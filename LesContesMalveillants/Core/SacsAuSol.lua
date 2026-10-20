-- Les sacs laches au sol (16 octobre 2026).
--
-- Glisser un sac (ou une tente) hors de l'inventaire le pose au sol, la ou
-- l'on se tient, AVEC tout ce qu'il contient : « Sac de gros de Blud'Sh'Idah ».
-- N'importe qui peut l'ouvrir, y prendre quelques objets, ou le ramasser en
-- entier pour se l'equiper.
--
-- Un coffre est arbitre par le MJ qui l'a pose. Or n'importe qui peut lacher
-- un sac, MJ present ou non. Tant qu'aucun MJ n'est la, le sac au sol est une
-- donnee « fantome » (decision du MJ, le meme jour) :
--   * il a un GARDIEN : d'abord celui qui l'a lache. Son addon arbitre ce qu'on
--     y prend, comme le MJ le fait pour un coffre, et le garde dans sa
--     sauvegarde tant qu'il est la ;
--   * tout le groupe en garde une COPIE, tenue a jour a chaque changement ;
--   * si le gardien part, un autre joueur reprend la garde avec sa copie, et
--     ainsi de suite ;
--   * des qu'un MJ le voit, il le SECURISE : il en fait une vraie entree
--     « Coffre », posee au meme endroit avec ce qu'il contient encore
--     (CoffresMJ.DepuisSol), et le sac au sol disparait.
--
-- Deux copies peuvent diverger un instant (deux joueurs reprennent la garde en
-- meme temps). La plus RECENTE l'emporte (`version`), a egalite celle dont le
-- gardien a le plus petit nom : tout le monde tranche pareil, sans se parler.
-- Un sac disparu (ramasse, ou securise) est retenu comme MORT : une copie qui
-- revient apres coup, d'un joueur reste deconnecte, ne le ressuscite pas.

local _, LCM = ...

local Sol = { sacs = {}, morts = {} }
LCM.SacsAuSol = Sol

Sol.SUJETS = {
    etat     = "sol",   -- gardien -> groupe : un sac au sol, entier
    demande  = "sol?",  -- joueur -> groupe  : quels sacs gardez-vous ?
    retrait  = "sol-",  -- gardien ou MJ -> groupe : ce sac n'est plus au sol
}
local S = Sol.SUJETS

-- Un gardien parti : son successeur designe reprend la garde aussitot ;
-- n'importe quel autre porteur d'une copie le fait apres ce delai, au cas ou
-- le successeur n'aurait pas la copie.
Sol.RELEVE = 15
-- Un sac mort est oublie au bout d'un mois : assez pour qu'aucune copie
-- perimee ne revienne.
local OUBLI_MORTS = 30 * 24 * 3600
-- Une copie relue de la sauvegarde est ENDORMIE (le MJ, 16 octobre 2026) :
-- A lache le sac et part ; B prend la garde et y prend des objets ; B part, C
-- prend la garde ; A revient avec sa vieille copie. Arbitrer avec elle
-- redonnerait ce que B a deja pris (duplication) ; la rediffuser ecraserait,
-- chez un nouveau venu, ce que B a fait (perte). Endormie, elle ne s'arbitre
-- pas, ne se diffuse pas, ne reprend pas la garde : elle DEMANDE au groupe la
-- version la plus recente, et se reveille quand elle l'a — ou apres ce delai
-- sans reponse, une fois la demande vraiment partie.
Sol.CONFIRMATION = 10

local function Moi() return LCM.PlayerId() end
local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Court(nom) return (tostring(nom or ""):match("^[^-]+")) or "" end
local function Maintenant() return (GetTime and GetTime()) or 0 end
local function Horloge() return (time and time()) or 0 end
-- Tout le monde, et pas seulement le groupe : le canal d'addon que
-- Core/Presence.lua rejoint (silencieux, hors des fenetres de discussion), le
-- groupe en repli. Un joueur hors du raid ne recevait rien, et celui qui y
-- entrait devait recharger (le MJ, 20 octobre 2026).
local function Canal() return LCM.Reseau.Diffusable() end

-- ===== Le paquet ===========================================================

function Sol.Paquet(sol)
    local o = {}
    for _, objet in ipairs(sol.objets or {}) do
        o[#o + 1] = { e = objet.entree, q = objet.quantite,
            d = LCM.Echange and LCM.Echange.DefinitionObjet(objet.entree) or nil }
    end
    local p = sol.position or {}
    -- `j` : un OBJET pose seul (pas un sac) : il se ramasse, il ne s'ouvre pas.
    return { i = sol.id, n = sol.label, b = sol.sac, t = sol.tente, j = sol.objet and 1 or nil,
        s = sol.places, o = o,
        x = p.x, y = p.y, z = p.z, r = p.source, k = p.carte, a = sol.auteur, g = sol.gardien,
        v = sol.version, w = sol.quand }
end

function Sol.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local objets = {}
    for _, o in ipairs(type(paquet.o) == "table" and paquet.o or {}) do
        local ref = Texte(o.e)
        if type(o.d) == "table" and LCM.Echange and LCM.Echange.ImporterObjetPartage then
            LCM.Echange.ImporterObjetPartage({ ref = ref, definition = o.d })
        end
        local q = math.max(0, math.floor(tonumber(o.q) or 0))
        if ref ~= "" and q > 0 then objets[#objets + 1] = { entree = ref, quantite = q } end
    end
    return {
        id = id, label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Sac",
        sac = Texte(paquet.b) ~= "" and Texte(paquet.b) or nil,
        tente = Texte(paquet.t) ~= "" and Texte(paquet.t) or nil,
        objet = paquet.j ~= nil and paquet.j ~= false or nil,
        places = math.max(1, math.floor(tonumber(paquet.s) or 1)),
        objets = objets,
        position = { x = tonumber(paquet.x), y = tonumber(paquet.y), z = tonumber(paquet.z),
            source = Texte(paquet.r) ~= "" and Texte(paquet.r) or nil, carte = tonumber(paquet.k) },
        auteur = Texte(paquet.a), gardien = Texte(paquet.g),
        version = math.max(1, math.floor(tonumber(paquet.v) or 1)),
        quand = tonumber(paquet.w) or 0,
    }
end

-- ===== La memoire ==========================================================

local function Sauver()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    LCM.db.solSacs = (next(Sol.sacs) or next(Sol.morts)) and { sacs = Sol.sacs, morts = Sol.morts } or nil
end

-- Le sac au sol, vu comme un coffre (Core/Coffres.lua) : c'est ce qui lui
-- donne le bouton « Ouvrir », la fenetre, et l'envoi des demandes au gardien.
local function Inscrire(sol)
    local C = LCM.Coffres
    if not (C and C.Connaitre) then return end
    local objets = {}
    for _, o in ipairs(sol.objets or {}) do objets[#objets + 1] = { entree = o.entree, quantite = o.quantite } end
    local p = sol.position or {}
    C.Connaitre({ id = sol.id, label = sol.label, sol = true,
        coffre = { places = sol.places, verrous = 0, reset = false, objets = objets,
            expertises = {}, outils = {}, sac = sol.sac, tente = sol.tente, objet = sol.objet } },
        { { id = sol.id, def = sol.id, x = p.x, y = p.y, z = p.z, source = p.source, carte = p.carte } },
        sol.gardien)
end

local function Effacer(id)
    local C = LCM.Coffres
    Sol.sacs[id] = nil
    if C then
        if C.points[id] then C.Oublier(id) end
        C.definitions[id] = nil
    end
end

-- Le sac n'est plus au sol (ramasse, ou securise par un MJ).
local function Mourir(id, diffuser)
    id = tostring(id or "")
    Sol.morts[id] = Horloge()
    Effacer(id)
    Sauver()
    if diffuser then
        local canal = Canal()
        if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    end
end
Sol.Mourir = Mourir

local function Diffuser(sol, qui)
    local canal = qui and "WHISPER" or Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer(S.etat, Sol.Paquet(sol), canal, qui, { etale = true })
end

-- Les copies endormies : id -> echeance (nil tant que la demande n'est pas
-- partie : sans groupe, personne ne peut repondre, et se reveiller serait
-- reprendre la garde d'une copie peut-etre perimee).
local endormis = {}
function Sol.Endormi(id) return endormis[tostring(id or "")] ~= nil end

-- Demander au groupe la version a jour de ce qu'on a : « id:version » pour
-- chaque copie. Tout porteur d'une copie plus recente repond.
local function Demander()
    local canal = Canal()
    if not canal then return false end
    local liste = {}
    for id, sol in pairs(Sol.sacs) do liste[#liste + 1] = id .. ":" .. tostring(sol.version or 1) end
    table.sort(liste)
    LCM.Reseau.Envoyer(S.demande, { l = table.concat(liste, ",") }, canal)
    local echeance = Maintenant() + Sol.CONFIRMATION
    for id, quand in pairs(endormis) do
        if quand == true then endormis[id] = echeance end
    end
    return true
end
Sol.Demander = Demander

-- Le canal de l'addon n'existe pas encore a la connexion : des qu'il repond,
-- on redemande (Core/Presence.lua, 20 octobre 2026).
LCM.WhenReady(function()
    if LCM.Presence and LCM.Presence.QuandCanal then
        LCM.Presence.QuandCanal(function() Demander() end)
    end
end)

-- Plus recente : la version, puis le plus petit nom de gardien.
local function PlusRecent(a, b)
    if not b then return true end
    if a.version ~= b.version then return a.version > b.version end
    return Court(a.gardien) < Court(b.gardien)
end

-- ===== Le MJ securise ======================================================

function Sol.Securiser(sol)
    if not (LCM.IsMaster() and LCM.CoffresMJ and LCM.CoffresMJ.DepuisSol) then return false end
    -- Une copie endormie est peut-etre perimee : on n'en fait pas un coffre.
    if endormis[sol.id] then return false end
    local id, raison = LCM.CoffresMJ.DepuisSol(sol)
    if not id then
        LCM.Erreur(string.format("sac au sol « %s » non sécurisé : %s", tostring(sol.label), tostring(raison)))
        return false
    end
    Mourir(sol.id, true)
    LCM.Info(string.format("« %s » sécurisé : c'est maintenant un coffre.", tostring(sol.label)))
    return true
end

-- ===== Le gardien arbitre ==================================================

local function Etat(sol)
    return { i = sol.id, o = LCM.Copie(sol.objets or {}), v = 0, f = false, s = true, vo = {} }
end

local function Cases(objets)
    local n = 0
    for _, o in ipairs(objets or {}) do
        local e = LCM.Compendium.Resoudre(o.entree)
        local pile = math.max(1, tonumber(e and e.pileMax) or 1)
        n = n + math.ceil((tonumber(o.quantite) or 0) / pile)
    end
    return n
end

-- Le contenu a change : tout le monde le sait, copies comprises.
local function Changer(sol)
    sol.version = (sol.version or 1) + 1
    Inscrire(sol)
    Sauver()
    Diffuser(sol)
    local C = LCM.Coffres
    local etat = Etat(sol)
    if C.courant == sol.id then
        C.etat = etat
        if C.onChange then pcall(C.onChange) end
    end
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(C.SUJETS.etat, etat, canal) end
end

-- Une demande « cof! » sur un sac au sol. Rend vrai si elle visait un sac au
-- sol (traitee ou refusee), faux pour la laisser au MJ des coffres.
function Sol.Traiter(expediteur, req)
    local sol = Sol.sacs[tostring(req and req.i or "")]
    if not sol then return false end
    local C = LCM.Coffres
    local function Repondre(ok, extra)
        local data = Etat(sol)
        data.ok = ok == true
        data.action = req.a
        for k, v in pairs(extra or {}) do data[k] = v end
        if expediteur == Moi() then
            C.etat = data
            if C.onChange then pcall(C.onChange) end
            if C.onReponse then pcall(C.onReponse, expediteur, data) end
        else
            LCM.Reseau.Envoyer(C.SUJETS.etat, data, "WHISPER", expediteur)
        end
    end
    if endormis[sol.id] then
        Repondre(false, { msg = "ce sac se met à jour auprès du groupe : réessaie dans un instant." })
        return true
    end
    if sol.gardien ~= Moi() then
        Repondre(false, { msg = "ce sac a changé de gardien : rouvre-le." })
        return true
    end
    if req.a == "ouvrir" or req.a == "fermer" then Repondre(true) return true end
    if req.a == "prendre" then
        local ref, n = tostring(req.e or ""), math.max(1, math.floor(tonumber(req.q) or 1))
        for index, o in ipairs(sol.objets) do
            if o.entree == ref and o.quantite >= n then
                o.quantite = o.quantite - n
                if o.quantite == 0 then table.remove(sol.objets, index) end
                Repondre(true, { e = ref, q = n, objet = LCM.Echange and LCM.Echange.DefinitionObjet(ref) })
                Changer(sol)
                return true
            end
        end
        Repondre(false, { msg = "il n'y en a plus assez." })
        return true
    end
    if req.a == "ranger" then
        local ref, n = tostring(req.e or ""), math.max(1, math.floor(tonumber(req.q) or 1))
        if not LCM.Compendium.Resoudre(ref) then Repondre(false, { msg = "objet inconnu." }) return true end
        local essai = LCM.Copie(sol.objets)
        local trouve
        for _, o in ipairs(essai) do if o.entree == ref then trouve = o break end end
        if trouve then trouve.quantite = trouve.quantite + n
        else essai[#essai + 1] = { entree = ref, quantite = n } end
        if Cases(essai) > sol.places then
            Repondre(false, { msg = "le sac n'a pas assez de place." })
            return true
        end
        sol.objets = essai
        Repondre(true)
        Changer(sol)
        return true
    end
    if req.a == "emporter" then
        local objets = {}
        for _, o in ipairs(sol.objets or {}) do
            objets[#objets + 1] = { e = o.entree, q = o.quantite,
                d = LCM.Echange and LCM.Echange.DefinitionObjet(o.entree) or nil }
        end
        -- On repond AVANT de faire disparaitre : la disparition ferme la
        -- fenetre du demandeur.
        Repondre(true, { b = sol.sac, t = sol.tente, w = objets })
        Mourir(sol.id, true)
        return true
    end
    Repondre(false, { msg = "un sac au sol n'a pas de verrou." })
    return true
end

-- ===== Lacher ==============================================================

local compteur = 0
local function Identifiant()
    compteur = compteur + 1
    return string.format("sol%x%04x%02x", Horloge(), compteur % 65536, math.random(0, 255))
end

-- Lacher le sac (ou la tente) d'un emplacement. true, ou false et la raison.
function Sol.Lacher(onglet, index)
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    local x, y, source, z = LCM.Recolte.Position3D()
    if not x then
        if LCM.DeplacementForce and LCM.DeplacementForce.DemanderGPS then LCM.DeplacementForce.DemanderGPS(true) end
        return false, "position indisponible : .gps demandé, relâche-le dans un instant."
    end
    local contenant = LCM.Inventaire.Contenant(LCM.Inventaire.Emplacement(entity, onglet, index))
    local emplacement, contenu = LCM.Inventaire.Lacher(entity, onglet, index)
    if not emplacement then return false, contenu end
    local element = contenant and contenant.element
    local qui = entity.name or (UnitName and UnitName("player")) or Court(Moi())
    local sol = {
        id = Identifiant(),
        label = string.format("%s de %s", tostring(element and element.label or "Sac"), tostring(qui)),
        sac = contenu.sac, tente = contenu.tente,
        places = math.max(1, (contenant and contenant.places or 0) + (contenant and contenant.placesDevise or 0)),
        objets = contenu.objets,
        position = { x = x, y = y, z = z, source = source, carte = LCM.Recolte.Carte() },
        auteur = Moi(), gardien = Moi(), version = 1, quand = Horloge(),
    }
    -- Un MJ le securise sur-le-champ ; un joueur le garde, et le dit au groupe.
    if LCM.IsMaster() and LCM.CoffresMJ then
        local id, raison = LCM.CoffresMJ.DepuisSol(sol)
        if not id then
            LCM.Inventaire.Reposer(entity, onglet, index, emplacement)
            return false, raison
        end
    else
        Sol.sacs[sol.id] = sol
        Inscrire(sol)
        Sauver()
        Diffuser(sol)
    end
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    LCM.Ok(string.format("« %s » est au sol : n'importe qui peut l'ouvrir ou le ramasser.", sol.label))
    return true
end

-- Poser au sol un OBJET d'une case (le MJ, 16 octobre 2026) : glisse hors de
-- l'inventaire, il n'est plus detruit, il tombe. Un seul objet (sa pile),
-- une seule collecte : « Ramasser », sans jet, sans metier, sans DD, et le
-- point disparait des qu'il est ramasse. Il suit la meme garde qu'un sac.
-- `objet` : le glissement d'une case (UI/Inventaires.lua), qui sait quitter sa
-- place et y revenir. true, ou false et la raison.
function Sol.LacherObjet(objet)
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end
    if type(objet) ~= "table" or not objet.ref then return false, "rien à poser." end
    local x, y, source, z = LCM.Recolte.Position3D()
    if not x then
        if LCM.DeplacementForce and LCM.DeplacementForce.DemanderGPS then LCM.DeplacementForce.DemanderGPS(true) end
        return false, "position indisponible : .gps demandé, relâche-le dans un instant."
    end
    local element = LCM.Compendium.Resoudre(objet.ref)
    local quantite = math.max(1, math.floor(tonumber(objet.quantite) or 1))
    local sol = {
        id = Identifiant(),
        label = tostring(element and element.label or objet.nom or objet.ref)
            .. (quantite > 1 and (" x" .. quantite) or ""),
        objet = true, places = 1,
        objets = { { entree = objet.ref, quantite = quantite } },
        position = { x = x, y = y, z = z, source = source, carte = LCM.Recolte.Carte() },
        auteur = Moi(), gardien = Moi(), version = 1, quand = Horloge(),
    }
    if objet.retirer then objet.retirer() end
    if LCM.IsMaster() and LCM.CoffresMJ then
        local id, raison = LCM.CoffresMJ.DepuisSol(sol)
        if not id then
            if objet.rendre then objet.rendre() end
            return false, raison
        end
    else
        Sol.sacs[sol.id] = sol
        Inscrire(sol)
        Sauver()
        Diffuser(sol)
    end
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    LCM.Ok(string.format("« %s » est au sol : n'importe qui peut le ramasser.", sol.label))
    return true
end

-- ===== La garde passe ======================================================

local absents = {}

-- Celui qui reprend la garde quand le gardien est parti : le plus petit nom
-- parmi les joueurs du groupe en ligne (soi compris). Tout le monde le calcule
-- pareil.
local function Successeur()
    local meilleur = Court(Moi())
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
        local nom = UnitName and UnitName(prefixe .. i)
        if nom and (not UnitIsConnected or UnitIsConnected(prefixe .. i)) and Court(nom) < meilleur then
            meilleur = Court(nom)
        end
    end
    return meilleur
end

function Sol.Veiller()
    local maintenant = Maintenant()
    for id, sol in pairs(Sol.sacs) do
        local echeance = endormis[id]
        if echeance then
            -- Personne n'a mieux : la copie se reveille. Gardien, on le redit.
            if echeance ~= true and maintenant >= echeance then
                endormis[id] = nil
                if sol.gardien == Moi() then Diffuser(sol) end
            end
        elseif LCM.IsMaster() then
            Sol.Securiser(sol)
        elseif sol.gardien ~= Moi() then
            if LCM.Recolte.EnLigne(sol.gardien) then
                absents[id] = nil
            else
                absents[id] = absents[id] or maintenant
                if Successeur() == Court(Moi()) or maintenant - absents[id] >= Sol.RELEVE then
                    sol.gardien = Moi()
                    sol.version = (sol.version or 1) + 1
                    absents[id] = nil
                    Inscrire(sol)
                    Sauver()
                    Diffuser(sol)
                end
            end
        end
    end
end

-- ===== Le reseau ===========================================================

local horloge
local function Battre()
    if horloge or not CreateFrame then return end
    horloge = CreateFrame("Frame")
    horloge.reste = 0
    horloge:SetScript("OnUpdate", function(self, ecoule)
        self.reste = self.reste + (tonumber(ecoule) or 0)
        if self.reste < 2 then return end
        self.reste = 0
        if next(Sol.sacs) then Sol.Veiller() end
    end)
end

-- Relire la sauvegarde : ce qu'on gardait, ou dont on avait une copie, en
-- copies ENDORMIES — on ne sait pas ce qui s'est passe pendant l'absence.
function Sol.Charger()
    local garde = LCM.db and LCM.db.solSacs
    if type(garde) ~= "table" then return end
    local limite = Horloge() - OUBLI_MORTS
    for id, quand in pairs(type(garde.morts) == "table" and garde.morts or {}) do
        if (tonumber(quand) or 0) >= limite then Sol.morts[id] = quand end
    end
    for id, sol in pairs(type(garde.sacs) == "table" and garde.sacs or {}) do
        if type(sol) == "table" and not Sol.morts[id] then
            Sol.sacs[id] = sol
            endormis[id] = true
            Inscrire(sol)
        end
    end
    Sauver()
end

LCM.WhenReady(function()
    Sol.Charger()
    Battre()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(S.etat, function(expediteur, donnees)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        local sol = Sol.Lire(donnees)
        if not sol then return end
        if Sol.morts[sol.id] then
            -- Une copie perimee d'un sac deja parti : on le redit.
            local canal = Canal()
            if canal then LCM.Reseau.Envoyer(S.retrait, { i = sol.id }, canal) end
            return
        end
        local connu = Sol.sacs[sol.id]
        -- Une copie endormie accepte une version au moins aussi recente : elle
        -- est confirmee, et se reveille.
        local accepte = PlusRecent(sol, connu)
            or (endormis[sol.id] and connu and sol.version >= connu.version)
        if not accepte then
            -- Plus ancienne que la notre, et la notre est sure : on corrige qui
            -- l'a envoyee (un joueur revenu avec une vieille copie).
            if connu and not endormis[sol.id] and sol.version < connu.version then
                Diffuser(connu, expediteur)
            end
            return
        end
        Sol.sacs[sol.id] = sol
        endormis[sol.id] = nil
        absents[sol.id] = nil
        Inscrire(sol)
        Sauver()
        if LCM.IsMaster() then Sol.Securiser(sol) end
    end)

    LCM.Reseau.Ecouter(S.retrait, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local id = Texte(donnees.i)
        if id ~= "" and not Sol.morts[id] then
            endormis[id] = nil
            Mourir(id, false)
        end
    end)

    -- Qui arrive (ou revient) dit ce qu'il a, « id:version ». On lui renvoie
    -- toute copie plus RECENTE que la sienne — gardien ou simple porteur : le
    -- gardien est peut-etre parti, et c'est alors un porteur qui sait. Ce qu'il
    -- n'a pas du tout, seul le gardien le lui envoie, pour ne pas l'inonder.
    -- Un sac qu'il croit au sol mais qui est parti, on le lui redit.
    LCM.Reseau.Ecouter(S.demande, function(expediteur, donnees)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        local siennes = {}
        for id, v in tostring(donnees and donnees.l or ""):gmatch("([^:,]+):(%d+)") do siennes[id] = tonumber(v) end
        for id, sol in pairs(Sol.sacs) do
            if not endormis[id] then
                local sienne = siennes[id]
                if (sienne and sienne < (sol.version or 1)) or (not sienne and sol.gardien == Moi()) then
                    Diffuser(sol, expediteur)
                end
            end
        end
        for id in pairs(siennes) do
            if Sol.morts[id] then LCM.Reseau.Envoyer(S.retrait, { i = id }, "WHISPER", expediteur) end
        end
    end)

    Demander()
    if LCM.IsMaster() then for _, sol in pairs(Sol.sacs) do Sol.Securiser(sol) end end
end)

LCM.On("GROUP_ROSTER_UPDATE", function()
    if not LCM.ready then return end
    -- Le groupe a change : les nouveaux savent peut-etre mieux, et les copies
    -- endormies sans groupe peuvent enfin demander.
    Demander()
    local canal = Canal()
    for id, sol in pairs(Sol.sacs) do
        if sol.gardien == Moi() and not endormis[id] and canal then Diffuser(sol) end
    end
    if next(Sol.sacs) then Sol.Veiller() end
end)
