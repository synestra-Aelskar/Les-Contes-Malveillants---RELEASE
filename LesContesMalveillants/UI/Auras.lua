-- Les auras de la cible : celles du JEU (buffs et debuffs WoW), pas un etat LCM.
--
-- Le portrait compact du HUD remplace TargetFrame, et avec lui la rangee
-- d'icones d'auras que Blizzard pose dessous : on ne voyait plus ce qui
-- affectait sa cible (13 octobre 2026). Le bouton « Aura » sous le portrait
-- deplie juste en dessous un petit cadre d'icones, comme celles du jeu : le
-- survol donne l'infobulle du jeu, qui dit deja tout. Rien de plus — une
-- premiere version en fenetre complete, avec noms et sources, etait de trop.
--
-- Le cadre suit la cible : changer de cible le redessine, une aura qui tombe
-- ou arrive aussi (UNIT_AURA).

local _, LCM = ...
local UI = LCM.UI

local Auras = { icones = {} }
UI.Auras = Auras

local UNITE = "target"
local ICONE, ECART, COLONNES, MARGE = 26, 3, 6, 4
-- La duree s'ecrit sous l'icone, comme dans la barre d'auras du jeu.
local TEXTE_H = 11
-- Le jeu n'en porte jamais autant ; c'est un garde-fou contre une API qui
-- rendrait toujours quelque chose.
local MAX_PAR_SORTE = 80

-- Le client d'Epsilon parle l'API d'avant Dragonflight (UnitAura) ; un client
-- recent ne connait plus que C_UnitAuras. On lit celle qui repond, et on rend
-- la meme forme dans les deux cas.
local function Lire(unite, index, filtre)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local a = C_UnitAuras.GetAuraDataByIndex(unite, index, filtre)
        if not a then return nil end
        return { nom = a.name, icone = a.icon, piles = a.applications or 0,
                 type = a.dispelName, duree = a.duration or 0,
                 expiration = a.expirationTime or 0 }
    end
    if not UnitAura then return nil end
    local nom, icone, piles, type_, duree, expiration = UnitAura(unite, index, filtre)
    if not nom then return nil end
    return { nom = nom, icone = icone, piles = piles or 0, type = type_,
             duree = duree or 0, expiration = expiration or 0 }
end

function Auras.Liste(unite, filtre)
    local out = {}
    for index = 1, MAX_PAR_SORTE do
        local a = Lire(unite, index, filtre)
        if not a then break end
        a.index, a.filtre = index, filtre
        out[#out + 1] = a
    end
    return out
end

-- « 12s », « 4m », « 2h » ; une aura sans fin n'ecrit rien, comme le jeu.
function Auras.Restant(aura, maintenant)
    if (tonumber(aura.duree) or 0) <= 0 or (tonumber(aura.expiration) or 0) <= 0 then
        return ""
    end
    local reste = math.max(0, aura.expiration - (maintenant or GetTime()))
    if reste < 60 then return string.format("%ds", math.ceil(reste)) end
    if reste < 3600 then return string.format("%dm", math.ceil(reste / 60)) end
    return string.format("%dh", math.ceil(reste / 3600))
end

local function Icone(parent, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(ICONE, ICONE + TEXTE_H)
    b.texture = b:CreateTexture(nil, "ARTWORK")
    b.texture:SetSize(ICONE, ICONE)
    b.texture:SetPoint("TOP", b, "TOP", 0, 0)
    -- Le contour colore un debuff selon sa nature (magie, poison...), comme
    -- le cadre de cible du jeu.
    b.cadre = CreateFrame("Frame", nil, b)
    b.cadre:SetAllPoints(b.texture)
    b.lisere = UI.Bordure(b.cadre)
    b.piles = UI.Texte(b, "", UI.C.texte)
    UI.Police(b.piles, 10, "OUTLINE")
    b.piles:SetPoint("BOTTOMRIGHT", b.texture, "BOTTOMRIGHT", 1, 0)
    b.temps = UI.Texte(b, "", UI.C.texte)
    UI.Police(b.temps, 9, "OUTLINE")
    b.temps:SetPoint("TOP", b.texture, "BOTTOM", 0, -1)
    b.temps:SetJustifyH("CENTER")
    b:SetScript("OnEnter", function(self)
        if not (self.aura and GameTooltip and GameTooltip.SetUnitAura) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetUnitAura(UNITE, self.aura.index, self.aura.filtre)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    Auras.icones[index] = b
    return b
end

-- Le cadre est un enfant du portrait de cible : il en prend l'echelle, et
-- disparait avec lui quand on n'a plus de cible.
local function Construire()
    local hud = UI.HUD and UI.HUD.frame
    local carte = hud and hud.cible
    if not carte then return nil end
    local f = CreateFrame("Frame", nil, carte)
    f:SetPoint("TOP", carte.aura or carte, "BOTTOM", 0, -3)
    f.fond = UI.Aplat(f, UI.C.fond, "BACKGROUND")
    f.fond:SetAllPoints(f)
    UI.Bordure(f)
    f.vide = UI.Texte(f, "Aucune aura.", UI.C.discret)
    UI.Police(f.vide, 10)
    f.vide:SetPoint("CENTER", f, "CENTER")
    f.attente = 0
    -- Les durees s'egrenent une fois par seconde, et seulement cadre ouvert.
    f:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 1 then return end
        self.attente = 0
        Auras.Temps()
    end)
    f:SetScript("OnShow", function() Auras.Actualiser() end)
    f:Hide()
    Auras.frame = f
    return f
end

function Auras.Temps()
    local maintenant = GetTime()
    for _, b in ipairs(Auras.icones) do
        if b:IsShown() and b.aura then b.temps:SetText(Auras.Restant(b.aura, maintenant)) end
    end
end

-- Les benefiques d'abord, les nefastes sur leur propre rangee : on voit d'un
-- coup d'oeil ce qui aide et ce qui nuit.
function Auras.Actualiser()
    local f = Auras.frame
    if not (f and f:IsShown()) then return end
    local existe = UnitExists and UnitExists(UNITE)
    local utiles = existe and Auras.Liste(UNITE, "HELPFUL") or {}
    local nefastes = existe and Auras.Liste(UNITE, "HARMFUL") or {}
    f.utiles, f.nefastes = utiles, nefastes
    for _, b in ipairs(Auras.icones) do b:Hide() b.aura = nil end

    local pas, hauteurLigne = ICONE + ECART, ICONE + TEXTE_H + ECART
    local n, rangee, colonnesMax = 0, 0, 0
    local function Poser(liste)
        if #liste == 0 then return end
        for i, aura in ipairs(liste) do
            n = n + 1
            local b = Auras.icones[n] or Icone(f, n)
            local col = (i - 1) % COLONNES
            if i > 1 and col == 0 then rangee = rangee + 1 end
            colonnesMax = math.max(colonnesMax, col + 1)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", MARGE + col * pas, -MARGE - rangee * hauteurLigne)
            b.aura = aura
            b.texture:SetTexture(aura.icone)
            b.piles:SetText((tonumber(aura.piles) or 0) > 1 and tostring(aura.piles) or "")
            local couleur = aura.filtre == "HARMFUL" and DebuffTypeColor
                and DebuffTypeColor[(aura.type and aura.type ~= "") and aura.type or "none"]
            for _, trait in ipairs(b.lisere) do
                if couleur then
                    trait:SetColorTexture(couleur.r, couleur.g, couleur.b, 1)
                elseif aura.filtre == "HARMFUL" then
                    trait:SetColorTexture(0.8, 0, 0, 1)
                else
                    trait:SetColorTexture(UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.6)
                end
            end
            b:Show()
        end
        rangee = rangee + 1
    end
    Poser(utiles)
    Poser(nefastes)

    f.vide:SetShown(n == 0)
    if n == 0 then
        f:SetSize(90, 22)
    else
        f:SetSize(2 * MARGE + colonnesMax * pas - ECART, 2 * MARGE + rangee * hauteurLigne - ECART)
    end
    Auras.Temps()
end

function Auras.Basculer()
    local f = Auras.frame or Construire()
    if not f then return false end
    f:SetShown(not f:IsShown())
    return f:IsShown()
end

LCM.WhenReady(function()
    local veille = CreateFrame("Frame")
    veille:RegisterEvent("PLAYER_TARGET_CHANGED")
    veille:RegisterEvent("UNIT_AURA")
    veille:SetScript("OnEvent", function(_, evenement, unite)
        if evenement == "UNIT_AURA" and unite ~= UNITE then return end
        Auras.Actualiser()
    end)
    Auras.veille = veille
end)
