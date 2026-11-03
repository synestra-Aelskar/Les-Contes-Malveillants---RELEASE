-- Les TAGS (le MJ, 3 novembre 2026) : retrouver vite une entree parmi des
-- milliers. « Je cree un vendeur au Val'Razkah, je veux qu'il vende des
-- objets, mais j'ai 7 600 entrees » : on filtre sur ses tags.
--
-- Un tag est une entree de la liste « tags » (Core/Contenus.lua). Il se range
-- en ARBRE : un tag peut avoir un PARENT — Valienne › Raptor › Électrique ›
-- Sans les dents —, aussi profond qu'on veut. Un tag peut avoir plusieurs
-- ORIGINES (« Liste origine ») ; sans origine, c'est un tag general, « Aucun ».
-- Un sous-tag reprend celles de son parent ou en garde seulement une partie.
--
-- Une entree porte ses tags dans `etiquettes` (`tags` est deja le libelle de
-- rarete). Le filtre est un OU, et un tag couvre ses sous-tags : choisir
-- « Raptor » montre aussi les raptors electriques ; choisir « Électrique » ne
-- montre que ceux-la.
local _, LCM = ...

local Etiquettes = {}
LCM.Etiquettes = Etiquettes

Etiquettes.AUCUN = "Aucun"
-- Garde-fou : un parent qui finirait par se citer lui-meme (deux MJ qui se
-- croisent) ne fait pas tourner l'addon en rond.
local PROFONDEUR_MAX = 12

function Etiquettes.Liste()
    return LCM.Listes and LCM.Listes.De("tags") or {}
end

function Etiquettes.Get(id)
    local e = LCM.Listes and LCM.Listes.Get(tostring(id or ""))
    return e and e.liste == "tags" and e or nil
end

-- Le parent d'un tag, s'il existe encore (un parent supprime fait de son
-- enfant une racine, plutot que de le perdre).
local function Parent(tag)
    return tag and tag.parent and Etiquettes.Get(tag.parent) or nil
end

-- La racine d'un tag, et sa profondeur (0 pour une racine).
function Etiquettes.Racine(tag)
    local courant, profondeur = tag, 0
    while courant and Parent(courant) and profondeur < PROFONDEUR_MAX do
        courant, profondeur = Parent(courant), profondeur + 1
    end
    return courant, profondeur
end

-- Origines effectives : un sous-tag peut garder seulement certaines origines
-- de son parent. Sans choix propre, il les reprend toutes.
function Etiquettes.Origines(tag)
    local courant, profondeur = tag, 0
    while courant and profondeur <= PROFONDEUR_MAX do
        if type(courant.origines) == "table" and courant.origines[1] then
            return courant.origines
        end
        if courant.origine and courant.origine ~= "" then return { courant.origine } end
        courant, profondeur = Parent(courant), profondeur + 1
    end
    return {}
end

-- Compatibilite avec les usages qui ne demandent qu'une premiere origine.
function Etiquettes.Origine(tag)
    return Etiquettes.Origines(tag)[1] or ""
end

-- « Raptor › Électrique », du haut vers le bas.
function Etiquettes.Chemin(id)
    local tag = Etiquettes.Get(id)
    if not tag then return "? " .. tostring(id) end
    local noms, courant, n = {}, tag, 0
    while courant and n <= PROFONDEUR_MAX do
        table.insert(noms, 1, tostring(courant.label or courant.id))
        courant, n = Parent(courant), n + 1
    end
    return table.concat(noms, " › ")
end
Etiquettes.Libelle = Etiquettes.Chemin

-- Les enfants de chaque tag : { [parentId ou ""] = { tag, ... } }, tries.
local function Enfants()
    local out = {}
    for _, tag in ipairs(Etiquettes.Liste()) do
        local cle = Parent(tag) and tag.parent or ""
        out[cle] = out[cle] or {}
        table.insert(out[cle], tag)
    end
    for _, liste in pairs(out) do
        table.sort(liste, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
    end
    return out
end

-- Les tags, ranges par origine puis en arbre (chaque racine suivie de ses
-- descendants, `niveau` = profondeur). « Aucun » d'abord, puis les origines
-- dans l'ordre de leur liste, puis celles qu'on ne connait plus.
-- { { id = origine ou "", label, tags = { { tag, niveau } } } }
function Etiquettes.Groupes()
    local enfants = Enfants()
    local parOrigine = {}
    local function Descendre(tag, niveau, liste, origine)
        local origines = Etiquettes.Origines(tag)
        local present = #origines == 0 and origine == ""
        for _, id in ipairs(origines) do if id == origine then present = true end end
        if not present then return end
        liste[#liste + 1] = { tag = tag, niveau = niveau }
        if niveau >= PROFONDEUR_MAX then return end
        for _, enfant in ipairs(enfants[tag.id] or {}) do Descendre(enfant, niveau + 1, liste, origine) end
    end
    for _, racine in ipairs(enfants[""] or {}) do
        local origines = Etiquettes.Origines(racine)
        for _, cle in ipairs(#origines > 0 and origines or { "" }) do
            parOrigine[cle] = parOrigine[cle] or {}
            Descendre(racine, 0, parOrigine[cle], cle)
        end
    end
    local out, vus = {}, { [""] = true }
    out[1] = { id = "", label = Etiquettes.AUCUN, tags = parOrigine[""] or {} }
    for _, origine in ipairs(LCM.Listes and LCM.Listes.De("origines") or {}) do
        out[#out + 1] = { id = origine.id, label = tostring(origine.label or origine.id),
            tags = parOrigine[origine.id] or {} }
        vus[origine.id] = true
    end
    for cle, tags in pairs(parOrigine) do
        if not vus[cle] then out[#out + 1] = { id = cle, label = "? " .. cle .. " (origine disparue)", tags = tags } end
    end
    return out
end

-- Les groupes tels que les attend une fenetre de cases (UI.ChoixCoches),
-- l'arbre en retrait. `vides` : garder les origines sans tag.
function Etiquettes.GroupesCoches(vides)
    local out = {}
    for _, g in ipairs(Etiquettes.Groupes()) do
        local options = {}
        for _, t in ipairs(g.tags) do
            options[#options + 1] = { id = t.tag.id, label = tostring(t.tag.label), niveau = t.niveau }
        end
        if options[1] or vides then out[#out + 1] = { id = g.id, label = g.label, options = options } end
    end
    return out
end

-- Ou poser un nouveau tag : une origine (racine), ou SOUS un tag existant.
-- { id = "origine:<id>" | "parent:<id>", label, groupe }
function Etiquettes.Emplacements()
    local out = { { id = "origine:", label = Etiquettes.AUCUN .. " (tag général)", groupe = "Nouvelle racine" } }
    for _, origine in ipairs(LCM.Listes and LCM.Listes.De("origines") or {}) do
        out[#out + 1] = { id = "origine:" .. origine.id, label = tostring(origine.label or origine.id),
            groupe = "Nouvelle racine" }
    end
    local vus = {}
    for _, g in ipairs(Etiquettes.Groupes()) do
        for _, t in ipairs(g.tags) do
            if not vus[t.tag.id] then
                vus[t.tag.id] = true
                out[#out + 1] = { id = "parent:" .. t.tag.id,
                    label = "sous « " .. Etiquettes.Chemin(t.tag.id) .. " »",
                    groupe = "Sous-tag" }
            end
        end
    end
    return out
end

-- La definition d'un nouveau tag, d'apres l'emplacement choisi.
function Etiquettes.Definition(id, nom, emplacement)
    local def = { id = id, label = tostring(nom or ""), liste = "tags" }
    local origine = tostring(emplacement or ""):match("^origine:(.*)$")
    local parent = tostring(emplacement or ""):match("^parent:(.+)$")
    if parent then def.parent = parent
    elseif origine and origine ~= "" then def.origine = origine end
    return def
end

-- La selection, etendue a tous les descendants : choisir « Raptor », c'est
-- choisir aussi « Électrique » et « Sans les dents ».
function Etiquettes.Etendre(selection)
    if not selection or next(selection) == nil then return selection end
    local enfants = Enfants()
    local out = {}
    local function Ajouter(id, n)
        if out[id] or n > PROFONDEUR_MAX then return end
        out[id] = true
        for _, enfant in ipairs(enfants[id] or {}) do Ajouter(enfant.id, n + 1) end
    end
    for id, v in pairs(selection) do if v then Ajouter(id, 0) end end
    return out
end

-- L'entree porte-t-elle l'un des tags choisis (ou l'un de leurs sous-tags) ?
-- `selection` : { [id] = true }, deja etendue ou non. Sans selection, tout passe.
function Etiquettes.Porte(element, selection, dejaEtendue)
    if not selection or next(selection) == nil then return true end
    local ensemble = dejaEtendue and selection or Etiquettes.Etendre(selection)
    for _, id in ipairs(type(element) == "table" and element.etiquettes or {}) do
        if ensemble[id] then return true end
    end
    return false
end

-- « Raptor › Électrique, Valienne… », ou « » sans tag.
function Etiquettes.Resume(ids)
    local noms = {}
    for _, id in ipairs(ids or {}) do noms[#noms + 1] = Etiquettes.Chemin(id) end
    table.sort(noms)
    return table.concat(noms, ", ")
end

function Etiquettes.Ensemble(ids)
    local out = {}
    for _, id in ipairs(ids or {}) do out[id] = true end
    return out
end
