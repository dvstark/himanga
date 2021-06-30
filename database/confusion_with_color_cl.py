#!/opt/local/bin/python
# -*- coding: utf-8 -*-
"""This program estimates the G/S probability distribution using color
and surface brightness. This is done for all known galaxies in a
telescope "beam" after which the confusion probability (likelihood
that <20% of total mesaured flux comes from galaxy other than primary
target) is estimated.

@author: david

"""


from hi_util.hi_util import *
import matplotlib.pyplot as plt
import numpy as np
from scipy.interpolate import interp1d
from astropy.table import Table
from astropy.io import fits
import sys

def refine_confusion(hi_id,opt_id,modcolor,mstars,beam_sep,beamsize,allowed_deltag=0.2,nsamples=1000):
    
    
    failures = 0
    failed = []
    probarr=np.zeros(len(hi_id))
    probs=[]
    
    #get beam sigma in arcsec
    beam_sigma = beamsize/2.355*60
    
    #get unique hi ids
    unique_hi_id = np.unique(hi_id)

    for u in unique_hi_id:
        
        print(u)

 #       while 1>0:
        try:
        
            sel = (hi_id == u)
            ids = opt_id[sel]
            seps = beam_sep[sel]
            cols = modcolor[sel]
            masses = mstars[sel]
            
            
            #identify primary target
            cent_ind = np.argmin(seps)
            comp_inds = np.arange(len(ids))
            comp_inds = np.delete(comp_inds,cent_ind)
            scale_factor = np.exp(-seps**2/2/beam_sigma**2)
            scale_factor[cent_ind]=1.
    
            pgfs = []
            mgs = []
            for c,m in zip(cols,masses):
                gs,pgf = gs_pgf(c)
                #interpolate to finer grid
                f=interp1d(gs,pgf)
                gs_fine = np.arange(gs[0],gs[-1],0.01)
                pgf_fine = f(gs_fine)
                pgfs.append(pgf_fine)
                mgs.append(gs_fine+m)
            
                fig,ax = plt.subplots()
                ax.plot(gs,pgf,marker='o')
                ax.plot(gs_fine,pgf_fine)
                plt.close()
    
            
            #draw random samples for primary
            sample_cent = np.random.choice(mgs[cent_ind],nsamples,p=pgfs[cent_ind]/np.sum(pgfs[cent_ind]))
            sample_comp = np.zeros_like(sample_cent)
            for c in comp_inds:
                sample_comp = sample_comp + 10**(np.random.choice(mgs[c],nsamples,p=pgfs[c]/np.sum(pgfs[c])))*scale_factor[c]
            sample_comp = np.log10(sample_comp)
    
            fig,ax = plt.subplots()
            ax.hist(sample_cent)
            ax.hist(sample_comp,alpha=0.5)
            plt.close()
    
            diff = sample_comp - np.log10(10**sample_cent + 10**sample_comp)
            fig,[ax1,ax2] = plt.subplots(ncols=2)
    
            ax1.hist(diff)
            n,bins,a = ax2.hist(diff,cumulative=True,density=True,bins=25)
            ax1.set_xlabel('log Mcompanions/Mprimary')        
            ax2.set_xlabel('log Mcompanions/Mprimary')
    
            ylims = ax1.get_ylim()
            ax1.plot(np.log10([allowed_deltag,allowed_deltag]),[ylims[0],ylims[1]])
            ylims = ax2.get_ylim()
            ax2.plot(np.log10([allowed_deltag,allowed_deltag]),[ylims[0],ylims[1]])
            plt.close()
    
            #interpolate to find prob. that Mcomp/Mprim > allowed_detag
            f = interp1d(bins[1:],n,fill_value='extrapolate')
            conf_prob = 1-f(np.log10(allowed_deltag))
            if conf_prob > 1:
                conf_prob = 1
            if conf_prob < 0:
                conf_prob = 0
            print('probability that companion is > 20% of total flux: ',conf_prob)      
            #plt.close()
            probarr[hi_id == u]=conf_prob
            probs.append(conf_prob)
            
        except:
             print('failure')
             failures = failures + 1
             failed.append(u)
    
    return failures,failed,probarr

arguments = sys.argv
if len(arguments) < 2:
    print('error: please supply input file name')
    sys.exit()
          
conf_file = arguments[1]

#process GBT confusion flags
print('processing GBT data')
#conf_file = '/home/david/manga/hi/mangahi_dr2_062321_gbtonly_nsamatch_1.5beam.fits'
#conf_file = '/users/dstark/17AGBT012/master/catalogs/mangahi_dr2_062321_gbtonly_nsamatch_1.5beam.fits'
if len(arguments) > 2:
    outfile = arguments[2]
else:
    outfile = conf_file #conf_file.split('.fits')[0]+'_withprob.fits'

conf_orig = Table.read(conf_file)
    
#select the confused cases
sel = conf_orig['CONFLAG']==1
conf = conf_orig[sel]
  
#read in nsa catalog so we can get modified colors
nsacat = '/home/scratch/dstark/nsa_v1_0_1.fits.1'
print('loading nsa catalog')
with fits.open(nsacat) as h:
    nsa = h[1].data

     
print('assigning modified colors to galaxies')
modcolor_conf=np.zeros(len(conf))
mstars = np.zeros(len(conf))

for i in range(len(conf)):
    sel=nsa['iauname']==conf['CZNAME'][i]
    if np.sum(sel)==0:
        pdb.set_trace()
    u_i = nsa['elpetro_absmag'][sel,2] - nsa['elpetro_absmag'][sel,5]
    mag = nsa['elpetro_absmag'][sel,4]+5*(np.log10(nsa['z'][sel]*2.998e5/70.*1e6)-1)
    lum = 10**(-mag/2.5)
    r50 = nsa['elpetro_th50_r'][sel]
    sb = lum/2./(np.pi*r50**2)
    logsb = -2.5*np.log10(sb)
    #modcolor_conf[i] = 4+1.14214135*u_i-0.14591545*logsb
    modcolor_conf[i] = 4+0.87846484*u_i-0.11607816*logsb #updated 01/06/21

    mstars[i] = np.log10(nsa['elpetro_mass'][sel])

failures,failed,probarr = refine_confusion(conf['HINAME'],conf['CZNAME'],modcolor_conf,mstars,conf['DIST']*180/np.pi*3600.,9,nsamples=10000)

#get unique entries
probs = []
unique_hi_id = np.unique(conf['HINAME'])
for u in unique_hi_id:
    sel=np.where(conf['HINAME']==u)[0]
    probs.append(probarr[sel[0]])

probs = np.array(probs)

print(np.sum(probs > 0.1)/len(probs))
fig,ax = plt.subplots()
ax.hist(probs,bins=20)
ax.set_xlabel('confusion probability')

conf_prob = np.zeros(len(conf_orig))
#append this table to the existing table
for n,p in zip(conf['HINAME'],probarr):
    sel=(conf_orig['HINAME']==n)
    if np.sum(sel) ==0:
        print('error, did not match properly back to parent catalog')
    conf_prob[sel] = p

try:
    conf_orig.add_column(conf_prob,name='CONF_PROB')
except:
    conf_orig.replace_column('CONF_PROB',conf_prob)
conf_orig.write(outfile,overwrite=True,format='fits')

