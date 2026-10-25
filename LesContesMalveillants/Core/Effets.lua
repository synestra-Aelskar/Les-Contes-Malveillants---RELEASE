-- Effets : ce qu'une chose portee apporte a une fiche.
--
-- Un trait, un objet equipe : deux choses differentes, un seul langage.
--   * `bonus`    : { [champ] = montant } — sur les six primaires, seulement
--                  pour un objet (voir Lire) ;
--   * `avantage` : des jets relances, dont on garde le meilleur ;
--   * `desavantage` : des jets relances, dont on garde le PIRE. Il se declare,
--                  comme l'avantage : un bonus negatif ne l'impose pas (le MJ,
--                  24 octobre 2026 — « c'est beaucoup trop punitif »).
--   * `pourcent`  : les champs dont le `bonus` n'est PAS un nombre de points
--                  mais un pourcentage. « Force -40 » devient « baisse la
--                  Force de 40 % » (le MJ, 24 octobre 2026). Le montant reste
--                  dans `bonus` : seule sa LECTURE change.
--
-- Ce module tient la REGLE (ce qu'un effet a le droit de viser) et la SOMME
-- (ce que tout ce qu'on porte donne sur un champ). Les registres (Traits,
-- Objets) s'y declarent comme sources ; la fiche et les jets ne demandent
-- qu'ici, sans savoir d'ou vient un bonus.

local _, LCM = ...

local Effets = { sources = {} }
LCM.Effets = Effets

-- Partagees et en lecture seule : un element qui ne declare ni desavantage ni
-- pourcentage n'a pas besoin de sa propre table vide.
local VIDE_DESAVANTAGE = {}
local VIDE_POURCENT = {}

-- Les six primaires sont hors de portee : c'est une regle de jeu, donc elle
-- est verifiee par le code et pas seulement ecrite quelque part.
Effets.PRIMAIRES = {
    force = true, mystique = true, perception = true,
    adresse = true, esprit = true, constitution = true,
}

-- Une LISTE de champs, telle qu'une definition l'ecrit — ou l'ENSEMBLE que
-- `Lire` en a deja fait. Les deux arrivent ici : la forge et l'editeur du
-- compendium repartent de l'element CONSTRUIT, donc de l'ensemble, et le
-- relire avec `ipairs` rendait une table vide. Un avantage disparaissait ainsi
-- en silence a chaque reenregistrement d'une entree (24 octobre 2026).
local function Ensemble(valeur)
    local out = {}
    if type(valeur) ~= "table" then return out end
    for cle, v in pairs(valeur) do
        if type(cle) == "number" then
            if v ~= nil and v ~= false then out[tostring(v)] = true end
        elseif v == true then
            out[tostring(cle)] = true
        end
    end
    return out
end
Effets.Ensemble = Ensemble

-- Lit et verifie les effets d'une definition. `Erreur` est celle du registre
-- appelant : le message garde son prefixe (« LCM/Traits : ... »).
-- `primairesPermises` : un objet peut donner de la Force (le template en a),
-- un trait jamais.
function Effets.Lire(id, definition, Erreur, primairesPermises)
    local bonus = {}
    for fieldId, value in pairs(definition.bonus or {}) do
        local cible = tostring(fieldId)
        if Effets.PRIMAIRES[cible] and not primairesPermises then
            Erreur(id .. " : ne peut pas modifier une statistique primaire (" .. cible .. ")")
        end
        local montant = tonumber(value)
        if not montant or montant == 0 then
            Erreur(id .. " : bonus nul ou illisible sur " .. cible)
        end
        bonus[cible] = montant
    end
    local avantage = Ensemble(definition.avantage)
    -- Le desavantage se declare jet par jet, comme l'avantage. Avant le
    -- 24 octobre 2026, il n'existait pas : c'est le SIGNE du bonus qui
    -- l'imposait, et un etat qui retirait un point d'Adresse condamnait tous
    -- les jets d'Adresse.
    local desavantage = Ensemble(definition.desavantage)
    -- Un pourcentage sans montant ne ferait rien du tout, en silence : c'est
    -- la case cochee puis la valeur remise a zero. On le dit.
    local pourcent = Ensemble(definition.pourcent)
    for cible in pairs(pourcent) do
        if bonus[cible] == nil then
            Erreur(id .. " : pourcentage sans montant sur " .. cible)
        end
    end
    return bonus, avantage, desavantage, pourcent
end

-- Une source : ce qu'une entite porte de ce genre. `portes(entity)` renvoie
-- les elements (tables a `label`, `bonus`, `avantage`), `liste()` tout ce
-- qui existe (pour la verification au demarrage). L'ordre de declaration est
-- l'ordre de priorite quand deux sources accordent le meme avantage.
--
-- `apport(entity, element, montant)` : ce que l'element donne VRAIMENT. Sans
-- lui, il donne ce qu'il annonce. L'equipement s'en sert pour n'apporter que
-- ce que son etat permet encore (9 octobre 2026) — la regle vit chez les
-- objets, et les effets n'ont pas a savoir ce qu'est une armure abimee.
function Effets.Source(nom, portes, liste, apport)
    Effets.sources[#Effets.sources + 1] = { nom = nom, portes = portes, liste = liste,
                                            apport = apport }
end

-- Ce qu'un element d'une source donne sur un champ, module s'il y a lieu.
-- `rang` : sa place dans `portes(entity)`. Deux objets identiques portes sont
-- deux exemplaires, chacun avec son etat : le modele seul ne dit pas lequel.
local function Apport(source, entity, element, cible, rang)
    local montant = element.bonus[cible] or 0
    if montant == 0 or not source.apport then return montant end
    return source.apport(entity, element, montant, rang) or 0
end
Effets.Apport = Apport

-- Ce montant se lit-il en pourcentage ?
local function EnPourcent(element, cible)
    return (element.pourcent or VIDE_POURCENT)[cible] == true
end
Effets.EnPourcent = EnPourcent

-- L'unite a ecrire apres un montant, pour que « Force -40 » et
-- « Force -40 % » ne se confondent pas. Toutes les fenetres passent par ici :
-- un meme etat doit se lire pareil partout.
function Effets.Unite(element, cible)
    return EnPourcent(element, tostring(cible)) and " %" or ""
end

-- Somme des bonus PLATS portes sur un champ : les pourcentages ne sont pas des
-- points et ne s'additionnent pas avec eux.
function Effets.Bonus(entity, fieldId)
    local total, cible = 0, tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for rang, element in ipairs(source.portes(entity)) do
            if not EnPourcent(element, cible) then
                total = total + Apport(source, entity, element, cible, rang)
            end
        end
    end
    return total
end

-- Somme des POURCENTAGES portes sur un champ. Ils s'additionnent entre eux et
-- ne se composent pas : deux etats a -40 % font -80 %, pas -64 %. C'est la
-- regle qu'on peut tenir de tete a une table, et elle ne depend pas de l'ordre
-- dans lequel les etats ont ete poses.
function Effets.Pourcent(entity, fieldId)
    local total, cible = 0, tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for rang, element in ipairs(source.portes(entity)) do
            if EnPourcent(element, cible) then
                total = total + Apport(source, entity, element, cible, rang)
            end
        end
    end
    return total
end

-- D'OU vient le bonus, source par source. Le total seul ne dit pas si ces +4
-- viennent de la race, d'un trait ou de l'equipement — et c'est la premiere
-- question qu'on se pose devant une fiche (5 octobre 2026).
--
-- Rend une liste { nom, total, pourcent, elements = { { label, montant,
-- pourcent } } }, dans l'ordre de declaration des sources, en ne gardant que
-- celles qui apportent quelque chose. `total` ne compte que les points :
-- melanger les deux afficherait « +(-40) » pour une baisse de 40 %.
function Effets.Detail(entity, fieldId)
    local cible, out = tostring(fieldId), {}
    for _, source in ipairs(Effets.sources) do
        local total, pourcent, elements = 0, 0, {}
        for rang, element in ipairs(source.portes(entity)) do
            local montant = Apport(source, entity, element, cible, rang)
            local enPourcent = EnPourcent(element, cible)
            if enPourcent then pourcent = pourcent + montant else total = total + montant end
            -- Un par un : « Traits +3 » ne dit pas lequel des traits le donne.
            if montant ~= 0 then
                elements[#elements + 1] = { label = element.label, montant = montant,
                                            pourcent = enPourcent or nil }
            end
        end
        if total ~= 0 or pourcent ~= 0 then
            out[#out + 1] = { nom = source.nom, total = total, pourcent = pourcent,
                              elements = elements }
        end
    end
    return out
end

-- Ce qui accorde l'avantage sur ce jet, s'il y a quelque chose : l'element
-- (trait ou objet) et le nom de sa source.
function Effets.Avantage(entity, fieldId)
    local cible = tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.portes(entity)) do
            if element.avantage[cible] then return element, source.nom end
        end
    end
    return nil
end

-- Ce qui impose un DESAVANTAGE sur ce jet. Rien ne se declare : il se deduit
-- d'un bonus NEGATIF. Un trait qui retire des points a « Vol a la tire » gene
-- celui qui le porte des qu'il s'en sert — on ne choisit pas ses faiblesses
-- comme on choisit ses forces (regle du 5 octobre 2026).
--
-- Rend l'element fautif et le nom de sa source, comme Avantage.
-- Les sources dont un bonus negatif n'impose PLUS le desavantage : les etats,
-- qu'on subit. Un trait, lui, est un defaut qu'on a choisi a la creation — « on
-- ne choisit pas ses faiblesses » reste vrai pour lui (le MJ, 24 octobre 2026).
local SUBI = { ["etat"] = true, ["état temporaire"] = true }

-- Le desavantage sur ce jet : celui qu'un element DECLARE, ou, pour ce qui
-- n'est pas subi, celui qu'un bonus negatif impose encore.
function Effets.Desavantage(entity, fieldId)
    local cible = tostring(fieldId)
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.portes(entity)) do
            if (element.desavantage or VIDE_DESAVANTAGE)[cible] then
                return element, source.nom
            end
            if not SUBI[source.nom] and (element.bonus[cible] or 0) < 0 then
                return element, source.nom
            end
        end
    end
    return nil
end

-- Les champs vises n'existent pas forcement au moment ou un element est
-- declare (les fichiers se chargent dans l'ordre du .toc). On verifie donc une
-- fois, a la connexion, quand toute la feuille est connue.
LCM.WhenReady(function()
    for _, source in ipairs(Effets.sources) do
        for _, element in ipairs(source.liste and source.liste() or {}) do
            for fieldId in pairs(element.bonus) do
                local metierId = tostring(fieldId):match("^metier:(.+)$")
                -- Les criteres d'un consommable : une jauge rendue a la
                -- consommation (Core/Consommation.lua), pas un champ porte.
                if not LCM.Schema.Field(fieldId)
                    and not (metierId and LCM.Metiers.Get(metierId))
                    and not (LCM.Consommation and LCM.Consommation.Critere(fieldId)) then
                    LCM.Erreur(string.format("%s « %s » : bonus vers un champ inconnu (%s)",
                        source.nom, element.label, fieldId))
                end
            end
            for fieldId in pairs(element.avantage) do
                local field = LCM.Schema.Field(fieldId)
                if not field then
                    LCM.Erreur(string.format("%s « %s » : avantage sur un champ inconnu (%s)",
                        source.nom, element.label, fieldId))
                elseif field.kind ~= "roll" then
                    LCM.Erreur(string.format("%s « %s » : avantage sur « %s », qui ne se lance pas",
                        source.nom, element.label, fieldId))
                end
            end
        end
    end
end)
