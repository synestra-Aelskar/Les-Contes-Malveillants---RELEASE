-- Les sorts propres a un personnage.
--
-- C'est la PREMIERE chose qu'on ecrit en sauvegarde qui ne soit pas une valeur
-- de fiche : un sort appris est du contenu, et il appartient a celui qui l'a.
-- Decision de l'utilisateur (1er octobre 2026), prise en connaissance de cause.
--
-- Consequences, et elles comptent :
--   * ce contenu-la n'est PAS versionne, il vit chez le joueur. Il faut donc
--     qu'il puisse voyager : d'ou le lien de chat (Core/Lien.lua) et le partage
--     (Core/Reseau.lua) ;
--   * il faut le valider a l'entree, parce qu'il arrivera aussi du reseau,
--     ou rien ne garantit ce qu'on recoit.
--
-- Ils remplissent le grimoire personnel (Data/Grimoires.lua).

local _, LCM = ...

local Sorts = {}
LCM.Sorts = Sorts

local VIDE = {}

-- Bornes volontairement serrees : un sort doit tenir dans un partage sans
-- devenir un roman, et un texte sans limite finit toujours par en etre un.
Sorts.NOM_MAX = 60
Sorts.TEXTE_MAX = 400
Sorts.CHAMP_MAX = 60

local function Texte(v, maximum)
    v = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if maximum and #v > maximum then v = v:sub(1, maximum) end
    return v
end

-- Lecture : ne cree rien.
local function Liste(entity)
    if type(entity) ~= "table" or type(entity.sorts) ~= "table" then return VIDE end
    return entity.sorts
end

local function ListePourEcrire(entity)
    if type(entity) ~= "table" then return nil end
    entity.sorts = type(entity.sorts) == "table" and entity.sorts or {}
    return entity.sorts
end

function Sorts.Liste(entity) return Liste(entity) end

function Sorts.Compte(entity) return #Liste(entity) end

function Sorts.Get(entity, id)
    id = tostring(id or "")
    for _, sort in ipairs(Liste(entity)) do
        if sort.id == id then return sort end
    end
    return nil
end

-- Un identifiant stable, derive du nom : c'est lui qui voyage dans un lien de
-- chat, donc il doit rester lisible et ne pas changer sous les pieds.
local function IdentifiantLibre(entity, nom)
    local base = Texte(nom):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "" then base = "sort" end
    if not Sorts.Get(entity, base) then return base end
    local index = 2
    while Sorts.Get(entity, base .. "_" .. index) do index = index + 1 end
    return base .. "_" .. index
end
Sorts.IdentifiantLibre = IdentifiantLibre

-- Met une definition en forme, ou dit pourquoi elle est refusee. Appelee aussi
-- bien par l'editeur que par ce qui arrive du reseau : c'est le seul endroit
-- ou l'on decide qu'un sort est acceptable.
-- Ce qu'un sort peut declencher. L'ordre est celui de l'editeur.
Sorts.ACTIONS = {
    resolution = "Action de combat",
    macro      = "Macro",
    arcanum    = "Sort Arcanum",
}
Sorts.ORDRE_ACTIONS = { "resolution", "macro", "arcanum" }

function Sorts.Valider(definition)
    if type(definition) ~= "table" then return nil, "sort illisible." end
    local nom = Texte(definition.label, Sorts.NOM_MAX)
    if nom == "" then return nil, "il faut un nom." end

    local sort = {
        label = nom,
        icone = Texte(definition.icone, 200),
        description = Texte(definition.description, Sorts.TEXTE_MAX),
    }
    if sort.icone == "" then sort.icone = nil end
    if sort.description == "" then sort.description = nil end
    -- « Champ 1 » et « Champ 2 » ont disparu le 5 octobre 2026 : deux cases
    -- sans nom que personne ne savait quoi remplir. Ce qu'elles contenaient
    -- chez quelqu'un reste dans sa sauvegarde, simplement plus affiche.

    -- Le jet d'un sort passe par une COMPETENCE de la fiche (Adresse, Esprit,
    -- une expertise) : c'est elle qui porte les des, la valeur et les apports.
    -- Avant, chaque sort portait sa propre plage « min a max », qui ne tenait
    -- compte de rien et vieillissait avec le personnage.
    local competence = Texte(definition.competence, 60)
    if competence ~= "" then
        if not LCM.Schema.Field(competence) then
            return nil, string.format("compétence inconnue : %s", competence)
        end
        sort.competence = competence
    end

    -- L'ancienne plage reste LUE : un sort ecrit avant la bascule garde son
    -- bouton. On ne la propose plus a l'ecriture, on ne la jette pas non plus.
    local jet = definition.jet
    if jet ~= nil then
        if type(jet) ~= "table" then return nil, "jet illisible." end
        local minimum = math.floor(tonumber(jet.min) or 0)
        local maximum = math.floor(tonumber(jet.max) or 0)
        if maximum < minimum then minimum, maximum = maximum, minimum end
        if not (minimum == 0 and maximum == 0) then
            sort.jet = { min = minimum, max = maximum }
        end
    end

    -- Ce que le sort DECLENCHE, en plus de son jet : une action de combat (avec
    -- un modele de la bibliotheque, s'il en porte un), une macro, ou un sort
    -- Arcanum. Repris de Necronicon, ou un sort du grimoire peut lancer autre
    -- chose que du texte.
    local action = definition.action
    if action ~= nil then
        if type(action) ~= "table" then return nil, "action illisible." end
        local genre = Texte(action.genre, 20)
        if genre ~= "" then
            if not Sorts.ACTIONS[genre] then
                return nil, string.format("type d'action inconnu : %s", genre)
            end
            local ref = Texte(action.ref, 200)
            if ref == "" then
                return nil, string.format("« %s » : il manque ce qu'il faut lancer.",
                    Sorts.ACTIONS[genre])
            end
            sort.action = { genre = genre, ref = ref }
            local modele = Texte(action.modele, 80)
            if modele ~= "" then sort.action.modele = modele end
        end
    end
    return sort
end

-- Lancer un sort : son JET d'abord (la competence de la fiche, avec ses des,
-- sa valeur et ses apports), puis ce qu'il DECLENCHE.
--
-- Les deux sont independants : un sort peut n'avoir qu'un jet, n'avoir qu'une
-- action, ou les deux. Rien n'oblige a choisir.
function Sorts.Lancer(entity, sort)
    entity = entity or LCM.Entities.Self()
    if not (entity and type(sort) == "table") then return false, "aucun personnage." end

    -- Le jet par la competence : c'est la fiche qui porte les des.
    if sort.competence then
        local resultat = LCM.Roll.Field(entity, sort.competence)
        if resultat then
            resultat.label = string.format("%s (%s)", tostring(sort.label), resultat.label)
            LCM.Roll.Annoncer(resultat)
        end
    elseif sort.jet then
        -- Un sort ecrit avant la bascule garde sa plage.
        local tirage, minimum, maximum = LCM.Roll.Des(sort.jet.min, sort.jet.max)
        LCM.Info(string.format("%s : |cffffd36b%d|r  (%d-%d)",
            tostring(sort.label), tirage, minimum, maximum))
    end

    local action = sort.action
    if not action then return true end

    if action.genre == "resolution" then
        -- L'action de combat du lanceur, avec le modele de la bibliotheque qui
        -- porte le nom du sort s'il en existe un : c'est ce qui evite de
        -- recomposer le meme buff a chaque fois.
        if not (LCM.Actions and LCM.Actions.Lancer) then
            return false, "les actions ne sont pas chargées."
        end
        LCM.Actions.modelePrecharge = action.modele or sort.label
        local ok = LCM.Actions.Lancer(action.ref, entity)
        if not ok then return false, string.format("action inconnue : %s", tostring(action.ref)) end
        return true
    end

    if action.genre == "macro" then
        -- Comme si on l'avait tapee. `RunMacroText` n'existe pas partout (ni au
        -- banc) : sans lui, on ne fait pas semblant, on le dit.
        if type(RunMacroText) ~= "function" then
            return false, "ce client ne sait pas lancer une macro."
        end
        local ok = pcall(RunMacroText, action.ref)
        if not ok then return false, "la macro a été refusée." end
        return true
    end

    if action.genre == "arcanum" then
        -- SpellCreator (Arcanum) expose ses sorts par son API. Absent, on ne
        -- devine pas : on dit ce qu'il manque.
        local sc = _G.SpellCreator
        local lancer = type(sc) == "table" and (sc.CastSpell or (sc.API and sc.API.CastSpell))
        if type(lancer) ~= "function" then
            return false, "Arcanum (SpellCreator) n'est pas chargé."
        end
        local ok = pcall(lancer, action.ref)
        if not ok then return false, string.format("sort Arcanum refusé : %s", tostring(action.ref)) end
        return true
    end

    return false, "action inconnue."
end

function Sorts.Ajouter(entity, definition)
    local sort, raison = Sorts.Valider(definition)
    if not sort then return nil, raison end
    local liste = ListePourEcrire(entity)
    if not liste then return nil, "aucun personnage." end
    -- Deux sorts peuvent porter le meme nom : le second prend un identifiant
    -- libre, comme les homonymes de personnages. En revanche, un identifiant
    -- IMPOSE doit etre libre — c'est le cas quand on adopte un sort partage, et
    -- la, ecraser le sien en silence serait une perte.
    local impose = Texte(definition.id)
    if impose ~= "" then
        if Sorts.Get(entity, impose) then return nil, "il a deja ce sort." end
        sort.id = impose
    else
        sort.id = IdentifiantLibre(entity, sort.label)
    end
    liste[#liste + 1] = sort
    return sort
end

function Sorts.Modifier(entity, id, definition)
    local ancien = Sorts.Get(entity, id)
    if not ancien then return nil, "sort inconnu." end
    local sort, raison = Sorts.Valider(definition)
    if not sort then return nil, raison end
    -- L'identifiant ne bouge pas : des liens de chat le citent peut-etre deja.
    sort.id = ancien.id
    for index, porte in ipairs(Liste(entity)) do
        if porte.id == ancien.id then entity.sorts[index] = sort end
    end
    return sort
end

function Sorts.Supprimer(entity, id)
    id = tostring(id or "")
    local liste = Liste(entity)
    for index = #liste, 1, -1 do
        if liste[index].id == id then
            table.remove(liste, index)
            -- Plus rien : on efface la table, la sauvegarde ne garde pas de
            -- liste vide.
            if #liste == 0 and type(entity) == "table" then entity.sorts = nil end
            return true
        end
    end
    return false
end
