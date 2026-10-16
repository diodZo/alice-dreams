import Phaser from 'phaser';
import { TILE, FORCE_TOUCH } from '../config/gameConfig.js';
import { PLAYER_TUNING, CAMERA_TUNING } from '../config/tuning.js';
import { Player } from '../entities/Player.js';
import { Star } from '../entities/Collectibles.js';
import { WEAPONS } from '../weapons/weaponDefs.js';
import { WeaponManager } from '../weapons/WeaponManager.js';
import { createProjectileGroup, Projectile } from '../weapons/Projectile.js';
import { AudioManager } from '../systems/AudioManager.js';
import { InputController } from '../systems/InputController.js';
import { EffectsManager } from '../systems/EffectsManager.js';
import { LevelBuilder } from '../systems/LevelBuilder.js';
import { ParallaxBackground } from '../systems/ParallaxBackground.js';
import { CheckpointManager } from '../systems/CheckpointManager.js';
import { EnemySpawner } from '../systems/EnemySpawner.js';
import { CrumblePlatform, createCloud } from '../entities/Platforms.js';

/**
 * Motor común de todos los niveles.  Las subclases sólo aportan sus datos
 * (getLevelData) y sus reglas particulares (onCreate / onUpdate).
 * No se duplican física, controles ni combate entre mundos.
 */
export class LevelScene extends Phaser.Scene {
  /** @abstract */
  getLevelData() {
    throw new Error('getLevelData() debe implementarse en la escena del mundo');
  }

  init(data) {
    this.entryData = data || {};
  }

  create() {
    const d = (this.levelData = this.getLevelData());
    this.manifest = this.registry.get('manifest');
    this.audio = AudioManager.get(this.game);
    this.cleanups = [];
    this.respawning = false;
    this.leaving = false;
    this.worldW = d.widthTiles * TILE;
    this.worldH = d.heightTiles * TILE;

    // sin límite inferior: caer al vacío es una zona de peligro
    this.physics.world.setBounds(0, 0, this.worldW, this.worldH + 80, true, true, true, false);
    this.cameras.main.setBounds(0, 0, this.worldW, this.worldH);
    this.cameras.main.setRoundPixels(true);

    this.touchMode = FORCE_TOUCH || this.sys.game.device.input.touch;
    this.parallax = new ParallaxBackground(this, {
      atlas: d.backgroundAtlas,
      objectsAtlas: d.objectsAtlas,
      worldWidth: this.worldW,
      worldHeight: this.worldH,
      showCastle: true,
      seed: d.key,
    });
    this.effects = new EffectsManager(this);
    this.builder = new LevelBuilder(this, d, this.manifest);
    this.level = this.builder.build({
      touchMode: this.touchMode,
      collectedStars: this.registry.get('collectedStars') || [],
    });

    this.controls = new InputController(this);
    const start = { x: d.playerStart.x * TILE + TILE / 2, y: d.playerStart.y * TILE };
    this.checkpoints = new CheckpointManager(this, d.checkpoints, d.objectsAtlas, this.scene.key, start);
    const spawn = this.checkpoints.respawnPoint;
    this.player = new Player(this, spawn.x, spawn.y, this.controls);
    const hp = this.registry.get('hp');
    this.player.hp = hp > 0 ? Math.min(hp, this.player.maxHp) : this.player.maxHp;

    this.playerProjectiles = createProjectileGroup(this, 24);
    this.enemyProjectiles = createProjectileGroup(this, 48);
    this.weapons = new WeaponManager(
      this,
      this.player,
      this.playerProjectiles,
      this.registry.get('weaponsOwned') || [],
      this.registry.get('weapon'),
    );
    this.weapons.emit();

    this.enemies = this.add.group();
    const spawns = d.enemies.map((e, i) => ({
      id: `${d.key}:e${i}`,
      type: e.type,
      x: e.x * TILE + TILE / 2,
      y: e.y * TILE,
      patrol: e.patrol ? [e.patrol[0] * TILE, e.patrol[1] * TILE + TILE] : undefined,
    }));
    this.spawner = new EnemySpawner(this, spawns, this.enemies, { maxActive: 6 });

    this.starGroup = this.add.group(this.level.stars);
    this.bonusStars = this.add.group();
    this.tempPlatforms = [];

    this.setupCollisions();
    this.setupCamera();
    this.setupEvents();

    this.registry.set('maxHp', this.player.maxHp);
    this.registry.set('hp', this.player.hp);
    this.registry.set('bossVisible', false);
    this.registry.set('progressMarks', d.sections.map((s) => s.from / d.progress.total));

    if (!this.scene.isActive('HUD')) this.scene.launch('HUD');
    this.scene.bringToTop('HUD');
    if (d.music) this.audio.playMusic(d.music);

    this.sectionIndex = this.findSection();
    this.registry.set('section', d.sections[this.sectionIndex]?.id);
    if (this.entryData.introBanner) this.announceSection();
    this.progressTimer = 0;

    this.onCreate();
    this.cameras.main.fadeIn(450, 52, 85, 164);
    this.events.once('shutdown', () => this.cleanup());
  }

  // ---------------------------------------------------------------- colisiones
  setupCollisions() {
    const L = this.level;
    const P = this.player;
    const phys = this.physics;

    phys.add.collider(P, L.terrain);
    phys.add.collider(
      P,
      L.oneWay,
      (p, plat) => this.onPlatformContact(plat),
      (p, plat) => this.oneWayCheck(p.body, plat.body),
    );
    phys.add.collider(this.enemies, L.terrain);
    phys.add.collider(this.enemies, L.oneWay, null, (e, plat) => this.oneWayCheck(e.body, plat.body));
    phys.add.collider(this.bonusStars, L.terrain);
    phys.add.collider(this.playerProjectiles, L.terrain, (proj) => proj.active && proj.hitWorld());
    phys.add.collider(this.enemyProjectiles, L.terrain, (proj) => proj.active && proj.kind !== 'wind' && proj.hitWorld(), (proj) => proj.kind !== 'rain' || proj.body.velocity.y > 0);

    // Phaser puede entregar el par en cualquier orden según el tipo de grupo: se normaliza
    const projPair = (a, b) => (a instanceof Projectile ? [a, b] : [b, a]);
    phys.add.overlap(
      this.playerProjectiles,
      this.enemies,
      (a, b) => {
        const [proj, enemy] = projPair(a, b);
        if (proj.active && enemy.hitBy(proj)) proj.expire();
      },
      (a, b) => {
        const [proj, enemy] = projPair(a, b);
        return proj.active && enemy.isAlive;
      },
    );
    phys.add.overlap(P, this.enemies, (p, e) => this.onPlayerTouchEnemy(e));
    phys.add.overlap(P, this.enemyProjectiles, (p, proj) => this.onEnemyProjectile(proj));
    phys.add.overlap(P, this.starGroup, (p, s) => this.onStar(s));
    phys.add.overlap(P, this.bonusStars, (p, s) => this.onStar(s));
    phys.add.overlap(P, L.pickups, (p, pk) => this.onPickup(pk));
    phys.add.overlap(P, this.checkpoints.group, (p, flag) => this.checkpoints.activate(flag));
    // el cojín se activa al pisarlo, tanto cayendo encima como entrando caminando
    phys.add.overlap(P, L.pads, (p, pad) => {
      if (p.body.velocity.y >= 0) pad.trigger(p);
    });
    phys.add.overlap(P, L.hazards, (p, h) => p.hurt(h.x));
    phys.add.overlap(P, L.winds, (p, w) => w.apply(p, this.game.loop.delta));
  }

  /** Colisión unidireccional: sólo se apoya quien llega desde arriba. */
  oneWayCheck(body, platBody) {
    if (!platBody || !platBody.enable) return false;
    const prevBottom = body.prev.y + body.height;
    const rise = Math.max(0, -(platBody.deltaY ? platBody.deltaY() : 0));
    return body.velocity.y >= -1 && prevBottom <= platBody.top + 5 + rise;
  }

  onPlatformContact(plat) {
    const p = this.player;
    if (!p.body.touching.down && !p.body.blocked.down) return;
    if (plat.bouncy) {
      p.bounce(plat.bouncy);
      this.audio.play('bounce');
      this.tweens.add({ targets: plat, scaleY: 0.8, scaleX: 1.1, duration: 80, yoyo: true });
      this.effects.sparkle(p.x, p.y, 6);
    } else if (plat instanceof CrumblePlatform) {
      plat.stepOn();
    }
  }

  onPlayerTouchEnemy(e) {
    const p = this.player;
    if (!e.isAlive || p.dead) return;
    if (e.isTrapped) {
      e.convertToStar();
      return;
    }
    const pb = p.body;
    if (pb.velocity.y > 20 && pb.bottom <= e.body.top + 10) {
      e.stomp();
      p.bounce(PLAYER_TUNING.stompBounce);
      this.effects.sparkle(e.x, e.body.top, 6);
      return;
    }
    if (e.isHarmful) p.hurt(e.x);
  }

  onEnemyProjectile(proj) {
    if (!proj.active || this.player.dead) return;
    if (proj.kind === 'wind') {
      if (proj.hitTargets.has('player')) return;
      proj.hitTargets.add('player');
      this.player.push(Math.sign(proj.body.velocity.x) * 330);
      if (this.player.grounded) this.player.body.setVelocityY(-90);
      this.effects.poof(this.player.x, this.player.y - 14, 6);
      return;
    }
    if (this.player.hurt(proj.x, proj.damage)) proj.expire();
  }

  onStar(star) {
    if (!star.collect()) return;
    this.registry.inc('stars', 1);
    if (star.id) {
      const list = this.registry.get('collectedStars') || [];
      this.registry.set('collectedStars', [...list, star.id]);
    }
    if (star.special) this.onSpecialStar(star);
  }

  onPickup(pk) {
    if (!pk.active) return;
    const w = WEAPONS[pk.weaponId];
    this.weapons.unlock(pk.weaponId);
    pk.collect();
    this.audio.play('pickup');
    this.game.events.emit('hud-banner', `¡Nueva arma: ${w.name}!`);
  }

  /** Estrella extra que sale de un monstruo atrapado en una burbuja. */
  spawnBonusStar(x, y) {
    const s = new Star(this, x, y, { bonus: true });
    this.bonusStars.add(s);
    s.body.setAllowGravity(true);
    s.body.setVelocity(Phaser.Math.Between(-40, 40), -180);
    s.body.setBounce(0.4);
    this.time.delayedCall(9000, () => {
      if (s.active) this.tweens.add({ targets: s, alpha: 0, duration: 400, onComplete: () => s.destroy() });
    });
  }

  /** Nube temporal (la invoca el jefe en la fase 2). */
  addTemporaryPlatform(x, y, ms) {
    const plat = createCloud(this, this.level.oneWay, { x: x / TILE, y: y / TILE, frame: 'cloud_face_small' }, this.levelData.objectsAtlas);
    plat.setAlpha(0);
    this.tweens.add({ targets: plat, alpha: 1, duration: 250 });
    this.time.delayedCall(ms - 1000, () => {
      if (plat.active) this.tweens.add({ targets: plat, alpha: 0.3, duration: 120, yoyo: true, repeat: 3 });
    });
    this.time.delayedCall(ms, () => {
      if (!plat.active) return;
      this.effects.poof(plat.x, plat.y + 6, 10);
      plat.destroy();
    });
  }

  // ------------------------------------------------------------------- cámara
  setupCamera() {
    const cam = this.cameras.main;
    cam.startFollow(this.player, true, CAMERA_TUNING.lerp, CAMERA_TUNING.lerp, 0, 16);
    cam.setDeadzone(CAMERA_TUNING.deadzone.width, CAMERA_TUNING.deadzone.height);
    this.lookAhead = 0;
  }

  updateCamera(delta) {
    const target = this.player.facing * CAMERA_TUNING.lookAhead;
    this.lookAhead += (target - this.lookAhead) * Math.min(1, delta / 400);
    this.cameras.main.setFollowOffset(-this.lookAhead, 16);
  }

  // ------------------------------------------------------------------- eventos
  listen(emitter, event, fn) {
    emitter.on(event, fn, this);
    this.cleanups.push(() => emitter.off(event, fn, this));
  }

  setupEvents() {
    this.listen(this.events, 'player-hp', (hp) => this.registry.set('hp', hp));
    this.listen(this.events, 'player-fainted', () => this.time.delayedCall(900, () => this.respawn(true)));
    this.listen(this.events, 'spawn-star', (x, y) => this.spawnBonusStar(x, y));
    this.listen(this.events, 'projectile-expired', (proj) => this.onProjectileExpired(proj));
    this.listen(this.events, 'resume', () => {
      this.controls.reset();
      this.audio.duck(false);
    });
  }

  onProjectileExpired(proj) {
    const fx = this.effects;
    switch (proj.kind) {
      case 'bubble':
        fx.bubblePop(proj.x, proj.y);
        break;
      case 'paint':
        fx.paintSplat(proj.x, proj.y, proj.paintColor);
        break;
      case 'sling':
        fx.impact(proj.x, proj.y, proj.tintTopLeft);
        break;
      case 'spit':
        fx.impact(proj.x, proj.y, 0x7ee07e);
        break;
      case 'cloudball':
      case 'rain':
      case 'flea':
        fx.poof(proj.x, proj.y, 5);
        break;
      default:
        break;
    }
  }

  // -------------------------------------------------------------- reaparición
  handleFall() {
    if (this.respawning || this.player.dead || this.leaving) return;
    const p = this.player;
    p.hp = Math.max(0, p.hp - 1);
    this.events.emit('player-hp', p.hp);
    this.audio.play('hurt');
    this.respawn(p.hp <= 0);
  }

  respawn(full) {
    if (this.respawning || this.leaving) return;
    this.respawning = true;
    const p = this.player;
    p.dead = true;
    p.body.setVelocity(0, 0);
    p.body.setAllowGravity(false);
    const cam = this.cameras.main;
    cam.fadeOut(280, 52, 85, 164);
    cam.once('camerafadeoutcomplete', () => {
      const pt = this.checkpoints.respawnPoint;
      p.body.setAllowGravity(true);
      p.respawnAt(pt.x, pt.y);
      if (full || p.hp <= 0) p.heal(true);
      this.spawner.resetActive();
      this.enemyProjectiles.getChildren().forEach((c) => c.active && c.kill());
      this.onRespawn();
      cam.fadeIn(300, 52, 85, 164);
      this.respawning = false;
    });
  }

  // -------------------------------------------------------------------- pausa
  pauseGame() {
    if (this.leaving || this.respawning) return;
    this.controls.reset();
    this.audio.play('pause');
    this.audio.duck(true);
    this.scene.launch('Pause', { from: this.scene.key });
    this.scene.bringToTop('Pause');
    this.scene.pause();
  }

  /** Reinicia la escena desde el último checkpoint (opción del menú de pausa). */
  restartFromCheckpoint() {
    this.registry.set('hp', this.player.maxHp);
    this.scene.restart({});
  }

  // ------------------------------------------------------------- secciones/HUD
  progressPx() {
    const pr = this.levelData.progress;
    return pr.offset + this.player.x * pr.scale;
  }

  findSection() {
    const px = this.progressPx();
    const secs = this.levelData.sections;
    let idx = 0;
    secs.forEach((s, i) => {
      if (px >= s.from) idx = i;
    });
    return idx;
  }

  announceSection() {
    const s = this.levelData.sections[this.sectionIndex];
    if (s) this.game.events.emit('hud-banner', `Sección ${s.id}: ${s.name}`);
  }

  updateProgress(delta) {
    this.progressTimer += delta;
    this.registry.inc('playTime', delta);
    if (this.progressTimer < 120) return;
    this.progressTimer = 0;
    const pr = this.levelData.progress;
    this.registry.set('progress', Phaser.Math.Clamp(this.progressPx() / pr.total, 0, 1));
    const idx = this.findSection();
    if (idx !== this.sectionIndex) {
      this.sectionIndex = idx;
      this.registry.set('section', this.levelData.sections[idx].id);
      this.announceSection();
    }
  }

  // ------------------------------------------------------------------- bucle
  update(time, delta) {
    this.controls.update();
    if (this.controls.state.pausePressed) {
      this.pauseGame();
      return;
    }
    this.player.update(time, delta);
    this.weapons.update(time);
    this.spawner.update();
    for (const m of this.level.movers) m.update(time, delta);
    this.updateSigns();
    this.parallax.update(delta);
    this.updateCamera(delta);
    this.updateProgress(delta);
    if (this.player.y > this.worldH + 24) this.handleFall();
    this.onUpdate(time, delta);
  }

  /** Sólo el cartel más cercano (a menos de 56 px) muestra su bocadillo. */
  updateSigns() {
    let best = null;
    let bestD = 56;
    for (const s of this.level.signs) {
      const d = s.distanceTo(this.player);
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    for (const s of this.level.signs) s.updateProximity(s === best);
  }

  cleanup() {
    this.cleanups.forEach((fn) => fn());
    this.cleanups = [];
    this.controls?.reset();
  }

  // ---------------------------------------------------- ganchos de las subclases
  onCreate() {}

  onUpdate() {}

  onRespawn() {}

  onSpecialStar() {}
}
