import { Checkpoint } from '../entities/Checkpoint.js';

/**
 * Gestiona los puntos de control de una escena: activación y punto de reaparición.
 * El último checkpoint se guarda en el registro para sobrevivir a reinicios de escena
 * (p. ej. "Reiniciar desde el checkpoint" en el menú de pausa).
 */
export class CheckpointManager {
  constructor(scene, defs, atlas, sceneKey, startPoint) {
    this.scene = scene;
    this.sceneKey = sceneKey;
    this.start = startPoint;
    this.flags = defs.map((d, i) => new Checkpoint(scene, d, atlas, i));
    const saved = scene.registry.get('checkpoint');
    this.current = null;
    if (saved && saved.scene === sceneKey) {
      this.current = saved;
      this.flags.forEach((f) => {
        if (f.index <= saved.index) f.activate(true);
      });
    }
  }

  get group() {
    return this.flags;
  }

  /** Devuelve el punto de reaparición actual (checkpoint o inicio de la escena). */
  get respawnPoint() {
    return this.current ? { x: this.current.x, y: this.current.y } : { ...this.start };
  }

  activate(flag) {
    if (!flag.activate()) return;
    if (this.current && this.current.index >= flag.index) return;
    this.current = { scene: this.sceneKey, index: flag.index, x: flag.respawn.x, y: flag.respawn.y };
    this.scene.registry.set('checkpoint', this.current);
    this.scene.audio.play('checkpoint');
    this.scene.game.events.emit('hud-toast', '¡Punto de control!');
    // al tocar un checkpoint se recupera la vida
    this.scene.player.heal(true);
  }
}
