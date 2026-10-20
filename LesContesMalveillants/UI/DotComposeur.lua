-- Composer un dot, sur le modele du constructeur d'effets.
--
-- Fenetre a elle, et non une resolution du composeur : le bareme du dot vit en
-- Lua (Data/Equilibrage.lua, Core/Dot.lua), pas dans le DSL importe de
-- Necronicon. Ecrire une seconde resolution de huit cents caracteres aurait
-- ajoute a une dette qu'on cherche a solder (10 octobre 2026).
--
-- Elle a d'abord ete une liste de jauges a boutons « - / + ». C'etait trop
-- maigre a cote du constructeur de debuff, alors qu'on y fait le meme geste :
-- repartir un capital sur des effets, nommer le resultat, et le poser sur
-- quelqu'un. Elle reprend donc sa forme (12 octobre 2026) :
--
--   * un apercu en tete, qui montre ce qu'on est en train de faire ;
--   * une bibliotheque de modeles, et un repli qui ne laisse qu'elle ;
--   * a gauche le CONSTRUCTEUR — nature, icone, nom, description, le capital,
--     la duree, puis les familles de ce qu'on grignote, repliables ;
--   * a droite les CHOIX — ce qui fabrique le pool (source, penetration,
--     niveau), avec les deux compteurs toujours sous les yeux ;
--   * en pied ce qui bloque, Annuler et Declarer.
--
-- Le pool se recalcule a chaque clic : on voit ce qu'il reste pendant qu'on
-- depense, pas apres.

local _, LCM = ...
local UI = LCM.UI
local D = LCM.Dot

local Ecran = {}
UI.DotComposeur = Ecran

-- Ce bouton du radial porte SA fenetre, pas une resolution du composeur. On le
-- declare des le chargement : le composeur verifie cette liste avant de crier
-- qu'un bouton n'a pas d'action, et l'ordre des WhenReady ne doit pas decider
-- lequel des deux parle en premier (10 octobre 2026).
LCM.BoutonsPropres = LCM.BoutonsPropres or {}
LCM.BoutonsPropres.dot = true

-- Les memes mesures que le constructeur : les deux fenetres font le meme
-- geste, elles doivent se ressembler.
local LARGEUR, HAUTEUR = 860, 700
local HAUTEUR_REPLIEE = 280
local DORE = { 0.93, 0.80, 0.52 }
local LIGNE = 22
local ICONE_DEFAUT = "Interface\\Icons\\Spell_Shadow_CallOfBone"

local function Placer(region, point, parent, relPoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relPoint, x, y)
end

local function Trim_(t) return (tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Les deux familles de la colonne de gauche. Elles ne sortent pas du schema de
-- fiche comme celles du constructeur : un dot n'a que quatre jauges a grignoter
-- et deux facons de durer. On les range quand meme en familles repliables,
-- pour que les deux fenetres se lisent pareil.
local function Familles()
    local reglages = (LCM.Equilibrage and LCM.Equilibrage.dot) or {}
    local grignote = {}
    for _, cible in ipairs(D.Cibles()) do
        grignote[#grignote + 1] = { id = cible.id, nom = cible.label, cout = cible.cout, cible = cible }
    end
    return {
        { libelle = "Ce qu'il grignote", champs = grignote },
        { libelle = "Durée et intensité", champs = {
            { id = "rounds", nom = "Rounds", cout = reglages.coutRound or 0 },
            { id = "stacks", nom = "Stacks", cout = reglages.coutStack or 0 },
        } },
    }
end

-- Ce qu'un point investi donne, en clair. C'est ce qu'on lit en depensant.
local function Effet(champ, points)
    local cible = champ.cible
    if points <= 0 or not cible then return "" end
    local texte = cible.plat and string.format("%d par round", cible.plat * points)
        or string.format("%d %% par round", math.ceil((cible.taux or 0) * points * 100 - 1e-9))
    if cible.zonee then texte = texte .. " (note)" end
    return texte
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_DotComposeur", UIParent)
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
    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)
    if UI.AelCadre then f.cadre = UI.AelCadre(f, "section") else UI.Bordure(f) end
    f.titre = UI.Texte(f, "Composer un dot", DORE, "GameFontNormalLarge")
    Placer(f.titre, "TOP", f, "TOP", 0, -12)

    f.choix = { rounds = 0, stacks = 0, penetrations = {} }
    f.conteneur = "etat"
    f.replies = {}

    -- ----- apercu -----------------------------------------------------------
    f.apercu = CreateFrame("Frame", nil, f)
    f.apercu:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.apercu:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -38)
    f.apercu:SetHeight(66)
    f.apercu.fond = UI.Aplat(f.apercu, { 1, 1, 1, 0.05 })
    f.apercu.fond:SetAllPoints(f.apercu)
    UI.BordureFine(f.apercu, 0.3)
    f.icone = f.apercu:CreateTexture(nil, "ARTWORK")
    f.icone:SetSize(44, 44)
    Placer(f.icone, "LEFT", f.apercu, "LEFT", 9, 0)
    f.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icone:SetTexture(ICONE_DEFAUT)
    f.nomApercu = UI.Texte(f.apercu, "", UI.C.titre)
    f.nomApercu:SetPoint("TOPLEFT", f.icone, "TOPRIGHT", 10, -2)
    f.nomApercu:SetPoint("RIGHT", f.apercu, "RIGHT", -230, 0)
    f.descApercu = UI.Texte(f.apercu, "", UI.C.texte, "GameFontNormalSmall")
    f.descApercu:SetPoint("TOPLEFT", f.icone, "TOPRIGHT", 10, -20)
    f.descApercu:SetPoint("RIGHT", f.apercu, "RIGHT", -230, 0)
    f.descApercu:SetWordWrap(false)
    f.effetsApercu = UI.Texte(f.apercu, "", UI.C.discret, "GameFontNormalSmall")
    f.effetsApercu:SetPoint("TOPLEFT", f.icone, "TOPRIGHT", 10, -38)
    f.effetsApercu:SetPoint("RIGHT", f.apercu, "RIGHT", -230, 0)
    f.effetsApercu:SetWordWrap(false)
    f.meta = UI.Texte(f.apercu, "", UI.C.discret, "GameFontNormalSmall")
    Placer(f.meta, "TOPRIGHT", f.apercu, "TOPRIGHT", -10, -8)
    f.meta:SetJustifyH("RIGHT")

    -- ----- la bibliotheque, et le repli -------------------------------------
    f.biblioLibelle = UI.Texte(f, "Bibliothèque", UI.C.discret, "GameFontNormalSmall")
    Placer(f.biblioLibelle, "TOPLEFT", f, "TOPLEFT", 16, -112)
    f.biblio = UI.Bouton(f, "— choisir un modèle —", 300, 22, function(self)
        local modeles = D.Modeles()
        if #modeles == 0 then LCM.Alerte("aucun modèle de dot enregistré pour l'instant.") return end
        local options = {}
        for _, m in ipairs(modeles) do options[#options + 1] = { id = m, label = m.nom } end
        Ecran.choixModele = Ecran.choixModele or UI.Choix("modele_dot", "Bibliothèque")
        Ecran.choixModele:Proposer(self, options, function(modele) f:Charger(modele) end)
    end)
    Placer(f.biblio, "LEFT", f.biblioLibelle, "RIGHT", 10, 0)

    f.enregistrer = UI.Bouton(f, "Enregistrer…", 130, 22, function()
        local ok, raison = D.Enregistrer(f.nom:GetText(), f.desc:GetText(),
            f.iconeChoisie, f.choix, f.conteneur)
        if ok then
            f.modeleCharge = raison
            LCM.Ok(string.format("« %s » enregistré dans la bibliothèque.", tostring(raison)))
            Ecran.Rendre()
        else
            LCM.Alerte(tostring(raison))
        end
    end)
    Placer(f.enregistrer, "LEFT", f.biblio, "RIGHT", 8, 0)

    -- « Configurer » deplie, « Réduire » replie. Replie, la fenetre ne garde
    -- que la bibliotheque : relancer une brulure connue ne demande rien de plus.
    f.replie = true
    f.basculer = UI.Bouton(f, "Configurer", 130, 22, function()
        f.replie = not f.replie
        f:Disposer()
        Ecran.Rendre()
    end)
    Placer(f.basculer, "TOPRIGHT", f, "TOPRIGHT", -16, -112)

    -- ----- gauche : le constructeur -----------------------------------------
    f.separateur = UI.Aplat(f, { 1, 1, 1, 0.08 }, "ARTWORK")
    f.separateur:SetWidth(1)
    f.separateur:SetPoint("TOP", f, "TOP", -6, -116)
    f.separateur:SetPoint("BOTTOM", f, "BOTTOM", -6, 56)

    f.titreGauche = UI.Texte(f, "CONSTRUCTEUR", DORE)
    Placer(f.titreGauche, "TOPLEFT", f, "TOPLEFT", 16, -144)

    -- OU le dot atterrit dans la fenetre Sante de la cible. Il tombait
    -- toujours dans « États » ; une brulure est parfois une maladie.
    f.conteneurLibelle = UI.Texte(f, "Nature", UI.C.discret, "GameFontNormalSmall")
    Placer(f.conteneurLibelle, "TOPLEFT", f, "TOPLEFT", 16, -170)
    f.conteneurs = {}
    for index, conteneur in ipairs(LCM.EtatsTemporaires.CONTENEURS) do
        local b = UI.Bouton(f, conteneur.label, 92, 22, function()
            f.conteneur = conteneur.id
            Ecran.Rendre()
        end)
        b.conteneurId = conteneur.id
        Placer(b, "TOPLEFT", f, "TOPLEFT", 86 + (index - 1) * 96, -168)
        f.conteneurs[index] = b
    end

    f.iconeBouton = CreateFrame("Button", nil, f)
    f.iconeBouton:SetSize(28, 28)
    Placer(f.iconeBouton, "TOPLEFT", f, "TOPLEFT", 16, -196)
    f.iconeBouton.texture = f.iconeBouton:CreateTexture(nil, "ARTWORK")
    f.iconeBouton.texture:SetAllPoints(f.iconeBouton)
    f.iconeBouton.texture:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    f.iconeBouton.texture:SetTexture(ICONE_DEFAUT)
    f.iconeBouton.survol = UI.Aplat(f.iconeBouton, UI.C.survol, "HIGHLIGHT")
    f.iconeBouton.survol:SetAllPoints(f.iconeBouton)
    if UI.AelCadre then
        local support = CreateFrame("Frame", nil, f.iconeBouton)
        support:SetPoint("TOPLEFT", f.iconeBouton, "TOPLEFT", -1, 1)
        support:SetPoint("BOTTOMRIGHT", f.iconeBouton, "BOTTOMRIGHT", 1, -1)
        UI.AelCadre(support, "icone")
    end
    f.iconeBouton:SetScript("OnClick", function(self)
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("dot")
        Ecran.selecteur:Proposer(self, function(chemin)
            f.iconeChoisie = chemin
            f.icone:SetTexture(chemin)
            self.texture:SetTexture(chemin)
            Ecran.Rendre()
        end)
    end)
    UI.Bulle(f.iconeBouton, "Icône", "Clic : choisir l'icône du dot.")

    f.nom = UI.Champ(f, 260, 22, function() Ecran.Rendre() end)
    Placer(f.nom, "LEFT", f.iconeBouton, "RIGHT", 10, 0)

    f.descLibelle = UI.Texte(f, "Description", UI.C.discret, "GameFontNormalSmall")
    Placer(f.descLibelle, "TOPLEFT", f, "TOPLEFT", 16, -230)
    f.desc = UI.Zone(f, 330, 76, function() Ecran.Rendre() end)
    Placer(f.desc, "TOPLEFT", f, "TOPLEFT", 16, -248)

    -- Le capital, en gros : c'est lui qu'on surveille en depensant.
    f.reserve = UI.Texte(f, "", UI.C.titre, "GameFontNormalLarge")
    Placer(f.reserve, "TOPLEFT", f, "TOPLEFT", 16, -334)
    f.duree = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    Placer(f.duree, "TOPLEFT", f, "TOPLEFT", 16, -362)
    f.duree:SetWidth(390)
    f.duree:SetJustifyH("LEFT")

    f.champs = UI.Defilement(f)
    f.champs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -388)
    f.champs:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -22, 140)
    f.entetes, f.lignes = {}, {}

    -- ----- droite : les choix -----------------------------------------------
    f.titreDroite = UI.Texte(f, "CHOIX", DORE)
    Placer(f.titreDroite, "TOPLEFT", f, "TOP", 8, -144)

    -- Deux carres, comme les PA et PF du constructeur : ici le capital et ce
    -- qu'il en reste. Une ligne de texte se lisait comme une note de bas de
    -- page, alors que c'est ce qu'on surveille.
    local function Carre(couleur, libelle)
        local k = CreateFrame("Frame", nil, f)
        k:SetSize(48, 28)
        k.fond = UI.Aplat(k, couleur)
        k.fond:SetAllPoints(k)
        UI.BordureFine(k, 0.5)
        k.titre = UI.Texte(k, libelle, { 0.92, 0.92, 0.88 }, "GameFontNormalSmall")
        k.titre:SetPoint("TOP", k, "TOP", 0, -2)
        k.valeur = UI.Texte(k, "0", UI.C.titre)
        UI.Police(k.valeur, 11)
        k.valeur:SetPoint("BOTTOM", k, "BOTTOM", 0, 2)
        return k
    end
    f.carrePool = Carre({ 0.16, 0.42, 0.22, 0.92 }, "Pool")
    f.carreReste = Carre({ 0.16, 0.26, 0.48, 0.92 }, "Reste")
    Placer(f.carrePool, "TOPRIGHT", f, "TOPRIGHT", -72, -136)
    Placer(f.carreReste, "LEFT", f.carrePool, "RIGHT", 0, 0)

    f.panneau = UI.Defilement(f)
    f.panneau:SetPoint("TOPLEFT", f, "TOP", 8, -166)
    f.panneau:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 140)

    -- Memes questions et grille de trois reponses que Buff et Debuff.
    local function Titre(texte, y)
        local t = UI.Texte(f.panneau.contenu, texte, { 0.62, 0.75, 0.87 }, "GameFontNormalSmall")
        Placer(t, "TOPLEFT", f.panneau.contenu, "TOPLEFT", 4, -y)
        return t
    end
    local largeur, pas = 118, 124
    f.titreSource = Titre("Source du dot", 0)
    f.sources = {}
    for index, id in ipairs((LCM.Equilibrage.dot and LCM.Equilibrage.dot.sources) or {}) do
        local libelle = id
        for _, prim in ipairs(LCM.Equilibrage.primaires or {}) do
            if prim.id == id then libelle = prim.label end
        end
        local b = UI.Bouton(f.panneau.contenu, libelle, largeur, 22, function()
            f.choix.source = id
            Ecran.Rendre()
        end)
        b.sourceId = id
        local col, rang = (index - 1) % 3, math.floor((index - 1) / 3)
        Placer(b, "TOPLEFT", f.panneau.contenu, "TOPLEFT", 4 + col * pas, -(18 + rang * 26))
        f.sources[index] = b
    end
    local y = 18 + math.max(1, math.ceil(#f.sources / 3)) * 26 + 8
    f.titrePen = Titre("Pénétrations (moyenne : 0)", y)
    y = y + 18
    f.penetrations = {}
    for _, groupe in ipairs(LCM.Equilibrage.groupesTypes or {}) do
        Titre(groupe, y)
        y = y + 18
        local index = 0
        for _, ty in ipairs(LCM.Equilibrage.types or {}) do
            if ty.groupe == groupe then
                index = index + 1
                local b = UI.Bouton(f.panneau.contenu, ty.label, largeur, 22, function()
                    local selection = f.choix.penetrations
                    selection[ty.id] = not selection[ty.id] or nil
                    Ecran.Rendre()
                end)
                b.typeId, b.typeLabel = ty.id, ty.label
                local col, rang = (index - 1) % 3, math.floor((index - 1) / 3)
                Placer(b, "TOPLEFT", f.panneau.contenu, "TOPLEFT", 4 + col * pas, -(y + rang * 26))
                f.penetrations[#f.penetrations + 1] = b
            end
        end
        y = y + math.ceil(index / 3) * 26 + 8
    end
    f.titreNiveau = Titre("Niveau du sort", y)
    y = y + 18
    f.niveaux = {}
    for index = 1, 6 do
        local b = UI.Bouton(f.panneau.contenu, "Niveau " .. index, largeur, 22, function()
            f.choix.niveau = index
            Ecran.Rendre()
        end)
        b.niveau = index
        local col, rang = (index - 1) % 3, math.floor((index - 1) / 3)
        Placer(b, "TOPLEFT", f.panneau.contenu, "TOPLEFT", 4 + col * pas, -(y + rang * 26))
        f.niveaux[index] = b
    end
    f.hauteurPanneau = y + 2 * 26 + 10

    f.emoteAction = UI.EmoteAction(f, LARGEUR - 32, 70, "Émote de l'action.")
    Placer(f.emoteAction, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 42)

    -- ----- pied -------------------------------------------------------------
    f.blocage = UI.Texte(f, "", UI.C.plein, "GameFontNormalSmall")
    Placer(f.blocage, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 22)
    f.declarer = UI.Bouton(f, "Déclarer", 150, 26, function() Ecran.Declarer() end)
    Placer(f.declarer, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.annuler = UI.Bouton(f, "Annuler", 110, 26, function() f:Hide() end)
    Placer(f.annuler, "RIGHT", f.declarer, "LEFT", -8, 0)

    -- Tout ce qui ne sert qu'a composer : cache tant qu'on n'a pas deplie.
    function f:Disposer()
        local ouvert = not self.replie
        self.basculer.label:SetText(ouvert and "Réduire" or "Configurer")
        for _, region in ipairs({ self.titreGauche, self.conteneurLibelle, self.nom, self.iconeBouton,
                                  self.descLibelle, self.desc, self.reserve, self.duree, self.champs,
                                  self.titreDroite, self.panneau, self.carrePool, self.carreReste,
                                  self.separateur }) do
            if region then region:SetShown(ouvert) end
        end
        for _, b in ipairs(self.conteneurs) do b:SetShown(ouvert) end
        self:SetHeight(ouvert and HAUTEUR or HAUTEUR_REPLIEE)
    end

    -- ----- l'etat de la composition -----------------------------------------
    function f:Entree()
        return { source = self.choix.source,
                 penetrations = self.choix.penetrations,
                 niveau = tonumber(self.choix.niveau) or 0 }
    end

    function f:Pool() return (D.Pool(LCM.Entities.Self(), self:Entree())) end

    -- Un pas qui ne tient pas dans le pool est refuse et DIT pourquoi : sans
    -- cela on clique trois fois sans comprendre que rien ne bouge.
    function f:Ajouter(cle, pas)
        if not cle then return end
        local avant = tonumber(self.choix[cle]) or 0
        self.choix[cle] = math.max(0, avant + pas)
        if (D.Cout(self.choix)) > self:Pool() then
            self.choix[cle] = avant
            if pas > 0 then LCM.Alerte("le pool n'y suffit pas.") end
        end
        Ecran.Rendre()
    end

    function f:Charger(modele)
        if type(modele) ~= "table" then return false end
        self.choix = {}
        for cle, valeur in pairs(modele.choix or {}) do
            if cle == "penetrations" and type(valeur) == "table" then
                self.choix[cle] = {}
                for id, actif in pairs(valeur) do self.choix[cle][id] = actif end
            else self.choix[cle] = valeur end
        end
        self.choix.penetrations = self.choix.penetrations or {}
        self.choix.rounds = self.choix.rounds or 0
        self.choix.stacks = self.choix.stacks or 0
        self.conteneur = modele.conteneur or "etat"
        self.nom:SetText(modele.nom or "")
        self.desc:SetText(modele.description or "")
        if modele.icone then
            self.iconeChoisie = modele.icone
            self.icone:SetTexture(modele.icone)
            self.iconeBouton.texture:SetTexture(modele.icone)
        end
        self.modeleCharge = modele.nom
        -- Un modele enregistre quand le pool etait plus large peut ne plus
        -- rentrer : on le dit plutot que de laisser declarer un dot ampute.
        if (D.Cout(self.choix)) > self:Pool() then
            LCM.Alerte(string.format("« %s » ne rentre plus dans ton pool : ajuste la source ou le niveau.",
                tostring(modele.nom)))
        end
        Ecran.Rendre()
        return true
    end

    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "LCM_DotComposeur" end
    f:Hide()
    return f
end

function Ecran.Fenetre() return Ecran.frame or Construire() end

-- ===== Rendu ===============================================================

local function Gauche(f)
    local y, nEntete, nLigne = 0, 0, 0
    for indexFamille, famille in ipairs(Familles()) do
        nEntete = nEntete + 1
        local e = f.entetes[nEntete]
        if not e then
            e = UI.Bouton(f.champs.contenu, "", 100, 20, function(self)
                -- `false` : ouverte. La position dans la liste est la cle, pas
                -- le libelle : c'est du texte d'interface, il peut changer.
                f.replies[self.cleFamille] = (f.replies[self.cleFamille] == false)
                Ecran.Rendre()
            end)
            e:RegisterForClicks("LeftButtonUp")
            e.label:SetJustifyH("LEFT")
            f.entetes[nEntete] = e
        end
        e.cleFamille = indexFamille
        local mis = 0
        for _, ch in ipairs(famille.champs) do mis = mis + (tonumber(f.choix[ch.id]) or 0) end
        e.label:SetText(string.format("[%s] %s  |cff9a9a9a(%d champ%s)|r%s",
            f.replies[indexFamille] == false and "-" or "+",
            famille.libelle, #famille.champs, #famille.champs > 1 and "s" or "",
            mis > 0 and ("  |cffffd200" .. mis .. "|r") or ""))
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", f.champs.contenu, "TOPLEFT", 0, -y)
        e:SetPoint("TOPRIGHT", f.champs.contenu, "TOPRIGHT", 0, -y)
        e:Show()
        y = y + 24

        -- Ouvertes par defaut : il n'y en a que deux, et la premiere chose
        -- qu'on vient faire ici est de choisir ce qu'on grignote.
        if f.replies[indexFamille] == nil then f.replies[indexFamille] = false end
        if f.replies[indexFamille] == false then
            for _, ch in ipairs(famille.champs) do
                nLigne = nLigne + 1
                local l = f.lignes[nLigne]
                if not l then
                    l = CreateFrame("Frame", nil, f.champs.contenu)
                    l:SetHeight(LIGNE)
                    l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                    Placer(l.nom, "LEFT", l, "LEFT", 14, 0)
                    l.plus = UI.Bouton(l, "+", 20, 18, function(self)
                        local pas = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
                        f:Ajouter(self:GetParent().cle, pas)
                    end)
                    Placer(l.plus, "RIGHT", l, "RIGHT", -2, 0)
                    l.valeur = UI.Texte(l, "0", UI.C.titre, "GameFontNormalSmall")
                    l.valeur:SetWidth(28)
                    l.valeur:SetJustifyH("CENTER")
                    Placer(l.valeur, "RIGHT", l.plus, "LEFT", -2, 0)
                    l.moins = UI.Bouton(l, "−", 20, 18, function(self)
                        local pas = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
                        f:Ajouter(self:GetParent().cle, -pas)
                    end)
                    Placer(l.moins, "RIGHT", l.valeur, "LEFT", -2, 0)
                    l.cout = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
                    Placer(l.cout, "RIGHT", l.moins, "LEFT", -8, 0)
                    l.effet = UI.Texte(l, "", UI.C.accent, "GameFontNormalSmall")
                    Placer(l.effet, "RIGHT", l.cout, "LEFT", -10, 0)
                    f.lignes[nLigne] = l
                end
                local points = tonumber(f.choix[ch.id]) or 0
                l.cle = ch.id
                l.nom:SetText(ch.nom)
                l.valeur:SetText(tostring(points))
                l.cout:SetText(string.format("%d pt%s", ch.cout, ch.cout > 1 and "s" or ""))
                l.effet:SetText(Effet(ch, points))
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", f.champs.contenu, "TOPLEFT", 0, -y)
                l:SetPoint("TOPRIGHT", f.champs.contenu, "TOPRIGHT", 0, -y)
                l:Show()
                y = y + LIGNE
            end
        end
    end
    for i = nEntete + 1, #f.entetes do f.entetes[i]:Hide() end
    for i = nLigne + 1, #f.lignes do f.lignes[i]:Hide() end
    f.champs:Regler(math.max(1, y))

    local pool, cout = f:Pool(), (D.Cout(f.choix))
    f.reserve:SetText(string.format("Pool : %d / %d", cout, pool))
    local couleur = cout > pool and UI.C.plein or UI.C.titre
    f.reserve:SetTextColor(couleur[1], couleur[2], couleur[3])
    local compose = D.Composer(f.choix)
    local reglages = LCM.Equilibrage.dot or {}
    f.duree:SetText(string.format("Durée : %d round%s · %d stack%s   (+1 round = %d pt, +1 stack = %d pt)",
        compose.rounds, compose.rounds > 1 and "s" or "",
        compose.stacks, compose.stacks > 1 and "s" or "",
        reglages.coutRound or 0, reglages.coutStack or 0))
end

local function Droite(f)
    for _, b in ipairs(f.sources) do b:Selectionner(f.choix.source == b.sourceId) end
    local entity = LCM.Entities.Self()
    for _, b in ipairs(f.penetrations) do
        local valeur = tonumber(LCM.Actions.ValeurType(b.typeId, "Penetrations", entity)) or 0
        b.label:SetText(string.format("%s (%s)", b.typeLabel, tostring(valeur)))
        b:SetEnabled(valeur > 0)
        b:Selectionner(f.choix.penetrations and f.choix.penetrations[b.typeId] == true)
    end
    f.titrePen:SetText(string.format("Pénétrations (moyenne : %s)",
        tostring(D.PenetrationMoyenne(entity, f.choix.penetrations))))
    for _, b in ipairs(f.niveaux) do b:Selectionner(tonumber(f.choix.niveau) == b.niveau) end
    f.panneau:Regler(f.hauteurPanneau)
    local pool, cout = f:Pool(), (D.Cout(f.choix))
    f.carrePool.valeur:SetText(tostring(pool))
    f.carreReste.valeur:SetText(tostring(pool - cout))
    local couleur = (pool - cout) < 0 and UI.C.plein or UI.C.titre
    f.carreReste.valeur:SetTextColor(couleur[1], couleur[2], couleur[3])
end

function Ecran.Rendre()
    local f = Ecran.frame
    if not f then return end
    for _, b in ipairs(f.conteneurs) do b:Selectionner(f.conteneur == b.conteneurId) end
    Gauche(f)
    Droite(f)

    -- L'apercu : ce qu'on est en train de faire, une ligne chacun.
    local nom = Trim_(f.nom:GetText())
    f.nomApercu:SetText(nom ~= "" and nom or "Dot sans nom")
    local desc = Trim_(f.desc:GetText())
    f.descApercu:SetText(desc ~= "" and desc or "(aucune description)")
    local compose = D.Composer(f.choix)
    local bouts = {}
    for _, morsure in ipairs(compose.morsures) do
        bouts[#bouts + 1] = string.format("%s %s", morsure.label,
            morsure.plat and (morsure.plat .. "/round")
            or (math.ceil((morsure.taux or 0) * 100 - 1e-9) .. " %/round"))
    end
    f.effetsApercu:SetText(#bouts > 0 and table.concat(bouts, "  ·  ") or "(ne grignote rien)")
    local pool, cout = f:Pool(), (D.Cout(f.choix))
    f.meta:SetText(string.format("Pool : %d / %d\nDurée : %d round%s · %d stack%s",
        cout, pool, compose.rounds, compose.rounds > 1 and "s" or "",
        compose.stacks, compose.stacks > 1 and "s" or ""))

    local pret = #compose.morsures > 0 and cout <= pool
    f.blocage:SetText(#compose.morsures == 0 and "Choisis au moins une jauge à grignoter."
        or (cout > pool and "Le pool n'y suffit pas." or ""))
    f.declarer:SetEnabled(pret)
    f.declarer:Selectionner(pret)
end

-- ===== Declarer ============================================================

function Ecran.Declarer()
    local f = Ecran.frame
    if not f then return end
    local compose = D.Composer(f.choix)
    if #compose.morsures == 0 then LCM.Alerte("ce dot ne grignote rien.") return end
    if (D.Cout(f.choix)) > f:Pool() then LCM.Alerte("le pool n'y suffit pas.") return end
    local nom = Trim_(f.nom:GetText())
    if nom == "" then nom = "Dot" end

    Ecran.choixCibles = Ecran.choixCibles or UI.ChoixJoueurs("dot")
    Ecran.choixCibles:Proposer(string.format("Sur qui poser « %s » ?", nom), function(noms)
        if #noms == 0 then return false, "choisis au moins une cible." end
        -- Le jet du lanceur : c'est lui que la dissipation devra battre, et
        -- c'est de lui que part la decroissance du rand.
        local jet = LCM.Roll.Field(LCM.Entities.Self(), "esprit")
        local valeur = jet and jet.total or 0
        local paquet = {
            t = "dot_" .. tostring(GetTime and math.floor(GetTime() * 100) or 0),
            nom = nom, a = LCM.PlayerId(),
            rp = LCM.Identite.NomEnJeu(LCM.Entities.Self()),
            desc = Trim_(f.desc:GetText()),
            ic = f.iconeChoisie,
            deb = 1, js = "Esprit", jr = valeur,
            ct = LCM.EtatsTemporaires.ConteneurValide(f.conteneur),
            dt = f.choix,
        }
        for _, cible in ipairs(noms) do
            LCM.Reseau.Envoyer("etat", paquet, "WHISPER", cible)
        end
        local emote, canal = f.emoteAction:Lire()
        if emote:match("%S") then LCM.Actions.DireEmoteAction(emote, canal) end
        LCM.Ok(string.format("« %s » envoyé à %s (jet %d).", nom, table.concat(noms, ", "), valeur))
        f:Hide()
        return true
    end)
end

function Ecran.Ouvrir()
    local f = Ecran.Fenetre()
    -- On garde la source, la penetration et le niveau d'une fois sur l'autre :
    -- c'est le personnage et son sort qui les dictent, pas le dot qu'on
    -- compose. Le reste repart a zero.
    f.choix = { rounds = 0, stacks = 0, source = f.choix and f.choix.source,
                penetrations = f.choix and f.choix.penetrations or {},
                niveau = f.choix and f.choix.niveau }
    f.modeleCharge = nil
    f.emoteAction:Reset()
    f:Disposer()
    Ecran.Rendre()
    f:Show()
    f:Raise()
    return f
end

LCM.WhenReady(function()
    if UI.Radial and UI.Radial.Lier then UI.Radial.Lier("dot", Ecran.Ouvrir) end
end)

LCM.AddCommand("dot", "compose un dot", function() Ecran.Ouvrir() end)
