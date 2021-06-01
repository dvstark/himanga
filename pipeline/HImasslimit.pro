

pro HImasslimit, rms, vbary,mhi = mhi

 print, ' Assuming rms in mJy = ', rms
 c=299792.46
 dist = lumdist(vbary/c) 
 print, ' Distance (in Mpc) is = ', dist
 
;Range of widths in km/s
 w=[100,200,300,400]

; HI flux in Jy.km/s
 FHI = rms*w/1000

; Mass of HI in Msun
 MHI = alog10(2.356e5*(dist^2)*FHI)
 
; Output
 print,'Output is assumed width, and implied 1 sigma mass limit (log10(MHI/Msun))'
 print, w, MHI

end 
