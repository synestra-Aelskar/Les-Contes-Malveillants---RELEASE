-- Morphologies et zones du corps.
--
-- Une morphologie se declare par un EFFECTIF : combien de tetes, de bras, de
-- jambes, de queues, d'ailes. Le torse et les internes sont toujours la. Les
-- zones sont ensuite engendrees — c'est ce qui permet trois tetes ou douze
-- pattes sans ecrire une ligne de plus.
--
-- Points de vie (regle du template Necronicon, fenetre Sante) :
--   - le maximum GLOBAL vient d'une formule (Data/Fiche.lua, pv_max) ;
--   - CHAQUE zone vaut arrondi_inf(PV max x Equilibrage.pv.parZone), soit
--     30 % : les zones ne se partagent pas le total, une blessure grave a la
--     tete n'epuise pas les jambes ;
--   - les PV courants globaux = PV max - somme des blessures des zones.
--     Jamais stockes.
--
-- On enregistre les degats subis, pas les points restants : si le maximum
-- change, les blessures en cours restent coherentes sans recalcul, et une
-- zone intacte ne laisse rien dans la sauvegarde.

local _, LCM = ...

local Morphologies = { list = {}, byId = {} }
local Races = { list = {}, byId = {} }
local Body = {}
LCM.Morphologies = Morphologies
LCM.Races = Races
LCM.Body = Body

local function Erreur(message)
    error("LCM/Body : " .. tostring(message), 0)
end

local ICONE = "Interface\\ICONS\\"

-- Categories connues, dans l'ordre d'affichage. `unique` : toujours exactement
-- une. `seul` : le libelle quand la morphologie n'en a qu'une (« Jambes » pour
-- la zone qui couvre les deux). Descriptions ET icones reprises du template
-- (window_custom_12, onglet Physique) ; l'icone retenue est celle de l'entree
-- posee dans la cellule, la seule que Necronicon affiche.
--
-- L'Aile et la Queue n'existent pas dans le template, qui est humanoide :
-- leurs icones sont des choix de l'addon.
local CATEGORIES = {
    { id = "tete",     label = "Tête",     seul = "Tête", feminin = true,
      icone = ICONE .. "inv_misc_head_human_02",
      description = "Représente l'état du crâne, du visage et des organes sensoriels." },
    { id = "buste",    label = "Torse",    unique = true,
      icone = ICONE .. "ability_warrior_intensifyrage",
      description = "Représente l'état de la poitrine, de l'abdomen et du dos, qui soutiennent le corps et protègent les organes." },
    { id = "bras",     label = "Bras",     seul = "Bras",
      icone = ICONE .. "ability_warrior_strengthofarms",
      description = "Représente l'état des membres supérieurs, des épaules jusqu'aux mains, permettant de saisir et d'agir." },
    { id = "jambe",    label = "Jambe",    seul = "Jambes", feminin = true,
      icone = ICONE .. "dos2_rogue8",
      description = "Représente l'état des membres inférieurs, des hanches jusqu'aux pieds, assurant l'appui et les déplacements." },
    { id = "aile",     label = "Aile",     seul = "Ailes", feminin = true,
      icone = ICONE .. "INV_Misc_Feather_01",     -- hors template
      description = "Représente l'état des ailes, de leur attache jusqu'aux rémiges." },
    { id = "queue",    label = "Queue",    seul = "Queue", feminin = true,
      icone = ICONE .. "INV_Misc_MonsterTail_03", -- hors template
      description = "Représente l'état de la queue, de sa base jusqu'à son extrémité." },
    { id = "internes", label = "Internes", unique = true, vital = true,
      icone = ICONE .. "spell_brokenheart",
      description = "Représente l'état des organes internes et des fonctions vitales, au-delà des blessures de surface." },
}
Body.CATEGORIES = CATEGORIES

local CATEGORY_BY_ID = {}
for _, category in ipairs(CATEGORIES) do CATEGORY_BY_ID[category.id] = category end

function Morphologies.Add(definition)
    if type(definition) ~= "table" then Erreur("morphologie invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("morphologie sans identifiant") end
    if Morphologies.byId[id] then Erreur("morphologie en double : " .. id) end

    local effectifs = type(definition.effectifs) == "table" and definition.effectifs or {}
    for categoryId in pairs(effectifs) do
        if not CATEGORY_BY_ID[categoryId] then
            Erreur(id .. " : categorie inconnue « " .. tostring(categoryId) .. " »")
        end
    end

    local morphology = { id = id, label = tostring(definition.label or id), parts = {}, byId = {} }
    for _, category in ipairs(CATEGORIES) do
        local count = category.unique and 1 or math.max(0, math.floor(tonumber(effectifs[category.id]) or 0))
        for index = 1, count do
            local partId = (count > 1) and (category.id .. "_" .. index) or category.id
            local label = category.seul or category.label
            if count == 2 then
                label = category.label .. (index == 1 and " gauche" or (category.feminin and " droite" or " droit"))
            elseif count > 2 then
                label = category.label .. " " .. index
            end
            local part = {
                id = partId,
                label = label,
                category = category.id,
                index = index,
                icone = category.icone,
                description = category.description,
                vital = category.vital == true,
            }
            morphology.byId[partId] = part
            morphology.parts[#morphology.parts + 1] = part
        end
    end

    Morphologies.byId[id] = morphology
    Morphologies.list[#Morphologies.list + 1] = morphology
    return morphology
end

function Morphologies.Get(id)
    return Morphologies.byId[tostring(id or "")]
end

-- ===== Races ===============================================================

-- Verifie et met en forme sans enregistrer (voir Traits.Construire).
-- Une race a une morphologie et, comme dans le compendium du template, une
-- icone, une description et des effets : elle peut donner des primaires
-- (Insgardienne : Perception +4, Force +2...).
function Races.Construire(definition)
    if type(definition) ~= "table" then Erreur("race invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("race sans identifiant") end
    local morphologyId = tostring(definition.morphology or "")
    if not Morphologies.byId[morphologyId] then
        Erreur("race " .. id .. " : morphologie inconnue « " .. morphologyId .. " »")
    end
    local bonus, avantage = LCM.Effets.Lire(id, definition, Erreur, true)
    -- Icone, description, tags, couleurs... : l'onglet General du compendium.
    return LCM.ChampsCommuns(definition, {
        id = id, label = tostring(definition.label or id), morphology = morphologyId,
        bonus = bonus, avantage = avantage,
        -- Une race que seul le MJ peut donner (un PNJ, une race de campagne
        -- pas encore ouverte) : absente de la creation d'un joueur, et
        -- refusee s'il la designe quand meme. Ce n'est PAS un secret : la
        -- race est livree avec l'addon, son texte est sur la machine du
        -- joueur. Un secret va dans le compagnon MJ.
        mjSeulement = definition.mjSeulement == true or nil,
    }, Erreur)
end

function Races.Add(definition)
    local race = Races.Construire(definition)
    if Races.byId[race.id] then Erreur("race en double : " .. race.id) end
    Races.byId[race.id] = race
    Races.list[#Races.list + 1] = race
    return race
end

function Races.Get(id)
    return Races.byId[tostring(id or "")]
end

-- Ce qu'on peut choisir a la creation : tout pour le MJ, sans les races qui
-- lui sont reservees pour un joueur.
function Races.Choisissable(race)
    return race ~= nil and (not race.mjSeulement or LCM.IsMaster())
end

function Races.Disponibles()
    local out = {}
    for _, race in ipairs(Races.list) do
        if Races.Choisissable(race) then out[#out + 1] = race end
    end
    return out
end

-- Une race supprimee en seance (voir Traits.Retirer).
function Races.Retirer(id)
    id = tostring(id or "")
    if not Races.byId[id] then return false end
    Races.byId[id] = nil
    for index = #Races.list, 1, -1 do
        if Races.list[index].id == id then table.remove(Races.list, index) end
    end
    return true
end

-- La race de l'entite est une source d'effets comme une autre.
LCM.Effets.Source("race", function(entity)
    local race = Races.Get(entity and entity.values and entity.values.race)
    return race and { race } or {}
end, function() return Races.list end)

-- ===== Cote entite =========================================================

-- Priorite : morphologie imposee sur l'entite, puis celle de sa race, puis le
-- defaut. La voie directe sert aux PNJ qui n'appartiennent a aucune race.
function Body.MorphologyOf(entity)
    local values = entity and entity.values or nil
    local direct = values and Morphologies.Get(values.morphologie)
    if direct then return direct end
    local race = Races.Get(values and values.race)
    if race then return Morphologies.Get(race.morphology) end
    return Morphologies.Get(LCM.DEFAULT_MORPHOLOGY or "humanoide")
end

-- Lecture seule : ne CREE rien (voir Traits.lua, meme piege).
local AUCUNE_BLESSURE = {}
local function Wounds(entity)
    if type(entity) ~= "table" or type(entity.body) ~= "table" then return AUCUNE_BLESSURE end
    return entity.body
end

local function WoundsForWrite(entity)
    if type(entity) ~= "table" then return nil end
    entity.body = type(entity.body) == "table" and entity.body or {}
    return entity.body
end

-- Une fois la derniere blessure soignee, la table disparait.
local function ForgetIfClean(entity)
    if type(entity) ~= "table" or type(entity.body) ~= "table" then return end
    if next(entity.body) == nil then entity.body = nil end
end

-- Maximum global : la formule d'equilibrage, et rien d'autre. La surcharge
-- « PV max impose » a ete retiree le 2 octobre 2026 : elle n'avait de sens que
-- pour un PNJ, elle trainait sur la fiche de tout le monde, et un PNJ dont les
-- PV ne suivent pas ses statistiques se regle en changeant ses statistiques.
function Body.MaxTotal(entity)
    return math.max(0, math.floor(tonumber(LCM.Entities.Get_Value(entity, "pv_max")) or 0))
end

-- Le maximum d'UNE zone, le meme pour toutes (template : PV max x 0,30).
function Body.PartMax(entity, total)
    total = tonumber(total) or Body.MaxTotal(entity)
    local parZone = LCM.Equilibrage and LCM.Equilibrage.pv and LCM.Equilibrage.pv.parZone or 0
    return math.max(0, math.floor(total * parZone))
end

function Body.State(entity, total)
    local morphology = Body.MorphologyOf(entity)
    if not morphology then return {}, nil end
    local maximum = Body.PartMax(entity, total)
    local wounds = Wounds(entity)
    local state = {}
    for _, part in ipairs(morphology.parts) do
        local wound = math.max(0, math.min(tonumber(wounds[part.id]) or 0, maximum))
        state[#state + 1] = {
            id = part.id, label = part.label, part = part,
            max = maximum, wound = wound, current = maximum - wound,
        }
    end
    return state, morphology
end

function Body.Damage(entity, partId, amount)
    local morphology = Body.MorphologyOf(entity)
    if not morphology or not morphology.byId[tostring(partId or "")] then return false end
    local maximum = Body.PartMax(entity)
    local actuelle = tonumber(Wounds(entity)[partId]) or 0
    local wound = math.max(0, math.min(actuelle + (tonumber(amount) or 0), maximum))
    if wound == 0 and actuelle == 0 then return true end
    local wounds = WoundsForWrite(entity)
    if not wounds then return false end
    wounds[partId] = wound > 0 and wound or nil
    ForgetIfClean(entity)
    LCM.Entities.Changed(entity, "corps")
    return true
end

function Body.Heal(entity, partId, amount)
    return Body.Damage(entity, partId, -(tonumber(amount) or 0))
end

-- Fixe directement les PV courants d'une zone (saisie a la main).
function Body.SetCurrent(entity, partId, current)
    local morphology = Body.MorphologyOf(entity)
    if not morphology or not morphology.byId[tostring(partId or "")] then return false end
    local maximum = Body.PartMax(entity)
    local valeur = math.max(0, math.min(tonumber(current) or 0, maximum))
    local wound = maximum - valeur
    if wound == 0 and (tonumber(Wounds(entity)[partId]) or 0) == 0 then return true end
    local wounds = WoundsForWrite(entity)
    if not wounds then return false end
    wounds[partId] = wound > 0 and wound or nil
    ForgetIfClean(entity)
    LCM.Entities.Changed(entity, "corps")
    return true
end

function Body.HealAll(entity)
    if type(entity) ~= "table" then return false end
    entity.body = nil
    LCM.Entities.Changed(entity, "corps")
    return true
end

-- PV courants = PV max - somme des blessures. Ils peuvent passer sous zero :
-- les zones valent ensemble plus que le total (template).
function Body.Totals(entity, total)
    local maximum = math.floor(tonumber(total) or Body.MaxTotal(entity))
    local current = maximum
    for _, part in ipairs(Body.State(entity, maximum)) do
        current = current - part.wound
    end
    return current, maximum
end

-- Une seule definition de l'inconscience pour toute l'interface. Les zones
-- peuvent faire descendre le total sous zero ; zero et moins signifient KO.
-- Un corps sans aucun PV maximum (fiche incomplete) n'est pas declare KO.
function Body.Inconscient(entity)
    local current, maximum = Body.Totals(entity)
    return maximum > 0 and current <= 0
end
