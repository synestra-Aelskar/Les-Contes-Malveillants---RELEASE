-- La jauge du deplacement force.
--
-- Mesures de Necronicon (`Deplacement.lua`) : fenetre de 260 de large, la jauge
-- en haut, le compteur dessous, la consigne sous le compteur, le bouton en bas.
--
-- Necronicon dessine un ANNEAU (un Cooldown retourne dont on fige le balayage)
-- et retombe sur une barre horizontale quand le Cooldown n'est pas disponible.
-- On prend sa barre : c'est son propre repli, pas une invention, et l'anneau
-- demande un gabarit qu'on n'a pas porte.
--
-- Fermer la fenetre interrompt la course, comme chez lui : une jauge qu'on
-- ferme et qui continuerait a compter dans le dos est pire que pas de jauge.

local _, LCM = ...
local UI = LCM.UI
local DF = LCM.DeplacementForce

local NOMS_MODE = { terrestre = "Terrestre", nage = "Nage", vol = "Vol" }

local Ecran = {}
UI.DeplacementForce = Ecran

local LARGEUR, HAUTEUR = 260, 374
local MODES = { { id = "terrestre", label = "Terrestre" },
                { id = "nage",      label = "Nage" },
                { id = "vol",       label = "Vol" } }

-- L'anneau de Necronicon (`MakeRing`), repris tel quel : un Cooldown RETOURNE
-- dont on fige le balayage a la fraction voulue, un disque sombre par-dessus
-- pour creuser l'anneau, et le chiffre au milieu. Le Cooldown peut manquer
-- (client ancien, modele absent) : la barre horizontale sous l'anneau prend le
-- relais, et c'est le repli de Necronicon, pas une invention.
local ANNEAU = 132
local MASQUE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function Anneau(parent)
    local a = CreateFrame("Frame", nil, parent)
    a:SetSize(ANNEAU, ANNEAU)
    a.fond = a:CreateTexture(nil, "BACKGROUND")
    a.fond:SetAllPoints()
    a.fond:SetTexture(MASQUE)
    a.fond:SetVertexColor(0.10, 0.10, 0.10, 0.92)

    local ok, cd = pcall(CreateFrame, "Cooldown", nil, a, "CooldownFrameTemplate")
    if ok and cd and cd.SetCooldown then
        cd:SetAllPoints()
        if cd.SetSwipeTexture then cd:SetSwipeTexture(MASQUE) end
        if cd.SetSwipeColor then cd:SetSwipeColor(0.85, 0.70, 0.25, 0.85) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        if cd.SetReverse then cd:SetReverse(true) end
        if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
        a.cd = cd
    end

    a.dedans = CreateFrame("Frame", nil, a)
    a.dedans:SetPoint("CENTER")
    a.dedans:SetSize(ANNEAU - 34, ANNEAU - 34)
    a.dedans:SetFrameLevel(a:GetFrameLevel() + 5)
    a.dedans.tex = a.dedans:CreateTexture(nil, "ARTWORK")
    a.dedans.tex:SetAllPoints()
    a.dedans.tex:SetTexture(MASQUE)
    a.dedans.tex:SetVertexColor(0.06, 0.06, 0.07, 1)

    a.valeur = UI.Texte(a.dedans, "0", UI.C.titre)
    UI.Police(a.valeur, 20)
    a.valeur:SetPoint("CENTER", a.dedans, "CENTER", 0, 8)
    a.sur = UI.Texte(a.dedans, "/ 0 m", UI.C.discret)
    UI.Police(a.sur, 11)
    a.sur:SetPoint("TOP", a.valeur, "BOTTOM", 0, -2)

    a.barre = UI.Barre(a, UI.C.accent, ANNEAU, 6)
    a.barre:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -6)
    a.barre:SetPoint("TOPRIGHT", a, "BOTTOMRIGHT", 0, -6)
    a.barre:SetShown(a.cd == nil)

    function a:Regler(distance, limite, enCours)
        distance, limite = tonumber(distance) or 0, tonumber(limite) or 0
        local part = limite > 0 and math.max(0, math.min(1, distance / limite)) or 0
        if self.cd then
            -- Duree enorme : la position ne bouge pas entre deux mesures.
            local D = 100000
            local maintenant = (GetTime and GetTime()) or 0
            self.cd:SetCooldown(maintenant - part * D, D)
            if self.cd.SetSwipeColor then
                if part >= 1 then self.cd:SetSwipeColor(0.90, 0.25, 0.20, 0.9)
                elseif part >= 0.8 then self.cd:SetSwipeColor(0.95, 0.55, 0.20, 0.88)
                else self.cd:SetSwipeColor(0.85, 0.70, 0.25, 0.85) end
            end
        end
        self.barre:Regler(part, 1)
        self.valeur:SetText(string.format("%.1f", distance))
        self.sur:SetText(string.format("/ %s m", tostring(limite)))
        -- Les couleurs de Necronicon : rouge arrive, ambre en marche, eteint
        -- a l'arret.
        if part >= 1 then self.valeur:SetTextColor(1, 0.35, 0.3)
        elseif enCours then self.valeur:SetTextColor(1, 0.85, 0.35)
        else self.valeur:SetTextColor(0.85, 0.85, 0.8) end
    end
    return a
end

local function Construire()
    local f = UI.Fenetre("deplacement_force", "Déplacement", LARGEUR, HAUTEUR, { x = 260, y = 60 })
    Ecran.frame = f
    local DEDANS = LARGEUR - 24

    -- Les trois modes en haut, comme des onglets : 70 de large, 6 d'ecart.
    f.modes = {}
    for index, mode in ipairs(MODES) do
        local b = UI.Bouton(f.contenu, mode.label, 70, 20, function()
            if DF.EnCours() then return end
            f.mode = mode.id
            f:Actualiser()
        end)
        b.modeId = mode.id
        b:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 7 + (index - 1) * 76, 0)
        f.modes[index] = b
    end
    f.mode = "terrestre"

    -- L'anneau et ses deux lignes vivent dans l'espace libre entre les modes et
    -- les boutons, et sont CENTRES dedans. Accroche en haut, l'anneau laissait
    -- un grand vide sous lui des que la ligne de round se taisait (hors
    -- combat), et la fenetre avait l'air cassee.
    f.centre = CreateFrame("Frame", nil, f.contenu)
    f.centre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -26)
    f.centre:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -26)

    f.anneau = Anneau(f.contenu)
    f.anneau:SetPoint("CENTER", f.centre, "CENTER", 0, 0)

    -- Le compteur du round, puis la consigne : l'ordre de Necronicon.
    f.round = UI.Texte(f.contenu, "", UI.C.accent)
    UI.Police(f.round, 12)
    f.round:SetPoint("TOP", f.anneau, "BOTTOM", 0, -12)
    f.round:SetJustifyH("CENTER")

    f.consigne = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.consigne, 11)
    f.consigne:SetPoint("TOP", f.round, "BOTTOM", 0, -3)
    f.consigne:SetPoint("LEFT", f.contenu, "LEFT", 0, 0)
    f.consigne:SetPoint("RIGHT", f.contenu, "RIGHT", 0, 0)
    f.consigne:SetJustifyH("CENTER")
    f.consigne:SetWordWrap(true)

    f.partir = UI.Bouton(f.contenu, "Se déplacer", DEDANS, 24, function()
        if DF.EnCours() then DF.Arreter("interrompu") return end
        local ok, raison = DF.DemarrerMode(f.mode)
        if not ok then LCM.Alerte(tostring(raison)) end
    end)
    f.partir:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    -- Marquer l'emplacement : l'aura qui montre ou l'on s'est arrete. Elle se
    -- pose toute seule a l'arrivee ; ce bouton sert a la garder, ou a la poser
    -- sans avoir couru.
    f.marquer = UI.Bouton(f.contenu, "Marquer l'emplacement", DEDANS, 24, function()
        DF.BasculerMarqueur()
        f:Actualiser()
    end)
    f.marquer:SetPoint("BOTTOMLEFT", f.partir, "TOPLEFT", 0, 6)

    -- Fermer, c'est interrompre. On passe par Arreter pour que le module le
    -- sache, et le drapeau evite que Arreter -> Hide -> Arreter tourne en rond.
    f:SetScript("OnHide", function(self)
        if self.enFermeture then return end
        self.enFermeture = true
        if DF.EnCours() then DF.Arreter("interrompu") end
        self.enFermeture = nil
    end)

    function f:Actualiser()
        local distance, limite, enCours = DF.Etat()
        -- Hors course, l'anneau montre ce que la fiche autorise dans le mode
        -- choisi : on voit son allocation avant de partir.
        if not enCours then limite = DF.Allocation(nil, self.mode) end
        for _, b in ipairs(self.modes) do
            b:Selectionner(b.modeId == self.mode)
            -- Un mode que la fiche ne permet pas (le vol, le plus souvent)
            -- reste visible mais eteint : le menu ne ment pas sur ce qui existe.
            b:SetEnabled(not enCours and DF.Allocation(nil, b.modeId) > 0)
        end

        local prochain = DF.Prochain()
        if enCours then
            self.partir.label:SetText("Arrêter")
        elseif not DF.EnCombat() then
            self.partir.label:SetText("Se déplacer")
        elseif prochain == "gratuit" then
            self.partir.label:SetText("Se déplacer (gratuit)")
        elseif prochain == "payant" then
            self.partir.label:SetText("Se déplacer (1 PA + 1 PF)")
        else
            self.partir.label:SetText("Plus de déplacement")
        end
        self.partir:SetEnabled(enCours or prochain ~= "fini")

        -- Hors combat, aucune limite : compter les deplacements de quelqu'un
        -- qui traverse une ville n'a pas de sens. La ligne du round ne parle
        -- donc qu'en combat, et le reste du temps elle se tait au lieu
        -- d'annoncer une regle qui ne s'applique pas.
        local regle = LCM.Equilibrage.deplacement
        local enCombat = DF.EnCombat()
        self.round:SetShown(enCombat)
        self.consigne:SetShown(enCombat)
        if enCombat then
            self.round:SetText(string.format("Déplacement %d / %d ce round",
                DF.Mouvements(), DF.MaxParRound()))
            self.consigne:SetText(string.format(
                "1 déplacement gratuit par round,\npuis 1 supplémentaire à %d PA + %d PF.",
                regle.supplementPA or 1, regle.supplementPF or 1))
        end

        -- Le groupe entier est centre : quand les deux lignes se taisent,
        -- l'anneau redescend au milieu au lieu de rester accroche en haut.
        self.centre:SetPoint("BOTTOM", self.marquer, "TOP", 0, 6)
        local basTextes = 0
        if enCombat then
            basTextes = 12 + (self.round:GetStringHeight() or 14)
                      + 3 + (self.consigne:GetStringHeight() or 28)
        end
        self.anneau:ClearAllPoints()
        self.anneau:SetPoint("CENTER", self.centre, "CENTER", 0, basTextes / 2)

        self.anneau:Regler(distance, limite, enCours)
        self.marquer.label:SetText(DF.Marqueur() and "Retirer l'emplacement" or "Marquer l'emplacement")
        self.marquer:Selectionner(DF.Marqueur())
    end

    function f:Montrer()
        self:Actualiser()
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

LCM.WhenReady(function()
    -- La fenetre s'ouvre toute seule quand une poussee commence : on ne demande
    -- pas a quelqu'un qu'on vient de repousser d'aller ouvrir un panneau.
    DF.onDemarrage = function()
        local f = Ecran.Fenetre()
        f:Montrer()
        if f.Raise then f:Raise() end
    end
    DF.onChange = function()
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Actualiser() end
    end
    DF.onFin = function(_, fini)
        if not Ecran.frame then return end
        Ecran.frame:Actualiser()
        -- Course finie : la fenetre se retire d'elle-meme. Interrompue, c'est
        -- qu'on vient de la fermer.
        if fini then Ecran.frame:Hide() end
    end
end)

-- De quoi la regarder sans se faire pousser, et verifier qu'elle va bien.
LCM.WhenReady(function()
    -- Les deux raccourcis ouvrent la même jauge : le menu principal permet de
    -- la consulter à tout moment, et le radial Combat la garde sous la main
    -- pendant un tour.
    local function Basculer()
        local f = Ecran.Fenetre()
        if f:IsShown() then f:Hide() else f:Montrer() end
    end
    UI.Menu.Lier("deplacement", Basculer)
    UI.Radial.Lier("mouvement", Basculer)
end)

LCM.AddCommand("deplacer", "ouvre la jauge de deplacement", function()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
end)

LCM.AddCommand("pousse", "essaie la jauge de deplacement force", function(argument)
    local metres = tonumber(tostring(argument or ""):match("%d+%.?%d*")) or 6
    local ok, raison = DF.Demarrer(metres, "Essai")
    if not ok then LCM.Alerte(tostring(raison)) end
end)
