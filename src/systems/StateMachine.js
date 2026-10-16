/**
 * Máquina de estados mínima usada por enemigos y jefe.
 * states: { NOMBRE: { enter(prev, data), update(time, delta), exit(next) } }
 */
export class StateMachine {
  constructor(owner, states, initial) {
    this.owner = owner;
    this.states = states;
    this.current = null;
    this.elapsed = 0;
    if (initial) this.set(initial);
  }

  set(name, data) {
    if (!this.states[name]) throw new Error(`Estado desconocido: ${name}`);
    const prev = this.current;
    if (prev && this.states[prev].exit) this.states[prev].exit.call(this.owner, name);
    this.current = name;
    this.elapsed = 0;
    if (this.states[name].enter) this.states[name].enter.call(this.owner, prev, data);
  }

  is(name) {
    return this.current === name;
  }

  update(time, delta) {
    this.elapsed += delta;
    const st = this.states[this.current];
    if (st && st.update) st.update.call(this.owner, time, delta);
  }
}
