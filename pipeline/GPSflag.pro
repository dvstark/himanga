pro GPSflag, scan, ntot,smo=smo

  for i=0,ntot-1 do begin
  getps,scan,intnum=i
  if keyword_set(smo) then boxcar,smo,/dec
  usr_input = "n"
  print,'Int = ',i
  READ, "Do you want to flag GPS in this int? (y/n, default n) ", usr_input
    IF STRLOWCASE(usr_input) EQ "y" THEN BEGIN
       flag,scan,intnum=i,idstring='GPS'
    ENDIF

 endfor

end 
