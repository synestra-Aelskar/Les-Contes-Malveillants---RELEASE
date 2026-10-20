-- Les sacs livres avec l'addon.
--
-- Le reste du contenu vient du compendium, publie depuis l'atelier du MJ. Ces
-- entrees-la font exception : un personnage tout neuf doit pouvoir porter
-- quelque chose des sa premiere seance, sans attendre que le MJ lui donne un
-- sac. C'est l'equivalent du sac de depart d'un personnage de jeu.

local _, LCM = ...

-- La sacoche de depart : cinq places, et elle ne s'empile pas (on n'a pas
-- « trois sacoches de depart » dans une case).
LCM.Sacs.Add({
    id = "sacoche_de_depart",
    label = "Sacoche",
    nature = "sacoche",
    places = 5,
    placesDevise = 0,
    pileMax = 1,
    icone = "Interface\\ICONS\\inv_misc_bag_09",
    description = "La sacoche qu'on a toujours eue.",
})
