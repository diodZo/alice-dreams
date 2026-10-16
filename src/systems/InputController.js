import Phaser from 'phaser';

/**
 * Estado compartido de los botones virtuales.  Los escribe TouchControls (escena HUD)
 * y lo lee InputController (escena de nivel).  Vive en el registro del juego.
 */
export class VirtualPad {
  static get(game) {
    if (!game.__virtualPad) game.__virtualPad = new VirtualPad();
    return game.__virtualPad;
  }

  constructor() {
    this.held = { left: false, right: false, up: false, jump: false, fire: false, run: false };
    this.pressed = { jump: false, fire: false, switch: false, pause: false };
  }

  press(name) {
    if (name in this.held) this.held[name] = true;
    if (name in this.pressed) this.pressed[name] = true;
  }

  release(name) {
    if (name in this.held) this.held[name] = false;
  }

  consume(name) {
    const v = this.pressed[name];
    this.pressed[name] = false;
    return v;
  }

  releaseAll() {
    Object.keys(this.held).forEach((k) => (this.held[k] = false));
    Object.keys(this.pressed).forEach((k) => (this.pressed[k] = false));
  }
}

/**
 * Traduce teclado y botones virtuales a acciones de juego.  Se actualiza una vez
 * por fotograma; las entidades sólo consultan acciones, nunca teclas.
 *   A/←  D/→  izquierda/derecha · W/↑ apuntar arriba · Espacio saltar
 *   J disparar · K cambiar arma · Shift correr · Esc pausa
 */
export class InputController {
  constructor(scene) {
    this.scene = scene;
    this.pad = VirtualPad.get(scene.game);
    const K = Phaser.Input.Keyboard.KeyCodes;
    this.keys = scene.input.keyboard.addKeys(
      {
        left: K.A,
        left2: K.LEFT,
        right: K.D,
        right2: K.RIGHT,
        up: K.W,
        up2: K.UP,
        jump: K.SPACE,
        fire: K.J,
        swap: K.K,
        run: K.SHIFT,
        pause: K.ESC,
        pause2: K.P,
      },
      true,
      false,
    );
    this.enabled = true;
    this.state = this.blank();
  }

  blank() {
    return {
      left: false,
      right: false,
      up: false,
      run: false,
      jumpHeld: false,
      jumpPressed: false,
      fireHeld: false,
      firePressed: false,
      switchPressed: false,
      pausePressed: false,
    };
  }

  update() {
    const k = this.keys;
    const p = this.pad;
    const JD = Phaser.Input.Keyboard.JustDown;
    const s = this.blank();
    // Las pulsaciones se consumen siempre, aunque el control esté desactivado,
    // para que no se acumulen durante una animación o una pausa.
    const jumpPressed = JD(k.jump) || p.consume('jump');
    const firePressed = JD(k.fire) || p.consume('fire');
    const switchPressed = JD(k.swap) || p.consume('switch');
    s.pausePressed = JD(k.pause) || JD(k.pause2) || p.consume('pause');
    if (this.enabled) {
      s.left = k.left.isDown || k.left2.isDown || p.held.left;
      s.right = k.right.isDown || k.right2.isDown || p.held.right;
      s.up = k.up.isDown || k.up2.isDown || p.held.up;
      s.run = k.run.isDown || p.held.run;
      s.jumpHeld = k.jump.isDown || p.held.jump;
      s.fireHeld = k.fire.isDown || p.held.fire;
      s.jumpPressed = jumpPressed;
      s.firePressed = firePressed;
      s.switchPressed = switchPressed;
    }
    this.state = s;
    return s;
  }

  get axis() {
    return (this.state.right ? 1 : 0) - (this.state.left ? 1 : 0);
  }

  setEnabled(on) {
    this.enabled = on;
    if (!on) this.state = this.blank();
  }

  /** Suelta todas las teclas (al pausar o cambiar de escena) para evitar teclas "pegadas". */
  reset() {
    this.scene.input.keyboard.resetKeys();
    this.pad.releaseAll();
    this.state = this.blank();
  }
}
