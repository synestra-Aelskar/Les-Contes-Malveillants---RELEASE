-- Vues : les fenetres qui montrent des morceaux de la fiche.
--
-- Une vue ne declare AUCUN champ : elle designe des parties du schema (un
-- onglet, une section, une liste de champs) et la fenetre les dessine avec les
-- lignes de la fiche. Les fenetres du template Necronicon (Fiche, Sante,
-- Expertises, Penetration & Resistances...) s'ecrivent ainsi dans
-- Data/Vues.lua, onglet par onglet, sans une ligne d'ecran.
--
-- L'identifiant d'une vue est celui de l'entree du menu qu'elle habille.
--
--   Vues.Add({ id = "fiche", titre = "Fiche", onglets = {
--       { id = "statistiques", label = "Statistiques", blocs = {
--           { label = "Générale", champs = { { id = "corps", zones = false }, "fatigue" } },
--           { section = { "general", "vitalite" } },     -- une section du schema
--           { onglet = "expertises" },                    -- toutes ses sections
--       } },
--   } })
--
-- Une vue sans onglets donne ses `blocs` directement.
--
-- Un champ se designe par son identifiant, ou par une table { id = ...,
-- option = valeur } : les options vont a la ligne qui le dessine (le corps
-- avec ou sans ses zones, par exemple).

local _, LCM = ...

local Vues = { list = {}, byId = {} }
LCM.Vues = Vues

local function Erreur(message)
    error("LCM/Vues : " .. tostring(message), 0)
end

-- Les catalogues qu'un conteneur peut designer, resolus a l'appel.
local CATALOGUES = {
    objets = function() return LCM.Objets end,
    etats = function() return LCM.Etats end,
    apprentissages = function() return LCM.Apprentissages end,
}

local function Onglet(id)
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        if tab.id == id then return tab end
    end
end

-- Un bloc -> des sections { label, fields, options }, celles que la fiche sait
-- dessiner. Resolu a la declaration : Data/Vues.lua se charge apres toute la
-- feuille, et une reference fausse doit casser au chargement, pas au premier
-- clic.
local function Resoudre(vueId, bloc, sections)
    if type(bloc) ~= "table" then Erreur(vueId .. " : bloc invalide") end
    local premiere = #sections + 1

    if bloc.conteneur then
        -- Un conteneur du template : { catalogue, categorie }. Ses
        -- emplacements sont ceux de l'equilibrage (Core/Catalogues.lua).
        local nom, categorieId = bloc.conteneur[1], bloc.conteneur[2]
        local catalogue = CATALOGUES[nom] and CATALOGUES[nom]()
        if not catalogue then Erreur(vueId .. " : catalogue inconnu « " .. tostring(nom) .. " »") end
        local categorie = catalogue.Categorie(categorieId)
        if not categorie then
            Erreur(string.format("%s : categorie « %s » absente du catalogue %s", vueId, tostring(categorieId), nom))
        end
        sections[#sections + 1] = {
            label = tostring(bloc.label or categorie.bloc or categorie.label), fields = {},
            conteneur = { catalogue = catalogue, categorie = categorieId },
        }

    elseif bloc.temporaires then
        -- Les etats poses par une action, pour quelques rounds
        -- (Core/EtatsTemporaires.lua) : pas d'emplacement, une ligne chacun.
        --
        -- On GARDE le nom du conteneur quand il est donne (« etat »,
        -- « maladie », « intangible ») : c'est le filtre de l'onglet. Il etait
        -- ecrase par `true`, et les trois onglets de la Sante montraient alors
        -- la meme liste entiere (12 octobre 2026).
        sections[#sections + 1] = { label = tostring(bloc.label or "États temporaires"),
            temporaires = type(bloc.temporaires) == "string" and bloc.temporaires or true,
            fields = {} }

    elseif bloc.texte then
        -- Un paragraphe (la description d'une fenetre du template).
        -- `taille` : la balise <taille=n> du template. Un texte vide garde le
        -- bloc : c'est un separateur seul (« [NF] - No Fatigue » des Regles).
        sections[#sections + 1] = { label = tostring(bloc.label or ""), texte = tostring(bloc.texte),
            taille = tonumber(bloc.taille), fields = {} }

    elseif bloc.onglet then
        local tab = Onglet(bloc.onglet)
        if not tab then Erreur(vueId .. " : onglet inconnu « " .. tostring(bloc.onglet) .. " »") end
        for _, section in ipairs(tab.sections) do sections[#sections + 1] = section end

    elseif bloc.section then
        local tabId, cle = bloc.section[1], bloc.section[2]
        local tab = Onglet(tabId)
        if not tab then Erreur(vueId .. " : onglet inconnu « " .. tostring(tabId) .. " »") end
        local trouvee
        -- Par identifiant de section d'abord ; le libelle reste accepte pour
        -- une section qui n'en a pas.
        for _, section in ipairs(tab.sections) do
            if section.id == cle or (not section.id and section.label == cle) then trouvee = section end
        end
        if not trouvee then
            Erreur(string.format("%s : section « %s » absente de l'onglet %s", vueId, tostring(cle), tabId))
        end
        -- Un libelle propre a la vue peut remplacer celui de la section.
        if bloc.label then
            sections[#sections + 1] = { id = trouvee.id, label = tostring(bloc.label), fields = trouvee.fields }
        else
            sections[#sections + 1] = trouvee
        end

    elseif bloc.champs then
        local fields, options = {}, {}
        for _, designation in ipairs(bloc.champs) do
            local fieldId = type(designation) == "table" and designation.id or designation
            local field = LCM.Schema.Field(fieldId)
            if not field then Erreur(vueId .. " : champ inconnu « " .. tostring(fieldId) .. " »") end
            fields[#fields + 1] = field
            if type(designation) == "table" then options[field.id] = designation end
        end
        sections[#sections + 1] = { label = tostring(bloc.label or ""), fields = fields, options = options }

    else
        Erreur(vueId .. " : un bloc designe un onglet, une section, des champs, un conteneur ou un texte")
    end

    -- Options de presentation, portees par chaque section produite (sans
    -- toucher aux sections du schema, partagees par toutes les vues) :
    --   recap = "total" | "bonus" : une ligne compacte par champ, avec sa
    --           valeur totale (toutes sources) ou ses seuls bonus portes ;
    --   replie = true | false : le bloc se replie d'un clic sur son titre, et
    --           s'ouvre replie (true) ou ouvert (false). Absent : il ne se
    --           replie pas.
    if bloc.recap or bloc.replie ~= nil then
        for index = premiere, #sections do
            local s = sections[index]
            local copie = {}
            for cle, valeur in pairs(s) do copie[cle] = valeur end
            copie.recap = bloc.recap
            copie.repliable, copie.replie = bloc.replie ~= nil, bloc.replie == true
            sections[index] = copie
        end
    end
end

local function Sections(vueId, blocs)
    local sections = {}
    for _, bloc in ipairs(blocs or {}) do Resoudre(vueId, bloc, sections) end
    return sections
end

function Vues.Add(definition)
    if type(definition) ~= "table" then Erreur("vue invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("vue sans identifiant") end
    if Vues.byId[id] then Erreur("vue en double : " .. id) end

    local vue = {
        id = id,
        titre = tostring(definition.titre or id),
        largeur = tonumber(definition.largeur) or 460,
        hauteur = tonumber(definition.hauteur) or 520,
        onglets = {},
        -- Une vue qui ne montre rien d'un personnage (les Regles) : pas de
        -- sous-titre, et elle s'ouvre meme sans personnage.
        sansPersonnage = definition.sansPersonnage == true,
        -- Ses chapitres a gauche, en sommaire, plutot qu'en bande d'onglets :
        -- c'est une vue qu'on lit, pas une qu'on remplit.
        sommaire = definition.sommaire == true,
        -- Tous les onglets cote a cote, la police reduite s'il le faut, au
        -- lieu de passer a la ligne.
        ongletsUneRangee = definition.ongletsUneRangee == true,
        groupes = definition.groupes,
    }
    if definition.onglets then
        for _, onglet in ipairs(definition.onglets) do
            local ongletId = tostring(onglet.id or "")
            if ongletId == "" then Erreur(id .. " : onglet sans identifiant") end
            local sections = Sections(id .. "/" .. ongletId, onglet.blocs)
            -- Un onglet vide est une erreur de saisie... sauf s'il est dit vide :
            -- le template en a (les Regles n'ont rempli que Fondamentaux).
            if #sections == 0 and not onglet.vide then Erreur(id .. " : onglet vide « " .. ongletId .. " »") end
            -- Sans libelle, l'onglet prend celui de son premier bloc : un
            -- chapitre du recapitulatif s'appelle comme la section qu'il montre,
            -- et le recopier ferait deux noms a tenir d'accord.
            local label = onglet.label or (sections[1] and sections[1].label ~= "" and sections[1].label) or ongletId
            vue.onglets[#vue.onglets + 1] = { id = ongletId, label = tostring(label), sections = sections,
                couleur = onglet.couleur, groupe = onglet.groupe }
        end
    else
        local sections = Sections(id, definition.blocs)
        if #sections > 0 then vue.onglets[1] = { id = "principal", label = vue.titre, sections = sections } end
    end
    if #vue.onglets == 0 then Erreur(id .. " : vue vide") end
    -- Raccourci : les sections du premier onglet (une vue simple n'a que lui).
    vue.sections = vue.onglets[1].sections

    Vues.byId[id] = vue
    Vues.list[#Vues.list + 1] = vue
    return vue
end

function Vues.Get(id)
    return Vues.byId[tostring(id or "")]
end
