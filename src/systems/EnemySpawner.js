import { ScratchMonster } from '../entities/ScratchMonster.js';
import { SpitMonster } from '../entities/SpitMonster.js';
import { FleaMonster } from '../entities/FleaMonster.js';
import { GAME_WIDTH } from '../config/gameConfig.js';

const TYPES = { scratch: ScratchMonster, spit: SpitMonster, flea: FleaMonster };

/**
 * Crea los enemigos sólo cuando la cámara se acerca a su posición y los retira
 * cuando quedan muy lejos, con un máximo de enemigos activos simultáneos.
 * Los enemigos derrotados no reaparecen.
 */
export class EnemySpawner {
  constructor(scene, spawns, group, { maxActive = 6, margin = 80 } = {}) {
    this.scene = scene;
    this.group = group;
    this.maxActive = maxActive;
    this.margin = margin;
    this.pending = spawns.map((s, i) => ({ id: s.id ?? `e${i}`, ...s }));
    this.defeated = new Set(scene.registry.get('defeatedEnemies') || []);
    this.active = new Map();
    // LevelScene.listen elimina el oyente al cerrar la escena (evita duplicados al reiniciar)
    scene.listen(scene.events, 'enemy-finished', (enemy) => {
      this.defeated.add(enemy.spawn.id);
      this.active.delete(enemy.spawn.id);
      scene.registry.set('defeatedEnemies', [...this.defeated]);
    });
  }

  update() {
    const cam = this.scene.cameras.main;
    const left = cam.scrollX - this.margin;
    const right = cam.scrollX + GAME_WIDTH + this.margin;
    for (const s of this.pending) {
      if (this.active.size >= this.maxActive) break;
      if (this.defeated.has(s.id) || this.active.has(s.id)) continue;
      if (s.x >= left && s.x <= right && (s.x < cam.scrollX - 8 || s.x > cam.scrollX + GAME_WIDTH + 8)) {
        // sólo aparecen fuera del encuadre, nunca de golpe delante de la jugadora
        this.spawn(s);
      } else if (s.x >= left && s.x <= right && !this.started) {
        this.spawn(s);
      }
    }
    this.started = true;
    for (const [id, e] of this.active) {
      if (!e.active) {
        this.active.delete(id);
        continue;
      }
      if (e.x < cam.scrollX - this.margin * 4 || e.x > cam.scrollX + GAME_WIDTH + this.margin * 4) {
        e.despawn();
        this.active.delete(id);
      }
    }
  }

  spawn(s) {
    const Cls = TYPES[s.type];
    if (!Cls) {
      console.error(`[EnemySpawner] Tipo de enemigo desconocido: ${s.type}`);
      this.defeated.add(s.id);
      return;
    }
    const e = new Cls(this.scene, s.x, s.y, s);
    this.group.add(e);
    this.active.set(s.id, e);
  }

  /** Al reaparecer en un checkpoint se retiran todos y vuelven a aparecer al acercarse. */
  resetActive() {
    for (const e of this.active.values()) if (e.active) e.despawn();
    this.active.clear();
    this.started = false;
  }
}
