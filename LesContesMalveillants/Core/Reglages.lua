-- Les reglages d'equilibrage : changer un nombre du jeu sans toucher au code.
--
-- Data/Equilibrage.lua porte TOUS les nombres, et c'est tres bien pour les
-- tenir au meme endroit — mais pas pour s'en servir en seance. « Le
-- perce-armure est trop fort, on passe ses degats a 90 % » demandait d'ouvrir
-- un fichier, de le modifier, de republier, et de faire mettre a jour tout le
-- monde (9 octobre 2026).
--
-- Ici, le MJ pose une SURCHARGE : un chemin dans l'equilibrage, une valeur. Elle
-- s'applique tout de suite et se range dans la sauvegarde. Le fichier reste la
-- reference ; la surcharge dit ce qu'on en change, et reste a reporter.
--
--     Reglages.Definir("puissanceMecanique.parMecanique.perce_armure.base", 90)
--
-- POURQUOI UN CHEMIN plutot qu'une table de reglages nommes : l'equilibrage
-- change souvent, et une seconde liste a tenir a jour aurait diverge. Le chemin
-- designe directement le nombre, quel qu'il soit, y compris ceux qu'on ajoutera
-- demain.
--
-- Une surcharge DOIT valoir pour tout le monde, sinon le MJ et ses joueurs ne
-- jouent pas au meme jeu : elle est donc diffusee au groupe, et reste a
-- exporter pour devenir definitive.

local _, LCM = ...

local Reglages = {}
LCM.Reglages = Reglages

local SUJET = "regl"

-- ===== Lire et ecrire par chemin ===========================================

local function Morceaux(chemin)
    local out = {}
    for bout in tostring(chemin or ""):gmatch("[^%.]+") do out[#out + 1] = bout end
    return out
end

-- La table qui porte le dernier morceau, et ce morceau. `creer` fabrique les
-- tables manquantes : `parMecanique` est vide au depart, et une surcharge doit
-- pouvoir y entrer.
local function Ou(racine, chemin, creer)
    local bouts = Morceaux(chemin)
    if #bouts == 0 then return nil end
    local t = racine
    for i = 1, #bouts - 1 do
        local cle = bouts[i]
        -- Un indice de tableau reste un nombre : `primaires.1.cout`.
        if tonumber(cle) and type(t) == "table" and t[tonumber(cle)] ~= nil then cle = tonumber(cle) end
        if type(t[cle]) ~= "table" then
            if not creer then return nil end
            t[cle] = {}
        end
        t = t[cle]
    end
    local dernier = bouts[#bouts]
    if tonumber(dernier) and type(t) == "table" and t[tonumber(dernier)] ~= nil then
        dernier = tonumber(dernier)
    end
    return t, dernier
end

function Reglages.Lire(chemin)
    local t, cle = Ou(LCM.Equilibrage, chemin, false)
    return t and t[cle] or nil
end

-- ===== Le magasin ==========================================================

local function Magasin(creer)
    if not (LCM.db and LCM.db.settings) then return nil end
    if type(LCM.db.settings.equilibrage) ~= "table" then
        if not creer then return nil end
        LCM.db.settings.equilibrage = {}
    end
    return LCM.db.settings.equilibrage
end

function Reglages.Surcharges()
    return Magasin(false) or {}
end

function Reglages.Compte()
    local n = 0
    for _ in pairs(Reglages.Surcharges()) do n = n + 1 end
    return n
end

-- Ce que le fichier dit, avant toute surcharge. Retenu a la PREMIERE surcharge
-- d'un chemin : sans lui, « remettre par defaut » rendrait la valeur surchargee
-- et le defaut serait perdu pour de bon.
--
-- Range dans une BOITE, et non directement : le defaut peut etre `nil`, et
-- c'est le cas le plus frequent — `parMecanique` est vide au depart, donc
-- regler le perce-armure CREE sa cle. Sans la boite, on ne distinguait pas
-- « pas de defaut retenu » de « le defaut est nil », et retirer la surcharge
-- laissait la valeur en place (9 octobre 2026).
local defauts = {}

function Reglages.Defaut(chemin)
    chemin = tostring(chemin or "")
    local boite = defauts[chemin]
    if boite then return boite.v end
    return Reglages.Lire(chemin)
end

-- ===== Poser, retirer ======================================================

local enReception = false

-- Rend true, ou false et la raison. `valeur` nil retire la surcharge.
function Reglages.Definir(chemin, valeur, silencieux)
    chemin = tostring(chemin or "")
    local t, cle = Ou(LCM.Equilibrage, chemin, valeur ~= nil)
    if not t then return false, "ce réglage n'existe pas : " .. chemin end

    if valeur ~= nil then
        valeur = tonumber(valeur)
        if valeur == nil then return false, "un réglage d'équilibrage est un nombre." end
        local avant = t[cle]
        if avant ~= nil and type(avant) ~= "number" then
            return false, "ce réglage n'est pas un nombre : " .. chemin
        end
        if defauts[chemin] == nil then defauts[chemin] = { v = avant } end
        t[cle] = valeur
        local magasin = Magasin(true)
        if magasin then magasin[chemin] = valeur end
    else
        -- Retirer : on REND ce que le fichier disait. Si on ne l'a pas retenu,
        -- c'est que rien n'a jamais ete surcharge ici.
        local magasin = Magasin(false)
        if magasin then magasin[chemin] = nil end
        local boite = defauts[chemin]
        if boite then
            -- `boite.v` peut valoir nil : la cle disparait alors, et la grille
            -- de puissance retombe sur sa valeur globale. C'est exactement ce
            -- qu'on veut pour « remettre le perce-armure par defaut ».
            t[cle] = boite.v
            defauts[chemin] = nil
        end
    end

    if not silencieux and not enReception then Reglages.Diffuser(chemin, valeur) end
    if Reglages.onChange then Reglages.onChange(chemin, valeur) end
    return true
end

function Reglages.Retirer(chemin) return Reglages.Definir(chemin, nil) end

-- Au chargement : le fichier donne les valeurs, puis les surcharges passent
-- par-dessus. Dans cet ordre — une mise a jour de l'addon doit pouvoir changer
-- un defaut sans effacer ce que le MJ a regle.
function Reglages.Appliquer()
    local magasin = Magasin(false)
    if not magasin then return 0 end
    local n = 0
    for chemin, valeur in pairs(magasin) do
        if Reglages.Definir(chemin, valeur, true) then n = n + 1 end
    end
    return n
end

-- ===== Ce qui est publie ===================================================
-- Un reglage reporte dans le depot n'est plus une surcharge : c'est la nouvelle
-- REFERENCE, au meme titre que Data/Equilibrage.lua. Le fichier genere appelle
-- ceci au chargement, avant que les surcharges locales ne passent par-dessus.
--
-- La difference avec `Definir` compte : `Publier` ne range rien dans la
-- sauvegarde et ne diffuse rien. Sans cette distinction, un reglage publie
-- serait eternellement reannonce comme « a exporter ».
function Reglages.Publier(chemin, valeur)
    valeur = tonumber(valeur)
    if valeur == nil then return false end
    local t, cle = Ou(LCM.Equilibrage, chemin, true)
    if not t then return false end
    t[cle] = valeur
    -- Le defaut, desormais, c'est ca. Une surcharge locale posee AVANT le
    -- chargement du fichier aurait retenu l'ancien : on le corrige.
    defauts[tostring(chemin)] = nil
    return true
end

-- Une surcharge devenue identique au fichier n'a plus de raison d'etre : on la
-- retire, sinon elle resterait « a exporter » pour toujours. Meme regle que les
-- entrees du compendium, que le chargement retire de la file d'envoi.
function Reglages.OublierLesRedondantes()
    local magasin = Magasin(false)
    if not magasin then return 0 end
    local n = 0
    for chemin, valeur in pairs(magasin) do
        if defauts[chemin] == nil and Reglages.Lire(chemin) == valeur then
            magasin[chemin] = nil
            n = n + 1
        end
    end
    return n
end

-- ===== Le meme jeu pour tout le monde ======================================
-- Une surcharge que le MJ garde pour lui ferait jouer deux jeux differents : la
-- fiche du joueur calculerait avec l'ancien nombre. On la diffuse donc, et on
-- l'accepte de quiconque est dans le groupe — c'est la meme confiance que
-- partout ailleurs dans l'addon.

function Reglages.Diffuser(chemin, valeur)
    if not (LCM.Reseau and LCM.IsMaster and LCM.IsMaster()) then return end
    local canal = LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
    if not canal then return end
    LCM.Reseau.Envoyer(SUJET, { c = chemin, v = valeur }, canal)
end

LCM.WhenReady(function()
    -- Le fichier genere s'est deja charge (il appelle Publier) : ce qui reste
    -- dans la sauvegarde et vaut deja la valeur du fichier est redondant.
    local oubliees = Reglages.OublierLesRedondantes()
    Reglages.Appliquer()
    if oubliees > 0 then
        LCM.Info(string.format("%d réglage(s) d'équilibrage désormais publié(s) : "
            .. "la surcharge locale est retirée.", oubliees))
    end
    local reste = Reglages.Compte()
    if reste > 0 and LCM.IsMaster() then
        LCM.Info(string.format("%d réglage(s) d'équilibrage en attente d'export.", reste))
    end
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end
    LCM.Reseau.Ecouter(SUJET, function(expediteur, donnees)
        if expediteur == LCM.PlayerId() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local chemin = tostring(donnees.c or "")
        if chemin == "" then return end
        enReception = true
        local ok = Reglages.Definir(chemin, donnees.v, true)
        enReception = false
        if ok then
            local magasin = Magasin(true)
            if magasin then magasin[chemin] = donnees.v end
            LCM.Info(string.format("%s règle l'équilibrage : %s = %s", tostring(expediteur),
                chemin, donnees.v ~= nil and tostring(donnees.v) or "par défaut"))
            if Reglages.onChange then Reglages.onChange(chemin, donnees.v) end
        end
    end)
end)

-- ===== Le tableau des vecteurs =============================================
-- Tout ce qui se regle, a plat : un chemin, sa valeur, son defaut. C'est ce que
-- le panneau du MJ met en tableau.
--
-- On ne descend que dans les tables de NOMBRES : les listes d'identifiants
-- (`statsDeDegats`, `groupesTypes`) ou de definitions (`mecaniques`,
-- `primaires`) ne sont pas des vecteurs d'equilibrage, ce sont des donnees. Les
-- melanger noierait les trente nombres qu'on veut vraiment regler.

local IGNORES = {
    types = true, groupesTypes = true, mecaniques = true, primaires = true,
    statsDeDegats = true, viesParRarete = true,
}

local function Parcourir(table_, prefixe, out, profondeur)
    if profondeur > 4 then return end
    local cles = {}
    for cle in pairs(table_) do cles[#cles + 1] = cle end
    table.sort(cles, function(a, b) return tostring(a) < tostring(b) end)
    for _, cle in ipairs(cles) do
        local valeur = table_[cle]
        local chemin = prefixe == "" and tostring(cle) or (prefixe .. "." .. tostring(cle))
        if type(valeur) == "number" then
            out[#out + 1] = { chemin = chemin, valeur = valeur,
                              defaut = Reglages.Defaut(chemin) }
        elseif type(valeur) == "table" then
            Parcourir(valeur, chemin, out, profondeur + 1)
        end
    end
end

function Reglages.Vecteurs(groupe)
    local out = {}
    local racine = LCM.Equilibrage
    if groupe then
        if IGNORES[groupe] or type(racine[groupe]) ~= "table" then return out end
        Parcourir(racine[groupe], groupe, out, 1)
        return out
    end
    local cles = {}
    for cle, valeur in pairs(racine) do
        if not IGNORES[cle] and (type(valeur) == "number" or type(valeur) == "table") then
            cles[#cles + 1] = cle
        end
    end
    table.sort(cles)
    for _, cle in ipairs(cles) do
        local valeur = racine[cle]
        if type(valeur) == "number" then
            out[#out + 1] = { chemin = cle, valeur = valeur, defaut = Reglages.Defaut(cle) }
        else
            Parcourir(valeur, cle, out, 1)
        end
    end
    return out
end

-- Les groupes, pour une liste a gauche du tableau.
function Reglages.Groupes()
    local out = {}
    for cle, valeur in pairs(LCM.Equilibrage) do
        if not IGNORES[cle] and type(valeur) == "table" then out[#out + 1] = cle end
    end
    table.sort(out)
    return out
end

-- ===== La puissance d'une mecanique ========================================
-- Le cas d'usage qui a fait naitre ce module : « le perce-armure est trop fort,
-- on passe ses degats a 90 % ». La grille de puissance (Core/Actions.lua) lit
-- deja `parMecanique[id]` avec un repli sur la valeur globale ; il ne manquait
-- qu'un moyen de la remplir.

function Reglages.CheminMecanique(mecaniqueId, colonne)
    return string.format("puissanceMecanique.parMecanique.%s.%s",
        tostring(mecaniqueId), tostring(colonne or "base"))
end

function Reglages.PuissanceMecanique(mecaniqueId)
    local P = LCM.Equilibrage.puissanceMecanique
    local propre = P.parMecanique and P.parMecanique[tostring(mecaniqueId)]
    return {
        base = tonumber(propre and propre.base) or tonumber(P.base) or 0,
        parPoint = tonumber(propre and propre.parPoint) or tonumber(P.parPoint) or 0,
        equipParPoint = tonumber(propre and propre.equipParPoint) or tonumber(P.equipParPoint) or 0,
        propre = propre ~= nil,
    }
end

LCM.AddCommand("equilibrage", "règle un nombre du jeu : <chemin> <valeur>, ou seul pour la liste",
    function(argument)
        argument = tostring(argument or "")
        local chemin, valeur = argument:match("^%s*([%w_%.]+)%s+(-?[%d%.]+)%s*$")
        if chemin then
            local ok, raison = Reglages.Definir(chemin, tonumber(valeur))
            if ok then
                LCM.Ok(string.format("%s = %s (défaut : %s)", chemin, valeur,
                    tostring(Reglages.Defaut(chemin))))
            else
                LCM.Alerte(tostring(raison))
            end
            return
        end
        local seul = argument:match("^%s*([%w_%.]+)%s*$")
        if seul then
            LCM.Info(string.format("%s = %s", seul, tostring(Reglages.Lire(seul))))
            return
        end
        local n = Reglages.Compte()
        LCM.Info(string.format("%d réglage(s) en cours. « /lcm outils » pour le tableau.", n))
        for chemin, v in pairs(Reglages.Surcharges()) do
            LCM.Info(string.format("   %s = %s (défaut : %s)", chemin, tostring(v),
                tostring(Reglages.Defaut(chemin))))
        end
    end, true)
