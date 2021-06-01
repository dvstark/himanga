function parse_summary,infile

  filein,infile
  summary,'temp_summary.txt'

  ;read this in and store in a structure
  readcol,'temp_summary.txt',F='I,A,F,A,I,F,I,I,I,F,F',scan,source,vel,proc,seq,restf,nif,nint,nfd,az,el


  ;create structure to hold this info
  summary = {scan:0,source:'',vel:0.,proc:'',seq:0,restf:0.,nif:0,nint:0,nfd:0,az:0.,el:0.,projid:'',scan_id:'',datapath:''}
  summary = replicate(summary,n_elements(scan))

  summary.scan = scan
  summary.source = source
  summary.vel = vel
  summary.proc = proc
  summary.seq = seq
  summary.restf = restf
  summary.nif = nif
  summary.nint = nint
  summary.nfd = nfd
  summary.az = az
  summary.el = el
  summary[*].datapath = strtrim(infile,2)


  ;get the program and sessoin info

                                ;due to session ids like 150b and
                                ;156b, I need to change how we get the
                                ;projid. Lets now get it from the file name
  getrec,0
  file_root = strsplit(infile,'.raw.vegas',/regex,/extract)
  file_root = strsplit(file_root,'/',/extract)
  file_root = file_root[n_elements(file_root)-1]

  summary[*].projid = strtrim(file_root,2)  
  summary.scan_id = strtrim(file_root,2) + '_'+strtrim(string(summary.scan),2)
;  summary[*].projid = strtrim(!g.s[0].projid,2)  
;  summary.scan_id = strtrim(summary.projid,2) + '_'+strtrim(string(summary.scan),2)

  return,summary

end

function scan_exists,db1,db2
  
  ;checks whether entries from db1 are already in db2
  db1_id = db1.projid+'_'+strtrim(string(db1.scan),2)
  db2_id = db2.projid+'_'+strtrim(string(db2.scan),2)
  
  exists = intarr(n_elements(db1))
  match,db1_id,db2_id,ind1,ind2
  if ind1[0] ne -1 then exists[ind1] = 1

  return,exists

end

pro update_scan_db,input,dbfile,create=create

if 1-keyword_set(create) and 1-file_test(dbfile) then begin
   print,'dbfile does not yet exist. Creating'
   create=1
endif


if keyword_set(create) then begin

                                ;just create new db file, but
                                ;first check that it doesn't
                                ;already exists

   if file_test(dbfile) then begin
      answer = ''
      print,'Database already exists. Overwrite (Y/N)?'
      read,answer
      if strupcase(answer) ne 'Y' then begin
         print,'Exiting'
         return 
      endif else begin
         print,'replacing file: ',dbfile
      endelse

   endif

   mwrfits,input,dbfile,/create

endif else begin

   ;load db file
   db = mrdfits(dbfile,1)
   
   ;check whether scans already exist
   exists = scan_exists(input,db)
   sel=where(1-exists,count)
   if count gt 0 then begin
      db_new = [db,input[sel]] 
      mwrfits,db_new,dbfile,/create
   endif else print,'All new entries already exist in main database'
endelse


end

pro add_mangaid,str,drpall
;this routine adds mangaid to the output from "parse_summary.pro."
;This is useful because our standard way of identifying targets is
;with plate-ifus, but a single galaxy can be visited multiple times
;and thus have several plate-ifus associated with it. Adding MaNGA ID
;into the scan database allows us to process duplicate observations
;together, rather than separately because they have different
;plate-ifu id.
;
;str = output structure array from parse_summary

  nrow = n_elements(str) 

  newstr = {scan:0,source:'',vel:0.,proc:'',seq:0,restf:0.,nif:0,nint:0,nfd:0,az:0.,el:0.,projid:'',scan_id:'',datapath:'',mangaid:''}
  newstr = replicate(newstr,nrow)

  ;copy original structure info into newstr
  struct_assign,str,newstr

  for i=0,nrow-1 do begin
     plateifu = strtrim(str[i].source,2) ;trim extra white space
     sel=where(drpall.plateifu eq plateifu,count)
     if count ne 0 then newstr[i].mangaid = drpall[sel].mangaid
  endfor
  
  str=newstr ;replace old structure

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

drpallfile = '/users/dstark/17AGBT012/idl_routines/drpall-v3_1_1.fits'
drpall = mrdfits(drpallfile,1)

outputdb = '~/17AGBT012/database/working/mangahi_scandb_06May21.fits'

if file_test(outputdb) eq 1 then begin
   print,'output file '+outputdb+' exists. Overwrite?'
   answer=''
   read,answer
   if strupcase(answer) eq 'Y' or answer eq '' then begin
      print,'overwriting '+outputdb
      spawn,'rm '+outputdb
   endif

endif


nsession=356;289
sessions = strtrim(string(indgen(nsession+1)),2)
;fix for the string size
sel=where(sessions*1. lt 10)
sessions[sel] = '0'+sessions[sel]


;datadirs = ['/home/sdfits/','/home/scratch/dstark/']
datadirs = ['/home/scratch/kmasters/AGBT17A_012/','/home/scratch/kmasters/AGBT16A_095/','/home/scratch/kmasters/AGBT19A_127/','/home/scratch/kmasters/AGBT20B_261/','/home/scratch/kmasters/AGBT20B_033/']
data_search_strings = ['AGBT17A_012_*','AGBT16A_095_*','AGBT19A_127_*','AGBT20B_261_*','AGBT20B_033_*']


for j=0,n_elements(datadirs)-1 do begin

   ;if j eq 0 then paths = datadirs[j]+'AGBT17A_012_'+sessions+'/AGBT17A_012_'+sessions+'.raw.vegas'
   ;if j eq 1 then paths = datadirs[j]+'AGBT17A_012_'+sessions+'.raw.vegas'

   paths = file_search(datadirs[j] + data_search_strings[j])
   ;extract session numbers and complete path
   sessions=strarr(n_elements(paths))
   for k=0,n_elements(paths)-1 do begin
      substr = strsplit(paths[k],'_',/extract)
      sessions[k] = substr[n_elements(substr)-1]
      if k eq 0 then begin
         ;get file name prefix
         prefix = substr[n_elements(substr)-3]+'_'+substr[n_elements(substr)-2]
         prefix = strsplit(prefix,'/',/extract)
         prefix = prefix[n_elements(prefix)-1]
      endif
   endfor
   paths = paths + '/' + prefix + '_' + sessions + '.raw.vegas'
;   paths = paths + '/AGBT17A_012_'+sessions+'.raw.vegas'

;   if j eq 0 then paths = datadirs[j]+'AGBT17A_012_'+sessions+'/AGBT17A_012_'+sessions+'.raw.vegas'


   for i=0,n_elements(paths)-1 do begin
      if file_test(paths[i]) then begin
         out=parse_summary(paths[i])
         add_mangaid,out,drpall

         ;if paths[i] eq '/home/scratch/kmasters/AGBT17A_012/AGBT17A_012_150b/AGBT17A_012_150b.raw.vegas' then stop
;         update_scan_db,out,'~/17AGBT012/database/working/mangahi_scandb_fix.fits'
         update_scan_db,out,outputdb
      endif
   endfor   
endfor

;fix the whitespace that keeps getting added to strings
;t=mrdfits('~/17AGBT012/database/working/mangahi_scandb_fix.fits',1)
t=mrdfits(outputdb,1)
t.source = strtrim(t.source,2)
t.proc = strtrim(t.proc,2)
t.projid = strtrim(t.projid,2)
t.scan_id = strtrim(t.scan_id,2)
t.datapath = strtrim(t.datapath,2)
t.mangaid = strtrim(t.mangaid,2)

;mwrfits,t,'~/17AGBT012/database/working/mangahi_scandb_fix.fits',/create
mwrfits,t,outputdb,/create
   

end

  
