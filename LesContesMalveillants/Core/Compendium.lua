-- Le compendium : une vue uniforme sur les registres de contenu.
--
-- Les categories (Data/Compendium.lua) sont figees dans le code ; leurs
-- entrees viennent des registres (Traits, Objets, Connaissances...). Ce
-- module ne stocke rien : il sait, pour une categorie, lister ses entrees,
-- ordonner ses champs, lire une valeur, la mettre en texte, composer la carte
-- d'une entree (en-tete, meta, corps, statistiques, pied) et regrouper les
-- entrees en sous-categories. La fenetre (UI/Compendium.lua) ne fait que
-- l'afficher ; l'editeur du MJ ne fait que l'enregistrer.
--
-- La composition de la carte reprend BuildEntryDisplayParts de Necronicon :
-- meme ordre, memes separateurs (« | » sur une ligne, saut de ligne en
-- en-tete et en pied), memes regles (une statistique nulle ne s'affiche pas).

local _, LCM = ...

local Compendium = { categories = {}, parId = {} }
LCM.Compendium = Compendium

-- Les types de categorie que le template utilise, dans l'ordre du filtre
-- « TYPES » de Necronicon. Ceux dont aucune categorie n'existe (sort,
-- grimoire, association...) ne sont pas repris. « Profile » et « Container »
-- traduits.
Compendium.TYPES = {
    { id = "generic",           label = "Générique" },
    { id = "currency",          label = "Devise" },
    { id = "knowledge",         label = "Connaissance" },
    { id = "list",              label = "Liste" },
    { id = "list_multiple",     label = "Liste multiple" },
    { id = "action_resolution", label = "Résolution d'action" },
    { id = "calculateur",       label = "Calculateur" },
    { id = "profile",           label = "Profil" },
    { id = "pnj",               label = "PNJ" },
    { id = "container",         label = "Conteneur" },
}
local TYPE_CONNU = {}
for _, t in ipairs(Compendium.TYPES) do TYPE_CONNU[t.id] = t end

-- Les emplacements d'un champ sur la carte (FIELD_SLOT_OPTIONS du template).
local EMPLACEMENTS = { header = true, meta = true, subtitle = true, body = true,
                       statistiques = true, footer = true, hidden = true }

local function Erreur(message) error("LCM/Compendium : " .. tostring(message), 0) end

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function Compendium.Categorie(def)
    if type(def) ~= "table" then Erreur("categorie invalide") end
    local id = Texte(def.id)
    if id == "" then Erreur("categorie sans identifiant") end
    if Compendium.parId[id] then Erreur("categorie en double : " .. id) end
    if not TYPE_CONNU[def.type] then Erreur(id .. " : type inconnu « " .. tostring(def.type) .. " »") end
    for _, champ in ipairs(def.champs or {}) do
        if not EMPLACEMENTS[champ.emplacement or "body"] then
            Erreur(id .. " : emplacement inconnu pour " .. tostring(champ.cle))
        end
    end
    def.id = id
    def.champs = def.champs or {}
    Compendium.parId[id] = def
    Compendium.categories[#Compendium.categories + 1] = def
    return def
end

function Compendium.Get(id) return Compendium.parId[tostring(id or "")] end

-- Le registre d'une categorie, resolu a l'appel (Core se charge avant Data).
function Compendium.Registre(categorie)
    return categorie and categorie.registre and LCM[categorie.registre] or nil
end

-- Les entrees d'une categorie, dans l'ordre de leur declaration (celui du
-- template, puis les entrees du MJ).
function Compendium.Entrees(categorie)
    if type(categorie) ~= "table" then return {} end
    if categorie.entrees then return categorie.entrees() end
    local registre = Compendium.Registre(categorie)
    local out = {}
    for _, element in ipairs(registre and registre.list or {}) do
        local visible = categorie.id ~= "traits" or LCM.Traits.EstAccessible(element.id)
        if visible and (not categorie.filtre or categorie.filtre(element)) then out[#out + 1] = element end
    end
    return out
end

function Compendium.Entree(categorie, id)
    for _, element in ipairs(Compendium.Entrees(categorie)) do
        if element.id == tostring(id or "") then return element end
    end
    return nil
end

function Compendium.Editable(categorie)
    return categorie ~= nil and categorie.famille ~= nil and categorie.lectureSeule == nil
end

-- ===== Les champs ==========================================================

local function LabelSchema(id)
    local field = LCM.Schema.Field(id)
    return field and field.label or id
end

-- Les cibles de bonus de la fiche (meme regle que l'atelier : ce qui se
-- lance, ce qui se compte, une jauge, un calcul qui l'accepte).
local function CiblesBonus()
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections) do
            for _, field in ipairs(section.fields) do
                local cible = field.kind == "stat" or field.kind == "roll"
                    or (field.kind == "gauge" and field.id ~= "armure" and not field.lire)
                    or (field.kind == "calc" and field.recoitBonus)
                if cible then out[#out + 1] = field.id end
            end
        end
    end
    return out
end

-- Le bloc de statistiques developpe en champs, plus un dossier « Autres »
-- pour les cibles que le template n'avait pas (points secondaires,
-- existence...) : sans lui, un bonus deja pose disparaitrait de l'ecran.
local blocDeveloppe
local function Bloc()
    if blocDeveloppe then return blocDeveloppe end
    blocDeveloppe = {}
    local dansLeBloc = {}
    for _, groupe in ipairs(Compendium.BLOC or {}) do
        for _, id in ipairs(groupe.champs) do
            dansLeBloc[id] = true
            if not groupe.masque then
                blocDeveloppe[#blocDeveloppe + 1] = {
                    cle = id, label = LabelSchema(id), type = "statistique",
                    emplacement = "statistiques", dossier = groupe.dossier,
                }
            end
        end
    end
    for _, id in ipairs(CiblesBonus()) do
        if not dansLeBloc[id] then
            blocDeveloppe[#blocDeveloppe + 1] = {
                cle = id, label = LabelSchema(id), type = "statistique",
                emplacement = "statistiques", dossier = "Autres",
            }
        end
    end
    return blocDeveloppe
end

-- Les champs d'une categorie, dans l'ordre des dossiers (GetOrdered-
-- CompendiumFields) : c'est l'ordre des colonnes et de l'editeur.
local cacheChamps = {}
function Compendium.Champs(categorie)
    if cacheChamps[categorie] then return cacheChamps[categorie] end
    local tous = {}
    for _, champ in ipairs(categorie.champs) do tous[#tous + 1] = champ end
    if categorie.statistiques == "bonus" then
        -- Une categorie peut porter son propre bloc (les tentes : securite,
        -- recuperations) quand celui de la fiche n'aurait personne a qui
        -- s'appliquer. La forge dose alors ces champs-la.
        for _, champ in ipairs(categorie.bloc or Bloc()) do tous[#tous + 1] = champ end
        for _, champ in ipairs(categorie.blocExtra or {}) do tous[#tous + 1] = champ end
    end
    local dossiers = categorie.dossiers or { "Général" }
    local parDossier, connus, ordre = {}, {}, {}
    for _, nom in ipairs(dossiers) do
        connus[nom] = true
        parDossier[nom] = {}
        ordre[#ordre + 1] = nom
    end
    for _, champ in ipairs(tous) do
        local nom = champ.dossier or "Général"
        if not connus[nom] then
            connus[nom] = true
            parDossier[nom] = {}
            ordre[#ordre + 1] = nom
        end
        table.insert(parDossier[nom], champ)
    end
    local out = {}
    for _, nom in ipairs(ordre) do
        for _, champ in ipairs(parDossier[nom]) do out[#out + 1] = champ end
    end
    cacheChamps[categorie] = out
    return out
end

-- Les dossiers de statistiques d'une categorie, dans l'ordre.
function Compendium.Dossiers(categorie)
    local out, vus = {}, {}
    for _, champ in ipairs(Compendium.Champs(categorie)) do
        if champ.type == "statistique" and not vus[champ.dossier] then
            vus[champ.dossier] = true
            out[#out + 1] = champ.dossier
        end
    end
    return out
end

-- ===== Valeurs =============================================================

-- La valeur brute d'un champ pour une entree.
function Compendium.Brut(categorie, champ, element)
    if type(element) ~= "table" then return nil end
    local lire = categorie.lire and categorie.lire[champ.cle]
    if lire then return lire(element) end
    if champ.type == "statistique" then
        local source = categorie.statistiques == "valeurs" and element.valeurs or element.bonus
        return type(source) == "table" and source[champ.cle] or nil
    end
    if champ.valeur then
        return type(element.valeurs) == "table" and element.valeurs[champ.cle] or nil
    end
    if champ.type == "avantage" then
        -- Son propre champ, et non `element.avantage` : depuis que le
        -- desavantage existe (24 octobre 2026), deux champs partagent ce type,
        -- et la carte montrait l'avantage dans les deux lignes.
        local out = {}
        for id in pairs(LCM.Effets.Ensemble(element[champ.cle])) do out[#out + 1] = id end
        table.sort(out)
        return out
    end
    local v = element[champ.cle]
    if v == nil then v = champ.defaut end
    return v
end

local function Nombre(v)
    local n = tonumber(v)
    if not n then return tostring(v or "") end
    if n == math.floor(n) then return string.format("%d", n) end
    return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end
Compendium.Nombre = Nombre

-- Les choix proposes par un champ « liste » : { id, label, icone }.
function Compendium.Options(champ)
    local source = tostring(champ.source or "")
    local out = {}
    local function Ajouter(liste)
        for _, e in ipairs(liste or {}) do
            out[#out + 1] = { id = e.id, label = e.label, icone = e.icone }
        end
    end
    local liste = source:match("^listes:(.+)$")
    local forge = source:match("^forge:(.+)$")
    if forge then
        for _, option in ipairs(LCM.Forge.Options(forge)) do out[#out + 1] = option end
    elseif liste then
        Ajouter(LCM.Listes.De(liste))
    elseif source == "metiers" then
        Ajouter(LCM.Metiers.list)
    elseif source == "morphologies" then
        Ajouter(LCM.Morphologies.list)
    elseif source == "races" then
        Ajouter(LCM.Races.list)
    elseif source == "traits" then
        Ajouter(LCM.Traits.Accessibles())
    elseif source == "accessoires_camping" then
        Ajouter(LCM.AccessoiresCamping.list)
    elseif source == "conteneurs_etats" then
        for _, c in ipairs(LCM.Etats.CATEGORIES) do
            out[#out + 1] = { id = c.id, label = c.id == "etat" and "États" or c.label }
        end
    elseif source == "etats" then
        for _, c in ipairs(LCM.Etats.CATEGORIES) do
            if c.id ~= "maladie" then out[#out + 1] = { id = c.id, label = c.label } end
        end
    end
    return out
end

-- Le libelle d'un choix ; un choix disparu reste visible, marque d'un « ? ».
-- Un type qui existe mais dans une AUTRE liste (une Boisson sur un outil
-- transfere) se nomme, et dit qu'il n'est pas a sa place : l'identifiant nu
-- ne disait rien au MJ (23 octobre 2026).
local function LibelleOption(champ, id)
    for _, option in ipairs(Compendium.Options(champ)) do
        if option.id == id then return option.label end
    end
    if tostring(champ.source or ""):match("^listes:") then
        local entree = LCM.Listes.Get(id)
        if entree then return "? " .. tostring(entree.label) .. " (pas dans cette liste)" end
    end
    return "? " .. tostring(id)
end

-- « famille/identifiant » -> l'element et sa categorie.
local FAMILLES = {
    objets = "Objets", livres = "Livres", cartes = "Cartes", traits = "Traits", races = "Races", etats = "Etats",
    apprentissages = "Apprentissages", sacs = "Sacs", ressources = "Ressources",
    devises = "Devises", informations = "Informations", listes = "Listes",
    connaissances = "Connaissances", resolutions = "Resolutions",
    calculateurs = "Calculateurs", pnj = "PNJ",
    tentes = "Tentes", accessoires_camping = "AccessoiresCamping",
    lanternes = "Lanternes", cristaux = "Cristaux", consommables = "Consommables",
    -- Les jeux d'equilibrage de la forge : du contenu, sans categorie a eux.
    jeux = "Forge",
}
Compendium.FAMILLES = FAMILLES

-- L'entree qui a quitte `famille` pour une autre en gardant son identifiant
-- (MJ/Transfert.lua), et sa nouvelle famille. Cherchee seulement quand la
-- reference ne repond plus : le cas ordinaire ne paie rien.
local function Transferee(famille, id)
    local ancienne = famille .. "/" .. id
    for autre, nom in pairs(FAMILLES) do
        local registre = autre ~= famille and LCM[nom]
        local element = registre and registre.Get and registre.Get(id)
        if element and type(element.transfertDe) == "table" then
            for _, ref in ipairs(element.transfertDe) do
                if ref == ancienne then return element, autre end
            end
        end
    end
    return nil
end

local function Trouver(ref)
    local famille, id = tostring(ref or ""):match("^([%w_]+)/(.+)$")
    local registre = famille and FAMILLES[famille] and LCM[FAMILLES[famille]]
    local element = registre and registre.Get(id)
    if not element and famille then element, famille = Transferee(famille, id) end
    return element, famille
end

function Compendium.Resoudre(ref)
    local element, famille = Trouver(ref)
    if not element then return nil end
    local id = element.id
    if famille == "traits" and not LCM.Traits.EstAccessible(id) then return nil end
    for _, categorie in ipairs(Compendium.categories) do
        if categorie.famille == famille and (not categorie.filtre or categorie.filtre(element)) then
            return element, categorie
        end
    end
    return element, nil
end

-- La reference d'aujourd'hui : « ressources/bandage » rend
-- « consommables/bandage » si l'entree a ete transferee, et toute autre
-- reference telle quelle. C'est elle qu'on range, et c'est par elle qu'on
-- compare deux piles.
function Compendium.Canonique(ref)
    local element, famille = Trouver(ref)
    if not element then return ref end
    return famille .. "/" .. element.id
end

-- Deux references qui designent la meme entree, l'une d'avant un transfert.
function Compendium.MemeEntree(a, b)
    if a == b then return true end
    if a == nil or b == nil then return false end
    return Compendium.Canonique(a) == Compendium.Canonique(b)
end

function Compendium.Reference(categorie, element)
    return tostring(categorie.famille or "") .. "/" .. tostring(element.id)
end

local function NomReference(ref)
    local element = Compendium.Resoudre(ref)
    return element and element.label or nil
end

-- Une valeur en texte. `mode` : "compact" (cellule du tableau), "full"
-- (carte, fenetre de valeur), "search".
function Compendium.Texte(categorie, champ, brut, mode)
    mode = mode or "compact"
    local t = champ.type
    if brut == nil then return "" end
    if t == "jauge" then
        if type(brut) ~= "table" then return "" end
        return Nombre(brut.courant) .. " / " .. Nombre(brut.max)
    elseif t == "liste" and tostring(champ.source or ""):match("^forge:") then
        -- La rarete du jeu, comme le champ la propose ; sinon le jeu et sa
        -- rarete par leur NOM. Les options ne connaissent que les jeux de la
        -- categorie : une entree transferee
        -- avec l'ancien jeu s'affichait « ? lcm_64a651_…/commun » (le MJ,
        -- 23 octobre 2026). Un jeu qui n'existe plus ne s'affiche pas.
        for _, option in ipairs(Compendium.Options(champ)) do
            if option.id == brut then return option.label end
        end
        local jeu, rarete = LCM.Forge.Lire(brut)
        if not jeu then return "" end
        return rarete and (jeu.label .. " · " .. rarete.label) or jeu.label
    elseif t == "liste" then
        local ids = type(brut) == "table" and brut or { brut }
        local out = {}
        for _, id in ipairs(ids) do
            if Texte(id) ~= "" then out[#out + 1] = LibelleOption(champ, id) end
        end
        return table.concat(out, ", ")
    elseif t == "avantage" then
        local out = {}
        for _, id in ipairs(brut) do out[#out + 1] = LabelSchema(id) end
        return table.concat(out, ", ")
    elseif t == "case" then
        return brut == true and "Oui" or ""
    elseif t == "nombre" or t == "statistique" then
        if tonumber(brut) == nil then return tostring(brut) end
        return Nombre(brut)
    elseif t == "table_niveaux" then
        return Texte(brut) ~= "" and "XP METIER" or ""
    elseif t == "entree" then
        if Texte(brut) == "" then return "" end
        return NomReference(brut) or ("? " .. tostring(brut))
    elseif t == "composants" then
        local out = {}
        for _, c in ipairs(brut) do
            out[#out + 1] = string.format("%s x%s", NomReference(c.ref) or "Composant introuvable", Nombre(c.quantite))
        end
        if mode == "compact" and #out > 2 then
            return string.format("%s / %s (+%d)", out[1], out[2], #out - 2)
        end
        return table.concat(out, mode == "full" and "\n" or " / ")
    elseif t == "prerequis" then
        local out = {}
        for _, p in ipairs(brut) do
            local texte = p.texte or NomReference(p.ref) or ("? " .. tostring(p.ref))
            out[#out + 1] = (mode == "full" and "• " or "") .. texte
        end
        return table.concat(out, mode == "full" and "\n" or " / ")
    elseif t == "injections" then
        local out = {}
        for _, inj in ipairs(brut) do
            out[#out + 1] = mode == "full" and (inj.nom .. " : " .. inj.description) or inj.nom
        end
        return table.concat(out, mode == "full" and "\n" or " / ")
    elseif t == "table_xp" then
        local out = {}
        for _, palier in ipairs(brut) do
            local nom = palier.niveau and string.format("%s %d", palier.nom, palier.niveau) or palier.nom
            local cumul = tonumber(palier.cumul)
            out[#out + 1] = nom .. " : " .. Nombre(palier.xp)
                .. (cumul and (" XP (" .. Nombre(cumul) .. " cumulés)") or "")
        end
        if mode == "compact" and #out > 2 then
            return string.format("%s / %s (+%d)", out[1], out[2], #out - 2)
        end
        return table.concat(out, mode == "full" and "\n" or " / ")
    elseif t == "feuilles" then
        local etapes = 0
        for _, feuille in ipairs(brut) do etapes = etapes + #(feuille.etapes or {}) end
        return string.format("%d feuille(s), %d étape(s)", #brut, etapes)
    elseif t == "calcul" then
        return string.format("%d ligne(s)", #brut)
    elseif t == "nombre_liste" then
        return tostring(#brut)
    elseif t == "liste_texte" then
        return table.concat(brut, mode == "full" and "\n" or ", ")
    elseif t == "contenu" then
        local out = {}
        for _, ids in pairs(brut) do
            for _, id in ipairs(ids) do
                local element = LCM.Objets.Get(id)
                out[#out + 1] = element and element.label or ("? " .. tostring(id))
            end
        end
        table.sort(out)
        return table.concat(out, ", ")
    end
    return tostring(brut)
end

-- ===== La carte d'une entree ==============================================

-- L'icone n'est pas une colonne : le tableau la pose a gauche de l'ID.
local function Colonne(champ)
    return champ.colonne ~= false and champ.cle ~= "avantage" and champ.type ~= "icone"
end

-- Les colonnes du tableau : tous les champs sauf le type interne, dans
-- l'ordre des dossiers ; ou, si la categorie le dit (`colonnesTableau`),
-- ceux-la seulement, dans cet ordre.
function Compendium.Colonnes(categorie)
    local out = {}
    if categorie.colonnesTableau then
        local parCle = {}
        for _, champ in ipairs(Compendium.Champs(categorie)) do parCle[champ.cle] = champ end
        for _, cle in ipairs(categorie.colonnesTableau) do
            local champ = parCle[cle]
            if champ and Colonne(champ) then out[#out + 1] = champ end
        end
        return out
    end
    for _, champ in ipairs(Compendium.Champs(categorie)) do
        if Colonne(champ) then out[#out + 1] = champ end
    end
    return out
end

-- La categorie a-t-elle une icone a montrer en tete de ligne ?
function Compendium.AIcone(categorie)
    for _, champ in ipairs(categorie.champs) do
        if champ.type == "icone" then return true end
    end
    return false
end

-- Les statistiques d'un PNJ : ses valeurs, rangees par section du schema.
local function StatistiquesPNJ(element)
    local items, index = {}, 0
    local valeurs = type(element.valeurs) == "table" and element.valeurs or {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections) do
            local premiers = true
            for _, field in ipairs(section.fields) do
                local v = valeurs[field.id]
                if field.id ~= "race" and field.id ~= "niveau" and tonumber(v) and tonumber(v) ~= 0 then
                    if premiers then index, premiers = index + 1, false end
                    items[#items + 1] = { label = field.label, valeur = Nombre(v),
                                          dossier = section.label ~= "" and section.label or tab.label,
                                          dossierIndex = index }
                end
            end
        end
    end
    return items
end

function Compendium.Carte(categorie, element)
    local sousTitre, entete, meta, pied, corps, stats = {}, {}, {}, {}, {}, {}
    local ic = LCM.IC.Description(element.ic)
    if ic ~= "" then corps[#corps + 1] = { titre="Propriétés IC", texte=ic } end
    local function Format(champ, valeur)
        if champ.libelle == false then return valeur end
        return string.format("%s : %s", champ.label, valeur)
    end
    for _, champ in ipairs(Compendium.Champs(categorie)) do
        if champ.type ~= "icone" and champ.carte ~= false and champ.emplacement ~= "hidden"
            and champ.emplacement ~= "statistiques"
        then
            local brut = Compendium.Brut(categorie, champ, element)
            local valeur = Texte(Compendium.Texte(categorie, champ, brut, "full"))
            if valeur ~= "" then
                local e = champ.emplacement or "body"
                if e == "subtitle" then
                    sousTitre[#sousTitre + 1] = valeur
                elseif e == "header" then
                    entete[#entete + 1] = Format(champ, valeur)
                elseif e == "meta" then
                    meta[#meta + 1] = Format(champ, valeur)
                elseif e == "footer" then
                    pied[#pied + 1] = Format(champ, valeur)
                else
                    local section = { titre = champ.libelle == false and "" or champ.label, texte = valeur }
                    if champ.type == "composants" then
                        section.composants = {}
                        for _, c in ipairs(brut) do
                            local source = Compendium.Resoudre(c.ref)
                            section.composants[#section.composants + 1] = {
                                ref = c.ref,
                                nom = source and source.label or "Composant introuvable",
                                icone = source and source.icone or LCM.Icone(nil),
                                quantite = Nombre(c.quantite),
                            }
                        end
                    end
                    corps[#corps + 1] = section
                end
            end
        end
    end
    -- Les statistiques : seulement ce qui a une valeur utile (un zero ne
    -- s'affiche pas), regroupe par dossier.
    if categorie.statistiques == "valeurs" then
        stats = StatistiquesPNJ(element)
    else
        local index, vus = 0, {}
        for _, champ in ipairs(Compendium.Champs(categorie)) do
            if champ.type == "statistique" and champ.carte ~= false then
                local brut = Compendium.Brut(categorie, champ, element)
                local n = tonumber(brut)
                if brut ~= nil and n ~= 0 then
                    if not vus[champ.dossier] then
                        index = index + 1
                        vus[champ.dossier] = index
                    end
                    stats[#stats + 1] = { label = champ.label, valeur = Compendium.Texte(categorie, champ, brut, "full"),
                                          dossier = champ.dossier or "", dossierIndex = vus[champ.dossier] }
                end
            end
        end
    end
    return {
        nom = tostring(element.label or element.id),
        icone = LCM.Icone(element.icone),
        couleurTitre = element.couleurTitre or LCM.COULEUR_TITRE,
        couleurFond = element.couleurFond or LCM.COULEUR_FOND,
        sousTitre = table.concat(sousTitre, "  |  "),
        entete = table.concat(entete, "\n"),
        meta = table.concat(meta, "  |  "),
        pied = table.concat(pied, "\n"),
        corps = corps,
        stats = stats,
    }
end

-- Ce que la recherche parcourt : nom, tags, et toutes les valeurs.
function Compendium.Recherche(categorie, element)
    local morceaux = { tostring(element.label or ""), tostring(element.tags or "") }
    for _, champ in ipairs(Compendium.Champs(categorie)) do
        if champ.type ~= "icone" then
            morceaux[#morceaux + 1] = Compendium.Texte(categorie, champ, Compendium.Brut(categorie, champ, element), "search")
        end
    end
    return table.concat(morceaux, " "):lower()
end

-- ===== Sous-categories =====================================================
-- Le champ `sousCategorie` d'une categorie regroupe ses entrees par valeur
-- (le « Type » des categories generiques, le metier des connaissances). Une
-- entree sans valeur va dans « Sans valeur ».

local SANS_VALEUR = "__sans_valeur__"

local function ChampSousCategorie(categorie)
    if not categorie.sousCategorie then return nil end
    for _, champ in ipairs(Compendium.Champs(categorie)) do
        if champ.cle == categorie.sousCategorie then return champ end
    end
    return nil
end

function Compendium.SousCategoriesDe(categorie, element)
    local champ = ChampSousCategorie(categorie)
    if not champ then return {} end
    local brut = Compendium.Brut(categorie, champ, element)
    local ids = type(brut) == "table" and brut or { brut }
    local out = {}
    for _, id in ipairs(ids) do
        if Texte(id) ~= "" then out[#out + 1] = { cle = "valeur:" .. tostring(id), label = LibelleOption(champ, id) } end
    end
    if #out == 0 then out[1] = { cle = SANS_VALEUR, label = "Sans valeur" } end
    return out
end

function Compendium.SousCategories(categorie)
    if not ChampSousCategorie(categorie) then return nil end
    local groupes, parCle = {}, {}
    for _, element in ipairs(Compendium.Entrees(categorie)) do
        for _, g in ipairs(Compendium.SousCategoriesDe(categorie, element)) do
            local groupe = parCle[g.cle]
            if not groupe then
                groupe = { cle = g.cle, label = g.label, nombre = 0 }
                parCle[g.cle] = groupe
                groupes[#groupes + 1] = groupe
            end
            groupe.nombre = groupe.nombre + 1
        end
    end
    table.sort(groupes, function(a, b) return a.label:lower() < b.label:lower() end)
    return groupes
end

function Compendium.DansSousCategorie(categorie, element, cle)
    if not cle then return true end
    for _, g in ipairs(Compendium.SousCategoriesDe(categorie, element)) do
        if g.cle == cle then return true end
    end
    return false
end

-- Combien d'entrees en tout (la carte du hub).
function Compendium.Total()
    local total = 0
    for _, categorie in ipairs(Compendium.categories) do total = total + #Compendium.Entrees(categorie) end
    return total
end
