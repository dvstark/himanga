;+
; Function to measure the area, width, and velocity of a galaxy
; profile.  The returned value is a 3-element array containing the
; area, width, and velocity.   The width and velocity are always given
; in km/s and the area is given in data units * km/s.
;
; <p>This is a front-end to <a href="awv.html">awv</a>.  The
; source code there originated at Arecibo.  See the comments there for
; a description of the 3 possibly values for mode and how f and rms
; are used.
;
; <p>The data currently displayed in the plotter is used.  The x-axis
; can be any type.  It will be converted to velocity using any
; previously set velocity offset.
;
; <p>If the region of interest is not specified, the user is asked to
; mark it interactively.
;
; <p>A baseline should have been removed prior to using this function.
;
; <p><B>Adapted by Karen Masters from code
; Contributed By: Karen O'Neil, NRAO-GB and Bob Garwood,
; NRAO-CV</B>
;
; @param mode {in}{required}{type=integer}  Must be one of 1,2,3 or 4.
; See the comments in <a href="../toolbox/awv2.html">awv2</a> for more
; details.
;
; @param f {in}{required}{type=float} Fraction of peak or mean used in
; locating the edges of the galaxy profile.  See the comments in 
; <a href="../toolbox/awv.html">awv</a> for more details.  Note that in
; mode 3 and 4, the user is always asked to mark the two horns of the galaxy
; profile with the cursor.
;
; @keyword ifirst {in}{optional}{type=integer} Defines one edge of the
; region of interest.  If not specified, the user is asked to mark both
; ifirst and last with the cursor.  It is not necessary that ifirst be
; less than last.
;
; @keyword last {in}{optional}{type=integer} Defines one edge of the
; region of interest.  If not specified, the user is asked to mark both
; ifirst and last with the cursor.  It is not necessary that ifirst be
; less than last.
;
; @keyword rms {in}{optional}{type=float} Used in modes 2 and 3 as
; described in <a href="../toolbox/awv.html>awv"</a>.  If this is not
; supplied, it defaults to the stddev of the data within the region of
; interest given by ifirst and last.
;
; @keyword quiet {in}{optional}{type=boolean} When set, the results
; are not printed to the terminal (they are still returned).
;
; @keyword highlightcolor {in}{optional}{type=color}{default=!g.highlightcolor}
; The color to use when the data in the region of interest is 
; highlighted.
;
; @uses <a href="../toolbox/awv.html">awv</a>
;
; @version $Id: gmeasure.pro,v 1.2.2.1 2005/12/12 18:41:54 gbtidl Exp $
;-
function mygmeasure,mode, f, ifirst=ifirst, last=last, rms=rms, quiet=quiet, $
                  highlightcolor=highlightcolor, fitl=fitl,fitr=fitr,peaks=peaks
    compile_opt idl2

    res = [0.0,0.0,0.0]

    if n_params() ne 2 then begin
        usage,'gmeasure'
        return,res
    endif

    npts = data_valid(getplotterdc())
    if npts le 0 then begin
        message,'The plotter is empty',/info
        return, res
    endif

    if mode ne 1 and mode ne 2 and mode ne 3 and mode ne 4 then begin
        message,'mode must be one of 1,2, 3 or 4',/info
        return, res
    endif

    if n_elements(highlightcolor) eq 0 then highlightcolor=!g.highlightcolor

    clearoplots

    if n_elements(ifirst) eq 0 or n_elements(last) eq 0 then begin
        print,'Mark the minimum and maximum velocity of the profile with the cursor (any mouse click)'
        c = click()
        gbtoplot,[c.x,c.x],getyrange(),color=!white
        ifirst = round(c.chan)
        c = click()
        gbtoplot,[c.x,c.x],getyrange(),color=!white
        last = round(c.chan)
        clearoplots
    endif
    if (ifirst gt last)then begin
        tmp=ifirst
        ifirst=last
        last=tmp
    endif
    if ifirst lt 0 then ifirst = 0
    if last lt 0 then last = 0
    if ifirst gt (npts-1) then ifirst = (npts-1)
    if last gt (npts-1) then last = (npts-1)

    ; highlight the data
    data = getyarray()
    gbtoplot,seq(ifirst,last), data[ifirst:last], color=highlightcolor, /chan

    if !g.plotter_axis_type eq 2 then begin
        ; x-axis is velocity, use it
        v = getxarray()
        if (getxunits() ne 'km/s') then begin
            ; must be m/s, scale to km/s
            v /= 1.d3
        endif
    endif else begin
        v = makeplotx(getplotterdc(),type=2) / 1.d3 ; always v is in m/s
    endelse
    return, myawv(data, v, ifirst, last, mode, f, rms=rms, quiet=quiet,fitl=fitl,fitr=fitr,peaks=peaks)
end
