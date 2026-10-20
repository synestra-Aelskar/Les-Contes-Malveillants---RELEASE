-- Les personnages du joueur.
--
-- Un compte peut porter plusieurs personnages : ce sont des entites comme les
-- autres (meme fiche, meme schema), simplement de nature « player ». Un seul
-- est joue a la fois, et ce choix appartient au personnage WoW connecte — pas
-- au compte : on ne joue pas le meme role sur deux avatars.

local _, LCM = ...

local Personnages = {}
LCM.Personnages = Personnages

local function EtatPerso()
    LCM.EnsureDatabase()
    return LCM.charDb
end

-- Tous les personnages du compte, par ordre alphabetique.
function Personnages.Liste()
    local out = {}
    for _, entity in ipairs(LCM.Entities.All()) do
        if entity.kind == "player" then out[#out + 1] = entity end
    end
    return out
end

function Personnages.Compte()
    return #Personnages.Liste()
end

-- L'identifiant du personnage joue, ou "" si aucun choix n'a ete fait.
function Personnages.ActifId()
    local id = tostring(EtatPerso().personnageActif or "")
    if id == "" then return "" end
    -- Un personnage efface ne doit pas rester « joue ».
    if not LCM.Entities.Get(id) then
        EtatPerso().personnageActif = nil
        return ""
    end
    return id
end

function Personnages.Actif()
    local id = Personnages.ActifId()
    if id == "" then return nil end
    return LCM.Entities.Get(id)
end

function Personnages.Choisir(id)
    id = tostring(id or "")
    local entity = LCM.Entities.Get(id)
    if not entity or entity.kind ~= "player" then
        LCM.Alerte("ce personnage n'existe pas.")
        return nil
    end
    local avant = LCM.Entities.Self()
    EtatPerso().personnageActif = id
    -- Le groupe voit ce nom dans ses listes de cibles (Core/Presence.lua).
    if LCM.Presence and LCM.Presence.Annoncer then LCM.Presence.Annoncer() end
    LCM.Entities.SoiChange(avant)
    if LCM.UI and LCM.UI.Fiche and LCM.UI.Fiche.frame and LCM.UI.Fiche.frame:IsShown() then
        LCM.UI.Fiche.frame:Montrer(entity)
    end
    return entity
end

-- Identifiant stable et lisible, derive du nom. Deux « Reika » ne peuvent pas
-- se recouvrir : le second devient reika-2.
local function IdentifiantLibre(nom)
    local base = tostring(nom or ""):lower()
    base = base:gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if base == "" then base = "personnage" end
    if not LCM.Entities.Get(base) then return base end
    local index = 2
    while LCM.Entities.Get(base .. "-" .. index) do index = index + 1 end
    return base .. "-" .. index
end
Personnages.IdentifiantLibre = IdentifiantLibre

-- Cree un personnage et le rend actif. `valeurs` est ce que l'outil de
-- creation a rassemble : race, statistiques, niveau...
function Personnages.Creer(nom, valeurs, icone)
    nom = tostring(nom or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nom == "" then return nil, "il faut un nom." end
    local entity = LCM.Entities.Create(IdentifiantLibre(nom), nom, "player", icone)
    if not entity then return nil, "creation impossible." end
    for champ, valeur in pairs(valeurs or {}) do
        LCM.Entities.Set_Value(entity, champ, valeur)
    end
    -- L'equipement de depart : une sacoche dans la premiere sacoche. Un
    -- personnage neuf doit pouvoir ramasser quelque chose des sa premiere
    -- seance, sans attendre que le MJ lui donne un sac.
    if LCM.Inventaire and LCM.Sacs and LCM.Sacs.Get("sacoche_de_depart") then
        LCM.Inventaire.Poser(entity, "saccoches", 1, "sacoche_de_depart")
    end
    Personnages.Choisir(entity.id)
    return entity
end

function Personnages.Supprimer(id)
    id = tostring(id or "")
    local entity = LCM.Entities.Get(id)
    if not entity or entity.kind ~= "player" then return false end
    if Personnages.ActifId() == id then EtatPerso().personnageActif = nil end
    return LCM.Entities.Delete(id)
end

-- Resume d'une ligne pour la carte du carrousel.
function Personnages.Resume(entity)
    if type(entity) ~= "table" then return "" end
    local race = tostring(LCM.Entities.Get_Value(entity, "race") or "")
    local niveau = tonumber(LCM.Entities.Get_Value(entity, "niveau")) or 1
    if race == "" then race = "sans race" end
    return string.format("%s — niveau %d", race, niveau)
end
