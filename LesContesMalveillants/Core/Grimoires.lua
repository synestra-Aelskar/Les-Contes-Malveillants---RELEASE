-- Ce qu'une entite possede comme grimoires.
--
-- Le template range les grimoires sous un HUB (fenetre `grimoire_hub`) : chaque
-- grimoire declare le hub auquel il appartient, et le hub montre ceux qu'on a.
-- D'ou la hierarchie : hub › grimoire › sous-grimoire › sorts. Les
-- sous-grimoires sont les `onglets` du catalogue — meme chose, dit avec le mot
-- du jeu.
--
-- On possede son propre grimoire (`personnel`), et ceux qu'on nous donne : le
-- MJ, un objet trouve, une recompense. La possession se range comme les traits,
-- une liste d'identifiants sur l'entite.

local _, LCM = ...
local Grimoires = LCM.Grimoires

local VIDE = {}

-- Lecture : ne cree rien. Un accesseur qui cree sa table au passage seme des
-- tables vides dans la sauvegarde.
local function Portes(entity)
    if type(entity) ~= "table" or type(entity.grimoires) ~= "table" then return VIDE end
    return entity.grimoires
end

local function PortesPourEcrire(entity)
    if type(entity) ~= "table" then return nil end
    entity.grimoires = type(entity.grimoires) == "table" and entity.grimoires or {}
    return entity.grimoires
end

-- Celui que tout le monde a d'office. Il n'y en a qu'un : le declarer deux fois
-- est une faute d'ecriture, pas un choix de jeu.
function Grimoires.Personnel()
    for _, grimoire in ipairs(Grimoires.list) do
        if grimoire.personnel then return grimoire end
    end
    return nil
end

-- ===== Le grimoire personnel, a son nom ==================================
-- Un grimoire vient du compendium : le renommer LA changerait celui de tout le
-- monde. La personnalisation vit donc sur le PERSONNAGE, et ne vaut que pour le
-- grimoire personnel — celui qu'on a d'office et qu'on remplit soi-meme. Les
-- grimoires recus restent ce que le maitre du jeu a ecrit (5 octobre 2026).

local PERSO_MAX = { label = 60, description = 400 }

local function Rogner(valeur, maximum)
    local texte = tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #texte > maximum then texte = texte:sub(1, maximum) end
    return texte
end

function Grimoires.Personnalisation(entity)
    if type(entity) ~= "table" then return nil end
    return type(entity.grimoirePerso) == "table" and entity.grimoirePerso or nil
end

-- `definition` : { label, description, icone }. Un champ vide efface sa
-- surcharge et rend ce que dit le compendium.
function Grimoires.Personnaliser(entity, definition)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    if type(definition) ~= "table" then return false, "definition illisible." end
    local perso = {
        label = Rogner(definition.label, PERSO_MAX.label),
        description = Rogner(definition.description, PERSO_MAX.description),
        icone = Rogner(definition.icone, 200),
    }
    for cle, valeur in pairs(perso) do
        if valeur == "" then perso[cle] = nil end
    end
    -- Plus rien de propre : on retire la table plutot que d'en garder une vide
    -- dans la sauvegarde.
    if not next(perso) then
        entity.grimoirePerso = nil
    else
        entity.grimoirePerso = perso
    end
    if Grimoires.onChange then Grimoires.onChange(entity) end
    return true
end

-- Ce qu'il faut AFFICHER pour ce grimoire, chez ce personnage : sa
-- personnalisation si elle existe, le compendium sinon. Tout ce qui dessine un
-- grimoire passe par ici, sinon la moitie de l'ecran garderait l'ancien nom.
function Grimoires.Affichage(grimoire, entity)
    if type(grimoire) ~= "table" then return nil end
    local perso = grimoire.personnel and Grimoires.Personnalisation(entity) or nil
    if not perso then return grimoire end
    return {
        id = grimoire.id,
        personnel = grimoire.personnel,
        label = perso.label or grimoire.label,
        description = perso.description or grimoire.description,
        icone = perso.icone or grimoire.icone,
    }
end

function Grimoires.Has(entity, id)
    id = tostring(id or "")
    local grimoire = Grimoires.Get(id)
    if grimoire and grimoire.personnel then return true end
    for _, porte in ipairs(Portes(entity)) do
        if porte == id then return true end
    end
    return false
end

-- Les grimoires de l'entite, le personnel d'abord : c'est le sien, il ouvre la
-- liste.
function Grimoires.Possedes(entity)
    local out, vus = {}, {}
    local personnel = Grimoires.Personnel()
    if personnel then
        out[#out + 1] = personnel
        vus[personnel.id] = true
    end
    for _, id in ipairs(Portes(entity)) do
        local grimoire = Grimoires.Get(id)
        if grimoire and not vus[grimoire.id] then
            out[#out + 1] = grimoire
            vus[grimoire.id] = true
        end
    end
    return out
end

-- Les identifiants portes, TOUS, meme ceux dont le grimoire n'existe plus chez
-- ce joueur (contenu pas encore recu). `Possedes` les tait ; le MJ doit pouvoir
-- les voir pour les retirer.
function Grimoires.Ids(entity)
    local out = {}
    for _, id in ipairs(Portes(entity)) do out[#out + 1] = id end
    return out
end

function Grimoires.Donner(entity, id)
    local grimoire = Grimoires.Get(id)
    if not grimoire or type(entity) ~= "table" then return false, "grimoire inconnu." end
    if grimoire.personnel then return false, "ce grimoire est deja le sien." end
    if Grimoires.Has(entity, grimoire.id) then return false, "il le possede deja." end
    local portes = PortesPourEcrire(entity)
    if not portes then return false end
    portes[#portes + 1] = grimoire.id
    return true
end

function Grimoires.Retirer(entity, id)
    id = tostring(id or "")
    local portes = Portes(entity)
    for index = #portes, 1, -1 do
        if portes[index] == id then
            table.remove(portes, index)
            -- Plus rien de porte : on efface la table pour ne pas laisser une
            -- liste vide en sauvegarde.
            if #portes == 0 and type(entity) == "table" then entity.grimoires = nil end
            return true
        end
    end
    return false
end

-- ===== Lecture d'un grimoire ==============================================
-- Les sous-grimoires sont les `onglets` du catalogue ; ces deux fonctions
-- evitent que chaque ecran ait a le savoir.

function Grimoires.SousGrimoires(grimoire)
    return (type(grimoire) == "table" and grimoire.onglets) or VIDE
end

-- Le grimoire personnel ne puise pas dans le catalogue : ses sorts
-- appartiennent au personnage et vivent dans sa sauvegarde (Core/Sorts.lua).
function Grimoires.Sorts(grimoire, rang, entity)
    if type(grimoire) == "table" and grimoire.personnel then
        return LCM.Sorts.Liste(entity)
    end
    local sous = Grimoires.SousGrimoires(grimoire)[rang or 1]
    return (sous and sous.sorts) or VIDE
end

function Grimoires.CompteSorts(grimoire, entity)
    if type(grimoire) == "table" and grimoire.personnel then
        return LCM.Sorts.Compte(entity)
    end
    local total = 0
    for _, sous in ipairs(Grimoires.SousGrimoires(grimoire)) do
        total = total + #(sous.sorts or VIDE)
    end
    return total
end

-- Les premiers sorts, tous sous-grimoires confondus : ce que le hub montre
-- pour donner une idee du grimoire sans l'ouvrir.
function Grimoires.Apercu(grimoire, combien, entity)
    combien = combien or (type(grimoire) == "table" and grimoire.apercu) or 2
    local out = {}
    if type(grimoire) == "table" and grimoire.personnel then
        for _, sort in ipairs(LCM.Sorts.Liste(entity)) do
            if #out >= combien then return out end
            out[#out + 1] = sort
        end
        return out
    end
    for _, sous in ipairs(Grimoires.SousGrimoires(grimoire)) do
        for _, sort in ipairs(sous.sorts or VIDE) do
            if #out >= combien then return out end
            out[#out + 1] = sort
        end
    end
    return out
end
