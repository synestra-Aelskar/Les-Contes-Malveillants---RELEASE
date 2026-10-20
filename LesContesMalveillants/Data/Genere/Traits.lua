-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Exporter les brouillons » a partir de ce que le MJ a
--  cree en jeu. Toute retouche manuelle sera perdue au prochain export.
--
--  Pour changer une entree : la corriger en jeu, puis reexporter.
-- ============================================================================

local _, LCM = ...
local Traits = LCM.Traits

Traits.Add({
    id = "escalade_jungle",
    label = "Escalade de la jungle",
    description = "Habitue aux parois vegetales et aux lianes : +3 en escalade, "
        .. "et relance du jet quand le decor s'y prete.",
    cout = 2,
    bonus = { escalade = 3 },
    avantage = { "escalade" },
})
