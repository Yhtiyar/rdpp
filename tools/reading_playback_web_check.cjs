/* Warmed, uninterrupted release playback; run after flutter build web. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
(async()=>{
 const out=path.resolve('docs/verification/home-page-turn');
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try {
  const page=await browser.newPage({viewport:{width:430,height:932}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>localStorage.setItem('littlewins.state.v1',JSON.stringify(JSON.stringify({version:1,onboarded:true,locale:'en',sound:true,reading:{completed:{},positions:{},spentCoins:0},wallet:{},batchProgress:{}}))));
  await page.goto(process.env.APP_URL || 'http://127.0.0.1:7357');
  await page.waitForFunction(()=>document.querySelector('flt-semantics-placeholder'));
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
  await page.getByText('The Frog Prince',{exact:true}).waitFor();
  const metrics={};
  for(const mode of ['reduce','no-preference']){
   await page.emulateMedia({reducedMotion:mode});await page.waitForTimeout(5500);
   metrics[mode]=await page.evaluate(()=>new Promise(resolve=>{
    let last,start;const intervals=[];
    function tick(t){
     if(start===undefined)start=t;if(last!==undefined)intervals.push(t-last);last=t;
     if(t-start<10500)requestAnimationFrame(tick);
     else {const sorted=[...intervals].sort((a,b)=>a-b);resolve({fps:intervals.length*1000/(t-start),medianMs:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],maximumMs:Math.max(...intervals),frames:intervals.length,durationMs:t-start});}
    }requestAnimationFrame(tick);
   }));
  }
  for(const width of [320,430,1365]){
   await page.setViewportSize({width,height:932});await page.waitForTimeout(400);
   await page.screenshot({path:path.join(out,`animated-${width}-a.png`)});
   await page.waitForTimeout(2450);
   await page.screenshot({path:path.join(out,`animated-${width}-b.png`)});
  }
  const renderer=await page.evaluate(()=>{
   const gl=document.createElement('canvas').getContext('webgl');
   const info=gl?.getExtension('WEBGL_debug_renderer_info');
   return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : 'unavailable';
  });
  assert.deepEqual(errors,[]);
  const report={renderer,metrics,errors,note:'Browser scheduling measured without screenshots or video during the sample. Software rendering is not a physical-device benchmark.'};
  fs.writeFileSync(path.join(out,'playback.json'),JSON.stringify(report,null,2));console.log(report);
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
