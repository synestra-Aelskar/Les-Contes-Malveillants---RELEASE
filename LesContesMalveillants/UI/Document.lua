-- Fenetre de documentation.
--
-- Le registre est dans Core/Documents.lua ; ici, seulement l'affichage : une
-- liste a gauche, le contenu a droite.

local _, LCM = ...
local UI = LCM.UI
local Documents = LCM.Documents

local Document = {}
UI.Document = Document

-- ===== Fenetre =============================================================

local function Vider(page)
    for _, region in ipairs(page.blocs or {}) do region:Hide() end
    page.blocs = page.blocs or {}
end

function Document.Fenetre()
    if Document.frame then return Document.frame end

    local f = UI.Fenetre("document", "Documentation", 520, 560, { x = 200, y = 0 })
    Document.frame = f

    -- Colonne de gauche : la liste des documents. A droite : le contenu.
    f.liste = CreateFrame("Frame", nil, f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(140)
    f.liste.boutons = {}

    -- Le contenu defile et se rogne : un long document ne deborde pas.
    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.liste, "TOPRIGHT", 12, 0)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.page = f.zone.contenu
    f.page.blocs, f.page.ornements = {}, {}
    local largeurTexte = 520 - 24 - 140 - 12

    local function Bloc()
        local fs = UI.Texte(f.page, "", UI.C.texte)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetWidth(largeurTexte)
        return fs
    end

    function f:AfficherDocument(id)
        local doc = Documents.Get(id)
        if not doc then return end
        self.documentId = id
        for _, bouton in ipairs(self.liste.boutons) do
            bouton:Selectionner(bouton.documentId == id)
        end
        Vider(self.page)
        for _, o in ipairs(self.page.ornements) do o:Hide() end

        local y, index, nOrnements = 0, 0, 0
        for _, bloc in ipairs(doc.blocs) do
            index = index + 1
            local fs = self.page.blocs[index]
            if not fs then
                fs = Bloc()
                self.page.blocs[index] = fs
            end
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", self.page, "TOPLEFT", 0, -y)
            fs:Show()

            if bloc.kind == "titre" then
                -- Titre du modele : capitales dorees et leur ornement.
                UI.Police(fs, 14)
                fs:SetText(UI.Majuscules(bloc.texte))
                fs:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
                if UI.AelRef then
                    nOrnements = nOrnements + 1
                    local o = self.page.ornements[nOrnements]
                    if not o then
                        o = UI.AelRef(self.page, 347, 344, 45, 17, "ARTWORK")
                        o:SetSize(30, 11)
                        self.page.ornements[nOrnements] = o
                    end
                    o:ClearAllPoints()
                    o:SetPoint("LEFT", self.page, "TOPLEFT", (fs:GetStringWidth() or 0) + 8, -y - 8)
                    o:Show()
                end
                y = y + 26
            elseif bloc.kind == "separateur" then
                fs:SetText("")
                y = y + 12
            else
                local texte = bloc.texte
                if bloc.kind == "liste" then
                    local lignes = {}
                    for _, item in ipairs(bloc.items or {}) do lignes[#lignes + 1] = "  -  " .. tostring(item) end
                    texte = table.concat(lignes, "\n")
                end
                UI.Police(fs, 12)
                fs:SetText(texte)
                fs:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3])
                -- Hauteur MESUREE : une estimation au nombre de signes laissait
                -- des blocs se chevaucher.
                y = y + (fs:GetStringHeight() or 14) + 8
            end
        end
        self.hauteur = y
        self.zone.decalage = 0
        self.zone:Regler(y)
    end

    function f:Reconstruire()
        local docs = Documents.Visibles()
        local precedent
        for index, doc in ipairs(docs) do
            local b = self.liste.boutons[index]
            if not b then
                b = UI.Bouton(self.liste, "", 138, 26, function(bouton)
                    self:AfficherDocument(bouton.documentId)
                end)
                if UI.HabillerOnglet then UI.HabillerOnglet(b) end
                self.liste.boutons[index] = b
            end
            b.documentId = doc.id
            b.label:SetText(doc.label)
            b:ClearAllPoints()
            if precedent then
                b:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -4)
            else
                b:SetPoint("TOPLEFT", self.liste, "TOPLEFT", 0, 0)
            end
            b:Show()
            precedent = b
        end
        for index = #docs + 1, #self.liste.boutons do self.liste.boutons[index]:Hide() end
        self.documents = docs
    end

    function f:Montrer(id)
        self:Reconstruire()
        local cible = id or self.documentId
        if not cible or not Documents.Get(cible) then
            cible = self.documents[1] and self.documents[1].id
        end
        if cible then self:AfficherDocument(cible) end
        self:Show()
    end

    return f
end

LCM.AddCommand("doc", "ouvre la documentation", function(argument)
    local f = Document.Fenetre()
    if f:IsShown() then
        f:Hide()
        return
    end
    local cible = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    f:Montrer(cible ~= "" and cible or nil)
end)
