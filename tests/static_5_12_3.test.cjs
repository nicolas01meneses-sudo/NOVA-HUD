// NOVA 5.12.3: checks + live parser harness using production Luau source.
// Structural checks do NOT establish Roblox gameplay behavior.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const src = fs.readFileSync('NOVA_HUD_5_12_3_NEON.lua','utf8');
const boot = fs.readFileSync('NOVA_BOOT_5_12_3.lua','utf8');
const checks = [
 ['version 5.12.3',()=>assert.match(src,/Name='NOVA_HUD_5_12_3_NEON'/)],
 ['previous 5.12.2 cleanup',()=>assert.match(src,/'NOVA_HUD_5_12_2_NEON','NOVA_HUD_5_12_3_NEON'/)],
 ['new loader',()=>assert.match(boot,/fix\/wallet-large-units-5-12-3\/NOVA_HUD_5_12_3_NEON\.lua/)],
 ['only one wallet parser',()=>assert.equal((src.match(/local function amountFromText\(t\)/g)||[]).length,1)],
 ['only one wallet scanner',()=>assert.equal((src.match(/local function walletMoney\(\)/g)||[]).length,1)],
 ['only one normal auto-build scheduler',()=>assert.equal((src.match(/task\.wait\(buildActive and \.30 or \.7\)/g)||[]).length,1)],
 ['file ends at scheduler',()=>assert.match(src,/task\.wait\(buildActive and \.30 or \.7\)\s+end\s+end\)\s*$/)],
 ['Spanish number suffix mapping generated',()=>assert.match(src,/moneyUnits\[word\.\.'illón'\]=rank/)],
 ['English number suffix mapping generated',()=>assert.match(src,/moneyUnits\[word\.\.'illion'\]=rank/)],
 ['novem base for 29th illion',()=>assert.match(src,/\[9\]=\{'novem','noven'\}/)],
 ['vigint base for twentieth group',()=>assert.match(src,/\{base=20,stems=\{'vigint'\}\}/)],
 ['numerical rank formula',()=>assert.match(src,/local rank=ten\.base\+unit\+1/)],
 ['reject unknown currency unit',()=>assert.match(src,/if not rank then return nil end/)],
 ['currency lookup world-specific',()=>assert.match(src,/NOVA_CORE\.detectedWorld==2 and 'Φ' or '\$'/)],
 ['strict zone order intact',()=>assert.match(src,/local available=groups\[current\]/)],
 ['no jumping to any later zone',()=>assert.doesNotMatch(src,/for index=current\+1,#names do/)],
 ['source has no malformed string replacement',()=>assert.doesNotMatch(src,/gsub\('\[%p\]\+\s*\n/)],
 ['collector retained',()=>assert.match(src,/local function runCollectionTick\(\)/)],
 ['Android drag fix retained',()=>assert.match(src,/local minY=halfHeight-topOverlap/)],
];
for(const [name,test] of checks){test();console.log('PASS',name)}
console.log(checks.length+' structural checks passed.');
// Generate a Luau test using the parser copied directly out of the released HUD.
// Avoid a duplicate, independently-maintained implementation of the money parser.
const start=src.indexOf('local moneyUnits={');
const end=src.indexOf('local function walletMoney()',start);
assert.ok(start>0 && end>start,'Cannot locate currency parser section');
const parser=src.slice(start,end);
const script=[
 'local NOVA_CORE={detectedWorld=2}',
 parser,
 'local p=amountFromText("Φ254.847 novemvigintillón")',
 'assert(p~=nil and p.rank==30, "novemvigintillón rank must be 30")',
 'assert(math.abs(p.n-254.847)<0.00001, "number should remain 254.847")',
 'assert(amountFromText("Φ10 novemvigintillion").rank==30)',
 'assert(amountFromText("Φ5 octovigintillón").rank==29)',
 'assert(amountFromText("Φ1 trigintillón").rank==31)',
 'assert(amountFromText("Φ1 septemvigintillón").rank==28)',
 'assert(amountFromText("Φ1 novemvigintillones").rank==30)',
 'assert(amountFromText("Φ500 unidad-inventada")==nil)',
 'assert(cheaper(amountFromText("Φ1 octovigintillón"),p))',
 'assert(not cheaper(p,amountFromText("Φ1 octovigintillón")))',
 'NOVA_CORE.detectedWorld=1',
 'assert(amountFromText("$20 novemvigintillón").rank==30)',
 'assert(amountFromText("Φ20 novemvigintillón")==nil)',
 'print("PASS: 12 live Luau wallet parsing assertions")',
].join('\n');
if(!process.argv[2]){
 console.log('Lua runner not supplied: production-source harness prepared, but not executed.');
 process.exit(0);
}
const tempfile=path.join(process.cwd(),'tests','.wallet_5_12_3_generated.luau');
try{
 fs.writeFileSync(tempfile,script);
 const run=spawnSync(process.argv[2],[tempfile],{encoding:'utf8',timeout:30000});
 process.stdout.write(run.stdout||'');
 process.stderr.write(run.stderr||'');
 assert.equal(run.status,0,'Luau wallet parser runtime assertions failed');
}finally{
 if(fs.existsSync(tempfile))fs.unlinkSync(tempfile);
}
