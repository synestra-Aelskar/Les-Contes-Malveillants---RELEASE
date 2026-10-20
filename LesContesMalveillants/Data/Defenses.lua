-- Mecaniques de defense : les champs de fiche.
--
-- Meme patron que Data/Mecaniques.lua, pour la meme raison : la liste vit
-- dans `Equilibrage.defenses`, et on n'en fait ici que des champs
-- (`def_courage`, `def_stable`...). La note de chaque champ reprend ce que la
-- defense fait reellement — c'est la seule place ou le joueur la lira au
-- moment d'y investir.

local _, LCM = ...
local Schema = LCM.Schema
local E = LCM.Equilibrage

local champs = {}
for _, defense in ipairs(E.defenses) do
    champs[#champs + 1] = {
        id = LCM.Defenses.Field(defense.id), kind = "stat", label = defense.label, default = 0,
        note = defense.note or "Points investis dans cette défense.",
    }
end

Schema.AddTab({
    id = "defenses",
    label = "Défenses",
    sections = {
        { label = "Mécaniques de défense", fields = champs },
    },
})
