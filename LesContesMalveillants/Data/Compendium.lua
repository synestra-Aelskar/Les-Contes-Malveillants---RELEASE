-- Le compendium « Systeme d'Aelskar » : ses categories, figees.
--
-- Releve du compendium du template (plugin Necronicon_System_Les_contes_
-- Malveillants_MJ, compendium « aelskar », 25 categories). Chaque categorie
-- garde son nom, son type, ses champs, leur emplacement sur la carte et leurs
-- dossiers, dans l'ordre du template. Ce qui change, et pourquoi :
--
--   * pas de « + Categorie », « + Champ », dossiers de champs ni transferts :
--     la structure est ici, pas dans la sauvegarde (CLAUDE.md, regle 1) ;
--   * « PNJ » et « Fiches PNJ » ne font qu'une categorie : un PNJ de l'addon
--     est une entree qui porte sa fiche (Core/Contenus.lua) ;
--   * le bloc de statistiques des categories generiques n'est pas recopie
--     champ par champ : ce sont les cibles de bonus de la fiche (le schema),
--     rangees dans les dossiers du template (BLOC ci-dessous) ;
--   * les quelques ajouts propres a l'addon (cout d'un trait, morphologie
--     d'une race, avantage...) sont signales la ou ils sont declares.
--
-- Une categorie dit d'ou viennent ses entrees (`registre`, et `filtre` quand
-- plusieurs categories partagent un registre) et sous quelle famille le MJ en
-- cree des brouillons (`famille`, voir MJ/Brouillons.lua).

local _, LCM = ...
local C = LCM.Compendium

-- ===== Le bloc de statistiques =============================================
-- Les dossiers des categories generiques du template (Traits), dans son
-- ordre. Les champs sont ceux de la fiche ; le libelle affiche est celui du
-- schema. Accents retablis dans les noms de dossiers du template
-- (« Resistances », « Athletismes »).

C.BLOC = {
    { dossier = "Statistiques", champs = { "force", "mystique", "perception", "adresse", "esprit", "constitution" } },
    { dossier = "Pénétrations", champs = {
        "pen_tranchant", "pen_perforant", "pen_contondant", "pen_feu", "pen_eau", "pen_vent", "pen_terre",
        "pen_esprit", "pen_pourriture", "pen_lumiere", "pen_ombre", "pen_desordre", "pen_ordre", "pen_vie", "pen_mort" } },
    { dossier = "Résistances", champs = {
        "resi_tranchant", "resi_perforant", "resi_contondant", "resi_feu", "resi_eau", "resi_vent", "resi_terre",
        "resi_esprit", "resi_pourriture", "resi_lumiere", "resi_ombre", "resi_vie", "resi_mort", "resi_ordre", "resi_desordre" } },
    { dossier = "Bonus", champs = { "pa", "fatigue", "depl_terrestre", "depl_nage", "initiative" } },
    { dossier = "Observations", champs = {
        "vue", "odorat_gout", "ouie", "toucher", "investigation", "elementaire", "cosmique", "pistage",
        "communication" } },
    { dossier = "Athlétismes", champs = {
        "puissance", "projection", "prise", "equilibre", "acrobaties", "escalade", "resistance", "endurance", "course", "nage" } },
    { dossier = "Filouteries", champs = {
        "discretion", "deguisement", "vol_a_la_tire", "crochetage", "escamotage", "evasion", "sabotage" } },
    { dossier = "Attaques & Défense", masque = true, champs = {
        "force_attaque", "mystique_attaque", "perception_attaque", "defense_constitution" } },
    { dossier = "Bouclier et Soin", masque = true, champs = {
        "force_bouclier", "mystique_bouclier", "constitution_bouclier", "mystique_soin", "constitution_soin" } },
    { dossier = "Buff", masque = true, champs = {
        "force_buff", "mystique_buff", "perception_buff", "constitution_buff", "duree_buff", "puissance_buff" } },
    { dossier = "Perce-Armure", masque = true, champs = { "force_perce_armure", "mystique_perce_armure", "perception_perce_armure" } },
    { dossier = "Brise-Armure", masque = true, champs = { "force_brise_armure", "mystique_brise_armure", "perception_brise_armure" } },
    { dossier = "Provocation", masque = true, champs = {
        "force_provocation", "constitution_provocation", "esprit_provocation", "mystique_provocation" } },
    { dossier = "Intimidation", masque = true, champs = {
        "force_intimidation", "constitution_intimidation", "esprit_intimidation", "mystique_intimidation" } },
    { dossier = "Saignement", masque = true, champs = { "force_saignement", "mystique_saignement", "perception_saignement" } },
    { dossier = "Empoisonnement", masque = true, champs = {
        "mystique_empoisonnement", "perception_empoisonnement", "constitution_empoisonnement" } },
    { dossier = "Debuff", masque = true, champs = {
        "force_debuff", "mystique_debuff", "perception_debuff", "constitution_debuff", "duree_debuff", "puissance_debuff" } },
    -- Engendre aussi, et pour la meme raison.
    { dossier = "Mécanique de défense", champs = (function()
        local out = {}
        for _, defense in ipairs(LCM.Equilibrage.defenses) do
            out[#out + 1] = LCM.Defenses.Field(defense.id)
        end
        return out
    end)() },
    -- Les mecaniques sont ENGENDREES depuis l'equilibrage, pas recopiees : la
    -- liste a la main avait derive, et « Peur » comme « Dot » tombaient dans
    -- le fourre-tout « Autres » faute d'etre ici (11 octobre 2026).
    { dossier = "Mécanique de compétence", champs = (function()
        local out = {}
        for _, mecanique in ipairs(LCM.Equilibrage.mecaniques) do
            out[#out + 1] = "meca_" .. mecanique.id
        end
        return out
    end)() },
}

-- Ordre des dossiers d'une categorie generique : celui du template, ou le
-- dossier « General » (icone, type, etat, description, metiers) vient juste
-- apres « Statistiques ». C'est aussi l'ordre des colonnes du tableau.
local DOSSIERS_GENERIQUES = { "Statistiques", "Général" }
for index = 2, #C.BLOC do
    if not C.BLOC[index].masque then
        DOSSIERS_GENERIQUES[#DOSSIERS_GENERIQUES + 1] = C.BLOC[index].dossier
    end
end

-- ===== Fabriques de champs =================================================

local function Icone()
    -- Toujours cachee sur la carte (le template la montre a cote du titre),
    -- toujours premiere colonne du tableau.
    return { cle = "icone", label = "Icone", type = "icone", emplacement = "meta", libelle = false }
end

local function Description(avecLibelle, typeChamp)
    return { cle = "description", label = "Description", type = typeChamp or "texte_long",
             emplacement = "body", libelle = avecLibelle == true }
end

-- Une categorie generique du template : Type (liste), Etat (jauge),
-- Description, Metier, et le bloc de statistiques.
local function Generique(def)
    local champs = { Icone() }
    if def.liste then
        champs[#champs + 1] = { cle = "type", label = "Type", type = "liste",
            source = "listes:" .. def.liste, emplacement = "header" }
    end
    local suite = {
        { cle = "etat", label = "Etat", type = "jauge", emplacement = "meta",
          defaut = def.etatDefaut or { courant = 100, max = 100 } },
        Description(true),
        { cle = "metiers", label = "Metier", type = "liste", source = "metiers", multiple = true, emplacement = "body" },
    }
    for _, champ in ipairs(suite) do champs[#champs + 1] = champ end
    for _, champ in ipairs(def.extras or {}) do champs[#champs + 1] = champ end
    -- Ajout de l'addon (3 octobre 2026) : le jeu d'equilibrage et la rarete
    -- de l'entree (Core/Forge.lua). Des qu'un jeu vise la categorie, le MJ
    -- doit en choisir un pour enregistrer, et le bareme s'applique.
    champs[#champs + 1] = { cle = "forge", label = "Forge", type = "liste", source = "forge:" .. def.id,
                            emplacement = "meta" }
    def.champs = champs
    def.statistiques = "bonus"
    -- Ecart au template (4 octobre 2026, demande du MJ) : le tableau ne
    -- montre que la description apres l'icone, l'ID et le nom, pas une
    -- colonne par statistique. Les statistiques se lisent dans « Voir ».
    def.colonnesTableau = def.colonnesTableau or { "description" }
    def.dossiers = def.dossiers or DOSSIERS_GENERIQUES
    def.sousCategorie = def.liste and "type" or nil
    def.type = "generic"
    -- L'avantage (relance, garde le meilleur) est une regle de l'addon, pas
    -- un champ du template : il a son onglet dans l'editeur et sa ligne en pied
    -- de carte, sans quoi il disparaitrait a la premiere modification.
    if def.avantage ~= false then
        champs[#champs + 1] = { cle = "avantage", label = "Avantage", type = "avantage", emplacement = "footer" }
        -- Son symetrique (le MJ, 24 octobre 2026) : les jets que cette entree
        -- fait relancer en gardant le PIRE. Avant, aucun champ ne le disait —
        -- c'est le signe du bonus qui l'imposait, et un etat qui retirait un
        -- point condamnait tous les jets de cette statistique.
        champs[#champs + 1] = { cle = "desavantage", label = "Désavantage",
                                type = "avantage", emplacement = "footer" }
    end
    return C.Categorie(def)
end

-- ===== Les categories, dans l'ordre du template ===========================

C.Categorie({
    id = "information", label = "Information", type = "generic",
    icone = "Interface\\ICONS\\eps_arc_door_waycrest_double",
    registre = "Informations", famille = "informations",
    dossiers = { "Général" },
    champs = { Icone(), Description(true, "texte") },
})

-- Les quatre listes de valeurs. « Table de niveaux » n'a de sens que pour les
-- metiers (la table XP METIER) ; le template la propose partout, vide.
local function Liste(id, label, listeId)
    C.Categorie({
        id = id, label = label, type = "list",
        registre = "Listes", famille = "listes",
        filtre = function(element) return element.liste == listeId end,
        defaut = { liste = listeId },
        champs = {
            Icone(), Description(false),
            -- Combien d'objets de CE type on peut porter a la fois. Vide : pas
            -- de limite. C'est ici et non dans le code : « une seule cape » est
            -- une decision de jeu, elle doit se regler en seance
            -- (10 octobre 2026).
            { cle = "maxEquipe", label = "Max équipé", type = "nombre", emplacement = "meta", min = 0 },
            { cle = "niveaux", label = "Table de niveaux", type = "table_niveaux", emplacement = "meta", carte = false },
        },
    })
end
Liste("type_armures", "Type Armures", "type_armures")
-- Les accessoires empruntaient la « Liste Armes », faute d'en avoir une : un
-- anneau se choisissait parmi des types d'armes (10 octobre 2026).
Liste("type_accessoires", "Type Accessoires", "type_accessoires")
Liste("liste_armes", "Liste Armes", "armes")
Liste("liste_outils", "Liste outils", "outils")
C.Categorie({
    id = "liste_type_etats", label = "Liste-Type-Etats", type = "list",
    registre = "Listes", famille = "listes",
    filtre = function(element) return element.liste == "type_etats" end,
    defaut = { liste = "type_etats" },
    champs = {
        { cle = "conteneur", label = "Type", type = "liste", source = "conteneurs_etats", emplacement = "meta" },
    },
})
Liste("liste_origine", "Liste origine", "origines")
Liste("liste_ressources", "Liste ressources", "ressources")
-- Ajout de l'addon (23 octobre 2026, le MJ) : les types de la categorie
-- Consommables.
Liste("liste_consommables", "Liste consommable", "consommables")

-- Les metiers sont figes dans Data/Metiers.lua (du code, pas du contenu de
-- seance) : la categorie les montre, le MJ ne les cree pas en jeu. Leur
-- table de niveaux est celle de l'equilibrage, la seule.
C.Categorie({
    id = "liste_metiers", label = "Liste métiers", type = "list",
    registre = "Metiers",
    lectureSeule = "les métiers sont figés dans le code (Data/Metiers.lua).",
    lire = { niveaux = function() return "xp_metier" end },
    champs = {
        Icone(), Description(false),
        { cle = "niveaux", label = "Table de niveaux", type = "table_niveaux", emplacement = "meta", carte = false },
    },
})

C.Categorie({
    id = "connaissances", label = "Connaissances", type = "knowledge",
    registre = "Connaissances", famille = "connaissances",
    sousCategorie = "metiers",
    dossiers = { "Général" },
    champs = {
        Icone(),
        { cle = "metiers", label = "Metier", type = "liste", source = "metiers", multiple = true, emplacement = "meta" },
        { cle = "niveau", label = "Niveau", type = "texte", emplacement = "meta" },
        Description(false),
        { cle = "composants", label = "Composants", type = "composants", emplacement = "body" },
        { cle = "prerequis", label = "Prerequis", type = "prerequis", emplacement = "body" },
        { cle = "fabrication", label = "Fabrication", type = "case", emplacement = "hidden", onglet = "fabrication" },
        { cle = "resultat", label = "Entree fabriquee", type = "entree", emplacement = "hidden", onglet = "fabrication" },
        { cle = "quantite", label = "Quantite fabriquee", type = "nombre", emplacement = "hidden", onglet = "fabrication", min = 1 },
        { cle = "apprenable", label = "Peut etre appris", type = "case", emplacement = "hidden", onglet = "fabrication" },
        { cle = "xp", label = "XP par fabrication", type = "nombre", emplacement = "meta", carte = false, min = 0 },
        { cle = "niveauRequis", label = "Niveau metier requis", type = "palier", emplacement = "meta", carte = false },
        { cle = "xpPlafond", label = "Plafond XP (niveau)", type = "palier", emplacement = "meta", carte = false },
    },
})

-- La table XP METIER est un chiffre d'equilibrage : elle vit dans
-- Data/Equilibrage.lua et nulle part ailleurs. Le compendium la montre.
C.Categorie({
    id = "table_xp", label = "Table xp", type = "list_multiple",
    entrees = function()
        return { { id = "xp_metier", label = "XP METIER", lignes = LCM.Equilibrage.metiers.paliers } }
    end,
    lectureSeule = "c'est un chiffre d'équilibrage : il vit dans Data/Equilibrage.lua.",
    colonnes = { { cle = "nom", label = "Niveau" }, { cle = "xp", label = "XP requis" } },
    champs = {
        Icone(),
        { cle = "lignes", label = "Lignes de la table", type = "table_xp", emplacement = "body", carte = false },
    },
})

local function Resolution(id, label, categorie)
    C.Categorie({
        id = id, label = label, type = "action_resolution",
        registre = "Resolutions", famille = "resolutions",
        filtre = function(element) return element.categorie == categorie end,
        defaut = { categorie = categorie },
        champs = {
            Icone(),
            { cle = "natures", label = "Natures gerees", type = "texte", emplacement = "meta" },
            { cle = "feuilles", label = "Options", type = "feuilles", emplacement = "hidden" },
        },
    })
end
-- « Systeme-Resolution-Action » est retiree le 4 octobre 2026 : toutes ses
-- entrees sont passees dans le code (Data/ActionsBoutons.lua, Data/
-- Receptions.lua), elle restait vide.

C.Categorie({
    id = "calculateurs", label = "Calculateur", type = "calculateur",
    registre = "Calculateurs", famille = "calculateurs",
    champs = {
        Icone(),
        { cle = "formule", label = "Formule du calcul", type = "texte_long", emplacement = "body", carte = false },
        { cle = "injections", label = "Injections attendues", type = "injections", emplacement = "body", carte = false },
        { cle = "lignes", label = "Lignes de calcul", type = "calcul", emplacement = "hidden" },
    },
})

C.Categorie({
    id = "sacs", label = "Sacs", type = "container",
    registre = "Sacs", famille = "sacs",
    dossiers = { "Général" },
    -- Tout dans un seul onglet : un sac a trois champs, les repartir sur deux
    -- onglets demandait un clic pour voir la moitie de si peu.
    ongletUnique = true,
    champs = {
        Icone(),
        -- « Slotcount » dans le template : libelle traduit.
        -- Sac ou sacoche : il faut choisir, et ce choix commande tout le
        -- rangement (ou l'on peut l'equiper, et ce qu'il peut contenir).
        { cle = "nature", label = "Nature", type = "choix", emplacement = "meta", obligatoire = true,
          -- Ceinture : ses emplacements s'AJOUTENT aux cases de base de la
          -- ceinture qu'on porte (13 octobre 2026).
          options = { { id = "sac", label = "Sac" }, { id = "sacoche", label = "Sacoche" },
                      { id = "ceinture", label = "Ceinture" } } },
        { cle = "places", label = "Emplacements", type = "nombre", emplacement = "meta", min = 1 },
        { cle = "placesDevise", label = "Emplacements devise", type = "nombre", emplacement = "meta", min = 0 },
    },
})

C.Categorie({
    id = "devises", label = "Devises", type = "currency",
    registre = "Devises", famille = "devises",
    champs = { Icone(), Description(false),
        -- Cochee : la monnaie se materialise en pile dans un sac, et retourne
        -- en bourse (Core/Bourse.lua). Decochee : elle n'est qu'un solde.
        { cle = "materiel", label = "Matériel", type = "case", emplacement = "meta" } },
})

-- Ajout de l'addon (3 octobre 2026) : les jeux d'equilibrage de la forge,
-- ranges juste avant les categories qu'ils equilibrent
-- (Core/Forge.lua). Ils se creent ici comme toute entree ; leur structure
-- (raretes, reglages par statistique) ne tient pas dans l'editeur a champs,
-- d'ou `editeur` : « Nouvelle entree » et la roue ouvrent l'equilibrage du
-- compagnon MJ (MJ/Forge.lua).
C.Categorie({
    id = "jeux_equilibrage", label = "Jeux d'équilibrage", type = "generic",
    registre = "Forge", famille = "jeux", editeur = "ForgeUI",
    dossiers = { "Général" },
    lire = {
        cible = function(jeu)
            local categorie = C.Get(jeu.categorie)
            return categorie and categorie.label or jeu.categorie
        end,
        raretes = function(jeu)
            local out = {}
            for _, r in ipairs(jeu.raretes or {}) do
                out[#out + 1] = string.format("|cff%s%s|r %d", r.couleur, r.label, r.points)
            end
            return table.concat(out, "  ·  ")
        end,
        reglages = function(jeu)
            local n = 0
            for _ in pairs(jeu.champs or {}) do n = n + 1 end
            return n
        end,
    },
    champs = {
        { cle = "cible", label = "Catégorie", type = "texte", emplacement = "meta" },
        { cle = "reglages", label = "Statistiques réglées", type = "nombre", emplacement = "meta" },
        { cle = "raretes", label = "Raretés", type = "texte", emplacement = "body" },
    },
})

Generique({ id = "ressources", label = "Ressources", liste = "ressources",
    registre = "Ressources", famille = "ressources", avantage = false })
-- Ajout de l'addon (23 octobre 2026, le MJ) : bandages, baumes et boissons
-- sortent des ressources. Leur Type se choisit dans la « Liste consommable »,
-- et un jeu d'equilibrage qui vise cette categorie les dose a la forge.
Generique({ id = "consommables", label = "Consommables", liste = "consommables",
    registre = "Consommables", famille = "consommables", avantage = false,
    -- L'etat pose a la consommation : resume sur la carte, regle dans la
    -- forge (son panneau « État posé »).
    extras = { { cle = "etatPose", label = "État posé", type = "texte", emplacement = "body", carte = true } },
    lire = {
        etatPose = function(element)
            local e = element.etatApplique
            if not e then return "Aucun" end
            local types = { etat = "État", maladie = "Maladie", intangible = "Intangible" }
            local duree = e.rounds and string.format("%d round(s)", e.rounds) or "jusqu'au retrait"
            return string.format("%s « %s », %s", types[e.conteneur] or e.conteneur,
                e.nom or element.label, duree)
        end,
    } })
-- Les criteres (23 octobre 2026, le MJ) : chaque jauge du personnage se dose
-- comme une statistique, avec son cout dans le jeu d'equilibrage
-- (Core/Consommation.lua). Ils passent en tete : c'est ce qu'un consommable
-- fait d'abord.
do
    local criteres = {}
    for _, critere in ipairs(LCM.Consommation.CRITERES) do
        criteres[#criteres + 1] = { cle = LCM.Consommation.Cle(critere.id), label = critere.label,
            type = "statistique", emplacement = "statistiques", dossier = "Critères" }
    end
    local categorie = C.Get("consommables")
    categorie.blocExtra = criteres
    local dossiers = { "Critères" }
    for _, nom in ipairs(DOSSIERS_GENERIQUES) do dossiers[#dossiers + 1] = nom end
    categorie.dossiers = dossiers
end

-- Armes, armures, accessoires : un seul registre (les objets), une
-- categorie fixe chacun. Le template donne a Armures et Accessoires la
-- « Liste Armes » pour Type : corrige en « Type Armures » pour les armures ;
-- les accessoires gardent la liste du template, faute d'une liste a eux.
local function Objet(id, label, categorie, liste, extras)
    Generique({ id = id, label = label, liste = liste,
        registre = "Objets", famille = "objets",
        filtre = function(element) return element.categorie == categorie end,
        defaut = { categorie = categorie }, extras = extras,
        etatDefaut = { courant = LCM.Equilibrage.forge.etatObjet.base,
                       max = LCM.Equilibrage.forge.etatObjet.base } })
end
Objet("armes", "Armes", "arme", "armes", {
    -- Ajout de l'addon (5 octobre 2026) : combien de mains l'arme demande.
    -- Une a une main laisse la place d'un bouclier ; une a deux mains prend
    -- les deux emplacements.
    { cle = "taille", label = "Emplacements", type = "nombre", emplacement = "meta",
      min = 1, max = 2, defaut = 1 },
})
Objet("armures", "Armures", "equipement", "type_armures", {
    -- Ajout de l'addon (2 octobre 2026) : ce qu'une piece porte vers la jauge
    -- #armure. Laisse vide, elle vaut Equilibrage.armure.parDefaut.
    { cle = "armure", label = "Armure", type = "nombre", emplacement = "meta", min = 0,
      defaut = LCM.Equilibrage.armure.parDefaut },
})
Objet("accessoires", "Accessoires", "accessoire", "type_accessoires")

-- Les livres sont du contenu lisible, independant de la forge et de l'equipement.
C.Categorie({
    id = "livres", label = "Livres", type = "generic", registre = "Livres",
    famille = "livres", editeur = "LivresUI", dossiers = { "Général" },
    lire = {
        format = function(livre) return livre.format == "note" and "Note" or "Livre" end,
        pages = function(livre) return livre.pages and #livre.pages or 0 end,
    },
    champs = {
        Icone(), Description(true),
        { cle = "format", label = "Format", type = "texte", emplacement = "meta" },
        { cle = "pages", label = "Pages", type = "nombre", emplacement = "meta" },
    },
})

-- Les outils ont leur propre liste de types et leur propre jeu de forge.
-- Chaque point attribué à un métier apporte +1 à son jet lorsqu'il est porté.
local bonusMetiers = {}
for _, metier in ipairs(LCM.Metiers.list) do
    bonusMetiers[#bonusMetiers + 1] = { cle = "metier:" .. metier.id,
        label = metier.label, type = "statistique", emplacement = "statistiques",
        dossier = "Métiers" }
end
local dossiersOutils = LCM.Copie(DOSSIERS_GENERIQUES)
dossiersOutils[#dossiersOutils + 1] = "Métiers"
Objet("outils", "Outils", "outil", "outils", {
    -- Ajout de l'addon (23 octobre 2026, le MJ) : ce qu'un outil peut
    -- contenir (Core/Contenants.lua). Resume ici, regle dans la forge.
    { cle = "contenantResume", label = "Contenant", type = "texte", emplacement = "body" },
})
local categorieOutils = C.Get("outils")
categorieOutils.lire = categorieOutils.lire or {}
categorieOutils.lire.contenantResume = function(element)
    local k = element.contenant
    if not k then return "Non" end
    -- « Boisson (Eau) » quand le type est restreint a quelques entrees.
    local types = {}
    for _, id in ipairs(k.types or {}) do
        local entree = LCM.Listes.Get(id)
        local seules = {}
        for _, ref in ipairs(k.entrees or {}) do
            local e = LCM.Compendium.Resoudre(ref)
            if e and e.type == id then seules[#seules + 1] = e.label end
        end
        types[#types + 1] = (entree and entree.label or id)
            .. (seules[1] and (" (" .. table.concat(seules, ", ") .. ")") or "")
    end
    local depart = k.depart and LCM.Compendium.Resoudre(k.depart)
    return string.format("%s — taille %d, %d par usage%s", types[1] and table.concat(types, ", ") or "tout",
        k.taille, k.retrait, depart and (", livré avec " .. depart.label) or "")
end
categorieOutils.blocExtra = bonusMetiers
categorieOutils.dossiers = dossiersOutils

-- Ajout de l'addon (22 octobre 2026) : la lanterne et ses cristaux, repris
-- du module Lanterne d'OmegaSurvive (Core/Lanternes.lua). Absents du
-- template. Les regles d'aura et les phrases du MJ s'enregistrent en texte, une
-- par ligne. Depuis le 23 octobre 2026, le MJ ne les ecrit plus a la main :
-- « Nouvelle entree » et « Forger » ouvrent le constructeur repris de Survive
-- (LesContesMalveillants_MJ/LumieresUI.lua), qui produit ce texte :
--   auras      « condition : commande » ou « condition : commande : phrase »,
--              condition parmi allumer, eteindre, vide, pause, reprise ; un
--              numero seul devient `.aura N` (posee) ou `.unaura N` (retiree) ;
--   phrases    une par ligne ; « phrase : eteindre » met en pause ET eteint ;
--   canaux     alerte, raid, groupe (ou le MJ parle).
local function ChampsLumiere()
    return {
        { cle = "aurasPosees", label = "Auras posées (condition : commande)", type = "texte_long", emplacement = "body", carte = false },
        { cle = "aurasRetirees", label = "Auras retirées (condition : commande)", type = "texte_long", emplacement = "body", carte = false },
        { cle = "canaux", label = "Canaux du MJ (alerte, raid, groupe)", type = "texte", emplacement = "meta", carte = false },
        { cle = "phrasesPause", label = "Phrases de pause (une par ligne)", type = "texte_long", emplacement = "body", carte = false },
        { cle = "phrasesReprise", label = "Phrases de reprise (une par ligne)", type = "texte_long", emplacement = "body", carte = false },
    }
end

local function Lumiere(def, propres)
    def.type = "generic"
    def.editeur, def.constructeur = "LumieresUI", true
    def.dossiers = { "Général" }
    def.champs = { Icone(), Description(true) }
    for _, champ in ipairs(propres) do def.champs[#def.champs + 1] = champ end
    -- Les regles d'aura et les phrases : la lanterne seule (le cristal est un
    -- combustible, on ne l'allume pas).
    if def.famille == "lanternes" then
        for _, champ in ipairs(ChampsLumiere()) do def.champs[#def.champs + 1] = champ end
    end
    def.colonnesTableau = def.colonnesTableau or { "description" }
    return C.Categorie(def)
end

Lumiere({
    id = "lanternes", label = "Lanternes",
    icone = "Interface\\ICONS\\inv_misc_trinket6oih_lanterna2",
    registre = "Lanternes", famille = "lanternes",
    -- Le multiplicateur de Survive valait 1 par defaut : une lanterne neuve
    -- consomme au rythme de son cristal.
    defaut = { multiplicateur = 1 },
}, {
    -- Hors de la carte (le MJ, 23 octobre 2026) : consulter une lanterne ou un
    -- cristal ne montre que son nom, son icone et sa description. Ses chiffres
    -- seraient des spoils.
    { cle = "multiplicateur", label = "Multiplicateur de consommation", type = "nombre", emplacement = "meta",
      min = 0, carte = false },
})

Lumiere({
    id = "cristaux", label = "Cristaux",
    icone = "Interface\\ICONS\\inv_enchanting_80_veiledcrystal",
    registre = "Cristaux", famille = "cristaux",
}, {
    { cle = "duree", label = "Durée (minutes)", type = "nombre", emplacement = "meta", min = 0, carte = false },
    -- Le seul chiffre montre : combien en tient une poignee, utile pour ranger.
    { cle = "pileMax", label = "Stack max", type = "nombre", emplacement = "meta", min = 1 },
})

-- Ajout de l'addon (10 octobre 2026) : le campement (Core/Campement.lua).
-- Absent du template ; les colonnes viennent de la feuille de calcul du MJ.
-- Le bloc de statistiques est celui du campement, en pourcentage entier, et
-- c'est lui que dose le jeu d'equilibrage — qui donne aussi la couleur et le
-- niveau de l'entree, d'ou l'absence de champs « Couleur » et « ILevel ».
local BLOC_CAMPEMENT = {}
for _, b in ipairs(LCM.CAMPEMENT_BONUS) do
    BLOC_CAMPEMENT[#BLOC_CAMPEMENT + 1] = { cle = b.cle, label = b.label .. " (%)", type = "statistique",
                                            emplacement = "statistiques", dossier = "Campement" }
end

local function Campement(def)
    def.type = "generic"
    def.statistiques = "bonus"
    def.bloc = BLOC_CAMPEMENT
    def.dossiers = { "Général", "Campement" }
    table.insert(def.champs, 1, Icone())
    def.champs[#def.champs + 1] = { cle = "origine", label = "Origine", type = "texte", emplacement = "meta" }
    def.champs[#def.champs + 1] = { cle = "forge", label = "Forge", type = "liste", source = "forge:" .. def.id,
                                    emplacement = "meta" }
    return C.Categorie(def)
end

Campement({
    id = "tentes", label = "Tentes",
    icone = "Interface\\ICONS\\spell_fire_fire",
    registre = "Tentes", famille = "tentes",
    champs = {
        { cle = "lits", label = "Lit max", type = "nombre", emplacement = "meta", min = 1 },
        { cle = "accessoiresMax", label = "Accessoires max", type = "nombre", emplacement = "meta", min = 0 },
        { cle = "accessoires", label = "Accessoires inclus", type = "liste", source = "accessoires_camping",
          multiple = true, emplacement = "body" },
    },
})

Campement({
    id = "accessoires_camping", label = "Accessoires de camping",
    icone = "Interface\\ICONS\\inv_misc_wrench_01",
    registre = "AccessoiresCamping", famille = "accessoires_camping",
    champs = { Description(true) },
})

-- Une race n'a pas de type d'arme.
Generique({ id = "races", label = "Races",
    registre = "Races", famille = "races",
    defaut = { morphology = "humanoide" },
    extras = {
        -- Ajout de l'addon : une race engendre le corps (Core/Body.lua).
        { cle = "morphology", label = "Morphologie", type = "liste", source = "morphologies", emplacement = "meta" },
        -- Ajout de l'addon (3 octobre 2026) : une race que seul le MJ donne.
        -- Un joueur ne la voit pas dans sa creation et ne peut pas la choisir.
        { cle = "mjSeulement", label = "Réservée au MJ", type = "case", emplacement = "meta" },
    } })

Generique({ id = "traits", label = "Traits",
    registre = "Traits", famille = "traits",
    extras = {
        -- Ajout de l'addon : le template mettait ce chiffre dans les tags.
        { cle = "cout", label = "Coût", type = "nombre", emplacement = "meta", min = 1, max = 4, defaut = 1 },
    } })

Generique({ id = "etats", label = "Etats", liste = "type_etats",
    registre = "Etats", famille = "etats",
    filtre = function(element) return LCM.Etats.Conteneur(element) ~= "maladie" end,
    defaut = { categorie = "etat" },
    })

Generique({ id = "maladies", label = "Maladies", liste = "type_etats",
    registre = "Etats", famille = "etats",
    filtre = function(element) return LCM.Etats.Conteneur(element) == "maladie" end,
    defaut = { categorie = "maladie" } })

Generique({ id = "apprentissages", label = "Apprentissage", liste = "armes",
    registre = "Apprentissages", famille = "apprentissages" })

Resolution("actions_mj", "Actions-MJ", "mj")

-- Le profil du template : dans Necronicon, un instantane de fenetres a
-- importer. Ici le profil EST le code : l'entree decrit ce que l'addon
-- reproduit (le menu des fenetres), sans rien a importer.
C.Categorie({
    id = "template", label = "TEMPLATE", type = "profile",
    entrees = function()
        local fenetres = {}
        local function Parcourir(noeuds)
            for _, n in ipairs(noeuds or {}) do
                if n.enfants then Parcourir(n.enfants) else fenetres[#fenetres + 1] = n.label end
            end
        end
        Parcourir(LCM.UI and LCM.UI.Menu and LCM.UI.Menu.STRUCTURE)
        return { {
            id = "template_fiche_lvl_5", label = "Template Fiche LVL 5 - Contes Malveillants V2",
            icone = "Interface\\Icons\\INV_Misc_Book_11",
            source = "Template Fiche LVL 5 - Contes Malveillants V2",
            fenetres = fenetres,
        } }
    end,
    lectureSeule = "le profil est le code de l'addon : il ne se modifie pas en jeu.",
    dossiers = { "Général" },
    champs = {
        Icone(),
        { cle = "source", label = "Profil source", type = "texte", emplacement = "meta" },
        { cle = "fenetres", label = "Fenetres", type = "nombre_liste", emplacement = "meta" },
        { cle = "fenetres", label = "Fenêtres reproduites", type = "liste_texte", emplacement = "body", colonne = false },
    },
})

-- PNJ et Fiches PNJ du template, fondus : un PNJ porte sa fiche. La carte
-- montre ce que la fiche repartit (rangé par sections du schema) et ce
-- qu'elle porte.
C.Categorie({
    id = "pnj", label = "PNJ", type = "pnj",
    registre = "PNJ", famille = "pnj",
    statistiques = "valeurs",
    dossiers = { "Général" },
    champs = {
        Icone(),
        { cle = "race", label = "Race", type = "liste", source = "races", emplacement = "meta", valeur = true },
        { cle = "niveau", label = "Niveau", type = "nombre", emplacement = "meta", valeur = true },
        Description(false),
        { cle = "traits", label = "Traits", type = "liste", source = "traits", multiple = true, emplacement = "body" },
        { cle = "equipement", label = "Équipement", type = "contenu", source = "objets", emplacement = "body" },
    },
})
