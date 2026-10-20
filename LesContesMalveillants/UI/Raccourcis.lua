-- Les raccourcis clavier que l'addon pose lui-meme.
--
-- I ouvre l'inventaire de l'addon, Maj + C la fiche et l'equipement
-- ensemble, et les touches natives qui ouvrent UN
-- sac de WoW (sac a dos, sacs 1 a 4) ne font plus rien : nos objets ne sont
-- pas dans ces sacs-la, et les ouvrir par reflexe n'y montrait rien d'utile
-- (20 octobre 2026). « Ouvrir tous les sacs » (B) reste a WoW.
--
-- Tout passe par des SURCHARGES (SetOverrideBinding) : elles se posent
-- par-dessus les raccourcis du joueur sans les reecrire. Desactiver l'addon
-- rend donc a WoW ses touches telles que le joueur les avait reglees ; rien
-- n'est a defaire a la main.
--
-- Les touches a neutraliser sont LUES dans les raccourcis du joueur
-- (GetBindingKey), pas supposees : celui qui a mis son sac a dos sur une autre
-- touche que F12 la voit neutralisee elle aussi. La lecture se fait une fois,
-- a la connexion ; une touche changee en cours de jeu suit au /reload.

local _, LCM = ...
local UI = LCM.UI

local Raccourcis = {}
UI.Raccourcis = Raccourcis

-- I seul (20 octobre 2026, Maj + I avant) : la touche la plus courte pour la
-- fenetre qu'on ouvre le plus. Elle recouvre celle de WoW (la recherche de
-- groupe dans sa configuration par defaut), qu'on n'utilise pas en jeu de role.
Raccourcis.INVENTAIRE = "I"
-- La fiche ET l'equipement, ensemble : c'est ce que montre la touche du
-- personnage de WoW, statistiques et objets portes cote a cote.
Raccourcis.PERSONNAGE = "SHIFT-C"
-- Les actions natives qui ouvrent un seul sac. TOGGLEBAG5 est le sac de
-- composants des versions qui en ont un ; ailleurs, aucune touche n'y repond.
Raccourcis.SACS_NATIFS = { "TOGGLEBACKPACK", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3",
                           "TOGGLEBAG4", "TOGGLEBAG5" }

_G.BINDING_NAME_LCM_INVENTAIRE = "Ouvrir l'inventaire"
function LCM_ToggleInventaire() UI.Inventaires.Basculer() end

_G.BINDING_NAME_LCM_PERSONNAGE = "Ouvrir la fiche et l'équipement"
-- Les deux s'ouvrent et se ferment ensemble. Si une seule est ouverte, la
-- touche ouvre l'autre plutot que de fermer celle-la : on la presse pour
-- VOIR les deux.
--
-- Cote a cote, la fiche a gauche et l'equipement a droite. Ouvertes
-- ensemble, elles se partagent le centre de l'ecran ; si l'une l'etait deja,
-- l'autre vient se coller a elle, la ou on l'a laissee. La place n'est pas
-- sauvegardee : glisser l'une la deplace comme avant.
--
-- Les deux cadres s'alignent PAR LE HAUT, et l'equipement prend la hauteur
-- de la fiche : deux fenetres de tailles differentes, centrees chacune sur
-- sa moitie, se lisaient comme deux choses sans rapport (20 octobre 2026,
-- maquette du MJ).
--
-- L'ecart compte la bordure doree, qui deborde HORS du rectangle de la
-- fenetre (UI.Fenetre, decor.debordGauche/Droite), plus de l'air : la
-- poignee « ‹ › » du volet d'artwork depasse du bord droit de la fiche, et
-- quatre unites la collaient au cadre voisin.
local JOUR = 60
local function Debord(f, cote) return (f.decor and tonumber(f.decor[cote])) or 0 end

local function CoteACote(fiche, equipement, gardee)
    local ecart = Debord(fiche, "debordDroite") + Debord(equipement, "debordGauche") + JOUR
    equipement:SetHeight(fiche:GetHeight())
    if gardee == fiche then
        equipement:ClearAllPoints()
        equipement:SetPoint("TOPLEFT", fiche, "TOPRIGHT", ecart, 0)
    elseif gardee == equipement then
        fiche:ClearAllPoints()
        fiche:SetPoint("TOPRIGHT", equipement, "TOPLEFT", -ecart, 0)
    else
        -- La paire centree a l'ecran : le haut de la fiche a mi-hauteur au-dessus
        -- du centre, l'equipement accroche a son haut.
        fiche:ClearAllPoints()
        fiche:SetPoint("TOPRIGHT", UIParent, "CENTER", -ecart / 2, fiche:GetHeight() / 2)
        equipement:ClearAllPoints()
        equipement:SetPoint("TOPLEFT", fiche, "TOPRIGHT", ecart, 0)
    end
end

function LCM_TogglePersonnage()
    local fiche, equipement = UI.Fiche.Fenetre(), UI.Vues.Fenetre("equipement")
    if fiche:IsShown() and equipement:IsShown() then
        fiche:Hide()
        equipement:Hide()
        return
    end
    local gardee = (fiche:IsShown() and fiche) or (equipement:IsShown() and equipement) or nil
    if not fiche:IsShown() then fiche:Montrer(LCM.Entities.Self()) end
    if not equipement:IsShown() then equipement:Montrer() end
    CoteACote(fiche, equipement, gardee)
end

local proprio = CreateFrame("Frame")
-- Une touche neutralisee clique ce bouton, qui ne fait rien : une surcharge
-- vers une action vide n'est pas un geste que l'API garantit.
local muet = CreateFrame("Button", "LCM_RaccourciMuet", UIParent)
muet:Hide()

-- Les touches neutralisees, pour le banc et pour qui voudrait savoir.
Raccourcis.neutralisees = {}

function Raccourcis.Poser()
    -- Une surcharge est un geste protege : en combat, on attend la fin.
    if InCombatLockdown() then
        Raccourcis.enAttente = true
        return false
    end
    Raccourcis.enAttente = nil
    ClearOverrideBindings(proprio)
    Raccourcis.neutralisees = {}
    for _, action in ipairs(Raccourcis.SACS_NATIFS) do
        for _, touche in ipairs({ GetBindingKey(action) }) do
            -- Nos touches sont a nous : si le joueur y avait mis un sac,
            -- c'est notre fenetre qui gagne, pas le silence.
            if touche ~= Raccourcis.INVENTAIRE and touche ~= Raccourcis.PERSONNAGE then
                SetOverrideBindingClick(proprio, false, touche, "LCM_RaccourciMuet")
                Raccourcis.neutralisees[#Raccourcis.neutralisees + 1] = touche
            end
        end
    end
    SetOverrideBinding(proprio, false, Raccourcis.INVENTAIRE, "LCM_INVENTAIRE")
    SetOverrideBinding(proprio, false, Raccourcis.PERSONNAGE, "LCM_PERSONNAGE")
    return true
end

LCM.On("PLAYER_REGEN_ENABLED", function()
    if Raccourcis.enAttente then Raccourcis.Poser() end
end)

LCM.WhenReady(Raccourcis.Poser)
