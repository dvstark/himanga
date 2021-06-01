PRO getshortps, StartNumber, Nfirst, Nlast

    freeze    
    FOR i = Nfirst,Nlast DO BEGIN
	getps, StartNumber, plnum=0, intnum=i, tau=0.0108, ap_eff=0.71, units="Jy"
	accum
	getps, StartNumber, plnum=1, intnum=i, tau=0.0108, ap_eff=0.71, units="Jy"
	accum
    ENDFOR
    unfreeze
    ave,/noclear

END

PRO mygetps, StartNumber, Nrepeat

	unzoom
	freeze
   FOR i = 0, Nrepeat-1 DO BEGIN
       n = i*2 + StartNumber
           getps,n,plnum=0, tau=0.0108, ap_eff=0.71, units="Jy"
           accum
           getps,n,plnum=1, tau=0.0108, ap_eff=0.71, units="Jy"
           accum
   ENDFOR	
	unfreeze
	ave,/noclear

        setxunit,'km/s'
	XRange = getxrange()
	rezoom, XRange[0]+10, XRange[1]

END

PRO rfiblank
	setxunit,'Channels'
	default=300
	  Print, "Blanking data from channel=0 to channel=",default
	  replace,0,default,/blank
	  rezoom, default+1, 32768

	default2=32000
      	  Print, "Blanking data to channel=32768 from channel=",default2
	  replace,default2,32768,/blank
	  rezoom, default+1, default2-1


;	XRange = getxrange()
;	rezoom, XRange[0]+10, XRange[1]

; Allows user to mark beginning of spectrum (in channels) to be blanked out.
	rfiOK=0

	WHILE rfiOK EQ 0 DO BEGIN
          usr_input = " "
	  READ, "Want to blank out more beginning channels? (y/n) ", usr_input

          IF STRLOWCASE(usr_input) EQ "n" THEN rfiOK=1
	  IF STRLOWCASE(usr_input) EQ "y" THEN BEGIN
		  PRINT, "Click on channel to blank to: "
		  cb = click()
	  Print, "Blanking data from channel=0 to channel=",cb.x
	  replace,0,cb.x,/blank
	  rezoom, cb.x, 32768
	  ENDIF
       ENDWHILE
       
	WHILE rfiOK EQ 0 DO BEGIN
          usr_input = " "
	  READ, "Want to blank out more end channels? (y/n) ", usr_input

          IF STRLOWCASE(usr_input) EQ "n" THEN rfiOK=1
	  IF STRLOWCASE(usr_input) EQ "y" THEN BEGIN
		  PRINT, "Click on channel to blank from: "
		  cb = click()
	  Print, "Blanking data to end from channel=",cb.x
	  replace,cb.x,default2,/blank
	  rezoom, default,c.x
	  ENDIF
       ENDWHILE
       

;Allows user to mark position of one or more RFI spikes. Interpolates data for 2 channels on either side of marked position.

	rfiOK=0

	WHILE rfiOK EQ 0 DO BEGIN
          usr_input = " "
	  READ, "Do you want to mark the position of RFI spikes? (y/n)", usr_input
	
	  IF STRLOWCASE(usr_input) EQ "n" THEN rfiOK=1

	  IF STRLOWCASE(usr_input) EQ "y" THEN BEGIN
            PRINT, "Click on position of RFI to zoom: "
	    c = click()
	    xmin=c.x-100
	    if xmin LE 300 then xmin=301	
	    xmax = c.x+100
	    if xmax GE 32768 then xmax=32767
	    rezoom, xmin, xmax		
            PRINT, "Click on position of RFI: "
	    c = click()
            Print, "Interpolating data in +/- 10 channels around channel=",c.x
	    rfi=c.freq/1.e6
            Print, "RFI record",rfi
	    replace,c.x-10,c.x+10
	    unzoom
	    ;rezoom, cb.x, 8192
	  ENDIF

	ENDWHILE
	setxunit,'km/s'
END

PRO rfispike, inds=inds
; Allows user to click either side of an RFI spike to remove.

   PRINT, "Click either side of RFI: "
   c1 = click()
   c2 = click()
   r1 = c1.chan
   r2 = c2.chan
   replace, r1, r2
   inds=[r1,r2]



END



PRO ReZoom, xMin, xMax

   dataX = getxarray()
   dataY = getyarray()

   ind = WHERE(dataX GE xMin AND dataX LE xMax)
   yMax = MAX(dataY(ind))
   yMin = MIN(dataY(ind))

   setxy, xMin, xMax, yMin-0.02, yMax+0.02
   
END

PRO Getpeak,ymax=ymax

   print, "Click on either side of profile, low vel side first"
   c1=click()
   c2=click()

   xMin=c1.x
   xMax=c2.x

   print, xMin, xMax

   dataX = getxarray()
   dataY = getyarray()

   ind = WHERE(dataX GE xMin AND dataX LE xMax)
   yMax = MAX(dataY(ind))

   print,"Peak is: ",yMax 

   g=getgain()
   
END

PRO quickwidth, peak, rms, widthinfo = widthinfo,calc_peak=calc_peak

  ;May 29, 2018: D.S. editing this so it automatically calculates the peak
  ;May 29, 2019: D.S. 

   widthinfo = {peak:0d,snr:0d,xmin:0L,xmax:0L,fhi:0d,vhi:0d,wm50:0d,wp50:0d,wp20:0d,eV:0d,w2p50:0d,wf50:0d,al:0d,bl:0d,ar:0d,br:0d,pr:0d,pl:0d}


   
   print, "Mark the region of interest with the cursor (any mouse click)"
   c=click()
   xMin = round(c.chan)
   xMin_kms=c.velo/1000.
   c=click()
   xMax = round(c.chan)
   xMax_kms = c.velo/1000.
   widthinfo.xmin = xmin
   widthinfo.xmax = xmax

   if keyword_set(calc_peak) then begin
      dataX = getxarray()
      dataY = getyarray()
      
      ind = WHERE(dataX GE xMin_kms AND dataX LE xMax_kms)
      yMax = MAX(dataY(ind))
      peak=ymax
   endif
   widthinfo.peak=peak

   snr=peak/rms
   print, "S/N is ", snr
   widthinfo.snr = snr

   print, "WM50"
   g=mygmeasure(1,0.5,rms=rms,ifirst=xMin,last=xMax)
   widthinfo.wm50=g[1]
   widthinfo.fhi=g[0]

   print, "WP50"
   g=mygmeasure(2,0.5,rms=rms,ifirst=xMin,last=xMax)
   wp50=g[1]
   widthinfo.wp50=g[1]
   print, "WP20"
   g=mygmeasure(2,0.2,rms=rms,ifirst=xMin,last=xMax)
   wp20=g[1]
   widthinfo.wp20 = g[1]
   slope=0.3*peak/(wp20-wp50) 
   error=sqrt((rms/slope)^2 + 2.3901)
 
   print, "Estimate of error on V is: ", error
   widthinfo.ev = error
   print, "W2P50"
   g=mygmeasure(3,0.5,rms=rms,ifirst=xMin,last=xMax);,peaks=peaks)
   widthinfo.w2p50 = g[1]
   print, "WF50"
   g=mygmeasure(4,0.5,rms=rms,ifirst=xMin,last=xMax,fitl=fitl,fitr=fitr);,peaks=peaks)
   widthinfo.wf50 = g[1]
   widthinfo.vhi = g[2]
   widthinfo.ar = fitr[0]
   widthinfo.br = fitr[1]
   widthinfo.al = fitl[0]
   widthinfo.bl = fitl[1]
   widthinfo.pr = peaks[0]
   widthinfo.pl = peaks[1]

END
