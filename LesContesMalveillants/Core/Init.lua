-- Les Contes Malveillants — point d'entree.
--
-- Cet addon est ecrit POUR une campagne : la structure des fiches, les
-- categories de contenu et les regles sont figees dans le code. C'est le choix
-- qui le distingue de Necronicon, ou tout etait configurable a l'execution —
-- avec pour rancon des identifiants negocies au vol, des references par nom et
-- les collisions qui vont avec.
--
-- Regle de base : aucune donnee de structure ne vit dans la sauvegarde. La
-- sauvegarde ne contient QUE ce que le joueur a saisi (valeurs, choix, etats).

local ADDON_NAME, LCM = ...
_G.LCM = LCM

LCM.name = ADDON_NAME
LCM.version = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"

-- Nom du compagnon qui porte le contenu du maitre du jeu. Sa presence suffit a
-- debloquer l'interface MJ : ce n'est pas un verrou, c'est un aiguillage. Ce qui
-- doit rester secret n'est pas « cache » ici, il n'est simplement pas livre aux
-- joueurs — un addon vit sur leur machine, rien de ce qu'on leur envoie ne leur
-- est inaccessible.
LCM.MASTER_ADDON = "LesContesMalveillants_MJ"

local function IsAddOnPresent(name)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not loaded then return false end
    local ok, isLoaded = pcall(loaded, name)
    return ok and isLoaded == true
end

-- Vrai quand le compagnon MJ est installe. A n'appeler qu'apres le chargement
-- des addons (le compagnon se charge APRES nous, il declare une dependance).
-- « Je joue, ce soir. » Un MJ qui prend un personnage veut voir exactement ce
-- que ses joueurs voient : pas de compendium, pas de Panel MJ, pas de case de
-- niveau ouverte. Plutot que de desactiver l'addon compagnon et de relancer le
-- jeu, on le met en veille — le compagnon reste charge, il ne repond plus.
--
-- C'est un reglage de COMPTE : on le retrouve apres un /reload, sinon on
-- croirait etre joueur et on ne le serait plus.
function LCM.ModeJoueur()
    return LCM.db and LCM.db.settings and LCM.db.settings.modeJoueur == true
end

function LCM.IsMaster()
    if LCM.ModeJoueur() then return false end
    if LCM._masterCompanion == true then return true end
    return IsAddOnPresent(LCM.MASTER_ADDON)
end

-- Bascule et rend le nouvel etat. `force` impose la valeur plutot que d'inverser.
function LCM.BasculerModeJoueur(force)
    LCM.EnsureDatabase()
    local voulu = force
    if voulu == nil then voulu = not LCM.ModeJoueur() end
    -- Sans le compagnon, il n'y a rien a mettre en veille.
    if voulu and not IsAddOnPresent(LCM.MASTER_ADDON) and LCM._masterCompanion ~= true then
        return false, "tu n'as pas le compagnon du maître du jeu."
    end
    LCM.db.settings.modeJoueur = voulu or nil
    if LCM.onModeJoueur then LCM.onModeJoueur(voulu) end
    return true, voulu
end

-- ===== Sauvegarde ==========================================================
-- Deux tables, et deux seulement :
--   LCM_DB      : ce qui appartient au compte (reglages, contenu partage)
--   LCM_CharDB  : ce qui appartient au personnage (sa fiche, ses etats)
-- Toute nouvelle donnee doit se ranger dans l'une des deux, jamais ailleurs.

local DB_VERSION = 1

function LCM.EnsureDatabase()
    _G.LCM_DB = type(_G.LCM_DB) == "table" and _G.LCM_DB or {}
    _G.LCM_CharDB = type(_G.LCM_CharDB) == "table" and _G.LCM_CharDB or {}

    local db = _G.LCM_DB
    db.version = tonumber(db.version) or DB_VERSION
    db.settings = type(db.settings) == "table" and db.settings or {}

    -- Nettoyage du prototype de curseur retire : remettre la taille native
    -- sauvegardee avant le test, une seule fois au prochain chargement.
    local tailleCurseur = db.settings.curseurTestTailleInitiale
    if tailleCurseur == nil and db.settings.curseurTestActif then
        tailleCurseur = "-1"
    end
    if tailleCurseur ~= nil and C_CVar and C_CVar.SetCVar then
        local ok = pcall(C_CVar.SetCVar, "cursorSizePreferred", tailleCurseur)
        if ok then
            db.settings.curseurTestTailleInitiale = nil
            db.settings.curseurTestActif = nil
        end
    end

    local charDb = _G.LCM_CharDB
    charDb.version = tonumber(charDb.version) or DB_VERSION

    LCM.db = db
    LCM.charDb = charDb
    return db, charDb
end

-- Identite reseau du joueur : « Nom-Royaume », stable et comparable.
function LCM.PlayerId()
    -- `a and f()` est ajuste a UNE valeur en affectation multiple : ecrit ainsi,
    -- le royaume etait silencieusement perdu.
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name = tostring(name or (UnitName and UnitName("player")) or "")
    realm = tostring(realm or "")
    if name == "" then return "" end
    if realm ~= "" then return name .. "-" .. realm end
    return name
end
