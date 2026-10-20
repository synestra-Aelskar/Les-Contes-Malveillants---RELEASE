-- Les outils partages du maitre du jeu : barres, compteurs, annonces, notes.
--
-- Repris des « Outils » du Panel MJ de Necronicon (Master.lua : Barres,
-- Compteurs, Annonce, Notes), cette fois en entier (le MJ, 20 octobre 2026).
-- La premiere reprise n'avait garde qu'un libelle et une valeur : tout partait
-- au groupe des la creation, dans une barre verte de taille fixe. Il manquait
-- donc l'essentiel de l'outil — son APPARENCE (ce que la table doit voir) et
-- sa PORTEE (qui doit le voir).
--
-- Ses Documents et Dessins ne sont pas repris : les documents ont deja leur
-- fenetre ici, et le dessin demandait une toile qu'on n'a pas.
--
-- Ce qu'un outil porte est decrit UNE fois, dans `Outils.CHAMPS` : le panneau
-- du MJ y construit son editeur, et `Verifier` y lit ses bornes. Deux
-- descriptions auraient fini par se contredire.
--
-- Un outil se cree, se regle, puis s'AFFICHE — et c'est l'affichage qui
-- choisit sa portee : moi seul, le groupe, le raid, ou des joueurs nommes.
-- Tant qu'il n'est pas affiche, il n'existe que chez le MJ ; une fois affiche,
-- chaque reglage repart tout seul a ceux qui le voient.
--
-- Ce fichier vit dans l'addon PRINCIPAL : c'est le joueur qui RECOIT, et il
-- n'a pas le compagnon MJ. Creer, lui, n'est permis qu'au MJ. La bibliotheque
-- (ce qu'on garde d'une seance a l'autre) vit chez le MJ seul
-- (LesContesMalveillants_MJ/Outils.lua).
--
-- Tout vit en memoire vive : un compteur de rounds ou une jauge de rituel
-- durent une scene, pas une campagne. Seules les PLACES des fenetres chez le
-- joueur sont gardees — on ne replace pas ses barres a chaque scene.
--
-- Les messages :
--   outil    MJ -> groupe, raid ou un joueur   l'outil en entier
--   outil-   MJ -> les memes                   { id }   retirer
--   annonce  MJ -> les memes                   l'annonce en entier
--   outils?  joueur -> groupe                  {}       « renvoyez-moi tout »

local _, LCM = ...

local Outils = {}
LCM.Outils = Outils

Outils.SORTES = { barre = "Barre", compteur = "Compteur", note = "Note" }
-- L'ordre des sous-onglets du panneau, et celui des listes.
Outils.ORDRE = { "barre", "compteur", "annonce", "note" }

-- Qui voit l'outil. « local » ne part sur aucun canal : l'outil s'affiche chez
-- le MJ seul, ce qui sert a le regler avant de le montrer.
Outils.PORTEES = {
    { id = "local",   label = "Moi seul" },
    { id = "groupe",  label = "Groupe" },
    { id = "raid",    label = "Raid" },
    { id = "joueurs", label = "Joueurs choisis" },
}

local PORTEE_CONNUE = {}
for _, p in ipairs(Outils.PORTEES) do PORTEE_CONNUE[p.id] = p.label end
Outils.NomPortee = function(id) return PORTEE_CONNUE[tostring(id or "")] end

-- ===== Ce qu'un outil porte ================================================
-- `nature` : texte, texte_long, nombre, couleur (RRVVBB), choix, icone.
-- `min` / `max` bornent un nombre ; `max` borne la longueur d'un texte.

local AFFICHAGES = {
    { id = "valeur",      label = "Valeur" },
    { id = "pourcentage", label = "Pourcentage" },
    { id = "cache",       label = "Cachée" },
}

local ALIGNEMENTS = {
    { id = "gauche", label = "Gauche" },
    { id = "centre", label = "Centré" },
    { id = "droite", label = "Droite" },
}

Outils.CHAMPS = {
    barre = {
        { cle = "libelle", label = "Libellé", nature = "texte", max = 40, defaut = "Nouvelle barre" },
        { cle = "minimum", label = "Minimum", nature = "nombre", defaut = 0 },
        { cle = "maximum", label = "Maximum", nature = "nombre", defaut = 100 },
        { cle = "valeur", label = "Valeur", nature = "nombre", defaut = 50 },
        { cle = "pas", label = "Pas", nature = "nombre", min = 0.01, max = 1000, defaut = 1 },
        { cle = "affichage", label = "Valeur affichée", nature = "choix",
          options = AFFICHAGES, defaut = "valeur" },
        { cle = "couleur", label = "Remplissage", nature = "couleur", defaut = "43C56B" },
        { cle = "couleurFond", label = "Fond", nature = "couleur", defaut = "1B1F24" },
        { cle = "largeur", label = "Largeur", nature = "nombre", min = 140, max = 800, defaut = 320 },
        { cle = "hauteur", label = "Hauteur", nature = "nombre", min = 28, max = 140, defaut = 44 },
    },
    compteur = {
        { cle = "libelle", label = "Libellé", nature = "texte", max = 40, defaut = "Nouveau compteur" },
        { cle = "valeur", label = "Valeur", nature = "nombre", defaut = 0 },
        { cle = "pas", label = "Pas", nature = "nombre", min = 0.01, max = 1000, defaut = 1 },
        { cle = "couleur", label = "Couleur", nature = "couleur", defaut = "FFD76A" },
        { cle = "police", label = "Taille du texte", nature = "nombre", min = 10, max = 42, defaut = 18 },
    },
    note = {
        { cle = "libelle", label = "Titre", nature = "texte", max = 40, defaut = "Nouvelle note" },
        { cle = "texte", label = "Texte", nature = "texte_long", max = 600, defaut = "" },
        { cle = "alignement", label = "Alignement", nature = "choix",
          options = ALIGNEMENTS, defaut = "gauche" },
        { cle = "couleurFond", label = "Fond", nature = "couleur", defaut = "0B0A08" },
        { cle = "largeur", label = "Largeur", nature = "nombre", min = 220, max = 820, defaut = 360 },
        { cle = "hauteur", label = "Hauteur", nature = "nombre", min = 150, max = 720, defaut = 280 },
    },
    annonce = {
        { cle = "libelle", label = "Titre", nature = "texte", max = 40, defaut = "Annonce" },
        { cle = "texte", label = "Texte", nature = "texte_long", max = 200, defaut = "" },
        { cle = "icone", label = "Icône", nature = "icone", defaut = "" },
        { cle = "couleurFond", label = "Fond", nature = "couleur", defaut = "1C1208" },
        { cle = "couleurTitre", label = "Titre", nature = "couleur", defaut = "F2E6C7" },
        { cle = "couleurTexte", label = "Texte", nature = "couleur", defaut = "E0D1A6" },
        { cle = "policeTitre", label = "Taille du titre", nature = "nombre", min = 10, max = 40, defaut = 20 },
        { cle = "police", label = "Taille du texte", nature = "nombre", min = 10, max = 32, defaut = 16 },
        { cle = "largeur", label = "Largeur", nature = "nombre", min = 200, max = 720, defaut = 420 },
    },
}

-- Les plafonds de texte, encore lus ailleurs.
Outils.LIBELLE_MAX, Outils.TEXTE_MAX, Outils.ANNONCE_MAX = 40, 600, 200

function Outils.Champs(sorte) return Outils.CHAMPS[tostring(sorte or "")] end

function Outils.Champ(sorte, cle)
    for _, champ in ipairs(Outils.Champs(sorte) or {}) do
        if champ.cle == cle then return champ end
    end
end

-- Un outil neuf, tous ses champs a leur defaut.
function Outils.Defauts(sorte)
    local o = { sorte = sorte }
    for _, champ in ipairs(Outils.Champs(sorte) or {}) do o[champ.cle] = champ.defaut end
    return o
end

-- ===== Lire et ecrire une valeur ===========================================

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Une couleur en trois nombres de 0 a 1. Sert au joueur comme au MJ (l'apercu
-- de son editeur) : une seule lecture du RRVVBB.
function Outils.Teinte(hexa, defaut)
    local h = tostring(hexa or ""):gsub("^#", ""):upper()
    if not h:match("^%x%x%x%x%x%x$") then h = tostring(defaut or "FFFFFF"):gsub("^#", ""):upper() end
    if not h:match("^%x%x%x%x%x%x$") then h = "FFFFFF" end
    return tonumber(h:sub(1, 2), 16) / 255,
           tonumber(h:sub(3, 4), 16) / 255,
           tonumber(h:sub(5, 6), 16) / 255
end

-- Verifie UNE valeur d'apres la description de son champ. Rend la valeur mise
-- en forme, ou nil et la raison. Un refus se dit : une barre a 12 sur 10 n'est
-- pas ramenee a 10 en douce, et une largeur de 2000 n'est pas rabotee a 800 —
-- sinon le MJ croit avoir regle ce qu'il n'a pas regle.
function Outils.Lire(sorte, cle, valeur)
    local champ = Outils.Champ(sorte, cle)
    if not champ then return nil, "champ inconnu." end
    if champ.nature == "nombre" then
        local n = tonumber(valeur)
        if not n then return nil, string.format("%s : il faut un nombre.", champ.label) end
        if champ.min and n < champ.min then
            return nil, string.format("%s : %s au moins.", champ.label, tostring(champ.min))
        end
        if champ.max and n > champ.max then
            return nil, string.format("%s : %s au plus.", champ.label, tostring(champ.max))
        end
        return n
    end
    if champ.nature == "couleur" then
        local h = tostring(valeur or ""):gsub("^#", ""):upper()
        if not h:match("^%x%x%x%x%x%x$") then
            return nil, string.format("%s : une couleur s'écrit RRVVBB (%s).", champ.label, champ.defaut)
        end
        return h
    end
    if champ.nature == "choix" then
        for _, option in ipairs(champ.options or {}) do
            if option.id == valeur then return valeur end
        end
        return nil, string.format("%s : choix inconnu.", champ.label)
    end
    -- Texte, texte long, icone : on tronque au plafond. Ce n'est pas un refus
    -- en douce — un texte plus long ne tiendrait pas dans un message, et le
    -- champ de saisie borne deja la frappe.
    local t = tostring(valeur or "")
    if champ.cle == "libelle" and Texte(t) == "" then
        return nil, string.format("%s : il en faut un.", champ.label)
    end
    if champ.max and #t > champ.max then t = t:sub(1, champ.max) end
    return t
end

-- Verifie un outil en entier, et le met en forme. nil et la raison au premier
-- refus.
local function Verifier(o)
    if type(o) ~= "table" then return nil, "outil illisible." end
    local sorte = tostring(o.sorte or "")
    if not Outils.Champs(sorte) then return nil, "sorte d'outil inconnue." end
    local propre = { sorte = sorte }
    for _, champ in ipairs(Outils.Champs(sorte)) do
        local brut = o[champ.cle]
        if brut == nil then brut = champ.defaut end
        local valeur, raison = Outils.Lire(sorte, champ.cle, brut)
        if valeur == nil and raison then return nil, raison end
        propre[champ.cle] = valeur
    end
    -- Les deux regles qu'aucun champ ne peut porter seul.
    if sorte == "barre" then
        if propre.maximum <= propre.minimum then
            return nil, "le maximum doit dépasser le minimum."
        end
        if propre.valeur < propre.minimum or propre.valeur > propre.maximum then
            return nil, string.format("la valeur doit rester entre %s et %s.",
                tostring(propre.minimum), tostring(propre.maximum))
        end
    end
    if sorte == "annonce" and Texte(propre.texte) == "" then
        return nil, "l'annonce est vide."
    end
    return propre
end
Outils.Verifier = Verifier

-- ===== Le reseau ===========================================================

-- Les cles courtes du message. Un outil complet depasserait les 255 octets d'un
-- message de jeu : Reseau.Envoyer le decoupe, mais une cle de dix lettres
-- repetee huit fois coute un morceau de plus pour rien.
local CLES = {
    libelle = "l", valeur = "v", minimum = "n", maximum = "m", pas = "p",
    affichage = "a", couleur = "c", couleurFond = "f", largeur = "w", hauteur = "h",
    police = "s", policeTitre = "st", texte = "t", icone = "ic",
    couleurTitre = "ct", couleurTexte = "cx", alignement = "g",
}
local DEPUIS_CLE = {}
for longue, courte in pairs(CLES) do DEPUIS_CLE[courte] = longue end

local function Paquet(o)
    local d = { id = o.id, k = o.sorte }
    for _, champ in ipairs(Outils.Champs(o.sorte) or {}) do
        local valeur = o[champ.cle]
        -- Ce qui vaut son defaut ne voyage pas : le receveur le remettra.
        if valeur ~= nil and valeur ~= champ.defaut then d[CLES[champ.cle]] = valeur end
    end
    return d
end
Outils.Paquet = Paquet

-- L'inverse, en se mefiant de tout : le message vient du reseau.
local function Depuis(d)
    local sorte = tostring(d and d.k or "")
    if not Outils.Champs(sorte) then return nil end
    local o = Outils.Defauts(sorte)
    o.id = Texte(d.id)
    if o.id == "" then return nil end
    for courte, valeur in pairs(d) do
        local longue = DEPUIS_CLE[courte]
        if longue then
            local propre = Outils.Lire(sorte, longue, valeur)
            if propre ~= nil then o[longue] = propre end
        end
    end
    return o
end

local function Canal(portee)
    -- Hors raid, « raid » n'a pas de canal a lui : on prend celui du groupe
    -- plutot que de ne rien envoyer.
    if portee == "raid" and IsInRaid and IsInRaid() then return "RAID" end
    return LCM.Combat.CanalGroupe()
end

-- Expedie un outil (ou une annonce) a qui doit le voir. true, ou false et la
-- raison.
local function Expedier(sujet, donnees, portee, cibles, joueur)
    -- Un renvoi vise UN joueur : il demande, on lui rend.
    if joueur then
        return LCM.Reseau.Envoyer(sujet, donnees, "WHISPER", joueur, { etale = true })
    end
    if portee == "local" then return true end
    if portee == "joueurs" then
        local liste = type(cibles) == "table" and cibles or {}
        if #liste == 0 then return false, "aucun joueur choisi." end
        local envoye = false
        for _, nom in ipairs(liste) do
            if Texte(nom) ~= "" and LCM.Reseau.Envoyer(sujet, donnees, "WHISPER", nom, { etale = true }) then
                envoye = true
            end
        end
        if not envoye then return false, "personne n'a pu être joint." end
        return true
    end
    local canal = Canal(portee)
    if not canal then return false, "hors groupe : personne à qui l'envoyer." end
    return LCM.Reseau.Envoyer(sujet, donnees, canal, nil, { etale = true })
end

-- ===== Cote MJ =============================================================

local miens, compteur = {}, 0

local function Prevenir()
    if Outils.onChange then Outils.onChange() end
end

function Outils.Liste(sorte)
    if not sorte then return miens end
    local out = {}
    for _, o in ipairs(miens) do if o.sorte == sorte then out[#out + 1] = o end end
    return out
end

function Outils.Get(id)
    for _, o in ipairs(miens) do if o.id == id then return o end end
end

-- Chez soi : ce qu'on s'affiche a soi-meme passe par la meme porte que ce
-- qu'on recoit, sous son propre nom. Sans quoi la portee « Moi seul »
-- demanderait un second chemin d'affichage, qui finirait par ne plus
-- ressembler a celui des joueurs.
local function Soi() return LCM.PlayerId() end
local Recevoir, Oublier

-- Outils.Creer("barre", { libelle = "Rituel", maximum = 10, valeur = 0 })
-- Rend l'outil, ou nil et la raison. Creer ne montre rien : c'est Afficher qui
-- choisit qui le voit.
function Outils.Creer(sorte, champs)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local brut = {}
    for cle, valeur in pairs(type(champs) == "table" and champs or {}) do brut[cle] = valeur end
    brut.sorte = sorte
    local o, raison = Verifier(brut)
    if not o then return nil, raison end
    compteur = compteur + 1
    o.id = "o" .. compteur
    o.portee, o.cibles, o.visible = "local", {}, false
    miens[#miens + 1] = o
    Prevenir()
    return o
end

-- Pose un outil tout fait : la bibliotheque du MJ s'en sert pour recharger une
-- barre gardee d'une seance a l'autre.
function Outils.Poser(modele)
    if type(modele) ~= "table" then return nil, "outil illisible." end
    local champs = {}
    for _, champ in ipairs(Outils.Champs(modele.sorte) or {}) do champs[champ.cle] = modele[champ.cle] end
    return Outils.Creer(modele.sorte, champs)
end

-- Change UN champ. Si l'outil est affiche, le changement repart aussitot a ceux
-- qui le voient : on regle une barre pendant que la table la regarde.
function Outils.Definir(id, cle, valeur)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    local essai = {}
    for _, champ in ipairs(Outils.Champs(o.sorte) or {}) do essai[champ.cle] = o[champ.cle] end
    essai.sorte, essai[cle] = o.sorte, valeur
    local propre, raison = Verifier(essai)
    if not propre then return false, raison end
    for _, champ in ipairs(Outils.Champs(o.sorte)) do o[champ.cle] = propre[champ.cle] end
    Prevenir()
    if o.visible then return Outils.Rafraichir(o) end
    return true
end

function Outils.Ajouter(id, pas)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    if o.sorte ~= "barre" and o.sorte ~= "compteur" then
        return false, "cet outil n'a pas de valeur."
    end
    local delta = tonumber(pas)
    if delta == nil then delta = tonumber(o.pas) or 1 end
    return Outils.Definir(id, "valeur", (tonumber(o.valeur) or 0) + delta)
end

-- Poser la portee SANS rien renvoyer : Afficher s'en sert avant son propre
-- envoi. Les deux chemins renvoyaient chacun le leur, et un outil cible
-- partait deux fois au meme joueur.
local function PoserPortee(o, portee, cibles)
    portee = tostring(portee or "")
    if not PORTEE_CONNUE[portee] then return false, "portée inconnue." end
    o.portee = portee
    if cibles ~= nil then
        local liste = {}
        for _, nom in ipairs(type(cibles) == "table" and cibles or {}) do
            if Texte(nom) ~= "" then liste[#liste + 1] = Texte(nom) end
        end
        o.cibles = liste
    end
    return true
end

-- Qui verra l'outil, quand on l'affichera.
function Outils.Cibler(id, portee, cibles)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    local ok, raison = PoserPortee(o, portee, cibles)
    if not ok then return false, raison end
    Prevenir()
    if o.visible then return Outils.Rafraichir(o) end
    return true
end

-- Renvoie un outil deja affiche a ceux qui le voient.
function Outils.Rafraichir(o)
    if type(o) == "string" then o = Outils.Get(o) end
    if not o then return false, "outil inconnu." end
    local ok, raison = true, nil
    if o.portee ~= "local" then ok, raison = Expedier("outil", Paquet(o), o.portee, o.cibles) end
    -- Chez le MJ aussi : il voit ce que la table voit.
    Recevoir(Soi(), Paquet(o))
    return ok, raison
end

function Outils.Afficher(id, portee, cibles)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    if portee then
        local ok, raison = PoserPortee(o, portee, cibles)
        if not ok then return false, raison end
    end
    o.visible = true
    local ok, raison = Outils.Rafraichir(o)
    -- Un envoi qui echoue ne laisse pas l'outil « affiche » : le MJ le croirait
    -- a l'ecran de la table.
    if not ok then
        o.visible = false
        Oublier(Soi(), o.id)
    end
    Prevenir()
    return ok, raison
end

function Outils.Masquer(id)
    local o = Outils.Get(id)
    if not o then return false, "outil inconnu." end
    o.visible = false
    Oublier(Soi(), o.id)
    if o.portee ~= "local" then Expedier("outil-", { id = o.id }, o.portee, o.cibles) end
    Prevenir()
    return true
end

function Outils.Retirer(id)
    for rang, o in ipairs(miens) do
        if o.id == id then
            if o.visible then Outils.Masquer(id) end
            table.remove(miens, rang)
            Prevenir()
            return true
        end
    end
    return false, "outil inconnu."
end

-- Une annonce ne se garde pas : elle s'affiche chez chacun et s'efface. On
-- accepte aussi un simple texte, qui reste le geste le plus courant.
function Outils.Annoncer(annonce)
    if not LCM.IsMaster() then return false, "réservé au maître du jeu." end
    if type(annonce) ~= "table" then annonce = { texte = annonce } end
    local brut = {}
    for cle, valeur in pairs(annonce) do brut[cle] = valeur end
    brut.sorte = "annonce"
    local propre, raison = Verifier(brut)
    if not propre then return false, raison end
    propre.id = "a" .. tostring((time and time()) or 0)
    local portee = PORTEE_CONNUE[tostring(annonce.portee or "")] and annonce.portee or "groupe"
    local ok, pourquoi = Expedier("annonce", Paquet(propre), portee, annonce.cibles)
    -- Le MJ voit son annonce, meme quand elle ne part nulle part : c'est ainsi
    -- qu'il la regle avant de la montrer.
    if Outils.onAnnonce then Outils.onAnnonce(Soi(), propre) end
    if not ok and portee ~= "local" then return false, pourquoi end
    return true
end

-- Tout renvoyer : a un joueur qui arrive, ou au groupe apres un incident.
function Outils.Renvoyer(joueur)
    local n = 0
    local function pour(o)
        -- Un joueur qui demande ne recoit que ce qui lui etait destine.
        if not joueur or o.portee ~= "joueurs" then return true end
        for _, nom in ipairs(o.cibles or {}) do
            if Texte(nom):lower() == Texte(joueur):lower() then return true end
        end
        return false
    end
    for _, o in ipairs(miens) do
        if o.visible and o.portee ~= "local" and pour(o) then
            Expedier("outil", Paquet(o), o.portee, o.cibles, joueur)
            n = n + 1
        end
    end
    return true, n
end

-- ===== Cote joueur =========================================================

-- Ce qui a ete recu, par « expediteur#id », avec qui l'a envoye.
Outils.recus = {}
local arrivee = 0

-- Les outils recus, dans l'ordre d'arrivee.
function Outils.Recus()
    local out = {}
    for _, o in pairs(Outils.recus) do out[#out + 1] = o end
    table.sort(out, function(a, b) return a.rang < b.rang end)
    return out
end

function Outils.Demander()
    local canal = LCM.Combat.CanalGroupe()
    if not canal then return false end
    return LCM.Reseau.Envoyer("outils?", {}, canal)
end

Recevoir = function(expediteur, d)
    local o = Depuis(d)
    if not o then return end
    local cle = tostring(expediteur) .. "#" .. o.id
    local garde = Outils.recus[cle]
    if not garde then
        arrivee = arrivee + 1
        garde = { rang = arrivee }
        Outils.recus[cle] = garde
    end
    local rang = garde.rang
    for champ in pairs(garde) do garde[champ] = nil end
    for champ, valeur in pairs(o) do garde[champ] = valeur end
    garde.rang, garde.cle, garde.mj = rang, cle, expediteur
    Prevenir()
end
Outils.Recevoir = Recevoir

Oublier = function(expediteur, id)
    local cle = tostring(expediteur) .. "#" .. tostring(id)
    if Outils.recus[cle] then
        Outils.recus[cle] = nil
        Prevenir()
    end
end
Outils.Oublier = Oublier

-- La place ou le joueur a tire une barre. Gardee : on ne replace pas ses
-- fenetres a chaque scene. Rangee par sorte et libelle, et non par identifiant :
-- « o3 » ne veut rien dire d'une seance a l'autre.
function Outils.ClePlace(o)
    return tostring(o and o.sorte or "?") .. "/" .. tostring(o and o.libelle or "?")
end

function Outils.Place(o)
    if not LCM.db then return nil end
    local places = LCM.db.outilsPlaces
    return type(places) == "table" and places[Outils.ClePlace(o)] or nil
end

-- `place` : { point, relPoint, x, y }, comme UI.Fenetre garde les siennes.
function Outils.NoterPlace(o, place)
    if type(place) ~= "table" then return end
    if LCM.EnsureDatabase then LCM.EnsureDatabase() end
    if not LCM.db then return end
    LCM.db.outilsPlaces = type(LCM.db.outilsPlaces) == "table" and LCM.db.outilsPlaces or {}
    LCM.db.outilsPlaces[Outils.ClePlace(o)] = {
        point = tostring(place.point or "CENTER"),
        relPoint = tostring(place.relPoint or place.point or "CENTER"),
        x = tonumber(place.x) or 0, y = tonumber(place.y) or 0,
    }
end

LCM.WhenReady(function()
    local R = LCM.Reseau
    R.Ecouter("outil", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        Recevoir(expediteur, d)
    end)
    R.Ecouter("outil-", function(expediteur, d)
        Oublier(expediteur, d and d.id)
    end)
    R.Ecouter("annonce", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local annonce = Depuis(d)
        if not annonce or Texte(annonce.texte) == "" then return end
        -- Qui annonce est toujours dit : on ne prouve pas qu'un expediteur est
        -- MJ, on le montre.
        LCM.Info(string.format("Annonce de %s : %s", tostring(expediteur), annonce.texte))
        if Outils.onAnnonce then Outils.onAnnonce(expediteur, annonce) end
    end)
    R.Ecouter("outils?", function(expediteur)
        if not LCM.IsMaster() then return end
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        Outils.Renvoyer(expediteur)
    end)
    -- Un joueur qui arrive (ou recharge) rattrape ce qui est deja affiche.
    if not LCM.IsMaster() then Outils.Demander() end
end)
