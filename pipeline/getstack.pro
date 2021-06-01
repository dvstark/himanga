
;+
; Get the records listed in the stack and save into output file.
;
;
; @examples
;    add index number 25, 30 through 39, and the odd indexes from 41
;    through 51 to the stack, and average them.
; <pre>
;    addstack, 25
;    addstack, 30, 39
;    addstack, 41, 51, 2
;    keepstack
; </pre>
;
;-
pro keepstack

    if not !g.line then begin
        message,'accum only works on spectral line data, can not avgstack continuum data, sorry',/info
	return
    for i = 0,(!g.acount-1) do begin
            getrec,astack(i)
	    keep
         endfor
 endif

end
