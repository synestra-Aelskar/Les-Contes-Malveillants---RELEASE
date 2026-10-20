-- La fenetre du constructeur de buff et de debuff.
--
-- Plan de Necronicon (RunBuffComposer : « fenetre UNIQUE : apercu en haut,
-- constructeur a gauche, familles repliables, choix a droite, carres de cout ») ;
-- 860 de large comme la sienne, moins haute : nos familles sont plus courtes
-- que son modele d'etats. La logique est dans Core/Actions.lua (Constructeur) :
-- la fenetre montre, et transmet les clics.
--
-- Ecart voulu : pas de choix d'un modele d'etat du compendium (notre fiche
-- n'en a qu'un genre, les champs). « Illimite » n'apparait que si l'action le
-- permet (aucune regle du template ne l'active aujourd'hui).

local _, LCM = ...
local UI = LCM.UI
local A = LCM.Actions

local Ecran = {}
UI.Constructeur = Ecran

local LARGEUR, HAUTEUR = 860, 700
-- Repliee, la fenetre ne montre que l'apercu et la rangee de boutons : de quoi
-- declarer un effet tout pret sans dérouler quatre-vingts champs. On ne deplie
-- que pour composer vraiment.
local HAUTEUR_REPLIEE = 280
local DORE = { 0.93, 0.80, 0.52 }
local LIGNE = 22
-- Le cote d'un carre de cout, colle au rectangle du nom d'une option.
local COTE_COUT = 22

local function Placer(region, point, parent, relPoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relPoint, x, y)
end

local function Trim_(t) return (tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function Arrondi(v) return tostring(math.floor((tonumber(v) or 0) + 0.5)) end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Constructeur", UIParent)
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
    f.titre = UI.Texte(f, "", DORE, "GameFontNormalLarge")
    Placer(f.titre, "TOP", f, "TOP", 0, -12)

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

    -- ----- gauche : le constructeur ----------------------------------------
    f.separateur = UI.Aplat(f, { 1, 1, 1, 0.08 }, "ARTWORK")
    f.separateur:SetWidth(1)
    f.separateur:SetPoint("TOP", f, "TOP", -6, -116)
    f.separateur:SetPoint("BOTTOM", f, "BOTTOM", -6, 56)

    f.titreGauche = UI.Texte(f, "CONSTRUCTEUR", DORE)
    Placer(f.titreGauche, "TOPLEFT", f, "TOPLEFT", 16, -144)

    -- OU l'effet atterrit dans la fenetre Sante du joueur : Etat, Maladie ou
    -- Intangible. C'est la premiere chose a decider — ca dit de quoi on parle,
    -- avant meme de le nommer. Sans ce choix tout tombait dans « Etats », et
    -- une maladie se lisait au milieu des immobilisations.
    f.conteneurLibelle = UI.Texte(f, "Nature", UI.C.discret, "GameFontNormalSmall")
    Placer(f.conteneurLibelle, "TOPLEFT", f, "TOPLEFT", 16, -170)
    f.conteneurs = {}
    for index, conteneur in ipairs(LCM.EtatsTemporaires.CONTENEURS) do
        local b = UI.Bouton(f, conteneur.label, 92, 22, function()
            f.constructeur.conteneur = conteneur.id
            Ecran.Rendre()
        end)
        b.conteneurId = conteneur.id
        Placer(b, "TOPLEFT", f, "TOPLEFT", 86 + (index - 1) * 96, -168)
        f.conteneurs[index] = b
    end

    -- L'icone se CHOISIT : l'apercu est un bouton, comme dans l'atelier et le
    -- compendium. Il n'y avait aucun moyen d'en changer depuis ici.
    f.iconeBouton = CreateFrame("Button", nil, f)
    f.iconeBouton:SetSize(28, 28)
    Placer(f.iconeBouton, "TOPLEFT", f, "TOPLEFT", 16, -196)
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
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("constructeur")
        Ecran.selecteur:Proposer(self, function(chemin)
            f.icone:SetTexture(chemin)
            f.iconeBouton.texture:SetTexture(chemin)
            f.iconeChoisie = chemin
            Ecran.Rendre()
        end)
    end)
    UI.Bulle(f.iconeBouton, "Icône", "Clic : choisir l'icône de l'effet.")

    f.nom = UI.Champ(f, 260, 22, function() Ecran.Rendre() end)
    Placer(f.nom, "LEFT", f.iconeBouton, "RIGHT", 10, 0)

    f.descLibelle = UI.Texte(f, "Description", UI.C.discret, "GameFontNormalSmall")
    Placer(f.descLibelle, "TOPLEFT", f, "TOPLEFT", 16, -230)
    -- Une VRAIE boite : une ligne de 22 px pour decrire un effet, on n'ecrivait
    -- rien. Celle de Necronicon fait quatre lignes, celle-ci aussi.
    f.desc = UI.Zone(f, 330, 76, function() Ecran.Rendre() end)
    Placer(f.desc, "TOPLEFT", f, "TOPLEFT", 16, -248)

    f.reserve = UI.Texte(f, "", UI.C.titre, "GameFontNormalLarge")
    Placer(f.reserve, "TOPLEFT", f, "TOPLEFT", 16, -334)
    f.duree = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    Placer(f.duree, "TOPLEFT", f, "TOPLEFT", 16, -362)
    f.dureeMoins = UI.Bouton(f, "−", 22, 20, function() f.constructeur:AcheterDuree(-1) Ecran.Rendre() end)
    Placer(f.dureeMoins, "TOPLEFT", f, "TOPLEFT", 300, -358)
    f.dureePlus = UI.Bouton(f, "+", 22, 20, function() f.constructeur:AcheterDuree(1) Ecran.Rendre() end)
    Placer(f.dureePlus, "LEFT", f.dureeMoins, "RIGHT", 4, 0)
    -- « Illimite » : seulement quand l'action le permet (regle `permanent`).
    f.illimite = UI.Bouton(f, "Illimité", 70, 20, function()
        f.constructeur:Illimite(not f.constructeur.illimite)
        Ecran.Rendre()
    end)
    Placer(f.illimite, "LEFT", f.dureePlus, "RIGHT", 8, 0)

    f.champs = UI.Defilement(f)
    f.champs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -388)
    f.champs:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -22, 140)
    f.entetes, f.lignes = {}, {}
    f.replies = {}

    -- ----- droite : les choix -----------------------------------------------
    f.titreDroite = UI.Texte(f, "CHOIX", DORE)
    Placer(f.titreDroite, "TOPLEFT", f, "TOP", 8, -144)
    f.choix = UI.Defilement(f)
    f.choix:SetPoint("TOPLEFT", f, "TOP", 8, -166)
    f.choix:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 140)
    f.questions, f.options = {}, {}

    -- Les deux reserves en CARRES, aux couleurs du jeu (PA vert, PF bleu),
    -- comme chez Necronicon. Une ligne de texte « PA 0 · PF 0 » se lisait
    -- comme une note de bas de page, alors que c'est ce qu'on surveille.
    local function Carre(couleur, libelle)
        local k = CreateFrame("Frame", nil, f)
        k:SetSize(48, 28)
        k.fond = UI.Aplat(k, couleur)
        k.fond:SetAllPoints(k)
        UI.BordureFine(k, 0.5)
        k.titre = UI.Texte(k, libelle, { 0.92, 0.92, 0.88 }, "GameFontNormalSmall")
        k.titre:SetPoint("TOP", k, "TOP", 0, -2)
        k.valeur = UI.Texte(k, "0 / 0", UI.C.titre)
        UI.Police(k.valeur, 11)
        k.valeur:SetPoint("BOTTOM", k, "BOTTOM", 0, 2)
        return k
    end
    f.carrePA = Carre({ 0.16, 0.42, 0.22, 0.92 }, "PA")
    f.carrePF = Carre({ 0.16, 0.26, 0.48, 0.92 }, "PF")
    -- Sur la ligne du titre CHOIX, au-DESSUS de la liste. Poses a -168 ils
    -- tombaient dans la zone qui commence a -166 : ils recouvraient la premiere
    -- rangee de choix (« Perception »), et leurs 62 x 42 debordaient du bord
    -- droit de cette zone (5 octobre 2026).
    Placer(f.carrePA, "TOPRIGHT", f, "TOPRIGHT", -72, -136)
    -- Colles l'un a l'autre : c'est une seule information en deux moities.
    Placer(f.carrePF, "LEFT", f.carrePA, "RIGHT", 0, 0)

    f.couts = UI.Texte(f, "", UI.C.texte)
    Placer(f.couts, "BOTTOMLEFT", f, "BOTTOM", 8, 114)
    f.absents = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    f.absents:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 94)
    f.absents:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.absents:SetWordWrap(true)

    -- La narration appartient aussi aux buffs et aux debuffs. Ces deux actions
    -- passent par ce constructeur (et non par le composeur generique), elles
    -- avaient donc ete les seules declarations sans champ d'emote.
    f.emoteAction = UI.EmoteAction(f, LARGEUR - 32, 70, "Émote de l'action.")
    Placer(f.emoteAction, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 42)

    -- ----- pied -------------------------------------------------------------
    f.blocage = UI.Texte(f, "", UI.C.plein, "GameFontNormalSmall")
    Placer(f.blocage, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 22)
    f.declarer = UI.Bouton(f, "Déclarer", 150, 26, function() Ecran.Declarer() end)
    Placer(f.declarer, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.annuler = UI.Bouton(f, "Annuler", 110, 26, function() f:Hide() end)
    Placer(f.annuler, "RIGHT", f.declarer, "LEFT", -8, 0)
    f:SetScript("OnHide", function()
        local annuler = f.rappelAnnuler
        f.rappelValider, f.rappelAnnuler = nil, nil
        if annuler then annuler() end
    end)
    -- La bibliotheque : choisir un modele enregistre, ou enregistrer celui
    -- qu'on vient de composer. Elle reste visible REPLIEE — c'est tout
    -- l'interet du repli : declarer « Vigueur » sans rien derouler.
    f.biblioLibelle = UI.Texte(f, "Bibliothèque", UI.C.discret, "GameFontNormalSmall")
    Placer(f.biblioLibelle, "TOPLEFT", f, "TOPLEFT", 16, -112)
    f.biblio = UI.Bouton(f, "— choisir un modèle —", 300, 22, function(self)
        local c = f.constructeur
        if not c then return end
        local modeles = A.ModelesPour(c)
        if #modeles == 0 then
            LCM.Alerte("aucun modèle enregistré pour l'instant.")
            return
        end
        local options = {}
        for _, m in ipairs(modeles) do
            options[#options + 1] = { id = m, label = m.nom }
        end
        local choix = Ecran.choixModele or UI.Choix("modele_effet", "Bibliothèque")
        Ecran.choixModele = choix
        choix:Proposer(self, options, function(modele)
            local ok, refuses = c:Charger(modele)
            if ok then
                f.nom:SetText(modele.nom or "")
                f.desc:SetText(modele.description or "")
                if modele.icone then
                    f.iconeChoisie = modele.icone
                    f.icone:SetTexture(modele.icone)
                    f.iconeBouton.texture:SetTexture(modele.icone)
                end
                f.modeleCharge = modele.nom
                if type(refuses) == "table" and #refuses > 0 then
                    -- On le DIT : un modele qui ne rentre plus (reserve plus
                    -- courte, cout monte) se charge en partie, et le taire
                    -- ferait declarer un effet amputé sans le savoir.
                    LCM.Alerte(string.format("« %s » ne rentre plus entièrement : %d champ(s) écarté(s).",
                        tostring(modele.nom), #refuses))
                end
                Ecran.Rendre()
            end
        end)
    end)
    Placer(f.biblio, "LEFT", f.biblioLibelle, "RIGHT", 10, 0)

    f.enregistrer = UI.Bouton(f, "Enregistrer…", 130, 22, function()
        local c = f.constructeur
        if not c then return end
        local nom = f.nom:GetText() or ""
        local ok, raison = c:Enregistrer(nom, f.desc:GetText() or "", f.iconeChoisie)
        if ok then
            f.modeleCharge = nom
            LCM.Ok(string.format("« %s » enregistré dans la bibliothèque.", nom))
            Ecran.Rendre()
        else
            LCM.Alerte(tostring(raison))
        end
    end)
    Placer(f.enregistrer, "LEFT", f.biblio, "RIGHT", 8, 0)

    -- « Configurer » deplie, « Réduire » replie.
    --
    -- Sur la MEME rangee que la bibliotheque, a l'autre bout : une ligne plus
    -- bas, il tombait sur « Déclarer » des que la fenetre etait repliee — et
    -- repliee, c'est son etat de depart (5 octobre 2026).
    f.replie = true
    f.basculer = UI.Bouton(f, "Configurer", 130, 22, function()
        f.replie = not f.replie
        f:Disposer()
        Ecran.Rendre()
    end)
    Placer(f.basculer, "TOPRIGHT", f, "TOPRIGHT", -16, -112)

    -- Tout ce qui ne sert qu'a composer : cache tant qu'on n'a pas deplie.
    function f:Disposer()
        local ouvert = not self.replie
        self.basculer.label:SetText(ouvert and "Réduire" or "Configurer")
        for _, region in ipairs({ self.titreGauche, self.conteneurLibelle, self.nom, self.iconeBouton,
                                  self.descLibelle, self.desc, self.reserve, self.duree,
                                  self.dureeMoins, self.dureePlus, self.champs,
                                  self.titreDroite, self.choix, self.absents,
                                  self.carrePA, self.carrePF }) do
            if region then region:SetShown(ouvert) end
        end
        for _, b in ipairs(self.conteneurs) do b:SetShown(ouvert) end
        if self.illimite then self.illimite:SetShown(ouvert and self.constructeur ~= nil
            and self.constructeur.regles.permanent == true) end
        self:SetHeight(ouvert and HAUTEUR or HAUTEUR_REPLIEE)
    end

    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "LCM_Constructeur" end
    f:Hide()
    return f
end

function Ecran.Fenetre() return Ecran.frame or Construire() end

-- ===== Rendu ===============================================================

local function Gauche(f)
    local c = f.constructeur
    local y = 0
    local nEntete, nLigne = 0, 0
    local plages = {}
    for indexFamille, famille in ipairs(c.familles) do
        nEntete = nEntete + 1
        local e = f.entetes[nEntete]
        if not e then
            e = UI.Bouton(f.champs.contenu, "", 100, 20, function(self)
                -- `false` : ouverte. Un clic ouvre une famille fermee, et ferme
                -- une famille ouverte. La position dans la liste est la cle :
                -- le libelle est du texte d'interface et peut etre homonyme ou
                -- changer avec le schema de fiche.
                local ouverte = f.replies[self.cleFamille] == false
                f.replies[self.cleFamille] = ouverte
                f.familleAReveler = not ouverte and self.cleFamille or nil
                Ecran.Rendre()
            end)
            e:RegisterForClicks("LeftButtonUp")
            e.label:SetJustifyH("LEFT")
            f.entetes[nEntete] = e
        end
        e.cleFamille = indexFamille
        e.libelle = famille.libelle
        local mis = 0
        for _, ch in ipairs(famille.champs) do mis = mis + (c.points[ch.id] or 0) end
        -- « [+] Pénétrations — Élémentaire  (6 champs) », comme Necronicon. Le
        -- prix ne s'affiche que s'il vaut pour toute la famille ; sinon il est
        -- sur chaque ligne, ou il est juste.
        e.label:SetText(string.format("[%s] %s  |cff9a9a9a(%d champ%s%s)|r%s",
            f.replies[indexFamille] == false and "-" or "+",
            famille.libelle, #famille.champs, #famille.champs > 1 and "s" or "",
            famille.cout and (", " .. tostring(famille.cout) .. " pt") or "",
            mis > 0 and ("  |cffffd200" .. mis .. "|r") or ""))
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", f.champs.contenu, "TOPLEFT", 0, -y)
        e:SetPoint("TOPRIGHT", f.champs.contenu, "TOPRIGHT", 0, -y)
        e:Show()
        y = y + 24
        -- Replie par defaut, sauf ce qu'on a deja touche : quatre-vingts champs
        -- deplies d'un coup ne se lisent pas.
        local hautFamille = y - 24
        local ouverte = f.replies[indexFamille] == false or (f.replies[indexFamille] == nil and mis > 0)
        if ouverte then
            f.replies[indexFamille] = false
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
                        f.constructeur:Ajouter(self:GetParent().champ, pas)
                        Ecran.Rendre()
                    end)
                    Placer(l.plus, "RIGHT", l, "RIGHT", -2, 0)
                    l.valeur = UI.Texte(l, "0", UI.C.titre, "GameFontNormalSmall")
                    l.valeur:SetWidth(28)
                    l.valeur:SetJustifyH("CENTER")
                    Placer(l.valeur, "RIGHT", l.plus, "LEFT", -2, 0)
                    l.moins = UI.Bouton(l, "−", 20, 18, function(self)
                        local pas = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
                        f.constructeur:Ajouter(self:GetParent().champ, -pas)
                        Ecran.Rendre()
                    end)
                    Placer(l.moins, "RIGHT", l.valeur, "LEFT", -2, 0)
                    l.cout = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
                    Placer(l.cout, "RIGHT", l.moins, "LEFT", -8, 0)
                    f.lignes[nLigne] = l
                end
                l.champ = ch.id
                l.nom:SetText(ch.nom)
                l.valeur:SetText(tostring(c.points[ch.id] or 0))
                local cout = c:Cout(ch.id)
                -- En vert quand un choix a fait BAISSER le prix de ce champ :
                -- on compare au prix de base du champ, pas a celui de la
                -- famille, qui n'est plus forcement unique.
                l.cout:SetText(cout ~= ch.cout and string.format("|cff9be08f%s pt|r", Arrondi(cout * 10) / 10)
                    or (cout .. " pt"))
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", f.champs.contenu, "TOPLEFT", 0, -y)
                l:SetPoint("TOPRIGHT", f.champs.contenu, "TOPRIGHT", 0, -y)
                l:Show()
                y = y + LIGNE
            end
        end
        plages[indexFamille] = { haut = hautFamille, bas = y }
    end
    for i = nEntete + 1, #f.entetes do f.entetes[i]:Hide() end
    for i = nLigne + 1, #f.lignes do f.lignes[i]:Hide() end
    f.champs:Regler(y)

    -- Une famille proche du bas s'ouvrait sous le bord rogne de la liste : le
    -- signe changeait, mais aucun champ n'apparaissait a l'ecran et le menu
    -- semblait inactif. Au clic d'ouverture, on garde son entete et ses lignes
    -- dans la zone visible.
    local cle = f.familleAReveler
    local plage = cle and plages[cle]
    if plage then
        local debut = f.champs.decalage or 0
        local finVisible = debut + (f.champs:GetHeight() or 0)
        if plage.haut < debut or plage.bas > finVisible then
            f.champs:Aller(plage.haut)
        end
    end
    f.familleAReveler = nil
end

local function Droite(f)
    local c = f.constructeur.composeur
    local largeur = f.choix:GetWidth()
    if not largeur or largeur < 40 then largeur = 390 end
    local y, nQ, nO = 0, 0, 0
    for _, q in ipairs(c:Visibles()) do
        nQ = nQ + 1
        local t = f.questions[nQ]
        if not t then
            t = UI.Texte(f.choix.contenu, "", { 0.62, 0.75, 0.87 }, "GameFontNormalSmall")
            f.questions[nQ] = t
        end
        t:SetText(q.label)
        Placer(t, "TOPLEFT", f.choix.contenu, "TOPLEFT", 0, -y)
        t:Show()
        y = y + 18
        local options = c:Options(q)
        local colonnes = 3
        local l = math.floor((largeur - (colonnes - 1) * 6) / colonnes)
        for i, o in ipairs(options) do
            nO = nO + 1
            local b = f.options[nO]
            if not b then
                b = UI.Bouton(f.choix.contenu, "", 100, 22, function(self)
                    local cc = f.constructeur.composeur
                    if self.q.mode == "multi" then cc:Cocher(self.q, self.o.id, not cc:EstChoisie(self.q, self.o.id))
                    else cc:Repondre(self.q, self.o.id) end
                    Ecran.Rendre()
                end)
                b.label:SetWordWrap(true)
                -- Le cout en deux CARRES colles au rectangle du nom, aux
                -- couleurs des jauges (PA vert, PF bleu). Ecrit dans le libelle
                -- (« Monocible (2 PA 1 PF) »), il mangeait la place du nom et
                -- se lisait comme une parenthese, alors que c'est le prix.
                local function Pastille(couleur)
                    local k = CreateFrame("Frame", nil, b)
                    k:SetSize(COTE_COUT, 22)
                    k.fond = UI.Aplat(k, couleur)
                    k.fond:SetAllPoints(k)
                    k.valeur = UI.Texte(k, "", { 0.95, 0.95, 0.92 }, "GameFontNormalSmall")
                    k.valeur:SetAllPoints(k)
                    k.valeur:SetJustifyH("CENTER")
                    return k
                end
                b.pa = Pastille({ 0.16, 0.42, 0.22, 0.95 })
                b.pf = Pastille({ 0.16, 0.26, 0.48, 0.95 })
                b.pf:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
                b.pa:SetPoint("TOPRIGHT", b.pf, "TOPLEFT", 0, 0)
                f.options[nO] = b
            end
            b.q, b.o = q, o
            b:SetSize(l, 22)
            local col, rang = (i - 1) % colonnes, math.floor((i - 1) / colonnes)
            Placer(b, "TOPLEFT", f.choix.contenu, "TOPLEFT", col * (l + 6), -y - rang * 26)
            -- Les carres ne s'affichent que s'il y a un prix : une option
            -- gratuite n'a pas a porter deux zeros.
            local aPA, aPF = o.pa ~= 0, o.pf ~= 0
            b.pa:SetShown(aPA)
            b.pf:SetShown(aPF)
            if aPA then b.pa.valeur:SetText(tostring(o.pa)) end
            if aPF then b.pf.valeur:SetText(tostring(o.pf)) end
            -- Le nom garde le rectangle qui reste.
            local pris = (aPA and COTE_COUT or 0) + (aPF and COTE_COUT or 0)
            b.label:ClearAllPoints()
            b.label:SetPoint("LEFT", b, "LEFT", 5, 0)
            b.label:SetPoint("RIGHT", b, "RIGHT", -(pris + 4), 0)
            b.label:SetJustifyH("LEFT")
            b.label:SetText(o.label)
            b:Selectionner(c:EstChoisie(q, o.id))
            b:Show()
        end
        y = y + math.ceil(#options / colonnes) * 26 + 8
    end
    for i = nQ + 1, #f.questions do f.questions[i]:Hide() end
    for i = nO + 1, #f.options do f.options[i]:Hide() end
    f.choix:Regler(y)
end

function Ecran.Rendre()
    local f = Ecran.frame
    local c = f.constructeur
    if not c then return end
    local mot = c.debuff and "Débuff" or "Buff"
    -- Le volet de Sante choisi s'allume : c'est la premiere decision, elle doit
    -- se voir sans la chercher.
    for _, b in ipairs(f.conteneurs) do b:Selectionner(b.conteneurId == c.conteneur) end
    local reserve, depense = c:Reserve(), c:Depense()
    local duree = c:Duree()
    local nom = f.nom:GetText() or ""
    f.nomApercu:SetText(nom ~= "" and nom or ("|cff9a9a9a" .. mot .. " sans nom|r"))
    f.descApercu:SetText(f.desc:GetText() or "")
    local effets = {}
    for champ, n in pairs(c.points) do
        local field = LCM.Schema.Field(champ)
        effets[#effets + 1] = string.format("%s %+d", field and field.label or champ, c.debuff and -n or n)
    end
    table.sort(effets)
    f.effetsApercu:SetText(#effets > 0 and table.concat(effets, ", ") or "|cff9a9a9a(aucun effet)|r")
    f.meta:SetText(string.format("Réserve : %s / %d\nDurée : %s", Arrondi(depense), reserve,
        duree and (duree .. " round" .. (duree > 1 and "s" or "")) or "jusqu'à dissipation"))
    f.reserve:SetText(string.format("Points : |cff%s%s|r / %d", depense > reserve + 0.001 and "ff5959" or "ffd200",
        Arrondi(depense), reserve))
    f.duree:SetText(string.format("Durée : %s  |cff9a9a9a(+1 round = %d pt)|r",
        duree and (duree .. " round" .. (duree > 1 and "s" or "")) or "jusqu'à dissipation", c:ParRound()))
    f.illimite:SetShown(not f.replie and c.regles.permanent == true)
    f.illimite:Selectionner(c.illimite == true)
    f.illimite.label:SetText(string.format("Illimité (%d pt)", c.regles.permanentCost or 0))
    Gauche(f)
    Droite(f)
    local pa, pf = c.composeur:Deriver()
    local dpa, dpf = A.Disponible(c.ctx.entity, c.ctx.recu ~= nil)
    f.couts:SetText("")
    local montreCout = not c.etape.hideCost
    f.carrePA:SetShown(montreCout and not f.replie)
    f.carrePF:SetShown(montreCout and not f.replie)
    if montreCout then
        f.carrePA.valeur:SetText(string.format("%s / %s", Arrondi(pa), Arrondi(dpa)))
        f.carrePF.valeur:SetText(string.format("%s / %s", Arrondi(pf), Arrondi(dpf)))
        -- En rouge quand on depasse : c'est ce qui bloque la declaration.
        local function teinte(carre, depense, dispo)
            if depense > dispo then carre.valeur:SetTextColor(1, 0.35, 0.3)
            else carre.valeur:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3]) end
        end
        teinte(f.carrePA, pa, dpa)
        teinte(f.carrePF, pf, dpf)
    end
    local nomSaisi = Trim_(f.nom:GetText() or "")
    f.enregistrer:SetEnabled(nomSaisi ~= "")
    f.enregistrer:SetAlpha(nomSaisi ~= "" and 1 or 0.4)
    f.biblio.label:SetText(f.modeleCharge and ("Modèle : " .. f.modeleCharge) or "— choisir un modèle —")
    f.absents:SetText(#c.absents > 0 and ("Sans champ sur notre fiche : " .. table.concat(c.absents, ", ")) or "")
    local blocage = c:Blocage()
    f.blocage:SetText(blocage or "")
    f.declarer:SetEnabled(blocage == nil)
    f.declarer:SetAlpha(blocage and 0.4 or 1)
end

function Ecran.Ouvrir(constructeur, valider, annuler)
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() end
    f.constructeur, f.rappelValider, f.rappelAnnuler = constructeur, valider, annuler
    f.replies = {}
    f.titre:SetText(constructeur.debuff and "Construire un débuff" or "Construire un buff")
    f.iconeChoisie = nil
    local icone = LCM.Icone(constructeur.ctx.icone)
    f.icone:SetTexture(icone)
    f.iconeBouton.texture:SetTexture(icone)
    f.nom:SetText("")
    f.desc:SetText("")
    f.modeleCharge = nil
    f.emoteAction:Reset()
    f.replie = true
    f:Disposer()
    f:Show()
    f:Raise()
    Ecran.Rendre()
    return f
end

function Ecran.Declarer()
    local f = Ecran.frame
    if f.constructeur:Blocage() then return end
    local valider = f.rappelValider
    f.rappelValider, f.rappelAnnuler = nil, nil
    local nom, desc = f.nom:GetText() or "", f.desc:GetText() or ""
    local icone = f.iconeChoisie
    local emote, canal = f.emoteAction:Lire()
    f.constructeur.ctx.emoteAction = emote:match("%S")
        and { texte = emote, canal = canal } or nil
    f:Hide()
    if valider then valider(nom, desc, icone) end
end

A.onConstruire = function(constructeur, valider, annuler) Ecran.Ouvrir(constructeur, valider, annuler) end
