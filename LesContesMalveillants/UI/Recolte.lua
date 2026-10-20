-- Le bouton « Recolter » : il apparait quand on se tient sur un point de
-- recolte (Core/Recolte.lua) et disparait quand on s'en eloigne. Rien n'est
-- visible avant : le filon se trouve en marchant dessus.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Recolte = Ecran

local function Construire()
    local b = UI.Interaction("LCM_BoutonRecolte", "Récolter", "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\fenetres-recoltes.tga")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, bouton)
        -- Clic droit : le MJ regle ce que CE point donne (MJ/RecoltesUI.lua
        -- pose `Ecran.Regler`). Un joueur n'a rien a y faire.
        if bouton == "RightButton" then
            if Ecran.Regler then Ecran.Regler(self.pointId) end
            return
        end
        local ok, raison = LCM.Recolte.Tenter(self.pointId)
        if not ok and raison then LCM.Alerte(tostring(raison)) end
    end)
    b:Hide()
    Ecran.bouton = b
    return b
end

function Ecran.Actualiser(point)
    local b = Ecran.bouton or Construire()
    local definition = point and LCM.Recolte.definitions[point.def]
    if not definition then
        b.pointId = nil
        b:Hide()
        return
    end
    b.pointId = point.id
    -- Une ressource unique montre son icone ; un point multiple garde
    -- l'embleme de recolte, sans privilegier arbitrairement un de ses produits.
    local ressources = LCM.Recolte.RessourcesDuPoint(point, definition)
    local ressource = #ressources == 1 and LCM.Compendium.Resoudre(ressources[1].entree)
    b.icone:SetTexture(ressource and ressource.icone and LCM.Icone(ressource.icone)
        or "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\fenetres-recoltes.tga")
    -- Un point encore tout eteint ne se voit que du MJ : il le dit.
    b.nom:SetText(point.vide and (definition.label .. " — à régler (clic droit)") or definition.label)
    b:Show()
end

LCM.Recolte.onProche = function(point) Ecran.Actualiser(point) end
