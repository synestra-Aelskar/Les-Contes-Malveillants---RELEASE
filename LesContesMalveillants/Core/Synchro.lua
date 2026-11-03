-- La synchronisation FORCEE (le MJ, 3 novembre 2026) : un bouton du Panel MJ
-- qui refait, a la demande, ce que la connexion fait d'habitude toute seule.
--
-- Pourquoi : le binome s'est connecte et n'a rien recu. Tout ce qui se
-- partage part a un moment precis — un reglage quand on le change, une
-- entree quand on l'enregistre, la base publique quand le JOUEUR se connecte —
-- et celui qui arrive apres ce moment, ou dont la demande s'est perdue (canal
-- pas encore rejoint, groupe pas encore connu), attend la prochaine
-- modification. Le bouton rejoue ces moments.
--
-- Deux temps :
--   * chez le MJ qui clique : ses reglages en cours repartent au groupe, sa
--     liste de la base publique part a tous (chaque joueur reclame ce qui
--     lui manque, le compendium compris), et ce que le compagnon MJ a branche
--     ici (la file d'envoi des entrees vers les autres MJ) repart aussi ;
--   * chez tout le monde, lui compris : « synchro! » fait relancer les
--     demandes de connexion (base publique, coffres, recolte, vendeurs,
--     panneaux, outils, scene, presence, acces aux traits).
--
-- Rien n'est ecrit en sauvegarde : on renvoie et on redemande, c'est tout.
local _, LCM = ...

local Synchro = {}
LCM.Synchro = Synchro

local SUJET = "synchro!"
-- Deux clics coup sur coup (ou deux MJ qui cliquent ensemble) ne doivent pas
-- doubler les demandes de chacun.
Synchro.INTERVALLE = 10

local derniereRelance = -math.huge
local branchements = {}

local function Maintenant() return (GetTime and GetTime()) or 0 end

-- Le compagnon MJ s'y branche : Core ne le connait pas (il n'est pas livre
-- aux joueurs). `fn()` rend le nombre de choses renvoyees.
function Synchro.SurForcer(fn)
    if type(fn) == "function" then branchements[#branchements + 1] = fn end
end

-- Appelle `fn` si elle existe, sans laisser une erreur arreter les autres :
-- une demande qui plante ne doit pas empecher la suivante de partir.
local function Essayer(nom, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, resultat = pcall(fn, ...)
    if not ok then
        if LCM.Erreur then LCM.Erreur("synchro, " .. nom .. " : " .. tostring(resultat)) end
        return false
    end
    return resultat and true or false
end

-- Relancer les demandes de connexion. Chacune garde ses propres regles (un
-- MJ ne demande pas la base publique, il EN EST la voix) : on les appelle,
-- on ne les reecrit pas. Rend le nombre de demandes parties.
function Synchro.Relancer(force)
    if not force and Maintenant() - derniereRelance < Synchro.INTERVALLE then return 0 end
    derniereRelance = Maintenant()
    local n = 0
    local function Demande(nom, module, ...)
        if module and Essayer(nom, module.Demander, ...) then n = n + 1 end
    end
    Demande("présence", LCM.Presence, true)
    Demande("base publique", LCM.BasePublique, true)
    Demande("coffres", LCM.Coffres)
    Demande("récolte", LCM.Recolte)
    Demande("vendeurs", LCM.Marchands)
    Demande("panneaux", LCM.Affichages)
    Demande("outils", LCM.Outils)
    Demande("scène", LCM.Scene)
    if not LCM.IsMaster() and LCM.Reseau then
        local canal = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
        if Essayer("traits", LCM.Reseau.Envoyer, "traits_acces_demande", {}, canal) then n = n + 1 end
    end
    return n
end

-- ===== Le flux, visible ====================================================
-- Tout ce que la synchro envoie passe par la file etalee du reseau (une
-- rafale, puis un message tous les CADENCE) : sur une grosse base, ca prend
-- une bonne minute, et le bouton restait muet pendant ce temps — le MJ
-- recliquait, croyant que rien ne partait (le MJ, 3 novembre 2026 : « parfois
-- les data mettent du temps a arriver »). On SUIT donc le flux : combien de
-- morceaux sont partis depuis le clic, combien attendent encore.
--
-- Le total n'est pas connu d'avance et ce n'est pas un defaut : chaque
-- joueur, en recevant la liste, reclame ce qui lui manque, et ces reponses
-- rejoignent la file apres coup. Le total GRANDIT donc pendant la synchro.
-- On ne la dit finie qu'une fois la file restee vide CALME secondes : le
-- temps qu'une reclamation en route ait pu arriver.
Synchro.CALME = 3

local suivi

-- nil si aucune synchro n'a ete lancee ; sinon { envoyes, total, fini }.
-- Lire la progression la fait avancer (c'est le bouton qui la lit, a son
-- rythme) : rien ne tourne en fond quand personne ne regarde.
function Synchro.Progression()
    if not suivi then return nil end
    local R = LCM.Reseau
    local reste = (R and R.FileEnvoi and R.FileEnvoi()) or 0
    local envoyes = ((R and R.Expedies and R.Expedies()) or 0) - suivi.debut
    if not suivi.fini then
        local t = Maintenant()
        if reste > 0 then suivi.actif = t end
        if reste == 0 and t - suivi.actif >= Synchro.CALME then suivi.fini = true end
    end
    return { envoyes = envoyes, total = envoyes + reste, fini = suivi.fini == true }
end

function Synchro.EnCours()
    local p = Synchro.Progression()
    return p ~= nil and not p.fini
end

-- Le bouton. Rend un resume { reglages, envois, base, annonce } pour le dire.
function Synchro.Forcer()
    local R0 = LCM.Reseau
    suivi = { debut = (R0 and R0.Expedies and R0.Expedies()) or 0, actif = Maintenant() }
    local resume = { reglages = 0, envois = 0, base = 0, annonce = false }
    if LCM.Reglages and LCM.Reglages.DiffuserTout then
        resume.reglages = LCM.Reglages.DiffuserTout()
    end
    for _, fn in ipairs(branchements) do
        local ok, n = pcall(fn)
        if ok then
            resume.envois = resume.envois + (tonumber(n) or 0)
        elseif LCM.Erreur then
            LCM.Erreur("synchro : " .. tostring(n))
        end
    end
    -- La base publique, POUSSEE aux joueurs (le MJ, 3 novembre 2026 : « que
    -- meme le compendium soit a jour chez eux »). Avant l'annonce : un joueur
    -- qui recoit la liste ouvre sa session, et sa propre demande relancee
    -- ensuite s'efface derriere elle au lieu de la doubler.
    if LCM.BasePublique and LCM.BasePublique.Pousser then
        resume.base = LCM.BasePublique.Pousser()
        if resume.base > 0 then resume.annonce = true end
    end
    -- Le canal ET le groupe : un joueur qui n'a pas encore rejoint le canal
    -- de l'addon (c'est asynchrone) n'entendrait que l'un des deux.
    local R = LCM.Reseau
    if R then
        local id = LCM.Presence and LCM.Presence.Canal and LCM.Presence.Canal()
        if id then resume.annonce = R.Envoyer(SUJET, {}, "CHANNEL", id) or resume.annonce end
        local groupe = LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
        if groupe then resume.annonce = R.Envoyer(SUJET, {}, groupe) or resume.annonce end
    end
    Synchro.Relancer(true)
    -- Personne a joindre : il n'y a pas de flux a suivre, le bouton le dit
    -- tout de suite au lieu de compter 0/0 pendant CALME secondes.
    if not resume.annonce then suivi = nil end
    return resume
end

LCM.WhenReady(function()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end
    LCM.Reseau.Ecouter(SUJET, function(expediteur)
        if expediteur == LCM.PlayerId() then return end
        if not LCM.Reseau.Connu(expediteur) then return end
        if Synchro.Relancer() > 0 and LCM.Info then
            LCM.Info(string.format("%s relance la synchronisation.", tostring(expediteur)))
        end
    end)
end)
