import Phaser from 'phaser';
import { DEPTH, GAME_WIDTH, GAME_HEIGHT } from '../config/gameConfig.js';

/**
 * Fondo multicapa con parallax.  Las capas no tienen colisión ni forman parte del
 * escenario jugable.  Capas (de lejos a cerca): cielo, estrellas, luna, castillo,
 * islas flotantes, banco de nubes lejano, nubes a la deriva, banco de nubes cercano.
 */
export class ParallaxBackground {
  constructor(scene, { atlas, objectsAtlas, worldWidth, worldHeight, showCastle = true, seed = 1 }) {
    this.scene = scene;
    this.worldHeight = worldHeight;
    const rnd = new Phaser.Math.RandomDataGenerator([String(seed)]);
    const fixed = (obj, depth) => obj.setScrollFactor(0).setDepth(DEPTH.BG + depth);

    fixed(scene.add.image(0, 0, 'sky').setOrigin(0).setDisplaySize(GAME_WIDTH, GAME_HEIGHT), 0);

    // estrellas titilantes del cielo
    for (let i = 0; i < 26; i++) {
      const s = fixed(scene.add.image(rnd.between(4, GAME_WIDTH - 4), rnd.between(4, 120), 'fx', 'sparkle'), 1);
      s.setScale(rnd.realInRange(0.3, 0.6)).setAlpha(rnd.realInRange(0.4, 1));
      scene.tweens.add({ targets: s, alpha: 0.15, duration: rnd.between(600, 1600), yoyo: true, repeat: -1, delay: rnd.between(0, 1500) });
    }

    // objetos lejanos: el parallax lo resuelve la cámara mediante scrollFactor
    const moon = scene.add.image(GAME_WIDTH - 70, 44, atlas, 'moon').setDepth(DEPTH.BG + 2).setScrollFactor(0.02, 0.05);
    scene.tweens.add({ targets: moon, angle: { from: -3, to: 3 }, duration: 3000, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });

    if (showCastle) {
      scene.add.image(GAME_WIDTH * 0.62, 118, atlas, 'castle').setDepth(DEPTH.BG + 3).setAlpha(0.95).setScrollFactor(0.05, 0.08);
    }

    // islas flotantes a media distancia (se repiten a lo largo del recorrido)
    const islands = ['island_big', 'island_wide', 'island_eggs', 'island_small_a', 'island_small_b', 'island_tiny'];
    const layers = [
      { fx: 0.15, depth: 4, step: 190, yMin: 50, yMax: 120, alpha: 0.75, scale: 0.75 },
      { fx: 0.3, depth: 6, step: 260, yMin: 70, yMax: 150, alpha: 1, scale: 1 },
    ];
    for (const L of layers) {
      const span = worldWidth * L.fx + GAME_WIDTH + 200;
      for (let x = -60; x < span; x += L.step + rnd.between(-40, 40)) {
        const img = scene.add.image(x, rnd.between(L.yMin, L.yMax), atlas, rnd.pick(islands));
        img.setDepth(DEPTH.BG + L.depth).setAlpha(L.alpha).setScale(L.scale).setScrollFactor(L.fx, L.fx * 0.4);
        scene.tweens.add({ targets: img, y: '+=3', duration: rnd.between(1600, 2600), yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
      }
    }

    const far = scene.textures.get('clouds_far').getSourceImage();
    this.cloudsFar = fixed(scene.add.tileSprite(0, GAME_HEIGHT - far.height + 20, GAME_WIDTH, far.height, 'clouds_far').setOrigin(0), 8);

    // nubes sueltas que se desplazan solas
    this.drifters = [];
    for (let i = 0; i < 5; i++) {
      const c = fixed(scene.add.image(rnd.between(0, GAME_WIDTH), rnd.between(30, 110), objectsAtlas, rnd.pick(['cloud_small', 'cloud_puff', 'cloud_med'])), 9);
      c.setAlpha(0.7).setScale(0.6);
      this.drifters.push({ obj: c, speed: rnd.realInRange(4, 10) });
    }

    const near = scene.textures.get('clouds_near').getSourceImage();
    this.cloudsNear = fixed(scene.add.tileSprite(0, GAME_HEIGHT - near.height + 30, GAME_WIDTH, near.height, 'clouds_near').setOrigin(0), 10);
    this.baseFarY = this.cloudsFar.y;
    this.baseNearY = this.cloudsNear.y;
  }

  update(delta) {
    const cam = this.scene.cameras.main;
    const sx = cam.scrollX;
    const sy = cam.scrollY;
    const maxSy = Math.max(1, this.worldHeight - GAME_HEIGHT);
    const vy = sy / maxSy; // 0 arriba .. 1 abajo
    this.cloudsFar.tilePositionX = sx * 0.4;
    this.cloudsNear.tilePositionX = sx * 0.65;
    this.cloudsFar.y = this.baseFarY + (1 - vy) * 18;
    this.cloudsNear.y = this.baseNearY + (1 - vy) * 30;
    const dt = delta / 1000;
    for (const d of this.drifters) {
      d.obj.x -= d.speed * dt;
      if (d.obj.x < -40) d.obj.x = GAME_WIDTH + 40;
    }
  }
}
