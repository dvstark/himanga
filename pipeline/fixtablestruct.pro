function fixtablestruct, str 

                                ;routine to turn a structure of arrays
                                ;into an array of structures (far
                                ;easier to work with!!  This is mainly
                                ;to clean up old code I wrote before I
                                ;really understood structures

  ;get tag names for structure
  tagnames = tag_names(str)
  
  nobj = n_elements(str.(0))

  ;create a single row of structure array and replicate
  row = create_struct(tagnames[0],str.(0)[0])
  for i=1,n_elements(tagnames)-1 do $
     row = create_struct(row,tagnames[i],str.(i)[0])

  table = replicate(row,nobj)

  for i=0,n_elements(tagnames)-1 do begin
     table.(i) = str.(i)
  endfor

  return,table

end

restore,'/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_020620_nsamatch_1.5beam.fits'
newstr = fixtablestruct(matches)

end
