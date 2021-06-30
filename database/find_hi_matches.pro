pro find_hi_matches,czname,czra,czdec,cz,czerr,czwidth,hiname,hira,hidec,hicz,hiw50,matchrad,outfile,dupfile=dupfile

;matches a redshift catalog (or any catalog) against an HI catalog.
;Inputs are:

;czname -- name of object (just some identifier)
;czra -- ra of cz catalog (deg)
;czdec -- dec in cz catalog (deg)
;cz -- redshift in km/s
;czerr -- error in redshift in km/s
;czwidth -- assumed linewidth of all galaxies
;hiname -- name of HI detection (just some identifier)
;hira -- ra of hi detection
;hidec -- dec of hi detection
;hicz -- hi redshift
;hiw50 -- known linewidth
;matchrad -- radius over which to search for companions (e.g., the
;            beam size)
;outfile -- output file
;dupfile -- file with coordinates of redshifts that are duplicates
;           (i.e., a redshift already exists for that object).  Should
;be a structure called "dup" with two arrays of ra and dec

;Matches the full redshift catalog from Mark against the a40 catalog.
;This will allow us to reliably find sources that are confused.  For
;now, this focuses on galaxies in the velocity range defined by the
;JUSHR catalog (2500 - 7000 km/s, with 500 km/s border), same for the
;                      ra range, but with a 4 arcminute buffer zone


if file_test(outfile) eq 1 then begin
   print,'output file already exists, continue?'
   stop
endif

matchrad=matchrad/60 ;in degrees
if n_elements(matchrad) eq 1 then matchrad=fltarr(n_elements(hira))+matchrad
if n_elements(czwidth) eq 1 then czwidth=fltarr(n_elements(hira))+czwidth

t0=systime(/seconds)

;trim all arrays so they don't extend over vastly different
;coordinates

minra=min([hira])
maxra=max([hira])
mindec=min([hidec])
maxdec=max([hidec])
minv=min([hicz])
maxv=max([hicz])

sel=where(czra gt minra-max(matchrad) and czra lt maxra+max(matchrad) and czdec gt mindec-max(matchrad) and czdec lt maxdec+max(matchrad) and cz gt minv-1000 and cz lt maxv+1000)

czname=czname[sel]
czra=czra[sel]
czdec=czdec[sel]
cz=cz[sel]
czerr=czerr[sel]
czwidth=czwidth[sel]

;remove any already known duplicates if user wants to.  
if keyword_set(dupfile) then begin
   restore,dupfile
   srcor,czra/15.d,czdec,dup.ra/15.d,dup.dec,.1,ind1,ind2,spherical=1,option=1
   if ind1[0] ne -1 then begin
      isdup=bytarr(n_elements(czra))
      isdup[ind1]=1
      sel=where(isdup eq 0)
      czname=czname[sel]
      czra=czra[sel]
      czdec=czdec[sel]
      cz=cz[sel]
      czerr=czerr[sel]
      czwidth=czwidth[sel]
      print,''
      print,'Ignoring '+strtrim(string(round(total(isdup))),2)+' known duplicate redshifts'
      print,''
      stop
   endif
endif

minra=min([czra])
maxra=max([czra])
mindec=min([czdec])
maxdec=max([czdec])
minv=min([cz])
maxv=max([cz])
sel=where(hira gt minra-max(matchrad) and hira lt maxra+max(matchrad) and hidec gt mindec-max(matchrad) and hidec lt maxdec+max(matchrad) and hicz gt minv-1000 and hicz lt maxv+1000)

hiname=hiname[sel]
hira=hira[sel]
hidec=hidec[sel]
hicz=hicz[sel]
hiw50=hiw50[sel]
matchrad=matchrad[sel]

;apply minimum linewidth
hiw50 = hiw50 > 20.

matchcount=fltarr(n_elements(hira))

;;;why not replace assumed linewidth with real line width if there is one
;srcor,hira/15.,hidec,czra/15.,czdec,60.,ind1,ind2,spherical=1,option=1
;czwidth[ind2]=hiw50[ind1]

;cycle through each HI source, and match to each optical source
print,''
print,'Matching underway!'
print,'sources in HI catalog:',n_elements(hira)
print,'sources in redshift catalog:',n_elements(czra)
print,''

matchrad=matchrad*3600. ;in arcseconds now

match=0
himatchindex=0
czmatchindex=0
for i=0L,n_elements(hira)-1 do begin
   ;print,i,hira[i],hidec[i],hicz[i]
   for j=0L,n_elements(czra)-1 do begin
      srcor,hira[i]/15.,hidec[i],czra[j]/15.,czdec[j],matchrad[i],ind1,ind2,spherical=1,silent=1
      if ind1[0] ne -1 then begin
         ;see if they match in velocity space as well
         ;extent of radio data is +/- half the line width
;         himaxextent=hicz[i]+1.5*hiw50[i]/2.
;         himinextent=hicz[i]-1.5*hiw50[i]/2.
         himaxextent=hicz[i]+hiw50[i]/2.+10 ;assumes W20 - W50 = 20
         himinextent=hicz[i]-hiw50[i]/2.+10
         hirange=indgen(round(himaxextent-himinextent))+round(himinextent)
         
         ;match in velocity
         sel=where(czerr[j] ge 0,count)
         if count gt 0 then begin
            czmaxextent=cz[j]+czerr[j]+czwidth[j]/2.
            czminextent=cz[j]-czerr[j]-czwidth[j]/2.
            if czmaxextent ne czminextent then czrange=indgen(round(czmaxextent-czminextent))+round(czminextent) else czrange = round(czminextent)
            match,hirange,czrange,ind1,ind2
         
            if ind1[0] ne -1 then begin
               print,'match!'
               print,i,j
               print,himaxextent,himinextent
               print,czmaxextent,czminextent
               matchcount[i]=matchcount[i]+1
               himatchindex=[himatchindex,i]
               czmatchindex=[czmatchindex,j]
            endif
         endif
      endif
   endfor
endfor

czmatchindex=czmatchindex[1:n_elements(czmatchindex)-1]
himatchindex=himatchindex[1:n_elementS(himatchindex)-1]

;which are confused?
;this confusion flag is not final; there are some duplicates in the
;redshift database which may be causing a lot of this.  They will need
;to be sorted out by eye
bestmatch=fltarr(n_elements(himatchindex))
conflag=bytarr(n_elements(himatchindex))
dist=fltarr(n_elements(himatchindex))
for i=0,max(himatchindex) do begin
   sel=where(himatchindex eq i,count)

   if count eq 1 then begin
      bestmatch[sel]=1
      ddec=abs(hidec[himatchindex[sel]]-czdec[czmatchindex[sel]])*!dtor
      dra= abs(hira[himatchindex[sel]]-czra[czmatchindex[sel]])*!dtor

      dist[sel]=2*asin(sqrt(sin(ddec/2.)^2+cos(hidec[himatchindex[sel]]*!dtor)*cos(czdec[czmatchindex[sel]]*!Dtor)*sin(dra/2.)^2)) ;angular distance (haversine formula)
   endif

   if count gt 1 then begin
      conflag[sel]=1.
                                ;determine which is the "best" match (closest)
                                ;dist=sqrt((hira[himatchindex[sel]]-czra[czmatchindex[sel]])^2+(hidec[himatchindex[sel]]-czdec[czmatchindex[sel]])^2)
                                ;not quite correct
      ddec=abs(hidec[himatchindex[sel]]-czdec[czmatchindex[sel]])*!dtor
      dra= abs(hira[himatchindex[sel]]-czra[czmatchindex[sel]])*!dtor

      dist[sel]=2*asin(sqrt(sin(ddec/2.)^2+cos(hidec[himatchindex[sel]]*!dtor)*cos(czdec[czmatchindex[sel]]*!dtor)*sin(dra/2.)^2)) ;angular distance (haversine formula)

      minval=min(dist[sel],index)
      bestmatch[sel[index]]=1
   endif

endfor

czname=czname[czmatchindex]
czra=czra[czmatchindex]
czdec=czdec[czmatchindex]
cz=cz[czmatchindex]
czerr=czerr[czmatchindex]

hiname=hiname[himatchindex]
hira=hira[himatchindex]
hidec=hidec[himatchindex]
hicz=hicz[himatchindex]

;put everything into a structure
matches={hiname:hiname,hira:hira,hidec:hidec,hicz:hicz,himatchindex:himatchindex,czname:czname,czra:czra,czdec:czdec,cz:cz,czerr:czerr,czmatchindex:czmatchindex,conflag:conflag,bestmatch:bestmatch,dist:dist}



;save,matches,filename=outfile
newmatches=fixtablestruct(matches)
mwrfits,newmatches,outfile,/create


;save,czname,czra,czdec,cz,czerr,hiname,hira,hidec,hicz,conflag,bestmatch,himatchindex,filename=outfile

t1=systime(/seconds)

deltat=(t1-t0)/60.

print,'done in ',deltat,' minutes'
print,''

sel=wherE(conflag eq 1)

confilename=(strsplit(outfile,'.',/extract))[0]+'_confused.txt'


openw,1,confilename
printf,1,'HImatchindex      ra        dec       conflag'
for i=0,n_elements(sel)-1 do printf,1,strtrim(string(himatchindex[sel[i]]),2),czra[sel[i]],czdec[sel[i]]
close,1


print,'Place contents of '+ confilename + ' SDSS image list tool and inspect for any duplicate redshifts.  Add a "0" on the end of the row if the object is not really confused.  Add a "1" if it is a duplicate redshift for a single object and should be ignored. See clean_confile.readme for futher info."
print,''
print,'Copy into terminal to quickly open '+confilename
print,''
print,'spawn, "emacs '+confilename+ ' &"'
print,''
print,'When finished noting duplicates, run clean_confile'
;print,''
;print,'clean_confile,"'+outfile+'","'+confilename+', dupfile='+dupfile'

end
