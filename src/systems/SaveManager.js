/**
 * Persistencia del progreso en localStorage.
 * Si el almacenamiento no está disponible (modo privado, bloqueado), el juego sigue
 * funcionando con los datos en memoria y se avisa por consola.
 */
const KEY = 'guardiana-de-los-suenos:save:v1';

const DEFAULTS = () => ({
  version: 1,
  worlds: {}, // { [worldId]: { completed: true, bestStars: n, completedAt: iso } }
  settings: { music: true, sfx: true },
});

let state = null;
let storageOk = true;

function load() {
  if (state) return state;
  state = DEFAULTS();
  try {
    const raw = window.localStorage.getItem(KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      state = { ...DEFAULTS(), ...parsed, settings: { ...DEFAULTS().settings, ...(parsed.settings || {}) } };
    }
  } catch (err) {
    storageOk = false;
    console.warn('[SaveManager] No se pudo leer el progreso guardado:', err);
  }
  return state;
}

function persist() {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(state));
  } catch (err) {
    if (storageOk) console.warn('[SaveManager] No se pudo guardar el progreso:', err);
    storageOk = false;
  }
}

export const SaveManager = {
  get data() {
    return load();
  },

  isStorageAvailable() {
    load();
    return storageOk;
  },

  getSetting(name) {
    return load().settings[name];
  },

  setSetting(name, value) {
    load().settings[name] = value;
    persist();
  },

  isWorldCompleted(worldId) {
    return !!load().worlds[worldId]?.completed;
  },

  getWorld(worldId) {
    return load().worlds[worldId] || null;
  },

  markWorldCompleted(worldId, stars, totalStars) {
    const s = load();
    const prev = s.worlds[worldId] || {};
    s.worlds[worldId] = {
      completed: true,
      bestStars: Math.max(prev.bestStars || 0, stars),
      totalStars,
      completedAt: new Date().toISOString(),
    };
    persist();
  },

  resetProgress() {
    const settings = load().settings;
    state = DEFAULTS();
    state.settings = settings;
    persist();
  },
};
