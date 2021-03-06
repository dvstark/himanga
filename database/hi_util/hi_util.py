# -*- coding: utf-8 -*-
"""
HI stacker. A set of routines to stack our HI data. Lots more stuff too.
"""

import os.path as path
from astropy.io import fits
import numpy as np
from scipy.io import readsav
import pdb
import matplotlib.pyplot as plt
from scipy import interpolate
import csv
import scipy.stats as stats
from scipy.special import erf


def find_files(names,telescope):
    
    alfalfa_path = '/home/david/manga/hi/alfalfa/SRCFILEs_all/'
    gbt_path = '/home/david/manga/hi/gbt/master/reduction_files/'
    
    specpath=''
    
    patharr = []
    existsarr = []
    
    for name,t in zip(names,telescope):
        
        
        if t == 'alfalfa':
            specpath = alfalfa_path + name+'.src'
        elif t == 'gbt':
            specpath = gbt_path + 'mangaHI-' + name + '.fits'
    
        patharr.append(specpath)
        existsarr.append(path.exists(specpath))
    
    return np.array(patharr),np.array(existsarr)
    
def stack(speclist,tel,v0,weight,scalefactor,savefig=None):
   
    #use scalefactor to convert to "gas fraction" units useful for when stacking galxaies of different masses and distance
    
    stack=[]
    weights=[]
    
    for s,t,v,w,sc in zip(speclist,tel,v0,weight,scalefactor):
        #load file
        if t=='alfalfa':
            #read this as an IDL save file
            src = readsav(s,python_dict=True)
            src=src['src']
            fluxa = src['specpol'][0]['yarra'][0]
            fluxb = src['specpol'][0]['yarrb'][0]
            weighta = src['weight'][0]['wspeca'][0]
            weightb = src['weight'][0]['wspecb'][0]
            flux = (fluxa*weighta + fluxb*weightb)/(weighta + weightb)/1000.          
            vel = src['velarr'][0]
        elif t=='gbt':
            #read fits file
            shdu = fits.open(s)
            vel = shdu[1].data['vhi'][0]
            flux = shdu[1].data['fhi'][0] #now mJy

        flux = flux*sc #multiply by scalefactor
        
        #subtract off central velocity        
        vel=vel-v
        if 'vref' not in locals():
            vref = vel[(vel > -1000) & (vel < 1000)]    
        
        #shift spectrum
        f = interpolate.interp1d(vel, flux,fill_value='extrapolate',bounds_error=False,kind='nearest')
        f_int = f(vref)

        #add to stack
        stack.append(f_int)       
        weights.append(1)#1./np.nanstd(f_int)**2)

    #now sum all channels
    sh=(np.shape(stack))
    print('stacking '+str(sh[0])+' galaxies')
    
    masked_stack = np.ma.masked_array(stack, np.isnan(stack))
    spec = np.ma.average(masked_stack, axis=0, weights=weight)
    
    return vref,spec
        
def jackknife(speclist): 
    
    print('test')


def parse_zooniverse_flags(class_file):
#(subject_file, class_file):
 
    class_hdu = fits.open(class_file)
    classes = class_hdu[1].data
    flags = {} #create empty dictionary to hold flags
    flag_keys = ['data.negative-detection-within-1000-km-s',
                 'data.baseline-not-fully-fit-within-1000-km-s',
                 'data.off-center-detection-within-1000-km-s',
                 'data.poor-baseline-fit',
                 'data.strong-baseline-wobble']
    new_keys = ['negative_detection',
                'incomplete_baseline',
                'offcenter_detection',
                'poor_baseline',
                'baseline_wobble',
                ]

    #get file name from input spectrum path
    
    for c in classes:
        file_info = c['metadata']
        spl = file_info.split(':')[-1]
        object_name = (spl.split('_')[0][1:])
        
        #create a new dictionary of flags
        subflags = {}
        for f_old,f_new in zip(flag_keys,new_keys):
            subflags[f_new] = c[f_old]
            if np.isnan(subflags[f_new]) == True:
                subflags[f_new]=0.
        
        flags[object_name] = subflags

    return flags            
        
    
    
'''    
I could never get the following two tables to match on subject id.
I therefore did the matching in topcat and am loading that in instead
    #load the subject csv file
    with open(subject_file,'rt')as f:
        
        subject_id = []
        target_name = []
        
        data = csv.reader(f)
        #skip header
        next(data)
        for row in data:
            
            subject_id.append(row[0])
            
            #process filename string to get target id
            file_string = row[4]
            sub = file_string.split(':')[1]
            sub2 = sub.split('_')[0]
            target_name.append(sub2[1:])

    #now open the classifications file
    classes = []
    with open(class_file, mode='r') as csv_file:
        csv_reader = csv.DictReader(csv_file)
        line_count = 0
        for row in csv_reader:
            print(row)
            if line_count == 0:
                print(f'Column names are {", ".join(row)}')
                line_count += 1
            print('read data row')
            classes.append(row)    
    pdb.set_trace()
'''

def automeasure(spec,vel,flag=''):
    
    
    #find center
    i0 = np.argmin(abs(vel))
    
    #starting at center, move outwards to find where flux falls below zero
    stop_condition=False
    i = i0
    count = 0
    while stop_condition is False:
        f = spec[i]
        if f < 0:
            count = count+1
        else:
            count = 0
        i=i+1
        if count > 2:
            stop_condition=True
        if i > (len(vel)-1):
            stop_condition=True
            flag = 'Edge Failure'
        
    bounds = [vel[i-1]]
    stop_condition=False
    i = i0
    count = 0
    while stop_condition is False:
        f = spec[i]
        if f < 0:
            count = count+1
        else:
            count = 0
        i=i-1
        if count > 2:
            stop_condition=True
        if i < 0:
            stop_condition=True 
            flag = 'Edge Failure'
    
    bounds.append(vel[i])
    #calculate flux within bounds
    dv = abs(np.median(vel[1:-1] - vel[0:-2])) #channel size
    sel=np.where((vel >= min(bounds)) & (vel <= max(bounds)))
    nchan=len(sel)
    flux = np.sum(spec[sel])*dv
    peakflux = np.max(spec[sel])
    limit=False
    
    #calculate rms outside of bounds
    sel=np.where((vel <= min(bounds)) | (vel >= max(bounds)))
    rms = stats.median_absolute_deviation(spec[sel])#np.nanstd(spec[sel])    
    
    #assess snr
    int_snr = flux/(rms*np.sqrt(nchan)*dv)
    peak_snr = peakflux/rms
    print(flux,peakflux,rms,int_snr,peak_snr)
    if (int_snr < 3) or (peak_snr < 3):
        flux = 3*rms*dv*np.sqrt(200/dv)
        limit = True
        print('limit: ',3*rms*dv*np.sqrt(200/dv))
    
    out={'flux':flux, 'limit':limit, 'bounds':bounds, 'rms':rms, 'eflux':rms*np.sqrt(nchan)*dv}
    return out

def process_duplicates(name,snr,rms,beam,confused):
    #create array of indices
    indices = np.arange(len(name))
    processed = np.array([False]*len(name))
    
    good_ind = []
    for i in range(len(name)):
        if processed[i]==False:
            #find all instances of this galaxy
            sel=np.where(name==name[i])[0]
            if len(sel)==1:
                good_ind.append(sel[0])
            elif len(sel)==2:
                #easiest to define two variables here
                snr1=snr[sel[0]]
                snr2=snr[sel[1]]
                rms1=rms[sel[0]]
                rms2=rms[sel[1]]
                beam1=beam[sel[0]]
                beam2=beam[sel[1]]
                conf1=confused[sel[0]]
                conf2=confused[sel[1]]
                sel_small_beam = np.argmin(beam[sel])
                sel_high_snr = np.argmax(snr[sel])
                sel_low_rms = np.argmin(rms[sel])
                
                if (snr1 > 0) & (snr2 > 0):
                    if (conf1==True) & (conf2==True):
                        #pick the smaller beam
                        pick = sel_small_beam
                    elif (conf1==True) & (conf2==False):
                        pick=1
                    elif (conf1==False) & (conf2==True):
                        pick=0
                    elif (conf1==False) & (conf2 == False):
                        pick = sel_high_snr
                elif (snr1==0) & (snr2==0):
                    pick=sel_low_rms
                elif (snr1>0) & (snr2==0):
                    if (conf1==False):
                        pick=0
                    elif (conf1==True):
                        pick=1
                elif (snr1==0) & (snr2 > 0):
                    if (conf2==False):
                        pick=1
                    elif (conf2==True):
                        pick=0
                else:
                    pdb.set_trace()

                good_ind.append(sel[pick])
                processed[sel]=True

    return good_ind
                    #this shouldn't happen
# zooniverse_path = '/home/david/manga/hi/gbt/master/catalogs/'
# subject_file = zooniverse_path + 'manga-hi-visual-flagging-subjects.csv'

# #subject_file = zooniverse_path + 'manga-hi-visual-flagging-subjects.csv'
# class_file = zooniverse_path + 'manga-hi-visual-flagging_reduction_subject_join.fits'
# flags = parse_zooniverse_flags(class_file)

#datafile = '/home/david/manga/fits/drpall_dapall_spx_mangahi_2_5_3.fits'
#hdu = fits.open(datafile)
#db = hdu[1].data
#beam=np.zeros(len(db))
#beam[:]=9.
#beam[db['session']=='ALFALFA']=3.5

#snr=db['fhi']/db['efhi']#
#snr[db['fhi']< 0]=0
#confused=db['conflag']==1

#good_ind=process_duplicates(db['plateifu_1'],snr,db['rms'],beam,confused) 
 
 

# sel=(db['logmhi'] < 0) & (db.nsa_elpetro_mass > 1e8) & (db.nsa_elpetro_mass > 1e11) #& (db.nsa_elpetro_mass < 1e9)#(tel == 'gbt')

# name = db['plateifu_1'][sel]
# tel = tel[sel]
# v0 = db['z_1']*2.998e5
# v0=v0[sel]
# weight = weight[sel]
# scalefactor = scalefactor[sel]

# #remove any with flags
# removal_flags = ['baseline_wobble','poor_baseline','incomplete_baseline','negative_detection','offcenter_detection']
# remove = np.array([False]*len(name))
# for n in name:
#     if n in flags:
#         for r in removal_flags:
#             if (flags[n][r]) > 0:
#                 remove[np.where(name == n)] = True                

# paths,exists=find_files(name,tel)
# paths = paths[(exists == True)  & (remove == False)]
# tel=tel[(exists == True) & (remove == False)]
# v0=v0[(exists == True) & (remove == False)]
# weight = weight[(exists == True) & (remove == False)]
# scalefactor = scalefactor[(exists == True) & (remove == False)]

# # paths = paths[0:100]
# # tel = tel[0:100]
# # v0 = v0[0:100]

# vref,spec=stack(paths,tel,v0,weight,scalefactor)

# plt.plot(vref,spec/1e-3)
# plt.xlabel('velocity [km/s]')
# plt.ylabel('flux density [mJy]')
# plt.savefig('mangahi_stack_gbt.png')
# plt.plot([-1000,1000],[0,0],'--',color='red')

# flag=''
# out = automeasure(spec,vref,flag=flag)
# print(flag)
#plt.plot([out[0],out[0]],[-1,1])
#plt.plot([out[1],out[1]],[-1,1])
# dv = abs(np.median(vref[1:-1] - vref[0:-2]))
# sel=np.where((vref >= min(out)) & (vref <= max(out)))
# flux = np.sum(spec[sel])*dv
# print(flux)

def pgf(X,a0,a1,a2,a3,a4,a5,a6,a7,a8):
   
    '''provides the G/S probability distribution given a modified color. 
    Need at least gs value at -1.3 in order to properly account for upper limit population'''
    
    mc,gs = X
    
    rho0 = a0/(mc*a2*np.sqrt(2*np.pi))*np.exp(-(np.log(mc)-a1)**2/2/a2**2)
    
    D1 = rho0*np.exp(-(gs - (a3*mc+a4))**2/(2*(a5*mc)**2))
    
    D2 = rho0*0.5*a5*mc*np.sqrt(2*np.pi)* (1-erf(np.abs(-1.3-(a3*mc+a4))/np.sqrt(2*(a5*mc)**2))) 
    
    D=np.zeros_like(gs)
    D[gs > -1.3]=D1[gs > -1.3]
    D[gs <= -1.3]=D2#[gs <= -1.3]
    
    L=np.zeros_like(gs)
    L[:] = a6*np.exp(-(mc-a7)**2/2/a8/a8)
    L[gs < -1.35]=0
    L[gs > -1.25]=0
    return D+L

def gs_pgf(modcolor,lim=None):
    
    '''returns the G/S probability distribution given a modified color (in this case 4+A*(u-i)+B*mu_r).
Note that this assumes h=1. '''

    gsarr = np.arange(-1.5,2,0.1)
    
    #pgf_par = [26.95701605,  0.47366476,  0.21887664, -1.15063809,  1.77660812,  0.20676654,
# 49.1606395,   2.68920161,  0.20577336] #use sb defined as abs mags/kpc instead of arcsec
    
    #modcolor = u-i + sb (abs mag/arcsec2)
    pgf_par = [27.3222102 ,  0.92820806 , 0.1427902  ,-1.14852537 , 2.82620221 , 0.13086835,
 51.52082796 , 3.58370553 , 0.18941135]
    
   #---best>
    pgf_par = [26.38126425,   0.92661594,   0.15364066,  -1.09953214,
         2.6941393 ,   0.12613072,  46.51728971,   3.7796027 ,   0.36754175] #this is the same as above but weighting the fit by 1/N
    
  #  pgf_par = [26.13578895,  0.41313352,  0.23390098, -1.11094243,  1.60332799,  0.22781835,
# 45.66977597,  2.59295923,  0.23341349] #thses use nsa stellar masses and colors, but resolve hi.from resolve_color_gs.py in reoslve directory
    
    #pgf_par = [28.54864802,  0.76878152,  0.20849511, -1.00951728,  2.37850459,
      #  0.14384875, 38.55588149,  3.58782079,  0.26711099] #these use resolve mstars. these coefficients from resolve_color_gs.py in reoslve directory

    mc = np.zeros_like(gsarr)
    mc[:]=modcolor
    pdf = pgf((modcolor,gsarr),*pgf_par)
    
    if lim != None:
        sel=gsarr >= lim
        pdf[sel]=0
    
    return gsarr,pdf

#test
# gsarr,pdf=gs_pgf(1.3)
# fig,ax = plt.subplots()
# ax.plot(gsarr,pdf)

