# Illustration du campement

`bivouac.tga` : texture RGBA non compressee, 512 x 512, chargee par `UI/Campement.lua`.
Illustration d'ambiance commune aux tentes, et non representation de chaque modele.
Generation avec l'outil integre imagegen, detourage transparent, puis conversion TGA et redimensionnement au plus proche pour WoW. `bivouac-source.png` conserve le detourage en haute resolution.

## Prompt de generation

Use case: stylized-concept. Asset type: square game UI illustration for a fantasy camping panel. Primary request: beautiful crisp pixel art medieval canvas tent at night, large readable tent in three quarter view with open dark entrance, small warm campfire beside it, forest silhouettes and a few stars behind, moss and stones at its feet. Composition: centered tent occupies middle 70 percent, compact diorama, no characters, no text or UI. Style: handcrafted 16-bit RPG pixel art, sharp square pixel clusters, limited palette, deep midnight teal background, muted ochre canvas, warm amber fire, atmospheric but clean silhouette. Square image with dark edges blending into a near-black teal UI panel. No lettering, no watermarks.

## Prompt de detourage

Edit this existing pixel art game asset as a precise background extraction. Keep the foreground medieval canvas tent and its ropes, small campfire, barrels, crates, stones and the compact grass/earth base exactly in the same composition and handcrafted crisp pixel style. Remove the entire night sky, moon, stars, mountains, distant forest, background water and rectangular dark teal backdrop. Make all pixels outside the foreground camp objects and their immediate ground base genuinely transparent alpha. Preserve the original tent silhouette and warm firelight. No text, no replacement background, no glow haze, no soft antialiased edges; hard pixel-art silhouette. The result is a square transparent cutout for overlaying directly on a dark UI.
