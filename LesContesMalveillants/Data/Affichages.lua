-- Catalogues partages MJ/joueur. Seuls les identifiants voyagent et se sauvegardent.
local _, LCM = ...
local RACINE = "Interface\\AddOns\\LesContesMalveillants\\ressources\\affichages\\"
local POLICES = "Interface\\AddOns\\LesContesMalveillants\\ressources\\bannieres\\polices\\"
LCM.AffichagesSupports = {}
for _, s in ipairs({
    { "bois", "Bois" }, { "pierre", "Pierre" }, { "numerique", "Numérique" },
    { "guilde", "Guilde" }, { "marchand", "Marchand" }, { "taverne", "Taverne" },
}) do
    LCM.AffichagesSupports[#LCM.AffichagesSupports + 1] = {
        id = s[1], label = s[2], texture = RACINE .. "panneau-" .. s[1] .. ".blp",
        rapport = 1.5, zone = { 0.10, 0.14, 0.90, 0.88 },
    }
end
LCM.AffichagesThemes = {}
for _, s in ipairs({
    { "papier", "Papier" }, { "parchemin", "Parchemin" }, { "missive", "Missive" },
    { "numerique", "Numérique" }, { "guilde", "Guilde" }, { "marchand", "Marchand" },
}) do
    local ecran = s[1] == "numerique"
    LCM.AffichagesThemes[#LCM.AffichagesThemes + 1] = {
        id = s[1], label = s[2], texture = RACINE .. "affiche-" .. s[1] .. ".blp",
        encre = ecran and { 0.70, 0.94, 1 } or { 0.18, 0.12, 0.08 },
        lien = ecran and { 0.30, 0.85, 1 } or { 0.42, 0.24, 0.06 },
        police = ecran and "numerique" or "classique",
    }
end
LCM.AffichagesPolices = {
    { id = "classique", label = "Classique", chemin = POLICES .. "Caudex-Regular.ttf" },
    { id = "calligraphie", label = "Calligraphie — élégante", chemin = RACINE .. "polices\\GreatVibes-Regular.ttf", facteur = 1.18 },
    { id = "medievale", label = "Calligraphie — médiévale", chemin = POLICES .. "Almendra-Regular.ttf" },
    { id = "gothique", label = "Calligraphie — gothique", chemin = POLICES .. "PirataOne-Regular.ttf" },
    { id = "machine", label = "Machine à écrire", chemin = RACINE .. "polices\\SpecialElite-Regular.ttf" },
    { id = "numerique", label = "Numérique — futuriste", chemin = POLICES .. "Rajdhani-Regular.ttf", facteur = 1.08 },
}
