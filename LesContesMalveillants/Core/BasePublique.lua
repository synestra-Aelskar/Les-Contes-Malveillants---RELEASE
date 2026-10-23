-- Synchronisation du contenu PUBLIC entre addons WoW. La base commune (le
-- service de synchro, son Sheet, les fichiers qu'il engendre) fait la loi ;
-- un maitre du jeu connecte en est la voix. Les joueurs ne recoivent que ce
-- qui leur est destine : une entree `distributionMJ` ne part jamais, et un
-- trait ne se montre qu'a celui que le MJ y autorise (Core/Traits.lua).
--
-- Trois chemins, et c'est tout (17 octobre 2026) :
--
--   * EN SEANCE, ce que le MJ enregistre ou supprime part tout de suite chez
--     les joueurs connectes (« base+ », « base- »). Avant, une entree creee en
--     jeu attendait le service, un /reload du MJ et une nouvelle demande du
--     joueur — et quand le service tombait (quota Google), elle n'arrivait
--     jamais ;
--   * A LA CONNEXION, le joueur envoie une EMPREINTE de ce qu'il a, en un
--     message. Un MJ repond par la sienne ; la liste complete ne voyage que si
--     elles different. La liste partait a chaque demande — 29 messages, deux
--     fois (canal et groupe), toutes les 30 secondes par joueur — dans la
--     file d'envoi unique du MJ, qui ne se vidait plus : ni la base, ni les
--     marchands, ni les recoltes n'arrivaient ;
--   * SANS MJ, un TIERS du groupe qui en sait plus recent relaie. Chaque
--     entree retient l'heure serveur ou un MJ l'a confirmee pour la derniere
--     fois ; entre deux relais, la confirmation la plus recente l'emporte,
--     entree par entree. Un relais ne fait jamais la loi : le prochain MJ
--     remplace tout ce qu'il a dit.
local _, LCM = ...

local Base = {}
LCM.BasePublique = Base

local R = LCM.Reseau
local Source = LCM.SourcePublique
local REGISTRES = {
    accessoires_camping = "AccessoiresCamping", apprentissages = "Apprentissages",
    calculateurs = "Calculateurs", connaissances = "Connaissances",
    devises = "Devises", etats = "Etats", informations = "Informations",
    listes = "Listes", objets = "Objets", livres = "Livres", races = "Races",
    ressources = "Ressources", sacs = "Sacs", tentes = "Tentes",
    traits = "Traits", resolutions = "Resolutions",
    lanternes = "Lanternes", cristaux = "Cristaux", consommables = "Consommables",
}
Base.REGISTRES = REGISTRES

-- Le temps laisse aux offres pour arriver apres une demande : un MJ, s'il est
-- la, gagne toujours ; un relais n'est choisi qu'une fois ce delai passe.
Base.ATTENTE_OFFRES = 3
-- Une demande arrive souvent deux fois (canal et groupe) : une seule reponse.
local REPONSE_UNIQUE = 5
-- Une session qui ne recoit plus rien est abandonnee, sans bloquer la suivante.
local SESSION_MUETTE = 30

local session, collecte, horloge
local derniereDemande = -math.huge
local reponses = {}

local function Maintenant() return (GetTime and GetTime()) or 0 end
-- L'heure serveur : la meme pour tous les clients, contrairement a GetTime.
local function Heure() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end

local function Cache()
    LCM.EnsureDatabase()
    LCM.db.basePublique = type(LCM.db.basePublique) == "table" and LCM.db.basePublique or {}
    return LCM.db.basePublique
end

local function Decouper(cle)
    return tostring(cle or ""):match("^([%w_]+)/([%w_.%-]+)$")
end

-- Le registre d'une entree PUBLIQUE, ou nil : c'est ici que se joue ce qui
-- ne doit jamais sortir de chez le MJ.
local function Registre(cle, definition)
    local famille, id = Decouper(cle)
    if not famille or type(definition) ~= "table" or tostring(definition.id) ~= id
        or definition.distributionMJ then return nil end
    if famille == "resolutions" and definition.categorie == "mj" then return nil end
    return REGISTRES[famille] and LCM[REGISTRES[famille]] or nil
end

-- ===== Empreintes ============================================================
-- `Lien.Serialiser` suit l'ordre de `pairs`, qui change d'un client a l'autre :
-- deux copies identiques n'y donneraient pas le meme texte. On trie les cles.
local function Canon(v, out)
    local t = type(v)
    if t == "number" then out[#out + 1] = "n" .. tostring(v) .. ","
    elseif t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then out[#out + 1] = v and "b1" or "b0"
    elseif t == "table" then
        local cles = {}
        for k, valeur in pairs(v) do
            local tk, tv = type(k), type(valeur)
            if (tk == "string" or tk == "number") and tv ~= "function" and tv ~= "userdata"
                and not (tk == "string" and k:sub(1, 2) == "__") then
                cles[#cles + 1] = k
            end
        end
        table.sort(cles, function(a, b)
            if type(a) ~= type(b) then return type(a) == "number" end
            return a < b
        end)
        out[#out + 1] = "t"
        for _, k in ipairs(cles) do
            Canon(k, out)
            Canon(v[k], out)
        end
        out[#out + 1] = "e"
    end
    return out
end

-- Deux sommes de 32 bits, sans operateur binaire (Lua 5.1) : de quoi
-- reconnaitre une version, pas de quoi resister a un faussaire.
local function Empreinte(texte)
    local a, b = 5381, 7
    for i = 1, #texte do
        local c = texte:byte(i)
        a = (a * 33 + c) % 4294967296
        b = (b * 31 + c + i) % 4294967296
    end
    return string.format("%08x%08x", a, b)
end

local function Revision(definition)
    return "j" .. Empreinte(table.concat(Canon(definition, {})))
end

local function EmpreinteDe(versions)
    local cles = {}
    for cle in pairs(versions) do cles[#cles + 1] = cle end
    table.sort(cles)
    local morceaux = {}
    for _, cle in ipairs(cles) do morceaux[#morceaux + 1] = cle .. "=" .. versions[cle] end
    return Empreinte(table.concat(morceaux, ";"))
end

-- ===== Ce que le MJ sert ======================================================
-- Le fichier engendre, plus ce que le MJ a ecrit depuis le dernier passage du
-- service (MJ/Brouillons.lua l'y verse), moins ce qu'il a supprime.
local servi
local function Servi()
    if servi then return servi end
    servi = {}
    for cle, entree in pairs(Source) do
        if Registre(cle, entree.definition) then
            servi[cle] = { revision = entree.revision, definition = entree.definition }
        end
    end
    return servi
end

local function VersionsServies()
    local versions = {}
    for cle, entree in pairs(Servi()) do versions[cle] = entree.revision end
    return versions
end

-- Le canal de presence, que tous les joueurs ont rejoint, groupes ou non ; le
-- groupe seulement s'il manque. Un joueur qui rate l'envoi le rattrape a sa
-- prochaine demande : les empreintes ne concorderont pas.
local function Diffuser(sujet, donnees)
    local canal = LCM.Presence and LCM.Presence.Canal()
    if canal then return R.Envoyer(sujet, donnees, "CHANNEL", canal, { etale = true }) end
    local groupe = LCM.Combat and LCM.Combat.CanalGroupe()
    if groupe then return R.Envoyer(sujet, donnees, groupe, nil, { etale = true }) end
    return false
end

-- Une entree enregistree par le MJ. `silencieux` : rien ne part (le
-- chargement, ou une entree recue de l'autre MJ, qui l'a deja envoyee).
-- Une entree devenue reservee au MJ se RETIRE chez les joueurs.
function Base.Publier(famille, definition, silencieux)
    if not LCM.IsMaster() or not REGISTRES[tostring(famille)] or type(definition) ~= "table" then
        return false
    end
    local cle = tostring(famille) .. "/" .. tostring(definition.id)
    if not Registre(cle, definition) then return Base.Retirer(famille, definition.id, silencieux) end
    local s = Servi()
    -- Identique au fichier : on garde la revision du fichier, que les joueurs
    -- a jour ont deja.
    local revision = Revision(definition)
    local fichier = Source[cle]
    if fichier and Revision(fichier.definition) == revision then revision = fichier.revision end
    if s[cle] and s[cle].revision == revision then return false end
    local copie = LCM.Copie(definition)
    s[cle] = { revision = revision, definition = copie }
    if not silencieux then
        Diffuser("base+", { cle = cle, revision = revision, corps = LCM.Lien.Serialiser(copie) })
    end
    return true
end

function Base.Retirer(famille, id, silencieux)
    if not LCM.IsMaster() then return false end
    local cle = tostring(famille) .. "/" .. tostring(id)
    local s = Servi()
    if not s[cle] then return false end
    s[cle] = nil
    if not silencieux then Diffuser("base-", { cle = cle }) end
    return true
end

function Base.Empreinte()
    if LCM.IsMaster() then return EmpreinteDe(VersionsServies()) end
    local versions = {}
    -- Une suppression retenue ne compte pas : le MJ, lui, n'a plus la cle.
    for cle, v in pairs(Base.Versions()) do
        if not v.supprime then versions[cle] = v.revision end
    end
    return EmpreinteDe(versions)
end

-- ===== Ce que le joueur tient =================================================
-- Le cache retient, par cle : la revision, l'heure serveur de la derniere
-- confirmation par un MJ (`quand`), la definition quand elle differe du
-- fichier de l'addon, ou `supprime`. Une suppression se garde : sans elle, un
-- relais qui l'ignore ferait revenir l'entree.

-- Ce qu'on a, effectivement : { [cle] = { revision, quand, supprime } }.
function Base.Versions()
    local versions = {}
    for cle, entree in pairs(Source) do
        versions[cle] = { revision = entree.revision, quand = 0 }
    end
    for cle, entree in pairs(Cache()) do
        if type(entree) == "table" and type(entree.revision) == "string" then
            local quand = tonumber(entree.quand) or 0
            if entree.supprime then
                versions[cle] = { revision = "-", quand = quand, supprime = true }
            elseif entree.definition and Registre(cle, entree.definition) then
                versions[cle] = { revision = entree.revision, quand = quand }
            elseif not entree.definition and Source[cle] and Source[cle].revision == entree.revision then
                -- Le fichier la porte telle quelle : seule l'heure change.
                versions[cle].quand = quand
            end
        end
    end
    return versions
end

local function Fraicheur()
    local q = 0
    for _, v in pairs(Base.Versions()) do if v.quand > q then q = v.quand end end
    return q
end

local function Definition(cle)
    local entree = Cache()[cle]
    if type(entree) == "table" and not entree.supprime then
        if entree.definition then return entree.definition end
    end
    return Source[cle] and Source[cle].definition or nil
end

-- Pose une definition dans son registre. Une entree que ce client refuse est
-- ecartee avec sa raison (LCM.Publier le dit) ; on retient quand meme sa
-- revision, sinon on la redemanderait a chaque connexion pour rien.
local function Poser(cle, definition)
    local registre = Registre(cle, definition)
    if not registre then return false end
    local ok, element = pcall(LCM.Publier, registre, definition)
    if not ok then LCM.Debug("base publique : " .. tostring(element)) end
    return true
end

local function Appliquer(cle, revision, definition, quand)
    if not Poser(cle, definition) then return false end
    local fichier = Source[cle]
    Cache()[cle] = {
        revision = revision, quand = quand,
        definition = not (fichier and fichier.revision == revision) and LCM.Copie(definition) or nil,
    }
    return true
end

local function Supprimer(cle, quand)
    local famille, id = Decouper(cle)
    if not famille then return end
    local registre = REGISTRES[famille] and LCM[REGISTRES[famille]]
    if registre and registre.Get and registre.Get(id) and registre.Retirer then registre.Retirer(id) end
    Cache()[cle] = { revision = "-", quand = quand, supprime = true }
end

-- Une cle qu'on a deja, telle quelle : seule l'heure de confirmation change.
local function Confirmer(cle, quand)
    local entree = Cache()[cle]
    if type(entree) == "table" then
        entree.quand = quand
    elseif Source[cle] then
        Cache()[cle] = { revision = Source[cle].revision, quand = quand }
    end
end

-- Le cache est charge apres les fichiers generes. Un joueur qui revient sans
-- MJ connecte retrouve ainsi la derniere copie publique qu'il a recue. Pas
-- chez un MJ : il sert le fichier, pas ce qu'il a recu un jour en joueur.
local function Charger()
    if LCM.IsMaster() then return end
    for cle, entree in pairs(Cache()) do
        if type(entree) ~= "table" then
            Cache()[cle] = nil
        elseif entree.supprime then
            Supprimer(cle, tonumber(entree.quand) or 0)
        elseif entree.definition then
            Poser(cle, entree.definition)
        end
    end
end

-- ===== La demande =============================================================

local function Battre()
    if horloge or not CreateFrame then return end
    horloge = CreateFrame("Frame")
    horloge.cumul = 0
    horloge:SetScript("OnUpdate", function(self, dt)
        self.cumul = self.cumul + (dt or 0)
        if self.cumul < 0.5 then return end
        self.cumul = 0
        local maintenant = Maintenant()
        if session and maintenant - session.vu > SESSION_MUETTE then session = nil end
        if collecte and maintenant >= collecte.fin then
            local choix = collecte.relais
            collecte = nil
            if choix and not session then
                session = { pair = choix.nom, relais = true, vu = maintenant }
                R.Envoyer("base_liste?", {}, "WHISPER", choix.nom)
            end
        end
    end)
end

function Base.Demander(force)
    if LCM.IsMaster() then return false end
    if session then return false end
    if not force and Maintenant() - derniereDemande < 30 then return false end
    local donnees = { e = Base.Empreinte(), q = Fraicheur() }
    local canal = LCM.Presence and LCM.Presence.Canal()
    local envoye = canal and R.Envoyer("base?", donnees, "CHANNEL", canal)
    local groupe = LCM.Combat and LCM.Combat.CanalGroupe()
    if groupe then envoye = R.Envoyer("base?", donnees, groupe) or envoye end
    if envoye then
        derniereDemande = Maintenant()
        Battre()
        collecte = { fin = Maintenant() + Base.ATTENTE_OFFRES, empreinte = donnees.e }
    end
    return envoye and true or false
end

local function DejaRepondu(joueur)
    local maintenant = Maintenant()
    if reponses[joueur] and maintenant - reponses[joueur] < REPONSE_UNIQUE then return true end
    reponses[joueur] = maintenant
    return false
end

local function ListeMJ()
    return LCM.Lien.Serialiser(VersionsServies())
end

local function Repondre(joueur, donnees)
    if DejaRepondu(joueur) then return end
    if LCM.IsMaster() then
        -- Un joueur pas encore a jour ne sait pas lire une empreinte : il
        -- recoit la liste, comme avant.
        if donnees.e == nil then
            if next(Servi()) then
                R.Envoyer("base_liste", { corps = ListeMJ() }, "WHISPER", joueur, { etale = true })
            end
            return
        end
        R.Envoyer("base=", { e = Base.Empreinte(), m = 1 }, "WHISPER", joueur)
        return
    end
    -- Un relais ne parle que s'il en sait PLUS RECENT, et seulement a son
    -- groupe : sinon chaque demande reveillerait tout le canal.
    if donnees.e == nil or not R.DansLeGroupe(joueur) then return end
    local q = Fraicheur()
    if q <= (tonumber(donnees.q) or 0) or donnees.e == Base.Empreinte() then return end
    R.Envoyer("base=", { e = Base.Empreinte(), q = q }, "WHISPER", joueur)
end

local function RecevoirOffre(joueur, donnees)
    if LCM.IsMaster() or not collecte or session then return end
    if donnees.m then
        collecte = nil
        if donnees.e == Base.Empreinte() then
            -- Le MJ a la meme chose : tout est confirme, a l'heure qu'il est.
            local quand = Heure()
            for cle, v in pairs(Base.Versions()) do
                if not v.supprime then Confirmer(cle, quand) end
            end
            return
        end
        session = { pair = joueur, vu = Maintenant() }
        R.Envoyer("base_liste?", {}, "WHISPER", joueur)
        return
    end
    local q = tonumber(donnees.q) or 0
    if not collecte.relais or q > collecte.relais.q then
        collecte.relais = { nom = joueur, q = q }
    end
end

local function ServirListe(joueur)
    if LCM.IsMaster() then
        if next(Servi()) then
            R.Envoyer("base_liste", { corps = ListeMJ() }, "WHISPER", joueur, { etale = true })
        end
        return
    end
    if not R.DansLeGroupe(joueur) then return end
    local versions = {}
    for cle, v in pairs(Base.Versions()) do versions[cle] = v.revision .. "@" .. v.quand end
    R.Envoyer("base_liste", { corps = LCM.Lien.Serialiser(versions), r = 1 },
        "WHISPER", joueur, { etale = true })
end

local function RecevoirListe(joueur, donnees)
    if LCM.IsMaster() then return end
    local relais = donnees.r ~= nil
    -- Un relais ne parle qu'a qui le lui a demande ; un MJ peut repondre a
    -- une demande de l'ancien protocole, qu'on n'a pas vue partir.
    if relais and not (session and session.relais and session.pair == joueur) then return end
    if not relais and session and session.pair ~= joueur then return end
    local versions = LCM.Lien.Deserialiser(donnees.corps)
    if type(versions) ~= "table" then return end
    local locales = Base.Versions()
    local demandes, attendues, quands = {}, {}, {}
    local maintenant = Heure()
    for cle, valeur in pairs(versions) do
        if type(cle) == "string" and type(valeur) == "string" and Decouper(cle) then
            local revision, quand = valeur, maintenant
            if relais then
                revision, quand = valeur:match("^(.-)@(%d+)$")
                quand = tonumber(quand)
            end
            local locale = locales[cle]
            if revision and quand and (not relais or quand > (locale and locale.quand or 0)) then
                if revision == "-" then
                    if locale and not locale.supprime then Supprimer(cle, quand) end
                elseif locale and locale.revision == revision then
                    Confirmer(cle, quand)
                else
                    demandes[#demandes + 1] = cle
                    attendues[cle], quands[cle] = revision, quand
                end
            end
        end
    end
    table.sort(demandes)
    session = { pair = joueur, relais = relais, vu = Maintenant(),
                versions = versions, attendues = attendues, quands = quands, recues = {} }
    R.Envoyer("base_demande", { cles = table.concat(demandes, ",") },
        "WHISPER", joueur, { etale = true })
end

local function ServirEntrees(joueur, donnees)
    local mj = LCM.IsMaster()
    if not mj and not R.DansLeGroupe(joueur) then return end
    local locales = not mj and Base.Versions() or nil
    local nombre = 0
    for cle in tostring(donnees.cles or ""):gmatch("[^,]+") do
        local revision, definition, quand
        if mj then
            local entree = Servi()[cle]
            if entree then revision, definition = entree.revision, entree.definition end
        else
            local v = locales[cle]
            if v and not v.supprime then
                revision, quand, definition = v.revision, v.quand, Definition(cle)
            end
        end
        if definition and Registre(cle, definition) and nombre < 500 then
            R.Envoyer("base_entree", { cle = cle, revision = revision, quand = quand,
                corps = LCM.Lien.Serialiser(definition) },
                "WHISPER", joueur, { etale = true })
            nombre = nombre + 1
        end
    end
    R.Envoyer("base_fin", {}, "WHISPER", joueur, { etale = true })
end

local function RecevoirEntree(joueur, donnees)
    if not (session and session.pair == joueur and session.attendues) then return end
    session.vu = Maintenant()
    local cle = tostring(donnees.cle or "")
    if session.attendues[cle] ~= donnees.revision then return end
    local definition = LCM.Lien.Deserialiser(donnees.corps)
    if not Appliquer(cle, donnees.revision, definition, session.quands[cle]) then return end
    session.recues[cle] = true
end

local function Finir(joueur)
    if not (session and session.pair == joueur and session.attendues) then return end
    local s = session
    session = nil
    -- Seul un MJ fait la loi : ce que sa liste ne porte pas n'existe plus.
    -- Un relais, lui, ne fait qu'ajouter ce qu'il sait de plus recent.
    if s.relais then return end
    for cle in pairs(s.attendues) do
        if not s.recues[cle] then return end
    end
    local quand = Heure()
    for cle, v in pairs(Base.Versions()) do
        if not s.versions[cle] and not v.supprime then Supprimer(cle, quand) end
    end
end

-- ===== En seance ==============================================================

local function RecevoirAjout(joueur, donnees)
    if LCM.IsMaster() then return end
    local cle, revision = tostring(donnees.cle or ""), tostring(donnees.revision or "")
    if not Decouper(cle) or revision == "" then return end
    local locale = Base.Versions()[cle]
    if locale and locale.revision == revision then
        Confirmer(cle, Heure())
        return
    end
    local definition = LCM.Lien.Deserialiser(donnees.corps)
    Appliquer(cle, revision, definition, Heure())
end

local function RecevoirRetrait(joueur, donnees)
    if LCM.IsMaster() then return end
    local cle = tostring(donnees.cle or "")
    local locale = Decouper(cle) and Base.Versions()[cle]
    if locale and not locale.supprime then Supprimer(cle, Heure()) end
end

LCM.WhenReady(function()
    Charger()
    Battre()
    R.Ecouter("base?", Repondre)
    R.Ecouter("base=", RecevoirOffre)
    R.Ecouter("base_liste?", ServirListe)
    R.Ecouter("base_liste", RecevoirListe)
    R.Ecouter("base_demande", ServirEntrees)
    R.Ecouter("base_entree", RecevoirEntree)
    R.Ecouter("base_fin", Finir)
    R.Ecouter("base+", RecevoirAjout)
    R.Ecouter("base-", RecevoirRetrait)
    if not LCM.IsMaster() then
        LCM.Presence.Suivre(function() Base.Demander() end)
        Base.Demander(true)
    end
end)
