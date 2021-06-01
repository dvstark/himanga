FUNCTION getgain
;Note these may not be the best values for tau and 
;apperture efficiency, but not too bad.

  tauz=get_tau(!g.s[0].observed_frequency/1.0e9)
  tau=tauz/sin((!pi/180)*!g.s[0].elevation)
  appeff=get_ap_eff(!g.s[0].observed_frequency/1.0e9)
  gain=2.85*appeff/(0.99*exp(tau))
  print, "Gain = ",gain
  return, gain

END
