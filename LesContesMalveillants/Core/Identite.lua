-- Identite : qui est le joueur, vu des autres.
--
-- Reprise de Necronicon (GetTRP3IconPath, GetPlayerDisplayProfile) : si Total
-- RP 3 est la, le nom RP (prenom + nom) et l'icone de son profil l'emportent ;
-- sinon, le nom du personnage WoW. C'est cette identite que Necronicon mettait
-- sur le bouton du menu, dans l'initiative, la presence et les messages de
-- combat (attackerRp, resolu cote emetteur : le recepteur l'affiche tel quel).
--
-- TRP3 est lu, jamais ecrit, et toujours sous pcall : son API peut manquer ou
-- changer, l'addon ne doit pas tomber avec.

local _, LCM = ...

local Identite = {}
LCM.Identite = Identite

local function Nettoyer(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function DonneeTRP(chemin)
    local api = TRP3_API
    if not (type(api) == "table" and type(api.profile) == "table"
        and type(api.profile.getData) == "function") then return nil end
    local ok, valeur = pcall(api.profile.getData, chemin)
    return ok and valeur or nil
end

-- Les caracteristiques du profil TRP3 du joueur, ou nil.
function Identite.ProfilTRP()
    local data = DonneeTRP("player")
    if not (type(data) == "table" and type(data.characteristics) == "table") then return nil end
    return data.characteristics
end

-- Le texte TRP porte parfois ses propres balises de mise en forme. Le volet de
-- fiche est un FontString ordinaire : on en garde le contenu lisible, sans
-- exposer les marqueurs du profil.
local function TexteTRP(valeur)
    local texte = tostring(valeur or "")
    texte = texte:gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("{[^}]-}", "")
    return Nettoyer(texte)
end

function Identite.DescriptionTRP()
    local a = DonneeTRP("player/about")
    if type(a) ~= "table" then return nil end
    local t1 = type(a.T1) == "table" and TexteTRP(a.T1.TX) or ""
    local t3 = type(a.T3) == "table" and type(a.T3.PH) == "table"
        and TexteTRP(a.T3.PH.TX) or ""
    local morceaux = {}
    if type(a.T2) == "table" then
        for _, bloc in ipairs(a.T2) do
            local texte = type(bloc) == "table" and TexteTRP(bloc.TX) or ""
            if texte ~= "" then morceaux[#morceaux + 1] = texte end
        end
    end
    local t2 = table.concat(morceaux, "\n\n")
    if tonumber(a.TE) == 2 and t2 ~= "" then return t2 end
    if tonumber(a.TE) == 3 and t3 ~= "" then return t3 end
    if t1 ~= "" then return t1 end
    if t3 ~= "" then return t3 end
    return t2 ~= "" and t2 or nil
end

-- Les cinq « coups d'oeil » de TRP3. Les cases inactives restent presentes :
-- l'interface peut ainsi garder une disposition stable tout en disant qu'une
-- case n'est pas renseignee.
function Identite.CoupsOeilTRP()
    local pe = DonneeTRP("player/misc/PE")
    local out = {}
    for index = 1, 5 do
        local brut = type(pe) == "table" and pe[tostring(index)] or nil
        out[index] = {
            actif = type(brut) == "table" and brut.AC == true,
            nom = type(brut) == "table" and TexteTRP(brut.TI) or "",
            description = type(brut) == "table" and TexteTRP(brut.TX) or "",
        }
    end
    return out
end

-- Copie volontairement minuscule du profil, faite pour accompagner une fiche
-- LCM lors de sa consultation par le MJ. On n'envoie ni profil complet, ni
-- notes, ni données techniques TRP3 : seulement ce que le volet affiche.
function Identite.InstantaneTRP()
    local caracteristiques = Identite.ProfilTRP()
    if not caracteristiques then return nil end
    local instantane = {
        nom = Identite.NomTRP() or "",
        age = TexteTRP(caracteristiques.AG),
        poids = TexteTRP(caracteristiques.WE),
        description = Identite.DescriptionTRP() or "",
        coups = {},
    }
    for index, coup in ipairs(Identite.CoupsOeilTRP()) do
        instantane.coups[index] = {
            actif = coup.actif and "1" or "0",
            nom = coup.nom,
            description = coup.description,
        }
    end
    return instantane
end

-- Le nom RP TRP3 (« Prenom Nom »), ou nil.
function Identite.NomTRP()
    local c = Identite.ProfilTRP()
    if not c then return nil end
    local prenom, nom = Nettoyer(c.FN), Nettoyer(c.LN)
    local complet = Nettoyer(prenom .. (nom ~= "" and (" " .. nom) or ""))
    return complet ~= "" and complet or nil
end

-- L'icone du profil TRP3 (chemin complet), ou nil.
function Identite.IconeTRP()
    local c = Identite.ProfilTRP()
    local icone = c and Nettoyer(c.IC) or ""
    if icone == "" then return nil end
    return "Interface\\Icons\\" .. icone
end

-- { joueur, nom, icone } : l'identite a afficher ou a envoyer. L'icone vaut
-- nil sans TRP3 — a l'appelant de choisir son repli.
function Identite.Joueur()
    return {
        joueur = LCM.PlayerId(),
        nom = Identite.NomTRP() or tostring((UnitName and UnitName("player")) or "Inconnu"),
        icone = Identite.IconeTRP(),
    }
end

-- Le nom sous lequel on AGIT : celui de la fiche qui agit (le PNJ incarne,
-- sinon le personnage), le nom RP ou WoW a defaut (4 octobre 2026). C'est ce
-- que la cible lit (« Déclaré par Assassin du culte ») : le MJ qui incarne un
-- PNJ ne doit pas signer de son nom de joueur.
function Identite.NomEnJeu(entity)
    entity = entity or (LCM.Entities and LCM.Entities.Self())
    local nom = type(entity) == "table" and tostring(entity.name or "") or ""
    if nom ~= "" then return nom end
    return Identite.Joueur().nom
end

-- TRP3 peut se charger apres nous : on previent qui affiche l'identite.
Identite.abonnes = {}
function Identite.AuChangement(fonction)
    Identite.abonnes[#Identite.abonnes + 1] = fonction
end

local function Prevenir()
    for _, fonction in ipairs(Identite.abonnes) do pcall(fonction) end
end

LCM.On("ADDON_LOADED", function(nom)
    if nom == "totalRP3" or nom == "TotalRP3" or nom == "TRP3" then Prevenir() end
end)
