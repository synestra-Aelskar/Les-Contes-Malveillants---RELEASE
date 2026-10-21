-- Lecteur de livres : mise en page native et sequences completes en BLP.
local _, LCM = ...
local UI, Ecran = LCM.UI, {}
UI.Livres = Ecran
local Animation = UI.LivresAnimation
local ART = Animation.ART
local POLICE = "Interface\\AddOns\\LesContesMalveillants\\ressources\\bannieres\\polices\\Caudex-Regular.ttf"
local LARGEUR, HAUTEUR, FONDU = 940, 650, .12

local function RGB(hexa)
    hexa = tostring(hexa or "302317")
    return (tonumber(hexa:sub(1, 2), 16) or 48) / 255,
        (tonumber(hexa:sub(3, 4), 16) or 35) / 255,
        (tonumber(hexa:sub(5, 6), 16) or 23) / 255
end

local function Texte(parent, taille, centre)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(POLICE, taille, "")
    t:SetShadowOffset(0, 0)
    t:SetJustifyH(centre and "CENTER" or "LEFT")
    t:SetJustifyV("TOP")
    t:SetWordWrap(true)
    if t.SetNonSpaceWrap then t:SetNonSpaceWrap(true) end
    return t
end

local function Feuillets(livre)
    local feuilles = {}
    if livre.format == "livre" then
        local face = livre.couverture or {}
        feuilles[1] = { titre = face.titre and face.titre ~= "" and face.titre or livre.label,
            texte = face.texte or "", nature = "Couverture" }
    end
    for i, page in ipairs(livre.pages) do
        feuilles[#feuilles + 1] = { titre = page.titre or "", texte = page.texte or "",
            nature = livre.format == "note" and (i == 1 and "Recto" or "Verso") or "Page" }
    end
    if livre.format == "livre" then
        local face = livre.dos or {}
        feuilles[#feuilles + 1] = { titre = face.titre or "", texte = face.texte or "", nature = "Dos" }
    end
    return feuilles
end

local function Surface(parent, largeur)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(largeur, HAUTEUR)
    s:SetPoint("CENTER", parent, "CENTER", 0, 0)
    s.image = s:CreateTexture(nil, "BACKGROUND")
    s.image:SetAllPoints(s)
    s.lecture = CreateFrame("Frame", nil, s)
    s.lecture:SetAllPoints(s)
    return s
end

local function Page(parent, x, y, largeur, hauteur, couverture)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(largeur, hauteur)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    p.largeur, p.hauteur = largeur, hauteur
    p.titre = Texte(p, couverture and 28 or 24, true)
    p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.titre:SetWidth(largeur)
    p.zone = UI.Defilement(p)
    p.zone:SetWidth(largeur)
    p.zone.barre.gouttiere:SetAlpha(0)
    p.zone.barre.poignee.fond:SetColorTexture(.45, .32, .16, .55)
    p.zone.barre:SetWidth(3)
    p.zone.barre.poignee:SetWidth(3)
    p.texte = Texte(p.zone.contenu, 18, couverture)
    p.texte:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, 0)
    p.texte:SetWidth(largeur - 12)
    p.texte:SetSpacing(4)
    p.numero = Texte(p, 13, true)
    p.numero:SetPoint("BOTTOM", p, "BOTTOM", 0, 0)
    p.numero:SetSize(largeur, 20)
    p.couverture = couverture
    return p
end

local function Remplir(p, feuille, style, numero, taille)
    p:SetShown(feuille ~= nil)
    if not feuille then return end
    p.titre:SetHeight(0)
    local tailleTitre = p.couverture and 28 or 24
    p.titre:SetFont(POLICE, tailleTitre, "")
    p.titre:SetText(feuille.titre or "")
    while tailleTitre > 18 and p.titre:GetStringHeight() > (p.couverture and 125 or 94) do
        tailleTitre = tailleTitre - 1
        p.titre:SetFont(POLICE, tailleTitre, "")
    end
    p.titre:SetTextColor(RGB(p.couverture and "E4C78E" or style.accent or "73512D"))
    p.texte:SetFont(POLICE, taille, "")
    p.texte:SetText(feuille.texte or "")
    p.texte:SetTextColor(RGB(p.couverture and "F1E4C6" or style.encre or "302317"))
    p.texte:SetJustifyH(p.couverture and "CENTER" or style.alignement or "LEFT")
    -- Deux zones distinctes de part et d'autre du motif de couverture.
    local haut = p.couverture and (p.hautTexte or 365) or ((feuille.titre or "") ~= ""
        and math.min(112, math.max(42, p.titre:GetStringHeight() + 18)) or 4)
    p.titre:SetHeight(p.couverture and 125 or math.max(1, haut - 10))
    p.zone:ClearAllPoints()
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -haut)
    p.zone:SetHeight(p.hauteur - haut - 30)
    p.zone:Regler(math.max(1, p.texte:GetStringHeight() + 12))
    p.zone:Aller(0)
    p.numero:SetText(numero and tostring(numero) or "")
    p.numero:SetTextColor(RGB(style.accent or "73512D"))
end

local function Disposer(p, parent, x, y, largeur, hauteur, hautTexte)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    p:SetSize(largeur, hauteur)
    p.largeur, p.hauteur, p.hautTexte = largeur, hauteur, hautTexte
    p.titre:SetWidth(largeur)
    p.zone:SetWidth(largeur)
    p.texte:SetWidth(largeur - 12)
    p.numero:SetWidth(largeur)
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_lecture_livre", UIParent)
    f.cle, f.defautPosition = "lecture_livre", { x = 0, y = 0 }
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.contenu, f.tailleTexte = f, 18
    UI.fenetres[#UI.fenetres + 1] = f
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = f:GetName() end
    local db = LCM.EnsureDatabase()
    local position = db.fenetres and db.fenetres[f.cle]
    if type(position) == "table" then
        f:ClearAllPoints()
        f:SetPoint(position.point or "CENTER", UIParent, position.relPoint or "CENTER", position.x or 0, position.y or 0)
    end
    f.ouvert, f.couverture, f.note = Surface(f, 940), Surface(f, 470), Surface(f, 470)
    f.gauche = Page(f.ouvert.lecture, 65, 69, 355, 505)
    f.droite = Page(f.ouvert.lecture, 520, 69, 355, 505)
    f.couverture.page = Page(f.couverture.lecture, 80, 88, 310, 485, true)
    f.note.page = Page(f.note.lecture, 56, 65, 358, 520)
    f.note.image:SetTexture(ART .. "chronique\\note.blp")
    for _, surface in ipairs({ f.ouvert, f.couverture, f.note }) do
        surface:EnableMouse(true)
        surface:RegisterForDrag("LeftButton")
        surface:SetScript("OnMouseDown", function() UI.Devant(f) end)
        surface:SetScript("OnDragStart", function(self) self.glisse = true; f:StartMoving() end)
        surface:SetScript("OnDragStop", function()
            f:StopMovingOrSizing()
            local point, _, relPoint, x, y = f:GetPoint()
            local database = LCM.EnsureDatabase()
            database.fenetres = database.fenetres or {}
            database.fenetres[f.cle] = { point = point, relPoint = relPoint, x = x, y = y }
        end)
    end
    f.couverture:SetScript("OnMouseUp", function(self, bouton)
        if self.glisse then self.glisse = nil; return end
        if bouton == "LeftButton" then f:Tourner(f.index == 1 and 1 or -1) end
    end)

    local function Bouton(label, largeur, action)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(largeur, 30)
        b.label = Texte(b, 15, true)
        b.label:SetAllPoints(b)
        b.label:SetJustifyV("MIDDLE")
        b.label:SetText(label)
        b.label:SetTextColor(.85, .72, .48)
        b.label:SetShadowColor(0, 0, 0, 1)
        b.label:SetShadowOffset(1, -1)
        b:SetScript("OnClick", action)
        b:SetScript("OnEnter", function(self) self.label:SetTextColor(1, .9, .68) end)
        b:SetScript("OnLeave", function(self) self.label:SetTextColor(.85, .72, .48) end)
        return b
    end
    f.precedent = Bouton("‹ Précédent", 115, function() f:Tourner(-1) end)
    f.suivant = Bouton("Suivant ›", 115, function() f:Tourner(1) end)
    f.fermer = Bouton("Fermer ×", 80, function() f:Fermer() end)
    f.fermer:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    f.compteur = Texte(f, 12, true)
    f.compteur:SetPoint("BOTTOM", f, "BOTTOM", 0, 42)
    f.compteur:SetSize(240, 20)
    f.compteur:SetTextColor(.43, .31, .17)
    f.zoom = Bouton("A+", 38, function()
        if f.animation then return end
        f.tailleTexte = f.tailleTexte == 18 and 21 or (f.tailleTexte == 21 and 24 or 18)
        f:AfficherPage()
    end)
    f.zoom:SetPoint("LEFT", f.fermer, "RIGHT", 4, 0)
    f.tourne = Animation.Creer(f)

    function f:SurfaceActive()
        if self.livre.format == "note" then return self.note end
        if self.index == 1 or self.index == #self.feuillets then return self.couverture end
        return self.ouvert
    end
    function f:AlphaTexte(alpha)
        for _, s in ipairs({ self.ouvert, self.couverture, self.note }) do s.lecture:SetAlpha(alpha) end
    end
    function f:AfficherPage()
        local surface = self:SurfaceActive()
        self.ouvert:SetShown(surface == self.ouvert)
        self.couverture:SetShown(surface == self.couverture)
        self.note:SetShown(surface == self.note)
        local style, feuilles = self.livre.style or {}, self.feuillets
        local necroOuvert = surface == self.ouvert and self.livre.modele == "necronicon"
        if surface == self.ouvert then
            local numero = self.index - 1
            Remplir(self.gauche, feuilles[self.index], style, numero, self.tailleTexte)
            Remplir(self.droite, numero < #self.livre.pages and feuilles[self.index + 1] or nil,
                style, numero + 1, self.tailleTexte)
            self.compteur:SetText(numero < #self.livre.pages and string.format("Pages %d–%d / %d", numero, numero + 1, #self.livre.pages)
                or string.format("Page %d / %d", numero, #self.livre.pages))
            if necroOuvert then
                self.gauche.numero:SetText(numero .. " / " .. #self.livre.pages)
                self.droite.numero:SetText((numero + 1) .. " / " .. #self.livre.pages)
            end
        else
            Remplir(surface.page, feuilles[self.index], style, nil, self.tailleTexte)
            self.compteur:SetText(feuilles[self.index].nature)
        end
        local dos = self.index == #feuilles and self.livre.format == "livre"
        self.couverture.image:SetTexCoord(dos and 1 or 0, dos and 0 or 1, 0, 1)
        self.precedent:ClearAllPoints()
        self.suivant:ClearAllPoints()
        self.precedent:SetPoint("BOTTOMLEFT", surface, "BOTTOMLEFT", 35, 8)
        self.suivant:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -35, 8)
        self.precedent:SetShown(self.index > 1)
        self.suivant:SetShown(self.index < #feuilles)
        self.suivant.label:SetText(self.index == 1 and self.livre.format == "livre" and "Ouvrir ›" or "Suivant ›")
        self.compteur:SetTextColor(RGB((surface == self.couverture or (surface == self.ouvert and self.livre.modele == "necronicon"))
            and "E4C78E" or style.encre or "73512D"))
        -- Le crane au pied de la reliure reste libre de textes et de boutons.
        self.compteur:SetShown(not necroOuvert)
        self.fermer:ClearAllPoints()
        self.fermer:SetPoint("BOTTOM", self, "BOTTOM", necroOuvert and -65 or 0, 8)
        self.zoom:ClearAllPoints()
        if necroOuvert then self.zoom:SetPoint("BOTTOM", self, "BOTTOM", 65, 8)
        else self.zoom:SetPoint("LEFT", self.fermer, "RIGHT", 4, 0) end
        self.zoom:Show()
    end
    function f:PositionSuivante(direction)
        local actuel, total = self.index, #self.feuillets
        if self.livre.format == "note" then return actuel + direction end
        if direction > 0 then return actuel == 1 and 2 or math.min(total, actuel + 2) end
        if actuel == total then return 2 + 2 * math.floor((#self.livre.pages - 1) / 2) end
        return math.max(1, actuel - 2)
    end
    function f:AnnulerAnimation()
        self.animation = nil
        self:SetScript("OnUpdate", nil)
        Animation.Arreter(self.tourne)
        self:AlphaTexte(1)
        if self.livre then self:AfficherPage() end
    end
    function f:TerminerAnimation()
        local a = self.animation
        self.index = a.cible
        self:AnnulerAnimation()
        if a.fermeture then self:Hide() end
    end
    function f:Animer(cible, fermeture)
        if self.animation then return end
        local note = self.livre.format == "note"
        local debutFerme = self:SurfaceActive() == self.couverture
        local finFermee = cible == 1 or cible == #self.feuillets
        local sequence = note and "note" or ((debutFerme or finFermee) and "opening" or "turning")
        local spec = Animation.Sequences[sequence]
        local inverse = sequence == "opening" and not debutFerme
        local miroir = sequence == "opening" and ((debutFerme and self.index == #self.feuillets)
            or (not debutFerme and cible == #self.feuillets)) or (sequence == "turning" and cible < self.index)
        self.animation = { cible = cible, fermeture = fermeture, sequence = sequence, temps = 0,
            attente = 0, phase = "attente", premier = inverse and spec.images - 1 or 0,
            dernier = inverse and 0 or spec.images - 1, miroir = miroir, duree = spec.duree }
        self.precedent:Hide(); self.suivant:Hide(); self.zoom:Hide(); self.compteur:Hide()
        self:SetScript("OnUpdate", function(cadre, dt)
            local a = cadre.animation
            if not a then return end
            if a.phase == "attente" then
                a.attente = a.attente + dt
                if not Animation.Pret(cadre.tourne, a.sequence) then
                    if a.attente > 5 then cadre:TerminerAnimation() end
                    return
                end
                a.phase, a.temps = "sortie", 0
                if PlaySound and SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_TURNPAGE then
                    PlaySound(SOUNDKIT.IG_SPELLBOOK_TURNPAGE, "SFX")
                end
            end
            -- A faible FPS, prolonger le mouvement au lieu de sauter des poses.
            local pas = math.min(dt, a.phase == "mouvement"
                and a.duree / math.max(1, math.abs(a.dernier - a.premier)) or .05)
            a.temps = a.temps + pas
            if a.phase == "sortie" then
                cadre:AlphaTexte(math.max(0, 1 - a.temps / FONDU))
                if a.temps >= FONDU then
                    if not Animation.Dessiner(cadre.tourne, a.sequence, a.premier, a.miroir) then return end
                    cadre.ouvert:Hide(); cadre.couverture:Hide(); cadre.note:Hide()
                    cadre.tourne:Show()
                    a.phase, a.temps = "mouvement", 0
                end
            elseif a.phase == "mouvement" then
                if not Animation.Pret(cadre.tourne, a.sequence) then a.temps = a.temps - pas; return end
                local p = math.min(1, a.temps / a.duree)
                Animation.Dessiner(cadre.tourne, a.sequence, math.floor(a.premier + (a.dernier - a.premier) * p + .5), a.miroir)
                if p == 1 then
                    cadre.index = a.cible
                    Animation.Arreter(cadre.tourne)
                    cadre:AfficherPage()
                    cadre.precedent:Hide(); cadre.suivant:Hide(); cadre.zoom:Hide()
                    cadre:AlphaTexte(0)
                    a.phase, a.temps = "entree", 0
                end
            else
                cadre:AlphaTexte(math.min(1, a.temps / FONDU))
                if a.temps >= FONDU then cadre:TerminerAnimation() end
            end
        end)
    end
    function f:Tourner(direction)
        if not self.feuillets or self.animation then return end
        local cible = self:PositionSuivante(direction < 0 and -1 or 1)
        if cible < 1 or cible > #self.feuillets or cible == self.index then return end
        self:Animer(cible)
    end
    function f:Fermer()
        self:AnnulerAnimation()
        if self:SurfaceActive() == self.ouvert then self:Animer(1, true) else self:Hide() end
    end
    function f:Ouvrir(livre)
        self:AnnulerAnimation()
        self.livre, self.feuillets, self.index = livre, Feuillets(livre), 1
        local modele = livre.modele or LCM.Livres.MODELE_DEFAUT
        if modele == "necronicon" then
            -- Les ferrures et le pendentif ont leurs propres marges reservees.
            Disposer(self.gauche, self.ouvert.lecture, 112, 94, 310, 468)
            Disposer(self.droite, self.ouvert.lecture, 518, 94, 310, 468)
            Disposer(self.couverture.page, self.couverture.lecture, 105, 170, 285, 385, 155)
        else
            Disposer(self.gauche, self.ouvert.lecture, 65, 69, 355, 505)
            Disposer(self.droite, self.ouvert.lecture, 520, 69, 355, 505)
            Disposer(self.couverture.page, self.couverture.lecture, 80, 88, 310, 485, 365)
        end
        self.ouvert.image:SetTexture(ART .. modele .. "\\ouvert.blp")
        self.couverture.image:SetTexture(ART .. modele .. "\\couverture.blp")
        Animation.Preparer(self.tourne, modele, livre.format == "note")
        local r, g, b = RGB(livre.style and livre.style.fond or "E5D3A3")
        local teinte = { math.min(1, r * 255 / 229), math.min(1, g * 255 / 211), math.min(1, b * 255 / 163) }
        for _, surface in ipairs({ self.ouvert, self.couverture, self.note }) do
            surface.image:SetVertexColor(unpack(teinte))
        end
        for _, image in ipairs(self.tourne.planches) do image:SetVertexColor(unpack(teinte)) end
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        self:SetScale(math.min(1, w > 0 and (w - 30) / LARGEUR or 1, h > 0 and (h - 30) / HAUTEUR or 1))
        self:AfficherPage()
        self:Show()
        UI.Devant(self)
    end
    f:SetScript("OnHide", function(self) self:AnnulerAnimation(); self:StopMovingOrSizing() end)
    f:Hide()
    return f
end

function Ecran.Ouvrir(ref)
    local livre = LCM.Compendium.Resoudre(ref)
    if not livre or tostring(ref or ""):match("^livres/") == nil then
        LCM.Alerte("livre inconnu du compendium."); return false
    end
    Ecran.frame = Ecran.frame or Construire()
    Ecran.frame:Ouvrir(livre)
    return true
end

function Ecran.Apercu(definition)
    local ok, livre = pcall(LCM.Livres.Construire, definition)
    if not ok then return false, livre end
    Ecran.frame = Ecran.frame or Construire()
    Ecran.frame:Ouvrir(livre)
    return true
end
