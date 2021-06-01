pro find_rfi,order,clip,window,badchans,dilate=dilate

;Description
;
;Routine to automatically find potential rfi.  Basic routine is:
;
;1) fits robust polynomial over a subrange of channels
;2) looks for strong outliers from polynomial fit
;3) proceeds to next range, then stop
;
;Input
;
;order - order of polynomial fit
;
;clip - multiple of rms noise to accept as not rfi
;
;window -- channel range to fit over
;
;badchans -- array to store bad channels in

if 1-keyword_set(dilate) then dilate=1

data=*!g.s[0].data_ptr
sz=n_elements(data)
chans=findgen(sz)

badch=[-1]

for i=window,sz-1,window do begin
   if i lt sz-1 then begin
      chansubset=chans[i-window:i]
      datasubset=data[i-window:i]
   endif else begin
      chansubset=chans[i-window:sz-1]
      datasubset=data[i-window:sz-1]
   endelse

   sel=where(finite(datasubset))
   chansubset = chansubset[sel]
   datasubset=datasubset[sel]

   out=robust_poly_fit(chansubset,datasubset,order,yfit)
   sm=datasubset-yfit
   rms=robust_sigma(sm)
;   if rms eq -1 then stop
   if rms ne -1 then begin
      bad=where(abs(sm) gt clip*rms)
      if bad[0] ne -1 then badch=[badch,(i-window)+bad] ;print,badch+(i-dch)
                                ;if badch[0] ne -1 then stop
   endif
   

endfor

print,'bad channels: ',badch

if n_elements(badch) gt 1 then begin
;do dilation
   d = indgen(2*dilate+1)-dilate
   for i=1,n_elements(badch) do badch = [badch,badch[i]+d]
   
   badch=badch[sort(badch)]
   badch=badch[uniq(badch)]
endif
   
badchans=badch
   
if n_elements(badchans) gt 1 then badchans=badchans[where(badchans ne -1)]

end
