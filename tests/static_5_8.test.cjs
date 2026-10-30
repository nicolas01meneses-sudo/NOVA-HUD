// NOVA HUD 5.8 — pruebas estáticas, no pruebas de juego.
// Ejecutar desde la raíz: node tests/static_5_8.test.cjs
const fs = require('node:fs');
const assert = require('node:assert/strict');

const source = fs.readFileSync('NOVA_HUD_5_8_NEON.lua', 'utf8');
const loader = fs.readFileSync('NOVA_BOOT_5_8.lua', 'utf8');
const cases = [
  ['identidad 5.8', () => assert.match(source, /Name='NOVA_HUD_5_8_NEON'/)],
  ['5.7 preservada en limpieza', () => assert.match(source, /'NOVA_HUD_5_7_NEON','NOVA_HUD_5_8_NEON'/)],
  ['escaneo inicial activo', () => assert.match(source, /local function refresh\(\)\s*scanWorld\(\)/)],
  ['BUY detectado automáticamente', () => assert.match(source, /refreshOfficialRemoteBuy\(\) -- escaneo periódico/)],
  ['no muestra vínculo manual', () => assert.doesNotMatch(source, /VINCULAR BUY VERDE/)],
  ['no muestra banner azul', () => assert.doesNotMatch(source, /TOCA BUY VERDE/)],
  ['no conserva remoteBeginLink', () => assert.doesNotMatch(source, /remoteBeginLink/)],
  ['no emula clic por coordenadas', () => assert.doesNotMatch(source, /Toque por posición enviado/)],
  ['coordenadas denegadas', () => assert.match(source, /if coordinate then return false,'No se admiten posiciones/)],
  ['prueba deliberada preservada', () => assert.match(source, /NOVA_CORE.remoteSendOne\(true\)/)],
  ['confirmación exige contador', () => assert.match(source, /afterCount>pending.beforeCount/)],
  ['loader referencia nuevo archivo', () => assert.match(loader, /ui\/auto-scan-neon-5-8\/NOVA_HUD_5_8_NEON\.lua/)],
];
for (const [title, test] of cases) {
  test();
  console.log('PASS', title);
}
console.log(cases.length + ' pruebas estáticas superadas; aún faltan Luau, Studio y Android.');
