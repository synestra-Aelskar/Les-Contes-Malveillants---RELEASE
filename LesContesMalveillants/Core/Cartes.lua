-- Les cartes (31 octobre 2026) : un objet qu'on trouve, qu'on lit, et qui
-- apprend des lieux.
--
-- Une carte est rattachee a une REGION de Crossings (Core/Crossings.lua). Le
-- MJ choisit ce qu'elle devoile : certains lieux de la region (« Bois des
-- Sorcieres ») et des REPERES — une ressource, un vendeur, un coffre poses
-- la, ou une epingle libre (« un PNJ ici »). La lire apprend pour de bon les
-- noms au personnage (la connaissance de Crossings : plus de « ????? ») ; la
-- vue de la carte, elle, se rouvre tant qu'on la possede.
--
-- Pourquoi un objet du compendium, comme les livres, et pas un point
-- d'Interactions : une etude de 100 situations de MJ (31 octobre 2026) l'a
-- donne gagnant. Un objet se trouve deja dans un coffre, se pose deja au sol
-- (coffre « objet ») et s'echange deja ; un point aurait demande en plus un
-- objet qui repete l'information. Une carte peut REPRENDRE le contenu d'une
-- autre (`reprend`) : deux objets, une seule information a tenir a jour.
--
-- La famille est RESERVEE AU MJ (comme les PNJ) : elle ne part jamais dans le
-- contenu livre aux joueurs, ou l'on lirait dans les fichiers ce que cachent
-- toutes les cartes. Un joueur recoit la definition d'une carte en la
-- TROUVANT : elle voyage avec l'objet, comme un livre recu (Importer).
--
-- Les positions des reperes sont dans le repere de Crossings (x vers l'ouest,
-- y vers le nord, voir ZG:GetPlayerPose) : c'est sur sa carte qu'on les pose.
local _, LCM = ...

local MAX_LIEUX, MAX_REPERES, MAX_REGIONS, MAX_PROFONDEUR = 30, 40, 10, 5

-- Ce qu'un repere designe : de quoi choisir son icone et sa legende.
local GENRES = {
    { id = "ressource", label = "Ressource" },
    { id = "vendeur", label = "Vendeur" },
    { id = "coffre", label = "Coffre" },
    { id = "affichage", label = "Panneau" },
    { id = "pnj", label = "PNJ" },
    { id = "libre", label = "Repère" },
}
local GENRE = {}
for _, g in ipairs(GENRES) do GENRE[g.id] = g end

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local Cartes = LCM.Registre({
    nom = "carte", prefixe = "Cartes",
    construire = function(definition, carte, Erreur)
        carte.forge, carte.etat = nil, nil
        carte.pileMax = 1
        -- Une carte qui en reprend une autre n'a pas de contenu a elle : elle
        -- renvoie. La chaine se resout a la lecture (Cartes.Contenu).
        local reprend = Texte(definition.reprend)
        carte.reprend = reprend ~= "" and reprend or nil
        if carte.reprend == carte.id then Erreur(carte.id .. " : une carte ne peut pas se reprendre elle-même") end
        -- Les REGIONS que la carte devoile (une ou plusieurs) : leur nom est
        -- appris a la lecture, et elles figurent sur la carte. Recopiees avec
        -- leur nom : la carte doit se lire meme chez qui n'a pas encore recu
        -- les regions de Crossings. Une ancienne carte a une seule `region`.
        carte.regions = {}
        local vues = {}
        local sources = type(definition.regions) == "table" and definition.regions
            or (Texte(definition.region) ~= "" and { { id = definition.region, nom = definition.regionNom } } or {})
        if #sources > MAX_REGIONS then Erreur(carte.id .. " : " .. MAX_REGIONS .. " régions au plus") end
        for i, r in ipairs(sources) do
            local id = Texte(type(r) == "table" and r.id or r)
            if id == "" then Erreur(carte.id .. " : région " .. i .. " sans identifiant") end
            if not vues[id] then
                vues[id] = true
                carte.regions[#carte.regions + 1] = { id = id, nom = Texte(type(r) == "table" and r.nom or "") }
            end
        end
        -- La premiere region, pour ce qui n'en lit qu'une (anciens appels).
        carte.region = carte.regions[1] and carte.regions[1].id or nil
        -- Une carte au tresor peut n'indiquer que des reperes, eparpilles dans
        -- plusieurs regions (le pirate et ses coffres) : la region principale
        -- n'est alors pas obligatoire. Mais une carte doit montrer QUELQUE chose.
        local nReperes = type(definition.reperes) == "table" and #definition.reperes or 0
        if not carte.reprend and #carte.regions == 0 and nReperes == 0 then
            Erreur(carte.id .. " : coche au moins une région à dévoiler, ou un repère")
        end
        carte.regionNom = carte.regions[1] and carte.regions[1].nom or nil
        carte.lieux = {}
        if type(definition.lieux) == "table" then
            if #definition.lieux > MAX_LIEUX then Erreur(carte.id .. " : " .. MAX_LIEUX .. " lieux au plus") end
            for i, lieu in ipairs(definition.lieux) do
                local id = Texte(type(lieu) == "table" and lieu.id or lieu)
                if id == "" then Erreur(carte.id .. " : lieu " .. i .. " sans identifiant") end
                carte.lieux[i] = { id = id, nom = Texte(type(lieu) == "table" and lieu.nom or "") }
            end
        end
        carte.reperes = {}
        if type(definition.reperes) == "table" then
            if #definition.reperes > MAX_REPERES then
                Erreur(carte.id .. " : " .. MAX_REPERES .. " repères au plus")
            end
            for i, r in ipairs(definition.reperes) do
                if type(r) ~= "table" or not tonumber(r.x) or not tonumber(r.y) then
                    Erreur(carte.id .. " : repère " .. i .. " sans position")
                end
                local genre = GENRE[tostring(r.genre)] and tostring(r.genre) or "libre"
                local label = Texte(r.label)
                if #label > 60 then Erreur(carte.id .. " : repère " .. i .. " : légende trop longue (60)") end
                -- `point` : le point pose dont le repere vient (« coffre:<id> »),
                -- pour que l'editeur le montre coche. Une epingle n'en a pas.
                local point = Texte(r.point)
                -- Ou se trouve le repere (Cartes.Localiser), recopie en clair :
                -- la carte doit dire « Aelskar › Région 5 › Lieu 28 » meme chez
                -- qui n'a pas recu les regions de Crossings.
                local function Court(v) v = Texte(v) return v ~= "" and v:sub(1, 60) or nil end
                carte.reperes[i] = { genre = genre, label = label,
                    x = math.floor(tonumber(r.x) * 10 + 0.5) / 10,
                    y = math.floor(tonumber(r.y) * 10 + 0.5) / 10,
                    z = tonumber(r.z) and math.floor(tonumber(r.z) * 10 + 0.5) / 10 or nil,
                    carte = tonumber(r.carte),
                    region = Court(r.region), regionNom = Court(r.regionNom),
                    lieu = Court(r.lieu), lieuNom = Court(r.lieuNom), paysNom = Court(r.paysNom),
                    point = point ~= "" and #point <= 80 and point or nil }
            end
        end
    end,
})
LCM.Cartes = Cartes
Cartes.GENRES = GENRES
Cartes.Genre = function(id) return GENRE[id] end
Cartes.MAX_LIEUX, Cartes.MAX_REPERES = MAX_LIEUX, MAX_REPERES

-- Le contenu d'une carte, en suivant ce qu'elle reprend. Rend la carte qui
-- PORTE le contenu, ou nil et la raison (chaine trop longue, ou qui boucle,
-- ou carte reprise inconnue).
function Cartes.Contenu(carte)
    local vues = {}
    for _ = 1, MAX_PROFONDEUR do
        if not carte then return nil, "carte reprise introuvable" end
        if vues[carte.id] then return nil, "les cartes se reprennent en boucle" end
        vues[carte.id] = true
        if not carte.reprend then return carte end
        carte = Cartes.Get(carte.reprend)
    end
    return nil, "trop de cartes reprises les unes des autres"
end

function Cartes.Remplacer(definition)
    local neuf = Cartes.Construire(definition)
    local ancien = Cartes.Get(neuf.id)
    if not ancien then return Cartes.Add(definition) end
    for cle in pairs(ancien) do ancien[cle] = nil end
    for cle, valeur in pairs(neuf) do ancien[cle] = valeur end
    return ancien
end

-- La definition qui accompagne l'objet quand il change de mains. Une carte
-- qui en reprend une autre emporte le CONTENU, aplati : celui qui la recoit
-- n'a pas la carte reprise, qui est reservee au MJ.
function Cartes.Definition(ref)
    local id = tostring(ref or ""):match("^cartes/(.+)$")
    local carte = id and Cartes.Get(id)
    if not carte then return nil end
    local copie = LCM.Copie(carte)
    local contenu = Cartes.Contenu(carte)
    if carte.reprend and contenu then
        copie.reprend = nil
        copie.regions = LCM.Copie(contenu.regions)
        copie.region, copie.regionNom = nil, nil
        copie.lieux, copie.reperes = LCM.Copie(contenu.lieux), LCM.Copie(contenu.reperes)
    end
    return copie
end

-- Une carte trouvee arrive avec sa definition, gardee apres /reload.
function Cartes.Importer(ref, definition)
    local id = tostring(ref or ""):match("^cartes/(.+)$")
    if not id or type(definition) ~= "table" or tostring(definition.id or "") ~= id then return false end
    local ok = pcall(Cartes.Construire, definition)
    if not ok then return false end
    local ajoute, resultat = pcall(Cartes.Remplacer, definition)
    if not ajoute or not resultat then return false end
    LCM.EnsureDatabase()
    LCM.db.cartesRecues = type(LCM.db.cartesRecues) == "table" and LCM.db.cartesRecues or {}
    LCM.db.cartesRecues[id] = LCM.Copie(definition)
    return true
end

-- ===== Situer un point ======================================================
-- Ou est un point (repere Crossings) : le lieu dont un perimetre ferme le
-- contient, sur la MEME carte quand les deux la connaissent (une carte
-- serveur inconnue ne compte que sur les coordonnees). Rend
-- { region, regionNom, lieu, lieuNom, paysNom } ou nil.
local function DansPolygone(points, x, y)
    local dedans, j = false, #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then dedans = not dedans end
        j = i
    end
    return dedans
end

function Cartes.Localiser(x, y, carteServeur)
    local ZG = LCM.Crossings
    if not (ZG and tonumber(x) and tonumber(y)) then return nil end
    for _, zone in ipairs(ZG:GetZoneList()) do
        for _, sub in pairs(zone.subZones or {}) do
            local memeCarte = not carteServeur or not sub.mapID or tonumber(sub.mapID) == tonumber(carteServeur)
            if memeCarte and sub.shape == "polygon" and sub.regionReady and sub.points and #sub.points >= 3
                and DansPolygone(sub.points, x, y) then
                local place = sub.enterPlace and ZG:FindPlace(sub.enterPlace)
                local pays = zone.countryId and ZG:GetCountry(zone.countryId)
                return { region = zone.id, regionNom = zone.name or "",
                    lieu = place and place.id or nil, lieuNom = place and place.name or nil,
                    paysNom = pays and pays.name or nil }
            end
        end
    end
    return nil
end

-- « Aelskar › Région 5 › Lieu 28 » : l'emplacement d'un repere, en clair.
function Cartes.Emplacement(r)
    local morceaux = {}
    for _, v in ipairs({ r.paysNom, r.regionNom, r.lieuNom }) do
        if v and v ~= "" then morceaux[#morceaux + 1] = v end
    end
    return #morceaux > 0 and table.concat(morceaux, " › ") or "emplacement inconnu"
end

-- L'emplacement d'un repere tel que le LECTEUR le voit : ce que la carte ne
-- devoile pas reste masque. Le pays ne se dit que si la region se dit.
function Cartes.EmplacementVu(r, vue)
    local ZG = LCM.Crossings
    local function Masque(nom) return ZG and ZG.MaskText and ZG:MaskText(nom or "") or "?????" end
    local regionVue = r.region and vue.regions[r.region]
    local lieuVu = r.lieu and vue.lieux[r.lieu]
    local morceaux = {}
    if regionVue and r.paysNom then morceaux[#morceaux + 1] = r.paysNom end
    if r.regionNom then morceaux[#morceaux + 1] = regionVue and r.regionNom or Masque(r.regionNom) end
    if r.lieuNom then morceaux[#morceaux + 1] = lieuVu and r.lieuNom or Masque(r.lieuNom) end
    return #morceaux > 0 and table.concat(morceaux, " › ") or "emplacement inconnu"
end

-- ===== La lecture ===========================================================

-- Ce que montre une carte, pret pour la vue : la region, les lieux devoiles
-- (avec leur nom), les reperes. `definition` : une copie de travail, pour
-- l'apercu de l'editeur ; sinon la carte `ref`.
function Cartes.Vue(ref, definition)
    local carte = definition
    if carte then
        local ok, construite = pcall(Cartes.Construire, carte)
        if not ok then return nil, tostring(construite) end
        carte = construite
        if carte.reprend then
            local reprise = Cartes.Get(carte.reprend)
            if not reprise then return nil, "carte reprise introuvable" end
            local contenu, raison = Cartes.Contenu(reprise)
            if not contenu then return nil, raison end
            carte = { id = carte.id, label = carte.label, regions = contenu.regions,
                lieux = contenu.lieux, reperes = contenu.reperes }
        end
    else
        local id = tostring(ref or ""):match("^cartes/(.+)$")
        local brute = id and Cartes.Get(id)
        if not brute then return nil, "carte inconnue" end
        local contenu, raison = Cartes.Contenu(brute)
        if not contenu then return nil, raison end
        carte = { id = brute.id, label = brute.label, regions = contenu.regions,
            lieux = contenu.lieux, reperes = contenu.reperes }
    end
    local ZG = LCM.Crossings
    -- Deux choses DIFFERENTES (le MJ, 31 octobre 2026) :
    --   * ce que la carte DEVOILE (les regions cochees) : nomme, et appris a
    --     la lecture ;
    --   * ce qu'elle DESSINE : les regions devoilees, plus celles ou elle pose
    --     un repere — ces dernieres sans leur nom (« ????? »), pour dire
    --     « c'est par la » sans dire ou.
    local regions, dans, noms = {}, {}, {}
    for _, r in ipairs(carte.regions or {}) do
        local zone = ZG and ZG:GetZone(r.id)
        local nom = (zone and zone.name) or r.nom or ""
        regions[#regions + 1] = { id = r.id, nom = nom }
        dans[r.id] = true
        if nom ~= "" then noms[#noms + 1] = nom end
    end
    local dessinees, vuesD = {}, {}
    local function Dessiner(id)
        if id and not vuesD[id] then vuesD[id] = true dessinees[#dessinees + 1] = id end
    end
    for _, r in ipairs(regions) do Dessiner(r.id) end
    for _, r in ipairs(carte.reperes or {}) do Dessiner(r.region) end
    local vue = { titre = carte.label or "Carte", regions = dans, ordreRegions = regions,
        dessinees = dessinees, region = dessinees[1], regionNom = table.concat(noms, ", "),
        lieux = {}, ordre = {}, reperes = carte.reperes or {}, ailleurs = {} }
    for _, lieu in ipairs(carte.lieux or {}) do
        local place = ZG and ZG:FindPlace(lieu.id)
        vue.lieux[lieu.id] = true
        vue.ordre[#vue.ordre + 1] = { id = lieu.id, nom = (place and place.name) or lieu.nom or "" }
    end
    return vue
end

-- Lire une carte : les noms sont appris pour de bon, puis la vue s'ouvre.
-- Rend la vue et la liste des noms NOUVELLEMENT appris. `definition` : une
-- carte qu'on lit SANS la posseder — affichee sur un panneau, elle arrive avec
-- le panneau et n'entre pas dans le registre du joueur.
function Cartes.Lire(ref, definition)
    local vue, raison = Cartes.Vue(ref, definition)
    if not vue then return nil, raison end
    local ZG = LCM.Crossings
    local appris = {}
    if ZG then
        for _, r in ipairs(vue.ordreRegions) do
            if not ZG:HasLearnedZoneName(r.id) then
                ZG:MarkLearnedZoneName(r.id)
                if r.nom ~= "" then appris[#appris + 1] = r.nom end
            end
        end
        for _, lieu in ipairs(vue.ordre) do
            if not ZG:HasLearnedSubZoneName(lieu.id) then
                ZG:MarkLearnedSubZoneName(lieu.id)
                if lieu.nom ~= "" then appris[#appris + 1] = lieu.nom end
            end
        end
    end
    return vue, appris
end

LCM.WhenReady(function()
    local db = LCM.EnsureDatabase()
    for id, definition in pairs(type(db.cartesRecues) == "table" and db.cartesRecues or {}) do
        if tostring(definition.id or "") == tostring(id) then
            local ok = pcall(Cartes.Remplacer, definition)
            if not ok then LCM.Erreur("carte reçue illisible : " .. tostring(id)) end
        end
    end
end)

-- ===== Les objets lisibles ==================================================
-- Livres et cartes voyagent pareil : leur definition accompagne l'objet
-- (coffre, recolte, echange, sol), et celui qui le recoit l'importe. Un seul
-- aiguillage plutot qu'un « si c'est un livre » repete a chaque endroit.
LCM.Lisibles = LCM.Lisibles or {}
local Lisibles = LCM.Lisibles
local FAMILLES = { livres = "Livres", cartes = "Cartes" }

function Lisibles.Registre(ref)
    local famille = tostring(ref or ""):match("^(%a+)/")
    local nom = famille and FAMILLES[famille]
    return nom and LCM[nom] or nil
end
function Lisibles.Definition(ref)
    local registre = Lisibles.Registre(ref)
    return registre and registre.Definition and registre.Definition(ref) or nil
end
function Lisibles.Importer(ref, definition)
    local registre = Lisibles.Registre(ref)
    return registre and registre.Importer and registre.Importer(ref, definition) or false
end
