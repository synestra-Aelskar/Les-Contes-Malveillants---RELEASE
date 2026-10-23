-- Le prix d'une offre de vendeur (16 octobre 2026).
--
-- Un prix est une liste de FACONS DE PAYER, au choix : « ca te coutera 600
-- essences. Ou 400 essences et 3 gaufres. » Chaque facon est une liste de
-- MORCEAUX, tous dus. Un morceau est une reference de compendium et une
-- quantite : une devise (« devises/... ») se paie de la bourse, toute autre
-- entree — une ressource, un objet — se prend dans les sacs. Plusieurs
-- monnaies ont cours dans un meme pays, et un marchand peut aussi accepter le
-- troc.
--
-- Une facon sans morceau est gratuite. Une offre SANS facon n'a pas de prix :
-- chez un vendeur, c'est un refus a l'enregistrement.
--
-- Le joueur choisit la facon au moment d'acheter (ou de revendre) ; tout ce
-- qu'elle demande est preleve (ou verse).

local _, LCM = ...

local Prix = {}
LCM.Prix = Prix

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function Entier(v)
    local n = tonumber(v)
    if not n or n ~= math.floor(n) then return nil end
    return n
end

-- « devises/ecus » -> « devises », « ecus »
local function Decouper(ref)
    return tostring(ref or ""):match("^([%w_]+)/(.+)$")
end

function Prix.EstDevise(ref)
    return (Decouper(ref)) == "devises"
end

-- Ce qu'une definition porte, en liste de facons. Trois formes :
--   * prix = { { { ref = "devises/ecus", quantite = 600 } },
--              { { ref = "devises/ecus", quantite = 400 },
--                { ref = "ressources/gaufre", quantite = 3 } } }
--   * un morceau peut dire `devise = "ecus"` au lieu de sa reference, ou ne
--     rien dire : il se paie alors dans la monnaie par defaut du vendeur ;
--   * l'ancienne forme, d'avant le 16 octobre 2026 : prix = 600, devise =
--     "ecus" (ou la monnaie par defaut). Les vendeurs deja enregistres la
--     portent encore.
-- Rend la liste, ou nil et la raison.
function Prix.Lire(prix, devise, deviseDefaut)
    if prix == nil or prix == "" then return {} end
    deviseDefaut = Texte(deviseDefaut)
    if type(prix) ~= "table" then
        local montant = Entier(prix)
        if not montant or montant < 0 then return nil, "prix illisible (" .. tostring(prix) .. ")" end
        if montant == 0 then return { {} } end
        local id = Texte(devise) ~= "" and Texte(devise) or deviseDefaut
        if id == "" then return nil, "prix sans monnaie" end
        return { { { ref = "devises/" .. id, quantite = montant } } }
    end
    local facons = {}
    for i, facon in ipairs(prix) do
        if type(facon) ~= "table" then return nil, string.format("façon de payer %d illisible", i) end
        local morceaux, rang = {}, {}
        for _, m in ipairs(facon) do
            if type(m) ~= "table" then return nil, string.format("façon de payer %d illisible", i) end
            local ref = Texte(m.ref)
            if ref == "" and Texte(m.devise) ~= "" then ref = "devises/" .. Texte(m.devise) end
            if ref == "" and deviseDefaut ~= "" then ref = "devises/" .. deviseDefaut end
            if not Decouper(ref) then
                return nil, string.format("façon de payer %d : un morceau ne dit pas en quoi il se paie", i)
            end
            local quantite = Entier(m.quantite or m.montant)
            if not quantite or quantite < 0 then
                return nil, string.format("façon de payer %d : quantité invalide (%s)", i,
                    tostring(m.quantite or m.montant))
            end
            -- Deux fois la meme chose dans une facon : on additionne.
            if quantite > 0 then
                if rang[ref] then
                    morceaux[rang[ref]].quantite = morceaux[rang[ref]].quantite + quantite
                else
                    morceaux[#morceaux + 1] = { ref = ref, quantite = quantite }
                    rang[ref] = #morceaux
                end
            end
        end
        facons[#facons + 1] = morceaux
    end
    return facons
end

-- Les facons d'une offre, quelle que soit sa forme : construite (`formules`),
-- ou ancienne (`prix` et `devise`), comme en garde la sauvegarde d'un joueur
-- qui a recu l'etal avant la mise a jour.
function Prix.DeLOffre(offre, deviseDefaut)
    if type(offre) ~= "table" then return {} end
    if type(offre.formules) == "table" then return offre.formules end
    return Prix.Lire(offre.prix, offre.devise, deviseDefaut) or {}
end

-- ===== Le dire =============================================================

function Prix.Nom(ref)
    local famille, id = Decouper(ref)
    if famille == "devises" then
        local devise = LCM.Devises and LCM.Devises.Get(id)
        return (devise and devise.label) or id
    end
    local entree = LCM.Compendium and LCM.Compendium.Resoudre(ref)
    return (entree and entree.label) or id or tostring(ref)
end

function Prix.TexteFacon(facon)
    if not facon or #facon == 0 then return "Gratuit" end
    local morceaux = {}
    for _, m in ipairs(facon) do
        morceaux[#morceaux + 1] = string.format("%d %s", m.quantite, Prix.Nom(m.ref))
    end
    return table.concat(morceaux, " + ")
end

function Prix.Texte(facons)
    if not facons or #facons == 0 then return "" end
    local out = {}
    for _, facon in ipairs(facons) do out[#out + 1] = Prix.TexteFacon(facon) end
    return table.concat(out, "  ou  ")
end

-- ===== Payer, et etre paye =================================================

-- Ce qu'on a d'une chose : la bourse pour une devise, les sacs pour le reste.
-- Ce qui est equipe ne compte pas : on ne paie pas avec l'epee qu'on porte.
function Prix.Avoir(entity, ref)
    local famille, id = Decouper(ref)
    if famille == "devises" then return LCM.Bourse.Solde(entity, id) end
    local total = 0
    for _, categorie in ipairs(LCM.Inventaire.categories or {}) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local emplacement = LCM.Inventaire.Emplacement(entity, categorie.id, index)
            for _, c in pairs(emplacement and type(emplacement.cases) == "table" and emplacement.cases or {}) do
                if type(c) == "table" and LCM.Compendium.MemeEntree(c.ref, ref) then
                    total = total + (tonumber(c.quantite) or 1)
                end
            end
        end
    end
    -- Et ce que les outils contiennent : la bave de dragon dans sa fiole se
    -- paie comme celle d'un sac (Core/Contenants.lua).
    return total + LCM.Contenants.Unites(entity, ref)
end

-- true, ou false et ce qui manque.
function Prix.Peut(entity, facon)
    for _, m in ipairs(facon or {}) do
        if Prix.Avoir(entity, m.ref) < m.quantite then
            return false, string.format("il te faut %d %s.", m.quantite, Prix.Nom(m.ref))
        end
    end
    return true
end

-- Preleve une facon. A n'appeler qu'apres `Peut` : rien ici ne se defait.
function Prix.Payer(entity, facon)
    for _, m in ipairs(facon or {}) do
        if Prix.EstDevise(m.ref) then
            LCM.Bourse.Debiter(entity, select(2, Decouper(m.ref)), m.quantite)
        else
            -- Les sacs d'abord, puis ce que les outils contiennent.
            for _ = 1, m.quantite do
                if not LCM.Inventaire.Prendre(entity, m.ref) then LCM.Contenants.Prendre(entity, m.ref) end
            end
        end
    end
    return true
end

-- Verse une facon (une revente). Ce qui va dans les sacs passe d'abord, et se
-- reprend si la suite ne tient pas : on ne verse jamais une moitie de prix.
-- true, ou false et la raison.
function Prix.Verser(entity, facon)
    local ranges = {}
    for _, m in ipairs(facon or {}) do
        if not Prix.EstDevise(m.ref) then
            local ok, raison = LCM.Inventaire.Deposer(entity, m.ref, m.quantite)
            if not ok then
                for _, r in ipairs(ranges) do
                    for _ = 1, r.quantite do LCM.Inventaire.Prendre(entity, r.ref) end
                end
                return false, raison or "plus de place dans les sacs."
            end
            ranges[#ranges + 1] = m
        end
    end
    for _, m in ipairs(facon or {}) do
        if Prix.EstDevise(m.ref) then
            LCM.Bourse.Crediter(entity, select(2, Decouper(m.ref)), m.quantite)
        end
    end
    return true
end

-- La facon choisie, verifiee. `choix` est son rang ; sans choix, il n'y en a
-- qu'une. nil et la raison sinon.
function Prix.Choisir(facons, choix)
    if #facons == 0 then return nil, "cette offre n'a pas de prix." end
    if choix == nil then
        if #facons == 1 then return facons[1], 1 end
        return nil, "choisis comment payer."
    end
    local rang = math.floor(tonumber(choix) or 0)
    if not facons[rang] then return nil, "façon de payer inconnue." end
    return facons[rang], rang
end

-- ===== Sur le reseau =======================================================
-- Une chaine courte : « 600*devises/ecus;400*devises/ecus,3*ressources/gaufre ».
-- Une facon gratuite s'ecrit « - ». Les identifiants n'ont ni « ; », ni « , »,
-- ni « * ».

function Prix.Plier(facons)
    local out = {}
    for _, facon in ipairs(facons or {}) do
        if #facon == 0 then
            out[#out + 1] = "-"
        else
            local morceaux = {}
            for _, m in ipairs(facon) do morceaux[#morceaux + 1] = m.quantite .. "*" .. m.ref end
            out[#out + 1] = table.concat(morceaux, ",")
        end
    end
    return table.concat(out, ";")
end

function Prix.Deplier(chaine)
    local facons = {}
    for morceau in (tostring(chaine or "") .. ";"):gmatch("([^;]*);") do
        if morceau ~= "" then
            local facon = {}
            if morceau ~= "-" then
                for quantite, ref in morceau:gmatch("(%d+)%*([^,]+)") do
                    facon[#facon + 1] = { ref = ref, quantite = tonumber(quantite) }
                end
            end
            facons[#facons + 1] = facon
        end
    end
    return facons
end
