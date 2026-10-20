-- L'etal d'un marchand pose sur la carte (Core/Marchands.lua), cote joueur.
--
-- Un bouton « Commercer » apparait devant un vendeur et ouvre son etal :
-- Acheter (ses offres, leur prix, ce qu'il en reste) et Revendre (ce qu'il
-- reprend). S'eloigner du vendeur referme l'etal : on ne commerce que devant
-- lui.

local _, LCM = ...
local UI = LCM.UI
local M = LCM.Marchands

local Ecran = { lignes = {} }
UI.Marchand = Ecran

-- Deux lignes de texte : le nom, et dessous le prix, qui peut proposer
-- plusieurs facons de payer (« 600 Essence  ou  400 Essence + 3 Gaufre »).
local LIGNE = 40

-- ===== Le bouton ===========================================================

local function Bouton()
    if Ecran.bouton then return Ecran.bouton end
    local b = UI.Interaction("LCM_BoutonMarchand", "Commercer", "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\fenetres-vendeurs.tga")
    b:SetScript("OnClick", function(self) Ecran.Ouvrir(self.defId) end)
    b:Hide()
    Ecran.bouton = b
    return b
end

-- ===== L'etal ==============================================================

local function Fenetre()
    if Ecran.frame then return Ecran.frame end
    local f = UI.Fenetre("marchand", "Marchand", 460, 440, { x = 260, y = 0 })
    f.mode = "acheter"
    f.acheter = UI.Bouton(f.contenu, "Acheter", 110, 24, function() f.mode = "acheter" Ecran.Afficher() end)
    f.acheter:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.revendre = UI.Bouton(f.contenu, "Revendre", 110, 24, function() f.mode = "revendre" Ecran.Afficher() end)
    f.revendre:SetPoint("LEFT", f.acheter, "RIGHT", 6, 0)
    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -32)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", -10, 0)
    f.vide = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.vide:SetPoint("TOP", f.zone, "TOP", 0, -20)
    Ecran.frame = f
    return f
end

local function Ligne(index)
    local f = Fenetre()
    local l = Ecran.lignes[index]
    if l then return l end
    l = CreateFrame("Frame", nil, f.zone.contenu)
    l:SetHeight(LIGNE - 2)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(22, 22)
    l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
    l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 6, 6)
    l.nom:SetPoint("RIGHT", l, "RIGHT", -150, 0)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    l.stock = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
    l.stock:SetPoint("RIGHT", l, "RIGHT", -96, 0)
    l.prix = UI.Texte(l, "", UI.C.accent, "GameFontNormalSmall")
    l.prix:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -3)
    l.prix:SetPoint("RIGHT", l, "RIGHT", -96, 0)
    l.prix:SetJustifyH("LEFT")
    l.prix:SetWordWrap(false)
    l.action = UI.Bouton(l, "", 84, 20, function(b)
        local ligne = b:GetParent()
        local revendre = Ecran.frame.mode == "revendre"
        local function Faire(choix)
            local ok, raison
            if revendre then ok, raison = M.Revendre(Ecran.defId, ligne.offreId, choix)
            else ok, raison = M.Acheter(Ecran.defId, ligne.offreId, choix) end
            if not ok and raison then LCM.Alerte(tostring(raison)) end
            Ecran.Afficher()
        end
        -- Plusieurs facons de payer : le joueur choisit la sienne.
        local facons = LCM.Prix.DeLOffre(ligne.offre)
        if #facons <= 1 then return Faire(nil) end
        local options = {}
        for rang, facon in ipairs(facons) do
            options[#options + 1] = { id = rang, label = LCM.Prix.TexteFacon(facon) }
        end
        Ecran.choix = Ecran.choix or UI.Choix("marchand_facon", "Comment payer ?")
        Ecran.choix.titre:SetText(revendre and "Être payé comment ?" or "Payer comment ?")
        Ecran.choix:Proposer(b, options, Faire)
    end)
    l.action:SetPoint("RIGHT", l, "RIGHT", -4, 0)
    Ecran.lignes[index] = l
    return l
end

local function Prix(offre)
    return LCM.Prix.Texte(LCM.Prix.DeLOffre(offre))
end

function Ecran.Afficher()
    local f = Ecran.frame
    if not (f and f:IsShown()) then return end
    local definition = M.definitions[Ecran.defId or ""]
    if not definition then f:Hide() return end
    f:Titre(definition.label)
    f.acheter:Selectionner(f.mode ~= "revendre")
    f.revendre:Selectionner(f.mode == "revendre")
    local liste = f.mode == "revendre" and definition.rachats or definition.offres
    local h = 0
    for index, offre in ipairs(liste) do
        local l = Ligne(index)
        l.offreId, l.offre = offre.id, offre
        local entree = LCM.Compendium.Resoudre(offre.entree)
        l.icone:SetTexture((entree and entree.icone) or "Interface\\ICONS\\INV_Misc_QuestionMark")
        local nom = M.Libelle(offre)
        if (offre.quantite or 1) > 1 then nom = nom .. "  x" .. offre.quantite end
        l.nom:SetText(nom)
        l.prix:SetText(Prix(offre))
        if f.mode == "revendre" then
            l.stock:SetText("")
            l.action.label:SetText("Revendre")
            l.action:SetEnabled(true)
        else
            local reste = M.Disponible(definition.id, offre)
            l.stock:SetText(reste and string.format("%d / %d", reste, offre.limite) or "")
            l.action.label:SetText("Acheter")
            l.action:SetEnabled(reste == nil or reste > 0)
        end
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 0, -h)
        l:SetPoint("TOPRIGHT", f.zone.contenu, "TOPRIGHT", 0, -h)
        l:Show()
        h = h + LIGNE
    end
    for index = #liste + 1, #Ecran.lignes do Ecran.lignes[index]:Hide() end
    f.zone:Regler(h)
    f.vide:SetText(#liste == 0 and (f.mode == "revendre" and "Ce marchand ne rachète rien."
        or "Ce marchand n'a rien à vendre.") or "")
end

function Ecran.Ouvrir(defId)
    if not M.definitions[defId or ""] then return end
    Ecran.defId = defId
    local f = Fenetre()
    f.mode = "acheter"
    f:Show()
    Ecran.Afficher()
end

-- Le bouton suit le vendeur devant lequel on se tient ; s'en eloigner referme
-- son etal.
M.onProche = function(point)
    local b = Bouton()
    local definition = point and M.definitions[point.def]
    if not definition then
        b.defId = nil
        b:Hide()
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Hide() end
        return
    end
    b.defId = definition.id
    b.nom:SetText(definition.label)
    b:Show()
    if Ecran.frame and Ecran.frame:IsShown() and Ecran.defId ~= definition.id then Ecran.frame:Hide() end
end

-- Un stock qui bouge, une bourse qui change : l'etal ouvert suit.
M.onChange = function() Ecran.Afficher() end
