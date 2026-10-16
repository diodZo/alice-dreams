/**
 * Definición de las tres armas.  Todo lo que diferencia un arma de otra es dato:
 * WeaponManager y Projectile son comunes.
 *  damage      -> daño a enemigos normales
 *  bossDamage  -> daño a Nubarrón (las tres armas pueden derrotarlo)
 *  effect      -> 'trap' (burbuja atrapa), 'paint' (marca de pintura y ralentiza), 'impact'
 */
export const PAINT_COLORS = [0xf7489a, 0x78c5f8, 0xffe082, 0x7ee07e, 0xb9a7f4, 0xff9f5a];
export const FOAM_COLORS = [0xf7a8d8, 0x78c5f8, 0xffe082, 0xb9a7f4, 0x9df0c0];

export const WEAPONS = {
  bubble: {
    id: 'bubble',
    name: 'Lanzaburbujas',
    icon: 'icon_bubble',
    sound: 'shoot_bubble',
    cooldown: 230,
    projectile: {
      texture: 'fx',
      frame: 'bubble',
      speed: 185,
      vy: -14,
      gravity: 0,
      lifespan: 950,
      alpha: 0.85,
      wobble: 3,
      body: 10,
      scale: 0.9,
    },
    damage: 0,
    bossDamage: 1,
    effect: 'trap',
    recoil: 0,
  },
  paint: {
    id: 'paint',
    name: 'Lanzapintura',
    icon: 'icon_paint',
    sound: 'shoot_paint',
    cooldown: 380,
    projectile: {
      texture: 'paint_blob',
      speed: 255,
      vy: 0,
      gravity: 0,
      lifespan: 560,
      body: 7,
      tintCycle: 'paint',
      trail: true,
    },
    damage: 1,
    bossDamage: 2,
    effect: 'paint',
    recoil: 0,
  },
  sling: {
    id: 'sling',
    name: 'Tirachinas',
    icon: 'icon_sling',
    sound: 'shoot_sling',
    cooldown: 650,
    projectile: {
      texture: 'fx',
      frame: 'pellet',
      speed: 235,
      vy: -150,
      gravity: 520,
      lifespan: 1500,
      body: 7,
      tintCycle: 'foam',
      spin: 720,
    },
    damage: 2,
    bossDamage: 3,
    effect: 'impact',
    recoil: 160,
  },
};

export const WEAPON_ORDER = ['bubble', 'paint', 'sling'];
