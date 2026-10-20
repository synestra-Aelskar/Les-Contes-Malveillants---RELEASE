-- Un seul cadre d'evenements pour tout l'addon. Les modules s'y abonnent au
-- lieu d'en creer chacun un : on garde un point d'entree unique et un ordre de
-- demarrage lisible.

local _, LCM = ...

local frame = CreateFrame("Frame")
local handlers = {}

-- LCM.On("PLAYER_LOGIN", function(...) end)
function LCM.On(event, handler)
    if type(event) ~= "string" or type(handler) ~= "function" then return end
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    table.insert(handlers[event], handler)
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(handlers[event] or {}) do
        -- Sous pcall : un module qui tombe ne doit pas empecher les suivants de
        -- recevoir l'evenement, ni casser la connexion.
        local ok, err = pcall(handler, ...)
        if not ok then
            LCM.Erreur(string.format("erreur sur %s : %s", tostring(event), tostring(err)))
        end
    end
end)

-- Demarrage. Tout ce qui a besoin de la sauvegarde ou du compagnon MJ attend
-- PLAYER_LOGIN : a ce moment-la tous les addons sont charges.
-- Un module qui plante au demarrage n'arrete pas les autres, mais il le DIT :
-- le pcall avalait l'erreur, et un module tombe la n'enregistrait jamais ses
-- ecouteurs reseau — il ne recevait plus rien, sans un mot (16 octobre 2026).
local function Lancer(handler)
    local ok, erreur = pcall(handler)
    if not ok and LCM.Erreur then LCM.Erreur("au démarrage : " .. tostring(erreur)) end
end

LCM.On("PLAYER_LOGIN", function()
    LCM.EnsureDatabase()
    LCM.ready = true
    if LCM.OnReady then
        for _, handler in ipairs(LCM.OnReady) do Lancer(handler) end
    end
    LCM.Debug(string.format("pret — version %s, MJ : %s", tostring(LCM.version), tostring(LCM.IsMaster())))
end)

-- LCM.WhenReady(fn) : execute maintenant si l'addon est deja pret, sinon a la
-- connexion. Evite aux modules de dupliquer ce test.
LCM.OnReady = {}
function LCM.WhenReady(handler)
    if type(handler) ~= "function" then return end
    if LCM.ready then Lancer(handler) else table.insert(LCM.OnReady, handler) end
end
