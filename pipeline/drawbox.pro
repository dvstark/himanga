Function DrawBox, $
   wid,sx=sx,sy=sy, $         ; ID of window where box is drawn. (!D.Window by default.)
   Color=color, $ ; The color index of the box. (!D.N_Colors-1 by default.)
   Data=data, $   ; Box coordinates returned as DATA coordinates.
   Normal=normal  ; Box coordinates returned as NORMAL coordinates.

; This function draws a rubberband box in the window specified
; by the positional parameter (or the current graphics window, by
; default). The coordinates of the final box are returned by the
; function. Click in the graphics window and drag to draw the box.

   ; Catch possible errors here.

Catch, error
IF error NE 0 THEN BEGIN
   ok = Widget_Message(!Err_String)
   RETURN, [0,0,1,1]
ENDIF

   ; Check for parameters.

IF N_Params() EQ 0 THEN wid = !D.Window > 0
IF N_Elements(color) EQ 0 THEN color = (!D.N_Colors - 1) < 255

   ; Make current window active.

WSet, wid
xsize = !D.X_VSize
ysize = !D.Y_VSize

   ; Create a pixmap for erasing the box. Copy window
   ; contents into it.

Window, /Pixmap, /Free, XSize=xsize, YSize=ysize
pixID = !D.Window
Device, Copy=[0, 0, xsize, ysize, 0, 0, wid]

   ; Get the first location in the window. This is the
   ; static corner of the box.

WSet, wid
if not keyword_set(sx) or not keyword_set(sy) then Cursor, sx, sy, /Down, /Device

   ; Go into a loop.

REPEAT BEGIN

      ; Get the new cursor location (dynamic corner of box).

   Cursor, dx, dy, /Change, /Device

      ; Erase the old box.

   Device, Copy=[0, 0, xsize, ysize, 0, 0, pixID]

      ; Draw the new box.

   PlotS, [sx, sx, dx, dx, sx], [sy, dy, dy, sy, sy], $
      /Device, Color=color

ENDREP UNTIL !Mouse.Button EQ 0

   ; Erase the final box.

Device, Copy=[ 0, 0, xsize, ysize, 0, 0, pixID]

   ; Delete the pixmap.

WDelete, pixID

   ; Order the box coordinates and return.

sx = Min([sx,dx], Max=dx)
sy = Min([sy,dy], Max=dy)

   ; Need coordinates in another coordinate system?

IF Keyword_Set(data) THEN BEGIN
   coords =  Convert_Coord([sx, dx], [sy, dy], /Device, /To_Data)
   RETURN, [coords[0,0], coords[1,0], coords[0,1], coords[1,1]]
ENDIF

IF Keyword_Set(normal) THEN BEGIN
   coords =  Convert_Coord([sx, dx], [sy, dy], /Device, /To_Normal)
   RETURN, [coords[0,0], coords[1,0], coords[0,1], coords[1,1]]
ENDIF

   ; Return device coordinates, otherwise.

RETURN, [sx, sy, dx, dy]
END
