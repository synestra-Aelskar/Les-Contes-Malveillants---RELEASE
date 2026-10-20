-- Portraits : les artworks des personnages.
--
-- WoW ne sait pas lire un PNG, et il ne lit que ce qui est DANS le dossier de
-- l'addon : une image ne peut donc pas voyager par le reseau, elle doit etre
-- livree avec la mise a jour. C'est exactement la chaine qu'on a deja pour le
-- contenu — les joueurs envoient leur artwork, l'outil le convertit en TGA et
-- reecrit `Data/Genere/Portraits.lua`, tout le monde met a jour avant la
-- seance. Un portrait qu'un joueur n'a pas encore recu s'affiche en repli,
-- jamais en carre noir.
--
-- Chaque portrait est decoupe a la meme proportion (2:3) par l'outil, donc les
-- coordonnees de texture sont les memes pour tous — elles restent declarables
-- au cas par cas pour une image qu'on voudrait cadrer autrement.

local _, LCM = ...

local Portraits = { list = {}, byId = {} }
LCM.Portraits = Portraits

-- La toile fait 256 x 512 (puissances de deux, exigence du moteur), l'image
-- occupe les 384 premiers pixels de hauteur : 384 / 512 = 0,75.
Portraits.COORDS = { 0, 1, 0, 0.75 }
Portraits.RATIO = 2 / 3

local DOSSIER = "Interface\\AddOns\\LesContesMalveillants\\ressources\\portraits\\"
Portraits.ICONE_DEFAUT = "Interface\\ICONS\\INV_Misc_Book_09"

-- La silhouette de repli, livree avec l'addon. Elle n'existe que si l'outil l'a
-- convertie : tant qu'elle n'est pas declaree, on retombe sur une icone, jamais
-- sur un chemin de texture absent (le moteur afficherait un carre vert).
function Portraits.SetSilhouette(fichier, coords)
    Portraits.silhouette = {
        texture = DOSSIER .. tostring(fichier),
        coords = coords or Portraits.COORDS,
    }
end

function Portraits.Add(definition)
    if type(definition) ~= "table" then return nil end
    local id = tostring(definition.id or "")
    if id == "" then return nil end
    local portrait = {
        id = id,
        label = tostring(definition.label or id),
        -- `fichier` suffit : le dossier est le meme pour tous.
        texture = definition.texture or (DOSSIER .. (definition.fichier or (id .. ".tga"))),
        coords = definition.coords or Portraits.COORDS,
        auteur = definition.auteur,
    }
    if Portraits.byId[id] then
        -- Un reexport remplace l'entree en place : l'ordre de la liste ne doit
        -- pas dependre du nombre de fois qu'on a exporte.
        for index, existant in ipairs(Portraits.list) do
            if existant.id == id then Portraits.list[index] = portrait end
        end
    else
        Portraits.list[#Portraits.list + 1] = portrait
    end
    Portraits.byId[id] = portrait
    return portrait
end

function Portraits.Get(id)
    return Portraits.byId[tostring(id or "")]
end

function Portraits.Count()
    return #Portraits.list
end

-- Le portrait d'une entite : celui qu'elle designe, sinon celui qui porte son
-- identifiant (convention pratique quand l'outil nomme les fichiers d'apres le
-- personnage), sinon rien.
function Portraits.Of(entity)
    if type(entity) ~= "table" then return nil end
    local choisi = tostring(LCM.Entities.Get_Value(entity, "portrait") or "")
    if choisi ~= "" then return Portraits.Get(choisi) end
    return Portraits.Get(entity.id)
end

-- Habille une texture et dit ce qu'elle porte : "portrait", "silhouette" ou
-- "icone". Les deux premiers remplissent la carte, le troisieme non — d'ou le
-- retour, plutot qu'un booleen qui aurait fini par mentir.
function Portraits.Appliquer(texture, entity)
    local portrait = Portraits.Of(entity)
    if portrait then
        texture:SetTexture(portrait.texture)
        texture:SetTexCoord(portrait.coords[1], portrait.coords[2], portrait.coords[3], portrait.coords[4])
        texture:SetVertexColor(1, 1, 1)
        return "portrait"
    end
    local silhouette = Portraits.silhouette
    if silhouette then
        texture:SetTexture(silhouette.texture)
        texture:SetTexCoord(silhouette.coords[1], silhouette.coords[2], silhouette.coords[3], silhouette.coords[4])
        -- Assombrie : elle dit « il manque une image », elle ne se fait pas
        -- passer pour l'artwork du personnage.
        texture:SetVertexColor(0.30, 0.28, 0.26)
        return "silhouette"
    end
    texture:SetTexture((type(entity) == "table" and entity.icon) or Portraits.ICONE_DEFAUT)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(0.55, 0.52, 0.48)
    return "icone"
end
