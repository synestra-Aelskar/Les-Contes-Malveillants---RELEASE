-- Un panneau d'affichage (Core/Affichages.lua), cote aventurier.
--
-- Devant un panneau pose, le bouton « Lire » apparait (comme « Commercer »
-- devant un vendeur). Il ouvre le panneau : le support, et les affiches
-- punaisees dessus. Un clic sur une affiche la lit : son image, son titre, son
-- texte. Rien ne se prend ni ne se consomme : on lit.
local _, LCM = ...
local UI = LCM.UI
local A = LCM.Affichages

local Ecran = {}
UI.Affichage = Ecran

local LARGEUR, HAUTEUR = 780, 560
local COLONNES = 4
local ICONE = "Interface\\ICONS\\INV_Misc_Note_02"
local CARTE_ICONE = "INV_Misc_Map_01"

local function Habiller(fond, titre, corps, affiche, miniature)
    local theme = A.Theme(affiche.theme)
    local police = A.Police(affiche.police or theme.police)
    fond:SetTexture(theme.texture)
    fond:SetVertexColor(1, 1, 1, 1)
    titre:SetFont(police.chemin, (miniature and 13 or 23) * (police.facteur or 1), "")
    titre:SetTextColor(unpack(theme.encre))
    if corps then
        corps:SetFont(police.chemin, 18 * (police.facteur or 1), "")
        corps:SetTextColor(unpack(theme.encre))
        corps:SetSpacing(4)
    end
    return theme
end

-- La carte d'une affiche, prete a lire : celle qui est arrivee avec le
-- panneau, sinon celle du registre (le MJ, qui a ses cartes).
local function CarteDe(affiche)
    if not (affiche and affiche.carte) then return nil end
    return affiche.carteDef or (LCM.Cartes and LCM.Cartes.Definition("cartes/" .. affiche.carte))
end
Ecran.CarteDe = CarteDe

-- ===== Le bouton « Lire » ===================================================

local function Bouton()
    if Ecran.bouton then return Ecran.bouton end
    local b = UI.Interaction("LCM_BoutonAffichage", "Lire", ICONE)
    b:SetScript("OnClick", function(self) Ecran.Ouvrir(self.pointId) end)
    b:Hide()
    Ecran.bouton = b
    return b
end

function Ecran.Actualiser(point)
    local b = Bouton()
    local definition = point and A.definitions[point.def]
    if not definition then
        b.pointId = nil
        b:Hide()
        return
    end
    b.pointId = point.id
    b.nom:SetText(definition.label)
    b:Show()
end

-- ===== La fenetre du panneau ================================================

local function Construire()
    local f = UI.Fenetre("affichage", "Panneau", LARGEUR, HAUTEUR, { x = 0, y = 0 })
    local c = f.contenu

    -- Le support : l'image du MJ, ou l'aplat du support provisoire.
    f.support = CreateFrame("Frame", nil, c)
    f.support.image = f.support:CreateTexture(nil, "BACKGROUND")
    f.support.image:SetAllPoints(f.support)
    f.support.cadre = UI.Bordure(f.support, { 0.55, 0.40, 0.20, 1 })

    -- Les affiches : des feuilles claires punaisees en grille dans la zone.
    f.zone = CreateFrame("Frame", nil, f.support)
    f.feuilles = {}
    local function Feuille(i)
        local b = CreateFrame("Button", nil, f.zone)
        b.fond = UI.Aplat(b, { 0.90, 0.84, 0.70, 0.96 })
        b.fond:SetAllPoints(b)
        b.image = b:CreateTexture(nil, "ARTWORK")
        b.image:SetSize(40, 40)
        b.image:SetPoint("TOP", b, "TOP", 0, -16)
        b.titre = UI.Texte(b, "", { 0.20, 0.14, 0.08 }, "GameFontNormalSmall")
        b.titre:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.titre:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.titre:SetPoint("TOP", b.image, "BOTTOM", 0, -6)
        b.titre:SetJustifyH("CENTER")
        b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
        b.survol:SetAllPoints(b)
        b:SetScript("OnClick", function(self) f:Lire(self.index) end)
        f.feuilles[i] = b
        return b
    end

    -- La lecture d'une affiche, par-dessus le panneau.
    local l = CreateFrame("Frame", nil, c)
    l:SetAllPoints(c)
    l:SetFrameLevel(c:GetFrameLevel() + 20)
    l:EnableMouse(true)
    l.fond = UI.Aplat(l, { 0.90, 0.84, 0.70, 0.98 })
    l.fond:SetPoint("TOP", l, "TOP", 0, -4)
    l.fond:SetPoint("BOTTOM", l, "BOTTOM", 0, 4)
    l.fond:SetWidth(340)
    l.image = l:CreateTexture(nil, "ARTWORK")
    l.image:SetSize(64, 64)
    l.image:SetPoint("TOPLEFT", l.fond, "TOPLEFT", 24, -24)
    l.titre = UI.Texte(l, "", { 0.20, 0.14, 0.08 }, "GameFontNormalLarge")
    l.titre:SetPoint("TOPLEFT", l.fond, "TOPLEFT", 24, -24)
    l.titre:SetPoint("RIGHT", l.fond, "RIGHT", -24, 0)
    l.texte = UI.Defilement(l)
    l.texte:SetPoint("TOPLEFT", l.fond, "TOPLEFT", 24, -60)
    l.texte:SetPoint("BOTTOMRIGHT", l.fond, "BOTTOMRIGHT", -24, 50)
    l.corps = UI.Texte(l.texte.contenu, "", { 0.18, 0.13, 0.08 }, "GameFontNormal")
    l.corps:SetPoint("TOPLEFT", l.texte.contenu, "TOPLEFT", 0, 0)
    l.corps:SetPoint("RIGHT", l.texte.contenu, "RIGHT", 0, 0)
    l.corps:SetJustifyV("TOP")
    l.corps:SetWordWrap(true)
    l.retour = UI.Bouton(l, "Retour au panneau", 160, 26, function() l:Hide() end)
    l.retour:SetPoint("BOTTOM", l.fond, "BOTTOM", 0, 14)
    -- Une carte punaisee : son LIEN (« [Carte du marais] », la couleur des
    -- liens du compendium) la consulte sur place ; « Arracher la carte » la
    -- met dans l'inventaire.
    l.lienTitre = UI.Texte(l, "Carte :", { 0.30, 0.22, 0.12 }, "GameFontNormal")
    l.lienTitre:SetPoint("BOTTOMLEFT", l.fond, "BOTTOMLEFT", 24, 56)
    l.lien = CreateFrame("Button", nil, l)
    l.lien:SetHeight(20)
    l.lien:SetPoint("LEFT", l.lienTitre, "RIGHT", 6, 0)
    l.lien.texte = UI.Texte(l.lien, "", { 0.55, 0.36, 0.05 }, "GameFontNormal")
    l.lien.texte:SetPoint("LEFT", l.lien, "LEFT", 0, 0)
    l.lien.texte:SetPoint("RIGHT", l.lien, "RIGHT", 0, 0)
    l.lien.texte:SetWordWrap(false)
    l.lien.survol = UI.Aplat(l.lien, { 0.55, 0.36, 0.05, 0.12 }, "HIGHLIGHT")
    l.lien.survol:SetAllPoints(l.lien)
    -- Arrachee, la carte n'est plus au panneau : son lien se RATURE, d'un
    -- trait sur toute sa longueur, et ne se clique plus.
    l.lien.rature = UI.Aplat(l.lien, { 0.30, 0.22, 0.12, 0.95 }, "OVERLAY")
    l.lien.rature:SetHeight(2)
    l.lien.rature:SetPoint("LEFT", l.lien.texte, "LEFT", -2, 0)
    l.lien.rature:SetPoint("RIGHT", l.lien.texte, "RIGHT", 2, 0)
    l.lien.rature:Hide()
    l.lien:SetScript("OnClick", function()
        local affiche = f.definition and f.definition.affiches[l.index]
        local def = CarteDe(affiche)
        if not def then LCM.Alerte("cette carte n'est plus lisible.") return end
        LCM.UI.Cartes.Ouvrir(nil, def)
    end)
    UI.Bulle(l.lien, "Consulter la carte", "La lire ici, sans l'emporter.", 0.2)
    l.arracher = UI.Bouton(l, "Arracher la carte", 170, 26, function()
        local ok, raison = A.Arracher(f.pointId, f.definition, l.index)
        if not ok then LCM.Alerte(tostring(raison)) end
        f:Lire(l.index)
    end)
    l.arracher:SetPoint("BOTTOM", l.fond, "BOTTOM", 0, 48)
    l:Hide()
    f.lecture = l

    function f:Disposer()
        local d = self.definition
        local support = A.Support(d.support) or {}
        -- Le support garde son rapport, et tient dans la fenetre.
        local lw, lh = LARGEUR - 40, HAUTEUR - (self.insetHaut or 60) - 30
        local rapport = tonumber(support.rapport) or 1.6
        local w, h = lw, lw / rapport
        if h > lh then h, w = lh, lh * rapport end
        self.support:ClearAllPoints()
        self.support:SetPoint("TOP", c, "TOP", 0, -8)
        self.support:SetSize(w, h)
        if support.texture then
            self.support.image:SetTexture(support.texture)
            local co = support.coords or { 0, 1, 0, 1 }
            self.support.image:SetTexCoord(co[1], co[2], co[3], co[4])
            self.support.image:SetVertexColor(1, 1, 1, 1)
            for _, t in ipairs(self.support.cadre) do t:Hide() end
        else
            local teinte = support.teinte or { 0.32, 0.22, 0.12 }
            self.support.image:SetColorTexture(teinte[1], teinte[2], teinte[3], 1)
            for _, t in ipairs(self.support.cadre) do t:Show() end
        end
        local z = support.zone or { 0.06, 0.10, 0.94, 0.92 }
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", self.support, "TOPLEFT", z[1] * w, -z[2] * h)
        self.zone:SetSize((z[3] - z[1]) * w, (z[4] - z[2]) * h)

        local affiches = d.affiches or {}
        local lignes = math.max(1, math.ceil(#affiches / COLONNES))
        local zw, zh = self.zone:GetWidth(), self.zone:GetHeight()
        local pas = 10
        local fw = (zw - pas * (COLONNES + 1)) / COLONNES
        local fh = math.min(176, (zh - pas * (lignes + 1)) / lignes)
        local largeurFeuille = math.min(fw, fh * 2 / 3)
        for i, affiche in ipairs(affiches) do
            local b = self.feuilles[i] or Feuille(i)
            b.index = i
            local col, rang = (i - 1) % COLONNES, math.floor((i - 1) / COLONNES)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.zone, "TOPLEFT", pas + col * (fw + pas) + (fw - largeurFeuille) / 2, -(pas + rang * (fh + pas)))
            b:SetSize(largeurFeuille, fh)
            Habiller(b.fond, b.titre, nil, affiche, true)
            b.titre:SetHeight(math.max(22, fh - 76))
            -- Une affiche qui porte une carte se reconnait a son icone de carte
            -- quand elle n'a pas d'image a elle.
            local icone = affiche.image or (affiche.carte and CARTE_ICONE) or nil
            b.image:SetShown(icone ~= nil)
            if icone then b.image:SetTexture(LCM.Icone(icone)) end
            if not icone then
                b.titre:ClearAllPoints()
                b.titre:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.titre:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.titre:SetPoint("TOP", b, "TOP", 0, -18)
            else
                b.titre:ClearAllPoints()
                b.titre:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.titre:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.titre:SetPoint("TOP", b.image, "BOTTOM", 0, -6)
            end
            b.titre:SetText(affiche.titre)
            b:Show()
        end
        for i = #affiches + 1, #self.feuilles do self.feuilles[i]:Hide() end
        if not self.vide then
            self.vide = UI.Texte(self.zone, "Rien n'est affiché ici pour l'instant.", { 0.85, 0.78, 0.60 })
            self.vide:SetPoint("CENTER", self.zone, "CENTER", 0, 0)
        end
        self.vide:SetShown(#affiches == 0)
    end

    function f:Lire(index)
        local affiche = self.definition and self.definition.affiches[index]
        if not affiche then return end
        local l = self.lecture
        l.index = index
        local theme = Habiller(l.fond, l.titre, l.corps, affiche)
        l.lienTitre:SetTextColor(unpack(theme.encre))
        local icone = affiche.image or (affiche.carte and CARTE_ICONE) or nil
        l.image:SetShown(icone ~= nil)
        if icone then l.image:SetTexture(LCM.Icone(icone)) end
        local avecCarte = affiche.carte ~= nil
        l.lienTitre:SetShown(avecCarte)
        l.lien:SetShown(avecCarte)
        l.arracher:SetShown(avecCarte)
        if avecCarte then
            local def = CarteDe(affiche)
            l.lien.texte:SetText("[" .. tostring(def and def.label or affiche.carte) .. "]")
            l.lien:SetWidth(math.min(220, (l.lien.texte:GetStringWidth() or 120) + 4))
            local deja = A.DejaArrachee(self.pointId, self.definition, index)
            l.lien.rature:SetShown(deja)
            l.lien:EnableMouse(not deja)
            local c = deja and { 0.45, 0.40, 0.33 } or theme.lien
            l.lien.texte:SetTextColor(c[1], c[2], c[3])
            l.arracher:SetEnabled(not deja)
            l.arracher.label:SetText(deja and "Carte déjà arrachée" or "Arracher la carte")
        end
        local gauche = icone and 100 or 28
        l.titre:ClearAllPoints()
        l.titre:SetPoint("TOPLEFT", l.fond, "TOPLEFT", gauche, -24)
        l.titre:SetPoint("RIGHT", l.fond, "RIGHT", -24, 0)
        l.titre:SetHeight(64)
        l.titre:SetText(affiche.titre)
        l.texte:ClearAllPoints()
        l.texte:SetPoint("TOPLEFT", l.fond, "TOPLEFT", 28, -100)
        l.texte:SetPoint("BOTTOMRIGHT", l.fond, "BOTTOMRIGHT", -28, affiche.carte and 114 or 54)
        l.lienTitre:ClearAllPoints()
        l.lienTitre:SetPoint("BOTTOMLEFT", l.fond, "BOTTOMLEFT", 28, 86)
        l.corps:SetText(affiche.texte ~= "" and affiche.texte or "(cette affiche n'a pas de texte)")
        l.texte:Regler((l.corps:GetStringHeight() or 0) + 8)
        l:Show()
    end

    function f:Montrer(definition, pointId)
        self.definition, self.pointId = definition, pointId
        -- Le titre de la fenetre est « Panneau », tout court (le MJ, 31 octobre
        -- 2026) : le nom donne au panneau dans l'atelier reste celui du MJ.
        self:Titre("Panneau")
        self.lecture:Hide()
        self:Show()
        self:Disposer()
    end

    f:Hide()
    return f
end

-- `pointId` : un panneau pose, connu (A.points). `definition` (facultatif) :
-- l'apercu de l'atelier, sans panneau pose.
function Ecran.Ouvrir(pointId, definition)
    if not definition then
        local p = A.points[tostring(pointId or "")]
        definition = p and A.definitions[p.def]
        if not definition then return false, "panneau inconnu." end
    end
    Ecran.frame = Ecran.frame or Construire()
    Ecran.frame:Montrer(definition, pointId)
    return true
end

A.onProche = function(point) Ecran.Actualiser(point) end
