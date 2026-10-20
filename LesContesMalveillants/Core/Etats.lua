-- Etats : ce qui affecte un personnage — etats divers, maladies, etats
-- intangibles (les trois conteneurs de la fenetre Sante du template).
--
-- Un catalogue (Core/Catalogues.lua) : chaque etat a son icone, sa
-- description et ses effets (le template : « Infection de sang », Force -10).
-- Un etat peut toucher une primaire, en bien comme en mal.

local _, LCM = ...

LCM.Etats = LCM.Catalogue({
    nom = "etat", prefixe = "Etats", cleEntite = "etats", primaires = true,
    categories = {
        { id = "etat",       label = "État",             onglet = "États",      bloc = "États divers" },
        { id = "maladie",    label = "Maladie",          onglet = "Maladies",   bloc = "États de maladies" },
        { id = "intangible", label = "État intangible",  onglet = "Intangible", bloc = "États intangibles" },
    },
})
