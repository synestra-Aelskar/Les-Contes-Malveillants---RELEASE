-- Le sceau et ses deux couronnes radiales.
--
-- Le sceau est affiche en permanence. Clic gauche : la couronne des FENETRES
-- (structure de UI/Menu.lua). Clic droit : la couronne des ACTIONS, dont les
-- categories sont les barres du template (Offensives, Supports, Competences,
-- Controles ; Animation pour le MJ) et dont chaque entree joue son action,
-- ecrite avec elle dans le code (Core/ActionsBoutons.lua, Core/Actions.lua).
-- Maj + clic gauche : la selection du
-- personnage. Une seule couronne a la fois : ouvrir l'une ferme l'autre.
--
-- Jusqu'au 3 octobre 2026, les fenetres avaient leur propre bouton, avec une
-- colonne d'icones a la Necronicon ; il a ete fondu dans le sceau. Dans une
-- couronne, clic sur une categorie : ses entrees s'ouvrent
-- en eventail ; une entree sans rien derriere reste eteinte et le dit.
--
-- La structure est FIGEE ici. Un module n'ajoute pas d'entree : il en habille
-- une qui existe deja, par Radial.Lier(id, fonction). L'action d'un bouton
-- est definie AVEC lui, dans le code (Core/ActionsBoutons.lua, Data/
-- ActionsBoutons.lua ; celles du MJ dans le compagnon) : jusqu'au 3 octobre
-- 2026, il citait une entree du compendium importee de Necronicon (quickMenu,
-- RunCompendiumEntryShortcut). UI/Composeur.lua fait la liaison. Un identifiant inconnu
-- est refuse — c'est ce qui evite les menus qui poussent tout seuls et les
-- ordres negocies au vol qu'on a subis dans Necronicon.
--
-- Un chouilla plus petit que celui de Necronicon : sceau de 58 au lieu de 64,
-- categories a 94 au lieu de 106, actions a 172 au lieu de 202.

local _, LCM = ...
local UI = LCM.UI
local GameTooltip = UI.Infobulle()

local Radial = {}
UI.Radial = Radial

local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\"
local SCEAU = ART .. "sceau.tga"
local SIGIL = ART .. "sigil.tga"
-- Meme famille noire et doree que les categories et sous-menus de Fenetres.
local ICONE = ART .. "icones\\actions-"

Radial.SCEAU = 58
Radial.LIVRE_LARGEUR = 76
-- Une seule taille pour les deux anneaux (categories et eventails) depuis le
-- 3 octobre 2026 : a 40 contre 52, le menu et son sous-menu ne semblaient pas
-- du meme jeu. 46 laisse de l'air des deux cotes : 61 unites entre deux
-- entrees voisines d'un eventail, et la legende d'une categorie du bas
-- s'arrete avant l'eventail qui s'ouvre sous elle.
Radial.VIGNETTE = 46
Radial.CATEGORIE = Radial.VIGNETTE
Radial.ACTION = Radial.VIGNETTE
Radial.FOND = 436
-- Couronne principale : filets de background.tga mesures a 146 et 272 px
-- du centre (texture 1024). Meme marge de chaque cote du cercle visible.
Radial.COURONNE_INTERIEURE = 146 / 1024
Radial.COURONNE_EXTERIEURE = 272 / 1024
Radial.RAYON_CATEGORIE = Radial.FOND * (Radial.COURONNE_INTERIEURE + Radial.COURONNE_EXTERIEURE) / 2
-- Ou le cuir d'un bandeau commence et finit, en fraction du cote de sa
-- texture. Mesure sur l'alpha de grimoire-fan-3 (le meme pour les neuf
-- longueurs) : 309 et 470 sur 1024.
Radial.BANDE_INTERIEURE = 309 / 1024
Radial.BANDE_EXTERIEURE = 470 / 1024
-- Centre du cercle sur la ligne mediane du cuir, pour TOUTES les couronnes
-- et tous leurs sous-menus. L'ancien rayon fixe (172) poussait les vignettes
-- de 6,2 unites vers le bord externe. Les neuf textures ont le meme rayon.
Radial.RAYON_ACTION = Radial.FOND * (Radial.BANDE_INTERIEURE + Radial.BANDE_EXTERIEURE) / 2

-- Le second eventail (un sous-menu, comme Systeme > Interactions) est le MEME
-- eventail que le premier, meme taille, DECALE vers l'exterieur dans la
-- direction de son bouton parent, avec un espace entre les deux.
--
-- Garde le meme centre, un second anneau ne peut s'ecarter du premier qu'en
-- grandissant : pose a 278 il flottait mais etait enorme, agrandi moins il
-- collait ou passait dessous (16 octobre 2026, quatre essais). Decale, il
-- garde la taille et la courbure du premier. Deux arcs de meme courbure se
-- rapprochent vers leurs bouts : le decalage est calcule pour laisser
-- ECART_SOUS_MENU au milieu et au moins ECART_BORDS aux extremites.
Radial.ECART_SOUS_MENU = 16
Radial.ECART_BORDS = 6
-- La distance entre les deux centres pour qu'un eventail de `nombre`
-- branches respecte ces deux ecarts.
function Radial.DecalageSousMenu(nombre)
    local interieur = Radial.FOND * Radial.BANDE_INTERIEURE
    local exterieur = Radial.FOND * Radial.BANDE_EXTERIEURE
    -- Le decalage d qui met le bord interieur du second, a l'angle `theta`
    -- de son milieu, a la distance `bord` du centre du premier.
    local function Decalage(theta, bord)
        local c = math.cos(theta)
        return -interieur * c + math.sqrt(interieur * interieur * (c * c - 1) + bord * bord)
    end
    local demiEmpan = (math.max(1, nombre) / 2) * math.pi / 8.75
    return math.max(Decalage(0, exterieur + Radial.ECART_SOUS_MENU),
        Decalage(demiEmpan, exterieur + Radial.ECART_BORDS))
end
-- Le plafond, c'est le nombre de BANDEAUX dessines dans
-- ressources/radial (grimoire-fan-1..9) : au-dela, l'eventail n'a plus de
-- fond a poser derriere ses branches. Le neuvieme a ete fabrique le
-- 10 octobre 2026 a partir du huitieme — les bandeaux sont le meme objet a
-- N longueurs (meme rayon, empan qui croit d'un pas constant de ~20,6°),
-- donc on etire le cuir du milieu en gardant les deux embouts dores.
Radial.MAX_ENTREES = 9

-- ===== La structure, figee =================================================
-- Ajouter une entree ici est un acte de developpement, pas un reglage : les
-- identifiants sont ceux que citeront les liaisons, les raccourcis et la doc.

Radial.STRUCTURE = {
    {
        id = "offensives", label = "Offensives", icone = ICONE .. "offensives.tga",
        entrees = {
            { id = "attaque_simple",     label = "Attaque",              icone = ICONE .. "attaque_simple.tga" },
            { id = "perce_armure",       label = "Perce-armure",         icone = ICONE .. "perce_armure.tga" },
            { id = "brise_armure",       label = "Brise-armure",         icone = ICONE .. "brise_armure.tga" },
            { id = "generation_debuff",  label = "Génération de débuff", icone = ICONE .. "generation_debuff.tga" },
            { id = "dot",               label = "Dot",                  icone = ICONE .. "generation_debuff.tga" },
        },
    },
    {
        id = "supports", label = "Supports", icone = ICONE .. "supports.tga",
        entrees = {
            { id = "generation_bouclier", label = "Génération de bouclier", icone = ICONE .. "generation_bouclier.tga" },
            { id = "generation_soin",     label = "Génération de soin",     icone = ICONE .. "generation_soin.tga" },
            { id = "generation_buff",     label = "Génération de buff",     icone = ICONE .. "generation_buff.tga" },
            { id = "dissipation",         label = "Dissipation",            icone = ICONE .. "dissipation.tga" },
        },
    },
    {
        id = "mouvement", label = "Déplacement", icone = ART .. "icones\\fenetres-deplacement.tga",
        direct = true,
    },
    -- La seule categorie dont le contenu n'est pas ecrit ici : ce sont les
    -- sorts du personnage joue, qui changent de personnage en personnage.
    -- Dans Necronicon, la barre « Compétences » portait la meme chose
    -- (RunGrimoireShortcutExec). Autant que l'eventail sait dessiner de
    -- branches, pas plus : au-dela on ne choisit plus, on cherche. Le plafond
    -- se LIT (MAX_ENTREES) au lieu de se recopier — ecrit en dur ici, il n'a
    -- pas suivi quand l'eventail a gagne une neuvieme branche, et la neuvieme
    -- competence restait introuvable sans un mot (10 octobre 2026).
    { id = "competences", label = "Compétences", icone = ICONE .. "competences.tga",
      contenu = function()
          local moi = LCM.Entities.Self()
          if not moi then return {} end
          local out = {}
          for _, sort in ipairs(LCM.Sorts.Liste(moi)) do
              out[#out + 1] = {
                  id = "sort_" .. tostring(sort.id), label = sort.label, icone = sort.icone,
                  onClick = function()
                      -- Un sort qui se lance se lance ; les autres se citent
                      -- dans le chat, ce qui est leur seule action utile.
                      if sort.jet then
                          local resultat, mini, maxi = LCM.Roll.Des(sort.jet.min, sort.jet.max)
                          LCM.Canal.Dire(string.format("%s : |cffffd36b%d|r  (%d-%d)",
                              tostring(sort.label), resultat, mini, maxi))
                      else
                          LCM.Lien.Inserer(LCM.Lien.Sort(moi, sort))
                      end
                  end,
              }
              if #out >= Radial.MAX_ENTREES then break end
          end
          return out
      end },
    {
        id = "controles", label = "Contrôles", icone = ICONE .. "controles.tga",
        entrees = {
            { id = "repulsion",      label = "Répulsion",      icone = ICONE .. "repulsion.tga" },
            { id = "attraction",     label = "Attraction",     icone = ICONE .. "attraction.tga" },
            { id = "permutation",    label = "Permutation",    icone = ICONE .. "permutation.tga" },
            { id = "immobilisation", label = "Immobilisation", icone = ICONE .. "immobilisation.tga" },
            { id = "entrave",        label = "Entrave",        icone = ICONE .. "entrave.tga" },
            { id = "levitation",     label = "Lévitation",     icone = ICONE .. "levitation.tga" },
        },
    },
    {
        id = "influences", label = "Influences", icone = ICONE .. "buff_debuff_mj.tga",
        entrees = {
            { id = "intimidation",    label = "Intimidation",     icone = ICONE .. "attaque_mj.tga" },
            { id = "provocation",     label = "Provocation",      icone = ICONE .. "offensives.tga" },
            { id = "illusion",        label = "Illusion",         icone = ICONE .. "permutation.tga" },
            { id = "peur",            label = "Peur",             icone = ICONE .. "generation_debuff.tga" },
            { id = "controle_mental", label = "Contrôle mental",  icone = ICONE .. "controles.tga" },
        },
    },
    -- Le second lanceur du template (« Action mj ») : une categorie reservee.
    {
        id = "animation", label = "Animation", icone = ICONE .. "animation.tga", mjSeulement = true,
        entrees = {
            -- « Résolution Test MJ » a quitté cette place le 2 octobre 2026.
            -- Elle etait fidele au template et ne servait a rien : elle se
            -- proposait l'epreuve a soi-meme, avec un paquet vide. Le vrai
            -- emetteur d'une epreuve de MJ, c'est « Dégât MJ ».
            { id = "degat_mj",           label = "Dégât MJ",           icone = ICONE .. "resolution_test_mj.tga" },
            { id = "buff_debuff_mj",     label = "Buff / Débuff MJ",   icone = ICONE .. "buff_debuff_mj.tga" },
            { id = "attaque_mj",         label = "Attaque MJ",         icone = ICONE .. "attaque_mj.tga" },
        },
    },
}

-- Verification au chargement : un eventail ne sait dessiner que 1 a 8 branches.
for _, categorie in ipairs(Radial.STRUCTURE) do
    local nombre = #(categorie.entrees or {})
    if nombre > Radial.MAX_ENTREES then
        error(string.format("radial : la categorie %s a %d entrees (maximum %d)",
            categorie.id, nombre, Radial.MAX_ENTREES))
    end
end

-- ===== Liaisons ============================================================

local function Trouver(id)
    id = tostring(id or "")
    for _, categorie in ipairs(Radial.STRUCTURE) do
        if categorie.id == id then return categorie end
        for _, entree in ipairs(categorie.entrees or {}) do
            if entree.id == id then return entree, categorie end
        end
    end
end
Radial.Trouver = Trouver

-- LCM.UI.Radial.Lier("fiche", function() ... end)
function Radial.Lier(id, onClick)
    local cible = Trouver(id)
    if not cible then
        LCM.Erreur(string.format("radial : entree inconnue « %s »", tostring(id)))
        return false
    end
    if type(onClick) ~= "function" then return false end
    cible.onClick = onClick
    return true
end

function Radial.EstLiee(id)
    local cible = Trouver(id)
    return cible ~= nil and type(cible.onClick) == "function"
end

-- Ce que le joueur a le droit de voir. Le MJ voit en plus ses outils.
function Radial.Categories()
    local out = {}
    for _, categorie in ipairs(Radial.STRUCTURE) do
        if (not categorie.mjSeulement) or LCM.IsMaster() then out[#out + 1] = categorie end
    end
    return out
end

function Radial.Entrees(categorieId)
    local categorie = Trouver(categorieId)
    local out = {}
    if not categorie then return out end
    -- Une categorie reservee au MJ ne laisse rien filtrer de son contenu.
    if categorie.mjSeulement and not LCM.IsMaster() then return out end
    -- Une categorie peut calculer son contenu (les sorts du personnage) plutot
    -- que le declarer. La structure du lanceur reste figee : c'est le contenu
    -- d'UNE case qui suit le personnage, pas le lanceur qui se reorganise.
    if type(categorie.contenu) == "function" then
        local ok, calcule = pcall(categorie.contenu)
        if not ok then
            LCM.Erreur(string.format("radial : « %s » : %s", tostring(categorie.label), tostring(calcule)))
            return out
        end
        -- Le plafond se tient ICI, pas dans chaque calcul : la verification au
        -- chargement ne voit que les entrees declarees, et un eventail de neuf
        -- branches n'existe pas.
        for i, entree in ipairs(calcule or {}) do
            if i > Radial.MAX_ENTREES then break end
            out[i] = entree
        end
        return out
    end
    for _, entree in ipairs(categorie.entrees or {}) do
        if (not entree.mjSeulement) or LCM.IsMaster() then out[#out + 1] = entree end
    end
    return out
end

-- ===== Animation ===========================================================
-- Un seul cadre d'animation pour tout le lanceur : aucun minuteur ne peut
-- terminer une fermeture devenue obsolete apres une reouverture rapide.

local transitions = {}
local animateur = CreateFrame("Frame")

local function Arreter(cible)
    transitions[cible] = nil
    if not next(transitions) then animateur:SetScript("OnUpdate", nil) end
end

local function Battement(_, ecoule)
    -- Les callbacks peuvent masquer des cadres ou annuler d'autres mouvements :
    -- on fige la liste avant de les appeler.
    local en_cours = {}
    for cible, mouvement in pairs(transitions) do
        en_cours[#en_cours + 1] = { cible, mouvement }
    end
    -- Chaque mouvement est protege : une erreur dans l'un s'arretait a chaque
    -- image au meme endroit, et ceux qui le suivaient dans la boucle ne
    -- finissaient jamais — dont la fin d'un repli, seule a lever le verrou des
    -- dossiers (constate le 21 octobre 2026 : « Système » retenu, plus rien ne
    -- s'ouvrait). Celui qui echoue est retire, et on le dit.
    for _, entree in ipairs(en_cours) do
        local cible, mouvement = entree[1], entree[2]
        if transitions[cible] == mouvement then
            mouvement.temps = mouvement.temps + ecoule
            if mouvement.temps >= 0 then
                local t = math.min(1, mouvement.temps / mouvement.duree)
                local ok, erreur = pcall(mouvement.pas, 1 - (1 - t) ^ 3)
                if not ok then LCM.Erreur("menu (animation) : " .. tostring(erreur)) end
                -- Un mouvement qui a echoue se termine quand meme : sa fin
                -- remet l'etat d'aplomb (le verrou du repli, l'orbite cachee).
                if (not ok or t == 1) and transitions[cible] == mouvement then
                    transitions[cible] = nil
                    if mouvement.fin then
                        ok, erreur = pcall(mouvement.fin)
                        if not ok then LCM.Erreur("menu (fin d'animation) : " .. tostring(erreur)) end
                    end
                end
            end
        end
    end
    if not next(transitions) then animateur:SetScript("OnUpdate", nil) end
end

local function Mouvement(cible, duree, delai, pas, fin)
    Arreter(cible)
    -- Le premier pas, protege comme les suivants (voir Battement) : il plantait
    -- dans le clic lui-meme, avant que le repli ait pu poser sa fin.
    local ok, erreur = pcall(pas, 0)
    if not ok then
        LCM.Erreur("menu (animation) : " .. tostring(erreur))
        if fin then
            ok, erreur = pcall(fin)
            if not ok then LCM.Erreur("menu (fin d'animation) : " .. tostring(erreur)) end
        end
        return
    end
    transitions[cible] = { temps = -(delai or 0), duree = duree, pas = pas, fin = fin }
    animateur:SetScript("OnUpdate", Battement)
end

-- Le bouton sort du centre en tournant : c'est ce mouvement-la qui fait le
-- caractere du menu de Necronicon, on le garde tel quel.
local TOURNIS = 0.95

local function Deployer(bouton, centre, x, y, departX, departY, delai)
    local dx, dy = x - departX, y - departY
    local rayon, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
    Mouvement(bouton, 0.34, delai, function(t)
        local a = angle - (1 - t) * TOURNIS
        bouton:SetAlpha(t)
        bouton:ClearAllPoints()
        bouton:SetPoint("CENTER", centre, "CENTER",
            departX + math.cos(a) * rayon * t, departY + math.sin(a) * rayon * t)
    end)
end

local function Replier(bouton, centre, x, y, arriveeX, arriveeY, delai, fin)
    local dx, dy = x - arriveeX, y - arriveeY
    local rayon, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
    Mouvement(bouton, 0.3, delai, function(t)
        local u = 1 - t
        local a = angle - (1 - u) * TOURNIS
        bouton:SetAlpha(u)
        bouton:ClearAllPoints()
        bouton:SetPoint("CENTER", centre, "CENTER",
            arriveeX + math.cos(a) * rayon * u, arriveeY + math.sin(a) * rayon * u)
    end, fin)
end

-- ===== Habillage ===========================================================

local function Surface(parent, nom, taille, couche)
    local t = parent:CreateTexture(nil, couche or "BACKGROUND")
    t:SetTexture(ART .. nom .. ".tga")
    t:SetPoint("CENTER", parent, "CENTER")
    t:SetSize(taille, taille)
    return t
end

-- Une ambiance permanente, independante des transitions d'ouverture.
-- Les textures sont creees une seule fois ; OnUpdate dort quand le sceau
-- (ou son parent) est masque. Aucun cadre supplementaire ne capte la souris.
local function ConstruireLivre(f)
    local livre = { ouverture = 0, temps = 0, images = {}, sceaux = {} }
    f.livre = livre
    -- Poses successives de la couverture puis d'une feuille autour du dos.
    -- Images prechargees, dimensions fixes : aucune deformation des pages.
    for i = 1, 7 do
        local pose = f.sceau:CreateTexture(nil, "ARTWORK", nil, 1)
        pose:SetTexture(ART .. (i == 7 and "grimoire-ouvert-v2.tga" or
            "grimoire-animation-" .. i .. ".tga"))
        pose:SetPoint("CENTER", f.sceau, "CENTER")
        pose:SetSize(Radial.LIVRE_LARGEUR, 64)
        pose:SetAlpha(0)
        livre.images[i] = pose
    end
    -- Seul le sceau gauche scintille ; la rune droite est en encre noire.
    do
        local sceau = f.sceau:CreateTexture(nil, "ARTWORK", nil, 2)
        sceau:SetTexture(SIGIL)
        sceau:SetBlendMode("ADD")
        sceau:SetVertexColor(0.72, 0.24, 1)
        sceau:SetAlpha(0)
        livre.sceaux[1] = sceau
    end
    livre.etincelles = {}
    for i = 1, 3 do
        local point = f.sceau:CreateTexture(nil, "OVERLAY")
        point:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        point:SetBlendMode("ADD")
        point:SetVertexColor(0.85, 0.48, 1)
        point:SetSize(1.2, 1.2)
        point:SetAlpha(0)
        livre.etincelles[i] = point
    end
    f.sceau.icone:ClearAllPoints()
    f.sceau.icone:SetPoint("CENTER", f.sceau, "CENTER")
    f.sceau.icone:SetSize(Radial.SCEAU - 6, Radial.SCEAU - 6)
end

local function ActualiserLivre(f, ecoule)
    local livre = f.livre
    -- La cible suffit : un clic rapide inverse le mouvement en cours sans saut.
    local cible = f.ouvert and 1 or 0
    local pas = ecoule / 0.85
    if livre.ouverture < cible then
        livre.ouverture = math.min(cible, livre.ouverture + pas)
    elseif livre.ouverture > cible then
        livre.ouverture = math.max(cible, livre.ouverture - pas)
    end
    local t = livre.ouverture
    livre.temps = (livre.temps + ecoule) % (20 * math.pi)
    local temps = livre.temps
    local index = math.min(7, math.floor(t * 8))
    if index ~= livre.index then
        f.sceau.icone:SetAlpha(index == 0 and 0.9 or 0)
        for i, pose in ipairs(livre.images) do pose:SetAlpha(i == index and 1 or 0) end
        livre.index = index
    end
    local magie = math.max(0, (t - 0.9) / 0.1)
    for i, sceau in ipairs(livre.sceaux) do
        local pulse = 0.5 + 0.5 * math.sin(temps * 2 + (i - 1) * math.pi)
        sceau:SetPoint("CENTER", f.sceau, "CENTER", -15.2, -7)
        sceau:SetSize(12 + pulse, 12 + pulse)
        sceau:SetAlpha(magie * (0.3 + 0.3 * pulse))
    end
    for i, point in ipairs(livre.etincelles) do
        local a = i * 2.399963 + temps * 0.5
        point:SetPoint("CENTER", f.sceau, "CENTER",
            -15.2 + math.cos(a) * 5, -7 + math.sin(a) * 5)
        point:SetAlpha(magie * 0.8 * math.max(0, math.sin(temps * 3 + i * 2)) ^ 6)
    end
end

local nombreMagies = 0
local function HabillerMagie(b, taille)
    nombreMagies = nombreMagies + 1
    local magie = { phase = nombreMagies * 1.7, points = {} }
    b.magie = magie
    -- Le fond noir de l'icone reste intact ; seules les gravures dorees vivent.
    magie.runes = Surface(b, "sigil", taille * 1.13, "OVERLAY")
    magie.runes:SetVertexColor(0.90, 0.72, 0.42)
    magie.runes:SetBlendMode("ADD")
    magie.runes:SetAlpha(0.08)
    for i = 1, 3 do
        local point = b:CreateTexture(nil, "OVERLAY")
        point:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        point:SetBlendMode("ADD")
        point:SetVertexColor(1, 0.78, 0.48)
        point:SetSize(1.5, 1.5)
        local angle = (i - 1) * math.pi * 2 / 3 + magie.phase
        point:SetPoint("CENTER", b, "CENTER",
            math.cos(angle) * taille * 0.47, math.sin(angle) * taille * 0.47)
        point:SetAlpha(0)
        magie.points[i] = point
    end
end

local function ActualiserMagie(b, temps)
    local magie = b.magie
    if not magie or not b:IsShown() then return end
    local phase = temps + magie.phase
    local pulse = 0.5 + 0.5 * math.sin(phase)
    local intensite = b.disponible == false and 0.22 or (b.survole and 1.5 or (b.choisi and 1.25 or 1))
    magie.runes:SetAlpha((0.06 + 0.04 * pulse) * intensite)
    -- Un tour en 48 secondes ; les points restent fixes sur le pourtour.
    magie.runes:SetRotation(temps * 0.1 + magie.phase)
    for i, point in ipairs(magie.points) do
        point:SetAlpha(math.max(0, math.sin(phase + i * 2)) ^ 10 * 0.65 * intensite)
    end
end

local function AnimerSceau(f)
    local tour = 2 * math.pi
    local angle = 0
    local tempsMagie = 0
    local particules = {}
    for i = 1, 14 do
        local texture = f.sceau:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        texture:SetBlendMode("ADD")
        texture:SetVertexColor(0.72, 0.25, 1)
        local taille = 0.8 + (i % 4) * 0.3
        texture:SetSize(taille, taille)
        texture:SetAlpha(0)
        particules[i] = {
            texture = texture,
            phase = (i - 1) / 14,
            duree = 2.8 + (i % 5) * 0.43,
            angle = i * 2.399963,
            rayon = Radial.SCEAU * (0.60 + (i % 4) * 0.035),
        }
    end

    local function Actualiser(_, ecoule)
        ActualiserLivre(f, ecoule)
        tempsMagie = (tempsMagie + ecoule * (2 * math.pi / 4.8)) % (20 * math.pi)
        for _, c in ipairs(f.couronnes) do
            if c.orbite:IsShown() then
                for _, b in ipairs(c.boutonsCategorie) do ActualiserMagie(b, tempsMagie) end
                for _, b in ipairs(c.boutonsEntree) do ActualiserMagie(b, tempsMagie) end
            end
        end
        -- SetRotation utilise les radians positifs dans le sens antihoraire.
        angle = (angle + ecoule * tour / 48) % tour
        f.sigil:SetRotation(angle)
        for _, p in ipairs(particules) do
            p.phase = (p.phase + ecoule / p.duree) % 1
            local vie = p.phase
            local a = p.angle + angle + vie * 0.48
            local rayon = p.rayon + vie * 7
            p.texture:SetPoint("CENTER", f.sceau, "CENTER",
                math.cos(a) * rayon, math.sin(a) * rayon + vie * 4)
            p.texture:SetAlpha(0.55 * math.sin(math.pi * vie) ^ 2)
        end
    end
    Actualiser(f.sceau, 0)
    f.sceau:SetScript("OnUpdate", Actualiser)
end

local function Rond(bouton, taille)
    -- Le masque arrondit l'icone carree ; sans lui, des vignettes carrees dans
    -- un menu circulaire, ca se voit tout de suite.
    if not bouton.CreateMaskTexture then return end
    local masque = bouton:CreateMaskTexture()
    masque:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    masque:SetAllPoints(bouton.icone)
    if bouton.icone.AddMaskTexture then bouton.icone:AddMaskTexture(masque) end
    bouton.masque = masque
end

local function Halo(bouton, taille)
    local halo = CreateFrame("Frame", nil, bouton)
    halo:SetAllPoints()
    halo:EnableMouse(false)
    Surface(halo, "glow", taille * 64 / 48, "OVERLAY")
    halo:SetAlpha(0)
    bouton.halo = halo
    bouton:HookScript("OnHide", function(self)
        Arreter(self.halo)
        self.halo:SetAlpha(0)
        self.survole = false
    end)
end

local function Eclairer(bouton, choisi, survole)
    bouton.choisi, bouton.survole = choisi, survole
    local vise = survole and 1 or (choisi and 0.78 or 0)
    local depuis = bouton.halo:GetAlpha()
    Mouvement(bouton.halo, 0.12, 0, function(t)
        bouton.halo:SetAlpha(depuis + (vise - depuis) * t)
    end)
    if bouton.legende then
        local couleur = (choisi or survole) and UI.C.titre or UI.C.discret
        bouton.legende:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
end

local function Bulle(bouton, titre, detail)
    bouton:SetScript("OnEnter", function(self)
        Eclairer(self, self.choisi, true)
        if self.legende then self.legende:Show() end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titre, UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        local texte = type(detail) == "function" and detail() or detail
        if texte then GameTooltip:AddLine(texte, 0.7, 0.68, 0.62, true) end
        GameTooltip:Show()
    end)
    bouton:SetScript("OnLeave", function(self)
        Eclairer(self, self.choisi, false)
        if self.legende and self.legendeAuSurvol then self.legende:Hide() end
        if GameTooltip then GameTooltip:Hide() end
    end)
end

-- `niveau` : le niveau d'affichage du bouton, pose AVANT ses enfants (le
-- halo) pour qu'ils le suivent.
local function Vignette(parent, taille, legendeAuSurvol, magique, niveau)
    local b = CreateFrame("Button", nil, parent)
    if niveau then b:SetFrameLevel(niveau) end
    b:SetSize(taille, taille)
    Surface(b, "button", taille * 64 / 48)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", 3, -3)
    b.icone:SetPoint("BOTTOMRIGHT", -3, 3)
    Rond(b, taille)
    if magique then HabillerMagie(b, taille) end
    b.legende = UI.Texte(b, "", UI.C.discret, "GameFontNormalSmall")
    b.legende:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.legende:SetJustifyH("CENTER")
    b.legendeAuSurvol = legendeAuSurvol and true or false
    if legendeAuSurvol then b.legende:Hide() end
    Halo(b, taille)

    -- Notification posee SUR le coin haut gauche de l'icone. Le contenu est
    -- fourni par le noeud du menu (par exemple les niveaux en attente), ce qui
    -- permet aux boutons recycles de l'effacer proprement.
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(18, 18)
    b.badge:SetPoint("CENTER", b, "TOPLEFT", 5, -5)
    b.badge:SetFrameLevel(b:GetFrameLevel() + 8)
    b.badge.fond = UI.Aplat(b.badge, { 0.32, 0.03, 0.02, 0.98 }, "OVERLAY")
    b.badge.fond:SetAllPoints(b.badge)
    UI.Bordure(b.badge, { 0.95, 0.68, 0.20, 1 })
    b.badge.texte = UI.Texte(b.badge, "", UI.C.titre, "GameFontNormalSmall")
    b.badge.texte:SetAllPoints(b.badge)
    b.badge.texte:SetJustifyH("CENTER")
    b.badge:Hide()
    return b
end

local function ActualiserBadge(bouton, cible)
    local nombre = 0
    if cible and type(cible.badge) == "function" then
        local ok, valeur = pcall(cible.badge)
        if ok then nombre = math.max(0, math.floor(tonumber(valeur) or 0)) end
    end
    bouton.badge.texte:SetText(tostring(nombre))
    bouton.badge:SetShown(nombre > 0)
end

-- ===== Les deux couronnes ==================================================
-- Le sceau porte deux menus, dessines de la meme facon (categories en
-- couronne, entrees en eventail) : les FENETRES au clic gauche (la structure
-- de UI/Menu.lua, qui n'a plus de bouton a elle depuis le 3 octobre 2026) et
-- les ACTIONS au clic droit (la structure ci-dessus). Les deux entourent le
-- sceau, une seule a la fois : ouvrir l'une referme l'autre. (Du 3 octobre
-- 2026, quelques heures : les deux pouvaient etre ouvertes cote a cote, et se
-- replacaient pres des bords. Abandonne : une seule suffit, et c'est plus
-- simple a lire.)

Radial.COURONNES = {
    {
        id = "fenetres", label = "Fenêtres", nom = "LCM_RadialFenetres",
        Categories = function() return UI.Menu.Visibles() end,
        -- Un dossier s'ouvre en eventail ; une fenetre seule s'ouvre au clic.
        Entrees = function(categorie)
            local out = {}
            for i, noeud in ipairs(categorie.enfants and UI.Menu.Visibles(categorie.enfants) or {}) do
                if i > Radial.MAX_ENTREES then break end
                out[i] = noeud
            end
            return out
        end,
    },
    {
        id = "actions", label = "Actions", nom = "LCM_RadialOrbite",
        Categories = function() return Radial.Categories() end,
        Entrees = function(categorie) return Radial.Entrees(categorie.id) end,
    },
}

-- ===== Le lanceur ==========================================================

local function Fond(c, t)
    c.fond:SetAlpha(t)
    local phase, echelle = -(1 - t) * TOURNIS, 0.65 + 0.35 * t
    if c.fond.surface.SetSize then
        c.fond.surface:SetSize(Radial.FOND * echelle, Radial.FOND * echelle)
    end
    if c.fond.surface.SetRotation then c.fond.surface:SetRotation(phase) end
end

local function Eventail(c, angle, nombre, avancement)
    c.secteur.surface:SetTexture(ART .. "grimoire-fan-" .. nombre .. ".tga")
    if c.secteur.surface.SetRotation then
        c.secteur.surface:SetRotation(angle - math.pi / 2)
    end
    local taille = Radial.FOND * (0.94 + 0.06 * (avancement or 1))
    c.secteur.surface:SetSize(taille, taille)
    c.secteur:Show()
end

-- Le livre du sceau s'ouvre tant qu'une couronne est ouverte.
local function Etat(f)
    f.ouvert = false
    for _, c in ipairs(f.couronnes) do
        if c.ouvert then f.ouvert = true end
    end
end

-- Poussiere entre deux niveaux : petits grains carres, trajectoires souples,
-- emission continue. Un cadre reutilise par lien, sous les deux bandeaux.
local function LienPourpre(c, proprietaire, x1, y1, x2, y2, nombre, angleCentre)
    local lien = proprietaire.lienPourpre
    if not lien then
        lien = CreateFrame("Frame", nil, c.orbite)
        lien:SetAllPoints(c.orbite)
        lien:SetFrameLevel(c.fond:GetFrameLevel())
        lien:EnableMouse(false)
        lien.grains = {}
        for i = 1, Radial.MAX_ENTREES * 12 do
            local grain = lien:CreateTexture(nil, "ARTWORK")
            grain:SetColorTexture(0.72 + (i % 3) * 0.08, 0.12, 1, 1)
            grain:SetBlendMode("ADD")
            local taille = 0.8 + (i % 4) * 0.45
            grain:SetSize(taille, taille)
            local halo = lien:CreateTexture(nil, "BACKGROUND")
            halo:SetTexture(ART .. "glow.tga")
            halo:SetBlendMode("ADD")
            halo:SetVertexColor(0.55, 0.08, 0.95)
            halo:SetSize(taille * 5, taille * 5)
            halo:SetPoint("CENTER", grain, "CENTER")
            lien.grains[i] = { texture = grain, halo = halo, phase = ((i - 1) * 0.61803398875) % 1,
                duree = 1.1 + (i % 5) * 0.17, graine = i * 2.399963 }
        end
        lien:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
        proprietaire.lienPourpre = lien
    end
    local dx, dy = x2 - x1, y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 1 then lien:Hide(); return end
    lien.departX, lien.departY, lien.arriveeX, lien.arriveeY = x1, y1, x2, y2
    nombre = math.max(1, math.min(Radial.MAX_ENTREES, nombre or 1))
    lien.nombreCibles = nombre
    lien.nombreGrains = nombre * 12
    lien.cibles = {}
    local ox = x2 - math.cos(angleCentre) * Radial.RAYON_ACTION
    local oy = y2 - math.sin(angleCentre) * Radial.RAYON_ACTION
    -- Une destination par icone, avec le meme pas angulaire que l'eventail.
    -- Les douze grains par branche gardent une densite stable de 1 a 9 icones.
    for i = 1, nombre do
        local angle = angleCentre + (i - (nombre + 1) / 2) * math.pi / 8.75
        lien.cibles[i] = { x = ox + math.cos(angle) * Radial.RAYON_ACTION,
            y = oy + math.sin(angle) * Radial.RAYON_ACTION }
    end
    for i, p in ipairs(lien.grains) do
        local actif = i <= lien.nombreGrains
        p.texture:SetShown(actif); p.halo:SetShown(actif)
        if actif then
            local cible = lien.cibles[1 + (i - 1) % nombre]
            p.dx, p.dy = cible.x - x1, cible.y - y1
            local longueur = math.max(1, math.sqrt(p.dx * p.dx + p.dy * p.dy))
            p.nx, p.ny = -p.dy / longueur, p.dx / longueur
        end
    end
    -- Le depart est cache sous le cercle du parent ; l'arrivee sous le cuir.
    -- Le jet s'evase et ondule sans tracer une ligne droite opaque.
    lien.temps = lien:IsShown() and (lien.temps or 0) or 0
    local function Actualiser(self, dt)
        self.temps = self.temps + dt
        for i = 1, self.nombreGrains do
            local p = self.grains[i]
            p.phase = (p.phase + dt / p.duree) % 1
            local t = p.phase
            local largeur = 1.5 + t * 6
            local derive = math.sin(p.graine + t * 5 + self.temps * 1.3) * largeur
            local x = x1 + p.dx * t + p.nx * derive
            local y = y1 + p.dy * t + p.ny * derive
            p.texture:SetPoint("CENTER", self, "CENTER", x, y)
            local alpha = math.sin(math.pi * t) * (0.45 + 0.35 * math.sin(p.graine + self.temps * 3)^2)
            alpha = alpha * math.min(1, self.temps / 0.3)
            p.texture:SetAlpha(alpha)
            p.halo:SetAlpha(alpha * 0.22)
        end
    end
    lien:SetScript("OnUpdate", Actualiser)
    Actualiser(lien, 0)
    lien:Show()
end

local Dessiner

local function MasquerSousMenu(c)
    local s = c.sousMenu
    if not s then return end
    if s.lienPourpre then s.lienPourpre:Hide() end
    Arreter(s.secteur)
    for _, b in ipairs(s.boutonsEntree) do Arreter(b) b:Hide() end
    s.orbite:Hide()
    s.nombreEntrees = 0
end

-- Replie les entrees vers leur categorie, puis appelle `apres`.
local function ReplierEntrees(f, c, apres)
    if c.lienPourpre then c.lienPourpre:Hide() end
    MasquerSousMenu(c)
    local une = false
    for i, b in ipairs(c.boutonsEntree) do
        if b:IsShown() then
            une = true
            Replier(b, c.orbite, b.rx, b.ry, c.choisiX or 0, c.choisiY or 0, (i - 1) * 0.012,
                function() b:Hide() end)
        end
    end
    if not une then if apres then apres() end return end
    c.replie = true
    -- Le repli dure 0,3 s ; au-dela d'une seconde, le verrou ne vaut plus
    -- rien (voir Verrouille).
    c.replieJusqua = (GetTime and GetTime() or 0) + 1
    Mouvement(c.secteur, 0.3, 0, function(t) c.secteur:SetAlpha(1 - t) end, function()
        c.replie = nil
        c.secteur:Hide()
        if apres then apres() end
    end)
end

-- Le repli est-il en cours ? Un verrou dont l'echeance est passee ne refuse
-- plus rien : quoi qu'il ait interrompu la fin du repli, le menu ne reste
-- jamais bloque sur un dossier jusqu'a la fermeture du sceau.
local function Verrouille(c)
    if not c.replie then return false end
    if (GetTime and GetTime() or 0) <= (c.replieJusqua or 0) then return true end
    c.replie = nil
    return false
end

local function Fermer(f, c, anime)
    if c.lienPourpre then c.lienPourpre:Hide() end
    Arreter(c.orbite) Arreter(c.fond) Arreter(c.secteur)
    for _, liste in ipairs({ c.boutonsCategorie, c.boutonsEntree }) do
        for _, b in ipairs(liste) do Arreter(b) end
    end
    local choisiX, choisiY = c.choisiX, c.choisiY
    c.ouvert, c.choisi, c.replie = false, nil, nil
    c.sousChoisi = nil
    MasquerSousMenu(c)
    Etat(f)
    if not anime or not c.orbite:IsShown() then
        c.orbite:Hide()
        c.orbite:SetAlpha(1)
        Fond(c, 1)
        return
    end
    -- Les entrees rentrent dans leur categorie, les categories rentrent au
    -- centre, le fond se replie en meme temps.
    local attente = 0
    for i, b in ipairs(c.boutonsEntree) do
        if b:IsShown() then
            Replier(b, c.orbite, b.rx, b.ry, choisiX or 0, choisiY or 0, (i - 1) * 0.012,
                function() b:Hide() end)
            attente = 0.12
        end
    end
    if c.secteur:IsShown() then
        Mouvement(c.secteur, 0.25, 0, function(t) c.secteur:SetAlpha(1 - t) end,
            function() c.secteur:Hide() end)
    end
    for i, b in ipairs(c.boutonsCategorie) do
        if b:IsShown() then
            Replier(b, c.orbite, b.rx, b.ry, 0, 0, attente + (i - 1) * 0.02)
        end
    end
    Mouvement(c.fond, 0.32, attente + 0.05, function(t) Fond(c, 1 - t) end)
    Mouvement(c.orbite, 0.42 + attente, 0, function() end, function()
        c.orbite:Hide()
        c.orbite:SetAlpha(1)
        Fond(c, 1)
    end)
end

local function FermerTout(f, anime)
    for _, c in ipairs(f.couronnes) do
        if c.ouvert or c.orbite:IsShown() then Fermer(f, c, anime) end
    end
end

local function Basculer(f, c)
    if c.ouvert then
        Fermer(f, c, true)
        return
    end
    -- Une seule a la fois : l'autre se replie pendant que celle-ci se deploie.
    for _, autre in ipairs(f.couronnes) do
        if autre ~= c and autre.ouvert then Fermer(f, autre, true) end
    end
    c.ouvert, c.choisi = true, nil
    c.sousChoisi = nil
    Etat(f)
    Dessiner(f, c, true, false)
end

function Radial.EstKO()
    local entity = LCM.Entities and LCM.Entities.Self and LCM.Entities.Self()
    return entity ~= nil and LCM.Body and LCM.Body.Inconscient
        and LCM.Body.Inconscient(entity) or false
end

local function RefuserSiKO(c)
    if c.id ~= "actions" or not Radial.EstKO() then return false end
    LCM.Erreur("Vous êtes KO !")
    return true
end

local function Lancer(f, c, cible)
    if RefuserSiKO(c) then return end
    if type(cible.onClick) == "function" then
        -- La couronne RESTE ouverte. Elle se refermait a chaque clic, et il
        -- fallait rouvrir le sceau puis redescendre dans la categorie pour
        -- regarder une deuxieme feuille — alors qu'on en consulte rarement une
        -- seule. On la ferme au sceau, ou par Radial.Fermer().
        local ok, err = pcall(cible.onClick)
        if not ok then LCM.Erreur(string.format("%s : %s", tostring(cible.label), tostring(err))) end
        return
    end
    LCM.Alerte(string.format("%s : pas encore disponible.", tostring(cible.label)))
end

-- Un anneau exterieur concentrique, centre sur la direction du bouton parent.
local function DessinerSousMenu(f, c, parent, anime)
    local s = c.sousMenu
    if not s then
        s = { boutonsEntree = {} }
        c.sousMenu = s
        s.orbite = CreateFrame("Frame", nil, c.orbite)
        s.orbite:SetSize(Radial.SCEAU, Radial.SCEAU)
        s.secteur = CreateFrame("Frame", nil, s.orbite)
        -- Sous le bandeau du premier eventail : il en depasse, il ne le couvre pas.
        s.secteur:SetFrameLevel(c.niveauBoutons - 2)
        s.secteur:SetAllPoints(s.orbite)
        s.secteur:EnableMouse(false)
        s.secteur.surface = Surface(s.secteur, "grimoire-fan-3", Radial.FOND)
    end
    local rayon = Radial.RAYON_ACTION
    local entrees = c.def.Entrees(parent.cible)
    local angleCentre = parent.angle
    -- Le meme eventail que le premier, decale vers l'exterieur dans la
    -- direction du bouton parent : un espace les separe, sans rien agrandir.
    local decalage = Radial.DecalageSousMenu(#entrees)
    local ox, oy = math.cos(angleCentre) * decalage, math.sin(angleCentre) * decalage
    s.orbite:ClearAllPoints()
    s.orbite:SetPoint("CENTER", c.orbite, "CENTER", ox, oy)
    s.orbite:Show()
    Eventail(s, angleCentre, #entrees)
    LienPourpre(c, s, parent.rx, parent.ry,
        ox + math.cos(angleCentre) * Radial.RAYON_ACTION,
        oy + math.sin(angleCentre) * Radial.RAYON_ACTION, #entrees, angleCentre)
    s.secteur:SetAlpha(1)
    if anime then
        Mouvement(s.secteur, 0.24, 0, function(t) s.secteur:SetAlpha(t) end)
    end
    for i, entree in ipairs(entrees) do
        local b = s.boutonsEntree[i]
        if not b then
            b = Vignette(s.orbite, Radial.ACTION, true, true, c.niveauBoutons)
            s.boutonsEntree[i] = b
        end
        -- Lecture de gauche a droite, sur l'arc inferieur.
        local angle = angleCentre + (i - (#entrees + 1) / 2) * math.pi / 8.75
        b.rx, b.ry = math.cos(angle) * rayon, math.sin(angle) * rayon
        b.cible = entree
        b:ClearAllPoints()
        b:SetPoint("CENTER", s.orbite, "CENTER", b.rx, b.ry)
        b:SetAlpha(1)
        b.icone:SetTexture(entree.icone)
        b.legende:SetText(entree.label)
        b.disponible = type(entree.onClick) == "function"
        local teinte = b.disponible and 1 or 0.42
        b.icone:SetVertexColor(teinte, teinte, teinte)
        ActualiserBadge(b, entree)
        Bulle(b, entree.label, b.disponible and "Clic : ouvrir." or "Pas encore disponible.")
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton) Lancer(f, c, bouton.cible) end)
        b:Show()
        -- Les boutons partent du parent, exprime dans le repere decale.
        if anime then Deployer(b, s.orbite, b.rx, b.ry, parent.rx - ox, parent.ry - oy, (i - 1) * 0.025) end
    end
    s.nombreEntrees = #entrees
end

Dessiner = function(f, c, animeCategories, animeEntrees, animeSousMenu)
    MasquerSousMenu(c)
    Arreter(c.orbite) Arreter(c.fond) Arreter(c.secteur)
    -- Arreter le bandeau annule aussi la fin d'un repli en cours, seule a
    -- lever ce verrou. Laisse pose, il refusait ensuite tout dossier jusqu'a
    -- la fermeture du sceau (constate le 20 octobre 2026 : un Rafraichir
    -- tombe pendant le repli, et plus rien ne se deployait). Ce dessin-ci
    -- remplace le repli : il montre deja la categorie retenue.
    c.replie = nil
    c.orbite:SetAlpha(1)
    for _, b in ipairs(c.boutonsCategorie) do Arreter(b) b:SetAlpha(1) b:Hide() end
    for _, b in ipairs(c.boutonsEntree) do Arreter(b) b:SetAlpha(1) b:Hide() end
    c.secteur:Hide()
    if not c.ouvert then c.orbite:Hide() return end
    c.orbite:Show()
    if animeCategories then
        Mouvement(c.fond, 0.4, 0, function(t) Fond(c, t) end)
    else
        Fond(c, 1)
    end

    local categories = c.def.Categories()
    local inconscient = c.id == "actions" and Radial.EstKO()
    local choisie, angleChoisi
    for i, categorie in ipairs(categories) do
        local b = c.boutonsCategorie[i]
        if not b then
            b = Vignette(c.orbite, Radial.CATEGORIE, false, true, c.niveauBoutons)
            c.boutonsCategorie[i] = b
        end
        -- Premiere categorie en haut, puis dans le sens horaire.
        local angle = math.pi / 2 - (i - 1) * 2 * math.pi / #categories
        b.rx, b.ry = math.cos(angle) * Radial.RAYON_CATEGORIE, math.sin(angle) * Radial.RAYON_CATEGORIE
        b.cible = categorie
        b:ClearAllPoints()
        b:SetPoint("CENTER", c.orbite, "CENTER", b.rx, b.ry)
        b.icone:SetTexture(categorie.icone)
        b.legende:SetText(categorie.label)
        ActualiserBadge(b, categorie)
        b.choisi = (c.choisi == categorie.id)
        -- Une categorie qui s'ouvre directement (une fenetre seule) et que
        -- rien ne branche reste eteinte, comme une entree.
        local direct = categorie.direct or #c.def.Entrees(categorie) == 0
        local prete = not direct or type(categorie.onClick) == "function"
        b.disponible = prete
        local teinte = (not prete and 0.42) or (b.choisi and 1) or 0.95
        if inconscient then
            b.icone:SetVertexColor(prete and 1 or 0.48, prete and 0.14 or 0.06, prete and 0.14 or 0.06)
        else
            b.icone:SetVertexColor(teinte, teinte, teinte)
        end
        Bulle(b, categorie.label, inconscient and "Vous êtes KO !" or (not prete and "Pas encore disponible.")
            or (direct and "Clic : ouvrir.") or "Clic : déployer.")
        Eclairer(b, b.choisi, false)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton)
            if RefuserSiKO(c) then return end
            local cat = bouton.cible
            if cat.direct or #c.def.Entrees(cat) == 0 then
                Lancer(f, c, cat)
                return
            end
            local dansSousMenu = c.sousChoisi ~= nil
            c.choisi = (c.choisi ~= cat.id or dansSousMenu) and cat.id or nil
            c.sousChoisi = nil
            -- Un clic pendant le repli : le choix est memorise, le dessin qui
            -- suit la fin du repli l'utilisera.
            if Verrouille(c) then return end
            ReplierEntrees(f, c, function() if c.ouvert then Dessiner(f, c, false, true) end end)
        end)
        b:Show()
        if animeCategories then Deployer(b, c.orbite, b.rx, b.ry, 0, 0, (i - 1) * 0.025) end
        if c.choisi == categorie.id then choisie, angleChoisi = categorie, angle end
    end
    for i = #categories + 1, #c.boutonsCategorie do c.boutonsCategorie[i]:Hide() end
    c.nombreCategories = #categories

    if not choisie then
        if c.lienPourpre then c.lienPourpre:Hide() end
        c.choisiX, c.choisiY = nil, nil
        c.nombreEntrees = 0
        return
    end

    local entrees = c.def.Entrees(choisie)
    local parentSousMenu
    c.choisiX = math.cos(angleChoisi) * Radial.RAYON_CATEGORIE
    c.choisiY = math.sin(angleChoisi) * Radial.RAYON_CATEGORIE
    LienPourpre(c, c, c.choisiX, c.choisiY,
        math.cos(angleChoisi) * Radial.RAYON_ACTION,
        math.sin(angleChoisi) * Radial.RAYON_ACTION, #entrees, angleChoisi)
    if animeEntrees then
        Mouvement(c.secteur, 0.4, 0, function(t)
            Eventail(c, angleChoisi - (1 - t) * TOURNIS, #entrees, t)
            c.secteur:SetAlpha(t)
        end)
    else
        Eventail(c, angleChoisi, #entrees)
        c.secteur:SetAlpha(1)
    end

    for i, entree in ipairs(entrees) do
        local b = c.boutonsEntree[i]
        if not b then
            b = Vignette(c.orbite, Radial.ACTION, true, true, c.niveauBoutons)
            c.boutonsEntree[i] = b
        end
        -- Sens horaire : la premiere entree a gauche, la derniere a droite,
        -- comme on lit (Fiche ... Apprentissage).
        local angle = angleChoisi - (i - (#entrees + 1) / 2) * math.pi / 8.75
        b.rx, b.ry = math.cos(angle) * Radial.RAYON_ACTION, math.sin(angle) * Radial.RAYON_ACTION
        b.angle = angle
        b.cible = entree
        b:ClearAllPoints()
        b:SetPoint("CENTER", c.orbite, "CENTER", b.rx, b.ry)
        b:SetSize(Radial.ACTION, Radial.ACTION)
        b.icone:SetTexture(entree.icone)
        b.legende:SetText(entree.label)
        ActualiserBadge(b, entree)
        -- Une entree sans fenetre derriere elle reste visible mais eteinte : le
        -- menu ne ment pas sur ce qui existe.
        local sousMenu = entree.enfants and #c.def.Entrees(entree) > 0
        local prete = sousMenu or type(entree.onClick) == "function"
        b.disponible = prete
        local teinte = prete and 1 or 0.42
        if inconscient then
            b.icone:SetVertexColor(prete and 1 or 0.48, prete and 0.14 or 0.06, prete and 0.14 or 0.06)
        else
            b.icone:SetVertexColor(teinte, teinte, teinte)
        end
        Bulle(b, entree.label, inconscient and "Vous êtes KO !"
            or (sousMenu and (c.sousChoisi == entree.id and "Clic : replier le sous-menu." or "Clic : déployer le sous-menu."))
            or (prete and "Clic : ouvrir." or "Pas encore disponible."))
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton)
            local cible = bouton.cible
            if cible.enfants then
                if Verrouille(c) then return end
                c.sousChoisi = c.sousChoisi ~= cible.id and cible.id or nil
                Dessiner(f, c, false, false, true)
            else
                Lancer(f, c, cible)
            end
        end)
        b.choisi = sousMenu and c.sousChoisi == entree.id
        Eclairer(b, b.choisi, false)
        if b.choisi then parentSousMenu = b end
        b:Show()
        if animeEntrees then
            Deployer(b, c.orbite, b.rx, b.ry, c.choisiX, c.choisiY, (i - 1) * 0.018)
        end
    end
    for i = #entrees + 1, #c.boutonsEntree do c.boutonsEntree[i]:Hide() end
    c.nombreEntrees = #entrees
    if parentSousMenu then
        DessinerSousMenu(f, c, parentSousMenu, animeSousMenu)
    else
        c.sousChoisi = nil
    end
end

-- Une notification peut changer pendant que la couronne est ouverte (gain
-- d'XP, validation d'un niveau). On redessine alors sans animation.
function Radial.Rafraichir()
    local f = Radial.frame
    if not f then return end
    for _, c in ipairs(f.couronnes or {}) do
        if c.ouvert then Dessiner(f, c, false, false) end
    end
end

LCM.Entities.Ecouter(function(entity, fieldId)
    if (fieldId == "corps" or fieldId == "direct") and entity == LCM.Entities.Self() then
        Radial.Rafraichir()
    end
end)
LCM.Entities.EcouterSoi(function() Radial.Rafraichir() end)

local function ConstruireCouronne(f, def)
    local c = { def = def, id = def.id, boutonsCategorie = {}, boutonsEntree = {},
                ouvert = false }
    c.orbite = CreateFrame("Frame", def.nom, f)
    c.orbite:SetSize(Radial.SCEAU, Radial.SCEAU)
    c.orbite:SetPoint("CENTER", f, "CENTER", 0, 0)
    c.orbite:Hide()

    -- Les niveaux d'affichage sont poses a la main : fond, puis eventail, puis
    -- boutons. Laisses au jeu, l'eventail et les boutons tombaient au meme
    -- niveau, empiles dans un ordre arbitraire — le cuir de certains
    -- eventails passait alors SUR le cadre dore des boutons (dessine sous
    -- l'icone) : des icones avec cadre, d'autres sans (3 octobre 2026).
    local base = c.orbite:GetFrameLevel()
    c.niveauBoutons = base + 3
    c.fond = CreateFrame("Frame", nil, c.orbite)
    c.fond:SetFrameLevel(base)
    c.fond:SetAllPoints()
    c.fond:EnableMouse(false)
    c.fond.surface = Surface(c.fond, "background", Radial.FOND)

    -- base + 2 : le bandeau d'un sous-menu (base + 1) glisse DESSOUS celui-ci.
    c.secteur = CreateFrame("Frame", nil, c.orbite)
    c.secteur:SetFrameLevel(base + 2)
    c.secteur:SetAllPoints()
    c.secteur:EnableMouse(false)
    c.secteur.surface = Surface(c.secteur, "grimoire-fan-1", Radial.FOND)
    c.secteur:Hide()
    Fond(c, 1)

    -- Echap referme la couronne (UISpecialFrames).
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = def.nom end
    c.orbite:SetScript("OnHide", function()
        if c.lienPourpre then c.lienPourpre:Hide() end
        MasquerSousMenu(c)
        c.sousChoisi = nil
        Arreter(c.orbite) Arreter(c.fond) Arreter(c.secteur)
        for _, liste in ipairs({ c.boutonsCategorie, c.boutonsEntree }) do
            for _, b in ipairs(liste) do Arreter(b) end
        end
        c.ouvert, c.choisi = false, nil
        Etat(f)
    end)
    return c
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Radial", UIParent)
    f:SetSize(Radial.SCEAU, Radial.SCEAU)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)

    f.sceau = Vignette(f, Radial.SCEAU, false)
    f.sceau:SetAllPoints(f)
    f.sceau.icone:SetTexture(SCEAU)
    f.sceau.icone:SetAlpha(0.9)
    f.sceau.legende:Hide()
    f.sigil = f.sceau:CreateTexture(nil, "ARTWORK", nil, -1)
    f.sigil:SetTexture(SIGIL)
    f.sigil:SetPoint("CENTER", f.sceau, "CENTER")
    f.sigil:SetSize(Radial.SCEAU * 1.55, Radial.SCEAU * 1.55)
    f.sigil:SetAlpha(0.62)

    -- Les couronnes, dans l'ordre de Radial.COURONNES, et aussi rangees par
    -- identifiant.
    f.couronnes = {}
    for i, def in ipairs(Radial.COURONNES) do
        local c = ConstruireCouronne(f, def)
        f.couronnes[i], f.couronnes[def.id] = c, c
    end
    -- Le sceau passe devant les couronnes : il reste cliquable.
    local niveau = 0
    for _, c in ipairs(f.couronnes) do niveau = math.max(niveau, c.niveauBoutons) end
    f.sceau:SetFrameLevel(niveau + 3)
    ConstruireLivre(f)
    AnimerSceau(f)

    -- Glisser (clic gauche, sans Maj depuis le 2 octobre 2026) deplace le
    -- sceau ; sa place est retenue.
    --
    -- Le jeu envoie quand meme OnClick au relache d'un glisser fini sur le
    -- sceau : sans garde, chaque deplacement ouvrait le menu. `f.glisse` dit
    -- « ce clic-la est la fin d'un glisser ». Il est remis a zero a CHAQUE
    -- appui, et pas seulement par le clic qu'il avale : un glisser relache
    -- hors du sceau ne recoit pas d'OnClick, et le drapeau reste pose — il
    -- mangerait alors le vrai clic suivant.
    --
    -- Le glisser est fait a la main (3 octobre 2026), pas par StartMoving :
    -- le jeu n'envoie OnDragStart qu'apres quelques pixels, et un geste vif
    -- est deja sorti du sceau a ce moment-la. StartMoving gardait alors
    -- l'ecart pris, et le sceau suivait de loin ou decrochait. Ici, le point
    -- saisi est retenu a l'appui, et le sceau est repose dessous a chaque
    -- image tant que le bouton est tenu, ou que soit le curseur.
    local SEUIL = 4
    local glisseur = CreateFrame("Frame", nil, f)
    f.glisseur = glisseur

    local function Retenir()
        LCM.EnsureDatabase()
        LCM.db.settings.radial = type(LCM.db.settings.radial) == "table" and LCM.db.settings.radial or {}
        local x, y = f:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if x and cx then
            -- Le centre de l'ecran, ramene a l'echelle du sceau : c'est dans
            -- celle-la que Radial.Placer pose son decalage.
            local k = (UIParent:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
            LCM.db.settings.radial.x, LCM.db.settings.radial.y = x - cx * k, y - cy * k
        end
    end

    local function Lacher()
        glisseur:SetScript("OnUpdate", nil)
        if f.glisse then Retenir() end
    end

    f.sceau:SetScript("OnMouseDown", function(_, bouton)
        f.glisse = false
        if bouton ~= "LeftButton" then return end
        local echelle = f:GetEffectiveScale() or 1
        local cx, cy = GetCursorPosition()
        cx, cy = cx / echelle, cy / echelle
        local x, y = f:GetCenter()
        if not x then return end
        local ecartX, ecartY = x - cx, y - cy
        glisseur:SetScript("OnUpdate", function()
            local mx, my = GetCursorPosition()
            mx, my = mx / echelle, my / echelle
            if not f.glisse then
                -- Sous le seuil, c'est encore un clic.
                if math.abs(mx - cx) < SEUIL and math.abs(my - cy) < SEUIL then
                    if not IsMouseButtonDown("LeftButton") then glisseur:SetScript("OnUpdate", nil) end
                    return
                end
                f.glisse = true
            end
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mx + ecartX, my + ecartY)
            -- Relache hors du sceau : il ne recoit pas OnMouseUp, on le voit ici.
            if not IsMouseButtonDown("LeftButton") then Lacher() end
        end)
    end)
    f.sceau:SetScript("OnMouseUp", function(_, bouton)
        if bouton == "LeftButton" then Lacher() end
    end)

    -- Clic gauche : les fenetres. Clic droit : les actions. Maj + clic
    -- gauche : la selection du personnage, d'ou l'on cree aussi.
    f.sceau:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.sceau:SetScript("OnClick", function(_, souris)
        if f.glisse then
            f.glisse = false
            return
        end
        if souris == "RightButton" then
            Basculer(f, f.couronnes.actions)
            return
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            FermerTout(f, true)
            if UI.Personnages then UI.Personnages.Ouvrir() end
            return
        end
        -- Aucun personnage : la couronne des fenetres n'aurait rien a montrer
        -- (une fiche sans personnage, un inventaire vide). On ouvre la creation,
        -- qui est la seule chose a faire a ce moment-la.
        if LCM.Personnages and LCM.Personnages.Compte() == 0 then
            FermerTout(f, true)
            if UI.Personnages and UI.Personnages.Creer then UI.Personnages.Creer() end
            return
        end
        Basculer(f, f.couronnes.fenetres)
    end)
    Bulle(f.sceau, "Les Contes Malveillants", function()
        -- Sans personnage, le premier clic ne fait pas ce qu'il fait
        -- d'habitude : l'infobulle doit le dire.
        if LCM.Personnages and LCM.Personnages.Compte() == 0 then
            return "Clic : créer ton premier personnage\nClic droit : les actions\nGlisser : déplacer"
        end
        return "Clic : les fenêtres\nClic droit : les actions\n"
            .. "Maj + clic : choisir ou créer un personnage\nGlisser : déplacer"
    end)

    Radial.frame = f
    return f
end

function Radial.Fenetre()
    if not Radial.frame then Construire() end
    return Radial.frame
end

-- Place le sceau : au centre-bas par defaut, ou la ou le joueur l'a laisse.
function Radial.Placer()
    local f = Radial.Fenetre()
    LCM.EnsureDatabase()
    local place = LCM.db.settings and LCM.db.settings.radial
    local x = type(place) == "table" and tonumber(place.x) or 0
    local y = type(place) == "table" and tonumber(place.y) or -160
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

-- Ouvre ou ferme une couronne : "fenetres" ou "actions" (par defaut).
function Radial.Basculer(id)
    local f = Radial.Fenetre()
    local c = f.couronnes[id or "actions"]
    if not c then
        LCM.Erreur(string.format("radial : couronne inconnue « %s »", tostring(id)))
        return
    end
    Basculer(f, c)
end

-- Ferme une couronne, ou toutes sans argument.
function Radial.Fermer(id)
    local f = Radial.Fenetre()
    if id == nil then FermerTout(f, true) return end
    local c = f.couronnes[id]
    if c and (c.ouvert or c.orbite:IsShown()) then Fermer(f, c, true) end
end

-- Montre ou cache le sceau lui-meme (il est affiche en permanence par defaut).
function Radial.Afficher(visible)
    local f = Radial.Fenetre()
    if visible == nil then visible = not f:IsShown() end
    if not visible then FermerTout(f) end
    f:SetShown(visible and true or false)
    LCM.EnsureDatabase()
    LCM.db.settings.radialCache = (not visible) and true or nil
end

LCM.AddCommand("actions", "ouvre le lanceur d'actions", function() Radial.Basculer("actions") end)
LCM.AddCommand("sceau", "montre ou cache le sceau", function() Radial.Afficher() end)

LCM.WhenReady(function()
    Radial.Placer()
    local f = Radial.Fenetre()
    f:SetShown(not (LCM.db.settings and LCM.db.settings.radialCache))
end)

-- Nom lisible dans les raccourcis clavier de WoW.
_G.BINDING_HEADER_LESCONTESMALVEILLANTS = "Les Contes Malveillants"
_G.BINDING_NAME_LCM_MENU = "Ouvrir le menu des fenêtres"
_G.BINDING_NAME_LCM_FICHE = "Ouvrir la fiche"

function LCM_ToggleMenu() LCM.UI.Radial.Basculer("fenetres") end
function LCM_ToggleFiche()
    local f = LCM.UI.Fiche.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer(LCM.Entities.Self()) end
end
