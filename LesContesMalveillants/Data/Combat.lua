-- Les statistiques de combat.
--
-- Releve du template (colonnes du calculateur des objets et dossiers du
-- recapitulatif « Statistiques ») : ce sont des modificateurs que portent les
-- objets, les traits et les etats, et que liront les actions (attaque,
-- bouclier, soin, buff...). Aucun n'est investi a la creation : ils partent
-- de zero et ne bougent que par ce que le personnage porte.
--
-- Identifiants sans accents, definitifs ; libelles tels que le template.

local _, LCM = ...
local Schema = LCM.Schema

local function stat(id, label)
    return { id = id, kind = "stat", label = label, default = 0 }
end

Schema.AddTab({
    id = "combat",
    label = "Combat",
    sections = {
        { id = "attaques_defense", label = "Attaques & Défense", fields = {
            stat("force_attaque", "Force"), stat("mystique_attaque", "Mystique"),
            stat("perception_attaque", "Perception"), stat("defense_constitution", "Défense"),
        } },
        { id = "bouclier_soin", label = "Bouclier et Soin", fields = {
            stat("force_bouclier", "Force (bouclier)"), stat("mystique_bouclier", "Mystique (bouclier)"),
            stat("constitution_bouclier", "Constitution (bouclier)"),
            stat("mystique_soin", "Mystique (soin)"), stat("constitution_soin", "Constitution (soin)"),
        } },
        { id = "buff", label = "Buff", fields = {
            stat("force_buff", "Force"), stat("mystique_buff", "Mystique"), stat("perception_buff", "Perception"),
            stat("constitution_buff", "Constitution"), stat("duree_buff", "Durée"), stat("puissance_buff", "Puissance"),
        } },
        { id = "perce_armure", label = "Perce-Armure", fields = {
            stat("force_perce_armure", "Force"), stat("mystique_perce_armure", "Mystique"),
            stat("perception_perce_armure", "Perception"),
        } },
        { id = "brise_armure", label = "Brise-Armure", fields = {
            stat("force_brise_armure", "Force"), stat("mystique_brise_armure", "Mystique"),
            stat("perception_brise_armure", "Perception"),
        } },
        { id = "provocation", label = "Provocation", fields = {
            stat("force_provocation", "Force"), stat("constitution_provocation", "Constitution"),
            stat("esprit_provocation", "Esprit"), stat("mystique_provocation", "Mystique"),
        } },
        { id = "intimidation", label = "Intimidation", fields = {
            stat("force_intimidation", "Force"), stat("constitution_intimidation", "Constitution"),
            stat("esprit_intimidation", "Esprit"), stat("mystique_intimidation", "Mystique"),
        } },
        { id = "saignement", label = "Saignement", fields = {
            stat("force_saignement", "Force"), stat("mystique_saignement", "Mystique"),
            stat("perception_saignement", "Perception"),
        } },
        { id = "empoisonnement", label = "Empoisonnement", fields = {
            stat("mystique_empoisonnement", "Mystique"), stat("perception_empoisonnement", "Perception"),
            stat("constitution_empoisonnement", "Constitution"),
        } },
        { id = "debuff", label = "Debuff", fields = {
            stat("force_debuff", "Force"), stat("mystique_debuff", "Mystique"), stat("perception_debuff", "Perception"),
            stat("constitution_debuff", "Constitution"), stat("duree_debuff", "Durée"), stat("puissance_debuff", "Puissance"),
        } },
    },
})
