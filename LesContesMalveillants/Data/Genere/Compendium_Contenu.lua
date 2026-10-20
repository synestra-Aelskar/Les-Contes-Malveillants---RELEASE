-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par Outils/importer_necronicon.py a partir du compendium Necronicon
--  « Systeme d'Aelskar »
--  (sauvegarde AKRX/Necronicon_System_Les_contes_Malveillants_MJ.lua).
--  Toute retouche manuelle sera perdue au prochain import.
--
--  Pour changer une entree : la corriger en jeu (Compendium, mode MJ), puis
--  l'exporter comme un brouillon.
-- ============================================================================

local _, LCM = ...

-- ===== Liste : Type Armures =====
LCM.Listes.Add({
    id = "plastron",
    label = "Plastron",
    liste = "type_armures",
    icone = "Interface\\ICONS\\inv_chest_chain_15",
})
LCM.Listes.Add({
    id = "jambiere",
    label = "Jambière",
    liste = "type_armures",
    icone = "Interface\\ICONS\\inv_misc_desecrated_mailpants",
})
LCM.Listes.Add({
    id = "casque",
    label = "Casque",
    liste = "type_armures",
    icone = "Interface\\ICONS\\inv_helmet_11",
})
LCM.Listes.Add({
    id = "gants",
    label = "Gants",
    liste = "type_armures",
    icone = "Interface\\ICONS\\eps_lol_item_sparringgloves",
})
LCM.Listes.Add({
    id = "bottes",
    label = "Bottes",
    liste = "type_armures",
    icone = "Interface\\ICONS\\inv_boots_05",
})
LCM.Listes.Add({
    id = "plaque_de_corps",
    label = "Plaque de corps",
    liste = "type_armures",
    icone = "Interface\\ICONS\\inv_gizmo_mithrilcasing_02",
    tags = "Plaque de corps",
})
LCM.Listes.Add({
    id = "masque",
    label = "Masque",
    liste = "type_armures",
    icone = "Interface\\ICONS\\eps_arc_halloween_shatteredmask",
    tags = "Masque",
})
LCM.Listes.Add({
    id = "essence_elementaire",
    label = "Essence élémentaire",
    liste = "type_armures",
    icone = "Interface\\ICONS\\inv_enchant_shardglowingsmall",
    tags = "Essence élémentaire",
})

-- ===== Liste : Liste Armes =====
LCM.Listes.Add({
    id = "baton",
    label = "Baton",
    liste = "armes",
    icone = "Interface\\ICONS\\inv_staff_08",
})
LCM.Listes.Add({
    id = "epee",
    label = "Épée",
    liste = "armes",
    icone = "Interface\\ICONS\\inv_sword_05",
})
LCM.Listes.Add({
    id = "poissons",
    label = "Poissons",
    liste = "armes",
    icone = "Interface\\ICONS\\inv_fishing_82_viperfish",
    description = "Du poisson qui peut servir d'ingrédient.",
})

-- ===== Liste : Liste origine =====
LCM.Listes.Add({
    id = "azerothienne",
    label = "Azerothienne",
    liste = "origines",
    icone = "Interface\\ICONS\\inv__faction_championsofazeroth",
    tags = "Azerothienne",
})
LCM.Listes.Add({
    id = "insgardienne",
    label = "Insgardienne",
    liste = "origines",
    icone = "Interface\\ICONS\\70_inscription_vantus_rune_light",
    tags = "Insgardienne",
})
LCM.Listes.Add({
    id = "aelskardien",
    label = "Aelskardien",
    liste = "origines",
    icone = "Interface\\ICONS\\achievement_zone_stormpeaks_03",
    tags = "Aelskardien",
})

-- ===== Liste : Liste ressources =====
LCM.Listes.Add({
    id = "minerais",
    label = "Minerais",
    liste = "ressources",
    icone = "Interface\\ICONS\\inv_ore_adamantium",
})
LCM.Listes.Add({
    id = "lingot",
    label = "Lingot",
    liste = "ressources",
    icone = "Interface\\ICONS\\inv_ingot_bronze",
    description = "Minerai transformé en lingot exploitable par de la forge.",
})
LCM.Listes.Add({
    id = "cuir",
    label = "cuir",
    liste = "ressources",
    icone = "Interface\\ICONS\\inv_skinning_80_coarseleather",
    description = "Un peau de créature.",
    tags = "cuir",
})
LCM.Listes.Add({
    id = "poisson",
    label = "poisson",
    liste = "ressources",
    icone = "Interface\\ICONS\\inv_fishing_82_viperfish",
    description = "C'est du poisson",
    tags = "poisson",
})
LCM.Listes.Add({
    id = "liquide",
    label = "Liquide",
    liste = "ressources",
    icone = "Interface\\ICONS\\eps_lol_item_refillablepotionold",
    tags = "Liquide",
})

-- ===== Information =====
LCM.Informations.Add({
    id = "information",
    label = "Information",
    icone = "Interface\\ICONS\\eps_arc_door_waycrest_double",
    description = "LA GROSSE PORTE. ELLE SEMBLE TENIR.",
})

-- ===== Devises =====
LCM.Devises.Add({
    id = "credits",
    label = "Crédits",
    icone = "Interface\\ICONS\\inv_misc_punchcards_blue",
    description = "Le crédits domien est la monnaie la plus répandue en Aelskar. Donnée purement numérique, contenue dans un cristal d'identité domien. A titre d'équivalence, 1 pièce d'argent vaut, selon le cours de la bourse domienne, entre 14 et 16 crédits domiens.",
    tags = "Crédits",
})
LCM.Devises.Add({
    id = "essence_stelaire",
    label = "Essence stelaire",
    icone = "Interface\\ICONS\\inv_enchant_essenceeternalsmall",
    description = "Essence stelaire, monnaie valienne par excelence.",
})
LCM.Devises.Add({
    id = "temps",
    label = "Temps",
    icone = "Interface\\ICONS\\spell_holy_borrowedtime",
    description = "Probablement la chose la plus importante de votre existence si vous n'êtes pas un éternel.",
})
LCM.Devises.Add({
    id = "ecus",
    label = "Écus",
    icone = "Interface\\ICONS\\eps_plunder_misc_pieceofeight",
    description = "Une monnai somme tout relativement banale.",
})

-- ===== Sacs =====
LCM.Sacs.Add({
    id = "sac_de_gros",
    label = "Sac de gros",
    icone = "Interface\\ICONS\\inv_misc_bag_07",
    pileMax = 1,
    places = 25,
    placesDevise = 0,
    sacMJ = true,
})
LCM.Sacs.Add({
    id = "gros_sac",
    label = "Gros sac",
    icone = "Interface\\ICONS\\inv_misc_bag_30",
    pileMax = 1,
    places = 12,
    placesDevise = 0,
})
LCM.Sacs.Add({
    id = "cristal_d_identite_domien",
    label = "Cristal d'identité Domien",
    icone = "Interface\\ICONS\\inv_misc_qirajicrystal_03",
    pileMax = 1,
    places = 10,
    placesDevise = 0,
})

-- ===== Ressources =====
LCM.Ressources.Add({
    id = "brochet_lunaire",
    label = "Brochet lunaire",
    icone = "Interface\\ICONS\\inv_fishing_f_whiptail2",
    description = "Un brochet capturé en pleine mer.. Il peut probablement servir d'ingrédient.",
    type = "poisson",
    metiers = { "cuisinier", "pecheur" },
})
LCM.Ressources.Add({
    id = "eau",
    label = "Eau",
    icone = "Interface\\ICONS\\inv_misc_volatilewater",
    type = "liquide",
    metiers = { "alchimiste", "cuisinier" },
})

-- ===== Armes =====
LCM.Objets.Add({
    id = "dague_d_assassin_du_culte",
    label = "Dague d'assassin du culte",
    categorie = "arme",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    tags = "Rare",
    couleurTitre = "4D8CFF",
    etat = {
        courant = 20,
        max = 20,
    },
    bonus = {
        meca_perce_armure = 1,
        pen_ombre = 2,
        pen_perforant = 4,
        pen_tranchant = 2,
    },
})
LCM.Objets.Add({
    id = "tenue_d_assassin_du_culte",
    label = "Tenue d'assassin du culte",
    categorie = "equipement",
    icone = "Interface\\ICONS\\inv_cape_leather_raiddruid_q_01",
    tags = "Rare",
    couleurTitre = "4D8CFF",
    etat = {
        courant = 20,
        max = 20,
    },
    bonus = {
        discretion = 1,
        resi_contondant = 2,
        resi_lumiere = 1,
        resi_ombre = 2,
        resi_perforant = 2,
        resi_tranchant = 2,
    },
})
LCM.Objets.Add({
    id = "capuche_d_assassin_du_culte",
    label = "Capuche d'assassin du culte",
    categorie = "equipement",
    icone = "Interface\\ICONS\\eps_wc3h_greyhooditem",
    tags = "Rare",
    couleurTitre = "4D8CFF",
    etat = {
        courant = 20,
        max = 20,
    },
    bonus = {
        deguisement = 1,
        discretion = 1,
        resi_contondant = 2,
        resi_lumiere = 1,
        resi_ombre = 1,
        resi_perforant = 1,
        resi_tranchant = 1,
    },
})
LCM.Objets.Add({
    id = "epee_rouillee",
    label = "Épée rouillée",
    categorie = "arme",
    icone = "Interface\\ICONS\\inv_sword_110",
    tags = "Commun",
    couleurTitre = "FF8CB8",
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        pen_contondant = 1,
        pen_perforant = 3,
        pen_tranchant = 2,
    },
})

-- ===== Armures =====
LCM.Objets.Add({
    id = "nouvelle_entree",
    label = "Nouvelle entree",
    categorie = "equipement",
    bonus = {
        acrobaties = 1,
        adresse = 1,
        constitution = 1,
        cosmique = 1,
        course = 1,
        crochetage = 1,
        deguisement = 1,
        depl_nage = 1,
        depl_terrestre = 1,
        discretion = 1,
        elementaire = 1,
        endurance = 1,
        equilibre = 1,
        escalade = 1,
        escamotage = 1,
        esprit = 1,
        evasion = 1,
        fatigue = 1,
        force = 1,
        initiative = 1,
        investigation = 1,
        mystique = 1,
        nage = 1,
        odorat_gout = 1,
        ouie = 1,
        pa = 1,
        pen_contondant = 1,
        pen_desordre = 1,
        pen_eau = 1,
        pen_esprit = 1,
        pen_feu = 1,
        pen_lumiere = 1,
        pen_mort = 1,
        pen_ombre = 1,
        pen_ordre = 1,
        pen_perforant = 1,
        pen_pourriture = 1,
        pen_terre = 1,
        pen_tranchant = 1,
        pen_vent = 1,
        pen_vie = 1,
        perception = 1,
        pistage = 1,
        prise = 1,
        projection = 1,
        puissance = 1,
        resi_contondant = 1,
        resi_desordre = 1,
        resi_eau = 1,
        resi_esprit = 1,
        resi_feu = 1,
        resi_lumiere = 1,
        resi_mort = 1,
        resi_ombre = 1,
        resi_ordre = 1,
        resi_perforant = 1,
        resi_pourriture = 1,
        resi_terre = 1,
        resi_tranchant = 1,
        resi_vent = 1,
        resi_vie = 1,
        resistance = 1,
        sabotage = 1,
        toucher = 1,
        vol_a_la_tire = 1,
        vue = 1,
    },
})

-- ===== Accessoires =====

-- ===== Races =====
LCM.Races.Add({
    id = "insgardienne",
    label = "Insgardienne",
    morphology = "humanoide",
    icone = "Interface\\ICONS\\eps_lol_leona_sunlight",
    bonus = {
        adresse = 4,
        constitution = 2,
        esprit = 3,
        force = 2,
        mystique = 3,
        perception = 4,
    },
})
LCM.Races.Add({
    id = "projet_htdt_02",
    label = "Projet HTDT-02",
    morphology = "humanoide",
    icone = "Interface\\ICONS\\eps_lol_nilah_jubilantveil",
    bonus = {
        adresse = 3,
        constitution = 2,
        esprit = 4,
        force = 2,
        mystique = 3,
        perception = 4,
    },
})
LCM.Races.Add({
    id = "orc",
    label = "ORC",
    morphology = "humanoide",
    icone = "Interface\\ICONS\\achievement_leader_ thrall",
    description = "Je suis un gros zorc VERT.",
    tags = "Commun",
    couleurTitre = "FF8CB8",
    bonus = {
        adresse = 3,
        constitution = 4,
        esprit = 3,
        force = 4,
        mystique = 1,
        pen_contondant = 3,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 3,
        pen_mort = 3,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 3,
        perception = 2,
        resi_contondant = 4,
        resi_desordre = 2,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 4,
        resi_lumiere = 3,
        resi_mort = 2,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 4,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 4,
        resi_vent = 3,
        resi_vie = 3,
    },
})
LCM.Races.Add({
    id = "aelskardien",
    label = "Aelskardien",
    morphology = "humanoide",
    icone = "Interface\\ICONS\\ability_mage_frostjaw",
    description = "Aeeelskardien.",
    tags = "Commun",
    couleurTitre = "629FFF",
    couleurFond = "080D11",
    bonus = {
        adresse = 3,
        constitution = 5,
        esprit = 3,
        force = 4,
        mystique = 4,
        pen_contondant = 3,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 3,
        pen_mort = 3,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 3,
        perception = 2,
        resi_contondant = 3,
        resi_desordre = 2,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 2,
        resi_mort = 2,
        resi_ombre = 2,
        resi_ordre = 2,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 2,
    },
})

-- ===== Traits =====
LCM.Traits.Add({
    id = "nouvelle_entree",
    label = "Nouvelle entree",
})
LCM.Traits.Add({
    id = "maitre_de_la_discretion",
    label = "Maitre de la discrétion",
    cout = 1,
    icone = "Interface\\ICONS\\ability_rogue_shadowdance",
    couleurTitre = "FF8CB8",
    bonus = {
        discretion = 4,
    },
})
LCM.Traits.Add({
    id = "adepte_de_nocturna",
    label = "Adepte de Nocturna",
    cout = 2,
    icone = "Interface\\ICONS\\dos2_shadow1",
    couleurTitre = "4DE04D",
    bonus = {
        pen_ombre = 4,
        resi_ombre = 4,
    },
})
LCM.Traits.Add({
    id = "assassin_expert",
    label = "Assassin expert",
    cout = 1,
    icone = "Interface\\ICONS\\eps_lol_profileicon_shadowassassin",
    couleurTitre = "FF8CB8",
    bonus = {
        meca_perce_armure = 2,
    },
})
LCM.Traits.Add({
    id = "cycle_construire_et_deconstruire",
    label = "Cycle : Construire et déconstruire.",
    icone = "Interface\\ICONS\\ability_nightfae_soulshape",
    description = "En quête de perfection, il ne suffisait guère à sa créatrice de produire une âme artificielle indiscernable d'une âme naturelle. Dans sa poursuite du progrès, elle dota sa création de la faculté de se façonner elle-même, lui offrant ainsi la plus grande des aventures : celle de passer une vie à expérimenter toutes les vies.\n\nAinsi, Reika, fruit de recherches que nul ne saurait pleinement comprendre, dispose de ce que sa créatrice a sobrement nommé « l'âme mouvante ».\n\nContrepied peu dissimulé à l'âme figée d'une certaine famille, celle-ci offre à la jeune femme une âme en perpétuelle reconstruction, qui se façonne et s'accorde au gré de ses désirs les plus profonds.\n\nReika est un peu différente de celle qu'elle était hier, et de celle qu'elle sera demain. Car après tout, pourquoi se contenter de ce que l'on est aujourd'hui, lorsqu'on peut devenir ce dont on aura besoin demain ?\n\nReika est capable de se recomposer quotidiennement. Chaque jour, elle peut réattribuer jusqu'à 4 points de ses statistiques primaires.\nEn contrepartie, elle subit un malus permanent face à l'Ordre, au Désordre et aux actions de soin.",
    bonus = {
        meca_soin = -2,
        resi_desordre = -2,
        resi_ordre = -2,
    },
})
LCM.Traits.Add({
    id = "machine_elementaire",
    label = "Machine élémentaire",
    cout = 1,
    icone = "Interface\\ICONS\\eps_lol_profileicon_sweetheartxayah",
    description = "Pure produit de la science mêlant éléments et âme, Reika dispose d'une affinité prononcée avec les éléments, imprégnant les éléments aux affres qu'elle produit. Connectée à ceux-ci, son esprit est en mesure d'en repousser les limites ainsi qu'en comprendre plus aisément les mécanismes.",
    couleurTitre = "FF8CB8",
    bonus = {
        pen_eau = 2,
        pen_feu = 2,
        pen_terre = 2,
        pen_vent = 2,
    },
})
LCM.Traits.Add({
    id = "violoniste_de_la_marionnette",
    label = "Violoniste de la marionnette.",
    cout = 1,
    icone = "Interface\\ICONS\\eps_lol_ahri_essencetheft",
    description = "Il ne suffit guère de savoir se façonner soi-même lorsque le monde qui nous entoure persiste à suivre sa propre mélodie. Reika dispose d'une attention particulière; qui, a l'image d'un instrument que l'on accorde, lui offre la mesure des subtilités qui composent l'équilibre d'un individu et d'y apporter quelques ajustements.\n\nUn mouvement, une respiration, une circulation magique ou le moindre déséquilibre deviennent autant d'occasions d'intervenir pour elle. Tantôt pour accompagner ses alliés, renforcer leur facultés ou corriger leur maladresses ; tantôt pour introduire quelques fausses notes chez un adversaire, accentuant ses faiblesses et perturbant ses aptitudes.\n\nCar après tout, il suffit parfois d'un rien pour qu'une mécanique parfaitement huilée se mette à grincer. Et quelle meilleure manière d'en découvrir les rouages que de les dérégler soi-même ?",
    couleurTitre = "FF8CB8",
    bonus = {
        meca_buff = 1,
        meca_debuff = 1,
    },
})
LCM.Traits.Add({
    id = "automate_danseuse",
    label = "Automate danseuse",
    cout = 1,
    icone = "Interface\\ICONS\\eps_lol_item_puppeteerold",
    description = "Au quotidien, Reika se meut avec la grâce d'un automate d'apparat. Ses gestes sont doux, lents et harmonieux, chaque mouvement soigneusement mesuré, comme il sied à une jeune dame de bonne famille.\n\nMais lorsque les circonstances l'exigent, cette délicatesse cède la place à une mécanique autrement plus troublante. Son corps s'articule avec une précision presque inhumaine, enchaînant les mouvements avec la célérité et l'exactitude d'une horloge parfaitement réglée.\n\nAprès tout, sous les apparences d'une poupée de salon se cache une mécanique autrement plus sophistiquée.",
    couleurTitre = "FF8CB8",
    bonus = {
        acrobaties = 1,
        equilibre = 1,
        escalade = 1,
        resistance = 1,
    },
})

-- ===== Etats =====
LCM.Etats.Add({
    id = "infection_de_sang",
    label = "Infection de sang",
    categorie = "etat",
    icone = "Interface\\ICONS\\ability_ironmaidens_corruptedblood",
    bonus = {
        force = -10,
    },
})

-- ===== Maladies =====

-- ===== Apprentissage =====
LCM.Apprentissages.Add({
    id = "etude_de_l_accrotabie_base_volume_1",
    label = "Etude de l'accrotabie : Base Volume 1",
    icone = "Interface\\ICONS\\ability_hunter_animalhandler",
    description = "Vous avez étudié et pratiqué les bases de l'accrobatie Volume 1.",
    bonus = {
        acrobaties = 1,
    },
})

-- ===== Reprises de l'ancien compendium « Aelskar » =====
LCM.Ressources.Add({
    id = "lingo_de_bronze",
    label = "Lingo de Bronze",
    icone = "Interface\\ICONS\\inv_ingot_03",
    type = "lingot",
    metiers = { "forgeron", "mineur" },
    etat = {
        courant = 10,
        max = 10,
    },
})
LCM.Ressources.Add({
    id = "cuivre",
    label = "Cuivre",
    icone = "Interface\\ICONS\\inv_ore_copper_01",
    description = "Un minerai brun-cuivré aux reflets rougeâtres, souvent veiné de teintes plus sombres. Relativement commun, il est apprécié pour sa facilité de fonte et sert principalement à produire des alliages solides destinés aux outils, armes et pièces métalliques.",
    type = "minerais",
    metiers = { "mineur", "forgeron" },
})
LCM.Ressources.Add({
    id = "argent",
    label = "Argent",
    icone = "Interface\\ICONS\\inv_ore_adamantite_nugget",
    description = "Un minerai gris clair aux reflets métalliques très brillants, parfois parcouru de veines sombres. Plus rare que les métaux communs, il est recherché autant pour sa valeur que pour sa conductivité et ses usages en joaillerie, artisanat fin ou préparations ésotériques.",
    type = "minerais",
    metiers = { "mineur", "forgeron" },
})
LCM.Objets.Add({
    id = "baton_magique_en_bois_eraenne",
    label = "Bâton magique en bois éraenne",
    categorie = "arme",
    icone = "Interface\\ICONS\\inv_staff_02",
    description = "Difficile de déterminer ce qu'il en est réellement de cet étrange bâton. Banal, austère, et dépourvue de toute fioriture, c'est un ouvrage à priori médiocre. \n\n\nMais les âmes martiales, les fins connaisseurs des arts étranger, pourraient remarquer que ce bâton semble avoir été façonné sur la base d'une ancien Boken. \n\nSon bois, imprégnée d'une légère aura solaire résiduelle, laisse entendre une seconde nature.. Ou une nature première scellée, liée à sa porteuse, qui ne semble guère vouloir se manifester. \n\nEnfin, ceux dont les sens sont affutés, pourraient déterminer que l'ouvrage, millénaire, suinte l'odeur du sang, du carnage, et de la guerre.",
    etat = {
        courant = 10,
        max = 10,
    },
    bonus = {
        cosmique = 1,
        elementaire = 1,
        esprit = 1,
        fatigue = 2,
        mystique = 1,
        pen_contondant = 2,
        pen_lumiere = 4,
        pen_vie = 4,
    },
})

-- ===== Connaissances =====
LCM.Connaissances.Add({
    id = "fabrication_de_lingot_de_bronze",
    label = "Fabrication de Lingot de bronze",
    icone = "Interface\\ICONS\\inv_ingot_bronze",
    description = "Permet de fondre du cuivre et de l’argent afin d’obtenir un lingot de bronze, utilisable comme matériau de base pour la forge et l’artisanat métallique.",
    metiers = { "mineur", "forgeron" },
    apprenable = true,
    composants = {
        {
            quantite = 1,
            ref = "ressources/cuivre",
        },
        {
            quantite = 1,
            ref = "ressources/argent",
        },
        {
            quantite = 1,
            ref = "necronicon/compendium_window_custom_2__238",
        },
    },
    fabrication = true,
    niveau = "1",
    niveauRequis = "Rose",
    resultat = "ressources/lingo_de_bronze",
    xp = 1,
})
