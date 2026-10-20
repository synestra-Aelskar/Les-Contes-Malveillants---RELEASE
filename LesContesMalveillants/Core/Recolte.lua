-- Les points de recolte, cote aventurier (13 octobre 2026).
--
-- Le MJ pose des points sur la carte (« Miner du fer », ici, ici et ici) ; un
-- aventurier qui marche dessus voit un bouton « Recolter », lance son jet de
-- metier et, s'il reussit, recoit les ressources tirees. Un point limite
-- disparait apres le nombre de recoltes prevu ; les ressources regenerables
-- reviennent apres leur delai.
--
-- Rien de tout cela n'est livre dans l'addon joueur. Le joueur DEMANDE les
-- points a la connexion (« rec? » au groupe) ; ceux qui ont le panneau MJ lui
-- repondent en silence, a lui seul, et le servent aussi des qu'ils le voient
-- arriver. Il GARDE ce qu'on lui a envoye dans sa sauvegarde : on recolte
-- aussi quand le MJ n'est pas la.
--
-- Trois statuts, dans l'ordre (13 octobre 2026) :
--   CREE        le MJ l'a pose, il est la ;
--   EN ATTENTE  un joueur l'a recolte pendant que son MJ etait absent : il a
--               sa part, le point a disparu chez lui, et il le dira au MJ des
--               qu'il le croisera (« rec# ») ;
--   RECOLTE     le MJ l'a note : il ne le renvoie plus jamais, et l'accuse de
--               reception (« rec* ») efface l'attente chez le joueur.
-- Un point en attente n'est jamais recree par une diffusion du MJ qui ne le
-- sait pas encore recolte.
--
-- Quand le MJ est la, il ARBITRE chaque prise : la quantite se tire chez lui,
-- qui retire le point au meme moment — deux joueurs sur le meme filon ne
-- peuvent pas le vider deux fois. Absent, il ne peut pas : deux joueurs qui
-- recoltent le meme point hors de sa presence ont chacun leur part. Un jet
-- rate ne coute rien, on peut retenter.
--
-- Les coordonnees suivent la regle des Lieux : un point retient la SOURCE de
-- position qui l'a pose (monde, carte, .gps) et sa carte, et ne se mesure
-- qu'avec elles. Des yards du monde contre des yards de carte, et l'on
-- recolterait a cent pas du filon.

local _, LCM = ...

local Recolte = {
    -- Ce que les MJ nous ont envoye. definitions[id] et points[id], ou chaque
    -- point porte `def` (l'identifiant de sa definition).
    definitions = {}, points = {},
    -- Les prises demandees au MJ present et pas encore repondues : l'instant
    -- de la demande. En memoire seulement.
    enAttente = {},
    -- Les points recoltes en l'absence de leur MJ, a lui dire :
    -- attente[id] = { a = auteur, d = definition, q = quantite, t = quand }.
    -- En sauvegarde : ils doivent survivre a une deconnexion, c'est tout
    -- l'interet.
    attente = {},
    echecs = {}, -- echecs hors ligne : usages locaux a signaler au MJ
}
LCM.Recolte = Recolte
Recolte.METIER_AUCUN = "__aucun__"

local INTERVALLE = 0.25
-- Une demande au MJ sans reponse au bout de ce delai (il s'est deconnecte
-- entre-temps) n'empeche plus de retenter.
local DELAI_REPONSE = 5

Recolte.SUJETS = {
    definition = "rec",   -- MJ -> joueur(s) : une definition et tous ses points
    retrait    = "rec-",  -- MJ -> groupe   : un point (ou une definition) n'est plus
    demande    = "rec?",  -- joueur -> groupe : envoyez-moi ce que vous avez
    prendre    = "rec!",  -- joueur -> MJ   : j'ai reussi mon jet sur ce point
    reponse    = "rec+",  -- MJ -> joueur   : voici ta part (ou pourquoi non)
    rendre     = "rec~",  -- joueur -> MJ   : je n'ai pas pu ranger, reprends-le
    signaler   = "rec#",  -- joueur -> MJ   : j'ai recolte ceux-la en ton absence
    accuse     = "rec*",  -- MJ -> joueur   : c'est note, oublie-les
    confirmer  = "rec^",  -- joueur -> MJ   : j'ai bien range ma part
    echec      = "recx",  -- joueur -> MJ   : le jet rate consomme une utilisation
}
local S = Recolte.SUJETS

local function Eq()
    return (LCM.Equilibrage and LCM.Equilibrage.recolte) or {}
end

local function Moi() return LCM.PlayerId() end

local function Texte(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Carte()
    local D = LCM.DeplacementForce
    return D and D.Carte and D.Carte() or nil
end

local function Position(source)
    local D = LCM.DeplacementForce
    if not (D and D.Position) then return nil end
    local x, y, z, trouvee = D.Position(source, source == "gps" and 1 or nil)
    if not x then return nil end
    return x, y, trouvee, trouvee ~= "carte" and z or nil
end
Recolte.Position, Recolte.Carte = Position, Carte

-- Un placement interactif exige une altitude reelle. Les coordonnees de carte
-- n'en donnent pas et ne peuvent pas etre utilisees par .worldport.
function Recolte.Position3D()
    -- Comme Arcanum pour un spark : la position serveur d'Epsilon d'abord, avec
    -- son altitude et sa carte, sans UnitPosition ni `.gps`. Sert aux points de
    -- recolte comme aux marchands (Marchands.Placer passe ici).
    local D = LCM.DeplacementForce
    if D and D.EpsilonDisponible and D.EpsilonDisponible() then
        local ex, ey, esource, ez = Position("gps")
        if ex and ez then return ex, ey, esource, ez end
    end
    local x, y, source, z = Position("monde")
    if x and z then return x, y, source, z end
    return Position("gps")
end

function Recolte.Distance(point, position)
    local x, y, z = tonumber(point and point.x), tonumber(point and point.y), tonumber(point and point.z)
    local px, py, pz = tonumber(position and position.x), tonumber(position and position.y), tonumber(position and position.z)
    if not (x and y and z and px and py and pz) then return nil end
    return math.sqrt((px - x)^2 + (py - y)^2 + (pz - z)^2)
end

function Recolte.Rayon(definition)
    return tonumber(definition and definition.rayon) or tonumber(Eq().rayon) or 3
end

function Recolte.Ressources(definition)
    if type(definition.ressources) == "table" then return definition.ressources end
    return { { entree = definition.entree, min = definition.min, max = definition.max,
        chance = 100, regeneration = false } }
end

-- Ce que CE point donne : sa propre liste si le MJ l'a reglee une fois pose
-- (20 octobre 2026), sinon celle de son modele. Le modele « Récolter du
-- minerai » donne le point de depart ; un filon en particulier peut etre plus
-- riche, ou ne donner que du cuivre, sans toucher aux autres.
-- Une liste vide est un point TOUT ETEINT : il ne donne rien (MJ/Recoltes.lua,
-- Effectives). Sans liste, c'est le modele entier.
function Recolte.RessourcesDuPoint(point, definition)
    if type(point) == "table" and type(point.ressources) == "table" then
        return point.ressources
    end
    return Recolte.Ressources(definition)
end

-- Un point que le MJ doit encore regler : rien ne s'y recolte, mais celui qui
-- l'a pose doit le trouver en marchant dessus, pour l'ouvrir.
local function ARegler(p)
    return p.vide == true and LCM.IsMaster and LCM.IsMaster()
end

-- L'etat appartient au point pose, jamais a sa definition partagee.
function Recolte.Disponible(point, definition, maintenant)
    maintenant = maintenant or (time and time()) or 0
    if (tonumber(definition.limite) or 1) > 0
        and (tonumber(point.usages) or 0) >= (tonumber(definition.limite) or 1) then return false end
    for index, ressource in ipairs(Recolte.RessourcesDuPoint(point, definition)) do
        local prochain = point.prochain and tonumber(point.prochain[index])
        local consomme = point.consomme and point.consomme[index]
        if ressource.regeneration then
            if not prochain or prochain <= maintenant then return true end
        elseif not consomme then return true end
    end
    return false
end

function Recolte.Epuise(point, definition)
    if tonumber(definition.limite) == 0 then return false end
    if (tonumber(definition.limite) or 1) > 0
        and (tonumber(point.usages) or 0) >= (tonumber(definition.limite) or 1) then return true end
    for index, ressource in ipairs(Recolte.RessourcesDuPoint(point, definition)) do
        if ressource.regeneration or not (point.consomme and point.consomme[index]) then
            return false
        end
    end
    return true
end

-- Calcule une prise sans modifier le point : le MJ ne la valide qu'apres
-- confirmation du rangement dans le sac.
function Recolte.Tirer(point, definition, maintenant)
    maintenant = maintenant or (time and time()) or 0
    if not Recolte.Disponible(point, definition, maintenant) then return nil end
    local lots, consomme, prochain = {}, {}, {}
    for i, v in pairs(point.consomme or {}) do consomme[i] = v end
    for i, v in pairs(point.prochain or {}) do prochain[i] = v end
    for index, ressource in ipairs(Recolte.RessourcesDuPoint(point, definition)) do
        local disponible = ressource.regeneration
            and (not prochain[index] or prochain[index] <= maintenant)
            or (not ressource.regeneration and not consomme[index])
        if disponible then
            local chance = math.max(0, math.min(100, tonumber(ressource.chance) or 100))
            if chance == 100 or (chance > 0 and LCM.Roll.Des(1, 100) <= chance) then
                if ressource.regeneration then
                    prochain[index] = maintenant + math.max(0, tonumber(ressource.minutes) or 0) * 60
                else
                    consomme[index] = true
                end
                lots[#lots + 1] = { index = index, entree = ressource.entree,
                    quantite = LCM.Roll.Des(tonumber(ressource.min) or 1,
                        tonumber(ressource.max) or tonumber(ressource.min) or 1) }
            end
        end
    end
    return lots, { usages = (tonumber(point.usages) or 0) + 1,
        consomme = consomme, prochain = prochain }
end

-- ===== Les points en une chaine ============================================
-- Comme les Lieux : « id,x,y,source,carte|… ». Une table imbriquee coute une
-- ligne par champ a l'encodeur, et cent points depasseraient de loin ce qu'on
-- veut faire passer par message.

function Recolte.Plier(points)
    local out = {}
    for _, p in ipairs(points or {}) do
        local marques = {}
        for i, v in pairs(p.consomme or {}) do if v then marques[#marques + 1] = tostring(i) end end
        table.sort(marques)
        local delais = {}
        for i, v in pairs(p.prochain or {}) do delais[#delais + 1] = tostring(i) .. ":" .. tostring(v) end
        table.sort(delais)
        out[#out + 1] = string.format("%s,%.2f,%.2f,%s,%s,%d,%s,%s,%s", p.id, p.x, p.y,
            tostring(p.source or ""), p.carte and tostring(p.carte) or "",
            tonumber(p.usages) or 0, table.concat(marques, ":"), table.concat(delais, ":"),
            p.z and string.format("%.2f", p.z) or "")
    end
    return table.concat(out, "|")
end

function Recolte.Deplier(texte)
    local out = {}
    for morceau in tostring(texte or ""):gmatch("[^|]+") do
        local id, x, y, source, carte, usages, marques, delais, z =
            morceau:match("^([^,]+),(-?[%d%.]+),(-?[%d%.]+),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)$")
        if not id then
            id, x, y, source, carte, usages, marques, delais =
                morceau:match("^([^,]+),(-?[%d%.]+),(-?[%d%.]+),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)$")
        end
        if not id then
            id, x, y, source, carte = morceau:match("^([^,]+),(-?[%d%.]+),(-?[%d%.]+),([^,]*),([^,]*)$")
        end
        if id and tonumber(x) and tonumber(y) then
            local p = { id = id, x = tonumber(x), y = tonumber(y), z = tonumber(z), usages = tonumber(usages) or 0,
                source = source ~= "" and source or nil, carte = tonumber(carte),
                consomme = {}, prochain = {} }
            for i in tostring(marques or ""):gmatch("%d+") do p.consomme[tonumber(i)] = true end
            for i, v in tostring(delais or ""):gmatch("(%d+):(%d+)") do p.prochain[tonumber(i)] = tonumber(v) end
            out[#out + 1] = p
        end
    end
    return out
end

-- Une liste de ressources telle qu'elle voyage : avec la definition de chaque
-- objet ou livre, que le joueur n'a peut-etre pas encore.
local function PlierRessources(liste)
    local out = {}
    for _, ressource in ipairs(liste) do
        out[#out + 1] = {
            entree = ressource.entree, min = ressource.min, max = ressource.max,
            chance = ressource.chance, aleatoire = ressource.aleatoire,
            regeneration = ressource.regeneration, minutes = ressource.minutes,
            definition = (LCM.Livres and LCM.Livres.Definition(ressource.entree))
                or (LCM.Echange and LCM.Echange.DefinitionObjet(ressource.entree)) or nil,
        }
    end
    return out
end

local function LireRessources(liste)
    local out = {}
    for _, r in ipairs(liste) do
        local entree = Texte(r.entree)
        if type(r.definition) == "table" then
            if entree:match("^livres/") and LCM.Livres then
                LCM.Livres.Importer(entree, r.definition)
            elseif LCM.Echange and LCM.Echange.ImporterObjetPartage then
                LCM.Echange.ImporterObjetPartage({ ref = entree, definition = r.definition })
            end
        end
        out[#out + 1] = {
            entree = entree, min = tonumber(r.min) or 1,
            max = tonumber(r.max) or tonumber(r.min) or 1,
            chance = tonumber(r.chance) or 100,
            aleatoire = r.aleatoire == true or r.aleatoire == "true",
            regeneration = r.regeneration == true or r.regeneration == "true",
            minutes = tonumber(r.minutes) or 0,
        }
    end
    return out
end

-- Le paquet d'une definition, cles courtes : il part une fois par MJ et par
-- joueur, mais il porte tous ses points. `o` : la liste propre des points
-- que le MJ a regles un par un, par identifiant de point.
function Recolte.Paquet(definition, points)
    local ressources = PlierRessources(Recolte.Ressources(definition))
    local propres
    for _, p in ipairs(points or {}) do
        if type(p.ressources) == "table" and p.ressources[1] then
            propres = propres or {}
            propres[p.id] = PlierRessources(p.ressources)
        end
    end
    return {
        i = definition.id, n = definition.label, e = definition.entree,
        a = definition.min, b = definition.max,
        m = definition.metier, d = definition.dd, r = definition.rayon,
        p = Recolte.Plier(points), l = definition.limite,
        u = ressources, v = definition.metiers,
        f = definition.echecConsomme and true or nil,
        o = propres,
    }
end

-- Le decodeur rend tout en texte : chaque nombre est remis dans son type ici.
function Recolte.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local mini = math.max(1, math.floor(tonumber(paquet.a) or 1))
    local ressources
    if type(paquet.u) == "table" then ressources = LireRessources(paquet.u) end
    local metiers
    if type(paquet.v) == "table" then
        metiers = {}
        for _, choix in ipairs(paquet.v) do
            local id = type(choix) == "table" and Texte(choix.id) or Texte(choix)
            if id ~= "" then
                metiers[#metiers + 1] = { id = id,
                    bonus = type(choix) ~= "table" or choix.bonus == true or choix.bonus == "true" }
            end
        end
    end
    return {
        id = id,
        label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Point de récolte",
        entree = Texte(paquet.e),
        min = mini,
        max = math.max(mini, math.floor(tonumber(paquet.b) or mini)),
        metier = Texte(paquet.m) ~= "" and Texte(paquet.m) or nil,
        metiers = metiers,
        dd = math.max(0, math.floor(tonumber(paquet.d) or 0)),
        rayon = tonumber(paquet.r), limite = tonumber(paquet.l) or 1,
        ressources = ressources,
        echecConsomme = paquet.f == true or paquet.f == "true",
    }, (function()
        local points = Recolte.Deplier(paquet.p)
        if type(paquet.o) == "table" then
            for _, p in ipairs(points) do
                if type(paquet.o[p.id]) == "table" then p.ressources = LireRessources(paquet.o[p.id]) end
            end
        end
        return points
    end)()
end

-- ===== La sauvegarde =======================================================
-- Ce que les MJ nous ont envoye, et ce qu'on a recolte sans eux. Pas ce que le
-- MJ local pose lui-meme : il le tient deja (MJ/Recoltes.lua) et le
-- reconstruit a chaque connexion.
--
-- Ecrit en entier a chaque changement, et efface quand tout est vide : une
-- table vide ne reste pas en sauvegarde.

function Recolte.Sauver()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local moi = Moi()
    local definitions, points = {}, {}
    for id, d in pairs(Recolte.definitions) do
        if d.auteur ~= moi then definitions[id] = d end
    end
    for id, p in pairs(Recolte.points) do
        if definitions[p.def] then points[id] = p end
    end
    if next(definitions) or next(Recolte.attente) or next(Recolte.echecs) then
        LCM.db.recolte = { definitions = definitions, points = points,
            attente = Recolte.attente, echecs = Recolte.echecs }
    else
        LCM.db.recolte = nil
    end
end

function Recolte.Charger()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local garde = type(LCM.db.recolte) == "table" and LCM.db.recolte or nil
    if not garde then return end
    for id, d in pairs(type(garde.definitions) == "table" and garde.definitions or {}) do
        if type(d) == "table" then Recolte.definitions[id] = d end
    end
    for id, p in pairs(type(garde.points) == "table" and garde.points or {}) do
        if type(p) == "table" and Recolte.definitions[p.def] then Recolte.points[id] = p end
    end
    for id, a in pairs(type(garde.attente) == "table" and garde.attente or {}) do
        if type(a) == "table" then Recolte.attente[id] = a end
    end
    for id, a in pairs(type(garde.echecs) == "table" and garde.echecs or {}) do
        if type(a) == "table" then Recolte.echecs[id] = a end
    end
end

-- ===== Ce qu'on connait ====================================================

local function Prevenir()
    Recolte.Sauver()
    Recolte.Regler()
    if Recolte.onChange then pcall(Recolte.onChange) end
end

-- Une definition arrive avec TOUS ses points : ceux qu'on avait pour elle et
-- qu'elle ne porte plus ont ete recoltes ou retires. Ceux qu'on a recoltes en
-- attendant de le dire au MJ ne reviennent pas : il ne le sait pas encore.
function Recolte.Connaitre(definition, points, auteur)
    if type(definition) ~= "table" or not definition.id then return false end
    definition.auteur = auteur or definition.auteur
    Recolte.definitions[definition.id] = definition
    local gardes = {}
    for id, p in pairs(Recolte.points) do
        if p.def == definition.id then
            if Recolte.attente[id] or Recolte.echecs[id] then gardes[id] = p end
            Recolte.points[id] = nil
        end
    end
    for _, p in ipairs(points or {}) do
        if not Recolte.attente[p.id] and not Recolte.echecs[p.id] then
            p.def = definition.id
            Recolte.points[p.id] = p
        end
    end
    for id, p in pairs(gardes) do Recolte.points[id] = p end
    Prevenir()
    return true
end

-- Le statut d'un point, tel qu'on le voit d'ici.
function Recolte.Statut(pointId)
    pointId = tostring(pointId or "")
    if Recolte.attente[pointId] then return "attente" end
    if Recolte.points[pointId] then return "cree" end
    return nil
end

function Recolte.Oublier(pointId)
    if not Recolte.points[tostring(pointId or "")] then return false end
    Recolte.points[tostring(pointId)] = nil
    Prevenir()
    return true
end

function Recolte.OublierDefinition(defId)
    defId = tostring(defId or "")
    Recolte.definitions[defId] = nil
    for id, p in pairs(Recolte.points) do
        if p.def == defId then Recolte.points[id] = nil end
    end
    Prevenir()
end

function Recolte.Nombre()
    local n = 0
    for _ in pairs(Recolte.points) do n = n + 1 end
    return n
end

-- ===== Ou l'on se tient ====================================================

-- Le point le plus proche dans son rayon, ou nil. `positions` sert de cache
-- d'un battement : une position par source, pas une par point.
function Recolte.Proche(positions)
    positions = positions or {}
    local carte = Carte()
    local meilleur, meilleureDistance
    for _, p in pairs(Recolte.points) do
        local definition = Recolte.definitions[p.def]
        if definition and p.carte == carte and (Recolte.Disponible(p, definition) or ARegler(p)) then
            local source = p.source or "?"
            -- De quoi juger si un `.gps` vaut la peine (DeplacementForce.GPSAPortee).
            if source == "gps" then
                positions.cibles = positions.cibles or {}
                positions.cibles[#positions.cibles + 1] = { x = p.x, y = p.y, r = Recolte.Rayon(definition) }
            end
            local pos = positions[source]
            if pos == nil then
                local x, y, _, z = Position(p.source)
                pos = x and { x = x, y = y, z = z } or false
                positions[source] = pos
            end
            if pos then
                local distance = Recolte.Distance(p, pos)
                if distance and distance <= Recolte.Rayon(definition)
                    and (not meilleureDistance or distance < meilleureDistance) then
                    meilleur, meilleureDistance = p, distance
                end
            end
        end
    end
    return meilleur, meilleureDistance
end

function Recolte.ProcheHorizontal()
    local D = LCM.DeplacementForce
    local x, y
    if D then x, y = D.Position("monde") end
    if not (x and y) then return nil end
    local carte, meilleur, distanceMin = Carte()
    for _, p in pairs(Recolte.points) do
        local definition = Recolte.definitions[p.def]
        local px, py = tonumber(p.x), tonumber(p.y)
        if definition and p.carte == carte and p.source ~= "carte" and px and py
            and (Recolte.Disponible(p, definition) or ARegler(p)) then
            local distance = math.sqrt((x - px)^2 + (y - py)^2)
            if distance <= Recolte.Rayon(definition) and (not distanceMin or distance < distanceMin) then
                meilleur, distanceMin = p, distance
            end
        end
    end
    return meilleur
end

function Recolte.Tick()
    local positions = {}
    local proche = Recolte.Proche(positions)
    if positions.gps == false then proche = Recolte.ProcheHorizontal() end
    local avant = Recolte.courant
    Recolte.courant = proche
    if avant ~= proche and Recolte.onProche then pcall(Recolte.onProche, proche) end
end

local horloge
local function Horloge()
    if horloge then return horloge end
    horloge = CreateFrame("Frame", nil, UIParent)
    horloge:Hide()
    horloge.reste = 0
    horloge:SetScript("OnUpdate", function(self, ecoule)
        self.reste = self.reste + (tonumber(ecoule) or 0)
        if self.reste < INTERVALLE then return end
        self.reste = 0
        Recolte.Tick()
    end)
    return horloge
end

-- On ne bat la mesure que s'il y a quelque chose a recolter.
function Recolte.Regler()
    local quelque = next(Recolte.points) ~= nil
    local h = Horloge()
    if quelque then h:Show() else h:Hide() end
    if not quelque and Recolte.courant then
        Recolte.courant = nil
        if Recolte.onProche then pcall(Recolte.onProche, nil) end
    end
    return quelque
end

-- ===== Le jet ==============================================================
-- Un métier de la liste est requis dès qu'elle n'est pas vide. Parmi ceux
-- appris, on garde le meilleur bonus autorisé pour ce point.
function Recolte.ChoisirMetier(entity, definition)
    local choix = type(definition.metiers) == "table" and definition.metiers
        or (definition.metier and { { id = definition.metier, bonus = true } } or {})
    if #choix == 0 then return nil, 0, true end
    local retenu, meilleur, sansMetier = nil, -1, false
    for _, regle in ipairs(choix) do
        local id = type(regle) == "table" and regle.id or regle
        if id == Recolte.METIER_AUCUN then
            sansMetier = true
        elseif id and LCM.Metiers.Get(id) and LCM.Metiers.Palier(entity, id).rang > 0 then
            local bonus = (type(regle) ~= "table" or regle.bonus ~= false)
                and LCM.Metiers.Bonus(entity, id) or 0
            if bonus > meilleur then retenu, meilleur = id, bonus end
        end
    end
    if not retenu and sansMetier then return nil, 0, true end
    if not retenu then return nil, 0, false end
    return retenu, meilleur, true
end

-- D15 + bonus du métier retenu contre le DD (Equilibrage.recolte).
-- Sans métier requis ni DD, il n'y a rien à réussir : on ramasse.

function Recolte.Jet(entity, definition)
    local des = Eq().des or {}
    local metier, bonus, autorise = Recolte.ChoisirMetier(entity, definition)
    if not autorise then return nil, "aucun des métiers requis n'est appris." end
    local jet = LCM.Roll.Des(des.min or 0, des.max or 15)
    local total = jet + bonus
    return { jet = jet, bonus = bonus, metier = metier, total = total, dd = definition.dd,
             reussi = total >= definition.dd, min = des.min or 0, max = des.max or 15 }
end

local function Annoncer(definition, r)
    local metier = r.metier and LCM.Metiers.Get(r.metier)
    local texte = string.format("Récolte : %s (DD %d) : %d  (D%d : %d%s) — %s",
        definition.label, r.dd, r.total, r.max, r.jet,
        metier and string.format(", %s : %+d", metier.label, r.bonus) or "",
        r.reussi and "réussi" or "raté")
    if LCM.Actions and LCM.Actions.Annoncer then LCM.Actions.Annoncer(texte)
    else LCM.Info(texte) end
end

-- Recevoir sa part : ranger, sinon rendre le point au MJ. Un filon vide pour
-- un sac plein serait une ressource perdue pour tout le monde.
function Recolte.Recevoir(pointId, quantite, entree, defId)
    Recolte.enAttente[pointId] = nil
    local definition = Recolte.definitions[defId or ""]
    local lots = type(quantite) == "table" and quantite
        or { { entree = entree, quantite = quantite } }
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    local essai = LCM.Copie(entity)
    for _, lot in ipairs(lots) do
        local ok, raison = LCM.Inventaire.Deposer(essai, lot.entree, tonumber(lot.quantite))
        if not ok then return false, raison or "impossible de ranger." end
    end
    -- Le MJ rediffuse l'etat du point apres confirmation si celui-ci reste
    -- exploitable. Jusque-la, on cache l'ancienne version au joueur.
    Recolte.Oublier(pointId)
    for _, lot in ipairs(lots) do
        local ok, raison = LCM.Inventaire.Deposer(entity, lot.entree, tonumber(lot.quantite))
        if not ok then return false, raison or "impossible de ranger." end
        local ressource = LCM.Compendium and LCM.Compendium.Resoudre
            and LCM.Compendium.Resoudre(lot.entree)
        LCM.Ok(string.format("Tu récoltes %s x%d.",
            (ressource and ressource.label) or (definition and definition.label) or lot.entree,
            tonumber(lot.quantite)))
    end
    if #lots == 0 then LCM.Info("Cette récolte ne donne aucune ressource.") end
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    return true
end


-- Le MJ d'un point est-il la pour arbitrer ? Dans le groupe ET connecte : un
-- membre deconnecte reste dans la liste du groupe, et une demande qui lui part
-- n'aura jamais de reponse.
local function Court(nom) return (tostring(nom or ""):match("^([^%-]+)")) end

function Recolte.EnLigne(nom)
    if not (LCM.Reseau and LCM.Reseau.Connu(nom)) then return false end
    if not (UnitIsConnected and GetNumGroupMembers and UnitName) then return true end
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    for index = 1, GetNumGroupMembers() or 0 do
        local unite = prefixe .. index
        local n = UnitName(unite)
        if n and Court(n) == Court(nom) then return UnitIsConnected(unite) and true or false end
    end
    return true
end

-- Dire a un MJ ce qu'on a recolte en son absence. Rappele chaque fois qu'il
-- se manifeste : tant qu'il n'a pas accuse reception, on redit.
function Recolte.Signaler(auteur)
    local ids = {}
    local comptes = {}
    local echecs = {}
    for id, a in pairs(Recolte.attente) do
        if a.a == auteur then
            ids[#ids + 1] = id
            if a.n then comptes[id] = { n = a.n, c = a.c, p = a.p } end
        end
    end
    for id, a in pairs(Recolte.echecs) do
        if a.a == auteur then echecs[id] = a.n end
    end
    if #ids == 0 and not next(echecs) then return false end
    table.sort(ids)
    return LCM.Reseau.Envoyer(S.signaler,
        { l = table.concat(ids, ","), c = comptes, f = echecs }, "WHISPER", auteur)
end

-- Le geste du joueur. Rend vrai quand la prise est faite (ou demandee au MJ).
function Recolte.Tenter(pointId)
    pointId = tostring(pointId or (Recolte.courant and Recolte.courant.id) or "")
    local p = Recolte.points[pointId]
    if not p then return false, "il n'y a rien à récolter ici." end
    local definition = Recolte.definitions[p.def]
    if not definition then return false, "point inconnu." end
    local maintenant = (GetTime and GetTime()) or 0
    local demande = Recolte.enAttente[pointId]
    if demande and maintenant - (type(demande) == "table" and demande.quand or demande) < DELAI_REPONSE then
        return false, "récolte déjà en cours."
    end
    Recolte.enAttente[pointId] = nil
    if Recolte.Proche() ~= p then
        local D = LCM.DeplacementForce
        if D and not D.Position("gps", 1) and Recolte.ProcheHorizontal() == p
            and D.DemanderGPS and D.DemanderGPS(true) then
            Recolte.attenteGPS = pointId
            return true
        end
        return false, "tu es trop loin, y compris en hauteur."
    end
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end

    if (definition.metiers and #definition.metiers > 0) or definition.metier or definition.dd > 0 then
        local r, raison = Recolte.Jet(entity, definition)
        if not r then return false, raison end
        Annoncer(definition, r)
        if not r.reussi then
            if not definition.echecConsomme then return false, "jet raté : tu peux retenter." end
            if definition.auteur == Moi() then
                if Recolte.Echec then Recolte.Echec(pointId, Moi()) end
            elseif Recolte.EnLigne(definition.auteur) then
                LCM.Reseau.Envoyer(S.echec, { i = pointId }, "WHISPER", definition.auteur)
            else
                p.usages = (tonumber(p.usages) or 0) + 1
                Recolte.echecs[pointId] = { a = definition.auteur, n = p.usages }
                Prevenir()
                LCM.Info("Le MJ sera averti de cet échec à son retour.")
            end
            return false, "jet raté : une récolte a été consommée."
        end
    end

    -- Le MJ lui-meme : il est son propre arbitre, et un message a soi-meme ne
    -- revient pas (Reseau ignore ce qu'on s'envoie).
    if definition.auteur == Moi() then
        if not Recolte.Arbitre then return false, "aucun arbitre." end
        local lots, raison = Recolte.Arbitre(pointId, Moi())
        if not lots then return false, raison or "déjà récolté." end
        local ok
        ok, raison = Recolte.Recevoir(pointId, lots, nil, definition.id)
        if ok and Recolte.Confirmer then Recolte.Confirmer(pointId)
        elseif not ok and Recolte.Restituer then Recolte.Restituer(pointId) end
        return ok, raison
    end

    -- Son MJ est la : il arbitre.
    if Recolte.EnLigne(definition.auteur) then
        Recolte.enAttente[pointId] = { quand = maintenant,
            auteur = definition.auteur, defId = definition.id }
        LCM.Reseau.Envoyer(S.prendre, { i = pointId }, "WHISPER", definition.auteur)
        return true
    end

    -- Il n'est pas la : on recolte tout de suite, et le point passe EN ATTENTE
    -- jusqu'a ce qu'on le lui dise. La quantite se tire ici, faute d'arbitre.
    local lots, etat = Recolte.Tirer(p, definition)
    if not lots then return false, "ce point ne donne plus rien pour le moment." end
    local ok, raison = Recolte.Recevoir(pointId, lots, nil, definition.id)
    if not ok then return false, raison end
    p.usages, p.consomme, p.prochain = etat.usages, etat.consomme, etat.prochain
    Recolte.attente[pointId] = { a = definition.auteur, d = definition.id,
        q = lots[1] and lots[1].quantite or 0, n = p.usages,
        c = p.consomme, p = p.prochain, t = (time and time()) or 0 }
    if not Recolte.Epuise(p, definition) then Recolte.points[pointId] = p end
    Prevenir()
    LCM.Info("Le MJ sera averti de cette récolte à son retour.")
    return true
end

function Recolte.ReponseGPS()
    local pointId = Recolte.attenteGPS
    if not pointId then return end
    Recolte.attenteGPS = nil
    local p = Recolte.points[pointId]
    if not p or Recolte.Proche() ~= p then
        LCM.Alerte("tu es trop loin du point de récolte, y compris en hauteur.")
        return
    end
    local ok, raison = Recolte.Tenter(pointId)
    if not ok and raison then LCM.Alerte(raison) end
end

-- Demander ce qu'il y a : a la connexion, et en entrant dans un groupe.
--
-- A la connexion, le jeu ne connait pas toujours encore le groupe : IsInGroup
-- repond faux un instant, et la demande ne partait pas — le joueur ne recevait
-- rien de ce qui avait ete pose pendant son absence (constate en jeu, 13
-- octobre 2026). Une demande sans groupe reste donc EN SUSPENS, et part des
-- que le groupe se fait connaitre (GROUP_ROSTER_UPDATE).
local demandeEnSuspens = false
function Recolte.Demander()
    local canal = LCM.Reseau.Diffusable()
    if not canal then
        demandeEnSuspens = true
        return false
    end
    demandeEnSuspens = false
    return LCM.Reseau.Envoyer(S.demande, {}, canal)
end
function Recolte.DemandeEnSuspens() return demandeEnSuspens end

-- Qui, dans le groupe, est connecte : { [nom] = vrai | faux }. Un membre
-- deconnecte reste dans la liste du groupe ; c'est son RETOUR qu'on guette.
function Recolte.Connectes()
    local etats = {}
    for _, nom in ipairs((LCM.Combat and LCM.Combat.Membres and LCM.Combat.Membres()) or {}) do
        etats[nom] = Recolte.EnLigne(nom)
    end
    return etats
end

-- Faire quelque chose dans quelques secondes. OnUpdate plutot que C_Timer,
-- comme les Lieux : il existe toujours, et le banc sait le faire avancer.
local plusTard = {}
local minuterie
function Recolte.PlusTard(secondes, fn)
    if not minuterie then
        minuterie = CreateFrame("Frame", nil, UIParent)
        minuterie:SetScript("OnUpdate", function(self, ecoule)
            local maintenant = (GetTime and GetTime()) or 0
            self.cumul = (self.cumul or 0) + (tonumber(ecoule) or 0)
            for index = #plusTard, 1, -1 do
                local t = plusTard[index]
                if self.cumul >= t.quand then
                    table.remove(plusTard, index)
                    pcall(t.fn)
                end
            end
            if #plusTard == 0 then self:Hide() end
        end)
    end
    minuterie.cumul = minuterie.cumul or 0
    plusTard[#plusTard + 1] = { quand = minuterie.cumul + (tonumber(secondes) or 0), fn = fn }
    minuterie:Show()
end

LCM.WhenReady(function()
    -- Ce qu'on savait avant de se deconnecter : de quoi recolter, et ce qu'on
    -- doit encore dire aux MJ.
    Recolte.Charger()
    Recolte.Regler()

    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(S.definition, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.Connu(expediteur) then return end
        local definition, points = Recolte.Lire(donnees)
        if definition then Recolte.Connaitre(definition, points, expediteur) end
        -- Il est la : c'est le moment de lui dire ce qu'on a pris sans lui.
        Recolte.Signaler(expediteur)
    end)

    LCM.Reseau.Ecouter(S.accuse, function(expediteur, donnees)
        local change = false
        for id in tostring(donnees.l or ""):gmatch("[^,]+") do
            local a = Recolte.attente[id]
            if a and a.a == expediteur then
                Recolte.attente[id] = nil
                change = true
            end
        end
        for id, n in pairs(type(donnees.f) == "table" and donnees.f or {}) do
            local a = Recolte.echecs[id]
            if a and a.a == expediteur and tonumber(n) and tonumber(n) >= (tonumber(a.n) or 0) then
                Recolte.echecs[id] = nil
                change = true
            end
        end
        if change then
            Prevenir()
            Recolte.Demander()
        end
    end)

    LCM.Reseau.Ecouter(S.retrait, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local id, defId = Texte(donnees.i), Texte(donnees.d)
        -- Seul celui qui a pose peut retirer.
        if id ~= "" then
            local p = Recolte.points[id]
            local definition = p and Recolte.definitions[p.def]
            if definition and definition.auteur == expediteur then Recolte.Oublier(id) end
        elseif defId ~= "" then
            local definition = Recolte.definitions[defId]
            if definition and definition.auteur == expediteur then Recolte.OublierDefinition(defId) end
        end
    end)

    LCM.Reseau.Ecouter(S.reponse, function(expediteur, donnees)
        local id = Texte(donnees.i)
        local demande = Recolte.enAttente[id]
        if not demande then return end
        local p = Recolte.points[id]
        local definition = Recolte.definitions[(type(demande) == "table" and demande.defId)
            or (p and p.def) or ""]
        if (type(demande) == "table" and demande.auteur ~= expediteur)
            or (definition and definition.auteur ~= expediteur) then return end
        local quantite = tonumber(donnees.q)
        if not quantite and type(donnees.l) ~= "table" then
            Recolte.enAttente[id] = nil
            Recolte.Oublier(id)
            LCM.Alerte(Texte(donnees.n) ~= "" and Texte(donnees.n) or "ce point a déjà été récolté.")
            return
        end
        local lots = type(donnees.l) == "table" and donnees.l or
            (quantite == 0 and {}) or nil
        local ok, raison = Recolte.Recevoir(id, lots or quantite, Texte(donnees.e),
            definition and definition.id)
        if ok then
            LCM.Reseau.Envoyer(S.confirmer, { i = id }, "WHISPER", expediteur)
        else
            LCM.Reseau.Envoyer(S.rendre, { i = id }, "WHISPER", expediteur)
            LCM.Alerte(tostring(raison) .. " Le point reste en place.")
        end
    end)

    -- Le MJ n'a rien a demander : c'est lui qui detient les points.
    if not LCM.IsMaster() then Recolte.Demander() end
end)

-- Le canal de l'addon n'existe pas encore a la connexion : des qu'il repond,
-- on redemande (Core/Presence.lua, 20 octobre 2026).
LCM.WhenReady(function()
    if LCM.Presence and LCM.Presence.QuandCanal then
        LCM.Presence.QuandCanal(function() if not LCM.IsMaster() then Recolte.Demander() end end)
    end
end)

LCM.On("GROUP_JOINED", function()
    if not LCM.IsMaster() then Recolte.Demander() end
end)
LCM.On("GROUP_ROSTER_UPDATE", function()
    if LCM.ready and demandeEnSuspens and not LCM.IsMaster() then Recolte.Demander() end
end)
