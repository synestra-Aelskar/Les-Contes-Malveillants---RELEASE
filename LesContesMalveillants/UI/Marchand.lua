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

local MOI = "__moi"
local function Court(nom) return (tostring(nom or ""):match("^[^-]+")) or tostring(nom or "") end

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
    -- « Acheter pour : » (31 octobre 2026) : moi, ou un joueur a cote. Il
    -- n'apparait que s'il y a quelqu'un a portee ; l'etal le cherche tant
    -- qu'il est ouvert (M.ScannerProches).
    f.pourLabel = UI.Texte(f.contenu, "Acheter pour :", UI.C.discret, "GameFontNormalSmall")
    f.pour = UI.Deroulant(f.contenu, 150, 24, function()
        local options = { { id = MOI, label = "Moi" } }
        for _, p in ipairs(M.ListeProches()) do
            options[#options + 1] = { id = p.nom, label = string.format("%s  (%.0f m)",
                p.perso or Court(p.nom), p.distance or 0) }
        end
        return options
    end, function(id)
        Ecran.pour = id ~= MOI and id or nil
        Ecran.Afficher()
    end)
    f.pour:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", -10, 0)
    f.pourLabel:SetPoint("RIGHT", f.pour, "LEFT", -6, 0)
    f.attente = 0
    f:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 3 then return end
        self.attente = 0
        if self.mode ~= "revendre" then M.ScannerProches() end
    end)
    f:HookScript("OnHide", function()
        Ecran.pour = nil
        for nom in pairs(M.proches) do M.proches[nom] = nil end
    end)
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
            else ok, raison = M.Acheter(Ecran.defId, ligne.offreId, choix, Ecran.pour) end
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
    -- Le destinataire choisi est-il toujours a portee ?
    local proches = M.ListeProches()
    if Ecran.pour and not M.proches[Ecran.pour] then Ecran.pour = nil end
    local montrer = f.mode ~= "revendre" and (#proches > 0 or Ecran.pour ~= nil)
    f.pour:SetShown(montrer)
    f.pourLabel:SetShown(montrer)
    local choisi = Ecran.pour and M.proches[Ecran.pour]
    f.pour:Definir(Ecran.pour or MOI, choisi and (choisi.perso or Court(choisi.nom)) or "Moi")
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
            l.action.label:SetText(Ecran.pour and "Offrir" or "Acheter")
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
    M.ScannerProches()
    Ecran.Afficher()
end

-- Un joueur a cote repond au scan : le choix « Acheter pour » suit.
M.onProches = function() Ecran.Afficher() end

-- ===== Chez le destinataire ================================================
-- Quelqu'un veut m'acheter quelque chose : j'accepte (c'est range dans mon
-- sac, il paie) ou je refuse (personne ne paie rien). Une seule demande a la
-- fois : une nouvelle remplace l'ancienne, refusee.
M.onCadeau = function(demande)
    if not Ecran.cadeau then
        local d = UI.Confirmer(UIParent, "", "Accepter")
        d.non.label:SetText("Refuser")
        d.non:SetScript("OnClick", function()
            local en = d.demande
            d.demande, d.action = nil, nil
            d:Hide()
            if en then en.refuser() end
        end)
        d.oui.label:SetTextColor(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3])
        Ecran.cadeau = d
    end
    local d = Ecran.cadeau
    if d.demande and d:IsShown() then d.demande.refuser() end
    d.demande = demande
    d:Demander(string.format("%s veut vous offrir %s%s%s.\nAccepter ?", Court(demande.de), demande.label,
        demande.quantite > 1 and (" x" .. demande.quantite) or "",
        demande.vendeur ~= "" and (" (" .. demande.vendeur .. ")") or ""), function()
        d.demande = nil
        demande.accepter()
    end)
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
