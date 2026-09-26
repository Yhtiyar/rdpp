/* Targeted seeded presentation checks. The full earning/purchase flow is in web_smoke.cjs. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..'),out=process.env.SMOKE_OUTPUT_DIR||path.join(root,'docs/verification/emotional-update');
const books=JSON.parse(fs.readFileSync(path.join(root,'assets/books/catalog.json')));
const url=process.env.APP_URL||'http://127.0.0.1:7357';
const day=new Date().toISOString().slice(0,10);
function state(pages,spent=0){const completed={};for(const b of books)for(let i=0;i<b.pages.length&&pages>0;i++,pages--)completed[b.id+':'+i]=day;return {version:1,onboarded:true,locale:'en',sound:false,dailyLimit:60,lastOpenedBookId:'frog',reading:{completed,spentCoins:spent,positions:{frog:11}},batchProgress:{},wallet:{}};}
(async()=>{
 fs.mkdirSync(out,{recursive:true});const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const checks=[],errors=[];
 async function scene(data,options={}){
  const c=await browser.newContext({viewport:options.viewport||{width:430,height:932},reducedMotion:options.reduce?'reduce':'no-preference',recordVideo:options.video?{dir:path.join(out,'recordings'),size:{width:430,height:932}}:undefined});
  const p=await c.newPage();p.on('pageerror',e=>errors.push(e.message));
  await p.addInitScript(({data,block})=>{localStorage.setItem('littlewins.state.v1',JSON.stringify(JSON.stringify(data)));window.__audioCalls=0;const play=HTMLMediaElement.prototype.play;HTMLMediaElement.prototype.play=function(){window.__audioCalls++;return block?Promise.reject(new DOMException('Blocked for verification','NotAllowedError')):play.call(this);};window.__frames=[];const frame=t=>{if(window.__measure)window.__frames.push(t);requestAnimationFrame(frame);};requestAnimationFrame(frame);},{data,block:options.block||false});
  await p.goto(url);await p.waitForFunction(()=>document.querySelector('flutter-view'));await p.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await p.getByText('The Frog Prince',{exact:true}).first().waitFor();
  return {c,p};
 }
 for(const [count,expected] of [[21,'1 new page left'],[22,'Reread for fun']]){
  const {c,p}=await scene(state(count,200));await p.getByRole('button',{name:String(count*10-200),exact:true}).click();await p.getByText(expected,{exact:false}).waitFor();assert.equal(await p.getByText('Read a little more to earn enough coins.',{exact:true}).count(),0);assert.equal(await p.getByText('Preview 15 minutes',{exact:true}).count(),0);await p.screenshot({path:path.join(out,`catalog-${count}.png`)});checks.push(`honest catalog at ${count} verified pages after spending`);await c.close();
 }
 const d=state(9);d.sound=true;d.dailyLimit=0;d.batchProgress['frog:9']={readPages:[9,10,11],attempts:[1,1,1,0],correctQuestions:[0,1,2],questionIndex:3,errors:0,passed:false,needsReread:false};
 const {c,p}=await scene(d,{video:true,block:true});
 await p.getByText('Continue my story',{exact:true}).click();await p.getByText('Continue test',{exact:true}).click();
 const q=books[0].batches[3].questions[3];await p.getByRole('button',{name:'D '+q.options[3],exact:true}).click();
 const session=await c.newCDPSession(p),trace=[];session.on('Tracing.dataCollected',e=>trace.push(...e.value));
 await session.send('Tracing.start',{categories:'devtools.timeline,disabled-by-default-devtools.timeline.frame',transferMode:'ReportEvents'});
 await p.evaluate(()=>{window.__frames=[];window.__measure=true;});
 await p.getByText('Check answer',{exact:true}).click();
 await p.getByText('Saved balance: 120 coins',{exact:true}).waitFor();await p.waitForTimeout(1300);
 const frames=await p.evaluate(()=>{window.__measure=false;return window.__frames;});
 const complete=new Promise(resolve=>session.once('Tracing.tracingComplete',resolve));await session.send('Tracing.end');await complete;
 const gaps=frames.slice(1).map((t,i)=>t-frames[i]).sort((a,b)=>a-b);
 const profile={samples:gaps.length,medianMs:gaps[Math.floor(gaps.length*.5)],p95Ms:gaps[Math.floor(gaps.length*.95)],over33ms:gaps.filter(x=>x>33.4).length,drawFrameEvents:trace.filter(e=>e.name==='DrawFrame').length,paintEvents:trace.filter(e=>e.name==='Paint').length,note:'Chromium release-web reward sequence, video enabled, software-rendered host. rAF cadence plus CDP frame/paint events; not Flutter raster or physical-device timings.'};
 fs.writeFileSync(path.join(out,'reward-profile.json'),JSON.stringify(profile,null,2));
 await p.getByText('Today’s allowance is used',{exact:false}).waitFor();await p.screenshot({path:path.join(out,'allowance-reached.png')});
 assert((await p.evaluate(()=>window.__audioCalls))>0,'Blocked audio path was not exercised');checks.push('saved reward succeeds with browser-blocked audio','allowance reached does not imply immediately available time','profiled 1100ms reward');
 await p.getByText('Keep reading',{exact:true}).click();await p.getByText('Page 13 of 13',{exact:true}).waitFor();await c.close();fs.renameSync(await p.video().path(),path.join(out,'reward-motion.webm'));
 const reduced=await scene(state(0),{reduce:true,viewport:{width:320,height:640}});await reduced.p.waitForTimeout(600);const before=await reduced.p.screenshot();await reduced.p.waitForTimeout(7500);assert(before.equals(await reduced.p.screenshot()),'Reduced-motion home blinked');checks.push('reduced-motion home remains stable beyond idle interval');await reduced.c.close();
 const gallery=await browser.newPage({viewport:{width:1100,height:650}});
 const moods=['ready','thinking','encouraging','proud','celebrating','calm'];
 await gallery.setContent(`<html><body style="margin:24px;background:#fefbff;color:#261044;font:16px sans-serif"><h1>MiMi · bundled poses at 64px and 160px</h1><div style="display:grid;grid-template-columns:repeat(6,1fr);gap:10px">${moods.map(m=>{const data=fs.readFileSync(path.join(root,'assets/art/mimi',m+'.webp')).toString('base64');return `<div><p>${m}</p><img width="64" src="data:image/webp;base64,${data}"><br><img width="160" src="data:image/webp;base64,${data}"></div>`;}).join('')}</div></body></html>`);await gallery.screenshot({path:path.join(out,'mimi-poses.png')});await gallery.close();
 assert.equal(errors.length,0,errors.join('\n'));fs.writeFileSync(path.join(out,'supplemental-checks.json'),JSON.stringify({passed:true,checks,errors,profile},null,2));console.log(JSON.stringify({passed:true,checks,profile},null,2));await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
