-- Objets > Outils : les places de la ceinture portent les objets de
-- categorie « outil » ET la lanterne. Certains ouvrent un panneau specialise.
--
-- La lanterne n'est pas un objet « outil » : c'est une entree de la categorie
-- Lanternes du compendium (le MJ, 23 octobre 2026). Rien ne s'ouvre tant que
-- le joueur n'en a pas une dans ses sacs ; il l'equipe ici, elle prend une
-- des places, et le menu Lanterne s'ouvre alors sur elle (Core/Lanternes.lua,
-- `EquiperLanterne`).
local _, LCM = ...
local UI = LCM.UI
local L = LCM.Lanterne
local Ceinture = {}
UI.Ceinture = Ceinture

-- Les outils qui ouvrent un panneau, par identifiant d'objet.
local OUVRIR = {
    outil_scanner_valrazkah = function() return UI.Scanner.Basculer() end,
}

-- Ce qu'on peut equiper depuis les sacs. Les options portent une reference
-- (« lanternes/x », « objets/x ») : un outil et une lanterne pourraient avoir
-- le meme identifiant.
local function Candidats(entity)
    local out = {}
    if not entity then return out end
    for _, objet in ipairs(LCM.Objets.list) do
        if objet.categorie == "outil" and LCM.Objets.Possede(entity, objet.id) then
            out[#out + 1] = { id = "objets/" .. objet.id, label = objet.label }
        end
    end
    for _, lanterne in ipairs(L.LanternesPortees()) do
        out[#out + 1] = { id = "lanternes/" .. lanterne.id, label = lanterne.label }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Ce qui est porte, dans l'ordre des lignes : la lanterne d'abord, puis les
-- outils dans leur ordre d'equipement (`rang` : leur place chez Core/Objets).
local function Portes(entity)
    local out = {}
    if not entity then return out end
    local idLanterne = L.IdEquipe(entity)
    if idLanterne then
        local lanterne = LCM.Lanternes.Get(idLanterne)
        out[#out + 1] = { genre = "lanterne", id = idLanterne,
            label = lanterne and lanterne.label or ("Lanterne inconnue : " .. idLanterne),
            description = lanterne and lanterne.description }
    end
    for rang, id in ipairs(LCM.Objets.Ids(entity, "outil")) do
        local objet = LCM.Objets.Get(id)
        out[#out + 1] = { genre = "outil", id = id, rang = rang,
            label = objet and objet.label or ("Objet inconnu : " .. id),
            description = objet and objet.description }
    end
    return out
end
Ceinture.Portes = Portes

local function Ouvrir(porte)
    if not porte then return nil end
    if porte.genre == "lanterne" then return function() return UI.Lanterne.Basculer() end end
    return OUVRIR[porte.id]
end

local function Fermer(porte)
    if porte.genre == "lanterne" then
        if UI.Lanterne.frame then UI.Lanterne.frame:Hide() end
    elseif porte.id == "outil_scanner_valrazkah" and UI.Scanner.frame then
        UI.Scanner.frame:Hide()
    end
end

local function Construire()
    local f = UI.Fenetre("outils_portes", "Ceinture porte-outils", 560, 580,
        { x = 180, y = -40 })
    Ceinture.frame = f
    f:SousTitre("Objets portés")
    local c = f.contenu
    f.image = c:CreateTexture(nil, "ARTWORK")
    f.image:SetTexture("Interface\\AddOns\\LesContesMalveillants\\ressources\\ceinture\\ceinture.blp")
    f.image:SetSize(520, 240)
    f.image:SetPoint("TOP", c, "TOP", 0, 0)

    -- La lanterne prend une des places des outils : pas de ligne en plus.
    f.lignes = {}
    for i = 1, LCM.Objets.Capacite("outil") do
        local y = -232 - (i - 1) * 39
        local nom = UI.Texte(c, "", UI.C.titre, "GameFontNormalSmall")
        nom:SetPoint("TOPLEFT", c, "TOPLEFT", 18, y)
        nom:SetWidth(270)
        local ouvrir = UI.Bouton(c, "Ouvrir", 82, 24, function()
            local action = Ouvrir(f.lignes[i].porte)
            if not action then return end
            local ok, raison = action()
            if not ok then LCM.Alerte(raison) end
        end)
        ouvrir:SetPoint("TOPRIGHT", c, "TOPRIGHT", -118, y + 3)
        UI.Bulle(ouvrir, function()
            local porte = f.lignes[i].porte
            return porte and porte.label or "Emplacement libre"
        end, function()
            local porte = f.lignes[i].porte
            if not porte then return "Équipez un outil depuis vos sacs." end
            return porte.description
        end, 0.2)
        local retirer = UI.Bouton(c, "Retirer", 100, 24, function()
            local porte = f.lignes[i].porte
            if not porte then return end
            local ok, raison
            if porte.genre == "lanterne" then
                ok, raison = L.RetirerLanterne()
            else
                -- Le rang de l'outil chez Core/Objets, pas celui de la ligne :
                -- la lanterne, quand elle est portee, occupe la premiere.
                ok, raison = LCM.Objets.Desequiper(LCM.Entities.Self(), porte.id, porte.rang)
            end
            if not ok then LCM.Alerte(raison) else Fermer(porte) end
            f:Afficher()
        end)
        retirer:SetPoint("LEFT", ouvrir, "RIGHT", 8, 0)
        f.lignes[i] = { nom = nom, ouvrir = ouvrir, retirer = retirer }
    end

    f.equiper = UI.Deroulant(c, 350, 24, function()
        return Candidats(LCM.Entities.Self())
    end, function(ref)
        local entity = LCM.Entities.Self()
        local famille, id = tostring(ref or ""):match("^([%w_]+)/(.+)$")
        local ok, raison
        if famille == "lanternes" then
            ok, raison = L.EquiperLanterne(id)
        else
            -- Core/Objets ne compte que les outils : la place prise par la
            -- lanterne se verifie ici.
            local capacite, prises = L.PlacesCeinture(entity)
            if prises >= capacite then
                ok, raison = false, "la ceinture est pleine : retire un outil d'abord."
            else
                ok, raison = LCM.Objets.Equiper(entity, id)
            end
        end
        if not ok then LCM.Alerte(raison) end
        f:Afficher()
    end)
    f.equiper:SetPoint("TOPLEFT", c, "TOPLEFT", 18, -400)
    local aide = UI.Texte(c, "Équiper un outil présent dans vos sacs", UI.C.discret,
        "GameFontNormalSmall")
    aide:SetPoint("BOTTOMLEFT", f.equiper, "TOPLEFT", 0, 5)

    function f:Afficher()
        local entity = LCM.Entities.Self()
        local portes = Portes(entity)
        for i, ligne in ipairs(self.lignes) do
            local porte = portes[i]
            ligne.porte = porte
            ligne.id = porte and porte.id
            ligne.nom:SetText(string.format("%d · %s", i, porte and porte.label or "Emplacement libre"))
            local ouvrable = Ouvrir(porte) ~= nil
            ligne.ouvrir:SetEnabled(ouvrable)
            ligne.ouvrir:SetAlpha(ouvrable and 1 or 0.45)
            ligne.retirer:SetEnabled(porte ~= nil)
            ligne.retirer:SetAlpha(porte and 1 or 0.45)
        end
        local choix = Candidats(entity)
        -- Une lanterne s'echange contre celle qu'on porte : elle n'a pas
        -- besoin d'une place libre. Un outil, si.
        local capacite, prises = L.PlacesCeinture(entity)
        local libre = prises < capacite or L.IdEquipe(entity) ~= nil and #L.LanternesPortees() > 0
        self.equiper:Definir(false, #choix == 0 and "Aucun outil dans les sacs" or "Équiper depuis les sacs…")
        self.equiper:SetEnabled(libre and #choix > 0)
        self.equiper:SetAlpha(libre and #choix > 0 and 1 or 0.45)
    end
    f:HookScript("OnShow", function(self) self:Afficher() end)
    if LCM.Entities.EcouterSoi then
        LCM.Entities.EcouterSoi(function() if f:IsShown() then f:Afficher() end end)
    end
    f:Hide()
    return f
end

function Ceinture.Fenetre()
    if not Ceinture.frame then Construire() end
    return Ceinture.frame
end

function Ceinture.Basculer()
    local f = Ceinture.Fenetre()
    f:SetShown(not f:IsShown())
    return f
end

LCM.WhenReady(function()
    UI.Menu.Lier("outils_portes", Ceinture.Basculer)
end)
