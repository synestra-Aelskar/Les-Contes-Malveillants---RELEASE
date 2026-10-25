-- Radar du scanner du Val'Razkah et sa console de pose MJ.
local _, LCM = ...
local UI, P = LCM.UI, LCM.PuitsTonnerre
local Scanner = {}
UI.Scanner = Scanner

local RAYON = 200
local TAILLE = 240
local MAX_POINTS = 24

local function Construire()
    local f = UI.Fenetre("scanner_valrazkah", "Scanner à haute fréquence", 390, 540,
        { x = 210, y = -20 })
    Scanner.frame = f
    f:SousTitre("Puits de tonnerre · Val'Razkah")
    local c = f.contenu
    local radar = CreateFrame("Frame", nil, c)
    f.radar = radar
    radar:SetSize(TAILLE, TAILLE)
    radar:SetPoint("TOP", c, "TOP", 0, -10)
    local fond = UI.Aplat(radar, { 0.025, 0.09, 0.10, 0.95 })
    fond:SetAllPoints(radar)
    UI.Bordure(radar, { 0.25, 0.72, 0.67, 0.85 })

    -- Grille fixe en coordonnees du monde ; le joueur reste au centre.
    for i = 1, 3 do
        local delta = i * TAILLE / 8
        for _, signe in ipairs({ -1, 1 }) do
            local v = UI.Aplat(radar, { 0.15, 0.45, 0.46, 0.30 }, "ARTWORK")
            v:SetSize(1, TAILLE)
            v:SetPoint("CENTER", radar, "CENTER", signe * delta, 0)
            local h = UI.Aplat(radar, { 0.15, 0.45, 0.46, 0.30 }, "ARTWORK")
            h:SetSize(TAILLE, 1)
            h:SetPoint("CENTER", radar, "CENTER", 0, signe * delta)
        end
    end
    local axeX = UI.Aplat(radar, { 0.29, 0.75, 0.69, 0.55 }, "ARTWORK")
    axeX:SetSize(TAILLE, 1)
    axeX:SetPoint("CENTER", radar, "CENTER")
    local axeY = UI.Aplat(radar, { 0.29, 0.75, 0.69, 0.55 }, "ARTWORK")
    axeY:SetSize(1, TAILLE)
    axeY:SetPoint("CENTER", radar, "CENTER")
    local curseur = UI.Aplat(radar, { 0.90, 0.82, 0.48, 1 }, "OVERLAY")
    curseur:SetSize(7, 7)
    curseur:SetPoint("CENTER", radar, "CENTER")
    f.points = {}
    for i = 1, MAX_POINTS do
        local dot = UI.Aplat(radar, { 0.40, 0.96, 0.87, 1 }, "OVERLAY")
        dot:SetSize(6, 6)
        dot:Hide()
        f.points[i] = dot
    end

    f.info = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
    f.info:SetPoint("TOP", radar, "BOTTOM", 0, -12)
    f.info:SetWidth(345)
    f.info:SetJustifyH("CENTER")
    f.portee = UI.Texte(c, "Portée : 200 m · centre : votre position", UI.C.discret,
        "GameFontNormalSmall")
    f.portee:SetPoint("TOP", f.info, "BOTTOM", 0, -8)
    f.portee:SetWidth(345)
    f.portee:SetJustifyH("CENTER")

    if LCM.IsMaster() then
        f.console = UI.Texte(c, "Console MJ · puits de tonnerre", UI.C.titre,
            "GameFontNormalSmall")
        f.console:SetPoint("TOPLEFT", c, "TOPLEFT", 18, -325)
        f.poser = UI.Bouton(c, "Poser un puits ici", 155, 24, function()
            local ok, raison = P.Poser()
            if not ok then LCM.Alerte(raison) else LCM.Info("puits de tonnerre posé.") end
            f:Afficher()
        end)
        f.poser:SetPoint("TOPLEFT", f.console, "BOTTOMLEFT", 0, -9)
        f.retirer = UI.Bouton(c, "Retirer le plus proche", 160, 24, function()
            local position = P.Position()
            local proche = P.PlusProche(position, 15)
            if not proche then return LCM.Alerte("aucun puits à moins de 15 m.") end
            local point
            for _, p in ipairs(P.Tous()) do if p.id == proche.id then point = p; break end end
            if point and point.auteur ~= LCM.PlayerId() then
                return LCM.Alerte("seul l'auteur de ce puits peut le retirer.")
            end
            local ok, raison = P.Retirer(proche.id)
            if not ok then LCM.Alerte(raison) else LCM.Info("puits retiré.") end
            f:Afficher()
        end)
        f.retirer:SetPoint("LEFT", f.poser, "RIGHT", 8, 0)
    end

    local dernierGPS = -10
    function f:Afficher()
        local position = P.Position()
        self.position = position
        self.echos = P.Echos(position, RAYON)
        if not position then
            self.info:SetText("Position indisponible : le scanner attend le GPS.")
            local maintenant = GetTime and GetTime() or 0
            if maintenant - dernierGPS >= 5 then
                dernierGPS = maintenant
                LCM.DeplacementForce.DemanderGPS(false, true)
            end
        elseif #self.echos == 0 then
            self.info:SetText("Aucun écho dans la portée.")
        else
            self.info:SetText(string.format("%d écho(s) · plus proche à %.0f m", #self.echos,
                self.echos[1].distance))
        end
        for i, dot in ipairs(self.points) do
            local echo = self.echos[i]
            dot:ClearAllPoints()
            if echo then
                dot:SetPoint("CENTER", radar, "CENTER", echo.x * (TAILLE / 2 - 8),
                    -echo.y * (TAILLE / 2 - 8))
                dot:SetSize(5 + echo.intensite * 5, 5 + echo.intensite * 5)
                dot:Show()
            else dot:Hide() end
        end
    end

    local cumul = 0
    f:SetScript("OnUpdate", function(self, ecoule)
        local entity = LCM.Entities.Self()
        if not (entity and LCM.Objets.Porte(entity, "outil_scanner_valrazkah")) then
            self:Hide()
            return
        end
        cumul = cumul + (tonumber(ecoule) or 0)
        if cumul < 0.2 then return end
        cumul = 0
        self:Afficher()
        local t = GetTime and GetTime() or 0
        for i, dot in ipairs(self.points) do
            local echo = self.echos[i]
            if echo then
                local vitesse = 2 + echo.intensite * 5
                dot:SetAlpha(0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * vitesse * 6 + i)))
            end
        end
    end)
    f:HookScript("OnShow", function(self) self:Afficher() end)
    P.onChange = function() if f:IsShown() then f:Afficher() end end
    f:Hide()
    return f
end

function Scanner.Fenetre()
    if not Scanner.frame then Construire() end
    return Scanner.frame
end

function Scanner.Basculer()
    local entity = LCM.Entities.Self()
    if not (entity and LCM.Objets.Porte(entity, "outil_scanner_valrazkah")) then
        return false, "équipe le scanner (Équipements › Outils) pour le voir."
    end
    local f = Scanner.Fenetre()
    f:SetShown(not f:IsShown())
    return true
end
