"""Prepare five individual CKF tales; source text and picture crops are reproducible.

Run with PyMuPDF + Pillow available (for this environment: PYTHONPATH=/tmp/readapp-pdf).
The source PDF is user supplied. The root integration bundles it once and adds audio.
"""
from pathlib import Path
import io
import json
import re
import subprocess
import pymupdf as fitz
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / 'books/fables-list.pdf'
OUT = ROOT / 'content/new-books'
ART = ROOT / 'assets/books'
LICENSE = ('This work is based on an original work of the Core Knowledge® Foundation made available through licensing under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License. This does not in any way imply that the Core Knowledge Foundation endorses this work. Copyright © 2014 Core Knowledge Foundation. Text and illustrations from Classic Tales Big Book, Preschool, Core Knowledge Language Arts®. Noncommercial use only; adaptations distributed under the same license. License: https://creativecommons.org/licenses/by-nc-sa/3.0/. Complete original notices retained in the bundled source PDF.')

# A batch ends at an exclusive zero-based page index. Answers are deliberately
# distributed across all four positions, and refer only to that batch's text.
def q(prompt, options, answer, hint, explanation):
    return dict(prompt=prompt, options=options, answer=answer, hint=hint, explanation=explanation)

QUIZZES = {
'lion-and-mouse': [
(3, [
q('What did the little mouse run across?', ['A sleeping lion’s paw.', 'A river bridge.', 'A bird’s nest.', 'A pile of ropes.'], 0, 'The lion was asleep when the mouse came near.', 'The mouse accidentally ran across the paw of a sleeping lion.'),
q('How did the lion catch the mouse?', ['In a wooden box.', 'In his big furry paws.', 'In a hole in a tree.', 'With a long rope.'], 1, 'The lion used part of his own body.', 'The angry lion captured the mouse in his great, big, furry paws.'),
q('What did the mouse promise the lion?', ['To bring him dinner.', 'To leave the forest.', 'To return his kindness one day.', 'To build him a home.'], 2, 'The mouse asked to be free and offered help in return.', 'The mouse promised to return the lion’s kindness one day.'),
q('What did the lion do after hearing the mouse’s plea?', ['He fell into a river.', 'He ran away from the mouse.', 'He built a net.', 'He let the mouse go.'], 3, 'The mouse asked the lion to set him free.', 'The lion released the mouse after the mouse asked for freedom.')]),
(5, [
q('What sound led the mouse back to the lion?', ['Angry roars.', 'Birdsong.', 'A bell ringing.', 'Quiet snoring.'], 0, 'The lion was caught and could not get free.', 'The mouse heard angry roars and followed them to the lion.'),
q('What was the lion trapped in?', ['A deep well.', 'A net made of ropes.', 'A locked house.', 'A hollow tree.'], 1, 'The mouse needed to make a hole to free him.', 'The mouse found the lion trapped in a net made of ropes.'),
q('How did the mouse free the lion?', ['He called a hunter.', 'He pushed down a tree.', 'He used his sharp teeth to make a hole.', 'He carried the lion away.'], 2, 'The mouse could bite through the ropes.', 'The mouse made a hole in the net with his sharp teeth, setting the lion free.'),
q('What does the story say about small friends?', ['They cannot keep promises.', 'They should never help lions.', 'They are always afraid.', 'They can still be great friends.'], 3, 'Think about how the little mouse helped the great lion.', 'The moral says friends who are little in size can still be great friends.')])],
'city-and-country-mouse': [
(3, [
q('Who did the City Mouse visit?', ['His cousin, the Country Mouse.', 'A cat in the city.', 'A lion in the forest.', 'A shoemaker.'], 0, 'The two mice belonged to the same family.', 'The City Mouse visited his cousin, the Country Mouse, on a summer’s day.'),
q('What food did the Country Mouse eat?', ['Ham and chocolate cake.', 'Corn and peas.', 'Fish and bread.', 'Honey and gingerbread.'], 1, 'His meals were simple foods from the country.', 'The Country Mouse ate plain food like corn and peas.'),
q('What did the City Mouse invite his cousin to do?', ['Build a new barn.', 'Hide from a lion.', 'Come with him to the city.', 'Plant a field of corn.'], 2, 'The City Mouse wanted to show his cousin where he lived.', 'The City Mouse invited the Country Mouse to the wonderful city.'),
q('How did the Country Mouse react to his cousin’s grand home?', ['He said it was too small.', 'He refused to look at it.', 'He went to sleep.', 'He exclaimed, “Oh my!”'], 3, 'The grand home surprised the Country Mouse.', 'When he saw his cousin’s grand home, the Country Mouse said, “Oh my!”')]),
(5, [
q('What foods did the cousins enjoy in the city?', ['Ham and chocolate cake.', 'Only corn and peas.', 'Leaves and grass.', 'Porridge and honey.'], 0, 'The City Mouse proudly called the meal a feast.', 'The mice secretly ate delicious foods like ham and chocolate cake.'),
q('What animal interrupted the mice’s feast?', ['A cow.', 'A cat.', 'A fox.', 'A bear.'], 1, 'The visitor had sharp claws.', 'A cat with sharp claws appeared after the mice heard noises.'),
q('Where did the mice escape?', ['Under a boat.', 'Into a garden.', 'Inside a small hole in the wall.', 'Onto a roof.'], 2, 'They squeezed into a place too small for the cat.', 'The mice escaped just in time into a small hole in the wall.'),
q('How were the mice eating before the cat appeared?', ['At a picnic with the cat.', 'Alone in a field.', 'Beside the Country Mouse’s corn.', 'Secretly, at the City Mouse’s feast.'], 3, 'The text describes how the cousins began their meal.', 'The cousins secretly began to eat the feast in the city.')]),
(7, [
q('Where did the Country Mouse go at the end?', ['Back to his simple home.', 'To another city.', 'Into the cat’s house.', 'To a palace.'], 0, 'He decided that the city was not for him.', 'The Country Mouse made his way back to his simple home.'),
q('How did the Country Mouse feel at home?', ['Lost and lonely.', 'Safe and happy.', 'Angry with his family.', 'Afraid of the fields.'], 1, 'His simple home gave him what the city could not.', 'The text says he was safe and happy in his simple home.'),
q('What did the Country Mouse decide about the city?', ['He wanted to rule it.', 'It needed more chocolate.', 'It was not for him.', 'He would never leave it.'], 2, 'His decision sent him back to the country.', 'The Country Mouse decided that the city was not for him.'),
q('What is the moral of this tale?', ['Bigger meals are always better.', 'All cousins should live together.', 'Never visit a friend.', 'There’s no place like home.'], 3, 'The Country Mouse was happiest when he returned home.', 'The final page gives the moral: There’s no place like home.')])],
'goldilocks': [
(3, [
q('Who made porridge for the bear family?', ['Papa Bear.', 'Goldilocks.', 'Baby Bear.', 'A neighbor.'], 0, 'The first page names the bear who cooked breakfast.', 'Papa Bear made the steaming-hot porridge and poured it into three bowls.'),
q('Why did the bears go for a walk?', ['They were looking for Goldilocks.', 'Their porridge needed to cool.', 'They needed new chairs.', 'They had no food.'], 1, 'Their breakfast was steaming hot.', 'The bears went walking in the forest while their porridge cooled.'),
q('How did Goldilocks find the cottage?', ['She followed Baby Bear.', 'She rode there in a cart.', 'She lost her way in the forest.', 'The bears invited her.'], 2, 'Goldilocks was also out walking that morning.', 'Goldilocks lost her way in the forest and came upon the bears’ cottage.'),
q('Which porridge did Goldilocks eat all up?', ['The big bowl’s hot porridge.', 'The middle bowl’s cold porridge.', 'All three bowls equally.', 'The tiny bowl’s porridge.'], 3, 'One bowl tasted just right.', 'The porridge in the tiny bowl was just right, so Goldilocks gobbled it all up.')]),
(6, [
q('How did the big chair feel to Goldilocks?', ['Too hard.', 'Too soft.', 'Just right.', 'Too wobbly to touch.'], 0, 'She said “Ouch!” when she tried it.', 'The big chair was too hard for Goldilocks.'),
q('What happened when she sat in the tiny chair?', ['It flew away.', 'It broke and she fell to the floor.', 'It became bigger.', 'It rocked her to sleep.'], 1, 'The story says “Crash!” at this moment.', 'The tiny chair broke and Goldilocks fell to the floor.'),
q('Where did Goldilocks find the three beds?', ['In the garden.', 'Beside the front door.', 'Upstairs.', 'In a cave.'], 2, 'She went to another part of the cottage after trying the chairs.', 'Goldilocks went upstairs and found three beds.'),
q('Which bed did Goldilocks fall asleep in?', ['The big, smooth bed.', 'The middle-sized, lumpy bed.', 'A bed outside.', 'The tiny bed.'], 3, 'One bed was just right.', 'The tiny bed was just right, and Goldilocks fell fast asleep in it.')]),
(9, [
q('What did Baby Bear find had happened to his chair?', ['It had been broken to pieces.', 'It had been painted blue.', 'It had been moved outdoors.', 'It had grown bigger.'], 0, 'The bears noticed someone had been sitting in their chairs.', 'Baby Bear said that someone had sat in his chair and broken it to pieces.'),
q('Where did the bears find Goldilocks?', ['In the kitchen.', 'In Baby Bear’s bed.', 'Behind a tree.', 'Under Papa Bear’s chair.'], 1, 'They found her when they went upstairs.', 'Baby Bear found Goldilocks sleeping in his bed.'),
q('How did Goldilocks feel when she woke and saw the bears?', ['Pleased to meet them.', 'Too sleepy to notice.', 'Startled.', 'Proud of herself.'], 2, 'Seeing the bears was an unexpected surprise.', 'The text says Goldilocks was startled when she woke up and saw the bears.'),
q('What happened after Goldilocks ran from the cottage?', ['She returned for more porridge.', 'The bears invited her to stay.', 'Baby Bear followed her home.', 'The bears never saw or heard from her again.'], 3, 'The final sentence tells whether she returned.', 'Goldilocks ran away, and the three bears never saw or heard from her again.')])],
'gingerbread-man': [
(3, [
q('Who decided to make a gingerbread man cookie?', ['A little old woman.', 'A clever fox.', 'A farmer’s cow.', 'A little boy.'], 0, 'The story begins in her kitchen.', 'A little old woman decided to make the cookie.'),
q('Where did the woman bake the cookie dough?', ['In a bowl of water.', 'On a cookie sheet in the oven.', 'In a basket outdoors.', 'On a windowsill.'], 1, 'She opened the oven after baking.', 'She put the cookie dough on a cookie sheet and baked it in the oven.'),
q('What surprised the woman when she opened the oven?', ['The cookie had disappeared.', 'A cat was sleeping there.', 'The Gingerbread Man jumped out.', 'The oven was full of flowers.'], 2, 'The cookie suddenly began to move.', 'The Gingerbread Man jumped out when she opened the oven.'),
q('Who chased the Gingerbread Man out of the house?', ['The fox and the cat.', 'The cow and the fox.', 'Only the woman’s husband.', 'The woman and her husband.'], 3, 'Both people ran as fast as they could.', 'The little old woman and her husband chased him, but could not catch him.')]),
(6, [
q('What made the cow want to eat the Gingerbread Man?', ['The smell of ginger.', 'The sound of a bell.', 'A bowl of milk.', 'A promise from the fox.'], 0, 'The cow sniffed the air.', 'The smell of ginger made the cow want to eat him.'),
q('What was the cat doing before noticing the Gingerbread Man?', ['Swimming in the river.', 'Sleeping in the warm sunshine.', 'Climbing the oven.', 'Helping the woman bake.'], 1, 'The cat was resting in a warm place.', 'The cat was sleeping in the warm sunshine.'),
q('Which of these animals caught the Gingerbread Man during the chase?', ['The cow.', 'The cat.', 'Neither the cow nor the cat.', 'Both the cow and the cat.'], 2, 'He ran too fast for both animals.', 'The cow could not catch him, and not even the cat could catch him.'),
q('What did the fox pretend?', ['That he could not see the cookie.', 'That he was asleep.', 'That he had lost his way.', 'That he was not hungry.'], 3, 'The fox wanted the Gingerbread Man to trust him.', 'The fox pretended he was not hungry and did not want to catch him.')]),
(8, [
q('What did the fox offer to help the Gingerbread Man cross?', ['The river.', 'A high mountain.', 'A city street.', 'A deep forest.'], 0, 'The next page describes the water getting deeper.', 'The fox offered to help the Gingerbread Man cross the river.'),
q('Why did the fox say the Gingerbread Man should move to his head?', ['His ears were cold.', 'The water was getting deeper.', 'They had reached the house.', 'The cow was waiting.'], 1, 'The fox gave a reason about the river.', 'The fox said the water was getting deeper and told him to ride on his head.'),
q('Where did the fox tell him to ride after his head?', ['On his tail.', 'On his back.', 'On his nose.', 'On a floating leaf.'], 2, 'It was a part of the fox’s face.', 'Moments later, the fox told him to ride on his nose.'),
q('When did the fox give these instructions?', ['Before meeting the Gingerbread Man.', 'Inside the woman’s kitchen.', 'After returning to the field.', 'While they were crossing the river.'], 3, 'The fox was carrying him through the water.', 'The fox gave the instructions as they were crossing the river.')]),
(10, [
q('What did the fox do to the Gingerbread Man?', ['He ate him.', 'He took him home.', 'He gave him to the cat.', 'He left him in a tree.'], 0, 'The story says the fox ate every last bite.', 'Before the Gingerbread Man could finish thanking him, the fox ate him.'),
q('What was the Gingerbread Man about to say?', ['“Run faster!”', '“Thank you for your kindness.”', '“Where is the cow?”', '“Let us go back.”'], 1, 'He thought the fox had been helpful.', 'He was about to thank the fox for his kindness.'),
q('What did the fox do with his lips afterward?', ['He covered them with a leaf.', 'He washed them with soap.', 'He licked them.', 'He painted them.'], 2, 'The final page describes the fox after eating.', 'The fox licked his lips as he crossed to the other side of the river.'),
q('Where did the fox go at the end?', ['Back into the oven.', 'To the woman’s cottage.', 'To the cow’s field.', 'To the other side of the river.'], 3, 'He completed the crossing.', 'The fox crossed to the other side of the river after eating the Gingerbread Man.')])],
'shoemaker-and-elves': [
(3, [
q('How much leather did the poor shoemaker have at first?', ['Enough for one pair of shoes.', 'Enough for ten pairs of shoes.', 'A whole cart of leather.', 'No leather at all.'], 0, 'He told his wife why he was worried.', 'He had only enough leather left to make one pair of shoes.'),
q('Where did the shoemaker leave the leather that night?', ['Under his bed.', 'On his workbench.', 'Beside the road.', 'In the customer’s bag.'], 1, 'It was the place where he worked.', 'He left the leather on his workbench and went to bed.'),
q('When did he plan to make the shoes?', ['In a week.', 'At midnight.', 'In the morning.', 'After the winter.'], 2, 'He went to bed before doing the work.', 'The shoemaker decided to make his last pair of shoes in the morning.'),
q('What surprised him when he woke up?', ['The leather had vanished forever.', 'His workbench was broken.', 'His wife had sold the house.', 'A beautiful pair of shoes was on the workbench.'], 3, 'The work seemed to have been done while he slept.', 'He found a beautiful pair of shoes and wondered who had made them.')]),
(6, [
q('Why did the customer pay double for the shoes?', ['They fit his feet perfectly.', 'He wanted to buy the workbench.', 'They were the only red shoes.', 'He had promised the wife.'], 0, 'The customer admired how well the shoes fit.', 'The shoes fit so perfectly that the customer paid double the money.'),
q('What could the shoemaker buy with the money?', ['A new cottage and a horse.', 'Dinner and leather for two more pairs.', 'Only one loaf of bread.', 'A golden crown.'], 1, 'The money helped with both food and his work.', 'He had enough money to buy dinner and leather for two more pairs of shoes.'),
q('How many pairs appeared the next morning?', ['One pair.', 'Two pairs.', 'Four pairs.', 'Eight pairs.'], 2, 'The story calls the surprise amazing.', 'Although he cut leather for two pairs, the source says four pairs appeared the next morning.'),
q('How did the shoemaker and his wife plan to find the helpers?', ['They asked the customer.', 'They followed tracks outdoors.', 'They locked the workshop.', 'They stayed awake to watch the workbench.'], 3, 'They wanted to see what happened at night.', 'They decided to stay awake and watch the workbench all night.')]),
(9, [
q('Who came into the workshop and made the shoes?', ['Two tiny elves.', 'Two bears.', 'The customer’s children.', 'A family of mice.'], 0, 'The helpers arrived wearing tattered clothes.', 'Two tiny elves tiptoed in and sewed the leather into beautiful shoes.'),
q('Why did the wife want to help the elves?', ['They had lost their tools.', 'She thought they were freezing in ragged clothes.', 'They had asked for a large house.', 'They could not find the workshop.'], 1, 'She noticed what the elves were wearing.', 'She worried that the elves were freezing in their ragged clothes.'),
q('What gifts did the couple leave on the workbench?', ['Bowls of porridge.', 'Bags of gold.', 'New clothes and shoes.', 'A toy cart.'], 2, 'They sewed gifts to keep the little helpers warm.', 'The shoemaker and his wife made new clothes and shoes for the elves.'),
q('What happened after the elves found their gifts?', ['They asked for more leather.', 'They stayed in the workshop forever.', 'They hid all the shoes.', 'They danced away, and the couple lived happily.'], 3, 'The last page tells how both the elves and the couple fared.', 'The happy elves danced away and were never seen again; the couple lived happily with plenty to eat.')])]
}

# Exact narrated scripts, source PDF page numbers, and matching illustration page.
SCENES = {
'lion-and-mouse': [
([9],9,'A little mouse scampered through the forest. A big lion was sleeping nearby. Oops! The mouse ran right across the sleeping lion’s paw.'),
([10,11],10,'The lion woke up. He was angry! He caught the little mouse in his big, furry paws. The mouse was very small beside the great lion.'),
([11],11,'“Please let me go,” said the mouse. “One day I will help you.” The lion listened to the tiny mouse. Then he opened his paws and let the mouse go free.'),
([12],12,'Later, the mouse heard a loud roar. He followed the sound. There was the lion, trapped in a net of ropes! The mouse was frightened, but he wanted to help.'),
([13],13,'The mouse bit the ropes with his sharp little teeth. Bite, bite, bite! He made a hole in the net. Now the big lion could get out.'),
([13],13,'The lion was free again, thanks to the little mouse. The mouse had kept his promise. A small friend can be a great friend, too!')],
'city-and-country-mouse': [
([17],17,'One sunny summer day, City Mouse came to visit his cousin, Country Mouse. City Mouse wore a green coat. Country Mouse wore blue overalls and welcomed his cousin to the country.'),
([18],18,'Country Mouse lived in a simple little home. He ate corn and peas. He shared his plain food with his cousin, but City Mouse was not impressed.'),
([19],19,'“Come with me to the city!” said City Mouse. The two cousins set off together. When Country Mouse saw City Mouse’s grand home, he said, “Oh my!”'),
([20],20,'Inside the city home, the mice found a feast. There was ham and chocolate cake! The two cousins secretly began to eat the wonderful food.'),
([21],21,'Suddenly, the mice heard a noise. A cat with sharp claws appeared! Quick, quick! The two cousins escaped into a small hole in the wall, just in time.'),
([22,23],22,'Country Mouse decided to go home. The city was not for him. He went back to his simple country home, where he was safe and happy. There was no place like home!')],
'goldilocks': [
([27],27,'Papa Bear made porridge for Mama Bear, Baby Bear, and himself. He filled a big bowl, a middle-sized bowl, and a tiny bowl. The porridge was hot, so the bears went for a walk.'),
([28],28,'A little girl named Goldilocks was walking in the forest, too. She lost her way. Then she found the bears’ cozy cottage among the trees.'),
([29],29,'Hungry Goldilocks went inside. She tasted the porridge. The big bowl was too hot. The middle bowl was too cold. The tiny bowl was just right! She ate it all.'),
([30],30,'Goldilocks felt tired and tried the chairs. Papa Bear’s big chair was too hard. Ouch! Mama Bear’s middle-sized chair was too soft. Plop! Neither chair felt right.'),
([31],31,'Goldilocks sat in Baby Bear’s tiny chair. It felt just right. But then, crash! The little chair broke, and Goldilocks fell down onto the floor.'),
([32],32,'Upstairs, Goldilocks found three beds. The big bed was too smooth. The middle bed was too lumpy. Baby Bear’s tiny bed was just right. Goldilocks lay down and fell fast asleep.'),
([33],33,'The three bears came home. Someone had eaten their porridge! Someone had sat in their chairs! Baby Bear looked at his tiny chair. It was broken into pieces.'),
([34],34,'The bears went upstairs. “Someone has been sleeping in my bed,” said Baby Bear. “And here she is!” Goldilocks woke up and saw the bears. What a surprise!'),
([35],35,'Goldilocks jumped up and ran out of the cozy cottage as fast as she could. She went away, and the three bears never saw or heard from her again.')],
'gingerbread-man': [
([39],39,'One day, a little old woman decided to bake a gingerbread man cookie. She mixed the dough in her kitchen and got the cookie ready for the oven.'),
([40],40,'The woman put the cookie on a baking sheet and baked it in the oven. When she opened the oven, out jumped the Gingerbread Man! What a surprise!'),
([41],41,'The Gingerbread Man ran out of the house. The little old woman and her husband ran after him. They ran as fast as they could, but they could not catch him.'),
([42],42,'A cow in a field sniffed the air. Mmm, gingerbread! The cow wanted to eat the Gingerbread Man. But the cookie ran so fast that the cow could not catch him.'),
([43],43,'A cat was sleeping in the warm sunshine. The cat thought the Gingerbread Man would be a tasty treat. But not even the cat could catch the running cookie!'),
([44],44,'Then the Gingerbread Man met a fox. The clever fox pretended he was not hungry. He made the Gingerbread Man think he did not want to catch him.'),
([45],45,'The fox offered to help the Gingerbread Man cross the river. The Gingerbread Man climbed onto the fox, and the fox carried him into the water.'),
([46],46,'“The water is getting deeper,” said the fox. “Ride on my head.” The Gingerbread Man climbed up. Then the fox said, “Now ride on my nose.”'),
([47,48],48,'Before the Gingerbread Man could thank him, the fox ate the little cookie, every last bite. Then the fox licked his lips and crossed to the other side of the river.')],
'shoemaker-and-elves': [
([53],53,'A poor shoemaker lived with his wife. He was worried. They had only enough leather to make one more pair of shoes. What would they do after that?'),
([54],54,'That night, the shoemaker left the leather on his workbench. He went to bed. He planned to make his last pair of shoes in the morning.'),
([55],55,'When the shoemaker woke up, a beautiful pair of shoes was waiting on the workbench! He had not made them. He looked at the shoes and wondered who had helped.'),
([56],56,'A customer came into the workshop. The beautiful shoes fit his feet perfectly. He liked them so much that he paid the shoemaker twice the usual money.'),
([57],57,'Now the shoemaker and his wife could buy dinner and more leather. That evening, the shoemaker cut leather for two pairs of shoes and left it on his workbench.'),
([58],58,'The next morning, four pairs of fancy shoes were waiting! The couple sold them all. “Who is making these shoes?” wondered the shoemaker. That night, he and his wife stayed awake to watch.'),
([59],59,'Two tiny elves tiptoed into the workshop. Their clothes were ragged and torn. The elves began sewing the leather into beautiful shoes. Now the couple knew who their little helpers were!'),
([60],60,'“Those poor elves must be cold,” said the wife. She and the shoemaker made new clothes and shoes for them. That evening, they left the gifts on the workbench for the elves to find.'),
([61],61,'The elves found their new clothes and shoes. They were so happy that they danced away and never came back. From then on, the shoemaker and his wife lived happily, with plenty to eat.')]
}

# Crops are literal regions of supplied illustrations, not generated replacements.
# Crop geometry is in original embedded-image pixels; choices are padded equally.
CROPS = {
'lion-and-mouse': {
'lion': (11,0,(30,0,863,803),'Lion'),
'mouse': (11,0,(236,837,763,1060),'Mouse')},
'city-and-country-mouse': {
'city-mouse': (17,0,(264,327,607,718),'City Mouse in a green coat'),
'country-mouse': (17,0,(631,426,954,804),'Country Mouse in blue overalls'),
'cat': (21,0,(550,115,928,566),'Cat')},
'goldilocks': {
'papa': (27,0,(73,159,627,830),'Papa Bear'),
'goldilocks': (29,0,(777,0,1067,313),'Goldilocks'),
'porridge': (29,0,(88,30,377,375),'Bowl of porridge'),
'chair': (31,0,(0,0,896,1255),'Broken chair'),
'bed': (32,0,(803,145,1168,478),'Baby Bear’s bed'),
'baby': (33,0,(833,401,1128,832),'Baby Bear')},
'gingerbread-man': {
'woman': (39,0,(480,65,921,552),'Little old woman'),
'gingerbread': (40,0,(306,13,785,629),'Gingerbread Man'),
'cow': (42,0,(373,136,887,815),'Cow'),
'cat': (43,0,(119,825,1030,1373),'Cat'),
'fox': (48,0,(30,168,807,633),'Fox')},
'shoemaker-and-elves': {
'shoe': (55,0,(270,539,456,701),'Shoe'),
'candle': (59,0,(837,121,1104,510),'Candle'),
'shoemaker': (57,0,(614,12,1135,572),'Shoemaker'),
'wife': (57,0,(227,33,612,583),'Shoemaker’s wife'),
'leather': (59,0,(700,554,1092,742),'Leather pieces'),
'elf': (59,0,(564,239,824,487),'Elf')}
}

# afterPage, prompt, hint, feedback, correct crop key, distractor crop key,
# evidence scene (one-based), exact sentence supporting the answer.
PICTURE_QUESTIONS = {
'lion-and-mouse': [
(2,'Who was sleeping when the mouse ran by?', 'The sleeping animal had big paws and a thick mane.', 'Yes, the lion was sleeping!', 'lion','mouse',1,'A big lion was sleeping nearby.'),
(2,'Who asked the lion to let him go?', 'The little animal was caught in the lion’s paws.', 'The little mouse asked to go free.', 'mouse','lion',3,'“Please let me go,” said the mouse.'),
(5,'Who was trapped in the net?', 'The big animal roared because he could not get out.', 'The lion was trapped in the net.', 'lion','mouse',4,'There was the lion, trapped in a net of ropes!'),
(5,'Who bit the ropes and helped his friend?', 'The helper was little and had sharp teeth.', 'The mouse helped the lion get free!', 'mouse','lion',5,'The mouse bit the ropes with his sharp little teeth.')],
'city-and-country-mouse': [
(2,'Who came to visit his cousin in the country?', 'The visitor wore a green coat.', 'City Mouse came to visit his cousin.', 'city-mouse','country-mouse',1,'One sunny summer day, City Mouse came to visit his cousin, Country Mouse.'),
(2,'Who lived in a simple country home?', 'This mouse wore blue overalls and shared corn and peas.', 'Country Mouse lived in the simple country home.', 'country-mouse','city-mouse',2,'Country Mouse lived in a simple little home.'),
(5,'Who appeared while the mice were eating?', 'This animal had sharp claws. The mice hurried away.', 'The cat appeared while the mice were eating.', 'cat','country-mouse',5,'A cat with sharp claws appeared!'),
(5,'Who went back to his country home?', 'The mouse in blue overalls wanted to feel safe at home.', 'Country Mouse went home and felt safe and happy.', 'country-mouse','cat',6,'Country Mouse decided to go home.')],
'goldilocks': [
(2,'Who made porridge for the bear family?', 'The big father bear cooked the breakfast.', 'Papa Bear made the porridge.', 'papa','goldilocks',1,'Papa Bear made porridge for Mama Bear, Baby Bear, and himself.'),
(2,'What did hungry Goldilocks eat?', 'It was warm food in a bowl.', 'Goldilocks ate the porridge.', 'porridge','bed',3,'She tasted the porridge.'),
(5,'What broke when Goldilocks sat down?', 'Goldilocks was sitting on it when she fell to the floor.', 'The little chair broke. Crash!', 'chair','porridge',5,'The little chair broke, and Goldilocks fell down onto the floor.'),
(5,'Where did Goldilocks fall asleep?', 'She lay down upstairs, on something soft.', 'Goldilocks fell asleep in Baby Bear’s bed.', 'bed','chair',6,'Baby Bear’s tiny bed was just right. Goldilocks lay down and fell fast asleep.'),
(8,'Who found Goldilocks in his bed?', 'The smallest bear said, “And here she is!”', 'Baby Bear found Goldilocks in his bed.', 'baby','papa',8,'“Someone has been sleeping in my bed,” said Baby Bear.'),
(8,'Who ran out of the cottage?', 'The girl woke up and saw the three bears.', 'Goldilocks ran out of the cottage.', 'goldilocks','baby',9,'Goldilocks jumped up and ran out of the cozy cottage as fast as she could.')],
'gingerbread-man': [
(2,'Who baked the gingerbread cookie?', 'She mixed the dough in her kitchen.', 'The little old woman baked the cookie.', 'woman','cow',1,'One day, a little old woman decided to bake a gingerbread man cookie.'),
(2,'Who jumped out of the oven?', 'The little cookie suddenly came alive!', 'The Gingerbread Man jumped out of the oven!', 'gingerbread','cat',2,'When she opened the oven, out jumped the Gingerbread Man!'),
(5,'Who sniffed the gingerbread smell in the field?', 'This big animal was grazing in a field.', 'The cow smelled the gingerbread.', 'cow','fox',4,'A cow in a field sniffed the air.'),
(5,'Who was sleeping in the warm sunshine?', 'This furry animal wanted the cookie for a treat.', 'The cat was sleeping in the sunshine.', 'cat','cow',5,'A cat was sleeping in the warm sunshine.'),
(8,'Who ate the Gingerbread Man?', 'The animal who carried him across the river ate him.', 'The fox ate the Gingerbread Man.', 'fox','cat',9,'Before the Gingerbread Man could thank him, the fox ate the little cookie, every last bite.'),
(8,'Who rode on the fox’s head?', 'The little cookie climbed up as the water got deeper.', 'The Gingerbread Man rode on the fox’s head.', 'gingerbread','woman',8,'The Gingerbread Man climbed up.')],
'shoemaker-and-elves': [
(2,'What did the shoemaker find on his workbench?', 'He could wear them on his feet.', 'He found beautiful shoes on his workbench.', 'shoe','candle',3,'When the shoemaker woke up, a beautiful pair of shoes was waiting on the workbench!'),
(2,'Who was worried about having only a little leather?', 'The man made shoes for his work.', 'The shoemaker was worried about his leather.', 'shoemaker','wife',1,'A poor shoemaker lived with his wife. He was worried.'),
(5,'What did the customer buy?', 'They fit the customer’s feet perfectly.', 'The customer bought the beautiful shoes.', 'shoe','candle',4,'The beautiful shoes fit his feet perfectly.'),
(5,'What did the shoemaker cut to make more shoes?', 'These pieces became the outside of the shoes.', 'The shoemaker cut pieces of leather.', 'leather','shoe',5,'That evening, the shoemaker cut leather for two pairs of shoes and left it on his workbench.'),
(8,'Who secretly made the beautiful shoes?', 'Two tiny helpers came into the workshop at night.', 'The little elves made the shoes!', 'elf','shoemaker',7,'The elves began sewing the leather into beautiful shoes.'),
(8,'Who said the little elves must be cold?', 'She helped her husband make gifts for the elves.', 'The shoemaker’s wife wanted to keep the elves warm.', 'wife','elf',8,'“Those poor elves must be cold,” said the wife.')]
}

BOOKS = [
('lion-and-mouse','The Lion and the Mouse',range(9,14),'Aesop','Gail McIntosh',None),
('city-and-country-mouse','The City Mouse and the Country Mouse',range(17,24),'Aesop','Gail McIntosh',None),
('goldilocks','Goldilocks and the Three Bears',range(27,36),'A traditional fairy tale','Gail McIntosh','Rosie McCormick'),
('gingerbread-man','The Gingerbread Man',range(39,49),'A traditional tale','Gail McIntosh','Rosie McCormick'),
('shoemaker-and-elves','The Shoemaker and the Elves',range(53,62),'A traditional fairy tale','Barbara L. Gibson','Rosie McCormick')]


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source_text = subprocess.check_output(['pdftotext','-layout',str(PDF),'-']).decode().split('\f')
    doc=fitz.open(PDF)
    reading=[];listening=[];art_records=[]
    def source_image(p, index=0):
        xref=doc[p-1].get_images(full=True)[index][0]
        return Image.open(io.BytesIO(doc.extract_image(xref)['image'])).convert('RGB')
    def save_image(im, path):
        im.thumbnail((1400,1400),Image.Resampling.LANCZOS)
        (ROOT/path).parent.mkdir(parents=True,exist_ok=True)
        im.save(ROOT/path,quality=92,method=6)
    for bid,title,nums,author,illustrator,reteller in BOOKS:
        credit=f'Illustrated by {illustrator}. '
        if reteller: credit=f'Retold by {reteller}. '+credit
        else: credit='A fable by Aesop. '+credit
        attribution=credit+LICENSE
        pages=[];image_map={}
        for ix,p in enumerate(nums,1):
            path=f'assets/books/{bid}/art/{bid}_{ix:02d}.webp'
            imgs=[source_image(p,j) for j in range(len(doc[p-1].get_images(full=True)))]
            if len(imgs)>1:
                # Goldilocks' two chair paintings share one text page.
                h=1000;scaled=[]
                for im in imgs:
                    scaled.append(im.resize((round(im.width*h/im.height),h),Image.Resampling.LANCZOS))
                im=Image.new('RGB',(sum(s.width for s in scaled)+50,h),'white');x=0
                for s in scaled:im.paste(s,(x,0));x+=s.width+50
            else:im=imgs[0]
            save_image(im,path);image_map[p]=path
            lines=[line.strip() for line in source_text[p-1].splitlines()]
            lines=['' if re.fullmatch(r'\d+',line) else line for line in lines]
            txt='\n\n'.join(' '.join(t.split()) for t in re.split(r'\n\s*\n','\n'.join(lines)) if t.strip())
            assert txt
            pages.append(dict(sourcePage=p,text=txt,image=path))
        batches=[];start=0
        for end,questions in QUIZZES[bid]:
            assert 1 <= end-start <= 3 and len(questions)==4
            batches.append(dict(startPage=start,endPage=end,questions=questions));start=end
        assert start==len(pages)
        reading.append(dict(id=bid,title=title,author=f'Retold by {reteller}' if reteller else author,language='en',attribution=attribution,original='assets/books/shared/fables_original.pdf',cover=pages[0]['image'],pages=pages,batches=batches))
        crop_paths={}
        for key,(p,j,box,label) in CROPS[bid].items():
            im=source_image(p,j).crop(box)
            scale=620/max(im.size)
            im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
            tile=Image.new('RGB',(680,680),'white');tile.paste(im,((680-im.width)//2,(680-im.height)//2))
            path=f'assets/books/{bid}/art/{bid}_answer_{key}.webp';save_image(tile,path)
            crop_paths[key]=dict(label=label,image=path)
            art_records.append(dict(book=bid,key=key,sourcePage=p,embeddedImage=j,crop=list(box),image=path))
        scenes=[]
        for i,(refs,p,txt) in enumerate(SCENES[bid],1):
            assert 15<=len(txt.split())<=65,(bid,i,len(txt.split()))
            scenes.append(dict(id=f'{bid}-page-{i:02d}',text=txt,image=image_map[p],sourcePages=refs,audio=f'assets/books/{bid}/audio/{bid}-page-{i:02d}.mp3'))
        questions=[]
        for i,(after,prompt,hint,feedback,correct,wrong,ev,sentence) in enumerate(PICTURE_QUESTIONS[bid],1):
            answer=(i-1)%2
            choices=[crop_paths[correct],crop_paths[wrong]] if answer==0 else [crop_paths[wrong],crop_paths[correct]]
            label=crop_paths[correct]['label']
            name = label if correct in {'city-mouse','country-mouse','goldilocks','papa','baby'} else 'the '+label[0].lower()+label[1:]
            guided=f'Let’s do it together. Tap the picture with the green frame. This is {name}.'
            assert sentence in scenes[ev-1]['text'],(bid,i)
            questions.append(dict(id=f'{bid}-question-{i:02d}',afterPage=after,prompt=prompt,hint=hint,guided=guided,feedback=feedback,choices=choices,answer=answer,audio={kind:f'assets/books/{bid}/audio/{bid}-question-{i:02d}-{kind}.mp3' for kind in ['prompt','hint','guided','feedback']},evidenceSceneIds=[f'{bid}-page-{ev:02d}'],evidenceSentence=sentence))
        note='A shortened listening adaptation of this supplied edition, using its original illustrations and cropped picture choices. The complete source reading text is preserved separately.'
        if bid=='gingerbread-man':note+=' Preserves the source ending: the fox eats the Gingerbread Man.'
        if bid=='goldilocks':note+=' Preserves the ending: Goldilocks runs away and the bears never hear from her again.'
        if bid=='shoemaker-and-elves':note+=' Preserves the source’s four-pair surprise after leather for two pairs, and the elves’ final departure.'
        listening.append(dict(id=bid,title=title,language='en',attribution=attribution,original='assets/books/shared/fables_original.pdf',cover=pages[0]['image'],version=1,voice='longanlingxin',model='qwen/qwen-audio-3.0-tts-plus',adaptationNote=note,pages=scenes,questions=questions,completion=dict(text='You listened to the whole story and found the pictures! Here is your story star. You can listen again whenever you like.',audio=f'assets/books/{bid}/audio/{bid}-complete.mp3')))
    for name,data in [('fables-first-reading',reading),('fables-first-listening',listening),('fables-first-art-provenance',art_records)]:
        (OUT/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps([dict(id=b['id'],readingPages=len(b['pages']),batches=len(b['batches']),listeningPages=len(l['pages']),pictureQuestions=len(l['questions'])) for b,l in zip(reading,listening)],indent=2))

if __name__=='__main__':main()
