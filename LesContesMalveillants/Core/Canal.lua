-- Routage des resultats de jets.
-- Par defaut : raid, puis groupe, puis emote quand le joueur est seul.

local _, LCM = ...

local Canal = {}
LCM.Canal = Canal

Canal.LISTE = {
    { id = "auto",  label = "Automatique (Raid, Groupe, Émote)", lettre = "A", couleur = { 1.00, 1.00, 1.00 } },
    { id = "local", label = "Local",  lettre = "L", couleur = { 1.00, 1.00, 1.00 } },
    { id = "emote", label = "Emote",  type = "EMOTE", lettre = "E", couleur = { 0.98, 0.86, 0.30 } },
    { id = "party", label = "Groupe", type = "PARTY", lettre = "G", couleur = { 0.38, 0.62, 0.98 } },
    { id = "raid",  label = "Raid",   type = "RAID",  lettre = "R", couleur = { 0.98, 0.60, 0.20 } },
}

function Canal.Get(id)
    for _, canal in ipairs(Canal.LISTE) do
        if canal.id == tostring(id or "") then return canal end
    end
    return Canal.LISTE[1]
end

-- Une ancienne sauvegarde sans choix utilisait Local par defaut. Elle adopte
-- maintenant le routage automatique ; Local reste disponible explicitement.
function Canal.Choix()
    LCM.EnsureDatabase()
    local id = LCM.db.settings and LCM.db.settings.canalJets
    return id and Canal.Get(id) or Canal.Get("auto")
end

function Canal.Choisir(id)
    local canal = Canal.Get(id)
    LCM.EnsureDatabase()
    LCM.db.settings.canalJets = canal.id ~= "auto" and canal.id or nil
    if Canal.onChange then Canal.onChange(canal) end
    return canal
end

local function DansRaid()
    return IsInRaid and IsInRaid() == true
end

local function DansGroupe()
    return IsInGroup and IsInGroup() == true
end

-- Canal effectivement utilise, avec repli garanti pour les choix Raid/Groupe.
function Canal.Actuel()
    local choix = Canal.Choix()
    if choix.id == "auto" then
        if DansRaid() then return Canal.Get("raid") end
        if DansGroupe() then return Canal.Get("party") end
        return Canal.Get("emote")
    end
    if choix.id == "raid" and not DansRaid() then
        if DansGroupe() then return Canal.Get("party") end
        return Canal.Get("emote")
    end
    if choix.id == "party" and not DansGroupe() then return Canal.Get("emote") end
    return choix
end

function Canal.Disponible(canal)
    local type_ = canal and canal.type
    if type_ == "RAID" then return DansRaid() end
    if type_ == "PARTY" then return DansGroupe() end
    return true
end

-- Envoie une ligne la ou il faut. Retourne le canal effectivement utilise.
function Canal.Dire(texte)
    local canal = Canal.Actuel()
    if canal.id == "local" then
        LCM.Info(texte)
        return canal
    end
    if SendChatMessage then
        SendChatMessage(LCM.SansCouleur(texte), canal.type)
    else
        LCM.Info(texte)
    end
    return canal
end

function LCM.SansCouleur(texte)
    return (tostring(texte or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
