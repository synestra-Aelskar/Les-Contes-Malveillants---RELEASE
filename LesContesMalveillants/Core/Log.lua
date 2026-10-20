-- Sorties chat. Un seul endroit : les messages doivent se ressembler, et on
-- doit pouvoir les couper tous d'un coup.

local _, LCM = ...

-- « [ Contes ] - Message » (3 octobre 2026) : « Contes aucun objet... » ne
-- se lisait pas comme une phrase.
local PREFIX = "|cffc8a45e[ Contes ]|r - "
local COLORS = {
    info = "|cffe8dcc0",
    ok = "|cff6fc96f",
    alerte = "|cffe8b451",
    erreur = "|cffe86b6b",
}

-- Les minuscules accentuees qu'un message peut avoir en tete (UTF-8).
local CAPITALES = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â",
                    ["ç"] = "Ç", ["î"] = "Î", ["ô"] = "Ô", ["û"] = "Û" }

-- Le message commence par une majuscule : c'est une phrase. Les messages du
-- code sont ecrits en minuscules pour se lire dans une raison (« Refusé :
-- plus de place »). Un code couleur en tete est saute.
local function Phrase(text)
    local couleur, reste = text:match("^(|c%x%x%x%x%x%x%x%x)(.*)$")
    if couleur then return couleur .. Phrase(reste) end
    -- Le premier caractere, entier : un accent tient sur deux octets.
    local octet = text:byte(1)
    if not octet then return text end
    local n = octet < 192 and 1 or (octet < 224 and 2 or (octet < 240 and 3 or 4))
    local premier, suite = text:sub(1, n), text:sub(n + 1)
    return (CAPITALES[premier] or premier:upper()) .. suite
end

local function Emit(kind, text)
    local frame = DEFAULT_CHAT_FRAME
    local color = COLORS[kind] or COLORS.info
    local line = PREFIX .. color .. Phrase(tostring(text)) .. "|r"
    if frame then frame:AddMessage(line) else print(line) end
end

function LCM.Info(text) Emit("info", text) end
function LCM.Ok(text) Emit("ok", text) end
function LCM.Alerte(text) Emit("alerte", text) end
function LCM.Erreur(text) Emit("erreur", text) end

-- Trace de developpement : muette tant que `/lcm debug` ne l'a pas activee.
function LCM.Debug(text)
    if not (LCM.db and LCM.db.settings and LCM.db.settings.debug) then return end
    Emit("info", "|cff888888[debug]|r " .. tostring(text))
end
