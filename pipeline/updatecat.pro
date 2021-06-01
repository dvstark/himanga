pro updatecat,input,catalogfile
print,''
end


  


pro reset_vars,varlist=varlist,reset_format=reset_format

;; Simple program to reset all output variable names that are created
;; when reducing data. By resetting them at the beginning of each
;; reduction, we can easily automaticaly save the output without
;; worrying about incorrect values being carried over from an earlier
;; reduction

;; varlist = input list of variable names that need to be reset

;; reset_format = input list of formats for the variables being reset.
;; Currently just 's' for string and 'f' for float.  The format
;; determines the default value to which each variable is set (to do:
;; make this something the user can set)

  if 1-keyword_set(varlist) then begin
     varlist = ['name'$,
                ,'session'$
                ,'vopt'$
                ,'exp'$
                ,'rms'$
                ,'peak'$
                ,'hilim'$
                ,'logmhi'$
                ,'snr'$
                ,'fhi'$
                ,'vhi'$
                ,'ev'$
                ,'wm50'$
                ,'wp50'$
                ,'wp20'$
                ,'w2p50'$
                ,'wf50'$
                ,'pr'$
                ,'pl'$
                ,'ar'$
                ,'br'$
                ,'al'$
                ,'bl'$
               ]
     
     reset_format = ['s','s',strarr(n_elements(varlist)-2)+'f']
     
  endif
  
  for i=0,n_elements(varlist)-1 do begin

     if reset_format[i] eq 's' then reset_val = ' ' 
     if reset_format[i] eq 'f' then reset_val = -999

     (scope_varfetch(varlist[i],/enter,level=-1)) = reset_val
  
  endfor

  
end


pro undefine,var

  tempvar = size(temporary(var))

end



 
