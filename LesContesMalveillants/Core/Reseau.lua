-- Le reseau : parler aux autres joueurs.
--
-- UN SEUL point de passage, et une seule raison : les messages d'addon de WoW
-- sont limites a 255 OCTETS. C'est ce qui cassait les invitations de combat
-- dans Necronicon — le message partait, personne ne le recevait, et rien ne le
-- disait. Ici, tout ce qui sort est decoupe et renumerote, tout ce qui entre
-- est recolle, et un morceau manquant se voit.
--
-- Rien d'autre ne doit appeler SendAddonMessage directement.

local _, LCM = ...

local Reseau = {}
LCM.Reseau = Reseau

Reseau.PREFIXE = "LCM1"
-- 255 est la limite dure. L'en-tete (<id>:<n>:<total>:) tient dans 16 octets ;
-- on garde une marge, un octet perdu coute moins cher qu'un message perdu.
Reseau.LIMITE = 255
Reseau.UTILE = 230

local handlers = {}
local recus = {}
local compteur = 0

-- ===== Mise en texte =======================================================
-- Un sort porte du texte libre : il faut que « ; » et « = » puissent s'y
-- trouver sans casser le decodage.

local function Echapper(v)
    return (tostring(v):gsub("[%%;=\n\r]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function Desechapper(v)
    return (tostring(v):gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

-- Une table plate de valeurs simples. Les tables imbriquees se disent par un
-- point : jet.min devient « jet.min ».
function Reseau.Encoder(donnees)
    local morceaux = {}
    local function poser(prefixe, table_)
        -- On garde la cle TELLE QUELLE et on trie sur son ecriture. Convertir
        -- la cle en texte pour trier, puis s'en servir pour lire la table,
        -- rendait nil sur toute cle numerique : les TABLEAUX disparaissaient
        -- en silence, et avec eux les raretes d'un jeu d'equilibrage, qui ne
        -- traversaient donc jamais le reseau (5 octobre 2026).
        local cles = {}
        for cle in pairs(table_) do cles[#cles + 1] = cle end
        -- Trie : deux encodages du meme contenu doivent se ressembler, sinon
        -- rien n'est comparable au banc. Les nombres d'abord, dans l'ordre,
        -- pour qu'un tableau se relise dans le sien.
        table.sort(cles, function(a, b)
            local na, nb = type(a) == "number", type(b) == "number"
            if na ~= nb then return na end
            if na then return a < b end
            return tostring(a) < tostring(b)
        end)
        for _, cle in ipairs(cles) do
            local valeur = table_[cle]
            if type(valeur) == "table" then
                poser(prefixe .. tostring(cle) .. ".", valeur)
            elseif valeur ~= nil then
                morceaux[#morceaux + 1] = Echapper(prefixe .. tostring(cle)) .. "=" .. Echapper(valeur)
            end
        end
    end
    poser("", donnees or {})
    return table.concat(morceaux, ";")
end

-- Rebatit la table, a TOUS les niveaux. Le decodeur ne coupait qu'au premier
-- point : « e.raretes.1.label » donnait une cle plate « raretes.1.label » dans
-- `e`, et tout ce qui etait imbrique arrivait casse — les bonus d'un trait, les
-- raretes et les champs d'un jeu d'equilibrage. On ne s'en apercevait pas,
-- parce que les paquets ecrits a la main sont plats (5 octobre 2026).
--
-- Une cle qui n'est QUE des chiffres redevient un indice de tableau : sans ca,
-- `raretes` serait une table a cles « 1 », « 2 », qu'`ipairs` ne parcourt pas.
--
-- « true » et « false » redeviennent des BOOLEENS. L'encodeur ecrit tout en
-- texte ; le decodeur rendait donc la chaine « false », qui est VRAIE en Lua.
-- Un coffre verrouille n'offrait aucun bouton de tentative au joueur distant
-- (`e.f == true` etait faux), un coffre ouvert ne montrait pas son contenu, et
-- surtout un refus du proprietaire (`ok = false`) se lisait comme une reussite
-- — on rangeait l'objet qu'on venait de se voir refuser (20 octobre 2026).
-- Le proprietaire, lui, ne voyait rien : son etat ne passe pas par le reseau.
--
-- Un champ de TEXTE qui vaudrait exactement « true » devient donc un booleen.
-- Aucun n'existe — un libelle, un nom, une description ne valent pas cela — et
-- le prix de l'inverse se compte en refus avales en silence.
--
-- L'encodeur n'a PAS change : un ancien emetteur et un nouveau produisent le
-- meme texte, donc les deux machines peuvent ne pas etre a jour en meme temps.
-- Un lecteur d'une version precedente lit encore « true » : tous ecrivaient
-- deja `x == true or x == "true"`.
function Reseau.Decoder(texte)
    local donnees = {}
    for morceau in tostring(texte or ""):gmatch("[^;]+") do
        local cle, valeur = morceau:match("^(.-)=(.*)$")
        if cle then
            cle, valeur = Desechapper(cle), Desechapper(valeur)
            local table_ = donnees
            local precedent
            for partie in cle:gmatch("[^%.]+") do
                local indice = partie:match("^%d+$")
                local k = indice and tonumber(indice) or partie
                if precedent ~= nil then
                    table_[precedent] = type(table_[precedent]) == "table" and table_[precedent] or {}
                    table_ = table_[precedent]
                end
                precedent = k
            end
            if valeur == "true" then valeur = true
            elseif valeur == "false" then valeur = false end
            if precedent ~= nil then table_[precedent] = valeur end
        end
    end
    return donnees
end

-- ===== Envoi ===============================================================

local function Decouper(texte, taille)
    local morceaux = {}
    local index = 1
    while index <= #texte do
        morceaux[#morceaux + 1] = texte:sub(index, index + taille - 1)
        index = index + taille
    end
    if #morceaux == 0 then morceaux[1] = "" end
    return morceaux
end
Reseau.Decouper = Decouper

local function Expedier(message, canal, cible)
    local envoyer = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not envoyer then return false end
    if #message > Reseau.LIMITE then
        -- Ne doit jamais arriver : si ca arrive, on le dit plutot que de
        -- laisser le message disparaitre en silence.
        LCM.Erreur(string.format("message de %d octets, au-dessus de la limite de %d.",
            #message, Reseau.LIMITE))
        return false
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(Reseau.PREFIXE, message, canal, cible)
    else
        envoyer(Reseau.PREFIXE, message, canal, cible)
    end
    return true
end

-- ===== Envoi etale ===========================================================
-- Le serveur ne laisse passer qu'une rafale de messages d'addon, puis un
-- filet : au-dela, il les jette sans rien dire. Un gros envoi (un PNJ entier
-- partage par « Link ») part donc en deux temps : une rafale, puis le reste
-- a cadence fixe. On bat la mesure avec OnUpdate plutot que C_Timer : il
-- existe toujours, et le banc sait le faire avancer (__avancer).
Reseau.RAFALE = 8
Reseau.CADENCE = 0.25
local file = {}
local horloge

local function Horloge()
    if horloge or not CreateFrame then return end
    horloge = CreateFrame("Frame")
    horloge.cumul = 0
    horloge:SetScript("OnUpdate", function(self, dt)
        if #file == 0 then return end
        self.cumul = self.cumul + (dt or 0)
        while self.cumul >= Reseau.CADENCE and #file > 0 do
            self.cumul = self.cumul - Reseau.CADENCE
            local m = table.remove(file, 1)
            Expedier(m.message, m.canal, m.cible)
        end
        if #file == 0 then self.cumul = 0 end
    end)
end

-- Combien de morceaux attendent encore de partir.
function Reseau.FileEnvoi() return #file end

-- ===== Le canal de tout le monde ===========================================
-- Un message d'addon ne part qu'au groupe, a la guilde, a un nom precis... ou
-- a un CANAL de discussion. L'addon en rejoint un, silencieux, pour sa
-- presence (Core/Presence.lua) : c'est par la qu'on joint tous ceux qui ont
-- l'addon, qu'ils soient du groupe ou non.
--
-- `TOUS` se passe comme un canal ordinaire a Envoyer, qui le resout au moment
-- de l'envoi : le canal de l'addon s'il est rejoint, le groupe sinon. Les
-- appelants n'ont donc pas a connaitre l'index du canal, et leurs gardes
-- « si j'ai un canal » gardent leur sens.
Reseau.TOUS = "TOUS"

-- Le canal et sa cible, ou nil si on est vraiment seul.
function Reseau.CanalTous()
    local id = LCM.Presence and LCM.Presence.Canal and LCM.Presence.Canal()
    if id then return "CHANNEL", id end
    local groupe = LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
    if groupe then return groupe, nil end
    return nil
end

-- `TOUS` quand il y a quelqu'un a joindre, nil sinon : de quoi ecrire
-- `local canal = Reseau.Diffusable() ; if canal then ... end`.
function Reseau.Diffusable()
    return (Reseau.CanalTous()) and Reseau.TOUS or nil
end

-- Reseau.Envoyer("sort", { ... }, "WHISPER", "Nytherah-Apertus")
-- `options.etale` : au-dela d'une rafale, le reste part a cadence fixe.
function Reseau.Envoyer(sujet, donnees, canal, cible, options)
    if canal == Reseau.TOUS then
        canal, cible = Reseau.CanalTous()
        if not canal then return false end
    end
    canal = canal or "RAID"
    local charge = tostring(sujet) .. "|" .. Reseau.Encoder(donnees)
    compteur = (compteur % 999) + 1
    local id = tostring(compteur)

    -- La place qui reste pour le contenu, une fois l'en-tete pose. On calcule
    -- l'en-tete le plus long possible, pas le premier.
    local morceaux = Decouper(charge, Reseau.UTILE)
    local entete = #id + #tostring(#morceaux) * 2 + 3
    if Reseau.UTILE + entete > Reseau.LIMITE then
        morceaux = Decouper(charge, Reseau.LIMITE - entete)
    end

    -- Un envoi etale passe derriere ce qui attend deja, meme sa rafale :
    -- sinon deux gros envois coup sur coup doubleraient la cadence.
    local etale = options and options.etale
    if etale then Horloge() end
    for rang, morceau in ipairs(morceaux) do
        local message = string.format("%s:%d:%d:%s", id, rang, #morceaux, morceau)
        if etale and (rang > Reseau.RAFALE or #file > 0) and horloge then
            file[#file + 1] = { message = message, canal = canal, cible = cible }
        elseif not Expedier(message, canal, cible) then
            return false
        end
    end
    return true, #morceaux
end

-- ===== Reception ===========================================================

-- L'origine du message en cours de distribution. Les crochets la lisent par
-- Reseau.Origine() ; elle ne vaut que le temps de l'appel.
local origine = nil

-- Ce nom est-il dans mon groupe ? C'est la seule verification d'origine qu'on
-- puisse faire d'un message : un client modifie dit ce qu'il veut, y compris
-- qu'il est maitre du jeu. Elle vaut ce qu'elle vaut — on ne reçoit que de
-- gens avec qui on joue — et le reste tient a ce qu'on AFFICHE qui a envoye
-- quoi, pour que la triche se voie.
--
-- Hors groupe et hors jeu (au banc), on accepte : sans API de groupe, refuser
-- reviendrait a tout bloquer.
function Reseau.DansLeGroupe(nom)
    if not (UnitName and GetNumGroupMembers) then return true end
    local nombre = GetNumGroupMembers() or 0
    if nombre == 0 then return false end
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    for index = 1, nombre do
        local n, royaume = UnitName(prefixe .. index)
        if n then
            local complet = (royaume and royaume ~= "" and (n .. "-" .. royaume)) or n
            if complet == nom or n == tostring(nom):match("^[^-]+") then return true end
        end
    end
    return false
end

-- D'ou vient le message qu'on est en train de traiter : « CHANNEL »,
-- « PARTY », « RAID », « WHISPER »... Nil hors reception.
function Reseau.Origine() return origine end

-- L'origine qu'on accepte pour ce qui se partage avec tout le monde (les
-- coffres, les points de recolte, les vendeurs, les sacs au sol).
--
-- Le CANAL de l'addon suffit : on n'y entre pas par hasard, et seul un addon
-- y parle. C'est la meme garantie que le groupe — c'est-a-dire aucune contre
-- un client modifie — et elle tient a la meme chose : on AFFICHE toujours qui
-- a envoye quoi, pour que la triche se voie.
--
-- Le groupe et la presence confirmee restent acceptes : un chuchotement de
-- reponse n'a pas d'autre marque que son expediteur.
function Reseau.Connu(nom)
    if origine == "CHANNEL" then return true end
    if Reseau.DansLeGroupe(nom) then return true end
    local P = LCM.Presence
    return (P and P.Confirmee and P.Confirmee(nom)) == true
end

function Reseau.Ecouter(sujet, handler)
    if type(handler) ~= "function" then return end
    handlers[tostring(sujet)] = handler
end

-- Rendue publique pour le banc : jouer un message recu sans passer par WoW.
-- `provenance` est le type de distribution de WoW (« CHANNEL », « PARTY »...).
function Reseau.Recevoir(expediteur, message, provenance)
    local id, rang, total, morceau = tostring(message or ""):match("^(%d+):(%d+):(%d+):(.*)$")
    if not id then return false end
    rang, total = tonumber(rang), tonumber(total)

    local cle = tostring(expediteur) .. "#" .. id
    local assemblage = recus[cle]
    if not assemblage or assemblage.total ~= total then
        assemblage = { total = total, morceaux = {}, recus = 0 }
        recus[cle] = assemblage
    end
    if assemblage.morceaux[rang] == nil then
        assemblage.morceaux[rang] = morceau
        assemblage.recus = assemblage.recus + 1
    end
    if assemblage.recus < total then return true end

    recus[cle] = nil
    local charge = table.concat(assemblage.morceaux)
    local sujet, corps = charge:match("^(.-)|(.*)$")
    if not sujet then return false end
    local handler = handlers[sujet]
    if not handler then return false end
    origine = provenance
    local ok, erreur = pcall(handler, expediteur, Reseau.Decoder(corps))
    origine = nil
    if not ok then LCM.Erreur(string.format("message « %s » : %s", sujet, tostring(erreur))) end
    return true
end

-- Combien de messages attendent encore un morceau : de quoi diagnostiquer un
-- envoi tombe en route.
function Reseau.EnAttente()
    local nombre = 0
    for _ in pairs(recus) do nombre = nombre + 1 end
    return nombre
end

LCM.On("CHAT_MSG_ADDON", function(prefixe, message, provenance, expediteur)
    if prefixe ~= Reseau.PREFIXE then return end
    if expediteur == LCM.PlayerId() then return end
    Reseau.Recevoir(expediteur, message, provenance)
end)

LCM.WhenReady(function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(Reseau.PREFIXE)
    end
end)
