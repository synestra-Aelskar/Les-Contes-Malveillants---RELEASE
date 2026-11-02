-- Les outils qu'un prerequis exige, et ce qu'on possede pour y repondre.
--
-- Ne dans l'ecran des coffres (UI/Coffre.lua) ; descendu ici le 2 novembre
-- 2026, quand les points de recolte ont eu leurs « Outils autorisés » : une
-- pioche liee au metier Mineur se cherche exactement comme la pioche qu'un
-- coffre demande. Un seul code, sinon les deux regles divergeraient.
--
-- Un prerequis : { entree = "objets/…" } (un objet precis) ou
-- { typeOutil = <id de la « Liste outils »> } (tout outil de ce type), avec
-- `quantite`, `consomme`, `consommeQuantite`.

local _, LCM = ...


local OutilsRequis = {}
LCM.OutilsRequis = OutilsRequis

local function SacTotal(entity, ref)
    local total = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for i = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(entity, categorie.id, i)
            for _, item in pairs(e and e.cases or {}) do
                if item.ref == ref then total = total + (tonumber(item.quantite) or 1) end
            end
        end
    end
    return total
end
OutilsRequis.SacTotal = SacTotal

local function InventaireTotal(entity, ref)
    local total = SacTotal(entity, ref)
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if objetId and LCM.Objets and LCM.Objets.Equipes then
        for _, objet in ipairs(LCM.Objets.Equipes(entity) or {}) do
            if tostring(objet and objet.id or "") == objetId then total = total + 1 end
        end
    end
    return total
end
OutilsRequis.InventaireTotal = InventaireTotal

-- Un prérequis peut viser un objet précis ou un type entier de la « Liste
-- outils ». On réserve d'abord les objets précis, puis les types : un même
-- exemplaire ne peut satisfaire deux lignes à la fois. Le résultat contient
-- les références concrètes à user ou consommer après la tentative.
local function ResoudreOutils(entity, outils)
    local disponibles, choisis = {}, {}
    local function Stock(ref)
        if disponibles[ref] == nil then disponibles[ref] = InventaireTotal(entity, ref) end
        return disponibles[ref]
    end
    local function Ajouter(outil, ref, nombre, consomme)
        choisis[#choisis + 1] = { entree = ref, quantite = nombre,
            consomme = consomme > 0, consommeQuantite = consomme,
            expertise = outil.expertise }
        disponibles[ref] = Stock(ref) - nombre
    end
    local function Traiter(outil)
        local restant = math.max(1, math.floor(tonumber(outil.quantite) or 1))
        local aConsommer = outil.consomme and math.max(1, math.floor(tonumber(outil.consommeQuantite) or 1)) or 0
        local refs = {}
        if outil.typeOutil then
            for _, objet in ipairs(LCM.Objets.list or {}) do
                if objet.categorie == "outil" and objet.type == outil.typeOutil then
                    refs[#refs + 1] = "objets/" .. objet.id
                end
            end
            table.sort(refs)
        elseif outil.entree then
            refs[1] = outil.entree
        end
        for _, ref in ipairs(refs) do
            local nombre = math.min(restant, Stock(ref))
            if nombre > 0 then
                local consomme = math.min(nombre, aConsommer)
                Ajouter(outil, ref, nombre, consomme)
                restant, aConsommer = restant - nombre, aConsommer - consomme
            end
            if restant == 0 then break end
        end
        if restant > 0 then
            local typeDef = outil.typeOutil and LCM.Listes.Get(outil.typeOutil)
            local objet = outil.entree and LCM.Compendium.Resoudre(outil.entree)
            return false, tostring((typeDef and typeDef.label) or (objet and objet.label)
                or outil.typeOutil or outil.entree or "outil")
        end
        return true
    end
    for _, outil in ipairs(outils or {}) do
        if not outil.typeOutil then
            local ok, manque = Traiter(outil)
            if not ok then return nil, manque end
        end
    end
    for _, outil in ipairs(outils or {}) do
        if outil.typeOutil then
            local ok, manque = Traiter(outil)
            if not ok then return nil, manque end
        end
    end
    return choisis
end
OutilsRequis.Resoudre = ResoudreOutils

local function ConsommerOutil(entity, ref)
    if LCM.Inventaire.Prendre(entity, ref) then return true end
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if objetId and LCM.Objets and LCM.Objets.EstEquipe
            and LCM.Objets.EstEquipe(entity, objetId) then
        return LCM.Objets.Enlever(entity, objetId)
    end
    return false
end
OutilsRequis.Consommer = ConsommerOutil
