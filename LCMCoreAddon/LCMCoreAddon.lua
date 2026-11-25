--[[
  LCM - Core Add-On — le seul morceau de LCM qui vit dans le jeu.

  1) Il ENVOIE à l'overlay, par une bande de carrés colorés en haut à gauche :
     position (C_Epsilon.GetPosition, sinon UnitPosition), carte, orientation,
     nom du personnage, nom de la cible, groupe/raid/combat, et l'accusé de
     réception de la dernière commande exécutée.
  2) Il EXÉCUTE ce que l'overlay tape dans le chat :
        /lcmx <id> <canal> <texte>
     canal : auto (raid > groupe > dire), dire, groupe, raid, emote, cmd, chuchoter (« Nom texte »)

  Protocole de la bande (identique à electron/pont.cjs) :
    carrés 1..4 : magenta, cyan, jaune, gris 136 (repères + calibration)
    carrés 5..100 : 144 octets, 3 nibbles par carré (R, G, B), valeur = nibble*17
    octets : 1 version(2) 2 seq 3 flags 4 ack 5-8 x 9-12 y 13-16 z
             17-18 orientation 19-20 carte, puis [len][nom] [len][cible],
             carteUi (2), appelCarte (1), codes (1), joueurSurvole (1),
             [len][nom du joueur sous le curseur],
             zéros, 143-144 somme Fletcher-16 des octets 1..142

  Trame TRP3 (octet 1 = 3, depuis le 5 novembre 2026) : l'icône du profil
  TRP3 et ses cinq coups d'oeil, rien d'autre (demande de l'utilisateur).
  Même bande, même taille : une trame sur deux le temps d'un passage complet
  après un changement, puis un morceau par seconde pour qu'un overlay lancé
  après coup finisse par tout recevoir. Chaque morceau reste 100 ms à l'écran
  (le lecteur relève la bande toutes les 33 ms).
    octets : 1 genre(3) 2 seq 3 flags 4 ack 5-8 empreinte (djb2 du profil)
             9 index du morceau 10 nombre de morceaux 11 longueur utile,
             12-142 le morceau (131 octets), 143-144 Fletcher-16
  Le profil : champs séparés par \30, ceux d'un coup d'oeil par \31 :
    "1" \30 personnage \30 icône \30 [actif \31 icône \31 titre \31 texte] x5
  Un overlay plus ancien rejette ces trames (genre ≠ 2) et garde la position.
]]

local MARQ, DATA = 4, 96
local TOTAL = MARQ + DATA
local NOCTETS = DATA * 3 / 2      -- 144
local floor = math.floor
local PI2 = 2 * math.pi

local db
local seq, ack = 0, 0
local gobEnAttente, gobCapture
-- Le portrait de WoW (gestes du HUD, plus bas) : declare ici, la trame le lit.
local portraitVoulu      -- true : cache, false : montre, nil : on n'y touche pas
-- L'overlay est parti (geste « liberer », envoye a sa fermeture) : WoW
-- reprend tout, et le clic droit sur le portrait ne recache plus rien.
local overlayParti = false
-- Le compte des appuis sur la touche de la carte (« carte on »), lu par la trame.
local appelCarte, carteLiee = 0, false
-- Les raccourcis clavier de l'addon (UI/Raccourcis.lua), plus bas.
local appelInventaire, appelPersonnage, touchesLiees = 0, 0, false
local SaisiePrete, JoueurEcrit, SaisieOuverte = function() return false end, function() return false end, function() return false end
local CodesPrets = function() return false end

-- Les messages techniques du capteur vont dans l'onglet de l'addon
-- (« LesContesMalveillants »), JAMAIS dans le General (le MJ, 16 novembre
-- 2026 : « mauvais canal »). C'etait l'ancien addon (Core/Log.lua) qui creait
-- cet onglet ; il est desactive quand on joue sur l'overlay, et l'onglet
-- n'existait donc plus. Le capteur le cree lui-meme, comme Log.lua : apres la
-- connexion, hors combat, vide de tout canal, sans y basculer. En attendant,
-- les messages patientent ; s'il ne peut pas etre cree (plus de place pour un
-- onglet), ils sont jetes plutot que d'aller au General.
local NOM_ONGLET = "LesContesMalveillants"
local ongletPret, ongletAttente = false, {}
local function OngletLCM()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    if frame and GetChatWindowInfo and GetChatWindowInfo(i) == NOM_ONGLET then return frame end
  end
  if not ongletPret or (InCombatLockdown and InCombatLockdown()) or not FCF_OpenNewWindow then return nil end
  local selection = SELECTED_CHAT_FRAME
  local frame = FCF_OpenNewWindow(NOM_ONGLET)
  if not frame then return nil end
  if ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(frame) end
  if ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
  if selection and FCF_SelectDockFrame then FCF_SelectDockFrame(selection) end
  return frame
end
local function ViderOnglet()
  if #ongletAttente == 0 then return end
  local frame = OngletLCM()
  if not frame then return end
  for _, ligne in ipairs(ongletAttente) do frame:AddMessage(ligne) end
  ongletAttente = {}
end
local function Msg(t)
  -- Au plus 50 messages en attente : un onglet impossible a creer ne doit pas
  -- remplir la memoire.
  if #ongletAttente >= 50 then table.remove(ongletAttente, 1) end
  ongletAttente[#ongletAttente + 1] = "|cffd2a04aLCM - Core Add-On|r : " .. t
  ViderOnglet()
end
local ongletEvenements = CreateFrame("Frame")
ongletEvenements:RegisterEvent("PLAYER_LOGIN")
ongletEvenements:RegisterEvent("PLAYER_REGEN_ENABLED")
ongletEvenements:SetScript("OnEvent", function(_, evenement)
  if evenement == "PLAYER_LOGIN" then ongletPret = true end
  ViderOnglet()
end)

-- ===== La bande ===========================================================
local pont = CreateFrame("Frame", "LCMCapteurPont")   -- sans parent : survit à Alt+Z
pont:SetFrameStrata("TOOLTIP")
pont:SetFrameLevel(9000)
pont:EnableMouse(false)
pont:Hide()

local carres = {}
for i = 1, TOTAL do carres[i] = pont:CreateTexture(nil, "OVERLAY") end

local function HauteurPhysique()
  if GetPhysicalScreenSize then
    local ok, _, h = pcall(GetPhysicalScreenSize)
    if ok and h and h > 0 then return h end
  end
  return 768
end

local function LargeurPhysique()
  if GetPhysicalScreenSize then
    local ok, w = pcall(GetPhysicalScreenSize)
    if ok and w and w > 0 then return w end
  end
  return nil
end

-- En haut a DROITE (le MJ, 6 novembre 2026 : au-dessus de la minicarte, elle
-- ne se voit presque pas). Le bord gauche tombe sur un pixel entier : une
-- bande a cheval sur deux pixels melange ses couleurs, illisibles.
local function Disposer()
  local unite = 768 / HauteurPhysique()        -- 1 pixel physique, en unites du pont
  local s = db.taille * unite
  pont:SetScale(1)
  pont:ClearAllPoints()
  local largeur = LargeurPhysique()
  if largeur then
    pont:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (largeur - TOTAL * db.taille) * unite, 0)
  else
    pont:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  end
  pont:SetSize(s * TOTAL, s)
  for i, t in ipairs(carres) do
    t:ClearAllPoints()
    t:SetSize(s, s)
    t:SetPoint("TOPLEFT", pont, "TOPLEFT", (i - 1) * s, 0)
  end
  carres[1]:SetColorTexture(1, 0, 1)
  carres[2]:SetColorTexture(0, 1, 1)
  carres[3]:SetColorTexture(1, 1, 0)
  carres[4]:SetColorTexture(8 / 15, 8 / 15, 8 / 15)
end

-- ===== Lecture du jeu =====================================================
local function Position()
  if type(C_Epsilon) == "table" and type(C_Epsilon.GetPosition) == "function" then
    local ok, x, y, z, carte = pcall(C_Epsilon.GetPosition)
    if ok and type(x) == "number" and type(y) == "number" then
      return x, y, tonumber(z) or 0, tonumber(carte) or 0, true
    end
  end
  local ok, x, y, z, inst = pcall(UnitPosition, "player")
  if ok and type(x) == "number" then return x, y, tonumber(z) or 0, tonumber(inst) or 0, false end
  return nil
end

-- coupe une chaîne UTF-8 à n octets sans casser un caractère
local function Couper(s, n)
  s = s or ""
  if #s <= n then return s end
  local fin = n
  while fin > 0 do
    local b = s:byte(fin + 1)
    if not b or b < 0x80 or b >= 0xC0 then break end
    fin = fin - 1
  end
  return s:sub(1, fin)
end

-- ===== Encodage ===========================================================
local oct = {}
local n = 0
local function u8(v) n = n + 1; oct[n] = v % 256 end
local function u16(v) v = floor(v); u8(floor(v / 256)); u8(v) end
local function u32(v) v = floor(v); u8(floor(v / 16777216)); u8(floor(v / 65536)); u8(floor(v / 256)); u8(v) end
local function borne(v, max) v = floor(v + 0.5); if v < 0 then return 0 elseif v > max then return max end return v end
local function chaine(s, limite)
  s = Couper(s, limite or 40)
  u8(#s)
  for i = 1, #s do u8(s:byte(i)) end
end

-- ===== TRP3 : l'icône du profil et les coups d'oeil ========================
-- Lu comme le fait l'addon (Core/Identite.lua) : jamais écrit, toujours sous
-- pcall, l'API de TRP3 peut manquer ou changer.
local RS, US = string.char(30), string.char(31)
local TRP_UTILE = 131

local function DonneeTRP(chemin)
  local api = TRP3_API
  if not (type(api) == "table" and type(api.profile) == "table"
      and type(api.profile.getData) == "function") then return nil end
  local ok, valeur = pcall(api.profile.getData, chemin)
  return ok and valeur or nil
end

-- Le texte sans les balises de TRP3 (Identite.lua, TexteTRP), ni les deux
-- séparateurs du profil, coupé à `max` octets.
local function TexteTRP(valeur, max)
  local texte = tostring(valeur or "")
  texte = texte:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    :gsub("{[^}]-}", ""):gsub("[\30\31\r]", "")
  texte = texte:gsub("^%s+", ""):gsub("%s+$", "")
  return Couper(texte, max)
end

-- Les descriptions longues restent lisibles dans l'overlay. Le profil reste
-- sous la limite de 255 morceaux du protocole (131 octets par morceau).
local function ProfilTRP()
  local joueur = DonneeTRP("player")
  local c = type(joueur) == "table" and joueur.characteristics
  if type(c) ~= "table" then return nil end
  local pe = DonneeTRP("player/misc/PE")
  local champs = { "1", TexteTRP(UnitName("player"), 40), TexteTRP(c.IC, 80) }
  for index = 1, 5 do
    local brut = type(pe) == "table" and (pe[tostring(index)] or pe[index]) or nil
    if type(brut) ~= "table" then brut = {} end
    champs[#champs + 1] = table.concat({ brut.AC == true and "1" or "0", TexteTRP(brut.IC, 80),
      TexteTRP(brut.TI, 80), TexteTRP(brut.TX, 1600) }, US)
  end
  return table.concat(champs, RS)
end

-- djb2 sur 32 bits, en flottants (h * 33 < 2^53) : le lecteur fait le même.
local function Empreinte(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return h
end

local trp = { donnees = nil, empreinte = 0, total = 0, suivant = 0, passes = 0,
  lu = -10, affiche = nil, fin = 0, prochain = 0 }

-- Le profil est relu toutes les 2 s, pas à chaque image.
local function ReleverTRP(t)
  if t - trp.lu < 2 then return end
  trp.lu = t
  local d = ProfilTRP()
  if d == trp.donnees then return end
  -- Le morceau a l'ecran appartenait a l'ancien profil.
  trp.donnees, trp.affiche = d, nil
  if not d then return end
  trp.empreinte = Empreinte(d)
  trp.total = math.max(1, math.ceil(#d / TRP_UTILE))
  trp.suivant, trp.passes = 0, 0
end

-- Le morceau a montrer maintenant, ou nil (trame de position).
local function MorceauTRP(t)
  ReleverTRP(t)
  if trp.affiche and t >= trp.fin then
    trp.affiche = nil
    trp.prochain = t + (trp.passes < 3 and 0.1 or 1)
  end
  if not trp.affiche and trp.donnees and t >= trp.prochain then
    trp.affiche, trp.fin = trp.suivant, t + 0.1
    trp.suivant = trp.suivant + 1
    if trp.suivant >= trp.total then trp.suivant, trp.passes = 0, trp.passes + 1 end
  end
  return trp.affiche
end

-- ===== Les auras de la cible (UI/Auras.lua) ================================
-- Le portrait compact de l'overlay remplace TargetFrame, et avec lui les
-- icones d'auras du jeu : la trame de genre 5 les transmet, une page de
-- quatre a la fois, sur une image sur quatre tant qu'il y a une cible.
--   octets : 1 genre(5) 2 seq 3 flags(0) 4 ack 5 version de la liste 6 page
--            7 nombre de pages 8 auras dans la page, puis par aura : 4 icone
--            (numero de fichier), 1 piles, 2 secondes restantes (65535 : sans
--            fin), 1 sorte (bit 1 nefaste, bits 2-4 : 1 magie, 2 malediction,
--            3 maladie, 4 poison), [len][nom] (20 octets au plus).
local AURAS_PAGE = 4
local auras = { liste = {}, signature = "", version = 0, lu = -10, page = 0 }
local SORTES = { Magic = 1, Curse = 2, Disease = 3, Poison = 4 }

-- Le client d'Epsilon parle l'API d'avant Dragonflight (UnitAura) ; un
-- client recent ne connait plus que C_UnitAuras (UI/Auras.lua, Lire).
local function LireAura(unite, index, filtre)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unite, index, filtre)
    if not (ok and a) then return nil end
    return { nom = a.name, icone = a.icon, piles = a.applications or 0, type = a.dispelName,
      duree = a.duration or 0, expiration = a.expirationTime or 0 }
  end
  if not UnitAura then return nil end
  local ok, nom, icone, piles, type_, duree, expiration = pcall(UnitAura, unite, index, filtre)
  if not (ok and nom) then return nil end
  return { nom = nom, icone = icone, piles = piles or 0, type = type_, duree = duree or 0, expiration = expiration or 0 }
end

-- Relue deux fois par seconde : la version change avec la liste.
local function ReleverAuras(t)
  if t - auras.lu < 0.5 then return end
  auras.lu = t
  local liste, morceaux = {}, {}
  if UnitExists("target") then
    for _, filtre in ipairs({ "HELPFUL", "HARMFUL" }) do
      for index = 1, 40 do
        local a = LireAura("target", index, filtre)
        if not a then break end
        a.nefaste = filtre == "HARMFUL"
        liste[#liste + 1] = a
        morceaux[#morceaux + 1] = table.concat({ tostring(a.icone), tostring(a.piles), tostring(a.expiration),
          tostring(a.nom), a.nefaste and "1" or "0" }, ":")
      end
    end
    morceaux[#morceaux + 1] = UnitGUID and tostring(UnitGUID("target")) or ""
  end
  local signature = table.concat(morceaux, ";")
  if signature ~= auras.signature then
    auras.signature, auras.liste = signature, liste
    auras.version = (auras.version + 1) % 256
    auras.page = 0
  end
end

local function Peindre()
  while n < NOCTETS - 2 do u8(0) end
  local a, b = 0, 0
  for i = 1, NOCTETS - 2 do a = (a + oct[i]) % 255; b = (b + a) % 255 end
  u8(b); u8(a)

  -- 144 octets -> 288 nibbles -> 96 carrés. Sans table par carré (23 novembre
  -- 2026) : 96 tables neuves a CHAQUE image chargeaient le ramasse-miettes.
  for i = 1, DATA do
    local k = (i - 1) * 3            -- index du premier nibble (0-based)
    local o1, o2, o3 = oct[floor(k / 2) + 1], oct[floor((k + 1) / 2) + 1], oct[floor((k + 2) / 2) + 1]
    local r = (k % 2 == 0) and floor(o1 / 16) or (o1 % 16)
    local v = ((k + 1) % 2 == 0) and floor(o2 / 16) or (o2 % 16)
    local b = ((k + 2) % 2 == 0) and floor(o3 / 16) or (o3 % 16)
    carres[MARQ + i]:SetColorTexture(r / 15, v / 15, b / 15)
  end
end

local function Encoder()
  seq = (seq + 1) % 256
  -- Le GUID capture repart une image sur quatre pendant 12 s, le temps que
  -- l'overlay le lise. Il n'etait efface qu'a l'image SUIVANTE (13 novembre
  -- 2026) : une seule trame partait, que le lecteur ratait presque toujours.
  if gobCapture and GetTime() - gobCapture.depuis >= 12 then gobCapture = nil end
  if gobCapture and seq % 4 == 0 then
    n = 0
    u8(4); u8(seq); u8(0); u8(ack)
    chaine(gobCapture.point)
    -- Le lecteur (lcm_pont.h) REJETTE une chaine vide : les accuses et
    -- demandes sans GUID (mogok, mogplus, mogdemande) etaient tous jetes.
    chaine(gobCapture.guid ~= "" and gobCapture.guid or "-")
    Peindre()
    return
  end
  if UnitExists("target") and seq % 4 == 2 then
    local t = GetTime()
    ReleverAuras(t)
    local liste = auras.liste
    local pages = math.max(1, math.ceil(#liste / AURAS_PAGE))
    local page = auras.page % pages
    auras.page = page + 1
    n = 0
    u8(5); u8(seq); u8(0); u8(ack)
    u8(auras.version); u8(page); u8(pages)
    local debut = page * AURAS_PAGE
    local nombre = math.max(0, math.min(AURAS_PAGE, #liste - debut))
    u8(nombre)
    for k = 1, nombre do
      local a = liste[debut + k]
      u32(type(a.icone) == "number" and borne(a.icone, 4294967295) or 0)
      u8(math.min(255, math.max(0, floor(tonumber(a.piles) or 0))))
      local reste = 65535
      if (tonumber(a.duree) or 0) > 0 and (tonumber(a.expiration) or 0) > 0 then
        reste = borne(a.expiration - t, 65534)
      end
      u16(reste)
      u8((a.nefaste and 1 or 0) + 2 * (SORTES[a.type or ""] or 0))
      chaine(a.nom, 20)
    end
    Peindre()
    return
  end
  local morceau = MorceauTRP(GetTime())
  local x, y, z, carte, epsilon = Position()
  local flags = 0
  if x then flags = flags + 1 else x, y, z, carte = 0, 0, 0, 0 end
  if epsilon then flags = flags + 2 end
  if IsInGroup and IsInGroup() then flags = flags + 4 end
  if IsInRaid and IsInRaid() then flags = flags + 8 end
  if UnitAffectingCombat and UnitAffectingCombat("player") then flags = flags + 16 end
  local cible = UnitExists("target") and UnitName("target") or ""
  if cible ~= "" then flags = flags + 32 end
  if cible ~= "" and UnitIsPlayer("target") then flags = flags + 64 end
  -- 128 : le portrait de WoW est tenu cache (HUD de l'overlay). L'overlay y lit
  -- si sa consigne est appliquee, et un clic droit sur le portrait (retour au
  -- HUD, comme UI/HUD.lua) lui parvient par la.
  if portraitVoulu then flags = flags + 128 end

  n = 0
  if morceau then
    local debut = morceau * TRP_UTILE + 1
    local part = trp.donnees:sub(debut, debut + TRP_UTILE - 1)
    u8(3); u8(seq); u8(flags); u8(ack)
    u32(trp.empreinte)
    u8(morceau); u8(trp.total); u8(#part)
    for i = 1, #part do u8(part:byte(i)) end
    Peindre()
    return
  end
  u8(2); u8(seq); u8(flags); u8(ack)
  u32(borne(x * 100 + 2 ^ 31, 4294967295))
  u32(borne(y * 100 + 2 ^ 31, 4294967295))
  u32(borne(z * 100 + 2 ^ 31, 4294967295))
  u16(borne((GetPlayerFacing() or 0) / PI2 * 65535, 65535))
  u16(borne(carte, 65535))
  chaine(UnitName("player"))
  chaine(cible)
  -- La carte d'INTERFACE (C_Map), apres les noms, dans la place libre : des
  -- points poses ne gardent qu'elle (interactions_rpc.sql, points_proches).
  -- Un lecteur plus ancien s'arrete aux noms et ne la voit pas.
  local ok, carteUi = pcall(C_Map and C_Map.GetBestMapForUnit or function() return nil end, "player")
  u16(borne(ok and tonumber(carteUi) or 0, 65535))
  -- Le compte des appuis sur la touche de la carte (7 bits, voir « carte on »),
  -- et en bit 128 : la touche est prise. Un /reload l'oublie ; l'overlay le
  -- voit ici et renvoie « carte on », comme pour le portrait.
  -- 4 bits d'appuis ; 16 : NOTRE saisie a le focus (le lecteur peut taper) ;
  -- 32 : saisie silencieuse prete ; 64 : le joueur ecrit ailleurs.
  u8(appelCarte + (SaisieOuverte() and 16 or 0) + (SaisiePrete() and 32 or 0)
    + (JoueurEcrit() and 64 or 0) + (carteLiee and 128 or 0))
  -- Octet suivant (6 novembre 2026, essai) : 1 = touches-codes liees. Un
  -- lecteur plus ancien ne le lit pas.
  u8(CodesPrets() and 1 or 0)
  -- La cible sous le curseur, comme UI/Echange.lua de l'addon historique.
  -- Elle sert au dépôt d'un objet sur le personnage dans le monde.
  local survol = ""
  if UnitExists("mouseover") and UnitIsPlayer("mouseover")
      and not UnitIsUnit("mouseover", "player") then
    survol = UnitName("mouseover") or ""
  end
  u8(survol ~= "" and 1 or 0)
  chaine(survol, math.max(0, math.min(40, 140 - n)))
  -- Les raccourcis clavier (12 novembre 2026) : 2 bits d'appuis sur I, 2 sur
  -- Maj + C, et 128 : les touches sont prises. Un lecteur plus ancien
  -- s'arrete au nom survole.
  u8(appelInventaire + 4 * appelPersonnage + (touchesLiees and 128 or 0))
  Peindre()
end
pont:SetScript("OnUpdate", Encoder)

-- ===== Exécution des commandes de l'overlay ===============================
local function Envoyer(texte, canal, cible)
  -- « | » est un code d'echappement du chat de WoW : un « | » seul (« Jet = 3
  -- | Mod. +4 », ligne des jets depuis le 17 novembre 2026) rend le message
  -- invalide et WoW le jette SANS rien dire. Tous les jets disparaissaient
  -- (le MJ, 19 novembre 2026). « || » s'affiche « | ». Un « || » deja double
  -- (saisie qui l'aurait echappe) n'est pas double deux fois.
  texte = tostring(texte or ""):gsub("||", "|"):gsub("|", "||")
  -- découpe à 255 octets sur les espaces
  local reste = texte
  while #reste > 0 do
    local morceau = reste
    if #morceau > 255 then
      morceau = Couper(reste, 255)
      local coupe = morceau:match("^(.*)%s")
      if coupe and #coupe > 100 then morceau = coupe end
    end
    SendChatMessage(morceau, canal, nil, cible)
    reste = reste:sub(#morceau + 1):gsub("^%s+", "")
  end
end

local function CanalAuto()
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
  return "SAY"
end

local CANAUX = { dire = "SAY", groupe = "PARTY", raid = "RAID", emote = "EMOTE", cmd = "SAY" }

-- ===== Les gestes du HUD de l'overlay (canal « lcm ») ======================
-- Repris de UI/HUD.lua de l'addon : quand l'overlay montre son HUD de PV, le
-- portrait de WoW se cache ; un clic droit sur le HUD ouvre le menu du joueur.
-- PlayerFrame est protege en combat : un changement demande en combat attend
-- la fin du combat (PLAYER_REGEN_ENABLED) au lieu de provoquer une action bloquee.
-- portraitVoulu : declare en tete du fichier (la trame de la bande le lit).
-- Le HUD de l'ADDON LCM (UI/HUD.lua) fait la meme chose que celui de l'overlay :
-- les deux se superposaient (le MJ, 5 novembre 2026). Quand l'overlay montre le
-- sien, celui de l'addon se range, et se re-range s'il se remontre ; il revient
-- quand l'overlay range le sien.
local hudAddonSuivi = false
local function HudAddon()
  local hud = _G.LCM_HUDPersonnage
  if not hud then return end
  if not hudAddonSuivi and hud.HookScript then
    hudAddonSuivi = true
    hud:HookScript("OnShow", function(self) if portraitVoulu then self:Hide() end end)
  end
  -- Pas d'Actualiser de l'addon au retour : il recacherait aussitot le portrait
  -- de WoW, alors que l'overlay vient de demander l'affichage classique.
  if portraitVoulu then hud:Hide() end
end
-- La carte compacte de la cible (UI/HUD.lua, MasquerCibleBlizzard) : quand
-- l'overlay montre la sienne, TargetFrame se cache. Protege en combat : la
-- consigne attend la fin du combat.
--
-- ECART (le MJ, 25 novembre 2026) : « ne retire plus l'unitframe des
-- personnages ; on le cachera juste en mettant notre truc par dessus ». Les
-- cadres de WoW ne se cachent PLUS : la consigne est gardee (l'overlay la lit,
-- flag 128), mais elle ne fait que rendre un cadre qu'on aurait cache avant.
local cibleVoulue = nil
local function AppliquerCible()
  if cibleVoulue == nil or not TargetFrame then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if UnitExists and UnitExists("target") and not TargetFrame:IsShown() then
    TargetFrame:Show()
  end
end

-- Le journal du portrait (le MJ, 15 novembre 2026 : un clic droit sur l'orbe
-- de l'overlay fait revenir le portrait de WoW, sans qu'aucun code connu ne le
-- demande). Chaque ordre recu et chaque apparition du portrait, avec QUI l'a
-- montre (debugstack), dans LCMCapteurDB.portraitJournal (40 lignes).
local function NoterPortrait(texte)
  if not db then return end
  db.portraitJournal = db.portraitJournal or {}
  local j = db.portraitJournal
  j[#j + 1] = date("%H:%M:%S") .. " " .. tostring(texte)
  while #j > 40 do table.remove(j, 1) end
end
local portraitSuivi = false
local function SuivrePortrait()
  if portraitSuivi or not (PlayerFrame and PlayerFrame.HookScript) then return end
  portraitSuivi = true
  PlayerFrame:HookScript("OnShow", function(self)
    local pile = debugstack and debugstack(2, 6, 0) or ""
    NoterPortrait("portrait MONTRE (voulu caché : " .. tostring(portraitVoulu) .. ") "
      .. pile:gsub("Interface[/\\]", ""):gsub("\n", " | "):sub(1, 400))
    -- Plus de garde qui le recache (25 novembre 2026) : le portrait de WoW
    -- reste affiche, l'overlay se pose par-dessus.
  end)
  PlayerFrame:HookScript("OnHide", function() NoterPortrait("portrait caché") end)
end

local function AppliquerPortrait()
  HudAddon()
  SuivrePortrait()
  if portraitVoulu == nil or not PlayerFrame then return end
  if InCombatLockdown and InCombatLockdown() then return end
  -- Jamais cache (25 novembre 2026, voir AppliquerCible) : seulement rendu.
  if not PlayerFrame:IsShown() then PlayerFrame:Show() end
end

-- UI/HUD.lua, InstallerBasculeBlizzard : portrait de WoW affiche (affichage
-- classique), son clic droit ramene le HUD. Le capteur recache le portrait et
-- le dit dans sa trame (flag 128) : l'overlay remontre son HUD en le voyant.
local basculeInstallee = false
local function InstallerBascule()
  if basculeInstallee or not (PlayerFrame and PlayerFrame.HookScript) then return end
  basculeInstallee = true
  -- ECART (le MJ, 14 novembre 2026) : le clic droit sur le portrait de WoW
  -- ne ramene PLUS le HUD. On s'en sert pour le menu du raid ; il basculait
  -- l'affichage « au hasard ». Seul Parametres > Afficher / Masquer le HUD
  -- decide desormais.
end

local function MenuUnite(unite)
  local menu = unite == "cible" and TargetFrameDropDown or PlayerFrameDropDown
  if not (menu and ToggleDropDownMenu) then return end
  if unite == "cible" and not (UnitExists and UnitExists("target")) then return end
  ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

-- Les sorts Arcanum d'un lieu (Core/Crossings.lua, CastArc / RemoveArc) : ARC
-- n'existe qu'ici, en jeu. « arc cast personal|phase <id> », « arc stop <id> ».
local function Arcanum(reste)
  local action, a, b = reste:match("^(%S+)%s+(%S+)%s*(%S*)")
  if type(ARC) ~= "table" then Msg("Arcanum absent : le sort du lieu n'est pas lancé.") return end
  if action == "stop" and type(ARC.STOP) == "function" then pcall(ARC.STOP, ARC, a) return end
  if action ~= "cast" or b == "" then return end
  if type(ARC.XAPI) == "table" and type(ARC.XAPI.GetArcSpell) == "function" then
    local ok, sort = pcall(ARC.XAPI.GetArcSpell, ARC.XAPI, b, a ~= "personal")
    if not (ok and sort) then Msg("sort Arcanum introuvable : " .. b) return end
  end
  if a == "personal" then pcall(ARC.CAST, ARC, b)
  elseif type(ARC.PHASE) == "table" then pcall(ARC.PHASE.CAST, ARC.PHASE, b, true) end
end

-- ===== Le terrain sous les cartes de l'overlay (6 novembre 2026) ==========
-- L'overlay dessine les zones des Lieux ; le JEU seul sait lire ses tuiles de
-- minimap (world\minimaps\<carte>\mapXX_YY.blp, un bloc ADT de 533,33 yards,
-- comme CarteZones.lua de l'addon MJ). L'overlay laisse le fond de sa carte
-- transparent et dit ici OU elle est a l'ecran (fractions de la fenetre), son
-- centre et son echelle (fraction de largeur par yard) : le capteur pose les
-- tuiles DESSOUS, au meme cadrage, et la fleche du joueur. En « suivre », il
-- se recentre seul sur le joueur (le trace), sans attendre l'overlay.
--   terrain on <fx> <fy> <fw> <fh> <cx> <cy> <ech> <suivre 0|1> <dossier|->
--   terrain off
local ADT, MAX_TUILES = 533.33333, 240
local terrain = CreateFrame("Frame", "LCMCapteurTerrain", UIParent)
terrain:SetFrameStrata("FULLSCREEN_DIALOG")
if terrain.SetClipsChildren then terrain:SetClipsChildren(true) end
terrain:Hide()
terrain.fond = terrain:CreateTexture(nil, "BACKGROUND")
terrain.fond:SetAllPoints(); terrain.fond:SetColorTexture(.055, .060, .058, 1)
terrain.tuiles = {}
terrain.fleche = terrain:CreateTexture(nil, "OVERLAY")
terrain.fleche:SetTexture("Interface\\Minimap\\MinimapArrow"); terrain.fleche:SetSize(28, 28)
terrain.mot = terrain:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
terrain.mot:SetPoint("BOTTOM", 0, 6); terrain.mot:SetTextColor(.9, .78, .3)
local etatTerrain

-- La position, dans le repere de Crossings (ZG:GetPlayerPose : x et y du
-- serveur echanges).
local function PoseCrossings()
  local x, y, _, carte = Position()
  if not x then return nil end
  return y, x, (GetPlayerFacing and GetPlayerFacing()) or 0, carte
end

-- Le dossier de tuiles des grands continents, par carte serveur
-- (GetInstanceInfo) : le jeu ne donne pas ce nom. Les cartes d'Epsilon se
-- reglent a la main, par carte, dans le panneau Lieux.
local DOSSIERS = { [0] = "azeroth", [1] = "kalimdor", [530] = "expansion01", [571] = "northrend",
  [870] = "hawaiimainland", [1116] = "draenor", [1220] = "trollraid", [1642] = "zandalar", [1643] = "kultiras" }
local function DossierTerrain()
  if etatTerrain and etatTerrain.dossier and etatTerrain.dossier ~= "-" then return etatTerrain.dossier end
  local instance = GetInstanceInfo and select(8, GetInstanceInfo())
  if instance and DOSSIERS[instance] then return DOSSIERS[instance] end
  local uiMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local info = uiMap and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMap)
  local nom = (info and info.name or ""):gsub("[%s'’%-]", ""):lower()
  return nom ~= "" and nom or nil
end

local function DessinerTerrain()
  local t = etatTerrain
  if not t then terrain:Hide() return end
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local w, h, s = t.fw * W, t.fh * H, t.ech * W
  terrain:ClearAllPoints()
  terrain:SetPoint("TOPLEFT", UIParent, "TOPLEFT", t.fx * W, -t.fy * H)
  terrain:SetSize(math.max(1, w), math.max(1, h))
  local px, py, facing = PoseCrossings()
  if t.suivre and px then t.cx, t.cy = px, py end
  local function Ecran(x, y) return w / 2 + (t.cx - x) * s, h / 2 - (y - t.cy) * s end
  for _, tex in ipairs(terrain.tuiles) do tex:Hide() end
  local dossier, n = DossierTerrain(), 0
  if dossier and s > 0 then
    local ouestMax, ouestMin = t.cx + (w / 2) / s, t.cx - (w / 2) / s
    local nordMax, nordMin = t.cy + (h / 2) / s, t.cy - (h / 2) / s
    local colMin, colMax = math.max(0, floor(32 - ouestMax / ADT)), math.min(63, floor(32 - ouestMin / ADT))
    local ligMin, ligMax = math.max(0, floor(32 - nordMax / ADT)), math.min(63, floor(32 - nordMin / ADT))
    if (colMax - colMin + 1) * (ligMax - ligMin + 1) <= MAX_TUILES then
      local cote = ADT * s
      for lig = ligMin, ligMax do
        for col = colMin, colMax do
          n = n + 1
          local tex = terrain.tuiles[n]
          if not tex then tex = terrain:CreateTexture(nil, "BORDER"); terrain.tuiles[n] = tex end
          tex:SetTexture(string.format("world\\minimaps\\%s\\map%02d_%02d.blp", dossier, col, lig))
          local x, y = Ecran((32 - col) * ADT, (32 - lig) * ADT)
          tex:ClearAllPoints(); tex:SetPoint("TOPLEFT", terrain, "TOPLEFT", x, -y)
          tex:SetSize(cote + 1, cote + 1); tex:Show()
        end
      end
    end
  end
  terrain.mot:SetText(n == 0 and ("Pas de terrain ici" .. (dossier and (" (dossier essayé : " .. dossier .. ")") or "")) or "")
  if px then
    local x, y = Ecran(px, py)
    terrain.fleche:ClearAllPoints(); terrain.fleche:SetPoint("CENTER", terrain, "TOPLEFT", x, -y)
    terrain.fleche:SetRotation(facing); terrain.fleche:Show()
  else terrain.fleche:Hide() end
  terrain:Show()
end
local depuisTerrain = 0
terrain:SetScript("OnUpdate", function(_, dt)
  depuisTerrain = depuisTerrain + dt
  if depuisTerrain >= .1 then depuisTerrain = 0; DessinerTerrain() end
end)

local function Terrain(reste)
  local mot = reste:match("^(%S+)")
  if mot ~= "on" then etatTerrain = nil; terrain:Hide() return end
  local fx, fy, fw, fh, cx, cy, ech, suivre, dossier =
    reste:match("^on%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
  if not ech then return end
  etatTerrain = { fx = tonumber(fx), fy = tonumber(fy), fw = tonumber(fw), fh = tonumber(fh), cx = tonumber(cx),
    cy = tonumber(cy), ech = tonumber(ech), suivre = suivre == "1", dossier = dossier ~= "" and dossier or nil }
  DessinerTerrain()
end

-- ===== Le cadre du TRACE (refait le 6 novembre 2026, 22 h 45) =============
-- Le MJ trace une zone depuis l'outil Lieux de l'overlay (fenetre libre, qui
-- peut sortir de l'ecran du jeu : « + Point ici », etc.). Le jeu, lui, ne
-- montre qu'UN cadre, comme la carte du trace de l'overlay : l'habillage
-- A'hell'Raz'kah leger de l'addon (UI/Skin.lua, frame-panel.tga, memes
-- mesures), le titre « TRACE DE LA ZONE · NOM », et dedans la VRAIE minimap
-- de WoW, seule (rien de ce qui s'y accroche), rectangulaire, qui remplit tout
-- l'interieur. Elle est plus grande que l'interieur (sa diagonale) et masquee
-- en rectangle : en Lock Cursor elle tourne sans jamais montrer de coin noir.
-- « trace on <nom> », « trace pts x,y;x,y… » (repere de Crossings), « trace add
-- x,y… » (sommets en plus), « trace off ».
local TR = {}
TR.DIAMETRES = {   -- yards couverts par la minimap, par zoom (HereBeDragons-Pins)
  exterieur = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
  interieur = { 300, 240, 180, 120, 80, 50 },
}
TR.DOSSIER = "Interface\\AddOns\\LCMCoreAddon\\ressources\\"
-- En Lock Cursor, WoW fait tourner le MASQUE avec la carte : un masque
-- rectangulaire tournait aussi, debordait du cadre et laissait des coins
-- noirs (vu en jeu, 6 novembre, 23 h 50). Seul un masque ROND reste le meme
-- en tournant. La minimap est donc ronde (masque du jeu), de diametre la
-- diagonale de l'aire : elle couvre tout le rectangle quel que soit l'angle.
-- Ce qui depasse du rectangle est cache par des aplats opaques du cadre,
-- poses AU-DESSUS de la carte (la minimap ignore SetClipsChildren). Le cadre
-- doit donc contenir le cercle entier. Plus petit a la demande du MJ
-- (7 novembre) : carte CARREE, le rectangle qui perd le moins de place autour
-- du cercle. Cadre de 330, cercle de 320, carte de 226 (diagonale 319,6).
TR.COTE, TR.MINI = 330, 320
TR.AW, TR.AH = 226, 226
TR.CY = 165                                   -- centre de l'aire, depuis le haut
TR.AX, TR.AY = (330 - 226) / 2, 165 - 226 / 2 -- coin haut gauche de l'aire
-- Couleurs de l'addon (UI/Kit.lua, UI.C ; OR_TERNI de UI/Skin.lua).
TR.FOND = { 0.06, 0.05, 0.04 }
TR.TITRE = { 0.80, 0.70, 0.40 }
TR.TEXTE = { 0.88, 0.84, 0.76 }
TR.OR_TERNI = { 0.66, 0.51, 0.27 }
-- Les sommets : or (Trace.lua), le premier en bleu (son repere de depart),
-- le dernier pose en vert.
TR.SOMMET = { 1, 0.82, 0.35 }
TR.PREMIER = { 0.45, 0.80, 1 }
TR.DERNIER = { 0.40, 0.90, 0.45 }
TR.guides = {}
-- L'habillage « leger » de UI/Skin.lua (VARIANTES.leger), tel quel.
TR.V = {
  fichier = "frame-panel.tga", tw = 1024, th = 1024,
  L = 98, T = 95, R = 1438, B = 884, largeur = 1340,
  facteur = 0.75, min = 0.26, max = 0.40, coupeHaut = 102,
  railOpaque = 34 / 110, bandeOpaque = { bas = 47 / 110, cote = 24 / 70 },
  fixes = {
    {   0,   0, 230, 330,    0,   0, "TOPLEFT" },
    { 232,   0, 236, 330, 1300,   0, "TOPRIGHT" },
    { 470,   0, 230, 284,    0, 740, "BOTTOMLEFT" },
    { 702,   0, 236, 284, 1300, 740, "BOTTOMRIGHT" },
    {   0, 340, 340, 200,  600,   0, "TOP" },
    { 342, 340, 260, 174,  640, 850, "BOTTOM" },
  },
  bandes = {
    { 610, 340, 12, 160, true,  "TOPLEFT",     230,  40, "TOP",          600, 200 },
    { 632, 340, 12, 160, true,  "TOP",         940,  40, "TOPRIGHT",    1300, 200 },
    { 654, 340, 12, 110, true,  "BOTTOMLEFT",  230, 850, "BOTTOM",       640, 960 },
    { 654, 340, 12, 110, true,  "BOTTOM",      900, 850, "BOTTOMRIGHT", 1300, 960 },
    { 668, 340, 70,  12, false, "TOPLEFT",      40, 330, "BOTTOMLEFT",   110, 740 },
    { 668, 356, 70,  12, false, "TOPRIGHT",   1426, 330, "BOTTOMRIGHT", 1496, 740 },
  },
}

-- Les capitales accentuees (UI.Majuscules de l'addon) : upper() les ignore.
TR.CAPITALES = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë", ["à"] = "À", ["â"] = "Â",
  ["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ù"] = "Ù", ["û"] = "Û", ["ç"] = "Ç", ["œ"] = "Œ" }
function TR.Majuscules(texte)
  texte = tostring(texte or ""):gsub("[\195\197][\128-\191]", function(c) return TR.CAPITALES[c] or c end)
  return (texte:upper())
end

local cadreTrace = CreateFrame("Frame", "LCMCapteurTrace", UIParent)
cadreTrace:SetSize(TR.COTE, TR.COTE)
cadreTrace:SetFrameStrata("HIGH")
cadreTrace:SetClampedToScreen(true)
cadreTrace:SetMovable(true)
cadreTrace:EnableMouse(true)
cadreTrace:RegisterForDrag("LeftButton")
cadreTrace:Hide()
cadreTrace:SetScript("OnDragStart", function(self) self:StartMoving() end)
cadreTrace:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local x, y = self:GetCenter()
  if db and x then db.trace = { x = x, y = y } end
end)

-- Le fond, remonte sous les bandes comme UI.Fenetre:AjusterFond.
cadreTrace.fond = cadreTrace:CreateTexture(nil, "BACKGROUND")
cadreTrace.fond:SetColorTexture(TR.FOND[1], TR.FOND[2], TR.FOND[3], 1)

-- L'habillage : UI.Cadre / decor:Disposer de UI/Skin.lua, pour une fenetre de
-- TR.COTE de large, titre non centre (le motif du haut est rogne quand meme :
-- ses pendentifs tomberaient dans la carte).
do
  local V = TR.V
  local decor = CreateFrame("Frame", nil, cadreTrace)
  decor:SetAllPoints(cadreTrace)
  decor:EnableMouse(false)
  cadreTrace.decor = decor
  local k = math.min(V.max, math.max(V.min, TR.COTE / V.largeur * V.facteur))
  local function Texture(r, etireeEnX, sousNiveau)
    local t = decor:CreateTexture(nil, "ARTWORK", nil, sousNiveau)
    t:SetTexture(TR.DOSSIER .. V.fichier)
    t:SetBlendMode("BLEND")
    local x0, x1, y0, y1 = r[1], r[1] + r[3], r[2], r[2] + r[4]
    if etireeEnX == true then x0, x1 = x0 + 3, x1 - 3
    elseif etireeEnX == false then y0, y1 = y0 + 3, y1 - 3 end
    t:SetTexCoord(x0 / V.tw, x1 / V.tw, y0 / V.th, y1 / V.th)
    return t
  end
  local function Poser(t, point, relatif, sx, sy)
    local centreX = (V.L + V.R) / 2
    local rx = relatif:find("LEFT") and V.L or (relatif:find("RIGHT") and V.R or centreX)
    local ry = relatif:find("TOP") and V.T or V.B
    t:SetPoint(point, cadreTrace, relatif, (sx - rx) * k, -(sy - ry) * k)
  end
  for _, r in ipairs(V.fixes) do
    local t = Texture(r, nil, 1)
    Poser(t, "TOPLEFT", r[7], r[5], r[6])
    local h = r[4]
    if r[7] == "TOP" then h = math.min(h, V.coupeHaut) end
    t:SetTexCoord(r[1] / V.tw, (r[1] + r[3]) / V.tw, r[2] / V.th, (r[2] + h) / V.th)
    t:SetSize(r[3] * k, h * k)
  end
  local haut, gauche, droite, bas = 0, 0, 0, 0
  for _, r in ipairs(V.bandes) do
    local t = Texture(r, r[5], 0)
    Poser(t, "TOPLEFT", r[6], r[7], r[8])
    Poser(t, "BOTTOMRIGHT", r[9], r[10], r[11])
    if r[6] == "TOPLEFT" and r[9] == "TOP" or r[6] == "TOP" and r[9] == "TOPRIGHT" then
      local h1, h2 = (V.T - r[8]) * k, (V.T - r[11]) * k
      haut = math.max(haut, h1 - (h1 - h2) * V.railOpaque)
    elseif r[6] == "TOPLEFT" and r[9] == "BOTTOMLEFT" then
      local a, b = (r[7] - V.L) * k, (r[10] - V.L) * k
      local dedans, dehors = math.max(a, b), math.min(a, b)
      gauche = math.max(gauche, -dehors - (dedans - dehors) * V.bandeOpaque.cote)
    elseif r[6] == "TOPRIGHT" and r[9] == "BOTTOMRIGHT" then
      local a, b = (r[7] - V.R) * k, (r[10] - V.R) * k
      local dedans, dehors = math.min(a, b), math.max(a, b)
      droite = math.max(droite, dehors - (dehors - dedans) * V.bandeOpaque.cote)
    else
      local a, b = -(r[8] - V.B) * k, -(r[11] - V.B) * k
      local dedans, dehors = math.max(a, b), math.min(a, b)
      bas = math.max(bas, -dehors - (dedans - dehors) * V.bandeOpaque.bas)
    end
  end
  cadreTrace.fond:SetPoint("TOPLEFT", cadreTrace, "TOPLEFT", -math.max(0, gauche), math.max(0, haut))
  cadreTrace.fond:SetPoint("BOTTOMRIGHT", cadreTrace, "BOTTOMRIGHT", math.max(0, droite), -math.max(0, bas))
end

-- Le titre, en capitales, comme les libelles du panneau Lieux.
-- Le titre vit au-dessus des aplats qui cachent le cercle.
cadreTrace.devant = CreateFrame("Frame", nil, cadreTrace)
cadreTrace.devant:SetAllPoints()
cadreTrace.titre = cadreTrace.devant:CreateFontString(nil, "OVERLAY")
cadreTrace.titre:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
cadreTrace.titre:SetTextColor(TR.TITRE[1], TR.TITRE[2], TR.TITRE[3])
cadreTrace.titre:SetPoint("TOPLEFT", cadreTrace, "TOPLEFT", 40, -14)
cadreTrace.titre:SetPoint("TOPRIGHT", cadreTrace, "TOPRIGHT", -40, -14)
cadreTrace.titre:SetJustifyH("LEFT")
cadreTrace.titre:SetWordWrap(false)

-- L'aire de la carte : un rectangle sous le titre, qui coupe ce qui deborde.
cadreTrace.aire = CreateFrame("Frame", nil, cadreTrace)
cadreTrace.aire:SetPoint("TOPLEFT", cadreTrace, "TOPLEFT", TR.AX, -TR.AY)
cadreTrace.aire:SetSize(TR.AW, TR.AH)
cadreTrace.aire:SetClipsChildren(true)
cadreTrace.aire:EnableMouseWheel(true)
cadreTrace.aire:SetScript("OnMouseWheel", function(_, d)
  if not (Minimap and Minimap.GetZoom) then return end
  local z = Minimap:GetZoom() + (d > 0 and 1 or -1)
  if z >= 0 and z <= (Minimap:GetZoomLevels() - 1) then Minimap:SetZoom(z) end
end)
-- Les aplats qui cachent ce que le cercle de la minimap deborde de l'aire :
-- du bord de l'aire au bord du cadre, de la couleur du fond.
cadreTrace.caches = CreateFrame("Frame", nil, cadreTrace)
cadreTrace.caches:SetAllPoints()
for _, a in ipairs({
  { cadreTrace, "TOPLEFT", 0, cadreTrace.aire, "TOPRIGHT", TR.AX },          -- haut, toute la largeur
  { cadreTrace.aire, "BOTTOMLEFT", -TR.AX, cadreTrace, "BOTTOMRIGHT", 0 },   -- bas, toute la largeur
  { cadreTrace, "TOPLEFT", 0, cadreTrace.aire, "BOTTOMLEFT", 0 },            -- gauche
  { cadreTrace.aire, "TOPRIGHT", 0, cadreTrace, "BOTTOMRIGHT", 0 },          -- droite
}) do
  local t = cadreTrace.caches:CreateTexture(nil, "BACKGROUND")
  t:SetColorTexture(TR.FOND[1], TR.FOND[2], TR.FOND[3], 1)
  t:SetPoint("TOPLEFT", a[1], a[2], a[3], 0)
  t:SetPoint("BOTTOMRIGHT", a[4], a[5], a[6], 0)
end
-- Un filet d'or terni autour de la carte (UI.Bordure).
cadreTrace.bord = CreateFrame("Frame", nil, cadreTrace)
cadreTrace.bord:SetAllPoints(cadreTrace.aire)
for _, cote in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
  local t = cadreTrace.bord:CreateTexture(nil, "OVERLAY")
  t:SetColorTexture(TR.OR_TERNI[1], TR.OR_TERNI[2], TR.OR_TERNI[3], 0.55)
  if cote == "TOP" or cote == "BOTTOM" then
    t:SetHeight(1); t:SetPoint(cote .. "LEFT"); t:SetPoint(cote .. "RIGHT")
  else
    t:SetWidth(1); t:SetPoint("TOP" .. cote); t:SetPoint("BOTTOM" .. cote)
  end
end
-- Les sommets, par-dessus la minimap.
cadreTrace.dessus = CreateFrame("Frame", nil, cadreTrace.aire)
cadreTrace.dessus:SetAllPoints()
cadreTrace.lignes, cadreTrace.points = {}, {}
-- La croix de l'addon (UI.Fenetre : piece 898,102 54x54 de
-- widgets-reference.tga, decoupee dans ressources/croix.tga), au centre de
-- l'encoche droite (UI.AelEncoches : 1423 ; 85,5), cote plafonne a 18.
cadreTrace.fermer = CreateFrame("Button", nil, cadreTrace)
do
  local V = TR.V
  local k = math.min(V.max, math.max(V.min, TR.COTE / V.largeur * V.facteur))
  local cote = math.max(14, math.min(18, 54 * TR.COTE / 845))
  local b = cadreTrace.fermer
  b:SetSize(cote, cote)
  b:SetPoint("CENTER", cadreTrace, "TOPRIGHT", (1423 - V.R) * k, -(85.5 - V.T) * k)
  b.icone = b:CreateTexture(nil, "OVERLAY")
  b.icone:SetAllPoints()
  b.icone:SetTexture(TR.DOSSIER .. "croix.tga")
  b.icone:SetTexCoord(0, 54 / 64, 0, 54 / 64)
  b.survol = b:CreateTexture(nil, "HIGHLIGHT")
  b.survol:SetAllPoints()
  b.survol:SetColorTexture(1, 1, 1, 0.07)
end

-- Lock North / Lock Cursor : le bouton de l'addon (UI.Bouton + AelBoutonNet :
-- aplat sombre, filet d'or terni, survol et appui plus chauds), en bas a
-- droite de la carte.
cadreTrace.mode = CreateFrame("Button", nil, cadreTrace)
cadreTrace.mode:SetSize(104, 22)
cadreTrace.mode:SetPoint("TOP", cadreTrace.aire, "BOTTOM", 0, -14)
do
  local b = cadreTrace.mode
  b.fond = b:CreateTexture(nil, "BACKGROUND")
  b.fond:SetAllPoints()
  for _, cote in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = b:CreateTexture(nil, "BORDER")
    t:SetColorTexture(TR.OR_TERNI[1], TR.OR_TERNI[2], TR.OR_TERNI[3], 1)
    if cote == "TOP" or cote == "BOTTOM" then
      t:SetHeight(1); t:SetPoint(cote .. "LEFT"); t:SetPoint(cote .. "RIGHT")
    else
      t:SetWidth(1); t:SetPoint("TOP" .. cote); t:SetPoint("BOTTOM" .. cote)
    end
  end
  local function Peindre(etat)
    local c = etat == "appui" and { 0.12, 0.085, 0.04 }
      or (etat == "survol" and { 0.09, 0.065, 0.03 } or { 0.035, 0.030, 0.023 })
    b.fond:SetColorTexture(c[1], c[2], c[3], 1)
  end
  Peindre()
  b:SetScript("OnEnter", function() Peindre("survol") end)
  b:SetScript("OnLeave", function() Peindre() end)
  b:SetScript("OnMouseDown", function() Peindre("appui") end)
  b:SetScript("OnMouseUp", function() Peindre("survol") end)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetAllPoints()
  b.label:SetJustifyH("CENTER")
  b.label:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
end

local sommetsTrace = {}
local minimapPrise   -- l'etat de la minimap avant l'emprunt, pour la rendre telle quelle

-- Le masque d'origine de la minimap (il n'a pas d'accesseur) : celui du jeu actuel.
local MASQUE_ROND = (WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
  and "Interface\\Masks\\CircleMaskScalable" or "Textures\\MinimapMask"
local function ModeTrace() return (db and db.traceMode) == "curseur" and "curseur" or "nord" end
local function AppliquerModeTrace()
  local curseur = ModeTrace() == "curseur"
  cadreTrace.mode.label:SetText(curseur and "Lock Cursor" or "Lock North")
  if minimapPrise and SetCVar then SetCVar("rotateMinimap", curseur and "1" or "0") end
end
cadreTrace.mode:SetScript("OnClick", function()
  if db then db.traceMode = ModeTrace() == "curseur" and "nord" or "curseur" end
  AppliquerModeTrace()
end)

-- Ce qui s'accroche a la minimap (boutons d'addons, horloge, boite a boutons,
-- zoom, bordure) : cache pendant le trace, remontre a la fin, et seulement ce
-- qui etait visible.
-- Les cadres INTERDITS de Blizzard (IsForbidden) ne se touchent pas, meme
-- pour lire leurs ancres : l'erreur « forbidden object » arretait le trace
-- (6 novembre, 23 h 25). Un cadre protege ne se cache pas en combat. Chaque
-- acces passe par pcall : un cadre etrange d'un autre addon ne doit rien
-- casser ici.
function TR.Touchable(f)
  if type(f) ~= "table" then return false end
  if f.IsForbidden and f:IsForbidden() then return false end
  if InCombatLockdown and InCombatLockdown() and f.IsProtected and f:IsProtected() then return false end
  return true
end
function TR.Cacher(pris, f)
  if f and f.lcmSacRepere then return end
  if f == cadreTrace or not TR.Touchable(f) then return end
  pcall(function()
    if f:IsShown() then
      f:Hide()
      pris.caches[#pris.caches + 1] = f
    end
  end)
end
function TR.AccrocheAMinimap(f)
  for i = 1, f:GetNumPoints() do
    local _, rel = f:GetPoint(i)
    if rel == Minimap then return true end
  end
  return false
end
function TR.CacherAccroches(pris)
  for _, f in ipairs({ Minimap:GetChildren() }) do TR.Cacher(pris, f) end
  for _, r in ipairs({ Minimap:GetRegions() }) do TR.Cacher(pris, r) end
  -- Accroches a la minimap sans en etre les enfants (horloge du jeu, boites
  -- a boutons d'autres addons) : leurs ancres le disent.
  for _, f in ipairs({ UIParent:GetChildren() }) do
    if f ~= cadreTrace and f ~= Minimap and TR.Touchable(f) then
      local ok, accroche = pcall(TR.AccrocheAMinimap, f)
      if ok and accroche then TR.Cacher(pris, f) end
    end
  end
  TR.Cacher(pris, MinimapCluster)
  TR.Cacher(pris, TimeManagerClockButton)
  TR.Cacher(pris, MinimapNorthTag)
  TR.Cacher(pris, MinimapCompassTexture)
end

local function PrendreMinimap()
  if minimapPrise or not Minimap then return end
  local pris = { parent = Minimap:GetParent(), w = Minimap:GetWidth(), h = Minimap:GetHeight(),
    echelle = Minimap:GetScale(), strate = Minimap:GetFrameStrata(), niveau = Minimap:GetFrameLevel(),
    points = {}, caches = {} }
  for i = 1, Minimap:GetNumPoints() do pris.points[i] = { Minimap:GetPoint(i) } end
  pris.rotation = GetCVar and GetCVar("rotateMinimap")
  pris.forme = GetMinimapShape
  minimapPrise = pris
  TR.CacherAccroches(pris)
  -- Ronde (masque du jeu) : seul un rond reste le meme en tournant.
  if Minimap.SetMaskTexture then Minimap:SetMaskTexture(MASQUE_ROND) end
  AppliquerModeTrace()
  Minimap:SetParent(cadreTrace.aire)
  Minimap:ClearAllPoints()
  Minimap:SetPoint("CENTER", cadreTrace.aire, "CENTER")
  Minimap:SetScale(1)
  Minimap:SetSize(TR.MINI, TR.MINI)
  Minimap:SetFrameStrata("HIGH")
  Minimap:SetFrameLevel(cadreTrace:GetFrameLevel() + 1)
  Minimap:Show()
  -- Le terrain se redessine a la nouvelle taille (sans cela il peut rester noir).
  if Minimap.GetZoom then
    local z = Minimap:GetZoom()
    Minimap:SetZoom(z > 0 and z - 1 or z + 1)
    Minimap:SetZoom(z)
  end
  -- Au-dessus de la carte : le filet, l'habillage (ses tours d'angle mordent
  -- sur la carte), les sommets, le bouton.
  local n = Minimap:GetFrameLevel()
  cadreTrace.caches:SetFrameLevel(n + 1)
  cadreTrace.bord:SetFrameLevel(n + 2)
  cadreTrace.decor:SetFrameLevel(n + 3)
  cadreTrace.devant:SetFrameLevel(n + 4)
  cadreTrace.dessus:SetFrameLevel(n + 4)
  cadreTrace.mode:SetFrameLevel(n + 6)
  cadreTrace.fermer:SetFrameLevel(n + 6)
end
local function RendreMinimap()
  local pris = minimapPrise
  if not pris or not Minimap then return end
  minimapPrise = nil
  if Minimap.SetMaskTexture then Minimap:SetMaskTexture(MASQUE_ROND) end
  GetMinimapShape = pris.forme
  if pris.rotation and SetCVar then SetCVar("rotateMinimap", pris.rotation) end
  Minimap:SetParent(pris.parent)
  Minimap:ClearAllPoints()
  for _, pt in ipairs(pris.points) do Minimap:SetPoint(unpack(pt)) end
  Minimap:SetScale(pris.echelle)
  Minimap:SetSize(pris.w, pris.h)
  Minimap:SetFrameStrata(pris.strate)
  Minimap:SetFrameLevel(pris.niveau)
  for _, f in ipairs(pris.caches) do
    if TR.Touchable(f) then pcall(f.Show, f) end
  end
  if Minimap.GetZoom then
    local z = Minimap:GetZoom()
    Minimap:SetZoom(z > 0 and z - 1 or z + 1)
    Minimap:SetZoom(z)
  end
end

-- Un sommet (repere de Crossings : x vers l'ouest, y vers le nord) sur la
-- minimap, centree sur le joueur : l'est a droite, le nord en haut, sauf si la
-- minimap tourne avec le joueur. L'echelle est celle de la MINIMAP entiere
-- (TR.MINI), pas de l'aire visible.
local function DessinerTrace()
  local px, py, facing = PoseCrossings()
  local aire = cadreTrace.dessus
  for _, l in ipairs(cadreTrace.lignes) do l:Hide() end
  for _, t in ipairs(cadreTrace.points) do t:Hide() end
  for _, l in pairs(TR.guides) do l:Hide() end
  if not px or #sommetsTrace == 0 then return end
  local zoom = (Minimap and Minimap.GetZoom and Minimap:GetZoom() or 0) + 1
  local table_ = (IsIndoors and IsIndoors()) and TR.DIAMETRES.interieur or TR.DIAMETRES.exterieur
  local s = TR.MINI / (table_[zoom] or table_[1])
  local tourne = GetCVar and GetCVar("rotateMinimap") == "1"
  local c, sn = math.cos(facing or 0), math.sin(facing or 0)
  local function Ecran(x, y)
    local est, nord = -(x - px) * s, (y - py) * s
    -- Minimap qui tourne (Lock Cursor) : le regard du joueur monte a l'ecran,
    -- soit une rotation de -facing.
    if tourne then est, nord = est * c + nord * sn, -est * sn + nord * c end
    return TR.AW / 2 + est, TR.AH / 2 + nord
  end
  local n = #sommetsTrace
  local function Guide(cle, couleur, bx, by)
    local l = TR.guides[cle]
    if not l then
      l = aire:CreateLine(nil, "OVERLAY", nil, 6)
      l:SetColorTexture(couleur[1], couleur[2], couleur[3], 0.9)
      l:SetThickness(2)
      TR.guides[cle] = l
    end
    l:SetStartPoint("BOTTOMLEFT", aire, TR.AW / 2, TR.AH / 2)
    l:SetEndPoint("BOTTOMLEFT", aire, bx, by)
    l:Show()
  end
  if aire.CreateLine then
    local fx, fy = Ecran(sommetsTrace[1][1], sommetsTrace[1][2])
    Guide("guidePremier", TR.PREMIER, fx, fy)
    if n > 1 then
      local dx, dy = Ecran(sommetsTrace[n][1], sommetsTrace[n][2])
      Guide("guideDernier", TR.DERNIER, dx, dy)
    end
  end
  for i = 1, n do
    local a = sommetsTrace[i]
    local ax, ay = Ecran(a[1], a[2])
    local t = cadreTrace.points[i]
    if not t then
      t = aire:CreateTexture(nil, "OVERLAY")
      t:SetTexture("Interface\\Buttons\\WHITE8X8")
      t:SetSize(6, 6)
      t:SetVertexColor(1, 0.82, 0.35)
      cadreTrace.points[i] = t
    end
    local c = i == 1 and TR.PREMIER or (i == n and TR.DERNIER or TR.SOMMET)
    t:SetVertexColor(c[1], c[2], c[3])
    t:SetSize(i == 1 and 9 or 6, i == 1 and 9 or 6)
    t:ClearAllPoints(); t:SetPoint("CENTER", aire, "BOTTOMLEFT", ax, ay); t:Show()
    -- Le contour ouvert : du sommet i au suivant (le dernier ne se referme pas).
    if i < n and aire.CreateLine then
      local b = sommetsTrace[i + 1]
      local bx, by = Ecran(b[1], b[2])
      local l = cadreTrace.lignes[i]
      if not l then
        l = aire:CreateLine(nil, "OVERLAY")
        l:SetColorTexture(1, 0.82, 0.35, 0.9)
        l:SetThickness(2)
        cadreTrace.lignes[i] = l
      end
      l:SetStartPoint("BOTTOMLEFT", aire, ax, ay)
      l:SetEndPoint("BOTTOMLEFT", aire, bx, by)
      l:Show()
    end
  end
end
local attenteTrace = 0
cadreTrace:SetScript("OnUpdate", function(_, dt)
  attenteTrace = attenteTrace + dt
  if attenteTrace < 0.05 then return end
  attenteTrace = 0
  DessinerTrace()
end)

local function Trace(reste)
  local mot, suite = reste:match("^(%S+)%s*(.-)%s*$")
  if mot == "on" then
    cadreTrace.titre:SetText(TR.Majuscules("TRACÉ DE LA ZONE  ·  " .. (suite or "")))
    cadreTrace:ClearAllPoints()
    if db and db.trace and db.trace.x then
      cadreTrace:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.trace.x, db.trace.y)
    else
      -- En haut a droite, a la place de la minimap qu'il emprunte.
      cadreTrace:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -30)
    end
    PrendreMinimap()
    cadreTrace:Show()
  elseif mot == "pts" or mot == "add" then
    -- « pts » remplace la liste, « add » la prolonge (21 novembre 2026) :
    -- renvoyer TOUS les sommets a chaque point faisait taper une ligne de
    -- plus en plus longue dans la saisie du capteur, et le jeu gelait.
    if mot == "pts" then sommetsTrace = {} end
    for x, y in (suite or ""):gmatch("(%-?[%d%.]+),(%-?[%d%.]+)") do
      sommetsTrace[#sommetsTrace + 1] = { tonumber(x), tonumber(y) }
    end
  elseif mot == "off" then
    cadreTrace:Hide()
    RendreMinimap()
    sommetsTrace = {}
  end
end

cadreTrace.fermer:SetScript("OnClick", function() Trace("off") end)

-- Les sacs poses restent des points individuels. Leurs reperes survivent a
-- /reload dans LCMCapteurDB ; l'identifiant est celui du point, pas du modele.
local reperesSacs = {}
local suiviSacs = CreateFrame("Frame", "LCMCapteurSacsMinicarte")
local attenteSacs = 0
local function RepereSac(id)
  local b = reperesSacs[id]
  if b then return b end
  b = CreateFrame("Button", nil, Minimap)
  b.lcmSacRepere = true
  b:SetSize(18, 18)
  b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
  b.fond = b:CreateTexture(nil, "BACKGROUND")
  b.fond:SetAllPoints(); b.fond:SetColorTexture(.02, .015, .01, .95)
  b.icone = b:CreateTexture(nil, "OVERLAY")
  b.icone:SetPoint("TOPLEFT", 2, -2); b.icone:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icone:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Sac posé", 1, .82, .35)
    if self.distance then GameTooltip:AddLine(string.format("À %.0f mètres", self.distance), .9, .85, .7) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  reperesSacs[id] = b
  return b
end
local function DessinerSacs()
  if not (db and type(db.sacsPoses) == "table" and Minimap and Minimap:IsShown()) then
    for _, b in pairs(reperesSacs) do b:Hide() end
    return
  end
  local px, py, _, carte = Position()
  if not px then for _, b in pairs(reperesSacs) do b:Hide() end return end
  local zoom = (Minimap:GetZoom() or 0) + 1
  local diametres = (IsIndoors and IsIndoors()) and TR.DIAMETRES.interieur or TR.DIAMETRES.exterieur
  local largeur = Minimap:GetWidth()
  local echelle = largeur / (diametres[zoom] or diametres[1])
  local rayon = largeur * .42
  local tourne = GetCVar and GetCVar("rotateMinimap") == "1"
  local facing = tourne and GetPlayerFacing and GetPlayerFacing() or 0
  local c, sn = math.cos(facing or 0), math.sin(facing or 0)
  for id, sac in pairs(db.sacsPoses) do
    local b = RepereSac(id)
    if tonumber(sac.carte) ~= carte then b:Hide()
    else
      -- C_Epsilon donne (x,y) ; Crossings et la minimap utilisent (y,x).
      local est, nord = -(sac.y - py) * echelle, (sac.x - px) * echelle
      if tourne then est, nord = est * c + nord * sn, -est * sn + nord * c end
      local distance = math.sqrt((sac.x - px)^2 + (sac.y - py)^2)
      local longueur = math.sqrt(est * est + nord * nord)
      if longueur > rayon then est, nord = est * rayon / longueur, nord * rayon / longueur end
      b.distance = distance
      b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
      b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", est, nord)
      b:Show()
    end
  end
  for id, b in pairs(reperesSacs) do if not db.sacsPoses[id] then b:Hide() end end
end
suiviSacs:SetScript("OnUpdate", function(_, dt)
  attenteSacs = attenteSacs + dt
  if attenteSacs < .15 then return end
  attenteSacs = 0
  DessinerSacs()
end)
local function SacsMinicarte(reste)
  if not db then return end
  local action, id, args = (reste or ""):match("^(%S+)%s+(sol_[%x]+)%s*(.-)%s*$")
  if not id then return end
  db.sacsPoses = db.sacsPoses or {}
  if action == "retirer" then
    db.sacsPoses[id] = nil
    if reperesSacs[id] then reperesSacs[id]:Hide() end
  elseif action == "poser" then
    local carte, x, y, z = args:match("^(%-?%d+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)$")
    carte, x, y, z = tonumber(carte), tonumber(x), tonumber(y), tonumber(z)
    if carte and x and y and z then db.sacsPoses[id] = { carte = carte, x = x, y = y, z = z } end
  end
end

-- Le serveur annonce le GUID dans sa réponse au spawn. Le point LCM est
-- associé à cette seule réponse, pendant une fenêtre courte et sérialisée.
-- « Spawned gameobject [nom - 716479] (GUID: 590830) » (Epsilon, 13
-- novembre 2026) : le GUID est entre PARENTHESES, et le chat l'habille de
-- couleurs et de liens. On lit le texte nu, crochets ou parentheses.
-- Deux ecoutes : l'evenement brut, et le texte AFFICHE dans les fenetres de
-- chat — l'addon d'Epsilon reecrit la reponse (liens [Spawn] [Delete]…) et
-- l'evenement brut n'a pas toujours cette forme. Les messages vus pendant
-- l'attente sont gardes dans db.diagGob pour le diagnostic.
local function LireGob(message, source)
  if not gobEnAttente then return end
  if GetTime() - gobEnAttente.depuis > 8 then gobEnAttente = nil; return end
  if type(message) ~= "string" then return end
  local nu = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
  if db then
    db.diagGob = db.diagGob or {}
    table.insert(db.diagGob, source .. " " .. nu:sub(1, 200))
    while #db.diagGob > 12 do table.remove(db.diagGob, 1) end
  end
  local guid = nu:match("GUID:%s*(%d+)")
  -- Un blueprint (posebp, plus bas) : « Spawned blueprint » ne porte pas de
  -- GUID, c'est le message SUIVANT qui donne celui du groupe (EpsilonLib,
  -- GameObject.lua, groupMessageCheck).
  if gobEnAttente.blueprint then
    if nu:find("Spawned blueprint", 1, true) then gobEnAttente.vu = true end
    if guid and gobEnAttente.vu then
      gobCapture = { point = gobEnAttente.point, guid = guid, depuis = GetTime() }
      gobEnAttente = nil
    end
    return
  end
  -- L'objet d'un modele (posegob, plus bas) : le serveur ne repete pas
  -- toujours le displayid donne a .gob spawn ; « spawn » suffit alors.
  if guid and (nu:find(gobEnAttente.entree, 1, true)
      or (gobEnAttente.souple and nu:lower():find("spawn", 1, true))) then
    gobCapture = { point = gobEnAttente.point, guid = guid, depuis = GetTime() }
    gobEnAttente = nil
  end
end
local guetteurGob = CreateFrame("Frame")
guetteurGob:RegisterEvent("CHAT_MSG_SYSTEM")
guetteurGob:SetScript("OnEvent", function(_, evenement, message) LireGob(message, evenement) end)
for i = 1, (NUM_CHAT_WINDOWS or 10) do
  local fenetre = _G["ChatFrame" .. i]
  if fenetre and fenetre.AddMessage then
    hooksecurefunc(fenetre, "AddMessage", function(_, texte) LireGob(texte, "chat" .. i) end)
  end
end
local function SacGob(reste)
  local action, point, entree = (reste or ""):match("^(%S+)%s+(sol_[%x]+)%s+(%d+)$")
  if action ~= "poser" or (entree ~= "716479" and entree ~= "716509") or not point then return end
  gobEnAttente = { point = point, entree = entree, depuis = GetTime() }
  gobCapture = nil
  Envoyer(".gob spawn " .. entree, "SAY")
end

-- ===== Les objets du monde (Panel MJ > Interactions, 13 novembre 2026) =====
-- Un modele de point (ressource, coffre, affichage) peut porter, s'il le veut,
-- un objet du jeu (un gob .m2) qui nait avec le point quand le MJ le pose.
-- Le catalogue et le rendu des .m2 n'existent QU'EN JEU : on reprend
-- Epsilon_Viewer (Warli) : C_Epsilon.GODI_Search / GODI_RetrieveSearch
-- (fileid, name, displayid), un ModelScene par apercu, « .gob spawn
-- <displayid> », et sa liste des objets qui font planter le client.
--   gobs chercher <texte>          ouvre la fenetre d'apercus
--   gobs fermer
--   posegob <point> <displayid>    le spawn, son GUID rendu comme celui d'un sac
-- Le choix repart par la trame de genre 4 (celle du GUID des sacs) :
-- point = « gobchoix:<n>:<displayid> », guid = le nom court (31 octets au plus).
local GOB = { COLS = 3, LIGNES = 2, L = 600, H = 480, MAX = 600, CW = 176, CH = 168 }
GOB.CACHES = { "alphabet_caligo", "alphabet_futhark", "alphabet_mechanical", "alphabet_morpheus",
  "alphabet_romansd", "alphabet_suastornad", "collections_" }
GOB.resultats, GOB.page, GOB.recherche, GOB.n = {}, 1, "", math.floor(GetTime()) % 10000

local function NomCourt(nom)
  local court = tostring(nom or ""):match("([^/\\]+)$") or ""
  return (court:gsub("%.[mM]2$", ""))
end

local function GobsChercher(texte)
  GOB.resultats, GOB.page, GOB.recherche = {}, 1, texte
  if not (C_Epsilon and C_Epsilon.GODI_Search and C_Epsilon.GODI_RetrieveSearch) then return "sans" end
  local mots = {}
  for m in texte:lower():gmatch("%S+") do mots[#mots + 1] = m end
  if not mots[1] or #mots[1] < 2 then return "court" end
  -- Le premier mot au catalogue, puis tous les mots sur le nom
  -- (Epsilon_Viewer, tokenizedSearch).
  local ok, n = pcall(C_Epsilon.GODI_Search, mots[1])
  if not ok or type(n) ~= "number" then return "sans" end
  local vus = {}
  for i = 0, n - 1 do
    if #GOB.resultats >= GOB.MAX then break end
    local okR, r = pcall(C_Epsilon.GODI_RetrieveSearch, i)
    if okR and type(r) == "table" and r.fileid and r.displayid and not vus[r.fileid] then
      vus[r.fileid] = true
      local nom = tostring(r.name or ""):gsub("eps_secret", "eps"):gsub("secret_eps", "eps")
      local bas = nom:lower()
      local garde = not bas:find(".wmo", 1, true)
      for _, c in ipairs(GOB.CACHES) do if bas:find(c, 1, true) then garde = false end end
      for _, m in ipairs(mots) do if not bas:find(m, 1, true) then garde = false end end
      if garde then table.insert(GOB.resultats, { fileid = r.fileid, displayid = r.displayid, nom = NomCourt(nom) }) end
    end
  end
  table.sort(GOB.resultats, function(a, b) return a.nom < b.nom end)
  return "ok"
end

-- L'habillage « leger » de UI/Skin.lua pour une fenetre de `largeur` : le
-- meme calcul que le cadre du trace (plus haut), et la croix de l'addon.
local function HabillerAel(cadre, largeur)
  local V = TR.V
  cadre.fond = cadre:CreateTexture(nil, "BACKGROUND")
  cadre.fond:SetColorTexture(TR.FOND[1], TR.FOND[2], TR.FOND[3], 1)
  local decor = CreateFrame("Frame", nil, cadre)
  decor:SetAllPoints(cadre)
  decor:EnableMouse(false)
  local k = math.min(V.max, math.max(V.min, largeur / V.largeur * V.facteur))
  local function Texture(r, etireeEnX, sousNiveau)
    local t = decor:CreateTexture(nil, "ARTWORK", nil, sousNiveau)
    t:SetTexture(TR.DOSSIER .. V.fichier)
    t:SetBlendMode("BLEND")
    local x0, x1, y0, y1 = r[1], r[1] + r[3], r[2], r[2] + r[4]
    if etireeEnX == true then x0, x1 = x0 + 3, x1 - 3
    elseif etireeEnX == false then y0, y1 = y0 + 3, y1 - 3 end
    t:SetTexCoord(x0 / V.tw, x1 / V.tw, y0 / V.th, y1 / V.th)
    return t
  end
  local function Poser(t, point, relatif, sx, sy)
    local centreX = (V.L + V.R) / 2
    local rx = relatif:find("LEFT") and V.L or (relatif:find("RIGHT") and V.R or centreX)
    local ry = relatif:find("TOP") and V.T or V.B
    t:SetPoint(point, cadre, relatif, (sx - rx) * k, -(sy - ry) * k)
  end
  for _, r in ipairs(V.fixes) do
    local t = Texture(r, nil, 1)
    Poser(t, "TOPLEFT", r[7], r[5], r[6])
    local h = r[4]
    if r[7] == "TOP" then h = math.min(h, V.coupeHaut) end
    t:SetTexCoord(r[1] / V.tw, (r[1] + r[3]) / V.tw, r[2] / V.th, (r[2] + h) / V.th)
    t:SetSize(r[3] * k, h * k)
  end
  local haut, gauche, droite, bas = 0, 0, 0, 0
  for _, r in ipairs(V.bandes) do
    local t = Texture(r, r[5], 0)
    Poser(t, "TOPLEFT", r[6], r[7], r[8])
    Poser(t, "BOTTOMRIGHT", r[9], r[10], r[11])
    if r[6] == "TOPLEFT" and r[9] == "TOP" or r[6] == "TOP" and r[9] == "TOPRIGHT" then
      local h1, h2 = (V.T - r[8]) * k, (V.T - r[11]) * k
      haut = math.max(haut, h1 - (h1 - h2) * V.railOpaque)
    elseif r[6] == "TOPLEFT" and r[9] == "BOTTOMLEFT" then
      local a, b = (r[7] - V.L) * k, (r[10] - V.L) * k
      local dedans, dehors = math.max(a, b), math.min(a, b)
      gauche = math.max(gauche, -dehors - (dedans - dehors) * V.bandeOpaque.cote)
    elseif r[6] == "TOPRIGHT" and r[9] == "BOTTOMRIGHT" then
      local a, b = (r[7] - V.R) * k, (r[10] - V.R) * k
      local dedans, dehors = math.min(a, b), math.max(a, b)
      droite = math.max(droite, dehors - (dehors - dedans) * V.bandeOpaque.cote)
    else
      local a, b = -(r[8] - V.B) * k, -(r[11] - V.B) * k
      local dedans, dehors = math.max(a, b), math.min(a, b)
      bas = math.max(bas, -dehors - (dedans - dehors) * V.bandeOpaque.bas)
    end
  end
  cadre.fond:SetPoint("TOPLEFT", cadre, "TOPLEFT", -math.max(0, gauche), math.max(0, haut))
  cadre.fond:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", math.max(0, droite), -math.max(0, bas))
  local cote = math.max(14, math.min(18, 54 * largeur / 845))
  local b = CreateFrame("Button", nil, cadre)
  b:SetSize(cote, cote)
  b:SetPoint("CENTER", cadre, "TOPRIGHT", (1423 - V.R) * k, -(85.5 - V.T) * k)
  b:SetFrameLevel(decor:GetFrameLevel() + 5)
  b.icone = b:CreateTexture(nil, "OVERLAY")
  b.icone:SetAllPoints()
  b.icone:SetTexture(TR.DOSSIER .. "croix.tga")
  b.icone:SetTexCoord(0, 54 / 64, 0, 54 / 64)
  b.survol = b:CreateTexture(nil, "HIGHLIGHT")
  b.survol:SetAllPoints()
  b.survol:SetColorTexture(1, 1, 1, 0.07)
  cadre.fermer = b
  return decor
end

-- Un filet d'or terni (UI.Bordure).
local function Filet(parent, alpha)
  for _, cote in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(TR.OR_TERNI[1], TR.OR_TERNI[2], TR.OR_TERNI[3], alpha or 1)
    if cote == "TOP" or cote == "BOTTOM" then
      t:SetHeight(1); t:SetPoint(cote .. "LEFT"); t:SetPoint(cote .. "RIGHT")
    else
      t:SetWidth(1); t:SetPoint("TOP" .. cote); t:SetPoint("BOTTOM" .. cote)
    end
  end
end

-- Le bouton de l'addon (UI.Bouton + AelBoutonNet), comme Lock North du trace.
local function BoutonAel(parent, l, h, texte)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(l, h)
  b.fond = b:CreateTexture(nil, "BACKGROUND")
  b.fond:SetAllPoints()
  Filet(b)
  local function Peindre(etat)
    local c = etat == "appui" and { 0.12, 0.085, 0.04 }
      or (etat == "survol" and { 0.09, 0.065, 0.03 } or { 0.035, 0.030, 0.023 })
    b.fond:SetColorTexture(c[1], c[2], c[3], 1)
  end
  Peindre()
  b:SetScript("OnEnter", function() Peindre("survol") end)
  b:SetScript("OnLeave", function() Peindre() end)
  b:SetScript("OnMouseDown", function() Peindre("appui") end)
  b:SetScript("OnMouseUp", function() Peindre("survol") end)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetAllPoints()
  b.label:SetJustifyH("CENTER")
  b.label:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
  b.label:SetText(texte)
  return b
end

local cadreGobs = CreateFrame("Frame", "LCMCapteurGobs", UIParent)
cadreGobs:SetSize(GOB.L, GOB.H)
cadreGobs:SetPoint("CENTER", UIParent, "CENTER", -220, 40)
cadreGobs:SetFrameStrata("DIALOG")
cadreGobs:SetClampedToScreen(true)
cadreGobs:SetMovable(true)
cadreGobs:EnableMouse(true)
cadreGobs:RegisterForDrag("LeftButton")
cadreGobs:Hide()
cadreGobs:SetScript("OnDragStart", function(self) self:StartMoving() end)
cadreGobs:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
do
  local decor = HabillerAel(cadreGobs, GOB.L)
  cadreGobs.fermer:SetScript("OnClick", function() cadreGobs:Hide() end)
  cadreGobs.devant = CreateFrame("Frame", nil, cadreGobs)
  cadreGobs.devant:SetAllPoints()
  cadreGobs.devant:SetFrameLevel(decor:GetFrameLevel() + 2)
  cadreGobs.titre = cadreGobs.devant:CreateFontString(nil, "OVERLAY")
  cadreGobs.titre:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  cadreGobs.titre:SetTextColor(TR.TITRE[1], TR.TITRE[2], TR.TITRE[3])
  cadreGobs.titre:SetPoint("TOPLEFT", cadreGobs, "TOPLEFT", 40, -14)
  cadreGobs.titre:SetPoint("TOPRIGHT", cadreGobs, "TOPRIGHT", -40, -14)
  cadreGobs.titre:SetJustifyH("LEFT")
  cadreGobs.titre:SetWordWrap(false)
  cadreGobs.aide = cadreGobs.devant:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cadreGobs.aide:SetPoint("TOPLEFT", cadreGobs, "TOPLEFT", 30, -40)
  cadreGobs.aide:SetPoint("TOPRIGHT", cadreGobs, "TOPRIGHT", -30, -40)
  cadreGobs.aide:SetJustifyH("LEFT")
  cadreGobs.aide:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
  cadreGobs.aide:SetText("Clic gauche : tourner · molette : zoom · « Choisir » lie l'objet au modèle du Panel MJ.")
end

-- La camera de Epsilon_Viewer (model_actor_OnModelLoaded) : cadree sur la
-- boite de l'objet, legerement de trois quarts.
local function ApercuCharge(acteur)
  local x1, y1, z1, x2, y2, z2 = acteur:GetActiveBoundingBox()
  if x2 == nil then return end
  local lx, ly, lz = x2 - x1, y2 - y1, z2 - z1
  if lx == 0 then lx = 12 end
  if ly == 0 then ly = 12 end
  if lz == 0 then lz = 12 end
  local taille = math.sqrt(lx ^ 2 + ly ^ 2 + lz ^ 2) * 1.5
  local angle = math.max(lx, ly) < lz and 45 / 3 or 45 / 2
  local camera = acteur:GetParent():GetActiveCamera()
  if not camera then return end
  camera:SetPitch(math.rad(angle)); camera:SetYaw(0); camera:SetRoll(0)
  camera:SetTarget(0, 0, 0)
  camera:SetMinZoomDistance(taille * 0.5)
  camera:SetMaxZoomDistance(taille * 2)
  camera:SetZoomDistance(taille * 1.1)
  camera:SnapAllInterpolatedValues()
  camera.panningXOffset, camera.panningYOffset = 0, 0
  acteur:SetYaw(math.pi / 1.2)
end

local AfficherGobs
GOB.cases = {}
for i = 1, GOB.COLS * GOB.LIGNES do
  local col, ligne = (i - 1) % GOB.COLS, math.floor((i - 1) / GOB.COLS)
  local c = CreateFrame("Frame", nil, cadreGobs.devant)
  c:SetSize(GOB.CW, GOB.CH)
  c:SetPoint("TOPLEFT", cadreGobs, "TOPLEFT", 30 + col * (GOB.CW + 8), -62 - ligne * (GOB.CH + 10))
  c.fond = c:CreateTexture(nil, "BACKGROUND")
  c.fond:SetAllPoints()
  c.fond:SetColorTexture(0.035, 0.030, 0.023, 1)
  Filet(c, 0.55)
  local ok, scene = pcall(CreateFrame, "ModelScene", nil, c, "ModelSceneMixinTemplate")
  if ok and scene then
    scene:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
    scene:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 44)
    local acteur = scene:CreateActor(nil, "ModelSceneActorTemplate")
    acteur.onModelLoadedCallback = ApercuCharge
    acteur:SetUseCenterForOrigin(true, true, true)
    scene:SetCameraNearClip(0.01)
    scene:SetCameraFarClip(2 ^ 64)
    scene.Camera = scene:CreateCameraFromScene(114)
    if scene.Camera then
      scene.Camera:SetPitch(0)
      if scene.Camera.SetLeftMouseButtonYMode then
        scene.Camera:SetRightMouseButtonXMode(ORBIT_CAMERA_MOUSE_PAN_HORIZONTAL, true)
        scene.Camera:SetRightMouseButtonYMode(ORBIT_CAMERA_MOUSE_PAN_VERTICAL, true)
        scene.Camera:SetLeftMouseButtonYMode(ORBIT_CAMERA_MOUSE_MODE_PITCH_ROTATION, true)
      end
    end
    c.scene, c.acteur = scene, acteur
  end
  c.nom = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.nom:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 6, 28)
  c.nom:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -6, 28)
  c.nom:SetJustifyH("CENTER")
  c.nom:SetWordWrap(false)
  c.nom:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
  c.choisir = BoutonAel(c, 96, 20, "Choisir")
  c.choisir:SetPoint("BOTTOM", c, "BOTTOM", 0, 5)
  c.choisir:SetScript("OnClick", function()
    local r = c.resultat
    if not r then return end
    GOB.n = (GOB.n % 99999) + 1
    local nom = Couper(r.nom ~= "" and r.nom or tostring(r.displayid), 31)
    gobCapture = { point = ("gobchoix:%d:%d"):format(GOB.n, r.displayid), guid = nom, depuis = GetTime() }
    GOB.choisi = r.fileid
    Msg("objet choisi : " .. r.nom .. " (" .. r.displayid .. ").")
    AfficherGobs()
  end)
  GOB.cases[i] = c
end
cadreGobs.precedent = BoutonAel(cadreGobs.devant, 90, 22, "‹ Précédent")
cadreGobs.precedent:SetPoint("BOTTOMLEFT", cadreGobs, "BOTTOMLEFT", 30, 18)
cadreGobs.suivant = BoutonAel(cadreGobs.devant, 90, 22, "Suivant ›")
cadreGobs.suivant:SetPoint("BOTTOMRIGHT", cadreGobs, "BOTTOMRIGHT", -30, 18)
cadreGobs.pages = cadreGobs.devant:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cadreGobs.pages:SetPoint("BOTTOM", cadreGobs, "BOTTOM", 0, 24)
cadreGobs.pages:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
cadreGobs.vide = cadreGobs.devant:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cadreGobs.vide:SetPoint("CENTER", cadreGobs, "CENTER", 0, 0)
cadreGobs.vide:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])

local function PagesGobs() return math.max(1, math.ceil(#GOB.resultats / (GOB.COLS * GOB.LIGNES))) end
AfficherGobs = function()
  local parPage = GOB.COLS * GOB.LIGNES
  GOB.page = math.max(1, math.min(GOB.page, PagesGobs()))
  cadreGobs.titre:SetText(TR.Majuscules("Objets du monde · " .. GOB.recherche))
  for i, c in ipairs(GOB.cases) do
    local r = GOB.resultats[(GOB.page - 1) * parPage + i]
    c.resultat = r
    if r then
      c:Show()
      c.nom:SetText(r.nom)
      c.choisir.label:SetText(GOB.choisi == r.fileid and "Choisi" or "Choisir")
      -- Seule la page visible charge ses modeles (Epsilon_Viewer fait de meme).
      if c.acteur and c.charge ~= r.fileid then
        c.charge = r.fileid
        pcall(c.acteur.SetModelByFileID, c.acteur, r.fileid)
      end
    else
      c:Hide()
    end
  end
  cadreGobs.pages:SetText(#GOB.resultats > 0 and ("Page %d / %d · %d objet(s)"):format(GOB.page, PagesGobs(), #GOB.resultats) or "")
  cadreGobs.precedent:SetShown(GOB.page > 1)
  cadreGobs.suivant:SetShown(GOB.page < PagesGobs())
end
cadreGobs.precedent:SetScript("OnClick", function() GOB.page = GOB.page - 1; AfficherGobs() end)
cadreGobs.suivant:SetScript("OnClick", function() GOB.page = GOB.page + 1; AfficherGobs() end)

local function Gobs(reste)
  local mot, texte = (reste or ""):match("^(%S+)%s*(.-)%s*$")
  mot = (mot or ""):lower()
  if mot == "fermer" then cadreGobs:Hide() return end
  if mot ~= "chercher" then return end
  local etat = GobsChercher(texte or "")
  GOB.choisi = nil
  cadreGobs.vide:SetText(etat == "sans" and "Le catalogue d'Epsilon (C_Epsilon.GODI) est absent de ce client."
    or etat == "court" and "Deux lettres au moins pour chercher."
    or #GOB.resultats == 0 and "Aucun objet ne répond à cette recherche." or "")
  AfficherGobs()
  cadreGobs:Show()
  cadreGobs:Raise()
end

-- Le spawn de l'objet d'un point pose par le MJ : son GUID repart comme
-- celui d'un sac (trame de genre 4), le point garde l'identifiant de la pose.
local function PoseGob(reste)
  local point, entree = (reste or ""):match("^([%w_%-]+)%s+(%-?%d+)$")
  if not point or #point > 47 then return end
  gobEnAttente = { point = point, entree = entree, depuis = GetTime(), souple = true }
  gobCapture = nil
  Envoyer(".gob spawn " .. entree, "SAY")
end

-- L'objet d'un point peut aussi etre un blueprint (14 novembre 2026) :
--   posebp <point> <id ou nom>   « .gob blueprint spawn », GUID du groupe capte
--   supbp <guid>                 selectionne le groupe de ce GUID, puis
--                                « .gob group delete » SEULEMENT si le serveur
--                                confirme la selection (sinon il supprimerait
--                                le groupe deja selectionne)
local function PoseBlueprint(reste)
  local point, plan = (reste or ""):match("^([%w_%-]+)%s+([%w_%-]+)$")
  if not point or #point > 47 or #plan > 40 then return end
  gobEnAttente = { point = point, blueprint = true, depuis = GetTime() }
  gobCapture = nil
  Envoyer(".gob blueprint spawn " .. plan, "SAY")
end

local suppressionGroupe
local guetteurGroupe = CreateFrame("Frame")
local function LireSelectionGroupe(message)
  if not suppressionGroupe or type(message) ~= "string" then return end
  if GetTime() - suppressionGroupe.depuis > 8 then suppressionGroupe = nil; return end
  local nu = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
  if nu:find("Selected gameobject group", 1, true) then
    suppressionGroupe = nil
    Envoyer(".gob group delete", "SAY")
  end
end
guetteurGroupe:RegisterEvent("CHAT_MSG_SYSTEM")
guetteurGroupe:SetScript("OnEvent", function(_, _, message) LireSelectionGroupe(message) end)
for i = 1, (NUM_CHAT_WINDOWS or 10) do
  local fenetre = _G["ChatFrame" .. i]
  if fenetre and fenetre.AddMessage then
    hooksecurefunc(fenetre, "AddMessage", function(_, texte) LireSelectionGroupe(texte) end)
  end
end
local function SupprimeBlueprint(reste)
  local guid = (reste or ""):match("^(%d+)$")
  if not guid or #guid > 20 then return end
  suppressionGroupe = { guid = guid, depuis = GetTime() }
  Envoyer(".gob group select " .. guid, "SAY")
end

-- ===== Les apparences d'objets (forge et inventaire, 14 novembre 2026) =====
-- La forge d'armes / d'armures choisit l'item WoW d'une entree (les modules
-- MogIt_Epsilon_*, extraits dans l'overlay : public/lcm/mogit). L'overlay
-- tient la liste et l'envoie par morceaux ; ici, une grille qui DEFILE
-- (molette, barre) sur un nombre fixe de cases : seules les lignes visibles
-- portent un modele (DressUpModel, comme MogIt).
--   mog ouvrir <total> <titre>
--   mog ids <debut> <id,id,...>     les items a partir du rang <debut>
--   mog fermer
-- Retours par la trame de genre 4 :
--   point = « mogchoix:<n>:<itemID> », guid = le nom (31 octets au plus)
--   point = « mogplus:<n>:<deja recus> »   la suite, quand on approche du bas
local MOG = { COLS = 4, LIGNES = 2, L = 720, H = 540, CW = 156, CH = 206,
  ids = {}, total = 0, haut = 0, titre = "", demande = 0, n = math.floor(GetTime()) % 10000 }
local function NomItem(id)
  local nom = GetItemInfo and GetItemInfo(id)
  if not nom and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return nom
end
local function CaptureMog(point, guid)
  MOG.n = (MOG.n % 99999) + 1
  gobCapture = { point = point:format(MOG.n), guid = guid or "", depuis = GetTime() }
end
local function LignesMog() return math.max(0, math.ceil(MOG.total / MOG.COLS) - MOG.LIGNES) end
-- L'infobulle d'une case, comme MogIt : l'item affiche [emplacement], puis
-- « Items using this appearance » avec un ▸ devant celui qu'on voit.
local function BulleMog(c)
  local items = c.items
  if not items then return end
  GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
  local function Ligne(id)
    local nom, _, _, _, _, _, _, _, place = GetItemInfo(id)
    local emplacement = place and place ~= "" and _G[place] or nil
    return (nom or ("item " .. id)) .. (emplacement and (" [" .. emplacement .. "]") or "")
  end
  GameTooltip:AddLine(Ligne(c.item), 1, 1, 1)
  if #items > 1 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Items utilisant cette apparence :", 1, 0.82, 0)
    for i, id in ipairs(items) do
      GameTooltip:AddLine((i == c.rang and "|cffffd100▸|r " or "   ") .. Ligne(id), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Clic : item suivant de cette apparence.", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

local cadreMog = CreateFrame("Frame", "LCMCapteurMog", UIParent)
cadreMog:SetSize(MOG.L, MOG.H)
cadreMog:SetPoint("CENTER", UIParent, "CENTER", -200, 30)
cadreMog:SetFrameStrata("DIALOG")
cadreMog:SetClampedToScreen(true)
cadreMog:SetMovable(true)
cadreMog:EnableMouse(true)
cadreMog:EnableMouseWheel(true)
cadreMog:RegisterForDrag("LeftButton")
cadreMog:Hide()
cadreMog:SetScript("OnDragStart", function(self) self:StartMoving() end)
cadreMog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
do
  local decor = HabillerAel(cadreMog, MOG.L)
  cadreMog.fermer:SetScript("OnClick", function() cadreMog:Hide() end)
  cadreMog.devant = CreateFrame("Frame", nil, cadreMog)
  cadreMog.devant:SetAllPoints()
  cadreMog.devant:SetFrameLevel(decor:GetFrameLevel() + 2)
  cadreMog.titre = cadreMog.devant:CreateFontString(nil, "OVERLAY")
  cadreMog.titre:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  cadreMog.titre:SetTextColor(TR.TITRE[1], TR.TITRE[2], TR.TITRE[3])
  cadreMog.titre:SetPoint("TOPLEFT", cadreMog, "TOPLEFT", 40, -14)
  cadreMog.titre:SetPoint("TOPRIGHT", cadreMog, "TOPRIGHT", -40, -14)
  cadreMog.titre:SetJustifyH("LEFT")
  cadreMog.titre:SetWordWrap(false)
  cadreMog.aide = cadreMog.devant:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cadreMog.aide:SetPoint("TOPLEFT", cadreMog, "TOPLEFT", 30, -40)
  cadreMog.aide:SetPoint("TOPRIGHT", cadreMog, "TOPRIGHT", -30, -40)
  cadreMog.aide:SetJustifyH("LEFT")
  cadreMog.aide:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
  cadreMog.aide:SetText("Modèles : clic gauche glissé tourner, clic droit glissé déplacer, molette zoom (toutes les cases) · ailleurs, la molette défile.")
end

-- Habiller un modele : seulement une fois le personnage charge, sinon
-- Undress / TryOn sont ignores et l'on voit sa tenue (constate en jeu).
local PositionnerMog, PositionnerTous
local function HabillerModele(m)
  if not m.item then return end
  pcall(m.Undress, m)
  pcall(m.TryOn, m, "item:" .. m.item)
  if m.SetSheathed then pcall(m.SetSheathed, m, false) end
  PositionnerMog(m)
end

local AfficherMog
MOG.cases = {}
-- La vue partagee : SetPosition(profondeur, horizontal, vertical) et SetFacing.
MOG.vue = { face = 0, z = 0, x = 0, y = 0 }
PositionnerMog = function(m)
  if not m then return end
  pcall(m.SetPosition, m, MOG.vue.z, MOG.vue.x, MOG.vue.y)
  pcall(m.SetFacing, m, MOG.vue.face)
end
PositionnerTous = function()
  for _, c in ipairs(MOG.cases) do if c.modele and c.modele:IsShown() then PositionnerMog(c.modele) end end
end
for i = 1, MOG.COLS * MOG.LIGNES do
  local col, ligne = (i - 1) % MOG.COLS, math.floor((i - 1) / MOG.COLS)
  local c = CreateFrame("Frame", nil, cadreMog.devant)
  c:SetSize(MOG.CW, MOG.CH)
  c:SetPoint("TOPLEFT", cadreMog, "TOPLEFT", 30 + col * (MOG.CW + 8), -62 - ligne * (MOG.CH + 10))
  c.fond = c:CreateTexture(nil, "BACKGROUND")
  c.fond:SetAllPoints()
  c.fond:SetColorTexture(0.035, 0.030, 0.023, 1)
  Filet(c, 0.55)
  local ok, m = pcall(CreateFrame, "DressUpModel", nil, c)
  if ok and m then
    m:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
    m:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 44)
    m:EnableMouse(true)
    -- Comme MogIt (Core/GUI.lua, modelUpdater) : clic gauche glisse =
    -- tourner, clic droit glisse = deplacer le corps, molette = zoom. La vue
    -- est UNE pour toutes les cases (MOG.vue) : ce qu'on fait sur l'une, on
    -- le voit sur toutes.
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(_, sens)
      MOG.vue.z = math.max(-2, math.min(6, MOG.vue.z + sens * 0.4))
      PositionnerTous()
    end)
    m:SetScript("OnMouseDown", function(self, bouton)
      self.bouton = bouton
      self.px, self.py = GetCursorPosition()
      self.dx0, self.bouge = self.px, false
    end)
    -- Un clic gauche sans glisser passe a l'item suivant de l'apparence (MogIt).
    m:SetScript("OnMouseUp", function(self, bouton)
      self.bouton = nil
      if bouton ~= "LeftButton" or self.bouge or not c.items or #c.items < 2 then return end
      c.rang = c.rang % #c.items + 1
      c.item = c.items[c.rang]
      c.nom:SetText((NomItem(c.item) or ("item " .. c.item)) .. "  (" .. #c.items .. ")")
      c.choisir.label:SetText(MOG.choisi == c.item and "Choisi" or "Choisir")
      if GameTooltip:GetOwner() == c then BulleMog(c) end
    end)
    m:SetScript("OnEnter", function() BulleMog(c) end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:SetScript("OnUpdate", function(self)
      if not self.bouton then return end
      local cx, cy = GetCursorPosition()
      local dx, dy = (cx - self.px) / 50, (cy - self.py) / 50
      self.px, self.py = cx, cy
      if math.abs(cx - (self.dx0 or cx)) > 3 then self.bouge = true end
      if self.bouton == "LeftButton" then
        MOG.vue.face = MOG.vue.face + dx
      elseif self.bouton == "RightButton" then
        self.bouge = true
        MOG.vue.x, MOG.vue.y = MOG.vue.x + dx, MOG.vue.y + dy
      end
      PositionnerTous()
    end)
    -- Le personnage pose sur le modele vient d'etre charge : on l'habille.
    pcall(m.SetScript, m, "OnModelLoaded", HabillerModele)
    c.modele = m
  end
  c.nom = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.nom:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 6, 28)
  c.nom:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -6, 28)
  c.nom:SetJustifyH("CENTER")
  c.nom:SetWordWrap(false)
  c.nom:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])
  c.choisir = BoutonAel(c, 96, 20, "Choisir")
  c.choisir:SetPoint("BOTTOM", c, "BOTTOM", 0, 5)
  c.choisir:SetScript("OnClick", function()
    local id = c.item
    if not id then return end
    local nom = NomItem(id) or tostring(id)
    CaptureMog("mogchoix:%d:" .. id, Couper(nom, 31))
    MOG.choisi = id
    Msg("apparence choisie : " .. nom .. " (" .. id .. ").")
    AfficherMog()
  end)
  MOG.cases[i] = c
end

-- La barre de defilement, a droite de la grille.
cadreMog.barre = CreateFrame("Slider", nil, cadreMog.devant)
cadreMog.barre:SetOrientation("VERTICAL")
cadreMog.barre:SetPoint("TOPLEFT", cadreMog, "TOPLEFT", 30 + MOG.COLS * (MOG.CW + 8) + 2, -62)
cadreMog.barre:SetSize(12, MOG.LIGNES * (MOG.CH + 10) - 10)
cadreMog.barre.fond = cadreMog.barre:CreateTexture(nil, "BACKGROUND")
cadreMog.barre.fond:SetAllPoints()
cadreMog.barre.fond:SetColorTexture(0.035, 0.030, 0.023, 1)
Filet(cadreMog.barre, 0.55)
cadreMog.barre:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
cadreMog.barre:GetThumbTexture():SetSize(10, 36)
cadreMog.barre:GetThumbTexture():SetVertexColor(TR.OR_TERNI[1], TR.OR_TERNI[2], TR.OR_TERNI[3], 1)
cadreMog.barre:SetValueStep(1)
cadreMog.barre:SetObeyStepOnDrag(true)
cadreMog.barre:SetMinMaxValues(0, 0)
cadreMog.barre:SetScript("OnValueChanged", function(_, v)
  v = math.floor(v + 0.5)
  if v ~= MOG.haut then MOG.haut = v; AfficherMog() end
end)
cadreMog:SetScript("OnMouseWheel", function(_, sens)
  local v = math.max(0, math.min(LignesMog(), MOG.haut - sens))
  cadreMog.barre:SetValue(v)
end)
cadreMog.compte = cadreMog.devant:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cadreMog.compte:SetPoint("BOTTOM", cadreMog, "BOTTOM", 0, 24)
cadreMog.compte:SetTextColor(TR.TEXTE[1], TR.TEXTE[2], TR.TEXTE[3])

AfficherMog = function()
  cadreMog.titre:SetText(TR.Majuscules("Apparences · " .. MOG.titre))
  local premier = MOG.haut * MOG.COLS
  for i, c in ipairs(MOG.cases) do
    local rang = premier + i
    local items = rang <= MOG.total and MOG.ids[rang] or nil
    if c.items ~= items then c.items, c.rang = items, 1 end
    local id = items and items[c.rang] or nil
    c.item = id
    if rang > MOG.total then
      c:Hide()
    else
      c:Show()
      c.nom:SetText(id and ((NomItem(id) or ("item " .. id)) .. (#items > 1 and ("  (" .. #items .. ")") or "")) or "…")
      c.choisir:SetShown(id ~= nil)
      c.choisir.label:SetText(MOG.choisi == id and "Choisi" or "Choisir")
      local m = c.modele
      if m then
        m:SetShown(id ~= nil)
        if id and m.item ~= id then
          m.item = id
          if not m.pret then m.pret = pcall(m.SetUnit, m, "player") end
          HabillerModele(m)
          -- Si le modele etait deja charge, OnModelLoaded ne revient pas.
          C_Timer.After(0.15, function() if m.item == id then HabillerModele(m) end end)
        end
      end
    end
  end
  local vus = math.min(MOG.total, premier + MOG.COLS * MOG.LIGNES)
  cadreMog.compte:SetText(MOG.total > 0 and ("%d – %d sur %d apparences"):format(premier + 1, vus, MOG.total) or "")
  -- La suite : quand ce qu'on regarde approche de ce qui est arrive.
  local recus = #MOG.ids
  if recus < MOG.total and vus + MOG.COLS * 4 > recus and MOG.demande ~= recus then
    MOG.demande = recus
    CaptureMog("mogplus:%d:" .. recus)
  end
end
-- Les noms arrivent du serveur apres coup.
cadreMog:RegisterEvent("GET_ITEM_INFO_RECEIVED")
cadreMog:SetScript("OnEvent", function()
  if not cadreMog:IsShown() then return end
  for _, c in ipairs(MOG.cases) do
    if c.item then
      c.nom:SetText((NomItem(c.item) or ("item " .. c.item)) .. (#c.items > 1 and ("  (" .. #c.items .. ")") or ""))
    end
  end
end)

local function Mog(reste)
  local mot, suite = (reste or ""):match("^(%S+)%s*(.-)%s*$")
  if mot == "fermer" then cadreMog:Hide() return end
  if mot == "ouvrir" then
    local total, titre = (suite or ""):match("^(%d+)%s*(.*)$")
    if not total then return end
    MOG.total, MOG.titre, MOG.ids, MOG.haut, MOG.demande, MOG.choisi = tonumber(total), titre or "", {}, 0, 0, nil
    cadreMog.barre:SetMinMaxValues(0, LignesMog())
    cadreMog.barre:SetValue(0)
    for _, c in ipairs(MOG.cases) do if c.modele then c.modele.item = nil end end
    AfficherMog()
    cadreMog:Show()
    cadreMog:Raise()
  elseif mot == "ids" then
    -- Une apparence par « , », ses items separes par « . ».
    local debut, liste = (suite or ""):match("^(%d+)%s+([%d,%.]+)$")
    if not debut then return end
    local rang = tonumber(debut)
    for groupe in liste:gmatch("[^,]+") do
      local items = {}
      for id in groupe:gmatch("%d+") do items[#items + 1] = tonumber(id) end
      if rang <= MOG.total and items[1] then MOG.ids[rang] = items end
      rang = rang + 1
    end
    if cadreMog:IsShown() then AfficherMog() end
  end
end

-- ===== Les objets LCM portes par le personnage WoW ========================
-- L'overlay envoie, a chaque changement de la fiche, les items WoW qu'elle
-- porte (sacs + equipement) : combien, et combien sont equipes.
--   mogsync <signature> <i>/<k> <itemID>:<nombre>:<equipes> ...
-- k morceaux, tous de la meme signature : rien n'est applique tant qu'il en
-- manque un (un morceau perdu ne doit jamais se lire « plus rien »). Une
-- fois applique, l'accuse « mogok:<signature> » repart par la trame 4 ;
-- sans lui, l'overlay renvoie (le lecteur jette un ordre quand WoW n'est pas
-- au premier plan, par exemple pendant un geste du Panel MJ).
-- On ne touche qu'a ce que LCM a donne (db.mogGeres, par personnage WoW) :
-- « .add <id> <n> » pour ajouter, « .add <id> -<n> » pour retirer, puis
-- equiper (EquipItemByName) ce qui est equipe dans LCM, et ranger dans un
-- sac ce qui ne l'est plus.
local function ClePersoWow() return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?") end
local function Geres()
  db.mogGeres = db.mogGeres or {}
  local cle = ClePersoWow()
  db.mogGeres[cle] = db.mogGeres[cle] or {}
  return db.mogGeres[cle]
end
local function Equipe(id)
  local f = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
  return f and f(id) or false
end
local function Nombre(id) return (GetItemCount and GetItemCount(id)) or 0 end
local function PlacesLibres(sac)
  local f = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  return f and (f(sac)) or 0
end
-- Retirer un item porte : on le prend sur le personnage et on le pose dans
-- le premier sac qui a une place (sinon il reste porte).
local function Desequiper(id)
  if InCombatLockdown() then return false end
  for emplacement = 1, 19 do
    if GetInventoryItemID("player", emplacement) == id then
      ClearCursor()
      PickupInventoryItem(emplacement)
      if not CursorHasItem() then return false end
      for sac = 0, 4 do
        if PlacesLibres(sac) > 0 then
          if sac == 0 then PutItemInBackpack()
          else
            local inv = (C_Container and C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID)(sac)
            PutItemInBag(inv)
          end
          return true
        end
      end
      ClearCursor()
      return false
    end
  end
  return false
end

local MOGSYNC = { parts = {} }
-- Le journal de la synchro, garde dans la sauvegarde (40 lignes) : ce qui
-- arrive, ce qui est compte, ce qui part. Pour comprendre un item « passe a
-- travers » sans deviner.
local function Journal(texte)
  if not db then return end
  db.mogJournal = db.mogJournal or {}
  table.insert(db.mogJournal, date("%H:%M:%S") .. " " .. texte)
  while #db.mogJournal > 40 do table.remove(db.mogJournal, 1) end
end
-- tonumber(x, 36) de WoW plafonne a 2^32 - 1 : on convertit a la main.
local function Base36(t)
  local n = 0
  for c in t:lower():gmatch(".") do
    local v = tonumber(c, 36)
    if not v then return nil end
    n = n * 36 + v
  end
  return n
end
-- Ce que le personnage POSSEDE vraiment de cet item : sacs 0..4 et objets
-- portes, comptes un par un (GetItemCount compte-t-il ce qui est porte ?
-- selon les versions : on ne s'y fie pas).
local function Possede(id)
  local n = 0
  local nbCases = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local idCase = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  local infoCase = (C_Container and C_Container.GetContainerItemInfo) or GetContainerItemInfo
  for sac = 0, 4 do
    for c = 1, (nbCases and nbCases(sac) or 0) do
      if idCase(sac, c) == id then
        local i, q = infoCase(sac, c)
        n = n + ((type(i) == "table" and i.stackCount) or q or 1)
      end
    end
  end
  for e = 1, 19 do if GetInventoryItemID("player", e) == id then n = n + 1 end end
  return n
end

-- Executer ce que LCM ordonne. Pas de surveillance en boucle : a l'ordre,
-- on agit tout de suite ; 3 s plus tard on verifie (et on refait ce qui
-- manque, quantite comme equipement) ; puis une seconde verification. Deux
-- verifications bonnes de suite : c'est en place, on s'arrete. Au plus 6.
-- La cible d'un item = ce que la fiche porte + ce que le joueur avait a lui
-- (g.perso) : ses items personnels ne sont jamais touches.
-- Ajuster rend vrai quand tout etait deja en place (rien a faire).
local function Ajuster()
  if InCombatLockdown() or not db then return false end
  local enPlace = true
  local geres = Geres()
  for id, g in pairs(geres) do
    -- 1. ranger ce qui ne doit plus etre porte (avant de le retirer)
    if (g.e or 0) == 0 and Equipe(id) then enPlace = false; Desequiper(id) end
    -- 2. la quantite (pas deux fois de suite en moins de 2 s : le serveur
    --    n'a peut-etre pas encore repondu)
    local possede, cible = Possede(id), g.n + (g.perso or 0)
    if possede ~= cible then
      enPlace = false
      if not g.t or time() - g.t >= 2 then
        local delta = cible - possede
        Journal(("item %d : possede %d, fiche %d -> .add %d"):format(id, possede, cible, delta))
        Envoyer((".add %d %d"):format(id, delta), "SAY")
        Msg(("apparences : %s %s (item %d)."):format(delta > 0 and ("+" .. delta) or tostring(delta), NomItem(id) or "", id))
        g.t = time()
      end
    elseif g.n == 0 and not Equipe(id) then
      geres[id] = nil                                -- retire, c'est fini
    end
    -- 3. equiper ce que LCM equipe
    if g.n > 0 and (g.e or 0) > 0 and not Equipe(id) then
      enPlace = false
      if Nombre(id) > 0 then pcall(EquipItemByName, id) end
    end
  end
  return enPlace
end
local ordreEquipement = 0
local function Verifier(ordre, bonnes, essais)
  if ordre ~= ordreEquipement then return end      -- un ordre plus recent a pris la main
  if Ajuster() then bonnes = bonnes + 1 else bonnes = 0 end
  if bonnes >= 2 or essais >= 6 then
    if bonnes < 2 then Msg("apparences : pas pu tout mettre en place (combat ? sacs pleins ?).") end
    return
  end
  C_Timer.After(3, function() Verifier(ordre, bonnes, essais + 1) end)
end
local function Ordonner()
  ordreEquipement = ordreEquipement + 1
  local ordre = ordreEquipement
  Ajuster()
  C_Timer.After(3, function() Verifier(ordre, 0, 1) end)
end

local function Reconcilier(voulu)
  local geres = Geres()
  local resume = {}
  for id, v in pairs(voulu) do resume[#resume + 1] = id .. "x" .. v.n end
  Journal("applique : " .. (#resume > 0 and table.concat(resume, " ") or "rien sur la fiche"))
  local ids = {}
  for id in pairs(voulu) do ids[id] = true end
  for id in pairs(geres) do ids[id] = true end
  for id in pairs(ids) do
    local v = voulu[id] or { n = 0, e = 0 }
    local g = geres[id]
    -- MIROIR EXACT (le MJ, 14 novembre 2026) : un item que LCM gere, le
    -- personnage en a autant que la fiche, ni plus ni moins. « Garder ce que
    -- le joueur avait a lui » laissait passer les doublons d'avant (3 casques,
    -- 1 seul retire). Un item jamais passe par une fiche n'est pas touche.
    geres[id] = { n = v.n, e = v.e, perso = 0, t = g and g.t }
  end
  Ordonner()
end

-- Au chargement (/reload, connexion), le capteur ne sait pas ce que porte
-- la fiche : il le DEMANDE a l'overlay (« mogdemande:<n> » par la trame 4),
-- qui renvoie son ordre. Sans cela, rien ne bougeait jusqu'au prochain geste.
do
  local demande = CreateFrame("Frame")
  demande:RegisterEvent("PLAYER_ENTERING_WORLD")
  demande:SetScript("OnEvent", function()
    C_Timer.After(2, function()
      gobCapture = { point = "mogdemande:" .. math.random(1, 999999), guid = "", depuis = GetTime() }
    end)
  end)
end

local function MogSync(reste)
  local sig, i, k, suite = (reste or ""):match("^(%w+)%s+(%d+)/(%d+)%s*(.-)%s*$")
  i, k = tonumber(i), tonumber(k)
  if not sig or not i or not k or k < 1 or k > 20 or i < 1 or i > k then return end
  -- La signature est l'heure de l'ordre (base 36) : un ordre PLUS ANCIEN que
  -- le dernier applique (reste en file pendant que WoW etait derriere) est
  -- ignore, sinon il redonnerait un objet qui n'est plus sur la fiche.
  local numero = Base36(sig)
  if numero and db and db.mogNumero == 4294967295 then db.mogNumero = nil end   -- l'ancien plafond
  if not numero or (db and db.mogNumero and numero < db.mogNumero) then
    Journal(("ordre %s %d/%d IGNORE (plus ancien que %s)"):format(sig, i, k, tostring(db and db.mogNumero)))
    return
  end
  Journal(("ordre %s %d/%d : %s"):format(sig, i, k, (suite or ""):sub(1, 120)))
  local p = MOGSYNC.parts
  if p.sig ~= sig then MOGSYNC.parts = { sig = sig, k = k, recus = {} }; p = MOGSYNC.parts end
  p.recus[i] = suite or ""
  for j = 1, k do if not p.recus[j] then return end end
  local voulu = {}
  for j = 1, k do
    for tid, tn, te in p.recus[j]:gmatch("(%d+):(%d+):(%d+)") do
      local id, n, e = tonumber(tid), tonumber(tn), tonumber(te)
      if id and n and n > 0 and n <= 200 then voulu[id] = { n = n, e = math.min(e or 0, n) } end
    end
  end
  MOGSYNC.parts = {}
  if not db then return end
  -- Toujours appliquer, meme un renvoi : la comparaison se fait avec ce que
  -- le personnage possede VRAIMENT, un ordre repete ne change rien s'il est
  -- deja en place, et remet d'aplomb ce qui a derive (objet detruit dans WoW,
  -- ordre perdu...).
  Reconcilier(voulu)
  db.mogSig = nil
  db.mogNumero = math.max(db.mogNumero or 0, numero)
  gobCapture = { point = "mogok:" .. sig, guid = "", depuis = GetTime() }
end

-- ===== La touche de la carte (M) ==========================================
-- Comme l'addon (UI/Crossings/Carte.lua, BindMapKey) : quand l'overlay le
-- demande, la touche de la carte du monde ouvre la carte des Lieux. Le
-- capteur ne fait que compter les appuis (octet « appel » de la trame) ;
-- l'overlay ouvre sa fenetre en voyant le compte changer.
local boutonCarte = CreateFrame("Button", "LCMCapteurCarte", UIParent)
boutonCarte:RegisterForClicks("AnyUp")
boutonCarte:SetScript("OnClick", function()
  -- Si le combat retarde ClearOverrideBindings après la fermeture, M doit
  -- tout de même ouvrir immédiatement la carte normale de WoW.
  if overlayParti then
    if ToggleWorldMap then ToggleWorldMap() end
  else
    appelCarte = (appelCarte + 1) % 16
  end
end)
-- Proprietaire a part, comme l'addon (Carte.lua, Bind) : la surcharge est
-- PRIORITAIRE, sinon une autre surcharge de la touche passe devant.
local lieurCarte = CreateFrame("Frame")
local carteVoulue, carteEnAttente = false, false
local function LierCarte()
  if InCombatLockdown and InCombatLockdown() then carteEnAttente = true return end
  carteEnAttente = false
  ClearOverrideBindings(lieurCarte)
  carteLiee = false
  if not carteVoulue then return end
  -- Sans touche reglee pour la carte du monde, M (celle de Blizzard).
  local touches = { GetBindingKey("TOGGLEWORLDMAP") }
  if #touches == 0 then touches = { "M" } end
  for _, touche in ipairs(touches) do
    SetOverrideBindingClick(lieurCarte, true, touche, "LCMCapteurCarte")
  end
  carteLiee = true
end
local function Carte(reste)
  local mot = reste:match("^(%S+)")
  -- La consigne recue (bit 128 de la trame), meme si le combat retarde la pose.
  if mot == "on" or mot == "off" then carteVoulue = mot == "on"; LierCarte()
  elseif mot == "jeu" and ToggleWorldMap then ToggleWorldMap() end
end

-- ===== Les raccourcis clavier (UI/Raccourcis.lua) ==========================
-- I ouvre l'inventaire, Maj + C la fiche et l'equipement ensemble, et les
-- touches natives qui ouvrent UN sac de WoW ne font plus rien (« Ouvrir tous
-- les sacs », B, reste a WoW). Par des SURCHARGES, comme l'addon : elles se
-- posent par-dessus les raccourcis du joueur sans les reecrire. Le capteur
-- compte les appuis (dernier octet de la trame) ; l'overlay ouvre ses
-- fenetres en voyant le compte changer.
local TOUCHE_INVENTAIRE, TOUCHE_PERSONNAGE = "I", "SHIFT-C"
local SACS_NATIFS = { "TOGGLEBACKPACK", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3", "TOGGLEBAG4", "TOGGLEBAG5" }
local boutonInventaire = CreateFrame("Button", "LCMCapteurInventaire", UIParent)
boutonInventaire:RegisterForClicks("AnyUp")
boutonInventaire:SetScript("OnClick", function() appelInventaire = (appelInventaire + 1) % 4 end)
local boutonPersonnage = CreateFrame("Button", "LCMCapteurPersonnage", UIParent)
boutonPersonnage:RegisterForClicks("AnyUp")
boutonPersonnage:SetScript("OnClick", function() appelPersonnage = (appelPersonnage + 1) % 4 end)
-- Une touche neutralisee clique ce bouton, qui ne fait rien.
local boutonMuet = CreateFrame("Button", "LCMCapteurMuet", UIParent)
boutonMuet:Hide()
local lieurTouches = CreateFrame("Frame")
local touchesVoulues, touchesEnAttente = false, false
local function LierTouches()
  -- Une surcharge est un geste protege : en combat, on attend la fin.
  if InCombatLockdown and InCombatLockdown() then touchesEnAttente = true return end
  touchesEnAttente = false
  ClearOverrideBindings(lieurTouches)
  touchesLiees = false
  if not touchesVoulues then return end
  for _, action in ipairs(SACS_NATIFS) do
    for _, touche in ipairs({ GetBindingKey(action) }) do
      if touche ~= TOUCHE_INVENTAIRE and touche ~= TOUCHE_PERSONNAGE then
        SetOverrideBindingClick(lieurTouches, false, touche, "LCMCapteurMuet")
      end
    end
  end
  SetOverrideBindingClick(lieurTouches, false, TOUCHE_INVENTAIRE, "LCMCapteurInventaire")
  SetOverrideBindingClick(lieurTouches, false, TOUCHE_PERSONNAGE, "LCMCapteurPersonnage")
  touchesLiees = true
end
local function Touches(reste)
  local mot = reste:match("^(%S+)")
  if mot == "on" or mot == "off" then touchesVoulues = mot == "on"; LierTouches() end
end

-- ===== La vitesse du personnage (6 novembre 2026) ==========================
-- Le ralentissement de l'arrivee (deplacement) doit rendre la vitesse
-- D'AVANT, pas une valeur fixe. Le capteur la lit dans les reponses du
-- serveur (« … [Nom] from normal to 1.00. ») et la garde d'un /reload a
-- l'autre. Pendant un ralentissement, il ne la note pas : c'est le sien.
local vitesseAvant, ralentiDepuis = nil, nil
local function VitesseConnue() return db and tonumber(db.vitesse) end
-- Le journal de la vitesse (15 novembre 2026 : « le mod speed ne se fait
-- pas ») : ce que l'overlay demande et ce que le serveur repond, dans
-- LCMCapteurDB.vitesseJournal, les 30 dernieres lignes.
local function NoterVitesse(texte)
  if not db then return end
  db.vitesseJournal = db.vitesseJournal or {}
  local j = db.vitesseJournal
  j[#j + 1] = date("%H:%M:%S") .. " " .. tostring(texte)
  while #j > 30 do table.remove(j, 1) end
end
local guetteurVitesse = CreateFrame("Frame")
guetteurVitesse:RegisterEvent("CHAT_MSG_SYSTEM")
guetteurVitesse:SetScript("OnEvent", function(_, _, message)
  if not db or type(message) ~= "string" then return end
  local bas = message:lower()
  if bas:find("speed", 1, true) or bas:find("vitesse", 1, true) then NoterVitesse("serveur : " .. message) end
  if ralentiDepuis then return end
  local nom = UnitName("player")
  if not nom or not message:find(nom, 1, true) then return end
  -- Seulement une reponse a « .mod speed » : « from normal to 1.00 » venait
  -- aussi d'autres .mod (vol, nage, taille), d'ou une vitesse retenue de 5.
  if not (bas:find("speed", 1, true) or bas:find("vitesse", 1, true)) then return end
  if bas:find("fly", 1, true) or bas:find("swim", 1, true) or bas:find("vol", 1, true) or bas:find("nage", 1, true) then return end
  local v = tonumber(message:match("from%s+%S+%s+to%s+(%d*%.?%d+)"))
    or tonumber(message:match("to%s+(%d*%.?%d+)%.?%s*$"))
  if v and v > 0 then db.vitesse = v; NoterVitesse("vitesse retenue : " .. v) end
end)
-- Appeles depuis une touche-code (un appui materiel : le /dire d'une
-- commande serveur est permis).
local function VitessePose(v)
  if not tonumber(v) then return end
  -- Un second ralentissement avant le retour garde la vitesse d'origine.
  if not ralentiDepuis or GetTime() - ralentiDepuis > 30 then
    vitesseAvant = VitesseConnue()
  end
  ralentiDepuis = GetTime()
  NoterVitesse(("ralentir a %s (avant : %s)"):format(tostring(v), tostring(vitesseAvant)))
  Envoyer(".mod speed " .. v, "SAY")
end
local function VitesseRend(repli)
  local v = vitesseAvant or tonumber(repli)
  NoterVitesse(("rendre %s (retenue %s, repli %s)"):format(tostring(v), tostring(vitesseAvant), tostring(repli)))
  vitesseAvant, ralentiDepuis = nil, nil
  if v then Envoyer(".mod speed " .. v, "SAY") end
end

local function GesteLCM(texte)
  -- Le geste en minuscules, le RESTE tel quel : un message ou l'identifiant
  -- d'un sort garde sa casse.
  local mot, reste = texte:match("^(%S+)%s*(.-)%s*$")
  local geste, arg = (mot or ""):lower(), ((reste or ""):match("^(%S*)") or ""):lower()
  if geste == "portrait" or geste == "menu" or geste == "liberer" then NoterPortrait("ordre : " .. geste .. " " .. arg) end
  if geste == "info" then
    -- Le message local d'un lieu (LCM.Info dans l'addon) : dans le chat du joueur seul.
    DEFAULT_CHAT_FRAME:AddMessage("|cffc8a45e[ Contes ]|r - |cffe8dcc0" .. (reste or "") .. "|r")
    return
  elseif geste == "arc" then
    Arcanum(reste or "")
    return
  elseif geste == "macro" then
    -- L'action « macro » d'un sort (Core/Sorts.lua, Lancer) : comme si on
    -- l'avait tapee. Sans RunMacroText, on le dit au lieu de faire semblant.
    if type(RunMacroText) ~= "function" then Msg("ce client ne sait pas lancer une macro.") return end
    if not pcall(RunMacroText, reste or "") then Msg("la macro a été refusée.") end
    return
  elseif geste == "terrain" then
    Terrain(reste or "")
    return
  elseif geste == "carte" then
    Carte(reste or "")
    return
  elseif geste == "touches" then
    Touches(reste or "")
    return
  elseif geste == "trace" then
    Trace(reste or "")
    return
  elseif geste == "sac" then
    SacsMinicarte(reste or "")
    return
  elseif geste == "sacgob" then
    SacGob(reste or "")
    return
  elseif geste == "gobs" then
    Gobs(reste or "")
    return
  elseif geste == "posegob" then
    PoseGob(reste or "")
    return
  elseif geste == "posebp" then
    PoseBlueprint(reste or "")
    return
  elseif geste == "supbp" then
    SupprimeBlueprint(reste or "")
    return
  elseif geste == "mog" then
    Mog(reste or "")
    return
  elseif geste == "mogsync" then
    MogSync(reste or "")
    return
  end
  if geste == "fichier" then
    -- Un son du jeu donne par son chemin (theme d'un lieu : « Sound\... »).
    if PlaySoundFile and (reste or "") ~= "" then pcall(PlaySoundFile, reste, "Master") end
    return
  end
  if geste == "liberer" then
    -- La fermeture de l'overlay (main.rs, RunEvent::Exit) : le portrait de
    -- WoW revient, la touche M et le terrain sont rendus, et rien n'est garde
    -- pour la prochaine connexion. Plus aucun HUD ne le remplace.
    overlayParti = true
    portraitVoulu = false
    if db then db.portrait = nil end
    AppliquerPortrait()
    cibleVoulue = false
    AppliquerCible()
    Carte("off")
    Touches("off")
    Terrain("off")
    Trace("off")
    cadreGobs:Hide()
    return
  end
  if geste == "cible" then
    cibleVoulue = arg == "cacher"
    AppliquerCible()
    return
  end
  if geste == "portrait" then
    overlayParti = false
    portraitVoulu = arg == "cacher"
    -- Garde d'un /reload ou d'une reconnexion a l'autre (6 novembre 2026) :
    -- sans cela, le portrait revenait tant que l'overlay ne renvoyait rien.
    if db then db.portrait = portraitVoulu end
    AppliquerPortrait()
  elseif geste == "menu" then
    MenuUnite(arg)
  elseif geste == "son" then
    -- Un son du jeu (l'invitation au combat joue l'appel de raid, 8960),
    -- canal Master comme Blizzard : il passe meme les effets coupes.
    local id = tonumber(arg)
    if id and PlaySound then PlaySound(id, "Master") end
  elseif geste == "vitesse_pose" then
    VitessePose(arg)
  elseif geste == "vitesse_rend" then
    VitesseRend(arg)
  else
    Msg("geste inconnu : " .. tostring(texte))
  end
end


-- ===== Les ordres SILENCIEUX de l'overlay (6 novembre 2026) ================
-- Avant, le lecteur tapait « /lcmx … » dans la barre de chat : le joueur le
-- voyait, l'historique s'en remplissait. Maintenant une seule touche,
-- Ctrl+Maj+Inser (liee ici en surcharge prioritaire), donne le focus
-- a une zone de saisie INVISIBLE ; le lecteur y tape la ligne et Entree.
-- Le message (« id canal texte ») passe par le meme chemin que /lcmx, dans
-- l'Entree : un evenement materiel, comme une ligne validee au clavier.
-- Ni touche de fonction ordinaire, ni Alt (Alt+F4 fermait la fenetre active).
local saisieOrdres = CreateFrame("EditBox", "LCMCapteurSaisie", UIParent)
saisieOrdres:SetSize(1, 1)
saisieOrdres:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
saisieOrdres:SetAlpha(0)
saisieOrdres:SetAutoFocus(false)
saisieOrdres:SetMaxLetters(1000)
saisieOrdres:SetFontObject(ChatFontNormal or GameFontNormal)
saisieOrdres:SetScript("OnEnterPressed", function(self)
  local texte = self:GetText() or ""
  self:SetText("")
  self:ClearFocus()
  if texte ~= "" and SlashCmdList.LCMX then SlashCmdList.LCMX(texte) end
end)
saisieOrdres:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
saisieOrdres:SetScript("OnEditFocusLost", function(self) self:SetText("") end)
local boutonSaisie = CreateFrame("Button", "LCMCapteurOuvrirSaisie", UIParent)
boutonSaisie:RegisterForClicks("AnyDown")
boutonSaisie:SetScript("OnClick", function()
  saisieOrdres:SetText(""); saisieOrdres:SetFocus()
  -- Jamais de clavier tenu par une saisie invisible : sans Entree dans la
  -- seconde, elle rend le focus.
  if C_Timer and C_Timer.After then
    C_Timer.After(1, function() if saisieOrdres:HasFocus() then saisieOrdres:SetText(""); saisieOrdres:ClearFocus() end end)
  end
end)
-- ===== ESSAI : les ordres par TOUCHES-CODES (6 novembre 2026) ===============
-- Aucune saisie ne prend le focus et aucune lettre n'est tapee : le lecteur
-- presse Ctrl+Maj+A..P, chaque touche vaut un chiffre hexadecimal 0..F, liee
-- ici en surcharge prioritaire. Deux touches font un octet. Trame :
--   longueur (2 octets) · texte (UTF-8) · controle (somme des octets mod 256)
-- Une trame incomplete (pas de touche depuis 0,5 s) ou fausse est jetee.
-- Si une touche n'etait pas prise, Ctrl+Maj+lettre ne fait rien dans WoW, et
-- dans un champ de texte Ctrl n'y ecrit pas de lettre (le lecteur attend de
-- toute facon que le joueur ait fini d'ecrire, bit 64).
local CODES = "ABCDEFGHIJKLMNOP"
local codesLies = false
local codeNib, codeDebut, codeDernier = {}, 0, 0
local codeStats = { ok = 0, rate = 0, signale = 0 }
local function CodeJeter(raison)
  if #codeNib > 0 then
    codeStats.rate = codeStats.rate + 1
    Msg(("essai codes : trame jetée (%s, %d touches reçues). Réussies %d, jetées %d.")
      :format(raison, #codeNib, codeStats.ok, codeStats.rate))
  end
  codeNib = {}
end
local function CodeOctet(i) return codeNib[2 * i - 1] * 16 + codeNib[2 * i] end
local function CodeRecu(v)
  local t = GetTime()
  if #codeNib > 0 and t - codeDernier > 0.5 then CodeJeter("incomplète") end
  if #codeNib == 0 then codeDebut = t end
  codeDernier = t
  codeNib[#codeNib + 1] = v
  if #codeNib < 4 then return end
  local long = CodeOctet(1) * 256 + CodeOctet(2)
  if long < 1 or long > 1000 then CodeJeter("longueur " .. long) return end
  local attendu = 2 * (long + 3)
  if #codeNib < attendu then return end
  local octets, somme = {}, 0
  for i = 3, long + 2 do
    local o = CodeOctet(i)
    octets[#octets + 1] = string.char(o)
    somme = (somme + o) % 256
  end
  if somme ~= CodeOctet(long + 3) then CodeJeter("contrôle faux") return end
  local duree = floor((t - codeDebut) * 1000 + 0.5)
  local nb = #codeNib
  codeNib = {}
  codeStats.ok = codeStats.ok + 1
  -- Le compte rendu de l'essai : le premier ordre, puis un bilan tous les 20.
  if codeStats.ok == 1 or codeStats.ok % 20 == 0 then
    Msg(("essai codes : ordre reçu (%d octets, %d touches, %d ms). Réussis %d, jetés %d.")
      :format(long, nb, duree, codeStats.ok, codeStats.rate))
  end
  if SlashCmdList.LCMX then SlashCmdList.LCMX(table.concat(octets)) end
end
for i = 1, 16 do
  local b = CreateFrame("Button", "LCMCapteurCode" .. (i - 1), UIParent)
  b:RegisterForClicks("AnyDown")
  b:SetScript("OnClick", function() CodeRecu(i - 1) end)
end
-- Une trame interrompue est jetee meme si plus aucune touche n'arrive.
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(0.25, function()
    if #codeNib > 0 and GetTime() - codeDernier > 0.5 then CodeJeter("incomplète") end
  end)
end
CodesPrets = function() return codesLies end

local lieurOrdres = CreateFrame("Frame")
local ordresLies, ordresEnAttente = false, false
local function LierOrdres()
  if InCombatLockdown and InCombatLockdown() then ordresEnAttente = true return end
  ordresEnAttente = false
  ClearOverrideBindings(lieurOrdres)
  -- Une touche que WoW connait (F13 ne l'etait pas : l'ordre partait dans
  -- le jeu). Le lecteur ne tape rien tant que la trame ne dit pas (bit 16)
  -- que cette saisie a bien le focus.
  SetOverrideBindingClick(lieurOrdres, true, "CTRL-SHIFT-INSERT", "LCMCapteurOuvrirSaisie")
  -- L'essai des touches-codes : Ctrl+Maj+A..P = 0..F.
  for i = 1, 16 do
    SetOverrideBindingClick(lieurOrdres, true, "CTRL-SHIFT-" .. CODES:sub(i, i), "LCMCapteurCode" .. (i - 1))
  end
  codesLies = true
  ordresLies = true
end
-- Pour la trame : la saisie est prete ; le joueur ecrit ailleurs (le lecteur
-- attend alors, il n'ecrit jamais dans son texte).
SaisiePrete = function() return ordresLies end
SaisieOuverte = function()
  local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  return f ~= nil and f == saisieOrdres
end
JoueurEcrit = function()
  local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  return f ~= nil and f ~= saisieOrdres
end

SLASH_LCMX1 = "/lcmx"
SlashCmdList.LCMX = function(msg)
  local id, canal, texte = (msg or ""):match("^(%d+)%s+(%S+)%s+(.+)$")
  if not id then Msg("commande mal formée : " .. tostring(msg)); return end
  ack = tonumber(id) % 256
  canal = canal:lower()
  -- Un geste du HUD de l'overlay : rien ne part dans le chat.
  if canal == "lcm" then GesteLCM(texte) return end
  -- Un message prive (les epreuves du Panel MJ) : « chuchoter Nom texte ».
  if canal == "chuchoter" then
    local nom, message = texte:match("^(%S+)%s+(.+)$")
    if not nom then Msg("chuchotement sans destinataire."); return end
    Envoyer(message, "WHISPER", nom)
    return
  end
  local c = canal == "auto" and CanalAuto() or CANAUX[canal]
  if not c then Msg("canal inconnu : " .. canal); return end
  if (c == "PARTY" and not IsInGroup()) or (c == "RAID" and not IsInRaid()) then c = "SAY" end
  Envoyer(texte, c)
end

-- ===== Démarrage ==========================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UI_SCALE_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
  -- L'heure du depart : seul un /reload (retour dans la minute) reprend la
  -- consigne du portrait. Une reconnexion plus tard, ou un overlay ferme sans
  -- avoir pu le dire, rend le portrait de WoW ; l'overlay ouvert le recache
  -- en 3 s (il se regle sur le flag 128 de la trame).
  if event == "PLAYER_LOGOUT" then
    if db then db.quand = time() end
    return
  end
  -- Fin du combat, ou Blizzard qui reaffiche son portrait en changeant de zone.
  -- Blizzard remontre TargetFrame a chaque changement de cible.
  if event == "PLAYER_TARGET_CHANGED" then
    auras.lu = -10
    AppliquerCible()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
    AppliquerPortrait()
    AppliquerCible()
    if carteEnAttente then LierCarte() end
    if touchesEnAttente then LierTouches() end
    if ordresEnAttente or not ordresLies then LierOrdres() end
    if event == "PLAYER_REGEN_ENABLED" then return end
  end
  if event == "PLAYER_LOGIN" then
    LCMCapteurDB = LCMCapteurDB or {}
    db = LCMCapteurDB
    -- 1 px depuis la version 2 (5 novembre 2026) : la bande de 4 px se voyait
    -- trop en haut de l'ecran. Une seule fois : une taille choisie ensuite reste.
    if (db.version or 1) < 2 then db.taille = 1; db.version = 2 end
    -- Version 3 (15 novembre 2026) : la vitesse retenue venait parfois d'un
    -- autre .mod (5, 50) ; on l'oublie une fois, la prochaine .mod speed la redit.
    if db.version < 3 then db.vitesse = nil; db.version = 3 end
    db.taille = db.taille or 1
    if db.actif == nil then db.actif = true end
    -- La derniere consigne de l'overlay pour le portrait (voir GesteLCM).
    local recent = tonumber(db.quand) and (time() - db.quand) < 90
    if portraitVoulu == nil and db.portrait ~= nil and recent then portraitVoulu = db.portrait == true end
    if not recent then db.portrait = nil end
    InstallerBascule()
    AppliquerPortrait()
    Disposer()
    if db.actif then pont:Show() end
    local _, _, _, _, ok = Position()
    Msg("actif" .. (ok and " (position Epsilon : Z disponible)." or " (sans C_Epsilon : pas de Z)."))
  elseif db then
    Disposer()
  end
end)

SLASH_LCMCAPTEUR1 = "/lcmc"
SlashCmdList.LCMCAPTEUR = function(arg)
  local cmd, val = (arg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "off" then db.actif = false; pont:Hide(); Msg("bande masquée.")
  elseif cmd == "on" then db.actif = true; pont:Show(); Msg("bande affichée.")
  elseif cmd == "taille" and tonumber(val) then
    db.taille = math.max(1, math.min(12, floor(tonumber(val)))); Disposer(); Msg("taille " .. db.taille .. " px.")
  elseif cmd == "pos" then
    local x, y, z, carte, eps = Position()
    Msg(x and ("X %.2f Y %.2f Z %.2f carte %d (%s)"):format(x, y, z, carte, eps and "Epsilon" or "client") or "position indisponible.")
  else
    Msg("/lcmc on · off · taille 1-12 · pos")
  end
end
