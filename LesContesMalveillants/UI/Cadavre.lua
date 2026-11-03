-- La fouille d'un cadavre (le MJ, 3 novembre 2026) : le bouton « Fouiller le
-- cadavre » quand on s'en approche, et la fenetre de ses sections — Équipé,
-- Sac, Naturel, Ventre ; seules celles qui ont quelque chose se montrent.
--
-- Le MJ voit aussi ce qui est desactive (grise) et corrige a la volee d'un
-- clic droit : activer, desactiver, changer la quantite, retirer ; « + » sur
-- une section ajoute un objet. Le contenu vit chez lui (MJ/Cadavres.lua).
local _, LCM = ...
local UI = LCM.UI
local C = LCM.Cadavres

local Ecran = {}
UI.Cadavre = Ecran

local LARGEUR, HAUTEUR = 420, 480
local LIGNE = 30
local ICONE_CADAVRE = "Interface\\Icons\\inv_misc_bone_humanskull_01"

local function EstMJ() return LCM.IsMaster() and LCM.CadavresMJ ~= nil end

-- ===== Le bouton ===========================================================

local function Bouton()
    if Ecran.bouton then return Ecran.bouton end
    local b = UI.Interaction("LCM_BoutonCadavre", "Fouiller le cadavre", ICONE_CADAVRE)
    b:SetScript("OnClick", function(self)
        if self.cadavreId then Ecran.Ouvrir(self.cadavreId) end
    end)
    b:Hide()
    Ecran.bouton = b
    return b
end

function Ecran.Actualiser(c)
    local b = Bouton()
    if not c then b.cadavreId = nil b:Hide() return end
    b.cadavreId = c.id
    b.icone:SetTexture(c.icone and LCM.Icone(c.icone) or ICONE_CADAVRE)
    b.nom:SetText(c.fouille and c.fouille ~= LCM.PlayerId() and (c.nom .. " — " .. c.fouille .. " fouille")
        or c.nom)
    b:Show()
end
C.onProche = function(c) Ecran.Actualiser(c) end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("cadavre", "Cadavre", LARGEUR, HAUTEUR, { x = 260, y = 0 },
        { enTeteSimple = true, sobre = true })
    f.statut = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -2)
    f.statut:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -2)
    f.statut:SetJustifyH("LEFT")
    f.statut:SetWordWrap(true)
    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -36)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", -10, 34)
    f.entetes, f.ajouts, f.lignes = {}, {}, {}
    f.terminer = UI.Bouton(f.contenu, "Terminer la fouille", 170, 24, function() f:Hide() end)
    f.terminer:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 4)
    f.retirer = UI.Bouton(f.contenu, "Retirer le cadavre", 150, 24, function()
        if f.cadavreId and LCM.CadavresMJ then LCM.CadavresMJ.Supprimer(f.cadavreId) end
        f:Hide()
    end)
    f.retirer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 4)
    UI.Bulle(f.retirer, "Retirer le cadavre", "Il disparaît pour tout le monde, avec ce qu'il porte encore.")

    -- Fermer, c'est finir la fouille : le verrou tombe, l'etat part a tous.
    f:HookScript("OnHide", function(self)
        if self.cadavreId and C.fouille and C.fouille.id == self.cadavreId then C.Fermer(self.cadavreId) end
    end)

    local function Entete(n)
        local t = f.entetes[n]
        if t then return t end
        t = CreateFrame("Frame", nil, f.zone.contenu)
        t:SetHeight(22)
        t.texte = UI.Texte(t, "", UI.C.libelle, "GameFontNormalSmall")
        t.texte:SetPoint("LEFT", t, "LEFT", 2, 0)
        t.filet = UI.Filet(t, true)
        t.filet:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
        t.filet:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
        t.plus = UI.Bouton(t, "+", 22, 18, function(b)
            local section = t.section
            f.choixAjout = f.choixAjout or UI.Choix("cadavre_ajout", "Objet")
            local options = {}
            for _, id in ipairs({ "ressources", "consommables", "armes", "armures", "accessoires", "outils", "livres", "cartes", "sacs" }) do
                local categorie = LCM.Compendium.Get(id)
                if categorie then
                    for _, e in ipairs(LCM.Compendium.Entrees(categorie)) do
                        options[#options + 1] = { id = LCM.Compendium.Reference(categorie, e),
                            label = e.label or e.id, groupe = categorie.label }
                    end
                end
            end
            f.choixAjout:Proposer(b, options, function(ref)
                local ok, raison = LCM.CadavresMJ.Ajouter(f.cadavreId, section, ref, 1)
                if not ok then LCM.Alerte(tostring(raison)) end
            end)
        end)
        t.plus:SetPoint("RIGHT", t, "RIGHT", 0, 2)
        UI.Bulle(t.plus, "Ajouter", "Ajoute un objet à cette section (MJ).")
        f.entetes[n] = t
        return t
    end

    local function Ligne(n)
        local l = f.lignes[n]
        if l then return l end
        l = CreateFrame("Button", nil, f.zone.contenu)
        l:SetHeight(LIGNE - 2)
        l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        l.fond = UI.Aplat(l, { 1, 1, 1, 0.035 }, "BACKGROUND")
        l.fond:SetAllPoints(l)
        l.icone = l:CreateTexture(nil, "ARTWORK")
        l.icone:SetSize(22, 22)
        l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
        l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        l.action = UI.Bouton(l, "Prendre", 92, 22, function()
            local ok, raison = C.Prendre(f.cadavreId, l.lotId)
            if not ok and raison then LCM.Alerte(tostring(raison)) end
        end)
        l.action:SetPoint("RIGHT", l, "RIGHT", -2, 0)
        l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
        l.nom:SetPoint("RIGHT", l.action, "LEFT", -8, 0)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        -- Clic droit (MJ) : corriger a la volee.
        l:SetScript("OnClick", function(self, souris)
            if souris ~= "RightButton" or not EstMJ() then return end
            local M = LCM.CadavresMJ
            UI.MenuContexte():Ouvrir(self, {
                { label = self.actif and "Désactiver" or "Activer", action = function()
                    M.Basculer(f.cadavreId, self.lotId) end },
                { label = "Quantité…", action = function()
                    UI.Demande():Demander("Quantité", self.quantite, function(texte)
                        return M.Quantite(f.cadavreId, self.lotId, texte)
                    end, "Valider", 4)
                end },
                { label = "Retirer", action = function() M.RetirerLot(f.cadavreId, self.lotId) end },
            })
        end)
        f.lignes[n] = l
        return l
    end

    function f:Afficher()
        local c = C.connus[self.cadavreId or ""]
        if not c then self:Hide() return end
        self.titre:SetText(c.nom)
        local mj = EstMJ()
        local moi = LCM.PlayerId()
        local fouille = C.fouille and C.fouille.id == c.id
        if fouille then
            self.statut:SetText(mj and "Tu fouilles ce cadavre. Clic droit sur un objet pour le corriger (MJ)."
                or "Tu fouilles ce cadavre. Les autres attendent que tu aies fini.")
        elseif c.fouille and c.fouille ~= moi then
            self.statut:SetText(string.format("%s fouille déjà ce cadavre : attends ton tour.", c.fouille))
        else
            self.statut:SetText(mj and "Clic droit sur un objet pour le corriger (MJ)." or "")
        end
        local y, ne, nl = 0, 0, 0
        for _, section in ipairs(C.SECTIONS) do
            local lots = C.Lots(c, section.id, mj)
            if lots[1] or mj then
                ne = ne + 1
                local t = Entete(ne)
                t.section = section.id
                local precision = section.id == "ventre" and "  |cff99907f(DD facultatif)|r"
                    or (section.jet and "  |cff99907f(extraction)|r" or "")
                t.texte:SetText(UI.Majuscules(section.label) .. precision)
                t.plus:SetShown(mj)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
                t:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
                t:Show()
                y = y + 26
                for _, lot in ipairs(lots) do
                    nl = nl + 1
                    local l = Ligne(nl)
                    l.lotId, l.actif, l.quantite = lot.id, lot.actif ~= false, lot.quantite
                    l.icone:SetTexture(LCM.Icone(lot.icone))
                    local element = LCM.Compendium.Resoudre(lot.entree)
                    local nom = string.format("%s x%d", tostring((element and element.label) or lot.label or lot.entree),
                        lot.quantite)
                    local dd = C.DD(lot, element)
                    if dd ~= nil then
                        local tent = tonumber(element and element.tentatives)
                        nom = nom .. string.format("  |cff99907fDD %d%s|r", dd,
                            tent and string.format(" · %d essai(s)", math.max(0, tent - (lot.essais or 0))) or "")
                    end
                    l.nom:SetText(nom)
                    l:SetAlpha(l.actif and 1 or 0.45)
                    l.action.label:SetText(dd ~= nil and "Extraire" or "Prendre")
                    l.action:SetShown(fouille and l.actif)
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
                    l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
                    l:Show()
                    y = y + LIGNE
                end
                y = y + 6
            end
        end
        for n = ne + 1, #self.entetes do self.entetes[n]:Hide() end
        for n = nl + 1, #self.lignes do self.lignes[n]:Hide() end
        self.zone:Regler(math.max(1, y))
        self.retirer:SetShown(mj)
    end

    Ecran.frame = f
    return f
end

function Ecran.Fenetre() return Ecran.frame or Construire() end

-- Ouvrir : demander la fouille au MJ ; la fenetre suit sa reponse.
function Ecran.Ouvrir(id)
    local f = Ecran.Fenetre()
    f.cadavreId = tostring(id or "")
    local ok, raison = C.Ouvrir(f.cadavreId)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    f:Show()
    f:Afficher()
    return f
end

C.onChange = function(id)
    local f = Ecran.frame
    if f and f:IsShown() and f.cadavreId == id then f:Afficher() end
    if Ecran.bouton and Ecran.bouton:IsShown() and Ecran.bouton.cadavreId == id then
        Ecran.Actualiser(C.connus[id])
    end
end
