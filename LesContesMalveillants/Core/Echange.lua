-- L'echange entre deux joueurs : on glisse un objet sur quelqu'un, et si cette
-- personne a l'addon, une fenetre s'ouvre des deux cotes. Chacun y pose des
-- objets et des pieces, chacun accepte, et tout change de main d'un coup.
--
-- Deux principes :
--
--   * Ce qu'on offre quitte le sac TOUT DE SUITE (mise en gage). Sinon on
--     pourrait promettre deux fois la meme chose, ou la depenser pendant que
--     l'autre regarde. Tout ce qui est en gage sait revenir : annuler rend
--     exactement ce qu'on avait pose.
--   * Tout changement de contenu REMET LES DEUX ACCORDS A ZERO. On n'echange
--     jamais autre chose que ce qu'on a vu en acceptant.
--
-- On fait confiance au message de l'autre, comme partout ailleurs dans l'addon
-- (voir Reseau.DansLeGroupe) : on ne joue qu'avec des gens avec qui on joue.

local _, LCM = ...

local Echange = {}
LCM.Echange = Echange

local Inv = LCM.Inventaire
local Bourse = LCM.Bourse

-- Au-dela, on considere que l'autre n'a pas l'addon : il n'a pas repondu.
Echange.DELAI = 5

-- La seance en cours. Une seule a la fois : a deux fenetres ouvertes on ne
-- saurait plus a qui l'on donne.
Echange.courant = nil

-- Le meme joueur s'ecrit « Yutosuu » quand on le cible et « Yutosuu-Apertus »
-- quand il repond : WoW qualifie l'expediteur de son royaume. On compare donc
-- sur le nom court, comme Core/Presence.lua et le combat le font deja.
local function Court(nom) return tostring(nom or ""):match("^([^-]+)") or tostring(nom or "") end
local function Meme(a, b) return Court(a):lower() == Court(b):lower() end

-- La seance retient l'ecriture de l'EXPEDITEUR des sa premiere reponse : les
-- chuchotements suivants partent vers le nom que le serveur nous a donne, et
-- non vers celui qu'on avait tape.
local function Reconnue(seance, qui)
    if not (seance and Meme(seance.qui, qui)) then return false end
    if seance.qui ~= qui and tostring(qui or "") ~= "" then seance.qui = qui end
    return true
end

local function Moi() return LCM.Entities.Self() end

local function Dire(texte) if LCM.Info then LCM.Info(texte) end end
local function Refuser(texte) if LCM.Alerte then LCM.Alerte(texte) end end

-- Ce qu'on previent quand la seance change : l'ecran s'y abonne.
local temoins = {}
function Echange.Observer(handler)
    if type(handler) == "function" then temoins[#temoins + 1] = handler end
end

local function Prevenir()
    for _, handler in ipairs(temoins) do handler(Echange.courant) end
end

-- ===== Le protocole ========================================================
-- DEMANDE : « veux-tu echanger ? »   OUI : « j'ai l'addon, j'ouvre. »
-- CONTENU : ce que je pose.          ACCORD : j'accepte, ou je retire mon
-- accord.                            FIN : conclu, ou annule.

local function Envoyer(sujet, donnees, options)
    local seance = Echange.courant
    if not (seance and LCM.Reseau) then return end
    LCM.Reseau.Envoyer("ECH_" .. sujet, donnees or {}, "WHISPER", seance.qui, options)
end

-- Une entree forgeable n'est pas forcement installee chez le joueur : la
-- definition MJ ne voyage pas dans son addon. On envoie une copie des seuls
-- champs d'un objet, jamais une reference seule qui serait inutilisable.
local function DefinitionObjet(ref)
    local famille, id = tostring(ref or ""):match("^([%w_]+)/(.+)$")
    local objet = famille == "objets" and LCM.Objets.Get(id)
    if not objet then return nil end
    local avantage = {}
    for champ, actif in pairs(objet.avantage or {}) do
        if actif then avantage[#avantage + 1] = champ end
    end
    table.sort(avantage)
    return {
        id = objet.id, label = objet.label, categorie = objet.categorie,
        description = objet.description, icone = objet.icone, tags = objet.tags,
        couleurTitre = objet.couleurTitre, couleurFond = objet.couleurFond,
        pileMax = objet.pileMax, type = objet.type, metiers = objet.metiers,
        forge = objet.forge, etat = objet.etat, bonus = objet.bonus,
        ic = LCM.Copie(objet.ic),
        -- Le transport historique aplatit les booleens/nombres des tables.
        -- Le corps type garde notamment confirmation=false et cumul=false.
        icSerialise = objet.ic and LCM.Lien.Serialiser(objet.ic) or nil,
        avantage = avantage, armure = objet.armure, taille = objet.taille,
    }
end

local function ImporterObjetPartage(pose)
    if type(pose) ~= "table" then return false end
    local famille, id = tostring(pose.ref or ""):match("^([%w_]+)/(.+)$")
    local definition = pose.definition
    if famille ~= "objets" or type(definition) ~= "table" or tostring(definition.id or "") ~= id then
        return false
    end
    if definition.icSerialise ~= nil then
        if type(definition.icSerialise) ~= "string" then return false end
        local lu, ic = pcall(LCM.Lien.Deserialiser, definition.icSerialise)
        if not lu or type(ic) ~= "table" then return false end
        definition = LCM.Copie(definition)
        definition.ic = ic
    end
    -- Construire valide categorie, bonus, durabilite et champs propres avant
    -- toute sauvegarde. Un message mal forme ne doit pas casser la reception.
    local ok, objet = pcall(LCM.Objets.Construire, definition)
    if not ok or not objet then return false end
    for champ in pairs(objet.bonus or {}) do
        if not LCM.Schema.Field(champ) then return false end
    end
    for champ in pairs(objet.avantage or {}) do
        if not LCM.Schema.Field(champ) then return false end
    end

    local ajoute, resultat = pcall(LCM.Objets.Remplacer or LCM.Objets.Add, definition)
    if not ajoute or not resultat then return false end
    LCM.EnsureDatabase()
    LCM.db.objetsRecus = type(LCM.db.objetsRecus) == "table" and LCM.db.objetsRecus or {}
    -- Sauvegarder la definition normalisee. Ainsi elle ne disparait pas au
    -- prochain /reload, meme si l'addon MJ de l'expediteur est absent.
    LCM.db.objetsRecus[id] = DefinitionObjet("objets/" .. id)
    return true
end
Echange.DefinitionObjet = DefinitionObjet
Echange.ImporterObjetPartage = ImporterObjetPartage

function Echange.DefinitionPartagee(ref)
    if tostring(ref or ""):match("^livres/") and LCM.Livres then
        return LCM.Livres.Definition(ref)
    end
    return DefinitionObjet(ref)
end

function Echange.ImporterPartage(pose)
    if type(pose) ~= "table" then return false end
    if tostring(pose.ref or ""):match("^livres/") and LCM.Livres then
        return LCM.Livres.Importer(pose.ref, pose.definition)
    end
    return ImporterObjetPartage(pose)
end

function Echange.ChargerObjetsRecus()
    local db = LCM.EnsureDatabase()
    for id, definition in pairs(type(db.objetsRecus) == "table" and db.objetsRecus or {}) do
        if type(definition) == "table" and tostring(definition.id or "") == tostring(id) then
            local ok, objet = pcall(LCM.Objets.Remplacer or LCM.Objets.Add, definition)
            if not ok or not objet then LCM.Erreur("objet reçu illisible : " .. tostring(id)) end
        end
    end
end
LCM.WhenReady(Echange.ChargerObjetsRecus)

local function NouvelleSeance(qui, role)
    return {
        qui = qui, role = role,
        mien = { objets = {}, devises = {} },
        sien = { objets = {}, devises = {} },
        monAccord = false, sonAccord = false,
        ouverte = true,
    }
end

-- ===== Ouvrir ==============================================================

-- `objet` : ce qu'on vient de lacher sur la personne, pose d'emblee si la
-- seance s'ouvre. Sans lui, c'est une demande a vide.
function Echange.Proposer(qui, objet)
    qui = tostring(qui or "")
    if qui == "" then return false, "on ne sait pas a qui." end
    if Echange.courant then return false, "un échange est déjà en cours." end
    if qui == (UnitName and UnitName("player") or "") then
        return false, "on n'échange pas avec soi-même."
    end

    Echange.courant = NouvelleSeance(qui, "demandeur")
    Echange.courant.attente = objet
    Echange.courant.ouverte = false   -- tant que l'autre n'a pas repondu
    Envoyer("DEMANDE", {})
    Dire(string.format("échange proposé à %s…", qui))

    -- Sans reponse, c'est qu'il n'a pas l'addon : on le dit, et on rend ce
    -- qu'on allait poser (il n'a pas encore quitte le sac, mais la demande
    -- doit se refermer proprement).
    if C_Timer and C_Timer.After then
        C_Timer.After(Echange.DELAI, function()
            local seance = Echange.courant
            if seance and Meme(seance.qui, qui) and not seance.ouverte then
                Echange.courant = nil
                Refuser(string.format("%s n'a pas l'addon : impossible d'échanger.", qui))
                Prevenir()
            end
        end)
    end
    Prevenir()
    return true
end

-- On nous propose un echange.
local function SurDemande(qui)
    if Echange.courant then
        -- Deja pris : on repond quand meme, pour que l'autre ne croie pas a une
        -- absence d'addon, mais on refuse.
        if LCM.Reseau then
            LCM.Reseau.Envoyer("ECH_FIN", { raison = "déjà en échange" }, "WHISPER", qui)
        end
        return
    end
    Echange.courant = NouvelleSeance(qui, "invite")
    Envoyer("OUI", {})
    Dire(string.format("%s propose un échange.", qui))
    Prevenir()
end

local function SurOui(qui)
    local seance = Echange.courant
    if not (Reconnue(seance, qui) and not seance.ouverte) then return end
    seance.ouverte = true
    -- Ce qu'on tenait au moment du lacher se pose tout seul : c'est ce geste-la
    -- qui a ouvert la fenetre.
    local attente = seance.attente
    seance.attente = nil
    -- Une SOMME (la bourse : « Échanger » sur une devise) se pose par
    -- Monnayer ; un objet, par Offrir.
    if attente and attente.devise then
        local ok, raison = Echange.Monnayer(attente.devise, attente.combien)
        if not ok and raison then Refuser(raison) end
    elseif attente and attente.lot then
        -- Une selection de l'inventaire (20 octobre 2026) : tout se pose.
        for _, objet in ipairs(attente.lot) do
            local ok, raison = Echange.Offrir(objet)
            if not ok and raison then Refuser(raison) end
        end
    elseif attente then
        Echange.Offrir(attente)
    end
    Prevenir()
end

-- ===== Poser et reprendre ==================================================

-- Tout changement casse les accords : on n'echange que ce qu'on a vu.
local function Bouge()
    local seance = Echange.courant
    if not seance then return end
    seance.monAccord, seance.sonAccord = false, false
end

-- `objet` : celui d'un glissement (UI.Glisser), qui sait quitter sa place et y
-- revenir. L'echange ne connait ni les sacs ni les emplacements : il garde ce
-- que la source lui a donne.
function Echange.Offrir(objet)
    local seance = Echange.courant
    if not (seance and seance.ouverte) then return false, "aucun échange en cours." end
    if type(objet) ~= "table" or not objet.ref then return false, "rien à poser." end
    local exemplaires, erreur = LCM.Exemplaires.Lire(objet.ref, tonumber(objet.quantite) or 1, objet.exemplaires)
    if erreur then return false, erreur end
    for _, pose in ipairs(seance.mien.objets) do
        if pose.ref == objet.ref and pose.origine == objet.origine then
            return false, "déjà posé."
        end
    end
    -- En GAGE : il quitte le sac maintenant. Promis deux fois, il n'existerait
    -- qu'une.
    if objet.retirer then objet.retirer() end
    seance.mien.objets[#seance.mien.objets + 1] = {
        ref = objet.ref, quantite = objet.quantite or 1,
        nom = objet.nom, icone = objet.icone,
        exemplaires = exemplaires,
        definition = Echange.DefinitionPartagee(objet.ref),
        rendre = objet.rendre, origine = objet.origine,
    }
    Bouge()
    Envoyer("CONTENU", Echange.Contenu(), { etale = true })
    Prevenir()
    return true
end

-- Rend une ligne de mon offre : elle retourne exactement d'ou elle venait.
function Echange.Reprendre(rang)
    local seance = Echange.courant
    if not (seance and seance.ouverte) then return false end
    local pose = table.remove(seance.mien.objets, rang)
    if not pose then return false end
    if pose.rendre then pose.rendre()
    else Inv.Deposer(Moi(), pose.ref, pose.quantite, pose.exemplaires) end
    Bouge()
    Envoyer("CONTENU", Echange.Contenu(), { etale = true })
    Prevenir()
    return true
end

-- Fixe la somme offerte dans une devise (0 pour ne plus rien offrir). La
-- difference seule passe par la bourse : on ne debite pas deux fois en
-- corrigeant un montant.
function Echange.Monnayer(deviseId, combien)
    local seance = Echange.courant
    if not (seance and seance.ouverte) then return false, "aucun échange en cours." end
    deviseId = tostring(deviseId or "")
    combien = math.max(0, math.floor(tonumber(combien) or 0))
    local pose = math.floor(tonumber(seance.mien.devises[deviseId]) or 0)
    local ecart = combien - pose
    if ecart == 0 then return true end
    if ecart > 0 then
        if not Bourse.Peut(Moi(), deviseId, ecart) then
            return false, "la bourse n'a pas de quoi."
        end
        Bourse.Debiter(Moi(), deviseId, ecart)
    else
        Bourse.Crediter(Moi(), deviseId, -ecart)
    end
    seance.mien.devises[deviseId] = combien > 0 and combien or nil
    Bouge()
    Envoyer("CONTENU", Echange.Contenu(), { etale = true })
    Prevenir()
    return true
end

-- Ce que je pose, dit a l'autre. Les rappels (`rendre`) restent chez moi : ils
-- ne regardent que mes sacs.
function Echange.Contenu()
    local seance = Echange.courant
    if not seance then return { objets = {}, devises = {} } end
    local objets = {}
    for _, pose in ipairs(seance.mien.objets) do
        objets[#objets + 1] = { ref = pose.ref, quantite = pose.quantite, nom = pose.nom,
            definition = pose.definition,
            exemplairesSerialises = pose.exemplaires and LCM.Lien.Serialiser(pose.exemplaires) or nil }
    end
    return { objets = objets, devises = seance.mien.devises }
end

local function LireExemplaires(pose)
    if pose.exemplairesSerialises == nil then return pose.exemplaires end
    if type(pose.exemplairesSerialises) ~= "string" then return nil, "exemplaires illisibles." end
    local ok, liste = pcall(LCM.Lien.Deserialiser, pose.exemplairesSerialises)
    if not ok or type(liste) ~= "table" then return nil, "exemplaires illisibles." end
    return LCM.Exemplaires.Lire(pose.ref, tonumber(pose.quantite) or 1, liste)
end

local function SurContenu(qui, donnees)
    local seance = Echange.courant
    if not Reconnue(seance, qui) then return end
    seance.sien.objets = (type(donnees) == "table" and donnees.objets) or {}
    for _, pose in ipairs(seance.sien.objets) do Echange.ImporterPartage(pose) end
    seance.sien.devises = (type(donnees) == "table" and donnees.devises) or {}
    Bouge()
    Prevenir()
end

-- ===== Accepter et conclure ================================================

-- Essayer le rangement sur une copie : une case de tente n'accepte pas une
-- arme, une pile peut deja etre pleine, et une entree MJ peut etre inconnue
-- du compendium du joueur. Compter les cases vides donnait un faux accord.
function Echange.Place()
    local seance = Echange.courant
    if not seance then return true end
    if #(seance.sien.objets or {}) == 0 then return true end
    local personnage = Moi()
    if not personnage then return false, "aucun personnage actif." end
    local essai = LCM.Copie(personnage)
    for _, pose in ipairs(seance.sien.objets) do
        local exemplaires, erreur = LireExemplaires(pose)
        if erreur then return false, erreur end
        local ok, raison = Inv.Deposer(essai, pose.ref, tonumber(pose.quantite) or 1, exemplaires)
        if not ok then
            return false, string.format("%s : %s", tostring(pose.nom or pose.ref),
                tostring(raison or "impossible à ranger."))
        end
    end
    return true
end

function Echange.Accepter(oui)
    local seance = Echange.courant
    if not (seance and seance.ouverte) then return false, "aucun échange en cours." end
    if oui == nil then oui = true end
    if oui then
        local place, raison = Echange.Place()
        if not place then
            return false, raison
        end
    end
    seance.monAccord = oui and true or false
    Envoyer("ACCORD", { ok = seance.monAccord })
    Prevenir()
    if seance.monAccord and seance.sonAccord then Echange.Conclure() end
    return true
end

local function SurAccord(qui, donnees)
    local seance = Echange.courant
    if not Reconnue(seance, qui) then return end
    seance.sonAccord = (type(donnees) == "table" and donnees.ok) and true or false
    Prevenir()
    if seance.monAccord and seance.sonAccord then Echange.Conclure() end
end

-- Les deux ont accepte : on prend ce que l'autre a pose. Ce qu'on avait pose
-- est deja sorti du sac (le gage) — il n'y a rien a en faire de plus.
function Echange.Conclure()
    local seance = Echange.courant
    if not seance then return false end
    Echange.courant = nil

    local recus, perdus = 0, {}
    for _, pose in ipairs(seance.sien.objets or {}) do
        local exemplaires, erreur = LireExemplaires(pose)
        local ok = not erreur and Inv.Deposer(Moi(), pose.ref, tonumber(pose.quantite) or 1, exemplaires)
        if ok then recus = recus + 1 else perdus[#perdus + 1] = pose.nom or pose.ref end
    end
    for deviseId, combien in pairs(seance.sien.devises or {}) do
        Bourse.Crediter(Moi(), deviseId, math.floor(tonumber(combien) or 0))
    end

    Dire(string.format("échange conclu avec %s : %d objet(s) reçu(s).", seance.qui, recus))
    if #perdus > 0 then
        -- On avait verifie la place en acceptant ; si l'on arrive ici, les sacs
        -- ont change entre-temps. On le DIT plutot que de perdre l'objet en
        -- silence.
        Refuser(string.format("sans place dans les sacs : %s", table.concat(perdus, ", ")))
    end
    Prevenir()
    return true
end

-- ===== Annuler =============================================================

-- Rend tout ce qu'on avait mis en gage. Appele aussi bien par le bouton que par
-- l'annulation de l'autre : un gage ne reste jamais nulle part.
local function Rendre(seance)
    for rang = #seance.mien.objets, 1, -1 do
        local pose = seance.mien.objets[rang]
        if pose.rendre then pose.rendre()
        else Inv.Deposer(Moi(), pose.ref, pose.quantite, pose.exemplaires) end
    end
    seance.mien.objets = {}
    for deviseId, combien in pairs(seance.mien.devises) do
        Bourse.Crediter(Moi(), deviseId, math.floor(tonumber(combien) or 0))
    end
    seance.mien.devises = {}
end

function Echange.Annuler(raison, silencieux)
    local seance = Echange.courant
    if not seance then return false end
    if not silencieux then Envoyer("FIN", { raison = raison }) end
    Rendre(seance)
    Echange.courant = nil
    Dire(raison and raison ~= "" and ("échange annulé : " .. raison) or "échange annulé.")
    Prevenir()
    return true
end

local function SurFin(qui, donnees)
    local seance = Echange.courant
    if not Reconnue(seance, qui) then return end
    local raison = type(donnees) == "table" and donnees.raison or nil
    Echange.Annuler(raison or string.format("%s a fermé la fenêtre.", qui), true)
end

-- ===== Branchements ========================================================

if LCM.Reseau then
    LCM.Reseau.Ecouter("ECH_DEMANDE", function(qui) SurDemande(qui) end)
    LCM.Reseau.Ecouter("ECH_OUI", function(qui) SurOui(qui) end)
    LCM.Reseau.Ecouter("ECH_CONTENU", function(qui, donnees) SurContenu(qui, donnees) end)
    LCM.Reseau.Ecouter("ECH_ACCORD", function(qui, donnees) SurAccord(qui, donnees) end)
    LCM.Reseau.Ecouter("ECH_FIN", function(qui, donnees) SurFin(qui, donnees) end)
end

LCM.AddCommand("echange", "propose un échange à ta cible (ou « annuler »)", function(argument)
    argument = tostring(argument or ""):lower()
    if argument == "annuler" then
        if not Echange.Annuler("annulé") then Dire("aucun échange en cours.") end
        return
    end
    if not (UnitExists and UnitExists("target")) then
        Dire("prends quelqu'un pour cible, ou glisse-lui un objet.")
        return
    end
    local nom, royaume = UnitName("target")
    local qui = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
    local ok, raison = Echange.Proposer(qui)
    if not ok and raison then Refuser(raison) end
end)
