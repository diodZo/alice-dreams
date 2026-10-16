import { WEAPONS, WEAPON_ORDER, PAINT_COLORS, FOAM_COLORS } from './weaponDefs.js';
import { spawnProjectile } from './Projectile.js';

/**
 * Inventario y disparo de armas.  Las armas se desbloquean al recoger su objeto
 * en el nivel; el estado se guarda en el registro para pasar entre escenas.
 */
export class WeaponManager {
  constructor(scene, player, group, owned = [], current = null) {
    this.scene = scene;
    this.player = player;
    this.group = group;
    this.owned = WEAPON_ORDER.filter((id) => owned.includes(id));
    this.currentId = current && this.owned.includes(current) ? current : this.owned[0] || null;
    this.readyAt = 0;
    this.colorIndex = 0;
    this.noWeaponHintAt = 0;
  }

  get current() {
    return this.currentId ? WEAPONS[this.currentId] : null;
  }

  has(id) {
    return this.owned.includes(id);
  }

  unlock(id) {
    if (!WEAPONS[id] || this.has(id)) return false;
    this.owned = WEAPON_ORDER.filter((w) => w === id || this.owned.includes(w));
    this.currentId = id;
    this.emit();
    return true;
  }

  cycle() {
    if (this.owned.length < 2) {
      if (this.owned.length === 0) this.hintNoWeapon();
      return;
    }
    const i = this.owned.indexOf(this.currentId);
    this.currentId = this.owned[(i + 1) % this.owned.length];
    this.scene.audio.play('weapon_switch');
    this.emit();
  }

  emit() {
    this.scene.registry.set('weapon', this.currentId);
    this.scene.registry.set('weaponsOwned', [...this.owned]);
  }

  update(time) {
    const c = this.player.controls.state;
    if (this.player.dead || this.player.frozen || this.player.celebrating) return;
    if (c.switchPressed) this.cycle();
    const wantsFire = c.firePressed || (c.fireHeld && this.currentId === 'bubble');
    if (!wantsFire) return;
    if (!this.current) {
      if (c.firePressed) this.hintNoWeapon();
      return;
    }
    if (time < this.readyAt || time < this.player.stunnedUntil) return;
    this.fire(time, c.up);
  }

  hintNoWeapon() {
    this.scene.audio.play('no_weapon');
    const now = this.scene.time.now;
    if (now > this.noWeaponHintAt) {
      this.noWeaponHintAt = now + 2500;
      this.scene.game.events.emit('hud-toast', '¡Aún no tienes arma! Salta sobre los monstruos.');
    }
  }

  fire(time, aimUp) {
    const w = this.current;
    const p = w.projectile;
    const m = this.player.muzzle();
    const dir = this.player.facing;
    let vx = dir * p.speed;
    let vy = p.vy || 0;
    if (aimUp) {
      vx = dir * p.speed * 0.7;
      vy = Math.min(vy, 0) - p.speed * 0.7;
    }
    let tint;
    if (p.tintCycle === 'paint') tint = PAINT_COLORS[this.colorIndex++ % PAINT_COLORS.length];
    if (p.tintCycle === 'foam') tint = FOAM_COLORS[this.colorIndex++ % FOAM_COLORS.length];
    const proj = spawnProjectile(this.group, {
      x: m.x,
      y: aimUp ? m.y - 6 : m.y,
      vx,
      vy,
      gravity: p.gravity,
      texture: p.texture,
      frame: p.frame,
      lifespan: p.lifespan,
      body: p.body,
      scale: p.scale,
      alpha: p.alpha,
      wobble: aimUp ? 0 : p.wobble,
      spin: p.spin,
      tint,
      owner: 'player',
      kind: w.id,
      damage: w.damage,
    });
    if (!proj) return;
    proj.weapon = w;
    proj.paintColor = tint;
    this.readyAt = time + w.cooldown;
    this.player.playAttack(w.id, w.recoil);
    this.scene.audio.play(w.sound);
    if (p.trail) this.scene.effects.paintTrail(proj, tint);
    if (w.id === 'sling') this.scene.cameras.main.shake(60, 0.0015);
  }
}
