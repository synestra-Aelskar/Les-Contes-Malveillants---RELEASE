-- Metiers : les 31 metiers du template (compendium « Liste metiers ») et
-- l'experience qu'un personnage accumule dans chacun.
--
-- Un metier progresse par couleurs, cinq niveaux par couleur (table
-- « XP METIER » dans Equilibrage.metiers.paliers). La table est INCREMENTALE :
-- chaque ligne demande son XP pour achever le niveau courant. Le dernier cout
-- est donc lui aussi consomme avant que le metier soit entierement maitrise.
-- Le bonus de jet reste le rang de COULEUR, pas le rang global sur 30 niveaux.
--
-- Cote entite, seulement l'XP gagnee : entity.metiers = { [id] = xp }. Un
-- metier a zero ne laisse rien dans la sauvegarde.

local _, LCM = ...

local Metiers = { list = {}, byId = {} }
LCM.Metiers = Metiers

local function Erreur(message) error("LCM/Metiers : " .. tostring(message), 0) end

function Metiers.Add(definition)
    local id = tostring(definition and definition.id or "")
    if id == "" then Erreur("metier sans identifiant") end
    if Metiers.byId[id] then Erreur("metier en double : " .. id) end
    local metier = {
        id = id,
        label = tostring(definition.label or id),
        description = tostring(definition.description or ""),
        icone = LCM.Icone(definition.icone),
    }
    Metiers.byId[id] = metier
    Metiers.list[#Metiers.list + 1] = metier
    return metier
end

function Metiers.Get(id) return Metiers.byId[tostring(id or "")] end

-- Les categories de la fenetre (Data/Metiers.lua, Metiers.CATEGORIES), avec
-- leurs metiers resolus et tries par nom, accents ignores (« Éclaireur »
-- entre « Dresseur » et « Érudit »). Un metier range nulle part va dans
-- « À classer » : il ne disparait jamais de la fenetre.
local SANS_ACCENT = { ["É"] = "E", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["â"] = "a", ["à"] = "a",
    ["ç"] = "c", ["î"] = "i", ["ô"] = "o", ["û"] = "u", ["ù"] = "u" }
local function Cle(texte)
    texte = tostring(texte or "")
    for avec, sans in pairs(SANS_ACCENT) do texte = texte:gsub(avec, sans) end
    return texte:lower()
end

function Metiers.Categories()
    local out, ranges = {}, {}
    for _, categorie in ipairs(Metiers.CATEGORIES or {}) do
        local liste = {}
        for _, id in ipairs(categorie.metiers or {}) do
            local metier = Metiers.byId[id]
            if metier then
                liste[#liste + 1] = metier
                ranges[id] = true
            end
        end
        table.sort(liste, function(a, b) return Cle(a.label) < Cle(b.label) end)
        out[#out + 1] = { id = categorie.id, label = categorie.label, metiers = liste }
    end
    local reste = {}
    for _, metier in ipairs(Metiers.list) do
        if not ranges[metier.id] then reste[#reste + 1] = metier end
    end
    if #reste > 0 then
        table.sort(reste, function(a, b) return Cle(a.label) < Cle(b.label) end)
        out[#out + 1] = { id = "a_classer", label = "À classer", metiers = reste }
    end
    return out
end

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
--
-- Le seuil `cumul` de chaque palier se CALCULE : c'est la somme des `xp`
-- jusqu'a lui. Il etait ecrit a la main a cote de chaque cout, et changer un
-- cout en seance sans retoucher les trente seuils qui suivent aurait casse
-- la progression (le MJ, 2 novembre 2026). Recalcule a chaque lecture : trente
-- additions, et jamais de decalage, meme apres un reglage recu du reseau.
local function Paliers()
    local paliers = LCM.Equilibrage and LCM.Equilibrage.metiers and LCM.Equilibrage.metiers.paliers or {}
    local total = 0
    for _, palier in ipairs(paliers) do
        total = total + math.max(0, math.floor(tonumber(palier.xp) or 0))
        palier.cumul = total
        -- Le nom et la teinte de la couleur viennent de l'ECHELLE (Nommages) :
        -- renommer « Rose » fait d'un metier « Novice 1 » (le MJ, 2 novembre
        -- 2026). Sans palier a ce rang, la table garde les siens.
        local echelon = LCM.Nommages and LCM.Nommages.Get(palier.rangCouleur)
        if echelon then palier.nom, palier.couleur = echelon.nom, echelon.couleur end
    end
    return paliers
end
Metiers.Paliers = Paliers

function Metiers.XP(entity, id)
    local stock = type(entity) == "table" and entity.metiers
    return type(stock) == "table" and math.max(0, math.floor(tonumber(stock[tostring(id)]) or 0)) or 0
end

-- L'XP totale minimale qui correspond a un niveau global (1 a 30). Sert
-- notamment a convertir les quatre points de creation en vrais niveaux de
-- metier, sans dupliquer le bareme dans le createur.
function Metiers.XPPourNiveau(niveau)
    niveau = math.max(0, math.floor(tonumber(niveau) or 0))
    local palier = Paliers()[niveau]
    return palier and math.max(0, math.floor(tonumber(palier.cumul) or 0)) or 0
end

-- Le dernier rang du bareme (Violet 5, le trentieme). C'est la seule borne
-- des metiers d'un PNJ : au-dela, le rang n'existe pas et XPPourNiveau le
-- rendrait a zero — le niveau serait perdu sans un mot.
function Metiers.RangMax()
    return #Paliers()
end

-- Le niveau acquis : { rang, nom, niveau, libelle, rangCouleur,
-- xpDansPalier, xpPalier, xpRestante, max }.
function Metiers.Palier(entity, id)
    local paliers = Paliers()
    local xp = Metiers.XP(entity, id)
    local rang = 0
    for index, niveau in ipairs(paliers) do
        if xp >= math.max(0, math.floor(tonumber(niveau.cumul) or 0)) then rang = index
        else break end
    end

    -- Niveau zero : le metier n'est pas appris. La barre vise Rose 1, mais le
    -- libelle et le bonus restent bien a zero.
    if rang == 0 then
        local suivant = paliers[1] or { xp = 0 }
        local cout = math.max(0, math.floor(tonumber(suivant.xp) or 0))
        return {
            rang = 0, nom = "Non appris", niveau = 0, libelle = "Niveau 0",
            rangCouleur = 0, couleur = { 0.45, 0.45, 0.45 },
            xpDansPalier = xp, xpPalier = cout,
            xpRestante = math.max(0, cout - xp), max = false,
        }
    end

    local palier = paliers[rang] or { nom = "?", niveau = 0, xp = 0 }
    local niveau = math.max(0, math.floor(tonumber(palier.niveau) or 0))
    local libelle = niveau > 0 and string.format("%s %d", palier.nom, niveau) or palier.nom
    local maitrise = rang >= #paliers
    local suivant = paliers[rang + 1]
    local debut = math.max(0, math.floor(tonumber(palier.cumul) or 0))
    local cout = suivant and math.max(0, math.floor(tonumber(suivant.xp) or 0)) or 0
    local dans = math.max(0, xp - debut)
    return {
        rang = rang, nom = palier.nom, niveau = niveau, libelle = libelle,
        rangCouleur = math.max(1, math.floor(tonumber(palier.rangCouleur) or rang)),
        couleur = palier.couleur,
        xpDansPalier = maitrise and 1 or dans, xpPalier = maitrise and 1 or cout,
        xpRestante = maitrise and 0 or math.max(0, cout - dans), max = maitrise,
    }
end

-- Bonus de jet d'un metier (Necronicon : GetProfessionRollBonus).
function Metiers.Bonus(entity, id)
    local appris = Metiers.Palier(entity, id).rangCouleur
    local equipement = LCM.Effets and LCM.Effets.Bonus(entity, "metier:" .. tostring(id)) or 0
    return appris + equipement
end

-- Ajoute (ou retire) de l'XP. Ne descend pas sous zero ; efface ce qui
-- revient a zero.
function Metiers.Gagner(entity, id, montant)
    if type(entity) ~= "table" or not Metiers.Get(id) then return false end
    local xp = math.max(0, Metiers.XP(entity, id) + math.floor(tonumber(montant) or 0))
    if xp == 0 then
        if type(entity.metiers) == "table" then
            entity.metiers[tostring(id)] = nil
            if next(entity.metiers) == nil then entity.metiers = nil end
        end
    else
        entity.metiers = type(entity.metiers) == "table" and entity.metiers or {}
        entity.metiers[tostring(id)] = xp
    end
    return true
end

-- ===== Donner de l'XP de metier, depuis le MJ ==============================
-- Le panneau « Attribuer de l'expérience » donne de l'XP de personnage OU de
-- metier (le MJ, 2 novembre 2026), en XP ou en NIVEAUX. Un niveau ne coute
-- pas pareil a chacun : c'est donc la fiche qui le recoit qui le convertit,
-- sur son XP du moment, plutot que le MJ sur une copie peut-etre en retard.

-- Rend { avant, apres (paliers), gagne (XP) }, ou nil et la raison.
function Metiers.Donner(entity, id, montant, niveaux)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    if not Metiers.Get(id) then return nil, "métier inconnu." end
    montant = math.floor(tonumber(montant) or 0)
    niveaux = math.floor(tonumber(niveaux) or 0)
    local avant = Metiers.Palier(entity, id)
    if niveaux > 0 then
        if avant.max then return nil, "ce métier est déjà maîtrisé." end
        -- Monter de N niveaux, c'est atteindre le debut du palier vise : l'XP
        -- deja gagnee dans le palier en cours compte.
        local vise = math.min(Metiers.RangMax(), avant.rang + niveaux)
        montant = Metiers.XPPourNiveau(vise) - Metiers.XP(entity, id)
    end
    if montant <= 0 then return nil, "il faut un montant positif." end
    Metiers.Gagner(entity, id, montant)
    return { avant = avant, apres = Metiers.Palier(entity, id), gagne = montant }
end

local SUJET = "xpm"

function Metiers.Envoyer(joueur, id, montant, niveaux, raison)
    joueur = tostring(joueur or "")
    montant = math.floor(tonumber(montant) or 0)
    niveaux = math.floor(tonumber(niveaux) or 0)
    if joueur == "" then return false, "a qui ?" end
    if not Metiers.Get(id) then return false, "métier inconnu." end
    if montant <= 0 and niveaux <= 0 then return false, "il faut un montant positif." end
    if not LCM.IsMaster() then return false, "seul le maître du jeu donne de l'expérience." end
    LCM.Reseau.Envoyer(SUJET, { i = tostring(id), m = montant > 0 and montant or nil,
        n = niveaux > 0 and niveaux or nil, r = raison }, "WHISPER", joueur)
    return true
end

-- Ce qu'on dit au joueur : le gain, et le palier franchi s'il y en a un.
function Metiers.Annoncer(id, resultat, expediteur, raison)
    local metier = Metiers.Get(id)
    if not (metier and resultat) then return end
    local pourquoi = tostring(raison or "")
    LCM.Ok(string.format("+%d XP de %s%s%s.", resultat.gagne, metier.label,
        expediteur and (" de " .. tostring(expediteur)) or "",
        pourquoi ~= "" and (" — " .. pourquoi) or ""))
    if resultat.apres.rang > resultat.avant.rang then
        LCM.Ok(string.format("Félicitations ! Le métier de %s passe : %s.", metier.label,
            resultat.apres.libelle))
    end
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(SUJET, function(expediteur, donnees)
        -- Meme regle que l'XP de personnage (Core/Experience.lua) : du groupe
        -- seulement, et l'on dit QUI a donne.
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local moi = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        if not moi then return end
        local resultat, raison = Metiers.Donner(moi, donnees.i, donnees.m, donnees.n)
        if not resultat then
            LCM.Debug(string.format("XP de metier refusee (%s) : %s", tostring(donnees.i), tostring(raison)))
            return
        end
        Metiers.Annoncer(donnees.i, resultat, expediteur, donnees.r)
        local fenetre = LCM.UI and LCM.UI.Metiers and LCM.UI.Metiers.frame
        if fenetre and fenetre:IsShown() then fenetre:Afficher() end
    end)
end)
