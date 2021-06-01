;+
; NAME:
;   struct_addtags
;       
; PURPOSE:
;   Add new tags to the structure. 
;
; CALLING SEQUENCE:
;   There are two valid ways to call: one with a structure to add and
;   another with string arrays representing the names and types to add.
;
;       newstruct = struct_addtags(oldstruct, addstruct, structype=)
;           OR
;       newstruct = struct_addtags(oldstruct, tagnames, values, structype=)
;
; INPUTS: 
;   oldstruct: The original structure (or array of structures)
;
;   Calling sequence when a struct is sent:
;       newstruct: A new struct to add.  Can be the same lenght as the oldstruct
;           array, otherwise the first element is replicated.
;
;   Calling sequence when string arrays are sent:
;       tagnames: new tag name(s), can be an array
;       values: string containing values for tagnames. must be same size
;            array as tagnames. Same format as MRD_STRUCT.PRO
;
;
; KEYWORD PARAMETERS:
;   structyp: a string with the name of the new structure.
;     if already defined the program will crash.
;       
; OUTPUTS: 
;   newstruct: The structure with the new tags in it.
;
; OPTIONAL OUTPUTS:
;   NONE
;
; EXAMPLE: 
;   ; using a structure
;   newst = struct_addtags(oldstruct, {a:0, b:0d})
;
;   ; using tag names and types
;   tagnames=['ra', 'dec', 'image', 'name']
;   values  =['0d', '0d',  'intarr(1000, 1000)', "'NGC3035'"]
;   newst = struct_addtags(oldstruct, tagnames, values)
;
; CALLED ROUTINES:
;   MRD_STRUCT
;   STRUCT_COMBINE
; 
; PROCEDURE: 
;   Use mrd_struct to create a new structure.
;	
;
; REVISION HISTORY:
;   25-OCT-2000, Erin Scott Sheldon
;   2007-08-09, Converted from add_tags to function. Erin Sheldon, NYU
;   2010-07-29: Added option to send a structure to define the new tags.
;       this makes it compatible with the idlutils function which was
;       causing namespace collisions
;                                             
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


function struct_addtags, struct, tags_or_struct, values, structype=structype

    n_struct=n_elements(struct)
    n_tags_or_struct=n_elements(tags_or_struct)
    n_values=n_elements(values)
    n_tot=(n_struct gt 0) + (n_tags_or_struct gt 0) + (n_values gt 0)

    ; we are OK if struct is sent and tags_or_struct is a struct
    if n_tags(struct) ne 0 and n_tags(tags_or_struct) ne 0 then begin
        ok=1
    endif else if (n_tags(struct) ne 0) and (n_tot eq 3) and (n_tags_or_struct eq n_values) then begin
        ok=1
    endif else begin
        ok=0
    endelse

    if not ok then begin
        print,'Syntax - '
        print,'  newst=struct_addtags(struct, tagnames, values, structype=)'
        print,'    OR'
        print,'  newst=struct_addtags(struct, addstruct, structype=)'
        print,'Use doc_library,"struct_addtags"  for more help.'  
        on_error, 2
        message,'Halting'
    END


    if n_tags(tags_or_struct) ne 0 then begin
        ; tags_or_struct is really a struct
        if n_elements(tags_or_struct) eq n_struct then begin
            ; in this case, combine directly.  All values will line
            ; up
            newstr = struct_combine(struct, tags_or_struct, structype=structype)
        endif else begin
            ; in this case, replicate the first so it is the same length
            ; as the input struct and then combine. 
            tmpstr = replicate(tags_or_struct[0], n_struct)
            newstr = struct_combine(struct, tmpstr, structype=structype)
        endelse
    endif else begin
  
        if n_tags_or_struct ne n_values then begin 
            message,'Number of tags_or_struct not equal to number of tag values'
        endif 

        if size(tags_or_struct,/tname) ne 'STRING' then begin
            message,'tagnames must be a string array'
        endif 
        if size(values,/tname) ne 'STRING' then begin
            message,'values must be a string array'
        endif 
        tmpstr = mrd_struct(tags_or_struct, values, n_struct)

        if size(tmpstr,/tname) eq 'INT' then begin 
            message,'Error: MRD_STRUCT exited with error'
        endif 

        newstr = struct_combine(struct, tmpstr, structype=structype)
    endelse




    return, newstr
end
