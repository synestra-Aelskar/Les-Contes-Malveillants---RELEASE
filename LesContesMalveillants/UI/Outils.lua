-- Les outils partages du MJ, vus par le joueur (Core/Outils.lua).
--
-- Chaque outil a SA fenetre, comme dans Necronicon (Master.lua :
-- ShowMasterSharedBar). La premiere reprise les empilait dans une liste de
-- 240 de large : la taille, les couleurs et le mode d'affichage que le MJ
-- regle n'y servaient a rien, et le joueur ne pouvait pas mettre la jauge du
-- rituel ou il voulait (le MJ, 20 octobre 2026).
--
-- Sans le grand habillage : les ornements d'angle mangeraient la moitie d'une
-- barre de 44 de haut. Une bordure fine, et le fond que le MJ a choisi.
--
-- A sa naissance, une fenetre se range dans une colonne a droite de l'ecran.
-- Des que le joueur la tire ailleurs, sa place est gardee (par sorte et
-- libelle : « Rituel » retrouve sa place a la scene suivante).
--
-- Une annonce, elle, n'est pas un outil qu'on garde : elle s'affiche en grand
-- au milieu de l'ecran et s'efface.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Outils = Ecran

local O = LCM.Outils
local DUREE_ANNONCE = 6
-- La colonne de naissance, en haut a droite.
local COLONNE_X, COLONNE_Y, ECART = -60, -140, 10

Ecran.cadres = {}

local function Teinte(hexa, defaut) return O.Teinte(hexa, defaut) end

local function Defaut(sorte, cle)
    local champ = O.Champ(sorte, cle)
    return champ and champ.defaut
end

-- Un nombre comme on l'ecrit : « 7 » et non « 7.0 ». Le pas d'une barre peut
-- etre fractionnaire, la valeur doit pouvoir l'etre aussi.
local function Chiffre(n)
    n = tonumber(n) or 0
    if n == math.floor(n) then return string.format("%d", n) end
    return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end

-- ===== La fenetre d'un outil ===============================================

local function Construire(cle)
    local f = CreateFrame("Frame", nil, UIParent)
    f.cleOutil = cle
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        if self.outil then
            O.NoterPlace(self.outil, { point = point, relPoint = relPoint, x = x, y = y })
        end
    end)
    f:SetScript("OnMouseDown", function(self) UI.Devant(self) end)
    f:SetScript("OnEnter", function(self)
        local o = self.outil
        if not o then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(o.libelle or ""))
        -- Qui partage est toujours dit : on ne prouve pas qu'un expediteur est
        -- MJ, on le montre.
        GameTooltip:AddLine("Partagé par " .. (tostring(o.mj or "?"):match("^[^-]+") or tostring(o.mj)),
            0.75, 0.75, 0.75)
        GameTooltip:AddLine("Glisse-la où tu veux : sa place est gardée.", 0.55, 0.55, 0.55)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)
    UI.BordureFine(f, 0.40)

    f.titre = UI.Texte(f, "", UI.C.titre, "GameFontNormalSmall")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -5)
    f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -5)
    f.titre:SetJustifyH("CENTER")
    f.titre:SetWordWrap(false)

    -- La jauge d'une barre : un fond, un remplissage, et la valeur par-dessus.
    f.jaugeFond = f:CreateTexture(nil, "ARTWORK")
    f.jaugeFond:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -20)
    f.jaugeFond:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    f.plein = f:CreateTexture(nil, "OVERLAY")
    f.plein:SetPoint("TOPLEFT", f.jaugeFond, "TOPLEFT", 0, 0)
    f.plein:SetPoint("BOTTOMLEFT", f.jaugeFond, "BOTTOMLEFT", 0, 0)
    f.valeur = UI.Texte(f, "", UI.C.texte, "GameFontNormal")
    f.valeur:SetPoint("CENTER", f.jaugeFond, "CENTER", 0, 0)
    f.valeur:SetJustifyH("CENTER")

    -- Le grand nombre d'un compteur.
    f.nombre = UI.Texte(f, "", UI.C.accent, "GameFontNormalLarge")
    f.nombre:SetPoint("TOP", f.titre, "BOTTOM", 0, -4)
    f.nombre:SetJustifyH("CENTER")

    -- Le texte d'une note, dans une zone qui defile.
    f.zone = UI.Defilement(f)
    f.zone:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -22)
    f.zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    f.texte = UI.Texte(f.zone.contenu, "", UI.C.texte)
    f.texte:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 2, -2)
    f.texte:SetPoint("TOPRIGHT", f.zone.contenu, "TOPRIGHT", -2, -2)
    f.texte:SetWordWrap(true)

    local ALIGNEMENTS = { gauche = "LEFT", centre = "CENTER", droite = "RIGHT" }

    function f:Montrer(o)
        self.outil = o
        local sorte = o.sorte
        self.titre:SetText(tostring(o.libelle or ""))

        local barre = sorte == "barre"
        local compteur = sorte == "compteur"
        local note = sorte == "note"
        self.jaugeFond:SetShown(barre)
        self.plein:SetShown(false)
        self.valeur:SetShown(false)
        self.nombre:SetShown(compteur)
        self.zone:SetShown(note)

        if barre then
            self:SetSize(o.largeur, o.hauteur)
            self.fond:SetColorTexture(0.03, 0.03, 0.03, 0.92)
            self.jaugeFond:SetColorTexture(Teinte(o.couleurFond, Defaut("barre", "couleurFond")))
            self.plein:SetColorTexture(Teinte(o.couleur, Defaut("barre", "couleur")))
            local etendue = (tonumber(o.maximum) or 1) - (tonumber(o.minimum) or 0)
            local part = etendue > 0 and (((tonumber(o.valeur) or 0) - (tonumber(o.minimum) or 0)) / etendue) or 0
            part = math.max(0, math.min(1, part))
            -- La largeur utile : la fenetre moins ses deux marges de 8.
            self.plein:SetWidth(math.max(1, math.floor((o.largeur - 16) * part)))
            self.plein:SetShown(part > 0)
            self.part = part
            if o.affichage == "cache" then
                self.valeur:SetText("")
            elseif o.affichage == "pourcentage" then
                self.valeur:SetText(string.format("%d%%", math.floor(part * 100 + 0.5)))
                self.valeur:Show()
            else
                self.valeur:SetText(string.format("%s / %s", Chiffre(o.valeur), Chiffre(o.maximum)))
                self.valeur:Show()
            end
        elseif compteur then
            local police = tonumber(o.police) or Defaut("compteur", "police")
            UI.Police(self.nombre, police)
            self.nombre:SetText(tostring(o.valeur or 0))
            self.nombre:SetTextColor(Teinte(o.couleur, Defaut("compteur", "couleur")))
            self.fond:SetColorTexture(0.03, 0.03, 0.03, 0.92)
            -- Le titre, le nombre, et deux marges.
            local largeur = math.max(120, (self.nombre:GetStringWidth() or 0) + 36,
                (self.titre:GetStringWidth() or 0) + 24)
            self:SetSize(largeur, 26 + police + 10)
        elseif note then
            self:SetSize(o.largeur, o.hauteur)
            self.fond:SetColorTexture(Teinte(o.couleurFond, Defaut("note", "couleurFond")))
            self.texte:SetText(tostring(o.texte or ""))
            self.texte:SetJustifyH(ALIGNEMENTS[o.alignement] or "LEFT")
            self.zone:Regler((self.texte:GetStringHeight() or 0) + 8)
        end
        self:Show()
    end

    Ecran.cadres[cle] = f
    return f
end

-- Ranger ce qui n'a pas de place choisie : une colonne en haut a droite, dans
-- l'ordre d'arrivee. Ce que le joueur a deplace garde sa place.
local function Ranger(recus)
    local y = COLONNE_Y
    for _, o in ipairs(recus) do
        local f = Ecran.cadres[o.cle]
        if f and f:IsShown() then
            local place = O.Place(o)
            f:ClearAllPoints()
            if place and place.point then
                f:SetPoint(place.point, UIParent, place.relPoint or place.point,
                    place.x or 0, place.y or 0)
            else
                f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", COLONNE_X, y)
                y = y - (f:GetHeight() or 40) - ECART
            end
        end
    end
end

function Ecran.Afficher()
    local recus = O.Recus()
    local vus = {}
    for _, o in ipairs(recus) do
        vus[o.cle] = true
        local f = Ecran.cadres[o.cle] or Construire(o.cle)
        f:Montrer(o)
    end
    for cle, f in pairs(Ecran.cadres) do
        if not vus[cle] then f:Hide() end
    end
    Ranger(recus)
    Ecran.nombre = #recus
    return #recus
end

-- Compat : il n'y a plus de fenetre unique, mais « /lcm outils » et les
-- scenarios demandaient « la fenetre ». On rend celle du premier outil.
function Ecran.Fenetre()
    local recus = O.Recus()
    return recus[1] and Ecran.cadres[recus[1].cle] or nil
end

-- ===== L'annonce ===========================================================

-- Grande, au centre, et elle s'efface seule. Le MJ en regle le titre, l'icone,
-- les couleurs et les tailles ; les bords s'estompent pour qu'elle se pose sur
-- l'ecran sans l'encadrer.
function Ecran.Annonce(expediteur, annonce)
    if type(annonce) ~= "table" then annonce = { texte = annonce } end
    local texte = tostring(annonce.texte or "")
    if texte:gsub("%s+", "") == "" then return nil end

    local a = Ecran.annonce
    if not a then
        a = CreateFrame("Frame", "LCM_Annonce", UIParent)
        a:SetPoint("TOP", UIParent, "TOP", 0, -180)
        a:SetFrameStrata("FULLSCREEN_DIALOG")
        a:SetToplevel(true)
        a:EnableMouse(false)
        -- Le fond en deux moities : chacune s'estompe vers le bord, de sorte
        -- que l'annonce n'ait pas de cadre franc au milieu de l'ecran.
        a.fondGauche = a:CreateTexture(nil, "BACKGROUND")
        a.fondGauche:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
        a.fondGauche:SetPoint("BOTTOMRIGHT", a, "BOTTOM", 0, 0)
        a.fondDroite = a:CreateTexture(nil, "BACKGROUND")
        a.fondDroite:SetPoint("TOPLEFT", a, "TOP", 0, 0)
        a.fondDroite:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, 0)
        a.filetHaut = a:CreateTexture(nil, "OVERLAY")
        a.filetHaut:SetHeight(2)
        a.filetHaut:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
        a.filetHaut:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, 0)
        a.filetBas = a:CreateTexture(nil, "OVERLAY")
        a.filetBas:SetHeight(2)
        a.filetBas:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 0, 0)
        a.filetBas:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, 0)
        a.icone = a:CreateTexture(nil, "ARTWORK")
        a.icone:SetSize(44, 44)
        a.icone:SetPoint("LEFT", a, "LEFT", 16, 0)
        a.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        a.titre = UI.Texte(a, "", UI.C.titre)
        a.titre:SetJustifyH("CENTER")
        a.titre:SetWordWrap(false)
        a.texte = UI.Texte(a, "", UI.C.texte)
        a.texte:SetJustifyH("CENTER")
        a.texte:SetWordWrap(true)
        a.qui = UI.Texte(a, "", UI.C.discret)
        UI.Police(a.qui, 11)
        a.qui:SetPoint("TOP", a, "BOTTOM", 0, -2)
        a:SetScript("OnUpdate", function(self, ecoule)
            self.reste = (self.reste or 0) - (tonumber(ecoule) or 0)
            -- La derniere seconde, l'annonce s'estompe au lieu de disparaitre.
            self:SetAlpha(math.max(0, math.min(1, self.reste)))
            if self.reste <= 0 then self:Hide() end
        end)
        Ecran.annonce = a
    end

    local largeur = tonumber(annonce.largeur) or Defaut("annonce", "largeur")
    local police = tonumber(annonce.police) or Defaut("annonce", "police")
    local policeTitre = tonumber(annonce.policeTitre) or Defaut("annonce", "policeTitre")
    local fr, fg, fb = Teinte(annonce.couleurFond, Defaut("annonce", "couleurFond"))
    local icone = tostring(annonce.icone or "")

    a.fondGauche:SetColorTexture(fr, fg, fb, 0.92)
    a.fondDroite:SetColorTexture(fr, fg, fb, 0.92)
    -- Le liseret reprend la couleur du fond, eclaircie : il appartient a
    -- l'annonce, il ne lui est pas colle.
    a.filetHaut:SetColorTexture(math.min(1, fr + 0.45), math.min(1, fg + 0.38), math.min(1, fb + 0.22), 0.85)
    a.filetBas:SetColorTexture(math.min(1, fr + 0.45), math.min(1, fg + 0.38), math.min(1, fb + 0.22), 0.85)

    a.icone:SetShown(icone ~= "")
    if icone ~= "" then a.icone:SetTexture(LCM.Icone(icone)) end
    local gauche = icone ~= "" and 72 or 20

    UI.Police(a.titre, policeTitre)
    UI.Police(a.texte, police)
    a.titre:SetText(tostring(annonce.libelle or Defaut("annonce", "libelle")))
    a.titre:SetTextColor(Teinte(annonce.couleurTitre, Defaut("annonce", "couleurTitre")))
    a.texte:SetText(texte)
    a.texte:SetTextColor(Teinte(annonce.couleurTexte, Defaut("annonce", "couleurTexte")))

    a:SetWidth(largeur)
    a.titre:ClearAllPoints()
    a.titre:SetPoint("TOPLEFT", a, "TOPLEFT", gauche, -12)
    a.titre:SetPoint("TOPRIGHT", a, "TOPRIGHT", -20, -12)
    a.texte:ClearAllPoints()
    a.texte:SetPoint("TOPLEFT", a.titre, "BOTTOMLEFT", 0, -8)
    a.texte:SetPoint("TOPRIGHT", a.titre, "BOTTOMRIGHT", 0, -8)
    -- La hauteur suit le texte : une annonce de trois lignes ne doit pas etre
    -- coupee, et une de trois mots ne doit pas flotter dans le vide.
    local hauteur = 12 + policeTitre + 8 + math.max(police, a.texte:GetStringHeight() or police) + 14
    a:SetHeight(math.max(hauteur, icone ~= "" and 64 or 0))

    a.qui:SetText("— " .. (tostring(expediteur):match("^[^-]+") or tostring(expediteur)))
    a.reste = DUREE_ANNONCE
    a:SetAlpha(1)
    a:Show()
    return a
end

-- ===== Les branchements ====================================================

O.onChange = function()
    -- Le panneau du MJ (compagnon) s'accroche ici pour suivre SES outils.
    if O.onChangeMJ then O.onChangeMJ() end
    Ecran.Afficher()
end

O.onAnnonce = function(expediteur, annonce) Ecran.Annonce(expediteur, annonce) end

LCM.AddCommand("outils", "montre les outils partages par le MJ", function()
    local n = Ecran.Afficher()
    if n == 0 then LCM.Info("aucun outil partagé pour l'instant.") end
end)
