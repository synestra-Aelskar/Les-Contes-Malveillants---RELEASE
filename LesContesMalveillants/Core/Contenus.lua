-- Contenus : ce que le compendium range, et la forme commune des entrees.
--
-- Toute entree du compendium du template a le meme onglet « General » : un
-- nom, une icone, une description, des tags, une couleur de titre et de fond,
-- une pile maximale. Les categories generiques y ajoutent un « Type » (pris
-- dans une liste), des metiers et une jauge d'etat. Plutot que de recopier
-- ces regles dans chaque registre, `LCM.ChampsCommuns` les tient une fois : Traits,
-- Races, catalogues et registres de ce fichier l'appellent tous.
--
-- Ce fichier pose aussi les familles que l'addon n'avait pas encore :
-- informations, listes, devises, ressources, connaissances, resolutions
-- d'action, calculateurs, PNJ. Chacune est un registre (Construire / Add / Get
-- / Retirer), rempli par les fichiers generes et par ce que le MJ enregistre.

local _, LCM = ...

local ICONE_DEFAUT = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Une icone du jeu : un nom court (« INV_Sword_05 ») ou un chemin complet.
function LCM.Icone(valeur)
    valeur = tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if valeur == "" then return ICONE_DEFAUT end
    -- Le navigateur d'icones et LibRPMedia rendent aussi des chemins avec /.
    -- Les normaliser avant de reconnaitre un chemin complet evite de lui
    -- ajouter une seconde fois Interface\Icons (texture verte en jeu).
    valeur = valeur:gsub("/", "\\")
    if not valeur:find("\\") then valeur = "Interface\\Icons\\" .. valeur end
    return valeur
end

local function Texte(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Couleurs par defaut des entrees du template (titre ivoire, fond presque
-- noir) : une couleur egale au defaut n'est pas retenue.
LCM.COULEUR_TITRE = "F2E6C6"
LCM.COULEUR_FOND = "111111"

local function Couleur(id, nom, valeur, defaut, Erreur)
    if valeur == nil or valeur == "" then return nil end
    local hexa = Texte(valeur):gsub("^#", ""):upper()
    if not hexa:match("^%x%x%x%x%x%x$") then
        Erreur(string.format("%s : couleur de %s illisible (%s), attendu RRVVBB", id, nom, tostring(valeur)))
    end
    if hexa == defaut then return nil end
    return hexa
end

local function Entier(id, nom, valeur, minimum, Erreur)
    if valeur == nil or valeur == "" then return nil end
    local n = tonumber(valeur)
    if not n or n ~= math.floor(n) or n < minimum then
        Erreur(string.format("%s : %s invalide (%s)", id, nom, tostring(valeur)))
    end
    return n
end

-- Copie une liste d'identifiants (des chaines), en refusant ce qui n'en est pas.
local function ListeIds(id, nom, valeur, Erreur)
    if valeur == nil then return nil end
    if type(valeur) ~= "table" then Erreur(id .. " : " .. nom .. " doit etre une liste") end
    local out = {}
    for _, v in ipairs(valeur) do
        local s = Texte(v)
        if s ~= "" then out[#out + 1] = s end
    end
    return #out > 0 and out or nil
end

-- Les champs de l'onglet General, et ceux que toute categorie generique du
-- template porte. Lus depuis `definition`, poses sur `element`.
function LCM.ChampsCommuns(definition, element, Erreur)
    local id = element.id
    element.description = tostring(definition.description or "")
    element.icone = LCM.Icone(definition.icone)
    local tags = Texte(definition.tags)
    element.tags = tags ~= "" and tags or nil
    element.couleurTitre = Couleur(id, "titre", definition.couleurTitre, LCM.COULEUR_TITRE, Erreur)
    element.couleurFond = Couleur(id, "fond", definition.couleurFond, LCM.COULEUR_FOND, Erreur)
    element.pileMax = Entier(id, "pile maximale", definition.pileMax, 1, Erreur)
    local typ = Texte(definition.type)
    element.type = typ ~= "" and typ or nil
    element.metiers = ListeIds(id, "metiers", definition.metiers, Erreur)
    -- Le jeu d'equilibrage et la rarete d'une entree forgee (« jeu/rarete »,
    -- Core/Forge.lua). Garde tel quel : c'est la forge qui juge, a
    -- l'enregistrement d'une entree, pas le chargement.
    local forge = Texte(definition.forge)
    element.forge = forge ~= "" and forge or nil
    -- Les references qu'une entree a portees avant d'etre transferee d'une
    -- famille a une autre (« ressources/bandage » devenu un consommable,
    -- MJ/Transfert.lua). Un sac, un coffre ou une recette qui tient encore
    -- l'ancienne la retrouve par elle : un transfert ne fait rien disparaitre.
    if definition.transfertDe ~= nil then
        if type(definition.transfertDe) ~= "table" then Erreur(id .. " : transfertDe doit etre une liste") end
        local refs = {}
        for _, ref in ipairs(definition.transfertDe) do
            if not tostring(ref):match("^[%w_]+/.+$") then
                Erreur(id .. " : ancienne reference illisible « " .. tostring(ref) .. " »")
            end
            refs[#refs + 1] = tostring(ref)
        end
        element.transfertDe = refs[1] and refs or nil
    end
    -- La jauge « Etat » (durabilite d'un objet...). Un courant au-dessus du
    -- maximum est refuse, pas rabote : c'est au MJ de trancher.
    if definition.etat ~= nil then
        local e = definition.etat
        if type(e) ~= "table" then Erreur(id .. " : etat doit etre { courant, max }") end
        local maximum = tonumber(e.max)
        local courant = tonumber(e.courant or e.max)
        if not maximum or maximum < 0 or not courant or courant < 0 then
            Erreur(id .. " : jauge d'etat illisible")
        end
        if courant > maximum then
            Erreur(string.format("%s : etat %s au-dessus de son maximum %s", id, tostring(courant), tostring(maximum)))
        end
        element.etat = { courant = courant, max = maximum }
    end
    return element
end

-- ===== Registre simple =====================================================
-- Le meme contrat que Traits ou les catalogues : `Construire` verifie et met
-- en forme sans enregistrer (c'est la porte de l'atelier), `Add` enregistre,
-- `Retirer` ne sert qu'aux entrees supprimees en seance.
--
--   LCM.Registre({ nom = "devise", prefixe = "Devises",
--                  construire = function(definition, element, Erreur) ... end })

function LCM.Registre(def)
    local R = { list = {}, byId = {}, nom = def.nom }
    local prefixe = "LCM/" .. (def.prefixe or def.nom) .. " : "
    local function Erreur(message) error(prefixe .. tostring(message), 0) end
    R.Erreur = Erreur

    function R.Construire(definition)
        if type(definition) ~= "table" then Erreur(def.nom .. " invalide") end
        local id = Texte(definition.id)
        if id == "" then Erreur(def.nom .. " sans identifiant") end
        local element = { id = id, label = tostring(definition.label or id) }
        LCM.ChampsCommuns(definition, element, Erreur)
        if def.construire then def.construire(definition, element, Erreur) end
        return element
    end

    function R.Add(definition)
        local element = R.Construire(definition)
        if R.byId[element.id] then Erreur(def.nom .. " en double : " .. element.id) end
        R.byId[element.id] = element
        R.list[#R.list + 1] = element
        return element
    end

    function R.Get(id) return R.byId[tostring(id or "")] end

    function R.Retirer(id)
        id = tostring(id or "")
        if not R.byId[id] then return false end
        R.byId[id] = nil
        for index = #R.list, 1, -1 do
            if R.list[index].id == id then table.remove(R.list, index) end
        end
        return true
    end
    return R
end

-- Publie une definition issue de l'atelier. Les fichiers generes sont charges
-- apres le contenu importe : une entree corrigee en jeu peut donc porter le
-- meme identifiant que sa version precedente. `Add` doit continuer a refuser
-- les vrais doublons ; seule cette porte explicite remplace une version deja
-- publiee, sur place, afin de ne pas casser les references tenues par l'UI.
local function Publier(registre, definition)
    if type(registre) ~= "table" or type(registre.Construire) ~= "function"
        or type(registre.Add) ~= "function" or type(registre.Get) ~= "function" then
        error("LCM/Publication : registre invalide", 0)
    end

    local neuf = registre.Construire(definition)
    local existant = registre.Get(neuf.id)
    if not existant then
        existant = registre.Add(definition)
    else
        for cle in pairs(existant) do existant[cle] = nil end
        for cle, valeur in pairs(neuf) do existant[cle] = valeur end
    end
    if type(registre.ActualiserRegles) == "function" then
        registre.ActualiserRegles(existant)
    end
    return existant
end

-- Une entree refusee est ECARTEE, avec sa raison, et le fichier continue. Le
-- refus remontait jusqu'au fichier genere et l'arretait net : un coffre qui
-- citait un objet absent de la base faisait disparaitre toutes les entrees
-- ecrites apres lui (15 octobre 2026). Une base commune se nourrit de
-- plusieurs MJ ; une entree fautive ne doit couter qu'elle-meme.
function LCM.Publier(registre, definition)
    local ok, resultat = pcall(Publier, registre, definition)
    if ok then return resultat end
    LCM.Erreur(string.format("entrée écartée (%s) : %s",
        tostring(type(definition) == "table" and definition.id or "?"), tostring(resultat)))
    return nil
end

-- Les definitions du fichier public genere servent aussi de source aux MJ
-- pour la synchronisation entre addons. Aucune entree du compagnon MJ ne passe
-- par cette porte.
LCM.SourcePublique = {}
function LCM.PublierPublique(registre, famille, definition, revision)
    local element = LCM.Publier(registre, definition)
    if not element then return nil end
    local cle =tostring(famille) .. "/" .. tostring(definition.id)
    LCM.SourcePublique[cle] = {
        famille = famille, definition = LCM.Copie(definition), revision = revision,
    }
    return element
end

-- Une copie profonde : une entree du MJ ou un fichier genere ne doit partager
-- aucune table avec ce qu'on enregistre.
local function Copie(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Copie(x) end
    return out
end
LCM.Copie = Copie

local function Vrai(v) return v == true or v == 1 or v == "1" or v == "true" or v == "oui" end

-- ===== Les familles ========================================================

-- « Information » : une fiche de texte (la grosse porte qui semble tenir).
LCM.Informations = LCM.Registre({ nom = "information", prefixe = "Informations" })

-- « Devises » : une monnaie, son icone, sa description.
--
-- « Materiel » : cette monnaie a une forme. Des pieces, un lingot, une fiole
-- d'essence — quelque chose qui se porte, se pose dans un coffre et se vole.
-- Cochee, elle peut quitter la bourse pour une case de sac et y revenir
-- (Core/Bourse.lua, le MJ du 19 octobre 2026). Sans la case, elle n'existe
-- qu'en solde.
LCM.Devises = LCM.Registre({ nom = "devise", prefixe = "Devises",
    construire = function(definition, element)
        element.materiel = Vrai(definition.materiel) or nil
    end })

-- Les listes de valeurs du template (« Type Armures », « Liste Armes »,
-- « Liste origine », « Liste ressources ») : les choix proposes par le champ
-- « Type » des categories generiques. La liste des metiers, elle, est le
-- registre des metiers (Core/Metiers.lua).
LCM.LISTES = {
    { id = "type_armures", label = "Type Armures" },
    -- Les accessoires empruntaient la « Liste Armes », faute d'en avoir une :
    -- un anneau se choisissait parmi des types d'armes (10 octobre 2026).
    { id = "type_accessoires", label = "Type Accessoires" },
    { id = "armes",        label = "Liste Armes" },
    { id = "outils",       label = "Liste outils" },
    { id = "origines",     label = "Liste origine" },
    { id = "ressources",   label = "Liste ressources" },
    -- Ajout de l'addon (23 octobre 2026, le MJ) : les types de consommables
    -- (bandage, baume, boisson) quittent la liste des ressources pour la leur.
    { id = "consommables", label = "Liste consommable" },
}
local LISTE_CONNUE = {}
for _, l in ipairs(LCM.LISTES) do LISTE_CONNUE[l.id] = l end

LCM.Listes = LCM.Registre({
    nom = "entree de liste", prefixe = "Listes",
    construire = function(definition, element, Erreur)
        local liste = Texte(definition.liste)
        if not LISTE_CONNUE[liste] then
            Erreur(element.id .. " : liste inconnue « " .. liste .. " »")
        end
        element.liste = liste
        -- « Table de niveaux » du template : la seule qui existe est la table
        -- XP METIER de l'equilibrage.
        local niveaux = Texte(definition.niveaux)
        if niveaux ~= "" and niveaux ~= "xp_metier" then
            Erreur(element.id .. " : table de niveaux inconnue « " .. niveaux .. " »")
        end
        element.niveaux = niveaux ~= "" and niveaux or nil
        -- Combien d'objets de ce TYPE on peut porter a la fois (« une seule
        -- cape »). Vide : pas de limite. C'est une decision de jeu, portee par
        -- l'entree de type pour se regler en seance (10 octobre 2026).
        local max = tonumber(definition.maxEquipe)
        if definition.maxEquipe ~= nil and Texte(definition.maxEquipe) ~= "" then
            if not max or max < 0 or max ~= math.floor(max) then
                Erreur(element.id .. " : max equipe invalide (" .. tostring(definition.maxEquipe) .. ")")
            end
            element.maxEquipe = max > 0 and max or nil
        end
    end,
})

-- Les entrees d'une liste, dans leur ordre de declaration.
function LCM.Listes.De(listeId)
    local out = {}
    for _, element in ipairs(LCM.Listes.list) do
        if element.liste == listeId then out[#out + 1] = element end
    end
    return out
end

-- « Ressources » : une matiere (un brochet, de l'eau), son type, les metiers
-- qui s'en servent, et le bloc de statistiques du template. Rien ne « porte »
-- une ressource : ses effets sont declares (et verifies) mais ne s'appliquent
-- a personne.
LCM.Ressources = LCM.Registre({
    nom = "ressource", prefixe = "Ressources",
    construire = function(definition, element, Erreur)
        element.bonus, element.avantage = LCM.Effets.Lire(element.id, definition, Erreur, true)
    end,
})
LCM.Effets.Source("ressource", function() return {} end, function() return LCM.Ressources.list end)

-- « Consommables » (23 octobre 2026, le MJ, hors template) : ce qui se
-- consomme — un bandage, un baume, une boisson. Ils vivaient parmi les
-- ressources ; ils ont maintenant leur famille, leur liste de types et leur
-- jeu de forge. Meme forme que les ressources : ce qu'un consommable fait en
-- etant consomme n'existe pas encore, ses effets sont declares sans
-- s'appliquer a personne.
--
-- Depuis le 23 octobre 2026, ils se forgent par CRITERES et font quelque
-- chose quand on les consomme (Core/Consommation.lua). `etatApplique` : l'etat
-- pose a la consommation, ou rien — { conteneur = "etat" | "maladie" |
-- "intangible", nom, description, rounds (vide : jusqu'a ce qu'on le retire) }.
LCM.Consommables = LCM.Registre({
    nom = "consommable", prefixe = "Consommables",
    construire = function(definition, element, Erreur)
        element.bonus, element.avantage = LCM.Effets.Lire(element.id, definition, Erreur, true)
        local etat = definition.etatApplique
        if etat ~= nil then
            if type(etat) ~= "table" then Erreur(element.id .. " : etat pose illisible") end
            local conteneur = Texte(etat.conteneur)
            if conteneur ~= "etat" and conteneur ~= "maladie" and conteneur ~= "intangible" then
                Erreur(element.id .. " : type d'etat inconnu « " .. conteneur .. " »")
            end
            local rounds
            if etat.rounds ~= nil and Texte(etat.rounds) ~= "" then
                rounds = tonumber(etat.rounds)
                if not rounds or rounds < 1 or rounds ~= math.floor(rounds) then
                    Erreur(element.id .. " : duree de l'etat illisible (" .. tostring(etat.rounds)
                        .. "), attendu un nombre entier de rounds")
                end
            end
            local nom = Texte(etat.nom)
            element.etatApplique = { conteneur = conteneur, nom = nom ~= "" and nom or nil,
                description = Texte(etat.description) ~= "" and tostring(etat.description) or nil,
                rounds = rounds }
        end
    end,
})

-- Verifie a l'ENREGISTREMENT, pas au chargement : un consommable deja publie
-- ne disparait pas du jeu parce que la regle est venue apres lui.
function LCM.Consommables.VerifierEnregistrement(element)
    if element.etatApplique then return true end
    for cle in pairs(element.bonus or {}) do
        if not LCM.Consommation.Critere(cle) then
            return false, "les bonus de statistiques d'un consommable passent par l'état qu'il pose : "
                .. "coche « Pose un état », ou retire ces bonus"
        end
    end
    return true
end
LCM.Effets.Source("consommable", function() return {} end, function() return LCM.Consommables.list end)

-- « Connaissances » : une recette de metier. Composants et resultat
-- designent des entrees du compendium par « famille/identifiant »
-- (`objets/dague`), ou par une reference Necronicon gardee telle quelle
-- (`necronicon/...`) quand l'entree n'a pas ete importee.
LCM.Connaissances = LCM.Registre({
    nom = "connaissance", prefixe = "Connaissances",
    construire = function(definition, element, Erreur)
        local id = element.id
        local niveau = Texte(definition.niveau)
        element.niveau = niveau ~= "" and niveau or nil
        element.composants = {}
        for _, c in ipairs(definition.composants or {}) do
            local ref = Texte(type(c) == "table" and c.ref)
            if ref == "" then Erreur(id .. " : composant sans reference") end
            local quantite = tonumber(c.quantite or 1)
            if not quantite or quantite < 1 or quantite ~= math.floor(quantite) then
                Erreur(id .. " : quantite de composant invalide (" .. tostring(c.quantite) .. ")")
            end
            element.composants[#element.composants + 1] = { ref = ref, quantite = quantite }
        end
        element.prerequis = {}
        for _, p in ipairs(definition.prerequis or {}) do
            if type(p) ~= "table" then Erreur(id .. " : prerequis illisible") end
            local ref, texte = Texte(p.ref), Texte(p.texte)
            if ref ~= "" then element.prerequis[#element.prerequis + 1] = { ref = ref }
            elseif texte ~= "" then element.prerequis[#element.prerequis + 1] = { texte = texte } end
        end
        element.fabrication = Vrai(definition.fabrication)
        local resultat = Texte(definition.resultat)
        element.resultat = resultat ~= "" and resultat or nil
        local quantite = tonumber(definition.quantite or 1)
        if not quantite or quantite < 1 or quantite ~= math.floor(quantite) then
            Erreur(id .. " : quantite fabriquee invalide (" .. tostring(definition.quantite) .. ")")
        end
        element.quantite = quantite
        element.apprenable = Vrai(definition.apprenable)
        local xp = tonumber(definition.xp or 0)
        if not xp or xp < 0 then Erreur(id .. " : XP par fabrication invalide") end
        element.xp = xp
        local requis, plafond = Texte(definition.niveauRequis), Texte(definition.xpPlafond)
        element.niveauRequis = requis ~= "" and requis or nil
        element.xpPlafond = plafond ~= "" and plafond or nil
    end,
})

-- « Systeme-Resolution-Action » et « Actions-MJ » : le cheminement d'une
-- action (feuilles d'etapes, branches, options). Il n'existe pas encore de
-- moteur pour les jouer : ce sont des donnees, relues et editees par le
-- compendium. Les clefs des etapes sont celles de Necronicon, gardees telles
-- quelles pour que le moteur a venir lise la meme chose.
LCM.RESOLUTION_CATEGORIES = { systeme = true, mj = true }
LCM.Resolutions = LCM.Registre({
    nom = "resolution", prefixe = "Resolutions",
    construire = function(definition, element, Erreur)
        local categorie = Texte(definition.categorie)
        if categorie == "" then categorie = "systeme" end
        if not LCM.RESOLUTION_CATEGORIES[categorie] then
            Erreur(element.id .. " : categorie inconnue « " .. categorie .. " »")
        end
        element.categorie = categorie
        local natures = Texte(definition.natures)
        element.natures = natures ~= "" and natures or nil
        element.emission = Vrai(definition.emission)
        element.debug = Vrai(definition.debug)
        if definition.feuilles ~= nil and type(definition.feuilles) ~= "table" then
            Erreur(element.id .. " : feuilles illisibles")
        end
        element.feuilles = Copie(definition.feuilles or {})
        for index, feuille in ipairs(element.feuilles) do
            if type(feuille) ~= "table" then Erreur(element.id .. " : feuille " .. index .. " illisible") end
            feuille.etapes = type(feuille.etapes) == "table" and feuille.etapes or {}
        end
    end,
})

-- « Calculateur » : une formule, les injections qu'elle attend, et ses
-- lignes de calcul (operandes, operation). Donnees seulement, comme les
-- resolutions.
LCM.Calculateurs = LCM.Registre({
    nom = "calculateur", prefixe = "Calculateurs",
    construire = function(definition, element, Erreur)
        element.formule = tostring(definition.formule or "")
        element.injections = {}
        for _, inj in ipairs(definition.injections or {}) do
            if type(inj) ~= "table" then Erreur(element.id .. " : injection illisible") end
            element.injections[#element.injections + 1] = {
                nom = Texte(inj.nom), description = tostring(inj.description or ""),
            }
        end
        if definition.lignes ~= nil and type(definition.lignes) ~= "table" then
            Erreur(element.id .. " : lignes illisibles")
        end
        element.lignes = Copie(definition.lignes or {})
    end,
})

-- « PNJ » : un modele de personnage non joueur. Le template rangeait un PNJ
-- dans une entree et ses dix fiches dans une autre categorie ; ici tout tient
-- en une entree : ce que la fiche REPARTIT (valeurs du schema) et ce qu'elle
-- PORTE (traits, equipement, etats, apprentissages). Les formules restent
-- celles de l'addon. Les champs sont verifies a la connexion, quand le schema
-- est complet.
LCM.PNJ = LCM.Registre({
    nom = "PNJ", prefixe = "PNJ",
    construire = function(definition, element, Erreur)
        if definition.valeurs ~= nil and type(definition.valeurs) ~= "table" then
            Erreur(element.id .. " : valeurs illisibles")
        end
        element.valeurs = Copie(definition.valeurs or {})
        element.traits = ListeIds(element.id, "traits", definition.traits, Erreur) or {}
        -- Le createur de PNJ retient des niveaux, comme le createur de joueur.
        -- Une instance, elle, utilise le stockage ordinaire des metiers (XP).
        element.metiers = {}
        if definition.metiersNiveaux ~= nil and type(definition.metiersNiveaux) ~= "table" then
            Erreur(element.id .. " : metiers illisibles")
        end
        for metierId, niveau in pairs(definition.metiersNiveaux or {}) do
            metierId = tostring(metierId or "")
            niveau = math.max(0, math.floor(tonumber(niveau) or 0))
            if metierId ~= "" and niveau > 0 then
                if not (LCM.Metiers and LCM.Metiers.Get(metierId)) then
                    Erreur(element.id .. " : metier inconnu : " .. metierId)
                end
                element.metiers[metierId] = LCM.Metiers.XPPourNiveau(niveau)
            end
        end
        if not next(element.metiers) then element.metiers = nil end
        for _, cle in ipairs({ "equipement", "etats", "apprentissages" }) do
            local v = definition[cle]
            if v ~= nil and type(v) ~= "table" then Erreur(element.id .. " : " .. cle .. " illisible") end
            element[cle] = {}
            for categorie, ids in pairs(v or {}) do
                element[cle][tostring(categorie)] = ListeIds(element.id, cle, ids, Erreur)
            end
        end
    end,
})

-- « Grimoires » : des onglets de sorts (icone, description, deux champs
-- libres, un jet). Repris de Necronicon en attendant la fenetre Grimoires ;
-- le grimoire n'est pas une categorie du compendium du template.
LCM.Grimoires = LCM.Registre({
    nom = "grimoire", prefixe = "Grimoires",
    construire = function(definition, element, Erreur)
        if definition.onglets ~= nil and type(definition.onglets) ~= "table" then
            Erreur(element.id .. " : onglets illisibles")
        end
        -- « Ton grimoire » : celui que tout le monde possede d'office, par
        -- opposition a ceux qu'on recoit (MJ, objet trouve...).
        element.personnel = Vrai(definition.personnel)
        -- Combien de sorts le hub montre en apercu (hubSpellCount du template).
        element.apercu = math.max(0, math.floor(tonumber(definition.apercu) or 2))
        element.onglets = {}
        for index, onglet in ipairs(definition.onglets or {}) do
            if type(onglet) ~= "table" then Erreur(element.id .. " : onglet " .. index .. " illisible") end
            local sorts = {}
            for n, sort in ipairs(onglet.sorts or {}) do
                if type(sort) ~= "table" or Texte(sort.label) == "" then
                    Erreur(string.format("%s : sort %d de l'onglet %d sans nom", element.id, n, index))
                end
                local copie = Copie(sort)
                copie.icone = LCM.Icone(sort.icone)
                sorts[#sorts + 1] = copie
            end
            element.onglets[#element.onglets + 1] = { nom = Texte(onglet.nom) ~= "" and Texte(onglet.nom) or "Grimoire",
                                                     sorts = sorts }
        end
    end,
})

-- Les references (types, metiers, champs de PNJ) visent des choses declarees
-- plus loin dans le .toc : on les verifie a la connexion, sans rien refuser —
-- une reference perdue s'affiche marquee dans le compendium.
LCM.WhenReady(function()
    for _, p in ipairs(LCM.PNJ.list) do
        for champ in pairs(p.valeurs) do
            if not LCM.Schema.Field(champ) then
                LCM.Erreur(string.format("PNJ « %s » : champ inconnu (%s)", p.label, tostring(champ)))
            end
        end
    end
end)
