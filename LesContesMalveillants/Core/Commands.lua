-- Commandes « /lcm ». Une seule table : ajouter une commande, c'est ajouter une
-- ligne ici, et l'aide se met a jour toute seule.

local _, LCM = ...

local commandes = {}
local ordre = {}

-- Elles restent utilisables lorsqu'un autre morceau de l'interface en a
-- besoin, mais ce sont des commandes techniques ou de mise au point : elles
-- n'encombrent pas la liste courte presentee aux joueurs.
local cacheesJoueur = {
    combat = true,
    debug = true,
    etats = true,
    doc = true,
    switch = true,
    pousse = true,
    outils = true,
}

-- LCM.AddCommand("version", "Affiche la version", function(argument) end)
function LCM.AddCommand(nom, description, handler, masterOnly)
    nom = tostring(nom or ""):lower()
    if nom == "" or type(handler) ~= "function" then return end
    if not commandes[nom] then ordre[#ordre + 1] = nom end
    commandes[nom] = { description = description or "", handler = handler, masterOnly = masterOnly == true }
end

local function Aide()
    LCM.Info("Commandes disponibles :")
    for _, nom in ipairs(ordre) do
        local commande = commandes[nom]
        local master = LCM.IsMaster()
        if (not commande.masterOnly or master) and (master or not cacheesJoueur[nom]) then
            LCM.Info(string.format("   |cffffd36b/lcm %s|r  %s", nom, commande.description))
        end
    end
end

LCM.AddCommand("aide", "cette liste", Aide)

LCM.AddCommand("version", "version installee", function()
    LCM.Info(string.format("version %s — %s", tostring(LCM.version),
        LCM.IsMaster() and "|cffe8b451maitre du jeu|r" or "joueur"))
end)

LCM.AddCommand("debug", "active ou coupe les traces", function()
    LCM.EnsureDatabase()
    LCM.db.settings.debug = not LCM.db.settings.debug
    LCM.Info("traces : " .. (LCM.db.settings.debug and "actives" or "coupees"))
end)

SLASH_LCM1 = "/lcm"
SLASH_LCM2 = "/contes"
SlashCmdList.LCM = function(message)
    local texte = tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local nom, argument = texte:match("^(%S+)%s*(.*)$")
    nom = tostring(nom or ""):lower()
    if nom == "" then return Aide() end
    local commande = commandes[nom]
    if not commande then
        LCM.Alerte(string.format("commande inconnue : %s", nom))
        return Aide()
    end
    if commande.masterOnly and not LCM.IsMaster() then
        LCM.Alerte("cette commande est reservee au maitre du jeu.")
        return
    end
    commande.handler(argument or "")
end
