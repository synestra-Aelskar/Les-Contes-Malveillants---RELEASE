-- Bandeau affiche lorsqu'un personnage RECOIT de l'experience du MJ.
-- Il ne depend d'aucune fenetre ouverte et disparait apres quatre secondes.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Experience = Ecran

local DUREE = 4
local LARGEUR, HAUTEUR = 720, 132
local TEXTURE_FOND = "Interface\\AddOns\\LesContesMalveillants\\ressources\\hud\\panneau-fondu.tga"

-- Le client Epsilon gere mal SetGradient avec de la transparence. Le HUD
-- fournit deja un vrai fondu alpha continu : on le reutilise ici afin de ne
-- plus simuler le degrade avec une succession de bandes visibles.
local function HabillerBandeau(parent, marge)
    marge = tonumber(marge) or 34

    local fond = parent:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(TEXTURE_FOND)
    fond:SetAllPoints(parent)
    parent.fond = fond

    local haut = UI.Aplat(parent, { 0.78, 0.57, 0.24, 0.72 }, "ARTWORK")
    haut:SetPoint("TOPLEFT", parent, "TOPLEFT", marge, -4)
    haut:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -marge, -4)
    haut:SetHeight(1)
    parent.haut = haut

    local bas = UI.Aplat(parent, { 0.46, 0.30, 0.12, 0.48 }, "ARTWORK")
    bas:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", marge, 4)
    bas:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -marge, 4)
    bas:SetHeight(1)
    parent.bas = bas
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_GainExperience", UIParent)
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetPoint("TOP", UIParent, "TOP", 0, -145)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)

    HabillerBandeau(f, 42)

    f.titre = UI.Texte(f, "GAIN D'EXPÉRIENCE !", UI.C.titre)
    UI.Police(f.titre, 22, "OUTLINE")
    f.titre:SetPoint("TOP", f, "TOP", 0, -19)
    f.titre:SetWidth(LARGEUR - 80)
    f.titre:SetJustifyH("CENTER")

    f.gain = UI.Texte(f, "", UI.C.texte)
    UI.Police(f.gain, 17)
    f.gain:SetPoint("TOP", f.titre, "BOTTOM", 0, -12)
    f.gain:SetWidth(LARGEUR - 100)
    f.gain:SetJustifyH("CENTER")

    f.motif = UI.Texte(f, "", UI.C.discret)
    UI.Police(f.motif, 13)
    f.motif:SetPoint("TOP", f.gain, "BOTTOM", 0, -9)
    f.motif:SetWidth(LARGEUR - 110)
    f.motif:SetJustifyH("CENTER")
    f.motif:SetWordWrap(true)

    -- Un second bandeau, plus court, accompagne uniquement le franchissement
    -- d'un palier. Il reste separe du gain d'XP : les deux informations se
    -- lisent d'un coup sans agrandir artificiellement le premier cadre.
    f.niveau = CreateFrame("Frame", nil, f)
    f.niveau:SetSize(560, 72)
    f.niveau:SetPoint("TOP", f, "BOTTOM", 0, -6)
    HabillerBandeau(f.niveau, 34)
    f.niveau.titre = UI.Texte(f.niveau, "", UI.C.titre)
    UI.Police(f.niveau.titre, 17, "OUTLINE")
    f.niveau.titre:SetPoint("TOP", f.niveau, "TOP", 0, -13)
    f.niveau.titre:SetWidth(520)
    f.niveau.titre:SetJustifyH("CENTER")
    f.niveau.felicitations = UI.Texte(f.niveau, "Félicitation !", UI.C.texte)
    UI.Police(f.niveau.felicitations, 13)
    f.niveau.felicitations:SetPoint("TOP", f.niveau.titre, "BOTTOM", 0, -8)
    f.niveau:Hide()

    f:SetScript("OnUpdate", function(self, ecoule)
        self.reste = (self.reste or 0) - (tonumber(ecoule) or 0)
        -- Trois secondes de lecture, puis une seconde de fondu.
        self:SetAlpha(math.max(0, math.min(1, self.reste)))
        if self.reste <= 0 then self:Hide() end
    end)
    f:Hide()
    Ecran.frame = f
    return f
end

local function EffetNiveau(monte)
    if not monte or type(SendChatMessage) ~= "function" then return false end
    -- Commande Epsilon : le sort remplace entierement la musique de niveau.
    return pcall(SendChatMessage, ".cast 194901", "SAY") and true or false
end

function Ecran.Afficher(montant, motif, resultat)
    local f = Ecran.frame or Construire()
    montant = math.max(0, math.floor(tonumber(montant) or 0))
    motif = tostring(motif or ""):gsub("^%s+", ""):gsub("%s+$", "")
    f.gain:SetText(string.format("Vous gagnez %d expérience", montant))
    f.motif:SetText("Motif : " .. (motif ~= "" and motif or "Non précisé"))
    f.reste = DUREE
    f:SetAlpha(1)
    f:Show()
    local monte = type(resultat) == "table" and resultat.monte or resultat == true
    if monte then
        local avant = type(resultat) == "table" and tonumber(resultat.avant) or nil
        local apres = type(resultat) == "table" and tonumber(resultat.apres) or nil
        if avant and apres then
            f.niveau.titre:SetText(string.format("GAIN DE NIVEAU : %d > %d", avant, apres))
        else
            f.niveau.titre:SetText("GAIN DE NIVEAU !")
        end
        f.niveau:Show()
    else
        f.niveau:Hide()
    end
    EffetNiveau(monte)
    return f
end

LCM.WhenReady(function()
    local avant = LCM.Experience.onReception
    LCM.Experience.onReception = function(_, montant, motif, expediteur, resultat)
        if avant then avant(_, montant, motif, expediteur, resultat) end
        Ecran.Afficher(montant, motif, resultat)
    end
end)

-- Bandeau de regain : meme langage visuel que l'experience, sans icone.
local RegainEcran = {}
UI.Regain = RegainEcran

local function ConstruireRegain()
    local f = CreateFrame("Frame", "LCM_Regain", UIParent)
    f:SetSize(LARGEUR, 112)
    f:SetPoint("TOP", UIParent, "TOP", 0, -145)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)
    HabillerBandeau(f, 42)

    f.titre = UI.Texte(f, "REGAIN", UI.C.titre)
    UI.Police(f.titre, 22, "OUTLINE")
    f.titre:SetPoint("TOP", f, "TOP", 0, -19)
    f.titre:SetWidth(LARGEUR - 80)
    f.titre:SetJustifyH("CENTER")
    f.texte = UI.Texte(f, "", UI.C.texte)
    UI.Police(f.texte, 15)
    f.texte:SetPoint("TOP", f.titre, "BOTTOM", 0, -13)
    f.texte:SetWidth(LARGEUR - 90)
    f.texte:SetJustifyH("CENTER")
    f.texte:SetWordWrap(true)
    f:SetScript("OnUpdate", function(self, ecoule)
        self.reste = (self.reste or 0) - (tonumber(ecoule) or 0)
        self:SetAlpha(math.max(0, math.min(1, self.reste)))
        if self.reste <= 0 then self:Hide() end
    end)
    f:Hide()
    RegainEcran.frame = f
    return f
end

function RegainEcran.Afficher(resultat)
    local f = RegainEcran.frame or ConstruireRegain()
    f.texte:SetText(LCM.Regain.Texte(resultat))
    f.reste = DUREE
    f:SetAlpha(1)
    f:Show()
    return f
end

LCM.WhenReady(function()
    local avant = LCM.Regain.onReception
    LCM.Regain.onReception = function(entity, resultat, expediteur)
        if avant then avant(entity, resultat, expediteur) end
        RegainEcran.Afficher(resultat)
    end
end)
