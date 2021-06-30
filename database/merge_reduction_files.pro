pro merge_reduction_files,input_paths,output_path,log=log,make_catalog=make_catalog,nocopy=nocopy,nile_mod=nile_mod ;#,overwrite=overwrite

;This routine merges all the finalized MaNGA-HI data reduction files
;and puts them into the same directory.  The program checks for
;1) duplicates
;2) incomplete data sets
;
;01-31-2020 -- added nile_mod.  Set this to just copy everything from
;              Nile's "final" directory first.  The reason for this is
;              that Nile analyzed galaxies using old reduction
;              routines and a few hundred galaxies lack *par.sav
;              files.  I'm just copying her stuff first without
;              checking for the presnce of all 4 file types (because
;              they don't exist!).  Then the code proceeds to copy
;              everything else...if there's a duplicate of one of
;              Nile's files, her files will get overwritten.  I'm not
;              willing to write anything more elaborate to deal with
;              such cases at this point.


if 1-keyword_set(log) then log = 'merge_files_log_'+strcompress(systime(),/remove_all)+'.txt'
  openw,1,log,width=1000
  printf,1,'merge_reduction_files.pro started at ',systime()

  if keyword_set(nile_mod) then begin
     print,'copying old format files from Nile Samanso directory first. These files will not be reflected in the log file.'
     print,'Approximate number of files: ',n_elements(file_search('/users/dstark/17AGBT012/reduced/nsamanso/final/mangaHI-*.csv')) - n_elements(file_search('/users/dstark/17AGBT012/reduced/nsamanso/final/*par.sav'))
     spawn,'cp /users/dstark/17AGBT012/reduced/nsamanso/final/* '+output_path
  endif


  ;collect all files
  file_list = ['']
  file_origin = ['']

  for i=0,n_elements(input_paths)-1 do begin
     newfiles = file_search(input_paths[i]+'*par.sav')
     if newfiles[0] ne '' then begin
        file_origin = [file_origin,strarr(n_elementS(newfiles))+input_paths[i]]
        file_list = [file_list,newfiles]
        printf,1,input_paths[i],', files found:',n_elements(newfiles)
     endif else printf,1,input_paths[i],', files found:    0'

  endfor
  
  ;split off the name at the end
  file_name = strarr(n_elements(file_list))
  galaxy_name = strarr(n_elements(file_list))

  for i=0,n_elementS(file_name)-1 do begin
     sub = strsplit(file_list[i],'/',/extract)
     file_name[i] = sub[n_elements(sub)-1]
     galaxy_name[i] = (strsplit(file_name[i],'_',/extract))[0]
  endfor

  count = n_elementS(file_name)
  file_name = file_name[1:count-1]
  file_list = file_list[1:count-1]
  file_origin = file_origin[1:count-1]
  galaxy_name = galaxy_name[1:count-1]
  
  ;create flags for (1) missing files (2) duplicates
  missing_files=intarr(n_elements(file_name))
  ;duplicate flag below
  
  ;check that all other files are present for each galaxy
  for i=0,n_elements(file_name)-1 do begin
     files = [galaxy_name[i] + '.fits','mangaHI-'+galaxy_name[i]+'.csv','mangaHI-'+galaxy_name[i]+'.fits']
     exists = file_test(file_origin[i]+files)
     if total(exists) lt 3 then begin
        missing_files[i]=1
        printf,1,' '
        printf,1,'MISSING DATA FILES'
        printf,1,file_origin[i]+files[where(1-exists)]
     endif
  endfor

  ;find any duplicates
  unique = intarr(n_elements(file_name))
  unique[uniq(file_name,sort(file_name))]=1

  usel=wherE(unique eq 0,count)
  if count gt 0 then begin
     printf,1,''
     printf,1,'DUPLICATE FILES FOUND'
     for i=0,count-1 do begin
        sel=where(file_name eq file_name[usel[i]])
        printf,1,file_list[sel]
        unique[sel]=0
        printf,1,''
     endfor
  endif

  duplicate = 1-unique

  sel=where(1-duplicate and 1-missing_files,ngood)
  print,'total good files to be copied:',ngood
  print,'files being ignored (check log): ',n_elements(missing_files)-ngood
  
  printf,1,''
  printf,1,'total good files to be copied:',ngood
  printf,1,'files being ignored: ',n_elements(missing_files)-ngood

  close,1

  ;now copy files
  if 1-keyword_set(nocopy) then begin
     print,'copying files...'
     sel=where(1-duplicate and 1-missing_files)
     for i=0,n_elements(sel)-1 do begin
;        print,'copying files for '+strtrim(galaxy_name[sel[i]],2)
        ;see if this file already exists in the output directory. 
        spawn,'cp '+file_origin[sel[i]]+galaxy_name[sel[i]] + '.fits '+output_path
        spawn,'cp '+file_origin[sel[i]]+galaxy_name[sel[i]] + '_par.sav '+output_path
        spawn,'cp '+file_origin[sel[i]]+'mangaHI-'+galaxy_name[sel[i]]+'.csv '+output_path
        spawn,'cp '+file_origin[sel[i]]+'mangaHI-'+galaxy_name[sel[i]]+'.fits '+output_path
     endfor
  endif

end
     
     


merge_reduction_files,'/users/dstark/17AGBT012/reduced/'+['cfielder_copy','cwithers_copy','dfinnega','dstark','eharring','ewarrick','jgoddy','kmasters','nsamanso','nwolthui','pfofie_copy','reaglin','sdillon_copy','sshamsi', 'gshapiro', 'jgarland', 'jturner', 'jwashington', 'rhladky', 'rlanggin', 'asharma']+'/final/','/users/dstark/17AGBT012/master/reduction_files/',log='/users/dstark/17AGBT012/master/reduction_files/file_merge_log_23Jun2021.txt',/nile_mod

end

