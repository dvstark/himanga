;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;WRAPPER TO GENERATE HI-MANGA CATALOG;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;
;START EDITING HERE;
;;;;;;;;;;;;;;;;;;;;

;name of final catalog (after combining with ALFALFA data)
final_catalog_name = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr3_063021'

;name of output catalog (just with GBT data)
catalog_name = final_catalog_name+'_gbtonly';'/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_062321_gbtonly.fits'

;add .fits on the end
final_catalog_name = final_catalog_name+'.fits'
catalog_name = catalog_name + '.fits'

;name of visual inspections file
vis_flag_file = '/users/dstark/17AGBT012/master/catalogs/HI-MaNGA_visual_inspection_gbt_spectra.csv'

;name of alfalfa hi-manga catalog
alfalfa_catalog = '/users/dstark/17AGBT012/master/catalogs/manga_mpl11_alfalfa_wconf_062921_gbtformat.fits'

;;;;;;;;;;;;;;;;;;;
;STOP EDITING HERE;
;;;;;;;;;;;;;;;;;;;

;start by compiling the GBT data
addcatmult = [{peak:1./1000.}] ;convert the peak fluxes down to Jy
make_mangahi_catalog,catalog_name,overwrite_entries=0,path='/users/dstark/17AGBT012/master/reduction_files/',addcat=['/users/dstark/17AGBT012/master/catalogs/mangaHIall.fits'],add_cat_mult=addcatmult;,'/users/dstark/17AGBT012/master/catalogs/manga_mpl8_alfalfa_gbtformat.fits']

;merge in Nile's reductions (except in cases where they've been redone)
merge_mangahi_nile,catalog_name,'/users/dstark/17AGBT012/reduced/nsamanso/nsamanso_reduced.fits'

;sort by plate-ifu
sortcat,catalog_name

;replace zero with -999
replace_zeros,catalog_name

;fix errors for 2016 and Nile's reductions where we lacked
;xmin/xmax needed for the calculation
fix_errors,catalog_name

;apply the flux scale correction Goddy et al. 2020)
scale_flux,catalog_name,1.2

;apply cosmological corrections to relevant quantities
cosmocor,catalog_name

;apply corrections to linewidths to account for instrumental broadening
widthcor,catalog_name

;add visual classification flags (only for HI-MaNGA DR2 thus far)
add_visflags,catalog_name,vis_flag_file

;run confusion flagging code (identifies optical counterparts for each
;beam, estimates confusion likelihood).
answer=''
print,'Run optical match finder (for confusion flagging)? This step will take ~10 minutes'
read,answer
if strupcase(answer) eq 'Y' or strupcase(answer) eq 'YES' then begin
   find_optical_matches_himangacat,catalog_name
endif

;merge with ALFALFA data for HI-MaNGA
print,'merging GBT data with ALFALFA catalog'
command = '/opt/local/bin/python /users/dstark/17AGBT012/python_routines/merge_himanga_catalogs.py '+catalog_name + ' '+ alfalfa_catalog + ' '+final_catalog_name
print,command
spawn,command

end
