;+
; Function to find the area, width, and velocity of a galaxy profile.
;
; <p>There are four ways in which the left and right (low channel number
; and high channel number) edges of the galaxy profile can be determined.  The
; mode parameter selects one of these methods:
; <ul>
; <li> 1 - As a fraction of the mean within the region of interest.
;          The mean of data from ifirst through last is calculated.  The
;          edges are then those locations where the data values are
;          greater than f*mean for 3 consecutive channels starting
;          from the end points of the region of interest.
; <li> 2 - As a fraction of the maximum value within the region of
;          interest.  The peak of data from ifirst to last is found.
;          The edges are then those locations where the data values
;          are greater than f*(peak-rms) for 3 consecutive channels
;          starting from the end points of the region of interest.
; <li> 3 - As a fraction of each of two peaks - identified by the
;          user.  The user uses the cursor to mark two peaks in the
;          region of interest.  The maximum value within 10 channels of
;          each peak is found.  The left edge is where the data values
;          fall below f*(peak-rms) for 3 consecutive channels searched
;          from the location of the peak.  The right-channel peak is
;          similarly used to find the right edge.
; <li> 4 - A polynomial is fit to either side of the profile between 
; 	   15-85% of (peak-rms) (where the peak is from the relevent side of
; 	   the profile - the two peaks are identified by the user). The velocity
;	   of the polynomical fit at f*(peak-rms) is then found for both sides 
;          of the profile. The difference between the two is the width, the mean is
;	   the central velocity. The order of the polynomial is chosen by the user
;	   (linear fits are usually sufficient). This scheme (further described in 
;	   Springob etal 2006) has the advatange of averaging out noise effects from 
;	   either side of the profile.
; 	     
; 	   
; </ul>
;
; <p>In the first 3 modes, the final left and right edge are linear
; interpolations to get the fractional channel where data value crossed
; the threshold given by f for that particular mode.
;
; <p>If an edge is not found, a warning is issued and the appropiate
; end-point of the region of interest is used.  Only the data values
; within the region of interest are used here.
;
; <p> The returned value is a 3-element array with these values, in
; this order.
; <ul>
; <li> Area.  The sum of data[i]*abs(vel[i+1]-vel[i-1])/2.0 for all i
; from ifirst to last (modes 1 and 2) or between the channels where
; the data values first become negative moving out from the two peaks
; found in mode 3 (not including that transition channel).
; <li> Width.  The absolute value of the difference between the left
; and right edges as determined for that mode.
; <li> Velocity.  The mean of the left and right edges as determiend
; for that mode.
; </ul>
;
; <p>
; This code adapted from code in use at Arecibo.  This particular
; version was originally from Karen O'Neil.
;
; Option 4 added by Karen Masters.
;
; <p><B>Contributed By: Karen O'Neil, NRAO-GB and Bob Garwood, NRAO-CV</B>
;
; @param data {in}{required}{type=float array} The data values.
; @param vel {in}{required}{type=float array} The velocities at each
; data point.
; @param ifirst {in}{required}{type=integer} The first channel to use.
; @param last {in}{required}{type=integer} The last channel to use.
; @param mode {in}{required}{type=integer} The method to use in
; finding the returned values.
; @param f {in}{required}{type=float} Used in locating the edges of
; the galaxy profile.  See the documentation for more details.
; @keyword rms {in}{optional}{type=float} Used in modes 2 and 3 as
; described above.  If this is not supplied, defaults to the stddev of
; data within the region of interest.
; @keyword quiet {in}{optional}{type=boolean} When set, the results
; are not printed to the terminal (they are still returned).
;
; @returns the values in a 3 element array: [0] is the area, [1] is
; the width and [2] is the velocity.  Returns 0.0 for all 3 values on
; error.
;
; @version $Id: awv.pro,v 1.3 2005/07/28 20:05:22 bgarwood Exp $
;-
function myawv, data,vel,ifirst,last,mode,f,rms=rms,quiet=quiet,fitl=fitl,fitr=fitr,peaks=peaks
    compile_opt idl2

    fitl=[-999,-999]
    fitr=[-999,-999]
    peaks = [-999,-999]


    res=fltarr(6)

    ; argument checks
    if n_params() ne 6 then begin
        message,'Usage: amv, data, vel, ifirst, last, mode, f',/info
        return, res
    endif

    if n_elements(data) ne n_elements(vel) then begin
        message,'data and vel must have the same number of elements',/info
        return, res
    endif

    ; in case the user entered the channel numbers in the wrong order
    if ifirst gt last then begin
        thisfirst = last
        thislast = ifirst
    endif else begin
        thisfirst = ifirst
        thislast = last
    endelse

    nptsTot = n_elements(data)

    ; watch for out of bounds values
    if thisfirst lt 0 then thisfirst = 0
    if thislast lt 0 then thislast = 0
    if thisfirst ge nptsTot then thisfirst = (nptsTot-1)
    if thislast ge nptsTot then thislast = (nptsTot-1)

    if ifirst eq last then message,'Warning: ifirst and last are the same point',/info

    data1=data[thisfirst:thislast]
    vel1 = vel[thisfirst:thislast]
    npts = n_elements(data1)

    switch mode of 
        1:
        2: begin
            ; determination of flevel differs between 1 and 2
            if mode eq 1 then begin
                ; the flevel is f * the mean over the region of interest.
                AVE = mean(data1) 
                if F GT 1 then message ," Fraction > 1; do not necessarily  expect the correct answer",/info
                FLEVEL =f*AVE
            endif else begin
                ; the flevel is f * the (peak-rms) over the region of interest.
                peak = max(data1)
                if n_elements(rms) eq 0 then rms=stddev(data1)
                peak =peak - rms
                FLEVEL = F*peak
            endelse

            if npts lt 4 then begin
                ; pathological case
                jl = 0
                jr = (npts-1)
            endif else begin
                ; find the channels that actually define the edges of the profile
                ; only use data1
                ; find the left edge
                jl = -1
                repeat begin
                    jl=jl+1 
                    if jl gt (npts-3) then break
                endrep until ((data1[jl] ge flevel) and (data1[jl+1] ge flevel) and (data1[jl+2] ge flevel))
                if (jl gt (npts-3)) then begin
                    message,string(thisfirst,format='("Could not find left edge, using ",i6)'),/info
                    jl = 0
                endif
                jr=npts
                ; find the right edge - stop looking when it gets to jl
                repeat begin
                    jr=jr-1 
                    if jr lt jl or jr lt 2 then break
                endrep until ((data1[jr] ge flevel) and (data1[jr-1] ge flevel) and (data1[jr-2] ge flevel))
                if (jr lt jl) or (jr lt 2) then begin
                    message,string(thislast,format='("Could not find left edge ... using ",i6)'),/info
                    jr = (npts-1)
                endif
                ; area comes from entire region of interest
            endelse
            jj1 = 0
            jj2 = (npts-1)
            fpeak1=flevel
            fpeak2=flevel
            break
        end
        3: begin
            if n_elements(rms) eq 0 then rms=stddev(data1)
            print, 'click on the positions for the two peaks'
            clk1 = click()
            if not clk1.ok then begin
                message,'There was a problem with plotter, can not continue',/info
                return, res
            endif
            clk2 = click()
            if not clk2.ok then begin
                message,'There was a problem with plotter, can not continue',/info
                return, res
            endif
            ; get clicked channels relative to thisfirst - in region of interest
            il=round(clk1.chan) - thisfirst
            ir=round(clk2.chan) - thisfirst

            if (il gt ir) then begin
                tmp = il
                il = ir
                ir = tmp
            endif

            ; find nearest maximum within 10 channels of selected value, watch out for the edges
            lmin = il-10 & lmax = il+10
            rmin = ir-10 & rmax = ir+10
            if lmin lt 0 then lmin = 0
            if lmin ge npts then lmin = npts-1
            if lmax lt 0 then lmax = 0
            if lmax ge npts then lmax = npts-1
            if rmin lt 0 then rmin = 0
            if rmin ge npts then rmin = npts-1
            if rmax lt 0 then rmax = 0
            if rmax ge npts then rmax = npts-1

            fpeakl=max(data1[lmin:lmax],lh)
            fpeakr=max(data1[rmin:rmax],rh)

            peaks = [lh,rh]

            jl = lh+lmin
            jr = rh+rmin

            jj1= jl
            jj2 = jr

            ; Find channels at f level of horns and at 1st null

            ; subtract the rms from the peak value
            FPEAK1 = F*(fpeakl-RMS)
            ; find left edge where value goes below fpeak1 for 3 consecutive channels
            if jl ge 2 then begin
                repeat begin
                    jl=jl-1 
                    if (jl lt 2) then break
                endrep until ((data1[jl] le fpeak1) and (data1[jl-1] le fpeak1) and (data1[jl-2] le fpeak1))
            endif
            if (jl lt 2) then begin
                message,'Left edge was not found, using left maximum location.',/info
                jl=jj1-1
            endif

            ; look for place where data values get negative
            if jj1 gt 0 then begin
                repeat begin
                    jj1=jj1-1 
                    if jj1 lt 0 then break
                endrep until (data1[jj1] le 0.0)
            endif

            if (jj1 lt 0) then begin
                message,string(thisfirst,format='("left start of profile was not found, using ",i6)'),/info
                jj1 = -1
            endif
            ; move right one channel
            jl=jl+1
            jj1=jj1+1

            ; repeat for the right edge
            ; subtract the rms from the peak value
            FPEAK2 = F*(fpeakr-RMS)
            ; find right edge where value goes below fpeak2 for 3 consecutive channels
            if (jr lt (npts-2)) then begin
                repeat begin
                    jr=jr+1 
                    if (jr gt (npts-3)) then break
                endrep until ((data1[jr] le fpeak2) and (data1[jr+1] le fpeak2) and (data1[jr+2] le fpeak2))
            endif
            if (jr gt (npts-3)) then begin 
                message,'Right edge was not found, using right maximum location.',/info
                jr=jj2+1
            endif

            ; look for place where data values get negative
            if jj2 lt (npts-1) then begin
                repeat begin
                    jj2=jj2+1 
                    if (jj2 ge npts) then break
                endrep until (data1[jj2] le 0.0)
            endif
            if (jj2 ge npts) then begin
                message,string(thisfirst+npts-1,format='("right start of profile was not found, using ",i6)'),/info
                jj2 = npts
            endif
            ; move left one channel
            jr=jr-1
            jj2=jj2-1
            break
        end
        4: begin
            if n_elements(rms) eq 0 then rms=stddev(data1)
            print, 'click on the positions for the two peaks'
            clk1 = click()
            if not clk1.ok then begin
                message,'There was a problem with plotter, can not continue',/info
                return, res
            endif
            clk2 = click()
            if not clk2.ok then begin
                message,'There was a problem with plotter, can not continue',/info
                return, res
            endif
            ; get clicked channels relative to thisfirst - in region of interest
            il=round(clk1.chan) - thisfirst
            ir=round(clk2.chan) - thisfirst

            if (il gt ir) then begin
                tmp = il
                il = ir
                ir = tmp
            endif

            ; find nearest maximum within 10 channels of selected value, watch out for the edges
            lmin = il-10 & lmax = il+10
            rmin = ir-10 & rmax = ir+10
            if lmin lt 0 then lmin = 0
            if lmin ge npts then lmin = npts-1
            if lmax lt 0 then lmax = 0
            if lmax ge npts then lmax = npts-1
            if rmin lt 0 then rmin = 0
            if rmin ge npts then rmin = npts-1
            if rmax lt 0 then rmax = 0
            if rmax ge npts then rmax = npts-1

            fpeakl=max(data1[lmin:lmax],lh)
            fpeakr=max(data1[rmin:rmax],rh)

            peaks = [lh,rh]

            jl = lh+lmin
            jr = rh+rmin

            jj1 = jl
            jj2 = jr

            ; Fit polynomial between 0.15(fpeak-rms) and 0.85(fpeak-rms)

            ; subtract the rms from the peak value
            FPEAK1 = (fpeakl-RMS)
	    pminl = 0.15*FPEAK1
	    pmaxl = 0.85*FPEAK1

            ; find left edge where value goes below pminl and pmaxl for 3 consecutive channels
	    ; first pmaxl
            if jl ge 2 then begin
                repeat begin
                    jl=jl-1 
                    if (jl lt 2) then break
                endrep until ((data1[jl] le pmaxl) and (data1[jl-1] le pmaxl) and (data1[jl-2] le pmaxl))
            endif
            if (jl lt 2) then begin
                message,'Left edge was not found, using left maximum location.',/info
                jl=jj1-1
            endif

	    ; now pminl
            if jj1 ge 2 then begin
                repeat begin
                    jj1=jj1-1 
                    if (jj1 lt 2) then break
                endrep until ((data1[jj1] le pminl) and (data1[jj1-1] le pminl) and (data1[jj1-2] le pminl))
            endif
            if (jj1 lt 2) then begin
                message,'Left edge was not found, using left maximum location.',/info
                jj1=-1
            endif

            ; move right one channel

            jl=jl+1
            jj1=jj1+1

	    ;print,jl,jj1

            ; repeat for the right edge
            ; subtract the rms from the peak value
            FPEAK2 = (fpeakr-RMS)
	    pminr = 0.15*FPEAK2
	    pmaxr = 0.85*FPEAK2

            ; find right edge where value goes below pminr and pmaxr for 3 consecutive channels
	    ; first pmaxr
            if (jr lt (npts-2)) then begin
                repeat begin
                    jr=jr+1 
                    if (jr gt (npts-3)) then break
                endrep until ((data1[jr] le pmaxr) and (data1[jr+1] le pmaxr) and (data1[jr+2] le pmaxr))
            endif
            if (jr gt (npts-3)) then begin 
                message,'Right edge was not found, using right maximum location.',/info
                jr=jj2+1
            endif

	    ; now pminr
            if (jj2 lt (npts-2)) then begin
                repeat begin
                    jj2=jj2+1 
                    if (jj2 gt (npts-3)) then break
                endrep until ((data1[jj2] le pminr) and (data1[jj2+1] le pminr) and (data1[jj2+2] le pminr))
            endif
            if (jj2 gt (npts-3)) then begin 
                message,'Right edge was not found, using right maximum location.',/info
                jj2=npts
            endif

            ; move left one channel
            jr=jr-1
            jj2=jj2-1

	    ;print, jr, jj2

	    ;Fits sides of profile
	     resultl = poly_fit(vel1[jj1:jl],data1[jj1:jl],1,sigma=sigmal,yerror=yerrorl,status=status)
	     if (status ne 0) then print,'fit to left side fails on status=',status
	     yfitl=poly(vel1,resultl)
	     resultr = poly_fit(vel1[jr:jj2],data1[jr:jj2],1,sigma=sigmar,yerror=yerrorr,status=status)
	     if (status ne 0) then print,'fit to right side fails on status=',status
	     yfitr=poly(vel1,resultr)

	     ;print,resultl
	     ;print,resultr

	      ; Plot fits over data.
	      x=getxarray()
	      yl = resultl[0]+resultl[1]*x
	      yr = resultr[0]+resultr[1]*x
	      gbtoplot,x,yl,color=2551
	      gbtoplot,x,yr,color=2551
	


	     ;Get widths
	      vl = (F*FPEAK1 - resultl[0])/resultl[1]
	      vr = (F*FPEAK2 - resultr[0])/resultr[1]

	      W = abs(vr - vl)
	      V = (vr + vl)/2.
	      verr=0.5*sqrt((rms/resultl[1])^2+(rms/resultr[1])^2)
              werr=2.*verr

	      al=1000*(resultl[0]+V*resultl[1])
	      ar=1000*(resultr[0]+V*resultr[1])
	      bl=resultl[1]*1000
	      br=resultr[1]*1000	
	      p1=(FPEAK1+RMS)*1000
	      p2=(FPEAK2+RMS)*1000
    	      if not keyword_set(quiet) then print, 'Right side fit (a + bx) =',al,bl, format='(a60,2f7.2)'	
    	      if not keyword_set(quiet) then print, 'Left side fit (a + bx) =',ar,br, format='(a60,2f7.2)'	
    	      if not keyword_set(quiet) then print, 'Peaks (right then left) =', p1, p2, format='(a60,2f7.2)'	
	      
              ;this sesms backwards, but going with variables defined above
              fitr = [al,bl]
              fitl = [ar,br]
              peaks = [p1,p2]


 	    ;Reset jj1 and jj2 to limits of user defined profile to measure flux.
            jj1 = 0
            jj2 = (npts-1)

            break
        end


        else: begin
            message,'Unrecognized mode, must be 1,2,3 or 4',/info
            return, -1
        end
    endswitch

    if mode eq 1 or mode eq 2 or mode eq 3 then begin
        ; true left break point between jl and jl-1 at fpeak1
        if jl le 0 then begin
            vl = vel1[0]
        endif else begin
            bl = (fpeak1-data1[jl-1])/(data1[jl]-data1[jl-1])
            VL = VEL1[JL-1]+BL*(VEL1[JL]-VEL1[JL-1])
        endelse

        ; true right break point between jr and jr+1 at fpeak2
        if jr ge (npts-1) then begin
            vr = vel1[npts-1]
        endif else begin
            br = (fpeak2-data1[jr])/(data1[jr+1]-data1[jr])
            VR = VEL1[JR]+BR*(VEL1[JR+1]-VEL1[JR])
        endelse
        W = abs(VR-VL)
        V = (VR+VL)/2.0
        verr=0
        werr=0
	endif

    ; compute area accurately, i.e. using the
    ; fact that the channels may not be evenly 
    ; spaced in velocity

    SDV = 0.0
    for I=jj1,jj2 do begin
        if i eq 0 then begin
            delv = abs(vel1[i+1]-vel1[i])
        endif else begin
            if i eq (npts-1) then begin
                delv = abs(vel1[i]-vel1[i-1])
            endif else begin
                delv = abs(vel1[i+1]-vel1[i-1])/2.0
            endelse
        endelse
        SDV = SDV + DATA1[I]*delv
	SDVERR=0
        if F eq 0.5 then begin
	    SDVERR = 2.*RMS*sqrt(1.4*w*delv)
	endif
        if F eq 0.2 then begin
	    SDVERR = 2.*RMS*sqrt(1.2*w*delv)
	endif
    endfor
    res[0]=sdv
    res[1]=w
    res[2]=v 
    res[3]=sdverr
    res[4]=werr
    res[5]=verr
    if not keyword_set(quiet) then print, 'Area, Width, Velocity (followed by errors in same order) =',res,string(res)+' ' ;format='(a60,6f8.2)'
    RETURN,res
END

