PRO asciiout,n,reducer,dir=dir
; A program to create a ascii data file for a reduced HI profile, in
; order to make plotting easier. 
; Version of March 2017
; Based on parts of write_ascii.pro, header.pro
; 
; Update History
; 19 Feb 2018 (David Stark): (1) project id number is now taken from the
; data file (2) code automatically sets the units to km/s if not
; already, (3) instead of assuming n=4 if n is not set, it looks for
; the most recently saved entry in the output file, (4) replaced
; "getrec" with "kgetrec". Otherwise incorrect spectra were output for
; me.

; 15 Mar 2018 (Karen Masters) fixed header info to match what's
; expected. 
;
; 29 May 2018 (David Stark): changed output file name to reflect
; newest convention
;
; 22 Oct 2019 (David Stark): switched kgetrec --> kget,nsave=n.  

; Input: reducer = optional name of person doing the data reduction
	if (n_elements(reducer) eq 0) then $
 	reducer='HI-MaNGA Team'
; Input: n = index of record being saved. It is assumed that n-1 is
; the spectrum pre-baseline subtraction
        if (n_elements(n) eq 0) then begin;$
           ;n = 4
           odc = !g.lineoutio->get_spectra()
           lastrec = n_elements(odc)-1
           n=lastrec
        endif


        print,'record being saved: ',n 
        kget,nsave=n-1

; Code from header.pro
        if (n_elements(dc) eq 0) then dc = !g.s[0]
        if (size(dc,/type) eq 2) then dc = !g.s[dc]
        isvalid = data_valid(dc,name=name)
        if (name ne 'SPECTRUM_STRUCT') then begin
           message,"header does not yet work in continuum mode.",/info
           return
        end
        if (isvalid eq -1) then begin
           message,'dc must be either continuum or spectrum', /info
           return
        endif
        if (isvalid eq 0) then begin
           message,'No spectrum is available.',/info
           return
        endif

        ;get project id
        projid = !g.s[0].projid
        ;trim off session #
        projid_sub = strsplit(projid,'_',/extract)
        projid = strtrim(projid_sub[0] + '_'+projid_sub[1],2)

        root=strtrim(dc[0].source)
	file='mangaHI-'+root+'.csv'
        if keyword_set(dir) then file = dir+file
	openw,lun,file,/get_lun	

        radecValue = getradec(dc,/quiet)
        radec=strtrim(adstring(radecValue[0],radecValue[1],0),2) ; RA,DEC string
        date = leftjustify(dc.date,11)  ;Date of observations
        Tint = leftjustify(string(dc.exposure,format='(F8.1)'),8,1)
        vel=leftjustify(string(dc.source_velocity/1.0e3,format='(F9.1)'),9,1)

        printf,lun,'################################################################################'
        printf,lun,'# HI-MaNGA: HI Followup for the MaNGA Survey' 
        printf,lun,'# Observed under code: '+projid ; GBT16A_095'
        printf,lun,'# Masters, K.L. et al. in prep.'
        printf,lun,'################################################################################'
        printf,lun,'# Telescope:   Robert C. Bryd Green Bank Telescope'
        printf,lun,'# Beam Size FWHM [arcminutes]: 9.0 '
        printf,lun,'# Object (MaNGA plate-ifu format): ', root
        printf,lun,'# RA Dec (J2000): ', radec
        printf,lun,'# Rest Frequency [MHz]:  1420.4058'
        printf,lun,'# Central velocity [km/s]: ',vel 
        printf,lun,'# Integration time [seconds]: ', Tint
        printf,lun,'# Date(s) of observations (UT): ', date
        printf,lun,'####################################################################################'
        printf,lun,'# ASCII Table'
        printf,lun,'# Generated by ',reducer, '  ', systime()
        printf,lun,'# The spectrum is baselined and Hanning smoothed'
        printf,lun,'# Columns are: Velocity of HI (km/s), Flux (Jy), Pre-baseline subtracted flux (Jy)'
        printf,lun,'####################################################################################'
        printf,lun,'# vHI,fHI,fBHI'

        if (getxunits() ne 'km/s') then begin
           setxunit,'km/s'
;           print,'Change x-units to km/s'
;           stop
        endif
        ;should be pre-baselined
;        kgetrec,n-1
        kget,nsave=n-1
        z=getyarray(count=nch)

        ;baselined
;        kgetrec,n
        kget,nsave=n
	x=getxarray(count=nch)
	y=getyarray(count=nch)
	for i = 0, nch-1, 1 do $
	if (FINITE(y[i]) eq 1) then printf,lun,x[i],y[i],z[i]
      
	close,lun
	free_lun,lun			

END
