/* Run against a built Flutter web app. npm install --prefix /tmp/littlewins-browser playwright */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs');const path=require('path');const assert=require('assert');
const root=path.resolve(__dirname,'..');
const output=path.join(root,'docs/verification');
const catalog=JSON.parse(fs.readFileSync(path.join(root,'assets/books/catalog.json'),'utf8'));
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:430,height:932},deviceScaleFactor:1});
 const page=await context.newPage();
 const errors=[],external=[];let counter=0;
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&/Exception|RenderFlex|overflow|Error/.test(m.text()))errors.push(m.text());});
 await context.route('**/*',route=>{const url=new URL(route.request().url());if(!['127.0.0.1','localhost'].includes(url.hostname)){external.push(url.href);return route.abort();}return route.continue();});
 const enable=async()=>{await page.waitForFunction(()=>document.querySelector('flutter-view'));await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(300);};
 const click=async(text)=>{await page.getByText(text,{exact:true}).click();await page.waitForTimeout(220);};
 const shot=async(name)=>{await page.screenshot({path:path.join(output,name+'.png')});};
 const pin=async(value)=>{for(const d of value)await click(d);};
 const bottom=async()=>{await page.mouse.move(205,550);await page.mouse.wheel(0,8000);await page.waitForTimeout(350);};
 const assertText=async(text)=>assert((await page.locator('body').innerText()).includes(text),`Missing: ${text}`);
 await page.goto(process.env.APP_URL||'http://127.0.0.1:7357');await page.waitForTimeout(2200);await enable();
 await shot('01-welcome');await click('Set up for my child');await shot('02-age');await click('Continue');await shot('03-pin');
 await pin('123456');await pin('123456');await shot('04-setup');await bottom();await click('Let’s start reading');await shot('05-home');
 await page.getByRole('tab',{name:/Books/}).click();await page.waitForTimeout(300);await shot('06-library');await click('Open the story');await shot('07-reader');
 // Earn ten pages through the actual reader and quizzes, without editing application storage.
 for(let i=0;i<10;i++){
  await bottom();await click('Check understanding  ·  +10 coins');
  const q=catalog[0].pages[i].question;
  if(i===0){await shot('08-quiz');await page.getByText(q.options[(q.answer+1)%3],{exact:false}).click();await click('Check answer');await assertText(q.hint);await shot('09-hint');await click('Try again');}
  await page.getByRole('button',{name:String.fromCharCode(65+q.answer)+' '+q.options[q.answer],exact:true}).click();await click('Check answer');
  await assertText('+10 coins');if(i===0)await shot('10-success');
  await click('Keep reading');counter++;
 }
 await shot('11-reader-resume');
 await page.getByRole('button',{name:'Back to books',exact:true}).click();await page.waitForTimeout(250);
 await page.getByRole('button',{name:'100',exact:true}).click();await page.waitForTimeout(300);await shot('18-wallet');
 await click('Preview 15 minutes');await click('Start my time');await page.waitForTimeout(400);await assertText('Preview timer is running');await shot('19-playtime');
 await page.reload();await page.waitForTimeout(1500);await enable();
 await page.getByRole('button',{name:'0',exact:true}).click();await page.waitForTimeout(250);await assertText('Preview timer is running');
 await page.getByRole('button',{name:'Back',exact:true}).click();await page.waitForTimeout(250);
 await page.getByRole('button',{name:'Parents',exact:true}).click();await pin('000000');await assertText('That PIN isn’t right. Try again.');await pin('123456');await page.waitForTimeout(300);await shot('12-parent');
 await bottom();await click('Русский');await shot('13-parent-russian');
 await page.getByRole('button',{name:'Назад',exact:true}).click();await page.waitForTimeout(300);
 await page.getByRole('tab',{name:/Книги/}).click();await page.waitForTimeout(300);await shot('14-library-russian');
 await click('Книги на английском');await assertText('The Frog Prince');await shot('15-english-tab-russian');
 await click('Продолжить чтение');await bottom();await click('Ответить на вопрос  ·  +10 монет');await assertText(catalog[0].pages[10].question.prompt);await shot('20-english-quiz-russian');
 await page.getByRole('button',{name:'Закрыть',exact:true}).click();await page.waitForTimeout(300);await page.getByRole('button',{name:'К книгам',exact:true}).click();await page.waitForTimeout(300);
 await page.setViewportSize({width:320,height:640});await page.waitForTimeout(300);await shot('16-small-phone');
 await page.setViewportSize({width:1365,height:900});await page.waitForTimeout(300);await shot('17-desktop');
 await page.reload();await page.waitForTimeout(1500);await enable();await assertText('Твоя следующая');
 await context.storageState({path:'/tmp/littlewins-browser/final-state.json'});
 assert.strictEqual(errors.length,0,errors.join('\n'));
 // All required fonts, story assets, sound and engine assets are local.
 assert.strictEqual(external.length,0,`External runtime requests: ${external.join(', ')}`);
 const report={passed:true,verifiedPages:counter,checks:['onboarding','PIN confirmation','reading navigation','wrong answer + hint','10 distinct rewards = 100 coins','15-minute purchase','purchase persistence on reload','wrong parent PIN','Russian interface','English questions in Russian UI','320px phone','desktop','locale persistence','no external runtime requests','no browser errors'],errors,external};
 fs.writeFileSync(path.join(output,'web-smoke.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
