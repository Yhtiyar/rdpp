/* Release Flutter web checks using real MP3 playback (8x only in this harness). */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');
const out=path.join(root,'docs/verification/toddler-books');
const url=process.env.APP_URL||'http://127.0.0.1:7358';
const books=JSON.parse(fs.readFileSync(path.join(root,'assets/toddler/catalog.json'))).filter(b=>['frog','kolobok'].includes(b.id));
const clips=Object.keys(JSON.parse(fs.readFileSync(path.join(root,'assets/toddler/audio_manifest.json'))));
const errors=[],checks=[],external=[];
let browser,page;
async function shot(name){await page.screenshot({path:path.join(out,name+'.png')});}
async function enable(){await page.waitForFunction(()=>document.querySelector('flutter-view'));await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
async function saved(id){return page.evaluate(id=>{const s=localStorage.getItem('littlewins.listening.v1');return s?JSON.parse(JSON.parse(s))[id]:null;},id);}
async function waitState(id,predicate){for(let i=0;i<300;i++){const s=await saved(id);if(s&&predicate(s))return s;await page.waitForTimeout(100);}throw new Error('Timed out waiting for '+id+' state: '+JSON.stringify(await saved(id)));}
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:430,height:932},deviceScaleFactor:1});
 await context.route('**/*',r=>{const u=new URL(r.request().url());if(!['127.0.0.1','localhost'].includes(u.hostname)){external.push(u.href);return r.abort();}return r.continue();});
 page=await context.newPage();
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&/Exception|RenderFlex|overflow|Error/.test(m.text()))errors.push(m.text());});
 await page.addInitScript(()=>{
  if(!localStorage.getItem('littlewins.state.v1'))localStorage.setItem('littlewins.state.v1',JSON.stringify(JSON.stringify({version:1,onboarded:true,locale:'en',age:4,sound:false,reading:{completed:{},spentCoins:0,positions:{}},wallet:{}})));
  window.__rate=8;window.__media=[];window.__ended=0;window.__blockAudio=false;
  const play=HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play=function(){if(window.__blockAudio)return Promise.reject(new DOMException('Autoplay test','NotAllowedError'));this.playbackRate=window.__rate;window.__media.push(this);this.addEventListener('ended',()=>window.__ended++,{once:true});return play.call(this);};
 });
 await page.goto(url);await enable();
 await page.getByText('Listen & play',{exact:true}).click();
 await page.getByRole('button',{name:'Pause story',exact:false}).waitFor();
 await page.getByRole('button',{name:'Pause story',exact:false}).click();
 await page.getByRole('button',{name:'Play story',exact:false}).waitFor();
 assert.equal(await page.getByRole('button',{name:'Next page',exact:true}).getAttribute('aria-disabled'),'true');
 await shot('01-frog-page-430');
 await page.setViewportSize({width:320,height:568});await page.waitForTimeout(200);await shot('02-frog-page-320');
 await page.setViewportSize({width:1365,height:900});await page.waitForTimeout(200);await shot('03-frog-page-desktop');
 await page.setViewportSize({width:430,height:932});
 await page.getByRole('button',{name:'Play story',exact:false}).click();
 await waitState('frog',s=>s.positionMs>0);await page.getByRole('button',{name:'Pause story',exact:false}).click();
 const paused=await waitState('frog',s=>s.positionMs>0);await page.getByRole('button',{name:'Close story',exact:true}).click();
 await page.getByText('Listen & play',{exact:true}).click();
 await page.getByRole('button',{name:'Play story',exact:false}).waitFor();
 assert.equal((await saved('frog')).positionMs,paused.positionMs);checks.push('pause and reopen preserves position without autoplay');
 await page.getByRole('button',{name:'Play story',exact:false}).click();
 for(const book of books){
  if(book.id==='kolobok'){
   await page.getByText('Back to my books',{exact:true}).click();
   await page.getByText('Explore my books',{exact:true}).click();
   await page.getByRole('button',{name:'Russian books',exact:true}).click();
   await page.getByText('Listen & play',{exact:true}).first().click();
   await page.getByRole('button',{name:'Пауза',exact:false}).waitFor();
   await page.getByRole('button',{name:'Пауза',exact:false}).click();await shot('07-kolobok-page');
   await page.getByRole('button',{name:'Играть',exact:false}).click();
  }
  for(let i=0;i<book.questions.length;i++){
   const q=book.questions[i];await page.getByText(q.prompt,{exact:true}).waitFor({timeout:60000});
   const choice=page.getByRole('button',{name:q.choices[q.answer].label,exact:true});
   await waitState(book.id,s=>s.phase==='question'&&s.question===i&&s.promptHeard);
   if(i===0){
    if(book.id==='frog'){
     const wrong=page.getByRole('button',{name:q.choices[1-q.answer].label,exact:true});
     await wrong.click();await waitState(book.id,s=>s.attempts===1&&s.promptHeard);
     await shot('04-frog-hint');
     await wrong.click();await waitState(book.id,s=>s.attempts===2&&s.promptHeard);
     await shot('05-frog-guided');
     await page.setViewportSize({width:320,height:568});await shot('06-frog-question-320');await page.setViewportSize({width:430,height:932});
     checks.push('two incorrect picture taps lead to spoken hint then guided answer');
    }else await shot('08-kolobok-question');
   }
   await choice.click();
  }
  await page.getByText(book.id==='frog'?'Story star collected':'Звёздочка за сказку получена',{exact:true}).waitFor({timeout:20000});
  const final=await waitState(book.id,s=>s.phase==='complete');
  assert.equal(final.heard.length,book.pages.length);assert.equal(Object.keys(final.answers).length,book.questions.length);assert(final.completedEver);
  await shot(book.id==='frog'?'09-frog-complete':'10-kolobok-complete');
  checks.push(book.id+': all pages heard, every picture question answered, star persisted');
 }
 const main=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('littlewins.state.v1'))));assert.deepEqual(main.reading.completed,{});assert.equal(main.reading.spentCoins,0);checks.push('listening leaves reading progress and coins unchanged');
 // Decode all bundled audio, including feedback paths not selected above.
 const decoded=await page.evaluate(async paths=>{
  const ctx=new AudioContext();const results=[];
  for(const path of paths){const r=await fetch('assets/'+path);if(!r.ok)throw new Error(path+' '+r.status);const buffer=await ctx.decodeAudioData(await r.arrayBuffer());const samples=buffer.getChannelData(0);let peak=0,sum=0,clipped=0;for(const x of samples){peak=Math.max(peak,Math.abs(x));sum+=x*x;if(Math.abs(x)>=.999)clipped++;}results.push({file:path,seconds:buffer.duration,sampleRate:buffer.sampleRate,peak,rms:Math.sqrt(sum/samples.length),clippedFraction:clipped/samples.length});}
  await ctx.close();return results;
 },clips);
 assert(decoded.every(x=>x.seconds>1&&x.rms>.001&&x.clippedFraction<.01));
 fs.writeFileSync(path.join(out,'audio-decode.json'),JSON.stringify(decoded,null,2));
 checks.push('all '+decoded.length+' MP3s decode with non-silent audio and no material clipping');
 const ended=await page.evaluate(()=>window.__ended);assert(ended>=50);assert.equal(errors.length,0,errors.join('\n'));assert.equal(external.length,0,external.join('\n'));
 fs.writeFileSync(path.join(out,'web-check.json'),JSON.stringify({passed:true,checks,actualAudioEndEvents:ended,playbackRate:8,errors,external},null,2));
 console.log(JSON.stringify({passed:true,checks,ended},null,2));await browser.close();
})().catch(async e=>{console.error(e);if(page){console.error((await page.locator('body').innerText()).slice(-3500));console.error(await page.locator('[role=button]').evaluateAll(es=>es.map(e=>({label:e.getAttribute('aria-label'),text:e.textContent,rect:e.getBoundingClientRect().toJSON(),html:e.outerHTML.slice(0,500)}))));await shot('failure');}if(browser)await browser.close();process.exitCode=1;});
