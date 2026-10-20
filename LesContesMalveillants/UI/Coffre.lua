-- Fenetre aventurier : consulter, prendre et ranger les objets d'un coffre.

local _, LCM = ...
local UI, C = LCM.UI, LCM.Coffres
local Ecran = {}
UI.Coffre = Ecran

local function Importer(ref, definition)
    if type(definition) ~= "table" then return end
    if tostring(ref or ""):match("^livres/") then
        if LCM.Livres then LCM.Livres.Importer(ref, definition) end
    elseif LCM.Echange and LCM.Echange.ImporterObjetPartage then
        LCM.Echange.ImporterObjetPartage({ ref = ref, definition = definition })
    end
end

-- Un transfert attend la reponse du proprietaire du coffre, et refuse le
-- suivant tant qu'elle n'est pas la. Si elle ne vient jamais (proprietaire
-- deconnecte, sans l'addon, message perdu, .gps qui ne repond pas ou qui
-- trouve le joueur trop loin), le verrou restait pose jusqu'au /reload : le
-- coffre refusait tout, « déjà en attente », et l'objet retire du sac ne
-- revenait pas. Au bout de ce delai, on rend et on deverrouille.
local DELAI_REPONSE = 10
local function Expirer(f, champ, attendu, rendre)
    LCM.Recolte.PlusTard(DELAI_REPONSE, function()
        if f[champ] ~= attendu then return end
        f[champ] = nil
        rendre()
    end)
end

local CASE, HAUTEUR_CASE, ECART, COLONNES_MAX = 68, 86, 8, 5
local LARGEUR_MIN, LARGEUR_VERROUILLEE = 340, 390
local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

local function SacTotal(entity, ref)
    local total = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for i = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(entity, categorie.id, i)
            for _, item in pairs(e and e.cases or {}) do
                if item.ref == ref then total = total + (tonumber(item.quantite) or 1) end
            end
        end
    end
    return total
end
Ecran.SacTotal = SacTotal

local function InventaireTotal(entity, ref)
    local total = SacTotal(entity, ref)
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if objetId and LCM.Objets and LCM.Objets.Equipes then
        for _, objet in ipairs(LCM.Objets.Equipes(entity) or {}) do
            if tostring(objet and objet.id or "") == objetId then total = total + 1 end
        end
    end
    return total
end
Ecran.InventaireTotal = InventaireTotal

-- Un prérequis peut viser un objet précis ou un type entier de la « Liste
-- outils ». On réserve d'abord les objets précis, puis les types : un même
-- exemplaire ne peut satisfaire deux lignes à la fois. Le résultat contient
-- les références concrètes à user ou consommer après la tentative.
local function ResoudreOutils(entity, outils)
    local disponibles, choisis = {}, {}
    local function Stock(ref)
        if disponibles[ref] == nil then disponibles[ref] = InventaireTotal(entity, ref) end
        return disponibles[ref]
    end
    local function Ajouter(outil, ref, nombre, consomme)
        choisis[#choisis + 1] = { entree = ref, quantite = nombre,
            consomme = consomme > 0, consommeQuantite = consomme,
            expertise = outil.expertise }
        disponibles[ref] = Stock(ref) - nombre
    end
    local function Traiter(outil)
        local restant = math.max(1, math.floor(tonumber(outil.quantite) or 1))
        local aConsommer = outil.consomme and math.max(1, math.floor(tonumber(outil.consommeQuantite) or 1)) or 0
        local refs = {}
        if outil.typeOutil then
            for _, objet in ipairs(LCM.Objets.list or {}) do
                if objet.categorie == "outil" and objet.type == outil.typeOutil then
                    refs[#refs + 1] = "objets/" .. objet.id
                end
            end
            table.sort(refs)
        elseif outil.entree then
            refs[1] = outil.entree
        end
        for _, ref in ipairs(refs) do
            local nombre = math.min(restant, Stock(ref))
            if nombre > 0 then
                local consomme = math.min(nombre, aConsommer)
                Ajouter(outil, ref, nombre, consomme)
                restant, aConsommer = restant - nombre, aConsommer - consomme
            end
            if restant == 0 then break end
        end
        if restant > 0 then
            local typeDef = outil.typeOutil and LCM.Listes.Get(outil.typeOutil)
            local objet = outil.entree and LCM.Compendium.Resoudre(outil.entree)
            return false, tostring((typeDef and typeDef.label) or (objet and objet.label)
                or outil.typeOutil or outil.entree or "outil")
        end
        return true
    end
    for _, outil in ipairs(outils or {}) do
        if not outil.typeOutil then
            local ok, manque = Traiter(outil)
            if not ok then return nil, manque end
        end
    end
    for _, outil in ipairs(outils or {}) do
        if outil.typeOutil then
            local ok, manque = Traiter(outil)
            if not ok then return nil, manque end
        end
    end
    return choisis
end
Ecran.ResoudreOutils = ResoudreOutils

local function ConsommerOutil(entity, ref)
    if LCM.Inventaire.Prendre(entity, ref) then return true end
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if objetId and LCM.Objets and LCM.Objets.EstEquipe
            and LCM.Objets.EstEquipe(entity, objetId) then
        return LCM.Objets.Enlever(entity, objetId)
    end
    return false
end
Ecran.ConsommerOutil = ConsommerOutil

local function UserOutil(entity, ref)
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if not objetId or not LCM.Objets then return false end
    if LCM.Objets.EstEquipe(entity, objetId) then
        LCM.Objets.Encaisser(entity, objetId, 1)
        return true
    end
    if SacTotal(entity, ref) > 0 and LCM.Objets.UserInventaire then
        LCM.Objets.UserInventaire(entity, objetId, 1)
        return true
    end
    return false
end
Ecran.UserOutil = UserOutil

local function BonusObjet(entity, ref, expertise)
    local element = LCM.Compendium.Resoudre(ref)
    if not (element and element.bonus) then return 0 end
    local montant = tonumber(element.bonus[expertise]) or 0
    if montant ~= 0 and LCM.Objets and LCM.Objets.ApportSelonEtat then
        -- L'etat de l'exemplaire qui servira : on porte, ou le plus entame
        -- des sacs.
        local exemplaire = LCM.Objets.ExemplaireAUser and element.id and LCM.Objets.ExemplaireAUser(entity, element.id)
        montant = LCM.Objets.ApportSelonEtat(entity, element, montant, exemplaire)
    end
    return tonumber(montant) or 0
end
Ecran.BonusObjet = BonusObjet

-- Les OUTILS de cette expertise que le personnage a dans ses sacs : un objet
-- de categorie « outil » qui lui donne un bonus (un kit de crochetage pour
-- Crochetage). Un par modele, le meilleur bonus d'abord — a etat egal, le
-- plus utile en tete (20 octobre 2026 : ils se proposent tout seuls, au lieu
-- d'aller les chercher et de les glisser un a un).
local function OutilsDeLExpertise(entity, expertise)
    local vus, out = {}, {}
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for i = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(entity, categorie.id, i)
            for _, item in pairs(e and e.cases or {}) do
                local ref = type(item) == "table" and item.ref
                local id = ref and tostring(ref):match("^objets/(.+)$")
                local objet = id and LCM.Objets.Get(id)
                if objet and not vus[ref] and objet.categorie == "outil"
                    and (tonumber(objet.bonus and objet.bonus[expertise]) or 0) > 0 then
                    vus[ref] = true
                    out[#out + 1] = { ref = ref, element = objet, bonus = BonusObjet(entity, ref, expertise) }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.bonus ~= b.bonus then return a.bonus > b.bonus end
        return tostring(a.element.label) < tostring(b.element.label)
    end)
    return out
end
Ecran.OutilsDeLExpertise = OutilsDeLExpertise

local function ChanceExpertise(expertise, bonus, dd, entity)
    local champ = LCM.Schema.Field(expertise)
    local des = champ and champ.dice or {}
    local minimum, maximum = tonumber(des.min) or 0, tonumber(des.max) or 0
    if maximum < minimum then minimum, maximum = maximum, minimum end
    local reussites, total = 0, maximum - minimum + 1
    for jet = minimum, maximum do if jet + bonus >= dd then reussites = reussites + 1 end end
    local chance = total > 0 and reussites / total or 0
    -- Roll.Field impose automatiquement le désavantage : il garde le plus
    -- mauvais de deux jets, donc les deux doivent réussir.
    if entity and LCM.Effets.Desavantage(entity, expertise) then chance = chance * chance end
    return math.floor(100 * chance + 0.5)
end
Ecran.ChanceExpertise = ChanceExpertise

local function NomMethode(id)
    if id == C.METHODE_CLEF then return "Clef" end
    local champ = LCM.Schema.Field(id)
    return (champ and champ.label) or tostring(id or "Expertise inconnue")
end

local function OutilsPour(coffre, expertise)
    local outils = {}
    for _, outil in ipairs((coffre and coffre.outils) or {}) do
        -- Les anciennes définitions sans association restent globales afin
        -- de ne pas rendre soudainement leurs verrous plus permissifs.
        if not outil.expertise or outil.expertise == "" or outil.expertise == expertise then
            outils[#outils + 1] = outil
        end
    end
    return outils
end
Ecran.OutilsPour = OutilsPour

local function Occuper(objets)
    local total = 0
    for _, objet in ipairs(objets or {}) do
        total = total + C.Places(objet.entree, objet.quantite)
    end
    return total
end

local function Piles(objets)
    local out = {}
    for _, objet in ipairs(objets or {}) do
        local definition = LCM.Compendium.Resoudre(objet.entree)
        local reste = math.max(0, math.floor(tonumber(objet.quantite) or 0))
        local pile = math.max(1, C.Pile(objet.entree) or reste)
        while reste > 0 do
            local quantite = math.min(reste, pile)
            out[#out + 1] = { ref = objet.entree, quantite = quantite, element = definition }
            reste = reste - quantite
        end
    end
    return out
end

local function Voir(ref, ancre)
    local element, categorie = LCM.Compendium.Resoudre(ref)
    if element and categorie and UI.Compendium and UI.Compendium.Voir then
        UI.Compendium.Voir(categorie, element, ancre)
    end
end

local function CarteSurvol()
    if Ecran.carteSurvol then return Ecran.carteSurvol end
    if not (UI.Compendium and UI.Compendium.NouvelleCarte) then return nil end
    local p = UI.Compendium.NouvelleCarte()
    p:SetFrameStrata("TOOLTIP")
    p:SetMovable(false)
    p:EnableMouse(false)
    p:SetScript("OnMouseDown", nil)
    p:SetScript("OnDragStart", nil)
    p:SetScript("OnDragStop", nil)
    if p.fermer then p.fermer:Hide() end
    if p.poignee then p.poignee:Hide() end
    -- Rester sur la case la charge, puis l'epingle : on la consulte, et sa
    -- croix (cachee jusque-la) la ferme.
    UI.SurvolAccrochable(p)
    p:Hide()
    Ecran.carteSurvol = p
    return p
end

local function AfficherProche(point)
    if not Ecran.bouton then
        local b = UI.Interaction("LCM_BoutonCoffre", "Ouvrir", "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\fenetres-coffres.tga")
        b:SetScript("OnClick", function(self)
            -- Un objet pose seul au sol se ramasse d'un clic ; un coffre s'ouvre.
            if self.ramasser then Ecran.RamasserObjet(self.pointId) else
                local ok, raison = C.Ouvrir(self.pointId)
                if not ok then LCM.Alerte(tostring(raison)) end
            end
        end)
        -- Le medaillon seul accepte le clic droit MJ ; le reste du bandeau
        -- conserve son clic gauche habituel.
        b.editer = CreateFrame("Button", nil, b)
        b.editer:SetSize(44, 44)
        b.editer:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.editer:SetFrameLevel(b:GetFrameLevel() + 1)
        b.editer:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.editer:SetScript("OnClick", function(_, bouton)
            if bouton == "RightButton" then
                if LCM.IsMaster() and not b.ramasser then
                    local ok, raison = C.Ouvrir(b.pointId, true)
                    if not ok then LCM.Alerte(tostring(raison)) end
                end
            elseif b.ramasser then Ecran.RamasserObjet(b.pointId)
            else C.Ouvrir(b.pointId) end
        end)
        UI.Bulle(b.editer, "Coffre", "Clic gauche : ouvrir. Clic droit MJ : éditer le contenu.")
        Ecran.bouton = b
    end
    local b = Ecran.bouton
    if not point then b.pointId = nil; b:Hide(); return end
    b.pointId = point.id
    local d = C.definitions[point.def]
    b.ramasser = d and d.coffre and d.coffre.objet and true or false
    b.editer:SetShown(LCM.IsMaster() and not b.ramasser)
    b.titre:SetText(b.ramasser and "Ramasser" or "Ouvrir")
    b.nom:SetText(tostring(d and d.label or "Coffre"))
    local coffre = d and d.coffre or {}
    local contenu = coffre.objets
    local objet
    if coffre.sac then
        objet = LCM.Sacs.Get(coffre.sac)
    elseif coffre.tente then
        objet = LCM.Tentes and LCM.Tentes.Get(coffre.tente)
    elseif b.ramasser and contenu and contenu[1] then
        objet = LCM.Compendium.Resoudre(contenu[1].entree)
    end
    b.icone:SetTexture(objet and objet.icone and LCM.Icone(objet.icone) or "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\fenetres-coffres.tga")
    b:Show()
end

local function Construire()
    local f = UI.Fenetre("coffre_joueur", "Coffre", 420, 280, { x = 0, y = -30 })
    f.modeEdition = CreateFrame("Frame", nil, f.contenu)
    f.modeEdition:SetSize(128, 24)
    f.modeEdition:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    UI.BordureFine(f.modeEdition, 0.45)
    f.modeEdition.texte = UI.Texte(f.modeEdition, "MODE ÉDITION", UI.C.accent, "GameFontNormalSmall")
    f.modeEdition.texte:SetAllPoints(f.modeEdition)
    f.modeEdition.texte:SetJustifyH("CENTER")
    f.modeEdition:Hide()
    f.verrouiller = UI.Bouton(f.contenu, "Verrouiller", 120, 24, function() C.Envoyer("verrouiller") end)
    f.verrouiller:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 0)
    f.resetVerrous = UI.Bouton(f.contenu, "Reset les verrous", 140, 24,
        function() C.Envoyer("reset_verrous") end)
    f.resetVerrous:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 0)
    f.resetVerrous:Hide()
    -- Un coffre qui EST un sac lache au sol (Core/SacsAuSol.lua) se ramasse
    -- en entier : le sac s'equipe, son contenu dedans.
    f.ramasser = UI.Bouton(f.contenu, "Ramasser le sac", 180, 32, function() Ecran.Ramasser() end)
    f.ramasser:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.ramasser.survol:Hide()
    f.ramasser.reflet = UI.DegradeOr(f.ramasser, "ARTWORK", 0.40)
    f.ramasser.reflet:SetAllPoints(f.ramasser)
    UI.FonduSurvol(f.ramasser, f.ramasser.reflet, 0.35, 1)
    f.ramasser:Hide()
    f.verrousBrises = UI.Texte(f.contenu, "", UI.C.plein, "GameFontNormalSmall")
    f.verrousBrises:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.statut = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.choixExpertise = UI.Bouton(f.contenu, "Choisir une expertise", 320, 24, function()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        local options = {}
        for _, m in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            local label = m.id == C.METHODE_CLEF
                and "Clef — objet requis, aucun jet"
                or (NomMethode(m.id) .. " — DD " .. tostring(m.dd)
                    .. " · " .. tostring(tonumber(m.fatigue) or 0) .. " PF")
            options[#options + 1] = { id = m.id, label = label }
        end
        UI.Choix("coffre_expertise_ouverture", "Expertise pour ouvrir")
            :Proposer(f.choixExpertise, options, function(id)
                f.expertise = id
                for _, o in ipairs(options) do if o.id == id then f.choixExpertise.label:SetText(o.label) end end
                f:ProposerOutils()
                f:MettreAJourTentative()
            end)
    end)
    f.choixExpertise:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -42)

    f.aidesTitre = UI.Texte(f.contenu,
        "Objets pour s’aider — tes outils sont proposés. Clic : en ajouter ; clic droit : retirer.",
        UI.C.discret, "GameFontNormalSmall")
    f.aidesTitre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -76)
    f.aides, f.aideCases = {}, {}
    for index = 1, 6 do
        local b = CreateFrame("Button", nil, f.contenu)
        b:SetSize(46, 46)
        b:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", (index - 1) * 54, -96)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.fond = UI.Aplat(b, { 0, 0, 0, 0.24 }); b.fond:SetAllPoints(b)
        UI.BordureFine(b, 0.30)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
        b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
        b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.bonus = UI.Texte(b, "", { 0.45, 1, 0.45 }, "GameFontNormalSmall")
        b.bonus:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 2)
        b.bonus:SetJustifyH("RIGHT")
        b:SetScript("OnClick", function(self, bouton)
            if bouton == "RightButton" and f.aides[self.index] then
                f.aides[self.index] = nil
                f:MettreAJourTentative()
            elseif bouton == "LeftButton" then
                f:ChoisirAide(self)
            end
        end)
        b:SetScript("OnEnter", function(self)
            local aide = f.aides[self.index]
            local element, categorie = aide and LCM.Compendium.Resoudre(aide.ref)
            local carte = element and categorie and CarteSurvol()
            if carte then
                carte:SuivreSurvol(self, function() carte.placee = nil; carte:Montrer(categorie, element, self) end)
            end
        end)
        b:SetScript("OnLeave", function() if Ecran.carteSurvol then Ecran.carteSurvol:QuitterSurvol() end end)
        UI.Glisser.Cible(b, function(objet)
            if not (f.etatRecu and f.etatRecu.f) then return false, "le coffre n’est pas verrouillé." end
            if not (objet.origine and objet.origine.case) then
                return false, "glisse un objet depuis une case de ton inventaire."
            end
            if not tostring(objet.ref or ""):match("^objets/") then
                return false, "seuls les objets peuvent aider cette tentative."
            end
            local deja = 0
            for i, aide in pairs(f.aides) do
                if i ~= b.index and aide.ref == objet.ref then deja = deja + 1 end
            end
            if deja >= SacTotal(LCM.Entities.Self(), objet.ref) then
                return false, "tu n’en possèdes pas assez pour remplir une autre case."
            end
            return true
        end, function(objet)
            f.aides[b.index] = { ref = objet.ref, element = objet.element }
            f:MettreAJourTentative()
        end)
        b.index = index
        f.aideCases[index] = b
    end
    f.bonusTentative = UI.Texte(f.contenu, "", UI.C.texte, "GameFontNormal")
    f.bonusTentative:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -153)
    f.ddTentative = UI.Texte(f.contenu, "", UI.C.texte, "GameFontNormalSmall")
    f.ddTentative:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -178)

    function f:MethodeCourante()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        for _, methode in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            if methode.id == self.expertise then return methode end
        end
    end

    -- Les outils de l'expertise choisie remplacent ce qui etait pose : ceux
    -- d'une autre expertise n'y apporteraient rien. Un exemplaire de chaque
    -- modele — en poser deux du meme reste un choix, par le clic.
    function f:ProposerOutils()
        self.aides = {}
        local methode = self:MethodeCourante()
        if not methode or methode.id == C.METHODE_CLEF then return end
        for i, outil in ipairs(OutilsDeLExpertise(LCM.Entities.Self(), methode.id)) do
            if i > #self.aideCases then break end
            self.aides[i] = { ref = outil.ref, element = outil.element }
        end
    end

    -- Un clic sur une case : la liste de ce qu'on peut y poser, sans glisser.
    -- Les outils de l'expertise d'abord, puis tout objet des sacs qui lui
    -- donne un bonus. Ce qu'on a deja pose autant de fois qu'on le possede
    -- n'y est plus.
    function f:ChoisirAide(case)
        local methode = self:MethodeCourante()
        if not methode or methode.id == C.METHODE_CLEF then
            LCM.Alerte("choisis d’abord une expertise.")
            return
        end
        local entity = LCM.Entities.Self()
        local poses = {}
        for i, aide in pairs(self.aides) do
            if i ~= case.index then poses[aide.ref] = (poses[aide.ref] or 0) + 1 end
        end
        local options, vus = {}, {}
        local function Ajouter(ref, element, groupe)
            if vus[ref] or (poses[ref] or 0) >= SacTotal(entity, ref) then return end
            vus[ref] = true
            options[#options + 1] = { id = ref, groupe = groupe, label = string.format("%s  (%+d)",
                element.label, BonusObjet(entity, ref, methode.id)) }
        end
        for _, outil in ipairs(OutilsDeLExpertise(entity, methode.id)) do Ajouter(outil.ref, outil.element, "Outils") end
        for _, categorie in ipairs(LCM.Inventaire.categories) do
            for i = 1, LCM.Inventaire.Capacite(categorie.id) do
                local e = LCM.Inventaire.Emplacement(entity, categorie.id, i)
                for _, item in pairs(e and e.cases or {}) do
                    local id = type(item) == "table" and tostring(item.ref or ""):match("^objets/(.+)$")
                    local objet = id and LCM.Objets.Get(id)
                    if objet and (tonumber(objet.bonus and objet.bonus[methode.id]) or 0) ~= 0 then
                        Ajouter(item.ref, objet, "Autres objets")
                    end
                end
            end
        end
        if #options == 0 then
            LCM.Alerte(string.format("rien dans tes sacs n’aide en %s.", NomMethode(methode.id)))
            return
        end
        -- Creee une fois : UI.Choix fabrique une fenetre a chaque appel.
        self.choixAide = self.choixAide or UI.Choix("coffre_aide", "Poser pour s’aider")
        self.choixAide:Proposer(case, options, function(ref)
            local id = tostring(ref):match("^objets/(.+)$")
            self.aides[case.index] = { ref = ref, element = id and LCM.Objets.Get(id) }
            self:MettreAJourTentative()
        end)
    end

    function f:BonusAides(methode)
        if not methode then return 0 end
        local total, entity = 0, LCM.Entities.Self()
        for _, aide in pairs(self.aides) do total = total + BonusObjet(entity, aide.ref, methode.id) end
        return total
    end

    function f:MettreAJourTentative()
        local methode, entity = self:MethodeCourante(), LCM.Entities.Self()
        local avecClef = methode and methode.id == C.METHODE_CLEF
        if self.etatRecu and self.etatRecu.f then
            local p = C.points[C.courant or ""]
            local d = p and C.definitions[p.def]
            local verbe = avecClef and "Ouvrir avec la clef" or "Forcer le verrou"
            local restants = tonumber(self.etatRecu.v) or 0
            self.forcer.label:SetText(string.format("%s (%d verrou%s restant%s / %d)",
                verbe, restants, restants > 1 and "s" or "", restants > 1 and "s" or "",
                tonumber(d and d.coffre and d.coffre.verrous) or 0))
        end
        self.aidesTitre:SetShown(self.etatRecu and self.etatRecu.f and not avecClef)
        local retenus = {}
        for index = 1, 6 do
            local aide = self.aides[index]
            if aide then
                retenus[aide.ref] = (retenus[aide.ref] or 0) + 1
                if retenus[aide.ref] > SacTotal(entity, aide.ref) then
                    self.aides[index], aide = nil, nil
                end
            end
            local case = self.aideCases[index]
            case:SetShown(self.etatRecu and self.etatRecu.f and not avecClef)
            local element = aide and (aide.element or LCM.Compendium.Resoudre(aide.ref))
            local bonus = aide and methode and BonusObjet(entity, aide.ref, methode.id) or 0
            case.icone:SetTexture(element and LCM.Icone(element.icone) or VIDE)
            case.icone:SetAlpha(element and 1 or 0.16)
            case.bonus:SetText(element and string.format("%+d", bonus) or "")
        end
        if not methode then
            self.bonusTentative:SetText("|cff70dc70Bonus total : —|r")
            self.ddTentative:SetText("DD d’expertise à vaincre : —")
            return
        end
        if avecClef then
            self.bonusTentative:SetText("|cff70dc70Ouverture automatique avec l’objet requis.|r")
            self.ddTentative:SetText("Aucun jet d’expertise ni DD à vaincre.")
            return
        end
        local expertise = LCM.Formules.Expertise(entity, methode.id)
        local objets = self:BonusAides(methode)
        local total, dd = expertise + objets, tonumber(methode.dd) or 0
        local chance = ChanceExpertise(methode.id, total, dd, entity)
        local couleur = chance < 30 and "ff5959" or (chance < 60 and "ff9f40"
            or (chance < 80 and "ffd34e" or "70dc70"))
        self.bonusTentative:SetText(string.format(
            "|cff70dc70Bonus total : %d|r  (|cffffd34eExpertise : %d|r + |cffffd34eObjets : %d|r)",
            total, expertise, objets))
        self.ddTentative:SetText(string.format(
            "DD d’expertise à vaincre : %d  (|cff%s%d %% de chance de réussir|r)", dd, couleur, chance))
    end

    f.forcer = UI.Bouton(f.contenu, "Forcer un verrou", 135, 24, function()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        local m
        for _, method in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            if method.id == f.expertise then m = method break end
        end
        if not m then LCM.Alerte("choisis une expertise autorisée."); return end
        local entity = LCM.Entities.Self()
        local outils = OutilsPour(d.coffre, m.id)
        local avecClef = m.id == C.METHODE_CLEF
        if avecClef and #outils == 0 then
            LCM.Alerte("aucune clef n’est configurée pour ce verrou."); return
        end
        local outilsConcrets, manquant = ResoudreOutils(entity, outils)
        if not outilsConcrets then LCM.Alerte("outil requis absent : " .. manquant); return end
        if avecClef then
            if m.usureOutils then
                for _, outil in ipairs(outilsConcrets) do
                    for _ = 1, tonumber(outil.quantite) or 1 do UserOutil(entity, outil.entree) end
                end
            end
            LCM.Actions.Annoncer("Clef : ouverture du verrou sans jet d’expertise.")
            f.outilsEnAttente = LCM.Copie(outilsConcrets)
            C.Envoyer("forcer", { expertise = m.id, score = 0, total = 0, clef = true })
            return
        end
        local coutFatigue = math.max(0, math.floor(tonumber(m.fatigue) or 0))
        local fatigue = LCM.Entities.Gauge(entity, "fatigue")
        if coutFatigue > 0 and (not fatigue or (tonumber(fatigue.current) or 0) < coutFatigue) then
            LCM.Alerte("fatigue insuffisante : cette tentative coûte " .. coutFatigue .. " PF.")
            return
        end
        f:MettreAJourTentative()
        local compteAides = {}
        for _, aide in pairs(f.aides) do
            compteAides[aide.ref] = (compteAides[aide.ref] or 0) + 1
            if compteAides[aide.ref] > SacTotal(entity, aide.ref) then
                LCM.Alerte("un objet d’aide n’est plus dans ton inventaire."); return
            end
        end
        local bonusAides = f:BonusAides(m)
        local resultat, raison = LCM.Roll.Field(entity, m.id, { modificateur = bonusAides })
        if not resultat then LCM.Alerte(tostring(raison or "jet impossible.")); return end
        if coutFatigue > 0 then
            local ok, erreur = LCM.Entities.SetGauge(entity, "fatigue",
                (tonumber(fatigue.current) or 0) - coutFatigue)
            if not ok then LCM.Alerte(tostring(erreur or "impossible de dépenser la fatigue.")); return end
            LCM.Info("Tentative de verrou : -" .. coutFatigue .. " PF.")
        end
        if m.usureOutils then
            for _, outil in ipairs(outilsConcrets) do
                for _ = 1, tonumber(outil.quantite) or 1 do UserOutil(entity, outil.entree) end
            end
        end
        for _, aide in pairs(f.aides) do
            local objetId = tostring(aide.ref or ""):match("^objets/(.+)$")
            if objetId and LCM.Objets and LCM.Objets.UserInventaire then
                LCM.Objets.UserInventaire(entity, objetId, 1)
            end
        end
        f:MettreAJourTentative()
        local score, dd = tonumber(resultat.total) or 0, tonumber(m.dd) or 0
        LCM.Actions.Annoncer(LCM.Roll.Describe(resultat) .. " contre DD " .. m.dd)
        f.outilsEnAttente = score >= dd and LCM.Copie(outilsConcrets) or nil
        C.Envoyer("forcer", { expertise = m.id, score = score, total = score, dd = dd })
    end)
    f.forcer:SetSize(300, 26)
    f.forcer:ClearAllPoints()
    f.forcer:SetPoint("TOP", f.contenu, "TOP", 0, -210)
    f.forcer:Hide()
    f.grille = UI.Defilement(f.contenu)
    f.grille:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -58)
    f.grille:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 36)
    f.cases = {}
    f.bandeau = UI.DegradeOr(f.contenu, "BACKGROUND", 0.15)
    f.bandeau:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", -5, 6)
    f.bandeau:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 5, 6)
    f.bandeau:SetHeight(48)
    f.apercu = UI.Texte(f.contenu, "CONTENU", UI.C.titre)
    UI.Police(f.apercu, 13)
    f.apercu:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -24)
    f.apercu:SetPoint("RIGHT", f.contenu, "RIGHT", 0, 0)
    f.apercu:SetWordWrap(false)
    f.aideContenu = UI.Texte(f.contenu, "Glisser : prendre   ·   Clic droit : options", UI.C.libelle, "GameFontNormalSmall")
    f.aideContenu:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 42)
    f.capaciteFond = UI.Aplat(f.contenu, { 0.30, 0.23, 0.12, 0.55 })
    f.capaciteFond:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -42)
    f.capaciteFond:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -42)
    f.capaciteFond:SetHeight(3)
    f.capacite = UI.Aplat(f.contenu, UI.C.accent, "ARTWORK")
    f.capacite:SetPoint("TOPLEFT", f.capaciteFond, "TOPLEFT")
    f.capacite:SetHeight(3)

    function f:PeutPrendre(ref, quantite)
        local copie = LCM.Copie(LCM.Entities.Self())
        return LCM.Inventaire.Deposer(copie, ref, quantite)
    end

    function f:Prendre(ref, quantite)
        if self.priseGlissee then LCM.Alerte("un transfert est déjà en attente."); return false end
        local ok, raison = self:PeutPrendre(ref, quantite)
        if not ok then LCM.Alerte(raison or "aucune place libre."); return false end
        return C.Envoyer("prendre", { e = ref, q = quantite })
    end

    local function DepuisCompendium(objet)
        -- Le compendium transmet une categorie et une reference, sans origine
        -- d'inventaire. Ne pas confondre avec un objet pris dans un autre
        -- coffre (origine.coffre) ou dans un sac (origine.case).
        --
        -- On reconnaissait la categorie a son NOM, « objets » ou « livres ».
        -- Or celle d'une arme s'appelle « armes », celle d'une armure
        -- « armures » : seuls les livres passaient, et glisser une epee du
        -- compendium s'entendait repondre qu'elle n'etait pas dans
        -- l'inventaire (19 octobre 2026). Ce qu'une entree EST, c'est la
        -- famille de sa reference qui le dit.
        return objet.origine == nil and objet.categorie ~= nil
    end

    function f:Ranger(objet)
        if self.rangementEnAttente then return false end
        local catalogue = DepuisCompendium(objet)
        -- Sortir un objet du compendium est un geste de MJ, comme pour les sacs
        -- (12 octobre 2026). Il fallait en plus le « mode edition », qui ne
        -- s'ouvre que sur un coffre qu'on a soi-meme pose et qui n'est pas au
        -- sol : garnir en seance le coffre d'un autre etait impossible
        -- (19 octobre 2026).
        if catalogue and not LCM.IsMaster() then
            LCM.Alerte("sortir un objet du compendium est un geste du maître du jeu.")
            return false
        end
        -- Un exemplaire du catalogue est cree dans le coffre, sans aucun
        -- retrait ni remboursement dans les sacs du MJ.
        local transfert = catalogue and {} or objet
        if transfert.retirer then transfert.retirer() end
        self.rangementEnAttente = transfert
        local ok, raison = C.Envoyer(catalogue and "ajouter_compendium" or "ranger",
            { e = objet.ref, q = catalogue and 1 or (objet.quantite or 1) })
        if not ok then
            if transfert.rendre then transfert.rendre() end
            self.rangementEnAttente = nil
            LCM.Alerte(raison or "transfert impossible.")
        else
            Expirer(self, "rangementEnAttente", transfert, function()
                if transfert.rendre then transfert.rendre() end
                -- Une reponse tardive qui accepte le rangement le reprend.
                self.rangementExpire = transfert
                LCM.Alerte("le coffre n'a pas répondu : l'objet revient dans ton sac.")
            end)
        end
        return ok, raison
    end

    function f:ObjetGlissable(pile)
        local demande = { ref = pile.ref, quantite = pile.quantite }
        return {
            icone = pile.element and LCM.Icone(pile.element.icone) or nil,
            nom = pile.element and pile.element.label or pile.ref,
            ref = pile.ref, quantite = pile.quantite, element = pile.element,
            origine = { coffre = true, point = self.pointId },
            retirer = function()
                demande.envoyee = true
                f.priseGlissee = demande
                local ok, raison = C.Envoyer("prendre", { e = demande.ref, q = demande.quantite })
                if not ok then
                    demande.reponse = false
                    demande.raison = raison
                else
                    -- Sans reponse, la prise est refusee : l'objet pose d'avance
                    -- dans le sac en ressort. Une reponse tardive qui l'accorde
                    -- le redepose (branche « prendre » sans prise en attente).
                    Expirer(f, "priseGlissee", demande, function()
                        if not demande.annulee then
                            for _ = 1, demande.quantite do LCM.Inventaire.Prendre(LCM.Entities.Self(), demande.ref) end
                        end
                        LCM.Alerte("le coffre n'a pas répondu : rien n'a été pris.")
                    end)
                end
            end,
            rendre = function() demande.annulee = true end,
        }
    end

    function f:NouvelleCase(index)
        local b = CreateFrame("Button", nil, self.grille.contenu)
        b:SetSize(CASE, HAUTEUR_CASE)
        b.index = index
        b:RegisterForClicks("RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b.fond = UI.Aplat(b, { 0, 0, 0, 0.28 })
        b.fond:SetAllPoints(b)
        b.traits = UI.Bordure(b, { 0.55, 0.42, 0.22, 0.55 })
        if UI.AelCadre then UI.AelCadre(b, "icone") end
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
        b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 23)
        b.nom = UI.Texte(b, "", UI.C.texte, "GameFontNormalSmall")
        UI.Police(b.nom, 10)
        b.nom:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 6)
        b.nom:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 6)
        b.nom:SetJustifyH("CENTER")
        b.nom:SetWordWrap(false)
        b.vide = UI.Texte(b, "+", UI.C.libelle)
        b.vide:SetPoint("CENTER", b, "CENTER", 0, 8)
        b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.nombre = UI.Texte(b, "", { 1, 0.92, 0.48 }, "GameFontNormal")
        b.nombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 25)
        b.nombre:SetJustifyH("RIGHT")
        b.survol = UI.DegradeOr(b, "ARTWORK", 0.34)
        b.survol:SetAllPoints(b)
        UI.Glisser.Cible(b, function(objet)
            if not f.ouvert then return false, "le coffre est verrouillé." end
            if b.pile then return false, "cet emplacement est déjà occupé." end
            if f.rangementEnAttente then return false, "un rangement est déjà en attente." end
            local accueilli, pourquoi = C.Accepte(objet.ref)
            if not accueilli then return false, pourquoi end
            if DepuisCompendium(objet) then
                if not LCM.IsMaster() then
                    return false, "sortir un objet du compendium est un geste du maître du jeu."
                end
                if not LCM.Compendium.Resoudre(objet.ref) then return false, "objet inconnu." end
                return true
            end
            if not objet.origine or not objet.origine.case then
                return false, "seuls les objets de ton inventaire peuvent être rangés."
            end
            return true
        end, function(objet) f:Ranger(objet) end)
        b:SetScript("OnDragStart", function(self)
            if not self.pile or f.priseGlissee then return end
            local ok, raison = f:PeutPrendre(self.pile.ref, self.pile.quantite)
            if not ok then LCM.Alerte(raison or "aucune place libre."); return end
            if Ecran.carteSurvol then Ecran.carteSurvol:Hide() end
            UI.Glisser.Commencer(f:ObjetGlissable(self.pile))
        end)
        b:SetScript("OnDragStop", function() UI.Glisser.Lacher() end)
        b:SetScript("OnClick", function(self, bouton)
            if bouton ~= "RightButton" or not self.pile then return end
            UI.MenuContexte():Ouvrir(self, {
                { label = "Prendre", action = function()
                    f:Prendre(self.pile.ref, self.pile.quantite)
                end },
                { label = "Voir", action = function() Voir(self.pile.ref, f) end },
            })
        end)
        b:SetScript("OnEnter", function(self)
            f.apercu:SetText(self.pile and self.pile.element and self.pile.element.label
                or (self.pile and self.pile.ref) or "Emplacement libre")
            if not self.pile then return end
            local element, categorie = LCM.Compendium.Resoudre(self.pile.ref)
            local carte = element and categorie and CarteSurvol()
            if carte then
                carte:SuivreSurvol(self, function()
                    carte.placee = nil
                    carte:Montrer(categorie, element, self)
                end)
            end
        end)
        b:SetScript("OnLeave", function()
            if Ecran.carteSurvol then Ecran.carteSurvol:QuitterSurvol() end
        end)
        b:HookScript("OnLeave", function() f.apercu:SetText("CONTENU") end)
        UI.FonduSurvol(b, b.survol, 0.12, 1)
        self.cases[index] = b
        return b
    end

    f.Afficher = function() Ecran.MettreAJour() end
    f:HookScript("OnHide", function()
        if f.edition then C.edition = false
        elseif f.ouvert then C.Envoyer("fermer") end
        f.edition = false
    end)
    Ecran.frame = f
    return f
end

function Ecran.Ouvrir(id)
    local f = Ecran.frame or Construire()
    f.pointId = id
    f.edition = C.edition == true and LCM.IsMaster()
    f.aides = {}
    f.expertise = nil
    f.choixExpertise.label:SetText("Choisir une expertise")
    f:Show(); f:Afficher(); f:Raise()
end

function Ecran.MettreAJour()
    local f = Ecran.frame
    if not f or not f:IsShown() then return end
    local p = C.points[C.courant or ""]
    local d = p and C.definitions[p.def]
    local e = C.etat
    if not p then f:Hide(); return end
    f.edition = C.edition == true and LCM.IsMaster()
    f.modeEdition:SetShown(f.edition)
    f.aideContenu:SetText(f.edition
        and "Compendium : déposer sur une case libre"
        or "Glisser : prendre   ·   Clic droit : options")
    f:Titre(tostring(d and d.label or "Coffre"))
    f.apercu:SetText("CONTENU")
    local contenuVisible = e and (e.s == true or f.edition) or false
    f.apercu:SetShown(contenuVisible and not f.edition)
    f.bandeau:SetShown(contenuVisible)
    f.aideContenu:SetShown(contenuVisible)
    f.capaciteFond:ClearAllPoints()
    f.capaciteFond:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, f.edition and -68 or -42)
    f.capaciteFond:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, f.edition and -68 or -42)
    f.capaciteFond:SetShown(contenuVisible)
    f.capacite:Hide()
    if not e then
        f.verrousBrises:Hide()
        f.statut:ClearAllPoints()
        f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, f.edition and -28 or 0)
        f.statut:SetText("Chargement du coffre…")
        f.grille:Hide()
        f.choixExpertise:Hide(); f.aidesTitre:Hide(); f.bonusTentative:Hide()
        f.ddTentative:Hide(); f.forcer:Hide()
        f.verrouiller:Hide(); f.resetVerrous:Hide()
        for _, case in ipairs(f.aideCases) do case:Hide() end
        for _, b in ipairs(f.cases) do b:Hide() end
        f:SetSize(LARGEUR_VERROUILLEE, f.insetHaut + 90 + f.insetBas)
        return
    end
    f.etatRecu = e
    f.ouvert = e.s == true or f.edition
    local places = d and d.coffre and d.coffre.places or 0
    local brises = 0
    for _, reverrouillable in ipairs(e.vo or {}) do if not reverrouillable then brises = brises + 1 end end
    f.verrousBrises:SetText(brises == 1 and "1 verrou brisé."
        or (brises > 1 and string.format("%d verrous brisés.", brises) or ""))
    f.verrousBrises:ClearAllPoints()
    f.verrousBrises:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, f.edition and -28 or 0)
    f.verrousBrises:SetShown(brises > 0)
    f.statut:ClearAllPoints()
    f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0,
        (f.edition and -28 or 0) - (brises > 0 and 20 or 0))
    f.statut:SetText(e.f and string.format("Verrouillé — %d verrou(x) restant(s).", e.v or 0)
        or string.format("%s — %d / %d emplacements occupés.", f.ouvert and "Ouvert" or "Fermé",
            Occuper(e.o), places))
    local verrousOuverts = e.vo or {}
    local reverrouillable = not (d and d.coffre and d.coffre.reset) and #verrousOuverts > 0
    for _, autorise in ipairs(verrousOuverts) do if not autorise then reverrouillable = false; break end end
    f.verrouiller:SetShown(not e.f and f.ouvert and reverrouillable)
    f.resetVerrous:SetShown(f.edition)
    local unSac = d and d.coffre and (d.coffre.sac or d.coffre.tente) and true or false
    f.verrouiller:ClearAllPoints()
    f.resetVerrous:ClearAllPoints()
    if f.edition and f.verrouiller:IsShown() then
        f.verrouiller:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOM", -5, 0)
        f.resetVerrous:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOM", 5, 0)
    else
        f.verrouiller:SetPoint(unSac and "BOTTOMLEFT" or "BOTTOM", f.contenu,
            unSac and "BOTTOMLEFT" or "BOTTOM", 0, 0)
        f.resetVerrous:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 0)
    end
    f.ramasser:SetShown(f.ouvert and unSac)
    f.ramasser.label:SetText(d and d.coffre and d.coffre.tente and "Ramasser la tente" or "Ramasser le sac")
    -- La rangee du bas sert aux deux boutons.
    if unSac then reverrouillable = reverrouillable or f.ouvert end
    local verrouille = e.f == true and not f.edition
    f.choixExpertise:SetShown(verrouille)
    f.aidesTitre:SetShown(verrouille)
    f.bonusTentative:SetShown(verrouille)
    f.ddTentative:SetShown(verrouille)
    f.forcer:SetShown(verrouille)
    for _, case in ipairs(f.aideCases) do case:SetShown(verrouille) end
    if verrouille then
        local methode = f:MethodeCourante()
        local verbe = methode and methode.id == C.METHODE_CLEF and "Ouvrir avec la clef" or "Forcer le verrou"
        f.forcer.label:SetText(string.format("%s (%d verrou%s restant%s / %d)", verbe,
            tonumber(e.v) or 0, (tonumber(e.v) or 0) > 1 and "s" or "",
            (tonumber(e.v) or 0) > 1 and "s" or "", tonumber(d.coffre.verrous) or 0))
        f:MettreAJourTentative()
    end
    local piles = f.ouvert and Piles(e.o) or {}
    local colonnes = math.max(1, math.min(COLONNES_MAX, places))
    local lignes = math.max(1, math.ceil(places / colonnes))
    if f.ouvert then
        f.grille:ClearAllPoints()
        f.grille:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, f.edition and -80 or -58)
        f.grille:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0,
            (reverrouillable or f.edition) and 70 or 30)
        f.grille:Show()
        for index = 1, places do
            local b = f.cases[index] or f:NouvelleCase(index)
            b.pile = piles[index]
            b.icone:SetAlpha(b.pile and 1 or 0)
            b.vide:SetShown(not b.pile)
            b.nom:SetText(b.pile and b.pile.element and b.pile.element.label or (b.pile and b.pile.ref) or "Libre")
            b.nom:SetTextColor(unpack(b.pile and UI.C.texte or UI.C.discret))
            b.fond:SetColorTexture(0.10, 0.075, 0.045, b.pile and 0.9 or 0.4)
            b.icone:SetTexture(b.pile and b.pile.element and LCM.Icone(b.pile.element.icone) or VIDE)
            b.nombre:SetText(b.pile and b.pile.quantite > 1 and tostring(b.pile.quantite) or "")
            local colonne = (index - 1) % colonnes
            local ligne = math.floor((index - 1) / colonnes)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f.grille.contenu, "TOPLEFT",
                colonne * (CASE + ECART), -ligne * (HAUTEUR_CASE + ECART))
            b:Show()
        end
    else
        f.grille:Hide()
        for _, b in ipairs(f.cases) do b:Hide() end
    end
    for index = places + 1, #f.cases do f.cases[index]:Hide() end
    local hauteurGrille = lignes * (HAUTEUR_CASE + ECART) - ECART
    f.grille:Regler(hauteurGrille)
    if e.f then
        f:SetSize(500, f.insetHaut + 250 + f.insetBas)
    else
        local largeurGrille = colonnes * (CASE + ECART) - ECART
        local largeur = math.max(LARGEUR_MIN, largeurGrille + f.insetCote * 2)
        f.capacite:SetWidth(math.max(1, (largeur - f.insetCote * 2) * math.min(1, Occuper(e.o) / math.max(1, places))))
        f.capacite:SetShown(f.ouvert and Occuper(e.o) > 0)
        local margeBas = (reverrouillable or f.edition) and 78 or 38
        f.aideContenu:ClearAllPoints()
        f.aideContenu:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0,
            (reverrouillable or f.edition) and 44 or 4)
        local margeHaut = f.edition and 80 or 58
        f:SetSize(largeur, f.insetHaut + margeHaut + math.min(hauteurGrille,
            math.max(150, UIParent:GetHeight() * 0.70 - f.insetHaut - f.insetBas
                - margeHaut - margeBas)) + margeBas + f.insetBas)
    end
end

function Ecran.Proche(point) AfficherProche(point) end

-- On s'est eloigne : la fenetre se referme. Son `OnHide` previent le
-- proprietaire (« fermer »), exactement comme un clic sur la croix — le coffre
-- ne reste donc pas occupe par quelqu'un qui est parti.
function Ecran.Quitter()
    local f = Ecran.frame
    if f and f:IsShown() then f:Hide() end
end
C.onChange = Ecran.MettreAJour

-- Ramasser un objet pose seul au sol : on verifie la place AVANT (a blanc,
-- sur une copie du personnage), puis on le demande a qui le garde.
function Ecran.RamasserObjet(pointId)
    local p = C.points[tostring(pointId or "")]
    local d = p and C.definitions[p.def]
    if not (d and d.coffre and d.coffre.objet) then return false end
    if Ecran.ramassageObjet then LCM.Alerte("un ramassage est déjà en cours.") return false end
    local copie = LCM.Copie(LCM.Entities.Self())
    for _, o in ipairs(d.coffre.objets or {}) do
        local ok, raison = LCM.Inventaire.Deposer(copie, o.entree, o.quantite)
        if not ok then LCM.Alerte(raison or "aucune place libre.") return false end
    end
    Ecran.ramassageObjet = p.id
    C.courant = p.id
    return C.Envoyer("emporter")
end

function Ecran.Repondre(expediteur, data)
    -- L'objet ramasse arrive dans les sacs ; sans fenetre de coffre.
    if data.action == "emporter" and Ecran.ramassageObjet then
        Ecran.ramassageObjet = nil
        if C.courant and not (Ecran.frame and Ecran.frame:IsShown()) then C.courant, C.etat = nil, nil end
        if not data.ok then if data.msg then LCM.Alerte(tostring(data.msg)) end return end
        local entite = LCM.Entities.Self()
        for _, o in ipairs(type(data.w) == "table" and data.w or {}) do
            Importer(o.e, o.d)
            local ok, raison = LCM.Inventaire.Deposer(entite, o.e, tonumber(o.q) or 1)
            if not ok then LCM.Alerte(raison or "aucune place libre.") end
        end
        if LCM.Entities.Changed then LCM.Entities.Changed(entite) end
        LCM.Ok("Ramassé.")
        return
    end
    local f = Ecran.frame
    if not f then return end
    if data.msg and not data.ok then LCM.Alerte(tostring(data.msg)) end
    if data.action == nil then return end
    if data.action == "emporter" then
        if data.ok then Ecran.Emporter(data) else f.ramassage = nil end
        return
    end
    if (data.action == "ranger" or data.action == "ajouter_compendium") and f.rangementEnAttente then
        local transfert = f.rangementEnAttente
        f.rangementEnAttente = nil
        if not data.ok and transfert.rendre then transfert.rendre() end
    elseif (data.action == "ranger" or data.action == "ajouter_compendium") and f.rangementExpire then
        -- Le coffre a fini par accepter un rangement deja rendu : sans ceci,
        -- l'objet serait a la fois dans le coffre et dans le sac.
        local transfert = f.rangementExpire
        f.rangementExpire = nil
        if data.ok and transfert.retirer then transfert.retirer() end
    elseif data.action == "prendre" and f.priseGlissee then
        local demande = f.priseGlissee
        demande.reponse = data.ok == true
        if data.ok then Importer(data.e, data.objet) end
        C_Timer.After(0, function()
            if f.priseGlissee ~= demande then return end
            if demande.reponse and demande.annulee then
                C.Envoyer("ranger", { e = demande.ref, q = demande.quantite })
            elseif not demande.reponse and not demande.annulee then
                for _ = 1, demande.quantite do LCM.Inventaire.Prendre(LCM.Entities.Self(), demande.ref) end
            end
            f.priseGlissee = nil
        end)
    elseif data.action == "prendre" and data.ok then
        local item = data.objet
        Importer(data.e, item)
        local ok, raison = LCM.Inventaire.Deposer(LCM.Entities.Self(), data.e, tonumber(data.q) or 1)
        if not ok then C.Envoyer("ranger", { e = data.e, q = tonumber(data.q) or 1 }); LCM.Alerte(raison) end
    elseif data.action == "forcer" and data.ok and f.outilsEnAttente then
        for _, outil in ipairs(f.outilsEnAttente) do
            if outil.consomme then
                for _ = 1, outil.consommeQuantite do
                    ConsommerOutil(LCM.Entities.Self(), outil.entree)
                end
            end
        end
        f.outilsEnAttente = nil
    elseif data.action == "forcer" and not data.ok then
        f.outilsEnAttente = nil
    end
end

-- Ramasser le sac en entier : il faut un emplacement libre de sa nature
-- (Inventaire.PlacePour), cherche AVANT de demander — sinon le sac quitterait
-- le sol sans avoir ou aller.
function Ecran.Ramasser()
    local f = Ecran.frame
    local p = C.points[C.courant or ""]
    local d = p and C.definitions[p.def]
    if not (f and d and d.coffre and (d.coffre.sac or d.coffre.tente)) then return false end
    if f.ramassage then LCM.Alerte("un ramassage est déjà en cours.") return false end
    local contenu = { sac = d.coffre.sac, tente = d.coffre.tente }
    local onglet, index = LCM.Inventaire.PlacePour(LCM.Entities.Self(), contenu)
    if not onglet then
        LCM.Alerte(d.coffre.tente and "aucun emplacement Saccoches libre pour porter cette tente."
            or (LCM.Sacs.EstSacoche(d.coffre.sac) and "aucun emplacement Saccoches libre pour porter cette sacoche."
                or "aucun emplacement Sacs libre pour porter ce sac."))
        return false
    end
    f.ramassage = contenu
    return C.Envoyer("emporter")
end

-- La reponse : le sac s'equipe, ce qu'il contenait y est range. Ce qui n'y
-- tiendrait pas va ailleurs dans les sacs ; et si rien ne le prend, on le dit.
local function Emporter(data)
    local entite = LCM.Entities.Self()
    local contenu = Ecran.frame.ramassage or {}
    Ecran.frame.ramassage = nil
    local sac, tente = data.b or contenu.sac, data.t or contenu.tente
    local onglet, index = LCM.Inventaire.PlacePour(entite, { sac = sac, tente = tente })
    local objets = {}
    for _, o in ipairs(type(data.w) == "table" and data.w or {}) do
        Importer(o.e, o.d)
        objets[#objets + 1] = { entree = o.e, quantite = tonumber(o.q) or 1 }
    end
    local reste = objets
    if onglet and LCM.Inventaire.Poser(entite, onglet, index, tente and ("tentes/" .. tente) or sac) then
        reste = LCM.Inventaire.RemplirSac(entite, onglet, index, objets)
    else
        LCM.Alerte("plus d'emplacement libre : le sac n'a pas pu être équipé.")
    end
    local perdus = {}
    for _, o in ipairs(reste) do
        if not LCM.Inventaire.Deposer(entite, o.entree, o.quantite) then
            local e = LCM.Compendium.Resoudre(o.entree)
            perdus[#perdus + 1] = string.format("%s x%d", e and e.label or o.entree, o.quantite)
        end
    end
    if #perdus > 0 then LCM.Alerte("faute de place, n'a pas pu être rangé : " .. table.concat(perdus, ", ")) end
    if LCM.Entities.Changed then LCM.Entities.Changed(entite) end
    LCM.Ok("Ramassé.")
end
Ecran.Emporter = Emporter

function Ecran.Retirer(id)
    local f = Ecran.frame
    if f and tostring(f.pointId or "") == tostring(id or "") then f:Hide() end
end

C.onChange = function() Ecran.MettreAJour() end
C.onReponse = Ecran.Repondre

