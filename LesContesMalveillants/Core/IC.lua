-- Le catalogue est du code partage ; seuls les choix du MJ voyagent avec
-- l'objet. Aucun compteur d'utilisation ni code executable dans ces choix.
local _, LCM = ...
local IC = { catalogue = {}, ordre = {}, categories = {}, effets = {} }
LCM.IC = IC
local function Eq() return LCM.Equilibrage.ic end
local function Nombre(n) return type(n) == "number" and n == n and n < math.huge and n >= 0 end
local function Entier(n) return Nombre(n) and n == math.floor(n) end
local function Donnees(v, vus, profondeur)
    local t = type(v)
    if t == "number" then return v == v and v > -math.huge and v < math.huge end
    if t == "string" or t == "boolean" or t == "nil" then return true end
    if t ~= "table" or vus[v] or profondeur > 16 then return false end
    vus[v] = true
    for k,x in pairs(v) do
        if (type(k) ~= "string" and type(k) ~= "number") or not Donnees(x,vus,profondeur+1) then return false end
    end
    vus[v] = nil
    return true
end
local function Egal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k,v in pairs(a) do if not Egal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local TYPES = { actif=true, passif=true, conditionnel=true }
local FREQUENCES = { heures24=true, combat=true, tour=true, permanent=true, sans_limite=true }
local DUREES = { instantanee=true, rounds=true, tours=true, combat=true, permanente=true }
local function Temps(v, frequences)
    if v == nil then return true end
    if type(v) ~= "table" then return false end
    if frequences then
        return FREQUENCES[v.type] and (v.type == "permanent" or v.type == "sans_limite" or (Entier(v.nombre) and v.nombre > 0))
    end
    return DUREES[v.type] and ((v.type ~= "tours" and v.type ~= "rounds") or (Entier(v.nombre) and v.nombre > 0))
end

function IC.Palier(rarete)
    if not rarete then return nil end
    -- Reprise uniquement des identifiants historiques, jamais de la couleur
    -- ou du libelle personnalisable. Les jeux nouveaux enregistrent ce choix.
    return rarete.palierIC or Eq().anciens[rarete.id]
end
function IC.Options()
    local out = {}
    for _,id in ipairs(Eq().ordre) do
        local r = Eq().paliers[id]
        out[#out+1] = { id=id, label=r.label .. " — " .. r.pool .. " IC" }
    end
    return out
end
function IC.Pool(palier) return Eq().paliers[palier] and Eq().paliers[palier].pool or nil end
function IC.Nouveau(palier) return { version=1, palier=palier, convertis=0, proprietes={} } end

-- Validation de forme seulement au chargement : un catalogue plus ancien ne
-- doit ni effacer une propriete recue, ni empecher de posseder l'objet.
function IC.Lire(v)
    if v == nil then return nil end
    assert(type(v)=="table", "données IC invalides")
    assert(Donnees(v,{},0), "les IC ne peuvent contenir que des données sérialisables")
    v=LCM.Copie(v)
    v.version, v.convertis=tonumber(v.version), tonumber(v.convertis)
    assert(v.version==1, "version IC inconnue")
    assert(IC.Pool(v.palier) ~= nil, "palier IC inconnu")
    assert(Entier(v.convertis), "nombre d'IC convertis invalide")
    -- Le transport reseau omet les tables vides.
    assert(v.proprietes==nil or type(v.proprietes)=="table", "liste de propriétés IC invalide")
    local vus = {}
    for k,p in pairs(v.proprietes or {}) do
        assert(Entier(k) and k>=1 and k<=#v.proprietes, "liste IC discontinue")
        assert(type(p)=="table" and type(p.id)=="string" and p.id~="" and not vus[p.id], "identifiant IC invalide ou répété")
        p.version,p.cout=tonumber(p.version),tonumber(p.cout)
        for _,champ in ipairs({"frequence","duree"}) do
            if type(p[champ])=="table" and p[champ].nombre~=nil then p[champ].nombre=tonumber(p[champ].nombre) end
        end
        assert(Entier(p.version) and p.version>0 and Nombre(p.cout), "version ou coût IC invalide")
        assert(Temps(p.frequence,true) and Temps(p.duree,false), "fréquence ou durée IC invalide")
        assert(p.parametres==nil or type(p.parametres)=="table", "paramètres IC invalides")
        vus[p.id]=true
    end
    local copie=LCM.Copie(v)
    copie.proprietes=copie.proprietes or {}
    return copie
end
function IC.Bilan(v, palier)
    local total = IC.Pool(palier or (v and v.palier)) or 0
    local depenses = 0
    for _,p in ipairs(v and v.proprietes or {}) do depenses=depenses+p.cout end
    local convertis = v and v.convertis or 0
    return { total=total, depenses=depenses, convertis=convertis,
        restants=total-depenses-convertis, forge=convertis*Eq().conversion }
end

-- Aucune propriete livree a cette etape. Ces declarations seront ajoutees
-- dans Data/IC.lua ; les joueurs ne composent pas leurs propres effets.
function IC.Declarer(d)
    assert(type(d)=="table" and type(d.id)=="string" and d.id~="" and not IC.catalogue[d.id], "identifiant de propriété IC invalide")
    assert(type(d.nom)=="string" and type(d.description)=="string" and type(d.categorie)=="string", "description IC incomplète")
    assert(TYPES[d.type] and Entier(d.version) and d.version>0 and Nombre(d.coutBase), "type, version ou coût IC invalide")
    assert(Temps(d.frequence,true) and Temps(d.duree,false), "fréquence ou durée IC invalide")
    assert(not d.instantane or d.duree==nil or d.duree.type=="instantanee", "un effet instantané ne peut avoir de durée temporaire")
    IC.catalogue[d.id]=LCM.Copie(d); IC.ordre[#IC.ordre+1]=d.id
    IC.categories[d.categorie]=true
end
function IC.Disponible(p)
    local d=IC.catalogue[p.id]
    return d and not d.desactive and d.version==p.version and d or nil
end
function IC.Cout(d, choix)
    -- Aucun bareme implicite de frequence/duree : une combinaison non
    -- declaree est refusee, pas offerte gratuitement.
    local function Supplement(v, bareme)
        if v==nil then return 0 end
        local cle=v.type .. (v.nombre and (":"..v.nombre) or "")
        return bareme and bareme[cle]
    end
    if not Temps(choix.frequence,true) or not Temps(choix.duree,false) then
        return nil,"fréquence ou durée IC invalide"
    end
    local commun = d.baremeCommun and Eq() or nil
    local f=Supplement(choix.frequence,d.coutsFrequence or (commun and commun.coutsFrequence))
    local t=Supplement(choix.duree,d.coutsDuree or (commun and commun.coutsDuree))
    if f==nil or t==nil then return nil,"fréquence ou durée sans barème IC" end
    if d.instantane and choix.duree and choix.duree.type~="instantanee" then
        return nil,"durée incompatible avec un effet instantané"
    end
    local declencheur = choix.declencheur
    local supplement = 0
    if declencheur ~= nil then
        if type(declencheur) ~= "string" then return nil,"déclencheur IC invalide" end
        local bareme = d.coutsDeclencheur or (commun and commun.coutsDeclencheur)
        supplement = bareme and bareme[declencheur]
        if supplement == nil then return nil,"déclencheur sans barème IC" end
        if d.declencheursInclus and d.declencheursInclus[declencheur] then supplement = 0 end
    end
    local total = d.coutBase+f+t+supplement
    return commun and math.max(commun.coutMinimum,total) or total
end
function IC.Verifier(v, precedent, rarete, reception)
    local ok,raison=pcall(IC.Lire,v)
    if not ok then return false,tostring(raison) end
    v=raison
    if (v and v.convertis or 0)<(precedent and precedent.convertis or 0) then
        return false,"les IC déjà convertis ne peuvent pas être récupérés"
    end
    if not v then return true end
    if not rarete and not Egal(v,precedent) then return false,"choisis un jeu et une rareté pour modifier les IC" end
    if rarete and not IC.Palier(rarete) then return false,"choisis un palier IC pour cette rareté" end
    local palier=rarete and IC.Palier(rarete) or v.palier
    if palier~=v.palier then return false,"le palier IC ne correspond pas à la rareté du jeu" end
    if IC.Bilan(v).restants<0 then return false,"le budget IC de cette rareté est dépassé" end
    local anciens={}
    for _,p in ipairs(precedent and precedent.proprietes or {}) do anciens[p.id]=p end
    for _,p in ipairs(v.proprietes or {}) do
        -- Une definition recue conserve le cout arrete chez son auteur,
        -- meme si nos versions du catalogue different. Le budget et le
        -- plancher de conversion restent verifies ci-dessus.
        if not Egal(p,anciens[p.id]) and not reception then
            local d=IC.Disponible(p)
            if not d then return false,"propriété IC indisponible : "..p.id end
            if d then
                -- Les futurs modules fournissent leurs validations specifiques,
                -- notamment restrictions d'equipement/cible et parametres permis.
                if not d.valider then return false,"propriété IC pas encore disponible à la forge : "..p.id end
                local valide,msg=d.valider(p)
                if not valide then return false,msg end
                if d.instantane and p.duree and p.duree.type~="instantanee" then return false,"durée incompatible avec un effet instantané" end
                local cout,msgCout=IC.Cout(d,p)
                if not cout or p.cout~=cout then return false,msgCout or "coût IC incorrect" end
            end
        end
    end
    return true
end
function IC.Description(v)
    local out={}
    for _,p in ipairs(v and v.proprietes or {}) do
        local d=IC.Disponible(p)
        out[#out+1]=(d and d.nom or p.nom or p.id).." ("..p.cout.." IC)"..(d and "" or " — indisponible")
        local texte=d and d.description or p.description
        if texte and texte~="" then out[#out+1]=texte end
    end
    return table.concat(out,"\n")
end

function IC.Selection(id)
    local d=IC.catalogue[id]
    if not d or d.desactive or not d.valider then return nil,"propriété indisponible" end
    local p={id=d.id,version=d.version,nom=d.nom,description=d.description,
        frequence=LCM.Copie(d.frequence),duree=LCM.Copie(d.duree),parametres=LCM.Copie(d.parametres)}
    local cout,raison=IC.Cout(d,p)
    if not cout then return nil,raison end
    p.cout=cout
    return p
end

-- Contrat reserve aux prochaines etapes : handlers indexes par identifiant
-- d'effet et evenements metier. Pas d'abonnement ni d'execution pour l'instant.
IC.EVENEMENTS = { "avant_jet", "apres_jet", "avant_degats", "apres_degats",
    "critique", "esquive", "jauge_modifiee", "debut_tour", "fin_tour", "debut_combat", "fin_combat" }
