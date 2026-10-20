-- Les icones de la fiche.
--
-- Elles ne sont pas inventees : chaque ligne de la fiche du template Necronicon
-- (« Template Fiche LVL 5 - Contes Malveillants V2 ») porte son icone, et ce
-- sont celles-la que les joueurs reconnaissent. Les chemins ci-dessous ont ete
-- releves dans la sauvegarde du template, entree par entree :
--
--   Statistiques  : window_custom_1 / onglet STATISTIQUES
--   Carateristiques : le conteneur « Statistiques » de ce meme onglet, cellule
--                   par cellule — l'icone retenue est celle de l'ENTREE posee
--                   dans la cellule, pas celle de la cellule : c'est ce que
--                   Necronicon affiche (Inventory.lua : entry.icon =
--                   ficheEntry.icon or entry.icon), et les deux divergent pour
--                   Force et Esprit, ou l'icone de cellule est restee celle du
--                   jour de sa creation.
--   Corps         : window_custom_12 / onglet Physique (voir Core/Body.lua)
--   Existence     : window_custom_12 / onglet Intangible
--
-- Deux icones n'existent pas dans le template, parce que les lignes n'y
-- existent pas : le Vol (le template ne compte que Terrestre et Nage) et les
-- zones Aile et Queue (le template est humanoide). Celles-la viennent des
-- ressources de la campagne, et sont signalees sur place.
--
-- `LCM.IconeCampagne("force")` rend le chemin d'une icone de ressource de
-- l'addon. Un nom inconnu renvoie nil, et la ligne s'affiche sans icone plutot
-- qu'avec un carre vert.

local _, LCM = ...

local DOSSIER = "Interface\\AddOns\\LesContesMalveillants\\ressources\\icones\\"
local ICONE = "Interface\\ICONS\\"

-- Ce qui existe dans le dossier des ressources. Declare pour qu'une faute de
-- frappe se voie : on ne devine pas un nom de fichier. Les noms accentues ont
-- ete corriges a la copie (« défense » devient « defense ») — un chemin de
-- texture accentue ne se charge pas partout de la meme facon.
local DISPONIBLES = {
    "Etat", "armes", "camp", "competences", "constitution", "defense",
    "deplacement", "divins", "energie", "esprit", "fiche", "force", "grimoire",
    "magie", "marche", "mecanique", "meteo", "nage", "parametres", "perception",
    "portee", "sacs", "savoirs", "temperature", "trait", "vitalite", "vol",
}

local connues = {}
for _, nom in ipairs(DISPONIBLES) do connues[nom] = DOSSIER .. nom .. ".blp" end

function LCM.IconeCampagne(nom)
    return connues[tostring(nom or "")]
end

-- Tous les chemins des icones de la campagne, dans l'ordre des noms : le
-- selecteur d'icones les propose avant celles du jeu.
-- Icones originales des couronnes, egalement disponibles pour les objets.
local ICONES_COURONNES = {
    "actions-animation.tga",
    "actions-attaque_mj.tga",
    "actions-attaque_simple.tga",
    "actions-attraction.tga",
    "actions-brise_armure.tga",
    "actions-buff_debuff_mj.tga",
    "actions-competences.tga",
    "actions-controles.tga",
    "actions-dissipation.tga",
    "actions-entrave.tga",
    "actions-generation_bouclier.tga",
    "actions-generation_buff.tga",
    "actions-generation_debuff.tga",
    "actions-generation_soin.tga",
    "actions-immobilisation.tga",
    "actions-levitation.tga",
    "actions-offensives.tga",
    "actions-perce_armure.tga",
    "actions-permutation.tga",
    "actions-repulsion.tga",
    "actions-resolution_test_mj.tga",
    "actions-supports.tga",
    "animation.tga",
    "attaque_mj.tga",
    "attaque_simple.tga",
    "attraction.tga",
    "brise_armure.tga",
    "buff_debuff_mj.tga",
    "competences.tga",
    "controles.tga",
    "dissipation.tga",
    "entrave.tga",
    "fenetres-apprentissage.tga",
    "fenetres-bourse.tga",
    "fenetres-compendium.tga",
    "fenetres-deplacement.tga",
    "fenetres-equipement.tga",
    "fenetres-expertise.tga",
    "fenetres-fiche.tga",
    "fenetres-grimoires.tga",
    "fenetres-incarner.tga",
    "fenetres-inventaires.tga",
    "fenetres-metiers.tga",
    "fenetres-objets.tga",
    "fenetres-outils.tga",
    "fenetres-panneau_mj.tga",
    "fenetres-parametres.tga",
    "fenetres-penetrations_resistances.tga",
    "fenetres-personnages.tga",
    "fenetres-regles.tga",
    "fenetres-ressources.tga",
    "fenetres-sante.tga",
    "fenetres-statistiques.tga",
    "fenetres-vendeur.tga",
    "generation_bouclier.tga",
    "generation_buff.tga",
    "generation_debuff.tga",
    "generation_soin.tga",
    "immobilisation.tga",
    "levitation.tga",
    "offensives.tga",
    "perce_armure.tga",
    "permutation.tga",
    "repulsion.tga",
    "resolution_test_mj.tga",
    "supports.tga",
}

function LCM.IconesCampagne()
    local out = {}
    for _, nom in ipairs(DISPONIBLES) do out[#out + 1] = connues[nom] end
    for _, fichier in ipairs(ICONES_COURONNES) do
        out[#out + 1] = "Interface/AddOns/LesContesMalveillants/ressources/radial/icones/" .. fichier
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- La correspondance champ de fiche -> icone, telle que le template la declare.
-- Tout ce qui n'est pas ici s'affiche sans icone : mieux vaut une ligne nue
-- qu'une icone qui raconte autre chose que ce qu'elle designe.
LCM.ICONES_CHAMPS = {
    -- Statistiques (onglet STATISTIQUES du template)
    pv_max           = ICONE .. "eps_lol_tft_heartemblem",      -- « Point de vie »
    corps            = ICONE .. "eps_lol_tft_heartemblem",      -- meme jauge, zone par zone
    armure           = ICONE .. "eps_lol_tft_sentinelemblem",   -- « Boucliers »
    fatigue          = ICONE .. "eps_rumble_arcenergy",
    pa               = ICONE .. "eps_lol_tft_ghostlyemblem",    -- « PA »
    initiative       = ICONE .. "eps_buildershaven_waypointmoddelay",
    depl_terrestre   = ICONE .. "eps_lol_tft_hextechemblem",    -- « Terrestre »
    depl_nage        = ICONE .. "eps_lol_tft_visionaryemblem",
    -- Le template ne connait pas le vol : icone de la campagne.
    depl_vol         = DOSSIER .. "vol.blp",

    -- Caracteristiques (conteneur « Statistiques »)
    force            = ICONE .. "ability_warrior_bloodfrenzy",
    mystique         = ICONE .. "ability_bastion_monk",
    perception       = ICONE .. "eps_lol_item_eyeofthebeholder",
    adresse          = ICONE .. "ability_titankeeper_phasing",
    esprit           = ICONE .. "spell_shadow_brainwash",
    constitution     = ICONE .. "ability_warrior_intensifyrage",

    -- Existence (onglet Intangible)
    existence_esprit = ICONE .. "ability_nightfae_soulshape",
    existence_ame    = ICONE .. "spell_warlock_demonsoul",
}

-- L'icone d'un champ du schema : celle qu'il declare, sinon celle du template.
function LCM.IconeChamp(field)
    if type(field) ~= "table" then return nil end
    if field.icone then return field.icone end
    return LCM.ICONES_CHAMPS[field.id]
end
