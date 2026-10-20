-- Creation de personnage : le moteur.
--
-- Ici, aucune fenetre — seulement les budgets, les plafonds et les refus.
-- L'ecran (UI/Creation.lua) ne fait que poser des questions a ce fichier, ce
-- qui rend les regles verifiables au banc sans dessiner quoi que ce soit.
--
-- Un brouillon est une table plate :
--     { nom, race, niveau, valeurs = { [champ] = n }, traits = { id, ... },
--       metiers = { [id] = niveau } }
-- Les identifiants de `valeurs` sont ceux du schema : au bout du compte, creer
-- le personnage se resume a recopier cette table.

local _, LCM = ...

-- Core/ se charge avant Data/ : l'equilibrage n'existe pas encore ici. On le
-- resout au premier appel plutot que de capturer une table vide.
local E
local function Eq()
    E = E or LCM.Equilibrage
    return E
end

local Creation = {}
LCM.Creation = Creation

function Creation.VersionEquilibrage()
    return math.max(1, math.floor(tonumber(Eq().VERSION_CREATION) or 1))
end

function Creation.ReequilibrageRequis(entity)
    if type(entity) ~= "table" or entity.kind ~= "player" then return false end
    return (tonumber(entity.versionCreation) or 0) < Creation.VersionEquilibrage()
end

function Creation.MarquerAJour(entity)
    if type(entity) ~= "table" then return false end
    entity.versionCreation = Creation.VersionEquilibrage()
    return true
end

-- Les cinq etapes, dans l'ordre. L'ecran s'y conforme ; il ne les invente pas.
-- Les onglets de la fenetre Creation du template, dans son ordre.
Creation.ETAPES = {
    { id = "bienvenue",    label = "Bienvenue" },
    { id = "generale",     label = "Générale" },
    { id = "statistiques", label = "Statistiques" },
    { id = "expertises",   label = "Expertises" },
    -- Les mecaniques ont leur propre etape depuis le 3 octobre 2026 : elles
    -- ont leur budget, leurs vingt lignes, et elles passaient inapercues en
    -- bas de la page des expertises.
    { id = "mecaniques",   label = "Mécaniques" },
    { id = "penetrations", label = "Pénétrations" },
    { id = "resistances",  label = "Résistances" },
    { id = "traits",       label = "Traits" },
    { id = "metiers",      label = "Métiers" },
}

function Creation.Nouveau(niveau)
    return {
        nom = "",
        race = "",
        niveau = tonumber(niveau) or Eq().creation.niveauDepart,
        valeurs = {},
        traits = {},
        metiers = {},
    }
end

-- Un PNJ se construit avec exactement le meme parcours qu'un personnage. Le
-- marqueur ne change que les regles qui lui sont propres (metiers facultatifs,
-- capital lie au niveau) et la destination finale : le compendium MJ, jamais
-- la liste des personnages du joueur.
function Creation.NouveauPNJ(niveau)
    local brouillon = Creation.Nouveau(niveau)
    brouillon.mode = "pnj"
    return brouillon
end

function Creation.Valeur(brouillon, champ)
    return tonumber(brouillon.valeurs[champ]) or 0
end

local function Somme(brouillon, liste)
    local total = 0
    for _, entree in ipairs(liste) do
        total = total + Creation.Valeur(brouillon, entree.id or entree)
    end
    return total
end

-- ===== Les listes de lignes d'une categorie ================================

local function Expertises()
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        if tab.id == "expertises" then
            for _, section in ipairs(tab.sections) do
                for _, field in ipairs(section.fields) do
                    out[#out + 1] = { id = field.id, label = field.label, groupe = section.label }
                end
            end
        end
    end
    return out
end

local cacheExpertises
function Creation.Expertises()
    cacheExpertises = cacheExpertises or Expertises()
    return cacheExpertises
end

local cacheMecaniques
function Creation.Mecaniques()
    if not cacheMecaniques then
        cacheMecaniques = {}
        for _, mecanique in ipairs(Eq().mecaniques) do
            cacheMecaniques[#cacheMecaniques + 1] = { id = "meca_" .. mecanique.id, label = mecanique.label,
                groupe = "Compétence" }
        end
        -- Les defenses prennent sur le MEME budget, et se plafonnent pareil
        -- (11 octobre 2026) : se blinder contre la peur, c'est du temps qu'on
        -- ne passe pas a apprendre a frapper.
        for _, defense in ipairs(Eq().defenses or {}) do
            cacheMecaniques[#cacheMecaniques + 1] = { id = LCM.Defenses.Field(defense.id),
                label = defense.label, groupe = "Défense", note = defense.note }
        end
    end
    return cacheMecaniques
end

-- ===== Ce que chaque ligne raconte =========================================
-- Lu dans les donnees, jamais invente : une regle qu'on ecrirait ici a la main
-- finirait par contredire celle que le jeu applique.

local function Nombre(n)
    n = tonumber(n) or 0
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ","))
end

local function Libelle(id)
    local champ = LCM.Schema and LCM.Schema.Field and LCM.Schema.Field(tostring(id or ""))
    return (champ and champ.label) or tostring(id or "")
end

-- Une mecanique de competence : ce qu'un point y ajoute, d'apres la grille de
-- puissance.
local function NoteMecanique(id)
    local R = LCM.Reglages
    if not (R and R.PuissanceMecanique) then return nil end
    local p = R.PuissanceMecanique(id)
    local bouts = {}
    if (tonumber(p.base) or 0) ~= 0 then
        bouts[#bouts + 1] = string.format("%s %% de base", Nombre(p.base))
    end
    if (tonumber(p.parPoint) or 0) ~= 0 then
        bouts[#bouts + 1] = string.format("+%s %% par point investi", Nombre(p.parPoint))
    end
    if (tonumber(p.equipParPoint) or 0) ~= 0 then
        bouts[#bouts + 1] = string.format("+%s %% par point d'équipement", Nombre(p.equipParPoint))
    end
    if #bouts == 0 then return nil end
    return "Puissance de la mécanique : " .. table.concat(bouts, ", ") .. "."
end

-- Une expertise : ce qui la nourrit, et ce qu'elle apporte.
local function NoteExpertise(id)
    local bouts = {}
    local apports = Eq().apportsExpertises and Eq().apportsExpertises[id]
    if apports then
        local sources = {}
        for source, coefficient in pairs(apports) do
            sources[#sources + 1] = { label = Libelle(source), c = coefficient }
        end
        table.sort(sources, function(a, b)
            if a.c ~= b.c then return a.c > b.c end
            return a.label < b.label
        end)
        local liste = {}
        for _, s in ipairs(sources) do
            liste[#liste + 1] = string.format("%s × %s", s.label, Nombre(s.c))
        end
        bouts[#bouts + 1] = "Nourrie par : " .. table.concat(liste, ", ") .. "."
    end
    local effet = Eq().effetsExpertises and Eq().effetsExpertises[id]
    if effet then
        local dits = {}
        if effet.partObligatoire then
            dits[#dits + 1] = string.format(
                "allège de %s %% par point la part des dégâts qui doit aller en santé",
                Nombre(effet.partObligatoire * 100))
        end
        if effet.degats then
            dits[#dits + 1] = string.format("+%s %% de dégâts par point", Nombre(effet.degats * 100))
        end
        if effet.rand then
            dits[#dits + 1] = string.format("+%s au jet par point", Nombre(effet.rand))
        end
        if effet.portee then
            dits[#dits + 1] = string.format("+%s yard par point", Nombre(effet.portee))
        end
        if effet.deplacement then
            local modes = {}
            for _, m in ipairs(effet.modes or {}) do modes[#modes + 1] = m end
            dits[#dits + 1] = string.format("+%s yard de déplacement par point (%s)",
                Nombre(effet.deplacement), table.concat(modes, ", "))
        end
        if effet.parade then
            local jets = {}
            for _, j in ipairs(effet.jets or {}) do jets[#jets + 1] = Libelle(j) end
            dits[#dits + 1] = string.format("+%s par point aux jets de %s quand on pare",
                Nombre(effet.parade), table.concat(jets, " et "))
        end
        if effet.mecaniques then
            dits[#dits + 1] = "sur : " .. table.concat(effet.mecaniques, ", ")
        end
        if #dits > 0 then
            bouts[#bouts + 1] = "Apporte : " .. table.concat(dits, " ; ") .. "."
        end
    end
    if #bouts == 0 then return nil end
    return table.concat(bouts, "\n\n")
end

-- La note d'une ligne de repartition. `nil` quand on n'a rien d'honnete a
-- dire : une infobulle vide vaut mieux qu'une phrase inventee.
function Creation.Note(categorie, champ)
    champ = tostring(champ or "")
    if categorie == "mecaniques" then
        local defense = champ:match("^def_(.+)$")
        if defense then
            local d = LCM.Defenses and LCM.Defenses.Get(defense)
            return d and d.note or nil
        end
        local mecanique = champ:match("^meca_(.+)$")
        if mecanique then return NoteMecanique(mecanique) end
        return nil
    end
    if categorie == "expertises" then return NoteExpertise(champ) end
    -- Les autres categories portent deja leur note dans le schema, quand elles
    -- en ont une.
    local field = LCM.Schema and LCM.Schema.Field and LCM.Schema.Field(champ)
    local note = field and field.note
    if note == nil or note == "" then return nil end
    -- « Points investis dans... » ne dit rien de plus que le libelle de la
    -- ligne : une infobulle qui repete la ligne vaut mieux absente.
    if tostring(note):find("^Points investis") then return nil end
    return note
end

function Creation.Types(cote)
    local prefixe = (cote == "resistance") and "resi_" or "pen_"
    local out = {}
    for _, t in ipairs(Eq().types) do
        out[#out + 1] = { id = prefixe .. t.id, label = t.label, groupe = t.groupe }
    end
    return out
end

function Creation.Lignes(categorie)
    if categorie == "primaires" then return Eq().primaires end
    if categorie == "mecaniques" then return Creation.Mecaniques() end
    if categorie == "secondaires" then return Eq().secondaires end
    if categorie == "expertises" then return Creation.Expertises() end
    if categorie == "penetration" then return Creation.Types("penetration") end
    if categorie == "resistance" then return Creation.Types("resistance") end
    if categorie == "metiers" then return LCM.Metiers and LCM.Metiers.list or {} end
    return {}
end

-- ===== Budgets =============================================================
-- Les points d'expertise, de mecanique, de penetration et de resistance ne
-- sont pas des budgets fixes : ils dependent de ce qu'on a deja investi
-- ailleurs. C'est voulu — c'est ce qui fait qu'un choix de statistique se paie
-- ou se rembourse plus loin.

function Creation.Total(brouillon, categorie)
    local niveau = brouillon.niveau
    if categorie == "primaires" then
        return Eq().Bareme(Eq().creation.primaires, niveau)
    elseif categorie == "secondaires" then
        return Eq().Bareme(Eq().creation.secondaires, niveau)
    elseif categorie == "expertises" then
        return Eq().Bareme(Eq().creation.expertises, niveau)
            + Eq().conversion.expertises * Creation.Valeur(brouillon, "sec_expertises")
    elseif categorie == "mecaniques" then
        local m = Eq().creation.mecaniques
        local niveauxGagnes = math.max(0,
            math.floor(tonumber(niveau) or 0) - (tonumber(m.niveauDepart) or 0))
        local intervalle = math.max(1, tonumber(m.niveauxParPalier) or 5)
        local paliers = math.floor(niveauxGagnes / intervalle)
        local total = (tonumber(m.base) or 0)
            + niveauxGagnes * (tonumber(m.parNiveau) or 0)
            + paliers * ((tonumber(m.gainPalier) or 0) - (tonumber(m.parNiveau) or 0))
        return total
            + Eq().conversion.mecaniques * Creation.Valeur(brouillon, "sec_mecanique")
    elseif categorie == "penetration" then
        local p = Eq().penetration.points
        local stats = 0
        for _, id in ipairs(Eq().statsDeDegats) do stats = stats + Creation.Valeur(brouillon, id) end
        return math.floor(p.base + p.parNiveau * niveau + p.parStatDeDegats * stats
            + p.parSecondaire * Creation.Valeur(brouillon, "sec_penetration"))
    elseif categorie == "resistance" then
        local p = Eq().resistance.points
        return math.floor(p.base + p.parNiveau * niveau
            + p.parConstitution * Creation.Valeur(brouillon, "constitution")
            + p.parEsprit * Creation.Valeur(brouillon, "esprit")
            + p.parSecondaire * Creation.Valeur(brouillon, "sec_resistance"))
    elseif categorie == "traits" then
        local t = Eq().creation.traits
        local total = tonumber(t.base) or 0
        for _, niveauGain in ipairs(t.niveaux or {}) do
            if niveau >= niveauGain then total = total + 1 end
        end
        return total
    elseif categorie == "metiers" then
        if brouillon.mode == "pnj" then
            return math.max(0, math.floor(tonumber(niveau) or 0)) * 4
        end
        if brouillon.mode == "reedition" or brouillon.mode == "reequilibrage" then
            return math.max(0, math.floor(tonumber(brouillon.metiersBudget) or 0))
        end
        -- Indépendant du niveau d'aventure : tout nouveau personnage dispose
        -- de quatre rangs à répartir. Une réédition reprend un budget égal aux
        -- rangs déjà acquis ; une montée de niveau ne le rouvre pas.
        return (brouillon.entite or brouillon.mode == "niveau") and 0 or 4
    end
    return 0
end

-- Ce que coute UN point sur cette ligne. Adresse et Esprit valent deux points,
-- un point d'action en vaut huit : le budget ne peut donc pas se contenter de
-- compter les valeurs.
function Creation.Cout(categorie, champ)
    if categorie == "primaires" then
        for _, stat in ipairs(Eq().primaires) do
            if stat.id == champ then return stat.cout or Eq().primaire.cout or 1 end
        end
    elseif categorie == "secondaires" then
        for _, pool in ipairs(Eq().secondaires) do
            if pool.id == champ then return pool.cout or 1 end
        end
    end
    return 1
end

function Creation.Depense(brouillon, categorie)
    if categorie == "primaires" or categorie == "secondaires" then
        local total = 0
        for _, ligne in ipairs(Creation.Lignes(categorie)) do
            total = total + Creation.Valeur(brouillon, ligne.id) * Creation.Cout(categorie, ligne.id)
        end
        return total
    elseif categorie == "traits" then
        local total = 0
        for _, id in ipairs(brouillon.traits) do
            local trait = LCM.Traits.Get(id)
            total = total + LCM.Traits.Cout(trait)
        end
        return total
    elseif categorie == "metiers" then
        local total = 0
        for _, niveau in pairs(brouillon.metiers or {}) do
            total = total + math.max(0, math.floor(tonumber(niveau) or 0))
        end
        return total
    end
    return Somme(brouillon, Creation.Lignes(categorie))
end

function Creation.Budget(brouillon, categorie)
    if brouillon.mode == "niveau" and brouillon.base then
        local total = math.max(0, Creation.Total(brouillon, categorie)
            - Creation.Total(brouillon.base, categorie))
        local depense = Creation.Depense(brouillon, categorie)
            - Creation.Depense(brouillon.base, categorie)
        return { total = total, depense = depense, reste = total - depense }
    end
    local total = Creation.Total(brouillon, categorie)
    local depense = Creation.Depense(brouillon, categorie)
    return { total = total, depense = depense, reste = total - depense }
end

-- ===== Plafonds ============================================================

function Creation.Plafond(brouillon, categorie, champ)
    local niveau = brouillon.niveau
    if categorie == "primaires" then
        for _, stat in ipairs(Eq().primaires) do
            if stat.id == champ then
                return Eq().Bareme(stat.plafond or Eq().primaire.plafond, niveau)
            end
        end
        return Eq().Bareme(Eq().primaire.plafond, niveau)
    elseif categorie == "expertises" or categorie == "mecaniques" then
        -- Meme limite que pour une expertise : dans Necronicon, les deux
        -- grilles pointaient vers le meme champ « Max expertise ».
        return Eq().Bareme(Eq().expertise.plafond, niveau)
    elseif categorie == "secondaires" then
        for _, pool in ipairs(Eq().secondaires) do
            if pool.id == champ then return Eq().Bareme(pool.plafond, niveau) end
        end
        return 0
    elseif categorie == "penetration" then
        local stats = 0
        for _, id in ipairs(Eq().statsDeDegats) do stats = stats + Creation.Valeur(brouillon, id) end
        local p = Eq().penetration.plafond
        return math.floor(stats / p.diviseurStats) + p.base
    elseif categorie == "resistance" then
        local p = Eq().resistance.plafond
        return math.floor(Creation.Valeur(brouillon, "constitution") * p.parConstitution) + p.base
    elseif categorie == "metiers" then
        -- Quatre, c'est la limite d'un JOUEUR : il n'a que quatre points en
        -- tout, un par niveau de metier. Un PNJ en recoit quatre par niveau,
        -- et le brider a quatre interdisait le forgeron legendaire du village
        -- (11 octobre 2026). Reste le bareme, qui s'arrete pour de bon.
        if brouillon.mode == "pnj" then
            return (LCM.Metiers and LCM.Metiers.RangMax and LCM.Metiers.RangMax()) or 4
        end
        if brouillon.mode == "reedition" or brouillon.mode == "reequilibrage" then
            return (LCM.Metiers and LCM.Metiers.RangMax and LCM.Metiers.RangMax()) or 4
        end
        return 4
    end
    return 0
end

-- ===== Ecriture ============================================================
-- Un seul point d'entree pour modifier un brouillon : il refuse et dit
-- pourquoi, plutot que de corriger en silence.

function Creation.Definir(brouillon, categorie, champ, valeur)
    valeur = math.floor(tonumber(valeur) or 0)
    if valeur < 0 then return false, "une valeur ne descend pas sous zero." end

    if brouillon.mode == "niveau" and brouillon.base then
        local minimum = Creation.Valeur(brouillon.base, champ)
        if valeur < minimum then
            return false, string.format("un passage de niveau ne peut pas descendre sous %d.", minimum)
        end
    end

    local avant = categorie == "metiers"
        and (tonumber((brouillon.metiers or {})[champ]) or 0)
        or Creation.Valeur(brouillon, champ)
    local resteAvant = Creation.Budget(brouillon, categorie).reste
    local plafond = Creation.Plafond(brouillon, categorie, champ)
    -- Un depassement peut apparaitre APRES coup, quand une statistique baisse
    -- et rabote un plafond. Redescendre doit rester possible, sinon la ligne
    -- est prise au piege : on refuse seulement ce qui monte au-dessus.
    if valeur > plafond and valeur >= avant then
        return false, string.format("plafond atteint : %d au maximum a ce niveau.", plafond)
    end

    if categorie == "metiers" then
        brouillon.metiers = type(brouillon.metiers) == "table" and brouillon.metiers or {}
        brouillon.metiers[champ] = (valeur ~= 0) and valeur or nil
    else
        brouillon.valeurs[champ] = (valeur ~= 0) and valeur or nil
    end

    local budget = Creation.Budget(brouillon, categorie)
    -- Une ancienne fiche peut commencer la refonte avec un budget negatif.
    -- Toute baisse qui rapproche ce budget de zero doit rester possible, meme
    -- si un seul clic ne suffit pas encore a effacer tout le depassement.
    if budget.reste < 0 and budget.reste <= resteAvant then
        if categorie == "metiers" then
            brouillon.metiers[champ] = (avant ~= 0) and avant or nil
        else
            brouillon.valeurs[champ] = (avant ~= 0) and avant or nil
        end
        local reste = Creation.Budget(brouillon, categorie).reste
        if reste < 0 then
            return false, string.format("budget déjà dépassé de %d point%s : retire d'abord des points.",
                -reste, reste < -1 and "s" or "")
        end
        return false, string.format("il ne reste que %d point%s.", reste, reste > 1 and "s" or "")
    end

    -- Monter une statistique de degats ou la constitution peut abaisser un
    -- plafond de type deja rempli : on le dit, on ne corrige pas en douce.
    return true, Creation.Debordements(brouillon)
end

-- Les lignes qui depassent leur plafond apres coup (baisse d'une statistique,
-- changement de niveau). Retourne une liste vide quand tout va bien.
function Creation.Debordements(brouillon)
    local out = {}
    for _, categorie in ipairs({ "primaires", "secondaires", "expertises", "mecaniques", "penetration", "resistance", "metiers" }) do
        for _, ligne in ipairs(Creation.Lignes(categorie)) do
            local plafond = Creation.Plafond(brouillon, categorie, ligne.id)
            local valeur = categorie == "metiers"
                and (tonumber((brouillon.metiers or {})[ligne.id]) or 0)
                or Creation.Valeur(brouillon, ligne.id)
            if valeur > plafond then
                out[#out + 1] = { categorie = categorie, id = ligne.id, label = ligne.label,
                    valeur = valeur, plafond = plafond }
            end
        end
    end
    return out
end

-- La plus grande valeur qu'on puisse encore se payer sur cette ligne : c'est ce
-- que pose le bouton « M ».
function Creation.Maximum(brouillon, categorie, champ)
    local plafond = Creation.Plafond(brouillon, categorie, champ)
    local cout = Creation.Cout(categorie, champ)
    local valeur = categorie == "metiers"
        and (tonumber((brouillon.metiers or {})[champ]) or 0)
        or Creation.Valeur(brouillon, champ)
    local reste = Creation.Budget(brouillon, categorie).reste
    if cout <= 0 then return plafond end
    return math.min(plafond, valeur + math.floor(reste / cout))
end

-- Remet une ligne a zero, ou toute une categorie, ou tout le brouillon. Les
-- valeurs partent : ce sont les points qu'on recupere, pas une mise en forme.
function Creation.Remettre(brouillon, categorie, champ)
    if categorie == "metiers" then
        brouillon.metiers = type(brouillon.metiers) == "table" and brouillon.metiers or {}
        brouillon.metiers[champ] = nil
        return true
    end
    local valeur = brouillon.mode == "niveau" and brouillon.base
        and Creation.Valeur(brouillon.base, champ) or 0
    brouillon.valeurs[champ] = valeur ~= 0 and valeur or nil
    return true
end

function Creation.RemettreCategorie(brouillon, categorie)
    if categorie == "traits" then
        brouillon.traits = {}
        if brouillon.mode == "niveau" and brouillon.base then
            for _, id in ipairs(brouillon.base.traits or {}) do
                brouillon.traits[#brouillon.traits + 1] = id
            end
        end
        return true
    end
    if categorie == "metiers" then
        brouillon.metiers = {}
        return true
    end
    for _, ligne in ipairs(Creation.Lignes(categorie)) do
        brouillon.valeurs[ligne.id] = nil
    end
    return true
end

Creation.CATEGORIES = { "primaires", "secondaires", "expertises", "mecaniques",
    "penetration", "resistance", "metiers", "traits" }

-- Reste-t-il quelque chose a ACHETER dans cette categorie ? Un budget qu'on ne
-- peut plus depenser ne doit pas interdire la creation : si toutes les lignes
-- sont a leur plafond, ou si plus aucun trait n'est abordable, le point qui
-- traine est impossible a placer, et bloquer dessus serait un cul-de-sac.
function Creation.PeutEncoreDepenser(brouillon, categorie)
    local reste = Creation.Budget(brouillon, categorie).reste
    if reste <= 0 then return false end
    if categorie == "traits" then
        local places = (tonumber(Eq().conteneurs.traits) or 0) - Creation.Depense(brouillon, "traits")
        for _, trait in ipairs(LCM.Traits.Accessibles()) do
            if LCM.Traits.Cout(trait) <= math.min(reste, places)
                and not Creation.ATrait(brouillon, trait.id) then
                return true
            end
        end
        return false
    end
    for _, ligne in ipairs(Creation.Lignes(categorie)) do
        local id = ligne.id or ligne
        local valeur = categorie == "metiers"
            and (tonumber((brouillon.metiers or {})[id]) or 0)
            or Creation.Valeur(brouillon, id)
        if Creation.Maximum(brouillon, categorie, id) > valeur then return true end
    end
    return false
end

-- Ce qu'on en dit au joueur : « il reste 3 points de statistiques », pas
-- « il reste 3 points de primaires ».
Creation.LIBELLES = {
    primaires = "statistiques", secondaires = "statistiques secondaires",
    expertises = "expertises", mecaniques = "mécaniques de compétence",
    penetration = "pénétrations", resistance = "résistances", metiers = "métiers", traits = "traits",
}

function Creation.RemettreTout(brouillon)
    for _, categorie in ipairs(Creation.CATEGORIES) do
        Creation.RemettreCategorie(brouillon, categorie)
    end
    return true
end

-- Ce trait est-il deja pris ? La liste est courte, la boucle suffit.
function Creation.ATrait(brouillon, id)
    for _, porte in ipairs(brouillon.traits or {}) do
        if porte == id then return true end
    end
    return false
end

function Creation.AjouterTrait(brouillon, id)
    local trait = LCM.Traits.Get(id)
    if not trait then return false, "trait inconnu." end
    if Creation.ATrait(brouillon, id) then return false, "trait deja choisi." end
    local budget = Creation.Budget(brouillon, "traits")
    local cout = LCM.Traits.Cout(trait)
    if cout > budget.reste then
        return false, string.format("%s coute %d point%s, il en reste %d.",
            trait.label, cout, cout > 1 and "s" or "", budget.reste)
    end
    local places = tonumber(Eq().conteneurs.traits) or 0
    if Creation.Depense(brouillon, "traits") + cout > places then
        return false, string.format("%s occupe %d emplacements de traits, %d disponibles.",
            trait.label, cout, math.max(0, places - Creation.Depense(brouillon, "traits")))
    end
    brouillon.traits[#brouillon.traits + 1] = id
    return true
end

function Creation.RetirerTrait(brouillon, id)
    if brouillon.mode == "niveau" and brouillon.base and Creation.ATrait(brouillon.base, id) then
        return false, "un passage de niveau ne retire pas un trait déjà acquis."
    end
    for index, porte in ipairs(brouillon.traits) do
        if porte == id then table.remove(brouillon.traits, index) return true end
    end
    return false
end

-- ===== Validation et application ===========================================

function Creation.Problemes(brouillon)
    local out = {}
    if brouillon.mode ~= "niveau" and tostring(brouillon.nom or ""):gsub("%s+", "") == "" then
        out[#out + 1] = "il faut un nom."
    end
    -- La race se CHOISIT dans le compendium, et nulle part ailleurs : une race
    -- tapee a la main n'apportait ni bonus ni morphologie, et laissait croire
    -- le contraire. Si elle manque, c'est au MJ de la creer.
    if brouillon.mode ~= "niveau" and tostring(brouillon.race or "") == "" then
        out[#out + 1] = "il faut choisir une race."
    elseif brouillon.mode ~= "niveau" and not LCM.Races.Get(brouillon.race) then
        out[#out + 1] = string.format("la race « %s » n'existe pas dans cette version.", tostring(brouillon.race))
    elseif brouillon.mode ~= "niveau" and not LCM.Races.Choisissable(LCM.Races.Get(brouillon.race)) then
        -- Le choix reste affiche : on dit pourquoi, on ne le retire pas.
        out[#out + 1] = string.format("la race « %s » est réservée au MJ.", LCM.Races.Get(brouillon.race).label)
    end
    -- Une saisie de niveau illisible reste affichee (en rouge) et bloque :
    -- `niveau`, lui, garde la derniere valeur valable pour les calculs.
    if brouillon.niveauSaisie ~= nil then
        out[#out + 1] = string.format("niveau illisible (%s) : un nombre entier, 1 au minimum.",
            tostring(brouillon.niveauSaisie))
    end
    for _, debordement in ipairs(Creation.Debordements(brouillon)) do
        out[#out + 1] = string.format("%s depasse son plafond (%d pour %d).",
            debordement.label, debordement.valeur, debordement.plafond)
    end
    -- Les points doivent etre TOUS places, pas seulement ne pas deborder.
    -- Un personnage qui arrive avec des points en poche, c'est un personnage
    -- qu'on finira de construire en seance, au moment ou tout le monde attend.
    -- Les traits comptent comme le reste : ce sont des points.
    for _, categorie in ipairs(Creation.CATEGORIES) do
        local budget = Creation.Budget(brouillon, categorie)
        if budget.reste < 0 then
            out[#out + 1] = string.format("budget %s depasse de %d.", categorie, -budget.reste)
        elseif budget.reste > 0
            and not (brouillon.mode == "pnj" and categorie == "metiers")
            and Creation.PeutEncoreDepenser(brouillon, categorie)
        then
            out[#out + 1] = string.format("il reste %d point%s de %s a placer.",
                budget.reste, budget.reste > 1 and "s" or "", Creation.LIBELLES[categorie] or categorie)
        end
    end
    return out
end

-- Forme exportable d'un PNJ du compendium. Les metiers y sont conserves comme
-- niveaux de creation ; le registre PNJ les convertit en XP quand il construit
-- le modele, afin que les instances utilisent ensuite le moteur Metiers normal.
function Creation.DefinitionPNJ(brouillon, id)
    if type(brouillon) ~= "table" or brouillon.mode ~= "pnj" then
        return nil, "creation de PNJ invalide."
    end
    local problemes = Creation.Problemes(brouillon)
    if #problemes > 0 then return nil, problemes[1] end

    local valeurs = { race = brouillon.race, niveau = brouillon.niveau }
    if brouillon.valeurs.sexe == "Autre" and tostring(brouillon.sexeAutre or "") ~= "" then
        valeurs.sexe = brouillon.sexeAutre
    end
    for champ, valeur in pairs(brouillon.valeurs or {}) do valeurs[champ] = valeur end

    local race = LCM.Races.Get(brouillon.race)
    return {
        id = tostring(id or ""),
        label = tostring(brouillon.nom or ""),
        icone = race and race.icone or nil,
        valeurs = valeurs,
        traits = LCM.Copie(brouillon.traits or {}),
        metiersNiveaux = LCM.Copie(brouillon.metiers or {}),
    }
end

-- Rien n'oblige a tout depenser : un personnage peut garder des points de cote.
-- ===== Rouvrir une fiche ===================================================
-- Un personnage termine n'etait plus modifiable : la creation ne savait que
-- creer. Deux portes s'ouvrent (5 octobre 2026) :
--
--   * le MJ rouvre n'importe quelle fiche, quand il veut ;
--   * un joueur rouvre la sienne s'il tient un JETON, que le MJ lui donne et
--     que la validation consomme. Un jeton, une refonte : on ne retouche pas
--     sa fiche entre deux phrases.

-- Le jeton vit sur la fiche elle-meme, pas dans les reglages du joueur : il
-- suit le personnage, y compris quand le MJ incarne un PNJ.
function Creation.ADesJetons(entity)
    return type(entity) == "table" and (tonumber(entity.jetonEdition) or 0) > 0
end

function Creation.DonnerJeton(entity, combien)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    combien = math.max(1, math.floor(tonumber(combien) or 1))
    entity.jetonEdition = (tonumber(entity.jetonEdition) or 0) + combien
    return true, entity.jetonEdition
end

-- Le jeton voyage jusqu'au joueur, puis s'attache a SON personnage actif. La
-- reponse evite au MJ de croire le geste accompli si le joueur n'a encore
-- cree aucun personnage.
local SUJET_JETON = "edition+"
local SUJET_REPONSE = "edition!"

function Creation.EnvoyerJeton(joueur)
    joueur = tostring(joueur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if joueur == "" then return false, "à qui ?" end
    if not LCM.IsMaster() then return false, "seul le maître du jeu donne un jeton de réédition." end
    if joueur == LCM.PlayerId() then
        return false, "tu n'en as pas besoin : le maître du jeu peut rééditer sa fiche à tout moment."
    end
    return LCM.Reseau.Envoyer(SUJET_JETON, {}, "WHISPER", joueur)
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(SUJET_JETON, function(expediteur)
        -- Comme pour l'XP, le client ne peut pas prouver que l'autre possède le
        -- compagnon MJ. Le groupe borne le geste, et le nom de l'expéditeur est
        -- annoncé : un envoi illégitime ne passe pas inaperçu.
        if not LCM.Reseau.DansLeGroupe(expediteur) then
            LCM.Debug(string.format("jeton de réédition refusé de %s : hors du groupe.", tostring(expediteur)))
            return
        end
        local moi = LCM.Entities.Personnage()
        if not moi then
            LCM.Reseau.Envoyer(SUJET_REPONSE,
                { r = "aucun personnage actif chez ce joueur." }, "WHISPER", expediteur)
            LCM.Alerte(string.format("%s a voulu te donner un jeton de réédition, mais tu n'as aucun personnage actif.",
                tostring(expediteur)))
            return
        end
        Creation.DonnerJeton(moi)
        LCM.Reseau.Envoyer(SUJET_REPONSE, { ok = 1, nom = tostring(moi.name) }, "WHISPER", expediteur)
        LCM.Ok(string.format("%s t'a donné un jeton de réédition pour %s. "
            .. "Ouvre /lcm personnages puis Rééditer, ou utilise /lcm editer.",
            tostring(expediteur), tostring(moi.name)))
        if LCM.UI and LCM.UI.Personnages and LCM.UI.Personnages.frame
            and LCM.UI.Personnages.frame:IsShown() then
            LCM.UI.Personnages.frame:Rafraichir()
        end
    end)

    LCM.Reseau.Ecouter(SUJET_REPONSE, function(expediteur, donnees)
        if not LCM.IsMaster() then return end
        if donnees.ok then
            LCM.Ok(string.format("%s a reçu son jeton de réédition pour %s.",
                tostring(expediteur), tostring(donnees.nom or "son personnage")))
        else
            LCM.Alerte(string.format("jeton non remis à %s : %s",
                tostring(expediteur), tostring(donnees.r or "raison inconnue")))
        end
    end)
end)

function Creation.RetirerJeton(entity)
    if not Creation.ADesJetons(entity) then return false end
    local reste = (tonumber(entity.jetonEdition) or 0) - 1
    entity.jetonEdition = reste > 0 and reste or nil
    return true
end

-- Qui peut rouvrir cette fiche, et sinon pourquoi.
function Creation.PeutEditer(entity)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    if Creation.ReequilibrageRequis(entity) then return true end
    if LCM.IsMaster() then return true end
    if Creation.ADesJetons(entity) then return true end
    return false, "il faut un jeton de réédition : demande-le au maître du jeu."
end

-- « Autre » se precise librement, et c'est CE TEXTE qui est enregistre (« Non
-- binaire », par exemple). Relu tel quel, il n'allumait aucun des trois
-- boutons et la precision disparaissait : on le reconnait comme un « Autre ».
local SEXES = { ["Féminin"] = true, ["Masculin"] = true, ["Autre"] = true }
local function RelireSexe(brouillon)
    local sexe = brouillon.valeurs.sexe
    if sexe ~= nil and sexe ~= "" and not SEXES[tostring(sexe)] then
        brouillon.valeurs.sexe, brouillon.sexeAutre = "Autre", tostring(sexe)
    end
end

-- Un brouillon fait d'une fiche existante : on repart de ce qu'elle est, et
-- `entite` dit que la validation modifiera CELLE-LA au lieu d'en creer une.
function Creation.Depuis(entity)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    local brouillon = Creation.Nouveau(LCM.Entities.Get_Value(entity, "niveau"))
    brouillon.entite = entity
    brouillon.nom = tostring(entity.name or "")
    brouillon.race = tostring(LCM.Entities.Get_Value(entity, "race") or "")

    -- Les valeurs investies, telles qu'elles ont ete saisies. Le reste de la
    -- fiche (jauges, etats, inventaire) ne regarde pas la creation et survit.
    for _, categorie in ipairs(Creation.CATEGORIES or {}) do
        if (categorie.id or categorie) ~= "metiers" then
            for _, ligne in ipairs(Creation.Lignes(categorie.id or categorie) or {}) do
                local id = ligne.id or ligne
                local valeur = tonumber(LCM.Entities.Get_Value(entity, id))
                if valeur and valeur ~= 0 then brouillon.valeurs[id] = valeur end
            end
        end
    end
    for _, champ in ipairs({ "sexe", "age", "poids", "taille", "portrait" }) do
        local valeur = LCM.Entities.Get_Value(entity, champ)
        if valeur ~= nil and valeur ~= "" then brouillon.valeurs[champ] = valeur end
    end
    RelireSexe(brouillon)
    brouillon.traits = {}
    for _, id in ipairs(LCM.Traits.Ids and LCM.Traits.Ids(entity) or {}) do
        brouillon.traits[#brouillon.traits + 1] = id
    end
    -- Une réédition avec jeton permet aussi de redistribuer les rangs de
    -- métiers déjà acquis. On garde le total actuel comme budget et l'XP
    -- partielle de chaque métier pour ne pas la perdre au passage.
    brouillon.mode = "reedition"
    brouillon.metiersBudget = 0
    brouillon.metiersProgression = {}
    for _, metier in ipairs(LCM.Metiers.list or {}) do
        local xp = LCM.Metiers.XP(entity, metier.id)
        local rang = LCM.Metiers.Palier(entity, metier.id).rang
        if rang > 0 then
            brouillon.metiers[metier.id] = rang
            brouillon.metiersBudget = brouillon.metiersBudget + rang
        end
        brouillon.metiersProgression[metier.id] = math.max(0,
            xp - LCM.Metiers.XPPourNiveau(rang))
    end
    brouillon.metiersBudget = math.max(4, brouillon.metiersBudget)
    return brouillon
end

-- Rouvrir la CREATION d'un PNJ du compendium (clic droit sur son engrenage,
-- 11 octobre 2026). Le clic gauche ouvre sa fiche : ce qu'il EST. Mais la
-- fiche ne montre plus ce qui a ete CHOISI — la race, le niveau, la
-- repartition des points — et un PNJ mal dose se refaisait de zero.
--
-- On part du MODELE du compendium, pas d'une entite : c'est lui que la ligne
-- du tableau tient, et il vaut aussi pour un PNJ publie. Ses metiers y sont
-- ranges en XP (Core/Contenus.lua les convertit a la construction) ; on les
-- relit en rangs, puisque c'est en rangs que la creation les depense.
function Creation.DepuisPNJ(modele)
    if type(modele) ~= "table" then return nil, "aucun PNJ." end
    local valeurs = modele.valeurs or {}
    local brouillon = Creation.NouveauPNJ(valeurs.niveau)
    -- Ce marqueur dit a l'ecran qu'il REPREND un PNJ : le titre, le bouton de
    -- validation et l'identifiant enregistre en dependent.
    brouillon.pnj = tostring(modele.id or "")
    brouillon.nom = tostring(modele.label or "")
    brouillon.race = tostring(valeurs.race or "")

    -- Seulement ce que la creation sait depenser. Le reste du modele
    -- (equipement, etats, apprentissages) ne la regarde pas et doit survivre
    -- a la reprise : c'est l'appelant qui le reporte.
    for _, categorie in ipairs(Creation.CATEGORIES or {}) do
        if categorie ~= "metiers" and categorie ~= "traits" then
            for _, ligne in ipairs(Creation.Lignes(categorie) or {}) do
                local id = ligne.id or ligne
                local valeur = tonumber(valeurs[id])
                if valeur and valeur ~= 0 then brouillon.valeurs[id] = valeur end
            end
        end
    end
    for _, champ in ipairs({ "sexe", "age", "poids", "taille", "portrait" }) do
        if valeurs[champ] ~= nil and valeurs[champ] ~= "" then
            brouillon.valeurs[champ] = valeurs[champ]
        end
    end
    RelireSexe(brouillon)
    for _, id in ipairs(modele.traits or {}) do
        brouillon.traits[#brouillon.traits + 1] = id
    end
    for _, metier in ipairs(LCM.Metiers and LCM.Metiers.list or {}) do
        local rang = LCM.Metiers.Palier(modele, metier.id).rang
        if rang > 0 then brouillon.metiers[metier.id] = rang end
    end
    return brouillon
end

function Creation.DepuisReequilibrage(entity)
    if not Creation.ReequilibrageRequis(entity) then
        return nil, "cette fiche utilise déjà l'équilibrage actuel."
    end
    local brouillon, erreur = Creation.Depuis(entity)
    if not brouillon then return nil, erreur end
    brouillon.mode = "reequilibrage"
    brouillon.versionCreationCible = Creation.VersionEquilibrage()
    return brouillon
end

-- Un passage ne rouvre pas toute la fiche : il part des investissements deja
-- valides, vise exactement le niveau suivant et conserve une photographie de
-- depart. Budgets et remises a zero ne portent alors que sur CE niveau.
function Creation.DepuisNiveau(entity)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    if Creation.ReequilibrageRequis(entity) then
        return nil, "rééquilibre d'abord ta fiche avec les règles actuelles."
    end
    if not (LCM.Experience and LCM.Experience.PeutMonter(entity)) then
        return nil, "aucun niveau en attente."
    end
    local brouillon, erreur = Creation.Depuis(entity)
    if not brouillon then return nil, erreur end
    local courant = LCM.Experience.NiveauFiche(entity)
    local base = Creation.Nouveau(courant)
    -- Une montée de niveau ne redistribue pas les métiers : ils restent sur
    -- la fiche, où leur XP progresse indépendamment de la création.
    brouillon.metiers, brouillon.metiersBudget, brouillon.metiersProgression = {}, nil, nil
    base.nom, base.race = brouillon.nom, brouillon.race
    for champ, valeur in pairs(brouillon.valeurs) do base.valeurs[champ] = valeur end
    for _, id in ipairs(brouillon.traits or {}) do base.traits[#base.traits + 1] = id end
    brouillon.mode = "niveau"
    brouillon.niveauAvant = courant
    brouillon.niveau = courant + 1
    brouillon.base = base
    return brouillon
end

function Creation.AppliquerNiveau(brouillon)
    if type(brouillon) ~= "table" or brouillon.mode ~= "niveau" then
        return nil, "passage de niveau invalide."
    end
    local entity = brouillon.entite
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    local courant = LCM.Experience.NiveauFiche(entity)
    if brouillon.niveauAvant ~= courant or brouillon.niveau ~= courant + 1 then
        return nil, "la fiche a changé depuis l'ouverture du passage de niveau."
    end
    if not LCM.Experience.PeutMonter(entity) then return nil, "aucun niveau en attente." end
    local problemes = Creation.Problemes(brouillon)
    if #problemes > 0 then return nil, problemes[1] end

    for _, categorie in ipairs(Creation.CATEGORIES) do
        if categorie ~= "traits" and categorie ~= "metiers" then
            for _, ligne in ipairs(Creation.Lignes(categorie)) do
                local id = ligne.id or ligne
                local valeur = Creation.Valeur(brouillon, id)
                LCM.Entities.Set_Value(entity, id, valeur ~= 0 and valeur or nil)
            end
        end
    end
    for _, id in ipairs(brouillon.traits or {}) do
        if not LCM.Traits.Has(entity, id) then LCM.Traits.Grant(entity, id) end
    end
    LCM.Entities.Set_Value(entity, "niveau", brouillon.niveau)
    if LCM.Entities.Changed then LCM.Entities.Changed(entity, "niveau") end
    return entity, LCM.Experience.NiveauxEnAttente(entity)
end

function Creation.Appliquer(brouillon)
    if brouillon and brouillon.mode == "niveau" then return Creation.AppliquerNiveau(brouillon) end
    local problemes = Creation.Problemes(brouillon)
    if #problemes > 0 then return nil, problemes[1] end

    -- Une race du compendium est rangee par son identifiant ; une race saisie,
    -- telle qu'elle a ete ecrite. Le champ `race` de la fiche porte les deux.
    local valeurs = {
        race = brouillon.race,
        niveau = brouillon.niveau,
    }
    -- « Autre » precise : c'est la precision qu'on garde, pas le mot « Autre ».
    if brouillon.valeurs.sexe == "Autre" and tostring(brouillon.sexeAutre or "") ~= "" then
        valeurs.sexe = brouillon.sexeAutre
    end
    for champ, valeur in pairs(brouillon.valeurs) do valeurs[champ] = valeur end

    -- Une REFONTE : la meme fiche, revue. Tout ce que la creation ne touche pas
    -- (jauges, sacs, equipement, etats) reste en place ; en recreant le
    -- personnage on l'aurait perdu.
    local entity, erreur = brouillon.entite, nil
    if entity then
        local reequilibrageImpose = brouillon.mode == "reequilibrage"
            or Creation.ReequilibrageRequis(entity)
        local peut, pourquoi = Creation.PeutEditer(entity)
        if not peut then return nil, pourquoi end
        -- On efface d'abord tout ce que l'outil de création gouverne. Sinon
        -- remettre une statistique ou l'âge à zéro ne ferait que l'omettre du
        -- brouillon, et l'ancienne valeur resterait silencieusement sur la fiche.
        local aRemplacer = {
            race = true, niveau = true, sexe = true, age = true,
            poids = true, taille = true, portrait = true,
        }
        for _, categorie in ipairs(Creation.CATEGORIES) do
            if categorie ~= "traits" and categorie ~= "metiers" then
                for _, ligne in ipairs(Creation.Lignes(categorie)) do
                    aRemplacer[ligne.id or ligne] = true
                end
            end
        end
        for champ in pairs(aRemplacer) do LCM.Entities.Set_Value(entity, champ, nil) end
        entity.name = brouillon.nom
        for champ, valeur in pairs(valeurs) do LCM.Entities.Set_Value(entity, champ, valeur) end
        -- Les traits se refont : ceux qu'on a retires partent, les nouveaux
        -- arrivent. Les laisser s'empiler doublerait leurs bonus.
        local garde = {}
        for _, id in ipairs(brouillon.traits) do garde[id] = true end
        for _, id in ipairs(LCM.Traits.Ids and LCM.Traits.Ids(entity) or {}) do
            if not garde[id] then LCM.Traits.Revoke(entity, id) end
        end
        for _, id in ipairs(brouillon.traits) do
            if not LCM.Traits.Has(entity, id) then LCM.Traits.Grant(entity, id) end
        end
        if brouillon.mode == "reedition" or brouillon.mode == "reequilibrage" then
            for _, metier in ipairs(LCM.Metiers.list or {}) do
                local id = metier.id
                local rang = math.max(0, math.floor(tonumber((brouillon.metiers or {})[id]) or 0))
                local progression = math.max(0,
                    math.floor(tonumber((brouillon.metiersProgression or {})[id]) or 0))
                local xp = LCM.Metiers.XPPourNiveau(rang)
                local prochain = LCM.Metiers.XPPourNiveau(rang + 1)
                if prochain > xp then progression = math.min(progression, prochain - xp - 1)
                else progression = 0 end
                local cible = xp + progression
                LCM.Metiers.Gagner(entity, id, cible - LCM.Metiers.XP(entity, id))
            end
        end
        -- Le jeton se consomme ICI, pas a l'ouverture : rouvrir sa fiche pour
        -- regarder, puis renoncer, ne doit rien couter. Le MJ, lui, n'en
        -- consomme pas.
        if not LCM.IsMaster() and not reequilibrageImpose then Creation.RetirerJeton(entity) end
        Creation.MarquerAJour(entity)
        if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
        return entity
    end

    -- Choisir le personnage nouvellement cree emet immediatement SoiChange.
    -- Le controle de versions ne doit pas prendre cette fiche pour un ancien
    -- profil pendant les quelques instructions qui precedent son marquage.
    Creation.applicationEnCours = true
    entity, erreur = LCM.Personnages.Creer(brouillon.nom, valeurs)
    Creation.applicationEnCours = nil
    if not entity then return nil, erreur end
    for _, id in ipairs(brouillon.traits) do LCM.Traits.Grant(entity, id) end
    -- Les points de creation donnent directement des NIVEAUX. La feuille des
    -- metiers, elle, stocke toujours de l'XP : le bareme central fait la
    -- conversion, de sorte qu'un point donne Rose 1 (40 XP), deux Rose 2, etc.
    for id, niveau in pairs(brouillon.metiers or {}) do
        local xp = LCM.Metiers.XPPourNiveau(niveau)
        if xp > 0 then LCM.Metiers.Gagner(entity, id, xp) end
    end
    Creation.MarquerAJour(entity)
    return entity
end
