-- Reagir a une action qui vise : la devier, ou intervenir a la place de sa
-- cible.
--
-- Repris du « Bloc D » de Necronicon (Reactions.lua) :
--   * Deviation    : par la cible (ou par un tiers), vers une autre cible.
--   * Intervention : par un tiers, sur lui-meme — la cible le lui PROPOSE ;
--     « avec deplacement » (+25 % sur la part fixe du jet) ou « a distance ».
-- Jet du reacteur : de + arrondi((valeur + bonus) x mecanique), competence au
-- choix (Esprit / Adresse ; « inadaptee » si ce n'est pas celle de
-- l'attaquant, la primaire au taux du malus).
--   bonus = arrondi(valeur x « Deviation par stat »
--                   + moyenne(mes penetrations, mes resistances) x « Deviation par Pen »),
--           x2 pour une intervention, sur les types de l'action.
-- A battre : le jet de l'attaquant (« Rand Resultat ») + « malus distance »
-- (action a distance) + « malus autrui » (l'action ne me visait pas).
-- Reussi : l'action part vers la nouvelle cible ; ses cibles d'origine
-- retirent leur « Vous etes la cible » (sauf si elles avaient deja commence a
-- resoudre : trop tard, la reaction est annulee et remboursee). Rate : les
-- couts sont perdus, l'action continue, et on ne peut plus la detourner.
--
-- Les messages :
--   devie       reacteur -> cibles d'origine   { t, vers, par }
--   devie+      cible d'origine -> reacteur    { t }  (detour accepte)
--   devie!      cible d'origine -> reacteur    { t }  (trop tard)
--   interv?     cible -> tiers                 le paquet de l'action, et pb (qui demande)
--   interv-     tiers -> cible                 { t, ok = 0 (refus) | echec = 1 }

local _, LCM = ...

local Reactions = {}
LCM.Reactions = Reactions

local A = LCM.Actions
local function Eq() return LCM.Equilibrage end
local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Moi() return LCM.PlayerId() end
-- Celui qui reagit signe du nom de la fiche qu'il joue (Identite.NomEnJeu).
local function MonNom() return LCM.Identite and LCM.Identite.NomEnJeu() or Moi() end

-- Peut-on reagir a ce paquet ? Faux, et la raison, sinon.
function Reactions.Possible(paquet)
    local v = type(paquet.valeurs) == "table" and paquet.valeurs or paquet.v or {}
    if v.Zone then return false, "action de zone : ni déviation ni intervention" end
    if tonumber(v["Rand Résultat"]) == nil then
        return false, "l'action ne transporte pas de jet d'attaquant (« Rand Résultat »)"
    end
    if paquet.nr then return false, "une redirection a déjà échoué sur cette action" end
    return true
end

function Reactions.Cout(mode, paquet)
    local c = Eq().reactions[mode] or Eq().reactions.deviation
    local pa = c.pa
    if c.paDeLAction then
        local v = type(paquet.valeurs) == "table" and paquet.valeurs or paquet.v or {}
        local n = tonumber(v["Cout PA"])
        if n then pa = math.max(0, math.floor(n + 0.5)) end
    end
    return pa, c.pf, mode == "intervention" and "Intervention" or "Déviation"
end

local function Types(paquet)
    local v = type(paquet.valeurs) == "table" and paquet.valeurs or paquet.v or {}
    local out = {}
    for _, k in ipairs({ "Type Physique", "Type Elementaire", "Type Cosmologie" }) do
        for t in tostring(v[k] or ""):gmatch("[^,]+") do
            t = Trim(t)
            if t ~= "" and t ~= "?" then out[#out + 1] = t end
        end
    end
    return out
end

local function Moyenne(types, onglet, entity)
    local somme, n = 0, 0
    for _, t in ipairs(types) do
        local v = A.ValeurType(t, onglet, entity)
        if v then somme, n = somme + v, n + 1 end
    end
    return n > 0 and somme / n or nil
end

-- Les chances : ce qu'il faut battre, le bonus, le multiplicateur.
-- options = { competence, deplacement }
function Reactions.Analyse(paquet, mode, competence, deplacement, entity)
    entity = entity or LCM.Entities.Self()
    local act = Eq().actions
    local v = type(paquet.valeurs) == "table" and paquet.valeurs or paquet.v or {}
    local base = tonumber(v["Rand Résultat"]) or 0
    local distance = tostring(v["Type action"] or ""):lower():find("distance", 1, true) ~= nil
    local malusDistance = distance and act.deviationMalusDistance or 0
    local mienne = false
    local cibles = tostring(paquet.ci or "")
    if cibles == "" and not paquet.pb then mienne = true end
    for c in cibles:gmatch("[^,]+") do if Trim(c):lower() == Moi():lower() then mienne = true end end
    local malusAutrui = mienne and 0 or act.deviationMalusAutrui
    local aBattre = base + malusDistance + malusAutrui

    local types = Types(paquet)
    local pen, resi = Moyenne(types, "Penetrations", entity), Moyenne(types, "Résistances", entity)
    local penResi = (pen or resi) and (((pen or 0) + (resi or 0)) / ((pen and 1 or 0) + (resi and 1 or 0))) or 0
    local attaquant = Trim(v["Rand Nom"])
    local adaptee = attaquant == "" or A.Cle(competence) == A.Cle(attaquant)
    local field = A.ChampParLibelle(competence, "roll")
    local valeur = 0
    if field then
        if adaptee then
            valeur = (tonumber(LCM.Entities.Get_Value(entity, field.id)) or 0) + LCM.Formules.Apport(entity, field.id)
                + LCM.Effets.Bonus(entity, field.id)
        else
            valeur = math.floor(LCM.Formules.Primaire(entity, field.id) * Eq().malusInadapte)
        end
    end
    local facteur = mode == "intervention" and 2 or 1
    local bonus = math.floor((valeur * act.deviationParStat + penResi * act.deviationParPen) * facteur + 0.5)
    -- La puissance de la mecanique (deviation ou intervention), comme une action.
    local ligne = mode == "intervention" and "Intervention" or "Déviation"
    local cle = mode == "intervention" and "intervention" or "deviation"
    local function T(col) return A.Stat("Mécaniques de compétence#" .. ligne .. ":" .. col, entity) or 0 end
    local points = A.Stat("Répartition des expertises#" .. cle, entity) or 0
    local equip = A.Stat("Recapitulatif#" .. cle, entity) or 0
    local pct = T("Base") + T("Par point") * points + T("Equip. par point") * equip
    local mult = pct > 0 and pct / 100 or 1
    local bonusDeplacement = (mode == "intervention" and deplacement) and act.interventionBonusDeplacement or 0
    if bonusDeplacement ~= 0 then mult = mult * (1 + bonusDeplacement / 100) end
    local propre = Trim(paquet.a):lower() == Moi():lower() and act.deviationBonusActionPropre or 0
    if propre ~= 0 then mult = mult * (1 + propre / 100) end
    return {
        aBattre = aBattre, base = base, malusDistance = malusDistance, malusAutrui = malusAutrui,
        bonus = bonus, valeur = valeur, adaptee = adaptee, types = types, pen = pen, resi = resi,
        facteur = facteur, mult = mult, pct = pct, bonusDeplacement = bonusDeplacement, propre = propre,
        jet = competence .. (adaptee and "" or " inadapté"), field = field,
    }
end

-- La distance jusqu'a un membre du groupe, si le jeu la donne (UnitPosition
-- ne marche qu'en groupe, et pas partout) ; en metres, comme le deplacement.
function Reactions.Distance(joueur)
    if type(UnitPosition) ~= "function" or not UnitName then return nil end
    local court = tostring(joueur or ""):match("^[^-]+") or ""
    for _, prefixe in ipairs({ "party", "raid" }) do
        for i = 1, prefixe == "party" and 4 or 40 do
            local ok, nom = pcall(UnitName, prefixe .. i)
            if ok and nom and nom:lower() == court:lower() then
                local ok2, x, y = pcall(UnitPosition, prefixe .. i)
                local ok3, mx, my = pcall(UnitPosition, "player")
                if ok2 and ok3 and type(x) == "number" and type(mx) == "number" then
                    return math.sqrt((x - mx) ^ 2 + (y - my) ^ 2)
                end
            end
        end
    end
    return nil
end

-- ===== Agir ================================================================

local attente = {}

-- L'action part vers sa nouvelle cible, une fois ses cibles d'origine
-- prevenues (ou d'emblee s'il n'y en a pas d'autre que soi).
local function Livrer(paquet, cible)
    local p = LCM.Copie(paquet)
    p.valeurs, p.pb, p.pbrp, p.nr = nil, nil, nil, nil
    p.t = tostring(paquet.t or "act") .. "_d" .. math.random(1000, 9999)
    p.rd = MonNom()
    p.ci = cible.pnj and ("PNJ " .. tostring(cible.nom)) or cible.id
    if cible.pnj then
        p.p, p.pn = cible.id, cible.nom
        local mj = cible.mj or Moi()
        if mj == Moi() then A.Recevoir(p, Moi()) else LCM.Reseau.Envoyer("act", p, "WHISPER", mj) end
    elseif cible.id == Moi() then
        A.Recevoir(p, Moi())
    else
        LCM.Reseau.Envoyer("act", p, "WHISPER", cible.id)
    end
end

local function Payer(mode, paquet)
    local pa, pf = Reactions.Cout(mode, paquet)
    local dpa, dpf = A.Disponible(LCM.Entities.Self(), true)
    if pa > 0 and (dpa or 0) < pa then return false, string.format("Pas assez de PA (%d requis).", pa) end
    if pf > 0 and (dpf or 0) < pf then return false, string.format("Pas assez de PF (%d requis).", pf) end
    if not A.Payer(LCM.Entities.Self(), "#pa", pa, true) then return false, "Pas assez de PA." end
    A.Payer(LCM.Entities.Self(), "#fatigue", pf)
    return true
end

-- Retire de la file une action recue (la sienne, deviee).
local function Oublier(t)
    for i = #A.recus, 1, -1 do if A.recus[i].paquet.t == t then table.remove(A.recus, i) end end
end

-- Le jet, et ce qui s'ensuit. `cible` = la nouvelle cible (deviation) ;
-- intervention : soi. Retourne vrai si l'action est detournee.
function Reactions.Agir(recu, mode, competence, cible, deplacement)
    local paquet = recu.paquet
    local ok, raison = Payer(mode, paquet)
    if not ok then LCM.Alerte(raison) return nil, raison end
    local a = Reactions.Analyse(paquet, mode, competence, deplacement, recu.entity)
    if not a.field then LCM.Alerte("compétence introuvable : " .. tostring(competence)) return nil end
    local de = LCM.Roll.Des(a.field.dice.min or 0, a.field.dice.max or 0)
    local fixe = math.floor((a.valeur + a.bonus) * a.mult + 0.5)
    local total = de + fixe
    local _, _, libelle = Reactions.Cout(mode, paquet)
    A.Annoncer(string.format("[%s — Rand %s] D%d : %d + (%d + %d bonus)%s = %d", libelle, a.jet, a.field.dice.max or 0,
        de, a.valeur, a.bonus, a.mult ~= 1 and string.format(" x %.2f", a.mult) or "", total))
    local reussi = total >= a.aBattre
    local nature = tostring(paquet.n or "action")
    local attaquant = Trim(paquet.rp) ~= "" and paquet.rp or tostring(paquet.a)
    if not reussi then
        -- Une deviation ratee expose davantage a l'attaque : a partir de 5
        -- points d'ecart, le resultat normal devient le resultat critique.
        -- La resolution peut encore etre evitee ensuite par une defense reussie.
        local ecart = a.aBattre - total
        if mode == "deviation" and ecart >= 5 then
            local valeurs = paquet.valeurs or paquet.v
            local critique = valeurs and tonumber(valeurs["Total Critique"])
            if critique then
                valeurs["Total Normal"] = tostring(critique)
            end
        end
        A.Annoncer(string.format("%s échoue à %s « %s » de %s (jet %d contre %d) : l'action continue.", MonNom(),
            mode == "intervention" and "intervenir contre" or "dévier", nature, attaquant, total, a.aBattre))
        paquet.nr = 1
        if paquet.pb then
            LCM.Reseau.Envoyer("interv-", { t = paquet.t, echec = 1 }, "WHISPER", paquet.pb)
        else
            -- La cible qui a rate sa deviation resout l'action, sans autre detour.
            A.recus[#A.recus + 1] = recu
            if A.onRecu then A.onRecu(recu) end
        end
        return false
    end
    A.Annoncer(string.format("%s %s « %s » de %s%s (jet %d contre %d).", MonNom(),
        mode == "intervention" and "intervient et reçoit" or "dévie", nature, attaquant,
        mode == "intervention" and "" or (" vers " .. tostring(cible.nom)), total, a.aBattre))
    -- Le deplacement force (jauge qui decompte les metres) : module a venir,
    -- LCM.DeplacementForce. Attention : LCM.Deplacement est la FONCTION de
    -- calcul des deplacements (Data/Fiche.lua), pas un module.
    if mode == "intervention" and deplacement and LCM.DeplacementForce and LCM.DeplacementForce.Demarrer then
        local distance = Reactions.Distance(paquet.pb)
        if distance then LCM.DeplacementForce.Demarrer(distance, "Intervention") end
    end
    Oublier(paquet.t)
    -- Les cibles d'origine (autres que soi, et pas les PNJ) sont prevenues ;
    -- l'action part quand toutes ont repondu (ou au bout de 6 s dans le jeu).
    local origine = {}
    for c in tostring(paquet.ci or ""):gmatch("[^,]+") do
        c = Trim(c)
        if c ~= "" and c:lower() ~= Moi():lower() and c:sub(1, 4) ~= "PNJ " then origine[#origine + 1] = c end
    end
    if #origine == 0 then Livrer(paquet, cible) return true end
    local en = { paquet = paquet, cible = cible, mode = mode, reste = {} }
    for _, c in ipairs(origine) do en.reste[c] = true end
    attente[paquet.t] = en
    for _, c in ipairs(origine) do
        LCM.Reseau.Envoyer("devie", { t = paquet.t, vers = cible.nom, par = MonNom() }, "WHISPER", c)
    end
    local function Partir()
        if en.parti or en.tard then return end
        en.parti = true
        attente[paquet.t] = nil
        Livrer(paquet, cible)
    end
    en.partir = Partir
    if C_Timer and C_Timer.After then C_Timer.After(6, Partir) end
    return true
end

-- Proposer a un tiers d'intervenir : il recoit l'action, et choisit.
function Reactions.Proposer(recu, joueur)
    Oublier(recu.paquet.t)
    recu.propose = joueur
    Reactions.proposees = Reactions.proposees or {}
    Reactions.proposees[recu.paquet.t] = recu
    local p = LCM.Copie(recu.paquet)
    p.valeurs = nil
    p.pb, p.pbrp = Moi(), MonNom()
    LCM.Reseau.Envoyer("interv?", p, "WHISPER", joueur)
end

-- Le tiers refuse : l'action revient chez la cible.
function Reactions.Refuser(recu)
    LCM.Reseau.Envoyer("interv-", { t = recu.paquet.t, ok = 0 }, "WHISPER", recu.paquet.pb)
end

LCM.WhenReady(function()
    local R = LCM.Reseau
    -- On me propose d'intervenir.
    R.Ecouter("interv?", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        d.valeurs = type(d.v) == "table" and d.v or {}
        local recu = { paquet = d, expediteur = expediteur, entity = LCM.Entities.Self(), proposition = true }
        if Reactions.onProposition then Reactions.onProposition(recu) end
    end)
    -- Le tiers a refuse, ou rate : l'action revient, a resoudre.
    R.Ecouter("interv-", function(expediteur, d)
        local recu = Reactions.proposees and Reactions.proposees[tostring(d.t)]
        if not recu then return end
        Reactions.proposees[tostring(d.t)] = nil
        if tostring(d.echec) == "1" then
            recu.paquet.nr = 1
            LCM.Info(string.format("%s n'a pas réussi à intervenir : l'action continue.", expediteur))
        else
            LCM.Info(string.format("%s refuse d'intervenir : l'action revient chez toi.", expediteur))
        end
        A.recus[#A.recus + 1] = recu
        if A.onRecu then A.onRecu(recu) end
    end)
    -- Une action qui me visait est detournee. Trop tard si j'ai deja resolu.
    R.Ecouter("devie", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local t = tostring(d.t)
        if A.resolues[t] then
            LCM.Info(string.format("%s a tenté de détourner l'action, mais tu avais déjà commencé à la résoudre : elle continue.",
                tostring(d.par or expediteur)))
            R.Envoyer("devie!", { t = t }, "WHISPER", expediteur)
            return
        end
        Oublier(t)
        if Reactions.proposees then Reactions.proposees[t] = nil end
        if Reactions.onDetour then Reactions.onDetour(t) end
        R.Envoyer("devie+", { t = t }, "WHISPER", expediteur)
        LCM.Info(string.format("L'action qui te visait a été redirigée par %s vers %s.", tostring(d.par), tostring(d.vers)))
    end)
    R.Ecouter("devie+", function(expediteur, d)
        local en = attente[tostring(d.t)]
        if not en then return end
        en.reste[expediteur] = nil
        if next(en.reste) == nil then en.partir() end
    end)
    -- Trop tard : la reaction est annulee, et ses couts rendus.
    R.Ecouter("devie!", function(expediteur, d)
        local en = attente[tostring(d.t)]
        if not en or en.parti then return end
        en.tard = true
        attente[tostring(d.t)] = nil
        local pa, pf, libelle = Reactions.Cout(en.mode, en.paquet)
        A.Payer(LCM.Entities.Self(), "#pa", -pa)
        A.Payer(LCM.Entities.Self(), "#fatigue", -pf)
        LCM.Alerte(string.format("Trop tard : %s avait déjà commencé à résoudre l'action. %s annulée, coûts remboursés.",
            expediteur, libelle))
    end)
end)
