"""Rebuild offline reading pages from the user-supplied PDFs (Poppler required)."""
import json,re,subprocess,tempfile
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
output=root/'assets/books'
# Source-grounded, pre-authored questions; their language follows the book.
frog_quiz=[
 ('What fell into the well?', ['A silver crown','A golden ball','A little shoe'],1,'The princess’s favourite toy looked like the sun.'),
 ('What did the princess offer the frog?', ['Her crown and jewels','A new pond','A bowl of soup'],0,'She offered the precious things she owned.'),
 ('What did the frog want in return?', ['A golden crown','A bigger well','A friend who would share with him'],2,'The frog said that his life was lonely.'),
 ('Who knocked on the palace door?', ['The king','The frog','A witch'],1,'The visitor had followed the princess from the well.'),
 ('How did the king react to the princess’s story?', ['He frowned','He laughed at the frog','He sent the frog away'],0,'He was not pleased that she had broken her promise.'),
 ('What did the frog do in the dining hall?', ['He hid under the table','He ate from the princess’s plate','He danced with the king'],1,'The princess had promised to share everything.'),
 ('What did the frog politely ask for?', ['A new crown','A golden ball','A drink from her cup'],2,'He was thirsty after his long hop to the palace.'),
 ('What did the frog leave on the castle floor?', ['Golden coins','Little muddy footprints','Flower petals'],1,'His feet were wet and dirty as he hopped upstairs.'),
 ('Where did the princess leave the frog?', ['At her bedroom door','In the well','Under the kitchen table'],0,'She climbed into bed while he looked up from the floor.'),
 ('Where did the frog want to sleep?', ['In a basket','Beside the window','On the princess’s pillow'],2,'He reminded her of her promise to share everything.'),
 ('What did the frog ask for before sleeping?', ['A good-night kiss','Another golden ball','A new blanket'],0,'He said that he had been a very lonely frog.'),
 ('What happened when the frog touched the floor?', ['He disappeared into the forest','He became a little prince','He turned into a bird'],1,'The witch’s spell was finally broken.'),
 ('What did the princess learn to keep?', ['Every golden coin','The frog in a cage','Her promise'],2,'Promises are more than air.'),
]
kolobok_quiz=[
 ('Что старик попросил испечь?', ['Пирог','Колобок','Хлеб'],1,'Название сказки — это и название угощения.'),
 ('Кого Колобок встретил первым?', ['Зайца','Медведя','Лису'],0,'Этот зверёк с длинными ушами встретился ему на дороге.'),
 ('Что Колобок предложил зайцу?', ['Поиграть','Поспать','Спеть песенку'],2,'Колобок сказал: «Я тебе песенку спою».'),
 ('Кого Колобок встретил после зайца?', ['Лису','Волка','Старика'],1,'Он обратился к зверю: «серый волк».'),
 ('Кто встретился Колобку после волка?', ['Медведь','Заяц','Лиса'],0,'Это большой косолапый зверь.'),
 ('Как Колобок назвал медведя?', ['Рыжий','Косой','Косолапый'],2,'Колобок сказал: «Где тебе, косолапому, съесть меня!»'),
 ('Как лиса встретила Колобка?', ['Стала ругаться','Похвалила его','Спряталась'],1,'Лиса сказала: «Какой ты хорошенький!»'),
 ('Почему лиса попросила петь погромче?', ['Она сказала, что плохо слышит','Вокруг шумел дождь','Колобок забыл слова'],0,'Лиса притворилась старой и глухой.'),
 ('Чем закончилась сказка?', ['Колобок вернулся домой','Колобок убежал','Лиса съела Колобка'],2,'Лиса обманула доверчивого Колобка.'),
]

def extract(name):
 source=root/'books'/name
 text=subprocess.check_output(['pdftotext','-layout',str(source),'-']).decode().split('\f')
 return source,text

def clean(raw,language):
 lines=[]
 for line in raw.splitlines():
  line=line.strip()
  if not line or 'freekidsbooks.org' in line or 'Core Knowledge' in line or 'deti-online.com' in line or re.fullmatch(r'\d+',line):
   lines.append(''); continue
  if line in ('The Frog Prince','Русская народная','Колобок','-THE END-'): continue
  lines.append(line)
 text='\n'.join(lines)
 text='\n\n'.join(' '.join(p.split()) for p in re.split(r'\n\s*\n',text) if p.strip())
 if language=='en':
  for a,b in [('long, owing','long, flowing'),('fngers','fingers'),('magnifcent','magnificent'),('foor','floor'),('to nd','to find'),('her nger','her finger'),('stone oor','stone floor'),('toad!”shesaid.','toad!” she said.'),('door. 9 The','door. The')]: text=text.replace(a,b)
 return text.strip()

books=[]
with tempfile.TemporaryDirectory() as temp:
 for book_id,name,lang,indices,quiz,title,author in [
  ('frog','The-Frog-Prince-Landscape-Book-CKF-FKB.pdf','en',[5,7,9,11,13,15,17,19,21,23,24,26,28],frog_quiz,'The Frog Prince','A classic fairy tale'),
  ('kolobok','Колобок.pdf','ru',list(range(1,10)),kolobok_quiz,'Колобок','Русская народная сказка')]:
  source,text=extract(name)
  prefix=Path(temp)/book_id
  subprocess.run(['pdfimages','-j',str(source),str(prefix)],check=True)
  image_numbers=([7,8,9,10,11,12,13,14,15,15,16,17,18] if lang=='en' else [0,1,2,3,3,4,5,5,6])
  pages=[]
  for index,(source_page,q,img_num) in enumerate(zip(indices,quiz,image_numbers)):
   # pdfimages counts soft masks too. Image numbers match `pdfimages -list`.
   extracted=list(Path(temp).glob(f'{book_id}-{img_num:03d}.*'))[0]
   image_path=f'assets/books/{book_id}_{index+1:02d}.webp'
   im=Image.open(extracted).convert('RGB');im.thumbnail((1100,1100));im.save(root/image_path,quality=88)
   pages.append(dict(sourcePage=source_page,text=clean(text[source_page-1],lang),image=image_path,
     question=dict(prompt=q[0],options=q[1],answer=q[2],hint=q[3])))
  attribution=('Based on an original work of the Core Knowledge® Foundation, remixed and published by Free Kids Books (freekidsbooks.org). Source PDF contains CC BY-NC-SA 3.0 and CC BY-NC notices. Non-commercial use; attribution and original license notices retained. Core Knowledge does not endorse this app.' if lang=='en' else 'Русская народная сказка «Колобок». Текст и иллюстрации из предоставленного PDF deti-online.com. Оригинальный файл и указание источника сохранены.')
  # Bundle source PDFs to retain complete attribution/licensing and original page layout.
  import shutil
  shutil.copyfile(source,output/f'{book_id}_original.pdf')
  books.append(dict(id=book_id,title=title,author=author,language=lang,attribution=attribution,
    original=f'assets/books/{book_id}_original.pdf',cover=pages[0]['image'],pages=pages))
(output/'catalog.json').write_text(json.dumps(books,ensure_ascii=False,indent=2)+'\n')
print('Prepared',[(b['id'],len(b['pages'])) for b in books])
