-- Mecaniques de competence.
--
-- Ce qu'une competence sait faire : frapper, soigner, repousser, immobiliser...
-- Le joueur y investit un budget a part (2 + 3 x niveau, agrandi par la stat
-- secondaire « Mecanique de competence »), et chaque mecanique se plafonne
-- comme une expertise.
--
-- La liste vit dans `Equilibrage.mecaniques` ; ici, on n'en fait que des champs
-- de fiche (`meca_soin`, `meca_entrave`...).

local _, LCM = ...
local Schema = LCM.Schema
local E = LCM.Equilibrage

function LCM.MecaniqueField(id) return "meca_" .. tostring(id) end

-- Une seule colonne de champs : ces mecaniques n'ont pas de groupes dans la
-- feuille d'origine, et en inventer aurait ete une regle de plus a maintenir.
local champs = {}
for _, mecanique in ipairs(E.mecaniques) do
    champs[#champs + 1] = {
        id = "meca_" .. mecanique.id, kind = "stat", label = mecanique.label, default = 0,
        note = "Points investis dans cette mécanique.",
    }
end

Schema.AddTab({
    id = "mecaniques",
    label = "Mécaniques",
    sections = {
        { label = "Mécaniques de compétence", fields = champs },
    },
})
