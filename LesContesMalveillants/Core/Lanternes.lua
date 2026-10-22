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
--     a moitie use le rend a moitie, un cristal jamais pose arrive plein ;
--   * recharger remplit le cristal pose et eteint la lanterne (hors pause) ;
--   * le MJ arrete l'ecoulement par une phrase dite en alerte, raid ou groupe
--     (« pause »), et le relance par une autre (« reprise »). Pendant la pause
--     le joueur peut encore allumer et eteindre — c'est l'aura qui suit, pas
--     le temps ;
--   * les auras du serveur : une regle dit QUAND (allumer, eteindre, vide,
--     pause, reprise) et QUOI (un numero de sort -> `.aura` / `.unaura`, ou
--     une commande entiere) ;
--   * la verification d'inventaire porte sur un objet du JEU (son ID), pas
--     sur un sac de l'addon, et un cristal « consommable » se retire par
--     `.additem ID -1` a la recharge.
--
-- Ce qui change, et pourquoi :
--   * le catalogue (lanternes, cristaux) est du contenu du compendium, pas
--     une liste que le joueur edite dans la sauvegarde (CLAUDE.md, regle 1) ;
--   * les cases « Auras actives » et « Phrases de controle » de Survive ne
--     sont pas reprises : une regle ecrite EST une regle active, et une liste
--     vide n'agit pas. Deux cases pour dire la meme chose divergeaient ;
--   * l'activation rapide a cote du lanceur n'existe pas ici : la lanterne
--     s'ouvre par le menu radial (Objets > Outils) ;
--   * le temps ne s'ecoule pas deconnecte, comme dans Survive : l'horloge de
--     reference est `GetTime()`, qui repart a chaque session. Elle ne va donc
--     PAS en sauvegarde.

local _, LCM = ...

local function Texte(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Vrai(v) return v == true or v == 1 or v == "1" or v == "true" or v == "oui" end

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

-- Ce que la lanterne et le cristal partagent : la verification d'inventaire,
-- les auras et les phrases du MJ.
local function Commun(definition, element, Erreur)
    local id = element.id
    element.verifInventaire = Vrai(definition.verifInventaire) or nil
    element.itemId = nil
    if definition.itemId ~= nil and Texte(definition.itemId) ~= "" then
        local n = tonumber(definition.itemId)
        if not n or n ~= math.floor(n) or n < 1 then
            Erreur(string.format("%s : ID d'objet illisible (%s)", id, tostring(definition.itemId)))
        end
        element.itemId = n
    end
    -- Survive acceptait la case cochee sans ID et refusait ensuite d'allumer,
    -- a chaque clic. Le refus est ici, une fois, chez le MJ.
    if element.verifInventaire and not element.itemId then
        Erreur(id .. " : la vérification d'inventaire demande l'ID de l'objet du jeu")
    end
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
        element.consommable = Vrai(definition.consommable) or nil
        Commun(definition, element, Erreur)
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
local consommationEnCours = false

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

function L.LanterneChoisie() return LCM.Lanternes.Get(Etat().lanterne) end
function L.CristalChoisi() return LCM.Cristaux.Get(Etat().cristal) end

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
    return cristal and cristal.duree * SECONDES_PAR_MINUTE or 0
end

function L.Charge()
    return math.max(0, math.min(tonumber(Etat().charge) or 0, L.ChargeMax()))
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
local function Auras(cote, condition, message)
    local n = 0
    local normalise = Normaliser(message)
    for _, element in ipairs(Choisies()) do
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

-- ----- Inventaire du jeu ----------------------------------------------------

local function Compte(itemId)
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, itemId, true, false, true)
        if ok and type(n) == "number" then return n end
    end
    if GetItemCount then
        local ok, n = pcall(GetItemCount, itemId, true)
        if ok and type(n) == "number" then return n end
    end
    return 0
end
L.Compte = Compte

local function Present(element, quoi)
    if not (element and element.verifInventaire) then return true end
    if Compte(element.itemId) <= 0 then
        return false, string.format("%s ne fonctionne pas sans l'objet requis (ID %d) dans l'inventaire.",
            quoi, element.itemId)
    end
    return true
end

-- ----- L'ecoulement ---------------------------------------------------------

-- Compte le temps passe depuis le dernier appel. C'est la seule porte par ou
-- la charge baisse : tout ce qui lit ou change la lanterne passe d'abord ici.
function L.Synchroniser(maintenant)
    maintenant = maintenant or Maintenant()
    local e = Etat()
    if e ~= VIDE and e.mode == "on" and not e.pauseMJ and derniere then
        local ecoule = math.max(0, maintenant - derniere)
        local charge = tonumber(e.charge) or 0
        if ecoule > 0 and charge > 0 then
            charge = math.max(0, charge - ecoule * Facteur())
            e.charge = charge
            if charge <= 0 then
                e.charge, e.mode = 0, "off"
                Auras("retirer", "vide")
                PoserAuraActive(false)
                L.DireEmote("empty")
                Notifier("la lanterne est déchargée.", true)
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
    local ok, raison = Present(lanterne, "cette lanterne")
    if not ok then return false, raison end
    ok, raison = Present(cristal, "ce cristal")
    if not ok then return false, raison end
    if L.Charge() <= 0 then return false, "la lanterne est déchargée : recharge-la avant de l'allumer." end
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

function L.ChoisirLanterne(id)
    L.Synchroniser()
    if id ~= nil and not LCM.Lanternes.Get(id) then return false, "lanterne inconnue : " .. tostring(id) end
    local e = EtatPourEcriture()
    e.lanterne = id
    if not id then Eteinte(e) end
    return true
end

-- Le cristal qu'on retire garde sa charge ; celui qu'on pose reprend la
-- sienne, ou arrive plein s'il n'a jamais servi.
function L.ChoisirCristal(id)
    L.Synchroniser()
    local cristal = id ~= nil and LCM.Cristaux.Get(id)
    if id ~= nil and not cristal then return false, "cristal inconnu : " .. tostring(id) end
    local e = EtatPourEcriture()
    local ancien = e.cristal
    if ancien == id then return true end
    if ancien then
        e.charges = type(e.charges) == "table" and e.charges or {}
        e.charges[ancien] = tonumber(e.charge) or 0
    end
    e.cristal = id
    if not cristal then
        Eteinte(e)
        e.charge = nil
        return true
    end
    local garde = type(e.charges) == "table" and e.charges[id] or nil
    local plein = cristal.duree * SECONDES_PAR_MINUTE
    e.charge = garde ~= nil and math.max(0, math.min(garde, plein)) or plein
    if ancien then L.DireEmote("swap") end
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

-- Recharger remplit le cristal pose. Consommable : l'objet du jeu doit
-- disparaitre du sac AVANT que la charge revienne — sinon recharger ne
-- couterait rien si la commande echoue.
function L.Recharger()
    L.Synchroniser()
    local lanterne, cristal = L.LanterneChoisie(), L.CristalChoisi()
    if not (lanterne and cristal) then return false, "choisis une lanterne et un cristal avant de recharger." end
    if cristal.verifInventaire and Compte(cristal.itemId) <= 0 then
        return false, string.format("l'objet requis pour recharger (ID %d) est introuvable dans l'inventaire.",
            cristal.itemId)
    end
    local function Appliquer()
        local e = EtatPourEcriture()
        e.charge = cristal.duree * SECONDES_PAR_MINUTE
        if type(e.charges) == "table" then
            e.charges[cristal.id] = nil
            if next(e.charges) == nil then e.charges = nil end
        end
        if not e.pauseMJ then e.mode = "off" end
        L.DireEmote("recharge")
        if L.onChange then pcall(L.onChange) end
    end
    if not (cristal.verifInventaire and cristal.consommable) then
        Appliquer()
        return true
    end
    if consommationEnCours then return false, "une consommation est déjà en attente." end
    local avant = Compte(cristal.itemId)
    if not SendChatMessage or not pcall(SendChatMessage, ".additem " .. cristal.itemId .. " -1", "SAY") then
        return false, "impossible de lancer la consommation de l'objet."
    end
    consommationEnCours = { itemId = cristal.itemId, avant = avant, suite = Appliquer }
    if C_Timer and C_Timer.After then
        local attente = consommationEnCours
        C_Timer.After(Eq().attenteConsommation, function()
            if consommationEnCours ~= attente then return end
            consommationEnCours = false
            Notifier("le cristal n'a pas été consommé : la recharge est annulée.", true)
        end)
    end
    return true, "en attente"
end

LCM.On("BAG_UPDATE_DELAYED", function()
    local c = consommationEnCours
    if not c then return end
    if Compte(c.itemId) < c.avant then
        consommationEnCours = false
        c.suite()
    end
end)

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
    local e = Etat()
    -- Une entree disparue du compendium ne laisse pas une lanterne fantome.
    if e.lanterne and not LCM.Lanternes.Get(e.lanterne) then L.ChoisirLanterne(nil) end
    if e.cristal and not LCM.Cristaux.Get(e.cristal) then
        local w = EtatPourEcriture()
        w.cristal, w.charge = nil, nil
        Eteinte(w)
    end
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
L.Regles = Regles
