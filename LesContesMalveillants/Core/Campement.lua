-- Le campement : les tentes et leurs accessoires.
--
-- Ce n'est pas une regle du template : le template Necronicon n'a pas de
-- campement. Le systeme vient de l'ancienne feuille de calcul du MJ (onglets
-- « Campement », « Tente », « Accesoire de Camping »), repris le 10 octobre
-- 2026. Ce fichier pose le contenu (ce qu'une tente et un accessoire
-- apportent), le calcul d'une nuit et le deroule d'un campement.
--
-- Ce qu'une tente ou un accessoire apporte est un vrai bonus, en POURCENTAGE
-- ENTIER : la forge ne dose que des entiers, et la feuille ecrivait deja
-- « +20 % ». 0,3 dans la feuille s'ecrit donc 30 ici. Une entree ne porte que
-- les bonus qu'elle donne : une tente peut n'agir que sur la securite.
--
-- Ecarts a la feuille, voulus :
--   * la « Couleur » et l'« ILevel » ne sont pas des champs : ce sont la
--     rarete et le pool du jeu d'equilibrage de l'entree (Core/Forge.lua) ;
--   * « Filtre meteo » et « Meteo encaissable » attendent le systeme meteo,
--     « Durabilite » attend d'etre decidee : aucun des trois n'est pose.

local _, LCM = ...

local function Texte(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Les bonus d'un campement, dans l'ordre des colonnes de la feuille. Ce sont
-- les seules cles qu'une tente ou un accessoire peut porter : un bonus de
-- fiche (Force...) n'aurait personne a qui s'appliquer pendant le camp.
-- Les libelles sont ceux du MJ pour ses jeux d'equilibrage « custom » (10
-- octobre 2026) ; les cles, elles, ne bougent plus.
LCM.CAMPEMENT_BONUS = {
    { cle = "securite",      label = "Sécurité" },
    { cle = "recup_fatigue", label = "Fatigue" },
    { cle = "recup_pv",      label = "Soin" },
    { cle = "recup_armure",  label = "Armure" },
}
local BONUS_CONNU = {}
for _, b in ipairs(LCM.CAMPEMENT_BONUS) do BONUS_CONNU[b.cle] = b end

local function Bonus(id, definition, Erreur)
    local bonus = {}
    for cle, valeur in pairs(type(definition.bonus) == "table" and definition.bonus or {}) do
        cle = tostring(cle)
        if not BONUS_CONNU[cle] then
            Erreur(string.format("%s : bonus de campement inconnu (%s)", id, cle))
        end
        local n = tonumber(valeur)
        -- Un pourcentage entier : 0,3 n'est pas refuse en silence ni arrondi,
        -- il est refuse avec ce qu'il fallait ecrire.
        if not n or n ~= math.floor(n) then
            Erreur(string.format("%s : %s illisible (%s), attendu un pourcentage entier (30 pour 0,3)",
                id, BONUS_CONNU[cle].label, tostring(valeur)))
        end
        if n ~= 0 then bonus[cle] = n end
    end
    return bonus
end

local function Origine(definition)
    local origine = Texte(definition.origine)
    return origine ~= "" and origine or nil
end

-- « Accessoire de camping » : ce qu'on installe sous une tente.
LCM.AccessoiresCamping = LCM.Registre({
    nom = "accessoire de camping", prefixe = "AccessoiresCamping",
    construire = function(definition, element, Erreur)
        element.bonus = Bonus(element.id, definition, Erreur)
        element.origine = Origine(definition)
    end,
})

local function Entier(id, nom, valeur, minimum, Erreur)
    if valeur == nil or Texte(valeur) == "" then return nil end
    local n = tonumber(valeur)
    if not n or n ~= math.floor(n) or n < minimum then
        Erreur(string.format("%s : %s invalide (%s)", id, nom, tostring(valeur)))
    end
    return n
end

-- « Tente » : ou dort le groupe. Elle a son registre, mais se PORTE COMME UN
-- SAC (10 octobre 2026) : sur un emplacement de sacoche, avec autant de cases
-- que d'accessoires maximum, et ces cases ne recoivent que des accessoires de
-- camping (Core/Inventaire.lua). Les accessoires inclus viennent avec elle et
-- prennent deja leur place.
LCM.Tentes = LCM.Registre({
    nom = "tente", prefixe = "Tentes",
    construire = function(definition, element, Erreur)
        local id = element.id
        element.bonus = Bonus(id, definition, Erreur)
        element.origine = Origine(definition)
        element.lits = Entier(id, "lits", definition.lits, 1, Erreur)
        element.accessoiresMax = Entier(id, "accessoires max", definition.accessoiresMax, 0, Erreur)
        element.accessoires = nil
        if definition.accessoires ~= nil then
            if type(definition.accessoires) ~= "table" then Erreur(id .. " : accessoires inclus illisibles") end
            local liste = {}
            for _, a in ipairs(definition.accessoires) do
                local s = Texte(a)
                if s ~= "" then liste[#liste + 1] = s end
            end
            -- Plus d'accessoires inclus que la tente n'en accepte : refuse, pas
            -- rabote. C'est au MJ de choisir lequel retirer.
            if element.accessoiresMax and #liste > element.accessoiresMax then
                Erreur(string.format("%s : %d accessoires inclus pour %d places", id, #liste, element.accessoiresMax))
            end
            element.accessoires = #liste > 0 and liste or nil
        end
    end,
})

-- Les accessoires inclus visent des entrees qui peuvent etre declarees plus
-- loin (fichiers generes, entrees du MJ) : verifies a la connexion, sans rien
-- refuser — une reference perdue s'affiche marquee « ? » dans le compendium.
LCM.WhenReady(function()
    for _, tente in ipairs(LCM.Tentes.list) do
        for _, ref in ipairs(tente.accessoires or {}) do
            if not LCM.AccessoiresCamping.Get(ref) then
                LCM.Erreur(string.format("tente « %s » : accessoire inclus inconnu (%s)", tente.label, ref))
            end
        end
    end
end)

-- ===== Le calcul ===========================================================
-- Ce qu'une nuit rend a UN participant, d'apres ses heures, la tente du
-- responsable et le nombre de campeurs. Les formules sont celles de la feuille
-- (« Fatigue Restauree », « Vitalite Restauree ») ; ce qui y manque est dit
-- dans `manques`, jamais devine.

local Campement = {}
LCM.Campement = Campement

-- Resolu a l'appel : Core se charge avant Data.
local function Eq() return LCM.Equilibrage.campement end

-- Arrondi « loin de zero », comme ARRONDI.SUP du tableur sur une valeur signee.
local function LoinDeZero(x)
    if x >= 0 then return math.ceil(x) end
    return -math.ceil(-x)
end

-- ARRONDI(x ; decimales) : sans lui, 0,1 x 3 ferait 0,30000000000000004 et
-- l'arrondi superieur donnerait un point de trop.
local function Arrondi(x, decimales)
    if not decimales then return x end
    local p = 10 ^ decimales
    return math.floor(x * p + 0.5) / p
end

-- Ce que la tente, ses accessoires inclus ET ceux qu'on y a installes
-- (`installes`, des identifiants) apportent sur un bonus, en fraction
-- (30 % -> 0,3). Sans tente, des accessoires seuls ne s'installent nulle part.
function Campement.Bonus(tente, cle, installes)
    if type(tente) ~= "table" then return 0 end
    local total = tonumber(tente.bonus and tente.bonus[cle]) or 0
    local function Ajouter(ids)
        for _, ref in ipairs(ids or {}) do
            local a = LCM.AccessoiresCamping.Get(ref)
            total = total + (tonumber(a and a.bonus[cle]) or 0)
        end
    end
    Ajouter(tente.accessoires)
    Ajouter(installes)
    return total / 100
end

-- Les attributs du camp (bloc « Attribues » de la feuille), en pourcentage :
-- la tente plus chacun de ses accessoires. C'est la formule de securite de la
-- feuille (« tente + SOMME des accessoires »), et la meme somme vaut pour les
-- trois recuperations.
function Campement.Attributs(tente, installes)
    local out = {}
    for _, b in ipairs(LCM.CAMPEMENT_BONUS) do
        out[#out + 1] = { cle = b.cle, label = b.label, valeur = math.floor(Campement.Bonus(tente, b.cle, installes) * 100 + 0.5) }
    end
    return out
end

function Campement.Action(id)
    for _, a in ipairs(Eq().actions) do
        if a.id == id then return a end
    end
    return nil
end

-- `heures` : id d'action -> MINUTES passees dessus (converties en heures, l'unite
-- des formules de la feuille). Rend { fatigue, ps, manques }.
function Campement.Calculer(entity, heures, tente, campeurs, installes)
    local e = Eq()
    heures = type(heures) == "table" and heures or {}
    local manques = {}
    local function Manque(texte)
        for _, m in ipairs(manques) do if m == texte then return end end
        manques[#manques + 1] = texte
    end

    -- Fatigue : max x base x (1 + bonus de la tente) x somme des heures
    -- ponderees, plafonnee, arrondie, puis reduite si la tente deborde.
    local jauge = LCM.Entities.Gauge(entity, "fatigue")
    local maximum = jauge and tonumber(jauge.max) or 0
    local mult = maximum * e.fatigue.base * (1 + Campement.Bonus(tente, "recup_fatigue", installes))
    local somme = 0
    for _, action in ipairs(e.actions) do
        local h = (tonumber(heures[action.id]) or 0) / e.minutesParHeure
        if h > 0 then
            local facteur = action.categorie and e.coefActions[action.categorie]
            if not action.categorie then
                Manque(action.label .. " n'a pas de catégorie d'action")
            elseif not action.fatigue then
                Manque("coefficient de fatigue inconnu pour " .. action.label)
            elseif facteur then
                somme = somme + h * facteur * action.fatigue
            end
        end
    end
    local total = somme * mult
    if e.plafondFatigue then
        local borne = e.plafondFatigue * mult
        total = math.min(math.max(total, -borne), borne)
    end
    local fatigue = LoinDeZero(Arrondi(total, e.fatigue.decimales))
    local lits = (type(tente) == "table" and tente.lits) or e.litsParDefaut
    local surplus = math.max(0, (tonumber(campeurs) or 1) - lits)
    if fatigue > 0 and surplus > 0 then
        fatigue = LoinDeZero(fatigue * math.max(0, 1 - surplus * e.surpopulation / 100))
    end

    -- PS : base x (soin x parSoin + sommeil x parSommeil) x (1 + bonus PV).
    local soin, sommeil = 0, 0
    for _, action in ipairs(e.actions) do
        local h = (tonumber(heures[action.id]) or 0) / e.minutesParHeure
        if action.categorie == "soin" then soin = soin + h end
        if action.categorie == "sommeil" then sommeil = sommeil + h end
    end
    local v = e.vitalite
    local ps = v.base * (soin * v.parSoin + sommeil * v.parSommeil) * (1 + Campement.Bonus(tente, "recup_pv", installes))
    ps = math.ceil(math.max(0, Arrondi(ps, v.decimales)))

    -- Armure et securite : la feuille a leurs bases (ARMOR_BASE, SECU_BASE),
    -- pas leurs formules.
    if (tonumber(heures.reparer) or 0) > 0 then Manque("la formule de l'armure restaurée n'est pas encore définie") end
    return { fatigue = fatigue, ps = ps, manques = manques }
end

-- ===== Le deroule ==========================================================
-- Un joueur lance le campement, le groupe est invite, chacun accepte ou
-- refuse. Le MJ donne les unites de temps de la nuit ; chaque participant les
-- repartit entre les actions et se declare pret. Quand tous le sont, le
-- responsable valide : chacun encaisse ce que ses choix lui rendent, et ceux
-- qui ont soigne distribuent leurs PS.
--
-- Chaque client calcule SON regain avec SES heures : rien de ce qui touche a
-- la fiche ne voyage, seulement les choix. Les messages passent par le groupe
-- (sauf les PS, d'un soigneur a un receveur), pour que tout le monde voie qui
-- en est ou.

Campement.courant = nil

local function Moi() return LCM.PlayerId() end
local function Perso() return LCM.Entities.Self() end
local function Dire(texte) if LCM.Info then LCM.Info(texte) end end
local function Refuser(texte) if LCM.Alerte then LCM.Alerte(texte) end end

local temoins = {}
function Campement.Observer(handler)
    if type(handler) == "function" then temoins[#temoins + 1] = handler end
end
local function Prevenir()
    for _, handler in ipairs(temoins) do handler(Campement.courant) end
end

local function Canal() return LCM.Combat and LCM.Combat.CanalGroupe() end

local function Envoyer(sujet, donnees)
    local camp = Campement.courant
    local canal = Canal()
    if not (camp and canal and LCM.Reseau) then return false end
    donnees = donnees or {}
    donnees.c = camp.id
    return LCM.Reseau.Envoyer("CAMP_" .. sujet, donnees, canal)
end

local function Chuchoter(sujet, qui, donnees)
    local camp = Campement.courant
    if not (camp and LCM.Reseau) then return false end
    donnees = donnees or {}
    donnees.c = camp.id
    return LCM.Reseau.Envoyer("CAMP_" .. sujet, donnees, "WHISPER", qui)
end

-- Les tentes que ce personnage a EQUIPEES (emplacements de sacoche) : on ne
-- campe que sous la sienne. Chacune vient avec les accessoires rangés dedans.
-- Rend { { tente, onglet, index, installes = { id, ... } }, ... }.
function Campement.TentesPossedees(entity)
    local out = {}
    local Inv = LCM.Inventaire
    for _, categorie in ipairs(Inv.categories) do
        for index = 1, Inv.Capacite(categorie.id) do
            local e = Inv.Emplacement(entity, categorie.id, index)
            local tente = e and e.tente and LCM.Tentes.Get(e.tente)
            if tente then
                local installes = {}
                for case = 1, Inv.Cases(e) do
                    local c = Inv.Case(e, case)
                    local id = c and tostring(c.ref or ""):match("^accessoires_camping/(.+)$")
                    if id then installes[#installes + 1] = id end
                end
                out[#out + 1] = { tente = tente, onglet = categorie.id, index = index, installes = installes }
            end
        end
    end
    return out
end

function Campement.Tente()
    local camp = Campement.courant
    return camp and camp.tente and LCM.Tentes.Get(camp.tente) or nil
end

-- Ce que le camp apporte sur un bonus : la tente du responsable, ses inclus et
-- ce qu'il y a installe (envoye avec l'invitation : personne d'autre ne voit
-- son inventaire).
function Campement.BonusCamp(cle)
    local camp = Campement.courant
    return Campement.Bonus(Campement.Tente(), cle, camp and camp.accessoires)
end

local function NouveauCamp(id, chef, tente, role, accessoires)
    return { id = id, chef = chef, tente = tente, role = role, membres = {},
             accessoires = accessoires or {},
             heures = {}, pret = false, etape = "preparation",
             psDisponibles = 0, psRecus = {} }
end

-- Ceux qui campent : qui a dit oui.
function Campement.Participants()
    local camp = Campement.courant
    local out = {}
    if not camp then return out end
    for nom, m in pairs(camp.membres) do
        if m.statut == "oui" then out[#out + 1] = nom end
    end
    table.sort(out)
    return out
end

function Campement.Participe()
    local camp = Campement.courant
    local m = camp and camp.membres[Moi()]
    return m ~= nil and m.statut == "oui"
end

-- `tenteId` : nil pour dormir sans tente.
function Campement.Lancer(tenteId)
    if Campement.courant then return false, "un campement est déjà en cours." end
    if not Canal() then return false, "il faut être en groupe pour camper." end
    local installes
    if tenteId then
        if not LCM.Tentes.Get(tenteId) then return false, "tente inconnue." end
        for _, p in ipairs(Campement.TentesPossedees(Perso())) do
            if p.tente.id == tenteId and not installes then installes = p.installes end
        end
        if not installes then return false, "cette tente n'est pas équipée (emplacement de sacoche)." end
    end
    local moi = Moi()
    local camp = NouveauCamp(moi .. ":" .. tostring(math.floor(GetTime and GetTime() or 0)), moi, tenteId, "chef",
        installes)
    camp.membres[moi] = { statut = "oui" }
    for _, nom in ipairs(LCM.Combat.Membres()) do camp.membres[nom] = { statut = "invite" } end
    Campement.courant = camp
    Envoyer("INVITE", { t = tenteId, a = installes })
    Dire("campement lancé : le groupe est invité.")
    Prevenir()
    return true
end

local function SurInvite(qui, d)
    if qui == Moi() then return end
    local camp = Campement.courant
    if camp then
        -- Deja pris : on le dit, pour que le responsable n'attende pas.
        if LCM.Reseau and Canal() then
            LCM.Reseau.Envoyer("CAMP_REPONSE", { c = d.c, ok = 0 }, Canal())
        end
        return
    end
    -- Le MJ ne campe pas : il donne le temps de la nuit.
    local role = LCM.IsMaster() and "mj" or "invite"
    camp = NouveauCamp(d.c, qui, d.t, role, type(d.a) == "table" and d.a or nil)
    camp.membres[qui] = { statut = "oui" }
    Campement.courant = camp
    if role == "mj" then
        Envoyer("REPONSE", { ok = 0, mj = 1 })
        Dire(string.format("%s lance un campement : donne-lui ses unités de temps.", qui))
    else
        camp.membres[Moi()] = { statut = "invite" }
        Dire(string.format("%s lance un campement.", qui))
    end
    Prevenir()
end

function Campement.Repondre(oui)
    local camp = Campement.courant
    if not (camp and camp.role == "invite") then return false, "aucune invitation en cours." end
    Envoyer("REPONSE", { ok = oui and 1 or 0 })
    if not oui then
        Campement.courant = nil
        Prevenir()
        return true
    end
    camp.membres[Moi()] = { statut = "oui" }
    camp.role = "participant"
    Prevenir()
    return true
end

local function Mien(qui, d)
    local camp = Campement.courant
    return camp and d and d.c == camp.id and qui ~= Moi()
end

local function SurReponse(qui, d)
    if not Mien(qui, d) then return end
    local camp = Campement.courant
    local statut = tonumber(d.mj) == 1 and "mj" or (tonumber(d.ok) == 1 and "oui" or "non")
    camp.membres[qui] = { statut = statut }
    Prevenir()
end

-- Le MJ fixe le temps de la nuit. Le changer remet tout le monde a zero :
-- des choix faits pour 22 unites ne valent rien pour 18.
function Campement.FixerUnites(n)
    local camp = Campement.courant
    if not camp then return false, "aucun campement en cours." end
    if not LCM.IsMaster() then return false, "seul le maître du jeu donne les unités de temps." end
    n = tonumber(n)
    if not n or n < 1 or n ~= math.floor(n) then return false, "indique un nombre entier d'unités." end
    Envoyer("UNITES", { u = n })
    camp.unites, camp.fixePar = n, Moi()
    for _, m in pairs(camp.membres) do m.pret = false end
    Prevenir()
    return true
end

local function SurUnites(qui, d)
    if not Mien(qui, d) then return end
    local camp = Campement.courant
    camp.unites, camp.fixePar = tonumber(d.u), qui
    camp.pret = false
    for _, m in pairs(camp.membres) do m.pret = false end
    Prevenir()
end

function Campement.Reparties()
    local camp = Campement.courant
    local total = 0
    for _, h in pairs(camp and camp.heures or {}) do total = total + h end
    return total
end

-- Retoucher ses heures retire le « pret » : le responsable ne valide que ce
-- que chacun a vu.
function Campement.Repartir(actionId, h)
    local camp = Campement.courant
    if not (camp and Campement.Participe()) then return false, "tu ne participes pas à ce campement." end
    if camp.etape ~= "preparation" then return false, "la nuit est déjà passée." end
    if not Campement.Action(actionId) then return false, "action inconnue." end
    h = math.floor(tonumber(h) or 0)
    if h < 0 then return false, "un nombre d'unités ne peut pas être négatif." end
    camp.heures[actionId] = h > 0 and h or nil
    if camp.pret then
        camp.pret = false
        camp.membres[Moi()].pret = false
        Envoyer("PRET", { ok = 0 })
    end
    Prevenir()
    return true
end

-- Les boutons d'aide (« +1h » / « -1h ») : ajoute ou retire `minutes` a une
-- action, pris sur ce qui reste a repartir. Pas assez de temps, ou pas assez
-- pose : refuse, avec ce qu'il reste — on ne pose pas en douce autre chose que
-- ce qui a ete demande.
function Campement.Ajouter(actionId, minutes)
    local camp = Campement.courant
    if not (camp and camp.unites) then return false, "le MJ n'a pas encore donné les unités de temps." end
    minutes = math.floor(tonumber(minutes) or 0)
    local pose = camp.heures[actionId] or 0
    local reste = camp.unites - Campement.Reparties()
    if minutes > reste then
        return false, string.format("il ne reste que %s à répartir.", Campement.Duree(reste))
    end
    if pose + minutes < 0 then
        return false, string.format("il n'y a que %s sur cette action.", Campement.Duree(pose))
    end
    return Campement.Repartir(actionId, pose + minutes)
end

-- Une duree en minutes, lisible : « 45 min », « 4 h », « 1 h 20 ».
function Campement.Duree(minutes)
    minutes = math.floor(tonumber(minutes) or 0)
    local parHeure = Eq().minutesParHeure
    local h, m = math.floor(minutes / parHeure), minutes % parHeure
    if h == 0 then return string.format("%d min", m) end
    if m == 0 then return string.format("%d h", h) end
    return string.format("%d h %02d", h, m)
end

function Campement.Valider()
    local camp = Campement.courant
    if not (camp and Campement.Participe()) then return false, "tu ne participes pas à ce campement." end
    if not camp.unites then return false, "le MJ n'a pas encore donné les unités de temps." end
    local reparties = Campement.Reparties()
    if reparties ~= camp.unites then
        return false, string.format("%s / %s réparties : il faut tout placer.",
            Campement.Duree(reparties), Campement.Duree(camp.unites))
    end
    camp.pret = true
    camp.membres[Moi()].pret = true
    local paquet = { ok = 1, h = {} }
    for id, h in pairs(camp.heures) do paquet.h[id] = h end
    Envoyer("PRET", paquet)
    Prevenir()
    return true
end

local function SurPret(qui, d)
    if not Mien(qui, d) then return end
    local m = Campement.courant.membres[qui]
    if not m then return end
    m.pret = tonumber(d.ok) == 1
    m.heures = type(d.h) == "table" and d.h or nil
    Prevenir()
end

-- ===== Le risque d'embuscade (chez le MJ) ==================================
-- Les joueurs ne le voient pas : il se calcule sur le client du MJ, avec ce
-- que le campement lui apprend deja (heures de chacun, tente), et n'est envoye
-- a personne. Le niveau de danger est un choix du MJ, garde dans la seance.
--
-- Ecart voulu a la feuille (le MJ, 10 octobre 2026) : ni lieu, ni zone, ni
-- ecart de niveau — « le MJ dira juste de quel niveau de danger il s'agit ».

function Campement.Danger(id)
    for _, d in ipairs(Eq().embuscade.dangers) do
        if d.id == id then return d end
    end
    return nil
end

function Campement.ChoisirDanger(id)
    local camp = Campement.courant
    if not (camp and LCM.IsMaster()) then return false, "seul le maître du jeu règle le danger." end
    if not Campement.Danger(id) then return false, "niveau de danger inconnu." end
    camp.danger = id
    Prevenir()
    return true
end

-- Rend { risque (0 a 1), manques, garde }. Les heures de garde ne comptent
-- que pour ceux qui se sont dits prets : c'est la qu'elles voyagent.
function Campement.Embuscade()
    local camp = Campement.courant
    local e = Eq().embuscade
    local manques = {}
    if not camp then return { risque = 0, manques = manques, garde = 0 } end
    local danger = Campement.Danger(camp.danger)
    if not danger then manques[#manques + 1] = "niveau de danger non choisi (compté Normal)" end

    local campeurs = Campement.Participants()
    local garde = 0
    for _, nom in ipairs(campeurs) do
        local m = camp.membres[nom]
        local heures = nom == Moi() and camp.heures or m.heures
        garde = garde + (tonumber(heures and heures.garde) or 0)
    end
    local repos = math.min(e.heuresMax, math.max(0, (tonumber(camp.unites) or 0) / Eq().minutesParHeure))
    local x = -(danger and danger.valeur or 0)
        + e.parHeureRepos * repos
        - e.parCampeur * #campeurs
        - e.parSecurite * Campement.BonusCamp("securite")
        - e.parHeureGarde * garde / Eq().minutesParHeure
    -- Un danger qui FORCE le risque (« Aucun » : 0 %) remplace le calcul.
    if danger and danger.force then x = danger.force end
    x = math.min(1, math.max(0, x))
    local p = 10 ^ e.decimales
    -- ARRONDI.INF : 0,7299 reste 0,72. Le petit epsilon evite que 0,72 calcule
    -- en 0,71999999 tombe a 0,71.
    return { risque = math.floor(x * p + 1e-9) / p, manques = manques, garde = garde }
end

-- Le jet d'embuscade, quand la nuit passe, sur le client du MJ seul : un d100
-- inferieur ou egal au risque, et le camp est attaque. Le resultat reste chez
-- le MJ — c'est a lui de jouer la suite.
function Campement.TirerEmbuscade()
    local camp = Campement.courant
    if not (camp and LCM.IsMaster()) then return nil end
    local e = Eq().embuscade
    local seuil = math.floor(Campement.Embuscade().risque * 100 + 0.5)
    local jet = LCM.Roll.Des(1, e.de)
    camp.embuscade = { jet = jet, seuil = seuil, attaque = jet <= seuil }
    if camp.embuscade.attaque then
        Refuser(string.format("EMBUSCADE : %d sur %d, sous le risque de %d %%.", jet, e.de, seuil))
    else
        Dire(string.format("pas d'embuscade : %d sur %d, au-dessus du risque de %d %%.", jet, e.de, seuil))
    end
    return camp.embuscade
end

-- Ceux qui ont accepte et ne sont pas prets. Une invitation restee sans
-- reponse ne bloque pas : quelqu'un sans l'addon ne repondra jamais.
function Campement.EnAttente()
    local out = {}
    for _, nom in ipairs(Campement.Participants()) do
        if not Campement.courant.membres[nom].pret then out[#out + 1] = nom end
    end
    return out
end

local function Encaisser(camp, campeurs)
    local resultat = Campement.Calculer(Perso(), camp.heures, Campement.Tente(), campeurs, camp.accessoires)
    local jauge = LCM.Entities.Gauge(Perso(), "fatigue")
    if jauge and resultat.fatigue ~= 0 then
        local avant = jauge.current
        LCM.Entities.SetGauge(Perso(), "fatigue", math.max(0, math.min(jauge.max, avant + resultat.fatigue)))
        local apres = LCM.Entities.Gauge(Perso(), "fatigue").current
        resultat.fatigueRendue = apres - avant
    else
        resultat.fatigueRendue = 0
    end
    camp.psDisponibles = resultat.ps
    camp.resultat = resultat
    camp.etape = "soins"
    Dire(string.format("la nuit est passée : %+d fatigue, %d PS à distribuer.", resultat.fatigueRendue, resultat.ps))
    for _, m in ipairs(resultat.manques) do Refuser("campement : " .. m .. ".") end
end

function Campement.Conclure()
    local camp = Campement.courant
    if not (camp and camp.role == "chef") then return false, "seul le responsable du campement valide la nuit." end
    if camp.etape ~= "preparation" then return false, "la nuit est déjà passée." end
    if not camp.unites then return false, "le MJ n'a pas encore donné les unités de temps." end
    local attente = Campement.EnAttente()
    if #attente > 0 then return false, "pas encore prêts : " .. table.concat(attente, ", ") end
    local campeurs = #Campement.Participants()
    local debut = ((GetServerTime and GetServerTime()) or time()) + 2
    local graine = math.random(1, 2147483646)
    local votants = LCM.Combat.Membres()
    votants[#votants + 1] = Moi()
    Envoyer("FIN", { n = campeurs, nuit = 1, debut = debut, graine = graine, votants = votants })
    if LCM.UI and LCM.UI.NuitCampement then
        LCM.UI.NuitCampement.Lancer(camp.id, graine, debut, votants)
    end
    -- Un MJ responsable du camp tire lui-meme l'embuscade, avant que les heures
    -- de la nuit ne s'effacent.
    if LCM.IsMaster() then Campement.TirerEmbuscade() end
    Encaisser(camp, campeurs)
    Prevenir()
    return true
end

local function SurFin(qui, d)
    -- La transition concerne tout le groupe, meme ceux qui ne dorment pas
    -- sous cette tente. Le calcul de recuperation reste reserve aux campeurs.
    local courant = Campement.courant
    if tonumber(d.nuit) == 1 and LCM.Reseau.DansLeGroupe(qui)
        and (not courant or courant.id ~= d.c or qui == courant.chef)
        and LCM.UI and LCM.UI.NuitCampement then
        LCM.UI.NuitCampement.Lancer(d.c, tonumber(d.graine), tonumber(d.debut), d.votants)
    end
    if not Mien(qui, d) then return end
    local camp = Campement.courant
    if qui ~= camp.chef then return end
    if camp.etape ~= "preparation" then return end
    if camp.role == "mj" then
        camp.etape = "soins"
        Campement.TirerEmbuscade()
    elseif Campement.Participe() and camp.pret then
        Encaisser(camp, tonumber(d.n) or #Campement.Participants())
    else
        -- Invite qui n'a pas repondu, ou participant pas pret : la nuit s'est
        -- faite sans lui.
        Campement.courant = nil
    end
    Prevenir()
end

-- ===== Les PS ==============================================================
-- Celui qui a soigne recoit des PS et choisit a qui les donner. Le receveur
-- les applique ; ce qu'il ne peut pas utiliser revient au soigneur, qui peut
-- le redonner a quelqu'un d'autre. Les PS ne sortent jamais du campement.

function Campement.PSRecus()
    local camp = Campement.courant
    local total = 0
    for _, n in pairs(camp and camp.psRecus or {}) do total = total + n end
    return total
end

local function Recevoir(qui, n)
    local camp = Campement.courant
    camp.psRecus[qui] = (camp.psRecus[qui] or 0) + n
    Dire(string.format("%s te confie %d PS.", qui, n))
end

function Campement.DonnerPS(qui, n)
    local camp = Campement.courant
    if not (camp and camp.etape == "soins") then return false, "la nuit n'est pas encore passée." end
    n = math.floor(tonumber(n) or 0)
    if n < 1 then return false, "indique un nombre de PS." end
    if n > camp.psDisponibles then
        return false, string.format("tu n'as que %d PS à donner.", camp.psDisponibles)
    end
    if not camp.membres[qui] or camp.membres[qui].statut ~= "oui" then
        return false, "on ne soigne que ceux qui campent."
    end
    camp.psDisponibles = camp.psDisponibles - n
    if qui == Moi() then Recevoir(qui, n) else Chuchoter("PS", qui, { n = n }) end
    Prevenir()
    return true
end

local function SurPS(qui, d)
    if not Mien(qui, d) or Campement.courant.etape ~= "soins" then return end
    Recevoir(qui, math.max(0, math.floor(tonumber(d.n) or 0)))
    Prevenir()
end

-- Prend `n` PS dans ce qu'on a recu, soigneur par soigneur.
local function Puiser(n)
    local camp = Campement.courant
    local noms = {}
    for nom in pairs(camp.psRecus) do noms[#noms + 1] = nom end
    table.sort(noms)
    for _, nom in ipairs(noms) do
        local pris = math.min(n, camp.psRecus[nom])
        camp.psRecus[nom] = camp.psRecus[nom] - pris
        if camp.psRecus[nom] == 0 then camp.psRecus[nom] = nil end
        n = n - pris
        if n == 0 then return end
    end
end

-- 1 PS = 1 PV, sur la zone choisie. Soigner plus que la blessure est refuse :
-- le surplus doit pouvoir repartir chez le soigneur.
function Campement.Soigner(partieId, n)
    local camp = Campement.courant
    if not (camp and camp.etape == "soins") then return false, "aucun soin en cours." end
    n = math.floor(tonumber(n) or 0)
    if n < 1 then return false, "indique un nombre de PS." end
    if n > Campement.PSRecus() then return false, string.format("tu n'as reçu que %d PS.", Campement.PSRecus()) end
    local partie
    for _, p in ipairs(LCM.Body.State(Perso())) do
        if p.id == partieId then partie = p end
    end
    if not partie then return false, "zone inconnue." end
    local manque = partie.max - partie.current
    if n > manque then
        return false, string.format("%s ne manque que de %d PV.", partie.label, manque)
    end
    LCM.Body.SetCurrent(Perso(), partieId, partie.current + n)
    Puiser(n)
    Prevenir()
    return true
end

-- Les etats et maladies : on les retire avec des PS, a raison de
-- `psParPointNegatif` par point NEGATIF qu'ils portent. Un etat sans jeu
-- d'equilibrage n'a pas de prix : c'est au MJ de le retirer. Les etats
-- intangibles ne se soignent pas au camp.
local SOIGNABLES = { etat = true, maladie = true }

-- Ce qu'un etat RETIRE, en points — ce que la forge affiche au bout de ses
-- lignes passees sous leur base. Le bilan le tient deja sous le nom de
-- `credit` : c'est ce que ces lignes rendent au pool, donc la somme exacte de
-- ce qui s'y lit en negatif. Nil quand l'entree n'a pas de jeu.
function Campement.PointsNegatifs(element)
    if type(element) ~= "table" then return nil end
    local jeu, rarete = LCM.Forge.Lire(element.forge)
    if not (jeu and rarete) then return nil end
    local bilan = LCM.Forge.Bilan(jeu, rarete.id, element.bonus, 1, nil, element.ic, element.pourcent)
    return bilan.credit
end

-- Le prix d'un etat, en PS (le MJ, 24 octobre 2026 : « le nombre de pts
-- negatifs egale le cout en PS »). Il se lisait avant sur le pool de sa
-- RARETE : deux etats de meme rarete coutaient alors pareil, qu'ils retirent
-- un point ou trente.
--
-- Zero est une reponse : un etat qui ne retire rien ne coute rien a lever. On
-- arrondit au-dessus, pour qu'un demi-point de malus se paie un PS.
function Campement.CoutEtat(element)
    if type(element) ~= "table" then return nil, "état inconnu." end
    local points = Campement.PointsNegatifs(element)
    if not points then
        return nil, string.format("« %s » n'a pas de jeu d'équilibrage : le MJ doit le retirer.", element.label)
    end
    return math.ceil(points * (tonumber(Eq().vitalite.psParPointNegatif) or 1))
end

-- Ce que porte le personnage et qu'un campement peut retirer, avec son prix.
function Campement.EtatsSoignables(entity)
    local out = {}
    for _, categorie in ipairs(LCM.Etats.CATEGORIES or {}) do
        if SOIGNABLES[categorie.id] then
            for _, id in ipairs(LCM.Etats.Ids(entity, categorie.id)) do
                local element = LCM.Etats.Get(id)
                if element then
                    local cout, raison = Campement.CoutEtat(element)
                    out[#out + 1] = { element = element, cout = cout, raison = raison }
                end
            end
        end
    end
    return out
end

function Campement.RetirerEtat(etatId)
    local camp = Campement.courant
    if not (camp and camp.etape == "soins") then return false, "aucun soin en cours." end
    local cible
    for _, e in ipairs(Campement.EtatsSoignables(Perso())) do
        if e.element.id == etatId then cible = e end
    end
    if not cible then return false, "tu ne portes pas cet état." end
    if not cible.cout then return false, cible.raison end
    if cible.cout > Campement.PSRecus() then
        return false, string.format("« %s » coûte %d PS, tu en as reçu %d.", cible.element.label, cible.cout,
            Campement.PSRecus())
    end
    LCM.Etats.Enlever(Perso(), etatId)
    Puiser(cible.cout)
    if LCM.Entities.Changed then LCM.Entities.Changed(Perso(), "etats") end
    Dire(string.format("« %s » est retiré (%d PS).", cible.element.label, cible.cout))
    Prevenir()
    return true
end

-- Rend a chaque soigneur ce qu'on n'a pas utilise de ses PS.
function Campement.RendrePS()
    local camp = Campement.courant
    if not camp then return false end
    for nom, n in pairs(camp.psRecus) do
        if nom == Moi() then camp.psDisponibles = camp.psDisponibles + n
        else Chuchoter("PS_RETOUR", nom, { n = n }) end
    end
    camp.psRecus = {}
    Prevenir()
    return true
end

local function SurRetour(qui, d)
    if not Mien(qui, d) then return end
    local camp = Campement.courant
    local n = math.max(0, math.floor(tonumber(d.n) or 0))
    camp.psDisponibles = camp.psDisponibles + n
    Dire(string.format("%s te rend %d PS.", qui, n))
    Prevenir()
end

-- Quitter : ce qu'on a recu et pas utilise repart d'abord chez son soigneur.
-- Le responsable qui quitte avant la nuit annule le campement pour tous.
function Campement.Quitter()
    local camp = Campement.courant
    if not camp then return false end
    if camp.etape == "soins" then Campement.RendrePS() end
    if camp.role == "chef" and camp.etape == "preparation" then Envoyer("ANNULE", {})
    elseif camp.etape == "preparation" and camp.role ~= "mj" then Envoyer("REPONSE", { ok = 0 }) end
    Campement.courant = nil
    Prevenir()
    return true
end

local function SurAnnule(qui, d)
    if not Mien(qui, d) or qui ~= Campement.courant.chef then return end
    Campement.courant = nil
    Dire(string.format("%s a levé le campement.", qui))
    Prevenir()
end

if LCM.Reseau then
    LCM.Reseau.Ecouter("CAMP_INVITE", SurInvite)
    LCM.Reseau.Ecouter("CAMP_REPONSE", SurReponse)
    LCM.Reseau.Ecouter("CAMP_UNITES", SurUnites)
    LCM.Reseau.Ecouter("CAMP_PRET", SurPret)
    LCM.Reseau.Ecouter("CAMP_FIN", SurFin)
    LCM.Reseau.Ecouter("CAMP_PS", SurPS)
    LCM.Reseau.Ecouter("CAMP_PS_RETOUR", SurRetour)
    LCM.Reseau.Ecouter("CAMP_ANNULE", SurAnnule)
end
