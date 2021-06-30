#!/opt/local/bin/python
# -*- coding: utf-8 -*-                                   
'''quick script to add a confusion flag to the full mangahi database without eliminating any rows which don't have entries in the confusion table (topcat does not make this easy!)
'''

from astropy.io import fits
import numpy as np
import pdb 
import sys

def add_conflag(catfile,confile,outfile,addprob=False):

    #catfile = original catalog
    #confile = file containing confusion flag
    
    dbhdu = fits.open(catfile)
    chdu = fits.open(confile)

    #extract data tables
    db = dbhdu[1].data
    conf = chdu[1].data

    #add new column to db which will contain the confusion flag
    new_col = fits.ColDefs([fits.Column(name='conflag',format='I',array=np.zeros(len(db)))])
    newdbhdu = fits.BinTableHDU.from_columns(db.columns + new_col)
    db=newdbhdu.data


    if addprob==True:
        new_col = fits.ColDefs([fits.Column(name='conf_prob',format='F',array=np.zeros(len(db)))])
        newdbhdu = fits.BinTableHDU.from_columns(db.columns + new_col)
        db=newdbhdu.data    

    #add confusion flag to db. First isolate unique entries (duplicates will have the same confusion flag) and let's just separate out the ones with conflag==1 (we'll only match these to save time)
    
    uniq_ind = (np.unique(conf['hiname'], return_index=True))[1]
#    uniq_ind = uniques[1]
    conf = conf[uniq_ind]
    sel=conf['conflag']==1
    conf=conf[sel]

    for name in conf['hiname']:
        sel = (db['mangaid'] == name)
        db['conflag'][sel]=1
        
    if addprob==True:
        for name,cp in zip(conf['hiname'],conf['conf_prob']):
            sel = (db['mangaid'] == name)
            #print(np.sum(sel))
            db['conf_prob'][sel]=cp
        
    newdbhdu.writeto(outfile,overwrite=True)    
    
arguments = sys.argv
if len(arguments) < 3:
    print('error: please supply input hi-manga catalog and optical matches file')
    sys.exit()

catfile = arguments[1]
confile = arguments[2]
if len(arguments)>3:
    outfile = arguments[3]
else:
    outfile = arguments[1]
    
#catfile = 'mangahi_dr2_062321_gbtonly.fits'
#confile = 'mangahi_dr2_062321_gbtonly_nsamatch_1.5beam_withprob.fits'
#outfile = 'mangahi_dr2_062321_gbtonly_withconf.fits'

out=add_conflag(catfile,confile,outfile,addprob=True)
