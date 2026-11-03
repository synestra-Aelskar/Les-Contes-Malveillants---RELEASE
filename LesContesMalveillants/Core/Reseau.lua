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
-- Le numero des messages part d'un point au hasard a chaque chargement :
-- remis a zero par un /reload, il reprenait les numeros que les autres
-- avaient peut-etre encore a moitie recus de nous (voir Recevoir).
local compteur = math.random(0, 998)

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

local expedies = 0

-- Ce que le reseau a vecu depuis le chargement, pour le diagnostic (le MJ,
-- 3 novembre 2026 : « est-ce que l'addon peut provoquer des desync ? »).
-- `refuses` : paquets que le JEU a refuses (debit depasse) puis repris ;
-- `abandonnes` : messages repris trop de fois, laisses tomber ; `erreurs` :
-- refuses pour une autre raison (pas de groupe, canal invalide), qu'on ne
-- reprend pas ; `regroupes` : messages partis a plusieurs dans un paquet ;
-- `remplaces` : versions perimees retirees de la file avant de partir ;
-- `perimes` / `ecrases` : messages recus a moitie, jetes (voir Recevoir).
local stats = { refuses = 0, abandonnes = 0, erreurs = 0, regroupes = 0, remplaces = 0,
                perimes = 0, ecrases = 0 }
function Reseau.Stats()
    local copie = { partis = expedies }
    for cle, valeur in pairs(stats) do copie[cle] = valeur end
    return copie
end

-- ===== Le journal ==========================================================
-- Tout ce qui passe, envoye ou recu, une ligne par MESSAGE (le MJ, 3 novembre
-- 2026 : « un lecteur de reseau qui catch toutes les communications », lu
-- dans le terminal du Panel MJ, onglet Reseau). Une ligne d'envoi vit : elle
-- part « en file », devient « freine » si le jeu refuse, puis « parti » ou
-- « abandonne ». En MEMOIRE seulement, les JOURNAL_MAX dernieres : c'est un
-- outil de seance, rien n'entre en sauvegarde.
Reseau.JOURNAL_MAX = 400
local journal, suiveursJournal = {}, {}
local horodater = date or (os and os.date)

local function Prevenir(entree)
    for _, fn in ipairs(suiveursJournal) do pcall(fn, entree) end
end

local function Noter(entree)
    entree.t = (GetTime and GetTime()) or 0
    entree.heure = horodater and horodater("%H:%M:%S") or string.format("%.1f", entree.t)
    journal[#journal + 1] = entree
    if #journal > Reseau.JOURNAL_MAX then table.remove(journal, 1) end
    Prevenir(entree)
    return entree
end

-- `probleme` : une ligne a voir (refus, abandon, message jete).
local function Statut(entree, statut, probleme)
    if not entree then return end
    entree.statut = statut
    if probleme then entree.probleme = true end
    Prevenir(entree)
end

function Reseau.Journal() return journal end
function Reseau.ViderJournal()
    for i = #journal, 1, -1 do journal[i] = nil end
    Prevenir(nil)
end
-- `fn(entree)` a chaque ligne nouvelle ou changee (nil : journal vide).
function Reseau.SuivreJournal(fn)
    if type(fn) == "function" then suiveursJournal[#suiveursJournal + 1] = fn end
end

-- Les autres prefixes de l'addon (les Crossings) : de quoi les nommer dans
-- le journal. `resumer(paquet, sens)` rend le libelle d'un paquet, ou nil
-- pour ne pas le noter (un etat en cent morceaux se note une fois).
local suivis = {}
function Reseau.SuivrePrefixe(prefixe, resumer)
    suivis[tostring(prefixe)] = resumer
end
local function Resumer(prefixe, paquet, sens)
    local resumer = suivis[tostring(prefixe)]
    if not resumer then return tostring(prefixe) end
    local ok, libelle = pcall(resumer, tostring(paquet or ""), sens)
    if not ok then return tostring(prefixe) end
    return libelle
end

local NOMS_PRIORITE = { "urgent", "normal", "fond" }

-- Ce que veut dire la reponse de SendAddonMessage. Un client recent rend un
-- code (Enum.SendAddonMessageResult) ; un plus ancien, un booleen ; un tres
-- ancien, rien du tout — on le croit alors sur parole, comme avant.
-- « refuse » se reprend plus tard ; « erreur » ne passera pas mieux en
-- reessayant.
local function Resultat(r)
    if r == nil or r == true then return "ok" end
    local codes = Enum and Enum.SendAddonMessageResult
    if codes then
        if r == codes.Success then return "ok" end
        if r == codes.AddonMessageThrottle or r == codes.ChannelThrottle then return "refuse" end
        if type(r) == "number" then return "erreur" end
    end
    if r == 0 then return "ok" end
    -- `false` : le client ne dit pas pourquoi. Le plus souvent, le debit ;
    -- la reprise est bornee, une vraie erreur finit abandonnee.
    return "refuse"
end

-- Rend "ok", "refuse" ou "erreur". Avant le 3 novembre 2026, la reponse du
-- jeu n'etait pas lue : un paquet refuse pour debit depasse etait compte
-- comme parti, et le message entier n'arrivait jamais — sans que personne
-- le sache. C'etait la premiere source de « desync » entre joueurs.
local function Expedier(message, canal, cible, prefixe)
    local envoyer = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not envoyer then return "erreur" end
    if #message > Reseau.LIMITE then
        -- Ne doit jamais arriver : si ca arrive, on le dit plutot que de
        -- laisser le message disparaitre en silence.
        LCM.Erreur(string.format("message de %d octets, au-dessus de la limite de %d.",
            #message, Reseau.LIMITE))
        return "erreur"
    end
    local resultat = Resultat(envoyer(prefixe or Reseau.PREFIXE, message, canal, cible))
    if resultat == "ok" then
        expedies = expedies + 1
    elseif resultat == "refuse" then
        stats.refuses = stats.refuses + 1
    else
        stats.erreurs = stats.erreurs + 1
    end
    return resultat
end

-- Combien de paquets sont VRAIMENT partis depuis le chargement, rafale et
-- file confondues. Un compteur qui ne fait que monter : celui qui suit un
-- envoi (la synchro forcee, Core/Synchro.lua) retient sa valeur au depart et
-- compte la difference.
function Reseau.Expedies() return expedies end

-- ===== La file : priorites et paquets ======================================
-- Le jeu ne laisse passer qu'une rafale de messages d'addon, puis un filet ;
-- au-dela, il REFUSE (et on le sait, maintenant). Trois regles, pour ne rien
-- perdre quand il freine (le MJ, 3 novembre 2026 : « un ordre de priorite
-- qui va chercher a stack les choses pour envoyer de jolis paquets ») :
--
--   * des PRIORITES : `urgent`, puis `normal` (le jeu en seance, par defaut),
--     puis `fond` (les envois etales : base publique, fiches, synchro). Le
--     fond ne passe jamais devant le jeu, et le jeu n'attend pas derriere lui ;
--   * des PAQUETS : quand une file attend, les petits messages qui vont au
--     meme endroit partent ENSEMBLE, dans un seul paquet plein. Dix messages
--     de vingt octets ne coutent plus dix envois au debit du jeu, mais un ;
--   * des REMPLACEMENTS : un message qui porte une `cle` remplace celui de
--     meme cle qui n'est pas encore parti (une fiche poussee deux fois de
--     suite : seule la derniere compte).
--
-- Tant que rien n'attend, un message part TOUT DE SUITE, comme avant : la
-- file ne coute rien quand le jeu suit. On bat la mesure avec OnUpdate
-- plutot que C_Timer : il existe toujours, et le banc sait le faire avancer.
Reseau.RAFALE = 8
Reseau.CADENCE = 0.25
-- Un paquet refuse : on attend REPRISE secondes avant de retenter (le debit
-- se recharge avec le temps, pas en insistant), et on abandonne le message
-- apres ESSAIS_MAX refus.
Reseau.REPRISE = 1
Reseau.ESSAIS_MAX = 20
Reseau.PRIORITES = { urgent = 1, normal = 2, fond = 3 }
-- Un paquet de plusieurs messages : « ~| » puis les messages, separes par
-- un saut de ligne — que l'encodage echappe toujours, il ne peut donc pas
-- apparaitre dans un message.
local PAQUET, SEPARATEUR = "~", "\n"

local files = { {}, {}, {} }
local horloge

local function Tete()
    for priorite = 1, #files do
        if files[priorite][1] then return files[priorite], priorite end
    end
end

local function NouvelId()
    compteur = (compteur % 999) + 1
    return tostring(compteur)
end

local function Entete(id, rang, total)
    return string.format("%s:%d:%d:", id, rang, total)
end

-- Un message pret a partir : ses morceaux, chacun avec son en-tete. `rang` :
-- le prochain morceau a envoyer.
local function Preparer(charge, canal, cible, priorite, cle, sujet)
    local id = NouvelId()
    -- La place qui reste pour le contenu, une fois l'en-tete pose. On calcule
    -- l'en-tete le plus long possible, pas le premier.
    local morceaux = Decouper(charge, Reseau.UTILE)
    local entete = #id + #tostring(#morceaux) * 2 + 3
    if Reseau.UTILE + entete > Reseau.LIMITE then
        morceaux = Decouper(charge, Reseau.LIMITE - entete)
    end
    local paquets = {}
    for rang, morceau in ipairs(morceaux) do paquets[rang] = Entete(id, rang, #morceaux) .. morceau end
    return { charge = charge, canal = canal, cible = cible, priorite = priorite, cle = cle,
             paquets = paquets, rang = 1, essais = 0, sujet = sujet, octets = #charge }
end

local function Retirer(m)
    local liste = files[m.priorite]
    for i, autre in ipairs(liste) do
        if autre == m then table.remove(liste, i) return end
    end
end

-- Un message qui tient en un morceau et n'est pas commence peut voyager avec
-- d'autres.
local function Petit(m) return m.charge ~= nil and #m.paquets == 1 and m.rang == 1 end

-- Envoyer UN paquet, le meilleur possible : le message en tete de la file la
-- plus prioritaire, et, s'il est petit, tous les petits qui vont au meme
-- endroit et tiennent avec lui — pris dans l'ordre des priorites.
local function Servir()
    local liste = Tete()
    if not liste then return nil end
    local m = liste[1]
    local message, lot = nil, nil
    if Petit(m) then
        lot = { m }
        local taille = #PAQUET + 1 + #m.charge
        for priorite = 1, #files do
            for _, autre in ipairs(files[priorite]) do
                if autre ~= m and Petit(autre) and autre.canal == m.canal and autre.cible == m.cible
                    and taille + #SEPARATEUR + #autre.charge <= Reseau.UTILE then
                    lot[#lot + 1] = autre
                    taille = taille + #SEPARATEUR + #autre.charge
                end
            end
        end
        if #lot > 1 then
            local charges = {}
            for i, x in ipairs(lot) do charges[i] = x.charge end
            message = Entete(NouvelId(), 1, 1) .. PAQUET .. "|" .. table.concat(charges, SEPARATEUR)
        else
            message = m.paquets[1]
        end
    else
        message = m.paquets[m.rang]
    end
    local resultat = Expedier(message, m.canal, m.cible, m.prefixe)
    if resultat == "ok" then
        if lot then
            for _, x in ipairs(lot) do
                Retirer(x)
                Statut(x.journal, #lot > 1 and string.format("parti en paquet x%d", #lot) or "parti")
            end
            if #lot > 1 then stats.regroupes = stats.regroupes + #lot end
        else
            m.rang = m.rang + 1
            if m.rang > #m.paquets then
                Retirer(m)
                Statut(m.journal, "parti")
            else
                Statut(m.journal, string.format("envoi %d/%d", m.rang - 1, #m.paquets))
            end
        end
    elseif resultat == "refuse" then
        m.essais = m.essais + 1
        Statut(m.journal, string.format("freiné (%d refus)", m.essais), true)
        if m.essais >= Reseau.ESSAIS_MAX then
            Retirer(m)
            Statut(m.journal, "ABANDONNÉ", true)
            stats.abandonnes = stats.abandonnes + 1
            LCM.Trace(string.format("réseau : message abandonné après %d refus du jeu (%s).",
                m.essais, tostring(m.cible or m.canal)))
        end
    else
        -- Une erreur qui ne passera pas mieux en reessayant : le message
        -- part a la poubelle plutot que de bloquer la file pour toujours.
        Retirer(m)
        Statut(m.journal, "ERREUR du jeu", true)
    end
    return resultat
end

local function Horloge()
    if horloge or not CreateFrame then return end
    horloge = CreateFrame("Frame")
    horloge.cumul = 0
    horloge:SetScript("OnUpdate", function(self, dt)
        if not Tete() then self.cumul = 0 return end
        self.cumul = self.cumul + (dt or 0)
        while self.cumul >= Reseau.CADENCE and Tete() do
            self.cumul = self.cumul - Reseau.CADENCE
            if Servir() == "refuse" then
                -- Le debit est epuise : laisser le jeu le recharger.
                self.cumul = -Reseau.REPRISE
                break
            end
        end
    end)
end

-- Combien de paquets attendent encore de partir (au plus : les petits
-- messages, regroupes, en couteront moins).
function Reseau.FileEnvoi()
    local n = 0
    for _, liste in ipairs(files) do
        for _, m in ipairs(liste) do n = n + (#m.paquets - m.rang + 1) end
    end
    return n
end

-- Combien de messages attendent, par priorite : { urgent, normal, fond }.
function Reseau.Files()
    return { urgent = #files[1], normal = #files[2], fond = #files[3] }
end

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
-- `options` :
--   * `etale` : un gros envoi, qui laisse passer le reste (priorite `fond`) ;
--     sa rafale part tout de suite si rien n'attend devant lui ;
--   * `priorite` : "urgent", "normal" ou "fond" ;
--   * `cle` : ce message remplace celui de meme cle qui attend encore.
-- Rend true et le nombre de morceaux, ou false si le message ne peut pas
-- partir du tout (personne a joindre, erreur du jeu). Un message que le jeu
-- freine n'est PAS un echec : il attend son tour, et il partira.
local function Confier(m, etale)
    Horloge()
    m.journal = Noter({ sens = "envoi", sujet = m.sujet or "?", canal = m.canal, qui = m.cible,
        octets = m.octets, morceaux = #m.paquets, priorite = NOMS_PRIORITE[m.priorite],
        statut = "en file" })
    if m.cle then
        for _, liste in ipairs(files) do
            for i, autre in ipairs(liste) do
                if autre.cle == m.cle and (autre.rang == 1 or m.interrompre) and autre.canal == m.canal
                    and autre.cible == m.cible then
                    table.remove(liste, i)
                    Statut(autre.journal, "remplacé par plus récent")
                    stats.remplaces = stats.remplaces + 1
                    break
                end
            end
        end
    end
    -- Partir tout de suite, seulement si rien d'aussi important n'attend
    -- devant lui et que le jeu n'est pas en train de freiner : sinon il
    -- passerait devant des messages plus anciens, ou se ferait refuser.
    local devant = horloge and horloge.cumul < 0
    for priorite = 1, m.priorite do
        if files[priorite][1] then devant = true end
    end
    if not devant then
        local limite = etale and math.min(Reseau.RAFALE, #m.paquets) or #m.paquets
        while m.rang <= limite do
            local resultat = Expedier(m.paquets[m.rang], m.canal, m.cible, m.prefixe)
            if resultat == "erreur" then
                Statut(m.journal, "ERREUR du jeu", true)
                return false
            end
            if resultat == "refuse" then
                if horloge then horloge.cumul = -Reseau.REPRISE end
                m.essais = 1
                Statut(m.journal, "freiné (1 refus)", true)
                break
            end
            m.rang = m.rang + 1
        end
        if m.rang > #m.paquets then
            Statut(m.journal, "parti")
            return true, #m.paquets
        end
        -- Sans horloge (hors jeu), il n'y a pas de file pour reprendre.
        if not horloge then return false end
    end
    table.insert(files[m.priorite], m)
    return true, #m.paquets
end

function Reseau.Envoyer(sujet, donnees, canal, cible, options)
    if canal == Reseau.TOUS then
        canal, cible = Reseau.CanalTous()
        if not canal then return false end
    end
    canal = canal or "RAID"
    local etale = options and options.etale
    local priorite = Reseau.PRIORITES[options and options.priorite or ""] or (etale and 3 or 2)
    local charge = tostring(sujet) .. "|" .. Reseau.Encoder(donnees)
    return Confier(Preparer(charge, canal, cible, priorite, options and options.cle, tostring(sujet)), etale)
end

-- La MEME file pour un autre prefixe, deja decoupe par son appelant : les
-- Crossings (Core/Crossings.lua) gardent leur format et leur prefixe — les
-- addons qui les recoivent n'ont rien a changer — mais ne sont plus une
-- seconde piste qui consommait le debit du jeu dans le dos de celle-ci (le
-- MJ, 3 novembre 2026 : « faut pas avoir 20 pistes reseaux »). Ces paquets
-- ne se regroupent pas avec les autres : ils ne sont pas du meme format.
function Reseau.EnvoyerBrut(prefixe, paquets, canal, cible, options)
    if type(paquets) ~= "table" or not paquets[1] then return false end
    local priorite = Reseau.PRIORITES[options and options.priorite or ""] or 3
    -- `interrompre` : la nouvelle version remplace l'ancienne meme si elle a
    -- commence a partir (la reception de l'appelant doit savoir oublier un
    -- message incomplet — celle des Crossings le fait).
    local m = { prefixe = prefixe, canal = canal, cible = cible, priorite = priorite,
                cle = options and options.cle, interrompre = options and options.interrompre,
                paquets = paquets, rang = 1, essais = 0,
                sujet = Resumer(prefixe, paquets[1], "envoi") or tostring(prefixe) }
    m.octets = 0
    for _, paquet in ipairs(paquets) do m.octets = m.octets + #paquet end
    return Confier(m, true)
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

-- Un message recu a moitie et qui ne bouge plus depuis PEREMPTION secondes
-- ne se completera jamais (un morceau refuse chez l'expediteur, avant que la
-- file ne sache reprendre, ou un expediteur parti) : on le jette, au lieu
-- de le garder indefiniment — il risquait de se coller a un message neuf
-- portant le meme numero.
Reseau.PEREMPTION = 60
-- Le sujet d'un message recu en partie, si son premier morceau est la.
local function Sujet(assemblage)
    return (tostring(assemblage.morceaux[1] or ""):match("^(.-)|")) or "?"
end

local function Purger(maintenant)
    for cle, assemblage in pairs(recus) do
        if maintenant - (assemblage.quand or maintenant) > Reseau.PEREMPTION then
            recus[cle] = nil
            stats.perimes = stats.perimes + 1
            Noter({ sens = "reception", sujet = Sujet(assemblage), qui = cle:match("^(.-)#"),
                statut = string.format("JETÉ, incomplet %d/%d", assemblage.recus, assemblage.total),
                probleme = true })
        end
    end
end

local function Distribuer(expediteur, sujet, corps, provenance, enPaquet)
    local handler = handlers[sujet]
    Noter({ sens = "reception", sujet = sujet, qui = expediteur, canal = provenance,
        octets = #sujet + 1 + #tostring(corps or ""),
        statut = handler and (enPaquet and "reçu (paquet)" or "reçu") or "reçu, personne n'écoute" })
    if not handler then return false end
    origine = provenance
    local ok, erreur = pcall(handler, expediteur, Reseau.Decoder(corps))
    origine = nil
    if not ok then LCM.Erreur(string.format("message « %s » : %s", sujet, tostring(erreur))) end
    return true
end

-- Rendue publique pour le banc : jouer un message recu sans passer par WoW.
-- `provenance` est le type de distribution de WoW (« CHANNEL », « PARTY »...).
function Reseau.Recevoir(expediteur, message, provenance)
    local id, rang, total, morceau = tostring(message or ""):match("^(%d+):(%d+):(%d+):(.*)$")
    if not id then return false end
    rang, total = tonumber(rang), tonumber(total)

    local cle = tostring(expediteur) .. "#" .. id
    local maintenant = (GetTime and GetTime()) or 0
    Purger(maintenant)
    local assemblage = recus[cle]
    -- Un morceau deja recu a ce rang, c'est un AUTRE message qui reprend le
    -- meme numero (l'expediteur a fait /reload, ou a fait le tour des 999) :
    -- l'ancien, reste a moitie, ne doit pas se coller au nouveau.
    if assemblage and (assemblage.total ~= total or assemblage.morceaux[rang] ~= nil) then
        stats.ecrases = stats.ecrases + 1
        Noter({ sens = "reception", sujet = Sujet(assemblage), qui = expediteur, canal = provenance,
            statut = string.format("JETÉ, remplacé incomplet %d/%d", assemblage.recus, assemblage.total),
            probleme = true })
        assemblage = nil
    end
    if not assemblage then
        assemblage = { total = total, morceaux = {}, recus = 0 }
        recus[cle] = assemblage
    end
    assemblage.quand = maintenant
    assemblage.morceaux[rang] = morceau
    assemblage.recus = assemblage.recus + 1
    if assemblage.recus < total then return true end

    recus[cle] = nil
    local charge = table.concat(assemblage.morceaux)
    local sujet, corps = charge:match("^(.-)|(.*)$")
    if not sujet then return false end
    if sujet == PAQUET then
        -- Plusieurs messages voyageant ensemble (la file regroupe les petits
        -- quand le jeu freine) : chacun est servi comme s'il etait venu seul.
        local servis = false
        for message in corps:gmatch("[^" .. SEPARATEUR .. "]+") do
            local s, c = message:match("^(.-)|(.*)$")
            if s and Distribuer(expediteur, s, c, provenance, true) then servis = true end
        end
        return servis
    end
    return Distribuer(expediteur, sujet, corps, provenance)
end

-- Combien de messages attendent encore un morceau : de quoi diagnostiquer un
-- envoi tombe en route.
function Reseau.EnAttente()
    local nombre = 0
    for _ in pairs(recus) do nombre = nombre + 1 end
    return nombre
end

LCM.On("CHAT_MSG_ADDON", function(prefixe, message, provenance, expediteur)
    if prefixe ~= Reseau.PREFIXE then
        -- Un autre prefixe de l'addon : il a sa propre reception, on ne fait
        -- que le noter au journal.
        if suivis[prefixe] and expediteur ~= LCM.PlayerId() then
            local sujet = Resumer(prefixe, message, "reception")
            if sujet then
                Noter({ sens = "reception", sujet = sujet, qui = expediteur, canal = provenance,
                    octets = #tostring(message or ""), statut = "reçu" })
            end
        end
        return
    end
    if expediteur == LCM.PlayerId() then return end
    Reseau.Recevoir(expediteur, message, provenance)
end)

LCM.WhenReady(function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(Reseau.PREFIXE)
    end
end)
