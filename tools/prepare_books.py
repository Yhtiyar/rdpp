"""Rebuild offline reading pages from the user-supplied PDFs (Poppler required)."""
import json,re,subprocess,tempfile
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
output=root/'assets/books'
# Source-grounded batch quizzes are authored separately from PDF extraction.
quizzes=json.loads((root/'tools/book_quizzes.json').read_text())

for batches in quizzes.values():
 for batch in batches:
  for question in batch['questions']:
   assert question.get('explanation','').strip(), 'Each answer needs a source-grounded explanation'

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
 for book_id,name,lang,indices,title,author in [
  ('frog','The-Frog-Prince-Landscape-Book-CKF-FKB.pdf','en',[5,7,9,11,13,15,17,19,21,23,24,26,28],'The Frog Prince','A classic fairy tale'),
  ('kolobok','Колобок.pdf','ru',list(range(1,10)),'Колобок','Русская народная сказка')]:
  source,text=extract(name)
  prefix=Path(temp)/book_id
  subprocess.run(['pdfimages','-j',str(source),str(prefix)],check=True)
  image_numbers=([7,8,9,10,11,12,13,14,15,15,16,17,18] if lang=='en' else [0,1,2,3,3,4,5,5,6])
  pages=[]
  for index,(source_page,img_num) in enumerate(zip(indices,image_numbers)):
   # pdfimages counts soft masks too. Image numbers match `pdfimages -list`.
   extracted=list(Path(temp).glob(f'{book_id}-{img_num:03d}.*'))[0]
   image_path=f'assets/books/{book_id}/art/{book_id}_{index+1:02d}.webp'
   (root/image_path).parent.mkdir(parents=True,exist_ok=True)
   im=Image.open(extracted).convert('RGB');im.thumbnail((1100,1100));im.save(root/image_path,quality=88)
   pages.append(dict(sourcePage=source_page,text=clean(text[source_page-1],lang),image=image_path))
  attribution=('Based on an original work of the Core Knowledge® Foundation, remixed and published by Free Kids Books (freekidsbooks.org). Source PDF contains CC BY-NC-SA 3.0 and CC BY-NC notices. Non-commercial use; attribution and original license notices retained. Core Knowledge does not endorse this app.' if lang=='en' else 'Русская народная сказка «Колобок». Текст и иллюстрации из предоставленного PDF deti-online.com. Оригинальный файл и указание источника сохранены.')
  # Bundle source PDFs to retain complete attribution/licensing and original page layout.
  import shutil
  shutil.copyfile(source,output/book_id/f'{book_id}_original.pdf')
  books.append(dict(id=book_id,title=title,author=author,language=lang,attribution=attribution,
    original=f'assets/books/{book_id}/{book_id}_original.pdf',cover=pages[0]['image'],pages=pages,batches=quizzes[book_id]))
print('Prepared',[(b['id'],len(b['pages'])) for b in books])

# Retain independently authored editions when rebuilding the original sources.
from merge_book_catalogs import merge_catalogs
merge_catalogs(reading_editions=books)
