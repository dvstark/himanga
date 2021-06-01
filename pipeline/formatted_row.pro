pro formatted_row,limit=limit

name = scope_varfetch('name',level=-1,/enter)
vopt = !g.s[0].source_velocity/1000.
session = scope_varfetch('session',level=-1,/enter)
exp = !g.s[0].exposure
stats = scope_varfetch('statinfo',level=-1,/enter)
rms = stats.rms*1000.

if not keyword_set(limit) then begin

peak = scope_varfetch('peak',level=-1,/enter)*1000
logmhi = scope_varfetch('mhi',level=-1,/enter)
w = scope_varfetch('widthinfo',level=-1,/enter)

   snr=w.snr
   fhi=w.fhi
   vhi=w.vhi
   ev=w.ev
   wm50=w.wm50
   wp50=w.wp50
   wp20 =w.wp20
   w2p50=w.w2p50
   wf50=w.wf50
   pr=w.pr
   pl=w.pl
   ar=w.ar
   br=w.br
   al=w.al
   bl=w.bl

   sep = '  '
   format = '(A,A,I5,A,A,A,I4,A,F4.2,A,F5.2,A,F4.1,A,F5.2,A,F5.2,A,I5,A,F6.2,A,I3,A,I3,A,I3,A,I3,A,I3,A,F4.1,A,F4.1,A,F6.2,A,F5.2,A,F6.2,A,F5.2)'
   print,name,sep,vopt,sep,session,sep,exp,sep,rms,sep,peak,sep,snr,sep,fhi,sep,logmhi,sep,vhi,sep,ev,sep,wm50,sep,wp50,sep,wp20,sep,w2p50,sep,wf50,sep,pr,sep,pl,sep,ar,sep,br,sep,al,sep,bl,sep,format=format
   save,name,vopt,session,exp,rms,peak,snr,fhi,logmhi,vhi,ev,wm50,wp50,wp20,w2p50,wf50,pr,pl,ar,br,al,bl,filename=name+'_prop.sav'

endif

if keyword_set(limit) then begin
   hilim = scope_varfetch('hilim',level=-1,/enter)
   format = '(A,A,F7.1,A,I3,A,F6.1,A,F4.2,A,F5.2)'
   print,name,'   ',vopt,' ',session,'     ',exp,' ',rms,'  ',hilim[1],format=format
   save,name,vopt,session,exp,rms,hilim,filename=name+'_prop.sav'
endif

end
