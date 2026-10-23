-- Les onglets de la fenetre Inventaires, figes (template : inventoryWindows ›
-- window_custom_10). Leur nombre d'emplacements est dans
-- Equilibrage.inventaire ; leur vue de depart, celle du template.

local _, LCM = ...
local Inventaire = LCM.Inventaire

Inventaire.Categorie({ id = "sacs",      label = "Sacs",      vue = "grille", contient = "sac" })
Inventaire.Categorie({ id = "saccoches", label = "Saccoches", vue = "grille", contient = "sac" })
-- La ceinture (13 octobre 2026, hors template) : jamais vide, elle a ses
-- cases de base (Equilibrage.inventaire.placesCeinture) ; une entree « Sacs »
-- de nature ceinture se pose par-dessus et en ajoute. Voir Core/Inventaire.lua.
Inventaire.Categorie({ id = "ceintures", label = "Ceintures", vue = "grille", contient = "sac", ceinture = true })
-- « Cristaux en cours d'usage » (le MJ, 23 octobre 2026, hors template) : la
-- poche des cristaux entames, chacun avec sa charge. Toujours la, sans limite.
-- Voir Core/Inventaire.lua (POCHE) et Core/Lanternes.lua.
Inventaire.Categorie({ id = "cristaux_usage", label = "Cristaux en cours d'usage", vue = "liste", contient = "sac",
    cristaux = true })
-- L'onglet « Devises » du template a ete retire le 1er octobre 2026 : il n'avait
-- qu'un emplacement, donc il ne pouvait pas tenir la monnaie d'un personnage.
-- C'est la Bourse (Core/Bourse.lua) qui s'en charge. Les cases de devise DANS
-- un sac, elles, restent : c'est autre chose.
