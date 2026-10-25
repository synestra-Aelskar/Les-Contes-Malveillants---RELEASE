-- Les raccourcis du joueur (le MJ, 25 octobre 2026) : ce qu'il veut sous la
-- main, a droite du sceau (Alt + clic, UI/PanneauRaccourcis.lua).
--
-- Ce n'est pas de la structure : la sauvegarde ne retient que des REFERENCES
-- vers ce qui existe deja dans le code ou le contenu, dans l'ordre choisi.
--   fenetre:<id du menu>         une entree de UI/Menu.lua (« fenetre:fiche »)
--   outil:<id d'objet>           un outil, qui se sert s'il est equipe
--   lanterne:<id>                une lanterne, de meme
--   sort:<grimoire>:<sort>       un sort d'un grimoire possede
-- Une reference dont la cible a disparu reste, eteinte, et le dit : on ne
-- retire rien dans le dos du joueur (CLAUDE.md).
--
-- Rangees par personnage (l'entite jouee) : un autre personnage n'a ni les
-- memes outils ni les memes sorts.

local _, LCM = ...

local Raccourcis = {}
LCM.Raccourcis = Raccourcis

local VIDE = {}
local GENRES = { fenetre = true, outil = true, lanterne = true, sort = true }

local function Cle(entity) return type(entity) == "table" and entity.id and tostring(entity.id) or nil end

-- Lecture seule : ne cree rien dans la sauvegarde.
function Raccourcis.Liste(entity)
    local cle = Cle(entity)
    local t = cle and LCM.db and LCM.db.raccourcis
    return (t and type(t[cle]) == "table") and t[cle] or VIDE
end

local function ListePourEcrire(entity)
    local cle = Cle(entity)
    if not cle then return nil end
    LCM.EnsureDatabase()
    LCM.db.raccourcis = LCM.db.raccourcis or {}
    LCM.db.raccourcis[cle] = LCM.db.raccourcis[cle] or {}
    return LCM.db.raccourcis[cle]
end

-- Une liste redevenue vide s'efface, et la table avec elle.
local function Nettoyer(entity)
    local cle = Cle(entity)
    local t = LCM.db and LCM.db.raccourcis
    if not (cle and t) then return end
    if t[cle] and #t[cle] == 0 then t[cle] = nil end
    if not next(t) then LCM.db.raccourcis = nil end
end

-- Le genre et le reste d'une reference, ou nil si elle est illisible.
function Raccourcis.Lire(ref)
    local genre, reste = tostring(ref or ""):match("^([%a_]+):(.+)$")
    if not (genre and GENRES[genre]) then return nil end
    return genre, reste
end

-- `max` : ce que l'ecran sait montrer (il le dit, le registre l'applique).
function Raccourcis.Ajouter(entity, ref, max)
    if not Cle(entity) then return false, "aucun personnage." end
    if not Raccourcis.Lire(ref) then return false, "raccourci illisible : " .. tostring(ref) end
    local actuels = Raccourcis.Liste(entity)
    for _, r in ipairs(actuels) do
        if r == ref then return false, "c'est déjà dans tes raccourcis." end
    end
    if max and #actuels >= max then
        return false, string.format("tes raccourcis sont pleins (%d) : retires-en un d'abord.", max)
    end
    local liste = ListePourEcrire(entity)
    liste[#liste + 1] = ref
    return true
end

function Raccourcis.Retirer(entity, index)
    local liste = Raccourcis.Liste(entity)
    index = tonumber(index)
    if not (index and liste[index]) then return false, "ce raccourci n'existe pas." end
    table.remove(ListePourEcrire(entity), index)
    Nettoyer(entity)
    return true
end

-- Deplace d'un cran (`sens` -1 vers la gauche, +1 vers la droite).
function Raccourcis.Deplacer(entity, index, sens)
    local liste = Raccourcis.Liste(entity)
    index, sens = tonumber(index), tonumber(sens)
    local cible = index and sens and index + sens
    if not (index and liste[index] and cible and liste[cible]) then return false, "il ne peut pas aller plus loin." end
    liste = ListePourEcrire(entity)
    liste[index], liste[cible] = liste[cible], liste[index]
    return true
end
