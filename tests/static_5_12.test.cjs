// NOVA 5.12: structural checks. A PASS does not imply Roblox runtime success.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync('NOVA_HUD_5_12_NEON.lua', 'utf8');
const loader = fs.readFileSync('NOVA_BOOT_5_12.lua', 'utf8');
const checks = [
  ['name 5.12', () => assert.match(source, /Name='NOVA_HUD_5_12_NEON'/)],
  ['removes older 5.11 GUI', () => assert.match(source, /'NOVA_HUD_5_11_NEON','NOVA_HUD_5_12_NEON'/)],
  ['loader points to 5.12 branch', () => assert.match(loader, /ui\/neon-5-12-stability\/NOVA_HUD_5_12_NEON\.lua/)],
  ['health state tracks three motors', () => {
    assert.match(source, /scanErrors=0,buyErrors=0,collectErrors=0/);
    assert.match(source, /scanStreak=0,buyStreak=0,collectStreak=0/);
  }],
  ['highlight diff retains unchanged markers', () => {
    assert.match(source, /local wanted=\{\}/);
    assert.match(source, /if not wanted\[part\] or not h or not h.Parent then/);
    assert.match(source, /for part in pairs\(wanted\) do/);
  }],
  ['no unconditional highlight reset during refresh', () => assert.doesNotMatch(source,/local function updateHighlights\(\)\s+clearHighlights\(\)/)],
  ['highlights capped at 22 per pass', () => assert.match(source,/if added<22 and part and part:IsDescendantOf\(Workspace\)/)],
  ['cleanup on reload', () => assert.match(source,/gui.Destroying:Connect\(function\(\)\s+running=false\s+clearHighlights\(\)/)],
  ['protected scan worker', () => assert.match(source,/local function safeRefresh\(\)/)],
  ['scan runs through pcall', () => assert.match(source,/local ok,err=pcall\(doRefresh\)/)],
  ['scan bounded retry', () => assert.match(source,/health.scanBackoffUntil=now\+math.min\(8/)],
  ['protected buy worker', () => assert.match(source,/local function safeRunAutoBuy\(\)/)],
  ['buy runs through pcall', () => assert.match(source,/local ok,err=pcall\(runAutoUpgrades\)/)],
  ['buy attempts stop after repeated runtime errors', () => assert.match(source,/if health.buyStreak>=3 then/)],
  ['pending buy cleared on repeated failures', () => assert.match(source,/state.autoStations=false\s+NOVA_CORE.buyPending=nil/)],
  ['collect scheduler still separate', () => assert.match(source,/local function runCollectionTick\(\)/)],
  ['collect worker uses protected callback', () => assert.match(source,/local ok,err=pcall\(runCollectionTick\)/)],
  ['collect backoff exists', () => assert.match(source,/health.collectStreak>0\s+and math.min\(5/)],
  ['collect errors stop collecting after repeated failures', () => assert.match(source,/if health.collectStreak>=4 then/)],
  ['collector stops all affected toggles', () => assert.match(source,/for _,key in ipairs\(\{'fruit','ice','cash'\}\) do/)],
  ['scan and buy errors visible', () => assert.match(source,/Errores: escaneo %d \| compra %d \| recoger %d/)],
  ['separate collection counts retained', () => assert.match(source,/collectCounters=\{fruit=0,ice=0,cash=0\}/)],
  ['workspacedescendants initial scan once', () => assert.equal((source.match(/Workspace:GetDescendants\(\)/g)||[]).length,1)],
  ['workspace listener cleanup retained', () => assert.match(source,/workspaceIndexAdded:Disconnect\(\)/)],
  ['normal buy survives', () => assert.match(source,/runAutoUpgrades=function\(\)/)],
  ['no active remote buy loop', () => assert.doesNotMatch(source,/^\s+NOVA_CORE\.runRemoteBuy\(\)\s*$/m)],
  ['protected initial scan', () => assert.match(source,/showPage\('World1'\)\s+detectWorld\(\)\s+safeRefresh\(\)/)],
  ['protected periodic scan', () => assert.match(source,/if os.clock\(\)-lastRefresh>\(buildActive and 1\.2 or \(state.ice and 2\.2 or 3\.5\)\) then safeRefresh\(\) end/)],
  ['protected purchase loop call', () => assert.match(source,/if buildActive then\s+safeRunAutoBuy\(\)\s+end/)],
  ['mobile drag bound retained', () => assert.match(source,/local safe=clampWindowCenter\(intended,viewport\)/)],
];
for(const [title,fn] of checks) { fn(); console.log('PASS',title) }
console.log(checks.length+' structural checks passed; in-game results unverified.');
