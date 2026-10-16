import { DEPTH, TILE } from '../config/gameConfig.js';
import { LevelScene } from './LevelScene.js';
import { WORLD1 } from '../data/world1.js';

/** Mundo 1, secciones A-E hasta la puerta del castillo de Nubarrón. */
export class World1Scene extends LevelScene {
  constructor() {
    super('World1');
  }

  getLevelData() {
    return WORLD1;
  }

  onCreate() {
    const door = this.levelData.door;
    const x = door.x * TILE + TILE / 2;
    const y = door.y * TILE;
    // fachada del castillo (decorado) con una puerta luminosa que inicia el combate
    this.add.image(x, y + 6, this.levelData.backgroundAtlas, 'castle').setOrigin(0.5, 1).setScale(1.6).setDepth(DEPTH.DECOR_BACK - 1);
    const glow = this.add.image(x, y - 18, 'glow').setScale(3, 4).setTint(0xffe082).setDepth(DEPTH.DECOR_BACK);
    this.tweens.add({ targets: glow, alpha: 0.35, duration: 600, yoyo: true, repeat: -1 });
    this.doorZone = this.add.zone(x, y - 20, 22, 40);
    this.physics.add.existing(this.doorZone, true);
    this.physics.add.overlap(this.player, this.doorZone, () => this.enterCastle());
  }

  enterCastle() {
    if (this.leaving || this.player.dead) return;
    this.leaving = true;
    this.player.frozen = true;
    this.player.body.setVelocity(0, 0);
    this.controls.setEnabled(false);
    this.audio.play('portal');
    this.registry.set('hp', this.player.hp);
    const cam = this.cameras.main;
    cam.fadeOut(600, 52, 85, 164);
    cam.once('camerafadeoutcomplete', () => this.scene.start(this.levelData.nextScene, {}));
  }
}
