-- Le bandeau de combat, et l'invitation a y entrer.
--
-- Mise en page reprise de l'habillage de Necronicon (InitiativeSkin.lua) : un
-- bandeau de 1574 x 142 unites affiche a 70 %, seize cases, le compteur
-- Tour / Round a gauche, « Passer le tour » a droite, « C'est votre tour »
-- dessous. Les deux textures (ressources\combat\) sont celles de Necronicon :
-- combat-strip.tga (4096 x 1024) pour le decor, reference-atlas.tga
-- (2048 x 512) pour les cases, le cadre actif, la fleche et les losanges.
-- Necronicon gardait en plus une presentation « sans skin » ; ici il n'y en a
-- qu'une, l'habillee.
--
-- Le bandeau ne decide rien : il montre LCM.Combat et lui renvoie le clic.

local _, LCM = ...
local UI = LCM.UI
local GameTooltip = UI.Infobulle()

local Ecran = {}
UI.Combat = Ecran

local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\combat\\"
local LARGEUR, HAUTEUR, CASES = 1574, 142, 16
-- Ce que les seize cases ajoutent au decor d'origine (prevu pour huit) : les
-- deux portions unies du rail s'allongent d'autant, le reste garde sa taille.
local EXTRA = 474
local RANGEE = 1259
local CASE, PAS, RANGEE_X, RANGEE_Y = 74, 79, 151, 61
-- La ligne doree qui borde les combattants est a 44 unites du haut : c'est
-- elle qu'on pose au bord de l'ecran, les ornements au-dessus peuvent sortir.
local RAIL_HAUT = 44
local ECHELLE = 0.70
local MAX_ETATS_HUD = 13
local LARGEUR_RESSOURCES = 410
-- Les quatre bords du cadre actif, pris separement dans l'atlas : le portrait
-- de la capture d'origine ne doit jamais apparaitre en jeu.
local BORDS = { { 0, 0, 92, 7 }, { 0, 83, 92, 7 }, { 0, 7, 7, 76 }, { 85, 7, 7, 76 } }

local function Placer(region, parent, x, y, l, h)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    region:SetSize(l, h)
end

local function Atlas(parent, couche, x, y, l, h)
    local t = parent:CreateTexture(nil, couche)
    t:SetTexture(ART .. "reference-atlas.tga")
    t:SetTexCoord(x / 2048, (x + l) / 2048, y / 512, (y + h) / 512)
    return t
end

local function CadreActif(parent, l, h)
    local cadre = CreateFrame("Frame", nil, parent)
    cadre:SetAllPoints(parent)
    cadre:SetFrameLevel(parent:GetFrameLevel() + 2)
    for _, b in ipairs(BORDS) do
        local t = Atlas(cadre, "OVERLAY", 217 + b[1], 69 + b[2], b[3], b[4])
        Placer(t, cadre, b[1] * l / 92, b[2] * h / 90, b[3] * l / 92, b[4] * h / 90)
    end
    return cadre
end

-- CE QU'ON JOUE, pas qui l'on est : le MJ qui incarne un PNJ doit voir les
-- ressources du PNJ sous le bandeau. `Self()` sait deja tout cela — il demande
-- l'incarnation, puis le personnage actif. Demander `Personnages.Actif()`
-- d'abord, comme ici, court-circuitait l'incarnation : elle ne passait jamais
-- (11 octobre 2026).
local function MaFiche()
    return LCM.Entities and LCM.Entities.Self and LCM.Entities.Self() or nil
end

-- Trois gemmes de meme silhouette : rubis, rubis/obsidienne, obsidienne.
local GEMMES_PA = {
    disponible = "Interface\\AddOns\\LesContesMalveillants\\ressources\\combat\\pa\\disponible.tga",
    bloque = "Interface\\AddOns\\LesContesMalveillants\\ressources\\combat\\pa\\bloque.tga",
    depense = "Interface\\AddOns\\LesContesMalveillants\\ressources\\combat\\pa\\depense.tga",
}
local function PastillePA(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(24, 24)
    p.gemme = p:CreateTexture(nil, "ARTWORK")
    p.gemme:SetAllPoints(p)
    function p:Regler(etat)
        self.etat = etat
        self.remplie = etat == "disponible"
        self.gemme:SetTexture(GEMMES_PA[etat] or GEMMES_PA.depense)
    end
    p:Regler("depense")
    return p
end

local LIBELLES_ETATS = {
    etat = "État",
    maladie = "Maladie",
    intangible = "État intangible",
}

local function EffetsEtat(etat)
    local effets = {}
    for champ, valeur in pairs(etat.bonus or {}) do
        local field = LCM.Schema.Field(champ)
        effets[#effets + 1] = string.format("%s %+g", field and field.label or champ, valeur)
    end
    table.sort(effets)
    return table.concat(effets, ", ")
end

-- Le bandeau rassemble les états posés par une action et ceux que le MJ a
-- placés durablement sur la fiche. Ce sont deux stockages différents dans la
-- fenêtre Santé, mais pour le joueur ils répondent à la même question :
-- « qu'est-ce qui m'affecte maintenant ? ».
local function EtatsDe(entity)
    local out = {}
    if not entity then return out end
    for _, etat in ipairs(LCM.EtatsTemporaires.Liste(entity)) do
        out[#out + 1] = {
            nom = etat.nom,
            icone = etat.icone,
            description = etat.description,
            bonus = etat.bonus,
            categorie = etat.conteneur or "etat",
            restant = etat.restant,
            duree = LCM.EtatsTemporaires.Duree(etat),
            debuff = etat.debuff,
        }
    end
    for _, etat in ipairs(LCM.Etats.Portes(entity)) do
        out[#out + 1] = {
            nom = etat.label,
            icone = etat.icone,
            description = etat.description,
            bonus = etat.bonus,
            categorie = etat.categorie or "etat",
            debuff = etat.categorie == "maladie",
        }
    end
    return out
end

local function MontrerBulleEtat(cadre)
    local etat = cadre.etat
    if not (GameTooltip and etat) then return end
    GameTooltip:SetOwner(cadre, "ANCHOR_BOTTOM")
    GameTooltip:ClearLines()
    if etat.resume then
        GameTooltip:SetText(string.format("%d autres états", #etat.caches))
        for _, cache in ipairs(etat.caches) do
            GameTooltip:AddLine(cache.nom, cache.debuff and 1 or 0.94,
                cache.debuff and 0.28 or 0.82, cache.debuff and 0.20 or 0.55)
        end
    else
        GameTooltip:SetText(etat.nom or "État")
        GameTooltip:AddLine(LIBELLES_ETATS[etat.categorie] or "État",
            etat.debuff and 1 or 0.94, etat.debuff and 0.28 or 0.82,
            etat.debuff and 0.20 or 0.55)
        if etat.description and etat.description ~= "" then
            GameTooltip:AddLine(etat.description, 0.82, 0.79, 0.72, true)
        end
        local effets = EffetsEtat(etat)
        if effets ~= "" then GameTooltip:AddLine(effets, 0.95, 0.72, 0.32, true) end
        if etat.duree then GameTooltip:AddLine("Durée : " .. etat.duree, 1, 0.32, 0.25) end
    end
    GameTooltip:Show()
end

-- Les combattants a montrer, au plus seize. Celui qui joue reste toujours
-- visible : s'il sort de la page, il prend la premiere case
-- (BuildVisibleInitiativeEntries de Necronicon).
function Ecran.Visibles(entrees, courant, debut)
    local total = #entrees
    local visibles = {}
    if total == 0 then return visibles, 1 end
    debut = math.min(math.max(1, debut or 1), math.max(1, total - CASES + 1))
    local fin = math.min(total, debut + CASES - 1)
    if courant >= debut and courant <= fin then
        for index = debut, fin do visibles[#visibles + 1] = index end
        return visibles, debut
    end
    visibles[1] = courant
    for index = debut, fin do
        if #visibles >= CASES then break end
        if index ~= courant then visibles[#visibles + 1] = index end
    end
    return visibles, debut
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Combat", UIParent)
    Ecran.frame = f
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    -- Deplace a la main, le bandeau garde sa place jusqu'au /reload.
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() self.deplace = true end)
    f.debut = 1

    -- Le decor, en cinq morceaux : bougies, panneaux et ornement central a
    -- leur taille, les deux portions de rail allongees de EXTRA / 2 chacune.
    f.decor = {}
    local x = 0
    for _, morceau in ipairs({ { 0, 180, 0 }, { 180, 440, EXTRA / 2 }, { 440, 660, 0 },
                               { 660, 920, EXTRA / 2 }, { 920, 1100, 0 } }) do
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        t:SetTexture(ART .. "combat-strip.tga")
        t:SetTexCoord(morceau[1] / 1100 * 2172 / 4096, morceau[2] / 1100 * 2172 / 4096, 80 / 1024, 580 / 1024)
        local l = morceau[2] - morceau[1] + morceau[3]
        Placer(t, f, x, 0, l, 1100 * 500 / 2172)
        x = x + l
        f.decor[#f.decor + 1] = t
    end

    -- Le compteur, a gauche.
    f.tourLibelle = UI.Texte(f, "TOUR", UI.C.titre, "GameFontNormalSmall")
    f.tourLibelle:SetJustifyH("CENTER")
    Placer(f.tourLibelle, f, 47, 61, 82, 15)
    f.tour = UI.Texte(f, "01", UI.C.titre)
    f.tour:SetJustifyH("CENTER")
    UI.Police(f.tour, 25)
    Placer(f.tour, f, 47, 75, 82, 27)
    f.round = UI.Texte(f, "", { 0.80, 0.70, 0.51 }, "GameFontNormalSmall")
    f.round:SetJustifyH("CENTER")
    Placer(f.round, f, 47, 102, 82, 14)

    -- La rangee : seize emplacements vides, et seize cartes posees dessus.
    f.rangee = CreateFrame("Frame", nil, f)
    Placer(f.rangee, f, RANGEE_X, RANGEE_Y, RANGEE, CASE)
    f.vides, f.cartes = {}, {}
    for index = 1, CASES do
        local vide = Atlas(f.rangee, "BACKGROUND", 318, 71, 90, 85)
        Placer(vide, f.rangee, (index - 1) * PAS, 0, CASE, CASE)
        f.vides[index] = vide

        local carte = CreateFrame("Frame", nil, f.rangee)
        Placer(carte, f.rangee, (index - 1) * PAS, 0, CASE, CASE)
        carte:EnableMouse(true)
        carte.fond = Atlas(carte, "BACKGROUND", 318, 71, 90, 85)
        carte.fond:SetAllPoints(carte)
        carte.icone = carte:CreateTexture(nil, "ARTWORK")
        Placer(carte.icone, carte, 7, 7, 60, 60)
        -- KO : le portrait reste reconnaissable sous un voile rouge, tandis
        -- qu'un crane noir translucide donne l'information sans texte.
        carte.koRouge = UI.Aplat(carte, { 0.78, 0.02, 0.02, 0.48 }, "OVERLAY")
        Placer(carte.koRouge, carte, 7, 7, 60, 60)
        carte.koCrane = carte:CreateTexture(nil, "OVERLAY", nil, 3)
        carte.koCrane:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        carte.koCrane:SetVertexColor(0, 0, 0)
        carte.koCrane:SetAlpha(0.68)
        Placer(carte.koCrane, carte, 23, 23, 28, 28)
        carte.koRouge:Hide()
        carte.koCrane:Hide()
        carte.actif = CadreActif(carte, CASE, CASE)
        -- Le nom et l'initiative au survol, comme dans Necronicon : seize noms
        -- sous seize portraits ne tiendraient pas.
        carte:SetScript("OnEnter", function(self)
            if not self.entree then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.entree.nom)
            GameTooltip:AddLine("Initiative : " .. tostring(self.entree.v), 0.85, 0.76, 0.57)
            if self.entree.ko then GameTooltip:AddLine("Inconscient", 1, 0.16, 0.16) end
            GameTooltip:Show()
        end)
        carte:SetScript("OnLeave", function() GameTooltip:Hide() end)
        carte:Hide()
        f.cartes[index] = carte
    end

    -- La fleche au-dessus de celui qui joue, les losanges dessous.
    f.fleche = Atlas(f, "OVERLAY", 250, 51, 25, 17)
    f.losanges = Atlas(f, "OVERLAY", 229, 163, 67, 19)

    -- Au-dela de seize combattants, on tourne les pages.
    f.precedent = UI.Bouton(f, "<", 16, 25, function()
        f.debut = math.max(1, f.debut - CASES)
        Ecran.Rafraichir()
    end)
    Placer(f.precedent, f, 132, 84, 16, 25)
    f.suivant = UI.Bouton(f, ">", 16, 25, function()
        f.debut = f.debut + CASES
        Ecran.Rafraichir()
    end)
    Placer(f.suivant, f, 940 + EXTRA, 84, 16, 25)

    -- « Passer le tour », seule action du panneau de droite.
    f.passer = CreateFrame("Button", nil, f)
    Placer(f.passer, f, 970 + EXTRA, 65, 82, 46)
    f.passer.label = UI.Texte(f.passer, "Passer\nle tour", UI.C.titre)
    f.passer.label:SetAllPoints(f.passer)
    f.passer.label:SetJustifyH("CENTER")
    for _, b in ipairs(BORDS) do
        local t = Atlas(f.passer, "BORDER", 217 + b[1], 69 + b[2], b[3], b[4])
        Placer(t, f.passer, b[1] * 82 / 92, b[2] * 46 / 90, b[3] * 82 / 92, b[4] * 46 / 90)
        t:SetAlpha(0.65)
    end
    f.passer.survol = UI.Aplat(f.passer, { 0.8, 0.61, 0.28, 0.12 }, "HIGHLIGHT")
    f.passer.survol:SetAllPoints(f.passer)
    f.passer:SetScript("OnClick", function()
        local ok, raison = LCM.Combat.Passer()
        if not ok and raison then LCM.Alerte(raison) end
    end)

    f.avis = UI.Texte(f, "C'est votre tour", { 0.94, 0.83, 0.60 }, "GameFontNormalSmall")
    f.avis:SetJustifyH("CENTER")
    Placer(f.avis, f, 430 + EXTRA / 2, 201, 240, 18)

    -- Les ressources personnelles restent sous les extremites du rail afin de
    -- ne jamais concurrencer l'ordre d'initiative ni l'avis central.
    f.ressourcesPA = CreateFrame("Frame", nil, f)
    Placer(f.ressourcesPA, f, 170, 158, LARGEUR_RESSOURCES, 30)
    f.ressourcesPA.fond = UI.Aplat(f.ressourcesPA, { 0.035, 0.025, 0.02, 0.84 })
    f.ressourcesPA.fond:SetAllPoints(f.ressourcesPA)
    UI.BordureFine(f.ressourcesPA, 0.42)
    f.ressourcesPA.titre = UI.Texte(f.ressourcesPA, "PA :", UI.C.titre)
    f.ressourcesPA.titre:SetPoint("LEFT", f.ressourcesPA, "LEFT", 10, 0)
    UI.Police(f.ressourcesPA.titre, 14, "OUTLINE")
    f.ressourcesPA.pastilles = {}
    f.ressourcesPA:EnableMouse(true)
    f.ressourcesPA:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:SetText("Points d'action")
        local disponibles, tranche, total = LCM.Combat.PADisponibles(MaFiche())
        local etat = LCM.Combat.Etat()
        if etat and disponibles and etat.r < etat.rm then
            GameTooltip:AddLine(string.format("Pendant ce round, vous ne pouvez dépenser que %d PA sur %d.", tranche, total),
                1, 0.76, 0.55, true)
            GameTooltip:AddLine(string.format("Il vous reste %d PA utilisables maintenant.", disponibles),
                0.9, 0.85, 0.75, true)
            GameTooltip:AddLine("Les défenses utilisent vos PA restants sans entamer cette limite.", 0.9, 0.85, 0.75, true)
        elseif etat and disponibles then
            GameTooltip:AddLine(string.format("Dernier round : vos %d PA restants sont disponibles.", disponibles),
                1, 0.76, 0.55, true)
        end
        GameTooltip:Show()
    end)
    f.ressourcesPA:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Une seule ligne compacte sous les PA. Les cadres existent dès la
    -- construction : un changement d'état ne crée rien pendant le rendu.
    f.ressourcesEtats = CreateFrame("Frame", nil, f)
    Placer(f.ressourcesEtats, f, 170, 192, 410, 28)
    f.ressourcesEtats.icones = {}
    for index = 1, MAX_ETATS_HUD do
        local bouton = CreateFrame("Frame", nil, f.ressourcesEtats)
        bouton:SetSize(28, 28)
        bouton:SetPoint("LEFT", f.ressourcesEtats, "LEFT", (index - 1) * 31, 0)
        bouton:EnableMouse(true)
        bouton.fond = UI.Aplat(bouton, { 0.025, 0.018, 0.015, 0.94 }, "BACKGROUND")
        bouton.fond:SetAllPoints(bouton)
        UI.BordureFine(bouton, 0.62)
        bouton.icone = bouton:CreateTexture(nil, "ARTWORK")
        Placer(bouton.icone, bouton, 2, 2, 24, 24)
        bouton.temps = UI.Texte(bouton, "", { 1, 0.12, 0.08 }, "GameFontNormalSmall")
        bouton.temps:SetPoint("BOTTOMRIGHT", bouton, "BOTTOMRIGHT", -1, 0)
        bouton.temps:SetJustifyH("RIGHT")
        bouton.temps:SetShadowColor(0, 0, 0, 1)
        bouton.temps:SetShadowOffset(1, -1)
        bouton:SetScript("OnEnter", MontrerBulleEtat)
        bouton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        bouton:Hide()
        f.ressourcesEtats.icones[index] = bouton
    end
    f.ressourcesEtats:Hide()

    f.ressourcesPF = CreateFrame("Frame", nil, f)
    f.ressourcesPF:SetSize(LARGEUR_RESSOURCES, 30)
    f.ressourcesPF:SetPoint("TOPRIGHT", f, "TOPRIGHT", -170, -158)
    f.ressourcesPF.fond = UI.Aplat(f.ressourcesPF, { 0.025, 0.035, 0.055, 0.86 })
    f.ressourcesPF.fond:SetAllPoints(f.ressourcesPF)
    UI.BordureFine(f.ressourcesPF, 0.42)
    f.ressourcesPF.titre = UI.Texte(f.ressourcesPF, "PF :", UI.C.titre)
    f.ressourcesPF.titre:SetPoint("LEFT", f.ressourcesPF, "LEFT", 10, 0)
    UI.Police(f.ressourcesPF.titre, 14, "OUTLINE")
    f.ressourcesPF.barre = UI.Barre(f.ressourcesPF, UI.C.fatigue, LARGEUR_RESSOURCES - 60, 18)
    f.ressourcesPF.barre:SetPoint("RIGHT", f.ressourcesPF, "RIGHT", -8, 0)
    UI.Police(f.ressourcesPF.barre.label, 16, "OUTLINE")
    f.ressourcesPF.barre.label:SetTextColor(1, 1, 1, 1)
    f.ressourcesPF.barre.vide:SetColorTexture(0.05, 0.09, 0.16, 0.96)
    if UI.AelCadreJauge then f.ressourcesPF.barre.cadre = UI.AelCadreJauge(f.ressourcesPF.barre) end

    f:Hide()
    return f
end

function Ecran.Fenetre()
    return Ecran.frame or Construire()
end

local function Positionner(f)
    local largeurEcran = (UIParent and UIParent:GetWidth()) or LARGEUR
    f:SetScale(math.min(ECHELLE, (largeurEcran - 24) / LARGEUR))
    if not f.deplace then
        f:ClearAllPoints()
        f:SetPoint("TOP", UIParent, "TOP", 0, RAIL_HAUT)
    end
end

function Ecran.RafraichirRessources()
    local f = Ecran.frame
    if not f then return end
    local entity = MaFiche()
    local pa = entity and LCM.Entities.Gauge(entity, "pa") or { current = 0, max = 0 }
    local pf = entity and LCM.Entities.Gauge(entity, "fatigue") or { current = 0, max = 0 }
    local maximum = math.max(0, math.floor(tonumber(pa.max) or 0))
    local courant = math.max(0, math.min(maximum, math.floor(tonumber(pa.current) or 0)))
    local disponibles = math.max(0, math.min(courant, LCM.Combat.PADisponibles(entity) or courant))

    for index = #f.ressourcesPA.pastilles + 1, maximum do
        local p = PastillePA(f.ressourcesPA)
        p:SetPoint("LEFT", f.ressourcesPA, "LEFT", 47 + (index - 1) * 25, 0)
        f.ressourcesPA.pastilles[index] = p
    end
    for index, p in ipairs(f.ressourcesPA.pastilles) do
        p:SetShown(index <= maximum)
        if index <= maximum then
            p:Regler(index <= disponibles and "disponible" or index <= courant and "bloque" or "depense")
        end
    end
    f.ressourcesPF.barre:Regler(pf.current, pf.max)
end

function Ecran.RafraichirEtats()
    local f = Ecran.frame
    if not f then return end
    local liste = EtatsDe(MaFiche())
    for index, bouton in ipairs(f.ressourcesEtats.icones) do
        local etat = liste[index]
        -- La dernière case résume ce qui ne tient pas sur la ligne plutôt que
        -- de laisser des icônes déborder sur l'avis central.
        if index == MAX_ETATS_HUD and #liste > MAX_ETATS_HUD then
            local caches = {}
            for i = MAX_ETATS_HUD, #liste do caches[#caches + 1] = liste[i] end
            etat = { resume = true, caches = caches,
                nom = string.format("+%d", #caches),
                icone = "Interface\\Icons\\INV_Misc_QuestionMark" }
        end
        bouton.etat = etat
        bouton:SetShown(etat ~= nil)
        if etat then
            bouton.icone:SetTexture(LCM.Icone(etat.icone))
            bouton.icone:SetDesaturated(etat.resume == true)
            bouton.temps:SetText(etat.resume and etat.nom
                or (etat.restant and tostring(etat.restant) or ""))
        end
    end
    f.ressourcesEtats:SetShown(#liste > 0)
end

function Ecran.Rafraichir()
    local etat = LCM.Combat.Etat()
    if not etat then
        if Ecran.frame then
            Ecran.frame:Hide()
            Ecran.frame.debut = 1
        end
        return
    end
    local f = Ecran.Fenetre()
    Positionner(f)
    Ecran.RafraichirRessources()
    Ecran.RafraichirEtats()

    f.tour:SetText(string.format("%02d", etat.t))
    f.round:SetText(string.format("Round %d / %d", etat.r, etat.rm))

    local visibles, debut = Ecran.Visibles(etat.entrees, etat.c, f.debut)
    f.debut = debut
    f.fleche:Hide()
    f.losanges:Hide()
    for index = 1, CASES do
        local carte = f.cartes[index]
        local source = visibles[index]
        local entree = source and etat.entrees[source]
        carte.entree = entree
        f.vides[index]:SetShown(entree == nil)
        if entree then
            carte.icone:SetTexture(LCM.Icone(entree.icone))
            carte.icone:SetVertexColor(entree.ko and 0.92 or 1, entree.ko and 0.18 or 1,
                entree.ko and 0.18 or 1)
            carte.koRouge:SetShown(entree.ko == true)
            carte.koCrane:SetShown(entree.ko == true)
            local actif = source == etat.c
            carte.actif:SetShown(actif)
            if actif then
                Placer(f.fleche, f, RANGEE_X + (index - 1) * PAS + 27, RANGEE_Y - 13, 20, 13)
                Placer(f.losanges, f, RANGEE_X + (index - 1) * PAS + 10, RANGEE_Y + CASE + 3, 54, 15)
                f.fleche:Show()
                f.losanges:Show()
            end
            carte:Show()
        else
            carte:Hide()
        end
    end
    local plusieursPages = #etat.entrees > CASES
    f.precedent:SetShown(plusieursPages)
    f.suivant:SetShown(plusieursPages)

    local peut = LCM.Combat.PeutPasser()
    f.passer:SetEnabled(peut)
    f.passer.label:SetAlpha(peut and 1 or 0.38)
    f.avis:SetShown(LCM.Combat.EstMonTour())
    f:Show()
end

-- ===== L'invitation ========================================================
-- Necronicon : « Participer au combat », Oui / Non (ShowCoreInitiativeParticipationPrompt).

local function ConstruireInvitation()
    local d = CreateFrame("Frame", "LCM_CombatInvitation", UIParent)
    Ecran.invitation = d
    d:SetSize(300, 150)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetToplevel(true)
    d:EnableMouse(true)
    d.fond = UI.Aplat(d, UI.C.fond)
    d.fond:SetAllPoints(d)
    if UI.AelCadre then d.cadre = UI.AelCadre(d, "section") else UI.Bordure(d) end

    d.titre = UI.Texte(d, "Participer au combat", UI.C.titre)
    d.titre:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -14)
    d.texte = UI.Texte(d, "", UI.C.texte, "GameFontNormalSmall")
    d.texte:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -42)
    d.texte:SetPoint("TOPRIGHT", d, "TOPRIGHT", -14, -42)
    d.texte:SetJustifyV("TOP")
    d.texte:SetWordWrap(true)

    local function Repondre(accepte)
        d:Hide()
        local ok, raison = LCM.Combat.Repondre(accepte)
        if not ok and raison then LCM.Alerte(raison) end
    end
    d.oui = UI.Bouton(d, "Oui", 126, 24, function() Repondre(true) end)
    d.oui:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 14, 14)
    d.non = UI.Bouton(d, "Non", 126, 24, function() Repondre(false) end)
    d.non:SetPoint("LEFT", d.oui, "RIGHT", 8, 0)
    d:Hide()
    return d
end

function Ecran.Invitation(recue)
    local d = Ecran.invitation or ConstruireInvitation()
    if not recue then d:Hide() return d end
    d.texte:SetText(string.format(
        "%s souhaite lancer un combat.\nVoulez-vous participer au bandeau d'initiative ?",
        recue.mj))
    d:Show()
    d:Raise()
    return d
end

LCM.Combat.onChange = function() Ecran.Rafraichir() end
LCM.Combat.onInvitationRecue = function(recue) Ecran.Invitation(recue) end

-- Une action, une reaction ou un deplacement peut depenser des ressources
-- sans faire avancer l'initiative : le bandeau doit alors suivre aussitot.
LCM.Entities.Ecouter(function(entity)
    local f = Ecran.frame
    if f and f:IsShown() and entity == MaFiche() then
        Ecran.RafraichirRessources()
        Ecran.RafraichirEtats()
    end
end)

-- Et quand on change de peau — incarnation prise ou relachee, autre
-- personnage choisi — le bandeau suit. Sans cela il gardait les ressources de
-- l'entite precedente jusqu'a ce qu'une valeur bouge d'elle-meme.
if LCM.Entities.EcouterSoi then
    LCM.Entities.EcouterSoi(function()
        local f = Ecran.frame
        if f and f:IsShown() then
            Ecran.RafraichirRessources()
            Ecran.RafraichirEtats()
        end
    end)
end
