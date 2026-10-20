-- Les influences mentales : contraintes de ciblage, illusions et jets
-- automatiques de libération. Les états eux-mêmes vivent dans
-- EtatsTemporaires ; ce module donne un sens à leurs métadonnées `controle`.

local _, LCM = ...

local Influences = {}
LCM.Influences = Influences

-- Demandes de contrôle mental en attente sur le client du lanceur. Elles ne
-- contiennent qu'un rappel en mémoire : les dépenses et l'envoi de l'état ne
-- sont effectués qu'après la réponse signée par le MJ du combat.
Influences.controlesEnAttente = {}
local sequenceControle = 0

local OFFENSIVES = {
    attaque_simple = true, perce_armure = true, brise_armure = true,
    generation_debuff = true, repulsion = true, attraction = true,
    permutation = true, immobilisation = true, entrave = true,
    intimidation = true, provocation = true, illusion = true, peur = true,
    controle_mental = true,
}
local SUPPORTS = {
    generation_bouclier = true, generation_soin = true,
    generation_buff = true, dissipation = true, levitation = true,
}

local function Court(nom)
    return (tostring(nom or ""):match("^([^-]+)") or tostring(nom or "")):lower()
end

local function Meme(a, b) return Court(a) == Court(b) end

local function CiblesLisibles(joueurs, pnj, soi)
    local noms = {}
    for _, joueur in ipairs(joueurs or {}) do noms[#noms + 1] = tostring(joueur) end
    for _, acteur in ipairs(pnj or {}) do noms[#noms + 1] = tostring(acteur.nom or acteur.id) end
    if soi then noms[#noms + 1] = LCM.Identite.NomEnJeu(LCM.Entities.Personnage()) end
    return table.concat(noms, ", ")
end

local function IdControle()
    sequenceControle = sequenceControle + 1
    local maintenant = GetTime and math.floor(GetTime() * 1000) or sequenceControle
    return table.concat({ Court(LCM.PlayerId()), tostring(maintenant), tostring(sequenceControle) }, ":")
end

-- Soumet la narration au MJ qui dirige le combat. `rappel` n'est appelé
-- qu'une fois ; le moteur d'actions y reprendra la déclaration et débitera
-- alors seulement ses coûts.
function Influences.SoumettreControleMental(paquet, joueurs, pnj, soi, rappel)
    local combat = LCM.Combat.Etat()
    if not combat or not combat.mj or tostring(combat.mj) == "" then
        return rappel(false, nil, "le contrôle mental exige un combat dirigé par un MJ.")
    end
    local id = IdControle()
    local demande = {
        q = id, txt = tostring(paquet.nt or ""), rp = tostring(paquet.rp or paquet.a or "?"),
        c = CiblesLisibles(joueurs, pnj, soi), s = tostring(combat.s or ""),
    }
    Influences.controlesEnAttente[id] = { rappel = rappel, mj = combat.mj }

    local function Expirer()
        local attente = Influences.controlesEnAttente[id]
        if not attente then return end
        Influences.controlesEnAttente[id] = nil
        attente.rappel(false, nil, "validation du contrôle mental expirée (aucune réponse du MJ).")
    end
    if C_Timer and C_Timer.After then C_Timer.After(120, Expirer) end

    if Meme(combat.mj, LCM.PlayerId()) and LCM.IsMaster() then
        if Influences.onValidationControleMental then
            Influences.onValidationControleMental(demande, LCM.PlayerId())
        else
            Influences.controlesEnAttente[id] = nil
            rappel(false, nil, "fenêtre MJ de validation indisponible.")
        end
        return true
    end
    local ok = LCM.Reseau.Envoyer("mental?", demande, "WHISPER", combat.mj, { etale = true })
    if not ok then
        Influences.controlesEnAttente[id] = nil
        rappel(false, nil, "impossible de joindre le MJ pour validation.")
        return false
    end
    LCM.Info("Contrôle mental envoyé au MJ pour relecture. PA et fatigue restent en attente.")
    return true
end

-- Point d'entrée du panneau compagnon MJ.
function Influences.DeciderControleMental(demande, expediteur, accepte, narration)
    if not LCM.IsMaster() or type(demande) ~= "table" or not demande.q then return false end
    local texte = tostring(narration or demande.txt or "")
    if Meme(expediteur, LCM.PlayerId()) then
        local attente = Influences.controlesEnAttente[demande.q]
        if not attente then return false end
        Influences.controlesEnAttente[demande.q] = nil
        attente.rappel(accepte == true, texte, accepte and nil or "contrôle mental refusé par le MJ.")
        return true
    end
    return LCM.Reseau.Envoyer("mental!", { q = demande.q, ok = accepte and 1 or nil, txt = texte },
        "WHISPER", expediteur, { etale = true })
end

local function Etats()
    local personnage = LCM.Entities.Personnage and LCM.Entities.Personnage()
    return personnage, personnage and LCM.EtatsTemporaires.Liste(personnage) or {}
end

local function CleBouton(ctx)
    return tostring(ctx and ctx.resolution and ctx.resolution.bouton or "")
end

local function CiblesContiennent(joueurs, pnj, soi, id)
    local nature, identifiant = tostring(id or ""):match("^([jp]):(.+)$")
    identifiant = identifiant or id
    if nature ~= "p" and soi and Court(identifiant) == Court(LCM.PlayerId()) then return true end
    if nature ~= "p" then
        for _, joueur in ipairs(joueurs or {}) do if Court(joueur) == Court(identifiant) then return true end end
    end
    if nature ~= "j" then
        for _, acteur in ipairs(pnj or {}) do if tostring(acteur.id) == tostring(identifiant) then return true end end
    end
    return false
end

local function CatalogueActeurs()
    local joueurs, pnj = LCM.Actions.Cibles()
    local catalogue = {}
    for _, acteur in ipairs(joueurs) do catalogue["j:" .. tostring(acteur.id)] = { joueur = acteur.id, soi = acteur.soi } end
    for _, acteur in ipairs(pnj) do catalogue["p:" .. tostring(acteur.id)] = { pnj = acteur } end
    return catalogue
end

local function InverserCibles(joueurs, pnj, soi, a, b)
    if not a or not b or a == "" or b == "" then return joueurs, pnj, soi end
    local catalogue = CatalogueActeurs()
    local tokens = {}
    for _, joueur in ipairs(joueurs) do tokens[#tokens + 1] = "j:" .. tostring(joueur) end
    for _, acteur in ipairs(pnj) do tokens[#tokens + 1] = "p:" .. tostring(acteur.id) end
    if soi then tokens[#tokens + 1] = "j:" .. tostring(LCM.PlayerId()) end
    local nouveauxJ, nouveauxP, nouveauS, vus = {}, {}, false, {}
    for _, token in ipairs(tokens) do
        if token == a then token = b elseif token == b then token = a end
        local acteur = catalogue[token]
        if acteur and not vus[token] then
            vus[token] = true
            if acteur.soi then nouveauS = true
            elseif acteur.joueur then nouveauxJ[#nouveauxJ + 1] = acteur.joueur
            elseif acteur.pnj then nouveauxP[#nouveauxP + 1] = acteur.pnj end
        end
    end
    return nouveauxJ, nouveauxP, nouveauS
end

-- Appelé après le choix des cibles, avant toute dépense. Refuser ici laisse
-- donc le composeur intact et ne consomme ni PA ni fatigue.
function Influences.PreparerCibles(ctx, joueurs, pnj, soi)
    joueurs, pnj = joueurs or {}, pnj or {}
    local bouton = CleBouton(ctx)
    local offensif, support = OFFENSIVES[bouton] == true, SUPPORTS[bouton] == true
    local _, etats = Etats()
    for _, etat in ipairs(etats) do
        local c = etat.controle
        if c then
            if c.type == "peur" and offensif then
                return false, "Terrifié : aucune action offensive n'est possible."
            elseif c.type == "intimidation" and offensif
                and CiblesContiennent(joueurs, pnj, soi, c.source) then
                return false, "Intimidé par " .. tostring(c.sourceNom or c.source)
                    .. " : impossible de l'attaquer."
            elseif c.type == "provocation" then
                if support then return false, "Provoqué : les actions de support sont impossibles." end
                local nombre = #joueurs + #pnj + (soi and 1 or 0)
                if nombre > 0 and (nombre ~= 1 or not CiblesContiennent(joueurs, pnj, soi, c.source)) then
                    return false, "Provoqué : seule la personne à l'origine de la provocation peut être ciblée."
                end
            elseif c.type == "illusion" then
                joueurs, pnj, soi = InverserCibles(joueurs, pnj, soi, c.acteurA, c.acteurB)
            end
        end
    end
    return true, nil, joueurs, pnj, soi
end

local LIBERATION = { intimidation = true, provocation = true, peur = true }

function Influences.TenterLiberation(horsCombat)
    local entity, etats = Etats()
    if not entity then return 0 end
    local essais = 0
    for index = #etats, 1, -1 do
        local etat, c = etats[index], etats[index].controle
        local maintenant = GetTime and GetTime() or 0
        local disponible = not horsCombat or maintenant >= (tonumber(c and c.prochainHorsCombat) or 0)
        if c and LIBERATION[c.type] and disponible then
            if horsCombat then c.prochainHorsCombat = maintenant + 20 * 60 end
            c.bonus = (tonumber(c.bonus) or 0) + 1
            local field = LCM.Actions.ChampParLibelle("Esprit", "roll")
            local jet = field and LCM.Roll.Field(entity, field.id)
            local total = (jet and jet.total or 0) + c.bonus
            local seuil = tonumber(c.seuil) or 0
            local texte = string.format("Libération de « %s » : Esprit %d + %d = %d contre %d — %s.",
                tostring(etat.nom), jet and jet.total or 0, c.bonus, total, seuil,
                total > seuil and "réussite" or "échec")
            if horsCombat then LCM.Info(texte) else LCM.Actions.Annoncer(texte) end
            if total > seuil then LCM.EtatsTemporaires.RetirerForce(entity, etat.nom) end
            essais = essais + 1
        end
    end
    return essais
end

local dernierTour
LCM.Combat.Suivre(function(etat)
    if not etat or not LCM.Combat.EstMonTour() then return end
    local cle = table.concat({ tostring(etat.s), tostring(etat.t), tostring(etat.r), tostring(etat.c) }, ":")
    if cle == dernierTour then return end
    dernierTour = cle
    Influences.TenterLiberation(false)
end)

local function HorlogeHorsCombat()
    if not LCM.Combat.Etat() then Influences.TenterLiberation(true) end
    if C_Timer and C_Timer.After then C_Timer.After(20 * 60, HorlogeHorsCombat) end
end

LCM.WhenReady(function()
    if C_Timer and C_Timer.After then C_Timer.After(20 * 60, HorlogeHorsCombat) end
    LCM.Reseau.Ecouter("mental?", function(expediteur, demande)
        local combat = LCM.Combat.Etat()
        if not LCM.IsMaster() or not combat or not Meme(combat.mj, LCM.PlayerId())
            or tostring(demande and demande.s or "") ~= tostring(combat.s or "")
            or not LCM.Reseau.DansLeGroupe(expediteur) then return end
        if Influences.onValidationControleMental then
            Influences.onValidationControleMental(demande, expediteur)
        else
            Influences.DeciderControleMental(demande, expediteur, false, demande and demande.txt)
        end
    end)
    LCM.Reseau.Ecouter("mental!", function(expediteur, reponse)
        local attente = type(reponse) == "table" and Influences.controlesEnAttente[reponse.q]
        if not attente or not Meme(expediteur, attente.mj) then return end
        Influences.controlesEnAttente[reponse.q] = nil
        attente.rappel(reponse.ok == 1, reponse.txt,
            reponse.ok == 1 and nil or "contrôle mental refusé par le MJ.")
    end)
end)

