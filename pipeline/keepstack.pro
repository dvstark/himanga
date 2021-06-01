PRO keepstack
    for i = 0,(!g.acount-1) do begin
	    freeze
            getrec,astack(i)
	    keep
	    unfreeze
    endfor
END
