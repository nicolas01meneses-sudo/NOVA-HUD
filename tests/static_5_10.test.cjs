// NOVA 5.10 — checks de regresión estructural (no gameplay).
const fs = require('node:fs');
const assert = require('node:assert/strict');
const src = fs.readFileSync('NOVA_HUD_5_10_NEON.lua','utf8');
const boot = fs.readFileSync('NOVA_BOOT_5_10.lua','utf8');
const cases = [
 ['versión nueva',()=>assert.match(src,/Name='NOVA_HUD_5_10_NEON'/)],
 ['limpieza de 5.9',()=>assert.match(src,/'NOVA_HUD_5_9_NEON','NOVA_HUD_5_10_NEON'/)],
 ['cargador rama 5.10',()=>assert.match(boot,/ui\/normal-auto-buy-5-10\/NOVA_HUD_5_10_NEON\.lua/)],
 ['sin panel de Compra Remota oficial',()=>assert.doesNotMatch(src,/COMPRA REMOTA OFICIAL/)],
 ['sin switch de compra remota',()=>assert.doesNotMatch(src,/toggle\([^\n]*'remoteBuy'\)/)],
 ['compra normal declarada',()=>assert.match(src,/COMPRA NORMAL \/ SIN PODER/)],
 ['botón Tierra vinculado',()=>assert.match(src,/buildActionButtons,\{button=buildWorld1,world=1,style='build'\}/)],
 ['botón Marte vinculado',()=>assert.match(src,/buildActionButtons,\{button=buildWorld2,world=2,style='build'\}/)],
 ['controlador de compra común',()=>assert.match(src,/NOVA_CORE\.setBuildMode=function\(world,enabled\)/)],
 ['switch sincronizado',()=>assert.match(src,/NOVA_CORE\.setBuildMode\(entry\.world,not state\[key\]\)/)],
 ['no ejecuta bucle de compra remota',()=>assert.doesNotMatch(src,/^\s+NOVA_CORE\.runRemoteBuy\(\)\s*$/m)],
 ['no refresca BUY oficial',()=>assert.doesNotMatch(src,/^\s+refreshOfficialRemoteBuy\(\)\s*$/m)],
 ['recogida de limones independiente',()=>assert.match(src,/toggle\(buildCollect,'Recoger limones cerca \(Tierra\)','fruit'\)/)],
 ['recogida de hielo independiente',()=>assert.match(src,/toggle\(buildCollect,'Recoger hielo cerca \(Marte\)','ice'\)/)],
 ['sin filtros por color',()=>assert.match(src,/PADS: %d \| BOTONES UI: %d \(sin filtro de color\)/)],
 ['confirmaciones siguen separadas',()=>assert.match(src,/NOVA_CORE\.buyVerified/)],
 ['compra física existente',()=>assert.match(src,/runAutoUpgrades=function\(\)/)],
 ['ejecución de compra normal',()=>assert.match(src,/if buildActive then\s+runAutoUpgrades\(\)\s+end/)],
 ['recolección sigue en bucle principal',()=>assert.match(src,/\{key='fruit',bucket='fruit'\}/)],
 ['poder oficial no se exige',()=>assert.match(src,/No utiliza Remote Buy oficial ni compra poderes/)],
];
for(const [name,run] of cases){run();console.log('PASS',name)}
console.log(cases.length+' comprobaciones estáticas superadas. Runtime sin verificar.');
