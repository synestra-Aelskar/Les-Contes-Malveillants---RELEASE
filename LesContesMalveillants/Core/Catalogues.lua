-- Catalogues : ce qu'une entite porte dans des emplacements.
--
-- Dans le compendium du template, objets, etats, maladies, apprentissages ont
-- tous la MEME forme : une icone, une description, des bonus et des avantages
-- sur les statistiques de la fiche. Et une fiche les range dans des conteneurs
-- a nombre d'emplacements fixe (1 arme, 30 etats, 60 apprentissages...).
--
-- Un catalogue, c'est ce modele une fois pour toutes :
--   * un REGISTRE de definitions (Construire / Add / Get / Retirer), cree en
--     jeu par le MJ puis exporte, comme les traits ;
--   * des CATEGORIES, chacune avec sa capacite (lue dans l'equilibrage) ;
--   * cote entite, des LISTES D'IDENTIFIANTS par categorie, rien d'autre ;
--   * une SOURCE D'EFFETS (Core/Effets.lua) : ce qu'on porte compte partout.
--
--   local Etats = LCM.Catalogue({
--       nom = "etat", cleEntite = "etats", primaires = true,
--       categories = { { id = "etat", label = "État", capacite = "etat" }, ... },
--   })

local _, LCM = ...

-- LCM.Icone et les champs communs (onglet General du template) vivent dans
-- Core/Contenus.lua : un catalogue n'est qu'une famille du compendium parmi
-- d'autres.

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Capacites()
    return LCM.Equilibrage and LCM.Equilibrage.conteneurs or {}
end

function LCM.Catalogue(def)
    local C = { list = {}, byId = {}, CATEGORIES = def.categories, nom = def.nom }
    local CATEGORIE = {}
    for _, categorie in ipairs(def.categories) do CATEGORIE[categorie.id] = categorie end
    local prefixe = "LCM/" .. (def.prefixe or def.nom) .. " : "

    local function Erreur(message) error(prefixe .. tostring(message), 0) end

    function C.Categorie(id) return CATEGORIE[tostring(id or "")] end

    function C.Capacite(categorieId)
        local categorie = CATEGORIE[tostring(categorieId or "")]
        if not categorie then return 0 end
        return tonumber(Capacites()[categorie.capacite or categorie.id]) or 0
    end

    -- Combien d'emplacements un element occupe. Un seul, sauf si la famille
    -- dit autrement : une arme a deux mains en prend deux, et l'autre main
    -- n'est alors plus libre pour un bouclier (5 octobre 2026).
    function C.Taille(element)
        if type(element) ~= "table" then element = C.Get(element) end
        if not element then return 1 end
        local taille = def.taille and def.taille(element) or 1
        taille = math.floor(tonumber(taille) or 1)
        return taille >= 1 and taille or 1
    end

    -- Les emplacements PRIS dans une categorie : on compte les places, pas les
    -- objets. Compter les objets laissait croire qu'il restait de la place a
    -- cote d'une arme a deux mains.
    function C.Occupation(entity, categorieId)
        local total = 0
        for _, id in ipairs(C.Ids(entity, categorieId)) do
            total = total + C.Taille(id)
        end
        return total
    end

    -- Verifie et met en forme sans enregistrer. Une seule categorie : elle
    -- est implicite.
    function C.Construire(definition)
        if type(definition) ~= "table" then Erreur(def.nom .. " invalide") end
        local id = tostring(definition.id or "")
        if id == "" then Erreur(def.nom .. " sans identifiant") end
        local categorie = tostring(definition.categorie or "")
        if categorie == "" and #def.categories == 1 then categorie = def.categories[1].id end
        if not CATEGORIE[categorie] then
            Erreur(id .. " : categorie inconnue « " .. categorie .. " »")
        end
        local bonus, avantage = LCM.Effets.Lire(id, definition, Erreur, def.primaires == true)
        local element = {
            id = id,
            label = tostring(definition.label or id),
            categorie = categorie,
            bonus = bonus,
            avantage = avantage,
        }
        LCM.ChampsCommuns(definition, element, Erreur)
        -- Certaines familles portent une jauge d'etat meme quand une ancienne
        -- definition ne la declarait pas encore. Le defaut reste ici, au coeur
        -- du registre, afin que toute entree et tout PNJ soient egaux.
        if element.etat == nil and def.etatDefaut ~= nil then
            local maximum = type(def.etatDefaut) == "function" and def.etatDefaut() or def.etatDefaut
            maximum = tonumber(maximum)
            if not maximum or maximum < 0 then Erreur(id .. " : etat par defaut illisible") end
            element.etat = { courant = maximum, max = maximum }
        end
        -- Champs propres a une famille (les places d'un sac) : des entiers,
        -- bornes, avec un defaut, ou des cases a cocher (sac du MJ). Un nombre
        -- illisible est refuse, pas devine. `categories` limite un champ a
        -- certaines categories (l'armure d'une piece, pas d'une arme) ; un
        -- defaut peut etre une fonction, pour le lire dans l'equilibrage,
        -- qui n'existe pas encore quand Core se charge.
        for _, champ in ipairs(def.champs or {}) do
            local brut = definition[champ.cle]
            -- Une case laissee vide dans l'atelier : le defaut, pas un refus.
            if brut == "" then brut = nil end
            local defaut = champ.defaut
            if type(defaut) == "function" then defaut = defaut() end
            if champ.categories and not champ.categories[categorie] then
                -- Hors de ses categories, le champ n'existe pas.
            elseif champ.genre == "case" then
                element[champ.cle] = brut == true or brut == 1 or brut == "1" or nil
            elseif champ.genre == "choix" then
                -- Un choix parmi des valeurs nommees : la nature d'un sac, par
                -- exemple. Hors de la liste, c'est une faute de saisie, pas une
                -- valeur a garder.
                local valeur = brut == nil and defaut or tostring(brut)
                if not (champ.valeurs and champ.valeurs[valeur]) then
                    Erreur(string.format("%s : %s invalide (%s)", id, champ.libelle or champ.cle, tostring(brut)))
                end
                element[champ.cle] = valeur
            else
                local valeur = brut == nil and defaut or tonumber(brut)
                -- `max` autant que `min` : une arme qui tiendrait sept
                -- emplacements est une faute de frappe, pas une intention.
                if valeur == nil or valeur ~= math.floor(valeur) or valeur < (champ.min or 0)
                    or (champ.max and valeur > champ.max)
                then
                    Erreur(string.format("%s : %s invalide (%s)", id, champ.libelle or champ.cle, tostring(brut)))
                end
                element[champ.cle] = valeur
            end
        end
        return element
    end

    function C.Add(definition)
        local element = C.Construire(definition)
        if C.byId[element.id] then Erreur(def.nom .. " en double : " .. element.id) end
        C.byId[element.id] = element
        C.list[#C.list + 1] = element
        return element
    end

    -- Remplace une definition partagee sans changer sa position au catalogue.
    function C.Remplacer(definition)
        local element = C.Construire(definition)
        local precedent = C.byId[element.id]
        C.byId[element.id] = element
        if precedent then
            for index, courant in ipairs(C.list) do
                if courant.id == element.id then
                    C.list[index] = element
                    return element
                end
            end
        end
        C.list[#C.list + 1] = element
        return element
    end

    function C.Get(id) return C.byId[tostring(id or "")] end

    -- Une entree supprimee en seance (voir Traits.Retirer).
    function C.Retirer(id)
        id = tostring(id or "")
        if not C.byId[id] then return false end
        C.byId[id] = nil
        for index = #C.list, 1, -1 do
            if C.list[index].id == id then table.remove(C.list, index) end
        end
        return true
    end

    -- ===== Cote entite =====================================================

    -- Lecture seule : ne CREE rien (voir Traits.lua, meme piege).
    local VIDE = {}
    local function Rangee(entity, categorieId)
        local stock = type(entity) == "table" and entity[def.cleEntite]
        if type(stock) ~= "table" then return VIDE end
        local rangee = stock[categorieId]
        return type(rangee) == "table" and rangee or VIDE
    end

    -- Les identifiants portes dans une categorie, TOUS, meme ceux dont la
    -- definition n'existe plus (la fenetre doit pouvoir les montrer). Une copie.
    function C.Ids(entity, categorieId)
        local out = {}
        for _, id in ipairs(Rangee(entity, tostring(categorieId))) do out[#out + 1] = id end
        return out
    end

    function C.Porte(entity, id)
        for _, categorie in ipairs(def.categories) do
            for _, porte in ipairs(Rangee(entity, categorie.id)) do
                if porte == tostring(id) then return true end
            end
        end
        return false
    end

    -- Tout ce qui est porte et connu, toutes categories.
    function C.Portes(entity)
        local out = {}
        for _, categorie in ipairs(def.categories) do
            for _, id in ipairs(Rangee(entity, categorie.id)) do
                local element = C.Get(id)
                if element then out[#out + 1] = element end
            end
        end
        return out
    end

    -- Place un element. Renvoie true, ou false et la raison : un refus se dit.
    function C.Placer(entity, id)
        if type(entity) ~= "table" then return false, "aucune entite." end
        local element = C.Get(id)
        if not element then return false, def.nom .. " inconnu." end
        -- Deux fois le meme cumulerait ses bonus : refuse — sauf pour une
        -- famille sans effets ou chaque exemplaire compte (deux sacs), et sauf
        -- pour les objets, ou porter deux dagues identiques est normal
        -- (10 octobre 2026). Ce sont les TYPES qui bornent, pas l'identifiant.
        if not def.doublons and C.Porte(entity, element.id) then
            return false, string.format("%s est deja porte.", element.label)
        end
        -- La limite par type : « une seule cape ». Elle est portee par l'entree
        -- de type elle-meme (`maxEquipe` sur la liste), pour que le MJ la regle
        -- dans le compendium au lieu d'attendre une version de l'addon.
        local refusType, raisonType = C.TypeSature(entity, element)
        if refusType then return false, raisonType end
        local places = C.Capacite(element.categorie)
        local occupees = C.Occupation(entity, element.categorie)
        local taille = C.Taille(element)
        if occupees + taille > places then
            -- On dit ce qu'il faut, pas seulement ce qui manque : « il faut
            -- deux emplacements » evite de chercher pourquoi une main libre ne
            -- suffit pas.
            return false, string.format("plus d'emplacement libre en %s (%d / %d)%s.",
                CATEGORIE[element.categorie].label:lower(), occupees, places,
                taille > 1 and string.format(" : « %s » en demande %d", element.label, taille) or "")
        end
        entity[def.cleEntite] = type(entity[def.cleEntite]) == "table" and entity[def.cleEntite] or {}
        local stock = entity[def.cleEntite]
        stock[element.categorie] = type(stock[element.categorie]) == "table" and stock[element.categorie] or {}
        table.insert(stock[element.categorie], element.id)
        return true
    end

    -- Le type d'un element, et ce que ce type autorise. `nil` : pas de limite.
    function C.LimiteDuType(element)
        local type_ = element and element.type
        if not (type_ and LCM.Listes and LCM.Listes.Get) then return nil end
        local entree = LCM.Listes.Get(tostring(type_))
        local max = entree and tonumber(entree.maxEquipe)
        if not max or max <= 0 then return nil end
        return max, entree
    end

    -- Ce type est-il deja au complet sur cette entite ?
    function C.TypeSature(entity, element)
        local max, entree = C.LimiteDuType(element)
        if not max then return false end
        local portes = 0
        for _, id in ipairs(C.Ids(entity, element.categorie)) do
            local autre = C.Get(id)
            if autre and autre.type == element.type then portes = portes + 1 end
        end
        if portes < max then return false end
        return true, string.format("%s : %d au maximum, et tu en portes déjà %d.",
            (entree and entree.label) or tostring(element.type), max, portes)
    end

    -- Enleve un element (un seul exemplaire), qu'il existe encore ou non.
    -- Efface les tables vides.
    function C.Enlever(entity, id)
        local stock = type(entity) == "table" and entity[def.cleEntite]
        if type(stock) ~= "table" then return false end
        local cible = tostring(id)
        for categorieId, rangee in pairs(stock) do
            if type(rangee) == "table" then
                for index = #rangee, 1, -1 do
                    if rangee[index] == cible then
                        table.remove(rangee, index)
                        if #rangee == 0 then stock[categorieId] = nil end
                        if next(stock) == nil then entity[def.cleEntite] = nil end
                        return true
                    end
                end
            end
        end
        return false
    end

    -- Les definitions d'une categorie qu'on ne porte pas deja : ce que la
    -- fenetre propose.
    function C.Candidats(entity, categorieId)
        local out = {}
        for _, element in ipairs(C.list) do
            if element.categorie == categorieId and (def.doublons or not C.Porte(entity, element.id)) then
                out[#out + 1] = element
            end
        end
        return out
    end

    -- `def.apport` : ce que la famille donne vraiment. Les objets le reglent
    -- sur leur etat ; les autres familles donnent ce qu'elles annoncent.
    LCM.Effets.Source(def.nom, C.Portes, function() return C.list end, def.apport)
    return C
end
