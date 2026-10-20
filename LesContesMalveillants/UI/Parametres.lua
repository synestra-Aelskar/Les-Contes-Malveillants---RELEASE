-- Les parametres.
--
-- Le template declare une fenetre `settings` sans en dire le contenu : il n'y a
-- donc rien a recopier, et cette fenetre montre ce que l'addon sait vraiment
-- regler. Trois sections, et pas une de plus — une fenetre de parametres qui
-- grossit est une fenetre que personne ne lit.
--
-- « Depannage » merite son nom : une fenetre perdue hors de l'ecran et un envoi
-- reseau tombe en route sont les deux pannes qu'on ne peut pas diagnostiquer
-- sans outil, et qui coutent une seance.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Parametres = Ecran

-- Mesures de la fenetre de parametres de Necronicon (388 x 600) : etroite
-- et haute. Une fenetre large etale trois reglages sur un demi-ecran.
local LARGEUR, HAUTEUR = 400, 560
local LIGNE = 26

local function Construire()
    local f = UI.Fenetre("parametres", "Paramètres", LARGEUR, HAUTEUR, { x = -60, y = 40 })
    Ecran.frame = f

    f.barre = UI.Onglets(f.contenu, { { id = "general", label = "Général" },
                                      { id = "apparences", label = "Apparences" } },
        function(id) f:Afficher(id) end, { largeur = 120 })
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.barre:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 0)

    f.pages = {}
    f.pages.general = CreateFrame("Frame", nil, f.contenu)
    f.pages.general:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -30)
    f.pages.general:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    local page = f.pages.general

    local y = 0
    local function Titre(texte)
        local h = UI.EnTeteGroupe(page, texte)
        h:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
        h.budget:SetText("")
        y = y + 24
        return h
    end
    local function Case(libelle, onChange)
        local c = UI.Case(page, libelle, onChange)
        c:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -y)
        y = y + LIGNE
        return c
    end
    local function Bouton(libelle, largeur, onClick)
        local b = UI.Bouton(page, libelle, largeur, 22, onClick)
        b:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -y)
        y = y + 28
        return b
    end
    local function Ligne(couleur)
        local fs = UI.Texte(page, "", couleur or UI.C.discret)
        UI.Police(fs, 11)
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -y)
        fs:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
        y = y + 18
        return fs
    end

    Titre("AFFICHAGE")
    f.sceau = Case("Afficher le sceau du lanceur d'actions", function(coche)
        UI.Radial.Afficher(coche)
    end)
    f.replacer = Bouton("Remettre les fenêtres à leur place", 230, function()
        local nombre = UI.ReplacerFenetres()
        LCM.Ok(string.format("%d fenêtre%s replacée%s.", nombre,
            nombre > 1 and "s" or "", nombre > 1 and "s" or ""))
    end)
    y = y + 8

    Titre("PERSONNAGE")
    f.joue = Ligne(UI.C.texte)
    f.choisir = Bouton("Choisir un personnage", 180, function()
        if UI.Personnages then UI.Personnages.Ouvrir() end
    end)
    y = y + 8

    Titre("DÉPANNAGE")
    f.traces = Case("Traces de développement", function(coche)
        LCM.EnsureDatabase()
        LCM.db.settings.debug = coche or nil
    end)
    f.version = Ligne()
    f.reseau = Ligne()
    f.attente = Ligne()

    -- ----- Apparences -----------------------------------------------------
    -- Deux sous-onglets : les reglages continus (opacite, taille) et le choix
    -- de l'habillage.
    f.pages.apparences = CreateFrame("Frame", nil, f.contenu)
    f.pages.apparences:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -30)
    f.pages.apparences:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    local app = f.pages.apparences

    app.barre = UI.Onglets(app, { { id = "general", label = "Général" },
                                  { id = "theme",   label = "Thème" } },
        function(id) f:AfficherApparence(id) end, { largeur = 110 })
    -- Les deux ancrages, pas un seul : UI.Onglets centre ses boutons sur le
    -- HAUT de la barre. Sans largeur, ce haut est le bord gauche, et les
    -- onglets partent hors de la fenetre — on ne les voyait plus.
    app.barre:SetPoint("TOPLEFT", app, "TOPLEFT", 0, 0)
    app.barre:SetPoint("TOPRIGHT", app, "TOPRIGHT", 0, 0)

    app.general = CreateFrame("Frame", nil, app)
    app.general:SetPoint("TOPLEFT", app, "TOPLEFT", 0, -32)
    app.general:SetPoint("BOTTOMRIGHT", app, "BOTTOMRIGHT", 0, 0)

    -- `depart` : la valeur a l'ouverture. Elle passe par `Regler`, pas par une
    -- affectation de `max` : c'est `Regler` qui montre la barre (UI.Curseur
    -- nait cachee, elle sert d'abord d'ascenseur) et qui pose la poignee.
    -- `lire(valeur)` rend le texte affiche a droite. `auRelachement` : la
    -- taille de l'interface ne s'applique qu'au lacher — elle redimensionne la
    -- fenetre qui porte la barre, et une barre qui grandit sous la poignee
    -- pendant qu'on tire devient impilotable.
    local function Barre(parent, libelle, aide, dy, depart, lire, onChange, auRelachement)
        local titre = UI.Texte(parent, libelle, UI.C.texte)
        UI.Police(titre, 12)
        titre:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -dy)
        local valeur = UI.Texte(parent, "", UI.C.titre)
        UI.Police(valeur, 12)
        valeur:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -dy)
        local curseur = UI.Curseur(parent, onChange, {
            auRelachement = auRelachement,
            -- Pendant le glissement, le chiffre suit meme si rien n'est encore
            -- applique : sans lui on tire a l'aveugle.
            onApercu = function(v) valeur:SetText(lire(v)) end,
        })
        curseur:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -dy - 20)
        curseur:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -dy - 20)
        -- Un filet autour de la gouttiere : sans lui, une barre presque noire
        -- sur un fond noir ne se voit pas, et on ne sait pas qu'on peut tirer.
        UI.Bordure(curseur, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.45 })
        curseur:Regler(100, depart)
        curseur.lire = lire
        valeur:SetText(lire(depart))
        local note = UI.Texte(parent, aide, UI.C.discret)
        UI.Police(note, 10)
        note:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -dy - 36)
        return curseur, valeur
    end

    app.opacite, app.opaciteValeur = Barre(app.general, "Opacité des fenêtres",
        "0 : presque transparente — 100 : pleine.", 0, UI.Opacite(),
        function(v) return v .. " %" end,
        function(v) UI.Opacite(v) f:Actualiser() end)
    app.echelle, app.echelleValeur = Barre(app.general, "Taille de l'interface",
        "50 : taille normale. En dessous ça rétrécit, au-dessus ça grandit.", 64, UI.Echelle(),
        function(v) return string.format("%d %%", math.floor((0.5 + v / 100) * 100)) end,
        function(v) UI.Echelle(v) f:Actualiser() end, true)
    -- Le bandeau de personnage n'est pas une fenetre qu'on ouvre : il reste a
    -- l'ecran, contre les cadres de groupe du jeu. Sa taille se regle a part
    -- (11 octobre 2026) — il grandit sans que tout grandisse.
    app.echelleHud, app.echelleHudValeur = Barre(app.general, "Taille du bandeau de personnage",
        "Les points de vie, la fatigue et les zones, en haut à gauche. Indépendant de la taille de l'interface.",
        128, UI.EchelleHUD(),
        function(v) return string.format("%d %%", math.floor((0.5 + v / 100) * 100)) end,
        function(v) UI.EchelleHUD(v) end, true)

    app.theme = CreateFrame("Frame", nil, app)
    app.theme:SetPoint("TOPLEFT", app, "TOPLEFT", 0, -32)
    app.theme:SetPoint("BOTTOMRIGHT", app, "BOTTOMRIGHT", 0, 0)
    app.themes = {}
    for index, theme in ipairs(UI.THEMES) do
        local b = UI.Bouton(app.theme, theme.label, LARGEUR - 40, 24, function()
            if theme.indisponible then
                LCM.Alerte(string.format("l'habillage « %s » n'est pas encore porté.", theme.label))
                return
            end
            UI.AppliquerTheme(theme.id)
            f:Actualiser()
        end)
        b:SetPoint("TOPLEFT", app.theme, "TOPLEFT", 4, -(index - 1) * 28)
        b.themeId = theme.id
        b.indisponible = theme.indisponible
        app.themes[index] = b
    end

    function f:AfficherApparence(id)
        self.apparence = id
        app.barre:Selectionner(id)
        app.general:SetShown(id == "general")
        app.theme:SetShown(id ~= "general")
    end

    function f:Afficher(id)
        self.onglet = id
        for cle, p in pairs(self.pages) do p:SetShown(cle == id) end
        if id == "apparences" then self:AfficherApparence(self.apparence or "general") end
        self:Actualiser()
    end

    function f:Actualiser()
        local radial = UI.Radial and UI.Radial.frame
        self.sceau:Cocher(not (LCM.db.settings and LCM.db.settings.radialCache))

        local moi = LCM.Entities.Self()
        self.joue:SetText(moi and string.format("Tu joues %s.", tostring(moi.name))
                              or "Aucun personnage choisi.")

        self.traces:Cocher(LCM.db.settings and LCM.db.settings.debug or false)
        self.version:SetText(string.format("Version %s — %s", tostring(LCM.version),
            LCM.IsMaster() and "maître du jeu" or "joueur"))

        -- Si le prefixe n'est pas enregistre, RIEN n'arrive, et aucun message
        -- d'erreur ne le dit : c'est exactement le genre de panne muette qu'on
        -- veut pouvoir lire ici.
        local enregistre = true
        if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
            enregistre = C_ChatInfo.IsAddonMessagePrefixRegistered(LCM.Reseau.PREFIXE) and true or false
        end
        self.reseau:SetText(string.format("Réseau : préfixe %s %s",
            LCM.Reseau.PREFIXE, enregistre and "enregistré" or "|cffe86b6bnon enregistré|r"))

        -- Apparences : les barres et l'habillage retenu.
        -- `Poser` et pas `Aller` : on remet la poignee en face de la valeur
        -- retenue, sans rejouer le reglage qu'on vient d'appliquer.
        local opacite = UI.Opacite()
        local echelleHud = UI.EchelleHUD()
        app.echelleHud:Poser(echelleHud)
        app.echelleHudValeur:SetText(app.echelleHud.lire(echelleHud))
        local echelle = UI.Echelle()
        app.opacite:Poser(opacite)
        app.echelle:Poser(echelle)
        app.opaciteValeur:SetText(app.opacite.lire(opacite))
        app.echelleValeur:SetText(app.echelle.lire(echelle))
        local actuel = UI.ThemeActuel()
        for _, b in ipairs(app.themes) do
            b:Selectionner(b.themeId == actuel)
            local teinte = b.indisponible and UI.C.discret or UI.C.texte
            if b.themeId ~= actuel then b.label:SetTextColor(teinte[1], teinte[2], teinte[3]) end
        end

        local attente = LCM.Reseau.EnAttente()
        self.attente:SetText(attente == 0 and "Aucun message en attente."
            or string.format("|cffe8b451%d message(s) incomplet(s)|r — un morceau n'est pas arrivé.", attente))
    end

    function f:Montrer()
        self.barre:Selectionner(self.onglet or "general")
        self:Afficher(self.onglet or "general")
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.AddCommand("parametres", "ouvre les parametres", function() Ecran.Basculer() end)

-- Jouer, ce soir, comme tout le monde. Un MJ qui prend un personnage veut voir
-- ce que ses joueurs voient : la commande met le compagnon en veille sans
-- toucher a la liste des addons ni relancer le jeu.
LCM.AddCommand("switch", "bascule entre maitre du jeu et joueur", function()
    local ok, resultat = LCM.BasculerModeJoueur()
    if not ok then LCM.Alerte(tostring(resultat)) return end
    if resultat then
        LCM.Ok("Mode joueur : le compagnon du maître du jeu est en veille.")
    else
        LCM.Ok("Mode maître du jeu : le compagnon répond de nouveau.")
    end
    -- Le menu et le lanceur relisent les droits a chaque ouverture : il suffit
    -- de les refermer. Les fenetres deja ouvertes, elles, ne se redessinent pas
    -- toutes seules — celles reservees au MJ se ferment, les autres se
    -- rafraichissent.
    if UI.Radial and UI.Radial.Fermer then UI.Radial.Fermer() end
    for _, fenetre in ipairs(UI.fenetres or {}) do
        if fenetre:IsShown() then
            -- `menuId` : l'entree de menu dont la fenetre depend, quand elle ne
            -- porte pas son nom (le compendium s'ouvre par « Systeme »).
            local id = fenetre.menuId or fenetre.cle
            local noeud = id and UI.Menu and UI.Menu.Trouver and UI.Menu.Trouver(id)
            if noeud and noeud.mjSeulement and not LCM.IsMaster() then
                fenetre:Hide()
            elseif fenetre.Rafraichir then
                LCM.Proteger("mode joueur", fenetre.Rafraichir, fenetre)
            elseif fenetre.Actualiser then
                LCM.Proteger("mode joueur", fenetre.Actualiser, fenetre)
            end
        end
    end
end)

LCM.WhenReady(function()
    UI.Menu.Lier("parametres", Ecran.Basculer)
end)
