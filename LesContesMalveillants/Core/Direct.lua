-- En direct : tout geste qui change un personnage previent l'interface.
--
-- `Entities.Changed` existait pour les valeurs de fiche (Set_Value, jauges) :
-- une action qui coute des PA se voyait aussitot. Mais equiper une dague, la
-- ranger, gagner un trait, poser un etat, payer... ne passaient pas par la :
-- la fenetre Statistiques gardait ses anciens chiffres jusqu'a ce qu'on change
-- d'onglet (3 octobre 2026).
--
-- Plutot que de semer un appel dans chaque module, la liste des gestes est
-- ICI, en un seul endroit : chaque fonction est enveloppee, et previent une
-- fois son travail fini. Un geste qui en appelle d'autres (Equiper = Placer
-- + sortir du sac) ne previent qu'a la fin : on ne redessine pas une fenetre
-- sur un etat a moitie fait. Une fonction ajoutee a un module et qui change
-- un personnage s'ajoute a la liste ci-dessous.
--
-- Charge apres tous les modules de Core qu'il enveloppe.

local _, LCM = ...

local Direct = { profondeur = 0, enAttente = {} }
LCM.Direct = Direct

-- Les gestes, par module : le personnage est toujours le premier argument.
local GESTES = {
    { "Objets", { "Equiper", "Desequiper", "Placer", "Enlever", "Encaisser", "PorterProtection" } },
    { "Apprentissages", { "Placer", "Enlever" } },
    { "Etats", { "Placer", "Enlever" } },
    { "Sacs", { "Placer", "Enlever" } },
    { "Inventaire", { "Poser", "Retirer", "Deplacer", "Solde", "Ranger", "Quantite", "Vider", "Prendre", "Deposer" } },
    { "Traits", { "Grant", "Revoke" } },
    { "EtatsTemporaires", { "Poser", "Retirer", "Round", "Guerir" } },
    { "Body", { "Damage", "Heal", "SetCurrent", "HealAll" } },
    { "Metiers", { "Gagner" } },
    { "Sorts", { "Ajouter", "Modifier", "Supprimer" } },
    { "Grimoires", { "Donner" } },
    { "Bourse", { "Crediter", "Debiter" } },
    { "Experience", { "Donner" } },
    -- Une refonte efface puis repose de nombreuses valeurs et plusieurs traits :
    -- l'interface ne doit voir que la fiche terminée, jamais l'état intermédiaire.
    { "Creation", { "Appliquer" } },
}

-- Previent pour chaque personnage touche, une fois.
local function Vider()
    local touches = Direct.enAttente
    Direct.enAttente = {}
    for entity in pairs(touches) do LCM.Entities.Changed(entity, "direct") end
end

-- Appele par Entities.Changed : pendant un geste, on retient au lieu de
-- prevenir. Vrai si c'est retenu.
function Direct.Differer(entity)
    if Direct.profondeur <= 0 then return false end
    if type(entity) == "table" then Direct.enAttente[entity] = true end
    return true
end

local function Terminer(entity, ok, ...)
    Direct.profondeur = Direct.profondeur - 1
    if type(entity) == "table" then Direct.enAttente[entity] = true end
    if Direct.profondeur == 0 then Vider() end
    if not ok then error((...), 0) end
    return ...
end

local function Envelopper(module, nomModule, nom)
    local original = module[nom]
    if type(original) ~= "function" then
        LCM.Erreur(string.format("direct : %s.%s introuvable", nomModule, nom))
        return
    end
    module[nom] = function(entity, ...)
        Direct.profondeur = Direct.profondeur + 1
        return Terminer(entity, pcall(original, entity, ...))
    end
end

for _, groupe in ipairs(GESTES) do
    local module = LCM[groupe[1]]
    if type(module) ~= "table" then
        LCM.Erreur("direct : module introuvable : " .. groupe[1])
    else
        for _, nom in ipairs(groupe[2]) do Envelopper(module, groupe[1], nom) end
    end
end

-- ===== Les ecouteurs ========================================================
-- `Entities.onChange` n'avait qu'une place (les vues la prenaient). Ceux qui
-- veulent suivre un personnage s'inscrivent ici ; `onChange` reste servi.

Direct.ecouteurs = {}

function LCM.Entities.Ecouter(fn)
    if type(fn) == "function" then Direct.ecouteurs[#Direct.ecouteurs + 1] = fn end
end
