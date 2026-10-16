/**
 * Asociación de eventos de sonido con archivos de audio.
 *
 * Mientras un evento no tenga archivo asignado, AudioManager usa un sonido
 * PROVISIONAL sintetizado con WebAudio (ver systems/SynthSounds.js).
 * Para sustituirlo: copiar el archivo a public/assets/audio/ y añadir aquí la
 * ruta, p. ej.  jump: 'assets/audio/jump.ogg'.  PreloadScene lo cargará y
 * AudioManager lo usará automáticamente.
 */
export const SFX_FILES = {
  jump: null,
  shoot_bubble: null,
  shoot_paint: null,
  shoot_sling: null,
  weapon_switch: null,
  star: null,
  hurt: null,
  checkpoint: null,
  boss_appear: null,
  victory: null,
  enemy_hit: null,
  enemy_defeat: null,
  bubble_trap: null,
  bubble_pop: null,
  bounce: null,
  pickup: null,
  wind: null,
  boss_hit: null,
  ui_move: null,
  ui_select: null,
  pause: null,
  no_weapon: null,
  portal: null,
};

export const MUSIC_FILES = {
  menu: null,
  world1: null,
  boss: null,
};
