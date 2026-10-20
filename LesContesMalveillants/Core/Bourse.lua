-- La bourse : ce que le personnage possede en monnaie.
--
-- Pourquoi elle ne passe PAS par l'inventaire, alors qu'il a un onglet
-- « Devises » : cet onglet n'a qu'UN emplacement dans le template
-- (`Equilibrage.inventaire.devises = 1`). Il y loge une monnaie, pas une
-- bourse. Or on veut voir les trois d'un coup, et davantage.
--
-- La bourse tient donc ses propres soldes, un par devise, et c'est elle qui
-- fait foi. L'onglet Devises de l'inventaire garde son role du template ; si un
-- jour il doit disparaitre ou s'ouvrir, ce sera une decision prise exprès, pas
-- un effet de bord.
--
-- Les devises elles-memes sont du contenu : elles viennent du compendium
-- (famille « devises »), donc le MJ en cree une dans l'atelier et elle part
-- avec la mise a jour. Rien a declarer ici.

local _, LCM = ...

local Bourse = {}
LCM.Bourse = Bourse

local VIDE = {}

-- Les monnaies que tout personnage voit, meme a zero. Les autres n'apparaissent
-- que s'il en possede : une bourse pleine de lignes a zero ne dit rien.
Bourse.DEFAUTS = { "ecus", "credits", "essence_stelaire" }

-- Lecture : ne cree rien.
local function Soldes(entity)
    if type(entity) ~= "table" or type(entity.bourse) ~= "table" then return VIDE end
    return entity.bourse
end

local function SoldesPourEcrire(entity)
    if type(entity) ~= "table" then return nil end
    entity.bourse = type(entity.bourse) == "table" and entity.bourse or {}
    return entity.bourse
end

function Bourse.Solde(entity, deviseId)
    return math.floor(tonumber(Soldes(entity)[tostring(deviseId or "")]) or 0)
end

-- Ce que montre la bourse : les monnaies de base, toujours, puis celles qu'on
-- detient en plus.
function Bourse.Liste(entity)
    local out, vus = {}, {}
    local function poser(devise)
        if not devise or vus[devise.id] then return end
        vus[devise.id] = true
        out[#out + 1] = {
            id = devise.id, label = devise.label, icone = devise.icone,
            description = devise.description, solde = Bourse.Solde(entity, devise.id),
        }
    end
    for _, id in ipairs(Bourse.DEFAUTS) do poser(LCM.Devises.Get(id)) end
    -- Dans l'ordre du compendium, pour que deux joueurs voient la meme chose.
    for _, devise in ipairs(LCM.Devises.list) do
        if Bourse.Solde(entity, devise.id) ~= 0 then poser(devise) end
    end
    return out
end

-- Toutes les devises du compendium : ce que le MJ peut donner.
function Bourse.Catalogue()
    return LCM.Devises.list
end

function Bourse.Crediter(entity, deviseId, combien)
    local devise = LCM.Devises.Get(deviseId)
    if not devise then return false, "devise inconnue." end
    combien = math.floor(tonumber(combien) or 0)
    if combien <= 0 then return false, "un montant positif." end
    local soldes = SoldesPourEcrire(entity)
    if not soldes then return false, "aucun personnage." end
    soldes[devise.id] = Bourse.Solde(entity, devise.id) + combien
    return true, soldes[devise.id]
end

function Bourse.Debiter(entity, deviseId, combien)
    local devise = LCM.Devises.Get(deviseId)
    if not devise then return false, "devise inconnue." end
    combien = math.floor(tonumber(combien) or 0)
    if combien <= 0 then return false, "un montant positif." end
    local solde = Bourse.Solde(entity, devise.id)
    if solde < combien then
        return false, string.format("il n'a que %d %s.", solde, devise.label)
    end
    local soldes = SoldesPourEcrire(entity)
    soldes[devise.id] = solde - combien
    -- Un solde a zero ne se garde pas : la sauvegarde n'a pas a retenir ce
    -- qu'on n'a pas.
    if soldes[devise.id] == 0 then soldes[devise.id] = nil end
    if not next(soldes) then entity.bourse = nil end
    return true
end

-- Poser un solde tel quel (le MJ le tape dans la bourse) : un entier, zero au
-- moins. Passe par Crediter / Debiter, qui savent deja ecrire et effacer.
function Bourse.Definir(entity, deviseId, solde)
    local devise = LCM.Devises.Get(deviseId)
    if not devise then return false, "devise inconnue." end
    local n = tonumber(solde)
    if not n or n ~= math.floor(n) or n < 0 then
        return false, string.format("solde illisible (%s) : un nombre entier, zéro au moins.", tostring(solde))
    end
    local ecart = n - Bourse.Solde(entity, devise.id)
    if ecart > 0 then return Bourse.Crediter(entity, devise.id, ecart) end
    if ecart < 0 then return Bourse.Debiter(entity, devise.id, -ecart) end
    return true
end

-- A-t-on de quoi payer ? Pose la question sans rien debiter.
function Bourse.Peut(entity, deviseId, combien)
    return Bourse.Solde(entity, deviseId) >= math.floor(tonumber(combien) or 0)
end

function Bourse.Total(entity)
    local total = 0
    for _, ligne in ipairs(Bourse.Liste(entity)) do total = total + ligne.solde end
    return total
end

-- ===== Les monnaies qui ont une forme ======================================
-- Une devise cochee « Materiel » dans sa creation existe aussi en objet : une
-- bourse de pieces, un lingot. Elle quitte alors la bourse pour une case de
-- sac, et y revient (le MJ, 19 octobre 2026). Les autres n'existent qu'en
-- solde : rien a porter, rien a cacher dans un coffre.
--
-- Une pile n'est PAS dans la bourse, et c'est le prix de la forme : elle ne
-- paie pas chez un marchand (Core/Prix.lua lit le solde), mais elle se donne,
-- se range et se perd comme un objet.

local function Ref(deviseId) return "devises/" .. tostring(deviseId or "") end
Bourse.Ref = Ref

function Bourse.EstMateriel(deviseId)
    local devise = LCM.Devises.Get(deviseId)
    return (devise and devise.materiel) == true
end

-- Combien on en porte en piles, tous sacs confondus. La bourse ne compte pas.
function Bourse.EnPiles(entity, deviseId)
    local ref, total = Ref(deviseId), 0
    for _, categorie in ipairs(LCM.Inventaire.categories or VIDE) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local emplacement = LCM.Inventaire.Emplacement(entity, categorie.id, index)
            local cases = emplacement and type(emplacement.cases) == "table" and emplacement.cases or VIDE
            for _, c in pairs(cases) do
                if type(c) == "table" and c.ref == ref then total = total + (tonumber(c.quantite) or 1) end
            end
        end
    end
    return total
end

-- Le controle commun aux deux gestes : la devise existe, elle a une forme, le
-- montant est un entier positif. Rend la devise et le montant, ou nil et la
-- raison.
local function Mesurer(deviseId, combien)
    local devise = LCM.Devises.Get(deviseId)
    if not devise then return nil, "devise inconnue." end
    if not devise.materiel then
        return nil, string.format("%s ne se transporte pas : elle reste dans la bourse.", devise.label)
    end
    local n = tonumber(combien)
    if not n or n ~= math.floor(n) or n < 1 then
        return nil, string.format("montant illisible (%s) : un nombre entier, 1 au moins.", tostring(combien))
    end
    return devise, n
end

-- Poser la pile sur UNE case : celle que le joueur a visee en glissant sa
-- monnaie depuis la bourse. Une case vide la recoit ; une case qui porte deja
-- la meme monnaie l'absorbe.
local function Poser(entity, deviseId, n, place)
    local Inv = LCM.Inventaire
    local ref = Ref(deviseId)
    local deja = Inv.Case(Inv.Emplacement(entity, place.onglet, place.index), place.case)
    if not deja then
        return Inv.Ranger(entity, place.onglet, place.index, place.case, ref, n)
    end
    if deja.ref ~= ref then return false, "cette case est déjà occupée." end
    return Inv.Quantite(entity, place.onglet, place.index, place.case,
        (tonumber(deja.quantite) or 1) + n)
end

-- Sortir de la bourse : le solde baisse, une pile apparait dans les sacs. Avec
-- `place` ({ onglet, index, case }), sur CETTE case — celle qu'on a visee.
-- Si la pile ne tient nulle part, le solde revient : on ne perd pas son argent
-- a manquer de place.
function Bourse.Materialiser(entity, deviseId, combien, place)
    local devise, n = Mesurer(deviseId, combien)
    if not devise then return false, n end
    local ok, raison = Bourse.Debiter(entity, devise.id, n)
    if not ok then return false, raison end
    local pose, pourquoi
    if type(place) == "table" then
        pose, pourquoi = Poser(entity, devise.id, n, place)
    else
        pose, pourquoi = LCM.Inventaire.Deposer(entity, Ref(devise.id), n)
    end
    if not pose then
        Bourse.Crediter(entity, devise.id, n)
        return false, pourquoi or "aucune place libre."
    end
    return true
end

-- Remettre en bourse. `place` ({ onglet, index, case }) designe LA pile a
-- entamer : sans elle on prend dans la premiere trouvee, et le clic droit sur
-- une pile viderait celle d'a cote.
function Bourse.Encaisser(entity, deviseId, combien, place)
    local devise, n = Mesurer(deviseId, combien)
    if not devise then return false, n end
    local Inv = LCM.Inventaire
    if type(place) == "table" then
        local c = Inv.Case(Inv.Emplacement(entity, place.onglet, place.index), place.case)
        if not (c and c.ref == Ref(devise.id)) then return false, "cette pile n'est plus là." end
        local dedans = tonumber(c.quantite) or 1
        if dedans < n then return false, string.format("cette pile n'en a que %d.", dedans) end
        local ok, raison
        if dedans == n then
            ok, raison = Inv.Vider(entity, place.onglet, place.index, place.case)
        else
            ok, raison = Inv.Quantite(entity, place.onglet, place.index, place.case, dedans - n)
        end
        if not ok then return false, raison end
    else
        local porte = Bourse.EnPiles(entity, devise.id)
        if porte < n then return false, string.format("tu n'en portes que %d.", porte) end
        for _ = 1, n do
            local ok, raison = Inv.Prendre(entity, Ref(devise.id))
            if not ok then return false, raison end
        end
    end
    local ok, raison = Bourse.Crediter(entity, devise.id, n)
    if not ok then return false, raison end
    return true
end
