-- Un outil de depart, sans bonus de fiche. Sa possession est celle des sacs
-- de l'addon ; l'equiper passe par Core/Objets comme les autres objets.
--
-- Il n'y a plus d'objet « Lanterne » ici (23 octobre 2026) : une lanterne est
-- une entree de la categorie Lanternes du compendium, creee par le MJ, et elle
-- n'existe pour le joueur que s'il en possede une (Core/Lanternes.lua).
local _, LCM = ...

LCM.Publier(LCM.Objets, { id = "outil_scanner_valrazkah", label = "Scanner à haute fréquence",
    categorie = "outil", description = "Détecte les puits de tonnerre du Val'Razkah." })
