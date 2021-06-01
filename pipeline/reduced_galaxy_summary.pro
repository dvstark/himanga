;this code goes through all reduced galaxies, regardless of whether or
;not they are finalized, and pulls out key information. In this case: 
;
;plateifu
;integration time
;rms
;session info

pro collect_info,info

;info = [] ;we'll populate this with the pameters we extract
first_time=1
reduced_dir = '/users/dstark/17AGBT012/reduced/'

reduced_subdir = ['cfielder_copy','cwithers_copy','dfinnega','dstark','eharring','ewarrick','jgoddy','kmasters','nsamanso','nwolthui','pfofie_copy','reaglin','sdillon_copy','sshamsi','asharma']

for i=0,n_elements(reduced_subdir)-1 do begin

   for check_final=0,1 do begin
      
      if check_final eq 0 then files = file_search(reduced_dir + reduced_subdir[i]+'/*par.sav') $
      else files = file_search(reduced_dir + reduced_subdir[i] + '/final/*par.sav')

      if files[0] ne '' then begin
         for j=0,n_elements(files)-1 do begin
            restore,files[j]
            print,files[j]
            row = {name:par.name,rms:par.statinfo.rms,snr:(par.awvinfo.peak-par.statinfo.rms)/par.statinfo.rms > 0,tint:par.obsinfo.tint,sessions:par.obsinfo.sessions}
            if first_time then begin
               info = [row] 
               first_time = 0
            endif else info = [info,row]
         endfor
      endif
      
   endfor
  endfor


end


collect_info,info
save,info,filename='~/17AGBT012/reduced/reduced_galaxy_info_03Feb2021.sav'

;assess which galaxies need more time

restore,'~/17AGBT012/reduced/reduced_galaxy_info_03Feb2021.sav'
;remove any duplicates

;get unique names first
u=uniq(info.name,sort(info.name))
unique_names = info[u].name

remove = intarr(n_elements(info))

for i=0,n_elements(unique_names)-1 do begin
   sel=where(info.name eq unique_names[i],count)
   if count gt 1 then begin
      print,info[sel].tint
      mintime = min(info[sel].tint,index)
      remove[sel[index]]=1
   endif
endfor

info = info[where(remove eq 0)]      




sel=where(info.tint lt 600. and info.tint gt 0)
print,n_elementS(sel)

cgplot,info.tint,info.rms*1.2,psym=4,xtitle='integration time, ON only [s]',ytitle='rms [Jy]',xrange=[0,1500],yrange=[0.0005,0.006]
cgplot,info[sel].tint,info[sel].rms*1.2,psym=4,color='red',/overplot
cgplot,[0,1500],[0.0015,0.0015],color='blue',thick=3,linestyle=2,/overplot
sel=where(info.tint gt 600 and info.tint lt 750)
cgplot,info[sel].tint,info[sel].rms*1.2,psym=4,color='orange',/overplot

sel=where(info.tint gt 850 and info.tint lt 950)
print,median(info[sel].rms*1.2),robust_sigma(info[sel].rms*1.2)
cgplot,[0,1500],[0.0015,0.0015]+robust_sigma(info[sel].rms*1.2),/overplot
cgplot,[0,1500],[0.0015,0.0015]+2*robust_sigma(info[sel].rms*1.2),/overplot

;if we get more observations for everything with <2 full scans done

sel=where(info.tint lt 600. and info.tint gt 450,count)
scans = count*1
sel=where(info.tint lt 450 and info.tint gt 0,count)
scans = scans + count*2
time = scans*36./3.
print,time/60.

;or everyhing with <2.5 full scans done

sel=where(info.tint lt 2.5*300 and info.tint gt 0,count) ;those with <2.5 scans, 1 scan = 300 s (ON)
incomplete = info[sel]
add_scans = intarr(n_elements(incomplete))

sel=where(incomplete.tint lt 750 and incomplete.tint gt 450)
add_scans[sel]=1.
sel=where(incomplete.tint lt 450 and incomplete.tint gt 0)
add_Scans[sel]=2

keep_observing = {name:'',tint:0d,rms:0d,snr:0d,sessions:'',add_scans:0}
keep_observing = replicate(keep_observing,n_elementS(incomplete))
keep_observing.name = incomplete.name
keep_observing.tint = incomplete.tint
keep_observing.rms = incomplete.rms
keep_observing.snr = incomplete.snr
keep_observing.sessions = incomplete.sessions
keep_observing.add_scans = add_scans

mwrfits,keep_observing,'~/17AGBT012/master/catalogs/hi-manga_incomplete_03Feb2021.fits',/create

stop

sel=where(info.tint lt 750. and info.tint gt 450,count)
scans = count*1
sel=where(info.tint lt 450 and info.tint gt 0,count)
scans = scans + count*2
time = scans*36./3.
print,time/60.

sel=where(info.tint lt 750. and info.tint gt 0,count)
print,count

end
