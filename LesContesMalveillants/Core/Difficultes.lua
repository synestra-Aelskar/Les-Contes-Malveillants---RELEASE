-- Les difficultes : un nombre, range dans une couleur de metier (2 novembre
-- 2026, ajout de l'addon). Les nombres vivent dans Equilibrage.difficultes ;
-- ici, de quoi les lire, les ajouter en seance, et calculer le coefficient
-- d'XP qu'une difficulte vaut pour un metier donne.
--
-- Ajouter une difficulte passe par les REGLAGES (Core/Reglages.lua), comme
-- tout nombre de l'equilibrage : « difficultes.niveaux.<n> = <rang> ». Elle
-- s'applique tout de suite, se diffuse au groupe, et reste a exporter. Aucune
-- structure ne vit en sauvegarde pour autant : c'est une surcharge du
-- fichier, que l'export rend definitive.

local _, LCM = ...

local Difficultes = {}
LCM.Difficultes = Difficultes

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Eq() return LCM.Equilibrage and LCM.Equilibrage.difficultes or {} end

-- Les six couleurs, telles que les metiers les nomment et les peignent : la
-- difficulte n'a pas sa propre palette, c'est tout l'interet de la comparer.
-- Les couleurs sont les paliers de l'echelle (Core/Nommages.lua, le MJ,
-- 2 novembre 2026) : une seule echelle pour tout le jeu.
function Difficultes.Couleurs()
    local out = {}
    for _, p in ipairs(LCM.Nommages.Liste()) do
        out[#out + 1] = { rang = p.rang, nom = p.nom, couleur = p.couleur, id = p.id }
    end
    return out
end

-- Les couleurs que porte un METIER : les sept couleurs de base, Rose a Noir,
-- telles que Equilibrage.metiers.paliers les nomme et les peint. Elles ne
-- suivent PAS les Nommages (le MJ, 3 novembre 2026) : l'echelle decoupee en
-- « Rose Facile, Rose, Rose Difficile… » nomme les difficultes ; un metier
-- reste Rose, Vert… C'est le premier indice de la matrice des coefficients.
function Difficultes.CouleursMetier()
    local out, vus = {}, {}
    local paliers = LCM.Equilibrage and LCM.Equilibrage.metiers and LCM.Equilibrage.metiers.paliers or {}
    for _, palier in ipairs(paliers) do
        local rang = tonumber(palier.rangCouleur)
        if rang and not vus[rang] then
            vus[rang] = true
            out[#out + 1] = { rang = rang, nom = palier.nom, couleur = palier.couleur, id = "metier_" .. rang }
        end
    end
    table.sort(out, function(a, b) return a.rang < b.rang end)
    return out
end

function Difficultes.Couleur(rang)
    for _, c in ipairs(Difficultes.Couleurs()) do
        if c.rang == tonumber(rang) then return c end
    end
end

-- Les difficultes posees, dans l'ordre croissant. Une cle ajoutee en seance
-- arrive en texte (« 15 ») par le chemin du reglage, une cle du fichier en
-- nombre : on lit les deux. Un rang 0 est une difficulte ecartee.
function Difficultes.Liste()
    local out = {}
    for cle, rang in pairs(Eq().niveaux or {}) do
        local valeur, r = tonumber(cle), tonumber(rang)
        if valeur and r and r >= 1 then
            local couleur = Difficultes.Couleur(r)
            if couleur then
                out[#out + 1] = { valeur = valeur, rang = r, nom = couleur.nom, couleur = couleur.couleur }
            end
        end
    end
    table.sort(out, function(a, b) return a.valeur < b.valeur end)
    return out
end

function Difficultes.Get(valeur)
    valeur = tonumber(valeur)
    if not valeur then return nil end
    for _, d in ipairs(Difficultes.Liste()) do
        if d.valeur == valeur then return d end
    end
end

local function Chemin(valeur) return "difficultes.niveaux." .. tostring(valeur) end

-- Ajouter ou recolorer une difficulte. Rend true, ou false et la raison. Le
-- refus dit pourquoi : un nombre non entier ou une couleur qui n'existe pas
-- ne sont pas corriges en douce.
function Difficultes.Definir(valeur, rang)
    local v, r = tonumber(valeur), tonumber(rang)
    if not v or v ~= math.floor(v) or v < 0 then
        return false, "une difficulté est un nombre entier, positif ou nul."
    end
    if not r or not Difficultes.Couleur(r) then
        return false, "choisis une couleur, de Rose à Noir."
    end
    return LCM.Reglages.Definir(Chemin(v), r)
end

-- Retirer : une difficulte ajoutee en seance disparait ; une difficulte du
-- fichier ne s'efface pas d'ici (le fichier fait foi), elle s'ECARTE avec un
-- rang 0, ce que la liste ne montre plus et que l'export reportera.
function Difficultes.Retirer(valeur)
    local v = tonumber(valeur)
    if not v then return false, "difficulté inconnue." end
    local chemin = Chemin(v)
    local surcharge = LCM.Reglages.Surcharges()[chemin] ~= nil
    if surcharge and LCM.Reglages.Defaut(chemin) == nil then
        return LCM.Reglages.Retirer(chemin)
    end
    return LCM.Reglages.Definir(chemin, 0)
end

-- Changer le NOMBRE d'une difficulte en gardant sa couleur (le MJ, 2 novembre
-- 2026). Un nombre deja pris est refuse : deux difficultes ne partagent pas
-- un DD. Ce qui utilisait l'ancien DD (une ressource, un coffre) le garde, et
-- s'affiche « hors liste » : on ne le change pas dans son dos.
function Difficultes.Renumeroter(ancien, nouveau)
    local d = Difficultes.Get(ancien)
    if not d then return false, "difficulté inconnue." end
    local v = tonumber(nouveau)
    if not v or v ~= math.floor(v) or v < 0 then
        return false, "une difficulté est un nombre entier, positif ou nul."
    end
    if v == d.valeur then return true end
    if Difficultes.Get(v) then return false, string.format("la difficulté %d existe déjà.", v) end
    local ok, raison = Difficultes.Definir(v, d.rang)
    if not ok then return false, raison end
    return Difficultes.Retirer(d.valeur)
end

-- Le coefficient d'XP : une case de la matrice (couleur du metier, couleur
-- de la difficulte), Equilibrage.difficultes.matrice. Un metier non appris
-- (rang 0) n'a pas de couleur : il prend la ligne Rose. Une case absente vaut
-- 1, pour qu'une couleur ajoutee demain ne fasse pas perdre toute l'XP sans
-- le dire. `Relation` reste, pour le dire en mots.
function Difficultes.Relation(rangMetier, rangDifficulte)
    rangMetier, rangDifficulte = tonumber(rangMetier) or 0, tonumber(rangDifficulte) or 0
    if rangDifficulte < rangMetier then return "dessous" end
    if rangDifficulte == rangMetier then return "egale" end
    return "dessus"
end

function Difficultes.Coefficient(rangMetier, rangDifficulte)
    local relation = Difficultes.Relation(rangMetier, rangDifficulte)
    local ligne = (Eq().matrice or {})[math.max(1, tonumber(rangMetier) or 0)]
    local case = ligne and ligne[tonumber(rangDifficulte) or 0]
    return tonumber(case) or 1, relation
end

-- La couleur de base d'un palier de l'echelle, d'apres son NOM : « Rose
-- Facile », « Rose » et « Rose Difficile » sont du Rose (rang de metier 1).
-- Un mot entier, pour qu'un « Rosace » ne passe pas pour du Rose. Nil quand
-- le nom ne contient aucune des couleurs des metiers : on ne devine pas.
function Difficultes.CouleurDeBase(nom)
    local texte = " " .. tostring(nom or ""):lower() .. " "
    for _, c in ipairs(Difficultes.CouleursMetier()) do
        local motif = tostring(c.nom or ""):lower():gsub("%p", "%%%0")
        if motif ~= "" and texte:find("[^%a]" .. motif .. "[^%a]") then return c.rang end
    end
end

-- Le coefficient PAR DEFAUT d'un metier face a un palier (Equilibrage.
-- difficultes.defaut, le MJ, 3 novembre 2026). Nil si le palier n'a pas de
-- couleur reconnaissable ou si la regle manque : rien n'est invente.
function Difficultes.CoefficientParDefaut(rangMetier, nomDifficulte)
    local couleur = Difficultes.CouleurDeBase(nomDifficulte)
    local r = Eq().defaut
    if not couleur or type(r) ~= "table" then return nil end
    local ecart = couleur - (tonumber(rangMetier) or 0)
    if ecart >= 0 then
        local egale, pas = tonumber(r.egale), tonumber(r.parCouleurAuDessus)
        if not egale or not pas then return nil end
        return egale + pas * ecart
    end
    if ecart == -1 then return tonumber(r.uneEnDessous) end
    return tonumber(r.auDela)
end

-- Le chemin de reglage d'une case : « difficultes.matrice.3.5 ».
function Difficultes.CheminCoefficient(rangMetier, rangDifficulte)
    return string.format("difficultes.matrice.%d.%d", tonumber(rangMetier) or 0, tonumber(rangDifficulte) or 0)
end

-- Pour un personnage et un metier : le coefficient que vaut la difficulte.
function Difficultes.CoefficientPour(entity, metierId, valeur)
    local d = Difficultes.Get(valeur)
    if not d then return nil, "difficulté inconnue." end
    local rangMetier = LCM.Metiers.Palier(entity, metierId).rangCouleur or 0
    return Difficultes.Coefficient(rangMetier, d.rang)
end

-- ===== Une difficulte, partout =============================================
-- Les difficultes ne servent pas qu'aux filons (le MJ, 2 novembre 2026) :
-- une epreuve, un jet d'expertise, une ressource se choisissent dans la meme
-- liste, « DD 15 · Rose ». Tant que le MJ n'en a pose aucune, les ecrans
-- gardent leur champ libre : rien ne se bloque en attendant la liste.

function Difficultes.Actives()
    return #Difficultes.Liste() > 0
end

local function Hex(couleur)
    if type(couleur) ~= "table" then return "ffffff" end
    return string.format("%02x%02x%02x", math.floor((couleur[1] or 1) * 255),
        math.floor((couleur[2] or 1) * 255), math.floor((couleur[3] or 1) * 255))
end

-- « DD 15 · Rose », dans sa couleur. Un DD qui n'est pas (ou plus) dans la
-- liste s'affiche tel quel, et le dit : on ne le remplace pas en douce.
function Difficultes.Libelle(valeur, sansCouleur)
    valeur = tonumber(valeur)
    if not valeur then return "" end
    local d = Difficultes.Get(valeur)
    if not d then return string.format("DD %d (hors liste)", valeur) end
    if sansCouleur then return string.format("DD %d · %s", d.valeur, d.nom) end
    -- En couleur, le nom du palier est de trop : la couleur le dit deja, et
    -- les menus gagnent la place (le MJ, 2 novembre 2026). Sans couleur (le
    -- chat, un texte brut), le nom reste.
    return string.format("|cff%sDD %d|r", Hex(d.couleur), d.valeur)
end

-- Les choix d'un menu deroulant : { id = valeur, label = « DD 15 · Rose » }.
-- `premier` : une entree a mettre en tete (« Sans jet », DD 0).
-- « DD 9 · Rose Facile », en couleur ET avec le nom du palier (le MJ,
-- 3 novembre 2026 : dans la forge des ressources, la couleur seule ne disait
-- pas QUEL palier — Rose Facile, Rose et Rose Difficile se ressemblent).
function Difficultes.LibelleNomme(valeur)
    valeur = tonumber(valeur)
    if not valeur then return "" end
    local d = Difficultes.Get(valeur)
    if not d then return string.format("DD %d (hors liste)", valeur) end
    return string.format("|cff%sDD %d · %s|r", Hex(d.couleur), d.valeur, tostring(d.nom))
end

-- `nomme` : le libelle porte le nom du palier (Difficultes.LibelleNomme).
function Difficultes.Options(premier, nomme)
    local out = {}
    if premier then out[#out + 1] = premier end
    for _, d in ipairs(Difficultes.Liste()) do
        out[#out + 1] = { id = d.valeur,
            label = nomme and Difficultes.LibelleNomme(d.valeur) or Difficultes.Libelle(d.valeur) }
    end
    return out
end

-- La difficulte qui suit `dd` dans la liste : c'est le seuil du NF (« No
-- Fatigue »). Nil quand `dd` est la plus haute.
function Difficultes.Suivante(dd)
    dd = tonumber(dd)
    if not dd then return nil end
    for _, d in ipairs(Difficultes.Liste()) do
        if d.valeur > dd then return d end
    end
end
