-- ============================================================
--  Crossings — Carte du pays et des régions (touche M)
--  La touche de la carte du jeu ouvre à la place la carte du pays
--  où l'on se trouve : toutes ses régions, une couleur chacune. Un
--  clic sur une région l'ouvre : ses lieux remplis de couleur, leurs
--  noms (« ????? » tant qu'on ne les connaît pas) et les passages
--  droits. Le curseur se déplace au-dessus du voile persistant. Un bouton passe
--  à la carte du jeu, et un bouton sur la carte du jeu revient ici.
-- ============================================================
local ZG=LCMCrossings
local UI=ZG.EditorUI
-- Élargie le 3 novembre 2026 : quatre menus (continent, pays, région,
-- bâtiment) et la rangée des étages ne tenaient plus dans 960 — et la carte
-- y gagne autant.
local W,H,HEAD=1100,660,56
local M=16
local CW,CH=W-2*M,H-HEAD-2*M-28
local MIN_SCALE,MAX_SCALE=.02,40
local function Me() return UnitName("player") or "" end

-- Couleurs des lieux : la région porte la sienne et chacun de ses lieux en
-- reçoit une variante (voir ZG:PlaceColor dans Core). Sans rien de réglé, la
-- teinte se tire de l'identifiant, comme avant. Par id : gardé pour l'éditeur,
-- qui colore aussi des zones sans lieu.
local function PlaceColor(id)
    return ZG:TeinteDeDefaut(id)
end
-- La couleur d'une zone dessinée : celle de son lieu s'il en a un, sinon celle
-- de sa région.
local function SubColor(sub,zone)
    local place=sub and sub.enterPlace and ZG:FindPlace(sub.enterPlace)
    return ZG:PlaceColor(place,zone)
end
-- Plus de passe-droit pour l'AUTEUR : en mode joueur, le MJ ne doit pas voir
-- ses propres regions sans les avoir apprises — c'est tout l'interet du mode.
-- Hors mode joueur il voit tout, et HasLearnedZoneName le dit deja
-- (MJVoitTout) : le test sur le createur ne faisait que court-circuiter la
-- bascule.
local function PlaceKnown(place,zone) return ZG:KnowsPlaceName(place) end
local function ZoneKnown(zone) return zone~=nil and ZG:HasLearnedZoneName(zone.id) end



-- ── Géométrie ────────────────────────────────────────────────────────────

local function Area(points)
    local a=0
    for i=1,#points do
        local p,q=points[i],points[i%#points+1]
        a=a+p.x*q.y-q.x*p.y
    end
    return a/2
end

local function InTriangle(p,a,b,c)
    local function side(u,v,w) return (v.x-u.x)*(w.y-u.y)-(v.y-u.y)*(w.x-u.x) end
    local d1,d2,d3=side(a,b,p),side(b,c,p),side(c,a,p)
    return d1>=0 and d2>=0 and d3>=0
end

-- Découpe en triangles par « oreilles » (contour simple). Gardée en cache :
-- un périmètre peut compter jusqu'à 1500 points.
local triCache=setmetatable({},{__mode="k"})
local function Triangulate(points)
    local n=#points
    -- La clé regarde TOUS les sommets. Elle ne lisait que le premier et le
    -- dernier : déplacer un sommet du milieu (ce que fait la carte des zones
    -- du MJ) laissait le remplissage sur l'ancienne découpe.
    local somme=0
    for i=1,n do somme=somme+points[i].x*31+points[i].y*17 end
    local key=n..":"..string.format("%.3f",somme)
    local cached=triCache[points]
    if cached and cached.key==key then return cached.tris end
    local idx={}
    for i=1,n do idx[i]=i end
    if Area(points)<0 then
        local r={};for i=n,1,-1 do r[#r+1]=i end;idx=r
    end
    local tris={}
    local guard=0
    while #idx>3 and guard<n*n do
        guard=guard+1
        local found=false
        for i=1,#idx do
            local ia,ib,ic=idx[(i-2)%#idx+1],idx[i],idx[i%#idx+1]
            local a,b,c=points[ia],points[ib],points[ic]
            if (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)>0 then
                local ear=true
                for _,j in ipairs(idx) do
                    if j~=ia and j~=ib and j~=ic and InTriangle(points[j],a,b,c) then ear=false;break end
                end
                if ear then tris[#tris+1]={ia,ib,ic};table.remove(idx,i);found=true;break end
            end
        end
        if not found then break end
    end
    if #idx==3 then tris[#tris+1]={idx[1],idx[2],idx[3]}
    elseif #idx>3 then
        -- Contour qui se croise : on termine en éventail plutôt que de ne rien remplir.
        for i=2,#idx-1 do tris[#tris+1]={idx[1],idx[i],idx[i+1]} end
    end
    triCache[points]={key=key,tris=tris}
    return tris
end

local function IsClosed(sub) return sub.shape=="polygon" and sub.regionReady and sub.points and #sub.points>=3 end

local function PointInPolygon(points,x,y)
    local inside,j=false,#points
    for i=1,#points do
        local a,b=points[i],points[j]
        if (a.y>y)~=(b.y>y) and x<(b.x-a.x)*(y-a.y)/(b.y-a.y)+a.x then inside=not inside end
        j=i
    end
    return inside
end

local function LineEnds(sub)
    local a=sub.facing or 0;local r=(sub.width or 6)/2
    return {x=sub.x-math.cos(a)*r,y=sub.y+math.sin(a)*r},{x=sub.x+math.cos(a)*r,y=sub.y-math.sin(a)*r}
end

-- Interpoler les bords, pas les cases : la précision visuelle ne dépend
-- plus du nombre de pixels qu'occupe un yard après zoom. Ne pas relier deux
-- îlots distincts quand la topologie change entre deux lignes.
local EMPTY_FOG_ROW={}
local function SmoothFogRow(a,b,f)
    a,b=a or EMPTY_FOG_ROW,b or EMPTY_FOG_ROW
    if f==0 or a==b then return a end
    if #a==0 and #b==0 then return EMPTY_FOG_ROW end
    local out={}
    if #a==0 or #b==0 then
        local row,weight=#a>0 and a or b,#a>0 and (1-f) or f
        for i=1,#row,2 do
            local middle=(row[i]+row[i+1])/2
            out[i]=middle+(row[i]-middle)*weight
            out[i+1]=middle+(row[i+1]-middle)*weight
        end
        return out
    end
    if #a~=#b then return f<.5 and a or b end
    for i=1,#a,2 do
        if a[i]>b[i+1] or b[i]>a[i+1] then return f<.5 and a or b end
    end
    for i=1,#a do out[i]=a[i]+(b[i]-a[i])*f end
    return out
end

-- La carte des zones du panneau MJ (Crossings/CarteZones.lua) dessine la même
-- chose, en modifiable. Elle emprunte la géométrie d'ici plutôt que d'en tenir
-- une seconde écriture : deux triangulations à maintenir, c'est une de trop.
ZG.Geo = {
    Area = Area, Triangulate = Triangulate, IsClosed = IsClosed,
    SmoothFogRow = SmoothFogRow,
    PointInPolygon = PointInPolygon, LineEnds = LineEnds, Color = PlaceColor,
}

-- Région où se trouve le joueur : celle du lieu où il est, sinon celle dont
-- un périmètre le contient, sinon celle du passage le plus proche (même carte).
function ZG:CurrentRegion()
    local px,py,_,map=ZG:GetPlayerPose()
    if not px then return nil end
    for _,subId in pairs(ZG.here or {}) do
        local sub,zone=ZG:FindSubZone(subId)
        if sub and zone and sub.mapID==map then return zone end
    end
    local best,bestDist
    for _,zone in ipairs(ZG:GetZoneList()) do
        for _,sub in pairs(zone.subZones or {}) do
            if sub.mapID==map then
                if IsClosed(sub) and PointInPolygon(sub.points,px,py) then return zone end
                local d=math.sqrt(((sub.x or 0)-px)^2+((sub.y or 0)-py)^2)
                if not bestDist or d<bestDist then best,bestDist=zone,d end
            end
        end
    end
    return best
end

-- ── Fenêtre ──────────────────────────────────────────────────────────────

-- Régions sans pays : regroupées sous « Sans pays ».
local NONE="__none"
-- Le nom du pays se masque comme les autres : on peut connaitre une vallee
-- sans savoir de quelle couronne elle releve.
local function CountryName(key)
    local c=key and key~=NONE and ZG:GetCountry(key)
    if not c then return "Sans pays" end
    if ZG:HasLearnedCountryName(key) then return c.name or "" end
    return ZG:MaskText(c.name or "")
end
-- Le continent suit la même règle que le pays : son nom s'apprend, il ne se
-- devine pas en marchant.
local function ContinentName(key)
    local c=key and key~=NONE and ZG:GetContinent(key)
    if not c then return "Sans continent" end
    if ZG:HasLearnedContinentName(key) then return c.name or "" end
    return ZG:MaskText(c.name or "")
end

local win
local function Build()
    -- Une UI.Fenetre de LCM autour (UI.Habiller). Le titre (la région ou le
    -- pays affiché) et le sous-titre passent dans la couronne de la fenêtre.
    win=CreateFrame("Frame","LCMCrossingsRegionMap",UIParent)
    win:SetSize(W,H);win:SetFrameStrata("HIGH")
    local fenetre=UI.Habiller(win,"carte","Carte")
    win:Hide()

    local head=CreateFrame("Frame",nil,win)
    head:SetPoint("TOPLEFT",1,-1);head:SetPoint("TOPRIGHT",-1,-1);head:SetHeight(HEAD)
    win.title={SetText=function(_,texte) fenetre:Titre(texte or "") end}
    win.subtitle={SetText=function(_,texte) fenetre:SousTitre(texte or "") end}
    local gameMap=UI.CreatePanelButton(head,130,24,"Carte du jeu")
    gameMap:SetPoint("RIGHT",head,"RIGHT",-12,0)
    gameMap:SetScript("OnClick",function() ZG:ShowGameMap() end)
    local fit=UI.CreatePanelButton(head,130,24,"Vue d'ensemble")
    fit:SetPoint("RIGHT",gameMap,"LEFT",-10,0)
    fit:SetScript("OnClick",function() win:Fit();win:Draw() end)

    -- Quatre niveaux, quatre menus à gauche : le CONTINENT (tous ses pays),
    -- le PAYS (toutes ses régions), la RÉGION (tous ses lieux), le BÂTIMENT
    -- (ses pièces). On descendait jusqu'ici d'un clic sur la carte, ce qui
    -- suppose de savoir où viser ; les menus disent ce qu'on connaît et y
    -- mènent directement. M ouvre le pays où l'on se trouve et le suit ;
    -- choisir quoi que ce soit arrête de suivre le joueur.
    --
    -- Les bâtiments ne se listent QUE dans une région : au niveau du pays ils
    -- feraient une liste de tout ce qui a quatre murs, sans rapport avec ce
    -- qu'on cherche.
    local pickerContinent=UI.CreateSelect(head,150,24)
    pickerContinent:SetPoint("LEFT",head,"LEFT",12,0)
    win.pickerContinent=pickerContinent
    -- Un continent ne se liste que si l'on connaît au moins un de ses pays :
    -- sans cela il annoncerait des terres dont on n'a jamais entendu parler.
    function win:ContinentsListables()
        local list={}
        for _,continent in ipairs(ZG:GetContinentList()) do
            for _,country in ipairs(ZG:GetCountryList(continent.id)) do
                if #self:RegionsDuPays(country.id)>0 then list[#list+1]=continent;break end
            end
        end
        return list
    end
    pickerContinent.items=function()
        local list={{value=NONE,text="Tout ce que je connais"}}
        for _,continent in ipairs(win:ContinentsListables()) do
            list[#list+1]={value=continent.id,text=ContinentName(continent.id)}
        end
        return list
    end
    pickerContinent.onSelect=function(key) win:ShowContinent(key~=NONE and key or nil) end

    local picker=UI.CreateSelect(head,150,24)
    picker:SetPoint("LEFT",pickerContinent,"RIGHT",8,0)
    win.picker=picker
    picker.items=function()
        local seen,list={},{}
        for _,zone in ipairs(ZG:GetZoneList()) do
            -- Un pays dont on ne connait aucune region ne se liste pas : son
            -- nom seul disait deja qu'il existe quelque part un ailleurs.
            -- Et un continent choisi ne montre que les siens.
            if next(zone.subZones or {}) then
                local key=zone.countryId or NONE
                local pays=key~=NONE and ZG:GetCountry(key)
                local dedans=win.continent==nil or (pays and pays.continentId==win.continent)
                if dedans and not seen[key] then
                    seen[key]=true;list[#list+1]={value=key,text=CountryName(key)}
                end
            end
        end
        table.sort(list,function(a,b)
            if (a.value==NONE)~=(b.value==NONE) then return b.value==NONE end
            return a.text<b.text
        end)
        return list
    end
    -- Le pays où l'on se trouve reprend le suivi du joueur.
    function win:OpenCountry(key)
        local here=ZG:CurrentRegion()
        if here and (here.countryId or NONE)==key then self:ShowCurrent() else self:ShowCountry(key) end
    end
    picker.onSelect=function(key) win:OpenCountry(key) end

    local pickerRegion=UI.CreateSelect(head,150,24)
    pickerRegion:SetPoint("LEFT",picker,"RIGHT",8,0)
    win.pickerRegion=pickerRegion
    -- Une région ne se liste que si l'on en a foulé quelque chose : la
    -- découverte se fait en marchant (voir ZG:EstVu), et un menu qui nommerait
    -- tout ce qui existe la rendrait vaine. On sonde les sommets d'un pas
    -- assez large pour qu'un contour de mille points ne coûte pas mille
    -- questions.
    local function RegionApercue(zone,map)
        -- Le brouillard fait seul autorité, y compris pour la région où l'on
        -- se tient : après un oubli, on ne la retrouve qu'au pas suivant.
        for _,sub in pairs(zone.subZones or {}) do
            if sub.mapID==map and not ZG:EstInterieur(sub) and not ZG:EstEmpreinteBatiment(sub) then
                local pts=sub.points or {}
                if #pts>0 then
                    local pas=math.max(1,math.floor(#pts/48))
                    local cx,cy=0,0
                    for i=1,#pts,pas do
                        local a,b=pts[i],pts[(i%#pts)+1]
                        -- Le sommet, puis le milieu de l'arête : longer un
                        -- bord sans passer par ses angles devait compter.
                        if ZG:EstVu(map,a.x,a.y) then return true end
                        if ZG:EstVu(map,(a.x+b.x)/2,(a.y+b.y)/2) then return true end
                    end
                    for _,p in ipairs(pts) do cx,cy=cx+p.x,cy+p.y end
                    if ZG:EstVu(map,cx/#pts,cy/#pts) then return true end
                elseif sub.x and ZG:EstVu(map,sub.x,sub.y) then return true end
            end
        end
        return false
    end
    -- Les régions d'un pays dont on a foulé quelque chose. Clé NONE : celles
    -- qui n'ont pas de pays.
    function win:RegionsDuPays(key)
        local list={}
        if key==nil then return list end
        for _,zone in ipairs(ZG:GetZoneList()) do
            if (zone.countryId or NONE)==key and next(zone.subZones or {}) then
                local map=self:Map({zone})
                if RegionApercue(zone,map) then list[#list+1]=zone end
            end
        end
        table.sort(list,function(a,b) return (a.name or "")<(b.name or "") end)
        return list
    end
    function win:RegionsListables() return self:RegionsDuPays(self.country) end
    pickerRegion.items=function()
        local list={}
        for _,zone in ipairs(win:RegionsListables()) do
            list[#list+1]={value=zone.id,
                text=ZoneKnown(zone) and (zone.name or "") or ZG:MaskText(zone.name or "")}
        end
        return list
    end
    pickerRegion.onSelect=function(id) win:ShowRegion(ZG:GetZone(id)) end

    local pickerBati=UI.CreateSelect(head,150,24)
    pickerBati:SetPoint("LEFT",pickerRegion,"RIGHT",8,0)
    win.pickerBati=pickerBati
    function win:BatimentsListables()
        local list={}
        local zone=self.zone
        if not zone then return list end
        for _,place in ipairs(ZG:GetBatimentList(zone.id)) do
            if PlaceKnown(place,zone) then list[#list+1]=place end
        end
        table.sort(list,function(a,b) return (a.name or "")<(b.name or "") end)
        return list
    end
    pickerBati.items=function()
        local list={}
        for _,place in ipairs(win:BatimentsListables()) do
            list[#list+1]={value=place.id,text=place.name or ""}
        end
        return list
    end
    pickerBati.onSelect=function(id) win:ShowBatiment(ZG:FindPlace(id)) end

    -- ── Les étages, à côté du nom du bâtiment ────────────────────────────
    -- Une rangée de petits boutons, un par étage où le bâtiment a des
    -- pièces : « -1 0 1 2 ». Celui qu'on regarde est allumé. Au-delà de ce
    -- que la rangée peut tenir, deux flèches font défiler — on autorise les
    -- étages de -8000 à 8000, et une tour de mille niveaux ne doit pas
    -- déborder sur les boutons de droite.
    local ETAGES_VUS=7
    local etages={frame=CreateFrame("Frame",nil,head),boutons={}}
    etages.frame:SetPoint("LEFT",pickerBati,"RIGHT",8,0)
    etages.frame:SetSize(ETAGES_VUS*30+36,24)
    etages.frame:Hide()
    win.etages=etages
    etages.gauche=UI.CreatePanelButton(etages.frame,18,24,"‹")
    etages.gauche:SetPoint("LEFT",etages.frame,"LEFT",0,0)
    etages.droite=UI.CreatePanelButton(etages.frame,18,24,"›")
    for i=1,ETAGES_VUS do
        local b=UI.CreatePanelButton(etages.frame,28,24,"0")
        b:SetPoint("LEFT",etages.frame,"LEFT",18+(i-1)*30,0)
        b:SetScript("OnClick",function(self)
            if self.niveau then win:ShowEtage(self.niveau) end
        end)
        etages.boutons[i]=b
    end
    etages.droite:SetPoint("LEFT",etages.frame,"LEFT",18+ETAGES_VUS*30,0)
    etages.gauche:SetScript("OnClick",function()
        etages.debut=math.max(1,(etages.debut or 1)-1);win:MajSelecteurs()
    end)
    etages.droite:SetScript("OnClick",function()
        etages.debut=(etages.debut or 1)+1;win:MajSelecteurs()
    end)

    function win:ShowEtage(niveau)
        self.etage=niveau
        self:MajSelecteurs()
        self:Fit();self:Draw()
    end

    -- Les quatre menus disent toujours où l'on est. Le menu des bâtiments se
    -- cache hors d'une région, et s'éteint dans une région qui n'en a aucun
    -- de connu : un menu vide qu'on peut ouvrir ne dit rien de bon.
    function win:MajEtages()
        local montrer=self.level=="batiment" and self.batiment~=nil
        etages.frame:SetShown(montrer)
        if not montrer then return end
        local liste=ZG:GetNiveauxBatiment(self.batiment.id)
        -- La fenêtre glisse pour garder l'étage courant en vue.
        local ici=1
        for i,n in ipairs(liste) do if n==self.etage then ici=i end end
        local debut=math.max(1,math.min(etages.debut or 1,#liste-ETAGES_VUS+1))
        if ici<debut then debut=ici elseif ici>debut+ETAGES_VUS-1 then debut=ici-ETAGES_VUS+1 end
        debut=math.max(1,debut)
        etages.debut=debut
        for i,b in ipairs(etages.boutons) do
            local n=liste[debut+i-1]
            b.niveau=n
            b:SetShown(n~=nil)
            if n~=nil then
                b:SetText(tostring(n))
                -- Le soulignement d'or : la même marque que l'onglet ouvert.
                b.accent:SetShown(n==self.etage)
            end
        end
        local trop=#liste>ETAGES_VUS
        etages.gauche:SetShown(trop);etages.droite:SetShown(trop)
        etages.gauche:SetEnabled(debut>1)
        etages.droite:SetEnabled(debut+ETAGES_VUS-1<#liste)
    end

    function win:MajSelecteurs()
        pickerContinent:SetText(self.continent and ContinentName(self.continent)
            or "Tout ce que je connais")
        pickerContinent:SetEnabled(#self:ContinentsListables()>0)
        picker:SetText(self.level=="continent" and "Tous ses pays"
            or (self.country and CountryName(self.country) or "Aucun pays"))
        local zone=self.zone
        pickerRegion:SetText(zone
            and (ZoneKnown(zone) and (zone.name or "") or ZG:MaskText(zone.name or ""))
            or "Toutes les régions")
        pickerRegion:SetEnabled(#self:RegionsListables()>0)
        local montrer=self.level=="region" or self.level=="batiment"
        pickerBati:SetShown(montrer)
        if montrer then
            local liste=self:BatimentsListables()
            pickerBati:SetText(self.batiment and (self.batiment.name or "") or "Aucun bâtiment")
            pickerBati:SetEnabled(#liste>0)
        end
        self:MajEtages()
    end

    -- Un CONTINENT : toutes les régions de tous ses pays d'un coup. C'est la
    -- carte du monde — un cran au-dessus du pays, et le seul endroit d'où
    -- l'on voit deux royaumes se toucher. `key` nil : tout ce qu'on connaît,
    -- continents ou non.
    function win:ShowContinent(key)
        self.level,self.continent,self.country,self.zone="continent",key,nil,nil
        self.batiment,self.follow=nil,false
        self:MajSelecteurs()
        self:Fit();self:Draw()
    end

    -- Le continent d'un pays, pour que le menu du haut suive la descente.
    local function ContinentDe(key)
        local pays=key and key~=NONE and ZG:GetCountry(key)
        return pays and pays.continentId or nil
    end

    -- Pays (clé du pays, ou NONE pour les régions sans pays).
    function win:ShowCountry(key,follow,garderVue)
        self.level,self.country,self.zone,self.follow="country",key,nil,follow and true or false
        self.batiment=nil
        self.continent=ContinentDe(key)
        self:MajSelecteurs()
        if not garderVue or not self.cx or not self.cy or not self.scale then self:Fit() end
        self:Draw()
    end
    function win:ShowRegion(zone)
        if not zone then return end
        self.level,self.country,self.zone,self.follow="region",zone.countryId or NONE,zone,false
        self.batiment=nil
        self.continent=ContinentDe(self.country)
        self:MajSelecteurs()
        self:Fit();self:Draw()
    end
    -- La carte d'un bâtiment : son intérieur, à sa propre échelle. Elle
    -- s'ouvre d'un clic sur son point, ou toute seule quand on y entre.
    function win:ShowBatiment(place)
        if not place then return end
        local zone=ZG:GetZone(place.zoneId)
        self.level,self.batiment,self.zone,self.follow="batiment",place,zone,false
        self.country=zone and (zone.countryId or NONE) or NONE
        self.continent=ContinentDe(self.country)
        -- On arrive à l'étage où l'on se tient ; de l'extérieur, au plus bas
        -- de ce que le bâtiment a — le rez d'ordinaire, la cave si elle est
        -- tout ce qu'il y a.
        local liste=ZG:GetNiveauxBatiment(place.id)
        local ici=ZG:NiveauDuJoueur()
        self.etage=nil
        for _,n in ipairs(liste) do if n==ici then self.etage=n end end
        if self.etage==nil then
            self.etage=liste[1] or 0
            for _,n in ipairs(liste) do if n==0 then self.etage=0 end end
        end
        etages.debut=nil
        self:MajSelecteurs()
        self:Fit();self:Draw()
    end
    function win:ShowCurrent(garderVue)
        local zone=ZG:CurrentRegion()
        self.here=zone
        self.batiment=nil
        if zone then self:ShowCountry(zone.countryId or NONE,true,garderVue)
        else
            self.level,self.country,self.zone,self.follow="country",nil,nil,true
            self:MajSelecteurs();self:Draw()
        end
    end

    -- Fond dessiné : sombre, légèrement chaud, avec un quadrillage discret.
    local canvas=CreateFrame("Frame",nil,win)
    canvas:SetPoint("TOPLEFT",M,-(HEAD+M));canvas:SetSize(CW,CH)
    local bg=canvas:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.055,.060,.058,1)
    if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
    -- Les couches graphiques se transforment ensemble, dans un viewport fixe.
    local scene=CreateFrame("Frame",nil,canvas);scene:SetSize(CW,CH)
    local function TransformScene(scale,x,y)
        scene:SetScale(scale);scene:ClearAllPoints()
        scene:SetPoint("TOPLEFT",canvas,"TOPLEFT",x/scale,-y/scale)
    end
    local function ResetScene() TransformScene(1,0,0) end
    ResetScene()
    win.scene=scene
    local grid=CreateFrame("Frame",nil,canvas);grid:SetAllPoints()
    for i=1,math.floor(CW/60) do
        local t=grid:CreateTexture(nil,"BORDER");t:SetColorTexture(1,1,1,.025);t:SetWidth(1)
        t:SetPoint("TOPLEFT",i*60,0);t:SetPoint("BOTTOMLEFT",i*60,0)
    end
    for i=1,math.floor(CH/60) do
        local t=grid:CreateTexture(nil,"BORDER");t:SetColorTexture(1,1,1,.025);t:SetHeight(1)
        t:SetPoint("TOPLEFT",0,-i*60);t:SetPoint("TOPRIGHT",0,-i*60)
    end
    -- Carte fixe, puis voile, puis curseur : trois couches indépendantes.
    local fills=CreateFrame("Frame",nil,scene);fills:SetAllPoints();fills:SetFrameLevel(canvas:GetFrameLevel()+2)
    local lines=CreateFrame("Frame",nil,scene);lines:SetAllPoints();lines:SetFrameLevel(canvas:GetFrameLevel()+3)
    local labels=CreateFrame("Frame",nil,scene);labels:SetAllPoints();labels:SetFrameLevel(canvas:GetFrameLevel()+4)
    local fog=CreateFrame("Frame",nil,scene);fog:SetAllPoints();fog:SetFrameLevel(canvas:GetFrameLevel()+5)
    local marker=CreateFrame("Frame",nil,scene);marker:SetAllPoints();marker:SetFrameLevel(canvas:GetFrameLevel()+6)
    -- Remplissage possible seulement si le jeu sait déformer une texture.
    local probe=fills:CreateTexture(nil,"ARTWORK");probe:Hide()
    local CAN_FILL=probe.SetVertexOffset~=nil
    win.canvas=canvas
    win.fog=fog
    win.empty=labels:CreateFontString(nil,"OVERLAY","GameFontNormal")
    win.empty:SetPoint("CENTER");win.empty:SetWidth(CW-80);UI.ApplyMutedText(win.empty)
    local help=win:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    help:SetPoint("BOTTOMRIGHT",-M,12);help:SetJustifyH("RIGHT");UI.ApplyMutedText(help)
    win.help=help

    -- Réserves de textures et de textes, réutilisées d'un dessin à l'autre.
    local triPool,linePool,labelPool={}, {}, {}
    local usedTri,usedLine,usedLabel=0,0,0
    local function Tri(a,b,c,color,alpha)
        if (a[1]<0 and b[1]<0 and c[1]<0) or (a[1]>CW and b[1]>CW and c[1]>CW)
            or (a[2]<0 and b[2]<0 and c[2]<0) or (a[2]>CH and b[2]>CH and c[2]>CH) then return end
        usedTri=usedTri+1
        local t=triPool[usedTri]
        if not t then t=fills:CreateTexture(nil,"ARTWORK");triPool[usedTri]=t end
        local minx,maxx=math.min(a[1],b[1],c[1]),math.max(a[1],b[1],c[1])
        local miny,maxy=math.min(a[2],b[2],c[2]),math.max(a[2],b[2],c[2])
        local w,h=math.max(1,maxx-minx),math.max(1,maxy-miny)
        t:ClearAllPoints();t:SetPoint("TOPLEFT",scene,"TOPLEFT",minx,-miny);t:SetSize(w,h)
        t:SetColorTexture(color[1],color[2],color[3],alpha or .28)
        -- Coins du carré déplacés sur le triangle : haut-gauche, bas-gauche, haut-droit, bas-droit.
        t:SetVertexOffset(1,a[1]-minx,-(a[2]-miny))
        t:SetVertexOffset(2,b[1]-minx,-(b[2]-(miny+h)))
        t:SetVertexOffset(3,c[1]-(minx+w),-(c[2]-miny))
        t:SetVertexOffset(4,c[1]-(minx+w),-(c[2]-(miny+h)))
        t:Show()
    end
    local function Line(x1,y1,x2,y2,color,width,alpha)
        local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
        if length<.5 then return end
        if (x1<0 and x2<0) or (x1>CW and x2>CW) or (y1<0 and y2<0) or (y1>CH and y2>CH) then return end
        usedLine=usedLine+1
        local t=linePool[usedLine]
        if not t then t=lines:CreateTexture(nil,"ARTWORK");linePool[usedLine]=t end
        t:ClearAllPoints();t:SetPoint("CENTER",scene,"TOPLEFT",(x1+x2)/2,-(y1+y2)/2)
        t:SetSize(length,width or 2);t:SetRotation(math.atan2(-dy,dx))
        t:SetColorTexture(color[1],color[2],color[3],alpha or .95);t:Show()
    end
    local function Text(x,y,text,color,big,kind,entry,region)
        -- M : les noms sont dans l'infobulle. Les cartes-objets gardent leur texte.
        if not win.carte then return end
        usedLabel=usedLabel+1
        local f=labelPool[usedLabel]
        if not f then f=labels:CreateFontString(nil,"OVERLAY","GameFontNormal");f:SetShadowColor(0,0,0,1);f:SetShadowOffset(1,-1);labelPool[usedLabel]=f end
        f:SetFontObject(big and "GameFontNormalLarge" or "GameFontNormal")
        f:ClearAllPoints();f:SetPoint("CENTER",scene,"TOPLEFT",x,-y)
        f.knownKind,f.knownEntry,f.knownRegion=kind,entry,region
        f:SetText(text);f:SetTextColor(color[1],color[2],color[3],1);f:Show()
    end

    -- Monde → cadre : nord en haut, est à droite (voir ZG:PlacementOffset).
    function win:ToScreen(x,y)
        return CW/2+(self.cx-x)*self.scale,CH/2-(y-self.cy)*self.scale
    end
    -- Régions affichées : la région ouverte, ou toutes celles du pays.
    function win:Zones()
        -- Une carte lue : toutes les régions qu'elle dévoile.
        if self.carte then
            local list={}
            for _,id in ipairs(self.carte.dessinees or {}) do
                local zone=ZG:GetZone(id)
                if zone then list[#list+1]=zone end
            end
            return list
        end
        if self.level=="region" then return {self.zone} end
        local list={}
        -- Un continent : toutes les régions de tous ses pays. Sans continent
        -- choisi, tout ce qu'on connaît, d'où qu'il vienne.
        if self.level=="continent" then
            for _,zone in ipairs(ZG:GetZoneList()) do
                local pays=zone.countryId and ZG:GetCountry(zone.countryId)
                if self.continent==nil or (pays and pays.continentId==self.continent) then
                    list[#list+1]=zone
                end
            end
            return list
        end
        if self.country==nil then return list end
        for _,zone in ipairs(ZG:GetZoneList()) do
            -- Une region inconnue ne se montre pas du tout, pas meme sa forme.
            if (zone.countryId or NONE)==self.country then list[#list+1]=zone end
        end
        return list
    end
    -- Carte (instance) affichée : celle du joueur si ces régions y ont des
    -- passages, sinon celle où elles en ont le plus.
    -- Hors d'un bâtiment, les INTÉRIEURS n'y votent pas : un bâtiment bâti
    -- sur une autre carte du jeu — ou une cave à vingt pièces — emporterait
    -- le choix, et la région se viderait de tout ce qu'elle montre.
    function win:Map(zones)
        local _,_,_,map=ZG:GetPlayerPose()
        local dedans=self.batiment~=nil
        local counts,best={},nil
        for _,zone in ipairs(zones) do
            for _,sub in pairs(zone.subZones or {}) do
                local compte=dedans or (not ZG:EstInterieur(sub) and not ZG:EstEmpreinteBatiment(sub))
                if compte then
                    if sub.mapID==map then return map end
                    if sub.mapID then counts[sub.mapID]=(counts[sub.mapID] or 0)+1 end
                end
            end
        end
        for id,n in pairs(counts) do if not best or n>counts[best] then best=id end end
        return best or map
    end
    -- Les pièces d'un bâtiment, son empreinte comprise : la carte d'un
    -- bâtiment ne montre QUE son intérieur, et celle de la région ne le
    -- montre pas du tout — elle s'y marque d'un point.
    function win:SubsBatiment()
        local b=self.batiment
        local zone=b and ZG:GetZone(b.zoneId)
        if not zone then return {} end
        local dedans,bouge={[b.id]=true},true
        while bouge do
            bouge=false
            for _,p in pairs(zone.places or {}) do
                if not dedans[p.id] and p.parent and dedans[p.parent] then dedans[p.id]=true;bouge=true end
            end
        end
        -- Un seul ÉTAGE à la fois : les cloisons de trois niveaux posées sur
        -- le même plan ne se lisent plus. L'empreinte du bâtiment, elle,
        -- reste toujours — c'est le contour, il vaut pour tous les étages.
        local etage=self.etage or 0
        local list={}
        for _,sub in pairs(zone.subZones or {}) do
            local lieu=sub.enterPlace and zone.places[sub.enterPlace]
            if lieu and dedans[lieu.id] and sub.enabled~=false
                and (lieu.id==b.id or ZG:GetNiveau(lieu)==etage) then
                local vide=sub.shape=="polygon" and #(sub.points or {})<2
                if not vide then list[#list+1]={sub=sub,zone=zone} end
            end
        end
        table.sort(list,function(a,b2) return a.sub.id<b2.sub.id end)
        return list
    end

    -- Passages visibles, chacun avec sa région : { {sub=, zone=} }.
    function win:Subs()
        if self.batiment then return self:SubsBatiment() end
        local zones=self:Zones()
        local map=self:Map(zones)
        local list={}
        for _,zone in ipairs(zones) do
            for _,sub in pairs(zone.subZones or {}) do
                -- Une carte lue dessine TOUTE région qu'elle montre ; c'est
                -- le dessin qui tait les noms qu'elle ne dévoile pas.
                -- Une zone sans sommets, elle, n'a rien à montrer : depuis
                -- qu'un lieu naît avec la sienne, toute région en porte.
                local vide=sub.shape=="polygon" and #(sub.points or {})<2
                -- Un intérieur ne s'étale pas sur la carte du dehors : ses
                -- cloisons noieraient le reste, et elles sont à une tout
                -- autre échelle.
                --
                -- Une carte LUE dessine tout ce qu'elle montre, connu ou non :
                -- c'est le MJ qui a choisi ce qu'elle revele, et les lieux non
                -- devoiles y donnent sa forme a la region. Ailleurs, on ne
                -- voit que ce qu'on a foule.
                -- L'EMPREINTE d'un bâtiment non plus : elle est bâtie où l'on
                -- veut sur la carte du monde — sous elle, le plus souvent,
                -- pour les images par seconde — et la dessiner ici posait le
                -- temple à des lieues de son village (3 novembre 2026). Le
                -- bâtiment se marque à son EMPLACEMENT, voir win:Batiments.
                if sub.mapID==map and sub.enabled~=false and not vide
                    and not ZG:EstInterieur(sub) and not ZG:EstEmpreinteBatiment(sub) then
                    list[#list+1]={sub=sub,zone=zone}
                end
            end
        end
        table.sort(list,function(a,b) return a.sub.id<b.sub.id end)
        return list
    end

    -- Les bâtiments visibles sur la carte du dehors : un point et un nom,
    -- posés à leur EMPLACEMENT — l'endroit de la région où le bâtiment se
    -- tient, sans rapport avec celui du monde où son intérieur est bâti.
    function win:Batiments()
        if self.batiment then return {} end
        local zones=self:Zones()
        local map=self:Map(zones)
        local list={}
        for _,zone in ipairs(zones) do
            for _,place in pairs(zone.places or {}) do
                -- Un batiment qu'on n'a jamais vu ne pose pas son point.
                if place.batiment and (self.carte~=nil or PlaceKnown(place,zone)) then
                    local m,ex,ey=ZG:GetEmplacement(place)
                    if ex and (m==nil or m==map) then
                        list[#list+1]={place=place,zone=zone,x=ex,y=ey}
                    end
                end
            end
        end
        table.sort(list,function(a,b) return a.place.id<b.place.id end)
        return list
    end

    -- ── Où je me tiens ───────────────────────────────────────────────────
    -- La carte cachait volontairement la position : elle ne devait rien
    -- révéler. Avec le brouillard, l'argument tombe — c'est SA carte, de SES
    -- pas, et sans repère on ne sait plus quel bord on vient de longer.
    local moi=marker:CreateTexture(nil,"OVERLAY")
    moi:SetSize(13,13);moi:SetColorTexture(.35,.85,1,1);moi:SetRotation(math.pi/4)
    local moiHalo=marker:CreateTexture(nil,"ARTWORK")
    moiHalo:SetSize(21,21);moiHalo:SetColorTexture(.08,.20,.26,.85);moiHalo:SetRotation(math.pi/4)
    local moiCap=marker:CreateTexture(nil,"OVERLAY")
    moiCap:SetColorTexture(.35,.85,1,.9)
    function win:Moi()
        local px,py,facing,carteJoueur=ZG:GetPlayerPose()
        local mapJeu=self.carte and nil or self.markerMap
        if not px or not self.cx or not self.cy or not self.scale or (mapJeu and carteJoueur~=mapJeu) then
            moi:Hide();moiHalo:Hide();moiCap:Hide()
            return
        end
        local x,y=self:ToScreen(px,py)
        if x<-20 or x>CW+20 or y<-20 or y>CH+20 then
            moi:Hide();moiHalo:Hide();moiCap:Hide()
            return
        end
        for _,t in ipairs({moi,moiHalo}) do
            t:ClearAllPoints();t:SetPoint("CENTER",scene,"TOPLEFT",x,-y);t:Show()
        end
        -- Le regard : +y est le nord, et le nord est en haut.
        facing=facing or 0
        local dx,dy=-math.sin(facing)*13,-math.cos(facing)*13
        moiCap:ClearAllPoints()
        moiCap:SetPoint("CENTER",scene,"TOPLEFT",x+dx,-(y+dy))
        moiCap:SetSize(4,4);moiCap:Show()
    end

    -- Le bâtiment où se tient le joueur, s'il y en a un.
    function win:BatimentIci()
        for placeId in pairs(ZG.here or {}) do
            local place=ZG:FindPlace(placeId)
            local b=place and ZG:BatimentDe(place)
            if b then return b end
        end
    end
    function win:Fit()
        local minx,maxx,miny,maxy
        local function add(p)
            minx=math.min(minx or p.x,p.x);maxx=math.max(maxx or p.x,p.x)
            miny=math.min(miny or p.y,p.y);maxy=math.max(maxy or p.y,p.y)
        end
        local surCarte={}
        for _,e in ipairs(self:Subs()) do
            local sub=e.sub
            surCarte[e.zone.id]=true
            if sub.shape=="polygon" then for _,p in ipairs(sub.points or {}) do add(p) end
            else local a,b=LineEnds(sub);add(a);add(b) end
        end
        -- Les emplacements des bâtiments comptent aussi : une région qui n'a
        -- qu'un temple doit se cadrer dessus.
        for _,b in ipairs(self:Batiments()) do add(b) end
        -- Les repères dessinés comptent ; ceux d'une autre carte du jeu, non.
        for _,r in ipairs(self.carte and self.carte.reperes or {}) do
            if not r.region or surCarte[r.region] then add(r) end
        end
        if not minx then self.cx,self.cy,self.scale=0,0,self.scale or 2;return end
        self.cx,self.cy=(minx+maxx)/2,(miny+maxy)/2
        local w,h=math.max(20,maxx-minx),math.max(20,maxy-miny)
        self.scale=math.max(MIN_SCALE,math.min(MAX_SCALE,math.min((CW-80)/w,(CH-80)/h)))
    end
    -- Le contour de la RÉGION (voir Core/Crossings.lua) : l'étendue de la
    -- région elle-même, qui contient ses lieux. On ne le remplit pas — son
    -- aplat les noierait — sauf sur la carte d'un pays, où c'est justement la
    -- région qu'on veut voir d'un bloc.
    -- L'empreinte d'un BÂTIMENT suit la même règle : sur sa propre carte,
    -- elle entoure ses pièces et ne se remplit donc pas.
    local function EstContourRegion(sub)
        local place=sub.enterPlace and ZG:FindPlace(sub.enterPlace)
        return place~=nil and (place.pourRegion==true or place.batiment==true)
    end
    -- Polygone fermé : rempli, contour, et boîte englobante (écran) pour
    -- l'étiquette. `fogOff` : dessiner entier, sans tenir compte du brouillard
    -- (une carte lue, que le MJ a composée pour être lue telle quelle).
    -- Réutiliser la triangulation tant que les sommets restent identiques,
    -- y compris quand l'éditeur modifie les coordonnées en place.
    local trianglesCache=setmetatable({}, {__mode="k"})
    local function Triangles(points)
        local c=trianglesCache[points]
        local identique=c and #c.coords==#points*2
        if identique then
            for i,p in ipairs(points) do
                if c.coords[i*2-1]~=p.x or c.coords[i*2]~=p.y then identique=false;break end
            end
        end
        if not identique then
            c={coords={},triangles=Triangulate(points)}
            for i,p in ipairs(points) do c.coords[i*2-1],c.coords[i*2]=p.x,p.y end
            trianglesCache[points]=c
        end
        return c.triangles
    end
    local function DrawPolygon(self,sub,color,outlineAlpha,box,remplirQuandMeme,fogOff)
        local screen={}
        for i,p in ipairs(sub.points) do
            local x,y=self:ToScreen(p.x,p.y);screen[i]={x,y}
            if box then
                box.minx=math.min(box.minx or x,x);box.maxx=math.max(box.maxx or x,x)
                box.miny=math.min(box.miny or y,y);box.maxy=math.max(box.maxy or y,y)
            end
        end
        local alpha=(not remplirQuandMeme and EstContourRegion(sub)) and .09 or .28
        if IsClosed(sub) and CAN_FILL then
            for _,t in ipairs(Triangles(sub.points)) do
                Tri(screen[t[1]],screen[t[2]],screen[t[3]],color,alpha)
            end
        end
        for i=2,#screen do Line(screen[i-1][1],screen[i-1][2],screen[i][1],screen[i][2],color,2,outlineAlpha) end
        if IsClosed(sub) then Line(screen[#screen][1],screen[#screen][2],screen[1][1],screen[1][2],color,2,outlineAlpha) end
        return screen
    end
    local function Light(c) return {math.min(1,c[1]+.35),math.min(1,c[2]+.35),math.min(1,c[3]+.35)} end

    -- ── Une carte lue (Core/Cartes.lua) ──
    -- La région de la carte, ses seuls lieux dévoilés — nommés, puisqu'on
    -- vient de les apprendre — et ses repères. Rien d'autre : une carte ne
    -- montre que ce que le MJ y a mis.
    local RADIAL="Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\"
    local ICONES_REPERE={
        ressource=RADIAL.."fenetres-recoltes.tga", vendeur=RADIAL.."fenetres-vendeurs.tga",
        coffre=RADIAL.."fenetres-coffres.tga", pnj=RADIAL.."fenetres-personnages.tga",
        affichage="Interface\\ICONS\\INV_Misc_Note_02",
        libre=RADIAL.."fenetres-lieux.tga",
    }
    local COULEUR_REPERE={.95,.85,.55}
    -- Les bâtiments, en violet, comme dans l'éditeur.
    local COULEUR_BATIMENT={.70,.52,.88}
    local pinPool,usedPin={},0
    local function Pin(x,y,genre)
        usedPin=usedPin+1
        local t=pinPool[usedPin]
        if not t then t=labels:CreateTexture(nil,"ARTWORK");t:SetSize(22,22);pinPool[usedPin]=t end
        t:SetTexture(ICONES_REPERE[genre] or ICONES_REPERE.libre)
        t:ClearAllPoints();t:SetPoint("CENTER",scene,"TOPLEFT",x,-y);t:Show()
    end
    function win:DrawCarte()
        local carte=self.carte
        self.title:SetText(carte.titre or "Carte")
        -- Le sous-titre ne nomme que ce que la carte DÉVOILE.
        local noms={}
        if carte.regionNom~="" then noms[#noms+1]=carte.regionNom end
        for _,lieu in ipairs(carte.ordre or {}) do if lieu.nom~="" then noms[#noms+1]=lieu.nom end end
        self.subtitle:SetText(table.concat(noms,"  ·  "))
        self.help:SetText("Molette : zoom · Glisser : déplacer")
        local subs=self:Subs()
        -- Les régions dessinées sur CETTE carte du jeu : un repère posé dans une
        -- région d'une autre carte ne se place pas ici, il se nomme en bas.
        local surCarte={}
        for _,e in ipairs(subs) do surCarte[e.zone.id]=true end
        local ici,lignes={},{}
        for _,r in ipairs(carte.reperes or {}) do
            if not r.region or surCarte[r.region] then
                ici[#ici+1]=r
            else
                local genre=LCM.Cartes and LCM.Cartes.Genre(r.genre)
                lignes[#lignes+1]=string.format("%s  ·  %s  —  %s",genre and genre.label or "Repère",
                    (r.label and r.label~="") and r.label or "?",LCM.Cartes.EmplacementVu(r,carte))
            end
        end
        if not self.ailleurs then
            self.ailleurs=labels:CreateFontString(nil,"OVERLAY","GameFontNormal")
            self.ailleurs:SetPoint("BOTTOMLEFT",canvas,"BOTTOMLEFT",12,12)
            self.ailleurs:SetPoint("RIGHT",canvas,"RIGHT",-12,0)
            self.ailleurs:SetJustifyH("LEFT");self.ailleurs:SetJustifyV("BOTTOM")
            self.ailleurs:SetShadowColor(0,0,0,1);self.ailleurs:SetShadowOffset(1,-1)
            self.ailleurs:SetTextColor(COULEUR_REPERE[1],COULEUR_REPERE[2],COULEUR_REPERE[3],1)
        end
        self.ailleurs:SetText(#lignes>0 and ("Ailleurs :\n"..table.concat(lignes,"\n")) or "")
        self.ailleurs:SetShown(#lignes>0)
        if #subs==0 and #ici==0 then
            self.empty:SetText(#lignes>0 and "" or "Cette carte ne montre rien que vous sachiez situer.")
            self.empty:SetShown(#lignes==0)
            return
        end
        self.empty:Hide()

        -- Les lieux : dévoilés, en couleur et nommés ; les autres, en gris et
        -- sans nom — ils ne servent qu'à donner sa forme à la région.
        local GRIS={.42,.42,.40}
        local placeLabel,boites={}, {}
        for _,e in ipairs(subs) do
            local sub=e.sub
            local place=sub.enterPlace and ZG:FindPlace(sub.enterPlace)
            local devoile=place and carte.lieux[place.id]
            local color=devoile and ZG:PlaceColor(place,e.zone) or GRIS
            local boite=boites[e.zone.id] or {zone=e.zone}
            boites[e.zone.id]=boite
            if sub.shape=="polygon" and sub.points and #sub.points>=2 then
                local screen=DrawPolygon(self,sub,color,devoile and .95 or .55,boite,nil,true)
                if devoile and IsClosed(sub) then
                    local area=math.abs(Area(sub.points))
                    if not placeLabel[place.id] or area>placeLabel[place.id].area then
                        local sx,sy=0,0
                        for _,pt in ipairs(screen) do sx,sy=sx+pt[1],sy+pt[2] end
                        placeLabel[place.id]={x=sx/#screen,y=sy/#screen,area=area,place=place,color=color}
                    end
                end
            elseif sub.shape~="polygon" and devoile then
                local a,b=LineEnds(sub)
                local x1,y1=self:ToScreen(a.x,a.y);local x2,y2=self:ToScreen(b.x,b.y)
                Line(x1,y1,x2,y2,color,4)
                if not placeLabel[place.id] then
                    placeLabel[place.id]={x=(x1+x2)/2,y=(y1+y2)/2-14,area=0,place=place,color=color}
                end
            end
        end
        for _,l in pairs(placeLabel) do
            if l.x>-40 and l.x<CW+40 and l.y>-20 and l.y<CH+20 then
                Text(l.x,l.y,l.place.name or "",Light(l.color),l.area>0)
            end
        end
        -- Le nom de chaque région, au-dessus de sa forme : en clair si la carte
        -- la dévoile, masqué sinon.
        for id,boite in pairs(boites) do
            if boite.minx then
                local nom=carte.regions[id] and (boite.zone.name or "") or ZG:MaskText(boite.zone.name or "")
                local x,y=(boite.minx+boite.maxx)/2,boite.miny-14
                if x>-60 and x<CW+60 and y>-20 and y<CH+20 then Text(x,y,nom,{.85,.80,.65},true) end
            end
        end
        for _,r in ipairs(ici) do
            local x,y=self:ToScreen(r.x,r.y)
            if x>-20 and x<CW+20 and y>-20 and y<CH+20 then
                Pin(x,y,r.genre)
                if r.label and r.label~="" then Text(x,y+18,r.label,COULEUR_REPERE,false) end
            end
        end
    end
    -- Ouvre la carte lue. `vue` : ce que rend Cartes.Vue.
    function win:ShowCarte(vue)
        self.carte=vue
        self.batiment=nil
        self.level,self.zone,self.follow="region",vue.region and ZG:GetZone(vue.region) or nil,false
        self.country=self.zone and (self.zone.countryId or NONE) or NONE
        -- Une carte LUE ne se parcourt pas : elle montre ce que le MJ y a mis,
        -- et les trois menus n'y mèneraient qu'ailleurs.
        pickerContinent:Hide();picker:Hide();pickerRegion:Hide();pickerBati:Hide()
        etages.frame:Hide()
        self:Fit();self:Draw()
    end

    -- Projection de la surface persistante : aucun rejeu du trajet.
    local fogRows={}
    local cover=fog:CreateTexture(nil,"OVERLAY");cover:SetAllPoints();cover:SetColorTexture(.055,.060,.058,1)
    local loading=fog:CreateFontString(nil,"OVERLAY","GameFontNormal")
    loading:SetPoint("CENTER");loading:SetText("Préparation des découvertes enregistrées…")
    function win:DrawFog()
        if self.carte or (LCM.IsMaster and LCM.IsMaster()) or not self.cx or not self.scale then
            fog:Hide();return
        end
        local state=ZG:PreparerBrouillard(self.markerMap)
        if not state then fog:Hide();return end
        fog:Show()
        -- La migration n'est jamais affichée comme une nouvelle exploration.
        if not state.ready then cover:Show();loading:Show();return end
        cover:Hide();loading:Hide()
        local view=self.fogView
        local sameView=view and view.state==state and view.cx==self.cx and view.cy==self.cy and view.scale==self.scale
        if sameView and view.revision==state.revision then return end
        self.fogView={state=state,cx=self.cx,cy=self.cy,scale=self.scale,revision=state.revision}
        for top=0,CH-1 do
            local h=1
            local worldY=self.cy-(top+.5-CH/2)/self.scale-.5
            local y=math.floor(worldY)
            local source,nextSource=state.rows[y],state.rows[y+1]
            local row=fogRows[top]
            if not row then row={textures={}};fogRows[top]=row end
            local revision=source and source.revision or 0
            local nextRevision=nextSource and nextSource.revision or 0
            if not sameView or row.source~=source or row.revision~=revision
                or row.nextSource~=nextSource or row.nextRevision~=nextRevision then
                row.source,row.revision=source,revision
                row.nextSource,row.nextRevision=nextSource,nextRevision
                local visible=SmoothFogRow(source,nextSource,worldY-y)
                local count,last=0,0
                local function Paint(left,right)
                    if right<=left then return end
                    count=count+1
                    local t=row.textures[count]
                    if not t then t=fog:CreateTexture(nil,"ARTWORK");t:SetColorTexture(.055,.060,.058,1);row.textures[count]=t end
                    if t.fogLeft~=left or t.fogRight~=right then
                        t:ClearAllPoints();t:SetPoint("TOPLEFT",scene,"TOPLEFT",left,-top)
                        t:SetSize(right-left,h);t.fogLeft,t.fogRight=left,right
                    end
                    t:Show()
                end
                for i=#visible-1,1,-2 do
                    local left=math.max(0,CW/2+(self.cx-visible[i+1])*self.scale)
                    local right=math.min(CW,CW/2+(self.cx-visible[i])*self.scale)
                    if right>0 and left<CW then Paint(last,left);last=math.max(last,right) end
                end
                Paint(last,CW)
                for i=count+1,#row.textures do row.textures[i]:Hide() end
            end
        end
    end
    function win:Draw()
        self.mapMaster=LCM.IsMaster and LCM.IsMaster() or false
        self.hoverCandidate=nil;self.hoverX=nil;self.hoverAreas={}
        self.zoomAnimation=nil;ResetScene()
        self.pendingZoom=nil
        self.hasBaseMap=not self.carte
        self.markerMap=self:Map(self:Zones())
        self:DrawFog()
        for i=1,usedPin do pinPool[i]:Hide() end
        usedPin=0
        for i=1,usedTri do triPool[i]:Hide() end
        for i=1,usedLine do linePool[i]:Hide() end
        for i=1,usedLabel do labelPool[i]:Hide() end
        usedTri,usedLine,usedLabel=0,0,0
        self.batimentsVus={}
        self:Moi()
        if self.ailleurs then self.ailleurs:Hide() end
        if self.carte then return self:DrawCarte() end
        -- La portee du regard se dit : sans elle, « je ne decouvre rien » ne
        -- distingue pas un brouillard qui marche d'une Vue tombee a zero.
        local rayon,points=ZG:RayonDeVue()
        local vueMot=string.format(" · vue : %d yd%s",math.floor(rayon),
            points and string.format(" (%d pt)",points) or "")
        if self.level=="batiment" then
            self.help:SetText("Clic droit : ressortir · Les chiffres en haut : changer d'étage"..vueMot)
        elseif self.level=="region" then
            self.help:SetText("Clic droit : retour au pays · Clic sur un bâtiment : y entrer"..vueMot)
        elseif self.level=="country" then
            self.help:SetText("Clic : ouvrir une région · Clic droit : voir le continent · Molette : zoom"..vueMot)
        else
            self.help:SetText("Clic : ouvrir une région · Molette : zoom"..vueMot)
        end
        local subs=self:Subs()
        for _,e in ipairs(subs) do
            if IsClosed(e.sub) then
                local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
                for _,pt in ipairs(e.sub.points) do
                    minx,miny=math.min(minx,pt.x),math.min(miny,pt.y)
                    maxx,maxy=math.max(maxx,pt.x),math.max(maxy,pt.y)
                end
                self.hoverAreas[#self.hoverAreas+1]={sub=e.sub,zone=e.zone,
                    minx=minx,miny=miny,maxx=maxx,maxy=maxy,area=math.abs(Area(e.sub.points))}
            end
        end
        table.sort(self.hoverAreas,function(a,b) return a.area<b.area end)
        local surContinent=self.level=="continent"
        if (self.country==nil and not surContinent) or #subs==0 then
            local nom=surContinent and (self.continent and ContinentName(self.continent) or "Carte")
                or (self.country and CountryName(self.country) or "Carte")
            self.title:SetText(nom)
            self.subtitle:SetText("")
            self.empty:SetText((self.country or surContinent) and "Rien à afficher sur cette carte." or "Aucune région Crossings ici.\nChoisissez un pays dans le menu, ou « Carte du jeu » pour la carte habituelle.")
            self.empty:Show()
            return
        end
        self.empty:Hide()

        if self.level=="country" or surContinent then
            if surContinent then
                self.title:SetText(self.continent and ContinentName(self.continent) or "Le monde connu")
                self.subtitle:SetText("Continent · cliquez sur une région")
            else
                self.title:SetText(CountryName(self.country))
                self.subtitle:SetText("Pays · cliquez sur une région")
            end
            -- Une couleur par région ; les lieux n'ont qu'un contour discret.
            local boxes={}
            for _,e in ipairs(subs) do
                if IsClosed(e.sub) then
                    local box=boxes[e.zone.id] or {zone=e.zone}
                    boxes[e.zone.id]=box
                    DrawPolygon(self,e.sub,ZG:ZoneColor(e.zone),.45,box,true)
                end
            end
            for _,box in pairs(boxes) do
                local x,y=(box.minx+box.maxx)/2,(box.miny+box.maxy)/2
                if x>-60 and x<CW+60 and y>-20 and y<CH+20 then
                    Text(x,y,ZoneKnown(box.zone) and (box.zone.name or "") or ZG:MaskText(box.zone.name or ""),Light(ZG:ZoneColor(box.zone)),true,"zone",box.zone)
                end
            end
        else
            local zone=self.zone
            if self.batiment then
                self.title:SetText(PlaceKnown(self.batiment,zone) and (self.batiment.name or "")
                    or ZG:MaskText(self.batiment.name or ""))
                self.subtitle:SetText("Bâtiment · "..(ZoneKnown(zone) and (zone.name or "") or ZG:MaskText(zone.name or ""))
                    .."  ·  étage "..tostring(self.etage or 0))
            else
                self.title:SetText(ZoneKnown(zone) and (zone.name or "") or ZG:MaskText(zone.name or ""))
                self.subtitle:SetText("Région · "..CountryName(self.country))
            end
            local placeLabel={}
            for _,e in ipairs(subs) do
                local sub=e.sub
                local place=sub.enterPlace and ZG:FindPlace(sub.enterPlace)
                local color=SubColor(sub,zone)
                if sub.shape=="polygon" and sub.points and #sub.points>=2 then
                    local screen=DrawPolygon(self,sub,color,.95)
                    -- Le contour de la région — comme l'empreinte d'un
                    -- bâtiment sur sa propre carte — porte un nom déjà en
                    -- titre : l'étiqueter au centre ferait double emploi.
                    if place and not place.pourRegion and not place.batiment and IsClosed(sub) then
                        -- Le nom se place au centre du plus grand périmètre du lieu.
                        local area=math.abs(Area(sub.points))
                        if not placeLabel[place.id] or area>placeLabel[place.id].area then
                            local sx,sy=0,0
                            for _,p in ipairs(screen) do sx,sy=sx+p[1],sy+p[2] end
                            placeLabel[place.id]={x=sx/#screen,y=sy/#screen,area=area,place=place,color=color}
                        end
                    end
                elseif sub.shape~="polygon" then
                    local a,b=LineEnds(sub)
                    local x1,y1=self:ToScreen(a.x,a.y);local x2,y2=self:ToScreen(b.x,b.y)
                    Line(x1,y1,x2,y2,color,4)
                    if place and not placeLabel[place.id] then
                        placeLabel[place.id]={x=(x1+x2)/2,y=(y1+y2)/2-14,area=0,place=place,color=color}
                    end
                end
            end
            for _,l in pairs(placeLabel) do
                if l.x>-40 and l.x<CW+40 and l.y>-20 and l.y<CH+20 then
                    local name=PlaceKnown(l.place,zone) and (l.place.name or "") or ZG:MaskText(l.place.name or "")
                    Text(l.x,l.y,name,Light(l.color),l.area>0,"place",l.place,zone)
                end
            end
            -- Les bâtiments : un point et un nom, pas leurs cloisons. Un clic
            -- dessus ouvre leur carte à eux.
            self.batimentsVus={}
            for _,b in ipairs(self:Batiments()) do
                local x,y=self:ToScreen(b.x,b.y)
                if x>-40 and x<CW+40 and y>-20 and y<CH+20 then
                    Pin(x,y,"libre")
                    local name=PlaceKnown(b.place,zone) and (b.place.name or "") or ZG:MaskText(b.place.name or "")
                    Text(x,y-18,name,Light(COULEUR_BATIMENT),false,"place",b.place,zone)
                    self.batimentsVus[#self.batimentsVus+1]={place=b.place,x=x,y=y}
                end
            end
        end
    end

    -- Région sous un point de l'écran (vue du pays), ou nil.
    function win:RegionAt(ox,oy)
        local wx=self.cx-(ox-CW/2)/self.scale
        local wy=self.cy-(oy-CH/2)/self.scale
        if not ZG:EstVu(self.markerMap,wx,wy) then return nil end
        for _,e in ipairs(self:Subs()) do
            if IsClosed(e.sub) and PointInPolygon(e.sub.points,wx,wy) then return e.zone end
        end
    end


    function win:HideMapTooltip()
        if self.hoverTooltip then self.hoverTooltip:Hide();self.hoverTooltip=nil end
        self.hoverTitle,self.hoverSubtitle=nil,nil
    end
    function win:HoverAt(ox,oy)
        if self.carte or not self.cx or not self.scale then return nil end
        local wx=self.cx-(ox-CW/2)/self.scale
        local wy=self.cy-(oy-CH/2)/self.scale
        if not ZG:EstVu(self.markerMap,wx,wy) then return nil end
        local hit
        if self.hoverX==ox and self.hoverY==oy then hit=self.hoverCandidate else
            for _,a in ipairs(self.hoverAreas or {}) do
                if wx>=a.minx and wx<=a.maxx and wy>=a.miny and wy<=a.maxy
                    and PointInPolygon(a.sub.points,wx,wy) then hit=a;break end
            end
            self.hoverX,self.hoverY,self.hoverCandidate=ox,oy,hit
        end
        if not hit then return nil end
        local place=hit.sub.enterPlace and ZG:FindPlace(hit.sub.enterPlace)
        -- Sur la carte, c'est le LIEU qu'on vise et son cadre qui le situe :
        -- le gras va au lieu, le reste passe dessous en plus fin (voir
        -- ZG:ResolveMapText). La bannière, elle, annonce d'abord qu'on entre
        -- quelque part.
        if place and not place.pourRegion then return ZG:ResolveMapText(place,hit.zone) end
        return ZoneKnown(hit.zone) and hit.zone.name or ZG:MaskText(hit.zone.name),CountryName(hit.zone.countryId or NONE)
    end
    function win:UpdateMapTooltip()
        if self.carte or self.drag or self.zoomAnimation or self.pendingZoom or not canvas:IsMouseOver() then
            self:HideMapTooltip();return
        end
        local mx,my=GetCursorPosition();local scale=canvas:GetEffectiveScale()
        local left,top=canvas:GetLeft(),canvas:GetTop()
        if not left or not top then self:HideMapTooltip();return end
        local ox,oy=mx/scale-left,top-my/scale
        if ox<0 or ox>CW or oy<0 or oy>CH then self:HideMapTooltip();return end
        local title,subtitle=self:HoverAt(ox,oy)
        if not title then self:HideMapTooltip();return end
        local tooltip=self.hoverTooltip or LCM.UI.Infobulle()
        if not self.hoverTooltip or title~=self.hoverTitle or subtitle~=self.hoverSubtitle then
            tooltip:SetOwner(canvas,"ANCHOR_RIGHT");tooltip:SetText(title)
            if subtitle and subtitle~="" then tooltip:AddLine(subtitle,.8,.77,.7) end
            self.hoverTitle,self.hoverSubtitle=title,subtitle
        end
        self.hoverTooltip=tooltip
        local es=UIParent:GetEffectiveScale()
        tooltip:ClearAllPoints();tooltip:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",mx/es+16,my/es-16)
        tooltip:Show()
    end
    canvas:SetScript("OnLeave",function() win:HideMapTooltip() end)

    -- Molette : zoom autour du curseur ; glisser : déplacer la vue.
    canvas:EnableMouse(true);canvas:EnableMouseWheel(true)
    local function FinishZoom()
        local animation=win.zoomAnimation
        if not animation then return end
        local queued=win.pendingZoom
        win.zoomAnimation=nil
        ResetScene()
        if not animation.drawn then
            win.cx,win.cy,win.scale=animation.target.cx,animation.target.cy,animation.target.scale
            win:Draw()
        end
        win.pendingZoom=queued
    end
    local function ApplyZoom(immediate)
        local pending=win.pendingZoom
        if not pending then return end
        win.pendingZoom=nil
        local old={cx=win.cx,cy=win.cy,scale=win.scale}
        if immediate then
            win.cx,win.cy,win.scale=pending.cx,pending.cy,pending.scale;win:Draw();return
        end
        local animation={target=pending,time=0,duration=.16}
        if pending.scale<old.scale then
            -- Au dézoom, dessiner la destination d'abord : aucune bande vide
            -- ne rentre dans le viewport pendant que l'image se réduit.
            win.cx,win.cy,win.scale=pending.cx,pending.cy,pending.scale;win:Draw()
            local ratio=old.scale/pending.scale
            animation.from={ratio,CW/2*(1-ratio)+(old.cx-pending.cx)*old.scale,
                CH/2*(1-ratio)+(old.cy-pending.cy)*old.scale}
            animation.to={1,0,0};animation.drawn=true
        else
            -- Au zoom, agrandir l'image existante ; affiner une fois à l'arrivée.
            local ratio=pending.scale/old.scale
            animation.from={1,0,0}
            animation.to={ratio,CW/2*(1-ratio)+(pending.cx-old.cx)*pending.scale,
                CH/2*(1-ratio)+(pending.cy-old.cy)*pending.scale}
        end
        win.zoomAnimation=animation
        TransformScene(unpack(animation.from))
    end
    canvas:SetScript("OnMouseWheel",function(_,delta)
        if not win.scale or not win.cx or not win.cy or delta==0 then return end
        -- Accumuler les crans sans toucher à la caméra effectivement dessinée.
        local target=win.zoomAnimation and win.zoomAnimation.target or win
        local p=win.pendingZoom or {cx=target.cx,cy=target.cy,scale=target.scale,age=0}
        local s=math.max(MIN_SCALE,math.min(MAX_SCALE,p.scale*(1.25^delta)))
        if s==p.scale then return end
        local mx,my=GetCursorPosition();local es=canvas:GetEffectiveScale()
        local left,top=canvas:GetLeft(),canvas:GetTop()
        if left and top then
            local ox,oy=mx/es-left,top-my/es
            local wx=p.cx-(ox-CW/2)/p.scale;local wy=p.cy-(oy-CH/2)/p.scale
            p.cx=wx+(ox-CW/2)/s;p.cy=wy+(oy-CH/2)/s
        end
        p.scale,p.quiet=s,0
        win.pendingZoom=p
    end)
    canvas:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" then return end
        FinishZoom();ApplyZoom(true)
        local mx,my=GetCursorPosition()
        win.drag={mx=mx,my=my,cx=win.cx,cy=win.cy}
    end)
    -- Un clic sans glisser, dans la vue du pays, ouvre la région cliquée ;
    -- un clic droit dans une région revient à son pays.
    canvas:SetScript("OnMouseUp",function(_,button)
        if button=="RightButton" then
            -- Dans un bâtiment, on ressort d'abord vers sa région.
            if win.level=="batiment" and not win.carte then win:ShowRegion(win.zone)
            elseif win.level=="region" and not win.carte then win:OpenCountry(win.country)
            -- Et d'un pays, on remonte à son continent : la carte du monde
            -- est au bout de la même touche.
            elseif win.level=="country" and not win.carte then win:ShowContinent(win.continent) end
            return
        end
        local drag=win.drag;win.drag=nil
        if button~="LeftButton" or not drag then return end
        local mx,my=GetCursorPosition()
        if math.abs(mx-drag.mx)+math.abs(my-drag.my)>4 then return end
        local es=canvas:GetEffectiveScale();local left,top=canvas:GetLeft(),canvas:GetTop()
        if not left or not top then return end
        local ox,oy=mx/es-left,top-my/es
        -- Un clic sur le point d'un bâtiment ouvre sa carte, à tous les
        -- niveaux où ce point se montre.
        for _,b in ipairs(win.batimentsVus or {}) do
            if math.abs(ox-b.x)<=14 and math.abs(oy-b.y)<=14 then win:ShowBatiment(b.place);return end
        end
        if win.level~="country" and win.level~="continent" then return end
        local zone=win:RegionAt(ox,oy)
        if zone then win:ShowRegion(zone) end
    end)

    local terrainCheck,labelCheck=0,0
    win:SetScript("OnUpdate",function(self,dt)
        local master=LCM.IsMaster and LCM.IsMaster() or false
        if self.mapMaster~=master then self:HideMapTooltip();self:Draw() end
        local p=self.pendingZoom
        if p then
            p.quiet=p.quiet+dt;p.age=p.age+dt
            -- Une rafale définit une destination ; la scène rejoint celle-ci
            -- en animation, avec un seul calcul géométrique par transition.
            if not self.zoomAnimation and (p.quiet>=.05 or p.age>=.14) then ApplyZoom() end
        end
        local animation=self.zoomAnimation
        if animation then
            animation.time=math.min(animation.duration,animation.time+dt)
            local t=animation.time/animation.duration
            local eased=t*t*(3-2*t)
            local a,b=animation.from,animation.to
            TransformScene(a[1]+(b[1]-a[1])*eased,a[2]+(b[2]-a[2])*eased,a[3]+(b[3]-a[3])*eased)
            if t>=1 then FinishZoom() end
        end
        -- Le marqueur reste actualisé, même pendant la transition.
        self:Moi()
        terrainCheck=terrainCheck+dt
        if terrainCheck>=.1 then
            terrainCheck=0
            if not self.carte and not self.zoomAnimation then self:DrawFog() end
            self:UpdateMapTooltip()
        end
        if self.drag then
            local mx,my=GetCursorPosition();local es=canvas:GetEffectiveScale()
            local cx=self.drag.cx+(mx-self.drag.mx)/es/self.scale
            local cy=self.drag.cy-(my-self.drag.my)/es/self.scale
            if cx~=self.cx or cy~=self.cy then self.cx,self.cy=cx,cy;self:Draw() end
            return
        end
        -- Les noms appris changent sans reconstruire les polygones.
        labelCheck=labelCheck+dt
        if labelCheck>=1 and not self.carte then
            labelCheck=0
            if self.country then
                self:MajSelecteurs()
                if self.level=="country" then self.title:SetText(CountryName(self.country))
                elseif self.zone then
                    local region=ZoneKnown(self.zone) and self.zone.name or ZG:MaskText(self.zone.name)
                    if self.batiment then
                        self.title:SetText(PlaceKnown(self.batiment,self.zone) and self.batiment.name or ZG:MaskText(self.batiment.name))
                        self.subtitle:SetText("Bâtiment · "..region)
                    else self.title:SetText(region);self.subtitle:SetText("Région · "..CountryName(self.country)) end
                end
            end
            for i=1,usedLabel do
                local f=labelPool[i]
                if f.knownEntry then
                    local known=f.knownKind=="zone" and ZoneKnown(f.knownEntry)
                        or f.knownKind=="place" and PlaceKnown(f.knownEntry,f.knownRegion)
                    local name=f.knownEntry.name or ""
                    local text=known and name or ZG:MaskText(name)
                    if f:GetText()~=text then f:SetText(text) end
                end
            end
        end
        -- Franchir une frontière ne change ni la carte affichée ni sa caméra.
    end)
    -- Une réouverture sur la même carte conserve le cadrage et le voile.
    -- Premier affichage ou changement de carte physique : choisir le contexte.
    win:SetScript("OnShow",function(self)
        if self.carte then return end
        pickerContinent:Show();picker:Show();pickerRegion:Show()
        local _,_,_,instance=ZG:GetPlayerPose()
        if self.openInstance==instance and self.cx and self.scale and self.hasBaseMap then
            self:DrawFog();self:Moi();return
        end
        self.openInstance=instance
        self:ShowCurrent()
        local b=self:BatimentIci()
        if b then self:ShowBatiment(b) end
    end)
    win:HookScript("OnHide",function(self) FinishZoom();self.pendingZoom=nil;self:HideMapTooltip() end)
    UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"LCMCrossingsRegionMap")
end

function ZG:ShowRegionMap()
    if not win then Build() end
    win.carte=nil
    if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
    win:Show()
end

-- Une carte lue (Core/Cartes.lua) dans la même fenêtre que la carte des
-- régions : on y voit la même chose, en moins.
function ZG:ShowCarteLue(vue)
    if not win then Build() end
    if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
    win.carte=vue
    win:Show()
    win:ShowCarte(vue)
end

function ZG:ShowGameMap()
    if win then win:Hide() end
    if WorldMapFrame and WorldMapFrame:IsShown() then return end
    if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then ShowUIPanel(WorldMapFrame) end
end

-- Touche M (ou celle de la carte du jeu) : bascule la carte de région ;
-- carte du jeu ouverte, elle la ferme comme d'habitude.
function ZG:ToggleRegionMap()
    if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame);return end
    if win and win:IsShown() then win:Hide() else ZG:ShowRegionMap() end
end

-- ── Raccourci ───────────────────────────────────────────────────────────
-- Surcharge des touches de la carte du jeu (impossible en combat : on
-- attend la fin du combat). Les raccourcis du joueur ne sont pas modifiés.
local toggle=CreateFrame("Button","LCMCrossingsMapToggle",UIParent)
toggle:SetScript("OnClick",function() ZG:ToggleRegionMap() end)
local binder=CreateFrame("Frame")
local bound,applied=false,nil
-- Ne refait la surcharge que si les touches voulues ont changé : poser une
-- surcharge déclenche lui-même UPDATE_BINDINGS.
local function Bind()
    local keys=bound and table.concat({GetBindingKey("TOGGLEWORLDMAP")},",") or ""
    if keys==applied then return end
    if InCombatLockdown and InCombatLockdown() then binder:RegisterEvent("PLAYER_REGEN_ENABLED");return end
    applied=keys
    ClearOverrideBindings(binder)
    if not bound then return end
    for _,key in ipairs({GetBindingKey("TOGGLEWORLDMAP")}) do
        SetOverrideBindingClick(binder,true,key,"LCMCrossingsMapToggle")
    end
end
binder:SetScript("OnEvent",function(self,event)
    if event=="PLAYER_REGEN_ENABLED" then self:UnregisterEvent("PLAYER_REGEN_ENABLED") end
    Bind()
end)
binder:RegisterEvent("UPDATE_BINDINGS")

function ZG:BindMapKey() bound=true;Bind();if ZG.worldMapButton then ZG.worldMapButton:Show() end end
function ZG:UnbindMapKey()
    bound=false;Bind()
    if win then win:Hide() end
    if ZG.worldMapButton then ZG.worldMapButton:Hide() end
end

-- Bouton « Carte de région » sur la carte du jeu.
local function AttachWorldMapButton()
    if not WorldMapFrame or ZG.worldMapButton then return end
    local b=UI.CreatePanelButton(WorldMapFrame,150,24,"Carte de région")
    local anchor=WorldMapFrame.ScrollContainer or WorldMapFrame
    b:SetPoint("TOPLEFT",anchor,"TOPLEFT",10,-10)
    b:SetFrameStrata("HIGH");b:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1)+50)
    b:SetScript("OnClick",function() ZG:ShowRegionMap() end)
    b:SetShown(bound)
    WorldMapFrame:HookScript("OnShow",function() b:SetShown(bound) end)
    ZG.worldMapButton=b
end
local loader=CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent",function(_,event,name)
    if event=="PLAYER_LOGIN" or name=="Blizzard_WorldMap" then AttachWorldMapButton() end
end)
