# Right ear correction

The top 12 pixels had a head-weight fade that anchored the ear tip to the image boundary while the rest of the ear rotated. During a page turn, this stretched the fur into a pointed hook. The deformation is visible in the before crop.

The entire ear now follows the same rigid head transform. A matching background fills the space exposed by the moving top edge, and a three-pixel alpha fade softens the cropped fur. The head-weight transition on the opposite side now lies beyond the other ear as well.

`test/mimi_reading_ears_test.dart` checks pairwise distances between the tips, rims, and bases of both ears using the actual rendered mesh at 201 phases. It also checks that the affected tip travels with the head. Both checks failed on the previous mesh and passed after the correction.

Flutter web close-ups were inspected at phases 0, .17, .37, .46, .50, .53, .60, .68, and .80. The sequence shows the original silhouette, the approach, the deepest head tilt, and recovery. The main Home recording is refreshed with this fix.

[Before](before.png) · [After](after.png) · [Both ears across the loop](sequence.png)
