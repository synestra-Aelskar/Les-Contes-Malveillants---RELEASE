-- Les actions des boutons du lanceur radial, ecrites dans le code.
--
-- Jusqu'au 3 octobre 2026, un bouton (« Attaque », « Répulsion »...) citait une
-- entree du compendium (Systeme-Resolution-Action, Actions-MJ), importee de
-- Necronicon. Le bouton dependait donc d'une entree que n'importe quel MJ
-- pouvait dupliquer, modifier ou perdre a l'import suivant. Ici,
-- l'action APPARTIENT a son bouton : elle est definie avec lui, dans le code,
-- et n'est plus une entree du compendium.
--
-- Une action garde le format d'une resolution (feuilles et etapes, verifie
-- par LCM.Resolutions.Construire) et son identifiant d'avant : les jeux de
-- choix deja enregistres (« Coup rapide » sur attaque_composeur) restent les
-- siens.
--
--     LCM.ActionsBoutons.Definir("attaque_simple", { id = "attaque_composeur", ... })
--
-- Les actions du joueur : Data/ActionsBoutons.lua. Celles du MJ vivent dans le
-- compagnon (ActionsBoutons.lua) : chez un joueur, elles n'existent pas.
--
-- Les RECEPTIONS (Defense, Reception de soin...) suivent le meme chemin depuis
-- le 3 octobre 2026 (Data/Receptions.lua) : elles n'ont pas de bouton, c'est
-- la nature de l'action recue qui les designe (Actions.ResolutionPour).

local _, LCM = ...

local Boutons = { parBouton = {}, parId = {}, list = {} }
LCM.ActionsBoutons = Boutons

local function Erreur(message) error("LCM/ActionsBoutons : " .. tostring(message), 0) end

-- Une action par bouton, un identifiant par action : un doublon est une faute
-- d'ecriture, refusee au chargement.
function Boutons.Definir(boutonId, definition)
    boutonId = tostring(boutonId or "")
    if boutonId == "" then Erreur("action sans bouton") end
    if Boutons.parBouton[boutonId] then Erreur("deux actions pour le bouton " .. boutonId) end
    local action = LCM.Resolutions.Construire(definition)
    if Boutons.parId[action.id] or LCM.Resolutions.Get(action.id) then
        Erreur("identifiant deja pris : " .. action.id)
    end
    action.bouton = boutonId
    Boutons.parBouton[boutonId] = action
    Boutons.parId[action.id] = action
    Boutons.list[#Boutons.list + 1] = action
    return action
end

-- Une reception : pas de bouton, des natures auxquelles elle repond.
function Boutons.Reception(definition)
    local reception = LCM.Resolutions.Construire(definition)
    if reception.emission then Erreur(reception.id .. " : une reception n'emet pas") end
    if Boutons.parId[reception.id] or LCM.Resolutions.Get(reception.id) then
        Erreur("identifiant deja pris : " .. reception.id)
    end
    Boutons.parId[reception.id] = reception
    Boutons.list[#Boutons.list + 1] = reception
    return reception
end

function Boutons.DuBouton(boutonId) return Boutons.parBouton[tostring(boutonId or "")] end

function Boutons.Get(id) return Boutons.parId[tostring(id or "")] end
