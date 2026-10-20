-- Le deplacement force : une Repulsion, une Attraction, une intervention
-- « avec deplacement ».
--
-- Quelqu'un te pousse de six metres. Personne ne compte six metres a l'oeil, et
-- la bonne foi n'a rien a voir la-dedans : sans mesure, chacun s'arrete ou il
-- croit etre arrive. L'addon mesure a ta place et dit quand c'est fait.
--
-- Repris de Necronicon (`Deplacement.lua`, `StartForcedDeplacement` et
-- `_DeplacementTick`), mecanique comprise :
--
--   * la distance est celle qui te separe de ton POINT DE DEPART, a vol
--     d'oiseau — jamais le chemin parcouru. Tourner en rond n'avance a rien,
--     c'est tout l'interet d'une poussee ;
--   * le relief ne compte pas : une variation verticale de moins d'une unite
--     (une marche, un saut sur place) est ignoree ;
--   * `unitesParMetre` convertit les unites de `UnitPosition` en metres de la
--     fiche. A 1 chez nous, comme chez Necronicon.
--
-- L'arrivee passe par des commandes serveur (`.mod speed`, `.aura`), comme
-- Necronicon et comme MoveMaster : annoncer « c'est fait » pendant qu'on court
-- encore ne sert a rien, on finit trois metres trop loin. Elles partent par le
-- chat de guilde ou de groupe — le client ne laisse pas un addon les taper
-- autrement — et `Equilibrage.deplacement.aura = 0` les coupe toutes.
--
-- `LCM.Deplacement` est la FONCTION de calcul des deplacements (Data/Fiche.lua).
-- Ce module s'appelle `LCM.DeplacementForce` : les deux noms se ressemblent, ils
-- n'ont rien a voir.

local _, LCM = ...

local DeplacementForce = {}
LCM.DeplacementForce = DeplacementForce

-- Un echantillon tous les dixiemes de seconde (Necronicon : sampleInterval).
local INTERVALLE = 0.1
local UNITES_PAR_METRE = 1
-- En dessous, une variation verticale est du relief, pas un deplacement.
local RELIEF_IGNORE = 1

-- L'etat vit en memoire vive : un deplacement force ne survit pas a un
-- /reload, et c'est tant mieux — on ne reprend pas une poussee a froid.
local course = nil

-- Ou se tient le personnage. DEUX sources, parce qu'une seule ne suffit pas :
--
--   * `UnitPosition` donne des yards du monde, c'est le bon outil. Mais le
--     client le REFUSE sur les cartes de type instance et rend nil — et nos
--     cartes de campagne en sont. C'est tout le « Position du personnage
--     indisponible (UnitPosition) » de Necronicon, qui s'arretait la ;
--   * la carte repond quand UnitPosition se tait :
--     `C_Map.GetPlayerMapPosition` rend une fraction (0..1) du rectangle de la
--     carte, que `C_Map.GetMapWorldSize` ramene en yards. Plus grossier, et
--     muet si la carte ne declare pas sa taille (certaines customs rendent 0).
--
-- Une course garde la source avec laquelle elle a commence : melanger des
-- yards du monde et des yards de carte au milieu d'un deplacement ferait un
-- bond de plusieurs metres sans que personne n'ait bouge.

local function PositionMonde()
    if type(UnitPosition) ~= "function" then return nil end
    local ok, x, y, z = pcall(UnitPosition, "player")
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, tonumber(z) or 0
end

local function PositionCarte()
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
    local ok4, largeur, hauteur = pcall(C_Map.GetMapWorldSize, carte)
    largeur, hauteur = ok4 and tonumber(largeur) or 0, ok4 and tonumber(hauteur) or 0
    if largeur <= 0 or hauteur <= 0 then return nil end
    -- La fraction se compte depuis le coin haut-gauche. L'altitude n'existe pas
    -- par ce chemin : z reste a 0, et le relief etait deja ignore.
    return x * largeur, y * hauteur, 0
end

-- ===== La troisieme source : .gps =========================================
-- Sur une carte d'instance, `UnitPosition` se tait ET la carte ne declare pas
-- sa taille — c'est le cas de nos cartes de campagne (Magisters' Terrace, 585).
-- Il reste la commande serveur `.gps`, qui marche la ou tout le reste echoue et
-- repond dans le chat :
--
--   Map: 585 (Magisters' Terrace) Zone: 0 (...) Area: 0 (...) Phase: 158070,
--   X: 11275.129883, Y: 11090.638672, Z: -81.208794, O: 1.904451
--
-- On la DEMANDE, et la reponse arrive plus tard : c'est la seule source
-- asynchrone des trois. On garde donc la derniere position connue, et la mesure
-- travaille dessus. Cadence lente exprés (voir INTERVALLE_GPS) : une commande
-- tous les dixiemes de seconde, c'est un mur de texte dans le chat et du bruit
-- pour le serveur.

local gps = { x = nil, y = nil, z = nil, carteMonde = nil, carteQuand = 0,
    quand = 0, demande = 0 }

-- Une ligne de .gps, quelle que soit la langue du serveur : on cherche les
-- trois nombres etiquetes, pas une phrase entiere.
function DeplacementForce.LireGPS(ligne)
    ligne = tostring(ligne or "")
    local x = ligne:match("X:%s*(-?%d+%.?%d*)")
    local y = ligne:match("Y:%s*(-?%d+%.?%d*)")
    local z = ligne:match("Z:%s*(-?%d+%.?%d*)")
    if not (x and y and z) then
        x, y, z = ligne:match("^%s*(-?%d+%.?%d*)%s+(-?%d+%.?%d*)%s+(-?%d+%.?%d*)%s+%d+%s+-?%d+%.?%d*%s*$")
    end
    if not (x and y) then return nil end
    return tonumber(x), tonumber(y), tonumber(z)
end

-- Les modules qui attendaient une reponse .gps pour finir ce qu'ils avaient
-- commence (poser un coffre, une recolte, un marchand).
local function PrevenirReponse()
    if LCM.Coffres and LCM.Coffres.ReponseGPS then LCM.Coffres.ReponseGPS() end
    if LCM.Recolte and LCM.Recolte.ReponseGPS then LCM.Recolte.ReponseGPS() end
    if LCM.Marchands and LCM.Marchands.ReponseGPS then LCM.Marchands.ReponseGPS() end
end

-- La position serveur SANS poser de question : `C_Epsilon.GetPosition()` rend
-- x, y, z et la carte serveur dans le meme repere que `.gps` et `.worldport`
-- (c'est ce que fait Arcanum pour poser un spark, et il l'envoie tel quel a
-- `.worldport`). Synchrone, muet dans le chat, et valable sur une carte
-- d'instance — donc plus de `.gps` a chaque coffre. Absent hors d'Epsilon :
-- on retombe alors sur la commande.
local function PositionEpsilon()
    if type(C_Epsilon) ~= "table" or type(C_Epsilon.GetPosition) ~= "function" then return nil end
    local ok, x, y, z, mapid = pcall(C_Epsilon.GetPosition)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, tonumber(z) or 0, tonumber(mapid)
end

-- Range la position Epsilon comme une reponse .gps toute fraiche.
local function RafraichirEpsilon()
    local x, y, z, mapid = PositionEpsilon()
    if not x then return false end
    local maintenant = (GetTime and GetTime()) or 0
    gps.x, gps.y, gps.z = x, y, z
    gps.carteMonde, gps.carteQuand = mapid, maintenant
    gps.quand = maintenant > 0 and maintenant or (gps.quand + 1)
    gps.sansReponse = 0
    DeplacementForce.gpsTente = nil
    return true
end

-- Appele par le guetteur de chat (et par le banc) quand une reponse arrive.
function DeplacementForce.NoterGPS(ligne)
    local maintenant = (GetTime and GetTime()) or 0
    local carteMonde = tonumber(tostring(ligne):match("Map:%s*(%d+)"))
        or tonumber(tostring(ligne):match("^%s*-?%d+%.?%d*%s+-?%d+%.?%d*%s+-?%d+%.?%d*%s+(%d+)%s+-?%d+%.?%d*%s*$"))
    if carteMonde then
        gps.carteMonde, gps.carteQuand = carteMonde, maintenant
    end
    local x, y, z = DeplacementForce.LireGPS(ligne)
    if not x then return false end
    gps.x, gps.y, gps.z = x, y, z
    if not carteMonde and maintenant > 0
        and maintenant - gps.carteQuand > 3 then gps.carteMonde = nil end
    gps.sansReponse = 0
    DeplacementForce.gpsTente = nil
    gps.quand = maintenant > 0 and maintenant or (gps.quand + 1)
    PrevenirReponse()
    return true
end

-- Une position de .gps n'est bonne qu'un temps : au-dela, on marche depuis
-- trop longtemps pour s'y fier.
local GPS_PERIME = 3

local function PositionGPS(ageMax)
    RafraichirEpsilon()
    if not gps.x then return nil end
    local maintenant = (GetTime and GetTime()) or 0
    if maintenant > 0 and (maintenant - gps.quand) > (ageMax or GPS_PERIME) then return nil end
    return gps.x, gps.y, gps.z
end

function DeplacementForce.CarteGPS(ageMax)
    if not PositionGPS(ageMax) then return nil end
    return gps.carteMonde
end

-- `source` : « monde », « carte » ou « gps » pour rester sur celle d'une course
-- en cours ; rien pour prendre la meilleure disponible. Rend x, y, z, source.
local function Position(source, ageMax)
    if source == "gps" then
        local x, y, z = PositionGPS(ageMax)
        if x then return x, y, z, "gps" end
        return nil
    end
    if source ~= "carte" then
        local x, y, z = PositionMonde()
        if x then return x, y, z, "monde" end
        if source == "monde" then return nil end
    end
    local x, y, z = PositionCarte()
    if x then return x, y, z, "carte" end
    if source == "carte" then return nil end
    -- Dernier recours : ce que .gps a repondu. S'il n'a jamais repondu, c'est
    -- qu'on n'a pas encore demande — Demarrer s'en charge.
    local gx, gy, gz = PositionGPS()
    if gx then return gx, gy, gz, "gps" end
    return nil
end

-- Rendue publique pour les Lieux (Core/Lieux.lua), qui mesurent des
-- franchissements de frontiere et ont donc besoin de la MEME position que les
-- deplacements — avec les trois sources et, surtout, avec le NOM de celle qui a
-- repondu. Deux modules qui lisent la position autrement finiraient par ne plus
-- parler du meme endroit.
function DeplacementForce.Position(source, ageMax)
    return Position(source, ageMax)
end

-- La carte courante, telle qu'on l'inscrit dans un seuil : deux portes posees
-- sur deux cartes differentes ne doivent jamais se repondre, meme si leurs
-- coordonnees se ressemblent.
function DeplacementForce.Carte()
    if type(C_Map) ~= "table" then return nil end
    local ok, carte = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then return nil end
    return tonumber(carte)
end

-- Demande une position au serveur, sans inonder le chat.
local INTERVALLE_GPS = 0.5
function DeplacementForce.DemanderGPS(force, silencieux)
    -- Epsilon sait deja ou l'on est : pas de commande, pas de ligne dans le chat.
    if RafraichirEpsilon() then
        -- Les appelants posent leur attente APRES cet appel : prevenir tout de
        -- suite partirait dans le vide. Au tick suivant, ils sont prets.
        if type(C_Timer) == "table" and C_Timer.After then C_Timer.After(0, PrevenirReponse)
        else PrevenirReponse() end
        return true
    end
    local maintenant = (GetTime and GetTime()) or 0
    if not force and maintenant > 0 and (maintenant - gps.demande) < INTERVALLE_GPS then
        return false
    end
    gps.demande = maintenant
    gps.sansReponse = (gps.sansReponse or 0) + 1
    local envoye = DeplacementForce.Commande(".gps")
    if envoye and silencieux and maintenant > 0 then
        gps.silencieuxJusqua = maintenant + 2
    end
    return envoye
end

-- ===== Le .gps de fond =====================================================
-- Les marchands, la recolte et les lieux battent la mesure quatre fois par
-- seconde. Ils redemandaient `.gps` des que la derniere reponse avait trois
-- secondes, PARTOUT sur la carte, et sans fin si le serveur ne repondait pas
-- (16 octobre 2026). On ne demande plus qu'A PORTEE d'un point : loin de
-- tout, on attend le temps qu'il faudrait pour arriver a portee, et c'est
-- seulement alors qu'on reverifie.
--
-- `cibles` : { { x, y, r }, ... } — les points poses au GPS sur cette carte,
-- `r` le rayon dans lequel ils reagissent.
local PORTEE_GPS = 30       -- yards au-dela du rayon : de quoi le voir venir
local VITESSE_MAX = 14      -- yards par seconde, une monture au galop
local ATTENTE_MAX = 30      -- un teleport ne doit pas laisser aveugle trop longtemps
local SANS_REPONSE_MAX = 3  -- puis on se tait une minute, sans rien dire
local REPOS = 60

-- Epsilon repond-il ? Alors la position serveur est toujours fraiche et rien
-- n'est jamais a demander : ni a la pose, ni en tache de fond.
function DeplacementForce.EpsilonDisponible()
    return PositionEpsilon() ~= nil
end

function DeplacementForce.GPSAPortee(cibles)
    if type(cibles) ~= "table" or #cibles == 0 then return false end
    if RafraichirEpsilon() then return false end
    local maintenant = (GetTime and GetTime()) or 0
    if maintenant < (gps.prochaine or 0) then return false end
    if (gps.sansReponse or 0) >= SANS_REPONSE_MAX then
        gps.sansReponse = 0
        gps.prochaine = maintenant + REPOS
        return false
    end
    -- Sans aucune reponse encore, on ne sait pas ou l'on est : une demande
    -- est le seul moyen de le savoir. Et une position deja jugee loin ne se
    -- rejuge pas : l'attente finie, c'est le moment de reverifier, pas de
    -- repartir pour un tour sur la meme vieille reponse.
    if gps.x and gps.jugee ~= gps.quand then
        local proche = math.huge
        for _, c in ipairs(cibles) do
            local d = math.sqrt((gps.x - c.x) ^ 2 + (gps.y - c.y) ^ 2) - (tonumber(c.r) or 0)
            if d < proche then proche = d end
        end
        if proche > PORTEE_GPS then
            gps.jugee = gps.quand
            gps.prochaine = maintenant + math.min(ATTENTE_MAX, (proche - PORTEE_GPS) / VITESSE_MAX)
            return false
        end
    end
    return DeplacementForce.DemanderGPS(false, true)
end

-- Le cadre qui bat la mesure. OnUpdate plutot que C_Timer : il existe toujours,
-- et le banc sait le faire avancer.
local horloge
local function Horloge()
    if horloge then return horloge end
    horloge = CreateFrame("Frame", nil, UIParent)
    horloge:Hide()
    horloge.reste = 0
    horloge:SetScript("OnUpdate", function(self, ecoule)
        if not course then self:Hide() return end
        self.reste = self.reste + (ecoule or 0)
        if self.reste < INTERVALLE then return end
        self.reste = 0
        DeplacementForce.Mesurer()
    end)
    return horloge
end

function DeplacementForce.EnCours()
    return course
end

-- La distance franchie, et celle qu'il reste. Toujours des nombres : une
-- fenetre qui affiche « nil / 6 m » n'aide personne.
function DeplacementForce.Etat()
    if not course then return 0, 0, false end
    return course.distance, course.limite, true
end

function DeplacementForce.Mesurer()
    if not course then return end
    -- Au GPS, la position ne vient pas toute seule : il faut la redemander. La
    -- cadence est bornee dans DemanderGPS, pas ici.
    if course.source == "gps" then DeplacementForce.DemanderGPS() end
    local x, y, z = Position(course.source)
    if not x then return end

    if course.cumule then
        -- Deplacement ORDINAIRE : on compte le chemin parcouru, pas la distance
        -- au depart. Faire le tour d'un pilier use son allocation, et c'est bien
        -- ce qu'on veut — c'est le mouvement qui coute, pas le resultat.
        local dx, dy, dz = x - course.x, y - course.y, z - course.z
        if math.abs(dz) < RELIEF_IGNORE then dz = 0 end
        course.x, course.y, course.z = x, y, z
        course.distance = course.distance + math.sqrt(dx * dx + dy * dy + dz * dz) / UNITES_PAR_METRE
    else
        -- Deplacement FORCE : la distance au point de depart, a vol d'oiseau.
        -- Tourner en rond n'avance a rien, c'est tout l'interet d'une poussee.
        local dx, dy, dz = x - course.x0, y - course.y0, z - course.z0
        if math.abs(dz) < RELIEF_IGNORE then dz = 0 end
        course.distance = math.sqrt(dx * dx + dy * dy + dz * dz) / UNITES_PAR_METRE
    end

    if course.distance >= course.limite then
        DeplacementForce.Arreter("fini")
        return
    end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
end

-- `metres` : ce qu'il faut franchir. `raison` : ce qui te pousse, pour l'ecrire.
-- `options.cumule` : compter le chemin parcouru (deplacement ordinaire) plutot
-- que la distance au depart (poussee). `options.mode` : le mode de deplacement,
-- pour l'afficher.
function DeplacementForce.Demarrer(metres, raison, options)
    metres = tonumber(metres) or 0
    if metres <= 0 then return false, "distance nulle." end
    local x, y, z, source = Position()
    if not x then
        -- Rien ne repond. On tente `.gps` UNE fois : sa reponse arrive dans le
        -- chat une fraction de seconde plus tard, donc on ne peut pas partir
        -- tout de suite. Mais si le serveur ne l'execute pas — il la renvoie
        -- alors comme un simple message de chat, ce qu'on a vu le 5 octobre —
        -- repeter « relance dans un instant » serait un mensonge poli. On ne le
        -- dit donc qu'au premier essai, et ensuite on nomme le vrai probleme.
        if not DeplacementForce.gpsTente and DeplacementForce.DemanderGPS(true) then
            DeplacementForce.gpsTente = true
            return false, "position demandée au serveur (.gps) — relance dans un instant."
        end
        return false, "position indisponible : ni UnitPosition, ni la carte, ni .gps ne répondent "
            .. "ici. Sur une carte d'instance, il faut le correctif client (Patches/AelskarMapFix)."
    end
    -- Une poussee en remplace une autre : on ne cumule pas deux dettes de
    -- metres, la seconde est celle qui compte.
    course = {
        limite = metres, distance = 0, raison = tostring(raison or "Déplacement forcé"),
        x0 = x, y0 = y, z0 = z, x = x, y = y, z = z, source = source,
        cumule = type(options) == "table" and options.cumule == true or false,
        mode = type(options) == "table" and options.mode or nil,
        debut = (GetTime and GetTime()) or 0,
    }
    Horloge():Show()
    LCM.Alerte(string.format("%s : éloigne-toi de %s m de ton point de départ.",
        course.raison, tostring(metres)))
    if DeplacementForce.onDemarrage then DeplacementForce.onDemarrage(course) end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
    return true
end

-- ===== Les commandes serveur ==============================================
-- Reprises de Necronicon (`SendDeplacementServerCommand`). Un addon ne peut
-- pas taper une commande serveur : il la fait passer par un canal de chat.
-- Guilde d'abord, puis raid, puis groupe. En dehors, on ne peut rien faire, et
-- on le dit une fois plutot que d'echouer en silence.

local function Reglages() return LCM.Equilibrage.deplacement end

local function CanalCommandes()
    local voulu = tostring(Reglages().canalCommandes or "auto"):lower()
    local enGuilde = IsInGuild and IsInGuild()
    local enRaid = IsInRaid and IsInRaid()
    local enGroupe = IsInGroup and IsInGroup()
    if voulu == "guilde" then return enGuilde and "GUILD" or nil end
    if voulu == "raid" then return enRaid and "RAID" or nil end
    if voulu == "groupe" then
        if enRaid then return "RAID" end
        return (enGroupe and "PARTY") or nil
    end
    if enGuilde then return "GUILD" end
    if enRaid then return "RAID" end
    if enGroupe then return "PARTY" end
    return nil
end

local prevenuSansCanal = false

function DeplacementForce.Commande(commande)
    commande = tostring(commande or "")
    if commande == "" then return false end
    local canal = CanalCommandes()
    if not canal or type(SendChatMessage) ~= "function" then
        -- Une seule fois : repete a chaque metre, l'avertissement devient du
        -- bruit et on cesse de le lire.
        if not prevenuSansCanal then
            prevenuSansCanal = true
            LCM.Alerte(string.format(
                "« %s » n'a pas pu partir : il faut etre en guilde ou en groupe. Tape-la a la main.",
                commande))
        end
        return false
    end
    prevenuSansCanal = false
    return pcall(SendChatMessage, commande, canal) and true or false
end

-- Le guetteur : les reponses de `.gps` arrivent comme des messages systeme.
-- Pendant une course, et juste apres une demande silencieuse de l'addon, on
-- les RETIRE de l'affichage — c'est l'addon qui a pose la question, pas le
-- joueur. Le reste du temps elles passent, pour que `.gps` tape a la main
-- reponde.
LCM.WhenReady(function()
    local cadre = CreateFrame("Frame")
    cadre:RegisterEvent("CHAT_MSG_SYSTEM")
    cadre:SetScript("OnEvent", function(_, _, message)
        DeplacementForce.NoterGPS(message)
    end)
    if ChatFrame_AddMessageEventFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
            local auto = GetTime and (GetTime() <= (gps.silencieuxJusqua or 0))
            if (course and course.source == "gps" or auto)
                and (DeplacementForce.LireGPS(message) or tostring(message):match("^Map:%s*%d+")) then
                return true
            end
        end)
    end
end)

-- ===== Le marqueur ========================================================
-- Une aura qui montre OU l'on s'est arrete. Elle se pose a l'arrivee, et le
-- joueur peut la garder (ou la poser lui-meme) par le bouton.

local marqueur = false

function DeplacementForce.Marqueur() return marqueur end

function DeplacementForce.BasculerMarqueur()
    local aura = math.floor(tonumber(Reglages().aura) or 0)
    if aura <= 0 then
        LCM.Alerte("aucune aura de marquage configuree (Equilibrage.deplacement.aura).")
        return false
    end
    if marqueur then
        DeplacementForce.Commande(string.format(".unaura %d", aura))
        marqueur = false
        LCM.Info("Emplacement retire.")
    else
        DeplacementForce.Commande(string.format(".aura %d", aura))
        marqueur = true
        LCM.Ok("Emplacement marque.")
    end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
    return marqueur
end

-- L'arrivee : on ralentit, on marque, et on rend la vitesse apres un temps.
-- Le marqueur pose A LA MAIN survit au retour a la normale : c'est tout son
-- interet, on l'a pose pour qu'il reste.
local function Clouer()
    local r = Reglages()
    local aura = math.floor(tonumber(r.aura) or 0)
    local arret = tonumber(r.vitesseArret) or 0.1
    local normale = tonumber(r.vitesseNormale) or 0.8
    DeplacementForce.Commande(string.format(".mod speed %s", tostring(arret)))
    if aura > 0 then DeplacementForce.Commande(string.format(".aura %d", aura)) end

    local function reprendre()
        if aura > 0 and not marqueur then
            DeplacementForce.Commande(string.format(".unaura %d", aura))
        end
        DeplacementForce.Commande(string.format(".mod speed %s", tostring(normale)))
    end
    local delai = math.max(0.2, tonumber(r.secondesArret) or 2)
    if C_Timer and C_Timer.After then C_Timer.After(delai, reprendre) else reprendre() end
end

-- `cause` : « fini » (distance atteinte) ou « interrompu » (fenetre fermee).
function DeplacementForce.Arreter(cause)
    if not course then return false end
    local fini = cause ~= "interrompu"
    local termine = course
    course = nil
    if horloge then horloge:Hide() end
    if fini then
        LCM.Ok(string.format("%s : %.1f m parcourus, c'est fait.", termine.raison, termine.limite))
        Clouer()
    else
        LCM.Alerte(string.format("%s interrompu : %.1f / %.1f m.",
            termine.raison, termine.distance, termine.limite))
    end
    if DeplacementForce.onFin then DeplacementForce.onFin(termine, fini) end
    if DeplacementForce.onChange then DeplacementForce.onChange() end
    return true
end

-- ===== Le deplacement ordinaire ===========================================
-- Celui qu'on fait de son propre chef, pendant un tour : la fiche dit combien
-- de metres on a, et la jauge les decompte pendant qu'on marche.

local EXPERTISES = { terrestre = "course", nage = "nage", vol = nil }

-- Ce que la fiche autorise dans ce mode, expertise comprise.
function DeplacementForce.Allocation(entity, mode)
    entity = entity or LCM.Entities.Self()
    if not entity then return 0 end
    return LCM.Deplacement(entity, mode, EXPERTISES[mode])
end

local NOMS = { terrestre = "Terrestre", nage = "Nage", vol = "Vol" }

-- ===== Le round ===========================================================
-- Regle de Necronicon : UN deplacement gratuit par round, puis un
-- supplementaire a 1 PA + 1 PF. Au-dela, on ne bouge plus avant le round
-- suivant. Le compteur vit en memoire vive : un round ne survit pas a un
-- /reload, et c'est tres bien — on en ouvre un nouveau.
local mouvements = 0

-- La regle du round ne vaut QU'EN COMBAT. Hors combat, on se deplace, point :
-- compter les deplacements de quelqu'un qui traverse une ville n'a aucun sens,
-- et obligeait a cliquer « nouveau round » pour avancer de trois metres.
function DeplacementForce.EnCombat()
    return LCM.Combat ~= nil and LCM.Combat.EnCours() == true
end

function DeplacementForce.Mouvements() return mouvements end

function DeplacementForce.MaxParRound()
    return math.max(1, math.floor(tonumber(Reglages().parRound) or 2))
end

-- Le prochain deplacement est-il gratuit, payant, ou impossible ?
function DeplacementForce.Prochain()
    if not DeplacementForce.EnCombat() then return "gratuit" end
    if mouvements >= DeplacementForce.MaxParRound() then return "fini" end
    return mouvements == 0 and "gratuit" or "payant"
end

-- Appele par le combat quand le round avance, plus par un bouton : le joueur
-- n'a pas a declarer lui-meme qu'un round a passe, le combat le sait.
-- `silencieux` : au changement de round, l'annonce du combat suffit.
function DeplacementForce.NouveauRound(silencieux)
    mouvements = 0
    if DeplacementForce.onChange then DeplacementForce.onChange() end
    if not silencieux then LCM.Ok("Nouveau round : ton déplacement gratuit est rendu.") end
    return true
end

-- Demarre un deplacement ordinaire dans ce mode.
function DeplacementForce.DemarrerMode(mode, entity)
    mode = tostring(mode or "terrestre")
    if not NOMS[mode] then return false, "mode inconnu." end
    entity = entity or LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end

    local etat = DeplacementForce.Prochain()
    if etat == "fini" then
        return false, string.format("plus de déplacement ce round (%d / %d).",
            mouvements, DeplacementForce.MaxParRound())
    end

    local metres = DeplacementForce.Allocation(entity, mode)
    if metres <= 0 then
        return false, string.format("aucun déplacement %s sur cette fiche.", NOMS[mode]:lower())
    end

    -- Le supplementaire se paie AVANT de partir, et seulement si on peut : on
    -- ne part pas a credit.
    if etat == "payant" then
        local pa = math.max(0, math.floor(tonumber(Reglages().supplementPA) or 1))
        local pf = math.max(0, math.floor(tonumber(Reglages().supplementPF) or 1))
        local jaugePA = LCM.Entities.Gauge(entity, "pa")
        local jaugePF = LCM.Entities.Gauge(entity, "fatigue")
        local disponibles = LCM.Combat and LCM.Combat.PADisponibles(entity)
        if (disponibles or 0) < pa then return false, string.format("il faut %d PA disponibles ce round.", pa) end
        if (jaugePF and jaugePF.current or 0) < pf then return false, string.format("il faut %d PF.", pf) end
        LCM.Entities.SetGauge(entity, "pa", jaugePA.current - pa)
        LCM.Entities.SetGauge(entity, "fatigue", jaugePF.current - pf)
        LCM.Info(string.format("Déplacement supplémentaire : %d PA et %d PF.", pa, pf))
    end

    local ok, raison = DeplacementForce.Demarrer(metres, NOMS[mode], { cumule = true, mode = mode })
    if ok and DeplacementForce.EnCombat() then mouvements = mouvements + 1 end
    return ok, raison
end
