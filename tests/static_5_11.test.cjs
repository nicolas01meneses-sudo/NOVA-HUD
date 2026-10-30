// NOVA 5.11 — static checks only. Runtime game behavior is not verified.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const src = fs.readFileSync('NOVA_HUD_5_11_NEON.lua', 'utf8');
const loader = fs.readFileSync('NOVA_BOOT_5_11.lua', 'utf8');
const checks = [
 ['version 5.11', () => assert.match(src,/Name='NOVA_HUD_5_11_NEON'/)],
 ['previous version cleanup', () => assert.match(src,/'NOVA_HUD_5_10_NEON','NOVA_HUD_5_11_NEON'/)],
 ['loader URL on 5.11 branch', () => assert.match(loader,/ui\/neon-5-11-independent-engines\/NOVA_HUD_5_11_NEON\.lua/)],
 ['only one initial world tree traversal', () => assert.equal((src.match(/Workspace:GetDescendants\(\)/g)||[]).length,1)],
 ['world interaction index', () => assert.match(src,/local workspaceInteractionIndex=\{\}/)],
 ['world GUI index', () => assert.match(src,/local workspaceGuiIndex=\{\}/)],
 ['incremental add', () => assert.match(src,/Workspace\.DescendantAdded:Connect\(trackWorkspaceObject\)/)],
 ['incremental remove', () => assert.match(src,/Workspace\.DescendantRemoving:Connect\(function\(obj\)/)],
 ['listeners disconnected on UI destruction', () => {
    assert.match(src,/workspaceIndexAdded:Disconnect\(\)/);
    assert.match(src,/workspaceIndexRemoved:Disconnect\(\)/);
 }],
 ['indexed GUI scan', () => assert.match(src,/workspaceGuiCandidates\(\) or playerGui:GetDescendants\(\)/)],
 ['classify after proximity', () => assert.match(src,/if center and part and \(part.Position-center\).Magnitude<=radius then\s+local category=classify\(obj\)/)],
 ['collection worker', () => assert.match(src,/local function runCollectionTick\(\)/)],
 ['collector runs with protected callback', () => assert.match(src,/pcall\(runCollectionTick\)/)],
 ['collectors have separate schedule', () => assert.match(src,/task.wait\(state.ice and \.22 or \(\(state.fruit or state.cash\) and \.35 or \.8\)\)/)],
 ['purchase loop still runs', () => assert.match(src,/if buildActive then\s+runAutoUpgrades\(\)\s+end/)],
 ['fruit still included', () => assert.match(src, /\{key='fruit',bucket='fruit'\}/)],
 ['cash still included', () => assert.match(src, /\{key='cash',bucket='cash'\}/)],
 ['ice still included', () => assert.match(src, /\{key='ice',bucket='ice'\}/)],
 ['separate attempt counters', () => assert.match(src, /collectCounters=\{fruit=0,ice=0,cash=0\}/)],
 ['honest evidence labels', () => assert.match(src,/Los intentos no prueban recompensas/)],
 ['no official RemoteBuy toggle', () => assert.doesNotMatch(src,/toggle\([^\n]*'remoteBuy'\)/)],
 ['no official RemoteBuy loop invocation', () => assert.doesNotMatch(src,/^\s+NOVA_CORE\.runRemoteBuy\(\)\s*$/m)],
 ['legacy buy controller present', () => assert.match(src,/NOVA_CORE\.setBuildMode=function\(world,enabled\)/)],
 ['mobile viewport bounds retained', () => assert.match(src,/local safe=clampWindowCenter\(intended,viewport\)/)],
];
for (const [title, run] of checks) {
    run();
    console.log('PASS', title);
}
console.log(checks.length+' tests passed. This is NOT validation in Roblox.');
