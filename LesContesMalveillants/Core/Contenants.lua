-- Les outils contenants (le MJ, 23 octobre 2026) : une gourde, une fiole de
-- prelevement.
--
-- Le MODELE (la forge de l'outil) dit `contenant = { taille, retrait, types,
-- depart }` :
--   * taille   ce que l'outil tient, dans l'unite que le MJ veut ;
--   * retrait  ce qu'un usage en retire ;
--   * types    les types (de la « Liste consommable » ou de la « Liste
--              ressources ») qu'il accepte — vide : tout consommable et toute
--              ressource ;
--   * entrees  parmi un type accepte, les SEULES entrees permises (« des
--              boissons, mais uniquement de l'eau »). Un type dont aucune
--              entree n'est nommee les accepte toutes ;
--   * depart   ce qu'il contient quand il nait (« Gourde d'eau »), ou rien.
--
-- Le CONTENU vit sur l'exemplaire, comme l'usure : `contenu = { ref, reste }`.
-- Deux gourdes ont chacune leur eau. Une seule sorte a la fois.
--
-- Une dose remplit : verser UN consommable dans l'outil le porte a sa taille
-- (decision du MJ — « une dose decoupee en % »). Chaque usage applique l'effet
-- ENTIER du consommable et retire `retrait`. Une gourde de 100, a 20 par
-- gorgee, donne cinq gorgees d'une seule Eau.
--
-- Une ressource contenue ne s'utilise pas : elle se transporte, et elle reste
-- ACCESSIBLE — un paiement, et demain une recette, la voient dans l'outil et
-- la prennent, `retrait` par `retrait` (Contenants.Unites / Contenants.Prendre).

local _, LCM = ...

local Contenants = {}
LCM.Contenants = Contenants

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Entier(v) local n = tonumber(v) return n and n == math.floor(n) and n or nil end

-- Les familles qu'un outil peut tenir.
local FAMILLES = { consommables = true, ressources = true }

-- Lit le `contenant` d'une definition d'outil. nil s'il n'en a pas.
function Contenants.Lire(definition, id, Erreur)
    local c = definition and definition.contenant
    if c == nil then return nil end
    if type(c) ~= "table" then Erreur(id .. " : contenant illisible") end
    local taille, retrait = Entier(c.taille), Entier(c.retrait)
    if not taille or taille < 1 then
        Erreur(id .. " : taille du contenant illisible (" .. tostring(c.taille) .. "), attendu un entier positif")
    end
    if not retrait or retrait < 1 then
        Erreur(id .. " : retrait par usage illisible (" .. tostring(c.retrait) .. "), attendu un entier positif")
    end
    if retrait > taille then
        Erreur(string.format("%s : un usage retire %d, plus que le contenant n'en tient (%d)", id, retrait, taille))
    end
    local types = {}
    for _, t in ipairs(type(c.types) == "table" and c.types or {}) do types[#types + 1] = tostring(t) end
    local entrees = {}
    for _, ref in ipairs(type(c.entrees) == "table" and c.entrees or {}) do
        ref = Texte(ref)
        if not FAMILLES[ref:match("^([%w_]+)/") or ""] then
            Erreur(id .. " : entree acceptee illisible « " .. ref .. " »")
        end
        entrees[#entrees + 1] = ref
    end
    local depart = Texte(c.depart)
    if depart ~= "" and not FAMILLES[depart:match("^([%w_]+)/") or ""] then
        Erreur(id .. " : contenu de depart illisible « " .. depart .. " »")
    end
    return { taille = taille, retrait = retrait, types = types[1] and types or nil,
             entrees = entrees[1] and entrees or nil, depart = depart ~= "" and depart or nil }
end

function Contenants.Modele(ref)
    local element = LCM.Compendium.Resoudre(ref)
    return element and type(element.contenant) == "table" and element or nil
end

-- Le contenant accepte-t-il `ref` ? true, ou false et la raison.
function Contenants.Accepte(modele, ref)
    local c = modele and modele.contenant
    if not c then return false, "cet outil ne contient rien." end
    local element, categorie = LCM.Compendium.Resoudre(ref)
    if not element or not categorie or not FAMILLES[categorie.famille] then
        return false, "un contenant ne reçoit qu'un consommable ou une ressource."
    end
    local typeRetenu = c.types == nil
    for _, t in ipairs(c.types or {}) do if t == element.type then typeRetenu = true end end
    if not typeRetenu then
        local noms = {}
        for _, t in ipairs(c.types) do
            local entree = LCM.Listes.Get(t)
            noms[#noms + 1] = entree and entree.label or t
        end
        return false, string.format("« %s » n'accepte que : %s.", modele.label, table.concat(noms, ", "))
    end
    -- Le type est bon ; reste a savoir si ce type est restreint a quelques
    -- entrees, et si celle-ci en est.
    if c.entrees then
        local voulu, permises = LCM.Compendium.Canonique(ref), {}
        for _, r in ipairs(c.entrees) do
            local e = LCM.Compendium.Resoudre(r)
            if e and e.type == element.type then
                if LCM.Compendium.Canonique(r) == voulu then return true end
                permises[#permises + 1] = e.label
            end
        end
        if permises[1] then
            local typeEntree = LCM.Listes.Get(element.type)
            return false, string.format("« %s » n'accepte, en %s, que : %s.", modele.label,
                typeEntree and typeEntree.label or tostring(element.type), table.concat(permises, ", "))
        end
    end
    return true
end

-- ===== Le contenu d'un exemplaire ============================================

function Contenants.Pourcent(modele, exemplaire)
    local contenu = exemplaire and exemplaire.contenu
    if not (modele and modele.contenant and contenu) then return 0 end
    return math.floor(100 * contenu.reste / modele.contenant.taille + 0.5)
end

-- « Eau, 60 % », ou « vide ».
function Contenants.Texte(modele, exemplaire)
    local contenu = exemplaire and exemplaire.contenu
    if not contenu then return "vide" end
    local element = LCM.Compendium.Resoudre(contenu.ref)
    return string.format("%s, %d %%", element and element.label or ("? " .. tostring(contenu.ref)),
        Contenants.Pourcent(modele, exemplaire))
end

-- Un exemplaire neuf nait avec son contenu de depart, s'il en a un.
function Contenants.Garnir(exemplaire, ref)
    local modele = Contenants.Modele(ref)
    local c = modele and modele.contenant
    if c and c.depart and LCM.Compendium.Resoudre(c.depart) then
        exemplaire.contenu = { ref = LCM.Compendium.Canonique(c.depart), reste = c.taille }
    end
    return exemplaire
end

-- La case d'un sac, ses exemplaires (crees s'il le faut : c'est un geste
-- d'ecriture) et le modele de contenant.
local function Case(entity, ou)
    local e = ou and LCM.Inventaire.Emplacement(entity, ou.onglet, ou.index)
    local c = e and LCM.Inventaire.Case(e, ou.case)
    if not c then return nil, nil, "cette case est vide." end
    local modele = Contenants.Modele(c.ref)
    if not modele then return nil, nil, "cet objet ne contient rien." end
    return c, modele
end

-- Le premier exemplaire de la pile qui a quelque chose dedans, pour l'usage.
local function Plein(c)
    for _, x in ipairs(LCM.Exemplaires.Assurer(c) or {}) do
        if x.contenu then return x end
    end
    return nil
end

-- Lecture seule : ce que montre la case (le premier exemplaire qui contient
-- quelque chose, sinon le premier).
function Contenants.DeLaCase(c)
    local modele = c and Contenants.Modele(c.ref)
    if not modele then return nil end
    local premier
    for _, x in ipairs(type(c.exemplaires) == "table" and c.exemplaires or {}) do
        premier = premier or x
        if x.contenu then return modele, x end
    end
    return modele, premier
end

-- Verse un exemplaire de `ref` (pris dans les sacs) dans l'outil de la case
-- `ou`. L'outil remonte a sa taille.
function Contenants.Remplir(entity, ou, ref)
    local c, modele, raison = Case(entity, ou)
    if not c then return false, raison end
    local ok, refus = Contenants.Accepte(modele, ref)
    if not ok then return false, refus end
    local voulu = LCM.Compendium.Canonique(ref)
    local cible
    for _, x in ipairs(LCM.Exemplaires.Assurer(c) or {}) do
        if x.contenu and x.contenu.ref == voulu and x.contenu.reste < modele.contenant.taille then cible = x break end
    end
    if not cible then
        for _, x in ipairs(c.exemplaires or {}) do
            if not x.contenu then cible = x break end
        end
    end
    if not cible then
        for _, x in ipairs(c.exemplaires or {}) do
            if x.contenu and x.contenu.ref == voulu then
                return false, string.format("« %s » est déjà à 100 %%.", modele.label)
            end
        end
        return false, string.format("« %s » contient déjà autre chose : vide son contenu d'abord.", modele.label)
    end
    if not LCM.Inventaire.Chercher(entity, ref) then return false, "tu n'en as plus dans tes sacs." end
    LCM.Inventaire.Prendre(entity, ref)
    cible.contenu = { ref = voulu, reste = modele.contenant.taille }
    return true
end

-- Ce qu'on peut verser dans l'outil de la case `ou`, d'apres les sacs :
-- { { ref, label } }, une ligne par entree.
function Contenants.Versables(entity, ou)
    local c, modele = Case(entity, ou)
    local out, vus = {}, {}
    if not c then return out end
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(entity, categorie.id, index)
            for _, pile in pairs(e and type(e.cases) == "table" and e.cases or {}) do
                local ref = type(pile) == "table" and LCM.Compendium.Canonique(pile.ref)
                if ref and not vus[ref] and Contenants.Accepte(modele, ref) == true then
                    vus[ref] = true
                    local element = LCM.Compendium.Resoudre(ref)
                    out[#out + 1] = { ref = ref, label = element and element.label or ref }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Utilise l'outil de la case `ou` : l'effet entier de son consommable, puis
-- `retrait` en moins. `repartition` : la repartition des PV, s'il y en a.
local UtiliserExemplaire

function Contenants.Utiliser(entity, ou, repartition)
    local c, modele, raison = Case(entity, ou)
    if not c then return nil, raison end
    return UtiliserExemplaire(entity, modele, Plein(c), repartition)
end

UtiliserExemplaire = function(entity, modele, x, repartition)
    if not (x and x.contenu) then return nil, string.format("« %s » est vide.", modele.label) end
    local element, categorie = LCM.Compendium.Resoudre(x.contenu.ref)
    if not element or not categorie or categorie.famille ~= "consommables" then
        return nil, "ce qu'il contient ne s'utilise pas : ça se transporte."
    end
    local bilan, refus = LCM.Consommation.Appliquer(entity, element, repartition)
    if not bilan then return nil, refus end
    Contenants.Retirer(x, modele)
    return bilan
end

-- Ce que contient le premier exemplaire plein d'une case (pour la
-- repartition des PV, avant d'utiliser).
function Contenants.ContenuDe(entity, ou)
    local c = Case(entity, ou)
    local x = c and Plein(c)
    if not x then return nil end
    return LCM.Compendium.Resoudre(x.contenu.ref)
end

-- ===== Un outil EQUIPE =======================================================
-- La gourde a la ceinture (Équipements > Outils, et « Mes Outils » du menu
-- radial) garde son contenu sur l'exemplaire equipe, comme dans le sac : on
-- s'en sert sans la reprendre. `rang` : son rang parmi les outils portes.

local function IdPorte(entity, rang)
    return LCM.Objets.Ids(entity, "outil")[tonumber(rang) or 0]
end

-- Lecture seule : le modele de contenant et l'exemplaire porte, ou nil.
function Contenants.Porte(entity, rang)
    local id = IdPorte(entity, rang)
    local modele = id and Contenants.Modele("objets/" .. id)
    if not modele then return nil end
    return modele, LCM.Objets.ExemplairePorte(entity, "outil", tonumber(rang))
end

-- Ce que contient l'outil porte (pour la repartition des PV, avant d'utiliser).
function Contenants.ContenuPorte(entity, rang)
    local _, x = Contenants.Porte(entity, rang)
    return x and x.contenu and LCM.Compendium.Resoudre(x.contenu.ref) or nil
end

function Contenants.UtiliserPorte(entity, rang, repartition)
    local id = IdPorte(entity, rang)
    local modele = id and Contenants.Modele("objets/" .. id)
    if not modele then return nil, "cet outil ne contient rien." end
    return UtiliserExemplaire(entity, modele,
        LCM.Objets.PreparerExemplaireEquipe(entity, id, tonumber(rang)), repartition)
end

-- Combien d'usages il reste : reste / retrait, arrondi en dessous.
function Contenants.Usages(modele, exemplaire)
    local contenu = exemplaire and exemplaire.contenu
    if not (modele and modele.contenant and contenu) then return 0 end
    return math.floor(contenu.reste / modele.contenant.retrait)
end

function Contenants.Retirer(exemplaire, modele)
    exemplaire.contenu.reste = exemplaire.contenu.reste - modele.contenant.retrait
    if exemplaire.contenu.reste <= 0 then exemplaire.contenu = nil end
end

function Contenants.Vider(entity, ou)
    local c, modele, raison = Case(entity, ou)
    if not c then return false, raison end
    local x = Plein(c)
    if not x then return false, string.format("« %s » est déjà vide.", modele.label) end
    x.contenu = nil
    return true
end

-- ===== Ce qui est accessible dans les contenants ============================
-- Une ressource dans une fiole compte pour ce qu'on peut en retirer :
-- reste / retrait, arrondi en dessous. C'est par la qu'un paiement (et
-- demain une recette) la trouve.

local function Parcourir(entity, fonction)
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(entity, categorie.id, index)
            for _, pile in pairs(e and type(e.cases) == "table" and e.cases or {}) do
                local modele = type(pile) == "table" and Contenants.Modele(pile.ref)
                if modele then
                    for _, x in ipairs(type(pile.exemplaires) == "table" and pile.exemplaires or {}) do
                        if x.contenu and fonction(x, modele) then return end
                    end
                end
            end
        end
    end
end

function Contenants.Unites(entity, ref)
    local voulu, total = LCM.Compendium.Canonique(ref), 0
    Parcourir(entity, function(x, modele)
        if x.contenu.ref == voulu then total = total + math.floor(x.contenu.reste / modele.contenant.retrait) end
    end)
    return total
end

function Contenants.Prendre(entity, ref)
    local voulu, pris = LCM.Compendium.Canonique(ref), false
    Parcourir(entity, function(x, modele)
        if x.contenu.ref == voulu and x.contenu.reste >= modele.contenant.retrait then
            Contenants.Retirer(x, modele)
            pris = true
            return true
        end
    end)
    return pris
end
