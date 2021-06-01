;+
; NAME:
;   struct_combine
;
; PURPOSE:
;   Combine 2 equal length arrays of structures into one array of structures,
;   with the UNION of the tags.  Values from the common tags will be from the
;   first structure.  
;
; CATEGORY:
;   IDL Structures
;
; CALLING SEQUENCE:
;   newst=struct_combine(struct_array1, struct_array2)
;
; INPUTS:
;   struct_array1, struct_array2: equal length arrays of structures.
;
; OUTPUTS:
;   new_struct: the output struct with the UNION of the tags.  Values from the
;             common tags will be from the first structure.
;
; PROCEDURE:
;   Get the union of the tags and tag descriptions.  The names are
;   concatenated and the duplicates removed.  The order of tags is preserved
;   except when common tags are found; then the order will be that of the 
;   second structure and the tag definition is also from the second.
;   COPY_STRUCT is used to copy, first from struct_array2 then from 
;   struct_array1.
;
; MODIFICATION HISTORY:
;   04-June-2004: created, E. Sheldon, UofChicago
;   2006-10-06: Now preserves name order.  Also, when structs have the 
;       exactly same tags, struct1 is returned. Renamed to struct_combine 
;       because it completely subsumes the functionality of that program.
;   2007-08-09: Renamed struct_combine and made a function. Erin Sheldon NYU
;-
;
;
;
;  Copyright (C) 2005  Erin Sheldon, NYU.  erin dot sheldon at gmail dot com
;
;    This program is free software; you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation; either version 2 of the License
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program; if not, write to the Free Software
;    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
;
;


function struct_combine, struct_array1, struct_array2, structype=structype

    if n_params() lt 2 then begin 
        print,'-Syntax: newst=struct_combine(struct1, struct2, structype=)'
        print
        print,'Values of common tags copy from 1 over 2'
        on_error, 2
        message,'Halting'
    endif 

    n1 = n_elements(struct_array1)
    n2 = n_elements(struct_array2)

    if (n1 NE n2) then begin 
        message,'Arrays of structures must be same length'
    endif 

    struct1 = struct_array1[0]
    struct2 = struct_array2[0]

    names1 = tag_names(struct1)
    names2 = tag_names(struct2)
    nt1 = n_elements(names1)
    nt2 = n_elements(names2)

    match, names1, names2, m1, m2

    if ( (m1[0] ne -1 and n_elements(m1) EQ nt1) $
        and (m2[0] ne -1 and n_elements(m2) EQ nt2) ) then begin 
        print,'Structures are the same. Setting new struct equal to struct1'
        newstruct = struct1
        return, newstruct
    endif 

    ;; Remove any duplicates from struct1
    tagind1 = lindgen(nt1)
    tagind2 = lindgen(nt2)
    if m1[0] ne -1 then begin 
        remove, m1, tagind1
        remove, m1, names1
        nt1 = n_elements(names1)
    endif 

    ;; Build up structure
    newstruct = create_struct(names1[0], struct_array1[0].(tagind1[0]))
    for i=1L,nt1-1 do begin 
        newstruct = $
            create_struct(newstruct, names1[i], struct_array1[0].(tagind1[i]))
    endfor 
    for i=0L,nt2-1 do begin 
        newstruct = $
            create_struct(newstruct, names2[i], struct_array2[0].(tagind2[i]))
    endfor 

    newstruct = replicate(newstruct, n1)

    copy_struct, struct_array2, newstruct
    copy_struct, struct_array1, newstruct

    return, newstruct
    
end
