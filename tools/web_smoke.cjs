/* Run against a built Flutter web app. npm install --prefix /tmp/littlewins-browser playwright */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs');const path=require('path');const assert=require('assert');
const root=path.resolve(__dirname,'..');
const output=process.env.SMOKE_OUTPUT_DIR||path.join(root,'docs/verification');
fs.mkdirSync(output,{recursive:true});
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/books/catalog.json'),'utf8'));
let failurePage;
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:430,height:932},deviceScaleFactor:1,recordVideo:{dir:path.join(output,'recordings'),size:{width:430,height:932}}});
 const page=await context.newPage();
 failurePage=page;
 const errors=[],external=[],audioRequests=[],captures=[];let verifiedPages=0;
 await page.addInitScript(()=>{window.__frameTimes=[];window.__audioPlays=0;const play=HTMLMediaElement.prototype.play;HTMLMediaElement.prototype.play=function(){window.__audioPlays++;return play.call(this);};const frame=t=>{window.__frameTimes.push(t);if(window.__frameTimes.length>15000)window.__frameTimes.shift();requestAnimationFrame(frame);};requestAnimationFrame(frame);});
 page.on('request',r=>{if(r.url().includes('/sounds/'))audioRequests.push(r.url().split('/').pop());});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&/Exception|RenderFlex|overflow|Error/.test(m.text()))errors.push(m.text());});
 await context.route('**/*',route=>{const url=new URL(route.request().url());if(!['127.0.0.1','localhost'].includes(url.hostname)){external.push(url.href);return route.abort();}return route.continue();});
 const enable=async()=>{await page.waitForFunction(()=>document.querySelector('flutter-view'));await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);};
 const click=async(text)=>{await page.getByText(text,{exact:true}).click();await page.waitForTimeout(250);};
 const shot=async(name)=>{captures.push({name,time:Date.now()});await page.screenshot({path:path.join(output,name+'.png')});};
 const pin=async(value)=>{for(const d of value)await click(d);};
 const bottom=async()=>{await page.mouse.move(205,550);await page.mouse.wheel(0,8000);await page.waitForTimeout(450);};
 const assertText=async(text)=>{await page.getByText(text,{exact:false}).first().waitFor();};
 const choose=async(q,index)=>{await page.getByRole('button',{name:String.fromCharCode(65+index)+' '+q.options[index],exact:true}).click();await click('Check answer');};
 const readBatch=async(batch)=>{
   for(let p=batch.startPage;p<batch.endPage;p++){
     await assertText(`Page ${p+1} of ${catalog[0].pages.length}`);
     await bottom();
     if(p+1<batch.endPage) { await page.getByRole('button',{name:'Next page',exact:true}).last().click(); await page.waitForTimeout(250); }
   }
   // Reaching the end leaves the page open until the child starts the test.
   await assertText(`Page ${batch.endPage} of ${catalog[0].pages.length}`);
   assert.equal(await page.getByText(batch.questions[0].prompt,{exact:true}).count(),0);
   if(batch.startPage===0) await shot('23-start-test');
   await click('Start test');
   await assertText(batch.questions[0].prompt);
 };
 const passBatch=async(batch)=>{
   for(let i=0;i<batch.questions.length;i++){
     const q=batch.questions[i];await assertText(q.prompt);
     for(let option=0;option<4;option++) assert.equal(await page.getByRole('button',{name:String.fromCharCode(65+option)+' '+q.options[option],exact:true}).count(),1);
     if(batch.startPage===0 && i===0){
       await page.getByRole('button',{name:String.fromCharCode(65+q.answer)+' '+q.options[q.answer],exact:true}).click();
       assert.equal(await page.getByText('Correct!',{exact:false}).count(),0);await shot('24-selected-before-check');
       await click('Check answer');await assertText(q.explanation);await shot('25-correct-answer');
       await page.setViewportSize({width:320,height:640});await shot('26-small-correct');
       await page.setViewportSize({width:430,height:932});
     }else await choose(q,q.answer);
     if(i+1<batch.questions.length) await click('Next question');
   }
   const earned=(batch.endPage-batch.startPage)*10;
   await assertText(`+${earned} coins`);verifiedPages+=batch.endPage-batch.startPage;
   await assertText(`Saved balance: ${verifiedPages*10} coins`);
   await shot(`reward-${verifiedPages*10}-early`);await page.waitForTimeout(350);await shot(`reward-${verifiedPages*10}-middle`);await page.waitForTimeout(500);await shot(`reward-${verifiedPages*10}-settled`);
   if(verifiedPages===12){await assertText('Enough coins for a 15-minute preview');await assertText('Ten-page explorer');}
   await click('Keep reading');
 };
 await page.goto(process.env.APP_URL||'http://127.0.0.1:7357');await page.waitForTimeout(2200);await enable();
 await shot('01-welcome');await click('Set up for my child');await shot('02-age');await click('Continue');await shot('03-pin');
 await pin('123456');await pin('123456');await shot('04-setup');await bottom();await click('Let’s start reading');await shot('05-home');
 await page.getByRole('tab',{name:/My wins/}).click();await shot('29-first-progress');await assertText('Your first little win is waiting');
 await page.getByRole('tab',{name:/Books/}).click();await page.waitForTimeout(300);await shot('06-library');await click('Open the story');await shot('07-reader');
 const first=catalog[0].batches[0];
 await readBatch(first);await shot('08-quiz');
 await page.setViewportSize({width:320,height:640});await page.waitForTimeout(300);await shot('22-small-quiz');
 await page.setViewportSize({width:430,height:932});await page.waitForTimeout(300);
 await choose(first.questions[0],(first.questions[0].answer+1)%4);
 await assertText('One attempt left');await shot('09-hint');
 await page.emulateMedia({reducedMotion:'reduce'});await page.waitForTimeout(500);const stillA=await page.screenshot();await page.waitForTimeout(700);assert(stillA.equals(await page.screenshot()),'Reduced-motion feedback changed while idle');await shot('30-reduced-motion-feedback');await page.emulateMedia({reducedMotion:'no-preference'});
 // A reload cannot erase the first failed attempt.
 await page.reload();await page.waitForTimeout(1400);await enable();
 await page.getByRole('tab',{name:/Books/}).click();await click('Continue reading');
 await assertText('Page 3 of 13');
 assert.equal(await page.getByText(first.questions[0].prompt,{exact:true}).count(),0);
 await click('Continue test');
 await assertText('Attempts left: 1 of 2');
 await choose(first.questions[0],(first.questions[0].answer+1)%4);
 await assertText('No attempts left');await shot('31-exhausted');
 assert.equal(await page.getByText('Try again',{exact:true}).count(),0);
 await click('Next question');
 await choose(first.questions[1],(first.questions[1].answer+1)%4);
 await assertText('Three wrong answers reset this section');await shot('21-batch-reset');
 await click('Read the section again');await assertText('Page 1 of 13');
 // Contents cannot bypass the required reread.
 await page.getByRole('button',{name:'Contents',exact:true}).click();
 await assertText('Page 3');
 assert.equal(await page.getByRole('button',{name:/^Page 1 /}).count(),1);
 // Disabled Flutter list tiles expose text, with no button action.
 assert.equal(await page.getByRole('button',{name:/^Page 3 /}).count(),0);
 await page.getByRole('button',{name:/^Page 1 /}).click();await page.waitForTimeout(300);
 await readBatch(first);await passBatch(first);await shot('10-success');
 for(const batch of catalog[0].batches.slice(1,4)){await readBatch(batch);await passBatch(batch);}
 await shot('11-reader-resume');
 await page.getByRole('button',{name:'Back to books',exact:true}).click();await page.waitForTimeout(250);
 await page.getByRole('tab',{name:/Home/}).click();await page.waitForTimeout(300);await shot('33-home-after-batch');
 await page.getByRole('button',{name:'120',exact:true}).click();await page.waitForTimeout(300);await shot('18-wallet');assert.equal(await page.getByText('45 min',{exact:true}).count(),0);
 await click('Preview 15 minutes');await click('Start my time');await assertText('Preview timer is running');await shot('19-playtime');
 await page.reload();await page.waitForTimeout(1500);await enable();
 await page.getByRole('button',{name:'20',exact:true}).click();await assertText('Preview timer is running');
 await page.getByRole('button',{name:'Back',exact:true}).click();await page.waitForTimeout(250);
 await page.getByRole('button',{name:'Parents',exact:true}).click();await pin('000000');await assertText('That PIN isn’t right. Try again.');await pin('123456');await page.waitForTimeout(300);await shot('12-parent');
 await bottom();await page.getByRole('switch',{name:/Happy sounds/}).click();await click('Русский');await shot('13-parent-russian');
 await page.getByRole('button',{name:'Назад',exact:true}).click();await page.waitForTimeout(300);
 await page.getByRole('tab',{name:/Книги/}).click();await page.waitForTimeout(300);await shot('14-library-russian');
 await click('Книги на английском');await assertText('The Frog Prince');await shot('15-english-tab-russian');
 await click('Продолжить чтение');await bottom();await click('Начать проверку');await assertText(catalog[0].batches[4].questions[0].prompt);await shot('20-english-quiz-russian');const mutedAudioBefore=await page.evaluate(()=>window.__audioPlays);
 // Final one-page batch still has four questions and earns only 10 coins.
 for(let i=0;i<4;i++){
   const q=catalog[0].batches[4].questions[i];
   await page.getByRole('button',{name:String.fromCharCode(65+q.answer)+' '+q.options[q.answer],exact:true}).click();
   await click('Проверить ответ');
   if(i<3) await click('Следующий вопрос');
 }
 await assertText('+10 монет');await assertText('Ты прочитал The Frog Prince!');await shot('32-book-finished');assert.equal(await page.evaluate(()=>window.__audioPlays),mutedAudioBefore,'Muted quiz played sound');verifiedPages++;await click('Читать дальше');
 await page.setViewportSize({width:320,height:640});await page.waitForTimeout(300);await shot('16-small-phone');
 await page.setViewportSize({width:1365,height:900});await page.waitForTimeout(300);await shot('17-desktop');
 await page.reload();await page.waitForTimeout(1500);await enable();await assertText('Сегодня ты разобрался');await assertText('The Frog Prince');
 assert.strictEqual(errors.length,0,errors.join('\n'));
 assert.strictEqual(external.length,0,`External runtime requests: ${external.join(', ')}`);
 const intervals=await page.evaluate(()=>window.__frameTimes.slice(1).map((t,i)=>t-window.__frameTimes[i]));
 const sorted=intervals.filter(x=>x>0).sort((a,b)=>a-b);
 const frameCadence={samples:sorted.length,medianMs:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],over33ms:sorted.filter(x=>x>33.4).length,note:'Browser requestAnimationFrame cadence during the final reload; not native-device or Flutter raster timings.'};
 fs.writeFileSync(path.join(output,'capture-timeline.json'),JSON.stringify({captures,audioRequests,frameCadence},null,2));
 const report={passed:true,verifiedPages,frameCadence,checks:['onboarding','PIN confirmation','three-page quiz starts only by button','four answer options','two attempts total','attempt persistence and manual resume on reload','third error resets batch','contents cannot skip rereading','batch credits only after four correct answers','final shorter batch','15-minute purchase','purchase persistence on reload','wrong parent PIN','Russian interface','English questions in Russian UI','320px phone','desktop','locale persistence','neutral selected marker','grounded correct explanation','correct feedback at 320px','reduced-motion stable feedback','reward timestamps and saved balance','100-coin milestone','unreachable wallet offers hidden','mute','book completion keepsake','remembered book across locale and reload','no external runtime requests','no browser errors'],errors,external};
 fs.writeFileSync(path.join(output,'web-smoke.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));await context.close();fs.renameSync(await page.video().path(),path.join(output,'walkthrough.webm'));await browser.close();
})().catch(async e=>{
 console.error(e);
 if(failurePage){
   await failurePage.screenshot({path:path.join(output,'failure.png')}).catch(()=>{});
   const snapshot=await failurePage.locator('body').ariaSnapshot().catch(()=> 'Snapshot unavailable');
   fs.writeFileSync(path.join(output,'failure.txt'),snapshot);
 }
 process.exit(1);
});
