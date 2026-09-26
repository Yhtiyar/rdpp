/* Verify the five-second Home book animation against a built Flutter web app. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const output=path.resolve(__dirname,'../docs/verification/home-page-turn');
(async()=>{
 fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:430,height:932},deviceScaleFactor:1,recordVideo:{dir:path.join(output,'recordings'),size:{width:430,height:932}}});
 const page=await context.newPage(),errors=[],audio=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&/Exception|RenderFlex|overflow/.test(m.text()))errors.push(m.text());});
 page.on('request',r=>{if(r.url().includes('/sounds/'))audio.push(r.url());});
 await page.addInitScript(()=>localStorage.setItem('littlewins.state.v1',JSON.stringify(JSON.stringify({version:1,onboarded:true,locale:'en',sound:true,reading:{completed:{},positions:{},spentCoins:0},wallet:{},batchProgress:{}}))));
 await page.goto(process.env.APP_URL||'http://127.0.0.1:7357');
 await page.waitForFunction(()=>document.querySelector('flutter-view'));
 await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 await page.getByText('The Frog Prince',{exact:true}).waitFor();await page.waitForTimeout(700);
 const beforeState=await page.evaluate(()=>localStorage.getItem('littlewins.state.v1'));
 const baseline=await page.screenshot({path:path.join(output,'idle.png')});
 await page.screenshot({path:path.join(output,'home-430.png')});
 const samples=[],started=Date.now();let savedFrames=0;
 while(Date.now()-started<12000){
  const capture=await page.screenshot();
  const changed=!capture.equals(baseline),ms=Date.now()-started;
  samples.push({ms,changed});
  if(changed && savedFrames<2){fs.writeFileSync(path.join(output,savedFrames===0?'page-lifting.png':'page-turning.png'),capture);savedFrames++;}
  await page.waitForTimeout(80);
 }
 const runs=[];for(let i=0;i<samples.length;i++)if(samples[i].changed&&(i===0||!samples[i-1].changed))runs.push(samples[i].ms);
 assert(runs.length>=2,`Expected two page turns; got ${JSON.stringify(runs)}`);
 assert(Math.abs((runs[1]-runs[0])-5000)<500,`Page turns did not repeat every five seconds: ${runs}`);
 assert(samples.filter(s=>!s.changed).length>samples.length*.7,'Artwork did not settle between page turns');
 assert.equal(await page.evaluate(()=>localStorage.getItem('littlewins.state.v1')),beforeState,'Decorative animation changed saved reading state');
 await page.emulateMedia({reducedMotion:'reduce'});await page.waitForTimeout(400);
 const reduced=await page.screenshot();await page.waitForTimeout(6100);assert(reduced.equals(await page.screenshot()),'Reduced motion animated');
 await page.screenshot({path:path.join(output,'reduced-motion.png')});
 for(const size of [{width:320,height:640},{width:1365,height:900}]){await page.setViewportSize(size);await page.waitForTimeout(400);await page.screenshot({path:path.join(output,`home-${size.width}.png`)});}
 assert.equal(audio.length,0,'Idle page turns played audio');assert.deepEqual(errors,[]);
 const report={passed:true,observedPageTurnStartsMs:runs,intervalMs:runs[1]-runs[0],samples,checks:['welcome artwork on Home','two turns five seconds apart','steady illustration between turns','no reading-state changes','reduced motion remains still','320px and desktop layouts','silent page turns','no browser errors'],errors};
 fs.writeFileSync(path.join(output,'checks.json'),JSON.stringify(report,null,2));
 await context.close();fs.renameSync(await page.video().path(),path.join(output,'home-page-turn.webm'));await browser.close();
 console.log(JSON.stringify({...report,samples:`${samples.length} samples`},null,2));
})().catch(e=>{console.error(e);process.exit(1);});
