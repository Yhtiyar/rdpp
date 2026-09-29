"""Prepare the final five tales from the supplied CKLA Classic Tales PDF.

Run with PYTHONPATH=/tmp/readapp-pdf python3 tools/prepare_fables_last.py.
The script owns only its five tales' art and content/new-books/fables-last-*.
Audio preparation and shared catalog integration happen separately.
"""
from collections import Counter
from io import BytesIO
import json
from pathlib import Path
import re

import pymupdf as fitz
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'books/fables-list.pdf'
OUTPUT = ROOT / 'content/new-books'
ART = ROOT / 'assets/books'

SOURCE_TEXT = {
65: 'There once was a little red hen who lived with her friends on a farm. She was not a lazy hen. She worked harder than all of the other animals.',
66: 'The Little Red Hen wanted to plant some grains of wheat. She asked for help, but her friends refused. So she planted the grains herself.',
67: 'In the summertime, the wonderful golden wheat was ready to be harvested. Once again, with no one to help her, the Little Red Hen did all the work.',
68: 'The Little Red Hen had to grind the wheat into flour.\n\nAs usual, her friends did not want to do any hard work. So the Little Red Hen ground the flour herself.',
69: 'The Little Red Hen used the flour to make bread dough. With no one to help her, she kneaded the dough all by herself.',
70: 'The Little Red Hen’s friends had completely abandoned her. So she baked the bread all by herself.\n\nWhen the smell of freshly baked bread rose up into the air, the Little Red Hen’s friends appeared.',
71: 'They were willing to help eat the bread, but the Little Red Hen ate it all by herself. She had done all the work!',
75: 'Once upon a time, there was a woman who was very sad because she did not have any children. One day, she planted a magical seed. That night, the seed grew into a flowering plant.',
76: '“What a beautiful flower,” said the woman as she kissed the petals. At that moment, the flower opened. Inside the flower sat a tiny girl.',
77: 'The girl was no bigger than a thumb. The woman named her Thumbelina.\n\nAt night, Thumbelina slept in a polished walnut shell.',
78: 'One night, a mother toad came and took Thumbelina away.\n\nThe mother toad wanted Thumbelina to marry her son.',
79: 'The mother toad and her son placed Thumbelina on a water lily leaf in the river. Then they set off to plan the wedding.\n\nThumbelina was very sad. She began to cry.',
80: 'A fish heard Thumbelina’s sobs. It nibbled on the stem of the lily pad until the leaf broke free. Thumbelina floated down the river.',
81: 'Summer disappeared, and winter came. Thumbelina was cold.\n\nA field mouse took pity on her. “My dear, you must come home with me,” the field mouse said.',
82: 'Thumbelina spent the rest of the winter in the mouse’s snug burrow. They became good friends.',
83: 'In a burrow nearby lived Mr. Mole. He liked to visit in the evening and hear Thumbelina sing.',
84: 'One evening, while visiting Mr. Mole, Thumbelina found a swallow. The bird was cold and hurt.\n\nThumbelina cared for the swallow and brought him food every day.',
85: 'Mr. Mole had fallen in love with Thumbelina. He wanted to marry her.\n\nThumbelina did not want to marry Mr. Mole. Once again, she was very unhappy.',
86: 'One day, the swallow that Thumbelina had cared for came to help her escape.\n\nTogether, they flew south to warmer lands.',
87: 'In a new land filled with flowers, Thumbelina met a king. He was tiny, too!',
88: 'Thumbelina became the queen. She and the king lived happily ever after.',
93: 'One autumn day, Turtle was talking with the birds. They said, “Winter is coming. Soon it’s going to be very cold here. We’re getting ready to fly south where it is warm.”',
94: '“Can I come with you?” asked Turtle. At first, the birds said, “No!” Turtle pleaded, “There must be some way I can go with you!” Finally, the birds agreed.',
95: '“Use your mouth to hold on tightly to this stick,” the birds explained. Turtle did just that.\n\nThen the two big birds grabbed the ends of the stick. Soon they were all high in the sky—including Turtle.',
96: 'Turtle had never been so high off the ground before. He could look down and see how small everything looked. He wondered how far they had come, and how far they had to go.',
97: 'Turtle tried to get the birds’ attention. He rolled his eyes at them, but they did not notice. He waved his legs too.\n\nFrustrated, Turtle opened his mouth to speak. At that moment he let go of the stick and began to fall! He fell down from the sky and hit the ground hard.',
98: 'Turtle’s body ached. He ached so much he did not notice that his shell had cracked all over. He crawled into a pond and swam down to the bottom.\n\nThere he dug a hole in the mud and slept all winter long.',
99: 'In the spring, Turtle woke up. He was very proud of the cracks on his shell.\n\nEver since then, every turtle’s shell looks like it has cracks all over it.',
103: 'One bright, sunny day, a man and his wife went into the jungle to gather food. When they reached a coconut tree, the man took out his knife. The man climbed up the tree to cut down some delicious coconuts.',
104: 'As the man reached for a coconut, a black fly flitted around his face. He tried to swat the fly, and dropped his knife. “Watch out, Wife!” he cried.',
105: 'The wife jumped out of the way. As she jumped, she kicked a crocodile that was sleeping beneath the tree.\n\nThe angry crocodile’s tail went—swack! swack! swack!',
106: 'Nearby, a jungle bird was looking for bugs to eat. As the crocodile’s tail came down, the bird squawked—scree! scree! scree!\n\nThe bird soared to a branch in a tree and landed right next to a monkey. The monkey was peeling a juicy mango.',
107: 'The monkey, startled by the bird, dropped his mango. It fell on the head of a hippo—splat! splat! splat!',
108: 'The hippo thought he was being attacked by hunters. He tried to escape—stomp! stomp! stomp!\n\nAs he did, he trampled on a bushfowl’s nest. The nest was full of eggs.',
109: '“My eggs are all broken!” wailed the bushfowl. She began to cry—sob! sob! sob! And there she stayed, beside her nest, for many days and nights.\n\nShe did not awaken the sun with her familiar call—kark! kark! kark! So the sky remained dark for several days.',
110: 'The jungle animals were worried. They went to talk to the wise lion.\n\nThe lion gathered all the animals together to find out what had happened.',
111: 'Everyone blamed each other.\n\nThe last to speak was the man. He said, “Wise Lion, I dropped my knife because a black fly was annoying me.”',
112: '“Aha!” said the lion. “Then it is the black fly’s fault!” said the lion. But the black fly answered back. “Buzz! Buzz! Buzz!” said the fly.\n\n“Have you nothing else to say?” asked the lion. The fly ignored the lion and continued saying “buzz! Buzz! Buzz!”',
113: 'The lion was angry with the fly and decided to punish him. “Black Fly!” he bellowed. “Since you refuse to answer, I shall take away your power to talk.”\n\nThe fly tried to speak, but all he could say was, “Buzz! Buzz! Buzz!” To this day, flies all around the world can only say, “Buzz! Buzz! Buzz!”',
114: 'The bushfowl was satisfied. The fly that had caused all the trouble had been punished. And so she agreed to once again call the sun to begin the day.',
119: 'Once upon a time, there were three little pigs. They lived with their mother. One day, Mama Pig said, “You are all grown now. It is time for you to go out into the world and live on your own.”',
120: 'The pigs said good-bye and went on their way.\n\nThe First Little Pig decided to build a house made out of straw. Before long, he was finished. He had time to relax in the shade.',
121: 'The Second Little Pig built a house made out of sticks. He worked hard, but he still had time to relax in the shade.',
122: 'The Third Little Pig decided to build a house made out of bricks. He worked very, very hard.\n\nIt took him a long time to finish building his house. He did not have time to rest in the shade.',
123: 'Soon after, a big, bad wolf came along. He saw the First Little Pig napping in the shade.\n\n‘That little pig would make a tasty bite to eat,’ thought the Big Bad Wolf to himself.',
124: 'The little pig saw the wolf coming and ran inside his straw house. The wolf said, “Little pig, little pig, let me come in.” The little pig replied, “Not by the hair of my chinny-chin-chin.”',
125: '“Then I’ll huff, and I’ll puff, and I’ll blow your house down,” said the Big Bad Wolf. And that is what he did! As the straw blew everywhere, the First Little Pig ran away.',
126: 'The Big Bad Wolf soon came across the Second Little Pig home made of sticks. The Big Bad Wolf knocked on the door and asked to come in.\n\n“Not by the hair of my chinny-chin-chin,” said the Second Little Pig. “Then I’ll huff, and I’ll puff, and I’ll blow your house down,” replied the wolf.',
127: 'The two little pigs ran to their brother’s brick house. Right behind them was the wolf! Once again the wolf asked to come inside. “Not by the hair of my chinny-chin-chin,” replied the Third Little Pig.\n\nThe wolf did not give up. He climbed up onto the roof. He jumped down the chimney.',
128: 'And he fell right into a pot of water that was heating on the fire. That water was so hot that the wolf jumped out and ran away.\n\nThe Three Little Pigs lived happily ever after.',
}

BOOKS = [
 ('little-red-hen', 'The Little Red Hen', 'Retold by Rosie McCormick', range(65,72), 'Gail McIntosh'),
 ('thumbelina', 'Thumbelina', 'Hans Christian Andersen; retold by Rosie McCormick', range(75,89), 'Gail McIntosh'),
 ('turtle-shell', 'How Turtle Cracked His Shell', 'Joseph Bruchac; retold by Rosie McCormick', range(93,100), 'Gail McIntosh and Barbara L. Gibson'),
 ('why-flies-buzz', 'Why Flies Buzz', 'Retold by Rosie McCormick', range(103,115), 'Gail McIntosh; illustration on PDF page 113 by Barbara L. Gibson'),
 ('three-little-pigs', 'The Three Little Pigs', 'Retold by Rosie McCormick', range(119,129), 'Gail McIntosh'),
]

LICENSE = ('This work is based on an original work of the Core Knowledge® Foundation made available through licensing under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License. This does not in any way imply that the Core Knowledge Foundation endorses this work. Copyright © 2014 Core Knowledge Foundation. Source: Classic Tales Big Book, shared by Free Kids Books (freekidsbooks.org). Noncommercial use and ShareAlike terms apply: https://creativecommons.org/licenses/by-nc-sa/3.0/. Original notices retained in assets/books/shared/fables_original.pdf. ')


def extract_illustration(doc, number):
    page = doc[number - 1]
    blocks = [b for b in page.get_text('dict')['blocks'] if b['type'] == 1]
    if len(blocks) == 1:
        return Image.open(BytesIO(blocks[0]['image'])).convert('RGB')
    # These three PDF pages have tiled illustrations. Render their original
    # placement/masks after removing the separately encoded text, preserving art.
    work = fitz.open()
    work.insert_pdf(doc, from_page=number - 1, to_page=number - 1)
    page = work[0]
    crop = fitz.Rect()
    for b in blocks:
        box = fitz.Rect(b['bbox']) & page.rect
        if not box.is_empty:
            crop |= box
    for block in page.get_text('dict')['blocks']:
        if block['type'] == 0:
            for line in block['lines']:
                page.add_redact_annot(fitz.Rect(line['bbox']), fill=False)
    page.apply_redactions(images=0, graphics=0)
    pix = page.get_pixmap(matrix=fitz.Matrix(1.3,1.3), clip=crop, alpha=False)
    return Image.frombytes('RGB', (pix.width,pix.height), pix.samples)


def image_path(book_id, index):
    return f'assets/books/{book_id}/art/{book_id}_{index:02d}.webp'


def word_tokens(text):
    return re.findall(r'\w+|[^\w\s]', text, flags=re.UNICODE)


def q(prompt, options, answer, hint, explanation):
    assert len(options) == 4 and 0 <= answer < 4
    return dict(prompt=prompt, options=options, answer=answer, hint=hint, explanation=explanation)


READING = {}

# (narration, source PDF pages, illustrated source page). The first two entries
# are independent because one listening scene may combine two source pages.
SCENES = {
'little-red-hen': [
 ('A little red hen lived on a farm with her friends. She worked hard. One day, she wanted to plant wheat. Her friends would not help, so the hen planted the little grains herself.', [65,66],66),
 ('The wheat grew tall. In summer, it was golden and ready to gather. The little red hen asked for help again. Nobody came to help her, so she gathered all the wheat herself.', [67],67),
 ('Now the hen needed flour. She ground the wheat into flour. Her friends still did not want to work. The little red hen kept going and did this job herself, too.', [68],68),
 ('The little red hen mixed her flour into bread dough. She pushed and folded the dough. That is called kneading. Her friends would not help, so she kneaded the dough all by herself.', [69],69),
 ('The hen baked her bread. Soon, a lovely smell drifted through the air. Her friends smelled the freshly baked bread. At last, they came to see what she had made.', [70],70),
 ('Now the hen’s friends wanted to help eat the bread! But the little red hen had done all the work. She ate the bread herself. She had planted, gathered, ground, kneaded, and baked it.', [71],71),
],
'thumbelina': [
 ('A woman wished for a child. She planted a magical seed, and a flower grew. When she kissed the petals, the flower opened. A tiny girl was sitting inside!', [75,76],76),
 ('The girl was no bigger than a thumb. The woman named her Thumbelina. At bedtime, Thumbelina curled up in a polished walnut shell. It was a little bed for a very little girl.', [77],77),
 ('One night, a mother toad carried Thumbelina away. She wanted Thumbelina to marry her son. The toads left the little girl on a lily leaf in the river. Thumbelina felt sad and cried.', [78,79],79),
 ('A fish heard Thumbelina crying. It nibbled the stem under her lily leaf. Nibble, nibble! The stem broke, and the leaf floated away. Thumbelina sailed down the river, away from the toads.', [80],80),
 ('Winter came, and Thumbelina was cold. A kind field mouse invited her inside. Thumbelina stayed in the mouse’s warm burrow for the rest of winter. The little girl and the mouse became good friends.', [81,82],82),
 ('Mr. Mole lived in a nearby burrow. In the evenings, he came to visit the field mouse and Thumbelina. He liked to sit and listen to the little girl sing.', [83],83),
 ('One evening, Thumbelina found a swallow at Mr. Mole’s home. The bird was cold and hurt. Thumbelina cared for him. Every day, she brought the swallow food to help him get better.', [84],84),
 ('Mr. Mole wanted to marry Thumbelina, but she did not want to marry him. Then the swallow returned to help her escape. Thumbelina climbed onto his back. Together, they flew south to warmer lands.', [85,86],86),
 ('The swallow brought Thumbelina to a land full of flowers. There she met a king who was tiny, just like her. Thumbelina became the queen. She and the king lived happily ever after.', [87,88],88),
],
'turtle-shell': [
 ('One autumn day, Turtle talked with the birds. Winter was coming. The birds were getting ready to fly south, where it was warm. Turtle wanted to go with them. At last, the birds agreed.', [93,94],94),
 ('The birds brought a stick. Turtle held the middle tightly in his mouth. Two big birds held the ends. Up they flew, carrying Turtle into the sky. He had to keep holding on!', [95],95),
 ('Turtle looked down from high in the sky. Everything below looked so small! He wondered how far they had traveled. He also wondered how much farther they still had to go.', [96],96),
 ('Turtle wanted the birds to look at him. He rolled his eyes and waved his legs. Then he opened his mouth to speak. He let go of the stick and fell hard onto the ground.', [97],97),
 ('Turtle ached all over. His shell had cracked, but he did not notice yet. He crawled into a pond and swam to the bottom. There he dug a hole in the mud and slept all winter.', [98],98),
 ('Spring came, and Turtle woke up. Now he saw the cracks on his shell, and he felt proud of them. This story says that ever since then, turtle shells have looked as though they have cracks.', [99],99),
],
'why-flies-buzz': [
 ('One sunny day, a man and his wife went into the jungle to find food. The man climbed a coconut tree. He carried a knife to cut down the coconuts.', [103],103),
 ('A black fly buzzed around the man’s face. The man tried to swat it away. His knife slipped and fell! “Watch out!” he called to his wife down below.', [104],104),
 ('The wife jumped out of the way. As she jumped, she kicked a sleeping crocodile under the tree. The crocodile woke up angry. Swack, swack! Its great tail swung through the air.', [105],105),
 ('A bird flew away from the crocodile’s swinging tail. It landed beside a monkey with a mango. The startled monkey dropped his fruit. Splat! The mango landed on a hippo’s head.', [106,107],107),
 ('The hippo thought hunters were after him. He ran away, stomping through the jungle. His feet trampled a bushfowl’s nest. The eggs inside the nest broke, and the bushfowl was very sad.', [108,109],108),
 ('The bushfowl stayed beside her broken eggs and cried. In this story, her morning call woke the sun. Now she did not call. The sky stayed dark for several days.', [109],109),
 ('The worried animals went to the wise lion. The lion gathered everyone to hear what had happened. Everyone blamed someone else. Last, the man explained that a black fly had made him drop his knife.', [110,111],110),
 ('The lion asked the fly to answer. “Buzz, buzz, buzz!” said the fly. The angry lion took away the fly’s power to talk. After that, the fly could only buzz. That is how this tale explains a fly’s sound.', [112,113],112),
 ('The bushfowl heard that the fly had been punished. She agreed to call the sun again. Her call welcomed the morning, and the day could begin. The fly still could only say, “Buzz, buzz, buzz!”', [113,114],114),
],
'three-little-pigs': [
 ('Three little pigs lived with Mama Pig. One day, she told them they were grown and ready to live on their own. The pigs said goodbye and set off to build their homes.', [119,120],119),
 ('The first little pig built a house from straw. He finished quickly. Now he had time to rest in the shade. His new straw house stood nearby.', [120],120),
 ('The second little pig built a house from sticks. He worked hard to put his house together. When he finished, he still had time to rest in the shade.', [121],121),
 ('The third little pig chose bricks for his house. Building it took a long time. He worked very, very hard. There was no time for him to rest in the shade.', [122],122),
 ('A hungry wolf came along. The first pig hurried inside his straw house. “Let me come in,” said the wolf. “Not by the hair of my chinny-chin-chin!” said the little pig.', [123,124],124),
 ('“Then I’ll huff, and I’ll puff!” said the wolf. He blew the straw house down. Straw flew everywhere. The first little pig ran away as fast as he could.', [125],125),
 ('The wolf came to the stick house next. The second pig would not let him in. The wolf threatened to blow this house down, too. The two little pigs ran to their brother’s brick house.', [126,127],126),
 ('The wolf followed the pigs to the brick house. The third pig would not open the door. So the wolf climbed onto the roof and jumped down the chimney.', [127],127),
 ('Down the chimney fell the wolf, right into a pot of hot water! He jumped straight out and ran away. The three little pigs were safe. They lived happily ever after.', [128],128),
],
}

# Source illustration crops, in normalized coordinates. All choices are square
# canvases containing the crop without stretching. Source credits apply.
CROPS = {
 'little-red-hen-hen': ('little-red-hen',5,(.15,.02,.88,.98)),
 'little-red-hen-bread': ('little-red-hen',6,(.18,.21,.88,.87)),
 'little-red-hen-wheat': ('little-red-hen',3,(.31,.01,.84,.40)),
 'thumbelina-flower': ('thumbelina',2,(0,0,1,1)),
 'thumbelina-bed': ('thumbelina',3,(0,0,1,1)),
 'thumbelina-toad': ('thumbelina',5,(.52,.01,.84,.375)),
 'thumbelina-fish': ('thumbelina',6,(.49,.66,.96,1)),
 'thumbelina-mouse': ('thumbelina',9,(.665,.085,.915,.43)),
 'thumbelina-mole': ('thumbelina',9,(.44,.09,.70,.37)),
 'thumbelina-swallow': ('thumbelina',12,(0,0,1,1)),
 'thumbelina-king': ('thumbelina',13,(.055,.35,.445,.64)),
 'turtle-shell-bird': ('turtle-shell',2,(.20,.01,.52,.29)),
 'turtle-shell-turtle': ('turtle-shell',7,(.20,.22,.89,.88)),
 'turtle-shell-pond': ('turtle-shell',6,(0,0,1,1)),
 'turtle-shell-sky': ('turtle-shell',4,(0,0,1,1)),
 'why-flies-buzz-fly': ('why-flies-buzz',10,(.10,.10,.97,1)),
 'why-flies-buzz-lion': ('why-flies-buzz',8,(.55,.25,.735,.65)),
 'why-flies-buzz-crocodile': ('why-flies-buzz',4,(0,.03,.72,.94)),
 'why-flies-buzz-monkey': ('why-flies-buzz',5,(.48,.05,.98,.71)),
 'why-flies-buzz-bushfowl': ('why-flies-buzz',7,(.10,.14,.86,.70)),
 'why-flies-buzz-hippo': ('why-flies-buzz',6,(.08,.02,.80,.99)),
 'three-little-pigs-mother': ('three-little-pigs',1,(.10,.12,.36,.42)),
 'three-little-pigs-wolf': ('three-little-pigs',5,(.70,.19,.94,.65)),
 'three-little-pigs-straw': ('three-little-pigs',2,(.16,.31,.65,.82)),
 'three-little-pigs-sticks': ('three-little-pigs',3,(.10,.02,.92,.93)),
 'three-little-pigs-bricks': ('three-little-pigs',4,(.05,.48,.68,.93)),
 'three-little-pigs-third': ('three-little-pigs',4,(.59,.03,.99,.98)),
 'three-little-pigs-first': ('three-little-pigs',2,(.71,.38,.95,.84)),
}


def choice(label, name):
    book_id = CROPS[name][0]
    return dict(label=label, image=f'assets/books/{book_id}/art/{name}.webp')


def lq(prompt, hint, feedback, labels, answer, evidence_scene, evidence_sentence):
    return dict(prompt=prompt, hint=hint, feedback=feedback,
                choices=[choice(*v) for v in labels], answer=answer,
                evidenceScene=evidence_scene, evidenceSentence=evidence_sentence)


LISTENING_QUESTIONS = {
'little-red-hen': [
 lq('Who planted the grains? Tap the helper.', 'She had red feathers and worked hard on the farm.', 'Yes! The little red hen planted the grains herself.', [('Little red hen','little-red-hen-hen'),('Bread','little-red-hen-bread')],0,1,'Her friends would not help, so the hen planted the little grains herself.'),
 lq('What did the hen gather in summer?', 'It grew tall and golden in the field.', 'You found the wheat! The hen gathered it herself.', [('Bread','little-red-hen-bread'),('Wheat','little-red-hen-wheat')],1,2,'The wheat grew tall. In summer, it was golden and ready to gather.'),
 lq('Who kneaded the dough?', 'She pushed and folded the dough all by herself.', 'The little red hen kneaded the dough!', [('Little red hen','little-red-hen-hen'),('Wheat','little-red-hen-wheat')],0,4,'The little red hen mixed her flour into bread dough. She pushed and folded the dough.'),
 lq('What did the hen bake and eat?', 'It smelled lovely when it came out of the oven.', 'Yes! She baked the bread and ate it herself.', [('Little red hen','little-red-hen-hen'),('Bread','little-red-hen-bread')],1,5,'The hen baked her bread.'),
],
'thumbelina': [
 lq('Where did the woman first find the tiny girl?', 'The petals opened, and there she was!', 'Thumbelina was inside a flower!', [('Thumbelina in a flower','thumbelina-flower'),('Thumbelina in her walnut bed','thumbelina-bed')],0,1,'When she kissed the petals, the flower opened. A tiny girl was sitting inside!'),
 lq('Who carried Thumbelina away in the night?', 'It was the mother of the little toad.', 'A mother toad carried Thumbelina away.', [('Fish','thumbelina-fish'),('Toad','thumbelina-toad')],1,3,'One night, a mother toad carried Thumbelina away.'),
 lq('Who nibbled the lily stem to help Thumbelina?', 'This helper swam in the river.', 'The fish nibbled the stem so Thumbelina could float away!', [('Fish','thumbelina-fish'),('Field mouse','thumbelina-mouse')],0,4,'A fish heard Thumbelina crying. It nibbled the stem under her lily leaf.'),
 lq('Who shared a warm home with Thumbelina in winter?', 'This kind little animal invited her into a burrow.', 'The field mouse shared her warm home with Thumbelina.', [('Mr. Mole','thumbelina-mole'),('Field mouse','thumbelina-mouse')],1,5,'A kind field mouse invited her inside.'),
 lq('Who carried Thumbelina through the sky?', 'She had cared for this bird when he was hurt.', 'The swallow flew south with Thumbelina!', [('Swallow','thumbelina-swallow'),('Mr. Mole','thumbelina-mole')],0,8,'Then the swallow returned to help her escape. Thumbelina climbed onto his back. Together, they flew south to warmer lands.'),
 lq('Who did Thumbelina meet in the land of flowers?', 'He was tiny like her, and she became his queen.', 'Thumbelina met the tiny king!', [('Field mouse','thumbelina-mouse'),('Tiny king','thumbelina-king')],1,9,'There she met a king who was tiny, just like her.'),
],
'turtle-shell': [
 lq('Who was getting ready to fly south?', 'They had wings and wanted to find warm weather.', 'The birds were getting ready to fly south!', [('Bird','turtle-shell-bird'),('Turtle','turtle-shell-turtle')],0,1,'The birds were getting ready to fly south, where it was warm.'),
 lq('Who held the stick in his mouth?', 'He had a shell and wanted to fly with the birds.', 'Turtle held the stick in his mouth!', [('Bird','turtle-shell-bird'),('Turtle','turtle-shell-turtle')],1,2,'Turtle held the middle tightly in his mouth.'),
 lq('Where did Turtle sleep through winter?', 'He swam down and dug a hole in the mud.', 'Turtle slept at the bottom of the pond.', [('Turtle under the pond water','turtle-shell-pond'),('Turtle flying in the sky','turtle-shell-sky')],0,5,'He crawled into a pond and swam to the bottom. There he dug a hole in the mud and slept all winter.'),
 lq('Who woke up with cracks on his shell?', 'He had slept in the pond until spring.', 'Turtle woke up and saw the cracks on his shell.', [('Bird','turtle-shell-bird'),('Turtle','turtle-shell-turtle')],1,6,'Spring came, and Turtle woke up. Now he saw the cracks on his shell, and he felt proud of them.'),
],
'why-flies-buzz': [
 lq('Who buzzed around the man’s face?', 'It was a tiny insect with wings.', 'The black fly buzzed around the man!', [('Black fly','why-flies-buzz-fly'),('Lion','why-flies-buzz-lion')],0,2,'A black fly buzzed around the man’s face.'),
 lq('Who was sleeping under the coconut tree?', 'It woke up and swung a long tail.', 'The crocodile was sleeping under the tree.', [('Monkey','why-flies-buzz-monkey'),('Crocodile','why-flies-buzz-crocodile')],1,3,'As she jumped, she kicked a sleeping crocodile under the tree.'),
 lq('Who dropped the mango?', 'This animal was sitting beside the bird in a tree.', 'The monkey dropped the mango onto the hippo!', [('Monkey','why-flies-buzz-monkey'),('Hippo','why-flies-buzz-hippo')],0,4,'The startled monkey dropped his fruit.'),
 lq('Who stayed beside the broken eggs?', 'She was a bird with a nest.', 'The bushfowl stayed beside her broken eggs.', [('Hippo','why-flies-buzz-hippo'),('Bushfowl','why-flies-buzz-bushfowl')],1,6,'The bushfowl stayed beside her broken eggs and cried.'),
 lq('Who gathered everyone to hear what happened?', 'This wise animal had a big mane.', 'The lion gathered everyone together.', [('Lion','why-flies-buzz-lion'),('Black fly','why-flies-buzz-fly')],0,7,'The lion gathered everyone to hear what had happened.'),
 lq('Who called the sun again at the end?', 'It was the bird who had been sad about her eggs.', 'The bushfowl called the sun, and the day could begin!', [('Monkey','why-flies-buzz-monkey'),('Bushfowl','why-flies-buzz-bushfowl')],1,9,'The bushfowl heard that the fly had been punished. She agreed to call the sun again.'),
],
'three-little-pigs': [
 lq('Who told the pigs they were ready to live on their own?', 'She was the pigs’ mother.', 'Mama Pig told her little pigs they were ready.', [('Mama Pig','three-little-pigs-mother'),('Wolf','three-little-pigs-wolf')],0,1,'Three little pigs lived with Mama Pig. One day, she told them they were grown and ready to live on their own.'),
 lq('Which house did the first little pig build?', 'His house was made of golden straw.', 'The first little pig built the straw house.', [('Stick house','three-little-pigs-sticks'),('Straw house','three-little-pigs-straw')],1,2,'The first little pig built a house from straw.'),
 lq('Who worked hard to build with bricks?', 'It was the third little pig.', 'The third little pig built his house with bricks.', [('Third little pig','three-little-pigs-third'),('Wolf','three-little-pigs-wolf')],0,4,'The third little pig chose bricks for his house.'),
 lq('Who huffed and puffed the straw house down?', 'He wanted the first pig to let him in.', 'The wolf blew the straw house down.', [('First little pig','three-little-pigs-first'),('Wolf','three-little-pigs-wolf')],1,6,'“Then I’ll huff, and I’ll puff!” said the wolf. He blew the straw house down.'),
 lq('Which house did the two pigs run to?', 'Their brother had built it with bricks.', 'They ran to their brother’s brick house.', [('Brick house','three-little-pigs-bricks'),('Straw house','three-little-pigs-straw')],0,7,'The two little pigs ran to their brother’s brick house.'),
 lq('Who jumped out of the hot water and ran away?', 'He had come down the chimney.', 'The wolf ran away. The three pigs were safe!', [('Third little pig','three-little-pigs-third'),('Wolf','three-little-pigs-wolf')],1,9,'Down the chimney fell the wolf, right into a pot of hot water! He jumped straight out and ran away.'),
],
}

ADAPTATION = {
 'little-red-hen': 'A shortened listening edition using the original illustrations and crops for picture answers. Preserves the ending: the hen eats the bread herself after doing all the work.',
 'thumbelina': 'A shortened listening edition using the original illustrations and crops for picture answers. Combines source pages while preserving the toad and mole marriage proposals, the fish and swallow rescues, and Thumbelina becoming queen.',
 'turtle-shell': 'A shortened listening edition using the original illustrations and crops for picture answers. Preserves Turtle’s fall, cracked shell, winter in the pond, and spring awakening. The explanation of shell markings is explicitly presented as the story’s explanation.',
 'why-flies-buzz': 'A shortened listening edition using the original illustrations and crops for picture answers. Preserves the full chain of accidents, broken eggs, the lion taking away the fly’s speech, and the bushfowl calling the sun again. The explanations of sunlight and buzzing are presented as events in the tale.',
 'three-little-pigs': 'A shortened listening edition using the original illustrations and crops for picture answers. Preserves all three building materials and the source ending: the wolf lands in hot water, jumps out, and runs away; all three pigs live happily ever after.',
}


def attribution(book_id, illustrator):
    credit = f'Retold by Rosie McCormick. Illustrated by {illustrator}. '
    if book_id == 'thumbelina':
        credit += 'Original story by Hans Christian Andersen. '
    if book_id == 'turtle-shell':
        credit += ('Adapted by Rosie McCormick from How the Turtle Flew South for the Winter by Joseph Bruchac, courtesy of Fulcrum Publishing, Inc. ')
    else:
        credit += 'Collection writing credits also name Linda Bevilacqua and Susan Hitchcock. '
    return LICENSE + credit


def prepare_listening():
    books, evidence = [], []
    for book_id, title, author, numbers, illustrator in BOOKS:
        source_numbers = list(numbers)
        pages = []
        for i, (text, refs, illustrated) in enumerate(SCENES[book_id], 1):
            assert 15 <= len(text.split()) <= 65, (book_id,i,len(text.split()))
            page_id = f'{book_id}-page-{i:02d}'
            pages.append(dict(id=page_id, text=text,
                              image=image_path(book_id,source_numbers.index(illustrated)+1),
                              sourcePages=refs, audio=f'assets/books/{book_id}/audio/{page_id}.mp3'))
        questions = []
        for i, authored in enumerate(LISTENING_QUESTIONS[book_id],1):
            data = authored.copy()
            source_scene = data.pop('evidenceScene')
            source_sentence = data.pop('evidenceSentence')
            qid = f'{book_id}-question-{i:02d}'
            after = ((i-1)//2)*3+2
            assert after-1 <= source_scene <= after+1
            assert source_sentence in pages[source_scene-1]['text']
            correct_label = data['choices'][data['answer']]['label']
            questions.append(dict(id=qid, afterPage=after, **data,
                 guided=f'Let’s do it together. Tap the picture with the green frame. It shows {correct_label.lower()}.',
                 audio={kind:f'assets/books/{book_id}/audio/{qid}-{kind}.mp3' for kind in ('prompt','hint','guided','feedback')}))
            evidence.append(dict(questionId=qid, sceneId=pages[source_scene-1]['id'], sentence=source_sentence))
        assert len(pages) in (6,9)
        assert len(questions) == len(pages)//3*2
        books.append(dict(id=book_id,title=title,language='en',attribution=attribution(book_id,illustrator),
            original='assets/books/shared/fables_original.pdf',cover=image_path(book_id,1),version=1,
            voice='longanlingxin',model='qwen/qwen-audio-3.0-tts-plus',adaptationNote=ADAPTATION[book_id],
            pages=pages,questions=questions,
            completion=dict(text=f'You listened to {title} and found the pictures! Here is your story star. You can listen again whenever you like.',audio=f'assets/books/{book_id}/audio/{book_id}-complete.mp3')))
    return books,evidence


def prepare_art(doc):
    for book_id,title,author,numbers,illustrator in BOOKS:
        for i,source_page in enumerate(numbers,1):
            raw = re.sub(r'^\d+\s*','',doc[source_page-1].get_text().strip())
            assert Counter(word_tokens(raw)) == Counter(word_tokens(SOURCE_TEXT[source_page])), source_page
            im = extract_illustration(doc,source_page)
            im.thumbnail((1300,1300))
            (ROOT/image_path(book_id,i)).parent.mkdir(parents=True,exist_ok=True)
            im.save(ROOT/image_path(book_id,i),quality=91)
    for name,(book_id,index,bbox) in CROPS.items():
        im=Image.open(ROOT/image_path(book_id,index)).convert('RGB')
        crop=im.crop(tuple(round(v*(im.width if i%2==0 else im.height)) for i,v in enumerate(bbox)))
        crop=ImageOps.contain(crop,(560,560),method=Image.Resampling.LANCZOS)
        canvas=Image.new('RGB',(600,600),'white')
        canvas.paste(crop,((600-crop.width)//2,(600-crop.height)//2))
        canvas.save(ART/book_id/'art'/f'{name}.webp',quality=93)


def batch(start, end, *questions):
    assert 1 <= end-start <= 3 and len(questions) == 4
    return dict(startPage=start,endPage=end,questions=list(questions))


READING.update({
'little-red-hen': [
 batch(0,2,
  q('Where did the little red hen live?', ['On a farm','In a castle','Beside the sea','In a cave'],0,'Her home had other animals.','The hen lived with her friends on a farm.'),
  q('What did the hen want to plant?', ['Apple trees','Grains of wheat','Flower bulbs','Carrots'],1,'These grains would eventually become bread.','She wanted to plant some grains of wheat.'),
  q('How did her friends respond when she asked for help?', ['They all helped.','They brought tools.','They refused.','They planted the grains first.'],2,'The hen had to do the planting herself.','Her friends refused to help her plant.'),
  q('How did the hen compare with the other animals?', ['She slept longer.','She was the laziest.','She never worked.','She worked harder.'],3,'The story says she was not lazy.','She worked harder than all the other animals.')),
 batch(2,4,
  q('When was the wheat ready to harvest?', ['In winter','In summer','Before it grew','During autumn snow'],1,'The story names a warm season.','The golden wheat was ready in the summertime.'),
  q('Who harvested the wheat?', ['The pig','All the friends','The hen by herself','A farmer'],2,'Again, nobody would help.','The Little Red Hen did all the harvesting work herself.'),
  q('What did the hen need to make from the wheat?', ['Soup','Honey','Jam','Flour'],3,'She had to grind the wheat.','The hen needed to grind the wheat into flour.'),
  q('Why did the hen grind the wheat herself?', ['Her friends did not want to work.','She had lost the wheat.','The flour was already baked.','Her friends were away at school.'],0,'Her friends acted as they had when she planted.','Her friends did not want to do any hard work.')),
 batch(4,7,
  q('What did the hen make from the flour?', ['A nest','Porridge','Bread dough','A cake'],2,'She pushed and folded it before baking.','She used the flour to make bread dough and kneaded it.'),
  q('What brought the hen’s friends back?', ['The rain','A bell','The sound of singing','The smell of fresh bread'],3,'Something delicious rose into the air.','Her friends appeared when they smelled the freshly baked bread.'),
  q('What were the friends finally willing to help with?', ['Eating the bread','Planting the wheat','Grinding the wheat','Kneading the dough'],0,'They arrived after the work was finished.','They were willing to help eat the bread.'),
  q('Why did the hen eat all the bread herself?', ['There was no bread left.','She had done all the work.','Her friends disliked bread.','She could not find the flour.'],1,'Remember who planted, ground, kneaded, and baked.','The hen ate it herself because she had done all the work.')),
],
'thumbelina': [
 batch(0,3,
  q('Why was the woman sad at the beginning?', ['She did not have any children.','She had lost a crown.','Her garden was flooded.','She had no winter coat.'],0,'She wished for someone small to care for.','The woman was sad because she did not have any children.'),
  q('What grew from the magical seed?', ['A walnut tree','A flowering plant','A giant beanstalk','A lily leaf in a river'],1,'The woman later kissed its petals.','The seed grew into a flowering plant that night.'),
  q('What happened when the woman kissed the petals?', ['The flower disappeared.','A toad jumped out.','The flower opened to reveal a tiny girl.','The seed fell into water.'],2,'Someone was sitting inside the flower.','The flower opened, and a tiny girl was inside.'),
  q('Where did Thumbelina sleep at night?', ['In a teacup','Under a mushroom','In a shoe','In a polished walnut shell'],3,'Her bed was made from part of a nut.','Thumbelina slept in a polished walnut shell.')),
 batch(3,6,
  q('Why did the mother toad take Thumbelina?', ['To teach her to swim','To have her marry the toad’s son','To plant more flowers','To sing for the king'],1,'The toads later left to plan a wedding.','The mother toad wanted Thumbelina to marry her son.'),
  q('Where did the toads leave Thumbelina?', ['In a walnut bed','Inside a cave','On a water lily leaf','Under a tree'],2,'She was in the river.','The toads placed Thumbelina on a water lily leaf in the river.'),
  q('How did Thumbelina feel on the lily leaf?', ['Excited to marry','Sleepy and peaceful','Angry with the fish','Sad enough to cry'],3,'The fish heard her sobs.','Thumbelina was very sad and began to cry.'),
  q('How did the fish help Thumbelina?', ['It nibbled through the lily stem.','It carried her to the mouse.','It called the swallow.','It built a boat from wood.'],0,'The leaf broke free and floated away.','The fish nibbled the stem until the leaf broke free.')),
 batch(6,9,
  q('Why did Thumbelina need help when winter came?', ['She had lost her crown.','She could not sing.','She was cold.','She wanted to fly.'],2,'The season had changed from summer.','Winter came, and Thumbelina was cold.'),
  q('Who invited Thumbelina home?', ['The king','The mother toad','The swallow','A field mouse'],3,'This animal had a snug burrow.','A field mouse took pity on her and invited her home.'),
  q('How long did Thumbelina stay with the mouse?', ['The rest of winter','Only one hour','All her life','Until the next evening'],0,'Their friendship grew during the cold season.','She spent the rest of winter in the mouse’s snug burrow.'),
  q('What did Mr. Mole like to hear?', ['The fish splashing','Thumbelina singing','The toads arguing','The wind blowing'],1,'He visited in the evenings to listen.','Mr. Mole liked to hear Thumbelina sing.')),
 batch(9,12,
  q('What was wrong with the swallow Thumbelina found?', ['It had lost a seed.','It wanted a crown.','It was too warm.','It was cold and hurt.'],3,'Thumbelina needed to care for the bird.','The swallow was cold and hurt.'),
  q('How did Thumbelina care for the swallow?', ['She brought him food every day.','She gave him a wedding ring.','She sent him to the toads.','She taught him to dig.'],0,'She returned daily with something he could eat.','Thumbelina cared for the swallow and brought food every day.'),
  q('How did Thumbelina feel about marrying Mr. Mole?', ['She was delighted.','She did not want to marry him.','She had already agreed happily.','She never heard the proposal.'],1,'The proposal made her unhappy again.','Thumbelina did not want to marry Mr. Mole.'),
  q('How did Thumbelina escape?', ['She swam with the fish again.','The field mouse carried her.','She flew south with the swallow.','She hid in a walnut shell.'],2,'The bird she had helped returned.','The swallow helped her escape, and they flew south to warmer lands.')),
 batch(12,14,
  q('What filled the new land?', ['Flowers','Icebergs','Tall buildings','Desert sand'],0,'The new setting matched the flower where she first appeared.','Thumbelina arrived in a land filled with flowers.'),
  q('Whom did Thumbelina meet there?', ['A giant','A king','The mother toad','Mr. Mole'],1,'She later became a queen.','Thumbelina met a king in the new land.'),
  q('What was special about the king’s size?', ['He was taller than a tree.','He was bigger than the swallow.','He was tiny, too.','He changed size every day.'],2,'He and Thumbelina had something in common.','The king was tiny, just like Thumbelina.'),
  q('How did Thumbelina’s story end?', ['She returned to the toads.','She married Mr. Mole.','She stayed alone in the river.','She became queen and lived happily with the king.'],3,'Her last home was in the flower-filled land.','Thumbelina became queen, and she and the king lived happily ever after.')),
],
'turtle-shell': [
 batch(0,3,
  q('Why were the birds getting ready to fly south?', ['Winter was coming, and it was warm in the south.','They wanted to find a larger stick.','Turtle had lost his pond.','It was too warm where they lived.'],0,'They told Turtle it would soon be cold.','The birds wanted to fly south to warm weather before winter.'),
  q('What did Turtle ask the birds?', ['To stay all winter','To let him come with them','To find a new shell','To dig a hole in the mud'],1,'He wanted to join their journey.','Turtle asked whether he could come with the birds.'),
  q('How did Turtle hold the stick?', ['With his back legs','With his shell','With his mouth','With a rope'],2,'The birds told him to hold on tightly.','Turtle used his mouth to hold the stick.'),
  q('How many big birds held the ends of the stick?', ['One','Four','Three','Two'],3,'Each end had a bird.','Two big birds grabbed the ends of the stick and carried Turtle.')),
 batch(3,5,
  q('How did everything below look to Turtle?', ['Huge','Small','Completely dark','Covered in snow'],1,'He had never been so high before.','From high in the sky, Turtle saw how small everything looked.'),
  q('What did Turtle wonder about the journey?', ['Whether his friends could swim','Where his shell had gone','How far they had come and still had to go','Why it was spring'],2,'He wanted to know about the distance.','He wondered how far they had come and how much farther they had to go.'),
  q('How did Turtle first try to get the birds’ attention?', ['He dropped a stone.','He shouted their names.','He shook a branch.','He rolled his eyes and waved his legs.'],3,'He tried movements before speaking.','Turtle rolled his eyes at the birds and waved his legs.'),
  q('Why did Turtle fall?', ['He opened his mouth and let go of the stick.','A bird pecked his shell.','The stick turned into water.','He jumped into the pond on purpose.'],0,'His mouth had been holding him up.','When Turtle opened his mouth to speak, he released the stick and fell.')),
 batch(5,7,
  q('What happened to Turtle’s shell when he fell?', ['It turned blue.','It disappeared.','It cracked all over.','It grew wings.'],2,'He ached too much to notice at first.','Turtle’s shell had cracked all over.'),
  q('Where did Turtle spend the winter?', ['In a nest','On a warm beach','In a tree','In a muddy hole at the bottom of a pond'],3,'He crawled into water and swam down.','He dug a hole in the mud at the pond bottom and slept there all winter.'),
  q('When did Turtle wake up?', ['In spring','That same evening','At the start of winter','Before the fall'],0,'He slept through the cold season.','Turtle woke up in the spring.'),
  q('How did Turtle feel about the cracks when he woke?', ['He was ashamed.','He was proud.','He could not see them.','He was angry with the fish.'],1,'He liked the new appearance of his shell.','Turtle was very proud of the cracks on his shell.')),
],
'why-flies-buzz': [
 batch(0,3,
  q('Why did the man and his wife go into the jungle?', ['To gather food','To meet the lion','To build a house','To find a lost nest'],0,'The man climbed a coconut tree.','They went into the jungle to gather food.'),
  q('What did the man take up the coconut tree?', ['A fishing net','A knife','A ladder','A mango'],1,'He needed to cut down coconuts.','The man took out his knife and climbed the tree to cut coconuts.'),
  q('Why did the man drop his knife?', ['A coconut hit his hand.','His wife called him.','He tried to swat a fly.','The lion roared.'],2,'Something was flitting around his face.','The man tried to swat the black fly and dropped his knife.'),
  q('What happened when the wife jumped away?', ['She caught a mango.','She climbed the tree.','She broke the knife.','She kicked a sleeping crocodile.'],3,'An animal was sleeping beneath the tree.','As she jumped, the wife kicked the crocodile.')),
 batch(3,6,
  q('What startled the jungle bird?', ['A falling mango','The crocodile’s swinging tail','The lion’s question','The bushfowl’s song'],1,'It squawked as the tail came down.','The crocodile’s tail startled the bird, which flew to a branch.'),
  q('What was the monkey doing before the bird arrived?', ['Building a nest','Climbing a coconut tree','Peeling a mango','Swimming with the hippo'],2,'It was holding a juicy fruit.','The monkey was peeling a juicy mango.'),
  q('Where did the dropped mango land?', ['In the river','On the lion’s mane','Inside the nest','On the hippo’s head'],3,'The falling fruit frightened a large animal.','The mango fell on the hippo’s head.'),
  q('What did the escaping hippo trample?', ['A bushfowl’s nest full of eggs','The coconut tree','The man’s basket','A pile of mangoes'],0,'The nest belonged to a bird.','The hippo trampled a bushfowl’s nest, which was full of eggs.')),
 batch(6,9,
  q('Why was the bushfowl crying?', ['She had lost the mango.','The lion would not speak.','Her eggs were broken.','The fly had eaten her food.'],2,'The hippo had trampled her nest.','The bushfowl cried because her eggs were all broken.'),
  q('Why did the sky stay dark in this tale?', ['The monkey covered the sky.','The crocodile hid the sun.','The lion slept all day.','The bushfowl stopped calling to awaken the sun.'],3,'She stayed beside her nest instead of making her familiar call.','Without the bushfowl’s call, the sun did not awaken in the story.'),
  q('Whom did the worried animals ask for help?', ['The wise lion','The mother toad','The little red hen','The king of flowers'],0,'He gathered the animals to hear what had happened.','The worried animals went to talk to the wise lion.'),
  q('What did the man tell the lion?', ['The hippo had taken his knife.','A black fly had made him drop his knife.','The bird had eaten a coconut.','The wife had hidden the mango.'],1,'He was the last to speak.','The man said he dropped his knife because the fly was annoying him.')),
 batch(9,12,
  q('How did the black fly answer the lion?', ['With a song','With an apology','With a long explanation','With “Buzz! Buzz! Buzz!”'],3,'The lion kept asking if it had anything else to say.','The black fly answered by buzzing.'),
  q('What power did the lion take away from the fly?', ['The power to talk','The power to fly','The power to see','The power to sleep'],0,'The lion was angry that the fly would not answer.','The lion took away the fly’s power to talk.'),
  q('What could the fly say after the punishment?', ['Only the lion’s name','Only buzzing sounds','Every animal’s name','A morning song'],1,'The tale explains the sound flies make today.','Afterward the fly could only say “Buzz! Buzz! Buzz!”'),
  q('What did the bushfowl agree to do at the end?', ['Leave the jungle','Build a coconut tree','Call the sun to begin the day again','Give the fly back its voice'],2,'She was satisfied that the fly had been punished.','The bushfowl agreed to call the sun again so the day could begin.')),
],
'three-little-pigs': [
 batch(0,3,
  q('Why did Mama Pig send the pigs into the world?', ['They were grown and ready to live on their own.','She had lost the house.','They wanted to find the wolf.','The farm had flooded.'],0,'She told them they were all grown now.','Mama Pig said it was time for them to live on their own.'),
  q('What did the first pig use for his house?', ['Bricks','Straw','Stones','Wooden boards'],1,'He finished quickly and rested.','The first pig built a house out of straw.'),
  q('What did the second pig use for his house?', ['Snow','Straw','Sticks','Bricks'],2,'His house used pieces of wood.','The second pig built a house out of sticks.'),
  q('What did both of these pigs have time to do after building?', ['Visit the wolf','Dig a pond','Cook soup for Mama Pig','Relax in the shade'],3,'Both finished with time left over.','The first and second pigs both had time to relax in the shade.')),
 batch(3,6,
  q('What did the third pig use for his house?', ['Straw','Bricks','Leaves','Sticks'],1,'This house took a long time to build.','The third pig built his house from bricks.'),
  q('Why did the third pig have no time to rest?', ['He had gone swimming.','He was asleep already.','He worked a long time building.','He was visiting Mama Pig.'],2,'He worked very, very hard on his house.','It took him a long time to finish building the brick house.'),
  q('What did the wolf think when he saw the first pig?', ['He wanted to help build.','He wanted to take a nap.','He wanted to plant wheat.','The pig would be tasty to eat.'],3,'The wolf was looking at the napping pig.','The wolf thought the little pig would make a tasty bite to eat.'),
  q('What did the first pig do when he saw the wolf coming?', ['He ran inside his straw house.','He welcomed the wolf.','He climbed onto the roof.','He hid in a tree.'],0,'He used his new house for shelter.','The first pig ran inside his straw house and refused to let the wolf in.')),
 batch(6,8,
  q('How did the wolf destroy the straw house?', ['He used an axe.','He set it on fire.','He huffed and puffed and blew it down.','He pushed it into a river.'],2,'His breath sent straw everywhere.','The wolf huffed and puffed and blew the straw house down.'),
  q('What did the first pig do as the straw blew everywhere?', ['He rebuilt the house.','He invited the wolf in.','He went to sleep.','He ran away.'],3,'He needed to escape the wolf.','The first little pig ran away.'),
  q('Which house did the wolf come to next?', ['The second pig’s stick house','Mama Pig’s house','The third pig’s brick house','A house made of stone'],0,'The next house belonged to the second pig.','The wolf came across the second pig’s home made of sticks.'),
  q('How did the second pig respond when the wolf asked to enter?', ['He opened the door.','He refused to let the wolf in.','He offered the wolf a mango.','He asked the wolf to build a roof.'],1,'He repeated the chinny-chin-chin reply.','The second pig said “Not by the hair of my chinny-chin-chin,” refusing entry.')),
 batch(8,10,
  q('Where did the first two pigs run?', ['Back to the straw house','Into the forest','To a pond','To their brother’s brick house'],3,'Their brother had worked hardest on his house.','The two pigs ran to their brother’s brick house.'),
  q('How did the wolf try to enter the brick house?', ['He jumped down the chimney.','He dug under the floor.','He swam through a window.','He waited for a key.'],0,'He climbed onto the roof first.','The wolf climbed onto the roof and jumped down the chimney.'),
  q('What did the wolf land in?', ['A basket of straw','A pot of hot water','A pile of pillows','A barrel of cold milk'],1,'The pot was heating on the fire.','The wolf fell into a pot of water that was heating on the fire.'),
  q('How did the story end?', ['The wolf ate all three pigs.','The pigs left with the wolf.','The wolf ran away, and the pigs lived happily.','The brick house fell down.'],2,'The hot water made the wolf jump out.','The wolf jumped out and ran away, and the three pigs lived happily ever after.')),
],
})


def main():
    OUTPUT.mkdir(parents=True,exist_ok=True)
    ART.mkdir(parents=True,exist_ok=True)
    doc=fitz.open(SOURCE)
    prepare_art(doc)
    listening,evidence=prepare_listening()
    (OUTPUT/'fables-last-listening.json').write_text(json.dumps(listening,ensure_ascii=False,indent=2)+'\n')
    (OUTPUT/'fables-last-evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
    if READING:
        reading=[]
        for book_id,title,author,numbers,illustrator in BOOKS:
            pages=[dict(sourcePage=n,text=SOURCE_TEXT[n],image=image_path(book_id,i)) for i,n in enumerate(numbers,1)]
            reading.append(dict(id=book_id,title=title,author=author,language='en',attribution=attribution(book_id,illustrator),original='assets/books/shared/fables_original.pdf',cover=pages[0]['image'],pages=pages,batches=READING[book_id]))
        (OUTPUT/'fables-last-reading.json').write_text(json.dumps(reading,ensure_ascii=False,indent=2)+'\n')
    print('Prepared',len(listening),'listening editions;',sum(len(b['pages']) for b in listening),'scenes;',sum(len(b['questions']) for b in listening),'picture questions.')


if __name__ == '__main__':
    main()
