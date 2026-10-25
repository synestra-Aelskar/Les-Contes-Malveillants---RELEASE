-- « Voir » une lanterne equipee (Mes Outils, 25 octobre 2026) : ce qu'elle a
-- dedans et ce qu'il lui reste, rien de plus.
--
-- Elle remplace le panneau repris d'OmegaSurvive, retire le meme jour : ses
-- emotes, son canal, son variateur et sa remise a zero n'ont pas suivi. La
-- regle vit dans Core/Lanternes.lua et n'a pas bouge ; ces reglages y gardent
-- leurs valeurs, ils n'ont simplement plus d'ecran.

local _, LCM = ...
local UI = LCM.UI
local L = LCM.Lanterne

local Ecran = {}
UI.Lanterne = Ecran

local LARGEUR = 300
local MARGE = 16
local LARGEUR_CTRL = LARGEUR - 2 * MARGE

local deconnexion = false
LCM.On("PLAYER_LOGOUT", function() deconnexion = true end)

local function Refus(ok, raison)
    if not ok and raison then LCM.Alerte(raison) end
    return ok
end

local function Duree(secondes)
    local s = math.floor(math.max(0, secondes))
    local j, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
    if j > 0 then return string.format("%d j %02d h", j, h) end
    if h > 0 then return string.format("%d h %02d min", h, m) end
    return string.format("%d min", m)
end

-- « Aucun cristal » d'abord, puis ce que le joueur PORTE : le catalogue du
-- compendium ne se montre pas, ce qui n'est pas dans les sacs n'existe pas
-- pour lui (23 octobre 2026).
local function Cristaux()
    local out = { { id = false, label = "Aucun cristal" } }
    for _, e in ipairs(L.CristauxPortes()) do out[#out + 1] = { id = e.id, label = e.label } end
    return out
end

local function Construire()
    local f = UI.Fenetre("lanterne_outil", "Lanterne", LARGEUR, 10, { x = 215, y = -40 })
    Ecran.frame = f
    local c = f.contenu
    local y = -8
    local function Poser(w, hauteur)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", c, "TOPLEFT", MARGE, y)
        y = y - hauteur
    end

    f.lblCristal = UI.Texte(c, "Cristal", UI.C.libelle, "GameFontNormalSmall")
    Poser(f.lblCristal, 16)
    f.cristal = UI.Deroulant(c, LARGEUR_CTRL, 22, Cristaux, function(id)
        Refus(L.ChoisirCristal(id or nil))
        f:Afficher()
    end)
    Poser(f.cristal, 34)

    f.charge = UI.Barre(c, UI.C.accent, LARGEUR_CTRL, 18)
    Poser(f.charge, 24)
    f.restant = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.restant:SetWidth(LARGEUR_CTRL)
    f.restant:SetJustifyH("CENTER")
    Poser(f.restant, 26)

    -- Allumer et eteindre ne passent pas par L.onChange (le Core ne le leve
    -- que pour un cristal) : on previent nous-memes le bandeau de Mes Outils,
    -- qui sinon proposerait encore « Éteindre » sur une lanterne eteinte.
    f.allumer = UI.Bouton(c, "Allumer", LARGEUR_CTRL, 24, function()
        Refus(L.Basculer())
        f:Afficher()
        if UI.MesOutils then UI.MesOutils.Actualiser() end
    end)
    Poser(f.allumer, 24)
    f:SetHeight(f.insetHaut + (-y) + 14 + f.insetBas)

    function f:Afficher()
        L.Synchroniser()
        local lanterne = L.LanterneChoisie()
        self:SousTitre(lanterne and lanterne.label or "Lanterne")
        local pose = L.CristalPose()
        local aucun = #L.CristauxPortes() == 0 and not pose
        self.cristal:Definir(pose and ("pose:" .. tostring(pose.id)) or false, pose and L.LibelleCristal(pose)
            or (aucun and "Aucun cristal dans tes sacs" or "Aucun cristal"))
        -- Un cristal pose peut toujours se retirer : la liste reste ouverte.
        self.cristal:SetEnabled(not aucun)
        self.cristal:SetAlpha(aucun and 0.45 or 1)

        local max, charge = L.ChargeMax(), L.Charge()
        self.charge:Regler(charge, max)
        self.charge.label:SetText(max > 0 and string.format("%.0f %%", charge / max * 100) or "—")
        local allumee = L.Allumee()
        local etat = L.EnPauseMJ() and "En pause (MJ)" or (allumee and "Allumée" or "Éteinte")
        self.restant:SetText(max > 0 and (etat .. " · encore " .. Duree(L.Restant())) or etat)

        -- Une lanterne vide ne s'allume pas : le bouton le dit au lieu de
        -- refuser au clic.
        local vide = not L.CristalChoisi() or (max > 0 and charge <= 0)
        self.allumer.label:SetText(allumee and "Éteindre" or (vide and "Pose un cristal chargé" or "Allumer"))
        self.allumer:SetEnabled(allumee or not vide)
        self.allumer:SetAlpha((allumee or not vide) and 1 or 0.45)
    end

    -- Regarder sa lanterne et la ranger se jouent en emote (Core/Lanternes,
    -- « open » et « close »). La deconnexion n'est pas un geste.
    f:HookScript("OnShow", function(self)
        self:Afficher()
        L.DireEmote("open")
    end)
    f:HookScript("OnHide", function()
        if not deconnexion then L.DireEmote("close") end
    end)

    -- Retiree (depuis la fiche, Mes Outils ou un echange) : il n'y a plus
    -- rien a regarder.
    local ecoule = 0
    f:HookScript("OnUpdate", function(self, dt)
        ecoule = ecoule + (tonumber(dt) or 0)
        if ecoule < 0.5 then return end
        ecoule = 0
        if not L.LanterneEquipee(LCM.Entities.Self()) then self:Hide() end
    end)
    f:Hide()
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Actualiser()
    if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
end

function Ecran.Basculer()
    if not L.LanterneEquipee(LCM.Entities.Self()) then
        return false, "équipe une lanterne (Équipements › Outils) pour la voir."
    end
    local f = Ecran.Fenetre()
    f:SetShown(not f:IsShown())
    return true, f
end

-- Le Core previent a chaque changement et a chaque battement : la fenetre et
-- le bandeau de Mes Outils (Allumer / Éteindre) suivent tous les deux.
L.onChange = function()
    Ecran.Actualiser()
    if UI.MesOutils then UI.MesOutils.Actualiser() end
end
L.onTick = L.onChange
