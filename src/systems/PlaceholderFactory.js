/**
 * Marcadores provisionales IDENTIFICABLES para recursos que no se pudieron cargar.
 * Son cuadros a cuadros magenta/negro con borde, imposibles de confundir con arte
 * final.  Cada uso queda registrado en `PlaceholderFactory.used` y en la consola,
 * y el menú principal muestra un aviso si existe alguno.
 */
export const PlaceholderFactory = {
  used: new Set(),

  makeTexture(scene, key, w, h) {
    if (scene.textures.exists(key)) scene.textures.remove(key);
    const tex = scene.textures.createCanvas(key, w, h);
    PlaceholderFactory.paint(tex.getContext(), 0, 0, w, h);
    tex.refresh();
    return tex;
  },

  paint(ctx, x, y, w, h) {
    for (let yy = 0; yy < h; yy += 4) {
      for (let xx = 0; xx < w; xx += 4) {
        ctx.fillStyle = ((xx + yy) / 4) % 2 === 0 ? '#ff00ff' : '#000000';
        ctx.fillRect(x + xx, y + yy, 4, 4);
      }
    }
    ctx.strokeStyle = '#ffff00';
    ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
  },

  /** Atlas provisional con todos los fotogramas indicados (mismo tamaño). */
  makeAtlas(scene, key, frameNames, w, h) {
    const cols = Math.max(1, Math.min(frameNames.length, 8));
    const rows = Math.ceil(frameNames.length / cols);
    if (scene.textures.exists(key)) scene.textures.remove(key);
    const tex = scene.textures.createCanvas(key, cols * w, rows * h);
    const ctx = tex.getContext();
    frameNames.forEach((name, i) => {
      const fx = (i % cols) * w;
      const fy = Math.floor(i / cols) * h;
      PlaceholderFactory.paint(ctx, fx, fy, w, h);
      tex.add(name, 0, fx, fy, w, h);
    });
    tex.refresh();
    PlaceholderFactory.mark(key);
    return tex;
  },

  /** Frame de atlas seguro: si falta, devuelve una textura provisional y lo registra. */
  frameOrPlaceholder(scene, atlas, frame) {
    if (scene.textures.exists(atlas) && scene.textures.get(atlas).has(frame)) {
      return { key: atlas, frame };
    }
    const key = `__placeholder_16`;
    if (!scene.textures.exists(key)) PlaceholderFactory.makeTexture(scene, key, 16, 16);
    PlaceholderFactory.mark(`${atlas}:${frame}`);
    return { key, frame: undefined };
  },

  mark(name) {
    if (!PlaceholderFactory.used.has(name)) {
      PlaceholderFactory.used.add(name);
      console.warn(`[Placeholder] Recurso no disponible, se usa marcador provisional: ${name}`);
    }
  },
};
