# Lecteur immersif Nécronicon

Le livre sert de fenêtre autonome. Les coins des pages tournent les feuillets,
la couverture s'ouvre au clic, le marque-page inférieur ferme le volume.
La reliure permet de le déplacer et Échap le ferme également.
Les pages tournent en 0,92 seconde : un maillage de 24 × 6 quadrilatères
se soulève autour de la reliure, avec torsion, perspective, recto/verso,
éclairage et ombre portée. Le texte est projeté sur la même surface que le
papier. Le livre reste immobile et la page suivante apparaît dessous.
Les notes se retournent autour de leur axe vertical.
Le contenu et les réglages d'encre existants sont conservés.

L'encre utilise un atlas transparent de la police Caudex déjà distribuée
dans l'addon, au repos comme pendant le mouvement. Les textes avec des
caractères hors atlas ou des balises WoW gardent leur rendu natif au repos.
Les textes sauvegardés ne sont jamais réécrits par le lecteur.

## Textures

- `necronicon-ouvert.tga` : RGBA 1024 × 1024, dessin dans les lignes 170–852.
- `necronicon-couverture.tga` : RGBA 512 × 1024, dessin dans les lignes 128–895.
- `note.tga` : feuille recto-verso existante, conservée.
- `encre-caudex.tga` : atlas RGBA 1024 × 1024 ; métriques dans
  `UI/LivresGlyphes.lua`, régénérables avec `Outils/build_livres_encre.py`.

Les deux nouvelles textures ont été générées avec l'outil imagegen intégré,
puis redimensionnées et placées sur un canevas en puissance de deux pour WoW.
Le canal alpha est conservé. Le cadre Ael’Raz’kah de Nécronicon a servi de
référence de matériaux et d'ornements, pas de cadre de fenêtre.

## Prompts finaux

### Livre ouvert

Use case: stylized-concept. Asset: transparent 2D fantasy game UI OPEN BOOK texture.
Reference image is only the art-direction reference for Necronicon: aged gold
filigree, black drapery, funerary small skulls, fine chains; do NOT reproduce
its rectangular window or background. Create a rich immersive open occult tome
that is itself the entire UI, perfectly front-on, two facing BLANK broad warm
ivory parchment pages, subtle center gutter, black cracked leather cover around
edges, fine antique-gold clasps and restrained tiny bone/skull ornaments at
spine and outer corners, one small black-and-gold hanging ribbon bookmark at
the bottom of the central spine. Tangible stacked paper edges, gentle realistic
gutter shadows. Excellent painted game art, crisp small details, elegant rather
than cartoon. Wide landscape composition filling canvas, symmetry with spine
exactly at x=50%, blank pale flat text-safe writing areas from x=10-46% and
x=54-90%, y=12-85%. Page rectangles should stay very close to flat/orthographic
for overlay text. All corners visible. Genuine transparent alpha background
outside silhouette. NO black rectangular background, no window frame around
the book, no captions, no letters or numbers, no symbols on pages, no buttons,
no title, no hands, no scenery, no table, no heavy stains. The book is mostly
charcoal, muted antique gold, ivory parchment; NOT red leather.

### Couverture

Use case: stylized-concept. Create matching CLOSED COVER asset for the exact
dark Necronicon tome in reference. Reference is for materials and decorative
identity. A single upright closed book perfectly front-on, portrait 3:4 ratio,
fully visible with narrow transparent margins. Weathered charcoal-black
leather, fine aged gold corner filigree, tiny funerary skull at top center,
thin delicate hanging gold chains, subtle stacked parchment edges on right
and bottom. Broad clean dark center panel for title and subtitle which will
be added in game; restrained embossed border, no symbols occupying center.
Gothic luxurious painted game UI texture, crisp, same antique gold and
charcoal as reference. Genuine transparent alpha outside book. NO letters,
words, runes, captions, text, buttons, background scene or rectangular UI
window. Do not depict an open book.
