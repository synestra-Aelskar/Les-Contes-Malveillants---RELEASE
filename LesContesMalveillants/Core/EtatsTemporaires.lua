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
        -- La duree se range en NOMBRE : elle arrive d'un champ de saisie du
        -- Panel ou d'un paquet reseau, qui ne rendent que du texte.
        bonus = etat.bonus or {}, restant = tonumber(etat.rounds), lanceur = etat.lanceur,
        -- Les jets que cet etat fait relancer en gardant le pire. Il voyage
        -- avec lui, comme ses bonus : un etat n'impose plus le desavantage
        -- parce qu'il retire des points, il l'impose parce qu'il le dit
        -- (le MJ, 24 octobre 2026).
        desavantage = type(etat.desavantage) == 'table' and LCM.Copie(etat.desavantage) or nil,
        -- Et les champs dont le montant se lit en POURCENTAGE : il voyage de
        -- la meme facon, sinon « baisse la Force de 40 % » deviendrait
        -- « retire 40 points de Force » une fois l'etat pose.
        pourcent = type(etat.pourcent) == 'table' and LCM.Copie(etat.pourcent) or nil,
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

-- Imposer un etat du compendium : LA DUREE DECIDE DE SON LOGEMENT.
--
-- Sans duree, il n'a rien de temporaire — il reste jusqu'a ce qu'on le
-- retire. Sa place est donc celle des etats PORTES, dans l'emplacement de son
-- conteneur (« États divers », « Maladies », « Intangible »), et non la liste
-- des etats temporaires, ou il se serait installe pour toujours sous une
-- duree vide (le MJ, 24 octobre 2026).
--
-- Avec une duree, c'est bien un etat temporaire : il compte ses rounds et
-- s'eteint seul.
--
-- Renvoie true, ou false et la raison (plus d'emplacement libre, deja porte).
function Temporaires.Imposer(entity, definition, rounds)
    if type(entity) ~= "table" then return false, "aucune fiche." end
    if type(definition) ~= "table" then return false, "état inconnu." end
    if rounds == nil then
        local ok, raison = LCM.Etats.Placer(entity, definition.id)
        if not ok then return false, raison end
        if LCM.Entities and LCM.Entities.Changed then LCM.Entities.Changed(entity, "etats") end
        return true
    end
    Temporaires.Poser(entity, {
        nom = definition.label, icone = definition.icone,
        description = definition.description, bonus = definition.bonus,
        desavantage = definition.desavantage, pourcent = definition.pourcent,
        rounds = rounds, conteneur = LCM.Etats.Conteneur(definition),
        debuff = definition.debuff == true, id = definition.id,
    })
    return true
end

-- Changer la duree d'un etat deja pose, en seance. Comme c'est la duree qui
-- decide du logement, la changer DEPLACE l'etat quand il le faut : donner une
-- duree a un etat porte en fait un etat temporaire, la lui retirer le range
-- avec les etats portes.
--
-- `nom` designe un etat temporaire, `id` une entree du compendium : une ligne
-- du Panel MJ peut etre l'un ou l'autre, et porte les deux.
function Temporaires.FixerDuree(entity, nom, rounds, id)
    if type(entity) ~= "table" then return false, "aucune fiche." end
    nom = tostring(nom or "")
    if rounds ~= nil then
        rounds = tonumber(rounds)
        if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then
            return false, "la durée doit être un nombre entier positif." end
    end
    for _, e in ipairs(Temporaires.Liste(entity)) do
        if e.nom == nom or (e.id ~= nil and id ~= nil and e.id == id) then
            if rounds ~= nil then
                e.restant = rounds
                if Temporaires.onChange then Temporaires.onChange(entity) end
                if LCM.Entities and LCM.Entities.Changed then
                    LCM.Entities.Changed(entity, "etatsTemporaires")
                end
                return true
            end
            -- Plus de duree. Un etat venu du compendium rejoint les etats
            -- portes ; un etat pose par une action n'y a pas d'entree, il
            -- reste ou il est et cesse simplement de compter.
            local definition = e.id and LCM.Etats.Get(e.id)
            if not definition then
                e.restant = nil
                if Temporaires.onChange then Temporaires.onChange(entity) end
                if LCM.Entities and LCM.Entities.Changed then
                    LCM.Entities.Changed(entity, "etatsTemporaires")
                end
                return true
            end
            local ok, raison = Temporaires.Imposer(entity, definition, nil)
            if not ok then return false, raison end
            Temporaires.RetirerForce(entity, e.nom)
            return true
        end
    end
    -- Pas dans les temporaires : c'est un etat PORTE.
    local definition = id and LCM.Etats and LCM.Etats.Get(id)
    if not definition then return false, "cet état n'est pas sur cette fiche." end
    if rounds == nil then return true end
    if not LCM.Etats.Enlever(entity, definition.id) then
        return false, "cet état n'est pas sur cette fiche."
    end
    if LCM.Entities and LCM.Entities.Changed then LCM.Entities.Changed(entity, "etats") end
    return Temporaires.Imposer(entity, definition, rounds)
end

-- Le MJ demande au personnage de changer la duree d'un de ses etats. Comme
-- Envoyer : c'est sa fiche a lui qui change, la copie consultee n'est qu'une
-- image.
function Temporaires.EnvoyerDuree(joueur, nom, rounds, id)
    joueur = tostring(joueur or "")
    if joueur == "" then return false, "choisis un joueur." end
    if not LCM.IsMaster() then return false, "seul le maître du jeu peut changer une durée." end
    if joueur == tostring(LCM.PlayerId()) then return false, "utilise la fiche locale pour ton personnage." end
    if not LCM.Reseau.DansLeGroupe(joueur) then return false, "ce joueur n'est pas dans le groupe." end
    if rounds ~= nil then
        rounds = tonumber(rounds)
        if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then
            return false, "la durée doit être un nombre entier positif." end
    end
    local ok, raison = LCM.Reseau.Envoyer("etat_mj~",
        { n = nom, r = rounds, i = id }, "WHISPER", joueur)
    if not ok then return false, raison or "la durée n'a pas pu être envoyée." end
    return true
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

-- Le MJ demande au personnage de RETIRER un etat de sa propre fiche. Le
-- pendant d'Envoyer : sans lui, le bouton « Retirer » d'une fiche consultee
-- n'aurait agi que sur la copie recue, donc sur rien (le MJ, 24 octobre 2026).
function Temporaires.EnvoyerRetrait(joueur, nom, catalogue)
    joueur, nom = tostring(joueur or ""), tostring(nom or "")
    if joueur == "" then return false, "choisis un joueur." end
    if nom == "" then return false, "quel état ?" end
    if not LCM.IsMaster() then return false, "seul le maître du jeu peut retirer un état." end
    if joueur == tostring(LCM.PlayerId()) then return false, "utilise la fiche locale pour ton personnage." end
    if not LCM.Reseau.DansLeGroupe(joueur) then return false, "ce joueur n'est pas dans le groupe." end
    local ok, raison = LCM.Reseau.Envoyer("etat_mj-", { n = nom, c = catalogue == true or nil }, "WHISPER", joueur)
    if not ok then return false, raison or "le retrait n'a pas pu être envoyé." end
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

-- `restant` peut arriver en CHAINE. Une fiche consultee traverse l'encodage du
-- reseau, qui ne rend que du texte : la duree se comparait alors a 1 et la
-- consultation s'arretait sur une erreur (le MJ, 25 octobre 2026). On la relit
-- en nombre ici, pour que l'affichage tienne quelle que soit la source.
function Temporaires.Duree(etat)
    local restant = tonumber(etat.restant)
    if not restant then return "jusqu'à retrait" end
    return string.format("%d round%s", restant, restant > 1 and "s" or "")
end

-- Une source d'effets comme les traits : ses elements ont un libelle, des
-- bonus, pas d'avantage, et le DESAVANTAGE que leur etat declare — un etat
-- temporaire porte le meme que l'etat du compendium dont il vient (le MJ,
-- 24 octobre 2026). Sans cela, poser un etat en seance n'aurait jamais pu
-- faire jeter avec desavantage, meme coche.
LCM.Effets.Source("état temporaire", function(entity)
    local out = {}
    for _, e in ipairs(Temporaires.Liste(entity)) do
        -- L'etat porte son desavantage, comme il porte ses bonus. A defaut
        -- (un etat pose avant le 24 octobre 2026, encore en sauvegarde), on
        -- le relit sur son modele du compendium.
        local declare, enPourcent = e.desavantage, e.pourcent
        if (not declare or not enPourcent) and e.id and LCM.Etats then
            local modele = LCM.Etats.Get(e.id)
            declare = declare or (modele and modele.desavantage)
            enPourcent = enPourcent or (modele and modele.pourcent)
        end
        out[#out + 1] = { label = e.nom, bonus = e.bonus or {}, avantage = VIDE,
                          desavantage = declare or VIDE, pourcent = enPourcent or VIDE }
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
    -- Le MJ retire un etat qu'il a pose. On FORCE : un etat de controle ne se
    -- retire pas par sa cible, mais celui qui l'a pose doit pouvoir le lever.
    LCM.Reseau.Ecouter("etat_mj-", function(expediteur, paquet)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local entity = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        if not entity then return end
        local nom = tostring(paquet and paquet.n or "")
        if nom == "" then return end
        local retire
        if paquet.c == true then
            retire = LCM.Etats.Enlever(entity, nom)
            if retire then LCM.Entities.Changed(entity, "etats") end
        else
            retire = Temporaires.RetirerForce(entity, nom)
        end
        if retire then
            LCM.Info(string.format("Le MJ retire « %s ».", nom))
        end
    end)

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
        -- Sans duree, il rejoint les etats PORTES et non la liste des
        -- temporaires : c'est Imposer qui en decide.
        local ok, raison = Temporaires.Imposer(entity, definition, rounds)
        if not ok then
            LCM.Alerte(string.format("« %s » n'a pas pu être posé : %s",
                definition.label, tostring(raison)))
            return
        end
        LCM.Info(string.format("Le MJ vous impose « %s » (%s).", definition.label,
            rounds and (rounds .. " round" .. (rounds > 1 and "s" or "")) or "jusqu'au retrait"))
    end)

    -- Le MJ change la duree d'un etat deja pose.
    LCM.Reseau.Ecouter("etat_mj~", function(expediteur, paquet)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local entity = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        if not entity then return end
        local rounds
        if paquet.r ~= nil and paquet.r ~= "" then
            rounds = tonumber(paquet.r)
            if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then return end
        end
        local ok = Temporaires.FixerDuree(entity, paquet.n, rounds, paquet.i)
        if ok then
            LCM.Info(string.format("Le MJ change la durée de « %s » : %s.",
                tostring(paquet.n), rounds and (rounds .. " round" .. (rounds > 1 and "s" or ""))
                    or "jusqu'au retrait"))
        end
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
            effets[#effets + 1] = string.format("%s %+d%s", field and field.label or champ, n,
                LCM.Effets.Unite(e, champ))
        end
        table.sort(effets)
        LCM.Info(string.format("%s (%s)%s", e.nom, Temporaires.Duree(e),
            #effets > 0 and (" — " .. table.concat(effets, ", ")) or ""))
    end
end)
