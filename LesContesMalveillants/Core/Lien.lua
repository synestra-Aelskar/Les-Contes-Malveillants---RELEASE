-- Les liens de chat.
--
-- Un sort se cite dans la conversation comme un objet du jeu : « [Coupe
-- tranchante] », cliquable. C'est la technique des liens personnalises — un
-- `|H` d'un type que WoW ne connait pas, que le jeu laisse passer et qu'on
-- intercepte sur SetItemRef. Total RP 3 fait de meme, donc elle est eprouvee
-- dans l'environnement de la campagne.
--
-- Le lien ne porte PAS le sort : seulement a qui il est et son identifiant.
-- Un texte de chat est court, et un sort peut etre long. Celui qui clique et
-- qui ne connait pas le sort le DEMANDE a son proprietaire (Core/Reseau.lua) ;
-- la reponse arrive, l'infobulle s'affiche, et il peut l'ajouter au sien.

local _, LCM = ...

local Lien = {}
LCM.Lien = Lien

Lien.TYPE = "lcmsort"
local COULEUR = "ff8aa4ff"

-- Ce qu'on a recu d'autrui et qu'on n'a pas (encore) pris : garde en memoire
-- vive seulement. Rien n'entre en sauvegarde sans que le joueur l'accepte.
local connus = {}

local function Cle(proprietaire, id)
    return tostring(proprietaire) .. "/" .. tostring(id)
end

-- Le texte VISIBLE d'un lien, nettoye de tout code d'affichage. Un libelle de
-- compendium peut en porter (une couleur, une icone) : glisse tel quel entre
-- « |h[ » et « ]|h », le premier « | » ferme le lien avant l'heure et le chat
-- n'affiche plus qu'un bout de texte mort, impossible a cliquer.
local function Lisible(texte)
    texte = tostring(texte or "")
    texte = texte:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    texte = texte:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    texte = texte:gsub("|H.-|h(.-)|h", "%1")
    -- Ce qui resterait de « | » n'a plus de sens ici : on l'enleve plutot que
    -- de le doubler, un lien n'est pas l'endroit pour une barre verticale.
    texte = texte:gsub("|", "")
    -- Une icone retiree laisse son espace : deux blancs de suite se verraient.
    return (texte:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
Lien.Lisible = Lisible

function Lien.Sort(entity, sort)
    if type(sort) ~= "table" then return nil end
    local proprietaire = (type(entity) == "table" and entity.id) or LCM.PlayerId()
    return string.format("|c%s|H%s:%s:%s|h[%s]|h|r",
        COULEUR, Lien.TYPE, proprietaire, sort.id, Lisible(sort.label))
end

-- Pose le lien dans la zone de saisie si elle est ouverte ; sinon l'affiche,
-- ou il reste cliquable et copiable.
function Lien.Inserer(lien)
    if not lien then return false end
    local boite = _G.ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if boite and ChatEdit_InsertLink and ChatEdit_InsertLink(lien) then return true end
    LCM.Info(lien)
    return false
end

-- Ce qu'on sait d'un sort cite : le sien, celui d'un PNJ qu'on a, ou celui
-- qu'on nous a envoye il y a un instant.
function Lien.Trouver(proprietaire, id)
    local moi = LCM.Entities.Self()
    if moi and moi.id == proprietaire then
        local sort = LCM.Sorts.Get(moi, id)
        if sort then return sort, true end
    end
    local entity = LCM.Entities.Get(proprietaire)
    if entity then
        local sort = LCM.Sorts.Get(entity, id)
        if sort then return sort, true end
    end
    return connus[Cle(proprietaire, id)], false
end

function Lien.Retenir(proprietaire, sort)
    if type(sort) ~= "table" or not sort.id then return end
    connus[Cle(proprietaire, sort.id)] = sort
end

-- ===== L'infobulle =========================================================

function Lien.Montrer(proprietaire, id)
    local sort = Lien.Trouver(proprietaire, id)
    if not GameTooltip then return sort end
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    if not sort then
        GameTooltip:SetText(tostring(id), 1, 0.82, 0.3)
        GameTooltip:AddLine("Sort inconnu — demande en cours a " .. tostring(proprietaire) .. ".", 0.7, 0.68, 0.62, true)
        GameTooltip:Show()
        Lien.Demander(proprietaire, id)
        return nil
    end
    GameTooltip:SetText(tostring(sort.label), 1, 0.82, 0.3)
    if sort.description then GameTooltip:AddLine(sort.description, 0.86, 0.84, 0.78, true) end
    if sort.champ1 then GameTooltip:AddLine(sort.champ1, 0.6, 0.58, 0.54, true) end
    if sort.champ2 then GameTooltip:AddLine(sort.champ2, 0.6, 0.58, 0.54, true) end
    if sort.jet then
        GameTooltip:AddLine(string.format("Jet : %s a %s", tostring(sort.jet.min), tostring(sort.jet.max)), 0.9, 0.75, 0.35)
    end
    GameTooltip:AddLine("De " .. tostring(proprietaire), 0.5, 0.48, 0.45)
    GameTooltip:Show()
    return sort
end

-- ===== Le reseau ===========================================================

function Lien.Demander(proprietaire, id)
    local nom = tostring(proprietaire)
    if nom == "" or nom == LCM.PlayerId() then return false end
    return LCM.Reseau.Envoyer("sort?", { id = tostring(id) }, "WHISPER", nom)
end

-- Envoyer un sort a quelqu'un : c'est le « partage ». Le destinataire ne le
-- recoit pas dans sa sauvegarde — il recoit de quoi le regarder, et decide.
function Lien.Partager(entity, id, cible)
    local sort = LCM.Sorts.Get(entity, id)
    if not sort then return false, "sort inconnu." end
    cible = tostring(cible or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cible == "" then return false, "a qui ?" end
    local donnees = {
        id = sort.id, label = sort.label, description = sort.description,
        icone = sort.icone, champ1 = sort.champ1, champ2 = sort.champ2,
    }
    if sort.jet then donnees.jet = { min = sort.jet.min, max = sort.jet.max } end
    local ok, morceaux = LCM.Reseau.Envoyer("sort", donnees, "WHISPER", cible)
    if not ok then return false, "l'envoi a echoue." end
    return true, morceaux
end

LCM.WhenReady(function()
    -- On me demande un de mes sorts.
    LCM.Reseau.Ecouter("sort?", function(expediteur, donnees)
        local moi = LCM.Entities.Self()
        local sort = moi and LCM.Sorts.Get(moi, donnees.id)
        if not sort then return end
        Lien.Partager(moi, sort.id, expediteur)
    end)

    -- On me donne un sort. Il reste en memoire vive tant que je ne l'ai pas
    -- pris : rien n'entre dans ma sauvegarde sans que je le veuille.
    LCM.Reseau.Ecouter("sort", function(expediteur, donnees)
        local sort, raison = LCM.Sorts.Valider(donnees)
        if not sort then
            LCM.Debug(string.format("sort refuse de %s : %s", tostring(expediteur), tostring(raison)))
            return
        end
        sort.id = tostring(donnees.id or sort.label)
        Lien.Retenir(expediteur, sort)
        LCM.Info(string.format("%s te montre %s", tostring(expediteur), Lien.Sort({ id = expediteur }, sort)))
        if Lien.onRecu then Lien.onRecu(expediteur, sort) end
    end)
end)

-- ===== Les entrees du compendium ===========================================
-- Le bouton « Link » d'une ligne du compendium (Necronicon : Link >
-- Montrer). On choisit a qui (membres du groupe ou du raid, ou n'importe
-- quel nom pour un /w), et l'entree part ENTIERE : toutes ses donnees, pas
-- seulement son nom — un objet forge, une race, un PNJ avec sa fiche.
--
-- Pourquoi les donnees ne sont pas DANS le lien du chat : un message de chat
-- tient en 255 caracteres, un PNJ en fait des milliers. Elles voyagent par
-- les messages d'addon (decoupees, etalees, Core/Reseau.lua) ; le lien
-- cliquable qui s'affiche chez le destinataire les designe.
--
-- Ce qui arrive reste en MEMOIRE VIVE : on regarde, on n'importe pas. Pas
-- de « Partager » a la Necronicon : le contenu n'entre pas dans la
-- sauvegarde d'un joueur, il arrive par la mise a jour.

Lien.TYPE_ENTREE = "lcmentree"
local COULEUR_ENTREE = "ffe6c06b"
local entreesRecues = {}

local function Court(nom) return tostring(nom or ""):match("^([^-]+)") or tostring(nom or "") end

function Lien.Entree(categorie, element, proprietaire)
    if type(categorie) ~= "table" or type(element) ~= "table" then return nil end
    return string.format("|c%s|H%s:%s:%s:%s|h[%s]|h|r", COULEUR_ENTREE, Lien.TYPE_ENTREE,
        proprietaire or LCM.PlayerId(), categorie.id, element.id,
        Lisible(element.label or element.id))
end

-- Une entree en texte, et retour. Format type par type (n, s, b, t), pour
-- que les nombres restent des nombres et les listes des listes : l'encodage
-- du reseau, lui, rend tout en chaines a un seul niveau. Le nombre finit par
-- une virgule et pas un point-virgule : le reseau echappe « ; » sur trois
-- octets, et un PNJ a des centaines de nombres.
local function Serialiser(v, out, vus)
    local t = type(v)
    if t == "number" then out[#out + 1] = "n" .. tostring(v) .. ","
    elseif t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then out[#out + 1] = v and "b1" or "b0"
    elseif t == "table" then
        -- Une table deja en cours d'ecriture (une reference circulaire) ne
        -- se recopie pas : on bouclerait sans fin.
        if vus[v] then return out end
        vus[v] = true
        out[#out + 1] = "t"
        for k, valeur in pairs(v) do
            local tk, tv = type(k), type(valeur)
            -- Les fonctions et les champs internes ne voyagent pas.
            if (tk == "string" or tk == "number") and tv ~= "function" and tv ~= "userdata"
                and not (tk == "string" and k:sub(1, 2) == "__")
            then
                if not (tv == "table" and vus[valeur]) then
                    Serialiser(k, out, vus)
                    Serialiser(valeur, out, vus)
                end
            end
        end
        vus[v] = nil
        out[#out + 1] = "e"
    end
    return out
end
function Lien.Serialiser(v) return table.concat(Serialiser(v, {}, {})) end

-- Ce qui arrive du reseau est lu, jamais execute (pas de loadstring) ; un
-- texte tronque ou trafique donne au pire une table incomplete.
local function Lire(texte, i, profondeur)
    if profondeur > 20 then return nil, #texte + 1 end
    local c = texte:sub(i, i)
    if c == "n" then
        local fin = texte:find(",", i, true)
        if not fin then return nil, #texte + 1 end
        return tonumber(texte:sub(i + 1, fin - 1)), fin + 1
    elseif c == "s" then
        local deux = texte:find(":", i, true)
        local n = deux and tonumber(texte:sub(i + 1, deux - 1))
        if not n then return nil, #texte + 1 end
        return texte:sub(deux + 1, deux + n), deux + n + 1
    elseif c == "b" then
        return texte:sub(i + 1, i + 1) == "1", i + 2
    elseif c == "t" then
        local out = {}
        i = i + 1
        while i <= #texte and texte:sub(i, i) ~= "e" do
            local k, v
            k, i = Lire(texte, i, profondeur + 1)
            v, i = Lire(texte, i, profondeur + 1)
            if k == nil then return out, #texte + 1 end
            out[k] = v
        end
        return out, i + 1
    end
    return nil, #texte + 1
end
function Lien.Deserialiser(texte)
    local v = Lire(tostring(texte or ""), 1, 0)
    return v
end

-- L'entree citee. Celle qu'on nous a ENVOYEE passe avant la notre : c'est
-- elle que l'autre voulait montrer (une entree corrigee depuis, un PNJ que
-- nous n'avons pas). Sans envoi, la notre.
function Lien.TrouverEntree(proprietaire, categorieId, id)
    local categorie = LCM.Compendium.Get(categorieId)
    if not categorie then return nil, nil end
    local recue = entreesRecues[Cle(proprietaire, categorieId .. "/" .. tostring(id))]
        or entreesRecues[Cle(Court(proprietaire), categorieId .. "/" .. tostring(id))]
    if recue then return categorie, recue end
    return categorie, LCM.Compendium.Entree(categorie, id)
end

function Lien.OuvrirEntree(proprietaire, categorieId, id)
    local categorie, element = Lien.TrouverEntree(proprietaire, categorieId, id)
    if not categorie then
        LCM.Info(string.format("Catégorie inconnue « %s » : mets l'addon à jour.", tostring(categorieId)))
        return false
    end
    if element then
        if LCM.UI and LCM.UI.Compendium and LCM.UI.Compendium.Voir then LCM.UI.Compendium.Voir(categorie, element) end
        return true
    end
    if tostring(proprietaire) == LCM.PlayerId() then
        LCM.Info(string.format("« %s » n'existe plus dans ton compendium.", tostring(id)))
        return false
    end
    -- Un lien recopie dans le chat sans envoi : on demande les donnees.
    LCM.Info(string.format("« %s » n'est pas dans ton compendium : demande à %s…", tostring(id), tostring(proprietaire)))
    LCM.Reseau.Envoyer("entree?", { categorie = categorieId, id = tostring(id) }, "WHISPER", tostring(proprietaire))
    return nil
end

local function Paquet(categorie, element, pour)
    return { categorie = categorie.id, id = element.id, corps = Lien.Serialiser(element), pour = pour }
end

-- Envoie une entree entiere a des joueurs. Plusieurs membres du groupe : un
-- seul envoi sur le canal du groupe, avec la liste des destinataires (les
-- autres l'ignorent) — un PNJ envoye cinq fois en chuchotement, c'est cinq
-- fois la file d'attente. Sinon, un chuchotement chacun : un /w part a
-- n'importe qui, dans le groupe ou non.
function Lien.EnvoyerEntree(categorie, element, joueurs)
    if type(categorie) ~= "table" or type(element) ~= "table" then return false, "rien à envoyer." end
    local cibles, vus = {}, {}
    for _, j in ipairs(joueurs or {}) do
        j = tostring(j or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if j ~= "" and j ~= LCM.PlayerId() and not vus[j] then
            vus[j] = true
            cibles[#cibles + 1] = j
        end
    end
    if #cibles == 0 then return false, "choisis au moins un joueur." end
    if categorie.id == "traits" and LCM.IsMaster() then
        for _, joueur in ipairs(cibles) do
            local acces = LCM.AccesTraits and LCM.AccesTraits.Liste(joueur)
            if not (acces and acces[element.id]) then
                return false, string.format("« %s » n'est pas autorisé pour %s.",
                    tostring(element.label or element.id), joueur)
            end
        end
    end
    local canal = LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
    local tousDuGroupe = canal ~= nil
    for _, j in ipairs(cibles) do
        if not LCM.Reseau.DansLeGroupe(j) then tousDuGroupe = false end
    end
    local morceaux
    if #cibles > 1 and tousDuGroupe then
        local ok, n = LCM.Reseau.Envoyer("entree", Paquet(categorie, element, table.concat(cibles, ",")),
            canal, nil, { etale = true })
        if not ok then return false, "l'envoi a échoué." end
        morceaux = n
    else
        for _, j in ipairs(cibles) do
            local ok, n = LCM.Reseau.Envoyer("entree", Paquet(categorie, element), "WHISPER", j, { etale = true })
            if not ok then return false, "l'envoi a échoué (" .. j .. ")." end
            morceaux = (morceaux or 0) + n
        end
    end
    return true, morceaux, cibles
end

-- Suis-je dans la liste « pour » d'un envoi au groupe ?
local function PourMoi(pour)
    if not pour or pour == "" then return true end
    local moi = LCM.PlayerId()
    for nom in tostring(pour):gmatch("[^,]+") do
        if nom == moi or Court(nom) == Court(moi) then return true end
    end
    return false
end

LCM.WhenReady(function()
    -- On me demande une entree que j'ai citee.
    LCM.Reseau.Ecouter("entree?", function(expediteur, donnees)
        local categorie = LCM.Compendium.Get(donnees.categorie)
        if categorie and categorie.id == "traits" and LCM.IsMaster() then
            local acces = LCM.AccesTraits and LCM.AccesTraits.Liste(expediteur)
            if not (acces and acces[donnees.id]) then return end
        end
        local element = categorie and LCM.Compendium.Entree(categorie, donnees.id)
        if not element then return end
        LCM.Reseau.Envoyer("entree", Paquet(categorie, element), "WHISPER", expediteur, { etale = true })
    end)

    -- On me l'envoie : en memoire vive, un lien cliquable dans le chat, et la
    -- carte s'ouvre.
    LCM.Reseau.Ecouter("entree", function(expediteur, donnees)
        if not PourMoi(donnees.pour) then return end
        local categorie = LCM.Compendium.Get(donnees.categorie)
        if not categorie then
            LCM.Info(string.format("%s t'envoie une entrée d'une catégorie inconnue (%s) : mets l'addon à jour.",
                tostring(expediteur), tostring(donnees.categorie)))
            return
        end
        local element = Lien.Deserialiser(donnees.corps)
        if type(element) ~= "table" then return end
        element.id = tostring(donnees.id)
        element.label = tostring(element.label or element.id)
        if categorie.id == "traits" and not LCM.Traits.EstAccessible(element.id) then return end
        entreesRecues[Cle(expediteur, categorie.id .. "/" .. element.id)] = element
        LCM.Info(string.format("%s te montre %s", tostring(expediteur), Lien.Entree(categorie, element, expediteur)))
        Lien.OuvrirEntree(expediteur, categorie.id, element.id)
    end)
end)

-- Prendre un sort qu'on m'a montre.
function Lien.Adopter(proprietaire, id)
    local sort = Lien.Trouver(proprietaire, id)
    if not sort then return nil, "ce sort n'est pas la." end
    local moi = LCM.Entities.Self()
    if not moi then return nil, "aucun personnage." end
    return LCM.Sorts.Ajouter(moi, sort)
end

-- ===== Le clic =============================================================
-- Un lien ne se clique que si DEUX choses sont vraies : la fenetre de chat
-- accepte les liens (`SetHyperlinksEnabled`), et quelqu'un ecoute le clic.
--
-- On ne tenait que la seconde, et par une seule porte — `SetItemRef`, ce que
-- fait l'interface par defaut. Une fenetre dont les liens sont coupes affiche
-- « [Nom] » en texte mort : rien a cliquer, et aucune erreur pour le dire. On
-- allume donc les liens sur chaque fenetre, et on ecoute aussi
-- `OnHyperlinkClick`, la porte qu'empruntent les addons qui remplacent le chat
-- (5 octobre 2026).

-- Le meme clic peut nous arriver par les deux portes. On ne fait le geste
-- qu'une fois : sinon la carte s'ouvrirait en double.
local dernierLien, dernierTemps = nil, -1

local function Intercepter(lien)
    lien = tostring(lien or "")
    local maintenant = (GetTime and GetTime()) or 0
    if lien == dernierLien and (maintenant - dernierTemps) < 0.5 then return true end

    local p, categorieId, entreeId = lien:match("^" .. Lien.TYPE_ENTREE .. ":([^:]+):([^:]+):(.+)$")
    if p then
        dernierLien, dernierTemps = lien, maintenant
        Lien.OuvrirEntree(p, categorieId, entreeId)
        return true
    end
    local proprietaire, id = lien:match("^" .. Lien.TYPE .. ":(.-):(.+)$")
    if not proprietaire then return false end
    dernierLien, dernierTemps = lien, maintenant
    Lien.Montrer(proprietaire, id)
    return true
end
Lien.Intercepter = Intercepter

-- Une fenetre de chat : ses liens sont allumes, et son clic nous arrive.
function Lien.BrancherChat(frame)
    if type(frame) ~= "table" then return false end
    if frame.SetHyperlinksEnabled then frame:SetHyperlinksEnabled(true) end
    if frame.lcmLienBranche then return true end
    if not frame.HookScript then return false end
    frame.lcmLienBranche = true
    frame:HookScript("OnHyperlinkClick", function(_, lien) Intercepter(lien) end)
    return true
end

function Lien.BrancherLeChat()
    local branchees, vues = 0, {}
    local function Brancher(frame)
        if type(frame) ~= "table" or vues[frame] then return end
        vues[frame] = true
        if Lien.BrancherChat(frame) then branchees = branchees + 1 end
    end
    -- `CHAT_FRAMES` d'abord : c'est la liste que le jeu tient a jour et que
    -- les remplacants de chat (Prat, ElvUI) alimentent avec LEURS fenetres.
    -- Ne chercher que « ChatFrame1..N » laissait ces fenetres-la sans ecoute,
    -- et un lien y restait du texte mort (12 octobre 2026).
    for _, frame in ipairs(_G.CHAT_FRAMES or {}) do
        Brancher(type(frame) == "string" and _G[frame] or frame)
    end
    for index = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        Brancher(_G["ChatFrame" .. index])
    end
    return branchees
end

if _G.SetItemRef and hooksecurefunc then
    hooksecurefunc("SetItemRef", function(lien) Intercepter(lien) end)
end

-- Apres l'ouverture : les fenetres de chat existent, et celles qu'un addon
-- ajoute ensuite sont reprises a la volee.
if LCM.WhenReady then LCM.WhenReady(function() Lien.BrancherLeChat() end) end

LCM.AddCommand("lien", "vérifie que les liens de chat sont cliquables", function()
    local branchees = Lien.BrancherLeChat()
    LCM.Info(string.format("fenêtres de chat branchées : %d", branchees))
    LCM.Info(string.format("SetItemRef : %s", _G.SetItemRef and "oui" or "ABSENT"))
    -- Une fenetre dont les liens sont coupes affiche « [Nom] » en texte mort :
    -- rien a cliquer, et aucune erreur pour le dire. On regarde donc chacune.
    local coupees = {}
    for _, frame in ipairs(_G.CHAT_FRAMES or {}) do
        local f = type(frame) == "string" and _G[frame] or frame
        if type(f) == "table" and f.GetHyperlinksEnabled and not f:GetHyperlinksEnabled() then
            coupees[#coupees + 1] = tostring(f:GetName() or "?")
        end
    end
    LCM.Info(string.format("liens coupés : %s", #coupees > 0 and table.concat(coupees, ", ") or "aucune"))
    local moi = LCM.Entities.Self()
    local categorie = LCM.Compendium and LCM.Compendium.categories
        and LCM.Compendium.categories[1]
    local element = categorie and (LCM.Compendium.Entrees(categorie) or {})[1]
    if element then
        LCM.Info("essai (clique dessus) : " .. tostring(Lien.Entree(categorie, element)))
    elseif moi then
        LCM.Info("aucune entrée de compendium pour faire l'essai.")
    end
end)
