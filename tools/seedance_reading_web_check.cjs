/* Run after flutter build web, with APP_URL pointing to the served build. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
(async()=>{
  const out=path.resolve('docs/verification/seedance-reading');
  const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
  try {
    const page=await browser.newPage({viewport:{width:430,height:932}});
    const errors=[],automaticAudio=[];
    page.on('pageerror',e=>errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error'&&/Exception|RenderFlex|overflow|Assertion failed/.test(m.text()))errors.push(m.text());});
    page.on('request',r=>{if(r.url().includes('/sounds/'))automaticAudio.push(r.url());});
    await page.addInitScript(()=>localStorage.setItem('littlewins.state.v1',JSON.stringify(JSON.stringify({version:1,onboarded:true,locale:'en',sound:true,reading:{completed:{},positions:{},spentCoins:0},wallet:{},batchProgress:{}}))));
    await page.goto(process.env.APP_URL || 'http://127.0.0.1:7359');
    await page.locator('video').waitFor();
    await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
    await page.getByText('The Frog Prince',{exact:true}).waitFor();
    await page.waitForTimeout(1000);
    const state=await page.evaluate(()=>localStorage.getItem('littlewins.state.v1'));
    const setup=await page.locator('video').evaluate(v=>{
      window.readingClip=v;window.loopCount=0;let last=v.currentTime;
      v.addEventListener('timeupdate',()=>{if(v.currentTime<last-1)window.loopCount++;last=v.currentTime;});
      window.startQuality=v.getVideoPlaybackQuality();
      return {duration:v.duration,width:v.videoWidth,height:v.videoHeight,muted:v.muted,loop:v.loop,paused:v.paused};
    });
    assert.equal(setup.duration,5);assert(setup.muted&&setup.loop&&!setup.paused);
    // No screenshots during this uninterrupted playback sample.
    await page.waitForTimeout(11500);
    const playback=await page.evaluate(()=>{const v=window.readingClip,q=v.getVideoPlaybackQuality(),s=window.startQuality;
      return {loops:window.loopCount,frames:q.totalVideoFrames-s.totalVideoFrames,droppedFrames:q.droppedVideoFrames-s.droppedVideoFrames,error:v.error?.message??null,paused:v.paused};});
    assert(playback.loops>=2);assert(playback.frames>=260);assert(playback.droppedFrames<=2);assert.equal(playback.error,null);
    assert.equal(automaticAudio.length,0);
    for(const width of [320,430,1365]){
      await page.setViewportSize({width,height:932});
      await page.waitForFunction(()=>{const v=document.querySelector('video');return v&&v.currentTime>2.7&&v.currentTime<3.1;});
      await page.screenshot({path:path.join(out,`home-${width}.png`)});
    }
    assert.equal(await page.evaluate(()=>localStorage.getItem('littlewins.state.v1')),state);
    await page.setViewportSize({width:430,height:932});
    await page.emulateMedia({reducedMotion:'reduce'});
    await page.waitForFunction(()=>window.readingClip.paused);
    await page.waitForTimeout(500);
    const still=await page.screenshot({path:path.join(out,'home-reduced-motion.png')});
    await page.waitForTimeout(5200);
    assert(still.equals(await page.screenshot()),'Reduced-motion artwork changed');
    await page.emulateMedia({reducedMotion:'no-preference'});
    await page.waitForFunction(()=>document.querySelector('video')&&!document.querySelector('video').paused);
    await page.getByRole('tab',{name:'Books',exact:true}).click();
    await page.waitForTimeout(500);
    assert(await page.evaluate(()=>!document.querySelector('video')||document.querySelector('video').paused),'Hidden Home is still playing');
    await page.getByRole('tab',{name:'Home',exact:true}).click();
    await page.waitForFunction(()=>document.querySelector('video')&&!document.querySelector('video').paused);
    assert.equal(await page.locator('video').count(),1);
    assert.deepEqual(errors,[]);
    const report={passed:true,setup,playback,reducedMotion:'unchanged for 5.2 seconds',navigation:'pauses away from Home and resumes on return',widths:[320,430,1365],errors};
    fs.writeFileSync(path.join(out,'flutter-web-checks.json'),JSON.stringify(report,null,2)+'\n');
    console.log(JSON.stringify(report,null,2));
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
