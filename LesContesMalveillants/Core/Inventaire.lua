-- Inventaire : ce qu'une entite range, et ou.
--
-- La fenetre Inventaires du template (inventoryWindows › window_custom_10) a
-- des ONGLETS (Sacs, Saccoches, Devises), chacun avec un nombre fixe
-- d'EMPLACEMENTS. Un emplacement de sac recoit un sac du compendium ; un sac
-- a des CASES (ses places, puis ses places de devise), et chaque case recoit
-- une entree du compendium avec sa quantite. Un emplacement de devise recoit
-- une devise et son solde.
--
-- Les onglets et leurs capacites sont de la structure (Data/Inventaire.lua,
-- Equilibrage.inventaire). Cote entite, seulement ce qui est range :
--
--     entity.inventaire = {
--         sacs      = { [1] = { sac = "gros_sac", cases = { [3] = { ref = "objets/dague", quantite = 1 } } } },
--         devises   = { [1] = { devise = "credits", solde = 120 } },
--     }
--
-- Un emplacement vide n'ecrit rien ; une table redevenue vide s'efface. Les
-- references sont celles du compendium (« famille/identifiant ») : une entree
-- disparue garde sa case, marquee, et revient si l'entree revient.

local _, LCM = ...

local Inventaire = { categories = {}, parId = {} }
LCM.Inventaire = Inventaire

local function Erreur(message) error("LCM/Inventaire : " .. tostring(message), 0) end

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Capacites() return LCM.Equilibrage and LCM.Equilibrage.inventaire or {} end

-- Un onglet : { id, label, vue = "grille" | "liste", contient = "sac" | "devise" }.
function Inventaire.Categorie(def)
    if type(def) ~= "table" or tostring(def.id or "") == "" then Erreur("onglet invalide") end
    if def.contient ~= "sac" and def.contient ~= "devise" then
        Erreur(def.id .. " : contenu inconnu « " .. tostring(def.contient) .. " »")
    end
    Inventaire.parId[def.id] = def
    Inventaire.categories[#Inventaire.categories + 1] = def
    return def
end

function Inventaire.Get(id) return Inventaire.parId[tostring(id or "")] end

function Inventaire.Capacite(categorieId)
    return math.max(0, math.floor(tonumber(Capacites()[tostring(categorieId or "")]) or 0))
end

-- ===== Lecture (ne cree rien) ==============================================

local VIDE = {}

local function Rangee(entity, categorieId)
    local inv = type(entity) == "table" and entity.inventaire
    local r = type(inv) == "table" and inv[categorieId]
    return type(r) == "table" and r or VIDE
end

-- La ceinture nue : ce que rend la lecture d'un emplacement de ceinture ou
-- rien n'est ecrit. Partagee et en LECTURE SEULE : un accesseur ne cree rien,
-- c'est l'ecriture (Ranger, Poser) qui pose la vraie table.
local CEINTURE_NUE = { ceinture = true }

local function EstCeinture(categorieId)
    local categorie = Inventaire.parId[tostring(categorieId or "")]
    return categorie and categorie.ceinture == true or false
end
Inventaire.EstCeinture = EstCeinture

-- « Cristaux en cours d'usage » (le MJ, 23 octobre 2026) : la POCHE ou vont
-- tous les cristaux entames, et eux seuls. Un cristal entame porte sa charge
-- sur son exemplaire (Core/Lanternes.lua) : sans cette poche, chaque cristal
-- retire de la lanterne aurait pris sa case dans les sacs, un a 99 %, un a
-- 98 %, un a 97 %... Ici ils s'empilent par modele, sans limite, et chacun
-- garde SA charge. Comme la ceinture, elle n'est jamais vide et ne se porte
-- pas : elle est la.
local POCHE_NUE = { cristaux = true }
local POCHE = { id = "cristaux_usage", label = "Cristaux en cours d'usage",
    icone = "Interface\\Icons\\inv_enchanting_80_veiledcrystal",
    description = "Les cristaux entamés, chacun avec sa charge." }

local function EstPoche(categorieId)
    local categorie = Inventaire.parId[tostring(categorieId or "")]
    return categorie and categorie.cristaux == true or false
end
Inventaire.EstPoche = EstPoche

-- Un cristal ENTAME : un exemplaire qui porte sa charge. `x` : une case (sa
-- liste d'exemplaires) ou une liste d'exemplaires.
local function Entame(x)
    local liste = x
    if type(x) == "table" and x.ref ~= nil then liste = x.exemplaires end
    if type(liste) ~= "table" then return false end
    for _, e in ipairs(liste) do
        if type(e) == "table" and e.charge ~= nil then return true end
    end
    return false
end
Inventaire.Entame = Entame

-- Le pourcentage affiche d'un cristal entame (Core/Lanternes.lua, lu a
-- l'appel : Lanternes se charge apres). Dans la poche, seuls s'empilent les
-- cristaux du meme modele AU MEME POURCENTAGE (le MJ, 23 octobre 2026) : les
-- autres vont a la suite, une ligne chacun. Chacun garde sa charge exacte.
local function Pourcent(x)
    local liste = x
    if type(x) == "table" and x.ref ~= nil then liste = x.exemplaires end
    local premier = type(liste) == "table" and liste[1]
    return premier and LCM.Lanterne and LCM.Lanterne.Pourcent(premier) or nil
end
local POCHE_SEULEMENT = "seuls les cristaux entamés vont dans « Cristaux en cours d'usage »."
local DANS_LA_POCHE = "un cristal entamé se range dans « Cristaux en cours d'usage »."

-- Ce que tient un emplacement (une table) ou nil. Une ceinture n'est jamais
-- vide : elle a toujours ses cases de base.
function Inventaire.Emplacement(entity, categorieId, index)
    local e = Rangee(entity, categorieId)[tonumber(index)]
    if type(e) == "table" then return e end
    index = tonumber(index)
    if EstCeinture(categorieId) and index and index >= 1 and index <= Inventaire.Capacite(categorieId) then
        return CEINTURE_NUE
    end
    if EstPoche(categorieId) and index and index >= 1 and index <= Inventaire.Capacite(categorieId) then
        return POCHE_NUE
    end
    return nil
end

-- L'emplacement a ECRIRE : la table de la sauvegarde, creee pour une ceinture
-- qui n'etait encore que nue.
local function EmplacementPourEcrire(entity, categorieId, index)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if e ~= CEINTURE_NUE and e ~= POCHE_NUE then return e end
    entity.inventaire = type(entity.inventaire) == "table" and entity.inventaire or {}
    entity.inventaire[categorieId] = type(entity.inventaire[categorieId]) == "table" and entity.inventaire[categorieId] or {}
    local ecrite = e == POCHE_NUE and { cristaux = true } or { ceinture = true }
    entity.inventaire[categorieId][tonumber(index)] = ecrite
    return ecrite
end

-- Combien d'emplacements sont occupes dans un onglet.
function Inventaire.Occupes(entity, categorieId)
    local n = 0
    for index = 1, Inventaire.Capacite(categorieId) do
        if Inventaire.Emplacement(entity, categorieId, index) then n = n + 1 end
    end
    return n
end

-- Le nombre de cases d'un sac : ses places, puis ses places de devise. Un sac
-- disparu du compendium n'a plus de cases connues : celles qui sont pleines
-- restent visibles.
-- Ce que tient un emplacement de sac : un SAC, ou une TENTE (10 octobre 2026).
-- La tente a son registre (Core/Campement.lua) mais se porte comme un sac : sur
-- un emplacement de sacoche, avec des cases ou l'on range ses accessoires.
-- Rend { element, ref, places, placesDevise, tente } ou nil.
local CEINTURE_SEULE = { id = "ceinture", label = "Ceinture", icone = "Interface\\Icons\\INV_Belt_05",
    description = "Cases de base. Pose une ceinture dessus pour en ajouter." }

function Inventaire.Contenant(emplacement)
    if type(emplacement) ~= "table" then return nil end
    -- La poche : sans limite, elle a toujours UNE case libre apres la derniere
    -- occupee.
    if emplacement.cristaux then
        local plusHaute = 0
        for index in pairs(type(emplacement.cases) == "table" and emplacement.cases or VIDE) do
            plusHaute = math.max(plusHaute, tonumber(index) or 0)
        end
        return { element = POCHE, id = POCHE.id, places = plusHaute + 1, placesDevise = 0, poche = true }
    end
    -- La ceinture : ses cases de base, plus celles de l'objet pose dessus.
    if emplacement.ceinture then
        local sac = emplacement.sac and LCM.Sacs.Get(emplacement.sac)
        local base = math.max(0, math.floor(tonumber(Capacites().placesCeinture) or 0))
        return { element = sac or CEINTURE_SEULE, ref = sac and ("sacs/" .. sac.id) or nil,
                 id = emplacement.sac or "ceinture", places = base + (sac and sac.places or 0),
                 placesDevise = 0, ceinture = true, base = base, nue = emplacement.sac == nil }
    end
    if emplacement.sac then
        local sac = LCM.Sacs.Get(emplacement.sac)
        return { element = sac, ref = "sacs/" .. emplacement.sac, id = emplacement.sac,
                 places = sac and sac.places or 0, placesDevise = sac and sac.placesDevise or 0 }
    end
    if emplacement.tente then
        local tente = LCM.Tentes and LCM.Tentes.Get(emplacement.tente)
        -- Ses accessoires inclus prennent deja leurs places.
        local places = tente and math.max(0, (tente.accessoiresMax or 0) - #(tente.accessoires or VIDE)) or 0
        return { element = tente, ref = "tentes/" .. emplacement.tente, id = emplacement.tente,
                 places = places, placesDevise = 0, tente = true }
    end
    return nil
end

function Inventaire.Cases(emplacement)
    local contenant = Inventaire.Contenant(emplacement)
    local places = contenant and contenant.places or 0
    local devise = contenant and contenant.placesDevise or 0
    local plusHaute = 0
    for index in pairs(emplacement and emplacement.cases or VIDE) do
        plusHaute = math.max(plusHaute, tonumber(index) or 0)
    end
    return math.max(places + devise, plusHaute), places, devise
end

-- Une case de devise : apres les places ordinaires.
function Inventaire.EstCaseDevise(emplacement, index)
    local _, places, devise = Inventaire.Cases(emplacement)
    return index > places and index <= places + devise
end

function Inventaire.Case(emplacement, index)
    local c = emplacement and type(emplacement.cases) == "table" and emplacement.cases[tonumber(index)]
    return type(c) == "table" and c or nil
end

-- ===== Ecriture ============================================================
-- Toutes renvoient true, ou false et la raison : un refus se dit.

local function RangeePourEcrire(entity, categorieId)
    entity.inventaire = type(entity.inventaire) == "table" and entity.inventaire or {}
    entity.inventaire[categorieId] = type(entity.inventaire[categorieId]) == "table" and entity.inventaire[categorieId] or {}
    return entity.inventaire[categorieId]
end

local function Nettoyer(entity, categorieId)
    local inv = entity.inventaire
    if type(inv) ~= "table" then return end
    if type(inv[categorieId]) == "table" and next(inv[categorieId]) == nil then inv[categorieId] = nil end
    if next(inv) == nil then entity.inventaire = nil end
end

local function Verifier(entity, categorieId, index)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    local categorie = Inventaire.Get(categorieId)
    if not categorie then return nil, "onglet inconnu." end
    index = tonumber(index)
    if not index or index < 1 or index > Inventaire.Capacite(categorieId) then
        return nil, string.format("l'onglet %s n'a pas d'emplacement %s.", categorie.label, tostring(index))
    end
    return categorie, index
end

-- Ce qu'un emplacement de sac accepte : un SAC dans Sacs, une SACOCHE dans
-- Saccoches, une ceinture sur la Ceinture, une tente dans Saccoches. Chacun a
-- sa place, et seulement la sienne (le MJ, 16 octobre 2026 ; une sacoche
-- allait jusque-la dans les deux). `contenu` : ce que tient un emplacement
-- ({ sac = id } ou { tente = id }). true, ou false et la raison.
local PLACE_DE = { sac = "sacs", sacoche = "saccoches", ceinture = "ceintures" }
local NOM_PLACE = { sacs = "Sacs", saccoches = "Saccoches", ceintures = "Ceinture" }
function Inventaire.PeutPorter(categorieId, contenu)
    if type(contenu) ~= "table" then return true end
    local voulu
    if contenu.tente then
        voulu = "saccoches"
    elseif contenu.sac then
        voulu = PLACE_DE[LCM.Sacs.Nature(contenu.sac)]
    else
        return true
    end
    if voulu == categorieId then return true end
    local quoi = contenu.tente and "une tente" or ({ sac = "un sac", sacoche = "une sacoche",
        ceinture = "une ceinture" })[LCM.Sacs.Nature(contenu.sac)]
    return false, string.format("%s se porte dans un emplacement %s.", quoi, NOM_PLACE[voulu] or voulu)
end

-- Pose un sac (ou une devise, selon l'onglet) dans un emplacement libre.
-- `forcer` : poser sans verifier la nature. Reserve a la MIGRATION — un sac
-- deja porte avant que la regle existe reste porte. La regle vaut pour ce qu'on
-- range aujourd'hui, pas pour reprendre ce qui etait la hier.
function Inventaire.Poser(entity, categorieId, index, id, forcer)
    local categorie, i = Verifier(entity, categorieId, index)
    if not categorie then return false, i end
    if categorie.cristaux then return false, "cet emplacement ne porte rien : il range les cristaux entamés." end
    -- La ceinture : on pose un objet « ceinture » PAR-DESSUS ses cases de base,
    -- qui gardent ce qu'on y avait range.
    if categorie.ceinture then
        local sac = LCM.Sacs.Get(id)
        if not (sac and LCM.Sacs.EstCeinture(sac)) then
            return false, "cet emplacement n'accepte qu'une ceinture."
        end
        if Inventaire.Emplacement(entity, categorieId, i).sac then
            return false, "une ceinture est déjà portée : retire-la d'abord."
        end
        EmplacementPourEcrire(entity, categorieId, i).sac = sac.id
        return true
    end
    if Inventaire.Emplacement(entity, categorieId, i) then
        return false, "cet emplacement est déjà occupé."
    end
    -- Une TENTE (« tentes/<id> ») ne se porte que sur un emplacement de sacoche
    -- (le MJ, 10 octobre 2026).
    local tenteId = categorie.contient == "sac" and tostring(id or ""):match("^tentes/(.+)$")
    if tenteId then
        local tente = LCM.Tentes and LCM.Tentes.Get(tenteId)
        if not tente then return false, "tente inconnue." end
        if categorieId ~= "saccoches" then return false, "une tente se porte dans un emplacement de sacoche." end
        RangeePourEcrire(entity, categorieId)[i] = { tente = tente.id }
    elseif categorie.contient == "sac" then
        local sac = LCM.Sacs.Get(id)
        if not sac then return false, "cet emplacement n'accepte qu'un sac." end
        if LCM.Sacs.EstCeinture(sac) then
            return false, "une ceinture se porte sur l'emplacement Ceinture."
        end
        -- Chacun sa place (Inventaire.PeutPorter). `forcer` : la migration,
        -- qui laisse porte ce qui l'etait avant que la regle existe.
        if not forcer then
            local ok, raison = Inventaire.PeutPorter(categorieId, { sac = sac.id })
            if not ok then return false, raison end
        end
        RangeePourEcrire(entity, categorieId)[i] = { sac = sac.id }
    else
        local devise = LCM.Devises.Get(id)
        if not devise then return false, "cet emplacement n'accepte qu'une devise." end
        RangeePourEcrire(entity, categorieId)[i] = { devise = devise.id, solde = 0 }
    end
    return true
end

-- Retire ce que tient un emplacement. Un sac qui contient quelque chose est
-- refuse : on ne jette pas son contenu en douce.
-- Ce que Retirer dirait, sans rien retirer : pour ne proposer « Échanger » ou
-- « Jeter » que lorsque c'est possible, et dire pourquoi sinon.
function Inventaire.PeutRetirer(entity, categorieId, index)
    local categorie, i = Verifier(entity, categorieId, index)
    if not categorie then return false, i end
    local e = Inventaire.Emplacement(entity, categorieId, i)
    if categorie.cristaux then return false, "« Cristaux en cours d'usage » ne se retire pas." end
    if categorie.ceinture then
        if not (e and e.sac) then return false, "aucune ceinture posée : ses cases de base restent." end
        -- Les cases de l'objet, au-dela de la base, doivent etre vides : on ne
        -- fait pas disparaitre ce qu'elles tiennent.
        local base = Inventaire.Contenant(e).base
        for case in pairs(type(e.cases) == "table" and e.cases or VIDE) do
            if (tonumber(case) or 0) > base then
                return false, string.format("vide d'abord les cases au-delà de %d.", base)
            end
        end
        return true
    end
    if not e then return false, "cet emplacement est déjà vide." end
    if type(e.cases) == "table" and next(e.cases) ~= nil then
        return false, "ce sac n'est pas vide : vide-le d'abord."
    end
    return true
end

function Inventaire.Retirer(entity, categorieId, index)
    local _, i = Verifier(entity, categorieId, index)
    if not _ then return false, i end
    if EstPoche(categorieId) then return false, "« Cristaux en cours d'usage » ne se retire pas." end
    local e = Inventaire.Emplacement(entity, categorieId, i)
    if EstCeinture(categorieId) then
        local ok, raison = Inventaire.PeutRetirer(entity, categorieId, i)
        if not ok then return false, raison end
        e.sac = nil
        -- Redevenue nue et sans rien dedans : la table s'efface.
        if not (type(e.cases) == "table" and next(e.cases) ~= nil) then
            entity.inventaire[categorieId][i] = nil
            Nettoyer(entity, categorieId)
        end
        return true
    end
    if not e then return false, "cet emplacement est déjà vide." end
    if type(e.cases) == "table" and next(e.cases) ~= nil then
        return false, "ce sac n'est pas vide : vide-le d'abord."
    end
    entity.inventaire[categorieId][i] = nil
    Nettoyer(entity, categorieId)
    return true
end

-- Deplace ce que tient un emplacement vers un autre, contenu compris : un sac
-- garde ses cases. L'arrivee doit accepter la meme chose que le depart (un sac
-- ne part pas dans l'onglet des devises). Si l'arrivee est OCCUPEE, les deux
-- echangent leur place : c'est ainsi qu'on reorganise ses sacs (16 octobre
-- 2026 ; c'etait refuse, et il fallait passer par un emplacement libre).
function Inventaire.Deplacer(entity, categorieId, index, versCategorieId, versIndex)
    local depart, i = Verifier(entity, categorieId, index)
    if not depart then return false, i end
    local arrivee, j = Verifier(entity, versCategorieId, versIndex)
    if not arrivee then return false, j end
    if depart.ceinture or arrivee.ceinture then
        return false, "la ceinture ne change pas d'emplacement."
    end
    if depart.cristaux or arrivee.cristaux then
        return false, "« Cristaux en cours d'usage » ne change pas d'emplacement."
    end
    local e = Inventaire.Emplacement(entity, categorieId, i)
    if not e then return false, "cet emplacement est vide." end
    if depart.id == arrivee.id and i == j then return false, "c'est déjà là." end
    if arrivee.contient ~= depart.contient then
        return false, string.format("l'onglet %s n'accepte pas ça.", arrivee.label)
    end
    -- Chacun sa place : ce qui part, et ce qui revient en echange.
    local ok, raison = Inventaire.PeutPorter(arrivee.id, e)
    if not ok then return false, raison end
    local occupant = Inventaire.Emplacement(entity, versCategorieId, j)
    ok, raison = Inventaire.PeutPorter(depart.id, occupant)
    if not ok then return false, raison end
    RangeePourEcrire(entity, arrivee.id)[j] = e
    RangeePourEcrire(entity, depart.id)[i] = occupant
    Nettoyer(entity, depart.id)
    return true
end

-- ===== Lacher un sac, et le ramasser (Core/SacsAuSol.lua) =================

-- Sort un sac (ou une tente) de son emplacement AVEC tout ce qu'il contient,
-- pour le poser au sol. Rend l'emplacement tel quel (pour le reposer si le
-- lacher n'aboutit pas) et ce qu'il contient, regroupe par entree : { sac =
-- id, tente = id, objets = { { entree, quantite } } }. La ceinture ne se lache
-- pas : ses cases de base restent. nil et la raison sinon.
function Inventaire.Lacher(entity, categorieId, index)
    local categorie, i = Verifier(entity, categorieId, index)
    if not categorie then return nil, i end
    if categorie.ceinture then return nil, "la ceinture ne se lâche pas : ses cases de base restent." end
    if categorie.cristaux then return nil, "« Cristaux en cours d'usage » ne se lâche pas." end
    local e = Inventaire.Emplacement(entity, categorieId, i)
    if not (e and (e.sac or e.tente)) then return nil, "rien à lâcher ici." end
    local objets, rang = {}, {}
    local cases = {}
    for case in pairs(type(e.cases) == "table" and e.cases or VIDE) do cases[#cases + 1] = case end
    table.sort(cases, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    for _, case in ipairs(cases) do
        local c = e.cases[case]
        if type(c) == "table" and c.ref then
            local q = math.max(1, math.floor(tonumber(c.quantite) or 1))
            local exemplaires = LCM.Exemplaires.Assurer(c)
            if rang[c.ref] then
                local precedent = objets[rang[c.ref]]
                if exemplaires then
                    for _, x in ipairs(exemplaires) do precedent.exemplaires[#precedent.exemplaires + 1] = LCM.Copie(x) end
                end
                objets[rang[c.ref]].quantite = objets[rang[c.ref]].quantite + q
            else
                objets[#objets + 1] = { entree = c.ref, quantite = q, exemplaires = LCM.Copie(exemplaires) }
                rang[c.ref] = #objets
            end
        end
    end
    entity.inventaire[categorieId][i] = nil
    Nettoyer(entity, categorieId)
    return e, { sac = e.sac, tente = e.tente, objets = objets }
end

-- Repose un emplacement tel que Lacher l'a rendu : le lacher n'a pas abouti.
-- L'emplacement a pu etre occupe entre-temps : on le dit, sans ecraser.
function Inventaire.Reposer(entity, categorieId, index, emplacement)
    if Inventaire.Emplacement(entity, categorieId, index) then
        return false, "l'emplacement a été repris entre-temps."
    end
    RangeePourEcrire(entity, categorieId)[index] = emplacement
    return true
end

-- Un emplacement libre ou porter ce sac ou cette tente (`contenu` : { sac =
-- id } ou { tente = id }), selon sa nature (Inventaire.PeutPorter). nil sinon.
function Inventaire.PlacePour(entity, contenu)
    for _, categorie in ipairs(Inventaire.categories) do
        if categorie.contient == "sac" and not categorie.ceinture and not categorie.cristaux
            and Inventaire.PeutPorter(categorie.id, contenu) then
            for index = 1, Inventaire.Capacite(categorie.id) do
                if not Inventaire.Emplacement(entity, categorie.id, index) then
                    return categorie.id, index
                end
            end
        end
    end
    return nil
end

-- Range une liste { { entree, quantite } } dans les cases d'UN sac porte, en
-- piles bornees par la pile maximale de chaque entree. Rend ce qui n'a pas
-- trouve de case, dans la meme forme (vide si tout tient).
function Inventaire.RemplirSac(entity, categorieId, index, objets)
    local reste = {}
    local e = Inventaire.Emplacement(entity, categorieId, index)
    local total = e and Inventaire.Cases(e) or 0
    local case = 1
    for _, o in ipairs(objets or VIDE) do
        local element = LCM.Compendium.Resoudre(o.entree)
        local pile = math.max(1, math.floor(tonumber(element and element.pileMax) or 0))
        if not (element and element.pileMax) then pile = math.huge end
        local a = math.max(0, math.floor(tonumber(o.quantite) or 0))
        local curseur = 1
        while a > 0 do
            while case <= total and (Inventaire.Case(e, case) or not Inventaire.Accepte(e, case, o.entree)) do
                case = case + 1
            end
            if case > total then break end
            local n = math.min(a, pile)
            local ok = Inventaire.Ranger(entity, categorieId, index, case, o.entree, n,
                LCM.Exemplaires.Tranche(o.exemplaires, curseur, n))
            if not ok then break end
            curseur = curseur + n
            a, case = a - n, case + 1
        end
        if a > 0 then reste[#reste + 1] = { entree = o.entree, quantite = a,
            exemplaires = LCM.Exemplaires.Tranche(o.exemplaires, curseur, a) } end
        case = 1
    end
    return reste
end

-- Transvaser : ranger `quantite` d'une entree dans UN sac porte precis — celui
-- sur lequel on l'a lachee (le MJ, 16 octobre 2026 : glisser un objet sur
-- l'emplacement d'un autre sac le fait passer dedans, il ne s'equipe pas).
-- Les piles deja la sont completees d'abord, puis les cases libres qui
-- l'acceptent. Tout ou rien : si tout ne tient pas, rien ne bouge. true, ou
-- false et la raison.
function Inventaire.Transvaser(entity, categorieId, index, ref, quantite, exemplaires)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    local contenant = Inventaire.Contenant(e)
    if not contenant then return false, "aucun sac dans cet emplacement." end
    quantite = math.floor(tonumber(quantite) or 1)
    if quantite < 1 then return false, "rien à transvaser." end
    local element = LCM.Compendium.Resoudre(ref)
    if not element then return false, "entrée inconnue du compendium." end
    -- Les cristaux entames ont leur poche, et la poche n'a qu'eux.
    local entame = Entame(exemplaires)
    if e.cristaux and not entame then return false, POCHE_SEULEMENT end
    if entame and not e.cristaux then return false, DANS_LA_POCHE end
    if entame then return Inventaire.Deposer(entity, ref, quantite, exemplaires) end
    local pile = tonumber(element.pileMax) and math.max(1, math.floor(element.pileMax)) or math.huge
    local total, reste, plan, raison = Inventaire.Cases(e), quantite, {}, nil
    -- Les piles de la meme entree, d'abord.
    for case = 1, total do
        local c = Inventaire.Case(e, case)
        if reste > 0 and c and LCM.Compendium.MemeEntree(c.ref, ref) then
            local place = pile - (tonumber(c.quantite) or 1)
            if place > 0 then
                local n = math.min(place, reste)
                plan[#plan + 1] = { case = case, pile = c, quantite = (tonumber(c.quantite) or 1) + n }
                reste = reste - n
            end
        end
    end
    -- Puis les cases libres qui l'acceptent.
    for case = 1, total do
        if reste > 0 and not Inventaire.Case(e, case) then
            local ok, pourquoi = Inventaire.Accepte(e, case, ref)
            if ok then
                local n = math.min(pile, reste)
                plan[#plan + 1] = { case = case, quantite = n }
                reste = reste - n
            else
                raison = raison or pourquoi
            end
        end
    end
    if reste > 0 then
        return false, raison or string.format("pas assez de place dans %s.",
            tostring(contenant.element and contenant.element.label or "ce sac"))
    end
    local copies, erreur = LCM.Exemplaires.Lire(ref, quantite, exemplaires)
    if erreur then return false, erreur end
    copies = copies or LCM.Exemplaires.CreerListe(ref, quantite)
    local curseur = 1
    for _, etape in ipairs(plan) do
        local nombre = etape.quantite - (etape.pile and (tonumber(etape.pile.quantite) or 1) or 0)
        local tranche = LCM.Exemplaires.Tranche(copies, curseur, nombre)
        if etape.pile then
            LCM.Exemplaires.Ajouter(etape.pile, tranche)
            etape.pile.quantite = etape.quantite
        else Inventaire.Ranger(entity, categorieId, index, etape.case, ref, etape.quantite, tranche) end
        curseur = curseur + nombre
    end
    return true
end

-- Le solde d'une devise (nombre entier, zero au moins).
function Inventaire.Solde(entity, categorieId, index, solde)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not e or not e.devise then return false, "aucune devise ici." end
    local n = tonumber(solde)
    if not n or n ~= math.floor(n) or n < 0 then
        return false, string.format("solde illisible (%s) : un nombre entier, zéro au moins.", tostring(solde))
    end
    e.solde = n
    return true
end

-- Ce qu'une case accepte : une entree du compendium. Une case de devise
-- n'accepte qu'une devise, une case ordinaire tout le reste qui se range
-- (objets, ressources, sacs).
-- Une tente se porte comme un sac (10 octobre 2026), mais elle ne recoit QUE
-- des accessoires de camping. Un accessoire, lui, se transporte aussi dans un
-- sac ordinaire. La tente, elle, ne se range pas dans un sac : elle s'equipe.
--
-- Lanternes et cristaux (23 octobre 2026) : ils n'existent pour le joueur que
-- s'il les porte (Core/Lanternes.lua). Il faut donc pouvoir les ranger.
local RANGEABLES = { objets = true, livres = true, ressources = true, sacs = true, accessoires_camping = true,
                     lanternes = true, cristaux = true, consommables = true }

function Inventaire.Accepte(emplacement, index, ref)
    local famille, entree = tostring(ref or ""):match("^([%w_]+)/(.+)$")
    if not LCM.Compendium.Resoudre(ref) then return false, "entrée inconnue du compendium." end
    -- La poche : des cristaux. Qu'ils soient ENTAMES se verifie la ou l'on
    -- connait leurs exemplaires (Ranger, Deposer, Empiler).
    if emplacement and emplacement.cristaux then
        if famille ~= "cristaux" then return false, POCHE_SEULEMENT end
        return true
    end
    if emplacement and emplacement.tente then
        if famille ~= "accessoires_camping" then
            return false, "une tente n'accueille que des accessoires de camping."
        end
        return true
    end
    if Inventaire.EstCaseDevise(emplacement, index) then
        if famille ~= "devises" then return false, "une case de devise n'accepte qu'une devise." end
    elseif famille == "devises" then
        -- Une monnaie cochee « Materiel » a une forme : elle se range comme un
        -- objet, dans n'importe quelle case (le MJ, 19 octobre 2026). Les
        -- autres n'existent qu'en solde de bourse.
        if not (LCM.Bourse and LCM.Bourse.EstMateriel(entree)) then
            return false, "cette monnaie ne se transporte pas : elle reste dans la bourse."
        end
    elseif not RANGEABLES[famille] then
        return false, "un sac accepte des objets, des livres, des ressources, des consommables, des accessoires de camping, des lanternes, des cristaux ou des sacoches."
    end
    -- Un contenant dans un contenant : seul un SAC en accepte, et il faut que
    -- le nouveau venu tienne — il occupe sa case plus toutes les siennes.
    if famille == "sacs" and emplacement and emplacement.ceinture then
        return false, "une ceinture ne contient pas de sac."
    end
    if famille == "sacs" then
        local hote = LCM.Sacs.Get(emplacement and emplacement.sac)
        if not hote then return false, "aucun sac ici." end
        if LCM.Sacs.EstSacoche(hote) then
            return false, "une sacoche ne contient ni sac ni sacoche."
        end
        local range = LCM.Compendium.Resoudre(ref)
        -- Un sac contient des SACOCHES, pas d'autres sacs (le MJ, 16 octobre
        -- 2026). Une ceinture, elle, se transporte : ce n'est pas un sac.
        if LCM.Sacs.Nature(range and range.id) == "sac" then
            return false, "un sac contient des sacoches, pas d'autres sacs."
        end
        local encombrement = LCM.Sacs.Encombrement(range and range.id)
        local libres = Inventaire.CasesLibres(emplacement)
        if encombrement > libres then
            return false, string.format("il faut %d places libres, il en reste %d.", encombrement, libres)
        end
    end
    return true
end

-- Combien de cases restent libres dans un sac, en comptant ce que les sacs
-- qu'il contient deja lui prennent.
function Inventaire.CasesLibres(emplacement)
    local total = Inventaire.Cases(emplacement)
    local pris = 0
    for index = 1, total do
        local c = Inventaire.Case(emplacement, index)
        if c then
            local famille = tostring(c.ref or ""):match("^([%w_]+)/")
            if famille == "sacs" then
                local dedans = LCM.Compendium.Resoudre(c.ref)
                pris = pris + LCM.Sacs.Encombrement(dedans and dedans.id)
            else
                pris = pris + 1
            end
        end
    end
    return math.max(0, total - pris)
end

-- Range une entree dans une case libre d'un sac.
function Inventaire.Ranger(entity, categorieId, index, case, ref, quantite, exemplaires)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not e or not (e.sac or e.tente or e.ceinture or e.cristaux) then return false, "aucun sac dans cet emplacement." end
    if e.cristaux and not Entame(exemplaires) then return false, POCHE_SEULEMENT end
    if Entame(exemplaires) and not e.cristaux then return false, DANS_LA_POCHE end
    local total = Inventaire.Cases(e)
    case = tonumber(case)
    if not case or case < 1 or case > total then return false, "ce sac n'a pas de case " .. tostring(case) .. "." end
    if Inventaire.Case(e, case) then return false, "cette case est déjà occupée." end
    local ok, raison = Inventaire.Accepte(e, case, ref)
    if not ok then return false, raison end
    quantite = tonumber(quantite or 1)
    if not quantite or quantite < 1 or quantite ~= math.floor(quantite) then
        return false, "quantité illisible : un nombre entier, 1 au moins."
    end
    local copies, erreur = LCM.Exemplaires.Lire(ref, quantite, exemplaires)
    if erreur then return false, erreur end
    copies = copies or LCM.Exemplaires.CreerListe(ref, quantite)
    e = EmplacementPourEcrire(entity, categorieId, index)
    e.cases = type(e.cases) == "table" and e.cases or {}
    -- Rangee sous son nom d'aujourd'hui : une entree d'avant un transfert
    -- (un coffre garni avant) ne fait pas une pile a part.
    e.cases[case] = { ref = LCM.Compendium.Canonique(ref), quantite = quantite, exemplaires = copies }
    return true
end

-- Change la quantite d'une case. La pile maximale de l'entree, si elle en a
-- une, borne : au-dessus, c'est refuse, pas rabote.
function Inventaire.Quantite(entity, categorieId, index, case, quantite)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    local c = Inventaire.Case(e, case)
    if not c then return false, "case vide." end
    local n = tonumber(quantite)
    if not n or n < 1 or n ~= math.floor(n) then
        return false, string.format("quantité illisible (%s) : un nombre entier, 1 au moins.", tostring(quantite))
    end
    local element = LCM.Compendium.Resoudre(c.ref)
    if element and element.pileMax and n > element.pileMax then
        return false, string.format("%s s'empile par %d au plus.", element.label, element.pileMax)
    end
    local liste = LCM.Exemplaires.Assurer(c)
    if liste then
        while #liste > n do table.remove(liste) end
        while #liste < n do liste[#liste + 1] = LCM.Exemplaires.Nouveau(c.ref) end
    end
    c.quantite = n
    return true
end

-- La premiere case libre qui accepte `ref` : dans le meme sac d'abord — on
-- scinde pour ranger a cote —, puis dans les autres. Nil s'il n'y en a pas.
function Inventaire.CaseLibrePour(entity, ref, categorieId, index)
    local function Dans(cat, i)
        local e = Inventaire.Emplacement(entity, cat, i)
        -- La poche n'est pas une case libre ordinaire : seul un cristal entame
        -- y va, et Deposer l'y envoie lui-meme.
        if not Inventaire.Contenant(e) or e.cristaux then return nil end
        for n = 1, Inventaire.Cases(e) do
            if not Inventaire.Case(e, n) and Inventaire.Accepte(e, n, ref) then return n end
        end
    end
    if categorieId then
        local n = Dans(categorieId, index)
        if n then return categorieId, index, n end
    end
    for _, categorie in ipairs(Inventaire.categories) do
        for i = 1, Inventaire.Capacite(categorie.id) do
            if not (categorie.id == categorieId and i == tonumber(index)) then
                local n = Dans(categorie.id, i)
                if n then return categorie.id, i, n end
            end
        end
    end
end

-- Combien une case peut encore recevoir de `ref` : sa pile maximale moins ce
-- qu'elle tient. Sans pileMax, rien ne borne (math.huge). Nil et la raison si
-- la case tient autre chose.
local function Place(element, c, ref, entrants)
    if c.ref ~= ref then return nil, "cette case est déjà occupée." end
    if Entame(c) ~= Entame(entrants) then
        return nil, "un cristal entamé et un cristal plein ne s'empilent pas ensemble."
    end
    -- Dans la poche, une pile par modele ET par pourcentage, sans maximum :
    -- chacun y garde sa charge sur son exemplaire.
    if Entame(c) then
        if Pourcent(c) ~= Pourcent(entrants) then
            return nil, "ces cristaux n'ont pas la même charge : ils ne s'empilent pas."
        end
        return math.huge
    end
    local max = element and tonumber(element.pileMax)
    if not max then return math.huge end
    local reste = max - (tonumber(c.quantite) or 1)
    if reste <= 0 then
        return nil, string.format("la pile est déjà pleine (%d).", max)
    end
    return reste
end

-- Ce qu'Empiler ferait, sans rien deplacer : combien passeraient. Nil et la
-- raison sinon.
function Inventaire.PeutEmpiler(entity, categorieId, index, case, versCategorieId, versIndex, versCase)
    local source = Inventaire.Case(Inventaire.Emplacement(entity, categorieId, index), case)
    local cible = Inventaire.Case(Inventaire.Emplacement(entity, versCategorieId, versIndex), versCase)
    if not source then return nil, "case vide." end
    if not cible then return nil, "rien sur quoi empiler." end
    if source == cible then return nil, "c'est la même pile." end
    local place, raison = Place(LCM.Compendium.Resoudre(source.ref), cible, source.ref, source.exemplaires)
    if not place then return nil, raison end
    return math.min(place, tonumber(source.quantite) or 1)
end

-- Reempile une pile sur une autre du meme objet (le MJ, 16 octobre 2026) :
-- la cible se remplit jusqu'a sa pile maximale, et ce qui n'y tient pas RESTE
-- dans la case de depart — 10 lachees sur 18 d'une pile de 20 en donnent 2,
-- et 8 demeurent. true et le nombre passe, ou false et la raison.
function Inventaire.Empiler(entity, categorieId, index, case, versCategorieId, versIndex, versCase)
    local n, raison = Inventaire.PeutEmpiler(entity, categorieId, index, case, versCategorieId, versIndex, versCase)
    if not n then return false, raison end
    local source = Inventaire.Case(Inventaire.Emplacement(entity, categorieId, index), case)
    local cible = Inventaire.Case(Inventaire.Emplacement(entity, versCategorieId, versIndex), versCase)
    LCM.Exemplaires.Assurer(cible)
    LCM.Exemplaires.Ajouter(cible, LCM.Exemplaires.Sortir(source, n))
    cible.quantite = (tonumber(cible.quantite) or 1) + n
    local reste = (tonumber(source.quantite) or 1) - n
    if reste > 0 then
        source.quantite = reste
    else
        Inventaire.Vider(entity, categorieId, index, case)
    end
    return true, n
end

-- Scinde une pile : `n` unites quittent la case pour une case VIDE, celle
-- qu'on designe (`vers` = { onglet, index, case }) ou, sans elle, la premiere
-- libre qui l'accepte (le MJ, 16 octobre 2026). Le nouveau tas est range
-- AVANT que l'ancien diminue : si le rangement est refuse, rien n'a bouge.
-- true, ou false et la raison.
function Inventaire.Scinder(entity, categorieId, index, case, n, vers)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    local c = Inventaire.Case(e, case)
    if not c then return false, "case vide." end
    local total = tonumber(c.quantite) or 1
    if total < 2 then return false, "une pile d'un seul ne se scinde pas." end
    n = tonumber(n)
    if not n or n ~= math.floor(n) or n < 1 or n >= total then
        return false, string.format("entre 1 et %d : il doit en rester au moins un dans la pile.", total - 1)
    end
    local cat, i, place
    if type(vers) == "table" then
        cat, i, place = vers.onglet, vers.index, vers.case
    else
        cat, i, place = Inventaire.CaseLibrePour(entity, c.ref, categorieId, index)
        if not cat then return false, "aucune case libre pour poser l'autre moitié." end
    end
    -- Scinder SUR une pile du meme objet l'y ajoute, si elle a la place.
    local deja = Inventaire.Case(Inventaire.Emplacement(entity, cat, i), place)
    if deja then
        if deja == c then return false, "c'est la même pile." end
        local libre, plein = Place(LCM.Compendium.Resoudre(c.ref), deja, c.ref, c.exemplaires)
        if not libre then return false, plein end
        if n > libre then return false, string.format("cette pile n'a de place que pour %d.", libre) end
        LCM.Exemplaires.Ajouter(deja, LCM.Exemplaires.Tranche(LCM.Exemplaires.Assurer(c), 1, n))
        deja.quantite = (tonumber(deja.quantite) or 1) + n
    else
        local ok, raison = Inventaire.Ranger(entity, cat, i, place, c.ref, n,
            LCM.Exemplaires.Tranche(LCM.Exemplaires.Assurer(c), 1, n))
        if not ok then return false, raison end
    end
    LCM.Exemplaires.Sortir(c, n)
    c.quantite = total - n
    return true
end

function Inventaire.Vider(entity, categorieId, index, case)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not Inventaire.Case(e, case) then return false, "case déjà vide." end
    e.cases[tonumber(case)] = nil
    -- La poche se resserre : sans limite, elle n'a pas de place a garder, et
    -- un trou au milieu de la liste ne dirait rien.
    if e.cristaux then
        local restes, indices = {}, {}
        for i in pairs(e.cases) do indices[#indices + 1] = tonumber(i) end
        table.sort(indices)
        for rang, i in ipairs(indices) do restes[rang] = e.cases[i] end
        e.cases = restes
    end
    if next(e.cases) == nil then e.cases = nil end
    -- Une ceinture nue, ou la poche des cristaux, redevenue vide n'a plus
    -- rien a retenir.
    if (e.ceinture and not e.sac or e.cristaux) and not e.cases then
        entity.inventaire[categorieId][tonumber(index)] = nil
        Nettoyer(entity, categorieId)
    end
    return true
end

-- ===== Reprise des sacs d'avant =============================================
-- L'inventaire precedent rangeait les sacs portes en liste (entity.sacs.sac).
-- Ils sont deplaces, pas effaces : dans les emplacements de sacs, puis de
-- saccoches ; ce qui ne tient nulle part reste ou il etait.
LCM.WhenReady(function()
    if not LCM.db or type(LCM.db.entities) ~= "table" then return end
    for _, entity in pairs(LCM.db.entities) do
        local ancien = type(entity.sacs) == "table" and entity.sacs.sac
        if type(ancien) == "table" then
            local restants = {}
            for _, id in ipairs(ancien) do
                local place = false
                for _, categorieId in ipairs({ "sacs", "saccoches" }) do
                    for index = 1, Inventaire.Capacite(categorieId) do
                        if not place and Inventaire.Poser(entity, categorieId, index, id, true) then place = true end
                    end
                end
                if not place then restants[#restants + 1] = id end
            end
            entity.sacs.sac = #restants > 0 and restants or nil
            if next(entity.sacs) == nil then entity.sacs = nil end
        end
    end
end)

-- Ou se trouve une entree dans les sacs : l'onglet, l'emplacement et la case
-- de la premiere pile qui la contient, ou nil. Sert a l'equipement, qui ne
-- prend que ce que le personnage porte dans ses sacs.
function Inventaire.Chercher(entity, ref)
    if type(entity) ~= "table" then return nil end
    for _, categorie in ipairs(Inventaire.categories) do
        for index = 1, Inventaire.Capacite(categorie.id) do
            local emplacement = Inventaire.Emplacement(entity, categorie.id, index)
            for case, c in pairs(emplacement and type(emplacement.cases) == "table" and emplacement.cases or VIDE) do
                if type(c) == "table" and LCM.Compendium.MemeEntree(c.ref, ref) then return categorie.id, index, case end
            end
        end
    end
    return nil
end

-- Sort UN exemplaire d'une entree des sacs : la pile baisse, la derniere
-- unite libere la case. false et la raison si elle n'y est pas.
function Inventaire.Prendre(entity, ref)
    local categorieId, index, case = Inventaire.Chercher(entity, ref)
    if not categorieId then return false, "absent des sacs." end
    local c = Inventaire.Case(Inventaire.Emplacement(entity, categorieId, index), case)
    local quantite = tonumber(c.quantite) or 1
    local exemplaires = LCM.Exemplaires.Sortir(c, 1)
    if quantite > 1 then
        c.quantite = quantite - 1
        return true, exemplaires and exemplaires[1]
    end
    Inventaire.Vider(entity, categorieId, index, case)
    return true, exemplaires and exemplaires[1]
end

-- Toutes les cases des sacs qui tiennent `ref`, dans l'ordre ou on les voit :
-- { categorie, index, case, pile }. Lecture seule — une pile d'avant les
-- exemplaires n'en recoit pas ici.
function Inventaire.Piles(entity, ref)
    local out = {}
    if type(entity) ~= "table" then return out end
    for _, categorie in ipairs(Inventaire.categories) do
        for index = 1, Inventaire.Capacite(categorie.id) do
            local emplacement = Inventaire.Emplacement(entity, categorie.id, index)
            local total = emplacement and Inventaire.Cases(emplacement) or 0
            for case = 1, total do
                local c = Inventaire.Case(emplacement, case)
                if type(c) == "table" and LCM.Compendium.MemeEntree(c.ref, ref) then
                    out[#out + 1] = { categorie = categorie.id, index = index, case = case, pile = c }
                end
            end
        end
    end
    return out
end

-- Sort CET exemplaire-la des sacs, pas le premier venu de sa pile : c'est lui
-- qui vient d'etre detruit, ses voisins n'y sont pour rien. true, ou false et
-- la raison s'il n'est plus dans aucun sac.
function Inventaire.RetirerExemplaire(entity, ref, exemplaireId)
    for _, p in ipairs(Inventaire.Piles(entity, ref)) do
        local liste = type(p.pile.exemplaires) == "table" and p.pile.exemplaires or VIDE
        for i, e in ipairs(liste) do
            if type(e) == "table" and e.id == exemplaireId then
                local quantite = tonumber(p.pile.quantite) or 1
                if quantite > 1 then
                    table.remove(liste, i)
                    p.pile.quantite = quantite - 1
                else
                    Inventaire.Vider(entity, p.categorie, p.index, p.case)
                end
                return true
            end
        end
    end
    return false, "cet exemplaire n'est plus dans les sacs."
end

-- ===== Plusieurs cases d'un coup (la selection, 20 octobre 2026) ===========
-- `sources` : { { onglet, index, case, ref }, ... } — ce que le joueur a
-- selectionne, celle qu'il a glissee en tete. `ref` est ce qu'il a VU dans la
-- case : si elle tient autre chose, ou plus rien, on ne bouge pas.
--
-- TOUT OU RIEN : le geste se joue d'abord sur une copie du personnage. Quatre
-- objets pour deux places, c'est un refus qui le dit, pas deux objets ranges
-- et deux laisses en route.

local function LireSources(entity, sources)
    local out = {}
    for _, s in ipairs(sources) do
        local c = Inventaire.Case(Inventaire.Emplacement(entity, s.onglet, s.index), s.case)
        if not (type(c) == "table" and c.ref == s.ref) then
            return nil, "un objet de la sélection n'est plus à sa place : rien n'a bougé."
        end
        out[#out + 1] = { source = s, pile = c }
    end
    return out
end

local function DeplacerGroupeSur(entity, sources, vers)
    local e = Inventaire.Emplacement(entity, vers.onglet, vers.index)
    local contenant = Inventaire.Contenant(e)
    if not contenant then return false, "aucun sac ici." end
    local lues, raison = LireSources(entity, sources)
    if not lues then return false, raison end
    -- Ce qui est deja dans ce sac y reste.
    local lot = {}
    for _, l in ipairs(lues) do
        if not (l.source.onglet == vers.onglet and l.source.index == vers.index) then
            lot[#lot + 1] = { source = l.source, ref = l.pile.ref, quantite = tonumber(l.pile.quantite) or 1,
                              exemplaires = LCM.Copie(LCM.Exemplaires.Assurer(l.pile)) }
        end
    end
    if #lot == 0 then return true, 0 end
    -- Tout quitte sa place d'abord : deux objets qui changent de sac ne se
    -- disputent pas une case qu'un troisieme s'apprete a liberer.
    for _, o in ipairs(lot) do Inventaire.Vider(entity, o.source.onglet, o.source.index, o.source.case) end
    for rang, o in ipairs(lot) do
        local ok, pourquoi
        -- Celle qu'on a lachee va dans la case visee, si elle est libre ; les
        -- autres, la ou ce sac a de la place.
        if rang == 1 and o.source == sources[1] and vers.case and not Inventaire.Case(e, vers.case) then
            ok, pourquoi = Inventaire.Ranger(entity, vers.onglet, vers.index, vers.case, o.ref, o.quantite, o.exemplaires)
        else
            ok, pourquoi = Inventaire.Transvaser(entity, vers.onglet, vers.index, o.ref, o.quantite, o.exemplaires)
        end
        if not ok then
            local nom = contenant.element and contenant.element.label or "ce sac"
            if tostring(pourquoi):match("^pas assez de place") then
                pourquoi = string.format("%d objets à ranger, et %s n'a pas la place pour tous", #lot, nom)
            end
            return false, tostring(pourquoi):gsub("%.$", "") .. " : rien n'a bougé."
        end
    end
    return true, #lot
end

-- Ce que donnerait le deplacement, sans rien toucher.
function Inventaire.PeutDeplacerGroupe(entity, sources, vers)
    if type(entity) ~= "table" or type(sources) ~= "table" or #sources == 0 then return false, "rien à déplacer." end
    return DeplacerGroupeSur(LCM.Copie(entity), sources, vers)
end

-- Range toute la selection dans le sac `vers` ({ onglet, index, case? }).
-- true et combien ont change de sac, ou false et la raison.
function Inventaire.DeplacerGroupe(entity, sources, vers)
    local ok, raison = Inventaire.PeutDeplacerGroupe(entity, sources, vers)
    if not ok then return false, raison end
    return DeplacerGroupeSur(entity, sources, vers)
end

-- Detruit toute la selection. Si l'une des cases a change depuis qu'on l'a
-- vue, on ne detruit RIEN : on ne jette jamais ce qui a pris sa place.
function Inventaire.ViderGroupe(entity, sources)
    local lues, raison = LireSources(entity, sources or {})
    if not lues then return false, raison end
    for _, l in ipairs(lues) do Inventaire.Vider(entity, l.source.onglet, l.source.index, l.source.case) end
    return true, #lues
end

-- Prevoir ou ranger `quantite` d'une entree dans les CASES des sacs, sans rien
-- ecrire. Rend le plan et ce qui ne tient pas.
--
-- Ce qui s'empile COMPLETE d'abord les piles deja la, jusqu'a leur maximum, et
-- n'ouvre une case que pour le reste. Chaque eau recoltee ouvrait sa propre
-- case : « Eau », « Eau x9 », « Eau »… (13 octobre 2026). Sans pile maximale,
-- une entree s'empile sans borne (Inventaire.Quantite).
local function PrevoirCases(entity, ref, quantite, entrants)
    local element = LCM.Compendium.Resoudre(ref)
    local pileMax = element and element.pileMax
    local reste = quantite
    local plan = {}
    -- Des cristaux entames : sur la pile de leur modele et de leur
    -- pourcentage dans la poche, ou sur sa case libre (a la suite). La poche
    -- est sans limite : tout y tient. Deposer les fait arriver UN PAR UN, pour
    -- que chacun trouve la pile de son pourcentage.
    if Entame(entrants) then
        local pourcent = Pourcent(entrants)
        for _, categorie in ipairs(Inventaire.categories) do
            if categorie.cristaux then
                local e = Inventaire.Emplacement(entity, categorie.id, 1)
                local total = Inventaire.Cases(e)
                for case = 1, total do
                    local c = Inventaire.Case(e, case)
                    if c and c.ref == ref and Pourcent(c) == pourcent then
                        return { { pile = c, quantite = (tonumber(c.quantite) or 1) + quantite } }, 0
                    end
                end
                for case = 1, total do
                    if not Inventaire.Case(e, case) then
                        return { { categorie = categorie.id, index = 1, case = case, quantite = quantite } }, 0
                    end
                end
            end
        end
        return plan, quantite
    end
    for _, categorie in ipairs(Inventaire.categories) do
        for index = 1, Inventaire.Capacite(categorie.id) do
            local emplacement = Inventaire.Emplacement(entity, categorie.id, index)
            -- Dans l'ordre des cases : la premiere pile du premier sac se
            -- remplit en premier, comme on la voit.
            local total = emplacement and Inventaire.Cases(emplacement) or 0
            for case = 1, total do
                local c = Inventaire.Case(emplacement, case)
                if reste > 0 and type(c) == "table" and LCM.Compendium.MemeEntree(c.ref, ref)
                    and not emplacement.cristaux then
                    local dedans = tonumber(c.quantite) or 1
                    local ajout = pileMax and math.min(reste, pileMax - dedans) or reste
                    if ajout > 0 then
                        plan[#plan + 1] = { pile = c, quantite = dedans + ajout }
                        reste = reste - ajout
                    end
                end
            end
        end
    end
    for _, categorie in ipairs(Inventaire.categories) do
        for index = 1, Inventaire.Capacite(categorie.id) do
            local emplacement = Inventaire.Emplacement(entity, categorie.id, index)
            if reste > 0 and emplacement then
                local total, places = Inventaire.Cases(emplacement)
                -- Une case qui n'accepte pas l'entree (une dague dans une tente)
                -- n'est pas une place libre pour elle : on passe au sac suivant.
                for case = 1, math.min(total, places) do
                    if reste > 0 and not emplacement.cristaux and not Inventaire.Case(emplacement, case)
                        and Inventaire.Accepte(emplacement, case, ref) then
                        local pose = pileMax and math.min(reste, pileMax) or reste
                        plan[#plan + 1] = { categorie = categorie.id, index = index, case = case, quantite = pose }
                        reste = reste - pose
                    end
                end
            end
        end
    end
    return plan, reste
end

-- Prevoir ou PORTER des contenants : un sac, une sacoche ou une ceinture
-- s'equipe dans l'emplacement fait pour lui avant d'etre range comme un objet.
-- Range comme un objet, un sac achete echouait : sans sac porte, ou avec des
-- sacoches seulement (qui ne contiennent pas de sac), il n'avait nulle part ou
-- aller (13 octobre 2026). Rend le plan et combien restent a ranger en case.
local function PrevoirEmplacements(entity, sac, quantite)
    local nature = LCM.Sacs.Nature(sac)
    -- Ou chaque nature se porte : chacune a sa place, et seulement la sienne
    -- (Inventaire.PeutPorter). Une sacoche allait aussi dans Sacs a defaut de
    -- place ; plus depuis le 16 octobre 2026.
    local rangees = nature == "ceinture" and { "ceintures" }
        or nature == "sacoche" and { "saccoches" }
        or { "sacs" }
    local plan, reste = {}, quantite
    for _, categorieId in ipairs(rangees) do
        local categorie = Inventaire.Get(categorieId)
        for index = 1, Inventaire.Capacite(categorieId) do
            if reste > 0 then
                local e = Inventaire.Emplacement(entity, categorieId, index)
                -- La ceinture existe toujours (ses cases de base) : elle est
                -- libre tant qu'aucun objet ceinture n'y est pose.
                local libre = (categorie and categorie.ceinture) and not (e and e.sac) or not e
                if libre then
                    plan[#plan + 1] = { categorie = categorieId, index = index }
                    reste = reste - 1
                end
            end
        end
    end
    return plan, reste
end

-- Ranger une entree SANS dire ou. C'est ce dont ont besoin la recolte, l'achat
-- et l'echange, qui donnent un objet sans savoir ce que le joueur a sur lui.
--
-- Les cases de devise sont sautees : une devise ne se range pas comme un objet,
-- et une herbe n'a rien a faire dans un porte-monnaie.
--
-- On PREVOIT avant d'ecrire : tout tient, ou rien ne bouge. Les appelants
-- rendent ce qu'ils ont pris quand ca echoue, et une moitie rangee serait une
-- moitie dupliquee.
function Inventaire.Deposer(entity, ref, quantite, exemplaires)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    if not LCM.Compendium.Resoudre(ref) then
        return false, "entrée inconnue du compendium."
    end
    ref = LCM.Compendium.Canonique(ref)
    -- Plusieurs cristaux entames (une pile lachee, un echange) : un par un,
    -- chacun vers la pile de son pourcentage. La poche n'a pas de limite :
    -- aucun ne peut manquer de place, il n'y a rien a defaire.
    if Entame(exemplaires) and type(exemplaires) == "table" and #exemplaires > 1 then
        local copies, erreur = LCM.Exemplaires.Lire(ref, tonumber(quantite) or #exemplaires, exemplaires)
        if erreur then return false, erreur end
        for _, x in ipairs(copies) do
            local ok, raison = Inventaire.Deposer(entity, ref, 1, { x })
            if not ok then return false, raison end
        end
        return true
    end
    -- Une tente ne se range pas dans un sac : elle s'equipe, sur le premier
    -- emplacement de sacoche libre. Sans quoi on ne pourrait ni l'acheter ni
    -- la recevoir.
    if tostring(ref or ""):match("^tentes/") then
        for index = 1, Inventaire.Capacite("saccoches") do
            if not Inventaire.Emplacement(entity, "saccoches", index) then
                return Inventaire.Poser(entity, "saccoches", index, ref)
            end
        end
        return false, "aucun emplacement de sacoche libre pour la tente."
    end
    quantite = tonumber(quantite or 1)
    if not quantite or quantite < 1 or quantite ~= math.floor(quantite) then
        return false, "quantité illisible : un nombre entier, 1 au moins."
    end

    -- Un contenant se PORTE d'abord, la ou sa nature le veut ; ce qui ne
    -- trouve pas d'emplacement libre se range ensuite comme un objet.
    local portes, aRanger = {}, quantite
    local sacId = tostring(ref or ""):match("^sacs/(.+)$")
    local sac = sacId and LCM.Sacs.Get(sacId)
    if sac then portes, aRanger = PrevoirEmplacements(entity, sac, quantite) end

    local plan, reste = {}, 0
    if aRanger > 0 then plan, reste = PrevoirCases(entity, ref, aRanger, exemplaires) end
    if reste > 0 then
        if sac then
            local nature = LCM.Sacs.Nature(sac)
            local ou = nature == "ceinture" and "l'emplacement Ceinture est déjà pris"
                or nature == "sacoche" and "aucun emplacement de sacoche libre"
                or "aucun emplacement de sac libre"
            return false, ou .. ", et aucun sac ne peut le contenir."
        end
        return false, "aucune place libre."
    end

    local copies, erreur = LCM.Exemplaires.Lire(ref, quantite, exemplaires)
    if erreur then return false, erreur end
    copies = copies or LCM.Exemplaires.CreerListe(ref, quantite)
    local curseur = 1
    for _, etape in ipairs(portes) do
        local ok, raison = Inventaire.Poser(entity, etape.categorie, etape.index, sac.id)
        if not ok then return false, raison end
    end
    for _, etape in ipairs(plan) do
        if etape.pile then
            local ajout = etape.quantite - (tonumber(etape.pile.quantite) or 1)
            LCM.Exemplaires.Ajouter(etape.pile, LCM.Exemplaires.Tranche(copies, curseur, ajout))
            curseur = curseur + ajout
            etape.pile.quantite = etape.quantite
        else
            local ok, raison = Inventaire.Ranger(entity, etape.categorie, etape.index, etape.case, ref, etape.quantite,
                LCM.Exemplaires.Tranche(copies, curseur, etape.quantite))
            if not ok then return false, raison end
            curseur = curseur + etape.quantite
        end
    end
    return true
end
