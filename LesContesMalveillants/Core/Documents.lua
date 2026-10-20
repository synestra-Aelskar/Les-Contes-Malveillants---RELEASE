-- Documents : regles, aides de jeu, tutoriels.
--
-- Ce fichier ne contient que le REGISTRE : il doit se charger avant les donnees
-- (Data/Documents.lua). La fenetre vit dans UI/Document.lua.
--
-- Dans Necronicon, ces pages etaient bricolees avec des feuilles de
-- personnage — une fiche qui ne decrit personne. Ici c'est un type a part :
-- un document est un titre et une suite de blocs, rien de plus.
--
-- Blocs reconnus : "titre", "texte", "liste", "separateur".

local _, LCM = ...

local Documents = { list = {}, byId = {} }
LCM.Documents = Documents

local function Erreur(message)
    error("LCM/Documents : " .. tostring(message), 0)
end

function Documents.Add(definition)
    if type(definition) ~= "table" then Erreur("document invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("document sans identifiant") end
    if Documents.byId[id] then Erreur("document en double : " .. id) end
    local doc = {
        id = id,
        label = tostring(definition.label or id),
        ordre = tonumber(definition.ordre) or 100,
        masterOnly = definition.masterOnly == true,
        blocs = {},
    }
    for _, bloc in ipairs(definition.blocs or {}) do
        local kind = tostring(bloc.kind or "texte")
        if kind ~= "titre" and kind ~= "texte" and kind ~= "liste" and kind ~= "separateur" then
            Erreur(id .. " : bloc inconnu « " .. kind .. " »")
        end
        doc.blocs[#doc.blocs + 1] = {
            kind = kind,
            texte = tostring(bloc.texte or ""),
            items = bloc.items,
        }
    end
    Documents.byId[id] = doc
    Documents.list[#Documents.list + 1] = doc
    return doc
end

function Documents.Get(id)
    return Documents.byId[tostring(id or "")]
end

function Documents.Visibles()
    local out = {}
    for _, doc in ipairs(Documents.list) do
        if (not doc.masterOnly) or LCM.IsMaster() then out[#out + 1] = doc end
    end
    table.sort(out, function(a, b)
        if a.ordre ~= b.ordre then return a.ordre < b.ordre end
        return tostring(a.label) < tostring(b.label)
    end)
    return out
end
