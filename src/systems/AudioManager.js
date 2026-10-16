import { SFX_FILES, MUSIC_FILES } from '../config/audioConfig.js';
import { SYNTH_SFX, SYNTH_MUSIC, parseTrack, noteToFreq, scheduleNote } from './SynthSounds.js';
import { SaveManager } from './SaveManager.js';

/**
 * Sistema de audio desacoplado: el juego sólo emite eventos por nombre
 * (audio.play('jump')).  Si existe un archivo asignado y cargado se reproduce;
 * si no, se usa el sonido provisional sintetizado.
 * Una única instancia por juego, compartida por todas las escenas.
 */
export class AudioManager {
  static get(game) {
    if (!game.__audioManager) game.__audioManager = new AudioManager(game);
    return game.__audioManager;
  }

  constructor(game) {
    this.game = game;
    this.musicOn = SaveManager.getSetting('music') !== false;
    this.sfxOn = SaveManager.getSetting('sfx') !== false;
    this.ctx = null;
    this.currentTrack = null;
    this.fileMusic = null;
    this.timer = null;
    this.lastPlay = {};
  }

  /** Crea/reanuda el contexto WebAudio (los navegadores exigen un gesto del usuario). */
  ensureContext() {
    if (!this.ctx) {
      const sm = this.game.sound;
      this.ctx = sm && sm.context ? sm.context : new (window.AudioContext || window.webkitAudioContext)();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.9;
      this.master.connect(this.ctx.destination);
      this.sfxBus = this.ctx.createGain();
      this.sfxBus.connect(this.master);
      this.musicBus = this.ctx.createGain();
      this.musicBus.gain.value = this.musicOn ? 1 : 0;
      this.musicBus.connect(this.master);
    }
    if (this.ctx.state === 'suspended') this.ctx.resume().catch(() => {});
    return this.ctx;
  }

  play(event) {
    if (!this.sfxOn) return;
    // evita acumulaciones del mismo efecto en el mismo instante
    const now = performance.now();
    if (this.lastPlay[event] && now - this.lastPlay[event] < 35) return;
    this.lastPlay[event] = now;

    const file = SFX_FILES[event];
    if (file && this.game.cache.audio.exists(`sfx_${event}`)) {
      this.game.sound.play(`sfx_${event}`);
      return;
    }
    const synth = SYNTH_SFX[event];
    if (!synth) {
      console.warn(`[AudioManager] Evento de sonido desconocido: ${event}`);
      return;
    }
    const ctx = this.ensureContext();
    if (ctx.state !== 'running') return;
    synth(ctx, this.sfxBus);
  }

  playMusic(track) {
    if (this.currentTrack === track) return;
    this.stopMusic();
    this.currentTrack = track;
    if (!this.musicOn) return;
    this.startCurrent();
  }

  startCurrent() {
    const track = this.currentTrack;
    if (!track) return;
    if (MUSIC_FILES[track] && this.game.cache.audio.exists(`music_${track}`)) {
      this.fileMusic = this.game.sound.add(`music_${track}`, { loop: true, volume: 0.5 });
      this.fileMusic.play();
      return;
    }
    const song = SYNTH_MUSIC[track];
    if (!song) return;
    const ctx = this.ensureContext();
    const melody = parseTrack(song.melody);
    const bass = parseTrack(song.bassline);
    const step = 60 / song.bpm / 2; // corcheas
    let index = 0;
    let nextTime = ctx.currentTime + 0.08;
    const len = Math.max(melody.length, bass.length);
    const durationOf = (arr, i) => {
      let n = 1;
      while (arr[(i + n) % arr.length] === '-' && n < 16) n++;
      return n * step;
    };
    const tick = () => {
      if (ctx.state !== 'running') {
        nextTime = ctx.currentTime + 0.08;
        return;
      }
      while (nextTime < ctx.currentTime + 0.2) {
        const m = melody[index % melody.length];
        const b = bass[index % bass.length];
        if (m && m !== '-' && m !== '.') scheduleNote(ctx, this.musicBus, song.lead, noteToFreq(m), nextTime, durationOf(melody, index % melody.length) * 0.92);
        if (b && b !== '-' && b !== '.') scheduleNote(ctx, this.musicBus, song.bass, noteToFreq(b), nextTime, durationOf(bass, index % bass.length) * 0.9);
        nextTime += step;
        index = (index + 1) % len;
      }
    };
    this.timer = window.setInterval(tick, 40);
    tick();
  }

  stopMusic() {
    if (this.timer) window.clearInterval(this.timer);
    this.timer = null;
    if (this.fileMusic) {
      this.fileMusic.stop();
      this.fileMusic.destroy();
      this.fileMusic = null;
    }
  }

  setMusicEnabled(on) {
    this.musicOn = on;
    SaveManager.setSetting('music', on);
    if (this.musicBus) this.musicBus.gain.value = on ? 1 : 0;
    if (on) {
      if (!this.timer && !this.fileMusic) this.startCurrent();
    } else {
      this.stopMusic();
    }
  }

  setSfxEnabled(on) {
    this.sfxOn = on;
    SaveManager.setSetting('sfx', on);
  }

  /** Atenúa la música (pausa) o la restaura. */
  duck(on) {
    if (this.musicBus) this.musicBus.gain.value = this.musicOn ? (on ? 0.35 : 1) : 0;
    if (this.fileMusic) this.fileMusic.setVolume(on ? 0.2 : 0.5);
  }
}
