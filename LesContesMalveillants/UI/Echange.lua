-- La fenetre d'echange : deux colonnes face a face, la mienne et la sienne.
--
-- On pose en GLISSANT dans sa colonne — c'est le meme geste que partout
-- ailleurs, et la colonne est une cible de glissement comme une case de sac.
-- Un clic droit sur une ligne posee la reprend.
--
-- Les deux accords s'allument quand chacun accepte ; tout changement de contenu
-- les eteint (Core/Echange.lua), et la fenetre le montre : on n'echange jamais
-- autre chose que ce qu'on a vu en acceptant.

local _, LCM = ...
local UI = LCM.UI
local E = LCM.Echange

local Ecran = {}
UI.Echange = Ecran

local LARGEUR, HAUTEUR = 560, 420
local LIGNE = 30
local COLONNE = 252

local function Nom(ref, secours)
    if secours and secours ~= "" then return secours end
    local element = LCM.Compendium and LCM.Compendium.Resoudre(ref)
    return (element and element.label) or tostring(ref)
end

local function Icone(ref)
    local element = LCM.Compendium and LCM.Compendium.Resoudre(ref)
    return (element and LCM.Icone and LCM.Icone(element.icone))
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Une colonne : un titre, une liste, et le compte des pieces posees.
local function Colonne(f, titre, mienne)
    local c = CreateFrame("Frame", nil, f.contenu)
    c:SetWidth(COLONNE)
    c.lignes, c.mienne = {}, mienne

    c.titre = UI.Texte(c, titre, UI.C.titreBloc)
    UI.Police(c.titre, 13)
    c.titre:SetPoint("TOPLEFT", c, "TOPLEFT", 4, 0)

    -- L'accord de ce cote : allume quand la personne a accepte.
    c.accord = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    c.accord:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -2)
    c.accord:SetJustifyH("RIGHT")

    c.cadre = CreateFrame("Frame", nil, c)
    c.cadre:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -20)
    c.cadre:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    c.cadre.fond = UI.Aplat(c.cadre, { 0, 0, 0, 0.22 })
    c.cadre.fond:SetAllPoints(c.cadre)
    UI.BordureFine(c.cadre, 0.28)

    c.vide = UI.Texte(c.cadre, mienne and "Glisse ici ce que tu donnes." or "(rien)",
        UI.C.discret, "GameFontNormalSmall")
    c.vide:SetPoint("TOP", c.cadre, "TOP", 0, -14)
    c.vide:SetWidth(COLONNE - 24)
    c.vide:SetJustifyH("CENTER")
    c.vide:SetWordWrap(true)

    -- MA colonne recoit ce qu'on y glisse : c'est le geste de poser.
    if mienne and UI.Glisser then
        UI.Glisser.Cible(c.cadre, function(objet)
            if not (E.courant and E.courant.ouverte) then return false, "aucun échange en cours." end
            if objet.devise then
                if not LCM.Devises.Get(objet.devise) then return false, "cette devise n'existe plus." end
                if not LCM.Bourse.Peut(LCM.Entities.Self(), objet.devise, 1) then
                    return false, "tu n'as plus de cette devise."
                end
                return true
            end
            if not objet.ref then return false, "on ne sait pas ce que c'est." end
            return true
        end, function(objet)
            if objet.devise then
                local demander = UI.Bourse and UI.Bourse.DemanderEchange
                if demander then demander(E.courant.qui, objet.devise) end
            else
                local ok, raison = E.Offrir(objet)
                if not ok and raison then LCM.Alerte(tostring(raison)) end
            end
        end)
    end

    function c:Poser(cote)
        local objets = (cote and cote.objets) or {}
        local devises = (cote and cote.devises) or {}
        local y = 6
        local rang = 0

        local function Ligne()
            rang = rang + 1
            local l = self.lignes[rang]
            if not l then
                l = CreateFrame("Button", nil, self.cadre)
                l:SetHeight(LIGNE - 2)
                l:RegisterForClicks("RightButtonUp")
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.icone = l:CreateTexture(nil, "ARTWORK")
                l.icone:SetSize(22, 22)
                l.icone:SetPoint("LEFT", l, "LEFT", 6, 0)
                l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
                l.nom:SetPoint("RIGHT", l, "RIGHT", -8, 0)
                l.nom:SetJustifyH("LEFT")
                l.nom:SetWordWrap(false)
                l:SetScript("OnClick", function(self2)
                    -- Clic droit : je reprends ce que j'avais pose. Seulement
                    -- de mon cote — on ne reprend pas ce qu'un autre donne.
                    if self2.rang and c.mienne then E.Reprendre(self2.rang) end
                end)
                self.lignes[rang] = l
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.cadre, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.cadre, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
            return l
        end

        for index, pose in ipairs(objets) do
            local l = Ligne()
            l.rang = index
            l.icone:SetTexture(Icone(pose.ref))
            local quantite = tonumber(pose.quantite) or 1
            l.nom:SetText(quantite > 1
                and string.format("%s  x%d", Nom(pose.ref, pose.nom), quantite)
                or Nom(pose.ref, pose.nom))
            l.nom:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3])
        end

        -- Les pieces apres les objets, dans l'ordre du compendium pour que les
        -- deux cotes voient la meme liste.
        for _, devise in ipairs(LCM.Bourse.Catalogue()) do
            local combien = math.floor(tonumber(devises[devise.id]) or 0)
            if combien > 0 then
                local l = Ligne()
                l.rang = nil
                l.icone:SetTexture(devise.icone or "Interface\\ICONS\\INV_Misc_Coin_02")
                l.nom:SetText(string.format("%d  %s", combien, devise.label))
                l.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            end
        end

        for index = rang + 1, #self.lignes do self.lignes[index]:Hide() end
        self.vide:SetShown(rang == 0)
    end

    return c
end

local function Construire()
    local f = UI.Fenetre("echange", "Échange", LARGEUR, HAUTEUR, { x = 0, y = -40 })
    Ecran.frame = f

    f.mienne = Colonne(f, "Je donne", true)
    f.mienne:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 6, -4)
    f.mienne:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 74)
    f.sienne = Colonne(f, "Je reçois", false)
    f.sienne:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", -6, -4)
    f.sienne:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 74)

    -- Les pieces : une devise, un montant. On fixe le montant, on ne l'ajoute
    -- pas — corriger « 50 » en « 5 » ne doit pas debiter cinquante-cinq.
    f.devise = UI.Bouton(f.contenu, "— devise —", 150, 22, function(self)
        local options = {}
        for _, devise in ipairs(LCM.Bourse.Catalogue()) do
            options[#options + 1] = { id = devise.id, label = devise.label }
        end
        if #options == 0 then LCM.Alerte("aucune devise déclarée.") return end
        Ecran.choixDevise = Ecran.choixDevise or UI.Choix("echange_devise", "Devise")
        Ecran.choixDevise:Proposer(self, options, function(id)
            f.deviseId = id
            local devise = LCM.Devises.Get(id)
            self.label:SetText(devise and devise.label or tostring(id))
            f:Rendre()
        end)
    end)
    f.devise:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 6, 42)

    f.montant = UI.Champ(f.contenu, 70, 22)
    f.montant:SetPoint("LEFT", f.devise, "RIGHT", 6, 0)
    f.poser = UI.Bouton(f.contenu, "Poser", 70, 22, function()
        if not f.deviseId then LCM.Alerte("choisis d'abord une devise.") return end
        local ok, raison = E.Monnayer(f.deviseId, f.montant:GetText())
        if not ok and raison then LCM.Alerte(tostring(raison)) end
    end)
    f.poser:SetPoint("LEFT", f.montant, "RIGHT", 6, 0)

    f.etat = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.etat:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 6, 16)
    f.etat:SetPoint("RIGHT", f.contenu, "RIGHT", -180, 0)
    f.etat:SetJustifyH("LEFT")

    f.accepter = UI.Bouton(f.contenu, "Accepter", 110, 24, function()
        local seance = E.courant
        if not seance then return end
        local ok, raison = E.Accepter(not seance.monAccord)
        if not ok and raison then LCM.Alerte(tostring(raison)) end
    end)
    f.accepter:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", -6, 10)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 90, 24, function() E.Annuler("annulé") end)
    f.annuler:SetPoint("RIGHT", f.accepter, "LEFT", -6, 0)

    -- Fermer la fenetre, c'est annuler : laisser un gage dans une fenetre
    -- fermee reviendrait a perdre ses objets sans rien dire.
    f:SetScript("OnHide", function()
        if E.courant then E.Annuler("fenêtre fermée") end
    end)

    function f:Rendre()
        local seance = E.courant
        if not seance then return end
        self.sousTitre:SetText(tostring(seance.qui))
        self.mienne:Poser(seance.mien)
        self.sienne:Poser(seance.sien)
        self.mienne.accord:SetText(seance.monAccord and "accepté" or "")
        self.sienne.accord:SetText(seance.sonAccord and "accepté" or "")
        local vert, gris = { 0.55, 0.85, 0.55 }, UI.C.discret
        local a = seance.monAccord and vert or gris
        self.mienne.accord:SetTextColor(a[1], a[2], a[3])
        local b = seance.sonAccord and vert or gris
        self.sienne.accord:SetTextColor(b[1], b[2], b[3])
        self.accepter.label:SetText(seance.monAccord and "Retirer" or "Accepter")

        -- Ce qui bloque, dit AVANT d'accepter : un objet sans place serait
        -- perdu des deux cotes au moment de conclure.
        local place, raison = E.Place()
        if not place then
            self.etat:SetText(raison or "Impossible de recevoir cet objet.")
            self.etat:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
        else
            self.etat:SetText("Clic droit sur une ligne pour la reprendre.")
            self.etat:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
        end
    end

    return f
end

function Ecran.Frame()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

-- La seance commande la fenetre : elle s'ouvre quand l'echange s'ouvre, elle se
-- ferme quand il se termine. On ne la pilote pas depuis un bouton de menu.
E.Observer(function(seance)
    local f = Ecran.frame
    if not (seance and seance.ouverte) then
        if f and f:IsShown() then
            -- Annuler a deja vide E.courant : le OnHide ne rappellera rien.
            f:Hide()
        end
        return
    end
    f = Ecran.Frame()
    f:Rendre()
    if not f:IsShown() then f:Show() end
end)

-- Lacher un objet sur une personne : c'est le geste qui ouvre un echange. Le
-- kit ne connait que ses cibles d'interface ; quand il n'en trouve aucune, il
-- nous demande si le curseur est sur quelqu'un.
if UI.Glisser then
    UI.Glisser.SansCible = function(objet)
        -- Une pile qu'on scinde (Maj + glisser) ne se donne pas : elle ne va
        -- que dans une case de sac (UI/Inventaires.lua).
        if objet.scinder then return false end
        if not (UnitExists and UnitExists("mouseover")) then return false end
        if UnitIsPlayer and not UnitIsPlayer("mouseover") then return false end
        if UnitIsUnit and UnitIsUnit("mouseover", "player") then return false end
        local nom, royaume = UnitName("mouseover")
        if not nom then return false end
        local qui = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
        -- Lache sur quelqu'un : le geste est traite, meme refuse. Rendre faux
        -- le ferait passer pour un lacher dans le vide, qui propose de jeter.
        if objet.devise then
            local demander = UI.Bourse and UI.Bourse.DemanderEchange
            if not demander then return false end
            demander(qui, objet.devise)
        else
            Ecran.Donner(qui, objet)
        end
        return true
    end
end

-- Donner un objet a quelqu'un : dans l'echange deja ouvert avec lui, sinon en
-- lui en proposant un. Le lacher sur une personne et le menu « Échanger » d'un
-- sac passent par ici.
-- `objet` peut aussi etre une SOMME : { devise = id, combien = n } (le clic
-- droit d'une devise de la bourse). Elle s'AJOUTE a ce qu'on offre deja.
function Ecran.Donner(qui, objet)
    if type(objet) == "table" and objet.devise then
        if not LCM.Bourse.Peut(LCM.Entities.Self(), objet.devise, objet.combien) then
            LCM.Alerte("la bourse n'a pas de quoi.")
            return false
        end
        if E.courant and E.courant.ouverte and E.courant.qui == qui then
            local deja = tonumber(E.courant.mien.devises[objet.devise]) or 0
            local ok, raison = E.Monnayer(objet.devise, deja + objet.combien)
            if not ok and raison then LCM.Alerte(tostring(raison)) end
            return ok
        end
    end
    if E.courant and E.courant.ouverte and E.courant.qui == qui then
        -- Une selection (`lot`) pose chacun de ses objets.
        local tous, ok, raison = type(objet) == "table" and objet.lot or { objet }, true, nil
        for _, o in ipairs(tous) do
            local pose, pourquoi = E.Offrir(o)
            if not pose then ok, raison = false, raison or pourquoi end
        end
        if not ok and raison then LCM.Alerte(tostring(raison)) end
        return ok
    end
    local ok, raison = E.Proposer(qui, objet)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    return ok
end

LCM.Echange.Ecran = Ecran
