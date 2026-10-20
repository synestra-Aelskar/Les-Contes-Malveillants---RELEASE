-- Penetrations et resistances.
--
-- Quinze types, trois groupes, et les memes des deux cotes : la penetration dit
-- ce qu'on inflige dans un type, la resistance ce qu'on encaisse. Les champs
-- sont engendres depuis `Equilibrage.types` — ajouter un type se fait la-bas,
-- et les deux colonnes suivent.
--
-- Releve de la feuille « Penetrations » / « Resistances » de Necronicon.

local _, LCM = ...
local Schema = LCM.Schema
local E = LCM.Equilibrage

-- Identifiants de champ : `pen_feu`, `resi_feu`. Une seule fonction pour les
-- fabriquer, pour qu'on ne puisse pas les ecrire differemment ailleurs.
function LCM.PenetrationField(typeId) return "pen_" .. tostring(typeId) end
function LCM.ResistanceField(typeId) return "resi_" .. tostring(typeId) end

local function Sections(prefixe, formule)
    local sections = {}
    for _, groupe in ipairs(E.groupesTypes) do
        local champs = {}
        for _, t in ipairs(E.types) do
            if t.groupe == groupe then
                champs[#champs + 1] = {
                    id = prefixe .. t.id, kind = "stat", label = t.label, default = 0,
                    note = formule,
                }
            end
        end
        if #champs > 0 then
            sections[#sections + 1] = { label = groupe, fields = champs }
        end
    end
    return sections
end

Schema.AddTab({
    id = "penetrations",
    label = "Pénétrations",
    sections = Sections("pen_", "Points investis dans ce type."),
})

Schema.AddTab({
    id = "resistances",
    label = "Résistances",
    sections = Sections("resi_", "Points investis dans ce type."),
})

-- ===== Plafonds ============================================================
-- Ce ne sont pas des limites de budget : elles disent seulement jusqu'ou UN
-- type peut monter. Plus on investit dans les trois statistiques de degats,
-- plus on peut se specialiser en penetration ; la constitution fait de meme
-- pour les resistances.

function LCM.PenetrationMax(entity)
    local total = 0
    for _, id in ipairs(E.statsDeDegats) do
        total = total + (tonumber(LCM.Entities.Get_Value(entity, id)) or 0)
    end
    local p = E.penetration.plafond
    return math.floor(total / p.diviseurStats) + p.base
end

function LCM.ResistanceMax(entity)
    local constitution = tonumber(LCM.Entities.Get_Value(entity, "constitution")) or 0
    local p = E.resistance.plafond
    return math.floor(constitution * p.parConstitution) + p.base
end
