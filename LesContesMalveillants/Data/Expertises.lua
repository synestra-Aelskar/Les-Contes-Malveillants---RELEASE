-- Expertises : trois domaines, 26 competences.
--
-- Chacune se lance (des 0-15) et peut recevoir un bonus de trait. Les
-- identifiants sont sans accent et definitifs ; seuls les libelles s'affichent.
--
-- Releve de la feuille « Expertises » de Necronicon.

local _, LCM = ...
local Schema = LCM.Schema

local function expertise(id, label)
    return { id = id, kind = "roll", label = label, default = 0, dice = { min = 0, max = 15 },
        jetExpertise = true }
end

Schema.AddTab({
    id = "expertises",
    label = "Expertises",
    sections = {
        {
            id = "observations", label = "Observations",
            fields = {
                expertise("vue",           "Vue"),
                expertise("odorat_gout",   "Odorat-Goût"),
                expertise("ouie",          "Ouïe"),
                expertise("toucher",       "Toucher"),
                expertise("investigation", "Investigation"),
                expertise("elementaire",   "Élémentaire"),
                expertise("cosmique",      "Cosmique"),
                expertise("pistage",       "Pistage"),
                expertise("communication", "Communication"),
            },
        },
        {
            id = "athletisme", label = "Athlétisme",
            fields = {
                expertise("puissance",  "Puissance"),
                expertise("projection", "Projection"),
                expertise("prise",      "Prise"),
                expertise("equilibre",  "Équilibre"),
                expertise("acrobaties", "Acrobaties"),
                expertise("escalade",   "Escalade"),
                expertise("resistance", "Résistance"),
                expertise("endurance",  "Endurance"),
                expertise("course",     "Course"),
                expertise("nage",       "Nage"),
            },
        },
        {
            id = "filouterie", label = "Filouterie",
            fields = {
                expertise("discretion",   "Discrétion"),
                expertise("deguisement",  "Déguisement"),
                expertise("vol_a_la_tire", "Vol à la tire"),
                expertise("crochetage",   "Crochetage"),
                expertise("escamotage",   "Escamotage"),
                expertise("evasion",      "Évasion"),
                expertise("sabotage",     "Sabotage"),
            },
        },
    },
})
