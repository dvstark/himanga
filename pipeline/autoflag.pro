pro autoflag, scan, ntot, x
  
                                ;22 Aug 2018: code will crash if the
                                ;8000-9000 velocity range extends
                                ;outside of data. Code now checks to
                                ;ensure this won't happen. (DVS)

                                ;01-15-2019: code will also
                                ;crash if the spectrum doesn't
                                ;overlap the gps region at all
                                ;(8000-9000 km/s). Adding a quick check
                                ;at the beginning

  gtime=0
  getps,scan,intnum=0
  if (getxunits() ne 'km/s') then begin
     print,'Changing x-units to km/s'
     setxunit,'km/s'
  endif	

  ;check to see if velocity range overlaps with known GPS region
  vminmax=minmax(velocity_axis(!g.s[0]))/1000
  if (vminmax[0] gt 9000) or (vminmax[1] lt 8000) then begin
     print,'spectrum does not overlap GPS region. Exiting autoflag'
     return
  endif


  for i=0,ntot-1 do begin
  getps,scan,intnum=i
  vminmax=minmax(velocity_axis(!g.s[0]))/1000
  stats,8000 > vminmax[0],9000 < vminmax[1],ret=mystats,/quiet
  print,mystats.rms
    IF mystats.rms gt x THEN BEGIN
       flag,scan,intnum=i,idstring='autoGPS'
       print,'FLAGGED scan ',i
       gtime=gtime+10
    ENDIF

    print,'Time lost: ',gtime, 'sec'
    print,gtime/60., ' min'

 endfor

end 
