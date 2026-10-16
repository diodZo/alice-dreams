import Phaser from 'phaser';
import { createGameConfig } from './config/gameConfig.js';

const game = new Phaser.Game(createGameConfig());

// Acceso desde la consola del navegador para depurar o automatizar pruebas
// (sólo con ?debug=1 o ?test=1 en la URL).
const params = new URLSearchParams(window.location.search);
if (params.has('debug') || params.has('test')) {
  window.__GAME__ = game;
}
