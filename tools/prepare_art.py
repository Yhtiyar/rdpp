"""Extract supplied scene illustrations without changing the source files."""
from pathlib import Path
from PIL import Image
import urllib.request
import wave, math, struct
root=Path(__file__).resolve().parents[1]
scenes=sorted((root/'scenes').glob('*.png'))
crops={
 'mimi_reading':(0,(109,330,490,657)),
 'screen_time':(1,(110,327,486,563)),
 'age_young':(0,(797,309,943,438)),
 'age_middle':(0,(800,486,941,634)),
 'age_older':(0,(795,674,950,817)),
 'lock':(0,(1173,276,1309,436)),
 'book':(0,(124,737,212,799)),
 'star':(0,(265,731,330,796)),
 'growth':(0,(387,733,461,796)),
 'mimi_celebrate':(4,(580,270,956,554)),
 'mimi_face':(4,(116,306,259,432)),
 'reward_star':(4,(1066,292,1177,405)),
}
for name,(i,box) in crops.items():
 Image.open(scenes[i]).crop(box).save(root/'assets/art'/f'{name}.webp',quality=95)
base='https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/'
for source,target in [('Nunito[wght].ttf','Nunito.ttf'),('OFL.txt','OFL.txt')]:
 urllib.request.urlretrieve(base+urllib.parse.quote(source),root/'assets/fonts'/target)
for name,notes in [('tap',[660]),('success',[523.25,659.25,783.99,1046.5]),('try_again',[440,349.23])]:
 rate=22050; frames=[]
 for freq in notes:
  length=.10 if name=='tap' else .16
  for i in range(int(rate*length)):
   t=i/rate; env=min(1,t/.008)*max(0,1-t/length)**2
   val=.22*env*(math.sin(2*math.pi*freq*t)+.25*math.sin(2*math.pi*freq*2*t))
   frames.append(struct.pack('<h',int(val*32767)))
 with wave.open(str(root/'assets/sounds'/f'{name}.wav'),'w') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(frames))
