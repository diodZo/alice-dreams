import { TILE } from '../config/gameConfig.js';
import { LevelScene } from './LevelScene.js';
import { WORLD1 } from '../data/world1.js';
import { Nubarron } from '../bosses/Nubarron.js';
import { Star, Portal } from '../entities/Collectibles.js';
import { SaveManager } from '../systems/SaveManager.js';

/**
 * Arena del castillo (tramo final del Mundo 1).  Usa el mismo motor que el resto
 * del nivel y añade: puerta que se cierra, combate con Nubarrón, estrella especial
 * y portal al siguiente mundo.
 */
export class BossScene extends LevelScene {
  constructor() {
    super('Boss');
  }

  getLevelData() {
    return WORLD1.boss;
  }

  onCreate() {
    const d = this.levelData;
    this.fightStarted = false;
    this.portal = null;
    this.boss = new Nubarron(this, d.boss);
    this.boss.setVisible(false);
    this.boss.body.enable = false;

    this.physics.add.overlap(
      this.playerProjectiles,
      this.boss,
      (a, b) => {
        // Phaser puede pasar los argumentos en cualquier orden según el tipo
        const proj = a === this.boss ? b : a;
        if (proj.active && this.boss.hitBy(proj)) proj.expire();
      },
      (a, b) => (a === this.boss ? b : a).active,
    );
    this.physics.add.overlap(this.player, this.boss, () => {
      if (this.boss.isDefeated || this.boss.fsm.is('INTRO') || !this.fightStarted) return;
      this.player.hurt(this.boss.x);
    });

    this.listen(this.events, 'boss-defeated', (x, y) => this.onBossDefeated(x, y));
    this.registry.set('bossVisible', false);
  }

  onUpdate() {
    if (!this.fightStarted && this.player.x > this.levelData.triggerX * TILE) this.startFight();
  }

  startFight() {
    const d = this.levelData;
    this.fightStarted = true;
    // la entrada queda bloqueada durante el combate
    for (const r of d.gate.rows) {
      this.builder.setBlock(d.gate.x, r, d.gate.tile);
      this.effects.poof(d.gate.x * TILE + 8, r * TILE + 8, 6);
    }
    this.audio.play('boss_appear');
    this.audio.playMusic(d.bossMusic);
    this.cameras.main.shake(500, 0.005);
    this.player.frozen = true;
    this.time.delayedCall(1500, () => (this.player.frozen = false));
    this.boss.setVisible(true);
    this.boss.body.enable = true;
    this.boss.intro();
    this.registry.set('bossMaxHp', this.boss.maxHp);
    this.registry.set('bossHp', this.boss.hp);
    this.registry.set('bossVisible', true);
    this.game.events.emit('hud-banner', '¡Nubarrón!');
  }

  onBossDefeated(x, y) {
    this.registry.set('bossVisible', false);
    this.enemyProjectiles.getChildren().forEach((c) => c.active && c.kill());
    this.audio.playMusic('world1');
    this.game.events.emit('hud-banner', '¡Has calmado a Nubarrón!');
    // entrega la estrella dorada especial, que cae hasta el suelo de la arena
    const star = new Star(this, x, y, { special: true });
    star.body.moves = false;
    this.tweens.killTweensOf(star);
    this.tweens.add({ targets: star, y: this.levelData.boss.floorY - 22, duration: 900, ease: 'Bounce.easeOut' });
    this.starGroup.add(star);
  }

  onSpecialStar() {
    this.registry.set('specialStar', true);
    this.game.events.emit('hud-toast', '¡Estrella dorada especial!');
    const p = this.levelData.portal;
    this.time.delayedCall(700, () => {
      this.portal = new Portal(this, p.x * TILE + TILE / 2, p.y * TILE);
      this.audio.play('portal');
      this.game.events.emit('hud-toast', 'Se ha abierto el portal al Mundo 2');
      this.physics.add.overlap(this.player, this.portal, () => this.enterPortal());
    });
  }

  enterPortal() {
    if (this.leaving || !this.portal || this.portal.used) return;
    this.portal.used = true;
    this.leaving = true;
    this.controls.setEnabled(false);
    this.player.celebrate();
    this.audio.stopMusic();
    this.audio.play('victory');
    this.effects.confetti(this.player.x, this.player.y - 40, 80);

    const stars = this.registry.get('stars') || 0;
    const total = this.registry.get('starsTotal') || 0;
    SaveManager.markWorldCompleted(1, stars, total);

    this.time.delayedCall(2200, () => {
      const cam = this.cameras.main;
      cam.fadeOut(700, 255, 247, 255);
      cam.once('camerafadeoutcomplete', () => {
        this.scene.stop('HUD');
        this.scene.start('Victory', {
          stars,
          total,
          special: !!this.registry.get('specialStar'),
          time: this.registry.get('playTime') || 0,
        });
      });
    });
  }

  /** Si la protagonista cae rendida durante el combate, el combate empieza de nuevo. */
  respawn(full) {
    if (this.fightStarted && !this.boss.isDefeated) {
      if (this.respawning) return;
      this.respawning = true;
      this.registry.set('hp', this.player.maxHp);
      this.registry.set('bossVisible', false);
      this.game.events.emit('hud-toast', '¡Inténtalo otra vez!');
      const cam = this.cameras.main;
      cam.fadeOut(500, 52, 85, 164);
      cam.once('camerafadeoutcomplete', () => this.scene.restart({}));
      return;
    }
    super.respawn(full);
  }
}
