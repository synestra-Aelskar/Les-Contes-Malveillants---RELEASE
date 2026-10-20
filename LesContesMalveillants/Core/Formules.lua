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

-- Une primaire, bonus portes compris (un objet peut en donner).
function Formules.Primaire(entity, fieldId)
    return Saisi(entity, fieldId) + LCM.Effets.Bonus(entity, fieldId)
end

-- La valeur d'une source d'apport, selon ce qu'elle designe.
local function Source(entity, fieldId, profondeur)
    local field = LCM.Schema.Field(fieldId)
    if not field then return 0 end
    if LCM.Effets.PRIMAIRES[fieldId] then return Formules.Primaire(entity, fieldId) end
    if field.kind == "roll" then return Formules.Expertise(entity, fieldId, profondeur) end
    return Saisi(entity, fieldId) + LCM.Effets.Bonus(entity, fieldId)
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

-- Valeur totale d'une expertise : investi + apport + bonus portes.
function Formules.Expertise(entity, fieldId, profondeur)
    return Saisi(entity, fieldId) + Formules.Apport(entity, fieldId, profondeur)
        + LCM.Effets.Bonus(entity, fieldId)
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
