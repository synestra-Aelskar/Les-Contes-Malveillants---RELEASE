-- Lanterne physique attachee au crochet : corps BLP, cristal, jauges et levier.
local _, LCM = ...
local UI, L = LCM.UI, LCM.Lanterne
local Ecran = {}
UI.LanterneCeinture = Ecran
local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\lanterne\\"
local W, H = 210, 210 * 1438 / 1094

function Ecran.Lire()
    local secondes = math.max(0, L.Restant())
    local maximum = L.ChargeMax()
    return { present = L.CristalPose() ~= nil, allumee = L.Allumee(),
        charge = maximum > 0 and math.max(0, math.min(1, L.Charge() / maximum)) or 0,
        minutes = (secondes % 3600) / 60,
        heures = (secondes % 86400) / 3600,
        jours = secondes / 86400, secondes = secondes }
end

local function Duree()
    local s = math.floor(math.max(0, L.Restant()))
    return string.format("%d j · %02d h · %02d min", math.floor(s / 86400),
        math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60))
end

local function Retour(ok, raison)
    if not ok and raison then LCM.Alerte(raison) end
    if UI.Inventaires then UI.Inventaires.Actualiser() end
end

local function Zone(parent, x, y, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x * W, -y * H)
    b:SetSize(w * W, h * H)
    return b
end

local function Jauge(parent, x, y, w, h, nombre, libelle)
    local b = Zone(parent, x, y, w, h)
    b.remplissage = b:CreateTexture(nil, "ARTWORK")
    b.remplissage:SetColorTexture(0.03, 0.82, 0.40, 0.85)
    b.remplissage:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.remplissage:SetHeight(h * H)
    b.traits = {}
    for i = 1, nombre do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.78, 0.87, 0.66, 0.85)
        t:SetSize(0.6, h * H * (i % 5 == 0 and 0.7 or 0.4))
        t:SetPoint("TOP", b, "TOPLEFT", (i - 0.5) * w * W / nombre, 0)
        b.traits[i] = t
    end
    UI.Bulle(b, libelle, function() return Duree() .. " restantes" end)
    function b:Regler(valeur)
        self.valeur = valeur
        self.remplissage:SetWidth(math.max(0.01, w * W * math.min(1, valeur / nombre)))
        self.remplissage:SetShown(valeur > 0)
    end
    return b
end

function Ecran.Creer(parent, crochet)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(W, H)
    -- Le crochet descend par-dessus l'anneau, loge sous son arche.
    f:SetPoint("TOPLEFT", crochet, "CENTER", -0.872 * W, 0.14 * H)
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
    f:EnableMouse(false)
    f.corps = f:CreateTexture(nil, "BACKGROUND")
    f.corps:SetTexture(ART .. "corps.blp")
    f.corps:SetTexCoord(0, 0.735, 0, 1)
    f.corps:SetSize(W * 0.735, H)
    f.corps:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.flanc = f:CreateTexture(nil, "BACKGROUND")
    f.flanc:SetTexture(ART .. "corps.blp")
    f.flanc:SetTexCoord(0.735, 1, 0.30, 1)
    f.flanc:SetSize(W * 0.265, H * 0.70)
    f.flanc:SetPoint("TOPLEFT", f, "TOPLEFT", W * 0.735, -H * 0.30)
    f.crochet = f:CreateTexture(nil, "BACKGROUND")
    f.crochet:SetTexture(ART .. "crochet.blp")
    f.crochet:SetTexCoord(0.735, 1, 0, 0.30)
    f.crochet:SetSize(W * 0.265, H * 0.30)
    f.crochet:SetPoint("TOPLEFT", f, "TOPLEFT", W * 0.735, 0)

    f.cristal = f:CreateTexture(nil, "ARTWORK")
    f.cristal:SetTexture(ART .. "cristal.blp")
    f.cristal:SetTexCoord(0.34, 0.67, 0.06, 0.93)
    f.cristal:SetSize(W * 0.13, H * 0.285)
    f.cristal:SetPoint("CENTER", f, "TOPLEFT", W * 0.385, -H * 0.49)

    -- Les barreaux de facade passent DEVANT le cristal, depuis le meme BLP.
    f.barreaux = {}
    for _, rect in ipairs({ {0.297, 0.324, 0.33, 0.655}, {0.474, 0.509, 0.33, 0.655} }) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ART .. "corps.blp")
        t:SetTexCoord(rect[1], rect[2], rect[3], rect[4])
        t:SetSize((rect[2] - rect[1]) * W, (rect[4] - rect[3]) * H)
        t:SetPoint("TOPLEFT", f, "TOPLEFT", rect[1] * W, -rect[3] * H)
        f.barreaux[#f.barreaux + 1] = t
    end

    f.minutes = Jauge(f, 0.200, 0.746, 0.319, 0.023, 60, "Minutes · 60 graduations")
    f.heures = Jauge(f, 0.164, 0.809, 0.115, 0.022, 24, "Heures · 24 graduations")
    f.jours = Jauge(f, 0.437, 0.809, 0.118, 0.022, 6, "Jours · 6 graduations")

    f.interrupteur = Zone(f, 0.326, 0.79, 0.068, 0.085)
    f.interrupteur:ClearAllPoints()
    f.interrupteur:SetPoint("CENTER", f, "TOPLEFT", 0.36 * W, -0.85 * H)
    f.interrupteur:SetSize(30, 44)
    f.platine = f.interrupteur:CreateTexture(nil, "BACKGROUND")
    f.platine:SetTexture(ART .. "corps.blp")
    f.platine:SetTexCoord(0.326, 0.394, 0.79, 0.875)
    f.platine:SetSize(24, 42)
    f.platine:SetPoint("CENTER", f.interrupteur, "CENTER", 0, 0)
    local levier = f.interrupteur:CreateTexture(nil, "ARTWORK")
    levier:SetTexture(ART .. "levier.blp")
    levier:SetTexCoord(0.32, 0.68, 0.07, 0.93)
    levier:SetSize(12, 24)
    f.levier = levier
    f.interrupteur:SetScript("OnClick", function()
        Retour(L.Basculer())
        f:Actualiser()
    end)
    UI.Bulle(f.interrupteur, function() return L.Allumee() and "Éteindre" or "Allumer" end,
        function() return L.Allumee() and "Levier en haut · allumée" or "Levier en bas · éteint" end)

    local choix = UI.Choix("cristal_ceinture_" .. crochet.place, "Cristal de la lanterne")
    f.chambre = Zone(f, 0.215, 0.325, 0.31, 0.33)
    f.chambre:SetScript("OnClick", function(self)
        local options = {}
        if L.CristalPose() then options[#options + 1] = { id = false, label = "Retirer le cristal" } end
        for _, cristal in ipairs(L.CristauxPortes()) do
            options[#options + 1] = { id = cristal.id, label = cristal.label }
        end
        if #options == 0 then LCM.Alerte("aucun cristal dans tes sacs.") return end
        choix:Proposer(self, options, function(id)
            Retour(L.ChoisirCristal(id))
            f:Actualiser()
        end)
    end)
    UI.Bulle(f.chambre, function()
        return L.CristalPose() and L.LibelleCristal(L.CristalPose()) or "Aucun cristal"
    end, "Clique pour poser, changer ou retirer le cristal.")

    -- La porte laterale donne les interactions de l'objet sans cadre autour.
    f.porte = Zone(f, 0.59, 0.39, 0.13, 0.245)
    f.porte:SetScript("OnClick", function()
        UI.MenuContexte():Ouvrir(f.porte, {
            { label = "Paramètres", action = function() UI.Lanterne.Basculer() end },
            { label = "Retirer la lanterne", action = function()
                Retour(L.RetirerLanterne())
                parent:Afficher()
            end },
        })
    end)
    UI.Bulle(f.porte, "Lanterne", "Paramètres et retrait de la ceinture.")

    -- L'anneau de la ceinture passe devant le creux du crochet de lanterne.
    crochet:SetFrameLevel(parent:GetFrameLevel() + 5)
    f.raccord = crochet:CreateTexture(nil, "OVERLAY")
    local cx = crochet.place == 1 and 0.321 or 0.774
    local cy = crochet.place == 1 and 0.563 or 0.569
    f.raccord:SetTexture("Interface\\AddOns\\LesContesMalveillants\\ressources\\ceinture\\ceinture.blp")
    f.raccord:SetTexCoord(cx - 18 / 520, cx + 18 / 520, cy - 18 / 260, cy + 18 / 260)
    f.raccord:SetSize(36, 36)
    f.raccord:SetPoint("CENTER", crochet, "CENTER", 0, 0)

    function f:Actualiser()
        local etat = Ecran.Lire()
        self.etat = etat
        self.cristal:SetShown(etat.present)
        self.cristal:SetDesaturated(etat.charge <= 0)
        local lumiere = 0.23 + 0.77 * etat.charge
        self.cristal:SetVertexColor(lumiere, lumiere, lumiere, 1)
        self.minutes:Regler(etat.minutes)
        self.heures:Regler(etat.heures)
        self.jours:Regler(etat.jours)
        self.levier:ClearAllPoints()
        self.levier:SetRotation(etat.allumee and 0 or math.pi)
        self.levier:SetPoint("CENTER", self, "TOPLEFT", 0.36 * W,
            -0.85 * H + (etat.allumee and 8 or -8))
    end
    f:HookScript("OnHide", function() f.raccord:Hide() choix:Hide() end)
    f:HookScript("OnShow", function() f.raccord:Show() f:Actualiser() end)
    f:Hide()
    return f
end
