sclear
 unzoom

  file = '/home/david-stark/manga/hi/gbt/data/AGBT17A_012_126.raw.vegas'

  filein,file

  s0 = 33
  reps = 3

  scans = indgen(2*reps)+s0

  nscans = n_elements(scans)
  for i=min(scans),max(scans), 2 do begin
     getps,i,plnum=0;,units='Jy'
     accum
     getps,i,plnum=1;,units='Jy'
     accum
  end

  ave
  boxcar,4,/dec
  hanning

  setregion
  
  bestorder=autobaseline()
  bshape,nfit=bestorder
  baseline
  setxunit,'Channels'
  setx,min(!g.regions[where(!g.regions gt 0)]),max(!g.regions)
  setxunit,'km/s'
  zline,/on
  
  end
