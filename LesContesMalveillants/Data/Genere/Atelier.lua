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

-- ----- devises (1) -------------------------------------------------
LCM.PublierPublique(LCM.Devises, "devises", {
    description = "Une monnai somme tout relativement banale.",
    icone = "Interface\\ICONS\\eps_plunder_misc_pieceofeight",
    id = "ecus",
    label = "Écus",
    materiel = true,
}, "f4e54a717e552624")

-- ----- etats (1) ---------------------------------------------------
LCM.PublierPublique(LCM.Etats, "etats", {
    bonus = {
        acrobaties = -1,
        communication = -1,
        cosmique = -1,
        elementaire = -1,
        equilibre = -1,
        escalade = -1,
        esprit = -2,
        force = -1,
        investigation = -1,
        odorat_gout = -1,
        ouie = -1,
        perception = -1,
        pistage = -1,
        resi_contondant = -2,
        toucher = -1,
        vue = -1,
    },
    categorie = "etat",
    couleurTitre = "4DE04D",
    description = "<Vous avez vraiment très mal au crâne.>",
    forge = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8/inhabituel",
    icone = "Interface\\ICONS\\inv_misc_bone_humanskull_02",
    id = "lcm_64a651_6acd8c83_0ff8950c_0001_18d910",
    label = "Commossion Cérébrale.",
    tags = "Inhabituel",
}, "0f159fc2b5e33cbc")

-- ----- listes (33) --------------------------------------------------
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
    icone = "Interface\\ICONS\\inv_inscription_inkblack02",
    id = "lcm_64a651_6ad69189_2038de7c_0003_65dfb5",
    label = "Encre",
    liste = "ressources",
}, "0b3d0fe7f740b096")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_misc_paperbundle02a",
    id = "lcm_64a651_6ad691c0_2039b590_0004_033a49",
    label = "Papier",
    liste = "ressources",
}, "8c045bfe277b4260")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_misc_food_159_fish_82",
    id = "lcm_64a651_6ad6933b_203f7d7a_0006_c0e4d5",
    label = "Nourriture",
    liste = "ressources",
}, "f22f52e4259c92c1")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_misc_bandage_01",
    id = "lcm_64a651_6ad6939e_2040ff8f_0007_cd304f",
    label = "Bandage",
    liste = "ressources",
}, "5ab085a1b79597c2")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\w3reforgedbronzebowlfull",
    id = "lcm_64a651_6ad69431_20433b69_0002_621c6d",
    label = "Baume",
    liste = "ressources",
}, "e0daae5e97045f45")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\eps_arc_book_blacksmith1",
    id = "lcm_64a651_6ad6963b_204b33a4_0007_f08a79",
    label = "Livre",
    liste = "ressources",
}, "797b0bb2ff6702a3")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\hots_thebutcher_furnaceblast_fire",
    id = "lcm_64a651_6ad698cf_205548ef_000f_056abe",
    label = "Chaleur",
    liste = "outils",
}, "ea3a1917d057f25e")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\inv_drink_07",
    id = "lcm_64a651_6ad69a7f_205bdff2_0013_e59c87",
    label = "Boisson",
    liste = "ressources",
}, "92d2aba8fcae8abb")

LCM.PublierPublique(LCM.Listes, "listes", {
    icone = "Interface\\ICONS\\eps_rumble_powercrystalgreen",
    id = "lcm_64a651_6ad6a260_207aa4a3_0021_04ec5d",
    label = "Cristal",
    liste = "ressources",
}, "433bd8608bbbc684")

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
    dos = {
        texte = "",
        titre = "",
    },
    format = "livre",
    icone = "Interface\\ICONS\\eps_bg3_itemkethericbook",
    id = "lcm_64a651_6ad4cd18_19518f43_0002_ea9d76",
    label = "Ouvrage humide.",
    pages = {
        {
            texte = "[Une large partie de l'ouvrage est vétuste.. rongé par l'humidité, et le temps.. Entre deux pages.. Vous trouvez éventuellement quelques insectes..]\n\nCette page semble contenir des annotations ressemblant à des cercles runiques.. Hélas, l'encre n'a guère survécu à l'humidité des lieux....\n\n{img:Interface\\Garrison\\ShadowlandsMissionLandingPageBackgroundNightFae:256:256:c}\n\n\n\n\n",
            titre = "",
        },
        {
            texte = "",
            titre = "",
        },
    },
    style = {
        accent = "C5A265",
        alignement = "LEFT",
        encre = "E9DDBF",
        fond = "202735",
    },
}, "d88971ed8d877a7a")

-- ----- objets (45) --------------------------------------------------
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
    avantage = {  },
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        force_brise_armure = 2,
        meca_buff = 1,
        meca_soin = 1,
        mystique_brise_armure = 2,
        perception_brise_armure = 2,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Ce bâton, réalisé à partir du bois de la forêt d'Elestria, a pour principale fonction d'aider un randonneur à se déplacer sous ces frondaisons. Il est orné de l'emblème de la Garde et permet à son porteur de se défendre en cas de problème.\n\nArme à deux mains, au corps à corps.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_staff_17",
    id = "baton_forestier",
    label = "Bâton forestier",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
    type = "baton",
}, "4526a35f0e9f9193")

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
        resi_contondant = 3,
        resi_feu = 3,
        resi_lumiere = 8,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Des renforts de metal pour une armure de géolier nhin. Elles semblent enchantée.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_armor_bastioncosmetic_d_01",
    id = "lcm_64a651_6aced3c9_01fbe20c_000b_ffef6c",
    label = "Renfort de géolier du culte pour nhin.",
    tags = "Rare",
    type = "bottes",
}, "00d67b2a42d6e637")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        def_defense = 1,
        def_mental = 1,
        resi_contondant = 3,
        resi_feu = 3,
        resi_lumiere = 8,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Des renforts de metal pour une armure de géolier nhin. Elles semblent enchantée.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_armor_bastioncosmetic_d_01",
    id = "lcm_64a651_6aced474_01fe7f4a_000e_7cd315",
    label = "Renfort de géolier du culte pour nhin. (copie)",
    tags = "Rare",
    type = "plaque_de_corps",
}, "d9e171116f096a30")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        def_defense = 1,
        def_mental = 1,
        resi_contondant = 3,
        resi_feu = 3,
        resi_lumiere = 8,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Des renforts de metal pour une armure de géolier nhin. Elles semblent enchantée.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_armor_bastioncosmetic_d_01",
    id = "lcm_64a651_6aced481_01feb200_0011_feea8d",
    label = "Renfort de géolier du culte pour nhin. (copie) (copie)",
    tags = "Rare",
    type = "plastron",
}, "cf2e283b939a1552")

LCM.PublierPublique(LCM.Objets, "objets", {
    armure = 2,
    avantage = {  },
    bonus = {
        def_defense = 1,
        def_mental = 1,
        resi_contondant = 3,
        resi_feu = 3,
        resi_lumiere = 8,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Des renforts de metal pour une armure de géolier nhin. Elles semblent enchantée.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_armor_bastioncosmetic_d_01",
    id = "lcm_64a651_6aced4d3_01fff30d_001f_3216c5",
    label = "Renfort de géolier du culte pour nhin. (copie) (copie) (copie)",
    tags = "Rare",
    type = "jambiere",
}, "6bcdc6a2694fda00")

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

-- ----- races (8) ---------------------------------------------------
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

-- ----- ressources (12) ----------------------------------------------
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
    description = "Une feuille de papier de mauvaise qualité.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_paperbundle02a",
    id = "lcm_64a651_6ad6917e_2038b154_0002_0495e5",
    label = "Papier de mauvaise qualité.",
    tags = "Commun",
    type = "lcm_64a651_6ad65bc0_1f66c19c_0004_cdf550",
}, "1c7507b67237f09d")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    avantage = {  },
    couleurTitre = "FF8CB8",
    description = "Une bande de tissu grossièrement découpée, aux fibres rêches et effilochées. Peu hygiénique, mais suffisante pour couvrir une plaie.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_bandage_03",
    id = "lcm_64a651_6ad691e4_203a41c9_0005_edf1c8",
    label = "Bandage de piètre qualité.",
    tags = "Commun",
    type = "lcm_64a651_6ad6939e_2040ff8f_0007_cd304f",
}, "73d07d2d8da78b79")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un maigre assortiment de viande séchée, de biscuits durcis et de quelques fruits secs. De quoi tromper la faim durant une journée.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_paperpackage01b",
    id = "lcm_64a651_6ad693b8_204164db_0008_1cbf44",
    label = "Petite ration de voyage",
    tags = "Commun",
    type = "lcm_64a651_6ad6933b_203f7d7a_0006_c0e4d5",
}, "383074e500dd16a7")

LCM.PublierPublique(LCM.Ressources, "ressources", {
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "Un onguent épais à l'odeur âcre, conservé dans un petit pot de terre cuite. Appliqué sur la peau, il apaise les morsures du froid et soulage les engelures superficielles.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\w3reforgedhealingsalve",
    id = "lcm_64a651_6ad693f0_20423093_0001_2f767b",
    label = "Onguent anti-engelures",
    tags = "Commun",
    type = "lcm_64a651_6ad69431_20433b69_0002_621c6d",
}, "fe4f85c7d5c967e6")

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
    bonus = {  },
    couleurTitre = "FF8CB8",
    description = "A première vue.. Cette gourde ne semble avoir rien de particulier.. Pourtant, vous discerner dans le fond de l'eau qu'elle contient une rune luissant d'une couleur solaire.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_drink_18",
    id = "lcm_64a651_6ad699e3_20597cb9_0012_35135e",
    label = "Gourde d'eau runique",
    tags = "Commun",
    type = "lcm_64a651_6ad69a7f_205bdff2_0013_e59c87",
}, "6fb3386752ea25cd")

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
    couleurTitre = "FF8CB8",
    description = "Un cristal d'aspecta rafiné. Allez savoir à quoi cela sert. En revanche, il dégage une lueur verte appaisante.",
    forge = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c/commun",
    icone = "Interface\\ICONS\\inv_misc_uncutgemsuperior2",
    id = "lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
    label = "Cristal d'aspecta rafiné",
    tags = "Commun",
    type = "lcm_64a651_6ad6a260_207aa4a3_0021_04ec5d",
}, "3f4a22f33369f585")

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

-- ----- tentes (3) --------------------------------------------------
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

-- ----- traits (37) --------------------------------------------------
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
        crochetage = 1,
        discretion = 1,
        vol_a_la_tire = 1,
    },
    couleurTitre = "FF8CB8",
    description = "L'arc et le jeu de scène suffisent assez rarement aux fins de mois. Alors, autrefois, elle se glissait avec quelques copains dans de riches baraques pour en voler les biens. Elle sait se faire discrète, se fondre dans les ombres, - dans une certaine mesure. Crocheter des verrous assez complexes, se faire morte quand le prédateur pointe le bout de son nez. Il est assez connu que Maia volait \"au-delà\" de ses besoins primaires. Elle aime l'argent comme l'orphelin aime la chaleur du feu. Parce qu'el",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_stealth",
    id = "cambrioleuse",
    label = "Cambrioleuse",
    tags = "Commun",
}, "3d16c290eaf5a166")

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
    bonus = {
        investigation = 1,
        resi_feu = 4,
    },
    couleurTitre = "FF8CB8",
    description = "Son séjour dans les mondes démoniaques l’ont rendu très résiliente face aux flammes et lui confère un savoir important sur les engeances démoniaques.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\sha_spell_warlock_demonsoul_nightmare",
    id = "lcm_64a651_6acab9e6_04f1ed9d_0001_b03c06",
    label = "Chevalier Infernal",
    tags = "Commun",
}, "8398c8ccdfb17081")

LCM.PublierPublique(LCM.Traits, "traits", {
    bonus = {
        endurance = 1,
        fatigue = 2,
        puissance = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Les chairs tordus de l’elfe lui confère une force démentielle bien plus que l’on pourrait en attendre d’une elfe de sa carrure, sans compter une résilience particulièrement notable.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_demonhunter_consumemagic",
    id = "lcm_64a651_6acabb9f_04f8b719_0002_c63df8",
    label = "Force Xorothienne",
    tags = "Commun",
}, "b6aec4cdd69dbd31")

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
        meca_perce_armure = "1",
        meca_soin = "1",
        mystique_soin = "2",
    },
    couleurTitre = "FF8CB8",
    description = "Prise sous le voile d'une mystérieuse femme, elle apprit à exploiter ses dons avec bien davantage de précision. On lui enseigna autant à préserver sa propre existence qu'à mettre rapidement un terme à celle de ses adversaires.\n\nElle sait reconnaître ce qui maintient un corps en vie, refermer certaines blessures lorsque personne d'autre ne peut le faire, mais également identifier les faiblesses d'une protection ou d'une anatomie afin de frapper là où cela fera réellement la différence.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\inv_crystallized_life",
    id = "moon_engeance_de_n",
    label = "Moon - Engeance de N'",
    tags = "Commun",
}, "ae3ad7c9cd8455f9")

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
