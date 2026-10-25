-- Formules : les valeurs TOTALES que les regles combinent.
--
-- Une valeur saisie (ce que le joueur a investi) n'est qu'une partie de ce qui
-- compte en jeu : les primaires recoivent les bonus portes, les expertises
-- recoivent en plus un apport de leurs primaires (Equilibrage
-- .apportsExpertises). Tout ce qui calcule — fiche, jets, jauges — passe ici,
-- pour qu'une meme valeur ne se calcule pas de deux facons.
--
-- Arrondi : les apports sont fractionnaires (0,33 x Perception) ; on arrondit
-- a l'inferieur la somme des apports d'une expertise, une seule fois.

local _, LCM = ...

local Formules = {}
LCM.Formules = Formules

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Eq() return LCM.Equilibrage end

local function Saisi(entity, fieldId)
    return tonumber(LCM.Entities.Get_Value(entity, fieldId)) or 0
end

-- Les pourcentages portes, appliques a un total DEJA fait (le MJ, 24 octobre
-- 2026 : « baisse force de 40 % »). Trois regles, dans cet ordre :
--
--   1. les points d'abord, le pourcentage ensuite. Il porte sur l'ensemble,
--      sinon l'ordre d'application changerait le resultat et deux fiches
--      identiques ne donneraient pas le meme chiffre ;
--   2. les pourcentages s'additionnent et ne se composent pas : deux etats a
--      -40 % font -80 %, pas -64 % (voir Effets.Pourcent) ;
--   3. une statistique ne descend pas sous zero : -150 % la vide, il ne
--      l'inverse pas. Un total deja negatif n'est pas remonte pour autant —
--      ce sont des points en moins, le pourcentage n'y est pour rien.
--
-- Arrondi a l'inferieur, comme les apports, et une seule fois.
-- `total * (100 + pourcent) / 100` et non `total * (1 + pourcent / 100)` : la
-- seconde ecriture donnait 1 pour « 10 moins 80 % », parce que 0,2 n'existe
-- pas en binaire et que le produit tombait a 1,9999999999999996 juste avant
-- l'arrondi. Ici le numerateur reste entier.
function Formules.Module(entity, fieldId, total)
    local pourcent = LCM.Effets.Pourcent(entity, fieldId)
    if pourcent == 0 then return total end
    local module = total * (100 + pourcent) / 100
    if total > 0 and module < 0 then module = 0 end
    return math.floor(module)
end

-- Une primaire, bonus portes compris (un objet peut en donner).
function Formules.Primaire(entity, fieldId)
    return Formules.Module(entity, fieldId,
        Saisi(entity, fieldId) + LCM.Effets.Bonus(entity, fieldId))
end

-- La valeur d'une source d'apport, selon ce qu'elle designe.
local function Source(entity, fieldId, profondeur)
    local field = LCM.Schema.Field(fieldId)
    if not field then return 0 end
    if LCM.Effets.PRIMAIRES[fieldId] then return Formules.Primaire(entity, fieldId) end
    if field.kind == "roll" then return Formules.Expertise(entity, fieldId, profondeur) end
    return Formules.Module(entity, fieldId,
        Saisi(entity, fieldId) + LCM.Effets.Bonus(entity, fieldId))
end

-- Ce que les primaires (et autres sources) apportent a une expertise, arrondi
-- a l'inferieur. Zero pour un jet sans apport declare (Initiative...).
function Formules.Apport(entity, fieldId, profondeur)
    local apports = Eq().apportsExpertises and Eq().apportsExpertises[tostring(fieldId)]
    if not apports then return 0 end
    -- Une expertise peut s'appuyer sur une autre (Crochetage lit Toucher) ; la
    -- profondeur coupe court a une boucle ecrite par megarde dans les donnees.
    profondeur = (profondeur or 0) + 1
    if profondeur > 4 then return 0 end
    local total = 0
    for source, coefficient in pairs(apports) do
        total = total + Source(entity, source, profondeur) * coefficient
    end
    return math.floor(total)
end

-- Valeur totale d'une expertise : investi + apport + bonus portes, le tout
-- module par les pourcentages portes.
function Formules.Expertise(entity, fieldId, profondeur)
    return Formules.Module(entity, fieldId,
        Saisi(entity, fieldId) + Formules.Apport(entity, fieldId, profondeur)
        + LCM.Effets.Bonus(entity, fieldId))
end

-- Verification au chargement des donnees : une source d'apport doit exister.
LCM.WhenReady(function()
    for expertise, apports in pairs(Eq().apportsExpertises or {}) do
        if not LCM.Schema.Field(expertise) then
            LCM.Erreur("apports : expertise inconnue « " .. expertise .. " »")
        end
        for source in pairs(apports) do
            if not LCM.Schema.Field(source) then
                LCM.Erreur(string.format("apports de %s : source inconnue « %s »", expertise, source))
            end
        end
    end
end)
