PRO QuickLook, Number
  getfs,Number,plnum=0
  sclear
  accum
  getfs,Number,plnum=1
  accum
  ave, /noclear
  unzoom
  boxcar,8,/decimate
  PRINT, "Zoom in, then type 'SubtractBaseLine' to continue..."
END

PRO SubtractBaseline, Order
  IF N_PARAMS() LT 1 THEN Order=5
  FitOK=0
  setregion
  col=0

  WHILE FitOK EQ 0 DO BEGIN
      PRINT, "Trying Polynomial of Order ", Order
      nfit, Order
      bshape, color=2550+col
      
      usr_input = ""
      READ, "Enter another order (or ENTER to accept, R to redo region) ", $
        usr_input
      
      IF usr_input EQ "" THEN FitOK=1 ELSE BEGIN
          IF STRLOWCASE(usr_input) EQ "r" THEN setregion ELSE $
            Order = FIX(usr_input)
      ENDELSE
      col = (col+1) mod 10
  ENDWHILE

  baseline,modelbuffer=5
;  boxcar,2, /decimate
END

PRO FastLook, Number, yMin, yMax

   IF N_PARAMS() LT 2 THEN BEGIN
       yMin = -0.35
       yMax = 0.25
   ENDIF
   
   setxunit, "km/s"
   QuickLook, Number   
   Xrange = getxrange()
   setxy, Xrange(0)+10, (Xrange(1)-Xrange(0))*0.6 + Xrange(0),yMin, yMax
   PRINT, "Set the region to fit the baseline to..."
   SubtractBaseLine
END

PRO QuickLookPS, StartNumber, Nrepeat, PLNUM=plnum
  
   IF N_PARAMS() LT 2 THEN Nrepeat=1

   DoPol0=0
   DoPol1=0
   IF N_ELEMENTS(plnum) GT 0 THEN BEGIN
       IF plnum EQ 0 THEN DoPol0 = 1
       IF plnum EQ 1 THEN DoPol1 = 1
   ENDIF ELSE BEGIN
       DoPol0=1
       DoPol1=1
   ENDELSE

   sclear
   FOR i = 0, Nrepeat-1 DO BEGIN
       n = i*2 + StartNumber
       IF DoPol0 EQ 1 THEN BEGIN
           getps,n,plnum=0
           accum
       ENDIF
       IF DoPol1 EQ 1 THEN BEGIN
           getps,n,plnum=1
           accum
       ENDIF
   ENDFOR

   ave, /noclear
   unzoom
   boxcar,4,/decimate
   hanning

   PRINT, "Zoom in, then type 'SubtractBaseLine' to continue..."
END

PRO ReZoom, xMin, xMax

   dataX = getxarray()
   dataY = getyarray()

   ind = WHERE(dataX GE xMin AND dataX LE xMax)
   yMax = MAX(dataY(ind))
   yMin = MIN(dataY(ind))

   setxy, xMin, xMax, yMin-0.02, yMax+0.02
   
END

PRO FastLookPS, StartNumber, Nrepeat, _EXTRA=extra
  
   QuickLookPS, StartNumber, Nrepeat, _EXTRA=extra
   setxunit, "km/s"

   PRINT, "Zooming..."

   XRange = getxrange()
   ReZoom, XRange(0), XRange(1)-80
   subtractbaseline, 2
   ReZoom, XRange(0), XRange(1)-80

END

PRO SlicePS, Number, NumInt
   ; Looks at yy-polarization, 1 slice at a time...

   i = 0
   WHILE i LT NumInt DO BEGIN
       PRINT, "IntNum=",i
       getps, Number, intnum=i
       unzoom
       XRange = getxrange()
       ReZoom, XRange(0), XRange(1)-80
       usr_input = ""
       READ, "Press Enter for next (B for back) ", usr_input
       IF STRLOWCASE(usr_input) EQ "b" AND i GT 0 THEN i=i-1 ELSE i=i+1
   ENDWHILE

END

PRO ShortObsPS, StartNumber, Ndumps, PLNUM=plnum
  
   IF N_PARAMS() LT 2 THEN Ndumps=1

   DoPol0=0
   DoPol1=0
   IF N_ELEMENTS(plnum) GT 0 THEN BEGIN
       IF plnum EQ 0 THEN DoPol0 = 1
       IF plnum EQ 1 THEN DoPol1 = 1
   ENDIF ELSE BEGIN
       DoPol0=1
       DoPol1=1
   ENDELSE

   sclear
   FOR i = 0, Ndumps-1 DO BEGIN
       IF DoPol0 EQ 1 THEN BEGIN
           getps,StartNumber,plnum=0,intnum=i
           accum
       ENDIF
       IF DoPol1 EQ 1 THEN BEGIN
           getps,StartNumber,plnum=1,intnum=i
           accum
       ENDIF
   ENDFOR

   ave, /noclear
   unzoom
   hanning
   boxcar,16,/decimate

   setxunit, "km/s"

   PRINT, "Zooming..."

   XRange = getxrange()
   ReZoom, XRange(0), XRange(1)-80

   subtractbaseline, 2
   ReZoom, XRange(0), XRange(1)-80

END
