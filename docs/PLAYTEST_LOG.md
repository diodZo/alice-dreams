# Registro de pruebas jugadas — Alice Dreams

> Protocolo y registro de IMP-034 ([`LEVEL_IMPROVEMENTS.md`](LEVEL_IMPROVEMENTS.md)). Es la única fuente de datos humanos del proyecto: las propuestas de balance (IMP-004, IMP-005, IMP-006, IMP-007) y la ubicación fina de los checkpoints (IMP-001) se ajustan con lo que se anote aquí.

## 1. Preparación

1. Jugadores: **al menos dos**, y uno de ellos de la edad objetivo (7 años). Si es posible, que nadie le haya explicado el juego antes.
2. Arrancar con el registro activado: el juego anota solo cada caída, golpe, desmayo, sección, checkpoint, puerta y jefe vencido.

   ```bat
   "C:\ruta\Godot_v4.7.2-stable_win64.exe" --path godot -- --playtest
   REM o la versión exportada:
   AliceDreams.exe -- --playtest
   ```

   El archivo queda en `%APPDATA%\Godot\app_userdata\Alice Dreams - Guardiana de los Sueños\playtest.csv` (se añaden filas; no se borra entre sesiones). Para empezar de cero, mover o borrar ese archivo.
3. Mando o teclado: anotar cuál se usa (columna *Control* de la tabla de sesiones).
4. Un mundo por sesión (15-20 min como máximo para la edad objetivo). Descanso entre mundos.

## 2. Durante la sesión

- **No ayudar** salvo que la persona lo pida o lleve más de 3 intentos en el mismo punto. Si se ayuda, anotarlo.
- Observar y anotar (sección *Observaciones*):
  - ¿Lee los carteles? ¿Cuáles salta o no entiende?
  - ¿Ve los avisos antes de los ataques (destello, “!”, farol levantado, estrella que titila)?
  - ¿Dónde duda, se frustra o se aburre? ¿Dónde se ríe o se sorprende?
  - ¿Sabe qué hacer en cada jefe? ¿Ataca sólo en el descanso o dispara todo el rato?
  - ¿Usa las tres armas o sólo una?
- Al terminar, tres preguntas: *¿Qué es lo que más te gustó? ¿Qué fue lo más difícil? ¿Quieres jugar el siguiente?*

## 3. Después de la sesión

```bat
python tools/playtest_summary.py
```

Imprime las tablas de caídas/golpes por sección y de mundos completados, listas para pegar en §5.

## 4. Sesiones

| Fecha | Jugador (edad) | Mundo | Control | Duración | ¿Completó el nivel? | ¿Venció al jefe? | Ayudas | Notas breves |
|---|---|---|---|---|---|---|---|---|
| | | | | | | | | |

## 5. Datos por sección (pegar la salida de `playtest_summary.py`)

*(pendiente de la primera sesión)*

## 6. Observaciones por mundo

### Mundo 1 — El Reino de las Nubes de Algodón
- Puntos a mirar: nube móvil sobre el foso 245-255 (sección C), Escupitines de la sección C, jefe Nubarrón.

### Mundo 2 — El Reino de los Crayones Encantados
- Puntos a mirar: puente dibujado 132-140 (sección B), libro móvil sobre el río ~244 (sección C), jefe Garabato.

### Mundo 3 — El Reino de los Peluches Dormilones
- Puntos a mirar: cuerdas con el Ovillo entre fosos 117-146 (sección B), nubes de sueño, jefe Rey Siestón.

### Mundo 4 — Reino de las Burbujas
- Puntos a mirar: natación (¿se entiende cómo salir del agua?), sección C, jefe Rey Patoburbuja.

### Mundo 5 — El Reino del Tren de Juguete
- Puntos a mirar: subir y bajar de los trenes, cruce en tren de la sección E (foso 560-583), jefe Locomostro.

### Mundo 6 — Sueños Cósmicos, Islas en el Cielo
- Puntos a mirar: tramo 480-525 de la sección D (menos enemigos tras IMP-030), ¿se distinguen las estrellas recogibles?, jefa Luna Estelar.

### Mundo 7 — El Valle de Caramelo
- Puntos a mirar: sección D (correas, piruletas, lanzadores), Piruletas Voladoras 280 y 353, jefe Don Chupetón.

### Mundo 8 — El Castillo de las Pesadillas
- Puntos a mirar: plataformas colgantes de la sección B (128-143), zonas de sombra, jefe Rey Pesadelo (¿se hace largo?), el final.

## 7. Conclusiones y decisiones

| Hallazgo | Mundo / sección | Propuesta afectada | Decisión |
|---|---|---|---|
| | | | |
