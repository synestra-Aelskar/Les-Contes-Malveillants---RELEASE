-- Jets.
--
-- Un jet = des + valeur investie + apport des primaires (Core/Formules.lua)
-- + bonus portes (traits, objets) + modificateur ponctuel. Avec avantage, on lance DEUX FOIS et l'on garde le meilleur : c'est
-- le joueur qui coche la case, car lui seul sait si la situation correspond a
-- son trait ou a son objet.
--
-- Le resultat est detaille (les deux jets, ce qui a ete garde, d'ou vient
-- chaque point) : un jet qu'on ne peut pas expliquer est un jet qu'on conteste.

local _, LCM = ...

local Roll = {}
LCM.Roll = Roll

local function Alea(minimum, maximum)
    if maximum <= minimum then return minimum end
    return math.random(minimum, maximum)
end

-- Un jet brut, entre deux bornes : le grimoire s'en sert pour ses sorts, qui
-- portent leur propre plage et ne passent pas par un champ de la fiche.
function Roll.Des(minimum, maximum)
    minimum = math.floor(tonumber(minimum) or 0)
    maximum = math.floor(tonumber(maximum) or 0)
    if maximum < minimum then minimum, maximum = maximum, minimum end
    return Alea(minimum, maximum), minimum, maximum
end

-- options : { avantage = true, desavantage = true, modificateur = 0,
--             traitExpertise = trait }
function Roll.Field(entity, fieldId, options)
    options = type(options) == "table" and options or {}
    local field = LCM.Schema.Field(fieldId)
    if not field then return nil, "champ inconnu" end
    if field.kind ~= "roll" then return nil, "ce champ ne se lance pas" end

    local dice = type(field.dice) == "table" and field.dice or {}
    local minimum = math.floor(tonumber(dice.min) or 0)
    local maximum = math.floor(tonumber(dice.max) or 0)
    if maximum < minimum then minimum, maximum = maximum, minimum end

    local valeur = tonumber(LCM.Entities.Get_Value(entity, fieldId)) or 0
    local apport = LCM.Formules.Apport(entity, fieldId)
    local bonus = LCM.Effets.Bonus(entity, fieldId)
    local modificateur = tonumber(options.modificateur) or 0
    local fixe = valeur + apport + bonus + modificateur

    -- L'avantage doit etre accorde par un trait ou un objet : cocher la case
    -- ne suffit pas. `trait` garde son nom, mais peut designer un objet.
    local trait, source = LCM.Effets.Avantage(entity, fieldId)
    if options.traitExpertise then
        trait, source = options.traitExpertise, "trait"
    end
    local avantage = options.avantage == true and trait ~= nil

    -- Le DESAVANTAGE, lui, ne se coche pas : il s'impose des qu'un trait porte
    -- un bonus negatif sur ce jet. On ne choisit pas ses faiblesses.
    local genant, sourceGenante = LCM.Effets.Desavantage(entity, fieldId)
    local desavantageChoisi = options.desavantage == true and options.traitExpertise ~= nil
    local desavantage = desavantageChoisi or genant ~= nil
    -- Les deux a la fois s'annulent : relancer pour garder le meilleur ET le
    -- pire n'a pas de sens, et c'est le cas d'un trait qui donne et reprend sur
    -- le meme jet.
    if avantage and desavantage then
        avantage, desavantage = false, false
    end

    local premier = Alea(minimum, maximum)
    local second = (avantage or desavantage) and Alea(minimum, maximum) or nil
    local garde = premier
    if second then
        if avantage and second > premier then garde = second end
        if desavantage and second < premier then garde = second end
    end

    return {
        field = field,
        label = field.label,
        des = { min = minimum, max = maximum },
        jets = second and { premier, second } or { premier },
        garde = garde,
        valeur = valeur,
        apport = apport,
        bonus = bonus,
        modificateur = modificateur,
        total = garde + fixe,
        avantage = avantage,
        trait = trait,
        source = source,
        desavantage = desavantage,
        desavantageChoisi = desavantageChoisi,
        genant = desavantageChoisi and options.traitExpertise or genant,
        sourceGenante = desavantageChoisi and "trait" or sourceGenante,
        -- Vrai quand la case etait cochee mais qu'aucun trait ne l'autorisait :
        -- on le dit plutot que d'ignorer en silence.
        avantageRefuse = options.avantage == true and trait == nil,
    }
end

-- Un jet d'expertise compare le resultat a un DD. En cas d'echec ou de
-- reussite partielle, le NF saisi est retire de la fatigue ; une reussite
-- totale (DD + 10 ou maximum possible du jet) ne coute rien.
function Roll.ResoudreExpertise(entity, fieldId, dd, nf, options)
    local field = LCM.Schema.Field(fieldId)
    if not field or field.jetExpertise ~= true then return nil, "expertise inconnue" end
    dd, nf = tonumber(dd), tonumber(nf) or 0
    if not dd or dd < 0 or dd ~= math.floor(dd) then return nil, "DD invalide" end
    if nf < 0 or nf ~= math.floor(nf) then return nil, "NF invalide" end
    if type(entity) ~= "table" or entity.distante then return nil, "personnage indisponible" end

    options = type(options) == "table" and options or {}
    if options.avantage == true and options.desavantage == true then
        return nil, "choisis l'avantage ou le désavantage, pas les deux"
    end
    local traitExpertise = LCM.Traits and LCM.Traits.BonusPositif
        and LCM.Traits.BonusPositif(entity, fieldId) or nil
    local avantageExistant = options.avantage == true and LCM.Effets.Avantage(entity, fieldId) ~= nil
    if (options.desavantage == true or (options.avantage == true and not avantageExistant))
        and not traitExpertise then
        return nil, "aucun trait ne donne de bonus à cette expertise"
    end
    local optionsJet = {
        avantage = options.avantage == true,
        desavantage = options.desavantage == true,
        modificateur = options.modificateur,
        traitExpertise = traitExpertise,
    }

    -- Les deux des sont lances AVANT de resoudre l'issue. La fatigue n'est
    -- donc calculee et retiree qu'une fois, d'apres le de finalement garde.
    local resultat, raison = Roll.Field(entity, fieldId, optionsJet)
    if not resultat then return nil, raison end
    local stat = resultat.valeur + resultat.apport + resultat.bonus + resultat.modificateur
    local maximum = resultat.des.max + stat
    local critique = resultat.total >= maximum
    local issue
    if critique or resultat.total >= dd + 10 then
        issue = "Réussite totale"
    elseif resultat.total >= dd then
        issue = "Réussite partielle"
    else
        issue = "Échec"
    end

    local perte = 0
    if issue ~= "Réussite totale" and nf > 0 then
        local fatigue = LCM.Entities.Gauge(entity, "fatigue")
        if not fatigue then return nil, "fatigue indisponible" end
        perte = math.min(nf, fatigue.current)
        if perte > 0 and not LCM.Entities.SetGauge(entity, "fatigue", fatigue.current - perte) then
            return nil, "fatigue impossible à dépenser"
        end
    end
    return { jet = resultat, dd = dd, nf = nf, stat = stat, issue = issue,
        critique = critique, perteFatigue = perte }
end

-- Une ligne lisible, pour le chat.
function Roll.Describe(resultat)
    if type(resultat) ~= "table" then return "" end
    -- Chaque part est NOMMEE, « Nom : valeur ». « de 2, valeur +4, stats +4 »
    -- se lisait comme une phrase, et on ne savait pas ou finissait le libelle
    -- ni ou commencait le chiffre.
    local morceaux = {}
    if #resultat.jets > 1 then
        morceaux[#morceaux + 1] = string.format("Jets : %d et %d, gardé : %d",
            resultat.jets[1], resultat.jets[2], resultat.garde)
    else
        morceaux[#morceaux + 1] = string.format("Jets : %d", resultat.garde)
    end
    if resultat.valeur ~= 0 then morceaux[#morceaux + 1] = string.format("Base : %+d", resultat.valeur) end
    if (resultat.apport or 0) ~= 0 then morceaux[#morceaux + 1] = string.format("Stat : %+d", resultat.apport) end
    if resultat.bonus ~= 0 then morceaux[#morceaux + 1] = string.format("Bonus : %+d", resultat.bonus) end
    if resultat.modificateur ~= 0 then morceaux[#morceaux + 1] = string.format("Modificateur : %+d", resultat.modificateur) end
    -- Ce que les expertises de parade ajoutent (Core/Expertises.lua). Une part
    -- nommee du jet, comme les autres : accolee apres coup, elle laissait un
    -- total qui ne la comptait pas.
    if (resultat.expertises or 0) ~= 0 then
        morceaux[#morceaux + 1] = string.format("Expertises : %+d", resultat.expertises)
    end
    local ligne = string.format("%s : %d  (%s)", resultat.label, resultat.total, table.concat(morceaux, ", "))
    if resultat.desavantage and resultat.genant then
        ligne = ligne .. "  — désavantage : " .. resultat.genant.label
    elseif resultat.avantage and resultat.trait then
        ligne = ligne .. "  — avantage : " .. resultat.trait.label
    end
    return ligne
end
