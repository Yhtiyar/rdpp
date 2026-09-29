"""Attach source-grounded picture questions without changing immutable exact parts."""
from copy import deepcopy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OLD={b['id']:b for name in ['fables-first-listening','fables-last-listening'] for b in json.loads((ROOT/f'content/new-books/{name}.json').read_text())}
# old question number, checkpoint endpoint, evidence part (1-based), exact quote;
# optional copy corrections remain outside source narration.
SPECS={
'lion-and-mouse':[
(1,2,1,'The mouse accidently ran across the paw of a sleeping lion.'),
(4,2,3,'Using his sharp teeth, the mouse made a hole in the net.')],
'city-and-country-mouse':[
(3,2,3,'A cat with sharp claws appeared.'),
(4,2,3,'The Country Mouse decided that the city was not for him. He made his way back to his simple home where he was safe and happy.',{'hint':'He decided that the city was not for him. He wanted his simple home.'})],
'goldilocks':[
(1,2,1,'One morning, Papa Bear made some steaming-hot porridge for his family.'),
(2,2,3,'Then she tasted the porridge in the tiny bowl. It was just right, so she gobbled it all up.'),
(3,5,4,'But, suddenly the chair broke and Goldilocks fell to the floor! Crash!'),
(4,5,5,'She tried the tiny bed. It was just right. Goldilocks fell fast asleep.',{'feedback':'Goldilocks fell asleep in the tiny bed.'}),
(6,6,7,'Goldilocks ran out of the cozy cottage as fast as she could.')],
'gingerbread-man':[
(1,2,1,'One day, a little old woman decided to make a delicious gingerbread man cookie. She put the cookie dough on a cookie sheet and baked it in the oven.',{'hint':'She put the cookie dough on a sheet and put it into the oven.'}),
(2,2,1,'To her surprise, when she opened the oven, the Gingerbread Man jumped out!'),
(5,4,5,'Before the Gingerbread Man could even say, “Thank you for your kindness,” the fox ate him— every last bite.'),
(6,4,5,'Before the Gingerbread Man could even say, “Thank you for your kindness,” the fox ate him— every last bite.',{'prompt':'Who did the fox eat?','hint':'It was the little cookie that the fox carried across the river.','feedback':'The fox ate the Gingerbread Man, every last bite.'})],
'shoemaker-and-elves':[
(1,2,2,'When the shoemaker woke up, he was shocked to find a beautiful pair of shoes on his workbench.'),
(4,2,3,'That evening he cut leather for two pairs of shoes and left it on his workbench.'),
(5,5,4,'That evening, two tiny elves in tattered clothes tip-toed into the workshop.'),
(6,5,5,'“Those poor elves must be freezing in their ragged clothes,” said the wife to the shoemaker.')],
'little-red-hen':[
(1,2,1,'The Little Red Hen wanted to plant some grains of wheat. She asked for help, but her friends refused.',{'prompt':'Who wanted to plant grains of wheat?','hint':'She was the hardworking hen on the farm.','feedback':'The Little Red Hen wanted to plant the wheat.'}),
(2,2,2,'In the summertime, the wonderful golden wheat was ready to be harvested.'),
(4,3,4,'So she baked the bread all by herself.',{'prompt':'What did the Little Red Hen bake?','hint':'Her friends appeared when they smelled it freshly baked.','feedback':'She baked the bread all by herself.'})],
'thumbelina':[
(1,2,2,'At that moment, the flower opened. Inside the flower sat a tiny girl.'),
(2,2,2,'One night, a mother toad came and took Thumbelina away.'),
(4,5,4,'A field mouse took pity on her. “My dear, you must come home with me,” the field mouse said.'),
(5,5,6,'The bird was cold and hurt. Thumbelina cared for the swallow and brought him food every day.',{'prompt':'Which bird did Thumbelina care for?','hint':'The bird was cold and hurt. She brought him food every day.','feedback':'Thumbelina cared for the hurt swallow.'}),
(6,6,7,'In a new land filled with flowers, Thumbelina met a king. He was tiny, too! Thumbelina became the queen.')],
'turtle-shell':[
(1,2,1,'One autumn day, Turtle was talking with the birds. They said, “Winter is coming. Soon it’s going to be very cold here. We’re getting ready to fly south where it is warm.”'),
(2,2,2,'“Use your mouth to hold on tightly to this stick,” the birds explained. Turtle did just that.'),
(3,4,5,'He crawled into a pond and swam down to the bottom. There he dug a hole in the mud and slept all winter long.'),
(4,4,5,'In the spring, Turtle woke up. He was very proud of the cracks on his shell.',{'feedback':'Turtle woke up in spring, proud of the cracks on his shell.'})],
'why-flies-buzz':[
(1,2,1,'As the man reached for a coconut, a black fly flitted around his face.',{'prompt':'Who flew around the man’s face?','feedback':'The black fly flew around the man’s face.'}),
(2,2,2,'As she jumped, she kicked a crocodile that was sleeping beneath the tree.'),
(5,5,5,'The lion gathered all the animals together to find out what had happened.'),
(4,5,4,'“My eggs are all broken!” wailed the bushfowl. She began to cry—sob! sob! sob! And there she stayed, beside her nest, for many days and nights.'),
(1,7,8,'The fly tried to speak, but all he could say was, “Buzz! Buzz! Buzz!”',{'prompt':'Who could only say, “Buzz, buzz, buzz”?','hint':'The little insect tried to speak after the lion punished him.','feedback':'The fly could only say, “Buzz, buzz, buzz!”'}),
(6,7,8,'The bushfowl was satisfied. The fly that had caused all the trouble had been punished. And so she agreed to once again call the sun to begin the day.',{'hint':'This bird was satisfied when the fly was punished.'})],
'three-little-pigs':[
(1,2,1,'One day, Mama Pig said, “You are all grown now. It is time for you to go out into the world and live on your own.”'),
(2,2,1,'The First Little Pig decided to build a house made out of straw.'),
(4,5,4,'“Then I’ll huff, and I’ll puff, and I’ll blow your house down,” said the Big Bad Wolf.',{'prompt':'Who said he would huff and puff?', 'hint':'He wanted the little pig to let him into the straw house.','feedback':'The Big Bad Wolf said he would huff and puff.'}),
(5,5,6,'The two little pigs ran to their brother’s brick house.'),
(6,6,7,'That water was so hot that the wolf jumped out and ran away.')]
}
PROPER={'Goldilocks','Papa Bear','Baby Bear','Mama Pig','Thumbelina in a flower','Thumbelina in her walnut bed'}

def main():
 for bid,specs in SPECS.items():
  path=ROOT/f'content/verbatim-books/{bid}.json';b=json.loads(path.read_text());before=deepcopy(b)
  result=[]
  for index,s in enumerate(specs):
   oldn,end,part,quote,*overrides=s
   old=OLD[bid]['questions'][oldn-1]
   q={k:deepcopy(old[k]) for k in ['prompt','hint','guided','feedback','choices','answer']}
   if overrides:q.update(overrides[0])
   right=deepcopy(old['choices'][old['answer']]);wrong=deepcopy(old['choices'][1-old['answer']])
   q['answer']=index%2;q['choices']=[right,wrong] if q['answer']==0 else [wrong,right]
   label=right['label'];name=label if label in PROPER else 'the '+label[0].lower()+label[1:]
   q['guided']=f'Let’s do it together. Tap the picture with the green frame. This is {name}.'
   qid=f'{bid}-exact-question-{index+1:03d}'
   q.update(id=qid,afterPage=end,audio={kind:f'assets/books/{bid}/audio/{qid}-{kind}.mp3' for kind in ['prompt','hint','guided','feedback']},evidence=dict(pageIds=[b['pages'][part-1]['id']],quote=quote))
   groupstart=end-end%3 if end==len(b['pages'])-1 and len(b['pages'])%3 else end-2
   assert groupstart<=part-1<=end,(bid,index,part,end)
   group=b['pages'][groupstart:end+1]
   combined=' '.join(page['text'] for page in group)
   assert quote in combined,(bid,index,quote)
   begin=combined.index(quote);finish=begin+len(quote);position=0;proof=[]
   for page in group:
    if position<finish and position+len(page['text'])>begin:proof.append(page['id'])
    position+=len(page['text'])+1
   q['evidence']['pageIds']=proof
   assert all((ROOT/c['image']).exists() for c in q['choices'])
   result.append(q)
  b['questions']=result
  assert {k:v for k,v in b.items() if k!='questions'}=={k:v for k,v in before.items() if k!='questions'}
  expected=2*(len(b['pages'])//3)+min(len(b['pages'])%3,2)
  assert len(result)==expected,(bid,len(result),expected)
  path.write_text(json.dumps(b,ensure_ascii=False,indent=2)+'\n')
  print(bid,len(b['pages']),'parts',len(result),'grounded questions',flush=True)
if __name__=='__main__':main()
