-- HUD du personnage LCM : remplace le portrait et les jauges Blizzard par
-- l'artwork du personnage, l'etat en pourcentage de chaque zone du corps, les
-- PV globaux et la fatigue.

local _, LCM = ...
local UI = LCM.UI

local Ecran = { pastilles = {} }
UI.HUD = Ecran

local DOSSIER_HUD = "Interface\\AddOns\\LesContesMalveillants\\ressources\\hud\\"
local LARGEUR, HAUTEUR = 650, 202
local PASTILLE, ECART = 72, 9
local ZONES_X, ZONES_Y = 190, -48
local CIBLE_L, CIBLE_H = 82, 112
local OR_ORBE = { 0.85, 0.67, 0.41 }

local ICONES = { tete = "tete", buste = "torse", bras = "bras",
    jambe = "jambes", internes = "internes", aile = "aile", queue = "queue" }

local function TextureHUD(parent, niveau, fichier, u, v)
    local texture = parent:CreateTexture(nil, niveau or "ARTWORK")
    texture:SetTexture(DOSSIER_HUD .. fichier .. ".tga")
    texture.u, texture.v = u or 1, v or 1
    texture:SetTexCoord(0, texture.u, 0, texture.v)
    return texture
end

local function Proportion(courant, maximum)
    return maximum > 0 and math.max(0, math.min(1, courant / maximum)) or 0
end

-- Decouper la texture, sans l'ecraser : le niveau descend vers le bas,
-- le fond noir apparait au-dessus et le cadre reste entier.
local function RemplirDisque(p, proportion)
    p.proportion = proportion
    p.remplissage:SetHeight(math.max(0.01, p.diametre * proportion))
    p.remplissage:SetTexCoord(0, 1, 1 - proportion, 1)
    p.remplissage:SetShown(proportion > 0)
end

local function Disque(p, diametre, fichier)
    p.diametre = diametre
    p.fond = TextureHUD(p, "BACKGROUND", "disque-noir-hd")
    p.fond:SetSize(diametre, diametre)
    p.fond:SetPoint("CENTER", p.orbe, "CENTER")
    p.fond:SetVertexColor(0.18, 0.18, 0.18)
    p.remplissage = TextureHUD(p, "ARTWORK", fichier)
    p.remplissage:SetWidth(diametre)
    p.remplissage:SetPoint("BOTTOM", p.fond, "BOTTOM")
end

local function MasquerPortraitBlizzard(masquer)
    if not PlayerFrame then return end
    -- PlayerFrame est protege en combat. Il est normalement deja cache avant
    -- l'engagement ; si Blizzard tente de le retablir, on attend la sortie de
    -- combat plutot que de provoquer une action bloquee.
    if InCombatLockdown and InCombatLockdown() then return end
    if masquer then
        if PlayerFrame:IsShown() then PlayerFrame:Hide() end
    elseif not PlayerFrame:IsShown() then
        PlayerFrame:Show()
    end
end

local function MasquerCibleBlizzard(masquer)
    if not TargetFrame then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if masquer then
        if TargetFrame:IsShown() then TargetFrame:Hide() end
    elseif UnitExists and UnitExists("target") and not TargetFrame:IsShown() then
        TargetFrame:Show()
    end
end

local function AffichageClassique()
    return LCM.db and LCM.db.settings
        and LCM.db.settings.affichageHUDClassique == true
end

-- Changer l'affichage de PlayerFrame en combat provoquerait une action
-- protegee. On retient donc le choix et on l'applique des la fin du combat.
function Ecran.ChoisirAffichage(classique)
    classique = classique == true
    if InCombatLockdown and InCombatLockdown() then
        Ecran.affichageEnAttente = classique
        if LCM.Alerte then
            LCM.Alerte("le changement de portrait sera appliqué à la fin du combat.")
        end
        return false
    end
    Ecran.affichageEnAttente = nil
    if LCM.EnsureDatabase then LCM.EnsureDatabase() end
    LCM.db.settings.affichageHUDClassique = classique or nil
    Ecran.Actualiser()
    return true
end

-- PlayerFrame porte deja les interactions securisees de Blizzard. Un hook
-- conserve donc son comportement normal et utilise simplement son clic droit
-- pour revenir au HUD LCM quand le portrait classique est affiche.
local function InstallerBasculeBlizzard()
    if Ecran.basculeBlizzardInstallee or not PlayerFrame then return end
    PlayerFrame:HookScript("OnClick", function(_, bouton)
        if bouton ~= "RightButton" or not AffichageClassique() then return end
        if CloseDropDownMenus then CloseDropDownMenus() end
        Ecran.ChoisirAffichage(false)
    end)
    Ecran.basculeBlizzardInstallee = true
end

local function MenuUnite(unite)
    local menu = unite == "player" and PlayerFrameDropDown or TargetFrameDropDown
    if not (menu and ToggleDropDownMenu) then return end
    if unite == "target" and not (UnitExists and UnitExists("target")) then return end
    -- Les menus sont initialises par Blizzard selon l'unite actuelle : on
    -- reutilise donc directement les cadres des portraits que le HUD cache.
    ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

local function Pastille(parent, index)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(PASTILLE, PASTILLE + 18)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT",
        ZONES_X + ((index - 1) % 5) * (PASTILLE + ECART),
        ZONES_Y - math.floor((index - 1) / 5) * 94)
    p.orbe = TextureHUD(p, "OVERLAY", "zone-anneau-hd")
    p.orbe:SetDesaturated(true)
    p.orbe:SetSize(PASTILLE, PASTILLE)
    p.orbe:SetPoint("TOP", p, "TOP", 0, 0)
    Disque(p, PASTILLE * 0.81, "zone-rouge-hd")
    p.icone = TextureHUD(p, "OVERLAY", "icone-tete-hd")
    p.icone:SetDrawLayer("OVERLAY", 1)
    p.icone:SetSize(32, 39)
    p.icone:SetPoint("CENTER", p.orbe, "CENTER", 0, 4)
    p.pourcent = UI.Texte(p, "", UI.C.texte)
    UI.Police(p.pourcent, 9, "OUTLINE")
    -- Une ligne symetrique sur toute l'orbe, legerement remontee sous l'icone.
    -- Le centrage porte sur le texte entier, y compris le signe pourcent.
    p.pourcent:SetHeight(12)
    p.pourcent:SetPoint("BOTTOMLEFT", p.orbe, "BOTTOMLEFT", 0, 12)
    p.pourcent:SetPoint("BOTTOMRIGHT", p.orbe, "BOTTOMRIGHT", 0, 12)
    p.pourcent:SetJustifyH("CENTER")
    p.pourcent:SetJustifyV("MIDDLE")
    p.pourcent:SetShadowOffset(0, 0)
    p.pourcent:SetWordWrap(false)
    p.nom = UI.Texte(p, "", UI.C.libelle)
    UI.Police(p.nom, 9)
    p.nom:SetPoint("TOPLEFT", p, "TOPLEFT", -3, -PASTILLE + 1)
    p.nom:SetPoint("TOPRIGHT", p, "TOPRIGHT", 3, -PASTILLE + 1)
    p.nom:SetJustifyH("CENTER")
    p.nom:SetWordWrap(false)
    UI.Bulle(p, function(soi) return soi.libelle end,
        function(soi) return string.format("%d / %d — %d %%", soi.courant, soi.maximum, soi.pct) end, 0.25)
    Ecran.pastilles[index] = p
    return p
end

local function OrbeTotal(parent)
    local p = CreateFrame("Button", nil, parent)
    p:SetSize(176, 176)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -13)
    p.orbe = TextureHUD(p, "OVERLAY", "pv-cadre-hd")
    p.orbe:SetAllPoints(p)
    Disque(p, 176 * 0.76, "pv-rouge-hd")
    p.valeur = UI.Texte(p, "", UI.C.texte)
    UI.Police(p.valeur, 25, "OUTLINE")
    p.valeur:SetPoint("CENTER", p, "CENTER", -19, 13)
    p.valeur:SetJustifyH("CENTER")
    p.separateurPV = UI.Texte(p, "/", UI.C.texte)
    UI.Police(p.separateurPV, 42, "OUTLINE")
    -- Même or chaud que les reflets du cadre de l'orbe.
    p.separateurPV:SetTextColor(OR_ORBE[1], OR_ORBE[2], OR_ORBE[3])
    p.separateurPV:SetPoint("CENTER", p, "CENTER", 0, 0)
    p.separateurPV:SetJustifyH("CENTER")
    p.maximumTexte = UI.Texte(p, "", UI.C.texte)
    UI.Police(p.maximumTexte, 25, "OUTLINE")
    p.maximumTexte:SetPoint("CENTER", p, "CENTER", 19, -13)
    p.maximumTexte:SetJustifyH("CENTER")
    p.pourcent = UI.Texte(p, "", UI.C.texte)
    p.pourcent:Hide()
    p.bouclier = CreateFrame("Frame", nil, p)
    p.bouclier:SetSize(71, 71)
    p.bouclier:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 6, -8)
    p.bouclier:SetFrameLevel(p:GetFrameLevel() + 10)
    p.bouclier:EnableMouse(true)
    p.bouclier:SetScript("OnMouseUp", function(_, bouton)
        if bouton == "RightButton" then Ecran.ChoisirAffichage(true) end
    end)
    p.bouclier.icone = p.bouclier:CreateTexture(nil, "ARTWORK")
    p.bouclier.icone:SetSize(70, 70)
    p.bouclier.icone:SetPoint("CENTER", p.bouclier, "CENTER", 0, 0)
    p.bouclier.icone:SetTexture("Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\generation_bouclier.tga")
    -- L'icone d'origine est très jaune. Désaturée puis teintée avec l'or de
    -- l'orbe, elle garde son relief sans jurer avec son contour.
    p.bouclier.icone:SetDesaturated(true)
    p.bouclier.icone:SetVertexColor(OR_ORBE[1], OR_ORBE[2], OR_ORBE[3])
    p.bouclier.valeur = UI.Texte(p.bouclier, "", UI.C.texte)
    UI.Police(p.bouclier.valeur, 20, "THICKOUTLINE")
    p.bouclier.valeur:SetTextColor(1, 0.92, 0.48)
    -- La boite reste assez large pour 100–999 : seule la glyphe est réduite,
    -- sinon WoW remplace les trois chiffres par des points de suspension.
    p.bouclier.valeur:SetSize(60, 26)
    -- La face utile du dessin est légèrement à droite et sous le centre de
    -- son carré transparent : on centre donc le nombre sur la face, pas sur
    -- les dimensions brutes de la texture.
    p.bouclier.valeur:SetPoint("CENTER", p.bouclier.icone, "CENTER", 3, 3)
    p.bouclier.valeur:SetJustifyH("CENTER")
    p.bouclier.valeur:SetJustifyV("MIDDLE")
    p.bouclier.valeur:SetWordWrap(false)
    p.bouclier:Hide()
    UI.Bulle(p.bouclier, "Bouclier ponctuel", function(soi)
        local courant = soi.bouclierCourant or 0
        return string.format("%d point%s de bouclier restant%s.",
            courant, courant == 1 and "" or "s", courant == 1 and "" or "s")
    end, 0.25)
    p:RegisterForClicks("RightButtonUp")
    p:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then Ecran.ChoisirAffichage(true) end
    end)
    UI.Bulle(p, "Points de vie totaux", function(soi)
        return string.format("%d / %d — %d %%\nClic droit : affichage classique de WoW.",
            soi.courant, soi.maximum, soi.pct)
    end, 0.25)
    return p
end

local function BarreFatigue(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(430, 48)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 186, -143)
    b.fond = TextureHUD(b, "BACKGROUND", "fatigue-cadre-hd")
    b.fond:SetSize(400, 27)
    b.fond:SetPoint("TOPLEFT", b, "TOPLEFT", 28, -2)
    b.remplissage = TextureHUD(b, "ARTWORK", "fatigue-or-hd")
    b.remplissage:SetPoint("TOPLEFT", b.fond, "TOPLEFT", 12, -5)
    b.remplissage:SetHeight(17)
    b.largeurRemplissage = 384
    b.fin = TextureHUD(b, "ARTWORK", "fatigue-or-hd")
    b.fin:SetHeight(17)
    -- Meme matiere que le corps de la jauge : seule la transparence de la
    -- pointe change, sans raccord de couleur entre deux images dorees.
    b.masqueFin = b:CreateMaskTexture(nil, "ARTWORK")
    b.masqueFin:SetTexture(DOSSIER_HUD .. "fatigue-fin-hd.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.masqueFin:SetAllPoints(b.fin)
    b.fin:AddMaskTexture(b.masqueFin)
    b.medaille = TextureHUD(b, "OVERLAY", "fatigue-medaille-hd")
    b.medaille:SetDrawLayer("OVERLAY", 0)
    b.medaille:SetSize(45, 45)
    b.medaille:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 7)
    b.icone = TextureHUD(b, "OVERLAY", "icone-fatigue-hd")
    -- Des textures au meme sous-niveau peuvent etre regroupees par le moteur.
    -- L'eclair doit toujours passer devant le fond opaque du medaillon.
    b.icone:SetDrawLayer("OVERLAY", 1)
    b.icone:SetSize(23, 30)
    b.icone:SetPoint("CENTER", b.medaille, "CENTER")
    -- Neutraliser l'or des textures avant la teinte bleue, en conservant
    -- leurs reliefs et reflets, y compris sur le medaillon et son eclair.
    for _, texture in ipairs({ b.fond, b.remplissage, b.fin, b.medaille, b.icone }) do
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.35, 0.68, 1)
    end
    b.label = UI.Texte(b, "", UI.C.texte)
    UI.Police(b.label, 11, "OUTLINE")
    b.label:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 1)
    b.titre = UI.Texte(b, "FATIGUE", UI.C.libelle)
    UI.Police(b.titre, 9)
    b.titre:SetPoint("BOTTOM", b, "BOTTOM", -10, 1)
    function b:Regler(courant, maximum)
        courant, maximum = tonumber(courant) or 0, tonumber(maximum) or 0
        local proportion = Proportion(courant, maximum)
        self.proportion = proportion
        local largeur = self.largeurRemplissage * proportion
        -- A pleine energie, remplissage entier. Des la premiere depense,
        -- une pointe en coups de pinceau accompagne le niveau vers la gauche.
        -- Elle est comprise dans la longueur restante, jamais ajoutee aux PF.
        local striee = proportion > 0 and proportion < 1
        local pointe = math.min(striee and 26 or 8.5, largeur)
        local corps = largeur - pointe
        self.finStriee = striee
        if striee then
            self.masqueFin:SetTexture(DOSSIER_HUD .. "fatigue-fin-hd.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            self.masqueFin:SetTexCoord(0, 1, 0, 1)
        else
            -- Pleine, la jauge epouse le bout arrondi de la piste noire.
            self.masqueFin:SetTexture(DOSSIER_HUD .. "disque-noir-hd.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            self.masqueFin:SetTexCoord(0.5, 1, 0, 1)
        end
        self.remplissage:SetWidth(math.max(0.01, corps))
        self.remplissage:SetTexCoord(0, self.remplissage.u * corps / self.largeurRemplissage,
            0, self.remplissage.v)
        self.remplissage:SetShown(corps > 0)
        self.fin:ClearAllPoints()
        self.fin:SetPoint("TOPLEFT", self.fond, "TOPLEFT", 12 + corps, -5)
        self.fin:SetWidth(math.max(0.01, pointe))
        self.fin:SetTexCoord(corps / self.largeurRemplissage, proportion, 0, self.fin.v)
        self.fin:SetShown(pointe > 0)
        self.largeurVisible = largeur
        self.label:SetText(string.format("%d / %d", courant, maximum))
    end
    return b
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_HUDPersonnage", UIParent)
    f:SetSize(LARGEUR, HAUTEUR)
    -- La composition source est tres detaillee : on la dessine a sa taille
    -- logique puis on la ramene a 72 % pour qu'elle remplace le portrait sans
    -- occuper tout le quart superieur de l'ecran.
    --
    -- `echellePropre` : « Taille de l'interface » ne me touche pas, j'ai mon
    -- curseur (UI.EchelleHUD). Sans ce marqueur, agrandir les fenetres pour
    -- les lire faisait mordre le bandeau sur les cadres de raid.
    f.echellePropre = true
    f:SetScale(UI.EchelleHUD and select(2, UI.EchelleHUD()) or 0.72)
    -- Au ras de l'angle : a dix-huit unites, son bas mordait sur les cadres de
    -- groupe, qui commencent juste en dessous.
    f.cle = "hud"
    f.defautPosition = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 4, y = -4 }
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 4, -4)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Sa place est RETENUE, comme celle de toutes les autres fenetres. Elle ne
    -- l'etait pas : on le poussait hors des cadres de groupe, et le /reload
    -- suivant le ramenait dessus. Ca ne se voyait pas, parce qu'on ne deplace
    -- un HUD qu'une fois.
    local function Retenir()
        f:StopMovingOrSizing()
        LCM.EnsureDatabase()
        LCM.db.fenetres = type(LCM.db.fenetres) == "table" and LCM.db.fenetres or {}
        local point, _, relPoint, x, y = f:GetPoint()
        LCM.db.fenetres.hud = { point = point, relPoint = relPoint, x = x, y = y }
    end
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", Retenir)
    f.Retenir = Retenir
    f.fond = TextureHUD(f, "BACKGROUND", "panneau-fondu")
    f.fond:SetAllPoints(f)
    f.separateurs = {}
    for i, y in ipairs({ -40, -138 }) do
        local ligne = TextureHUD(f, "BORDER", "separateur")
        ligne:SetSize(428, 1)
        ligne:SetPoint("TOPLEFT", f, "TOPLEFT", 187, y)
        f.separateurs[i] = ligne
    end
    f.nom = UI.Texte(f, "", UI.C.texte)
    UI.Police(f.nom, 16)
    f.nom:SetPoint("TOPLEFT", f, "TOPLEFT", ZONES_X + 6, -14)
    f.nom:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    f.nom:SetJustifyH("LEFT")
    f.nom:SetWordWrap(false)
    f.entete = CreateFrame("Button", nil, f)
    f.entete:SetPoint("TOPLEFT", f, "TOPLEFT", 186, -4)
    f.entete:SetSize(430, 35)
    f.entete:RegisterForClicks("RightButtonUp")
    f.entete:RegisterForDrag("LeftButton")
    f.entete:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then MenuUnite("player") end
    end)
    f.entete:SetScript("OnDragStart", function() f:StartMoving() end)
    f.entete:SetScript("OnDragStop", function() f.Retenir() end)
    f.total = OrbeTotal(f)
    InstallerBasculeBlizzard()
    f.fatigue = BarreFatigue(f)
    local capacite = 5
    for _, morphologie in ipairs(LCM.Morphologies.list) do
        capacite = math.max(capacite, #morphologie.parts)
    end
    for index = 1, capacite do Pastille(f, index):Hide() end

    -- Carte compacte de la cible : elle remplace TargetFrame seulement quand
    -- l'addon connait réellement l'artwork du personnage sélectionné.
    f.cible = CreateFrame("Frame", nil, f)
    f.cible:SetSize(CIBLE_L, CIBLE_H)
    f.cible:SetPoint("LEFT", f, "RIGHT", 7, 0)
    f.cible.fond = UI.Aplat(f.cible, UI.C.fond, "BACKGROUND")
    f.cible.fond:SetAllPoints(f.cible)
    if UI.AelCadre then f.cible.cadre = UI.AelCadre(f.cible, "icone")
    else UI.Bordure(f.cible) end
    f.cible.art = f.cible:CreateTexture(nil, "ARTWORK")
    f.cible.art:SetPoint("TOPLEFT", f.cible, "TOPLEFT", 4, -4)
    f.cible.art:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)

    -- La place retenue, s'il y en a une.
    LCM.EnsureDatabase()
    local memoire = LCM.db.fenetres and LCM.db.fenetres.hud
    if type(memoire) == "table" then
        f:ClearAllPoints()
        f:SetPoint(memoire.point or "TOPLEFT", UIParent, memoire.relPoint or "TOPLEFT",
            tonumber(memoire.x) or 4, tonumber(memoire.y) or -4)
    end
    -- Dans la liste des fenetres : « remettre les fenetres a leur place » doit
    -- pouvoir le ramener dans son angle quand il est parti hors de l'ecran.
    UI.fenetres[#UI.fenetres + 1] = f
    f.cible.modele = CreateFrame("PlayerModel", nil, f.cible)
    f.cible.modele:SetPoint("TOPLEFT", f.cible, "TOPLEFT", 4, -4)
    f.cible.modele:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)
    f.cible.modele:Hide()
    f.cible.nomFond = UI.Aplat(f.cible, { 0.02, 0.015, 0.01, 0.86 }, "OVERLAY")
    f.cible.nomFond:SetPoint("BOTTOMLEFT", f.cible, "BOTTOMLEFT", 4, 4)
    f.cible.nomFond:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)
    f.cible.nomFond:SetHeight(19)
    f.cible.nom = UI.Texte(f.cible, "", UI.C.titre)
    UI.Police(f.cible.nom, 9)
    f.cible.nom:SetPoint("BOTTOMLEFT", f.cible, "BOTTOMLEFT", 6, 7)
    f.cible.nom:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -6, 7)
    f.cible.nom:SetJustifyH("CENTER")
    f.cible.nom:SetWordWrap(false)
    f.cible.entete = CreateFrame("Button", nil, f.cible)
    f.cible.entete:SetPoint("BOTTOMLEFT", f.cible, "BOTTOMLEFT", 4, 4)
    f.cible.entete:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)
    f.cible.entete:SetHeight(19)
    f.cible.entete:RegisterForClicks("RightButtonUp")
    f.cible.entete:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then MenuUnite("target") end
    end)
    -- Le portrait compact cache TargetFrame, et avec lui les auras du jeu que
    -- Blizzard range dessous : ce bouton les rend (UI/Auras.lua).
    f.cible.aura = UI.Bouton(f.cible, "Aura", CIBLE_L, 22, function()
        if UI.Auras then UI.Auras.Basculer() end
    end)
    f.cible.aura:SetPoint("TOP", f.cible, "BOTTOM", 0, -4)
    f.cible:Hide()

    f:Hide()
    Ecran.frame = f
    return f
end

local function IdentiteCible()
    if not (UnitExists and UnitExists("target") and UnitName) then return nil end
    local nom, royaume = UnitName("target")
    if not nom then return nil end
    local joueur = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
    if UnitIsUnit and UnitIsUnit("target", "player") then
        local moi = LCM.Entities.Personnage and LCM.Entities.Personnage()
        return moi, joueur, nom
    end
    local entity = LCM.Fiches and LCM.Fiches.Recue and LCM.Fiches.Recue(joueur)
    if entity and LCM.Portraits.Of(entity) then return entity, joueur, nom end
    local portrait = LCM.Presence and LCM.Presence.Portrait and LCM.Presence.Portrait(joueur)
    local nomPersonnage = LCM.Presence and LCM.Presence.Personnage
        and LCM.Presence.Personnage(joueur)
    if not portrait and LCM.Presence and LCM.Presence.ParPersonnage then
        local joueurTrouve, presence = LCM.Presence.ParPersonnage(nom)
        if presence then
            joueur = joueurTrouve or joueur
            portrait = presence.portrait
            nomPersonnage = presence.personnage
        end
    end
    if portrait and LCM.Portraits.Get(portrait) then
        return {
            id = joueur,
            name = nomPersonnage or nom,
            values = { portrait = portrait },
        }, joueur, nom
    end
    -- Une cible sans fiche LCM reste une vraie cible : son modele 3D remplace
    -- le portrait Blizzard au lieu de laisser les deux interfaces cohabiter.
    return nil, joueur, nom
end

local function ActualiserCible(f)
    local entity, joueur, nomUnite = IdentiteCible()
    if not joueur then
        f.cible:Hide()
        f.cible.entity, f.cible.joueur = nil, nil
        MasquerCibleBlizzard(false)
        return
    end
    if entity and LCM.Portraits.Of(entity) then
        LCM.Portraits.Appliquer(f.cible.art, entity)
        f.cible.art:Show()
        f.cible.modele:Hide()
    else
        f.cible.art:Hide()
        f.cible.modele:Show()
        if f.cible.modele.ClearModel then f.cible.modele:ClearModel() end
        if f.cible.modele.SetUnit then pcall(f.cible.modele.SetUnit, f.cible.modele, "target") end
        if f.cible.modele.SetPortraitZoom then
            pcall(f.cible.modele.SetPortraitZoom, f.cible.modele, 0.72)
        end
        if f.cible.modele.SetAnimation then
            pcall(f.cible.modele.SetAnimation, f.cible.modele, 0)
        end
        -- Une présence ancienne peut ne pas encore contenir l'artwork. Le
        -- ping est temporisé par Presence lui-même ; sa réponse rappellera
        -- automatiquement Actualiser via Presence.Suivre.
        if LCM.Presence and LCM.Presence.Demander then LCM.Presence.Demander(false) end
    end
    local nom = entity and entity.name
        or (LCM.Presence and LCM.Presence.Personnage and LCM.Presence.Personnage(joueur))
        or nomUnite or joueur
    f.cible.nom:SetText(tostring(nom))
    f.cible.entity, f.cible.joueur = entity, joueur
    f.cible:Show()
    MasquerCibleBlizzard(true)
end

local function ReglerPastille(p, libelle, courant, maximum, categorie)
    courant, maximum = tonumber(courant) or 0, tonumber(maximum) or 0
    local pct = maximum > 0 and math.max(0, math.min(100, math.floor(courant * 100 / maximum + 0.5))) or 0
    p.libelle, p.courant, p.maximum, p.pct = libelle, courant, maximum, pct
    local proportion = Proportion(courant, maximum)
    RemplirDisque(p, proportion)
    -- L'anneau gris neutre est teinte en or a pleine sante, puis en charbon.
    local lumiere = 0.12 + 0.88 * proportion
    local orRestant = math.max(0, 2 * proportion - 1)
    p.orbe:SetVertexColor(lumiere, lumiere * (1 - 0.23 * orRestant),
        lumiere * (1 - 0.56 * orRestant))
    p.icone:SetTexture(DOSSIER_HUD .. "icone-" .. (ICONES[categorie] or "internes") .. "-hd.tga")
    p.pourcent:SetText(pct .. "%")
    local nom = tostring(libelle or "")
        :gsub("à", "À"):gsub("â", "Â"):gsub("ä", "Ä")
        :gsub("é", "É"):gsub("è", "È"):gsub("ê", "Ê"):gsub("ë", "Ë")
        :gsub("î", "Î"):gsub("ï", "Ï"):gsub("ô", "Ô"):gsub("ö", "Ö")
        :gsub("ù", "Ù"):gsub("û", "Û"):gsub("ü", "Ü"):gsub("ç", "Ç")
        :upper()
    p.nom:SetText(nom)
    p:Show()
end

function Ecran.Actualiser()
    local f = Ecran.frame or Construire()
    -- Le HUD suit celui qu'on joue, comme toutes les fiches : le PNJ incarne
    -- s'il y en a un. Il restait sur le personnage du MJ, et c'etait la seule
    -- fenetre a ne pas changer de corps (13 octobre 2026).
    local entity = LCM.Entities.Self()
    if not entity then
        f:Hide()
        f.cible:Hide()
        MasquerPortraitBlizzard(false)
        MasquerCibleBlizzard(false)
        return
    end

    if AffichageClassique() then
        f:Hide()
        f.cible:Hide()
        MasquerPortraitBlizzard(false)
        MasquerCibleBlizzard(false)
        return
    end

    MasquerPortraitBlizzard(true)
    f.nom:SetText(tostring(entity.name or entity.id))

    local etat = LCM.Body.State(entity)
    local totalCourant, totalMaximum = LCM.Body.Totals(entity)
    local supplement = math.max(0, math.ceil(#etat / 5) - 1) * 94
    f:SetHeight(HAUTEUR + supplement)
    f.fatigue:ClearAllPoints()
    f.fatigue:SetPoint("TOPLEFT", f, "TOPLEFT", 186, -143 - supplement)
    f.separateurs[2]:ClearAllPoints()
    f.separateurs[2]:SetPoint("TOPLEFT", f, "TOPLEFT", 187, -138 - supplement)

    for index, partie in ipairs(etat) do
        local p = Ecran.pastilles[index] or Pastille(f, index)
        ReglerPastille(p, partie.label, partie.current, partie.max, partie.part.category)
    end
    local total = f.total
    total.courant, total.maximum = tonumber(totalCourant) or 0, tonumber(totalMaximum) or 0
    total.pct = total.maximum > 0 and math.max(0,
        math.min(100, math.floor(total.courant * 100 / total.maximum + 0.5))) or 0
    total.valeur:SetText(tostring(total.courant))
    total.separateurPV:SetText("/")
    total.maximumTexte:SetText(tostring(total.maximum))
    total.pourcent:SetText(total.pct .. "%")
    RemplirDisque(total, Proportion(total.courant, total.maximum))
    total:Show()
    for index = #etat + 1, #Ecran.pastilles do
        Ecran.pastilles[index]:Hide()
    end

    local fatigue = LCM.Entities.Gauge(entity, "fatigue") or { current = 0, max = 0 }
    f.fatigue:Regler(fatigue.current, fatigue.max)
    local bouclier = LCM.Entities.Gauge(entity, "armure") or { current = 0, max = 0 }
    total.bouclierCourant = math.max(0, math.floor((tonumber(bouclier.current) or 0) + 0.5))
    total.bouclier.bouclierCourant = total.bouclierCourant
    total.bouclier.valeur:SetText(tostring(total.bouclierCourant))
    total.bouclier:SetShown(total.bouclierCourant > 0)
    f.entity, f.nombreZones = entity, #etat
    f:Show()
    ActualiserCible(f)
end

-- Les degats, soins et depenses de fatigue se voient immediatement.
LCM.Entities.Ecouter(function(entity)
    if entity == LCM.Entities.Self() then Ecran.Actualiser() end
end)
LCM.Entities.EcouterSoi(function() Ecran.Actualiser() end)

LCM.WhenReady(function()
    Ecran.Actualiser()
    local veille = CreateFrame("Frame")
    veille:RegisterEvent("PLAYER_ENTERING_WORLD")
    veille:RegisterEvent("PLAYER_ALIVE")
    veille:RegisterEvent("PLAYER_REGEN_ENABLED")
    veille:RegisterEvent("PLAYER_TARGET_CHANGED")
    veille:SetScript("OnEvent", function(_, evenement)
        if evenement == "PLAYER_REGEN_ENABLED" and Ecran.affichageEnAttente ~= nil then
            local classique = Ecran.affichageEnAttente
            Ecran.affichageEnAttente = nil
            Ecran.ChoisirAffichage(classique)
            return
        end
        Ecran.Actualiser()
    end)
    Ecran.veille = veille
    if LCM.Presence and LCM.Presence.Suivre then
        LCM.Presence.Suivre(function() Ecran.Actualiser() end)
    end
end)
