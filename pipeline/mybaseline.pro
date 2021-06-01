PRO MyBaseline, Order
  IF N_PARAMS() LT 1 THEN Order=2
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

  baseline
END


PRO smooth16
	boxcar,16,/decimate
	hanning
	unzoom
END

PRO smooth32
	boxcar,32,/decimate
	hanning
	unzoom
END

PRO smooth64
	boxcar,64,/decimate
	hanning
	unzoom
END

PRO mpeak
	stats
	getpeak
END
