-- Identite physique separee du modele : une pile porte une liste ordonnee
-- d'exemplaires. Aucun de ces etats n'est copie dans le compendium.
--
-- L'etat d'un objet vit ICI, sur l'exemplaire (20 octobre 2026) : `usure`
-- (ce qu'il a perdu d'etat) et `viesPerdues`, absents tant qu'il est neuf.
-- Ils etaient sur le personnage, au nom du modele : six kits de crochetage
-- partageaient un seul compteur, et un kit detruit le leguait au suivant.
--
-- Les CRISTAUX ont aussi leurs exemplaires (23 octobre 2026) : un cristal
-- entame porte `charge`, les secondes d'eclairage qui lui restent
-- (Core/Lanternes.lua). Absente, il est plein. Elle le suit comme l'usure suit
-- une arme : d'un sac a l'autre, dans un coffre, dans un echange.
local _, LCM = ...
local X = {}
LCM.Exemplaires = X
local function Donnees(v, vus, profondeur)
    local t = type(v)
    if t == "number" then return v == v and v > -math.huge and v < math.huge end
    if t == "string" or t == "boolean" then return true end
    if t ~= "table" or vus[v] or profondeur > 16 then return false end
    vus[v] = true
    for k, valeur in pairs(v) do
        if (type(k) ~= "string" and type(k) ~= "number") or not Donnees(valeur, vus, profondeur + 1) then return false end
    end
    vus[v] = nil
    return true
end

function X.Concerne(ref)
    return type(ref) == "string" and (ref:match("^objets/.+") ~= nil or ref:match("^cristaux/.+") ~= nil)
end

function X.Nouveau(ref)
    local db = LCM.EnsureDatabase()
    db.sequenceExemplaires = (tonumber(db.sequenceExemplaires) or 0) + 1
    local auteur = UnitGUID("player") or LCM.PlayerId()
    assert(auteur, "identité du porteur indisponible")
    local id = tostring(auteur) .. ":" .. tostring(time()) .. ":" .. db.sequenceExemplaires
    -- Un cristal n'a pas de proprietes IC : seulement son identite, et sa
    -- charge quand il est entame.
    if ref:match("^cristaux/") then return { version = 1, id = id, ref = ref, usages = {} } end
    -- Un outil contenant nait avec son contenu de depart (Core/Contenants.lua).
    return LCM.Contenants.Garnir(LCM.IC.Charges.Nouveau(id, ref), ref)
end

-- Valide avant toute ecriture. Une liste fournie n'est jamais completee :
-- en reseau, une unite manquante est une erreur, pas un objet neuf gratuit.
function X.Lire(ref, quantite, liste)
    if not X.Concerne(ref) then
        if liste ~= nil then return nil, "ces exemplaires ne correspondent pas à un objet." end
        return nil
    end
    if liste == nil then return nil end
    if not Donnees(liste, {}, 0) then return nil, "données d'exemplaire illisibles." end
    if type(liste) ~= "table" or #liste ~= quantite then return nil, "nombre d'exemplaires incorrect." end
    local vus = {}
    for k, e in pairs(liste) do
        if type(k) ~= "number" or k ~= math.floor(k) or k < 1 or k > quantite
            or type(e) ~= "table" or e.version ~= 1 or e.ref ~= ref
            or type(e.id) ~= "string" or e.id == "" or vus[e.id]
            or type(e.usages) ~= "table" then return nil, "exemplaire invalide ou répété." end
        -- Son etat (Core/Objets.lua) : absent, il est neuf.
        for _, cle in ipairs({ "usure", "viesPerdues" }) do
            local n = e[cle]
            if n ~= nil and (type(n) ~= "number" or n < 1 or n ~= math.floor(n)) then
                return nil, "état d'exemplaire illisible."
            end
        end
        -- La charge d'un cristal entame : des secondes, zero au moins.
        if e.charge ~= nil and (type(e.charge) ~= "number" or e.charge < 0) then
            return nil, "charge de cristal illisible."
        end
        -- Ce que contient un outil : une reference et ce qu'il en reste.
        if e.contenu ~= nil and (type(e.contenu) ~= "table" or type(e.contenu.ref) ~= "string"
            or type(e.contenu.reste) ~= "number" or e.contenu.reste <= 0) then
            return nil, "contenu d'outil illisible."
        end
        vus[e.id] = true
        for propriete, historique in pairs(e.usages) do
            if type(propriete) ~= "string" or type(historique) ~= "table" then
                return nil, "historique IC invalide."
            end
            for rang, u in pairs(historique) do
                if type(rang) ~= "number" or rang < 1 or rang ~= math.floor(rang) or rang > #historique
                    or type(u) ~= "table" or type(u.action) ~= "string"
                    or type(u.date) ~= "number" or u.date < 0 or u.date >= math.huge
                    or u.date ~= math.floor(u.date)
                    or (u.cle ~= nil and type(u.cle) ~= "string") then
                    return nil, "historique IC invalide."
                end
            end
        end
    end
    return LCM.Copie(liste)
end

function X.CreerListe(ref, quantite)
    if not X.Concerne(ref) then return nil end
    local liste = {}
    for i = 1, quantite do liste[i] = X.Nouveau(ref) end
    return liste
end

-- Migration seulement lors d'un geste d'ecriture, jamais dans un getter.
--
-- Une case qui tient une entree sous une reference d'avant un transfert
-- (« ressources/gourde » devenue un outil, MJ/Transfert.lua) passe d'abord a
-- sa reference d'aujourd'hui : sans quoi elle n'aurait jamais d'exemplaire, et
-- la gourde « (vide) » refusait d'etre remplie (le MJ, 23 octobre 2026).
function X.Assurer(case)
    local actuelle = LCM.Compendium and LCM.Compendium.Canonique(case.ref)
    if actuelle and actuelle ~= case.ref then
        case.ref = actuelle
        if type(case.exemplaires) == "table" and not X.Lire(actuelle, tonumber(case.quantite) or 1, case.exemplaires) then
            case.exemplaires = nil
        end
    end
    if not X.Concerne(case.ref) then return nil end
    local liste, raison = X.Lire(case.ref, tonumber(case.quantite) or 1, case.exemplaires)
    assert(not raison, raison)
    if not liste then case.exemplaires = X.CreerListe(case.ref, tonumber(case.quantite) or 1) end
    return case.exemplaires
end

function X.Tranche(liste, debut, nombre)
    if not liste then return nil end
    local out = {}
    for i = debut, debut + nombre - 1 do out[#out + 1] = LCM.Copie(liste[i]) end
    return out
end

function X.Sortir(case, nombre)
    local liste = X.Assurer(case)
    local out = X.Tranche(liste, 1, nombre)
    if liste then for i = 1, nombre do table.remove(liste, 1) end end
    return out
end

function X.Ajouter(case, liste)
    if not liste then return end
    local dedans = X.Assurer(case)
    for _, e in ipairs(liste) do dedans[#dedans + 1] = LCM.Copie(e) end
end
