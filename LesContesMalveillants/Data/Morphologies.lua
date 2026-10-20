-- Morphologies : combien de chaque zone du corps.
--
-- `effectifs` : le nombre de zones par categorie. Torse et internes sont
-- toujours presents, on ne les compte pas. Chaque zone vaut 30 % des PV max
-- (Equilibrage.pv.parZone, regle du template) : il n'y a plus de part a
-- repartir, seulement des zones a compter.
--
-- L'humanoide suit le template Necronicon : une zone Bras, une zone Jambes.
-- Les autres morphologies sont des extensions de l'addon (elles n'existaient
-- pas dans Necronicon) ; leurs effectifs sont a valider.

local _, LCM = ...
local Morphologies = LCM.Morphologies

LCM.DEFAULT_MORPHOLOGY = "humanoide"

Morphologies.Add({
    id = "humanoide", label = "Humanoïde",
    effectifs = { tete = 1, bras = 1, jambe = 1 },
})

Morphologies.Add({
    id = "quadrupede", label = "Quadrupède",
    effectifs = { tete = 1, jambe = 4, queue = 1 },
})

Morphologies.Add({
    id = "aile", label = "Humanoïde ailé",
    effectifs = { tete = 1, bras = 1, jambe = 1, aile = 2 },
})

Morphologies.Add({
    id = "aberration", label = "Aberration",
    effectifs = { tete = 3, jambe = 12, queue = 2 },
})
