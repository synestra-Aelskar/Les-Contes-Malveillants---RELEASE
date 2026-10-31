-- Les panneaux d'affichage (31 octobre 2026), cote aventurier.
--
-- Un panneau est un SUPPORT (bois, pierre, terminal… : Data/Affichages.lua)
-- et des AFFICHES punaisees dessus — un titre, un texte, une image — pour une
-- quete, une information, un avis. Le MJ le construit et le pose dans
-- l'atelier « Affichage » (Systeme > Interactions) ; l'aventurier qui se
-- tient devant voit « Lire » et ouvre le panneau.
--
-- La meme procedure que les vendeurs (Core/Marchands.lua), en plus simple :
-- un panneau ne se consomme pas et n'a pas de stock, donc pas d'arbitre.
-- Rien n'est livre dans l'addon joueur : le joueur demande les panneaux a la
-- connexion, le MJ les lui envoie (et a chaque arrivant, et a chaque pose), et
-- le joueur les garde dans sa sauvegarde.
local _, LCM = ...

local Affichages = {
    -- definitions[id] = { id, label, auteur, support, affiches = { {titre, texte, image} } }
    -- points[id] = { id, def, x, y, z, source, carte, auteur }
    definitions = {}, points = {},
}
LCM.Affichages = Affichages

local INTERVALLE = 0.25

Affichages.SUJETS = {
    definition = "aff",   -- MJ -> joueur(s) : un panneau, ses affiches et ses emplacements
    retrait    = "aff-",  -- MJ -> groupe   : un emplacement (ou un panneau) n'est plus
    demande    = "aff?",  -- joueur -> groupe : envoyez-moi vos panneaux
}
local S = Affichages.SUJETS

local function Eq() return (LCM.Equilibrage and LCM.Equilibrage.affichages) or {} end
local function Moi() return LCM.PlayerId() end
local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function Affichages.Rayon() return tonumber(Eq().rayon) or 4 end

-- ===== Les supports ========================================================

function Affichages.Supports() return LCM.AffichagesSupports or {} end
function Affichages.Support(id)
    if id == "provisoire" then id = "bois" end
    for _, s in ipairs(Affichages.Supports()) do if s.id == id then return s end end
    return Affichages.Supports()[1]
end

function Affichages.Themes() return LCM.AffichagesThemes or {} end
function Affichages.Polices() return LCM.AffichagesPolices or {} end
function Affichages.Theme(id)
    for _, theme in ipairs(Affichages.Themes()) do if theme.id == id then return theme end end
    return Affichages.Themes()[1]
end
function Affichages.Police(id)
    for _, police in ipairs(Affichages.Polices()) do if police.id == id then return police end end
    return Affichages.Polices()[1]
end

-- Ce qu'un panneau porte, verifie. Partage par le constructeur du MJ
-- (MJ/Points.lua, nature « affichage ») et par ce qui arrive du reseau.
-- `Erreur(message)` leve ; rend { support, affiches }.
function Affichages.Normaliser(source, Erreur)
    source = type(source) == "table" and source or {}
    local eq = Eq()
    local maxAffiches = tonumber(eq.maxAffiches) or 12
    local titreMax, texteMax = tonumber(eq.titreMax) or 80, tonumber(eq.texteMax) or 2000
    local support = Texte(source.support)
    if support == "provisoire" then support = "bois" end
    local connu = false
    for _, s in ipairs(Affichages.Supports()) do if s.id == support then connu = true end end
    if support ~= "" and not connu then
        Erreur("support de panneau inconnu (" .. support .. ")")
    end
    local affiches = {}
    local liste = type(source.affiches) == "table" and source.affiches or {}
    if #liste > maxAffiches then Erreur(maxAffiches .. " affiches au plus sur un panneau") end
    for i, a in ipairs(liste) do
        if type(a) ~= "table" then Erreur("affiche " .. i .. " illisible") end
        local titre, texte = Texte(a.titre), tostring(a.texte or "")
        if titre == "" then Erreur("l'affiche " .. i .. " n'a pas de titre") end
        if #titre > titreMax then Erreur("affiche " .. i .. " : titre trop long (" .. titreMax .. ")") end
        if #texte > texteMax then Erreur("affiche " .. i .. " : texte trop long (" .. texteMax .. ")") end
        local image = Texte(a.image)
        local theme = Affichages.Theme(a.theme)
        local police = Affichages.Police(a.police or theme.police)
        if a.theme and a.theme ~= theme.id then Erreur("affiche " .. i .. " : thème inconnu") end
        if a.police and a.police ~= police.id then Erreur("affiche " .. i .. " : écriture inconnue") end
        -- Une affiche peut porter une CARTE du compendium (31 octobre 2026) :
        -- on la consulte sur le panneau. Chez le MJ, la carte est dans son
        -- registre ; chez le joueur, elle arrive avec le panneau (`carteDef`,
        -- aplatie), parce que les cartes ne sont pas livrees aux joueurs.
        local carte, carteDef = Texte(a.carte), nil
        if carte ~= "" then
            if type(a.carteDef) == "table" then
                local ok = LCM.Cartes and pcall(LCM.Cartes.Construire, a.carteDef)
                if not ok or tostring(a.carteDef.id or "") ~= carte then
                    Erreur("affiche " .. i .. " : carte illisible (" .. carte .. ")")
                end
                carteDef = a.carteDef
            end
            -- Pas de « carte inconnue » ici : une carte supprimee (ou chargee
            -- apres les points) ferait tomber le panneau ENTIER, comme le
            -- coffre qui disparaissait pour un type d'outil supprime. Le lien
            -- se resout a la lecture ; une carte disparue ne s'ouvre plus.
        end
        affiches[i] = { titre = titre, texte = texte, image = image ~= "" and image or nil,
            carte = carte ~= "" and carte or nil, carteDef = carteDef,
            theme = theme.id, police = a.police and police.id or nil }
    end
    return { support = connu and support or (Affichages.Supports()[1] or {}).id, affiches = affiches }
end

-- ===== Le paquet d'un panneau ==============================================
-- Les affiches en table imbriquee, les emplacements en une chaine (comme la
-- recolte et les vendeurs). Cles courtes : le paquet part par morceaux.

function Affichages.Paquet(definition, points)
    local a = {}
    for _, affiche in ipairs((definition.affichage or definition).affiches or {}) do
        -- La carte part avec sa definition : le joueur n'en a pas d'autre.
        local carte = affiche.carte and (affiche.carteDef
            or (LCM.Cartes and LCM.Cartes.Definition("cartes/" .. affiche.carte))) or nil
        a[#a + 1] = { t = affiche.titre, x = affiche.texte, m = affiche.image, c = carte,
            h = affiche.theme, f = affiche.police }
    end
    return { i = definition.id, n = definition.label,
        s = (definition.affichage or definition).support, a = a,
        p = LCM.Recolte.Plier(points) }
end

function Affichages.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local affiches = {}
    for _, a in ipairs(type(paquet.a) == "table" and paquet.a or {}) do
        if type(a) == "table" then
            affiches[#affiches + 1] = { titre = Texte(a.t), texte = tostring(a.x or ""), image = a.m,
                theme = a.h, police = a.f,
                carte = type(a.c) == "table" and a.c.id or nil, carteDef = type(a.c) == "table" and a.c or nil }
        end
    end
    local ok, propre = pcall(Affichages.Normaliser, { support = paquet.s, affiches = affiches },
        function(message) error(message, 0) end)
    if not ok then
        LCM.Alerte("panneau reçu illisible (" .. id .. ") : " .. tostring(propre))
        return nil
    end
    local definition = { id = id, label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Panneau",
        support = propre.support, affiches = propre.affiches }
    return definition, LCM.Recolte.Deplier(paquet.p)
end

-- ===== Ce qu'on connait ====================================================

function Affichages.Auteur(p)
    if not p then return nil end
    local d = Affichages.definitions[p.def]
    return p.auteur or (d and d.auteur) or nil
end

-- Ce que les autres ont pose reste connu apres /reload ; ce que J'AI pose,
-- non : il vit dans ma sauvegarde de MJ (MJ/Affichages.lua).
function Affichages.Sauver()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local moi = Moi()
    local definitions, points = {}, {}
    for id, p in pairs(Affichages.points) do
        local d = Affichages.definitions[p.def]
        if d and Affichages.Auteur(p) ~= moi then points[id], definitions[p.def] = p, d end
    end
    LCM.db.panneaux = next(definitions) and { definitions = definitions, points = points } or nil
end

function Affichages.Charger()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local garde = type(LCM.db.panneaux) == "table" and LCM.db.panneaux or nil
    if not garde then return end
    for id, d in pairs(type(garde.definitions) == "table" and garde.definitions or {}) do
        if type(d) == "table" then Affichages.definitions[id] = d end
    end
    for id, p in pairs(type(garde.points) == "table" and garde.points or {}) do
        local d = type(p) == "table" and Affichages.definitions[p.def]
        if d then p.auteur = p.auteur or d.auteur; Affichages.points[id] = p end
    end
end

local function Prevenir()
    Affichages.Sauver()
    Affichages.Regler()
    if Affichages.onChange then LCM.Proteger("panneau", Affichages.onChange) end
end
Affichages.Prevenir = Prevenir

-- `points` : TOUS les emplacements de ce panneau que `auteur` a poses. Ceux
-- d'un autre MJ ne bougent pas.
function Affichages.Connaitre(definition, points, auteur)
    if type(definition) ~= "table" or not definition.id then return false end
    auteur = auteur or definition.auteur
    definition.auteur = auteur
    Affichages.definitions[definition.id] = definition
    for id, p in pairs(Affichages.points) do
        if p.def == definition.id and Affichages.Auteur(p) == auteur then Affichages.points[id] = nil end
    end
    for _, p in ipairs(points or {}) do
        p.def, p.auteur = definition.id, auteur
        Affichages.points[p.id] = p
    end
    Prevenir()
    return true
end

function Affichages.Oublier(pointId)
    if not Affichages.points[tostring(pointId or "")] then return false end
    Affichages.points[tostring(pointId)] = nil
    Prevenir()
    return true
end

function Affichages.OublierDefinition(defId)
    defId = tostring(defId or "")
    Affichages.definitions[defId] = nil
    for id, p in pairs(Affichages.points) do
        if p.def == defId then Affichages.points[id] = nil end
    end
    Prevenir()
end

-- ===== Ou l'on se tient ====================================================
-- Comme un vendeur : en 3D quand l'altitude est connue (Recolte.Distance),
-- a plat sinon.

function Affichages.Proche()
    local carte = LCM.Recolte.Carte()
    local positions = {}
    local meilleur, meilleureDistance
    for _, p in pairs(Affichages.points) do
        if Affichages.definitions[p.def] and p.carte == carte then
            local source = p.source or "?"
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
                if distance and distance <= Affichages.Rayon()
                    and (not meilleureDistance or distance < meilleureDistance) then
                    meilleur, meilleureDistance = p, distance
                end
            end
        end
    end
    return meilleur, meilleureDistance
end

function Affichages.Tick()
    local proche = Affichages.Proche()
    local avant = Affichages.courant
    Affichages.courant = proche
    if avant ~= proche and Affichages.onProche then
        LCM.Proteger("panneau proche", Affichages.onProche, proche)
    end
end

-- OnUpdate plutot que C_Timer : un cadre existe toujours, et le banc sait le
-- faire avancer. Il ne bat que s'il y a des panneaux connus.
local horloge
function Affichages.Regler()
    if not horloge then
        horloge = CreateFrame("Frame", nil, UIParent)
        horloge:Hide()
        horloge.reste = 0
        horloge:SetScript("OnUpdate", function(self, ecoule)
            self.reste = self.reste + (tonumber(ecoule) or 0)
            if self.reste < INTERVALLE then return end
            self.reste = 0
            Affichages.Tick()
        end)
    end
    local quelque = next(Affichages.points) ~= nil
    if quelque then horloge:Show() else horloge:Hide() end
    if not quelque and Affichages.courant then
        Affichages.courant = nil
        if Affichages.onProche then LCM.Proteger("panneau proche", Affichages.onProche, nil) end
    end
    return quelque
end

-- ===== Arracher la carte d'une affiche =====================================
-- La carte liee a une affiche passe dans l'inventaire (31 octobre 2026). Une
-- fois par personnage et par affiche : la carte reste au panneau pour les
-- autres, sans arbitre a consulter. Sa definition est importee comme celle
-- d'une carte trouvee dans un coffre (Cartes.Importer) : elle se relit
-- ensuite depuis l'inventaire, meme hors de vue du panneau.

local function CleArrachage(pointId, definition, index, carteId)
    return table.concat({ tostring(pointId or ("apercu:" .. tostring(definition.id))),
        tostring(index), tostring(carteId) }, "#")
end

function Affichages.DejaArrachee(pointId, definition, index)
    local affiche = definition and definition.affiches and definition.affiches[index]
    if not (affiche and affiche.carte) then return false end
    local garde = LCM.charDb and LCM.charDb.cartesArrachees
    return type(garde) == "table" and garde[CleArrachage(pointId, definition, index, affiche.carte)] == true
end

-- Rend true, ou false et la raison.
function Affichages.Arracher(pointId, definition, index)
    local affiche = definition and definition.affiches and definition.affiches[index]
    if not (affiche and affiche.carte) then return false, "cette affiche ne porte pas de carte." end
    if Affichages.DejaArrachee(pointId, definition, index) then
        return false, "tu as déjà arraché cette carte."
    end
    local Cartes = LCM.Cartes
    local ref = "cartes/" .. affiche.carte
    -- Le MJ a la carte dans son registre ; le joueur l'importe depuis ce que
    -- le panneau a apporte.
    if not Cartes.Get(affiche.carte) then
        local def = affiche.carteDef
        if not (def and Cartes.Importer(ref, def)) then return false, "cette carte n'est plus lisible." end
    end
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    local ok, raison = LCM.Inventaire.Deposer(entity, ref, 1)
    if not ok then return false, raison or "impossible de la ranger." end
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    LCM.charDb.cartesArrachees = type(LCM.charDb.cartesArrachees) == "table" and LCM.charDb.cartesArrachees or {}
    LCM.charDb.cartesArrachees[CleArrachage(pointId, definition, index, affiche.carte)] = true
    local carte = Cartes.Get(affiche.carte)
    LCM.Ok(string.format("Carte arrachée : %s.", carte and carte.label or affiche.carte))
    return true
end

-- ===== Le reseau ===========================================================

function Affichages.Demander()
    local canal = LCM.Reseau.Diffusable()
    if not canal then return false end
    return LCM.Reseau.Envoyer(S.demande, {}, canal)
end

LCM.WhenReady(function()
    Affichages.Charger()
    Affichages.Regler()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(S.definition, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.Connu(expediteur) then return end
        local definition, points = Affichages.Lire(donnees)
        if definition then Affichages.Connaitre(definition, points, expediteur) end
    end)

    LCM.Reseau.Ecouter(S.retrait, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local id, defId = Texte(donnees.i), Texte(donnees.d)
        if id ~= "" then
            if Affichages.Auteur(Affichages.points[id]) == expediteur then Affichages.Oublier(id) end
        elseif defId ~= "" then
            -- SES panneaux de ce modele, pas ceux d'un autre MJ.
            local reste = false
            for pid, p in pairs(Affichages.points) do
                if p.def == defId then
                    if Affichages.Auteur(p) == expediteur then Affichages.points[pid] = nil else reste = true end
                end
            end
            if reste then Prevenir() else Affichages.OublierDefinition(defId) end
        end
    end)

    Affichages.Demander()
end)
