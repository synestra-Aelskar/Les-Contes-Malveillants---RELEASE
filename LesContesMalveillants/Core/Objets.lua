-- Objets : armes, armures et vetements, accessoires.
--
-- Un catalogue (Core/Catalogues.lua) : un objet est une DEFINITION, comme un
-- trait — icone, description, categorie, bonus, avantage. Il est cree en jeu
-- par le MJ (atelier), puis exporte vers Data/Genere/Objets.lua. Un objet
-- peut donner une primaire (le template en a : une armure a Force +1).
--
-- Cote entite, on ne stocke que ce qui est equipe : des identifiants, ranges
-- par categorie, autant que la categorie a d'emplacements.
--
--     entity.equipement = { arme = { "lame_de_givre" }, accessoire = { ... } }
--
-- On n'equipe que ce qu'on POSSEDE (3 octobre 2026) : l'objet doit etre dans
-- un sac du personnage, et il le quitte en passant sur lui ; le retirer le
-- remet dans le premier sac qui a de la place. Le compendium n'est pas un
-- magasin. Tout le monde peut donc equiper ses propres affaires ; remplir un
-- sac, en revanche, reste un geste du MJ (UI/Inventaires.lua).

local _, LCM = ...

-- `onglet` et `bloc` : les libelles de la fenetre Equipements du template.
-- `toutesLesCases` : la fenetre montre toutes les places, meme vides (les
-- cinq pieces d'armure, les cinq accessoires se lisent d'un coup d'oeil).
local Objets = LCM.Catalogue({
    nom = "objet", prefixe = "Objets", cleEntite = "equipement", primaires = true,
    -- Porter deux fois la meme dague est normal : ce sont les TYPES qui
    -- bornent (« une seule cape »), pas l'identifiant (10 octobre 2026).
    doublons = true,
    -- Ce qu'une piece apporte suit son etat : voir Objets.ApportSelonEtat.
    -- `rang` est sa place parmi les objets portes (Effets.Apport) : deux
    -- capuches identiques n'ont pas le meme etat.
    apport = function(entity, objet, montant, rang)
        return LCM.Objets.ApportSelonEtat(entity, objet, montant,
            LCM.Objets.ExemplaireAuRangPorte(entity, rang))
    end,
    etatDefaut = function() return LCM.Equilibrage.forge.etatObjet.base end,
    categories = {
        { id = "arme",       label = "Arme",       onglet = "Armes",       bloc = "Armes" },
        { id = "equipement", label = "Armure",     onglet = "Armures",     bloc = "Armures et vêtements", toutesLesCases = true },
        { id = "accessoire", label = "Accessoire", onglet = "Accessoires", bloc = "Accessoires", toutesLesCases = true },
        { id = "outil",      label = "Outil",      onglet = "Outils",      bloc = "Outils", toutesLesCases = true },
    },
    -- La valeur d'armure d'une piece (Equilibrage.armure). Une arme ou un
    -- accessoire n'en a pas.
    champs = {
        { cle = "armure", libelle = "armure", min = 0, categories = { equipement = true },
          defaut = function() return LCM.Equilibrage.armure.parDefaut end },
        -- Combien de mains une arme demande. Une epee en prend une, et il
        -- reste la place d'un bouclier ; une arme a deux mains prend les deux
        -- (5 octobre 2026).
        { cle = "taille", libelle = "emplacements", min = 1, max = 2,
          categories = { arme = true }, defaut = 1 },
    },
    -- Ce que l'element occupe : sa taille s'il en declare une.
    taille = function(objet) return tonumber(objet and objet.taille) or 1 end,
})
LCM.Objets = Objets

-- Les objets forges avant le nouveau bareme portaient 10 points de base et
-- gagnaient 2 points par palier. La conversion se fait a la lecture de leur
-- definition, sans modifier les fichiers generes (la synchro les regenere).
-- Les definitions recentes portent une version explicite ; 40 sans version
-- reste aussi intact, car il peut deja venir de la nouvelle forge. Le rempart
-- publie a 40 dans l'ancien bareme est l'exception connue.
local ConstruireObjet = Objets.Construire
function Objets.Construire(definition)
    local source = definition
    local etat = type(definition) == "table" and definition.etat
    local ancien = type(etat) == "table" and tonumber(etat.max)
    if definition and definition.forge and type(etat) == "table" and etat.version == nil
        and ancien and ancien >= 2
        and (ancien < 40 or (ancien - 40) % 6 ~= 0 or definition.id == "rempart_de_guerre")
        and ancien == math.floor(ancien)
        and (ancien - 10) % 2 == 0 then
        source = LCM.Copie(definition)
        local maximum = 40 + ((ancien - 10) / 2) * 6
        source.etat.max = maximum
        source.etat.courant = math.max(0, math.min(maximum,
            math.floor((tonumber(etat.courant) or ancien) * maximum / ancien + 0.5)))
        source.etat.version = 2
    end
    local element = ConstruireObjet(source)
    element.ic = LCM.IC.Lire(source.ic)
    -- Un outil peut CONTENIR un consommable ou une ressource (le MJ,
    -- 23 octobre 2026, Core/Contenants.lua). Les autres objets non.
    if type(source) == "table" and source.contenant ~= nil then
        if element.categorie ~= "outil" then
            error("LCM/Objets : " .. element.id .. " : seul un outil peut être un contenant", 0)
        end
        element.contenant = LCM.Contenants.Lire(source, element.id, function(message)
            error("LCM/Objets : " .. tostring(message), 0)
        end)
    end
    if type(source) == "table" and type(source.etat) == "table" and type(element.etat) == "table" then
        element.etat.version = source.etat.version
        element.etat.ancienMax = source ~= definition and ancien or source.etat.ancienMax
    end
    return element
end

-- Les noms que le reste de l'addon connaissait deja.
Objets.Icone = LCM.Icone
Objets.Emplacements = Objets.Capacite
Objets.EstEquipe = Objets.Porte
Objets.Equipes = Objets.Portes

-- Un objet BRISE : son etat est tombe a zero et il a survecu (il lui restait
-- une vie, ou il en a d'illimitees). Il reste porte, n'apporte plus rien, et
-- redevient normal des qu'on le repare au-dessus de zero.
--
-- On le DEDUIT de l'etat au lieu de le ranger quelque part : un drapeau de plus
-- serait un drapeau a tenir a jour, et il finirait par mentir apres une
-- reparation faite ailleurs.
--
-- `exemplaire` : CET objet-la (voir « Etat des objets »). Sans lui, on parle
-- d'un exemplaire neuf.
function Objets.EstBrise(entity, objet, exemplaire)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    if not objet then return false end
    local maximum = Objets.EtatMax(objet)
    if not maximum or maximum <= 0 then return false end
    return (maximum - Objets.Usure(entity, objet.id, exemplaire)) <= 0
end

-- ===== Ce qu'un objet apporte encore =======================================
-- Un objet abime donne moins. Il a perdu 20 % de son etat : il apporte 20 % de
-- moins (9 octobre 2026). Une armure en loques ne protege pas comme une neuve,
-- et cela rend la reparation utile avant la rupture, pas seulement apres.
--
-- ARRONDI AU SUPERIEUR, et sur la VALEUR ABSOLUE : « +5 » a 70 % d'etat donne
-- 3,5, donc 4. Un malus suit la meme pente — « -4 » devient « -3 » — sinon un
-- objet qui penalise deviendrait meilleur en s'abimant.
--
-- Brise (zero d'etat) : il n'apporte plus rien. Il reste porte, et la case
-- qu'il occupe ne donne rien tant qu'on ne l'a pas repare.
function Objets.ApportSelonEtat(entity, objet, montant, exemplaire)
    montant = tonumber(montant) or 0
    if montant == 0 then return 0 end
    local maximum = Objets.EtatMax(objet)
    if not maximum or maximum <= 0 then return montant end
    local reste = math.max(0, maximum - Objets.Usure(entity, objet.id, exemplaire))
    if reste >= maximum then return montant end
    if reste <= 0 then return 0 end
    local brut = math.abs(montant) * reste / maximum
    local garde = math.ceil(brut - 1e-9)
    return montant < 0 and -garde or garde
end

-- ===== Equiper depuis les sacs =============================================
-- `Placer` et `Enlever` (le catalogue) restent les gestes bruts, sans sac :
-- ils servent aux regles et aux PNJ que le MJ habille. Les fenetres passent
-- par `Equiper` et `Desequiper`.

local function Ref(id) return "objets/" .. tostring(id) end

local function EquipesPourEcrire(entity, categorie)
    entity.exemplairesEquipes = entity.exemplairesEquipes or {}
    local liste = entity.exemplairesEquipes[categorie] or {}
    entity.exemplairesEquipes[categorie] = liste
    for i, id in ipairs(Objets.Ids(entity, categorie)) do
        if not liste[i] then liste[i] = LCM.Exemplaires.Nouveau(Ref(id)) end
    end
    return liste
end

function Objets.PreparerExemplaireEquipe(entity, id, rang)
    local objet = Objets.Get(id)
    if not objet then return nil end
    local ids = Objets.Ids(entity, objet.categorie)
    local liste = EquipesPourEcrire(entity, objet.categorie)
    if rang then return ids[rang] == id and liste[rang] or nil end
    for i = #ids, 1, -1 do if ids[i] == id then return liste[i] end end
end

local PlacerModele = Objets.Placer
function Objets.Placer(entity, id, exemplaire)
    local objet = Objets.Get(id)
    if objet and objet.categorie == "outil" and LCM.Lanterne
        and LCM.Lanterne.IdEquipe(entity)
        and Objets.Occupation(entity, "outil") + 1 >= Objets.Capacite("outil") then
        return false, "la ceinture est pleine : retire un outil ou la lanterne d'abord."
    end
    if exemplaire then
        local _, raison = LCM.Exemplaires.Lire(Ref(id), 1, {exemplaire})
        if raison then return false, raison end
    end
    local ok, raison = PlacerModele(entity, id)
    if not ok then return false, raison end
    local liste = EquipesPourEcrire(entity, objet.categorie)
    if exemplaire then liste[#Objets.Ids(entity, objet.categorie)] = LCM.Copie(exemplaire) end
    return true
end

function Objets.Enlever(entity, id, exemplaireId)
    for categorie, rangee in pairs(type(entity) == "table" and entity.equipement or {}) do
        for i = #rangee, 1, -1 do
            if rangee[i] == tostring(id) then
                local liste = EquipesPourEcrire(entity, categorie)
                local exemplaire = liste[i]
                if not exemplaireId or exemplaire.id == exemplaireId then
                table.remove(rangee, i)
                if #rangee == 0 then entity.equipement[categorie] = nil end
                if not next(entity.equipement) then entity.equipement = nil end
                table.remove(liste, i)
                if #liste == 0 then entity.exemplairesEquipes[categorie] = nil end
                if not next(entity.exemplairesEquipes) then entity.exemplairesEquipes = nil end
                return true, exemplaire
                end
            end
        end
    end
    return false
end

function Objets.Possede(entity, id)
    return LCM.Inventaire.Chercher(entity, Ref(id)) ~= nil
end

function Objets.Equiper(entity, id)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    local objet = Objets.Get(id)
    if not objet then return false, "objet inconnu." end
    if not Objets.Possede(entity, objet.id) then
        return false, string.format("%s n'est dans aucun sac : on n'équipe que ce qu'on porte sur soi.", objet.label)
    end
    -- La place sur soi d'abord : si elle manque, l'objet reste dans son sac.
    local cat, index, case = LCM.Inventaire.Chercher(entity, Ref(objet.id))
    local contenu = LCM.Inventaire.Case(LCM.Inventaire.Emplacement(entity, cat, index), case)
    local exemplaire = LCM.Exemplaires.Assurer(contenu)[1]
    local ok, raison = Objets.Placer(entity, objet.id, exemplaire)
    if not ok then return false, raison end
    LCM.Inventaire.Prendre(entity, Ref(objet.id))
    return true
end

-- Remet l'objet dans un sac. Sans place libre, il reste porte : on ne le
-- fait pas disparaitre faute de sac.
function Objets.Desequiper(entity, id, rang)
    if not Objets.Porte(entity, id) then return false, "cet objet n'est pas équipé." end
    local objet = Objets.Get(id)
    if not objet then
        return false, string.format("« %s » n'existe pas dans cette version : il reste équipé.", tostring(id))
    end
    local exemplaire = Objets.PreparerExemplaireEquipe(entity, id, rang)
    if not exemplaire then return false, "cet exemplaire n'est plus équipé." end
    local ok, raison = LCM.Inventaire.Deposer(entity, Ref(objet.id), 1, {exemplaire})
    if not ok then
        return false, string.format("%s reste équipé : %s", objet.label, raison == "aucune place libre."
            and "aucune place libre dans les sacs." or tostring(raison))
    end
    Objets.Enlever(entity, objet.id, exemplaire.id)
    return true
end

-- Ce que la fenetre propose : les objets de cette categorie qui sont dans les
-- sacs, une fois chacun, sauf ceux deja portes.
function Objets.CandidatsPossedes(entity, categorieId)
    local out, vus = {}, {}
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local emplacement = LCM.Inventaire.Emplacement(entity, categorie.id, index)
            for _, c in pairs(emplacement and type(emplacement.cases) == "table" and emplacement.cases or {}) do
                local id = type(c) == "table" and tostring(c.ref or ""):match("^objets/(.+)$")
                local objet = id and Objets.Get(id)
                if objet and objet.categorie == categorieId and not vus[objet.id] and not Objets.Porte(entity, objet.id) then
                    vus[objet.id] = true
                    out[#out + 1] = objet
                end
            end
        end
    end
    return out
end

-- ===== Etat des objets =====================================================
-- Toute arme, armure, accessoire ou outil possede son propre etat. La valeur
-- maximale vient de la jauge `etat` definie par la Forge ; une ancienne entree
-- qui n'en a pas encore recu part du defaut d'equilibrage.
--
-- L'etat est celui de L'EXEMPLAIRE, pas du modele (20 octobre 2026) : il vit
-- sur lui (Core/Exemplaires.lua, `usure` et `viesPerdues`) et le suit partout
-- — d'un sac a l'autre, sur soi, dans un coffre, dans un echange. Six kits de
-- crochetage, sept capuches identiques : chacun s'use, se brise et se detruit
-- seul, et un objet detruit emporte son etat avec lui.
--
-- Avant, il etait range sur le personnage, au nom du modele :
--
--     entity.usureArmure = { kit_de_crochetage = 7 }   entity.viesObjet = { … }
--
-- Tous les exemplaires partageaient donc un compteur, et « Détruire » ne
-- l'effacait pas : le kit suivant heritait de l'usure et des vies perdues du
-- precedent. Ces tables ne servent plus qu'a lire une fiche qui ne les a pas
-- encore quittees (Objets.MigrerEtats), celle d'un joueur dont l'addon n'est
-- pas a jour par exemple, recue par le reseau.

local CATEGORIE_ARMURE = "equipement"

function Objets.Armure(objet)
    return type(objet) == "table" and math.max(0, math.floor(tonumber(objet.armure) or 0)) or 0
end

function Objets.EtatMax(objet)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    local maximum = objet and type(objet.etat) == "table" and tonumber(objet.etat.max) or nil
    maximum = maximum or (LCM.Equilibrage.forge.etatObjet and LCM.Equilibrage.forge.etatObjet.base) or 10
    return math.max(0, math.floor(tonumber(maximum) or 0))
end

-- ===== Les vies d'un objet =================================================
-- Voir Data/Equilibrage.lua : la rarete (couleur du titre) dit combien de fois
-- un objet peut tomber a zero d'etat avant d'etre detruit.

-- Le reglage de sa rarete, ou le defaut si sa couleur n'en declare aucune.
local function Rarete(objet)
    local table_ = (LCM.Equilibrage and LCM.Equilibrage.viesParRarete) or {}
    local couleur = type(objet) == "table" and tostring(objet.couleurTitre or ""):upper() or ""
    return table_[couleur]
end

-- Combien de vies un objet a au depart. nil = illimitees.
function Objets.ViesMax(objet)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    if not objet then return 0 end
    local r = Rarete(objet)
    if r then
        if r.illimitees then return nil end
        return math.max(0, math.floor(tonumber(r.vies) or 0))
    end
    return math.max(0, math.floor(tonumber(
        LCM.Equilibrage and LCM.Equilibrage.viesParDefaut or 0) or 0))
end

function Objets.ViesIllimitees(objet)
    return Objets.ViesMax(objet) == nil
end

-- ===== Lire l'etat d'un exemplaire =========================================

-- Ce que l'ancien rangement retient pour ce modele, ou nil s'il n'en dit rien.
local function Ancien(entity, cle, id)
    local t = type(entity) == "table" and entity[cle]
    if type(t) ~= "table" or t[tostring(id)] == nil then return nil end
    local valeur = t[tostring(id)]
    return math.max(0, math.floor(tonumber(valeur) or 0))
end

local function Compte(exemplaire, cle)
    return type(exemplaire) == "table" and math.max(0, math.floor(tonumber(exemplaire[cle]) or 0)) or 0
end

-- Ce que cet exemplaire a perdu d'etat. Lecture seule : rien n'est ecrit ici,
-- pas meme la conversion d'un ancien bareme (elle se fait a la migration).
function Objets.Usure(entity, id, exemplaire)
    id = tostring(id)
    local ancien = Ancien(entity, "usureArmure", id)
    if ancien then
        local objet = Objets.Get(id)
        local avant = objet and type(objet.etat) == "table" and objet.etat.ancienMax
        if ancien > 0 and avant and avant > 0
            and not (type(entity.usureArmureMigree) == "table" and entity.usureArmureMigree[id]) then
            ancien = math.min(Objets.EtatMax(objet), math.floor(ancien * Objets.EtatMax(objet) / avant + 0.5))
        end
        return ancien
    end
    return Compte(exemplaire, "usure")
end

-- Combien de vies cet exemplaire a DEJA perdues.
function Objets.ViesPerdues(entity, id, exemplaire)
    return Ancien(entity, "viesObjet", id) or Compte(exemplaire, "viesPerdues")
end

-- Ce qu'il lui reste, et son maximum. `nil, nil` pour les illimitees.
function Objets.Vies(entity, objet, exemplaire)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    if not objet then return 0, 0 end
    local maximum = Objets.ViesMax(objet)
    if maximum == nil then return nil, nil end
    return math.max(0, maximum - Objets.ViesPerdues(entity, objet.id, exemplaire)), maximum
end

-- ===== Quel exemplaire =====================================================

-- L'exemplaire porte a ce rang de cette categorie. Lecture seule : un objet
-- pose avant les exemplaires n'en a pas, et il est neuf.
function Objets.ExemplairePorte(entity, categorie, rang)
    local t = type(entity) == "table" and entity.exemplairesEquipes
    local liste = type(t) == "table" and t[categorie]
    return type(liste) == "table" and liste[rang] or nil
end

-- Le n-ieme objet porte, toutes categories confondues, dans l'ordre ou les
-- effets les parcourent (C.Portes) : sa categorie et son rang.
local function PorteAuRang(entity, n)
    n = tonumber(n)
    if not n then return nil end
    for _, categorie in ipairs(Objets.CATEGORIES) do
        local ids = Objets.Ids(entity, categorie.id)
        local compte = 0
        for _, id in ipairs(ids) do if Objets.Get(id) then compte = compte + 1 end end
        if n <= compte then
            local vus = 0
            for rang, id in ipairs(ids) do
                if Objets.Get(id) then
                    vus = vus + 1
                    if vus == n then return categorie.id, rang end
                end
            end
        end
        n = n - compte
    end
end

function Objets.ExemplaireAuRangPorte(entity, n)
    local categorie, rang = PorteAuRang(entity, n)
    return categorie and Objets.ExemplairePorte(entity, categorie, rang) or nil
end

-- Le PLUS ENTAME d'une liste d'exemplaires : c'est lui qui sert le premier
-- (20 octobre 2026). On finit un kit avant d'en ouvrir un neuf, au lieu d'user
-- toute la pile d'un cran. A usure egale, le premier de la liste.
-- `utilisable` : les brises sont ecartes, ils n'ont plus rien a donner.
-- Rend l'indice dans la liste, ou nil.
local function PlusEntame(objet, liste, utilisable)
    local maximum = Objets.EtatMax(objet)
    local choisi, pire
    for i = 1, #liste do
        local u = Compte(liste[i], "usure")
        local brise = maximum > 0 and u >= maximum
        if not (utilisable and brise) and (not pire or u > pire) then choisi, pire = i, u end
    end
    return choisi
end

local function LePremierAServir(objet, liste)
    return PlusEntame(objet, liste, true) or PlusEntame(objet, liste, false)
end

-- Ce que montre une pile : l'exemplaire qui servira le premier. Une pile
-- d'avant les exemplaires n'en a pas : nil, elle est neuve.
function Objets.ExemplaireDePile(pile)
    local liste = type(pile) == "table" and type(pile.exemplaires) == "table" and pile.exemplaires
    if not liste or #liste == 0 then return nil end
    local objet = Objets.Get(tostring(pile.ref or ""):match("^objets/(.+)$") or "")
    if not objet then return liste[1] end
    return liste[LePremierAServir(objet, liste)]
end

-- Parmi ceux qu'on PORTE de ce modele, le rang de celui qui servira le
-- premier. Nil si on n'en porte aucun.
local function RangPorteAServir(entity, objet)
    local rangs, liste = {}, {}
    for rang, id in ipairs(Objets.Ids(entity, objet.categorie)) do
        if id == objet.id then
            rangs[#rangs + 1] = rang
            liste[#liste + 1] = Objets.ExemplairePorte(entity, objet.categorie, rang) or {}
        end
    end
    if #rangs == 0 then return nil end
    return rangs[LePremierAServir(objet, liste)]
end

-- L'exemplaire qu'un outil employerait : celui qu'on porte d'abord, sinon le
-- premier a servir dans les sacs. Lecture seule — pour dire ce qu'il apporte
-- avant de s'en servir.
function Objets.ExemplaireAUser(entity, id)
    local objet = Objets.Get(id)
    if not objet then return nil end
    local rang = RangPorteAServir(entity, objet)
    if rang then return Objets.ExemplairePorte(entity, objet.categorie, rang) end
    local liste = {}
    for _, p in ipairs(LCM.Inventaire.Piles(entity, Ref(objet.id))) do
        local exemplaires = type(p.pile.exemplaires) == "table" and p.pile.exemplaires or {}
        for _, e in ipairs(exemplaires) do liste[#liste + 1] = e end
    end
    local i = LePremierAServir(objet, liste)
    return i and liste[i] or nil
end

-- ===== Reprise de l'ancien rangement =======================================
-- Les compteurs au nom du modele passent sur les exemplaires, une fois, dans
-- un geste d'ecriture (au chargement, ou avant d'user un objet) — jamais dans
-- un accesseur.
--
-- CHAQUE exemplaire possede du modele recoit l'ancien compteur : c'est l'etat
-- que la fiche affichait pour tous, et en donner un neuf a certains serait une
-- reparation gratuite. A partir de la, chacun suit son chemin.
--
-- Un modele inconnu de cette version garde son entree : on n'efface pas ce
-- qu'on ne sait pas relire.
function Objets.MigrerEtats(entity)
    if type(entity) ~= "table" then return end
    local ids = {}
    for _, cle in ipairs({ "usureArmure", "viesObjet" }) do
        for id in pairs(type(entity[cle]) == "table" and entity[cle] or {}) do ids[tostring(id)] = true end
    end
    for id in pairs(ids) do
        local objet = Objets.Get(id)
        if objet then
            local usure = math.min(Objets.EtatMax(objet), Objets.Usure(entity, id))
            local perdues = Ancien(entity, "viesObjet", id) or 0
            local function Poser(e)
                e.usure = usure > 0 and usure or nil
                e.viesPerdues = perdues > 0 and perdues or nil
            end
            for rang, porte in ipairs(Objets.Ids(entity, objet.categorie)) do
                if porte == objet.id then Poser(EquipesPourEcrire(entity, objet.categorie)[rang]) end
            end
            for _, p in ipairs(LCM.Inventaire.Piles(entity, Ref(objet.id))) do
                for _, e in ipairs(LCM.Exemplaires.Assurer(p.pile)) do Poser(e) end
            end
            for _, cle in ipairs({ "usureArmure", "viesObjet", "usureArmureMigree" }) do
                if type(entity[cle]) == "table" then
                    entity[cle][id] = nil
                    if next(entity[cle]) == nil then entity[cle] = nil end
                end
            end
        end
    end
end

LCM.WhenReady(function()
    for _, entity in pairs(type(LCM.db.entities) == "table" and LCM.db.entities or {}) do
        Objets.MigrerEtats(entity)
    end
end)

-- ===== Les objets portes ===================================================

-- Tous les objets portes, dans l'ordre des categories et des emplacements,
-- chacun avec son rang et son exemplaire. `reste` est l'etat actuel.
function Objets.EquipementsEtat(entity)
    local out = {}
    for _, categorie in ipairs(Objets.CATEGORIES) do
        for rang, id in ipairs(Objets.Ids(entity, categorie.id)) do
            local objet = Objets.Get(id)
            if objet then
                local exemplaire = Objets.ExemplairePorte(entity, categorie.id, rang)
                local valeur = Objets.EtatMax(objet)
                local usure = math.min(valeur, Objets.Usure(entity, id, exemplaire))
                out[#out + 1] = { id = objet.id, label = objet.label, categorie = objet.categorie,
                                  objet = objet, rang = rang, exemplaire = exemplaire,
                                  valeur = valeur, usure = usure, reste = valeur - usure }
            end
        end
    end
    return out
end


-- Les armures seulement, pour la jauge « Armure » de la fiche. Sa capacite
-- est maintenant leur etat forge, et non plus la petite statistique `armure`.
function Objets.PiecesArmure(entity)
    local out = {}
    for _, piece in ipairs(Objets.EquipementsEtat(entity)) do
        -- Une piece BRISEE ne protege plus. Depuis que l'etat a zero ne detruit
        -- plus l'objet (il perd une vie et reste porte), une loque restait dans
        -- la jauge et continuait d'encaisser — alors qu'elle n'apporte deja
        -- plus aucune statistique (10 octobre 2026).
        if piece.categorie == CATEGORIE_ARMURE and piece.reste > 0 then
            out[#out + 1] = piece
        end
    end
    return out
end

-- La jauge #armure : { current = encaisse, max = total des pieces portees }.
function Objets.Protection(entity)
    local encaisse, total = 0, 0
    for _, piece in ipairs(Objets.PiecesArmure(entity)) do
        encaisse, total = encaisse + piece.usure, total + piece.valeur
    end
    return { current = encaisse, max = total }
end

-- ===== User un exemplaire ==================================================
-- Un exemplaire encaisse `n` points (negatif : on le repare), borne entre
-- neuf et detruit.
--
-- A zero d'etat il se BRISE : il perd une vie et reste la, reparable. C'est
-- seulement quand il tombe a zero sans vie qu'il est detruit et retire, sans
-- revenir dans le sac (9 octobre 2026 : avant, le premier zero le detruisait,
-- ce qui etait trop dur). Detruit, il part avec son etat : un exemplaire neuf
-- du meme modele repart avec toutes ses vies.
--
-- `apres > avant` garde le compte juste : on ne perd une vie qu'en TOMBANT a
-- zero, pas a chaque coup encaisse une fois qu'on y est.
--
-- Renvoie la variation d'usure, le verdict de destruction, et si une vie vient
-- d'etre perdue.
local function Encaisser(entity, objet, exemplaire, n, detruire)
    local maximum = Objets.EtatMax(objet)
    local avant = Compte(exemplaire, "usure")
    local apres = math.max(0, math.min(maximum, avant + math.floor(tonumber(n) or 0)))
    local aZero = maximum > 0 and apres >= maximum and apres > avant
    local detruit, briseMaintenant = false, false
    if aZero then
        local restantes = Objets.Vies(entity, objet, exemplaire)
        if restantes == nil then
            -- Illimitees : il se brise, on ne compte rien, il n'est jamais
            -- detruit.
            briseMaintenant = true
        elseif restantes > 0 then
            exemplaire.viesPerdues = Compte(exemplaire, "viesPerdues") + 1
            briseMaintenant = true
        else
            detruit = true
        end
    end
    exemplaire.usure = apres > 0 and apres or nil
    if detruit then detruire() end
    return apres - avant, detruit, briseMaintenant
end

-- Un objet PORTE. `rang` dit lequel quand on en porte plusieurs identiques
-- (une piece touchee, une ligne de la fiche) ; sans lui, celui qui sert le
-- premier.
function Objets.Encaisser(entity, id, n, rang)
    local objet = Objets.Get(id)
    if type(entity) ~= "table" or not objet then return 0, false end
    Objets.MigrerEtats(entity)
    local ids = Objets.Ids(entity, objet.categorie)
    if rang then
        if ids[rang] ~= objet.id then return 0, false end
    else
        rang = RangPorteAServir(entity, objet)
        if not rang then return 0, false end
    end
    local exemplaire = EquipesPourEcrire(entity, objet.categorie)[rang]
    return Encaisser(entity, objet, exemplaire, n, function()
        Objets.Enlever(entity, objet.id, exemplaire.id)
    end)
end

-- Un outil employe directement depuis un sac s'use lui aussi. Il n'est pas
-- equipe pour autant et ne quitte le sac que si sa derniere vie est detruite.
-- C'est le plus entame qui sert, ou qu'il soit dans les sacs.
function Objets.UserInventaire(entity, id, n)
    local objet = Objets.Get(id)
    if type(entity) ~= "table" or not objet then return 0, false end
    Objets.MigrerEtats(entity)
    local ref = Ref(objet.id)
    local tous = {}
    for _, p in ipairs(LCM.Inventaire.Piles(entity, ref)) do
        for _, e in ipairs(LCM.Exemplaires.Assurer(p.pile)) do tous[#tous + 1] = e end
    end
    if #tous == 0 then return 0, false end
    local exemplaire = tous[LePremierAServir(objet, tous)]
    return Encaisser(entity, objet, exemplaire, n, function()
        LCM.Inventaire.RetirerExemplaire(entity, ref, exemplaire.id)
    end)
end

-- Porte la jauge a `encaisse` en repartissant l'ecart sur les pieces portees :
-- les coups s'empilent dans l'ordre des emplacements, les reparations
-- commencent par la derniere piece touchee. C'est ce que font les + / - et le
-- R de la fiche ; une attaque, elle, choisit ses pieces (Actions.Zones).
function Objets.PorterProtection(entity, encaisse)
    local pieces = Objets.PiecesArmure(entity)
    local ecart = math.floor(tonumber(encaisse) or 0) - Objets.Protection(entity).current
    if ecart > 0 then
        for i = 1, #pieces do
            if ecart == 0 then break end
            ecart = ecart - Objets.Encaisser(entity, pieces[i].id, math.min(ecart, pieces[i].reste), pieces[i].rang)
        end
    elseif ecart < 0 then
        for i = #pieces, 1, -1 do
            if ecart == 0 then break end
            ecart = ecart - Objets.Encaisser(entity, pieces[i].id, math.max(ecart, -pieces[i].usure), pieces[i].rang)
        end
    end
    return true
end
