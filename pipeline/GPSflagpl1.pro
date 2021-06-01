pro GPSflagpl, scan, ntot

  for i=0,ntot-1 do begin
  getps,scan,intnum=i,plnum=1
  usr_input = "n"
  print,'Int = ',i
  READ, "Do you want to flag GPS in this int? (y/n, default n) ", usr_input
    IF STRLOWCASE(usr_input) EQ "y" THEN BEGIN
       flag,scan,intnum=i,idstring='GPS'
    ENDIF

 endfor

stop
end 
