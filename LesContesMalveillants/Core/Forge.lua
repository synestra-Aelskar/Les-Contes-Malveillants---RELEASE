-- La Forge : les jeux d'equilibrage des entrees du compendium.
--
-- Reprise du principe de la Forge de Necronicon (necronicon/Forge.lua, elle-
-- meme tiree de l'« Item Creator » d'OmegaHub). Un jeu (« Creation d'arme »)
-- vise UNE categorie du compendium et fixe :
--   * ses raretes : un nom, un pool de points, une couleur ;
--   * pour chaque statistique du bloc de la categorie : verrou, minimum,
--     base, maximum, et le cout d'un point (+1 = combien du pool).
--     Minimum, base et maximum peuvent changer selon la rarete.
--
-- Une entree forgee porte `forge = "jeu/rarete"`. Ce qu'elle depense : la
-- somme, sur les statistiques de sa categorie, de (valeur - base) x cout.
-- Une valeur sous la base rembourse.
--
-- Ce qui change par rapport a Necronicon, et pourquoi :
--   * un jeu est du CONTENU : le MJ l'enregistre et il part dans la base
--     commune, comme un trait. Necronicon le gardait dans sa
--     sauvegarde (NecroniconDB.forge) ;
--   * le cout d'un point est propre a chaque jeu (decision du 3 octobre 2026),
--     la ou Necronicon le partageait entre tous ;
--   * rien n'est rabote : Necronicon ramenait en silence une valeur dans ses
--     bornes. Ici elle reste, et l'enregistrement est REFUSE avec sa raison ;
--   * le bareme BLOQUE (decision du 3 octobre 2026) : des qu'un jeu vise une
--     categorie, toute entree de cette categorie enregistree par le MJ doit
--     en choisir un, et le respecter. Le contenu deja publie n'est pas
--     re-verifie au chargement : c'est le fichier qui fait foi.
--
-- Les pools et les couts ne sont PAS dans Data/Equilibrage.lua : ils sont
-- decides par le MJ en creant le jeu (decision du 3 octobre 2026). Seul le
-- cout d'un point qu'un jeu ne fixe pas y vit.

local _, LCM = ...

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Resolu a l'appel : Core se charge avant Data.
local function Eq() return LCM.Equilibrage.forge end

-- Un entier, ou nil si vide. Une saisie illisible est refusee, pas ignoree.
local function EntierOuRien(id, nom, valeur, Erreur)
    if valeur == nil or Texte(valeur) == "" then return nil end
    local n = tonumber(valeur)
    if not n or n ~= math.floor(n) then
        Erreur(string.format("%s : %s illisible (%s), attendu un entier", id, nom, tostring(valeur)))
    end
    return n
end

-- Les statistiques d'une categorie que la forge peut doser : le bloc de
-- bonus. { cle, label, dossier }, dans l'ordre de l'editeur.
local function Statistiques(categorie)
    local out = {}
    if not categorie or categorie.statistiques ~= "bonus" then return out end
    for _, champ in ipairs(LCM.Compendium.Champs(categorie)) do
        if champ.type == "statistique" then out[#out + 1] = champ end
    end
    return out
end

-- Ces anciennes cibles restent reconnues dans les jeux deja publies, mais ne
-- figurent plus parmi les choix proposes dans la forge.
local function StatistiquesMasquees(categorie)
    local out = {}
    if not categorie or categorie.statistiques ~= "bonus" or categorie.bloc then return out end
    for _, groupe in ipairs(LCM.Compendium.BLOC or {}) do
        if groupe.masque then
            for _, id in ipairs(groupe.champs) do
                local field = LCM.Schema.Field(id)
                out[#out + 1] = { cle = id, label = field and field.label or id,
                    dossier = groupe.dossier, masque = true }
            end
        end
    end
    return out
end

local CATEGORIES_OBJETS = { armes = true, armures = true, accessoires = true, outils = true }

local function EstObjet(categorie)
    local id = type(categorie) == "table" and categorie.id or tostring(categorie or "")
    return CATEGORIES_OBJETS[id] == true
end

-- Min, base, max d'un reglage, coherents entre eux.
local function Bornes(id, quoi, r, Erreur)
    local minimum = EntierOuRien(id, quoi .. " : minimum", r.min, Erreur)
    local base = EntierOuRien(id, quoi .. " : base", r.base, Erreur)
    local maximum = EntierOuRien(id, quoi .. " : maximum", r.max, Erreur)
    if minimum and maximum and minimum > maximum then
        Erreur(string.format("%s : %s, minimum %d au-dessus du maximum %d", id, quoi, minimum, maximum))
    end
    return minimum, base, maximum
end

local Forge = LCM.Registre({
    nom = "jeu", prefixe = "Forge",
    construire = function(definition, element, Erreur)
        local id = element.id
        local categorie = LCM.Compendium.Get(definition.categorie)
        if not categorie then
            Erreur(id .. " : choisis la categorie que ce jeu equilibre")
        end
        if categorie.statistiques ~= "bonus" or not categorie.famille then
            Erreur(string.format("%s : la categorie %s n'a pas de statistiques a doser", id, categorie.label))
        end
        element.categorie = categorie.id

        -- Les raretes, dans leur ordre : c'est celui du menu de la forge.
        if type(definition.raretes) ~= "table" or not definition.raretes[1] then
            Erreur(id .. " : il faut au moins une rarete")
        end
        element.raretes = {}
        local vues = {}
        for index, r in ipairs(definition.raretes) do
            local rid = Texte(r.id)
            local nom = Texte(r.label)
            if rid == "" or nom == "" then Erreur(string.format("%s : rarete %d sans nom", id, index)) end
            if vues[rid] then Erreur(string.format("%s : deux raretes « %s »", id, nom)) end
            vues[rid] = true
            local points = EntierOuRien(id, "points de " .. nom, r.points, Erreur)
            if not points or points < 0 then
                Erreur(string.format("%s : pool de %s illisible (%s)", id, nom, tostring(r.points)))
            end
            local couleur = Texte(r.couleur):gsub("^#", ""):upper()
            if not couleur:match("^%x%x%x%x%x%x$") then
                Erreur(string.format("%s : couleur de %s illisible (%s), attendu RRVVBB", id, nom, tostring(r.couleur)))
            end
            local coutTrait = nil
            if r.coutTrait ~= nil and Texte(r.coutTrait) ~= "" then
                coutTrait = tonumber(r.coutTrait)
                if not coutTrait or coutTrait ~= math.floor(coutTrait)
                    or coutTrait < 1 or coutTrait > LCM.Traits.COUT_MAX then
                    Erreur(string.format("%s : coût de trait de %s invalide (%s)",
                        id, nom, tostring(r.coutTrait)))
                end
            end
            element.raretes[index] = { id = rid, label = nom, points = points,
                couleur = couleur, coutTrait = coutTrait, palierIC = LCM.IC.Palier({id=rid,palierIC=r.palierIC}) }
            if r.palierIC ~= nil and LCM.IC.Pool(r.palierIC) == nil then
                Erreur(id .. " : palier IC inconnu pour " .. nom)
            end
        end

        -- Les reglages par statistique. Un reglage vide ne se retient pas :
        -- une statistique sans reglage est libre, a son cout par defaut.
        local connues = {}
        for _, champ in ipairs(Statistiques(categorie)) do connues[champ.cle] = champ end
        for _, champ in ipairs(StatistiquesMasquees(categorie)) do connues[champ.cle] = champ end
        element.champs = {}
        for cle, r in pairs(type(definition.champs) == "table" and definition.champs or {}) do
            local champ = connues[tostring(cle)]
            if not champ then
                Erreur(string.format("%s : %s n'est pas une statistique de %s", id, tostring(cle), categorie.label))
            end
            if type(r) ~= "table" then Erreur(id .. " : reglage de " .. champ.label .. " illisible") end
            local minimum, base, maximum = Bornes(id, champ.label, r, Erreur)
            local cout = nil
            if r.cout ~= nil and Texte(r.cout) ~= "" then
                cout = tonumber(r.cout)
                if not cout then
                    Erreur(string.format("%s : cout de %s illisible (%s)", id, champ.label, tostring(r.cout)))
                end
            end
            local reglage = { verrou = r.verrou == true or nil, min = minimum, base = base, max = maximum,
                              cout = cout, raretes = {} }
            for rid, sur in pairs(type(r.raretes) == "table" and r.raretes or {}) do
                if not vues[tostring(rid)] then
                    Erreur(string.format("%s : %s vise une rarete inconnue (%s)", id, champ.label, tostring(rid)))
                end
                local quoi = champ.label .. " en " .. tostring(rid)
                local smin, sbase, smax = Bornes(id, quoi, sur, Erreur)
                if smin or sbase or smax then
                    reglage.raretes[tostring(rid)] = { min = smin, base = sbase, max = smax }
                end
            end
            if next(reglage.raretes) == nil then reglage.raretes = nil end
            if next(reglage) ~= nil then element.champs[champ.cle] = reglage end
        end
    end,
})
LCM.Forge = Forge

-- ===== Lecture d'un jeu ====================================================

function Forge.Rarete(jeu, rareteId)
    for _, r in ipairs(jeu and jeu.raretes or {}) do
        if r.id == rareteId then return r end
    end
    return nil
end

-- Le cout d'un trait suit sa rarete. Les anciens jeux n'ont pas ce champ :
-- le bareme par defaut conserve rose/vert a 1, bleu a 2, orange a 3.
function Forge.CoutTrait(jeu, rarete)
    if type(rarete) ~= "table" then return 1 end
    local explicite = tonumber(rarete.coutTrait)
    if explicite then return explicite end
    local parId = { commun = 1, inhabituel = 1, rare = 2,
        epique = 3, legendaire = 4, mythique = 4, unique = 4 }
    local parCouleur = { FF8CB8 = 1, ["4DE04D"] = 1, ["4D8CFF"] = 2,
        FF9926 = 3, FF3838 = 4, BF4DFF = 4, ["9999A6"] = 4 }
    return parId[rarete.id] or parCouleur[tostring(rarete.couleur or ""):upper()] or 1
end

-- Les jeux qui visent une categorie, dans l'ordre de declaration.
function Forge.PourCategorie(categorieId)
    local out = {}
    for _, jeu in ipairs(Forge.list) do
        if jeu.categorie == categorieId then out[#out + 1] = jeu end
    end
    return out
end

Forge.Statistiques = Statistiques

-- Les champs que regle un jeu : ceux de sa categorie, et avant qu'elle soit
-- choisie, ceux d'une categorie a statistiques quelconque — toutes portent le
-- meme bloc (Data/Compendium.lua), le MJ peut donc commencer par la.
function Forge.Champs(categorieId)
    local C = LCM.Compendium
    local categorie = C.Get(categorieId)
    if categorie and categorie.statistiques == "bonus" then return Statistiques(categorie) end
    for _, autre in ipairs(C.categories) do
        if autre.statistiques == "bonus" then return Statistiques(autre) end
    end
    return {}
end

-- Le reglage effectif d'une statistique pour une rarete : ce que la rarete
-- precise l'emporte sur le reglage du jeu. Base absente = 0.
function Forge.Limites(jeu, cle, rareteId)
    local r = jeu and jeu.champs and jeu.champs[cle] or {}
    local sur = rareteId and r.raretes and r.raretes[rareteId] or {}
    local function Choix(nom)
        if sur[nom] ~= nil then return sur[nom] end
        return r[nom]
    end
    return {
        verrou = r.verrou == true,
        min = Choix("min"),
        base = Choix("base") or 0,
        max = Choix("max"),
        cout = r.cout or Eq().coutParDefaut,
    }
end

-- « jeu/rarete » -> le jeu et la rarete, ou nil.
function Forge.Lire(valeur)
    local jeuId, rareteId = Texte(valeur):match("^([^/]+)/(.+)$")
    local jeu = jeuId and Forge.Get(jeuId)
    return jeu, jeu and Forge.Rarete(jeu, rareteId) or nil, jeuId, rareteId
end

function Forge.Valeur(jeu, rarete) return jeu.id .. "/" .. rarete.id end

-- Ce que coute un jeu de valeurs : le total, et le detail par statistique.
-- `valeurs` : cle -> nombre (le `bonus` d'une entree) ; absent = 0. Chaque
-- ligne dit ce qui la met hors bareme, s'il y a quelque chose.
--
-- Deux regles sur les valeurs NEGATIVES (5 octobre 2026) :
--
--   * descendre une statistique sous sa base ne rend que la MOITIE de son
--     cout. Force a -1 dans un jeu ou le point vaut 1 rend 0,5. Un defaut
--     coute a jouer autant qu'il rapporte a construire ; a plein tarif, il
--     etait toujours rentable d'en empiler.
--   * ce que les negatives rendent en tout est PLAFONNE au pool de la rarete.
--     Quinze statistiques a -10 ne financent pas une entree legendaire : avec
--     un pool de 4, elles rendent 4, et l'on peut donc depenser 8 en tout.
--     Sans ce plafond, il suffisait d'assez de defauts pour tout s'offrir.
--
-- Le bilan dit ce qui a ete rendu (`credit`), ce qu'on en garde
-- (`creditRetenu`) et ce que le plafond a mange (`creditPerdu`), pour que
-- l'ecran puisse l'expliquer plutot que d'afficher un total inexplicable.
-- Le pool peut etre multiplie par la place physique prise par l'entree. Pour
-- l'instant seules les armes l'emploient : une arme a deux emplacements a
-- deux fois le budget de sa rarete. Le multiplicateur reste volontairement
-- borne a 1 ou 2, comme le registre des objets.
function Forge.Pool(rarete, multiplicateur, categorie)
    local m = tonumber(multiplicateur) == 2 and 2 or 1
    local bonus = EstObjet(categorie) and (tonumber(Eq().etatObjet.bonusPool) or 0) or 0
    return (rarete and rarete.points or 0) * m + bonus
end

-- Ce qu'une statistique passee sous sa base rend au pool, en part de son cout.
-- La moitie partout, sauf la ou l'equilibrage en decide autrement — les races
-- remboursent en entier.
local function Remboursement(categorie)
    -- Eq() rend DEJA Equilibrage.forge : y rechercher un champ `forge` donnait
    -- nil, et le taux retombait silencieusement sur sa valeur de repli.
    local regle = Eq() or {}
    local id = type(categorie) == "table" and categorie.id or tostring(categorie or "")
    local parCategorie = regle.remboursementParCategorie
    local exception = parCategorie and tonumber(parCategorie[id])
    if exception then return exception end
    return tonumber(regle.remboursement) or 0.5
end

function Forge.Bilan(jeu, rareteId, valeurs, multiplicateurPool, etatObjet, ic)
    valeurs = type(valeurs) == "table" and valeurs or {}
    local categorie = LCM.Compendium.Get(jeu.categorie)
    local rarete = rareteId and Forge.Rarete(jeu, rareteId) or nil
    local lignes, depenses, credit = {}, 0, 0
    local remboursement = Remboursement(categorie)
    -- Premiere caracteristique des objets : leur maximum d'etat. Elle est
    -- commune a tous les jeux d'armes, d'armures et d'accessoires, et n'a
    -- donc pas a etre redefinie dans chaque jeu d'equilibrage.
    if EstObjet(categorie) then
        local regle = Eq().etatObjet
        local base, minimum, pas = tonumber(regle.base) or 10, tonumber(regle.min) or 2,
            tonumber(regle.pas) or 2
        local v = tonumber(etatObjet) or base
        local hors
        if v ~= math.floor(v) then
            hors = "Pts d'armures doit être un nombre entier"
        elseif v < minimum then
            hors = string.format("Pts d'armures sous son minimum (%s < %s)",
                LCM.Compendium.Nombre(v), LCM.Compendium.Nombre(minimum))
        elseif (v - base) % pas ~= 0 then
            hors = string.format("Pts d'armures se règle par pas de %d", pas)
        end
        local coutPoint = (tonumber(regle.coutParPas) or 0.5) / pas
        local ecart = v - base
        local depense = ecart * coutPoint
        if ecart < 0 then
            depense = depense * remboursement
            credit = credit - depense
        else
            depenses = depenses + depense
        end
        lignes[#lignes + 1] = {
            champ = { cle = "etatObjet", label = "Pts d'armures", dossier = "Pts d'armures" },
            valeur = v,
            limites = { base = base, min = minimum, cout = coutPoint, pas = pas },
            depense = depense,
            hors = hors,
            etatObjet = true,
        }
    end
    local toutes = Statistiques(categorie)
    for _, champ in ipairs(StatistiquesMasquees(categorie)) do toutes[#toutes + 1] = champ end
    local horsMasques
    for _, champ in ipairs(toutes) do
        local l = Forge.Limites(jeu, champ.cle, rareteId)
        local v = tonumber(valeurs[champ.cle]) or 0
        local hors
        local N = LCM.Compendium.Nombre
        if l.verrou and v ~= l.base then
            hors = string.format("%s est verrouillé à %s", champ.label, N(l.base))
        elseif l.min and v < l.min then
            hors = string.format("%s sous son minimum (%s < %s)", champ.label, N(v), N(l.min))
        elseif l.max and v > l.max then
            hors = string.format("%s au-dessus de son maximum (%s > %s)", champ.label, N(v), N(l.max))
        end
        local ecart = v - l.base
        local depense
        if ecart < 0 then
            -- Ce qui revient, compte a part : c'est lui que le pool plafonne.
            depense = ecart * l.cout * remboursement
            credit = credit - depense
        else
            depense = ecart * l.cout
            depenses = depenses + depense
        end
        if champ.masque then
            horsMasques = horsMasques or hors
        else
            lignes[#lignes + 1] = { champ = champ, valeur = v, limites = l, depense = depense, hors = hors }
        end
    end

    -- Sans rarete connue (un jeu qu'on est en train d'ecrire), rien ne plafonne
    -- : on n'a pas de pool a quoi se referer.
    local pool = rarete and Forge.Pool(rarete, multiplicateurPool, categorie) or nil
    local retenu = credit
    if pool and credit > pool then retenu = pool end
    local poolClassique = pool
    local bonusIC = EstObjet(categorie) and LCM.IC.Bilan(ic).forge or 0
    if pool then pool = pool + bonusIC end
    return {
        poolClassique = poolClassique, bonusIC = bonusIC,
        total = depenses - retenu,
        lignes = lignes,
        horsMasques = horsMasques,
        depenses = depenses,
        credit = credit,
        creditRetenu = retenu,
        creditPerdu = credit - retenu,
        pool = pool,
        valeurs = valeurs,
    }
end

-- La rarete la plus basse dont le pool couvre ces valeurs, s'il y en a une.
--
-- On refait le bilan pour CHAQUE rarete : depuis que le credit des negatives
-- est plafonne par le pool, le total depend de la rarete qu'on vise. Calcule
-- une fois pour toutes, il proposait une rarete ou les valeurs ne rentraient
-- pas.
function Forge.RareteSuffisante(jeu, valeurs, multiplicateurPool, etatObjet, ic)
    if type(valeurs) ~= "table" then return nil end
    local meilleure
    for _, r in ipairs(jeu.raretes) do
        local bilan = Forge.Bilan(jeu, r.id, valeurs, multiplicateurPool, etatObjet, ic)
        local possible = not ic or (LCM.IC.Palier(r) and LCM.IC.Bilan(ic, LCM.IC.Palier(r)).restants >= 0)
        if possible and bilan.total <= bilan.pool and (not meilleure or r.points < meilleure.points) then
            meilleure = r
        end
    end
    return meilleure
end

-- ===== Le garde-fou ========================================================

-- La categorie du compendium ou tombe une entree de cette famille.
local function CategorieDe(famille, element)
    for _, categorie in ipairs(LCM.Compendium.categories) do
        if categorie.famille == famille and (not categorie.filtre or categorie.filtre(element)) then
            return categorie
        end
    end
    return nil
end
Forge.CategorieDe = CategorieDe

local function Noms(jeux)
    local out = {}
    for _, jeu in ipairs(jeux) do out[#out + 1] = "« " .. jeu.label .. " »" end
    return table.concat(out, ", ")
end

-- Vrai si l'entree (deja construite par son registre) respecte le bareme de
-- sa categorie ; sinon false et la premiere raison. Une categorie qu'aucun
-- jeu ne vise est libre, meme si l'entree garde le « jeu/rarete » d'un jeu
-- supprime depuis : sinon elle ne pourrait plus jamais etre modifiee.
function Forge.Verifier(famille, element, reception)
    if famille == "objets" then
        local _, rarete = Forge.Lire(element.forge)
        local ancien = LCM.Objets.Get(element.id)
        local ok, raison = LCM.IC.Verifier(element.ic, ancien and ancien.ic, rarete, reception)
        if not ok then return false, raison end
    elseif element.ic ~= nil then return false, "les IC sont réservés aux objets" end
    local categorie = CategorieDe(famille, element)
    if not categorie then return true end
    local jeux = Forge.PourCategorie(categorie.id)
    if #jeux == 0 then return true end

    local valeur = Texte(element.forge)
    if valeur == "" then
        return false, string.format("%s passe par un jeu d'équilibrage (%s) : choisis-en un, et sa rareté",
            categorie.label, Noms(jeux))
    end
    local jeu, rarete, jeuId, rareteId = Forge.Lire(valeur)
    if not jeu then
        return false, string.format("jeu d'équilibrage inconnu (%s)", tostring(jeuId or valeur))
    end
    if jeu.categorie ~= categorie.id then
        return false, string.format("le jeu « %s » n'équilibre pas %s", jeu.label, categorie.label)
    end
    if not rarete then
        return false, string.format("rareté inconnue dans « %s » (%s)", jeu.label, tostring(rareteId))
    end
    local multiplicateurPool = categorie.id == "armes" and element.taille or 1
    local etatObjet = type(element.etat) == "table" and element.etat.max or nil
    local bilan = Forge.Bilan(jeu, rarete.id, element.bonus, multiplicateurPool, etatObjet, element.ic)
    if bilan.horsMasques then return false, bilan.horsMasques end
    for _, ligne in ipairs(bilan.lignes) do
        if ligne.hors then return false, ligne.hors end
    end
    if bilan.total > bilan.pool then
        return false, string.format("%s pts dépensés, le pool %s en permet %s",
            LCM.Compendium.Nombre(bilan.total), rarete.label, LCM.Compendium.Nombre(bilan.pool))
    end
    return true
end

-- Les choix du champ « Forge » d'une categorie : chaque rarete de chaque jeu
-- qui la vise. Un seul menu choisit les deux.
function Forge.Options(categorieId)
    local out = {}
    for _, jeu in ipairs(Forge.PourCategorie(categorieId)) do
        for _, r in ipairs(jeu.raretes) do
            local categorie = LCM.Compendium.Get(jeu.categorie)
            out[#out + 1] = { id = Forge.Valeur(jeu, r),
                              label = string.format("%s (%s pts)", r.label,
                                  LCM.Compendium.Nombre(Forge.Pool(r, 1, categorie))), groupe = jeu.label }
        end
    end
    return out
end
