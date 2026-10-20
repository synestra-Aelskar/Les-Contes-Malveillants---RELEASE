-- Les metiers du template (compendium « Liste metiers »), dans son ordre.
-- Nom, icone et description d'origine. Leur progression suit la table
-- « XP METIER » (Equilibrage.metiers).

local _, LCM = ...
local Metiers = LCM.Metiers

local function Metier(id, label, icone, description)
    Metiers.Add({ id = id, label = label, icone = icone, description = description })
end

Metier("depeceur", "Dépeçeur", "inv_misc_profession_book_skinning",
    "Permet de récupérer et préserver efficacement les composants issus des créatures.")
Metier("mineur", "Mineur", "inv_misc_profession_book_mining",
    "Spécialiste de l’extraction de minerais et de ressources enfouies.")
Metier("herboriste", "Herboriste", "inv_misc_profession_book_herbalism",
    "Identifie et récolte les ressources naturelles utiles à la transformation.")
Metier("bucheron", "Bûcheron", "inv_axe_19",
    "Récolte et exploite le bois, permettant l’obtention de matériaux et ressources naturelles issues des forêts.")
Metier("pecheur", "Pêcheur", "inv_fishingpole_02",
    "Permet de capturer des ressources aquatiques et d’exploiter les milieux marins ou fluviaux.")
Metier("traqueur", "Traqueur", "ability_hunter_snipershot",
    "Repère, piste et anticipe les déplacements des créatures et des cibles.")
Metier("eclaireur", "Eclaireur", "eps_lol_vayne_nighthunterold",
    "Explore, sécurise et révèle les dangers ou opportunités du terrain.")
Metier("militaire", "Militaire", "spell_nature_enchantarmor",
    "Maîtrise les stratégies, formations et tactiques de combat pour coordonner et optimiser les affrontements.")
Metier("gardien", "Gardien", "inv_shield_04",
    "Assure la surveillance et la sécurité d’un lieu, capable de détecter, alerter et réagir face aux menaces.")
Metier("forgeron", "Forgeron", "ability_rogue_reinforcedleather",
    "Permet de créer, améliorer et réparer armes et armures.")
Metier("artisan", "Artisan", "inv_offhand_1h_draenorcrafted_d_02a",
    "Permet de créer, améliorer et réparer des objets non métalique")
Metier("ingenieur", "Ingénieur", "inv_eng_gearspringparts",
    "Conçoit des mécanismes, gadgets et dispositifs techniques avancés.")
Metier("batisseur", "Bâtisseur", "garrison_building_workshop",
    "Construit et améliore structures, défenses et installations temporaires.")
Metier("tailleur", "Tailleur", "trade_tailoring",
    "Conçoit des pièces d'équipement ou objets à partir de tissus.")
Metier("tanneur", "Tanneur", "inv_skinning_80_coarseleather",
    "Conçoit des pièces d'équipement ou des objets à partir de cuir qu'il peut créer.")
Metier("joaillier", "Joaillier", "inv_jewelry_necklace_76",
    "Conçoit des bijoux, ornement, ou parrure à partir de métaux et pierre précieuse")
Metier("cuisinier", "Cuisinier", "achievement_cooking_masteroftheoven",
    "Transforme des ingrédients en plats offrant des effets temporaires, améliorant la récupération et les performances du groupe.")
Metier("alchimiste", "Alchimiste", "inv_alchemy_70_blue",
    "Transforme des substances en potions, poisons et composés instables.")
Metier("medical", "Médical", "inv_first_aid_70_medicalkit",
    "Soigne, stabilise et traite les blessures ainsi que les altérations physiques.")
Metier("erudit", "Erudit", "hd_book1_brown",
    "Accumule et exploite les connaissances pour identifier et comprendre le monde.")
Metier("historien", "Historien", "spell_mage_altertime",
    "Collecte, organise et exploite des informations historiques.")
Metier("artificier", "Artificier", "inv_misc_bomb_03",
    "Conçoit et utilise des explosifs, charges et dispositifs à effet destructeur ou tactique.")
Metier("enchanteur", "Enchanteur", "inv_enchanting_80_veiledcrystal",
    "Imprègne les objets de magie pour leur conférer des propriétés spéciales et persistantes.")
Metier("occultiste", "Occultiste", "trade_archaeology_troll_voodoodoll",
    "Interagit avec les forces invisibles, malédictions et phénomènes surnaturels.")
Metier("guide_spirituel", "Guide spirituel", "spell_holy_guardianspirit",
    "Accompagne les esprits et influence les états mentaux ou émotionnels des individus.")
Metier("runiste", "Runiste", "70_inscription_vantus_rune_odyn",
    "Grave et manipule des runes pour conférer des effets durables aux objets ou aux lieux.")
Metier("ritualiste", "Ritualiste", "inv_helm_misc_candle_a_01",
    "Réalise des rituels complexes pour invoquer, altérer ou renforcer des forces au-delà du commun.")
Metier("negociant", "Négociant", "garrison_building_tradingpost",
    "Optimise les échanges, les prix et les gains économiques.")
Metier("diplomate", "Diplomate", "achievement_halloween_smiley_01",
    "Facilite les interactions sociales, négociations et résolutions sans combat")
Metier("artiste", "Artiste", "inv_misc_flute_01",
    "Interprète ou crée des œuvres artistiques : musique, danse, théâtre ou arts visuels.")
Metier("dresseur", "Dresseur", "ability_hunter_pet_assist",
    "Permet de capturer, apprivoiser et utiliser des créatures comme montures ou aides.")
Metier("informaticien", "Informaticien", "inv_misc_punchcards_blue",
    "Interagit avec les systèmes numériques, la matrice et les technologies avancées.")
