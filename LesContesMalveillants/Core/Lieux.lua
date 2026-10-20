-- Les Lieux : donner un nom aux endroits, et le dire quand on y entre.
--
-- Un LIEU est un nom (« Les Marches Grises »). Il porte un ou plusieurs
-- SEUILS, et c'est le seuil qu'on franchit. Franchir un seuil affiche une
-- banniere : le nom du lieu, et celui du seuil (« Porte du Nord »).
--
-- Repris du module Zone Gate d'Omega Hub (Akriaxx), dont l'idee est juste :
-- marquer le territoire a la main, sur place, plutot que d'attendre que le
-- serveur declare une aire. Trois differences assumees :
--
--   * UNE PORTE SE POSE AVEC DEUX BORNES, pas avec l'orientation du
--     personnage. Zone Gate capture `GetPlayerFacing` et deduit la normale de
--     la porte ; nous posons la borne A, on marche, on pose la borne B. C'est
--     une marche de plus et deux soucis de moins : la porte a une LARGEUR
--     reelle (celle du passage) au lieu d'un nombre a deviner, et on ne depend
--     plus de l'ordre dans lequel le client rend ses axes — `UnitPosition`
--     rend y AVANT x, et une normale calculee sur des axes inverses se
--     retourne sans prevenir ;
--   * LA POSITION PASSE PAR LE DEPLACEMENT FORCE
--     (`LCM.DeplacementForce.Position`). Zone Gate appelle `UnitPosition`
--     directement — ce qui ne repond PAS sur une carte d'instance, et nos
--     cartes de campagne en sont. Il y a trois sources (le monde, la carte,
--     `.gps`) et elles ne comptent pas dans la meme unite : un seuil retient
--     donc CELLE qui l'a capture, et ne se mesure qu'avec elle. Melanger des
--     yards du monde et des yards de carte ferait franchir une porte sans
--     bouger ;
--   * LE NOM SE DECOUVRE EN ENTRANT, par defaut. Zone Gate masque tout
--     jusqu'a ce que l'auteur debloque le nom joueur par joueur. C'est utile
--     pour un secret, pas pour une region ordinaire — on entre dans les
--     Marches Grises et la banniere le dit. Le MJ coupe la decouverte
--     automatique sur les lieux qu'il veut tenir caches, et les revele a la
--     main.
--
-- Ce fichier vit dans l'addon PRINCIPAL : c'est le JOUEUR qui franchit et qui
-- voit la banniere. L'edition, elle, n'est permise qu'au MJ, et son atelier
-- est dans le compagnon (LesContesMalveillants_MJ/Lieux.lua).
--
-- Les messages :
--   lieu    MJ -> groupe   un lieu entier (ses seuils compris)
--   lieu-   MJ -> groupe   { id }            retirer
--   lieu+   MJ -> joueur   { l, s }          revele un nom
--   lieux?  joueur -> groupe                 « renvoyez-moi tout »

local _, LCM = ...

local Lieux = {}
LCM.Lieux = Lieux

-- Un battement tous les quarts de seconde : assez fin pour qu'une porte se
-- declenche au pas ou on la franchit, assez large pour ne rien couter.
local INTERVALLE = 0.25
-- La bande morte autour d'une frontiere, en yards. Sans elle, se tenir pile
-- sur le seuil ferait clignoter la banniere a chaque echantillon.
local MARGE = 1.5
-- Ce qu'on tolere au-dela des bornes d'une porte : on ne passe jamais
-- exactement entre les deux piquets.
local DEBORD = 4
local RAYON = 12
-- De quoi dessiner un contour detaille sans crever le budget reseau.
local POINTS_MAX = 20
local NOM_MAX, MESSAGE_MAX = 40, 160

Lieux.FORMES = { porte = "Porte", cercle = "Cercle", region = "Région" }
Lieux.ORDRE_FORMES = { "porte", "cercle", "region" }
Lieux.SENS = { entree = "Entrée", retour = "Retour" }

-- ===== Sauvegarde ==========================================================
-- Les lieux sont du CONTENU PARTAGE : le meme monde pour tous les personnages
-- du compte, donc LCM_DB. Ce qu'on a DECOUVERT, en revanche, appartient au
-- personnage : un deuxieme personnage ne connait pas les endroits du premier.

local function Magasin()
    LCM.EnsureDatabase()
    if type(LCM.db.lieux) ~= "table" then LCM.db.lieux = {} end
    return LCM.db.lieux
end

local function Connus()
    LCM.EnsureDatabase()
    local c = LCM.charDb
    if type(c.lieux) ~= "table" then c.lieux = {} end
    if type(c.lieux.lieux) ~= "table" then c.lieux.lieux = {} end
    if type(c.lieux.seuils) ~= "table" then c.lieux.seuils = {} end
    return c.lieux
end

local function Moi() return LCM.PlayerId() end

local function Texte(valeur, maximum)
    local t = tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if maximum and #t > maximum then t = t:sub(1, maximum) end
    return t
end

local function Identifiant(prefixe)
    return string.format("%s%d_%04d", prefixe, (time and time()) or 0, math.random(0, 9999))
end

local function Prevenir()
    -- Toute modification locale passe par ici : c'est donc ici qu'on remet
    -- l'horloge en marche (ou qu'on l'arrete). Reglee seulement au chargement
    -- et a la reception, elle laissait une porte toute fraiche inerte jusqu'au
    -- prochain /reload — chez son auteur, et chez lui seul.
    if Lieux.Regler then Lieux.Regler() end
    if Lieux.onChange then Lieux.onChange() end
end

-- ===== Lecture =============================================================

function Lieux.Get(id)
    if not id then return nil end
    return Magasin()[tostring(id)]
end

-- Les lieux dans l'ordre alphabetique : le MJ en aura trente, et l'ordre de
-- creation ne lui dira rien.
function Lieux.Liste()
    local out = {}
    for _, lieu in pairs(Magasin()) do out[#out + 1] = lieu end
    table.sort(out, function(a, b)
        local na, nb = tostring(a.nom or ""):lower(), tostring(b.nom or ""):lower()
        if na ~= nb then return na < nb end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

-- Les seuils d'un lieu, dans l'ordre alphabetique eux aussi.
function Lieux.Seuils(lieuId)
    local lieu = Lieux.Get(lieuId)
    local out = {}
    if not lieu then return out end
    for _, seuil in pairs(lieu.seuils or {}) do out[#out + 1] = seuil end
    table.sort(out, function(a, b)
        local na, nb = tostring(a.nom or ""):lower(), tostring(b.nom or ""):lower()
        if na ~= nb then return na < nb end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

-- Rend le seuil ET son lieu : presque tout ce qui suit a besoin des deux.
function Lieux.Seuil(id)
    if not id then return nil end
    id = tostring(id)
    for _, lieu in pairs(Magasin()) do
        local seuil = (lieu.seuils or {})[id]
        if seuil then return seuil, lieu end
    end
    return nil
end

function Lieux.Compte()
    local lieux, seuils = 0, 0
    for _, lieu in pairs(Magasin()) do
        lieux = lieux + 1
        for _ in pairs(lieu.seuils or {}) do seuils = seuils + 1 end
    end
    return lieux, seuils
end

-- A moi d'en decider ? Un lieu recu d'ailleurs se lit, il ne se modifie pas :
-- le modifier ici ne changerait rien chez son auteur, et la prochaine
-- diffusion ecraserait la retouche. Mieux vaut un refus franc.
function Lieux.AMoi(lieu)
    return lieu ~= nil and lieu.auteur == Moi()
end

local function Mien(id)
    local lieu = Lieux.Get(id)
    if not lieu then return nil, "lieu introuvable." end
    if not Lieux.AMoi(lieu) then return nil, "ce lieu est à " .. tostring(lieu.auteur) .. "." end
    return lieu
end

local function MienSeuil(id)
    local seuil, lieu = Lieux.Seuil(id)
    if not seuil then return nil, nil, "seuil introuvable." end
    if not Lieux.AMoi(lieu) then return nil, nil, "ce lieu est à " .. tostring(lieu.auteur) .. "." end
    return seuil, lieu
end

-- ===== Ou se tient le personnage ===========================================

local function Carte()
    local D = LCM.DeplacementForce
    return D and D.Carte and D.Carte() or nil
end

-- Rend x, y, source — ou nil. `source` impose celle d'un seuil deja pose.
local function Position(source)
    local D = LCM.DeplacementForce
    if not (D and D.Position) then return nil end
    local x, y, _, trouvee = D.Position(source)
    if not x and source == "gps" then x, y, _, trouvee = D.Position("monde") end
    if not x then return nil end
    return x, y, trouvee
end

-- ===== Creation et edition (MJ) ============================================

function Lieux.Creer(nom)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local lieu = {
        id = Identifiant("l_"),
        nom = Texte(nom, NOM_MAX),
        auteur = Moi(),
        -- Par defaut on apprend le nom en entrant : c'est le cas courant. Un
        -- secret se decoche (voir Decouverte).
        decouverte = true,
        seuils = {},
    }
    if lieu.nom == "" then lieu.nom = "Lieu sans nom" end
    Magasin()[lieu.id] = lieu
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return lieu
end

function Lieux.Renommer(id, nom)
    local lieu, raison = Mien(id)
    if not lieu then return false, raison end
    nom = Texte(nom, NOM_MAX)
    if nom == "" then return false, "il faut un nom." end
    lieu.nom = nom
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Couleur(id, hexa)
    local lieu, raison = Mien(id)
    if not lieu then return false, raison end
    hexa = Texte(hexa):upper():gsub("^#", "")
    if hexa == "" then
        lieu.couleur = nil
    elseif hexa:match("^%x%x%x%x%x%x$") then
        lieu.couleur = hexa
    else
        return false, "une couleur s'écrit en six chiffres hexadécimaux (RRVVBB)."
    end
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- La decouverte automatique : le nom s'apprend en franchissant. Coupee, le
-- lieu reste « Lieu inconnu » jusqu'a ce que le MJ le revele.
function Lieux.Decouverte(id, actif)
    local lieu, raison = Mien(id)
    if not lieu then return false, raison end
    lieu.decouverte = actif and true or false
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Retirer(id)
    local lieu, raison = Mien(id)
    if not lieu then return false, raison end
    for seuilId in pairs(lieu.seuils or {}) do Lieux.etats[seuilId] = nil end
    Magasin()[lieu.id] = nil
    Lieux.AnnoncerRetrait(lieu.id)
    Prevenir()
    return true
end

-- Un seuil nait TOUJOURS ici, a l'endroit ou se tient le MJ : c'est tout
-- l'interet d'aller le poser sur place.
function Lieux.CreerSeuil(lieuId, nom, forme)
    local lieu, raison = Mien(lieuId)
    if not lieu then return nil, raison end

    local x, y, source = Position()
    if not x then
        return nil, "position indisponible ici : essaie « /lcm gps », ou vérifie le correctif de carte."
    end
    local carte = Carte()

    forme = Lieux.FORMES[forme] and forme or "porte"
    nom = Texte(nom, NOM_MAX)
    if nom == "" then
        local n = 0
        for _ in pairs(lieu.seuils) do n = n + 1 end
        nom = "Seuil " .. (n + 1)
    end

    local seuil = {
        id = Identifiant("s_"),
        lieu = lieu.id,
        nom = nom,
        actif = true,
        forme = forme,
        carte = carte,
        source = source,
        -- La porte : borne A posee, borne B a poser (voir PoserBorne). Tant
        -- qu'elle manque, le seuil est incomplet et inerte — on ne devine pas
        -- la largeur d'un passage.
        ax = x, ay = y, bx = nil, by = nil, debord = DEBORD,
        -- Le cercle : centre ici, rayon par defaut.
        x = x, y = y, rayon = RAYON,
        -- La region : le premier point, c'est ici.
        points = { { x = x, y = y } }, ferme = false,
        sens = 1,
        entree = true, retour = true,
        message = "",
        -- Le theme de banniere. Vide : celui du lieu, et a defaut le theme
        -- d'origine (Core/Bannieres.lua, Resoudre).
        theme = nil,
    }
    lieu.seuils[seuil.id] = seuil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return seuil
end

function Lieux.RetirerSeuil(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    lieu.seuils[seuil.id] = nil
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.RenommerSeuil(id, nom)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    nom = Texte(nom, NOM_MAX)
    if nom == "" then return false, "il faut un nom." end
    seuil.nom = nom
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Forme(id, forme)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if not Lieux.FORMES[forme] then return false, "forme inconnue." end
    if forme == "region" and seuil.forme ~= "region" then
        -- Une region qui commence part du point deja capture, comme a la
        -- creation : « ici » reste le point de depart.
        seuil.points = { { x = seuil.x or seuil.ax, y = seuil.y or seuil.ay } }
        seuil.ferme = false
    end
    seuil.forme = forme
    -- La geometrie change : on rearme la detection, sinon le premier battement
    -- lirait un cote calcule avec l'ancienne forme et declencherait a vide.
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- Deplace le seuil ici : borne A pour une porte, centre pour un cercle. Pour
-- une region, les points se gerent un par un (AjouterPoint).
function Lieux.Recapturer(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    local x, y, source = Position()
    if not x then return false, "position indisponible ici." end
    seuil.carte, seuil.source = Carte(), source
    if seuil.forme == "porte" then
        seuil.ax, seuil.ay = x, y
    else
        seuil.x, seuil.y = x, y
    end
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- La seconde borne d'une porte. C'est elle qui donne sa largeur au passage.
function Lieux.PoserBorne(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if seuil.forme ~= "porte" then return false, "seule une porte a des bornes." end
    local x, y, source = Position()
    if not x then return false, "position indisponible ici." end
    if source ~= seuil.source then
        return false, "la première borne a été posée avec une autre source de position ("
            .. tostring(seuil.source) .. ") : repose la porte entièrement."
    end
    if seuil.carte ~= Carte() then
        return false, "les deux bornes d'une porte doivent être sur la même carte."
    end
    local dx, dy = x - (seuil.ax or 0), y - (seuil.ay or 0)
    if math.sqrt(dx * dx + dy * dy) < MARGE then
        return false, "les deux bornes sont au même endroit : éloigne-toi un peu."
    end
    seuil.bx, seuil.by = x, y
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- Quel cote compte comme « dedans ». Une porte posee de gauche a droite ou de
-- droite a gauche n'a pas le meme avant : plutot que de faire deviner le MJ,
-- on lui donne un bouton.
function Lieux.Inverser(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    seuil.sens = (seuil.sens == -1) and 1 or -1
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Rayon(id, rayon)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    rayon = tonumber(rayon)
    if not rayon or rayon <= 0 then return false, "un rayon se compte en mètres, au-dessus de 0." end
    seuil.rayon = math.min(500, rayon)
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Debord(id, debord)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    debord = tonumber(debord)
    if not debord or debord < 0 then return false, "le débord se compte en mètres, à partir de 0." end
    seuil.debord = math.min(200, debord)
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Activer(id, actif)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    seuil.actif = actif and true or false
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Sens(id, sens, actif)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if sens ~= "entree" and sens ~= "retour" then return false, "sens inconnu." end
    seuil[sens] = actif and true or false
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Message(id, texte)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    seuil.message = Texte(texte, MESSAGE_MAX)
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- Le theme de banniere, sur le lieu ou sur un seuil en particulier. Vide :
-- on herite (le seuil du lieu, le lieu du theme d'origine).
function Lieux.ThemeDuLieu(id, themeId)
    local lieu, raison = Mien(id)
    if not lieu then return false, raison end
    themeId = Texte(themeId)
    lieu.theme = (themeId ~= "" and themeId) or nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.ThemeDuSeuil(id, themeId)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    themeId = Texte(themeId)
    seuil.theme = (themeId ~= "" and themeId) or nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- ===== La region, point par point ==========================================

local function RecentrerRegion(seuil)
    local points = seuil.points or {}
    if #points == 0 then return end
    local sx, sy = 0, 0
    for _, p in ipairs(points) do sx, sy = sx + p.x, sy + p.y end
    seuil.x, seuil.y = sx / #points, sy / #points
end

function Lieux.AjouterPoint(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if seuil.forme ~= "region" then return false, "seule une région a des points." end
    local x, y, source = Position()
    if not x then return false, "position indisponible ici." end

    seuil.points = seuil.points or {}
    if #seuil.points == 0 then
        seuil.carte, seuil.source = Carte(), source
    elseif source ~= seuil.source then
        return false, "cette région a été commencée avec une autre source de position ("
            .. tostring(seuil.source) .. ")."
    elseif seuil.carte ~= Carte() then
        return false, "une région ne peut pas enjamber un changement de carte."
    elseif #seuil.points >= POINTS_MAX then
        return false, string.format("une région tient en %d points au maximum.", POINTS_MAX)
    end

    seuil.points[#seuil.points + 1] = { x = x, y = y }
    RecentrerRegion(seuil)
    -- Tout point ajoute rouvre le contour : on le revalide ensuite.
    seuil.ferme = false
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.RetirerPoint(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if seuil.forme ~= "region" then return false, "seule une région a des points." end
    if not seuil.points or #seuil.points == 0 then return false, "il n'y a plus de point." end
    table.remove(seuil.points)
    RecentrerRegion(seuil)
    seuil.ferme = false
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.ViderPoints(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if seuil.forme ~= "region" then return false, "seule une région a des points." end
    seuil.points, seuil.ferme = {}, false
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- Fermer la region, c'est juste lever ce drapeau : le dernier point est
-- TOUJOURS relie au premier, il n'y a rien de plus a stocker.
function Lieux.Fermer(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if seuil.forme ~= "region" then return false, "seule une région se ferme." end
    if not seuil.points or #seuil.points < 3 then
        return false, "il faut au moins trois points pour fermer une région."
    end
    seuil.ferme = true
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

function Lieux.Rouvrir(id)
    local seuil, lieu, raison = MienSeuil(id)
    if not seuil then return false, raison end
    if seuil.forme ~= "region" then return false, "seule une région se rouvre." end
    seuil.ferme = false
    Lieux.etats[seuil.id] = nil
    Lieux.Diffuser(lieu.id)
    Prevenir()
    return true
end

-- ===== Geometrie ===========================================================

-- Un seuil incomplet est INERTE, et dit ce qui lui manque : une porte sans sa
-- seconde borne n'a pas de largeur, une region ouverte n'a pas de dedans.
function Lieux.Complet(seuil)
    if not seuil then return false, "seuil introuvable." end
    if seuil.forme == "porte" then
        if not (seuil.ax and seuil.bx) then return false, "il manque la seconde borne." end
        return true
    end
    if seuil.forme == "cercle" then
        if not (seuil.x and (tonumber(seuil.rayon) or 0) > 0) then return false, "il manque un rayon." end
        return true
    end
    if seuil.forme == "region" then
        local n = seuil.points and #seuil.points or 0
        if n < 3 then return false, string.format("il manque des points (%d sur 3).", n) end
        if not seuil.ferme then return false, "la région n'est pas fermée." end
        return true
    end
    return false, "forme inconnue."
end

-- Distance d'un point au segment [a,b], projection ramenee sur le segment.
local function DistanceAuSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local carre = dx * dx + dy * dy
    if carre == 0 then return math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2) end
    local t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / carre))
    local cx, cy = ax + t * dx, ay + t * dy
    return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

-- Dedans ou dehors, par comptage d'intersections. Le dernier point est
-- toujours relie au premier : pas besoin de dupliquer le depart en fin de
-- liste.
local function DansLePolygone(points, px, py)
    local dedans, n = false, #points
    local j = n
    for i = 1, n do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y
        if ((yi > py) ~= (yj > py))
            and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            dedans = not dedans
        end
        j = i
    end
    return dedans
end

local function DistanceAuContour(points, px, py)
    local n, mini = #points, math.huge
    local j = n
    for i = 1, n do
        local d = DistanceAuSegment(px, py, points[j].x, points[j].y, points[i].x, points[i].y)
        if d < mini then mini = d end
        j = i
    end
    return mini
end

-- De quel cote du seuil on se tient : 1 (dedans / devant), -1 (dehors /
-- derriere), ou nil — ni l'un ni l'autre, parce qu'on est hors de portee ou
-- dans la bande morte. `nil` rearme la detection, il n'annonce rien.
function Lieux.Cote(seuil, px, py)
    if not Lieux.Complet(seuil) then return nil end
    local sens = (seuil.sens == -1) and -1 or 1

    if seuil.forme == "cercle" then
        local rayon = tonumber(seuil.rayon) or RAYON
        local d = math.sqrt((px - seuil.x) ^ 2 + (py - seuil.y) ^ 2)
        if d <= rayon - MARGE then return sens end
        if d >= rayon + MARGE then return -sens end
        return nil
    end

    if seuil.forme == "region" then
        if DistanceAuContour(seuil.points, px, py) < MARGE then return nil end
        return DansLePolygone(seuil.points, px, py) and sens or -sens
    end

    -- La porte. Hors de l'emprise du passage (le segment, plus le debord), on
    -- ne regarde meme pas de quel cote on est : contourner la porte, ce n'est
    -- pas la franchir.
    local ax, ay, bx, by = seuil.ax, seuil.ay, seuil.bx, seuil.by
    local dx, dy = bx - ax, by - ay
    local longueur = math.sqrt(dx * dx + dy * dy)
    if longueur == 0 then return nil end
    local le, lo = dx / longueur, dy / longueur
    local ex, ey = px - ax, py - ay
    local lelong = ex * le + ey * lo
    local debord = tonumber(seuil.debord) or DEBORD
    if lelong < -debord or lelong > longueur + debord then return nil end
    -- Le cote, par le produit vectoriel : positif a gauche de A -> B.
    local travers = ex * (-lo) + ey * le
    if math.abs(travers) < MARGE then return nil end
    return (travers > 0) and sens or -sens
end

-- Pour l'atelier du MJ : ou se tient le MJ par rapport a ce seuil, sans
-- toucher a la detection. Rend portee (bool), cote (« dedans »/« dehors »),
-- ou nil si la carte ou la source ne correspondent pas.
function Lieux.Etat(seuil)
    if not seuil then return nil end
    local x, y = Position(seuil.source)
    if not x then return nil end
    if seuil.carte ~= Carte() then return nil end
    local cote = Lieux.Cote(seuil, x, y)
    if cote == nil then return false, nil end
    return true, (cote == 1) and "dedans" or "dehors"
end

-- La distance jusqu'au seuil, pour que l'atelier puisse dire « 32 m ». nil si
-- la mesure n'a pas de sens ici.
function Lieux.Distance(seuil)
    if not seuil then return nil end
    local x, y = Position(seuil.source)
    if not x or seuil.carte ~= Carte() then return nil end
    if seuil.forme == "porte" then
        if not (seuil.ax and seuil.bx) then return nil end
        return DistanceAuSegment(x, y, seuil.ax, seuil.ay, seuil.bx, seuil.by)
    end
    if seuil.forme == "region" then
        if not seuil.points or #seuil.points < 2 then return nil end
        return DistanceAuContour(seuil.points, x, y)
    end
    if not seuil.x then return nil end
    local d = math.sqrt((x - seuil.x) ^ 2 + (y - seuil.y) ^ 2)
    return math.abs(d - (tonumber(seuil.rayon) or RAYON))
end

-- ===== La boussole =========================================================
-- Ou est le nord, dans les coordonnees d'une source donnee.
--
-- Rien n'en avait eu besoin jusqu'au radar de l'atelier : une distance est la
-- meme quel que soit le sens des axes. Une carte, non — et les trois sources
-- ne nomment pas leurs axes pareil :
--
--   « monde » : `UnitPosition` rend worldY PUIS worldX, et
--     Core/DeplacementForce les nomme x, y dans cet ordre — notre x est donc
--     worldY. Dans le monde, worldX croit vers le SUD et worldY vers l'OUEST.
--   « gps » : la commande repond « X: … Y: … » dans l'ordre du monde, et
--     `LireGPS` les garde ainsi : notre x est ici worldX. Les deux axes sont
--     ECHANGES par rapport a « monde ».
--   « carte » : une fraction du rectangle de carte comptee depuis le coin
--     HAUT-GAUCHE : x vers l'est, y vers le sud.
--
-- Ces trois lignes sont DEDUITES, et une deduction se trompe en silence : un
-- radar en miroir se lit tres bien, et on ne s'en apercoit qu'en posant une
-- porte a l'envers. Elles ne servent donc que de DERNIER RECOURS. Le vrai
-- chemin est la mesure, juste en dessous.
Lieux.CONVENTION = {
    monde = { droite = { -1, 0 }, haut = { 0, -1 } },
    gps   = { droite = { 0, -1 }, haut = { -1, 0 } },
    carte = { droite = { 1, 0 },  haut = { 0, -1 } },
}

-- Ramene un angle dans ]-pi, pi]. Elle vivait plus bas, avec le cap ; le nord
-- par la marche en a besoin aussi, et une seconde copie aurait derive.
local DEUXPI = math.pi * 2
local function RamenerAngle(a)
    a = a % DEUXPI
    if a > math.pi then a = a - DEUXPI end
    return a
end

local function Normaliser(x, y)
    local n = math.sqrt(x * x + y * y)
    if n < 1e-9 then return nil end
    return { x / n, y / n }
end

-- Resout la boussole a partir de DEUX deplacements non paralleles, chacun vu
-- dans la source (`s`) et sur la carte (`m`). Rend droite (l'est) et haut (le
-- nord), exprimes dans la source et normalises — ou nil et la raison.
--
-- On cherche M telle que dm = M ds, puis on applique son inverse a l'est de la
-- carte (1, 0) et a son nord (0, -1). L'echelle ne compte pas : seules les
-- directions nous interessent, et c'est ce qui fait marcher la mesure meme sur
-- une carte qui ne declare pas sa taille.
function Lieux.ResoudreBoussole(s1, m1, s2, m2)
    local detM = m1[1] * m2[2] - m2[1] * m1[2]
    if math.abs(detM) < 1e-12 then return nil, "les deux déplacements sont parallèles sur la carte." end

    -- M^-1 = S * Mm^-1, developpe pour ne pas trimballer de matrices.
    local estX = (s1[1] * m2[2] - s2[1] * m1[2]) / detM
    local estY = (s1[2] * m2[2] - s2[2] * m1[2]) / detM
    local nordX = (s1[1] * m2[1] - s2[1] * m1[1]) / detM
    local nordY = (s1[2] * m2[1] - s2[2] * m1[1]) / detM

    local est, nord = Normaliser(estX, estY), Normaliser(nordX, nordY)
    if not (est and nord) then return nil, "déplacements trop courts." end
    -- Garde-fou : l'est et le nord sont perpendiculaires dans une source
    -- metrique. S'ils ne le sont pas, les deux echantillons ne viennent pas du
    -- meme endroit (changement de carte au milieu, position perimee) et la
    -- mesure ne vaut rien. Mieux vaut la jeter que poser un nord de travers.
    local produit = est[1] * nord[1] + est[2] * nord[2]
    if math.abs(produit) > 0.12 then
        return nil, "mesure incohérente : les deux relevés ne concordent pas."
    end
    return est, nord
end

-- Ce qui a ete mesure, par carte et par source. En sauvegarde : une carte
-- mesuree une fois n'a pas a l'etre a chaque connexion.
local function Boussoles()
    LCM.EnsureDatabase()
    if type(LCM.db.boussoles) ~= "table" then LCM.db.boussoles = {} end
    return LCM.db.boussoles
end

local function Cle(carte, source)
    return tostring(carte or "?") .. "/" .. tostring(source or "?")
end

-- Rend droite, haut, connue, origine. `connue` est faux quand on retombe sur
-- la convention ; `origine` vaut « mesure », « main » ou « convention ».
-- L'atelier le dit, pour qu'un nord suppose ne passe jamais pour un nord su —
-- ni un nord pose au doigt pour un nord mesure.
function Lieux.Boussole(carte, source)
    local b = Boussoles()[Cle(carte, source)]
    if b and b.droite and b.haut then
        return b.droite, b.haut, true, b.origine or "mesure"
    end
    local c = Lieux.CONVENTION[source] or Lieux.CONVENTION.monde
    return c.droite, c.haut, false, "convention"
end

function Lieux.OublierBoussole(carte, source)
    Boussoles()[Cle(carte, source)] = nil
end

-- La carte et la fraction qu'on y occupe : elles se lisent ENSEMBLE, et c'est
-- le point. Prendre la carte d'ailleurs, c'est risquer de ranger sous une
-- carte des releves pris sur une autre. La fraction repond meme quand la carte
-- ne declare pas sa taille — et c'est tout ce qu'il nous faut, puisqu'on ne
-- cherche que des directions.
local function Fraction()
    if type(C_Map) ~= "table" then return nil end
    local ok, carte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not tonumber(carte) then return nil end
    local ok2, point = pcall(C_Map.GetPlayerMapPosition, carte, "player")
    if not ok2 or type(point) ~= "table" then return nil end
    local x, y = point.x, point.y
    if type(point.GetXY) == "function" then
        local ok3, a, b = pcall(point.GetXY, point)
        if ok3 then x, y = a, b end
    end
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return tonumber(carte), x, y
end

-- Le nord par la MARCHE, quand la carte se tait.
--
-- Marcher droit devant, c'est avancer vers son cap. Si `theta` est la
-- direction prise dans les coordonnees de la source et `phi` le cap annonce
-- par le client, alors theta = A*phi + C, avec A valant +1 ou -1 (le sens dans
-- lequel tourne la source par rapport au monde) et C une constante. Deux
-- trajets droits de caps differents donnent A et C.
--
-- Et C, c'est le nord : la direction qu'on prend en regardant au cap zero.
-- A dit le reste — l'est est a un quart de tour horaire du nord, et c'est A
-- qui dit de quel cote est l'horaire dans cette source.
--
-- Rend droite (l'est) et haut (le nord), ou nil et la raison.
function Lieux.ResoudreBoussoleParMarche(phi1, theta1, phi2, theta2)
    if math.abs(RamenerAngle(phi1 - phi2)) < 0.5 then
        return nil, "les deux trajets suivaient le même cap."
    end
    local essais = {}
    for _, A in ipairs({ 1, -1 }) do
        local c1, c2 = RamenerAngle(theta1 - A * phi1), RamenerAngle(theta2 - A * phi2)
        essais[#essais + 1] = { A = A, c1 = c1, c2 = c2,
                                ecart = math.abs(RamenerAngle(c1 - c2)) }
    end
    table.sort(essais, function(u, v) return u.ecart < v.ecart end)
    local bon, autre = essais[1], essais[2]
    if bon.ecart > 0.30 then
        return nil, "relevés incohérents : le personnage n'allait pas droit."
    end
    if (autre.ecart - bon.ecart) < 0.30 then
        return nil, "les deux sens se valent : il faut des trajets plus francs."
    end
    local C = RamenerAngle(bon.c1 + RamenerAngle(bon.c2 - bon.c1) / 2)
    local est = (bon.A == 1) and (C - math.pi / 2) or (C + math.pi / 2)
    return { math.cos(est), math.sin(est) }, { math.cos(C), math.sin(C) }
end

-- Redresser une boussole a la main, quand la mesure tombe a cote ou tarde.
-- Un quart de tour et un miroir suffisent a atteindre les huit orientations.
local function PoserBoussole(carte, source, droite, haut, origine)
    Boussoles()[Cle(carte, source)] = { droite = droite, haut = haut, origine = origine }
    if Lieux.onChange then Lieux.onChange() end
    return true
end

function Lieux.TournerBoussole(carte, source)
    local droite, haut = Lieux.Boussole(carte, source)
    -- Un quart de tour : ce qui etait a l'est passe au nord.
    return PoserBoussole(carte, source,
        { -haut[1], -haut[2] }, { droite[1], droite[2] }, "main")
end

function Lieux.MiroirBoussole(carte, source)
    local droite, haut = Lieux.Boussole(carte, source)
    -- Gauche et droite echangees : le nord ne bouge pas, l'est se retourne.
    return PoserBoussole(carte, source,
        { -droite[1], -droite[2] }, { haut[1], haut[2] }, "main")
end

-- Les releves en cours, en memoire vive : un deplacement a moitie mesure n'a
-- aucune raison de survivre a un /reload.
local releves = {}

-- A appeler avec la position courante dans `source`. Accumule les trajets et
-- resout des que deux d'entre eux sont assez francs et assez differents.
--
-- DEUX chemins, dans cet ordre : contre la carte si elle repond (elle tranche
-- aussi le sens sans rien supposer), par la marche sinon. La carte manquait
-- sur les cartes qui ne repondent pas, et la mesure n'aboutissait alors
-- jamais — c'est ce qui laissait le radar sur « N ? » et la convention aux
-- commandes (10 octobre 2026).
--
-- Rend true le jour ou la mesure aboutit.
function Lieux.Calibrer(source, x, y)
    if not (source and x and y) then return false end

    local carte, mx, my = Fraction()
    -- Pas de carte du tout : on se rabat sur celle du deplacement, qui peut
    -- etre nil elle aussi — la cle le supporte.
    if not carte then carte = Carte() end
    local cle = Cle(carte, source)
    if Boussoles()[cle] then return false end

    local phi
    if type(GetPlayerFacing) == "function" then
        local ok, valeur = pcall(GetPlayerFacing)
        if ok and type(valeur) == "number" then phi = valeur end
    end
    -- Ni carte ni cap : il n'y a rien a comparer.
    if not mx and not phi then return false end

    local r = releves[cle]
    -- Changer de carte en cours de mesure jette ce qui etait commence : deux
    -- releves pris dans deux reperes ne se comparent pas.
    if r and r.carte ~= carte then r = nil end
    if not r then
        releves[cle] = { carte = carte, base = { x = x, y = y, phi = phi, mx = mx, my = my }, pas = {} }
        return false
    end

    -- Tourner sur place rearme le trajet : ce qui a ete parcouru avant le
    -- virage ne dit rien du nouveau cap.
    if phi and r.base.phi and math.abs(RamenerAngle(phi - r.base.phi)) > 0.15 then
        r.base = { x = x, y = y, phi = phi, mx = mx, my = my }
        return false
    end

    local ds = { x - r.base.x, y - r.base.y }
    if math.sqrt(ds[1] * ds[1] + ds[2] * ds[2]) < 4 then return false end
    local dm
    if mx and r.base.mx then
        dm = { mx - r.base.mx, my - r.base.my }
        if math.sqrt(dm[1] * dm[1] + dm[2] * dm[2]) < 1e-5 then dm = nil end
    end

    local trajet = { s = ds, m = dm, phi = r.base.phi }
    local garde = r.pas[1]
    local function Repartir()
        r.base = { x = x, y = y, phi = phi, mx = mx, my = my }
    end

    if not garde then
        r.pas[1] = trajet
        -- On repart d'ici pour le second trajet : deux segments bout a bout
        -- valent mieux que deux rayons depuis le meme point, ou l'on risque de
        -- revenir sur ses pas.
        Repartir()
        return false
    end

    -- Assez different du premier ? Deux trajets alignes ne disent rien de plus
    -- qu'un seul.
    local a, b = garde.s, ds
    local croise = math.abs(a[1] * b[2] - a[2] * b[1])
    local normes = math.sqrt(a[1] * a[1] + a[2] * a[2]) * math.sqrt(b[1] * b[1] + b[2] * b[2])
    if normes <= 0 or (croise / normes) < 0.25 then
        if (b[1] * b[1] + b[2] * b[2]) > (a[1] * a[1] + a[2] * a[2]) then r.pas[1] = trajet end
        Repartir()
        return false
    end

    local est, nord
    if garde.m and dm then
        est, nord = Lieux.ResoudreBoussole(garde.s, garde.m, ds, dm)
    end
    if not est and garde.phi and phi then
        est, nord = Lieux.ResoudreBoussoleParMarche(
            garde.phi, math.atan2(garde.s[2], garde.s[1]),
            trajet.phi, math.atan2(ds[2], ds[1]))
    end
    releves[cle] = nil
    if not est then return false end
    Boussoles()[cle] = { droite = est, haut = nord, origine = "mesure" }
    if Lieux.onChange then Lieux.onChange() end
    return true
end

-- ===== Le cap ==============================================================
-- Vers ou regarde le personnage, exprime dans le repere du radar : un angle
-- HORAIRE depuis le nord.
--
-- `GetPlayerFacing` rend bien un angle, mais dans quel sens, et depuis quelle
-- origine ? La convention veut 0 au nord et le sens trigonometrique. Zone Gate
-- a du corriger la sienne « constate en jeu » — ce qui dit assez ce que vaut
-- une convention ici. Meme remede que pour le nord : on part d'elle, et on la
-- verifie en marchant. Quand le personnage avance TOUT DROIT, la direction de
-- son deplacement EST son cap ; deux trajets de caps differents suffisent a
-- trancher le sens et l'origine.
Lieux.CAP_CONVENTION = { signe = -1, decalage = 0 }

-- Definie plus haut, avec la boussole : les deux en ont besoin.
local Ramener = RamenerAngle

local function CapMemo()
    LCM.EnsureDatabase()
    if type(LCM.db.cap) ~= "table" then LCM.db.cap = {} end
    return LCM.db.cap
end

-- Deux releves (cap annonce par le client, direction reellement prise). Rend
-- signe, decalage — ou nil et la raison.
function Lieux.ResoudreCap(p1, a1, p2, a2)
    if math.abs(Ramener(p1 - p2)) < 0.5 then
        return nil, "les deux trajets regardent dans la même direction."
    end
    local essais = {}
    for _, signe in ipairs({ 1, -1 }) do
        local d1, d2 = Ramener(a1 - signe * p1), Ramener(a2 - signe * p2)
        essais[#essais + 1] = { signe = signe, d1 = d1, d2 = d2,
                                ecart = math.abs(Ramener(d1 - d2)) }
    end
    table.sort(essais, function(u, v) return u.ecart < v.ecart end)
    local bon, autre = essais[1], essais[2]
    if bon.ecart > 0.30 then return nil, "relevés incohérents : le personnage n'allait pas droit." end
    -- Les deux sens expliquent aussi bien : on ne tranche pas a pile ou face.
    if (autre.ecart - bon.ecart) < 0.30 then
        return nil, "les deux sens se valent : il faut un trajet plus franc."
    end
    return bon.signe, Ramener(bon.d1 + Ramener(bon.d2 - bon.d1) / 2)
end

-- Rend l'angle horaire depuis le nord, et s'il a ete mesure. nil si le client
-- ne dit pas ou regarde le personnage.
function Lieux.Cap()
    if type(GetPlayerFacing) ~= "function" then return nil end
    local ok, phi = pcall(GetPlayerFacing)
    if not ok or type(phi) ~= "number" then return nil end
    local memo = CapMemo()
    if memo.signe then return Ramener(memo.signe * phi + (memo.decalage or 0)), true end
    local c = Lieux.CAP_CONVENTION
    return Ramener(c.signe * phi + c.decalage), false
end

function Lieux.OublierCap()
    local memo = CapMemo()
    memo.signe, memo.decalage = nil, nil
end

-- Les trajets en cours. En memoire vive : a moitie mesure, ca ne vaut rien.
local trajets = nil

-- A appeler avec la position courante dans `source`. Rend true le jour ou la
-- mesure aboutit.
function Lieux.CalibrerCap(source, x, y)
    if CapMemo().signe then return false end
    if not (source and x and y) then return false end
    if type(GetPlayerFacing) ~= "function" then return false end
    local ok, phi = pcall(GetPlayerFacing)
    if not ok or type(phi) ~= "number" then return false end

    if not trajets or trajets.source ~= source then
        trajets = { source = source, base = { x, y, phi }, paires = {} }
        return false
    end

    -- Le virage D'ABORD : tourner sur place n'avance de rien, et si on
    -- regardait la distance en premier on sortirait avant d'avoir note le
    -- nouveau cap — le trajet suivant serait alors toujours rejete parce que
    -- compare au cap d'avant le virage.
    if math.abs(Ramener(phi - trajets.base[3])) > 0.15 then
        trajets.base = { x, y, phi }
        return false
    end
    local dx, dy = x - trajets.base[1], y - trajets.base[2]
    if math.sqrt(dx * dx + dy * dy) < 6 then return false end

    local droite, haut = Lieux.Boussole(Carte(), source)
    local est = droite[1] * dx + droite[2] * dy
    local nord = haut[1] * dx + haut[2] * dy
    trajets.paires[#trajets.paires + 1] = { phi, math.atan2(est, nord) }
    trajets.base = { x, y, phi }
    if #trajets.paires < 2 then return false end

    local p1 = trajets.paires[#trajets.paires - 1]
    local p2 = trajets.paires[#trajets.paires]
    local signe, decalage = Lieux.ResoudreCap(p1[1], p1[2], p2[1], p2[2])
    if not signe then
        -- Le dernier trajet reste : il servira avec le suivant.
        if #trajets.paires > 4 then trajets.paires = { p2 } end
        return false
    end
    local memo = CapMemo()
    memo.signe, memo.decalage = signe, decalage
    trajets = nil
    if Lieux.onChange then Lieux.onChange() end
    return true
end

-- ===== Ce qu'on connait ====================================================

-- Masque chaque caractere en gardant la silhouette du mot (« Le sous-bois »
-- donne « ?? ????-???? »). En Lua 5.1 il n'y a pas de bibliotheque utf8 : on
-- lit la longueur des sequences a la main, sinon un « é » donnerait deux « ? »
-- et le masque trahirait les accents.
local GARDE = { [" "] = true, ["-"] = true, ["'"] = true, ["’"] = true, ["_"] = true }

function Lieux.Masquer(texte)
    if not texte or texte == "" then return texte end
    local out, i, n = {}, 1, #texte
    while i <= n do
        local b = texte:byte(i)
        local large = 1
        if b >= 240 then large = 4
        elseif b >= 224 then large = 3
        elseif b >= 192 then large = 2 end
        local c = texte:sub(i, i + large - 1)
        out[#out + 1] = GARDE[c] and c or "?"
        i = i + large
    end
    return table.concat(out)
end

function Lieux.Connait(lieu)
    if not lieu then return false end
    if Lieux.AMoi(lieu) then return true end
    return Connus().lieux[tostring(lieu.id)] == true
end

function Lieux.ConnaitSeuil(seuil, lieu)
    if not seuil then return false end
    if lieu and Lieux.AMoi(lieu) then return true end
    return Connus().seuils[tostring(seuil.id)] == true
end

function Lieux.Apprendre(lieuId, seuilId)
    local c = Connus()
    if lieuId then c.lieux[tostring(lieuId)] = true end
    if seuilId then c.seuils[tostring(seuilId)] = true end
end

function Lieux.Oublier(lieuId, seuilId)
    local c = Connus()
    if lieuId then c.lieux[tostring(lieuId)] = nil end
    if seuilId then c.seuils[tostring(seuilId)] = nil end
end

-- Le titre et le sous-titre de la banniere. Les deux noms se decouvrent
-- separement : on peut savoir qu'on est aux Marches Grises sans savoir par
-- quelle porte on est entre.
function Lieux.Titre(seuil, lieu)
    if not (seuil and lieu) then return nil end
    local titre = Lieux.Connait(lieu) and tostring(lieu.nom) or "Lieu inconnu"
    local sous = Lieux.ConnaitSeuil(seuil, lieu) and tostring(seuil.nom)
        or Lieux.Masquer(tostring(seuil.nom or ""))
    return titre, sous
end

-- ===== Franchissement ======================================================

-- [seuilId] = 1 | -1 | nil. Rien n'entre en sauvegarde : au /reload on rearme,
-- et le premier battement note le cote sans rien annoncer. C'est voulu — se
-- reconnecter dans un lieu ne doit pas faire croire qu'on vient d'y entrer.
Lieux.etats = Lieux.etats or {}

function Lieux.Rearmer() for k in pairs(Lieux.etats) do Lieux.etats[k] = nil end end

function Lieux.Franchir(seuil, lieu, sens)
    -- La decouverte vient AVANT le texte : on entre pour la premiere fois dans
    -- les Marches Grises, et c'est la banniere qui nous l'apprend.
    if lieu.decouverte then Lieux.Apprendre(lieu.id, seuil.id) end

    if seuil[sens] then
        local titre, sous = Lieux.Titre(seuil, lieu)
        if Lieux.onFranchir then
            Lieux.onFranchir(titre, sous, lieu, seuil, sens)
        end
    end

    -- Le message est local : il s'imprime dans VOTRE chat, et personne d'autre
    -- ne le voit. C'est une indication de jeu, pas une annonce.
    if seuil.message and seuil.message ~= "" and seuil[sens] then
        LCM.Info(seuil.message)
    end
end

-- Le cercle qui contient un seuil, pour juger de loin s'il vaut la peine de
-- redemander `.gps` (DeplacementForce.GPSAPortee). Grossier expres : il ne
-- sert qu'a savoir si l'on est loin de tout.
local function Emprise(seuil)
    if seuil.forme == "cercle" then
        return { x = seuil.x, y = seuil.y, r = tonumber(seuil.rayon) or RAYON }
    end
    if seuil.forme == "porte" then
        local demi = math.sqrt((seuil.bx - seuil.ax) ^ 2 + (seuil.by - seuil.ay) ^ 2) / 2
        return { x = (seuil.ax + seuil.bx) / 2, y = (seuil.ay + seuil.by) / 2,
                 r = demi + (tonumber(seuil.debord) or DEBORD) }
    end
    local cx, cy = 0, 0
    for _, p in ipairs(seuil.points) do cx, cy = cx + p.x, cy + p.y end
    cx, cy = cx / #seuil.points, cy / #seuil.points
    local r = 0
    for _, p in ipairs(seuil.points) do
        r = math.max(r, math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2))
    end
    return { x = cx, y = cy, r = r }
end

function Lieux.Tick()
    local carte = Carte()
    local magasin = Magasin()
    -- Une position par SOURCE, pas une par seuil : trois appels au pire.
    local positions = {}

    for _, lieu in pairs(magasin) do
        for id, seuil in pairs(lieu.seuils or {}) do
            if seuil.actif and seuil.carte == carte and Lieux.Complet(seuil) then
                local source = seuil.source
                local p = positions[source]
                if p == nil then
                    local x, y = Position(source)
                    p = x and { x = x, y = y } or false
                    positions[source] = p
                end
                if p then
                    local cote = Lieux.Cote(seuil, p.x, p.y)
                    if cote then
                        local avant = Lieux.etats[id]
                        if avant and avant ~= cote then
                            Lieux.Franchir(seuil, lieu, (cote == 1) and "entree" or "retour")
                        end
                        Lieux.etats[id] = cote
                    else
                        Lieux.etats[id] = nil
                    end
                end
            end
        end
    end
end

-- ===== L'horloge ===========================================================
-- OnUpdate plutot que C_Timer : il existe toujours, et le banc sait le faire
-- avancer (meme choix que le deplacement force).

local horloge
local function Horloge()
    if horloge then return horloge end
    horloge = CreateFrame("Frame", nil, UIParent)
    horloge:Hide()
    horloge.reste = 0
    horloge:SetScript("OnUpdate", function(self, ecoule)
        self.reste = self.reste + (tonumber(ecoule) or 0)
        if self.reste < INTERVALLE then return end
        self.reste = 0
        Lieux.Tick()
    end)
    return horloge
end

-- On ne bat la mesure que s'il y a quelque chose a franchir.
function Lieux.Regler()
    local quelque = false
    for _, lieu in pairs(Magasin()) do
        for _, seuil in pairs(lieu.seuils or {}) do
            if seuil.actif and Lieux.Complet(seuil) then
                quelque = true
                break
            end
        end
        if quelque then break end
    end
    local h = Horloge()
    if quelque then h:Show() else h:Hide() end
    return quelque
end

-- ===== Reseau ==============================================================

local SUJET, SUJET_RETRAIT = "lieu", "lieu-"
local SUJET_REVELE, SUJET_DEMANDE = "lieu+", "lieux?"

local enReception = false

local function Canal()
    return LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
end

-- Les points tiennent dans UNE chaine (« x,y|x,y|… ») plutot qu'en table
-- imbriquee : l'encodeur ecrit une ligne « p.3.x=… » par coordonnee, et vingt
-- points couteraient a eux seuls plus que les 255 octets d'un message.
local function PlierPoints(points)
    local out = {}
    for _, p in ipairs(points or {}) do
        out[#out + 1] = string.format("%.2f,%.2f", p.x, p.y)
    end
    return table.concat(out, "|")
end

local function DeplierPoints(texte)
    local out = {}
    for couple in tostring(texte or ""):gmatch("[^|]+") do
        local x, y = couple:match("^(-?%d+%.?%d*),(-?%d+%.?%d*)$")
        if x then out[#out + 1] = { x = tonumber(x), y = tonumber(y) } end
    end
    return out
end

-- Cles courtes : un lieu de six seuils doit passer sans etre decoupe en
-- quinze morceaux.
local function Paquet(lieu)
    local p = {
        id = lieu.id, n = lieu.nom, c = lieu.couleur, th = lieu.theme,
        d = lieu.decouverte and 1 or 0, s = {},
    }
    for _, seuil in ipairs(Lieux.Seuils(lieu.id)) do
        p.s[#p.s + 1] = {
            i = seuil.id, n = seuil.nom, f = seuil.forme,
            m = seuil.carte, o = seuil.source,
            a = seuil.actif and 1 or 0,
            ax = seuil.ax, ay = seuil.ay, bx = seuil.bx, by = seuil.by,
            db = seuil.debord, x = seuil.x, y = seuil.y, r = seuil.rayon,
            p = (seuil.forme == "region") and PlierPoints(seuil.points) or nil,
            fe = seuil.ferme and 1 or 0, se = seuil.sens,
            e = seuil.entree and 1 or 0, t = seuil.retour and 1 or 0,
            g = (seuil.message ~= "" and seuil.message) or nil,
            th = seuil.theme,
        }
    end
    return p
end

-- Le decodeur rend TOUT en texte (Reseau.Decoder desechappe des chaines) : un
-- nombre relu sans tonumber comparerait « 12 » a 12 et ne trouverait jamais sa
-- carte. On remet donc chaque champ dans son type, ici et nulle part ailleurs.
local function Lire(paquet, expediteur)
    local id = Texte(paquet.id)
    if id == "" then return nil end
    local lieu = {
        id = id, nom = Texte(paquet.n, NOM_MAX), auteur = expediteur,
        couleur = (Texte(paquet.c) ~= "" and Texte(paquet.c)) or nil,
        theme = (Texte(paquet.th) ~= "" and Texte(paquet.th)) or nil,
        decouverte = tostring(paquet.d or "0") == "1",
        seuils = {},
    }
    if lieu.nom == "" then lieu.nom = "Lieu sans nom" end
    for _, s in ipairs(paquet.s or {}) do
        local sid = Texte(s.i)
        if sid ~= "" then
            lieu.seuils[sid] = {
                id = sid, lieu = id, nom = Texte(s.n, NOM_MAX),
                forme = Lieux.FORMES[s.f] and s.f or "porte",
                carte = tonumber(s.m), source = Texte(s.o),
                actif = tostring(s.a or "0") == "1",
                ax = tonumber(s.ax), ay = tonumber(s.ay),
                bx = tonumber(s.bx), by = tonumber(s.by),
                debord = tonumber(s.db) or DEBORD,
                x = tonumber(s.x), y = tonumber(s.y),
                rayon = tonumber(s.r) or RAYON,
                points = DeplierPoints(s.p),
                ferme = tostring(s.fe or "0") == "1",
                sens = (tonumber(s.se) == -1) and -1 or 1,
                entree = tostring(s.e or "0") == "1",
                retour = tostring(s.t or "0") == "1",
                message = Texte(s.g, MESSAGE_MAX),
                theme = (Texte(s.th) ~= "" and Texte(s.th)) or nil,
            }
        end
    end
    return lieu
end

function Lieux.Diffuser(lieuId)
    if enReception then return false end
    local lieu = Lieux.Get(lieuId)
    if not lieu or not Lieux.AMoi(lieu) then return false end
    local canal = Canal()
    if not canal then return false, "hors groupe : le lieu est posé, mais personne ne le voit." end
    -- Etale : un lieu de vingt seuils fait plusieurs morceaux, et le MJ qui
    -- pose une porte ne doit pas chasser du reseau ce qui attendait deja.
    return LCM.Reseau.Envoyer(SUJET, Paquet(lieu), canal, nil, { etale = true })
end

function Lieux.AnnoncerRetrait(lieuId)
    local canal = Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer(SUJET_RETRAIT, { id = lieuId }, canal)
end

-- Tout renvoyer : apres un /reload d'un joueur, ou quand quelqu'un arrive.
function Lieux.Renvoyer()
    local n = 0
    for _, lieu in ipairs(Lieux.Liste()) do
        if Lieux.AMoi(lieu) and Lieux.Diffuser(lieu.id) then n = n + 1 end
    end
    return n
end

function Lieux.Demander()
    local canal = Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer(SUJET_DEMANDE, {}, canal)
end

-- Reveler un nom a quelqu'un : c'est la seule facon de faire connaitre un lieu
-- dont la decouverte automatique est coupee. `seuilId` nil ne revele que le
-- nom du lieu — on peut savoir ou on est sans savoir par ou on est passe.
function Lieux.Reveler(lieuId, joueur, seuilId)
    local lieu, raison = Mien(lieuId)
    if not lieu then return false, raison end
    joueur = Texte(joueur)
    if joueur == "" then return false, "à qui ?" end
    if joueur == Moi() then
        Lieux.Apprendre(lieuId, seuilId)
        Prevenir()
        return true
    end
    return LCM.Reseau.Envoyer(SUJET_REVELE, { l = lieuId, s = seuilId }, "WHISPER", joueur)
end

LCM.WhenReady(function()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(SUJET, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local lieu = Lire(donnees, expediteur)
        if not lieu then return end
        local ancien = Magasin()[lieu.id]
        -- Un lieu recu n'ecrase JAMAIS un lieu dont je suis l'auteur : deux MJ
        -- dans le groupe, et le second effacerait le travail du premier.
        if ancien and Lieux.AMoi(ancien) then return end
        enReception = true
        Magasin()[lieu.id] = lieu
        enReception = false
        Lieux.Regler()
        Prevenir()
    end)

    LCM.Reseau.Ecouter(SUJET_RETRAIT, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local id = Texte(donnees.id)
        local lieu = Magasin()[id]
        -- Seul son auteur peut retirer un lieu.
        if not lieu or lieu.auteur ~= expediteur then return end
        for seuilId in pairs(lieu.seuils or {}) do Lieux.etats[seuilId] = nil end
        Magasin()[id] = nil
        Lieux.Regler()
        Prevenir()
    end)

    LCM.Reseau.Ecouter(SUJET_REVELE, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local lieuId = Texte(donnees.l)
        local lieu = Magasin()[lieuId]
        -- On n'apprend un nom que de la bouche de celui qui l'a invente.
        if not lieu or lieu.auteur ~= expediteur then return end
        local seuilId = Texte(donnees.s)
        Lieux.Apprendre(lieuId, seuilId ~= "" and seuilId or nil)
        local titre = tostring(lieu.nom)
        LCM.Info(string.format("%s te fait connaître un lieu : %s", tostring(expediteur), titre))
        Prevenir()
    end)

    LCM.Reseau.Ecouter(SUJET_DEMANDE, function(expediteur)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Lieux.Renvoyer()
    end)

    Lieux.Regler()
    -- Au demarrage, un joueur demande ce qu'il a manque. Le MJ, lui, n'a rien
    -- a demander : c'est lui qui detient les lieux.
    if not LCM.IsMaster() then Lieux.Demander() end
end)

-- Changer de carte rearme : les cotes retenus valaient pour l'ancienne, et
-- reapparaitre ailleurs ne doit pas annoncer un franchissement.
LCM.On("PLAYER_ENTERING_WORLD", function() Lieux.Rearmer() end)
LCM.On("ZONE_CHANGED_NEW_AREA", function() Lieux.Rearmer() end)

LCM.AddCommand("lieux", "ce que l'on connaît des lieux", function()
    local lieux, seuils = Lieux.Compte()
    LCM.Info(string.format("%d lieu(x), %d seuil(s).", lieux, seuils))
    for _, lieu in ipairs(Lieux.Liste()) do
        local titre = Lieux.Connait(lieu) and tostring(lieu.nom) or "Lieu inconnu"
        local liste = Lieux.Seuils(lieu.id)
        LCM.Info(string.format("  %s — %d seuil(s), de %s", titre, #liste, tostring(lieu.auteur)))
    end
end)
