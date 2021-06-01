function lnlikelihood,y,yerr,yfit
  mu = yfit
  sigma=yerr
  
  lnprob = total(alog(1./sqrt(2*!pi*sigma^2))-(y-yfit)^2/2/sigma^2)
  return,lnprob
  
end


function autobaseline,x,y,rms,max_order=max_order,bic_cut=bic_cut,ploton=ploton,tsys=tsys

  ;automatically fits baseline to spectrum
  ;Mar 5, 2018 - updated to handle NaNs in data

  if n_params() eq 0 then begin

     setxunit,'km/s'
                                ;retrieve x, y, rms arrays from data container
     if 1-keyword_set(tsys) then tsys = !g.s[0].tsys
     dv = !g.s[0].frequency_resolution/!g.s[0].reference_frequency*2.998e5
     t_on = !g.s[0].exposure
     rms = 0.32*(2*t_on)^(-0.5)*(tsys/18.)/sqrt(dv)  
     x=velocity_axis(!g.s[0])/1000.
     y=*!g.s[0].data_ptr
     print,'rms from Tsys: ',rms
                                ;print,'rms, dv, t_on',rms,dv,t_on
     
                                ;isolate out regions selected for baseline
     regions = !g.regions
     sel=where(!g.regions[0,*] ne -1,count)
     if count gt 0 then begin
        regions = regions[*,sel]
        for i=0,count-1 do begin

           if i eq 0 then begin
              x_sub=x[regions[0,i]:regions[1,i]]
              y_sub=y[regions[0,i]:regions[1,i]]
           endif else begin
              x_sub=[x_sub,x[regions[0,i]:regions[1,i]]]
              y_sub=[y_sub,y[regions[0,i]:regions[1,i]]]
           endelse
        endfor
        x=x_sub
        y=y_sub
     endif
     
  endif
  
  if not keyword_set(bic_cut) then bic_cut = 2
  if not keyword_set(max_order) then max_order = 8
  
  lnmaxl = fltarr(max_order+1)
  npar = fltarr(max_order+1)

  ;ndata = n_elements(y)

  if keyword_set(ploton) then begin
     loadct,0,/silent
     !p.multi=[0,1,2]
     plot,x,y

     loadct,74,/silent
  endif
  
     
  
  for order=0,max_order do begin
     
     sel=where(finite(y),count)

     result = poly_fit(x[sel],y[sel],order,yfit=yfit,/double)
     if order eq 0 then yfit = fltarr(n_elements(x))+yfit
     ndata=count
     npar[order] = n_elements(result)

     dof = ndata - npar[order]
     lnmaxl[order] = lnlikelihood(y[sel],rms,yfit)

     if keyword_set(ploton) then oplot,x[sel],yfit,color=randomu(seed)*255
     
  endfor

  bic_arr = fltarr(max_order+1,max_order+1)
  for i=0,max_order-1 do begin
     for j=i+1,max_order do begin
        bic_arr[i,j] = 2*(lnmaxl[j]-lnmaxl[i]) - (npar[j]-npar[i])*alog(ndata)
     endfor
  endfor
  better_fit = bic_arr gt bic_cut

  sz=size(bic_arr,/dim)
  i = 0
  found_best = -1
  while found_best eq -1 do begin
     nobettermodel = total(better_fit[i,*] eq 1)
     if nobettermodel eq 0 then found_best = i else i=i+1
  endwhile
  
  print,'best fit order: ',found_best
  result = poly_fit(x,y,found_best,yfit=yfit,/double)
  if found_best eq 0 then yfit = x*0+yfit
  if keyword_set(ploton) then begin
     oplot,x,yfit,thick=3,color=cgcolor('red')

     loadct,0
     plot,x,y-yfit
     oplot,[min(x),max(x)],[0,0],thick=3,color=cgcolor('red')
  endif

  return,found_best
  
end

;testing
;print,autobaseline()

;step=.01
;min=-10
;max=10
;x=dindgen((max-min)/step+1)*step+min


;order = 4
;nparms = order+1
;parms = (randomu(seed,nparms)*5-2.5)/10 
;y=poly(x,parms)
;noise_scale = (max(y)-min(y))/50
;y = y+randomn(seed,n_elements(y))*noise_scale
;device,decomposed=0

;fit=autobaseline(x,y,noise_scale)


;end
