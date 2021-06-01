pro session_summary,makeplots=makeplots,gpsflag=gpsflag,gps_thresh=gps_thresh
  
;routine to print out a summary of the session which gets put into the
;wiki. Must load data set with "online", "offline", or "filein" first.

;Update History
;2018-09-10: D. Stark, created
;2019-01-15: D. Stark, added makeplots and gpsflag keywords


if keyword_set(makeplots) and 1-file_test('./tmp/',/directory) $
then spawn,'mkdir tmp'
if keyword_set(makeplots) then spawn,'rm ./tmp/*'
if 1-keyword_set(gps_thresh) then gps_thresh=0.5

astrid_log_path = '/users/dstark/17AGBT012/astrid_logs/'

;get this input file name and extract session
path = !g.line_filein_name
s = strsplit(path,'/',/extract)
file = s[n_elements(s)-1]
s = strsplit(file,'.',/extract)
session = s[0]

summary,'temp_summary.txt'

;read in summary info (to do: is there a cleaner way to get summary info?)
readcol,'temp_summary.txt',F='I,A,F,A,I,F,I,I,I,F,F',scan,source,vel,proc,seq,restf,nif,nint,nfd,az,el,/silent

pair_warning = 'INCOMPLETE ON/OFF PAIR'

target_list = ['']



newtarget=1
for i=0,n_elements(scan)-1 do begin

   warning = ''

   if newtarget then begin
      target = source[i]
      start=scan[i]
      nscans=0
      newtarget=0
   endif

   nscans=nscans+1*(proc[i] eq 'OnOff' and seq[i] eq 2)

   if i lt n_elements(scan)-1 then begin

      newtarget = source[i+1] ne source[i]
      
      if (seq[i] eq 1 and seq[i+1] ne 2) $
         or (seq[i] eq 1 and seq[i+1] eq 2 and abs(nint[i] - nint[i+1]) gt 1) $
      then warning = pair_warning

   endif

   if i eq n_elements(scan)-1 and seq[i] ne 2 then warning = pair_warning

   ;gps flagging
   if proc[i] eq 'OnOff' and seq[i] eq 1 and keyword_set(gpsflag) then $
      autoflag,scan[i],nint[i]-1,gps_thresh

   if newtarget or i eq n_elements(scan)-1 then begin
      ;print,target+','+strtrim(string(start),2)+','+strtrim(string(nscans),2)+' '+warning
      target_list = [target_list,target+','+strtrim(string(start),2)+','+strtrim(string(nscans),2)+' '+warning]
      if keyword_set(makeplots) then begin
         quicklookps,start,nscans
         setxunit,'km/s'
         ;trim edges to make plot range better
         nchan=n_elements(get_chans(!g.s[0]))
         replace,0,150,/blank
         replace,nchan-1-150,nchan-1,/blank

         annotate,0.15,0.15,'T(On+Off) = '+strtrim(string(!g.s[0].exposure*2/60.),2)+' min',/normal,color=0

         write_ps,'./tmp/'+strtrim(string(start,f='(I03)'),2)+'-'+strtrim(string(nscans),2)+'.ps',/portrait
      endif
   endif

   clearmarks

endfor

if keyword_set(makeplots) then begin
   spawn,'gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER -sOutputFile='+session+'.pdf '+strjoin(file_search('./tmp/*.ps')+' ')
   print,'plots available in '+session+'.pdf'
   spawn,'evince '+session+'.pdf &'
endif


print,''
print,''
spawn,'getastridlog '+session
spawn,'mv '+session+'_log.txt '+astrid_log_path

print,''
print,'Targets:'
print,''
for i=0,n_elements(target_list)-1 do print,target_list[i]

print,''
print,'Scan List:'
print,''
summary

end
