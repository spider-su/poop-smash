# Reference-aligned art direction

The supplied concept image guides the palette, hierarchy and materials: bright blue park scenery; warm orange glossy mascot; large outlined rounded lettering; lime Free Play and gold Challenge buttons; compact green timer/score pills; a purple character legend; purple results with radial light, a crowned sunglasses mascot, a large gold score and a green replay action.

The character remains the existing continuous deformable mesh. Its contour, pressure, stretch, scoring, variants and save schema are unchanged. Its eyes, mouth, tongue, palette and outline have been restyled. The crown/sunglasses on results are a presentation accessory, not a new reward system. The gameplay house returns to the menu; the character strip is a legend, preserving the current rotation/random spawn rules. Sound and haptics stay directly accessible.

## Assets and provenance

- `assets/backgrounds/park.png`: original background generated with the built-in imagegen tool. No reference UI or character is baked into it. Generated source preserved at `/Users/alex/.codex/generated_images/01a1b5ae-2274-74d3-b44d-19b7e588e500/exec-f04fc3f4-e87a-4bb9-9968-ea36a5279c00.png`; the shipped copy is inside this repository.
- `assets/fonts/Fredoka.ttf`: Fredoka variable font from https://github.com/google/fonts/tree/main/ofl/fredoka, bundled offline at weight 700. SIL Open Font License is included as `assets/fonts/OFL.txt`.
- All UI geometry, title lettering, controls, thumbnails and live characters are drawn by Godot. No phone frame, fake finger or flattened screenshot is used as game UI.

Final generation prompt (built-in tool, opaque background):

> Use case: stylized-concept. Asset type: actual portrait mobile game background texture, no UI, no lettering. Create a new original full-bleed 1024x1536 portrait background for a cheerful glossy 3D cartoon squish game. Scene: bright blue sky with a few soft fluffy clouds in upper third, sunlit rounded lush green park trees and a tiny distant pastel cottage at far right around the horizon, then a wide smooth peach/orange sandy path occupying the lower 55 percent, with faint lavender pink grass/flowers at the bottom corners. Shallow depth of field, softened background detail so a large orange cartoon character can be overlaid in the center. Premium playful mobile casual-game illustration, candy colors, luminous soft light, subtly dreamy. Composition: leave the entire central 65 percent quiet, horizon around 43 percent of image height. Background only: no characters, no poop, no hands, no text, no symbols, no logos, no UI, no device frames. This will be used behind live gameplay and must read well on both tall and short portrait crops.

## Verification

Use the existing `tests/capture_visuals.gd` to capture nine actual game states at portrait, short and tall aspect ratios. Inspect title and control text, speech bubbles against the compact HUD, results card/mascot overlap, and every variant. Existing unit/integration tests continue to validate the unchanged interaction rules. Physical-device acceptance remains outstanding.
