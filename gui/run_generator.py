
import safari_input
import os
import numpy

def frange(start, end, step):
    return numpy.arange(start, end, step)
    

def generate(basename, tstart, tend, pstart, pend, estart, eend, res=0.025,\
             estep=1, pstep=1, tstep=1):
    
    safio = safari_input.SafariInput('template.input')
    rundir = os.path.join('.','runs')
    try:
        os.mkdir(rundir)
    except:
        pass
    rundir = os.path.join(rundir,basename)
    try:
        os.mkdir(rundir)
    except:
        pass
    for theta in frange(tstart, tend + tstep, tstep):
        for phi in frange(pstart, pend + pstep, pstep):
            for e0 in frange(estart, eend + estep, estep):
                edir = os.path.join(rundir,str(e0))
                try:
                    os.mkdir(edir)
                except:
                    pass
                safio.E0 = e0
                safio.THETA0 = theta
                safio.PHI0 = phi
                # Set energy resolution to 1%
                safio.ESIZE = e0/100
                filename = str(e0)+'_'+str(theta)\
                                  +'_'+str(phi)+'.input'
                filename = os.path.join(edir,filename)
                safio.save(file=filename)

if __name__ == '__main__':
    
    basename = input("Output Base Name? ")
    
    estart = input("Energy Start? ")
    eend = input("Energy End? ")
    estep = '1'
    if(estart!=eend):
        estep = input("Energy Step? ")
    
    tstart = input("Theta Start? ")
    tend = input("Theta End? ")
    tstep = '1'
    if(tstart!=tend):
        tstep = input("Theta Step? ")
    
    pstart = input("Phi Start? ")
    pend = input("Phi End? ")
    pstep = '1'
    if(pstart!=pend):
        pstep = input("Phi Step? ")
        
    generate(basename, float(tstart), float(tend), float(pstart),\
                       float(pend), float(estart), float(eend),\
                       estep=float(estep), pstep=float(pstep), tstep=float(tstep))