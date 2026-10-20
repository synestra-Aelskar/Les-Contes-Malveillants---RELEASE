-- Documentation en jeu : regles, aides, tutoriels.
--
-- Ajouter une page = ajouter un bloc ici. C'est aussi ce qui remplace les
-- « feuilles de tutoriel » bricolees dans Necronicon.

local _, LCM = ...
local Documents = LCM.Documents

Documents.Add({
    id = "demarrer",
    label = "Premiers pas",
    ordre = 10,
    blocs = {
        { kind = "titre", texte = "Les Contes Malveillants" },
        { kind = "texte", texte = "Ta fiche se remplit toute seule a partir de ce que tu investis. "
            .. "Les points de vie, la fatigue et l'initiative sont calcules : tu n'as pas a les saisir." },
        { kind = "separateur" },
        { kind = "titre", texte = "Ouvrir les fenetres" },
        { kind = "liste", items = {
            "/lcm fenetres — le menu des fenetres (ou le bouton)",
            "/lcm actions — le lanceur d'actions (le sceau)",
            "/lcm fiche — ta fiche",
            "/lcm aide — cette documentation",
        } },
        { kind = "separateur" },
        { kind = "titre", texte = "La silhouette" },
        { kind = "texte", texte = "Tes points de vie se repartissent sur les parties de ton corps, "
            .. "selon ta morphologie. La molette sur une partie te blesse ou te soigne." },
    },
})

Documents.Add({
    id = "jets",
    label = "Jets et traits",
    ordre = 20,
    blocs = {
        { kind = "titre", texte = "Lancer un de" },
        { kind = "texte", texte = "Chaque expertise se lance avec le bouton Jet. Le resultat additionne "
            .. "le de, ta valeur dans l'expertise, et les bonus de tes traits." },
        { kind = "separateur" },
        { kind = "titre", texte = "L'avantage" },
        { kind = "texte", texte = "Un trait peut t'accorder l'avantage sur certaines expertises. "
            .. "Dans ce cas, une case apparait a cote du bouton Jet : coche-la quand la situation "
            .. "correspond a ton trait. Le de est alors lance deux fois, et l'on garde le meilleur." },
        { kind = "texte", texte = "C'est a toi de juger si ton trait s'applique — l'addon ne le devine pas." },
    },
})
