/**
 * Crea las animaciones de todos los personajes a partir de assets/manifest.json
 * (generado por tools/prepare_assets.py).  Las claves resultantes siguen el
 * patrón "<personaje>_<animación>", p. ej. "player_walk" o "nubarron_storm".
 */
export const AnimationManager = {
  createAll(scene, manifest) {
    const created = [];
    for (const [charKey, def] of Object.entries(manifest.characters || {})) {
      for (const [anim, a] of Object.entries(def.anims)) {
        const key = `${charKey}_${anim}`;
        if (scene.anims.exists(key)) continue;
        const tex = scene.textures.get(charKey);
        const frames = a.frames.filter((f) => tex.has(f)).map((f) => ({ key: charKey, frame: f }));
        if (frames.length === 0) {
          console.error(`[AnimationManager] La animación ${key} no tiene fotogramas válidos.`);
          continue;
        }
        scene.anims.create({ key, frames, frameRate: a.frameRate, repeat: a.repeat });
        created.push(key);
      }
    }
    // Animación del portal (fotogramas generados en el atlas fx)
    const fx = scene.textures.get('fx');
    const portalFrames = [0, 1, 2, 3, 4, 5].map((i) => `portal_${i}`).filter((f) => fx.has(f));
    if (portalFrames.length && !scene.anims.exists('portal_spin')) {
      scene.anims.create({
        key: 'portal_spin',
        frames: portalFrames.map((f) => ({ key: 'fx', frame: f })),
        frameRate: 10,
        repeat: -1,
      });
    }
    return created;
  },

  /** Devuelve el tamaño de celda de un personaje (para calcular hitboxes). */
  frameSize(manifest, charKey) {
    const c = manifest.characters?.[charKey];
    return c ? { width: c.frameWidth, height: c.frameHeight } : { width: 32, height: 32 };
  },
};
