// NOVA HUD 5.9 — verificaciones estáticas de regresión (Node.js 22+).
// Comando: node tests/static_5_9.test.cjs
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync('NOVA_HUD_5_9_NEON.lua', 'utf8');
const loader = fs.readFileSync('NOVA_BOOT_5_9.lua', 'utf8');
const cases = [
  ['identidad 5.9', () => assert.match(source, /Name='NOVA_HUD_5_9_NEON'/)],
  ['limpieza de GUI 5.8 preservada', () => assert.match(source, /'NOVA_HUD_5_8_NEON','NOVA_HUD_5_9_NEON'/)],
  ['loader dirige a la rama aislada', () => assert.match(loader, /ui\/neon-5-9-mobile-diagnostics\/NOVA_HUD_5_9_NEON\.lua/)],
  ['lector de mundo conservado', () => assert.match(source, /local function scanWorld\(\)/)],
  ['fruta y upgrades conservados', () => {
    assert.match(source, /key='fruit',bucket='fruit'/);
    assert.match(source, /runAutoUpgrades\(\)/);
  }],
  ['diagnóstico diferenciado de botones', () => assert.match(source, /ESCANEO SIN COLOR \| pads: %d \| botones UI: %d/)],
  ['el detector cuenta BUY ambiguos', () => {
    assert.match(source, /local function findOfficialRemoteBuy\(\)/);
    assert.match(source, /if count~=1 then return nil,count end/);
  }],
  ['sin filtro por color para GUI', () => assert.match(source, /No filtramos por color/)],
  ['detección por identidad de instancia', () => assert.match(source, /if obj~=lastRemoteDetection or mode~=lastRemoteMode then/)],
  ['no usa ruta como identidad de objeto', () => assert.doesNotMatch(source, /obj:GetFullName\(\) or 'none'/)],
  ['detector informa ambigüedad', () => assert.match(source, /Varios BUY visibles: no se elige uno automáticamente/)],
  ['control no reutiliza coordenadas', () => assert.match(source, /local coordinate=nil\s*if not button then/)],
  ['sin botón manual de vinculación', () => assert.doesNotMatch(source, /VINCULAR BUY VERDE/)],
  ['sin banner de vinculación', () => assert.doesNotMatch(source, /TOCA BUY VERDE/)],
  ['limita HUD durante arrastre', () => assert.match(source, /local safe=clampWindowCenter\(intended,viewport\)/)],
  ['limita HUD al rotar', () => assert.match(source, /local safe=clampWindowCenter\(center,vp\)/)],
  ['no confunde controles con compras', () => assert.match(source, /Permiso y compra sin verificar/)],
  ['contador explícito preservado', () => assert.match(source, /afterCount>pending.beforeCount/)],
];
for (const [name, fn] of cases) {
  fn();
  console.log('PASS', name);
}
console.log(cases.length + ' pruebas estáticas completadas. No comprueban motor Luau ni gameplay.');
