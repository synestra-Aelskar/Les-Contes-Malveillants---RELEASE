-- L'experience, et la montee de niveau qu'elle amene.
--
-- Le niveau est fixe a 5 a la creation, et seul le compagnon MJ ouvre la case.
-- Monter se gagne en jeu : c'est le MJ qui donne l'experience, a la fin d'une
-- scene, et le palier se franchit tout seul quand le total y arrive.
--
-- CE QUI VIENT DU TEMPLATE, ET CE QUI N'EN VIENT PAS
--
-- Le template Necronicon n'a PAS de table d'experience de personnage. Il n'a
-- que celle des metiers (« XP METIER », `Equilibrage.metiers.paliers`), qui
-- fait progresser un metier, pas un niveau. La table des paliers de niveau est
-- donc la seule chose ici qu'on ne reprend de nulle part : elle est declaree
-- dans `Data/Equilibrage.lua` (`E.experience`), marquee comme a valider, et
-- se change sans toucher a ce fichier.
--
-- L'experience ne se retire pas. Un MJ peut se tromper de montant, pas defaire
-- une scene : s'il donne trop, il donne moins la prochaine fois.

local _, LCM = ...

local Experience = {}
LCM.Experience = Experience

local function Eq() return LCM.Equilibrage.experience end

-- L'XP vit sur l'entite, a cote de ses valeurs : c'est un acquis du
-- personnage, pas un champ de la feuille (la feuille dit ce qu'on est, pas ce
-- qu'on a traverse pour y arriver).
function Experience.Total(entity)
    return math.max(0, math.floor(tonumber(entity and entity.xp) or 0))
end

-- Le niveau qu'un total d'XP donne droit. Les paliers sont CUMULATIFS : le
-- palier n dit l'XP totale pour atteindre le niveau n.
function Experience.NiveauPour(xp)
    xp = math.max(0, math.floor(tonumber(xp) or 0))
    local niveau = Eq().niveauDepart
    for _, palier in ipairs(Eq().paliers) do
        if xp >= palier.xp then niveau = palier.niveau end
    end
    return niveau
end

function Experience.NiveauFiche(entity)
    return math.max(1, math.floor(tonumber(LCM.Entities.Get_Value(entity, "niveau"))
        or Eq().niveauDepart))
end

-- L'XP donne le DROIT de monter ; le niveau de la fiche ne bouge qu'apres
-- repartition et validation. La difference est le nombre de passages que le
-- joueur doit encore traiter, un par un.
function Experience.NiveauxEnAttente(entity)
    if type(entity) ~= "table" then return 0 end
    return math.max(0, Experience.NiveauPour(Experience.Total(entity)) - Experience.NiveauFiche(entity))
end

function Experience.PeutMonter(entity)
    return Experience.NiveauxEnAttente(entity) > 0
end

-- Ou l'on en est : le niveau courant, et ce qu'il faut pour le suivant.
-- `reste` vaut nil au dernier palier connu — il n'y a plus rien a viser.
function Experience.Progression(entity)
    local xp = Experience.Total(entity)
    local niveau = Experience.NiveauPour(xp)
    local prochain
    for _, palier in ipairs(Eq().paliers) do
        if palier.xp > xp then prochain = palier break end
    end
    return {
        xp = xp, niveau = niveau,
        prochainNiveau = prochain and prochain.niveau or nil,
        prochainXp = prochain and prochain.xp or nil,
        reste = prochain and (prochain.xp - xp) or nil,
    }
end

-- Donne l'experience et fait monter le niveau si le palier est franchi.
-- Retourne l'ancien et le nouveau niveau : l'appelant sait ainsi s'il doit
-- annoncer quelque chose.
function Experience.Donner(entity, montant, raison)
    montant = math.floor(tonumber(montant) or 0)
    if not entity then return nil, "aucun personnage." end
    if montant <= 0 then return nil, "il faut un montant positif." end

    local avant = Experience.NiveauPour(Experience.Total(entity))
    entity.xp = Experience.Total(entity) + montant
    local apres = Experience.NiveauPour(entity.xp)

    if Experience.onGain then Experience.onGain(entity, montant, avant, apres, raison) end
    if LCM.UI and LCM.UI.Radial and LCM.UI.Radial.Rafraichir then LCM.UI.Radial.Rafraichir() end
    return { avant = avant, apres = apres, monte = apres > avant, xp = entity.xp,
        enAttente = Experience.NiveauxEnAttente(entity) }
end

-- ===== Entre le MJ et le joueur ===========================================
-- Le MJ donne, le joueur recoit. L'inverse n'existe pas : personne ne
-- s'attribue d'experience, c'est tout l'interet de la faire passer par le MJ.

local SUJET = "xp"

function Experience.Envoyer(joueur, montant, raison)
    joueur = tostring(joueur or "")
    montant = math.floor(tonumber(montant) or 0)
    if joueur == "" then return false, "a qui ?" end
    if montant <= 0 then return false, "il faut un montant positif." end
    if not LCM.IsMaster() then return false, "seul le maître du jeu donne de l'expérience." end
    LCM.Reseau.Envoyer(SUJET, { m = montant, r = raison }, "WHISPER", joueur)
    return true
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(SUJET, function(expediteur, donnees)
        -- Meme regle que la consultation de fiche : l'expediteur doit etre dans
        -- le groupe. On ne peut pas verifier qu'il est MJ — un client modifie
        -- dirait qu'il l'est — alors on dit QUI a donne, et la triche se voit.
        if not LCM.Reseau.DansLeGroupe(expediteur) then
            LCM.Debug(string.format("experience refusee de %s : hors du groupe.", tostring(expediteur)))
            return
        end
        -- Un gain adresse au joueur appartient toujours a son personnage,
        -- meme si une incarnation ou une autre entite est active a l'ecran.
        local moi = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        if not moi then return end
        local resultat = Experience.Donner(moi, donnees.m, donnees.r)
        if not resultat then return end
        -- L'interface distingue un vrai gain RECU du reseau d'un ajustement
        -- local de l'entite. Le bandeau et son son ne doivent accompagner que
        -- le premier cas.
        if Experience.onReception then
            Experience.onReception(moi, math.floor(tonumber(donnees.m) or 0), donnees.r,
                expediteur, resultat)
        end
        local pourquoi = tostring(donnees.r or "")
        LCM.Ok(string.format("+%d XP de %s%s.", math.floor(tonumber(donnees.m) or 0),
            tostring(expediteur), pourquoi ~= "" and (" — " .. pourquoi) or ""))
        if resultat.monte then
            LCM.Ok(string.format("|cffffd36b%d niveau%s en attente !|r Ouvre le menu Personnage pour répartir tes points.",
                resultat.enAttente, resultat.enAttente > 1 and "x" or ""))
        end
    end)
end)

-- ===== Regain des ressources ==============================================
-- Le panneau MJ choisit plusieurs personnages, les ressources concernees et
-- une seule operation : remplir, vider, ou rendre un nombre precis de points.
-- Le nombre precis peut etre NEGATIF (le MJ, 23 octobre 2026) : on retire
-- des PA comme on en donne. La jauge reste bornee entre 0 et son maximum.
-- Le client joueur ne possede aucune commande d'envoi pour ce protocole.

local Regain = {}
LCM.Regain = Regain

local RESSOURCES = {
    { cle = "fatigue", paquet = "f", label = "Fatigue", phrase = "fatigue" },
    { cle = "pa",      paquet = "p", label = "PA",      phrase = "PA" },
    { cle = "armure",  paquet = "b", label = "Bouclier", phrase = "bouclier" },
    { cle = "pv_tete",     paquet = "t", label = "PV (Tête)",     phrase = "PV de la tête",     partie = "tete" },
    { cle = "pv_buste",    paquet = "o", label = "PV (Torse)",    phrase = "PV du torse",       partie = "buste" },
    { cle = "pv_bras",     paquet = "r", label = "PV (Bras)",     phrase = "PV des bras",       partie = "bras" },
    { cle = "pv_jambe",    paquet = "j", label = "PV (Jambes)",  phrase = "PV des jambes",     partie = "jambe" },
    { cle = "pv_internes", paquet = "i", label = "PV (Internes)", phrase = "PV des internes",   partie = "internes" },
}
Regain.RESSOURCES = RESSOURCES

local PAR_CLE = {}
for _, def in ipairs(RESSOURCES) do PAR_CLE[def.cle] = def end

local function SelectionDepuisPaquet(donnees)
    local selection = {}
    for _, def in ipairs(RESSOURCES) do
        selection[def.cle] = tonumber(donnees and donnees[def.paquet]) == 1
    end
    return selection
end

-- Etat agrege d'une ressource. Une categorie corporelle peut contenir
-- plusieurs zones (deux bras, plusieurs tetes...) : le panneau les regroupe
-- proprement, et l'operation s'applique a chacune.
function Regain.Etat(entity, cle)
    local def = PAR_CLE[tostring(cle or "")]
    if not def or type(entity) ~= "table" then return nil end
    if not def.partie then return LCM.Entities.Gauge(entity, def.cle) end
    local courant, maximum, parties = 0, 0, {}
    for _, partie in ipairs(LCM.Body.State(entity)) do
        if partie.part.category == def.partie then
            courant = courant + partie.current
            maximum = maximum + partie.max
            parties[#parties + 1] = partie
        end
    end
    if #parties == 0 then return nil end
    return { current = courant, max = maximum, parties = parties }
end

function Regain.Appliquer(entity, selection, mode, montant)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    selection = type(selection) == "table" and selection or {}
    mode = tostring(mode or "")
    montant = math.floor(tonumber(montant) or 0)
    if mode ~= "max" and mode ~= "min" and mode ~= "exact" then return nil, "choisis Max, Min ou Chiffre précis." end
    if mode == "exact" and montant == 0 then return nil, "indique un chiffre, positif ou négatif." end

    local resultat = { mode = mode, ressources = {} }
    for _, def in ipairs(RESSOURCES) do
        if selection[def.cle] then
            local jauge = Regain.Etat(entity, def.cle)
            if jauge then
                if def.partie then
                    for _, partie in ipairs(jauge.parties) do
                        local cible = mode == "max" and partie.max
                            or (mode == "min" and 0
                                or math.max(0, math.min(partie.max, partie.current + montant)))
                        LCM.Body.SetCurrent(entity, partie.id, cible)
                    end
                else
                    local cible = mode == "max" and jauge.max
                        or (mode == "min" and 0
                            or math.max(0, math.min(jauge.max, jauge.current + montant)))
                    LCM.Entities.SetGauge(entity, def.cle, cible)
                end
                local apres = Regain.Etat(entity, def.cle)
                resultat.ressources[#resultat.ressources + 1] = {
                    id = def.cle, label = def.label, phrase = def.phrase,
                    avant = jauge.current, apres = apres.current, max = apres.max,
                    gain = apres.current - jauge.current,
                }
            end
        end
    end
    if #resultat.ressources == 0 then return nil, "coche au moins une ressource." end
    return resultat
end

function Regain.Texte(resultat)
    if type(resultat) ~= "table" then return "" end
    local morceaux = {}
    if resultat.mode == "exact" then
        -- Ce qui monte et ce qui descend se disent a part : « Vous gagnez -3
        -- PA » ne se lit pas.
        local gagnes, perdus = {}, {}
        for _, r in ipairs(resultat.ressources or {}) do
            local gain = tonumber(r.gain) or 0
            if gain < 0 then perdus[#perdus + 1] = string.format("%d %s", -gain, r.label)
            else gagnes[#gagnes + 1] = string.format("%d %s", gain, r.label) end
        end
        local phrases = {}
        if #gagnes > 0 then phrases[#phrases + 1] = "Vous gagnez " .. table.concat(gagnes, " - ") .. "." end
        if #perdus > 0 then phrases[#phrases + 1] = "Vous perdez " .. table.concat(perdus, " - ") .. "." end
        return table.concat(phrases, " ")
    end
    for _, r in ipairs(resultat.ressources or {}) do morceaux[#morceaux + 1] = r.phrase end
    if resultat.mode == "max" then
        return "Vous regagnez tous vos points de " .. table.concat(morceaux, " / ") .. "."
    end
    return "Vous perdez la totalité de vos points de " .. table.concat(morceaux, " / ") .. "."
end

local SUJET_REGAIN = "regain"

function Regain.Envoyer(joueur, selection, mode, montant)
    joueur = tostring(joueur or "")
    if joueur == "" then return false, "a qui ?" end
    if not LCM.IsMaster() then return false, "seul le maître du jeu utilise le regain." end
    local paquet = { mode = mode, m = math.floor(tonumber(montant) or 0) }
    local nombre = 0
    for _, def in ipairs(RESSOURCES) do
        if selection and selection[def.cle] then paquet[def.paquet] = 1 nombre = nombre + 1 end
    end
    if nombre == 0 then return false, "coche au moins une ressource." end
    if mode ~= "max" and mode ~= "min" and mode ~= "exact" then return false, "choisis Max, Min ou Chiffre précis." end
    if mode == "exact" and paquet.m == 0 then return false, "indique un chiffre, positif ou négatif." end
    LCM.Reseau.Envoyer(SUJET_REGAIN, paquet, "WHISPER", joueur)
    return true
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(SUJET_REGAIN, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then
            LCM.Debug(string.format("regain refusé de %s : hors du groupe.", tostring(expediteur)))
            return
        end
        local moi = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        if not moi then return end
        local resultat = Regain.Appliquer(moi, SelectionDepuisPaquet(donnees), donnees.mode, donnees.m)
        if not resultat then return end
        if Regain.onReception then Regain.onReception(moi, resultat, expediteur) end
        LCM.Ok(Regain.Texte(resultat) .. " — " .. tostring(expediteur))
    end)
end)
