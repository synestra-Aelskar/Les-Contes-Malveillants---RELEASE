-- Puits de tonnerre du Val'Razkah. Positions posees par le MJ depuis le scanner.
local _, LCM = ...
local P = {}
LCM.PuitsTonnerre = P

local function Magasin()
    LCM.EnsureDatabase()
    LCM.db.puitsTonnerre = type(LCM.db.puitsTonnerre) == "table" and LCM.db.puitsTonnerre or {}
    return LCM.db.puitsTonnerre
end

local function Notifier()
    if P.onChange then P.onChange() end
end

local function PointValide(p)
    if type(p) ~= "table" then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    local carte = tonumber(p.carte)
    local source = tostring(p.source or "")
    local id = tostring(p.id or "")
    if not (x and y and z and carte) or (source ~= "gps" and source ~= "monde")
        or not id:match("^[%w_%-]+$") then return nil end
    return { id = id, x = x, y = y, z = z, carte = carte, source = source,
        auteur = tostring(p.auteur or "") }
end

function P.Tous()
    local out = {}
    for _, point in pairs(Magasin()) do out[#out + 1] = point end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function P.Position()
    local D = LCM.DeplacementForce
    if not D then return nil end
    local x, y, z, source = D.Position("gps", 1)
    local carte = x and D.CarteGPS(1)
    if not x then
        x, y, z, source = D.Position("monde")
        carte = x and D.Carte()
    end
    if not x or not carte then return nil end
    return { x = x, y = y, z = z, source = source, carte = carte }
end

local function Publier(sujet, donnees)
    if LCM.Reseau and LCM.Reseau.Diffusable() then
        LCM.Reseau.Envoyer(sujet, donnees, LCM.Reseau.TOUS)
    end
end

function P.Poser()
    if not LCM.IsMaster() then return false, "réservé au MJ." end
    local pos = P.Position()
    if not pos then
        LCM.DeplacementForce.DemanderGPS(false, true)
        return false, "position indisponible ; attends la réponse GPS et réessaie."
    end
    local point = PointValide({ id = string.format("pt%d_%04d", (time and time()) or 0, math.random(0, 9999)),
        x = pos.x, y = pos.y, z = pos.z, carte = pos.carte, source = pos.source,
        auteur = LCM.PlayerId() })
    if not point then return false, "position invalide." end
    Magasin()[point.id] = point
    Publier("puits+", point)
    Notifier()
    return true, point
end

function P.Retirer(id)
    if not LCM.IsMaster() then return false, "réservé au MJ." end
    local point = Magasin()[tostring(id or "")]
    if not point then return false, "puits introuvable." end
    if point.auteur ~= LCM.PlayerId() then return false, "seul l'auteur du puits peut le retirer." end
    Magasin()[point.id] = nil
    Publier("puits-", { id = point.id })
    Notifier()
    return true
end

-- Rend des coordonnees de radar normalisees et une intensite 0..1. Les deux
-- sources (GPS serveur, monde client) ne se melangent jamais.
function P.Echos(position, rayon)
    local out = {}
    rayon = tonumber(rayon) or 200
    if not position or rayon <= 0 then return out end
    for _, p in pairs(Magasin()) do
        if p.carte == position.carte and p.source == position.source then
            local dx, dy, dz = p.x - position.x, p.y - position.y, p.z - position.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            if distance <= rayon then
                out[#out + 1] = { id = p.id, x = dx / rayon, y = dy / rayon,
                    distance = distance, intensite = 1 - distance / rayon }
            end
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

function P.PlusProche(position, rayon)
    return P.Echos(position, rayon)[1]
end

LCM.WhenReady(function()
    if not LCM.Reseau then return end
    LCM.Reseau.Ecouter("puits+", function(expediteur, donnees)
        if expediteur == LCM.PlayerId() or not LCM.Reseau.Connu(expediteur) then return end
        local point = PointValide(donnees)
        if not point then return end
        point.auteur = expediteur
        Magasin()[point.id] = point
        Notifier()
    end)
    LCM.Reseau.Ecouter("puits-", function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local id = tostring(donnees.id or "")
        local point = Magasin()[id]
        if point and point.auteur == expediteur then
            Magasin()[id] = nil
            Notifier()
        end
    end)
    LCM.Reseau.Ecouter("puits?", function(expediteur)
        if not LCM.IsMaster() or not LCM.Reseau.Connu(expediteur) then return end
        for _, point in ipairs(P.Tous()) do
            if point.auteur == LCM.PlayerId() then
                LCM.Reseau.Envoyer("puits+", point, "WHISPER", expediteur)
            end
        end
    end)
    local function Demander()
        if not LCM.IsMaster() and LCM.Reseau.Diffusable() then
            LCM.Reseau.Envoyer("puits?", {}, LCM.Reseau.TOUS)
        end
    end
    LCM.On("GROUP_ROSTER_UPDATE", Demander)
    Demander()
end)
