-- Ecrire un sort de son grimoire.
--
-- Un sort est fait pour etre cite dans une conversation, pas pour etre une
-- fiche de plus : nom, icone, description, et ce qu'il declenche. Les bornes
-- de longueur viennent de Core/Sorts.lua, et c'est lui qui accepte ou refuse —
-- l'ecran ne fait que porter le refus a l'ecran.
--
-- Refait le 5 octobre 2026 : fenetre plus large et moins haute, l'icone se
-- choisit au lieu de se taper, la description a une vraie boite, le jet designe
-- une COMPETENCE de la fiche au lieu d'une plage ecrite a la main, et un sort
-- peut declencher une action (combat, macro, Arcanum). « Champ 1 » et
-- « Champ 2 » sont partis : deux cases sans nom que personne ne savait remplir.

local _, LCM = ...
local UI = LCM.UI
local Sorts = LCM.Sorts

local Editeur = {}
UI.SortEditeur = Editeur

local LARGEUR, HAUTEUR = 560, 310
local ETIQUETTE = 92
local CHAMP = LARGEUR - 24 - ETIQUETTE - 8

local function Libelle(f, texte, y)
    local fs = UI.Texte(f.contenu, texte, UI.C.texte)
    UI.Police(fs, 11)
    fs:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    return fs
end

-- Les jets qu'une fiche sait faire : Adresse, Esprit, et les expertises. On lit
-- le SCHEMA, pas une liste tenue a cote : une expertise ajoutee (la
-- Communication, le 3 octobre) apparait ici sans qu'on y touche.
local function Competences()
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections or {}) do
            for _, field in ipairs(section.fields or {}) do
                if field.kind == "roll" and not field.masque then
                    out[#out + 1] = {
                        id = field.id, label = field.label,
                        groupe = (tab.label or tab.id)
                            .. ((section.label or "") ~= "" and (" — " .. section.label) or ""),
                    }
                end
            end
        end
    end
    return out
end
Editeur.Competences = Competences

local function Construire()
    local f = UI.Fenetre("sort_editeur", "Sort", LARGEUR, HAUTEUR, { x = 260, y = -60 })
    Editeur.frame = f

    local y = 4

    -- ----- l'icone se choisit, elle ne se tape pas -------------------------
    f.iconeBouton = CreateFrame("Button", nil, f.contenu)
    f.iconeBouton:SetSize(30, 30)
    f.iconeBouton:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    f.iconeBouton.texture = f.iconeBouton:CreateTexture(nil, "ARTWORK")
    f.iconeBouton.texture:SetAllPoints(f.iconeBouton)
    f.iconeBouton.texture:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    f.iconeBouton.survol = UI.Aplat(f.iconeBouton, UI.C.survol, "HIGHLIGHT")
    f.iconeBouton.survol:SetAllPoints(f.iconeBouton)
    if UI.AelCadre then
        local support = CreateFrame("Frame", nil, f.iconeBouton)
        support:SetPoint("TOPLEFT", f.iconeBouton, "TOPLEFT", -1, 1)
        support:SetPoint("BOTTOMRIGHT", f.iconeBouton, "BOTTOMRIGHT", 1, -1)
        UI.AelCadre(support, "icone")
    end
    f.iconeBouton:SetScript("OnClick", function(self)
        Editeur.selecteur = Editeur.selecteur or UI.SelecteurIcone("sort")
        Editeur.selecteur:Proposer(self, function(chemin)
            f.iconeChoisie = chemin
            f.iconeBouton.texture:SetTexture(chemin)
        end)
    end)
    UI.Bulle(f.iconeBouton, "Icône", "Clic : choisir l'icône du sort.")

    f.nom = UI.Champ(f.contenu, CHAMP + ETIQUETTE - 38, 22)
    f.nom:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 38, -y - 4)
    y = y + 38

    Libelle(f, "Description", y)
    -- Une VRAIE boite : sur une ligne de 22 px, on n'ecrivait rien.
    f.description = UI.Zone(f.contenu, CHAMP, 70)
    f.description:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE, -y + 3)
    y = y + 80

    -- ----- le jet : une competence de la fiche, ou rien --------------------
    Libelle(f, "Jet", y)
    f.avecJet = UI.Case(f.contenu, "", function(coche)
        f.jetActif = coche
        f:MajJet()
    end)
    f.avecJet:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE, -y + 1)
    f.competence = UI.Bouton(f.contenu, "— choisir —", 190, 22, function(self)
        local options = {}
        for _, c in ipairs(Competences()) do
            options[#options + 1] = { id = c.id, label = c.label, groupe = c.groupe }
        end
        Editeur.choixCompetence = Editeur.choixCompetence or UI.Choix("sort_competence", "Jet du sort")
        Editeur.choixCompetence:Proposer(self, options, function(id)
            f.competenceId = id
            f.jetActif = true
            f.avecJet:Cocher(true)
            f:MajJet()
        end)
    end)
    f.competence:SetPoint("LEFT", f.avecJet, "RIGHT", 10, 0)
    f.aideJet = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.aideJet, 10)
    f.aideJet:SetPoint("LEFT", f.competence, "RIGHT", 10, 0)
    y = y + 30

    -- ----- ce que le sort declenche ---------------------------------------
    Libelle(f, "Action", y)
    f.avecAction = UI.Case(f.contenu, "", function(coche)
        f.actionActive = coche
        f:MajAction()
    end)
    f.avecAction:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE, -y + 1)
    f.genreAction = UI.Bouton(f.contenu, "— type —", 130, 22, function(self)
        local options = {}
        for _, genre in ipairs(Sorts.ORDRE_ACTIONS) do
            options[#options + 1] = { id = genre, label = Sorts.ACTIONS[genre] }
        end
        Editeur.choixGenre = Editeur.choixGenre or UI.Choix("sort_action", "Action du sort")
        Editeur.choixGenre:Proposer(self, options, function(genre)
            f.actionGenre = genre
            f.actionActive = true
            f.avecAction:Cocher(true)
            f:MajAction()
        end)
    end)
    f.genreAction:SetPoint("LEFT", f.avecAction, "RIGHT", 10, 0)
    f.refAction = UI.Champ(f.contenu, CHAMP - 158, 22)
    f.refAction:SetPoint("LEFT", f.genreAction, "RIGHT", 8, 0)
    y = y + 28

    f.aideAction = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.aideAction, 10)
    f.aideAction:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE + 28, -y)
    f.aideAction:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -y)
    f.aideAction:SetJustifyH("LEFT")
    f.aideAction:SetWordWrap(true)
    y = y + 24

    f.probleme = UI.Texte(f.contenu, "", UI.C.plein)
    UI.Police(f.probleme, 10)
    f.probleme:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    f.probleme:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -y)
    f.probleme:SetWordWrap(true)

    f.valider = UI.Bouton(f.contenu, "Enregistrer", 120, 24, function() f:Enregistrer() end)
    f.valider:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 100, 24, function() f:Hide() end)
    f.annuler:SetPoint("LEFT", f.valider, "RIGHT", 8, 0)

    -- Decoche : aucun jet. Le selecteur reste VISIBLE mais eteint, pour qu'on
    -- voie ce qu'on avait choisi si on recoche.
    function f:MajJet()
        local actif = self.jetActif == true
        self.competence:SetEnabled(actif)
        self.competence:SetAlpha(actif and 1 or 0.45)
        local field = self.competenceId and LCM.Schema.Field(self.competenceId)
        self.competence.label:SetText(field and field.label or "— choisir —")
        self.aideJet:SetText(actif and "" or "sort sans jet")
    end

    function f:MajAction()
        local actif = self.actionActive == true
        self.genreAction:SetEnabled(actif)
        self.genreAction:SetAlpha(actif and 1 or 0.45)
        self.refAction:SetShown(actif)
        self.genreAction.label:SetText(self.actionGenre and Sorts.ACTIONS[self.actionGenre]
            or "— type —")
        local aides = {
            resolution = "l'identifiant de l'action du lanceur (attaque_simple, generation_buff…) ; "
                .. "le modèle de la bibliothèque qui porte le nom du sort se charge avec elle",
            macro = "le texte de la macro, tel qu'on le taperait",
            arcanum = "le nom du sort Arcanum à lancer",
        }
        self.aideAction:SetText(actif and (aides[self.actionGenre] or "choisis un type") or "")
    end

    function f:Definition()
        local definition = {
            label = self.nom:GetText(),
            icone = self.iconeChoisie,
            description = self.description:GetText(),
        }
        if self.jetActif and self.competenceId then definition.competence = self.competenceId end
        if self.actionActive and self.actionGenre then
            definition.action = { genre = self.actionGenre, ref = self.refAction:GetText() }
        end
        return definition
    end

    function f:Enregistrer()
        local definition = self:Definition()
        local sort, raison
        if self.sortId then
            sort, raison = Sorts.Modifier(self.entity, self.sortId, definition)
        else
            sort, raison = Sorts.Ajouter(self.entity, definition)
        end
        if not sort then
            self.probleme:SetText(tostring(raison))
            return
        end
        self.probleme:SetText("")
        LCM.Ok(string.format("%s %s.", tostring(sort.label),
            self.sortId and "corrige" or "ecrit dans ton grimoire"))
        self:Hide()
        local livre = UI.Grimoire.frame
        if livre and livre:IsShown() then livre:Afficher(livre.sousRang) end
        local hub = UI.Grimoires.frame
        if hub and hub:IsShown() then hub:Afficher() end
    end

    function f:Montrer(entity, sort)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucun personnage.")
            return
        end
        self.sortId = sort and sort.id or nil
        self:Titre(sort and "Corriger un sort" or "Nouveau sort")
        self:SousTitre(self.entity.name or self.entity.id)
        self.nom:SetText(sort and sort.label or "")
        self.iconeChoisie = sort and sort.icone or nil
        self.iconeBouton.texture:SetTexture(self.iconeChoisie
            or "Interface\\ICONS\\INV_Misc_QuestionMark")
        self.description:SetText(sort and sort.description or "")

        self.competenceId = sort and sort.competence or nil
        self.jetActif = self.competenceId ~= nil
        self.avecJet:Cocher(self.jetActif)
        self:MajJet()

        local action = sort and sort.action
        self.actionGenre = action and action.genre or nil
        self.actionActive = action ~= nil
        self.avecAction:Cocher(self.actionActive)
        self.refAction:SetText(action and action.ref or "")
        self:MajAction()

        self.probleme:SetText("")
        self:Show()
    end

    return f
end

function Editeur.Fenetre()
    if not Editeur.frame then Construire() end
    return Editeur.frame
end

function Editeur.Ouvrir(entity, sort)
    local f = Editeur.Fenetre()
    f:Montrer(entity, sort)
    return f
end
