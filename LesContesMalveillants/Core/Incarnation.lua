-- Incarner un PNJ.
--
-- Le MJ prend la place d'un personnage non joueur : toutes les fenetres qui
-- montrent « le personnage joue » montrent alors le PNJ, sans qu'aucune d'elles
-- ait a le savoir. C'est `Entities.Self()` qui ment, et c'est le seul endroit
-- qui doit mentir.
--
-- Le catalogue des PNJ (Data/Genere/Compendium_PNJ.lua) est du CONTENU : il est
-- versionne, partage, et ne doit pas bouger en seance. Un PNJ qui entre en jeu
-- recoit donc une INSTANCE, copiee du catalogue au premier usage, rangee dans
-- la sauvegarde du personnage qui l'incarne. Les blessures d'un soir vivent la,
-- pas dans le contenu.
--
-- Plusieurs instances d'un meme PNJ sont possibles : trois gardes du meme
-- modele, chacun avec ses propres blessures.

local _, LCM = ...

local Incarnation = {}
LCM.Incarnation = Incarnation

local VIDE = {}

local function Etat()
    LCM.EnsureDatabase()
    return LCM.charDb
end

-- Lecture : ne cree rien. Un accesseur qui cree sa table au passage laisse une
-- table vide en sauvegarde, et le piege est d'autant plus sournois qu'il ne se
-- voit qu'apres avoir tout efface.
local function Instances()
    local etat = Etat()
    return type(etat.incarnations) == "table" and etat.incarnations or VIDE
end

local function InstancesPourEcrire()
    local etat = Etat()
    etat.incarnations = type(etat.incarnations) == "table" and etat.incarnations or {}
    return etat.incarnations
end

-- Un identifiant d'instance lisible : « pnj:garde », puis « pnj:garde#2 ».
local function IdentifiantLibre(pnjId)
    local base = "pnj:" .. tostring(pnjId)
    local instances = Instances()
    if not instances[base] then return base end
    local index = 2
    while instances[base .. "#" .. index] do index = index + 1 end
    return base .. "#" .. index
end

-- ===== Les instances =======================================================

-- `options.horsScene` : un exemplaire qu'on JOUE sans le mettre en scene
-- (voir Incarnation.Incarner).
function Incarnation.Instancier(pnjId, nom, options)
    local modele = LCM.PNJ.Get(pnjId)
    if not modele then return nil, "PNJ inconnu." end
    local id = IdentifiantLibre(modele.id)
    local instance = {
        id = id,
        modele = modele.id,
        name = tostring(nom or modele.label),
        icon = modele.icone,
        kind = "npc",
        -- Copie des valeurs du modele : a partir d'ici, l'instance vit sa vie.
        values = LCM.Copie(modele.valeurs or {}),
        traits = LCM.Copie(modele.traits or {}),
        metiers = LCM.Copie(modele.metiers or {}),
        equipement = LCM.Copie(modele.equipement or {}),
        etats = LCM.Copie(modele.etats or {}),
        apprentissages = LCM.Copie(modele.apprentissages or {}),
        horsScene = (type(options) == "table" and options.horsScene) and true or nil,
    }
    InstancesPourEcrire()[id] = instance
    return instance
end

function Incarnation.Instance(id)
    return Instances()[tostring(id or "")]
end

-- Les PNJ EN SCENE : ceux que les joueurs ciblent, que le combat invite, dont
-- les rounds font vieillir les etats. `tout` y ajoute les exemplaires hors
-- scene, qu'on joue sans les montrer — pour qui doit tout voir (nettoyer).
function Incarnation.Liste(tout)
    local out = {}
    for _, instance in pairs(Instances()) do
        if tout or not instance.horsScene then out[#out + 1] = instance end
    end
    table.sort(out, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    return out
end

function Incarnation.Oublier(id)
    id = tostring(id or "")
    local instances = Instances()
    if not instances[id] then return false end
    if Incarnation.ActuelleId() == id then Incarnation.Relacher() end
    instances[id] = nil
    if not next(instances) then Etat().incarnations = nil end
    return true
end

-- ===== Prendre et relacher =================================================

function Incarnation.ActuelleId()
    return tostring(Etat().incarne or "")
end

function Incarnation.Actuelle()
    local id = Incarnation.ActuelleId()
    if id == "" then return nil end
    local instance = Incarnation.Instance(id)
    -- Instance effacee ailleurs : on ne reste pas accroche a un fantome.
    if not instance then Etat().incarne = nil return nil end
    return instance
end

function Incarnation.Prendre(id)
    if not LCM.IsMaster() then return nil, "reserve au maitre du jeu." end
    local instance = Incarnation.Instance(id)
    if not instance then return nil, "instance inconnue." end
    local avant = LCM.Entities.Self()
    Etat().incarne = instance.id
    if Incarnation.onChange then Incarnation.onChange(instance) end
    LCM.Entities.SoiChange(avant)
    return instance
end

function Incarnation.Relacher()
    local avant = Incarnation.ActuelleId()
    local qui = LCM.Entities.Self()
    Etat().incarne = nil
    if avant ~= "" and Incarnation.onChange then Incarnation.onChange(nil) end
    LCM.Entities.SoiChange(qui)
    return avant ~= ""
end

-- Jouer un PNJ du catalogue SANS le mettre en scene (le MJ, 2 novembre 2026).
-- Incarner creait une instance, et toute instance etait en scene : chaque
-- clic sur « Incarner » ajoutait un exemplaire ciblable par les joueurs. Ce
-- qu'on incarne ainsi est un exemplaire HORS SCENE, un seul par modele :
-- incarner de nouveau le reprend, avec ses blessures, au lieu d'en creer un
-- autre. Mettre en scene reste le geste « + Scène » (Instancier).
function Incarnation.Incarner(pnjId, nom)
    if not LCM.IsMaster() then return nil, "reserve au maitre du jeu." end
    local modele = LCM.PNJ.Get(pnjId)
    if not modele then return nil, "PNJ inconnu." end
    for _, instance in pairs(Instances()) do
        if instance.horsScene and instance.modele == modele.id then
            return Incarnation.Prendre(instance.id)
        end
    end
    local instance, raison = Incarnation.Instancier(pnjId, nom, { horsScene = true })
    if not instance then return nil, raison end
    return Incarnation.Prendre(instance.id)
end

LCM.AddCommand("incarner", "incarne un PNJ (vide : relacher)", function(argument)
    local cible = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cible == "" then
        if Incarnation.Relacher() then LCM.Ok("tu reprends ta place.")
        else LCM.Info("tu n'incarnes personne.") end
        return
    end
    local instance, raison = Incarnation.Instance(cible) and Incarnation.Prendre(cible)
        or Incarnation.Incarner(cible)
    if not instance then LCM.Alerte(tostring(raison or "PNJ inconnu.")) return end
    LCM.Ok(string.format("tu incarnes %s.", tostring(instance.name)))
end, true)
