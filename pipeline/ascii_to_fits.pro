pro ascii_to_fits,asciifile,outfile=outfile

  ;Program to convert a MaNGA-HI ascii data file into a fits file.
  ;The output file is given the same file root as the ascii file but
  ;with fits at the end, unless a specific output file is given with
  ;the "outfile" keyword.
  
                                ;read in ascii data
  readcol,asciifile,vhi,fhi,bhi

                                ;put data into a structure
  data = {vhi:vhi,fhi:fhi,bhi:bhi}

                                ;create minimal header
  FXBHMAKE, hdr, n_elements(vhi)
  
                                ;parse the header info.  If a header
                                ;keyword is found, then extract it and
                                ;add it to the header
  openr,lun,asciifile,/get_lun
  ;keywords to look for
  keywords = ['Telescope','Beam Size','Object','RA Dec','Rest Frequency','Central velocity','Integration time','Date']
  keywords = strupcase(keywords)
  
  ;corresponding header keywords to add to the fits header
  header_keyword = ['telescope','beam_fwhm','object','ra_dec','restfrq','obj_vel','tint','date']
  
  ;indicate which header parameters should be strings or floats
  header_format = ['s','f','s','s','f','f','f','s']
  
  line=''
  while not EOF(lun) do begin
     readf,lun,line
     
     ;check for header keyword
     keyword_found=0
     for i=0,n_elements(keywords)-1 do begin
        if strpos(strupcase(line),keywords[i]) ne -1 then begin
                                ;get info after the :
           x=strsplit(line,':',/extract)
           value = x[n_elements(x)-1]
           if header_format[i] eq 'f' then value=float(value) $
           else value = strtrim(value,2)

           ;description is everything before the :
           descr = x[0]
           x=strsplit(descr,'#',/extract) ;removing extra #
           descr=x[n_elements(x)-1]
           
           FXADDPAR, hdr, header_keyword[i], value, descr
           keyword_found=1
        endif
        
     endfor
        
     if not keyword_found and strpos(line,'###') eq -1 and strpos(line,'#') ne -1 then begin
                                ;these are comments
        
                                ;remove the leading #
           comment=strsplit(line,'#',/extract)

                                ;add to header
           sxaddhist,comment,hdr,/comment
           
        endif
      
  endwhile
  
  if 1-keyword_set(outfile) then begin
     root = (strsplit(asciifile,'.txt',/extract))[0]
     outfile = root[0]+'.fits'
  endif
  
  mwrfits,data,outfile,hdr,/create
  close,lun
  free_lun,lun

end

