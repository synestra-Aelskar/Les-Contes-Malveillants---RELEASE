-- Objets > Outils : deux crochets pour les outils portes.
local _, LCM = ...
local UI = LCM.UI
local Ceinture = {}
UI.Ceinture = Ceinture

local function Moi() return LCM.Entities.Self() end

local function Portes(entity)
    local places, utilisees = {}, {}
    if not entity then return places end
    for rang, id in ipairs(LCM.Objets.Ids(entity, "outil")) do
        local place = entity.ceinturePlaces and tonumber(entity.ceinturePlaces[rang])
        if not place or place < 1 or place > 2 or utilisees[place] then
            place = not utilisees[1] and 1 or not utilisees[2] and 2 or nil
        end
        if place then
            places[place] = { genre = "outil", id = id, rang = rang, objet = LCM.Objets.Get(id) }
            utilisees[place] = true
        end
    end
    local id = LCM.Lanterne and LCM.Lanterne.IdEquipe(entity)
    if id then
        local place = tonumber(entity.ceintureLanternePlace)
        if not place or place < 1 or place > 2 or utilisees[place] then
            place = not utilisees[1] and 1 or not utilisees[2] and 2 or nil
        end
        if place then places[place] = { genre = "lanterne", id = id, objet = LCM.Lanternes.Get(id) } end
    end
    return places
end
Ceinture.Portes = Portes

local function Equiper(id, place)
    local entity = Moi()
    if not entity then return false, "aucun personnage." end
    local avant = Portes(entity)
    if avant[place] then return false, "cet emplacement est déjà occupé." end
    local famille, identifiant = tostring(id):match("^([%w_]+)/(.+)$")
    if famille == "lanternes" then
        local ok, raison = LCM.Lanterne.EquiperLanterne(identifiant)
        if not ok then return false, raison end
        entity.ceintureLanternePlace = place
        if UI.Inventaires then UI.Inventaires.Actualiser() end
        return true
    end
    id = famille == "objets" and identifiant or id
    local objet = LCM.Objets.Get(id)
    if not objet or objet.categorie ~= "outil" then return false, "cet emplacement n'accepte qu'un outil." end
    local ok, raison = LCM.Objets.Equiper(entity, id)
    if not ok then return false, raison end
    entity.ceinturePlaces = entity.ceinturePlaces or {}
    for position, porte in pairs(avant) do
        if porte.genre == "outil" then entity.ceinturePlaces[porte.rang] = position end
    end
    entity.ceinturePlaces[#LCM.Objets.Ids(entity, "outil")] = place
    if UI.Vues then UI.Vues.Rafraichir() end
    if UI.Inventaires then UI.Inventaires.Actualiser() end
    return true
end
Ceinture.Equiper = Equiper

local function DessinerPlus(b)
    b.vide = CreateFrame("Frame", nil, b)
    b.vide:SetAllPoints(b)
    b.vide:EnableMouse(false)
    -- Un filet rond et un fond sombre, avec les couleurs des boutons de l'addon.
    for _, disque in ipairs({
        { rayon = 14, couleur = UI.C.bordure },
        { rayon = 12, couleur = UI.C.fond },
    }) do
        for y = -disque.rayon, disque.rayon do
            local largeur = 2 * math.sqrt(disque.rayon * disque.rayon - y * y)
            local trait = b.vide:CreateTexture(nil, "ARTWORK")
            local c = disque.couleur
            trait:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
            trait:SetSize(math.max(1, largeur), 1)
            trait:SetPoint("CENTER", b, "CENTER", 0, y)
        end
    end
    b.plus = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.plus:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.plus:SetText("+")
    b.plus:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
end

local function Construire()
    local f = CreateFrame("Frame", "LCMCeinturePorteOutils", UIParent)
    Ceinture.frame = f
    f:SetSize(520, 260)
    f:SetPoint("CENTER", UIParent, "CENTER", 180, -40)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    f.image = f:CreateTexture(nil, "ARTWORK")
    f.image:SetTexture("Interface\\AddOns\\LesContesMalveillants\\ressources\\ceinture\\ceinture.blp")
    f.image:SetAllPoints(f)

    local choix = UI.Choix("ceinture_outils", "Outils dans les sacs")
    f.emplacements = {}
    for i, crochet in ipairs({ { x = 0.321, y = 0.563 }, { x = 0.774, y = 0.569 } }) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(36, 36)
        b:SetPoint("CENTER", f, "TOPLEFT", crochet.x * 520, -crochet.y * 260)
        b.place = i
        DessinerPlus(b)
        b.objetIcone = b:CreateTexture(nil, "OVERLAY")
        b.objetIcone:SetSize(30, 30)
        b.objetIcone:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.objetIcone:Hide()
        b:SetScript("OnClick", function(self)
            if self.porte then
                local porte = self.porte
                local options = {}
                if porte.genre == "outil" and porte.id == "outil_scanner_valrazkah" then
                    options[#options + 1] = { label = "Ouvrir", action = function() UI.Scanner.Basculer() end }
                elseif porte.genre == "lanterne" then
                    options[#options + 1] = { label = "Ouvrir", action = function() UI.Lanterne.Basculer() end }
                end
                options[#options + 1] = { label = "Retirer", action = function()
                    local ok, raison
                    if porte.genre == "lanterne" then
                        ok, raison = LCM.Lanterne.RetirerLanterne()
                    else
                        ok, raison = LCM.Objets.Desequiper(Moi(), porte.id, porte.rang)
                    end
                    if not ok then LCM.Alerte(raison) end
                    f:Afficher()
                    if UI.Vues then UI.Vues.Rafraichir() end
                    if UI.Inventaires then UI.Inventaires.Actualiser() end
                end }
                UI.MenuContexte():Ouvrir(self, options)
                return
            end
            local options = {}
            for _, objet in ipairs(LCM.Objets.CandidatsPossedes(Moi(), "outil")) do
                options[#options + 1] = { id = "objets/" .. objet.id, label = objet.label }
            end
            for _, lanterne in ipairs(LCM.Lanterne.LanternesPortees()) do
                options[#options + 1] = { id = "lanternes/" .. lanterne.id, label = lanterne.label }
            end
            if #options == 0 then LCM.Alerte("aucun outil compatible dans les sacs.") return end
            table.sort(options, function(a, b) return a.label < b.label end)
            choix:Proposer(self, options, function(id)
                local ok, raison = Equiper(id, self.place)
                if not ok then LCM.Alerte(raison) end
                f:Afficher()
            end)
        end)
        UI.Glisser.Cible(b, function(objet)
            if b.porte then return false, "cet emplacement est déjà occupé." end
            local ref = tostring(objet.ref or "")
            local id = ref:match("^objets/(.+)$")
            local outil = id and LCM.Objets.Get(id)
            if not (outil and outil.categorie == "outil")
                and not (ref:match("^lanternes/(.+)$") and LCM.Lanternes.Get(ref:match("^lanternes/(.+)$"))) then
                return false, "cet emplacement n'accepte qu'un outil ou une lanterne."
            end
            if not (objet.origine and objet.origine.case) then
                return false, "glisse un outil depuis tes sacs."
            end
            return true
        end, function(objet)
            local ok, raison = Equiper(objet.ref, b.place)
            if not ok then LCM.Alerte(raison) end
            f:Afficher()
        end)
        UI.Bulle(b, function() return b.porte and b.porte.objet and b.porte.objet.label or "Équiper un outil" end,
            function() return b.porte and b.porte.objet and b.porte.objet.description or "Choisir un outil dans les sacs ou le glisser ici." end)
        f.emplacements[i] = b
    end

    function f:Afficher()
        local portes = Portes(Moi())
        for i, b in ipairs(self.emplacements) do
            b.porte = portes[i]
            b.vide:SetShown(not b.porte)
            b.plus:SetShown(not b.porte)
            local lanterne = b.porte and b.porte.genre == "lanterne"
            b.objetIcone:SetShown(b.porte ~= nil and not lanterne)
            if lanterne and not b.lanterne then b.lanterne = UI.LanterneCeinture.Creer(self, b) end
            if b.lanterne then
                b.lanterne:SetShown(lanterne == true)
                if lanterne then b.lanterne:Actualiser() end
            end
            if b.porte then b.objetIcone:SetTexture(b.porte.objet and b.porte.objet.icone or LCM.Icone()) end
        end
    end
    f:HookScript("OnShow", function(self) self:Afficher() end)
    local ecoule = 0
    f:SetScript("OnUpdate", function(self, dt)
        ecoule = ecoule + dt
        if ecoule >= 0.2 then ecoule = 0 self:Afficher() end
    end)
    LCM.Entities.EcouterSoi(function() if f:IsShown() then f:Afficher() end end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = f:GetName() end
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

LCM.WhenReady(function() UI.Menu.Lier("outils_portes", Ceinture.Basculer) end)
