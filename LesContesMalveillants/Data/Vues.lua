-- Les fenetres tirees de la fiche, telles que le template Necronicon les
-- organise (« Template Fiche LVL 5 - Contes Malveillants V2 ») : memes
-- fenetres, memes onglets, memes blocs, dans le meme ordre.
--
-- Chaque vue habille l'entree du menu qui porte son identifiant. Elle ne
-- declare pas de champ : elle designe ce qui existe dans la feuille (voir
-- Core/Vues.lua).

local _, LCM = ...
local Vues = LCM.Vues

-- Regles : huit onglets, seul FONDAMENTAUX est rempli dans le template. Chaque
-- separateur y ouvre un bloc, suivi de sa description en <taille=14>. Texte
-- d'origine, coquilles comprises ; le dernier separateur n'a pas de texte.
local TAILLE_REGLES = 14
Vues.Add({
    id = "regles", titre = "Règles",
    -- Les chapitres sont a gauche, en sommaire : la colonne prend 174, la page
    -- garde la largeur d'une page de texte.
    largeur = 580, hauteur = 520,
    sansPersonnage = true,
    sommaire = true,
    onglets = {
        { id = "fondamentaux", label = "Fondamentaux", blocs = {
            { label = "Principe", taille = TAILLE_REGLES, texte =
                "Les contes malveillants sont un univers de jeu de rôle dans lequel chaque joueur incarne un "
                .. "personnage disposant de ses propres caractéristiques, compétences et capacités.\n\n"
                .. "Les personnages évoluent au fil des aventures, développent leurs aptitudes et affrontent des "
                .. "situations dont l'issue dépend de leurs décisions, de leurs capacités et du hasard.\n\n"
                .. "Le système repose sur une combinaison de caractéristiques, de jets de dés et de différentes "
                .. "ressources permettant de déterminer les possibilités de chaque personnage." },
            { label = "Maitres du jeu", taille = TAILLE_REGLES, texte =
                "Le ou les maîtres du jeu, ou MJ, sont responsables de la narration, de l'environnement et des "
                .. "personnages non joueurs.\n\n"
                .. "Ils décrivent  les situations auxquelles les personnages sont confrontés, interprètent les "
                .. "conséquences de leurs actions et déterminent les difficultés des épreuves.\n\n"
                .. "Lorsque les règles ne permettent pas de résoudre directement une situation, le ou les MJ "
                .. "disposent de l'autorité nécessaire pour prendre une décision cohérente avec le contexte." },
            { label = "Les joueurs :", taille = TAILLE_REGLES, texte =
                "Un personnage peut entreprendre toute action cohérente avec ses capacités et son environnement.\n\n"
                .. "Les actions courantes ne nécessitent pas systématiquement de jet. En revanche, lorsqu'une action "
                .. "présente une difficulté, un risque ou une opposition, le MJ peut demander au joueur d'effectuer "
                .. "un test.\n\n"
                .. "Le choix des caractéristiques et des compétences employées dépend de la nature de l'action.\n\n"
                .. "Il est exigé des joueurs d'être en mesure de jouer dans la limite des capacités de son "
                .. "personnage." },
            { label = "Le principe des tests", taille = TAILLE_REGLES, texte =
                "Les tests permettent de déterminer l'issue des actions dont la réussite est incertaine.\n\n"
                .. "Lorsqu'un test est nécessaire, le personnage utilise les caractéristiques et les compétences "
                .. "correspondant à l'action entreprise. Le résultat est comparé à une difficulté ou, lorsqu'il "
                .. "affronte un adversaire, à un résultat opposé.\n\n"
                .. "La réussite ou l'échec du test détermine les conséquences de l'action, et il est généralement à "
                .. "charge du joueur de dérouler une narration en cohérence avec le résultat obtenu. \n\n"
                .. "Un maitre du jeu demeure néanmoins en mesure d'offrir ou d'imposer des conditions de narration." },
            { label = "[NF] - No Fatigue", texte = "" },
        } },
        { id = "personnages",  label = "Personnages",         vide = true },
        { id = "ressources",   label = "Ressources",          vide = true },
        { id = "tests",        label = "Tests et Expertises", vide = true },
        { id = "combat",       label = "Combat",              vide = true },
        { id = "magie",        label = "Magie et effets",     vide = true },
        { id = "equipement",   label = "Équipement",          vide = true },
        { id = "progression",  label = "Progression",         vide = true },
    },
})

-- Fiche : STATISTIQUES (Generale, Statistiques, Caracteristiques,
-- Deplacement), FACULTES (Physiques), TRAITS.
Vues.Add({
    id = "fiche", titre = "Fiche",
    largeur = 340, hauteur = 470,
    onglets = {
        { id = "statistiques", label = "Statistiques", blocs = {
            -- La jauge des PV seule : les zones sont dans Sante. La surcharge
            -- des PV n'apparait qu'au MJ.
            -- La jauge « Armure » a quitte la fiche le 3 octobre 2026 : elle n'existe
            -- pas sur celle de Necronicon. La mecanique, elle, reste (valeur par
            -- piece, usure conservee, repartition d'une attaque) : c'est la LIGNE
            -- qu'on retire, pas la regle.
            { label = "Générale", champs = { { id = "corps", zones = false }, "armure", "fatigue", "pa" } },
            { label = "Habilités", champs = { "adresse", "esprit" } },
            { label = "Statistiques", champs = { "force", "mystique", "perception", "constitution" } },
            { label = "Caractéristiques", champs = { "initiative" } },
            { label = "Déplacement", champs = { "depl_terrestre", "depl_nage" } },
        } },
        { id = "facultes", label = "Facultés", blocs = {
            { section = { "statistiques", "facultes" }, label = "Physiques" },
        } },
        { id = "traits", label = "Traits", blocs = {
            { champs = { "traits_portes" } },
        } },
    },
})

-- Sante : Sante Globale (ce qui tient le personnage debout), Physique (ses
-- etats), Maladies, Intangible.
--
-- Les IDENTIFIANTS gardent leur nom d'origine — `physique` porte desormais
-- « Santé Globale », et `etats` porte « Physique » (le MJ, 24 octobre 2026).
-- Ils designent l'onglet dans ce qui est deja enregistre ; les renommer aurait
-- rouvert la fenetre sur un autre volet que celui qu'on avait quitte.
Vues.Add({
    id = "sante", titre = "Santé",
    largeur = 336, hauteur = 450,
    onglets = {
        { id = "physique", label = "Santé Globale", blocs = {
            -- L'Esprit et l'Ame etaient au fond d'« Intangible » : ce sont des
            -- jauges de sante, elles ouvrent la fenetre avec les autres.
            { section = { "general", "existence" } },
            -- Les PV en un seul chiffre, avant le detail par zone : on veut
            -- d'abord savoir ou l'on en est, et ensuite seulement ou ca fait
            -- mal.
            { label = "Points de vie", champs = { { id = "corps", zones = false } } },
            { label = "Parties corporelles", champs = { { id = "corps", total = false } } },
        } },
        -- Ajout a la structure du template : les etats qu'une action a poses
        -- (Immobilise, un buff...), avec leur duree.
        { id = "etats", label = "Physique", blocs = {
            { conteneur = { "etats", "etat" } }, { temporaires = "etat" } } },
        { id = "maladies", label = "Maladies", blocs = {
            { conteneur = { "etats", "maladie" } }, { temporaires = "maladie" } } },
        { id = "intangible", label = "Intangible", blocs = {
            { conteneur = { "etats", "intangible" } },
            { temporaires = "intangible" },
        } },
    },
})

-- Equipements : Armes, Armures, Accessoires (1 / 5 / 5 emplacements).
Vues.Add({
    id = "equipement", titre = "Équipements",
    largeur = 340, hauteur = 450,
    onglets = {
        { id = "arme",       label = "Armes",       blocs = { { conteneur = { "objets", "arme" } } } },
        { id = "equipement", label = "Armures",     blocs = { { conteneur = { "objets", "equipement" } } } },
        { id = "accessoire", label = "Accessoires", blocs = { { conteneur = { "objets", "accessoire" } } } },
        { id = "outil",      label = "Outils",      blocs = { { conteneur = { "objets", "outil" } } } },
    },
})

-- Apprentissage : un conteneur de 60 emplacements.
Vues.Add({
    id = "apprentissage", titre = "Apprentissage",
    largeur = 340, hauteur = 460,
    blocs = { { conteneur = { "apprentissages", "apprentissage" }, label = "Apprentissages" } },
})

-- Capacités : deux familles, chacune avec ses propres domaines.
Vues.Add({
    id = "expertise", titre = "Capacité",
    largeur = 340, hauteur = 460,
    ongletsUneRangee = true,
    groupes = {
        { id = "expertise", label = "Expertise" },
        { id = "mecanique", label = "Mécanique" },
    },
    onglets = {
        { id = "observations", groupe = "expertise", label = "Observations", blocs = { { section = { "expertises", "observations" } } } },
        { id = "athletisme",   groupe = "expertise", label = "Athlétisme",   blocs = { { section = { "expertises", "athletisme" } } } },
        { id = "filouterie",   groupe = "expertise", label = "Filouterie",   blocs = { { section = { "expertises", "filouterie" } } } },
        { id = "competence",   groupe = "mecanique", label = "Compétence",   blocs = { { onglet = "mecaniques" } } },
        { id = "defense",      groupe = "mecanique", label = "Défense",      blocs = { { onglet = "defenses" } } },
    },
})

-- Penetration & Resistances : les resistances d'abord, comme le template.
Vues.Add({
    id = "penetrations_resistances", titre = "Pénétration & Résistances",
    largeur = 340, hauteur = 460,
    onglets = {
        { id = "resistances", label = "Résistances", couleur = { 0.44, 0.78, 0.94 }, blocs = { { onglet = "resistances" } } },
        { id = "penetrations", label = "Pénétrations", couleur = { 1, 0.48, 0.38 }, blocs = { { onglet = "penetrations" } } },
    },
})

-- Statistiques : le recapitulatif du template, un dossier par famille, chaque
-- ligne montrant la valeur TOTALE (race, traits, objets, etats, repartition).
-- « Bonus » ne montre que ce qu'apportent traits et objets.
--
-- En deux volets depuis le 3 octobre 2026 : les familles a gauche, en sommaire
-- (la piece des Regles), la famille choisie seule a droite. Ecart voulu au
-- template, qui empilait dix-huit dossiers replies ou ouverts dans une seule
-- colonne : on y cherchait sa ligne en faisant defiler. Les dossiers ne se
-- replient donc plus — replier la seule chose qu'une page montre ne cacherait
-- que la page.
do
    local E = LCM.Equilibrage
    local function Types(prefixe)
        local out = {}
        for _, t in ipairs(E.types) do out[#out + 1] = prefixe .. t.id end
        return out
    end
    local mecaniques = {}
    for _, m in ipairs(E.mecaniques) do mecaniques[#mecaniques + 1] = "meca_" .. m.id end
    local defenses = {}
    for _, d in ipairs(E.defenses or {}) do
        defenses[#defenses + 1] = LCM.Defenses.Field(d.id)
    end

    -- Une famille du recapitulatif = un chapitre du sommaire. Son libelle est
    -- celui de son bloc (Core/Vues.lua le reprend quand l'onglet n'en donne pas).
    local function Famille(id, bloc)
        bloc.recap = bloc.recap or "total"
        return { id = id, blocs = { bloc } }
    end
    Vues.Add({
        id = "statistiques", titre = "Statistiques",
        -- La page garde la largeur qu'elle avait seule (312) ; le sommaire et
        -- sa barre prennent 173 a gauche.
        largeur = 509, hauteur = 460,
        sommaire = true,
        onglets = {
            Famille("statistiques", { label = "Statistiques",
                champs = { "force", "mystique", "perception", "adresse", "esprit", "constitution" } }),
            Famille("penetrations", { label = "Pénétrations", champs = Types("pen_") }),
            Famille("resistances",  { label = "Résistances",  champs = Types("resi_") }),
            Famille("bonus", { label = "Bonus", recap = "bonus",
                champs = { "pa", "fatigue", "depl_terrestre", "depl_nage", "initiative" } }),
            Famille("observations", { section = { "expertises", "observations" }, label = "Observations" }),
            Famille("athletisme",   { section = { "expertises", "athletisme" },   label = "Athlétismes" }),
            Famille("filouterie",   { section = { "expertises", "filouterie" },   label = "Filouteries" }),
            Famille("mecaniques", { label = "Mécanique de compétence", champs = mecaniques }),
            Famille("defenses", { label = "Mécanique de défense", champs = defenses }),
        },
    })
end
