pro reset_x,par_struct
                                ;adjust x range to match the min/max regions
  sel=where(par_struct.blregions ge 0,count)
  if count gt 1 then begin
     setxunit,'km/s'
     chans = minmax(par_struct.blregions[sel])
     vels = chantovel(!g.s[0],chans)
     unzoom
     setx,min(vels)/1000,max(vels)/1000
  endif else unzoom

end
  

pro trim_edges,nlow=nlow,nhigh=nhigh

  ;wrapper program for trimming the edges of spectra

  if not keyword_set(nlow) then nlow = 150
  if not keyword_set(nhigh) then nhigh = 150

  nchan=n_elements(get_chans(!g.s[0]))

  replace,0,nlow,/blank
  replace,nchan-1-nhigh,nchan-1,/blank
end

pro rfi_wrapper,par_struct

  ;wrapper program for easy RFI flagging and removal

  setxunit,'Channels'
  overlay_on=1
  done = 0
  copy,0,1
  while done eq 0 do begin
     
     ;show currently defined rfi regions
     if total(par_struct.rfi_regions ne -99) gt 0 and overlay_on then begin
        sel=where(par_struct.rfi_regions ne -99)
        for i=0,n_elements(sel)-1 do vline,par_struct.rfi_regions[sel[i]],label='rfi',ylabel=0.95,/ynorm
        sz = size(par_struct.rfi_regions,/dim)
        for i=0,sz[1]-1 do begin
           if par_struct.rfi_regions[0,i] ne -99 then replace,par_struct.rfi_regions[0,i],par_struct.rfi_regions[1,i]
        endfor
     endif

     if overlay_on then olabel = 'on' else olabel = 'off'

     print,''
     print,'flag rfi: f'
     print,'automated flagging (in prep): a'
     print,'erase all existing rfi regions: x'
     print,'toggle overlays: o (currently '+olabel+')'
     print,'quit: q'
     print,''     

     answer=''
     read,answer

     case answer of

        'o':begin
           if overlay_on eq 1 then begin
              clearovers
              overlay_on=0
           endif else overlay_on=1
        end


        'f':begin
           unzoom
           print,'click x range to zoom into'
           c=click()
           x0=c.x
           c=click()
           x1=c.x
           setx,x0,x1
           rfispike,inds=inds
           unzoom

           ;save clicked regions
           sel=where(par_struct.rfi_regions eq -99)
           ind_2d = array_indices(par_struct.rfi_regions,sel)
           yinds = ind_2d[1,*]
           yinds = yinds[uniq(yinds,sort(yinds))]
           par_struct.rfi_regions[*,yinds[0]] = inds

        end

        'a':begin
           find_rfi,3,5,500,badchans
           ;save all these regions
           sel=where(badchans ne -1,count)
           if count gt 0 then begin
              
              badchans=badchans[sel]
              ;find consecutive blocks
              fid=indgen(count)
              for jj=1,count-1 do begin
                 if badchans[jj] eq badchans[jj-1]+1 then fid[jj]=fid[jj-1] $
                 else fid[jj] = fid[jj-1]+1
              endfor
              
              ;show on plotter and save regions
              
              d=*!g.s[0].DATA_PTR
              for jj = 0,max(fid) do begin
                 ;print,'fid: ',fid[jj]
                 ;print,where(fid eq jj)
                 xvals = badchans[where(fid eq jj)]
                 yvals = d[xvals]
                 gbtoplot,xvals,yvals,color=250
                 ;print,xvals,yvals
              endfor
              answer=''
              print,'flag this rfi? (y/n)'
              read,answer
              
              if strlowcase(answer) eq 'y' then begin

                                ;save these regions
                 for jj = 0,max(fid) do begin
                    inds = minmax(badchans[where(fid eq jj)])
                    sel=where(par_struct.rfi_regions eq -99)
                    ind_2d = array_indices(par_struct.rfi_regions,sel)
                    yinds = ind_2d[1,*]
                    yinds = yinds[uniq(yinds,sort(yinds))]
                    par_struct.rfi_regions[*,yinds[0]] = inds
                    replace,inds[0],inds[1]
                 endfor
              endif

           endif else print,'no rfi found'

        end


        'x':begin
           par_struct.rfi_regions[*,*]=-99
           kget,nsave=load_ind    
        end

        'q':begin
                                ;reapply all rfi flags (in case
                                ;someone was just rechecking, but not
                                ;redefining, rfi flags
           sel=where(par_struct.rfi_regions ne -99,count)
           if count gt 0 then begin
              sz = size(par_struct.rfi_regions,/dim)
              for i=0,sz[1]-1 do begin
                 if par_struct.rfi_regions[0,i] eq -99 then break $
                 else replace,par_struct.rfi_regions[0,i],par_struct.rfi_regions[1,i]
              endfor
           endif

           done = 1
        end

        else:print,'choose valid option'

     endcase
     clearvlines
     unzoom

endwhile

end

pro do_smooth

  ;wrapper program that smooths data

  boxcar,4,/dec
  hanning
  unzoom
end

pro do_region,par_struct
  ;wrapper program for defining baseline fitting regions
  unzoom
  setregion
  par_struct.blregions = !g.regions 
end

pro do_baseline,par_struct

  ;wrapper program for easy baseline fitting
  ;!g.regions=par_struct.blregions
  fit_order=par_struct.fit_order
  s0=0
  s1 = max(where(par_struct.blregions[0,*] ne -1))
  nregion,par_struct.blregions[*,s0:s1]
  showregion

;  print,!g.regions[*,0:10],fit_order
;  showregion
  if fit_order eq -1 then fit_order=autobaseline()
  bshape,nfit=fit_order
  zline,/on
  
  goodbl=0
  print,'Auto baseline fit order: '+strtrim(string(fit_order),2)
  while 1-goodbl do begin
     print,'Accept baseline: ENTER'
     print,'Provide new fit order: [fit order]'
     print,'Rerun automatric baseline fit: a'
     answer=''
     read,answer
;     clearovers
     case answer of
        '':begin
           baseline
           goodbl=1
        end
        'a':begin
           fit_order=autobaseline()
;           print,'determined best order: ',fit_order
           bshape,nfit=fit_order
        end
        else:begin
           if valid_num(answer) then begin
              fit_order = uint(answer)
              bshape,nfit=fit_order,color=long(round(245+randomu(seed)*10))
           endif else print,'invalid entry'
        end
     endcase
  endwhile
  par_struct.fit_order=fit_order
end

pro do_quickwidth,par_struct

  ;wrapper program to calculate HI profile properties

  zline,/on
  print,'click x range to zoom into'
  c=click()
  x0=c.x
  c=click()
  x1=c.x
  setx,x0,x1
                                ;getpeak,ymax=peak
  quickwidth,0,par_struct.statinfo.rms,widthinfo=widthinfo,/calc_peak
  unzoom
  par_struct.awvinfo=widthinfo
  print,''
  tag = tag_names(widthinfo)
  for i=0,n_elements(tag)-1 do print,tag[i],widthinfo.(i)
end
  
pro do_stats,par_struct

  ;wrapper program to calculate statistical properties of background noise
  print,'Choose a SIGNAL-FREE region to measure the noise of the spectrum'

  zline,/on
  stats,ret=statinfo
                                ;sometimes data types change...replace
                                ;each value in par array explicitly
  par_struct.statinfo = {bchan:long(statinfo.bchan),$
                         echan:long(statinfo.echan),$
                         nchan:long(statinfo.nchan),$
                         xmin:double(statinfo.xmin),$
                         xmax:double(statinfo.xmax),$
                         min:double(statinfo.min),$
                         max:double(statinfo.max),$
                         mean:double(statinfo.max),$
                         median:double(statinfo.median),$
                         rms:double(statinfo.rms),$
                         variance:double(statinfo.variance),$
                         area:double(statinfo.area)}

print,''
print,'rms = '+string(par_struct.statinfo.rms)

end

pro do_gasmass,par_struct
  ;determine if we're looking at an upper limit or a detection
  if par_struct.awvinfo.fhi ne 0 then detection=1 else detection=0
  if detection then lab='detection' else lab='non-detection'
  print,'Calculating assuming this is a '+lab+'. Correct?'
  answer=''
  read,answer

  if strupcase(answer) eq 'N' or strupcase(answer) eq 'NO' then begin
     if detection then begin
        ;clear the awv info data
        print,'clearing profile parameter measurements'
        ntags = n_tags(par_struct.awvinfo)
        for i=0,ntags-1 do par_struct.awvinfo.(i)=0
        detection=0
     endif else begin
        print,'HI flux = 0. Go back and measure'
        return
     endelse
  endif

  if detection then begin
     HImass,par_struct.awvinfo.fhi,par_struct.awvinfo.vhi,mhi=mhi
     par_struct.logmhi=mhi
     par_struct.logmhilim200kms=0d
;     print,''
;     print,'log MHI = ',par_struct.logmhi
  endif else begin 
     HImasslimit,par_struct.statinfo.rms*1000,par_struct.obsinfo.vopt,mhi=mhi
     par_struct.logmhilim200kms = mhi[1]
     par_struct.logmhi=0d
     
;     print,''
;     print,'log MHI limit (200km/s) = ',par_struct.logmhilim200kms

  endelse

  

end


function gatekeeper,stage,task_str

                                ;says whether we are allowed to
                                ;proceed to a given step (checks that
                                ;all prior steps are complete)

  proceed=1
  
  ntags = n_tags(task_str)
  status_arr = intarr(ntags)
  for i=0,ntags-1 do status_arr[i]=task_str.(i).status
  
  if stage gt 0 then begin
     unfinished = total(status_arr[0:stage-1] eq 0)
     if unfinished ne 0 then proceed = 0
  endif
  
  if proceed eq 0 then print,'None shall pass! (you forgot something)'
  return,proceed
  
end

function create_menu,task_str

                                ;simple code to create a menu
                                ;indicating which steps can be done,
                                ;and which have been completed
  ntags = n_tags(task_str)

  menu = strarr(ntags)

     print,''
     print,';;;;;;;;;;;;;;;;;;;;;;;;;'
     print,'Choose a task:'

  nc=strtrim(27B,2)+'[0m'
  redtext=strtrim(27B,2)+'[31;3m'
  bluetext=strtrim(27B,2)+'[34;3m'

  for i=0,ntags-1 do begin
     status_str = ''
     if task_str.(i).status eq 1 then status_str = redtext+' (done)'+nc $
     else if task_str.(i).status eq -1 then status_str =  bluetext+' (optional)'+nc
     menu[i] = strtrim(string(i),2)+': '+task_str.(i).label+status_str
  endfor

  menu = [menu,'q: Quit',$
         'x [x0 x1]: set x (leave x0,x1 empty to unzoom)',$
         'y [y0 y1]: set y (leave y0,y1 emplty to unzoom)']

     for i = 0,n_elements(menu)-1 do print,menu[i]
     print,';;;;;;;;;;;;;;;;;;;;;;;'
     print,''
end

pro print_summary,par

           print,'****************'
           print,'    Summary     '
           print,'****************'
           print,'Name: ',par.name
           print,'T_int:',par.obsinfo.tint
           print,'Tsys: ',par.obsinfo.tsys
           print, 'rms: ',par.statinfo.rms
           tags = tag_names(par.awvinfo)
           for i=0,n_elementS(tags)-1 do print,tags[i],par.awvinfo.(i)
           print,'logMHI: ',par.logmhi
           print, 'logMHI (lim): ',par.logmhilim200kms

end

pro reduce_gbt,galaxy,reducer=reducer,overwrite=overwrite

  if n_params() eq 0 then begin
     print,''
     print,'calling sequence:'
     print,'   reduce_gbt,galaxy,reducer=reducer,overwrite=overwrite'
     print,''
     print,'galaxy = MaNGA plate-ifu designation'
     print,'reducer = your name'
     print,'overwrite = flag to erase existing data reduction files and start from scratch'
     print,''
     return
  endif


  ;primary code. Steps through each stage of the reduction.

;This code should allow one to go back and redo steps as needed.
;Spectra are saved in different indices in the output file, and these
;are linked to given steps int the program.
;  load_ind, save_ind, step
;  None, 0, scans loaded
;  0,1, trim edges
;  1,2, rfi removal
;  2,3, data smoothed
;  3,4, baseline removed


  if 1-keyword_set(reducer) then begin
     reducer=''
     print,'Who goes there?'
     read,reducer
  endif

  if reducer eq '' then reducer='HI-MaNGA Team'

;  if keyword_set(outputdir) then begin
;     if 1-file_test(outputdir,/directory) then begin
;        print,'Specificied output directory does not exist. Creating.'
;        spawn,'mkdir '+outputdir
;     endif
;  endif else outputdir = './'
  new=0
  if keyword_set(overwrite) or file_test(galaxy+'.fits') eq 0 then new=1

  fileout,galaxy+'.fits',new=new
  sprotect_off

                                ;write tasks dictionary. 0 = not done
                                ;yet, 1 means done, -1 means optional
                                ;and not done
  tasks={$
        load_scans:{status:0,label:'Load Scans'},$
         inspect_scans:{status:-1,label:'Inspect Scans'},$
         trim_edges:{status:0,label:'Trim Edges'},$
         remove_rfi:{status:-1,label:'Remove RFI'},$
         smooth:{status:0,label:'Smooth Data'},$
         baseline_regions:{status:0,label:'Set Baseline Regions'},$
         fit_baseline:{status:0,label:'Fit Baseline'},$
         measure_rms:{status:0,label:'Measure RMS'},$
         measure_prof:{status:-1,label:'Measure Profile Parameters'},$
        measure_mhi:{status:0,label:'Measure HI mass/upper limit'},$
         write_catalog:{status:0,label:'Write Out Spectra'}$
         }

  ;empty structure to hold stat info
  obsinfo={tsys:0d,tint:0d,vopt:0d,sessions:''}
  statinfo = {bhan:0L,echan:0L,nchan:0L,xmin:0d,xmax:0d,min:0d,max:0d,mean:0d,median:0d,rms:0d,variance:0d,area:0d}
  awvinfo_orig = {peak:0d,snr:0d,xmin:0L,xmax:0L,fhi:0d,vhi:0d,wm50:0d,wp50:0d,wp20:0d,eV:0d,w2p50:0d,wf50:0d,al:0d,bl:0d,ar:0d,br:0d,pr:0d,pl:0d}

  par = {name:galaxy,rfi_regions:intarr(2,100)-99,tasks:tasks, blregions:intarr(2,100)-99, fit_order:-1,statinfo:statinfo,awvinfo:awvinfo_orig,obsinfo:obsinfo, logmhi:0d,logmhilim200kms:0d}
  
                                ;if there exists a parameter file already and overwrite not set, load it in
  if file_test(galaxy+'_par.sav') and 1-keyword_set(overwrite) then restore,galaxy+'_par.sav'

                                ;some older .par files may have had
                                ;extra white space in their scan info
                                ;arrays when first created. Quick fix:
  if tag_exist(par,'scans') then begin
     nscan = n_elements(par.scans.scaninfo)
     for i=0,nscan-1 do begin
        par.scans.scaninfo[i].projid = strcompress(par.scans.scaninfo[i].projid,/remove_all)
        par.scans.scaninfo[i].scan_id = strcompress(par.scans.scaninfo[i].scan_id,/remove_all)
        par.scans.scaninfo[i].datapath = strcompress(par.scans.scaninfo[i].datapath,/remove_all)
        par.scans.scaninfo[i].source = strcompress(par.scans.scaninfo[i].source,/remove_all)
        par.scans.scaninfo[i].proc = strcompress(par.scans.scaninfo[i].proc,/remove_all)

     endfor
  endif

  ;determine last step run (if any) and load that spectrum
  ntags=n_tags(par.tasks)
  statuses = intarr(ntags)
  for i=0,ntags-1 do statuses[i] = par.tasks.(i).status

  laststep = where(statuses eq 1,count)
  if count gt 0 then begin
     laststep = laststep[n_elements(laststep)-1] + 1
     if laststep gt 10 then begin
        print,'You have fully reduced this data (unless you want to go back and fix something).'
                                ;load final spectrum
        load_ind=4
        kget,nsave=load_ind
        reset_x,par
        show     
        print_summary,par
     endif else begin
        print,''
        print,'Keep going champ! You are on stage '+strtrim(string(laststep),2)+' ('+par.tasks.(laststep).label+')'
     endelse

  endif


  finished = 0
  while finished eq 0 do begin

                                ;use tasks dictionary to create menu
     menu=create_menu(par.tasks)

     answer=''
     read,answer
     answer_orig=answer
     answer = (strsplit(answer,/extract))[0]

                                ;check if we're allowed to proceed

;fix this so we can have bad input and not crash
     ;if answer eq 'q' then proceed = 1 $
     ;else proceed = gatekeeper(uint(answer),tasks)
         
     ;if proceed eq 0 then print,'Finish all prior tasks first' else begin
        
     print,''
        
     case answer of
        '0':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;load scans;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

           print,'loading scans'
           fetch_data,galaxy,'/users/dstark/17AGBT012/database/stable/mangahi_scandb.fits',scaninfo=scaninfo
           unzoom
           if n_elements(scaninfo) eq 0 then return
           if tag_exist(par,'scans') then struct_delete_field,par,'scans'
           scans={scaninfo:scaninfo}
           struct_add_field,par,'scans',scans
           
           par.obsinfo.tsys = !g.s[0].tsys
           par.obsinfo.tint = !g.s[0].exposure
           par.obsinfo.vopt = !g.s[0].source_velocity/1000.

           sessions = scaninfo.projid
           sessions = sessions[uniq(sessions,sort(sessions))]
           par.obsinfo.sessions=strjoin(sessions,'-')
           save_ind = 0
           nsave,save_ind
           par.tasks.(0).status=1
        end
        '1':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;inspect scans;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              inspect_scan,par.scans.scaninfo
                                ;need to refetch data after flagging
              print,'reloading data'
              fetch_data,galaxy,'/users/dstark/17AGBT012/database/stable/mangahi_scandb.fits',scaninfo=scaninfo
              ;update scan info  
              par.obsinfo.tsys = !g.s[0].tsys
              par.obsinfo.tint = !g.s[0].exposure
              save_ind = 0
              nsave,save_ind
              par.tasks.(1).status=1
           endif 
        end
        '2':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;trim edges;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              load_ind=0
              kget,nsave=load_ind
              print,'trimming edges'
              trim_edges
              unzoom
              par.tasks.(2).status=1
              save_ind=1
              nsave,save_ind
              ;save in ind_2 also. This will be replaced if we remove rfi
              save_ind=2
              nsave,save_ind
           endif
        end
        '3':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;remove any rfi;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              load_ind=1 
              kget,nsave=load_ind    
              rfi_wrapper,par        
              par.tasks.(3).status=1
              save_ind=2
              nsave,save_ind
           endif 
        end
        '4':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;smooth data;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              load_ind=2
              kget,nsave=load_ind
              print,''
              do_smooth
              par.tasks.(4).status=1
              save_ind=3
              nsave,save_ind
           endif 
        end
        '5':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;define baseline regions;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              load_ind=3
              kget,nsave=load_ind
              print,''
              do_region,par
              par.tasks.(5).status=1
              reset_x,par
           endif
        end
        '6':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;fit baseline;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              print,''
              load_ind=3
              kget,nsave=load_ind
              reset_x,par
              do_baseline,par
              save_ind=4
              nsave,save_ind
              par.tasks.(6).status=1
              reset_x,par
           endif 
        end
        '7':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;calculate rms;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              print,''
              load_ind=4
              kget,nsave=load_ind
              reset_x,par
              do_stats,par
              par.tasks.(7).status=1
           endif 
        end
        '8':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;calculate profile properties;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              print,''
              load_ind=4
              kget,nsave=load_ind
              reset_x,par
              do_quickwidth,par
              par.tasks.(8).status=1
              reset_x,par
           endif 
        end
        '9':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;calcualte atomic gas mass/limit;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           load_ind=4
           kget,nsave=load_ind
           do_gasmass,par
           par.tasks.(9).status=1
        end
        '10':begin
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;write out spectrum;;;;;;;;;;;;;;;;;;;
           ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
           if gatekeeper(uint(answer),par.tasks) then begin
              print,''
              load_ind=4
              kget,nsave=load_ind
              show
              asciiout,load_ind,reducer;,dir=outputdir
              asciifile = 'mangaHI-'+par.name+'.csv'
              ascii_to_fits,asciifile
              par.tasks.(10).status=1
                                ;save output to formatted .fits file
           endif 
        end
        'q':begin

           ;print out the key pamaraters for a sanity check
           
           print_summary,par

           print,'Ja ne'
           finished=1
        end
        'x':begin
           sub = strsplit(answer_orig,/extract)
           if n_elements(sub) eq 1 then begin
              unzoom
              zoom_off=1
           endif

           if n_elements(sub) eq 3 then begin
              x0 = sub[1]*1.
              x1 = sub[2]*1.
              setx,x0,x1
              zoom_on = 1
           endif
        end
        'y':begin
           sub = strsplit(answer_orig,/extract)
           if n_elements(sub) eq 1 then begin
              unzoom
              zoom_off=1
           endif

           if n_elements(sub) eq 3 then begin
              y0 = sub[1]*1.
              y1 = sub[2]*1.
              sety,y0,y1
              zoom_on = 1
           endif
        end

        else:begin
           print,''
        end
        
     endcase
     
                                ;save after every step
     if answer ne 'q' and answer ne '' then setxunit,'km/s'
     save,par,filename=galaxy+'_par.sav'
     
     
  endwhile

end

