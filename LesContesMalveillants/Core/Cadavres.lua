-- Les CADAVRES (le MJ, 3 novembre 2026). Un PNJ tombe a 0 PV en combat, le
-- MJ clique « Mort » : un cadavre apparait a sa position, et qui s'en
-- approche peut le fouiller.
--
-- Jusqu'a quatre sections : Équipé (ce que le PNJ portait), Sac, Naturel et
-- Ventre (son butin, regle dans sa creation). Équipé et Sac se prennent d'un
-- clic ; Naturel demande un jet d'EXTRACTION. Ventre n'en demande un que si
-- son lot porte un DD. Le jet suit celui de la recolte : D15 + bonus du
-- metier, contre ce DD, par les seuls metiers que l'objet accepte. Les
-- TENTATIVES de la ressource comptent : au
-- dernier rate, l'objet disparait du butin (pas du compendium).
--
-- Un seul joueur fouille a la fois : les autres lisent « untel fouille deja,
-- attends ton tour ». Quand il a fini, l'etat part a tous, pour que rien de
-- pris ou de detruit ne reapparaisse ailleurs.
--
-- Le MJ arbitre (LesContesMalveillants_MJ/Cadavres.lua) : il tient le
-- cadavre, le verrou et le contenu. Ici, le cote joueur : ce qu'on connait,
-- ce qu'on demande, ce qu'on recoit. Un cadavre est un objet de SEANCE : il ne
-- va pas dans la base commune.
local _, LCM = ...

local Cadavres = {}
LCM.Cadavres = Cadavres

local function Eq() return LCM.Equilibrage and LCM.Equilibrage.cadavres or {} end
local function Moi() return LCM.PlayerId() end

Cadavres.SECTIONS = {
    { id = "equipe",  label = "Équipé",  jet = false },
    { id = "sacs",    label = "Sac",     jet = false },
    { id = "naturel", label = "Naturel", jet = true },
    { id = "ventre",  label = "Ventre",  jet = true },
}
function Cadavres.Section(id)
    for _, s in ipairs(Cadavres.SECTIONS) do if s.id == id then return s end end
end

Cadavres.SUJETS = {
    annonce = "cad",   -- MJ -> tous    : un cadavre et ce qu'il porte encore
    retrait = "cad-",  -- MJ -> tous    : ce cadavre n'est plus
    demande = "cad?",  -- joueur -> tous : envoyez-moi vos cadavres
    action  = "cad!",  -- joueur -> MJ  : ouvrir, prendre, rendre, fermer
    reponse = "cad+",  -- MJ -> joueur  : voici (ou pourquoi non)
}
local S = Cadavres.SUJETS

-- Ce qu'on connait : id -> { id, nom, icone, x, y, z, source, carte, auteur,
-- fouille = nom ou nil, lots = { { id, section, entree, quantite, label,
-- icone, essais } } }. Le MJ, lui, voit aussi les lots desactives.
Cadavres.connus = {}
-- La fouille en cours chez moi : { id } une fois le MJ d'accord.
Cadavres.fouille = nil
-- Qui arbitre un cadavre qu'on a ouvert, garde meme apres son effacement : la
-- derniere prise efface le cadavre AVANT que sa reponse ne soit rangee, et un
-- objet qu'on ne peut pas ranger doit encore pouvoir lui etre rendu.
Cadavres.ouverts = {}

function Cadavres.Rayon() return tonumber(Eq().rayon) or 4 end

-- ===== Le paquet ===========================================================
-- Cles courtes : un cadavre voyage a chaque changement.

local function DefinitionDe(entree)
    return (LCM.Lisibles and LCM.Lisibles.Definition and LCM.Lisibles.Definition(entree))
        or (LCM.Echange and LCM.Echange.DefinitionObjet and LCM.Echange.DefinitionObjet(entree)) or nil
end
Cadavres.DefinitionDe = DefinitionDe

local function Importer(entree, definition)
    if type(definition) ~= "table" then return end
    if LCM.Lisibles and LCM.Lisibles.Registre and LCM.Lisibles.Registre(entree) then
        LCM.Lisibles.Importer(entree, definition)
    elseif LCM.Echange and LCM.Echange.ImporterObjetPartage then
        LCM.Echange.ImporterObjetPartage({ ref = entree, definition = definition })
    end
end
Cadavres.Importer = Importer

-- `tout` : le MJ garde les lots desactives ; les joueurs ne les voient pas.
function Cadavres.Paquet(c, tout)
    local lots = {}
    for _, lot in ipairs(c.lots or {}) do
        if tout or lot.actif ~= false then
            lots[#lots + 1] = { k = lot.id, s = lot.section, e = lot.entree, q = lot.quantite,
                n = lot.label, ic = lot.icone, t = lot.essais, d = lot.dd,
                a = lot.actif == false and 0 or nil }
        end
    end
    return { i = c.id, n = c.nom, ic = c.icone, x = c.x, y = c.y, z = c.z, so = c.source,
             ca = c.carte, au = c.auteur, f = c.fouille and c.fouille.par or nil, l = lots }
end

function Cadavres.Lire(p)
    local id = tostring(p and p.i or "")
    if id == "" then return nil end
    local lots = {}
    for _, l in ipairs(type(p.l) == "table" and p.l or {}) do
        lots[#lots + 1] = { id = tonumber(l.k) or l.k, section = tostring(l.s or ""), entree = tostring(l.e or ""),
            quantite = math.max(1, math.floor(tonumber(l.q) or 1)), label = l.n and tostring(l.n) or nil,
            icone = l.ic, essais = tonumber(l.t) or 0, dd = tonumber(l.d),
            actif = not (l.a ~= nil and tonumber(l.a) == 0) }
    end
    return { id = id, nom = tostring(p.n or "Cadavre"), icone = p.ic, x = tonumber(p.x), y = tonumber(p.y),
             z = tonumber(p.z), source = p.so and tostring(p.so) or nil, carte = tonumber(p.ca),
             auteur = tostring(p.au or ""), fouille = (p.f and tostring(p.f) ~= "") and tostring(p.f) or nil,
             lots = lots }
end

-- ===== Ce qu'on connait ====================================================

function Cadavres.Connaitre(c)
    if not c then return end
    Cadavres.connus[c.id] = c
    if Cadavres.onChange then LCM.Proteger("cadavre", Cadavres.onChange, c.id) end
end

function Cadavres.Oublier(id)
    id = tostring(id or "")
    Cadavres.connus[id] = nil
    if Cadavres.fouille and Cadavres.fouille.id == id then Cadavres.fouille = nil end
    if Cadavres.onChange then LCM.Proteger("cadavre", Cadavres.onChange, id) end
end

-- Les lots qu'on voit d'un cadavre, dans une section.
function Cadavres.Lots(c, section, tout)
    local out = {}
    for _, lot in ipairs(c and c.lots or {}) do
        if lot.section == section and (tout or lot.actif ~= false) then out[#out + 1] = lot end
    end
    return out
end

function Cadavres.Vide(c)
    for _, lot in ipairs(c and c.lots or {}) do if lot.actif ~= false then return false end end
    return true
end

-- Le cadavre le plus proche, dans son rayon. Meme mesure que la recolte : la
-- position de la meme source, en 3D, sur la meme carte.
function Cadavres.Proche()
    local R = LCM.Recolte
    if not (R and R.Position and R.Distance) then return nil end
    local carte = R.Carte and R.Carte() or nil
    local positions, meilleur, meilleure = {}, nil, nil
    for _, c in pairs(Cadavres.connus) do
        if (c.carte == nil or c.carte == carte) and (not Cadavres.Vide(c) or LCM.IsMaster()) then
            local source = c.source or "?"
            local pos = positions[source]
            if pos == nil then
                local x, y, _, z = R.Position(c.source)
                pos = x and { x = x, y = y, z = z } or false
                positions[source] = pos
            end
            local d = pos and R.Distance(c, pos)
            if d and d <= Cadavres.Rayon() and (not meilleure or d < meilleure) then
                meilleur, meilleure = c, d
            end
        end
    end
    return meilleur, meilleure
end

-- ===== Le jet d'extraction =================================================
-- Le ventre ne demande un jet que si son lot porte un DD explicite.
function Cadavres.DD(lot, element)
    if not lot then return nil end
    if lot.section == "ventre" then return tonumber(lot.dd) end
    if lot.section == "naturel" then
        element = element or (LCM.Compendium and LCM.Compendium.Resoudre and LCM.Compendium.Resoudre(lot.entree))
        return tonumber(element and element.dd) or 0
    end
    return nil
end

-- Celui de la recolte : D15 + bonus du meilleur metier APPRIS parmi ceux que
-- la ressource accepte. Sans metier coche sur la ressource, aucun bonus ; si
-- elle en exige et qu'on n'en a aucun, on ne tente pas — et on le dit.
function Cadavres.Jet(entity, lot)
    local element = LCM.Compendium and LCM.Compendium.Resoudre and LCM.Compendium.Resoudre(lot.entree)
    local dd = Cadavres.DD(lot, element)
    if dd == nil then return nil, "aucun jet requis pour cet objet." end
    local metiers = element and type(element.metiers) == "table" and element.metiers[1] and element.metiers or nil
    local metier, bonus = nil, 0
    if metiers then
        for _, id in ipairs(metiers) do
            if LCM.Metiers.Get(id) and LCM.Metiers.Palier(entity, id).rang > 0 then
                local b = LCM.Metiers.Bonus(entity, id)
                if not metier or b > bonus then metier, bonus = id, b end
            end
        end
        if not metier then
            local noms = {}
            for _, id in ipairs(metiers) do noms[#noms + 1] = (LCM.Metiers.Get(id) or {}).label or id end
            return nil, "il faut savoir l'extraire : " .. table.concat(noms, ", ") .. "."
        end
    end
    local des = (LCM.Equilibrage and LCM.Equilibrage.recolte and LCM.Equilibrage.recolte.des) or {}
    local jet = LCM.Roll.Des(des.min or 0, des.max or 15)
    return { jet = jet, bonus = bonus, total = jet + bonus, metier = metier, dd = dd,
             max = des.max or 15, reussi = jet + bonus >= dd }
end

-- ===== Les demandes ========================================================

-- Le MJ s'arbitre lui-meme : un message a soi ne revient pas.
local function Envoyer(c, donnees)
    if c.auteur == Moi() or c.auteur == "" then
        if Cadavres.Arbitre then
            local reponse = Cadavres.Arbitre(Moi(), donnees)
            if reponse and Cadavres.Recevoir then Cadavres.Recevoir(reponse) end
        end
        return true
    end
    return LCM.Reseau.Envoyer(S.action, donnees, "WHISPER", c.auteur)
end

function Cadavres.Ouvrir(id)
    local c = Cadavres.connus[tostring(id or "")]
    if not c then return false, "ce cadavre n'est plus là." end
    if c.fouille and c.fouille ~= Moi() then
        return false, string.format("%s fouille déjà ce cadavre : attends ton tour.", tostring(c.fouille))
    end
    Cadavres.ouverts[c.id] = { id = c.id, auteur = c.auteur }
    Envoyer(c, { i = c.id, a = "ouvrir" })
    return true
end

-- Prendre un lot (Équipé, Sac) ou l'extraire (Naturel, Ventre) : le jet se
-- fait ici, le MJ juge sur le total.
function Cadavres.Prendre(id, lotId)
    local c = Cadavres.connus[tostring(id or "")]
    if not c then return false, "ce cadavre n'est plus là." end
    if not (Cadavres.fouille and Cadavres.fouille.id == c.id) then return false, "ouvre d'abord le cadavre." end
    local lot
    for _, l in ipairs(c.lots) do if l.id == lotId then lot = l end end
    if not lot then return false, "cet objet n'est plus là." end
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    -- La place dans le sac, AVANT de demander : un objet pris puis rendu
    -- ferait un aller-retour pour rien.
    local essai = LCM.Copie(entity)
    local ok, raison = LCM.Inventaire.Deposer(essai, lot.entree, lot.quantite)
    if not ok then return false, raison or "pas de place pour le ranger." end
    local donnees = { i = c.id, a = "prendre", l = lot.id }
    local section = Cadavres.Section(lot.section)
    if Cadavres.DD(lot) ~= nil then
        local r, refus = Cadavres.Jet(entity, lot)
        if not r then return false, refus end
        donnees.t, donnees.m = r.total, r.metier
        local texte = string.format("Extraction : %s (DD %d) : %d  (D%d : %d%s) — %s",
            tostring(lot.label or lot.entree), r.dd, r.total, r.max, r.jet,
            r.metier and string.format(", %s : %+d", LCM.Metiers.Get(r.metier).label, r.bonus) or "",
            r.reussi and "réussi" or "raté")
        if LCM.Actions and LCM.Actions.Annoncer then LCM.Actions.Annoncer(texte) else LCM.Info(texte) end
        Cadavres.jets = Cadavres.jets or {}
        Cadavres.jets[c.id .. ":" .. tostring(lot.id)] = { metier = r.metier, dd = r.dd }
    end
    Envoyer(c, donnees)
    return true
end

function Cadavres.Fermer(id)
    local c = Cadavres.connus[tostring(id or "")]
    if Cadavres.fouille and Cadavres.fouille.id == tostring(id or "") then Cadavres.fouille = nil end
    if not c then return false end
    Envoyer(c, { i = c.id, a = "fermer" })
    return true
end

-- ===== Les reponses ========================================================

-- Ranger ce qu'on a obtenu ; s'il n'y a plus de place, le rendre au cadavre.
local function Ranger(c, r)
    Importer(r.e, r.d)
    local entity = LCM.Entities.Self()
    local ok = entity and LCM.Inventaire.Deposer(entity, r.e, tonumber(r.q) or 1)
    if not ok then
        Envoyer(c, { i = c.id, a = "rendre", e = r.e, q = r.q, s = r.s, n = r.n, ic = r.ic })
        LCM.Alerte("pas de place : l'objet reste sur le cadavre.")
        return
    end
    local element = LCM.Compendium and LCM.Compendium.Resoudre and LCM.Compendium.Resoudre(r.e)
    LCM.Ok(string.format("Tu prends %s x%d sur le cadavre.", (element and element.label) or tostring(r.n or r.e),
        tonumber(r.q) or 1))
    -- L'XP d'une extraction reussie, comme une recolte : la ressource et
    -- son DD, au metier qui a servi.
    local jet = Cadavres.jets and Cadavres.jets[c.id .. ":" .. tostring(r.k)]
    if jet and LCM.Recolte and LCM.Recolte.XPGagnee then
        Cadavres.jets[c.id .. ":" .. tostring(r.k)] = nil
        local xp, metierId = LCM.Recolte.XPGagnee(entity, jet, { { entree = r.e, quantite = r.q } })
        if metierId and xp > 0 then
            LCM.Metiers.Gagner(entity, metierId, xp)
            LCM.Ok(string.format("+%d XP de %s.", xp, LCM.Metiers.Get(metierId).label))
        end
    end
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
end

function Cadavres.Recevoir(r)
    local id = tostring(r and r.i or "")
    local c = Cadavres.connus[id]
    local arbitre = c or Cadavres.ouverts[id]
    if r.refus then LCM.Alerte(tostring(r.refus)) end
    if r.etat then
        c = Cadavres.Lire(r.etat)
        if c then Cadavres.Connaitre(c) end
    end
    if r.ouvert and c then
        Cadavres.fouille = { id = c.id }
    end
    if r.donne and arbitre then Ranger(arbitre, r.donne) end
    if r.rate then
        LCM.Info(r.reste and string.format("Extraction ratée : encore %d tentative(s).", tonumber(r.reste) or 0)
            or "Extraction ratée : tu peux retenter.")
    end
    if r.detruit then
        LCM.Alerte(string.format("Vous avez détruit 1 %s.", tostring(r.detruit)))
    end
    if r.ferme then
        if Cadavres.fouille and Cadavres.fouille.id == id then Cadavres.fouille = nil end
        Cadavres.ouverts[id] = nil
    end
    if Cadavres.onChange then LCM.Proteger("cadavre", Cadavres.onChange, id) end
end

function Cadavres.Demander()
    local canal = LCM.Reseau.Diffusable()
    if not canal then return false end
    return LCM.Reseau.Envoyer(S.demande, {}, canal)
end

-- ===== Le battement ========================================================

local function Tick()
    local proche = Cadavres.Proche()
    if proche ~= Cadavres.courant then
        Cadavres.courant = proche
        if Cadavres.onProche then LCM.Proteger("cadavre", Cadavres.onProche, proche) end
    end
end
Cadavres.Tick = Tick

LCM.WhenReady(function()
    if CreateFrame then
        local h = CreateFrame("Frame")
        h.reste = 0
        h:SetScript("OnUpdate", function(self, ecoule)
            self.reste = self.reste + (tonumber(ecoule) or 0)
            if self.reste < 0.25 then return end
            self.reste = 0
            Tick()
        end)
        Cadavres.horloge = h
    end
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end
    LCM.Reseau.Ecouter(S.annonce, function(expediteur, donnees)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        local c = Cadavres.Lire(donnees)
        if not c then return end
        c.auteur = expediteur
        Cadavres.Connaitre(c)
    end)
    LCM.Reseau.Ecouter(S.retrait, function(expediteur, donnees)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        local c = Cadavres.connus[tostring(donnees.i or "")]
        if c and c.auteur == expediteur then Cadavres.Oublier(c.id) end
    end)
    LCM.Reseau.Ecouter(S.reponse, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local c = Cadavres.connus[tostring(donnees.i or "")]
        if c and c.auteur ~= expediteur then return end
        Cadavres.Recevoir(donnees)
    end)
    Cadavres.Demander()
end)
