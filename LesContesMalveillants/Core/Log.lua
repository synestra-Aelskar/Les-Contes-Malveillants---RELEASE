-- Sorties chat. Un seul endroit : les messages doivent se ressembler, et on
-- doit pouvoir les couper tous d'un coup.

local _, LCM = ...

-- « [ Contes ] - Message » (3 octobre 2026) : « Contes aucun objet... » ne
-- se lisait pas comme une phrase.
local PREFIX = "|cffc8a45e[ Contes ]|r - "
local COLORS = {
    info = "|cffe8dcc0",
    ok = "|cff6fc96f",
    alerte = "|cffe8b451",
    erreur = "|cffe86b6b",
}

-- Les minuscules accentuees qu'un message peut avoir en tete (UTF-8).
local CAPITALES = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â",
                    ["ç"] = "Ç", ["î"] = "Î", ["ô"] = "Ô", ["û"] = "Û" }

-- Le message commence par une majuscule : c'est une phrase. Les messages du
-- code sont ecrits en minuscules pour se lire dans une raison (« Refusé :
-- plus de place »). Un code couleur en tete est saute.
local function Phrase(text)
    local couleur, reste = text:match("^(|c%x%x%x%x%x%x%x%x)(.*)$")
    if couleur then return couleur .. Phrase(reste) end
    -- Le premier caractere, entier : un accent tient sur deux octets.
    local octet = text:byte(1)
    if not octet then return text end
    local n = octet < 192 and 1 or (octet < 224 and 2 or (octet < 240 and 3 or 4))
    local premier, suite = text:sub(1, n), text:sub(n + 1)
    return (CAPITALES[premier] or premier:upper()) .. suite
end

-- ===== Le journal ecrit =====================================================
-- Une trace qui survit a la session (23 octobre 2026) : une erreur affichee
-- au chat disparaissait avec lui, et on ne pouvait plus dire apres coup ce
-- qui s'etait passe — ni chez le MJ, ni chez un joueur qui ne repondait pas.
--
-- Il a SA PROPRE variable de sauvegarde, `LCM_Journal`, et pas une place dans
-- LCM_DB : ce n'est ni un reglage ni du contenu, et on doit pouvoir l'ouvrir,
-- l'envoyer ou l'effacer sans toucher au reste. WoW l'ecrit dans
-- WTF\Account\<compte>\SavedVariables\LesContesMalveillants.lua a chaque
-- /reload et a la deconnexion.
--
-- Ce qui y va : les erreurs, les alertes, les erreurs Lua venues de l'addon,
-- les traces (`LCM.Debug`, ecrites meme quand /lcm debug est coupe, et
-- `LCM.Trace`, qui n'ecrit QUE la), et le journal de garde. Pas les messages
-- d'information ordinaires : ils noieraient ce qu'on cherche.
--
-- Une ligne par evenement, lisible telle quelle dans le fichier :
--   « 2026-10-23 01:30:12  erreur  Blud'Sh'Idah  message »
-- La meme ligne repetee d'affilee ne se recopie pas : elle compte (« x12 »).
-- Les plus anciennes partent au-dela de JOURNAL_MAX.

local JOURNAL_MAX = 3000
local journalLignes          -- la table sauvegardee, une fois la session chargee
local avantChargement = {}   -- ce qui arrive avant PLAYER_LOGIN
local derniere, repetitions  -- la derniere ligne ecrite, pour les repetitions

local function SansCouleur(texte)
    return (tostring(texte or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("\r?\n", " / "))
end

local function Horodatage()
    local d = date or (os and os.date)
    return d and d("%Y-%m-%d %H:%M:%S") or "?"
end

local function QuiJe()
    local nom = UnitName and UnitName("player")
    return nom and tostring(nom) or "?"
end

local function Ecrire(ligne)
    if not journalLignes then
        avantChargement[#avantChargement + 1] = ligne
        return
    end
    journalLignes[#journalLignes + 1] = ligne
    while #journalLignes > JOURNAL_MAX do table.remove(journalLignes, 1) end
end

local function Noter(niveau, texte)
    local message = SansCouleur(texte)
    local cle = niveau .. "\1" .. message
    if cle == derniere and journalLignes and #journalLignes > 0 then
        -- La meme chose encore : on compte au lieu de recopier.
        repetitions = repetitions + 1
        journalLignes[#journalLignes] = journalLignes[#journalLignes]:gsub("  x%d+$", "")
            .. "  x" .. repetitions
        return
    end
    derniere, repetitions = cle, 1
    Ecrire(string.format("%s  %s  %s  %s", Horodatage(), niveau, QuiJe(), message))
end
LCM.NoterJournal = Noter

-- Une trace qui ne va QUE dans le journal ecrit : ce qui aide a comprendre
-- une panne sans encombrer le chat (une fiche demandee, recue, refusee).
function LCM.Trace(text) Noter("trace", text) end

-- Le journal tel qu'il est, pour le banc et pour qui voudrait l'afficher.
function LCM.LignesJournal() return journalLignes or avantChargement end

local function ChargerJournal()
    if journalLignes then return end
    _G.LCM_Journal = type(_G.LCM_Journal) == "table" and _G.LCM_Journal or {}
    local j = _G.LCM_Journal
    j.lignes = type(j.lignes) == "table" and j.lignes or {}
    journalLignes = j.lignes
    for _, ligne in ipairs(avantChargement) do Ecrire(ligne) end
    avantChargement = {}
    Noter("session", "début de session (" .. tostring(LCM.version or "?") .. ")")
end

-- Les erreurs Lua de l'addon : elles ne passent ni par LCM.Erreur ni par
-- Proteger, et ce sont les pires. On s'intercale devant le gestionnaire en
-- place (celui de WoW, ou celui d'un BugGrabber) sans le remplacer : il voit
-- toujours tout, nous ne gardons que ce qui vient de nos fichiers.
local function SurveillerErreursLua()
    if not (geterrorhandler and seterrorhandler) then return end
    local precedent = geterrorhandler()
    seterrorhandler(function(message, ...)
        local texte = tostring(message or "")
        if texte:find("LesContesMalveillants", 1, true) then
            local pile = debugstack and debugstack(3, 6, 0) or ""
            Noter("lua", texte .. (pile ~= "" and ("  |  " .. pile) or ""))
        end
        if precedent then return precedent(message, ...) end
    end)
end

local function Emit(kind, text)
    local frame = DEFAULT_CHAT_FRAME
    local color = COLORS[kind] or COLORS.info
    local line = PREFIX .. color .. Phrase(tostring(text)) .. "|r"
    if frame then frame:AddMessage(line) else print(line) end
    if kind == "erreur" or kind == "alerte" then Noter(kind, Phrase(tostring(text))) end
end

function LCM.Info(text) Emit("info", text) end
function LCM.Ok(text) Emit("ok", text) end
function LCM.Alerte(text) Emit("alerte", text) end
function LCM.Erreur(text) Emit("erreur", text) end

-- Le suivi de garde est un journal local, pas une annonce de jeu ni un canal
-- reseau. Ne pas envoyer ces informations techniques a tout le groupe.
local NOM_JOURNAL = "LesContesMalveillants"
local attente, pret = {}, false
local function FenetreJournal()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame and GetChatWindowInfo and GetChatWindowInfo(i) == NOM_JOURNAL then return frame end
    end
    if not pret or (InCombatLockdown and InCombatLockdown()) or not FCF_OpenNewWindow then return nil end
    local selection = SELECTED_CHAT_FRAME
    local frame = FCF_OpenNewWindow(NOM_JOURNAL)
    if not frame then return nil end
    -- Un nouvel onglet herite parfois du General : seul celui que nous venons
    -- de creer est nettoye. Les preferences d'un onglet existant sont gardees.
    if ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(frame) end
    if ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
    if selection and FCF_SelectDockFrame then FCF_SelectDockFrame(selection) end
    return frame
end
local function ViderJournal()
    if #attente == 0 then return end
    local frame = FenetreJournal()
    if not frame then return end -- Aucun repli vers le General en cas de limite d'onglets.
    for _, ligne in ipairs(attente) do frame:AddMessage(ligne) end
    attente = {}
end
function LCM.Journal(text)
    Noter("garde", text)
    attente[#attente + 1] = PREFIX .. COLORS.info .. Phrase(tostring(text)) .. "|r"
    ViderJournal()
end
local journalEvenements = CreateFrame("Frame")
journalEvenements:RegisterEvent("PLAYER_LOGIN")
journalEvenements:RegisterEvent("PLAYER_REGEN_ENABLED")
journalEvenements:SetScript("OnEvent", function(_, evenement)
    if evenement == "PLAYER_LOGIN" then
        pret = true
        ChargerJournal()
        SurveillerErreursLua()
    end
    ViderJournal()
end)

-- Appeler un rappel (onChange, onReponse, un ecouteur...) sans qu'il casse
-- l'appelant, mais SANS LE TAIRE. Une vingtaine de rappels passaient par un
-- `pcall(fn)` nu : quand l'un tombait, la fenetre ne se mettait plus a jour,
-- une reponse de coffre se perdait, et rien ne le disait — « ça casse sans
-- raison » (20 octobre 2026). Chaque erreur distincte s'affiche une fois :
-- un rappel appele a chaque battement ne doit pas noyer le chat.
local dejaDites = {}
function LCM.Proteger(contexte, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, erreur = pcall(fn, ...)
    if not ok then
        local message = string.format("%s : %s", tostring(contexte), tostring(erreur))
        if not dejaDites[message] then
            dejaDites[message] = true
            LCM.Erreur(message)
        end
    end
    return ok, erreur
end

-- Trace de developpement : muette tant que `/lcm debug` ne l'a pas activee.
-- Ecrite au journal dans tous les cas : c'est quand on n'y pensait pas qu'on
-- en a besoin.
function LCM.Debug(text)
    Noter("trace", text)
    if not (LCM.db and LCM.db.settings and LCM.db.settings.debug) then return end
    Emit("info", "|cff888888[debug]|r " .. tostring(text))
end
