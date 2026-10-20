-- Les etats temporaires : ce qu'une action pose sur une fiche pour quelques
-- rounds — Immobilise, Entrave, En levitation.
--
-- A ne pas confondre avec les Etats du catalogue (Core/Etats.lua), que le MJ
-- donne et retire a la main : ceux-ci viennent d'une resolution d'action
-- (pas « effect » de Necronicon), portent leur propre effet chiffre et
-- s'eteignent seuls. Repris des « etats ephemeres » de Necronicon
-- (BuildEphemeralStateFromTemplate, PlaceEphemeralStateOnFiche), sans les
-- cumuls ni la guerison par jet, que les controles du template n'utilisent
-- pas.
--
-- Ils vivent SUR l'entite qui les subit (sa fiche, ou l'instance du PNJ) :
-- c'est une donnee de partie, comme une blessure. Une source d'effets
-- (Core/Effets.lua) les ajoute aux bonus : la fiche et les jets les voient
-- sans savoir d'ou ils viennent.
--
-- La duree se compte en rounds du combat (Core/Combat.lua) : un etat pose a
-- 3 rounds s'eteint au troisieme round suivant. Hors combat, il dure jusqu'a
-- ce qu'on le retire.

local _, LCM = ...

local Temporaires = {}
LCM.EtatsTemporaires = Temporaires

local VIDE = {}

-- Les trois conteneurs de la fenetre Sante (Core/Etats.lua) : un buff ou un
-- debuff dit lequel le recoit, sinon tout atterrissait dans « Etats » et la
-- maladie qu'on venait de poser se lisait au milieu des immobilisations.
Temporaires.CONTENEURS = {
    { id = "etat",       label = "État" },
    { id = "maladie",    label = "Maladie" },
    { id = "intangible", label = "Intangible" },
}

function Temporaires.ConteneurValide(id)
    for _, c in ipairs(Temporaires.CONTENEURS) do if c.id == id then return id end end
    return "etat"
end

-- Lecture : ne cree rien. `conteneur` filtre sur le volet de Sante demande ;
-- sans lui, tout. Un etat d'avant cette regle n'en a pas : il compte comme
-- « etat », la ou il s'affichait deja.
function Temporaires.Liste(entity, conteneur)
    local liste = type(entity) == "table" and type(entity.etatsTemporaires) == "table"
        and entity.etatsTemporaires or VIDE
    if not conteneur then return liste end
    local out = {}
    for _, e in ipairs(liste) do
        if (e.conteneur or "etat") == conteneur then out[#out + 1] = e end
    end
    return out
end

local function PourEcrire(entity)
    entity.etatsTemporaires = type(entity.etatsTemporaires) == "table" and entity.etatsTemporaires or {}
    return entity.etatsTemporaires
end

-- Une liste redevenue vide disparait de la sauvegarde.
local function Ranger(entity)
    if type(entity.etatsTemporaires) == "table" and #entity.etatsTemporaires == 0 then
        entity.etatsTemporaires = nil
    end
end

-- etat = { nom, icone, description, bonus = { [champ] = n }, rounds (nil :
-- jusqu'a ce qu'on le retire), lanceur, debuff, dissipation }
function Temporaires.Poser(entity, etat)
    local liste = PourEcrire(entity)
    -- Le meme etat repose (meme nom) remplace l'ancien : on ne s'immobilise
    -- pas deux fois, on prolonge.
    for i = #liste, 1, -1 do
        if liste[i].nom == etat.nom then table.remove(liste, i) end
    end
    liste[#liste + 1] = {
        nom = tostring(etat.nom or "État"), icone = etat.icone, description = etat.description,
        bonus = etat.bonus or {}, restant = etat.rounds, lanceur = etat.lanceur,
        debuff = etat.debuff == true, dissipation = etat.dissipation, cumul = etat.cumul,
        conteneur = Temporaires.ConteneurValide(etat.conteneur),
        -- Ce que la dissipation doit battre : le jet du lanceur, et sa
        -- competence (la meme est « adaptee », l'autre « inadaptee »).
        id = etat.id, jet = etat.jet,
        -- Un etat sans duree se guerit : par la narration (le MJ le retire) ou
        -- par un jet { competence, dc } (Necronicon : cureMode « rand »).
        guerison = etat.guerison,
        controle = type(etat.controle) == "table" and LCM.Copie(etat.controle) or nil,
        -- Ce qui fait d'un etat un DOT (Core/Dot.lua) : stacks, morsures, rand.
        -- Sans cette ligne, l'etat se posait mais ne mordait jamais.
        dot = type(etat.dot) == "table" and LCM.Copie(etat.dot) or nil,
    }
    if Temporaires.onChange then Temporaires.onChange(entity) end
    if LCM.Entities and LCM.Entities.Changed then LCM.Entities.Changed(entity, "etatsTemporaires") end
    return liste[#liste]
end

-- Le MJ demande au personnage de poser un etat du catalogue sur sa propre
-- fiche. Seul l'identifiant et la duree voyagent : les effets viennent du
-- catalogue partage, jamais d'un paquet arbitraire.
function Temporaires.Envoyer(joueur, id, rounds)
    joueur, id = tostring(joueur or ""), tostring(id or "")
    if joueur == "" then return false, "choisis un joueur." end
    if not LCM.IsMaster() then return false, "seul le maître du jeu peut imposer un état." end
    if joueur == tostring(LCM.PlayerId()) then return false, "utilise la fiche locale pour ton personnage." end
    if not LCM.Reseau.DansLeGroupe(joueur) then return false, "ce joueur n'est pas dans le groupe." end
    local definition = LCM.Etats and LCM.Etats.Get(id)
    if not definition then return false, "état inconnu." end
    if rounds ~= nil then
        rounds = tonumber(rounds)
        if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then
            return false, "la durée doit être un nombre entier positif." end
    end
    local ok, raison = LCM.Reseau.Envoyer("etat_mj", { i = id, r = rounds }, "WHISPER", joueur)
    if not ok then return false, raison or "l'état n'a pas pu être envoyé." end
    return true
end

-- Retire par nom, ou par identifiant (celui que la dissipation designe).
function Temporaires.Retirer(entity, nom, force)
    local liste = Temporaires.Liste(entity)
    local retire = false
    for i = #liste, 1, -1 do
        if liste[i].nom == nom or (liste[i].id ~= nil and liste[i].id == nom) then
            if liste[i].controle and not force and not LCM.IsMaster() then return false, "cet état ne peut pas être retiré par sa cible." end
            table.remove(liste, i)
            retire = true
        end
    end
    if retire then
        Ranger(entity)
        if Temporaires.onChange then Temporaires.onChange(entity) end
        if LCM.Entities and LCM.Entities.Changed then LCM.Entities.Changed(entity, "etatsTemporaires") end
    end
    return retire
end

function Temporaires.RetirerForce(entity, nom) return Temporaires.Retirer(entity, nom, true) end

-- Un cumul (« stack ») draine, a chaque round, pct % du maximum de sa jauge
-- par cumul : une zone du corps (« Torse »), la Fatigue ou les Boucliers.
local function Drainer(entity, cumul)
    local Cle = LCM.Actions and LCM.Actions.Cle or function(x) return tostring(x):lower() end
    local voulu = Cle(cumul.jauge)
    local function Part(max) return math.ceil(max * (cumul.pct or 5) / 100 * (cumul.n or 1) - 1e-9) end
    if voulu == "fatigue" or voulu:find("^bouclier") then
        local champ = voulu == "fatigue" and "fatigue" or "armure"
        local j = LCM.Entities.Gauge(entity, champ)
        local n = Part(j.max)
        LCM.Entities.SetGauge(entity, champ, j.current - n)
        return n, champ == "fatigue" and "Fatigue" or "Boucliers"
    end
    for _, z in ipairs(LCM.Body.State(entity, LCM.Body.MaxTotal(entity))) do
        if Cle(z.label) == voulu or Cle(z.label):find(voulu, 1, true) then
            local n = Part(z.max)
            LCM.Body.Damage(entity, z.id, n)
            return n, z.label
        end
    end
end

-- Un round passe : chaque etat compte, ceux qui arrivent a zero s'eteignent ;
-- un cumul draine sa jauge d'abord. Retourne les noms eteints.
function Temporaires.Round(entity)
    local liste = Temporaires.Liste(entity)
    local avaitEtat = #liste > 0
    local eteints = {}
    -- Les dots mordent AVANT que les durees ne baissent : un dot d'un round
    -- doit mordre une fois, pas zero.
    --
    -- On DIT ce qui s'est passe. Pour une jauge unique c'est deja applique et
    -- l'on informe ; pour une jauge zonee, rien n'a bouge et c'est une consigne
    -- a jouer — elle passe donc en alerte, pour qu'elle ne se perde pas au
    -- milieu du journal.
    if LCM.Dot then
        for _, fait in ipairs(LCM.Dot.Tic(entity)) do
            if fait.zonee then
                LCM.Alerte(fait.note)
            elseif (fait.retire or 0) > 0 then
                local champ = LCM.Schema.Field(fait.jauge)
                LCM.Info(string.format("« %s » grignote %d %s.", fait.etat, fait.retire,
                    champ and champ.label or fait.jauge))
            end
        end
    end
    for _, e in ipairs(liste) do
        if type(e.cumul) == "table" then
            local n, ou = Drainer(entity, e.cumul)
            if n and n > 0 then
                LCM.Info(string.format("%s : « %s » draine %d (%s).", tostring(entity.name or "?"), e.nom, n, ou))
            end
        end
    end
    for i = #liste, 1, -1 do
        local e = liste[i]
        if e.restant then
            e.restant = e.restant - 1
            if e.restant <= 0 then
                eteints[#eteints + 1] = e.nom
                table.remove(liste, i)
            end
        end
    end
    if #eteints > 0 then
        Ranger(entity)
        if Temporaires.onChange then Temporaires.onChange(entity) end
    end
    if avaitEtat and LCM.Entities and LCM.Entities.Changed then
        LCM.Entities.Changed(entity, "etatsTemporaires")
    end
    return eteints
end

-- Tenter de guerir un etat qui le permet par un jet : la competence contre la
-- difficulte. Une primaire qui ne se lance pas (Constitution) se joue au de de
-- l'Adresse, plus sa valeur.
function Temporaires.Guerir(entity, nom)
    local etat
    for _, e in ipairs(Temporaires.Liste(entity)) do if e.nom == nom or e.id == nom then etat = e end end
    if not etat then return nil, "aucun état « " .. tostring(nom) .. " »." end
    local g = etat.guerison
    if not (g and g.mode == "rand") then return nil, "« " .. etat.nom .. " » ne se guérit pas par un jet : le MJ le retire." end
    local A = LCM.Actions
    local field = A.ChampParLibelle(g.competence, "roll")
    local total, detail
    if field then
        local r = LCM.Roll.Field(entity, field.id)
        total, detail = r.total, LCM.Roll.Describe(r)
    else
        local primaire = A.ChampParLibelle(g.competence)
        local des = LCM.Schema.Field("adresse").dice
        local de = LCM.Roll.Des(des.min or 0, des.max or 0)
        local valeur = primaire and LCM.Formules.Primaire(entity, primaire.id) or 0
        total = de + valeur
        detail = string.format("%s : %d  (dé %d, valeur %+d)", tostring(g.competence), total, de, valeur)
    end
    local ok = total >= (tonumber(g.dc) or 0)
    if ok then Temporaires.Retirer(entity, etat.nom) end
    return ok, string.format("%s — guérison de « %s » (DC %d) : %s", detail, etat.nom, tonumber(g.dc) or 0,
        ok and "réussie" or "ratée")
end

function Temporaires.Duree(etat)
    if not etat.restant then return "jusqu'à retrait" end
    return string.format("%d round%s", etat.restant, etat.restant > 1 and "s" or "")
end

-- Une source d'effets comme les traits : ses elements ont un libelle, des
-- bonus et pas d'avantage.
LCM.Effets.Source("état temporaire", function(entity)
    local out = {}
    for _, e in ipairs(Temporaires.Liste(entity)) do
        out[#out + 1] = { label = e.nom, bonus = e.bonus or {}, avantage = VIDE }
    end
    return out
end)

-- Les rounds du combat font vieillir les etats de qui s'y trouve ici : soi,
-- et, chez le MJ, les PNJ en jeu. « Soi », c'est le personnage du joueur, pas
-- Entities.Self() : pendant le tour d'un PNJ, le MJ l'incarne, et Self() est
-- alors le PNJ — son propre personnage serait oublie.
local function Vieillir()
    local touches = { LCM.Entities.Self() }
    local actif = LCM.Personnages and LCM.Personnages.Actif and LCM.Personnages.Actif()
    touches[#touches + 1] = actif or LCM.Entities.Get(LCM.PlayerId())
    if LCM.IsMaster() then
        for _, instance in ipairs(LCM.Incarnation.Liste()) do touches[#touches + 1] = instance end
    end
    local vus = {}
    for _, entity in ipairs(touches) do
        if entity and not vus[entity] then
            vus[entity] = true
            for _, nom in ipairs(Temporaires.Round(entity)) do
                LCM.Info(string.format("%s : « %s » prend fin.", tostring(entity.name or "?"), nom))
            end
        end
    end
end
Temporaires.Vieillir = Vieillir

LCM.WhenReady(function()
    LCM.Reseau.Ecouter("etat_mj", function(expediteur, paquet)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local definition = LCM.Etats and LCM.Etats.Get(paquet.i)
        if not definition then
            LCM.Debug("état MJ ignoré : définition absente du compendium.")
            return
        end
        local rounds
        if paquet.r ~= nil and paquet.r ~= "" then
            rounds = tonumber(paquet.r)
            if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then return end
        end
        local entity = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        if not entity then return end
        Temporaires.Poser(entity, {
            nom = definition.label, icone = definition.icone,
            description = definition.description, bonus = definition.bonus,
            rounds = rounds, conteneur = definition.categorie,
            debuff = definition.debuff == true, id = definition.id,
        })
        LCM.Info(string.format("Le MJ vous impose « %s » (%s).", definition.label,
            rounds and (rounds .. " round" .. (rounds > 1 and "s" or "")) or "jusqu'au retrait"))
    end)
end)

LCM.AddCommand("etats", "les états temporaires : la liste, ou « retirer <nom> »", function(argument)
    local mot, reste = tostring(argument or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local moi = LCM.Entities.Self()
    if mot == "retirer" and reste ~= "" then
        if Temporaires.Retirer(moi, reste) then LCM.Ok(string.format("« %s » retiré.", reste))
        else LCM.Alerte(string.format("aucun état temporaire « %s ».", reste)) end
        return
    end
    local liste = Temporaires.Liste(moi)
    if #liste == 0 then LCM.Info("aucun état temporaire.") return end
    for _, e in ipairs(liste) do
        local effets = {}
        for champ, n in pairs(e.bonus or {}) do
            local field = LCM.Schema.Field(champ)
            effets[#effets + 1] = string.format("%s %+d", field and field.label or champ, n)
        end
        table.sort(effets)
        LCM.Info(string.format("%s (%s)%s", e.nom, Temporaires.Duree(e),
            #effets > 0 and (" — " .. table.concat(effets, ", ")) or ""))
    end
end)
