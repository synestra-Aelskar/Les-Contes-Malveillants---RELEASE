-- Le dot : un etat qui GRIGNOTE une jauge a chaque round.
--
-- Il se compose comme un debuff — un pool de points qu'on repartit — mais ce
-- qu'il pose n'est pas un malus de statistique : c'est une morsure qui revient
-- tant que l'etat tient. Le bareme (ce que coute chaque pool, ce que vaut un
-- point) vit dans Data/Equilibrage.lua, comme tous les nombres du jeu.
--
-- DEUX FACONS DE MORDRE, et c'est la seule subtilite du module :
--
--   * une jauge UNIQUE (bouclier, fatigue) se grignote toute seule : il n'y
--     a qu'elle, tout le monde a la meme, personne n'a de choix a faire ;
--   * les points de vie et l'etat des armures sont repartis en ZONES propres a
--     la silhouette de la cible. Personne d'autre que son porteur ne sait ou le
--     coup tombe. Le dot n'y touche donc pas : il pose une NOTE a jouer, et
--     c'est la cible qui applique, selon ce que la note raconte.
--
-- LES STACKS. Chaque stack mord une fois par round : deux stacks a 5 % font
-- 10 % dans le round. Ils partagent un seul jet a battre (`rand`), qui BAISSE
-- d'un point par round — un dot ancien se decroche plus facilement qu'un dot
-- frais. Les dissiper n'est pas tout ou rien : battre le rand en retire un, et
-- chaque point au-dessus en retire un de plus.

local _, LCM = ...

local Dot = {}
LCM.Dot = Dot

local function Reglages() return (LCM.Equilibrage and LCM.Equilibrage.dot) or {} end

function Dot.Cibles() return Reglages().cibles or {} end

function Dot.Cible(id)
    for _, c in ipairs(Dot.Cibles()) do
        if c.id == tostring(id or "") then return c end
    end
    return nil
end

-- ===== Ce que coute une composition ========================================

-- `choix` : { [cibleId] = points, rounds = points, stacks = points }. Rend le
-- total, et le detail ligne par ligne pour que le composeur puisse l'afficher
-- sans refaire le calcul.
function Dot.Cout(choix)
    choix = type(choix) == "table" and choix or {}
    local r, total, lignes = Reglages(), 0, {}
    for _, cible in ipairs(Dot.Cibles()) do
        local points = math.max(0, math.floor(tonumber(choix[cible.id]) or 0))
        if points > 0 then
            local cout = points * cible.cout
            total = total + cout
            lignes[#lignes + 1] = { id = cible.id, label = cible.label, points = points, cout = cout }
        end
    end
    local rounds = math.max(0, math.floor(tonumber(choix.rounds) or 0))
    if rounds > 0 then
        total = total + rounds * (r.coutRound or 0)
        lignes[#lignes + 1] = { id = "rounds", label = "Rounds", points = rounds,
                                cout = rounds * (r.coutRound or 0) }
    end
    local stacks = math.max(0, math.floor(tonumber(choix.stacks) or 0))
    if stacks > 0 then
        total = total + stacks * (r.coutStack or 0)
        lignes[#lignes + 1] = { id = "stacks", label = "Stacks", points = stacks,
                                cout = stacks * (r.coutStack or 0) }
    end
    return total, lignes
end

-- Ce qu'une composition donne vraiment : la duree, le nombre de stacks, et ce
-- qui sera mordu. Separe du cout : le composeur montre l'un pendant qu'on
-- depense l'autre.
function Dot.Composer(choix)
    choix = type(choix) == "table" and choix or {}
    local r = Reglages()
    local morsures = {}
    for _, cible in ipairs(Dot.Cibles()) do
        local points = math.max(0, math.floor(tonumber(choix[cible.id]) or 0))
        if points > 0 then
            morsures[#morsures + 1] = {
                id = cible.id, label = cible.label, jauge = cible.jauge,
                zonee = cible.zonee == true, note = cible.note,
                points = points,
                -- Par stack et par round : c'est le point investi qui dit
                -- combien, le stack multiplie ensuite.
                taux = cible.taux and cible.taux * points or nil,
                plat = cible.plat and cible.plat * points or nil,
            }
        end
    end
    return {
        rounds = (r.roundsBase or 1) + math.max(0, math.floor(tonumber(choix.rounds) or 0)),
        stacks = (r.stacksBase or 1) + math.max(0, math.floor(tonumber(choix.stacks) or 0)),
        morsures = morsures,
    }
end

-- ===== Ce qu'on a a depenser ===============================================
-- Le pool, bati comme celui du buff : une statistique source, la moyenne des
-- penetrations choisies, le niveau du sort, le tout module par la puissance de
-- la mecanique « Dot ».
--
-- `choix` : { source = "force", penetrations = { feu = true }, niveau = n }.
-- La moyenne vient des caracteristiques du personnage, pas d'un champ libre.
function Dot.PenetrationMoyenne(entity, choix)
    local somme, nombre = 0, 0
    local selection = type(choix) == "table" and choix or {}
    for _, ty in ipairs((LCM.Equilibrage and LCM.Equilibrage.types) or {}) do
        if selection[ty.id] and LCM.Actions and LCM.Actions.ValeurType then
            local valeur = tonumber(LCM.Actions.ValeurType(ty.id, "Penetrations", entity)) or 0
            if valeur > 0 then somme, nombre = somme + valeur, nombre + 1 end
        end
    end
    return nombre > 0 and somme / nombre or 0
end

function Dot.Pool(entity, choix)
    choix = type(choix) == "table" and choix or {}
    local r = Reglages()
    local p = r.pool or {}
    local source = 0
    if choix.source and LCM.Formules and LCM.Formules.Primaire then
        source = tonumber(LCM.Formules.Primaire(entity, choix.source)) or 0
    end
    local penetration = Dot.PenetrationMoyenne(entity, choix.penetrations)
    local brut = source * (p.parSource or 0)
        + penetration * (p.parPen or 0)
        + (tonumber(choix.niveau) or 0) * (p.parNiveau or 0)
    -- La puissance de la mecanique, en pourcentage : (base + parPoint x points
    -- investis + equipParPoint x points d'equipement) / 100. C'est la grille
    -- commune a toutes les mecaniques, et elle se regle desormais mecanique par
    -- mecanique (Core/Reglages.lua).
    local mult = 1
    if LCM.Reglages and LCM.Reglages.PuissanceMecanique then
        local g = LCM.Reglages.PuissanceMecanique("dot")
        local points = tonumber(LCM.Entities.Get_Value(entity, "meca_dot")) or 0
        local equip = (LCM.Effets and LCM.Effets.Bonus) and LCM.Effets.Bonus(entity, "meca_dot") or 0
        mult = (g.base + g.parPoint * points + g.equipParPoint * equip) / 100
    end
    return math.max(0, math.floor(brut * mult)), brut, mult
end

-- Ce que la resistance de la cible fait au grignotage.
--
-- A penetration egale a la resistance, le facteur vaut 1 : ni l'un ni l'autre
-- ne l'emporte, ce qui est la regle voulue. La cible qui resiste mieux encaisse
-- moins, celle qui resiste moins encaisse plus — borne des deux cotes pour
-- qu'un dot ne soit jamais ni nul ni devastateur.
function Dot.FacteurResistance(penetration, resistance)
    local pen = math.max(0, tonumber(penetration) or 0)
    local resi = math.max(0, tonumber(resistance) or 0)
    local bornes = Reglages().resistance or {}
    if pen + resi <= 0 then return 1 end
    local facteur = 2 * pen / (pen + resi)
    return math.max(bornes.plancher or 0, math.min(bornes.plafond or math.huge, facteur))
end

-- ===== Poser ===============================================================

-- `def` : { nom, icone, description, choix, jet, lanceur, conteneur }.
-- `jet` : le score du lanceur, que la dissipation devra battre.
function Dot.Poser(entity, def)
    if type(entity) ~= "table" or type(def) ~= "table" then return nil, "rien a poser." end
    local compose = Dot.Composer(def.choix)
    if #compose.morsures == 0 then return nil, "ce dot ne grignote rien." end
    local nom = tostring(def.nom or "Dot")
    -- Le reste de l'addon lit le jet du lanceur comme une TABLE
    -- ({ valeur, competence }) : c'est ce que la dissipation interroge
    -- (Actions.Resume). On accepte un nombre par commodite d'appel, et on le
    -- met en forme ici plutot que de laisser chaque appelant s'en souvenir.
    local jet = def.jet
    if type(jet) ~= "table" then
        jet = { valeur = tonumber(jet) or 0, competence = def.competence }
    end
    local etat = LCM.EtatsTemporaires.Poser(entity, {
        nom = nom, icone = def.icone, description = def.description,
        rounds = compose.rounds, lanceur = def.lanceur, debuff = true,
        conteneur = def.conteneur or "etat",
        id = def.id or ("dot_" .. nom:lower()),
        jet = jet,
        dissipation = def.dissipation or "dot",
        -- Tout ce qui fait de cet etat un dot tient ici : le reste de l'addon
        -- voit un etat temporaire ordinaire.
        dot = {
            stacks = compose.stacks,
            morsures = compose.morsures,
            rand = tonumber(jet.valeur) or 0,
            -- Fige a la POSE : c'est la resistance qu'avait la cible quand le
            -- dot l'a touchee. La recalculer a chaque round ferait varier la
            -- morsure au gre d'un buff pose entre-temps, ce qui se discuterait
            -- a chaque tour de table.
            facteur = tonumber(def.facteur) or 1,
        },
    })
    return etat
end

-- ===== Mordre, une fois par round ==========================================

local function Jauge(entity, id)
    return LCM.Entities and LCM.Entities.Gauge and LCM.Entities.Gauge(entity, id) or nil
end

-- Ce qu'une morsure retire ce round-ci, pour ce nombre de stacks. Le taux porte
-- sur le MAXIMUM de la jauge : le grignotage ne faiblit pas a mesure qu'elle
-- descend, sinon il ne finirait jamais le travail.
--
-- Arrondi au superieur : 5 % d'une jauge de 12 font 0,6, et une morsure qui ne
-- retire rien n'est pas une morsure.
function Dot.Montant(entity, morsure, stacks, facteur)
    stacks = math.max(1, math.floor(tonumber(stacks) or 1))
    facteur = tonumber(facteur) or 1
    if morsure.plat then return math.ceil(morsure.plat * stacks * facteur - 1e-9) end
    if not morsure.taux then return 0 end
    local maximum
    if morsure.jauge then
        local jauge = Jauge(entity, morsure.jauge)
        maximum = jauge and tonumber(jauge.max) or nil
    else
        -- Zonee : la note parle en pourcentage, il n'y a pas de maximum unique
        -- a lire. C'est la cible qui saura sur quoi l'appliquer.
        return nil
    end
    if not maximum or maximum <= 0 then return 0 end
    return math.ceil(maximum * morsure.taux * stacks * facteur - 1e-9)
end

-- Un round passe : chaque dot mord, puis son rand baisse.
--
-- Rend ce qui s'est passe — ce qui a ete retire, et les NOTES a jouer — pour
-- que l'ecran et le journal le disent. On n'applique jamais une jauge zonee :
-- on rend sa note, et la cible s'en charge.
function Dot.Tic(entity)
    local faits = {}
    if type(entity) ~= "table" then return faits end
    for _, etat in ipairs(LCM.EtatsTemporaires.Liste(entity)) do
        local d = etat.dot
        if type(d) == "table" then
            local stacks = math.max(1, math.floor(tonumber(d.stacks) or 1))
            local facteur = tonumber(d.facteur) or 1
            for _, morsure in ipairs(d.morsures or {}) do
                if morsure.zonee then
                    faits[#faits + 1] = {
                        etat = etat.nom, cible = morsure.id, zonee = true, stacks = stacks,
                        pourcent = (morsure.taux or 0) * stacks * facteur * 100,
                        note = string.format("%s : %d %% de %s (%d stack%s) — à répartir selon la note.",
                            etat.nom, math.ceil((morsure.taux or 0) * stacks * facteur * 100 - 1e-9),
                            morsure.note or morsure.label, stacks, stacks > 1 and "s" or ""),
                    }
                else
                    local montant = Dot.Montant(entity, morsure, stacks, facteur)
                    if montant and montant > 0 then
                        local jauge = Jauge(entity, morsure.jauge)
                        if jauge then
                            local avant = tonumber(jauge.current) or 0
                            local apres = math.max(0, avant - montant)
                            LCM.Entities.SetGauge(entity, morsure.jauge, apres)
                            faits[#faits + 1] = { etat = etat.nom, cible = morsure.id,
                                                  jauge = morsure.jauge, stacks = stacks,
                                                  retire = avant - apres }
                        end
                    end
                end
            end
            -- Le rand baisse APRES la morsure : le round ou l'on pose compte
            -- pour le jet du lanceur, pas pour sa decroissance.
            d.rand = (tonumber(d.rand) or 0) - (Reglages().randParRound or 0)
        end
    end
    if #faits > 0 and LCM.EtatsTemporaires.onChange then LCM.EtatsTemporaires.onChange(entity) end
    return faits
end

-- ===== Dissiper ============================================================

-- Battre le rand en retire UN stack ; chaque point au-dessus en retire un de
-- plus. Un score qui ne bat pas le rand ne retire rien.
--
--     rand 11, score 12 -> 12 - 11 + 1 = 2 stacks
--
-- A zero stack, l'etat s'en va.
-- Rend le nombre de stacks retires, ce qu'il en reste, et le rand qu'il
-- fallait battre.
function Dot.Dissiper(entity, nomOuId, score)
    score = math.floor(tonumber(score) or 0)
    for _, etat in ipairs(LCM.EtatsTemporaires.Liste(entity)) do
        if etat.nom == nomOuId or (etat.id ~= nil and etat.id == nomOuId) then
            local d = etat.dot
            if type(d) ~= "table" then return nil, "« " .. tostring(etat.nom) .. " » n'est pas un dot." end
            local rand = tonumber(d.rand) or 0
            if score <= rand then return 0, d.stacks, rand end
            local partis = math.min(d.stacks, score - rand + 1)
            d.stacks = d.stacks - partis
            if d.stacks <= 0 then
                LCM.EtatsTemporaires.Retirer(entity, etat.id or etat.nom, true)
                return partis, 0, rand
            end
            if LCM.EtatsTemporaires.onChange then LCM.EtatsTemporaires.onChange(entity) end
            return partis, d.stacks, rand
        end
    end
    return nil, "aucun dot de ce nom."
end

-- Ce qu'un dot retire par round, en clair : « Bouclier -3, PV 10 % ». Ce que
-- l'on sait chiffrer est chiffre ; une jauge zonee se dit en pourcentage,
-- puisque personne d'autre que son porteur ne connait le maximum de la zone
-- ou le coup tombera.
function Dot.Resume(entity, etat)
    local d = type(etat) == "table" and etat.dot
    if type(d) ~= "table" then return nil end
    local stacks = math.max(1, math.floor(tonumber(d.stacks) or 1))
    local facteur = tonumber(d.facteur) or 1
    local bouts = {}
    for _, morsure in ipairs(d.morsures or {}) do
        if morsure.zonee then
            bouts[#bouts + 1] = string.format("%s %d %%", morsure.label,
                math.ceil((morsure.taux or 0) * stacks * facteur * 100 - 1e-9))
        else
            local montant = Dot.Montant(entity, morsure, stacks, facteur)
            bouts[#bouts + 1] = string.format("%s -%d", morsure.label, montant or 0)
        end
    end
    return table.concat(bouts, ", "), stacks, tonumber(d.rand) or 0
end

-- ===== La bibliotheque =====================================================
-- Les compositions que le joueur garde. Meme idee que celle du constructeur
-- d'effets (LCM.db.modelesEffets) : une brulure qu'on relance souvent ne se
-- recompose pas point par point a chaque fois. Donnee du JOUEUR, rangee avec
-- ses reglages.

local function Bibliotheque()
    LCM.EnsureDatabase()
    LCM.db.modelesDots = type(LCM.db.modelesDots) == "table" and LCM.db.modelesDots or {}
    return LCM.db.modelesDots
end

function Dot.Modeles()
    local out = {}
    for _, m in ipairs(Bibliotheque()) do out[#out + 1] = m end
    table.sort(out, function(a, b) return tostring(a.nom):lower() < tostring(b.nom):lower() end)
    return out
end

-- Enregistre, ou remplace celui du meme nom : on retouche un modele en le
-- reenregistrant, on n'en accumule pas trois versions.
function Dot.Enregistrer(nom, description, icone, choix, conteneur)
    nom = tostring(nom or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nom == "" then return false, "il faut un nom." end
    if type(choix) ~= "table" then return false, "rien a enregistrer." end
    local compose = Dot.Composer(choix)
    if #compose.morsures == 0 then return false, "ce dot ne grignote rien." end
    local copie = {}
    for cle, valeur in pairs(choix) do
        if cle == "penetrations" and type(valeur) == "table" then
            copie[cle] = {}
            for id, actif in pairs(valeur) do copie[cle][id] = actif end
        else copie[cle] = valeur end
    end
    local modele = { nom = nom, description = tostring(description or ""), icone = icone,
                     conteneur = conteneur, choix = copie }
    local liste = Bibliotheque()
    for rang, m in ipairs(liste) do
        if tostring(m.nom):lower() == nom:lower() then liste[rang] = modele return true, nom end
    end
    liste[#liste + 1] = modele
    return true, nom
end

function Dot.Oublier(nom)
    local liste = Bibliotheque()
    for rang, m in ipairs(liste) do
        if tostring(m.nom):lower() == tostring(nom or ""):lower() then
            table.remove(liste, rang)
            return true
        end
    end
    return false
end

-- Les dots portes, pour les ecrans qui veulent les lister a part.
function Dot.Liste(entity)
    local out = {}
    for _, etat in ipairs(LCM.EtatsTemporaires.Liste(entity)) do
        if type(etat.dot) == "table" then out[#out + 1] = etat end
    end
    return out
end
