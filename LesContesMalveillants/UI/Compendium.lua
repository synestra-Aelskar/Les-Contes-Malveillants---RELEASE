-- La fenetre du compendium « Systeme d'A'Hell'Razkah ». Le hub « Compendiums »
-- qui y menait (CreateCompendiumHubFrame) est retire le 3 octobre 2026 : il
-- ne contenait que cette carte.
--
-- Reprise de Necronicon (Compendium.lua : CreateCompendiumFrame,
-- RefreshCompendiumUI, UpdateCompendiumPanelLayout, EnsureCompendiumRow,
-- LayoutCompendiumLinkPopup, CreateCompendiumHubFrame) avec ses mesures :
--
--   * a gauche, la colonne TYPES (filtres par type de categorie, repliable)
--     et la colonne CATEGORIES (recherche, sous-categories depliables) ;
--   * a droite, la recherche d'entrees, la rangee d'actions, l'en-tete du
--     tableau (ID, NOM, colonnes des champs), les lignes (24 de haut, 28 de
--     pas, 20 par page), la pagination et le defilement horizontal ;
--   * « Voir » ouvre la carte de l'entree (Voir, comme le template) ; une
--     cellule ouvre sa valeur complete.
--
-- Ce qui n'est pas repris, et pourquoi : l'edition de la STRUCTURE (+ Categorie,
-- + Champ, panneau CHAMPS, transferts, dossiers, sous-categorie au clic droit)
-- parce qu'elle vivrait dans la sauvegarde ; « Partager » et « Importer
-- (code) », parce qu'une entree n'entre pas dans la sauvegarde d'un joueur ;
-- « Forge », qui est un autre outil. « Link » est repris, en « Montrer »
-- seulement (Core/Lien.lua). L'edition des ENTREES appartient au compagnon MJ :
-- il s'inscrit dans `Compendium.Editeur` et ses boutons n'existent que la.

local _, LCM = ...
local UI = LCM.UI
local GameTooltip = UI.Infobulle()
local C = LCM.Compendium

local Fenetre = {}
UI.Compendium = Fenetre

-- ===== Mesures de Necronicon ===============================================

local LARGEUR, HAUTEUR, MIN_L, MIN_H = 760, 500, 620, 400
local PANEL_TOP, PANEL_BOTTOM, PANEL_GAP, INSET = -38, 16, 12, 8
local LARGEUR_TYPES = 140
local LARGEUR_CATEGORIES = 184
local DECALAGE_CATEGORIES = LARGEUR_TYPES + PANEL_GAP
local LARGEUR_RECHERCHE = 104
local PAS_LIGNE, HAUTEUR_LIGNE, PAR_PAGE = 28, 24, 20
local ECART = 8
local ID_MIN, ID_MAX, NOM_MIN, NOM_MAX = 42, 58, 90, 150
local ACTION_MIN, ACTION_MAX = 56, 220
local LARGEURS = { icone = 44, statistique = 84, composants = 140, prerequis = 140, injections = 140,
                   table_xp = 140, description = 140, type = 72 }

-- Bouton texte du modele (UI.CreateTextAction) : 7 px par octet + 10.
local function Action(parent, texte, hauteur)
    return UI.Bouton(parent, texte, math.max(18, #tostring(texte) * 7 + 10), hauteur or 16)
end

-- Une mesure de texte, pour dimensionner les colonnes ID et NOM.
local mesure
local function Largeur(texte)
    if not mesure then
        mesure = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mesure:Hide()
    end
    mesure:SetText(tostring(texte or ""))
    return math.floor((mesure:GetStringWidth() or 0) + 0.5)
end

local function Couleur(hexa)
    hexa = tostring(hexa or "FFFFFF")
    return (tonumber(hexa:sub(1, 2), 16) or 255) / 255, (tonumber(hexa:sub(3, 4), 16) or 255) / 255,
        (tonumber(hexa:sub(5, 6), 16) or 255) / 255
end
Fenetre.Couleur = Couleur

local function Peindre(fs, couleur) fs:SetTextColor(couleur[1], couleur[2], couleur[3]) end

-- L'editeur du compagnon MJ, s'il est la. Le joueur consulte, le MJ edite.
local function Editeur()
    return LCM.IsMaster() and Fenetre.Editeur or nil
end

-- ===== Preferences d'affichage =============================================
-- Les colonnes masquees, par categorie : une preference d'ecran (comme la
-- position d'une fenetre), pas de la structure. Une table vide est effacee.

local function Masquees(categorieId)
    local db = LCM.db and LCM.db.compendium
    return db and db.colonnesMasquees and db.colonnesMasquees[categorieId] or {}
end

local function Masquer(categorieId, cle, masquee)
    LCM.EnsureDatabase()
    local db = LCM.db
    if masquee then
        db.compendium = type(db.compendium) == "table" and db.compendium or {}
        db.compendium.colonnesMasquees = type(db.compendium.colonnesMasquees) == "table" and db.compendium.colonnesMasquees or {}
        db.compendium.colonnesMasquees[categorieId] = db.compendium.colonnesMasquees[categorieId] or {}
        db.compendium.colonnesMasquees[categorieId][cle] = true
    else
        local par = db.compendium and db.compendium.colonnesMasquees
        local liste = par and par[categorieId]
        if liste then
            liste[cle] = nil
            if next(liste) == nil then par[categorieId] = nil end
            if next(par) == nil then db.compendium.colonnesMasquees = nil end
            if next(db.compendium) == nil then db.compendium = nil end
        end
    end
end

-- ===== Flux des statistiques (ComputeFieldFlowLayout) ======================

local FLUX = { gauche = 8, droite = 8, haut = 5, ligne = 15, entete = 22, groupe = 7, ecartX = 16, ecartValeur = 4 }

-- Place des « libelle : valeur » en colonnes, dossier par dossier. Renvoie les
-- en-tetes { texte, y }, les puces { x, y, largeur, ... } et la hauteur.
local function Flux(items, largeur)
    local utile = math.max(60, largeur - FLUX.gauche - FLUX.droite)
    local groupes, ordre = {}, {}
    for _, item in ipairs(items) do
        local g = groupes[item.dossier]
        if not g then
            g = { label = item.dossier, ordre = item.dossier == "" and -1 or (item.dossierIndex or 0), premier = #ordre, items = {} }
            groupes[item.dossier] = g
            ordre[#ordre + 1] = g
        end
        g.items[#g.items + 1] = item
    end
    table.sort(ordre, function(a, b)
        if a.ordre ~= b.ordre then return a.ordre < b.ordre end
        return a.premier < b.premier
    end)
    local entetes, puces, y = {}, {}, FLUX.haut
    for _, g in ipairs(ordre) do
        if g.label ~= "" then
            y = y + FLUX.groupe
            entetes[#entetes + 1] = { texte = g.label, y = y }
            y = y + FLUX.entete
        end
        local plusLarge = 1
        for _, item in ipairs(g.items) do
            item.titre = item.label ~= "" and (item.label .. " :") or ""
            item.lt = item.titre ~= "" and Largeur(item.titre) or 0
            item.lv = Largeur(item.valeur)
            item.ecart = (item.titre ~= "" and item.valeur ~= "") and FLUX.ecartValeur or 0
            plusLarge = math.max(plusLarge, item.lt + item.ecart + item.lv)
        end
        -- 15 % de marge avant de choisir le nombre de colonnes : sans elle, des
        -- libelles de longueurs voisines finissent tronques.
        local colonnes = math.max(1, math.floor((utile + FLUX.ecartX) / (plusLarge * 1.15 + FLUX.ecartX)))
        colonnes = math.min(colonnes, #g.items)
        local largeurColonne = utile / colonnes
        local titreCol = {}
        for n, item in ipairs(g.items) do
            local col = (n - 1) % colonnes
            titreCol[col] = math.max(titreCol[col] or 0, item.lt)
        end
        for n, item in ipairs(g.items) do
            local col = (n - 1) % colonnes
            if col == 0 and n > 1 then y = y + FLUX.ligne end
            local decalage = item.titre ~= "" and (titreCol[col] + item.ecart) or 0
            puces[#puces + 1] = {
                x = FLUX.gauche + math.floor(col * largeurColonne), y = y,
                largeur = math.min(largeurColonne, decalage + item.lv), decalage = decalage,
                titre = item.titre, valeur = item.valeur,
            }
        end
        y = y + FLUX.ligne
    end
    return entetes, puces, y
end
Fenetre.Flux = Flux

-- ===== La carte d'une entree (« Voir ») ====================================

local cartes = {}

-- Le plancher d'une carte : de quoi montrer l'en-tete, la ligne d'etat et le
-- bandeau « Statistiques » replie, et rien de plus. A 150, une carte repliee
-- gardait une bande vide sous le bandeau.
local HAUTEUR_MINI = 96

local function NouvelleCarte()
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(435, 360)
    p:SetFrameStrata("DIALOG")
    p:SetToplevel(true)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetClampedToScreen(true)
    p:SetScript("OnMouseDown", function(self) UI.Devant(self) end)
    p:SetScript("OnDragStart", function(self) self:StartMoving() end)
    p:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() self.placee = true end)
    p.fond = UI.Aplat(p, UI.C.fond)
    p.fond:SetAllPoints(p)
    -- Cadre « panel », comme toute carte de compendium du modele.
    if UI.Cadre then UI.Cadre(p) else UI.BordureFine(p, 0.28) end

    p.fermer = UI.Bouton(p, "x", 16, 16, function() p:Hide() end)
    p.fermer:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
    p.fermer:SetFrameLevel(p:GetFrameLevel() + 6)

    p.icone = p:CreateTexture(nil, "ARTWORK")
    -- Plus grande qu'avant (28), sans etre envahissante : a 28 on ne
    -- reconnaissait pas l'objet qu'on est venu lire.
    p.icone:SetSize(42, 42)
    p.icone:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    -- Le tour dore de l'habillage, qui mord d'un pixel SUR l'image : sans lui
    -- on voyait le liseré gris que le jeu dessine au bord de ses icones.
    if UI.AelCadre then
        local support = CreateFrame("Frame", nil, p)
        support:SetPoint("TOPLEFT", p.icone, "TOPLEFT", -1, 1)
        support:SetPoint("BOTTOMRIGHT", p.icone, "BOTTOMRIGHT", 1, -1)
        support:SetFrameLevel(p:GetFrameLevel() + 2)
        p.cadreIcone = UI.AelCadre(support, "icone")
    end
    p.titre = UI.Texte(p, "", UI.C.titre, "GameFontNormal")
    p.titre:SetWordWrap(false)
    p.sousTitre = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.sousTitre:SetPoint("TOPLEFT", p.titre, "BOTTOMLEFT", 0, -2)
    p.sousTitre:SetWordWrap(true)

    -- L'entete se pose DANS le cadre, pas sous son ornement. A douze pixels du
    -- bord, l'icone et le nom passaient sous la draperie du coin : l'habillage
    -- mord bien plus que ca, et c'est lui qui dit de combien.
    function p:PlacerEntete()
        local e = UI.AelEmprise(self)
        local cote = math.max(12, (e.cote or 0) + 6)
        -- En HAUT de la carte : l'ornement du haut est au milieu du bord, pas
        -- dans le coin gauche ou vit l'icone. Se decaler de sa portee (40 px)
        -- faisait descendre tout l'entete sur l'etat.
        local haut = math.max(10, cote - 2)
        self.margeCote, self.margeHaut = cote, haut
        self.icone:ClearAllPoints()
        self.icone:SetPoint("TOPLEFT", self, "TOPLEFT", cote, -haut)
        self.titre:ClearAllPoints()
        self.titre:SetPoint("TOPLEFT", self.icone, "TOPRIGHT", 10, -2)
        self.titre:SetPoint("TOPRIGHT", self, "TOPRIGHT", -(cote + 26), -haut)
        self.sousTitre:SetPoint("TOPRIGHT", self, "TOPRIGHT", -(cote + 26), 0)
        self.fermer:ClearAllPoints()
        -- La croix va dans l'encoche du coin haut droit, comme sur les
        -- fenetres (UI.Fenetre:PlacerCoinsHaut) ; a defaut, sous l'ornement.
        local encoches = UI.AelEncoches and UI.AelEncoches(self)
        if encoches then
            local taille = math.max(10, math.floor(encoches.cote + 0.5))
            self.fermer:SetSize(taille, taille)
            self.fermer:SetPoint("CENTER", self, "TOPRIGHT", encoches.droite[1], encoches.droite[2])
        else
            self.fermer:SetSize(16, 16)
            self.fermer:SetPoint("TOPRIGHT", self, "TOPRIGHT", -math.max(8, cote - 4), -haut)
        end
        -- Ou commence le texte aligne sur le NOM : apres l'icone.
        self.xTexte = cote + self.icone:GetWidth() + 10
    end
    p.entete = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.entete:SetWordWrap(true)
    p.filetEntete = UI.Filet(p)
    p.meta = UI.Texte(p, "", UI.C.discret, "GameFontNormalSmall")
    p.meta:SetWordWrap(true)
    p.filetMeta = UI.Filet(p, true)

    p.corps = UI.Defilement(p)
    p.sections = {}
    p.composants = {}
    p.puces, p.entetesStats = {}, {}
    p.basculeStats = Action(p.corps.contenu, "+ Statistiques")
    p.basculeStats.label:ClearAllPoints()
    p.basculeStats.label:SetPoint("LEFT", p.basculeStats, "LEFT", 4, 0)
    p.basculeStats.label:SetJustifyH("LEFT")
    Peindre(p.basculeStats.label, UI.C.accent)
    -- Deplier les statistiques AGRANDIT la carte, et la replier la referme
    -- jusque sous le bandeau. Avant, la hauteur ne bougeait pas : depliee on
    -- lisait par un hublot, repliee on regardait du vide.
    --
    -- Sauf si on l'a redimensionnee soi-meme (`placee`) : la, c'est la taille
    -- choisie qui vaut, et le defilement fait le reste.
    p.basculeStats:SetScript("OnClick", function()
        p.statsRepliees = not p.statsRepliees
        local hauteur = p:Disposer()
        -- La hauteur suit TOUJOURS, meme si on a deplace ou retaille la carte.
        -- Avant, retailler posait `placee`, et deplier ne faisait plus rien :
        -- on retaillait parce que ca ne s'agrandissait pas, ce qui garantissait
        -- que ca ne s'agrandirait plus jamais. La largeur, elle, reste celle
        -- qu'on a choisie.
        p:SetHeight(math.min(560, math.max(HAUTEUR_MINI, hauteur)))
        p:Disposer()
    end)

    p.filetPied = UI.Filet(p, true)
    p.pied = UI.Texte(p, "", UI.C.discret, "GameFontNormalSmall")
    p.pied:SetWordWrap(true)

    UI.Redimensionner(p, 180, HAUTEUR_MINI, function() p.placee = true p:Disposer() end)

    -- Met la carte en page ; renvoie la hauteur que demande son contenu.
    function p:Disposer()
        local d = self.donnees
        if not d then return 0 end
        local largeur = math.max(320, self:GetWidth())
        self:PlacerEntete()
        local marge = self.margeCote or 12
        -- Aligne sur le nom, pas sur le bord : « Etat : 20 / 20 » se lisait
        -- sous l'icone, decroche du nom auquel il se rapporte — et par-dessus
        -- elle une fois l'icone agrandie.
        local xTexte = self.xTexte or 12
        -- Deux largeurs : celle de l'ENTETE, qui commence apres l'icone, et
        -- celle du CORPS, qui traverse la carte d'une marge a l'autre. Les
        -- confondre raccourcissait le rectangle des statistiques de toute la
        -- largeur de l'icone.
        local utileEntete = largeur - marge - xTexte
        local utile = largeur - 2 * marge
        local haut = self.margeHaut or 12
        -- Le texte descend sous le NOM ; le bas de l'icone ne compte que pour
        -- ce qui traverse la carte (les filets).
        local y = -haut - 22
        local basIcone = -haut - self.icone:GetHeight() - 4
        if d.sousTitre ~= "" then
            self.sousTitre:SetText(d.sousTitre)
            self.sousTitre:SetWidth(math.max(largeur - (self.xTexte or 92) - 40, 160))
            y = -30 - math.max(self.sousTitre:GetStringHeight() or 0, 14)
        end
        self.sousTitre:SetShown(d.sousTitre ~= "")
        self.entete:SetShown(d.entete ~= "")
        self.filetEntete:SetShown(d.entete ~= "")
        if d.entete ~= "" then
            y = y - 3
            self.entete:SetText(d.entete)
            self.entete:ClearAllPoints()
            self.entete:SetPoint("TOPLEFT", self, "TOPLEFT", xTexte, y)
            self.entete:SetWidth(math.max(80, utileEntete))
            y = y - math.max(self.entete:GetStringHeight() or 0, 14) - 5
            self.filetEntete:ClearAllPoints()
            self.filetEntete:SetPoint("TOPLEFT", self, "TOPLEFT", marge, y)
            self.filetEntete:SetPoint("TOPRIGHT", self, "TOPRIGHT", -marge, y)
            y = y - 3
        end
        self.meta:SetShown(d.meta ~= "")
        self.filetMeta:SetShown(d.meta ~= "")
        if d.meta ~= "" then
            self.meta:SetText(d.meta)
            self.meta:ClearAllPoints()
            self.meta:SetPoint("TOPLEFT", self, "TOPLEFT", xTexte, y)
            self.meta:SetWidth(utileEntete)
            y = y - math.max(self.meta:GetStringHeight() or 0, 14) - 4
            self.filetMeta:ClearAllPoints()
            self.filetMeta:SetPoint("TOPLEFT", self, "TOPLEFT", 12, y)
            self.filetMeta:SetPoint("TOPRIGHT", self, "TOPRIGHT", -12, y)
            y = y - 6
        end

        -- Pied : en bas, borne a 84 de haut.
        local hauteurPied = 0
        self.pied:SetShown(d.pied ~= "")
        self.filetPied:SetShown(d.pied ~= "")
        if d.pied ~= "" then
            self.pied:SetText(d.pied)
            self.pied:SetWidth(utile)
            hauteurPied = math.min(84, math.max(18, (self.pied:GetStringHeight() or 0) + 6))
            self.pied:ClearAllPoints()
            self.pied:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 12, 12)
            self.pied:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 12)
            self.pied:SetHeight(hauteurPied)
            self.filetPied:ClearAllPoints()
            self.filetPied:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 12, 12 + hauteurPied + 4)
            self.filetPied:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, 12 + hauteurPied + 4)
        end

        -- Corps : une section par champ, puis le bloc Statistiques.
        local corps = self.corps.contenu
        local sections = d.corps
        local vide = #sections == 0 and #d.stats == 0
        local yc = 0
        for index = 1, math.max(#sections, vide and 1 or 0) do
            local s = sections[index] or { titre = "Contenu", texte = "Aucun contenu." }
            local ligne = self.sections[index]
            if not ligne then
                ligne = CreateFrame("Frame", nil, corps)
                ligne.titre = UI.Texte(ligne, "", UI.C.accent, "GameFontNormalSmall")
                ligne.titre:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, 0)
                ligne.texte = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.texte:SetWordWrap(true)
                ligne.composants = {}
                self.sections[index] = ligne
            end
            local decalageTitre = (s.titre or "") ~= "" and 18 or 0
            ligne.titre:SetText(s.titre or "")
            ligne.titre:SetShown(decalageTitre > 0)
            local hauteurTexte
            local avecComposants = s.composants and #s.composants > 0
            ligne.texte:SetShown(not avecComposants)
            if avecComposants then
                hauteurTexte = math.max(#s.composants * 30, 18)
                for n, c in ipairs(s.composants) do
                    local r = ligne.composants[n]
                    if not r then
                        r = CreateFrame("Frame", nil, ligne)
                        r:SetHeight(26)
                        r.icone = r:CreateTexture(nil, "ARTWORK")
                        r.icone:SetSize(24, 24)
                        r.icone:SetPoint("LEFT", r, "LEFT", 0, 0)
                        r.nom = UI.Texte(r, "", UI.C.texte, "GameFontNormalSmall")
                        r.nom:SetPoint("LEFT", r.icone, "RIGHT", 8, 0)
                        r.nom:SetPoint("RIGHT", r, "RIGHT", -70, 0)
                        r.quantite = UI.Texte(r, "", UI.C.accent, "GameFontNormalSmall")
                        r.quantite:SetPoint("RIGHT", r, "RIGHT", -4, 0)
                        r.quantite:SetJustifyH("RIGHT")
                        ligne.composants[n] = r
                    end
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, -decalageTitre - (n - 1) * 30)
                    r:SetPoint("TOPRIGHT", ligne, "TOPRIGHT", 0, -decalageTitre - (n - 1) * 30)
                    r.icone:SetTexture(c.icone)
                    r.nom:SetText(c.nom)
                    r.quantite:SetText("x" .. tostring(c.quantite))
                    r:Show()
                end
            else
                ligne.texte:ClearAllPoints()
                ligne.texte:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, -decalageTitre)
                ligne.texte:SetWidth(utile - 10)
                ligne.texte:SetText(s.texte or "")
                hauteurTexte = math.max((ligne.texte:GetStringHeight() or 0) + 6, 18)
            end
            for n = (avecComposants and #s.composants or 0) + 1, #ligne.composants do ligne.composants[n]:Hide() end
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", corps, "TOPLEFT", 0, -yc)
            ligne:SetPoint("TOPRIGHT", corps, "TOPRIGHT", 0, -yc)
            ligne:SetHeight(decalageTitre + hauteurTexte)
            ligne:Show()
            yc = yc + decalageTitre + hauteurTexte + 6
        end
        for index = math.max(#sections, vide and 1 or 0) + 1, #self.sections do self.sections[index]:Hide() end

        -- Statistiques : repliees a l'ouverture, comme dans le modele.
        self.basculeStats:SetShown(#d.stats > 0)
        for _, h in ipairs(self.entetesStats) do h:Hide() h.filet:Hide() end
        for _, c in ipairs(self.puces) do c:Hide() end
        if #d.stats > 0 then
            self.basculeStats:ClearAllPoints()
            self.basculeStats:SetPoint("TOPLEFT", corps, "TOPLEFT", 0, -yc)
            self.basculeStats:SetWidth(math.max(60, utile))
            self.basculeStats.label:SetText((self.statsRepliees and "+ " or "- ") .. "Statistiques")
            yc = yc + 20
            if not self.statsRepliees then
                local entetes, puces, hauteur = Flux(d.stats, utile - 10)
                for n, e in ipairs(entetes) do
                    local h = self.entetesStats[n]
                    if not h then
                        h = UI.Texte(corps, "", UI.C.accent, "GameFontNormal")
                        h.filet = UI.Filet(corps)
                        self.entetesStats[n] = h
                    end
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", corps, "TOPLEFT", FLUX.gauche, -yc - e.y)
                    h:SetText(e.texte)
                    h:Show()
                    h.filet:ClearAllPoints()
                    h.filet:SetPoint("TOPLEFT", corps, "TOPLEFT", FLUX.gauche, -yc - e.y - FLUX.entete + 4)
                    h.filet:SetPoint("TOPRIGHT", corps, "TOPRIGHT", -FLUX.droite, -yc - e.y - FLUX.entete + 4)
                    h.filet:Show()
                end
                for n, info in ipairs(puces) do
                    local c = self.puces[n]
                    if not c then
                        c = CreateFrame("Frame", nil, corps)
                        c:SetHeight(FLUX.ligne)
                        c.titre = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
                        c.titre:SetPoint("LEFT", c, "LEFT", 0, 0)
                        c.valeur = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
                        self.puces[n] = c
                    end
                    c:ClearAllPoints()
                    c:SetPoint("TOPLEFT", corps, "TOPLEFT", info.x, -yc - info.y)
                    c:SetWidth(math.max(1, info.largeur))
                    c.titre:SetText(info.titre)
                    c.titre:SetShown(info.titre ~= "")
                    c.valeur:ClearAllPoints()
                    c.valeur:SetPoint("LEFT", c, "LEFT", info.decalage, 0)
                    c.valeur:SetText(info.valeur)
                    c:Show()
                end
                yc = yc + hauteur
            end
            yc = yc + 6
        end

        local reserve = d.pied ~= "" and (hauteurPied + 5 + 8) or 0
        self.corps:ClearAllPoints()
        self.corps:SetPoint("TOPLEFT", self, "TOPLEFT", 12, y)
        self.corps:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -16, 12 + reserve)
        self.corps:Regler(yc)
        return math.abs(y) + yc + reserve + 18
    end

    function p:Montrer(categorie, element, ancre, rang)
        local d = C.Carte(categorie, element)
        self.donnees = d
        self.categorieId, self.entreeId = categorie.id, element.id
        self.statsRepliees = true
        self.icone:SetTexture(d.icone)
        self.titre:SetText(d.nom)
        self.titre:SetTextColor(Couleur(d.couleurTitre))
        local r, g, b = Couleur(d.couleurFond)
        self.fond:SetColorTexture(r, g, b, 0.94)
        if not self.placee then self:SetWidth(435) end
        local hauteur = self:Disposer()
        if not self.placee then
            self:SetHeight(math.min(560, math.max(HAUTEUR_MINI, hauteur)))
            self:Disposer()
            if ancre then
                self:ClearAllPoints()
                self:SetPoint("TOPRIGHT", ancre, "TOPLEFT", -12 - (rang or 0) * 22, -(rang or 0) * 18)
            end
        end
        self:Show()
        UI.Devant(self)
    end
    p:Hide()
    return p
end
-- Les vues contextuelles (coffres, inventaires, etc.) peuvent ainsi réutiliser
-- exactement le rendu d'une carte du compendium sans entrer dans la pile des
-- cartes persistantes ouvertes avec « Voir ».
Fenetre.NouvelleCarte = NouvelleCarte

-- Ouvre une carte de plus (Necronicon en ouvre une par clic, pour comparer).
function Fenetre.Voir(categorie, element, ancre)
    local carte, ouvertes = nil, 0
    for _, c in ipairs(cartes) do
        if c:IsShown() then ouvertes = ouvertes + 1 elseif not carte then carte = c end
    end
    if not carte then
        carte = NouvelleCarte()
        cartes[#cartes + 1] = carte
    end
    carte.placee = nil
    carte:Montrer(categorie, element, ancre, ouvertes)
    return carte
end
Fenetre.cartes = cartes

-- « Link » : le choix des destinataires, puis l'envoi de l'entree entiere.
-- L'entree est lue au moment du clic sur Envoyer : la fenetre a pu rester
-- ouverte pendant qu'on la retouchait.
function Fenetre.Partager(categorie, element)
    Fenetre.choixJoueurs = Fenetre.choixJoueurs or UI.ChoixJoueurs("compendium")
    local d = Fenetre.choixJoueurs
    d:Proposer(string.format("Envoyer « %s »", tostring(element.label or element.id)), function(noms)
        local actuel = C.Entree(categorie, element.id) or element
        local ok, morceaux, cibles = LCM.Lien.EnvoyerEntree(categorie, actuel, noms)
        if not ok then return false, morceaux end
        LCM.Ok(string.format("%s envoyé à %s%s.", LCM.Lien.Entree(categorie, actuel), table.concat(cibles, ", "),
            morceaux > LCM.Reseau.RAFALE and string.format(" (%d messages, quelques secondes)", morceaux) or ""))
        return true
    end)
    return d
end

-- ===== La fenetre principale ==============================================

local TYPES_FILTRE = {}

local function Construire()
    local f = UI.Fenetre("compendium", "Système d'A'Hell'Razkah", LARGEUR, HAUTEUR, { x = -120, y = 30 },
        { enTeteSimple = true, redimensionnable = true })
    Fenetre.frame = f
    -- Ouverte par l'entree « Systeme » : c'est elle qui dit qu'elle est
    -- reservee au MJ (/lcm switch la referme).
    f.menuId = "systeme_aelskar"
    f.actif = C.categories[1] and C.categories[1].id
    f.types = {}
    for _, t in ipairs(C.TYPES) do f.types[t.id] = true end
    f.rechercheCategories, f.recherche = "", ""
    f.deplies, f.sousCategorie = {}, {}
    f.selection, f.ancres = {}, {}
    f.page, f.decalageX = 1, 0
    f.edition = false

    -- ----- en-tete ------------------------------------------------------------
    f.reglages = CreateFrame("Button", nil, f)
    f.reglages:SetSize(16, 16)
    f.reglages:SetPoint("RIGHT", f.fermer, "LEFT", -8, 0)
    f.reglages:SetFrameLevel(f:GetFrameLevel() + 6)
    f.reglages.icone = f.reglages:CreateTexture(nil, "ARTWORK")
    f.reglages.icone:SetAllPoints(f.reglages)
    f.reglages.icone:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    f.reglages:SetScript("OnClick", function() f:BasculerEdition() end)
    f.reglages:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Mode édition", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    f.reglages:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.modeEdition = UI.Texte(f, "Mode edition", UI.C.libelle, "GameFontNormalSmall")
    f.modeEdition:SetPoint("RIGHT", f.reglages, "LEFT", -8, 0)
    f.modeEdition:Hide()

    -- ----- panneau de gauche : TYPES et CATEGORIES -------------------------------
    local g = CreateFrame("Frame", nil, f)
    f.gauche = g
    g.fond = UI.Aplat(g, { 0.05, 0.05, 0.05, 0.6 * UI.C.fond[4] })
    g.fond:SetAllPoints(g)
    UI.BordureFine(g, 0.18)

    f.titreTypes = UI.Texte(g, "TYPES", UI.C.libelle, "GameFontNormalSmall")
    f.titreTypes:SetPoint("TOPLEFT", g, "TOPLEFT", INSET, -INSET)
    f.replierTypes = Action(g, "<", 18)
    f.replierTypes:SetSize(18, 18)
    f.replierTypes:SetScript("OnClick", function()
        f.typesReplies = not f.typesReplies
        f:Rafraichir()
    end)
    f.replierTypes:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(f.typesReplies and "Afficher les types" or "Replier les types")
        GameTooltip:Show()
    end)
    f.replierTypes:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.filetTypes = UI.Filet(g)
    f.filetTypes:SetPoint("TOPLEFT", g, "TOPLEFT", INSET, -36)
    f.filetTypes:SetPoint("TOPRIGHT", g, "TOPLEFT", LARGEUR_TYPES - INSET, -36)
    f.colonneTypes = UI.Filet(g, false, true)
    f.colonneTypes:SetPoint("TOPLEFT", g, "TOPLEFT", LARGEUR_TYPES + PANEL_GAP / 2, -INSET)
    f.colonneTypes:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", LARGEUR_TYPES + PANEL_GAP / 2, INSET)

    -- Un bouton par type, plus « Tous » : crees une fois.
    f.boutonsTypes = {}
    local lignesTypes = { { id = "tous", label = "Tous" } }
    for _, t in ipairs(C.TYPES) do lignesTypes[#lignesTypes + 1] = t end
    for index, t in ipairs(lignesTypes) do
        local b = UI.Bouton(g, t.label, LARGEUR_TYPES - 2 * INSET, 22)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b, "LEFT", 8, 1)
        b.label:SetPoint("RIGHT", b, "RIGHT", -6, 1)
        b.label:SetJustifyH("LEFT")
        b.voile = UI.Aplat(b, { 0.5, 0.5, 0.5, 0.18 }, "ARTWORK")
        b.voile:SetAllPoints(b)
        b.typeId = t.id
        b:SetPoint("TOPLEFT", g, "TOPLEFT", INSET, -48 - (index - 1) * 26)
        b:SetScript("OnClick", function(self) f:FiltrerType(self.typeId) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(t.label)
            GameTooltip:AddLine(string.format("%d categorie(s)", f:NombreDeType(self.typeId)), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Afficher ou masquer ce type de categorie.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.boutonsTypes[index] = b
    end

    f.titreCategories = UI.Texte(g, "CATEGORIES", UI.C.libelle, "GameFontNormalSmall")
    f.filetCategories = UI.Filet(g)
    f.rechercheCat = UI.Champ(g, LARGEUR_RECHERCHE, 18, function(texte)
        f.rechercheCategories = texte
        f:Rafraichir()
    end)
    f.effacerCat = Action(g, "X", 14)
    f.effacerCat:SetSize(14, 14)
    f.effacerCat:SetPoint("LEFT", f.rechercheCat, "RIGHT", 4, 0)
    f.effacerCat:SetScript("OnClick", function()
        f.rechercheCategories = ""
        f.rechercheCat:SetText("")
        f:Rafraichir()
    end)
    f.listeCategories = UI.Defilement(g)
    -- Un bouton par categorie, crees une fois ; les sous-categories viennent
    -- d'un vivier qui ne fait que grandir.
    f.boutonsCategories, f.boutonsSous = {}, {}
    for index, categorie in ipairs(C.categories) do
        local b = UI.Bouton(f.listeCategories.contenu, categorie.label, 10, 22)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b, "LEFT", 4, 1)
        b.label:SetPoint("RIGHT", b, "RIGHT", -24, 1)
        b.label:SetJustifyH("LEFT")
        if UI.HabillerOnglet then UI.HabillerOnglet(b) end
        UI.Police(b.label, 12)
        b.categorieId = categorie.id
        b:SetScript("OnClick", function(self) f:ChoisirCategorie(self.categorieId) end)
        -- Lacher une entree sur une categorie la TRANSFERE (le MJ, 23 octobre
        -- 2026) : un type change de liste et ses entrees le suivent, une
        -- entree change de categorie. C'est le compagnon qui juge
        -- (MJ/Transfert.lua) ; chez un joueur, ces boutons ne sont pas des
        -- cibles du tout.
        if LCM.IsMaster() then
            UI.Glisser.Cible(b, function(objet)
                if not LCM.Transfert then return false, nil end
                return LCM.Transfert.Accepte(objet, C.Get(b.categorieId))
            end, function(objet) f:Transferer(objet, b.categorieId) end)
        end
        f.boutonsCategories[index] = b
    end

    -- ----- panneau de droite : les entrees -------------------------------------
    local d = CreateFrame("Frame", nil, f)
    f.droite = d
    d.fond = UI.Aplat(d, { 0.05, 0.05, 0.05, 0.45 * UI.C.fond[4] })
    d.fond:SetAllPoints(d)
    UI.BordureFine(d, 0.18)

    f.colonnesBouton = CreateFrame("Button", nil, d)
    f.colonnesBouton:SetSize(16, 16)
    f.colonnesBouton:SetPoint("TOPRIGHT", d, "TOPRIGHT", -10, -9)
    f.colonnesBouton.icone = f.colonnesBouton:CreateTexture(nil, "ARTWORK")
    f.colonnesBouton.icone:SetAllPoints(f.colonnesBouton)
    f.colonnesBouton.icone:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    f.colonnesBouton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Colonnes affichees", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    f.colonnesBouton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.colonnesBouton:SetScript("OnClick", function() f:OuvrirColonnes() end)

    f.effacer = Action(d, "X", 14)
    f.effacer:SetSize(14, 14)
    f.effacer:SetPoint("RIGHT", f.colonnesBouton, "LEFT", -8, 0)
    f.effacer:SetScript("OnClick", function()
        f.recherche = ""
        f.champRecherche:SetText("")
        f:Rafraichir()
    end)
    f.champRecherche = UI.Champ(d, LARGEUR_RECHERCHE + 40, 18, function(texte)
        f.recherche = texte
        f:Rafraichir()
    end)
    f.champRecherche:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -10)
    f.champRecherche:SetPoint("RIGHT", f.effacer, "LEFT", -4, 0)

    -- Rangee 2 : les actions du MJ. Elles n'existent que si l'editeur est la.
    f.nouvelle = UI.Bouton(d, "Nouvelle entree", 106, 20, function() f:Nouvelle() end)
    f.groupee = UI.Bouton(d, "Modif. groupée", 128, 20, function() f:ModifGroupee() end)
    f.supprimer = UI.Bouton(d, "Supprimer", 100, 20, function() f:SupprimerSelection() end)
    -- A droite de la rangee : la forge, pour une categorie qu'un jeu
    -- d'equilibrage peut viser (MJ/Forge.lua).
    f.forger = UI.Bouton(d, "Forger", 90, 20, function() f:Forger() end)
    f.lectureSeule = UI.Texte(d, "", UI.C.discret, "GameFontNormalSmall")
    f.lectureSeule:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -36)
    f.lectureSeule:SetPoint("TOPRIGHT", d, "TOPRIGHT", -10, -36)
    f.lectureSeule:SetWordWrap(false)

    f.filetEntete = UI.Filet(d)
    f.enteteId = UI.Texte(d, "ID", UI.C.accent, "GameFontNormalSmall")
    f.enteteId:SetWordWrap(false)
    f.enteteNom = UI.Texte(d, "NOM", UI.C.accent, "GameFontNormalSmall")
    f.enteteNom:SetWordWrap(false)
    f.diviseurG = UI.Filet(d, false, true)
    f.diviseurD = UI.Filet(d, false, true)
    f.vueEntete = CreateFrame("Frame", nil, d)
    f.vueEntete:SetHeight(18)
    f.vueEntete:SetClipsChildren(true)
    f.colonnesEntete = {}
    f.filetControles = UI.Filet(d)

    f.lignes = UI.Defilement(d)
    f.aucune = UI.Texte(f.lignes.contenu, "Aucune entree.", UI.C.discret, "GameFontNormalSmall")
    f.aucune:SetPoint("TOPLEFT", f.lignes.contenu, "TOPLEFT", 10, -10)

    -- Pagination : < X / Y >
    f.pagePrec = Action(d, "<", 18)
    f.pagePrec:SetSize(22, 18)
    f.pageTexte = UI.Texte(d, "", UI.C.accent, "GameFontNormalSmall")
    f.pageTexte:SetSize(74, 18)
    f.pageTexte:SetJustifyH("CENTER")
    f.pageTexte:SetPoint("BOTTOM", d, "BOTTOM", 0, 26)
    f.pagePrec:SetPoint("RIGHT", f.pageTexte, "LEFT", -6, 0)
    f.pageSuiv = Action(d, ">", 18)
    f.pageSuiv:SetSize(22, 18)
    f.pageSuiv:SetPoint("LEFT", f.pageTexte, "RIGHT", 6, 0)
    f.pagePrec:SetScript("OnClick", function() f:AllerPage(f.page - 1) end)
    f.pageSuiv:SetScript("OnClick", function() f:AllerPage(f.page + 1) end)

    f.curseur = UI.Curseur(d, function(valeur)
        f.decalageX = valeur
        f:RafraichirLignes()
    end)
    f.curseur:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 10)
    f.curseur:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -28, 10)

    -- Les vingt lignes d'une page, creees une fois.
    f.rangees = {}
    for index = 1, PAR_PAGE do
        f.rangees[index] = Fenetre.NouvelleLigne(f, index)
    end

    -- Fenetre de valeur : le texte complet d'une cellule.
    local v = CreateFrame("Frame", nil, f)
    f.valeur = v
    v:SetSize(360, 250)
    v:SetPoint("CENTER", f, "CENTER", 0, 0)
    v:SetFrameStrata("FULLSCREEN_DIALOG")
    v:EnableMouse(true)
    v:SetMovable(true)
    v:RegisterForDrag("LeftButton")
    v:SetScript("OnDragStart", function(self) self:StartMoving() end)
    v:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    v.fond = UI.Aplat(v, { 0.05, 0.05, 0.05, 0.9 })
    v.fond:SetAllPoints(v)
    UI.BordureFine(v, 0.38)
    v.titre = UI.Texte(v, "Valeur", UI.C.titre, "GameFontNormalSmall")
    v.titre:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -12)
    v.fermer = UI.Bouton(v, "x", 16, 16, function() v:Hide() end)
    v.fermer:SetPoint("TOPRIGHT", v, "TOPRIGHT", -8, -8)
    v.entree = UI.Texte(v, "", UI.C.discret, "GameFontNormalSmall")
    v.entree:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -38)
    v.entree:SetPoint("TOPRIGHT", v, "TOPRIGHT", -34, -38)
    v.filet = UI.Filet(v, true)
    v.filet:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -58)
    v.filet:SetPoint("TOPRIGHT", v, "TOPRIGHT", -12, -58)
    v.corps = UI.Defilement(v)
    v.corps:SetPoint("TOPLEFT", v, "TOPLEFT", 12, -68)
    v.corps:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -28, 12)
    v.texte = UI.Texte(v.corps.contenu, "", UI.C.texte, "GameFontNormalSmall")
    v.texte:SetPoint("TOPLEFT", v.corps.contenu, "TOPLEFT", 0, 0)
    v.texte:SetPoint("TOPRIGHT", v.corps.contenu, "TOPRIGHT", 0, 0)
    v.texte:SetWordWrap(true)
    v:Hide()

    -- Confirmation des suppressions (le seul geste sans retour).
    f.confirmation = UI.Confirmer(f, "", "Supprimer")
    f.confirmationTransfert = UI.Confirmer(f, "", "Transférer")
    f.message = UI.Texte(d, "", UI.C.discret, "GameFontNormalSmall")
    f.message:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 28)
    f.message:SetPoint("RIGHT", f.pagePrec, "LEFT", -10, 0)
    f.message:SetWordWrap(false)

    UI.Redimensionner(f, MIN_L, MIN_H, function() f:Rafraichir() end)
    f:HookScript("OnSizeChanged", function() if not f.enRedimension then f:Rafraichir() end end)
    -- Le panneau de droite ne connait sa largeur qu'une fois mis en page par
    -- le jeu : les colonnes visibles se recalculent a ce moment-la.
    d:SetScript("OnSizeChanged", function()
        if not f.enRedimension and f:IsShown() and not f.enRafraichissement then f:Rafraichir() end
    end)
    f:HookScript("OnShow", function() f:Rafraichir() end)
    f:HookScript("OnHide", function()
        v:Hide()
        f.confirmation:Hide()
        if f.colonnesPopup then f.colonnesPopup:Hide() end
    end)

    Fenetre.Comportement(f)
    return f
end

-- ===== Une ligne du tableau ===============================================

function Fenetre.NouvelleLigne(f, index)
    local r = CreateFrame("Button", nil, f.lignes.contenu)
    r:SetHeight(HAUTEUR_LIGNE)
    r:RegisterForClicks("LeftButtonUp")
    r.fond = UI.Aplat(r, { 0.07, 0.07, 0.07, 0.10 })
    r.fond:SetAllPoints(r)
    UI.BordureFine(r, 0.14)
    r.selectionFond = UI.Aplat(r, { 0.72, 0.72, 0.72, 0.20 }, "BORDER")
    r.selectionFond:SetAllPoints(r)
    r.selectionTrait = UI.Aplat(r, { 0.65, 0.55, 0.28, 0.70 }, "ARTWORK")
    r.selectionTrait:SetWidth(2)
    r.selectionTrait:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
    r.selectionTrait:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 1, 1)
    r.icone = r:CreateTexture(nil, "ARTWORK")
    r.icone:SetSize(18, 18)
    r.icone:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.id = UI.Texte(r, "", UI.C.discret, "GameFontNormalSmall")
    r.id:SetWordWrap(false)
    r.nom = UI.Texte(r, "", UI.C.titre, "GameFontNormalSmall")
    r.nom:SetWordWrap(false)
    local function titreEntree()
        return r.element and (r.element.label or r.element.id) or "Entrée"
    end
    local function texteEntree()
        local e = r.element
        if not e then return "" end
        local categorie = f:Categorie()
        local description = tostring(e.description or "")
        if description ~= "" then return description end
        return categorie and ("Entrée du compendium : " .. categorie.label .. ".")
            or "Entrée du compendium."
    end
    UI.Bulle(r, titreEntree, texteEntree, 0.2)
    r.bulleTitre, r.bulleTexte = titreEntree, texteEntree
    r.diviseurG = UI.Filet(r, false, true)
    r.diviseurD = UI.Filet(r, false, true)
    r.vue = CreateFrame("Frame", nil, r)
    r.vue:SetHeight(24)
    r.vue:SetClipsChildren(true)
    r.cellules = {}

    r.reglages = CreateFrame("Button", nil, r)
    r.reglages:SetSize(14, 14)
    r.reglages.icone = r.reglages:CreateTexture(nil, "ARTWORK")
    r.reglages.icone:SetAllPoints(r.reglages)
    r.reglages.icone:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    r.reglages:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.reglages:SetScript("OnClick", function(_, bouton)
        f:Editer(r.element, bouton == "RightButton" and "creation" or nil)
    end)
    -- Le clic droit n'a de sens que la ou il mene ailleurs : la bulle ne
    -- l'annonce donc que pour les PNJ, et elle se relit a chaque survol
    -- (la categorie affichee change, la ligne est reutilisee).
    UI.Bulle(r.reglages, "Modifier", function()
        local categorie = f:Categorie()
        if categorie and (categorie.id == "pnj" or categorie.famille == "pnj") then
            return "Clic gauche : sa fiche.\n"
                .. "Clic droit : rouvrir sa création — race, niveau, répartition des points."
        end
        return "Ouvre cette entrée dans l'éditeur."
    end)
    r.supprimer = Action(r, "X")
    r.supprimer:SetScript("OnClick", function() f:Supprimer({ r.element }) end)
    r.dupliquer = Action(r, "Dup")
    r.dupliquer:SetScript("OnClick", function() f:Dupliquer(r.element) end)
    r.voir = Action(r, "Voir")
    r.voir:SetWidth(34)
    r.voir:SetScript("OnClick", function() Fenetre.Voir(f:Categorie(), r.element, f) end)
    -- Link : on choisit a qui, et l'entree part entiere (Core/Lien.lua).
    r.lien = Action(r, "Link")
    r.lien:SetScript("OnClick", function()
        if r.element then Fenetre.Partager(f:Categorie(), r.element) end
    end)

    r:SetScript("OnClick", function(self) f:Selectionner(self.element) end)
    -- Glisser une ligne : l'entree part vers un emplacement (la race de la
    -- creation, par exemple), comme dans Necronicon (StartInventoryCompendium-
    -- EntryDrag). L'emplacement dit lui-meme ce qu'il accepte.
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnDragStart", function(self)
        local e = self.element
        if not e then return end
        local categorie = f:Categorie()
        UI.Glisser.Commencer({ icone = LCM.Icone(e.icone), nom = e.label, element = e,
            categorie = categorie.id, ref = C.Reference(categorie, e) })
    end)
    r:Hide()
    return r
end

-- Une cellule (texte ou icone) d'une ligne, par rang de colonne visible.
local function Cellule(r, n)
    local c = r.cellules[n]
    if c then return c end
    c = CreateFrame("Button", nil, r.vue)
    c:SetHeight(20)
    c.texte = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
    c.texte:SetPoint("LEFT", c, "LEFT", 2, 0)
    c.texte:SetPoint("RIGHT", c, "RIGHT", -2, 0)
    c.texte:SetWordWrap(false)
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetSize(18, 18)
    c.icone:SetPoint("LEFT", c, "LEFT", 2, 0)
    c.survol = UI.Aplat(c, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
    c.survol:SetAllPoints(c)
    UI.Bulle(c, r.bulleTitre, r.bulleTexte, 0.2)
    -- Une cellule est un bouton : elle prend la souris a la ligne. Sans ce
    -- relais, on ne glissait une entree qu'en la saisissant par son nom.
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnDragStart", function() local f = r:GetScript("OnDragStart") if f then f(r) end end)
    r.cellules[n] = c
    return c
end

-- ===== Comportement =======================================================

function Fenetre.Comportement(f)
    function f:Categorie() return C.Get(self.actif) end

    function f:NombreDeType(typeId)
        local n = 0
        for _, categorie in ipairs(C.categories) do
            if typeId == "tous" or categorie.type == typeId then n = n + 1 end
        end
        return n
    end

    -- « Tous » coche ou decoche tout ; un type se bascule seul.
    function f:FiltrerType(typeId)
        if typeId == "tous" then
            local tous = true
            for _, t in ipairs(C.TYPES) do tous = tous and self.types[t.id] end
            for _, t in ipairs(C.TYPES) do self.types[t.id] = not tous end
        else
            self.types[typeId] = not self.types[typeId]
        end
        self:Rafraichir()
    end

    -- Une categorie a sous-categories se deplie au clic (et s'active) ; un
    -- second clic sur l'active la replie. Les autres s'activent.
    function f:ChoisirCategorie(id)
        local categorie = C.Get(id)
        if not categorie then return end
        if C.SousCategories(categorie) then
            if self.actif ~= id then
                self.deplies[id] = true
                self.sousCategorie[id] = nil
            else
                self.deplies[id] = not self.deplies[id]
                if not self.deplies[id] then self.sousCategorie[id] = nil end
            end
        end
        self.actif = id
        self.page, self.decalageX = 1, 0
        self.lignes:Aller(0)
        self:Rafraichir()
    end

    function f:ChoisirSousCategorie(id, cle)
        self.actif = id
        self.deplies[id] = true
        self.sousCategorie[id] = self.sousCategorie[id] ~= cle and cle or nil
        self.page = 1
        self.lignes:Aller(0)
        self:Rafraichir()
    end

    function f:AllerPage(page)
        self.page = math.max(1, math.min(page, self.pages or 1))
        self.lignes:Aller(0)
        self:Rafraichir()
    end

    function f:BasculerEdition()
        if not Editeur() then return end
        self.edition = not self.edition
        self:Rafraichir()
    end

    -- ----- selection (Ctrl : ajoute ou retire ; Maj : etend depuis l'ancre) ---
    function f:Selection()
        self.selection[self.actif] = self.selection[self.actif] or {}
        return self.selection[self.actif]
    end

    function f:Selectionner(element)
        if not element then return end
        local sel = self:Selection()
        local ctrl, maj = IsControlKeyDown and IsControlKeyDown(), IsShiftKeyDown and IsShiftKeyDown()
        if maj then
            if not ctrl then for k in pairs(sel) do sel[k] = nil end end
            local debut, fin
            for n, e in ipairs(self.filtrees or {}) do
                if e.id == self.ancres[self.actif] then debut = n end
                if e.id == element.id then fin = n end
            end
            debut = debut or fin
            if debut and fin then
                for n = math.min(debut, fin), math.max(debut, fin) do sel[self.filtrees[n].id] = true end
            end
        elseif ctrl then
            sel[element.id] = not sel[element.id] or nil
            self.ancres[self.actif] = element.id
        else
            for k in pairs(sel) do sel[k] = nil end
            sel[element.id] = true
            self.ancres[self.actif] = element.id
        end
        self:RafraichirSelection()
    end

    function f:Selectionnees()
        local sel, out = self:Selection(), {}
        for _, e in ipairs(C.Entrees(self:Categorie())) do
            if sel[e.id] then out[#out + 1] = e end
        end
        return out
    end

    function f:RafraichirSelection()
        local sel = self:Selection()
        for _, r in ipairs(self.rangees) do
            local choisie = r.element ~= nil and sel[r.element.id] == true
            r.selectionFond:SetShown(choisie)
            r.selectionTrait:SetShown(choisie)
        end
        local n = #self:Selectionnees()
        local function Etat(bouton, texte)
            bouton.label:SetText(n > 0 and string.format("%s (%d)", texte, n) or texte)
            bouton:SetEnabled(n > 0)
            Peindre(bouton.label, n > 0 and UI.C.accent or UI.C.discret)
        end
        Etat(self.groupee, "Modif. groupée")
        Etat(self.supprimer, "Supprimer")
    end

    -- ----- gestes du MJ (delegues a l'editeur du compagnon) -------------------
    function f:Message(texte, couleur)
        self.message:SetText(texte or "")
        Peindre(self.message, couleur or UI.C.discret)
    end

    function f:Forger()
        if self:Categorie().constructeur then return self:Nouvelle() end
        if not (LCM.IsMaster() and UI.Forge) then return end
        local ok, raison = UI.Forge.Ouvrir(self:Categorie().id)
        if not ok then self:Message("Forge : " .. tostring(raison), UI.C.plein) end
    end

    function f:Nouvelle()
        local ed = Editeur()
        if ed then ed.Ouvrir(self:Categorie(), nil) end
    end

    function f:Editer(element, mode)
        local ed = Editeur()
        if ed and element then ed.Ouvrir(self:Categorie(), element, mode) end
    end

    function f:Dupliquer(element)
        local ed = Editeur()
        if not (ed and element) then return end
        local ok, raison = ed.Dupliquer(self:Categorie(), element)
        if ok then self:Message("Copie créée : " .. tostring(raison), UI.C.accent)
        else self:Message("Refusé : " .. tostring(raison), UI.C.plein) end
        self:Rafraichir()
    end

    function f:Supprimer(elements)
        local ed = Editeur()
        if not ed or #elements == 0 then return end
        local noms = {}
        for _, e in ipairs(elements) do noms[#noms + 1] = e.label end
        self.confirmation:Demander(
            string.format("Supprimer %s ?\nRetiré du jeu tout de suite, et de la base au prochain /reload.",
                #noms == 1 and ("« " .. noms[1] .. " »") or (#noms .. " entrées")),
            function()
                local faits, refus = ed.Supprimer(self:Categorie(), elements)
                if refus and refus ~= "" then
                    self:Message(string.format("%d supprimée(s). Refus : %s", faits, refus), UI.C.plein)
                else
                    self:Message(string.format("%d supprimée(s).", faits), UI.C.accent)
                end
                for k in pairs(self:Selection()) do self:Selection()[k] = nil end
                self:Rafraichir()
            end)
    end

    function f:SupprimerSelection() self:Supprimer(self:Selectionnees()) end

    -- Une entree lachee sur le bouton d'une categorie : le plan se montre, et
    -- rien ne bouge avant que le MJ l'accepte. Un refus dit pourquoi.
    function f:Transferer(objet, categorieId)
        if not LCM.Transfert then return end
        local plan, raison = LCM.Transfert.Plan(objet, C.Get(categorieId))
        if not plan then
            self:Message("Transfert refusé : " .. tostring(raison), UI.C.plein)
            return
        end
        self.confirmationTransfert:Demander(plan.question, function()
            local ok, message = LCM.Transfert.Lancer(plan)
            self:Message(tostring(message), ok and UI.C.accent or UI.C.plein)
            self:Rafraichir()
        end)
    end

    function f:ModifGroupee()
        local ed = Editeur()
        local elements = self:Selectionnees()
        if ed and #elements > 0 then ed.ModifGroupee(self:Categorie(), elements) end
    end

    -- ----- colonnes affichees ------------------------------------------------
    function f:OuvrirColonnes()
        local p = self.colonnesPopup
        if not p then
            p = CreateFrame("Frame", nil, self)
            p:SetSize(240, 320)
            p:SetFrameStrata("FULLSCREEN_DIALOG")
            p:EnableMouse(true)
            p:SetMovable(true)
            p:RegisterForDrag("LeftButton")
            p:SetScript("OnDragStart", function(s) s:StartMoving() end)
            p:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
            p.fond = UI.Aplat(p, { 0.05, 0.05, 0.05, 1 })
            p.fond:SetAllPoints(p)
            UI.BordureFine(p, 0.4)
            p.titre = UI.Texte(p, "Colonnes affichees", UI.C.titre, "GameFontNormalSmall")
            p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
            p.fermer = UI.Bouton(p, "x", 16, 16, function() p:Hide() end)
            p.fermer:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
            p.zone = UI.Defilement(p)
            p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -32)
            p.zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -28, 12)
            p.cases = {}
            self.colonnesPopup = p
        end
        p:ClearAllPoints()
        p:SetPoint("TOPRIGHT", self.colonnesBouton, "BOTTOMRIGHT", 0, -4)
        self:RafraichirColonnes()
        p:Show()
        p:Raise()
    end

    function f:RafraichirColonnes()
        local p = self.colonnesPopup
        if not p then return end
        local categorie = self:Categorie()
        local masquees = Masquees(categorie.id)
        local colonnes = C.Colonnes(categorie)
        for n, champ in ipairs(colonnes) do
            local case = p.cases[n]
            if not case then
                case = UI.Case(p.zone.contenu, "", function(coche)
                    local c = p.cases[n]
                    Masquer(f.actif, c.cle, not coche)
                    f:Rafraichir()
                end)
                p.cases[n] = case
            end
            case.cle = champ.cle
            case.label:SetText(champ.label)
            case:ClearAllPoints()
            case:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 4, -6 - (n - 1) * 24)
            case:Cocher(not masquees[champ.cle])
            case:Show()
        end
        for n = #colonnes + 1, #p.cases do p.cases[n]:Hide() end
        p.zone:Regler(12 + #colonnes * 24)
    end

    -- ----- rendu ---------------------------------------------------------------
    function f:Disposer()
        local replie = self.typesReplies
        local decalage = replie and 0 or DECALAGE_CATEGORIES
        local g = self.gauche
        g:ClearAllPoints()
        g:SetPoint("TOPLEFT", self, "TOPLEFT", 12, PANEL_TOP)
        g:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 12, PANEL_BOTTOM)
        g:SetWidth(replie and LARGEUR_CATEGORIES or (DECALAGE_CATEGORIES + LARGEUR_CATEGORIES))
        for _, w in ipairs({ self.titreTypes, self.filetTypes, self.colonneTypes }) do w:SetShown(not replie) end
        for _, b in ipairs(self.boutonsTypes) do b:SetShown(not replie) end
        self.replierTypes:ClearAllPoints()
        self.replierTypes:SetPoint("TOPLEFT", g, "TOPLEFT", replie and INSET or (LARGEUR_TYPES - 28), -INSET)
        self.replierTypes.label:SetText(replie and ">" or "<")
        self.titreCategories:ClearAllPoints()
        self.titreCategories:SetPoint("TOPLEFT", g, "TOPLEFT", decalage + INSET + (replie and 24 or 0), -INSET - 5)
        self.filetCategories:ClearAllPoints()
        self.filetCategories:SetPoint("TOPLEFT", g, "TOPLEFT", decalage + INSET, -36)
        self.filetCategories:SetPoint("TOPRIGHT", g, "TOPRIGHT", -10, -36)
        self.rechercheCat:ClearAllPoints()
        self.rechercheCat:SetPoint("TOPLEFT", g, "TOPLEFT", decalage + INSET, -48)
        self.listeCategories:ClearAllPoints()
        self.listeCategories:SetPoint("TOPLEFT", g, "TOPLEFT", decalage + INSET, -72)
        self.listeCategories:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -28, INSET)
        local d = self.droite
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", g, "TOPRIGHT", PANEL_GAP, 0)
        d:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -12, PANEL_BOTTOM)
    end

    function f:RafraichirTypes()
        local tous = true
        for _, t in ipairs(C.TYPES) do tous = tous and self.types[t.id] end
        for _, b in ipairs(self.boutonsTypes) do
            local actif = b.typeId == "tous" and tous or (b.typeId ~= "tous" and self.types[b.typeId])
            b.voile:SetColorTexture(actif and 0.5 or 0, actif and 0.5 or 0, actif and 0.5 or 0, actif and 0.18 or 0.24)
            Peindre(b.label, actif and UI.C.texte or UI.C.discret)
        end
    end

    function f:RafraichirCategories()
        local filtre = tostring(self.rechercheCategories or ""):lower()
        local y, nSous = 0, 0
        for index, categorie in ipairs(C.categories) do
            local b = self.boutonsCategories[index]
            local groupes = C.SousCategories(categorie)
            local deplie = groupes ~= nil and self.deplies[categorie.id] == true
            local nomCorrespond = filtre == "" or categorie.label:lower():find(filtre, 1, true) ~= nil
            local montres = nil
            if groupes and (deplie or filtre ~= "") then
                if filtre == "" or nomCorrespond then
                    montres = deplie and groupes or nil
                else
                    montres = {}
                    for _, gr in ipairs(groupes) do
                        if gr.label:lower():find(filtre, 1, true) then montres[#montres + 1] = gr end
                    end
                end
            end
            local visible = self.types[categorie.type] and (nomCorrespond or (montres and #montres > 0))
            b:SetShown(visible and true or false)
            if visible then
                -- Etire sur la colonne : la largeur suit le panneau, meme avant
                -- qu'il ait sa taille definitive.
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.listeCategories.contenu, "TOPLEFT", 0, -y)
                b:SetPoint("TOPRIGHT", self.listeCategories.contenu, "TOPRIGHT", -10, -y)
                b.label:SetText((groupes and (deplie and "- " or "+ ") or "") .. categorie.label)
                if b.Selectionner then b:Selectionner(categorie.id == self.actif) end
                y = y + 28
                for _, gr in ipairs(montres or {}) do
                    nSous = nSous + 1
                    local s = self.boutonsSous[nSous]
                    if not s then
                        s = UI.Bouton(self.listeCategories.contenu, "", 10, 20, function(bouton)
                            f:ChoisirSousCategorie(bouton.categorieId, bouton.cle)
                        end)
                        s.label:ClearAllPoints()
                        s.label:SetPoint("LEFT", s, "LEFT", 12, 1)
                        s.label:SetPoint("RIGHT", s, "RIGHT", -4, 1)
                        s.label:SetJustifyH("LEFT")
                        if UI.HabillerOnglet then UI.HabillerOnglet(s) end
                        UI.Police(s.label, 11)
                        self.boutonsSous[nSous] = s
                    end
                    s.categorieId, s.cle = categorie.id, gr.cle
                    s:ClearAllPoints()
                    s:SetPoint("TOPLEFT", self.listeCategories.contenu, "TOPLEFT", 12, -y)
                    s:SetPoint("TOPRIGHT", self.listeCategories.contenu, "TOPRIGHT", -10, -y)
                    s.label:SetText("> " .. gr.label .. "  (" .. gr.nombre .. ")")
                    if s.Selectionner then
                        s:Selectionner(categorie.id == self.actif and self.sousCategorie[categorie.id] == gr.cle)
                    end
                    s:Show()
                    y = y + 22
                end
            end
        end
        for n = nSous + 1, #self.boutonsSous do self.boutonsSous[n]:Hide() end
        self.listeCategories:Regler(y)
    end

    -- Les entrees de la categorie active, filtrees par sous-categorie et
    -- recherche. La selection garde toute la liste ; seul le rendu est pagine.
    function f:Filtrer()
        local categorie = self:Categorie()
        local aiguille = tostring(self.recherche or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local cle = self.sousCategorie[categorie.id]
        -- Une sous-categorie disparue (sa derniere entree a change de type)
        -- n'est plus selectionnee.
        if cle then
            local existe = false
            for _, gr in ipairs(C.SousCategories(categorie) or {}) do existe = existe or gr.cle == cle end
            if not existe then self.sousCategorie[categorie.id] = nil cle = nil end
        end
        local out = {}
        for _, e in ipairs(C.Entrees(categorie)) do
            if C.DansSousCategorie(categorie, e, cle)
                and (aiguille == "" or C.Recherche(categorie, e):find(aiguille, 1, true)) then
                out[#out + 1] = e
            end
        end
        return out
    end

    function f:LargeurActions()
        local editeur = Editeur()
        local lien = #"Link" * 7 + 10 + 8
        if not editeur then return math.max(ACTION_MIN, Largeur("Voir") + 20 + 12 + lien) end
        local voir = Largeur("Voir") + 20
        local dup = Largeur("Dup") + 16
        local x = math.max(18, Largeur("X") + 10)
        local vue = 14 + 8 + dup + 8 + voir + 12 + lien
        local edition = 14 + 8 + x + 8 + dup + 20 + lien
        return math.min(ACTION_MAX, math.max(ACTION_MIN, vue, edition))
    end

    function f:RafraichirLignes()
        local categorie = self:Categorie()
        local d = self.droite
        local masquees = Masquees(categorie.id)
        local colonnes = {}
        for _, champ in ipairs(C.Colonnes(categorie)) do
            if not masquees[champ.cle] then colonnes[#colonnes + 1] = champ end
        end
        local function LargeurColonne(champ)
            return LARGEURS[champ.cle] or LARGEURS[champ.type] or 96
        end
        -- L'icone, s'il y en a une, ouvre la ligne, avant l'ID.
        local avecIcone = C.AIcone(categorie)
        local gauche = avecIcone and (10 + 18 + ECART) or 10
        local largeurEntete = math.max((d:GetWidth() or 400) - 20 - (gauche - 10), 260)
        local actions = self:LargeurActions()
        -- ID et NOM a la mesure de leur contenu, bornes (GetCompendiumFixedColumnWidths).
        local plusId, plusNom = Largeur("ID"), Largeur("NOM")
        for _, e in ipairs(self.filtrees) do
            plusId = math.max(plusId, Largeur(e.id))
            plusNom = math.max(plusNom, Largeur(e.label))
        end
        local largeurId = math.min(ID_MAX, math.max(ID_MIN, plusId + 14))
        local largeurNom = math.min(NOM_MAX, math.max(NOM_MIN, plusNom + 18))
        largeurNom = math.min(largeurNom, math.max(NOM_MIN, largeurEntete - largeurId - actions - 2 * ECART - 120))
        local visible = math.max(largeurEntete - largeurId - largeurNom - actions - 2 * ECART, 120)
        -- Peu de colonnes choisies (`colonnesTableau`) : la derniere prend la
        -- place qui reste, plutot que de laisser un vide a droite.
        if categorie.colonnesTableau and #colonnes > 0 then
            local avant, derniere = 0, colonnes[#colonnes]
            for n = 1, #colonnes - 1 do avant = avant + LargeurColonne(colonnes[n]) + ECART end
            local etiree = math.max(LargeurColonne(derniere), visible - avant - 4)
            local base = LargeurColonne
            LargeurColonne = function(champ) return champ == derniere and etiree or base(champ) end
        end

        local total, positions = 0, {}
        for n, champ in ipairs(colonnes) do
            positions[n] = total
            total = total + LargeurColonne(champ) + (n < #colonnes and ECART or 0)
        end
        local maxDecalage = math.max(0, total - visible)
        self.decalageX = math.max(0, math.min(self.decalageX, maxDecalage))
        self.curseur:Regler(maxDecalage, self.decalageX)

        -- En-tete.
        local extra = self.extraActions or 0
        local yEntete = -74 - extra
        self.enteteId:ClearAllPoints()
        self.enteteId:SetPoint("TOPLEFT", d, "TOPLEFT", gauche, yEntete)
        self.enteteId:SetWidth(largeurId)
        self.enteteNom:ClearAllPoints()
        self.enteteNom:SetPoint("LEFT", self.enteteId, "RIGHT", ECART, 0)
        self.enteteNom:SetWidth(largeurNom)
        self.vueEntete:ClearAllPoints()
        self.vueEntete:SetPoint("TOPLEFT", self.enteteNom, "TOPRIGHT", ECART, 0)
        self.vueEntete:SetPoint("TOPRIGHT", d, "TOPRIGHT", -(actions + 10), yEntete)
        self.diviseurG:ClearAllPoints()
        self.diviseurG:SetPoint("TOPLEFT", self.enteteNom, "TOPRIGHT", ECART / 2, 12)
        self.diviseurG:SetPoint("BOTTOMLEFT", self.enteteNom, "BOTTOMRIGHT", ECART / 2, -4)
        self.diviseurD:ClearAllPoints()
        self.diviseurD:SetPoint("TOPLEFT", self.vueEntete, "TOPRIGHT", ECART / 2, 12)
        self.diviseurD:SetPoint("BOTTOMLEFT", self.vueEntete, "BOTTOMRIGHT", ECART / 2, -4)

        -- Seules les colonnes qui tombent dans la vue sont dessinees.
        local premiere, derniere = nil, nil
        for n, champ in ipairs(colonnes) do
            local x = positions[n] - self.decalageX
            if x + LargeurColonne(champ) > 0 and x < visible then
                premiere = premiere or n
                derniere = n
            end
        end
        local nVisibles = premiere and (derniere - premiere + 1) or 0
        for k = 1, nVisibles do
            local champ = colonnes[premiere + k - 1]
            local h = self.colonnesEntete[k]
            if not h then
                h = UI.Texte(self.vueEntete, "", UI.C.accent, "GameFontNormalSmall")
                h:SetWordWrap(false)
                self.colonnesEntete[k] = h
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.vueEntete, "TOPLEFT", positions[premiere + k - 1] - self.decalageX, -2)
            h:SetWidth(LargeurColonne(champ))
            h:SetText(UI.Majuscules(champ.label))
            h:Show()
        end
        for k = nVisibles + 1, #self.colonnesEntete do self.colonnesEntete[k]:Hide() end

        -- Lignes de la page.
        local editeur = Editeur()
        local editable = editeur ~= nil and C.Editable(categorie)
        local debut = (self.page - 1) * PAR_PAGE
        local nLignes = 0
        for index = 1, PAR_PAGE do
            local r = self.rangees[index]
            local e = self.filtrees[debut + index]
            r.element = e
            if not e then
                r:Hide()
            else
                nLignes = nLignes + 1
                local rf, gf, bf = Couleur(e.couleurFond or LCM.COULEUR_FOND)
                r.fond:SetColorTexture(rf, gf, bf, 0.10)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", self.lignes.contenu, "TOPLEFT", 0, -(index - 1) * PAS_LIGNE)
                r:SetPoint("TOPRIGHT", self.lignes.contenu, "TOPRIGHT", -4, -(index - 1) * PAS_LIGNE)
                r.id:ClearAllPoints()
                r.id:SetPoint("LEFT", r, "LEFT", gauche, 0)
                r.id:SetWidth(largeurId)
                r.icone:SetShown(avecIcone)
                if avecIcone then r.icone:SetTexture(LCM.Icone(e.icone)) end
                r.id:SetText(e.id)
                r.nom:ClearAllPoints()
                r.nom:SetPoint("LEFT", r.id, "RIGHT", ECART, 0)
                r.nom:SetWidth(largeurNom)
                r.nom:SetText(e.label)
                r.nom:SetTextColor(Couleur(e.couleurTitre or LCM.COULEUR_TITRE))
                local xDiv = gauche + largeurId + ECART + largeurNom + ECART / 2
                r.diviseurG:ClearAllPoints()
                r.diviseurG:SetPoint("TOPLEFT", r, "TOPLEFT", xDiv, -3)
                r.diviseurG:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", xDiv, 3)
                r.vue:ClearAllPoints()
                r.vue:SetPoint("LEFT", r.nom, "RIGHT", ECART, 0)
                r.vue:SetPoint("RIGHT", r, "RIGHT", -(actions + 10), 0)
                r.diviseurD:ClearAllPoints()
                r.diviseurD:SetPoint("TOPLEFT", r, "TOPRIGHT", -(actions + 10) + ECART / 2, -3)
                r.diviseurD:SetPoint("BOTTOMLEFT", r, "BOTTOMRIGHT", -(actions + 10) + ECART / 2, 3)
                for k = 1, nVisibles do
                    local champ = colonnes[premiere + k - 1]
                    local c = Cellule(r, k)
                    local largeur = LargeurColonne(champ)
                    c:ClearAllPoints()
                    c:SetPoint("LEFT", r.vue, "LEFT", positions[premiere + k - 1] - self.decalageX - 2, 0)
                    c:SetWidth(largeur + 4)
                    c.champ = champ
                    if champ.type == "icone" then
                        c.icone:SetTexture(LCM.Icone(e.icone))
                        c.icone:Show()
                        c.texte:Hide()
                        c:SetScript("OnClick", function() f:Selectionner(r.element) end)
                    else
                        c.icone:Hide()
                        local texte = C.Texte(categorie, champ, C.Brut(categorie, champ, e), "compact")
                        c.texte:SetText(texte ~= "" and texte or "-")
                        c.texte:Show()
                        c:SetScript("OnClick", function(cellule) f:OuvrirValeur(r.element, cellule.champ) end)
                    end
                    c:Show()
                end
                for k = nVisibles + 1, #r.cellules do r.cellules[k]:Hide() end

                -- Actions : Voir pour tous ; Dup et reglages pour le MJ ; X en
                -- mode edition seulement.
                for _, b in ipairs({ r.reglages, r.supprimer, r.dupliquer, r.voir, r.lien }) do b:ClearAllPoints() end
                r.reglages:SetShown(editable)
                r.dupliquer:SetShown(editable)
                r.supprimer:SetShown(editable and self.edition)
                r.voir:SetShown(not self.edition or not editable)
                if editable and self.edition then
                    r.reglages:SetPoint("RIGHT", r, "RIGHT", -10, 0)
                    r.supprimer:SetPoint("RIGHT", r.reglages, "LEFT", -8, 0)
                    r.dupliquer:SetPoint("RIGHT", r.supprimer, "LEFT", -8, 0)
                elseif editable then
                    r.reglages:SetPoint("RIGHT", r, "RIGHT", -10, 0)
                    r.dupliquer:SetPoint("RIGHT", r.reglages, "LEFT", -8, 0)
                    r.voir:SetPoint("RIGHT", r.dupliquer, "LEFT", -8, 0)
                else
                    r.voir:SetPoint("RIGHT", r, "RIGHT", -10, 0)
                end
                -- Link, a gauche du premier bouton montre.
                r.lien:SetPoint("RIGHT", r.voir:IsShown() and r.voir or r.dupliquer, "LEFT", -8, 0)
                r:Show()
            end
        end
        self.lignes:Regler(nLignes * PAS_LIGNE)
        self.aucune:SetShown(#self.filtrees == 0)
        self.aucune:SetText(#C.Entrees(categorie) > 0 and "Aucune entree ne correspond a la recherche." or "Aucune entree.")
        self:RafraichirSelection()
    end

    -- Un rafraichissement n'en declenche pas un second (la mise en page change
    -- des tailles, qui previennent la fenetre) ; une erreur ne laisse pas la
    -- fenetre bloquee.
    function f:Rafraichir()
        if not self:IsShown() or self.enRafraichissement then return end
        if not self:Categorie() then return end
        self.enRafraichissement = true
        local ok, erreur = pcall(self.Remettre, self)
        self.enRafraichissement = nil
        if not ok then error(erreur, 0) end
    end

    function f:Remettre()
        local categorie = self:Categorie()
        self:Disposer()
        self:RafraichirTypes()
        self:RafraichirCategories()

        -- Rangee d'actions du MJ, qui passe a la ligne si le panneau est etroit.
        local ed = Editeur()
        local editable = ed ~= nil and C.Editable(categorie)
        self.reglages:SetShown(ed ~= nil)
        self.modeEdition:SetShown(ed ~= nil and self.edition)
        local d = self.droite
        local boutons = { self.nouvelle, self.groupee, self.supprimer }
        local x, rang = 0, 0
        local utile = math.max(200, (d:GetWidth() or 400) - 20)
        -- « Forger », cale a droite de la premiere rangee : les autres lui
        -- laissent sa place.
        -- Une categorie a constructeur (lanternes, cristaux) a le sien a la
        -- place de la forge : meme bouton, meme place (23 octobre 2026).
        local forgeable = editable and LCM.IsMaster()
            and ((UI.Forge ~= nil and categorie.statistiques == "bonus") or categorie.constructeur == true)
        self.forger:SetShown(forgeable)
        if forgeable then
            self.forger:ClearAllPoints()
            self.forger:SetPoint("TOPRIGHT", d, "TOPRIGHT", -10, -34)
            utile = utile - self.forger:GetWidth() - 10
        end
        for _, b in ipairs(boutons) do
            b:SetShown(editable)
            if editable then
                local w = b:GetWidth()
                if x > 0 and x + w > utile then rang, x = rang + 1, 0 end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", d, "TOPLEFT", 10 + x, -34 - rang * 24)
                x = x + w + 10
            end
        end
        -- Une categorie qu'on ne cree pas en jeu le dit, avec la raison.
        local raison = ed ~= nil and categorie.lectureSeule or nil
        self.lectureSeule:SetText(raison and ("Lecture seule : " .. raison) or "")
        self.lectureSeule:SetShown(raison ~= nil)
        self.extraActions = rang * 24
        self.filetEntete:ClearAllPoints()
        self.filetEntete:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -60 - self.extraActions)
        self.filetEntete:SetPoint("TOPRIGHT", d, "TOPRIGHT", -10, -60 - self.extraActions)
        self.filetControles:ClearAllPoints()
        self.filetControles:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -94 - self.extraActions)
        self.filetControles:SetPoint("TOPRIGHT", d, "TOPRIGHT", -10, -94 - self.extraActions)
        self.lignes:ClearAllPoints()
        self.lignes:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -106 - self.extraActions)
        self.lignes:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -28, 46)

        self.filtrees = self:Filtrer()
        -- Une recherche ou une sous-categorie nouvelle ramene en page 1.
        local contexte = table.concat({ self.actif, self.recherche or "", tostring(self.sousCategorie[self.actif]) }, "|")
        if contexte ~= self.contexte then
            self.contexte = contexte
            self.page = 1
        end
        self.pages = math.max(1, math.ceil(#self.filtrees / PAR_PAGE))
        self.page = math.max(1, math.min(self.page, self.pages))
        local plusieurs = self.pages > 1
        self.pagePrec:SetShown(plusieurs)
        self.pageSuiv:SetShown(plusieurs)
        self.pageTexte:SetShown(plusieurs)
        self.pageTexte:SetText(string.format("%d / %d", self.page, self.pages))
        self.pagePrec:SetEnabled(self.page > 1)
        self.pageSuiv:SetEnabled(self.page < self.pages)

        self:RafraichirLignes()
        if self.colonnesPopup and self.colonnesPopup:IsShown() then self:RafraichirColonnes() end
    end

    function f:OuvrirValeur(element, champ)
        if not element then return end
        self:Selectionner(element)
        if (IsControlKeyDown and IsControlKeyDown()) or (IsShiftKeyDown and IsShiftKeyDown()) then return end
        local categorie = self:Categorie()
        local v = self.valeur
        v.titre:SetText(UI.Majuscules(champ.label))
        v.entree:SetText(element.label)
        local texte = C.Texte(categorie, champ, C.Brut(categorie, champ, element), "full")
        v.texte:SetText(texte ~= "" and texte or "-")
        v.texte:SetWidth(300)
        v.corps:Regler((v.texte:GetStringHeight() or 0) + 6)
        v.corps:Aller(0)
        v:Show()
        v:Raise()
    end
end

-- ===== Ouverture ==========================================================

function Fenetre.Fenetre()
    if not Fenetre.frame then Construire() end
    return Fenetre.frame
end

function Fenetre.Basculer()
    local f = Fenetre.Fenetre()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- Ouvre sur une categorie (et, au besoin, une entree selectionnee).
function Fenetre.Ouvrir(categorieId)
    local f = Fenetre.Fenetre()
    if categorieId and C.Get(categorieId) then f.actif = categorieId end
    f:Show()
    f:Rafraichir()
    return f
end

-- Apres un enregistrement du MJ : la fenetre et les cartes ouvertes se
-- remettent a jour, sans fermer quoi que ce soit.
function Fenetre.Actualiser()
    if Fenetre.frame and Fenetre.frame:IsShown() then Fenetre.frame:Rafraichir() end
    for _, carte in ipairs(cartes) do
        if carte:IsShown() then
            local categorie = C.Get(carte.categorieId)
            local element = categorie and C.Entree(categorie, carte.entreeId)
            if element then carte:Montrer(categorie, element) else carte:Hide() end
        end
    end
end

LCM.WhenReady(function()
    if UI.Menu and UI.Menu.Lier then
        UI.Menu.Lier("systeme_aelskar", Fenetre.Basculer)
    end
end)
