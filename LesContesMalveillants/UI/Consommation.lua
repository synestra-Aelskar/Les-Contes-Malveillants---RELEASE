-- Consommer depuis un sac, ou administrer a un allie (Core/Consommation.lua).
--
-- Tout ce qui se decide est ici : la repartition des PV (« Vous disposez de 5
-- PV a repartir », UI.Repartition) et, chez l'allie, l'accord. Les regles
-- elles-memes — ce qui est rendu, ce que l'etat porte — sont dans le Core.

local _, LCM = ...
local UI = LCM.UI
local Consommation = LCM.Consommation

local Ecran = {}
UI.Consommation = Ecran

local function Actualiser()
    if UI.Inventaires and UI.Inventaires.Actualiser then UI.Inventaires.Actualiser() end
end

-- Demande la repartition des PV s'il y en a, puis `suite(repartition)`, qui
-- rend true, ou false et la raison (la fenetre reste alors ouverte). Fermer
-- la fenetre sans valider appelle `abandon`.
local function Repartir(entity, element, suite, abandon)
    local pv = Consommation.PVARepartir(element)
    if pv == 0 then return suite(nil) end
    local zones = Consommation.Zones(entity, pv)
    local place = 0
    for _, z in ipairs(zones) do place = place + z.place end
    -- Plus aucune zone ne peut rien recevoir : il n'y a rien a choisir.
    if place == 0 then return suite({}) end
    local total = math.abs(pv)
    UI.Repartition():Demander({
        titre = tostring(element.label),
        phrase = pv > 0 and string.format("Vous disposez de %d PV à répartir.", total)
            or string.format("Vous perdez %d PV : choisissez où.", total),
        total = total, unite = "PV", sens = pv > 0 and 1 or -1,
        lignes = (function()
            local out = {}
            for _, z in ipairs(zones) do
                out[#out + 1] = { id = z.id, label = z.label, courant = z.courant, max = z.max, place = z.place }
            end
            return out
        end)(),
        onValider = function(parts) return suite(parts) end,
        onAnnuler = abandon,
    })
    return true
end
Ecran.Repartir = Repartir

-- Consommer pour soi.
function Ecran.Consommer(entity, ref)
    local element, raison = Consommation.Consommable(entity, ref)
    if not element then LCM.Alerte(raison) return false end
    return Repartir(entity, element, function(parts)
        local bilan, refus = Consommation.Consommer(entity, ref, parts)
        if not bilan then
            LCM.Alerte(refus)
            return false, refus
        end
        LCM.Ok(Consommation.Texte(bilan))
        Actualiser()
        return true
    end)
end

-- Administrer a un allie : la demande part, l'exemplaire attend sa reponse.
function Ecran.Administrer(entity, joueur, ref)
    local ok, raison = Consommation.Administrer(entity, joueur, ref)
    if not ok then LCM.Alerte(raison) return false end
    local element = LCM.Compendium.Resoudre(ref)
    LCM.Info(string.format("« %s » proposé à %s : il doit accepter.", tostring(element and element.label), joueur))
    return true
end

-- Se servir d'un outil contenant (Core/Contenants.lua) : l'effet entier de
-- ce qu'il contient, ses PV repartis comme pour un consommable.
function Ecran.UtiliserContenant(entity, ou)
    local element = LCM.Contenants.ContenuDe(entity, ou)
    if not element then LCM.Alerte("il est vide.") return false end
    return Repartir(entity, element, function(parts)
        local bilan, refus = LCM.Contenants.Utiliser(entity, ou, parts)
        if not bilan then
            LCM.Alerte(refus)
            return false, refus
        end
        LCM.Ok(Consommation.Texte(bilan))
        Actualiser()
        return true
    end)
end

-- ===== Chez l'allie ========================================================

local function Accord()
    if Ecran.accord then return Ecran.accord end
    local d = UI.Confirmer(UIParent, "", "Accepter")
    d.oui.label:SetTextColor(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3])
    -- Refuser se dit a celui qui propose : sans reponse, il ne saurait pas
    -- que son exemplaire lui reste.
    d.non:HookScript("OnClick", function()
        local demande = d.demande
        d.demande = nil
        if demande then Consommation.Refuser(demande.expediteur, demande.element) end
    end)
    Ecran.accord = d
    return d
end

Consommation.SurDemande = function(expediteur, element)
    local d = Accord()
    -- Une demande encore ouverte est refusee : on ne repond qu'a une a la fois.
    if d.demande then Consommation.Refuser(d.demande.expediteur, d.demande.element) end
    d.demande = { expediteur = expediteur, element = element }
    d:Demander(string.format("%s veut vous administrer « %s ».\n%s\nAccepter ?", tostring(expediteur),
        tostring(element.label), Consommation.Resume(element)), function()
        local demande = d.demande
        d.demande = nil
        if not demande then return end
        local moi = LCM.Entities.Self()
        Repartir(moi, element, function(parts)
            local bilan, raison = Consommation.Accepter(expediteur, element, parts)
            if not bilan then
                LCM.Alerte(raison)
                return false, raison
            end
            LCM.Ok(Consommation.Texte(bilan))
            return true
        end, function() Consommation.Refuser(expediteur, element) end)
    end)
end

Consommation.onChange = Actualiser
