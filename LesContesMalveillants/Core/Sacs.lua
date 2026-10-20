-- Sacs : les conteneurs de l'inventaire (fenetre Inventaires du template,
-- categorie « Sacs »). Un sac a un nombre de places, et des places pour les
-- devises (compendium : « Gros sac », 12 places ; « Sac de gros », 25).
--
-- Un catalogue (Core/Catalogues.lua) sans effets : un sac ne donne rien, il
-- contient. Ce fichier ne pose que les DEFINITIONS des sacs ; ou une entite
-- les range, et ce qu'elle met dedans, c'est l'inventaire (Core/Inventaire.lua).

local _, LCM = ...

-- Ce qu'un sac est : « sac » ou « sacoche ». On ne devine pas — une entree
-- sans nature est un sac, parce que c'est ce qu'etaient tous les sacs avant
-- que la distinction existe (3 octobre 2026).
-- « ceinture » (13 octobre 2026) : ne se porte que sur l'emplacement
-- Ceinture, et ajoute ses places aux cases de base de celle-ci.
local NATURES = { sac = true, sacoche = true, ceinture = true }

LCM.Sacs = LCM.Catalogue({
    nom = "sac", prefixe = "Sacs", cleEntite = "sacs", doublons = true,
    categories = {
        { id = "sac", label = "Sac", onglet = "Sacs", bloc = "Sacs", capacite = "sacs" },
    },
    champs = {
        -- Sac ou sacoche. Un sac ne s'equipe que dans un emplacement de sac ;
        -- une sacoche va dans les deux. Et seul un SAC peut en contenir un
        -- autre : voir Core/Inventaire.lua.
        { cle = "nature", libelle = "nature (sac, sacoche ou ceinture)", genre = "choix",
          valeurs = NATURES, defaut = "sac" },
        { cle = "places", libelle = "nombre de places", min = 1, defaut = 12 },
        { cle = "placesDevise", libelle = "places de devise", min = 0, defaut = 0 },
        -- « Sac maitre du jeu » du template (case de l'onglet General).
        { cle = "sacMJ", libelle = "sac du maitre du jeu", genre = "case" },
    },
})

-- La nature d'un sac, toujours l'une des deux.
function LCM.Sacs.Nature(sac)
    if type(sac) == "string" then sac = LCM.Sacs.Get(sac) end
    local nature = sac and tostring(sac.nature or "")
    return NATURES[nature] and nature or "sac"
end

function LCM.Sacs.EstSacoche(sac) return LCM.Sacs.Nature(sac) == "sacoche" end
function LCM.Sacs.EstCeinture(sac) return LCM.Sacs.Nature(sac) == "ceinture" end

-- Ce qu'il coute DANS un autre sac : sa case, plus toutes les siennes.
-- Un sac de 10 places occupe 11 cases dans celui qui le porte.
function LCM.Sacs.Encombrement(sac)
    if type(sac) == "string" then sac = LCM.Sacs.Get(sac) end
    if not sac then return 0 end
    return 1 + math.max(0, math.floor(tonumber(sac.places) or 0))
        + math.max(0, math.floor(tonumber(sac.placesDevise) or 0))
end
