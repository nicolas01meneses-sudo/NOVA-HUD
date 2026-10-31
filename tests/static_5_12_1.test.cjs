// NOVA 5.12.1 — mobile position regression, structural + geometry.
const fs=require('node:fs');
const assert=require('node:assert/strict');
const hud=fs.readFileSync('NOVA_HUD_5_12_1_NEON.lua','utf8');
const loader=fs.readFileSync('NOVA_BOOT_5_12_1.lua','utf8');
const checks=[
  ['new HUD version',()=>assert.match(hud,/Name='NOVA_HUD_5_12_1_NEON'/)],
  ['prior HUD removed on load',()=>assert.match(hud,/'NOVA_HUD_5_12_NEON','NOVA_HUD_5_12_1_NEON'/)],
  ['loader points to new branch',()=>assert.match(loader,/fix\/mobile-hud-top-drag-5-12-1\/NOVA_HUD_5_12_1_NEON\.lua/)],
  ['no artificial upper 58px barrier',()=>assert.doesNotMatch(hud,/local minY=halfHeight\+58/)],
  ['scaled header dimension',()=>assert.match(hud,/local headerHeight=73\*scale.Scale/)],
  ['visible header floor',()=>assert.match(hud,/local visibleHeader=math.min\(headerHeight,math.max\(12,headerHeight\*\.65\)\)/)],
  ['allow header overlap at top',()=>assert.match(hud,/local minY=halfHeight-topOverlap/)],
  ['bottom clamp remains',()=>assert.match(hud,/local maxY=viewport.Y-halfHeight-12/)],
  ['oversized HUD still draggable',()=>assert.match(hud,/maxY=minY\+math.min\(math.max\(24,headerHeight\*\.5\),viewport.Y\*\.18\)/)],
  ['viewport guard',()=>assert.match(hud,/if viewport.X<64 or viewport.Y<64 then return point end/)],
  ['touch drag uses updated clamp',()=>assert.match(hud,/local safe=clampWindowCenter\(intended,viewport\)/)],
  ['orientation changes use updated clamp',()=>assert.match(hud,/local safe=clampWindowCenter\(center,vp\)/)],
  ['floating restore remains',()=>assert.match(hud,/restore.MouseButton1Click:Connect/)],
  ['NOVA 5.12 collection engine preserved',()=>assert.match(hud,/local function runCollectionTick\(\)/)],
  ['NOVA 5.12 buy engine preserved',()=>assert.match(hud,/local function safeRunAutoBuy\(\)/)],
  ['mobile help text updated',()=>assert.match(hud,/Arrastra desde la barra NOVA hasta el borde superior/)],
];
// Independent arithmetic model of the visible Luau clamp constants.
// This validates UX constraints for representative viewports; it is not Roblox UI testing.
function bounds(w,h,pct) {
  const scale=Math.max(.05,Math.min((w-32)/1180,(h-158)/550))*pct/100;
  const halfHeight=275*scale;
  const headerHeight=73*scale;
  const visibleHeader=Math.min(headerHeight,Math.max(12,headerHeight*.65));
  const topOverlap=headerHeight-visibleHeader;
  const minY=halfHeight-topOverlap;
  let maxY=h-halfHeight-12;
  if (maxY<minY) maxY=minY+Math.min(Math.max(24,headerHeight*.5),h*.18);
  return {scale,halfHeight,headerHeight,visibleHeader,minY,maxY,top:minY-halfHeight};
}
for(const [label,w,h,pct] of [
 ['landscape HD 100%',2772,1280,100],
 ['landscape HD 110%',2772,1280,110],
 ['landscape HD 150%',2772,1280,150],
 ['smaller Android landscape 100%',1280,720,100],
 ['smaller Android landscape 110%',1280,720,110],
 ['smaller Android landscape 150%',1280,720,150],
 ['portrait 100%',720,1280,100],
 ['portrait 150%',720,1280,150]
]){
 checks.push([label+' top freedom',()=>{
    const b=bounds(w,h,pct);
    assert.ok(b.top<=0,'top bound should be near/above viewport edge: '+JSON.stringify(b));
    assert.ok(b.top >= -(b.headerHeight-b.visibleHeader)-1e-6,'header too far out');
    assert.ok(b.maxY>b.minY,'window should be vertically draggable: '+JSON.stringify(b));
    assert.ok(b.visibleHeader>=b.headerHeight*.65-1e-7,'not enough title bar visible');
 }]);
}
for(const [name,check] of checks){check();console.log('PASS',name)}
console.log(checks.length+' structural/geometry tests passed. Real Roblox touch test remains pending.');
