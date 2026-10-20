-- Les grimoires : un hub, et la fenetre d'un grimoire.
--
-- Organisation du template (fenetre `grimoire_hub`, et chaque grimoire qui
-- declare son `hubWindowId`) : l'icone du menu ouvre le HUB, qui montre les
-- grimoires qu'on POSSEDE — le sien, et ceux qu'on nous a donnes. Ouvrir l'un
-- d'eux montre ses SOUS-GRIMOIRES, et dans chacun la liste de ses sorts.
--
-- Le hub donne un apercu de quelques sorts par grimoire (le `hubSpellCount` du
-- template) : on choisit lequel ouvrir sans avoir a les ouvrir tous.
--
-- Le jet d'un sort ne passe PAS par un champ de la fiche : sa plage lui
-- appartient, d'ou Roll.Des.

local _, LCM = ...
local UI = LCM.UI
local Grimoires = LCM.Grimoires

local Hub = {}
local Livre = {}
UI.Grimoires = Hub
UI.Grimoire = Livre

local HUB_L, HUB_H = 430, 520
local LIVRE_L, LIVRE_H = 700, 460
local ICONE = 36
local CARTE = 60

-- ===== Le hub ==============================================================

local function Tuile(parent)
    local t = CreateFrame("Button", nil, parent)
    if UI.SurfaceLigne then UI.SurfaceLigne(t) end
    t.survol = UI.Aplat(t, UI.C.survol, "HIGHLIGHT")
    t.survol:SetAllPoints(t)

    t.icone = t:CreateTexture(nil, "ARTWORK")
    t.icone:SetSize(ICONE, ICONE)
    t.icone:SetPoint("TOPLEFT", t, "TOPLEFT", 6, -6)
    t.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    t.nom = UI.Texte(t, "", UI.C.titre)
    UI.Police(t.nom, 13)
    t.nom:SetPoint("TOPLEFT", t.icone, "TOPRIGHT", 8, -1)

    t.compte = UI.Texte(t, "", UI.C.discret)
    UI.Police(t.compte, 10)
    t.compte:SetPoint("TOPRIGHT", t, "TOPRIGHT", -8, -8)

    t.description = UI.Texte(t, "", UI.C.texte)
    UI.Police(t.description, 10)
    t.description:SetPoint("TOPLEFT", t.nom, "BOTTOMLEFT", 0, -3)
    t.description:SetJustifyH("LEFT")
    t.description:SetWordWrap(true)

    t.apercu = UI.Texte(t, "", UI.C.discret)
    UI.Police(t.apercu, 10)
    t.apercu:SetJustifyH("LEFT")

    -- Reprendre un grimoire donne : au MJ seul, et jamais sur le sien.
    t.reprendre = UI.Bouton(t, "x", 16, 16, function()
        local grimoire = t.grimoire
        if not (grimoire and t.entity) then return end
        Grimoires.Retirer(t.entity, grimoire.id)
        LCM.Ok(string.format("%s n'a plus « %s ».", tostring(t.entity.name), tostring(grimoire.label)))
        Hub.Fenetre():Afficher()
    end)
    t.reprendre:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -6, 6)

    function t:Habiller(grimoire, entity, largeur)
        self.grimoire, self.entity = grimoire, entity
        -- Le nom, la description et l'icone peuvent avoir ete changes par le
        -- joueur : on affiche SA version, pas celle du compendium.
        local vu = Grimoires.Affichage(grimoire, entity) or grimoire
        self.icone:SetTexture(vu.icone or "Interface\\ICONS\\INV_Misc_Book_09")
        self.nom:SetText(vu.label)

        local sorts = Grimoires.CompteSorts(grimoire, entity)
        local sous = #Grimoires.SousGrimoires(grimoire)
        self.compte:SetText(string.format("%d sort%s · %d", sorts, sorts > 1 and "s" or "", sous))

        local largeurTexte = largeur - ICONE - 24
        self.description:SetWidth(math.max(80, largeurTexte))
        self.description:SetText(tostring(vu.description or ""))
        local y = 8 + math.max(ICONE, 16 + self.description:GetStringHeight())

        local noms = {}
        for _, sort in ipairs(Grimoires.Apercu(grimoire, nil, entity)) do
            noms[#noms + 1] = tostring(sort.label or sort.id or "")
        end
        self.apercu:SetWidth(math.max(80, largeurTexte))
        self.apercu:SetText(#noms > 0 and (table.concat(noms, "  ·  ")
            .. (sorts > #noms and "  …" or "")) or "")
        self.apercu:ClearAllPoints()
        self.apercu:SetPoint("TOPLEFT", self, "TOPLEFT", ICONE + 14, -y)
        if #noms > 0 then y = y + 14 end

        self.reprendre:SetShown(LCM.IsMaster() and not grimoire.personnel)
        self.hauteur = math.max(CARTE, y + 8)
        self:SetHeight(self.hauteur)
        self:Show()
        return self.hauteur
    end

    return t
end

local function ConstruireHub()
    local f = UI.Fenetre("grimoires", "Grimoires", HUB_L, HUB_H, { x = -40, y = 0 })
    Hub.frame = f
    f.nom = f.sousTitre

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 28)
    f.tuiles = {}

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    -- ----- donner un grimoire (MJ) ----------------------------------------
    f.donner = UI.Bouton(f.contenu, "Donner un grimoire", 150, 22, function()
        f.choix:SetShown(not f.choix:IsShown())
        if f.choix:IsShown() then f:RemplirChoix() end
    end)
    f.donner:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    f.choix = CreateFrame("Frame", nil, f)
    f.choix:SetPoint("BOTTOMLEFT", f.donner, "TOPLEFT", 0, 4)
    f.choix:SetSize(HUB_L - 40, 10)
    f.choix.fond = UI.Aplat(f.choix, UI.C.fond)
    f.choix.fond:SetAllPoints(f.choix)
    UI.Bordure(f.choix)
    f.choix:SetFrameLevel(f:GetFrameLevel() + 8)
    f.choix.boutons = {}
    f.choix:Hide()

    function f:RemplirChoix()
        local disponibles = {}
        for _, grimoire in ipairs(Grimoires.list) do
            if not Grimoires.Has(self.entity, grimoire.id) then disponibles[#disponibles + 1] = grimoire end
        end
        for index, grimoire in ipairs(disponibles) do
            local b = self.choix.boutons[index]
            if not b then
                b = UI.Bouton(self.choix, "", HUB_L - 52, 20, function()
                    local cible = self.choix.boutons[index].grimoireId
                    local ok, raison = Grimoires.Donner(self.entity, cible)
                    if not ok then LCM.Alerte(tostring(raison)) return end
                    LCM.Ok(string.format("%s recoit « %s ».",
                        tostring(self.entity.name), tostring(Grimoires.Get(cible).label)))
                    self.choix:Hide()
                    self:Afficher()
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetJustifyH("LEFT")
                self.choix.boutons[index] = b
            end
            b.grimoireId = grimoire.id
            b.label:SetText(grimoire.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.choix, "TOPLEFT", 6, -6 - (index - 1) * 22)
            b:Show()
        end
        for index = #disponibles + 1, #self.choix.boutons do self.choix.boutons[index]:Hide() end
        self.choix:SetHeight(math.max(22, #disponibles * 22 + 12))
        if #disponibles == 0 then
            LCM.Alerte("il les possede tous.")
            self.choix:Hide()
        end
    end

    function f:Afficher()
        local entity = self.entity
        local possedes = Grimoires.Possedes(entity)
        local largeur = HUB_L - 24
        local y, nombre = 0, 0
        for rang, grimoire in ipairs(possedes) do
            local t = self.tuiles[rang]
            if not t then
                t = Tuile(self.zone.contenu)
                t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                t:SetScript("OnClick", function(tuile, bouton)
                    if not tuile.grimoire then return end
                    -- Clic droit : renommer le sien. Un grimoire RECU reste ce
                    -- que le maitre du jeu a ecrit.
                    if bouton == "RightButton" then
                        if tuile.grimoire.personnel then
                            UI.GrimoireEditeur.Ouvrir(self.entity, tuile.grimoire)
                        else
                            LCM.Alerte("ce grimoire ne t'appartient pas : il garde son nom.")
                        end
                        return
                    end
                    Livre.Ouvrir(tuile.grimoire.id, self.entity)
                end)
                self.tuiles[rang] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            t:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            y = y + t:Habiller(grimoire, entity, largeur) + 4
            nombre = rang
        end
        for rang = nombre + 1, #self.tuiles do self.tuiles[rang]:Hide() end

        self.zone:Regler(y)
        self.nombreAffiche = nombre
        self.vide:SetText(nombre > 0 and "" or "Aucun grimoire.")
        self.donner:SetShown(LCM.IsMaster())
        if not LCM.IsMaster() then self.choix:Hide() end
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self:SousTitre(self.entity.name or self.entity.id)
        self.choix:Hide()
        self:Afficher()
        self:Show()
    end

    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
    f.suitSoi = true
    return f
end

function Hub.Fenetre()
    if not Hub.frame then ConstruireHub() end
    return Hub.frame
end

function Hub.Basculer()
    local f = Hub.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

-- ===== La fenetre d'un grimoire ===========================================

local function Carte(parent)
    local c = CreateFrame("Frame", nil, parent)
    if UI.SurfaceLigne then UI.SurfaceLigne(c) end

    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetSize(40, 40)
    c.icone:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    c.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    c.nom = UI.Texte(c, "", UI.C.titre)
    UI.Police(c.nom, 13)
    c.nom:SetPoint("TOPLEFT", c.icone, "TOPRIGHT", 8, -2)

    c.description = UI.Texte(c, "", UI.C.texte)
    UI.Police(c.description, 11)
    c.description:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -4)
    c.description:SetJustifyH("LEFT")
    c.description:SetWordWrap(true)

    c.champs = UI.Texte(c, "", UI.C.discret)
    UI.Police(c.champs, 11)
    c.champs:SetJustifyH("LEFT")

    c.raccourci = UI.Texte(c, "", UI.C.discret)
    UI.Police(c.raccourci, 10)
    c.raccourci:SetJustifyH("LEFT")

    -- Pas de bouton sur un sort qui ne fait rien : ni jet, ni action.
    c.jet = UI.Bouton(c, "Lancer", 60, 20, function()
        local sort = c.sort
        if not sort then return end
        local ok, raison = LCM.Sorts.Lancer(c.entity, sort)
        if not ok and raison then LCM.Alerte(tostring(raison)) end
    end)
    c.jet:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -6)

    -- Actions d'un sort PERSONNEL : le citer, le donner, le corriger, l'oublier.
    -- Elles n'apparaissent que sur son propre grimoire — un sort du catalogue
    -- ne s'edite pas depuis ici.
    c.lier = UI.Bouton(c, "Lier", 46, 18, function()
        if c.sort and c.entity then LCM.Lien.Inserer(LCM.Lien.Sort(c.entity, c.sort)) end
    end)
    c.partager = UI.Bouton(c, "Partager", 66, 18, function()
        if c.sort and c.entity and Livre.frame then Livre.frame:DemanderCible(c.sort) end
    end)
    c.modifier = UI.Bouton(c, "Modifier", 66, 18, function()
        if c.sort and c.entity then UI.SortEditeur.Ouvrir(c.entity, c.sort) end
    end)
    c.oublier = UI.Bouton(c, "x", 18, 18, function()
        if not (c.sort and c.entity and Livre.frame) then return end
        local sort, entity = c.sort, c.entity
        Livre.frame.confirmation:Demander(
            string.format("Oublier %s ?", tostring(sort.label)),
            function()
                LCM.Sorts.Supprimer(entity, sort.id)
                Livre.frame:Afficher(Livre.frame.sousRang)
            end)
    end)

    -- La carte se mesure : la description est de longueur libre, et la zone qui
    -- defile a besoin d'une hauteur juste.
    function c:Habiller(sort, largeur, entity, personnel)
        self.sort, self.entity = sort, entity
        local icone = tostring(sort.icone or "")
        self.icone:SetTexture(icone ~= "" and icone or "Interface\\ICONS\\INV_Misc_QuestionMark")
        self.nom:SetText(tostring(sort.label or sort.id or ""))

        local largeurTexte = largeur - 40 - 28
            - ((sort.competence or sort.jet or sort.action) and 66 or 0)
        self.description:SetWidth(math.max(80, largeurTexte))
        self.description:SetText(tostring(sort.description or ""))
        local y = 6 + math.max(40, 18 + self.description:GetStringHeight() + 4)

        local morceaux = {}
        for _, cle in ipairs({ "champ1", "champ2" }) do
            local v = tostring(sort[cle] or "")
            if v ~= "" then morceaux[#morceaux + 1] = v end
        end
        self.champs:SetText(table.concat(morceaux, "   ·   "))
        self.champs:ClearAllPoints()
        self.champs:SetPoint("TOPLEFT", self, "TOPLEFT", 54, -y)
        if #morceaux > 0 then y = y + 14 end

        local raccourci = tostring(sort.raccourci or "")
        self.raccourci:SetText(raccourci ~= "" and ("raccourci : " .. raccourci) or "")
        self.raccourci:ClearAllPoints()
        self.raccourci:SetPoint("TOPLEFT", self, "TOPLEFT", 54, -y)
        if raccourci ~= "" then y = y + 13 end

        -- Le bouton apparait des que le sort fait QUELQUE CHOSE : un jet (par
        -- sa competence ou son ancienne plage) ou une action.
        self.jet:SetShown((sort.competence or sort.jet or sort.action) ~= nil)
        self.jet.label:SetText(sort.action and not (sort.competence or sort.jet) and "Action" or "Lancer")

        -- Les actions se posent en bas a droite, de la droite vers la gauche.
        local actions = {}
        if personnel then
            actions = { self.lier, self.partager, self.modifier, self.oublier }
        end
        for _, bouton in ipairs({ self.lier, self.partager, self.modifier, self.oublier }) do
            bouton:Hide()
        end
        local x = -6
        for _, bouton in ipairs(actions) do
            bouton:ClearAllPoints()
            bouton:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", x, 6)
            bouton:Show()
            x = x - bouton:GetWidth() - 4
        end
        if personnel then y = math.max(y, 24) end

        self.hauteur = math.max(CARTE, y + (personnel and 24 or 6))
        self:SetHeight(self.hauteur)
        self:Show()
        return self.hauteur
    end

    return c
end

local function ConstruireLivre()
    local f = UI.Fenetre("grimoire", "Grimoire", LIVRE_L, LIVRE_H, { x = 120, y = -30 })
    Livre.frame = f
    f.nom = f.sousTitre

    f.description = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.description, 11)
    f.description:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.description:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 0)
    f.description:SetJustifyH("LEFT")
    f.description:SetWordWrap(true)

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.cartes = {}

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    f.confirmation = UI.Confirmer(f, "", "Oublier")

    -- Sur son propre grimoire : ecrire un sort de plus.
    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau sort", 120, 22, function()
        UI.SortEditeur.Ouvrir(f.entity, nil)
    end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    -- A qui partager : on demande le nom, on ne devine pas.
    f.cible = UI.Champ(f.contenu, 160, 22)
    f.cible:SetPoint("BOTTOMLEFT", f.nouveau, "BOTTOMRIGHT", 8, 0)
    f.cibleAide = UI.Texte(f.contenu, "nom du destinataire", UI.C.discret)
    UI.Police(f.cibleAide, 10)
    f.cibleAide:SetPoint("LEFT", f.cible, "RIGHT", 8, 0)
    f.envoyer = UI.Bouton(f.contenu, "Envoyer", 80, 22, function()
        local sort = f.sortAPartager
        if not sort then return end
        local ok, raison = LCM.Lien.Partager(f.entity, sort.id, f.cible:GetText())
        if not ok then LCM.Alerte(tostring(raison)) return end
        LCM.Ok(string.format("%s envoye a %s.", tostring(sort.label), f.cible:GetText()))
        f:CacherPartage()
    end)
    f.envoyer:SetPoint("LEFT", f.cibleAide, "RIGHT", 8, 0)

    function f:DemanderCible(sort)
        self.sortAPartager = sort
        self.cibleAide:SetText("destinataire de « " .. tostring(sort.label) .. " »")
        self.cible:SetShown(true)
        self.cibleAide:Show()
        self.envoyer:Show()
        if self.cible.SetFocus then self.cible:SetFocus() end
    end

    function f:CacherPartage()
        self.sortAPartager = nil
        self.cible:SetText("")
        self.cible:Hide()
        self.cibleAide:Hide()
        self.envoyer:Hide()
    end

    -- La bande des sous-grimoires se refait a chaque grimoire : deux grimoires
    -- n'ont ni le meme nombre ni les memes noms.
    function f:Bande()
        if self.barre then self.barre:Hide() self.barre = nil end
        local sous = Grimoires.SousGrimoires(self.grimoire)
        local haut = 0
        if #sous > 1 then
            local onglets = {}
            for index, s in ipairs(sous) do
                onglets[#onglets + 1] = { id = tostring(index), label = s.nom }
            end
            self.barre = UI.BandeauOnglets(self.contenu, onglets, function(id) self:Afficher(tonumber(id)) end)
            self.barre:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, -self.hautDescription)
            self.barre:SetWidth(LIVRE_L - 24)
            haut = self.barre:Disposer(LIVRE_L - 24, self.mesures.onglet) + 8
        end
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, -(self.hautDescription + haut))
        self.zone:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", 0, 0)
    end

    function f:Afficher(rang)
        self.sousRang = rang or 1
        if self.barre then self.barre:Selectionner(tostring(self.sousRang)) end

        local largeur = LIVRE_L - 24
        local y, nombre = 0, 0
        for index, sort in ipairs(Grimoires.Sorts(self.grimoire, self.sousRang, self.entity)) do
            local c = self.cartes[index]
            if not c then
                c = Carte(self.zone.contenu)
                self.cartes[index] = c
            end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            y = y + c:Habiller(sort, largeur, self.entity, self.grimoire.personnel) + 4
            nombre = index
        end
        for index = nombre + 1, #self.cartes do self.cartes[index]:Hide() end

        self.zone.decalage = 0
        self.zone:Regler(y)
        self.nombreAffiche = nombre
        local sien = self.grimoire and self.grimoire.personnel
        self.vide:SetText(nombre > 0 and "" or
            (sien and "Aucun sort. Le bouton « + Nouveau sort » en ecrit un."
                  or "Ce sous-grimoire est vide."))
        self.nouveau:SetShown(sien and true or false)
    end

    function f:Montrer(grimoireId, entity)
        local grimoire = Grimoires.Get(grimoireId)
        if not grimoire then
            LCM.Alerte("ce grimoire n'existe pas.")
            return
        end
        self.grimoire, self.entity = grimoire, entity
        self:Titre(grimoire.label)
        self:SousTitre(entity and (entity.name or entity.id) or "")

        local texte = tostring(grimoire.description or "")
        self.description:SetText(texte)
        self.hautDescription = texte ~= "" and (self.description:GetStringHeight() + 10) or 0
        self:Bande()
        self:CacherPartage()
        self:Afficher(1)
        self:Show()
    end

    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) if self.grimoire then self:Afficher(self.sousRang) end end)
    return f
end

function Livre.Fenetre()
    if not Livre.frame then ConstruireLivre() end
    return Livre.frame
end

function Livre.Ouvrir(grimoireId, entity)
    local f = Livre.Fenetre()
    f:Montrer(grimoireId, entity)
    return f
end

LCM.AddCommand("grimoires", "ouvre tes grimoires", function() Hub.Basculer() end)

LCM.WhenReady(function()
    UI.Menu.Lier("grimoires", Hub.Basculer)
end)
