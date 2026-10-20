-- Les marchands poses sur la carte, cote aventurier (13 octobre 2026).
--
-- La meme procedure que les points de recolte (Core/Recolte.lua) : le MJ pose
-- un vendeur ; un aventurier qui se tient devant voit « Commercer » et ouvre
-- son etal. Rien n'est livre dans l'addon joueur : il demande les vendeurs a
-- la connexion, le MJ les lui envoie en silence (et a chaque arrivant, et a
-- chaque pose), et le joueur les garde dans sa sauvegarde.
--
-- Ce qui se partage, c'est le STOCK d'une offre (« 10 herbes, 2 par heure ») :
--   * MJ present : il ARBITRE chaque achat. Il reserve l'unite (EN ATTENTE),
--     le joueur paie et range, puis confirme ; s'il ne peut pas ranger, il
--     rend l'unite. Deux joueurs ne vident pas le meme etal deux fois ;
--   * MJ absent : on achete quand meme. L'achat est EN ATTENTE chez le joueur,
--     qui le signale au MJ des qu'il le croise ; le MJ l'accuse et l'oublie.
--     Le stock affiche deduit ce qu'on a deja pris sans le lui avoir dit.
--
-- Revendre (les « Achats » du constructeur : le vendeur reprend un objet) ne
-- touche a aucun stock : cela se fait chez le joueur, sans reseau.

local _, LCM = ...

local Marchands = {
    -- definitions[id] = { id, label, auteur, offres = {...}, rachats = {...} }
    -- points[id] = { id, def, x, y, source, carte }
    definitions = {}, points = {},
    -- Achats demandes au MJ present, sans reponse encore : « v/o » -> instant.
    enAttente = {},
    -- Et la facon de payer choisie pour chacun : la reponse du MJ arrive apres.
    choix = {},
    -- Achats faits en l'absence du MJ, a lui dire : « v/o » -> { a, v, o, n }.
    attente = {},
}
LCM.Marchands = Marchands

local INTERVALLE = 0.25
local DELAI_REPONSE = 5

Marchands.SUJETS = {
    definition = "mar",   -- MJ -> joueur(s) : un vendeur, ses offres et ses points
    retrait    = "mar-",  -- MJ -> groupe   : un point (ou un vendeur) n'est plus
    demande    = "mar?",  -- joueur -> groupe : envoyez-moi vos vendeurs
    acheter    = "mar!",  -- joueur -> MJ   : je prends une unite de cette offre
    reponse    = "mar+",  -- MJ -> joueur   : elle est a toi (ou pourquoi non)
    rendre     = "mar~",  -- joueur -> MJ   : je n'ai pas pu ranger, reprends-la
    confirmer  = "mar^",  -- joueur -> MJ   : paye et range
    stock      = "mar=",  -- MJ -> groupe   : ce qu'il reste d'une offre
    signaler   = "mar#",  -- joueur -> MJ   : j'ai achete ceci en ton absence
    accuse     = "mar*",  -- MJ -> joueur   : c'est note
}
local S = Marchands.SUJETS

local function Eq() return (LCM.Equilibrage and LCM.Equilibrage.marchands) or {} end
local function Moi() return LCM.PlayerId() end
local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Cle(v, o) return tostring(v) .. "/" .. tostring(o) end

function Marchands.Rayon() return tonumber(Eq().rayon) or 4 end

-- ===== Le paquet d'un vendeur ==============================================
-- Les offres en table imbriquee (l'encodeur sait les dire) ; les points en
-- une chaine, comme la recolte. Cles courtes : un etal de vingt articles fait
-- deja plusieurs morceaux. Le prix voyage plie en une chaine (Prix.Plier) :
-- ses facons et leurs morceaux en tables feraient trois niveaux de plus.

function Marchands.Paquet(definition, points)
    local o, b = {}, {}
    for _, offre in ipairs(definition.offres or {}) do
        local definitionObjet = LCM.Echange and LCM.Echange.DefinitionPartagee(offre.entree)
        o[#o + 1] = { i = offre.id, e = offre.entree, l = offre.label, q = offre.quantite,
            f = LCM.Prix.Plier(LCM.Prix.DeLOffre(offre)), g = offre.onglet, s = offre.limite,
            r = offre.restant, x = definitionObjet }
    end
    for _, rachat in ipairs(definition.rachats or {}) do
        b[#b + 1] = { i = rachat.id, e = rachat.entree, l = rachat.label,
            f = LCM.Prix.Plier(LCM.Prix.DeLOffre(rachat)), g = rachat.onglet }
    end
    return { i = definition.id, n = definition.label, o = o, b = b,
        p = LCM.Recolte.Plier(points) }
end

local function Nombre(v, defaut) return tonumber(v) or defaut end

-- Le prix d'une offre recue. Un MJ pas encore a jour envoie l'ancienne forme
-- (`p` et `d`, un montant et une devise).
local function FaconsRecues(o)
    if Texte(o.f) ~= "" then return LCM.Prix.Deplier(o.f) end
    return LCM.Prix.Lire(Nombre(o.p), Texte(o.d)) or {}
end

function Marchands.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local definition = { id = id, label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Marchand",
        offres = {}, rachats = {} }
    local function Rang(t)
        local out = {}
        for k, v in pairs(type(t) == "table" and t or {}) do
            if tonumber(k) and type(v) == "table" then out[#out + 1] = { k = tonumber(k), v = v } end
        end
        table.sort(out, function(a, b) return a.k < b.k end)
        return out
    end
    for _, r in ipairs(Rang(paquet.o)) do
        local o = r.v
        if Texte(o.i) ~= "" then
            definition.offres[#definition.offres + 1] = {
                id = Texte(o.i), entree = Texte(o.e), label = Texte(o.l),
                quantite = math.max(1, math.floor(Nombre(o.q, 1))),
                formules = FaconsRecues(o),
                onglet = Texte(o.g) ~= "" and Texte(o.g) or nil,
                limite = math.max(0, math.floor(Nombre(o.s, 0))),
                restant = math.max(0, math.floor(Nombre(o.r, 0))),
                definition = type(o.x) == "table" and o.x or nil,
            }
            local dernier = definition.offres[#definition.offres]
            if dernier.definition and LCM.Echange and LCM.Echange.ImporterPartage then
                LCM.Echange.ImporterPartage({ ref = dernier.entree, definition = dernier.definition })
            end
        end
    end
    for _, r in ipairs(Rang(paquet.b)) do
        local o = r.v
        if Texte(o.i) ~= "" then
            definition.rachats[#definition.rachats + 1] = {
                id = Texte(o.i), entree = Texte(o.e), label = Texte(o.l),
                formules = FaconsRecues(o),
                onglet = Texte(o.g) ~= "" and Texte(o.g) or nil,
            }
        end
    end
    return definition, LCM.Recolte.Deplier(paquet.p)
end

-- ===== La sauvegarde =======================================================
-- Ce que les MJ nous ont envoye et ce qu'on a achete sans eux. Pas ce que le
-- MJ local pose lui-meme : il le reconstruit a chaque connexion.

function Marchands.Sauver()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local moi = Moi()
    local definitions, points = {}, {}
    for id, d in pairs(Marchands.definitions) do
        if d.auteur ~= moi then definitions[id] = d end
    end
    for id, p in pairs(Marchands.points) do
        if definitions[p.def] then points[id] = p end
    end
    if next(definitions) or next(Marchands.attente) then
        LCM.db.marche = { definitions = definitions, points = points, attente = Marchands.attente }
    else
        LCM.db.marche = nil
    end
end

function Marchands.Charger()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local garde = type(LCM.db.marche) == "table" and LCM.db.marche or nil
    if not garde then return end
    for id, d in pairs(type(garde.definitions) == "table" and garde.definitions or {}) do
        if type(d) == "table" then Marchands.definitions[id] = d end
    end
    for id, p in pairs(type(garde.points) == "table" and garde.points or {}) do
        if type(p) == "table" and Marchands.definitions[p.def] then Marchands.points[id] = p end
    end
    for cle, a in pairs(type(garde.attente) == "table" and garde.attente or {}) do
        if type(a) == "table" then Marchands.attente[cle] = a end
    end
end

-- ===== Ce qu'on connait ====================================================

local function Prevenir()
    Marchands.Sauver()
    Marchands.Regler()
    if Marchands.onChange then pcall(Marchands.onChange) end
end
Marchands.Prevenir = Prevenir

function Marchands.Connaitre(definition, points, auteur)
    if type(definition) ~= "table" or not definition.id then return false end
    definition.auteur = auteur or definition.auteur
    Marchands.definitions[definition.id] = definition
    for id, p in pairs(Marchands.points) do
        if p.def == definition.id then Marchands.points[id] = nil end
    end
    for _, p in ipairs(points or {}) do
        p.def = definition.id
        Marchands.points[p.id] = p
    end
    Prevenir()
    return true
end

function Marchands.Oublier(pointId)
    if not Marchands.points[tostring(pointId or "")] then return false end
    Marchands.points[tostring(pointId)] = nil
    Prevenir()
    return true
end

function Marchands.OublierDefinition(defId)
    defId = tostring(defId or "")
    Marchands.definitions[defId] = nil
    for id, p in pairs(Marchands.points) do
        if p.def == defId then Marchands.points[id] = nil end
    end
    Prevenir()
end

function Marchands.Offre(defId, offreId)
    local d = Marchands.definitions[tostring(defId or "")]
    for _, o in ipairs((d and d.offres) or {}) do
        if o.id == tostring(offreId) then return o, d end
    end
    return nil, d
end

function Marchands.Rachat(defId, rachatId)
    local d = Marchands.definitions[tostring(defId or "")]
    for _, o in ipairs((d and d.rachats) or {}) do
        if o.id == tostring(rachatId) then return o, d end
    end
    return nil, d
end

-- Ce qu'il reste, vu d'ici : le stock du MJ moins ce qu'on lui a pris sans le
-- lui avoir encore dit. nil : illimite.
function Marchands.Disponible(defId, offre)
    if not offre or (offre.limite or 0) <= 0 then return nil end
    local a = Marchands.attente[Cle(defId, offre.id)]
    return math.max(0, (offre.restant or 0) - ((a and a.n) or 0))
end

-- Le libelle d'une offre : le sien, sinon celui de l'entree du compendium.
function Marchands.Libelle(offre)
    if offre.label and offre.label ~= "" then return offre.label end
    local e = LCM.Compendium.Resoudre(offre.entree)
    return (e and e.label) or offre.entree
end

-- ===== Ou l'on se tient ====================================================

function Marchands.Proche(positions)
    positions = positions or {}
    local carte = LCM.Recolte.Carte()
    local meilleur, meilleureDistance
    for _, p in pairs(Marchands.points) do
        if Marchands.definitions[p.def] and p.carte == carte then
            local source = p.source or "?"
            -- De quoi juger si un `.gps` vaut la peine (DeplacementForce.GPSAPortee).
            if source == "gps" then
                positions.cibles = positions.cibles or {}
                positions.cibles[#positions.cibles + 1] = { x = p.x, y = p.y, r = Marchands.Rayon() }
            end
            local pos = positions[source]
            if pos == nil then
                local D = LCM.DeplacementForce
                local x, y, z
                if D then x, y, z = D.Position(p.source, p.source == "gps" and 1 or nil) end
                pos = x and { x = x, y = y, z = z } or false
                positions[source] = pos
            end
            if pos then
                local distance = LCM.Recolte.Distance(p, pos)
                if distance and distance <= Marchands.Rayon() and (not meilleureDistance or distance < meilleureDistance) then
                    meilleur, meilleureDistance = p, distance
                end
            end
        end
    end
    return meilleur, meilleureDistance
end

function Marchands.ProcheHorizontal()
    local D = LCM.DeplacementForce
    local x, y
    if D then x, y = D.Position("monde") end
    if not (x and y) then return nil end
    local carte, meilleur, distanceMin = LCM.Recolte.Carte()
    for _, p in pairs(Marchands.points) do
        local px, py = tonumber(p.x), tonumber(p.y)
        if Marchands.definitions[p.def] and p.carte == carte and p.source ~= "carte" and px and py then
            local distance = math.sqrt((x - px)^2 + (y - py)^2)
            if distance <= Marchands.Rayon() and (not distanceMin or distance < distanceMin) then
                meilleur, distanceMin = p, distance
            end
        end
    end
    return meilleur
end

function Marchands.Tick()
    local positions = {}
    local proche = Marchands.Proche(positions)
    if positions.gps == false then proche = Marchands.ProcheHorizontal() end
    local avant = Marchands.courant
    Marchands.courant = proche
    if avant ~= proche and Marchands.onProche then pcall(Marchands.onProche, proche) end
end

local horloge
function Marchands.Regler()
    if not horloge then
        horloge = CreateFrame("Frame", nil, UIParent)
        horloge:Hide()
        horloge.reste = 0
        horloge:SetScript("OnUpdate", function(self, ecoule)
            self.reste = self.reste + (tonumber(ecoule) or 0)
            if self.reste < INTERVALLE then return end
            self.reste = 0
            Marchands.Tick()
        end)
    end
    local quelque = next(Marchands.points) ~= nil
    if quelque then horloge:Show() else horloge:Hide() end
    if not quelque and Marchands.courant then
        Marchands.courant = nil
        if Marchands.onProche then pcall(Marchands.onProche, nil) end
    end
    return quelque
end

-- On ne commerce qu'avec le vendeur devant lequel on se tient.
local function Devant(defId)
    local p = Marchands.Proche()
    return p and p.def == defId
end

-- ===== Acheter =============================================================

-- Le paiement est verifie une seconde fois ici : entre la demande et la
-- reponse du MJ, le joueur a pu depenser ce qu'il comptait donner.
local function Livrer(definition, offre, facon)
    local entity = LCM.Entities.Self()
    local peut, manque = LCM.Prix.Peut(entity, facon)
    if not peut then return false, manque end
    local ok, raison = LCM.Inventaire.Deposer(entity, offre.entree, offre.quantite)
    if not ok then return false, raison or "impossible de ranger." end
    LCM.Prix.Payer(entity, facon)
    LCM.Ok(string.format("Acheté : %s x%d.", Marchands.Libelle(offre), offre.quantite))
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    return true
end

-- Rend vrai quand l'achat est fait (ou demande au MJ). `choix` : le rang de
-- la facon de payer, quand l'offre en propose plusieurs (Core/Prix.lua).
function Marchands.Acheter(defId, offreId, choix)
    local offre, definition = Marchands.Offre(defId, offreId)
    if not offre then return false, "offre inconnue." end
    if not Devant(defId) then
        local D = LCM.DeplacementForce
        local p = Marchands.ProcheHorizontal()
        if p and p.def == defId and D and not D.Position("gps", 1)
            and D.DemanderGPS and D.DemanderGPS(true) then
            Marchands.attenteGPS = { action = "acheter", defId = defId, offreId = offreId, choix = choix }
            return true
        end
        return false, "tu n'es pas devant ce marchand, y compris en hauteur."
    end
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    local facon, pourquoi = LCM.Prix.Choisir(LCM.Prix.DeLOffre(offre), choix)
    if not facon then return false, pourquoi end
    local peut, manque = LCM.Prix.Peut(entity, facon)
    if not peut then return false, manque end
    local reste = Marchands.Disponible(defId, offre)
    if reste and reste < 1 then return false, "il n'y en a plus." end
    local cle = Cle(defId, offreId)
    local maintenant = (GetTime and GetTime()) or 0
    if Marchands.enAttente[cle] and maintenant - Marchands.enAttente[cle] < DELAI_REPONSE then
        return false, "achat déjà en cours."
    end
    Marchands.enAttente[cle] = nil

    -- Le MJ lui-meme : son propre arbitre.
    if definition.auteur == Moi() then
        if not reste then return Livrer(definition, offre, facon) end
        if not Marchands.Arbitre then return false, "aucun arbitre." end
        local ok, raison = Marchands.Arbitre(defId, offreId, Moi())
        if not ok then return false, raison end
        local livre, refus = Livrer(definition, offre, facon)
        if livre then Marchands.Confirmer(defId, offreId, Moi())
        else Marchands.Restituer(defId, offreId, Moi()) end
        return livre, refus
    end

    -- Sans stock a partager, rien a arbitrer : on achete.
    if not reste then return Livrer(definition, offre, facon) end

    if LCM.Recolte.EnLigne(definition.auteur) then
        Marchands.enAttente[cle] = maintenant
        Marchands.choix[cle] = facon
        LCM.Reseau.Envoyer(S.acheter, { v = defId, o = offreId }, "WHISPER", definition.auteur)
        return true
    end

    -- MJ absent : on achete, et on le lui dira.
    local ok, raison = Livrer(definition, offre, facon)
    if not ok then return false, raison end
    local a = Marchands.attente[cle] or { a = definition.auteur, v = defId, o = offreId, n = 0 }
    a.n = a.n + 1
    Marchands.attente[cle] = a
    Prevenir()
    LCM.Info("Le marchand en sera averti au retour du MJ.")
    return true
end

-- Revendre : le vendeur reprend un objet du sac et paie, de la facon que le
-- joueur choisit. Sans stock, sans MJ. Si le paiement ne tient pas dans les
-- sacs, l'objet est rendu.
function Marchands.Revendre(defId, rachatId, choix)
    local rachat = Marchands.Rachat(defId, rachatId)
    if not rachat then return false, "offre de rachat inconnue." end
    if not Devant(defId) then
        local D = LCM.DeplacementForce
        local p = Marchands.ProcheHorizontal()
        if p and p.def == defId and D and not D.Position("gps", 1)
            and D.DemanderGPS and D.DemanderGPS(true) then
            Marchands.attenteGPS = { action = "revendre", defId = defId, offreId = rachatId, choix = choix }
            return true
        end
        return false, "tu n'es pas devant ce marchand, y compris en hauteur."
    end
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    local facon, pourquoi = LCM.Prix.Choisir(LCM.Prix.DeLOffre(rachat), choix)
    if not facon then return false, pourquoi end
    local ok, raison = LCM.Inventaire.Prendre(entity, rachat.entree)
    if not ok then return false, raison or "objet absent des sacs." end
    local verse, refus = LCM.Prix.Verser(entity, facon)
    if not verse then
        LCM.Inventaire.Deposer(entity, rachat.entree, 1)
        return false, refus
    end
    LCM.Ok(string.format("Revendu : %s.", Marchands.Libelle(rachat)))
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    return true
end

function Marchands.ReponseGPS()
    local attente = Marchands.attenteGPS
    if not attente then return end
    Marchands.attenteGPS = nil
    local p = Marchands.Proche()
    if not p or p.def ~= attente.defId then
        LCM.Alerte("tu es trop loin du marchand, y compris en hauteur.")
        return
    end
    local ok, raison
    if attente.action == "revendre" then
        ok, raison = Marchands.Revendre(attente.defId, attente.offreId, attente.choix)
    else
        ok, raison = Marchands.Acheter(attente.defId, attente.offreId, attente.choix)
    end
    if not ok and raison then LCM.Alerte(raison) end
end

function Marchands.Signaler(auteur)
    local morceaux = {}
    for cle, a in pairs(Marchands.attente) do
        if a.a == auteur and (a.n or 0) > 0 then morceaux[#morceaux + 1] = cle .. ":" .. a.n end
    end
    if #morceaux == 0 then return false end
    table.sort(morceaux)
    return LCM.Reseau.Envoyer(S.signaler, { l = table.concat(morceaux, ",") }, "WHISPER", auteur)
end

-- Sans groupe connu encore (juste apres la connexion), la demande attend que
-- le groupe se fasse connaitre : meme piege que la recolte.
local demandeEnSuspens = false
function Marchands.Demander()
    local canal = LCM.Reseau.Diffusable()
    if not canal then
        demandeEnSuspens = true
        return false
    end
    demandeEnSuspens = false
    return LCM.Reseau.Envoyer(S.demande, {}, canal)
end

LCM.WhenReady(function()
    Marchands.Charger()
    Marchands.Regler()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(S.definition, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.Connu(expediteur) then return end
        local definition, points = Marchands.Lire(donnees)
        if definition then Marchands.Connaitre(definition, points, expediteur) end
        Marchands.Signaler(expediteur)
    end)

    LCM.Reseau.Ecouter(S.retrait, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local id, defId = Texte(donnees.i), Texte(donnees.d)
        if id ~= "" then
            local p = Marchands.points[id]
            local d = p and Marchands.definitions[p.def]
            if d and d.auteur == expediteur then Marchands.Oublier(id) end
        elseif defId ~= "" then
            local d = Marchands.definitions[defId]
            if d and d.auteur == expediteur then Marchands.OublierDefinition(defId) end
        end
    end)

    LCM.Reseau.Ecouter(S.stock, function(expediteur, donnees)
        local offre, d = Marchands.Offre(Texte(donnees.v), Texte(donnees.o))
        if not offre or d.auteur ~= expediteur then return end
        offre.restant = math.max(0, math.floor(tonumber(donnees.r) or 0))
        Prevenir()
    end)

    LCM.Reseau.Ecouter(S.reponse, function(expediteur, donnees)
        local v, o = Texte(donnees.v), Texte(donnees.o)
        local cle = Cle(v, o)
        if not Marchands.enAttente[cle] then return end
        local offre, d = Marchands.Offre(v, o)
        if not offre or d.auteur ~= expediteur then return end
        Marchands.enAttente[cle] = nil
        local facon = Marchands.choix[cle] or LCM.Prix.Choisir(LCM.Prix.DeLOffre(offre))
        Marchands.choix[cle] = nil
        if tonumber(donnees.r) then offre.restant = math.max(0, math.floor(tonumber(donnees.r))) end
        if tostring(donnees.ok or "") ~= "1" then
            Prevenir()
            LCM.Alerte(Texte(donnees.n) ~= "" and Texte(donnees.n) or "il n'y en a plus.")
            return
        end
        local ok, raison = false, "choisis comment payer."
        if facon then ok, raison = Livrer(d, offre, facon) end
        if ok then
            LCM.Reseau.Envoyer(S.confirmer, { v = v, o = o }, "WHISPER", expediteur)
        else
            LCM.Reseau.Envoyer(S.rendre, { v = v, o = o }, "WHISPER", expediteur)
            LCM.Alerte(tostring(raison))
        end
        Prevenir()
    end)

    LCM.Reseau.Ecouter(S.accuse, function(expediteur, donnees)
        local change = false
        for morceau in tostring(donnees.l or ""):gmatch("[^,]+") do
            local cle, n = morceau:match("^(.+):(%d+)$")
            local a = cle and Marchands.attente[cle]
            if a and a.a == expediteur then
                a.n = (a.n or 0) - tonumber(n)
                if a.n <= 0 then Marchands.attente[cle] = nil end
                change = true
            end
        end
        if change then Prevenir() end
    end)

    if not LCM.IsMaster() then Marchands.Demander() end
end)

-- Le canal de l'addon n'existe pas encore a la connexion : des qu'il repond,
-- on redemande (Core/Presence.lua, 20 octobre 2026).
LCM.WhenReady(function()
    if LCM.Presence and LCM.Presence.QuandCanal then
        LCM.Presence.QuandCanal(function() if not LCM.IsMaster() then Marchands.Demander() end end)
    end
end)

LCM.On("GROUP_JOINED", function()
    if not LCM.IsMaster() then Marchands.Demander() end
end)
LCM.On("GROUP_ROSTER_UPDATE", function()
    if LCM.ready and demandeEnSuspens and not LCM.IsMaster() then Marchands.Demander() end
end)
