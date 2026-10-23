-- Consommer un consommable (le MJ, 23 octobre 2026).
--
-- Un consommable se forge par CRITERES : chaque jauge du personnage (PV,
-- fatigue, boucliers, PA, etat d'armure, esprit, ame) est un critere que le
-- jeu d'equilibrage dose comme une statistique, avec son cout. Une potion de
-- soin a +5 en « PV », une potion de vigueur +5 en « Fatigue ». Les criteres
-- vivent dans le `bonus` de l'entree sous la cle « rend:<critere> », comme les
-- metiers d'un outil sous « metier:<id » : la forge et son bareme n'ont rien a
-- apprendre.
--
-- Le reste du bonus (les statistiques : +5 resistance au vent) n'est porte que
-- par l'ETAT que le consommable pose, s'il en pose un (case « Etat » de la
-- forge) : un etat temporaire (Core/EtatsTemporaires.lua) avec son type
-- (etat, maladie, intangible), sa description ecrite par le MJ, et sa duree en
-- rounds — vide, il dure jusqu'a ce qu'on le retire. Sans etat, un consommable
-- ne donne que des jauges : un bonus de statistique sans duree serait donne a
-- vie (decision du MJ).
--
-- Les PV sont repartis par zone : celui qui consomme choisit ou vont ses
-- points (« Vous disposez de 5 PV a repartir »). Les autres jauges sont
-- uniques et se remplissent d'un coup ; l'etat d'armure se repartit seul sur
-- les pieces portees (Objets.PorterProtection).
--
-- On consomme pour soi, ou on administre a un allie : la demande voyage, mais
-- seul l'IDENTIFIANT du consommable part. La cible lit ses effets dans son
-- propre compendium, accepte ou refuse, repartit ses PV, et l'exemplaire ne
-- quitte le sac de celui qui donne qu'une fois l'effet applique.

local _, LCM = ...

local Consommation = {}
LCM.Consommation = Consommation

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Les jauges d'un personnage. `zones` : la jauge se repartit par zone du
-- corps, au choix de celui qui consomme.
Consommation.CRITERES = {
    { id = "pv",               label = "PV",             zones = true },
    { id = "fatigue",          label = "Fatigue (PF)" },
    { id = "armure",           label = "Boucliers" },
    { id = "pa",               label = "PA" },
    { id = "armure_portee",    label = "État d'armure" },
    { id = "existence_esprit", label = "Esprit" },
    { id = "existence_ame",    label = "Âme" },
}
local PAR_ID = {}
for _, c in ipairs(Consommation.CRITERES) do PAR_ID[c.id] = c end

Consommation.PREFIXE = "rend:"
function Consommation.Cle(critereId) return Consommation.PREFIXE .. critereId end
function Consommation.Critere(cle)
    local id = tostring(cle or ""):match("^rend:(.+)$")
    return id and PAR_ID[id] or nil
end

-- ===== Ce qu'un consommable fait ============================================

-- { jauges = { { critere, montant } }, statistiques = { [champ] = n }, etat }
-- Lecture seule : rien n'est cree dans l'element.
function Consommation.Effets(element)
    local out = { jauges = {}, statistiques = {}, etat = element and element.etatApplique }
    for cle, montant in pairs(element and element.bonus or {}) do
        local critere = Consommation.Critere(cle)
        if critere then
            out.jauges[#out.jauges + 1] = { critere = critere, montant = montant }
        else
            out.statistiques[cle] = montant
        end
    end
    -- Dans l'ordre des criteres : le message se lit toujours pareil.
    table.sort(out.jauges, function(a, b)
        local ra, rb = 0, 0
        for i, c in ipairs(Consommation.CRITERES) do
            if c == a.critere then ra = i end
            if c == b.critere then rb = i end
        end
        return ra < rb
    end)
    return out
end

-- Ce qu'il fera, en une ligne : « +5 PV, +3 Fatigue (PF), état « Repus » ».
-- C'est ce que lit l'allie avant d'accepter.
function Consommation.Resume(element)
    local effets = Consommation.Effets(element)
    local morceaux = {}
    for _, j in ipairs(effets.jauges) do
        morceaux[#morceaux + 1] = string.format("%s%s %s", j.montant >= 0 and "+" or "", tostring(j.montant),
            j.critere.label)
    end
    if type(effets.etat) == "table" then
        morceaux[#morceaux + 1] = "état « " .. (effets.etat.nom or tostring(element.label)) .. " »"
    end
    return #morceaux > 0 and table.concat(morceaux, ", ") or "aucun effet"
end

-- Les PV a repartir (positif : a soigner, negatif : a perdre), ou 0.
function Consommation.PVARepartir(element)
    return tonumber(element and element.bonus and element.bonus[Consommation.Cle("pv")]) or 0
end

-- Ce que chaque zone peut encore recevoir dans le sens du montant : un soin
-- ne depasse pas le maximum, une perte ne descend pas sous zero.
function Consommation.Zones(entity, montant)
    local out = {}
    for _, z in ipairs(LCM.Body.State(entity)) do
        out[#out + 1] = { id = z.id, label = z.label, courant = z.current, max = z.max,
            place = montant >= 0 and (z.max - z.current) or z.current }
    end
    return out
end

-- La repartition proposee est-elle juste ? Tout doit etre place, sauf ce
-- qu'aucune zone ne peut plus recevoir — on ne force pas a soigner un
-- membre deja plein, on ne perd pas un soin qu'on pouvait placer.
function Consommation.VerifierRepartition(entity, montant, repartition)
    local total = math.abs(montant)
    local zones = Consommation.Zones(entity, montant)
    local place, pose = 0, 0
    local parId = {}
    for _, z in ipairs(zones) do parId[z.id] = z place = place + z.place end
    for id, n in pairs(repartition or {}) do
        n = tonumber(n)
        local z = parId[id]
        if not z then return false, "zone inconnue : " .. tostring(id) end
        if not n or n < 0 or n ~= math.floor(n) then return false, "répartition illisible." end
        if n > z.place then
            return false, string.format("%s ne peut recevoir que %d.", z.label, z.place)
        end
        pose = pose + n
    end
    if pose > total then return false, string.format("tu n'as que %d PV à répartir.", total) end
    if pose < math.min(total, place) then
        return false, string.format("il reste %d PV à répartir.", math.min(total, place) - pose)
    end
    return true
end

local function Jauge(entity, critere, montant)
    local j = LCM.Entities.Gauge(entity, critere.id)
    if not j then return nil end
    LCM.Entities.SetGauge(entity, critere.id, j.current + montant)
    local apres = LCM.Entities.Gauge(entity, critere.id)
    return (apres and apres.current or j.current) - j.current
end

-- Applique les effets d'un consommable a `entity`. `repartition` :
-- { [zone] = n }, obligatoire s'il y a des PV. Rend le bilan, ou nil et la
-- raison — et dans ce cas rien n'a ete applique.
function Consommation.Appliquer(entity, element, repartition)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    if type(element) ~= "table" then return nil, "consommable inconnu." end
    local pv = Consommation.PVARepartir(element)
    if pv ~= 0 then
        local ok, raison = Consommation.VerifierRepartition(entity, pv, repartition)
        if not ok then return nil, raison end
    end

    local bilan = { nom = element.label, jauges = {}, etat = nil }
    local effets = Consommation.Effets(element)
    for _, j in ipairs(effets.jauges) do
        if j.critere.zones then
            local sens = pv >= 0 and 1 or -1
            local total = 0
            for _, z in ipairs(LCM.Body.State(entity)) do
                local n = tonumber(repartition and repartition[z.id]) or 0
                if n > 0 then
                    LCM.Body.SetCurrent(entity, z.id, z.current + sens * n)
                    total = total + n
                    bilan.jauges[#bilan.jauges + 1] = { label = j.critere.label .. " (" .. z.label .. ")",
                        gain = sens * n }
                end
            end
            if total == 0 then
                bilan.jauges[#bilan.jauges + 1] = { label = j.critere.label, gain = 0 }
            end
        else
            local gain = Jauge(entity, j.critere, j.montant)
            if gain then bilan.jauges[#bilan.jauges + 1] = { label = j.critere.label, gain = gain } end
        end
    end
    local etat = effets.etat
    if type(etat) == "table" then
        LCM.EtatsTemporaires.Poser(entity, {
            id = "conso:" .. tostring(element.id),
            nom = Texte(etat.nom) ~= "" and Texte(etat.nom) or element.label,
            icone = element.icone, description = etat.description,
            bonus = LCM.Copie(effets.statistiques), rounds = etat.rounds,
            conteneur = etat.conteneur,
        })
        bilan.etat = Texte(etat.nom) ~= "" and Texte(etat.nom) or element.label
    end
    return bilan
end

function Consommation.Texte(bilan)
    if type(bilan) ~= "table" then return "" end
    local morceaux = {}
    for _, j in ipairs(bilan.jauges) do
        morceaux[#morceaux + 1] = string.format("%s%d %s", j.gain >= 0 and "+" or "", j.gain, j.label)
    end
    if bilan.etat then morceaux[#morceaux + 1] = "état « " .. bilan.etat .. " »" end
    if #morceaux == 0 then return string.format("« %s » consommé, sans effet.", tostring(bilan.nom)) end
    return string.format("« %s » : %s.", tostring(bilan.nom), table.concat(morceaux, ", "))
end

-- Ce qu'on peut consommer : un consommable, present dans les sacs.
local function Consommable(entity, ref)
    local element, categorie = LCM.Compendium.Resoudre(ref)
    if not element or not categorie or categorie.famille ~= "consommables" then
        return nil, "ce n'est pas un consommable."
    end
    if not LCM.Inventaire.Chercher(entity, ref) then return nil, "il n'est plus dans tes sacs." end
    return element
end
Consommation.Consommable = Consommable

-- Consommer pour soi : l'effet, puis un exemplaire en moins.
function Consommation.Consommer(entity, ref, repartition)
    local element, raison = Consommable(entity, ref)
    if not element then return nil, raison end
    local bilan, refus = Consommation.Appliquer(entity, element, repartition)
    if not bilan then return nil, refus end
    LCM.Inventaire.Prendre(entity, ref)
    return bilan
end

-- ===== Administrer a un allie ================================================
-- Demande (« conso_dem », { i = id }) -> la cible accepte et applique chez
-- elle -> reponse (« conso_rep », { i = id, o = 1 | 0 }). Ce qui a ete
-- propose et a qui reste ici : une reponse qu'on n'attendait pas ne retire rien.

local SUJET_DEMANDE, SUJET_REPONSE = "conso_dem", "conso_rep"
local attentes = {}
Consommation.attentes = attentes

function Consommation.Administrer(entity, joueur, ref)
    joueur = tostring(joueur or "")
    if joueur == "" then return false, "à qui ?" end
    if not LCM.Reseau.DansLeGroupe(joueur) then return false, "ce joueur n'est pas dans le groupe." end
    local element, raison = Consommable(entity, ref)
    if not element then return false, raison end
    local ok, erreur = LCM.Reseau.Envoyer(SUJET_DEMANDE, { i = element.id }, "WHISPER", joueur)
    if ok == false then return false, erreur or "la demande n'a pas pu partir." end
    attentes[joueur .. "/" .. element.id] = { entity = entity, ref = ref, nom = element.label }
    return true
end

-- La cible repond : `accepte` et, le cas echeant, ce qui a ete applique.
function Consommation.Repondre(expediteur, id, accepte)
    LCM.Reseau.Envoyer(SUJET_REPONSE, { i = id, o = accepte and 1 or 0 }, "WHISPER", expediteur)
end

-- Ce que l'interface fait d'une demande recue : demander a la cible. Sans
-- interface (le banc), personne ne decide et rien ne s'applique.
Consommation.SurDemande = nil

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(SUJET_DEMANDE, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local id = Texte(donnees and donnees.i)
        local element, categorie = LCM.Compendium.Resoudre("consommables/" .. id)
        if not element or not categorie or categorie.famille ~= "consommables" then
            -- On ne connait pas ce consommable (base pas encore recue) : on le
            -- dit, et rien ne quitte le sac de celui qui donne.
            Consommation.Repondre(expediteur, id, false)
            return
        end
        if Consommation.SurDemande then
            Consommation.SurDemande(expediteur, element)
        else
            Consommation.Repondre(expediteur, id, false)
        end
    end)
    LCM.Reseau.Ecouter(SUJET_REPONSE, function(expediteur, donnees)
        local id = Texte(donnees and donnees.i)
        local cle = tostring(expediteur) .. "/" .. id
        local attente = attentes[cle]
        if not attente then return end
        attentes[cle] = nil
        if tonumber(donnees.o) == 1 then
            LCM.Inventaire.Prendre(attente.entity, attente.ref)
            LCM.Ok(string.format("%s a reçu « %s ».", tostring(expediteur), tostring(attente.nom)))
        else
            LCM.Info(string.format("%s n'a pas pris « %s ».", tostring(expediteur), tostring(attente.nom)))
        end
        if Consommation.onChange then Consommation.onChange() end
    end)
end)

-- La cible a accepte : elle applique chez elle, puis repond.
function Consommation.Accepter(expediteur, element, repartition)
    local entity = LCM.Entities.Self()
    local bilan, raison = Consommation.Appliquer(entity, element, repartition)
    if not bilan then return nil, raison end
    Consommation.Repondre(expediteur, element.id, true)
    return bilan
end

function Consommation.Refuser(expediteur, element)
    Consommation.Repondre(expediteur, element and element.id, false)
end
