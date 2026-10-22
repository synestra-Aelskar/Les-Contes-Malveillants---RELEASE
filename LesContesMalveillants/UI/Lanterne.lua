-- La fenetre « Outils » : ce qu'on tient en main. Pour l'instant, la lanterne.
--
-- Reproduction PROVISOIRE du panneau Lanterne d'OmegaSurvive (Survive/
-- Modules/Lantern/Lantern.lua) : la moitie gauche attend son visuel, la moitie
-- droite porte les controles dans le meme ordre — lanterne, cristal,
-- variateur, etat, charge, Allumer, Recharger. Les quatre onglets de ses
-- parametres (Lanterne, Reactifs, Options, Debug) tiennent ici dans un volet
-- unique : les deux premiers ne faisaient que lister le catalogue, que les
-- listes deroulantes montrent deja. Une interface plus profonde viendra la
-- remplacer ; la regle, elle, vit dans Core/Lanternes.lua et n'en dependra pas.

local _, LCM = ...
local UI = LCM.UI
local L = LCM.Lanterne

local Ecran = {}
UI.Lanterne = Ecran

local MOITIE = 280
-- Le volet des parametres (sept emotes, le canal, la remise a zero) est la
-- plus haute des deux colonnes : c'est lui qui donne la hauteur.
local HAUTEUR = 480
local MARGE = 14
local LARGEUR_CTRL = MOITIE - 2 * MARGE

local deconnexion = false
LCM.On("PLAYER_LOGOUT", function() deconnexion = true end)

local function Libelle(parent, texte)
    local fs = UI.Texte(parent, texte, UI.C.libelle, "GameFontNormalSmall")
    return fs
end

local function Variateur(v)
    if math.floor(v) == v then return string.format("x%d", v) end
    return string.format("x%.1f", v)
end

local function Duree(secondes)
    secondes = math.floor(secondes + 0.5)
    local h, m, s = math.floor(secondes / 3600), math.floor(secondes % 3600 / 60), secondes % 60
    if h > 0 then return string.format("%dh %02dmin", h, m) end
    if m > 0 then return string.format("%dmin %02ds", m, s) end
    return string.format("%ds", s)
end

local function Refus(ok, raison)
    if not ok and raison then LCM.Alerte(raison) end
    return ok
end

-- Le choix courant d'abord « aucun », puis le catalogue : comme Survive, qui
-- proposait « Aucune lanterne » et « Insérez un réactif » en tete de liste.
local function OptionsDe(registre, aucun)
    local out = { { id = false, label = aucun } }
    for _, e in ipairs(registre.list) do out[#out + 1] = { id = e.id, label = e.label } end
    return out
end

local function Construire()
    local f = UI.Fenetre("outils_portes", "Outils", MOITIE * 2 + 20, HAUTEUR, { x = 180, y = -40 })
    Ecran.frame = f
    f:SousTitre("Lanterne")
    local c = f.contenu

    -- ----- Moitie gauche : le visuel a venir --------------------------------
    f.gauche = CreateFrame("Frame", nil, c)
    f.gauche:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    f.gauche:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    f.gauche:SetWidth(MOITIE)
    f.aVenir = UI.Texte(f.gauche, "— à venir —", UI.C.discret)
    UI.Police(f.aVenir, 12)
    f.aVenir:SetPoint("CENTER", f.gauche, "CENTER", 0, 0)
    f.separation = UI.Filet(c, true, true)
    f.separation:SetPoint("TOPLEFT", f.gauche, "TOPRIGHT", 0, 0)
    f.separation:SetPoint("BOTTOMLEFT", f.gauche, "BOTTOMRIGHT", 0, 0)

    -- ----- Moitie droite : les controles ------------------------------------
    local d = CreateFrame("Frame", nil, c)
    f.droite = d
    d:SetPoint("TOPLEFT", f.gauche, "TOPRIGHT", 1, 0)
    d:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)

    local y = -6
    local function Poser(w, hauteur, decalage)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", d, "TOPLEFT", MARGE + (decalage or 0), y)
        y = y - hauteur
    end

    f.lblLanterne = Libelle(d, "Lanterne")
    Poser(f.lblLanterne, 16)
    f.lanterne = UI.Deroulant(d, LARGEUR_CTRL, 22,
        function() return OptionsDe(LCM.Lanternes, "Aucune lanterne") end,
        function(id) Refus(L.ChoisirLanterne(id or nil)) f:Afficher() end)
    Poser(f.lanterne, 32)

    f.lblCristal = Libelle(d, "Cristal")
    Poser(f.lblCristal, 16)
    f.cristal = UI.Deroulant(d, LARGEUR_CTRL, 22,
        function() return OptionsDe(LCM.Cristaux, "Insère un cristal") end,
        function(id) Refus(L.ChoisirCristal(id or nil)) f:Afficher() end)
    Poser(f.cristal, 32)

    f.lblVariateur = Libelle(d, "Variateur de temps")
    Poser(f.lblVariateur, 16)
    f.variateur = UI.Deroulant(d, LARGEUR_CTRL, 22, function()
        local out = {}
        for _, v in ipairs(LCM.Equilibrage.lanterne.variateurs) do out[#out + 1] = { id = v, label = Variateur(v) } end
        return out
    end, function(v) Refus(L.DefinirVariateur(v)) f:Afficher() end)
    Poser(f.variateur, 34)

    f.etat = UI.Texte(d, "", UI.C.titre, "GameFontNormalSmall")
    Poser(f.etat, 16)
    f.lblCharge = Libelle(d, "Charge restante")
    Poser(f.lblCharge, 16)
    f.charge = UI.Barre(d, UI.C.accent, LARGEUR_CTRL, 18)
    Poser(f.charge, 22)
    f.restant = UI.Texte(d, "", UI.C.discret, "GameFontNormalSmall")
    Poser(f.restant, 22)

    f.allumer = UI.Bouton(d, "Allumer", LARGEUR_CTRL, 22, function()
        Refus(L.Basculer())
        f:Afficher()
    end)
    Poser(f.allumer, 28)
    f.recharger = UI.Bouton(d, "Recharger", LARGEUR_CTRL, 22, function()
        local ok, raison = L.Recharger()
        if not ok then LCM.Alerte(raison) elseif raison then LCM.Info("recharge : en attente du serveur.") end
        f:Afficher()
    end)
    Poser(f.recharger, 28)

    -- Le rouage de Survive : le volet des parametres, par-dessus la moitie
    -- gauche, puisqu'elle n'a encore rien a montrer.
    f.reglages = UI.Bouton(d, "Paramètres", LARGEUR_CTRL, 20, function()
        f.volet:SetShown(not f.volet:IsShown())
        f:Afficher()
    end)
    Poser(f.reglages, 24)

    -- ----- Le volet des parametres ------------------------------------------
    local v = CreateFrame("Frame", nil, c)
    f.volet = v
    v:SetAllPoints(f.gauche)
    v:SetFrameLevel(f.gauche:GetFrameLevel() + 5)
    v:Hide()

    local vy = -6
    local function PoserVolet(w, hauteur, decalage)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", v, "TOPLEFT", MARGE + (decalage or 0), vy)
        vy = vy - hauteur
    end

    f.lblEmotes = UI.Texte(v, "Émotes", UI.C.titre, "GameFontNormalSmall")
    PoserVolet(f.lblEmotes, 18)
    f.emotes = {}
    for _, def in ipairs(L.EMOTES) do
        local cle, nom = def.cle, def.label
        local ligne = CreateFrame("Frame", nil, v)
        ligne:SetSize(LARGEUR_CTRL, 30)
        ligne.nom = Libelle(ligne, nom)
        ligne.nom:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, 0)
        ligne.texte = UI.Texte(ligne, "", UI.C.discret, "GameFontNormalSmall")
        ligne.texte:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, -13)
        ligne.texte:SetPoint("RIGHT", ligne, "RIGHT", -70, 0)
        ligne.texte:SetJustifyH("LEFT")
        ligne.texte:SetWordWrap(false)
        ligne.modifier = UI.Bouton(ligne, "Modifier", 64, 18, function()
            UI.Demande():Demander("Émote : " .. nom, L.Emote(cle), function(texte)
                local ok, raison = L.DefinirEmote(cle, texte)
                if ok then f:Afficher() end
                return ok, raison
            end, nil, 200)
        end)
        ligne.modifier:SetPoint("TOPRIGHT", ligne, "TOPRIGHT", 0, 0)
        ligne.cle = cle
        PoserVolet(ligne, 32)
        f.emotes[#f.emotes + 1] = ligne
    end

    f.restaurer = UI.Bouton(v, "Restaurer les émotes par défaut", LARGEUR_CTRL, 20, function()
        L.RestaurerEmotes()
        f:Afficher()
    end)
    PoserVolet(f.restaurer, 26)

    f.lblCanal = Libelle(v, "Canal des émotes")
    PoserVolet(f.lblCanal, 16)
    f.canal = UI.Deroulant(v, LARGEUR_CTRL, 22, function() return L.CANAUX_EMOTE end,
        function(id) Refus(L.DefinirCanalEmote(id)) f:Afficher() end)
    PoserVolet(f.canal, 30)

    -- « Debug » dans Survive : quand la lanterne reste coincee.
    f.reinitialiser = UI.Bouton(v, "Réinitialiser la lanterne", LARGEUR_CTRL, 20, function()
        L.Reinitialiser()
        f:Afficher()
    end)
    PoserVolet(f.reinitialiser, 24)

    function f:Afficher()
        L.Synchroniser()
        local e = L.Etat()
        local lanterne, cristal = L.LanterneChoisie(), L.CristalChoisi()
        self.lanterne:Definir(lanterne and lanterne.id or false, lanterne and lanterne.label or "Aucune lanterne")
        self.cristal:Definir(cristal and cristal.id or false, cristal and cristal.label or "Insère un cristal")
        self.variateur:Definir(L.Variateur(), Variateur(L.Variateur()))

        local allumee = L.Allumee()
        if L.EnPauseMJ() then
            self.etat:SetText("État : pause du MJ — " .. (allumee and "allumée" or "éteinte"))
        else
            self.etat:SetText("État : " .. (allumee and "allumée" or "éteinte"))
        end

        local max, charge = L.ChargeMax(), L.Charge()
        self.charge:Regler(charge, max)
        self.charge.label:SetText(max > 0 and string.format("%.0f%%", charge / max * 100) or "—")
        if max > 0 and lanterne then
            self.restant:SetText("Éclairage restant : " .. Duree(L.Restant()))
        else
            self.restant:SetText("")
        end

        -- Comme Survive : une lanterne vide ne s'allume pas, et le bouton le dit
        -- au lieu de refuser au clic.
        if allumee then
            self.allumer.label:SetText("Éteindre")
            self.allumer:SetAlpha(1)
            self.allumer:Enable()
        elseif max > 0 and charge <= 0 then
            self.allumer.label:SetText("Recharger d'abord")
            self.allumer:SetAlpha(0.4)
            self.allumer:Disable()
        else
            self.allumer.label:SetText("Allumer")
            self.allumer:SetAlpha(1)
            self.allumer:Enable()
        end

        self.aVenir:SetShown(not self.volet:IsShown())
        self.reglages.label:SetText(self.volet:IsShown() and "Fermer les paramètres" or "Paramètres")
        if self.volet:IsShown() then
            for _, ligne in ipairs(self.emotes) do
                local texte = L.Emote(ligne.cle)
                ligne.texte:SetText(texte ~= "" and texte or "|cff7f7a70(aucune)|r")
            end
            local canal = L.CanalEmote()
            for _, option in ipairs(L.CANAUX_EMOTE) do
                if option.id == canal then self.canal:Definir(canal, option.label) end
            end
        end
    end

    -- Ouvrir et ranger la lanterne se jouent en emote, comme dans Survive. La
    -- deconnexion n'est pas un geste : elle ne dit rien.
    f:HookScript("OnShow", function(self)
        self:Afficher()
        L.DireEmote("open")
    end)
    f:HookScript("OnHide", function()
        if not deconnexion then L.DireEmote("close") end
    end)

    L.onChange = function() if f:IsShown() then f:Afficher() end end
    L.onTick = L.onChange
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    f:SetShown(not f:IsShown())
    return f
end

LCM.WhenReady(function()
    UI.Menu.Lier("outils_portes", Ecran.Basculer)
end)
