pro check_duplicates,logfile

  print,'finding duplicate files noted in '+logfile

  openr,1,logfile

  begin_dup = 0

  line=''
  while ~EOF(1) do begin
     readf,1,line
;     print,line
     
     if (strpos(line,'DUPLICATE'))[0] eq -1 then begin_dup=1
     
     if begin_dup then begin
        paths = strsplit(line,' ',/extract)
        if n_elementS(paths) gt 1 then begin
           path1=paths[0]
           path2=paths[1]

           print,path1,path2
           compare_duplicates,path1,path2
           print,''
        endif
     endif




  endwhile


  close,1
  
end

;check_duplicates,'/users/dstark/17AGBT012/master/reduction_files/file_merge_log_23Jun2021.txt'
;
;end
