-- Etats : ce qui affecte un personnage — etats divers, maladies, etats
-- intangibles (les trois conteneurs de la fenetre Sante du template).
--
-- Un catalogue (Core/Catalogues.lua) : chaque etat a son icone, sa
-- description et ses effets (le template : « Infection de sang », Force -10).
-- Un etat peut toucher une primaire, en bien comme en mal.

local _, LCM = ...

-- La liste peut arriver apres l'etat (partage, chargement de la base).
-- Resoudre aussi au moment de la pose ; sans type connu, conserver le
-- classement historique plutot que de deplacer les anciens etats.
local function Conteneur(definition)
    local entree = definition and definition.type and LCM.Listes.Get(definition.type)
    if entree and entree.liste == "type_etats" then return entree.conteneur end
    return definition and definition.categorie or "etat"
end

LCM.Etats = LCM.Catalogue({
    nom = "etat", prefixe = "Etats", cleEntite = "etats", primaires = true,
    categorieDe = Conteneur,
    categories = {
        { id = "etat",       label = "État",             onglet = "États",      bloc = "États divers" },
        { id = "maladie",    label = "Maladie",          onglet = "Maladies",   bloc = "États de maladies" },
        { id = "intangible", label = "État intangible",  onglet = "Intangible", bloc = "États intangibles" },
    },
})
LCM.Etats.Conteneur = Conteneur
