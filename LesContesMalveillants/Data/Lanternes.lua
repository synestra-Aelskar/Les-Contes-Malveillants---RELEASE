-- Les lanternes et cristaux livres avec l'addon.
--
-- Ce sont ceux de la base d'OmegaSurvive (Survive/Modules/Lantern/
-- LanternData.lua), recopies a l'identique le 22 octobre 2026 : nom,
-- multiplicateur, duree. Comme la sacoche de depart (Data/Sacs.lua), c'est
-- une exception au « le contenu vient de l'atelier » : sans eux, la lanterne
-- n'aurait rien a eclairer avant que le MJ ait cree la premiere entree.
--
-- Le MJ les corrige dans le compendium comme le reste : une entree publiee du
-- meme identifiant les remplace sur place (LCM.Publier). Le jour ou la base
-- commune les porte, ce fichier peut disparaitre.

local _, LCM = ...

-- Les identifiants de Survive etaient en capitales (ASPECTA, POOR...) : ils
-- passent en minuscules, comme tout identifiant de l'addon.
for _, lanterne in ipairs({
    { id = "aspecta",   label = "Lanterne d'aspecta",            multiplicateur = 1 },
    { id = "fremas",    label = "Lanterne d'aspecta des Fremas", multiplicateur = 2 },
    { id = "generator", label = "Générateur d'aspecta",          multiplicateur = 2 },
}) do
    LCM.Publier(LCM.Lanternes, lanterne)
end

for _, cristal in ipairs({
    { id = "poor",      label = "Cristaux d'aspecta raffinés de mauvaise facture",  duree = 5 },
    { id = "refined",   label = "Cristaux d'aspecta raffinés",                      duree = 120 },
    { id = "excellent", label = "Cristaux d'aspecta raffinés d'excellente qualité", duree = 240 },
    { id = "ancient",   label = "Cristaux d'aspecta raffinés d'ancien temps",       duree = 600 },
}) do
    LCM.Publier(LCM.Cristaux, cristal)
end
