-- « Mes Outils » (Objets, sous Inventaires ; le MJ, 25 octobre 2026) : ce qui
-- est equipe dans Équipements > Outils, et ce qu'on en fait.
--
-- Le bouton du menu radial ouvre un BANDEAU vers la droite. Le retour (« < »)
-- prend la PLACE du bouton Mes Outils, et le referme ; a sa droite, une
-- vignette par outil porte, reliees par le jet pourpre du radial. Rien de
-- porte : une seule vignette, « — ». Ce sont les pieces du radial lui-meme
-- (Radial.Vignette, Radial.Diriger) : un premier essai dessine a part, copie
-- d'un autre addon, perdait le theme du sceau. Un clic sur un outil deplie
-- dessous ses actions, et seulement celles qui ont un sens pour lui :
--
--   contenant (gourde)   Boire · Voir · Déséquiper
--   lanterne             Allumer ou Éteindre · Voir · Déséquiper
--   scanner              Voir · Déséquiper
--   autre outil          Déséquiper
--
-- « Voir » ouvre la vue propre a l'outil : UI/Lanterne.lua, UI/Scanner.lua,
-- ou, pour un contenant, la fenetre breve d'ici (ce qu'il tient, a combien).
--
-- Il remplace la ceinture dessinee (UI/Ceinture.lua, retiree le meme jour).
-- Equiper reste l'affaire de la fiche : le bandeau ne propose pas d'outil,
-- il sert ceux qui sont deja a la ceinture.

local _, LCM = ...
local UI = LCM.UI

local MesOutils = {}
UI.MesOutils = MesOutils

local ID_MENU = "mes_outils"
local SCANNER = "outil_scanner_valrazkah"
-- Les outils au pas d'un eventail du radial (61 entre deux voisines, pour
-- Radial.ACTION = 46) ; les actions, un cran plus petites, sous leur outil.
local ECART_TETE, PAS = 72, 61
local ACTION, PAS_ACTION, DESSOUS = 38, 54, 70

local ICONES = {
    boire = "Interface\\Icons\\INV_Drink_07",
    voir = "Interface\\Icons\\INV_Misc_Spyglass_02",
    desequiper = "Interface\\Icons\\INV_Misc_Bag_08",
    allumer = "Interface\\Icons\\Spell_Fire_Fire",
    eteindre = "Interface\\Icons\\Spell_Shadow_Twilight",
}

local function Moi() return LCM.Entities.Self() end

local function Refus(ok, raison)
    if not ok and raison then LCM.Alerte(raison) end
    return ok
end

-- Ce qui depend de l'equipement : la fiche, les sacs, et nous.
local function Suivre()
    if UI.Vues then UI.Vues.Rafraichir() end
    if UI.Inventaires then UI.Inventaires.Actualiser() end
    MesOutils.Actualiser()
end

-- ===== Ce qui est porte, et ce qu'on peut en faire ===========================

-- Les outils portes, dans l'ordre de la fiche : les outils, puis la lanterne.
function MesOutils.Portes(entity)
    local out = {}
    if not entity then return out end
    for rang, id in ipairs(LCM.Objets.Ids(entity, "outil")) do
        local objet = LCM.Objets.Get(id)
        out[#out + 1] = { genre = "outil", cle = "outil:" .. rang .. ":" .. id, id = id, rang = rang,
            label = objet and objet.label or ("? " .. id), icone = LCM.Icone(objet and objet.icone),
            contenant = LCM.Contenants.Porte(entity, rang) ~= nil }
    end
    local lanterne = LCM.Lanterne and LCM.Lanterne.IdEquipe(entity)
    if lanterne then
        local def = LCM.Lanternes.Get(lanterne)
        out[#out + 1] = { genre = "lanterne", cle = "lanterne:" .. lanterne, id = lanterne,
            label = def and def.label or ("? " .. lanterne), icone = LCM.Icone(def and def.icone) }
    end
    return out
end

-- L'etat lisible d'un outil, pour sa bulle : « Eau, 60 % », « Allumée ».
local function Etat(entity, porte)
    if porte.genre == "lanterne" then
        local L = LCM.Lanterne
        if not L.CristalPose() then return "Sans cristal." end
        local max = L.ChargeMax()
        local part = max > 0 and string.format(" · %.0f %%", L.Charge() / max * 100) or ""
        return (L.Allumee() and "Allumée" or "Éteinte") .. part
    end
    if porte.contenant then
        local modele, x = LCM.Contenants.Porte(entity, porte.rang)
        return "Contenu : " .. LCM.Contenants.Texte(modele, x)
    end
    return nil
end

-- Les actions d'un outil porte : { cle, label, icone, faire }.
function MesOutils.Actions(entity, porte)
    local out = {}
    if porte.genre == "lanterne" then
        local allumee = LCM.Lanterne.Allumee()
        out[#out + 1] = { cle = allumee and "eteindre" or "allumer", label = allumee and "Éteindre" or "Allumer",
            faire = function() Refus(LCM.Lanterne.Basculer()) MesOutils.Actualiser() end }
        out[#out + 1] = { cle = "voir", label = "Voir", faire = function() Refus(UI.Lanterne.Basculer()) end }
        out[#out + 1] = { cle = "desequiper", label = "Déséquiper",
            faire = function() if Refus(LCM.Lanterne.RetirerLanterne()) then Suivre() end end }
        return out
    end
    if porte.contenant then
        out[#out + 1] = { cle = "boire", label = "Boire", faire = function()
            UI.Consommation.UtiliserContenantPorte(Moi(), porte.rang)
            Suivre()
        end }
        out[#out + 1] = { cle = "voir", label = "Voir", faire = function() MesOutils.VoirContenant(porte.rang) end }
    elseif porte.id == SCANNER then
        out[#out + 1] = { cle = "voir", label = "Voir", faire = function() Refus(UI.Scanner.Basculer()) end }
    end
    out[#out + 1] = { cle = "desequiper", label = "Déséquiper", faire = function()
        if Refus(LCM.Objets.Desequiper(Moi(), porte.id, porte.rang)) then Suivre() end
    end }
    return out
end

-- ===== Le bandeau ============================================================

-- Les actions d'un outil, deplies SOUS sa vignette (en `x0` du centre de
-- `f`) et reliees a elle par le jet pourpre. Partage avec les Raccourcis
-- (UI/Raccourcis.lua), ou un outil precis se sert de la meme facon.
-- `f.actions` et `f.jetActions` sont crees au premier appel, puis recycles.
function MesOutils.PoserActions(f, x0, actions)
    local R = UI.Radial
    f.actions = f.actions or {}
    f.jetActions = f.jetActions or R.CreerJet(f, f:GetFrameLevel())
    local cibles = {}
    for i, action in ipairs(actions) do
        local b = f.actions[i]
        if not b then
            -- La legende reste affichee : c'est le nom du geste.
            b = R.Vignette(f, ACTION, false, f:GetFrameLevel() + 4)
            b.disponible = true
            b:RegisterForClicks("LeftButtonUp")
            b:SetScript("OnClick", function(self) if self.action then self.action.faire() end end)
            f.actions[i] = b
        end
        b.action = action
        b.icone:SetTexture(ICONES[action.cle])
        b.legende:SetText(action.label)
        local x = x0 + (i - (#actions + 1) / 2) * PAS_ACTION
        b:ClearAllPoints()
        b:SetPoint("CENTER", f, "CENTER", x, -DESSOUS)
        cibles[i] = { x = x, y = -DESSOUS }
        R.Bulle(b, action.label, nil)
        b:Show()
    end
    for i = #actions + 1, #f.actions do f.actions[i]:Hide() end
    if #actions > 0 then R.Diriger(f.jetActions, x0, 0, cibles) else f.jetActions:Hide() end
    f.nombreActions = #actions
end

local function Construire()
    local R = UI.Radial
    local f = CreateFrame("Frame", "LCM_MesOutils", UIParent)
    MesOutils.frame = f
    -- Au-dessus du menu radial (MEDIUM), qu'il prolonge. Son CENTRE est celui
    -- du bouton Mes Outils : tout se place en decalage de ce point.
    f:SetFrameStrata("HIGH")
    f:SetSize(2 * (ECART_TETE + 9 * PAS), 2 * (DESSOUS + ACTION))
    f:EnableMouse(false)

    -- Le jet pourpre du retour vers les outils : sous les vignettes.
    f.jet = R.CreerJet(f, f:GetFrameLevel())

    local function Signe(b)
        b.glyphe = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        b.glyphe:SetPoint("CENTER", b, "CENTER", 0, 1)
        b.glyphe:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        return b
    end

    -- Le retour, a la place exacte du bouton du menu.
    f.tete = Signe(R.Vignette(f, UI.Radial.ACTION, true, f:GetFrameLevel() + 4))
    f.tete:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.tete.glyphe:SetText("<")
    f.tete.disponible = true
    f.tete:RegisterForClicks("LeftButtonUp")
    f.tete:SetScript("OnClick", function() f:Hide() end)
    R.Bulle(f.tete, "Mes Outils", "Clic : refermer.")

    f.outils = {}

    local function Outil(i)
        local b = f.outils[i]
        if b then return b end
        b = Signe(R.Vignette(f, UI.Radial.ACTION, true, f:GetFrameLevel() + 4))
        b:SetPoint("CENTER", f, "CENTER", ECART_TETE + (i - 1) * PAS, 0)
        b.disponible = true
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(self)
            if not self.porte then
                LCM.Alerte("aucun outil équipé : ça se passe dans Équipements › Outils.")
                return
            end
            f.choisi = f.choisi ~= self.porte.cle and self.porte.cle or nil
            f:Afficher()
        end)
        f.outils[i] = b
        return b
    end

    function f:Afficher()
        local moi = Moi()
        local portes = MesOutils.Portes(moi)
        local n = math.max(1, #portes)
        local choisi
        local cibles = {}
        for i = 1, n do
            local b = Outil(i)
            local porte = portes[i]
            b.porte = porte
            if porte then
                b.icone:SetTexture(porte.icone)
                b.icone:SetVertexColor(1, 1, 1)
                b.glyphe:SetText("")
            else
                -- Le rond vide garde le fond noir de la vignette, sans icone.
                b.icone:SetTexture(nil)
                b.glyphe:SetText("—")
            end
            b.legende:SetText(porte and porte.label or "")
            R.Bulle(b, porte and porte.label or "Aucun outil", function()
                if not b.porte then return "Rien n'est équipé dans Équipements › Outils." end
                local etat = Etat(Moi(), b.porte)
                return (etat and (etat .. "\n") or "") .. "Clic : ses actions."
            end)
            local actif = porte ~= nil and porte.cle == self.choisi
            R.Eclairer(b, actif, b.survole)
            if actif then choisi = b end
            cibles[i] = { x = ECART_TETE + (i - 1) * PAS, y = 0 }
            b:Show()
        end
        for i = n + 1, #self.outils do self.outils[i]:Hide() end
        R.Diriger(self.jet, 0, 0, cibles)
        -- Un choix qui n'est plus porte (desequipe ailleurs) s'oublie.
        if not choisi then self.choisi = nil end

        local x0 = 0
        for i = 1, n do if self.outils[i] == choisi then x0 = ECART_TETE + (i - 1) * PAS end end
        MesOutils.PoserActions(self, x0, choisi and MesOutils.Actions(moi, choisi.porte) or {})
    end

    -- Le bandeau prolonge SON bouton : si le radial se referme, ou si le
    -- bouton sert maintenant a une autre entree (ils sont recycles), il part.
    -- Il se relit aussi de lui-meme : un outil equipe ou retire depuis la
    -- fiche ne previent personne, et un bandeau qui montre l'ancien mentirait.
    -- Les runes des vignettes vivent comme celles du radial.
    local ecoule, temps = 0, 0
    f:SetScript("OnUpdate", function(self, dt)
        local a = self.ancre
        if a and not (a:IsVisible() and a.cible and a.cible.id == ID_MENU) then self:Hide() return end
        dt = tonumber(dt) or 0
        temps = temps + dt
        R.AnimerMagie(self.tete, temps)
        for _, b in ipairs(self.outils) do R.AnimerMagie(b, temps) end
        for _, b in ipairs(self.actions or {}) do R.AnimerMagie(b, temps) end
        ecoule = ecoule + dt
        if ecoule >= 0.5 then ecoule = 0 self:Afficher() end
    end)
    f:HookScript("OnShow", function(self)
        -- Le retour porte l'icone du bouton qu'il recouvre, eteinte sous la
        -- fleche : on voit d'ou l'on vient.
        local icone = self.ancre and self.ancre.icone and self.ancre.icone:GetTexture()
        self.tete.icone:SetTexture(icone)
        self.tete.icone:SetVertexColor(0.3, 0.3, 0.3)
        self:Afficher()
    end)
    LCM.Entities.EcouterSoi(function() MesOutils.Actualiser() end)
    f:Hide()
    return f
end

function MesOutils.Fenetre()
    if not MesOutils.frame then Construire() end
    return MesOutils.frame
end

function MesOutils.Actualiser()
    local f = MesOutils.frame
    if f and f:IsShown() then f:Afficher() end
    local v = MesOutils.contenant
    if v and v:IsShown() then v:Afficher() end
end

-- Le bouton du menu : ouvre le bandeau par-dessus lui, vers la droite. Le
-- retour le recouvre : c'est lui qui referme, le bouton n'est plus cliquable
-- tant que le bandeau est ouvert.
function MesOutils.Basculer()
    local f = MesOutils.Fenetre()
    if f:IsShown() then f:Hide() return f end
    local ancre = UI.Radial and UI.Radial.BoutonEntree(ID_MENU)
    f.ancre = ancre
    f.choisi = nil
    f:ClearAllPoints()
    if ancre then
        f:SetPoint("CENTER", ancre, "CENTER", 0, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:Show()
    return f
end

-- ===== « Voir » un contenant =================================================
-- Breve : ce qu'il tient, a combien, et combien d'usages cela fait.

local function ConstruireContenant()
    local L = 260
    local v = UI.Fenetre("contenant_outil", "Contenant", L, 10, { x = 200, y = 40 })
    MesOutils.contenant = v
    local c = v.contenu
    v.texte = UI.Texte(c, "", UI.C.texte)
    v.texte:SetPoint("TOP", c, "TOP", 0, -10)
    v.texte:SetWidth(L - 32)
    v.texte:SetJustifyH("CENTER")
    v.barre = UI.Barre(c, UI.C.accent, L - 32, 16)
    v.barre:SetPoint("TOP", v.texte, "BOTTOM", 0, -10)
    v.usages = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    v.usages:SetPoint("TOP", v.barre, "BOTTOM", 0, -8)
    v:SetHeight(v.insetHaut + 84 + v.insetBas)

    function v:Afficher()
        local moi = Moi()
        local modele, x = LCM.Contenants.Porte(moi, self.rang)
        -- Desequipe, ou remplace a ce rang par autre chose : plus rien a voir.
        if not modele or modele.id ~= self.id then self:Hide() return end
        self:Titre(modele.label)
        local contenu = x and x.contenu
        local element = contenu and LCM.Compendium.Resoudre(contenu.ref)
        local pourcent = LCM.Contenants.Pourcent(modele, x)
        self.texte:SetText(contenu and ("Contient : " .. (element and element.label or ("? " .. tostring(contenu.ref))))
            or "Vide.")
        self.barre:Regler(pourcent, 100)
        self.barre.label:SetText(pourcent .. " %")
        local n = LCM.Contenants.Usages(modele, x)
        self.usages:SetText(contenu and (n > 1 and (n .. " usages restants") or (n .. " usage restant")) or "")
    end
    v:HookScript("OnShow", function(self) self:Afficher() end)
    LCM.Entities.EcouterSoi(function() if v:IsShown() then v:Afficher() end end)
    v:Hide()
    return v
end

function MesOutils.VoirContenant(rang)
    local v = MesOutils.contenant or ConstruireContenant()
    local id = LCM.Objets.Ids(Moi(), "outil")[rang]
    if v:IsShown() and v.rang == rang and v.id == id then v:Hide() return v end
    v.rang, v.id = rang, id
    v:Show()
    v:Afficher()
    return v
end

LCM.WhenReady(function() UI.Menu.Lier(ID_MENU, MesOutils.Basculer) end)
