# First five CKF tales: preparation record

Source: `books/fables-list.pdf`, Classic Tales Big Book, Preschool, Core Knowledge Language Arts, © 2014 Core Knowledge Foundation. Each tale retains its illustrator credit, reteller credit where present, complete license attribution, and reference to the single bundled original `assets/books/shared/fables_original.pdf`.

| Tale | Source PDF pages | Reading pages | Reading batches/questions | Listening scenes/questions |
| --- | --- | ---: | ---: | ---: |
| The Lion and the Mouse | 9–13 | 5 | 2 / 8 | 6 / 4 |
| The City Mouse and the Country Mouse | 17–23 | 7 | 3 / 12 | 6 / 4 |
| Goldilocks and the Three Bears | 27–35 | 9 | 3 / 12 | 9 / 6 |
| The Gingerbread Man | 39–48 | 10 | 4 / 16 | 9 / 6 |
| The Shoemaker and the Elves | 53–61 | 9 | 3 / 12 | 9 / 6 |

Reading text is complete text extracted with Poppler, with numeric footers removed and whitespace joined. It excludes covers and blank pages. The original spelling “accidently” in The Lion and the Mouse is retained. The source’s unusual four-pair result after cutting leather for two pairs in The Shoemaker and the Elves is also retained in both editions.

The listening editions preserve complete endings, including the fox eating the Gingerbread Man, Goldilocks never returning, and the elves dancing away permanently. Each adaptation is explicitly identified. Spoken scripts have 15–65 words per scene. Two picture questions follow every trio, with balanced correct positions and exact scene/sentence evidence. Audio paths are declared for 148 clips; audio generation and app integration are handled separately.

Art is extracted directly from embedded source illustrations, with no source-page text or footer in scene images. Goldilocks source page 30 contains two paintings; they are combined side by side. The 22 picture-answer crops preserve original artwork; every crop is recorded in `fables-first-art-provenance.json`. Crops are fitted into equal white squares at a consistent maximum extent. Visual inspection led to larger answer subjects, a complete cat face, a clear Baby Bear portrait, and an actual broken-chair image. All 40 story illustrations and 22 answer crops were reviewed in contact sheets. No artwork gaps remain.

Reproduce the fragments and all art with `PYTHONPATH=/tmp/readapp-pdf python3 tools/prepare_fables_first.py` (PyMuPDF, Pillow, and Poppler required). This script does not overwrite shared catalogs or audio manifests.
