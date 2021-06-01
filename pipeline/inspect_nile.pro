;kluging more general version of inspector.pro to work with Nile's data

function extract_name,files

  names = strarr(n_elements(files))
  
  for i=0,n_elements(files)-1 do begin

     f = strsplit(files[i],'/',/extract)
     f = f[n_elements(f)-1]
     s=strsplit(f,'_par.sav',/extract,/regex)
     names[i] = s[0]

  endfor

  return, names

end

     

function collect_files,dir

  files = file_search(dir + '*par.sav')

  return, files

end

     
  
  
pro inspector

common catalog_state, status, listname

status={baseID:0L, $                
        listwidget: 0L, $
        working_dir:'./',$
        drawwidget:0,$
        plotwidget:0,$
        search:0,$
        param:0,$
        move:0,$
        marvin:0,$
        current_index:0,$
        zline:0,$
        replot:0,$
        resetplot:0,$
        diagplot:0,$
        ploton:0,$
        xrange:[0.,0.],$
        yrange:[0.,0.], $
        showbaseline:0, $
       statregions:[0,0]}



main=widget_base(title='HI Analysis Tool', $
                tlb_frame_attr=1, xsize=1000, ysize=730, mbar=top_menu, $
                 uvalue='main',/row)

;;;create menus at top;;;;

topmenu=widget_button(top_menu, value=' File ')
buttonrefresh = widget_button(topmenu,value='Refresh',uvalue='refresh')
buttonclean = widget_button(topmenu,value='Remove Finalized Objects',uvalue='remove_finalized')
buttonexit=widget_button(topmenu,value=' Exit ',uvalue='exit')


plotmenu=widget_button(top_menu, value=' Plot ')
buttonzline=widget_button(plotmenu,value = ' Zeroline ', uvalue='zline')
buttonbaseline = widget_button(plotmenu,value=' Plot pre-baselined/baselined spectrum', uvalue='bltoggle')

imagemenu=widget_button(top_menu, value=' Image ')
plotsdss=widget_button(imagemenu, value= ' SDSS ', uvalue='getsdss')

;create list of objects
listbase=widget_base(main,/column)
listlabel=widget_label(listbase,value='Object')
;read in nile's catalog to get list of objects
ncat = mrdfits('/users/dstark/17AGBT012/reduced/nsamanso/nsamanso_reduced.fits',1)
listname = strtrim(ncat.plateifu,2)
print,n_elements(listname)

;go through "final" directories and remove any objects which have been
;finished
donefiles = file_search('/users/dstark/17AGBT012/reduced/nsamanso/final/mangaHI-*.csv')
donefiles = [donefiles,file_search('/users/dstark/17AGBT012/reduction/DS_reductions/nsamanso_fix/final/mangaHI-*.csv')]
for i=0,n_elements(donefiles)-1 do begin
   root = strsplit(donefiles[i],'mangaHI-',/extract,/regex)
   root = root[n_elements(root)-1]
   root = strsplit(root,'.',/extract)
   root = strtrim(root[0],2)
   print,total(listname eq root)
   listname = listname[where(listname ne root)]
endfor
print,n_elements(listname)
stop

status.listwidget=widget_list(listbase, value=listname, uvalue='objlist',xsize=12,ysize=20)

label=widget_label(listbase, value='Search for Object')
status.search = widget_text(listbase, uvalue='search',/editable,/wrap)
status.marvin=widget_button(listbase,uvalue='marvin',value='View in Marvin')

;create plot window
;plot window
;status.plotxsize=700
;status.plotysize=400
drawbase=widget_base(main,/column,/frame)
status.drawwidget = widget_draw(drawbase, uvalue='draw',xsize=700,ysize=350,/button_events)
status.plotwidget = widget_Draw(drawbase,uvalue='plot',xsize=700,ysize=300)
paramwidget=widget_base(main,/column)
status.param = widget_text(paramwidget,xsize=20,ysize=28)
status.move = widget_button(paramwidget,value = 'Move to Final',uvalue='move')


widget_control, main, /realize

xmanager, 'inspector', main, /no_block


end


pro inspector_event,event

  common catalog_state, status, listname
  common spec, spec, db, dbind ;need spec data in common block otherwise it disappears after each event
  common plotting, x1, y1

  ref_cat = '/users/dstark/17AGBT012/idl_routines/mangaHIall.fits'
  drpallfile = '/users/dstark/17AGBT012/idl_routines/drpall-v2_4_3.fits'
  nile_cat = '/users/dstark/17AGBT012/reduced/nsamanso/nsamanso_reduced.fits'
  finaldir = './final'
  ref = mrdfits(ref_cat,1,/silent)
  db = mrdfits(drpallfile,1,/silent)
  ncat = mrdfits(nile_cat,1,/silent)
  mstars = fltarr(n_elements(ref))
  match,strtrim(ref.plateifu,2),strtrim(db.plateifu,2),ind1,ind2
  mstars[ind1]=alog10(db[ind2].nsa_elpetro_mass)
  
  ncat.plateifu = strtrim(ncat.plateifu,2)  
  ncatind = where(ncat.plateifu eq listname[status.current_index])
  ncat = ncat[ncatind]

widget_control, event.id, get_uvalue=uvalue 

case 1 of
   
   uvalue eq 'exit':begin
      widget_control, event.top, /destroy
      return
   end
   
   (uvalue eq 'objlist') or (uvalue eq 'search'):begin

      status.showbaseline=0

      if uvalue eq 'objlist' then begin
      
         status.current_index = event.index
         found=1

      endif else if uvalue eq 'search' then begin

         widget_control, status.search, get_value=searchstring
         searchstring=strtrim(searchstring[0],2)
         newind = where(listname eq searchstring)
         found = newind ne -1
         if found then status.current_index = newind
         widget_control,status.search,set_value=''
      endif 

      if found then begin
         loadobj:
         status.diagplot=1
;         restore,status.working_dir+listname[status.current_index]+'_par.sav'
                                ;load data for this object
         ncat = mrdfits(nile_cat,1,/silent)
         ncat.plateifu = strtrim(ncat.plateifu,2)  
         ncatind = where(ncat.plateifu eq listname[status.current_index])
         ncat = ncat[ncatind]
         
         dbind = where(strtrim(db.plateifu,2) eq strtrim(ncat.plateifu,2))
         widget_control,status.listwidget,set_list_select=status.current_index

         ;get the regions where we measured the statistics


         param_string = ['Target Parameters',$
                         '------------------']
         tags = tag_names(ncat)
         for i=0,n_elementS(tags)-1 do param_string=[param_string,tags[i]+': '+strtrim(string(ncat.(i)),2)]
         widget_control, status.param, set_value=param_string
         


         specfile = '/users/dstark/17AGBT012/reduced/nsamanso/mangaHI-'+listname[status.current_index]+'.fits'
         spec_exists = file_test(specfile)
         if spec_exists then begin
            spec = mrdfits(specfile,1)
            nonblspec = spec.bhi
            blspec = spec.fhi
            plotspec = blspec
            status.replot=1
            status.resetplot=1
         endif else begin
               wset,32
               erase
               xyouts,0.5,0.5,'Missing spectrum file',color=cgcolor('red'),/norm,align=0.5,charsize=2
               wset,33
               erase
         endelse      
      endif else begin
            wset,32
            erase
            xyouts,0.5,0.5,'Object not found',color=cgcolor('red'),/norm,align=0.5,charsize=2
            wset,33
            erase
            
         endelse
   end
      
   uvalue eq 'bltoggle':begin
      if status.showbaseline eq 0 then begin
         status.showbaseline = 1
         plotspec = spec.bhi;nonblspec
      endif else if status.showbaseline eq 1 then begin
         status.showbaseline = 0
         plotspec = spec.fhi
      endif
      status.replot=1
      status.resetplot=1
   end

   uvalue eq 'zline':begin
      if status.zline eq 1 then status.zline=0 $
      else if status.zline eq 0 then status.zline=1
      status.replot=1
   end

   uvalue eq 'draw':begin
;      wset,32
      if event.press eq 4 then status.resetplot=2
      if event.press eq 1 then begin
         b = drawbox(32,sx=event.x,sy=event.y)
         ;drawbox seems to screw up the coordinate structures...restoring
         !x=x1
         !y=y1
         coords =  Convert_Coord([b[0],b[2]], [b[1], b[3]], /Device, /To_Data)
         
         status.xrange=coords[0,*]
         status.yrange=coords[1,*]
         status.replot=1
         print,!d.window
      endif
      
         
      types = ['down','up','motion']

   end
   
   uvalue eq 'move':begin
      files = ['mangaHI-'+db[dbind].plateifu+'.csv',$
              'mangaHI-'+db[dbind].plateifu+'.fits']
  
       test = file_test(files)
       if total(test) lt n_elements(files) then begin
          warn = dialog_message(['Not yet. Some files are missing:',files[where(1-test)]],/center)
       endif else begin

          for f=0,n_elements(files)-1 do spawn,'mv '+files[f]+' '+finaldir

          listname = listname[where(listname ne db[dbind].plateifu)]
          widget_control, status.listwidget, set_value=listname
          newind = status.current_index
          widget_control,status.listwidget,set_list_select=newind
          goto,loadobj

       endelse
      

    end

   uvalue eq 'remove_finalized': begin
      print,'not working yet'
   end

   ;;    find all objects in the "final" directory
   ;;    finalized_files = file_search('./final/*par.sav')
   ;;    nfiles = n_elements(finalized_files)
   ;;    if nfiles gt 0 then begin
   ;;       need to extract manga ids
   ;;       for ii=0,nfiles-1 do begin
   ;;          sub = strsplit(finalized_files[ii],'_',/extract)
   ;;          sub = sub[0]
   ;;          sub = strsplit(sub,'/',/extract)
   ;;          sub = sub[n_elements(sub)-1]
   ;;          now removing
   ;;          print,'removing files for '+sub
   ;;          spawn,'rm -f '+sub+'.fits'
   ;;          spawn,'rm -f '+sub+'.index'
   ;;          spawn,'rm -f '+sub+'_par.sav'
   ;;          spawn,'rm -f mangaHI-'+sub+'.csv'
   ;;          spawn,'rm -f mangaHI-'+sub+'.fits'
   ;;          listname = listname[where(listname ne sub)]
   ;;       endfor
   ;;       widget_control, status.listwidget, set_value=listname
   ;;       newind = 0status.current_index
   ;;       status.current_index=0
   ;;       widget_control,status.listwidget,set_list_select=newind
   ;;       goto,loadobj
   ;;    endif else print,'nothing to clean out'
   ;; end

   uvalue eq 'marvin':begin
      spawn,'firefox -url https://sas.sdss.org/marvin2/galaxy/'+listname[status.current_index]+' &'
   end


   else: begin
      print,'dsds'
   end
         
endcase

if status.resetplot ne 0 then begin
   if 1-status.showbaseline then plotspec = spec.fhi else plotspec=spec.bhi
   if status.resetplot eq 1 then begin
      status.xrange = ncat.vopt + [-1500,1500]
      yspread = minmax(plotspec[where(spec.vhi ge status.xrange[0] and spec.vhi le status.xrange[1])])
      status.yrange = yspread + [-0.1,0.1]*(yspread[1]-yspread[0])
   endif
   
   if status.resetplot eq 2 then begin
      status.xrange = minmax(spec.vhi)
      yspread = minmax(plotspec[where(spec.vhi ge status.xrange[0] and spec.vhi le status.xrange[1])])
      status.yrange = yspread + [-0.1,0.1]*(yspread[1]-yspread[0])
   endif

   status.resetplot=0
   status.replot=1
endif

;plot
if status.replot then begin
   wset,32
   !p.multi=[0,1,1]
   if 1-status.showbaseline then plotspec = spec.fhi else plotspec=spec.bhi
;;    sel=where(par.blregions ne -1)
;;    indarr = [0]
;;    for ii=0,n_elements(sel)-1 do begin
;;       ind = par.blregions[ii] > 0
;;       ind = (ind - round(150/4)) > 0 ;this accounts for the fact that we trimmed hte outer 150 channels (before smoothing by 4). The region array doesn't account for this missing data, but the output spectra does not include it
;;       ind = ind < (n_elements(spec.vhi)-1)
;; ;      if status.showbaseline then oplot,[spec.vhi[ind] > 0,spec.vhi[ind]],[-100000,100000],color=cgcolor('green')
;;       indarr = [indarr,ind]
;;    endfor
;;    indarr=indarr[1:n_elements(indarr)-1]
   ;use indarr to define the minmax velocity range
   ;status.xrange = minmax(spec.vhi[indarr])
   ;yspread = minmax(plotspec[where(spec.vhi ge status.xrange[0] and spec.vhi lt status.xrange[1])])
   ;status.yrange = yspread + [-0.1,0.1]*(yspread[1]-yspread[0])

   plot,spec.vhi,plotspec,xtitle='velocity [km/s]',ytitle='flux density [Jy]',xrange=status.xrange,/xsty,yrange=status.yrange,/ysty,title=ncat.plateifu
  ;;  if status.showbaseline then begin
  ;;     oplot,spec.vhi,spec.bhi-spec.fhi,color=cgcolor('red'),thick=3
  ;;     for ii=0,n_elements(indarr)-1 do oplot,[spec.vhi[indarr[ii]] > 0,spec.vhi[indarr[ii]]],[-100000,100000],color=cgcolor('green')
  ;; endif

   device,decomposed=0
   loadct,13,/silent
   arrow,db[dbind].z*2.998e5,!y.crange[0],db[dbind].z*2.998e5,!y.crange[0] + 0.1*(!y.crange[1]-!y.crange[0]),color=100,/data
   if status.zline eq 1 then oplot,minmax(spec.vhi),[0,0],color=150
   loadct,0,/s
   status.replot=0
   x1=!x
   y1=!y
   ;indicate detection or nondetection
   det_label = 'None'
   if ncat.logmhi ne 0 and ncat.loghilim200kms eq 0 then det_label = 'detection'
   if ncat.logmhi eq 0 and ncat.loghilim200kms ne 0 then det_label = 'nondetection'
   xyouts,!x.window[0]+0.02,!y.window[1]-0.05,det_label,/norm,color=cgcolor('red'),charsize=2
;   xyouts,!x.window[1]-0.02,!y.window[1]-0.06,'fit order = '+strtrim(par.fit_order,2),/norm,color=cgcolor('turquoise'),alignment=1,charsize=2
;   if status.showbaseline eq 0 then bllabel = 'baselined' else bllabel = 'pre-baselined'
;   xyouts,!x.window[1]-0.02,!y.window[1]-0.12,bllabel,color=cgcolor('turquoise'),/norm,align=1,charsize=2

   ;show regions where we measured statistics
   dy = status.yrange[1]-status.yrange[0]
;   oplot,[par.statinfo.xmin,par.statinfo.xmin],dy*[-0.15,0.15],color=cgcolor('magenta'),thick=3
;   oplot,[par.statinfo.xmax,par.statinfo.xmax],dy*[-0.15,0.15],color=cgcolor('magenta'),thick=3
;   print,par.statinfo
;   print,status.showbaseline

   ;
   ;; if par.awvinfo.xmin ne 0 then begin
   ;;    awvinds = [par.awvinfo.xmin,par.awvinfo.xmax] - round(150/4)
   ;;    oplot,[spec.vhi[awvinds[0]],spec.vhi[awvinds[0]]],[-100,100],color=cgcolor('orange')
   ;;    oplot,[spec.vhi[awvinds[1]],spec.vhi[awvinds[1]]],[-100,100],color=cgcolor('orange')
   ;; endif

endif

if status.diagplot then begin
   wset,33
   !p.multi=[0,3,1]
   plot,ref.exp,ref.rms,psym=3,xtitle='t_int',ytitle='rms [mJy]',charsize=2,/ynozero
   loadct,13,/silent
   oplot,[ncat.exp],[ncat.rms],psym=4,color=255,thick=3
   loadct,0,/silent
   
   s=where(ref.logmhi gt 0)
   plot,ref[s].vhi,ref[s].logmhi,psym=3,xtitle='V_HI [km/s]',ytitle = 'log MHI',charsize=2,xrange=[0,max(ref.vopt)],/ynozero
   s=where(ref.LOGHILIM200KMS gt 0)
   plotsym,1,1
   oplot,ref[s].vopt,ref[s].LOGHILIM200KMS,psym=8
   
   loadct,13,/silent
   plotsym,1,1,thick=2   
   if ncat.logmhi gt 0 then oplot,[ncat.vhi],[ncat.logmhi],psym=4,color=255,thick=3 $
   else oplot,[ncat.vopt],[ncat.LOGHILIM200KMS],psym=8,color=255,symsize=2
   loadct,0,/silent
   
   s=where(ref.logmhi gt 0)
   plot,mstars[s],ref[s].logmhi-mstars[s],xtitle='log M_*',ytitle='log MHI/M_*',charsize=2,psym=3
   plotsym,1,1
   s=where(ref.LOGHILIM200KMS gt 0)
   oplot,mstars[s],ref[s].LOGHILIM200KMS-mstars[s],psym=8

   loadct,13,/silent
   plotsym,1,1,thick=2   
   if ncat.logmhi gt 0 then oplot,[alog10(db[dbind].nsa_elpetro_mass)],[ncat.logmhi - alog10(db[dbind].nsa_elpetro_mass)],psym=4,color=255,thick=3 $
   else oplot,[alog10(db[dbind].nsa_elpetro_mass)],[ncat.LOGHILIM200KMS-alog10(db[dbind].nsa_elpetro_mass)],psym=8,color=255,symsize=2
   loadct,0,/silent
   status.diagplot=0
   
endif


end
