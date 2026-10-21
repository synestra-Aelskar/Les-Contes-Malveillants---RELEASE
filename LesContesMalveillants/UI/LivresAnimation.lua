-- Atlas BLP precalcules, selon le journal de quete Omega_Hub.
-- Une texture persistante par planche ; aucun maillage ni glyphe deforme.
local _, LCM = ...
local A = {}
LCM.UI.LivresAnimation = A
A.ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\livres\\"
A.Sequences = { opening = { images = 24, duree = .70 }, turning = { images = 16, duree = .45 },
    note = { images = 16, duree = .45 } }

function A.Creer(parent)
    local m = CreateFrame("Frame", nil, parent)
    m:SetAllPoints(parent)
    m:SetFrameLevel(parent:GetFrameLevel() + 20)
    m:EnableMouse(true)
    m.planches = {}
    m.precharge = CreateFrame("Frame", nil, UIParent)
    m.precharge:SetSize(2, 2)
    m.precharge:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    m.precharge:SetFrameStrata("TOOLTIP")
    m.precharge:EnableMouse(false)
    m.precharge.images = {}
    m.precharge:Hide()
    m:Hide()
    return m
end

function A.Preparer(m, modele, note)
    A.Arreter(m)
    -- Ne garder que les dix atlas du modele utilise (quatre pour une note).
    local cle = note and "note" or modele
    if m.cle == cle then return end
    m.cle = cle
    local warm = m.precharge
    warm:SetScript("OnUpdate", nil)
    for _, image in ipairs(warm.images) do image:Hide(); image:SetTexture(nil) end
    warm.ressources, warm.temps = {}, 0
    for _, image in ipairs(m.planches) do image:Hide(); image:SetTexture(nil) end
    m.sequences = {}
    local rang = 0
    for _, nom in ipairs(note and { "note" } or { "opening", "turning" }) do
        local sequence = {}
        m.sequences[nom] = sequence
        for i = 1, A.Sequences[nom].images / 4 do
            rang = rang + 1
            local image = m.planches[rang]
            if not image then
                image = m:CreateTexture(nil, "ARTWORK")
                image:SetAllPoints(m)
                m.planches[rang] = image
            end
            local chemin = A.ART .. (note and "chronique" or modele) .. "\\" .. nom .. "-" .. i .. ".blp"
            image:SetTexture(chemin)
            image:Hide()
            sequence[i] = image
            local petite = warm.images[rang]
            if not petite then
                petite = warm:CreateTexture(nil, "ARTWORK")
                petite:SetAllPoints(warm)
                petite:SetAlpha(.02)
                warm.images[rang] = petite
            end
            -- Afficher toute la planche sur trois images prepare aussi le GPU.
            petite:SetTexture(chemin)
            petite:Hide()
            warm.ressources[#warm.ressources + 1] = { image = petite, sequence = nom, poses = 0 }
        end
    end
    warm:Show()
    warm:SetScript("OnUpdate", function(self, dt)
        self.temps = self.temps + dt
        local ressource
        for _, r in ipairs(self.ressources) do
            if not r.pret and (not ressource or r.sequence == m.priorite) then
                ressource = r
                if r.sequence == m.priorite then break end
            end
        end
        if not ressource or self.temps > 5 then
            for _, image in ipairs(self.images) do image:Hide() end
            self:SetScript("OnUpdate", nil); self:Hide(); return
        end
        local image = ressource.image
        image:Show()
        if not image.IsObjectLoaded or image:IsObjectLoaded() then
            ressource.poses = ressource.poses + 1
            if ressource.poses >= 3 then ressource.pret = true; image:Hide() end
        end
    end)
end

function A.Pret(m, sequence)
    m.priorite = sequence
    for _, ressource in ipairs(m.precharge.ressources) do
        if ressource.sequence == sequence and not ressource.pret then return false end
    end
    for _, image in ipairs(m.sequences[sequence]) do
        if image.IsObjectLoaded and not image:IsObjectLoaded() then return false end
    end
    return true
end

function A.Dessiner(m, sequence, index, miroir)
    local image = m.sequences[sequence][math.floor(index / 4) + 1]
    if image.IsObjectLoaded and not image:IsObjectLoaded() then return false end
    if m.image ~= image then
        if m.image then m.image:Hide() end
        m.image = image
        image:Show()
    end
    local tuile = index % 4
    local x, y = tuile % 2, math.floor(tuile / 2)
    local u0, u1 = x / 2, (x + 1) / 2
    image:SetTexCoord(miroir and u1 or u0, miroir and u0 or u1, y / 2, (y + 1) / 2)
    m.index, m.sequence = index, sequence
    return true
end

function A.Arreter(m)
    m:Hide()
    if m.image then m.image:Hide() end
    m.image = nil
end
