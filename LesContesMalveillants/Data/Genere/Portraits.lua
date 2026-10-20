-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Convertir les portraits » a partir des images deposees
--  dans LesContesMalveillants\Portraits. Toute retouche manuelle sera perdue
--  au prochain export.
--
--  Pour ajouter un portrait : deposer l'image (png / jpg), relancer l'outil,
--  publier. Les joueurs le voient a la mise a jour suivante.
-- ============================================================================

local _, LCM = ...
local Portraits = LCM.Portraits

Portraits.Add({ id = "aiwe", label = "Aiwe" })
Portraits.Add({ id = "archibald", label = "Archibald" })
Portraits.Add({ id = "iridia", label = "Iridia" })
Portraits.Add({ id = "moon", label = "Moon" })
Portraits.Add({ id = "petersen", label = "Petersen" })
Portraits.Add({ id = "reikashira", label = "ReikaShira" })
Portraits.Add({ id = "svallesansnom", label = "SvalLeSansNom" })

-- Repli : affichee quand un personnage n'a pas encore son artwork.
Portraits.SetSilhouette("silhouette.tga")
