pro compare_duplicates,file1,file2

                                ;This codes takes two paths specifying
                                ;the location of *par.sav files which
                                ;exist for the same galaxy but in two
                                ;different locations, then compares
                                ;the outputs and spectra.  The user
                                ;can choose which one to keep.  The
                                ;one that is not kept is moved (along
                                ;with all supporting files) to a
                                ;"duplicates" directory which is
                                ;created in the file path if it
                                ;doesn't already exist.  This code is
                                ;meant to be used in conjuction with
                                ;"check_duplicates.pro" which reads a
                                ;list of duplicates from the output
                                ;log file from
                                ;"collect_reduction_files.pro"


  if 1-file_test(file1) or 1-file_test(file2) then begin
     print,'Missing files. Exiting'
     return
  endif


  restore,file1
  par1=par
  restore,file2
  par2=par

  print,'NAME ',par1.name,'  ',par2.name

  print,'RMS',par1.statinfo.rms,par2.statinfo.rms
  tags = tag_names(par1.awvinfo)
  for i=0,n_elements(tags)-1 do print,tags[i],par1.awvinfo.(i),par2.awvinfo.(i)
  tags = tag_names(par1.obsinfo)
  for i=0,n_elements(tags)-1 do print,tags[i],par1.obsinfo.(i),par2.obsinfo.(i)
  print,'LOGMHI',par1.logmhi,par2.logmhi
  print,'LOGMHILIM200KMS',par1.logmhilim200kms,par2.logmhilim200kms

  ;separate off file name to get path
  path1 = strsplit(file1,'/',/extract)
  reducer1 = path1[4]
  path1 = '/'+strjoin(path1[0:n_elements(path1)-2],'/')+'/'
  path2 = strsplit(file2,'/',/extract)
  reducer2 = path2[4]
  path2 = '/'+strjoin(path2[0:n_elements(path2)-2],'/')+'/'
  print,'users: ',reducer1,'    ',reducer2

  ;read spectra and plot
  spec1 = mrdfits(path1+'mangaHI-'+par1.name+'.fits',1,/silent)
  spec2 = mrdfits(path2+'mangaHI-'+par2.name+'.fits',1,/silent)

  !p.multi=[0,2,1]
  plot,spec1.vhi,spec1.fhi,xrange=par1.obsinfo.vopt + [-500,500],xtitle='velocity',ytitle='flux density',/xsty
  oplot,[-100000,100000],[0,0],thick=3,linestyle=2
  plot,spec1.vhi,spec1.fhi,xrange=par2.obsinfo.vopt + [-500,500],xtitle='velocity',ytitle='flux density',/ysty
  oplot,[-100000,100000],[0,0],thick=3,linestyle=2


  print,''
  print,'Which should we keep?'
  print,'1: ',reducer1
  print,'2: ',reducer2
  print,'q: ','exit'
  answer=''
  read,answer
  if answer eq '1' then begin
     movepath = path2+'duplicates/'
     movecommand = 'mv '+path2+'*'+par2.name+'* '+movepath
  endif else if answer eq '2' then begin
     movepath = path1+'duplicates/'
     movecommand = 'mv '+path1+'*'+par1.name+'* '+movepath
  endif

  if 1-file_test(movepath,/directory) then spawn,'mkdir '+movepath
  print,movecommand
  spawn,movecommand

end

;; file1='/users/dstark/17AGBT012/reduced/cfielder_copy/final/8445-3704_par.sav'
;; file2='/users/dstark/17AGBT012/reduced/dstark/final/8445-3704_par.sav'

;; compare_duplicates,file1,file2

;; end
