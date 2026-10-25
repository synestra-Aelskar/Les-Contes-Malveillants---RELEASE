-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Construit depuis la base commune `necronicon/database/entries`.
--  Une archive d'addon est un livrable ; elle n'est jamais la source de verite.
-- ============================================================================

local _, LCM = ...

-- ----- accessoires_camping (1) -------------------------------------
LCM.PublierPublique(LCM.AccessoiresCamping, "accessoires_camping", {
    bonus = {
        recup_armure = 40,
    },
    description = "Les petits outils de Kaléa pour qu'elle répare ses équipements.",
    id = "accessoire_reparation_kalea",
    label = "Accessoire de réparation de Kaléa",
    origine = "Kaléa",
}, "323d4907b00feaef")

-- ----- consommables (5) --------------------------------------------
LCM.PublierPublique(LCM.Consommables, "consommables", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "De l'eau classique que n'importe qui peut boire. C'est juste là.. Pour boire.",
    forge = "lcm_132159_6adb718b_2005bd2b_0004_7abb48/commun",
    icone = "Interface\\ICONS\\pet_type_water",
    id = "lcm_132159_6adb71d4_2006d99d_0005_039df9",
    label = "Eau claire",
    tags = "Commun",
    type = "lcm_64a651_6ad69a7f_205bdff2_0013_e59c87",
}, "c92cb014cb5a9102")

LCM.PublierPublique(LCM.Consommables, "consommables", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Une bande de tissu grossièrement découpée, aux fibres rêches et effilochées. Peu hygiénique, mais suffisante pour couvrir une plaie.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_bandage_03",
    id = "lcm_64a651_6ad691e4_203a41c9_0005_edf1c8",
    label = "Bandage de piètre qualité.",
    tags = "Commun",
    transfertDe = { "ressources/lcm_64a651_6ad691e4_203a41c9_0005_edf1c8" },
    type = "lcm_64a651_6ad6939e_2040ff8f_0007_cd304f",
}, "1376b2161db3f8ef")

LCM.PublierPublique(LCM.Consommables, "consommables", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un maigre assortiment de viande séchée, de biscuits durcis et de quelques fruits secs. De quoi tromper la faim durant une journée.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_paperpackage01b",
    id = "lcm_64a651_6ad693b8_204164db_0008_1cbf44",
    label = "Petite ration de voyage",
    tags = "Commun",
    transfertDe = { "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44" },
    type = "lcm_64a651_6ad6933b_203f7d7a_0006_c0e4d5",
}, "aefc817be0f2cc12")

LCM.PublierPublique(LCM.Consommables, "consommables", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un onguent épais à l'odeur âcre, conservé dans un petit pot de terre cuite. Appliqué sur la peau, il apaise les morsures du froid et soulage les engelures superficielles.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\w3reforgedhealingsalve",
    id = "lcm_64a651_6ad693f0_20423093_0001_2f767b",
    label = "Onguent anti-engelures",
    tags = "Commun",
    transfertDe = { "ressources/lcm_64a651_6ad693f0_20423093_0001_2f767b" },
    type = "lcm_64a651_6ad69431_20433b69_0002_621c6d",
}, "ea028bf1f8f835bb")

LCM.PublierPublique(LCM.Consommables, "consommables", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un cristal d'aspecta rafiné. Allez savoir à quoi cela sert. En revanche, il dégage une lueur verte appaisante.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_uncutgemsuperior2",
    id = "lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
    label = "Cristal d'aspecta rafiné",
    tags = "Commun",
    transfertDe = { "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783" },
    type = "lcm_64a651_6ad6a260_207aa4a3_0021_04ec5d",
}, "5688ca0c261ec1cf")

-- ----- cristaux (3) ------------------------------------------------
LCM.PublierPublique(LCM.Cristaux, "cristaux", {
    consommable = true,
    description = "",
    duree = 60,
    icone = "Interface\\ICONS\\inv_enchanting_80_veiledcrystal",
    id = "lcm_132159_6adaa530_1ce76f00_0002_059867",
    label = "Cristal de Test",
    pileMax = 50,
}, "c8fc15cb1b5092e8")

LCM.PublierPublique(LCM.Cristaux, "cristaux", {
    description = "",
    duree = 660,
    icone = "Interface\\ICONS\\inv_enchanting_80_veiledcrystal",
    id = "lcm_132159_6adb704d_2000e302_0002_8828e1",
    label = "Cristal de TEst 2",
}, "48050852aaf489a8")

LCM.PublierPublique(LCM.Cristaux, "cristaux", {
    description = "",
    duree = 6000,
    icone = "Interface\\ICONS\\inv_enchanting_80_veiledcrystal",
    id = "lcm_132159_6adb706d_20015e68_0003_803248",
    label = "Cristal de test 3",
}, "fd3a30cbf1842c39")

-- ----- devises (1) -------------------------------------------------
LCM.PublierPublique(LCM.Devises, "devises", {
    description = "Une monnai somme tout relativement banale.",
    icone = "Interface\\ICONS\\eps_plunder_misc_pieceofeight",
    id = "ecus",
    label = "Écus",
    materiel = true,
}, "f4e54a717e552624")

-- ----- etats (6) ---------------------------------------------------
LCM.PublierPublique(LCM.Etats, "etats", {
    avantage = {  },
    bonus = {  },
    categorie = "maladie",
    couleurTitre = "FF8CB8",
    desavantage = {  },
    description = "",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/commun",
    icone = "Interface\\ICONS\\ability_ironmaidens_corruptedblood",
    id = "infection_de_sang",
    label = "Infection de sang",
    tags = "Commun",
    type = "lcm_64a651_6adc94a9_0ea39278_0008_86d1d0",
}, "f2effe2cdacb9f86")

LCM.PublierPublique(LCM.Etats, "etats", {
    bonus = {
        acrobaties = -15,
        adresse = -10,
        course = -15,
        def_agilite = -15,
        def_courage = -15,
        def_defense = -15,
        def_esprit_libre = -15,
        def_insensible = -15,
        def_mental = -15,
        def_stable = -15,
        equilibre = -15,
        escalade = -15,
        esprit = -10,
        evasion = -15,
        investigation = -15,
        meca_confusion = -15,
        meca_controle_mental = -15,
        meca_creation = -15,
        meca_dissipation = -15,
        meca_illusion = -15,
        meca_intimidation = -15,
        meca_levitation = -15,
        meca_permutation = -15,
        meca_peur = -15,
        meca_provocation = -15,
        nage = -15,
        perception = -10,
    },
    categorie = "etat",
    couleurTitre = "FF8CB8",
    description = "Vous avez vraiment très mal au crâne.",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/commun",
    icone = "Interface\\ICONS\\inv_misc_bone_humanskull_02",
    id = "lcm_64a651_6acd8c83_0ff8950c_0001_18d910",
    label = "Commossion Cérébrale.",
    pourcent = { "acrobaties", "adresse", "course", "def_agilite", "def_courage", "def_defense", "def_esprit_libre", "def_insensible", "def_mental", "def_stable", "equilibre", "escalade", "esprit", "evasion", "investigation", "meca_confusion", "meca_controle_mental", "meca_creation", "meca_dissipation", "meca_illusion", "meca_intimidation", "meca_levitation", "meca_permutation", "meca_peur", "meca_provocation", "nage", "perception" },
    tags = "Commun",
    type = "lcm_64a651_6adc93f5_0ea0d176_0002_0e8574",
}, "29af5c6046366a1e")

LCM.PublierPublique(LCM.Etats, "etats", {
    avantage = {  },
    bonus = {
        acrobaties = -4,
        adresse = -1,
        constitution = -1,
        course = -4,
        def_defense = -1,
        endurance = -4,
        equilibre = -4,
        escalade = -4,
        esprit = -1,
        force = -1,
        mystique = -1,
        odorat_gout = -4,
        ouie = -4,
        pen_feu = -10,
        perception = -1,
        resi_eau = -10,
        resi_vent = -10,
        resistance = -4,
        toucher = -4,
        vue = -4,
    },
    categorie = "etat",
    couleurTitre = "FF9926",
    desavantage = {  },
    description = "ATTENTION : RISQUE DE MORT. \n\nSi vous ne trouvez pas une source de chaleur rapidement, ou un moyen de contrer ce processus, vous finirez congelé, et probablement M.O.R.T.",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/epique",
    icone = "Interface\\ICONS\\ability_mage_frostjaw",
    id = "lcm_64a651_6ad6b28b_20b9bf23_0001_a315f2",
    label = "Congelation en cours",
    tags = "Épique",
    type = "lcm_64a651_6adc9409_0ea12403_0003_ffc54c",
}, "3bbf5a67ff84e6df")

LCM.PublierPublique(LCM.Etats, "etats", {
    avantage = {  },
    bonus = {
        mystique = -10,
    },
    categorie = "etat",
    couleurTitre = "FF9926",
    desavantage = {  },
    description = "Utiliser toute forme de magie inflige une douleur tétanisante, comme si vos os se craquaient sous un étau. - Et ce n'est pas qu'une impression ! -\nN'empêche pas l'utilisation de la magie, bien que la douleur - ou le risque de mort - dissuade le porteur de s'y risquer.\nPeut entrainer la mort par suffocation, ou par répétition de douleur.",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/epique",
    icone = "Interface\\ICONS\\hd_silence_1",
    id = "lcm_64a651_6ad6b4fc_20c35703_0003_18b5af",
    label = "COLLIER DE SILENCE",
    tags = "Épique",
    type = "lcm_64a651_6adc94b2_0ea3b62b_0009_a682b7",
}, "d685e56640cd3a22")

LCM.PublierPublique(LCM.Etats, "etats", {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
    },
    categorie = "etat",
    couleurTitre = "FF8CB8",
    desavantage = {  },
    description = "Une mélasse verte, nauséabonde, et visqueuse.. qui colle à vos vêtements..",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/commun",
    icone = "Interface\\ICONS\\ability_creature_poison_02",
    id = "lcm_aa9c40_6ad93309_016e48e4_0001_182b4e",
    label = "Mélasse verte",
    tags = "Commun",
    type = "lcm_64a651_6adc93f5_0ea0d176_0002_0e8574",
}, "1a1d29a15a22137a")

LCM.PublierPublique(LCM.Etats, "etats", {
    bonus = {
        acrobaties = -25,
        course = -25,
        depl_nage = -25,
        depl_terrestre = -25,
        equilibre = -25,
        escalade = -25,
        nage = -25,
    },
    categorie = "etat",
    couleurTitre = "FF8CB8",
    description = "Après une mauvaise chute.. une de vos chevilles est semble-t-il foulée.",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/commun",
    icone = "Interface\\ICONS\\dos2_rogue2",
    id = "lcm_aa9c40_6adcc761_0f699f11_0001_ca781b",
    label = "Cheville foulée.",
    pourcent = { "acrobaties", "course", "depl_nage", "depl_terrestre", "equilibre", "escalade", "nage" },
    tags = "Commun",
    type = "lcm_64a651_6adc93f5_0ea0d176_0002_0e8574",
}, "12aabeb45448de5a")

-- ----- lanternes (1) -----------------------------------------------
LCM.PublierPublique(LCM.Lanternes, "lanternes", {
    description = "Une lantere qui sert à faire des test",
    icone = "Interface\\ICONS\\inv_misc_trinket6oih_lanterna2",
    id = "lcm_132159_6adaa616_1ceaef75_0002_d12bd4",
    label = "Lanterne d Test",
    multiplicateur = 1,
}, "7e23f96b80a1b5cd")

-- ----- listes (48) --------------------------------------------------
LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_jewelry_ring_03",
    id = "anneau",
    label = "Anneau",
    liste = "type_accessoires",
    maxEquipe = 4,
    remplacePublie = true,
}, "a7bf7fdfc2fdf84e")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_staff_08",
    id = "baton",
    label = "Baton",
    liste = "armes",
    maxEquipe = 1,
    remplacePublie = true,
}, "bfdf74ac2b403284")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_gem_pearl_03",
    id = "bijou",
    label = "Bijou",
    liste = "type_accessoires",
    maxEquipe = 4,
    remplacePublie = true,
}, "acee6e37125c05a8")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_boots_05",
    id = "bottes",
    label = "Bottes",
    liste = "type_armures",
    maxEquipe = 1,
    remplacePublie = true,
}, "a5bef02da3f11b28")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_bracer_07",
    id = "bracelet",
    label = "Bracelet",
    liste = "type_accessoires",
    maxEquipe = 2,
}, "5a8fae93c5d99c23")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_misc_cape_11",
    id = "cape",
    label = "Cape",
    liste = "type_accessoires",
    maxEquipe = 1,
}, "398251e4dde9ca2a")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_helmet_11",
    id = "casque",
    label = "Casque",
    liste = "type_armures",
    maxEquipe = 1,
    remplacePublie = true,
}, "7c60014ef5b65607")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_belt_15",
    id = "ceinture",
    label = "Ceinture",
    liste = "type_accessoires",
    maxEquipe = 1,
}, "033989e5b2763198")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_sword_05",
    id = "epee",
    label = "Épée",
    liste = "armes",
    maxEquipe = 2,
    remplacePublie = true,
}, "a362ec60d82fb264")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\eps_lol_item_sparringgloves",
    id = "gants",
    label = "Gants",
    liste = "type_armures",
    maxEquipe = 1,
    remplacePublie = true,
}, "6393945e645894c7")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_desecrated_mailpants",
    id = "jambiere",
    label = "Jambière",
    liste = "type_armures",
    maxEquipe = 1,
    remplacePublie = true,
}, "92383a462d5307a7")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "Des outils qui servent en tant que pioche afin de pouvoir récupérer des trucs. Ou en ouvrir d'autre.",
    icone = "Interface\\ICONS\\inv_axe_1h_6dr_pickaxe_a_01",
    id = "lcm_132159_6ad3adf6_01b19bc9_0002_567205",
    label = "Pioche",
    liste = "outils",
    maxEquipe = 5,
}, "d089cdd5c989701b")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_helmet_121",
    id = "lcm_132159_6ad7981d_10fc569c_0007_a14edd",
    label = "Masque",
    liste = "type_accessoires",
}, "109a725d77b6d9c4")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_sword_19",
    id = "lcm_64a651_6acd5c7c_0f3d04b6_0002_62d5d3",
    label = "Épée deux mains",
    liste = "armes",
    maxEquipe = 1,
}, "109a7abdb1999a3c")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\eps_wc3h_woodenbow",
    id = "lcm_64a651_6acd5c99_0f3d75d2_0003_0cffbf",
    label = "Arc",
    liste = "armes",
    maxEquipe = 1,
}, "739df86cc03e6283")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\eps_wc3_dagger",
    id = "lcm_64a651_6acd5caa_0f3db97f_0004_0e6737",
    label = "Dague",
    liste = "armes",
    maxEquipe = 2,
}, "4c4086668cbe5f7c")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\8xp_vulperaflute",
    id = "lcm_64a651_6acd5cbe_0f3e05e9_0005_ba6ba7",
    label = "Instrument",
    liste = "armes",
    maxEquipe = 2,
}, "b5a8f389d66ec2c1")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_sword_1h_panstart_a_01",
    id = "lcm_64a651_6acd5d01_0f3f0ba2_0009_3efd73",
    label = "Katana",
    liste = "armes",
    maxEquipe = 2,
}, "6ef4f54f260e34ce")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_sword_1h_broker_c_01",
    id = "lcm_64a651_6acd5d14_0f3f576d_000a_ba8a1c",
    label = "Nodashi",
    liste = "armes",
    maxEquipe = 1,
    remplacePublie = true,
}, "64e8d6e9866d555a")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_polearm_2h_maw_c_01",
    id = "lcm_64a651_6acd5d29_0f3fa8ea_000b_0d4e18",
    label = "Hallebarde",
    liste = "armes",
    maxEquipe = 1,
    remplacePublie = true,
}, "6a328beb2dd2407a")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\eps_wc3h_runedshield",
    id = "lcm_64a651_6acd5da2_0f417f8c_000d_4f2944",
    label = "Bouclier",
    liste = "armes",
    maxEquipe = 2,
}, "2b017459462025f0")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "Sert principalement à ouvrir des serrures, des verroues etc.",
    icone = "Interface\\ICONS\\inv_misc_1h_jewelcraftingtool_a_03",
    id = "lcm_64a651_6ad257b0_0fb70286_0002_90a6d4",
    label = "Crochetage",
    liste = "outils",
    maxEquipe = 10,
}, "87dac0ca65d0f980")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "Une petite pierre runique.. allez savoir à quoi cela sert. ",
    icone = "Interface\\ICONS\\inv_misc_rune_04",
    id = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
    label = "Pierre runique",
    liste = "ressources",
}, "4e8d26c4d66a6ea3")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_inscription_inkblack02",
    id = "lcm_64a651_6ad69189_2038de7c_0003_65dfb5",
    label = "Encre",
    liste = "ressources",
}, "81e7441cb50b197f")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_paperbundle02a",
    id = "lcm_64a651_6ad691c0_2039b590_0004_033a49",
    label = "Papier",
    liste = "ressources",
}, "54a08c38e3b13f68")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_food_159_fish_82",
    id = "lcm_64a651_6ad6933b_203f7d7a_0006_c0e4d5",
    label = "Nourriture",
    liste = "consommables",
}, "443fa37cbeaa3412")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_bandage_01",
    id = "lcm_64a651_6ad6939e_2040ff8f_0007_cd304f",
    label = "Bandage",
    liste = "consommables",
}, "770b0c9b42ecf577")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\w3reforgedbronzebowlfull",
    id = "lcm_64a651_6ad69431_20433b69_0002_621c6d",
    label = "Baume",
    liste = "consommables",
}, "017b4f2a03a6beaf")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\eps_arc_book_blacksmith1",
    id = "lcm_64a651_6ad6963b_204b33a4_0007_f08a79",
    label = "Livre",
    liste = "ressources",
}, "1bdce2be424c9676")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\hots_thebutcher_furnaceblast_fire",
    id = "lcm_64a651_6ad698cf_205548ef_000f_056abe",
    label = "Chaleur",
    liste = "outils",
}, "9aa4c43cc0f2fd48")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_drink_07",
    id = "lcm_64a651_6ad69a7f_205bdff2_0013_e59c87",
    label = "Boisson",
    liste = "consommables",
}, "9993da4c5c410f29")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\eps_rumble_powercrystalgreen",
    id = "lcm_64a651_6ad6a260_207aa4a3_0021_04ec5d",
    label = "Cristal",
    liste = "consommables",
}, "e5e6c5c145699382")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_azsharacoin",
    id = "lcm_64a651_6ad6b267_20b93f97_0009_924d4c",
    label = "Pièce",
    liste = "ressources",
}, "3df0e1823c5fd4c0")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_hammer_15",
    id = "lcm_64a651_6adb7b60_0a58d5af_0006_a624f1",
    label = "Marteaux à deux mains",
    liste = "armes",
    maxEquipe = "1",
}, "277c2fc19c6b5da8")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "etat",
    description = "",
    id = "lcm_64a651_6adc93f5_0ea0d176_0002_0e8574",
    label = "Altérations physiques",
    liste = "type_etats",
}, "c1816ac1381795a9")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "etat",
    description = "",
    id = "lcm_64a651_6adc9409_0ea12403_0003_ffc54c",
    label = "Altérations élémentaires",
    liste = "type_etats",
}, "9fbf2c71061350eb")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "maladie",
    description = "",
    id = "lcm_64a651_6adc941d_0ea17036_0004_2aa645",
    label = "Altérations mentales",
    liste = "type_etats",
}, "57add735f05ecd6a")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "intangible",
    description = "",
    id = "lcm_64a651_6adc942b_0ea1a7ce_0005_2556b5",
    label = "Altérations magiques",
    liste = "type_etats",
}, "eaba6b00e0cb6cd6")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "etat",
    description = "",
    id = "lcm_64a651_6adc9436_0ea1d18e_0006_2c7892",
    label = "Altérations de mobilité",
    liste = "type_etats",
}, "5a4aa7aa803bd106")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "etat",
    description = "",
    id = "lcm_64a651_6adc943e_0ea1efdf_0007_597516",
    label = "États incapacitants",
    liste = "type_etats",
}, "0e0f63d7d40459b8")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "maladie",
    description = "",
    id = "lcm_64a651_6adc94a9_0ea39278_0008_86d1d0",
    label = "Maladie",
    liste = "type_etats",
}, "c5606c4d2c6feffc")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "etat",
    description = "",
    id = "lcm_64a651_6adc94b2_0ea3b62b_0009_a682b7",
    label = "Objet maudit",
    liste = "type_etats",
}, "498836a93f384f90")

LCM.PublierPublique(LCM.Listes, "listes", {
    conteneur = "intangible",
    description = "",
    id = "lcm_64a651_6adc94bc_0ea3dc90_000a_aabd5f",
    label = "Malédictions",
    liste = "type_etats",
}, "c91a1ab62cb1388e")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\eps_arc_halloween_shatteredmask",
    id = "masque",
    label = "Masque",
    liste = "type_armures",
    maxEquipe = 1,
    remplacePublie = true,
    tags = "Masque",
}, "6356ca4b9ad3ae87")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_jewelry_necklace_07",
    id = "pendentif",
    label = "Pendentif",
    liste = "type_accessoires",
    maxEquipe = 4,
    remplacePublie = true,
}, "eff1d493af2d058e")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_gizmo_mithrilcasing_02",
    id = "plaque_de_corps",
    label = "Plaque de corps",
    liste = "type_armures",
    maxEquipe = 5,
    remplacePublie = true,
    tags = "Plaque de corps",
}, "9c10b98bd6a03a44")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_chest_chain_15",
    id = "plastron",
    label = "Plastron",
    liste = "type_armures",
    maxEquipe = 1,
}, "a95d34eb7ff4a99f")

LCM.PublierPublique(LCM.Listes, "listes", {
    description = "",
    icone = "Interface\\ICONS\\inv_misc_idol_03",
    id = "talisman",
    label = "Talisman",
    liste = "type_accessoires",
    maxEquipe = 4,
    remplacePublie = true,
}, "cb994e63522e63f6")

-- ----- livres (1) --------------------------------------------------
LCM.PublierPublique(LCM.Livres, "livres", {
    couverture = {
        texte = "",
        titre = "",
    },
    description = "",
    dos = {
        texte = "",
        titre = "",
    },
    format = "livre",
    icone = "Interface\\ICONS\\eps_bg3_itemkethericbook",
    id = "lcm_64a651_6ad4cd18_19518f43_0002_ea9d76",
    label = "Ouvrage humide.",
    modele = "necronicon",
    pages = {
        {
            texte = "[Une large partie de l'ouvrage est vétuste.. rongé par l'humidité, et le temps.. Entre deux pages.. Vous trouvez éventuellement quelques insectes..]\n\nCette page semble contenir des annotations ressemblant à des cercles runiques.. Hélas, l'encre n'a guère survécu à l'humidité des lieux....\n\n{img:Interface\\Garrison\\ShadowlandsMissionLandingPageBackgroundNightFae:256:256:c}\n\n\n\n\n",
            titre = "",
        },
        {
            texte = "",
            titre = "",
        },
        {
            texte = "ad",
            titre = "ad",
        },
        {
            texte = "test",
            titre = "da",
        },
    },
    pileMax = 1,
    style = {
        accent = "C5A265",
        alignement = "LEFT",
        encre = "E9DDBF",
        fond = "202735",
    },
}, "a7dd3cbf83d6a376")

-- ----- objets (56) --------------------------------------------------
LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        depl_nage = -1,
        depl_terrestre = -1,
        force_brise_armure = 2,
        mystique_brise_armure = 2,
        pen_contondant = 2,
        pen_perforant = 10,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    description = "C'est un arc de bonne facture, souple et résistant. Il apparaît que la barde n'a jamais eu besoin de plus.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\eps_wc3h_woodenbow",
    id = "arc_court",
    label = "Arc court",
    remplacePublie = true,
    tags = "Commun",
    taille = 1,
    type = "lcm_64a651_6acd5c99_0f3d75d2_0003_0cffbf",
}, "060196a6e0ffe8e1")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        depl_nage = -1,
        depl_terrestre = -1,
        meca_buff = 1,
        meca_debuff = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une bannière dont le drapé change au gré des volontés de celui qui la porte, une fois planté dans le sol, elle peut diffuser divers effet bénéfique pour les alliés de son utilisateur ou néfaste pour ses ennemis.\n\nUne bannière qui peut prendre plusieurs forme, soit augmentant les capacités des alliés ou en causant des troubles pour les ennemis. \nSi la bannière est détruite, Caedicia souffre d'un malus temporaire particulièrement lourd.",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_banner_tolbarad_alliance",
    id = "banniere_de_toute_les_gloires",
    label = "Bannière de toute les gloires",
    tags = "Commun",
}, "e96b41cd686b7d2e")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {  },
    categorie = "equipement",
    couleurTitre = "FF8CB8",
    description = "Armure du pauvre.",
    etat = {
        courant = 18,
        max = 18,
    },
    forge = "equilibrage_arme_copie/commun",
    icone = "Interface\\ICONS\\inv_chest_chain_12",
    id = "bridandine_de_pauvre",
    label = "Bridandine de pauvre",
    remplacePublie = true,
    tags = "Commun",
    type = "plastron",
}, "11dedebd835f17c5")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        investigation = 2,
        pistage = 3,
    },
    categorie = "accessoire",
    couleurTitre = "4DE04D",
    description = "Un étrange compas qui semble mettre en évidence les traces de pas laissée au sol.",
    forge = "equilibrage_armure_copie/inhabituel",
    icone = "Interface\\ICONS\\eps_arc_xtracompass",
    id = "compas_du_traqueur",
    label = "Compas du Traqueur",
    tags = "Inhabituel",
}, "b13fa14986bf9ddd")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        force_brise_armure = 2,
        mystique_brise_armure = 2,
        pen_contondant = 1,
        pen_perforant = 2,
        pen_tranchant = 1,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    description = "Un simple couteau permettant de récupérer la peau d'un animal mort.\nPermet d'obtenir la peau d'un animal mort sous forme d'item vendable ou de composant.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\trade_archaeology_silverdagger",
    id = "couteau_a_depecer",
    label = "Couteau à dépecer",
    remplacePublie = true,
    tags = "Commun",
    taille = 1,
    type = "lcm_64a651_6acd5caa_0f3db97f_0004_0e6737",
}, "1736f06aee399618")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        depl_nage = -1,
        depl_terrestre = -1,
        puissance = 1,
        resi_contondant = 6,
        resi_perforant = 5,
        resi_tranchant = 5,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Une armure composée d'un, alliage léger sans doute fait de mithril permet à son porteur de rester mobile. Néanmoins l'armure  porte des enchantements qui décuple la force du porteur, lui permettant de supporter un tel fardeau.\n\nArmure Lourde mais considérée comme une armure de catégorie plus légère au niveau du poids.",
    etat = {
        courant = 30,
        max = 30,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_chest_leather_11",
    id = "ensemble_harnois_blanc",
    label = "Harnois blanc",
    remplacePublie = true,
    tags = "Rare",
    type = "plastron",
}, "ed28b5747ee05fa7")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        force_brise_armure = 2,
        meca_brise_armure = 1,
        mystique_brise_armure = 2,
        pen_contondant = 2,
        pen_perforant = 2,
        pen_tranchant = 4,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Une hallebarde forgée en thorium et pourvue de nombreux enchantement, l'arme est particulièrement lourde du fait de l'alliage qui la compose. Un utilisateur habile peut ouvrir des armures et tenir tête à une foule d'ennemis. On raconte même qu'elle permet à son utilisateur de briser le sol.\n\nEn puissant dans la magie de l'arme, l'utilisateur peut fracasser le sol sous les pieds de ses adversaires pour les faire tomber à la renverse.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_polearm_2h_maw_c_01",
    id = "hallebarde_du_briseur_de_ligne",
    label = "Hallebarde du briseur de ligne",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 2,
    type = "lcm_64a651_6acd5d29_0f3fa8ea_000b_0d4e18",
}, "d5da3ce1e70288c6")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        acrobaties = -2,
        depl_nage = -1,
        depl_terrestre = -1,
        equilibre = -2,
        escalade = -2,
        force_brise_armure = 2,
        initiative = -1,
        meca_intervention = 1,
        mystique_brise_armure = 2,
        pen_contondant = 2,
        perception_brise_armure = 2,
        resi_contondant = 3,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "le pavois est intégralement composé de métal le rendant particulièrement lourd. Porte des enchantements qui décuple la force du porteur, lui permettant de supporter un tel fardeau.\nLe pavois donne un instinct de protectecteur.",
    etat = {
        courant = 30,
        max = 30,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_shield_1h_kultirasquest_b_01",
    id = "harnois_blanc",
    label = "Pavois du gardien",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
    type = "lcm_64a651_6acd5da2_0f417f8c_000d_4f2944",
}, "a4333e8e97295078")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        force_brise_armure = 2,
        mystique_brise_armure = 2,
        pen_contondant = 4,
        pen_perforant = 8,
        pen_tranchant = 12,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Un sabre qui coupe.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_sword_10",
    id = "katana",
    label = "Katana",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
    type = "lcm_64a651_6acd5d01_0f3f0ba2_0009_3efd73",
}, "31894f4393f9fe82")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        depl_nage = -1,
        equilibre = -1,
        escalade = -1,
        force_brise_armure = 2,
        mystique_brise_armure = 2,
        pen_contondant = 2,
        pen_perforant = 4,
        pen_tranchant = 6,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\inv_sword_110",
    id = "lame_rouillee",
    label = "Lame rouillée",
    remplacePublie = true,
    tags = "Commun",
    taille = 1,
    type = "epee",
}, "eac2dd16c92b643c")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        meca_debuff = "1",
        meca_soin = "1",
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Un masque entièrement façonné en os, couvert de runes gravées dans une langue inconnue. Deux cornes ornées de petites clochettes prolongent sa silhouette. Rien ne semble le distinguer d'un simple masque, si ce n'est une légère odeur de cadavre en décomposition.",
    etat = {
        courant = "40",
        max = "40",
        version = "2",
    },
    forge = "equilibrage_armure_copie/commun",
    ic = {
        convertis = 0,
        palier = "rose",
        proprietes = {  },
        version = 1,
    },
    icone = "Interface\\ICONS\\eps_lol_profileicon_wolfsmask",
    id = "lcm_132159_6ad79747_10f91382_0006_96fa11",
    label = "Blud'Sh'Idah Vek",
    tags = "Commun",
}, "40e2b21d19a433ca")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        force_brise_armure = 2,
        mystique_brise_armure = 2,
        pen_contondant = 4,
        pen_ombre = 12,
        pen_perforant = 12,
        pen_tranchant = 12,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    description = "Une lame sombre, courte, imbibée d'ombre. Toucher cette arme sans être liée à son maitre s'accompagne d'une douleur oblitérante.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    id = "lcm_64a651_6ac7bbe9_36c708be_0001_efdd32",
    label = "Dague du culte de l'assassin",
    remplacePublie = true,
    tags = "Rare",
    taille = 1,
    type = "lcm_64a651_6acd5caa_0f3db97f_0004_0e6737",
}, "d6a890a14dbf61ff")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        discretion = 1,
        resi_contondant = 6,
        resi_feu = 7,
        resi_lumiere = -2,
        resi_perforant = 6,
        resi_tranchant = 6,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Une tenue sombre et délicate, qui semble clairement imbibée d'un manteau d'ombre.",
    etat = {
        courant = 18,
        max = 18,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_leather_raidrogue_p_01chest",
    id = "lcm_64a651_6ac7be10_36cf7992_0004_fb40af",
    label = "Tenue d'assassin du culte.",
    remplacePublie = true,
    tags = "Rare",
    type = "plastron",
}, "954f2afd2914c608")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        discretion = 2,
        resi_contondant = 4,
        resi_feu = 5,
        resi_lumiere = -2,
        resi_perforant = 4,
        resi_tranchant = 4,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "..Nimbée d'ombre.",
    etat = {
        courant = 18,
        max = 18,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_leather_warfrontshorde_d_01_pants",
    id = "lcm_64a651_6ac7be6a_36d0dc15_0005_7dbd88",
    label = "Soutane des ombres",
    remplacePublie = true,
    tags = "Rare",
    type = "jambiere",
}, "501c6073ddbfd10c")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        course = 1,
        discretion = 2,
        resi_contondant = 4,
        resi_feu = 2,
        resi_lumiere = -2,
        resi_perforant = 3,
        resi_tranchant = 4,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Nimbée d'ombre..",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_boots_leather_cataclysm_b_02",
    id = "lcm_64a651_6ac7beb5_36d1fee9_0006_6b2588",
    label = "Bottes des ombres",
    remplacePublie = true,
    tags = "Rare",
    type = "bottes",
}, "499eab06ad128f0b")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        discretion = 2,
        pen_ombre = 3,
        resi_contondant = 4,
        resi_feu = 3,
        resi_lumiere = -2,
        resi_perforant = 4,
        resi_tranchant = 4,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Nimbée d'ombre.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_glove_leather_zuldazarraid_d_01",
    id = "lcm_64a651_6ac7beea_36d2cf27_0007_8cf26e",
    label = "Gants du cultiste des ombres",
    remplacePublie = true,
    tags = "Rare",
    type = "gants",
}, "bc5f6f4c1ce0faaa")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        discretion = 2,
        resi_contondant = 4,
        resi_feu = 2,
        resi_perforant = 3,
        resi_tranchant = 3,
        vue = 1,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Nimbée d'ombre.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_leather_zuldazarraid_d_01",
    id = "lcm_64a651_6ac7bf11_36d36743_0008_d09027",
    label = "Voile du corbeau",
    remplacePublie = true,
    tags = "Rare",
    type = "casque",
}, "9028527a7f794bdd")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        crochetage = 2,
        discretion = 3,
        evasion = 2,
        sabotage = 2,
        vol_a_la_tire = 1,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Parfait pour stocker des lames.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\inv_cloth_mawraid_d_01_belt",
    id = "lcm_64a651_6ac7bf81_36d51ea2_0010_f1c74a",
    label = "Baudrier de l'assassin.",
    remplacePublie = true,
    tags = "Rare",
}, "86ea55112bfb41aa")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        discretion = 2,
        meca_perce_armure = 2,
        pen_ombre = 6,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Une paire de bracelet qui semble augmenter la puissance des ombres ainsi que les facultés d'assassins de son porteur.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\dos2_shadow12",
    id = "lcm_64a651_6ac7bfb7_36d5f1de_0011_981ba7",
    label = "Bracelets du cisaire de Nocturna",
    remplacePublie = true,
    tags = "Rare",
}, "dc08e431d7986513")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        force_brise_armure = 2,
        mystique_brise_armure = 2,
        pen_contondant = 4,
        pen_ombre = 12,
        pen_perforant = 12,
        pen_tranchant = 12,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    description = "Une lame sombre, courte, imbibée d'ombre. Toucher cette arme sans être liée à son maitre s'accompagne d'une douleur oblitérante.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    id = "lcm_64a651_6ac7c627_36ef1069_0002_7464d5",
    label = "Seconde Dague du culte de l'assassin",
    remplacePublie = true,
    tags = "Rare",
    taille = 1,
    type = "lcm_64a651_6acd5caa_0f3db97f_0004_0e6737",
}, "20f7010de10aefb1")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        acrobaties = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une robe simple et élégante, tissée dans une soie noble. Elle semble imprégnée de l'âme d'un millier de représentation d'accrobaties.",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_chest_cloth_pvpmagegladiator_o_01",
    id = "lcm_64a651_6ac7c7c7_36f56009_0001_a1f814",
    label = "Robe de l'automate.",
    tags = "Commun",
}, "393a2d9529bcc554")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        force_brise_armure = 2,
        meca_brise_armure = 1,
        mystique_brise_armure = 2,
        pen_contondant = 8,
        pen_perforant = 6,
        pen_tranchant = 14,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Une lame inabituellement grande, qui semble capable de vendre un cheval en deux.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_sword_1h_draenorraid_d_03blue",
    id = "lcm_64a651_6ac8a2eb_3a4d5de1_0001_5e0efb",
    label = "Déchireuse de l'automate.",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 2,
    type = "lcm_64a651_6acd5c7c_0f3d04b6_0002_62d5d3",
}, "d743ca2e64cb1c54")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        pen_ombre = 3,
        resi_lumiere = 4,
        resi_ombre = 4,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Une marque gravée par les ombres, prouvant dans la chair et l'âme, que le cultiste est dévoué à nocturna. Lorsqu'il meurt, Nocturna emporte son corps dans un brasier de flamme noire.",
    etat = {
        courant = 2,
        max = 2,
    },
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\d3_markedfordeath",
    id = "lcm_64a651_6acb7e3f_07f0f686_000e_eee119",
    label = "Marque du culte de rang 8",
    tags = "Rare",
}, "b75638111fca2cd1")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        def_defense = 1,
        resi_contondant = 6,
        resi_perforant = 6,
        resi_tranchant = 6,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Une armure imposante, dans un acier sinistre.",
    etat = {
        courant = 24,
        max = 24,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_chest_chain_12",
    id = "lcm_64a651_6aced371_01fa872b_0008_2528da",
    label = "Armure de géolier du culte pour nhin.",
    tags = "Rare",
    type = "plastron",
}, "5b81a19e1d52b8a6")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        def_defense = 1,
        def_mental = 1,
        resi_contondant = 2,
        resi_feu = 2,
        resi_lumiere = 8,
        resi_perforant = 2,
        resi_tranchant = 2,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Des renforts de metal pour une armure de géolier nhin. Elles semblent enchantée.",
    etat = {
        courant = 18,
        max = 18,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_armor_bastioncosmetic_d_01",
    id = "lcm_64a651_6aced3c9_01fbe20c_000b_ffef6c",
    label = "Renfort de géolier du culte pour nhin.",
    tags = "Rare",
    type = "plaque_de_corps",
}, "3c3d7f8853e064af")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        force_brise_armure = 2,
        meca_attaque_simple = 3,
        mystique_brise_armure = 2,
        pen_contondant = 20,
        pen_perforant = 5,
        pen_tranchant = 35,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\inv_axe_1h_draenorcrafted_d_01_c_alliance",
    id = "lcm_64a651_6aced4fa_02008acc_0023_de2ead",
    label = "Grosse hache d'enculeur de prisonnier. (Modele tabasse fort.)",
    tags = "Rare",
    taille = 2,
    type = "jambiere",
}, "ca8c28f25ae7d36b")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        def_courage = 3,
        def_insensible = 3,
        def_mental = 3,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Pulse une petite aura de feu corrompue..",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\inv_misc_cat_trinket01",
    id = "lcm_64a651_6aced581_02029a27_0024_0779ae",
    label = "Vestige d'un autre monde.",
    tags = "Rare",
    type = "jambiere",
}, "caa6286a32f3d159")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        force_brise_armure = 2,
        meca_buff = 1,
        meca_soin = 1,
        mystique_brise_armure = 2,
        pen_contondant = 6,
        pen_terre = 10,
        pen_vie = 16,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Ce bâton, réalisé à partir du bois de la forêt d'Elestria, a pour principale fonction d'aider un randonneur à se déplacer sous ces frondaisons. Il est orné de l'emblème de la Garde et permet à son porteur de se défendre en cas de problème.\n\nArme à deux mains, au corps à corps.",
    etat = {
        courant = 18,
        max = 18,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_staff_17",
    id = "lcm_64a651_6acff035_0652ddbe_0007_085fa2",
    label = "Bâton forestier",
    tags = "Inhabituel",
    taille = 2,
    type = "baton",
}, "54f723c6cf9c1d4e")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        crochetage = 2,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Un assortiment de tiges métalliques grossièrement façonnées, aux extrémités tordues et limées. Fragiles et peu précises, elles permettent néanmoins de forcer les serrures les plus rudimentaires.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_misc_1h_jewelcraftingtool_a_05",
    id = "lcm_64a651_6ad0c1d8_0985bdbc_0003_781391",
    label = "Outils  de crochetage rudimentaire.",
    remplacePublie = true,
    tags = "Commun",
}, "99e944a88e3ebbd0")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        pen_perforant = 2,
        pen_tranchant = 2,
    },
    categorie = "equipement",
    couleurTitre = "FF8CB8",
    description = "Un pantalon assez épais troué, dnas un état plus que discutable. Vous protégera. Ou pas.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme_copie/commun",
    icone = "Interface\\ICONS\\inv_pants_cloth_pvpmage_f_01",
    id = "lcm_64a651_6ad0c218_0986b5ca_0004_79e46a",
    label = "Pantalon miteux.",
    tags = "Commun",
}, "935aa2c39651a354")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        resi_contondant = 2,
        resi_perforant = 1,
        resi_tranchant = 1,
    },
    categorie = "equipement",
    couleurTitre = "FF8CB8",
    description = "..Elles ont connue des jours meilleurs.. Je crois que vous sentez même qu'un de vos petons touche directement le sol.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/commun",
    icone = "Interface\\ICONS\\inv_boots_07",
    id = "lcm_64a651_6ad10a50_0aa0cd22_0003_a57e3e",
    label = "Bottes moisie",
    tags = "Commun",
    type = "bottes",
}, "538827a80ae829cb")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        crochetage = "2",
    },
    categorie = "outil",
    couleurTitre = "FF8CB8",
    description = "Ce ne sont clairement pas les meilleurs outils que vous aurez dans vos mains.. mais au moins, cela vous permettra de tenter votre chance.",
    etat = {
        courant = "40",
        max = "40",
        version = "2",
    },
    forge = "lcm_64a651_6ad64dd2_1f305b72_0007_10d35a/commun",
    ic = {
        convertis = 0,
        palier = "rose",
        proprietes = {  },
        version = 1,
    },
    icone = "Interface\\ICONS\\inv_misc_1h_jewelcraftingtool_a_05",
    id = "lcm_64a651_6ad64b7b_1f2726d6_0001_9b532f",
    label = "Neccessaire de crochetage rudimentaire.",
    tags = "Commun",
    type = "lcm_64a651_6ad257b0_0fb70286_0002_90a6d4",
}, "df5798ecb5dbe577")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        escalade = 2,
        resi_contondant = 1,
        resi_eau = 2,
        resi_lumiere = -2,
        resi_perforant = 2,
        resi_tranchant = 2,
        resi_vent = 2,
    },
    categorie = "equipement",
    couleurTitre = "4DE04D",
    description = "Cette paire de gant rudimentaire semble équipée de crochets, facilitant la prise sur les paroies.",
    etat = {
        ancienMax = 14,
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "equilibrage_arme_copie/inhabituel",
    icone = "Interface\\ICONS\\inv_hand_1h_artifactstormfist_d_01",
    id = "lcm_64a651_6ad64e8d_1f333644_0002_031f9a",
    label = "Gants du dompteur de paroie.",
    tags = "Inhabituel",
    type = "gants",
}, "4fc2757fa9fec101")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        mystique = -1,
        pen_feu = 3,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une paire de bracelet dont l'intérieur en cuir usé semble avoir été doté de runes rouges.. Son porteur semble en mesure de générer de petites flammes de ses mains.",
    etat = {
        courant = 28,
        max = 28,
        version = 2,
    },
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_plate_draenorlfr_c_01wrist",
    id = "lcm_64a651_6ad655bc_1f4f3bea_0001_191e68",
    label = "Paire de bracelet runique usé.",
    tags = "Commun",
    type = "bracelet",
}, "a4f74ff66d692145")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        pen_perforant = 2,
    },
    categorie = "outil",
    couleurTitre = "FF8CB8",
    description = "Une pioche bon marché. A priori.",
    etat = {
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "lcm_64a651_6ad4ab02_18cc6d43_0002_bbe6a7/commun",
    icone = "Interface\\ICONS\\inv_axe_1h_6miningpick",
    id = "lcm_64a651_6ad65717_1f548f99_0004_7f5032",
    label = "Pioche en acier",
    tags = "Commun",
    type = "lcm_132159_6ad3adf6_01b19bc9_0002_567205",
}, "e3bed0dbefe2e7b6")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        resi_mort = 6,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Cette lanterne à l'ouvrage délicat renferme un cristal de petite taille, dont la lente combustion dispense une douce lueur.\n\nSa monture métallique est parcourue d'antiques runes entrelacées, semblables à de fines toiles d'araignée. Trois jauges, graduées, se trouvent à sa base. Une petite trappe permet d'ouvrir le coté, et d'accéder à l'intérieur pour y placer un cristal. \n\nEnfin, l'objet porte avec lui le poids des siècles, et conserve pourtant sa solidité.",
    etat = {
        courant = 88,
        max = 88,
        version = 2,
    },
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\inv_misc_trinket6oih_lanterna2",
    id = "lcm_64a651_6ad65732_1f54fb40_0005_e376f8",
    label = "Lanterne d'aspecta",
    tags = "Rare",
    type = "talisman",
}, "1c3807765b7eee3b")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        constitution = -1,
        resi_contondant = 1,
        resi_perforant = 1,
        resi_tranchant = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "..Une pointe à l'intérieur semble prévue pour se planter dans la chair de son porteur...Allez savoir ce que ça fait.",
    etat = {
        courant = 28,
        max = 28,
        version = 2,
    },
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\eps_wc3h_rubyring",
    id = "lcm_64a651_6ad6948d_2044a6eb_0003_9081c9",
    label = "Anneau macabre",
    tags = "Commun",
    type = "anneau",
}, "2f59f336ada36dc9")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        resi_contondant = 2,
        resi_perforant = 2,
        resi_tranchant = 6,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Une lame qui fut autrefois impossante, et qui désormais, brisé en deux, n'a de prestance que sa garde encore ornée de symboles complexes et nobles.",
    etat = {
        courant = 76,
        max = 76,
        version = 2,
    },
    forge = "armes/inhabituel",
    icone = "Interface\\ICONS\\inv_sword_19",
    id = "lcm_64a651_6ad696b3_204d09c7_0009_8dcac8",
    label = "Espadon brisé.",
    tags = "Inhabituel",
    taille = 2,
    type = "epee",
}, "3340c8dae2909b84")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        resi_contondant = 2,
        resi_perforant = 2,
        resi_tranchant = 2,
    },
    categorie = "equipement",
    couleurTitre = "FF8CB8",
    description = "Une paire de mitaines épaisses, aux coutures irrégulières. Elles préservent tant bien que mal les doigts des morsures du gel.",
    etat = {
        courant = 46,
        max = 46,
        version = 2,
    },
    forge = "equilibrage_arme_copie/commun",
    icone = "Interface\\ICONS\\inv_leather_draenordungeon_c_01glove",
    id = "lcm_64a651_6ad697c4_205133c8_000b_f04e7d",
    label = "Mitaines de laine grossière",
    tags = "Commun",
    type = "gants",
}, "2141d45bab48e51f")

LCM.PublierPublique(LCM.Objets, "objets", {
    categorie = "outil",
    contenant = {
        entrees = { "consommables/lcm_132159_6adb71d4_2006d99d_0005_039df9" },
        retrait = "100",
        taille = "1000",
        types = { "lcm_64a651_6ad69a7f_205bdff2_0013_e59c87" },
    },
    couleurTitre = "FF8CB8",
    description = "A première vue.. Cette gourde ne semble avoir rien de particulier.. Pourtant, vous discerner dans le fond qu'elle contient une rune luissant d'une couleur solaire.",
    etat = {
        courant = "64",
        max = "64",
        version = "2",
    },
    forge = "lcm_64a651_6ad4ab02_18cc6d43_0002_bbe6a7/commun",
    ic = {
        convertis = 0,
        palier = "rose",
        proprietes = {  },
        version = 1,
    },
    icone = "Interface\\ICONS\\inv_drink_18",
    id = "lcm_64a651_6ad699e3_20597cb9_0012_35135e",
    label = "Gourde runique",
    tags = "Commun",
    transfertDe = { "ressources/lcm_64a651_6ad699e3_20597cb9_0012_35135e", "consommables/lcm_64a651_6ad699e3_20597cb9_0012_35135e" },
    type = "lcm_64a651_6ad69a7f_205bdff2_0013_e59c87",
}, "b94c4844b98dcfe4")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        pen_contondant = 4,
        pen_feu = 18,
        pen_lumiere = 18,
        pen_perforant = 16,
        pen_tranchant = 16,
    },
    categorie = "arme",
    couleurTitre = "FF9926",
    description = "Une épée batarde, dont les ornements ne sont pas sans rappeler les terres d'Era. Cette lame, d'une qualité reconnue, est animée d'une flamme dévorante.",
    etat = {
        courant = 76,
        max = 76,
        version = 2,
    },
    forge = "equilibrage_arme/epique",
    icone = "Interface\\ICONS\\inv_sword_1h_artifactfelomelorn_d_02",
    id = "lcm_64a651_6ad69c6a_20635e8c_0018_cf22e7",
    label = "Sérénité, lame de la gardienne de l'est.",
    tags = "Épique",
    taille = 1,
    type = "epee",
}, "d6933756e9162df1")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {  },
    categorie = "equipement",
    couleurTitre = "FF9926",
    description = "..Si tant est que vous tentiez d'en passer le voile, c'est l'abysse, et le néant qui vous attendraient. \n\nUn oeil divinatoire ne saurait percer les secrets que cache se masque.. pire encore.. Il semble même officier de barrière pour le porteur, couvrant même ses traces aux affres divinatoires. \n\nEn contrepartie.. Un oeil expert pourrait déterminer, en étudiant le masque, et sa signature, qu'il oeuvre une malédiction, interdisant à son portée l'accès à sa mémoire antérieur au port du masque.",
    etat = {
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "equilibrage_arme_copie/epique",
    icone = "Interface\\ICONS\\inv_helm_leather_demonhunter_a_01",
    id = "lcm_64a651_6ad69ffc_20714dc1_001a_88e267",
    label = "Vestige brisé de l'occulte masque de Blanche.",
    tags = "Épique",
    type = "masque",
}, "7a883886b986e020")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        acrobaties = 1,
        escalade = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Un anneau dont les reliefs ressemblent à une toile d'araignée. Lorsqu'il est porté, le porteur peut sentir son corps s'assouplir.",
    etat = {
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_70_quest_ring7a",
    id = "lcm_64a651_6ad6a129_2075e8c3_001c_b21b43",
    label = "Chevalière de la toile.",
    tags = "Commun",
    type = "anneau",
}, "54981ce461a956bf")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        escalade = -1,
        force_brise_armure = 2,
        meca_soin = 1,
        mystique_brise_armure = 2,
        pen_contondant = 6,
        pen_terre = 8,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    description = "Un bâton somme tout assez banal.. Des petites runes sur le coté indique un enchantement mineur..Et qui le porte sens la volonté de la terre l'animer.",
    etat = {
        ancienMax = 18,
        courant = 28,
        max = 28,
        version = 2,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\inv_staff_17",
    id = "lcm_64a651_6ad6a6b5_208b909d_0002_03630b",
    label = "Bâton brisé.",
    tags = "Commun",
    taille = 2,
    type = "baton",
}, "5c86d0e33e817d62")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        meca_buff = 2,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Un libram écrit par les plus fervents combattants de la Croisade, des litanies et quantiques particulièrement guerrier couvrent les pages, de quoi y puiser le courage nécessaire à lancer un nouvel assaut cinglant.\n\nLire un passage du Libram galvanise Kirsa et lui donne un avantage au combat",
    etat = {
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_offhand_1h_draenorquest95_b_02",
    id = "lcm_64a651_6ad6a8b1_2093524d_0003_269275",
    label = "Libram de zèle",
    tags = "Commun",
    type = "bijou",
}, "77ee0c6df47810f9")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        fatigue = 2,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Un héritage particulièrement sensible, offert par le supérieur de Kirsa, marque de la dévotion de la combattante et un outil de focalisation particulièrement utile.",
    etat = {
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_jewelry_necklace_28naxxramas",
    id = "lcm_64a651_6ad6a914_2094d3ee_0005_fbb4f8",
    label = "Chapelet de la Première Guerre",
    tags = "Commun",
    type = "pendentif",
}, "d7f4a32ffbeb3dc0")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        def_courage = 1,
        def_esprit_libre = 1,
        def_mental = 1,
        mystique = -1,
    },
    categorie = "accessoire",
    couleurTitre = "4DE04D",
    description = "Un anneau étrange, qui lorsqu'il est porté, semble faire mouvoir de l'encre sur le doigt du porteur. A priori, celle-ci se déforme parfois pour former une toile noirâtre. Allez savoir à quoi cela peut servir autre qu'à laisser une trace d'encre qui ne semble jamais disparaitre.",
    etat = {
        courant = 82,
        max = 82,
        version = 2,
    },
    forge = "equilibrage_armure_copie/inhabituel",
    icone = "Interface\\ICONS\\eps_wc3h_ringofflames",
    id = "lcm_64a651_6ad6a939_209564a6_0006_8050a9",
    label = "La toile morbide.",
    tags = "Inhabituel",
    type = "bijou",
}, "4d60db7cc05427c8")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        cosmique = 2,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Un ouvrage ancien et modeste dontla reliure de cuir n'est pas sans rapeler des stries c'encre séchée. L'oeuvre est d'un noir total, autant dans sa couverture que ses pages. Les esquisses ou texte inscrit sur ces dernières se tracent uniquement de blanc. Quand un écrit est inscrit, il ne demeure guère longtemps, disparaissant tôt ou tard.. Enfin.. Des pages semblent avoir été arrachés.",
    etat = {
        courant = 40,
        max = 40,
        version = 2,
    },
    forge = "equilibrage_armure_copie/commun",
    ic = {
        convertis = 0,
        palier = "rose",
        proprietes = {  },
        version = 1,
    },
    icone = "Interface\\ICONS\\eps_arc_book_venthyr2",
    id = "lcm_64a651_6ad79608_243265dd_0002_42b45b",
    label = "Le carnet ombreux.",
    tags = "Commun",
}, "007088a7e55d12d2")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        acrobaties = "-1",
        equilibre = "-1",
        escalade = "-1",
        pen_contondant = "15",
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Honnêtement.. Jamais vous ne parviendrez à porter pareil tronc d'arbre.. A moins d'être un ogre ?",
    etat = {
        courant = "70",
        max = "70",
        version = "2",
    },
    forge = "armes/inhabituel",
    ic = {
        convertis = 0,
        palier = "vert",
        proprietes = {  },
        version = 1,
    },
    icone = "Interface\\ICONS\\inv_hammer_15",
    id = "lcm_64a651_6adb7af6_0a5736cd_0004_627585",
    label = "Énorme tronc avec manche.",
    tags = "Inhabituel",
    taille = "2",
    type = "lcm_64a651_6adb7b60_0a58d5af_0006_a624f1",
}, "72cf6a711c88fb50")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        resi_contondant = "4",
        resi_eau = "2",
        resi_perforant = "4",
        resi_tranchant = "4",
        resi_vent = "2",
    },
    categorie = "equipement",
    couleurTitre = "4DE04D",
    description = "Une armure qui semble en mauvais état.. A l'image d'une combinaison, cette \"armure\" s'est enroulée autour de vos corps. Chaque partie a été sanglée, vous enfermant presque hemertiquement. C'est bien.. Vous êtes presque protégé du froid.",
    etat = {
        courant = "18",
        max = "18",
    },
    forge = "equilibrage_arme_copie/inhabituel",
    icone = "Interface\\ICONS\\inv_chest_cloth_78green",
    id = "lcm_aa9c40_6acfb25d_056140d0_0001_6ce82a",
    label = "Armure d'errance rapiecée.",
    tags = "Inhabituel",
}, "7b42d7eee369e67f")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        resi_contondant = 1,
        resi_perforant = 1,
        resi_tranchant = 2,
    },
    categorie = "equipement",
    couleurTitre = "FF8CB8",
    description = "Un manteau en cuir, pièce maîtresse d'une armure légère de cuirassier, portant les stigmates de innombrables campagnes. Son cuir épais, patiné par le temps et marqué de fines éraflures, offre une protection souple mais robuste. Il a été subtilement renforcé aux endroits stratégiques : des plaques d'acier rivetées ornent les coudes et les épaules, ajoutant une touche de rigidité sans compromettre la mobilité. Le col montant, renforcé par une bande métallique interne, protège la gorge contre les c",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/commun",
    icone = "Interface\\ICONS\\inv_chest_armor_dwarf_d_01",
    id = "lcm_aa9c40_6ad01d02_0701cde1_0001_4276a5",
    label = "Manteau d'exploration",
    tags = "Commun",
}, "3e234d032ea8aef3")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        cosmique = 1,
        elementaire = 1,
        meca_dissipation = 1,
        meca_soin = 2,
        vue = 4,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Une lentille enchantée permettant d'observer l'intérieur du corps d'une créature.\nPermet de repérer blessures internes, organes fragiles ou points faibles avant ou pendant un combat.",
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\inv_helm_glasses_b_01_gold2_teal",
    id = "lunette_d_anatomie",
    label = "Lunette d'anatomie",
    tags = "Rare",
}, "2698b0c5ef637267")

LCM.PublierPublique(LCM.Objets, "objets", {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        force_brise_armure = 2,
        meca_buff = 1,
        meca_confusion = 1,
        meca_controle_mental = 1,
        meca_debuff = 1,
        mystique_brise_armure = 2,
        pen_contondant = 4,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Un cadeau de l'école des Bardes. Une table d'harmonie en épicéa avec une caisse en érable flammé. Manche en érable, touche et chevilles en buis, le tout avec une rosace sculptée et des filets en bois sombre méticuleusement damasquinés.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\trade_archaeology_carved harp of exotic wood",
    id = "luth",
    label = "Luth",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
    type = "lcm_64a651_6acd5cbe_0f3e05e9_0005_ba6ba7",
}, "1b85cdc20765d0ea")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        pistage = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Dans leurs missions d'escorte de voyageurs,  les garde-forestiers d'Elestria donnent à ces derniers une pièce enchantée avec un sort de localisation : toute fée d'Elestria à portée peut situer la direction et une distance approximative de la pièce. Ce pouvoir est amplifié dans leur forêt native, permettant de repérer un voyageur égaré sur plusieurs kilomètres. En revanche, en dehors de la forêt, la pièce n'est détectable que sur quelques centaines de mètres et de manière peu précise.\n\nDans notre",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_misc_azsharacoin",
    id = "piece_du_voyageur_egaree",
    label = "Pièce du voyageur égarée",
    tags = "Commun",
}, "b30a03766ee4458f")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        resi_contondant = 2,
        resi_perforant = 2,
        resi_tranchant = 2,
    },
    categorie = "equipement",
    couleurTitre = "4DE04D",
    description = "Un rempart qui protège bien.",
    etat = {
        courant = 40,
        max = 40,
    },
    forge = "equilibrage_arme_copie/inhabituel",
    icone = "Interface\\ICONS\\inv_chest_chain_17",
    id = "rempart_de_guerre",
    label = "Rempart de guerre",
    tags = "Inhabituel",
    type = "plastron",
}, "af4e7a9d83f78e64")

LCM.PublierPublique(LCM.Objets, "objets", {
    bonus = {
        meca_soin = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une sacoche contenant bandages, aiguilles, fils, pinces, antiseptiques et petits instruments chirurgicaux.\n\nPermet à Archibald de soigner et stabiliser les créatures et allier blessées, même sans disposer d'une véritable infirmerie.",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_misc_coinbag04",
    id = "trousse_de_veterinaire_de_terrain",
    label = "Trousse de vétérinaire de terrain",
    tags = "Commun",
}, "211eae70c4035f12")

-- ----- races (9) ---------------------------------------------------
LCM.PublierPublique(LCM.Races, "races", {
    avantage = {},
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
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
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurFond = "080D11",
    couleurTitre = "FF8CB8",
    description = "Aeeelskardien.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\ability_mage_frostjaw",
    id = "aelskardien",
    label = "Aelskardien",
    mjSeulement = true,
    morphology = "humanoide",
    tags = "Commun",
}, "f6793bd579dcde52")

LCM.PublierPublique(LCM.Races, "races", {
    bonus = {
        adresse = "4",
        constitution = "2",
        esprit = "3",
        force = "2",
        mystique = "3",
        pen_contondant = "3",
        pen_desordre = "3",
        pen_eau = "3",
        pen_esprit = "3",
        pen_feu = "3",
        pen_lumiere = "3",
        pen_mort = "3",
        pen_ombre = "3",
        pen_ordre = "3",
        pen_perforant = "3",
        pen_pourriture = "3",
        pen_terre = "3",
        pen_tranchant = "3",
        pen_vent = "3",
        pen_vie = "3",
        perception = "3",
        resi_contondant = "3",
        resi_desordre = "3",
        resi_eau = "3",
        resi_esprit = "3",
        resi_feu = "3",
        resi_lumiere = "3",
        resi_mort = "3",
        resi_ombre = "3",
        resi_ordre = "3",
        resi_perforant = "3",
        resi_pourriture = "3",
        resi_terre = "3",
        resi_tranchant = "3",
        resi_vent = "3",
        resi_vie = "3",
    },
    couleurTitre = "FF8CB8",
    description = "Un elfe. Imbuvable. Mais pas comme son vin.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_character_bloodelf_male",
    id = "elfe",
    label = "Elfe",
    morphology = "humanoide",
    tags = "Commun",
}, "9207f03f21135072")

LCM.PublierPublique(LCM.Races, "races", {
    avantage = {  },
    bonus = {
        adresse = 4,
        constitution = 2,
        esprit = 3,
        force = 2,
        mystique = 3,
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
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurTitre = "FF8CB8",
    description = "Fée Flappy. Fée pas le malin, tu n'as plus tes ailes.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_tft_faerieemblem",
    id = "fee",
    label = "Fée (sans ailes.)",
    morphology = "humanoide",
    tags = "Commun",
}, "cfd7809d33b7b1d4")

LCM.PublierPublique(LCM.Races, "races", {
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
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
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurTitre = "FF8CB8",
    description = "Un humain. tout ce qu'il y a de plus humain.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_character_human_male",
    id = "humain",
    label = "Humain",
    morphology = "humanoide",
    tags = "Commun",
}, "45ffae6429f25eed")

LCM.PublierPublique(LCM.Races, "races", {
    avantage = {},
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
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
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurTitre = "FF8CB8",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_leona_sunlight",
    id = "insgardienne",
    label = "Insgardienne",
    mjSeulement = true,
    morphology = "humanoide",
    remplacePublie = true,
    tags = "Commun",
}, "c559e4d2ac409820")

LCM.PublierPublique(LCM.Races, "races", {
    bonus = {
        adresse = 2,
        constitution = 5,
        esprit = 2,
        force = 5,
        mystique = 3,
        pen_contondant = 5,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 1,
        pen_mort = 5,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 1,
        perception = 2,
        resi_contondant = 4,
        resi_desordre = 3,
        resi_eau = 2,
        resi_esprit = 3,
        resi_feu = 2,
        resi_lumiere = 1,
        resi_mort = 5,
        resi_ombre = 5,
        resi_ordre = 3,
        resi_perforant = 4,
        resi_pourriture = 5,
        resi_terre = 2,
        resi_tranchant = 4,
        resi_vent = 2,
        resi_vie = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Imposant, massif.. Un \"nain\" n'est certainement pas une créature de petite taille.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_item_bamiscinder",
    id = "lcm_aa9c40_6acecf5e_01ea95fe_0001_4b65d0",
    label = "Nhins",
    mjSeulement = true,
    morphology = "humanoide",
    tags = "Commun",
}, "6c1c293766a9b1d4")

LCM.PublierPublique(LCM.Races, "races", {
    bonus = {
        adresse = "2",
        constitution = "5",
        esprit = "2",
        force = "5",
        mystique = "3",
        pen_contondant = "3",
        pen_desordre = "3",
        pen_eau = "3",
        pen_esprit = "3",
        pen_feu = "3",
        pen_lumiere = "3",
        pen_mort = "3",
        pen_ombre = "3",
        pen_ordre = "3",
        pen_perforant = "3",
        pen_pourriture = "3",
        pen_terre = "3",
        pen_tranchant = "3",
        pen_vent = "3",
        pen_vie = "3",
        perception = "3",
        resi_contondant = "3",
        resi_desordre = "3",
        resi_eau = "3",
        resi_esprit = "3",
        resi_feu = "3",
        resi_lumiere = "3",
        resi_mort = "3",
        resi_ombre = "3",
        resi_ordre = "3",
        resi_perforant = "3",
        resi_pourriture = "3",
        resi_terre = "3",
        resi_tranchant = "3",
        resi_vent = "3",
        resi_vie = "3",
    },
    couleurTitre = "FF8CB8",
    description = "Foutrement gros. Foutrement fort.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_reputation_ogre",
    id = "lcm_aa9c40_6adb6c92_0a1ef442_0001_98aa1a",
    label = "Ogre",
    mjSeulement = true,
    morphology = "humanoide",
    tags = "Commun",
}, "7982bf24788765d7")

LCM.PublierPublique(LCM.Races, "races", {
    avantage = {},
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
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
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurTitre = "FF8CB8",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_nilah_jubilantveil",
    id = "projet_htdt_02",
    label = "Projet HTDT-02",
    mjSeulement = true,
    morphology = "humanoide",
    remplacePublie = true,
    tags = "Commun",
}, "9f10f4f4fdcb42c9")

LCM.PublierPublique(LCM.Races, "races", {
    bonus = {
        adresse = "3",
        constitution = "4",
        esprit = "4",
        force = "2",
        mystique = "3",
        nage = "-1",
        pen_contondant = "3",
        pen_desordre = "2",
        pen_eau = "3",
        pen_esprit = "3",
        pen_feu = "3",
        pen_lumiere = "3",
        pen_mort = "3",
        pen_ombre = "3",
        pen_ordre = "3",
        pen_perforant = "3",
        pen_pourriture = "3",
        pen_terre = "3",
        pen_tranchant = "3",
        pen_vent = "3",
        pen_vie = "3",
        perception = "3",
        resi_contondant = "3",
        resi_desordre = "3",
        resi_eau = "3",
        resi_esprit = "3",
        resi_feu = "3",
        resi_lumiere = "3",
        resi_mort = "3",
        resi_ombre = "3",
        resi_ordre = "3",
        resi_perforant = "3",
        resi_pourriture = "3",
        resi_terre = "3",
        resi_tranchant = "3",
        resi_vent = "3",
        resi_vie = "3",
    },
    couleurTitre = "FF8CB8",
    description = "Une race qui vient du pays de l'été et du soleil qui ne se couche jamais.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_zone_tanaris_01",
    id = "valien",
    label = "Valien",
    morphology = "humanoide",
    tags = "Commun",
}, "7cd83a01972d2ca4")

-- ----- ressources (14) ----------------------------------------------
LCM.PublierPublique(LCM.Ressources, "ressources", {
    description = "Franchement, c'est solide.",
    etat = {
        courant = 10,
        max = 10,
    },
    icone = "Interface\\ICONS\\inv_ore_blackrock_ore",
    id = "lcm_64a651_6ace4cd9_12e7e6e8_0004_f78759",
    label = "Cailloux",
}, "3916a98044d16548")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Une petite pierre runique.. allez savoir à quoi cela sert.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_rune_04",
    id = "lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
    label = "Pierre runique",
    tags = "Commun",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "b96a4675db78c675")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "4DE04D",
    description = "Cette pierre d'un rouge feu dégage une petite chaleur au creux de votre main.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/inhabituel",
    icone = "Interface\\ICONS\\inv_jewelcrafting_80_gem01_red",
    id = "lcm_64a651_6ad65c1f_1f683923_0006_eecba6",
    label = "Pierre rouge.",
    tags = "Inhabituel",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "e23d5ccb92ca12eb")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "4DE04D",
    description = "Une pierre violâtre qui semble dégager une petite brume violacée.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/inhabituel",
    icone = "Interface\\ICONS\\inv_misc_gem_amethyst_01",
    id = "lcm_64a651_6ad65d53_1f6ceb05_0008_ac7d09",
    label = "Pierre violâtre",
    tags = "Inhabituel",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "d63ab8bf529579d2")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "4DE04D",
    description = "Cette petite pierre verte ne semble rien peser.. Pire.. Lorsqu'elle tombe, celle-ci semble prendre son temps pour rejoindre le sol.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/inhabituel",
    icone = "Interface\\ICONS\\inv_misc_gem_deepperidot_03",
    id = "lcm_64a651_6ad65e22_1f70123b_000b_aa9a60",
    label = "Pierre verte",
    tags = "Inhabituel",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "ad8e2a08b5046686")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "4DE04D",
    description = "Cette pierre d'un bleu profond est humide entre vos mains et glisserait presque si vous ne ma mainteniez pas correctement. outre ça, son toucher est foutrement froid.. et l'eau qu'elle laisse sur votre peau gèle. ",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/inhabituel",
    icone = "Interface\\ICONS\\inv_jewelcrafting_80_gem02_blue",
    id = "lcm_64a651_6ad65ebf_1f7276d7_000e_4cb110",
    label = "Pierre bleu",
    tags = "Inhabituel",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "a796f63815c45bce")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "4DE04D",
    description = "Une pierre noir.. quand vous tenez celle-ci en main.. vos doigts semblent peu à peu happé vers la pierre.. vous forçant à la serrer.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/inhabituel",
    icone = "Interface\\ICONS\\inv_misc_gem_pearl_01",
    id = "lcm_64a651_6ad65f76_1f7541c3_0010_bb7819",
    label = "Pierre noir",
    tags = "Inhabituel",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "5a193e8b8b28105c")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Une feuille de papier de mauvaise qualité.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_paperbundle02a",
    id = "lcm_64a651_6ad6917e_2038b154_0002_0495e5",
    label = "Papier de mauvaise qualité.",
    tags = "Commun",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "1c7507b67237f09d")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "L'ouvrage dégage une auteur de bois et de fougère.. Un cadena gravé d'une rune semble bloqué son ouverture. A en juger par sa deventure, il a été rédigé dans une langue inconnue.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\eps_arc_book_blacksmith2",
    id = "lcm_64a651_6ad69649_204b6b9c_0008_8ea27e",
    label = "Livre scellé.",
    tags = "Commun",
    type = "lcm_64a651_6ad6963b_204b33a4_0007_f08a79",
}, "f8a4fe91c933bfc5")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un galet sombre qui, une fois placé près d'une flamme, conserve sa chaleur pendant une durée étonnamment longue.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\w3reforgedphilosophersstone",
    id = "lcm_64a651_6ad698e5_20559c3e_0010_d9c4c2",
    label = "Pierre chauffe-main",
    tags = "Commun",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "949efc33f73feade")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un lingot d'or. Quoi de plus parlant que cette richesse ?",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_ingot_03",
    id = "lcm_64a651_6ad69940_2056ffd5_0011_2aebe3",
    label = "Lingot d'or.",
    tags = "Commun",
    type = "lingot",
}, "a797ebd200205d8e")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "FF8CB8",
    description = "Ce bibelot empeste d'une odeur de renfermé. En revanche, son contenue écrit dans une langue inconnue est en parfait état. Parfois, sur certaines pages, d'étranges symboles formant des cercles magiques sont présentés.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\eps_arc_book_firedruid1",
    id = "lcm_64a651_6ad6a1ac_2077e559_001e_3e8557",
    label = "Livre en langue inconnue.",
    tags = "Commun",
    type = "lcm_64a651_6ad6963b_204b33a4_0007_f08a79",
}, "7db5a3f057edafea")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "BF4DFF",
    description = "Une pièce, qui parait indestructible. Grâvée d'une lune noire, l'objet semble parfaitement lisse de toute aspérité.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/mythique",
    icone = "Interface\\ICONS\\eps_rumble_traitearthandmoon",
    id = "lcm_64a651_6ad6afb5_20aeb7c6_0007_bfca2d",
    label = "Pièce blanche gravée d'une lune.",
    tags = "Mythique",
    type = "lcm_64a651_6ad6b267_20b93f97_0009_924d4c",
}, "9c6cc4f5c51480ce")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "FF8CB8",
    description = "Une encre noire contenue dans un flacon ébréché.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_inscription_inkblack01",
    id = "lcm_aa9c40_6ad68e2f_202bb932_0001_d016e0",
    label = "Encre en fiole",
    tags = "Commun",
    type = "lcm_64a651_6ad69189_2038de7c_0003_65dfb5",
}, "9ece97cf811ea052")

-- ----- tentes (4) --------------------------------------------------
LCM.PublierPublique(LCM.Tentes, "tentes", {
    accessoiresMax = 20,
    bonus = {
        recup_fatigue = 100,
        recup_pv = 100,
        securite = 100,
    },
    id = "auberge_de_tephris",
    label = "Auberge de Tephris",
    lits = 1,
    origine = "Aelskar",
}, "ab23b73d6f9eba82")

LCM.PublierPublique(LCM.Tentes, "tentes", {
    bonus = {
        recup_fatigue = 6,
        securite = 4,
    },
    couleurTitre = "FF8CB8",
    description = "zeazeaeaeaz",
    forge = "lcm_64a651_6acbc610_09097aca_0002_99aa48/commun",
    icone = "Interface\\AddOns\\LesContesMalveillants\\ressources\\icones\\constitution.blp",
    id = "lcm_132159_6acfc046_01d79ef3_0001_f0d206",
    label = "Suuuuuuuuuuuuce",
    tags = "Commun",
}, "61b79120cda76bdd")

LCM.PublierPublique(LCM.Tentes, "tentes", {
    accessoiresMax = 5,
    bonus = {
        recup_armure = 2,
        recup_fatigue = 3,
        recup_pv = 3,
        securite = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Une petite tente pour survivre face aux tempêtes blanches.",
    forge = "lcm_64a651_6acbc610_09097aca_0002_99aa48/commun",
    icone = "Interface\\ICONS\\hots_deckard_horadriccube",
    id = "lcm_64a651_6acbc523_0905cf56_0001_23671e",
    label = "Toundralite de petite taille",
    lits = 1,
    origine = "Aelskar",
    tags = "Commun",
}, "71edc199723e0471")

LCM.PublierPublique(LCM.Tentes, "tentes", {
    bonus = {
        recup_fatigue = "4",
        recup_pv = "4",
        securite = "2",
    },
    couleurTitre = "FF8CB8",
    description = "fsqdqzd",
    forge = "lcm_64a651_6acbc610_09097aca_0002_99aa48/commun",
    icone = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\actions-supports.tga",
    id = "lcm_64a651_6acfdf84_0611a8c6_0003_343bf4",
    label = "Tente de gros",
    tags = "Commun",
}, "8f2f4c148d791e38")

-- ----- traits (40) --------------------------------------------------
LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        pen_perforant = 1,
        pen_tranchant = 2,
        resi_contondant = 1,
        resi_perforant = 1,
        resi_tranchant = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Elle maintient ses armes et son armure en bonne condition en toute circonstance. Il n'est pas rare qu'elle fasse du zèle pour aiguiser un peu plus sa lame ou ajouter quelques renforts d'appoint à son armure.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_eyeoftheowl",
    id = "attentive",
    label = "Attentive",
    tags = "Commun",
}, "0af45951a250601b")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        acrobaties = "1",
        escalade = "1",
        resistance = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Au quotidien, Reika se meut avec la grâce d'un automate d'apparat. Ses gestes sont doux, lents et harmonieux, chaque mouvement soigneusement mesuré, comme il sied à une jeune dame de bonne famille.\n\nMais lorsque les circonstances l'exigent, cette délicatesse cède la place à une mécanique autrement plus troublante. Son corps s'articule avec une précision presque inhumaine, enchaînant les mouvements avec la célérité et l'exactitude d'une horloge parfaitement réglée.\n\nAprès tout, sous les apparence",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_viktor_gloriousevolution",
    id = "automate_danseuse",
    label = "Automate danseuse",
    tags = "Commun",
}, "ecbc4ca6dd068f44")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        meca_buff = 1,
        meca_confusion = 1,
        meca_debuff = 1,
    },
    couleurTitre = "FF8CB8",
    description = "L'art a une souveraineté en ce bas monde. Il égaie les esprits, galvanise les coeurs... Autant de notes frémissantes pincées de ses cordes qui embaument l'air comme des promesses. Ses années passées à l'Ecole des Bardes lui ont enseigné les arcanes de l'envoûtement. Elle sait vous faire rire, - jusqu'à la mort. Vous faire pleurer sur une femme que vous n'avez pas connue. Vous exalter tant et si bien qu'aucun ennemi ne vous résistera. - jusqu'à ce qu'il vous résiste. - Les artistes sont ce qu'ils",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\hd_hd_hd_bard_   overture",
    id = "barde",
    label = "Barde",
    tags = "Commun",
}, "3414cd2959eb45d1")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        crochetage = "1",
        discretion = "1",
        vol_a_la_tire = "1",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "L'arc et le jeu de scène suffisent assez rarement aux fins de mois. Alors, autrefois, elle se glissait avec quelques copains dans de riches baraques pour en voler les biens. Elle sait se faire discrète, se fondre dans les ombres, - dans une certaine mesure. Crocheter des verrous assez complexes, se faire morte quand le prédateur pointe le bout de son nez. Il est assez connu que Maia volait \"au-delà\" de ses besoins primaires. Elle aime l'argent comme l'orphelin aime la chaleur du feu.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_stealth",
    id = "cambrioleuse",
    label = "Cambrioleuse",
    tags = "Commun",
}, "7ab7758e73508ea3")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        deguisement = 2,
        discretion = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Que ce soit lorsqu'elle travaillait à la Foire de Sombrelune ou à l'Ecole des Bardes de Hurlevent, Maia a développé son sens de la comédie, du paraître et de la vraisemblance. Elle est le môme aux cheveux courts qu'on a engagé dans ce baleinier. Cette triste veuve grimée de noir qui attend son époux depuis dix ans maintenant. L'écuyer. L'amant. Ou l'amante. La pieuse femme et l'impie. Elle sait jouer le drame et la comédie, - bien qu'elle préfère la comédie.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_arc_halloween_shatteredmask",
    id = "comedienne",
    label = "Comédienne",
    tags = "Commun",
}, "011eddf939eb169b")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        communication = 1,
        pen_vie = 1,
        pistage = 1,
        resi_vie = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Archibald sait interpréter les comportements, traces et réactions des créatures. Grâce à ses connaissances de zoologiste, il peut déduire instinctivement leurs intentions, habitudes ou état d'esprit, là où d'autres devraient enquêter.\n\nSa permettrais d'avoir quelques informations pour :\n- Anticiper les attaques\n- Identifier les points faibles\n- Eviter certains combat\n- Comprendre l'écosystème",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_beasttraining",
    id = "comprehension_des_creatures",
    label = "Compréhension des créatures.",
    tags = "Commun",
}, "facfb9eff5b9a4a6")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        communication = 1,
        investigation = 1,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Des champignons aux oiseaux en passant par les rongeurs et autres créatures, les gardes forestiers se doivent de connaitre le microcosme de leur forêt natale afin de mieux guider quiconque s'y aventure.\n\nAvantage de savoir concernant les animaux vivant dans un milieu forestier. Cela permet aussi de mieux connaitre les habitudes de ces derniers et donc de mieux les chasser.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\achievement_zone_elwynnforest",
    id = "connaissance_du_regne_forestier",
    label = "Connaissance du règne forestier",
    tags = "Commun",
}, "3ff09b24de19cf58")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        pa = "1",
        resi_desordre = "-2",
        resi_ordre = "-2",
    },
    couleurTitre = "FF8CB8",
    description = "En quête de perfection, il ne suffisait guère à sa créatrice de produire une âme artificielle indiscernable d'une âme naturelle. Dans sa poursuite du progrès, elle dota sa création de la faculté de se façonner elle-même, lui offrant ainsi la plus grande des aventures : celle de passer une vie à expérimenter toutes les vies.\n\nAinsi, Reika, fruit de recherches que nul ne saurait pleinement comprendre, dispose de ce que sa créatrice a sobrement nommé « l'âme mouvante ».\n\nContrepied peu dissimulé à",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_camille_adaptivedefense",
    id = "cycle_construire_et_deconstruire",
    label = "Cycle : Construire et déconstruire.",
    tags = "Commun",
}, "75a10d94f2dd1796")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        acrobaties = 1,
        discretion = 1,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Les gardes-forestiers de la forêt d'Elestria sont formés à se déplacer de manière silencieuse au sein de leur environnement. Cela leur permet de guider les voyageurs et les commerçants sans attirer l'attention d'animaux considérés comme dangereux. Utile aussi lorsqu'ils doivent aider les chasseurs de leur communauté.\n\nAvantage de discrétion dans une forêt, sur un terrain \"végétalisé\" ou \"encombré de branches, feuilles, cailloux\".",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_posthaste",
    id = "deplacement_furtif_en_millieu_forestier",
    label = "Déplacement furtif en millieu forestier",
    tags = "Commun",
}, "f677988d2f87ec3a")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        meca_perce_armure = 2,
        perception_attaque = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Il n'y a rien qui puisse justifier que Maia Petersen ait une telle adresse à l'arc. C'est ainsi, comme il en est du génie qui remplit les fronts des poètes et de la puissance des grands sorciers. Petite, elle tirait avec l'arc de sa mère pour éloigner les goules; la chose lui est toujours apparue comme instinctive. Evidente. Elle manie l'arc avec une aisance industrielle et n'a jamais semblé s'en interroger.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_focusedaim",
    id = "elfe_manquee",
    label = "Elfe manquée",
    tags = "Commun",
}, "172a4faf45c40926")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        discretion = 2,
        evasion = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Malgré le port d'une armure lourde, on peut s'étonner de la vivacité de Caedicia, il n'est pas rare qu'elle évite plus de coup qu'elle n'en encaisse.\nDe plus, dans l'obscurité sa nature elfique lui permet de passer inaperçu...Tant qu'elle ne bouge pas.\n\nPlus prompt à esquivé les coups. Aisance à se cacher lorsqu'elle est immobile.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_ambush",
    id = "elusive",
    label = "Élusive",
    tags = "Commun",
}, "ce81a5e1899c949d")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        deguisement = "1",
        discretion = "1",
        evasion = "1",
    },
    couleurTitre = "FF8CB8",
    description = "C'est là qu'il a acquis son instinct pour repérer les ennuis, sa méfiance envers les inconnus et sa capacité à passer inaperçu. Il sait marchander, se faufiler et dormir n'importe où, et cette enfance explique pourquoi il n'a jamais cherché la gloire : il sait ce que vaut un repas chaud.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\achievement_dungeon_lostcity of tolvir",
    id = "enfant_des_rues",
    label = "Enfant des rues",
    tags = "Commun",
}, "a6268a2eb2b0e1eb")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        resi_esprit = 3,
        resi_ombre = 3,
    },
    couleurTitre = "FF8CB8",
    description = "Une vie de conflit ont rendu Caedicia plutôt détachée, à tel point que les sorts d'influence mentales ont du mal à trouvé un ancrage solide dans son esprit.\n\nPlus grande chance de résister aux effets de peurs et d'influence mentale.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\dos2_mind",
    id = "forteresse_mentale",
    label = "Forteresse mentale",
    tags = "Commun",
}, "4f9547879c7b27ae")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        meca_perce_armure = "1",
        odorat_gout = "1",
        resi_contondant = "2",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "La porteuse de ces mémoires est capable de pouvoir discuter avec des reptiles, elle connait les secrets et les maniement du sifflement comme personne.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_item_spiritofthedragon",
    id = "lcm_132159_6ad17f79_08aa84cb_0001_cf7036",
    label = "Mio'Rina - Souvenir de Reptile",
    tags = "Commun",
}, "de59567dd28fde8a")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        pen_eau = "2",
        pen_perforant = "4",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "zeazeaeazeaze",
    forge = "traits/commun",
    id = "lcm_132159_6ad78703_10b97f24_0001_99129e",
    label = "TEST TEST TEST",
    tags = "Commun",
}, "7fe8610219363798")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        discretion = 2,
        pen_ombre = 3,
        resi_lumiere = -2,
    },
    couleurTitre = "FF8CB8",
    description = "Ce personnage manie les ombres avec une aisance terrifiante.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_rogue_shadowdance",
    id = "lcm_64a651_6ac76e82_3598aaf8_0001_f2b89d",
    label = "Danseur des ombres",
    tags = "Commun",
}, "492e6756f47d1edb")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        discretion = 1,
        meca_perce_armure = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Autrefois quelqu'un.. Il n'aspire désormais qu'à s'élever dans la hiérarchie du culte de Nocturna.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\hots_sylvanas_shadowdagger",
    id = "lcm_64a651_6ac7710f_35a2aedc_0003_6b06bc",
    label = "Cisaire ambitieux.",
    tags = "Commun",
}, "820ac48eecfaef8a")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        deguisement = 1,
        discretion = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Nul ne sait qui des nôtres est si ce n'est lui-même.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\spell_arcane_prismaticcloak",
    id = "lcm_64a651_6ac7715c_35a3dd0b_0004_ba2485",
    label = "Terreur des ombres.",
    tags = "Commun",
}, "194275f98a186703")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        pen_ombre = 2,
        resi_lumiere = 4,
    },
    couleurTitre = "FF8CB8",
    description = "Vos lumières nous font chaux, car dans l'abnégation du culte, nous servons, nous endurons.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\d3_shadowpower",
    id = "lcm_64a651_6ac77195_35a4bae4_0005_9cc402",
    label = "Résilience nocturne",
    tags = "Commun",
}, "476db3cadc16875b")

LCM.PublierPublique(LCM.Traits, "traits", {
    avantage = {  },
    bonus = {
        pen_lumiere = 4,
        resi_lumiere = 2,
    },
    couleurTitre = "FF8CB8",
    cout = 1,
    description = "La Lumière habite Kirsa, si l’ont peu avoir des doutes sur la sainteté de la Croisade qu’elle a servie, on ne peut douter de la sienne.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_wow_lightsmith",
    id = "lcm_64a651_6acab9e6_04f1ed9d_0001_b03c06",
    label = "Vertueuse",
    tags = "Commun",
}, "550c62837a3c535f")

LCM.PublierPublique(LCM.Traits, "traits", {
    avantage = {  },
    bonus = {
        def_courage = 1,
        def_esprit_libre = 1,
        def_mental = 1,
    },
    couleurTitre = "FF8CB8",
    cout = 1,
    description = "Peu importe que la Croisade ait disparu, les vœux de Kirsa sont immuable et renforce sa détermination en toute circonstance.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_paladin_selflesshealer",
    id = "lcm_64a651_6acabb9f_04f8b719_0002_c63df8",
    label = "Serment",
    tags = "Commun",
}, "b6223434af277430")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        pistage = 1,
        vue = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Monstre de la nuit, les voyageurs nocturnes disposent d'une faculté innée à percevoir dans la pénombre, et se frayer un chemin là où leur cible attend leur mort.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_rogue_nightblade",
    id = "lcm_64a651_6acb7c33_07e8ea2e_0001_290bb6",
    label = "Voyageur nocturne.",
    tags = "Commun",
}, "3ad5c9eba8f52894")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        def_agilite = 1,
        def_courage = 2,
        def_defense = 2,
        def_esprit_libre = 2,
        def_insensible = 1,
        def_mental = 1,
        def_stable = 2,
        meca_attraction = 2,
    },
    couleurTitre = "FF9926",
    forge = "traits/epique",
    icone = "Interface\\ICONS\\ability_warrior_bloodfrenzy",
    id = "lcm_64a651_6aced05c_01ee805c_0002_685bb7",
    label = "Nhin Cac",
    tags = "Épique",
}, "03670987f545a1a3")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        def_courage = 4,
        def_defense = 2,
    },
    couleurTitre = "4DE04D",
    forge = "traits/inhabituel",
    icone = "Interface\\ICONS\\ability_bossdarkvindicator_auraofoppression",
    id = "lcm_64a651_6aced2e4_01f863c6_0003_d663b1",
    label = "Base nhin",
    tags = "Inhabituel",
}, "86c00dd24e7eb694")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        vue = 3,
    },
    couleurTitre = "FF8CB8",
    cout = 1,
    description = "Un trait d'encre bien placé, une vallée ombrée avec soin, une marge ornée d'un petit monstre ou d'une rose des vents. Il dessine par goût autant que par métier, et c'est ce qui fait que ses cartes se vendent mieux que celles des autres.\n\nNégociant / Diplomate\nVue",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\achievement_zone_talador",
    id = "lcm_64a651_6acf8ba7_04ca156c_0002_7fea76",
    label = "Artiste",
    tags = "Commun",
}, "2d456be0ee5f8ad9")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        pen_contondant = "17",
        resi_contondant = "3",
        resi_perforant = "3",
        resi_tranchant = "3",
    },
    couleurTitre = "FF9926",
    cout = "4",
    description = "Peu me chau de votre stratégie. Moi, je frappe.",
    forge = "traits/epique",
    icone = "Interface\\ICONS\\w3reforgedoneheadedogre",
    id = "lcm_64a651_6adb7916_0a4fe223_0002_603254",
    label = "Moi tappey très fort !",
    tags = "Épique",
}, "813bf91ad3e25c65")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        initiative = "-1",
        pa = "1",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "Moi pas comprendre.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\spell_shadow_brainwash",
    id = "lcm_64a651_6adb7ab8_0a5642fe_0003_de4228",
    label = "Moi pas savoir quoi toi dire.",
    tags = "Commun",
}, "b846af94fdba0b50")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        meca_intimidation = 1,
        meca_provocation = 1,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    cout = 1,
    description = "Face à une bête non magique, Archibald peut tenter de l'intimider ou de la calmer en utilisant sa connaissance de ses instincts.\n\nCe trait permet à Archibald d'utiliser sa connaissance du comportement animal pendant un combat :\n- Intimider une bête\n- Calmer une créature\n- Détourner son attention",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_onewithnature",
    id = "lcm_aa9c40_6acf8ad8_04c6e228_0001_a3737c",
    label = "Domination instinctive",
    tags = "Commun",
}, "6fb008a3cb3cc73d")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        communication = 2,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Archibald sais calmer, dresser et manipuler les animaux. Une créature non magique peut être apprivoisée ou temporairement coopérative si ses instincts et son état le permettent.\n\nMaître de la Ménagerie apporte surtout une utilité hors combat et situationnelle :\n- Aide au domptage de la faune forestière\n- Faciliter l'exploration\n- Interagir avec la faune",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_rumble_petrify",
    id = "maitre_de_la_menagerie",
    label = "Maitre de la ménagerie",
    tags = "Commun",
}, "dc4072bc76861e08")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        initiative = "1",
        meca_attaque_simple = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Il se bat comme il dessine : sans fioritures, en allant à l'essentiel. Il vise à mettre fin au combat le plus vite possible pour reprendre la route. Ses années dans la rue lui ont appris à se battre sale et à profiter du terrain, plus que les gestes appris dans une salle d'armes.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\dos2_sword",
    id = "maniement_de_l_epee",
    label = "Maniement de l'épée",
    tags = "Commun",
}, "d995a5ac8801c71f")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        meca_attaque_simple = 1,
        meca_brise_armure = 1,
        meca_intervention = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Férue des ouvrages traitants des arts martiaux et de la guerre, Caedicia n'a besoin qu'une lecture pour retenir l'essentiel de tels ouvrages. Pratique dans certaines situations particulière.\n\nApprentissage bien plus rapide des techniques de combats. Connaissance quasi-encyclopédique de l'art de la guerre.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_mage_studentofthemind",
    id = "memoire_selective",
    label = "Mémoire sélective",
    tags = "Commun",
}, "a0d67c7585143b3e")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        discretion = "1",
        meca_perce_armure = "1",
        odorat_gout = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Ses quelques années passées au contact des Blud’kra lui ont largement suffi. Il n’était désormais plus seulement question de leur survivre, mais d’apprendre à s’en défaire. Proprement. Efficacement. Avant qu’ils n’aient eux-mêmes l’occasion de frapper.\n\nÀ force de les observer, elle apprit à se mouvoir dans leur ombre, à masquer sa propre présence sous leur odeur et à reconnaître les traces qu’ils laissaient derrière eux. Avec le temps, elle devint même capable de sentir leur passage sur un terr",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_fiddlesticks_crowstormsurpriseparty",
    id = "moon_chasseuse_de_monstruosites",
    label = "Moon - Chasseuse de monstruosités",
    tags = "Commun",
}, "79c6c073baeea2ce")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        investigation = "1",
        pistage = "1",
        vue = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Danseuse n'est hélas pas le métier que l'on souhaiterait exercer. Il n'est guère propice aux soirées animées où éclatent de doux rires, ni aux représentations sous les regards émerveillés d'un public.\n\nDans le Val'Razkah, les danseurs sont ceux qui ont appris à arpenter les plaines de sable et les parois rocheuses sans finir dans la gueule d'une créature ou au fond d'un piège. Observer son environnement, reconnaître les traces laissées derrière soi et déceler ce que le désert cherche à dissimule",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_profileicon_thedancer",
    id = "moon_danseuse_du_val_razkah",
    label = "Moon - Danseuse du Val'Razkah",
    tags = "Commun",
}, "bc6cd1b3cab98d2c")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        cosmique = 1,
        investigation = 1,
        vue = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Dès leur plus jeune âge, les fées apprennent à écouter et à ressentir le monde qui les entoure. Elles sont donc plus enclines à détecter des fluctuations de magie.\n\nUne perception légèrement accrue de la magie. Capacité à dire si un objet, une personne ou un lieu est magique ou non. Si la nature de la magie est familière au personnage, il peut mieux la cerner. Sinon, c'est juste magique.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_rk_yasuo_eyeofthewind",
    id = "perception_feerique",
    label = "Perception féérique",
    tags = "Commun",
}, "4e58dd1b9e250887")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        investigation = "1",
        ouie = "1",
        vue = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Son regard va au-delà de ce que tout le monde voit. Il repère le détail qui cloche dans un paysage : un sol trop lisse pour être naturel, un silence inhabituel, une trace qui mène à une embuscade. Cet œil aiguisé lui permet de tracer des cartes fiables, et de rester en vie pour les vendre.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\inv_misc_pignosemask_a_01",
    id = "perspicace",
    label = "Perspicace",
    tags = "Commun",
}, "9a919df177da771b")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        depl_nage = "-1",
        initiative = "1",
        investigation = "1",
        pen_tranchant = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Il ne cherche ni la gloire ni les grandes causes, seulement ce qui fonctionne. Il évite un danger quand il le peut, et sait jouer du fer quand il n'a pas d'autre choix. Pour lui, un combat n'est qu'un moyen de poursuivre sa route, jamais une fin.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_akshan_goingrogue",
    id = "pragmatique",
    label = "Pragmatique",
    tags = "Commun",
}, "70a8cfb25a16a42f")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        crochetage = "1",
        deguisement = "1",
        evasion = "1",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "Être prise en otage une fois aurait déjà pu être considéré comme un manque de chance. Lorsque cela devient une habitude, il faut bien finir par s'adapter.\n\nÀ force de captivités, elle apprit à devenir quelqu'un d'autre lorsque la situation l'exigeait, à tromper ses geôliers par la parole comme par les apparences et, surtout, à préparer méthodiquement sa sortie. Serrures, entraves et chaînes cessèrent peu à peu d'être des obstacles insurmontables.\n\nAprès suffisamment de tentatives, elle finit par",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_rk_illaoi_testofspirit",
    id = "quelle_vie_de_merde",
    label = "Moon - Quelle vie de merde... !",
    tags = "Commun",
}, "963aa1c8fc25ebba")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        discretion = 1,
        escalade = 2,
    },
    couleurTitre = "FF8CB8",
    description = "La magie des fées imprègne le sang de ces dernières, conférant à leur corps une légèreté significative leur permettant de voler avec plus d'efficacité.\n\nLors de la marche, permet de laisser moins de traces au sol.\nEscalade facilitée.\nEn revanche, plus de difficulté à résister à de violentes bourrasques ou à repoussement.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\9xp_sigil_ardenweald01",
    id = "sang_feerique",
    label = "Sang féérique",
    tags = "Commun",
}, "21cb8aeeb5fc724e")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        meca_dissipation = 1,
        meca_soin = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Archibald peut soigner les blessures et affections des animaux avec le matériel disponible. Il peut stabiliser une créature mourante et lui permettre de récupérer progressivement. Faire la même chose sur un allier ? Après tout nous sommes aussi des animaux.\n\n- Utilisation de la médecine vétérinaire pour soigner les alliers.\n- Stabiliser une créature.\n- Traiter les affections.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\hots_ltmorales_healingbeam",
    id = "veterinaire_de_terrain",
    label = "Vétérinaire de terrain",
    tags = "Commun",
}, "b5c01c1979d7b926")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        acrobaties = "1",
        meca_buff = "3",
        meca_soin = "-2",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "Il ne suffit guère de savoir se façonner soi-même lorsque le monde qui nous entoure persiste à suivre sa propre mélodie. Reika dispose d'une attention particulière; qui, a l'image d'un instrument que l'on accorde, lui offre la mesure des subtilités qui composent l'équilibre d'un individu et d'y apporter quelques ajustements.\n\nUn mouvement, une respiration, une circulation magique ou le moindre déséquilibre deviennent autant d'occasions d'intervenir pour elle. Tantôt pour accompagner ses alliés,",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_item_puppeteer",
    id = "violoniste_de_la_marionnette",
    label = "Violoniste de la marionnette.",
    tags = "Commun",
}, "9164a14635e4bc90")
