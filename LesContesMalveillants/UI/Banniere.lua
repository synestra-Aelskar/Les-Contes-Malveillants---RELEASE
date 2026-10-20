-- La banniere des Lieux : le nom de l'endroit, quand on y entre.
--
-- Porte de `UI_Banner.lua` du module Zone Gate d'Omega Hub (Akriaxx), avec ses
-- images et ses polices, reprises avec son accord. Le theme qui commande tout
-- est dans Core/Bannieres.lua ; ici, c'est le dessin.
--
-- Ce n'est pas un detournement du texte de zone de Blizzard : c'est une
-- fenetre a nous. Accrocher ZoneTextFrame casse d'une version du client a
-- l'autre, et on ne maitrise ni son rythme ni sa typographie.
--
-- Deux ecarts avec l'original, tous deux des simplifications :
--
--   * son groupe d'animation est ABANDONNE. Il etait cree, configure a chaque
--     theme... et jamais joue : c'est `Seek`, appele par le OnUpdate, qui fait
--     reellement l'alpha et les mouvements. Le garder aurait laisse croire
--     qu'il sert ;
--   * un franchissement qui arrive pendant une banniere la RELANCE avec le
--     nouveau texte, sans file d'attente — comme l'original. Entrer dans un
--     cercle par une porte annonce donc la porte, pas les deux a la suite.
--
-- `UI.Banniere.Creer` rend un afficheur autonome : l'atelier s'en sert pour
-- son apercu, avec exactement le meme code que la vraie banniere. Un apercu
-- qui ment ne sert a rien.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Banniere = Ecran

local B = LCM.Bannieres

-- Le cadre orne : un seul coin, retourne quatre fois.
local CADRE_RETRAIT, CADRE_COIN, CADRE_TRAIT = 6, 26, 2

-- Les compositions « paysage » reservent leurs bords aux arbres et aux
-- reliefs : le texte doit rester au milieu, donc la banniere s'elargit plus
-- vite. Les autres se contentent de moins.
local ETROITES = {
    souls = true, western = true, sumi = true, scifi = true,
    deco = true, minimal = true,
}
-- La part de la hauteur de l'image ou le texte a le droit de se poser.
local HAUTEUR_UTILE = {
    deco = 0.48, sumi = 0.50, western = 0.54, souls = 0.56,
    scifi = 0.70, minimal = 0.56,
}

local function CoinTexCoord(mirroirH, mirroirV)
    local x0, x1, y0, y1 = 0, 1, 0, 1
    if mirroirH then x0, x1 = 1, 0 end
    if mirroirV then y0, y1 = 1, 0 end
    return x0, y0, x0, y1, x1, y0, x1, y1
end

-- Cree un afficheur. `nomCadre` non nil = la vraie banniere : elle se place
-- toute seule a l'ecran et se met a l'echelle. L'apercu de l'atelier, lui,
-- reste dans sa boite.
function Ecran.Creer(parent, nomCadre, vraie)
    local b = CreateFrame("Frame", nomCadre, parent or UIParent)
    b:SetSize(600, 90)
    b:SetPoint("TOP", UIParent, "TOP", 0, -140)
    b:SetFrameStrata("HIGH")
    b:EnableMouse(false)
    b:SetAlpha(0)
    b:Hide()

    -- Le bandeau de fond : une image de degrade teintee, et non
    -- `SetGradient` — cette API manque sur certains clients, et le bandeau
    -- restait alors invisible sans la moindre erreur (constat d'Akriaxx).
    local fond = b:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(B.DEGRADE)
    fond:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -2)
    fond:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 2)
    fond:Hide()

    -- Les compositions sont chargees a la demande : quarante-deux images d'un
    -- mega-octet, on ne les met pas toutes en memoire pour en montrer une.
    local compositions = {}
    local function Composition(id)
        local chemin = B.Image(id)
        if not chemin then return nil end
        if compositions[id] then return compositions[id] end
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(chemin)
        t:SetPoint("CENTER")
        t:Hide()
        compositions[id] = t
        return t
    end

    -- ----- le cadre --------------------------------------------------------
    local traits = {}
    for _, cote in ipairs({ "haut", "bas", "gauche", "droite" }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        if cote == "haut" or cote == "bas" then t:SetHeight(CADRE_TRAIT) else t:SetWidth(CADRE_TRAIT) end
        t:Hide()
        traits[cote] = t
    end

    local coins = {}
    local function Coin(mirroirH, mirroirV, point, dx, dy)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetTexture(B.CADRE_COIN)
        t:SetSize(CADRE_COIN, CADRE_COIN)
        t:SetTexCoord(CoinTexCoord(mirroirH, mirroirV))
        t:SetPoint(point, b, point, dx, dy)
        t:Hide()
        coins[#coins + 1] = t
    end
    Coin(false, false, "TOPLEFT", CADRE_RETRAIT, -CADRE_RETRAIT)
    Coin(true, false, "TOPRIGHT", -CADRE_RETRAIT, -CADRE_RETRAIT)
    Coin(false, true, "BOTTOMLEFT", CADRE_RETRAIT, CADRE_RETRAIT)
    Coin(true, true, "BOTTOMRIGHT", -CADRE_RETRAIT, CADRE_RETRAIT)

    -- `creux` vaut la largeur d'un coin en style orne (les traits s'arretent
    -- avant lui), zero en style simple (ils vont d'un bout a l'autre).
    local function PoserTraits(creux)
        traits.haut:ClearAllPoints()
        traits.haut:SetPoint("TOPLEFT", b, "TOPLEFT", CADRE_RETRAIT + creux, -CADRE_RETRAIT)
        traits.haut:SetPoint("TOPRIGHT", b, "TOPRIGHT", -CADRE_RETRAIT - creux, -CADRE_RETRAIT)
        traits.bas:ClearAllPoints()
        traits.bas:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", CADRE_RETRAIT + creux, CADRE_RETRAIT)
        traits.bas:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -CADRE_RETRAIT - creux, CADRE_RETRAIT)
        traits.gauche:ClearAllPoints()
        traits.gauche:SetPoint("TOPLEFT", b, "TOPLEFT", CADRE_RETRAIT, -CADRE_RETRAIT - creux)
        traits.gauche:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", CADRE_RETRAIT, CADRE_RETRAIT + creux)
        traits.droite:ClearAllPoints()
        traits.droite:SetPoint("TOPRIGHT", b, "TOPRIGHT", -CADRE_RETRAIT, -CADRE_RETRAIT - creux)
        traits.droite:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -CADRE_RETRAIT, CADRE_RETRAIT + creux)
    end

    -- ----- les filets et le texte ------------------------------------------
    local filetHaut = b:CreateTexture(nil, "ARTWORK")
    filetHaut:SetPoint("TOP", b, "TOP", 0, -6)
    filetHaut:SetSize(360, 1)
    local filetHaut2 = b:CreateTexture(nil, "ARTWORK")
    filetHaut2:SetPoint("TOP", filetHaut, "BOTTOM", 0, -2)
    filetHaut2:SetSize(360, 1)

    local titre = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titre:SetPoint("TOP", filetHaut, "BOTTOM", 0, -10)

    local filetMilieu = b:CreateTexture(nil, "ARTWORK")
    filetMilieu:SetPoint("TOP", titre, "BOTTOM", 0, -6)
    filetMilieu:SetSize(240, 1)
    filetMilieu:Hide()

    local sous = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sous:SetPoint("TOP", filetMilieu, "BOTTOM", 0, -6)

    local filetBas = b:CreateTexture(nil, "ARTWORK")
    filetBas:SetPoint("TOP", sous, "BOTTOM", 0, -10)
    filetBas:SetSize(360, 1)
    local filetBas2 = b:CreateTexture(nil, "ARTWORK")
    filetBas2:SetPoint("TOP", filetBas, "BOTTOM", 0, -2)
    filetBas2:SetSize(360, 1)

    local POLICE_REPLI = titre:GetFont() or "Fonts\\FRIZQT__.TTF"

    -- ----- appliquer un theme ----------------------------------------------
    local function Appliquer(theme)
        theme = theme or B.DEFAUT
        local largeur = math.max(400, math.min(900, tonumber(B.Valeur(theme, "largeur")) or 600))
        local image = Composition(B.Valeur(theme, "composition"))
        b:SetSize(largeur, image and 150 or 90)
        b.image, b.largeurBase = image, largeur
        for _, t in pairs(compositions) do t:Hide() end

        local fondActif = B.Valeur(theme, "fondActif") and true or false
        local couleurFond = B.Valeur(theme, "couleurFond")
        if image then
            image:SetSize(largeur, 150)
            image:SetVertexColor(couleurFond[1], couleurFond[2], couleurFond[3], couleurFond[4] or 0.55)
            -- Une composition se montre meme sans « fond » coche : c'est elle
            -- qu'on est alle choisir. Le fond ne commande que son bandeau.
            image:Show()
        end
        for _, t in ipairs({ filetHaut, filetHaut2, filetBas, filetBas2 }) do t:SetWidth(largeur * 0.6) end

        local chemin = B.CheminPolice(theme) or POLICE_REPLI
        local drapeaux = B.Valeur(theme, "contour") and "OUTLINE" or ""
        local taille = tonumber(B.Valeur(theme, "taille")) or 28
        if titre.SetFont and not titre:SetFont(chemin, taille, drapeaux) then
            titre:SetFont(POLICE_REPLI, taille, drapeaux)
        end
        local petite = math.max(12, taille - 10)
        if sous.SetFont and not sous:SetFont(chemin, petite, drapeaux) then
            sous:SetFont(POLICE_REPLI, petite, drapeaux)
        end

        local ct = B.Valeur(theme, "couleurTitre")
        titre:SetTextColor(ct[1], ct[2], ct[3], 1)
        local cs = B.Valeur(theme, "couleurSous")
        sous:SetTextColor(cs[1], cs[2], cs[3], 1)

        local cf = B.Valeur(theme, "couleurFilet")
        local separateur = B.Valeur(theme, "separateur")
        local visible, double = separateur ~= "aucun", separateur == "double"
        for _, t in ipairs({ filetHaut, filetBas }) do
            t:SetColorTexture(cf[1], cf[2], cf[3], cf[4] or 1)
        end
        filetHaut:SetShown(visible)
        filetBas:SetShown(visible)
        filetHaut2:SetShown(visible and double)
        filetBas2:SetShown(visible and double)
        if double then
            for _, t in ipairs({ filetHaut2, filetBas2 }) do
                t:SetColorTexture(cf[1], cf[2], cf[3], (cf[4] or 1) * 0.6)
            end
        end
        filetMilieu:SetColorTexture(cf[1], cf[2], cf[3], cf[4] or 1)

        -- Le bandeau de degrade ne sert que SANS composition : sous une image,
        -- il ne ferait que la salir.
        fond:SetShown(fondActif and not image)
        if fondActif then
            fond:SetVertexColor(couleurFond[1], couleurFond[2], couleurFond[3], couleurFond[4] or 0.55)
        end

        local cadre = B.Valeur(theme, "cadre")
        local orne = cadre == "orne"
        PoserTraits(orne and CADRE_COIN or 0)
        local cc = B.Valeur(theme, "couleurCadre")
        for _, t in pairs(traits) do
            t:SetColorTexture(cc[1], cc[2], cc[3], cc[4] or 1)
            t:SetShown(cadre ~= "aucun")
        end
        for _, t in ipairs(coins) do
            t:SetVertexColor(cc[1], cc[2], cc[3], cc[4] or 1)
            t:SetShown(orne)
        end
    end

    -- ----- composer la banniere --------------------------------------------
    function b:Composer(nomLieu, nomSeuil, theme)
        if not nomLieu or nomLieu == "" then return end
        theme = theme or B.DEFAUT
        self:SetScript("OnUpdate", nil)
        Appliquer(theme)

        titre:SetText(B.StyleTexte(nomLieu, theme))
        local aSous = nomSeuil ~= nil and nomSeuil ~= ""
        sous:SetText(aSous and B.StyleTexte(nomSeuil, theme) or "")
        sous:SetShown(aSous)
        self.theme = theme

        -- La largeur suit le texte, une fois la police posee : la largeur du
        -- theme n'est qu'un plancher. Une composition paysage demande plus de
        -- marge, ses bords etant occupes par le decor.
        local composition = B.Valeur(theme, "composition")
        local largeurTexte = math.max(titre:GetStringWidth() or 0, sous:GetStringWidth() or 0)
        local sobre = type(composition) == "string" and composition:match("^quiet_")
        local paysage = self.image and not sobre and not ETROITES[composition]
        local largeur = math.max(self.largeurBase or 600,
            math.ceil((largeurTexte + 48) / (paysage and 0.52 or 0.78)))
        self.largeurBase = largeur
        self:SetWidth(largeur)
        if self.image then self.image:SetWidth(largeur) end
        for _, t in ipairs({ filetHaut, filetHaut2, filetBas, filetBas2 }) do
            t:SetWidth(largeur * 0.78)
        end

        local avecFilet = B.Valeur(theme, "filetMilieu") and true or false
        local ecart = avecFilet and 20 or 12
        local hauteurBloc = (titre:GetStringHeight() or 0)
            + (aSous and (ecart + (sous:GetStringHeight() or 0)) or 0)
        local part = HAUTEUR_UTILE[composition] or ((paysage or sobre) and 0.56 or 0.80)
        local hauteur = math.max(self.image and 150 or 90, math.ceil((hauteurBloc + 24) / part))
        self.hauteurBase = hauteur
        self.hautTexte = hauteurBloc / 2
        self:SetHeight(hauteur)
        if self.image then self.image:SetSize(largeur, hauteur) end

        titre:ClearAllPoints()
        titre:SetPoint("TOP", self, "CENTER", 0, self.hautTexte)
        sous:ClearAllPoints()
        sous:SetPoint("TOP", titre, "BOTTOM", 0, -ecart)
        filetMilieu:ClearAllPoints()
        filetMilieu:SetPoint("TOP", titre, "BOTTOM", 0, -ecart / 2)
        filetMilieu:SetWidth(largeur * 0.55)
        filetMilieu:SetShown(aSous and avecFilet)
        filetHaut:ClearAllPoints()
        filetHaut:SetPoint("BOTTOM", titre, "TOP", 0, 10)
        filetBas:ClearAllPoints()
        filetBas:SetPoint("TOP", aSous and sous or titre, "BOTTOM", 0, -10)

        -- La vraie banniere se retrecit pour tenir a l'ecran, en comptant le
        -- moment le plus large du mouvement de frappe.
        if vraie and UIParent and UIParent.GetWidth then
            local pointe = (B.Valeur(theme, "mouvement") == "frappe") and 1.15 or 1
            self:SetScale(math.min(1,
                math.max(1, (UIParent:GetWidth() or 1024) - 48) / (largeur * pointe),
                math.max(1, (UIParent:GetHeight() or 768) - 320) / hauteur))
        end
        return self
    end

    -- Ou en est la banniere a `secondes` de son debut. Rend la duree totale.
    -- C'est ici que vit toute l'animation : alpha, montee, frappe, ouverture.
    function b:Chercher(secondes)
        local theme = self.theme or B.DEFAUT
        local entree = math.max(0.05, tonumber(B.Valeur(theme, "apparition")) or 0.4)
        local reste = math.max(0, tonumber(B.Valeur(theme, "maintien")) or 2.5)
        local sortie = math.max(0.05, tonumber(B.Valeur(theme, "disparition")) or 0.8)
        local t = math.max(0, secondes or entree)

        local alpha
        if t < entree then alpha = t / entree
        elseif t < entree + reste then alpha = 1
        else alpha = math.max(0, 1 - (t - entree - reste) / sortie) end

        local avancement = math.min(1, t / entree)
        local adouci = 1 - (1 - avancement) ^ 3
        local mouvement = B.Valeur(theme, "mouvement")
        local decalage = 0
        if mouvement == "montee" then decalage = (1 - adouci) * -22
        elseif mouvement == "frappe" then decalage = (1 - adouci) * 12 end
        titre:ClearAllPoints()
        titre:SetPoint("TOP", self, "CENTER", 0, (self.hautTexte or 0) + decalage)

        if self.image then
            local facteur = 1
            if mouvement == "ouverture" then facteur = 0.2 + 0.8 * adouci
            elseif mouvement == "frappe" then facteur = 1 + 0.15 * (1 - adouci) end
            self.image:SetSize((self.largeurBase or 600) * facteur, self.hauteurBase or 150)
        end

        self:SetAlpha(alpha)
        self:Show()
        return entree + reste + sortie
    end

    function b:Montrer(nomLieu, nomSeuil, theme)
        if not nomLieu or nomLieu == "" then return end
        self:Composer(nomLieu, nomSeuil, theme)
        self:SetAlpha(0)
        self:Show()
        if vraie then
            self:ClearAllPoints()
            local ou = B.Valeur(theme or B.DEFAUT, "placement")
            if ou == "centre" then self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            elseif ou == "bas" then self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)
            else self:SetPoint("TOP", UIParent, "TOP", 0, -140) end
        end
        local ecoule = 0
        self:SetScript("OnUpdate", function(_, dt)
            ecoule = ecoule + (tonumber(dt) or 0)
            local total = self:Chercher(ecoule)
            if ecoule >= total then self:Cacher() end
        end)
        return self
    end

    function b:Cacher()
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(0)
        self:Hide()
    end

    return b
end

function Ecran.Fenetre()
    if not Ecran.frame then
        Ecran.frame = Ecran.Creer(UIParent, "LCM_Banniere", true)
    end
    return Ecran.frame
end

function Ecran.Montrer(titre, sous, theme)
    return Ecran.Fenetre():Montrer(titre, sous, theme)
end

-- Le franchissement, vu d'ici (Core/Lieux.lua appelle onFranchir).
--
-- Entrer et sortir donnent la MEME banniere chez Zone Gate, et on ne sait donc
-- pas de quel cote on vient de passer. Ici le sous-titre le dit : on nomme le
-- seuil en entrant, on dit qu'on le repasse en sortant.
LCM.Lieux.onFranchir = function(titre, sous, lieu, seuil, sens)
    local ligne = tostring(sous or "")
    if sens == "retour" and ligne ~= "" then
        ligne = "en repassant " .. ligne
    end
    local theme = LCM.Bannieres.Resoudre(seuil, lieu)
    Ecran.Montrer(titre, ligne, theme)
    LCM.Bannieres.Jouer(theme, sens)
end
