-- Les Raccourcis (le MJ, 25 octobre 2026) : Alt + clic gauche sur le sceau
-- ouvre, a sa droite, ce que le joueur a choisi d'avoir sous la main — une
-- fenetre du menu, un outil precis, un sort de grimoire. Le dernier rond, « + »,
-- en ajoute ; le clic droit sur un raccourci le deplace ou le retire.
--
-- Les memes pieces que le radial et que Mes Outils : vignettes du sceau, jet
-- pourpre, et pour un outil, ses actions depliees dessous
-- (UI.MesOutils.PoserActions). Ce que la sauvegarde en retient est dans
-- Core/Raccourcis.lua : des references, rien d'autre.
--
-- Une rangee, au pas d'un eventail : MAX_ENTREES vignettes, le « + » compris.

local _, LCM = ...
local UI = LCM.UI
local Raccourcis = LCM.Raccourcis

local Ecran = {}
-- UI.Raccourcis est deja pris : les raccourcis CLAVIER (UI/Raccourcis.lua).
UI.PanneauRaccourcis = Ecran

local ECART, PAS = 72, 61

local function Moi() return LCM.Entities.Self() end
local function Max() return UI.Radial.MAX_ENTREES - 1 end

local function Refus(ok, raison)
    if not ok and raison then LCM.Alerte(raison) end
    return ok
end

-- ===== Ce que designe une reference ==========================================

-- Les entrees du menu qui ouvrent quelque chose, dossiers parcourus. « Mes
-- Outils » n'y est pas : son bandeau prolonge SON bouton du radial, et chaque
-- outil se met lui-meme en raccourci.
local function Fenetres()
    local out = {}
    local function Parcourir(noeuds)
        for _, n in ipairs(UI.Menu.Visibles(noeuds)) do
            if n.enfants then
                Parcourir(n.enfants)
            elseif type(n.onClick) == "function" and n.id ~= "mes_outils" then
                out[#out + 1] = n
            end
        end
    end
    Parcourir(UI.Menu.STRUCTURE)
    return out
end

-- Le sort `sortId` d'un grimoire POSSEDE, ou nil.
local function Sort(entity, grimoireId, sortId)
    local grimoire = LCM.Grimoires.Get(grimoireId)
    if not (grimoire and LCM.Grimoires.Has(entity, grimoireId)) then return nil end
    if grimoire.personnel then return LCM.Sorts.Get(entity, sortId), grimoire end
    for _, sous in ipairs(LCM.Grimoires.SousGrimoires(grimoire)) do
        for _, sort in ipairs(sous.sorts or {}) do
            if tostring(sort.id) == sortId then return sort, grimoire end
        end
    end
    return nil
end

-- L'outil porte que designe `genre:id` (pour ses actions), ou nil.
local function Porte(entity, genre, id)
    for _, porte in ipairs(UI.MesOutils.Portes(entity)) do
        if porte.genre == genre and porte.id == id then return porte end
    end
end

-- Ce qu'il faut pour dessiner et servir un raccourci : { label, icone,
-- faire, porte, eteint }. `eteint` dit pourquoi on ne peut pas s'en servir.
function Ecran.Resoudre(entity, ref)
    local genre, reste = Raccourcis.Lire(ref)
    if genre == "fenetre" then
        local n = UI.Menu.Trouver(reste)
        if not n then return { label = reste, eteint = "cette fenêtre n'existe plus." } end
        if type(n.onClick) ~= "function" then return { label = n.label, icone = n.icone, eteint = "pas encore disponible." } end
        return { label = n.label, icone = n.icone, faire = n.onClick }
    elseif genre == "outil" or genre == "lanterne" then
        local def = genre == "outil" and LCM.Objets.Get(reste) or LCM.Lanternes.Get(reste)
        local r = { label = def and def.label or reste, icone = LCM.Icone(def and def.icone) }
        if not def then r.eteint = "cet outil n'existe plus." return r end
        r.porte = Porte(entity, genre, reste)
        if not r.porte then r.eteint = string.format("« %s » n'est pas équipé : Équipements › Outils.", r.label) end
        return r
    elseif genre == "sort" then
        local grimoireId, sortId = reste:match("^(.-):(.+)$")
        local sort = grimoireId and Sort(entity, grimoireId, sortId)
        if not sort then return { label = sortId or reste, eteint = "ce sort n'est plus dans tes grimoires." } end
        -- Comme le bouton de sa carte dans le grimoire : il se lance s'il fait
        -- quelque chose (competence, jet, action) ; sinon il se cite.
        return { label = tostring(sort.label or sort.id), icone = LCM.Icone(sort.icone), faire = function()
            if sort.competence or sort.jet or sort.action then
                Refus(LCM.Sorts.Lancer(entity, sort))
            else
                LCM.Lien.Inserer(LCM.Lien.Sort(entity, sort))
            end
        end }
    end
    return { label = tostring(ref), eteint = "raccourci illisible." }
end

-- Ce que le « + » propose, par groupes : ce qui n'y est pas deja.
function Ecran.Candidats(entity)
    local deja = {}
    for _, r in ipairs(Raccourcis.Liste(entity)) do deja[r] = true end
    local out = {}
    local function Proposer(groupe, ref, label)
        if not deja[ref] then
            deja[ref] = true
            out[#out + 1] = { groupe = groupe, id = ref, label = label }
        end
    end
    for _, n in ipairs(Fenetres()) do Proposer("Fenêtres", "fenetre:" .. n.id, n.label) end
    -- Les outils equipes, puis ceux des sacs : un raccourci vers un outil du
    -- sac servira des qu'on l'equipera.
    for _, porte in ipairs(UI.MesOutils.Portes(entity)) do
        Proposer("Outils", porte.genre .. ":" .. porte.id, porte.label)
    end
    for _, objet in ipairs(LCM.Objets.CandidatsPossedes(entity, "outil")) do
        Proposer("Outils", "outil:" .. objet.id, objet.label)
    end
    for _, lanterne in ipairs(LCM.Lanterne.LanternesPortees()) do
        Proposer("Outils", "lanterne:" .. lanterne.id, lanterne.label)
    end
    for _, grimoire in ipairs(LCM.Grimoires.Possedes(entity)) do
        local nom = (LCM.Grimoires.Affichage(grimoire, entity) or grimoire).label or grimoire.id
        local sorts = {}
        if grimoire.personnel then
            sorts = LCM.Sorts.Liste(entity)
        else
            for _, sous in ipairs(LCM.Grimoires.SousGrimoires(grimoire)) do
                for _, sort in ipairs(sous.sorts or {}) do sorts[#sorts + 1] = sort end
            end
        end
        for _, sort in ipairs(sorts) do
            if sort.id then
                Proposer("Sorts · " .. tostring(nom), "sort:" .. grimoire.id .. ":" .. sort.id,
                    tostring(sort.label or sort.id))
            end
        end
    end
    return out
end

-- ===== Le panneau ============================================================

local function Construire()
    local R = UI.Radial
    local f = CreateFrame("Frame", "LCM_PanneauRaccourcis", UIParent)
    Ecran.frame = f
    -- Centre sur le sceau, au-dessus du radial : tout se place a sa droite.
    f:SetFrameStrata("HIGH")
    f:SetSize(2 * (ECART + R.MAX_ENTREES * PAS), 2 * 150)
    f:EnableMouse(false)
    f.jet = R.CreerJet(f, f:GetFrameLevel())
    f.boutons = {}

    local choix = UI.Choix("raccourcis", "Ajouter un raccourci")

    local function Ajouter(ancre)
        local options = Ecran.Candidats(Moi())
        if #options == 0 then LCM.Alerte("rien d'autre à mettre en raccourci.") return end
        choix:Proposer(ancre, options, function(ref)
            Refus(Raccourcis.Ajouter(Moi(), ref, Max()))
            f:Afficher()
        end)
    end

    local function Menu(b)
        local index = b.index
        local options = {}
        if index > 1 then
            options[#options + 1] = { label = "Vers la gauche", action = function()
                Refus(Raccourcis.Deplacer(Moi(), index, -1)) f:Afficher() end }
        end
        if index < #Raccourcis.Liste(Moi()) then
            options[#options + 1] = { label = "Vers la droite", action = function()
                Refus(Raccourcis.Deplacer(Moi(), index, 1)) f:Afficher() end }
        end
        options[#options + 1] = { label = "Retirer", action = function()
            Refus(Raccourcis.Retirer(Moi(), index))
            f.choisi = nil
            f:Afficher()
        end }
        UI.MenuContexte():Ouvrir(b, options)
    end

    local function Bouton(i)
        local b = f.boutons[i]
        if b then return b end
        b = R.Vignette(f, R.ACTION, true, f:GetFrameLevel() + 4)
        b:SetPoint("CENTER", f, "CENTER", ECART + (i - 1) * PAS, 0)
        b.glyphe = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        b.glyphe:SetPoint("CENTER", b, "CENTER", 0, 1)
        b.glyphe:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, souris)
            if self.plus then
                if self.disponible then Ajouter(self) else LCM.Alerte(self.plein) end
                return
            end
            if souris == "RightButton" then Menu(self) return end
            local r = self.resolu
            if r.eteint then LCM.Alerte(r.eteint) return end
            if r.porte then
                -- Un outil : ses actions se deplient dessous, comme dans Mes Outils.
                f.choisi = f.choisi ~= self.ref and self.ref or nil
                f:Afficher()
                return
            end
            r.faire()
        end)
        f.boutons[i] = b
        return b
    end

    function f:Afficher()
        local moi = Moi()
        local liste = Raccourcis.Liste(moi)
        local cibles, choisi, xChoisi = {}, nil, 0
        for i, ref in ipairs(liste) do
            local b = Bouton(i)
            local r = Ecran.Resoudre(moi, ref)
            b.plus, b.ref, b.index, b.resolu = nil, ref, i, r
            b.icone:SetTexture(r.icone)
            local teinte = r.eteint and 0.42 or 1
            b.icone:SetVertexColor(teinte, teinte, teinte)
            b.glyphe:SetText(r.icone and "" or "?")
            b.legende:SetText(r.label)
            b.disponible = not r.eteint
            R.Bulle(b, r.label, (r.eteint and (r.eteint .. "\n") or (r.porte and "Clic : ses actions.\n" or "Clic : ouvrir.\n"))
                .. "Clic droit : déplacer ou retirer.")
            local actif = r.porte ~= nil and self.choisi == ref
            R.Eclairer(b, actif, b.survole)
            if actif then choisi, xChoisi = r.porte, ECART + (i - 1) * PAS end
            cibles[#cibles + 1] = { x = ECART + (i - 1) * PAS, y = 0 }
            b:Show()
        end
        -- Le « + » ferme la rangee ; plein, il reste, eteint, et dit pourquoi.
        local n = #liste + 1
        local plus = Bouton(n)
        plus.plus, plus.ref, plus.index, plus.resolu = true, nil, nil, nil
        plus.icone:SetTexture(nil)
        plus.glyphe:SetText("+")
        plus.legende:SetText("")
        local plein = #liste >= Max()
        plus.disponible = not plein
        plus.plein = string.format("tes raccourcis sont pleins (%d) : retires-en un d'abord.", Max())
        plus.glyphe:SetAlpha(plein and 0.4 or 1)
        R.Bulle(plus, "Ajouter un raccourci", plein and plus.plein
            or "Une fenêtre, un outil ou un sort : à toi de choisir.")
        R.Eclairer(plus, false, plus.survole)
        plus:Show()
        cibles[#cibles + 1] = { x = ECART + (n - 1) * PAS, y = 0 }
        for i = n + 1, #self.boutons do self.boutons[i]:Hide() end
        R.Diriger(self.jet, 0, 0, cibles)
        if not choisi then self.choisi = nil end
        UI.MesOutils.PoserActions(self, xChoisi, choisi and UI.MesOutils.Actions(moi, choisi) or {})
        self.nombre = #liste
    end

    -- Le panneau suit le sceau : cache avec lui. Il se relit aussi de
    -- lui-meme (un outil equipe ailleurs, une lanterne qui s'eteint).
    local ecoule, temps = 0, 0
    f:SetScript("OnUpdate", function(self, dt)
        local sceau = UI.Radial.frame
        if not (sceau and sceau:IsVisible()) then self:Hide() return end
        dt = tonumber(dt) or 0
        temps = temps + dt
        for _, b in ipairs(self.boutons) do R.AnimerMagie(b, temps) end
        for _, b in ipairs(self.actions or {}) do R.AnimerMagie(b, temps) end
        ecoule = ecoule + dt
        if ecoule >= 0.5 then ecoule = 0 self:Afficher() end
    end)
    f:HookScript("OnShow", function(self) self:Afficher() end)
    LCM.Entities.EcouterSoi(function() if f:IsShown() then f.choisi = nil f:Afficher() end end)
    f:Hide()
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Actualiser()
    if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
end

-- Alt + clic sur le sceau (UI/Radial.lua). Le panneau se pose sur le sceau
-- et s'ouvre vers la droite.
function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() return f end
    local sceau = UI.Radial.frame and UI.Radial.frame.sceau
    f:ClearAllPoints()
    if sceau then f:SetPoint("CENTER", sceau, "CENTER", 0, 0)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    f.choisi = nil
    f:Show()
    return f
end
