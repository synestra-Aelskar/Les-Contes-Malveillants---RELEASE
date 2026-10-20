-- Les bannieres : de quoi a l'air le nom d'un lieu quand on y entre.
--
-- La geographie est dans Core/Lieux.lua ; ici, c'est l'APPARENCE. Un lieu (ou
-- un seuil en particulier) porte un THEME, et le theme dit tout : la
-- composition de fond, la police, les couleurs, les filets, le cadre, le
-- mouvement, la place a l'ecran, les durees et les sons.
--
-- Tout vient du module Zone Gate d'Omega Hub, y compris les images : les
-- quarante-deux compositions et les quinze polices sont l'ouvrage d'Akriaxx,
-- reprises avec son accord dans `ressources/bannieres` (10 octobre 2026).
-- Ce fichier est le catalogue et la tenue des themes ; UI/Banniere.lua est le
-- rendu, porte de son UI_Banner.lua.
--
-- Un theme est du CONTENU DE SEANCE, comme un lieu : il vit dans LCM_DB et
-- voyage par le reseau avec le lieu qui s'en sert. Sans quoi le MJ verrait sa
-- belle banniere et ses joueurs une ligne de texte nu.

local _, LCM = ...

local Bannieres = {}
LCM.Bannieres = Bannieres

local RESSOURCES = "Interface\\AddOns\\LesContesMalveillants\\ressources\\bannieres\\"
Bannieres.COMPOSITIONS_DOSSIER = RESSOURCES .. "compositions\\"
Bannieres.CADRE_COIN = RESSOURCES .. "FrameCorner.tga"
Bannieres.DEGRADE = RESSOURCES .. "Gradient.tga"

local NOM_MAX = 40

-- ===== Les polices =========================================================
-- Trois du client, quinze livrees avec l'addon (Google Fonts, licence SIL Open
-- Font — les OFL-*.txt sont a cote des fichiers), plus un chemin libre. Les
-- autres polices du client sont des jeux de glyphes cyrilliques ou asiatiques :
-- inutilisables pour du francais.
local POLICES_DOSSIER = RESSOURCES .. "polices\\"

Bannieres.POLICES = {
    frizqt          = { chemin = "Fonts\\FRIZQT__.TTF",  label = "Standard" },
    skurri          = { chemin = "Fonts\\SKURRI.TTF",    label = "Rugueux" },
    morpheus        = { chemin = "Fonts\\MORPHEUS.TTF",  label = "Fantastique" },
    cinzel          = { chemin = POLICES_DOSSIER .. "Cinzel-Regular.ttf",          label = "Épique" },
    metamorphous    = { chemin = POLICES_DOSSIER .. "Metamorphous-Regular.ttf",    label = "Runique" },
    pirataone       = { chemin = POLICES_DOSSIER .. "PirataOne-Regular.ttf",       label = "Gothique" },
    medievalsharp   = { chemin = POLICES_DOSSIER .. "MedievalSharp-Regular.ttf",   label = "Manuscrit" },
    marcellus       = { chemin = POLICES_DOSSIER .. "Marcellus-Regular.ttf",       label = "Sanctuaire" },
    cormorantsc     = { chemin = POLICES_DOSSIER .. "CormorantSC-Regular.ttf",     label = "Poétique" },
    almendra        = { chemin = POLICES_DOSSIER .. "Almendra-Regular.ttf",        label = "Conte ancien" },
    amiri           = { chemin = POLICES_DOSSIER .. "Amiri-Regular.ttf",           label = "Lettré" },
    tajawal         = { chemin = POLICES_DOSSIER .. "Tajawal-Regular.ttf",         label = "Épuré" },
    rajdhani        = { chemin = POLICES_DOSSIER .. "Rajdhani-Regular.ttf",        label = "Futuriste" },
    rye             = { chemin = POLICES_DOSSIER .. "Rye-Regular.ttf",             label = "Western" },
    forum           = { chemin = POLICES_DOSSIER .. "Forum-Regular.ttf",           label = "Antique" },
    barlowcondensed = { chemin = POLICES_DOSSIER .. "BarlowCondensed-Regular.ttf", label = "Survie" },
    philosopher     = { chemin = POLICES_DOSSIER .. "Philosopher-Regular.ttf",     label = "Voyage" },
    caudex          = { chemin = POLICES_DOSSIER .. "Caudex-Regular.ttf",          label = "Chronique" },
    perso           = { chemin = nil, label = "Personnalisée (chemin)" },
}
Bannieres.ORDRE_POLICES = {
    "frizqt", "skurri", "morpheus",
    "cinzel", "metamorphous", "pirataone", "medievalsharp",
    "marcellus", "cormorantsc", "almendra", "amiri", "tajawal",
    "rajdhani", "rye", "forum", "barlowcondensed", "philosopher", "caudex",
    "perso",
}

-- ===== Les compositions ====================================================
-- Le fond image de la banniere. « aucune » : pas d'image, juste le texte et
-- ses filets — c'est le rendu d'origine, et il reste le defaut.
--
-- Les groupes servent la galerie de l'atelier : quarante-deux vignettes a la
-- suite, on n'y trouve rien.
local function C(id, label, groupe) return { id = id, label = label, groupe = groupe } end

Bannieres.COMPOSITIONS = {
    C("aucune", "Aucune", "Sobre"),
    C("souls", "Âmes", "Compositions"),
    C("western", "Western", "Compositions"),
    C("sumi", "Encre", "Compositions"),
    C("scifi", "Science-fiction", "Compositions"),
    C("deco", "Art déco", "Compositions"),
    C("minimal", "Épuré", "Compositions"),
    C("forest_spring", "Forêt — printemps", "Paysages"),
    C("forest_summer", "Forêt — été", "Paysages"),
    C("forest_autumn", "Forêt — automne", "Paysages"),
    C("forest_winter", "Forêt — hiver", "Paysages"),
    C("mountains", "Montagnes", "Paysages"),
    C("snowpeaks", "Cimes enneigées", "Paysages"),
    C("desert", "Désert", "Paysages"),
    C("ocean", "Océan", "Paysages"),
    C("marsh", "Marais", "Paysages"),
    C("ruins", "Ruines", "Paysages"),
    C("volcano", "Volcan", "Paysages"),
    C("cavern", "Caverne", "Paysages"),
    C("relic", "Relique", "Univers"),
    C("crystal", "Cristal", "Univers"),
    C("hunt", "Chasse", "Univers"),
    C("gothic", "Gothique", "Univers"),
    C("runes", "Runes", "Univers"),
    C("portal", "Portail", "Univers"),
    C("quiet_sacred", "Sanctuaire", "Sobres"),
    C("quiet_survivor", "Survie", "Sobres"),
    C("quiet_reverie", "Rêverie", "Sobres"),
    C("quiet_ronin", "Rônin", "Sobres"),
    C("quiet_orbit", "Orbite", "Sobres"),
    C("quiet_ashen", "Cendres", "Sobres"),
    C("quiet_noir", "Noir", "Sobres"),
    C("quiet_fable", "Fable", "Sobres"),
    C("quiet_bamboo", "Bambou", "Sobres"),
    C("quiet_sakura", "Sakura", "Sobres"),
    C("quiet_jade", "Jade", "Sobres"),
    C("quiet_wave", "Vague", "Sobres"),
    C("quiet_rosette", "Rosace", "Sobres"),
    C("quiet_arch", "Arcade", "Sobres"),
    C("quiet_lattice", "Treillis", "Sobres"),
    C("quiet_arabesque", "Arabesque", "Sobres"),
    C("quiet_caravan", "Caravane", "Sobres"),
    C("quiet_copper", "Cuivre", "Sobres"),
}

Bannieres.GROUPES = { "Sobre", "Compositions", "Paysages", "Univers", "Sobres" }

local parId = {}
for _, c in ipairs(Bannieres.COMPOSITIONS) do parId[c.id] = c end
function Bannieres.Composition(id) return parId[tostring(id or "")] end

-- Une composition a-t-elle une image ? « aucune » n'en a pas.
function Bannieres.Image(id)
    local c = parId[tostring(id or "")]
    if not c or c.id == "aucune" then return nil end
    return Bannieres.COMPOSITIONS_DOSSIER .. c.id .. ".tga"
end

Bannieres.SEPARATEURS = { simple = "Simple", double = "Double", aucun = "Aucun" }
Bannieres.ORDRE_SEPARATEURS = { "simple", "double", "aucun" }
Bannieres.CADRES = { aucun = "Aucun", trait = "Simple", orne = "Orné" }
Bannieres.ORDRE_CADRES = { "aucun", "trait", "orne" }
Bannieres.MOUVEMENTS = { fondu = "Fondu", montee = "Montée", frappe = "Frappe", ouverture = "Ouverture" }
Bannieres.ORDRE_MOUVEMENTS = { "fondu", "montee", "frappe", "ouverture" }
Bannieres.PLACEMENTS = { haut = "En haut", centre = "Au centre", bas = "En bas" }
Bannieres.ORDRE_PLACEMENTS = { "haut", "centre", "bas" }

-- ===== Le theme par defaut =================================================
-- Il reproduit le rendu d'avant les themes : pas d'image, deux filets, la
-- police du client. Un lieu qui n'a rien choisi ressemble donc a ce qu'il
-- ressemblait, et rien ne change sous les pieds de personne.
Bannieres.DEFAUT = {
    composition = "aucune", mouvement = "fondu", placement = "haut", largeur = 600,
    police = "frizqt", policePerso = "", taille = 28,
    couleurTitre = { 1.00, 0.90, 0.55 }, couleurSous = { 0.72, 0.68, 0.55 },
    contour = false, majuscules = false, espacement = false,
    separateur = "simple", couleurFilet = { 0.25, 0.25, 0.25, 1.00 }, filetMilieu = false,
    fondActif = false, couleurFond = { 0, 0, 0, 0.55 },
    cadre = "aucun", couleurCadre = { 0.82, 0.66, 0.20, 0.90 },
    apparition = 0.4, maintien = 2.5, disparition = 0.8,
    sonEntree = "", sonSortie = "",
}

-- Les champs, avec leur nature : c'est ce qui permet a l'atelier de construire
-- son formulaire et au reseau de relire les valeurs dans le bon type, sans
-- qu'aucun des deux ne redise la liste.
Bannieres.CHAMPS = {
    { cle = "composition", nature = "choix", label = "Composition" },
    { cle = "mouvement",   nature = "choix", label = "Mouvement" },
    { cle = "placement",   nature = "choix", label = "Place à l'écran" },
    { cle = "largeur",     nature = "nombre", label = "Largeur", min = 400, max = 900 },
    { cle = "police",      nature = "choix", label = "Police" },
    { cle = "policePerso", nature = "texte", label = "Chemin de la police" },
    { cle = "taille",      nature = "nombre", label = "Taille du titre", min = 12, max = 64 },
    { cle = "couleurTitre", nature = "couleur", label = "Couleur du titre" },
    { cle = "couleurSous",  nature = "couleur", label = "Couleur du sous-titre" },
    { cle = "contour",     nature = "oui", label = "Contour du texte" },
    { cle = "majuscules",  nature = "oui", label = "Majuscules" },
    { cle = "espacement",  nature = "oui", label = "Lettres espacées" },
    { cle = "separateur",  nature = "choix", label = "Filets" },
    { cle = "couleurFilet", nature = "couleurA", label = "Couleur des filets" },
    { cle = "filetMilieu", nature = "oui", label = "Filet entre titre et sous-titre" },
    { cle = "fondActif",   nature = "oui", label = "Fond" },
    { cle = "couleurFond", nature = "couleurA", label = "Couleur du fond" },
    { cle = "cadre",       nature = "choix", label = "Cadre" },
    { cle = "couleurCadre", nature = "couleurA", label = "Couleur du cadre" },
    { cle = "apparition",  nature = "duree", label = "Apparition", min = 0.05, max = 3 },
    { cle = "maintien",    nature = "duree", label = "Maintien", min = 0, max = 15 },
    { cle = "disparition", nature = "duree", label = "Disparition", min = 0.05, max = 5 },
    { cle = "sonEntree",   nature = "texte", label = "Son en entrant" },
    { cle = "sonSortie",   nature = "texte", label = "Son en sortant" },
}

local champParCle = {}
for _, c in ipairs(Bannieres.CHAMPS) do champParCle[c.cle] = c end

-- ===== Sauvegarde ==========================================================

local function Magasin()
    LCM.EnsureDatabase()
    if type(LCM.db.themes) ~= "table" then LCM.db.themes = {} end
    return LCM.db.themes
end

local function Moi() return LCM.PlayerId() end

local function Texte(valeur, maximum)
    local t = tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if maximum and #t > maximum then t = t:sub(1, maximum) end
    return t
end

local function Copier(source)
    local out = {}
    for cle, valeur in pairs(source) do
        if type(valeur) == "table" then
            local t = {}
            for i, v in ipairs(valeur) do t[i] = v end
            out[cle] = t
        else
            out[cle] = valeur
        end
    end
    return out
end

local function Prevenir()
    if Bannieres.onChange then Bannieres.onChange() end
end

-- ===== Lire ================================================================

function Bannieres.Get(id)
    if not id then return nil end
    return Magasin()[tostring(id)]
end

function Bannieres.Liste()
    local out = {}
    for _, theme in pairs(Magasin()) do out[#out + 1] = theme end
    table.sort(out, function(a, b)
        local na, nb = tostring(a.nom or ""):lower(), tostring(b.nom or ""):lower()
        if na ~= nb then return na < nb end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

function Bannieres.AMoi(theme)
    return theme ~= nil and theme.auteur == Moi()
end

-- Le theme qui s'applique : celui du SEUIL s'il en a un, sinon celui du lieu,
-- sinon le defaut. Le seuil l'emporte — une porte peut tonner la ou le reste
-- du lieu chuchote.
function Bannieres.Resoudre(seuil, lieu)
    local theme = (seuil and seuil.theme and Bannieres.Get(seuil.theme))
        or (lieu and lieu.theme and Bannieres.Get(lieu.theme))
    if not theme then return Bannieres.DEFAUT end
    return theme
end

-- Une valeur du theme, avec le defaut en repli : un theme recu d'une version
-- plus ancienne n'a pas forcement tous les champs.
function Bannieres.Valeur(theme, cle)
    theme = theme or Bannieres.DEFAUT
    local v = theme[cle]
    if v == nil then return Bannieres.DEFAUT[cle] end
    return v
end

-- ===== Ecrire ==============================================================

local function Identifiant()
    return string.format("t_%d_%04d", (time and time()) or 0, math.random(0, 9999))
end

function Bannieres.Creer(nom, modele)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local theme = Copier(modele or Bannieres.DEFAUT)
    theme.id = Identifiant()
    theme.auteur = Moi()
    theme.nom = Texte(nom, NOM_MAX)
    if theme.nom == "" then theme.nom = "Nouveau thème" end
    Magasin()[theme.id] = theme
    Bannieres.Diffuser(theme.id)
    Prevenir()
    return theme
end

function Bannieres.Dupliquer(id)
    local theme = Bannieres.Get(id)
    if not theme then return nil, "thème introuvable." end
    return Bannieres.Creer(tostring(theme.nom) .. " (copie)", theme)
end

local function Mien(id)
    local theme = Bannieres.Get(id)
    if not theme then return nil, "thème introuvable." end
    if not Bannieres.AMoi(theme) then
        return nil, "ce thème est à " .. tostring(theme.auteur) .. "."
    end
    return theme
end

function Bannieres.Renommer(id, nom)
    local theme, raison = Mien(id)
    if not theme then return false, raison end
    nom = Texte(nom, NOM_MAX)
    if nom == "" then return false, "il faut un nom." end
    theme.nom = nom
    Bannieres.Diffuser(id)
    Prevenir()
    return true
end

function Bannieres.Retirer(id)
    local theme, raison = Mien(id)
    if not theme then return false, raison end
    Magasin()[tostring(id)] = nil
    Bannieres.AnnoncerRetrait(id)
    Prevenir()
    return true
end

-- Un seul point d'ecriture pour tous les champs : la nature du champ dit
-- comment lire la valeur, et c'est la meme table qui sert a l'atelier. Vingt
-- petites fonctions auraient diverge.
function Bannieres.Definir(id, cle, valeur)
    local theme, raison = Mien(id)
    if not theme then return false, raison end
    local champ = champParCle[tostring(cle or "")]
    if not champ then return false, "champ de thème inconnu." end

    if champ.nature == "nombre" or champ.nature == "duree" then
        local n = tonumber(valeur)
        if not n then return false, string.format("« %s » attend un nombre.", champ.label) end
        if champ.min and n < champ.min then n = champ.min end
        if champ.max and n > champ.max then n = champ.max end
        theme[cle] = n
    elseif champ.nature == "oui" then
        theme[cle] = valeur and true or false
    elseif champ.nature == "texte" then
        theme[cle] = Texte(valeur, 180)
    elseif champ.nature == "choix" then
        local v = tostring(valeur or "")
        local bon =
            (cle == "composition" and parId[v] ~= nil)
            or (cle == "police" and Bannieres.POLICES[v] ~= nil)
            or (cle == "separateur" and Bannieres.SEPARATEURS[v] ~= nil)
            or (cle == "cadre" and Bannieres.CADRES[v] ~= nil)
            or (cle == "mouvement" and Bannieres.MOUVEMENTS[v] ~= nil)
            or (cle == "placement" and Bannieres.PLACEMENTS[v] ~= nil)
        if not bon then return false, string.format("« %s » : choix inconnu.", champ.label) end
        theme[cle] = v
    elseif champ.nature == "couleur" or champ.nature == "couleurA" then
        if type(valeur) ~= "table" then return false, "une couleur attend trois ou quatre nombres." end
        local c = { tonumber(valeur[1]) or 0, tonumber(valeur[2]) or 0, tonumber(valeur[3]) or 0 }
        if champ.nature == "couleurA" then c[4] = tonumber(valeur[4]) or 1 end
        theme[cle] = c
    end

    Bannieres.Diffuser(id)
    Prevenir()
    return true
end

-- ===== Le texte, mis en forme ==============================================
-- Majuscules et lettres espacees. En Lua 5.1 `string.upper` ne connait que
-- l'ASCII : un caractere accentue resterait tel quel. UI.Majuscules sait le
-- faire, et on s'en sert quand l'interface est la (c'est toujours le cas pour
-- une banniere, jamais au banc en mode pur).
local function Decouper(texte)
    local out, i, n = {}, 1, #texte
    while i <= n do
        local b = texte:byte(i)
        local large = 1
        if b >= 240 then large = 4
        elseif b >= 224 then large = 3
        elseif b >= 192 then large = 2 end
        out[#out + 1] = texte:sub(i, i + large - 1)
        i = i + large
    end
    return out
end

function Bannieres.StyleTexte(texte, theme)
    texte = tostring(texte or "")
    if texte == "" then return texte end
    theme = theme or Bannieres.DEFAUT
    if Bannieres.Valeur(theme, "majuscules") then
        texte = (LCM.UI and LCM.UI.Majuscules and LCM.UI.Majuscules(texte)) or texte:upper()
    end
    if Bannieres.Valeur(theme, "espacement") then
        texte = table.concat(Decouper(texte), " ")
    end
    return texte
end

-- Le chemin de la police a poser. nil : celle du client.
function Bannieres.CheminPolice(theme)
    theme = theme or Bannieres.DEFAUT
    local police = Bannieres.Valeur(theme, "police")
    if police == "perso" then
        local chemin = Texte(Bannieres.Valeur(theme, "policePerso"))
        return chemin ~= "" and chemin or nil
    end
    local entree = Bannieres.POLICES[police]
    return entree and entree.chemin or nil
end

-- Le son d'un franchissement : un identifiant de son du jeu (un nombre) ou un
-- chemin de fichier. Essaye dans cet ordre, et se tait si rien ne joue — un
-- chemin faux ne doit jamais casser un franchissement.
function Bannieres.Jouer(theme, sens)
    theme = theme or Bannieres.DEFAUT
    local valeur = Texte(Bannieres.Valeur(theme, sens == "retour" and "sonSortie" or "sonEntree"))
    if valeur == "" then return false end
    local identifiant = tonumber(valeur)
    if identifiant and PlaySound then
        local ok, joue = pcall(PlaySound, identifiant, "Master")
        if ok and joue then return true end
    end
    if PlaySoundFile then
        local ok = pcall(PlaySoundFile, valeur, "Master")
        return ok and true or false
    end
    return false
end

-- ===== Reseau ==============================================================
-- Un theme voyage avec le lieu qui s'en sert : sinon le MJ voit sa banniere et
-- ses joueurs du texte nu. Cles courtes, couleurs pliees en une chaine : un
-- theme complet doit passer sans etre decoupe en dix morceaux.

local SUJET, SUJET_RETRAIT = "theme", "theme-"
local enReception = false

local function Canal()
    return LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
end

local function PlierCouleur(c)
    if type(c) ~= "table" then return nil end
    local out = {}
    for i = 1, 4 do
        if c[i] == nil then break end
        out[#out + 1] = string.format("%.3f", c[i])
    end
    return table.concat(out, ",")
end

local function DeplierCouleur(texte, avecAlpha)
    local out = {}
    for bout in tostring(texte or ""):gmatch("[^,]+") do out[#out + 1] = tonumber(bout) or 0 end
    if #out < 3 then return nil end
    if not avecAlpha then out[4] = nil end
    return out
end

local function Paquet(theme)
    local p = { id = theme.id, n = theme.nom }
    for _, champ in ipairs(Bannieres.CHAMPS) do
        local v = theme[champ.cle]
        if v ~= nil then
            if champ.nature == "couleur" or champ.nature == "couleurA" then
                p[champ.cle] = PlierCouleur(v)
            elseif champ.nature == "oui" then
                p[champ.cle] = v and 1 or 0
            else
                p[champ.cle] = v
            end
        end
    end
    return p
end

-- Le decodeur rend TOUT en texte : chaque champ est relu dans son type ici, et
-- nulle part ailleurs.
local function Lire(paquet, expediteur)
    local id = Texte(paquet.id)
    if id == "" then return nil end
    local theme = Copier(Bannieres.DEFAUT)
    theme.id, theme.auteur = id, expediteur
    theme.nom = Texte(paquet.n, NOM_MAX)
    if theme.nom == "" then theme.nom = "Thème sans nom" end
    for _, champ in ipairs(Bannieres.CHAMPS) do
        local brut = paquet[champ.cle]
        if brut ~= nil then
            if champ.nature == "couleur" then
                theme[champ.cle] = DeplierCouleur(brut, false) or theme[champ.cle]
            elseif champ.nature == "couleurA" then
                theme[champ.cle] = DeplierCouleur(brut, true) or theme[champ.cle]
            elseif champ.nature == "oui" then
                theme[champ.cle] = tostring(brut) == "1"
            elseif champ.nature == "nombre" or champ.nature == "duree" then
                theme[champ.cle] = tonumber(brut) or theme[champ.cle]
            else
                theme[champ.cle] = Texte(brut, 180)
            end
        end
    end
    return theme
end

function Bannieres.Diffuser(id)
    if enReception then return false end
    local theme = Bannieres.Get(id)
    if not theme or not Bannieres.AMoi(theme) then return false end
    local canal = Canal()
    if not canal then return false, "hors groupe : le thème est enregistré, mais personne ne le voit." end
    return LCM.Reseau.Envoyer(SUJET, Paquet(theme), canal, nil, { etale = true })
end

function Bannieres.AnnoncerRetrait(id)
    local canal = Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer(SUJET_RETRAIT, { id = id }, canal)
end

function Bannieres.Renvoyer()
    local n = 0
    for _, theme in ipairs(Bannieres.Liste()) do
        if Bannieres.AMoi(theme) and Bannieres.Diffuser(theme.id) then n = n + 1 end
    end
    return n
end

LCM.WhenReady(function()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(SUJET, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local theme = Lire(donnees, expediteur)
        if not theme then return end
        local ancien = Magasin()[theme.id]
        -- Un theme recu n'ecrase jamais un theme dont je suis l'auteur.
        if ancien and Bannieres.AMoi(ancien) then return end
        enReception = true
        Magasin()[theme.id] = theme
        enReception = false
        Prevenir()
    end)

    LCM.Reseau.Ecouter(SUJET_RETRAIT, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local id = Texte(donnees.id)
        local theme = Magasin()[id]
        if not theme or theme.auteur ~= expediteur then return end
        Magasin()[id] = nil
        Prevenir()
    end)
end)
