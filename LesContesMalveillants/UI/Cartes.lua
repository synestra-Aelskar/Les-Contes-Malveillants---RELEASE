-- Lire une carte (Core/Cartes.lua) : depuis l'inventaire, « Lire la carte ».
--
-- La lecture apprend les noms pour de bon, puis montre la carte dans la
-- fenetre de la carte des regions de Crossings, en mode « carte lue » : la
-- region, ses seuls lieux devoiles, et les reperes. Relire la rouvre.
local _, LCM = ...
local UI = LCM.UI
local Ecran = {}
UI.Cartes = Ecran

-- `ref` : « cartes/<id> ». Rend true, ou false et la raison. `definition` :
-- une carte lue sans la posseder (sur un panneau d'affichage).
function Ecran.Ouvrir(ref, definition)
    local vue, appris = LCM.Cartes.Lire(ref, definition)
    if not vue then
        LCM.Alerte("Carte illisible : " .. tostring(appris))
        return false, appris
    end
    if #appris > 0 then
        LCM.Ok("Vous apprenez : " .. table.concat(appris, ", ") .. ".")
    end
    local ZG = LCM.Crossings
    if ZG and ZG.ShowCarteLue then ZG:ShowCarteLue(vue) end
    return true
end

-- L'apercu de l'editeur : la meme vue, sans rien apprendre a personne.
function Ecran.Apercu(definition)
    local vue, raison = LCM.Cartes.Vue(nil, definition)
    if not vue then return false, raison end
    local ZG = LCM.Crossings
    if ZG and ZG.ShowCarteLue then ZG:ShowCarteLue(vue) end
    return true
end
