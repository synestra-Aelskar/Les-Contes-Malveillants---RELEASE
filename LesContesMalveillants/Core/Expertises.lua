-- Ce que les expertises APPORTENT au jeu.
--
-- A ne pas confondre avec `Equilibrage.apportsExpertises`, qui dit ce qui
-- NOURRIT une expertise (la Force nourrit la Puissance). Ici, c'est l'inverse :
-- ce qu'une expertise, une fois acquise, change ailleurs.
--
-- Le template ne les portait pas — elles etaient passees a la trappe lors de
-- la reprise, et remises le 11 octobre 2026. La table vit dans
-- `Equilibrage.effetsExpertises` ; ce fichier ne fait que la lire et la
-- rendre utilisable.
--
-- On compte sur la valeur TOTALE de l'expertise (investi + apports + bonus
-- portes), pas sur les seuls points investis : c'est ce que « une bonne
-- expertise » veut dire, et c'est deja ainsi que la fatigue lit l'Endurance.

local _, LCM = ...

local Expertises = {}
LCM.Expertises = Expertises

local function Eq() return LCM.Equilibrage end
local function Effets() return Eq().effetsExpertises or {} end

-- La valeur totale d'une expertise.
function Expertises.Valeur(entity, id)
    if not entity then return 0 end
    if LCM.Formules and LCM.Formules.Expertise then
        return tonumber(LCM.Formules.Expertise(entity, id)) or 0
    end
    return tonumber(entity[id]) or 0
end

local function Contient(liste, valeur)
    for _, v in ipairs(liste or {}) do if v == valeur then return true end end
    return false
end

-- ===== La part obligatoire ================================================
-- Un perce-armure force une part des degats a passer en sante, quoi qu'on
-- reparte. Les Resistances allegent cette part — elles ne retirent pas des
-- degats, elles rendent leur placement plus libre. Un personnage resistant
-- n'encaisse pas moins ; il choisit mieux ou il encaisse.

-- La fraction de la part obligatoire qu'on retire. Bornee a 1 : au-dela, la
-- part deviendrait negative et le calcul perdrait son sens.
function Expertises.AllegementObligatoire(entity)
    local regle = Effets().resistance
    local parPoint = regle and tonumber(regle.partObligatoire) or 0
    if parPoint == 0 then return 0 end
    local part = Expertises.Valeur(entity, "resistance") * parPoint
    if part < 0 then return 0 end
    if part > 1 then return 1 end
    return part
end

-- La part obligatoire, une fois allegee. Rend aussi ce qui a ete libere, pour
-- pouvoir l'ecrire.
function Expertises.PartObligatoire(entity, minimum)
    minimum = math.max(0, tonumber(minimum) or 0)
    if minimum == 0 then return 0, 0 end
    local allegement = Expertises.AllegementObligatoire(entity)
    if allegement <= 0 then return minimum, 0 end
    local reste = math.floor(minimum * (1 - allegement) + 0.5)
    if reste < 0 then reste = 0 end
    return reste, minimum - reste
end

-- ===== Les parades ========================================================
-- Parer une action, c'est y opposer un jet. Certaines expertises aident selon
-- la STATISTIQUE qu'on oppose : l'Equilibre et les Acrobaties portent
-- l'Adresse, l'Elementaire et le Cosmique portent l'Esprit, et l'Evasion
-- porte les deux.

-- Le bonus aux jets de parade sur une statistique donnee, et son detail.
-- Le detail compte : un jet qui monte sans qu'on sache pourquoi est un jet
-- qu'on soupconne.
function Expertises.BonusParade(entity, statId)
    statId = tostring(statId or "")
    local total, detail = 0, {}
    for id, regle in pairs(Effets()) do
        local parPoint = tonumber(regle.parade)
        if parPoint and Contient(regle.jets, statId) then
            local points = Expertises.Valeur(entity, id)
            if points ~= 0 then
                local bonus = points * parPoint
                total = total + bonus
                detail[#detail + 1] = { id = id, points = points, bonus = bonus,
                                        label = Expertises.Label(id) }
            end
        end
    end
    table.sort(detail, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return total, detail
end

-- ===== Ce qu'on produit ===================================================

-- Le supplement de degats, en fraction (0,05 pour 5 %), sur les mecaniques
-- que l'expertise sert.
function Expertises.BonusDegats(entity, mecaniqueId)
    mecaniqueId = tostring(mecaniqueId or "")
    local total = 0
    for id, regle in pairs(Effets()) do
        local parPoint = tonumber(regle.degats)
        if parPoint and Contient(regle.mecaniques, mecaniqueId) then
            total = total + Expertises.Valeur(entity, id) * parPoint
        end
    end
    return total
end

-- Le supplement au jet qui PRODUIT une action (a ne pas confondre avec une
-- parade, qui la subit).
function Expertises.BonusAction(entity, mecaniqueId)
    mecaniqueId = tostring(mecaniqueId or "")
    local total, detail = 0, {}
    for id, regle in pairs(Effets()) do
        local parPoint = tonumber(regle.rand)
        if parPoint and Contient(regle.mecaniques, mecaniqueId) then
            local points = Expertises.Valeur(entity, id)
            if points ~= 0 then
                total = total + points * parPoint
                detail[#detail + 1] = { id = id, points = points, label = Expertises.Label(id) }
            end
        end
    end
    return total, detail
end

-- Les metres gagnes sur la portee d'une action (la Projection sur la
-- Repulsion).
function Expertises.BonusPortee(entity, mecaniqueId)
    mecaniqueId = tostring(mecaniqueId or "")
    local total = 0
    for id, regle in pairs(Effets()) do
        local parPoint = tonumber(regle.portee)
        if parPoint and Contient(regle.mecaniques, mecaniqueId) then
            total = total + Expertises.Valeur(entity, id) * parPoint
        end
    end
    return total
end

-- Les yards gagnes sur un mode de deplacement (la Course sur le terrestre,
-- la Nage sur la nage). Sur la valeur TOTALE de l'expertise, comme tout le
-- reste de ce fichier : une race qui court vite doit se voir sur la fiche.
function Expertises.BonusDeplacement(entity, mode)
    mode = tostring(mode or "")
    local total = 0
    for id, regle in pairs(Effets()) do
        local parPoint = tonumber(regle.deplacement)
        if parPoint and Contient(regle.modes, mode) then
            total = total + Expertises.Valeur(entity, id) * parPoint
        end
    end
    return total
end

-- Le libelle d'une expertise, tel que la fiche le porte.
function Expertises.Label(id)
    local field = LCM.Schema and LCM.Schema.Field and LCM.Schema.Field(tostring(id or ""))
    return (field and field.label) or tostring(id or "")
end
