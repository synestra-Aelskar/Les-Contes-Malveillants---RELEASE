-- Structure des feuilles, declaree en dur.
--
-- Une feuille = des onglets, des sections, des champs. Cette structure vit dans
-- le code et UNIQUEMENT dans le code : elle n'est jamais ecrite dans la
-- sauvegarde, jamais recopiee par entite. Une entite (joueur ou PNJ) ne porte
-- que ses valeurs, indexees par l'identifiant de champ.
--
-- Chaque champ a un identifiant stable, choisi a l'ecriture et jamais calcule.
-- C'est ce qui rend les references fiables : `pv`, `force`, `resi_feu` sont des
-- constantes, pas des noms d'affichage ni des numeros attribues a l'execution.

local _, LCM = ...

local Schema = {}
LCM.Schema = Schema

-- Types de champ reconnus. La liste est volontairement courte et fermee : tout
-- ce qui s'affiche sur une feuille doit entrer dans l'un d'eux.
--   stat    nombre simple                          (Force : 3)
--   gauge   courant / maximum                      (Point de vie : 36 / 36)
--   roll    des + stat + modificateur, lancable    (Adresse : 0-15, 7, +0, Rand)
--   text    texte libre
--   calc    valeur calculee, non saisissable       (somme, moyenne...)
--   body    silhouette : les points de vie repartis sur les parties du corps
--   traits  la liste des traits portes (vit dans `entity.traits`, pas dans
--           `values` : c'est une liste d'identifiants, pas une valeur)
Schema.KINDS = { stat = true, gauge = true, roll = true, text = true, calc = true, body = true, traits = true }

local sheet = { tabs = {}, byId = {}, order = {} }
Schema.sheet = sheet

local function Erreur(message)
    -- A l'ecriture d'une feuille, une faute doit etre bruyante et immediate :
    -- c'est le moment ou elle coute le moins cher a corriger.
    error("LCM/Schema : " .. tostring(message), 0)
end

-- Declare un onglet. `fields` de chaque section porte les champs dans l'ordre
-- d'affichage.
function Schema.AddTab(definition)
    if type(definition) ~= "table" then Erreur("onglet invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("onglet sans identifiant") end
    for _, existing in ipairs(sheet.tabs) do
        if existing.id == id then Erreur("onglet en double : " .. id) end
    end

    local tab = {
        id = id,
        label = tostring(definition.label or id),
        sections = {},
    }

    for _, sectionDef in ipairs(definition.sections or {}) do
        local section = {
            -- Identifiant stable, pour qu'une vue designe la section sans
            -- dependre de son libelle (qui, lui, peut changer).
            id = sectionDef.id and tostring(sectionDef.id) or nil,
            label = tostring(sectionDef.label or ""),
            fields = {},
        }
        for _, fieldDef in ipairs(sectionDef.fields or {}) do
            local fieldId = tostring(fieldDef.id or "")
            if fieldId == "" then Erreur("champ sans identifiant dans " .. id) end
            if not Schema.KINDS[tostring(fieldDef.kind or "")] then
                Erreur("type inconnu pour " .. fieldId .. " : " .. tostring(fieldDef.kind))
            end
            -- L'unicite est verifiee sur TOUTE la feuille, pas seulement dans
            -- l'onglet : un identifiant designe un champ et un seul.
            if sheet.byId[fieldId] then
                Erreur("champ en double : " .. fieldId)
            end

            local field = {
                id = fieldId,
                kind = fieldDef.kind,
                label = tostring(fieldDef.label or fieldId),
                tab = id,
                section = section.label,
                default = fieldDef.default,
                max = fieldDef.max,
                min = fieldDef.min,
                dice = fieldDef.dice,        -- { min, max } pour un roll
                stat = fieldDef.stat,        -- champ « stat » utilise par un roll
                formula = fieldDef.formula,            -- fonction(entite), champ calc
                maxFormula = fieldDef.maxFormula,      -- fonction(entite), maximum d'une jauge
                valueFormula = fieldDef.valueFormula,  -- fonction(entite), valeur d'un jet
                -- Une jauge calculee ailleurs que dans les valeurs (l'armure
                -- portee) : lire(entite) -> { current, max }, ecrire(entite, courant).
                lire = fieldDef.lire,
                ecrire = fieldDef.ecrire,
                note = fieldDef.note,
                jetExpertise = fieldDef.jetExpertise == true,
                -- Un champ calcule qui accepte les bonus portes (sa formule les
                -- lit) : l'atelier le propose comme cible d'un bonus.
                recoitBonus = fieldDef.recoitBonus == true,
                -- `masque` : jamais dessine (sa valeur est montree ailleurs).
                -- `mjSeulement` : dessine pour le MJ seulement (une surcharge).
                masque = fieldDef.masque == true,
                mjSeulement = fieldDef.mjSeulement == true,
            }
            sheet.byId[fieldId] = field
            sheet.order[#sheet.order + 1] = fieldId
            section.fields[#section.fields + 1] = field
        end
        tab.sections[#tab.sections + 1] = section
    end

    sheet.tabs[#sheet.tabs + 1] = tab
    return tab
end

function Schema.Field(fieldId)
    return sheet.byId[tostring(fieldId or "")]
end

function Schema.Tabs()
    return sheet.tabs
end

-- Parcourt tous les champs de la feuille, dans l'ordre de declaration.
function Schema.EachField(handler)
    for _, fieldId in ipairs(sheet.order) do
        handler(sheet.byId[fieldId])
    end
end

function Schema.Count()
    return #sheet.order
end
