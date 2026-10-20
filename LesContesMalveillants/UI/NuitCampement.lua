-- Cinematique commune : textures BLP transparentes, calques ordonnes.
local _, LCM = ...
local N = {}
LCM.UI.NuitCampement = N
local floor, min, max = math.floor, math.min, math.max
local FEUX = {}
local function borne(v) return max(0, min(1, v)) end
local function doux(v) v = borne(v); return v * v * (3 - 2 * v) end
local function cadre(parent, niveau)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameStrata("TOOLTIP"); f:SetFrameLevel(niveau)
    f:SetSize(384, 216); f:Show()
    f.pool = {}
    return f
end
local CHEMIN = "Interface\\AddOns\\LesContesMalveillants\\ressources\\campement\\"
for i=1,4 do FEUX[i]=CHEMIN.."feu"..i..".blp" end
local function sprite(parent, nom, x, y, w, h)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetTexture(CHEMIN..nom..".blp")
    t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",x,y); t:SetSize(w,h)
    parent.pool[#parent.pool+1]=t
    return t
end
local function horloge() return (GetServerTime and GetServerTime()) or time() end
local vus, ordre = {}, {}

local function actualiserVote(f)
    local n=0
    for _ in pairs(f.votes) do n=n+1 end
    f.nombreVotes=n
    f.voteTexte:SetText(string.format("%d/%d votes pour passer",n,f.nombreVotants))
    f.voteAide:SetText((f.votes[LCM.PlayerId()] and "Vote enregistré" or "Espace pour voter")
        .. string.format("  ·  %d requis (80 %%)",f.seuilVotes))
    if n>=f.seuilVotes and not f.finVote then
        f.finVote=GetTime(); f.alphaFinVote=f:GetAlpha()
    end
end

local function recevoirVote(qui,id)
    local f=N.frame
    if not f or not f:IsShown() or f.idNuit~=id or not f.votants[qui]
        or f.votes[qui] or f.finVote then return false end
    f.votes[qui]=true
    actualiserVote(f)
    return true
end

function N.Voter()
    local f=N.frame
    if not f or not f:IsShown() or GetTime()<f.origine then return false end
    local id=f.idNuit
    if not recevoirVote(LCM.PlayerId(),id) then return false end
    local canal=LCM.Combat.CanalGroupe()
    if canal then LCM.Reseau.Envoyer("CAMP_VOTE",{c=id},canal) end
    return true
end

LCM.Reseau.Ecouter("CAMP_VOTE",function(qui,d)
    if d and LCM.Reseau.DansLeGroupe(qui) then recevoirVote(qui,d.c) end
end)

local function creer()
    if N.frame then return N.frame end
    local f = cadre(UIParent, 9000); N.frame=f
    f:SetAllPoints(UIParent); f:EnableMouse(true)
    if f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
    f.noir=f:CreateTexture(nil,"BACKGROUND"); f.noir:SetAllPoints(f); f.noir:SetColorTexture(0,0,0,1)
    f.scene=cadre(f,9010); f.scene:SetPoint("CENTER"); f.scene:SetClipsChildren(true)
    f.ciel=cadre(f.scene,9020); f.ciel:SetAllPoints(f.scene)
    f.astres=cadre(f.scene,9040); f.astres:SetAllPoints(f.scene)
    f.terre=cadre(f.scene,9050); f.terre:SetAllPoints(f.scene)
    f.tente=cadre(f.scene,9060)
    f.feu=cadre(f.scene,9070); f.feu:SetAllPoints(f.scene)
    f.legende=cadre(f,9090); f.legende:SetSize(340,34)
    f.legende:SetPoint("BOTTOM",f,"BOTTOM",0,16)
    local fond=f.legende:CreateTexture(nil,"BACKGROUND")
    fond:SetAllPoints(f.legende); fond:SetColorTexture(.015,.02,.025,.72)
    f.titre=f.legende:CreateFontString(nil,"OVERLAY")
    f.titre:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",16,"")
    f.titre:SetPoint("CENTER"); f.titre:SetTextColor(.82,.80,.73)
    f.voteCadre=cadre(f,9100)
    f.voteCadre:SetSize(330,60); f.voteCadre:SetPoint("TOPRIGHT",f,"TOPRIGHT",-26,-22)
    f.voteTexte=f.voteCadre:CreateFontString(nil,"OVERLAY")
    f.voteTexte:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",16,"")
    f.voteTexte:SetPoint("TOPRIGHT"); f.voteTexte:SetTextColor(.94,.88,.70)
    f.voteAide=f.voteCadre:CreateFontString(nil,"OVERLAY")
    f.voteAide:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
    f.voteAide:SetPoint("TOPRIGHT",f.voteTexte,"BOTTOMRIGHT",0,-8); f.voteAide:SetTextColor(.66,.67,.65)
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown",function(self,touche)
        if not (InCombatLockdown and InCombatLockdown()) then
            self:SetPropagateKeyboardInput(touche~="SPACE")
        end
        if touche=="SPACE" then N.Voter() end
    end)
    f:Hide()
    f:SetScript("OnHide",function(self)
        self:SetScript("OnUpdate",nil)
        self:EnableKeyboard(false)
        self.votes=nil; self.votants=nil; self.idNuit=nil; self.finVote=nil
    end)
    return f
end

local function decor(f,graine)
    if not f.images then
        f.images=true
        f.ciel.nuit=sprite(f.ciel,"ciel-nuit",0,0,432,216)
        f.ciel.aube=sprite(f.ciel,"ciel-aube",0,0,432,216)
        f.ciel.aube:SetDrawLayer("OVERLAY")
        f.lune=sprite(f.astres,"lune",0,0,36,36)
        f.soleil=sprite(f.astres,"soleil",0,0,27,27)
        f.foret=sprite(f.terre,"lac-montagne",0,0,432,216)
        f.tente.image=sprite(f.tente,"tente",0,0,96,96)
        f.feu.base=sprite(f.feu,"feu1",216,15,52,68)
        f.feu.suivante=sprite(f.feu,"feu2",216,15,52,68)
        f.feu.suivante:SetDrawLayer("OVERLAY")
    end
    -- L'arbre et la tente restent a gauche comme sur le modele.
    f.foret:SetTexCoord(0,1,0,1)
    f.graine=graine
    f.imageFeu=nil
    f.largeur=nil; f.hauteur=nil; f.libelle=nil
end

function N.Lancer(id,graine,debut,membres)
    graine,debut=tonumber(graine),tonumber(debut)
    local maintenant=horloge()
    if type(id)~="string" or id=="" or vus[id] or not graine or not debut
        or graine~=graine or debut~=debut or graine<1 or graine>2147483646
        or debut<maintenant-16 or debut>maintenant+10 then return false end
    local f=creer()
    if f:IsShown() then return false end
    vus[id]=true; ordre[#ordre+1]=id
    if #ordre>64 then vus[table.remove(ordre,1)]=nil end
    decor(f,floor(graine))
    f.origine=GetTime()+debut-maintenant
    f.idNuit=id; f.votes={}; f.votants={}; f.nombreVotants=0; f.finVote=nil
    -- Liste figee au lancement, commune a tous les clients meme si le groupe change.
    if type(membres)~="table" then
        membres=LCM.Combat.Membres(); membres[#membres+1]=LCM.PlayerId()
    end
    for _,nom in ipairs(membres) do
        if type(nom)=="string" and not f.votants[nom] then
            f.votants[nom]=true; f.nombreVotants=f.nombreVotants+1
        end
    end
    f.seuilVotes=max(1,math.ceil(f.nombreVotants*.8))
    actualiserVote(f)
    if not (InCombatLockdown and InCombatLockdown()) then f:SetPropagateKeyboardInput(true) end
    f:EnableKeyboard(true)
    f:SetAlpha(0); f.scene:SetAlpha(0); f.legende:SetAlpha(0); f:Show()
    local function avancer(self)
        if self.finVote then
            local p=(GetTime()-self.finVote)/.45
            if p>=1 then self:Hide() else self:SetAlpha(self.alphaFinVote*(1-doux(p))) end
            return
        end
        local t=GetTime()-self.origine
        if t>=18 then self:Hide(); return end
        self.temps=t
        self:EnableMouse(t>=0)
        self:SetAlpha(t<1.3 and doux(t/1.3) or (1-doux((t-16.5)/1.5)))
        local reveal=doux((t-1.4)/1.2)*(1-doux((t-15)/1.3))
        self.scene:SetAlpha(reveal); self.legende:SetAlpha(reveal)
        local largeur,hauteur=UIParent:GetWidth(),UIParent:GetHeight()
        if largeur~=self.largeur or hauteur~=self.hauteur then
            self.largeur,self.hauteur=largeur,hauteur
            local echelle=max(.1,hauteur/216)
            self.scene:SetScale(echelle)
            self.scene:SetSize(largeur/echelle,216)
            self.largeurScene=largeur/echelle
            -- Remplissage integral, quel que soit le format d'ecran.
            local w=max(self.largeurScene,432)*(1+(self.graine%4)*.008)
            local x=(self.largeurScene-w)/2
            self.decorX,self.decorW,self.decorH=x,w,w/2
            for _,image in ipairs({self.foret}) do
                image:ClearAllPoints(); image:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",x,0)
                image:SetSize(w,w/2)
            end
            -- Ciels carres : garder les etoiles et nuages a leurs proportions.
            for _,image in ipairs({self.ciel.nuit,self.ciel.aube}) do
                image:ClearAllPoints(); image:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",x,(216-w)/2)
                image:SetSize(w,w)
            end
            for _,image in ipairs({self.feu.base,self.feu.suivante}) do
                image:ClearAllPoints(); image:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",x+w*.43,w*.075)
            end
        end
        local jour=doux((t-9)/4.5)
        self.ciel.aube:SetAlpha(jour)
        local p=borne((t-2)/10)
        self.lune:ClearAllPoints()
        self.lune:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",self.decorX+self.decorW*(.52+.32*p),self.decorH*.62+35*math.sin(p*math.pi))
        self.lune:SetAlpha(1-doux((t-10)/2))
        self.soleil:ClearAllPoints()
        self.soleil:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",self.decorX+self.decorW*(.75-.06*jour),self.decorH*.48+70*jour)
        self.soleil:SetAlpha(jour*.85)
        local libelle=jour<.5 and "L A   N U I T   P A S S E" or "U N   N O U V E A U   J O U R"
        if libelle~=self.libelle then self.titre:SetText(libelle); self.libelle=libelle end
        self.tente:SetAlpha(doux((t-2)/.65)); self.tente:ClearAllPoints()
        self.tente:SetPoint("BOTTOMLEFT",self.scene,"BOTTOMLEFT",self.decorX+self.decorW*.20,self.decorH*.125-6*(1-doux((t-2)/.65)))
        local lumiere=.94+jour*.06
        self.foret:SetVertexColor(lumiere,lumiere,lumiere)
        self.tente.image:SetVertexColor(.94+jour*.06,.92+jour*.08,.88+jour*.12)
        local cycle=max(0,t)*7
        local feu=floor(cycle)%4+1
        if self.imageFeu~=feu then
            self.feu.base:SetTexture(FEUX[feu])
            self.feu.suivante:SetTexture(FEUX[feu%4+1])
            self.imageFeu=feu
        end
        self.feu.suivante:SetAlpha(doux(cycle-floor(cycle)))
        self.feu:SetAlpha(doux((t-2)/.65)*(1-jour*.3))

    end
    f:SetScript("OnUpdate",avancer); avancer(f)
    return true
end
