# Reading artwork

The built-in image generation tool produced the body, head expressions, and connected limb using the existing MiMi illustrations as references. Project assets are in `assets/art/mimi/reading/`. The welcome artwork remains unchanged.

The earlier separate paw and resized foreleg were rejected after close-up inspection showed a pinched wrist and a visible rim beneath the paw. They are no longer used by the animation.

Generation prompts:

1. Clean plate: preserve the kitten, book, body, supporting paw, feet, tail, framing, and background; remove the anatomical left front paw/forearm on the viewer’s right; reconstruct the book edge and torso underneath.
2. Body: erase the head and ears from the clean plate; fill with matching pale lavender background; preserve the lower objects and their positions; add a furry neck behind the book.
3. Head strip: three versions of the same isolated lavender head—open eyes looking toward the book, half-closed lids, and closed eyes without visible irises. Preserve silhouette, ears, nose, mouth, fur, scale, light, and identity; transparent background. Only eye patches from the latter two versions are composited onto the original open head.
4. Connected limb: “Create one isolated, connected lavender kitten front paw and short bent foreleg on a transparent background. Match the round furry paw of the first reference and the seamless bent arm anatomy of the second reference. Paw at upper left, bent elbow and shoulder base at lower right. Short, thick, plush limb; foreleg about 70% of paw width. Continuous fur and volume through the wrist, without a narrow neck or a seam below the paw. Three tiny toe grooves, no long human fingers. Only this single limb, centered with generous margins, no head, torso, book, other objects, or text.” References: `mimi_reading.webp` and `mimi/proud.webp`.

The connected-limb request returned successfully after about 120 seconds. The preceding two requests returned service timeout errors; they produced no usable output. No timeout parameter was changed.

Exports retain alpha, remove near-transparent noise, and reduce dimensions for the app. The head gutter is excluded. Eye patches are cached once and opaque over the original eyes, with feathering confined to surrounding fur. The limb uses fixed-length shoulder/elbow/wrist geometry, with a rigid connected paw/forearm and an upper-arm layer that overlaps inside the elbow. Its root sits behind the head; the hand and forearm pass in front of the book.
