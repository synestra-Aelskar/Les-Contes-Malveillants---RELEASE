-- Consulter la fiche d'un autre joueur.
--
-- Le MJ demande, le joueur repond. L'inverse n'existe pas : un joueur n'a aucun
-- moyen de demander la fiche d'un autre — ce n'est pas une option, c'est qu'il
-- n'y a pas de code pour le faire, et que celui qui repond verifie qui demande.
--
-- Ce que ce fichier NE fait pas, et qu'il faut savoir : il n'empeche pas
-- quelqu'un qui aurait le dossier du compagnon MJ de poser la question. Un
-- addon vit sur la machine du joueur. La protection reelle est ailleurs : le
-- dossier `LesContesMalveillants_MJ` n'est pas livre aux joueurs. Le controle
-- ci-dessous arrete les curieux, pas un tricheur decide, et il ne faut pas lui
-- faire dire plus que ca.
--
-- Une fiche recue reste en MEMOIRE VIVE. On consulte, on ne collectionne pas :
-- rien n'entre en sauvegarde.

local _, LCM = ...

local Fiches = {}
LCM.Fiches = Fiches

local recues = {}
local abonnements = {}
local actualisationPlanifiee = false

-- UnitName peut donner « Nom » pour un membre du meme royaume alors que
-- CHAT_MSG_ADDON annonce « Nom-Royaume ». On privilegie toujours l'identite
-- complete, puis on accepte le nom court uniquement s'il ne designe qu'une
-- seule fiche recue (deux joueurs homonymes inter-royaumes restent distincts).
local function NomCourt(joueur)
    local court = tostring(joueur or ""):match("^([^-]+)") or ""
    return court:lower()
end

local function EntreeRecue(joueur)
    joueur = tostring(joueur or "")
    if recues[joueur] then return recues[joueur] end
    local court, trouve = NomCourt(joueur), nil
    for nom, entree in pairs(recues) do
        if NomCourt(nom) == court then
            if trouve and trouve ~= entree then return nil end
            trouve = entree
        end
    end
    return trouve
end

-- Combien de temps une fiche recue reste consultable. Au-dela, on la redemande
-- plutot que de montrer un etat d'il y a une heure pour l'etat actuel.
Fiches.FRAICHEUR = 300

local function Maintenant()
    return (GetTime and GetTime()) or 0
end

-- Qui a le droit de demander. Le groupe sert de garde-fou : on ne repond pas a
-- quelqu'un qui n'est meme pas avec nous.
local function DansLeGroupe(nom) return LCM.Reseau.DansLeGroupe(nom) end
Fiches.DansLeGroupe = DansLeGroupe

-- ===== Cote joueur : repondre ==============================================

-- Les parties de l'entite necessaires aux sept vues de consultation. Cette
-- liste blanche est volontaire : pas de sorts personnels, d'inventaire ni de
-- brouillons. Le MJ recoit ce qui se voit sur ces fiches, et rien d'autre.
local ANNEXES = {
    traits = "t",
    body = "b",
    etats = "e",
    etatsTemporaires = "et",
    apprentissages = "a",
    equipement = "eq",
    -- L'ancien etat, au nom du modele : celui qu'envoie encore une fiche
    -- d'avant le 20 octobre 2026. L'etat vit maintenant sur l'exemplaire porte.
    usureArmure = "u",
    exemplairesEquipes = "xe",
    bourse = "bo",
    xp = "xp",
}

-- Detache le paquet de l'entite vivante. Ainsi une reception en boucle dans le
-- banc, ou un transport remplace plus tard, ne partage jamais ses tables avec
-- le personnage d'origine.
local function Copier(valeur, profondeur)
    if type(valeur) ~= "table" then return valeur end
    if (profondeur or 0) > 8 then return nil end
    local copie = {}
    for cle, contenu in pairs(valeur) do
        if (type(cle) == "string" or type(cle) == "number")
            and type(contenu) ~= "function" and type(contenu) ~= "userdata" then
            copie[cle] = Copier(contenu, (profondeur or 0) + 1)
        end
    end
    return copie
end

-- Ce qu'on envoie : les valeurs et les annexes utiles aux vues de consultation.
-- Les valeurs vont dans une SOUS-TABLE `v`, et pas sous un prefixe « v. » :
-- l'encodage du reseau se sert deja du point pour dire l'imbrication, et
-- « v.force » lui revenait comme une table nommee v. Un separateur qui veut
-- dire deux choses finit toujours par en dire une de trop.
function Fiches.Paquet(entity)
    local paquet = { nom = tostring(entity.name or entity.id), id = tostring(entity.id), v = {} }
    for champ, valeur in pairs(entity.values or {}) do
        -- Les jauges sont des tables : elles se disent « courant/max ». Lues,
        -- pas recopiees : le maximum d'une jauge a formule n'est plus retenu
        -- dans les valeurs, et l'autre cote n'a pas de quoi le recalculer.
        local field = LCM.Schema.Field(champ)
        if type(valeur) == "table" and field and field.kind == "gauge" then
            local jauge = LCM.Entities.Gauge(entity, champ)
            paquet.v[champ] = string.format("%d/%d", jauge.current, jauge.max)
        elseif type(valeur) == "table" then
            paquet.v[champ] = string.format("%s/%s",
                tostring(valeur.current or ""), tostring(valeur.max or ""))
        else
            paquet.v[champ] = tostring(valeur)
        end
    end
    for champ, cle in pairs(ANNEXES) do
        if entity[champ] ~= nil then paquet[cle] = Copier(entity[champ]) end
    end
    -- La fiche distante doit montrer le même volet d'identité que la fiche
    -- locale. TRP3 ne sait lire directement que les profils connus du client
    -- du MJ : le joueur joint donc un instantané strictement limité aux champs
    -- visibles du volet.
    if LCM.Identite and LCM.Identite.InstantaneTRP then
        paquet.trp = LCM.Identite.InstantaneTRP()
    end
    -- Les jauges calculees (l'armure portee) ne sont pas dans les valeurs, et
    -- restent aussi envoyees sous leur lecture afin que la vue supporte les
    -- personnages provenant d'une version precedente du paquet.
    for _, champ in ipairs(LCM.Schema.sheet.order) do
        local field = LCM.Schema.Field(champ)
        if field.kind == "gauge" and field.lire then
            local jauge = LCM.Entities.Gauge(entity, champ)
            paquet.v[champ] = string.format("%d/%d", jauge.current, jauge.max)
        end
    end
    return paquet
end

-- L'inverse : refaire une entite consultable a partir de ce qu'on a recu. Elle
-- n'est PAS enregistree ; elle sert a nourrir la fenetre de fiche.
function Fiches.Entite(paquet)
    local entity = { id = tostring(paquet.id or "?"), name = tostring(paquet.nom or "?"),
                     kind = "player", values = {}, distante = true }
    for champ, valeur in pairs(type(paquet.v) == "table" and paquet.v or {}) do
        -- Un champ absent du schema est ignore : ce qui arrive du reseau n'a
        -- pas a decider de ce qui existe dans la feuille.
        local field = LCM.Schema.Field(champ)
        if field then
            local courant, maximum = tostring(valeur):match("^(.-)/(.*)$")
            if courant and field.kind == "gauge" then
                entity.values[champ] = { current = tonumber(courant), max = tonumber(maximum) }
            else
                entity.values[champ] = tonumber(valeur) or valeur
            end
        end
    end
    for champ, cle in pairs(ANNEXES) do
        if paquet[cle] ~= nil then entity[champ] = Copier(paquet[cle]) end
    end
    if type(paquet.trp) == "table" then entity.trp = Copier(paquet.trp) end
    return entity
end

-- ===== Cote MJ : demander ==================================================

function Fiches.Demander(joueur)
    joueur = tostring(joueur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if joueur == "" then return false, "quel joueur ?" end
    if not LCM.IsMaster() then return false, "reserve au maitre du jeu." end
    if joueur == LCM.PlayerId() then return false, "c'est toi." end
    return LCM.Reseau.Envoyer("fiche?", {}, "WHISPER", joueur)
end

function Fiches.Arreter(joueur)
    joueur = tostring(joueur or "")
    if joueur == "" then return false end
    return LCM.Reseau.Envoyer("fiche-", {}, "WHISPER", joueur)
end

-- La derniere fiche recue de ce joueur, si elle est encore fraiche.
function Fiches.Recue(joueur)
    local entree = EntreeRecue(joueur)
    if not entree then return nil end
    if Maintenant() - entree.quand > Fiches.FRAICHEUR then return nil, entree.entity end
    return entree.entity, entree.entity
end

function Fiches.Oublier(joueur)
    joueur = tostring(joueur or "")
    if recues[joueur] then recues[joueur] = nil return end
    local court, nomTrouve
    court = NomCourt(joueur)
    for nom in pairs(recues) do
        if NomCourt(nom) == court then
            if nomTrouve then return end -- homonymes : ne rien effacer au hasard
            nomTrouve = nom
        end
    end
    if nomTrouve then recues[nomTrouve] = nil end
end

function Fiches.Connues()
    local out = {}
    for joueur in pairs(recues) do out[#out + 1] = joueur end
    table.sort(out)
    return out
end

LCM.WhenReady(function()
    -- On me demande ma fiche.
    LCM.Reseau.Ecouter("fiche?", function(expediteur)
        if not DansLeGroupe(expediteur) then
            LCM.Debug(string.format("fiche refusee a %s : hors du groupe.", tostring(expediteur)))
            return
        end
        local moi = LCM.Entities.Self()
        if not moi then return end
        abonnements[tostring(expediteur)] = true
        LCM.Reseau.Envoyer("fiche", Fiches.Paquet(moi), "WHISPER", expediteur, { etale = true })
        LCM.Info(string.format("%s a consulte ta fiche.", tostring(expediteur)))
    end)

    -- Une fiche arrive.
    LCM.Reseau.Ecouter("fiche", function(expediteur, donnees)
        local actualisation = EntreeRecue(expediteur) ~= nil
        local entity = Fiches.Entite(donnees)
        recues[tostring(expediteur)] = { entity = entity, quand = Maintenant() }
        if Fiches.onRecue then Fiches.onRecue(expediteur, entity, actualisation) end
    end)

    LCM.Reseau.Ecouter("fiche-", function(expediteur)
        abonnements[tostring(expediteur)] = nil
    end)

    -- La fiche reste en lecture seule cote MJ, mais suit les changements du
    -- joueur tant que la consultation est ouverte. Regrouper les mutations
    -- rapprochées evite d'inonder le reseau lors d'une action atomique.
    local function PousserFichesAbonnees()
        if actualisationPlanifiee or not next(abonnements) then return end
        actualisationPlanifiee = true
        local function EnvoyerMisesAJour()
            actualisationPlanifiee = false
            local entity = LCM.Entities.Self()
            if not entity then return end
            local paquet = Fiches.Paquet(entity)
            for joueur in pairs(abonnements) do
                if DansLeGroupe(joueur) then
                    LCM.Reseau.Envoyer("fiche", paquet, "WHISPER", joueur, { etale = true })
                else
                    abonnements[joueur] = nil
                end
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, EnvoyerMisesAJour) else EnvoyerMisesAJour() end
    end
    LCM.Entities.Ecouter(function(entity)
        if entity == LCM.Entities.Self() then PousserFichesAbonnees() end
    end)
end)
