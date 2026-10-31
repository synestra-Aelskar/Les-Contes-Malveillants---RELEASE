-- Selection du personnage.
--
-- Une liste a gauche, un carrousel de cartes a droite : la carte du milieu est
-- grande et nette, ses voisines sont plus petites et en retrait. C'est la seule
-- fenetre de l'addon qui montre des artworks, donc la seule qui a le droit
-- d'etre large.
--
-- Ouverte par Maj + clic gauche sur le sceau.

local _, LCM = ...
local UI = LCM.UI
local Personnages = LCM.Personnages
local Portraits = LCM.Portraits

local Ecran = {}
UI.Personnages = Ecran

local LARGEUR_LISTE = 210
local CARTE = { largeur = 208, hauteur = 318 }
local VOISINE = { largeur = 128, hauteur = 204 }
local ECART = 184      -- 496 unites au total, dans une scene de 566
local PIED = 32        -- hauteur du bandeau du nom

-- ===== Une carte ===========================================================

local function Carte(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(CARTE.largeur, CARTE.hauteur)

    c.fond = UI.Aplat(c, UI.C.fond)
    c.fond:SetAllPoints(c)
    c.traits = UI.Bordure(c)

    -- L'artwork occupe toute la carte sauf le bandeau du nom.
    c.art = c:CreateTexture(nil, "ARTWORK")
    c.art:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
    c.art:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, PIED)

    c.bandeau = UI.Aplat(c, { 0.04, 0.03, 0.03, 0.96 }, "OVERLAY")
    c.bandeau:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 2, 2)
    c.bandeau:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", -2, PIED)

    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormal")
    c.nom:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 6, 8)
    c.nom:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -24, 8)
    c.nom:SetJustifyH("CENTER")
    c.nom:SetHeight(16)
    c.nom:SetWordWrap(false)

    -- Changer d'artwork apres coup : on choisit son portrait a la creation, et
    -- on n'avait plus aucun moyen d'en changer. Le crayon est a cote du nom,
    -- sur la carte de celui qu'on regarde.
    c.portraitMenu = UI.Choix("portrait_carte", "Artwork")
    c.editerArtwork = UI.Bouton(c, "A", 18, 16, function(self)
        local entity = self:GetParent().entity
        if not entity then return end
        local options = { { id = "", label = "Aucun" } }
        for _, portrait in ipairs(LCM.Portraits.list) do
            options[#options + 1] = { id = portrait.id, label = portrait.label }
        end
        if #options == 1 then
            LCM.Alerte("aucun artwork n'est livré pour l'instant.")
            return
        end
        self:GetParent().portraitMenu:Proposer(self, options, function(choix)
            LCM.Entities.Set_Value(entity, "portrait", choix ~= "" and choix or nil)
            if Ecran.frame then Ecran.frame:Afficher() end
        end)
    end)
    c.editerArtwork:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -5, 7)
    UI.Bulle(c.editerArtwork, "Artwork", "Clic : choisir l'image de ce personnage.")

    -- Le niveau, en haut a gauche, dans son propre cadre.
    c.niveau = CreateFrame("Frame", nil, c)
    c.niveau:SetSize(52, 24)
    c.niveau:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    c.niveau.fond = UI.Aplat(c.niveau, { 0.04, 0.03, 0.03, 0.92 })
    c.niveau.fond:SetAllPoints(c.niveau)
    UI.Bordure(c.niveau)
    c.niveau.label = UI.Texte(c.niveau, "", UI.C.accent, "GameFontNormalSmall")
    c.niveau.label:SetAllPoints(c.niveau)
    c.niveau.label:SetJustifyH("CENTER")
    c.niveau.label:SetJustifyV("MIDDLE")

    c.statutFond = UI.Aplat(c, { 0.04, 0.03, 0.03, 0.92 }, "ARTWORK")
    c.statutFond:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -6)
    c.statutFond:SetSize(62, 24)
    c.marque = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.marque:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -12)
    c.marque:SetJustifyH("RIGHT")
    c.marque:SetShadowColor(0, 0, 0, 1)
    c.marque:SetShadowOffset(1, -1)

    c.survol = UI.Aplat(c, UI.C.survol, "HIGHLIGHT")
    c.survol:SetAllPoints(c)

    function c:Habiller(entity, centrale)
        self.entity = entity
        self:SetSize(centrale and CARTE.largeur or VOISINE.largeur,
                     centrale and CARTE.hauteur or VOISINE.hauteur)
        self:SetAlpha(centrale and 1 or 0.72)
        -- Le bouton d'artwork n'est que sur la carte du milieu : sur les
        -- voisines, reduites et a demi transparentes, il serait illisible et on
        -- cliquerait a cote.
        self.editerArtwork:SetShown(centrale and entity ~= nil)
        if not entity then self:Hide() return end

        local mode = Portraits.Appliquer(self.art, entity)
        -- Une icone ne doit pas s'etirer sur toute la carte ; un artwork ou une
        -- silhouette, si.
        self.art:ClearAllPoints()
        if mode ~= "icone" then
            self.art:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -2)
            self.art:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, PIED)
        else
            self.art:SetPoint("CENTER", self, "CENTER", 0, PIED / 2)
            self.art:SetSize(72, 72)
        end

        self.nom:SetText(tostring(entity.name))
        self.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        self.niveau.label:SetText("Niv. " .. tostring(LCM.Entities.Get_Value(entity, "niveau") or "?"))
        self.niveau:SetShown(centrale or false)
        self.marque:SetText(centrale and entity.id == Personnages.ActifId() and "EN JEU" or "")
        self.statutFond:SetShown(centrale and entity.id == Personnages.ActifId())
        self:Show()
    end

    return c
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("personnages", "Sélection du personnage", 820, 520)
    Ecran.frame = f
    f.index = 1

    -- ----- la liste -------------------------------------------------------
    f.liste = CreateFrame("Frame", nil, f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(LARGEUR_LISTE)
    f.liste.fond = UI.Aplat(f.liste, UI.C.fondClair)
    f.liste.fond:SetAllPoints(f.liste)
    UI.Bordure(f.liste)
    f.liste.boutons = {}

    f.liste.titre = UI.Texte(f.liste, "Vos personnages", UI.C.titre, "GameFontNormal")
    f.liste.titre:SetPoint("TOPLEFT", f.liste, "TOPLEFT", 14, -16)
    f.liste.compteur = UI.Texte(f.liste, "", UI.C.discret, "GameFontNormalSmall")
    f.liste.compteur:SetPoint("TOPLEFT", f.liste.titre, "BOTTOMLEFT", 0, -7)
    f.liste.defilement = UI.Defilement(f.liste)
    f.liste.defilement:SetPoint("TOPLEFT", f.liste, "TOPLEFT", 12, -58)
    f.liste.defilement:SetPoint("BOTTOMRIGHT", f.liste, "BOTTOMRIGHT", -16, 58)

    f.creer = UI.Bouton(f.liste, "+  Créer un personnage", LARGEUR_LISTE - 24, 30, function()
        Ecran.Creer()
    end)
    f.creer:SetPoint("BOTTOMLEFT", f.liste, "BOTTOMLEFT", 12, 12)

    -- ----- la scene -------------------------------------------------------
    f.scene = CreateFrame("Frame", nil, f.contenu)
    f.scene:SetPoint("TOPLEFT", f.liste, "TOPRIGHT", 20, 0)
    f.scene:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.vide = UI.Texte(f.scene, "", UI.C.discret, "GameFontNormal")
    f.vide:SetPoint("CENTER", f.scene, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")
    f.vide:SetWidth(340)

    f.galerie = CreateFrame("Frame", nil, f.scene)
    f.galerie:SetPoint("TOPLEFT", f.scene, "TOPLEFT", 0, -38)
    f.galerie:SetPoint("BOTTOMRIGHT", f.scene, "BOTTOMRIGHT", 0, 58)
    f.galerie:SetClipsChildren(true)
    f.position = UI.Texte(f.scene, "", UI.C.discret, "GameFontNormalSmall")
    f.position:SetPoint("TOP", f.scene, "TOP", 0, -13)
    f.precedent = UI.Bouton(f.scene, "<", 30, 26, function() f:Decaler(-1) end)
    f.precedent:SetPoint("TOPLEFT", f.scene, "TOPLEFT", 8, -4)
    f.suivant = UI.Bouton(f.scene, ">", 30, 26, function() f:Decaler(1) end)
    f.suivant:SetPoint("TOPRIGHT", f.scene, "TOPRIGHT", -8, -4)

    -- Deux cartes de reserve permettent l'entree et la sortie du slider.
    f.cartes = {}
    for place = -2, 2 do
        local c = Carte(f.galerie)
        c.place = place
        c:SetPoint("CENTER", f.galerie, "CENTER", place * ECART, 0)
        c:SetScript("OnClick", function(bouton)
            if bouton.place == 0 then
                if bouton.entity then f:Jouer(bouton.entity) end
            else
                f:Decaler(bouton.place)
            end
        end)
        f.cartes[place] = c
    end
    -- La carte du milieu passe devant ses voisines.
    f.cartes[0]:SetFrameLevel(f.galerie:GetFrameLevel() + 4)

    f.jouer = UI.Bouton(f.scene, "Jouer ce personnage", 196, 32, function()
        local entity = f:Courant()
        if entity then f:Jouer(entity) end
    end)
    f.jouer:SetPoint("BOTTOM", f.scene, "BOTTOM", 0, 12)
    f.jouer:Selectionner(true)

    -- Le bouton n'existe visuellement que lorsque la fiche choisie peut être
    -- rouverte : toujours pour le MJ, ou le temps d'un jeton pour un joueur.
    f.editer = UI.Bouton(f.scene, "Rééditer", 100, 32, function()
        local entity = f:Courant()
        if not entity then return end
        local ouverte = f:IsShown()
        if ouverte then f:Hide() end
        local creation, raison = UI.Creation.Editer(entity)
        if not creation then
            LCM.Alerte(tostring(raison))
            if ouverte then f:Montrer() end
            return
        end
        creation.retourSelection = ouverte or nil
    end)
    f.editer:SetPoint("RIGHT", f.jouer, "LEFT", -12, 0)

    -- Effacer un personnage ne se rattrape pas : on demande confirmation, et le
    -- nom est dans la question — pour ne pas supprimer le mauvais.
    f.confirmation = UI.Confirmer(f, "", "Supprimer")
    f.supprimer = UI.Bouton(f.scene, "Supprimer", 100, 32, function()
        local entity = f:Courant()
        if not entity then return end
        f.confirmation:Demander(
            string.format("Supprimer %s ?\nSa fiche et tout ce qu'elle contient sont perdus.",
                tostring(entity.name)),
            function()
                local nom = tostring(entity.name)
                Personnages.Supprimer(entity.id)
                LCM.Ok(string.format("%s a ete supprime.", nom))
                f:Rafraichir()
            end)
    end)
    f.supprimer:SetPoint("LEFT", f.jouer, "RIGHT", 12, 0)

    f.scene:EnableMouseWheel(true)
    f.scene:SetScript("OnMouseWheel", function(_, delta) f:Decaler(delta > 0 and -1 or 1) end)

    -- ----- comportement ---------------------------------------------------

    function f:Courant()
        return self.profils and self.profils[self.index] or nil
    end

    -- Les voisins suivent strictement la liste : aucune boucle aux extremites.
    function f:Voisin(pas)
        return self.profils and self.profils[self.index + pas] or nil
    end

    function f:Selectionner(index)
        local nombre = #(self.profils or {})
        if nombre == 0 then return end
        index = math.max(1, math.min(nombre, index))
        self.destination = index
        if self.glissement or index == self.index then return end
        local direction = index > self.index and 1 or -1
        self.index = self.index + direction
        self:Afficher()
        self.destination = index
        self.glissement = true
        self.jouer:Disable()
        self.editer:Disable()
        self.supprimer:Disable()
        local temps = 0
        local function Pas(_, ecoule)
            temps = temps + ecoule
            local t = math.min(1, temps / 0.26)
            local u = t * t * (3 - 2 * t)
            for place = -2, 2 do
                local c = self.cartes[place]
                local depart = place + direction
                local existe = c.entity and (math.abs(place) <= 1 or math.abs(depart) <= 1)
                c:SetShown(existe and true or false)
                if existe then
                    local central = (depart == 0 and (1 - u) or 0) + (place == 0 and u or 0)
                    c:SetSize(VOISINE.largeur + (CARTE.largeur - VOISINE.largeur) * central,
                        VOISINE.hauteur + (CARTE.hauteur - VOISINE.hauteur) * central)
                    local alphaDepart = math.abs(depart) > 1 and 0 or (depart == 0 and 1 or 0.72)
                    local alphaFin = math.abs(place) > 1 and 0 or (place == 0 and 1 or 0.72)
                    c:SetAlpha(alphaDepart + (alphaFin - alphaDepart) * u)
                    c:ClearAllPoints()
                    c:SetPoint("CENTER", self.galerie, "CENTER", (depart - direction * u) * ECART, 0)
                    c:EnableMouse(false)
                end
            end
            if t == 1 then
                local destination = self.destination
                self:Afficher()
                if destination and destination ~= self.index then self:Selectionner(destination) end
            end
        end
        self.galerie:SetScript("OnUpdate", Pas)
        Pas(nil, 0)
    end

    function f:Decaler(pas)
        local nombre = #(self.profils or {})
        if nombre < 2 then return end
        self:Selectionner((self.destination or self.index) + pas)
    end

    function f:Jouer(entity)
        Personnages.Choisir(entity.id)
        LCM.Ok(string.format("tu joues %s.", tostring(entity.name)))
        self:Afficher()
    end

    function f:Afficher()
        self.galerie:SetScript("OnUpdate", nil)
        self.glissement, self.destination = nil, nil
        self.jouer:Enable()
        self.editer:Enable()
        self.supprimer:Enable()
        local nombre = #(self.profils or {})
        self.liste.compteur:SetText(string.format("%d personnage%s", nombre, nombre == 1 and "" or "s"))
        self.position:SetText(nombre > 0 and string.format("Personnage %d / %d", self.index, nombre) or "")
        self.precedent:SetShown(nombre > 1)
        self.suivant:SetShown(nombre > 1)
        self.precedent:SetEnabled(self.index > 1)
        self.suivant:SetEnabled(self.index < nombre)
        self.precedent:SetAlpha(self.index > 1 and 1 or 0.3)
        self.suivant:SetAlpha(self.index < nombre and 1 or 0.3)
        for place = -2, 2 do
            local c = self.cartes[place]
            c:Habiller(self:Voisin(place), place == 0)
            c:ClearAllPoints()
            c:SetPoint("CENTER", self.galerie, "CENTER", place * ECART, 0)
            c:EnableMouse(true)
            if math.abs(place) > 1 then c:Hide() end
        end
        self.jouer:SetShown(nombre > 0)
        local courant = self:Courant()
        local peutEditer = courant and LCM.Creation and LCM.Creation.PeutEditer(courant)
        self.editer:SetShown(peutEditer and true or false)
        self.supprimer:SetShown(nombre > 0)
        self.vide:SetText(nombre > 0 and "" or
            "Aucun personnage.\nLe bouton « Créer un personnage » ouvre la création.")

        for index, profil in ipairs(self.profils or {}) do
            local b = self.liste.boutons[index]
            if not b then
                b = UI.Bouton(self.liste.defilement.contenu, "", LARGEUR_LISTE - 28, 44, function()
                    self:Selectionner(index)
                end)
                b:SetPoint("TOPLEFT", self.liste.defilement.contenu, "TOPLEFT", 0, -(index - 1) * 50)
                b.label:SetJustifyH("LEFT")
                b.label:ClearAllPoints()
                b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
                b.label:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -8)
                b.label:SetHeight(14)
                b.label:SetWordWrap(false)
                b.detail = UI.Texte(b, "", UI.C.discret, "GameFontNormalSmall")
                b.detail:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 8)
                b.selection = UI.Aplat(b, UI.C.accent, "OVERLAY")
                b.selection:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -3)
                b.selection:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 3)
                b.selection:SetWidth(2)
                self.liste.boutons[index] = b
            end
            b.label:SetText(tostring(profil.name))
            b.detail:SetText(string.format("Niveau %s%s",
                tostring(LCM.Entities.Get_Value(profil, "niveau") or "?"),
                profil.id == Personnages.ActifId() and "  ·  En jeu" or ""))
            b:Selectionner(index == self.index)
            b.selection:SetShown(index == self.index)
            b:Show()
        end
        for index = nombre + 1, #self.liste.boutons do self.liste.boutons[index]:Hide() end
        self.liste.defilement:Regler(math.max(1, nombre * 50 - 6))
        local zone = self.liste.defilement
        local haut = (self.index - 1) * 50
        if haut < zone.decalage then zone:Aller(haut)
        elseif haut + 44 > zone.decalage + zone:GetHeight() then
            zone:Aller(haut + 44 - zone:GetHeight())
        end
    end

    function f:Rafraichir()
        self.profils = Personnages.Liste()
        self.index = math.max(1, math.min(self.index, math.max(1, #self.profils)))
        self:Afficher()
    end

    -- Ouvre sur le personnage joue plutot que sur le premier de la liste.
    function f:Montrer()
        self.profils = Personnages.Liste()
        local actif = Personnages.ActifId()
        self.index = 1
        for index, entity in ipairs(self.profils) do
            if entity.id == actif then self.index = index end
        end
        self:Afficher()
        self:Show()
    end

    f:HookScript("OnHide", function(self)
        self.galerie:SetScript("OnUpdate", nil)
        self.glissement, self.destination = nil, nil
    end)

    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) self:Rafraichir() end)
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Ouvrir()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() return f end
    f:Montrer()
    return f
end

-- La creation prend toute la place : les deux fenetres cote a cote se
-- recouvrent et on ne sait plus laquelle on manipule. On efface donc la
-- selection, et elle revient quand la creation se ferme.
function Ecran.Creer()
    if not (UI.Creation and UI.Creation.Ouvrir) then
        LCM.Alerte("la creation de personnage n'est pas encore disponible.")
        return
    end
    local ouverte = Ecran.frame and Ecran.frame:IsShown()
    if ouverte then Ecran.frame:Hide() end
    local creation = UI.Creation.Ouvrir()
    creation.retourSelection = ouverte or nil
end

LCM.AddCommand("personnages", "choisir son personnage", function() Ecran.Ouvrir() end)
