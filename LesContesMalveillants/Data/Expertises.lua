-- Expertises : trois domaines, 26 competences.
--
-- Chacune se lance (des 0-15) et peut recevoir un bonus de trait. Les
-- identifiants sont sans accent et definitifs ; seuls les libelles s'affichent.
--
-- Releve de la feuille « Expertises » de Necronicon.

local _, LCM = ...
local Schema = LCM.Schema

local AIDE = {
    vue = "Repérer et distinguer ce qui est visible, même à distance ou dans une scène chargée.",
    odorat_gout = "Reconnaître une odeur ou une saveur et remarquer ce qu'elle révèle.",
    ouie = "Percevoir et identifier les sons autour de soi.",
    toucher = "Reconnaître une forme, une matière ou un détail par le contact.",
    investigation = "Examiner des indices et relier les détails d'une scène.",
    elementaire = "Observer et interpréter les phénomènes élémentaires.",
    cosmique = "Observer et interpréter les phénomènes cosmiques.",
    pistage = "Suivre des traces et reconstituer un passage.",
    communication = "Faire passer un message et comprendre celui d'autrui.",
    puissance = "Déployer sa force dans un effort athlétique.",
    projection = "Projeter une cible ou un objet par un mouvement du corps.",
    prise = "Saisir, maintenir ou dégager une prise.",
    equilibre = "Garder son appui sur une surface instable ou étroite.",
    acrobaties = "Exécuter un mouvement du corps qui demande agilité et coordination.",
    escalade = "Grimper et conserver ses prises pendant l'ascension.",
    resistance = "Tenir face à un effort ou une contrainte physique.",
    endurance = "Soutenir un effort dans la durée.",
    course = "Se déplacer rapidement à pied.",
    nage = "Se déplacer et agir dans l'eau.",
    discretion = "Agir ou se déplacer sans attirer l'attention.",
    deguisement = "Modifier son apparence pour passer pour quelqu'un d'autre.",
    vol_a_la_tire = "Subtiliser un objet porté par une autre personne.",
    crochetage = "Manipuler une serrure ou un mécanisme de fermeture.",
    escamotage = "Dissimuler ou déplacer un petit objet à la vue d'autrui.",
    evasion = "Se libérer d'une entrave ou s'échapper d'une prise.",
    sabotage = "Altérer discrètement un objet ou un mécanisme.",
}

local function expertise(id, label)
    return { id = id, kind = "roll", label = label, default = 0, dice = { min = 0, max = 15 },
        jetExpertise = true, note = AIDE[id] }
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
