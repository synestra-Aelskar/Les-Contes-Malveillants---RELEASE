-- Jouer une resolution d'action du compendium.
--
-- Les resolutions (Data/Genere/Compendium_Resolutions.lua) sont celles de
-- Necronicon, importees telles quelles : des feuilles d'etapes (composer,
-- calculer, payer, declarer...). Ce fichier est le moteur qui les joue, repris
-- de ActionResolution.lua de Necronicon et reduit, pour l'instant, a ce qui se
-- passe chez CELUI QUI AGIT :
--
--   compose   l'assistant de choix (les questions, les couts PA / PF)
--   compute   un calculateur du compendium, sources injectees
--   pay       le debit des jauges (differe jusqu'a la declaration)
--   declare   les jets {jet:...}, le debit, l'annonce
--   message   un message a lire
--   call      aller a une autre etape, ou a une feuille commune
--   condition si / sinon si / sinon
--
-- Le reste (cibler, la defense chez la cible, les etats, la repartition d'un
-- soin...) n'est pas encore la. Une etape inconnue ARRETE la resolution et le
-- dit ; comme les couts ne sont debites qu'a la declaration, rien n'est perdu.
-- On ne saute jamais une etape en silence.
--
-- Les formules des resolutions parlent la langue de Necronicon : {stat:Base buff
-- Pen}, [[0.fiche.window_custom_7::custom_11::field_221.value]]. Notre fiche
-- est figee dans le code, ces noms n'y existent pas : la TABLE DE
-- CORRESPONDANCE ci-dessous les traduit, une famille a la fois. Une reference
-- qu'elle ne connait pas vaut 0 — comme dans Necronicon — mais elle est notee
-- dans ctx.inconnues et signalee : un calcul faux ne doit pas avoir l'air juste.

local _, LCM = ...

local Actions = {}
LCM.Actions = Actions

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Eq() return LCM.Equilibrage end

local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Comparaison tolerante : minuscules, sans accents, sans espaces ni tirets.
-- « Perce-armure », « percearmure » et « Perce armure » designent la meme chose.
local ACCENTS = {
    ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ä"] = "a", ["ã"] = "a",
    ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
    ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["ö"] = "o", ["õ"] = "o",
    ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c", ["ñ"] = "n",
    ["À"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ç"] = "c",
}
local function Cle(s)
    s = tostring(s or ""):gsub("[\195][\128-\191]", function(c) return ACCENTS[c] or c end)
    return (s:lower():gsub("[%s%-_'%.]+", ""))
end
Actions.Cle = Cle

-- ===== Table de correspondance =============================================

-- Une valeur de fiche telle que les actions la lisent : ce qui est investi,
-- plus ce que portent traits, objets et etats.
local function Total(entity, fieldId)
    if not LCM.Schema.Field(fieldId) then return nil end
    return (tonumber(LCM.Entities.Get_Value(entity, fieldId)) or 0) + LCM.Effets.Bonus(entity, fieldId)
end

-- Les nombres de l'onglet « Equilibrage ACTIONS », par libelle du template.
local LIBELLES_ACTIONS = {
    ["Base multi Force"] = "multiForce", ["Base multi Mystique"] = "multiMystique",
    ["Base multi Perception"] = "multiPerception",
    ["Base constitution"] = "baseConstitution", ["Equilibrage reduction Mod"] = "reductionMod",
    ["Base défense"] = "baseDefense", ["Défense par point"] = "defenseParPoint",
    ["Base bouclier Force"] = "bouclierForce", ["Base bouclier Mystique"] = "bouclierMystique",
    ["Base bouclier Constitution"] = "bouclierConstitution",
    ["Multiplicateur Bouclier"] = "multiBouclier", ["Multiplicateur Stat BOUCLIER"] = "multiStatBouclier",
    ["Multiplicateur Pen BOUCLIER"] = "multiPenBouclier", ["Multiplicateur Fatigue BOUCLIER"] = "multiFatigueBouclier",
    ["Cout PA BOUCLIER"] = "coutPABouclier",
    ["Base soin Mystique"] = "soinMystique", ["Base soin Constitution"] = "soinConstitution",
    ["Multiplicateur SOIN"] = "multiSoin", ["Multiplicateur Stat SOIN"] = "multiStatSoin",
    ["Multiplicateur Pen SOIN"] = "multiPenSoin", ["Multiplicateur Fatigue SOIN"] = "multiFatigueSoin",
    ["Cout PA SOIN"] = "coutPASoin",
    ["Base buff Force"] = "buffForce", ["Base buff Constitution"] = "buffConstitution",
    ["Base buff Perception"] = "buffPerception", ["Base buff Mystique"] = "buffMystique",
    ["Base buff Pen"] = "buffPen", ["Multiplicateur BUFF"] = "multiBuff",
    ["Multiplicateur stat BUFF"] = "multiStatBuff", ["Multiplicateur pen BUFF"] = "multiPenBuff",
    ["Attraction par stat"] = "attractionParStat", ["Attraction par Pen"] = "attractionParPen",
    ["Répulsion par stat"] = "repulsionParStat", ["Répulsion par Pen"] = "repulsionParPen",
    ["Immobilisation par stat"] = "immobilisationParStat", ["Immobilisation par Pen"] = "immobilisationParPen",
    ["Entrave par stat"] = "entraveParStat", ["Entrave par Pen"] = "entraveParPen",
    ["Permutation par stat"] = "permutationParStat", ["Permutation par Pen"] = "permutationParPen",
    ["Déviation par stat"] = "deviationParStat", ["Déviation par Pen"] = "deviationParPen",
    ["Déviation malus distance"] = "deviationMalusDistance", ["Déviation malus autrui"] = "deviationMalusAutrui",
    ["Intervention bonus déplacement"] = "interventionBonusDeplacement",
    ["Déviation bonus action propre"] = "deviationBonusActionPropre",
}
local ACTIONS_PAR_CLE = {}
for libelle, cle in pairs(LIBELLES_ACTIONS) do ACTIONS_PAR_CLE[Cle(libelle)] = cle end

-- Les memes, par identifiant de champ de la fenetre Equilibrage (custom_11).
local CHAMPS_EQUILIBRAGE = {
    field_221 = "multiForce", field_223 = "multiMystique", field_224 = "multiPerception",
    field_226 = "baseConstitution", field_244 = "reductionMod", field_269 = "baseDefense",
    field_270 = "defenseParPoint", field_227 = "bouclierForce", field_228 = "bouclierMystique",
    field_229 = "bouclierConstitution", field_230 = "soinConstitution", field_231 = "soinMystique",
}

-- Le recapitulatif « Statistiques » du template (field_2) : ses lignes sont les
-- statistiques de combat de Data/Combat.lua. Les lignes de mecanique
-- (« repulsion », « entrave »...) n'ont pas d'equivalent : notre recapitulatif
-- n'en porte pas ; elles restent inconnues, et donc signalees.
local RECAP = {
    ["Attaques & Défense/Force"] = "force_attaque", ["Attaques & Défense/Mystique"] = "mystique_attaque",
    ["Attaques & Défense/Perception"] = "perception_attaque",
    ["Perce-Armure/Force"] = "force_perce_armure", ["Perce-Armure/Mystique"] = "mystique_perce_armure",
    ["Perce-Armure/Perception"] = "perception_perce_armure",
    ["Brise-Armure/Force"] = "force_brise_armure", ["Brise-Armure/Mystique"] = "mystique_brise_armure",
    ["Brise-Armure/Perception"] = "perception_brise_armure",
    ["défense_constitution"] = "defense_constitution",
    ["mystique_débuff"] = "mystique_debuff",
    ["durée_buff"] = "duree_buff", ["durée_debuff"] = "duree_debuff",
}
local RECAP_PAR_CLE = {}
for libelle, champ in pairs(RECAP) do RECAP_PAR_CLE[Cle(libelle)] = champ end

-- Une mecanique de competence, par son libelle ou sa cle de grille
-- (« Attaque simple », « attaquesimple »).
local function Mecanique(nom)
    local voulu = Cle(nom)
    for _, m in ipairs(Eq().mecaniques) do
        if Cle(m.id) == voulu or Cle(m.label) == voulu then return m end
    end
end

-- La grille de puissance des mecaniques : colonne Base, Par point, Equip. par point
-- (c1, c2, c3 dans le template).
local COLONNES = { base = "base", parpoint = "parPoint", equipparpoint = "equipParPoint",
                   c1 = "base", c2 = "parPoint", c3 = "equipParPoint" }
local function Puissance(mecanique, colonne)
    local m = Mecanique(mecanique)
    local champ = COLONNES[Cle(colonne)]
    if not (m and champ) then return nil end
    local P = Eq().puissanceMecanique
    local propre = P.parMecanique[m.id]
    return tonumber(propre and propre[champ]) or tonumber(P[champ])
end

local function Primaire(nom, entity)
    local voulu = Cle(nom)
    for _, p in ipairs(Eq().primaires) do
        if Cle(p.label) == voulu or Cle(p.id) == voulu then return LCM.Formules.Primaire(entity, p.id) end
    end
end

-- Un champ de la fiche par son libelle, en dernier recours.
local function ChampParLibelle(nom, genre)
    local voulu = Cle(nom)
    local trouve
    LCM.Schema.EachField(function(field)
        if not trouve and Cle(field.label) == voulu and (genre == nil or field.kind == genre) then trouve = field end
    end)
    return trouve
end

Actions.ChampParLibelle = ChampParLibelle

-- {stat:<nom>} : « Fenetre#ligne:colonne » ou un nom seul.
function Actions.Stat(nom, entity)
    nom = Trim(nom)
    local fenetre, reste = nom:match("^(.-)#(.+)$")
    if fenetre then
        local f = Cle(fenetre)
        if f == Cle("Mécaniques de compétence") then
            local ligne, colonne = reste:match("^(.-):(.+)$")
            return ligne and Puissance(ligne, colonne)
        elseif f == Cle("Répartition des expertises") then
            local m = Mecanique(reste)
            return m and Total(entity, LCM.MecaniqueField(m.id))
        elseif f == Cle("Recapitulatif") then
            local champ = RECAP_PAR_CLE[Cle(reste)]
            if not champ and LCM.Schema.Field(reste) then champ = reste end
            if champ then return Total(entity, champ) end
            -- Une ligne de mecanique (« repulsion », « dissipation ») : le
            -- recapitulatif du template y additionne ce que portent traits,
            -- etats et equipement. Chez nous : les bonus portes sur la
            -- mecanique, sans les points investis (comptes a part, « Par point »).
            local m = Mecanique(reste)
            return m and LCM.Effets.Bonus(entity, LCM.MecaniqueField(m.id))
        end
        return nil
    end
    local v = Primaire(nom, entity)
    if v then return v end
    local cle = ACTIONS_PAR_CLE[Cle(nom)]
    if cle then return tonumber(Eq().actions[cle]) end
    local field = ChampParLibelle(nom)
    if field and field.kind ~= "gauge" then return Total(entity, field.id) end
    if field then return LCM.Entities.Gauge(entity, field.id).current end
    return nil
end

-- [[...]] : un chemin vers une case d'une fenetre Necronicon.
function Actions.Chemin(chemin, entity)
    chemin = Trim(chemin)
    local id = chemin:match("window_custom_7::custom_11::(field_%d+)%.value$")
    if id then
        local cle = CHAMPS_EQUILIBRAGE[id]
        return cle and tonumber(Eq().actions[cle])
    end
    -- La case N du conteneur des primaires : l'ordre est celui de la feuille.
    local case = chemin:match("window_custom_1_field_39::cell_(%d+)::")
    if case then
        local p = Eq().primaires[tonumber(case)]
        return p and LCM.Formules.Primaire(entity, p.id)
    end
    local ligne = chemin:match("window_custom_6::field_97%.row:(.+)$")
    if ligne then return Actions.Stat("Répartition des expertises#" .. ligne, entity) end
    local meca, col = chemin:match("field_258%.row:([^:]+):(c%d)$")
    if meca then return Puissance(meca, col) end
    ligne = chemin:match("window_custom_20::fiche::field_2%.row:(.+)$")
    if ligne then return Actions.Stat("Recapitulatif#" .. ligne, entity) end
    return nil
end

-- Un jet de la fiche, par son nom (« Adresse », « Esprit »).
function Actions.Jet(nom, entity)
    local field = ChampParLibelle(nom, "roll")
    if not field then return nil end
    return LCM.Roll.Field(entity, field.id)
end

-- ===== Jetons et expressions ===============================================

local function Noter(ctx, quoi)
    if not ctx then return end
    ctx.inconnues = ctx.inconnues or {}
    ctx.inconnues[quoi] = true
end

-- var:<nom>  recu:<tag>  inject:<nom>  stat:/jauge:/champ:<nom>  jet:<nom>
local function Jeton(prefixe, nom, ctx)
    prefixe, nom = tostring(prefixe):lower(), Trim(nom)
    if prefixe == "var" then return ctx.vars[nom] end
    if prefixe == "inject" then return type(ctx.inject) == "table" and ctx.inject[nom] or nil end
    if prefixe == "recu" or prefixe == "reçu" then
        local valeurs = ctx.paquet and ctx.paquet.valeurs or {}
        local v = valeurs[nom]
        if v == nil then
            for k, vv in pairs(valeurs) do if Cle(k) == Cle(nom) then v = vv break end end
        end
        return tonumber(v) or v
    end
    if prefixe == "stat" or prefixe == "jauge" or prefixe == "champ" then
        local v = Actions.Stat(nom, ctx.entity)
        if v == nil then Noter(ctx, prefixe .. ":" .. nom) end
        return v
    end
    if prefixe == "jet" then
        -- Le nom peut etre indirect : jet:var:RandNom.
        local indirect = nom:match("^var:(.+)$")
        if indirect then nom = tostring(ctx.vars[Trim(indirect)] or "") end
        return nom
    end
    return nil
end
Actions.Jeton = Jeton

local CONNUS = { var = true, recu = true, ["reçu"] = true, inject = true, stat = true, jauge = true, champ = true, jet = true }

-- Remplace les jetons d'un texte par leur valeur : {stat:Nom avec espaces} ou
-- var:motSimple. Un jeton sans valeur devient « ? » dans un texte.
--
-- Dans une FORMULE (`expression` vrai), un jeton nu peut porter des espaces
-- (« recu:Rand Résultat + 10 ») : il s'arrete au premier operateur. Dans un
-- texte, il s'arrete a l'espace — sinon « recu:Bouclier points » avalerait la
-- suite de la phrase. Les deux regles sont celles de Necronicon
-- (evalExpression et substituteTokens).
function Actions.Substituer(texte, ctx, inconnu, expression)
    inconnu = inconnu or "?"
    texte = tostring(texte or ""):gsub("%[%[(.-)%]%]", function(chemin)
        local v = Actions.Chemin(chemin, ctx.entity)
        if v == nil then Noter(ctx, "[[" .. chemin .. "]]") return inconnu end
        return tostring(v)
    end)
    texte = texte:gsub("{%s*([%a\195\167]+):([^}]+)}", function(prefixe, nom)
        if not CONNUS[prefixe:lower()] then return nil end
        local v = Jeton(prefixe, nom, ctx)
        return v == nil and inconnu or tostring(v)
    end)
    local nu = expression and "(%a+):([%w%s\128-\255#_:%-]+)" or "(%a+):([%w\128-\255#_:%-]+)"
    texte = texte:gsub(nu, function(prefixe, nom)
        if not CONNUS[prefixe:lower()] then return nil end
        -- Une soustraction espacee (« var:a - 2 ») n'est pas un tiret de nom
        -- (« Perce-armure ») : le nom s'arrete devant. Les espaces de fin
        -- appartiennent a la formule, pas au nom.
        local fin = ""
        local coupe = expression and nom:find("%s%-")
        if coupe then fin, nom = nom:sub(coupe), nom:sub(1, coupe - 1) end
        fin = nom:match("(%s*)$") .. fin
        local v = Jeton(prefixe, nom, ctx)
        return (v == nil and inconnu or tostring(v)) .. fin
    end)
    return texte
end

-- Une expression purement arithmetique (nombres, + - * / % ^, parentheses).
-- Evaluee dans un environnement vide : rien d'autre que du calcul n'y passe.
local function Arithmetique(texte)
    texte = Trim(texte)
    if texte == "" or not texte:find("^[%s%d%.%(%)%+%-%*/%%^]+$") then return nil end
    local f = loadstring("return " .. texte)
    if not f then return nil end
    setfenv(f, {})
    local ok, r = pcall(f)
    if ok and type(r) == "number" and r == r and r ~= math.huge and r ~= -math.huge then return r end
    return nil
end
Actions.Arithmetique = Arithmetique

-- Des « NdM » dans une expression deja substituee.
local function Des(texte)
    return (tostring(texte):gsub("(%d*)[dD](%d+)", function(n, faces)
        n, faces = math.max(1, tonumber(n) or 1), math.max(1, tonumber(faces) or 1)
        local somme = 0
        for _ = 1, n do somme = somme + math.random(1, faces) end
        return tostring(somme)
    end))
end

-- Une formule : jetons, chemins, des, puis calcul. nil si elle ne se calcule pas.
function Actions.Evaluer(texte, ctx)
    texte = Trim(texte)
    if texte == "" then return nil end
    local direct = tonumber(texte)
    if direct then return direct end
    return Arithmetique(Des(Actions.Substituer(texte, ctx, "0", true)))
end

-- Un montant : un jeton seul, sinon une formule.
local function Montant(texte, ctx)
    texte = Trim(texte)
    if texte == "" then return nil end
    local prefixe, nom = texte:match("^(%a+):(.+)$")
    if prefixe and CONNUS[prefixe:lower()] and not nom:find("[%*%+/%(%)]") then
        local v = Jeton(prefixe, nom, ctx)
        if type(v) == "number" then return v end
        if tonumber(v) then return tonumber(v) end
    end
    return Actions.Evaluer(texte, ctx)
end
Actions.Montant = Montant

-- « a=1 ; b=2 » -> { {k, v}, ... }
local function Paires(texte)
    local out = {}
    for morceau in (tostring(texte or "") .. ";"):gmatch("([^;\n]*)[;\n]") do
        local k, v = morceau:match("^%s*(.-)%s*=%s*(.-)%s*$")
        if k and Trim(k) ~= "" then out[#out + 1] = { k = Trim(k), v = Trim(v) } end
    end
    return out
end
Actions.Paires = Paires

-- ===== Conditions ==========================================================
-- « <sujet> <op> <valeur> », clauses jointes par « && ».

local OPERATEURS = { "<=", ">=", "==", "!=", "=", "contient", "<", ">" }

local function Operande(s, ctx)
    s = Trim(s)
    -- « resultat » et « oppose » : le dernier jet et ce qu'il devait battre,
    -- memorises par le pas qui l'a lance.
    local mot = Cle(s)
    local resultat, oppose = tostring(tonumber(ctx.vars.resultat) or 0), tostring(tonumber(ctx.vars.oppose) or 0)
    if mot == "resultat" then return tonumber(resultat) end
    if mot == "oppose" then return tonumber(oppose) end
    if s:find("[%+%*/%(%)]") or s:find(" %- ") then
        local expr = s:gsub("r\195\169sultat", resultat):gsub("resultat", resultat)
                      :gsub("oppos\195\169", oppose):gsub("oppose", oppose)
        local n = Actions.Evaluer(expr, ctx)
        if n ~= nil then return n end
    end
    local prefixe, nom = s:match("^(%a+):(.+)$")
    if prefixe and CONNUS[prefixe:lower()] then
        local v = Jeton(prefixe, nom, ctx)
        if v == nil then return "" end
        return v
    end
    return tonumber(s) or s
end

local function Comparer(a, op, b)
    local na, nb = tonumber(a), tonumber(b)
    if op == "==" or op == "=" then
        if na and nb then return na == nb end
        return Cle(a) == Cle(b)
    elseif op == "!=" then
        if na and nb then return na ~= nb end
        return Cle(a) ~= Cle(b)
    elseif op == "contient" then
        return Cle(a):find(Cle(b), 1, true) ~= nil
    elseif na and nb then
        if op == "<" then return na < nb end
        if op == ">" then return na > nb end
        if op == "<=" then return na <= nb end
        if op == ">=" then return na >= nb end
    end
    return false
end

-- true / false ; nil pour une condition vide.
function Actions.Condition(expr, ctx)
    expr = Trim(expr)
    if expr == "" then return nil end
    for clause in expr:gmatch("[^&]+") do
        clause = Trim(clause)
        if clause ~= "" then
            local sujet, op, valeur
            for _, candidat in ipairs(OPERATEURS) do
                local a, b = clause:find(candidat, 1, true)
                if a then
                    sujet, op, valeur = clause:sub(1, a - 1), candidat, clause:sub(b + 1)
                    break
                end
            end
            if not op then return false end
            if not Comparer(tostring(Operande(sujet, ctx)), op, tostring(Operande(valeur, ctx))) then return false end
        end
    end
    return true
end

-- ===== L'assistant de choix (pas « compose ») ==============================
-- Le texte des questions, tel que Necronicon l'ecrit :
--   Q: Libelle | single|multi|number|text|multival | showIf: <cond> | avg: var @ onglet | require
--   - Option | pa=1 pf=2 pac=1/3 pfc=1 | cle=valeur ; cle2=valeur2

local function Cout(texte, nom)
    return tonumber((tostring(texte):match(nom .. "%s*=%s*(%-?%d+%.?%d*)"))) or 0
end

function Actions.LireQuestions(texte)
    local questions, courante = {}, nil
    for ligne in (tostring(texte or "") .. "\n"):gmatch("(.-)\n") do
        local l = Trim(ligne)
        if l:match("^[Qq]%s*:") then
            local parts = {}
            for seg in (Trim((l:gsub("^[Qq]%s*:%s*", ""))) .. "|"):gmatch("(.-)|") do parts[#parts + 1] = Trim(seg) end
            local m2 = tostring(parts[2] or ""):lower()
            local mode = (m2 == "multi" and "multi")
                or ((m2 == "number" or m2 == "num" or m2 == "nombre" or m2 == "saisie") and "number")
                or ((m2 == "text" or m2 == "texte" or m2 == "libre") and "text")
                or ((m2 == "multival" or m2 == "kv" or m2 == "listeval") and "multival")
                or ((m2 == "actors" or m2 == "acteurs") and "actors")
                or "single"
            local saisie = mode == "number" or mode == "text"
            local p3 = tostring(parts[3] or "")
            local avg = (not saisie and mode ~= "multival") and p3:match("^%s*[Aa][Vv][Gg]%s*:%s*(.+)$") or nil
            local requis, signe = false, false
            for _, seg in ipairs(parts) do
                local s = seg:lower()
                if s == "require" or s == "req" then requis = true end
                if s == "signed" or s == "signe" then signe = true end
            end
            local showIf = p3
            if saisie or mode == "multival" then
                showIf = ""
                for i = 4, #parts do
                    if parts[i]:lower():match("^%s*showif%s*:") or parts[i]:lower():match("^%s*si%s*:") then
                        showIf = parts[i] break
                    end
                end
            end
            showIf = avg and "" or Trim((showIf:gsub("^[Ss][Hh][Oo][Ww][Ii][Ff]%s*:%s*", ""):gsub("^[Ss][Ii]%s*:%s*", "")))
            courante = { id = "q" .. (#questions + 1), label = parts[1] or "", mode = mode, signe = signe,
                         showIf = showIf, requis = requis, options = {} }
            if saisie or mode == "multival" then courante.variable = Trim(p3) end
            if mode == "actors" then
                courante.variable = Trim(p3)
                for _, seg in ipairs(parts) do
                    local ex = seg:match("^[Ee][Xx][Cc][Ll][Uu][Dd][Ee]%s*:%s*(.+)$")
                    if ex then courante.excludeVar = Trim(ex) end
                    if seg:lower() == "must" or seg:lower() == "obligatoire" then courante.obligatoire = true end
                end
            end
            if avg then
                courante.avgVar = Trim((avg:gsub("@.*$", "")))
                courante.avgOnglet = Trim(avg:match("@%s*(.+)$") or "")
            end
            questions[#questions + 1] = courante
        elseif l:match("^%-") and courante then
            local corps = Trim((l:gsub("^%-%s*", "")))
            local f1, f2, f3 = corps:match("^(.-)%s*|%s*(.-)%s*|%s*(.*)$")
            if not f1 then f1, f2, f3 = corps, "", "" end
            local q = #questions
            courante.options[#courante.options + 1] = {
                id = "o" .. q .. "_" .. (#courante.options + 1),
                label = Trim(f1),
                pa = Cout(f2, "[Pp][Aa]"), pf = Cout(f2, "[Pp][Ff]"),
                -- Couts par cible : la regle vient avec le ciblage.
                pac = Cout(f2, "[Pp][Aa][Cc]"), pfc = Cout(f2, "[Pp][Ff][Cc]"),
                set = Trim(f3),
            }
        end
    end
    return questions
end

-- La valeur d'un type (« Tranchant », « Air ») dans l'onglet d'une question
-- avg: — Penetrations ou Resistances. Le template nomme « Air » en
-- penetration ce qu'il nomme « Vent » en resistance : meme type, « vent ».
local ALIAS_TYPES = { air = "vent" }
local function ValeurType(libelle, onglet, entity)
    local voulu = Cle(libelle)
    voulu = ALIAS_TYPES[voulu] or voulu
    local prefixe = Cle(onglet):find("^resi") and "resi_" or "pen_"
    for _, t in ipairs(Eq().types) do
        if Cle(t.id) == voulu or Cle(t.label) == voulu then return Total(entity, prefixe .. t.id) end
    end
    return nil
end
Actions.ValeurType = ValeurType

-- Un composeur : les questions, les reponses, et ce qu'elles valent. Sans
-- interface : la fenetre (UI/Composeur.lua) ne fait que l'appeler.
local Composeur = {}
Composeur.__index = Composeur

function Actions.Composeur(etape, ctx)
    local c = setmetatable({ etape = etape, ctx = ctx, reponses = {},
                             questions = Actions.LireQuestions(etape.questionsText) }, Composeur)
    -- Toutes les variables qu'un choix peut ecrire : on les efface avant chaque
    -- recalcul, pour qu'un choix defait ne laisse pas de trace.
    c.cles = {}
    for _, q in ipairs(c.questions) do
        if q.mode == "actors" then
            local joueurs, pnj = Actions.Cibles()
            for _, acteur in ipairs(joueurs) do
                local valeur = "j:" .. tostring(acteur.id)
                q.options[#q.options + 1] = { id = "a" .. #q.options + 1, label = acteur.nom,
                    pa = 0, pf = 0, pac = 0, pfc = 0, actorId = valeur,
                    set = tostring(q.variable) .. "=" .. valeur }
            end
            for _, acteur in ipairs(pnj) do
                local valeur = "p:" .. tostring(acteur.id)
                q.options[#q.options + 1] = { id = "a" .. #q.options + 1, label = acteur.nom,
                    pa = 0, pf = 0, pac = 0, pfc = 0, actorId = valeur,
                    set = tostring(q.variable) .. "=" .. valeur }
            end
        end
        if q.avgVar and q.avgVar ~= "" then c.cles[q.avgVar] = true end
        if q.variable and q.variable ~= "" then c.cles[q.variable] = true end
        for _, o in ipairs(q.options) do
            for paire in o.set:gmatch("[^;\n]+") do
                local k = paire:match("^%s*(.-)%s*=")
                if k and Trim(k) ~= "" then c.cles[Trim(k)] = true end
            end
        end
    end
    c:Deriver()
    return c
end

-- Une valeur d'option : formule de fiche ou calcul -> nombre ; texte -> texte.
function Composeur:Valeur(v)
    v = tostring(v or "")
    if v:find("%[%[") then return Actions.Evaluer(v, self.ctx) end
    local s = Trim(Actions.Substituer(v, self.ctx, "0"))
    local n = tonumber(s)
    if n then return n end
    if s:find("[%+%*/]") then
        local r = Arithmetique(s)
        if r then return r end
    end
    return s
end

-- Recalcule les variables et les couts depuis TOUTES les reponses.
function Composeur:Deriver()
    local V = self.ctx.vars
    for k in pairs(self.cles) do V[k] = nil end
    V._coutPAParCible = nil
    local pa, pf, pac, pfc = 0, 0, 0, 0
    local moyennes = {}
    for _, q in ipairs(self.questions) do
        local r = self.reponses[q.id]
        local cumul = {}
        if q.avgVar and q.mode == "multi" and type(r) == "table" then
            local m = moyennes[q.avgVar] or { somme = 0, n = 0 }
            for _, o in ipairs(q.options) do
                if r[o.id] then
                    local v = ValeurType(o.label, q.avgOnglet, self.ctx.entity)
                    if v then m.somme, m.n = m.somme + v, m.n + 1 end
                end
            end
            moyennes[q.avgVar] = m
        end
        local function Prendre(o)
            pa, pf, pac, pfc = pa + o.pa, pf + o.pf, pac + o.pac, pfc + o.pfc
            if o.paParCible then V._coutPAParCible = true end
            for paire in o.set:gmatch("[^;\n]+") do
                local k, v = paire:match("^%s*(.-)%s*=%s*(.-)%s*$")
                if k and k ~= "" then
                    if q.mode == "multi" then
                        cumul[k] = cumul[k] or {}
                        cumul[k][#cumul[k] + 1] = Trim(Actions.Substituer(v, self.ctx))
                    else
                        V[k] = self:Valeur(v)
                    end
                end
            end
        end
        local variable = q.variable or ""
        if q.mode == "number" then
            if tonumber(r) and variable ~= "" then V[variable] = tonumber(r) end
        elseif q.mode == "text" then
            if type(r) == "string" and Trim(r) ~= "" and variable ~= "" then V[variable] = r end
        elseif q.mode == "multi" and type(r) == "table" then
            for _, o in ipairs(q.options) do if r[o.id] then Prendre(o) end end
            for k, liste in pairs(cumul) do V[k] = table.concat(liste, ", ") end
        elseif type(r) == "string" then
            for _, o in ipairs(q.options) do if o.id == r then Prendre(o) end end
        end
    end
    for var, m in pairs(moyennes) do
        V[var] = m.n > 0 and (math.floor((m.somme / m.n) * 1000 + 0.5) / 1000) or 0
    end
    V._coutPA, V._coutPF, V._coutPAC, V._coutPFC = pa, pf, pac, pfc
    return pa, pf
end

-- Une option de type dont la valeur est nulle n'est pas proposee : on ne
-- choisit pas une penetration ou l'on n'a rien.
function Composeur:Proposee(q, o)
    if not q.avgVar then return true end
    local v = ValeurType(o.label, q.avgOnglet, self.ctx.entity)
    return v == nil or v > 0
end

function Composeur:Options(q)
    local out = {}
    for _, o in ipairs(q.options) do
        local exclue = q.mode == "actors" and q.excludeVar and o.actorId == self.ctx.vars[q.excludeVar]
        if not exclue and self:Proposee(q, o) then out[#out + 1] = o end
    end
    return out
end

-- Les questions a poser, dans l'ordre : leur showIf est vrai, et une question
-- de types dont aucun n'a de valeur est sautee.
function Composeur:Visibles()
    self:Deriver()
    local out = {}
    for _, q in ipairs(self.questions) do
        local ok = q.showIf == "" or Actions.Condition(q.showIf, self.ctx) == true
        if ok and q.avgVar and #self:Options(q) == 0 then ok = false end
        if ok then out[#out + 1] = q end
    end
    return out
end

function Composeur:Repondre(q, optionId)
    -- Un second clic sur le meme choix le defait.
    self.reponses[q.id] = (self.reponses[q.id] ~= optionId) and optionId or nil
    self:Deriver()
end

function Composeur:Cocher(q, optionId, coche)
    self.reponses[q.id] = type(self.reponses[q.id]) == "table" and self.reponses[q.id] or {}
    self.reponses[q.id][optionId] = coche and true or nil
    if not next(self.reponses[q.id]) then self.reponses[q.id] = nil end
    self:Deriver()
end

function Composeur:Saisir(q, texte)
    self.reponses[q.id] = Trim(texte) ~= "" and texte or nil
    self:Deriver()
end

function Composeur:EstChoisie(q, optionId)
    local r = self.reponses[q.id]
    if type(r) == "table" then return r[optionId] == true end
    return r == optionId
end

-- Les libelles retenus, pour le recapitulatif.
function Composeur:Choix(q)
    local r, out = self.reponses[q.id], {}
    if q.mode == "number" or q.mode == "text" then return type(r) == "string" and Trim(r) or "" end
    for _, o in ipairs(q.options) do
        if (type(r) == "table" and r[o.id]) or r == o.id then out[#out + 1] = o.label end
    end
    return table.concat(out, ", ")
end

-- Au moins une reponse parmi les questions « require » visibles (les types
-- d'une attaque : il en faut un).
function Composeur:Requis()
    local exige, repondu = false, false
    for _, q in ipairs(self:Visibles()) do
        if q.requis then
            exige = true
            if self.reponses[q.id] ~= nil then repondu = true end
        end
    end
    return (not exige) or repondu
end

-- PA et fatigue disponibles chez celui qui agit.
function Actions.Disponible(entity, defense)
    local pf = LCM.Entities.Gauge(entity, "fatigue")
    local pa = LCM.Combat and LCM.Combat.PADisponibles(entity)
    if defense then
        local jauge = LCM.Entities.Gauge(entity, "pa")
        pa = jauge and jauge.current
    end
    return pa, pf and pf.current
end

-- Necronicon ne grise une option que sur les PA ; la fatigue peut passer dans
-- le rouge pendant qu'on compose, c'est a la declaration qu'elle bloque.
function Composeur:Abordable(q, o)
    if self:EstChoisie(q, o.id) then return true end
    local dispo = Actions.Disponible(self.ctx.entity, self.ctx.recu ~= nil)
    if dispo == nil then return true end
    local engage = 0
    for _, qq in ipairs(self.questions) do
        local r = self.reponses[qq.id]
        for _, oo in ipairs(qq.options) do
            local pris = (type(r) == "table" and r[oo.id]) or r == oo.id
            -- Un choix unique remplace celui de la meme question.
            if pris and not (qq.id == q.id and q.mode ~= "multi") then engage = engage + oo.pa end
        end
    end
    return engage + o.pa <= dispo + 0.005
end

-- Ce qui empeche de declarer, ou nil.
function Composeur:Blocage()
    if not self:Requis() then return "Il faut au moins un type d'attaque." end
    for _, q in ipairs(self:Visibles()) do
        if q.obligatoire and self.reponses[q.id] == nil then
            return "Il faut choisir « " .. tostring(q.label) .. " »."
        end
    end
    local pa, pf = self:Deriver()
    local dpa, dpf = Actions.Disponible(self.ctx.entity, self.ctx.recu ~= nil)
    if dpa and pa > dpa + 0.005 then return "PA insuffisants pour cette action." end
    if dpf and pf > dpf + 0.005 then return "PF insuffisants pour cette action." end
    return nil
end

-- ===== Les jeux de choix ===================================================
-- Repris de Necronicon (SaveActionComposerTemplate) : un jeu de reponses
-- enregistre pour une action, qu'on recharge d'un clic (« Coup de bouclier »
-- au lieu de huit questions). Donnee du JOUEUR, rangee avec son personnage.
-- Ecart : les reponses sont retenues par LIBELLE de question et d'option, pas
-- par numero — un jeu survit ainsi a une retouche de l'action au compendium.
-- Une reponse qui ne correspond plus a rien est ignoree au chargement.

local function Jeux(resolutionId, ecrire)
    LCM.EnsureDatabase()
    local db = LCM.charDb
    if not ecrire then
        return type(db.jeuxDeChoix) == "table" and type(db.jeuxDeChoix[resolutionId]) == "table"
            and db.jeuxDeChoix[resolutionId] or {}
    end
    db.jeuxDeChoix = type(db.jeuxDeChoix) == "table" and db.jeuxDeChoix or {}
    db.jeuxDeChoix[resolutionId] = type(db.jeuxDeChoix[resolutionId]) == "table" and db.jeuxDeChoix[resolutionId] or {}
    return db.jeuxDeChoix[resolutionId]
end

-- Une liste devenue vide disparait de la sauvegarde.
local function RangerJeux(resolutionId)
    local db = LCM.charDb
    if type(db.jeuxDeChoix) ~= "table" then return end
    if type(db.jeuxDeChoix[resolutionId]) == "table" and #db.jeuxDeChoix[resolutionId] == 0 then
        db.jeuxDeChoix[resolutionId] = nil
    end
    if not next(db.jeuxDeChoix) then db.jeuxDeChoix = nil end
end

function Actions.JeuxDeChoix(resolutionId) return Jeux(tostring(resolutionId or "")) end

function Actions.EnregistrerJeu(resolutionId, nom, composeur)
    local reponses = {}
    for _, q in ipairs(composeur.questions) do
        local r = composeur.reponses[q.id]
        if type(r) == "table" then
            local labels = {}
            for _, o in ipairs(q.options) do if r[o.id] then labels[#labels + 1] = o.label end end
            reponses[q.label] = labels
        elseif r ~= nil then
            local label = r
            for _, o in ipairs(q.options) do if o.id == r then label = o.label end end
            reponses[q.label] = (q.mode == "number" or q.mode == "text") and { saisie = r } or label
        end
    end
    local pa, pf = composeur:Deriver()
    local liste = Jeux(tostring(resolutionId), true)
    nom = Trim(nom)
    liste[#liste + 1] = { nom = nom ~= "" and nom or ("Jeu " .. (#liste + 1)), reponses = reponses, pa = pa, pf = pf }
    return liste[#liste]
end

function Actions.ChargerJeu(composeur, jeu)
    composeur.reponses = {}
    for _, q in ipairs(composeur.questions) do
        local r = jeu.reponses and jeu.reponses[q.label]
        if type(r) == "table" and r.saisie ~= nil then
            composeur.reponses[q.id] = r.saisie
        elseif type(r) == "table" then
            local coche = {}
            for _, label in ipairs(r) do
                for _, o in ipairs(q.options) do if o.label == label then coche[o.id] = true end end
            end
            if next(coche) then composeur.reponses[q.id] = coche end
        elseif r ~= nil then
            for _, o in ipairs(q.options) do if o.label == r then composeur.reponses[q.id] = o.id end end
        end
    end
    composeur:Deriver()
end

function Actions.RenommerJeu(resolutionId, index, nom)
    local jeu = Jeux(tostring(resolutionId))[index]
    if jeu and Trim(nom) ~= "" then jeu.nom = Trim(nom) return true end
    return false
end

function Actions.SupprimerJeu(resolutionId, index)
    local liste = Jeux(tostring(resolutionId))
    if not liste[index] then return false end
    table.remove(liste, index)
    RangerJeux(tostring(resolutionId))
    return true
end

function Actions.DeplacerJeu(resolutionId, index, sens)
    local liste = Jeux(tostring(resolutionId))
    local cible = index + ((tonumber(sens) or 0) < 0 and -1 or 1)
    if not liste[index] or not liste[cible] then return false end
    liste[index], liste[cible] = liste[cible], liste[index]
    return true
end

-- ===== Calculateurs (pas « compute ») ======================================

-- Les libelles d'une valeur recue sous forme de liste (« Tranchant, Feu »).
-- « ? » et « - » ne sont pas des types : un groupe que l'attaquant n'a pas
-- choisi arrive ainsi.
function Actions.ListeRecue(ctx, tag)
    local v = Jeton("recu", tag, ctx)
    local out = {}
    for morceau in tostring(v or ""):gmatch("[^,;/|\r\n]+") do
        morceau = Trim(morceau)
        if morceau ~= "" and morceau ~= "-" and morceau ~= "?" then out[#out + 1] = morceau end
    end
    return out
end

local function Agreger(op, nombres)
    local r = 0
    if op == "valeur" then r = nombres[1] or 0
    elseif op == "somme" then for _, n in ipairs(nombres) do r = r + n end
    elseif op == "moyenne" then
        if #nombres > 0 then for _, n in ipairs(nombres) do r = r + n end r = r / #nombres end
    elseif op == "produit" then
        r = #nombres > 0 and 1 or 0
        for _, n in ipairs(nombres) do r = r * n end
    elseif op == "min" then for i, n in ipairs(nombres) do r = (i == 1) and n or math.min(r, n) end
    elseif op == "max" then for i, n in ipairs(nombres) do r = (i == 1) and n or math.max(r, n) end
    elseif op == "soustraction" then
        r = nombres[1] or 0
        for i = 2, #nombres do r = r - nombres[i] end
    elseif op == "division" then
        r = nombres[1] or 0
        for i = 2, #nombres do if nombres[i] ~= 0 then r = r / nombres[i] end end
    elseif op == "arrondi" then r = math.floor((nombres[1] or 0) + 0.5)
    end
    return r
end

-- Le calculateur d'une etape : par son libelle (« Degats Attaque »), seule
-- reference portable — les identifiants de Necronicon ne voyagent pas.
local function Calculateur(etape)
    local nom = Cle(etape.aggregatorName)
    for _, c in ipairs(LCM.Calculateurs.list or {}) do
        if nom ~= "" and Cle(c.label) == nom then return c end
    end
    return LCM.Calculateurs.Get(etape.aggregator)
end

function Actions.Calculer(etape, ctx)
    local calc = Calculateur(etape)
    if not calc then return nil, "calculateur introuvable : " .. tostring(etape.aggregatorName or etape.aggregator) end
    local injections = {}
    for _, b in ipairs(type(etape.injections) == "table" and etape.injections or {}) do
        if Trim(b.name) ~= "" then injections[Trim(b.name)] = Montant(b.source, ctx) end
    end
    for _, p in ipairs(Paires(etape.inject)) do injections[p.k] = Montant(p.v, ctx) end

    local avant = ctx.inject
    ctx.inject = injections
    local resultat
    if Trim(calc.formule) ~= "" then
        resultat = Actions.Evaluer((calc.formule:gsub("[iI][nN][jJ][eE][cC][tT]:([%w_%-]+)", function(nom)
            return tostring(tonumber(injections[nom]) or 0)
        end)), ctx)
    else
        local lignes, dernier, sortie = {}, nil, nil
        for _, ligne in ipairs(calc.lignes) do
            local nombres = {}
            for _, op in ipairs(type(ligne.operands) == "table" and ligne.operands or {}) do
                local v
                if op.kind == "injection" then v = injections[Trim(op.ref)]
                elseif op.kind == "ligne" then v = lignes[Trim(op.ref)]
                elseif op.kind == "nombre" then v = op.value
                elseif op.kind == "champ" then v = Actions.Evaluer(op.ref, ctx)
                elseif op.kind == "expr" then v = Actions.Evaluer(op.value, ctx)
                elseif op.kind == "recu" then
                    -- Une valeur par type que l'attaquant a declare (« Type
                    -- Physique » = « Tranchant, Perforant ») : celle de la fiche
                    -- de la cible, dans l'onglet que l'operande nomme. Sans
                    -- onglet, les Resistances : c'est un calcul de reduction,
                    -- et un meme nom existe en Penetrations.
                    local onglet = Trim(op.value) ~= "" and op.value or "Résistances"
                    for _, nom in ipairs(Actions.ListeRecue(ctx, op.ref)) do
                        local r = ValeurType(nom, onglet, ctx.entity)
                        if r == nil then Noter(ctx, "type reçu : " .. nom) end
                        nombres[#nombres + 1] = tonumber(r) or 0
                    end
                    v = false
                else
                    -- « selection » : une fenetre a cocher, que les resolutions
                    -- jouees ici n'utilisent pas encore.
                    Noter(ctx, "calcul : operande « " .. tostring(op.kind) .. " »")
                end
                if v ~= false then nombres[#nombres + 1] = tonumber(v) or 0 end
            end
            local r = Agreger(ligne.op == "selection" and (ligne.subOp or "moyenne") or ligne.op, nombres)
            lignes[Trim(ligne.id)] = r
            dernier = r
            if ligne.sortie == true then sortie = r end
        end
        resultat = sortie ~= nil and sortie or dernier
    end
    ctx.inject = avant
    return tonumber(resultat)
end


-- ===== Jauges (pas « pay » et « grant ») ===================================

-- Le tag d'une jauge -> le champ de la fiche. #sante n'est pas une jauge : ce
-- sont les zones du corps, qu'on n'atteint que par la repartition des degats.
-- #armure n'est pas une jauge qu'on debite : ce sont les pieces d'armure
-- portees, qu'on n'atteint, comme #sante, que par la repartition.
local TAGS = { pa = "pa", fatigue = "fatigue", pf = "fatigue", bouclier = "armure", boucliers = "armure" }
Actions.TAGS = TAGS

-- Debite (montant positif) ou credite (negatif) une jauge. true si trouvee.
function Actions.Payer(entity, tag, montant, defense)
    local champ = TAGS[Cle(tostring(tag or ""):gsub("#", ""))]
    montant = tonumber(montant) or 0
    if not champ or montant == 0 then return montant == 0 end
    local jauge = LCM.Entities.Gauge(entity, champ)
    if not jauge then return false end
    if champ == "pa" and montant > 0 then
        if defense then return LCM.Combat.PayerPADefense(entity, montant) end
        local disponibles = Actions.Disponible(entity)
        if not disponibles or montant > disponibles then return false end
    end
    return LCM.Entities.SetGauge(entity, champ, jauge.current - montant)
end

-- ===== Annonces ============================================================
-- Les annonces d'une resolution (un jet, « X declare : Attaque ») vont la ou
-- le groupe les voit : raid, sinon groupe, sinon emote. Jamais le canal de
-- jets choisi sur la fiche, qui peut etre « Local » (regle de Necronicon,
-- SendActionResolutionChat). Pendant une declaration, elles attendent que les
-- cibles soient choisies : une declaration annulee n'a rien annonce.

function Actions.Annoncer(texte, ctx)
    if ctx and ctx.annonces then
        ctx.annonces[#ctx.annonces + 1] = texte
        return
    end
    local canal = (IsInRaid and IsInRaid()) and "RAID" or ((IsInGroup and IsInGroup()) and "PARTY") or "EMOTE"
    if SendChatMessage then
        SendChatMessage("[Contes] " .. LCM.SansCouleur(texte), canal)
    else
        LCM.Info(texte)
    end
end

-- Une emote (ou une reponse) dans le chat : decoupee en morceaux de 250
-- octets au plus sur les espaces (limite de SendChatMessage), comme
-- SendChatChunked de Necronicon. Raid sans raid : groupe, sinon « dire ».
-- Necronicon espacait les morceaux de 0,8 s ; sans minuterie, ils partent
-- d'un coup.
function Actions.DireEnChat(texte, canal)
    texte = Trim(tostring(texte or "")):gsub("%s+", " ")
    if texte == "" or not SendChatMessage then return 0 end
    canal = tostring(canal or "EMOTE"):upper()
    if canal == "RAID" then
        canal = (IsInRaid and IsInRaid()) and "RAID" or ((IsInGroup and IsInGroup()) and "PARTY" or "SAY")
    elseif canal == "PARTY" then
        canal = (IsInGroup and IsInGroup()) and "PARTY" or "SAY"
    end
    local morceaux, courant = {}, ""
    for mot in texte:gmatch("%S+") do
        while #mot > 250 do
            if courant ~= "" then morceaux[#morceaux + 1] = courant courant = "" end
            morceaux[#morceaux + 1] = mot:sub(1, 250)
            mot = mot:sub(251)
        end
        local candidat = courant == "" and mot or (courant .. " " .. mot)
        if #candidat > 250 then morceaux[#morceaux + 1] = courant courant = mot else courant = candidat end
    end
    if courant ~= "" then morceaux[#morceaux + 1] = courant end
    local i = 0
    local function Suivant()
        i = i + 1
        if not morceaux[i] then return end
        pcall(SendChatMessage, morceaux[i], canal)
        if morceaux[i + 1] then
            if C_Timer and C_Timer.After then C_Timer.After(0.8, Suivant) else Suivant() end
        end
    end
    Suivant()
    return #morceaux
end

-- L'emote qui accompagne une declaration d'action a une presentation propre
-- au canal choisi. En groupe/raid, chaque morceau reste entierement encadre
-- par < >. En emote, les morceaux intermediaires portent (...) afin que la
-- continuation reste explicite meme si d'autres messages s'intercalent.
function Actions.DireEmoteAction(texte, canal)
    texte = Trim(tostring(texte or "")):gsub("%s+", " ")
    if texte == "" or not SendChatMessage then return 0 end

    canal = tostring(canal or "EMOTE"):upper()
    if canal == "RAID" and not (IsInRaid and IsInRaid()) then
        canal = (IsInGroup and IsInGroup()) and "PARTY" or "EMOTE"
    elseif canal == "PARTY" and not (IsInGroup and IsInGroup()) then
        canal = "EMOTE"
    elseif canal ~= "RAID" and canal ~= "PARTY" then
        canal = "EMOTE"
    end

    local encadre = canal == "RAID" or canal == "PARTY"
    -- 250 octets est la marge deja employee par l'addon. Les decorations les
    -- plus longues occupent douze octets : 238 garantit donc que chaque
    -- message final reste sous la limite.
    local limite = encadre and 246 or 238
    local morceaux, courant = {}, ""
    for mot in texte:gmatch("%S+") do
        while #mot > limite do
            if courant ~= "" then morceaux[#morceaux + 1], courant = courant, "" end
            morceaux[#morceaux + 1] = mot:sub(1, limite)
            mot = mot:sub(limite + 1)
        end
        if mot ~= "" then
            local candidat = courant == "" and mot or (courant .. " " .. mot)
            if #candidat > limite then
                morceaux[#morceaux + 1], courant = courant, mot
            else
                courant = candidat
            end
        end
    end
    if courant ~= "" then morceaux[#morceaux + 1] = courant end

    local total = #morceaux
    for i, morceau in ipairs(morceaux) do
        if encadre then
            morceaux[i] = "< " .. morceau .. " >"
        elseif total > 1 then
            if i > 1 then morceau = "(...) " .. morceau end
            if i < total then morceau = morceau .. " (...)" end
            morceaux[i] = morceau
        end
    end

    local i = 0
    local function Suivant()
        i = i + 1
        if not morceaux[i] then return end
        pcall(SendChatMessage, morceaux[i], canal)
        if morceaux[i + 1] then
            if C_Timer and C_Timer.After then C_Timer.After(0.8, Suivant) else Suivant() end
        end
    end
    Suivant()
    return total
end

-- ===== Jets (pas « roll ») =================================================

-- Les « jets complets » que les resolutions designent par leur case dans les
-- fenetres de Necronicon. Les deux derniers sont les jets « inadaptes ».
local JETS_FICHE = {
    inventory_fiche_36 = { champ = "adresse" },
    inventory_fiche_38 = { champ = "esprit" },
    fiche_stat_18 = { champ = "adresse", inadapte = true },
    fiche_stat_19 = { champ = "esprit", inadapte = true },
}

-- Un jet inadapte : le de de la primaire, et la primaire au taux « Malus
-- inadapte ». Pas d'apport ni de bonus porte : le template n'en met pas.
local function JetInadapte(entity, champ)
    local field = LCM.Schema.Field(champ)
    local des = field and field.dice or {}
    local de = LCM.Roll.Des(des.min or 0, des.max or 0)
    local part = math.floor(LCM.Formules.Primaire(entity, champ) * Eq().malusInadapte)
    local nom = field.label .. " inadapté"
    return { total = de + part, label = nom,
             texte = string.format("%s : %d  (dé %d, %s × %s %+d)", nom, de + part, de, field.label,
                 tostring(Eq().malusInadapte), part) }
end

-- ===== Les mecaniques de defense ===========================================

-- Un nombre lisible : « 2 » et non « 2.0 », « 1,5 » et non « 1.5 ».
local function Nombre(n)
    n = tonumber(n) or 0
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return (string.format("%.1f", n):gsub("%.", ","))
end

-- La mecanique de l'action qu'on est en train d'encaisser, s'il y en a une.
-- `ctx.paquet` n'existe que dans une RECEPTION (voir Actions.Resoudre) : un
-- jet d'attaque ne passe donc jamais par ici.
function Actions.MecaniqueRecue(ctx)
    local paquet = ctx and (ctx.paquet or (ctx.recu and ctx.recu.paquet))
    if not paquet then return nil end
    return Mecanique(paquet.n)
end

-- Le bonus que les mecaniques de defense ajoutent a ce jet, et le resume qui
-- l'explique. Zero quand rien ne s'applique — la plupart des actions n'ont
-- pas de defense dediee, et c'est voulu.
function Actions.BonusDefense(ctx)
    local m = Actions.MecaniqueRecue(ctx)
    if not (m and LCM.Defenses) then return 0, nil end
    local bonus = LCM.Defenses.BonusRand(ctx.entity, m.id)
    if bonus == 0 then return 0, nil end
    return bonus, (LCM.Defenses.Resume(ctx.entity, m.id))
end

-- Le supplement que les expertises de parade apportent a ce jet. Comme les
-- defenses, il ne vaut que dans une RECEPTION : parer, c'est subir. Et il
-- depend de la statistique opposee, d'ou le champ.
function Actions.BonusParade(ctx, champ)
    if not (champ and LCM.Expertises) then return 0, nil end
    if not (ctx and (ctx.paquet or (ctx.recu and ctx.recu.paquet))) then return 0, nil end
    local bonus, detail = LCM.Expertises.BonusParade(ctx.entity, champ)
    if bonus == 0 then return 0, nil end
    local bouts = {}
    for _, d in ipairs(detail) do
        bouts[#bouts + 1] = string.format("%s %d", d.label, d.points)
    end
    return bonus, table.concat(bouts, ", ")
end

-- Le jet d'une formule de candidat : « jet:Nom », un jet complet de fiche, ou
-- une formule. Retourne le total et la ligne a annoncer (ou nil).
--
-- C'est le passage oblige de tous les jets d'une resolution : c'est donc ici,
-- et nulle part ailleurs, que s'ajoutent les mecaniques de defense et les
-- expertises de parade.
function Actions.JetFormule(formule, ctx)
    local total, texte, champ, resultat = Actions.JetFormuleBrut(formule, ctx)
    if not total then return total, texte end

    -- Les expertises de parade entrent DANS le decompte du jet, arrondies vers
    -- le bas : un demi-point qu'on ne peut pas lire sur un de n'a pas a
    -- gonfler un total. Accolees apres coup, elles laissaient un total qui ne
    -- les comptait pas (11 octobre 2026).
    local parade = math.floor(Actions.BonusParade(ctx, champ))
    if parade ~= 0 then
        total = total + parade
        if resultat then
            resultat.expertises = (resultat.expertises or 0) + parade
            resultat.total = resultat.total + parade
            texte = LCM.Roll.Describe(resultat)
        end
    end

    -- La defense, elle, garde sa mention a part : elle dit CONTRE QUOI elle
    -- vaut, et ce detail n'entre pas dans un decompte en colonnes.
    local bonus, resume = Actions.BonusDefense(ctx)
    if bonus ~= 0 then
        total = total + bonus
        if texte then
            texte = string.format("%s  +%s (%s)", texte, Nombre(bonus), resume or "défense")
        end
    end
    return total, texte
end

-- Rend aussi, en troisieme valeur, le CHAMP sur lequel le jet a porte : les
-- parades en dependent (l'Equilibre porte l'Adresse, le Cosmique l'Esprit).
-- L'information etait la, elle se perdait.
function Actions.JetFormuleBrut(formule, ctx)
    formule = Trim(formule)
    local nom = formule:match("^{?%s*[jJ][eE][tT]:%s*(.-)%s*}?$")
    if nom and nom ~= "" then
        local r = Actions.Jet(nom, ctx.entity)
        if r then
            local field = ChampParLibelle(nom, "roll")
            return r.total, LCM.Roll.Describe(r), field and field.id, r
        end
        Noter(ctx, "jet:" .. nom)
        return 0
    end
    local id = formule:match("%[%[0%.fiche%.[^%]]-([%w_]+)%.[rR]andComplete%]%]")
    local jet = id and JETS_FICHE[id]
    if jet then
        if jet.inadapte then
            local r = JetInadapte(ctx.entity, jet.champ)
            return r.total, r.texte, jet.champ
        end
        local r = LCM.Roll.Field(ctx.entity, jet.champ)
        return r.total, LCM.Roll.Describe(r), jet.champ, r
    end
    if id then Noter(ctx, "jet de fiche : " .. id) return 0 end
    return tonumber(Actions.Evaluer(formule, ctx)) or 0
end

-- La plage d'un jet, a cote du bouton qui le lance : « ( 0-15 +4 ) ».
function Actions.Plage(formule, entity)
    formule = Trim(formule)
    local id = formule:match("%[%[0%.fiche%.[^%]]-([%w_]+)%.[rR]andComplete%]%]")
    local jet = id and JETS_FICHE[id]
    local champ = jet and jet.champ
    if not champ then
        local nom = formule:match("[jJ][eE][tT]:%s*(.-)%s*}?$")
        local field = nom and ChampParLibelle(nom, "roll")
        champ = field and field.id
    end
    local field = champ and LCM.Schema.Field(champ)
    if not field or not field.dice then return "" end
    local fixe
    if jet and jet.inadapte then
        fixe = math.floor(LCM.Formules.Primaire(entity, champ) * Eq().malusInadapte)
    else
        fixe = (tonumber(LCM.Entities.Get_Value(entity, champ)) or 0) + LCM.Formules.Apport(entity, champ)
            + LCM.Effets.Bonus(entity, champ)
    end
    return string.format("  |cff9fbfdf( %d-%d %+d )|r", field.dice.min or 0, field.dice.max or 0, fixe)
end

-- ===== Le moteur ===========================================================

-- Une liste d'etapes contient-elle une declaration (branches comprises) ?
local function ContientDeclaration(etapes, profondeur)
    profondeur = profondeur or 0
    if type(etapes) ~= "table" or profondeur > 6 then return false end
    for _, etape in ipairs(etapes) do
        if type(etape) == "table" then
            if etape.type == "declare" then return true end
            for _, valeur in pairs(etape) do
                if type(valeur) == "table" and ContientDeclaration(valeur, profondeur + 1) then return true end
                if type(valeur) == "table" and ContientDeclaration(valeur.steps, profondeur + 1) then return true end
            end
        end
    end
    return false
end

local function Journal(ctx, texte) ctx.journal[#ctx.journal + 1] = texte end

-- Arrete la resolution, et dit pourquoi. Chez celui qui agit, rien n'est
-- debite : les couts attendent la declaration.
local function Arreter(ctx, raison)
    ctx.arretee = raison
    Journal(ctx, "Arrêt : " .. raison)
    LCM.Alerte(string.format("%s : %s%s", ctx.nom, raison, ctx.differe and " Rien n'a été débité." or ""))
    if ctx.onFin then ctx.onFin(ctx) end
    if ctx.recu and Actions.onResolu then Actions.onResolu(ctx) end
end

local function Etape(id, liste)
    for _, etape in ipairs(liste or {}) do
        if type(etape) == "table" and tostring(etape.id) == tostring(id) then return etape end
    end
end

-- Le debit differe : applique a la declaration (ou en fin de feuille sans
-- declaration).
local function Regler(ctx)
    if not ctx.dettes then return true end
    local totalPA = 0
    for _, d in ipairs(ctx.dettes) do
        if tostring(d.tag or ""):gsub("#", "") == "pa" then totalPA = totalPA + (tonumber(d.montant) or 0) end
    end
    local disponibles = Actions.Disponible(ctx.entity, ctx.recu ~= nil)
    if totalPA > 0 and disponibles and totalPA > disponibles then return false end
    for _, d in ipairs(ctx.dettes) do
        local ok = Actions.Payer(ctx.entity, d.tag, d.montant, ctx.recu ~= nil)
        Journal(ctx, string.format("%s %s : %s%s%s", d.montant < 0 and "Remboursement" or "Débit",
            tostring(d.tag), d.montant < 0 and "+" or "-", tostring(math.abs(d.montant)),
            ok and "" or " (jauge introuvable)"))
    end
    ctx.dettes = nil
    return true
end

local Pas = {}
-- Rendue publique pour le banc : jouer UN pas d'une resolution sans monter
-- toute la machinerie de reception. Rien d'autre ne s'en sert.
Actions.Pas = Pas

function Pas.message(etape, ctx, suite)
    local texte = Trim(Actions.Substituer(etape.message, ctx))
    if texte == "" then return suite() end
    if texte:find("[Cc]ritique") then ctx.vars._critique = true end
    Journal(ctx, "Message : " .. texte:gsub("\n", " / "))
    if Actions.onMessage then return Actions.onMessage(texte, ctx, suite) end
    LCM.Info(texte)
    return suite()
end

function Pas.call(etape, ctx, suite)
    if (ctx.profondeur or 0) >= 12 then
        Journal(ctx, "Aller à : boucle trop profonde, ignoré")
        return suite()
    end
    local feuilleId = tostring(etape.callTarget or ""):match("^sheet:(.+)$")
    ctx.profondeur = (ctx.profondeur or 0) + 1
    local function retour() ctx.profondeur = ctx.profondeur - 1 suite() end
    if feuilleId then
        for _, f in ipairs(ctx.feuilles) do
            if tostring(f.id) == feuilleId then return Actions.Etapes(f.etapes, ctx, retour) end
        end
        ctx.profondeur = ctx.profondeur - 1
        Journal(ctx, "Aller à : feuille introuvable")
        return suite()
    end
    local cible = Etape(etape.callTarget, ctx.etapes)
    if not cible then
        ctx.profondeur = ctx.profondeur - 1
        Journal(ctx, "Aller à : étape introuvable")
        return suite()
    end
    return Actions.Etape(cible, ctx, retour)
end

-- Si / Sinon si / Sinon : la premiere branche dont la condition est vraie
-- (une condition vide l'est toujours) joue ses etapes, puis on reprend.
function Pas.condition(etape, ctx, suite)
    for _, branche in ipairs(type(etape.branches) == "table" and etape.branches or {}) do
        if type(branche) == "table" then
            local vraie = branche.kind == "else" or Trim(branche.condition) == ""
                or Actions.Condition(branche.condition, ctx) == true
            if vraie then
                Journal(ctx, "Condition -> " .. (Trim(branche.condition) ~= "" and branche.condition or "sinon"))
                return Actions.Etapes(type(branche.steps) == "table" and branche.steps or {}, ctx, suite)
            end
        end
    end
    return suite()
end

function Pas.compose(etape, ctx, suite)
    local composeur = Actions.Composeur(etape, ctx)
    ctx.composeur = composeur
    if not Actions.onComposer then return Arreter(ctx, "aucune fenêtre pour composer l'action.") end
    -- La fenetre rappelle `valider` (« Declarer mon action ») ou `annuler`.
    Actions.onComposer(composeur, function() composeur:Deriver() suite() end,
        function() Arreter(ctx, "action annulée.") end)
end

function Pas.compute(etape, ctx, suite)
    local valeur, erreur = Actions.Calculer(etape, ctx)
    if valeur == nil then return Arreter(ctx, erreur or "calcul impossible.") end
    -- Les points de bouclier sont entiers, y compris pour les anciennes
    -- actions du compendium qui n'ont pas encore le drapeau `arrondir`.
    if etape.arrondir == true or Cle(etape.label) == Cle("Bouclier généré") then
        valeur = math.max(0, math.floor((tonumber(valeur) or 0) + 0.5))
    end
    if Trim(etape.out) ~= "" then ctx.vars[Trim(etape.out)] = valeur end
    Journal(ctx, string.format("%s = %s", Trim(etape.label) ~= "" and etape.label or "Calcul", tostring(valeur)))
    return suite()
end

function Pas.pay(etape, ctx, suite)
    local montant = tonumber(Montant(etape.amount, ctx)) or 0
    if ctx.dettes then
        if montant ~= 0 then ctx.dettes[#ctx.dettes + 1] = { tag = etape.tag, montant = montant } end
        Journal(ctx, string.format("Débit différé %s : %s", tostring(etape.tag), tostring(montant)))
        return suite()
    end
    local ok = Actions.Payer(ctx.entity, etape.tag, montant, ctx.recu ~= nil)
    if not ok and montant > 0 and tostring(etape.tag or ""):gsub("#", "") == "pa" then
        return Arreter(ctx, "PA indisponibles pendant ce round.")
    end
    Journal(ctx, string.format("%s %s : %s%s", montant < 0 and "Remboursement" or "Débit", tostring(etape.tag),
        tostring(math.abs(montant)), ok and "" or " (jauge introuvable)"))
    return suite()
end

-- Plusieurs jauges d'un coup, depuis un tag recu : « #pa=-2 ; #fatigue=+5 ».
-- Le signe est celui de la valeur ; `pct` : un pourcentage du maximum.
function Pas.paymulti(etape, ctx, suite)
    local source = Jeton("recu", Trim(etape.fromTag), ctx)
    for _, p in ipairs(Paires(type(source) == "string" and source or "")) do
        local brut = tonumber(p.v) or 0
        if brut ~= 0 then
            local delta = brut
            if etape.pct == true then
                local champ = TAGS[Cle(p.k:gsub("#", ""))]
                local j = champ and LCM.Entities.Gauge(ctx.entity, champ)
                delta = j and brut / 100 * j.max or 0
            end
            local ok = Actions.Payer(ctx.entity, p.k, -delta)
            Journal(ctx, string.format("Jauge %s : %+d%s", p.k, delta, ok and "" or " (jauge introuvable)"))
        end
    end
    return suite()
end

-- « Accorde » : un gain direct sur une jauge (la reception d'un bouclier).
function Pas.grant(etape, ctx, suite)
    local montant = math.abs(tonumber(Montant(etape.amount, ctx)) or 0)
    if etape.sign == "-" then montant = -montant end
    local tag = Trim(Actions.Substituer(etape.tag, ctx))
    local ok = Actions.Payer(ctx.entity, tag, -montant)
    Journal(ctx, string.format("Accorde %s : %+d%s", tag, montant, ok and "" or " (jauge introuvable)"))
    return suite()
end

-- « Repartir » (chez celui qui agit) : un montant sur des zones nommees — le
-- soin qu'on donne, zone par zone. Le resultat, « Tete=3 ; Torse=2 », part
-- dans la declaration ; la cible l'applique par un pas « grantsplit ».
function Pas.distribute(etape, ctx, suite)
    local montant = math.max(0, math.floor((tonumber(Montant(etape.amount, ctx)) or 0) + 0.5))
    local zones = {}
    for z in (tostring(etape.zones or "") .. ","):gmatch("(.-),") do
        z = Trim(z)
        if z ~= "" then zones[#zones + 1] = z end
    end
    local sortie = Trim(etape.out) ~= "" and Trim(etape.out) or "repartition"
    ctx.vars[sortie .. "Total"] = montant
    if montant <= 0 or #zones == 0 then
        ctx.vars[sortie] = ""
        Journal(ctx, string.format("Répartition : rien à répartir (%d).", montant))
        return suite()
    end
    if not Actions.onDistribuer then return Arreter(ctx, "aucune fenêtre pour répartir.") end
    Actions.onDistribuer(Trim(etape.label) ~= "" and etape.label or "Répartir", montant, zones, ctx, function(parts)
        if not parts then return Arreter(ctx, "répartition annulée.") end
        local morceaux = {}
        for _, z in ipairs(zones) do
            if (parts[z] or 0) > 0 then morceaux[#morceaux + 1] = z .. "=" .. parts[z] end
        end
        ctx.vars[sortie] = table.concat(morceaux, " ; ")
        Journal(ctx, "Répartition : " .. ctx.vars[sortie])
        suite()
    end, Trim(Actions.Substituer(etape.note or "", ctx)))
end

-- Une zone du corps par son nom, avec tolerance : le soin du template dit
-- « Jambe », notre humanoide a « Jambes ».
local function ZoneParNom(entity, nom)
    local voulu = Cle(nom)
    local etat = LCM.Body.State(entity, LCM.Body.MaxTotal(entity))
    for _, z in ipairs(etat) do if Cle(z.label) == voulu then return z end end
    for _, z in ipairs(etat) do if Cle(z.label):find(voulu, 1, true) then return z end end
end

-- « Appliquer une repartition » (chez la cible) : « Tete=3 ; Torse=2 » soigne
-- (mode ajouter) ou blesse (mode retirer) ces zones. Un nom qui n'est pas une
-- zone est cherche parmi les jauges (#pa, #bouclier...).
function Pas.grantsplit(etape, ctx, suite)
    local retirer = tostring(etape.mode or "") == "retirer"
    local faits, manquants = {}, {}
    for _, p in ipairs(Paires(Actions.Substituer(etape.amount, ctx))) do
        local n = math.abs(tonumber(p.v) or 0)
        if n > 0 then
            local zone = ZoneParNom(ctx.entity, p.k)
            local ok
            if zone then
                if retirer then ok = LCM.Body.Damage(ctx.entity, zone.id, n) else ok = LCM.Body.Heal(ctx.entity, zone.id, n) end
            else
                ok = Actions.Payer(ctx.entity, p.k, retirer and n or -n)
            end
            if ok then faits[#faits + 1] = string.format("%s %s%d", zone and zone.label or p.k, retirer and "-" or "+", n)
            else manquants[#manquants + 1] = p.k end
        end
    end
    Journal(ctx, string.format("Répartition appliquée : %s%s", #faits > 0 and table.concat(faits, ", ") or "(rien)",
        #manquants > 0 and (" — introuvables : " .. table.concat(manquants, ", ")) or ""))
    return suite()
end

-- « Applique » : un degat (ou un gain) a repartir sur les zones que les tags
-- autorisent. Rien n'est touche ici : la repartition se fait a la fin, dans
-- la fenetre, ou le joueur choisit ou il encaisse.
function Pas.apply(etape, ctx, suite)
    local montant = tonumber(Montant(etape.amount, ctx))
    local signe = etape.sign == "+" and "+" or "-"

    -- La mecanique de defense « Defense » retire sa part AVANT la repartition :
    -- c'est le montant a encaisser qui diminue, pas les zones qui encaissent
    -- mieux. Un soin (signe +) n'est pas concerne, et une action qu'on porte
    -- soi-meme non plus — il faut etre dans une reception.
    if signe == "-" and montant and montant > 0 and LCM.Defenses then
        local m = Actions.MecaniqueRecue(ctx)
        if m then
            local restant, evite = LCM.Defenses.Encaisses(ctx.entity, m.id, montant)
            if evite > 0 then
                local part = LCM.Defenses.Reduction(ctx.entity, m.id)
                Journal(ctx, string.format("Défense : %d %% retirés, %d dégât(s) évité(s) sur %d.",
                    math.floor(part * 100 + 0.5), evite, montant))
                montant = restant
            end
        end
    end

    if signe == "-" and montant and montant <= 0 then
        Journal(ctx, string.format("Dégât absorbé : %s, rien à répartir.", tostring(montant)))
        -- La résistance du calculateur peut ramener une attaque reçue à zéro
        -- avant même l'écran de répartition. Sans retour visible, le joueur a
        -- l'impression que la résolution s'est perdue. Ce constat ne concerne
        -- que la défense automatique d'une attaque et reste strictement local.
        local paquet = ctx and (ctx.paquet or (ctx.recu and ctx.recu.paquet))
        local resolution = paquet and Actions.ResolutionPour(paquet.n)
        if resolution and resolution.id == "defense_auto_v3" then
            LCM.Info("Votre résistance est suffisamment élevée : vous ne subissez aucun dégât.")
        end
        return suite()
    end
    local tags = {}
    for tag in Actions.Substituer(etape.tags, ctx):gmatch("%S+") do
        if tag ~= "?" then tags[#tags + 1] = tag end
    end
    ctx.effets[#ctx.effets + 1] = { montant = montant or 0, signe = signe, tags = tags }
    Journal(ctx, string.format("Applique %s : %s%s", #tags > 0 and table.concat(tags, " ") or "(toutes zones)",
        signe, tostring(montant)))
    return suite()
end

-- Le cout d'entree d'une option de choix : ses `pay` de premier niveau, en
-- suivant un « aller a la feuille ». Une option trop chere est grisee.
local function CoutOption(etapes, ctx, profondeur)
    profondeur = profondeur or 0
    local pa, pf = 0, 0
    for _, e in ipairs(type(etapes) == "table" and etapes or {}) do
        if type(e) == "table" and e.type == "pay" then
            local tag = Cle(tostring(e.tag or ""):gsub("#", ""))
            local m = math.abs(tonumber(Montant(e.amount, ctx)) or 0)
            if tag == "pa" then pa = pa + m elseif tag == "pf" or tag == "fatigue" then pf = pf + m end
        elseif type(e) == "table" and e.type == "call" and profondeur < 3 then
            local id = tostring(e.callTarget or ""):match("^sheet:(.+)$")
            for _, f in ipairs(id and ctx.feuilles or {}) do
                if tostring(f.id) == id then
                    local a, b = CoutOption(f.etapes, ctx, profondeur + 1)
                    pa, pf = pa + a, pf + b
                end
            end
        end
    end
    return pa, pf
end

-- Le premier jet d'une option, pour afficher sa plage.
local function JetOption(etapes, ctx, profondeur)
    profondeur = profondeur or 0
    for _, e in ipairs(type(etapes) == "table" and etapes or {}) do
        if type(e) == "table" and e.type == "roll" and type(e.rolls) == "table" and e.rolls[1] then
            return Actions.Plage(e.rolls[1].formula, ctx.entity)
        elseif type(e) == "table" and e.type == "call" and profondeur < 3 then
            local id = tostring(e.callTarget or ""):match("^sheet:(.+)$")
            for _, f in ipairs(id and ctx.feuilles or {}) do
                if tostring(f.id) == id then
                    local p = JetOption(f.etapes, ctx, profondeur + 1)
                    if p ~= "" then return p end
                end
            end
        end
    end
    return ""
end

-- Ce que le coup ferait, normal et critique, pour qu'on choisisse sa reaction
-- en connaissance de cause.
local function Apercu(etape, ctx)
    if Trim(etape.previewAggregatorName) == "" and Trim(etape.previewAggregator) == "" then return nil end
    local function Un(inject)
        return Actions.Calculer({ aggregatorName = etape.previewAggregatorName,
                                  aggregator = etape.previewAggregator, inject = inject }, ctx)
    end
    local normal, critique = Un(etape.previewInjectNormal), Un(etape.previewInjectCritique)
    local cases = {
        { titre = "Coup normal", valeur = normal and math.floor(normal + 0.5), couleur = { 1, 0.9, 0.55 } },
        { titre = "Coup critique", valeur = critique and math.floor(critique + 0.5), couleur = { 1, 0.35, 0.35 } },
    }
    local pct = Actions.PercePourcentage(ctx)
    if pct > 0 then
        cases[3] = { titre = string.format("Perce-armure %d%%", math.floor(pct + 0.5)),
                     texte = string.format("%s / |cffff5959%s|r",
                         normal and math.ceil(normal * pct / 100 - 1e-9) or "?",
                         critique and math.ceil(critique * pct / 100 - 1e-9) or "?") }
    end
    return cases
end

-- Une question posee a celui qui resout : un bouton par option.
function Pas.choice(etape, ctx, suite)
    local options = type(etape.options) == "table" and etape.options or {}
    if #options == 0 then return suite() end
    if not Actions.onChoix then return Arreter(ctx, "aucune fenêtre pour choisir.") end
    local pa = Actions.Disponible(ctx.entity, ctx.recu ~= nil)
    local boutons = {}
    for _, o in ipairs(options) do
        local cpa, cpf = CoutOption(o.steps, ctx)
        local couts = {}
        if cpa > 0 then couts[#couts + 1] = math.floor(cpa + 0.5) .. " PA" end
        if cpf > 0 then couts[#couts + 1] = math.floor(cpf + 0.5) .. " PF" end
        boutons[#boutons + 1] = {
            texte = (Trim(o.label) ~= "" and o.label or "Option") .. JetOption(o.steps, ctx),
            cout = #couts > 0 and ("( " .. table.concat(couts, " - ") .. " )") or nil,
            aide = Trim(Actions.Substituer(o.help or "", ctx)),
            grise = pa ~= nil and cpa > 0 and cpa > pa + 0.001,
            choisir = function()
                Journal(ctx, "Choix : " .. tostring(o.label))
                Actions.Etapes(type(o.steps) == "table" and o.steps or {}, ctx, suite)
            end,
        }
    end
    Actions.onChoix(Trim(etape.label) ~= "" and etape.label or "Choix", ctx, boutons, {
        contexte = Trim(Actions.Substituer(etape.note or "", ctx)),
        apercu = Apercu(etape, ctx), pa = pa,
    })
end

-- La branche d'un jet : les conditions ecrites d'abord, sinon le seuil. Une
-- egalite peut etre rendue a la reussite ou a l'echec (tieMode).
local function Branche(b)
    if type(b) ~= "table" then return { condition = "", steps = {} } end
    if type(b.steps) ~= "table" then return { condition = tostring(b.condition or ""), steps = b[1] and b or {} } end
    return { condition = tostring(b.condition or ""), steps = b.steps }
end

local function ChoisirBranche(c, ctx, resultat, oppose)
    local mode = (c.tieMode == "success" or c.tieMode == "fail") and c.tieMode or "own"
    local cles = mode == "own" and { "onSuccess", "onTie", "onFail" } or { "onSuccess", "onFail" }
    for _, k in ipairs(cles) do
        local b = Branche(c[k])
        if Trim(b.condition) ~= "" and Actions.Condition(b.condition, ctx) == true then return b, k end
    end
    if resultat > oppose then return Branche(c.onSuccess), "onSuccess" end
    if resultat < oppose then return Branche(c.onFail), "onFail" end
    if mode == "success" then return Branche(c.onSuccess), "onSuccess" end
    if mode == "fail" then return Branche(c.onFail), "onFail" end
    return Branche(c.onTie), "onTie"
end

local ISSUES = { onSuccess = "Réussite", onTie = "Égalité", onFail = "Échec" }

function Pas.roll(etape, ctx, suite)
    local candidats = type(etape.rolls) == "table" and etape.rolls or {}
    -- Candidats dynamiques : des tags recus « Nom=Seuil ; Nom2=Seuil2 », un jet
    -- par paire, branches communes (les epreuves du MJ).
    if #candidats == 0 and Trim(etape.rollsFromTags) ~= "" then
        candidats = {}
        for tag in tostring(etape.rollsFromTags):gmatch("[^,]+") do
            for _, p in ipairs(Paires(tostring(Jeton("recu", Trim(tag), ctx) or ""))) do
                if tonumber(p.v) then
                    candidats[#candidats + 1] = { label = p.k, formula = "jet:" .. p.k, vs = p.v,
                        tieMode = etape.tieMode, announce = etape.announce == true or etape.announce == "True",
                        announceName = p.k, onSuccess = etape.dynOnSuccess, onTie = etape.dynOnTie,
                        onFail = etape.dynOnFail }
                end
            end
        end
    end
    if #candidats == 0 then return suite() end
    local function Lancer(c)
        local resultat, ligne = Actions.JetFormule(c.formula, ctx)
        local oppose = tonumber(Montant(c.vs, ctx)) or 0
        -- Les conditions en aval lisent « resultat » et « oppose ».
        ctx.vars.resultat, ctx.vars.oppose = resultat, oppose
        local branche, cle = ChoisirBranche(c, ctx, resultat, oppose)
        Journal(ctx, string.format("Jet %s : %s contre %s -> %s", tostring(c.label or "?"), tostring(resultat),
            tostring(oppose), ISSUES[cle] or cle))
        if c.announce then
            Actions.Annoncer(ligne or string.format("[%s] %s", tostring(c.announceName or c.label or "Jet"), resultat), ctx)
        end
        Actions.Etapes(branche.steps, ctx, suite)
    end
    if #candidats == 1 then return Lancer(candidats[1]) end
    if not Actions.onChoix then return Arreter(ctx, "aucune fenêtre pour choisir le jet.") end
    local boutons = {}
    for _, c in ipairs(candidats) do
        boutons[#boutons + 1] = { texte = (Trim(c.label) ~= "" and c.label or "Jet") .. Actions.Plage(c.formula, ctx.entity),
                                  choisir = function() Lancer(c) end }
    end
    Actions.onChoix(Trim(etape.label) ~= "" and etape.label or "Choisissez le jet", ctx, boutons, {})
end

-- ===== Le constructeur de buff (pas « allocate ») ==========================
-- Repris de RunBuffComposer de Necronicon. Les questions (source, jet, niveau,
-- penetrations, ciblage, cumul) sont celles d'un composeur ordinaire ; elles
-- fixent une RESERVE de points (regle `pool`). On la depense sur les champs que
-- l'etat modifiera — chacun au cout de sa famille (regle `families`) — et sur
-- des rounds de duree en plus. Un debuff a sa reserve reduite (poolMult) et la
-- cible y resiste ; un buff s'accepte.

-- Les cles d'effet du template -> nos champs. « terreste » est la coquille du
-- template (Immobilisation, Entrave) : on la lit telle quelle.
local CHAMPS_EFFET = { terreste = "depl_terrestre", terrestre = "depl_terrestre", nage = "depl_nage",
                       vol = "depl_vol" }
Actions.CHAMPS_EFFET = CHAMPS_EFFET

local function LireRegles(texte)
    local r = { mode = "buff", families = {}, groupes = {}, defaut = 1, affinityGood = 0.7, affinityBad = 1,
                poolMult = 1, pool = "0", durationBase = "1", durationPerPoint = 1, resistSkills = { "Esprit" },
                stackDrainPct = 5, stackLifeCost = 3, dispellCost = 10, puissanceRef = "", dureeRef = "",
                -- « Illimite » : pas d'expiration, pour un surcout ; la guerison
                -- (narration, jet, action) coute plus cher a mesure qu'elle est dure.
                permanent = false, permanentCost = 10, cureMode = "narration", cureRandSkill = "Constitution",
                cureDC = 12 }
    for ligne in (tostring(texte or "") .. "\n"):gmatch("(.-)\n") do
        local k, v = ligne:match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
        if k then
            k = k:lower()
            if k == "mode" then r.mode = Cle(v) == "debuff" and "debuff" or "buff"
            elseif k == "permanent" then r.permanent = Cle(v):match("^[o1ty]") ~= nil
            elseif k == "curemode" then
                local m = Cle(v)
                r.cureMode = (m == "rand" or m == "action") and m or "narration"
            elseif k == "curerandskill" then r.cureRandSkill = Trim(v)
            elseif k == "pool" or k == "durationbase" or k == "puissanceref" or k == "dureeref" or k == "dispelltag" then
                r[({ pool = "pool", durationbase = "durationBase", puissanceref = "puissanceRef",
                     dureeref = "dureeRef", dispelltag = "dispellTag" })[k]] = Trim(v)
            elseif k == "resistskills" then
                local liste = {}
                for nom in (v .. ","):gmatch("(.-),") do if Trim(nom) ~= "" then liste[#liste + 1] = Trim(nom) end end
                if #liste > 0 then r.resistSkills = liste end
            elseif k == "families" then
                -- « [Libelle] Nom1,Nom2 = cout ; * = cout »
                for groupe in (v .. ";"):gmatch("(.-);") do
                    local libelle, reste = Trim(groupe):match("^%[(.-)%]%s*(.+)$")
                    reste = reste or Trim(groupe)
                    local noms, cout = reste:match("^%s*(.-)%s*=%s*([%d%.]+)%s*$")
                    if noms then
                        cout = tonumber(cout) or 1
                        if Trim(noms) == "*" then
                            r.defaut = cout
                        else
                            local g = { libelle = libelle and Trim(libelle) or noms, cout = cout, noms = {} }
                            for nom in (noms .. ","):gmatch("(.-),") do
                                if Trim(nom) ~= "" then g.noms[#g.noms + 1] = Trim(nom) end
                            end
                            r.groupes[#r.groupes + 1] = g
                        end
                    end
                end
            else
                local cle = ({ poolmult = "poolMult", affinitygood = "affinityGood", affinitybad = "affinityBad",
                               durationperpoint = "durationPerPoint", stackdrainpct = "stackDrainPct",
                               stacklifecost = "stackLifeCost", dispellcost = "dispellCost",
                               permanentcost = "permanentCost", curedc = "cureDC", curecost = "cureCost" })[k]
                if cle then r[cle] = tonumber(v) or r[cle] end
            end
        end
    end
    -- Le prix de la guerison, retire de la reserve (Necronicon :
    -- BUFF_CURE_COST_BY_MODE) : narration 0, jet 4, action 8.
    if r.cureCost == nil then r.cureCost = ({ narration = 0, rand = 4, action = 8 })[r.cureMode] or 0 end
    return r
end

-- Un nom de famille du template -> un champ de notre fiche. « Pen-air »,
-- « Resi-feu », « Force - Perce-armure », « Esprit-Provocation », « Pistage »,
-- « Attaque simple » (mecanique), « Terreste » (la coquille du template).
-- Un meme libelle peut exister deux fois (« Nage » : l'expertise et le
-- deplacement) : on prefere ce qu'on investit a ce qui se calcule.
local function ChampDeFamille(nom)
    local prefixe, reste = nom:match("^%s*([Pp]en)%s*%-%s*(.+)$")
    if not prefixe then prefixe, reste = nom:match("^%s*([Rr]esi)%s*%-%s*(.+)$") end
    if prefixe then
        local t = Cle(reste)
        t = ALIAS_TYPES[t] or t
        for _, ty in ipairs(Eq().types) do
            if Cle(ty.id) == t or Cle(ty.label) == t then
                return (Cle(prefixe) == "pen" and "pen_" or "resi_") .. ty.id
            end
        end
        return nil
    end
    local a, b = nom:match("^%s*(.-)%s*%-%s*(.-)%s*$")
    if a and b and a ~= "" and b ~= "" then
        -- « Force - Perce-armure » -> force_perce_armure ; « Défense - Constitution » -> defense_constitution.
        local candidat = (Cle(a) .. "_" .. Cle(b)):gsub("percearmure", "perce_armure"):gsub("brisearmure", "brise_armure")
        if LCM.Schema.Field(candidat) then return candidat end
    end
    local m = Mecanique(nom)
    if m then return LCM.MecaniqueField(m.id) end
    local voulu = Cle(nom)
    -- Une primaire d'abord (« Esprit » est aussi une jauge d'Existence).
    for _, p in ipairs(Eq().primaires) do
        if Cle(p.label) == voulu or Cle(p.id) == voulu then return p.id end
    end
    -- Puis, a libelle egal, ce qui compte en jeu : un jet (« Initiative » est
    -- le jet, pas les points secondaires qu'on y investit), une jauge, une
    -- statistique ; ce qui se calcule en dernier. Le pluriel est tolere
    -- (« Acrobatie » / « Acrobaties »).
    local RANG = { roll = 1, gauge = 2, stat = 3, calc = 9 }
    local meilleur, rang
    LCM.Schema.EachField(function(field)
        local c = Cle(field.label)
        if c == voulu or Cle(field.id) == voulu or c == voulu .. "s" then
            local r = RANG[field.kind] or 5
            if not rang or r < rang then meilleur, rang = field, r end
        end
    end)
    if meilleur and rang < 9 then return meilleur.id end
    if CHAMPS_EFFET[voulu] then return CHAMPS_EFFET[voulu] end
    return meilleur and meilleur.id
end
Actions.ChampDeFamille = ChampDeFamille

local ELEMENTS = { "feu", "eau", "vent", "air", "terre", "esprit", "pourriture",
                   "lumiere", "ombre", "ordre", "desordre", "vie", "mort" }

local Constructeur = {}
Constructeur.__index = Constructeur

local CIBLAGES_EFFET = { mono = true, multi = true, aoe = true, aoecond = true }
local function CiblageEffetValide(vars)
    return CIBLAGES_EFFET[Cle(vars and vars.cibleMode)] == true
end

function Actions.Constructeur(etape, ctx)
    local c = setmetatable({ etape = etape, ctx = ctx, regles = LireRegles(etape.buffRulesText),
                             points = {}, dureeAchetee = 0 }, Constructeur)
    c.composeur = Actions.Composeur({ questionsText = etape.questionsText, hideCost = etape.hideCost }, ctx)
    -- Le cumul n'est pas encore jouable : retirer ses questions du composeur
    -- empeche aussi les anciennes reponses enregistrees de produire un effet.
    local questions = {}
    for _, question in ipairs(c.composeur.questions) do
        if question.label ~= "Type d'effet" and not tostring(question.showIf):find("effetMode", 1, true) then
            questions[#questions + 1] = question
        end
    end
    c.composeur.questions = questions
    -- Dans un buff/debuff multicible, le premier PA paie la premiere cible.
    -- Chaque cible suivante ajoute un PA au moment du choix des cibles.
    for _, question in ipairs(questions) do
        for _, option in ipairs(question.options) do
            if option.set:find("cibleMode%s*=%s*multi") then
                option.pa, option.pac, option.paParCible = 1, 1, true
            end
        end
    end
    c.composeur:Deriver()
    c.debuff = c.regles.mode == "debuff"
    -- Ou l'effet ira dans la fenetre Sante : Etat, Maladie ou Intangible. Le
    -- choix se fait AVANT tout le reste — c'est lui qui dit de quoi on parle.
    c.conteneur = "etat"
    -- Les champs qu'on peut toucher, groupes par famille ; ce que le template
    -- nomme et que notre fiche n'a pas est mis de cote, et dit.
    c.familles, c.absents = {}, {}
    local vus, retenus = {}, {}
    -- La section opposee n'a rien a faire ici : « Durée » et « Puissance »
    -- existent en deux exemplaires sur la fiche (duree_buff / duree_debuff), et
    -- les regles nommaient les deux. On voyait donc DEUX durees et DEUX
    -- puissances en construisant un buff, sans pouvoir deviner laquelle servait.
    local sectionExclue = c.debuff and "Buff" or "Debuff"
    for _, g in ipairs(c.regles.groupes) do
        for _, nom in ipairs(g.noms) do
            local champ = ChampDeFamille(nom)
            local field = champ and LCM.Schema.Field(champ)
            if champ and field and (field.section == sectionExclue or field.tab == "combat") then
                -- Les anciennes statistiques de combat ne se choisissent plus.
            elseif champ and not vus[champ] then
                vus[champ] = true
                retenus[#retenus + 1] = { id = champ, nom = field and field.label or nom, cout = g.cout }
            elseif not champ then
                c.absents[#c.absents + 1] = nom
            end
        end
    end

    -- Groupes par SENS, pas par cout. Les regles rangent les champs par prix
    -- (« Cout 3 », « Cout 5 »), ce qui ne dit rien de ce qu'on achete et fait
    -- se cotoyer six « Force » sans contexte. On reprend le decoupage de la
    -- fiche — onglet puis section, comme Necronicon affiche « Pénétrations —
    -- Élémentaire » — et le prix reste porte par chaque champ, qui l'affiche.
    local ordreOnglet, labelOnglet = {}, {}
    for rang, tab in ipairs(LCM.Schema.Tabs()) do
        ordreOnglet[tab.id] = rang
        labelOnglet[tab.id] = tab.label or tab.id
    end
    local parGroupe, ordre = {}, {}
    for _, ch in ipairs(retenus) do
        local field = LCM.Schema.Field(ch.id)
        local onglet = field and field.tab
        local section = (field and field.section) or ""
        -- Une section dont le nom se suffit (« Statistiques ») n'a pas besoin
        -- du nom de son onglet ; « Élémentaires » si, sinon penetrations et
        -- resistances se ressemblent trait pour trait.
        local titreOnglet = labelOnglet[onglet]
        local libelle = section
        if libelle == "" then libelle = titreOnglet or "Autres"
        elseif titreOnglet and titreOnglet ~= section then
            libelle = titreOnglet .. " — " .. section
        end
        local groupe = parGroupe[libelle]
        if not groupe then
            groupe = { libelle = libelle, cout = ch.cout, champs = {},
                       rang = ordreOnglet[onglet] or 99 }
            parGroupe[libelle] = groupe
            ordre[#ordre + 1] = groupe
        end
        groupe.champs[#groupe.champs + 1] = ch
        -- Le cout de la famille n'est affiche que s'il vaut pour tous.
        if groupe.cout ~= ch.cout then groupe.cout = nil end
    end
    -- L'ordre de la fiche : on retrouve les familles la ou on a l'habitude de
    -- les lire. `table.sort` n'est pas stable, d'ou le rang de secours.
    for index, groupe in ipairs(ordre) do groupe.apparition = index end
    table.sort(ordre, function(a, b)
        if a.rang ~= b.rang then return a.rang < b.rang end
        return a.apparition < b.apparition
    end)
    c.familles = ordre
    return c
end

-- ===== La bibliotheque d'effets ==========================================
-- Un buff qu'on a compose se reutilise : « Vigueur » revient a chaque seance,
-- et le recomposer champ par champ a chaque fois est du travail perdu.
--
-- Les modeles vivent dans la base du COMPTE (LCM_DB) et non sur le
-- personnage : le MJ comme le joueur s'en sert avec qui il joue ce soir-la.
-- On garde ce qu'on a saisi et choisi, pas le resultat : une regle qui change
-- (un cout, une reserve) doit se repercuter au rechargement, sinon un vieux
-- modele contournerait l'equilibrage sans qu'on le voie.

local function Modeles()
    LCM.EnsureDatabase()
    LCM.db.modelesEffets = type(LCM.db.modelesEffets) == "table" and LCM.db.modelesEffets or {}
    return LCM.db.modelesEffets
end
Actions.Modeles = Modeles

-- Ceux qui vont avec cette etape : un modele de debuff n'a rien a faire dans
-- un constructeur de buff, ses champs n'y existent pas forcement.
function Actions.ModelesPour(constructeur)
    local out = {}
    for _, m in ipairs(Modeles()) do
        if (m.debuff == true) == (constructeur.debuff == true) then out[#out + 1] = m end
    end
    table.sort(out, function(a, b) return tostring(a.nom):lower() < tostring(b.nom):lower() end)
    return out
end

function Constructeur:Enregistrer(nom, description, icone)
    nom = Trim(nom)
    if nom == "" then return false, "il faut un nom." end
    local reponses = {}
    local questions = {}
    for _, q in ipairs(self.composeur.questions) do questions[q.id] = true end
    for cle, valeur in pairs(self.composeur.reponses) do
        if questions[cle] then
            if type(valeur) == "table" then
                local copie = {}
                for k, v in pairs(valeur) do copie[k] = v end
                reponses[cle] = copie
            else
                reponses[cle] = valeur
            end
        end
    end
    local points = {}
    for champ, n in pairs(self.points) do points[champ] = n end

    local modele = {
        nom = nom, description = Trim(description or ""), icone = icone,
        debuff = self.debuff == true, conteneur = self.conteneur,
        points = points, reponses = reponses,
        duree = self.dureeAchetee, illimite = self.illimite == true,
    }
    local liste = Modeles()
    -- Un meme nom remplace : on corrige un modele, on n'en empile pas trois.
    for index, m in ipairs(liste) do
        if tostring(m.nom):lower() == nom:lower() and (m.debuff == true) == modele.debuff then
            liste[index] = modele
            return true, modele
        end
    end
    liste[#liste + 1] = modele
    return true, modele
end

function Constructeur:Charger(modele)
    if type(modele) ~= "table" then return false end
    self.conteneur = modele.conteneur
    self.illimite = modele.illimite == true
    self.dureeAchetee = tonumber(modele.duree) or 0
    self.composeur.reponses = {}
    local questions = {}
    for _, q in ipairs(self.composeur.questions) do questions[q.id] = true end
    for cle, valeur in pairs(modele.reponses or {}) do
        if questions[cle] then
            if type(valeur) == "table" then
                local copie = {}
                for k, v in pairs(valeur) do copie[k] = v end
                self.composeur.reponses[cle] = copie
            else
                self.composeur.reponses[cle] = valeur
            end
        end
    end
    -- Les points se REJOUENT champ par champ : `Ajouter` refuse ce qui depasse
    -- la reserve ou le plafond du jour. Les recopier en bloc aurait laisse
    -- passer un modele devenu trop cher depuis qu'on l'a enregistre.
    self.points = {}
    local refuses = {}
    for champ, n in pairs(modele.points or {}) do
        for _ = 1, n do
            if not self:Ajouter(champ, 1) then
                refuses[#refuses + 1] = champ
                break
            end
        end
    end
    return true, refuses
end

function Actions.SupprimerModele(modele)
    local liste = Modeles()
    for index, m in ipairs(liste) do
        if m == modele then table.remove(liste, index) return true end
    end
    return false
end

-- Les variables de la reserve : celles des choix, en minuscules (la regle
-- s'ecrit « src*1 + penMoy*penCoef »), plus src, niveau, puissance.
function Constructeur:Variables()
    self.composeur:Deriver()
    local V = self.ctx.vars
    local vars = {}
    for k, v in pairs(V) do
        if type(k) == "string" and tonumber(v) then vars[k:lower()] = tonumber(v) end
    end
    vars.src = tonumber(V.srcVal) or 0
    vars.srcmult = tonumber(V.srcMult) or 1
    vars.penmoy = tonumber(V.penMoy) or 0
    vars.niveau = tonumber(V.niveauSort) or 1
    vars.puissance = Trim(self.regles.puissanceRef) ~= "" and (Actions.Stat(self.regles.puissanceRef, self.ctx.entity) or 0) or 0
    return vars
end

local function Calcul(expr, vars)
    expr = Trim(expr)
    if tonumber(expr) then return tonumber(expr) end
    return Arithmetique((expr:gsub("[%a_][%w_]*", function(mot) return tostring(vars[mot:lower()] or 0) end))) or 0
end

function Constructeur:Reserve()
    local brute = math.floor(Calcul(self.regles.pool, self:Variables()) * (self.regles.poolMult or 1) + 0.5)
    return math.max(0, brute - (self.regles.cureCost or 0))
end

-- « Illimite » : seulement si l'action le permet ; on n'achete plus de rounds.
function Constructeur:Illimite(oui)
    if not self.regles.permanent then return false end
    self.illimite = oui and true or false
    if self.illimite then self.dureeAchetee = 0 end
    return true
end

-- Le cumul (« stack ») : chaque cumul draine une part d'une jauge a chaque round.
function Constructeur:Cumul()
    local V = self.ctx.vars
    if tostring(V.effetMode or "") ~= "stack" then return nil end
    return { n = math.max(1, math.floor(tonumber(V.stackCount) or 1)), jauge = tostring(V.stackGauge or "Torse"),
             coutJauge = tonumber(V.stackGaugeCost) or 0, fin = tostring(V.stackEnd or "duree") }
end

-- Le prix d'un point sur un champ : celui de sa famille, remise si c'est une
-- penetration ou une resistance d'un type qu'on a choisi.
function Constructeur:Cout(champ)
    local cout = self.regles.defaut
    for _, f in ipairs(self.familles) do
        for _, ch in ipairs(f.champs) do
            -- Une famille visuelle peut reunir des champs de prix differents ;
            -- dans ce cas `f.cout` vaut volontairement nil (on n'affiche pas
            -- un faux prix commun). Le prix reel reste porte par le champ.
            if ch.id == champ then cout = ch.cout or f.cout or cout end
        end
    end
    if champ:find("^pen_") or champ:find("^resi_") then
        local choisis = Cle(self.ctx.vars.penTypes)
        local element = champ:gsub("^pen_", ""):gsub("^resi_", "")
        local actif = false
        for _, e in ipairs(ELEMENTS) do
            if e == element or (element == "vent" and e == "air") then
                if choisis:find(e, 1, true) then actif = true end
            end
        end
        if actif then cout = cout * self.regles.affinityGood else cout = cout * self.regles.affinityBad end
    end
    return math.max(0.1, cout)
end

function Constructeur:ParRound()
    local cumul = self:Cumul()
    if cumul and cumul.fin == "duree" then return self.regles.stackLifeCost end
    local bonus = Trim(self.regles.dureeRef) ~= "" and (Actions.Stat(self.regles.dureeRef, self.ctx.entity) or 0) or 0
    return math.max(1, math.floor(self.regles.durationPerPoint * (1 - 0.05 * bonus) + 0.5))
end

function Constructeur:Depense()
    local s = 0
    for champ, n in pairs(self.points) do s = s + n * self:Cout(champ) end
    local cumul = self:Cumul()
    if not (cumul and cumul.fin == "dispell") and not self.illimite then s = s + self.dureeAchetee * self:ParRound() end
    if self.illimite then s = s + (self.regles.permanentCost or 0) end
    if cumul then
        s = s + cumul.n * cumul.coutJauge
        if cumul.fin == "dispell" then s = s + self.regles.dispellCost end
    end
    return s
end

-- La duree en rounds, ou nil pour « jusqu'a dissipation ».
function Constructeur:Duree()
    local cumul = self:Cumul()
    if self.illimite or (cumul and cumul.fin == "dispell") then return nil end
    if cumul then return 1 + self.dureeAchetee end
    local pts = 0
    for _, n in pairs(self.points) do pts = pts + n end
    local base = math.max(1, math.floor(Calcul(self.regles.durationBase,
        { pf = tonumber(self.ctx.vars._coutPF) or 0, pts = pts }) + 0.5))
    return base + self.dureeAchetee
end

-- Ajoute (ou retire) des points a un champ, dans la limite de la reserve.
function Constructeur:Ajouter(champ, n)
    local actuel = self.points[champ] or 0
    local voulu = math.max(0, actuel + n)
    if voulu > actuel then
        local libre = self:Reserve() - self:Depense()
        voulu = math.min(voulu, actuel + math.floor(libre / self:Cout(champ) + 1e-9))
    end
    self.points[champ] = voulu > 0 and voulu or nil
end

function Constructeur:AcheterDuree(n)
    local voulu = math.max(0, self.dureeAchetee + n)
    if voulu > self.dureeAchetee then
        local libre = self:Reserve() - self:Depense()
        voulu = math.min(voulu, self.dureeAchetee + math.floor(libre / self:ParRound() + 1e-9))
    end
    self.dureeAchetee = voulu
end

function Constructeur:Blocage()
    local b = self.composeur:Blocage()
    if b and not b:find("type d'attaque") then return b end
    if not CiblageEffetValide(self.ctx.vars) then return "Il faut choisir un mode de ciblage." end
    if self:Depense() > self:Reserve() + 0.001 then return "Plus de points dépensés que la réserve." end
    if not next(self.points) and not self:Cumul() then return "Aucun point réparti." end
    return nil
end

-- Valide : l'effet est pret a etre declare (meme forme qu'un pas « effect »).
function Constructeur:Valider(nom, description, icone)
    local s = self.debuff and -1 or 1
    local donnees = {}
    for champ, n in pairs(self.points) do donnees["@" .. champ] = n * s end
    local cumul = self:Cumul()
    local V = self.ctx.vars
    self.ctx.effet = {
        debuff = self.debuff, nom = Trim(nom) ~= "" and Trim(nom) or (self.debuff and "Débuff" or "Buff"),
        conteneur = LCM.EtatsTemporaires.ConteneurValide(self.conteneur),
        icone = Trim(icone) ~= "" and icone or self.ctx.icone, description = Trim(description),
        donnees = donnees, rounds = self:Duree(), resistance = table.concat(self.regles.resistSkills, ", "),
        critEcart = 0, critFacteur = 1, narratif = false, texte = "", montant = 0, unite = "",
        deplacementForce = false,
        bonusJet = 0, multJet = 1,
        dissipation = Trim(self.regles.dispellTag) ~= "" and self.regles.dispellTag or Cle(nom),
        cumul = cumul and { n = cumul.n, jauge = cumul.jauge, pct = self.regles.stackDrainPct } or nil,
        -- Un etat sans fin se guerit comme la regle le dit.
        guerison = (self.illimite or (cumul and cumul.fin == "dispell"))
            and { mode = self.regles.cureMode, competence = self.regles.cureRandSkill, dc = self.regles.cureDC } or nil,
    }
    V._buffData = donnees
    Journal(self.ctx, string.format("%s « %s » : %d / %d pt, %s", self.debuff and "Débuff" or "Buff",
        self.ctx.effet.nom, math.floor(self:Depense() + 0.5), self:Reserve(),
        self.ctx.effet.rounds and (self.ctx.effet.rounds .. " round(s)") or "jusqu'à dissipation"))
end

function Pas.allocate(etape, ctx, suite)
    if not Actions.onConstruire then return Arreter(ctx, "aucune fenêtre pour construire l'état.") end
    local c = Actions.Constructeur(etape, ctx)
    ctx.constructeur = c
    Actions.onConstruire(c, function(nom, description, icone)
        c:Valider(nom, description, icone)
        suite()
    end, function() Arreter(ctx, "action annulée.") end)
end

-- ===== La dissipation (pas « dispel ») =====================================
-- Repris de la Dissipation v2 de Necronicon (BuildDispelConfig, ExecuteDispel).
-- On choisit ses cibles et, chez chacune, les etats a dissiper (la liste est
-- demandee au porteur) ; puis la competence et le niveau du sort ; puis un jet
-- par competence, contre le jet qu'avait fait le lanceur de chaque etat. Un
-- etat battu est retire chez son porteur.

function Actions.ConfigDissipation(etape, ctx)
    local cfg = { competences = {}, niveaux = {}, paParCibles = {}, pfParCible = 2, pfParEtat = 1, mult = 1 }
    for c in (Trim(etape.skills) ~= "" and etape.skills or "Esprit, Adresse"):gmatch("[^,]+") do
        if Trim(c) ~= "" then cfg.competences[#cfg.competences + 1] = Trim(c) end
    end
    local niveaux = Trim(etape.levels) ~= "" and etape.levels or "1:0/1, 2:0/2, 3:1/4, 4:1/8, 5:2/12, 6:2/15"
    for n, pa, pf in niveaux:gmatch("(%d+)%s*:%s*(%-?[%d%.]+)%s*/%s*(%-?[%d%.]+)") do
        cfg.niveaux[#cfg.niveaux + 1] = { niveau = tonumber(n), pa = tonumber(pa), pf = tonumber(pf) }
    end
    local tarifs = Trim(etape.tarifs) ~= "" and etape.tarifs or "pa=1:1,3:2,6:3,10:4 ; pfCible=2 ; pfEtat=1"
    for _, p in ipairs(Paires(tarifs)) do
        if p.k == "pa" then
            for jusque, pa in p.v:gmatch("(%d+)%s*:%s*(%d+)") do
                cfg.paParCibles[#cfg.paParCibles + 1] = { jusque = tonumber(jusque), pa = tonumber(pa) }
            end
        elseif p.k == "pfCible" then cfg.pfParCible = tonumber(p.v) or cfg.pfParCible
        elseif p.k == "pfEtat" then cfg.pfParEtat = tonumber(p.v) or cfg.pfParEtat end
    end
    table.sort(cfg.paParCibles, function(a, b) return a.jusque < b.jusque end)
    local m = Trim(etape.mult) ~= "" and Actions.Evaluer(etape.mult, ctx)
    if m and m > 0 then cfg.mult = m end
    return cfg
end

function Actions.CoutDissipation(cfg, nCibles, nEtats, niveau)
    local pa = 0
    if nCibles > 0 then
        pa = cfg.paParCibles[#cfg.paParCibles] and cfg.paParCibles[#cfg.paParCibles].pa or 0
        for _, t in ipairs(cfg.paParCibles) do if nCibles <= t.jusque then pa = t.pa break end end
    end
    local pf = cfg.pfParCible * nCibles + cfg.pfParEtat * nEtats
    for _, n in ipairs(cfg.niveaux) do
        if n.niveau == niveau then pa, pf = pa + n.pa, pf + n.pf end
    end
    return pa, pf
end

-- La part fixe du jet : arrondi((valeur + niveau) x mecanique). Inadaptee, la
-- primaire ne compte qu'au taux du malus (comme les jets de defense).
local function FixeDissipation(entity, competence, inadaptee, niveau, mult)
    local field = ChampParLibelle(competence, "roll")
    if not field then return nil end
    local valeur
    if inadaptee then
        valeur = math.floor(LCM.Formules.Primaire(entity, field.id) * Eq().malusInadapte)
    else
        valeur = (tonumber(LCM.Entities.Get_Value(entity, field.id)) or 0) + LCM.Formules.Apport(entity, field.id)
            + LCM.Effets.Bonus(entity, field.id)
    end
    return math.floor((valeur + (niveau or 0)) * mult + 0.5), field
end

-- La chance (en %) de battre `seuil` : le de est uniforme.
function Actions.ChanceDissipation(entity, competence, inadaptee, niveau, mult, seuil)
    local fixe, field = FixeDissipation(entity, competence, inadaptee, niveau, mult)
    if not fixe then return nil end
    local mn, mx = field.dice.min or 0, field.dice.max or 0
    local n = 0
    for r = mn, mx do if r + fixe >= (seuil or 0) then n = n + 1 end end
    return math.floor(100 * n / (mx - mn + 1) + 0.5)
end

-- Les etats d'une cible, pour la liste : chez soi ou chez le MJ (PNJ), on
-- lit ; chez un autre joueur, on demande, et la reponse arrive par onEtats.
Actions.etatsConnus = {}
local function Resume(liste)
    local out = {}
    for _, e in ipairs(liste) do
        if e.id then
            -- Un DOT annonce son rand COURANT, pas le jet d'origine : il baisse
            -- d'un point par round (Core/Dot.lua), et c'est lui qu'il faut
            -- battre. Ses stacks voyagent aussi — dissiper n'est pas tout ou
            -- rien sur un dot (9 octobre 2026).
            local dot = type(e.dot) == "table" and e.dot or nil
            out[#out + 1] = { id = e.id, nom = e.nom, icone = e.icone, competence = e.jet and e.jet.competence,
                              seuil = dot and (tonumber(dot.rand) or 0) or (e.jet and e.jet.valeur or 0),
                              restant = e.restant, lanceur = e.lanceur,
                              stacks = dot and dot.stacks or nil }
        end
    end
    return out
end

function Actions.EtatsDe(cible)
    if cible.soi then return Resume(LCM.EtatsTemporaires.Liste(LCM.Entities.Personnage())) end
    if cible.pnj and (cible.mj or LCM.PlayerId()) == LCM.PlayerId() then
        local instance = LCM.Incarnation.Instance(cible.id)
        return instance and Resume(LCM.EtatsTemporaires.Liste(instance)) or {}
    end
    local cle = cible.id
    if cible.pnj then
        LCM.Reseau.Envoyer("etats?", { p = cible.id }, "WHISPER", cible.mj)
    else
        LCM.Reseau.Envoyer("etats?", {}, "WHISPER", cible.id)
    end
    return Actions.etatsConnus[cle]
end

-- choix = { competence, niveau } ; selection = { { cible, etat } }
function Actions.Dissiper(ctx, cfg, selection, choix)
    local cibles = {}
    for _, s in ipairs(selection) do cibles[s.cible.id] = true end
    local nCibles = 0
    for _ in pairs(cibles) do nCibles = nCibles + 1 end
    local pa, pf = Actions.CoutDissipation(cfg, nCibles, #selection, choix.niveau)
    if pa > 0 and not Actions.Payer(ctx.entity, "#pa", pa) then return false end
    Actions.Payer(ctx.entity, "#fatigue", pf)
    Journal(ctx, string.format("Dissipation : %d PA / %d PF (niveau %d, %s).", pa, pf, choix.niveau, choix.competence))
    local jets, resultats, reussis = {}, {}, 0
    for _, s in ipairs(selection) do
        local etat = s.etat
        local inadaptee = Cle(choix.competence) ~= Cle(etat.competence or choix.competence)
        local cle = choix.competence .. (inadaptee and " inadapté" or "")
        if not jets[cle] then
            local fixe, field = FixeDissipation(ctx.entity, choix.competence, inadaptee, choix.niveau, cfg.mult)
            local de = LCM.Roll.Des(field.dice.min or 0, field.dice.max or 0)
            jets[cle] = de + fixe
            Actions.Annoncer(string.format("[Rand %s] D%d : %d + %d = %d", cle, field.dice.max or 0, de, fixe, de + fixe))
        end
        local ok = jets[cle] >= (tonumber(etat.seuil) or 0)
        -- Un DOT ne part pas d'un bloc : battre son rand en retire un stack, et
        -- chaque point au-dessus en retire un de plus. On envoie donc le SCORE,
        -- et c'est le porteur qui compte — lui seul connait l'etat exact de ses
        -- stacks (9 octobre 2026).
        local estDot = etat.stacks ~= nil
        local partis
        if ok then
            reussis = reussis + 1
            local c = s.cible
            if c.soi then
                if estDot and LCM.Dot then partis = LCM.Dot.Dissiper(ctx.entity, etat.id, jets[cle])
                else LCM.EtatsTemporaires.Retirer(ctx.entity, etat.id) end
            elseif c.pnj and (c.mj or LCM.PlayerId()) == LCM.PlayerId() then
                local instance = LCM.Incarnation.Instance(c.id)
                if instance then
                    if estDot and LCM.Dot then partis = LCM.Dot.Dissiper(instance, etat.id, jets[cle])
                    else LCM.EtatsTemporaires.Retirer(instance, etat.id) end
                end
            else
                LCM.Reseau.Envoyer("dissipe", { id = etat.id, p = c.pnj and c.id or nil, nom = etat.nom,
                    sc = estDot and jets[cle] or nil },
                    "WHISPER", c.pnj and c.mj or c.id)
            end
        end
        local verdict
        if not ok then verdict = "échec"
        elseif estDot then
            -- Chez un autre joueur, c'est lui qui compte : on annonce ce qu'on
            -- sait plutot que d'inventer un nombre.
            verdict = partis and string.format("%d stack%s dissipé%s", partis,
                partis > 1 and "s" or "", partis > 1 and "s" or "") or "stacks dissipés"
        else verdict = "dissipé" end
        resultats[#resultats + 1] = string.format("%s%s : %d contre %d -> %s", tostring(etat.nom),
            s.cible.soi and "" or (" (" .. tostring(s.cible.nom) .. ")"), jets[cle], tonumber(etat.seuil) or 0,
            verdict)
    end
    local qui = LCM.Identite.NomEnJeu(ctx.entity)
    Actions.Annoncer(string.format("%s dissipe (%s, niveau %d) : %s.", qui, choix.competence, choix.niveau,
        table.concat(resultats, " ; ")))
    ctx.vars.dispelSuccess, ctx.vars.dispelCount = reussis, #selection
    Journal(ctx, "Dissipation : " .. table.concat(resultats, " ; "))
    return reussis
end

function Pas.dispel(etape, ctx, suite)
    if not Actions.onDissiper then return Arreter(ctx, "aucune fenêtre pour dissiper.") end
    local cfg = Actions.ConfigDissipation(etape, ctx)
    Actions.onDissiper(ctx, cfg, function(selection, choix)
        if not selection or #selection == 0 or not choix then return Arreter(ctx, "dissipation annulée.") end
        if Actions.Dissiper(ctx, cfg, selection, choix) == false then
            return Arreter(ctx, "PA indisponibles pendant ce round.")
        end
        local emote = choix.emoteAction
        if emote and tostring(emote.texte or ""):match("%S") then
            Actions.DireEmoteAction(emote.texte, emote.canal)
        end
        suite()
    end)
end

-- Les valeurs declarees qui sont des degats ou des couts s'ecrivent en entiers
-- (les multiplicateurs laissent des virgules).
local function Entier(nom)
    local c = Cle(nom)
    return c:find("total") or c:find("cout") or c:find("perce") or c:find("degat")
end

-- ===== Declarer : choisir ses cibles, envoyer ==============================

-- Hors combat : soi, le groupe/raid et les PNJ de la scene. En combat, seuls
-- les combattants inscrits au roster sont ciblables. Chaque PNJ indique son MJ.
-- Les joueurs s'affichent sous le nom de leur PERSONNAGE actif (4 octobre
-- 2026) : le sien meme quand on incarne un PNJ, celui des autres tel que leur
-- addon l'annonce (Core/Presence.lua) ; le nom WoW a defaut. L'identifiant,
-- lui, reste le nom WoW : c'est l'adresse des messages.
local function Court(nom) return tostring(nom or ""):match("^([^-]+)") or tostring(nom or "") end

function Actions.Cibles()
    local moi = LCM.PlayerId()
    local perso = LCM.Entities.Personnage()
    local etat = LCM.Combat.Etat()
    local joueurs, pnj, vus = {}, {}, {}
    local function AjouterPNJ(e, mj)
        if not e or not e.id or vus[e.id] then return end
        vus[e.id] = true
        pnj[#pnj + 1] = { id = e.id, nom = e.nom, icone = e.icone, mj = e.mj or mj }
    end
    if etat then
        for _, e in ipairs(etat.entrees or {}) do
            if e.pnj then
                AjouterPNJ(e, etat.mj)
            elseif e.id then
                local soi = Court(e.id) == Court(moi)
                joueurs[#joueurs + 1] = { id = e.id, soi = soi,
                    nom = soi and (perso and perso.name or (UnitName and UnitName("player")) or moi)
                        or LCM.Presence.Personnage(e.id) or e.nom or e.id }
            end
        end
    else
        joueurs[1] = { id = moi, soi = true,
                       nom = perso and perso.name or (UnitName and UnitName("player")) or moi }
        for _, m in ipairs(LCM.Combat.Membres()) do
            if m ~= moi and Court(m) ~= Court(moi) then
                joueurs[#joueurs + 1] = { id = m, nom = LCM.Presence.Personnage(m) or m }
            end
        end
    end
    if not etat then
        for _, e in ipairs(LCM.Scene.Liste()) do AjouterPNJ(e) end
    end
    return joueurs, pnj
end

-- Ce qu'un BAREME de cibles rend, pour ce nombre de cibles. Les paliers
-- jusqu'au dernier, puis la part de chaque cible en plus
-- (Data/Equilibrage.lua, E.cibles). Nil si le bareme n'existe pas.
function Actions.Bareme(nom, nombre)
    local bareme = (LCM.Equilibrage.cibles or {})[tostring(nom or "")]
    if not bareme then return nil end
    nombre = math.max(0, math.floor(tonumber(nombre) or 0))
    if nombre == 0 then return 0, 0 end
    local paliers = bareme.paliers or {}
    local dernier = #paliers
    if dernier == 0 then return 0, 0 end
    if nombre <= dernier then
        local p = paliers[nombre]
        return tonumber(p.pa) or 0, tonumber(p.pf) or 0
    end
    local p, enPlus = paliers[dernier], bareme.enPlus or {}
    local sup = nombre - dernier
    return (tonumber(p.pa) or 0) + (tonumber(enPlus.pa) or 0) * sup,
           (tonumber(p.pf) or 0) + (tonumber(enPlus.pf) or 0) * sup
end

-- Le supplement par cible. Trois regles, dans cet ordre :
--
--   * le BAREME que l'action demande (`baremeCibles=multicible`), un prix par
--     nombre de cibles qui n'a pas a etre lineaire (le MJ, 21 octobre 2026) ;
--   * le cout lineaire qu'elle declare (`pac=` / `pfc=`) ;
--   * sinon la regle historique de Necronicon, +1 PA / +1 PF par cible au-dela
--     de la premiere, quand l'action ne dit rien et n'est pas monocible.
function Actions.Supplement(ctx, nombre, mono)
    local V = ctx.vars
    local bareme = tostring(V.baremeCibles or "")
    if bareme ~= "" then
        local n = mono and math.min(nombre, 1) or nombre
        local pa, pf = Actions.Bareme(bareme, n)
        if pa then return pa, pf end
    end
    local pac, pfc = tonumber(V._coutPAC) or 0, tonumber(V._coutPFC) or 0
    if pac ~= 0 or pfc ~= 0 then
        if mono then nombre = math.min(nombre, 1) end
        local nombrePA = V._coutPAParCible and math.max(0, nombre - 1) or nombre
        return pac * math.floor(nombrePA / math.max(1, tonumber(V._coutPACPer) or 1)),
               pfc * math.floor(nombre / math.max(1, tonumber(V._coutPFCPer) or 1))
    end
    if mono then return 0, 0 end
    local extra = math.max(0, nombre - 1)
    return extra, extra
end

local function Jeton_()
    return string.format("%d%04d", math.floor((GetTime and GetTime() or 0) * 1000) % 1000000, math.random(0, 9999))
end

-- Envoie la declaration a chaque cible. Un PNJ est resolu par le MJ, sur la
-- fiche du PNJ : chez lui si c'est nous, sinon on lui envoie.
local function Envoyer(ctx, joueurs, pnj, soi)
    local d = ctx.declaration
    -- Signe du nom de la fiche qui agit : l'assassin incarne, pas le joueur.
    local paquet = { t = Jeton_(), n = d.nature, a = LCM.PlayerId(), rp = LCM.Identite.NomEnJeu(ctx.entity),
                     v = d.valeurs }
    -- Qui l'action vise : une deviation par un tiers en depend (malus « action
    -- visant autrui »), et les cibles d'origine sont prevenues d'un detour.
    local visees = {}
    for _, j in ipairs(joueurs) do visees[#visees + 1] = j end
    for _, p in ipairs(pnj) do visees[#visees + 1] = "PNJ " .. tostring(p.nom) end
    if soi then visees[#visees + 1] = LCM.PlayerId() end
    paquet.ci = table.concat(visees, ",")
    for _, joueur in ipairs(joueurs) do
        LCM.Reseau.Envoyer("act", paquet, "WHISPER", joueur)
    end
    for _, p in ipairs(pnj) do
        local copie = LCM.Copie(paquet)
        copie.p, copie.pn = p.id, p.nom
        local mj = p.mj or LCM.PlayerId()
        if mj == LCM.PlayerId() then
            Actions.Recevoir(copie, LCM.PlayerId())
        else
            LCM.Reseau.Envoyer("act", copie, "WHISPER", mj)
        end
    end
    if soi then Actions.Recevoir(LCM.Copie(paquet), LCM.PlayerId()) end
end

-- ===== Les effets : controles et etats ======================================
-- Pas « effect » de Necronicon : un effet FIXE (Immobilisation, Entrave,
-- Attraction...). Il prepare l'etat a poser ; la declaration qui suit fait le
-- jet du lanceur, le ciblage, et envoie. La cible resiste (un debuff) ou
-- accepte (un buff), puis l'etat se pose — ou, pour un effet narratif, un
-- message dit ce qui arrive (« repousse de 6 m »).


function Pas.effect(etape, ctx, suite)
    local V = ctx.vars
    local function Sub(x) return Trim(Actions.Substituer(tostring(x or ""), ctx)) end
    -- Les variables de l'effet, calculees avant le reste ; « |max 90 » borne.
    for _, p in ipairs(Paires(etape.effectVars)) do
        local expr, borne, valeur = p.v:match("^(.-)%s*|%s*(m%a%a)%s*([%-%d%.]+)%s*$")
        expr = expr or p.v
        local v = Actions.Evaluer(expr, ctx)
        if v then
            if borne == "max" then v = math.min(v, tonumber(valeur)) end
            if borne == "min" then v = math.max(v, tonumber(valeur)) end
            V[p.k] = math.floor(v + 0.5)
        end
    end
    local donnees = {}
    for _, p in ipairs(Paires(Sub(etape.effectData))) do donnees[p.k] = tonumber(p.v) or p.v end
    local duree = tonumber(Sub(etape.effectDuration)) or Actions.Evaluer(Sub(etape.effectDuration), ctx) or 0
    local oui = function(x) return Cle(Sub(x)):match("^[o1ty]") ~= nil end
    -- Jet du lanceur : de + arrondi((valeur + niveau) x mecanique).
    local bonus = Trim(etape.effectRollBonus) ~= "" and (Actions.Evaluer(etape.effectRollBonus, ctx) or 0)
        or (tonumber(V.niveauSort) or 0)
    local mult = Trim(etape.effectRollMult) ~= "" and Actions.Evaluer(etape.effectRollMult, ctx) or tonumber(V.mecaMult) or 1
    ctx.effet = {
        debuff = Cle(Sub(etape.effectMode)) ~= "buff",
        nom = Sub(etape.effectName) ~= "" and Sub(etape.effectName) or "État",
        icone = Sub(etape.effectIcon), description = Sub(etape.effectDesc),
        donnees = donnees, rounds = duree > 0 and math.floor(duree + 0.5) or nil,
        resistance = Sub(etape.effectResist) ~= "" and Sub(etape.effectResist) or "Esprit, Adresse",
        critEcart = tonumber(Sub(etape.effectCritMargin)) or 10,
        critFacteur = tonumber(Sub(etape.effectCritFactor)) or 2,
        narratif = oui(etape.effectNarrative), texte = Trim(etape.effectText or ""),
        montant = math.floor((tonumber(Montant(etape.effectAmount, ctx)) or 0) + 0.5),
        unite = Sub(etape.effectUnit),
        -- Necronicon : `effectForcedMove` sur un effet narratif, dont `amount`
        -- donne les metres (ActionResolution.lua, `_buffForcedMove`).
        deplacementForce = oui(etape.effectForcedMove),
        bonusJet = tonumber(bonus) or 0, multJet = (tonumber(mult) or 1) > 0 and tonumber(mult) or 1,
        dissipation = Sub(etape.effectDispellTag),
        conteneur = Sub(etape.effectContainer),
        controle = Sub(etape.effectControl),
        controleA = Sub(etape.effectControlA), controleB = Sub(etape.effectControlB),
        controleTexte = Sub(etape.effectControlText),
    }
    V._buffData = donnees
    Journal(ctx, string.format("Effet « %s » (%s%s)", ctx.effet.nom, ctx.effet.debuff and "débuff" or "buff",
        ctx.effet.narratif and ", narratif" or ""))
    return suite()
end

-- Le jet du lanceur d'un effet : le de de la competence, et sa part fixe
-- (valeur, apports, bonus portes, niveau du sort) multipliee par la mecanique.
local function JetEffet(ctx, nom)
    local field = ChampParLibelle(nom, "roll")
    if not field then return nil end
    local r = LCM.Roll.Field(ctx.entity, field.id)
    local e = ctx.effet
    local fixe = math.floor((r.valeur + r.apport + r.bonus + e.bonusJet) * e.multJet + 0.5)
    local total = r.garde + fixe
    return total, string.format("[Rand %s] D%d : %d + (%d stat + %d niveau) x %d %% = %d", field.label,
        r.des.max, r.garde, r.valeur + r.apport + r.bonus, e.bonusJet, math.floor(e.multJet * 100 + 0.5), total)
end

local function DeclarerEffet(etape, ctx, suite)
    local e, V = ctx.effet, ctx.vars
    if not CiblageEffetValide(V) then
        return Arreter(ctx, "Il faut choisir un mode de ciblage.")
    end
    local paquet = {
        t = Jeton_(), a = LCM.PlayerId(), rp = LCM.Identite.NomEnJeu(ctx.entity), nom = e.nom, ic = e.icone, desc = e.description,
        deb = e.debuff and 1 or nil, nar = e.narratif and 1 or nil, txt = e.texte, mt = e.montant, u = e.unite,
        r = e.rounds, res = e.resistance, ce = e.critEcart, cf = e.critFacteur, dis = e.dissipation,
        -- `ct` : le volet de Sante qui recoit. Deux lettres, parce que le
        -- paquet se decoupe a 255 octets.
        ct = e.conteneur ~= "etat" and e.conteneur or nil,
        types = table.concat((function()
            local t = {}
            for _, k in ipairs({ "Type Physique", "Type Elementaire", "Type Cosmologie" }) do
                if Trim(V[k]) ~= "" then t[#t + 1] = Trim(V[k]) end
            end
            return t
        end)(), ", "),
        kp = tonumber(V.kPen) or tonumber(V.penCoef) or 0, d = e.donnees,
        -- `fm` : cet effet POUSSE. Le montant (`mt`) devient alors des metres a
        -- franchir, et la cible ouvre sa jauge de deplacement force.
        fm = e.deplacementForce and 1 or nil,
        ctl = Trim(e.controle) ~= "" and e.controle or nil,
        -- Identité de l'ACTEUR, distincte du client qui transmet. Un MJ qui
        -- incarne un PNJ doit provoquer/intimider au nom de ce PNJ, pas au nom
        -- de son personnage joueur.
        cs = ctx.entity and ctx.entity.kind == "npc" and ("p:" .. tostring(ctx.entity.id))
            or ("j:" .. tostring(LCM.PlayerId())),
        c1 = Trim(e.controleA) ~= "" and e.controleA or nil,
        c2 = Trim(e.controleB) ~= "" and e.controleB or nil,
        nt = Trim(e.controleTexte) ~= "" and e.controleTexte or nil,
        cu = e.cumul and { n = e.cumul.n, j = e.cumul.jauge, p = e.cumul.pct } or nil,
        gu = e.guerison and { m = e.guerison.mode, c = e.guerison.competence, d = e.guerison.dc } or nil,
    }
    ctx.annonces = {}

    -- La Projection allonge ce qu'on PROJETTE. Une poussee declare sa distance
    -- ici et nulle part ailleurs (`fm` dit qu'elle pousse, `mt` dit de combien)
    -- : c'est donc le seul endroit ou le gain se pose, sans rien demander au
    -- contenu. L'effet nomme sa mecanique, la mecanique dit quelle expertise
    -- l'allonge (11 octobre 2026).
    if e.deplacementForce and LCM.Expertises then
        local poussee = Mecanique(e.nom)
        local gain = poussee and LCM.Expertises.BonusPortee(ctx.entity, poussee.id) or 0
        local base = tonumber(paquet.mt)
        if gain > 0 and base then
            -- Arrondi a l'inferieur : un demi-yard ne s'annonce pas.
            local allonge = math.floor(base + gain)
            if allonge ~= base then
                paquet.mt = allonge
                Actions.Annoncer(string.format("%s : %s → %s %s (Projection)",
                    tostring(e.nom), Nombre(base), Nombre(allonge),
                    Trim(e.unite) ~= "" and e.unite or "m"), ctx)
            end
        end
    end

    local nomJet = Trim(V.randSkill)
    if nomJet ~= "" then
        local total, ligne = JetEffet(ctx, nomJet)
        if total then
            paquet.js, paquet.jr = nomJet, total
            Actions.Annoncer(ligne, ctx)
        else
            Noter(ctx, "jet:" .. nomJet)
        end
    end
    local annonce = tostring(etape.announce or ""):lower():match("^[o1ty]") ~= nil
    local mode = Cle(V.cibleMode)
    local mono = mode:find("mono") ~= nil
    ctx.declaration = { nature = e.nom, valeurs = {}, ordre = {} }

    local function Envoyer_(joueurs, pnj, soi)
        if LCM.Influences and LCM.Influences.PreparerCibles then
            local ok, raison, j2, p2, s2 = LCM.Influences.PreparerCibles(ctx, joueurs, pnj, soi)
            if not ok then
                ctx.annonces = nil
                return Arreter(ctx, raison)
            end
            joueurs, pnj, soi = j2, p2, s2
        end
        local function Finaliser()
            local nombre = #joueurs + #pnj + (soi and 1 or 0)
            local epa, epf = Actions.Supplement(ctx, nombre, mono)
            ctx.dettes = ctx.dettes or {}
            if epa > 0 then ctx.dettes[#ctx.dettes + 1] = { tag = "#pa", montant = epa } end
            if epf > 0 then ctx.dettes[#ctx.dettes + 1] = { tag = "#fatigue", montant = epf } end
            if not Regler(ctx) then return Arreter(ctx, "PA indisponibles pendant ce round.") end
            local attente = ctx.annonces
            ctx.annonces = nil
            for _, texte in ipairs(attente) do Actions.Annoncer(texte) end
            if annonce then
                Actions.Annoncer(string.format("%s lance %s : %s.", LCM.Identite.NomEnJeu(ctx.entity),
                    e.debuff and "un débuff" or "un buff", e.nom))
            end
            for _, j in ipairs(joueurs) do LCM.Reseau.Envoyer("etat", paquet, "WHISPER", j) end
            for _, p in ipairs(pnj) do
                local copie = LCM.Copie(paquet)
                copie.p, copie.pn = p.id, p.nom
                local mj = p.mj or LCM.PlayerId()
                if mj == LCM.PlayerId() then Actions.RecevoirEtat(copie, LCM.PlayerId())
                else LCM.Reseau.Envoyer("etat", copie, "WHISPER", mj) end
            end
            if soi then Actions.RecevoirEtat(LCM.Copie(paquet), LCM.PlayerId()) end
            local noms = {}
            for _, p in ipairs(pnj) do noms[#noms + 1] = p.id end
            ctx.cibles = { joueurs = joueurs, pnj = noms, soi = soi }
            Journal(ctx, string.format("%s « %s » envoyé à %d cible%s.", e.debuff and "Débuff" or "Buff", e.nom,
                nombre, nombre > 1 and "s" or ""))
            if Actions.onDeclaration then Actions.onDeclaration(ctx) end
            return suite()
        end

        -- Le contrôle mental n'existe réellement qu'après relecture du MJ.
        -- Tant qu'il n'a pas répondu, on conserve annonces et dettes en
        -- mémoire : aucun PA/PF n'est consommé, aucun jet n'est publié.
        if paquet.ctl == "controle_mental" and LCM.Influences and LCM.Influences.SoumettreControleMental then
            return LCM.Influences.SoumettreControleMental(paquet, joueurs, pnj, soi, function(ok, narration, raison)
                if not ok then
                    ctx.annonces = nil
                    return Arreter(ctx, raison or "contrôle mental refusé par le MJ.")
                end
                paquet.nt = Trim(narration) ~= "" and Trim(narration) or paquet.nt
                Finaliser()
            end)
        end
        return Finaliser()
    end

    if mode:find("aoe") then
        local joueurs, pnj = Actions.Cibles()
        local autres = {}
        for _, j in ipairs(joueurs) do if not j.soi then autres[#autres + 1] = j.id end end
        if mode:find("cond") and Actions.onEmote then
            return Actions.onEmote("Condition de la zone",
                "Décrivez la condition de déclenchement / la portée de l'effet. Ce texte part dans le chat à la suite du jet.",
                function() Envoyer_(autres, pnj, true) end)
        end
        return Envoyer_(autres, pnj, true)
    end
    if not Actions.onCibler then return Arreter(ctx, "aucune fenêtre pour choisir les cibles.") end
    Actions.onCibler(ctx, mono, function(joueurs, pnj, soi)
        if not joueurs then
            ctx.annonces = nil
            return Arreter(ctx, "déclaration annulée.")
        end
        Envoyer_(joueurs, pnj, soi)
    end)
end

-- ===== Recevoir un effet ===================================================
-- Le paquet : { t, a, rp, nom, ic, desc, deb, nar, txt, mt, u, r, res, ce,
-- cf, dis, types, kp, d = donnees, js/jr = jet du lanceur, p/pn = PNJ vise }.

Actions.effetsRecus = {}

function Actions.RecevoirEtat(paquet, expediteur)
    if type(paquet) ~= "table" then return false end
    if expediteur ~= LCM.PlayerId() and not LCM.Fiches.DansLeGroupe(expediteur) then return false end
    local entity
    if paquet.p then
        if not LCM.IsMaster() then return false end
        entity = LCM.Incarnation.Instance(paquet.p)
        if not entity then return false end
    else
        -- Adresse au joueur : son personnage, pas le PNJ qu'il incarne.
        entity = LCM.Entities.Personnage()
    end
    local recu = { paquet = paquet, expediteur = expediteur, entity = entity, debuff = paquet.deb ~= nil }
    -- La resistance aux types de l'effet : la moyenne des resistances de la
    -- cible, multipliee par le coefficient de penetration du lanceur.
    local somme, n = 0, 0
    for nom in tostring(paquet.types or ""):gmatch("[^,]+") do
        local v = ValeurType(Trim(nom), "Résistances", entity)
        if v then somme, n = somme + v, n + 1 end
    end
    recu.bonusResistance = (n > 0 and (tonumber(paquet.kp) or 0) > 0) and math.floor(somme / n * tonumber(paquet.kp) + 0.5) or 0
    -- On resiste avec la competence du lanceur s'il en a lance une, sinon au
    -- choix parmi Esprit et Adresse.
    local competences = {}
    if Trim(paquet.js) ~= "" and paquet.jr then
        competences = { Trim(paquet.js) }
    else
        for nom in tostring(paquet.res or ""):gmatch("[^,]+") do
            local c = Cle(nom)
            if c == "esprit" or c == "adresse" then competences[#competences + 1] = Trim(nom) end
        end
        if #competences == 0 then competences = { "Esprit", "Adresse" } end
    end
    recu.competences = competences
    Actions.effetsRecus[#Actions.effetsRecus + 1] = recu
    if Actions.onEffetRecu then Actions.onEffetRecu(recu) end
    return true
end

-- Les effets chiffres, resolus pour la cible : « -100%Terrestre » devient le
-- nombre que vaut 100 % de SA valeur Terrestre.
local function Bonus(donnees, entity, facteur)
    local bonus, inconnus = {}, {}
    for cle, v in pairs(donnees or {}) do
        -- « @nage » : un identifiant de champ exact (le constructeur de buff) ;
        -- « nage » : une cle d'effet du template, qui veut dire le DEPLACEMENT
        -- Nage — pas l'expertise du meme nom.
        local exact = tostring(cle):match("^@(.+)$")
        local champ = exact and LCM.Schema.Field(exact) and exact
            or CHAMPS_EFFET[Cle(cle)] or (ChampParLibelle(cle) and ChampParLibelle(cle).id)
        local n = tonumber(v)
        if n == nil then
            local pct, nom = tostring(v):match("^%s*([%-%+]?%d+%.?%d*)%s*%%%s*(.-)%s*$")
            if pct then
                local cible = CHAMPS_EFFET[Cle(nom)] or (ChampParLibelle(nom) and ChampParLibelle(nom).id)
                local base = cible and tonumber(LCM.Entities.Get_Value(entity, cible)) or 0
                n = tonumber(pct) < 0 and -math.ceil(math.abs(base * tonumber(pct) / 100) - 1e-9)
                    or math.floor(base * tonumber(pct) / 100 + 0.5)
            end
        end
        if champ and n and n ~= 0 then bonus[champ] = (bonus[champ] or 0) + n
        elseif n and n ~= 0 then inconnus[#inconnus + 1] = cle end
    end
    return bonus, inconnus
end

local function Retirer(recu)
    for i, r in ipairs(Actions.effetsRecus) do if r == recu then table.remove(Actions.effetsRecus, i) break end end
end

-- L'effet passe : un message pour un effet narratif, un etat pose sinon. Un
-- echec de 10 ou plus a la resistance double la distance ou la duree.
function Actions.Subir(recu, ecart)
    Retirer(recu)
    local p = recu.paquet
    local facteur = (tonumber(p.ce) or 0) > 0 and (tonumber(p.cf) or 1) > 1 and ecart and ecart >= tonumber(p.ce)
        and tonumber(p.cf) or 1
    local cible = p.p and (p.pn or p.p) or LCM.Identite.NomEnJeu(recu.entity)
    local lanceur = Trim(p.rp) ~= "" and p.rp or p.a
    local texte
    if p.nar then
        local montant = math.floor((tonumber(p.mt) or 0) * facteur + 0.5)
        texte = Trim(p.txt) ~= "" and p.txt or "{target} subit « " .. tostring(p.nom) .. " » de {caster}."
        texte = texte:gsub("{caster}", lanceur):gsub("{target}", cible):gsub("{amount}", tostring(montant))
                     :gsub("{unit}", tostring(p.u or ""))
        if facteur > 1 then texte = texte .. " (critique)" end
        Actions.Annoncer(texte)
        -- Un effet qui pousse : la jauge s'ouvre chez celui qui encaisse, et
        -- compte les metres a sa place. Pas pour un PNJ : c'est le MJ qui le
        -- deplace, il n'a pas de personnage a bouger.
        if p.fm and montant > 0 and not p.p and LCM.DeplacementForce then
            LCM.DeplacementForce.Demarrer(montant, tostring(p.nom or "Déplacement forcé"))
        end
    else
        local bonus, inconnus = Bonus(p.d, recu.entity, facteur)
        local rounds = tonumber(p.r) and math.floor(tonumber(p.r) * facteur + 0.5) or nil
        local cumul = type(p.cu) == "table" and { n = tonumber(p.cu.n) or 1, jauge = p.cu.j, pct = tonumber(p.cu.p) or 5 } or nil
        local nomEtat, description = p.nom, p.desc
        if p.ctl == "intimidation" then nomEtat = "Intimidé par " .. lanceur
        elseif p.ctl == "provocation" then nomEtat = "Provoqué par " .. lanceur
        elseif p.ctl == "peur" then nomEtat = "Terrifié"
        elseif p.ctl == "illusion" then nomEtat = "Confus par une illusion"
        elseif p.ctl == "controle_mental" then
            nomEtat = "Sous contrôle mental"
            description = Trim(p.nt) ~= "" and p.nt or description
        end
        -- Un paquet qui porte `dt` est un DOT : ce n'est pas un malus de
        -- statistique mais une morsure qui revient chaque round, et c'est
        -- Core/Dot.lua qui sait la composer (sa duree et ses stacks viennent de
        -- ce qu'on a depense, pas du paquet).
        if type(p.dt) == "table" and LCM.Dot then
            LCM.Dot.Poser(recu.entity, {
                nom = nomEtat, icone = p.ic, description = description,
                choix = p.dt, lanceur = lanceur, id = p.t, conteneur = p.ct,
                dissipation = p.dis,
                jet = { competence = p.js, valeur = tonumber(p.jr) or 0 },
            })
            texte = string.format("Dot « %s » appliqué à %s.", tostring(nomEtat), cible)
        else
        LCM.EtatsTemporaires.Poser(recu.entity, { nom = nomEtat, icone = p.ic, description = description, bonus = bonus,
            rounds = rounds, lanceur = lanceur, debuff = recu.debuff, dissipation = p.dis, cumul = cumul,
            id = p.t, jet = p.js and { competence = p.js, valeur = tonumber(p.jr) or 0 } or nil,
            conteneur = p.ct,
            guerison = type(p.gu) == "table" and { mode = p.gu.m, competence = p.gu.c, dc = tonumber(p.gu.d) or 0 } or nil,
            controle = p.ctl and { type = p.ctl, source = p.cs or ("j:" .. tostring(p.a)), sourceNom = lanceur,
                seuil = tonumber(p.jr) or 0, bonus = 0, acteurA = p.c1, acteurB = p.c2,
                narration = p.nt, prochainHorsCombat = (GetTime and GetTime() or 0) + 20 * 60 } or nil })
        texte = string.format("%s « %s » appliqué à %s (%s)%s.", recu.debuff and "Débuff" or "Buff", tostring(nomEtat),
            cible, rounds and (rounds .. " round" .. (rounds > 1 and "s" or "")) or "jusqu'à retrait",
            facteur > 1 and " — critique, durée doublée" or "")
        end
        if #inconnus > 0 then
            LCM.Alerte(string.format("« %s » : effets sans champ sur la fiche, ignorés — %s", tostring(p.nom),
                table.concat(inconnus, ", ")))
        end
        LCM.Info(texte)
    end
    if recu.expediteur ~= LCM.PlayerId() then
        LCM.Reseau.Envoyer("act=", { t = p.t, texte = texte }, "WHISPER", recu.expediteur)
    end
    if Actions.onResolu then Actions.onResolu() end
    return texte
end

-- Resister a un debuff : la competence, plus le bonus de resistance, contre le
-- jet du lanceur. Egal ou mieux : resiste.
function Actions.Resister(recu, competence)
    local p = recu.paquet
    local field = ChampParLibelle(competence, "roll")
    if not field then return nil end
    local r = LCM.Roll.Field(recu.entity, field.id)
    local total = r.total + recu.bonusResistance
    local oppose = tonumber(p.jr) or 0
    local resiste = total >= oppose
    local cible = p.p and (p.pn or p.p) or LCM.Identite.NomEnJeu(recu.entity)
    local ligne = string.format("%s %s %s de %s (jet %d contre %d)%s.", cible, resiste and "résiste" or "succombe",
        p.nar and "à l'effet" or "au débuff", Trim(p.rp) ~= "" and p.rp or "l'adversaire", total, oppose,
        (not resiste and oppose - total >= (tonumber(p.ce) or 0) and (tonumber(p.ce) or 0) > 0)
            and " — échec critique, effet doublé" or "")
    Actions.Annoncer(LCM.Roll.Describe(r) .. (recu.bonusResistance ~= 0 and string.format("  +%d (résistance)", recu.bonusResistance) or ""))
    Actions.Annoncer(ligne)
    if resiste then
        Retirer(recu)
        if recu.expediteur ~= LCM.PlayerId() then
            LCM.Reseau.Envoyer("act=", { t = p.t, texte = ligne }, "WHISPER", recu.expediteur)
        end
        if Actions.onResolu then Actions.onResolu() end
        return false
    end
    Actions.Subir(recu, oppose - total)
    return true
end

-- Refuser un buff (ou ignorer un effet).
function Actions.Refuser(recu)
    Retirer(recu)
    if recu.expediteur ~= LCM.PlayerId() then
        LCM.Reseau.Envoyer("act=", { t = recu.paquet.t,
            texte = string.format("%s refuse « %s ».", LCM.Identite.NomEnJeu(recu.entity),
                tostring(recu.paquet.nom)) }, "WHISPER", recu.expediteur)
    end
    if Actions.onResolu then Actions.onResolu() end
end

-- ===== La retenue ==========================================================
--
-- Les degats d'une attaque sont calcules, et on frappait toujours a fond : rien
-- ne permettait de retenir son coup (17 octobre 2026). La retenue est un
-- pourcentage choisi juste avant de declarer, applique aux deux totaux.
--
-- Une action est retenable si sa declaration porte un Total Critique : c'est
-- ce qui distingue un coup (attaque, perce-armure, brise-armure) d'un soin ou
-- d'un bouclier, qui ne declarent qu'un Total Normal.
--
-- Arrondi au superieur, minimum 1 : retenir son coup n'est pas le rater.

-- Les variables qui portent les deux totaux declares (`tnorm`, `tcrit`), ou
-- nil si l'action n'est pas un coup.
function Actions.SortiesRetenables(ctx)
    local sorties, critique = {}, false
    for _, etape in ipairs(ctx and ctx.etapes or {}) do
        if etape.type == "declare" then
            for _, p in ipairs(Paires(etape.declareTags)) do
                if p.k == "Total Normal" or p.k == "Total Critique" then
                    local var = Trim(p.v):match("^[Vv][Aa][Rr]%s*:%s*(.-)%s*$")
                    if var and var ~= "" then sorties[var] = true end
                    if p.k == "Total Critique" then critique = true end
                end
            end
        end
    end
    return critique and sorties or nil
end

function Actions.Retenable(ctx) return Actions.SortiesRetenables(ctx) ~= nil end

function Actions.Retenir(valeur, pourcentage)
    local v, pct = tonumber(valeur), tonumber(pourcentage)
    if not v or v <= 0 or not pct or pct >= 100 then return v end
    return math.max(1, math.ceil(v * math.max(0, pct) / 100 - 1e-9))
end

function Pas.declare(etape, ctx, suite)
    if ctx.effet then return DeclarerEffet(etape, ctx, suite) end
    if ctx.vars._buffData then return Arreter(ctx, "les buffs et débuffs ne se déclarent pas encore.") end
    local nature = Trim(Actions.Substituer(etape.nature, ctx))
    if nature == "" then nature = ctx.nom end
    ctx.annonces = {}

    -- La mecanique qu'on PRODUIT : c'est elle qui dit quelles expertises
    -- aident. La Projection porte la Repulsion, la Puissance porte l'attaque
    -- simple et le brise-armure (11 octobre 2026).
    local produite = Mecanique(nature)
    local supJet, supDetail = 0, nil
    if produite and LCM.Expertises then
        supJet, supDetail = LCM.Expertises.BonusAction(ctx.entity, produite.id)
    end

    -- {jet:Nom} : un vrai jet de la fiche, lance une fois par nom, annonce comme
    -- un jet ordinaire, puis remplace par son total.
    local jets = {}
    local brut = tostring(etape.declareTags or ""):gsub("{%s*[Jj][Ee][Tt]%s*:%s*([^}]-)%s*}", function(nom)
        nom = Trim(nom)
        if nom:find(":") then nom = tostring(Jeton("jet", nom, ctx) or "") end
        if nom == "" then return "0" end
        if not jets[nom] then
            local resultat = Actions.Jet(nom, ctx.entity)
            if resultat then
                jets[nom] = resultat.total + supJet
                local ligne = LCM.Roll.Describe(resultat)
                if supJet ~= 0 then
                    local bouts = {}
                    for _, d in ipairs(supDetail or {}) do
                        bouts[#bouts + 1] = string.format("%s %d", d.label, d.points)
                    end
                    ligne = string.format("%s  +%s (%s)", ligne, Nombre(supJet),
                        #bouts > 0 and table.concat(bouts, ", ") or "expertise")
                end
                Actions.Annoncer(ligne, ctx)
            else
                jets[nom] = 0
                Noter(ctx, "jet:" .. nom)
            end
        end
        return tostring(jets[nom])
    end)

    local valeurs, ordre = {}, {}
    for _, p in ipairs(Paires(brut)) do
        local v = Trim(Actions.Substituer(p.v, ctx))
        if v:find("[%+%*/]") then
            local r = Arithmetique(v)
            if r then v = tostring(r) end
        end
        if Entier(p.k) and tonumber(v) then v = tostring(math.floor(tonumber(v) + 0.5)) end
        valeurs[p.k] = v
        ordre[#ordre + 1] = p.k
    end
    -- La Puissance ajoute sa part aux DEGATS declares — pas au jet : elle dit
    -- la force du coup, pas la justesse. Les deux totaux sont touches, sinon
    -- un critique rendrait la Puissance inutile.
    if produite and LCM.Expertises then
        local part = LCM.Expertises.BonusDegats(ctx.entity, produite.id)
        if part > 0 then
            local touches = {}
            for _, cle in ipairs({ "Total Normal", "Total Critique" }) do
                local v = tonumber(valeurs[cle])
                if v and v > 0 then
                    local augmente = math.floor(v * (1 + part) + 0.5)
                    if augmente ~= v then
                        valeurs[cle] = tostring(augmente)
                        touches[#touches + 1] = string.format("%s %d → %d", cle, v, augmente)
                    end
                end
            end
            if #touches > 0 then
                Journal(ctx, string.format("Puissance : +%d %% — %s",
                    math.floor(part * 100 + 0.5), table.concat(touches, ", ")))
            end
        end
    end
    -- La retenue passe APRES la Puissance : elle dit ce qu'on choisit de
    -- frapper sur le coup qu'on porterait, Puissance comprise.
    local retenue = tonumber(ctx.retenue)
    if retenue and retenue < 100 and Actions.Retenable(ctx) then
        local touches = {}
        for _, cle in ipairs({ "Total Normal", "Total Critique" }) do
            local v = tonumber(valeurs[cle])
            local r = Actions.Retenir(v, retenue)
            if v and r ~= v then
                valeurs[cle] = tostring(r)
                touches[#touches + 1] = string.format("%s %d → %d", cle, v, r)
            end
        end
        if #touches > 0 then
            Journal(ctx, string.format("Retenue : %d %% — %s", retenue, table.concat(touches, ", ")))
        end
    end

    ctx.declaration = { nature = nature, valeurs = valeurs, ordre = ordre }
    local annonce = tostring(etape.announce or ""):lower():match("^[o1ty]") ~= nil
    local mode = Cle(ctx.vars.cibleMode)
    local mono = mode:find("mono") ~= nil

    -- Cibles choisies (ou zone) : c'est ICI que l'action est debitee, annoncee
    -- et envoyee. Une declaration annulee ne coute rien et ne dit rien.
    local function Declarer(joueurs, pnj, soi)
        if LCM.Influences and LCM.Influences.PreparerCibles then
            local ok, raison, j2, p2, s2 = LCM.Influences.PreparerCibles(ctx, joueurs, pnj, soi)
            if not ok then
                ctx.annonces = nil
                return Arreter(ctx, raison)
            end
            joueurs, pnj, soi = j2, p2, s2
        end
        local nombre = #joueurs + #pnj + (soi and 1 or 0)
        local epa, epf = Actions.Supplement(ctx, nombre, mono)
        ctx.dettes = ctx.dettes or {}
        if epa > 0 then ctx.dettes[#ctx.dettes + 1] = { tag = "#pa", montant = epa } end
        if epf > 0 then ctx.dettes[#ctx.dettes + 1] = { tag = "#fatigue", montant = epf } end
        if epa > 0 or epf > 0 then
            valeurs["Cout PA"] = tostring((tonumber(valeurs["Cout PA"]) or 0) + epa)
            valeurs["Cout PF"] = tostring((tonumber(valeurs["Cout PF"]) or 0) + epf)
        end
        if not Regler(ctx) then return Arreter(ctx, "PA indisponibles pendant ce round.") end
        local attente = ctx.annonces
        ctx.annonces = nil
        for _, texte in ipairs(attente) do Actions.Annoncer(texte) end
        if annonce then
            local qui = LCM.Identite.NomEnJeu(ctx.entity)
            Actions.Annoncer(string.format("%s déclare : %s", qui, nature))
        end
        Journal(ctx, string.format("Déclaration : %s (%d cible%s)", nature, nombre, nombre > 1 and "s" or ""))
        local noms = {}
        for _, p in ipairs(pnj) do noms[#noms + 1] = p.id end
        ctx.cibles = { joueurs = joueurs, pnj = noms, soi = soi }
        Envoyer(ctx, joueurs, pnj, soi)
        if Actions.onDeclaration then Actions.onDeclaration(ctx) end
        return suite()
    end

    if mode:find("aoe") then
        -- Une zone ne se cible pas : tout le monde la recoit, et chacun peut
        -- dire qu'il n'y est pas.
        local joueurs, pnj = Actions.Cibles()
        local autres = {}
        for _, j in ipairs(joueurs) do if not j.soi then autres[#autres + 1] = j.id end end
        valeurs.Zone = string.format("%s yards%s", tostring(math.floor((tonumber(ctx.vars.aoeYards) or 0) + 0.5)),
            mode:find("cond") and " (conditionnelle)" or "")
        -- Une zone conditionnelle : la condition s'ecrit en emote, a la suite
        -- du jet, avant que la zone parte (Necronicon : PromptChatEmote).
        if mode:find("cond") and Actions.onEmote then
            return Actions.onEmote("Condition de la zone",
                "Décrivez la condition de déclenchement / la portée de l'effet. Ce texte part dans le chat à la suite du jet.",
                function() Declarer(autres, pnj, true) end)
        end
        return Declarer(autres, pnj, true)
    end
    if not Actions.onCibler then return Arreter(ctx, "aucune fenêtre pour choisir les cibles.") end
    Actions.onCibler(ctx, mono, function(joueurs, pnj, soi)
        if not joueurs then
            ctx.annonces = nil
            return Arreter(ctx, "déclaration annulée.")
        end
        Declarer(joueurs, pnj, soi)
    end)
end

function Actions.Etape(etape, ctx, suite)
    if ctx.arretee then return end
    local pas = Pas[tostring(etape.type or "")]
    if not pas then
        return Arreter(ctx, string.format("l'étape « %s » (%s) n'est pas encore prise en charge.",
            Trim(etape.label) ~= "" and etape.label or tostring(etape.id), tostring(etape.type)))
    end
    return pas(etape, ctx, suite)
end

function Actions.Etapes(etapes, ctx, fin)
    local proprietaire = false
    if ctx.dettes == nil and not ctx.differe and ContientDeclaration(etapes) then
        ctx.dettes, ctx.differe, proprietaire = {}, true, true
    end
    local index = 0
    local function suivante()
        if ctx.arretee then return end
        index = index + 1
        local etape = etapes[index]
        if type(etape) ~= "table" then
            if proprietaire and not Regler(ctx) then return Arreter(ctx, "PA indisponibles pendant ce round.") end
            if fin then fin() end
            return
        end
        Actions.Etape(etape, ctx, suivante)
    end
    suivante()
end

local function Signaler(ctx)
    if ctx.inconnues and next(ctx.inconnues) then
        local liste = {}
        for k in pairs(ctx.inconnues) do liste[#liste + 1] = k end
        table.sort(liste)
        LCM.Alerte(string.format("%s : références inconnues de l'addon, comptées 0 — %s",
            ctx.nom, table.concat(liste, " ; ")))
    end
end

local function Contexte(resolution, entity, onFin)
    local feuille = resolution.feuilles[1]
    return {
        resolution = resolution, nom = resolution.label, icone = resolution.icone,
        entity = entity, vars = {}, journal = {}, effets = {}, feuilles = resolution.feuilles,
        etapes = feuille and feuille.etapes or {}, onFin = onFin,
    }
end

-- Joue une resolution du compendium pour une fiche. Retourne le contexte, qui
-- porte le journal, la declaration, et les references inconnues.
function Actions.Lancer(resolutionId, entity, onFin)
    -- Une action de bouton (Core/ActionsBoutons.lua) l'emporte : c'est le
    -- code qui fait foi, pas une entree du compendium au meme identifiant.
    local resolution = type(resolutionId) == "table" and resolutionId
        or (LCM.ActionsBoutons and LCM.ActionsBoutons.Get(resolutionId))
        or LCM.Resolutions.Get(resolutionId)
    if not resolution then
        LCM.Alerte("action inconnue : " .. tostring(resolutionId))
        return nil
    end
    if resolution.categorie == "mj" and not LCM.IsMaster() then
        LCM.Alerte(resolution.label .. " : réservé au maître du jeu.")
        return nil
    end
    -- Une entree de RECEPTION lancee d'un bouton (Resolution Test MJ) : comme
    -- Necronicon (TriggerCompendiumActionResolutionEntry), on se la propose a
    -- soi, avec un paquet vide.
    if not resolution.emission then
        local nature = tostring(resolution.natures or resolution.label):match("^[^,;]+") or resolution.label
        local paquet = { t = Jeton_(), n = Trim(nature), a = LCM.PlayerId(), v = {} }
        Actions.Recevoir(paquet, LCM.PlayerId(), resolution)
        return nil
    end
    local ctx = Contexte(resolution, entity or LCM.Entities.Self(), onFin)
    if #ctx.etapes == 0 then
        Arreter(ctx, "aucune étape.")
        return ctx
    end
    Actions.Etapes(ctx.etapes, ctx, function()
        Signaler(ctx)
        if ctx.onFin then ctx.onFin(ctx) end
    end)
    return ctx
end

-- ===== Recevoir une action =================================================
-- Le paquet : { t = jeton, n = nature, a = attaquant, rp = son nom, v = valeurs,
-- p = PNJ vise (instance), pn = son nom }.

-- La resolution qui repond a une nature (« Attaque » -> Defense). Une entree
-- d'EMISSION (le composeur d'attaque) n'en est jamais une : se cibler soi-meme
-- rouvrirait le composeur.
function Actions.ResolutionPour(nature)
    local voulu = Cle(nature)
    if voulu == "" then return nil end
    -- Les receptions ecrites dans le code d'abord (Data/Receptions.lua), puis
    -- celles qu'un MJ aurait creees au compendium.
    local listes = { LCM.ActionsBoutons and LCM.ActionsBoutons.list or {}, LCM.Resolutions.list }
    for _, liste in ipairs(listes) do
        for _, r in ipairs(liste) do
            if not r.emission then
                for morceau in tostring(r.natures or ""):gmatch("[^,;\n]+") do
                    if Cle(morceau) == voulu then return r end
                end
            end
        end
    end
end

Actions.recus = {}

function Actions.Recevoir(paquet, expediteur, resolutionImposee)
    if type(paquet) ~= "table" then return false end
    local moi = LCM.PlayerId()
    if expediteur ~= moi and not LCM.Fiches.DansLeGroupe(expediteur) then return false end
    local entity
    if paquet.p then
        -- Un PNJ vise : seul le MJ le resout, sur sa fiche a lui.
        if not LCM.IsMaster() then return false end
        entity = LCM.Incarnation.Instance(paquet.p)
        if not entity then
            LCM.Alerte(string.format("%s vise %s, qui n'est plus en jeu.", tostring(paquet.rp or paquet.a),
                tostring(paquet.pn or paquet.p)))
            return false
        end
    else
        -- Adresse au joueur : son PERSONNAGE resout, avec ses stats, meme si
        -- le MJ incarne un PNJ a ce moment-la (4 octobre 2026).
        entity = LCM.Entities.Personnage()
    end
    paquet.valeurs = type(paquet.v) == "table" and paquet.v or {}
    local recu = { paquet = paquet, expediteur = expediteur, entity = entity,
                   resolution = resolutionImposee or Actions.ResolutionPour(paquet.n) }
    Actions.recus[#Actions.recus + 1] = recu
    if Actions.onRecu then Actions.onRecu(recu) end
    return true
end

-- Le compte rendu, renvoye a celui qui a agi.
local function CompteRendu(ctx, recu)
    -- Un joueur repond sous le nom de son PERSONNAGE (celui qui a encaisse).
    local perso = not recu.paquet.p and recu.entity
    local qui = recu.paquet.p and (recu.paquet.pn or recu.paquet.p)
        or (perso and perso.name) or (LCM.Identite and LCM.Identite.Joueur().nom) or LCM.PlayerId()
    local lignes = {}
    for _, l in ipairs(ctx.journal) do
        if l:match("^Jet ") or l:match("^Message") or l:match("^Réparti") or l:match("^Dégât absorbé")
            or l:match("^Répartition appliquée")
            or l:match("^Choix") then
            lignes[#lignes + 1] = l
        end
    end
    local texte = string.format("%s — %s : %s", qui, tostring(recu.paquet.n), table.concat(lignes, " | "))
    -- A l'attaquant, meme quand l'action a ete deviee en route : c'est lui qui
    -- attend l'issue, pas celui qui a fait le detour.
    local destinataire = Trim(recu.paquet.a) ~= "" and recu.paquet.a or recu.expediteur
    if destinataire == LCM.PlayerId() then
        LCM.Info(texte)
    else
        LCM.Reseau.Envoyer("act=", { t = recu.paquet.t, texte = texte }, "WHISPER", destinataire)
    end
end

-- Resoudre une action recue : la resolution de sa nature, jouee sur la fiche
-- visee, puis la repartition de ce qu'elle applique, puis le compte rendu.
-- Les actions dont la resolution a commence : un detour qui arrive apres est
-- « trop tard » (Core/Reactions.lua).
Actions.resolues = {}

function Actions.Resoudre(recu)
    for i, r in ipairs(Actions.recus) do if r == recu then table.remove(Actions.recus, i) break end end
    if recu.paquet.t then Actions.resolues[recu.paquet.t] = true end
    local resolution = recu.resolution
    if not resolution then
        LCM.Alerte(string.format("aucune résolution pour « %s ».", tostring(recu.paquet.n)))
        return nil
    end
    local ctx = Contexte(resolution, recu.entity)
    ctx.paquet, ctx.recu = recu.paquet, recu
    Actions.Etapes(ctx.etapes, ctx, function()
        Signaler(ctx)
        local function Fin()
            CompteRendu(ctx, recu)
            if ctx.onFin then ctx.onFin(ctx) end
            if Actions.onResolu then Actions.onResolu(ctx) end
        end
        if #ctx.effets > 0 and Actions.onAppliquer then return Actions.onAppliquer(ctx, Fin) end
        Fin()
    end)
    return ctx
end

-- ===== Repartir ce qui est applique ========================================

-- Ou l'on peut encaisser : les zones du corps pour #sante, la jauge temporaire
-- et TOUS les objets equipes pour #bouclier. #armure reste un alias accepte
-- pour les anciennes actions et vise les memes objets. Chaque objet expose son
-- etat forge ; a zero il est detruit (Core/Objets.lua).
function Actions.Zones(entity, tags)
    local voulus = {}
    for _, t in ipairs(tags or {}) do voulus[Cle(t:gsub("#", ""))] = true end
    local out = {}
    if voulus.sante then
        local total = LCM.Body.MaxTotal(entity)
        for _, z in ipairs(LCM.Body.State(entity, total)) do
            out[#out + 1] = { genre = "zone", id = z.id, nom = z.label, courant = z.current, max = z.max,
                              plafond = z.current, sante = true }
        end
    end
    if voulus.bouclier then
        local j = LCM.Entities.Gauge(entity, "armure")
        out[#out + 1] = { genre = "jauge", id = "armure", nom = "Boucliers", courant = j.current, max = j.max,
                          plafond = j.current, tag = "#bouclier" }
    end
    if voulus.bouclier or voulus.armure then
        for _, objet in ipairs(LCM.Objets.EquipementsEtat(entity)) do
            out[#out + 1] = { genre = "objet", id = objet.id, nom = objet.label, categorie = objet.categorie,
                              rang = objet.rang,
                              courant = objet.reste, max = objet.valeur, plafond = objet.reste, tag = "#bouclier" }
        end
    end
    local inconnus = {}
    for t in pairs(voulus) do
        if t ~= "sante" and t ~= "bouclier" and t ~= "armure" then inconnus[#inconnus + 1] = "#" .. t end
    end
    table.sort(inconnus)
    return out, inconnus
end

-- Pourcentage de degats qui doit traverser les protections. Une valeur issue
-- d'une ancienne fiche ou saisie a la main peut depasser 100 : on la borne ici
-- afin que la repartition ne puisse jamais devenir impossible.
function Actions.PercePourcentage(ctx)
    local pct = tonumber(Jeton("recu", "Perce armure", ctx)) or 0
    return math.max(0, math.min(100, pct))
end

-- Le perce-armure : la part du degat qui DOIT aller en sante (arrondie au
-- superieur), quoi que le joueur repartisse.
--
-- Les Resistances l'ALLEGENT (2 % par point) : elles ne retirent pas de
-- degats, elles rendent leur placement plus libre. Un personnage resistant
-- n'encaisse pas moins, il choisit mieux ou il encaisse (11 octobre 2026).
function Actions.PerceMinimum(ctx, montant)
    local pct = Actions.PercePourcentage(ctx)
    montant = math.max(0, tonumber(montant) or 0)
    if pct <= 0 or montant <= 0 then return 0 end
    local minimum = math.min(math.ceil(montant - 1e-9), math.ceil(montant * pct / 100 - 1e-9))
    if LCM.Expertises then
        local reste = LCM.Expertises.PartObligatoire(ctx and ctx.entity, minimum)
        return reste
    end
    return minimum
end

-- Applique une repartition : { [index de case] = points }. Les degats d'une
-- zone s'ecrivent en blessures (Core/Body.lua), ceux des Boucliers en jauge,
-- ceux d'un objet dans son etat (Core/Objets.lua) ; un gain le repare.
function Actions.Repartir(ctx, cases, repartition, signe)
    local lignes = {}
    for i, case in ipairs(cases) do
        local n = math.floor(tonumber(repartition[i]) or 0)
        if n > 0 then
            if case.genre == "zone" then
                if signe == "+" then LCM.Body.Heal(ctx.entity, case.id, n) else LCM.Body.Damage(ctx.entity, case.id, n) end
            elseif case.genre == "objet" or case.genre == "piece" then
                -- Le rang dit LAQUELLE de deux pieces identiques est touchee.
                local _, detruit = LCM.Objets.Encaisser(ctx.entity, case.id, signe == "+" and -n or n, case.rang)
                if detruit then case.detruit = true end
            else
                local j = LCM.Entities.Gauge(ctx.entity, case.id)
                LCM.Entities.SetGauge(ctx.entity, case.id, j.current + (signe == "+" and n or -n))
            end
            lignes[#lignes + 1] = string.format("%s %s%d%s", case.nom, signe, n,
                case.detruit and " (détruit)" or "")
        end
    end
    Journal(ctx, "Réparti : " .. (#lignes > 0 and table.concat(lignes, ", ") or "rien"))
end

-- ===== Reception par le reseau =============================================

LCM.WhenReady(function()
    local R = LCM.Reseau
    R.Ecouter("act", function(expediteur, d) Actions.Recevoir(d, expediteur) end)
    R.Ecouter("etat", function(expediteur, d) Actions.RecevoirEtat(d, expediteur) end)
    -- Qu'est-ce qui pese sur toi (ou sur ce PNJ) ? Seul un membre du groupe
    -- peut le demander ; on ne livre que ce qu'une dissipation doit savoir.
    R.Ecouter("etats?", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local entity = LCM.Entities.Personnage()
        if d.p then
            if not LCM.IsMaster() then return end
            entity = LCM.Incarnation.Instance(d.p)
            if not entity then return end
        end
        local paquet = { p = d.p, nb = 0 }
        for k, e in ipairs(Resume(LCM.EtatsTemporaires.Liste(entity))) do
            paquet.nb = k
            paquet["i" .. k], paquet["n" .. k], paquet["c" .. k] = e.id, e.nom, e.competence
            paquet["s" .. k], paquet["r" .. k] = e.seuil, e.restant
            paquet["k" .. k] = e.stacks
        end
        R.Envoyer("etats", paquet, "WHISPER", expediteur)
    end)
    R.Ecouter("etats", function(expediteur, d)
        local liste = {}
        for k = 1, tonumber(d.nb) or 0 do
            liste[#liste + 1] = { id = d["i" .. k], nom = d["n" .. k], competence = d["c" .. k],
                                  seuil = tonumber(d["s" .. k]) or 0, restant = tonumber(d["r" .. k]),
                                  stacks = tonumber(d["k" .. k]) }
        end
        local cle = d.p or expediteur
        Actions.etatsConnus[cle] = liste
        if Actions.onEtats then Actions.onEtats(cle, liste) end
    end)
    -- Un de mes etats (ou de mes PNJ) a ete dissipe.
    R.Ecouter("dissipe", function(expediteur, d)
        if not LCM.Fiches.DansLeGroupe(expediteur) then return end
        local entity = LCM.Entities.Personnage()
        if d.p then
            if not LCM.IsMaster() then return end
            entity = LCM.Incarnation.Instance(d.p)
            if not entity then return end
        end
        -- `sc` : le score du dissipateur. Present, c'est un dot — on retire des
        -- stacks, et on dit combien.
        local score = tonumber(d.sc)
        if score and LCM.Dot then
            local partis, reste = LCM.Dot.Dissiper(entity, d.id, score)
            if partis and partis > 0 then
                LCM.Info(string.format("%s dissipe %d stack%s de « %s »%s.", expediteur, partis,
                    partis > 1 and "s" or "", tostring(d.nom or d.id),
                    (reste or 0) > 0 and string.format(" (il en reste %d)", reste) or " : il s'éteint"))
            end
            return
        end
        if LCM.EtatsTemporaires.Retirer(entity, d.id) then
            LCM.Info(string.format("%s dissipe « %s ».", expediteur, tostring(d.nom or d.id)))
        end
    end)
    -- Le compte rendu d'une action qu'on a declaree.
    R.Ecouter("act=", function(_, d)
        if Trim(d.texte) ~= "" then LCM.Info(d.texte) end
    end)
end)
