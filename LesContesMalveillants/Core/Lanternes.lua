-- La lanterne : ce qui eclaire, et ce qui la nourrit.
--
-- Repris du module Lanterne d'OmegaSurvive (Survive/Modules/Lantern, 22
-- octobre 2026). Une LANTERNE consomme, un CRISTAL (le « reactif » de
-- Survive) se consume : la lanterne porte un multiplicateur, le cristal une
-- duree en minutes, et la charge s'ecoule a `multiplicateur x variateur`
-- secondes par seconde tant que la lanterne est allumee.
--
-- Ce qui est garde tel quel, parce que c'est la regle :
--   * chaque cristal garde SA charge quand on en change : remettre un cristal
--     a moitie use le rend a moitie, un cristal jamais pose arrive plein.
--     Survive la retenait par TYPE de reactif ; elle vit ici sur le cristal
--     lui-meme, son exemplaire (23 octobre 2026) — voir « Les cristaux » ;
--   * changer de cristal (le « Recharger » de Survive) eteint la lanterne,
--     hors pause ;
--   * le MJ arrete l'ecoulement par une phrase dite en alerte, raid ou groupe
--     (« pause »), et le relance par une autre (« reprise »). Pendant la pause
--     le joueur peut encore allumer et eteindre — c'est l'aura qui suit, pas
--     le temps ;
--   * les auras du serveur : une regle dit QUAND (allumer, eteindre, vide,
--     pause, reprise) et QUOI (un numero de sort -> `.aura` / `.unaura`, ou
--     une commande entiere) ;
--
-- Ce qui change, et pourquoi :
--   * le catalogue (lanternes, cristaux) est du contenu du compendium, pas
--     une liste que le joueur edite dans la sauvegarde (CLAUDE.md, regle 1) ;
--   * les cases « Auras actives » et « Phrases de controle » de Survive ne
--     sont pas reprises : une regle ecrite EST une regle active, et une liste
--     vide n'agit pas. Deux cases pour dire la meme chose divergeaient ;
--   * l'activation rapide a cote du lanceur n'existe pas ici : la lanterne
--     s'equipe depuis l'onglet Outils de la fiche. La ceinture dessinee du
--     menu radial et la fenetre de la lanterne ont ete retirees le 25
--     octobre 2026, a refaire plus epure : ce module reste leur seul socle ;
--   * rien n'existe sans etre possede (23 octobre 2026) : la lanterne
--     s'EQUIPE sur la ceinture, les cristaux viennent des sacs LCM, et un
--     cristal reste terne a 0 %, puis disparait au retrait. La
--     « Vérification inventaire » de Survive (un objet du JEU, par son ID)
--     n'a donc plus lieu d'etre et a ete retiree (le MJ, 23 octobre 2026) :
--     une entree qui en porte encore les champs les voit ignores ;
--   * le temps ne s'ecoule pas deconnecte, comme dans Survive : l'horloge de
--     reference est `GetTime()`, qui repart a chaque session. Elle ne va donc
--     PAS en sauvegarde.

local _, LCM = ...

local function Texte(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end


-- Core se charge avant Data : l'equilibrage se lit au premier appel.
local function Eq() return LCM.Equilibrage.lanterne end

local SECONDES_PAR_MINUTE = 60

-- ===== Lecture des regles ecrites ==========================================
-- Les regles se saisissent en texte, une par ligne, dans l'editeur du
-- compendium : la forme en tableaux de Survive (une ligne de formulaire par
-- regle) attendra l'interface plus profonde annoncee. Le texte reste ce qui
-- est enregistre ; la lecture se refait a la demande et se garde en cache.

local SANS_ACCENT = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
    ["ç"] = "c", ["ÿ"] = "y", ["À"] = "a", ["Â"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e",
    ["Î"] = "i", ["Ô"] = "o", ["Ù"] = "u", ["Û"] = "u", ["Ç"] = "c", ["œ"] = "oe", ["Œ"] = "oe",
    ["æ"] = "ae", ["Æ"] = "ae",
}

-- Une phrase de controle se compare sans casse, sans accents ni ponctuation :
-- « Pause ! » du MJ et « pause » ecrit dans l'entree sont la meme phrase.
local function Normaliser(texte)
    local s = Texte(texte)
    for avec, sans in pairs(SANS_ACCENT) do s = s:gsub(avec, sans) end
    s = s:lower():gsub("[%p]+", " "):gsub("%s+", " ")
    return Texte(s)
end

local CONDITIONS = {
    allumer = "allumer", allume = "allumer",
    eteindre = "eteindre", eteint = "eteindre",
    vide = "vide", dechargee = "vide",
    pause = "pause",
    reprise = "reprise",
}
local CONDITIONS_TEXTE = "allumer, eteindre, vide, pause, reprise"

local CANAUX = {
    alerte = "RAID_WARNING", raid = "RAID", groupe = "GROUP",
}
local EVENEMENTS_CANAL = {
    RAID_WARNING = { CHAT_MSG_RAID_WARNING = true },
    RAID = { CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true },
    GROUP = { CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true,
              CHAT_MSG_INSTANCE_CHAT = true, CHAT_MSG_INSTANCE_CHAT_LEADER = true },
}

local function Lignes(texte)
    local out = {}
    for ligne in (tostring(texte or "") .. "\n"):gmatch("([^\n]*)\n") do
        ligne = Texte(ligne)
        if ligne ~= "" then out[#out + 1] = ligne end
    end
    return out
end

-- « condition : commande » ou « condition : commande : phrase ». La phrase ne
-- vaut que pour pause et reprise : elle restreint la regle a cette phrase-la.
local function LireAuras(id, nom, texte, Erreur)
    local regles = {}
    for n, ligne in ipairs(Lignes(texte)) do
        local condition, reste = ligne:match("^([^:]+):(.*)$")
        local cle = condition and CONDITIONS[Normaliser(condition)]
        if not cle then
            Erreur(string.format("%s : %s, ligne %d illisible (%s) ; attendu « condition : commande », condition parmi %s",
                id, nom, n, ligne, CONDITIONS_TEXTE))
        end
        local commande, phrase = reste:match("^([^:]*):(.*)$")
        commande = Texte(commande or reste)
        phrase = Texte(phrase)
        if commande == "" then
            Erreur(string.format("%s : %s, ligne %d sans commande (%s)", id, nom, n, ligne))
        end
        regles[#regles + 1] = { condition = cle, commande = commande, phrase = phrase ~= "" and phrase or nil }
    end
    return regles
end

-- Une phrase par ligne ; « phrase : eteindre » met en pause ET eteint.
local function LirePhrases(texte, avecEffet)
    local out = {}
    for _, ligne in ipairs(Lignes(texte)) do
        local phrase, effet = ligne, nil
        if avecEffet then
            local avant, apres = ligne:match("^(.*):([^:]*)$")
            if avant and CONDITIONS[Normaliser(apres)] == "eteindre" then phrase, effet = Texte(avant), "eteindre" end
        end
        local cle = Normaliser(phrase)
        if cle ~= "" then out[#out + 1] = { texte = phrase, cle = cle, eteindre = effet == "eteindre" } end
    end
    return out
end

local function LireCanaux(id, texte, Erreur)
    local out = {}
    for mot in tostring(texte or ""):gmatch("[^,;%s]+") do
        local canal = CANAUX[Normaliser(mot)]
        if not canal then
            Erreur(string.format("%s : canal inconnu (%s) ; attendu alerte, raid ou groupe", id, mot))
        end
        out[canal] = true
    end
    return out
end

local cache = setmetatable({}, { __mode = "k" })

-- Les regles d'une entree, lues. Une entree publiee a deja ete verifiee a sa
-- construction : ici, une erreur ne peut plus arriver.
local function Regles(element)
    if not element then return nil end
    local signature = table.concat({ tostring(element.aurasPosees or ""), tostring(element.aurasRetirees or ""),
        tostring(element.phrasesPause or ""), tostring(element.phrasesReprise or ""),
        tostring(element.canaux or "") }, "\1")
    local c = cache[element]
    if c and c.signature == signature then return c end
    local ok, poser = pcall(LireAuras, element.id, "auras posees", element.aurasPosees, error)
    local ok2, retirer = pcall(LireAuras, element.id, "auras retirees", element.aurasRetirees, error)
    local ok3, canaux = pcall(LireCanaux, element.id, element.canaux, error)
    c = {
        signature = signature,
        poser = ok and poser or {}, retirer = ok2 and retirer or {},
        pause = LirePhrases(element.phrasesPause, true),
        reprise = LirePhrases(element.phrasesReprise, false),
        canaux = ok3 and canaux or {},
    }
    cache[element] = c
    return c
end

-- ===== Les registres =======================================================

-- Ce que la lanterne et le cristal partagent : les auras et les phrases du MJ.
local function Commun(definition, element, Erreur)
    local id = element.id
    for _, cle in ipairs({ "aurasPosees", "aurasRetirees", "phrasesPause", "phrasesReprise", "canaux" }) do
        local s = Texte(definition[cle])
        element[cle] = s ~= "" and tostring(definition[cle]) or nil
    end
    LireAuras(id, "auras posées", element.aurasPosees, Erreur)
    LireAuras(id, "auras retirées", element.aurasRetirees, Erreur)
    local canaux = LireCanaux(id, element.canaux, Erreur)
    if (element.phrasesPause or element.phrasesReprise) and next(canaux) == nil then
        Erreur(id .. " : des phrases de contrôle sans canal ne seront jamais entendues (alerte, raid, groupe)")
    end
end

local function Positif(id, nom, valeur, Erreur)
    local n = tonumber(valeur)
    if not n or n <= 0 then
        Erreur(string.format("%s : %s invalide (%s), attendu un nombre au-dessus de zéro", id, nom, tostring(valeur)))
    end
    return n
end

LCM.Lanternes = LCM.Registre({
    nom = "lanterne", prefixe = "Lanternes",
    construire = function(definition, element, Erreur)
        element.multiplicateur = Positif(element.id, "multiplicateur", definition.multiplicateur, Erreur)
        Commun(definition, element, Erreur)
    end,
})

LCM.Cristaux = LCM.Registre({
    nom = "cristal", prefixe = "Cristaux",
    construire = function(definition, element, Erreur)
        element.duree = Positif(element.id, "durée", definition.duree, Erreur)
        -- Pas de regles d'aura ni de phrases du MJ sur un cristal (le MJ, 23
        -- octobre 2026) : c'est la lanterne qu'on allume et qu'on eteint, pas
        -- son combustible. Celles qu'un cristal porterait encore sont ignorees.
    end,
})

-- ===== La lanterne portee ==================================================
-- Une par personnage, dans LCM_CharDB. Ce qui y va : le choix, la charge, le
-- reglage, les emotes reecrites. Ce qui n'y va pas : l'horloge.

local L = {}
LCM.Lanterne = L

L.EMOTES = {
    { cle = "on",       label = "Allumer",            defaut = "allume sa lanterne." },
    { cle = "off",      label = "Éteindre",           defaut = "éteint sa lanterne." },
    { cle = "open",     label = "Ouvrir",             defaut = "examine sa lanterne." },
    { cle = "close",    label = "Fermer",             defaut = "remet sa lanterne à sa ceinture." },
    { cle = "recharge", label = "Recharger",          defaut = "change le réactif de sa lanterne." },
    { cle = "swap",     label = "Changer de cristal", defaut = "" },
    { cle = "empty",    label = "Déchargée",          defaut = "" },
}
local EMOTE_DEFAUT = {}
for _, e in ipairs(L.EMOTES) do EMOTE_DEFAUT[e.cle] = e.defaut end

L.CANAUX_EMOTE = {
    { id = "EMOTE", label = "/me" },
    { id = "SAY",   label = "/s" },
    { id = "RAID",  label = "/raid" },
}

local VIDE = {}
local derniere            -- GetTime() du dernier ecoulement compte

-- Lecture : ne cree rien.
local function Etat()
    local c = LCM.charDb
    return (c and type(c.lanterne) == "table") and c.lanterne or VIDE
end
L.Etat = Etat

local function EtatPourEcriture()
    LCM.EnsureDatabase()
    local c = LCM.charDb
    c.lanterne = type(c.lanterne) == "table" and c.lanterne or {}
    return c.lanterne
end

local function Maintenant() return GetTime and GetTime() or 0 end

local function Notifier(texte, alerte)
    if alerte then LCM.Alerte(texte) else LCM.Info(texte) end
    if L.onChange then pcall(L.onChange) end
end

-- ----- Ce que le joueur porte -----------------------------------------------
-- Une lanterne ou un cristal n'existe pour le joueur que s'il le possede (le
-- MJ, 23 octobre 2026). Le compendium dit ce qui PEUT exister, le personnage
-- ce qu'il A. Il n'y a plus de contenu livre par defaut.
--
-- La LANTERNE s'equipe sur la ceinture porte-outils, ou elle prend une des
-- places des outils (Equilibrage.conteneurs.outil). C'est la lanterne
-- equipee qui eclaire : le menu Lanterne ne s'ouvre pas sans elle, et c'est
-- elle qu'il montre. Les CRISTAUX restent dans les sacs.
--
-- La lanterne equipee vit sur le personnage LCM (`entity.lanterneEquipee`),
-- comme ce qu'il porte : changer de personnage change de lanterne.

local function Moi() return LCM.Entities and LCM.Entities.Self() end
-- Defini avec les cristaux, plus bas : la lanterne qu'on retire rend le sien.
local Remiser

local function Possede(famille, id)
    local moi = Moi()
    if not (moi and id and LCM.Inventaire) then return false end
    return LCM.Inventaire.Chercher(moi, famille .. "/" .. id) ~= nil
end

-- L'identifiant equipe, tel qu'il est ecrit (meme si l'entree a disparu du
-- compendium : elle reste portee, et se retire comme le reste).
function L.IdEquipe(entity)
    entity = entity or Moi()
    return type(entity) == "table" and entity.lanterneEquipee or nil
end

function L.LanterneEquipee(entity)
    return LCM.Lanternes.Get(L.IdEquipe(entity))
end

-- Les places de la ceinture : les outils (Core/Objets) plus la lanterne.
function L.PlacesCeinture(entity)
    local capacite = LCM.Objets.Capacite("outil")
    local prises = #LCM.Objets.Ids(entity, "outil") + (L.IdEquipe(entity) and 1 or 0)
    return capacite, prises
end

-- Equiper une lanterne des sacs. Une lanterne deja portee retourne au sac a
-- sa place (l'echange ne demande donc pas de place libre sur la ceinture).
function L.EquiperLanterne(id)
    local moi = Moi()
    if not moi then return false, "aucun personnage." end
    local lanterne = LCM.Lanternes.Get(id)
    if not lanterne then return false, "lanterne inconnue : " .. tostring(id) end
    local ancien = L.IdEquipe(moi)
    if ancien == lanterne.id then return true end
    if not Possede("lanternes", lanterne.id) then
        return false, lanterne.label .. " n'est dans aucun de tes sacs."
    end
    local capacite, prises = L.PlacesCeinture(moi)
    if not ancien and prises >= capacite then
        return false, "la ceinture est pleine : retire un outil d'abord."
    end
    if ancien and L.Allumee() then L.Eteindre() end
    LCM.Inventaire.Prendre(moi, "lanternes/" .. lanterne.id)
    if ancien then
        local ok, raison = LCM.Inventaire.Deposer(moi, "lanternes/" .. ancien, 1)
        if not ok then
            -- L'ancienne ne trouve pas de place : on annule tout.
            LCM.Inventaire.Deposer(moi, "lanternes/" .. lanterne.id, 1)
            return false, "pas de place dans les sacs pour l'ancienne lanterne : " .. tostring(raison)
        end
    end
    moi.lanterneEquipee = lanterne.id
    EtatPourEcriture().lanterne = lanterne.id
    if L.onChange then pcall(L.onChange) end
    return true
end

-- Remettre la lanterne au sac. Sans place libre, elle reste portee : on ne la
-- fait pas disparaitre faute de sac (comme Objets.Desequiper).
function L.RetirerLanterne()
    local moi = Moi()
    local id = L.IdEquipe(moi)
    if not id then return false, "aucune lanterne n'est équipée." end
    if L.Allumee() then L.Eteindre() end
    -- Son cristal retourne aux sacs avec elle, et garde sa charge.
    local rendu, pourquoi = Remiser(moi)
    if not rendu then return false, "la lanterne reste équipée : " .. tostring(pourquoi) end
    if LCM.Lanternes.Get(id) then
        local ok, raison = LCM.Inventaire.Deposer(moi, "lanternes/" .. id, 1)
        if not ok then
            return false, "la lanterne reste équipée : " .. (raison == "aucune place libre."
                and "aucune place libre dans les sacs." or tostring(raison))
        end
    end
    moi.lanterneEquipee = nil
    if L.onChange then pcall(L.onChange) end
    return true
end

local function Portees(registre, famille)
    local out = {}
    for _, e in ipairs(registre.list) do
        if Possede(famille, e.id) then out[#out + 1] = e end
    end
    return out
end

function L.LanternesPortees() return Portees(LCM.Lanternes, "lanternes") end

-- La lanterne telle qu'elle est ecrite, portee ou non : sert a retirer les
-- auras d'une lanterne qu'on vient de perdre (la derniere equipee).
local function ChoixEcrit() return LCM.Lanternes.Get(Etat().lanterne) end

-- La lanterne qui eclaire : celle de la ceinture, et aucune autre.
function L.LanterneChoisie() return L.LanterneEquipee() end

-- ----- Les cristaux -----------------------------------------------------------
-- Un cristal a SA charge, et elle le suit (le MJ, 23 octobre 2026). Elle vit
-- sur son exemplaire (Core/Exemplaires.lua), en secondes d'eclairage :
--
--   * POSE, il quitte les sacs et vit dans la lanterne, sur le personnage
--     (`entity.cristalPose`, son exemplaire). C'est la que la charge baisse ;
--   * RETIRE, il retourne dans les sacs. Plein, il redevient un cristal
--     ordinaire, sans pourcentage, et s'empile avec les autres. Entame, il va
--     dans « Cristaux en cours d'usage » (Core/Inventaire.lua, la poche),
--     empile avec ceux de son modele mais avec SA charge. Vide, il disparait ;
--   * il s'echange, se donne, se pose dans un coffre comme un objet : sa
--     charge voyage avec son exemplaire.

local function Plein(cristal) return cristal.duree * SECONDES_PAR_MINUTE end

local function ModeleDe(exemplaire)
    local id = type(exemplaire) == "table" and tostring(exemplaire.ref or ""):match("^cristaux/(.+)$")
    return id and LCM.Cristaux.Get(id) or nil
end

-- L'exemplaire pose dans la lanterne, ou nil. Lecture : ne cree rien.
function L.CristalPose(entity)
    entity = entity or Moi()
    local pose = type(entity) == "table" and entity.cristalPose
    return type(pose) == "table" and pose or nil
end

function L.CristalChoisi() return ModeleDe(L.CristalPose()) end

-- Le pourcentage d'un cristal, ou nil s'il est plein. Un cristal qui garde un
-- souffle de charge ne s'affiche pas a 0 % : on le croirait vide.
function L.Pourcent(exemplaire)
    local cristal = ModeleDe(exemplaire)
    local charge = type(exemplaire) == "table" and tonumber(exemplaire.charge)
    if not (cristal and charge) or charge >= Plein(cristal) then return nil end
    if charge <= 0 then return 0 end
    return math.max(1, math.min(99, math.floor(charge / Plein(cristal) * 100)))
end

-- « Cristal raffiné (62 %) » pour un entame, son nom seul pour un plein.
function L.LibelleCristal(exemplaire)
    local cristal = ModeleDe(exemplaire)
    if not cristal then return "Cristal inconnu" end
    local pourcent = L.Pourcent(exemplaire)
    return pourcent and string.format("%s (%d %%)", cristal.label, pourcent) or cristal.label
end

-- Ce qu'on peut poser, dans l'ordre du compendium : pour chaque modele, les
-- pleins (une seule option, ils sont interchangeables), puis chaque entame,
-- le plus charge d'abord. { id, label, cristal, exemplaire }.
function L.CristauxPortes()
    local moi, out = Moi(), {}
    if not moi then return out end
    local Inv = LCM.Inventaire
    for _, cristal in ipairs(LCM.Cristaux.list) do
        local ref = "cristaux/" .. cristal.id
        local pleins, entames = 0, {}
        for _, p in ipairs(Inv.Piles(moi, ref)) do
            if Inv.Entame(p.pile) then
                for _, x in ipairs(p.pile.exemplaires) do
                    if type(x) == "table" and x.charge ~= nil then entames[#entames + 1] = x end
                end
            else
                pleins = pleins + (tonumber(p.pile.quantite) or 1)
            end
        end
        if pleins > 0 then out[#out + 1] = { id = "plein:" .. cristal.id, label = cristal.label, cristal = cristal } end
        table.sort(entames, function(a, b) return (tonumber(a.charge) or 0) > (tonumber(b.charge) or 0) end)
        for _, x in ipairs(entames) do
            out[#out + 1] = { id = "entame:" .. x.id, label = L.LibelleCristal(x), cristal = cristal, exemplaire = x }
        end
    end
    return out
end

-- Un choix de la liste, ou le nom d'un modele (« plein » sous-entendu).
local function Option(choix)
    choix = tostring(choix or "")
    if not choix:find(":", 1, true) then choix = "plein:" .. choix end
    for _, o in ipairs(L.CristauxPortes()) do
        if o.id == choix then return o end
    end
end

-- Sort des sacs le cristal de cette option et rend son exemplaire (une copie
-- detachee du sac). Un plein : le premier d'une pile pleine.
local function Sortir(moi, option)
    local Inv, ref = LCM.Inventaire, "cristaux/" .. option.cristal.id
    local exemplaire = option.exemplaire
    if not exemplaire then
        for _, p in ipairs(Inv.Piles(moi, ref)) do
            if not Inv.Entame(p.pile) then
                exemplaire = LCM.Exemplaires.Assurer(p.pile)[1]
                break
            end
        end
    end
    if not exemplaire then return nil, "ce cristal n'est dans aucun de tes sacs." end
    local copie = LCM.Copie(exemplaire)
    local ok, raison = Inv.RetirerExemplaire(moi, ref, copie.id)
    if not ok then return nil, raison end
    return copie
end

-- Remet dans les sacs le cristal pose. Plein, il perd sa charge ecrite (il
-- redevient un cristal ordinaire, qui s'empile) ; entame, il la garde et va
-- dans la poche ; vide, il disparait (le MJ, 23 octobre 2026). Sans place, il
-- reste pose : on ne le fait pas disparaitre faute de sac.
Remiser = function(moi)
    local pose = L.CristalPose(moi)
    if not pose then return true end
    local cristal = ModeleDe(pose)
    if not cristal then
        return false, "ce cristal n'existe plus dans le compendium : il reste dans la lanterne."
    end
    local x = LCM.Copie(pose)
    local charge = tonumber(x.charge) or Plein(cristal)
    if charge > 0 then
        x.charge = charge < Plein(cristal) and charge or nil
        local ok, raison = LCM.Inventaire.Deposer(moi, x.ref, 1, { x })
        if not ok then return false, "le cristal retiré ne trouve pas de place : " .. tostring(raison) end
    end
    moi.cristalPose = nil
    return true
end

function L.Variateur()
    local v = tonumber(Etat().variateur)
    return v or Eq().variateurDefaut
end

function L.EnPauseMJ()
    local e = Etat()
    return e.pauseMJ == true
end

-- Allumee, pour le joueur : en marche, ou allumee pendant la pause du MJ.
function L.Allumee()
    local e = Etat()
    if e.pauseMJ then return e.actifEnPause == true end
    return e.mode == "on"
end

local function Facteur()
    local lanterne = L.LanterneChoisie()
    if not lanterne then return 0 end
    return lanterne.multiplicateur * L.Variateur()
end

function L.ChargeMax()
    local cristal = L.CristalChoisi()
    return cristal and Plein(cristal) or 0
end

function L.Charge()
    local pose = L.CristalPose()
    if not (pose and L.CristalChoisi()) then return 0 end
    return math.max(0, math.min(tonumber(pose.charge) or L.ChargeMax(), L.ChargeMax()))
end

-- Le temps d'eclairage qui reste, en secondes reelles.
function L.Restant()
    local f = Facteur()
    if f <= 0 then return 0 end
    return L.Charge() / f
end

-- ----- Commandes du serveur ------------------------------------------------

-- `.aura` / `.unaura` pour un numero de sort, la commande telle quelle sinon.
-- Comme Survive : raid, puis guilde, puis /dire — le premier canal qui prend.
local function Commande(commande, retrait)
    commande = Texte(commande)
    if commande == "" or not SendChatMessage then return false end
    if commande:match("^%d+$") then commande = (retrait and ".unaura " or ".aura ") .. commande end
    local canaux = {}
    if IsInRaid and IsInRaid() then canaux[#canaux + 1] = "RAID" end
    if IsInGuild and IsInGuild() then canaux[#canaux + 1] = "GUILD" end
    canaux[#canaux + 1] = "SAY"
    for _, canal in ipairs(canaux) do
        if pcall(SendChatMessage, commande, canal) then return true end
    end
    return false
end
L.Commande = Commande

local function Choisies()
    local out = {}
    local lanterne, cristal = L.LanterneChoisie(), L.CristalChoisi()
    if lanterne then out[#out + 1] = lanterne end
    if cristal then out[#out + 1] = cristal end
    return out
end

-- Joue les regles d'une condition ; rend combien de commandes sont parties.
-- `elements` : par defaut, ce qui est choisi ET porte.
local function Auras(cote, condition, message, elements)
    local n = 0
    local normalise = Normaliser(message)
    for _, element in ipairs(elements or Choisies()) do
        for _, regle in ipairs(Regles(element)[cote]) do
            if regle.condition == condition
                and (not regle.phrase or Normaliser(regle.phrase) == normalise) then
                if Commande(regle.commande, cote == "retirer") then n = n + 1 end
            end
        end
    end
    return n
end
L.Auras = Auras

local function PoserAuraActive(v) EtatPourEcriture().auraActive = v and true or nil end

-- ----- Emotes ---------------------------------------------------------------

local MAJUSCULE = { ["à"] = "À", ["â"] = "Â", ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["î"] = "Î",
                    ["ô"] = "Ô", ["ù"] = "Ù", ["û"] = "Û", ["ç"] = "Ç" }
local MINUSCULE = {}
for petite, grande in pairs(MAJUSCULE) do MINUSCULE[grande] = petite end

local function PremiereLettre(texte, table_, motif, fn)
    for de, vers in pairs(table_) do
        if texte:sub(1, #de) == de then return vers .. texte:sub(#de + 1) end
    end
    return (texte:gsub(motif, fn, 1))
end

-- /me attend une suite de phrase (« allume sa lanterne. ») ; les autres
-- canaux, une action entre asterisques (« *Allume sa lanterne.* »).
function L.FormaterEmote(texte, canal)
    local s = Texte(texte):gsub("^%*+", ""):gsub("%*+$", "")
    if s == "" then return "" end
    if canal == "EMOTE" then return PremiereLettre(s, MINUSCULE, "^%u", string.lower) end
    return "*" .. PremiereLettre(s, MAJUSCULE, "^%l", string.upper) .. "*"
end

function L.Emote(cle)
    local perso = Etat().emotes
    if type(perso) == "table" and perso[cle] ~= nil then return perso[cle] end
    return EMOTE_DEFAUT[cle] or ""
end

-- Une emote egale a son defaut s'oublie : la sauvegarde ne garde que ce que le
-- joueur a reecrit.
function L.DefinirEmote(cle, texte)
    if EMOTE_DEFAUT[cle] == nil then return false, "émote inconnue : " .. tostring(cle) end
    local e = EtatPourEcriture()
    texte = Texte(texte)
    e.emotes = type(e.emotes) == "table" and e.emotes or {}
    e.emotes[cle] = texte ~= EMOTE_DEFAUT[cle] and texte or nil
    if next(e.emotes) == nil then e.emotes = nil end
    return true
end

function L.RestaurerEmotes()
    local e = EtatPourEcriture()
    e.emotes = nil
end

function L.CanalEmote() return Etat().canalEmote or "EMOTE" end

function L.DefinirCanalEmote(canal)
    for _, c in ipairs(L.CANAUX_EMOTE) do
        if c.id == canal then
            EtatPourEcriture().canalEmote = canal ~= "EMOTE" and canal or nil
            return true
        end
    end
    return false, "canal inconnu : " .. tostring(canal)
end

function L.DireEmote(cle)
    local canal = L.CanalEmote()
    local texte = L.FormaterEmote(L.Emote(cle), canal)
    if texte == "" or not SendChatMessage then return false end
    pcall(SendChatMessage, texte, canal)
    return true
end

-- ----- L'ecoulement ---------------------------------------------------------

-- Une lanterne allumee qui n'a plus sa lanterne ou son cristal (un autre
-- personnage choisi, une entree retiree du compendium) s'eteint, et ses auras
-- partent avec. On retire celles de la lanterne ECRITE : celle qu'on porte ne
-- suffirait pas, elle n'y est plus.
local function Perdue()
    if L.LanterneChoisie() and L.CristalChoisi() then return false end
    local lanterne = ChoixEcrit()
    local w = EtatPourEcriture()
    if w.pauseMJ then w.actifEnPause, w.reprise = false, "off" else w.mode = "off" end
    Auras("retirer", "eteindre", nil, lanterne and { lanterne } or {})
    PoserAuraActive(false)
    Notifier("ta lanterne s'éteint : il lui manque sa lanterne ou son cristal.", true)
    return true
end

-- Compte le temps passe depuis le dernier appel. C'est la seule porte par ou
-- la charge baisse : tout ce qui lit ou change la lanterne passe d'abord ici.
function L.Synchroniser(maintenant)
    maintenant = maintenant or Maintenant()
    local e = Etat()
    if e ~= VIDE and L.Allumee() and Perdue() then
        derniere = maintenant
        return
    end
    local pose = L.CristalPose()
    if e ~= VIDE and e.mode == "on" and not e.pauseMJ and derniere and pose then
        local ecoule = math.max(0, maintenant - derniere)
        local charge = L.Charge()
        if ecoule > 0 and charge > 0 then
            charge = math.max(0, charge - ecoule * Facteur())
            pose.charge = charge
            if charge <= 0 then
                pose.charge, e.mode = 0, "off"
                Auras("retirer", "vide")
                PoserAuraActive(false)
                L.DireEmote("empty")
                -- La lanterne affiche le cristal vide et terne jusqu'a son
                -- retrait. Remiser elimine ce cristal sans charge au retrait.
                local modele = ModeleDe(pose)
                e.dernierCristal = modele and modele.id or nil
                Notifier("ton cristal est épuisé : la lanterne s'éteint.", true)
            end
        end
    end
    derniere = maintenant
end

local function Controler()
    local lanterne, cristal = L.LanterneChoisie(), L.CristalChoisi()
    if not (lanterne and cristal) then
        return false, "choisis une lanterne et un cristal avant de l'allumer."
    end
    if L.Charge() <= 0 then return false, "la lanterne est déchargée : change de cristal avant de l'allumer." end
    return true
end

function L.Allumer()
    L.Synchroniser()
    if L.Allumee() then return false, "elle est déjà allumée." end
    local ok, raison = Controler()
    if not ok then return false, raison end
    local e = EtatPourEcriture()
    if e.pauseMJ then
        -- Pendant la pause, on rallume l'aura sans relancer le temps.
        e.actifEnPause, e.reprise = true, "on"
        if Auras("poser", "allumer") > 0 then PoserAuraActive(true) end
    else
        e.mode = "on"
        Auras("poser", "allumer")
        PoserAuraActive(true)
    end
    L.DireEmote("on")
    return true
end

function L.Eteindre()
    L.Synchroniser()
    if not L.Allumee() then return false, "elle est déjà éteinte." end
    local e = EtatPourEcriture()
    if e.pauseMJ then
        e.actifEnPause, e.reprise = false, "off"
    else
        e.mode = "off"
    end
    Auras("retirer", "eteindre")
    PoserAuraActive(false)
    L.DireEmote("off")
    return true
end

function L.Basculer()
    if L.Allumee() then return L.Eteindre() end
    return L.Allumer()
end

local function Eteinte(e)
    e.mode, e.pauseMJ, e.reprise, e.actifEnPause = "off", nil, nil, nil
end

-- Pose un cristal des sacs (`choix` : un id de L.CristauxPortes, ou le nom
-- d'un modele pour un plein), ou retire celui qui est pose (`choix` nil). Le
-- cristal retire retourne aux sacs avec sa charge (Remiser) ; celui qu'on pose
-- reprend la sienne, ou arrive plein s'il n'a jamais servi.
function L.ChoisirCristal(choix)
    L.Synchroniser()
    local moi = Moi()
    if not moi then return false, "aucun personnage." end
    if choix == nil or choix == false then
        if not L.CristalPose(moi) then return true end
        if L.Allumee() then L.Eteindre() end
        local ok, raison = Remiser(moi)
        if not ok then return false, raison end
        Eteinte(EtatPourEcriture())
        if L.onChange then pcall(L.onChange) end
        return true
    end
    local option = Option(choix)
    if not option then return false, "ce cristal n'est dans aucun de tes sacs." end
    local avait = L.CristalPose(moi) ~= nil
    local ok, raison = Remiser(moi)
    if not ok then return false, raison end
    -- Retrouve apres le rangement : remiser a pu deplacer des piles.
    option = Option(option.id) or option
    local x, pourquoi = Sortir(moi, option)
    if not x then return false, pourquoi end
    x.charge = tonumber(x.charge) or Plein(option.cristal)
    moi.cristalPose = x
    if avait then L.DireEmote("swap") end
    if L.onChange then pcall(L.onChange) end
    return true
end

function L.DefinirVariateur(valeur)
    valeur = tonumber(valeur)
    local connu = false
    for _, v in ipairs(Eq().variateurs) do connu = connu or v == valeur end
    if not connu then return false, "variateur inconnu : " .. tostring(valeur) end
    -- L'ecoulement d'avant se compte a l'ancien rythme.
    L.Synchroniser()
    EtatPourEcriture().variateur = valeur ~= Eq().variateurDefaut and valeur or nil
    return true
end

-- Le « Recharger » de Survive, REMPLACE par « Changer de cristal » (le MJ, 23 octobre 2026) : recharger
-- remplissait le cristal pose sur place, et ce qu'il lui restait de charge
-- disparaissait — le cristal etait comme jete. Changer de cristal en POSE UN
-- NEUF du meme modele, pris dans les sacs, et EJECTE l'ancien comme tout
-- cristal retire (Remiser) : entame, il va dans « Cristaux en cours
-- d'usage » et revient dans la liste avec son pourcentage ; vide, il
-- disparait.
function L.ChangerCristal()
    L.Synchroniser()
    -- Le cristal pose, ou le dernier modele epuise.
    local lanterne = L.LanterneChoisie()
    local cristal = L.CristalChoisi() or LCM.Cristaux.Get(Etat().dernierCristal)
    if not (lanterne and cristal) then
        return false, "choisis une lanterne et un cristal avant d'en changer."
    end
    local option = Option("plein:" .. cristal.id)
    if not option then
        return false, string.format("aucun %s plein dans tes sacs : choisis-en un autre dans la liste.", cristal.label)
    end
    local moi = Moi()
    local e = EtatPourEcriture()
    -- Comme Survive a la recharge : on change de cristal lanterne eteinte.
    if L.Allumee() and not e.pauseMJ then L.Eteindre() end
    local ok, raison = Remiser(moi)
    if not ok then return false, raison end
    option = Option(option.id) or option
    local x, pourquoi = Sortir(moi, option)
    if not x then return false, pourquoi end
    x.charge = tonumber(x.charge) or Plein(cristal)
    moi.cristalPose = x
    L.DireEmote("recharge")
    if L.onChange then pcall(L.onChange) end
    return true
end

-- Le bouton « Débug » de Survive : tout remettre a zero, sans toucher aux
-- emotes ni au canal, qui sont des reglages du joueur.
function L.Reinitialiser()
    local e = EtatPourEcriture()
    for _, cle in ipairs({ "lanterne", "cristal", "mode", "pauseMJ", "reprise", "actifEnPause", "charge",
                           "charges", "variateur", "auraActive" }) do e[cle] = nil end
    derniere = Maintenant()
end

-- ----- Le MJ ----------------------------------------------------------------

local function PhraseEntendue(evenement, message, cote)
    for _, element in ipairs(Choisies()) do
        local r = Regles(element)
        for canal in pairs(r.canaux) do
            if EVENEMENTS_CANAL[canal][evenement] then
                local cle = Normaliser(message)
                for _, p in ipairs(r[cote]) do
                    if p.cle == cle then return p end
                end
            end
        end
    end
end

-- Une regle d'aura « pause : X : phrase » joue meme si la phrase n'arrete pas
-- la lanterne : c'est ainsi que Survive laisse le MJ declencher une aura par
-- la voix sans toucher au temps.
local function AurasDePhrase(evenement, condition, message)
    local entendu = false
    for _, element in ipairs(Choisies()) do
        for canal in pairs(Regles(element).canaux) do
            entendu = entendu or EVENEMENTS_CANAL[canal][evenement] == true
        end
    end
    if not entendu then return 0, 0 end
    return Auras("retirer", condition, message), Auras("poser", condition, message)
end

local function Resoudre(retires, poses)
    if poses > 0 then PoserAuraActive(true) elseif retires > 0 then PoserAuraActive(false) end
end

function L.Pause(message, eteindre)
    L.Synchroniser()
    local e = EtatPourEcriture()
    local deja = e.pauseMJ
    e.pauseMJ = true
    Resoudre(Auras("retirer", "pause", message), Auras("poser", "pause", message))
    if eteindre then
        Auras("retirer", "eteindre")
        PoserAuraActive(false)
    end
    -- Comme Survive : pendant la pause, « allumee » suit l'aura. Une regle de
    -- pause qui la retire eteint donc la lanterne aux yeux du joueur.
    e.actifEnPause = e.auraActive == true
    e.reprise = e.actifEnPause and "on" or "off"
    if not deja then Notifier("l'écoulement du temps de ta lanterne a été arrêté par le MJ.") end
end

function L.Reprendre(message)
    L.Synchroniser()
    local e = EtatPourEcriture()
    if not e.pauseMJ then
        Resoudre(Auras("retirer", "reprise", message), Auras("poser", "reprise", message))
        return
    end
    e.mode = e.reprise == "on" and "on" or "off"
    e.pauseMJ, e.actifEnPause, e.reprise = nil, nil, nil
    derniere = Maintenant()
    Resoudre(Auras("retirer", "reprise", message), Auras("poser", "reprise", message))
    if e.mode == "on" and L.Charge() <= 0 then e.mode = "off" end
    Notifier("l'écoulement du temps de ta lanterne a été remis en marche par le MJ.")
end

function L.Entendre(evenement, message)
    local pause = PhraseEntendue(evenement, message, "pause")
    local reprise = PhraseEntendue(evenement, message, "reprise")
    if not pause then Resoudre(AurasDePhrase(evenement, "pause", message)) end
    if not reprise then Resoudre(AurasDePhrase(evenement, "reprise", message)) end
    if pause then L.Pause(message, pause.eteindre) end
    if reprise then L.Reprendre(message) end
    if (pause or reprise) and L.onChange then pcall(L.onChange) end
end

for evenement in pairs({ CHAT_MSG_RAID_WARNING = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
                         CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_INSTANCE_CHAT = true,
                         CHAT_MSG_INSTANCE_CHAT_LEADER = true }) do
    local nom = evenement
    LCM.On(nom, function(message) L.Entendre(nom, message) end)
end

-- ----- Le battement ---------------------------------------------------------
-- Une seconde suffit : on ne guette que la decharge. La charge, elle, se
-- calcule juste a chaque lecture.

LCM.WhenReady(function()
    derniere = Maintenant()
    -- `cristal`, `charge` et `charges` de LCM_CharDB (la charge par modele de
    -- la 0.2.6) ne sont plus lus : la charge vit sur le cristal. Ils restent
    -- ecrits, sans effet ; on n'efface pas sur l'heuristique.
    local battement = CreateFrame("Frame")
    local cumul = 0
    battement:SetScript("OnUpdate", function(_, dt)
        cumul = cumul + (dt or 0)
        if cumul < 1 then return end
        cumul = 0
        if Etat().mode == "on" then
            L.Synchroniser()
            if L.onTick then pcall(L.onTick) end
        end
    end)
end)

L.Normaliser = Normaliser
L.LireAuras = LireAuras
L.LirePhrases = LirePhrases
L.LireCanaux = LireCanaux
L.CANAUX = CANAUX
L.Regles = Regles
