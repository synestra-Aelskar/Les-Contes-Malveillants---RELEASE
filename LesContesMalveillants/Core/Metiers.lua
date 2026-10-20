-- Metiers : les 31 metiers du template (compendium « Liste metiers ») et
-- l'experience qu'un personnage accumule dans chacun.
--
-- Un metier progresse par couleurs, cinq niveaux par couleur (table
-- « XP METIER » dans Equilibrage.metiers.paliers). La table est INCREMENTALE :
-- chaque ligne demande son XP pour achever le niveau courant. Le dernier cout
-- est donc lui aussi consomme avant que le metier soit entierement maitrise.
-- Le bonus de jet reste le rang de COULEUR, pas le rang global sur 30 niveaux.
--
-- Cote entite, seulement l'XP gagnee : entity.metiers = { [id] = xp }. Un
-- metier a zero ne laisse rien dans la sauvegarde.

local _, LCM = ...

local Metiers = { list = {}, byId = {} }
LCM.Metiers = Metiers

local function Erreur(message) error("LCM/Metiers : " .. tostring(message), 0) end

function Metiers.Add(definition)
    local id = tostring(definition and definition.id or "")
    if id == "" then Erreur("metier sans identifiant") end
    if Metiers.byId[id] then Erreur("metier en double : " .. id) end
    local metier = {
        id = id,
        label = tostring(definition.label or id),
        description = tostring(definition.description or ""),
        icone = LCM.Icone(definition.icone),
    }
    Metiers.byId[id] = metier
    Metiers.list[#Metiers.list + 1] = metier
    return metier
end

function Metiers.Get(id) return Metiers.byId[tostring(id or "")] end

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Paliers() return LCM.Equilibrage and LCM.Equilibrage.metiers and LCM.Equilibrage.metiers.paliers or {} end

function Metiers.XP(entity, id)
    local stock = type(entity) == "table" and entity.metiers
    return type(stock) == "table" and math.max(0, math.floor(tonumber(stock[tostring(id)]) or 0)) or 0
end

-- L'XP totale minimale qui correspond a un niveau global (1 a 30). Sert
-- notamment a convertir les quatre points de creation en vrais niveaux de
-- metier, sans dupliquer le bareme dans le createur.
function Metiers.XPPourNiveau(niveau)
    niveau = math.max(0, math.floor(tonumber(niveau) or 0))
    local palier = Paliers()[niveau]
    return palier and math.max(0, math.floor(tonumber(palier.cumul) or 0)) or 0
end

-- Le dernier rang du bareme (Violet 5, le trentieme). C'est la seule borne
-- des metiers d'un PNJ : au-dela, le rang n'existe pas et XPPourNiveau le
-- rendrait a zero — le niveau serait perdu sans un mot.
function Metiers.RangMax()
    return #Paliers()
end

-- Le niveau acquis : { rang, nom, niveau, libelle, rangCouleur,
-- xpDansPalier, xpPalier, xpRestante, max }.
function Metiers.Palier(entity, id)
    local paliers = Paliers()
    local xp = Metiers.XP(entity, id)
    local rang = 0
    for index, niveau in ipairs(paliers) do
        if xp >= math.max(0, math.floor(tonumber(niveau.cumul) or 0)) then rang = index
        else break end
    end

    -- Niveau zero : le metier n'est pas appris. La barre vise Rose 1, mais le
    -- libelle et le bonus restent bien a zero.
    if rang == 0 then
        local suivant = paliers[1] or { xp = 0 }
        local cout = math.max(0, math.floor(tonumber(suivant.xp) or 0))
        return {
            rang = 0, nom = "Non appris", niveau = 0, libelle = "Niveau 0",
            rangCouleur = 0, couleur = { 0.45, 0.45, 0.45 },
            xpDansPalier = xp, xpPalier = cout,
            xpRestante = math.max(0, cout - xp), max = false,
        }
    end

    local palier = paliers[rang] or { nom = "?", niveau = 0, xp = 0 }
    local niveau = math.max(0, math.floor(tonumber(palier.niveau) or 0))
    local libelle = niveau > 0 and string.format("%s %d", palier.nom, niveau) or palier.nom
    local maitrise = rang >= #paliers
    local suivant = paliers[rang + 1]
    local debut = math.max(0, math.floor(tonumber(palier.cumul) or 0))
    local cout = suivant and math.max(0, math.floor(tonumber(suivant.xp) or 0)) or 0
    local dans = math.max(0, xp - debut)
    return {
        rang = rang, nom = palier.nom, niveau = niveau, libelle = libelle,
        rangCouleur = math.max(1, math.floor(tonumber(palier.rangCouleur) or rang)),
        couleur = palier.couleur,
        xpDansPalier = maitrise and 1 or dans, xpPalier = maitrise and 1 or cout,
        xpRestante = maitrise and 0 or math.max(0, cout - dans), max = maitrise,
    }
end

-- Bonus de jet d'un metier (Necronicon : GetProfessionRollBonus).
function Metiers.Bonus(entity, id)
    local appris = Metiers.Palier(entity, id).rangCouleur
    local equipement = LCM.Effets and LCM.Effets.Bonus(entity, "metier:" .. tostring(id)) or 0
    return appris + equipement
end

-- Ajoute (ou retire) de l'XP. Ne descend pas sous zero ; efface ce qui
-- revient a zero.
function Metiers.Gagner(entity, id, montant)
    if type(entity) ~= "table" or not Metiers.Get(id) then return false end
    local xp = math.max(0, Metiers.XP(entity, id) + math.floor(tonumber(montant) or 0))
    if xp == 0 then
        if type(entity.metiers) == "table" then
            entity.metiers[tostring(id)] = nil
            if next(entity.metiers) == nil then entity.metiers = nil end
        end
    else
        entity.metiers = type(entity.metiers) == "table" and entity.metiers or {}
        entity.metiers[tostring(id)] = xp
    end
    return true
end
