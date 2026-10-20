-- Qui a l'addon.
--
-- Un ping discret : a la connexion, l'addon envoie « ici? » a tous les autres
-- possesseurs de l'addon ; chacun note sa presence et lui repond « ici » en
-- prive (« moi aussi j'suis la »). Repris de la presence de Necronicon
-- (RememberAddonPresence), mais pour tout le serveur et sans peremption : on
-- a vu quelqu'un, on le sait jusqu'au /reload.
--
-- Pour joindre tout le monde, et pas seulement le groupe, le ping passe par un
-- CANAL de discussion que chaque addon rejoint : un message d'addon ne peut
-- partir qu'au groupe, a la guilde, a un nom precis... ou a un canal.
-- Necronicon faisait de meme pour ses stocks (Resource.lua). Le canal est
-- retire des fenetres de discussion : les messages d'addon ne s'y affichent
-- jamais, et le canal n'a pas a encombrer la liste du joueur. Le groupe recoit
-- aussi le ping, au cas ou le canal manquerait.
--
-- Ce qu'on en fait : un INDICE, jamais un verrou. Le choix des cibles marque
-- « addon non confirmé » sans bloquer la case, et ne propose de toute facon
-- QUE les membres du groupe ou du raid — connaitre un possesseur de l'addon a
-- l'autre bout du monde n'en fait pas une cible.
--
-- Tout vit en memoire vive : rien n'entre en sauvegarde.

local _, LCM = ...

local Presence = {}
LCM.Presence = Presence

Presence.CANAL = "LesContesMalveillants"
-- Un changement de groupe ne relance pas un ping a chaque fois : un groupe qui
-- se forme envoie des rafales d'evenements, et le debit est compte.
Presence.INTERVALLE = 10

local vus = {}
local derniereDemande = -math.huge

local function Maintenant() return (GetTime and GetTime()) or 0 end
local function Court(nom) return tostring(nom or ""):match("^([^-]+)") or tostring(nom or "") end

local function Noter(joueur, version, personnage, portrait)
    joueur = tostring(joueur or "")
    if joueur == "" then return end
    personnage = tostring(personnage or "")
    -- Le meme joueur peut arriver avec ou sans son royaume selon le canal.
    portrait = tostring(portrait or "")
    vus[joueur] = {
        version = version,
        personnage = personnage ~= "" and personnage or nil,
        portrait = portrait ~= "" and portrait or nil,
    }
    vus[Court(joueur)] = vus[joueur]
    if Presence.onChange then Presence.onChange(joueur) end
    for _, fn in ipairs(Presence.suivis) do fn(joueur) end
end

-- D'autres fenetres que le choix des cibles veulent suivre les reponses (le
-- choix des destinataires d'un Link) : `onChange` n'a qu'une place.
Presence.suivis = {}
function Presence.Suivre(fn)
    if type(fn) == "function" then Presence.suivis[#Presence.suivis + 1] = fn end
end

-- Vrai si ce joueur a montre l'addon depuis la connexion.
function Presence.Confirmee(joueur)
    joueur = tostring(joueur or "")
    if joueur == LCM.PlayerId() then return true end
    return (vus[joueur] or vus[Court(joueur)]) ~= nil
end

-- Le nom du personnage que ce joueur joue, tel que son addon l'a annonce, ou
-- nil (pas vu, ou aucun personnage choisi).
function Presence.Personnage(joueur)
    local v = vus[tostring(joueur or "")] or vus[Court(joueur)]
    return v and v.personnage or nil
end

-- L'identifiant de l'artwork suffit pour le HUD de cible : les textures sont
-- deja livrees avec l'addon, aucune fiche personnelle ne voyage pour cela.
function Presence.Portrait(joueur)
    local v = vus[tostring(joueur or "")] or vus[Court(joueur)]
    return v and v.portrait or nil
end

local function NomNormalise(nom)
    return tostring(nom or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

-- Epsilon peut afficher sur l'unite cible le nom RP / LCM plutôt que le nom
-- technique qui signe les messages addon. Cette recherche inverse permet de
-- retrouver l'annonce réseau a partir du nom visible au-dessus du personnage.
function Presence.ParPersonnage(personnage)
    local cherche = NomNormalise(personnage)
    if cherche == "" then return nil end
    local deja = {}
    for joueur, v in pairs(vus) do
        if not deja[v] then
            deja[v] = true
            if NomNormalise(v.personnage) == cherche then return joueur, v end
        end
    end
    return nil
end

-- Ce qu'on annonce de soi : la version, et le personnage joue, le sien meme
-- quand le MJ incarne un PNJ.
local function Moi()
    local perso = LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage()
    local definition = perso and LCM.Portraits and LCM.Portraits.Of and LCM.Portraits.Of(perso)
    -- `Of` couvre aussi la convention portrait.id == personnage.id : une
    -- fiche peut donc avoir un artwork sans champ `portrait` explicite.
    local portrait = definition and definition.id
        or (perso and LCM.Entities.Get_Value(perso, "portrait") or nil)
    return { v = LCM.version, p = perso and perso.name or nil, a = portrait }
end

-- Ceux d'une liste qu'on n'a pas encore vus.
function Presence.Inconnus(joueurs)
    local out = {}
    for _, j in ipairs(joueurs or {}) do if not Presence.Confirmee(j) then out[#out + 1] = j end end
    return out
end

-- ===== Le canal ============================================================

function Presence.Canal()
    if not GetChannelName then return nil end
    local ok, id = pcall(GetChannelName, Presence.CANAL)
    id = ok and tonumber(id) or nil
    return (id and id > 0) and id or nil
end

local function Cacher()
    for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
        local fenetre = _G["ChatFrame" .. i]
        if fenetre and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, fenetre, Presence.CANAL) end
    end
end

function Presence.Rejoindre()
    local id = Presence.Canal()
    if id then return id end
    -- Un canal TEMPORAIRE ne s'ajoute a aucune fenetre de discussion : rien ne
    -- s'affiche, pas meme l'avis d'arrivee. L'ancien chemin reste en repli, et
    -- Cacher avec lui : un canal deja rejoint autrement doit sortir des
    -- fenetres (20 octobre 2026).
    local rejoindre = JoinTemporaryChannel
        or (C_ChatInfo and C_ChatInfo.JoinTemporaryChannel)
        or JoinChannelByName
        or (C_ChatInfo and C_ChatInfo.JoinChannelByName)
    if not rejoindre then return nil end
    pcall(rejoindre, Presence.CANAL)
    Cacher()
    local nouveau = Presence.Canal()
    if nouveau then Presence.Pret() end
    return nouveau
end

-- ===== « Le canal repond » =================================================
-- Le canal n'existe pas encore a la connexion. Ce qui a besoin de parler a
-- tout le monde des qu'il est la — demander aux MJ leurs coffres, leurs
-- points, leurs etals — s'inscrit ici plutot que de deviner le moment.
Presence.attentes = {}
function Presence.QuandCanal(fn)
    if type(fn) ~= "function" then return end
    Presence.attentes[#Presence.attentes + 1] = fn
    -- Deja rejoint : on ne fait pas attendre l'inscrit jusqu'au prochain
    -- evenement de canal.
    if Presence.Canal() then LCM.Proteger("canal", fn) end
end

-- Appelee a chaque fois que le canal devient (ou redevient) disponible.
function Presence.Pret()
    for _, fn in ipairs(Presence.attentes) do LCM.Proteger("canal", fn) end
end

-- ===== Le ping =============================================================

-- `force` passe outre l'intervalle (a la connexion, a l'ouverture du choix
-- des cibles).
function Presence.Demander(force)
    if not force and Maintenant() - derniereDemande < Presence.INTERVALLE then return false end
    derniereDemande = Maintenant()
    local envoye = false
    local id = Presence.Canal()
    if id then envoye = LCM.Reseau.Envoyer("ici?", Moi(), "CHANNEL", id) or envoye end
    local groupe = LCM.Combat and LCM.Combat.CanalGroupe()
    if groupe then envoye = LCM.Reseau.Envoyer("ici?", Moi(), groupe) or envoye end
    return envoye
end

-- On change de personnage : le groupe doit l'apprendre, sinon il cible
-- encore l'ancien nom. Un « ici » sans question : chacun le note.
function Presence.Annoncer()
    local groupe = LCM.Combat and LCM.Combat.CanalGroupe()
    if groupe then return LCM.Reseau.Envoyer("ici", Moi(), groupe) end
    return false
end

LCM.WhenReady(function()
    local R = LCM.Reseau
    -- On me demande : je reponds en prive, et sa question prouve qu'il a
    -- l'addon lui aussi.
    R.Ecouter("ici?", function(expediteur, d)
        Noter(expediteur, d.v, d.p, d.a)
        R.Envoyer("ici", Moi(), "WHISPER", expediteur)
    end)
    R.Ecouter("ici", function(expediteur, d) Noter(expediteur, d.v, d.p, d.a) end)
    -- Le canal n'est pas toujours rejoignable des la connexion : s'il l'est
    -- deja, on pingue ; sinon, on pinguera en le rejoignant (plus bas).
    if Presence.Rejoindre() then Presence.Demander(true) end
end)

-- Le canal vient d'etre rejoint : c'est le moment du ping.
LCM.On("CHAT_MSG_CHANNEL_NOTICE", function(notice, _, _, _, _, _, _, _, nomCanal)
    if (notice == "YOU_JOINED" or notice == "YOU_CHANGED") and tostring(nomCanal or "") == Presence.CANAL then
        Cacher()
        Presence.Demander(true)
        -- Et tout ce qui attendait le canal parle maintenant : « coucou, je
        -- suis la — qui a des coffres, des points, des etals pour moi ? »
        Presence.Pret()
    end
end)

-- Les canaux du jeu sont prets (peu apres la connexion) : on rejoint le notre
-- s'il manque encore.
LCM.On("CHANNEL_UI_UPDATE", function()
    if LCM.ready and not Presence.Canal() then Presence.Rejoindre() end
end)

-- Quelqu'un entre dans le groupe sans qu'on l'ait vu : un ping, au cas ou.
LCM.On("GROUP_ROSTER_UPDATE", function()
    if #Presence.Inconnus(LCM.Combat.Membres()) > 0 then Presence.Demander(false) end
end)
