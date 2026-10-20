-- La fenetre Metiers.
--
-- Reprise de la feuille de metiers du template (Necronicon, Profession.lua) :
-- une colonne des metiers (220 de large) — icone, nom, palier dans sa
-- couleur — et, a droite, le metier choisi : description, palier, barre
-- d'experience vers le palier suivant, bonus de jet. Le MJ ajoute ou retire
-- de l'experience.
--
-- Les connaissances (recettes, composants, niveau requis) viendront avec les
-- placements : cette fenetre ne pose que les metiers et leur progression.

local _, LCM = ...
local UI = LCM.UI
local Metiers = LCM.Metiers

local Ecran = {}
UI.Metiers = Ecran

local LARGEUR, HAUTEUR = 620, 540
local COLONNE = 220
local LIGNE = 34

local function Couleur(fs, c)
    if c then fs:SetTextColor(c[1], c[2], c[3]) end
end

local function Construire()
    local f = UI.Fenetre("metiers", "Métiers", LARGEUR, HAUTEUR, { x = 200, y = 10 })
    Ecran.frame = f
    f.nom = f.sousTitre

    -- ----- la colonne des metiers -----------------------------------------
    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(COLONNE)
    f.lignes = {}
    for index, metier in ipairs(Metiers.list) do
        local b = CreateFrame("Button", nil, f.liste.contenu)
        b:SetHeight(LIGNE - 2)
        b:SetPoint("TOPLEFT", f.liste.contenu, "TOPLEFT", 0, -(index - 1) * LIGNE)
        b:SetPoint("TOPRIGHT", f.liste.contenu, "TOPRIGHT", 0, -(index - 1) * LIGNE)
        if UI.SurfaceLigne then UI.SurfaceLigne(b) end
        b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
        b.survol:SetAllPoints(b)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetSize(LIGNE - 8, LIGNE - 8)
        b.icone:SetPoint("LEFT", b, "LEFT", 4, 0)
        b.icone:SetTexture(metier.icone)
        b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.label = UI.Texte(b, metier.label, UI.C.texte)
        UI.Police(b.label, 12)
        b.label:SetPoint("LEFT", b.icone, "RIGHT", 6, 0)
        b.palier = UI.Texte(b, "", UI.C.discret)
        UI.Police(b.palier, 11)
        b.palier:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.metierId = metier.id
        b:SetScript("OnClick", function(bouton) f:Choisir(bouton.metierId) end)
        f.lignes[index] = b
    end
    f.liste:Regler(#Metiers.list * LIGNE)

    -- ----- le detail --------------------------------------------------------
    local d = CreateFrame("Frame", nil, f.contenu)
    d:SetPoint("TOPLEFT", f.liste, "TOPRIGHT", 16, 0)
    d:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.detail = d
    local largeurDetail = LARGEUR - 24 - COLONNE - 16
    d.bloc = UI.Fiche.Bloc(d, { label = "Métier" }, largeurDetail)
    d.bloc:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    d.bloc:SetSize(largeurDetail, 300)
    local y = d.bloc.hautTitre + 12
    d.icone = d.bloc:CreateTexture(nil, "ARTWORK")
    d.icone:SetSize(50, 50)
    d.icone:SetPoint("TOPLEFT", d.bloc, "TOPLEFT", 16, -y)
    d.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if UI.AelCadre then
        local support = CreateFrame("Frame", nil, d.bloc)
        support:SetPoint("TOPLEFT", d.icone, "TOPLEFT", -2, 2)
        support:SetPoint("BOTTOMRIGHT", d.icone, "BOTTOMRIGHT", 2, -2)
        UI.AelCadre(support, "icone")
    end
    d.label = UI.Texte(d.bloc, "", UI.C.titre)
    UI.Police(d.label, 18)
    d.label:SetPoint("TOPLEFT", d.icone, "TOPRIGHT", 12, -2)
    d.palier = UI.Texte(d.bloc, "", UI.C.texte)
    UI.Police(d.palier, 14)
    d.palier:SetPoint("TOPLEFT", d.label, "BOTTOMLEFT", 0, -6)
    y = y + 64
    d.description = UI.Texte(d.bloc, "", UI.C.texte)
    UI.Police(d.description, 12)
    d.description:SetWidth(largeurDetail - 32)
    d.description:SetWordWrap(true)
    d.description:SetPoint("TOPLEFT", d.bloc, "TOPLEFT", 16, -y)
    d.barre = UI.Barre(d.bloc, { 0.83, 0.68, 0.33 }, largeurDetail - 32, 18)
    if UI.AelCadreJauge then UI.AelCadreJauge(d.barre) end
    d.xp = UI.Texte(d.bloc, "", UI.C.discret)
    UI.Police(d.xp, 11)
    d.bonus = UI.Texte(d.bloc, "", UI.C.accent)
    UI.Police(d.bonus, 12)

    -- Le MJ donne ou retire de l'experience (1, 5 ou 10).
    d.boutons = {}
    for i, pas in ipairs({ -10, -5, -1, 1, 5, 10 }) do
        local b = UI.Bouton(d.bloc, (pas > 0 and "+" or "") .. pas, 46, 24, function()
            f:Gagner(pas)
        end)
        d.boutons[i] = b
    end

    function f:Choisir(id)
        self.metierId = id
        self:Afficher()
    end

    function f:Gagner(montant)
        if not (LCM.IsMaster() and self.entity and self.metierId) then return end
        local avant = Metiers.Palier(self.entity, self.metierId)
        Metiers.Gagner(self.entity, self.metierId, montant)
        local apres = Metiers.Palier(self.entity, self.metierId)
        -- Le template felicite au passage de palier ; ici, au chat.
        if apres.rang > avant.rang then
            LCM.Ok(string.format("Félicitations ! Le métier de %s passe : %s.",
                Metiers.Get(self.metierId).label, apres.libelle))
        end
        self:Afficher()
    end

    function f:Afficher()
        local e = self.entity
        for _, b in ipairs(self.lignes) do
            local p = Metiers.Palier(e, b.metierId)
            b.palier:SetText(p.libelle)
            local appris = p.rang > 0
            Couleur(b.palier, appris and p.couleur or UI.C.discret)
            b.icone:SetDesaturated(not appris)
            b.icone:SetAlpha(appris and 1 or 0.42)
            local choisi = b.metierId == self.metierId
            if not appris then b.label:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
            elseif choisi then b.label:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            else b.label:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3]) end
        end
        local metier = Metiers.Get(self.metierId)
        if not metier then return end
        local p = Metiers.Palier(e, metier.id)
        d.icone:SetTexture(metier.icone)
        d.label:SetText(metier.label)
        d.palier:SetText("Palier : " .. p.libelle)
        Couleur(d.palier, p.couleur)
        d.description:SetText(metier.description)
        local yb = d.bloc.hautTitre + 12 + 64 + (d.description:GetStringHeight() or 14) + 16
        d.barre:ClearAllPoints()
        d.barre:SetPoint("TOPLEFT", d.bloc, "TOPLEFT", 16, -yb)
        if p.max then
            d.barre:Regler(1, 1)
            d.barre.label:SetText("Maîtrise complète")
            d.xp:SetText(string.format("%d XP au total", Metiers.XP(e, metier.id)))
        else
            d.barre:Regler(p.xpDansPalier, p.xpPalier)
            d.xp:SetText(string.format("%d XP avant le niveau suivant", p.xpRestante))
        end
        d.xp:ClearAllPoints()
        d.xp:SetPoint("TOPLEFT", d.barre, "BOTTOMLEFT", 0, -6)
        d.bonus:SetText(string.format("Bonus de jet : +%d", Metiers.Bonus(e, metier.id)))
        d.bonus:ClearAllPoints()
        d.bonus:SetPoint("TOPLEFT", d.xp, "BOTTOMLEFT", 0, -8)
        local mj = LCM.IsMaster()
        for i, b in ipairs(d.boutons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", d.bloc, "TOPLEFT", 16 + (i - 1) * 52, -(yb + 70))
            b:SetShown(mj)
        end
        d.bloc:SetHeight(yb + 70 + (mj and 36 or 0))
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self:SousTitre(self.entity.name or self.entity.id)
        self.metierId = self.metierId or (Metiers.list[1] and Metiers.list[1].id)
        self:Afficher()
        self:Show()
    end
    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
    f.suitSoi = true
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    UI.Menu.Lier("metiers", Ecran.Basculer)
end)
