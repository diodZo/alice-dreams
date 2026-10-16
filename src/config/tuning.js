/**
 * Valores de ajuste de jugabilidad (en píxeles lógicos y milisegundos).
 * Están separados del código para poder equilibrar el juego sin tocar la lógica.
 */
export const PLAYER_TUNING = {
  maxHp: 3,
  walkSpeed: 95,
  runSpeed: 150,
  groundAccel: 950,
  groundDecel: 1200,
  airAccel: 620,
  airDecel: 380,
  jumpVelocity: -335,
  jumpCutVelocity: -120,
  maxFallSpeed: 430,
  coyoteTime: 100,
  jumpBuffer: 120,
  invulnerableTime: 1300,
  hurtStunTime: 350,
  hurtKnockback: { x: 150, y: -170 },
  stompBounce: -250,
  attackPoseTime: 260,
  // Hitbox independiente del tamaño gráfico (la celda del sprite es 42x44)
  body: { width: 12, height: 30, footPadding: 1 },
};

export const CAMERA_TUNING = {
  lerp: 0.12,
  deadzone: { width: 40, height: 60 },
  lookAhead: 36,
};
