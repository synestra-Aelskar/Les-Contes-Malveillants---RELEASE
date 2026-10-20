-- La fenetre du campement (menu Outils). Une seule fenetre suit tout le
-- deroule (Core/Campement.lua) : on y lance le camp, on y repond a
-- l'invitation, on y repartit ses unites de temps, et apres la nuit on y
-- distribue et applique les PS. Le MJ y donne les unites de temps.
--
-- Tout est cree une fois ; `Rendre` ne fait que montrer, cacher et remplir.

local _, LCM = ...
local UI = LCM.UI
local K = LCM.Campement

local Ecran = {}
UI.Campement = Ecran

-- Deux colonnes : preparation a gauche, bivouac et compagnie a droite.
local LARGEUR_ACCUEIL, LARGEUR_CAMP = 720, 760
local HAUTEUR_ACCUEIL, HAUTEUR_CAMP = 410, 620
local LIBELLE_ACTION = 210
local LIBELLE_SOIN = 120
local COLONNE_MEMBRES = 250
local MEMBRES_MAX = 12
-- Le resume en haut, puis les sections dessous.
local RESUME_H = 112
local HAUT_SECTIONS = -(RESUME_H + 12)
local LIGNE = 24

local STATUTS = {
    oui = "campe", non = "refuse", invite = "sans réponse", mj = "maître du jeu",
}

local function Alerter(ok, raison)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    return ok
end

local function NomCourt(nom) return (tostring(nom or ""):match("^([^%-]+)") or tostring(nom)) end

local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\campement\\bivouac.tga"
local function Icone(nom, taille)
    return "|TInterface\\Icons\\" .. nom .. ":" .. (taille or 18) .. "|t "
end
local ACTION_ICONES = {
    reposer = "Spell_Nature_Sleep", craft = "Trade_BlackSmithing", apprendre = "INV_Misc_Book_09",
    soigner = "Spell_Holy_Heal", reparer = "Trade_Engineering", backstage = "INV_Misc_Scroll_03",
    garde = "Ability_Rogue_Sprint", prier = "Spell_Holy_PrayerOfHealing",
}

local function Construire()
    local f = UI.Fenetre("campement", "Campement", LARGEUR_ACCUEIL, HAUTEUR_ACCUEIL, { x = 0, y = 20 }, { enTeteSimple = true })
    local c = f.contenu
    f.menuId = "campement"
    f.fond:SetColorTexture(0.045, 0.039, 0.032, 1)
    f.filet = UI.Aplat(c, { 0.55, 0.39, 0.16, 0.5 }, "BORDER")
    f.filet:SetPoint("TOPLEFT", c, "TOPLEFT", 4, 0)
    f.filet:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, 0)
    f.filet:SetHeight(1)
    f.parcours = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.parcours:SetPoint("BOTTOM", c, "BOTTOM", 0, 3)

    f.scene = CreateFrame("Frame", nil, c)
    f.scene:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -2)
    f.scene:SetSize(COLONNE_MEMBRES, COLONNE_MEMBRES)
    f.illustration = f.scene:CreateTexture(nil, "ARTWORK")
    f.illustration:SetPoint("TOP", f.scene, "TOP", 0, -28)
    f.illustration:SetSize(205, 205)
    f.illustration:SetTexture(ART)
    f.sceneTitre = UI.Texte(f.scene, "SOUS LES ÉTOILES", UI.C.titreBloc)
    f.sceneTitre:SetPoint("TOP", f.scene, "TOP", 0, -2)
    f.sceneNom = UI.Texte(f.scene, "Votre prochain refuge", UI.C.texte)
    f.sceneNom:SetPoint("BOTTOMLEFT", f.scene, "BOTTOMLEFT", 14, 4)
    f.sceneNom:SetPoint("RIGHT", f.scene, "RIGHT", -14, 0)
    f.sceneNom:SetJustifyH("CENTER")

    -- Le resume du camp, dans un cadre de section a hauteur FIXE : sans
    -- hauteur, un texte de plusieurs lignes se centrait sur son ancrage et
    -- montait sous la couronne de la fenetre.
    f.resume = CreateFrame("Frame", nil, c)
    f.resume:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)
    f.resume:SetPoint("TOPRIGHT", c, "TOPRIGHT", -COLONNE_MEMBRES - 12, -2)
    f.resume:SetHeight(RESUME_H)
    f.resume.fond = UI.Aplat(f.resume, { 0.09, 0.075, 0.05, 1 })
    f.resume.fond:SetAllPoints(f.resume)
    UI.Bordure(f.resume)
    f.etat = UI.Texte(f.resume, "", UI.C.texte, "GameFontNormalSmall")
    f.etat:SetPoint("TOPLEFT", f.resume, "TOPLEFT", 12, -10)
    f.etat:SetPoint("BOTTOMRIGHT", f.resume, "BOTTOMRIGHT", -12, 8)
    f.etat:SetJustifyH("LEFT")
    f.etat:SetJustifyV("TOP")
    f.etat:SetWordWrap(true)

    -- ----- Les campeurs, a droite -----------------------------------------
    f.membresTitre = UI.Texte(c, "Campeurs", UI.C.titreBloc)
    f.membresTitre:SetPoint("TOPLEFT", f.scene, "BOTTOMLEFT", 8, -16)
    f.membresTitre:SetWidth(COLONNE_MEMBRES)
    f.membres = {}
    for rang = 1, MEMBRES_MAX do
        local t = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", f.scene, "BOTTOMLEFT", 8, -42 - (rang - 1) * 18)
        t:SetWidth(COLONNE_MEMBRES)
        t:SetJustifyH("LEFT")
        f.membres[rang] = t
    end

    -- ----- Lancer --------------------------------------------------------
    f.lancement = CreateFrame("Frame", nil, c)
    f.lancement:SetPoint("TOPLEFT", c, "TOPLEFT", 0, HAUT_SECTIONS)
    f.lancement:SetSize(324, 320)
    f.accroche = UI.Texte(f.lancement, "L’AVENTURE ATTENDRA L’AUBE", UI.C.titreBloc, "GameFontNormalSmall")
    f.accroche:SetPoint("TOPLEFT", f.lancement, "TOPLEFT", 0, 0)
    f.hero = UI.Texte(f.lancement, "Au coin du feu.", UI.C.titre)
    UI.Police(f.hero, 28)
    f.hero:SetPoint("TOPLEFT", f.accroche, "BOTTOMLEFT", 0, -10)
    f.intro = UI.Texte(f.lancement, "Posez les armes. Rassemblez vos compagnons.\nChoisissez le refuge de votre prochaine nuit.", UI.C.texte, "GameFontNormalSmall")
    f.intro:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", 0, -10)
    f.intro:SetSize(324, 30)
    f.intro:SetJustifyV("TOP")
    f.tenteTitre = UI.Texte(f.lancement, "VOTRE REFUGE", UI.C.titreBloc, "GameFontNormalSmall")
    f.tenteTitre:SetPoint("TOPLEFT", f.lancement, "TOPLEFT", 0, -100)
    f.choixTente = UI.CarteAction(f.lancement, "Sans tente", "Choisir une tente équipée", "INV_Misc_Bag_10", 324, 62, false, function(self)
        local options = { { id = "", label = "Sans tente" } }
        -- Seules les tentes EQUIPEES (emplacement de sacoche) se proposent.
        for _, p in ipairs(K.TentesPossedees(LCM.Entities.Self())) do
            options[#options + 1] = { id = p.tente.id, label = p.tente.label, icone = p.tente.icone }
        end
        Ecran.choix = Ecran.choix or UI.Choix("campement_tente", "Tente")
        Ecran.choix:Proposer(self, options, function(id)
            f.tenteId = id ~= "" and id or nil
            local tente = f.tenteId and LCM.Tentes.Get(f.tenteId)
            self.label:SetText(tente and tente.label or "Sans tente")
            f:Rendre()
        end)
    end)
    f.choixTente:SetPoint("TOPLEFT", f.tenteTitre, "BOTTOMLEFT", 0, -8)
    f.tenteDetail = UI.Texte(f.lancement, "", UI.C.texte, "GameFontNormalSmall")
    f.tenteDetail:SetPoint("TOPLEFT", f.choixTente, "BOTTOMLEFT", 2, -10)
    f.tenteDetail:SetSize(320, 60)
    f.tenteDetail:SetJustifyH("LEFT")
    f.tenteDetail:SetJustifyV("TOP")
    f.lancer = UI.CarteAction(f.lancement, "Établir le campement", "Inviter vos compagnons à faire halte", "Spell_Fire_Fire", 324, 58, true, function()
        Alerter(K.Lancer(f.tenteId))
    end)
    f.lancer:SetPoint("TOPLEFT", f.lancement, "TOPLEFT", 0, -260)

    -- ----- Repondre a l'invitation ----------------------------------------
    f.invitation = CreateFrame("Frame", nil, c)
    f.invitation:SetPoint("TOPLEFT", c, "TOPLEFT", 0, HAUT_SECTIONS)
    f.invitation:SetSize(LARGEUR_CAMP - COLONNE_MEMBRES - 60, 40)
    f.accepter = UI.Bouton(f.invitation, "Rejoindre", 110, 24, function() Alerter(K.Repondre(true)) end)
    f.accepter:SetPoint("TOPLEFT", f.invitation, "TOPLEFT", 6, 0)
    f.refuser = UI.Bouton(f.invitation, "Refuser", 110, 24, function() Alerter(K.Repondre(false)) end)
    f.refuser:SetPoint("LEFT", f.accepter, "RIGHT", 8, 0)

    -- ----- Le MJ : les unites de temps -------------------------------------
    f.mj = CreateFrame("Frame", nil, c)
    f.mj:SetPoint("TOPLEFT", c, "TOPLEFT", 0, HAUT_SECTIONS)
    f.mj:SetSize(LARGEUR_CAMP - COLONNE_MEMBRES - 60, 140)
    f.mjTitre = UI.Texte(f.mj, "Temps (minutes) :", UI.C.libelle)
    f.mjTitre:SetPoint("TOPLEFT", f.mj, "TOPLEFT", 6, -4)
    f.mjUnites = UI.Champ(f.mj, 60, 22)
    f.mjUnites:SetNumeric(true)
    f.mjUnites:SetPoint("LEFT", f.mjTitre, "RIGHT", 8, 0)
    f.mjDonner = UI.Bouton(f.mj, "Donner", 80, 22, function()
        Alerter(K.FixerUnites(f.mjUnites:GetText()))
    end)
    f.mjDonner:SetPoint("LEFT", f.mjUnites, "RIGHT", 6, 0)
    -- Le risque d'embuscade : le MJ choisit le danger, l'addon fait le compte.
    -- Rien de tout ca ne quitte son client.
    f.mjDangerTitre = UI.Texte(f.mj, "Danger :", UI.C.libelle)
    f.mjDangerTitre:SetPoint("TOPLEFT", f.mjTitre, "BOTTOMLEFT", 0, -16)
    f.mjDanger = UI.Bouton(f.mj, "Normal", 170, 22, function(self)
        local options = {}
        for _, d in ipairs(LCM.Equilibrage.campement.embuscade.dangers) do
            options[#options + 1] = { id = d.id, label = d.label }
        end
        Ecran.choixDanger = Ecran.choixDanger or UI.Choix("campement_danger", "Niveau de danger")
        Ecran.choixDanger:Proposer(self, options, function(id) Alerter(K.ChoisirDanger(id)) end)
    end)
    f.mjDanger:SetPoint("LEFT", f.mjDangerTitre, "RIGHT", 8, 0)
    f.mjRisque = UI.Texte(f.mj, "", UI.C.titreBloc)
    f.mjRisque:SetPoint("TOPLEFT", f.mjDangerTitre, "BOTTOMLEFT", 0, -16)
    f.mjRisqueDetail = UI.Texte(f.mj, "", UI.C.discret, "GameFontNormalSmall")
    f.mjRisqueDetail:SetPoint("TOPLEFT", f.mjRisque, "BOTTOMLEFT", 0, -4)
    f.mjRisqueDetail:SetPoint("RIGHT", f.mj, "RIGHT", -6, 0)
    f.mjRisqueDetail:SetJustifyH("LEFT")
    f.mjRisqueDetail:SetWordWrap(true)

    -- ----- Repartir ses unites --------------------------------------------
    f.repartition = CreateFrame("Frame", nil, c)
    f.repartition:SetPoint("TOPLEFT", c, "TOPLEFT", 0, HAUT_SECTIONS)
    f.repartition:SetSize(LARGEUR_CAMP - COLONNE_MEMBRES - 60, 300)
    f.compteurs = {}
    for rang, action in ipairs(LCM.Equilibrage.campement.actions) do
        local id = action.id
        -- L'aide de saisie : une heure de plus ou de moins d'un clic, au lieu
        -- de taper des minutes, rangee dans le compteur comme ses autres
        -- boutons : [R][-1h][-] valeur [+][+1h][M]. Le pas vient de
        -- l'equilibrage.
        local pas = LCM.Equilibrage.campement.pasRapide
        local l = UI.Compteur(f.repartition, Icone(ACTION_ICONES[id] or "INV_Misc_PocketWatch_01") .. action.label, LIBELLE_ACTION, {
            pas = { valeur = pas, libelle = "1h", ajouter = function(delta) Alerter(K.Ajouter(id, delta)) end },
            -- Le compteur se redessine par l'observateur du campement : ici on
            -- ne fait que demander, et dire le refus.
            change = function(valeur)
                if not Alerter(K.Repartir(id, valeur)) then return false end
            end,
            max = function()
                local camp = K.courant
                local reste = (camp and camp.unites or 0) - K.Reparties()
                return reste + (camp and camp.heures[id] or 0)
            end,
        })
        l:SetHeight(28)
        l:SetPoint("TOPLEFT", f.repartition, "TOPLEFT", 6, -(rang - 1) * 32)
        l:SetPoint("RIGHT", f.repartition, "RIGHT", -6, 0)
        f.compteurs[rang] = { ligne = l, id = id }
    end
    local nActions = #LCM.Equilibrage.campement.actions
    f.reparties = UI.Texte(f.repartition, "", UI.C.texte, "GameFontNormalSmall")
    f.reparties:SetPoint("TOPLEFT", f.repartition, "TOPLEFT", 6, -nActions * 32 - 6)
    f.apercu = UI.Texte(f.repartition, "", UI.C.discret, "GameFontNormalSmall")
    f.apercu:SetPoint("TOPLEFT", f.reparties, "BOTTOMLEFT", 0, -6)
    f.apercu:SetPoint("RIGHT", f.repartition, "RIGHT", -6, 0)
    f.apercu:SetJustifyH("LEFT")
    f.apercu:SetWordWrap(true)
    f.valider = UI.Bouton(f.repartition, "Validé", 110, 24, function() Alerter(K.Valider()) end)
    f.valider:SetPoint("TOPLEFT", f.apercu, "BOTTOMLEFT", 0, -10)
    f.passerNuit = UI.Bouton(f.repartition, "Passer la nuit", 130, 24, function() Alerter(K.Conclure()) end)
    f.passerNuit:SetPoint("LEFT", f.valider, "RIGHT", 8, 0)

    -- ----- Les PS, apres la nuit ------------------------------------------
    -- Trois blocs titres, une ligne par chose a soigner ou a qui donner : on
    -- voit tout d'un coup d'oeil, sans menu a derouler. Les lignes sont creees
    -- une fois (au plus PS_LIGNES_MAX par bloc) puis seulement remplies.
    local PS_LIGNES_MAX = 12
    f.soins = CreateFrame("Frame", nil, c)
    f.soins:SetPoint("TOPLEFT", c, "TOPLEFT", 0, HAUT_SECTIONS)
    f.soins:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -COLONNE_MEMBRES - 12, 34)
    f.soinsZone = UI.Defilement(f.soins)
    f.soinsZone:SetAllPoints(f.soins)
    local z = f.soinsZone.contenu

    -- Une ligne. Avec montant : le compteur de l'addon, comme partout
    -- (« libelle .. [R][-] montant / plafond [+][M] »), puis une information et
    -- le bouton d'action a droite. Sans montant (les etats) : le libelle,
    -- l'information et le bouton.
    local function Ligne(avecMontant, texteBouton, onClick)
        local l
        if avecMontant then
            l = UI.Compteur(z, "", LIBELLE_SOIN, {
                -- Le montant ne regarde que cette ligne : on le retient et on
                -- redessine, rien ne part tant qu'on n'a pas clique le bouton.
                change = function(valeur)
                    l.montant = valeur
                    l:Regler(valeur, l.plafondMontant or 0)
                end,
                max = function() return l.plafondMontant or 0 end,
            })
            l.nom = l.label
        else
            l = CreateFrame("Frame", nil, z)
            if UI.SurfaceLigne then UI.SurfaceLigne(l) end
            l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
            l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
            l.nom:SetWidth(LIBELLE_SOIN + 140)
            l.nom:SetJustifyH("LEFT")
            l.nom:SetWordWrap(false)
        end
        l.montant = 0
        l.bouton = UI.Bouton(l, texteBouton, 70, 18, function() onClick(l) end)
        l.bouton:SetPoint("RIGHT", l, "RIGHT", -4, 0)
        l.info = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
        l.info:SetPoint("RIGHT", l.bouton, "LEFT", -10, 0)
        l.info:SetJustifyH("RIGHT")
        return l
    end

    local function Bloc(titre, vide)
        local b = { titre = UI.EnTeteGroupe(z, titre), lignes = {} }
        b.vide = UI.Texte(z, vide, UI.C.discret, "GameFontNormalSmall")
        b.vide:SetJustifyH("LEFT")
        return b
    end

    -- Apres un geste reussi, le montant de la ligne revient a zero.
    local function Fait(l, ok)
        if ok then l.montant = 0 end
    end

    -- Donner : une ligne par campeur, soi-meme compris.
    f.blocDon = Bloc("Donner tes PS", "Tu n'as aucun PS à donner.")
    for rang = 1, PS_LIGNES_MAX do
        f.blocDon.lignes[rang] = Ligne(true, "Donner", function(l)
            Fait(l, Alerter(K.DonnerPS(l.cle, l.montant)))
        end)
    end

    -- Soigner : une ligne par zone du corps ; le plafond est ce qui manque,
    -- dans la limite des PS recus (M pose tout d'un coup).
    f.blocSoin = Bloc("Soigner tes blessures", "Aucun PS reçu pour l'instant.")
    for rang = 1, PS_LIGNES_MAX do
        f.blocSoin.lignes[rang] = Ligne(true, "Soigner", function(l)
            Fait(l, Alerter(K.Soigner(l.cle, l.montant)))
        end)
    end

    -- Retirer : une ligne par etat ou maladie porte, avec son prix.
    f.blocEtat = Bloc("États et maladies", "Aucun état ni maladie à retirer.")
    for rang = 1, PS_LIGNES_MAX do
        f.blocEtat.lignes[rang] = Ligne(false, "Retirer", function(l) Alerter(K.RetirerEtat(l.cle)) end)
    end

    f.rendre = UI.Bouton(z, "Rendre le reste", 180, 22, function() Alerter(K.RendrePS()) end)
    f.regle = UI.Texte(z, string.format("1 PS = 1 PV. Un état coûte %d PS par point de sa rareté. "
        .. "Ce que tu n'utilises pas repart chez ton soigneur.", LCM.Equilibrage.campement.vitalite.psParPoint),
        UI.C.discret, "GameFontNormalSmall")
    f.regle:SetJustifyH("LEFT")
    f.regle:SetWordWrap(true)

    -- Pose les blocs les uns sous les autres et annonce la hauteur au defilement.
    local function Poser(element, y, hauteur)
        element:ClearAllPoints()
        element:SetPoint("TOPLEFT", z, "TOPLEFT", 0, y)
        element:SetPoint("TOPRIGHT", z, "TOPRIGHT", -14, y)
        if hauteur then element:SetHeight(hauteur) end
        element:Show()
        return y - (hauteur or element:GetHeight() or 0)
    end

    -- `entrees` : { cle, nom, info, couleur, actif, plafond }.
    local function RemplirBloc(b, y, budget, entrees)
        y = Poser(b.titre, y, 18) - 6
        b.titre.budget:SetText(budget)
        for rang, l in ipairs(b.lignes) do
            local e = entrees[rang]
            if e then
                y = Poser(l, y, LIGNE) - 2
                -- Une ligne qui change de sujet repart de zero.
                if l.cle ~= e.cle then l.montant = 0 end
                l.cle = e.cle
                l.nom:SetText(e.nom)
                l.info:SetText(e.info or "")
                local couleur = e.couleur or UI.C.discret
                l.info:SetTextColor(couleur[1], couleur[2], couleur[3])
                l.bouton:SetAlpha(e.actif and 1 or 0.4)
                if l.Regler then
                    l.plafondMontant = e.plafond or 0
                    l:Regler(l.montant or 0, l.plafondMontant)
                end
            else
                l:Hide()
            end
        end
        b.vide:SetShown(#entrees == 0)
        if #entrees == 0 then y = Poser(b.vide, y - 2, 16) end
        return y - 14
    end

    function f:RendreSoins()
        local camp, moi = K.courant, LCM.Entities.Self()
        local disponibles, recus = camp.psDisponibles or 0, K.PSRecus()

        local dons = {}
        if disponibles > 0 then
            for _, nom in ipairs(K.Participants()) do
                dons[#dons + 1] = { cle = nom, nom = NomCourt(nom) .. (nom == LCM.PlayerId() and " (toi)" or ""),
                                    actif = true, plafond = disponibles }
            end
        end
        local y = RemplirBloc(self.blocDon, 0, string.format("%d PS", disponibles), dons)

        local zones = {}
        for _, p in ipairs(LCM.Body.State(moi)) do
            local manque = p.max - p.current
            zones[#zones + 1] = { cle = p.id, nom = p.label, plafond = math.min(manque, recus),
                info = string.format("%d / %d PV", p.current, p.max),
                couleur = manque > 0 and UI.C.plein or UI.C.discret,
                actif = manque > 0 and recus > 0 }
        end
        if recus == 0 then zones = {} end
        y = RemplirBloc(self.blocSoin, y, string.format("%d PS reçus", recus), zones)

        local etats = {}
        for _, e in ipairs(K.EtatsSoignables(moi)) do
            etats[#etats + 1] = { cle = e.element.id, nom = e.element.label,
                info = e.cout and string.format("%d PS", e.cout) or "MJ",
                couleur = (e.cout and e.cout <= recus) and UI.C.accent or UI.C.discret,
                actif = e.cout ~= nil and e.cout <= recus }
        end
        y = RemplirBloc(self.blocEtat, y, "", etats)

        self.rendre.label:SetText(recus > 0 and string.format("Rendre le reste (%d PS)", recus) or "Rendre le reste")
        self.rendre:SetAlpha(recus > 0 and 1 or 0.4)
        self.rendre:ClearAllPoints()
        self.rendre:SetPoint("TOPLEFT", z, "TOPLEFT", 0, y)
        y = y - 30
        y = Poser(self.regle, y, 30)
        self.soinsZone:Regler(-y + 4)
    end

    -- Lever le camp, ou le quitter : toujours en bas.
    f.quitter = UI.Bouton(c, "Quitter le campement", 160, 22, function() Alerter(K.Quitter()) end)
    f.quitter:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 6, 4)

    function f:Rendre()
        local camp = K.courant
        local moi = LCM.PlayerId()
        local role = camp and camp.role
        local selection, installes
        if camp then
            selection, installes = K.Tente(), camp.accessoires
        else
            for _, possession in ipairs(K.TentesPossedees(LCM.Entities.Self())) do
                if possession.tente.id == self.tenteId then
                    selection, installes = possession.tente, possession.installes
                    break
                end
            end
            -- Une tente retiree de la sacoche ne reste pas selectionnee.
            if not selection then self.tenteId = nil end
            self.choixTente.label:SetText(selection and selection.label or "À la belle étoile")
            self.choixTente.detail:SetText(selection and "Changer de tente équipée" or "Choisir une tente équipée")
            local details = {}
            if selection then
                details[1] = string.format("%s lits  ·  %s emplacements d'accessoires",
                    tostring(selection.lits or "?"), tostring(selection.accessoiresMax or "?"))
                for _, a in ipairs(K.Attributs(selection, installes)) do
                    if a.cle ~= "securite" or LCM.IsMaster() then
                        details[#details + 1] = string.format("%s %+d %%", a.label, a.valeur)
                    end
                end
                self.tenteDetail:SetText(table.concat(details, "  ·  "))
            else
                self.tenteDetail:SetText("Aucun bonus d’abri.\nUne tente équipée dans une sacoche pourra\nêtre sélectionnée ici.")
            end
        end
        self:SetWidth(camp and LARGEUR_CAMP or LARGEUR_ACCUEIL)
        self.scene:SetSize(camp and COLONNE_MEMBRES or 338, camp and 240 or 326)
        self.scene:ClearAllPoints()
        self.scene:SetPoint("TOPRIGHT", self.contenu, "TOPRIGHT", -4, -16)
        self.illustration:ClearAllPoints()
        self.illustration:SetPoint("TOP", self.scene, "TOP", 0, camp and -24 or -10)
        self.illustration:SetSize(camp and 210 or 330, camp and 210 or 330)
        self.sceneNom:ClearAllPoints()
        self.sceneNom:SetPoint("BOTTOM", self.scene, "BOTTOM", 0, camp and -6 or -2)
        self.sceneNom:SetWidth(camp and 240 or 320)
        self.sceneTitre:SetTextColor(0.65, 0.52, 0.32)
        self.parcours:SetText(not camp and "|cffffd18a01  LE REFUGE|r     —     02  LA VEILLÉE     —     03  L’AUBE"
            or camp.etape == "soins" and "01  LE REFUGE     —     02  LA VEILLÉE     —     |cffffd18a03  L’AUBE|r"
            or "01  LE REFUGE     —     |cffffd18a02  LA VEILLÉE|r     —     03  L’AUBE")
        self.parcours:ClearAllPoints()
        self.parcours:SetPoint(camp and "BOTTOMRIGHT" or "BOTTOM", self.contenu, camp and "BOTTOMRIGHT" or "BOTTOM", camp and -4 or 0, 3)
        self.resume:ClearAllPoints()
        self.resume:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, -2)
        self.resume:SetPoint("TOPRIGHT", self.contenu, "TOPRIGHT", -(camp and COLONNE_MEMBRES or 205) - 12, -2)
        self.resume:SetHeight(camp and RESUME_H or 54)
        self.resume:SetShown(camp ~= nil)
        self.lancement:ClearAllPoints()
        self.lancement:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 16, -20)
        self.sceneNom:SetText(selection and selection.label or "À la belle étoile")
        self.sceneTitre:SetText(not camp and "SOUS LES ÉTOILES" or camp.etape == "soins" and "AU PETIT MATIN" or "LE BIVOUAC")
        -- Tout le monde peut lancer, MJ compris : celui qui a le compagnon joue
        -- souvent aussi un personnage.
        self.lancement:SetShown(camp == nil)
        self.invitation:SetShown(role == "invite")
        -- Les reglages du MJ suivent le compagnon, pas le role : un MJ qui a
        -- lance le camp en est le responsable ET donne ses unites.
        local reglagesMJ = camp ~= nil and LCM.IsMaster() and camp.etape == "preparation"
            and (role == "mj" or role == "chef")
        self.mj:SetShown(reglagesMJ)
        -- La repartition descend sous les reglages du MJ quand les deux sont la.
        self.repartition:ClearAllPoints()
        self.repartition:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0,
            reglagesMJ and HAUT_SECTIONS - 144 or HAUT_SECTIONS)
        self:SetHeight(not camp and HAUTEUR_ACCUEIL
            or (reglagesMJ and K.Participe()) and HAUTEUR_CAMP + 150 or HAUTEUR_CAMP)
        if reglagesMJ then
            local danger = K.Danger(camp.danger)
            self.mjDanger.label:SetText(danger and danger.label or "Choisir…")
            local e = K.Embuscade()
            self.mjRisque:SetText(string.format("Risque d'embuscade : %d %%", math.floor(e.risque * 100 + 0.5)))
            local detail = string.format("%d campeur(s), %s de garde.", #K.Participants(), K.Duree(e.garde))
            if #e.manques > 0 then detail = detail .. "\n|cffff7060" .. table.concat(e.manques, "\n") .. "|r" end
            self.mjRisqueDetail:SetText(detail)
        end
        local repartit = camp ~= nil and camp.etape == "preparation" and K.Participe()
        self.repartition:SetShown(repartit)
        self.soins:SetShown(camp ~= nil and camp.etape == "soins" and role ~= "mj")
        self.quitter:SetShown(camp ~= nil)

        -- L'etat, en une phrase.
        if not camp then
            self.etat:SetText("|cffffd18aFAIRE HALTE|r\nChoisissez votre abri pour préparer la nuit.")
        else
            local tente = K.Tente()
            local morceaux = { string.format("Responsable : %s", NomCourt(camp.chef)),
                               "Tente : " .. (tente and tente.label or (camp.tente and ("? " .. camp.tente)) or "aucune") }
            -- La securite (le risque d'embuscade) est l'affaire du MJ : on ne
            -- l'affiche pas aux joueurs. Ce n'est PAS un secret — la tente et
            -- ses bonus sont dans l'addon joueur, qui veut fouiller la trouve —
            -- seulement une information qu'on ne leur met pas sous les yeux.
            local attributs = {}
            for _, a in ipairs(K.Attributs(tente, camp.accessoires)) do
                if a.cle ~= "securite" or LCM.IsMaster() then
                    attributs[#attributs + 1] = string.format("%s %+d %%", a.label, a.valeur)
                end
            end
            morceaux[#morceaux + 1] = table.concat(attributs, "  ·  ")
            if camp.unites then
                morceaux[#morceaux + 1] = string.format("Temps de repos : %s (donné par %s)",
                    K.Duree(camp.unites), NomCourt(camp.fixePar))
            else
                morceaux[#morceaux + 1] = "En attente des unités de temps du MJ."
            end
            if camp.etape == "soins" then morceaux[#morceaux + 1] = "La nuit est passée." end
            -- Le jet d'embuscade n'existe que chez le MJ.
            if camp.embuscade then
                local j = camp.embuscade
                morceaux[#morceaux + 1] = string.format(j.attaque and "|cffff5040EMBUSCADE|r : %d / %d %%"
                    or "Pas d'embuscade : %d / %d %%", j.jet, j.seuil)
            end
            self.etat:SetText(table.concat(morceaux, "\n"))
        end

        -- Les campeurs.
        local noms = {}
        for nom in pairs(camp and camp.membres or {}) do noms[#noms + 1] = nom end
        table.sort(noms)
        for rang = 1, MEMBRES_MAX do
            local t, nom = self.membres[rang], noms[rang]
            if nom then
                local m = camp.membres[nom]
                local statut = STATUTS[m.statut] or m.statut
                if m.statut == "oui" and camp.etape == "preparation" then
                    statut = m.pret and "prêt" or "choisit…"
                end
                t:SetText(string.format("%s%s — %s", NomCourt(nom), nom == camp.chef and " (resp.)" or "", statut))
                local couleur = (m.statut == "oui" and (m.pret or camp.etape ~= "preparation")) and UI.C.accent or UI.C.discret
                t:SetTextColor(couleur[1], couleur[2], couleur[3])
                t:Show()
            else
                t:Hide()
            end
        end
        self.membresTitre:SetText(Icone("INV_Misc_GroupLooking") .. "Compagnons  ·  " .. tostring(#noms))
        self.membresTitre:SetShown(camp ~= nil)

        if repartit then
            local unites = camp.unites or 0
            local reparties = K.Reparties()
            for _, compteur in ipairs(self.compteurs) do
                local h = camp.heures[compteur.id] or 0
                compteur.ligne:Regler(h, unites - reparties + h)
            end
            self.reparties:SetText(string.format("Réparti : %s / %s  |  reste %s",
                K.Duree(reparties), K.Duree(unites), K.Duree(unites - reparties)))
            local resultat = K.Calculer(LCM.Entities.Self(), camp.heures, K.Tente(), #K.Participants(), camp.accessoires)
            local texte = string.format("Cette nuit te rendrait %+d fatigue et %d PS.", resultat.fatigue, resultat.ps)
            if #resultat.manques > 0 then texte = texte .. "\n|cffff7060" .. table.concat(resultat.manques, "\n") .. "|r" end
            self.apercu:SetText(texte)
            self.valider.label:SetText(camp.pret and "Prêt" or "Validé")
            self.passerNuit:SetShown(role == "chef")
            local attente = K.EnAttente()
            self.passerNuit:SetAlpha((camp.unites and #attente == 0) and 1 or 0.4)
        end

        if camp and camp.etape == "soins" and role ~= "mj" then self:RendreSoins() end
    end

    f:SetScript("OnShow", function(self) self:Rendre() end)
    f:Hide()
    Ecran.frame = f
    return f
end

function Ecran.Frame() return Ecran.frame or Construire() end

function Ecran.Basculer()
    local f = Ecran.Frame()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- Une invitation ou la fin de la nuit ouvre la fenetre : sans elle, on ne
-- saurait pas qu'on attend notre reponse ou nos PS.
K.Observer(function(camp)
    local f = Ecran.frame
    if camp and (camp.role == "invite" or camp.etape == "soins" or camp.role == "mj") then
        f = Ecran.Frame()
        if not f:IsShown() then f:Show() end
    end
    if f and f:IsShown() then f:Rendre() end
end)

LCM.WhenReady(function()
    UI.Menu.Lier("campement", Ecran.Basculer)
end)
