#!/opt/local/bin/python
'''merges two hi-manga tables together. Primary application is to
merge the GBT and ALFALFA catalogs

Run from command line with:

    /opt/local/bin/python merge_himanga_catalogs.py [catalog 1] [catalog 2] [merged_catalog]

where [catalog 1] and [catalog 2] are the input catalogs to be merged,
and [merged_catalog] is the final combined catalog (all of these are
file paths).

'''

from astropy.io import fits
import sys

#make sure there are 3 command line arguments

arguments = sys.argv
if len(arguments) < 4:
    print('Check syntax')
    print('usage:  merge_himanga_catalogs.py [catalog 1] [catalog 2] [merged_catalog]')
    sys.exit()

catalog_1 = arguments[1]
catalog_2 = arguments[2]
outfile = arguments[3]

#catalog_1 = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_062321_gbtonly.fits'
#catalog_2 = '/users/dstark/17AGBT012/master/catalogs/manga_mpl11_alfalfa_wconf_062921_gbtformat.fits'
#outfile = 'merged.fits'

#the code below to merge the tables is taken from
#https://docs.astropy.org/en/stable/io/fits/usage/table.html

with fits.open(catalog_1) as hdul1:
    with fits.open(catalog_2) as hdul2:
        nrows1 = hdul1[1].data.shape[0]
        nrows2 = hdul2[1].data.shape[0]
        nrows = nrows1 + nrows2
        hdu = fits.BinTableHDU.from_columns(hdul1[1].columns, nrows=nrows)
        for colname in hdul1[1].columns.names:
            hdu.data[colname][nrows1:] = hdul2[1].data[colname]

#write out new table
hdu.writeto(outfile,overwrite=True)
