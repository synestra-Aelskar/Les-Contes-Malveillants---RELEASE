-- Le combat : invitation, initiative, tours et rounds.
--
-- Repris de l'initiative de Necronicon (Core.lua, StartInitiativeSession et
-- suivantes), reduit a ce que le Panel MJ des Contes utilisait vraiment :
-- ordonnancement classique (la liste triee, du plus haut au plus bas), jet de
-- la statistique Initiative, tours et rounds comptes, annonces au raid. Les
-- tours nommes, la frise temporelle, les assistants et les prereglages de
-- Necronicon ne sont pas repris : le profil des Contes ne s'en servait pas.
--
-- Qui decide : le MJ. Il invite, il lance, il tient l'etat et le diffuse. Un
-- joueur ne fait que repondre a l'invitation et passer SON tour ; tout ce
-- qu'il envoie, le MJ le verifie (c'est bien son tour ? c'est bien lui ?).
--
-- Un ecart voulu sur Necronicon : le jet d'initiative du joueur part AVEC sa
-- reponse a l'invitation. Necronicon faisait deux allers-retours (accepter,
-- puis envoyer son jet) et attendait 1,2 seconde le second ; ici, quand tout le
-- monde a repondu, le MJ a deja tous les jets et lance sans minuterie.
--
-- L'etat vit en MEMOIRE VIVE, chez tout le monde : un combat ne survit pas au
-- /reload du MJ. Un joueur qui recharge redemande l'etat au MJ (« combat! »).
--
-- Les messages, tous sous le prefixe du reseau (Core/Reseau.lua) :
--   combat?  MJ -> groupe   invitation                      { s }
--   combat+  joueur -> MJ   reponse, avec le jet            { s, ok, n, ic, v }
--   combat=  MJ -> groupe   l'etat complet                  { s, c, t, r, rm, nb, j1, n1, v1, ic1, p1... }
--   combat~  MJ -> groupe   un pas (tour suivant)           { s, c, t, r }
--   combat>  joueur -> MJ   « j'ai fini mon tour »          { s }
--   combat.  MJ -> groupe   fin du combat                   { s }
--   combat!  joueur -> groupe  « ou en est-on ? » (apres un /reload)
--   combatK  joueur -> MJ   changement de son etat KO       { s, k }
--   combatK= MJ -> groupe   changement KO d'un combattant   { s, j, k }
-- L'etat complet n'est envoye qu'au lancement et sur demande : WoW limite le
-- debit des messages d'addon, et un pas de tour tient en un seul message.

local _, LCM = ...

local Combat = {}
LCM.Combat = Combat

-- Un nom ou une icone trop longs font deborder l'etat complet sur un morceau
-- de plus pour chaque combattant. Memes bornes que Necronicon.
Combat.NOM_MAX = 30
Combat.ICONE_MAX = 90

local function Eq()
    return LCM.Equilibrage.combat
end

local function Moi()
    return LCM.PlayerId()
end

-- Les API de groupe peuvent rendre « Nom » pour un personnage du meme
-- royaume, alors que CHAT_MSG_ADDON identifie toujours l'expediteur sous la
-- forme « Nom-Royaume ». Sans cette canonicalisation, le MJ envoie bien
-- l'invitation mais rejette ensuite la reponse comme venant d'un non-invite.
local function IdJoueur(nom)
    nom = tostring(nom or "")
    if nom == "" or nom:find("-", 1, true) then return nom end
    local royaume
    if UnitFullName then _, royaume = UnitFullName("player") end
    royaume = tostring(royaume or "")
    return royaume ~= "" and (nom .. "-" .. royaume) or nom
end

local function IdUnite(unite)
    if not UnitName then return nil end
    local nom, royaume = UnitName(unite)
    if not nom then return nil end
    royaume = tostring(royaume or "")
    return royaume ~= "" and (nom .. "-" .. royaume) or IdJoueur(nom)
end

local function Nettoyer(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ===== Le groupe ===========================================================

-- Ou parler au groupe. Sans groupe, personne a inviter : le MJ combat seul
-- avec ses PNJ, et rien ne part sur le reseau.
-- Groupe ou raid, c'est le chef qui en decide, pas le nombre de membres : un
-- raid peut ne compter qu'une personne. On le demande donc au jeu.
function Combat.CanalGroupe()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

function Combat.Membres()
    local out = {}
    if not (GetNumGroupMembers and UnitName) then return out end
    local nombre = GetNumGroupMembers() or 0
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    local moi = Moi()
    for index = 1, nombre do
        local complet = IdUnite(prefixe .. index)
        if complet and complet ~= moi then out[#out + 1] = complet end
    end
    table.sort(out)
    return out
end

local function Envoyer(sujet, donnees, canal, cible)
    if not canal then return false end
    return LCM.Reseau.Envoyer(sujet, donnees, canal, cible)
end

-- ===== Les jets ============================================================

-- La fiche du joueur LUI-MEME, meme quand le MJ incarne un PNJ : Entities.Self()
-- suit l'incarnation, et le MJ qui s'inclut au combat y entre en personne.
local function MaFiche()
    local actif = LCM.Personnages and LCM.Personnages.Actif and LCM.Personnages.Actif()
    if actif then return actif end
    local id = Moi()
    if id == "" then return nil end
    return LCM.Entities.Get(id) or LCM.Entities.Self()
end

-- Le jet d'Initiative d'une fiche : des de la statistique + sa valeur + apports
-- et bonus, exactement comme le bouton de la fiche (Core/Roll.lua). C'est le
-- mode « stat » de Necronicon (RollLocalInitiativeStat).
function Combat.Jet(entity)
    if not entity then return 0, nil end
    local resultat = LCM.Roll.Field(entity, "initiative")
    if not resultat then return 0, nil end
    return resultat.total, resultat
end

local function Tronquer(texte, maximum)
    texte = tostring(texte or "")
    if #texte > maximum then texte = texte:sub(1, maximum) end
    return texte
end

-- Le joueur, tel que les autres le verront sur le bandeau : son nom RP et son
-- icone TRP3 s'il en a, sinon le nom du personnage (Core/Identite.lua).
local function MonIdentite()
    local identite = LCM.Identite and LCM.Identite.Joueur() or {}
    return Tronquer(identite.nom or Moi(), Combat.NOM_MAX),
           identite.icone and Tronquer(identite.icone, Combat.ICONE_MAX) or nil
end

-- ===== L'ordre =============================================================

-- Du plus haut au plus bas ; a egalite, par nom, pour que tous les clients
-- tombent sur le meme ordre (SortInitiativeEntries de Necronicon).
function Combat.Trier(entrees)
    table.sort(entrees, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return tostring(a.nom):lower() < tostring(b.nom):lower()
    end)
    return entrees
end

-- ===== L'etat ==============================================================
-- etat = { s, mj, c, t, r, rm, entrees = { { id, nom, v, icone, pnj } } }

Combat.etat = nil
-- Cote MJ : l'invitation en cours. Cote joueur : celle qu'on a recue.
Combat.invitation = nil
Combat.invitationRecue = nil
Combat.invitationTardive = nil

function Combat.Etat() return Combat.etat end

function Combat.EnCours() return Combat.etat ~= nil end

-- Le plafond est une depense PAR round, pas une baisse de la jauge : les PA
-- ignores restent dans la fiche et se debloquent tous au dernier round.
-- On retient le solde au premier regard sur un round pour compter ce qui y a
-- ete depense, y compris par un deplacement supplementaire. Les defenses
-- passent par PayerPADefense pour laisser cette tranche intacte.
local soldesPARound = setmetatable({}, { __mode = "k" })
function Combat.PADisponibles(entity)
    local jauge = entity and LCM.Entities.Gauge(entity, "pa")
    if not jauge then return nil end
    local etat = Combat.etat
    local courant = math.max(0, math.floor(tonumber(jauge.current) or 0))
    local maximum = math.max(0, math.floor(tonumber(jauge.max) or 0))
    if not etat then return courant, maximum, maximum end
    local rounds = math.max(1, math.floor(tonumber(etat.rm) or 1))
    local round = math.max(1, math.floor(tonumber(etat.r) or 1))
    local tranche = round >= rounds and maximum or math.floor(maximum / rounds + 0.5)
    local cle = tostring(etat.s) .. ":" .. tostring(etat.t) .. ":" .. tostring(round)
    local suivi = soldesPARound[entity]
    if not suivi or suivi.cle ~= cle then
        suivi = { cle = cle, dernier = courant, depenses = 0 }
        soldesPARound[entity] = suivi
    end
    -- Une restitution de PA ne rend pas une tranche deja depensee.
    if courant < suivi.dernier then suivi.depenses = suivi.depenses + suivi.dernier - courant end
    suivi.dernier = courant
    return math.max(0, math.min(courant, tranche - suivi.depenses)), tranche, maximum
end

function Combat.PayerPADefense(entity, montant)
    local jauge = entity and LCM.Entities.Gauge(entity, "pa")
    if not jauge or montant < 0 or montant > jauge.current then return false end
    Combat.PADisponibles(entity)
    local suivi = soldesPARound[entity]
    -- Avant SetGauge : ses observateurs relisent immediatement le budget.
    if suivi then suivi.dernier = jauge.current - montant end
    return LCM.Entities.SetGauge(entity, "pa", jauge.current - montant)
end

-- Vrai chez le MJ qui tient ce combat.
function Combat.EstMJ()
    return Combat.etat ~= nil and Combat.etat.mj == Moi()
end

function Combat.Courant()
    local etat = Combat.etat
    if not etat then return nil end
    return etat.entrees[etat.c]
end

function Combat.EstMonTour()
    local courant = Combat.Courant()
    return courant ~= nil and not courant.pnj and courant.id == Moi()
end

-- Le bouton « Passer le tour » : le joueur dont c'est le tour, et le MJ quand
-- c'est le tour d'un PNJ. Ecart a Necronicon, qui laissait le MJ passer les PNJ
-- depuis sa fenetre seulement : le bandeau est sous ses yeux, la fenetre non.
function Combat.PeutPasser()
    if Combat.EstMonTour() then return true end
    local courant = Combat.Courant()
    return Combat.EstMJ() and courant ~= nil and courant.pnj == true
end

Combat.suivis = {}
function Combat.Suivre(fn)
    if type(fn) == "function" then Combat.suivis[#Combat.suivis + 1] = fn end
end

local function Prevenir()
    if Combat.onChange then Combat.onChange(Combat.etat) end
    for _, fn in ipairs(Combat.suivis) do fn(Combat.etat) end
end

local function EstKO(entity)
    return entity ~= nil and LCM.Body and LCM.Body.Inconscient
        and LCM.Body.Inconscient(entity) or false
end

local function EntreeParId(id)
    local etat = Combat.etat
    if not etat then return nil end
    id = tostring(id or "")
    for _, entree in ipairs(etat.entrees or {}) do
        if entree.id == id then return entree end
    end
end

-- Met a jour le bandeau immediatement. Le MJ peut ensuite relayer ce nouvel
-- etat a tout le groupe ; les clients ne peuvent modifier que leur propre KO.
local function DefinirKO(id, ko, diffuser)
    local entree = EntreeParId(id)
    if not entree then return false end
    ko = ko == true
    if (entree.ko == true) == ko then return false end
    entree.ko = ko or nil
    Prevenir()
    if diffuser then
        Envoyer("combatK=", { s = Combat.etat.s, j = entree.id, k = ko and 1 or 0 }, Combat.CanalGroupe())
    end
    return true
end

-- ===== Les annonces ========================================================

local function Annoncer(texte)
    local canal = Eq().annonces
    -- Un canal de groupe sans groupe avale le message : on parle pour soi.
    local disponible = canal == "RAID" and Combat.CanalGroupe() == "RAID"
        or canal == "PARTY" and Combat.CanalGroupe() ~= nil
    if disponible and SendChatMessage then
        SendChatMessage("[Contes] " .. texte, canal)
    else
        LCM.Info(texte)
    end
end

-- Ce qui a change entre deux etats, dit dans l'ordre de Necronicon
-- (AnnounceInitiativeStateChanges) : le tour, le round, puis qui joue.
local function AnnoncerChangements(avant, apres)
    if not avant or avant.t ~= apres.t then
        Annoncer(string.format("Tour %d.", apres.t))
    end
    if not avant or avant.r ~= apres.r then
        Annoncer(string.format("Round %d/%d.", apres.r, apres.rm))
    end
    local courant = apres.entrees[apres.c]
    local precedent = avant and avant.entrees[avant.c]
    if courant and (not avant or avant.c ~= apres.c or (precedent and precedent.id) ~= courant.id) then
        Annoncer(string.format("%s a désormais l'initiative !", courant.nom))
    end
end

-- Le MJ suit l'initiative : au tour d'un PNJ, il l'incarne ; a son propre tour,
-- il reprend sa place. Au tour d'un autre joueur, il ne bouge pas. C'est le
-- reglage incarnationFollowInitiative du profil (vrai), et la regle de
-- SyncIncarnationWithInitiative.
local function SuivreIncarnation()
    local I = LCM.Incarnation
    if not (I and Combat.EstMJ()) then return end
    local courant = Combat.Courant()
    if not courant then return end
    if courant.pnj then
        if I.Instance(courant.id) and I.ActuelleId() ~= courant.id then I.Prendre(courant.id) end
    elseif courant.id == Moi() and I.ActuelleId() ~= "" then
        I.Relacher()
    end
end

-- Les PA reviennent au debut d'un TOUR complet, pas a chaque round ni a
-- chaque changement de combattant. Chaque joueur restaure sa propre fiche ;
-- le MJ, seul proprietaire des instances de PNJ, restaure aussi celles qui
-- participent au combat.
local function RestaurerPADuTour(avant, apres)
    if not (avant and apres and avant.s == apres.s and apres.t > avant.t) then return end
    local faits = {}
    local function Restaurer(entity)
        if not entity or faits[entity] then return end
        faits[entity] = true
        local jauge = LCM.Entities.Gauge(entity, "pa")
        if jauge then LCM.Entities.SetGauge(entity, "pa", jauge.max) end
    end

    local estMJ = apres.mj == Moi()
    for _, entree in ipairs(apres.entrees or {}) do
        if not entree.pnj and entree.id == Moi() then
            Restaurer(LCM.Entities.Personnage())
        elseif estMJ and entree.pnj and LCM.Incarnation then
            Restaurer(LCM.Incarnation.Instance(entree.id))
        end
    end
end

local function Appliquer(etat)
    local avant = Combat.etat
    Combat.etat = etat
    local charDb = LCM.charDb
    if charDb then
        local participe = false
        if etat then
            for _, entree in ipairs(etat.entrees or {}) do
                if not entree.pnj and entree.id == Moi() then participe = true break end
            end
        end
        if participe then
            charDb.combatSnapshot = { s = etat.s, mj = etat.mj, etat = Combat.Paquet(etat) }
        else
            charDb.combatSnapshot = nil
        end
    end
    RestaurerPADuTour(avant, etat)
    -- Figer les soldes des fiches locales avant qu'un dot du nouveau round
    -- retire des PA : cette perte doit compter dans sa tranche.
    if etat then
        for _, entree in ipairs(etat.entrees or {}) do
            if not entree.pnj and entree.id == Moi() then
                Combat.PADisponibles(LCM.Entities.Personnage())
            elseif etat.mj == Moi() and entree.pnj and LCM.Incarnation then
                Combat.PADisponibles(LCM.Incarnation.Instance(entree.id))
            end
        end
    end
    if etat and etat.mj == Moi() then
        AnnoncerChangements(avant, etat)
        SuivreIncarnation()
    end
    -- Un round de plus : les etats temporaires vieillissent (chez chacun, pour
    -- ce qu'il porte). Revenir en arriere ne leur rend rien.
    if avant and etat and avant.s == etat.s and (etat.t > avant.t or (etat.t == avant.t and etat.r > avant.r)) then
        if LCM.EtatsTemporaires then LCM.EtatsTemporaires.Vieillir() end
    end
    -- Le deplacement se rend quand c'est DE NOUVEAU a nous de jouer, pas au
    -- changement de round : un round n'est pas un tour, et c'est en reprenant
    -- la main qu'on retrouve ses deux deplacements. C'etait un bouton « Nv
    -- round » que le joueur devait penser a cliquer ; le combat le sait tout
    -- seul.
    if LCM.DeplacementForce and etat then
        local courant = etat.entrees[etat.c]
        local avantCourant = avant and avant.entrees[avant.c]
        local aNous = courant and courant.id == Moi()
        local etaitANous = avantCourant and avantCourant.id == Moi()
        if aNous and not (etaitANous and avant.s == etat.s) then
            LCM.DeplacementForce.NouveauRound(true)
        end
    end
    Prevenir()
end

-- ===== Mise en paquet ======================================================
-- L'encodage du reseau ne connait qu'un niveau d'imbrication : les combattants
-- se disent a plat, j1/n1/v1, j2/n2/v2...

function Combat.Paquet(etat)
    local p = { s = etat.s, c = etat.c, t = etat.t, r = etat.r, rm = etat.rm, nb = #etat.entrees }
    for k, e in ipairs(etat.entrees) do
        p["j" .. k] = e.id
        p["n" .. k] = e.nom
        p["v" .. k] = e.v
        if e.icone then p["ic" .. k] = e.icone end
        if e.pnj then p["p" .. k] = 1 end
        if e.ko then p["k" .. k] = 1 end
    end
    return p
end

function Combat.Depaqueter(p, mj)
    local etat = {
        s = tostring(p.s or ""), mj = mj,
        c = tonumber(p.c) or 1, t = tonumber(p.t) or 1,
        r = tonumber(p.r) or 1, rm = tonumber(p.rm) or 1,
        entrees = {},
    }
    for k = 1, tonumber(p.nb) or 0 do
        local id = p["j" .. k]
        if id then
            etat.entrees[#etat.entrees + 1] = {
                id = tostring(id), nom = tostring(p["n" .. k] or id),
                v = tonumber(p["v" .. k]) or 0,
                icone = p["ic" .. k], pnj = p["p" .. k] ~= nil,
                ko = p["k" .. k] ~= nil,
            }
        end
    end
    -- Un curseur hors de la liste viendrait d'un message abime : on le ramene
    -- au premier plutot que de montrer un bandeau sans personne d'actif.
    if etat.c < 1 or etat.c > #etat.entrees then etat.c = 1 end
    return etat
end

-- ===== Cote MJ : inviter, lancer, faire avancer ============================

local function NouvelleSession()
    return string.format("%d%04d", math.floor((GetTime and GetTime() or 0) * 1000) % 100000,
        math.random(0, 9999))
end

-- options = { pnj = { idInstance, ... }, moi = true }
-- Le MJ s'inclut par defaut, comme dans Necronicon (initiativeHideSelf faux).
function Combat.Inviter(options)
    if not LCM.IsMaster() then return nil, "reserve au maitre du jeu." end
    if Combat.etat then return nil, "un combat est deja en cours." end
    options = type(options) == "table" and options or {}
    local invitation = {
        s = NouvelleSession(),
        moi = options.moi ~= false,
        pnj = {},
        cibles = {},
        reponses = {},
    }
    for _, id in ipairs(options.pnj or {}) do
        if LCM.Incarnation.Instance(id) then invitation.pnj[#invitation.pnj + 1] = id end
    end
    for _, joueur in ipairs(Combat.Membres()) do invitation.cibles[joueur] = true end
    Combat.invitation = invitation

    if not next(invitation.cibles) then
        -- Personne a attendre : on lance tout de suite.
        return Combat.Lancer()
    end
    Envoyer("combat?", { s = invitation.s }, Combat.CanalGroupe())
    if Combat.onInvitation then Combat.onInvitation(invitation) end
    return invitation
end

function Combat.Attendus()
    local invitation = Combat.invitation
    local out = {}
    if not invitation then return out end
    for joueur in pairs(invitation.cibles) do
        if invitation.reponses[joueur] == nil then out[#out + 1] = joueur end
    end
    table.sort(out)
    return out
end

function Combat.Annuler()
    if not Combat.invitation then return false end
    Combat.invitation = nil
    if Combat.onInvitation then Combat.onInvitation(nil) end
    return true
end

-- Lance avec ceux qui ont accepte. Ceux qui n'ont pas encore repondu restent
-- dehors : « Lancer sans attendre » ne force personne a combattre.
function Combat.Lancer()
    if not LCM.IsMaster() then return nil, "reserve au maitre du jeu." end
    local invitation = Combat.invitation
    if not invitation then return nil, "aucune invitation en cours." end

    local entrees = {}
    if invitation.moi then
        local fiche = MaFiche()
        local nom, icone = MonIdentite()
        entrees[#entrees + 1] = {
            id = Moi(), nom = nom, v = (Combat.Jet(fiche)), icone = icone,
            ko = EstKO(fiche) or nil,
        }
    end
    for _, id in ipairs(invitation.pnj) do
        local instance = LCM.Incarnation.Instance(id)
        if instance then
            entrees[#entrees + 1] = {
                id = instance.id, nom = Tronquer(instance.name, Combat.NOM_MAX),
                v = (Combat.Jet(instance)), icone = Tronquer(LCM.Icone(instance.icon), Combat.ICONE_MAX),
                pnj = true, ko = EstKO(instance) or nil,
            }
        end
    end
    for joueur, reponse in pairs(invitation.reponses) do
        if reponse.ok then
            entrees[#entrees + 1] = {
                id = joueur, nom = reponse.nom, v = reponse.v, icone = reponse.icone,
                ko = reponse.ko or nil,
            }
        end
    end
    if #entrees == 0 then return nil, "personne au combat." end
    Combat.Trier(entrees)

    Combat.invitation = nil
    if Combat.onInvitation then Combat.onInvitation(nil) end
    local etat = { s = invitation.s, mj = Moi(), c = 1, t = 1, r = 1,
                   rm = math.max(1, tonumber(Eq().roundsParTour) or 1), entrees = entrees }
    Appliquer(etat)
    Envoyer("combat=", Combat.Paquet(etat), Combat.CanalGroupe())
    return etat
end

-- Range de nouveaux combattants dans un combat lance : l'ordre est retrie sans
-- deplacer celui dont c'est actuellement le tour, puis diffuse.
local function AjouterEntrees(entrees)
    local courant = Combat.Courant()
    local idCourant = courant and courant.id
    local nouveau = LCM.Copie(Combat.etat)
    for _, entree in ipairs(entrees) do nouveau.entrees[#nouveau.entrees + 1] = entree end
    Combat.Trier(nouveau.entrees)
    for index, entree in ipairs(nouveau.entrees) do
        if entree.id == idCourant then nouveau.c = index break end
    end
    Appliquer(nouveau)
    Envoyer("combat=", Combat.Paquet(nouveau), Combat.CanalGroupe())
end

local function DansLeCombat(etat, id)
    for _, entree in ipairs(etat.entrees) do
        if entree.id == id then return true end
    end
    return false
end

-- Ajoute des joueurs ou des PNJ a un combat deja lance. Un joueur fait son jet
-- comme lors de l'invitation initiale, et entre a son acceptation. Un PNJ en
-- jeu (Incarner) n'a personne a attendre : le MJ jette pour lui et il entre
-- tout de suite — jusqu'au 16 octobre 2026, seuls les joueurs pouvaient
-- rejoindre un combat lance.
function Combat.Integrer(ids)
    if not Combat.EstMJ() then return nil, "reserve au maitre du jeu qui mene le combat." end
    local etat = Combat.etat
    if not etat then return nil, "aucun combat en cours." end
    local pnj = {}
    local invitation = Combat.invitationTardive or { s = etat.s, cibles = {}, reponses = {} }
    for _, nom in ipairs(ids or {}) do
        local instance = LCM.Incarnation.Instance(nom)
        if instance then
            if not DansLeCombat(etat, instance.id) then
                pnj[#pnj + 1] = {
                    id = instance.id, nom = Tronquer(instance.name, Combat.NOM_MAX),
                    v = (Combat.Jet(instance)), icone = Tronquer(LCM.Icone(instance.icon), Combat.ICONE_MAX),
                    pnj = true, ko = EstKO(instance) or nil,
                }
            end
        else
            local joueur = IdJoueur(nom)
            if not DansLeCombat(etat, joueur) and LCM.Reseau.DansLeGroupe(joueur) then
                invitation.cibles[joueur] = true
                Envoyer("combat?", { s = invitation.s }, "WHISPER", joueur)
            end
        end
    end
    if #pnj > 0 then AjouterEntrees(pnj) end
    if next(invitation.cibles) then
        Combat.invitationTardive = invitation
        if Combat.onInvitation then Combat.onInvitation(invitation) end
        return invitation
    end
    Combat.invitationTardive = nil
    if #pnj > 0 then return Combat.etat end
    return nil, "aucun nouveau combattant valide a integrer."
end

local function AjouterReponseTardive(joueur, reponse)
    local invitation = Combat.invitationTardive
    if not invitation or not invitation.cibles[joueur] then return false end
    invitation.cibles[joueur] = nil
    invitation.reponses[joueur] = reponse
    if reponse.ok then
        AjouterEntrees({ {
            id = joueur, nom = reponse.nom, v = reponse.v, icone = reponse.icone,
            ko = reponse.ko or nil,
        } })
    end
    if not next(invitation.cibles) then Combat.invitationTardive = nil end
    if Combat.onInvitation then Combat.onInvitation(Combat.invitationTardive) end
    return true
end

-- Tour et round avancent quand la liste fait le tour (AdvanceInitiativeSequence,
-- tours et rounds comptes tous deux) : round suivant ; apres le dernier round,
-- round 1 du tour suivant. A rebours, l'inverse, sans descendre sous le tour 1.
local function Compteurs(etat, sens)
    if sens > 0 then
        etat.r = etat.r + 1
        if etat.r > etat.rm then
            etat.r = 1
            etat.t = etat.t + 1
        end
    else
        etat.r = etat.r - 1
        if etat.r < 1 then
            etat.r = etat.rm
            etat.t = math.max(1, etat.t - 1)
        end
    end
end

function Combat.Avancer(sens)
    if not Combat.EstMJ() then return nil, "reserve au maitre du jeu qui mene le combat." end
    sens = (tonumber(sens) or 1) >= 0 and 1 or -1
    local etat = Combat.etat
    local nombre = #etat.entrees
    local function PasSuivant()
        local suivant = LCM.Copie(Combat.etat)
        suivant.c = suivant.c + sens
        if suivant.c > nombre then
            suivant.c = 1
            Compteurs(suivant, 1)
        elseif suivant.c < 1 then
            suivant.c = nombre
            Compteurs(suivant, -1)
        end
        Appliquer(suivant)
        return suivant
    end

    -- Les etats (dont les degats periodiques) sont resolus par Appliquer
    -- avant de verifier le KO. On saute uniquement les joueurs inconscients ;
    -- le MJ garde la main sur les tours des PNJ. La borne evite une boucle si
    -- tous les joueurs du combat sont KO.
    for _ = 1, math.max(1, nombre) do
        etat = PasSuivant()
        local courant = etat.entrees[etat.c]
        if not (courant and not courant.pnj and courant.ko) then break end
    end
    Envoyer("combat~", { s = etat.s, c = etat.c, t = etat.t, r = etat.r }, Combat.CanalGroupe())
    return etat
end

function Combat.Terminer()
    local etat = Combat.etat
    if not etat then return false, "aucun combat en cours." end
    if etat.mj ~= Moi() then return false, "seul le maitre du jeu qui mene le combat peut l'arreter." end
    Combat.etat = nil
    Combat.invitationTardive = nil
    if LCM.charDb then LCM.charDb.combatSnapshot = nil end
    Envoyer("combat.", { s = etat.s }, Combat.CanalGroupe())
    LCM.Info("Combat terminé.")
    Prevenir()
    return true
end

-- ===== Cote joueur =========================================================

function Combat.Repondre(accepte)
    local recue = Combat.invitationRecue
    if not recue then return false, "aucune invitation." end
    Combat.invitationRecue = nil
    local paquet = { s = recue.s, ok = accepte and 1 or 0 }
    if accepte then
        local total, resultat = Combat.Jet(LCM.Entities.Self())
        local nom, icone = MonIdentite()
        paquet.n, paquet.ic, paquet.v = nom, icone, total
        paquet.k = EstKO(LCM.Entities.Self()) and 1 or nil
        if resultat then LCM.Info(LCM.Roll.Describe(resultat)) end
    end
    if Combat.onInvitationRecue then Combat.onInvitationRecue(nil) end
    return Envoyer("combat+", paquet, "WHISPER", recue.mj)
end

-- Le bouton « Passer le tour ». Le MJ avance lui-meme ; le joueur le demande
-- au MJ, qui verifiera que c'est bien son tour.
function Combat.Passer()
    local etat = Combat.etat
    if not etat then return false, "aucun combat en cours." end
    if not Combat.PeutPasser() then return false, "ce n'est pas ton tour." end
    if Combat.EstMJ() then return Combat.Avancer(1) ~= nil end
    return Envoyer("combat>", { s = etat.s }, "WHISPER", etat.mj)
end

-- ===== Reception ===========================================================

LCM.WhenReady(function()
    local R = LCM.Reseau

    -- Une invitation. On ne la propose qu'a quelqu'un du meme groupe, et pas
    -- pendant un combat qu'on mene soi-meme.
    R.Ecouter("combat?", function(expediteur, d)
        if Combat.EstMJ() then return end
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        if Combat.etat and Combat.etat.s ~= tostring(d.s or "") then return end
        Combat.invitationRecue = { s = tostring(d.s or ""), mj = IdJoueur(expediteur) }
        if Combat.onInvitationRecue then Combat.onInvitationRecue(Combat.invitationRecue) end
    end)

    -- Une reponse. Elle ne compte que pour l'invitation en cours, et venant de
    -- quelqu'un qu'on a invite.
    R.Ecouter("combat+", function(expediteur, d)
        local invitation = Combat.invitation
        local joueur = IdJoueur(expediteur)
        if Combat.etat and Combat.invitationTardive
            and tostring(d.s) == Combat.invitationTardive.s
            and Combat.invitationTardive.cibles[joueur] then
            local reponse
            if tostring(d.ok) == "1" then
                reponse = { ok = true, v = tonumber(d.v) or 0,
                    nom = Tronquer(Nettoyer(d.n) ~= "" and d.n or joueur, Combat.NOM_MAX),
                    icone = d.ic and Tronquer(d.ic, Combat.ICONE_MAX) or nil,
                    ko = tostring(d.k) == "1" }
            else
                reponse = { ok = false }
            end
            AjouterReponseTardive(joueur, reponse)
            return
        end
        if not invitation or tostring(d.s) ~= invitation.s then return end
        if not invitation.cibles[joueur] then return end
        if tostring(d.ok) == "1" then
            invitation.reponses[joueur] = {
                ok = true, v = tonumber(d.v) or 0,
                nom = Tronquer(Nettoyer(d.n) ~= "" and d.n or joueur, Combat.NOM_MAX),
                icone = d.ic and Tronquer(d.ic, Combat.ICONE_MAX) or nil,
                ko = tostring(d.k) == "1",
            }
        else
            invitation.reponses[joueur] = { ok = false }
        end
        if Combat.onInvitation then Combat.onInvitation(invitation) end
        -- Tout le monde a repondu : on lance (Necronicon faisait de meme).
        if #Combat.Attendus() == 0 then Combat.Lancer() end
    end)

    -- L'etat complet. Celui qui mene son propre combat n'en accepte pas d'un
    -- autre : son etat a lui fait foi.
    R.Ecouter("combat=", function(expediteur, d)
        if Combat.EstMJ() then return end
        local etat = Combat.Depaqueter(d, IdJoueur(expediteur))
        -- Comme dans Necronicon, celui qui n'est pas au combat ne voit pas le
        -- bandeau : il a refuse, ou il n'a pas ete invite.
        local present = false
        for _, e in ipairs(etat.entrees) do
            if not e.pnj and e.id == Moi() then present = true break end
        end
        if not present then return end
        Appliquer(etat)
    end)

    R.Ecouter("combat~", function(expediteur, d)
        local etat = Combat.etat
        if not etat or Combat.EstMJ() then return end
        if etat.mj ~= IdJoueur(expediteur) or etat.s ~= tostring(d.s) then return end
        local nouveau = LCM.Copie(etat)
        nouveau.c = tonumber(d.c) or nouveau.c
        nouveau.t = tonumber(d.t) or nouveau.t
        nouveau.r = tonumber(d.r) or nouveau.r
        if nouveau.c < 1 or nouveau.c > #nouveau.entrees then return end
        Appliquer(nouveau)
    end)

    -- Un joueur annonce uniquement son propre changement ; le MJ choisit
    -- l'entree a partir de l'expediteur et relaie une version autoritaire.
    R.Ecouter("combatK", function(expediteur, d)
        local etat = Combat.etat
        if not etat or not Combat.EstMJ() or etat.s ~= tostring(d.s) then return end
        local joueur = IdJoueur(expediteur)
        local entree = EntreeParId(joueur)
        if not entree or entree.pnj then return end
        DefinirKO(joueur, tostring(d.k) == "1", true)
    end)

    R.Ecouter("combatK=", function(expediteur, d)
        local etat = Combat.etat
        if not etat or Combat.EstMJ() then return end
        if etat.mj ~= IdJoueur(expediteur) or etat.s ~= tostring(d.s) then return end
        DefinirKO(tostring(d.j or ""), tostring(d.k) == "1", false)
    end)

    R.Ecouter("combat.", function(expediteur, d)
        local etat = Combat.etat
        if not etat or Combat.EstMJ() then
            local snapshot = LCM.charDb and LCM.charDb.combatSnapshot
            if snapshot and tostring(d.s) == tostring(snapshot.s) then
                LCM.charDb.combatSnapshot = nil
                Combat.etat = nil
                Prevenir()
            end
            return
        end
        if etat.mj ~= IdJoueur(expediteur) or etat.s ~= tostring(d.s) then return end
        Combat.etat = nil
        if LCM.charDb then LCM.charDb.combatSnapshot = nil end
        LCM.Info("Combat terminé.")
        Prevenir()
    end)

    -- « J'ai fini mon tour. » Seul celui dont c'est le tour peut le dire.
    R.Ecouter("combat>", function(expediteur, d)
        local etat = Combat.etat
        if not Combat.EstMJ() or etat.s ~= tostring(d.s) then return end
        local courant = Combat.Courant()
        if not courant or courant.pnj or courant.id ~= IdJoueur(expediteur) then return end
        Combat.Avancer(1)
    end)

    -- Un joueur revient d'un /reload : on lui rend l'etat, s'il en est.
    R.Ecouter("combat!", function(expediteur, d)
        local etat = Combat.etat
        if not LCM.IsMaster() then return end
        local joueur = IdJoueur(expediteur)
        if not LCM.Reseau.DansLeGroupe(joueur) then return end
        if not etat then
            Envoyer("combat.", { s = tostring(d and d.s or "") }, "WHISPER", joueur)
            return
        end
        for _, e in ipairs(etat.entrees) do
            if not e.pnj and e.id == joueur then
                Envoyer("combat=", Combat.Paquet(etat), "WHISPER", joueur)
                return
            end
        end
        Envoyer("combat.", { s = tostring(d and d.s or etat.s) }, "WHISPER", joueur)
    end)

    -- Au chargement, si l'on est en groupe, on demande ou en est le combat.
    local function DemanderEtat()
        local canal = Combat.CanalGroupe()
        if canal then
            local snapshot = LCM.charDb and LCM.charDb.combatSnapshot
            Envoyer("combat!", { s = snapshot and snapshot.s or "" }, canal)
        end
    end
    if LCM.charDb and LCM.charDb.combatSnapshot then
        local snapshot = LCM.charDb.combatSnapshot
        local sauvegarde = Combat.Depaqueter(snapshot.etat or snapshot, snapshot.mj)
        local participe = false
        for _, entree in ipairs(sauvegarde.entrees) do
            if not entree.pnj and entree.id == Moi() then participe = true break end
        end
        if participe then Appliquer(sauvegarde) else LCM.charDb.combatSnapshot = nil end
    end
    DemanderEtat()
    -- Une seule requete au login pouvait partir avant l'arrivee dans le
    -- groupe. Quelques reprises courtes couvrent reconnexion/crash et delai
    -- de restauration de groupe, puis GROUP_ROSTER_UPDATE reprend le relais.
    if C_Timer and C_Timer.After then
        for essai = 1, 5 do
            C_Timer.After(essai * 2, DemanderEtat)
        end
    end
    LCM.On("GROUP_ROSTER_UPDATE", DemanderEtat)

    -- Les blessures changent en dehors du pas d'initiative. On actualise le
    -- bandeau sur-le-champ, puis le proprietaire de l'etat le synchronise.
    LCM.Entities.Ecouter(function(entity, fieldId)
        local etat = Combat.etat
        -- Body est enveloppe par Core/Direct : hors geste on recoit « corps »,
        -- a la fin d'un geste atomique on recoit « direct ».
        if not etat or (fieldId ~= "corps" and fieldId ~= "direct") then return end
        local id
        if entity.kind == "npc" and Combat.EstMJ() then
            id = entity.id
        elseif entity == LCM.Entities.Personnage() then
            id = Moi()
        end
        if not id or not EntreeParId(id) then return end
        local ko = EstKO(entity)
        if Combat.EstMJ() then
            DefinirKO(id, ko, true)
        elseif id == Moi() and DefinirKO(id, ko, false) then
            Envoyer("combatK", { s = etat.s, k = ko and 1 or 0 }, "WHISPER", etat.mj)
        end
    end)
end)

LCM.AddCommand("combat", "le combat : passer (son tour), fin (MJ) ; seul, ouvre la fenetre du MJ", function(argument)
    local mot = Nettoyer(argument):lower()
    local ok, raison
    -- La fenetre de combat vit dans le compagnon MJ : chez un joueur, elle
    -- n'existe pas, et « /lcm combat » passe son tour.
    if mot == "" and LCM.UI and LCM.UI.CombatMJ then
        LCM.UI.CombatMJ.Basculer()
        return
    end
    if mot == "passer" or mot == "" then
        ok, raison = Combat.Passer()
    elseif mot == "fin" then
        ok, raison = Combat.Terminer()
    else
        LCM.Alerte("/lcm combat passer, ou /lcm combat fin.")
        return
    end
    if not ok and raison then LCM.Alerte(raison) end
end)
