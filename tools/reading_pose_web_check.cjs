/* Full-cycle Flutter web evidence: run the tools/mimi_reading_preview.dart target on port 7360. */
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
(async()=>{
 const output=path.resolve('.implementation/emotional/layered-review');fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try {
  const page=await browser.newPage({viewport:{width:650,height:850}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error'&& /Exception|RenderFlex|overflow|Assertion failed/.test(m.text()))errors.push(m.text());});
  await page.goto(process.env.PREVIEW_URL || 'http://127.0.0.1:7360');
  await page.waitForFunction(()=>document.querySelector('flt-semantics-placeholder'));
  await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
  const input=page.getByRole('textbox',{name:'Exact phase'});await input.waitFor();
  const frames=[];
  for(let i=0;i<=200;i++){
   const phase=i/200;
   await input.fill(phase.toFixed(3));await page.waitForTimeout(30);
   const file=`pose-${String(i).padStart(3,'0')}.png`;
   await page.screenshot({path:path.join(output,file)});frames.push({phase,file});
  }
  for(const width of [320,430,1365]){
   await page.setViewportSize({width,height:900});
   for(const phase of [0,.159,.17,.185,.335,.44,.50,.51,.53,.565,.60,.68,.72,.79,.80,.81,.825,.995]){
    await input.fill(String(phase));await page.waitForTimeout(40);
    await page.screenshot({path:path.join(output,`${width}-${phase}.png`)});
   }
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(output,'index.json'),JSON.stringify({frames,errors},null,2));
  console.log(`Captured ${frames.length} cycle poses, plus 54 responsive poses; no browser errors.`);
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
