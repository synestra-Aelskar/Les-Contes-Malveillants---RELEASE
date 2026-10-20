-- Livres lisibles : definitions partagees, sans statistiques ni forge.
local _, LCM = ...

local Livres = LCM.Registre({
    nom = "livre", prefixe = "Livres",
    construire = function(definition, livre, Erreur)
        local format = tostring(definition.format or "livre")
        if format ~= "note" and format ~= "livre" then
            Erreur(livre.id .. " : format de livre inconnu")
        end
        livre.format = format
        livre.forge, livre.etat = nil, nil
        livre.pileMax = livre.pileMax or 1
        local style = type(definition.style) == "table" and definition.style or {}
        local function Couleur(valeur, defaut)
            valeur = tostring(valeur or defaut):gsub("^#", ""):upper()
            if not valeur:match("^%x%x%x%x%x%x$") then Erreur(livre.id .. " : couleur de livre invalide") end
            return valeur
        end
        livre.style = {
            fond = Couleur(style.fond, "E5D3A3"),
            encre = Couleur(style.encre, "302317"),
            accent = Couleur(style.accent, "8D632D"),
            alignement = style.alignement == "CENTER" and "CENTER" or "LEFT",
        }
        if type(definition.pages) ~= "table" then Erreur(livre.id .. " : pages manquantes") end
        local nombre = #definition.pages
        if format == "note" and nombre ~= 2 then Erreur(livre.id .. " : une note a un recto et un verso") end
        if format == "livre" and (nombre < 1 or nombre > 32) then
            Erreur(livre.id .. " : un livre contient de 1 à 32 pages")
        end
        livre.pages = {}
        local volume = 0
        for index, page in ipairs(definition.pages) do
            if type(page) ~= "table" then Erreur(livre.id .. " : page " .. index .. " invalide") end
            local titre, texte = tostring(page.titre or ""), tostring(page.texte or "")
            if #titre > 120 or #texte > 4000 then Erreur(livre.id .. " : page " .. index .. " trop longue") end
            volume = volume + #titre + #texte
            livre.pages[index] = { titre = titre, texte = texte }
        end
        local function Face(source)
            source = type(source) == "table" and source or {}
            local titre, texte = tostring(source.titre or ""), tostring(source.texte or "")
            if #titre > 120 or #texte > 4000 then Erreur(livre.id .. " : couverture trop longue") end
            return { titre = titre, texte = texte }
        end
        if format == "livre" then
            livre.couverture = Face(definition.couverture)
            livre.dos = Face(definition.dos)
            volume = volume + #livre.couverture.titre + #livre.couverture.texte
                + #livre.dos.titre + #livre.dos.texte
        end
        -- La definition voyage aussi dans une cellule de la base partagee.
        if volume > 30000 then Erreur(livre.id .. " : texte trop long (30 000 caractères maximum)") end
    end,
})
LCM.Livres = Livres

function Livres.Remplacer(definition)
    local neuf = Livres.Construire(definition)
    local ancien = Livres.Get(neuf.id)
    if not ancien then return Livres.Add(definition) end
    for cle in pairs(ancien) do ancien[cle] = nil end
    for cle, valeur in pairs(neuf) do ancien[cle] = valeur end
    return ancien
end

function Livres.Definition(ref)
    local id = tostring(ref or ""):match("^livres/(.+)$")
    local livre = id and Livres.Get(id)
    if not livre then return nil end
    return LCM.Copie(livre)
end

-- Un coffre ou un point de recolte peut arriver avant la base publique.
-- La definition accompagne donc aussi le loot et reste apres /reload.
function Livres.Importer(ref, definition)
    local id = tostring(ref or ""):match("^livres/(.+)$")
    if not id or type(definition) ~= "table" or tostring(definition.id or "") ~= id then return false end
    local ok, livre = pcall(Livres.Construire, definition)
    if not ok or not livre then return false end
    local ajoute, resultat = pcall(Livres.Remplacer, definition)
    if not ajoute or not resultat then return false end
    LCM.EnsureDatabase()
    LCM.db.livresRecus = type(LCM.db.livresRecus) == "table" and LCM.db.livresRecus or {}
    LCM.db.livresRecus[id] = LCM.Copie(definition)
    return true
end

LCM.WhenReady(function()
    local db = LCM.EnsureDatabase()
    for id, definition in pairs(type(db.livresRecus) == "table" and db.livresRecus or {}) do
        if tostring(definition.id or "") == tostring(id) then
            local ok = pcall(Livres.Remplacer, definition)
            if not ok then LCM.Erreur("livre reçu illisible : " .. tostring(id)) end
        end
    end
end)
