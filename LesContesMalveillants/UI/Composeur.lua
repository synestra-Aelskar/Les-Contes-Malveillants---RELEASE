-- La fenetre du composeur d'action, et le lien entre les boutons du lanceur
-- radial et les resolutions du compendium.
--
-- Mise en page reprise du composeur de Necronicon sous son skin
-- (ActionResolution.lua : RunActionComposer, ApplyLayout(true) ; habillage de
-- ThemeNecronicon.lua) : 686 x 352, bandeau de titre avec l'icone et les blocs
-- PA / PF, recapitulatif a gauche (232), questions au centre, cases de
-- resultat en pied. La logique est dans Core/Actions.lua : cette fenetre ne
-- fait que montrer le composeur et lui transmettre les clics.
--
-- Les jeux de choix (Necronicon : templates du composeur) : on enregistre ses
-- reponses a la fin, on les recharge depuis l'ecran d'accueil. Ecart voulu :
-- l'accueil (« Commencer » / « Charger un jeu ») ne s'affiche que s'il y a un
-- jeu a charger — sans, il ne ferait qu'ajouter un clic a chaque action.

local _, LCM = ...
local UI = LCM.UI
local A = LCM.Actions

local Ecran = {}
UI.Composeur = Ecran

local LARGEUR, HAUTEUR = 760, 402
local PAD, ECART_X, ECART_Y = 4, 8, 8
-- La jauge de retenue, sous les cases de degats : la fenetre grandit d'autant
-- a l'ecran final d'un coup, plutot que d'ecraser les cases. Elle avance par
-- pas de 5 %, assez fin pour doser, assez gros pour viser a la souris.
local HAUTEUR_RETENUE, PAS_RETENUE = 26, 5
local DORE = { 0.93, 0.80, 0.52 }
local CANAUX_EMOTE = {
    { id = "EMOTE", nom = "Émote" },
    { id = "PARTY", nom = "Groupe" },
    { id = "RAID", nom = "Raid" },
}

local function AvecEmoteFinale()
    -- Toute action qui passe par le composeur se termine par sa narration. Les
    -- ecrans speciaux portent desormais leur propre bloc commun : aucune action
    -- ne doit donc etre exclue ici sur la foi d'un ancien parcours d'interface.
    return true
end

local function EstControleMental(f)
    local r = f and f.composeur and f.composeur.ctx and f.composeur.ctx.resolution
    return r and r.id == "controle_mental"
end

local function BlocageFinal(f)
    local blocage = f.composeur:Blocage()
    if not blocage and EstControleMental(f) and not tostring(f.emoteFinale.zone:GetText() or ""):match("%S") then
        blocage = "Écris la narration imposée dans Emotes."
    end
    return blocage
end

local function ActualiserDeclaration(f)
    local blocage = BlocageFinal(f)
    f.question:SetText(blocage and ("|cffff6060" .. blocage .. "|r")
        or string.format("|cffffd200Prêt|r  —  %d étape(s) répondue(s)", #(f.visibles or {})))
    f.declarer:SetEnabled(blocage == nil)
    f.declarer:SetAlpha(blocage and 0.4 or 1)
    return blocage
end

local function Panneau(parent, opacite, bordure)
    local p = CreateFrame("Frame", nil, parent)
    p.fond = UI.Aplat(p, { 0.045, 0.043, 0.038, opacite or 0 })
    p.fond:SetAllPoints(p)
    if bordure then UI.BordureFine(p, 0.38) end
    return p
end

local function Placer(region, point, parent, relPoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relPoint, x, y)
end

-- Le corps, le filet du pied et la hauteur de la fenetre, avec ou sans la
-- jauge de retenue. Rien ne bouge si la disposition est deja la bonne.
local function DisposerPied(f, avecRetenue)
    local d = avecRetenue and HAUTEUR_RETENUE or 0
    if f.decalagePied == d then return end
    f.decalagePied = d
    f:SetHeight(HAUTEUR + d)
    f.principal:ClearAllPoints()
    f.principal:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -78)
    f.principal:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 88 + d)
    f.pied:ClearAllPoints()
    f.pied:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 80 + d)
    f.pied:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 80 + d)
    f.retenue:SetShown(avecRetenue)
end

-- Bloc PA ou PF du bandeau : etiquette a gauche, « cout / dispo » a droite.
local function BlocCout(f, libelle, decalage, couleur)
    local b = CreateFrame("Frame", nil, f.bandeau)
    b:SetSize(106, 44)
    Placer(b, "TOPRIGHT", f.bandeau, "TOPRIGHT", decalage, -4)
    b.filet = UI.Aplat(b, { 0.53, 0.43, 0.27, 0.8 })
    b.filet:SetWidth(1)
    b.filet:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -4)
    b.filet:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 4)
    b.libelle = UI.Texte(b, libelle, DORE, "GameFontNormalSmall")
    Placer(b.libelle, "TOPLEFT", b, "TOPLEFT", 10, -10)
    b.valeur = UI.Texte(b, "0 / 0", couleur, "GameFontNormalLarge")
    Placer(b.valeur, "TOPRIGHT", b, "TOPRIGHT", -10, -8)
    b.sous = UI.Texte(b, "coût / dispo", { 0.72, 0.62, 0.42 }, "GameFontNormalSmall")
    Placer(b.sous, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -10, 4)
    b.couleur = couleur
    return b
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Composeur", UIParent)
    Ecran.frame = f
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.fond = UI.Aplat(f, { 0.045, 0.038, 0.03, 0.985 })
    f.fond:SetAllPoints(f)
    if UI.AelCadre then f.cadre = UI.AelCadre(f, "section") else UI.Bordure(f) end

    -- ----- bandeau ----------------------------------------------------------
    f.bandeau = Panneau(f)
    f.bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    f.bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
    f.bandeau:SetHeight(62)
    f.regle = UI.Aplat(f.bandeau, { 0.53, 0.43, 0.27, 0.9 })
    f.regle:SetHeight(1)
    f.regle:SetPoint("BOTTOMLEFT", f.bandeau, "BOTTOMLEFT", 0, 0)
    f.regle:SetPoint("BOTTOMRIGHT", f.bandeau, "BOTTOMRIGHT", 0, 0)

    f.cadreIcone = Panneau(f, 0.95, true)
    f.cadreIcone:SetSize(46, 46)
    Placer(f.cadreIcone, "TOPLEFT", f, "TOPLEFT", 18, -18)
    if UI.AelCadre then f.cadreIcone.cadre = UI.AelCadre(f.cadreIcone, "icone") end
    f.icone = f.cadreIcone:CreateTexture(nil, "ARTWORK")
    f.icone:SetPoint("TOPLEFT", f.cadreIcone, "TOPLEFT", 3, -3)
    f.icone:SetPoint("BOTTOMRIGHT", f.cadreIcone, "BOTTOMRIGHT", -3, 3)

    f.titre = UI.Texte(f.bandeau, "", DORE, "GameFontNormalLarge")
    f.titre:SetJustifyH("CENTER")
    f.titre:SetWordWrap(false)

    f.pf = BlocCout(f, "PF", -38, { 0.62, 0.80, 0.96 })
    f.pa = BlocCout(f, "PA", -154, { 0.62, 0.88, 0.62 })

    f.fermer = UI.Bouton(f, "x", 18, 18, function() f:Hide() end)
    Placer(f.fermer, "TOPRIGHT", f, "TOPRIGHT", -14, -12)
    UI.Bulle(f.fermer, "Fermer le composeur", "Annule cette action sans dépenser de points.")

    -- ----- corps ------------------------------------------------------------
    f.principal = Panneau(f, 0.95, true)
    local M = f.principal

    f.recap = Panneau(M, 0.34, true)
    f.recap:SetPoint("TOPLEFT", M, "TOPLEFT", 10, -10)
    f.recap:SetPoint("BOTTOMLEFT", M, "BOTTOMLEFT", 10, 10)
    f.recap:SetWidth(232)
    f.recapTitre = UI.Texte(f.recap, "RÉCAPITULATIF", DORE, "GameFontNormalSmall")
    Placer(f.recapTitre, "TOPLEFT", f.recap, "TOPLEFT", 12, -10)
    f.recapFilet = UI.Filet(f.recap)
    f.recapFilet:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 6, -26)
    f.recapFilet:SetPoint("TOPRIGHT", f.recap, "TOPRIGHT", -6, -26)
    f.recapZone = UI.Defilement(f.recap)
    f.recapZone:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 8, -40)
    f.recapZone:SetPoint("BOTTOMRIGHT", f.recap, "BOTTOMRIGHT", -14, 8)
    f.recapLignes = {}
    f.recapVide = UI.Texte(f.recapZone.contenu, "(aucun choix)", UI.C.discret, "GameFontNormalSmall")
    Placer(f.recapVide, "TOPLEFT", f.recapZone.contenu, "TOPLEFT", 2, 0)

    f.centre = Panneau(M, 0.34, true)
    f.centre:SetPoint("TOPLEFT", f.recap, "TOPRIGHT", 10, 0)
    f.centre:SetPoint("BOTTOMRIGHT", M, "BOTTOMRIGHT", -10, 10)
    local C = f.centre
    f.centreTitre = UI.Texte(C, "COMPOSER L'ACTION", DORE, "GameFontNormalSmall")
    Placer(f.centreTitre, "TOPLEFT", C, "TOPLEFT", 12, -10)
    f.centreFilet = UI.Filet(C)
    f.centreFilet:SetPoint("TOPLEFT", C, "TOPLEFT", 6, -26)
    f.centreFilet:SetPoint("TOPRIGHT", C, "TOPRIGHT", -6, -26)
    f.question = UI.Texte(C, "", DORE, "GameFontNormalSmall")
    f.question:SetPoint("TOPLEFT", C, "TOPLEFT", 16, -40)
    f.question:SetPoint("TOPRIGHT", C, "TOPRIGHT", -16, -40)
    f.question:SetHeight(22)

    f.corps = UI.Defilement(C)
    f.corps:SetPoint("TOPLEFT", C, "TOPLEFT", 8, -68)
    f.corps:SetPoint("BOTTOMRIGHT", C, "BOTTOMRIGHT", -14, 34)
    f.boutons, f.cases = {}, {}

    -- Une question texte/nombre obligatoire doit deverrouiller « Suivant »
    -- pendant la frappe. Refaire tout le rendu ferait perdre le curseur ; on
    -- actualise donc seulement l'entete et l'etat du bouton.
    local function TexteSaisi(texte)
        if not f.q then return end
        f.composeur:Saisir(f.q, texte)
        Ecran.Entete()
        local attend = f.q.mode ~= "multi" and f.composeur.reponses[f.q.id] == nil
        f.suivant:SetEnabled(not attend)
        f.suivant:SetAlpha(attend and 0.4 or 1)
    end

    f.saisie = UI.Champ(f.corps.contenu, 180, 26, TexteSaisi)
    f.saisie:Hide()

    -- Les textes libres (notamment la narration du contrôle mental) ont leur
    -- propre zone multiligne. Ils n'utilisent pas le petit champ prévu pour
    -- une quantité : toute la surface centrale doit servir à écrire et relire.
    f.narration = UI.Zone(f.corps.contenu, 400, 120, TexteSaisi)
    f.narration:Hide()

    -- Derniere etape commune : l'emote n'est envoyee qu'une fois la
    -- declaration reellement partie (apres le choix des cibles).
    f.emoteFinale = Panneau(f.corps.contenu, 0.26, true)
    f.emoteFinale:SetSize(400, 116)
    f.emoteFinale.titre = UI.Texte(f.emoteFinale, "EMOTES", DORE, "GameFontNormalSmall")
    Placer(f.emoteFinale.titre, "TOPLEFT", f.emoteFinale, "TOPLEFT", 10, -9)
    f.emoteFinale.canal = UI.Bouton(f.emoteFinale, "", 112, 22, function(self)
        self.rang = self.rang % #CANAUX_EMOTE + 1
        f.emoteCanal = CANAUX_EMOTE[self.rang].id
        self.label:SetText("Canal : " .. CANAUX_EMOTE[self.rang].nom)
    end)
    Placer(f.emoteFinale.canal, "TOPRIGHT", f.emoteFinale, "TOPRIGHT", -8, -6)
    f.emoteFinale.zone = UI.Zone(f.emoteFinale, 380, 76, function(texte)
        f.emoteTexte = texte
        if f.ecran == "fin" and EstControleMental(f) then ActualiserDeclaration(f) end
    end)
    f.emoteFinale.zone.saisie:SetMaxLetters(4000)
    f.emoteFinale.zone:SetPoint("TOPLEFT", f.emoteFinale, "TOPLEFT", 8, -34)
    f.emoteFinale.zone:SetPoint("BOTTOMRIGHT", f.emoteFinale, "BOTTOMRIGHT", -8, 8)
    f.emoteFinale:Hide()

    f.precedent = UI.Bouton(C, "Précédent", 100, 22, function() Ecran.Aller(-1) end)
    Placer(f.precedent, "BOTTOMLEFT", C, "BOTTOMLEFT", 8, 6)
    f.suivant = UI.Bouton(C, "Suivant", 100, 22, function() Ecran.Aller(1) end)
    Placer(f.suivant, "BOTTOMRIGHT", C, "BOTTOMRIGHT", -8, 6)
    f.declarer = UI.Bouton(C, "Déclarer mon action", 190, 24, function() Ecran.Declarer() end)
    Placer(f.declarer, "BOTTOM", C, "BOTTOM", 0, 6)
    f.enregistrer = UI.Bouton(C, "Enregistrer", 108, 24, function()
        UI.Demande():Demander("Nom du jeu de choix", "", function(nom)
            local jeu = A.EnregistrerJeu(f.composeur.ctx.resolution.id, nom, f.composeur)
            LCM.Ok(string.format("jeu de choix « %s » enregistré.", jeu.nom))
            return true
        end)
    end)
    Placer(f.enregistrer, "LEFT", f.declarer, "RIGHT", 8, 0)
    -- L'accueil et la liste des jeux : de gros boutons, puis une ligne par jeu.
    f.accueil = {}
    for i, texte in ipairs({ "Commencer mon action", "Charger un jeu de choix" }) do
        local b = UI.Bouton(C, texte, 260, 32, function()
            if i == 1 then f.ecran, f.pos = "questions", 1 else f.ecran = "jeux" end
            Ecran.Rendre()
        end)
        Placer(b, "TOP", C, "TOP", 0, -76 - (i - 1) * 40)
        f.accueil[i] = b
    end
    f.lignesJeux = {}
    f.blocage = UI.Texte(C, "", UI.C.plein, "GameFontNormalSmall")
    f.blocage:SetPoint("TOPLEFT", f.declarer, "BOTTOMLEFT", -20, -8)
    f.blocage:SetPoint("TOPRIGHT", f.declarer, "BOTTOMRIGHT", 20, -8)
    f.blocage:SetJustifyH("CENTER")

    -- ----- pied : une case par calcul de la feuille -------------------------
    f.pied = UI.Aplat(f, { 0.53, 0.43, 0.27, 0.9 })
    f.pied:SetHeight(1)
    f.resultats = {}
    for i = 1, 3 do
        local c = Panneau(f, 0.3)
        c.titre = UI.Texte(c, "", UI.C.titre, "GameFontNormalSmall")
        Placer(c.titre, "TOP", c, "TOP", 0, -9)
        c.titre:SetWidth(200)
        c.titre:SetJustifyH("CENTER")
        c.titre:SetWordWrap(false)
        c.valeur = UI.Texte(c, "—", { 1, 0.82, 0.35 }, "GameFontNormalLarge")
        Placer(c.valeur, "BOTTOM", c, "BOTTOM", 0, 9)
        c.separateur = UI.Aplat(c, { 0.64, 0.52, 0.31, 0.9 }, "OVERLAY")
        c.separateur:SetWidth(1)
        c.separateur:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -7)
        c.separateur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 7)
        c.separateur:SetShown(i > 1)
        c.filet = UI.Aplat(c, { 0.64, 0.52, 0.31, 0.55 }, "ARTWORK")
        c.filet:SetHeight(1)
        c.filet:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -4)
        c.filet:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -4)
        c:Hide()
        f.resultats[i] = c
    end

    -- ----- la retenue : frapper moins fort que son plein coup ---------------
    f.retenue = CreateFrame("Frame", nil, f)
    f.retenue:SetHeight(16)
    f.retenue:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 14)
    f.retenue:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
    f.retenue.libelle = UI.Texte(f.retenue, "", DORE, "GameFontNormalSmall")
    Placer(f.retenue.libelle, "LEFT", f.retenue, "LEFT", 0, 0)
    f.retenue.libelle:SetWidth(170)
    f.retenue.libelle:SetJustifyH("LEFT")
    f.retenue.curseur = UI.Curseur(f.retenue, function(valeur)
        f.composeur.ctx.retenue = valeur * PAS_RETENUE
        Ecran.Entete()
    end)
    f.retenue.curseur:SetPoint("LEFT", f.retenue.libelle, "RIGHT", 8, 0)
    f.retenue.curseur:SetPoint("RIGHT", f.retenue, "RIGHT", 0, 0)
    UI.Bulle(f.retenue.curseur, "Retenir son coup",
        "Baisse les dégâts déclarés, normal et critique ensemble. Jamais sous 1.")
    f.retenue:Hide()
    DisposerPied(f, false)

    -- Fermer avant de declarer arrete l'action : rien n'est debite.
    f:SetScript("OnHide", function()
        local annuler = f.annuler
        f.valider, f.annuler = nil, nil
        if annuler then annuler() end
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "LCM_Composeur" end
    f:Hide()
    return f
end

function Ecran.Fenetre() return Ecran.frame or Construire() end

-- ===== Le bandeau, le recapitulatif, le pied ===============================

local function Arrondi(v) return v ~= nil and tostring(math.floor(tonumber(v) + 0.5)) or "?" end

local function NombreApercu(v)
    local n = tonumber(v)
    if not n then return "?" end
    -- Arrondi arithmétique identique à celui employé au moment du jet :
    -- 2,49 -> 2 ; 2,50 -> 3.
    return tostring(math.floor(n + 0.5))
end

-- Les cases du pied : les calculs de la feuille (Degat normal, critique...),
-- les apercus du composeur (« Distance (m) = ... »), et le perce-armure quand
-- l'action en pose. Necronicon les recalculait en differe, pour ne pas geler ;
-- les notres sont assez legers pour etre faits au clic.
local function Cases(f)
    local c = f.composeur
    local ctx = c.ctx
    local cases = {}
    -- Un coup retenu montre ce qui partira, et son plein coup a cote. Le
    -- perce-armure plus bas se calcule sur la valeur retenue : c'est celle
    -- que la cible recevra.
    local retenables = A.SortiesRetenables(ctx)
    local retenue = tonumber(ctx.retenue) or 100
    for _, etape in ipairs(ctx.etapes or {}) do
        if etape.type == "compute" and tostring(etape.out or "") ~= "" then
            local v = A.Calculer(etape, ctx)
            if v then ctx.vars[etape.out] = v end
            local case = { titre = etape.label ~= "" and etape.label or "Résultat", valeur = ctx.vars[etape.out] }
            local plein = tonumber(case.valeur)
            if retenables and retenables[etape.out] and plein and retenue < 100 then
                case.valeur = A.Retenir(math.floor(plein + 0.5), retenue)
                case.plein = plein
            end
            cases[#cases + 1] = case
        end
    end
    for _, p in ipairs(A.Paires(c.etape.previewText)) do
        cases[#cases + 1] = { titre = p.k, valeur = A.Evaluer(p.v, ctx), decimales = true }
    end
    local perce = false
    for _, q in ipairs(c.questions) do
        for _, o in ipairs(q.options) do
            for paire in o.set:gmatch("[^;\n]+") do
                local k = paire:match("^%s*(.-)%s*=")
                if k and k:lower():find("^perce") then perce = true end
            end
        end
    end
    if perce and #cases < 3 then
        local pct = tonumber(ctx.vars.perceArmure or ctx.vars["Perce Armure"] or ctx.vars.perce)
        local texte = "—"
        if pct then
            pct = math.max(0, math.min(100, pct))
            local n, cr = tonumber(cases[1] and cases[1].valeur), tonumber(cases[2] and cases[2].valeur)
            texte = string.format("|cffffffff%d|r / |cffff5959%d|r  |cff9a9a9a(%d %%)|r",
                math.ceil((n or 0) * pct / 100 - 1e-9), math.ceil((cr or 0) * pct / 100 - 1e-9),
                math.floor(pct + 0.5))
        end
        cases[#cases + 1] = { titre = "Perce-armure #santé  (norm / crit)", texte = texte }
    end
    return cases
end

function Ecran.Entete()
    local f = Ecran.frame
    local c = f.composeur
    local pa, pf = c:Deriver()
    local dpa, dpf = A.Disponible(c.ctx.entity, c.ctx.recu ~= nil)
    f.pa.valeur:SetText(Arrondi(pa) .. " / " .. Arrondi(dpa))
    f.pf.valeur:SetText(Arrondi(pf) .. " / " .. Arrondi(dpf))
    -- Trop cher : la valeur passe au rouge (le skin de Necronicon reportait la
    -- teinte « pas assez » sur la valeur).
    for _, b in ipairs({ { f.pa, pa, dpa }, { f.pf, pf, dpf } }) do
        local couleur = (b[3] and b[2] > b[3] + 0.005) and { 1, 0.42, 0.38 } or b[1].couleur
        b[1].valeur:SetTextColor(couleur[1], couleur[2], couleur[3])
    end

    -- Recapitulatif : une ligne cliquable par question repondue.
    local y, rang = 0, 0
    for _, q in ipairs(c.questions) do
        local choix = c:Choix(q)
        if choix ~= "" then
            rang = rang + 1
            local l = f.recapLignes[rang]
            if not l then
                l = CreateFrame("Button", nil, f.recapZone.contenu)
                l.survol = UI.Aplat(l, UI.C.survol, "HIGHLIGHT")
                l.survol:SetAllPoints(l)
                l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.texte:SetPoint("TOPLEFT", l, "TOPLEFT", 2, 0)
                l.texte:SetPoint("TOPRIGHT", l, "TOPRIGHT", -2, 0)
                l.texte:SetWordWrap(true)
                l:SetScript("OnClick", function(self) Ecran.AllerA(self.q) end)
                f.recapLignes[rang] = l
            end
            l.q = q
            l.texte:SetText(string.format("|cff9fbfdf%s :|r\n  %s", q.label, choix))
            local h = math.max(16, (l.texte:GetStringHeight() or 16) + 4)
            l:SetHeight(h)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", f.recapZone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", f.recapZone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + h + 3
        end
    end
    for i = rang + 1, #f.recapLignes do f.recapLignes[i]:Hide() end
    f.recapVide:SetShown(rang == 0)
    f.recapZone:Regler(y)

    -- Pied.
    f.retenue.libelle:SetText(string.format("Force du coup : |cffffffff%d %%|r",
        tonumber(c.ctx.retenue) or 100))
    local cases = Cases(f)
    local n = math.min(3, #cases)
    local l = n > 0 and math.floor((LARGEUR - 36) / n) or 0
    for i, case in ipairs(f.resultats) do
        local spec = cases[i]
        if spec and i <= n then
            Placer(case, "BOTTOMLEFT", f, "BOTTOMLEFT", 18 + (i - 1) * l, 16 + (f.decalagePied or 0))
            case:SetSize(l, 58)
            case.titre:SetText(spec.titre)
            case.titre:SetWidth(l - 16)
            local texte = spec.texte or (spec.valeur and
                (spec.decimales and NombreApercu(spec.valeur) or Arrondi(spec.valeur))) or "—"
            if spec.plein then texte = texte .. "  |cff9a9a9a/ " .. Arrondi(spec.plein) .. "|r" end
            case.valeur:SetText(texte)
            -- La deuxieme de deux calculs (le critique) en rouge.
            local rouge = i == 2 and not spec.texte
            case.valeur:SetTextColor(1, rouge and 0.35 or 0.82, rouge and 0.35 or 0.35)
            case:Show()
        else
            case:Hide()
        end
    end
end

-- ===== Les ecrans ==========================================================

local function Cacher(f)
    for _, b in ipairs(f.boutons) do b:Hide() end
    for _, c in ipairs(f.cases) do c:Hide() end
    f.saisie:Hide()
    f.narration:Hide()
    f.emoteFinale:Hide()
    f.declarer:Hide()
    f.enregistrer:Hide()
    for _, b in ipairs(f.accueil) do b:Hide() end
    for _, l in ipairs(f.lignesJeux) do l:Hide() end
    f.blocage:SetText("")
end

-- Une ligne par jeu de choix : le charger, le monter, le descendre, le
-- renommer, le supprimer.
local function Jeux(f)
    local id = f.composeur.ctx.resolution.id
    local jeux = A.JeuxDeChoix(id)
    f.question:SetText(#jeux > 0 and "|cffffd200Jeux de choix|r  —  clic pour charger"
        or "|cff909090Aucun jeu de choix enregistré.|r")
    local largeur = f.corps:GetWidth()
    if not largeur or largeur < 40 then largeur = 380 end
    for i, jeu in ipairs(jeux) do
        local l = f.lignesJeux[i]
        if not l then
            l = CreateFrame("Frame", nil, f.corps.contenu)
            l:SetHeight(26)
            -- La ligne est creee une fois et resservira pour d'autres actions :
            -- elle relit la resolution courante (l.resolution) a chaque clic,
            -- jamais celle de la premiere action qui l'a fait naitre.
            l.charger = UI.Bouton(l, "", 100, 24, function()
                A.ChargerJeu(f.composeur, A.JeuxDeChoix(l.resolution)[l.index])
                -- Charge, on va droit a la fin : il ne reste qu'a declarer.
                f.ecran = "fin"
                Ecran.Rendre()
            end)
            l.charger:SetPoint("LEFT", l, "LEFT", 0, 0)
            local function Petit(texte, action)
                local b = UI.Bouton(l, texte, 22, 22, function() action(l.index) Ecran.Rendre() end)
                return b
            end
            l.supprimer = Petit("x", function(n) A.SupprimerJeu(l.resolution, n) end)
            l.supprimer:SetPoint("RIGHT", l, "RIGHT", -2, 0)
            l.renommer = Petit("R", function(n)
                UI.Demande():Demander("Renommer le jeu de choix", A.JeuxDeChoix(l.resolution)[n].nom, function(nom)
                    A.RenommerJeu(l.resolution, n, nom)
                    Ecran.Rendre()
                    return true
                end)
            end)
            l.renommer:SetPoint("RIGHT", l.supprimer, "LEFT", -3, 0)
            l.bas = Petit("v", function(n) A.DeplacerJeu(l.resolution, n, 1) end)
            l.bas:SetPoint("RIGHT", l.renommer, "LEFT", -3, 0)
            l.haut = Petit("^", function(n) A.DeplacerJeu(l.resolution, n, -1) end)
            l.haut:SetPoint("RIGHT", l.bas, "LEFT", -3, 0)
            f.lignesJeux[i] = l
        end
        l.index = i
        l.resolution = id
        l:SetWidth(largeur)
        l.charger:SetWidth(math.max(60, largeur - 110))
        l.charger.label:SetText(string.format("%s  |cff909090(PA %d · PF %d)|r", jeu.nom, jeu.pa or 0, jeu.pf or 0))
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", f.corps.contenu, "TOPLEFT", 0, -(i - 1) * 30)
        l:Show()
    end
    f.corps:Regler(#jeux * 30)
end

local function Libelle(o)
    local couts = {}
    if o.pa ~= 0 then couts[#couts + 1] = "PA : " .. o.pa end
    if o.pf ~= 0 then couts[#couts + 1] = "PF : " .. o.pf end
    if #couts == 0 then return o.label end
    return o.label .. "\n|cff909090( " .. table.concat(couts, " - ") .. " )|r"
end

local function Question(f, q)
    local c = f.composeur
    local largeur = f.corps:GetWidth()
    if not largeur or largeur < 40 then largeur = 408 end
    local visible = f.corps:GetHeight()
    if not visible or visible < 40 then visible = 150 end
    local options = c:Options(q)
    local n = #options

    if q.mode == "text" then
        f.narration:SetText(tostring(c.reponses[q.id] or ""))
        f.narration:ClearAllPoints()
        f.narration:SetPoint("TOPLEFT", f.corps.contenu, "TOPLEFT", PAD, -PAD)
        -- Une marge basse nette separe la zone de la rangee de navigation.
        f.narration:SetSize(math.max(1, largeur - PAD * 2), math.max(1, visible - 12))
        f.narration:Show()
        f.corps:Regler(visible)
        return
    end

    if q.mode == "number" then
        f.saisie:SetText(tostring(c.reponses[q.id] or ""))
        f.saisie:ClearAllPoints()
        f.saisie:SetPoint("TOP", f.corps.contenu, "TOP", 0, -12)
        f.saisie:Show()
        f.corps:Regler(visible)
        return
    end

    -- Grille quasi carree, trois colonnes au plus, comme Necronicon.
    local multi = q.mode == "multi"
    local minimum = multi and 92 or 106
    local colonnes = math.max(1, math.min(3, math.ceil(math.sqrt(math.max(1, n)))))
    while colonnes > 1 and math.floor((largeur - PAD * 2 - (colonnes - 1) * ECART_X) / colonnes) < minimum do
        colonnes = colonnes - 1
    end
    local rangees = math.ceil(n / colonnes)
    local cellule = math.floor((largeur - PAD * 2 - (colonnes - 1) * ECART_X) / colonnes)
    local depart = math.max(PAD, math.floor((largeur - (colonnes * cellule + (colonnes - 1) * ECART_X)) / 2))

    if multi then
        local h = 26
        for i, o in ipairs(options) do
            local case = f.cases[i]
            if not case then
                case = UI.Case(f.corps.contenu, "", function(coche)
                    local cible = f.cases[i]
                    if not cible.o then return end
                    -- f.composeur et pas `c` : la case est creee une fois et
                    -- sert a toutes les actions suivantes. `c` etait celui de
                    -- la PREMIERE : il jugeait avec ses reponses et ses PA, ne
                    -- laissait cocher que les types deja pris la premiere fois
                    -- et decochait les autres sans rien dire (13 octobre 2026).
                    if coche and not f.composeur:Abordable(f.q, cible.o) then cible:Cocher(false) return end
                    f.composeur:Cocher(f.q, cible.o.id, coche)
                    Ecran.Rendre()
                end)
                f.cases[i] = case
            end
            case.o = o
            local col, rang = (i - 1) % colonnes, math.floor((i - 1) / colonnes)
            Placer(case, "TOPLEFT", f.corps.contenu, "TOPLEFT", depart + col * (cellule + ECART_X), -PAD - rang * (h + ECART_Y))
            case.label:SetText(o.label)
            local coche = c:EstChoisie(q, o.id)
            case:Cocher(coche)
            local abordable = c:Abordable(q, o)
            case:SetEnabled(abordable)
            local couleur = abordable and UI.C.texte or UI.C.discret
            case.label:SetTextColor(couleur[1], couleur[2], couleur[3])
            case:Show()
        end
        f.corps:Regler(PAD * 2 + rangees * h + (rangees - 1) * ECART_Y)
        return
    end

    local couts = false
    for _, o in ipairs(options) do if o.pa ~= 0 or o.pf ~= 0 then couts = true end end
    local h = math.floor((visible - PAD * 2 - (rangees - 1) * ECART_Y) / rangees) - 1
    local mini = couts and 40 or 26
    if h < mini then h = mini elseif h > 58 then h = 58 end
    for i, o in ipairs(options) do
        local b = f.boutons[i]
        if not b then
            b = UI.Bouton(f.corps.contenu, "", 100, 28, function(self)
                if not self.o or not f.composeur:Abordable(f.q, self.o) then return end
                f.composeur:Repondre(f.q, self.o.id)
                Ecran.Rendre()
            end)
            b.label:SetWordWrap(true)
            f.boutons[i] = b
        end
        b.o = o
        b:SetSize(cellule, h)
        local col, rang = (i - 1) % colonnes, math.floor((i - 1) / colonnes)
        Placer(b, "TOPLEFT", f.corps.contenu, "TOPLEFT", depart + col * (cellule + ECART_X), -PAD - rang * (h + ECART_Y))
        b.label:SetText(Libelle(o))
        b:Selectionner(c:EstChoisie(q, o.id))
        local abordable = c:Abordable(q, o)
        b:SetEnabled(abordable)
        b:SetAlpha(abordable and 1 or 0.4)
        b:Show()
    end
    f.corps:Regler(PAD * 2 + rangees * h + (rangees - 1) * ECART_Y)
end

function Ecran.Rendre()
    local f = Ecran.frame
    local c = f.composeur
    Cacher(f)
    -- La retenue n'apparait qu'a la fin, au moment de declarer un coup : avant,
    -- les degats bougent encore avec chaque reponse.
    local fin = f.ecran == "fin" or (f.ecran == "questions" and #c:Visibles() == 0)
    local retenue = fin and A.Retenable(c.ctx)
    DisposerPied(f, retenue)
    if retenue then
        f.retenue.curseur:Regler(100 / PAS_RETENUE,
            math.floor((tonumber(c.ctx.retenue) or 100) / PAS_RETENUE + 0.5))
    end
    Ecran.Entete()
    f.visibles = c:Visibles()
    if f.ecran == "accueil" then
        f.q = nil
        f.question:SetText("|cffffd200Composer l'action|r")
        local jeux = #A.JeuxDeChoix(c.ctx.resolution.id) > 0
        f.accueil[1]:Show()
        f.accueil[2]:Show()
        f.accueil[2]:SetEnabled(jeux)
        f.accueil[2]:SetAlpha(jeux and 1 or 0.4)
        f.corps:Regler(0)
        f.precedent:Hide()
        f.suivant:Hide()
        return
    end
    if f.ecran == "jeux" then
        f.q = nil
        Jeux(f)
        f.precedent:Show()
        f.precedent:SetEnabled(true)
        f.suivant:Hide()
        return
    end
    if f.ecran ~= "fin" and #f.visibles == 0 then f.ecran = "fin" end
    if f.ecran == "fin" then
        f.q = nil
        f.declarer:Show()
        f.enregistrer:Show()
        if f.avecEmoteFinale then
            f.declarer:SetSize(190, 24)
            Placer(f.declarer, "BOTTOM", f.centre, "BOTTOM", 0, 6)
            f.enregistrer:SetSize(108, 24)
            f.enregistrer.label:SetText("Enregistrer")
            Placer(f.enregistrer, "LEFT", f.declarer, "RIGHT", 8, 0)
            local largeur = f.corps:GetWidth()
            if not largeur or largeur < 1 then largeur = 400 end
            local hauteur = f.corps:GetHeight()
            if not hauteur or hauteur < 1 then hauteur = 116 end
            f.emoteFinale:ClearAllPoints()
            f.emoteFinale:SetPoint("TOPLEFT", f.corps.contenu, "TOPLEFT", PAD, -PAD)
            -- Ne jamais imposer un minimum superieur a l'espace disponible :
            -- sur une faible resolution/UI scale, c'etait la cause du cadre
            -- qui sortait du panneau et recouvrait les boutons.
            f.emoteFinale:SetSize(math.max(1, largeur - PAD * 2), math.max(1, hauteur - 12))
            f.emoteFinale:Show()
            f.corps:Regler(hauteur)
        else
            f.declarer:SetSize(200, 34)
            Placer(f.declarer, "TOP", f.centre, "TOP", 0, -80)
            f.enregistrer:SetSize(200, 26)
            f.enregistrer.label:SetText("Enregistrer ce jeu de choix")
            Placer(f.enregistrer, "TOP", f.declarer, "BOTTOM", 0, -8)
            f.corps:Regler(0)
        end
        ActualiserDeclaration(f)
        f.precedent:Show()
        f.suivant:Hide()
        return
    end
    f.pos = math.max(1, math.min(f.pos or 1, #f.visibles))
    local q = f.visibles[f.pos]
    f.q = q
    f.question:SetText(string.format("|cffffd200%d/%d|r  %s", f.pos, #f.visibles, q.label))
    Question(f, q)
    f.precedent:Show()
    f.precedent:SetEnabled(f.pos > 1 or #A.JeuxDeChoix(c.ctx.resolution.id) > 0)
    f.suivant:Show()
    f.suivant.label:SetText(f.pos >= #f.visibles and "Terminer" or "Suivant")
    -- Un choix unique exige une reponse avant d'avancer.
    local attend = q.mode ~= "multi" and c.reponses[q.id] == nil
    f.suivant:SetEnabled(not attend)
    f.suivant:SetAlpha(attend and 0.4 or 1)
end

function Ecran.Aller(sens)
    local f = Ecran.frame
    if f.ecran == "jeux" then
        f.ecran = "accueil"
        return Ecran.Rendre()
    end
    if f.ecran == "questions" and sens < 0 and f.pos <= 1 and #A.JeuxDeChoix(f.composeur.ctx.resolution.id) > 0 then
        f.ecran = "accueil"
        return Ecran.Rendre()
    end
    if f.ecran == "fin" then
        if sens < 0 then f.ecran, f.pos = "questions", #f.visibles end
        return Ecran.Rendre()
    end
    local q = f.q
    if sens > 0 and q and q.mode ~= "multi" and f.composeur.reponses[q.id] == nil then return end
    if sens > 0 and f.pos >= #f.visibles then
        f.ecran = "fin"
    else
        f.pos = f.pos + sens
    end
    Ecran.Rendre()
end

function Ecran.AllerA(q)
    local f = Ecran.frame
    for i, v in ipairs(f.composeur:Visibles()) do
        if v == q then f.ecran, f.pos = "questions", i return Ecran.Rendre() end
    end
end

function Ecran.Declarer()
    local f = Ecran.frame
    local blocage = BlocageFinal(f)
    if blocage then
        f.blocage:SetText(blocage)
        return
    end
    local valider = f.valider
    local texte = f.avecEmoteFinale and tostring(f.emoteFinale.zone:GetText() or "") or ""
    if texte:match("%S") then
        f.composeur.ctx.emoteAction = { texte = texte, canal = f.emoteCanal or "EMOTE" }
    else
        f.composeur.ctx.emoteAction = nil
    end
    -- Le contrôle mental utilisait auparavant une question texte séparée.
    -- La zone Emotes est désormais son unique narration : elle alimente aussi
    -- le paquet soumis au MJ avant la déclaration effective.
    if EstControleMental(f) then f.composeur.ctx.vars.narration = texte end
    f.valider, f.annuler = nil, nil
    f:Hide()
    if valider then valider() end
end

-- Le moteur demande a composer : on montre la fenetre sur la premiere question.
function Ecran.Ouvrir(composeur, valider, annuler)
    local f = Ecran.Fenetre()
    -- Une composition precedente encore ouverte est abandonnee proprement.
    if f:IsShown() then f:Hide() end
    f.composeur, f.valider, f.annuler = composeur, valider, annuler
    -- L'accueil n'a de sens que s'il y a un jeu de choix a charger.
    f.ecran = #A.JeuxDeChoix(composeur.ctx.resolution.id) > 0 and "accueil" or "questions"
    f.pos = 1
    f.avecEmoteFinale = AvecEmoteFinale(composeur)
    f.emoteTexte = ""
    f.emoteFinale.zone:SetText("")
    local rang = (IsInRaid and IsInRaid()) and 3 or ((IsInGroup and IsInGroup()) and 2 or 1)
    f.emoteFinale.canal.rang = rang
    f.emoteCanal = CANAUX_EMOTE[rang].id
    f.emoteFinale.canal.label:SetText("Canal : " .. CANAUX_EMOTE[rang].nom)
    local etape = composeur.etape
    f.titre:SetText(tostring(etape.label or "") ~= "" and etape.label or "Composer l'action")
    f.icone:SetTexture(LCM.Icone(composeur.ctx.icone))
    local sansCout = etape.hideCost == true
    f.pa:SetShown(not sansCout)
    f.pf:SetShown(not sansCout)
    f.titre:ClearAllPoints()
    f.titre:SetPoint("LEFT", f.bandeau, "LEFT", 66, 0)
    f.titre:SetPoint("RIGHT", f.bandeau, "RIGHT", sansCout and -40 or -276, 0)
    f.titre:SetHeight(28)
    f:Show()
    f:Raise()
    Ecran.Rendre()
    return f
end

A.onComposer = function(composeur, valider, annuler) Ecran.Ouvrir(composeur, valider, annuler) end

-- Ce qui a ete declare : celui qui agit voit ce qu'il a envoye, et a qui.
A.onDeclaration = function(ctx)
    local emote = ctx.emoteAction
    ctx.emoteAction = nil
    if emote and tostring(emote.texte or ""):match("%S") then
        A.DireEmoteAction(emote.texte, emote.canal)
    end
    local d, c = ctx.declaration, ctx.cibles or {}
    local lignes = {}
    for _, k in ipairs(d.ordre) do
        local v = d.valeurs[k]
        if v ~= "" and v ~= "?" then lignes[#lignes + 1] = k .. " : " .. v end
    end
    local n = #(c.joueurs or {}) + #(c.pnj or {}) + (c.soi and 1 or 0)
    LCM.Info(string.format("%s déclaré à %d cible%s — %s", d.nature, n, n > 1 and "s" or "", table.concat(lignes, ", ")))
end

-- ===== Les boutons du lanceur radial =======================================

-- Chaque bouton joue SON action (Core/ActionsBoutons.lua), definie avec lui
-- dans le code depuis le 3 octobre 2026 ; il ne cite plus une entree du
-- compendium.
LCM.WhenReady(function()
    for _, categorie in ipairs(UI.Radial.STRUCTURE) do
        -- Les actions du MJ vivent dans le compagnon (ActionsBoutons.lua) :
        -- chez un joueur, elles n'existent pas, et leur categorie ne s'affiche
        -- pas. Rien a lier, rien a signaler.
        local entrees = (categorie.mjSeulement and not LCM.IsMaster()) and {} or categorie.entrees or {}
        for _, entree in ipairs(entrees) do
            local action = LCM.ActionsBoutons.DuBouton(entree.id)
            -- Un bouton peut porter sa propre fenetre au lieu d'une resolution
            -- du composeur : le Dot a son ecran a lui (UI/DotComposeur.lua),
            -- parce que son bareme est en Lua et n'a pas besoin du DSL importe.
            if (LCM.BoutonsPropres or {})[entree.id] then
                -- Ce bouton porte sa propre fenetre : rien a lier ici.
            elseif action then
                -- Une seule icone : celle du bouton, que le composeur reprend.
                -- Les deux montraient chacun la sienne (le lanceur ses
                -- dessins, le composeur l'icone WoW importee de Necronicon).
                action.icone = entree.icone
                UI.Radial.Lier(entree.id, function() A.Lancer(action) end)
            else
                LCM.Erreur(string.format("radial : le bouton « %s » n'a pas d'action.", entree.id))
            end
        end
    end
end)
