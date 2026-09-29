"""Picture checkpoints grounded in the full, unchanged Frog Prince text."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OLD = 'assets/books/frog/art/frog-answers.png'
NEW = 'assets/books/frog/art/frog-exact-answers.webp'
ART = {
    'Frog': (OLD, 0), 'Princess': (OLD, 1), 'Golden ball': (OLD, 2),
    'Well': (OLD, 3), 'King': (OLD, 4), 'Palace': (OLD, 5),
    'Golden plate': (NEW, 0), 'Silver cup': (NEW, 1), 'Pillow': (NEW, 2),
    'Prince': (NEW, 3), 'Table': (NEW, 4), 'Bed': (NEW, 5),
}
# Each consecutive pair belongs to the next group of three listening parts.
ROWS = [
('What was the princess’s favorite toy?', 'Golden ball', 'Silver cup',
 'She tossed and bounced her round, golden toy.', 'Yes, the golden ball was her favorite toy!',
 'her favorite plaything was a bright golden ball'),
('Where did the golden ball fall?', 'Well', 'Palace',
 'It fell into a deep, dark place with water.', 'The ball fell into the deep well.',
 'fell— splash!—into a deep well.'),
('Who offered to fetch the lost ball?', 'Frog', 'Prince',
 'The small creature beside the well could dive into the water.', 'The frog offered to get the ball.',
 'The frog looked at her and blinked. “I could get it for you,'),
('Who cried because the ball was lost?', 'Princess', 'King',
 'It was the girl whose favorite toy had fallen into the well.', 'The princess cried about her lost ball.',
 '“I have dropped my ball into the well, and it is lost forever!” she wailed.'),
('Who brought the golden ball out of the water?', 'Frog', 'King',
 'He held it in his little webbed hands.', 'The frog brought the ball out of the well!',
 'he emerged from the water holding the precious golden ball between two slimy webbed hands.'),
('Where did the princess run with her ball?', 'Palace', 'Well',
 'She ran back to her grand home.', 'She ran back to the palace with the ball.',
 'seizing the ball, she immediately ran back to the palace.'),
('Who came to the palace door that night?', 'Frog', 'Prince',
 'The visitor was small, green, and warty.', 'The frog came to the palace door.',
 'who should stand on the palace stairs but the icky, warty frog!'),
('Who asked his daughter about the visitor?', 'King', 'Frog',
 'The princess’s father wanted to know who was at the door.', 'The king asked his daughter about the visitor.',
 '“Who was at the door, my daughter?” asked the king.'),
('Who smiled and bounced on the palace steps?', 'Frog', 'Princess',
 'He was so happy to see the princess open the door.', 'The happy frog smiled and bounced!',
 'he smiled happily—a smiling frog is quite a sight to behold—and bounced up and down with froggy glee.'),
('Who told the princess to keep her promise?', 'King', 'Prince',
 'Her father wanted her to be the frog’s friend.', 'Her father, the king, insisted that she keep her promise.',
 'Her father insisted, however, that she should be his friend just as she said she would.'),
('What did the frog eat from?', 'Golden plate', 'Golden ball',
 'It was a shining dish on the dinner table.', 'The frog ate from the princess’s golden plate.',
 'he began to eat from her shining gold plate'),
('Who turned away while the frog was eating?', 'Princess', 'King',
 'The girl did not like seeing food on the frog’s face.', 'The princess turned away from the messy frog.',
 'the princess, noticing how he smeared the food all over his face, turned away in disgust.'),
('What did the frog ask to drink from?', 'Silver cup', 'Golden plate',
 'He asked to share the princess’s drinking cup.', 'The frog asked to drink from her cup.',
 '“May I have a drink from your cup?”'),
('Who became sleepy after dinner?', 'Frog', 'King',
 'He said he was tired and asked to be taken up to bed.', 'The frog was tired and wanted to go to bed.',
 'The frog sighed and continued eating, but soon he began to look sleepy.'),
('Where did the princess climb when she reached her room?', 'Bed', 'Table',
 'Her room had a cozy place with a quilt and a pillow.', 'She climbed into her beautiful bed.',
 'The princess left the frog at the door and climbed into her beautiful bed.'),
('Who left muddy footprints on the castle floor?', 'Frog', 'Prince',
 'He hopped up the stairs behind the princess. Splish, splash!', 'The hopping frog left the muddy footprints.',
 'she could hear the frog hopping behind her—boing! boing!—and leaving little muddy footprints'),
('Where did the princess finally put the frog?', 'Pillow', 'Golden plate',
 'He wanted the soft place where her head would rest.', 'She put the frog on the pillow.',
 'she climbed down and tossed the frog roughly onto the pillow'),
('Who asked for a good-night kiss?', 'Frog', 'King',
 'He said that he had been a very lonely frog.', 'The frog asked the princess for a good-night kiss.',
 '“Could I have a good-night kiss? I have been a very lonely frog.'),
('Who was snoring on the pillow in the morning?', 'Frog', 'Prince',
 'He was still a small, green creature when she woke up.', 'The frog was snoring on the pillow.',
 'the princess woke to find the frog still snoring on the pillow.'),
('Who tried to wake the sleepy frog?', 'Princess', 'King',
 'The girl poked him with her finger and told him to get up.', 'The princess tried to wake the frog.',
 'Finally, she poked him hard with her finger. “Get up, you lazy toad!”'),
('Who appeared when the frog touched the floor?', 'Prince', 'King',
 'The little frog changed into a smiling boy.', 'A little prince appeared where the frog had been!',
 'the warty frog disappeared, and in his place sat a little prince'),
('Who reminded the prince that they should stay friends?', 'Princess', 'King',
 'She stopped him when he said he would go home.', 'The princess wanted them to stay friends forever.',
 '“Wait!” said the princess. “I thought we were supposed to be friends forever after.'),
('What did the prince ask to play with?', 'Golden ball', 'Silver cup',
 'It was the round toy that had fallen into the well.', 'He asked to play with the princess’s ball.',
 '“So they are. Shall we go play with your ball?”'),
('Who married the princess when they were grown up?', 'Prince', 'King',
 'He had once been the frog who became her friend.', 'The prince and the princess married when they were grown up.',
 'They were friends forever afterward, and when they were quite grown up, they were married'),
]


def main():
    path = ROOT / 'content/verbatim-books/frog.json'
    book = json.loads(path.read_text())
    questions = []
    for i, (prompt, correct, other, hint, feedback, quote) in enumerate(ROWS):
        group = book['pages'][i // 2 * 3:i // 2 * 3 + 3]
        passage = ' '.join(page['text'] for page in group)
        assert quote in passage, (i, quote)
        choices = [dict(label=label, image=ART[label][0], cell=ART[label][1]) for label in [correct, other]]
        if i % 2:
            choices.reverse()
        identifier = f'frog-exact-question-{i + 1:03d}'
        questions.append(dict(id=identifier, afterPage=min(i // 2 * 3 + 2, len(book['pages']) - 1),
                              prompt=prompt, hint=hint,
                              guided=f'Let’s find it together. Tap the picture with the green frame. {feedback}',
                              feedback=feedback, choices=choices, answer=i % 2,
                              evidence=dict(pageIds=[page['id'] for page in group], quote=quote),
                              audio={kind:f'assets/books/frog/audio/{identifier}-{kind}.mp3' for kind in ['prompt','hint','guided','feedback']}))
    book['questions'] = questions
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + '\n')
    print('Frog Prince:',len(book['pages']),'exact parts;',len(questions),'grounded picture questions')


if __name__ == '__main__':
    main()
