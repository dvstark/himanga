;                                             wrapper script to run
;                                             find_hi_matches.pro --
;                                             designed to identify all
;                                             the possibly confused
;                                             objects in HI-MaNGA
;                                             observations

redshiftcat = '/users/dstark/17AGBT012/idl_routines/nsa_v0_1_2.fits'
redshiftcat = '/home/scratch/dstark/nsa_v1_0_1.fits.1'
mangahicat = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_113020.fits'

nsa = mrdfits(redshiftcat,1)
mangahi = mrdfits(mangahicat,1)

czname = nsa.iauname
czra = nsa.ra
czdec = nsa.dec
cz = nsa.z*2.998e5
czerr = 1e-9
czwidth = 200.

mangahi = mangahi[where(mangahi.logmhi gt 0)]
mangahi.mangaid = strtrim(mangahi.mangaid,2)
mangahi.session = strtrim(mangahi.session,2)


hiname = strtrim(mangahi.mangaid,2)
hira = mangahi.objra
hidec = mangahi.objdec
hicz = mangahi.vhi
hiw50 = mangahi.wf50*(mangahi.wf50 gt 0) + 200.*(mangahi.wf50 le 0)
;set minimum in case of bad measurement (this is now donw in find_hi_matches
;hiw50 = hiw50 > 40.

matchrad=9./2.*(mangahi.session ne 'ALFALFA') + 4./2.*(mangahi.session eq 'ALFALFA')
matchrad = matchrad*1.5

;this file used matchrad = 1.5*beam, no cz width, minimum linewidth of 40
;outfile = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_063020_nsamatch_1.5beam.fits'

;this file uses a czwidth of 200.
;outfile='/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_111720_nsamatch_1.5beam.fits'

;this file uses a czwidth of 200 and updated nsa catalog
outfile='/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_113020_nsamatch_1.5beam.fits'
stop
find_hi_matches,czname,czra,czdec,cz,czerr,czwidth,hiname,hira,hidec,hicz,hiw50,matchrad,outfile,dupfile=dupfile

end
