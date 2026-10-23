-- La fenetre Inventaires, et la fenetre d'un sac ouvert.
--
-- Reprise de Necronicon (Inventory.lua : CreateInventoryFrame,
-- RefreshInventoryUI, OpenBagWindow, GetEntryContextMenu) avec ses mesures :
--
--   * la fenetre : 420 x 360 (360 x 240 au moins), un bandeau d'onglets sous
--     le titre (Sacs, Saccoches, Devises : les onglets du template), la
--     bascule Grille / Liste ; en grille, des cartes de 112 de haut, une
--     colonne tous les 180, 8 d'ecart — icone de 36 en haut, nom et
--     description centres ; en liste, des lignes de 60 ;
--   * un clic sur un sac l'OUVRE : sa fenetre (380 x 300, cadre « panel »),
--     ses cases de 46, 8 d'ecart — les places du sac, puis ses places de
--     devise (« DEV ») ; bascule Grille / Liste ;
--   * on DEPOSE en glissant une ligne du compendium sur un emplacement ou une
--     case ; un clic sur un emplacement vide propose la liste du compendium ;
--     le clic droit ouvre le menu (Voir, Ouvrir, Quantite, Deplacer >,
--     Supprimer).
--
-- Ranger, deplacer et supprimer sont des gestes de MJ, comme l'equipement : le
-- joueur voit, ouvre et consulte. Ce qui n'est pas repris : l'edition des
-- onglets et des emplacements (structure, Data/Inventaire.lua), « Donner... »
-- (pas de reseau), « Scinder la pile », les colonnes personnalisees des sacs.

local _, LCM = ...
local UI = LCM.UI
local GameTooltip = UI.Infobulle()
local Inv = LCM.Inventaire

-- Un glissement qui vient du COMPENDIUM fabrique un objet : c'est au MJ. Un
-- glissement qui vient d'un sac ou d'un emplacement le DEPLACE : il porte son
-- `origine`, et c'est un geste de joueur ordinaire (12 octobre 2026).
local function Creation(objet)
    return type(objet) ~= "table" or objet.origine == nil
end

local Ecran = {}
UI.Inventaires = Ecran

local LARGEUR, HAUTEUR, MIN_L, MIN_H = 420, 360, 360, 240
local CARTE_H_GRILLE, CARTE_H_LISTE, ECART, COLONNE = 112, 60, 8, 180
-- La colonne des six emplacements, a gauche.
local COLONNE_SACS, LIGNE_CONTENU = 168, 26
local CASE, ECART_CASE = 46, 8
-- Un emplacement vide, comme sur la fiche, au coffre et a la creation. C'etait
-- l'icone par defaut de Necronicon (135956), un tas de cranes dores qu'on
-- prenait pour un objet (16 octobre 2026).
local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function Action(parent, texte, largeur, hauteur)
    return UI.Bouton(parent, texte, largeur or math.max(18, #tostring(texte) * 7 + 10), hauteur or 18)
end

local function Peindre(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

-- Le son des sacs de WoW (ContainerFrame les joue a l'ouverture et a la
-- fermeture d'un sac) : nos sacs s'ouvrent comme les siens (20 octobre 2026).
-- Sur le canal SFX, celui que le joueur regle pour les bruits d'interface.
-- Un sac dont l'emplacement s'est vide se referme dans son propre OnShow : il
-- n'a alors rien ouvert, et ne doit pas sonner l'ouverture apres la fermeture.
local function Sonner(f)
    f:HookScript("OnShow", function()
        if f:IsShown() and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN, "SFX") end
    end)
    f:HookScript("OnHide", function()
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE, "SFX") end
    end)
end

local function Entite() return LCM.Entities.Self() end

-- Les six emplacements d'affilee : deux sacs puis quatre sacoches. L'onglet a
-- disparu de l'ecran le 3 octobre 2026, mais la categorie reste le modele —
-- c'est elle qui dit combien d'emplacements et ce qu'ils acceptent.
-- L'ordre de la colonne, par sections (le MJ, 23 octobre 2026) : la ceinture
-- EN HAUT — tout en bas, sous quatre sacoches, on ne la voyait pas en ouvrant
-- l'inventaire —, puis les sacs, les sacoches, et la poche des cristaux
-- entames. Une categorie absente de cette liste vient apres, dans son ordre.
local ORDRE_SECTIONS = { "ceintures", "sacs", "saccoches", "cristaux_usage" }

-- Le bandeau qui ouvre chaque section : un nom, une couleur legere, et a
-- droite son remplissage (« 0/2 »). Ceinture en bleu, Sac en marron et le
-- titre « Saccoches » sont du MJ ; la couleur des Saccoches et la poche ont
-- recu les leurs pour se distinguer.
local SECTIONS = {
    ceintures      = { titre = "Ceinture", couleur = { 0.22, 0.42, 0.78 } },
    sacs           = { titre = "Sac", couleur = { 0.50, 0.32, 0.16 } },
    saccoches      = { titre = "Saccoches", couleur = { 0.22, 0.45, 0.28 } },
    -- « Cristaux » suffit au bandeau (le MJ) : la carte dessous dit le reste.
    cristaux_usage = { titre = "Cristaux", couleur = { 0.45, 0.30, 0.70 } },
}
local BANDEAU_H = 20

local function CategoriesEnOrdre()
    local out, vues = {}, {}
    for _, id in ipairs(ORDRE_SECTIONS) do
        local categorie = Inv.Get(id)
        if categorie then out[#out + 1] = categorie vues[id] = true end
    end
    for _, categorie in ipairs(Inv.categories) do
        if not vues[categorie.id] then out[#out + 1] = categorie end
    end
    return out
end

-- Ce que montre chaque section (le MJ, 23 octobre 2026) :
--   * la ceinture : toujours son emplacement ;
--   * « Cristaux en cours d'usage » : seulement s'il tient un cristal ;
--   * Sac, Saccoches : les emplacements OCCUPES, plus UN seul vide pour
--     accueillir le suivant. Rien d'equipe : un seul emplacement, « 0/2 » ;
--     un sac equipe : le deuxieme apparait, « 1/2 ». Plein : plus de vide.
local function Emplacements()
    local out, entity = {}, Entite()
    for _, categorie in ipairs(CategoriesEnOrdre()) do
        local videMontre = false
        for index = 1, Inv.Capacite(categorie.id) do
            local e = Inv.Emplacement(entity, categorie.id, index)
            local montrer
            if categorie.ceinture then
                montrer = true
            elseif categorie.cristaux then
                montrer = e and type(e.cases) == "table" and next(e.cases) ~= nil
            elseif e then
                montrer = true
            elseif not videMontre then
                montrer, videMontre = true, true
            end
            if montrer then
                out[#out + 1] = { onglet = categorie.id, index = index, categorie = categorie }
            end
        end
    end
    return out
end

-- Comment on nomme un emplacement vide : « Sac », « Sacoche », au singulier.
-- « Emplacement » ne disait pas ce qu'on peut y mettre.
local SINGULIER = { sacs = "Sac", saccoches = "Sacoche", ceintures = "Ceinture" }
local function NomVide(categorie)
    if categorie.contient == "devise" then return "Emplacement devise" end
    return SINGULIER[categorie.id] or categorie.label
end

local function Refuser(raison) if raison then LCM.Alerte(raison) end end

-- La charge de chaque cristal d'une pile de « Cristaux en cours d'usage »
-- (« 62 %, 40 % »), ou nil pour une case ordinaire : un cristal plein ne
-- montre pas de pourcentage (le MJ, 23 octobre 2026).
local function Charges(c)
    if not (c and Inv.Entame and Inv.Entame(c)) then return nil end
    -- Une pile de la poche n'a qu'UN pourcentage (Core/Inventaire.lua) : on
    -- le dit une fois. Une pile d'avant cette regle peut en avoir plusieurs.
    local morceaux, vus = {}, {}
    for _, x in ipairs(c.exemplaires) do
        local pourcent = LCM.Lanterne.Pourcent(x)
        if pourcent and not vus[pourcent] then
            vus[pourcent] = true
            morceaux[#morceaux + 1] = pourcent .. " %"
        end
    end
    return #morceaux > 0 and table.concat(morceaux, ", ") or nil
end

-- La categorie du compendium d'une reference, pour « Voir ».
local function Voir(ref, ancre)
    local element, categorie = LCM.Compendium.Resoudre(ref)
    if element and categorie then UI.Compendium.Voir(categorie, element, ancre) end
end

local function LireOuVoir(ref, ancre)
    if tostring(ref or ""):match("^livres/") and UI.Livres then
        UI.Livres.Ouvrir(ref)
    else
        Voir(ref, ancre)
    end
end

-- Les vues choisies (grille / liste) durent le temps de la session : une
-- preference d'ecran, pas une donnee du personnage.
local vues = {}
local function Vue(cle, defaut) return vues[cle] or defaut end

-- ===== Un objet de sac : le prendre, le donner, le jeter ===================

-- Ce qu'une case contient, sous la forme d'un glissement (UI.Glisser) : il
-- sait quitter sa case et y revenir. Le glisser-deposer, l'echange et le menu
-- du clic droit partagent cet objet-la.
local function ObjetDeCase(onglet, index, place)
    local ici = Inv.Emplacement(Entite(), onglet, index)
    local c = ici and Inv.Case(ici, place)
    if not c then return nil end
    local element = LCM.Compendium.Resoudre(c.ref)
    local ref, quantite = c.ref, c.quantite
    local exemplaires = LCM.Copie(LCM.Exemplaires.Assurer(c))
    return {
        icone = element and LCM.Icone(element.icone) or nil,
        nom = element and element.label or tostring(ref),
        ref = ref, quantite = quantite, element = element, exemplaires = exemplaires,
        origine = { onglet = onglet, index = index, case = place },
        retirer = function() Inv.Vider(Entite(), onglet, index, place) end,
        rendre = function() Inv.Ranger(Entite(), onglet, index, place, ref, quantite or 1, exemplaires) end,
    }
end

-- Une monnaie glissee depuis la BOURSE : elle n'a pas de case d'origine, elle
-- a un solde. La poser dans un sac, c'est la materialiser — on demande combien,
-- puisqu'on en a rarement une seule (le MJ, 19 octobre 2026).
local function DeLaBourse(objet)
    local o = type(objet) == "table" and objet.origine
    return o and o.bourse and o.devise or nil
end

local function AccepteBourse(objet, ici, vers)
    local devise = DeLaBourse(objet)
    if not Inv.Contenant(ici) then return false, "aucun sac ici." end
    local ref = LCM.Bourse.Ref(devise)
    local deja = Inv.Case(ici, vers.case)
    if deja and deja.ref ~= ref then return false, "cette case est déjà occupée." end
    local ok, raison = Inv.Accepte(ici, vers.case, ref)
    if not ok then return false, raison end
    if LCM.Bourse.Solde(Entite(), devise) < 1 then return false, "ta bourse n'en a plus." end
    return true
end

-- Ou une monnaie lachee sur un SAC se pose : dans la pile de cette monnaie si
-- le sac en porte deja une, sinon dans sa premiere case libre. On ne cherche
-- pas ailleurs : c'est sur CE sac qu'on l'a lachee.
local function CaseDeBourse(devise, onglet, index)
    local ref = LCM.Bourse.Ref(devise)
    local ici = Inv.Emplacement(Entite(), onglet, index)
    if not Inv.Contenant(ici) then return nil end
    local libre
    for n = 1, Inv.Cases(ici) do
        local dedans = Inv.Case(ici, n)
        if dedans then
            if dedans.ref == ref then return n end
        elseif not libre and Inv.Accepte(ici, n, ref) then
            libre = n
        end
    end
    return libre
end

local function AccepteBourseSac(objet, onglet, index)
    local devise = DeLaBourse(objet)
    if not Inv.Contenant(Inv.Emplacement(Entite(), onglet, index)) then
        return false, "aucun sac ici."
    end
    if not LCM.Bourse.EstMateriel(devise) then
        return false, "cette monnaie ne se transporte pas : elle reste dans la bourse."
    end
    if LCM.Bourse.Solde(Entite(), devise) < 1 then return false, "ta bourse n'en a plus." end
    if not CaseDeBourse(devise, onglet, index) then
        return false, "aucune case libre dans ce sac."
    end
    return true
end

local function DeposerBourse(objet, vers)
    local devise = DeLaBourse(objet)
    local entite = Entite()
    local element = LCM.Devises.Get(devise)
    local nom = element and element.label or devise
    UI.Demande():Demander(string.format("Sortir combien de %s de la bourse ?", nom),
        LCM.Bourse.Solde(entite, devise), function(texte)
            local ok, raison = LCM.Bourse.Materialiser(entite, devise, texte, vers)
            if ok then
                Ecran.Actualiser()
                if UI.Bourse and UI.Bourse.frame then UI.Bourse.frame:Afficher() end
            end
            return ok, raison
        end)
end

-- Jeter, c'est detruire : on le demande toujours. Et au « oui », on verifie
-- que l'objet est encore dans sa case — entre la question et la reponse, il a
-- pu partir dans un echange ou changer de sac. On ne jette jamais ce qui a
-- pris sa place.
local confirmation
local function Jeter(objet)
    local o = type(objet) == "table" and objet.origine
    if not (o and (o.case or o.emplacement)) then return false end
    confirmation = confirmation or UI.Confirmer(UIParent, "", "Détruire")
    local q = tonumber(objet.quantite) or 1
    confirmation:Demander(string.format("Détruire « %s »%s ?\nOn ne le récupère pas.",
        tostring(objet.nom), q > 1 and (" x" .. q) or ""), function()
        local ici = Inv.Emplacement(Entite(), o.onglet, o.index)
        if o.emplacement then
            -- Ce que porte l'emplacement (un sac, une ceinture) : encore le
            -- meme, et toujours vide la ou il faut — Retirer le reverifie.
            local contenant = Inv.Contenant(ici)
            if not (contenant and contenant.ref == objet.ref) then
                Refuser("l'objet n'est plus à sa place : rien n'a été détruit.")
                return
            end
            local ok, raison = Inv.Retirer(Entite(), o.onglet, o.index)
            if not ok then Refuser(raison) return end
            Ecran.FermerSac(o.onglet, o.index)
        else
            local c = ici and Inv.Case(ici, o.case)
            if not (c and c.ref == objet.ref) then
                Refuser("l'objet n'est plus à sa place : rien n'a été détruit.")
                return
            end
            Inv.Vider(Entite(), o.onglet, o.index, o.case)
        end
        LCM.Info(string.format("%s détruit.", tostring(objet.nom)))
        Ecran.Actualiser()
    end)
    return true
end
Ecran.Jeter = Jeter

-- A qui l'on peut donner : sa cible si c'est un joueur, puis le groupe. La
-- bourse s'en sert aussi (UI.Inventaires.Destinataires).
local function Destinataires()
    local out, vus = {}, {}
    local moi = UnitName and UnitName("player")
    local function Ajouter(unite)
        if UnitExists and not UnitExists(unite) then return end
        if UnitIsPlayer and not UnitIsPlayer(unite) then return end
        local nom, royaume = UnitName(unite)
        if not nom or nom == moi then return end
        local qui = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
        if not vus[qui] then
            vus[qui] = true
            out[#out + 1] = qui
        end
    end
    Ajouter("target")
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do Ajouter(prefixe .. i) end
    return out
end
Ecran.Destinataires = Destinataires

-- Le menu d'un objet de sac, pour tout le monde : Voir, Échanger, Jeter. Le MJ
-- y ajoute ses gestes (`extras`). Le jeter ne passait que par le glisser dans
-- le vide, et l'echange que par le lacher sur quelqu'un : deux gestes qu'on
-- ne devine pas (13 octobre 2026).
-- « Échanger » : un sous-menu des destinataires, ou une entree qui dit
-- pourquoi il n'y en a pas. `bloque` : la raison pour laquelle l'objet ne peut
-- pas partir (un sac pas vide).
local function OptionEchanger(objet, bloque)
    local donner = LCM.Echange and LCM.Echange.Ecran and LCM.Echange.Ecran.Donner
    if not donner then return nil end
    if bloque then
        return { label = "Échanger", action = function() Refuser(bloque) end }
    end
    local cibles = {}
    for _, qui in ipairs(Destinataires()) do
        cibles[#cibles + 1] = { label = qui, action = function() donner(qui, objet) end }
    end
    if #cibles > 0 then return { label = "Échanger >", sous = cibles } end
    return { label = "Échanger", action = function()
        Refuser("personne à qui le donner : cible un joueur ou forme un groupe.")
    end }
end

-- Scinder une pile (le MJ, 16 octobre 2026) : un petit panneau demande
-- combien en sortir, et le nouveau tas va dans `vers` (une case designee par
-- un Maj + glisser) ou dans la premiere case libre (le clic droit). Au
-- « Scinder », on reverifie que la pile est toujours la : entre la question et
-- la reponse, elle a pu partir.
local function Scinder(objet, vers)
    local o = objet.origine
    local ref = objet.scinder and objet.scinder.ref or objet.ref
    local total = tonumber(objet.quantite) or 1
    local d = UI.Demande()
    Ecran.demandeScinder = d
    d:Demander(string.format("Scinder en combien ? « %s » x%d", tostring(objet.nom), total),
        math.floor(total / 2), function(texte)
            local ici = Inv.Emplacement(Entite(), o.onglet, o.index)
            local c = ici and Inv.Case(ici, o.case)
            if not (c and c.ref == ref) then return false, "la pile n'est plus à sa place." end
            local ok, raison = Inv.Scinder(Entite(), o.onglet, o.index, o.case, texte, vers)
            if ok then Ecran.Actualiser() end
            return ok, raison
        end, "Scinder")
    return true
end
Ecran.Scinder = Scinder

-- Maj + glisser une pile : on la SCINDE vers la case ou on la lache. Le
-- glissement ne porte ni reference ni `retirer` : aucune autre cible (un
-- emplacement, la fiche, un coffre, quelqu'un) ne le prend pour un objet a
-- deplacer — seules les cases de sac lisent `scinder`.
local function GlisserPile(objet)
    if not (objet and IsShiftKeyDown and IsShiftKeyDown()) then return objet end
    if (tonumber(objet.quantite) or 1) < 2 then return objet end
    objet.scinder = { ref = objet.ref }
    objet.nom = objet.nom .. " — scinder"
    objet.ref, objet.element, objet.retirer, objet.rendre = nil, nil, nil, nil
    return objet
end

-- Ce que dit une case de sac a une pile qu'on scinde (Maj + glisser), et ce
-- qu'elle en fait. `ici` : l'emplacement de la case, `vers` : la case.
local function AccepteScission(objet, ici, vers)
    local o = objet.origine
    if o.onglet == vers.onglet and o.index == vers.index and o.case == vers.case then return true end
    if not Inv.Contenant(ici) then return false, "aucun sac ici." end
    local deja = Inv.Case(ici, vers.case)
    if deja then
        -- Sur une pile du meme objet : on y ajoute, s'il reste de la place.
        if deja.ref ~= objet.scinder.ref then return false, "cette case est déjà occupée." end
        local n, raison = Inv.PeutEmpiler(Entite(), o.onglet, o.index, o.case, vers.onglet, vers.index, vers.case)
        if not n then return false, raison end
        return true
    end
    return Inv.Accepte(ici, vers.case, objet.scinder.ref)
end
local function DeposerScission(objet, vers)
    local o = objet.origine
    if o.onglet == vers.onglet and o.index == vers.index and o.case == vers.case then return end
    Scinder(objet, vers)
end

-- Une pile lachee sur une pile du MEME objet se reempile (le MJ, 16 octobre
-- 2026) : jusqu'a la pile maximale, le reste demeure dans la case de depart.
-- Elle disait « cette case est déjà occupée ». Nil si ce n'est pas le cas :
-- la case juge alors comme d'habitude.
local function Empilable(objet, ici, vers)
    local o = objet.origine
    if not (o and o.case and objet.ref) then return nil end
    local deja = Inv.Case(ici, vers.case)
    if not (deja and deja.ref == objet.ref) then return nil end
    if o.onglet == vers.onglet and o.index == vers.index and o.case == vers.case then return nil end
    return true
end
local function AccepteEmpiler(objet, vers)
    local o = objet.origine
    local n, raison = Inv.PeutEmpiler(Entite(), o.onglet, o.index, o.case, vers.onglet, vers.index, vers.case)
    if not n then return false, raison end
    return true
end
local function Empiler(objet, vers)
    local o = objet.origine
    local ok, raison = Inv.Empiler(Entite(), o.onglet, o.index, o.case, vers.onglet, vers.index, vers.case)
    if not ok then Refuser(raison) end
    Ecran.Actualiser()
end

-- Une entree du COMPENDIUM lachee sur une pile de la meme entree : une de
-- plus dans la pile (le MJ, 23 octobre 2026). Elle disait « cette case est
-- déjà occupée », alors que la case tenait justement cela. Elle n'a pas de
-- case d'origine : c'est un don, pas un deplacement. Nil si ce n'est pas le
-- cas : la case juge alors comme d'habitude.
local function DuCompendium(objet, ici, vers)
    if objet.origine or not objet.ref or objet.groupe or objet.scinder then return nil end
    local deja = Inv.Case(ici, vers.case)
    return deja and deja.ref == objet.ref or nil
end
local function AccepteAjout(ici, vers)
    local deja = Inv.Case(ici, vers.case)
    -- Un cristal plein ne rejoint pas une pile de cristaux entames.
    if Inv.Entame and Inv.Entame(deja) then
        return false, "un cristal entamé et un cristal plein ne s'empilent pas ensemble."
    end
    local element = LCM.Compendium.Resoudre(deja.ref)
    local max = element and tonumber(element.pileMax)
    if max and (tonumber(deja.quantite) or 1) >= max then
        return false, string.format("la pile est déjà pleine (%d).", max)
    end
    return true
end
local function Ajouter(ici, vers)
    local ok, raison = AccepteAjout(ici, vers)
    if ok then
        local deja = Inv.Case(ici, vers.case)
        ok, raison = Inv.Quantite(Entite(), vers.onglet, vers.index, vers.case, (tonumber(deja.quantite) or 1) + 1)
    end
    if not ok then Refuser(raison) end
    Ecran.Actualiser()
end

local function MenuObjet(ancre, onglet, index, place, extras)
    local objet = ObjetDeCase(onglet, index, place)
    if not objet then return end
    local options = { { label = "Voir", action = function() Voir(objet.ref, ancre) end } }
    if tostring(objet.ref or ""):match("^livres/") then
        options[#options + 1] = { label = "Lire", action = function() UI.Livres.Ouvrir(objet.ref) end }
    end
    options[#options + 1] = OptionEchanger(objet)
    -- Regler une pile, c'est en fabriquer ou en detruire : geste de MJ. La
    -- fenetre d'un sac l'offrait deja, ce menu-ci non — on ne savait pas
    -- laquelle des deux fenetres le permettait (19 octobre 2026).
    if LCM.IsMaster() then
        options[#options + 1] = { label = "Quantité : " .. tostring(objet.quantite or 1),
            action = function()
                UI.Demande():Demander("Quantité de la pile", objet.quantite or 1, function(texte)
                    local ok, raison = Inv.Quantite(Entite(), onglet, index, place, texte)
                    if ok then Ecran.Actualiser() end
                    return ok, raison
                end)
            end }
    end
    -- Une pile de monnaie retourne en bourse : la pile n'est qu'une forme,
    -- pas une autre monnaie (le MJ, 19 octobre 2026). On vise CETTE pile :
    -- avec deux bourses d'ecus dans deux sacs, vider la premiere en cliquant
    -- sur la seconde serait incomprehensible.
    local deviseId = tostring(objet.ref or ""):match("^devises/(.+)$")
    if deviseId and LCM.Bourse and LCM.Bourse.EstMateriel(deviseId) then
        local ici = { onglet = onglet, index = index, case = place }
        options[#options + 1] = { label = "Mettre en bourse", action = function()
            UI.Demande():Demander("Mettre combien en bourse ?", objet.quantite or 1, function(texte)
                local ok, raison = LCM.Bourse.Encaisser(Entite(), deviseId, texte, ici)
                if ok then Ecran.Actualiser() end
                return ok, raison
            end)
        end }
    end
    for _, extra in ipairs(extras or {}) do options[#options + 1] = extra end
    if (tonumber(objet.quantite) or 1) > 1 then
        options[#options + 1] = { label = "Scinder", action = function() Scinder(objet) end }
    end
    options[#options + 1] = { label = "Détruire", action = function() Jeter(objet) end }
    UI.MenuContexte():Ouvrir(ancre, options)
end

-- ===== La selection ========================================================
-- Comme dans l'explorateur de Windows (20 octobre 2026) : un clic met une
-- case en surbrillance, Ctrl + clic en ajoute ou en retire une, Maj + clic
-- prend tout ce qui va de la case en surbrillance a celle qu'on clique. Le
-- double-clic, lui, ouvre l'objet — c'etait le clic simple avant.
--
-- La selection n'appartient a aucune fenetre : on clique dans le sac A, Ctrl
-- + clic dans B, C et D, et les quatre restent choisies. Glisser l'une les
-- emmene toutes ; le clic droit les deplace, les donne ou les detruit
-- ensemble (Inv.DeplacerGroupe, Inv.ViderGroupe : tout ou rien).
--
-- Chaque case retient ce qu'on y a VU (`ref`) : une case qui s'est videe ou
-- remplie d'autre chose sort d'elle-meme de la selection. On ne deplace jamais
-- un objet qui n'est plus la.

local Selection = { cases = {}, ancre = nil }
Ecran.Selection = Selection

local function Cle(onglet, index, case) return onglet .. ":" .. index .. ":" .. case end

-- Toutes les cases occupees, dans l'ordre ou l'inventaire les montre : les
-- onglets, leurs emplacements, puis les cases. C'est la ligne que parcourt
-- Maj + clic, d'un sac a l'autre.
local function CasesDansLOrdre(entity)
    local out = {}
    for _, categorie in ipairs(Inv.categories) do
        for index = 1, Inv.Capacite(categorie.id) do
            local e = Inv.Emplacement(entity, categorie.id, index)
            for case = 1, (Inv.Contenant(e) and Inv.Cases(e) or 0) do
                local c = Inv.Case(e, case)
                if c then out[#out + 1] = { onglet = categorie.id, index = index, case = case, ref = c.ref } end
            end
        end
    end
    return out
end

-- Oublie ce qui a change depuis qu'on l'a choisi.
local function Nettoyer()
    local entity = Entite()
    for cle, s in pairs(Selection.cases) do
        local c = Inv.Case(Inv.Emplacement(entity, s.onglet, s.index), s.case)
        if not (c and c.ref == s.ref) then Selection.cases[cle] = nil end
    end
    if Selection.ancre and not Selection.cases[Selection.ancre] then Selection.ancre = nil end
end

-- Cette case est-elle choisie, et tient-elle toujours ce qu'on y a vu ?
function Selection.Marque(onglet, index, case, ref)
    local s = Selection.cases[Cle(onglet, index, case)]
    return s ~= nil and ref ~= nil and s.ref == ref
end

-- La selection, dans l'ordre de l'inventaire ; `tete` (une case) passe devant.
function Selection.Liste(tete)
    Nettoyer()
    local out = {}
    for _, s in ipairs(CasesDansLOrdre(Entite())) do
        if Selection.cases[Cle(s.onglet, s.index, s.case)] then out[#out + 1] = s end
    end
    if tete then
        for i, s in ipairs(out) do
            if s.onglet == tete.onglet and s.index == tete.index and s.case == tete.case then
                table.insert(out, 1, table.remove(out, i))
                break
            end
        end
    end
    return out
end

function Selection.Nombre()
    Nettoyer()
    local n = 0
    for _ in pairs(Selection.cases) do n = n + 1 end
    return n
end

function Selection.Vider()
    Selection.cases, Selection.ancre = {}, nil
end

-- Plusieurs cases choisies, dont celle-ci : les gestes valent pour toutes.
function Selection.Groupe(onglet, index, case)
    return Selection.cases[Cle(onglet, index, case)] ~= nil and Selection.Nombre() > 1
end

-- Un clic gauche sur une case. Les touches tenues disent lequel des trois.
function Selection.Cliquer(onglet, index, case)
    local c = Inv.Case(Inv.Emplacement(Entite(), onglet, index), case)
    local ctrl = IsControlKeyDown and IsControlKeyDown()
    local maj = IsShiftKeyDown and IsShiftKeyDown()
    local cle = Cle(onglet, index, case)
    Nettoyer()
    if not c then
        -- Une case vide : un clic simple deselectionne tout, comme cliquer
        -- dans le blanc d'un dossier. Avec une touche, on ne perd rien.
        if not (ctrl or maj) then Selection.Vider() end
    elseif ctrl then
        if Selection.cases[cle] then
            Selection.cases[cle] = nil
        else
            Selection.cases[cle] = { onglet = onglet, index = index, case = case, ref = c.ref }
        end
        Selection.ancre = cle
    elseif maj and Selection.ancre then
        -- De l'ancre a cette case, dans l'ordre de l'inventaire. L'ancre ne
        -- bouge pas : un second Maj + clic refait la plage depuis elle.
        local ordre = CasesDansLOrdre(Entite())
        local debut, fin
        for i, s in ipairs(ordre) do
            local k = Cle(s.onglet, s.index, s.case)
            if k == Selection.ancre then debut = i end
            if k == cle then fin = i end
        end
        if debut and fin then
            if debut > fin then debut, fin = fin, debut end
            Selection.cases = {}
            for i = debut, fin do
                local s = ordre[i]
                Selection.cases[Cle(s.onglet, s.index, s.case)] = s
            end
        end
    else
        Selection.cases = { [cle] = { onglet = onglet, index = index, case = case, ref = c.ref } }
        Selection.ancre = cle
    end
    Ecran.Actualiser()
end

-- Le glissement d'une selection : il porte toutes les cases, celle qu'on a
-- prise en tete. Sans reference ni `retirer` : seules les cases et les
-- emplacements de sacs savent le recevoir — une autre cible (la fiche, un
-- coffre) n'en prendrait qu'un, et laisserait croire qu'elle a pris le reste.
local function GlisserSelection(objet)
    local o = objet.origine
    objet.groupe = Selection.Liste({ onglet = o.onglet, index = o.index, case = o.case })
    objet.nom = string.format("%d objets", #objet.groupe)
    objet.ref, objet.element, objet.retirer, objet.rendre, objet.exemplaires = nil, nil, nil, nil, nil
    return objet
end

-- Le glissement qui part d'une case : la selection si cette case en fait
-- partie avec d'autres, sinon la case seule (ou sa scission, Maj + glisser).
local function GlisserDepuis(onglet, index, case)
    local objet = ObjetDeCase(onglet, index, case)
    if not objet then return nil end
    if Selection.Groupe(onglet, index, case) then return GlisserSelection(objet) end
    return GlisserPile(objet)
end

local function AccepteGroupe(objet, vers)
    return Inv.PeutDeplacerGroupe(Entite(), objet.groupe, vers)
end

local function DeposerGroupe(objet, vers)
    local ok, raison = Inv.DeplacerGroupe(Entite(), objet.groupe, vers)
    if not ok then Refuser(raison) return end
    Selection.Vider()
    Ecran.Actualiser()
end

-- Les noms de la selection, pour la question : « Minerai x3, Capuche… ».
local function Noms(liste)
    local noms = {}
    for i, s in ipairs(liste) do
        if i > 6 then noms[#noms + 1] = "…" break end
        local c = Inv.Case(Inv.Emplacement(Entite(), s.onglet, s.index), s.case)
        local element = c and LCM.Compendium.Resoudre(c.ref)
        local q = c and tonumber(c.quantite) or 1
        noms[#noms + 1] = (element and element.label or tostring(s.ref)) .. (q > 1 and (" x" .. q) or "")
    end
    return table.concat(noms, ", ")
end

local confirmationGroupe
local function JeterSelection(liste)
    confirmationGroupe = confirmationGroupe or UI.Confirmer(UIParent, "", "Détruire")
    Ecran.confirmationGroupe = confirmationGroupe
    confirmationGroupe:Demander(string.format("Détruire %d objets ?\n%s\nOn ne les récupère pas.",
        #liste, Noms(liste)), function()
        local ok, raison = Inv.ViderGroupe(Entite(), liste)
        if not ok then Refuser(raison) return end
        LCM.Info(string.format("%d objets détruits.", raison))
        Selection.Vider()
        Ecran.Actualiser()
    end)
end

-- Le menu d'une selection : les memes gestes qu'un objet, pour toutes.
local function MenuSelection(ancre, tete)
    local liste = Selection.Liste(tete)
    local entity = Entite()
    local options = {}
    -- Deplacer > : vers chaque sac porte qui n'est pas celui de TOUTES.
    local cibles = {}
    for _, categorie in ipairs(Inv.categories) do
        for i = 1, Inv.Capacite(categorie.id) do
            local contenant = Inv.Contenant(Inv.Emplacement(entity, categorie.id, i))
            if contenant then
                local onglet, index = categorie.id, i
                cibles[#cibles + 1] = { label = contenant.element and contenant.element.label or contenant.id,
                    action = function()
                        local ok, raison = Inv.DeplacerGroupe(Entite(), liste, { onglet = onglet, index = index })
                        if not ok then Refuser(raison) return end
                        Selection.Vider()
                        Ecran.Actualiser()
                    end }
            end
        end
    end
    if #cibles > 0 then options[#options + 1] = { label = "Déplacer >", sous = cibles } end
    -- Échanger > : tout part dans le meme echange.
    local donner = LCM.Echange and LCM.Echange.Ecran and LCM.Echange.Ecran.Donner
    if donner then
        local qui = {}
        for _, nom in ipairs(Destinataires()) do
            qui[#qui + 1] = { label = nom, action = function()
                local lot = {}
                for _, s in ipairs(liste) do
                    local objet = ObjetDeCase(s.onglet, s.index, s.case)
                    if objet then lot[#lot + 1] = objet end
                end
                donner(nom, { lot = lot, nom = string.format("%d objets", #lot) })
                Selection.Vider()
                Ecran.Actualiser()
            end }
        end
        options[#options + 1] = #qui > 0 and { label = "Échanger >", sous = qui }
            or { label = "Échanger", action = function()
                Refuser("personne à qui les donner : cible un joueur ou forme un groupe.")
            end }
    end
    options[#options + 1] = { label = string.format("Détruire (%d)", #liste), action = function() JeterSelection(liste) end }
    UI.MenuContexte():Ouvrir(ancre, options)
end
Ecran.MenuSelection = MenuSelection

-- Le clic droit sur une case : le menu de la selection si elle en fait
-- partie, sinon celui de l'objet seul — et la case devient la selection, pour
-- qu'on voie de quoi parle le menu.
local function MenuDeCase(ancre, onglet, index, case, extras)
    if Selection.Groupe(onglet, index, case) then
        MenuSelection(ancre, { onglet = onglet, index = index, case = case })
        return
    end
    local c = Inv.Case(Inv.Emplacement(Entite(), onglet, index), case)
    if c and not Selection.Marque(onglet, index, case, c.ref) then
        Selection.cases = { [Cle(onglet, index, case)] = { onglet = onglet, index = index, case = case, ref = c.ref } }
        Selection.ancre = Cle(onglet, index, case)
        Ecran.Actualiser()
    end
    MenuObjet(ancre, onglet, index, case, extras)
end

-- La surbrillance d'une case choisie : posee une fois a la creation, montree
-- ou cachee a chaque rafraichissement.
local function Surbrillance(cadre)
    cadre.choisie = UI.Aplat(cadre, { 0.95, 0.78, 0.30, 0.22 }, "ARTWORK")
    cadre.choisie:SetAllPoints(cadre)
    cadre.choisie:Hide()
end

-- Un autre personnage : d'autres sacs, plus rien de choisi.
LCM.Entities.EcouterSoi(function() Selection.Vider() end)

-- Ce que porte un emplacement (un sac, une sacoche, l'objet d'une ceinture),
-- sous la forme d'un glissement : il quitte l'emplacement s'il est vide, et y
-- revient. Nil pour une ceinture nue : ses cases de base ne partent pas.
local function ObjetDEmplacement(onglet, index)
    local e = Inv.Emplacement(Entite(), onglet, index)
    local contenant = Inv.Contenant(e)
    if not (contenant and contenant.ref) then return nil end
    local element = contenant.element
    local id = contenant.id
    return {
        icone = element and LCM.Icone(element.icone) or nil,
        nom = element and element.label or tostring(contenant.ref),
        ref = contenant.ref, quantite = 1, element = element,
        origine = { onglet = onglet, index = index, emplacement = true },
        retirer = function()
            Inv.Retirer(Entite(), onglet, index)
            Ecran.FermerSac(onglet, index)
        end,
        rendre = function() Inv.Poser(Entite(), onglet, index, contenant.tente and contenant.ref or id, true) end,
    }
end

-- Lache dans le vide — sur le monde, ni sur une fenetre ni sur quelqu'un :
-- on propose de jeter. Seul un objet de SAC se jette ainsi ; une entree du
-- compendium n'est a personne, et ce qu'on porte se retire d'abord.
-- Un SAC porte (la carte d'un emplacement) lache dans le vide se pose AU SOL,
-- avec tout son contenu, et devient un coffre que n'importe qui peut ouvrir ou
-- ramasser (Core/SacsAuSol.lua ; le MJ, 16 octobre 2026). On le demande.
local confirmationSol
local function PoserAuSol(objet)
    local o = objet.origine
    confirmationSol = confirmationSol or UI.Confirmer(UIParent, "", "Poser au sol")
    Ecran.confirmationSol = confirmationSol
    confirmationSol:Demander(string.format("Poser « %s » au sol ?\nSon contenu reste dedans : "
        .. "n'importe qui pourra l'ouvrir, y prendre, ou le ramasser.", tostring(objet.nom)), function()
        local ok, raison = LCM.SacsAuSol.Lacher(o.onglet, o.index)
        if not ok then Refuser(raison) return end
        Ecran.FermerSac(o.onglet, o.index)
        Ecran.Actualiser()
    end)
    return true
end
Ecran.PoserAuSol = PoserAuSol

if UI.Glisser then
    UI.Glisser.DansLeVide = function(objet)
        if Creation(objet) or not objet.origine then return false end
        -- Une pile qu'on scinde, lachee hors d'une case : on n'en fait rien.
        -- Une selection non plus : elle se range dans un sac, ou se detruit
        -- par le clic droit.
        if objet.scinder or objet.groupe then return false end
        local foci = (GetMouseFoci and GetMouseFoci())
            or (GetMouseFocus and { GetMouseFocus() }) or {}
        local focus = foci[1]
        if focus and focus ~= WorldFrame then return false end
        if objet.origine.emplacement and LCM.SacsAuSol then return PoserAuSol(objet) end
        if not objet.origine.case then return false end
        -- Un objet lache hors de l'inventaire TOMBE : il se ramasse (le MJ,
        -- 16 octobre 2026). Le detruire, c'est le clic droit, « Détruire ».
        if LCM.SacsAuSol then
            local ok, raison = LCM.SacsAuSol.LacherObjet(objet)
            if not ok then Refuser(raison) end
            Ecran.Actualiser()
            return true
        end
        return Jeter(objet)
    end
end

-- ===== Une carte d'emplacement ============================================

local function Carte(f)
    local c = CreateFrame("Button", nil, f.colonne.contenu)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.fond = UI.Aplat(c, { 0, 0, 0, 0.2 })
    c.fond:SetAllPoints(c)
    UI.BordureFine(c, 0.30)
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormal")
    c.nom:SetWordWrap(false)
    c.description = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    c.description:SetWordWrap(true)
    c.survol = UI.Aplat(c, UI.C.survol, "HIGHLIGHT")
    c.survol:SetAllPoints(c)
    -- Un emplacement glisse sur un autre : on reorganise. Il s'y deplace, ou
    -- les deux echangent leur place, chacun avec son contenu (Inv.Deplacer).
    local function Reorganise(objet)
        return objet.origine and objet.origine.emplacement
    end
    local function MemeEmplacement(objet)
        return objet.origine.onglet == c.onglet and objet.origine.index == c.index
    end
    -- Un objet (d'une case, ou du compendium) lache sur un emplacement qui
    -- porte deja un sac : il se transvase dedans.
    local function Transvase(objet)
        if Reorganise(objet) or not objet.ref then return false end
        -- La ceinture n'est jamais vide (ses cases de base) : un objet
        -- « ceinture » lache dessus s'y EQUIPE, il n'entre pas dans ses cases.
        local categorie = Inv.Get(c.onglet)
        if categorie and categorie.ceinture and tostring(objet.ref):match("^sacs/")
            and LCM.Sacs.EstCeinture(tostring(objet.ref):match("^sacs/(.+)$")) then
            return false
        end
        return Inv.Contenant(Inv.Emplacement(Entite(), c.onglet, c.index)) ~= nil
    end
    -- Il vient deja de ce sac : rien a faire.
    local function MemeSac(objet)
        local o = objet.origine
        return o and o.case and o.onglet == c.onglet and o.index == c.index
    end

    -- On y depose un sac (ou une devise) glisse depuis le compendium.
    UI.Glisser.Cible(c, function(objet)
        -- Une monnaie venue de la BOURSE se materialise dans ce sac. Sans
        -- cette branche, « transvaser » l'aurait prise pour un objet qu'on
        -- possede deja — et en aurait range un sans debiter la bourse
        -- (19 octobre 2026, le jour ou le fantome a recu une reference).
        if DeLaBourse(objet) then return AccepteBourseSac(objet, c.onglet, c.index) end
        -- Une selection lachee sur un sac porte : tout y entre.
        if objet.groupe then return AccepteGroupe(objet, { onglet = c.onglet, index = c.index }) end
        if Reorganise(objet) then
            if MemeEmplacement(objet) then return true end
            local depart, arrivee = Inv.Get(objet.origine.onglet), Inv.Get(c.onglet)
            if not (depart and arrivee) then return false, "onglet inconnu." end
            if depart.ceinture or arrivee.ceinture then
                return false, "la ceinture ne change pas d'emplacement."
            end
            if depart.contient ~= arrivee.contient then
                return false, string.format("l'onglet %s n'accepte pas ça.", arrivee.label)
            end
            -- Chacun sa place : ce qui arrive, et ce qui repart en echange.
            local entite = Entite()
            local ok, raison = Inv.PeutPorter(c.onglet,
                Inv.Emplacement(entite, objet.origine.onglet, objet.origine.index))
            if not ok then return false, raison end
            return Inv.PeutPorter(objet.origine.onglet, Inv.Emplacement(entite, c.onglet, c.index))
        end
        if Creation(objet) and not LCM.IsMaster() then
            return false, "sortir un objet du compendium est un geste du maître du jeu."
        end
        -- Un emplacement qui porte deja un sac : ce qu'on y lache passe DEDANS
        -- (on transvase), on ne l'equipe pas (le MJ, 16 octobre 2026).
        if Transvase(objet) then
            if MemeSac(objet) then return true end
            -- A blanc, sur une copie : tient-il entier dans ce sac ?
            return Inv.Transvaser(LCM.Copie(Entite()), c.onglet, c.index, objet.ref, objet.quantite or 1)
        end
        local categorie = Inv.Get(c.onglet or Inv.categories[1].id)
        local voulu = categorie.contient == "sac" and "sacs" or "devises"
        -- Une tente s'equipe comme un sac, mais seulement sur une sacoche.
        local tente = c.onglet == "saccoches" and tostring(objet.ref or ""):match("^tentes/")
        if not tente and not tostring(objet.ref or ""):match("^" .. voulu .. "/") then
            return false, categorie.contient == "sac" and "cet emplacement n'accepte qu'un sac."
                or "cet emplacement n'accepte qu'une devise."
        end
        local sac = not tente and LCM.Sacs.Get(objet.element and objet.element.id)
        local ceinture = sac and LCM.Sacs.EstCeinture(sac)
        if categorie.ceinture then
            if not ceinture then return false, "cet emplacement n'accepte qu'une ceinture." end
            if Inv.Emplacement(Entite(), c.onglet, c.index).sac then
                return false, "une ceinture est déjà portée : retire-la d'abord."
            end
            return true
        end
        if ceinture then return false, "une ceinture se porte sur l'emplacement Ceinture." end
        if Inv.Emplacement(Entite(), c.onglet, c.index) then return false, "cet emplacement est déjà occupé." end
        -- Un sac dans Sacs, une sacoche dans Saccoches (Inv.PeutPorter).
        if sac then return Inv.PeutPorter(c.onglet, { sac = sac.id }) end
        return true
    end, function(objet)
        if DeLaBourse(objet) then
            local place = CaseDeBourse(DeLaBourse(objet), c.onglet, c.index)
            if place then
                DeposerBourse(objet, { onglet = c.onglet, index = c.index, case = place })
            end
            return
        end
        if objet.groupe then DeposerGroupe(objet, { onglet = c.onglet, index = c.index }) return end
        if Reorganise(objet) then
            if MemeEmplacement(objet) then return end
            local o = objet.origine
            local ok, raison = Inv.Deplacer(Entite(), o.onglet, o.index, c.onglet, c.index)
            if not ok then Refuser(raison) return end
            -- Les fenetres de sac ouvertes montraient l'ancienne place.
            Ecran.FermerSac(o.onglet, o.index)
            Ecran.FermerSac(c.onglet, c.index)
            Ecran.Actualiser()
            return
        end
        if Transvase(objet) then
            if MemeSac(objet) then return end
            -- Il quitte sa place, puis entre dans ce sac ; s'il n'y tient pas,
            -- il y retourne.
            if objet.retirer then objet.retirer() end
            local ok, raison = Inv.Transvaser(Entite(), c.onglet, c.index, objet.ref, objet.quantite or 1, objet.exemplaires)
            if not ok then
                if objet.rendre then objet.rendre() end
                Refuser(raison)
            end
            Ecran.Actualiser()
            return
        end
        local tente = tostring(objet.ref or ""):match("^tentes/")
        -- Un sac pris dans une CASE demenage : il quitte sa case, puis se pose.
        -- Il etait pose sans quitter la case — on se retrouvait avec deux sacs
        -- (13 octobre 2026). S'il ne se pose pas, il y retourne.
        if objet.retirer then objet.retirer() end
        local ok, raison = Inv.Poser(Entite(), c.onglet, c.index, tente and objet.ref or objet.element.id)
        if not ok then
            if objet.rendre then objet.rendre() end
            Refuser(raison)
        end
        Ecran.Actualiser()
    end)
    -- ... et une SOURCE : on prend un sac porte pour le poser sur un autre
    -- emplacement. Un sac PLEIN ne peut que changer d'emplacement : son contenu
    -- ne se jette pas, ne se donne pas, ne se range pas dans une case avec lui.
    -- Sans reference ni `retirer`, aucune autre cible ne l'accepte — sinon il
    -- serait pose ailleurs sans quitter sa place, donc double.
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnDragStart", function(self)
        if not self.onglet then return end
        local objet = ObjetDEmplacement(self.onglet, self.index)
        if not objet then return end
        if not Inv.PeutRetirer(Entite(), self.onglet, self.index) then
            objet.ref, objet.element, objet.retirer, objet.rendre = nil, nil, nil, nil
        end
        UI.Glisser.Commencer(objet)
    end)
    c:SetScript("OnDragStop", function() UI.Glisser.Lacher() end)
    c:SetScript("OnClick", function(self, bouton) f:CliquerEmplacement(self, bouton) end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.nom:GetText() or "Emplacement", 1, 0.82, 0)
        -- La description entiere : la carte n'en montre qu'une ligne.
        local texte = self.description:GetText()
        if texte and texte ~= "" then GameTooltip:AddLine(texte, 0.8, 0.75, 0.62, true) end
        if self.aide then GameTooltip:AddLine(self.aide, 0.55, 0.55, 0.55, true) end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return c
end

-- ===== La fenetre principale ==============================================

local function Construire()
    local f = UI.Fenetre("inventaires", "Inventaires", LARGEUR, HAUTEUR, { x = 240, y = 20 },
        { enTeteSimple = true, redimensionnable = true })
    Ecran.frame = f
    -- L'emplacement qu'on regarde. Plus d'onglets : les six sont la, et c'est
    -- celui qu'on choisit qui remplit la droite. Nil : le premier sac
    -- (Rafraichir).
    f.choisi = nil
    f.choix = UI.Choix("inventaire", "")

    f.filet = UI.Filet(f)
    f.filet:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    f.filet:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)

    -- A gauche, les six emplacements en colonne ; a droite, ce que contient
    -- celui qu'on a choisi. Les onglets « Sacs » et « Saccoches » ont disparu
    -- le 3 octobre 2026 : deux onglets pour six cases, c'etait un clic de plus
    -- pour voir la moitie de ce qu'on porte.
    f.colonne = UI.Defilement(f)
    f.colonne:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -46)
    f.colonne:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 16)
    f.colonne:SetWidth(COLONNE_SACS)
    f.cartes = {}

    f.titreContenu = UI.Texte(f, "", UI.C.titre, "GameFontNormalSmall")
    f.titreContenu:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + COLONNE_SACS + 16, -46)
    f.titreContenu:SetJustifyH("LEFT")

    f.zone = UI.Defilement(f)
    f.lignes = {}

    -- Le compte « occupes / total » du sac ouvert, en face de son nom.
    f.occupation = UI.Texte(f, "", UI.C.titre, "GameFontNormalSmall")
    f.occupation:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -46)
    f.occupation:SetJustifyH("RIGHT")

    UI.Redimensionner(f, MIN_L, MIN_H, function() f:Rafraichir() end)
    f:HookScript("OnSizeChanged", function() if not f.enRedimension then f:Rafraichir() end end)
    f:HookScript("OnShow", function() f:Rafraichir() end)
    f:HookScript("OnHide", function() f.choix:Hide() end)
    Sonner(f)

    -- La colonne de gauche : les six emplacements, deux sacs puis quatre
    -- sacoches, chacun avec son nom et ce qu'il porte.
    function f:Colonne()
        local entity = Entite()
        local liste = Emplacements()
        local y, section = 0, nil
        for _, b in pairs(self.bandeaux) do b:Hide() end
        for rang, place in ipairs(liste) do
            -- Une nouvelle section : son bandeau d'abord.
            if place.onglet ~= section then
                section = place.onglet
                local b = self:Bandeau(place.categorie)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.colonne.contenu, "TOPLEFT", 0, -y)
                b.compte:SetText(self:Remplissage(entity, place.categorie))
                b:Show()
                y = y + BANDEAU_H + 4
            end
            local c = self.cartes[rang]
            if not c then
                c = Carte(self)
                self.cartes[rang] = c
            end
            c.rang, c.onglet, c.index = rang, place.onglet, place.index
            c:SetSize(COLONNE_SACS - 10, CARTE_H_LISTE)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", self.colonne.contenu, "TOPLEFT", 0, -y)
            y = y + CARTE_H_LISTE + 4
            self:HabillerCarte(c, entity, place.categorie,
                Inv.Emplacement(entity, place.onglet, place.index), "liste")
            -- Celui qu'on regarde se voit.
            c.fond:SetColorTexture(0, 0, 0, rang == self.choisi and 0.55 or 0.2)
            c:Show()
        end
        for rang = #liste + 1, #self.cartes do self.cartes[rang]:Hide() end
        self.colonne:Regler(y)
        return liste
    end

    -- La carte d'un emplacement, ou nil s'il n'est pas montre. Son RANG
    -- dans la colonne change avec ce qu'on equipe (un emplacement vide de
    -- plus ou de moins) : on la retrouve par ce qu'elle represente.
    function f:CarteDe(onglet, index)
        index = index or 1
        for _, c in ipairs(self.cartes) do
            if c:IsShown() and c.onglet == onglet and c.index == index then return c end
        end
    end

    -- Le bandeau d'une section, cree une fois par categorie.
    f.bandeaux = {}
    function f:Bandeau(categorie)
        local b = self.bandeaux[categorie.id]
        if b then return b end
        local def = SECTIONS[categorie.id] or { titre = categorie.label, couleur = { 0.4, 0.4, 0.4 } }
        b = CreateFrame("Frame", nil, self.colonne.contenu)
        b:SetSize(COLONNE_SACS - 10, BANDEAU_H)
        local r, v, bl = def.couleur[1], def.couleur[2], def.couleur[3]
        b.fond = UI.Aplat(b, { r, v, bl, 0.35 })
        b.fond:SetAllPoints(b)
        b.trait = UI.Aplat(b, { r, v, bl, 0.9 }, "ARTWORK")
        b.trait:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        b.trait:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        b.trait:SetHeight(1)
        b.titre = UI.Texte(b, def.titre, UI.C.titre, "GameFontNormalSmall")
        b.titre:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.compte = UI.Texte(b, "", UI.C.texte, "GameFontNormalSmall")
        b.compte:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        self.bandeaux[categorie.id] = b
        return b
    end

    -- Ce que dit le bandeau a droite : les emplacements occupes sur leur
    -- nombre (« 1/2 »). La ceinture compte l'objet pose par-dessus ses cases
    -- de base ; la poche, sans limite, dit combien de piles elle tient.
    function f:Remplissage(entity, categorie)
        local capacite = Inv.Capacite(categorie.id)
        if categorie.cristaux then
            local e = Inv.Emplacement(entity, categorie.id, 1)
            local n = 0
            for _ in pairs(e and type(e.cases) == "table" and e.cases or {}) do n = n + 1 end
            return tostring(n)
        end
        local pris = 0
        for index = 1, capacite do
            local e = Inv.Emplacement(entity, categorie.id, index)
            if categorie.ceinture then
                if e and e.sac then pris = pris + 1 end
            elseif e then
                pris = pris + 1
            end
        end
        return string.format("%d/%d", pris, capacite)
    end

    -- La droite : le contenu du sac choisi, ligne par ligne.
    function f:Contenu(place)
        local entity = Entite()
        local e = place and Inv.Emplacement(entity, place.onglet, place.index)
        local contenant = Inv.Contenant(e)
        local sac = contenant and contenant.element
        self.titreContenu:SetText(sac and sac.label or (e and e.devise and "Devise") or "")
        local total = e and Inv.Cases(e) or 0
        self.occupation:SetText(total > 0 and string.format("%d / %d",
            Inv.Occupees and Inv.Occupees(e) or self:CompterCases(e, total), total) or "")

        local y = 0
        for n = 1, total do
            local l = self.lignes[n]
            if not l then
                l = CreateFrame("Button", nil, self.zone.contenu)
                l:SetHeight(LIGNE_CONTENU)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.icone = l:CreateTexture(nil, "ARTWORK")
                l.icone:SetSize(20, 20)
                l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
                l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                -- L'etat de l'objet au BOUT de la ligne : ce qui reste de
                -- solide se lit dans le sac comme sur la fiche, sans ouvrir la
                -- carte (9 octobre 2026).
                l.etat = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
                l.etat:SetPoint("RIGHT", l, "RIGHT", -8, 0)
                l.etat:SetJustifyH("RIGHT")
                l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
                l.nom:SetPoint("RIGHT", l.etat, "LEFT", -8, 0)
                l.nom:SetJustifyH("LEFT")
                l.nom:SetWordWrap(false)
                l.survol = UI.Aplat(l, UI.C.survol, "HIGHLIGHT")
                l.survol:SetAllPoints(l)
                Surbrillance(l)
                -- On y depose une entree glissee du compendium, comme dans la
                -- fenetre d'un sac. Il manquait : c'est pourtant la que le MJ
                -- regarde le contenu, et le glisser y etait refuse sans un mot.
                -- Reposer un objet sur sa propre case n'est pas une erreur :
                -- c'est un glissement qu'on annule.
                local function MemeCase(objet)
                    local o = objet.origine
                    return o and l.place and o.onglet == l.place.onglet
                        and o.index == l.place.index and o.case == l.case
                end
                UI.Glisser.Cible(l, function(objet)
                    if Creation(objet) and not LCM.IsMaster() then
                        return false, "sortir un objet du compendium est un geste du maître du jeu."
                    end
                    local ici = l.place and Inv.Emplacement(Entite(), l.place.onglet, l.place.index)
                    if DeLaBourse(objet) then
                        if not l.place then return false, "aucun sac ici." end
                        return AccepteBourse(objet, ici,
                            { onglet = l.place.onglet, index = l.place.index, case = l.case })
                    end
                    if objet.scinder then
                        if not l.place then return false, "aucun sac ici." end
                        return AccepteScission(objet, ici,
                            { onglet = l.place.onglet, index = l.place.index, case = l.case })
                    end
                    if objet.groupe then
                        if not l.place then return false, "aucun sac ici." end
                        return AccepteGroupe(objet, { onglet = l.place.onglet, index = l.place.index, case = l.case })
                    end
                    if not Inv.Contenant(ici) then return false, "aucun sac ici." end
                    if MemeCase(objet) then return true end
                    local vers = { onglet = l.place.onglet, index = l.place.index, case = l.case }
                    if Empilable(objet, ici, vers) then return AccepteEmpiler(objet, vers) end
                    if DuCompendium(objet, ici, vers) then return AccepteAjout(ici, vers) end
                    if Inv.Case(ici, l.case) then return false, "cette case est déjà occupée." end
                    return Inv.Accepte(ici, l.case, objet.ref)
                end, function(objet)
                    local vers = { onglet = l.place.onglet, index = l.place.index, case = l.case }
                    if DeLaBourse(objet) then
                        DeposerBourse(objet, vers)
                        return
                    end
                    if objet.scinder then
                        DeposerScission(objet, vers)
                        return
                    end
                    if objet.groupe then DeposerGroupe(objet, vers) return end
                    local ici = Inv.Emplacement(Entite(), l.place.onglet, l.place.index)
                    if Empilable(objet, ici, vers) then Empiler(objet, vers) return end
                    if DuCompendium(objet, ici, vers) then Ajouter(ici, vers) return end
                    if MemeCase(objet) then return end
                    local entite = Entite()
                    -- Un objet qui vient d'ailleurs demenage : il quitte sa
                    -- place, puis on le range ici. Si le rangement echoue, il
                    -- y retourne — un objet perdu entre deux sacs serait pire
                    -- que le refus. La SOURCE sait comment partir et revenir :
                    -- une case se vide, un emplacement d'equipement se
                    -- deshabille.
                    if objet.retirer then objet.retirer() end
                    local ok, raison = Inv.Ranger(entite, l.place.onglet, l.place.index, l.case,
                        objet.ref, objet.quantite or 1, objet.exemplaires)
                    if not ok then
                        if objet.rendre then objet.rendre() end
                        Refuser(raison)
                    end
                    f:Rafraichir()
                end)

                -- ... et une SOURCE. Ces lignes-ci sont le panneau de droite de
                -- la fenetre Inventaires — c'est LA qu'on lit le contenu d'une
                -- sacoche, et donc de la qu'on veut sortir un objet. Seules les
                -- cases de la fenetre d'un sac savaient se glisser, si bien que
                -- le glisser-deposer semblait ne pas exister (5 octobre 2026).
                l:RegisterForDrag("LeftButton")
                l:SetScript("OnDragStart", function(self)
                    -- Cette fenetre montre TOUJOURS son propre inventaire
                    -- (`Entite()` rend ce qu'on joue) : y prendre un objet est
                    -- un geste de joueur. Le garde-fou etait pose ici aussi, et
                    -- le glissement ne demarrait meme pas — la destination
                    -- avait beau accepter, il n'y avait rien a deposer
                    -- (12 octobre 2026). C'est la DESTINATION qui dit ce
                    -- qu'elle autorise, pas la main qui prend.
                    if not self.place then return end
                    local objet = GlisserDepuis(self.place.onglet, self.place.index, self.case)
                    if objet then UI.Glisser.Commencer(objet) end
                end)
                l:SetScript("OnDragStop", function() UI.Glisser.Lacher() end)
                -- Clic : choisir (Ctrl, Maj : plusieurs) ; double-clic : voir ;
                -- clic droit : Voir, Échanger, Jeter — ou les gestes de la
                -- selection.
                l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                l:SetScript("OnClick", function(self, bouton)
                    if not self.place then return end
                    if bouton == "RightButton" then
                        local ici = Inv.Emplacement(Entite(), self.place.onglet, self.place.index)
                        if not (ici and Inv.Case(ici, self.case)) then return end
                        MenuDeCase(self, self.place.onglet, self.place.index, self.case)
                    else
                        Selection.Cliquer(self.place.onglet, self.place.index, self.case)
                    end
                end)
                l:SetScript("OnDoubleClick", function(self, bouton)
                    if bouton ~= "LeftButton" or not self.place then return end
                    local ici = Inv.Emplacement(Entite(), self.place.onglet, self.place.index)
                    local c = ici and Inv.Case(ici, self.case)
                    if c then LireOuVoir(c.ref, f) end
                end)
                self.lignes[n] = l
            end
            l.place, l.case = place, n
            local c = Inv.Case(e, n)
            local element = c and LCM.Compendium.Resoudre(c.ref)
            l.choisie:SetShown(c ~= nil and place ~= nil and Selection.Marque(place.onglet, place.index, n, c.ref))
            l.icone:SetTexture(element and element.icone or VIDE)
            if element then
                local quantite = tonumber(c.quantite) or 1
                -- Brise : icone rouge et « [BRISÉ] » devant le nom. On le voit
                -- dans le sac comme sur la fiche, sans ouvrir la carte.
                -- L'etat de CET objet : pour une pile, celui qui servira le
                -- premier (le plus entame).
                local exemplaire = LCM.Objets.ExemplaireDePile(c)
                local brise = UI.ObjetBrise(entity, element, exemplaire)
                local marque = brise and (UI.MARQUE_BRISE .. " ") or ""
                local charges = Charges(c)
                l.nom:SetText(marque .. (quantite > 1
                    and (element.label .. "  x" .. quantite) or element.label)
                    .. (charges and ("  (" .. charges .. ")") or ""))
                Peindre(l.nom, brise and UI.C.plein or UI.C.texte)
                UI.TeinterBrise(l.icone, brise)
                local etat, reste, plein = UI.EtatObjet(entity, element, exemplaire)
                l.etat:SetText(etat or "")
                if etat then Peindre(l.etat, UI.CouleurEtat(reste, plein)) end
            else
                l.nom:SetText(Inv.EstCaseDevise(e, n) and "Case de devise" or "Vide")
                Peindre(l.nom, UI.C.discret)
                l.etat:SetText("")
                UI.TeinterBrise(l.icone, false)
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE_CONTENU
        end
        for n = total + 1, #self.lignes do self.lignes[n]:Hide() end
        self.zone:Regler(math.max(1, y))
    end

    -- Combien de cases occupees : la fonction du noyau si elle existe, sinon on
    -- compte. (Elle n'existe pas aujourd'hui ; le jour ou elle arrive, elle
    -- gagne.)
    function f:CompterCases(e, total)
        local n = 0
        for index = 1, (total or 0) do if Inv.Case(e, index) then n = n + 1 end end
        return n
    end

    function f:Rafraichir()
        if not self:IsShown() then return end
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", self, "TOPLEFT", 12 + COLONNE_SACS + 16, -64)
        self.zone:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -28, 16)

        -- Sans choix (ou un choix disparu, comme la poche videe), c'est le
        -- premier SAC qu'on montre : la ceinture est en tete de la colonne
        -- depuis le 23 octobre 2026, mais ouvrir l'inventaire doit toujours
        -- montrer son sac.
        local places = Emplacements()
        if not self.choisi or self.choisi > #places then
            self.choisi = 1
            for rang, place in ipairs(places) do
                if place.onglet == "sacs" then self.choisi = rang break end
            end
        end
        local liste = self:Colonne()
        self:Contenu(liste[self.choisi])
        Ecran.RafraichirSacs()
    end

    function f:HabillerCarte(c, entity, categorie, e, vue)
        c.icone:ClearAllPoints()
        c.nom:ClearAllPoints()
        c.description:ClearAllPoints()
        if vue == "grille" then
            c.icone:SetSize(36, 36)
            c.icone:SetPoint("TOP", c, "TOP", 0, -10)
            c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -52)
            c.nom:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -52)
            c.nom:SetJustifyH("CENTER")
            c.description:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -2)
            c.description:SetPoint("TOPRIGHT", c.nom, "BOTTOMRIGHT", 0, -2)
            c.description:SetJustifyH("CENTER")
        else
            c.icone:SetSize(34, 34)
            c.icone:SetPoint("LEFT", c, "LEFT", 8, 0)
            c.nom:SetPoint("TOPLEFT", c.icone, "TOPRIGHT", 10, 1)
            c.nom:SetPoint("RIGHT", c, "RIGHT", -12, 0)
            c.nom:SetJustifyH("LEFT")
            c.description:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -2)
            c.description:SetPoint("RIGHT", c, "RIGHT", -12, 0)
            c.description:SetJustifyH("LEFT")
        end
        -- En liste, la carte fait 60 de haut : une ligne de description, coupee.
        -- Elle passait a la ligne sans limite et sortait de la carte
        -- (13 octobre 2026). Le texte entier est dans l'infobulle.
        c.description:SetWordWrap(vue == "grille")
        c.emplacement = e
        if not e then
            c.icone:SetTexture(VIDE)
            c.nom:SetText(NomVide(categorie))
            Peindre(c.nom, UI.C.discret)
            c.description:SetText("Emplacement disponible")
            c.aide = LCM.IsMaster()
                and (categorie.contient == "sac" and "Glisse un sac depuis le compendium."
                    or "Glisse une devise depuis le compendium.")
                or nil
            return
        end
        Peindre(c.nom, UI.C.titre)
        local contenant = Inv.Contenant(e)
        if contenant then
            local sac = contenant.element
            local total = Inv.Cases(e)
            local pleines = 0
            for _ in pairs(e.cases or {}) do pleines = pleines + 1 end
            c.icone:SetTexture(sac and sac.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
            -- Le nom et le remplissage, comme le template : « Gros sac (2/12) ».
            -- La poche des cristaux entames n'a pas de limite : « (2/3) » y
            -- ferait croire a un plafond. Elle dit seulement combien elle tient.
            if contenant.poche then
                c.nom:SetText(string.format("%s (%d)", sac.label, pleines))
            else
                c.nom:SetText(string.format("%s (%d/%d)", sac and sac.label or ("? " .. contenant.id), pleines, total))
            end
            if not sac then Peindre(c.nom, UI.C.plein) end
            c.description:SetText(sac and sac.description or "N'existe pas dans cette version de l'addon.")
            c.aide = "Clic : ouvrir. Clic droit : options."
        else
            local devise = LCM.Devises.Get(e.devise)
            c.icone:SetTexture(devise and devise.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
            c.nom:SetText(devise and devise.label or ("? " .. e.devise))
            if not devise then Peindre(c.nom, UI.C.plein) end
            c.description:SetText("Solde : " .. tostring(e.solde or 0))
            c.aide = "Clic droit : options."
        end
    end

    -- Clic : ouvrir un sac, ou (MJ) choisir ce qu'on pose dans un vide.
    -- Clic droit : le menu de l'emplacement.
    function f:CliquerEmplacement(c, bouton)
        local entity, onglet, index = Entite(), c.onglet, c.index
        local e = c.emplacement
        -- Clic gauche : on regarde ce qu'il y a dedans, a droite.
        local contenant = Inv.Contenant(e)
        if bouton ~= "RightButton" and contenant then
            self.choisi = c.rang
            self.zone:Aller(0)
            self:Rafraichir()
            return
        end
        if bouton == "RightButton" then
            if not e then return end
            local options = {}
            if contenant then
                -- Le clic droit ouvrait le sac sans rien proposer d'autre. Il
                -- ouvre maintenant un menu, comme sur un objet : Ouvrir, Voir,
                -- Échanger, Jeter (13 octobre 2026).
                options[#options + 1] = { label = "Ouvrir", action = function() Ecran.OuvrirSac(onglet, index) end }
                if contenant.ref then
                    options[#options + 1] = { label = "Voir", action = function() Voir(contenant.ref, self) end }
                end
            else
                options[#options + 1] = { label = "Voir", action = function() Voir("devises/" .. e.devise, self) end }
            end
            if LCM.IsMaster() then
                if e.devise then
                    options[#options + 1] = { label = "Solde : " .. tostring(e.solde or 0), action = function()
                        UI.Demande():Demander("Solde de la devise", e.solde or 0, function(texte)
                            local ok, raison = Inv.Solde(entity, onglet, index, texte)
                            if ok then self:Rafraichir() end
                            return ok, raison
                        end)
                    end }
                end
                -- La ceinture reste a sa place : elle n'a qu'un emplacement.
                if contenant and not contenant.ceinture then
                    -- Deplacer > : vers un emplacement libre de SA nature — un
                    -- sac dans Sacs, une sacoche dans Saccoches (Inv.PeutPorter).
                    local cibles = {}
                    local porte = Inv.Emplacement(entity, onglet, index)
                    for _, autre in ipairs(Inv.categories) do
                        if autre.contient == "sac" and not autre.ceinture
                            and Inv.PeutPorter(autre.id, porte) then
                            for i = 1, Inv.Capacite(autre.id) do
                                if not Inv.Emplacement(entity, autre.id, i) then
                                    local cibleOnglet, cibleIndex = autre.id, i
                                    cibles[#cibles + 1] = { label = string.format("%s · emplacement %d", autre.label, i),
                                        action = function()
                                            local ok, raison = Inv.Deplacer(entity, onglet, index, cibleOnglet, cibleIndex)
                                            if not ok then Refuser(raison) return end
                                            Ecran.FermerSac(onglet, index)
                                            self:Rafraichir()
                                        end }
                                end
                            end
                        end
                    end
                    if #cibles > 0 then options[#options + 1] = { label = "Deplacer >", sous = cibles } end
                end
            end
            -- Ce que porte l'emplacement s'echange et se jette comme un objet,
            -- s'il peut le quitter (un sac vide ; une ceinture dont les cases
            -- en plus sont vides). Sinon l'entree dit pourquoi.
            local objet = ObjetDEmplacement(onglet, index)
            if objet then
                local ok, raison = Inv.PeutRetirer(entity, onglet, index)
                options[#options + 1] = OptionEchanger(objet, not ok and raison or nil)
                options[#options + 1] = { label = "Détruire", action = function()
                    if not ok then Refuser(raison) return end
                    Jeter(objet)
                end }
            end
            UI.MenuContexte():Ouvrir(c, options)
            return
        end
        if contenant then
            Ecran.OuvrirSac(onglet, index)
        elseif e then
            Voir("devises/" .. e.devise, self)
        end
        -- Un emplacement vide ne propose plus de liste au clic (3 octobre
        -- 2026) : on ne se donne pas un sac a la volee. Le MJ le glisse depuis
        -- le compendium.
    end
    return f
end

-- ===== La fenetre d'un sac ================================================

local sacs = {}

local function NouvelleCase(s, n)
    local b = CreateFrame("Button", nil, s.zone.contenu)
    b:SetSize(CASE, CASE)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.fond = UI.Aplat(b, { 0, 0, 0, 0.2 })
    b.fond:SetAllPoints(b)
    UI.BordureFine(b, 0.30)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
    b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
    b.nombre = UI.Texte(b, "", { 1, 0.97, 0.86 }, "GameFontNormal")
    b.nombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.nombre:SetJustifyH("RIGHT")
    -- En liste : une ligne de 28, icone de 20 et nom.
    b.nom = UI.Texte(b, "", UI.C.texte, "GameFontNormalSmall")
    b.nom:SetWordWrap(false)
    -- Le meme etat qu'au panneau de contenu : les deux listes montrent la meme
    -- chose, sinon l'une des deux ment.
    b.etat = UI.Texte(b, "", UI.C.discret, "GameFontNormalSmall")
    b.etat:SetJustifyH("RIGHT")
    b.survol = UI.Aplat(b, { 0.80, 0.70, 0.40, 0.12 }, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    Surbrillance(b)
    UI.Glisser.Cible(b, function(objet)
        if Creation(objet) and not LCM.IsMaster() then
            return false, "sortir un objet du compendium est un geste du maître du jeu."
        end
        local e = s:Emplacement()
        if DeLaBourse(objet) then
            return AccepteBourse(objet, e, { onglet = s.onglet, index = s.index, case = b.index })
        end
        if objet.scinder then
            return AccepteScission(objet, e, { onglet = s.onglet, index = s.index, case = b.index })
        end
        if objet.groupe then
            return AccepteGroupe(objet, { onglet = s.onglet, index = s.index, case = b.index })
        end
        -- Reposer un objet sur sa propre case n'est pas une erreur : c'est un
        -- glissement qu'on annule. On accepte, et le depot ne fera rien.
        if objet.origine and objet.origine.onglet == s.onglet
            and objet.origine.index == s.index and objet.origine.case == b.index then
            return true
        end
        local vers = { onglet = s.onglet, index = s.index, case = b.index }
        if Empilable(objet, e, vers) then return AccepteEmpiler(objet, vers) end
        if DuCompendium(objet, e, vers) then return AccepteAjout(e, vers) end
        if Inv.Case(e, b.index) then return false, "cette case est déjà occupée." end
        return Inv.Accepte(e, b.index, objet.ref)
    end, function(objet)
        local vers = { onglet = s.onglet, index = s.index, case = b.index }
        if DeLaBourse(objet) then
            DeposerBourse(objet, vers)
            return
        end
        if objet.scinder then
            DeposerScission(objet, vers)
            return
        end
        if objet.groupe then DeposerGroupe(objet, vers) return end
        if Empilable(objet, s:Emplacement(), vers) then Empiler(objet, vers) return end
        if DuCompendium(objet, s:Emplacement(), vers) then Ajouter(s:Emplacement(), vers) return end
        local entite = Entite()
        if objet.origine and objet.origine.onglet == s.onglet
            and objet.origine.index == s.index and objet.origine.case == b.index then
            return
        end
        -- Un objet qui vient d'ailleurs demenage : il quitte sa place, puis on
        -- le range ici. Si le rangement echoue, il y retourne — un objet perdu
        -- entre deux sacs serait pire que le refus (5 octobre 2026). La SOURCE
        -- sait comment partir et revenir.
        if objet.retirer then objet.retirer() end
        local ok, raison = Inv.Ranger(entite, s.onglet, s.index, b.index,
            objet.ref, objet.quantite or 1, objet.exemplaires)
        if not ok then
            if objet.rendre then objet.rendre() end
            Refuser(raison)
        end
        Ecran.Actualiser()
    end)

    -- ... et une SOURCE : on prend ce qu'elle contient pour le poser ailleurs.
    -- Le glissement n'existait que depuis le compendium ; d'un sac a l'autre, il
    -- fallait passer par le menu contextuel et son sous-menu.
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        -- Son propre sac : on y prend ce qu'on veut. C'est la destination qui
        -- juge (12 octobre 2026).
        local objet = GlisserDepuis(s.onglet, s.index, self.index)
        if objet then UI.Glisser.Commencer(objet) end
    end)
    -- Pas d'OnUpdate ici : c'est le fantome du kit qui bat la mesure, suit la
    -- souris et lache au relachement. En poser un second ferait le travail
    -- deux fois par image.
    b:SetScript("OnDragStop", function() UI.Glisser.Lacher() end)
    b:SetScript("OnClick", function(self, bouton) s:CliquerCase(self, bouton) end)
    b:SetScript("OnDoubleClick", function(self, bouton)
        if bouton ~= "LeftButton" then return end
        local c = Inv.Case(s:Emplacement(), self.index)
        if c then LireOuVoir(c.ref, s) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local c = Inv.Case(s:Emplacement(), self.index)
        local element = c and LCM.Compendium.Resoudre(c.ref)
        if c then
            GameTooltip:SetText(element and element.label or ("? " .. tostring(c.ref)), 1, 0.82, 0)
            local charges = Charges(c)
            if charges then GameTooltip:AddLine("Charge : " .. charges, 0.55, 0.8, 1, true) end
            if element and element.description ~= "" then
                GameTooltip:AddLine(element.description, 0.8, 0.75, 0.62, true)
            end
            GameTooltip:AddLine("Clic : choisir (Ctrl, Maj : plusieurs). Double-clic : voir. Clic droit : options.",
                0.55, 0.55, 0.55, true)
        else
            GameTooltip:SetText(self.devise and "Emplacement devise" or "Emplacement", 1, 0.82, 0)
            if LCM.IsMaster() then GameTooltip:AddLine("Glisse une entrée depuis le compendium.", 0.55, 0.55, 0.55) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    s.cases[n] = b
    return b
end

local function ConstruireSac(onglet, index)
    local cle = onglet .. "_" .. index
    local s = UI.Fenetre("sac_" .. cle, "Sac", 380, 300, { x = 120 + index * 20, y = -40 - index * 20 },
        { enTeteSimple = true, redimensionnable = true })
    s.onglet, s.index = onglet, index
    s.cases = {}
    s.vue = Action(s, "Liste", 44, 18)
    s.vue:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -12)
    s.vue:SetFrameLevel(s:GetFrameLevel() + 6)
    s.vue:SetScript("OnClick", function()
        vues[cle] = Vue(cle, "grille") == "grille" and "liste" or "grille"
        s:Rafraichir()
    end)
    s.filet = UI.Filet(s)
    s.filet:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -42)
    s.filet:SetPoint("TOPRIGHT", s, "TOPRIGHT", -14, -42)
    s.zone = UI.Defilement(s)
    s.zone:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -52)
    s.zone:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -30, 28)
    s.choix = UI.Choix("sac_" .. cle, "")
    UI.Redimensionner(s, 320, 260, function() s:Rafraichir() end)
    s:HookScript("OnSizeChanged", function() if not s.enRedimension then s:Rafraichir() end end)
    s:HookScript("OnShow", function() s:Rafraichir() end)
    s:HookScript("OnHide", function() s.choix:Hide() end)
    Sonner(s)

    function s:Emplacement() return Inv.Emplacement(Entite(), self.onglet, self.index) end

    function s:Rafraichir()
        if not self:IsShown() then return end
        local e = self:Emplacement()
        local contenant = Inv.Contenant(e)
        if not contenant then self:Hide() return end
        local sac = contenant.element
        self:Titre(sac and sac.label or ("? " .. contenant.id))
        local vue = Vue(cle, "grille")
        self.vue.label:SetText(vue == "grille" and "Liste" or "Grille")
        local total = Inv.Cases(e)
        local largeur = self.zone:GetWidth()
        if not largeur or largeur <= CASE then largeur = self:GetWidth() - 44 end
        largeur = math.max(CASE, largeur - 8)
        local colonnes = math.max(1, math.floor((largeur + ECART_CASE) / (CASE + ECART_CASE)))
        for n = 1, total do
            local b = self.cases[n] or NouvelleCase(self, n)
            b.index = n
            b.devise = Inv.EstCaseDevise(e, n)
            local c = Inv.Case(e, n)
            local element = c and LCM.Compendium.Resoudre(c.ref)
            b.choisie:SetShown(c ~= nil and Selection.Marque(self.onglet, self.index, n, c.ref))
            b:ClearAllPoints()
            b.icone:ClearAllPoints()
            b.nom:ClearAllPoints()
            b.etat:ClearAllPoints()
            b.etat:SetText("")
            if vue == "grille" then
                local col, rang = (n - 1) % colonnes, math.floor((n - 1) / colonnes)
                b:SetSize(CASE, CASE)
                b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", col * (CASE + ECART_CASE), -rang * (CASE + ECART_CASE))
                b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
                b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
                b.nom:Hide()
                -- En grille, une case fait 48 pixels : l'etat n'y tiendrait
                -- pas. La carte au survol le dit.
                b.etat:Hide()
            else
                b:SetHeight(28)
                b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -(n - 1) * 30)
                b:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -(n - 1) * 30)
                b.icone:SetSize(20, 20)
                b.icone:SetPoint("LEFT", b, "LEFT", 6, 0)
                -- L'etat au bout, puis la quantite a sa gauche : le nom
                -- s'arrete avant les deux.
                b.etat:SetPoint("RIGHT", b, "RIGHT", -8, 0)
                local exemplaire = c and LCM.Objets.ExemplaireDePile(c)
                local etat, reste, plein = c and element and UI.EtatObjet(Entite(), element, exemplaire) or nil
                b.etat:SetText(etat or "")
                if etat then
                    b.etat:SetTextColor(unpack(UI.CouleurEtat(reste, plein)))
                end
                b.etat:Show()
                local brise = c and element and UI.ObjetBrise(Entite(), element, exemplaire) or false
                b.nom:SetPoint("LEFT", b.icone, "RIGHT", 8, 0)
                b.nom:SetPoint("RIGHT", b.etat, "LEFT", -34, 0)
                b.nom:SetText(c and ((brise and (UI.MARQUE_BRISE .. " ") or "")
                        .. (element and element.label or ("? " .. tostring(c.ref))))
                    or (b.devise and "Emplacement devise" or "Emplacement"))
                b.nom:SetTextColor(unpack(brise and UI.C.plein or UI.C.texte))
                b.nom:Show()
            end
            if c then
                b.icone:SetTexture(element and element.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
                -- La teinte se repose a CHAQUE passage : une case qui garde la
                -- sienne la donnerait a l'objet suivant.
                UI.TeinterBrise(b.icone, element and UI.ObjetBrise(Entite(), element, LCM.Objets.ExemplaireDePile(c)) or false)
                b.icone:Show()
                b.fond:SetColorTexture(0, 0, 0, 0.28)
                -- Une devise montre toujours son nombre ; le reste, a partir de deux.
                local q = tonumber(c.quantite) or 1
                b.nombre:SetText((b.devise or q > 1) and ("x" .. q) or "")
            else
                b.icone:SetShown(vue ~= "grille")
                if vue ~= "grille" then b.icone:SetTexture(VIDE) end
                UI.TeinterBrise(b.icone, false)
                b.fond:SetColorTexture(0, 0, 0, 0.2)
                b.nombre:SetText(b.devise and "DEV" or "")
            end
            b:Show()
        end
        for n = total + 1, #self.cases do self.cases[n]:Hide() end
        local rangs = vue == "grille" and math.ceil(total / colonnes) or total
        local hauteurContenu = vue == "grille" and rangs * (CASE + ECART_CASE) or total * 30
        self.zone:Regler(hauteurContenu)
        -- La fenetre prend la taille de son sac : cinq cases ne meritent pas la
        -- meme fenetre que vingt-cinq, et passer de la grille a la liste change
        -- la hauteur du tout au tout. Tant qu'on ne l'a pas tiree soi-meme
        -- (`placee`), elle suit.
        if not self.placee then
            -- 52 au-dessus de la zone (titre, filet), 28 en dessous.
            local voulue = 80 + hauteurContenu
            local plafond = (UIParent and UIParent:GetHeight() or 1080) * 0.8
            self:SetHeight(math.max(160, math.min(voulue, plafond)))
            -- En grille, on cale aussi la LARGEUR sur les colonnes occupees :
            -- une rangee de cinq cases dans une fenetre de 380 laissait un
            -- desert a droite.
            if vue == "grille" then
                local utiles = math.min(colonnes, total)
                self:SetWidth(math.max(320, 44 + utiles * (CASE + ECART_CASE)))
            end
        end
    end

    function s:CliquerCase(b, bouton)
        local entity = Entite()
        local e = self:Emplacement()
        local c = Inv.Case(e, b.index)
        if bouton == "RightButton" then
            if not c then return end
            local options = {}
            if LCM.IsMaster() then
                -- « Quantite » vit maintenant dans MenuObjet, le menu partage :
                -- elle etait ici seulement, et la colonne de contenu ne
                -- l'offrait pas (19 octobre 2026).
                -- Deplacer > : vers la premiere case libre d'un autre sac qui l'accepte.
                local cibles = {}
                for _, categorie in ipairs(Inv.categories) do
                    for i = 1, Inv.Capacite(categorie.id) do
                        local autre = Inv.Emplacement(entity, categorie.id, i)
                        if Inv.Contenant(autre) and autre ~= e then
                            local libre
                            for n = 1, Inv.Cases(autre) do
                                if not libre and not Inv.Case(autre, n) and Inv.Accepte(autre, n, c.ref) then libre = n end
                            end
                            if libre then
                                local sac = Inv.Contenant(autre).element
                                local cibleOnglet, cibleIndex, cibleCase = categorie.id, i, libre
                                cibles[#cibles + 1] = { label = sac and sac.label or Inv.Contenant(autre).id, action = function()
                                    local ref, quantite = c.ref, c.quantite
                                    local exemplaires = LCM.Copie(LCM.Exemplaires.Assurer(c))
                                    Inv.Vider(entity, self.onglet, self.index, b.index)
                                    local ok = Inv.Ranger(entity, cibleOnglet, cibleIndex, cibleCase, ref, quantite, exemplaires)
                                    if not ok then Inv.Ranger(entity, self.onglet, self.index, b.index, ref, quantite, exemplaires) end
                                    Ecran.Actualiser()
                                end }
                            end
                        end
                    end
                end
                if #cibles > 0 then options[#options + 1] = { label = "Deplacer >", sous = cibles } end
            end
            -- « Supprimer » (MJ, sans confirmation) laisse la place a « Jeter »,
            -- pour tout le monde et confirme : deux entrees pour le meme geste.
            -- Si la case fait partie d'une selection, ce sont les gestes de
            -- la selection.
            MenuDeCase(b, self.onglet, self.index, b.index, options)
            return
        end
        -- Le clic choisit (Ctrl, Maj : plusieurs) ; voir, c'est le
        -- double-clic (20 octobre 2026). Un sac range dans un sac se voit
        -- de meme.
        Selection.Cliquer(self.onglet, self.index, b.index)
        -- Une case vide ne propose plus de liste au clic (3 octobre 2026) :
        -- on ne se donne pas un objet a la volee. Le MJ le glisse depuis le
        -- compendium.
    end
    return s
end

function Ecran.OuvrirSac(onglet, index)
    local cle = onglet .. "_" .. index
    sacs[cle] = sacs[cle] or ConstruireSac(onglet, index)
    sacs[cle]:Show()
    sacs[cle]:Rafraichir()
    return sacs[cle]
end

function Ecran.FermerSac(onglet, index)
    local s = sacs[onglet .. "_" .. index]
    if s then s:Hide() end
end

-- Les fenetres de sac montrent un emplacement de CE personnage : quand on en
-- change, elles n'ont plus de sens.
function Ecran.FermerSacsOuverts()
    for _, s in pairs(sacs) do if s:IsShown() then s:Hide() end end
end

function Ecran.RafraichirSacs()
    for _, s in pairs(sacs) do if s:IsShown() then s:Rafraichir() end end
end
Ecran.sacs = sacs

function Ecran.Actualiser()
    if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Rafraichir() else Ecran.RafraichirSacs() end
end

-- Le personnage joue change (un objet equipe quitte son sac, une recolte en
-- remplit un) : l'inventaire ouvert suit (Core/Direct.lua).
LCM.Entities.Ecouter(function(entity)
    if entity == LCM.Entities.Self() then Ecran.Actualiser() end
end)
-- On joue quelqu'un d'autre : ses sacs a lui.
LCM.Entities.EcouterSoi(function()
    Ecran.FermerSacsOuverts()
    Ecran.Actualiser()
end)

-- ===== Ouverture ==========================================================

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Show() end
end

LCM.WhenReady(function()
    UI.Menu.Lier("inventaires", Ecran.Basculer)
end)
