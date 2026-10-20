-- Donner son nom a son grimoire.
--
-- Un grimoire vient du compendium, et son contenu appartient au maitre du jeu.
-- Mais le grimoire PERSONNEL — celui que tout le monde a d'office et qu'on
-- remplit soi-meme — n'a pas de raison de s'appeler pareil chez tout le monde.
-- On peut donc lui donner un nom, une description et une icone, et ca ne vaut
-- que pour soi : rien n'est ecrit dans le compendium (Core/Grimoires.lua).
--
-- Un grimoire RECU n'est pas concerne : le renommer effacerait ce que le
-- maitre du jeu a ecrit, pour personne d'autre que soi.

local _, LCM = ...
local UI = LCM.UI
local Grimoires = LCM.Grimoires

local Editeur = {}
UI.GrimoireEditeur = Editeur

local LARGEUR, HAUTEUR = 480, 260
local ETIQUETTE = 92
local CHAMP = LARGEUR - 24 - ETIQUETTE - 8

local function Construire()
    local f = UI.Fenetre("grimoire_editeur", "Mon grimoire", LARGEUR, HAUTEUR, { x = 200, y = -40 })
    Editeur.frame = f

    local y = 4

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
        Editeur.selecteur = Editeur.selecteur or UI.SelecteurIcone("grimoire")
        Editeur.selecteur:Proposer(self, function(chemin)
            f.iconeChoisie = chemin
            f.iconeBouton.texture:SetTexture(chemin)
        end)
    end)
    UI.Bulle(f.iconeBouton, "Icône", "Clic : choisir l'icône de ton grimoire.")

    f.nom = UI.Champ(f.contenu, CHAMP + ETIQUETTE - 38, 22)
    f.nom:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 38, -y - 4)
    y = y + 38

    local fs = UI.Texte(f.contenu, "Description", UI.C.texte)
    UI.Police(fs, 11)
    fs:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    f.description = UI.Zone(f.contenu, CHAMP, 86)
    f.description:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE, -y + 3)
    y = y + 96

    f.aide = UI.Texte(f.contenu, "Laisse un champ vide pour reprendre ce que dit le compendium.",
        UI.C.discret)
    UI.Police(f.aide, 10)
    f.aide:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    f.aide:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -y)
    f.aide:SetJustifyH("LEFT")
    f.aide:SetWordWrap(true)

    f.valider = UI.Bouton(f.contenu, "Enregistrer", 120, 24, function() f:Enregistrer() end)
    f.valider:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.defaut = UI.Bouton(f.contenu, "Par défaut", 110, 24, function()
        f.iconeChoisie = nil
        f.nom:SetText("")
        f.description:SetText("")
        f.iconeBouton.texture:SetTexture(f.iconeOrigine or "Interface\\ICONS\\INV_Misc_Book_09")
    end)
    f.defaut:SetPoint("LEFT", f.valider, "RIGHT", 8, 0)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 100, 24, function() f:Hide() end)
    f.annuler:SetPoint("LEFT", f.defaut, "RIGHT", 8, 0)

    function f:Enregistrer()
        local ok, raison = Grimoires.Personnaliser(self.entity, {
            label = self.nom:GetText(),
            description = self.description:GetText(),
            icone = self.iconeChoisie,
        })
        if not ok then
            LCM.Alerte(tostring(raison))
            return
        end
        LCM.Ok("Ton grimoire porte ton nom.")
        self:Hide()
        local hub = UI.Grimoires.frame
        if hub and hub:IsShown() then hub:Afficher() end
        local livre = UI.Grimoire.frame
        if livre and livre:IsShown() then livre:Afficher(livre.sousRang) end
    end

    function f:Montrer(entity, grimoire)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucun personnage.")
            return
        end
        if not (grimoire and grimoire.personnel) then
            LCM.Alerte("seul ton grimoire personnel se renomme.")
            return
        end
        self.grimoire = grimoire
        self.iconeOrigine = grimoire.icone
        self:SousTitre(self.entity.name or self.entity.id)

        -- On montre CE QU'ON A ECRIT, pas ce que le compendium dit : un champ
        -- vide veut dire « reprends le defaut », et il doit se voir vide.
        local perso = Grimoires.Personnalisation(self.entity) or {}
        self.nom:SetText(perso.label or "")
        self.description:SetText(perso.description or "")
        self.iconeChoisie = perso.icone
        self.iconeBouton.texture:SetTexture(perso.icone or grimoire.icone
            or "Interface\\ICONS\\INV_Misc_Book_09")
        self:Show()
    end

    return f
end

function Editeur.Fenetre()
    if not Editeur.frame then Construire() end
    return Editeur.frame
end

function Editeur.Ouvrir(entity, grimoire)
    local f = Editeur.Fenetre()
    f:Montrer(entity, grimoire)
    return f
end
