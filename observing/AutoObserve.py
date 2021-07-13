'''
##########################################
## BEFORE EDITING THIS SCRIPT, COPY ALL CATALOGS FROM
##        /users/dstark/17AGBT012/catalogs/obscat/    
## TO
##        /users/dstark/17AGBT012/catalogs/save/      
##########################################

Automatic Observing script for program 17A-012/19A-127/20B-033/21B-130

Operator instructions can be found in:
/users/dstark/17AGBT012/scripts/17A-012_AutoObserve.readme

Questions can be directed to: 

David Stark
email:dstark@haverford.edu
phone +1-484-695-0716

Summary of routines:

ang_sep -- calculates angular separation between two sets of J2000
coordinates

choose_plate -- chooses which MaNGA plate (i.e., a subregion) the
program will observe, based on current telscope position as well as
other pre-defined priorities

set_target_priority -- determines the order in which galaxies on a
given plate are observed, based on predefined priorities

observe_plate -- executes the observations of galaxies on a given
plate

observe_cal -- execultes the observation of a calibrator

update_plate_cat -- script that updates our catalogs to say which
targets have been observed

check_cal_status -- checks the last time a calibrator was observed

'''

import numpy as np
import math as m
from gbt.turtle.user import locationToJ2000
from gbt.turtle.ygor import SolarSystem
from operator import itemgetter
import os
from mx import DateTime

#defining a few variables
slew_rate=[35.2, 17.6] #GBT slew rates in deg per min (az, el) (check these!)
min_el =8 #when telescope elevation goes below this, we move on
min_starting_el = 15 #minimum elevation to start observing a plate
max_el = 85 #avoid plates higher than this to help avoid long slew times
min_sun_dist = 40 #minimum desired distance from sun (check this!)
catdir = '/users/dstark/17AGBT012/catalogs/obscat/'
badcals = ['W3OH'] #insert any calibrator sources we should avoid

def ang_sep(ra1,ra2,dec1,dec2):
    """
    Calculates angular separation in degrees between two objects. 
    ra1, dec1, ra2, dec2 are the coordinates of the two targets in decimal 
    degrees. Note: equation being used not great for very small separations, 
    but should be fine for our purposes.
    """

    #print('target_coords: ',ra1,dec1,ra2,dec2)

    dra = abs(ra1-ra2)
    if dra > 180:
        dra  = 360 - dra
    
    #convert relevant angles to radians
    dec1_rad = np.radians(dec1)
    dec2_rad = np.radians(dec2)
    ra1_rad = np.radians(ra1)
    ra2_rad = np.radians(ra2)
    dra_rad = np.radians(dra)

    deldec2 = (dec2_rad - dec1_rad)/2.
    delra2 = (ra2_rad - ra1_rad)/2.
    sindis = np.sqrt(np.sin(deldec2)*np.sin(deldec2) + np.cos(dec1_rad)*np.cos(dec2_rad)*np.sin(delra2)*np.sin(delra2))
    sep = 2*np.arcsin(sindis)

    #calculate separation
    #sep = np.arccos(np.sin(dec1_rad)*np.sin(dec2_rad) + 
      #    np.cos(dec1_rad)*np.cos(dec2_rad)*np.cos(ra1_rad-ra2_rad))

    #convert separation back to degrees
    sep_deg = np.degrees(sep)

    return sep_deg


def choose_plate(docal=0,quiet=0):
    '''
    This code chooses the best plate to observe at the given time, based on: 
    1) slew time (including to calibrator)
    2) proximity to sun
    3) proximity to horizon
    4) number of requested objects in subcatalog
    5) number of started targets in subcatalog

    If cal = 1, then code looks for the best calibator + plate
    combination. Otherwise, it just looks for the best plate
    '''
    if not quiet:
        if docal == 1:
            print 'Determining best calibrator/plate combination to observe'
        else:
            print 'Determining best plate to observe'
    
    #get current location in RA/DEC and AZ/EL
    cl_j2000 = GetCurrentLocation("J2000")
    cl = GetCurrentLocation("AzEl")
    
    #get position of sun
    sun= SolarSystem("Sun")
    sun_ra = sun.GetH() #sun RA
    sun_dec = sun.GetV() #sun DEC
    print('sun position: ',sun_ra,sun_dec)

    #read in calibrator catalog
    cal=Catalog("fluxcal")
    #filter out any bad calibrators
    src=[x for x in cal.keys() if x not in badcals]


    #read in plate catalog (decided to use numpy because its easier to work with, 
    #but it means I'm processing the flux calibrator and plate catalogs different
    #ways which is somewhat unsatisfying...maybe fix this later
    plate_cat_path = catdir+'platelist_uptodate.txt'
    plate_cat = np.genfromtxt(plate_cat_path,dtype=[('plate','S10'), ('ra','f'),
              ('dec','f'),('ngal','i'),('nrequest','i'),('nstarted','i')], skip_header=1) 

    #go through the calibration sources, select those above the
    # horizon, far from sun, and then calculate slew time
    cal_list = [] #list of final useable calibrators
    cal_az = [] #azimuths of final usable calibrators
    cal_el = [] # elevations of final usable calibrators
    cal_slew = [] #slew times of final useable calibrators

    for c in src:
        radec=cal[c]['location'] #calibrator position (J2000)
        azel=locationToJ2000.ConvertJ2000toMode(radec,newmode='AzEl') #calibrator position (AZ//EL)
        
        #get distance of calibrator to sun 
        sun_dist = ang_sep(radec.h,sun_ra,radec.v,sun_dec)

        #ignore calibrator if close to the sun or below the horizon
        if (azel.v > min_el) and (sun_dist > min_sun_dist): 
            cal_list = cal_list + [c] #store name of calibrator
            cal_az = cal_az + [azel.h] #store azimuth of calibrator
            cal_el = cal_el + [azel.v] #store position of calibrator

            #calculate slew time from current position to calibrator
            delta = np.array([abs(azel.h-cl.h), abs(azel.v - cl.v)]) #angular separation
            if delta[0] > 180:
                delta[0] = 360-delta[0]
            slew_time = max(delta/slew_rate)
            cal_slew = cal_slew + [slew_time] #store in list of slew times

    #Now cycle through plates, determine slew time w/ or w/o
    #calibrator, determine best one to observe

    plate_cal = np.zeros_like(plate_cat['plate']) #stores best calibrator for each plate (shortest total slew time to cal then to plate)
    plate_slewtime = np.zeros_like(plate_cat['ra']) #stores overall slew time
    plate_el = np.zeros_like(plate_cat['ra']) #store plate elevation
    plate_sun_dist = np.zeros_like(plate_cat['ra']) #stores plate-to-sun distance
    plate_ntargs = np.zeros_like(plate_cat['ra']) #number of observable targets per plate (takes into account ones we've already observed this run)

    for i in range(len(plate_cat)):
        
        #piggybacking on set_target_priority code to determine total
        #number of observable targets
        plate_ntargs[i]=len(set_target_priority(plate_cat[i]['plate']))
        
        #create position instance for plate
        plate_pos = Location('J2000',float(plate_cat[i]['ra']),float(plate_cat[i]['dec']))
        azel=locationToJ2000.ConvertJ2000toMode(plate_pos,newmode='AzEl')
        plate_el[i]=azel.v #plate elevation
        plate_sun_dist[i] = ang_sep(plate_pos.h,sun_ra,plate_pos.v,sun_dec) #distance from sun
        #print(plate_cat[i]['plate'],plate_sun_dist[i],plate_cat[i]['ra'],plate_cat[i]['dec'])
        #calculate slew time either from each calibrator or from current position
        if docal == 1:
            delta = np.array([abs(azel.h-np.array(cal_az)),abs(azel.v-np.array(cal_el))])     
        else:
            delta = np.array([abs(azel.h-cl.h), abs(azel.v - cl.v)])

        sel=np.where(delta > 180) 
        delta[sel] = 360-delta[sel]

        if docal == 1:
            slew_time = np.amax(np.divide(np.transpose(delta),slew_rate),axis=1) #time to slew from each calibrator to the target
            slew_time = slew_time + cal_slew #adding initial time to get to each calibrator from current position

            #choose minimum slew time
            best_cal = cal_list[np.argmin(slew_time)] 
            plate_cal[i]=best_cal  #keep track of best calibrator
            plate_slewtime[i]=min(slew_time) #keep track of overall slew time
        else:
            slew_time = np.max(delta/slew_rate) #time to move to target (no cal)
            plate_slewtime[i]=slew_time

    #now lets choose the best plate 
    good = (plate_el > min_starting_el) & (plate_el < max_el) & (plate_sun_dist > min_sun_dist) & (plate_ntargs > 0) #throw out bad plates
    plate_slewtime[good != True] = 9999. #easier just to set slew times to large values where good !=1. Fewer indices to manage

    #if sum(good) == 0:
     #   #relax a bit if we have to
     #   good = (plate_el > min_el)
    if not quiet:
        print 'total plates we can observe:',sum(good)
    if sum(good) == 0:
        print 'NO OBSERVABLE PLATES!'
        Break('No observable targets found. Abort script and call someone')
    else:
        #try to limit slew time to  < 2 min
        slew_lt_2 = plate_slewtime < 2
        print 'within 2 min slew:', sum(slew_lt_2)
        if sum(slew_lt_2) > 0:
            subcat = zip(plate_cat['plate'][slew_lt_2],
                              plate_cat['nrequest'][slew_lt_2],
                              plate_cat['nstarted'][slew_lt_2],
                              plate_slewtime[slew_lt_2]) 
            srt_subcat=sorted(subcat,key=itemgetter(1,2),reverse=1) #sort by whether requested, then # started
        else:
            subcat = zip(plate_cat['plate'][good],
                              plate_cat['nrequest'][good],
                              plate_cat['nstarted'][good],
                              plate_slewtime[good]) 
            srt_subcat=sorted(subcat,key=itemgetter(3)) #just go for nearest one

        best = (plate_cat['plate'] == srt_subcat[0][0])
 
    if docal==1:
        if not quiet:
            print 'Best calibrator/plate combination: ',plate_cal[best],plate_cat['plate'][best]
        return plate_cat['plate'][best][0],plate_cal[best][0]
    else:
        if not quiet:
            print 'Best plate to observe: ',plate_cat['plate'][best]
        return plate_cat['plate'][best][0]
        

def set_target_priority(plate,quiet=0):
    from operator import itemgetter
    '''
     Reads in a catalog and uses the various flags to set priorities.
    #current priority order: (1) a requested object (2) started but not finished 
    #(3) not started. Sort each priority group by total time needed to complete
    '''

    #read in the plate catalog
    catpath = catdir+"catalog"+plate+".txt"   
    cat = np.genfromtxt(catpath,dtype=[('target','S21'), ('requested','i'),
                                        ('status','S1'),('nscans','i'),('scanlength','f')],
                                        usecols=[0,4,5,6,7],skip_header=1) 

    #total observing time (scans x scanlength)
    tot_time = cat['nscans']*cat['scanlength']

    #remove finished targets
    keep = (cat['status'] != 'f') & (cat['status'] != 'p')
    cat = cat[keep] 

    priority=np.zeros(len(cat))+2 #default priority
    priority[cat['status'] == 's']=1 #prioritize targets we've started
    priority[cat['requested'] == 1]=0 #requested targets moved to front of list

    if len(cat) > 1:
        subcat = zip(cat['target'],priority,tot_time) #shuld make this a structure
        srt_subcat=sorted(subcat,key=itemgetter(1,2)) #sort by priority, then time
        sourcelist =  [x[0] for x in srt_subcat]
    else:
        sourcelist = cat['target']

    return sourcelist

def observe_plate(plate,quiet=0):
    '''
    Runs all observing commands for a given plate. Also checks the elevation 
    after each scan to make sure we're not getting too low. 
    '''

    if not quiet:
        print 'Observing plate: ',plate
    #read in plate catalog
    catpath = catdir+"catalog"+plate+".txt"
    c=Catalog(catpath) #this is a dictionary (of dictionaries)
    targs = c.keys()
            
    #get the priorities
    if not quiet:
        print 'Determining target priority...'
    srcs=set_target_priority(plate)
    if not quiet:
        print 'Target order: ',srcs
    for s in srcs:
       
        ss=s.tolist() #this is just because some of hte GBT routines dont 
                              #appear to like numpy arrays
#to do, replace this big array with a list that gets imported
        newoff = ['8548-6104','8717-3704', '8624-12705', '8980-3703', 
                         '8484-3703','8550-3701', '8611-6101', '8999-12702',
                         '8999-12702', '8603-6104','8485-6103', '9027-12701',
                         '9871-9101','9871-3701','8454-9102','8948-12703',
                         '8243-12703','8243-3704','10508-12702','8336-12703',
                         '9186-6101','10506-1901','8710-3704','8710-12702',
                         '11941-3702', '11742-3703','11945-1901','11013-6103', 
                         '11013-3703','11945-9101','11863-3703','11941-1902',
                         '11758-12702','11830-9101','8334-6101','11956-6104']   

        if ss in newoff:
            offset=Offset("J2000", "00:02:30","00:00:00",cosv=True) 
        else:
            offset=Offset("J2000", "-00:02:30","00:00:00",cosv=True) #ON/OFF separation

        Slew(ss)
        Balance()

        nscans = c[ss]['nscans']
        scanlength=c[ss]['scanlength']
        catind=np.where(targs == s[0])
        if not quiet:
            print 'Observing '+ss
            print 'nscans = ',nscans
            print 'scan length (s) = ',scanlength
        for j in range(int(nscans)):
            print '**** '
            print 'Reminder: a full ON/OFF pair will take 10 minutes.  If there is not enought time to finish the full pair before our session is over, we encourange you to end early and move on to the next program'
            print '****'
            OnOff(ss,offset,scanlength,'1') 

            #update hte catalogs to say this has been observed
            if j==0:
                if not quiet:
                    print 'updating catalog'
                update_plate_cat(plate,s) #setting status to indicte it's been observed this session

            #check the current position, move on if we've gotten too low or too close to zenith
            cl = GetCurrentLocation("AzEl")
            if not quiet:
                print 'current telescope elevation: ',cl.v
            if cl.v < min_el:
                if not quiet:
                    print 'Getting too low, moving to next plate'
                return
            if cl.v > max_el:
                if not quiet: 
                    print 'Target very close to zenith; moving to another target to minimize overheads'
                return
    if not quiet:
        print 'Finished observing '+plate

def observe_cal(calname,quiet=0,fluxcal=0):
    '''
    Runs observing commands for calibrators
    '''
    if not quiet:
        print 'Observing calibrator '+calname

    Slew(str(calname))
    AutoPeak(str(calname))
    
    #write out file with timestamp of this calibration obs
    t = open(catdir+'calstatus.txt','w')
    now=DateTime.utc()
    #now=DateTime.DateTime(2016,11,15,0,0,0) #this was just for testing
    t.write(now.strftime('%x %X'))
    t.close()
    
    if fluxcal == 1:
        hoff = Offset("J2000", "00:04:00", 0, cosv=True) 
        Configure(config_vegas_onoff)
        Slew(str(calname))
        Balance()
        OnOff(str(calname), hoff, 60)

            #write out file with timestamp of this calibration obs
        t = open(catdir+'fluxcalstatus2.txt','w')
        now=DateTime.utc()
        #now=DateTime.DateTime(2016,11,15,0,0,0) #this was just for testing
        t.write(now.strftime('%x %X'))
        t.close()
    



def update_plate_cat(plate,target):
    '''Updates the plate catalogs to note which objects have been observed
        during this run. Important if there is a crash and we have to restart 
        the observing script.
    '''
    platepath = catdir+'catalog'+plate+'.txt'
    f = open(platepath,'r')
    nf=open('temp.txt','w')
    nf.write(f.readline())
    for line in f:
        #print target
        #print line
        #print target in line
        if target in line:
            line=line.replace('n','p')
            line=line.replace('s','p')
        nf.write(line)
    f.close()
    nf.close()
    #replace original file with temporary one
    os.system('cp temp.txt '+platepath)

def check_cal_status():
    '''Looks for a text file saying when the last calibration was done. If it
    doesn't exist, then it does a cal. If it does exist, then it checks the 
    time, and if more then 4 hours since last cal, it performs one
'''
    now = DateTime.utc()
    #if os.path.isfile(catdir+'calstatus.txt'):
    try:
        t=open(catdir+'calstatus.txt','r')
        lastcal = t.readline()
        delta_t = (now - DateTime.strptime(lastcal,'%x %X')).hours
        print 'time since last calibration (hours): ',delta_t
        if delta_t > 4:
            docal=1
            print '>4 hours since last calibration scan. Will now run calibration scan'
        else:
            docal=0
            print '<4 hours since last calibration scan. Proceeding to galaxy observations'
    except:
        docal=1
        print 'No record of last calibration scan. Will now run calibration scan'


    try:
        t=open(catdir+'fluxcalstatus2.txt','r')
        lastcal = t.readline()
        delta_t = (now - DateTime.strptime(lastcal,'%x %X')).days
        print 'time since last flux calibration( days): ',delta_t
        if delta_t > 3:
            dofluxcal=1
            docal=1
            print '>3 days since flux last calibration scan. Will now run.'
        else:
            dofluxcal=0
            print '<3 days since last flux calibration scan. Ignoring'
    except:
        dofluxcal=1
        docal=1
        print 'No record of last flux calibration scan. Will nowflux  run calibration scan'
    return docal,dofluxcal
    
####################################################################


#configure telescope
execfile("/users/kmasters/16AGBT095/Observing/Config.py")
Configure(config_vegas_onoff)

docal,dofluxcal = check_cal_status() #checks whether we should do a cal scan based on time since last one
#docal=0 #override above code
iter=0
#The script is meant to just keep going, and be aborted when
#our time is up
while iter < 20:
    print 'iteration ',iter
    out=choose_plate(docal=docal) #choose calibrator and first plate
    if len(out) == 2:
        observe_cal(out[1],fluxcal=dofluxcal) #observes calibrator
        Configure(config_vegas_onoff)
        observe_plate(out[0]) #observes plate (MaNGA subregion)
    else:
        Configure(config_vegas_onoff)
        observe_plate(out) #observes plate (MaNGA subregion)
    docal=0 #tell script to no longer observe a calibrator
    iter=iter+1
