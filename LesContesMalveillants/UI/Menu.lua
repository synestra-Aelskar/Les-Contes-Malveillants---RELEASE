-- Le menu des fenetres.
--
-- Il s'affiche en couronne radiale, au clic gauche sur le sceau (UI/Radial.lua,
-- couronne « fenetres ») : les entrees de premier niveau en couronne, les
-- fenetres d'un dossier en eventail. Jusqu'au 3 octobre 2026, il avait son
-- propre bouton a la Necronicon (colonne d'icones, volets a gauche) ; les
-- deux lanceurs ont ete fondus en un.
--
-- La STRUCTURE est celle du menu du template (« Template Fiche LVL 5 - Contes
-- Malveillants V2 », menuTree), figee ici. Un module n'ajoute pas d'entree : il
-- en habille une qui existe, par Menu.Lier(id, fonction). Une entree sans
-- fenetre reste visible, eteinte, et le dit au clic.

local _, LCM = ...
local UI = LCM.UI

local Menu = {}
UI.Menu = Menu

local ICONE = "Interface\\ICONS\\"
local RADIAL = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\"

-- ===== La structure, figee =================================================
-- Categories et sous-menus partagent les icones noires et dorees du radial.
-- Systeme utilise lui aussi des pictogrammes noirs et dores.

Menu.STRUCTURE = {
    -- « Création » a quitte le menu le 1er octobre 2026 : on cree un personnage
    -- depuis la selection (Maj + clic sur le sceau, « + Créer un personnage »),
    -- la ou l'on choisit deja qui l'on joue. L'avoir aux deux endroits ne
    -- servait qu'a se demander lequel fait foi. Le dossier « Création
    -- Personnage » du template, qui ne gardait plus que les Règles, l'a suivi
    -- le 2 octobre 2026 ; les Règles sont passees dans « Outils ».
    { id = "fiches_personnages", label = "Personnage", icone = RADIAL .. "fenetres-personnages.tga",
      badge = function()
          local entity = LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage()
          return LCM.Experience and LCM.Experience.NiveauxEnAttente(entity) or 0
      end,
      enfants = {
          { id = "montee_niveau", label = "Niveau supérieur",
            icone = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
            visible = function()
                local entity = LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage()
                return LCM.Experience and LCM.Experience.PeutMonter(entity)
            end,
            badge = function()
                local entity = LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage()
                return LCM.Experience and LCM.Experience.NiveauxEnAttente(entity) or 0
            end },
          { id = "fiche",         label = "Fiche",                     icone = RADIAL .. "fenetres-fiche.tga" },
          { id = "sante",         label = "Santé",                     icone = RADIAL .. "fenetres-sante.tga" },
          { id = "expertise",     label = "Expertises",                icone = RADIAL .. "fenetres-expertise.tga" },
          { id = "penetrations_resistances", label = "Pénétration & Résistances", icone = RADIAL .. "fenetres-penetrations_resistances.tga" },
          { id = "statistiques",  label = "Statistiques",              icone = RADIAL .. "fenetres-statistiques.tga" },
          { id = "apprentissage", label = "Apprentissage",             icone = RADIAL .. "fenetres-apprentissage.tga" },
      } },
    { id = "objets", label = "Objets", icone = RADIAL .. "fenetres-objets.tga",
      enfants = {
          { id = "equipement",  label = "Équipements", icone = RADIAL .. "fenetres-equipement.tga" },
          { id = "inventaires", label = "Inventaires", icone = RADIAL .. "fenetres-inventaires.tga" },
          -- Ajout a la structure du template : chaque joueur voit sa bourse.
          { id = "bourse",      label = "Bourse",      icone = RADIAL .. "fenetres-bourse.tga" },
          { id = "metiers",     label = "Métiers",     icone = RADIAL .. "fenetres-metiers.tga" },
          -- Ajout de l'addon (22 octobre 2026) : ce qu'on tient en main. Pour
          -- l'instant la lanterne et son cristal (UI/Lanterne.lua) ; le nom
          -- est provisoire. L'id n'est pas « outils », deja pris par le
          -- dossier du premier niveau.
          { id = "outils_portes", label = "Outils",    icone = RADIAL .. "fenetres-outils.tga" },
      } },
    { id = "grimoires", label = "Grimoires", icone = RADIAL .. "fenetres-grimoires.tga" },
    { id = "systeme", label = "Système", icone = RADIAL .. "fenetres-compendium.tga",
      enfants = {
          { id = "systeme_aelskar", label = "Compendium", icone = RADIAL .. "fenetres-compendium.tga", mjSeulement = true },
          { id = "lieux", label = "Lieux", icone = RADIAL .. "fenetres-lieux.tga", mjSeulement = true },
          { id = "interactions", label = "Interactions", icone = RADIAL .. "fenetres-interactions.tga", mjSeulement = true,
            enfants = {
                { id = "coffres", label = "Coffres", icone = RADIAL .. "fenetres-coffres.tga", mjSeulement = true },
                { id = "vendeur", label = "Vendeurs", icone = RADIAL .. "fenetres-vendeurs.tga", mjSeulement = true },
                { id = "ressources", label = "Ressources", icone = RADIAL .. "fenetres-recoltes.tga", mjSeulement = true },
            } },
          { id = "regles", label = "Règles", icone = RADIAL .. "fenetres-regles.tga" },
      } },
    { id = "outils", label = "Outils", icone = RADIAL .. "fenetres-outils.tga",
      enfants = {
          { id = "campement",  label = "Campement",  icone = ICONE .. "spell_fire_fire" },
          { id = "incarner",   label = "Incarner",   icone = RADIAL .. "fenetres-incarner.tga", mjSeulement = true },
          { id = "atelier",    label = "Atelier",    icone = RADIAL .. "fenetres-compendium.tga", mjSeulement = true },
          { id = "panneau_mj", label = "Panel MJ",   icone = RADIAL .. "fenetres-panneau_mj.tga", mjSeulement = true },
          { id = "parametres", label = "Paramètres", icone = RADIAL .. "fenetres-parametres.tga" },
          -- L'atelier etait enfoui dans le Panel MJ, a trois clics : c'est
          -- l'outil qu'on ouvre le plus en seance, il est ici (3 octobre 2026).
          -- Reserves au MJ depuis le 3 octobre 2026 : un vendeur et un filon
          -- s'ouvrent quand le MJ les met en jeu, pas quand un joueur decide
          -- d'aller faire ses courses.
          -- Ajout de l'addon (10 octobre 2026), absent du template : rangee ici
          -- en attendant de lui trouver sa place. Pas encore d'icone noire et
          -- doree : celle du jeu en attendant.
          -- Ajout du 10 octobre 2026. Le dossier etait plein a huit : c'est
          -- pour cette entree qu'un neuvieme bandeau d'eventail a ete
          -- fabrique (UI/Radial.lua, MAX_ENTREES). Pas encore d'icone noire et
          -- doree : celle du jeu en attendant.
      } },
    -- Accessible ici pour consulter sa jauge hors combat, et conserve aussi
    -- dans le radial des actions afin de rester immédiatement disponible en
    -- combat.
    { id = "deplacement", label = "Déplacement", icone = RADIAL .. "fenetres-deplacement.tga" },
}

-- Un dossier s'ouvre en eventail, et un eventail ne sait dessiner que les
-- longueurs de bandeau qui existent. Le plafond se lit chez celui qui le sait
-- (UI/Radial.lua, MAX_ENTREES) plutot que de se recopier ici : repete, il
-- aurait fallu penser a le changer aux deux endroits.
local PLAFOND = (UI.Radial and UI.Radial.MAX_ENTREES) or 8
local function VerifierDossiers(noeuds, profondeur)
    for _, noeud in ipairs(noeuds) do
        if noeud.enfants then
            local maximum = PLAFOND
            if #noeud.enfants > maximum then
                error(string.format("menu : le dossier %s a %d fenetres (maximum %d)",
                    noeud.id, #noeud.enfants, maximum))
            end
            VerifierDossiers(noeud.enfants, profondeur + 1)
        end
    end
end
VerifierDossiers(Menu.STRUCTURE, 0)

-- ===== Liaisons ============================================================

local function Trouver(id, noeuds)
    id = tostring(id or "")
    for _, noeud in ipairs(noeuds or Menu.STRUCTURE) do
        if noeud.id == id then return noeud end
        if noeud.enfants then
            local trouve = Trouver(id, noeud.enfants)
            if trouve then return trouve end
        end
    end
end
Menu.Trouver = Trouver

-- LCM.UI.Menu.Lier("fiche", function() ... end). Un dossier ne se lie pas :
-- il s'ouvre.
function Menu.Lier(id, onClick)
    local cible = Trouver(id)
    if not cible or cible.enfants then
        LCM.Erreur(string.format("menu : entree inconnue « %s »", tostring(id)))
        return false
    end
    if type(onClick) ~= "function" then return false end
    cible.onClick = onClick
    return true
end

function Menu.EstLiee(id)
    local cible = Trouver(id)
    return cible ~= nil and type(cible.onClick) == "function"
end

-- Ce que le joueur voit ; le MJ voit en plus ses outils. Un dossier dont tout
-- le contenu est reserve au MJ disparait pour les autres.
function Menu.Visibles(noeuds)
    local out = {}
    for _, noeud in ipairs(noeuds or Menu.STRUCTURE) do
        local visible = type(noeud.visible) ~= "function" or noeud.visible()
        if visible and (not noeud.mjSeulement or LCM.IsMaster()) then
            if not noeud.enfants or #Menu.Visibles(noeud.enfants) > 0 then out[#out + 1] = noeud end
        end
    end
    return out
end

-- ===== Ouverture ===========================================================
-- Le menu n'a plus de bouton a lui : c'est la couronne gauche du sceau
-- (UI/Radial.lua). Cette fonction reste le point d'entree de la commande et
-- du raccourci clavier.

function Menu.Basculer()
    UI.Radial.Basculer("fenetres")
end

LCM.AddCommand("fenetres", "ouvre le menu des fenetres", function() Menu.Basculer() end)

-- Les vues (Regles comprise) se lient elles-memes (UI/Vues.lua).
