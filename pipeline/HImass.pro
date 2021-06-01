pro HImass, FHI, vbary,mhi=mhi

 print, 'The total HI flux is in Jy.km/s', FHI
 c=299792.46
 dist = lumdist(vbary/c) 
 print, ' Distance (in Mpc) is = ', dist

; Mass of HI in Msun
 MHI = alog10(2.356e5*(dist^2)*FHI)
 
; Output
 print, 'The HI mass (log MHI/Msun) is: ', MHI

end
