-- Apprentissages : ce qu'un personnage a etudie (fenetre Apprentissage du
-- template, 60 emplacements). Le template : « Etude de l'acrobatie : Base
-- Volume 1 », Acrobaties +1.
--
-- Un catalogue (Core/Catalogues.lua) a une seule categorie.

local _, LCM = ...

LCM.Apprentissages = LCM.Catalogue({
    nom = "apprentissage", prefixe = "Apprentissages", cleEntite = "apprentissages", primaires = true,
    categories = {
        { id = "apprentissage", label = "Apprentissage", onglet = "Fiche", bloc = "Emplacement" },
    },
})
