pro find_optical_matches_himangacat,mangahicat,nsacat=nsacat,beam_mult=beam_mult,outfile=outfile

;                                             wrapper script to run
;                                             find_hi_matches.pro --
;                                             designed to identify all
;                                             the possibly confused
;                                             objects in HI-MaNGA
;                                             observations
;
;INPUT: 
;
;mangahicat - himanga catalog for which to search for optical
;             counterparts (created by manga_mangahi_catalog.pro
;
;nsacat - NSA catalog. Uses v1_0_1 unless another is specified.
;
;beam_mult - search radius around each galaxy in terms of the beam
;            FWHM of the radio telescope being used. Default is 1.5,
;            so we search for companions within 1.5 beams of the
;            target.
;
;            note: The matching in velocity space is coded into
;            find_hi_matches.pro. There are some things we could add
;            as inputs here.
;
;OUTPUT
;
;outfile - output file name. If not specified, the output file is
;          equal to mangahicat with the .fits removed, then
;          '_nsamatch_'+strtrim(string(beam_mult,format='(F4.1)'),2)+'beam.fits'
;          appended to the end. A file with the additional suffix
;          "_withprob" is created with contains the confusion
;          probability based on color.
;
;UPDATE HISTORY
;
;28 Jun 2021 -- (DVS) earlier wrapper code revised into this version
;               and documented. Added python routine to estimate
;               confusion probability from color/surface brightness


  if 1-keyword_set(nsacat) then nsacat = '/home/scratch/dstark/nsa_v1_0_1.fits.1'
  if 1-keyword_set(beam_mult) then beam_mult = 1.5

  ;read in catalogs
  nsa = mrdfits(nsacat,1)
  mangahi = mrdfits(mangahicat,1)

  ;run strtrim on a few key string parameters
  mangahi.mangaid = strtrim(mangahi.mangaid,2)
  mangahi.session = strtrim(mangahi.session,2)

  ;define properties of galaxies in optical catalog
  czname = nsa.iauname
  czra = nsa.ra
  czdec = nsa.dec
  cz = nsa.z*2.998e5
  czerr = 1e-9
  czwidth = 200. ;assumed HI linewidth

  ;just isolating detections here; extract their properties
  mangahi = mangahi[where(mangahi.logmhi gt 0)]
  hiname = strtrim(mangahi.mangaid,2)
  hira = mangahi.objra
  hidec = mangahi.objdec
  hicz = mangahi.vhi
  hiw50 = mangahi.wf50*(mangahi.wf50 gt 0) + 200.*(mangahi.wf50 le 0)
                                ;note: no need to set a minimum
                                ;linewidth in case of poor
                                ;measurement; this is done
                                ;in"find_hi_matches"


                                ;define search radius depending in
                                ;telescope (only considers GBT or
                                ;Arecibo) - beam_mult x beam HPBW
  matchrad=9./2.*(mangahi.session ne 'ALFALFA') + 4./2.*(mangahi.session eq 'ALFALFA')
  matchrad = matchrad*beam_mult

  if 1-keyword_set(outfile) then begin
     ;define output file based on input file name with an added suffix
     
     root = strsplit(mangahicat,'.fits',/extract,/regex)
     root = root[0]
     suffix = '_nsamatch_'+strtrim(string(beam_mult,format='(F4.1)'),2)+'beam.fits'
     outfile = root + suffix
  endif
  print,'Directing output to '+outfile


;  outfile='/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_062321_gbtonly_nsamatch_1.5beam.fits'
  find_hi_matches,czname,czra,czdec,cz,czerr,czwidth,hiname,hira,hidec,hicz,hiw50,matchrad,outfile,dupfile=dupfile

  ;now run confusion probability code
  print,'estimating confusion probabilities'
  spawn,'/opt/local/bin/python /users/dstark/17AGBT012/python_routines/confusion_with_color_cl.py '+outfile

  ;and run code that adds confusion flags to main catalog
  print,'adding confusion flags to main catalog'
  spawn,'/opt/local/bin/python /users/dstark/17AGBT012/python_routines/add_conflag_cl.py '+mangahicat+' '+outfile

end

mangahicat = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_062321_gbtonly.fits'
find_optical_matches_himangacat,mangahicat;,outfile='test.fits'

end
