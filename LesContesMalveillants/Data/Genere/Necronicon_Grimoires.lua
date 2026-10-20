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
LCM.Grimoires.Add({
    id = "grimoire_sans_fenetre_window_custom_17",
    label = "Grimoire sans fenetre (window_custom_17)",
    description = "Catalogues d'actions simples via raccourcies.",
    onglets = {
        {
            nom = "Grimoire 1",
            sorts = {
                {
                    description = "Une coupe simple et efficace à l'aide de votre arme.",
                    icone = "Interface\\ICONS\\ability_rogue_sabreslash",
                    id = "coupe_tranchante",
                    jet = {
                        icone = "Interface\\ICONS\\ability_rogue_sabreslash",
                        max = "100",
                        min = "1",
                    },
                    label = "Coupe tranchante",
                    raccourci = "Coupe tranchante",
                },
                {
                    champ1 = "NC",
                    champ2 = "NC",
                    description = "NC",
                    id = "nc",
                    label = "NC",
                },
            },
        },
    },
})
LCM.Grimoires.Add({
    id = "grimoire_sans_fenetre_window_custom_15",
    label = "Grimoire sans fenetre (window_custom_15)",
    onglets = {
        {
            nom = "Grimoire 1",
            sorts = {
                {
                    id = "nc",
                    jet = {
                        icone = "Interface\\Icons\\INV_Misc_Dice_02",
                        max = "2",
                        min = "1",
                    },
                    label = "NC",
                },
            },
        },
    },
})
LCM.Grimoires.Add({
    id = "grimoire_sans_fenetre_window_custom_4",
    label = "Grimoire sans fenetre (window_custom_4)",
    onglets = {
        {
            nom = "Grimoire 1",
            sorts = {
                {
                    description = "Le personnage impacte un adversaire de sa paume de main, produisant une désagrégation rapide de la zone de contact,\n\nCompte comme une malédiction instantanée de Pourriture.",
                    icone = "Interface\\ICONS\\hd_darkhand_sha",
                    id = "impact_desagregeant",
                    jet = {
                        icone = "Interface\\Icons\\INV_Misc_Dice_02",
                        max = "100",
                        min = "1",
                        stat = "0.fiche.window_custom_1::fiche::inventory_fiche_38.statValue",
                    },
                    label = "Impact désagrégeant",
                    raccourci = "Impact désagr 3",
                },
            },
        },
    },
})
LCM.Grimoires.Add({
    id = "grimoire_test",
    label = "Grimoire test",
    description = "Héhéhé.",
    onglets = {
        {
            nom = "Magie du trololofire",
            sorts = {
                {
                    description = "Ceci est une compétence / spell. L'idée est que vous pouvez créer des spells, ou compétence, dans votre \"grimoire\" qui vont directement faire une \"action\" + une macro, un spell arcanum, ou du lua etc. \n\nConcrètement, ça permet de directement charger un preset, comme j'ai fais pour mon attaque que j'ai enregistré. Et en plus, d'en faire une compétence partageable, enseignable etc. (Plus de garder en mémoire des trucs cool de votre coté.) \n\nCe n'est PAS obligatoire.",
                    icone = "Interface\\ICONS\\spell_fire_fireball02",
                    id = "la_boule_de_feu_de_l_enfer",
                    label = "La boule de feu de l'enfer.",
                },
            },
        },
    },
})
