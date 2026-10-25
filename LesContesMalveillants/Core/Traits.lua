-- Traits.
--
-- Un trait apporte deux choses, et deux seulement :
--   * des bonus a des statistiques — jamais aux six primaires (force,
--     mystique, perception, adresse, esprit, constitution) ;
--   * un « avantage » sur une ou plusieurs expertises : le jet est lance deux
--     fois et l'on garde le meilleur.
--
-- Exemple : « Escalade de la jungle » donne +3 en escalade, et permet de
-- relancer un jet d'escalade quand la situation s'y prete. Le joueur coche la
-- case a cote de son jet : c'est lui qui juge si le trait s'applique.
--
-- Les traits d'une entite sont une LISTE D'IDENTIFIANTS. Le contenu du trait
-- vit dans le code, jamais dans la sauvegarde.
--
-- Bonus et avantage suivent les regles communes de Core/Effets.lua (les memes
-- que pour les objets) ; ce fichier n'ajoute que ce qui est propre au trait :
-- son cout.

local _, LCM = ...

local Traits = { list = {}, byId = {} }
LCM.Traits = Traits

-- L'addon contient les definitions, mais le joueur n'en expose que celles
-- que le MJ lui a revelees. La liste est volontairement en memoire vive : a
-- chaque connexion, le joueur la redemande au MJ de son groupe.
local accesAutorises

function Traits.Accessibles()
    if LCM.IsMaster() then return Traits.list end
    local out = {}
    for _, trait in ipairs(Traits.list) do
        if accesAutorises and accesAutorises[trait.id] then out[#out + 1] = trait end
    end
    return out
end

function Traits.EstAccessible(id)
    if LCM.IsMaster() then return Traits.Get(id) ~= nil end
    return accesAutorises ~= nil and accesAutorises[tostring(id or "")] == true
end

function Traits.DefinirAccessibles(ids)
    accesAutorises = {}
    for id, autorise in pairs(type(ids) == "table" and ids or {}) do
        if autorise and Traits.Get(id) then accesAutorises[tostring(id)] = true end
    end
    if LCM.UI and LCM.UI.Compendium and LCM.UI.Compendium.Actualiser then
        LCM.UI.Compendium.Actualiser()
    end
    if LCM.UI and LCM.UI.Creation and LCM.UI.Creation.Actualiser then
        LCM.UI.Creation.Actualiser()
    end
end

-- La regle vit dans Effets ; le nom reste ici pour qui le lisait deja.
Traits.PRIMAIRES = LCM.Effets.PRIMAIRES

Traits.COUT_MAX = 4

local function Erreur(message)
    error("LCM/Traits : " .. tostring(message), 0)
end

-- Verifie une definition et la met en forme, SANS l'enregistrer. C'est la seule
-- porte des regles d'un trait : l'atelier du MJ s'en sert pour refuser une
-- saisie avant qu'elle n'atteigne la sauvegarde, avec le meme message que le
-- chargement d'un fichier genere.
function Traits.Construire(definition)
    if type(definition) ~= "table" then Erreur("trait invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("trait sans identifiant") end

    -- Un trait coute de 1 a 4 points ; c'est la regle, donc le code la tient.
    local cout = tonumber(definition.cout) or 1
    if LCM.Forge and LCM.Forge.CoutTrait then
        local jeu, rarete, jeuId, rareteId = LCM.Forge.Lire(definition.forge)
        if rareteId and (jeu and jeu.categorie == "traits" or jeuId == "traits") then
            cout = math.max(cout, LCM.Forge.CoutTrait(jeu, rarete or { id = rareteId }))
        end
    end
    if cout ~= math.floor(cout) or cout < 1 or cout > Traits.COUT_MAX then
        Erreur(id .. " : cout invalide (" .. tostring(definition.cout) .. "), attendu 1 a " .. Traits.COUT_MAX)
    end

    local bonus, avantage, desavantage, pourcent = LCM.Effets.Lire(id, definition, Erreur)

    -- Un avantage se PAIE : un par niveau de trait, pas un de plus. Un trait a
    -- 1 point qui relancerait trois jets differents serait la meilleure affaire
    -- de la feuille (regle du 5 octobre 2026).
    local combien = 0
    for _ in pairs(avantage) do combien = combien + 1 end
    if combien > cout then
        Erreur(string.format("%s : %d avantage(s) pour un trait de niveau %d — un par niveau",
            id, combien, cout))
    end

    -- Et il ne porte que sur ce que le trait AMELIORE. Prendre l'avantage sur
    -- un jet qu'on ne touche pas, ou pire sur un jet qu'on penalise, n'a aucun
    -- sens : le desavantage y est deja, de facto.
    for champ in pairs(avantage) do
        local montant = bonus[champ] or 0
        if montant <= 0 then
            Erreur(string.format(
                "%s : avantage sur « %s », que le trait n'améliore pas (%+d) — "
                .. "un avantage se choisit parmi les bonus positifs",
                id, champ, montant))
        end
    end

    -- Icone, description, tags, couleurs... : l'onglet General du compendium.
    return LCM.ChampsCommuns(definition, {
        id = id,
        label = tostring(definition.label or id),
        cout = cout,
        bonus = bonus,
        avantage = avantage,
        desavantage = desavantage,
        pourcent = pourcent,
    }, Erreur)
end

function Traits.Add(definition)
    local trait = Traits.Construire(definition)
    if Traits.byId[trait.id] then Erreur("trait en double : " .. trait.id) end
    Traits.byId[trait.id] = trait
    Traits.list[#Traits.list + 1] = trait
    return trait
end

function Traits.Get(id)
    return Traits.byId[tostring(id or "")]
end

-- Sert aux entrees que le MJ supprime en seance : le retrait vaut tout de
-- suite, et la base suit au /reload (MJ/Brouillons.lua). Les
-- entites qui portaient ce trait gardent son identifiant ; il redevient visible
-- si le trait revient.
function Traits.Retirer(id)
    id = tostring(id or "")
    if not Traits.byId[id] then return false end
    Traits.byId[id] = nil
    for index = #Traits.list, 1, -1 do
        if Traits.list[index].id == id then table.remove(Traits.list, index) end
    end
    return true
end

-- ===== Cote entite =========================================================

-- Lecture seule : ne CREE rien. Un accesseur qui fabrique la table au passage
-- finit par semer des tables vides dans la sauvegarde.
local VIDE = {}
local function OwnedIds(entity)
    if type(entity) ~= "table" or type(entity.traits) ~= "table" then return VIDE end
    return entity.traits
end

-- Version qui ecrit : appelee uniquement quand on ajoute vraiment un trait.
local function OwnedIdsForWrite(entity)
    if type(entity) ~= "table" then return nil end
    entity.traits = type(entity.traits) == "table" and entity.traits or {}
    return entity.traits
end

function Traits.Owned(entity)
    local out = {}
    for _, id in ipairs(OwnedIds(entity)) do
        local trait = Traits.Get(id)
        if trait then out[#out + 1] = trait end
    end
    return out
end

-- Les identifiants portes, TOUS, y compris ceux dont le trait n'existe plus
-- (entree supprimee, ou pas encore recue par ce joueur). `Owned` les
-- tait ; la fiche doit pouvoir les montrer. Une copie : la modifier ne touche
-- pas l'entite.
function Traits.Ids(entity)
    local out = {}
    for _, id in ipairs(OwnedIds(entity)) do out[#out + 1] = id end
    return out
end

function Traits.Cout(trait)
    local cout = tonumber(trait and trait.cout) or 1
    if LCM.Forge and LCM.Forge.CoutTrait then
        local jeu, rarete, jeuId, rareteId = LCM.Forge.Lire(trait and trait.forge)
        if rareteId and (jeu and jeu.categorie == "traits" or jeuId == "traits") then
            cout = math.max(cout, LCM.Forge.CoutTrait(jeu, rarete or { id = rareteId }))
        end
    end
    return cout
end

-- Somme des couts des traits portes et connus.
function Traits.CoutTotal(entity)
    local total = 0
    for _, trait in ipairs(Traits.Owned(entity)) do total = total + Traits.Cout(trait) end
    return total
end

function Traits.Has(entity, traitId)
    for _, id in ipairs(OwnedIds(entity)) do
        if id == tostring(traitId) then return true end
    end
    return false
end

function Traits.Grant(entity, traitId)
    local trait = Traits.Get(traitId)
    if not trait or type(entity) ~= "table" then return false end
    if Traits.Has(entity, trait.id) then return false end
    local owned = OwnedIdsForWrite(entity)
    if not owned then return false end
    owned[#owned + 1] = trait.id
    return true
end

function Traits.Revoke(entity, traitId)
    local owned = OwnedIds(entity)
    for index = #owned, 1, -1 do
        if owned[index] == tostring(traitId) then
            table.remove(owned, index)
            if #owned == 0 then entity.traits = nil end
            return true
        end
    end
    return false
end

-- Somme des bonus de tous les traits portes, pour un champ donne.
function Traits.Bonus(entity, fieldId)
    local total = 0
    for _, trait in ipairs(Traits.Owned(entity)) do
        total = total + (trait.bonus[tostring(fieldId)] or 0)
    end
    return total
end

-- Le premier trait porte qui AMELIORE ce champ. Les jets d'expertise s'en
-- servent pour proposer un avantage ou un desavantage volontaire : les bonus
-- d'une race, d'un objet ou d'un etat ne donnent pas ce choix.
function Traits.BonusPositif(entity, fieldId)
    local cible = tostring(fieldId)
    for _, trait in ipairs(Traits.Owned(entity)) do
        if (tonumber(trait.bonus[cible]) or 0) > 0 then return trait end
    end
    return nil
end

-- Le trait qui accorde l'avantage sur ce jet, s'il y en a un.
function Traits.Advantage(entity, fieldId)
    for _, trait in ipairs(Traits.Owned(entity)) do
        if trait.avantage[tostring(fieldId)] then return trait end
    end
    return nil
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter("traits_acces", function(expediteur, donnees)
        if LCM.Reseau.DansLeGroupe(expediteur) then
            Traits.DefinirAccessibles(donnees and donnees.ids or {})
        end
    end)
    LCM.Reseau.Ecouter("traits_acces_demande", function(expediteur)
        if not LCM.IsMaster() or not Traits.EnvoyerAccessibles then return end
        Traits.EnvoyerAccessibles(expediteur)
    end)
    local function DemanderAcces()
        if LCM.IsMaster() or not LCM.Reseau then return end
        local canal = IsInRaid and IsInRaid() and "RAID" or "PARTY"
        LCM.Reseau.Envoyer("traits_acces_demande", {}, canal)
    end
    LCM.On("PLAYER_LOGIN", DemanderAcces)
    LCM.On("GROUP_ROSTER_UPDATE", DemanderAcces)
    if C_Timer and C_Timer.After then C_Timer.After(1, DemanderAcces) else DemanderAcces() end
end)

-- Les traits portes sont une source d'effets comme une autre.
LCM.Effets.Source("trait", Traits.Owned, function() return Traits.list end)
