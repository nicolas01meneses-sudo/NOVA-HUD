// NOVA 5.12.2 — strict zone-order regressions (structural, not Roblox gameplay).
const fs=require('node:fs');
const assert=require('node:assert/strict');
const s=fs.readFileSync('NOVA_HUD_5_12_2_NEON.lua','utf8');
const boot=fs.readFileSync('NOVA_BOOT_5_12_2.lua','utf8');
const cases=[
 ['version 5.12.2',()=>assert.match(s,/Name='NOVA_HUD_5_12_2_NEON'/)],
 ['remove prior GUI 5.12.1',()=>assert.match(s,/'NOVA_HUD_5_12_1_NEON','NOVA_HUD_5_12_2_NEON'/)],
 ['diagnostic boot points to new file',()=>assert.match(boot,/fix\/strict-zone-order-5-12-2\/NOVA_HUD_5_12_2_NEON\.lua/)],
 ['Mars zone 1 is Oxygen Pump',()=>assert.match(s,/\[2\]=\{'Oxygen Pump','Fast O2','Oxygen Warehouse','Oxygen Center'/)],
 ['Earth zone 1 is Lemon Stand',()=>assert.match(s,/\[1\]=\{'Lemon Stand','LemonDash','Lemon Depot'/)],
 ['both worlds start in zone 1',()=>assert.match(s,/NOVA_CORE\.zoneStage=\{\[1\]=1,\[2\]=1\}/)],
 ['current zone queue ONLY',()=>assert.match(s,/local available=groups\[current\]/)],
 ['never loop through future zones',()=>assert.doesNotMatch(s,/for index=current\+1,#names do/)],
 ['no future zone considered as bought',()=>assert.doesNotMatch(s,/if chosen~=current then NOVA_CORE\.zoneStage\[world\]=chosen end/)],
 ['no cheap later zone used as starting anchor',()=>assert.doesNotMatch(s,/economicallyPlausible/)],
 ['starting anchor names first station',()=>assert.match(s,/local tokens=world==1 and \{'lemon stand','lemonstand','first stand'\}/)],
 ['starting anchor checks owner',()=>assert.match(s,/local owned=plotOwnedByPlayer\(part\)/)],
 ['starting anchor requires recognized starter name',()=>assert.match(s,/and hasAny\(padIdentity\(hit\),tokens\) then/)],
 ['ambiguity causes pause',()=>assert.match(s,/Varios puestos iniciales posibles; marca Zona 1 en Build/)],
 ['generic pads near starter match zone 1',()=>assert.match(s,/if start and \(part.Position-start\).Magnitude<=55 then return 1 end/)],
 ['explicit zones outrank generic near-start',()=>assert.match(s,/local known=NOVA_CORE\.explicitZone\(hit\)\s+if known then return known end/)],
 ['observed pads counted even without price',()=>assert.match(s,/zoneSeen\[zone\]=\(zoneSeen\[zone\] or 0\)\+1/)],
 ['zone with pads blocks forward progress',()=>assert.match(s,/if countCurrent>0 then[\s\S]*?return wallet,\{\}/)],
 ['insufficient wallet pauses zone',()=>assert.match(s,/why='saldo insuficiente'/)],
 ['cooldown pauses current zone',()=>assert.match(s,/why='esperando reintento'/)],
 ['no confirmed receipt means no advance',()=>assert.match(s,/local verified=NOVA_CORE\.zoneReceipts\[world\]\[current\] or 0/)],
 ['receipts indexed by world/zone',()=>assert.match(s,/NOVA_CORE\.zoneReceipts=\{\[1\]=\{\},\[2\]=\{\}\}/)],
 ['purchase pending carries zone',()=>assert.match(s,/label=cheapest.price.label,mode=mode,world=world,zone=cheapest.zone/)],
 ['receipt added only for current build zone',()=>assert.match(s,/if pending.mode=='build' and pending.world and pending.zone\s+and pending.zone==NOVA_CORE.zoneStage\[pending.world\]/)],
 ['probable (disappeared) not treated as receipt',()=>assert.match(s,/elseif vanished or hidden then[\s\S]*?compra probable, sin confirmar/)],
 ['requires three full scans',()=>assert.match(s,/NOVA_CORE\.zoneRequiredClearScans=3/)],
 ['world scan has revision number',()=>assert.match(s,/NOVA_CORE\.scanRevision\+=1/)],
 ['same snapshot cannot count twice',()=>assert.match(s,/zoneEmptyLastScan\[world\]\[current\]~=NOVA_CORE.scanRevision/)],
 ['auto advances exactly one zone',()=>assert.match(s,/NOVA_CORE\.zoneStage\[world\]=current\+1/)],
 ['manual advance two taps in eight seconds',()=>assert.match(s,/or now-advanceArmedAt>8 then/)],
 ['manual confirm button present',()=>assert.match(s,/ZONA TERMINADA → AVANZAR UNA/)],
 ['manual anchor explicitly labels zone one',()=>assert.match(s,/MARCAR INICIO AQUÍ \(ZONA 1\)/)],
 ['reset button clears evidence',()=>assert.match(s,/NOVA_CORE\.zoneReceipts\[world\]=\{\}/)],
 ['BUY status reports blocker',()=>assert.match(s,/showBatchStatus\(NOVA_CORE.zoneStatus\)/)],
 ['keeps Android top drag fix',()=>assert.match(s,/local minY=halfHeight-topOverlap/)],
 ['keeps collector loop',()=>assert.match(s,/local function runCollectionTick\(\)/)],
 ['keeps buy error protection',()=>assert.match(s,/local function safeRunAutoBuy\(\)/)],
 ['no active remote buy scheduler',()=>assert.doesNotMatch(s,/^\s+NOVA_CORE\.runRemoteBuy\(\)\s*$/m)],
];
for(const [name,test] of cases){test();console.log('PASS',name)}
console.log(cases.length+' static regressions passed. Roblox gameplay NOT tested.');
