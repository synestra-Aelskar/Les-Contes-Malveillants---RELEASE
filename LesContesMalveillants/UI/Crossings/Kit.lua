-- ============================================================
--  Crossings — les widgets, habilles par LCM
--
--  Les ecrans de Crossings ont ete ecrits contre la boite a outils d'Omega
--  (OS2.UI, plus l'habillage bleu-gris de son UI_Style). On garde leur
--  logique et leur mise en page, mais chaque piece est construite ICI par le
--  Kit de LCM : un bouton de Crossings EST un UI.Bouton, une case un carre
--  d'or comme UI.Case, une fenetre une UI.Fenetre avec son cadre
--  A'hell'Raz'kah. Le joueur ne doit pas voir qu'il a change d'addon en
--  ouvrant la carte ou l'atelier.
--
--  C'est une TRADUCTION d'API, pas un second Kit : aucun dessin nouveau ne
--  vit ici, tout renvoie a UI/Kit.lua et UI/Skin.lua. Si un widget de LCM
--  change d'allure, Crossings suit.
--
--  Les noms (CreatePanelButton, ApplyLabel…) sont ceux que les ecrans
--  appellent ; les champs exposes (bgN, bgP, accent, highlight, surfaceBg)
--  sont ceux qu'ils touchent. Un ecran qui teinte un bouton en rouge pour
--  « Supprimer » passe par bgN : il doit exister, sinon la suppression
--  ressemble a n'importe quel autre bouton.
-- ============================================================

local ZG = LCMCrossings
local K = LCM.UI
local UI = {}
ZG.EditorUI = UI

local function rgb(c, a) return { c[1], c[2], c[3], a or c[4] or 1 } end

-- La palette d'Omega, rebranchee sur celle du Kit (UI.C).
UI.colors = {
    windowBg          = rgb(K.C.fond),
    border            = rgb(K.C.bordure),
    separator         = rgb(K.C.filet),
    separatorSoft     = rgb(K.C.filetDoux),
    title             = rgb(K.C.titre),
    text              = rgb(K.C.texte),
    textMuted         = rgb(K.C.discret),
    textSoft          = rgb(K.C.discret),
    label             = rgb(K.C.libelle),
    labelStrong       = rgb(K.C.titreBloc),
    warning           = rgb(K.C.plein),
    placeholder       = { 0.40, 0.40, 0.40, 1 },
    tabActive         = rgb(K.C.titre),
    tabInactive       = { 0.52, 0.50, 0.47, 1 },
    tabLine           = rgb(K.C.accent),
    panelButtonAccent = rgb(K.C.accent, 0.7),
    -- Les lignes de liste : le brun des champs du Kit, et la selection dans
    -- l'or de l'accent, comme une ligne choisie partout ailleurs dans LCM.
    rowBg             = { 0.035, 0.030, 0.023, 0.92 },
    rowSelection      = rgb(K.C.accent, 0.18),
}

local function Teinte(fs, c) if fs and c then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end end

function UI.ApplyTitle(fs) Teinte(fs, UI.colors.title) end
function UI.ApplyBodyText(fs) Teinte(fs, UI.colors.text) end
function UI.ApplyMutedText(fs) Teinte(fs, UI.colors.textMuted) end
function UI.ApplySoftText(fs) Teinte(fs, UI.colors.textSoft) end
function UI.ApplyLabel(fs) Teinte(fs, UI.colors.label) end
function UI.ApplyStrongLabel(fs) Teinte(fs, UI.colors.labelStrong) end
function UI.ApplyWarningText(fs) Teinte(fs, UI.colors.warning) end
function UI.ApplyPlaceholderText(fs) Teinte(fs, UI.colors.placeholder) end

function UI.ApplyWindowBackground(texture, alpha)
    if not texture then return end
    local c = K.C.fond
    texture:SetColorTexture(c[1], c[2], c[3], alpha or c[4])
end

function UI.ApplySeparator(texture, soft)
    if not texture then return end
    local c = soft and K.C.filetDoux or K.C.filet
    texture:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

function UI.ApplyTabState(button, active)
    if not button then return end
    if button.Selectionner then button:Selectionner(active) end
    if button.accent then button.accent:SetShown(active and true or false) end
end

-- Un panneau : le fond des fenetres du Kit et son filet. `soft` : la bordure
-- fine (UI.BordureFine), pour ce qui vit DANS une fenetre.
function UI.Surface(frame, soft)
    if frame.editorSurface then return end
    frame.editorSurface = true
    if not frame.bgN and not frame.bg then
        frame.surfaceBg = K.Aplat(frame, soft and { 0.035, 0.030, 0.023, 0.92 } or K.C.fond)
        frame.surfaceBg:SetAllPoints(frame)
    end
    if soft then K.BordureFine(frame, 0.25) else K.Bordure(frame) end
end

-- ── Boutons ────────────────────────────────────────────────────────────────

function UI.CreatePanelButton(parent, width, height, text)
    local b = K.Bouton(parent, text or "", width, height or 22)
    -- bgN / bgP : deux aplats TRANSPARENTS par-dessus le fond du Kit. Ils ne
    -- se voient que si un ecran les teinte (le rouge d'une suppression).
    b.bgN = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.bgN:SetAllPoints(b)
    b.bgN:SetColorTexture(0, 0, 0, 0)
    b.bgP = b:CreateTexture(nil, "BACKGROUND", nil, 3)
    b.bgP:SetAllPoints(b)
    b.bgP:SetColorTexture(0, 0, 0, 0)
    b.bgP:Hide()
    -- Le soulignement d'or : la marque de l'onglet ouvert. Cache par defaut :
    -- un bouton ordinaire du Kit n'en porte pas.
    b.accent = b:CreateTexture(nil, "ARTWORK")
    b.accent:SetHeight(2)
    b.accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 2)
    b.accent:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 2)
    b.accent:SetColorTexture(K.C.accent[1], K.C.accent[2], K.C.accent[3], 1)
    b.accent:Hide()
    b.highlight = b.survol
    -- Le texte du bouton est son `label` (UI.Bouton) : SetText / GetText et
    -- GetFontString y renvoient, comme sur un bouton a police du jeu.
    function b:SetText(t) self.label:SetText(t or "") end
    function b:GetText() return self.label:GetText() end
    function b:GetFontString() return self.label end
    b:HookScript("OnMouseDown", function(self) self.bgP:Show() end)
    b:HookScript("OnMouseUp", function(self) self.bgP:Hide() end)
    b:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
    b:HookScript("OnDisable", function(self) self:SetAlpha(0.4) end)
    return b
end

-- La croix du cadre (l'icone de l'atlas A'hell'Raz'kah), pour les petites
-- fenetres qui n'ont pas d'UI.Fenetre autour d'elles.
function UI.CreateCloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0, 0, 0, 0)
    b.label = K.Texte(b, "", K.C.discret)
    b.label:SetAllPoints(b)
    b.label:SetJustifyH("CENTER")
    if K.AelRef then
        b.icone = K.AelRef(b, 898, 102, 54, 54, "OVERLAY")
        b.icone:SetAllPoints(b)
    else
        b.label:SetText("×")
    end
    b.highlight = K.Aplat(b, K.C.survol, "HIGHLIGHT")
    b.highlight:SetAllPoints(b)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function UI.CreateAddButton(parent, onClick)
    local b = K.Bouton(parent, "+", 16, 16, onClick)
    Teinte(b.label, K.C.accent)
    b.bg = b.fond
    b.highlight = b.survol
    return b
end

-- ── Saisie ─────────────────────────────────────────────────────────────────

function UI.CreateStyledEditBox(parent, width, height, multiLine)
    local e = K.Champ(parent, width, height or 22)
    e:SetMaxLetters(multiLine and 512 or 128)
    e:SetMultiLine(multiLine and true or false)
    if multiLine then
        e:SetTextInsets(8, 8, 5, 5)
        -- Entree passe a la ligne dans un texte long, elle ne le valide pas.
        e:SetScript("OnEnterPressed", nil)
    end
    UI.ApplyBodyText(e)
    e.bg = e.fond
    return e
end

-- Une case du Kit (UI.Case), mais en CheckButton : les ecrans lisent
-- GetChecked / SetChecked, l'API du jeu.
function UI.CreateStyledCheckbox(parent, labelText)
    local b = CreateFrame("CheckButton", nil, parent)
    b:SetSize(18, 18)
    b.fond = K.Aplat(b, { 0.10, 0.10, 0.10, 1 })
    b.fond:SetAllPoints(b)
    K.Bordure(b, { 0.82, 0.66, 0.20, 1 })
    local coche = b:CreateTexture(nil, "ARTWORK")
    coche:SetColorTexture(0.82, 0.66, 0.20, 1)
    coche:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
    coche:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
    b:SetCheckedTexture(coche)
    local survol = b:CreateTexture(nil, "HIGHLIGHT")
    survol:SetAllPoints(b)
    survol:SetColorTexture(0.90, 0.78, 0.30, 0.22)
    b:SetHighlightTexture(survol)
    local label = K.Texte(parent, labelText or "", K.C.texte, "GameFontNormalSmall")
    b.label = label
    return b, label
end

-- Une pastille de couleur qui ouvre le selecteur du jeu.
function UI.CreateColorSwatch(parent, size, hasAlpha)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size or 20, size or 20)
    local bord = btn:CreateTexture(nil, "BACKGROUND")
    bord:SetAllPoints(btn)
    bord:SetColorTexture(K.C.bordure[1], K.C.bordure[2], K.C.bordure[3], 1)
    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    swatch:SetColorTexture(1, 1, 1, 1)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.15)
    btn.r, btn.g, btn.b, btn.a = 1, 1, 1, 1
    function btn:SetColor(r, g, b, a)
        self.r, self.g, self.b = r or self.r, g or self.g, b or self.b
        self.a = hasAlpha and (a or self.a or 1) or 1
        swatch:SetColorTexture(self.r, self.g, self.b, self.a)
    end
    btn:SetScript("OnClick", function(self)
        if not ColorPickerFrame then return end
        if ColorPickerFrame.SetupColorPickerAndShow then
            local function Apply()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = hasAlpha and ColorPickerFrame:GetColorAlpha() or 1
                self:SetColor(nr, ng, nb, na)
                if self.onColorChanged then self.onColorChanged(nr, ng, nb, na) end
            end
            ColorPickerFrame:SetupColorPickerAndShow({
                r = self.r, g = self.g, b = self.b,
                hasOpacity = hasAlpha, opacity = self.a or 1,
                swatchFunc = Apply, opacityFunc = Apply,
                cancelFunc = function(prev)
                    if prev then self:SetColor(prev.r, prev.g, prev.b, prev.opacity) end
                    if self.onColorChanged then self.onColorChanged(self.r, self.g, self.b, self.a) end
                end,
            })
        else
            -- Ancienne API : l'opacite se lit sur OpacitySliderFrame, INVERSEE
            -- (0 = opaque), d'ou le « 1 - » dans les deux sens.
            local pr, pg, pb, pa = self.r, self.g, self.b, self.a
            local function Apply()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = (hasAlpha and OpacitySliderFrame) and (1 - OpacitySliderFrame:GetValue()) or 1
                self:SetColor(nr, ng, nb, na)
                if self.onColorChanged then self.onColorChanged(nr, ng, nb, na) end
            end
            ColorPickerFrame.hasOpacity = hasAlpha
            ColorPickerFrame.opacity = 1 - (self.a or 1)
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc = Apply, Apply
            ColorPickerFrame.cancelFunc = function()
                self:SetColor(pr, pg, pb, pa)
                if self.onColorChanged then self.onColorChanged(self.r, self.g, self.b, self.a) end
            end
            ColorPickerFrame:SetColorRGB(self.r, self.g, self.b)
            ShowUIPanel(ColorPickerFrame)
        end
    end)
    return btn
end

-- Les menus deroulants du jeu (UIDropDownMenuTemplate), qui restent pour la
-- police et la musique de l'atelier : leurs listes passent devant la
-- fenetre, et leur bouton prend la teinte des champs du Kit.
function UI.StyleDropdown(dd, textLeft, textYOffset, textRightPad)
    local function Devant()
        local parent = dd:GetParent()
        local niveau = math.max(200, ((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or dd:GetFrameLevel() or 1) + 80)
        for i = 1, 2 do
            local liste = _G["DropDownList" .. i]
            if liste then
                liste:SetFrameStrata("TOOLTIP")
                liste:SetToplevel(true)
                liste:SetFrameLevel(niveau)
            end
        end
    end
    if dd.SetFrameStrata then
        local parent = dd:GetParent()
        if parent and parent.GetFrameStrata then dd:SetFrameStrata(parent:GetFrameStrata()) end
    end
    if dd.Button and not dd.Button.lcmDevant then
        dd.Button:HookScript("OnClick", Devant)
        dd.Button.lcmDevant = true
    end
    for i = 1, 2 do
        local liste = _G["DropDownList" .. i]
        if liste and not liste.lcmDevant then
            liste:HookScript("OnShow", Devant)
            liste.lcmDevant = true
        end
    end
    for _, morceau in ipairs({ dd.Left, dd.Middle, dd.Right }) do
        if morceau then morceau:SetVertexColor(0.30, 0.25, 0.18) end
    end
    if dd.Button then
        dd.Button:ClearAllPoints()
        dd.Button:SetPoint("RIGHT", dd, "RIGHT", -15, 3)
        dd.Button:SetSize(22, 22)
    end
    if dd.Text then
        UI.ApplyBodyText(dd.Text)
        dd.Text:SetJustifyH("LEFT")
        dd.Text:ClearAllPoints()
        dd.Text:SetPoint("LEFT", dd, "LEFT", textLeft or 18, textYOffset or 1)
        if dd.Button then dd.Text:SetPoint("RIGHT", dd.Button, "LEFT", textRightPad or -6, 0) end
    end
end

-- ── Liste deroulante et menu contextuel ────────────────────────────────────
-- La liste de Crossings garde ce que celle du Kit n'a pas (des titres de
-- section, la molette au-dela de dix lignes) ; elle prend l'allure du menu
-- contextuel du Kit (UI.MenuContexte) : fond noir, filet fin, lignes de 24.

local LIGNE, PAS, MAX_LIGNES = 24, 26, 10
local menu
local function Menu()
    if menu then return menu end
    menu = CreateFrame("Frame", "LCMCrossingsSelectMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    menu.fond = K.Aplat(menu, { 0.05, 0.05, 0.05, 1 })
    menu.fond:SetAllPoints(menu)
    K.BordureFine(menu, 0.35)
    menu:Hide()
    -- Un clic n'importe ou ailleurs referme la liste.
    local voile = CreateFrame("Button", nil, UIParent)
    voile:SetAllPoints(UIParent)
    voile:SetFrameStrata("FULLSCREEN")
    voile:Hide()
    voile:SetScript("OnClick", function() menu:Hide() end)
    menu.catcher, menu.rows, menu.list, menu.offset = voile, {}, {}, 0
    menu.more = K.Texte(menu, "", K.C.discret, "GameFontNormalSmall")
    menu.more:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -10, 6)
    menu:SetScript("OnHide", function(self)
        voile:Hide()
        self.owner, self.pick, self.current, self.width = nil, nil, nil, nil
    end)
    menu:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(math.max(0, #self.list - MAX_LIGNES), self.offset - delta))
        self:Render()
    end)
    function menu:Render()
        local owner = self.owner
        if not owner then return end
        local largeur = self.width or owner:GetWidth()
        for i = 1, MAX_LIGNES do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, self)
                row:SetHeight(LIGNE)
                row:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4 - (i - 1) * PAS)
                row.survol = K.Aplat(row, { 0.80, 0.70, 0.40, 0.12 }, "HIGHLIGHT")
                row.survol:SetAllPoints(row)
                row.mark = K.Aplat(row, K.C.accent, "ARTWORK")
                row.mark:SetSize(3, 16)
                row.mark:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.text = K.Texte(row, "", K.C.texte, "GameFontNormalSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.text:SetWordWrap(false)
                self.rows[i] = row
            end
            row:SetWidth(largeur - 8)
            local item = self.list[i + self.offset]
            if item then
                row.text:SetText(item.text or "")
                local courant = not item.title and self.current ~= nil and item.text == self.current
                row.mark:SetShown(courant)
                if item.title then UI.ApplyLabel(row.text)
                elseif courant then Teinte(row.text, K.C.accent)
                else UI.ApplyBodyText(row.text) end
                row:EnableMouse(not item.title)
                -- L'element est porte par la fermeture de CETTE ligne, pas
                -- par un compteur partage (le piege des boucles en Lua 5.1).
                local choisi = item
                row:SetScript("OnClick", function()
                    local pick = self.pick
                    self:Hide()
                    if pick then pick(choisi) end
                end)
                row:Show()
            else
                row:Hide()
            end
        end
        local montrees = math.min(#self.list, MAX_LIGNES)
        self.more:SetText(#self.list > MAX_LIGNES
            and string.format("Molette · %d-%d sur %d", self.offset + 1, self.offset + montrees, #self.list) or "")
        self:SetSize(largeur, math.max(1, montrees) * PAS + 6 + (#self.list > MAX_LIGNES and 18 or 0))
    end
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "LCMCrossingsSelectMenu")
    return menu
end

-- Un champ a choix : l'allure d'UI.Deroulant. `s.items()` rend
-- { {text=, value=, title=} }, `s.onSelect(value)` recoit le choix.
function UI.CreateSelect(parent, w, h)
    local s = K.Bouton(parent, "", w, h or 30)
    s.label:ClearAllPoints()
    s.label:SetPoint("LEFT", s, "LEFT", 10, 0)
    s.label:SetPoint("RIGHT", s, "RIGHT", -26, 0)
    s.label:SetJustifyH("LEFT")
    s.label:SetWordWrap(false)
    s.fleche = s:CreateTexture(nil, "OVERLAY")
    s.fleche:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    s.fleche:SetSize(14, 14)
    s.fleche:SetPoint("RIGHT", s, "RIGHT", -8, -3)
    s.enabled = true
    function s:SetText(t) self.label:SetText(t or "") end
    function s:GetText() return self.label:GetText() end
    function s:SetEnabled(on)
        self.enabled = on and true or false
        self:EnableMouse(self.enabled)
        self.label:SetAlpha(self.enabled and 1 or 0.45)
        self.fleche:SetAlpha(self.enabled and 1 or 0.3)
    end
    s:SetScript("OnClick", function(self)
        local m = Menu()
        if m:IsShown() and m.owner == self then m:Hide() return end
        m.owner, m.list, m.offset = self, self.items and self.items() or {}, 0
        m.current = self.label:GetText()
        m.pick = function(item)
            self:SetText(item.text)
            if self.onSelect then self.onSelect(item.value) end
        end
        -- La liste vit sur UIParent : elle reprend l'echelle du champ.
        m:SetScale(self:GetEffectiveScale() / UIParent:GetEffectiveScale())
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        m.catcher:Show()
        m:Show()
        m:Render()
    end)
    s:SetScript("OnHide", function(self) if menu and menu.owner == self then menu:Hide() end end)
    return s
end

-- Menu contextuel (clic droit) au curseur. items : { {text=, func=, title=} }.
function UI.OpenContextMenu(owner, items, width)
    local m = Menu()
    m:Hide()
    m.owner, m.list, m.offset, m.width = owner, items, 0, width or 200
    m.pick = function(item) if item.func then item.func() end end
    m:SetScale(1)
    local x, y = GetCursorPosition()
    local echelle = UIParent:GetEffectiveScale()
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / echelle, y / echelle)
    m.catcher:Show()
    m:Show()
    m:Render()
    return m
end

-- ── Fenetres ───────────────────────────────────────────────────────────────
-- Les fenetres de Crossings sont posees a la main, au pixel pres, depuis
-- leur coin haut-gauche. Plutot que de deplacer chaque controle, on GLISSE
-- la fenetre entiere dans une UI.Fenetre de LCM : son cadre, son titre
-- couronne, sa croix, sa place retenue et sa touche Echap. La fenetre de
-- Crossings devient le contenu, a sa taille exacte.
--
-- Ses Show / Hide / IsShown / SetScale / SetPoint / StartMoving passent
-- ensuite a la fenetre LCM : le code d'origine (« panel:Hide() »,
-- « win:SetScale(...) ») continue de dire ce qu'il veut dire. Ses OnShow et
-- OnHide se declenchent quand la fenetre LCM s'ouvre et se ferme, puisqu'elle
-- reste montree a l'interieur.
--
-- A appeler JUSTE APRES la creation, avant d'y accrocher des scripts.
--
-- `rogne` : la hauteur de l'ancien en-tete d'Omega, quand il ne contient
-- plus rien (son titre est parti dans la couronne). Le contenu remonte
-- d'autant, sous le filet d'or, au lieu de laisser une bande vide.
function UI.Habiller(frame, cle, titre, rogne)
    rogne = rogne or 0
    local largeur, hauteur = frame:GetWidth(), frame:GetHeight()
    local f = K.Fenetre("crossings_" .. cle, titre, largeur + 24, hauteur)
    local function Haut(h) return h - rogne + (f.insetHaut or 0) + (f.insetBas or 0) end
    f:SetHeight(Haut(hauteur))
    f:SetFrameStrata(frame:GetFrameStrata() or "HIGH")
    f.crossings = frame
    frame.fenetre = f

    -- Les methodes d'origine, prises AVANT de les recouvrir.
    local Show, SetPoint, ClearAllPoints = frame.Show, frame.SetPoint, frame.ClearAllPoints
    frame:SetParent(f.contenu)
    ClearAllPoints(frame)
    SetPoint(frame, "TOPLEFT", f.contenu, "TOPLEFT", 0, rogne)
    frame:SetSize(largeur, hauteur)
    Show(frame)

    function frame:Show() f:Show() end
    function frame:Hide() f:Hide() end
    function frame:IsShown() return f:IsShown() end
    function frame:IsVisible() return f:IsVisible() end
    function frame:SetShown(v) if v then f:Show() else f:Hide() end end
    function frame:SetScale(e) f:SetScale(e) end
    function frame:GetScale() return f:GetScale() end
    function frame:SetPoint(...)
        -- Les ancrages relatifs a la fenetre elle-meme n'ont plus de sens.
        local _, rel = ...
        if rel == frame then return end
        f:SetPoint(...)
    end
    function frame:ClearAllPoints() f:ClearAllPoints() end
    function frame:StartMoving() f:StartMoving() end
    -- Lacher passe par le OnDragStop de la fenetre LCM : c'est lui qui retient
    -- la place.
    function frame:StopMovingOrSizing()
        local script = f:GetScript("OnDragStop")
        if script then script(f) else f:StopMovingOrSizing() end
    end
    function frame:SetFrameStrata(s) f:SetFrameStrata(s) end
    -- Une fenetre qui change de taille (l'atelier passe a 1280 x 760 apres
    -- coup) emmene son cadre avec elle.
    local SetSize, SetWidth, SetHeight = frame.SetSize, frame.SetWidth, frame.SetHeight
    function frame:SetSize(l, h)
        SetSize(frame, l, h)
        f:SetSize(l + 24, Haut(h))
    end
    function frame:SetWidth(l) SetWidth(frame, l) f:SetWidth(l + 24) end
    function frame:SetHeight(h)
        SetHeight(frame, h)
        f:SetHeight(Haut(h))
    end
    function frame:SetClampedToScreen(v) f:SetClampedToScreen(v) end
    -- Le glisser d'origine a capture la methode StartMoving de la fenetre
    -- Crossings AVANT l'habillage : il deplacerait le contenu dans son cadre.
    -- On le rebranche sur la fenetre LCM, qui retient sa place.
    if frame:GetScript("OnDragStart") then
        frame:SetScript("OnDragStart", function() f:StartMoving() end)
        frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    end
    -- Le titre de la couronne, pour qui veut le changer en cours de route.
    function frame:Titre(t) f:Titre(t) end
    return f
end
