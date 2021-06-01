PRO asciiout,root

	if (n_elements(root) eq 0) then $
 	root='junk'

	file=root+'.txt'
	lun=10
	openw,lun,file,/get_lun	
	x=indgen(512)
	y=indgen(512)

	x=getxarray()
	y=getyarray()

	for i = 0, 511, 1 do $
	if (FINITE(y[i]) eq 1) then printf,lun,x[i],y[i]
      
	close,lun
	free_lun,lun			

END

