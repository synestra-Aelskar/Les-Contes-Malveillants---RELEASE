-- La fenetre de fiche.
--
-- Elle se construit ENTIEREMENT a partir du schema : un champ ajoute dans
-- Data/ apparait ici sans une ligne de plus. Le rendu ne connait que les types
-- de champ.
--
-- La mise en page est celle du theme A'hell'Raz'kah de Necronicon (AelLayout.lua,
-- AelWidgets.lua), reprise avec ses mesures : une section est un bloc encadre
-- avec un titre en capitales ; une ligne fait 62 unites sur 786 et place ses
-- colonnes aux memes abscisses que le modele (nom 96, plage 310, valeur 418,
-- modificateur 535, action 652 ; jauge de 270 a 540, boutons a 561 / 607 / 653).
-- Tout suit la largeur : une fenetre elargie grossit, elle ne s'etale pas.
--
-- Une seule fenetre, qui affiche l'entite qu'on lui donne : la sienne, ou celle
-- d'un PNJ. Joueurs et PNJ partagent la meme feuille, donc le meme ecran.

local _, LCM = ...
local UI = LCM.UI
local GameTooltip = UI.Infobulle()

local Fiche = {}
UI.Fiche = Fiche

-- Les lignes se touchent, et les blocs aussi : Necronicon n'aere pas, et c'est
-- ce qui lui permet de tenir la meme fiche dans moins de place. Le filet de
-- chaque ligne suffit a les separer.
-- Ce qu'on laisse entre la derniere valeur et le bord de la ligne.
local MARGE_VALEUR = 8
local ECART_LIGNES = 0
local ECART_BLOCS = 4

local function Nombre(valeur)
    local n = tonumber(valeur)
    if not n then return tostring(valeur or "") end
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return string.format("%.2f", n)
end

local function Montant(n)
    return (n >= 0 and "+" or "") .. Nombre(n)
end

-- ===== Une ligne : surface, colonnes ======================================

-- Le fond de pierre et le cadre discret d'une ligne de fiche (UI.SkinAelRow).
function Fiche.Surface(l)
    if UI.SurfaceLigne then
        UI.SurfaceLigne(l)
    else
        l.surface = UI.Aplat(l, UI.C.fondClair)
        l.surface:SetAllPoints(l)
    end
end

local Surface = Fiche.Surface

-- `sorte` : « Button » pour une ligne sur laquelle on clique. Le jeu ne donne
-- de script OnClick qu'aux boutons — une ligne-cadre a laquelle on en attache
-- un leve « doesn't have a "OnClick" script » et la fenetre ne s'ouvre plus.
function Fiche.Ligne(parent, c, sorte)
    local l = CreateFrame(sorte or "Frame", nil, parent)
    l:SetHeight(c.ligne)
    Surface(l)
    return l
end
local Ligne = Fiche.Ligne

-- Le nom, a sa place : apres l'icone s'il y en a une, sinon a la sienne.
--
-- Il recoit une LARGEUR, bornee par la colonne qui suit : sans elle un libelle
-- un peu long continue tout droit et s'ecrit sur la jauge (« Points d'action »
-- par-dessus sa barre). Coupe plutot que deborde — et si ca coupe souvent,
-- c'est le libelle qu'il faut raccourcir, comme le template le fait avec PA.
-- La largeur qu'un libelle prendra REELLEMENT, dans sa police. Un seul texte
-- de mesure, cache : il ne sert qu'a construire.
local mesureur
function Fiche.LargeurTexte(texte, police)
    if not mesureur then
        mesureur = UI.Texte(UIParent, "", UI.C.texte)
        mesureur:Hide()
    end
    UI.Police(mesureur, police or 12)
    mesureur:SetText(tostring(texte or ""))
    return mesureur:GetStringWidth() or 0
end

-- Les noms des sources, tels qu'on veut les lire sur une fiche. Ceux du code
-- sont au singulier et en minuscules ; ici on parle au joueur.
-- Un element seul, d'ou le singulier : « Trait · Colosse ».
local LIBELLE_SOURCE = {
    ["race"] = "Race",
    ["trait"] = "Trait",
    ["objet"] = "Équipement",
    ["etat"] = "État",
    ["état temporaire"] = "État temporaire",
    ["apprentissage"] = "Apprentissage",
}

-- « D'où viennent ces +4 ? » : chaque point, un par un, ce qui le donne a
-- gauche et combien a droite ; le total en dernier, sous un filet.
-- `apport` est la part qui vient des primaires (la formule de la fiche), qui
-- n'est pas une source d'effets mais compte dans le total.
-- Rend une liste de lignes { gauche, droite, couleur } que Fiche.Bulle sait
-- poser, et la note du champ a part.
function Fiche.Decomposition(e, field, base, apport, options)
    options = options or {}
    local lignes = { note = field.note and field.note ~= "" and field.note or nil }
    local total = (base or 0) + (apport or 0)
    if not options.sansBase then
        local nom = field.kind == "calc" and "Valeur calculée" or "Points investis"
        if field.note and field.note:find("pas des points investis", 1, true) then nom = "Valeur initiale" end
        lignes[#lignes + 1] = { nom, Nombre(base or 0) }
    end
    if field.kind == "roll" or (apport or 0) ~= 0 then
        lignes[#lignes + 1] = { "Apport des statistiques", Montant(apport or 0) }
    end
    for _, part in ipairs(LCM.Effets.Detail(e, field.id)) do
        total = total + part.total
        local source = LIBELLE_SOURCE[part.nom] or (part.nom:sub(1, 1):upper() .. part.nom:sub(2))
        for _, element in ipairs(part.elements or {}) do
            local nom = element.label and (source .. " · " .. tostring(element.label)) or source
            lignes[#lignes + 1] = { nom, Montant(element.montant),
                                    element.montant < 0 and UI.C.plein or UI.C.accent }
        end
    end
    if options.sansBase and #lignes == 0 then lignes[#lignes + 1] = { "Bonus portés", "0" } end
    local mecaniqueId = field.id and field.id:match("^meca_(.+)$")
    if mecaniqueId and LCM.Reglages and LCM.Reglages.PuissanceMecanique then
        local p = LCM.Reglages.PuissanceMecanique(mecaniqueId)
        local equipement = LCM.Effets.Bonus(e, field.id)
        lignes.note = string.format("Puissance : %s %% + (%s × %s %%) + (%s × %s %%) = %s %%",
            Nombre(p.base), Nombre(base or 0), Nombre(p.parPoint), Nombre(equipement),
            Nombre(p.equipParPoint), Nombre(p.base + (base or 0) * p.parPoint
                + equipement * p.equipParPoint))
    end
    lignes.total = Nombre(total)
    return lignes
end

-- Une jauge affiche un courant et un maximum : le survol explicite aussi la
-- soustraction, y compris lorsque la jauge est pleine ou vide.
function Fiche.DecompositionJauge(jauge, note, e, id)
    if not jauge then return note end
    local lignes = { note = note }
    local q = LCM.Equilibrage and LCM.Equilibrage[id]
    local v = function(champ) return tonumber(LCM.Entities.Get_Value(e, champ)) or 0 end
    if e and id == "fatigue" and q then
        local morceaux = {
            { "Base", q.base },
            { "Niveau × " .. Nombre(q.parNiveau), v("niveau") * q.parNiveau },
            { "Esprit × " .. Nombre(q.parEsprit), v("esprit") * q.parEsprit },
            { "Constitution × " .. Nombre(q.parConstitution), v("constitution") * q.parConstitution },
            { "Endurance / " .. Nombre(q.diviseurEndurance),
                LCM.Formules.Expertise(e, "endurance") / q.diviseurEndurance },
            { "Points secondaires × " .. Nombre(q.parSecondaire), v("sec_fatigue") * q.parSecondaire },
            { "Bonus portés", LCM.Effets.Bonus(e, "fatigue") },
        }
        local somme = 0
        for _, part in ipairs(morceaux) do somme = somme + part[2] end
        if math.floor(somme) == jauge.max then
            for _, part in ipairs(morceaux) do lignes[#lignes + 1] = { part[1], Nombre(part[2]) } end
        end
    elseif e and id == "pa" and q then
        local palier = math.floor(v("niveau") / q.niveauxParPA)
        local morceaux = {
            { "Base", q.base }, { "Niveau : paliers de " .. Nombre(q.niveauxParPA), palier },
            { "Points secondaires", v("sec_pa") }, { "Bonus portés", LCM.Effets.Bonus(e, "pa") },
        }
        local somme = 0
        for _, part in ipairs(morceaux) do somme = somme + part[2] end
        if math.floor(somme) == jauge.max then
            for _, part in ipairs(morceaux) do lignes[#lignes + 1] = { part[1], Nombre(part[2]) } end
        end
    end
    lignes[#lignes + 1] = { "Maximum", Nombre(jauge.max) }
    lignes[#lignes + 1] = { "Écart au maximum", Montant(jauge.current - jauge.max) }
    lignes.total = Nombre(jauge.current)
    return lignes
end

-- Les champs dont la valeur provient d'une formule montrent ses termes, et
-- pas simplement « valeur calculée = total ».
function Fiche.DecompositionFormule(e, field)
    if not e or not field then return nil end
    local id, eq = field.id, LCM.Equilibrage
    local v = function(champ) return tonumber(LCM.Entities.Get_Value(e, champ)) or 0 end
    local p = function(champ) return LCM.Formules.Primaire(e, champ) end
    local lignes = { note = field.note }
    if id == "poids_soulevable" then
        local q = eq.quotidien
        lignes[1] = { "Base", Nombre(q.poidsBase) }
        lignes[2] = { "Force totale × " .. Nombre(q.poidsParForce), Nombre(p("force") * q.poidsParForce) }
    elseif id == "saut_horizontal" or id == "saut_vertical" then
        local q = eq.sauts[id == "saut_horizontal" and "horizontal" or "vertical"]
        lignes[1] = { "Force totale / " .. Nombre(q.diviseurForce), Nombre(p("force") / q.diviseurForce) }
        lignes[2] = { "Adresse totale / " .. Nombre(q.diviseurAdresse), Nombre(p("adresse") / q.diviseurAdresse) }
        lignes.note = (field.note or "") .. "\nArrondi à l'entier inférieur."
    elseif id == "initiative" then
        -- Une valeur saisie explicitement remplace la formule dans Entities.
        if e.values and e.values.initiative ~= nil then return nil end
        local q = eq.initiative
        lignes[1] = { "Points secondaires", Nombre(v("sec_initiative")) }
        lignes[2] = { "Niveau / " .. Nombre(q.diviseurNiveau), Nombre(v("niveau") / q.diviseurNiveau) }
        lignes[3] = { "Esprit total / " .. Nombre(q.diviseurEsprit), Nombre(p("esprit") / q.diviseurEsprit) }
        lignes[4] = { "Perception totale / " .. Nombre(q.diviseurPerception), Nombre(p("perception") / q.diviseurPerception) }
        lignes[5] = { "Bonus portés", Montant(LCM.Effets.Bonus(e, id)) }
        lignes.note = (field.note or "") .. "\nArrondi à l'entier inférieur."
    elseif id == "depl_terrestre" or id == "depl_nage" or id == "depl_vol" then
        local mode = id:sub(6)
        local q = eq.deplacement
        lignes[1] = { "Base", Nombre(q[mode] or 0) }
        lignes[2] = { "Expertise", Nombre(LCM.Expertises.BonusDeplacement(e, mode) or 0) }
        lignes[3] = { "Points secondaires × " .. Nombre(q.parSecondaire), Nombre(q.parSecondaire * v("sec_deplacement")) }
        lignes[4] = { "Bonus portés", Montant(LCM.Effets.Bonus(e, id)) }
        lignes.note = (field.note or "") .. "\nArrondi à l'entier inférieur."
    else
        return nil
    end
    lignes.total = Nombre(v(id) + (id == "initiative" and LCM.Effets.Bonus(e, id) or 0))
    return lignes
end

function Fiche.DecompositionVie(e)
    if not e then return nil end
    local courant, maximum = LCM.Body.Totals(e)
    local lignes = { note = "Chaque zone vaut 30 % du maximum." }
    local q = LCM.Equilibrage and LCM.Equilibrage.pv
    if q then
        local v = function(champ) return tonumber(LCM.Entities.Get_Value(e, champ)) or 0 end
        local constitution = LCM.Formules.Primaire(e, "constitution")
        local morceaux = {
            { "Base", q.base },
            { "Niveau × " .. Nombre(q.parNiveau), v("niveau") * q.parNiveau },
            { "Vitalité × " .. Nombre(q.parVitalite), v("sec_vitalite") * q.parVitalite },
            { "Constitution × coefficient",
                constitution * (q.constitution.base + v("constitution") * q.constitution.parConstitution) },
        }
        local somme = 0
        for _, part in ipairs(morceaux) do somme = somme + part[2] end
        if math.floor(somme) == maximum then
            for _, part in ipairs(morceaux) do lignes[#lignes + 1] = { part[1], Nombre(part[2]) } end
            lignes.note = lignes.note .. "\nCoefficient de Constitution : "
                .. Nombre(q.constitution.base) .. " + (" .. Nombre(v("constitution"))
                .. " × " .. Nombre(q.constitution.parConstitution) .. ")."
        end
    end
    lignes[#lignes + 1] = { "Maximum", Nombre(maximum) }
    lignes[#lignes + 1] = { "Blessures", Montant(courant - maximum) }
    lignes.total = Nombre(courant)
    return lignes
end

function Fiche.Nom(l, c, texte, avecIcone)
    l.nom = UI.Texte(l, texte, UI.C.texte)
    UI.Police(l.nom, c.police)
    local depart = avecIcone and c.nom or c.nomSansIcone
    l.nom:SetPoint("LEFT", l, "LEFT", depart, 0)
    l.nom:SetWidth(math.max(40, math.min(c.nomLargeur, c.barreDebut - depart - 6)))
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    l.label = l.nom
    return l.nom
end
local Nom = Fiche.Nom

-- Icone encadree et son separateur (UI.LayoutAelContainerRow).
-- `taille` force la taille de l'icone (les lignes de conteneur la doublent).
-- Elle est de toute facon bornee par la hauteur REELLE de la ligne : une icone
-- qui depasse de sa ligne mord sur la voisine.
function Fiche.Icone(l, c, texture, taille)
    local hauteur = l:GetHeight()
    if not hauteur or hauteur <= 0 then hauteur = c.ligne end
    local cote = math.min(taille or c.iconeTaille, hauteur - 4)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(cote, cote)
    l.icone:SetPoint("LEFT", l, "LEFT", c.icone, 0)
    l.icone:SetTexture(texture)
    -- Rognee plus franchement : les icones du jeu portent un liseré gris sur
    -- leur bord, qui jurait avec l'habillage.
    l.icone:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    l.iconeCote = cote
    -- Ou finit l'icone, cadre compris : ce qui suit s'y accroche.
    l.apresIcone = c.icone + cote + 2
    if UI.AelCadre then
        -- Le tour dore mord d'un pixel SUR l'icone au lieu de l'entourer : pose
        -- autour, il laissait voir le liseré gris du jeu entre lui et l'image.
        local support = CreateFrame("Frame", nil, l)
        support:SetPoint("TOPLEFT", l.icone, "TOPLEFT", -1, 1)
        support:SetPoint("BOTTOMRIGHT", l.icone, "BOTTOMRIGHT", 1, -1)
        l.cadreIcone = UI.AelCadre(support, "icone")
        l.separateur = UI.AelRef(l, 202, 397, 15, 37, "ARTWORK")
        l.separateur:SetSize(12 * c.echelle, math.min(37 * c.echelle, hauteur - 4))
        -- Calee sur l'icone qu'on vient de poser, pas sur la colonne du
        -- gabarit : une icone doublee aurait pousse le separateur en plein
        -- milieu d'elle-meme.
        l.separateur:SetPoint("LEFT", l, "LEFT", taille and (l.apresIcone + 4) or c.separateur, 0)
        l.apresIcone = (taille and (l.apresIcone + 4) or c.separateur) + 12 * c.echelle + 6
    end
end
local Icone = Fiche.Icone

-- Une jauge du modele : barre avec embouts dores, chiffres contournes dessus,
-- trois boutons carres a droite. `rappels` : moins(), plus(), remise().
-- `saisir(n)` : poser la valeur tapee, rend true ou false et la raison.
--
-- Boutons et saisie sont au MAITRE DU JEU (13 octobre 2026) : le joueur lit
-- ses jauges, la partie les fait bouger. `l:Controles(mj)` les montre ou les
-- cache ; sans eux, la barre prend leur place.
local function Jauge(l, c, couleur, rappels, saisir)
    local debut = c.barreDebut
    -- Une jauge SANS boutons (les points de vie, qui se perdent et se rendent
    -- zone par zone) laissait derriere elle la place des trois boutons, vide.
    -- Elle va donc jusqu'au bord gauche du « R » des jauges d'en dessous : les
    -- colonnes restent alignees, et la barre occupe ce qui ne servait a rien.
    local finAvec, finSans = c.barreFin, c.boutons[3]
    l.finBarre = rappels and finAvec or finSans
    l.barre = UI.Barre(l, couleur, l.finBarre - debut, c.barreHauteur)
    l.barre:SetPoint("LEFT", l, "LEFT", debut, 0)
    UI.Police(l.barre.label, c.police, "OUTLINE")
    if UI.AelCadreJauge then l.cadreJauge = UI.AelCadreJauge(l.barre) end

    -- La barre commence apres le nom : une police plus grande ne la cache pas.
    function l:CaleBarre()
        local fin = self.finBarre
        local x = math.min(fin - 80 * c.echelle,
            math.max(debut, (self.nomX or c.nomSansIcone) + (self.nom:GetStringWidth() or 0) + 14 * c.echelle))
        self.barre:ClearAllPoints()
        self.barre:SetPoint("LEFT", self, "LEFT", x, 0)
        self.barre:SetWidth(fin - x)
        if self.barre.courant then self.barre:Regler(self.barre.courant, self.barre.maximum) end
    end

    if rappels then
        l.boutons = {}
        for i, def in ipairs({ { "-", rappels.moins }, { "+", rappels.plus }, { "R", rappels.remise } }) do
            local b = UI.Bouton(l, def[1], c.boutonL, c.boutonH, function() def[2]() end)
            b:SetPoint("LEFT", l, "LEFT", c.boutons[i], 0)
            UI.Police(b.label, c.police)
            l.boutons[i] = b
        end
    end

    -- Un clic sur la barre : le MJ tape la valeur. Pose une fois, par-dessus
    -- la barre, et seulement montre ou cache ensuite.
    if saisir then
        l.saisie = CreateFrame("Button", nil, l)
        l.saisie:SetAllPoints(l.barre)
        l.saisie:SetFrameLevel(l.barre:GetFrameLevel() + 5)
        l.saisie:SetScript("OnClick", function()
            if not LCM.IsMaster() then return end
            UI.Demande():Demander(tostring(l.nom:GetText() or "Valeur"), l.barre.courant or 0, function(texte)
                local n = tonumber(texte)
                if not n or n ~= math.floor(n) then
                    return false, string.format("valeur illisible (%s) : un nombre entier.", tostring(texte))
                end
                return saisir(n)
            end)
        end)
        l.saisie:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(l.nom:GetText() or ""))
            GameTooltip:AddLine("Clic : saisir la valeur.", 0.55, 0.55, 0.55)
            GameTooltip:Show()
        end)
        l.saisie:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    function l:Controles(mj)
        for _, b in ipairs(self.boutons or {}) do b:SetShown(mj) end
        if self.saisie then self.saisie:SetShown(mj) end
        local fin = (rappels and mj) and finAvec or finSans
        if fin ~= self.finBarre then
            self.finBarre = fin
            self:CaleBarre()
        end
    end
end

-- Une valeur saisie doit tenir dans la jauge : au-dessus du maximum ou sous
-- zero, c'est refuse et dit, pas rabote.
local function DansLaJauge(n, maximum)
    if n < 0 then return false, "pas de valeur négative." end
    if n > maximum then return false, string.format("au-dessus du maximum (%d).", maximum) end
    return true
end

-- Bulle d'aide au survol d'une ligne. `texte` : une phrase, ou une
-- decomposition (Fiche.Decomposition) posee en deux colonnes.
function Fiche.Bulle(l, titre, texte)
    if not texte or texte == "" then return end
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local contenu = type(texte) == "function" and texte(self) or texte
        if not contenu or contenu == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titre)
        if type(contenu) == "table" then
            local t, d = UI.C.texte, UI.C.titre
            for _, ligne in ipairs(contenu) do
                local c = ligne[3] or d
                GameTooltip:AddDoubleLine(ligne[1], ligne[2], t[1], t[2], t[3], c[1], c[2], c[3])
            end
            if #contenu > 0 then GameTooltip:AddFilet() end
            GameTooltip:AddDoubleLine("Total", contenu.total, d[1], d[2], d[3], d[1], d[2], d[3])
            if contenu.note then
                local n = UI.C.discret
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(contenu.note, n[1], n[2], n[3], true)
            end
        else
            GameTooltip:AddLine(contenu, 0.88, 0.84, 0.76, true)
        end
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
local Bulle = Fiche.Bulle

-- ===== Lignes, une par type de champ =======================================

local Lignes = {}

-- Valeur simple : le nom a gauche, la valeur alignee a droite sur la derniere
-- colonne (comme dans Deplacement chez Necronicon), bonus portes a la suite.
function Lignes.stat(parent, field, c)
    local l = Ligne(parent, c)
    local icone = LCM.IconeChamp(field)
    if icone then Icone(l, c, icone) end
    -- Le quatrieme argument n'est pas decoratif : sans lui le nom se pose a la
    -- colonne « sans icone » et vient s'ecrire par-dessus l'icone.
    Nom(l, c, field.label, icone ~= nil)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police)
    -- Calee sur la COLONNE DE VALEUR, pas sur le bord droit de la ligne. Au
    -- bord, le nom finissait vers 110 et le chiffre vers 300 : deux cents
    -- pixels de rien entre les deux, et dans un volet etroit le chiffre
    -- sortait carrement du cadre visible. Toujours alignee a droite, donc les
    -- chiffres restent les uns sous les autres ; simplement plus pres du nom.
    l.valeur:SetPoint("RIGHT", l, "LEFT", c.valeur + c.valeurLargeur, 0)
    l.valeur:SetJustifyH("RIGHT")
    -- Le bonus a son propre texte, A DROITE de la valeur (4 octobre 2026) :
    -- ecrit a la suite dans le meme texte aligne a droite, « 0 +1 » poussait
    -- le 0 vers la gauche, et la colonne ne s'alignait plus.
    l.bonus = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.bonus, c.police)
    l.bonus:SetPoint("LEFT", l.valeur, "RIGHT", 4, 0)
    l.bonus:SetJustifyH("LEFT")
    function l:Actualiser(e)
        local valeur = LCM.Entities.Get_Value(e, field.id)
        local bonus = field.kind == "stat" and LCM.Effets.Bonus(e, field.id) or 0
        -- LE TOTAL, un seul nombre. « 2 +3 » ecrivait deux valeurs dans une
        -- colonne prevue pour une : ca debordait, et c'est le total qu'on lit
        -- en jouant. Le detail passe dans l'infobulle, ou il ne gene personne
        -- (5 octobre 2026).
        local base = tonumber(valeur)
        self.valeur:SetText(Nombre(base and (base + bonus) or valeur))
        self.bonus:SetText("")
        Bulle(self, field.label, Fiche.DecompositionFormule(e, field)
            or (base and Fiche.Decomposition(e, field, base, 0) or field.note))
    end
    return l
end

Lignes.calc = Lignes.stat
Lignes.text = Lignes.stat

local COULEURS_JAUGE = {
    fatigue = UI.C.fatigue,
    armure = UI.C.armure,
    -- L'armure portee se remplit de ce qu'elle a encaisse : un bronze terni.
    armure_portee = { 0.62, 0.48, 0.34 },
    pa = { 0.83, 0.68, 0.33 },
    -- Sante > Intangible : l'Esprit et l'Ame avaient le rouge de la vie, qui
    -- ne veut rien dire pour elles. Bleu clair et violet clair, comme leurs
    -- icones (4 octobre 2026).
    existence_esprit = { 0.45, 0.72, 0.95 },
    existence_ame    = { 0.70, 0.55, 0.92 },
}

function Lignes.gauge(parent, field, c)
    local l = Ligne(parent, c)
    local icone = LCM.IconeChamp(field)
    if icone then Icone(l, c, icone) end
    Nom(l, c, field.label, icone ~= nil)
    local function Poser(delta, absolu)
        local e = l.entity
        if not e then return end
        local jauge = LCM.Entities.Gauge(e, field.id)
        if not jauge then return end
        local cible = absolu or (jauge.current + delta)
        LCM.Entities.SetGauge(e, field.id, cible)
        l:Actualiser(e)
    end
    -- Aucune jauge ne se regle a la main cote joueur : PA, fatigue et
    -- boucliers l'etaient deja (11 octobre 2026), l'armure portee, l'Esprit et
    -- l'Ame le sont depuis le 13 octobre. Leur chemin normal est la partie.
    -- Le MJ a les boutons, et un clic sur la barre pour taper la valeur.
    -- Le bouton se cache, et le geste se refuse quand meme : une fenetre
    -- construite avant que l'on sache qui joue ne doit pas ouvrir une porte.
    local function Permis()
        if LCM.IsMaster() then return true end
        LCM.Erreur("Seul le maître du jeu peut modifier cette jauge.")
        return false
    end
    local rappels = {
        moins = function() if Permis() then Poser(-1) end end,
        plus = function() if Permis() then Poser(1) end end,
        remise = function()
            if not Permis() then return end
            local jauge = l.entity and LCM.Entities.Gauge(l.entity, field.id)
            if jauge then Poser(0, field.default ~= nil and field.default or jauge.max) end
        end,
    }
    Jauge(l, c, COULEURS_JAUGE[field.id] or UI.C.vie, rappels, function(n)
        if not (Permis() and l.entity) then return false end
        local jauge = LCM.Entities.Gauge(l.entity, field.id)
        local ok, raison = DansLaJauge(n, jauge.max)
        if not ok then return false, raison end
        Poser(0, n)
        return true
    end)
    Bulle(l, field.label, function(self)
        return self.entity and Fiche.DecompositionJauge(LCM.Entities.Gauge(self.entity, field.id), field.note,
            self.entity, field.id)
            or field.note
    end)
    function l:Actualiser(e)
        self.entity = e
        local jauge = LCM.Entities.Gauge(e, field.id)
        if jauge then self.barre:Regler(jauge.current, jauge.max) end
        self:Controles(LCM.IsMaster() and not e.distante)
        self:CaleBarre()
    end
    return l
end

local function SaisieExpertise(parent, code)
    local champ
    champ = UI.Champ(parent, 58, 26, function(texte)
        champ.indication:SetShown(tostring(texte or "") == "")
    end)
    champ:SetNumeric(true)
    champ:SetMaxLetters(5)
    -- L'indication est enfant du champ : creee sur le panneau, elle pouvait
    -- passer derriere l'EditBox et disparaitre selon le niveau de frame.
    champ.indication = UI.Texte(champ, code, UI.C.discret, "GameFontNormalSmall")
    champ.indication:SetAllPoints(champ)
    champ.indication:SetJustifyH("CENTER")
    return champ
end

local function OuvrirSaisieExpertise(ligne, field)
    local panneau = ligne.saisieExpertise
    if not panneau then
        panneau = CreateFrame("Frame", nil, UIParent)
        panneau:SetSize(286, 112)
        panneau:SetFrameStrata("DIALOG")
        panneau:SetFrameLevel((UIParent:GetFrameLevel() or 0) + 30)
        panneau:EnableMouse(true)
        panneau.fond = UI.Aplat(panneau, UI.C.fond)
        panneau.fond:SetAllPoints(panneau)
        UI.Bordure(panneau, UI.C.accent)
        panneau.titre = UI.Texte(panneau, "Jet d'expertise", UI.C.titre)
        panneau.titre:SetPoint("TOPLEFT", panneau, "TOPLEFT", 12, -8)

        panneau.dd = SaisieExpertise(panneau, "DD")
        panneau.dd:SetPoint("TOPLEFT", panneau, "TOPLEFT", 42, -32)
        panneau.nf = SaisieExpertise(panneau, "PF")
        panneau.nf:SetPoint("TOPRIGHT", panneau, "TOPRIGHT", -42, -32)
        UI.Bulle(panneau.dd, "DD — Dés de difficulté",
            "Valeur à égaler ou dépasser pour réussir votre action.")
        UI.Bulle(panneau.nf, "PF — Perte de fatigue",
            "Fatigue perdue en cas d'échec ou de réussite partielle. Dépasser le DD de 10 ou réaliser un critique ne fait pas perdre de fatigue.")

        local function HabillerMode(bouton)
            bouton.selection = UI.Aplat(bouton,
                { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.18 }, "ARTWORK")
            bouton.selection:SetPoint("TOPLEFT", bouton, "TOPLEFT", 3, -3)
            bouton.selection:SetPoint("BOTTOMRIGHT", bouton, "BOTTOMRIGHT", -3, 3)
            bouton.selection:Hide()
            local selectionner = bouton.Selectionner
            function bouton:Selectionner(actif)
                selectionner(self, actif)
                self.selection:SetShown(actif)
            end
            bouton:Selectionner(false)
        end
        local function ChoisirMode(mode)
            panneau.mode = panneau.mode == mode and nil or mode
            panneau.avantage:Selectionner(panneau.mode == "avantage")
            panneau.desavantage:Selectionner(panneau.mode == "desavantage")
        end
        panneau.avantage = UI.Bouton(panneau, "Avec avantage", 122, 22,
            function() ChoisirMode("avantage") end)
        panneau.avantage:SetPoint("TOPLEFT", panneau, "TOPLEFT", 16, -66)
        HabillerMode(panneau.avantage)
        UI.Bulle(panneau.avantage, "Avec avantage",
            "Lance deux fois le jet, puis conserve le meilleur résultat.")
        panneau.desavantage = UI.Bouton(panneau, "Avec désavantage", 122, 22,
            function() ChoisirMode("desavantage") end)
        panneau.desavantage:SetPoint("TOPRIGHT", panneau, "TOPRIGHT", -16, -66)
        HabillerMode(panneau.desavantage)
        UI.Bulle(panneau.desavantage, "Avec désavantage",
            "Lance deux fois le jet, puis conserve le pire résultat.")

        panneau.lancer = UI.Bouton(panneau, "Lancer", 88, 22, function()
            panneau.dd:ClearFocus()
            panneau.nf:ClearFocus()
            local ddTexte = tostring(panneau.dd:GetText() or "")
            if ddTexte == "" then
                LCM.Alerte("Indique le DD pour lancer ce jet.")
                panneau.dd:SetFocus()
                return
            end
            local resultat, raison = LCM.Roll.ResoudreExpertise(ligne.entity, field.id, ddTexte,
                panneau.nf:GetText(), {
                    avantage = panneau.mode == "avantage"
                        or (not panneau.avantage:IsShown() and ligne.avantage:GetChecked()),
                    desavantage = panneau.mode == "desavantage",
                })
            if not resultat then
                LCM.Alerte(tostring(raison or "jet impossible"))
                return
            end
            local jet = resultat.jet
            local des = #jet.jets > 1
                and string.format("%d et %d (gardé : %d)", jet.jets[1], jet.jets[2], jet.garde)
                or tostring(jet.garde)
            local recap = string.format("%s : %s (Jets : %s, Stat : %s) = %s",
                field.label, Nombre(jet.total), des, Nombre(resultat.stat), resultat.issue)
            LCM.Canal.Dire(recap)
            LCM.Info(string.format("Perte de %s PF", Nombre(resultat.perteFatigue)))
            panneau:Hide()
        end)
        panneau.lancer:SetPoint("BOTTOMLEFT", panneau, "BOTTOMLEFT", 24, 9)
        panneau.annuler = UI.Bouton(panneau, "Annuler", 88, 22, function() panneau:Hide() end)
        panneau.annuler:SetPoint("BOTTOMRIGHT", panneau, "BOTTOMRIGHT", -24, 9)
        panneau:Hide()
        ligne.saisieExpertise = panneau
    end

    if panneau:IsShown() then
        panneau:Hide()
        return
    end
    panneau.dd:SetText("")
    panneau.nf:SetText("")
    panneau.dd.indication:Show()
    panneau.nf.indication:Show()
    panneau.mode = nil
    panneau.avantage:Selectionner(false)
    panneau.desavantage:Selectionner(false)
    local traitExpertise = ligne.entity and LCM.Traits.BonusPositif(ligne.entity, field.id) or nil
    local avecModes = traitExpertise ~= nil
    panneau.avantage:SetShown(avecModes)
    panneau.desavantage:SetShown(avecModes)
    panneau:SetHeight(avecModes and 148 or 112)
    panneau:ClearAllPoints()
    panneau:SetPoint("BOTTOM", ligne.lancer, "TOP", 0, 6)
    panneau:Show()
    panneau.dd:SetFocus()
end

function Lignes.roll(parent, field, c)
    local l = Ligne(parent, c)
    local icone = LCM.IconeChamp(field)
    if icone then Icone(l, c, icone) end
    Nom(l, c, field.label, icone ~= nil)

    local dice = type(field.dice) == "table" and field.dice or {}
    l.plage = UI.Texte(l, string.format("%d-%d", tonumber(dice.min) or 0, tonumber(dice.max) or 0), UI.C.discret)
    UI.Police(l.plage, c.police)
    l.plage:SetPoint("LEFT", l, "LEFT", c.plage, 0)
    l.plage:SetWidth(c.plageLargeur)
    l.plage:SetJustifyH("CENTER")

    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police)
    l.valeur:SetPoint("LEFT", l, "LEFT", c.valeur, 0)
    l.valeur:SetWidth(c.valeurLargeur)
    l.valeur:SetJustifyH("CENTER")

    l.bonus = UI.Texte(l, "", UI.C.accent)
    UI.Police(l.bonus, c.police)
    l.bonus:SetPoint("LEFT", l, "LEFT", c.modificateur, 0)
    l.bonus:SetWidth(c.modificateurLargeur - 22 * c.echelle)
    l.bonus:SetJustifyH("CENTER")

    -- La case d'avantage n'apparait que si un trait ou un objet l'accorde :
    -- inutile de proposer un choix qui n'en est pas un.
    l.avantage = CreateFrame("CheckButton", nil, l)
    local cote = math.max(14, 20 * c.echelle)
    l.avantage:SetSize(cote, cote)
    l.avantage:SetPoint("RIGHT", l, "LEFT", c.modificateur + c.modificateurLargeur, 0)
    l.avantage.fond = UI.Aplat(l.avantage, { 0.035, 0.030, 0.023, 1 })
    l.avantage.fond:SetAllPoints(l.avantage)
    UI.Bordure(l.avantage, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.7 })
    l.avantage.marque = UI.Texte(l.avantage, "", UI.C.accent, "GameFontNormalSmall")
    l.avantage.marque:SetAllPoints(l.avantage)
    l.avantage.marque:SetJustifyH("CENTER")
    l.avantage:SetScript("OnClick", function(bouton)
        bouton:SetChecked(not bouton:GetChecked())
        bouton.marque:SetText(bouton:GetChecked() and "v" or "")
    end)

    l.lancer = UI.Bouton(l, "Jet", c.actionLargeur, c.boutonH, function()
        local entite = l.entity
        if not entite then return end
        if field.jetExpertise then
            OuvrirSaisieExpertise(l, field)
            return
        end
        local resultat = LCM.Roll.Field(entite, field.id, { avantage = l.avantage:GetChecked() })
        if resultat then LCM.Canal.Dire(LCM.Roll.Describe(resultat)) end
    end)
    l.lancer:SetPoint("LEFT", l, "LEFT", c.action, 0)
    UI.Police(l.lancer.label, c.police)
    Bulle(l, field.label, field.note)

    function l:Actualiser(e)
        self.entity = e
        -- Ce que le personnage vaut de lui-meme (investi + apport de ses
        -- primaires), puis ce qu'il porte, dans sa colonne.
        local valeur = (tonumber(LCM.Entities.Get_Value(e, field.id)) or 0) + LCM.Formules.Apport(e, field.id)
        local bonus = LCM.Effets.Bonus(e, field.id)
        -- Le TOTAL dans la colonne de valeur : c'est lui qu'on ajoute au de, et
        -- il manquait — on lisait « +1 » a cote d'une case vide sans savoir ce
        -- que valait le jet (5 octobre 2026). Le bonus reste a part, dans sa
        -- propre colonne : il dit d'ou vient la difference.
        self.valeur:SetText(Nombre(valeur + bonus))
        self.bonus:SetText(bonus ~= 0 and Montant(bonus) or "")
        local investi = tonumber(LCM.Entities.Get_Value(e, field.id)) or 0
        Bulle(self, field.label, Fiche.DecompositionFormule(e, field)
            or Fiche.Decomposition(e, field, investi, valeur - investi))
        local source = LCM.Effets.Avantage(e, field.id)
        -- Les expertises proposent maintenant avantage/desavantage dans leur
        -- fenetre DD/PF si un trait positif existe. La petite case demeure
        -- pour un avantage d'objet sur une expertise sans un tel trait.
        local traitExpertise = field.jetExpertise and LCM.Traits.BonusPositif(e, field.id)
        self.avantage:SetShown(not e.distante and source ~= nil
            and (not field.jetExpertise or not traitExpertise))
        self.lancer:SetShown(not e.distante)
        if traitExpertise or not source then
            self.avantage:SetChecked(false)
            self.avantage.marque:SetText("")
        end
    end
    return l
end

-- Le corps (template : fenetre Sante, onglet Physique) : une jauge des points
-- de vie, puis une jauge par zone avec son icone. Moins blesse, plus soigne,
-- R soigne la zone entiere. Les PV courants = PV max - blessures.
--
-- Options (Data/Vues.lua) : `zones = false` ne garde que la jauge des PV (la
-- Fiche du template), `total = false` que les zones (Sante › Physique).
function Lignes.body(parent, field, c, options)
    options = options or {}
    local avecZones, avecTotal = options.zones ~= false, options.total ~= false
    local l = CreateFrame("Frame", nil, parent)
    l.zones = {}

    l.total = Ligne(l, c)
    l.total:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.total:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
    -- Le coeur du template : c'est sa ligne « Point de vie ».
    local iconeTotal = LCM.IconeChamp(field)
    if iconeTotal then Icone(l.total, c, iconeTotal) end
    -- « Point de vie » au singulier : c'est le libelle du template.
    Nom(l.total, c, "Point de vie", iconeTotal ~= nil)
    Jauge(l.total, c, UI.C.vie, nil)
    Bulle(l.total, "Point de vie", function()
        return Fiche.DecompositionVie(l.entity)
    end)

    local function Zone(index)
        local z = Ligne(l, c)
        Icone(z, c, "Interface\\Icons\\INV_Misc_QuestionMark")
        Nom(z, c, "", true)
        z.nomX = c.nom
        local function Agir(fonction, montant)
            if not (l.entity and z.partieId) then return end
            -- Les blessures ne sont jamais une jauge que le joueur ajuste a
            -- la main. Seul le compagnon MJ peut blesser ou soigner depuis la
            -- fiche ; les actions de combat restent le chemin normal.
            if not LCM.IsMaster() then
                LCM.Erreur("Seul le maître du jeu peut modifier les PV.")
                return
            end
            fonction(l.entity, z.partieId, montant)
            l:Actualiser(l.entity)
            if l.onChange then l.onChange(l.entity) end
        end
        Jauge(z, c, { 0.30, 0.76, 0.42 }, {
            moins = function() Agir(LCM.Body.Damage, 1) end,
            plus = function() Agir(LCM.Body.Heal, 1) end,
            remise = function() Agir(LCM.Body.Heal, 1000000) end,
        }, function(n)
            -- Les PV de la zone, tapes : la blessure se deduit du maximum.
            if not (l.entity and z.partieId and LCM.IsMaster()) then return false end
            local ok, raison = DansLaJauge(n, z.barre.maximum or 0)
            if not ok then return false, raison end
            Agir(LCM.Body.SetCurrent, n)
            return true
        end)
        l.zones[index] = z
        return z
    end

    l.total:SetShown(avecTotal)

    function l:Actualiser(e)
        self.entity = e
        local courant, maximum = LCM.Body.Totals(e)
        self.total.barre:Regler(courant, maximum)
        self.total:CaleBarre()
        for _, bouton in ipairs(self.total.boutons or {}) do
            bouton:SetShown(not e.distante)
        end

        local etat = avecZones and LCM.Body.State(e) or {}
        local y = avecTotal and (c.ligne + ECART_LIGNES) or 0
        for index, partie in ipairs(etat) do
            local z = self.zones[index] or Zone(index)
            z.partieId = partie.id
            z.nom:SetText(partie.label)
            z.icone:SetTexture(partie.part.icone)
            Bulle(z, partie.label, {
                { "Maximum", Nombre(partie.max) },
                { "Blessures", Montant(partie.current - partie.max) },
                total = Nombre(partie.current), note = partie.part.description,
            })
            z.barre:Regler(partie.current, partie.max)
            z:Controles(LCM.IsMaster() and not e.distante)
            z:CaleBarre()
            z:ClearAllPoints()
            z:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            z:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            z:Show()
            y = y + c.ligne + ECART_LIGNES
        end
        for index = #etat + 1, #self.zones do self.zones[index]:Hide() end
        self:SetHeight(y - ECART_LIGNES)
    end
    l:SetHeight(c.ligne)
    return l
end

-- ----- Les traits portes ----------------------------------------------------
-- Une carte par trait : nom, cout, description, effets. Donner ou retirer un
-- trait est un geste de MJ : le joueur choisit les siens a la creation, avec
-- un budget ; ensuite, c'est la partie qui les accorde.

-- « Escalade +3  ·  Avantage : Escalade ». Trie, pour qu'un meme trait se lise
-- toujours pareil.
function Fiche.Effets(element)
    local bonus, avantages = {}, {}
    for champ, montant in pairs(element.bonus) do
        local field = LCM.Schema.Field(champ)
        bonus[#bonus + 1] = (field and field.label or champ) .. " " .. Montant(montant)
    end
    for champ in pairs(element.avantage) do
        local field = LCM.Schema.Field(champ)
        avantages[#avantages + 1] = field and field.label or champ
    end
    table.sort(bonus)
    table.sort(avantages)
    if #avantages > 0 then bonus[#bonus + 1] = "Avantage : " .. table.concat(avantages, ", ") end
    return table.concat(bonus, "  ·  ")
end
-- Les memes effets, mais RANGES : par section de la fiche, dans l'ordre de la
-- fiche, et chacun avec sa valeur a part. La version a plat (`Fiche.Effets`)
-- jetait tout sur une ligne par ordre alphabetique — « Ombre +2 · Perce-armure
-- +1 · Perforant +4 » melange une penetration, une mecanique et une autre
-- penetration, et on ne sait plus ce qu'on lit.
--
-- Rend une liste ordonnee de { titre, lignes = { { label, valeur } } }.
function Fiche.EffetsGroupes(element)
    -- L'ordre de la fiche, releve une fois : onglet, puis section, puis champ.
    if not Fiche.rangChamp then
        Fiche.rangChamp, Fiche.groupeChamp = {}, {}
        local n = 0
        for _, tab in ipairs(LCM.Schema.Tabs()) do
            for _, section in ipairs(tab.sections or {}) do
                -- Une section dont le nom se suffit n'a pas besoin de celui de
                -- son onglet ; « Élémentaires » si, sinon penetrations et
                -- resistances se ressemblent trait pour trait.
                local titre = section.label or ""
                local onglet = tab.label or tab.id
                if titre == "" then titre = onglet
                elseif onglet and onglet ~= titre then titre = onglet .. " — " .. titre end
                for _, field in ipairs(section.fields or {}) do
                    n = n + 1
                    Fiche.rangChamp[field.id] = n
                    Fiche.groupeChamp[field.id] = titre
                end
            end
        end
    end

    local plats = {}
    for champ, montant in pairs(element.bonus) do
        local field = LCM.Schema.Field(champ)
        plats[#plats + 1] = {
            id = champ,
            label = (field and field.label) or champ,
            valeur = Montant(montant),
            groupe = Fiche.groupeChamp[champ] or "Autres",
            rang = Fiche.rangChamp[champ] or 9999,
        }
    end
    table.sort(plats, function(a, b) return a.rang < b.rang end)

    local groupes, parNom = {}, {}
    for _, e in ipairs(plats) do
        local g = parNom[e.groupe]
        if not g then
            g = { titre = e.groupe, lignes = {} }
            parNom[e.groupe] = g
            groupes[#groupes + 1] = g
        end
        g.lignes[#g.lignes + 1] = { label = e.label, valeur = e.valeur }
    end

    -- Les avantages ne sont pas chiffres : ils font leur propre paquet, en bout.
    local avantages = {}
    for champ in pairs(element.avantage) do
        local field = LCM.Schema.Field(champ)
        avantages[#avantages + 1] = (field and field.label) or champ
    end
    table.sort(avantages)
    if #avantages > 0 then
        local g = { titre = "Avantage", lignes = {} }
        for _, nom in ipairs(avantages) do g.lignes[#g.lignes + 1] = { label = nom, valeur = "" } end
        groupes[#groupes + 1] = g
    end
    return groupes
end

local Effets = Fiche.Effets

-- Une carte pour tout ce qui porte des effets (trait, objet) : la fenetre
-- d'equipement s'en sert aussi. `onRetirer(id)` est appele par la croix.
-- `largeur` : celle du texte (la carte, elle, suit ses ancrages).
function Fiche.Carte(parent, onRetirer, largeur)
    largeur = largeur or 480
    local c = CreateFrame("Frame", nil, parent)
    Surface(c)
    c:EnableMouse(true)
    UI.Bulle(c, function(self) return self.nom:GetText() end, function(self)
        local description = self.description:GetText() or ""
        local effets = self.effets:GetText() or ""
        return description .. (effets ~= "" and ("\n" .. effets) or "")
    end, 0.2)

    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormal")
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -8)
    c.cout = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.cout:SetPoint("TOPRIGHT", c, "TOPRIGHT", -34, -8)
    c.cout:SetJustifyH("RIGHT")
    -- L'identifiant est porte par la carte, lu au clic : les cartes sont
    -- reutilisees d'un affichage a l'autre.
    c.retirer = UI.Bouton(c, "x", 20, 20, function() onRetirer(c.elementId) end)
    c.retirer:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -6)

    c.description = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
    c.description:SetWidth(largeur - 20)
    c.description:SetWordWrap(true)
    c.effets = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.effets:SetWidth(largeur - 20)
    c.effets:SetWordWrap(true)

    -- Remplit la carte et renvoie sa hauteur. `element` est nil quand
    -- l'identifiant ne designe plus rien ; `coin` est le texte en haut a
    -- droite (le cout d'un trait).
    function c:Habiller(id, element, mj, coin)
        self.elementId = id
        local description, effets
        if element then
            self.nom:SetText(element.label)
            self.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            self.cout:SetText(coin or "")
            description = element.description
            effets = Effets(element)
            if effets == "" then effets = "Aucun effet chiffré." end
        else
            -- Un element disparu reste montre : il est encore sur l'entite, et
            -- redevient actif s'il revient. Le taire ferait croire a une
            -- fiche saine.
            self.nom:SetText("? " .. tostring(id))
            self.nom:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
            self.cout:SetText("")
            description = "N'existe pas dans cette version de l'addon (entrée supprimée, "
                .. "ou pas encore reçue). Ne donne rien tant qu'il n'existe pas."
            effets = ""
        end
        self.retirer:SetShown(mj)

        local y = 30
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
        self.description:SetText(description or "")
        if (description or "") ~= "" then
            self.description:Show()
            y = y + self.description:GetStringHeight() + 4
        else
            self.description:Hide()
        end
        self.effets:ClearAllPoints()
        self.effets:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
        self.effets:SetText(effets)
        if effets ~= "" then
            self.effets:Show()
            y = y + self.effets:GetStringHeight() + 4
        else
            self.effets:Hide()
        end
        return y + 8
    end
    return c
end

function Lignes.traits(parent, field, c)
    local l = CreateFrame("Frame", nil, parent)
    l.cartes = {}
    l.largeur = c.largeurLigne

    l.entete = Ligne(l, c)
    Bulle(l.entete, field.label, field.note)
    l.entete:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.entete:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
    l.label = Nom(l.entete, c, field.label)
    l.resume = UI.Texte(l.entete, "", UI.C.discret)
    UI.Police(l.resume, c.police * 0.85)
    l.resume:SetPoint("LEFT", l.entete, "LEFT", c.plage, 0)

    -- Le meme bouton carre que l'equipement : « + Ajouter » ne tenait pas
    -- dans la colonne d'action (16 octobre 2026).
    l.ajouter = UI.BoutonSigne(l.entete, c.boutonH, function() l:ProposerAjout() end)
    l.ajouter:Signe("+", "Ajouter un trait", "Choisir un trait à donner à ce personnage.")
    l.ajouter:SetPoint("RIGHT", l.entete, "LEFT", c.action + c.actionLargeur, 0)
    l.choix = UI.Choix("fiche_traits", "Ajouter un trait")
    l:SetScript("OnHide", function() l.choix:Hide() end)

    l.vide = UI.Texte(l, "Aucun trait porté.", UI.C.discret, "GameFontNormalSmall")
    l.vide:SetPoint("TOPLEFT", l, "TOPLEFT", c.nomSansIcone, -(c.ligne + ECART_LIGNES + 4))

    -- Ne propose que ce qui n'est pas deja porte.
    function l:ProposerAjout()
        if not (self.entity and LCM.IsMaster()) or self.entity.distante then return end
        local options = {}
        for _, trait in ipairs(LCM.Traits.list) do
            if not LCM.Traits.Has(self.entity, trait.id) then
                local cout = LCM.Traits.Cout(trait)
                options[#options + 1] = {
                    id = trait.id,
                    label = string.format("%s  (%d pt%s)", trait.label, cout, cout > 1 and "s" or ""),
                }
            end
        end
        if #options == 0 then
            LCM.Alerte("tous les traits connus sont deja portes.")
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        self.choix:Proposer(self.ajouter, options, function(id)
            if LCM.Traits.Grant(self.entity, id) then
                local sauver = self.entity and self.entity.__sauverPNJ
                local ok, raison = true
                if type(sauver) == "function" then ok, raison = sauver(self.entity) end
                if not ok then
                    LCM.Traits.Revoke(self.entity, id)
                    LCM.Alerte("PNJ : " .. tostring(raison))
                end
                self:Changer()
            end
        end)
    end

    -- Retirer se rattrape (on redonne le trait) : pas de confirmation.
    function l:Retirer(id)
        if not (self.entity and LCM.IsMaster()) or self.entity.distante then return end
        if LCM.Traits.Revoke(self.entity, id) then
            local sauver = self.entity and self.entity.__sauverPNJ
            local ok, raison = true
            if type(sauver) == "function" then ok, raison = sauver(self.entity) end
            if not ok then
                LCM.Traits.Grant(self.entity, id)
                LCM.Alerte("PNJ : " .. tostring(raison))
            end
            self:Changer()
        end
    end

    -- La hauteur change avec le nombre de cartes : la page se re-dispose.
    function l:Changer()
        self:Actualiser(self.entity)
        if self.onChange then self.onChange(self.entity) end
    end

    function l:Actualiser(e)
        self.entity = e
        local mj = LCM.IsMaster() and not e.distante
        self.ajouter:SetShown(mj)
        -- On ne retire pas SES PROPRES traits : ils se choisissent a la
        -- creation et font le personnage. La croix restait offerte au MJ sur
        -- toutes les fiches, la sienne comprise, et un clic de travers effacait
        -- un trait paye. Sur la fiche d'un AUTRE, le MJ garde la main.
        local sien = e ~= nil and e == LCM.Entities.Self()
        local peutRetirer = mj and not sien

        local ids = LCM.Traits.Ids(e)
        local y = c.ligne + ECART_LIGNES
        for index, id in ipairs(ids) do
            local carte = self.cartes[index]
            if not carte then
                carte = Fiche.Carte(self, function(traitId) self:Retirer(traitId) end, self.largeur)
                self.cartes[index] = carte
            end
            carte:ClearAllPoints()
            carte:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            carte:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            local trait = LCM.Traits.Get(id)
            -- Exception : un trait qui n'existe plus (entree supprimee) reste
            -- retirable, meme sur sa propre fiche. Sinon il y resterait colle,
            -- sans rien donner, sans moyen de s'en defaire.
            local cout = trait and LCM.Traits.Cout(trait)
            local hauteur = carte:Habiller(id, trait, peutRetirer or (mj and trait == nil),
                cout and string.format("%d pt%s", cout, cout > 1 and "s" or ""))
            carte:SetHeight(hauteur)
            carte:Show()
            y = y + hauteur + ECART_LIGNES
        end
        for index = #ids + 1, #self.cartes do self.cartes[index]:Hide() end
        self.vide:SetShown(#ids == 0)
        if #ids == 0 then y = y + 24 end

        local cout = LCM.Traits.CoutTotal(e)
        self.resume:SetText(#ids == 0 and "" or string.format("%d trait%s  ·  %d pt%s",
            #ids, #ids > 1 and "s" or "", cout, cout > 1 and "s" or ""))
        self:SetHeight(y - ECART_LIGNES)
    end
    l:SetHeight(c.ligne)
    return l
end

-- ----- Recapitulatif -------------------------------------------------------
-- Une ligne compacte par statistique (fenetre Statistiques du template) : le
-- nom et la valeur TOTALE, toutes sources confondues — ou, pour le dossier
-- « Bonus », ce que portent traits et objets.

function Fiche.Total(e, field, mode)
    if mode == "bonus" then return LCM.Effets.Bonus(e, field.id) end
    if LCM.Effets.PRIMAIRES[field.id] then return LCM.Formules.Primaire(e, field.id) end
    if field.kind == "roll" then return LCM.Formules.Expertise(e, field.id) end
    local valeur = tonumber(LCM.Entities.Get_Value(e, field.id)) or 0
    if field.kind == "stat" then valeur = valeur + LCM.Effets.Bonus(e, field.id) end
    return valeur
end

function Lignes.recap(parent, field, c, mode)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(math.max(20, 34 * c.echelle))
    Surface(l)
    Bulle(l, field.label, function(self)
        if not self.entity then return field.note end
        if mode == "bonus" then
            return Fiche.Decomposition(self.entity, field, 0, 0, { sansBase = true })
        end
        local formule = Fiche.DecompositionFormule(self.entity, field)
        if formule then return formule end
        local base = tonumber(LCM.Entities.Get_Value(self.entity, field.id)) or 0
        local apport = field.kind == "roll" and LCM.Formules.Apport(self.entity, field.id) or 0
        return Fiche.Decomposition(self.entity, field, base, apport)
    end)
    Nom(l, c, field.label)
    UI.Police(l.nom, c.police * 0.85)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police * 0.85)
    -- Calee sur la COLONNE DE VALEUR, pas sur le bord droit de la ligne. Au
    -- bord, le nom finissait vers 110 et le chiffre vers 300 : deux cents
    -- pixels de rien entre les deux, et dans un volet etroit le chiffre
    -- sortait carrement du cadre visible. Toujours alignee a droite, donc les
    -- chiffres restent les uns sous les autres ; simplement plus pres du nom.
    l.valeur:SetPoint("RIGHT", l, "LEFT", c.valeur + c.valeurLargeur, 0)
    l.valeur:SetJustifyH("RIGHT")
    function l:Actualiser(e)
        self.entity = e
        local total = Fiche.Total(e, field, mode)
        self.valeur:SetText((mode == "bonus" and total > 0 and "+" or "") .. Nombre(total))
        -- Une valeur nulle s'efface : on lit d'un coup d'oeil ce qui compte.
        local couleur = total ~= 0 and UI.C.titre or UI.C.discret
        self.valeur:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
    return l
end

-- ----- Conteneurs -----------------------------------------------------------
-- Les conteneurs du template (Equipements, Sante › Etats, Apprentissage) : une
-- ligne par emplacement, sur le modele des emplacements Necronicon
-- (UI.LayoutAelContainerRow) — icone encadree, separateur, nom, effets. Une
-- case vide dit « Emplacement ». Placer et retirer sont des gestes de MJ.

local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

-- La liste de choix partagee par tous les conteneurs (un seul menu ouvert a
-- la fois, de toute facon).
local function Choix()
    Fiche.choixConteneur = Fiche.choixConteneur or UI.Choix("conteneur", "")
    return Fiche.choixConteneur
end

-- La carte au survol : ce que le clic droit ouvre en grand, en lecture seule
-- et sans habillage. L'infobulle du jeu ne donnait que deux lignes de texte ;
-- ici on veut voir l'objet — son icone, son nom, ce qu'il est, ses chiffres.
--
-- Bordure SIMPLIFIEE a dessein : un survol apparait et disparait sans arret,
-- et l'habillage complet d'une carte de compendium y clignoterait.
local function CarteSurvol()
    if Fiche.carteSurvol then return Fiche.carteSurvol end
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("TOOLTIP")
    p:SetSize(360, 120)
    p:EnableMouse(false)
    p:Hide()
    p.fond = UI.Aplat(p, { 0.04, 0.04, 0.05, 0.96 })
    p.fond:SetAllPoints(p)
    UI.BordureFine(p, 0.45)

    p.icone = p:CreateTexture(nil, "ARTWORK")
    p.icone:SetSize(40, 40)
    p.icone:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    p.icone:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    p.nom = UI.Texte(p, "", UI.C.titre)
    p.nom:SetPoint("TOPLEFT", p.icone, "TOPRIGHT", 10, -2)
    p.nom:SetPoint("TOPRIGHT", p, "TOPRIGHT", -26, -10)
    p.nom:SetJustifyH("LEFT")
    p.nom:SetWordWrap(true)
    p.description = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.description:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -56)
    p.description:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -56)
    p.description:SetJustifyH("LEFT")
    p.description:SetWordWrap(true)
    -- Les effets, ranges : un intertitre par section, puis ses lignes sur
    -- trois colonnes, libelle a gauche et valeur calee a droite de sa colonne.
    p.titres, p.cases = {}, {}
    p.COLONNES, p.LIGNE_H, p.TITRE_H = 3, 15, 17

    function p:Montrer(element, groupes, ancreSur)
        self.icone:SetTexture(element.icone)
        self.nom:SetText(element.label or "")
        local description = element.description or ""
        self.description:SetText(description)
        self.description:SetShown(description ~= "")
        local y = 56
        if description ~= "" then
            y = y + (self.description:GetStringHeight() or 14) + 8
        end
        local nT, nC = 0, 0
        local largeurCase = (self:GetWidth() - 20 - (self.COLONNES - 1) * 8) / self.COLONNES
        for _, groupe in ipairs(groupes or {}) do
            nT = nT + 1
            local t = self.titres[nT]
            if not t then
                t = UI.Texte(self, "", UI.C.titre, "GameFontNormalSmall")
                t:SetJustifyH("LEFT")
                self.titres[nT] = t
            end
            t:SetText(groupe.titre)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
            t:Show()
            y = y + self.TITRE_H

            for index, ligne in ipairs(groupe.lignes) do
                nC = nC + 1
                local c = self.cases[nC]
                if not c then
                    c = CreateFrame("Frame", nil, self)
                    c.label = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
                    c.label:SetPoint("LEFT", c, "LEFT", 0, 0)
                    c.label:SetJustifyH("LEFT")
                    c.label:SetWordWrap(false)
                    c.valeur = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
                    c.valeur:SetPoint("RIGHT", c, "RIGHT", 0, 0)
                    c.valeur:SetJustifyH("RIGHT")
                    self.cases[nC] = c
                end
                local col = (index - 1) % self.COLONNES
                local rang = math.floor((index - 1) / self.COLONNES)
                c:SetSize(largeurCase, self.LIGNE_H)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", self, "TOPLEFT",
                    14 + col * (largeurCase + 8), -(y + rang * self.LIGNE_H))
                c.label:SetWidth(largeurCase - 26)
                c.label:SetText(ligne.label)
                c.valeur:SetText(ligne.valeur)
                c:Show()
            end
            y = y + math.ceil(#groupe.lignes / self.COLONNES) * self.LIGNE_H + 4
        end
        for i = nT + 1, #self.titres do self.titres[i]:Hide() end
        for i = nC + 1, #self.cases do self.cases[i]:Hide() end
        self:SetHeight(math.max(62, y + 8))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", ancreSur, "TOPRIGHT", 12, 0)
        self:Show()
    end

    -- Rester sur la ligne la charge, puis l'epingle : on la lit, et la croix
    -- la ferme.
    p.fermer = UI.Bouton(p, "x", 16, 16, function() p:Hide() end)
    p.fermer:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -6)
    p.fermer:Hide()
    UI.SurvolAccrochable(p)
    Fiche.carteSurvol = p
    return p
end

-- Montre la fiche de l'element porte, comme le clic droit du compendium et de
-- l'inventaire.
local function VoirElement(conteneur, id, ancre)
    if not id or not UI.Compendium then return end
    local element, categorie = LCM.Compendium.Resoudre(
        tostring(conteneur.categorie) .. "/" .. tostring(id))
    -- Sinon on cherche l'entree dans les familles. Le repli evident — prendre
    -- la categorie du CATALOGUE — est faux : ce n'est pas une categorie de
    -- compendium, elle n'a pas de champs, et la carte plantait dessus.
    if not (element and categorie) then
        for _, cat in ipairs(LCM.Compendium.categories) do
            for _, e in ipairs(LCM.Compendium.Entrees(cat)) do
                if tostring(e.id) == tostring(id) then element, categorie = e, cat break end
            end
            if element then break end
        end
    end
    if element and categorie then UI.Compendium.Voir(categorie, element, ancre) end
end

-- La reference de compendium (« objets/dague_… ») d'un element porte. Le
-- conteneur ne la connait pas : sa `categorie` est un type d'EMPLACEMENT
-- (arme, armure), pas une famille de compendium. On tente la lecture directe,
-- puis on cherche l'entree dans les familles, comme VoirElement.
function Fiche.RefPortee(conteneur, id)
    if not (id and LCM.Compendium) then return nil end
    local direct = tostring(conteneur.categorie) .. "/" .. tostring(id)
    if LCM.Compendium.Resoudre(direct) then return direct end
    for _, cat in ipairs(LCM.Compendium.categories) do
        for _, e in ipairs(LCM.Compendium.Entrees(cat)) do
            if tostring(e.id) == tostring(id) then
                return LCM.Compendium.Reference(cat, e)
            end
        end
    end
    return nil
end

local function Emplacement(conteneur, c)
    -- Un BOUTON, pas un cadre : seuls les boutons recoivent OnClick, et sans
    -- ca le clic droit ne part jamais (c'est la panne du 1er octobre).
    local l = Ligne(conteneur, c, "Button")
    -- Deux lignes de texte : le nom en entier, la description dessous.
    l:SetHeight(math.max(52, c.ligne * 2))

    -- L'icone double : une vignette de 16 ne montrait rien d'un objet. Bornee
    -- par la hauteur de la ligne, elle ne peut pas deborder.
    Icone(l, c, VIDE, c.iconeTaille * 2)
    local depart = l.apresIcone or c.nom
    local finTexte = c.action - 8 * c.echelle

    -- Le nom en ENTIER : il etait coupe des « Capuche de... ». Il a toute la
    -- largeur jusqu'au bouton, et sa propre ligne.
    -- Les VIES, devant tout le reste : un chiffre vert tant qu'il en reste, et
    -- rouge a zero. C'est un cadre a lui pour porter son propre survol — le nom
    -- est un seul texte, on ne peut pas survoler le debut d'un texte.
    l.vies = CreateFrame("Frame", nil, l)
    l.vies:SetSize(18, math.max(14, c.police + 2))
    l.vies:SetPoint("TOPLEFT", l, "TOPLEFT", depart, -8)
    l.vies.texte = UI.Texte(l.vies, "", UI.C.discret)
    UI.Police(l.vies.texte, c.police)
    l.vies.texte:SetAllPoints(l.vies)
    l.vies.texte:SetJustifyH("LEFT")
    l.vies:EnableMouse(true)
    l.vies:SetScript("OnEnter", function(self)
        if not self.texte:GetText() or self.texte:GetText() == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Vies", 1, 0.82, 0)
        GameTooltip:AddLine(UI.AIDE_VIES, 0.8, 0.75, 0.62, true)
        GameTooltip:Show()
    end)
    l.vies:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, c.police)
    -- Le nom commence apres le chiffre des vies.
    l.nom:SetPoint("TOPLEFT", l.vies, "TOPRIGHT", 6, 0)
    l.nom:SetPoint("TOPRIGHT", l, "TOPLEFT", finTexte, -8)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    l.label = l.nom

    -- La description dessous, et les effets au bout de la meme ligne : le nom
    -- garde ainsi sa ligne pour lui seul.
    l.description = UI.Texte(l, "", UI.C.discret)
    UI.Police(l.description, c.police * 0.78)
    l.description:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -3)
    l.description:SetJustifyH("LEFT")
    l.description:SetWordWrap(false)

    -- La description prend toute la ligne. Les chiffres (« Perce-armure +1 ·
    -- Perforant +4 ») etaient affiches ici : ils disent ce que l'objet FAIT,
    -- pas ce qu'il EST, et la carte au survol les donne deja. Sous le nom, on
    -- veut savoir de quoi il s'agit.
    l.description:SetPoint("TOPRIGHT", l, "TOPLEFT", finTexte, -(8 + c.police + 5))
    -- Garde pour le code qui l'alimente encore : jamais dessine.
    l.effets = UI.Texte(l, "", UI.C.accent)
    l.effets:Hide()

    -- Le bout droit de la ligne EST le bouton (UI.BoutonDegrade, dessin du MJ
    -- du 16 octobre 2026) : « + » pour equiper, « × » pour retirer, sur toute
    -- la hauteur. Deux largeurs de colonne d'action, dont le signe occupe la
    -- seconde : le nom, qui s'arrete avant elle, ne passe jamais dessous.
    -- « + Ajouter » ne tenait pas dans la colonne et se coupait en « + Aj… ».
    --
    -- C'est TOUTE la case qui se clique (le MJ, 16 octobre 2026) : il fallait
    -- viser le fondu. Le bouton ne capte donc plus la souris ; la ligne recoit
    -- le clic et allume le fondu a son survol.
    function l:Agir()
        if self.elementId then conteneur:Retirer(self.elementId, self.rangPorte) else conteneur:Proposer(self.action) end
    end
    l.action = UI.BoutonDegrade(l, function() l:Agir() end)
    l.action:EnableMouse(false)
    l.action:SetPoint("TOPRIGHT", l, "TOPRIGHT", -1, -1)
    l.action:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", -1, 1)
    l.action:SetPoint("LEFT", l, "LEFT", c.action - c.actionLargeur, 0)

    -- Cible de glissement : on y depose un objet venu d'un sac, s'il va dans
    -- cette categorie. Equiper demandait d'ouvrir le menu « + Ajouter » et de
    -- retrouver l'objet dans une liste, alors qu'on l'a sous la souris.
    if UI.Glisser then
        UI.Glisser.Cible(l, function(objet)
            if conteneur.entity and conteneur.entity.distante then
                return false, "fiche distante en lecture seule."
            end
            -- Equiper ce qu'on possede est un geste de joueur ; seul un objet
            -- tire du COMPENDIUM (sans origine) est une fabrication, donc
            -- reserve au MJ (12 octobre 2026).
            if objet.origine == nil and not LCM.IsMaster() then
                return false, "sortir un objet du compendium est un geste du maître du jeu."
            end
            if l.elementId then return false, "cet emplacement est déjà pris." end
            local ref = tostring(objet.ref or "")
            local famille, id = ref:match("^([%w_]+)/(.+)$")
            if not famille then
                -- Glisse depuis le compendium : l'element porte sa categorie.
                id = objet.element and objet.element.id
            end
            if not id then return false, "on ne sait pas ce que c'est." end
            local element = conteneur.catalogue.Get(id)
            if not element then
                return false, "cet objet n'appartient pas à cette famille."
            end
            if element.categorie ~= conteneur.categorie then
                return false, string.format("« %s » ne se porte pas ici.", element.label)
            end
            if conteneur.catalogue == LCM.Objets and (tonumber(objet.quantite) or 1) ~= 1 then
                return false, "sépare un exemplaire de la pile avant de l'équiper."
            end
            return true
        end, function(objet)
            local ref = tostring(objet.ref or "")
            local _, id = ref:match("^([%w_]+)/(.+)$")
            id = id or (objet.element and objet.element.id)
            local ok, raison = conteneur.catalogue.Placer(conteneur.entity, id,
                objet.exemplaires and objet.exemplaires[1])
            if not ok then
                LCM.Alerte(tostring(raison))
                return
            end
            -- Equipe : il quitte la place d'ou il vient, sinon il existerait
            -- en deux exemplaires. C'est la SOURCE qui sait comment : une case
            -- de sac se vide, un autre emplacement se deshabille.
            if objet.retirer then objet.retirer() end
            -- La fiche d'un modele PNJ ouverte depuis le compendium est une
            -- entite de travail. Le bouton « Ajouter » passait deja par cette
            -- sauvegarde, mais pas le glisser-deposer : l'objet semblait porte
            -- jusqu'a la fermeture, puis disparaissait a la reouverture.
            -- En cas de refus, on remet aussi bien la destination que la source
            -- dans leur etat initial afin de ne perdre aucun objet.
            if not conteneur:SauverPNJ() then
                conteneur.catalogue.Enlever(conteneur.entity, id)
                if objet.rendre then objet.rendre() end
            end
            conteneur:Actualiser(conteneur.entity)
        end)

        -- ... et une SOURCE : on reprend ce qu'on porte pour le ranger dans un
        -- sac. L'emplacement ne savait que recevoir, si bien qu'on equipait en
        -- glissant mais qu'on ne pouvait pas desequiper de meme (5 octobre
        -- 2026).
        l:RegisterForDrag("LeftButton")
        l:SetScript("OnDragStart", function(self)
            if not self.elementId then return end
            if not conteneur:Autorise(conteneur.entity) then return end
            local element = conteneur.catalogue.Get(self.elementId)
            local porte = self.elementId
            local exemplaire = conteneur.catalogue.PreparerExemplaireEquipe
                and conteneur.catalogue.PreparerExemplaireEquipe(conteneur.entity, porte, self.rangPorte)
            UI.Glisser.Commencer({
                icone = element and element.icone or nil,
                nom = element and element.label or tostring(porte),
                ref = Fiche.RefPortee(conteneur, porte),
                element = element,
                quantite = 1,
                exemplaires = exemplaire and {LCM.Copie(exemplaire)} or nil,
                origine = { equipement = conteneur, id = porte },
                -- Quitter l'emplacement, et savoir y revenir si le rangement
                -- echoue : un objet perdu entre le corps et le sac serait pire
                -- que le refus.
                retirer = function()
                    conteneur.catalogue.Enlever(conteneur.entity, porte, exemplaire and exemplaire.id)
                    conteneur:Actualiser(conteneur.entity)
                end,
                rendre = function()
                    conteneur.catalogue.Placer(conteneur.entity, porte, exemplaire)
                    conteneur:Actualiser(conteneur.entity)
                end,
            })
        end)
        l:SetScript("OnDragStop", function() UI.Glisser.Lacher() end)
    end

    -- Clic droit : la fiche de l'objet porte. Il manquait — on voyait l'objet
    -- sur soi sans pouvoir le lire. Clic gauche, n'importe ou sur la case :
    -- equiper ou retirer, quand le bouton est offert.
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l:SetScript("OnClick", function(self, bouton)
        if bouton == "RightButton" then VoirElement(conteneur, self.elementId, self)
        elseif self.action:IsShown() then self:Agir() end
    end)

    -- Survol : la carte de l'objet quand il y en a un, l'infobulle sinon (une
    -- case vide n'a pas de carte a montrer). Et le fondu s'allume.
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if self.action:IsShown() then self.action:Eclairer(true) end
        if self.survol then
            local carte, survol = CarteSurvol(), self.survol
            local ligne = self
            carte:SuivreSurvol(self, function() carte:Montrer(survol.element, survol.groupes, ligne) end)
        elseif self.bulle and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.bulle.titre)
            GameTooltip:AddLine(self.bulle.texte, 0.88, 0.84, 0.76, true)
            GameTooltip:Show()
        end
    end)
    l:SetScript("OnLeave", function(self)
        self.action:Eclairer(false)
        if Fiche.carteSurvol then Fiche.carteSurvol:QuitterSurvol() end
        if GameTooltip then GameTooltip:Hide() end
    end)

    function l:Habiller(catalogue, id, mj)
        self.elementId = id
        local element = id and catalogue.Get(id)
        if not id then
            self.icone:SetTexture(VIDE)
            UI.TeinterBrise(self.icone, false)
            self.vies.texte:SetText("")
            self.vies:Hide()
            self.nom:SetText("Emplacement")
            self.nom:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
            self.description:SetText("")
            self.effets:SetText("")
            self.survol = nil
            self.bulle = { titre = "Emplacement", texte = mj and "Emplacement disponible. Clic : équiper."
                or "Emplacement disponible." }
            self.action:Signe("+", "Équiper", "Choisir ce qu'on porte ici. On peut aussi y glisser un objet d'un sac.")
        elseif element then
            self.icone:SetTexture(element.icone)
            -- L'etat DEVANT le nom : « (8/12) Rempart de guerre ». Il n'etait
            -- lisible que dans la carte au survol, alors que c'est en regardant
            -- ce qu'on porte qu'on veut savoir ce qui tient encore.
            -- CET exemplaire : deux capuches identiques n'ont pas le meme etat.
            local exemplaire = LCM.Objets.ExemplairePorte
                and LCM.Objets.ExemplairePorte(conteneur.entity, element.categorie, self.rangPorte)
            local vies, _, _, couleurVies = UI.ViesObjet(conteneur.entity, element, exemplaire)
            self.vies.texte:SetText(vies or "")
            if couleurVies then
                self.vies.texte:SetTextColor(couleurVies[1], couleurVies[2], couleurVies[3])
            end
            self.vies:SetShown(vies ~= nil)
            local etat, reste, plein = UI.EtatObjet(conteneur.entity, element, exemplaire)
            local brise = UI.ObjetBrise(conteneur.entity, element, exemplaire)
            local marque = brise and (UI.MARQUE_BRISE .. " ") or ""
            if etat then
                self.nom:SetText(string.format("|cff%s(%s)|r %s%s",
                    UI.Hex(UI.CouleurEtat(reste, plein)), etat, marque, element.label))
            else
                self.nom:SetText(marque .. element.label)
            end
            local couleurNom = brise and UI.C.plein or UI.C.titre
            self.nom:SetTextColor(couleurNom[1], couleurNom[2], couleurNom[3])
            UI.TeinterBrise(self.icone, brise)
            local effets = Effets(element)
            -- L'etat forge suit chaque arme, armure et accessoire. L'afficher
            -- ici rend visible ce que le dispatch de degats peut casser.
            local maximum = LCM.Objets.EtatMax(element)
            local courant = math.max(0, maximum - LCM.Objets.Usure(conteneur.entity, element.id, exemplaire))
            local infos = { string.format("État %d / %d", courant, maximum) }
            if element.armure then infos[#infos + 1] = string.format("Armure %d", element.armure) end
            local etat = table.concat(infos, "  ·  ")
            effets = effets ~= "" and (etat .. "  ·  " .. effets) or etat
            self.effets:SetText(effets)
            -- La description sous le nom : elle n'existait que dans l'infobulle,
            -- qu'il fallait aller chercher a la souris.
            self.description:SetText(element.description or "")
            -- La carte au survol remplace l'infobulle : elle montre l'objet.
            self.survol = { element = element, groupes = Fiche.EffetsGroupes(element) }
            self.bulle = nil
            self.action:Signe("×", "Retirer", "Ne plus porter cet objet.")
        else
            -- Disparu : il occupe toujours sa case, et redevient actif s'il
            -- revient.
            self.icone:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            UI.TeinterBrise(self.icone, false)
            -- Un objet disparu n'a pas de vies a montrer : son chiffre doit
            -- s'effacer, sinon il garde celui de l'objet d'avant.
            self.vies.texte:SetText("")
            self.vies:Hide()
            self.nom:SetText("? " .. tostring(id))
            self.nom:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
            self.description:SetText("")
            self.effets:SetText("")
            self.survol = nil
            self.bulle = { titre = tostring(id),
                           texte = "N'existe pas dans cette version de l'addon : ne donne rien." }
            self.action:Signe("×", "Retirer", "Il ne donne rien : le retirer libère la place.")
        end
        self.action:SetShown(mj)
    end
    return l
end

-- Les etats temporaires (Core/EtatsTemporaires.lua) : une ligne par etat —
-- icone, nom, effets, duree. Le MJ peut retirer ; un etat qui se guerit par
-- un jet propose « Guérir ». Aucun : une ligne le dit.
function Lignes.temporaires(bloc, c, conteneur)
    local l = CreateFrame("Frame", nil, bloc)
    l.lignes = {}
    l.vide = UI.Texte(l, "Aucun état temporaire.", UI.C.discret)
    UI.Police(l.vide, c.police * 0.85)
    l.vide:SetPoint("TOPLEFT", l, "TOPLEFT", 8, -6)
    function l:Actualiser(e)
        self.entity = e
        local T = LCM.EtatsTemporaires
        local liste = T.Liste(e, self.conteneur)
        local y = 0
        for i, etat in ipairs(liste) do
            local r = self.lignes[i]
            if not r then
                r = Ligne(self, c)
                r:SetHeight(math.max(40, c.ligne))
                Icone(r, c, VIDE)
                Nom(r, c, "", true)
                r.effets = UI.Texte(r, "", UI.C.accent)
                UI.Police(r.effets, c.police * 0.72)
                r.effets:SetPoint("LEFT", r, "LEFT", c.plage, 0)
                r.effets:SetPoint("RIGHT", r, "LEFT", c.action - 8 * c.echelle, 0)
                r.effets:SetJustifyH("RIGHT")
                r.effets:SetWordWrap(false)
                r.action = UI.Bouton(r, "", c.actionLargeur, c.boutonH, function(self_)
                    local et = self_:GetParent().etat
                    local ent = l.entity
                    if not (et and ent) then return end
                    if et.guerison and et.guerison.mode == "rand" and not LCM.IsMaster() then
                        local _, ligne = T.Guerir(ent, et.nom)
                        if ligne then LCM.Actions.Annoncer(ligne) end
                    else
                        T.Retirer(ent, et.nom)
                    end
                end)
                r.action:SetPoint("LEFT", r, "LEFT", c.action, 0)
                UI.Police(r.action.label, c.police * 0.8)
                self.lignes[i] = r
            end
            r.etat = etat
            r.icone:SetTexture(LCM.Icone(etat.icone))
            -- Un DOT porte ses stacks devant son nom : c'est le nombre qui dit
            -- combien il mord, et celui qu'une dissipation fait tomber.
            local dotResume, dotStacks, dotRand
            if LCM.Dot then dotResume, dotStacks, dotRand = LCM.Dot.Resume(e, etat) end
            r.nom:SetText(dotStacks and string.format("x%d  %s", dotStacks, etat.nom) or etat.nom)
            local couleur = etat.debuff and UI.C.plein or UI.C.titre
            r.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
            local effets = {}
            for champ, n in pairs(etat.bonus or {}) do
                local field = LCM.Schema.Field(champ)
                effets[#effets + 1] = string.format("%s %+d", field and field.label or champ, n)
            end
            table.sort(effets)
            -- Ce qu'il grignote passe AVANT la durée : c'est ce qu'on regarde.
            if dotResume and dotResume ~= "" then
                table.insert(effets, 1, dotResume)
            end
            r.effets:SetText(table.concat(effets, ", ") .. "  |cff9a9a9a" .. T.Duree(etat) .. "|r")
            local aide = ((etat.description or "") ~= "" and (etat.description .. "\n\n") or "")
                .. (etat.lanceur and ("De " .. etat.lanceur .. ". ") or "") .. "Durée : " .. T.Duree(etat)
            if dotStacks then
                -- Le rand COURANT, puisqu'il baisse d'un round a l'autre : sans
                -- lui on ne peut pas juger si une dissipation valait le coup.
                aide = aide .. string.format("\n\n%d stack%s, %s par round."
                    .. "\nÀ battre pour dissiper : %d — et chaque point au-dessus"
                    .. " emporte un stack de plus.", dotStacks, dotStacks > 1 and "s" or "",
                    dotResume ~= "" and dotResume or "rien", dotRand or 0)
            end
            Bulle(r, etat.nom, aide)
            local guerir = etat.guerison and etat.guerison.mode == "rand" and not LCM.IsMaster()
            r.action.label:SetText(guerir and string.format("Guérir (%s)", etat.guerison.competence) or "Retirer")
            r.action:SetShown(not e.distante and (LCM.IsMaster() or guerir))
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            r:Show()
            y = y + r:GetHeight() + 2
        end
        for i = #liste + 1, #self.lignes do self.lignes[i]:Hide() end
        self.vide:SetShown(#liste == 0)
        local h = math.max(#liste == 0 and 24 or 0, y)
        if h ~= self.hauteur then
            self.hauteur = h
            self:SetHeight(h)
            if self.onChange then self.onChange() end
        end
    end
    return l
end

-- Un conteneur : autant de lignes que d'emplacements. `bloc` recoit le compte
-- « occupes / total ».
function Lignes.conteneur(bloc, def, c)
    local l = CreateFrame("Frame", nil, bloc)
    l.catalogue, l.categorie = def.catalogue, def.categorie
    l.emplacements = {}
    local m = UI.AelMesures(c.largeurLigne)
    bloc.occupation = UI.Texte(bloc, "", UI.C.titre)
    UI.Police(bloc.occupation, m.titre * 0.6)
    -- Aligne sur le HAUT du titre, comme lui : ancre au centre, il flottait
    -- d'une demi-ligne trop haut.
    bloc.occupation:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -26 * m.echelle, -(bloc.hautTitre - 4) / 2 + 2)

    -- Un catalogue qui s'equipe depuis les sacs (les objets) : chacun habille
    -- son propre personnage, et l'on ne propose que ce qu'il porte dans ses
    -- sacs. Les autres (etats, apprentissages) restent un geste du MJ.
    local depuisLesSacs = l.catalogue.Equiper ~= nil

    -- Une fiche de modele PNJ n'a pas de sacs : le compendium lui attribue
    -- directement ses objets. Les personnages ordinaires conservent le
    -- circuit inventaire -> equipement.
    function l:DepuisLesSacs()
        return depuisLesSacs and not (self.entity and self.entity.editionPNJ)
    end

    function l:SauverPNJ()
        if not (self.entity and type(self.entity.__sauverPNJ) == "function") then return true end
        local ok, raison = self.entity.__sauverPNJ(self.entity)
        if not ok then LCM.Alerte("PNJ : " .. tostring(raison)) end
        return ok
    end

    function l:Autorise(entity)
        if not entity then return false end
        if entity.distante then return false end
        if LCM.IsMaster() then return true end
        return self:DepuisLesSacs() and LCM.Personnages.Actif() == entity
    end

    function l:Proposer(ancre)
        if not self:Autorise(self.entity) then return end
        local categorie = self.catalogue.Categorie(self.categorie)
        local sacs = self:DepuisLesSacs()
        local candidats = sacs and self.catalogue.CandidatsPossedes(self.entity, self.categorie)
            or self.catalogue.Candidats(self.entity, self.categorie)
        local options = {}
        for _, element in ipairs(candidats) do
            options[#options + 1] = { id = element.id, label = element.label }
        end
        if #options == 0 then
            LCM.Alerte(sacs
                and string.format("aucun objet de type %s dans les sacs.", categorie.label:lower())
                or string.format("rien a ajouter en %s.", categorie.label:lower()))
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        local choix = Choix()
        choix.titre:SetText(categorie.label)
        choix:Proposer(ancre, options, function(id)
            local placer = sacs and self.catalogue.Equiper or self.catalogue.Placer
            local ok, raison = placer(self.entity, id)
            if not ok then
                LCM.Alerte(raison)
            elseif not self:SauverPNJ() then
                self.catalogue.Enlever(self.entity, id)
            end
            self:Actualiser(self.entity)
        end)
    end

    -- Retirer se rattrape (on replace) : pas de confirmation. Un objet
    -- retourne dans un sac ; sans place, il reste porte et c'est dit.
    function l:Retirer(id, rang)
        if not self:Autorise(self.entity) then return end
        if self:DepuisLesSacs() then
            -- Un objet disparu de cette version ne peut pas retourner dans un
            -- sac (une case refuse l'inconnu) : seul le MJ l'enleve, d'un clic
            -- explicite, comme avant.
            if not self.catalogue.Get(id) and LCM.IsMaster() then
                if self.catalogue.Enlever(self.entity, id) then self:Actualiser(self.entity) end
                return
            end
            local ok, raison = self.catalogue.Desequiper(self.entity, id, rang)
            if not ok then LCM.Alerte(raison) end
            self:Actualiser(self.entity)
        elseif self.catalogue.Enlever(self.entity, id) then
            if not self:SauverPNJ() then self.catalogue.Placer(self.entity, id) end
            self:Actualiser(self.entity)
        end
    end

    function l:Actualiser(e)
        self.entity = e
        local mj = self:Autorise(e)
        local portes = self.catalogue.Ids(e, self.categorie)
        local places = self.catalogue.Capacite(self.categorie)
        -- Les PLACES prises, pas le nombre d'objets : une arme a deux mains en
        -- prend deux, et le compte doit le dire, sinon on cherche en vain la
        -- main libre qu'il annonce (5 octobre 2026).
        local occupe = self.catalogue.Occupation and self.catalogue.Occupation(e, self.categorie)
            or #portes
        -- Au-dessus du total (capacite reduite apres coup), le compte passe au
        -- rouge : rien n'est retire en douce.
        bloc.occupation:SetText(string.format("%d / %d", occupe, places))
        local couleur = (occupe > places) and UI.C.plein or UI.C.titre
        bloc.occupation:SetTextColor(couleur[1], couleur[2], couleur[3])
        -- Les cases occupees, puis UNE case libre tant qu'il reste de la
        -- place : trente cases vides ne disent rien de plus qu'une seule.
        -- Sauf categorie qui demande toutes ses places (l'armure).
        local categorie = self.catalogue.Categorie(self.categorie)
        -- Une case libre en plus seulement s'il RESTE une place : a cote d'une
        -- arme a deux mains, il n'y en a pas.
        local n = (occupe < places) and (#portes + 1) or #portes
        n = math.max(#portes, n)
        if categorie and categorie.toutesLesCases then n = math.max(#portes, places) end
        local y = 0
        for index = 1, n do
            local ligne = self.emplacements[index]
            if not ligne then
                ligne = Emplacement(self, c)
                self.emplacements[index] = ligne
            end
            -- Le rang AVANT l'habillage : c'est lui qui dit quel exemplaire
            -- montrer, et donc quel etat.
            ligne.rangPorte = index
            ligne:Habiller(self.catalogue, portes[index], mj)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            ligne:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            ligne:Show()
            y = y + ligne:GetHeight() + ECART_LIGNES
        end
        for index = n + 1, #self.emplacements do self.emplacements[index]:Hide() end
        self:SetHeight(math.max(1, y - ECART_LIGNES))
        if self.onChange then self.onChange(e) end
    end
    l:SetScript("OnHide", function() if Fiche.choixConteneur then Fiche.choixConteneur:Hide() end end)
    return l
end

-- ===== Blocs de section ====================================================
-- Un bloc par section (UI.SkinFicheBlocks) : cadre du modele, titre en
-- capitales suivi de son ornement, filet sous le titre, gemme au sommet.

local MARGE_BLOC = 10
Fiche.MARGE_BLOC = MARGE_BLOC
Fiche.ECART_LIGNES = ECART_LIGNES

function Fiche.Bloc(parent, section, largeur)
    local b = CreateFrame("Frame", nil, parent)
    local m = UI.AelMesures(largeur)
    local q = largeur / 822
    -- Le bloc garde ce qui l'a produit : un sommaire a besoin de son titre et
    -- de savoir ou il se trouve dans la page.
    b.section = section
    b.aTitre = section.label ~= ""
    b.hautTitre = b.aTitre and math.max(24, 50 * m.echelle) or 0
    if b.aTitre then
        if UI.AelCadre then
            b.cadre = UI.AelCadre(b, "section")
            b.gemme = UI.AelRef(b, 501, 656, 27, 25, "OVERLAY")
            b.gemme:SetSize(9, 9)
            b.gemme:SetPoint("TOP", b, "TOP", 0, 5)
        end
        b.titre = UI.Texte(b, UI.Majuscules(section.label), UI.C.titreBloc)
        -- + 2 : a cette densite le titre de bloc se confondait avec ses lignes,
        -- alors que c'est lui qui dit de quoi parle le paquet (3 octobre 2026).
        UI.Police(b.titre, m.titre * 0.8 + 2)
        b.titre:SetPoint("TOPLEFT", b, "TOPLEFT", math.max(14, 26 * m.echelle), -(b.hautTitre - 4) / 2 + 2)
        if UI.AelRef then
            b.ornement = UI.AelRef(b, 347, 344, 45, 17, "ARTWORK")
            b.ornement:SetSize(45 * m.echelle, 17 * m.echelle)
            b.ornement:SetPoint("LEFT", b.titre, "RIGHT", 12 * m.echelle, 0)
        end
        b.filet = UI.Aplat(b, { 0.48, 0.36, 0.19, 0.8 }, "ARTWORK")
        b.filet:SetHeight(1)
        b.filet:SetPoint("TOPLEFT", b, "TOPLEFT", 10 * q, -b.hautTitre)
        b.filet:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10 * q, -b.hautTitre)
        -- Un bloc repliable (le recapitulatif) : un clic sur son titre, un
        -- signe a droite pour dire dans quel etat il est.
        if section.repliable then
            b.replie = section.replie == true
            b.bascule = CreateFrame("Button", nil, b)
            b.bascule:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            b.bascule:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
            b.bascule:SetHeight(b.hautTitre)
            b.signe = UI.Texte(b.bascule, "", UI.C.titre)
            UI.Police(b.signe, m.titre * 0.8)
            b.signe:SetPoint("RIGHT", b.bascule, "RIGHT", -26 * m.echelle, 0)
            b.survolTitre = UI.Aplat(b.bascule, UI.C.survol, "HIGHLIGHT")
            b.survolTitre:SetAllPoints(b.bascule)
        end
    end
    -- Un paragraphe : la description d'une fenetre du template.
    if section.texte and section.texte ~= "" then
        b.paragraphe = UI.Texte(b, section.texte, UI.C.texte)
        UI.Police(b.paragraphe, section.taille or math.max(11, m.police * 0.75))
        b.paragraphe:SetWidth(largeur - 40)
        -- Le bloc sait se re-largir : son paragraphe se recoupe tout seul.
        function b:Largeur(l)
            self.paragraphe:SetWidth(math.max(80, l - 40))
        end
        b.paragraphe:SetWordWrap(true)
        b.paragraphe:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(b.hautTitre + 12))
    end
    b.lignes = {}
    return b
end
local Bloc = Fiche.Bloc

-- ===== La page =============================================================

-- Une page : des sections du schema, en blocs. La fiche en fait un onglet ; les
-- fenetres du menu (UI/Vues.lua) en font une fenetre a part avec les MEMES
-- lignes — une seule facon de montrer un champ dans l'addon.
--
-- `largeur` : celle de la page. Les colonnes des lignes s'en deduisent.
-- Une ligne de JET porte, a droite de son nom, quatre colonnes de plus : la
-- plage, la valeur, le bonus et le bouton. Quand un bloc elargit sa colonne de
-- noms pour ne couper aucun libelle, il faut les pousser d'autant — sans quoi
-- le libelle leur passe dessus.
--
-- Les colonnes du jet sont larges pour des textes de deux ou trois signes : ce
-- sont elles qui cedent la place, dans l'ordre plage (« 0-15 »), valeur,
-- bonus, chacune jusqu'a la largeur de ce qu'elle ecrit. Le bouton ne bouge
-- que si ca ne suffit pas. Tout decaler d'un bloc poussait le bouton Jet hors
-- du cadre dans une vue a largeur fixe (Expertises › Observations :
-- « Investigation », « Communication », 13 octobre 2026).
-- Rend ce dont le bouton a du bouger.
function Fiche.DecalerJet(ligne, c, decalage)
    if decalage <= 0 then return 0 end
    local function Texte(t) return Fiche.LargeurTexte(t, c.police) end
    local reste = decalage
    local function Ceder(largeur, minimum)
        local cede = math.max(0, math.min(reste, largeur - minimum))
        reste = reste - cede
        return cede
    end
    local cedePlage = Ceder(c.plageLargeur, ligne.plage and (Texte(ligne.plage:GetText()) + 8) or 0)
    local cedeValeur = Ceder(c.valeurLargeur, Texte("00") + 8)
    -- Le bonus partage sa colonne avec la case d'avantage, calee a droite.
    local caseAvantage = ligne.avantage and ligne.avantage:GetWidth() or 0
    local cedeBonus = Ceder(c.modificateurLargeur, caseAvantage + Texte("+00") + 6)

    local function Poser(region, x, largeur)
        if not region then return end
        region:ClearAllPoints()
        region:SetPoint("LEFT", ligne, "LEFT", x, 0)
        if largeur then region:SetWidth(math.max(1, largeur)) end
    end
    -- Chaque colonne commence ou la precedente finit desormais : decalee de ce
    -- que le nom a pris, moins ce que les colonnes d'avant ont rendu.
    Poser(ligne.plage, c.plage + decalage, c.plageLargeur - cedePlage)
    local apresPlage = decalage - cedePlage
    Poser(ligne.valeur, c.valeur + apresPlage, c.valeurLargeur - cedeValeur)
    local apresValeur = apresPlage - cedeValeur
    Poser(ligne.bonus, c.modificateur + apresValeur,
        c.modificateurLargeur - cedeBonus - 22 * c.echelle)
    Poser(ligne.lancer, c.action + reste)
    if ligne.avantage then
        ligne.avantage:ClearAllPoints()
        ligne.avantage:SetPoint("RIGHT", ligne, "LEFT",
            c.modificateur + c.modificateurLargeur + reste, 0)
    end
    return reste
end

function Fiche.Page(parent, sections, largeur)
    largeur = largeur or 520
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page.lignes, page.blocs = {}, {}

    local largeurLigne = largeur - 2 * MARGE_BLOC
    local c = UI.AelColonnes(largeurLigne)
    c.largeurLigne = largeurLigne
    page.colonnes = c

    for _, section in ipairs(sections) do
        local bloc = Bloc(page, section, largeur)
        if bloc.bascule then
            bloc.bascule:SetScript("OnClick", function()
                bloc.replie = not bloc.replie
                page:Disposer()
            end)
        end
        if section.temporaires then
            local ligne = Lignes.temporaires(bloc, c,
                type(section.temporaires) == "string" and section.temporaires or nil)
            ligne.conteneur = type(section.temporaires) == "string" and section.temporaires or nil
            ligne.onChange = function() if not page.enDisposition then page:Disposer() end end
            bloc.lignes[#bloc.lignes + 1] = ligne
            page.lignes[#page.lignes + 1] = ligne
        end
        if section.conteneur then
            local ligne = Lignes.conteneur(bloc, section.conteneur, c)
            ligne.onChange = function() if not page.enDisposition then page:Disposer() end end
            bloc.conteneur = ligne
            bloc.lignes[#bloc.lignes + 1] = ligne
            page.lignes[#page.lignes + 1] = ligne
        end
        for _, field in ipairs(section.fields) do
            local fabrique = Lignes[field.kind]
            if section.recap then
                local mode = section.recap
                fabrique = function(p, f, col) return Lignes.recap(p, f, col, mode) end
            end
            -- Un champ masque (le maximum brut des PV, deja dans la jauge) ou
            -- reserve au MJ (une surcharge) ne se dessine pas pour les autres.
            local visible = not field.masque and (not field.mjSeulement or LCM.IsMaster())
            if fabrique and visible then
                local ligne = fabrique(bloc, field, c, section.options and section.options[field.id])
                ligne.field = field
                -- Une ligne qui change de hauteur (corps, traits) le signale :
                -- la page se re-dispose.
                ligne.onChange = function() page:Disposer() end
                bloc.lignes[#bloc.lignes + 1] = ligne
                page.lignes[#page.lignes + 1] = ligne
            end
        end
        -- Les libelles ne se coupent PAS. La colonne de noms est calee sur le
        -- gabarit (205 unites), et « Distance de saut horizontal » n'y tient
        -- pas : on lisait « Distance de… » deux fois de suite, sans pouvoir
        -- distinguer l'horizontal du vertical. On mesure le plus long du bloc
        -- et on pousse la valeur d'autant — par BLOC, donc les chiffres
        -- restent alignes entre eux la ou on les compare.
        local plusLong = 0
        for _, ligne in ipairs(bloc.lignes) do
            if ligne.nom and ligne.valeur and ligne.field then
                plusLong = math.max(plusLong, Fiche.LargeurTexte(ligne.field.label, c.police) + 6)
            end
        end
        if plusLong > 0 then
            local depart = c.nom
            local largeur = math.max(plusLong, c.nomLargeur)
            local decalage = math.max(0, largeur - c.nomLargeur)
            local avecJet, resteJet = false, 0
            for _, ligne in ipairs(bloc.lignes) do
                if ligne.nom and ligne.valeur and ligne.field then
                    ligne.nom:SetWidth(largeur)
                    if ligne.lancer then
                        -- Une ligne de JET garde ses colonnes : son bord droit
                        -- est pris par le bouton. Epinglee au bord comme les
                        -- autres, la valeur passait DESSOUS — on lisait « +1 »
                        -- (le bonus) a cote d'un vide, et le total nulle part
                        -- (5 octobre 2026).
                        avecJet = true
                        resteJet = math.max(resteJet, Fiche.DecalerJet(ligne, c, decalage))
                    else
                        -- Au BOUT de la ligne, pas a une abscisse calculee :
                        -- une fois le bloc taille sur son contenu, le bord est
                        -- justement la ou la valeur doit tomber. Calee sur un
                        -- point fixe, elle restait au milieu d'un bloc devenu
                        -- plus large que prevu (4 octobre 2026).
                        ligne.valeur:ClearAllPoints()
                        ligne.valeur:SetPoint("RIGHT", ligne, "RIGHT", -MARGE_VALEUR, 0)
                    end
                end
            end
            -- Ce qu'il FAUDRAIT a ce bloc pour que rien ne soit coupe ni ne
            -- flotte : le libelle le plus long, puis la valeur, puis la marge.
            -- La vue s'en sert pour se tailler a son contenu au lieu de garder
            -- une largeur fixe ou l'on voit du vide a droite.
            bloc.largeurVoulue = math.ceil(depart + largeur + c.valeurLargeur + 14)
            if avecJet then
                -- Avec un jet, il faut aussi la plage, le bonus et le bouton.
                bloc.largeurVoulue = math.ceil(c.action + c.actionLargeur
                    + resteJet + 2 * MARGE_BLOC)
            end
        end

        if #bloc.lignes > 0 or section.texte then
            page.blocs[#page.blocs + 1] = bloc
        else
            bloc:Hide()
        end
    end

    page.largeurVoulue = 0
    for _, bloc in ipairs(page.blocs) do
        page.largeurVoulue = math.max(page.largeurVoulue, bloc.largeurVoulue or 0)
    end

    -- Pose blocs et lignes de haut en bas : certaines lignes (corps, traits)
    -- changent de hauteur avec l'entite.
    -- Changer la largeur d'une page : pour une fenetre qu'on tire. Les blocs
    -- s'etirent et les paragraphes se re-coupent tout seuls.
    --
    -- ATTENTION : les colonnes des LIGNES de fiche (`c`) gardent les mesures du
    -- depart. C'est sans effet sur une page de texte (les Regles), qui n'a pas
    -- de ligne ; une page de fiche ne doit pas etre redimensionnee tant que `c`
    -- ne se recalcule pas.
    function page:Largeur(nouvelle)
        nouvelle = math.max(120, tonumber(nouvelle) or largeur)
        if nouvelle == largeur then return end
        largeur = nouvelle
        for _, bloc in ipairs(self.blocs) do
            if bloc.Largeur then bloc:Largeur(largeur) end
        end
        self:Disposer()
    end

    function page:Disposer()
        local y = 0
        for _, bloc in ipairs(self.blocs) do
            local yb = bloc.hautTitre + (bloc.aTitre and 8 or 0)
            if bloc.paragraphe then
                yb = yb + (bloc.paragraphe:GetStringHeight() or 14) + 12
            end
            if bloc.signe then bloc.signe:SetText(bloc.replie and "+" or "-") end
            for _, ligne in ipairs(bloc.lignes) do
                -- Replie : on ne garde que le titre.
                ligne:SetShown(not bloc.replie)
                if not bloc.replie then
                    ligne:ClearAllPoints()
                    ligne:SetPoint("TOPLEFT", bloc, "TOPLEFT", MARGE_BLOC, -yb)
                    ligne:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -MARGE_BLOC, -yb)
                    yb = yb + ligne:GetHeight() + ECART_LIGNES
                end
            end
            local hauteur = bloc.replie and (bloc.hautTitre + 4) or (yb - ECART_LIGNES + MARGE_BLOC)
            bloc:ClearAllPoints()
            bloc:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            bloc:SetSize(largeur, hauteur)
            y = y + hauteur + ECART_BLOCS
        end
        self.hauteur = math.max(1, y - ECART_BLOCS)
        if self.onHauteur then self.onHauteur(self.hauteur) end
    end

    function page:Actualiser(entity)
        -- Les lignes se re-disposent elles-memes quand elles changent de
        -- hauteur ; pendant une actualisation complete, une seule fois a la fin.
        self.enDisposition = true
        for _, ligne in ipairs(self.lignes) do
            if ligne.Actualiser then ligne:Actualiser(entity) end
        end
        self.enDisposition = false
        self:Disposer()
    end

    page:Disposer()
    page:Hide()
    return page
end

-- ===== La fenetre ==========================================================
-- Artwork fixe : il reste visible lorsque les statistiques defilent.
function Fiche.Artwork(parent, largeur)
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(largeur)
    p.fond = UI.Aplat(p, UI.C.fond)
    p.fond:SetAllPoints(p)
    -- L'habillage complet, comme une fenetre : pose a l'exterieur du bord
    -- gauche, le volet n'avait qu'un filet et flottait a cote du cadre dore
    -- sans lui appartenir (4 octobre 2026).
    if UI.Cadre then p.cadre = UI.Cadre(p) else UI.Bordure(p) end
    p.art = p:CreateTexture(nil, "ARTWORK")
    -- L'image se range DANS le cadre : au ras du bord elle passait dessous.
    local e = UI.AelEmprise and UI.AelEmprise(p) or { bas = 0, cote = 0 }
    p.art:SetPoint("TOPLEFT", p, "TOPLEFT", math.max(2, e.cote), -math.max(2, e.cote))
    p.art:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -math.max(2, e.cote), math.max(2, e.bas))
    -- L'habillage se remesure quand il change de taille ou de theme.
    function p:AjusterArt()
        local em = UI.AelEmprise and UI.AelEmprise(self) or { bas = 0, cote = 0 }
        local cote = math.max(2, em.cote)
        self.art:ClearAllPoints()
        self.art:SetPoint("TOPLEFT", self, "TOPLEFT", cote, -cote)
        self.art:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -cote, math.max(2, em.bas))
    end
    p:SetScript("OnSizeChanged", function(self) self:AjusterArt() end)

    local pied = CreateFrame("Frame", nil, p)
    pied:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 3, 3)
    pied:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -3, 3)
    pied:SetHeight(108)
    -- Voile progressif, pour garder l'image sous le cartouche sans perdre le texte.
    for i = 1, 12 do
        local voile = UI.Aplat(pied, { 0.025, 0.015, 0.022, i / 13 }, "BACKGROUND")
        voile:SetPoint("TOPLEFT", pied, "TOPLEFT", 0, -(i - 1) * 9)
        voile:SetPoint("TOPRIGHT", pied, "TOPRIGHT", 0, -(i - 1) * 9)
        voile:SetHeight(9)
    end
    p.niveau = UI.Texte(pied, "", UI.C.titre)
    UI.Police(p.niveau, 22)
    p.niveau:SetPoint("TOP", pied, "TOP", 0, -27)
    p.niveau:SetShadowColor(0, 0, 0, 1)
    p.niveau:SetShadowOffset(1, -2)
    if UI.AelRef then
        -- Fondu ADDITIF : ces ornements sont decoupes dans la planche avec un
        -- fond NOIR. Invisible sur un panneau sombre, il se voyait comme une
        -- boite noire par-dessus l'artwork. En additif, le noir ne pose rien et
        -- l'or reste l'or (4 octobre 2026).
        for _, cote in ipairs({ "LEFT", "RIGHT" }) do
            local t = UI.AelRef(pied, cote == "LEFT" and 329 or 635, 119, 63, 19, "ARTWORK")
            t:SetSize(42, 13)
            t:SetPoint(cote, pied, cote, cote == "LEFT" and 20 or -20, 14)
            if t.SetBlendMode then t:SetBlendMode("ADD") end
        end
        local gemme = UI.AelRef(pied, 501, 656, 27, 25, "OVERLAY")
        gemme:SetSize(15, 14)
        gemme:SetPoint("TOP", pied, "TOP", 0, -9)
        if gemme.SetBlendMode then gemme:SetBlendMode("ADD") end
    end
    p.jauge = CreateFrame("Frame", nil, pied)
    p.jauge:SetPoint("BOTTOMLEFT", pied, "BOTTOMLEFT", 22, 27)
    p.jauge:SetPoint("BOTTOMRIGHT", pied, "BOTTOMRIGHT", -22, 27)
    p.jauge:SetHeight(22)
    p.remplissage = p.jauge:CreateTexture(nil, "ARTWORK")
    p.remplissage:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    p.remplissage:SetVertexColor(0.58, 0.12, 0.22)
    p.remplissage:SetPoint("TOPLEFT", p.jauge, "TOPLEFT", 0, 0)
    p.remplissage:SetHeight(22)
    local fond = UI.Aplat(p.jauge, { 0.065, 0.025, 0.035, 1 }, "BACKGROUND")
    fond:SetAllPoints(p.jauge)
    local cadre = UI.AelCadreJauge and UI.AelCadreJauge(p.jauge) or p.jauge
    p.xp = UI.Texte(cadre, "", UI.C.titre)
    p.xp:SetAllPoints(p.jauge)
    p.xp:SetJustifyH("CENTER")
    UI.Police(p.xp, 12)
    p.legende = UI.Texte(pied, "EXPÉRIENCE", UI.C.discret)
    p.legende:SetPoint("BOTTOM", pied, "BOTTOM", 0, 9)
    UI.Police(p.legende, 9)

    -- A zero PV, un voile rouge sur le portrait (4 octobre 2026) : rouge
    -- tres sombre et opaque sur les bords, qui s'eclaircit et s'efface vers
    -- le centre, ou ne reste qu'un rouge clair translucide. Le portrait reste
    -- reconnaissable. Les degrades sont ceux du jeu (SetGradient), un par
    -- bord : les seize bandes d'avant doublaient l'opacite dans les coins.
    p.inconscient = CreateFrame("Frame", nil, p)
    local etat = p.inconscient
    -- Cale exactement sur le portrait : en retrait de 3 quand le portrait l'est
    -- de 2, il laissait un liseré clair d'un pixel tout autour.
    etat:SetAllPoints(p.art)
    etat:SetFrameLevel(p:GetFrameLevel() + 4)
    etat:EnableMouse(false)
    -- Une seule texture (ressources/fiche/voile-inconscient.tga, 256 x 512) :
    -- SetGradient rendait du noir opaque en jeu, sans transparence.
    etat.voile = etat:CreateTexture(nil, "ARTWORK")
    etat.voile:SetTexture("Interface\\AddOns\\LesContesMalveillants\\ressources\\fiche\\voile-inconscient.tga")
    etat.voile:SetAllPoints(etat)

    local cartouche = CreateFrame("Frame", nil, etat)
    cartouche:SetSize(276, 64)
    cartouche:SetPoint("CENTER", etat, "CENTER", 0, 0)
    local ombre = UI.Aplat(cartouche, { 0.09, 0.008, 0.014, 0.8 }, "BACKGROUND")
    ombre:SetAllPoints(cartouche)
    local filetHaut = UI.Aplat(cartouche, { 0.69, 0.12, 0.16, 0.8 }, "ARTWORK")
    filetHaut:SetHeight(1)
    filetHaut:SetPoint("TOPLEFT", cartouche, "TOPLEFT", 12, -7)
    filetHaut:SetPoint("TOPRIGHT", cartouche, "TOPRIGHT", -12, -7)
    local filetBas = UI.Aplat(cartouche, { 0.36, 0.035, 0.055, 0.85 }, "ARTWORK")
    filetBas:SetHeight(1)
    filetBas:SetPoint("BOTTOMLEFT", cartouche, "BOTTOMLEFT", 12, 7)
    filetBas:SetPoint("BOTTOMRIGHT", cartouche, "BOTTOMRIGHT", -12, 7)
    etat.texte = UI.Texte(cartouche, "INCONSCIENT", { 0.94, 0.13, 0.17 })
    UI.Police(etat.texte, 25, "OUTLINE")
    etat.texte:SetPoint("CENTER", cartouche, "CENTER", 0, 0)
    etat.texte:SetWidth(270)
    etat.texte:SetHeight(32)
    etat.texte:SetJustifyH("CENTER")
    etat.texte:SetShadowColor(0.13, 0, 0, 1)
    etat.texte:SetShadowOffset(2, -2)
    -- Les gouttes de sang sous le titre sont retirees le 4 octobre 2026 : elles
    -- seront redessinees.
    etat:Hide()
    -- Le niveau et l'experience passent DEVANT le voile : on doit les lire
    -- meme inconscient.
    pied:SetFrameLevel(etat:GetFrameLevel() + 2)

    function p:Actualiser(entity)
        LCM.Portraits.Appliquer(self.art, entity)
        -- Rogner le portrait pour remplir le panneau sans deformer l'artwork.
        local portrait = LCM.Portraits.Of(entity) or LCM.Portraits.silhouette
        if portrait then
            local c = portrait.coords or LCM.Portraits.COORDS
            local ratio = math.max(1, self:GetWidth() - 4) / math.max(1, self:GetHeight() - 4)
            local x, y = math.min(1, ratio / LCM.Portraits.RATIO), math.min(1, LCM.Portraits.RATIO / ratio)
            local dx, dy = (c[2] - c[1]) * (1 - x) / 2, (c[4] - c[3]) * (1 - y) / 2
            self.art:SetTexCoord(c[1] + dx, c[2] - dx, c[3] + dy, c[4] - dy)
        end
        local progression = LCM.Experience.Progression(entity)
        local debut = 0
        for _, palier in ipairs(LCM.Equilibrage.experience.paliers) do
            if palier.xp <= progression.xp then debut = palier.xp end
        end
        local maximum = progression.prochainXp and (progression.prochainXp - debut)
        local acquis = progression.xp - debut
        self.niveau:SetText("Niveau " .. Nombre(LCM.Entities.Get_Value(entity, "niveau") or progression.niveau))
        local proportion = maximum and math.max(0, math.min(1, acquis / maximum)) or 1
        self.remplissage:SetWidth(math.max(0.01, (largeur - 50) * proportion))
        self.remplissage:SetShown(proportion > 0)
        self.xp:SetText(maximum and (Nombre(acquis) .. " / " .. Nombre(maximum)) or "Palier maximal")
        local pvCourants, pvMaximum = LCM.Body.Totals(entity)
        self.inconscient:SetShown(pvMaximum > 0 and pvCourants <= 0)
        UI.Bulle(self.jauge, "Expérience", Nombre(progression.xp) .. " XP au total."
            .. (progression.reste and ("\n" .. Nombre(progression.reste) .. " XP avant le niveau " .. progression.prochainNiveau .. ".") or ""))
    end
    p:SetScript("OnSizeChanged", function(self) if self.entity then self:Actualiser(self.entity) end end)
    p:Hide()
    return p
end

-- Volet d'identite, symetrique a l'artwork. Il rassemble ce que la fiche LCM
-- connait (nom, age, poids) et ce que TRP3 expose deja (description et cinq
-- coups d'oeil), sans recopier ces informations dans nos sauvegardes.
function Fiche.Identite(parent, largeur)
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(largeur)
    p.fond = UI.Aplat(p, UI.C.fond)
    p.fond:SetAllPoints(p)
    if UI.Cadre then p.cadre = UI.Cadre(p) else UI.Bordure(p) end

    p.titre = UI.Texte(p, "", UI.C.titre)
    UI.Police(p.titre, 16)
    p.titre:SetPoint("TOP", p, "TOP", 0, -18)
    p.titre:SetWidth(largeur - 32)

    p.zone = UI.Defilement(p)
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -48)
    p.zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 18)
    p.coupsOeil = {}

    -- Age et poids forment une seule ligne compacte. La description suit sans
    -- etiquette : dans ce volet etroit, les valeurs sont plus importantes que
    -- les grands intertitres qui mangeaient la hauteur utile.
    p.infos = UI.Texte(p.zone.contenu, "", UI.C.discret)
    UI.Police(p.infos, 11)
    p.infos:SetJustifyH("LEFT")
    p.description = UI.Texte(p.zone.contenu, "", UI.C.texte)
    UI.Police(p.description, 11)
    p.description:SetJustifyH("LEFT")
    p.description:SetWordWrap(true)

    for index = 1, 5 do
        local carte = CreateFrame("Frame", nil, p.zone.contenu)
        if UI.AelCadre then UI.AelCadre(carte, "section") else UI.Bordure(carte) end
        carte.nom = UI.Texte(carte, "", UI.C.titre)
        UI.Police(carte.nom, 12)
        carte.nom:SetPoint("TOPLEFT", carte, "TOPLEFT", 8, -8)
        carte.nom:SetPoint("TOPRIGHT", carte, "TOPRIGHT", -8, -8)
        carte.nom:SetJustifyH("LEFT")
        carte.description = UI.Texte(carte, "", UI.C.texte)
        UI.Police(carte.description, 11)
        carte.description:SetPoint("TOPLEFT", carte.nom, "BOTTOMLEFT", 0, -4)
        carte.description:SetPoint("TOPRIGHT", carte, "TOPRIGHT", -8, -38)
        carte.description:SetJustifyH("LEFT")
        carte.description:SetWordWrap(true)
        p.coupsOeil[index] = carte
    end

    function p:Disposer()
        local largeurUtile = math.max(80, self:GetWidth() - 38)
        local y = 0
        self.infos:SetWidth(largeurUtile)
        self.infos:ClearAllPoints()
        self.infos:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
        y = y + math.max(14, self.infos:GetStringHeight() or 14) + 12
        self.description:SetWidth(largeurUtile)
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
        if self.description:IsShown() then
            y = y + math.max(14, self.description:GetStringHeight() or 14) + 16
        end
        for _, carte in ipairs(self.coupsOeil) do
            carte:SetWidth(largeurUtile)
            carte.nom:SetWidth(largeurUtile - 16)
            carte.description:SetWidth(largeurUtile - 16)
            local h = 18 + math.max(14, carte.nom:GetStringHeight() or 14)
                + math.max(14, carte.description:GetStringHeight() or 14)
            carte:SetHeight(h)
            carte:ClearAllPoints()
            carte:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            y = y + h + 8
        end
        self.zone:Regler(y)
    end

    function p:Actualiser(entity)
        self.entity = entity
        local estSoi = entity ~= nil and LCM.Entities.Self() == entity
        local profilTRP = estSoi and LCM.Identite.ProfilTRP() or nil
        local instantaneTRP = estSoi and LCM.Identite.InstantaneTRP()
            or (entity and entity.trp)
        local function Valeur(id, repli)
            local valeur = entity and LCM.Entities.Get_Value(entity, id)
            if valeur == nil or tostring(valeur) == "" then valeur = repli end
            if valeur == nil or tostring(valeur) == "" then return "—" end
            return tostring(valeur)
        end
        self.titre:SetText(Valeur("nom", entity and entity.name))
        local age = Valeur("age", instantaneTRP and instantaneTRP.age
            or (profilTRP and profilTRP.AG))
        local poids = Valeur("poids", instantaneTRP and instantaneTRP.poids
            or (profilTRP and profilTRP.WE))
        self.infos:SetText("Âge : " .. age .. "     Poids : " .. poids)
        local description = entity and LCM.Entities.Get_Value(entity, "description")
        if description == nil or tostring(description) == "" then
            description = instantaneTRP and instantaneTRP.description
        end
        description = tostring(description or "")
        self.description:SetText(description)
        self.description:SetShown(description ~= "")

        local coups = instantaneTRP and instantaneTRP.coups or {}
        for index, carte in ipairs(self.coupsOeil) do
            local coup = coups[index]
            local active = coup and (coup.actif == true or tostring(coup.actif) == "1")
            local actif = active and (tostring(coup.nom or "") ~= ""
                or tostring(coup.description or "") ~= "")
            carte.nom:SetText(actif and (coup.nom ~= "" and coup.nom or "Sans nom") or "Non renseigné")
            carte.description:SetText(actif and (coup.description ~= "" and coup.description or "—") or "")
            local couleur = actif and UI.C.titre or UI.C.discret
            carte.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
        end
        self:Disposer()
    end

    p:Hide()
    return p
end

-- La Fiche est une vue comme les autres (Data/Vues.lua, id « fiche ») : ses
-- onglets sont ceux du template (Statistiques, Facultes, Traits).

function Fiche.Fenetre()
    local f = UI.Vues.Fenetre("fiche")
    Fiche.frame = f
    return f
end

LCM.AddCommand("fiche", "ouvre la fiche", function(argument)
    local f = Fiche.Fenetre()
    if f:IsShown() then
        f:Hide()
        return
    end
    local entite = LCM.Entities.Self()
    local cible = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cible ~= "" then
        entite = LCM.Entities.Get(cible) or entite
    end
    f:Montrer(entite)
end)
