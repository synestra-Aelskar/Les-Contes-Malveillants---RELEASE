-- Le livre est la fenetre : papier, reliure et coins interactifs, sans panneau.
local _, LCM = ...
local UI = LCM.UI
local Ecran = {}
UI.Livres = Ecran

local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\livres\\"
local UV_LIVRE = { 0, 1, 170 / 1024, 853 / 1024 }
local UV_SIMPLE = { 0, 1, 128 / 1024, 896 / 1024 }
local DUREE = 0.92
local Animation = UI.LivresAnimation
local POLICE = "Interface\\AddOns\\LesContesMalveillants\\ressources\\bannieres\\polices\\Caudex-Regular.ttf"

local function RGB(hexa)
    hexa = tostring(hexa or "FFFFFF")
    return (tonumber(hexa:sub(1, 2), 16) or 255) / 255,
        (tonumber(hexa:sub(3, 4), 16) or 255) / 255,
        (tonumber(hexa:sub(5, 6), 16) or 255) / 255
end

local function Texte(parent, taille, titre)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(POLICE, taille, "")
    fs:SetShadowColor(0, 0, 0, 0)
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH(titre and "CENTER" or "LEFT")
    fs:SetWordWrap(true)
    if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(true) end
    return fs
end

local function Feuillets(livre)
    local feuilles = {}
    if livre.format == "livre" then
        local face = livre.couverture or {}
        feuilles[1] = { titre = face.titre and face.titre ~= "" and face.titre or livre.label,
            texte = face.texte or "", nature = "Couverture" }
    end
    for i, page in ipairs(livre.pages or {}) do
        feuilles[#feuilles + 1] = { titre = page.titre or "", texte = page.texte or "",
            nature = livre.format == "note" and (i == 1 and "Recto" or "Verso") or "Page" }
    end
    if livre.format == "livre" then
        local face = livre.dos or {}
        feuilles[#feuilles + 1] = { titre = face.titre or "", texte = face.texte or "", nature = "Dos" }
    end
    return feuilles
end

local function Surface(parent, fichier, largeur, hauteur, uv)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(largeur, hauteur)
    s:SetPoint("CENTER", parent, "CENTER", 0, 0)
    s.largeur, s.hauteur = largeur, hauteur
    s.image = s:CreateTexture(nil, "BACKGROUND")
    s.image:SetTexture(ART .. fichier .. ".tga")
    s.image:SetTexCoord(unpack(uv))
    s.image:SetAllPoints(s)
    s.lecture = CreateFrame("Frame", nil, s)
    s.lecture:SetAllPoints(s)
    return s
end

local function Page(parent, x, y, largeur, hauteur)
    local p = CreateFrame("Frame", nil, parent)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    p:SetSize(largeur, hauteur)
    p.largeur, p.hauteur = largeur, hauteur
    p.pageX, p.pageY = x, y
    p.titre = Texte(p, 22, true)
    p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
    p.titre:SetWidth(largeur - 8)
    p.numero = Texte(p, 11)
    p.numero:SetPoint("BOTTOM", p, "BOTTOM", 0, 0)
    p.numero:SetJustifyH("CENTER")
    p.zone = UI.Defilement(p)
    p.zone:SetWidth(largeur)
    -- Le rail est discret, dans la marge du papier, sans fond de panneau.
    p.zone.barre.gouttiere:SetAlpha(0)
    p.zone.barre.poignee.fond:SetColorTexture(0.46, 0.32, 0.13, 0.45)
    p.zone.barre:SetWidth(3)
    p.zone.barre.poignee:SetWidth(3)
    p.texte = Texte(p.zone.contenu, 14)
    p.texte:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, 0)
    p.texte:SetWidth(largeur - 4)
    return p
end

local function Remplir(p, feuille, style, numero, couverture)
    p:SetShown(feuille ~= nil)
    if not feuille then return end
    local er, eg, eb = RGB(couverture and "E6D5B5" or style.encre)
    local ar, ag, ab = RGB(couverture and "D9B876" or style.accent)
    p.titre:SetText(feuille.titre or "")
    p.titre:SetTextColor(ar, ag, ab)
    p.texte:SetText(feuille.texte or "")
    p.texte:SetTextColor(er, eg, eb)
    p.texte:SetJustifyH(couverture and "CENTER" or (style.alignement or "LEFT"))
    local haut = (feuille.titre or "") ~= "" and math.max(38, (p.titre:GetStringHeight() or 22) + 17) or 6
    p.zone:ClearAllPoints()
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -haut)
    p.zone:SetHeight(math.max(50, p.hauteur - haut - 27))
    p.zone:Regler((p.texte:GetStringHeight() or 0) + 12)
    p.zone:Aller(0)
    p.numero:SetText(numero and tostring(numero) or "")
    p.numero:SetTextColor(ar, ag, ab)
    Animation.Encrer(p)
end

local function Teinter(surface, style)
    -- Une teinte sur la texture complete conserve le relief et ne dessine
    -- aucun rectangle par-dessus le papier. Le preset Parchemin est neutre.
    local r, g, b = RGB(style.fond or "E5D3A3")
    surface.teinte = { math.min(1, r / (229 / 255)), math.min(1, g / (211 / 255)), math.min(1, b / (163 / 255)) }
    surface.image:SetVertexColor(unpack(surface.teinte))
end

local function Info(b, texte)
    b.aide = Texte(b, 10)
    b.aide:SetPoint("TOP", b, "BOTTOM", 0, -2)
    b.aide:SetWidth(145)
    b.aide:SetJustifyH("CENTER")
    b.aide:SetTextColor(0.74, 0.59, 0.34)
    b.aide:Hide()
    b:SetScript("OnEnter", function(self)
        if self.label then self.label:SetAlpha(0.9) end
        self.aide:SetText(type(texte) == "function" and texte() or texte)
        self.aide:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if self.label then self.label:SetAlpha(self.repos or 0) end
        self.aide:Hide()
    end)
end

local function Construire()
    -- Pas de UI.Fenetre : ni aplat noir, ni bordure rectangulaire, ni bandeau.
    local f = CreateFrame("Frame", "LCM_lecture_livre", UIParent)
    f.cle, f.defautPosition = "lecture_livre", { x = 50, y = 0 }
    f:SetSize(900, 600)
    f:SetPoint("CENTER", UIParent, "CENTER", 50, 0)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f.contenu = f
    UI.fenetres[#UI.fenetres + 1] = f
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = f:GetName() end
    local db = LCM.EnsureDatabase()
    local position = db.fenetres and db.fenetres[f.cle]
    if type(position) == "table" then
        f:ClearAllPoints()
        f:SetPoint(position.point or "CENTER", UIParent, position.relPoint or "CENTER", position.x or 50, position.y or 0)
    end

    f.ouvert = Surface(f, "necronicon-ouvert", 900, 600, UV_LIVRE)
    f.couverture = Surface(f, "necronicon-couverture", 400, 560, UV_SIMPLE)
    f.note = Surface(f, "note", 400, 550, UV_SIMPLE)
    f.gauche = Page(f.ouvert.lecture, 127, 89, 280, 365)
    f.droite = Page(f.ouvert.lecture, 494, 89, 280, 365)
    f.couverture.page = Page(f.couverture.lecture, 86, 150, 243, 277)
    f.couverture.page.titre:SetFont(POLICE, 27, "")
    f.couverture.indice = Texte(f.couverture.lecture, 12)
    f.couverture.indice:SetPoint("BOTTOM", f.couverture, "BOTTOM", 14, 67)
    f.couverture.indice:SetTextColor(0.85, 0.70, 0.43)
    f.couverture.indice:SetAlpha(0)
    f.couverture:SetScript("OnEnter", function(self) self.indice:SetAlpha(0.85) end)
    f.couverture:SetScript("OnLeave", function(self) self.indice:SetAlpha(0) end)
    f.note.page = Page(f.note.lecture, 54, 72, 292, 411)

    -- Toute partie libre du volume, notamment la reliure, permet de le deplacer.
    for _, s in ipairs({ f.ouvert, f.couverture, f.note }) do
        s:EnableMouse(true)
        s:RegisterForDrag("LeftButton")
        s:SetScript("OnMouseDown", function() UI.Devant(f) end)
        s:SetScript("OnDragStart", function(self) self.glisse = true; f:StartMoving() end)
        s:SetScript("OnDragStop", function()
            f:StopMovingOrSizing()
            local point, _, relatif, x, y = f:GetPoint()
            local database = LCM.EnsureDatabase()
            database.fenetres = database.fenetres or {}
            database.fenetres[f.cle] = { point = point, relPoint = relatif, x = x, y = y }
        end)
    end
    f.couverture:SetScript("OnMouseUp", function(self, bouton)
        if self.glisse then self.glisse = nil; return end
        if bouton == "LeftButton" then f:Tourner(f.index == 1 and 1 or -1) end
    end)

    local function Coin(direction)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(67, 53)
        b.label = Texte(b, 26)
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.label:SetText(direction < 0 and "<" or ">")
        b.label:SetTextColor(0.43, 0.29, 0.12)
        b.label:SetAlpha(0)
        b:SetScript("OnClick", function() f:Tourner(direction) end)
        Info(b, direction < 0 and "Page précédente" or "Page suivante")
        return b
    end
    f.precedent, f.suivant = Coin(-1), Coin(1)
    f.fermer = CreateFrame("Button", nil, f)
    f.fermer.label = Texte(f.fermer, 12)
    f.fermer.label:SetPoint("CENTER", f.fermer, "CENTER", 0, 0)
    f.fermer.label:SetJustifyH("CENTER")
    f.fermer.label:SetTextColor(0.89, 0.76, 0.48)
    f.fermer:SetScript("OnClick", function() f:Hide() end)
    Info(f.fermer, "Fermer · Échap")
    f.compteur = Texte(f, 11)
    f.compteur:Hide() -- informations de lecture pour l'infobulle de la reliure.

    f.tourne = Animation.Creer(f)
    f.brouillon = Page(f, 0, 0, 280, 365)
    f.brouillon:Hide()

    function f:SurfaceActive()
        if self.livre.format == "note" then return self.note end
        if self.index == 1 or self.index == #self.feuillets then return self.couverture end
        return self.ouvert
    end

    function f:AfficherPage()
        local feuilles, style = self.feuillets, self.livre.style or {}
        local surface = self:SurfaceActive()
        self.couverture.indice:SetText(self.index == 1 and "Ouvrir l’ouvrage" or "Reprendre la lecture")
        self.ouvert:SetShown(surface == self.ouvert)
        self.couverture:SetShown(surface == self.couverture)
        self.note:SetShown(surface == self.note)
        self:SetSize(surface.largeur, surface.hauteur)
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        self:SetScale(math.min(1, w > 0 and (w - 30) / 900 or 1, h > 0 and (h - 30) / 600 or 1))
        if surface == self.ouvert then
            local numero, nombre = self.index - 1, #self.livre.pages
            Remplir(self.gauche, feuilles[self.index], style, numero)
            Remplir(self.droite, numero < nombre and feuilles[self.index + 1] or nil, style, numero + 1)
            Teinter(surface, style)
            self.compteur:SetText(numero < nombre and string.format("Pages %d–%d / %d", numero, numero + 1, nombre)
                or string.format("Page %d / %d", numero, nombre))
        else
            Remplir(surface.page, feuilles[self.index], style,
                surface == self.note and feuilles[self.index].nature or nil, surface == self.couverture)
            if surface == self.note then Teinter(surface, style) end
            self.compteur:SetText(feuilles[self.index].nature)
        end
        self.precedent:ClearAllPoints()
        self.suivant:ClearAllPoints()
        self.fermer:ClearAllPoints()
        if surface == self.ouvert then
            self.precedent:SetPoint("BOTTOMLEFT", surface, "BOTTOMLEFT", 102, 115)
            self.suivant:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -102, 115)
            self.fermer:SetSize(47, 68)
            self.fermer:SetPoint("BOTTOM", surface, "BOTTOM", 0, 0)
            self.fermer.label:SetText("Fermer")
            self.fermer.repos = 0
        else
            self.precedent:SetPoint("BOTTOMLEFT", surface, "BOTTOMLEFT", 30, 28)
            self.suivant:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", -30, 28)
            self.fermer:SetSize(30, 30)
            self.fermer:SetPoint("TOPRIGHT", surface, "TOPRIGHT", -22, -27)
            self.fermer.label:SetText("×")
            self.fermer.repos = 0.5
        end
        self.fermer.label:SetAlpha(self.fermer.repos)
        self.precedent.aide:Hide()
        self.suivant.aide:Hide()
        self.fermer.aide:Hide()
        self.precedent:SetShown(self.index > 1)
        self.suivant:SetShown(self.index < #feuilles)
    end

    function f:PositionSuivante(direction)
        local actuel, total = self.index or 1, #self.feuillets
        if self.livre.format == "note" then return actuel + direction end
        if direction > 0 then return actuel == 1 and 2 or math.min(total, actuel + 2) end
        if actuel == total then return 2 + 2 * math.floor((#self.livre.pages - 1) / 2) end
        return math.max(1, actuel - 2)
    end

    function f:CapturerFeuillet(feuille, modele, cote, mode, numero)
        local p = self.brouillon
        p.largeur,p.hauteur,p.pageX,p.pageY=modele.largeur,modele.hauteur,modele.pageX,modele.pageY
        p:SetSize(p.largeur,p.hauteur)
        p.zone:SetWidth(p.largeur)
        p.texte:SetWidth(p.largeur-4)
        p.titre:SetWidth(p.largeur-8)
        p.titre:SetFont(POLICE,mode=="couverture" and 27 or 22,"")
        Remplir(p,feuille,self.livre.style or {},numero,mode=="couverture")
        local encre=Animation.Capturer(p,cote,mode)
        p:Hide()
        return encre
    end

    function f:AnnulerAnimation()
        self.animation = nil
        self:SetScript("OnUpdate", nil)
        self.tourne:Hide()
        self.gauche:SetAlpha(1)
        self.droite:SetAlpha(1)
        for _, s in ipairs({ self.ouvert, self.couverture, self.note }) do
            s:SetAlpha(1)
            s.image:ClearAllPoints()
            s.image:SetAllPoints(s)
            s.lecture:SetAlpha(1)
        end
    end

    function f:Tourner(direction)
        if not self.feuillets or self.animation then return end
        direction = direction < 0 and -1 or 1
        local cible = self:PositionSuivante(direction)
        if cible < 1 or cible > #self.feuillets or cible == self.index then return end
        self.precedent.aide:Hide()
        self.suivant.aide:Hide()
        local depart = self:SurfaceActive()
        local versPage = self.livre.format == "livre" and cible > 1 and cible < #self.feuillets
        local mode = self.livre.format=="note" and "note" or
            (depart==self.couverture and "ouvrir" or (versPage and "feuille" or "fermer"))
        local recto,verso
        local feuilles,style=self.feuillets,self.livre.style or {}
        if mode=="feuille" then
            local source=direction>0 and self.droite or self.gauche
            local arrivee=direction>0 and self.gauche or self.droite
            recto=Animation.Capturer(source,direction)
            local i=direction>0 and cible or cible+1
            verso=self:CapturerFeuillet(i<#feuilles and feuilles[i] or nil,arrivee,-direction,nil,i-1)
            -- La page dessous est deja la suivante. L'autre page ne change pas
            -- tant que le feuillet qui la recouvre n'est pas retombe.
            local dessous=direction>0 and cible+1 or cible
            Remplir(source,dessous<#feuilles and feuilles[dessous] or nil,style,dessous-1)
        elseif mode=="ouvrir" then
            recto=Animation.Capturer(self.couverture.page,1,"couverture")
            verso=self:CapturerFeuillet(feuilles[cible],self.gauche,-1,nil,cible-1)
            local ancien=self.index
            self.index=cible;self:AfficherPage();self.index=ancien
            self.ouvert:SetAlpha(0);self.gauche:SetAlpha(0)
        elseif mode=="fermer" then
            recto=self:CapturerFeuillet(feuilles[cible],self.couverture.page,1,"couverture")
            verso=Animation.Capturer(self.gauche,-1)
            self.gauche:SetAlpha(0)
        else
            recto=Animation.Capturer(self.note.page,1,"note")
            verso=self:CapturerFeuillet(feuilles[cible],self.note.page,-1,"note",feuilles[cible].nature)
            self.note:Hide()
        end
        self.animation = { temps=0,cible=cible,direction=mode=="feuille" and direction or 1,
            mode=mode,depart=depart,recto=recto,verso=verso }
        self.precedent:Hide();self.suivant:Hide()
        self.tourne:SetFrameLevel(self:GetFrameLevel()+30)
        self.tourne:Show()
        Animation.Rendre(self.tourne,0,self.animation.direction,mode,recto,verso,self.ouvert.teinte or {1,1,1})
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_TURNPAGE then
            PlaySound(SOUNDKIT.IG_SPELLBOOK_TURNPAGE, "SFX")
        end
        self:SetScript("OnUpdate", function(cadre, dt)
            local a = cadre.animation
            if not a then return end
            a.temps = a.temps + (dt or 0)
            local p = math.min(1, a.temps / DUREE)
            if a.mode=="ouvrir" then cadre.ouvert:SetAlpha(math.min(1,p*4)) end
            if a.mode=="fermer" then cadre.ouvert:SetAlpha(math.min(1,(1-p)*4)) end
            Animation.Rendre(cadre.tourne,p,a.direction,a.mode,a.recto,a.verso,cadre.ouvert.teinte or {1,1,1})
            if p>=1 then
                cadre.index=a.cible
                cadre:AnnulerAnimation()
                cadre:AfficherPage()
            end
        end)
    end

    function f:Ouvrir(livre)
        self:AnnulerAnimation()
        self.livre, self.feuillets, self.index = livre, Feuillets(livre), 1
        self:AfficherPage()
        self:Show()
        UI.Devant(self)
    end
    f:SetScript("OnHide", function(self)
        self:AnnulerAnimation()
        self:StopMovingOrSizing()
        if self.livre then self:AfficherPage() end
    end)
    f:Hide()
    return f
end

function Ecran.Ouvrir(ref)
    local livre = LCM.Compendium.Resoudre(ref)
    if not livre or tostring(ref or ""):match("^livres/") == nil then
        LCM.Alerte("livre inconnu du compendium.")
        return false
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
