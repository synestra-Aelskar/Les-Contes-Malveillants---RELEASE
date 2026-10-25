-- La bourse.
--
-- Une ligne par devise declaree, meme a zero : savoir qu'une monnaie existe et
-- qu'on n'en a pas est une information. Le MJ ajuste les soldes ici, en
-- cliquant sur la valeur pour la taper ; le joueur lit.
--
-- Depuis le 24 octobre 2026, ces lignes vivent AILLEURS aussi : la colonne
-- d'Inventaires en pose un jeu au-dessus de la Ceinture (« transvaser la
-- Bourse directement dans inventaires »), ce qui a libere son cran du menu
-- radial. On ne garde donc pas le dessin d'une ligne dans la fenetre : c'est un
-- PANNEAU, qu'on accroche ou l'on veut. La fenetre, elle, reste — le MJ s'en
-- sert pour consulter la bourse d'un autre (Consultation.lua), et la commande
-- /lcm bourse l'ouvre encore.

local _, LCM = ...
local UI = LCM.UI
local Bourse = LCM.Bourse

local Ecran = {}
UI.Bourse = Ecran

local LARGEUR, HAUTEUR = 420, 360
local LIGNE = 34

-- Un montant a prendre dans la bourse : un entier, 1 au moins, pas plus qu'on
-- n'a. Un refus le dit et laisse la demande ouverte.
local function DemanderMontant(titre, solde, suite)
    UI.Demande():Demander(titre, solde, function(texte)
        local n = tonumber(texte)
        if not n or n ~= math.floor(n) or n < 1 then
            return false, string.format("montant illisible (%s) : un nombre entier, 1 au moins.", tostring(texte))
        end
        if n > solde then return false, string.format("tu n'en as que %d.", solde) end
        suite(n)
        return true
    end)
end

local confirmation

-- Tout ce qui montre un solde se remet a jour d'un coup : la fenetre si elle
-- existe, et la colonne d'Inventaires qui en porte un second jeu de lignes.
-- Sans cela, on materialisait des ecus d'un cote et l'autre gardait l'ancien
-- chiffre (le MJ, 24 octobre 2026).
function Ecran.Rafraichir()
    if Ecran.frame then Ecran.frame:Afficher() end
    if UI.Inventaires and UI.Inventaires.Actualiser then UI.Inventaires.Actualiser() end
end

-- Le depot sur un personnage demande le montant, puis propose l'echange.
-- Le solde est relu au moment du depot pour ne pas se fier a un glissement
-- ancien si la bourse a change entre-temps.
--
-- Au niveau du module, et non dans la fenetre : UI/Echange.lua s'en sert, et
-- depuis que la Bourse vit dans Inventaires la fenetre peut tres bien n'avoir
-- jamais ete ouverte.
function Ecran.DemanderEchange(qui, deviseId)
    local entity = LCM.Entities.Self()
    if not entity then return false end
    local devise = LCM.Devises.Get(deviseId)
    if not devise then LCM.Alerte("cette devise n'existe plus.") return false end
    local solde = Bourse.Solde(entity, deviseId)
    if solde < 1 then LCM.Alerte("tu n'as plus de " .. devise.label .. ".") return false end
    DemanderMontant(string.format("Donner combien de %s à %s ?", devise.label, qui), solde, function(n)
        local echange = LCM.Echange and LCM.Echange.Ecran
        if echange and echange.Donner then
            echange.Donner(qui, { devise = deviseId, combien = n, nom = devise.label, icone = devise.icone })
        end
    end)
    return true
end

-- Reposer en bourse une pile prise dans un sac : le geste inverse de
-- « Materialiser ». `deviseVoulue` restreint a une monnaie — c'est le cas d'une
-- LIGNE, qui ne parle que de la sienne ; la carte « Monnaies » de la colonne
-- d'Inventaires, elle, accepte n'importe laquelle et la route elle-meme
-- (le MJ, 24 octobre 2026).
function Ecran.Accepte(objet, deviseVoulue, nomVoulu)
    local o = type(objet) == "table" and objet.origine
    -- Reposer sur la bourse ce qu'on venait d'y prendre : un glissement qu'on
    -- annule, pas une erreur. Le depot ne fera rien.
    if o and o.bourse then return true end
    if not (o and o.case) then return false, "glisse une pile depuis un de tes sacs." end
    local devise = tostring(objet.ref or ""):match("^devises/(.+)$")
    if not devise then return false, "seule une monnaie se met en bourse." end
    if deviseVoulue and devise ~= deviseVoulue then
        return false, string.format("c'est la ligne des %s.", tostring(nomVoulu or deviseVoulue))
    end
    if not Bourse.EstMateriel(devise) then return false, "cette monnaie ne se transporte pas." end
    return true
end

function Ecran.Reposer(objet)
    local o = type(objet) == "table" and objet.origine
    if o and o.bourse then return end
    local entity = LCM.Entities.Self()
    local devise = tostring(objet.ref or ""):match("^devises/(.+)$")
    local element = devise and LCM.Devises.Get(devise)
    local nom = element and element.label or tostring(devise)
    DemanderMontant(string.format("Remettre combien de %s en bourse ?", nom),
        tonumber(objet.quantite) or 1, function(n)
            local ok, raison = Bourse.Encaisser(entity, devise, n, o)
            if not ok then LCM.Alerte(tostring(raison)) return end
            LCM.Info(string.format("%d %s en bourse.", n, nom))
            Ecran.Rafraichir()
        end)
end

-- ===== Le panneau : des lignes de devises, posables n'importe ou ===========

local Panneau = {}
Panneau.__index = Panneau

-- `parent` recoit les lignes ; `hauteur` les taille (34 dans la fenetre, plus
-- serre dans une colonne).
function Ecran.Panneau(parent, options)
    options = options or {}
    return setmetatable({
        parent = parent, lignes = {},
        hauteur = options.hauteur or LIGNE,
    }, Panneau)
end

-- La sienne, et pas une copie recue : on ne donne, ne jette ni ne materialise
-- l'argent d'un autre.
function Panneau:Mienne()
    local entity = self.entity
    return entity ~= nil and not entity.distante and entity == LCM.Entities.Self()
end

function Panneau:Glisser(l)
    if not (self:Mienne() and l.deviseId and UI.Glisser) then return end
    local solde = Bourse.Solde(self.entity, l.deviseId)
    if solde < 1 then return end
    local devise = LCM.Devises.Get(l.deviseId)
    UI.Glisser.Commencer({
        devise = l.deviseId, combien = solde,
        nom = (devise and devise.label or l.deviseId) .. "  (choisir le montant au dépôt)",
        icone = devise and devise.icone,
        ref = Bourse.Ref(l.deviseId),
        -- Une monnaie glissee de la bourse n'est pas une FABRICATION : elle
        -- existe deja, elle change seulement de forme. Son origine le dit,
        -- pour que les sacs ne la prennent pas pour une entree du
        -- compendium — ce qui la reservait au MJ, et faisait demander au
        -- compendium ce qu'etait une reference absente (19 octobre 2026).
        origine = { bourse = true, devise = l.deviseId },
    })
end

-- Clic droit sur une devise : Échanger (a qui, puis combien) et Jeter
-- (combien, puis confirmation), comme un objet de sac (13 octobre 2026).
function Panneau:Menu(l)
    if not (self:Mienne() and l.deviseId) then return end
    local entity = self.entity
    local id, label = l.deviseId, tostring(l.nom:GetText() or "")
    local solde = Bourse.Solde(entity, id)
    local function Rien() LCM.Alerte(string.format("pas de %s dans la bourse.", label)) end
    local options = {}
    local donner = LCM.Echange and LCM.Echange.Ecran and LCM.Echange.Ecran.Donner
    if donner then
        if solde <= 0 then
            options[#options + 1] = { label = "Échanger", action = Rien }
        else
            local cibles = {}
            local liste = UI.Inventaires and UI.Inventaires.Destinataires and UI.Inventaires.Destinataires() or {}
            for _, qui in ipairs(liste) do
                cibles[#cibles + 1] = { label = qui, action = function()
                    DemanderMontant(string.format("Donner combien de %s à %s ?", label, qui), solde, function(n)
                        donner(qui, { devise = id, combien = n, nom = label })
                    end)
                end }
            end
            if #cibles > 0 then
                options[#options + 1] = { label = "Échanger >", sous = cibles }
            else
                options[#options + 1] = { label = "Échanger", action = function()
                    LCM.Alerte("personne à qui le donner : cible un joueur ou forme un groupe.")
                end }
            end
        end
    end
    -- Une monnaie « Materiel » sort de la bourse en pile : elle se porte,
    -- se cache dans un coffre, se donne comme un objet. Elle revient en
    -- bourse par le clic droit sur la pile (le MJ, 19 octobre 2026).
    if Bourse.EstMateriel(id) then
        options[#options + 1] = { label = "Matérialiser", action = function()
            if solde <= 0 then Rien() return end
            DemanderMontant(string.format("Sortir combien de %s de la bourse ?", label), solde, function(n)
                local ok, raison = Bourse.Materialiser(entity, id, n)
                if not ok then LCM.Alerte(tostring(raison)) return end
                LCM.Info(string.format("%d %s en main.", n, label))
                Ecran.Rafraichir()
            end)
        end }
    end
    options[#options + 1] = { label = "Détruire", action = function()
        if solde <= 0 then Rien() return end
        DemanderMontant(string.format("Détruire combien de %s ?", label), solde, function(n)
            confirmation = confirmation or UI.Confirmer(UIParent, "", "Détruire")
            confirmation:Demander(string.format("Détruire %d %s ?\nC'est perdu : on ne le récupère pas.", n, label),
                function()
                    local ok, raison = Bourse.Debiter(entity, id, n)
                    if not ok then LCM.Alerte(tostring(raison)) return end
                    LCM.Info(string.format("%d %s détruit(s).", n, label))
                    Ecran.Rafraichir()
                end)
        end)
    end }
    UI.MenuContexte():Ouvrir(l, options)
end

function Panneau:Ligne(rang)
    local l = self.lignes[rang]
    if l then return l end
    local p = self
    l = CreateFrame("Button", nil, self.parent)
    l:SetHeight(self.hauteur - 2)
    l:RegisterForClicks("RightButtonUp")
    l:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then p:Menu(l) end
    end)
    l:RegisterForDrag("LeftButton")
    l:SetScript("OnDragStart", function() p:Glisser(l) end)
    l:SetScript("OnDragStop", function() if UI.Glisser then UI.Glisser.Lacher() end end)
    l:SetScript("OnEnter", function()
        GameTooltip:SetOwner(l, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(l.nom:GetText() or ""))
        GameTooltip:AddLine("Glisse sur un joueur pour proposer un échange.", 0.75, 0.75, 0.75)
        if Bourse.EstMateriel(l.deviseId) then
            GameTooltip:AddLine("Glisse-la dans un sac pour l'emporter en pièces.", 0.75, 0.75, 0.75)
            GameTooltip:AddLine("Pose une pile ici pour la remettre en bourse.", 0.75, 0.75, 0.75)
        end
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- On y REPOSE une pile de cette monnaie : c'est le geste inverse de
    -- « Materialiser », et il manquait — la bourse n'etait une cible pour rien
    -- (le MJ, 19 octobre 2026).
    UI.Glisser.Cible(l, function(objet)
        if not p:Mienne() then return false, "ce n'est pas ta bourse." end
        return Ecran.Accepte(objet, l.deviseId, l.nom:GetText())
    end, Ecran.Reposer)

    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(self.hauteur - 10, self.hauteur - 10)
    l.icone:SetPoint("LEFT", l, "LEFT", 6, 0)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    l.solde = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.solde, 13)
    l.solde:SetJustifyH("RIGHT")
    l.solde:SetPoint("RIGHT", l, "RIGHT", -10, 0)
    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, 12)
    l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
    -- Borne a droite, sans retour a la ligne : dans une colonne etroite, un nom
    -- long se coupe au lieu de passer sous le solde.
    l.nom:SetPoint("RIGHT", l.solde, "LEFT", -8, 0)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)

    -- Le MJ clique sur le solde et tape le nouveau ; le joueur ne touche a
    -- rien. Les boutons + et - (un par un, Maj par dix) ont ete retires le
    -- 13 octobre 2026 : pour donner 250 ecus, on tapait sur un bouton.
    l.saisie = CreateFrame("Button", nil, l)
    -- Le clic droit garde son menu, meme sur le montant.
    l.saisie:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l.saisie:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
    l.saisie:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 0)
    l.saisie:SetWidth(70)
    l.saisie.survol = UI.Aplat(l.saisie, UI.C.survol, "HIGHLIGHT")
    l.saisie.survol:SetAllPoints(l.saisie)
    l.saisie:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then p:Menu(l) return end
        if not (LCM.IsMaster() and p.entity and l.deviseId) then return end
        local deviseId = l.deviseId
        UI.Demande():Demander("Solde : " .. tostring(l.nom:GetText() or ""),
            Bourse.Solde(p.entity, deviseId), function(texte)
                local ok, raison = Bourse.Definir(p.entity, deviseId, texte)
                if ok then Ecran.Rafraichir() end
                return ok, raison
            end)
    end)
    l.saisie:SetScript("OnEnter", function(bouton)
        GameTooltip:SetOwner(bouton, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(l.nom:GetText() or ""))
        GameTooltip:AddLine("Clic : saisir le solde.", 0.55, 0.55, 0.55)
        GameTooltip:AddLine("Glisse sur un joueur pour proposer un échange.", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    l.saisie:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l.saisie:RegisterForDrag("LeftButton")
    l.saisie:SetScript("OnDragStart", function() p:Glisser(l) end)
    l.saisie:SetScript("OnDragStop", function() if UI.Glisser then UI.Glisser.Lacher() end end)

    self.lignes[rang] = l
    return l
end

-- Pose les lignes a partir de `y` (qui descend, comme partout ailleurs) et rend
-- la hauteur occupee — 0 quand aucune devise n'est declaree, pour qu'un hote
-- n'annonce pas une section vide. Sans `largeur`, elles s'etirent sur le cadre.
function Panneau:Poser(entity, y, largeur)
    self.entity = entity
    local devises = Bourse.Liste(entity)
    local mj = LCM.IsMaster() and not (entity and entity.distante)
    local haut = y or 0
    for rang, devise in ipairs(devises) do
        local l = self:Ligne(rang)
        l.deviseId = devise.id
        l.icone:SetTexture(devise.icone or "Interface\\ICONS\\INV_Misc_Coin_02")
        l.nom:SetText(devise.label)
        l.solde:SetText(tostring(devise.solde))
        -- Un solde a zero s'efface : l'oeil va a ce qu'on a.
        local couleur = devise.solde > 0 and UI.C.titre or UI.C.discret
        l.solde:SetTextColor(couleur[1], couleur[2], couleur[3])
        l.saisie:SetShown(mj)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, -haut)
        if largeur then
            l:SetWidth(largeur)
        else
            l:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", 0, -haut)
        end
        l:Show()
        haut = haut + self.hauteur
    end
    for rang = #devises + 1, #self.lignes do self.lignes[rang]:Hide() end
    self.nombre = #devises
    return haut - (y or 0)
end

function Panneau:Masquer()
    for _, l in ipairs(self.lignes) do l:Hide() end
    self.nombre = 0
end

-- La largeur qu'il faut pour ne pas couper les noms : 6 de marge + 24 d'icone
-- + 8 + le nom + 16 + le solde + la marge de droite. Nil s'il n'y a rien a
-- montrer. A 420 fixes, on avait trois lignes courtes dans un rectangle vide —
-- « Essence stelaire » n'en demande pas la moitie (4 octobre 2026).
function Ecran.LargeurVoulue(entity)
    local plusLong = 0
    for _, devise in ipairs(Bourse.Liste(entity)) do
        plusLong = math.max(plusLong, UI.Fiche.LargeurTexte(devise.label, 12) or 0)
    end
    if plusLong <= 0 then return nil end
    return math.ceil(6 + 24 + 8 + plusLong + 16 + 44 + 8 + 24)
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("bourse", "Bourse", LARGEUR, HAUTEUR, { x = -120, y = -60 })
    Ecran.frame = f
    f.nom = f.sousTitre

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.panneau = Ecran.Panneau(f.zone.contenu)
    -- La meme table, pas une copie : qui lisait f.lignes continue de lire les
    -- lignes de la fenetre.
    f.lignes = f.panneau.lignes

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    function f:Afficher()
        -- La fenetre se taille sur le plus long nom de devise.
        local voulue = Ecran.LargeurVoulue(self.entity)
        -- Un plancher : sous cette largeur, le titre de la fenetre et ses
        -- ornements ne tiennent plus.
        if voulue then self:SetWidth(math.max(260, voulue)) end
        local h = self.panneau:Poser(self.entity, 0)
        self.zone:Regler(h)
        self.nombreAffiche = self.panneau.nombre
        self.vide:SetText(self.panneau.nombre > 0 and "" or "Aucune devise déclarée.")
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self:SousTitre(self.entity.name or self.entity.id)
        self:Afficher()
        self:Show()
    end

    f:SetScript("OnMouseDown", function(self) UI.Devant(self) end)

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

-- La commande reste : la Bourse a quitte le menu radial pour la colonne
-- d'Inventaires (le MJ, 24 octobre 2026), mais la fenetre sert encore — au MJ
-- qui consulte celle d'un autre, et a qui prefere la voir a part.
LCM.AddCommand("bourse", "ouvre ta bourse", function() Ecran.Basculer() end)
