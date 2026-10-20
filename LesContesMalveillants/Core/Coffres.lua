-- Coffres poses sur la carte : contenu partage, ouverture et verrouillage.
-- Le MJ proprietaire arbitre chaque mouvement pour que deux joueurs ne
-- puissent ni prendre le meme objet, ni depasser la capacite du coffre.

local _, LCM = ...
local Coffres = { definitions = {}, points = {}, courant = nil, etat = nil }
LCM.Coffres = Coffres
Coffres.METHODE_CLEF = "clef"

-- Ce qu'un coffre accueille : des objets, des livres, des ressources, des sacs
-- (le MJ, 20 octobre 2026) et les monnaies qui ont une forme (19 octobre
-- 2026). Une monnaie qui n'existe qu'en solde de bourse n'a rien a poser dans
-- une case.
--
-- La regle est ici, et non dans chaque fenetre : la fenetre du joueur,
-- l'atelier du MJ et l'arbitrage du proprietaire la lisent au meme endroit.
-- Elles la recopiaient, et l'une d'elles finissait par ne plus dire la meme
-- chose que les autres.
-- Combien d'emplacements prend une quantite dans un coffre.
--
-- Une entree SANS pile maximale n'en prend qu'UN, quelle que soit la quantite :
-- une bourse d'ecus est une bourse, une poignee d'herbes une poignee. C'est
-- deja ce que la fenetre MONTRE (une seule pile) ; le compte, lui, divisait par
-- une pile de 1, donc cinquante ecus occupaient cinquante emplacements (le MJ,
-- 19 octobre 2026). Quatre fonctions tenaient ces deux regles, et elles n'en
-- disaient pas la meme.
function Coffres.Pile(ref)
    local entree = LCM.Compendium.Resoudre(ref)
    local pile = tonumber(entree and entree.pileMax)
    return pile and math.max(1, math.floor(pile)) or nil
end

function Coffres.Places(ref, quantite)
    quantite = math.max(0, math.floor(tonumber(quantite) or 0))
    if quantite == 0 then return 0 end
    local pile = Coffres.Pile(ref)
    return pile and math.ceil(quantite / pile) or 1
end

local ACCUEILLIS = { objets = true, livres = true, ressources = true, devises = true,
                     sacs = true, accessoires_camping = true }
function Coffres.Accepte(ref)
    local famille, entree = tostring(ref or ""):match("^([%w_]+)/(.+)$")
    if not ACCUEILLIS[famille or ""] then
        return false, "le coffre accepte des objets, des livres, des ressources, des sacs ou des devises."
    end
    if famille == "devises" and not (LCM.Bourse and LCM.Bourse.EstMateriel(entree)) then
        return false, "cette monnaie ne se transporte pas : elle reste dans la bourse."
    end
    if not LCM.Compendium.Resoudre(ref) then return false, "entrée inconnue du compendium." end
    return true
end

Coffres.SUJETS = { definition = "cof", retrait = "cof-", demande = "cof?",
    action = "cof!", etat = "cof+" }
local S = Coffres.SUJETS
local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Moi() return LCM.PlayerId() end
local function Signaler() if Coffres.onChange then pcall(Coffres.onChange) end end
local function RayonDefaut()
    local equilibrage = LCM.Equilibrage or {}
    return tonumber(equilibrage.coffres and equilibrage.coffres.rayon)
        or tonumber(equilibrage.marchands and equilibrage.marchands.rayon) or 4
end
local Positionner

function Coffres.Paquet(definition, points)
    local c = definition.coffre or {}
    local objets = {}
    for _, o in ipairs(c.objets or {}) do
        objets[#objets + 1] = { e = o.entree, q = o.quantite,
            d = (LCM.Livres and LCM.Livres.Definition(o.entree))
                or (LCM.Echange and LCM.Echange.DefinitionObjet(o.entree)) or nil }
    end
    local outils = {}
    for _, o in ipairs(c.outils or {}) do
        outils[#outils + 1] = { e = o.entree, t = o.typeOutil, q = o.quantite, c = o.consomme,
            n = o.consommeQuantite, x = o.expertise,
            d = LCM.Echange and LCM.Echange.DefinitionObjet(o.entree) or nil }
    end
    -- `b` / `t` : le sac ou la tente que ce coffre EST (un sac lache au sol,
    -- Core/SacsAuSol.lua) ; c'est ce qui permet de le ramasser en entier.
    return { i = definition.id, n = definition.label, p = LCM.Recolte.Plier(points),
        c = { s = c.places, v = c.verrous, r = c.reset, y = c.rayon, o = objets,
            x = c.expertises, u = outils, b = c.sac, t = c.tente, j = c.objet and 1 or nil } }
end

function Coffres.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local function importer(ref, definition)
        if type(definition) == "table" then
            if tostring(ref):match("^livres/") and LCM.Livres then
                LCM.Livres.Importer(ref, definition)
            elseif LCM.Echange and LCM.Echange.ImporterObjetPartage then
                LCM.Echange.ImporterObjetPartage({ ref = ref, definition = definition })
            end
        end
    end
    local raw = type(paquet.c) == "table" and paquet.c or {}
    local coffre = { places = math.max(1, math.floor(tonumber(raw.s) or 1)),
        rayon = math.max(0.1, tonumber(raw.y) or RayonDefaut()),
        verrous = math.max(0, math.floor(tonumber(raw.v) or 0)), reset = raw.r == true or raw.r == "true",
        objets = {}, expertises = {}, outils = {},
        sac = Texte(raw.b) ~= "" and Texte(raw.b) or nil,
        tente = Texte(raw.t) ~= "" and Texte(raw.t) or nil,
        -- Un objet pose seul au sol : il se ramasse, il ne s'ouvre pas.
        objet = raw.j ~= nil and raw.j ~= false or nil }
    for _, o in ipairs(type(raw.o) == "table" and raw.o or {}) do
        local ref = Texte(o.e)
        importer(ref, o.d)
        if ref ~= "" then coffre.objets[#coffre.objets + 1] = { entree = ref,
            quantite = math.max(0, math.floor(tonumber(o.q) or 0)) } end
    end
    for _, x in ipairs(type(raw.x) == "table" and raw.x or {}) do
        coffre.expertises[#coffre.expertises + 1] = { id = Texte(x.id),
            dd = math.max(0, math.floor(tonumber(x.dd) or 0)),
            fatigue = math.max(0, math.floor(tonumber(x.fatigue) or 0)),
            usureOutils = x.usureOutils == true or x.usureOutils == "true",
            reverrouillable = x.reverrouillable == true or x.reverrouillable == "true" }
    end
    for _, o in ipairs(type(raw.u) == "table" and raw.u or {}) do
        local ref = Texte(o.e)
        importer(ref, o.d)
        local typeOutil = Texte(o.t)
        if ref ~= "" or typeOutil ~= "" then coffre.outils[#coffre.outils + 1] = {
            entree = ref ~= "" and ref or nil, typeOutil = typeOutil ~= "" and typeOutil or nil,
            quantite = math.max(1, math.floor(tonumber(o.q) or 1)),
            consomme = o.c == true or o.c == "true",
            consommeQuantite = math.max(1, math.floor(tonumber(o.n) or 1)),
            expertise = Texte(o.x) ~= "" and Texte(o.x) or nil } end
    end
    return { id = id, label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Coffre",
        coffre = coffre }, LCM.Recolte.Deplier(paquet.p)
end

function Coffres.Sauver()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local defs, points = {}, {}
    -- Un sac au sol (`sol`) a sa propre sauvegarde, et sa propre garde
    -- (Core/SacsAuSol.lua) : il ne revient pas d'ici apres sa disparition.
    for id, d in pairs(Coffres.definitions) do if d.auteur ~= Moi() and not d.sol then defs[id] = d end end
    for id, p in pairs(Coffres.points) do if defs[p.def] then points[id] = p end end
    LCM.db.coffres = next(defs) and { definitions = defs, points = points } or nil
end

function Coffres.Connaitre(definition, points, auteur)
    if type(definition) ~= "table" or not definition.id then return false end
    definition.auteur = auteur or definition.auteur
    Coffres.definitions[definition.id] = definition
    for id, p in pairs(Coffres.points) do if p.def == definition.id then Coffres.points[id] = nil end end
    for _, p in ipairs(points or {}) do p.def = definition.id; Coffres.points[p.id] = p end
    Coffres.Sauver()
    if Positionner and next(Coffres.points) then Positionner() end
    Signaler()
    return true
end

function Coffres.Oublier(id)
    id = tostring(id or "")
    Coffres.points[id] = nil
    if tostring(Coffres.courant or "") == id then Coffres.courant, Coffres.etat = nil, nil end
    if Coffres.proche and tostring(Coffres.proche.id or "") == id then
        Coffres.proche = nil
        if LCM.UI.Coffre and LCM.UI.Coffre.Proche then LCM.UI.Coffre.Proche(nil) end
    end
    if LCM.UI.Coffre and LCM.UI.Coffre.Retirer then LCM.UI.Coffre.Retirer(id) end
    Coffres.Sauver()
    if Positionner then Positionner() end
    Signaler()
end

function Coffres.Proche(positions)
    local imposees = positions ~= nil
    positions = positions or {}
    local carte = LCM.Recolte.Carte()
    local gps, carteServeur
    if not imposees then
        local D = LCM.DeplacementForce
        local x, y, z
        if D then x, y, z = D.Position("gps", 1) end
        carteServeur = D and D.CarteGPS(1)
        gps = x and z and carteServeur and { x = x, y = y, z = z } or nil
        if not gps then return nil end
    end
    local meilleur, distanceMin
    for _, p in pairs(Coffres.points) do
        local definition = Coffres.definitions[p.def]
        if definition and p.carte == carte and (imposees or not p.mapid or p.mapid == carteServeur) then
            local source = p.source or "?"
            local pos = imposees and positions[source] or gps
            if imposees and pos == nil then
                local x, y, _, z = LCM.Recolte.Position(p.source)
                pos = x and { x = x, y = y, z = z } or false; positions[source] = pos
            end
            if pos then
                local d = LCM.Recolte.Distance(p, pos)
                local rayon = tonumber(definition.coffre and definition.coffre.rayon) or RayonDefaut()
                if d and d <= rayon and (not distanceMin or d < distanceMin) then meilleur, distanceMin = p, d end
            end
        end
    end
    return meilleur
end

-- Le bouton peut se montrer sur la seule proximité horizontale. Une ouverture
-- ou une action exige ensuite une mesure GPS récente des trois axes.
function Coffres.ProcheHorizontal()
    local D = LCM.DeplacementForce
    local x, y
    if D then x, y = D.Position("monde") end
    if not (x and y) then return nil end
    local carte = LCM.Recolte.Carte()
    local meilleur, distanceMin
    for _, p in pairs(Coffres.points) do
        local definition = Coffres.definitions[p.def]
        local px, py = tonumber(p.x), tonumber(p.y)
        if definition and p.carte == carte and p.source ~= "carte" and px and py then
            local distance = math.sqrt((x - px)^2 + (y - py)^2)
            local rayon = tonumber(definition.coffre and definition.coffre.rayon) or RayonDefaut()
            if distance <= rayon and (not distanceMin or distance < distanceMin) then
                meilleur, distanceMin = p, distance
            end
        end
    end
    return meilleur
end

local function GPSFrais()
    local D = LCM.DeplacementForce
    return D and D.Position("gps", 1) and D.CarteGPS(1)
end

local function ApresVerificationGPS(p, poursuivre)
    local D = LCM.DeplacementForce
    if not (D and D.DemanderGPS and D.DemanderGPS(true)) then
        return false, "position .gps indisponible."
    end
    Coffres.attenteGPS = { id = p.id, poursuivre = poursuivre }
    return true
end

function Coffres.ReponseGPS()
    local attente = Coffres.attenteGPS
    if not attente then return end
    Coffres.attenteGPS = nil
    local p = Coffres.points[attente.id]
    if p and Coffres.Proche() == p then
        attente.poursuivre()
    else
        LCM.Alerte("tu es trop loin du coffre, y compris en hauteur.")
    end
    if Positionner then Positionner() end
end

function Coffres.Envoyer(action, donnees)
    local p = Coffres.points[Coffres.courant or ""]
    local d = p and Coffres.definitions[p.def]
    if not d or not d.auteur then return false, "propriétaire du coffre indisponible." end
    if action ~= "fermer" and not Coffres.edition and Coffres.Proche() ~= p then
        if not GPSFrais() and Coffres.ProcheHorizontal() == p then
            return ApresVerificationGPS(p, function() Coffres.Envoyer(action, donnees) end)
        end
        return false, "tu es trop loin du coffre, y compris en hauteur."
    end
    donnees = donnees or {}; donnees.i = p.id; donnees.a = action
    if Coffres.edition then donnees.edition = true end
    -- Un sac au sol dont on est le gardien : on s'arbitre soi-meme.
    if d.sol and d.auteur == Moi() and LCM.SacsAuSol then
        LCM.SacsAuSol.Traiter(Moi(), donnees)
        return true
    end
    if d.auteur == Moi() and LCM.IsMaster() and LCM.CoffresMJ then
        local ok, raison = LCM.CoffresMJ.Traiter(Moi(), donnees)
        if ok == nil then return true end
        return ok, raison
    end
    return LCM.Reseau.Envoyer(S.action, donnees, "WHISPER", d.auteur)
end

function Coffres.Ouvrir(id, edition)
    local p = Coffres.points[tostring(id or "")]
    local d = p and Coffres.definitions[p.def]
    if not d then return false, "coffre inconnu." end
    -- N'IMPORTE QUEL MJ edite le contenu d'un coffre, pas seulement celui qui
    -- l'a pose (le MJ, 20 octobre 2026) : a deux MJ sur une phase, l'autre ne
    -- pouvait rien garnir. Le geste passe toujours par le proprietaire, qui
    -- arbitre et sauvegarde (MJ/Coffres.lua).
    --
    -- Un sac lache au sol reste dehors : il n'a pas de MJ auteur mais un
    -- gardien, et son contenu appartient a quelqu'un.
    if edition and (not LCM.IsMaster() or d.sol) then
        return false, d.sol and "un sac au sol ne s'édite pas : il appartient à quelqu'un."
            or "l'édition d'un coffre est réservée au maître du jeu."
    end
    if not edition and Coffres.Proche() ~= p then
        if not GPSFrais() and Coffres.ProcheHorizontal() == p then
            return ApresVerificationGPS(p, function() Coffres.Ouvrir(id) end)
        end
        return false, "tu es trop loin du coffre, y compris en hauteur."
    end
    if Coffres.courant and Coffres.courant ~= p.id and not Coffres.edition then
        Coffres.Envoyer("fermer")
    end
    Coffres.courant, Coffres.etat, Coffres.edition = p.id, nil, edition == true
    if LCM.UI.Coffre and LCM.UI.Coffre.Ouvrir then LCM.UI.Coffre.Ouvrir(p.id) end
    return Coffres.Envoyer(edition and "editer" or "ouvrir")
end

-- Tout le monde, et pas seulement le groupe : le canal d'addon que
-- Core/Presence.lua rejoint (silencieux, hors des fenetres de discussion), le
-- groupe en repli. Un joueur hors du raid ne recevait rien, et celui qui y
-- entrait devait recharger (le MJ, 20 octobre 2026).
--
-- « Coucou, je suis la » : a l'arrivee, on demande leurs coffres a ceux qui en
-- ont pose, et ils repondent en prive (MJ/Coffres.lua).
function Coffres.Demander()
    if LCM.IsMaster() then return end
    LCM.Reseau.Envoyer(S.demande, {}, LCM.Reseau.TOUS)
end

Positionner = function()
    if not Coffres.horloge then
        local h = CreateFrame("Frame"); h:Hide(); h.reste = 0
        h:SetScript("OnUpdate", function(self, elapsed)
            self.reste = self.reste + (tonumber(elapsed) or 0)
            if self.reste < 0.25 then return end
            self.reste = 0
            local proche = Coffres.Proche()
            if not GPSFrais() then proche = Coffres.ProcheHorizontal() end
            if proche ~= Coffres.proche then
                Coffres.proche = proche
                if LCM.UI.Coffre and LCM.UI.Coffre.Proche then LCM.UI.Coffre.Proche(proche) end
            end
            -- S'eloigner referme le coffre ouvert. Le proprietaire refusait
            -- deja tout geste a distance (Coffres.Agir) : la fenetre restait
            -- ouverte sur un contenu auquel on ne pouvait plus toucher (le MJ,
            -- 20 octobre 2026). L'etal d'un vendeur se refermait deja ainsi.
            --
            -- Verifie a chaque battement, et pas seulement quand le plus
            -- proche CHANGE : une fenetre ouverte doit se fermer meme si la
            -- mesure precedente disait deja « personne ».
            --
            -- L'EDITION du MJ fait exception, comme pour les actions : elle se
            -- mene a distance, sur un coffre pose ailleurs.
            if Coffres.courant and not Coffres.edition
                and not (proche and proche.id == Coffres.courant)
                and LCM.UI.Coffre and LCM.UI.Coffre.Quitter then
                LCM.UI.Coffre.Quitter()
            end
        end)
        Coffres.horloge = h
    end
    if next(Coffres.points) then Coffres.horloge:Show() else Coffres.horloge:Hide() end
end

-- Le canal n'existe pas encore a la connexion : on redemande des qu'il repond.
LCM.WhenReady(function()
    if LCM.Presence and LCM.Presence.QuandCanal then
        LCM.Presence.QuandCanal(function() Coffres.Demander() end)
    end
end)

LCM.WhenReady(function()
    local saved = LCM.db and LCM.db.coffres
    for id, d in pairs(type(saved) == "table" and saved.definitions or {}) do Coffres.definitions[id] = d end
    for id, p in pairs(type(saved) == "table" and saved.points or {}) do
        if Coffres.definitions[p.def] then Coffres.points[id] = p end
    end
    Positionner()
    LCM.Reseau.Ecouter(S.definition, function(expediteur, data)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        local def, points = Coffres.Lire(data)
        if def then Coffres.Connaitre(def, points, expediteur) end
    end)
    -- UN SEUL ecouteur par sujet (Reseau.Ecouter remplace) : la demande va au
    -- gardien d'un sac au sol si c'est le notre, sinon au MJ des coffres. Le
    -- compagnon MJ l'ecoutait lui-meme et aurait ecrase un joueur gardien.
    LCM.Reseau.Ecouter(S.action, function(expediteur, data)
        if not LCM.Reseau.Connu(expediteur) then return end
        if LCM.SacsAuSol and LCM.SacsAuSol.Traiter(expediteur, data) then return end
        if LCM.CoffresMJ then LCM.CoffresMJ.Traiter(expediteur, data) end
    end)
    LCM.Reseau.Ecouter(S.retrait, function(expediteur, data)
        if not LCM.Reseau.Connu(expediteur) then return end
        if data.i then Coffres.Oublier(data.i) end
    end)
    LCM.Reseau.Ecouter(S.etat, function(expediteur, data)
        if tostring(data.i or "") ~= tostring(Coffres.courant or "") then return end
        local point = Coffres.points[Coffres.courant]
        local definition = point and Coffres.definitions[point.def]
        if definition and definition.auteur and definition.auteur ~= expediteur then return end
        Coffres.etat = data
        Signaler()
        if Coffres.onReponse then pcall(Coffres.onReponse, expediteur, data) end
    end)
    LCM.Reseau.Ecouter(S.demande, function(expediteur)
        if not LCM.IsMaster() or not LCM.Reseau.Connu(expediteur) then return end
        LCM.CoffresMJ.Renvoyer(expediteur)
    end)
    if not LCM.IsMaster() then Coffres.Demander() end
end)

LCM.On("GROUP_JOINED", function() if not LCM.IsMaster() then Coffres.Demander() end end)
LCM.On("GROUP_ROSTER_UPDATE", Positionner)

