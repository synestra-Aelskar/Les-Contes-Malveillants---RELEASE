-- Les usages appartiennent a l'exemplaire, jamais a sa definition de forge.
-- Ce module ne consomme qu'apres confirmation de l'effet par l'appelant.
local _, LCM = ...
local Charges = {}
LCM.IC.Charges = Charges

local function Entier(n)
    return type(n) == "number" and n >= 0 and n < math.huge and n == math.floor(n)
end

function Charges.Nouveau(id, ref)
    assert(type(id) == "string" and id ~= "", "identité d'exemplaire requise")
    assert(type(ref) == "string" and ref:match("^objets/.+"), "référence d'objet requise")
    return { version = 1, id = id, ref = ref, usages = {} }
end

local function Verifier(exemplaire, propriete, frequence, contexte)
    if type(exemplaire) ~= "table" or exemplaire.version ~= 1
        or type(exemplaire.id) ~= "string" or exemplaire.id == ""
        or type(exemplaire.ref) ~= "string" or not exemplaire.ref:match("^objets/.+")
        or type(exemplaire.usages) ~= "table" then
        return nil, "exemplaire IC invalide."
    end
    if type(propriete) ~= "string" or propriete == "" then return nil, "propriété IC absente." end
    if type(frequence) ~= "table" then return nil, "fréquence IC absente." end
    contexte = contexte or {}
    local nature = frequence.type
    if nature == "sans_limite" then return { illimite = true } end
    if not Entier(frequence.nombre) or frequence.nombre < 1 then
        return nil, "limite d'utilisation invalide."
    end
    local cle
    if nature == "heures24" then
        if not Entier(contexte.maintenant) then return nil, "horloge indisponible." end
    elseif nature == "combat" or nature == "tour" then
        if type(contexte.combat) ~= "string" or contexte.combat == "" then
            return nil, "aucun combat actif."
        end
        cle = contexte.combat
        if nature == "tour" then
            if not Entier(contexte.tour) then return nil, "tour indisponible." end
            cle = cle .. ":" .. contexte.tour
        end
    else
        return nil, "fréquence IC inconnue."
    end
    local utilises, retenus = 0, {}
    local historique = exemplaire.usages[propriete]
    if historique ~= nil and type(historique) ~= "table" then return nil, "historique IC invalide." end
    for k in pairs(historique or {}) do
        if not Entier(k) or k < 1 or k > #historique then return nil, "historique IC discontinu." end
    end
    for _, usage in ipairs(historique or {}) do
        if type(usage) ~= "table" or type(usage.action) ~= "string"
            or not Entier(usage.date) then return nil, "historique IC invalide." end
        -- Fenetre glissante, pas minuit : changer de porteur ne recharge rien.
        local garde = nature == "heures24" and usage.date > contexte.maintenant - 24 * 60 * 60
            or nature ~= "heures24" and usage.cle == cle
        if garde then retenus[#retenus + 1] = usage; utilises = utilises + 1 end
    end
    return { restants = math.max(0, frequence.nombre - utilises), retenus = retenus, cle = cle }
end

-- Lecture pure : ouvrir un survol ne migre ni ne purge la sauvegarde.
function Charges.Restants(exemplaire, propriete, frequence, contexte)
    local bilan, raison = Verifier(exemplaire, propriete, frequence, contexte)
    if not bilan then return nil, raison end
    return bilan.illimite and math.huge or bilan.restants
end

function Charges.Consommer(exemplaire, propriete, frequence, contexte, action)
    if type(action) ~= "string" or action == "" then return false, "identité d'action requise." end
    local bilan, raison = Verifier(exemplaire, propriete, frequence, contexte)
    if not bilan then return false, raison end
    if not contexte or not Entier(contexte.maintenant) then return false, "horloge indisponible." end
    -- Un rejeu ne doit ni repayer ni autoriser une deuxieme application.
    for _, usage in ipairs(exemplaire.usages[propriete] or {}) do
        if usage.action == action then return false, "action déjà consommée." end
    end
    if bilan.illimite then
        -- L'idempotence des effets illimites appartient au journal d'actions :
        -- aucun compteur de charges ne pretend pouvoir la garantir.
        return true
    end
    if bilan.restants == 0 then return false, "aucune utilisation restante." end
    bilan.retenus[#bilan.retenus + 1] = { action = action, date = contexte.maintenant, cle = bilan.cle }
    exemplaire.usages[propriete] = bilan.retenus
    return true
end
