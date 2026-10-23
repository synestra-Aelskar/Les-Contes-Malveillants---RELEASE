-- La feuille des Contes Malveillants.
--
-- C'est ici, et nulle part ailleurs, que vit la structure d'une fiche. Les
-- identifiants ne bougent jamais une fois publies : ce sont eux que referencent
-- les formules, les actions et les sauvegardes existantes.
--
-- Trois onglets : General, Statistiques, Traits.

local _, LCM = ...
local Schema = LCM.Schema

Schema.AddTab({
    id = "general",
    label = "Général",
    sections = {
        {
            id = "vitalite", label = "Vitalité",
            fields = {
                -- Le maximum vient d'une formule ; sa repartition sur les
                -- parties du corps vient de la morphologie de la race.
                -- Les PV COURANTS ne sont pas un champ : ils sont la somme des
                -- parties (LCM.Body.Totals).
                -- Template : 2 + 1,5 x niveau + 3 x vitalite
                --   + constitution totale x (2 + constitution investie x 0,25).
                -- La constitution compte deux fois : elle multiplie, et sa part
                -- investie fait grandir le multiplicateur.
                { id = "pv_max", kind = "calc", label = "Points de vie (max)", masque = true,
                  formula = function(entity)
                      local e = LCM.Equilibrage.pv
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      local investie = v("constitution")
                      local totale = LCM.Formules.Primaire(entity, "constitution")
                      return math.floor(e.base + e.parNiveau * v("niveau") + e.parVitalite * v("sec_vitalite")
                          + totale * (e.constitution.base + investie * e.constitution.parConstitution))
                  end },
                { id = "corps",    kind = "body", label = "Parties du corps",
                  note = "Points de vie et blessures, zone par zone." },
                -- Fatigue (template) : 15 + 2 x niveau + esprit + 2 x constitution
                --   + Endurance totale / 1 + 3 x (pts secondaires) + bonus portes.
                { id = "fatigue",  kind = "gauge", label = "Fatigue",
                  note = "Réserve d'énergie du personnage. À mesure qu'elle baisse, la fatigue impose des malus croissants. À zéro, le personnage est totalement épuisé et subit de lourds malus.",
                  maxFormula = function(entity)
                      local e = LCM.Equilibrage.fatigue
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      return math.floor(e.base + e.parNiveau * v("niveau") + e.parEsprit * v("esprit")
                          + e.parConstitution * v("constitution")
                          + LCM.Formules.Expertise(entity, "endurance") / e.diviseurEndurance
                          + e.parSecondaire * v("sec_fatigue") + LCM.Effets.Bonus(entity, "fatigue"))
                  end },
                -- « Boucliers » dans le template : 0 / 1000 au depart.
                { id = "armure",   kind = "gauge", label = "Boucliers", max = 1000, default = 0,
                  note = "Protection temporaire. Part de zéro ; R la remet à zéro." },
                -- Ecart voulu (Equilibrage.armure) : l'armure des pieces
                -- portees, calculee depuis l'equipement. L'identifiant
                -- « armure » etant celui des Boucliers depuis la premiere
                -- publication, celle-ci s'appelle « armure_portee ».
                { id = "armure_portee", kind = "gauge", label = "Armure", default = 0,
                  lire = function(entity) return LCM.Objets.Protection(entity) end,
                  ecrire = function(entity, encaisse) return LCM.Objets.PorterProtection(entity, encaisse) end,
                  note = "Dégâts encaissés par les armures portées, sur leur total. Chaque pièce garde son usure ; R les répare." },
            },
        },
        {
            -- Sante › Intangible dans le template : deux jauges sur 100.
            id = "existence", label = "Existence",
            fields = {
                { id = "existence_esprit", kind = "gauge", label = "Esprit", max = 100,
                  note = "Définit l'état actuel de votre esprit. Plus cet état est bas, plus votre santé mentale est atteinte." },
                { id = "existence_ame", kind = "gauge", label = "Âme", max = 100,
                  note = "L'état actuel de votre âme, le poids de votre existence dans l'univers. Une âme fragile peine à se maintenir ; à zéro, le personnage disparaît." },
            },
        },
        {
            label = "Identité",
            fields = {
                { id = "race",         kind = "text", label = "Race",
                  note = "Origine du personnage. Elle détermine notamment sa morphologie et peut apporter des caractéristiques." },
                { id = "portrait",     kind = "text", label = "Portrait",
                  note = "Identifiant de l'artwork livré avec l'addon ; vide = celui du personnage." },
                { id = "morphologie",  kind = "text", label = "Morphologie imposée", mjSeulement = true,
                  note = "Pour un PNJ sans race : prime sur celle de la race." },
                { id = "niveau", kind = "stat", label = "Niveau",
                  default = LCM.Equilibrage.creation.niveauDepart,
                  note = "Progression du personnage. Le niveau intervient dans plusieurs maximums et calculs de la fiche." },
                { id = "age",   kind = "stat", label = "Âge",
                  note = "Âge du personnage, en années." },
                { id = "sexe",  kind = "text", label = "Sexe",
                  note = "Sexe indiqué dans l'identité du personnage." },
                { id = "poids", kind = "stat", label = "Poids", note = "En kilogrammes." },
            },
        },
    },
})

-- Les points secondaires : un champ par pool, engendre depuis l'equilibrage.
-- Ajouter un pool se fait la-bas, pas ici.
local champsSecondaires = {}
for _, pool in ipairs(LCM.Equilibrage.secondaires) do
    champsSecondaires[#champsSecondaires + 1] = {
        id = pool.id, kind = "stat", label = pool.label, default = 0,
        note = string.format("Points secondaires investis (%d point%s l'unite).",
            pool.cout, pool.cout > 1 and "s" or ""),
    }
end

-- Une distance de saut : Force / a + Adresse / b (template), ARRONDIE A
-- L'INFERIEUR. « 3.33 m » n'est pas une distance qu'on annonce a une table :
-- on saute trois metres, et la fraction ne sert a rien (4 octobre 2026).
function LCM.Saut(entity, sens)
    local e = LCM.Equilibrage.sauts[sens]
    return math.floor(LCM.Formules.Primaire(entity, "force") / e.diviseurForce
        + LCM.Formules.Primaire(entity, "adresse") / e.diviseurAdresse)
end

-- Un mode de deplacement : base + ce que son expertise apporte + points
-- secondaires + bonus portes.
--
-- L'expertise comptait pour ses points INVESTIS, un yard chacun, comme le
-- template. Elle compte desormais pour sa valeur TOTALE, un demi-yard par
-- point (decision du 11 octobre 2026) : une race qui court vite doit se voir
-- ici. Quelle expertise porte quel mode est dit dans
-- `Equilibrage.effetsExpertises`, pas ici — le vol n'en a aucune, et il n'y a
-- rien a passer pour le dire.
--
-- Le tout est arrondi A L'INFERIEUR : un demi-yard ne s'annonce pas a une
-- table, comme pour les sauts juste au-dessus.
function LCM.Deplacement(entity, mode)
    local e = LCM.Equilibrage.deplacement
    local v = function(id) return (id and tonumber(LCM.Entities.Get_Value(entity, id))) or 0 end
    local expertise = (LCM.Expertises and LCM.Expertises.BonusDeplacement(entity, mode)) or 0
    return math.floor((e[mode] or 0) + expertise + e.parSecondaire * v("sec_deplacement")
        + LCM.Effets.Bonus(entity, "depl_" .. mode))
end

Schema.AddTab({
    id = "statistiques",
    label = "Statistiques",
    sections = {
        {
            -- Les deux primaires qui se LANCENT (template : « 0-15 ... Rand »)
            -- sont a part : leur ligne porte un de et un bouton, les quatre
            -- autres se lisent. Melangees, on ne voyait plus lesquelles se
            -- jouent.
            label = "Habilités",
            fields = {
                { id = "adresse",      kind = "roll", label = "Adresse",      default = 0,
                  dice = { min = 0, max = 15 },
                  note = "Mesure la coordination physique nécessaire à certaines actions, notamment pour toucher un adversaire avec une attaque.\n\n0 - 15 [+ Mod.]" },
                { id = "esprit",       kind = "roll", label = "Esprit",       default = 0,
                  dice = { min = 0, max = 15 },
                  note = "Mesure la capacité à supporter des images intenses et à manipuler des sortilèges. En attaque, aide à mieux contrôler ses sorts pour toucher leur cible.\n\n0 - 15 [+ Mod.]" },
            },
        },
        {
            label = "Statistiques",
            fields = {
                { id = "force",        kind = "stat", label = "Force",        default = 0,
                  note = "Mesure votre puissance physique. Elle influe notamment sur le poids que vous pouvez soulever, vos capacités athlétiques, vos distances de saut et la portée de vos lancers d'objets." },
                { id = "mystique",     kind = "stat", label = "Mystique",     default = 0,
                  note = "Mesure votre affinité avec les magies élémentaire et cosmique. Elle détermine la puissance de vos sortilèges, quelle que soit leur école, et affine vos observations dans ces deux domaines." },
                { id = "perception",   kind = "stat", label = "Perception",   default = 0,
                  note = "Permet d'analyser son environnement et de repérer les failles dans l'armure d'autrui. Aide aussi à détecter l'hostilité adverse et à y réagir plus vite, ce qui améliore l'initiative." },
                { id = "constitution", kind = "stat", label = "Constitution", default = 0,
                  note = "Mesure la capacité naturelle à survivre. Elle détermine la résistance aux coups, aux poisons et aux autres états qui affectent le corps, ainsi que les points de vie généraux." },
            },
        },
        {
            label = "Points secondaires",
            fields = champsSecondaires,
        },
        {
            -- Fiche › Facultes dans le template.
            id = "facultes", label = "Facultés",
            fields = {
                { id = "poids_soulevable", kind = "calc", label = "Poids soulevable (en kg)",
                  note = "Charge que le personnage peut soulever, calculée à partir de sa Force totale.",
                  formula = function(entity)
                      local e = LCM.Equilibrage.quotidien
                      return e.poidsBase + e.poidsParForce * LCM.Formules.Primaire(entity, "force")
                  end },
                { id = "saut_horizontal", kind = "calc", label = "Distance de saut horizontal",
                  note = "Distance de saut vers l'avant, calculée à partir de la Force et de l'Adresse totales.",
                  formula = function(entity) return LCM.Saut(entity, "horizontal") end },
                { id = "saut_vertical", kind = "calc", label = "Distance de saut vertical",
                  note = "Hauteur de saut, calculée à partir de la Force et de l'Adresse totales.",
                  formula = function(entity) return LCM.Saut(entity, "vertical") end },
            },
        },
        {
            label = "Caractéristiques",
            fields = {
                -- Initiative (template) : pts secondaires + niveau / 2
                --   + esprit / 2 + perception / 2. Les bonus portes s'ajoutent
                --   au jet (Core/Roll.lua), pas ici.
                { id = "initiative", kind = "roll", label = "Initiative", dice = { min = 0, max = 10 },
                  note = "Ordre d'action calculé avec le niveau, l'Esprit, la Perception et les points secondaires ; jet de 0 à 10.",
                  valueFormula = function(entity)
                      local e = LCM.Equilibrage.initiative
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      return math.floor(v("sec_initiative") + v("niveau") / e.diviseurNiveau
                          + LCM.Formules.Primaire(entity, "esprit") / e.diviseurEsprit
                          + LCM.Formules.Primaire(entity, "perception") / e.diviseurPerception)
                  end },
                -- Points d'action : 4 + 1 tous les 5 niveaux + pts secondaires
                --   + bonus portes.
                { id = "pa",         kind = "gauge", label = "PA",
                  note = "Les points d'action servent surtout lors des combats au tour par tour. Ils déterminent les actions que vous pouvez accomplir pendant votre tour.",
                  maxFormula = function(entity)
                      local e = LCM.Equilibrage.pa
                      local v = tonumber(LCM.Entities.Get_Value(entity, "sec_pa")) or 0
                      local niveau = tonumber(LCM.Entities.Get_Value(entity, "niveau")) or 1
                      local paliers = math.floor(niveau / e.niveauxParPA)
                      return math.floor(e.base + paliers + v + LCM.Effets.Bonus(entity, "pa"))
                  end },
                -- Deplacement : base + ce que la Course ou la Nage apporte
                --   + pts secondaires x 1 + bonus portes (compris dans la formule :
                --   un objet peut viser ces champs, d'ou `recoitBonus`).
                { id = "depl_terrestre", kind = "calc", label = "Terrestre", recoitBonus = true,
                  note = "Distance de déplacement à pied. Elle tient compte de la Course, des points secondaires et des bonus portés.",
                  formula = function(entity) return LCM.Deplacement(entity, "terrestre") end },
                { id = "depl_nage",      kind = "calc", label = "Nage",      recoitBonus = true,
                  note = "Distance de déplacement dans l'eau. Elle tient compte de la Nage, des points secondaires et des bonus portés.",
                  formula = function(entity) return LCM.Deplacement(entity, "nage") end },
                -- Le vol : base zero dans le template, il ne vient donc que des
                -- points secondaires et de ce qu'on porte.
                { id = "depl_vol",       kind = "calc", label = "Vol",       recoitBonus = true,
                  note = "Distance de déplacement en vol. Elle vient des points secondaires et des bonus portés.",
                  formula = function(entity) return LCM.Deplacement(entity, "vol") end },
            },
        },
    },
})

Schema.AddTab({
    id = "traits",
    label = "Traits",
    sections = {
        {
            label = "Traits",
            fields = {
                -- La liste des traits portes : un champ a part entiere, pour
                -- que la fiche la dessine comme le reste, mais sa donnee vit
                -- dans `entity.traits` (voir Core/Traits.lua).
                { id = "traits_portes", kind = "traits", label = "Traits portés",
                  note = "Traits du personnage. Leurs effets et leur coût figurent sur leurs cartes." },
                { id = "traits_notes", kind = "text", label = "Notes",
                  note = "Espace de notes lié aux traits du personnage." },
            },
        },
    },
})
