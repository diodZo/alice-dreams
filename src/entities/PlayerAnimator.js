/**
 * Selecciona la animación de la protagonista según su estado físico.
 * No modifica la física: sólo lee el estado de Player.
 */
export class PlayerAnimator {
  constructor(player) {
    this.player = player;
    this.nextBlinkAt = 0;
    this.attackRestart = false;
  }

  restartAttack() {
    this.attackRestart = true;
  }

  update(time) {
    const p = this.player;
    if (p.dead || p.celebrating) return;
    const body = p.body;
    let key;
    if (time < p.stunnedUntil) {
      key = 'player_hurt';
    } else if (time < p.attackUntil && p.attackAnim) {
      key = `player_${p.attackAnim}`;
      if (this.attackRestart) {
        this.attackRestart = false;
        p.anims.play(key, false);
        return;
      }
    } else if (!p.grounded) {
      key = body.velocity.y < 0 ? 'player_jump' : 'player_fall';
    } else if (Math.abs(body.velocity.x) > 12) {
      key = Math.abs(body.velocity.x) > 115 ? 'player_run' : 'player_walk';
    } else {
      key = 'player_idle';
      // parpadeo ocasional en reposo
      if (time > this.nextBlinkAt) {
        this.nextBlinkAt = time + 2500 + Math.random() * 2500;
        p.anims.play('player_blink', true);
        p.once('animationcomplete-player_blink', () => {
          if (p.anims.currentAnim?.key === 'player_blink') p.anims.play('player_idle', true);
        });
        return;
      }
      if (p.anims.currentAnim?.key === 'player_blink' && p.anims.isPlaying) return;
    }
    p.anims.play(key, true);
  }
}
