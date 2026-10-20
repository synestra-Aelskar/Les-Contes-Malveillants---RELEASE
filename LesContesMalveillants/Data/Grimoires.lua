-- Le grimoire personnel.
--
-- Celui que tout personnage possede d'office, en tete de son hub. Les autres
-- arrivent par le jeu : le MJ les donne, un objet trouve en apporte un.
--
-- Il est declare ici, en dur, et pas engendre par l'import : ce n'est pas du
-- contenu repris de Necronicon, c'est une piece du systeme.
--
-- Son contenu est vide pour l'instant. Y ecrire les sorts d'UN personnage
-- demanderait de stocker du contenu par entite — a decider avant de le faire,
-- parce que c'est la premiere fois qu'on ecrirait autre chose que des valeurs
-- dans la sauvegarde.

local _, LCM = ...

LCM.Grimoires.Add({
    id = "grimoire_personnel",
    label = "Mon grimoire",
    icone = "Interface\\ICONS\\inv_misc_book_09",
    description = "Tes propres actions. Le maitre du jeu y ajoute ce que tu apprends.",
    personnel = true,
    onglets = {
        { nom = "Sorts", sorts = {} },
    },
})
