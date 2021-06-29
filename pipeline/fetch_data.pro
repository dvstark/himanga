function parse_badscan_file,file

  readcol,file,f='a,a',session,badscans,comment='#',delimiter = ' '
  
  badscan_template = {session:'',scan:0,scan_id:''}
  
  for i=0,n_elements(session)-1 do begin
     scans = (strsplit(badscans[i],',',/extract)) ;turn into integer
     
     badscans_add = replicate(badscan_template,n_elementS(scans))
     badscans_add[*].session = (session[i])
     badscans_add.scan = uint(scans)
     
     if i eq 0 then badscans_db = badscans_add else badscans_db = [badscans_db,badscans_add]

  endfor

  badscans_db.scan_id = badscans_db.session+'_'+strtrim(string(badscans_db.scan),2)

  return,badscans_db

  
end



pro fetch_data,name,dbfile,badscan_file=badscan_file,scaninfo=scaninfo,drpallfile=drpallfile,alt_names = alt_names
  
;;script to find data for a given manga-HI target, read it in, and
;;accumulate it.
;;
;; name = target name (plate-ifu)
;; dbfile = observations database (holds all the scan info)
;; badscan_file = file that indicates which scans are bad and should
;; be completely ignored (this is separate from issues like GPS, but
;; rather scans that were bad from the start due to telescope issues)
;; scaninfo = variable that holds all the info about each scan loaded
;;
;; Updated on June 1 2021 to look up MangaID and use that for
;; matching. Will merge all data for single object with two plate-ifu
;; designationd together. The combined file is named whatever is given
;; in "name" but alt_names is returned that gives the other plate-ifu
;; designations for this galaxy

  if 1-keyword_set(drpallfile) then drpallfile = '/users/dstark/17AGBT012/idl_routines/drpall-v3_1_1.fits'

  if 1-keyword_set(badscan_file) then begin
     
     s = strsplit(dbfile,'.fits',/regex,/extract)
     badscan_file = s[0]+'_badscans.txt'

  endif

  alt_names = ''

  sclear

  ;looks for data for a given target and reads that data in
  db=mrdfits(dbfile,1)
  ;fix extra whitespace that always seems to appear
  db.source = strtrim(db.source,2)
  db.proc = strtrim(db.proc,2)
  db.projid = strtrim(db.projid,2)
  db.scan_id = strtrim(db.scan_id,2)
  db.datapath = strtrim(db.datapath,2)
  db.mangaid = strtrim(db.mangaid,2)

  badscan_db = parse_badscan_file(badscan_file)
  
  ;go ahead and remove anything which is flagged as bad
  keep=bytarr(n_elements(db))+1
  match,db.scan_id,badscan_db.scan_id,ind1,ind2
  if ind1[0] ne -1 then keep[ind1]=0
  db=db[where(keep)]

  ;read drpall and look up MaNGA-ID
  drp = mrdfits(drpallfile,1,/silent)
  sel=where(drp.plateifu eq name)
  matched_mangaid = drp[sel].mangaid
  sel=where(strtrim(db.mangaid,2) eq matched_mangaid,nmatch)

  
  ;line below replaced with line above (now matching on mangaid, not plate-ifu)
  ;sel=where(strtrim(db.source,2) eq name and strtrim(db.proc,2) eq 'OnOff',nmatch)
  if nmatch lt 2 then begin
     print,'no data found. Exiting'
     return
  endif

  db=db[sel]

  

  good = intarr(n_elements(db))+1
  

  ;iterate through files and scans
  ;paths = '/home/sdfits/'+db.projid+'/'+db.projid+'.raw.vegas'
  paths = db.datapath

  ;get unique paths
  uniq = uniq(paths,sort(paths))
  unique_paths = paths[uniq]

  for i=0,n_elements(unique_paths)-1 do begin
     filein,strtrim(unique_paths[i],2) ;removing extra white space
     
     print,''
     print,'loading ',unique_paths[i]

     ;get ON scans
     sel=where(paths eq unique_paths[i] and db.seq eq 1)
     on_scans = db[sel].scan
     
     ;iterate
     for j=0,n_elements(on_scans)-1 do begin
        
        on = on_scans[j]
        on_ind = where(db.scan eq on and paths eq unique_paths[i],count)

        off = on + 1
        
        ;check that off truly is an off
        off_ind=where(db.scan eq on+1 and paths eq unique_paths[i],count)
        if count eq 0 then begin
           print,'No OFF scan for ON scan ',on
           good[j] = 0
           continue
        endif else if count eq 2 then begin
           print,'ERROR! DUPLICATE ENTRIES IN SCANDATA BASE. THIS NEEDS TO BE FIXED BEFORE PROCEEDING'
           stop
           return
        endif else if db[off_ind].seq ne 2 then begin
           print,'No OFF scan for ON scan',on
           good[j] = 0
           continue
        endif

        getps,on,plnum=0,unit='Jy',status=status
        if status eq 1 then accum
        print,'status:',status
        if status ne 1 then begin
           good[on_ind] = 0
           good[off_ind]=0
        endif


        getps,on,plnum=1,unit='Jy',status=status
        if status eq 1 then accum
        print,'status:',status
        if status ne 1 then begin
           good[on_ind] = 0
           good[off_ind]=0
        endif

     endfor

  endfor

  ave

  scan_status = strarr(n_elementS(db)) + ' processed'
  if total(1-good) gt 0 then scan_status[where(1-good)]=' ignored'

  forprint,db,scan_status
  
  scaninfo = db

                                ;see if there are multiple plateifus
                                ;for this galaxy. Warn user if so

  ;find all entries in drpall catalog
  sel=where(drp.mangaid eq matched_mangaid,count)
  unique_plateifu = drp[sel].plateifu

  ;uniq_plateifu = uniq(db.source,sort(db.source))
  ;unique_plateifu = db[uniq_plateifu].source
  if n_elements(unique_plateifu) gt 1 then begin
     print,''
     print,'NOTE: THIS GALAXY HAS MULTIPLE PLATE-IFU DESIGNATIONS. COMBINING THEM ALL'
     print,'PLATEIFUs:',unique_plateifu
     print,''
     alt_names = strjoin(unique_plateifu[where(unique_plateifu ne name)],';')

     if !g.s[0].source ne name then begin
        print,'renaming combined spectrum as user-defined name'
        !g.s[0].source = name
        copy,0,1
        copy,1,0 ;there's got to be a better way to make the plot title refresh
     endif

  endif

end

pro inspect_scan,scaninfo

;routine to let the user examine scans in detail

  scan_ind = indgen(n_elements(scaninfo))

  done=0
  while not done do begin
     print,'scan_num    scan_id   procedure   step    nint'
     forprint,scan_ind,':  '+scaninfo.scan_id,'  '+scaninfo.proc,scaninfo.seq,scaninfo.nint
     print,''

     print,'Plot scan: p [scan_num]'
     print,'Automatic GPS flag: a [scan_num] [threshold (default=0.5)]'
     print,'Manual Flag: m [scan_num]'
     print,'Flag Full Scan: f [scan_num]'
     print,'Unflag Full Scan: u [scan_num]'
     print,'set x range: x [x0 x1]'
     print,'set y range: y [x0 x1]'
     print,'Exit: q'

     answer = ''
     read,answer
     print,answer
     case strmid(answer,0,1) of
        'q': done=1
        'p':begin
           sub = strsplit(answer,/extract)
           if n_elements(sub) gt 1 then begin
              num = uint(sub[1])
              if num gt max(scan_ind) then print,'choose valid scan' else begin
                 path = strcompress(scaninfo[num].datapath,/remove_all) ;'/home/sdfits/'+scaninfo[num].projid+'/'+scaninfo[num].projid+'.raw.vegas'
                 filein,path
                 getps,scaninfo[num].scan,plnum=0
                 copy,0,1
                 accum
                 getps,scaninfo[num].scan,plnum=1
                 copy,0,2
                 accum
                 ave
                                ;oshow,1,color='blue'
                                ;oshow,2
              endelse

           endif

        end
        'a':begin
           sub = strsplit(answer,/extract)
           if n_elements(sub) gt 1 then begin
              num = uint(sub[1])
              if num gt max(scan_ind) then print,'choose valid scan' else begin
                 if n_elements(sub) gt 2 then autoflag_thresh=sub[2]*1. $
                 else autoflag_thresh = 0.5
                 path = strcompress(scaninfo[num].datapath,/remove_all) ;'/home/sdfits/'+scaninfo[num].projid+'/'+scaninfo[num].projid+'.raw.vegas'
                 filein,path

                 autoflag,scaninfo[num].scan,scaninfo[num].nint,autoflag_thresh
              endelse

           endif


        end

        'm':begin
           sub = strsplit(answer,/extract)
           if n_elements(sub) gt 1 then begin
              num = uint(sub[1])
              if num gt max(scan_ind) then print,'choose valid scan' else begin

                 path = strcompress(scaninfo[num].datapath,/remove_all) ;'/home/sdfits/'+scaninfo[num].projid+'/'+scaninfo[num].projid+'.raw.vegas'
                 filein,path
                 gpsflag,scaninfo[num].scan,scaninfo[num].nint
              endelse

           endif           
        end

        'f':begin
           vals = strsplit(answer,/extract)
           print,vals
           if n_elements(vals) gt 1 then begin
              if vals[1]*1. gt max(scan_ind) then print,'choose valid scan' $
              else begin
                 path = strcompress(scaninfo[vals[1]*1].datapath,/remove_all) ;'/home/sdfits/'+scaninfo[num].projid+'/'+scaninfo[num].projid+'.raw.vegas'
                 filein,path
                 flag,scaninfo[vals[1]*1].scan
                 print,'flagging ',scaninfo[vals[1]*1].scan

              endelse
              

           endif else print,'specify scan'

        end

        'x':begin
           vals = strsplit(answer,/extract)
           if n_elements(vals) ge 3 then setx,vals[1]*1.,vals[2]*1.
        end

        'y':begin
           vals = strsplit(answer,/extract)
           if n_elements(vals) ge 3 then sety,vals[1]*1.,vals[2]*1.
        end

        'u':begin
           sub = strsplit(answer,/extract)
           if n_elements(sub) gt 1 then begin
              num = uint(sub[1])
              path = strcompress(scaninfo[num].datapath,/remove_all);'/home/sdfits/'+scaninfo[num].projid+'/'+scaninfo[num].projid+'.raw.vegas'
              filein,path
              listflags
              print,'Type which flag IDs you want to remove (e.g., 0,1,2,5...)'
              print,'Note: you are trying to unflag scan number '+strtrim(string(scaninfo[num].scan),2)
              read,answer
              if answer ne '' then begin
                 vals=strsplit(answer,',',/extract)
                 vals = vals*1
                 print,vals
                 unflag,vals
              endif
           endif
        end

        else:print,'try try again'
     endcase
  endwhile





end




;fetch_data,'8256-9101','testdb.fits',scaninfo=scaninfo

;print,'scan summary'
;inspect_scan,scaninfo


;end
  
