-- Les mecaniques de defense : ce qu'on investit pour encaisser.
--
-- Les mecaniques de COMPETENCE disent ce qu'on sait faire ; celles-ci disent
-- ce qu'on sait subir. Elles vivent dans `Equilibrage.defenses`, se prennent
-- sur le meme budget que les premieres et se plafonnent pareil — c'est une
-- decision de jeu, pas une commodite : un personnage qui se blinde contre la
-- peur n'apprend pas a frapper plus fort pendant ce temps.
--
-- Deux sortes, et il ne faut pas les confondre :
--
--   REDUCTION : un pourcentage retire aux DEGATS recus. Une seule la porte,
--     la Defense, et elle ne vaut que contre ce qui frappe (attaque simple,
--     perce-armure, brise-armure).
--   RAND : un bonus au JET de defense. C'est la reponse aux actions qu'on
--     n'encaisse pas mais a quoi l'on resiste — peur, controle, entrave.
--
-- Une mecanique d'attaque sans defense dediee n'en a pas, et c'est voulu : on
-- ne se defend pas contre un soin.

local _, LCM = ...

local Defenses = {}
LCM.Defenses = Defenses

local function Eq() return LCM.Equilibrage end

-- Le champ de fiche d'une mecanique de defense. Prefixe `def_`, comme les
-- mecaniques de competence ont `meca_`.
function Defenses.Field(id) return "def_" .. tostring(id) end

function Defenses.Liste() return Eq().defenses or {} end

local parId
function Defenses.Get(id)
    if not parId then
        parId = {}
        for _, d in ipairs(Defenses.Liste()) do parId[d.id] = d end
    end
    return parId[tostring(id or "")]
end

-- Les defenses qui repondent a une mecanique d'attaque donnee. Une defense
-- peut en couvrir plusieurs (le Courage tient la peur ET l'intimidation).
local parMecanique
function Defenses.Contre(mecaniqueId)
    if not parMecanique then
        parMecanique = {}
        for _, d in ipairs(Defenses.Liste()) do
            for _, cible in ipairs(d.contre or {}) do
                parMecanique[cible] = parMecanique[cible] or {}
                table.insert(parMecanique[cible], d)
            end
        end
    end
    return parMecanique[tostring(mecaniqueId or "")] or {}
end

-- Ce qu'une entite a investi dans une defense, bonus d'equipement compris :
-- on lit le champ de fiche, pas le brouillon.
function Defenses.Points(entity, id)
    if not entity then return 0 end
    local champ = Defenses.Field(id)
    local valeur = LCM.Fiches and LCM.Fiches.Valeur and LCM.Fiches.Valeur(entity, champ)
    if valeur == nil and LCM.Effets and LCM.Effets.Total then
        valeur = LCM.Effets.Total(entity, champ)
    end
    if valeur == nil then valeur = entity[champ] end
    return tonumber(valeur) or 0
end

-- ===== Ce que ca donne =====================================================

-- Le bonus au jet de defense contre une mecanique, et le detail qui l'explique.
-- Le detail n'est pas un luxe : un jet qui monte sans qu'on sache pourquoi est
-- un jet qu'on soupconne.
function Defenses.BonusRand(entity, mecaniqueId)
    local total, detail = 0, {}
    for _, d in ipairs(Defenses.Contre(mecaniqueId)) do
        if d.sorte == "rand" then
            local points = Defenses.Points(entity, d.id)
            if points ~= 0 then
                local bonus = points * (tonumber(d.parPoint) or 0)
                total = total + bonus
                detail[#detail + 1] = { id = d.id, label = d.label, points = points, bonus = bonus }
            end
        end
    end
    return total, detail
end

-- La part des degats retiree par les defenses de reduction, en fraction
-- (0,15 pour 15 %). Bornee a `plafond` : une reduction qui atteindrait 100 %
-- rendrait invulnerable, ce qu'aucune table d'equilibrage n'a jamais voulu.
Defenses.PLAFOND_REDUCTION = 0.9

function Defenses.Reduction(entity, mecaniqueId)
    local total, detail = 0, {}
    for _, d in ipairs(Defenses.Contre(mecaniqueId)) do
        if d.sorte == "reduction" then
            local points = Defenses.Points(entity, d.id)
            if points ~= 0 then
                local part = points * (tonumber(d.parPoint) or 0)
                total = total + part
                detail[#detail + 1] = { id = d.id, label = d.label, points = points, part = part }
            end
        end
    end
    if total > Defenses.PLAFOND_REDUCTION then total = Defenses.PLAFOND_REDUCTION end
    return total, detail
end

-- Les degats reellement encaisses, une fois la reduction appliquee. On
-- ARRONDIT AU SUPERIEUR ce qui reste : une reduction ne doit jamais faire
-- tomber a zero une attaque qui a touche.
function Defenses.Encaisses(entity, mecaniqueId, degats)
    degats = tonumber(degats) or 0
    if degats <= 0 then return degats, 0 end
    local part = Defenses.Reduction(entity, mecaniqueId)
    if part <= 0 then return degats, 0 end
    local restant = math.ceil(degats * (1 - part))
    if restant < 1 then restant = 1 end
    return restant, degats - restant
end

-- Pour l'affichage : « Courage 4 (+2,0) », de quoi lire d'ou vient le bonus.
function Defenses.Resume(entity, mecaniqueId)
    local bonus, detail = Defenses.BonusRand(entity, mecaniqueId)
    local part = Defenses.Reduction(entity, mecaniqueId)
    local bouts = {}
    for _, d in ipairs(detail) do
        bouts[#bouts + 1] = string.format("%s %d (+%s)", d.label, d.points,
            LCM.Compendium and LCM.Compendium.Nombre and LCM.Compendium.Nombre(d.bonus)
            or tostring(d.bonus))
    end
    if part > 0 then
        bouts[#bouts + 1] = string.format("dégâts −%d %%", math.floor(part * 100 + 0.5))
    end
    return table.concat(bouts, ", "), bonus, part
end
