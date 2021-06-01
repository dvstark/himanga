function get_drpall_info,plateifu,drpcat,check=check

  sel=where(strtrim(plateifu,2) eq strtrim(drpcat.plateifu,2),count)
  if count eq 0 then begin
     print, 'warning, no match in drpall file found for '+plateifu
     return,{mangaid:-999.,objra:-999.,objdec:-999.,logmstars:-999.,b_a:-999.}
  endif else begin
     if keyword_set(check) then stop
     return,{mangaid:drpcat[sel].mangaid,objra:drpcat[sel].objra,objdec:drpcat[sel].objdec,logmstars:alog10(drpcat[sel].nsa_elpetro_mass),b_a:drpcat[sel].nsa_elpetro_ba}
  endelse

  end

function get_row_template

  row_template = {plateifu:'',$
                  mangaid:'',$
                  objra:0d,$
                  objdec:0d,$
                  logmstars:0d,$
                  sini:0d,$
                  vopt:-999.,$
                  session:'',$
                  exp:-999.,$
                  rms:-999.,$
                  loghilim200kms:-999.,$
                  peak:-999.,$
                  snr:-999.,$
;                snr_alt:-999.,$
                  fhi:-999.,$
                  efhi:-999.,$
                  logmhi:-999.,$
                  vhi:-999.,$
                  ev:-999.,$
                  wm50:-999.,$
                  wp50:-999.,$
                  wp20:-999.,$
                  w2p50:-999.,$
                  wf50:-999.,$
                  pr:-999.,$
                  pl:-999.,$
                  ar:-999.,$
                  br:-999.,$
                  al:-999.,$
                  bl:-999.}
  return,row_template
  
end


pro make_mangahi_catalog,outname,list=list,path=path,addcat=addcat,nullvalue=nullvalue,overwrite_entries=overwrite_entries,add_cat_mult=add_cat_mult

;Program to combine the individual *par_.sav files from our GBT
;reductions and put them into a single easy to read catalog.
;
;Has the option of inputing a list of files, or supplying a path in
;which case it will find all files with *par.sav and combine them
;
;update history
;
;at some point: (DS) Written
;
;June 4, 2019: (DS) modified S/N calculation to be S/N = (peak -
;              rms)/rms. Also added in calculation of (random) error
;              on integrated HI flux
;
;June 19, 2019: (DS) Added ability to add in other catalogs.  Main
;motivation here is to allow us to create this catalog with dr1
;already in it
;
;June 24, 2019: (DS) Added routine to replace 0s with -999. Note, this
;may be a problem if there's a measurement that is legitimately
;supposed to be 0
;
;May 15, 2020: (DS) Added a correction for cases whre flux uncertainty
;was missing because the min/max velocities used for line integrtion
;were not recorded (2016 and N. Samanso data)
;
;Nov 27, 2020: (DS) Added the "overwrite_entries" option. To be used
;when addcat keyword is set, will cause any entries to be replaced by
;entries in addcat if they are for the same target. Also added
;add_mult_cat keyword which allows values from catalogs added via the
;"addcat" keyword to be scaled. This was needed because the 2016
;catalog had some units in mJy while our newer catalog used Jy.
;
;Jan 25, 2020: (DS) Added the visual classifications here (they were
;previously incorporated into analyses at later stages) -- ended up
;making this a separate program
;

drpallfile = '~/17AGBT012/idl_routines/drpall-v3_0_1.fits'

db=mrdfits(drpallfile,1)

if n_params() eq 0 then begin
   print,'useage: make_mangahi_catalog,outname,list=list,path=path'
   return
endif

if 1-keyword_set(path) and 1-keyword_set(list) then begin
   print,'Provide either list of files or directory'
   return
endif

if keyword_set(path) then begin
   ;create list all files at this path
   list = file_search(path+'*par.sav')
endif

if n_elements(list) eq 0 then begin
   print,'Error empty list supplied'
   return
endif

if 1-keyword_set(nullvalue) then nullvalue=-999

if 1-keyword_set(overwrite_entries) then overwrite_entries=0

row_template = get_row_template()

for i=0,n_elements(list)-1 do begin

   row = row_template
   restore,list[i]
   row.plateifu = par.name

   ;get manga id, objra, objdec, mstars, and inclin from the drpall file
   sel=where(strtrim(db.plateifu,2) eq strtrim(par.name,2),count)
   if count eq 0 then begin
      print,'WARNING: FAILED TO FIND MATCH IN DRPALL FILE FOR '+par.name
      continue
   endif

   row.mangaid = db[sel].mangaid
   row.objra = db[sel].objra
   row.objdec = db[sel].objdec
   row.logmstars = alog10(db[sel].nsa_elpetro_mass)
   b_a = db[sel].nsa_elpetro_ba > 0.2
   cosi_squared = (b_a^2-0.2^2)/(1-0.2^2)
   row.sini = sqrt(1-cosi_squared)
   
   row.vopt = par.obsinfo.vopt
   row.session = par.obsinfo.sessions
   row.exp = par.obsinfo.tint
   row.rms = par.statinfo.rms*1000.
   row.loghilim200kms = par.logmhilim200kms
   row.peak = par.awvinfo.peak
;   row.snr = par.awvinfo.snr
   row.snr = (par.awvinfo.peak - par.statinfo.rms)/par.statinfo.rms*(par.awvinfo.peak ne 0)
   wsmo = par.awvinfo.wf50/(2*10.)*(par.awvinfo.wf50 lt 400) + 400./(2*10.)*(par.awvinfo.wf50 ge 400)
;   row.snr_alt =  (1000*par.awvinfo.fhi/par.awvinfo.wf50)*sqrt(wsmo)/row.rms
   row.fhi = par.awvinfo.fhi
;   print,row.snr,row.snr_alt


   ;determine the channel size
   z=par.obsinfo.vopt/2.998e5
   nu_rest = 1.4204050e9
   dnu = 5.722e3
   ;channel size is dnu/dnu_obs*c (check into 1+z corrections)
   dv = dnu/(nu_rest/(1+z))*2.998e5
   smo = 4*2. ;boxcar by 4, then hanning reduces res by factor of 2
   dv=dv*smo
   
   row.efhi = par.statinfo.rms*dv*sqrt(par.awvinfo.xmax - par.awvinfo.xmin)
   row.logmhi = par.logmhi
   row.vhi = par.awvinfo.vhi
   row.ev = par.awvinfo.ev
   row.wm50 = par.awvinfo.wm50
   row.wp50 = par.awvinfo.wp50
   row.wp20 = par.awvinfo.wp20
   row.w2p50 = par.awvinfo.w2p50
   row.wf50 = par.awvinfo.wf50
   row.pr = par.awvinfo.pr
   row.pl = par.awvinfo.pl
   row.ar = par.awvinfo.ar
   row.br = par.awvinfo.br
   row.al = par.awvinfo.al
   row.bl = par.awvinfo.bl

  

   if i eq 0 then cat = row else cat = [cat,row]
endfor

print,'finished creating catalog. Size = ',n_elements(cat)

;if addcat is set, cycle through those input catalogs and apply fixes
for i=0,n_elements(addcat)-1 do begin
   add = mrdfits(addcat[i],1)
   print,'adding existing catalog: '+addcat[i]
   print,'catalog size: ',n_elements(add)

                                ;if any catalog entries need to be
                                ;multiplied to correct units, do now
   if keyword_set(add_cat_mult) then begin
      cat_fixes = add_cat_mult[i]
      ;get tags which need fixing
      fix_tags = tag_names(cat_fixes)
      main_tags = tag_names(add)

      for tt=0,n_elements(fix_tags)-1 do begin
         ;find tag index
         tag_ind = where(main_tags eq fix_tags[tt],count)
         if count eq 0 then stop else begin
            s=where(add.(tag_ind) ne -999)
            add[s].(tag_ind) = add[s].(tag_ind)*cat_fixes.(tt)
         endelse

      endfor
    endif

   for j=0,n_elements(add)-1 do begin
      row=row_template
      struct_assign,add[j],row
      ;fetch the relevant drpall catalog stuff
      out = get_drpall_info(add[j].plateifu,db)
      print,out
      row.mangaid = out.mangaid
      row.objra = out.objra
      row.objdec = out.objdec
      row.logmstars = out.logmstars
      b_a = out.b_a > 0.2
      cosi_squared = (b_a^2-0.2^2)/(1-0.2^2)
      row.sini = sqrt(1-cosi_squared)

                                ;if replace entries is set and this
                                ;entry exists,
                                ;overwrite. Otherwise,skip
      sel=where(strtrim(cat.plateifu,2) eq strtrim(row.plateifu,2),count,complement=keep)
      if count gt 1 then stop
      if count eq 1 then begin
         if overwrite_entries eq 1 then begin
            cat = cat[keep]
            cat = [cat,row]
         endif
      endif else cat = [cat,row] ;entry doesn't exist yet
   endfor
endfor

;go through and replace 0's or infinities with whatever null
;value is specified as

ntags = n_tags(cat)
tagnames = tag_names(cat)
for i=0,ntags-1 do begin
   if tagnames[i] ne 'PLATEIFU' and tagnames[i] ne 'MANGAID' and tagnames[i] ne 'SESSION' then begin
      sel=where(cat.(i) eq 0 or 1-finite(cat.(i)),count)
      if count gt 0 then cat[sel].(i) = nullvalue
   endif
endfor

;write out catalog, but make sure we don't overwrite one that
;already exists

print,'preparing to write output file: '+outname
if file_test(outname) then begin
   print,'Output filename already exists. Overwrite (y/n)?'
   answer=''
   read,answer
   if strlowcase(answer) ne 'y' then begin
      print,'Input new file name'
      read,answer
      outname=answer
   endif
endif





print,'Generating catalog: '+outname

mwrfits,cat,outname,/create

end

pro merge_mangahi_nile,mangahicat,nilecat

  drpallfile = '~/17AGBT012/idl_routines/drpall-v3_0_1.fits'

  db=mrdfits(drpallfile,1)

  row_template = get_row_template()

                                ;script to merge Nile Samanso's HI
                                ;catalog (created before our
                                ;standardized MaNGA-HI pipeline) with
                                ;the output catalog using the standard
                                ;pipeline data. The script only uses
                                ;Nile's catalog values if they are not
                                ;already in the standard MaNGA-HI
                                ;catalog because several of her
                                ;galaxies were redone for various
                                ;reasons.



  mangahi = mrdfits(mangahicat,1)
  nilehi = mrdfits(nilecat,1)


  match,strtrim(mangahi.plateifu,2),strtrim(nilehi.plateifu,2),ind1,ind2

  hasmatch = intarr(n_elements(nilehi))
  hasmatch[ind2]=1
  sel=where(1-hasmatch,count)
  if count eq 0 then begin
     print,'nothing to add from Nile catalog'
     return
  endif

  nilehi = nilehi[where(1-hasmatch)]
  
  print,'adding ',n_elements(nilehi),'galaxies from N. Samanso reductions'

  for j=0,n_elements(nilehi)-1 do begin
     row=row_template
     struct_assign,nilehi[j],row
      ;fetch the relevant drpall catalog stuff
      out =  get_drpall_info(nilehi[j].plateifu,db)
      if out.objra eq -999 then continue
      row.mangaid = out.mangaid
      row.objra = out.objra
      row.objdec = out.objdec
      row.logmstars = out.logmstars
      b_a = out.b_a > 0.2
      cosi_squared = (b_a^2-0.2^2)/(1-0.2^2)
      row.sini = sqrt(1-cosi_squared)
     mangahi = [mangahi,row]
  endfor

mwrfits,mangahi,mangahicat,/create


end

pro fix_errors,mangahicat

 ;Data from 2016 and data reduced by Nile Samanso lack the xmin/xmax
 ;measurements for line flux
                                ;calculation.  Replace with W20 ~
                                ;W50+20 (see Kannappan et al. 2013 for
                                ;the reference; I recall using it for
                                ;this paper)

  cat=mrdfits(mangahicat,1)

  usew50 = cat.wf50
  sel=where(cat.snr gt 0 and usew50 lt 0,count)
  if count gt 0 then usew50[sel] = cat[sel].w2p50
  ;if all else fails assume 200
  sel=where(cat.snr gt 0 and usew50 lt 0,count)
  if count gt 0 then usew50[sel]=200

  ;replace missing error measurements
  sel=where(cat.efhi le 0 and cat.snr gt 0,count)
  if count eq 0 then return

  if total(usew50[sel] lt 0) gt 0 then begin
     print,'error! some "detections" lacking linewidths which should not happen!'
     stop
  endif

                                ;recover dv using spectral resolution
                                ;(this is all hard coded so will not
                                ;be adaptive to different setups!)
  dnu = 5.722e3 ;Hz
  restfreq = 1.420405e9 ;21cm line
  z = cat.vopt/2.998e5
  obsfreq = restfreq/(1+z)
  dv = dnu/obsfreq*2.998e5
  dv = dv*4.*2. ;boxcar by 4 then hanning

  cat[sel].efhi = cat[sel].rms/1000*dv[sel]*sqrt(usew50[sel]+20)/sqrt(dv[sel])

  mwrfits,cat,mangahicat,/create

end


pro sortcat,mangahicat  

  cat = mrdfits(mangahicat,1)
  srt = sort(strtrim(cat.plateifu,2))
  cat = cat[srt]
  mwrfits,cat,mangahicat,/create


end

pro replace_zeros,catfile,nullvalue=nullvalue

  if 1-keyword_set(nullvalue) then nullvalue = -999

  cat = mrdfits(catfile,1)

  ntags = n_tags(cat)
  tagnames = tag_names(cat)
  for i=0,ntags-1 do begin
     if tagnames[i] ne 'PLATEIFU' and tagnames[i] ne 'MANGAID' and tagnames[i] ne 'SESSION' then begin
        sel=where(cat.(i) eq 0 or 1-finite(cat.(i)),count)
        if count gt 0 then cat[sel].(i) = nullvalue
     endif
  endfor

  mwrfits,cat,catfile,/create

end

pro scale_flux,catfile,scale

;scales all fluxes by a factor (scale). This is used to apply the
;factor of 1.2 needed to correct the default flux calibration

  fix_tags = ['RMS','LOGHILIM200KMS','PEAK','FHI','EFHI','LOGMHI']
  cat=mrdfits(catfile,1)
  tags = tag_names(cat)

  session = strtrim(cat.session,2)
  
  ;rms
  sel=where(cat.rms ne -999 and session ne 'ALFALFA')
  print,n_elements(sel)
  print,minmax(cat[sel].rms)
  cat[sel].rms = scale*cat[sel].rms
  print,minmax(cat[sel].rms)

  ;loghilim200kms
  sel=where(cat.loghilim200kms ne -999 and session ne 'ALFALFA')
  print,n_elements(sel)
  print,minmax(cat[sel].loghilim200kms)
  cat[sel].loghilim200kms = cat[sel].loghilim200kms + alog10(scale)
  print,minmax(cat[sel].loghilim200kms)

  ;peak
  sel=where(cat.peak ne -999 and session ne 'ALFALFA')
  print,n_elements(sel)
  print,minmax(cat[sel].peak)
  cat[sel].peak = scale*cat[sel].peak
  print,minmax(cat[sel].peak)

  ;fhi
  sel=where(cat.fhi ne -999 and session ne 'ALFALFA')
  print,n_elements(sel)
  print,minmax(cat[sel].fhi)
  cat[sel].fhi = scale*cat[sel].fhi
  print,minmax(cat[sel].fhi)

  ;efhi
  sel=where(cat.efhi ne -999 and session ne 'ALFALFA')
  print,n_elements(sel)
  print,minmax(cat[sel].efhi)
  cat[sel].efhi = scale*cat[sel].efhi
  print,minmax(cat[sel].efhi)

  ;logmhi
  sel=where(cat.logmhi ne -999 and session ne 'ALFALFA')
  print,n_elements(sel)
  print,minmax(cat[sel].logmhi)
  cat[sel].logmhi = cat[sel].logmhi + alog10(scale)
  print,minmax(cat[sel].logmhi)

  mwrfits,cat,catfile,/create

end

pro cosmocor,catfile

  ;apply 1+z factors where necessary
  cat=mrdfits(catfile,1)
  z = cat.vopt/2.998e5

  ;mass upper limit
  sel=where(cat.loghilim200kms gt 0)
  cat[sel].loghilim200kms = cat[sel].loghilim200kms-2*alog10(1+z[sel])

  ;mass
  sel=where(cat.logmhi gt 0)
  cat[sel].logmhi = cat[sel].logmhi - 2*alog10(1+z[sel])

  ;linewidths
  sel=where(cat.wm50 gt 0)
  cat[sel].wm50 = cat[sel].wm50/(1+z[sel])

  sel=where(cat.wp50 gt 0)
  cat[sel].wp50 = cat[sel].wp50/(1+z[sel])

  sel=where(cat.wp20 gt 0)
  cat[sel].wp20 = cat[sel].wp20/(1+z[sel])

  sel=where(cat.w2p50 gt 0)
  cat[sel].w2p50 = cat[sel].w2p50/(1+z[sel])

  sel=where(cat.wf50 gt 0)
  cat[sel].wf50 = cat[sel].wf50/(1+z[sel])

  mwrfits,cat,catfile,/create

end

pro widthcor,catfile
  print,'calculating linewidth corrections'
  cat=mrdfits(catfile,1)
  z = cat.vopt/2.998e5

  dv=5.
  snr = (cat.peak*1000-cat.rms)/cat.rms
  logsnr = alog10(snr)
  lambda = 0.005*(logsnr < 0.6) + $
           (-0.4685+0.785*logsnr)*(logsnr > 0.6 and logsnr < 1.1) + $
           0.395*(logsnr > 1.1)

  dW = 2*dv*lambda/(1+z)

  ;apply dW to linewidth measurements
  sel=where(cat.wm50 gt 0)
  cat[sel].wm50 = cat[sel].wm50-dW[sel]

  sel=where(cat.wp50 gt 0)
  cat[sel].wp50 = cat[sel].wp50-dW[sel]

  sel=where(cat.wp50 gt 0)
  cat[sel].wp20 = cat[sel].wp20-dW[sel]

  sel=where(cat.w2p50 gt 0)
  cat[sel].w2p50 = cat[sel].w2p50-dW[sel]

  sel=where(cat.wf50 gt 0)
  cat[sel].wf50 = cat[sel].wf50-dW[sel]

  sel=where(snr lt 0)
  dW[sel]=-999

  ;add to the catalog
  struct_add_field,cat,'dW',dW,after='WF50'

  mwrfits,cat,catfile,/create


end

pro rename_struct_tags,str,newnames,oldnames=oldnames

;renames structure tags. If oldname is not specified, the current tag
;names are used. newname and oldname must have same number of elements.

  tags = tag_names(str)
  n_tags = n_elementS(tags)

  if 1-keyword_set(oldnames) then oldnames = tags

  if n_elements(oldnames) ne n_elements(newnames) then begin
     print,'ERROR RENAMING STRUCTURE TAGS'
     print,'number of elements in newname and oldname must match'
     return
  endif

  ;create new structure using first tag
  for i=0,n_elements(oldnames)-1 do begin
     
     sel=where(tags eq oldnames[i],count)
     if count eq 0 then begin
        print,'ERROR IN RENAME_STRUCT_TAGS'
        print,oldnames[i]+' not found in tags'
        return
     endif

     if i eq 0 then newstr = create_struct(newnames[i],str.(sel)) $
     else newstr = create_struct(newstr,newnames[i],str.(sel))

  endfor

  str = newstr

end


pro add_visflags,catfile,vis_flag_file
  
  print,'Adding visual classification flags'
  cat=mrdfits(catfile,1)

  flags = read_csv(vis_flag_file,header=header,n_table_header=1)  
  rename_struct_tags,flags,header ;just renaming tags based on column names

  negdet = intarr(n_elementS(cat))
  blstruct = intarr(n_elements(cat))

  match,strtrim(cat.plateifu,2),strtrim(flags.plateifu,2),ind1,ind2
  negdet[ind1] = flags.critical_negdet[ind2]
  blstruct[ind1] = flags.wobble[ind2]

    ;add to the catalog
  struct_add_field,cat,'negdet',negdet
  struct_add_field,cat,'blstruct',blstruct
  mwrfits,cat,catfile,/create

  

end

;; uncomment to run

;; catalog_name = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_020620.fits'

;; make_mangahi_catalog,'/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_020620.fits',path='/users/dstark/17AGBT012/master/reduction_files/',addcat=['/users/dstark/17AGBT012/master/catalogs/mangaHIall.fits','/users/dstark/17AGBT012/master/catalogs/manga_mpl8_alfalfa_gbtformat.fits']

;; merge_mangahi_nile,catalog_name,'/users/dstark/17AGBT012/reduced/nsamanso/nsamanso_reduced.fits'

;; sortcat,catalog_name

;; replace_zeros,catalog_name

;; scale_flux,catalog_name,1.2


;;;;;;;;just gbt;;;;;
catalog_name = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_022321_gbtonly.fits'
vis_flag_file = '/users/dstark/17AGBT012/master/catalogs/HI-MaNGA_visual_inspection_gbt_spectra.csv'

addcatmult = [{peak:1./1000.}]

make_mangahi_catalog,catalog_name,overwrite_entries=0,path='/users/dstark/17AGBT012/master/reduction_files/',addcat=['/users/dstark/17AGBT012/master/catalogs/mangaHIall.fits'],add_cat_mult=addcatmult;,'/users/dstark/17AGBT012/master/catalogs/manga_mpl8_alfalfa_gbtformat.fits']

merge_mangahi_nile,catalog_name,'/users/dstark/17AGBT012/reduced/nsamanso/nsamanso_reduced.fits'

sortcat,catalog_name

replace_zeros,catalog_name

fix_errors,catalog_name

scale_flux,catalog_name,1.2

cosmocor,catalog_name

widthcor,catalog_name

add_visflags,catalog_name,vis_flag_file



;;;;;;;;;final tweak to remove some bad entries from our 2016 release
;;;;;;;;;catalog
;;;;Nov 25-2020, dont need this stuff anymore
;t=mrdfits(catalog_name,1)
;sel=where(strtrim(t.plateifu,2) eq '8082-6101' and strtrim(t.session,2) eq '16A-3',complement=nsel)
;t=t[nsel]
;sel=where(strtrim(t.plateifu,2) eq '8247-6103' and strtrim(t.session,2) eq '16A;-5',complement=nsel)
;t=t[nsel]
;sel=where(strtrim(t.plateifu,2) eq '8551-12704' and strtrim(t.session,2) eq '16;A-7',complement=nsel)
;t=t[nsel]
;sel=where(strtrim(t.plateifu,2) eq '8551-6101' and strtrim(t.session,2) eq '16A-7',complement=nsel)
;t=t[nsel]
;
;mwrfits,t,catalog_name,/create
;
end

; To do: fix 2016 "peak" units, check for duplicates (Generaize end of
; code above)
