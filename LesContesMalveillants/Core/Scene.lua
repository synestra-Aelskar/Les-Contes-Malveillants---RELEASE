-- Les PNJ en scene.
--
-- Cibler un PNJ sans parcourir tous les PNJ de l'univers : le MJ met en jeu
-- ceux de la scene (fenetre Incarner, qui en cree des INSTANCES), et c'est
-- cette liste courte, et elle seule, que les joueurs voient dans le choix des
-- cibles. Combat ou pas.
--
-- Le MJ diffuse la liste au groupe a chaque changement, et la renvoie a qui la
-- demande (un joueur qui arrive, qui recharge, qui ouvre le choix des cibles).
-- Une action sur un de ces PNJ part au MJ qui l'a mis en scene, et se resout
-- chez lui, sur la fiche du PNJ (Core/Actions.lua).
--
-- Ce qu'un joueur recoit n'est qu'un nom, une icone et un identifiant
-- d'instance : la fiche du PNJ reste chez le MJ. Tout vit en memoire vive.
--
-- Les messages :
--   scene   MJ -> groupe ou un joueur   { nb, i1, n1, ic1, ... }
--   scene?  joueur -> groupe            « qui a une scene ? »

local _, LCM = ...

local Scene = {}
LCM.Scene = Scene

-- Chez un joueur : la scene recue, et le MJ qui l'a envoyee.
Scene.recue = { mj = nil, pnj = {} }

local NOM_MAX, ICONE_MAX = 30, 90
local function Tronquer(texte, maximum)
    texte = tostring(texte or "")
    return #texte > maximum and texte:sub(1, maximum) or texte
end

-- Les PNJ de la scene, vus d'ici : chez le MJ, ses instances en jeu ; chez un
-- joueur, ce que le MJ a envoye. Chaque entree dit a quel MJ s'adresser.
function Scene.Liste()
    if LCM.IsMaster() then
        local out = {}
        for _, instance in ipairs(LCM.Incarnation.Liste()) do
            out[#out + 1] = { id = instance.id, nom = instance.name, icone = LCM.Icone(instance.icon),
                              mj = LCM.PlayerId() }
        end
        return out
    end
    return Scene.recue.pnj
end

local function Paquet()
    local p = { nb = 0 }
    for k, e in ipairs(Scene.Liste()) do
        p.nb = k
        p["i" .. k] = e.id
        p["n" .. k] = Tronquer(e.nom, NOM_MAX)
        p["ic" .. k] = Tronquer(e.icone, ICONE_MAX)
    end
    return p
end

-- Le MJ envoie sa scene : au groupe, ou a un seul joueur.
function Scene.Diffuser(joueur)
    if not LCM.IsMaster() then return false end
    if joueur then return LCM.Reseau.Envoyer("scene", Paquet(), "WHISPER", joueur) end
    local canal = LCM.Combat.CanalGroupe()
    if not canal then return false end
    return LCM.Reseau.Envoyer("scene", Paquet(), canal)
end

function Scene.Demander()
    if LCM.IsMaster() then return false end
    local canal = LCM.Combat.CanalGroupe()
    if not canal then return false end
    return LCM.Reseau.Envoyer("scene?", {}, canal)
end

local function Oublier()
    Scene.recue = { mj = nil, pnj = {} }
    if Scene.onChange then Scene.onChange() end
end

-- Mettre en jeu ou retirer un PNJ change la scene : on la rediffuse. On
-- s'accroche aux deux fonctions d'Incarner plutot que de les modifier : la
-- scene est une affaire de reseau, l'incarnation n'a pas a la connaitre.
local Instancier, OublierInstance = LCM.Incarnation.Instancier, LCM.Incarnation.Oublier
LCM.Incarnation.Instancier = function(...)
    local instance, raison = Instancier(...)
    if instance then Scene.Diffuser() end
    return instance, raison
end
LCM.Incarnation.Oublier = function(...)
    local fait = OublierInstance(...)
    if fait then Scene.Diffuser() end
    return fait
end

LCM.WhenReady(function()
    local R = LCM.Reseau
    R.Ecouter("scene", function(expediteur, d)
        if LCM.IsMaster() then return end
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local pnj = {}
        for k = 1, tonumber(d.nb) or 0 do
            if d["i" .. k] then
                pnj[#pnj + 1] = { id = tostring(d["i" .. k]), nom = tostring(d["n" .. k] or d["i" .. k]),
                                  icone = d["ic" .. k], mj = expediteur }
            end
        end
        Scene.recue = { mj = expediteur, pnj = pnj }
        if Scene.onChange then Scene.onChange() end
    end)
    R.Ecouter("scene?", function(expediteur)
        if LCM.Fiches.DansLeGroupe(expediteur) then Scene.Diffuser(expediteur) end
    end)
    Scene.Demander()
    Scene.Diffuser()
end)

-- Le groupe change : le MJ qui a quitte le groupe emporte sa scene ; un
-- nouveau venu la recoit. Un groupe qui se forme envoie des rafales
-- d'evenements : on ne rediffuse pas plus d'une fois toutes les 10 secondes.
local derniere = -math.huge
LCM.On("GROUP_ROSTER_UPDATE", function()
    local mj = Scene.recue.mj
    if mj and not LCM.Fiches.DansLeGroupe(mj) then Oublier() end
    local maintenant = (GetTime and GetTime()) or 0
    if maintenant - derniere < 10 then return end
    derniere = maintenant
    Scene.Diffuser()
end)
