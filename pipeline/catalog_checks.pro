;this script runs a series of sanity checks on the catalog to identify
;any weird entries.  Adding checks as I find them 

pro catalog_checks,catalog

  t=mrdfits(catalog,1)
  ndet = total(t.logmhi gt 0)
  nnondet = total(t.loghilim200kms gt 0)
  nboth = total(t.loghilim200kms gt 0 and t.logmhi gt 0)
  nneither = total(t.loghilim200kms lt 0 and t.logmhi lt 0)
  print,'# detections: ',ndet
  print,'# nondetections: ',nnondet
  print,'# detection and nondetection (should be zero): ',nboth
  if nboth gt 0 then begin
     print,''
     print,'offending plate-ifus:'
     sel=where(t.loghilim200kms gt 0 and t.logmhi gt 0)
     print,t[sel].plateifu
  endif
  
  print,'# not detection and not nondetection (should be zero)',nneither
  if nneither gt 0 then begin
     print,''
     print,'offending plate-ifus:'
     sel=where(t.loghilim200kms lt 0 and t.logmhi lt 0)
     print,t[sel].plateifu
  endif
  
  ;find any unusual rms values
  plothist,alog10(t.rms)
  sel=where(t.rms lt 1 or t.rms gt 10)
  print,''
  print,'the following have unusually low or high rms values:'
  forprint,t[sel].plateifu,t[sel].rms
  
  ;plot sensitivity vs distance
  sel=where(t.logmhi gt 0)
  plot,t[sel].vopt,t[sel].logmhi,psym=4
  sel=where(t.logmhi gt 0 and t.logmhi lt 8,count)
  if count gt 0 then begin
     print,''
     print,'unusually low HI masses:'
     forprint,t[sel].plateifu,t[sel].logmhi
  endif else print,'all masses seem reasonable'

  sel=where(t.loghilim200kms gt 0)
  plot,t[sel].vopt,t[sel].loghilim200kms,psym=4,/ynozero
  oplot,findgen(20000),alog10(8e8/(9000./findgen(20000))^2),color=255
  lowlim = where(t.loghilim200kms lt alog10(8e8/(9000./t.vopt)^2) and t.loghilim200kms gt 0,count)
  if count gt 0 then begin
     print,''
     print,'unusually low limits: '
     forprint,t[lowlim].plateifu
  endif else print,'all upper limits look reasonable'

;;;

  skiptags = ['PLATEIFU','MANGAID','SESSION']
  tags = tag_names(t)
  for i=0,n_elements(tags)-1 do begin
     check = where(skiptags eq tags[i],count)
     if count eq 0 then begin
     
        print,''
        print,tags[i]
        var = t.(i)
        sel=where(var ne -999)
        print,'min:',min(var[sel])
        print,'max:',max(var[sel])
        print,'mean:',mean(var[sel])
        print,'stdev:',stdev(var[sel])

     endif
  endfor

stop
  
end

catalog = '/users/dstark/17AGBT012/master/catalogs/testcat.fits';  mangahi_dr2_072420.fits'
catalog_checks,catalog

end
