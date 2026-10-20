-- Papier et encre partagent la meme surface courbe, projetee en perspective.
local _, LCM = ...
local UI = LCM.UI
local A = {}
UI.LivresAnimation = A
local atlas = UI.LivresGlyphes
local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\livres\\"
local NX, NY = 24, 6
local PI = math.pi
local function Doux(p) return p * p * (3 - 2 * p) end

-- Les quatre sommets ne restent pas rectangulaires : chaque petit carre de
-- papier devient un quadrilatere. Les coordonnees de l'interface montent en Y.
local function Quad(t, parent, points)
    local minx, miny, maxx, maxy = points[1].x, points[1].y, points[1].x, points[1].y
    for i = 2, 4 do
        local p = points[i]
        minx, miny, maxx, maxy = math.min(minx,p.x), math.min(miny,p.y), math.max(maxx,p.x), math.max(maxy,p.y)
    end
    local w, h = math.max(0.01,maxx-minx), math.max(0.01,maxy-miny)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",minx,-miny)
    t:SetSize(w,h)
    local coins = { {minx,miny}, {minx,miny+h}, {minx+w,miny}, {minx+w,miny+h} }
    for i=1,4 do t:SetVertexOffset(i,points[i].x-coins[i][1],coins[i][2]-points[i].y) end
end

function A.Projeter(u,v,p,direction,mode)
    local q = Doux(p)
    local note = mode == "note"
    local couverture = mode == "ouvrir" or mode == "fermer"
    if mode == "fermer" then q = 1-q end
    local theta = PI*q
    local courbure = couverture and 0 or 1.05*math.sin(theta)
    -- Le coin inferieur commence avant le bord superieur : la feuille se tord.
    local angle = theta + (couverture and 0 or 0.19*math.sin(theta)*(v-0.5))
    local largeur = couverture and (400-65*q) or (note and 400 or 335)
    local hauteur = couverture and (560-141*q) or (note and 550 or 419)
    local x,z,normal
    if note then
        x=(u-0.5)*largeur*math.cos(angle)
        z=(u-0.5)*largeur*math.sin(angle)
        normal=math.cos(angle)
    elseif courbure < 0.00001 then
        x=u*largeur*math.cos(angle);z=u*largeur*math.sin(angle);normal=math.cos(angle)
    else
        local debut=angle-courbure
        local fin=debut+2*courbure*u
        x=largeur*(math.sin(fin)-math.sin(debut))/(2*courbure)
        z=largeur*(math.cos(debut)-math.cos(fin))/(2*courbure)
        normal=math.cos(fin)
    end
    local perspective=1600/(1600-z)
    local centreX,centreY=note and 200 or 450,note and 275 or 267
    local charniere = couverture and -200*(1-q) or 0
    if couverture then centreY=300-33*q end
    local marge = (note or couverture) and (couverture and 12*q*math.cos(angle) or 0) or 12*math.cos(angle)
    return { x=centreX+charniere+direction*(x+marge)*perspective,
        y=centreY+((v-0.5)*hauteur-0.12*z)*perspective,z=z,face=normal,
        sx=centreX+charniere+direction*(x+marge)+0.16*z,
        sy=centreY+(v-0.5)*hauteur+0.06*z }
end

-- Mise en page de l'atlas : les memes glyphes servent au repos et en mouvement.
-- Aucun texte du personnage n'est transforme en fichier ou modifie en sauvegarde.
function A.Composer(texte, taille, largeur, alignement)
    local facteur=taille/atlas.taille
    local lignes, ligne, longueur = {}, {}, 0
    local function Finir() lignes[#lignes+1]={lettres=ligne,largeur=longueur};ligne={};longueur=0 end
    for paragraphe in (tostring(texte or "").."\n"):gmatch("(.-)\n") do
        for mot, espaces in paragraphe:gmatch("(%S+)(%s*)") do
            local lettres, avance={},0
            for c in mot:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                local g=atlas.lettres[c] or atlas.lettres["?"]
                lettres[#lettres+1]={c=c,g=g};avance=avance+g[1]*facteur
            end
            if longueur>0 and longueur+avance>largeur then Finir() end
            for _,l in ipairs(lettres) do
                local a=l.g[1]*facteur
                if longueur>0 and longueur+a>largeur then Finir() end
                l.x=longueur;ligne[#ligne+1]=l;longueur=longueur+a
            end
            if espaces~="" then longueur=longueur+atlas.lettres[" "][1]*facteur end
        end
        Finir()
    end
    local resultat={}
    local interligne=taille*1.25
    for i,l in ipairs(lignes) do
        local dx=alignement=="CENTER" and math.max(0,(largeur-l.largeur)/2) or 0
        for _,c in ipairs(l.lettres) do
            local g=c.g
            resultat[#resultat+1]={x=dx+c.x+g[2]*facteur,y=(i-1)*interligne+(atlas.ascente+g[3])*facteur,
                w=g[4]*facteur,h=g[5]*facteur,u0=g[6],v0=g[7],u1=g[8],v1=g[9]}
        end
    end
    return resultat,#lignes*interligne
end

local function Dessiner(parent,ancien,glyphes,couleur)
    ancien=ancien or {}
    for i,g in ipairs(glyphes) do
        local t=ancien[i]
        if not t then t=parent:CreateTexture(nil,"OVERLAY");t:SetTexture(ART.."encre-caudex.tga");ancien[i]=t end
        t:ClearAllPoints();t:SetPoint("TOPLEFT",parent,"TOPLEFT",g.x,-g.y);t:SetSize(g.w,g.h)
        t:SetTexCoord(g.u0,g.u1,g.v0,g.v1);t:SetVertexColor(unpack(couleur));t:Show()
    end
    for i=#glyphes+1,#ancien do ancien[i]:Hide() end
    return ancien
end

function A.Encrer(page)
    -- Conserver le rendu natif pour les alphabets non couverts et les balises
    -- WoW : mieux vaut une transition sans encre que remplacer leur contenu.
    local compatible=true
    for _,champ in ipairs({page.titre,page.texte,page.numero}) do
        local texte=champ:GetText() or ""
        if texte:find("|[cHrTtA]") then compatible=false end
        for c in texte:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            if c~="\n" and c~="\r" and c~="\t" and not atlas.lettres[c] then compatible=false end
        end
    end
    if not compatible then
        for _,liste in ipairs({page.encreTitre or {},page.encreCorps or {},page.encreNumero or {}}) do
            for _,t in ipairs(liste) do t:Hide() end
        end
        page.titre:Show();page.texte:Show();page.numero:Show();page.encre=nil
        return
    end
    local er,eg,eb=page.texte:GetTextColor()
    local ar,ag,ab=page.titre:GetTextColor()
    local _,tailleTitre=page.titre:GetFont()
    local titre, ht=A.Composer(page.titre:GetText(),tailleTitre or 22,page.largeur,"CENTER")
    local haut=(page.titre:GetText() or "")~="" and ht+17 or 6
    local corps,hc=A.Composer(page.texte:GetText(),14,page.largeur-4,page.texte:GetJustifyH())
    local numero=A.Composer(page.numero:GetText(),11,page.largeur,"CENTER")
    for _,g in ipairs(numero) do g.y=g.y+page.hauteur-14 end
    page.zone:ClearAllPoints();page.zone:SetPoint("TOPLEFT",page,"TOPLEFT",0,-haut)
    page.zone:SetHeight(math.max(50,page.hauteur-haut-27));page.zone:Regler(hc+12);page.zone:Aller(0)
    page.encreTitre=Dessiner(page,page.encreTitre,titre,{ar,ag,ab})
    page.encreCorps=Dessiner(page.zone.contenu,page.encreCorps,corps,{er,eg,eb})
    page.encreNumero=Dessiner(page,page.encreNumero,numero,{ar,ag,ab})
    page.titre:Hide();page.texte:Hide();page.numero:Hide()
    page.encre={titre=titre,corps=corps,numero=numero,haut=haut,couleur={er,eg,eb},accent={ar,ag,ab}}
end

function A.Capturer(page,side,mode)
    local resultat={}
    if not page or not page.encre or not page:IsShown() then return resultat end
    local e=page.encre
    local note=mode=="note" or mode=="couverture"
    local ox,oy=page.pageX or 0,page.pageY or 0
    local function Ajouter(liste,dy,couleur,clipHaut,clipBas)
        for _,g in ipairs(liste) do
            local y=g.y+dy
            if not clipHaut or (y>=clipHaut and y+g.h<=clipBas) then
                local function U(x) return note and (side>0 and x/400 or 1-x/400) or (side>0 and (x-462)/335 or (438-x)/335) end
                local function V(v) return note and v/(mode=="couverture" and 560 or 550) or (v-57.5)/419 end
                resultat[#resultat+1]={u0=U(ox+g.x),u1=U(ox+g.x+g.w),v0=V(oy+y),v1=V(oy+y+g.h),
                    tex={g.u0,g.u1,g.v0,g.v1},couleur=couleur}
            end
        end
    end
    Ajouter(e.titre,0,e.accent)
    Ajouter(e.corps,e.haut-(page.zone.decalage or 0),e.couleur,e.haut,page.hauteur-27)
    Ajouter(e.numero,0,e.accent)
    return resultat
end

function A.Creer(parent)
    local f=CreateFrame("Frame",nil,parent)
    f:SetAllPoints(parent)
    f.cellules,f.glyphes={},{}
    for i=1,NX*NY do
        local c=CreateFrame("Frame",nil,f);c:SetAllPoints(f)
        c.image=c:CreateTexture(nil,"ARTWORK")
        c.ombre=f:CreateTexture(nil,"BACKGROUND")
        c.ombre:SetColorTexture(0.07,0.04,0.01,0)
        c.glyphes={}
        f.cellules[i]=c
    end
    f:Hide()
    return f
end

local function TexturePapier(t,u0,u1,v0,v1,face,direction,mode)
    if mode=="note" then
        t:SetTexture(ART.."note.tga")
        if face<0 then u0,u1=1-u0,1-u1 end
        t:SetTexCoord(u0,u1,0.125+0.75*v0,0.125+0.75*v1)
    elseif (mode=="ouvrir" or mode=="fermer") and face>0 then
        t:SetTexture(ART.."necronicon-couverture.tga")
        t:SetTexCoord(u0,u1,0.125+0.75*v0,0.125+0.75*v1)
    else
        t:SetTexture(ART.."necronicon-ouvert.tga")
        local cote=direction*(face>0 and 1 or -1)
        local debut,fin=cote>0 and 0.515 or 0.484,cote>0 and 0.884 or 0.115
        local haut,plage=170/1024,683/1024
        t:SetTexCoord(debut+(fin-debut)*u0,debut+(fin-debut)*u1,
            haut+(0.095+0.699*v0)*plage,haut+(0.095+0.699*v1)*plage)
    end
end

function A.Rendre(f,p,direction,mode,recto,verso,teinte)
    local cellules,grille={},{}
    local function Points(u0,u1,v0,v1)
        return { A.Projeter(u0,v0,p,direction,mode),A.Projeter(u0,v1,p,direction,mode),
            A.Projeter(u1,v0,p,direction,mode),A.Projeter(u1,v1,p,direction,mode) }
    end
    for iy=1,NY do for ix=1,NX do
        local u0,u1,v0,v1=(ix-1)/NX,ix/NX,(iy-1)/NY,iy/NY
        local points=Points(u0,u1,v0,v1)
        local milieu=A.Projeter((u0+u1)/2,(v0+v1)/2,p,direction,mode)
        cellules[#cellules+1]={points=points,z=milieu.z,face=milieu.face,u0=u0,u1=u1,v0=v0,v1=v1,ix=ix,iy=iy}
    end end
    table.sort(cellules,function(a,b)return a.z<b.z end)
    local base=f:GetFrameLevel()+2
    for i,d in ipairs(cellules) do
        local c=f.cellules[i]
        c.nombreGlyphes=0
        grille[(d.iy-1)*NX+d.ix]={cadre=c,donnees=d}
        c:SetFrameLevel(base+math.floor(math.max(0,d.z)*2))
        Quad(c.image,c,d.points)
        TexturePapier(c.image,d.u0,d.u1,d.v0,d.v1,d.face,direction,mode)
        local lumiere=0.72+0.28*math.abs(d.face)
        c.image:SetVertexColor(teinte[1]*lumiere,teinte[2]*lumiere,teinte[3]*lumiere)
        local ombre={}
        for j,point in ipairs(d.points) do ombre[j]={x=point.sx,y=point.sy} end
        Quad(c.ombre,f,ombre)
        c.ombre:SetColorTexture(0.07,0.04,0.01,0.18*math.sin(PI*p))
    end
    f.glyphes={}
    local function Encre(liste,face)
        for _,g in ipairs(liste or {}) do
            local minU,maxU=math.min(g.u0,g.u1),math.max(g.u0,g.u1)
            -- L'encre est decoupee aux memes coutures que le papier. Trier un
            -- glyphe entier separement cachait des morceaux sous la cellule voisine.
            for iy=math.max(1,math.floor(g.v0*NY)+1),math.min(NY,math.ceil(g.v1*NY)) do
                for ix=math.max(1,math.floor(minU*NX)+1),math.min(NX,math.ceil(maxU*NX)) do
                    local cellule=grille[(iy-1)*NX+ix]
                    local c,d=cellule.cadre,cellule.donnees
                    if d.face*face>0.025 then
                        local u0,u1=math.max(minU,d.u0),math.min(maxU,d.u1)
                        if g.u0>g.u1 then u0,u1=u1,u0 end
                        local v0,v1=math.max(g.v0,d.v0),math.min(g.v1,d.v1)
                        local function U(u) return g.tex[1]+(g.tex[2]-g.tex[1])*(u-g.u0)/(g.u1-g.u0) end
                        local function V(v) return g.tex[3]+(g.tex[4]-g.tex[3])*(v-g.v0)/(g.v1-g.v0) end
                        c.nombreGlyphes=c.nombreGlyphes+1
                        local t=c.glyphes[c.nombreGlyphes]
                        if not t then t=c:CreateTexture(nil,"OVERLAY");t:SetTexture(ART.."encre-caudex.tga");c.glyphes[c.nombreGlyphes]=t end
                        Quad(t,c,Points(u0,u1,v0,v1))
                        t:SetTexCoord(U(u0),U(u1),V(v0),V(v1));t:SetVertexColor(unpack(g.couleur));t:Show()
                        f.glyphes[#f.glyphes+1]=t
                    end
                end
            end
        end
    end
    Encre(recto,1);Encre(verso,-1)
    for _,c in ipairs(f.cellules) do
        for i=c.nombreGlyphes+1,#c.glyphes do c.glyphes[i]:Hide() end
    end
end
