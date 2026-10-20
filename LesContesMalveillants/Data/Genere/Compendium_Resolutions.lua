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

-- ===== Systeme-Résolution-Action =====

-- ===== Actions-MJ =====

-- ===== Calculateur =====
LCM.Calculateurs.Add({
    id = "degats_attaque",
    label = "Dégâts Attaque",
    icone = "Interface\\ICONS\\ability_warrior_savageblow",
    injections = {
        {
            description = "Source : dégâts arme + stat choisie (Force / Perception / Mystique)",
            nom = "source",
        },
        {
            description = "Pénétrations : moyenne des types sélectionnés (0 si aucun)",
            nom = "pen",
        },
        {
            description = "Multiplicateur : Normal Multi (R3) ou Critique Multi (R4)",
            nom = "mult",
        },
    },
    lignes = {
        {
            id = "l_src",
            label = "Source (arme + stat)",
            op = "valeur",
            operands = {
                {
                    kind = "injection",
                    label = "",
                    ref = "source",
                    value = "",
                },
            },
            sortie = false,
            subOp = "moyenne",
        },
        {
            id = "l_pen",
            label = "Pénétrations (moyenne)",
            op = "valeur",
            operands = {
                {
                    kind = "injection",
                    label = "",
                    ref = "pen",
                    value = "",
                },
            },
            sortie = false,
            subOp = "moyenne",
        },
        {
            id = "l_base",
            label = "Base = Source + Pénétrations",
            op = "somme",
            operands = {
                {
                    kind = "ligne",
                    label = "",
                    ref = "l_src",
                    value = "",
                },
                {
                    kind = "ligne",
                    label = "",
                    ref = "l_pen",
                    value = "",
                },
            },
            sortie = false,
            subOp = "moyenne",
        },
        {
            id = "l_tot",
            label = "Total",
            op = "produit",
            operands = {
                {
                    kind = "ligne",
                    label = "",
                    ref = "l_base",
                    value = "",
                },
                {
                    kind = "injection",
                    label = "",
                    ref = "mult",
                    value = "",
                },
            },
            sortie = true,
            subOp = "moyenne",
        },
    },
})
LCM.Calculateurs.Add({
    id = "reduction_defense",
    label = "Réduction Défense",
    icone = "Interface\\ICONS\\inv_shield_04",
    injections = {
        {
            description = "Dégâts reçus (Total Normal ou Critique)",
            nom = "degats",
        },
    },
    lignes = {
        {
            id = "cl_type",
            label = "Réduction Type",
            op = "moyenne",
            operands = {
                {
                    kind = "recu",
                    label = "",
                    ref = "Type Physique",
                    value = "",
                },
                {
                    kind = "recu",
                    label = "",
                    ref = "Type Elementaire",
                    value = "",
                },
                {
                    kind = "recu",
                    label = "",
                    ref = "Type Cosmologie",
                    value = "",
                },
            },
            sortie = false,
            subOp = "moyenne",
        },
        {
            id = "cl_constit",
            label = "Réduction Constitution",
            op = "valeur",
            operands = {
                {
                    kind = "expr",
                    label = "",
                    ref = "",
                    value = "[[0.inventory.window_custom_1::ficheContainer_window_custom_1_field_39::cell_6::6.value]] * [[0.fiche.window_custom_7::custom_11::field_226.value]] * (stat:Base défense + stat:Défense par point * [[0.fiche.window_custom_20::fiche::field_2.row:défense_constitution]]) / 100",
                },
            },
            sortie = false,
            subOp = "moyenne",
        },
        {
            id = "cl_net",
            label = "Dégât net",
            op = "soustraction",
            operands = {
                {
                    kind = "injection",
                    label = "",
                    ref = "degats",
                    value = "",
                },
                {
                    kind = "ligne",
                    label = "",
                    ref = "cl_type",
                    value = "",
                },
                {
                    kind = "ligne",
                    label = "",
                    ref = "cl_constit",
                    value = "",
                },
            },
            sortie = false,
            subOp = "moyenne",
        },
        {
            id = "cl_final",
            label = "Total",
            op = "arrondi",
            operands = {
                {
                    kind = "ligne",
                    label = "",
                    ref = "cl_net",
                    value = "",
                },
            },
            sortie = true,
            subOp = "moyenne",
        },
    },
})
