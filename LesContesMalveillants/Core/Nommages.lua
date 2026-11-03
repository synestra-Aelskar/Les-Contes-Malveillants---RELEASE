-- Les NOMMAGES : l'echelle des paliers du jeu, de bas en haut (le MJ,
-- 2 novembre 2026). Elle nomme les DIFFICULTES et les lignes de la grille
-- d'XP. Les couleurs des metiers n'en dependent plus (3 novembre 2026) : ce
-- sont les sept couleurs de base de Equilibrage.metiers.paliers.
--
-- C'est de l'EQUILIBRAGE, pas du contenu : Data/Equilibrage.lua (E.nommages)
-- donne l'echelle de depart, et le MJ la regle en seance par les reglages
-- (Core/Reglages.lua), comme les difficultes — diffusee au groupe, exportee.
--   nommages.<n>.nom       le nom du palier n (texte)
--   nommages.<n>.couleur   sa couleur, six chiffres hexadecimaux (texte)
--   nommages.nombre        combien de paliers (sans lui : ceux du fichier)
-- La premiere version les rangeait en contenu (liste « paliers ») ; le MJ les
-- voulait hors du compendium. Ce qui en reste est repris une fois en reglages
-- puis supprime (MJ/Panneau.lua, Nommages.Reprendre).
--
-- Un palier : { id, rang, nom, couleur = { r, g, b }, hex }. `rang` est sa
-- place, de 1 en bas ; la liste suit les numeros (9 avant 10).

local _, LCM = ...

local Nommages = {}
LCM.Nommages = Nommages

local function Rgb(hex)
    hex = tostring(hex or ""):gsub("^#", "")
    if not hex:match("^%x%x%x%x%x%x$") then return { 1, 1, 1 } end
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end
Nommages.Rgb = Rgb

function Nommages.Hex(couleur)
    if type(couleur) ~= "table" then return "FFFFFF" end
    return string.format("%02X%02X%02X", math.floor((couleur[1] or 1) * 255 + 0.5),
        math.floor((couleur[2] or 1) * 255 + 0.5), math.floor((couleur[3] or 1) * 255 + 0.5))
end

local function Table() return LCM.Equilibrage and LCM.Equilibrage.nommages or {} end

-- Un palier ajoute en seance arrive par le chemin d'un reglage, sa cle en
-- texte (« 8 ») ; un palier du fichier a une cle nombre. On lit les deux.
local function Brut(rang)
    local t = Table()
    return t[rang] or t[tostring(rang)]
end

function Nommages.Nombre()
    local t = Table()
    local n = tonumber(t.nombre)
    if n then return math.max(0, math.floor(n)) end
    return #t
end

function Nommages.Chemin(rang, cle)
    return string.format("nommages.%d.%s", tonumber(rang) or 0, tostring(cle))
end

function Nommages.Liste()
    local out = {}
    for rang = 1, Nommages.Nombre() do
        local b = Brut(rang) or {}
        local hex = tostring(b.couleur or "CCCCCC"):gsub("^#", ""):upper()
        out[#out + 1] = { id = "palier_" .. rang, rang = rang,
            nom = tostring(b.nom or ("Palier " .. rang)), hex = hex, couleur = Rgb(hex) }
    end
    return out
end

function Nommages.Get(rang)
    rang = tonumber(rang)
    if not rang or rang < 1 or rang > Nommages.Nombre() then return nil end
    return Nommages.Liste()[rang]
end

-- Le MJ a-t-il touche a l'echelle (une surcharge en cours) ?
function Nommages.Reglee()
    for chemin in pairs(LCM.Reglages and LCM.Reglages.Surcharges() or {}) do
        if tostring(chemin):match("^nommages%.") then return true end
    end
    return false
end
