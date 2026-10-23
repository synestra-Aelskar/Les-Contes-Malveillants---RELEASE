-- Creation de personnage : l'ecran.
--
-- Organise comme la fenetre « Creation » du template Necronicon : sept
-- onglets (Bienvenue, Generale, Statistiques, Expertises, Penetrations,
-- Resistances, Traits), avec ses textes, et une grille de repartition par
-- budget. Chaque grille est un bloc du modele (titre en capitales, compte
-- « reste / total », remise a zero).
--
-- L'ecran ne connait aucune regle : il demande a `LCM.Creation` ce qu'on peut
-- poser et affiche ce qu'on lui repond — y compris les refus. Ajouter une
-- statistique ou un type de degat ne demande pas une ligne ici.

local _, LCM = ...
local UI = LCM.UI
local GameTooltip = UI.Infobulle()
local C = LCM.Creation

local Ecran = {}
UI.Creation = Ecran

-- 1040 de large : le recapitulatif a gauche, et une page qui tient TROIS
-- colonnes de compteurs. Les expertises ont trois familles (Observations,
-- Athletisme, Filouterie) ; sur deux colonnes, la troisieme passait sous la
-- ligne de flottaison et on repartissait a l'aveugle.
local LARGEUR, HAUTEUR = 1040, 620
-- La colonne du recapitulatif, a gauche : ce qu'on a deja pose, par categorie.
local LARGEUR_RECAP = 224
local LARGEUR_PAGE = LARGEUR - 24 - LARGEUR_RECAP - 12
local LIGNE = 24
local LARGEUR_LABEL = 150
local ECART_BLOCS = 14

-- ===== Textes du template ==================================================

local TEXTES = {
    introduction = "Bienvenue dans le système des Contes Malveillants !\n\n"
        .. "Au fil des prochains onglets, tu seras invité à donner vie à ton personnage en choisissant sa race, "
        .. "ses caractéristiques, ses expertises et toutes les particularités qui le rendront unique.\n\n"
        .. "Chaque onglet t'accompagnera dans sa création et t'expliquera les différentes mécaniques de notre "
        .. "système de jeu.\n\n"
        .. "Et si tu as la moindre question, n'hésite surtout pas à te tourner vers Syn ou Talyah. Nous serons "
        .. "là pour te guider !",
    reglesImportantes = "Lors de la création de ton personnage, veille à respecter le niveau qui t'a été attribué.\n\n"
        .. "Tu pourras également proposer tes propres traits en effectuant une demande de création directement "
        .. "sur notre site internet.\n\n"
        .. "Enfin, prends le temps de répartir tes points en fonction du personnage que tu souhaites incarner. "
        .. "L'idée est avant tout que ses caractéristiques et ses compétences reflètent au mieux sa personnalité, "
        .. "son histoire et ses aptitudes !",
    race = "Choisis la race de ton personnage pour bénéficier de bonus de statistiques reflétant ses forces et "
        .. "ses faiblesses.\n\nTa race devra être créée et validée par un maître du jeu avant de pouvoir être utilisée.",
    niveau = "Par défaut, ton personnage commence au niveau cinq ! Les niveaux inférieurs représentent des "
        .. "créatures plus faibles qu'un aventurier lambda.\n\nSauf indication contraire de la part d'un maître "
        .. "du jeu, veille bien à commencer niveau 5.",
    informations = "Tu retrouveras ci-dessous le nombre de points dont tu disposes pour personnaliser ton "
        .. "personnage au fil des prochains onglets.",
    statistiques = "Il est temps de répartir tes points de statistiques primaires et secondaires !\n\n"
        .. "Les statistiques primaires représentent les aptitudes fondamentales de ton personnage. Elles "
        .. "interviennent dans tes jets de dés et servent de base au calcul de tes expertises et de tes bonus "
        .. "de dégâts.\n\n"
        .. "Les statistiques secondaires, quant à elles, te permettent de développer des aptitudes "
        .. "principalement liées au combat.\n\n"
        .. "Répartis tes points en fonction des forces et des faiblesses que tu souhaites donner à ton personnage !",
    statistiquesGenerales = "Répartissez ci-dessous vos points de statistiques. Les points de statistiques "
        .. "primaires influent sur l'ensemble de vos compétences. Elles constituent le socle de votre personnage.",
    mecaniques = "Les mécaniques de compétence disent ce que ton personnage sait faire d'une "
        .. "compétence : à quelle distance, sur combien de cibles, avec quelle force. "
        .. "Elles se répartissent comme les expertises, et sur leur propre budget.",
    expertises = "Les expertises représentent les compétences diverses et variées qu'un personnage sait faire "
        .. "ou non.\n\nIl est possible que certaines expertises ne soient pas présentées dans cette liste ; le "
        .. "cas échéant, celles-ci sont traitées soit au feeling, soit par aval d'un maître du jeu.",
    metiers = "Un personnage joueur dispose de 4 points de métier, quel que soit son niveau d'aventure, "
        .. "et aucun de ses métiers ne dépasse le niveau 4.\n\n"
        .. "Un PNJ dispose de 4 points par niveau, peut en laisser une partie inutilisée, et n'a pas cette "
        .. "limite de 4 : un seul de ses métiers peut monter jusqu'au bout du barème.\n\n"
        .. "Chaque point augmente directement le niveau du métier choisi de 1.",
    penetrations = "Les pénétrations représentent les compétences du personnage dans un domaine lorsqu'il "
        .. "s'agit de manipuler ce dernier à des fins actives.\n\n"
        .. "Comprenez par là qu'une pénétration permet autant de définir les dégâts produits par un type que la "
        .. "puissance d'un soin. Elle s'ajoute en outre en tant que bonus lors d'une action liée à ce type.\n\n"
        .. "Celles-ci sont divisées en 3 catégories : physiques, élémentaires et cosmologiques.\n\n"
        .. "Il n'y a aucune restriction au nombre de types que votre personnage sait ou non manier, mais un type "
        .. "ne peut être augmenté qu'à un seuil lié à vos trois statistiques de dégâts (Force, Mystique, Perception).",
    resistances = "Les résistances représentent les compétences du personnage dans un domaine lorsqu'il s'agit "
        .. "de se prémunir de ce dernier.\n\n"
        .. "Une résistance représente autant les actions naturelles que les mécanismes qu'un personnage met en "
        .. "place pour s'en défendre.\n\n"
        .. "Celles-ci sont divisées en 3 catégories : physiques, élémentaires et cosmologiques.\n\n"
        .. "Il n'y a aucune restriction au nombre de types que votre personnage sait ou non manier, mais un type "
        .. "ne peut être augmenté qu'à un seuil maximal lié à votre constitution.",
    traits = "Tout personnage commence au niveau 5 avec 3 points de traits. Il gagne ensuite un point "
        .. "supplémentaire aux niveaux 8, 12, 15, 19, 22, 25, 30, 35, 40, 45 et 50.\n\n"
        .. "Les traits doivent être confectionnés par un maître du jeu.\n\n"
        .. "Ils apportent ou retirent des statistiques directement à la fiche. Ils représentent les affinités, "
        .. "particularités, etc., du personnage. À la différence de l'équipement, ils ne peuvent pas être amputés "
        .. "du personnage. De plus, chaque trait s'accompagne d'un « avantage ou désavantage » offrant des bonus "
        .. "ou malus dans des situations précises.",
}

-- ===== Une page : des blocs empiles ========================================

local function NouvellePage(f)
    local page = CreateFrame("Frame", nil, f.zone.contenu)
    page:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 0, 0)
    page:SetPoint("TOPRIGHT", f.zone.contenu, "TOPRIGHT", 0, 0)
    page.blocs, page.compteurs, page.budgets = {}, {}, {}

    -- Chaque bloc connait sa hauteur interieure (`bloc.hauteurContenu`) ; la
    -- page les pose l'un sous l'autre.
    function page:Disposer()
        local y = 0
        for _, bloc in ipairs(self.blocs) do
            if bloc:IsShown() then
                local h = bloc.hautTitre + 8
                if bloc.paragraphe then h = h + (bloc.paragraphe:GetStringHeight() or 14) + 12 end
                h = h + (bloc.hauteurContenu or 0) + UI.Fiche.MARGE_BLOC
                bloc:ClearAllPoints()
                bloc:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
                bloc:SetSize(LARGEUR_PAGE, h)
                y = y + h + ECART_BLOCS
            end
        end
        self.hauteur = math.max(1, y - ECART_BLOCS)
        self:SetHeight(self.hauteur)
    end
    page:Hide()
    return page
end

-- Un bloc du modele, avec un texte eventuel. Le contenu se pose sous le
-- texte : `Haut(bloc)` donne ou commencer.
local function Bloc(page, titre, texte)
    local bloc = UI.Fiche.Bloc(page, { label = titre or "", texte = texte }, LARGEUR_PAGE)
    page.blocs[#page.blocs + 1] = bloc
    return bloc
end

local function Haut(bloc)
    local y = bloc.hautTitre + 8
    if bloc.paragraphe then y = y + (bloc.paragraphe:GetStringHeight() or 14) + 12 end
    return y
end

-- Le compte « reste / total » et la remise a zero d'une categorie, dans le
-- titre du bloc.
-- Le budget d'une categorie : combien il reste, et le bouton qui remet tout a
-- zero. Il est ancre a la FENETRE, pas au bloc : une liste de vingt lignes se
-- fait defiler, et c'est precisement en bas de liste qu'on a besoin de savoir
-- ce qu'il reste. Le bloc, lui, garde son titre.
local function Budget(page, f, bloc, categorie)
    -- Le pool vit dans l'entete du bloc, sur la ligne du titre et a droite.
    --
    -- Il a vecu un temps dans un bandeau fige au-dessus de la liste, pour
    -- rester lisible quand on faisait defiler (3 octobre 2026). Ca coutait
    -- trop cher : un bloc prive de titre perd aussi son cadre, la description
    -- s'affichait en double, et deux grilles sur une meme page se disputaient
    -- le bandeau. L'entete est revenue dans le bloc (5 octobre 2026).
    bloc.budget = UI.Texte(bloc, "", UI.C.titre)
    UI.Police(bloc.budget, 14)
    bloc.remise = UI.Bouton(bloc, "R", 22, 20, function()
        C.RemettreCategorie(f.brouillon, categorie)
        f:Actualiser()
    end)
    bloc.remise:SetFrameLevel(bloc:GetFrameLevel() + 5)
    bloc.budget:SetDrawLayer("OVERLAY")
    bloc.categorie = categorie
    -- Posee par f:PlacerBudget() quand on change d'etape : une seule de ces
    -- lignes est visible a la fois, celle de l'etape ouverte.
    page.budgets[#page.budgets + 1] = bloc
end

-- Une grille de repartition : un compteur par ligne de la categorie, sur une
-- ou deux colonnes, avec un intertitre quand le groupe change.
local Apercu
local function Grille(page, f, titre, texte, categorie, colonnes, domaine)
    -- Titre et description dans le bloc, comme partout ailleurs. Les mettre
    -- ailleurs laissait un bloc sans titre, donc sans cadre (`b.aTitre`
    -- commande `AelCadre`), et la description s'ecrivait deux fois.
    local bloc = Bloc(page, titre or "", texte)
    Budget(page, f, bloc, categorie)
    colonnes = colonnes or 1
    local lignes = C.Lignes(categorie)
    if domaine then
        local filtre = {}
        for _, ligne in ipairs(lignes) do
            if ligne.groupe == domaine then filtre[#filtre + 1] = ligne end
        end
        lignes = filtre
    end
    local marge = UI.Fiche.MARGE_BLOC + 6
    local largeurUtile = LARGEUR_PAGE - 2 * marge
    local haut = Haut(bloc)

    -- Ce qui tient dans une ligne de largeur donnee : le libelle, les boutons
    -- (136), puis le total. Quand il n'y a plus la place du total, on le rend
    -- au libelle — le total est de toute facon dans le recapitulatif.
    -- 6 : la marge avant le libelle.
    --
    -- `voulu` : la largeur du plus long libelle de la rangee. Donnee, le
    -- libelle passe AVANT le total : « Contondant » coupe en « Contond… » pour
    -- garder trente pixels de total, c'etait lire le chiffre sans savoir de
    -- quoi.
    local function Mesures(largeur, serre, voulu)
        local boutons = serre and 130 or 136
        local dispo = (largeur - 12) - 6 - boutons
        local label = math.min(LARGEUR_LABEL, math.max(serre and 56 or 76, dispo - 8 - 96))
        if voulu then label = math.min(LARGEUR_LABEL, math.max(serre and 56 or 76, voulu)) end
        local total = math.min(96, math.max(0, dispo - label - 8))
        if total < 30 then label, total = math.max(serre and 56 or 76, dispo), 0 end
        label = math.min(label, math.max(40, (largeur - 12) - 6 - boutons))
        return label, total
    end

    -- La place minimale d'un compteur serre : sa marge, son libelle le plus
    -- court lisible, et ses boutons.
    local MINIMUM_SERRE = 6 + 56 + 130 + 12

    -- Les lignes, par groupe, dans l'ordre. Un groupe ne se coupe jamais en
    -- deux : une categorie qui se deverse sur la colonne d'a cote ne se lit
    -- plus, on ne sait plus ou elle commence.
    local groupes, parNom = {}, {}
    for _, ligne in ipairs(lignes) do
        local nom = ligne.groupe or ""
        local g = parNom[nom]
        if not g then
            g = { nom = nom, lignes = {} }
            parNom[nom] = g
            groupes[#groupes + 1] = g
        end
        g.lignes[#g.lignes + 1] = ligne
    end

    local function Titre(nom, x, y, largeur)
        if nom == "" then return 0 end
        local t = UI.Texte(bloc, UI.Majuscules(nom), UI.C.accent)
        UI.Police(t, 12)
        t:SetPoint("TOPLEFT", bloc, "TOPLEFT", x, -y)
        t:SetWidth(largeur)
        return 20
    end

    -- La largeur d'un libelle tel que le compteur l'ecrira (meme police).
    -- Un seul texte de mesure par grille, cache : il ne sert qu'a construire.
    local mesureur
    local function LargeurTexte(texte)
        if not mesureur then
            mesureur = UI.Texte(bloc, "", UI.C.texte, "GameFontNormalSmall")
            UI.Police(mesureur, 12)
            mesureur:Hide()
        end
        mesureur:SetText(texte)
        return mesureur:GetStringWidth() or 0
    end

    local function Poser(ligne, x, y, largeur, serre, voulu)
        local largeurLabel, largeurTotal = Mesures(largeur, serre, voulu)
        local compteur = UI.Compteur(bloc, ligne.label, largeurLabel, {
            serre = serre,
            change = function(valeur)
                local ok, raison = C.Definir(f.brouillon, categorie, ligne.id, valeur)
                if not ok then
                    LCM.Alerte(string.format("%s : %s", ligne.label, tostring(raison)))
                    return false
                end
                f:Actualiser()
            end,
            max = function() return C.Maximum(f.brouillon, categorie, ligne.id) end,
        })
        compteur:SetHeight(LIGNE - 2)
        -- Dire ce que c'est. Un joueur qui repartit trente lignes ne sait pas
        -- de tete ce que « Insensible » ou « Projection » lui donnent, et il
        -- n'a aucune raison de le savoir : la ligne le lui dit.
        local field = LCM.Schema.Field(ligne.id)
        local description = ligne.note or (field and field.note)
        local regle = C.Note(categorie, ligne.id)
        local note = description or regle
        if description and regle and description ~= regle then
            note = description .. "\n\n" .. regle
        end
        UI.Fiche.Bulle(compteur, ligne.label, function()
            local apercu = Apercu(f.brouillon)
            local investi = C.Valeur(f.brouillon, ligne.id)
            local champ = field or { id = ligne.id, kind = "stat" }
            local detail = UI.Fiche.Decomposition(apercu, champ, investi,
                categorie == "expertises" and LCM.Formules.Apport(apercu, ligne.id) or 0)
            if note and note ~= "" and not ligne.id:match("^meca_") then detail.note = note end
            return detail
        end)
        compteur:SetPoint("TOPLEFT", bloc, "TOPLEFT", x, -y)
        compteur:SetWidth(largeur - 12)
        compteur.champ, compteur.categorie = ligne.id, categorie

        -- A droite de la ligne : le TOTAL que donnera la fiche, race comprise.
        -- C'est ce que le joueur veut savoir en repartissant ; le cout, lui, ne
        -- l'interesse qu'au moment d'appuyer — il est donc passe en infobulle
        -- sur le « + », apres une seconde d'arret.
        compteur.total = UI.Texte(compteur, "", UI.C.accent, "GameFontNormalSmall")
        compteur.total:SetPoint("LEFT", compteur.maximum, "RIGHT", 8, 0)
        compteur.total:SetWidth(math.max(1, largeurTotal))
        -- Cale a droite : les totaux s'alignent, quelle que soit la longueur
        -- du calcul qui les precede.
        compteur.total:SetJustifyH("RIGHT")
        compteur.total:SetShown(largeurTotal > 0)

        local cout = C.Cout(categorie, ligne.id)
        UI.Bulle(compteur.plus,
            function() return ligne.label end,
            function()
                local morceaux = { cout > 1 and string.format("Coûte %d points.", cout)
                                           or "Coûte 1 point." }
                local bonus = compteur.bonus or 0
                if bonus ~= 0 then
                    morceaux[#morceaux + 1] = string.format("Ta race y ajoute %+d.", bonus)
                end
                return table.concat(morceaux, "\n")
            end)
        page.compteurs[#page.compteurs + 1] = compteur
    end

    local hauteurMax = haut

    if colonnes <= 1 or #groupes <= 1 then
        -- Une seule colonne : tout a la suite.
        local y = haut
        for _, g in ipairs(groupes) do
            y = y + Titre(g.nom, marge, y, largeurUtile)
            for _, ligne in ipairs(g.lignes) do
                Poser(ligne, marge, y, largeurUtile)
                y = y + LIGNE
            end
        end
        hauteurMax = y
    else
        -- Le PREMIER groupe prend toute la largeur, ses lignes cote a cote :
        -- trois types physiques tiennent sur un rang, les empiler sur une
        -- demi-largeur gachait la moitie de la place.
        local y = haut
        local premier = groupes[1]
        local n = #premier.lignes
        -- Quatre pixels entre deux compteurs, et pas les douze d'une colonne :
        -- sur ce rang, chaque pixel rendu va au libelle ou au total.
        local ECART_RANG = 4
        local largeurCompteur = (largeurUtile - (n - 1) * ECART_RANG) / n
        -- Poser retranche 12 (l'air d'une colonne) : on le lui rend.
        local part = largeurCompteur + 12
        local voulu = 0
        for _, ligne in ipairs(premier.lignes) do
            -- +4 : l'arrondi d'une police qu'on mesure au banc, pas en jeu.
            voulu = math.max(voulu, LargeurTexte(ligne.label) + 4)
        end
        local debut = 1
        -- ... a condition que ses lignes y tiennent. Au-dela, on ne gagne rien
        -- a les serrer : les libelles se couperaient.
        if part >= MINIMUM_SERRE then
            y = y + Titre(premier.nom, marge, y, largeurUtile)
            for index, ligne in ipairs(premier.lignes) do
                Poser(ligne, marge + (index - 1) * (largeurCompteur + ECART_RANG), y, part, true, voulu)
            end
            y = y + LIGNE + 6
            debut = 2
        end
        hauteurMax = y

        -- Les suivants : a tour de role dans la colonne la moins remplie.
        --
        -- Un groupe trop grand pour une colonne s'y DEVERSE par tranches, et
        -- chaque tranche reprend son titre suivi de « (suite) ». On refusait
        -- de couper un groupe, pour qu'on sache toujours ou il commence ; a
        -- vingt-quatre mecaniques de competence, ce refus coutait un
        -- defilement et une colonne vide a cote (11 octobre 2026). Le titre
        -- repete repond au meme souci, sans le defilement.
        local largeurColonne = largeurUtile / colonnes
        -- A trois colonnes, un compteur entier ne tient plus : on le serre.
        local serreColonne = colonnes >= 3
        local yColonne = {}
        for c = 1, colonnes do yColonne[c] = y end
        -- Combien de lignes par colonne si l'on repartit au mieux : c'est la
        -- taille d'une tranche. On compte les titres, qui prennent leur place.
        local aPlacer = 0
        for rang = debut, #groupes do aPlacer = aPlacer + #groupes[rang].lignes + 1 end
        local parColonne = math.max(1, math.ceil(aPlacer / colonnes))

        for rang = debut, #groupes do
            local g = groupes[rang]
            -- Le plus long libelle du groupe commande la largeur de la colonne
            -- de libelles. Sans ca, chacun retombait sur la part calculee
            -- (« dispo - 8 - 96 ») qui reserve d'abord la place du total : on
            -- lisait « = 0 » a cote d'« Odorat… » et d'« Investi… ». Un
            -- intitule coupe ne dit pas de quoi il parle ; le total, lui, se
            -- deduit de la ligne.
            local vouluGroupe = 0
            for _, ligne in ipairs(g.lignes) do
                -- +4 : l'arrondi d'une police qu'on mesure au banc, pas en jeu.
                vouluGroupe = math.max(vouluGroupe, LargeurTexte(ligne.label) + 4)
            end

            local index, suite = 1, false
            while index <= #g.lignes do
                -- La colonne la moins remplie : deux groupes inegaux ne
                -- laissent pas un trou d'un cote.
                local choisie = 1
                for c = 2, colonnes do
                    if yColonne[c] < yColonne[choisie] then choisie = c end
                end
                local x = marge + (choisie - 1) * largeurColonne
                yColonne[choisie] = yColonne[choisie]
                    + Titre(suite and (g.nom .. " (suite)") or g.nom, x, yColonne[choisie], largeurColonne)
                local combien = math.min(#g.lignes - index + 1, parColonne)
                for k = 0, combien - 1 do
                    Poser(g.lignes[index + k], x, yColonne[choisie], largeurColonne, serreColonne, vouluGroupe)
                    yColonne[choisie] = yColonne[choisie] + LIGNE
                end
                index = index + combien
                yColonne[choisie] = yColonne[choisie] + 6
                hauteurMax = math.max(hauteurMax, yColonne[choisie])
                suite = true
            end
        end
    end

    bloc.hauteurContenu = hauteurMax - haut
    return bloc
end

-- Une ligne de lecture : libelle a gauche, valeur a droite.
local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function Teinte(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function Lecture(bloc, libelle, y)
    local l = CreateFrame("Frame", nil, bloc)
    l:SetHeight(LIGNE)
    l:SetPoint("TOPLEFT", bloc, "TOPLEFT", UI.Fiche.MARGE_BLOC, -y)
    l:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -y)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    l.nom = UI.Texte(l, libelle, UI.C.texte)
    UI.Police(l.nom, 13)
    l.nom:SetPoint("LEFT", l, "LEFT", 10, 0)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, 13)
    l.valeur:SetPoint("RIGHT", l, "RIGHT", -12, 0)
    l.valeur:SetJustifyH("RIGHT")
    return l
end

-- Ce que vaut vraiment un point secondaire, une fois investi. Le joueur ne
-- repartit pas des points : il achete des PV, de la fatigue, de l'initiative.
-- C'est donc le RESULTAT qu'on lui montre a droite de la ligne, pas le nombre
-- de points qu'il vient de poser.
local MARRON, BLEU, BLANC = "ffa0703c", "ff5a9bd8", "ffdedede"

local RENDEMENTS = {
    sec_vitalite = function(e)
        return string.format("%d PV", tonumber(LCM.Entities.Get_Value(e, "pv_max")) or 0)
    end,
    sec_fatigue = function(e)
        local jauge = LCM.Entities.Gauge(e, "fatigue")
        return string.format("%d fatigue", (jauge and jauge.max) or 0)
    end,
    sec_initiative = function(e)
        return string.format("%d init.", tonumber(LCM.Entities.Get_Value(e, "initiative")) or 0)
    end,
    sec_pa = function(e)
        local jauge = LCM.Entities.Gauge(e, "pa")
        return string.format("%d PA", (jauge and jauge.max) or 0)
    end,
    -- Les trois modes d'un coup, chacun dans sa couleur : terre, eau, air.
    sec_deplacement = function(e)
        local function m(champ) return tonumber(LCM.Entities.Get_Value(e, champ)) or 0 end
        return string.format("|c%s%d|r / |c%s%d|r / |c%s%d|r",
            MARRON, m("depl_terrestre"), BLEU, m("depl_nage"), BLANC, m("depl_vol"))
    end,
}

-- Ceux qui ouvrent un budget : ce qu'ils rapportent, ce sont des points a
-- repartir ailleurs.
local BUDGETS_SECONDAIRES = {
    sec_penetration = "penetration",
    sec_resistance  = "resistance",
    sec_expertises  = "expertises",
    sec_mecanique   = "mecaniques",
}

-- Une entite de passage, faite du brouillon : les formules de la fiche (PV,
-- fatigue) s'y appliquent telles quelles, race et traits compris.
Apercu = function(brouillon)
    local values = {}
    for cle, valeur in pairs(brouillon.valeurs) do values[cle] = valeur end
    values.race, values.niveau = brouillon.race, brouillon.niveau
    return { id = "__apercu", name = brouillon.nom, kind = "player", values = values, traits = brouillon.traits }
end

-- ===== Les onglets =========================================================

local Pages = {}

function Pages.bienvenue(page)
    Bloc(page, "Introduction", TEXTES.introduction)
    Bloc(page, "Règles importantes", TEXTES.reglesImportantes)
end

function Pages.generale(page, f)
    -- Identite : ce que le template prend au personnage WoW ; ici, saisi.
    local identite = Bloc(page, "Identité")
    local y = Haut(identite)
    local x = UI.Fiche.MARGE_BLOC + 6
    local function Etiquette(texte, dy)
        local fs = UI.Texte(identite, texte, UI.C.texte)
        UI.Police(fs, 13)
        fs:SetPoint("TOPLEFT", identite, "TOPLEFT", x, -dy - 3)
        return fs
    end
    Etiquette("Nom", y)
    page.nom = UI.Champ(identite, 260, 22, function(texte)
        f.brouillon.nom = texte
        f:Actualiser()
    end)
    page.nom:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -y)
    y = y + 30
    -- Age, sexe et poids ne coutent rien : ce sont des champs d'identite, pas
    -- des investissements.
    Etiquette("Âge", y)
    page.age = UI.Champ(identite, 70, 22, function(texte)
        f.brouillon.valeurs.age = tonumber(texte)
        f:Actualiser()
    end)
    page.age:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -y)
    page.age:SetNumeric(true)
    Etiquette("Poids (kg)", y + 30)
    page.poids = UI.Champ(identite, 70, 22, function(texte)
        f.brouillon.valeurs.poids = tonumber(texte)
        f:Actualiser()
    end)
    page.poids:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -(y + 30))
    page.poids:SetNumeric(true)
    y = y + 60
    Etiquette("Sexe", y)
    page.sexes = {}
    local precedent
    for _, sexe in ipairs({ "Féminin", "Masculin", "Autre" }) do
        local b = UI.Bouton(identite, sexe, 90, 22, function()
            f.brouillon.valeurs.sexe = sexe
            f:Actualiser()
        end)
        b.sexe = sexe
        if precedent then b:SetPoint("LEFT", precedent, "RIGHT", 4, 0)
        else b:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -y) end
        precedent = b
        page.sexes[#page.sexes + 1] = b
    end
    -- « Autre » demande de preciser : un bouton qui ne dit rien de plus qu'il
    -- n'est ni l'un ni l'autre n'apprend rien a la table.
    -- Aussi large que les trois boutons reunis, et pose juste dessous : c'est
    -- la precision de l'un d'eux, pas un champ qui flotte a cote.
    local LARGEUR_SEXES = 3 * 90 + 2 * 4
    page.sexeAutre = UI.Champ(identite, LARGEUR_SEXES, 22, function(texte)
        f.brouillon.sexeAutre = texte ~= "" and texte or nil
        f:Actualiser()
    end)
    page.sexeAutre:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -(y + 28))
    page.sexeAutre:Hide()

    -- La tabulation passe d'un champ a l'autre, dans l'ordre de lecture.
    UI.Enchainer({ page.nom, page.age, page.poids, page.sexeAutre })

    identite.hauteurContenu = y + 26 - Haut(identite) + 26

    -- Race : un CONTENEUR d'un emplacement dans le template (Creation ›
    -- Generale, « RACE », ajout limite a la categorie Races du compendium).
    -- On y depose une race en la glissant depuis le compendium ; un clic droit
    -- sur la case occupee la montre ou la retire.
    local race = Bloc(page, "Race", TEXTES.race)
    local c = UI.AelColonnes(LARGEUR_PAGE - 2 * UI.Fiche.MARGE_BLOC)
    -- Un bouton, pas un cadre : on clique dessus (gauche pour choisir, droit
    -- pour voir ou retirer).
    local slot = UI.Fiche.Ligne(race, c, "Button")
    slot:SetHeight(math.max(48, c.ligne))
    slot:SetPoint("TOPLEFT", race, "TOPLEFT", UI.Fiche.MARGE_BLOC, -Haut(race))
    slot:SetPoint("TOPRIGHT", race, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -Haut(race))
    UI.Fiche.Icone(slot, c, VIDE)
    UI.Fiche.Nom(slot, c, "Emplacement", true)
    slot.effets = UI.Texte(slot, "", UI.C.accent)
    UI.Police(slot.effets, c.police * 0.72)
    slot.effets:SetPoint("LEFT", slot, "LEFT", c.plage, 0)
    slot.effets:SetPoint("RIGHT", slot, "RIGHT", -12 * c.echelle, 0)
    slot.effets:SetJustifyH("RIGHT")
    slot.effets:SetWordWrap(false)
    slot:EnableMouse(true)
    page.race = slot
    UI.Glisser.Cible(slot, function(objet)
        if objet.categorie ~= "races" then
            return false, "cet emplacement n'accepte qu'une race (catégorie Races du compendium)."
        end
        if not LCM.Races.Choisissable(objet.element) then
            return false, "cette race est réservée au MJ."
        end
        return true
    end, function(objet)
        f.brouillon.race = objet.element.id
        f:Actualiser()
    end)
    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local r = f.brouillon.race ~= "" and LCM.Races.Get(f.brouillon.race)
        if r then
            GameTooltip:SetText(r.label)
            if r.description ~= "" then GameTooltip:AddLine(r.description, 0.88, 0.84, 0.76, true) end
            local effets = UI.Fiche.Effets(r)
            if effets ~= "" then GameTooltip:AddLine(effets, 0.83, 0.68, 0.33, true) end
            GameTooltip:AddLine("Clic droit : voir ou retirer.", 0.6, 0.56, 0.5)
        else
            GameTooltip:SetText("Emplacement")
            GameTooltip:AddLine("Glisse ici une race depuis le compendium (Système d'A'Hell'Razkah, catégorie Races).",
                0.88, 0.84, 0.76, true)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot.menu = UI.Choix("creation_race", "Race")
    -- Clic gauche : choisir parmi les races du compendium. Le glisser-deposer
    -- reste, mais il suppose la fenetre du compendium ouverte — ce qui fait de
    -- la race le seul choix de la creation qu'on ne puisse pas faire sur place.
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Les deux clics passent par le meme script : un bouton n'a qu'un OnClick,
    -- et c'est lui qui recoit le nom du bouton presse.
    slot:SetScript("OnClick", function(self, bouton)
        if bouton == "RightButton" then
            if f.brouillon.race == "" then return end
            local r = LCM.Races.Get(f.brouillon.race)
            local options = { { id = "retirer", label = "Retirer" } }
            if r then table.insert(options, 1, { id = "voir", label = "Voir" }) end
            self.menu:Proposer(self, options, function(choix)
                if choix == "voir" and r then
                    UI.Compendium.Voir(LCM.Compendium.Get("races"), r, f)
                elseif choix == "retirer" then
                    f.brouillon.race = ""
                    f:Actualiser()
                end
            end)
            return
        end
        local options = {}
        -- Sans les races reservees au MJ, pour un joueur : Races.Disponibles.
        for _, r in ipairs(LCM.Races.Disponibles()) do
            options[#options + 1] = { id = r.id, label = r.label, icone = r.icone }
        end
        if #options == 0 then
            LCM.Alerte("aucune race au compendium.")
            return
        end
        if f.brouillon.race ~= "" then
            table.insert(options, 1, { id = "", label = "Aucune" })
        end
        self.menu:Proposer(self, options, function(choix)
            f.brouillon.race = choix or ""
            f:Actualiser()
        end)
    end)

    race.hauteurContenu = slot:GetHeight() + 32

    -- Portrait : l'artwork livre avec l'addon. Sans choix, un personnage n'a
    -- jamais son image — l'identifiant d'un portrait ne tombe pas tout seul sur
    -- celui du personnage (« reikashira » n'est pas « reika-shira »).
    local portrait = Bloc(page, "Portrait", "Choisis l'artwork de ton personnage parmi ceux livrés avec l'addon.")
    local vignette = CreateFrame("Button", nil, portrait)
    vignette:SetSize(40, 60)
    vignette:SetPoint("TOPLEFT", portrait, "TOPLEFT", UI.Fiche.MARGE_BLOC, -Haut(portrait))
    if UI.BordureFine then UI.BordureFine(vignette, 0.4) end
    vignette.art = vignette:CreateTexture(nil, "ARTWORK")
    vignette.art:SetPoint("TOPLEFT", vignette, "TOPLEFT", 1, -1)
    vignette.art:SetPoint("BOTTOMRIGHT", vignette, "BOTTOMRIGHT", -1, 1)
    vignette.survol = UI.Aplat(vignette, UI.C.survol, "HIGHLIGHT")
    vignette.survol:SetAllPoints(vignette)

    vignette.nom = UI.Texte(portrait, "", UI.C.texte)
    UI.Police(vignette.nom, 13)
    vignette.nom:SetPoint("LEFT", vignette, "RIGHT", 10, 8)
    vignette.aide = UI.Texte(portrait, "", UI.C.discret)
    UI.Police(vignette.aide, 11)
    vignette.aide:SetPoint("LEFT", vignette, "RIGHT", 10, -8)

    vignette.menu = UI.Choix("creation_portrait", "Portrait")
    vignette:SetScript("OnClick", function(self)
        local options = { { id = "", label = "Aucun" } }
        for _, p in ipairs(LCM.Portraits.list) do
            options[#options + 1] = { id = p.id, label = p.label }
        end
        if #options == 1 then
            LCM.Alerte("aucun artwork n'est livre pour l'instant.")
            return
        end
        self.menu:Proposer(self, options, function(choix)
            f.brouillon.valeurs.portrait = (choix ~= "" and choix) or nil
            f:Actualiser()
        end)
    end)
    page.portrait = vignette
    portrait.hauteurContenu = 60

    -- Niveau d'aventure : un champ de la fiche (« Niveau du personnage »,
    -- modifiable en vue), comme les lignes d'informations qui suivent. La
    -- valeur se saisit a droite ; une saisie illisible reste affichee en
    -- rouge et bloque la creation, rien n'est corrige en douce.
    local niveau = Bloc(page, "Niveau d'aventure", TEXTES.niveau)
    local ligneNiveau = Lecture(niveau, "Niveau du personnage (5 par défaut)", Haut(niveau))
    -- Le niveau est fixe pour les joueurs : tout le monde commence a 5. Seul le
    -- compagnon MJ ouvre la saisie — monter de niveau se gagne en jeu, ca ne se
    -- tape pas dans une case.
    --
    -- `ligneNiveau.valeur` sert deja a porter le nombre (il est ecrase a chaque
    -- rafraichissement) : on garde une reference a part pour le texte.
    ligneNiveau.lecture = ligneNiveau.valeur
    ligneNiveau.lecture:Hide()
    ligneNiveau.saisie = UI.Champ(ligneNiveau, 56, LIGNE - 6, function(texte)
        local n = tonumber(texte)
        if n and n == math.floor(n) and n >= 1 then
            f.brouillon.niveau = n
            f.brouillon.niveauSaisie = nil
        else
            f.brouillon.niveauSaisie = texte
        end
        f:Actualiser()
    end)
    ligneNiveau.saisie:SetMaxLetters(3)
    ligneNiveau.saisie:SetJustifyH("RIGHT")
    ligneNiveau.saisie:SetPoint("RIGHT", ligneNiveau, "RIGHT", -8, 0)
    UI.Police(ligneNiveau.saisie, 13)
    page.niveau = ligneNiveau
    niveau.hauteurContenu = LIGNE

    -- Informations generales : ce qu'on a a repartir, au niveau choisi.
    local infos = Bloc(page, "Informations générales", TEXTES.informations)
    y = Haut(infos)
    page.infos = {}
    for _, def in ipairs({ { "primaires", "Points de statistiques" }, { "secondaires", "Points de statistiques secondaires" },
                           { "expertises", "Points d'expertises" } }) do
        local l = Lecture(infos, def[2], y)
        l.categorie = def[1]
        page.infos[#page.infos + 1] = l
        y = y + LIGNE + 4
    end
    infos.hauteurContenu = y - Haut(infos)

    -- Variante « montée de niveau » : la page Générale ne montre ni identité,
    -- ni race, ni portrait. Elle annonce seulement le passage traité et les
    -- réserves gagnées à ce niveau précis.
    page.creationBlocs = { identite, race, portrait, niveau, infos }
    local progression = Bloc(page, "Niveau supérieur",
        "Chaque validation ne traite qu'un seul niveau. Tous les points encore dépensables doivent être répartis avant de passer au suivant.")
    progression:Hide()
    page.progression = progression
    page.gains = {}
    y = Haut(progression)
    for _, def in ipairs({
        { "primaires", "Statistiques" }, { "secondaires", "Statistiques secondaires" },
        { "expertises", "Expertises" }, { "mecaniques", "Mécaniques de compétence" },
        { "penetration", "Pénétrations" }, { "resistance", "Résistances" },
        { "traits", "Traits" },
    }) do
        local l = Lecture(progression, def[2], y)
        l.categorie = def[1]
        page.gains[#page.gains + 1] = l
        y = y + LIGNE + 4
    end
    progression.hauteurContenu = y - Haut(progression)

    function page:Actualiser()
        local b = f.brouillon
        local montee = b.mode == "niveau"
        for _, bloc in ipairs(self.creationBlocs) do bloc:SetShown(not montee) end
        self.progression:SetShown(montee)
        if montee then
            if self.progression.paragraphe then
                self.progression.paragraphe:SetText(string.format(
                    "Passage du niveau %d au niveau %d. Répartis uniquement ce que ce niveau vient d'accorder.",
                    b.niveauAvant, b.niveau))
            end
            local gy = Haut(self.progression)
            for _, l in ipairs(self.gains) do
                local budget = C.Budget(b, l.categorie)
                local visible = budget.total > 0
                l:SetShown(visible)
                if visible then
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", self.progression, "TOPLEFT", UI.Fiche.MARGE_BLOC, -gy)
                    l:SetPoint("TOPRIGHT", self.progression, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -gy)
                    l.valeur:SetText(string.format("+%d acquis — %d à dépenser", budget.total, budget.reste))
                    gy = gy + LIGNE + 4
                end
            end
            self.progression.hauteurContenu = math.max(LIGNE, gy - Haut(self.progression))
        end
        if self.nom:GetText() ~= b.nom then self.nom:SetText(b.nom or "") end
        local age = tostring(b.valeurs.age or "")
        if self.age:GetText() ~= age then self.age:SetText(age) end
        local poids = tostring(b.valeurs.poids or "")
        if self.poids:GetText() ~= poids then self.poids:SetText(poids) end
        -- Le niveau ne se saisit qu'avec le compagnon MJ ; sinon il se lit.
        local mj = LCM.IsMaster()
        self.niveau.saisie:SetShown(mj)
        self.niveau.lecture:SetShown(not mj)
        if not mj then
            self.niveau.lecture:SetText(tostring(b.niveau))
            Teinte(self.niveau.lecture, UI.C.titre)
        end

        -- Une saisie en cours (meme illisible) n'est pas remplacee.
        local saisie = self.niveau.saisie
        if b.niveauSaisie == nil and saisie:GetText() ~= tostring(b.niveau) then saisie:SetText(tostring(b.niveau)) end
        local teinte = b.niveauSaisie ~= nil and UI.C.plein or UI.C.titre
        saisie:SetTextColor(teinte[1], teinte[2], teinte[3])
        self.niveau.valeur = b.niveau
        for _, bouton in ipairs(self.sexes) do bouton:Selectionner(bouton.sexe == b.valeurs.sexe) end
        -- Le champ libre n'apparait que si « Autre » est choisi.
        local autre = b.valeurs.sexe == "Autre"
        self.sexeAutre:SetShown(autre)
        if autre and self.sexeAutre:GetText() ~= (b.sexeAutre or "") then
            self.sexeAutre:SetText(b.sexeAutre or "")
        end

        -- L'apercu de l'artwork. Sans choix, la silhouette de repli : on voit
        -- ce qu'on aura, pas une case vide.
        local choisi = b.valeurs.portrait and LCM.Portraits.Get(b.valeurs.portrait)
        LCM.Portraits.Appliquer(self.portrait.art, { values = b.valeurs })
        self.portrait.nom:SetText(choisi and choisi.label or "Aucun")
        Teinte(self.portrait.nom, choisi and UI.C.titre or UI.C.discret)
        self.portrait.aide:SetText(#LCM.Portraits.list > 0 and "Cliquer pour choisir"
            or "Aucun artwork livré")
        -- La case de race : la race deposee, ou « Emplacement ». Une race
        -- disparue reste visible, marquee, et bloque la creation.
        local slot, r = self.race, b.race ~= "" and LCM.Races.Get(b.race)
        if b.race == "" then
            slot.icone:SetTexture(VIDE)
            slot.nom:SetText("Emplacement")
            Teinte(slot.nom, UI.C.discret)
            slot.effets:SetText("")
        elseif r then
            slot.icone:SetTexture(r.icone)
            slot.nom:SetText(r.label)
            slot.nom:SetTextColor(UI.Compendium.Couleur(r.couleurTitre or LCM.COULEUR_TITRE))
            slot.effets:SetText(UI.Fiche.Effets(r))
        else
            slot.icone:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            slot.nom:SetText("? " .. tostring(b.race))
            Teinte(slot.nom, UI.C.plein)
            slot.effets:SetText("")
        end
        for _, l in ipairs(self.infos) do l.valeur:SetText(tostring(C.Total(b, l.categorie))) end
    end
end

function Pages.statistiques(page, f)
    Bloc(page, "Statistiques", TEXTES.statistiques)
    -- Ce que la repartition donne deja : les formules de la fiche, sur le
    -- brouillon.
    local general = Bloc(page, "Général")
    local y = Haut(general)
    page.pv = Lecture(general, "Points de vie", y)
    page.fatigue = Lecture(general, "Fatigue", y + LIGNE + 4)
    UI.Fiche.Bulle(page.pv, "Points de vie", function()
        return UI.Fiche.DecompositionVie(Apercu(f.brouillon))
    end)
    UI.Fiche.Bulle(page.fatigue, "Fatigue", function()
        local apercu = Apercu(f.brouillon)
        return UI.Fiche.DecompositionJauge(LCM.Entities.Gauge(apercu, "fatigue"),
            LCM.Schema.Field("fatigue").note, apercu, "fatigue")
    end)
    general.hauteurContenu = 2 * (LIGNE + 4)
    Grille(page, f, "Statistiques générales", TEXTES.statistiquesGenerales, "primaires", 2)
    Grille(page, f, "Statistiques secondaires", nil, "secondaires", 2)

    function page:Actualiser()
        local e = Apercu(f.brouillon)
        self.pv.valeur:SetText(tostring(LCM.Entities.Get_Value(e, "pv_max") or 0))
        local fatigue = LCM.Entities.Gauge(e, "fatigue")
        self.fatigue.valeur:SetText(tostring(fatigue and fatigue.max or 0))
    end
end

function Pages.expertises(page, f)
    page.domaines = {}
    for _, domaine in ipairs({ "Observations", "Athlétisme", "Filouterie" }) do
        local bloc = Grille(page, f, domaine, TEXTES.expertises, "expertises", 3, domaine)
        page.domaines[domaine] = bloc
        bloc:SetShown(domaine == "Observations")
    end
end

function Pages.metiers(page, f)
    local bloc = Bloc(page, "Métiers", TEXTES.metiers)
    Budget(page, f, bloc, "metiers")
    page.metiers = {}
    local marge = UI.Fiche.MARGE_BLOC + 6
    local haut = Haut(bloc)
    local colonnes, ecart = 2, 8
    local largeur = (LARGEUR_PAGE - 2 * marge - ecart) / colonnes
    local hauteurLigne = 32

    for index, metier in ipairs(LCM.Metiers.list) do
        local metierLigne = metier
        local colonne = (index - 1) % colonnes
        local rangee = math.floor((index - 1) / colonnes)
        local compteur = UI.Compteur(bloc, metierLigne.label, 190, {
            change = function(valeur)
                local ok, raison = C.Definir(f.brouillon, "metiers", metierLigne.id, valeur)
                if not ok then
                    LCM.Alerte(string.format("%s : %s", metierLigne.label, tostring(raison)))
                    return false
                end
                f:Actualiser()
            end,
            max = function() return C.Maximum(f.brouillon, "metiers", metierLigne.id) end,
        })
        compteur:SetHeight(hauteurLigne - 4)
        compteur:SetWidth(largeur)
        compteur:SetPoint("TOPLEFT", bloc, "TOPLEFT",
            marge + colonne * (largeur + ecart), -(haut + rangee * hauteurLigne))
        compteur.icone = compteur:CreateTexture(nil, "ARTWORK")
        compteur.icone:SetSize(22, 22)
        compteur.icone:SetPoint("LEFT", compteur, "LEFT", 5, 0)
        compteur.icone:SetTexture(metierLigne.icone)
        compteur.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        compteur.label:ClearAllPoints()
        compteur.label:SetPoint("LEFT", compteur.icone, "RIGHT", 6, 0)
        compteur.label:SetWidth(150)
        compteur.metierId = metierLigne.id
        UI.Fiche.Bulle(compteur, metierLigne.label, metierLigne.description)
        page.metiers[#page.metiers + 1] = compteur
    end
    bloc.hauteurContenu = math.ceil(#LCM.Metiers.list / colonnes) * hauteurLigne

    function page:Actualiser()
        for _, compteur in ipairs(self.metiers) do
            local valeur = tonumber((f.brouillon.metiers or {})[compteur.metierId]) or 0
            compteur:Regler(valeur, C.Plafond(f.brouillon, "metiers", compteur.metierId))
        end
    end
    page:Actualiser()
end

function Pages.mecaniques(page, f)
    page.domaines = {}
    for _, domaine in ipairs({ "Compétence", "Défense" }) do
        local bloc = Grille(page, f, domaine, TEXTES.mecaniques, "mecaniques", 3, domaine)
        page.domaines[domaine] = bloc
        bloc:SetShown(domaine == "Compétence")
    end
end

function Pages.penetrations(page, f)
    Grille(page, f, "Pénétrations", TEXTES.penetrations, "penetration", 2)
end

function Pages.resistances(page, f)
    Grille(page, f, "Résistances", TEXTES.resistances, "resistance", 2)
end

-- Traits : le conteneur « Traits » du template (10 places), sous le total.
-- Les emplacements seulement — les pris, puis une case libre tant qu'il en
-- reste (trente cases vides ne disent rien de plus). Chaque case se remplit
-- comme celle de la race : clic gauche pour choisir dans le compendium, clic
-- droit pour voir ou retirer, ou glisser un trait depuis le compendium.

function Pages.traits(page, f)
    Bloc(page, "Traits de votre personnage", TEXTES.traits)
    local bloc = Bloc(page, "Traits totaux")
    Budget(page, f, bloc, "traits")
    local largeurLigne = LARGEUR_PAGE - 2 * UI.Fiche.MARGE_BLOC
    local c = UI.AelColonnes(largeurLigne)
    page.emplacements = {}
    -- Une seule liste pour toutes les cases : elle ne s'ouvre qu'une a la fois.
    page.menu = UI.Choix("creation_trait", "Trait")

    -- Poser `id` dans la case qui porte `ancien` (nil : une case libre). Un
    -- remplacement qui echoue — budget depasse — remet l'ancien a sa place :
    -- on ne perd pas un trait parce que le suivant etait trop cher. Le refus
    -- dit pourquoi.
    local function Poser(ancien, id)
        if ancien == id then return end
        local rang
        if ancien then
            for index, porte in ipairs(f.brouillon.traits) do
                if porte == ancien then rang = index break end
            end
            C.RetirerTrait(f.brouillon, ancien)
        end
        local ok, raison = C.AjouterTrait(f.brouillon, id)
        if ok then
            -- Le remplacant prend le rang du remplace, pas la fin de la liste.
            if rang then
                table.remove(f.brouillon.traits)
                table.insert(f.brouillon.traits, rang, id)
            end
        else
            if rang then table.insert(f.brouillon.traits, rang, ancien) end
            LCM.Alerte(raison)
        end
        f:Actualiser()
    end

    local function Emplacement(index)
        -- Un bouton, pas un cadre : on clique dessus (gauche pour choisir,
        -- droit pour voir ou retirer).
        local l = UI.Fiche.Ligne(bloc, c, "Button")
        l:SetHeight(math.max(48, c.ligne))
        UI.Fiche.Icone(l, c, VIDE)
        UI.Fiche.Nom(l, c, "Emplacement", true)
        l.effets = UI.Texte(l, "", UI.C.accent)
        UI.Police(l.effets, c.police * 0.72)
        l.effets:SetPoint("LEFT", l, "LEFT", c.plage, 0)
        l.effets:SetPoint("RIGHT", l, "RIGHT", -12 * c.echelle, 0)
        l.effets:SetJustifyH("RIGHT")
        l.effets:SetWordWrap(false)
        l:EnableMouse(true)

        -- Le trait de la case est lu sur la ligne (`l.traitId`, pose par
        -- Actualiser) au moment du clic : les cases sont reutilisees, une
        -- valeur capturee a la creation serait perimee.
        UI.Glisser.Cible(l, function(objet)
            if objet.categorie ~= "traits" then
                return false, "cet emplacement n'accepte qu'un trait (catégorie Traits du compendium)."
            end
            return true
        end, function(objet)
            Poser(l.traitId, objet.element.id)
        end)
        l:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local t = self.traitId and LCM.Traits.Get(self.traitId)
            if t then
                GameTooltip:SetText(t.label)
                local cout = LCM.Traits.Cout(t)
                GameTooltip:AddLine(string.format("Coût : %d point%s", cout, cout > 1 and "s" or ""),
                    0.83, 0.68, 0.33)
                if t.description ~= "" then GameTooltip:AddLine(t.description, 0.88, 0.84, 0.76, true) end
                local effets = UI.Fiche.Effets(t)
                if effets ~= "" then GameTooltip:AddLine(effets, 0.83, 0.68, 0.33, true) end
                GameTooltip:AddLine("Clic gauche : remplacer. Clic droit : voir ou retirer.", 0.6, 0.56, 0.5)
            else
                GameTooltip:SetText("Emplacement")
                GameTooltip:AddLine("Clique pour choisir un trait, ou glisse-le depuis le compendium "
                    .. "(Système d'A'Hell'Razkah, catégorie Traits).", 0.88, 0.84, 0.76, true)
            end
            GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() GameTooltip:Hide() end)
        l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        l:SetScript("OnClick", function(self, bouton)
            local actuel = self.traitId
            if bouton == "RightButton" then
                if not actuel then return end
                local t = LCM.Traits.Get(actuel)
                local options = { { id = "retirer", label = "Retirer" } }
                if t then table.insert(options, 1, { id = "voir", label = "Voir" }) end
                page.menu:Proposer(self, options, function(choix)
                    if choix == "voir" and t then
                        UI.Compendium.Voir(LCM.Compendium.Get("traits"), t, f)
                    elseif choix == "retirer" then
                        C.RetirerTrait(f.brouillon, actuel)
                        f:Actualiser()
                    end
                end)
                return
            end
            -- Tous les traits non pris, avec leur cout : un trait trop cher
            -- reste proposé, et son refus dit combien il manque.
            local options = {}
            local traitsAccessibles = LCM.Traits.Accessibles()
            for _, t in ipairs(traitsAccessibles) do
                if t.id == actuel or not C.ATrait(f.brouillon, t.id) then
                    options[#options + 1] = { id = t.id, icone = t.icone,
                        label = string.format("%s (%d)", t.label, LCM.Traits.Cout(t)) }
                end
            end
            if #options == 0 then
                LCM.Alerte(#traitsAccessibles == 0 and "aucun trait autorisé par le MJ."
                    or "tous les traits du compendium sont déjà pris.")
                return
            end
            page.menu:Proposer(self, options, function(choix)
                if choix then Poser(actuel, choix) end
            end)
        end)
        page.emplacements[index] = l
        return l
    end

    function page:Actualiser()
        local pris = f.brouillon.traits
        local places = tonumber(LCM.Equilibrage.conteneurs.traits) or 0
        local cases = {}
        for _, id in ipairs(pris) do
            local trait = LCM.Traits.Get(id)
            local cout = trait and LCM.Traits.Cout(trait) or 1
            for rang = 1, cout do
                cases[#cases + 1] = { id = id, trait = trait, rang = rang, cout = cout }
            end
        end
        local n = math.max(#cases, math.min(places, #cases + 1))
        local y = Haut(bloc)
        for index = 1, n do
            local l = self.emplacements[index] or Emplacement(index)
            local occupe = cases[index]
            local id = occupe and occupe.id
            local trait = occupe and occupe.trait
            l.traitId = id
            -- Un trait disparu du compendium reste visible, marque : on ne le
            -- retire pas en douce, le joueur le retire d'un clic droit.
            if trait then
                l.icone:SetTexture(trait.icone)
                l.nom:SetText(occupe.rang == 1 and trait.label
                    or string.format("%s (%d/%d)", trait.label, occupe.rang, occupe.cout))
                l.nom:SetTextColor(UI.Compendium.Couleur(trait.couleurTitre or LCM.COULEUR_TITRE))
                l.effets:SetText(occupe.rang == 1 and UI.Fiche.Effets(trait) or "Emplacement occupé")
            elseif id then
                l.icone:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                l.nom:SetText("? " .. tostring(id))
                Teinte(l.nom, UI.C.plein)
                l.effets:SetText("")
            else
                l.icone:SetTexture(VIDE)
                l.nom:SetText("Emplacement")
                Teinte(l.nom, UI.C.discret)
                l.effets:SetText("")
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", bloc, "TOPLEFT", UI.Fiche.MARGE_BLOC, -y)
            l:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -y)
            l:Show()
            y = y + l:GetHeight() + UI.Fiche.ECART_LIGNES
        end
        for index = n + 1, #self.emplacements do self.emplacements[index]:Hide() end
        bloc.hauteurContenu = y - Haut(bloc)
    end
    page:Actualiser()
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("creation", "Création", LARGEUR, HAUTEUR)
    Ecran.frame = f
    f.brouillon = C.Nouveau()
    local m = f.mesures

    -- ----- le recapitulatif -----------------------------------------------
    -- Il repond a la question qu'on se pose tout du long : « qu'est-ce que j'ai
    -- deja mis, et ou ? ». Une categorie repliee ne coute qu'une ligne ;
    -- depliee, elle montre ce qui est investi — jamais les zeros, a 156 champs
    -- la liste serait illisible.
    f.recap = CreateFrame("Frame", nil, f.contenu)
    f.recap:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    -- Le bas se pose dans f:PlacerBas, avec la rangee de boutons.
    f.recap:SetWidth(LARGEUR_RECAP)
    if UI.AelCadre then UI.AelCadre(f.recap, "section") else UI.Bordure(f.recap) end

    f.recap.titre = UI.Texte(f.recap, "Récapitulatif", UI.C.titre)
    UI.Police(f.recap.titre, 13)
    f.recap.titre:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 10, -10)

    -- Les trois chiffres qu'on regarde en repartissant. Hors de la liste
    -- repliable, et sans en-tete a plier : on ne cache pas ce qu'on consulte
    -- en permanence (11 octobre 2026).
    f.recap.vitaux = {}
    for index, vital in ipairs({ { "pv", "Points de vie" }, { "pf", "Fatigue" },
                                 { "pa", "Points d'action" } }) do
        local cle = vital[1]
        local l = CreateFrame("Frame", nil, f.recap)
        l:SetHeight(16)
        l:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 10, -30 - (index - 1) * 16)
        l:SetPoint("RIGHT", f.recap, "RIGHT", -10, 0)
        l.nom = UI.Texte(l, vital[2] .. " :", UI.C.libelle)
        UI.Police(l.nom, 11)
        l.nom:SetPoint("LEFT", l, "LEFT", 0, 0)
        l.valeur = UI.Texte(l, "—", UI.C.accent)
        UI.Police(l.valeur, 12)
        l.valeur:SetPoint("RIGHT", l, "RIGHT", 0, 0)
        l.cle = cle
        UI.Fiche.Bulle(l, vital[2], function()
            local apercu = Apercu(f.brouillon)
            if cle == "pv" then return UI.Fiche.DecompositionVie(apercu) end
            local id = cle == "pf" and "fatigue" or "pa"
            return UI.Fiche.DecompositionJauge(LCM.Entities.Gauge(apercu, id),
                LCM.Schema.Field(id).note, apercu, id)
        end)
        f.recap.vitaux[index] = l
    end
    f.recap.filet = UI.Filet(f.recap, true)
    f.recap.filet:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 10, -82)
    f.recap.filet:SetPoint("TOPRIGHT", f.recap, "TOPRIGHT", -10, -82)

    f.recapZone = UI.Defilement(f.recap)
    f.recapZone:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 8, -90)
    f.recapZone:SetPoint("BOTTOMRIGHT", f.recap, "BOTTOMRIGHT", -8, 10)
    f.recap.entetes, f.recap.lignes = {}, {}
    f.deplie = { identite = true, primaires = true }

    local onglets, capaciteAjoutee = {}, false
    for _, etape in ipairs(C.ETAPES) do
        if etape.id == "expertises" or etape.id == "mecaniques" then
            if not capaciteAjoutee then
                onglets[#onglets + 1] = { id = "capacites", label = "Capacité" }
                capaciteAjoutee = true
            end
        else
            onglets[#onglets + 1] = { id = etape.id, label = etape.label }
        end
    end
    f.barre = UI.BandeauOnglets(f.contenu, onglets, function(id) f:Afficher(id) end)
    f.barre:SetPoint("TOPLEFT", f.recap, "TOPRIGHT", 12, 0)
    f.barre:SetWidth(LARGEUR_PAGE)
    -- Les sept etapes sur une seule ligne : empilees sur trois rangees, elles
    -- mangeaient le tiers de la fenetre et noyaient l'etape ou l'on est.
    local hauteurBandeau = f.barre:Disposer(LARGEUR_PAGE, m.onglet, { uneRangee = true })
    f.barreCapacites = UI.BandeauOnglets(f.contenu, {
        { id = "expertises", label = "Expertise" },
        { id = "mecaniques", label = "Mécanique" },
    }, function(id) f:Afficher(id) end)
    f.barreCapacites:SetPoint("TOPLEFT", f.barre, "BOTTOMLEFT", 0, -6)
    f.barreCapacites:SetWidth(LARGEUR_PAGE)
    f.barreCapacites:Disposer(LARGEUR_PAGE, m.onglet, { uneRangee = true })
    f.barreCapacites:Hide()
    f.barresDomaines = {}
    for etapeId, domaines in pairs({
        expertises = { "Observations", "Athlétisme", "Filouterie" },
        mecaniques = { "Compétence", "Défense" },
    }) do
        local choix = {}
        for _, domaine in ipairs(domaines) do choix[#choix + 1] = { id = domaine, label = domaine } end
        local barre = UI.BandeauOnglets(f.contenu, choix, function(id) f:ChoisirDomaine(id) end)
        barre:SetPoint("TOPLEFT", f.barreCapacites, "BOTTOMLEFT", 0, -6)
        barre:SetWidth(LARGEUR_PAGE)
        barre:Disposer(LARGEUR_PAGE, m.onglet, { uneRangee = true })
        barre:Hide()
        f.barresDomaines[etapeId] = barre
    end

    -- En bas : ce qui bloque, et les trois gestes.
    f.valider = UI.Bouton(f.contenu, "Créer le personnage", 190, 26, function()
        if f.brouillon.mode == "pnj" then
            if type(f.sauverPNJ) ~= "function" then
                LCM.Alerte("enregistrement du PNJ indisponible.")
                return
            end
            local ok, resultat = f.sauverPNJ(f.brouillon)
            if not ok then
                LCM.Alerte(tostring(resultat))
                return
            end
            LCM.Ok(string.format("PNJ %s enregistré dans le compendium.", tostring(resultat or f.brouillon.nom)))
            f:Hide()
            return
        end
        local montee = f.brouillon.mode == "niveau"
        local edition = f.brouillon.entite ~= nil
        local entity, resultat = C.Appliquer(f.brouillon)
        if not entity then
            LCM.Alerte(tostring(resultat))
            return
        end
        if montee then
            LCM.Ok(string.format("niveau %d validé pour %s.", f.brouillon.niveau, tostring(entity.name)))
            if UI.Radial and UI.Radial.Rafraichir then UI.Radial.Rafraichir() end
            if (tonumber(resultat) or 0) > 0 then
                local suivant, erreur = C.DepuisNiveau(entity)
                if not suivant then LCM.Alerte(tostring(erreur)) f:Hide() return end
                f:Montrer(suivant)
                return
            end
            f:Hide()
            UI.Fiche.Fenetre():Montrer(entity)
            return
        end
        LCM.Ok(edition and string.format("la fiche de %s a été rééditée.", tostring(entity.name))
            or string.format("%s rejoint les Contes.", tostring(entity.name)))
        f:Hide()
        if UI.Personnages and UI.Personnages.frame and UI.Personnages.frame:IsShown() then
            UI.Personnages.frame:Montrer()
        end
        UI.Fiche.Fenetre():Montrer(entity)
    end)
    -- « Créer le personnage » tout a droite, et SEULEMENT sur la derniere
    -- etape : c'est l'aboutissement du parcours, pas un bouton qu'on croise
    -- sept fois et sur lequel on finit par cliquer trop tot.

    -- La navigation, au centre : on avance d'une etape a la fois, et on peut
    -- revenir. Les onglets restent, pour sauter directement quelque part.
    f.precedent = UI.Bouton(f.contenu, "< Précédent", 120, 26, function() f:Pas(-1) end)
    f.suivant = UI.Bouton(f.contenu, "Suivant >", 120, 26, function() f:Pas(1) end)
    -- « Precedent » s'accroche au bouton de droite VISIBLE (Suivant, ou Creer
    -- a la derniere etape) : voir Actualiser.

    -- Abandonner : la fenetre se ferme et le brouillon part. Avec la remise a
    -- zero, ce sont les deux gestes qui DEFONT : ils vivent sous le
    -- recapitulatif, a gauche, loin de ceux qui font avancer.
    f.abandonner = UI.Bouton(f.contenu, "Abandonner", LARGEUR_RECAP, 26, function() f:Hide() end)
    -- Tout remettre a zero se confirme : c'est le seul geste qu'on ne peut pas
    -- defaire d'un clic.
    f.confirmation = UI.Confirmer(f, "", "Tout remettre a zero")
    f.remiseTotale = UI.Bouton(f.contenu, "Tout remettre à zéro", 170, 26, function()
        f.confirmation:Demander(
            "Remettre a zero tous les points depenses ?\nLe nom, la race et l'identite sont conserves.",
            function()
                C.RemettreTout(f.brouillon)
                f:Actualiser()
            end)
    end)
    f.remiseTotale:SetPoint("BOTTOMLEFT", f.abandonner, "TOPLEFT", 0, 6)
    f.remiseTotale:SetWidth(LARGEUR_RECAP)

    -- Ce qui bloque, a droite au-dessus des boutons qui font avancer : c'est la
    -- qu'on regarde quand « Créer le personnage » refuse de s'allumer.
    f.probleme = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.probleme, 12)
    f.probleme:SetJustifyH("RIGHT")

    f.zone = UI.Defilement(f.contenu)
    -- Ce qui est pose AU-DESSUS de la zone : la rangee d'onglets.
    f.hautZoneCreation = hauteurBandeau + 10
    f.zone:SetPoint("TOPLEFT", f.recap, "TOPRIGHT", 12, -(hauteurBandeau + 34))
    f.zone:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -(hauteurBandeau + 34))

    -- La rangee du bas (et ce qui s'appuie dessus) se pose au-dessus de ce que
    -- l'habillage mange a l'interieur de la fenetre : au ras du contenu, les
    -- boutons passaient sur le liseré et l'equerre doree du coin (3 octobre
    -- 2026). Refait a chaque ouverture : le theme a pu changer entre-temps.
    function f:PlacerBas()
        local e = UI.AelEmprise(self)
        local dy = math.max(0, math.ceil(e.bas + 4 - (self.insetBas or 0)))
        local dx = math.max(0, math.ceil(e.cote + 4 - (self.insetCote or 0)))
        self.bas = { dx = dx, dy = dy }
        self.recap:SetPoint("BOTTOMLEFT", self.contenu, "BOTTOMLEFT", 0, dy)
        self.valider:ClearAllPoints()
        self.valider:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", -dx, dy)
        self.suivant:ClearAllPoints()
        self.suivant:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", -dx, dy)
        self.abandonner:ClearAllPoints()
        -- A gauche, les boutons restent alignes sur le recapitulatif, qu'ils
        -- prolongent : seul le bas compte.
        self.abandonner:SetPoint("BOTTOMLEFT", self.contenu, "BOTTOMLEFT", 0, dy)
        self.probleme:ClearAllPoints()
        self.probleme:SetPoint("BOTTOMLEFT", self.contenu, "BOTTOMLEFT", LARGEUR_RECAP + 12, dy + 32)
        self.probleme:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", -dx, dy + 32)
        self.zone:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", 0, dy + 60)
    end
    f:PlacerBas()
    f:HookScript("OnShow", function(self) self:PlacerBas() end)

    f.pages = {}
    for _, etape in ipairs(C.ETAPES) do
        local page = NouvellePage(f)
        Pages[etape.id](page, f)
        page:Disposer()
        f.pages[etape.id] = page
    end

    -- Les categories du recapitulatif, dans l'ordre des etapes.
    local RECAP = {
        { id = "identite",    label = "Identité" },
        { id = "primaires",   label = "Statistiques" },
        { id = "secondaires", label = "Secondaires" },
        { id = "expertises",  label = "Expertises" },
        { id = "mecaniques",  label = "Mécaniques" },
        { id = "penetration", label = "Pénétrations" },
        { id = "resistance",  label = "Résistances" },
        { id = "traits",      label = "Traits" },
        { id = "metiers",     label = "Métiers" },
    }

    -- Ce qu'une categorie montre quand on la deplie. On ne liste que ce qui est
    -- investi : les zeros n'apprennent rien.
    local function LignesRecap(brouillon, categorie)
        local out = {}
        if categorie == "identite" then
            if brouillon.mode == "niveau" then
                out[#out + 1] = { "Passage", string.format("%d → %d", brouillon.niveauAvant, brouillon.niveau) }
                return out
            end
            local race = brouillon.race ~= "" and LCM.Races.Get(brouillon.race)
            out[#out + 1] = { "Nom", brouillon.nom ~= "" and brouillon.nom or "—" }
            out[#out + 1] = { "Race", (race and race.label) or "—" }
            out[#out + 1] = { "Niveau", tostring(brouillon.niveau) }
            if brouillon.valeurs.sexe then
                out[#out + 1] = { "Sexe", tostring(brouillon.sexeAutre or brouillon.valeurs.sexe) }
            end
            if brouillon.valeurs.age then out[#out + 1] = { "Âge", tostring(brouillon.valeurs.age) } end
            if brouillon.valeurs.poids then out[#out + 1] = { "Poids", tostring(brouillon.valeurs.poids) .. " kg" } end
            return out
        end
        if categorie == "traits" then
            for _, id in ipairs(brouillon.traits) do
                if not (brouillon.mode == "niveau" and brouillon.base and C.ATrait(brouillon.base, id)) then
                    local trait = LCM.Traits.Get(id)
                    local cout = LCM.Traits.Cout(trait)
                    out[#out + 1] = { (trait and trait.label) or id,
                        brouillon.mode == "niveau" and ("+" .. tostring(cout)) or tostring(cout) }
                end
            end
            return out
        end
        if categorie == "metiers" then
            for _, metier in ipairs(LCM.Metiers.list) do
                local niveau = tonumber((brouillon.metiers or {})[metier.id]) or 0
                if niveau > 0 then out[#out + 1] = { metier.label, tostring(niveau) } end
            end
            return out
        end
        for _, ligne in ipairs(C.Lignes(categorie)) do
            local valeur = C.Valeur(brouillon, ligne.id)
            if brouillon.mode == "niveau" and brouillon.base then
                local gain = valeur - C.Valeur(brouillon.base, ligne.id)
                if gain > 0 then out[#out + 1] = { ligne.label, "+" .. tostring(gain) } end
            elseif valeur > 0 then
                out[#out + 1] = { ligne.label, tostring(valeur) }
            end
        end
        return out
    end

    -- Les trois chiffres vitaux, lus sur l'apercu : la fiche telle qu'elle
    -- sera, race, traits et points secondaires compris.
    function f:ActualiserVitaux()
        local apercu = Apercu(self.brouillon)
        local valeurs = {}
        local okPV, pv = pcall(function() return LCM.Body.MaxTotal(apercu) end)
        valeurs.pv = okPV and pv or nil
        for cle, jauge in pairs({ pf = "fatigue", pa = "pa" }) do
            local ok, j = pcall(function() return LCM.Entities.Gauge(apercu, jauge) end)
            valeurs[cle] = (ok and j and j.max) or nil
        end
        for _, l in ipairs(self.recap.vitaux) do
            local v = valeurs[l.cle]
            l.valeur:SetText(v and tostring(math.floor(v)) or "—")
        end
    end

    function f:ActualiserRecap()
        self:ActualiserVitaux()
        local y, index, indexLigne = 0, 0, 0
        for _, categorie in ipairs(RECAP) do
            index = index + 1
            local h = self.recap.entetes[index]
            if not h then
                -- L'identifiant de l'iteration, pas le compteur : toutes les
                -- fermetures partageraient le second.
                local categorieId = categorie.id
                h = UI.Bouton(self.recapZone.contenu, "", LARGEUR_RECAP - 24, 20, function()
                    self.deplie[categorieId] = not self.deplie[categorieId]
                    self:ActualiserRecap()
                end)
                h.label:ClearAllPoints()
                h.label:SetPoint("LEFT", h, "LEFT", 4, 0)
                h.label:SetJustifyH("LEFT")
                h.compte = UI.Texte(h, "", UI.C.discret)
                UI.Police(h.compte, 11)
                h.compte:SetPoint("RIGHT", h, "RIGHT", -4, 0)
                self.recap.entetes[index] = h
            end
            local ouvert = self.deplie[categorie.id] and true or false
            h.label:SetText((ouvert and "- " or "+ ") .. categorie.label)
            h:Selectionner(ouvert)
            if categorie.id == "identite" then
                h.compte:SetText("")
            else
                local budget = C.Budget(self.brouillon, categorie.id)
                h.compte:SetText(string.format("%d / %d", budget.reste, budget.total))
                local teinte = budget.reste < 0 and UI.C.plein
                    or (budget.reste == 0 and UI.C.discret or UI.C.titre)
                h.compte:SetTextColor(teinte[1], teinte[2], teinte[3])
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.recapZone.contenu, "TOPLEFT", 0, -y)
            h:Show()
            y = y + 22

            if ouvert then
                for _, paire in ipairs(LignesRecap(self.brouillon, categorie.id)) do
                    indexLigne = indexLigne + 1
                    local l = self.recap.lignes[indexLigne]
                    if not l then
                        l = CreateFrame("Frame", nil, self.recapZone.contenu)
                        l:SetSize(LARGEUR_RECAP - 28, 15)
                        l.nom = UI.Texte(l, "", UI.C.discret)
                        UI.Police(l.nom, 11)
                        l.nom:SetPoint("LEFT", l, "LEFT", 10, 0)
                        l.valeur = UI.Texte(l, "", UI.C.texte)
                        UI.Police(l.valeur, 11)
                        l.valeur:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                        l.valeur:SetJustifyH("RIGHT")
                        self.recap.lignes[indexLigne] = l
                    end
                    l.nom:SetText(paire[1])
                    l.valeur:SetText(paire[2])
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", self.recapZone.contenu, "TOPLEFT", 0, -y)
                    l:Show()
                    y = y + 16
                end
                y = y + 4
            end
        end
        for i = index + 1, #self.recap.entetes do self.recap.entetes[i]:Hide() end
        for i = indexLigne + 1, #self.recap.lignes do self.recap.lignes[i]:Hide() end
        self.recapZone:Regler(y)
    end

    -- Avancer ou reculer d'une etape. On s'arrete aux extremites plutot que de
    -- boucler : revenir a « Bienvenue » depuis « Traits » en cliquant Suivant
    -- donnerait l'impression d'avoir perdu son travail.
    -- Un seul budget visible : celui de l'etape ouverte, epingle au-dessus de
    -- la zone qui defile.
    function f:PlacerBudget()
        local page = self.pages[self.etape]
        local budgets = (page and page.budgets) or {}
        for _, bloc in ipairs(budgets) do
            -- Sur la ligne du titre de SON bloc, a droite. Une page peut porter
            -- plusieurs grilles (Statistiques en a deux) : chacune compte son
            -- propre pool, en face de son propre titre.
            bloc.remise:ClearAllPoints()
            bloc.budget:ClearAllPoints()
            bloc.remise:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -14,
                -(bloc.hautTitre - 20) / 2)
            bloc.budget:SetPoint("RIGHT", bloc.remise, "LEFT", -8, 0)
            bloc.remise:Show()
            bloc.budget:Show()
        end
        for id, autre in pairs(self.pages) do
            if id ~= self.etape then
                for _, bloc in ipairs(autre.budgets or {}) do
                    bloc.remise:Hide()
                    bloc.budget:Hide()
                end
            end
        end
    end

    local ETAPE_CATEGORIES = {
        statistiques = { "primaires", "secondaires" },
        expertises = { "expertises" }, mecaniques = { "mecaniques" },
        metiers = { "metiers" },
        penetrations = { "penetration" }, resistances = { "resistance" },
        traits = { "traits" },
    }

    function f:EtapesDisponibles()
        if self.brouillon.mode ~= "niveau" then
            local out = {}
            for _, etape in ipairs(C.ETAPES) do
                if etape.id ~= "metiers" or C.Total(self.brouillon, "metiers") > 0 then
                    out[#out + 1] = etape
                end
            end
            return out
        end
        local out = {}
        for _, etape in ipairs(C.ETAPES) do
            local visible = etape.id == "generale"
            for _, categorie in ipairs(ETAPE_CATEGORIES[etape.id] or {}) do
                if C.Budget(self.brouillon, categorie).total > 0 then visible = true end
            end
            if visible then out[#out + 1] = etape end
        end
        return out
    end

    function f:ActualiserEtapes()
        self.etapes = self:EtapesDisponibles()
        local visibles = {}
        for _, etape in ipairs(self.etapes) do visibles[etape.id] = true end
        for _, bouton in ipairs(self.barre.boutons) do
            local id = bouton.ongletId
            bouton:SetShown(id == "capacites" and (visibles.expertises or visibles.mecaniques)
                or (id ~= "capacites" and visibles[id]) or false)
        end
        self.barre:Disposer(LARGEUR_PAGE, m.onglet, { uneRangee = true })
        for _, bouton in ipairs(self.barreCapacites.boutons) do
            bouton:SetShown(visibles[bouton.ongletId] or false)
        end
        if self.barreCapacites:IsShown() then
            self.barreCapacites:Disposer(LARGEUR_PAGE, m.onglet, { uneRangee = true })
        end
    end

    function f:Pas(sens)
        local rang = 1
        for index, etape in ipairs(self.etapes or C.ETAPES) do
            if etape.id == self.etape then rang = index end
        end
        local cible = (self.etapes or C.ETAPES)[rang + sens]
        if cible then self:Afficher(cible.id) end
    end

    function f:ChoisirDomaine(domaine)
        local page = self.pages[self.etape]
        if not (page and page.domaines and page.domaines[domaine]) then return end
        self.domaineActif = self.domaineActif or {}
        self.domaineActif[self.etape] = domaine
        for id, bloc in pairs(page.domaines) do bloc:SetShown(id == domaine) end
        self.barresDomaines[self.etape]:Selectionner(domaine)
        self.zone.decalage = 0
        self:Actualiser()
    end

    function f:Afficher(etapeId)
        if etapeId == "capacites" then
            local actuel = self.etape
            if actuel == "expertises" or actuel == "mecaniques" then etapeId = actuel
            else
                local disponibles = self:EtapesDisponibles()
                local expertiseVisible = false
                for _, etape in ipairs(disponibles) do
                    if etape.id == "expertises" then expertiseVisible = true end
                end
                etapeId = expertiseVisible and "expertises" or "mecaniques"
            end
        end
        self.etape = etapeId
        local capacites = etapeId == "expertises" or etapeId == "mecaniques"
        self.barre:Selectionner(capacites and "capacites" or etapeId)
        self.barreCapacites:SetShown(capacites)
        if capacites then
            self.barreCapacites:Disposer(LARGEUR_PAGE, m.onglet, { uneRangee = true })
            self.barreCapacites:Selectionner(etapeId)
        end
        for id, barre in pairs(self.barresDomaines) do barre:SetShown(capacites and id == etapeId) end
        local supplement = capacites and (2 * (m.onglet + 6)) or 0
        local hautZone = hauteurBandeau + 34 + supplement
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", self.recap, "TOPRIGHT", 12, -hautZone)
        self.zone:SetPoint("TOPRIGHT", self.contenu, "TOPRIGHT", 0, -hautZone)
        self.zone:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", 0,
            (self.bas and self.bas.dy or 0) + 60)
        for id, page in pairs(self.pages) do page:SetShown(id == etapeId) end
        if capacites then
            local page = self.pages[etapeId]
            local defaut = etapeId == "expertises" and "Observations" or "Compétence"
            local domaine = self.domaineActif and self.domaineActif[etapeId] or defaut
            for id, bloc in pairs(page.domaines) do bloc:SetShown(id == domaine) end
            self.barresDomaines[etapeId]:Selectionner(domaine)
        end
        self.zone.decalage = 0
        self:Actualiser()
    end

    function f:Actualiser()
        self:ActualiserEtapes()
        self:ActualiserRecap()
        local page = self.pages[self.etape]
        if not page then return end
        -- Les compteurs relisent tout : un plafond peut avoir bouge a cause
        -- d'une modification faite dans un autre onglet.
        local apercu = Apercu(self.brouillon)
        for _, compteur in ipairs(page.compteurs) do
            local investi = C.Valeur(self.brouillon, compteur.champ)
            compteur:Regler(investi, C.Plafond(self.brouillon, compteur.categorie, compteur.champ))
            -- Le total : ce qu'on a mis, plus ce que la race (ou un trait)
            -- apporte. Le bonus est dit a part pour qu'on sache d'ou il vient.
            local bonus = LCM.Effets.Bonus(apercu, compteur.champ)
            compteur.bonus = bonus
            if compteur.total then
                local rendement = RENDEMENTS[compteur.champ]
                local budget = BUDGETS_SECONDAIRES[compteur.champ]
                local texte
                if rendement then
                    texte = rendement(apercu)
                elseif budget then
                    texte = string.format("%d pts", C.Total(self.brouillon, budget))
                elseif bonus ~= 0 then
                    -- Le calcul en entier, dans l'ordre ou il se fait : ce que
                    -- la RACE donne (gris, on n'y peut rien), ce qu'on DEPENSE
                    -- (orange, c'est notre geste), et le TOTAL.
                    texte = string.format("|cff8a8a8a%d|r |cffff9933+ %d|r = |cfff2d9a1%d|r",
                        bonus, investi, investi + bonus)
                else
                    -- Sans apport racial, il n'y a rien a additionner : le
                    -- total seul, a la meme place, pour que la colonne se lise
                    -- d'un trait.
                    texte = string.format("= |cfff2d9a1%d|r", investi)
                end
                compteur.total:SetText(texte)
                local teinte = (rendement or budget or bonus ~= 0) and UI.C.accent or UI.C.discret
                compteur.total:SetTextColor(teinte[1], teinte[2], teinte[3])
            end
        end
        for _, bloc in ipairs(page.budgets) do
            local budget = C.Budget(self.brouillon, bloc.categorie)
            bloc.budget:SetText(string.format("%d / %d", budget.reste, budget.total))
            local couleur = UI.C.titre
            if budget.reste < 0 then couleur = UI.C.plein elseif budget.reste == 0 then couleur = UI.C.discret end
            bloc.budget:SetTextColor(couleur[1], couleur[2], couleur[3])
        end
        if page.Actualiser then page:Actualiser() end
        page:Disposer()
        self.zone:Regler(page.hauteur)

        -- La derniere etape est la seule qui propose de creer ; partout
        -- ailleurs, c'est « Suivant » qui occupe cette place.
        local etapes = self.etapes or C.ETAPES
        local rang, dernier = 1, #etapes
        for index, etape in ipairs(etapes) do
            if etape.id == self.etape then rang = index end
        end
        self.valider:SetShown(rang == dernier)
        self.suivant:SetShown(rang < dernier)
        -- Un ecart franc entre les deux : colles, leurs cadres se chevauchaient.
        self.precedent:ClearAllPoints()
        self.precedent:SetPoint("RIGHT", rang == dernier and self.valider or self.suivant, "LEFT", -6, 0)
        self.precedent:SetEnabled(rang > 1)

        -- Le budget de l'etape ouverte, epingle en haut a droite de la page.
        self:PlacerBudget()

        local problemes = C.Problemes(self.brouillon)
        self.probleme:SetText(problemes[1] or "")
        self.valider:SetEnabled(#problemes == 0)
        local teinte = (#problemes == 0) and UI.C.titre or UI.C.discret
        self.valider.label:SetTextColor(teinte[1], teinte[2], teinte[3])
    end

    f:SetScript("OnHide", function(self)
        self.confirmation:Hide()
        -- Echap fait partie des UISpecialFrames et peut donc cacher la fenetre
        -- sans passer par notre croix. Une refonte obligatoire revient tant
        -- qu'elle n'a pas ete validee, sauf pendant une deconnexion/recharge.
        if self.brouillon and self.brouillon.mode == "reequilibrage"
            and C.ReequilibrageRequis(self.brouillon.entite)
            and not Ecran.deconnexion
        then
            local function Rouvrir()
                if self.brouillon and C.ReequilibrageRequis(self.brouillon.entite) then self:Show() end
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, Rouvrir) else Rouvrir() end
            return
        end
        if self.retourSelection then
            self.retourSelection = nil
            UI.Personnages.Fenetre():Montrer()
        end
    end)

    function f:Montrer(brouillon)
        self.brouillon = brouillon or self.brouillon or C.Nouveau()
        local montee = self.brouillon.mode == "niveau"
        local pnj = self.brouillon.mode == "pnj"
        -- Un PNJ REPRIS n'est pas un PNJ cree : on le dit, pour qu'on ne
        -- croie pas en fabriquer un second.
        local repris = pnj and self.brouillon.pnj ~= nil
        local reequilibrage = self.brouillon.mode == "reequilibrage"
        local edition = self.brouillon.entite ~= nil
        self:Titre(reequilibrage and "Rééquilibrage requis"
            or (montee and string.format("Niveau %d → %d", self.brouillon.niveauAvant, self.brouillon.niveau)
            or (pnj and (repris and "Réédition d'un PNJ" or "Création d'un PNJ")
            or (edition and "Réédition" or "Création"))))
        self.valider.label:SetText(montee and ("Valider le niveau " .. tostring(self.brouillon.niveau))
            or (reequilibrage and "Valider le rééquilibrage"
            or (pnj and (repris and "Enregistrer le PNJ" or "Créer le PNJ")
            or (edition and "Valider la fiche" or "Créer le personnage"))))
        self.recap.titre:SetText(montee and "Gains de ce niveau"
            or (reequilibrage and "Nouvel équilibrage" or "Récapitulatif"))
        self.remiseTotale.label:SetText(montee and "Réinitialiser ce niveau" or "Tout remettre à zéro")
        self.fermer:SetShown(not reequilibrage)
        self.abandonner:SetShown(not reequilibrage)
        self:Afficher(montee and "generale" or C.ETAPES[1].id)
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Actualiser()
    if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Actualiser() end
end

local function ProfilActifAReequilibrer()
    local entity = LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage()
    return entity and C.ReequilibrageRequis(entity) and entity or nil
end

-- Toujours sur un brouillon neuf : « creer un personnage » ne doit pas reprendre
-- les restes de la fois d'avant.
function Ecran.Ouvrir()
    local impose = ProfilActifAReequilibrer()
    if impose then return Ecran.Reequilibrer(impose) end
    local f = Ecran.Fenetre()
    f.sauverPNJ = nil
    f:Montrer(C.Nouveau())
    return f
end

-- Point d'entree du compagnon MJ : meme createur, mais la validation lui rend
-- une definition a enregistrer dans le compendium au lieu de creer un joueur.
--
-- `brouillon` sert a REPRENDRE un PNJ existant (Creation.DepuisPNJ) : meme
-- parcours, mais rempli de ce qu'il est deja.
function Ecran.OuvrirPNJ(sauver, brouillon)
    local impose = ProfilActifAReequilibrer()
    if impose then return Ecran.Reequilibrer(impose) end
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    if type(sauver) ~= "function" then return nil, "enregistrement du PNJ indisponible." end
    if brouillon ~= nil and (type(brouillon) ~= "table" or brouillon.mode ~= "pnj") then
        return nil, "reprise de PNJ invalide."
    end
    local f = Ecran.Fenetre()
    f.sauverPNJ = sauver
    f:Montrer(brouillon or C.NouveauPNJ())
    return f
end

function Ecran.Editer(entity)
    local impose = ProfilActifAReequilibrer()
    if impose and entity ~= impose then return Ecran.Reequilibrer(impose) end
    entity = entity or (LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage())
    local peut, raison = C.PeutEditer(entity)
    if not peut then return nil, raison end
    local brouillon, erreur
    if C.ReequilibrageRequis(entity) then
        brouillon, erreur = C.DepuisReequilibrage(entity)
    else
        brouillon, erreur = C.Depuis(entity)
    end
    if not brouillon then return nil, erreur end
    local f = Ecran.Fenetre()
    f.sauverPNJ = nil
    f:Montrer(brouillon)
    return f
end

function Ecran.Reequilibrer(entity)
    entity = entity or (LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage())
    if not C.ReequilibrageRequis(entity) then return nil, "aucun rééquilibrage requis." end
    local brouillon, erreur = C.DepuisReequilibrage(entity)
    if not brouillon then return nil, erreur end
    local f = Ecran.Fenetre()
    f.sauverPNJ = nil
    f:Montrer(brouillon)
    LCM.Alerte("les règles de création ont évolué : répartis à nouveau tes points pour continuer.")
    return f
end

function Ecran.MonterNiveau(entity)
    local impose = ProfilActifAReequilibrer()
    if impose then return Ecran.Reequilibrer(impose) end
    entity = entity or (LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage())
    local brouillon, erreur = C.DepuisNiveau(entity)
    if not brouillon then return nil, erreur end
    local f = Ecran.Fenetre()
    f.sauverPNJ = nil
    f:Montrer(brouillon)
    return f
end

LCM.WhenReady(function()
    UI.Menu.Lier("montee_niveau", function()
        local f, erreur = Ecran.MonterNiveau()
        if not f then LCM.Alerte(tostring(erreur)) end
    end)
    local function VerifierReequilibrage()
        local entity = LCM.Entities and LCM.Entities.Personnage and LCM.Entities.Personnage()
        if entity and C.ReequilibrageRequis(entity) then Ecran.Reequilibrer(entity) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, VerifierReequilibrage)
    else VerifierReequilibrage() end
    if LCM.Entities and LCM.Entities.EcouterSoi then
        LCM.Entities.EcouterSoi(function(_, entity)
            if not C.applicationEnCours and entity and entity.kind == "player"
                and C.ReequilibrageRequis(entity)
            then
                Ecran.Reequilibrer(entity)
            end
        end)
    end
end)

LCM.On("PLAYER_LOGOUT", function() Ecran.deconnexion = true end)

LCM.AddCommand("creer", "cree un personnage", function() Ecran.Ouvrir() end)
LCM.AddCommand("editer", "réédite ton personnage (MJ ou avec un jeton)", function()
    local f, raison = Ecran.Editer()
    if not f then LCM.Alerte(tostring(raison)) end
end)
LCM.AddCommand("niveau", "répartit les points d'un niveau en attente", function()
    local f, raison = Ecran.MonterNiveau()
    if not f then LCM.Alerte(tostring(raison)) end
end)
