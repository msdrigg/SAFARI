C MODIFIED TO ACCOMODATE THE ULTIMATE DETECTOR.
C MODIFIED TO WRITE TO DISK AT INTERMEDIATE POINTS.
C CAPABLE OF RUNNING FINITE TEMPERATURE SPECTRA
C
      PROGRAM SAFARI
C
C THIS PROGRAM COMPUTES THE ENERGY AND/OR ANGULAR SPECTRUM OF IONS
C SCATTERED CLASSICALLY FROM A CRYSTAL SURFACE.
C SUBROUTINE SCAT IS USED TO COMPUTE THE TRAJECTORIES OF THE IONS.
C
C PLAN OF ATTACK:
C     THE INCOMING IONS ARE CHARACTERIZED BY THEIR ENERGY E0 AND
C ANGLES THETA0 AND PHI0. THESE VALUES ARE PROVIDED BY THE USER.
C PARAMETERS CHARACTERIZING THE CRYSTAL ARE FETCHED FROM DISK BY
C SUBROUTINE CRYSTL. SEE THE SUBROUTINE FOR DETAILS.
C
C       IMPACT PARAMETERS ARE SELECTED TO GET THE MOST INFORMATION FOR T
C LEAST AMOUNT OF WORK. THE USER SPECIFIES ENERGY, THETA, AND PHI BIN
C SIZES FOR THE DETECTOR. THE UNIT CELL IS SUBDIVIDED INTO 4 CELLS, AND
C TRAJECTORIES ARE CALCULATED AT THE CORNERS OF EACH CELL. IF THE 4 TRAJ
C OF A SUBCELL WILL FIT INTO ONE DETECTOR BIN, OR IF THEY ARE ALL OUT OF
C DETECTOR'S RANGE, THEN ALL IS GOOD. IF NOT, THEN THE SUBCELL IS DIVIDE
C INTO 4 SUBCELLS, AND SO ON UNTIL THE TRAJECTORIES FIT INTO THE DETECTO
C OR A MAXIMUM NUMBER OF DIVISIONS HAVE BEEN PERFORMED.
C       TRAJECTORIES ARE STORED IN THESE ARRAYS:
C               XTRAJ, YTRAJ    IMPACT PARAMETER
C               ENRGY                   FINAL ENERGY
C               THETA, PHI              FINAL ANGLES
C               AREA                    TOTAL AREA OF DETECTABLE SUBCELL
C                                               WHICH CONTAIN THE TRAJEC
C       IN ORDER TO AVOID COMPUTING ANY TRAJECTORY TWICE, LOTS OF INFORM
C ABOUT THE SUBCELLS IS REQUIRED.
C               XLL,YLL         COORDINATES OF LOWER LEFT CORNER OF CELL
C               PADD                    ADDRESS OF PARENT CELL. XLL(PADD
C                                               THE COORDINATE OF THE L.
C                                               THE CELL OF WHICH CELL I
C               PSUB                    IS THIS CELL A NE, NW, SE, OR SW
C               SUBADD          GIVES ADDRESSES OF THE SUBCELLS OF A CEL
C               TRJADD          POINTS TO TRAJECTORIES AT THE CORNERS OF
C WHEN ALL IS DONE, SUBROUTINE OUTPUT WRITES THE TRAJECTORY ARRAYS.
C SPECTRA MAY BE COMPUTED BY ASSIGNING A WEIGHT AREA TO EACH TRAJECTORY.
C
C TRAJECTORIES ARE COMPUTED IN THREE STEPS. IN THE FIRST STEP THE ION
C MOVES FROM A HEIGHT INFINITY TO A HEIGHT Z1 UNDER THE INFLUENCE OF THE
C CHARGE POTENTIAL ALONE. THIS STEP IS PERFORMED ANALYTICALLY BY
C RAINBOW. IN THE SECOND STEP, THE ION MOVES UNDER THE INFLUENCE OF THE
C FULL SURFACE POTENTIAL FROM HEIGHT Z1 TO ITS TURNING POINT, AND BACK T
C Z1. THIS STEP IS PERFORMED BE SCAT. IN THE THIRD STEP THE ION RETURNS
C TO HEIGHT INFINITY WITH ONLY THE IMAGE CHARGE POTENTIAL.
C
C SUBROUTINE SCAT REQUIRES FOUR FUNCTIONS TO CALCULATE TRAJECTORIES.
C THESE ARE
C     DVDR(R)   - DERIVATIVE OF ION-ATOM POTENTIAL ENERGY W.R.T. ION-ATO
C                 SEPARATION R.
C     DVIMDZ(Z) - DERIVATIVE OF IMAGE CHARGE ENERGY W.R.T. DISTANCE FROM
C                 THE SURFACE Z.
C     V(R)      - POTENTIAL ENERGY OF ION AND ATOM.
C     VIM(Z)    - POTENTIAL ENERGY DUE TO IMAGE CHARGE OR OTHER BULK EFF
C
C ALL ENERGIES ARE IN EV.
C ALL DISTANCES ARE IN ANGSTROMS.
C ALL MASSES ARE IN AMU.
C ALL TIMES ARE IN ANGSTROMS*SQRT(AMU/EV) = 10.18 FEMTOSECONDS.
c                                         = 421.44 a.u. time units
C KEEP THIS IN MIND WHEN WRITING DVDR, ETC.
C
C
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE "params.txt"
C
C DETECTION:
C
      REAL*8 EMIN,EMAX,ESIZE
C               INPUT PARAMETERS.
C               MINIMUM AND MAXIMUM DETECTABLE ENERGIES, AND THE REQUEST
C               ENERGY RESOLUTION.
      REAL*8 ASIZE
C               INPUT PARAMTER.   ANGULAR RESOLUTION.
      INTEGER NDTECT
C               WHAT IS THE DETECTOR SHAPE?
C               1 ==> SPOT.
C               2 ==> STRIPE.
C               3 ==> GEODESICS.
C               4 ==> SIMPLE LIMITS ON THETA AND PHI.
      REAL*8 DPARAM(10)
C               INPUT PARAMETERS DESCRIBING THE ANGULAR EXTENT OF THE DE
C
C BEAM:
C
      REAL*8 E0,THETA0,PHI0
C           INPUT PARAMETERS.
C           INCIDENT ENERGY AND ANGLE.
      REAL*8 MION
C           INPUT PARAMETER.
C           MASS OF INCIDENT ION.
      REAL*8 MION1
C               INVERSE MASS.

c     Charge of the ion squared, used for image potentials.
      integer qion
C
C CRYSTAL:    ALL THIS IS IN COMMON/XTAL/ AND COMMON/MASS/.
C
      REAL*8 AX,AY
C           DIMENSIONS OF THE SURFACE UNIT CELL IN ANGSTROMS.
      INTEGER NBASIS
C           NUMBER OF BASIS ATOMS IN THE UNIT CELL.
      REAL*8 XBASIS(3,NBASISMAX)
C           BASIS VECTORS OF ATOMS IN THE CELL IN ANGSTROMS.
      INTEGER TYPBAS(NBASISMAX)
C           TYPES OF ATOMS IN CELL.
C           EACH VARIETY OF ATOM IS ASSIGNED AN INTEGER TYPE, WHICH
C           IS THEN REFERRED TO BY ANY ROUTINE WHICH REQUIRES THE
C           MASS OR POTENTIAL OF THE ATOM.
      INTEGER TYPEAT(NPARTMAX)
C               USED BY SCAT AND DECLARED HERE TO GET THE COMMON BLOCKS
      REAL*8 MASS(NTYPEMAX)
C           MASSES IN AMU OF SURFACE ATOMS OF VARIOUS TYPES.
      REAL*8 MASS1(NTYPEMAX)
C               INVERSES OF MASSES.
C
C INTEGRATION OF TRAJECTORIES:
C
      REAL*8 DELT0
C           INITIAL TIME STEP IN SECONDS. INPUT PARAMETER.
C               THE TIME STEP IS NEVER GREATER THAN DELT0 AND NEVER LESS
C               THAN DELLOW.
      REAL*8 DEMAX,DEMIN
C           MAXIMUM AND MINIMUM TOLERANCES FOR RELATIVE ENERGY
C           NONCONSERVATION. IF ENERGY IS NOT BEING CONSERVED,
C           THEN THE TIME STEP IS ALTERED. SEE SCAT FOR DETAILS.
      REAL*8 ABSERR
C           MAXIMUM TOLERANCE FOR ABSOLUTE ENERGY NONCONSERVATION.
      REAL*8 DELLOW
C               SMALLEST TIME STEP TO BE CONSIDERED. INPUT PARAMETER.
      REAL*8 DELMIN
C           SMALLEST TIME STEP NEEDED TO KEEP ENERGY VARIATION
C           WITHIN BOUNDS. IN ORDER TO RUN WITHOUT CHECKING THE
C           ENERGY, MAKE A TEST RUN, FIND DELMIN, AND SET
C           DELT0 = DELMIN.
      INTEGER NCALLS,NSTEPS
C           STATISTICS ON INTEGRATION. SEE SCAT.
      REAL*8 TIME
C           TIME OF FLIGHT FOR ION.
      INTEGER NPART
C           INPUT PARAMETER. NPART ATOMS ON THE SURFACE INTERACT WITH
C       THE ION AT ONCE. LIMIT IS TEN.
      LOGICAL RECOIL
C               LET THE SURFACE RECOIL?
C
C TABULATED POTENTIAL FUNCTIONS.
C
      REAL*8 TDVDR2(NTABLE,3),TINDR2(NTABLE)
      REAL*8 TDIMDZ(NTABLE),TVR2(ntable,3)
      EXTERNAL VR2,DVDR2,DVIMDZ,DINDR2
C               POTENTIAL ENERGY FUNCTIONS AND TABLES THEREOF.
      INTEGER NTAB
C               NUMBER OF ENTRIES IN TABLES.
      REAL*8 RRMIN,RRSTEP,ZMIN,ZSTEP
C               MINIMUM VALUES AND STEP SIZES FOR INDEPENDENT VARIABLE I
C               TABLES. V AND DVDR ARE FUNCTIONS OF R; VIM AND DVIMDZ AR
C               FUNCTIONS OF Z.
C
C GRID CELLS, ADDRESSES, POINTERS, AND MASSIVE DATA STRUCTURES.
C
      INTEGER MAXDIV,MINDIV
C               INPUT PARAMETERS.
C               MAXDIV = MAXIMUM NUMBER OF GRID BIFURCATIONS ALLOWED.
C               MAXDIV .LE. MXDIV; SET IN A PARAMETER STATEMENT.
C               MINDIV = MINIMUM NUMBER OF GRID BIFURCATIONS. IF MINDIV
C               IS TOO SMALL, FEATURES OF THE SPECTRUM MAY BE MISSED.
C
      REAL*8 FAX,FAY
C               INPUT PARAMETERS.
C               FRACTION OF UNIT CELL TO BE COVERED BY GRID.
C               FOR COMPLETE COVERAGE, FAX=FAY=1.
      LOGICAL PBC
C               ARE THERE PERIODIC BOUNDARY CONDITIONS?
C               (I.E. DOES FAX=FAY=1?)
C
      REAL*8 XLL(NARRAY),YLL(NARRAY)
C               COORDINATES OF LOWER LEFT HAND CORNER OF CELL.
C
      INTEGER PADD(NARRAY),PSUB(NARRAY)
C               PADD(I) IS THE ADDRESS OF THE PARENT OF THE ITH CELL.
C               PADD(PADD(I)) IS THE ADDRESS OF THE GRANDPARENT OF THE
C               ITH CELL. THE ITH CELL IS THE PSUB(I) SUBCELL OF ITS
C               PARENT.
C                       5 = 0101 = SW
C                       6 = 0110 = SE
C                       9 = 1001 = NW
C                       10= 1010 = NE
C
      INTEGER SUBADD(4,NARRAY),TRJADD(4,NARRAY)
C               SUBADD(J,I) IS THE ADDRESS WITHIN XLL, LEVEL, PADD,
C               ETC. OF THE JTH SUBCELL OF THE ITH CELL.
C               TRJADD(J,I) IS THE ADDRESS WITHIN ENERGY, THETA, PHI
C               OF THE TRAJECTORY WHOSE IMPACT PARAMETER LIES ON THE
C               JTH CORNER OF THE       ITH CELL.
C
      INTEGER CPOINT
C               CPOINT GIVES THE NEXT VACANT SPACE IN XLL,YLL,PADD,
C               PSUB,SUBADD, AND TRJADD. IT IS THE CELL POINTER.
C
      INTEGER SEARCH
C               SEARCH IS THE FUNCTION THAT FINDS NEIGHBORING CELLS
C               OF THE GRID.
      INTEGER CCELL(MXDIV),NDIV,PARENT,NBOR,EDGE
C               CCELL(NDIV) IS THE ADDRESS WITHIN XLL, ETC. OF THE
C               CURRENT CELL, SOMETIMES CALLED PARENT.
C               NDIV IS THE CURRENT GRID NESTING DEPTH.
C               NBOR IS THE ADDRESS OF A NEIGHBORING CELL,
C               RETURNED BY SEARCH.
C               EDGE TELLS SEARCH WHICH NEIGHBOR TO LOOK FOR.
C
      INTEGER*4 ISTORE,ITOTJ
      REAL*8 AREA(NARRAY)
C               AREA STORES THE AREA OF THE CELL ASSOCIATED WITH
C               THE TRAJECTORY.
      REAL*8 ENRGY(NARRAY),THETA(NARRAY),PHI(NARRAY)
C               ENRGY(I) ,THETA(I), AND PHI(I) ARE THE RESULTS OF SCAT
C               FOR THE ITH     TRAJECTORY.
      REAL*8 XTRAJ(NARRAY),YTRAJ(NARRAY)
C               X AND Y COORDINATES OF IMPACT PARAMETERS
      REAL*8 PX(NARRAY),PY(NARRAY),PZ(NARRAY)
C               FINAL MOMENTA OF TRAJECTORY.
      INTEGER LEVEL(NARRAY)
C               LEVEL INDICATES THE SUBDIVISION AT WHICH A TRAJECTORY
C               WAS COMPUTED.
      INTEGER TPOINT
C               TPOINT INDICATES THE NEXT VACANT POSITION IN AREA,
C               ENRGY, THETA, ETC. IT IS THE TRAJECTORY POINTER.
      LOGICAL DTECT
C               DTECT IS A FUNCTION THAT TRIES TO FIT THE TRAJECTORIES
C               OF A CELL INTO A BIN OF THE DETECTOR AND INCREMENTS AREA
C               ACCORDINGLY. DTECT RETURNS .TRUE. IF SUCCESSFUL.
      INTEGER SW,SE,NW,NE
C
      LOGICAL START
C
      INTEGER I,J
C
C
      CHARACTER*70 POTENT
      INTEGER ITRAJ
C VARIABLES FOR CHAIN CALCULATION
      REAL*8 XSTART,YSTART,XSTEP,YSTEP
C
      LOGICAL TOFINE
      LOGICAL IMAGE
C THERMAL VARIABLES
      REAL*8 TEMP, SEED
      INTEGER NITER
C NITER = NUMBER OF CONFIGURATIONS TO USE
C
      Character*25 finput
      Character*50 Fname
C Variables for CONVEX timing
      REAL TARRAY(2), TIMER
C Variable for IBM RSC6000 timing
*      INTEGER ITIMER
      LOGICAL PLOTAT
      INTEGER PLOT
c variable for timing
COMMON!!
      COMMON/BEAM/E0,THETA0,PHI0
      COMMON/XTAL/AX,AY,XBASIS,TYPBAS,NBASIS
        COMMON/TYPES/NTYPES
      COMMON/MASS/MASS,MION,TYPEAT
        COMMON/MINV/MASS1,MION1
        common/projectile/qion
      COMMON/NRG/DEMAX,DEMIN,ABSERR,DELLOW,DELT0
      COMMON/STATS/DELMIN,NCALLS,NSTEPS,TIME
        COMMON/SWITCH/PLOT,PLOTAT,RECOIL
        COMMON/TABLES/TDVDR2,TDIMDZ,TINDR2,RRMIN,RRSTEP,ZMIN,ZSTEP,NTAB
        COMMON/TVR2/TVR2
      COMMON/DETECT/AREA
        COMMON/DPARAM/DPARAM,NDTECT
        COMMON/TRAJS/ENRGY,THETA,PHI,TRJADD
        COMMON/MOMENT/PX,PY,PZ
        COMMON/POINTS/XTRAJ,YTRAJ,LEVEL
        COMMON/OTHER/Z1,MAXDIV,MINDIV,FAX,FAY,START,NPART
        COMMON/PBC/PBC,NWRITX,NWRITY
        COMMON/POTPAR/POTPAR(30),PIMPAR(10),IPOT,IIMPOT
        COMMON/POTENT/POTENT
        COMMON/TOFINE/TOFINE
        COMMON/IMAGE/IMAGE
        COMMON/TEMP/TEMP
        COMMON/RANDOM/SEED,NITER
      COMMON/MAXDIF/EDIF,ADIF,AMISS,ATOT,AMULT,EAV,AAV,NONRES
     &  ,NUMCEL
        COMMON/RESOLV/EMIN,EMAX,ESIZE,ASIZE
        COMMON/CHAIN/XSTART,YSTART,XSTEP,YSTEP,NUMCHA
      COMMON/UTILTY/DZERO, XNULL(4), PI

      DATA SW,SE,NW,NE/5,6,9,10/
      PI=2.0d0*dasin(1.0d0)
      DZERO = 1.0D-10
      XNULL(1) = 0.0D0
      XNULL(2) = 0.0D0
      XNULL(3) = 0.0D0
      XNULL(4) = 0.0D0
      NONRES=0
      NUMCEL=0
      AMISS=0.0D0
      ATOT=0.0D0
      AMULT=0.0D0
      EAV=0.0D0
      AAV=0.0D0
      ISTORE=0
      TPOINT=0
      plot=0
      qion = 1
      PLOTAT=.FALSE.
      START=.TRUE.
C
C
      KK=0
      ITOTJ=0

C      Get names for input file and crystal file
      open(20,status='old',file='safari.input',form='formatted')
      read(20,'(A)') finput
      close(20)
      LINPUT = INDEX(FINPUT,' ')-1
      Fname=finput(1:linput)//'.input'
      open(unit=9,form='formatted',status='old',file=Fname)
      Fname=finput(1:linput)//'.param'
      open(unit=10,form='formatted',file=Fname)
      Fname=finput(1:linput)//'.undata'
      open(unit=13,form='unformatted',file=Fname)
      Fname=finput(1:linput)//'.data'
      open(unit=66,form='formatted',file=Fname)

C GET INPUT.
      EDIF=-1.0D0
      ADIF=-1.0D0
      CALL INPUTS
C
C SET UP THE DETECTOR.
      CALL DSETUP(NDTECT)
C Call dtput to write detector parameters to data files
      Call dtput
C
C TABULATE POTENTIALS.
      IF(NTAB.NE.0) THEN
         DO 10 NV=1,NTYPES
            CALL TABLE(VR2,RRMIN,RRSTEP,NTAB,TVR2(1,NV),NV)
            CALL TABLE(DVDR2,RRMIN,RRSTEP,NTAB,TDVDR2(1,NV),NV)
10       CONTINUE
         IF(IMAGE) THEN
C           USE IMAGE POTENTIALS
            IF(IIMPOT.EQ.1) THEN
               CALL TABLE(DVIMDZ,ZMIN,ZSTEP,NTAB,TDIMDZ,0)
            ELSE IF(IIMPOT.EQ.2) THEN
               CALL TABLE(DINDR2,RRMIN,RRSTEP,NTAB,TINDR2,0)
            ENDIF
         ENDIF
      ENDIF
      IF(IMAGE .AND. IIMPOT.EQ.2) CALL IMINIT(1,0)
C
C
C ALL IONS START AT HEIGHT INFINITY AND FALL TO HEIGHT Z1 USING ONLY THE
C IMAGE CHARGE (BULK) POTENTIAL. COMPUTE THE MOMENTUM AT Z1 NOW.
C       FIRST, THE MOMENTUM AT INFINITY.
      P0=DSQRT(2.*MION*E0)
      PZ0=-P0*DCOS(THETA0)
      PTRANS=P0*DSIN(THETA0)
      PX0=PTRANS*DCOS(PHI0)
      PY0=PTRANS*DSIN(PHI0)
C COMPUTE OFFSETS FOR SURFACE IMPACT PARAMETERS
      OFFX = Z1*DTAN(THETA0)*DCOS(PHI0)
      OFFY = Z1*DTAN(THETA0)*DSIN(PHI0)
C       MOVE TO Z1 BY CONSERVING ENERGY.  ASSUME THAT EVEN CORRUGATED
C       IMAGES ARE FLAT THIS FAR OUT
      IF(IMAGE) THEN
         PZ1=-DSQRT(PZ0*PZ0-2.*MION*VIM(0.0D0,0.0D0,Z1))
      ELSE
         PZ1=PZ0
      ENDIF
C
C PREPARE FOR THERMAL EFFECTS
      CALL TSETUP(TEMP)

c start timing
      timer=dtime(tarray)

C FOR CHAIN CALCULATIONS AND MONTE CARLO:  REQUIRES MAXDIV.EQ.MINDIV.EQ.1
      IF(MAXDIV.EQ.MINDIV.AND.MAXDIV.EQ.1) THEN

*        If only 1, we should output a plot file as well.
         if(numcha.eq.1) then
            PLOT = 11
            Fname=finput(1:linput)//'.xyz'
            open(unit=11,form='formatted',file=Fname)
*           Run a single chainscat, then quit
            call chainscat(OFFX, OFFY, PX0, PY0, PZ1, NPART)
            go to 777
         endif

C IF NWRITX AND NWRITY .EQ.666 THEN DO MONTE CARLO
         IF(NWRITX.EQ.666 .AND. NWRITY.EQ.666) THEN
            call montecarlo(OFFX, OFFY, PX0, PY0, PZ1, NPART)
*           Do Output
            go to 777
         ENDIF

*        Assume we want a chain calculation instead.
         call chainscat(OFFX, OFFY, PX0, PY0, PZ1, NPART)
*        Do Output
         go to 777
      ENDIF
C THE EFFECTIVE PRIMARY CELL HAS SIDES AXPRIM AND AYPRIM.
C ONE EFFECTIVE PRIMARY CELL IS COVERED, THE RESULTS ARE
C WRITTEN TO THE DISK, THE ARRAYS ARE REINITIALIZED, AND THE
C NEXT EPC IS COVERED.
      AXPRIM=AX*FAX/NWRITX
      AYPRIM=AY*FAY/NWRITY
C
C LOOP OVER THERMAL CONFIGURATIONS
      DO 2345 ISURF=1,NITER
         SEED=RANDSF(SEED)
C LOOP THROUGH THE PRIMARY CELLS.
C
         DO 12345 IEPCX=1,NWRITX
         DO 12345 IEPCY=1,NWRITY
C
            NDUMP=0
C
C SET UP THE PRIMARY CELL.
            XLL(1)=AXPRIM*(IEPCX-1)
            YLL(1)=AYPRIM*(IEPCY-1)
            NDIV=1
            CCELL(1)=1
            CPOINT=2
C
C INITIALIZE ARRAYS.
            DO 90 I=1, NARRAY
               PADD(I)=0
               PSUB(I)=0
               AREA(I)=0.
               LEVEL(I)=0
               DO 90 J=1, 4
                  SUBADD(J,I)=0
                  TRJADD(J,I)=0
90          CONTINUE
C
C
C COMPUTE THE TRAJECTORY AT THE ORIGIN OF THEPCRIMARY CELL.
            XTRAJ(1) = XLL(1)
            YTRAJ(1) = YLL(1)
            X = XTRAJ(1) -OFFX
            Y = YTRAJ(1) -OFFY
            ITRAJ=1
            CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,ENRGY(1),THETA(1),
     &             PHI(1),PX(1),PY(1),PZ(1),NPART,ITRAJ)
C           WRITE(6,*) '1'
            IF(NDIV.LT.MINDIV) THEN
               LEVEL(1)=MINDIV
            ELSE
               LEVEL(1)=NDIV
            ENDIF
            TRJADD(1,1)=1
            IF(PBC) THEN
               TRJADD(2,1)=1
               TRJADD(3,1)=1
               TRJADD(4,1)=1
               TPOINT=2
            ELSE
               XTRAJ(2) = XLL(1)+AXPRIM
               YTRAJ(2) = YLL(1)
               X = XTRAJ(2) -OFFX
               Y = YTRAJ(2) -OFFY
               ITRAJ=2
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,ENRGY(2),THETA(2),
     &                PHI(2),PX(2),PY(2),PZ(2),NPART,ITRAJ)
C              WRITE(6,*) '2'
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(2)=MINDIV
               ELSE
                  LEVEL(2)=NDIV
               ENDIF
               TRJADD(2,1)=2
C
               XTRAJ(3) = XLL(1)
               YTRAJ(3) = YLL(1)+AYPRIM
               X = XTRAJ(3) -OFFX
               Y = YTRAJ(3) -OFFY
               ITRAJ=3
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,ENRGY(3),THETA(3),
     &                PHI(3),PX(3),PY(3),PZ(3),NPART,ITRAJ)
C              WRITE(6,*) '3'
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(3)=MINDIV
               ELSE
                  LEVEL(3)=NDIV
               ENDIF
               TRJADD(3,1)=3
C
               XTRAJ(4) = XLL(1)+AXPRIM
               YTRAJ(4) = YLL(1)+AYPRIM
               X = XTRAJ(4) -OFFX
               Y = YTRAJ(4) -OFFY
               ITRAJ=4
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,ENRGY(4),THETA(4),
     &                PHI(4),PX(4),PY(4),PZ(4),NPART,ITRAJ)
C              WRITE(6,*) '4'
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(4)=MINDIV
               ELSE
                  LEVEL(4)=NDIV
               ENDIF
               TRJADD(4,1)=4
C
               TPOINT=5
            ENDIF
C
C
C
C SUBDIVIDE THE CELL!
C
100         CONTINUE
C
C       DUMP TO SFDUMP SOMETIMES TO RECOVER FROM SYSTEM CRASHES.
C
C SET UP FOUR SUBCELLS AT CPOINT, CPOINT+1, CPOINT+2, CPOINT+3.
C       LOADPARENT ADDRESS FOR FOUR SUBCELLS.
            PARENT=CCELL(NDIV)
            DO 110 I=1,4
               PADD(CPOINT-1+I)=PARENT
               SUBADD(I,PARENT)=CPOINT-1+I
110         CONTINUE
C
C COMPUTE COORDINATES OF LOWER LEFT HAND CORNERS OF SUBCELLS.
            AXC=AXPRIM/2.**NDIV
            AYC=AYPRIM/2.**NDIV
            XLL(CPOINT)=XLL(PARENT)
            YLL(CPOINT)=YLL(PARENT)
            XLL(CPOINT+1)=XLL(PARENT)+AXC
            YLL(CPOINT+1)=YLL(PARENT)
            XLL(CPOINT+2)=XLL(PARENT)
            YLL(CPOINT+2)=YLL(PARENT)+AYC
            XLL(CPOINT+3)=XLL(CPOINT+1)
            YLL(CPOINT+3)=YLL(CPOINT+2)
C
C LOAD RELATIVE LOCATIONS OF SUBCELLS.
            PSUB(CPOINT)=SW
            PSUB(CPOINT+1)=SE
            PSUB(CPOINT+2)=NW
            PSUB(CPOINT+3)=NE
C
C GO DOWN TO THE LEVEL OF THE SUBCELLS AND COMPUTE TRAJECTORIES.
            NDIV=NDIV+1
C
C THE TRAJECTORIES OF THEPARENT CELL ARE ALSO TRAJECTORIES OF THE SUBCE
            DO 120 I=1,4
               TRJADD(I,CPOINT-1+I)=TRJADD(I,PARENT)
120         CONTINUE
C
C COMPUTE THE TRAJECTORY AT THE CENTER OF THEPARENT CELL.
            XTRAJ(TPOINT) = XLL(CPOINT+3)
            YTRAJ(TPOINT) = YLL(CPOINT+3)
            X = XTRAJ(TPOINT) -OFFX
            Y = YTRAJ(TPOINT) -OFFY
            ITRAJ=TPOINT
            CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,ENRGY(TPOINT),THETA(TPOINT),
     1       PHI(TPOINT),PX(TPOINT),PY(TPOINT),PZ(TPOINT),NPART,TPOINT)
C           WRITE(6,*) '*',TPOINT,X,Y
            IF(NDIV.LT.MINDIV) THEN
               LEVEL(TPOINT)=MINDIV
            ELSE
               LEVEL(TPOINT)=NDIV
            ENDIF
            DO 130 I=1,4
               TRJADD(I,CPOINT+4-I)=TPOINT
130         CONTINUE
            TPOINT=TPOINT+1
C               IF TOO MANY TRAJECTORIES HAVE BEEN COMPUTED, QUIT.
            IF(TPOINT.GT.NARRAY) GO TO 6666
C
C
C FIND OUT WHETHER THE TRAJECTORIES ON THE EDGE OF THEPARENT CELL HAVE
C COMPUTED. COPY THE DATA TO THE SUBCELLS IF IT HAS BEEN COMPUTED, OR CO
C THE TRAJECTORIES IF NECESSARY.
C
C       FIRST, THE ADVENTUROUS WEST...
            EDGE=1
C       NBOR IS THE ADDRESS OF THE NEIGHBORING CELL ON THE EDGE IN QUEST
            NBOR=SEARCH(EDGE,PARENT,PSUB,PADD,SUBADD)
C       IF CELL NBOR HAS SUBCELLS, THEN THE TRAJECTORY HAS BEEN COMPUTED
C       IF NBOR IS ZERO, THEN THE NEIGHBORING CELL DOES NOT EXIST.
            IF(NBOR.NE.0 .AND. SUBADD(4,NBOR).NE.0) THEN
C                       THE TRAJECTORY IS FOUND IN A SUBCELL OF NBOR.
               TRJADD(3,CPOINT)=TRJADD(2,SUBADD(4,NBOR))
               TRJADD(1,CPOINT+2)=TRJADD(3,CPOINT)
            ELSE
C                       THE TRAJECTORY IS NOT FOUND. COMPUTE IT.
               XTRAJ(TPOINT) = XLL(CPOINT+2)
               YTRAJ(TPOINT) = YLL(CPOINT+2)
               X = XTRAJ(TPOINT) -OFFX
               Y = YTRAJ(TPOINT) -OFFY
               ITRAJ=TPOINT
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,
     1                ENRGY(TPOINT),THETA(TPOINT),PHI(TPOINT),
     1                PX(TPOINT),PY(TPOINT),PZ(TPOINT),NPART,TPOINT)
C              WRITE(6,*) '*',TPOINT,X,Y
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(TPOINT)=MINDIV
               ELSE
                  LEVEL(TPOINT)=NDIV
               ENDIF
               TRJADD(3,CPOINT)=TPOINT
               TRJADD(1,CPOINT+2)=TPOINT
               TPOINT=TPOINT+1
               IF(TPOINT.GT.NARRAY) GO TO 6666
            ENDIF
C
C ... THEN THE MYSTERIOUS EAST...
            EDGE=2
            NBOR=SEARCH(EDGE,PARENT,PSUB,PADD,SUBADD)
            IF(NBOR.NE.0 .AND. SUBADD(1,NBOR).NE.0) THEN
C                       THE TRAJECTORY IS FOUND IN A SUBCELL OF NBOR.
               TRJADD(4,CPOINT+1)=TRJADD(3,SUBADD(1,NBOR))
               TRJADD(2,CPOINT+3)=TRJADD(4,CPOINT+1)
            ELSE
C                       THE TRAJECTORY IS NOT FOUND. COMPUTE IT.
               XTRAJ(TPOINT) = XLL(CPOINT+3) +AXC
               YTRAJ(TPOINT) = YLL(CPOINT+3)
               X = XTRAJ(TPOINT) -OFFX
               Y = YTRAJ(TPOINT) -OFFY
               ITRAJ=TPOINT
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,
     1                ENRGY(TPOINT),THETA(TPOINT),PHI(TPOINT),
     2                PX(TPOINT),PY(TPOINT),PZ(TPOINT),NPART,TPOINT)
C              WRITE(6,*) '*',TPOINT,X,Y
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(TPOINT)=MINDIV
               ELSE
                  LEVEL(TPOINT)=NDIV
               ENDIF
               TRJADD(4,CPOINT+1)=TPOINT
               TRJADD(2,CPOINT+3)=TPOINT
               TPOINT=TPOINT+1
               IF(TPOINT.GT.NARRAY) GO TO 6666
            ENDIF
C
C ... AND THE TORRID SOUTH...
            EDGE=4
            NBOR=SEARCH(EDGE,PARENT,PSUB,PADD,SUBADD)
            IF(NBOR.NE.0 .AND. SUBADD(4,NBOR).NE.0) THEN
C                       THE TRAJECTORY IS FOUND IN A SUBCELL OF NBOR.
               TRJADD(2,CPOINT)=TRJADD(3,SUBADD(4,NBOR))
               TRJADD(1,CPOINT+1)=TRJADD(2,CPOINT)
            ELSE
C                       THE TRAJECTORY IS NOT FOUND. COMPUTE IT.
               XTRAJ(TPOINT) = XLL(CPOINT+1)
               YTRAJ(TPOINT) = YLL(CPOINT+1)
               X = XTRAJ(TPOINT) -OFFX
               Y = YTRAJ(TPOINT) -OFFY
               ITRAJ=TPOINT
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,
     1                ENRGY(TPOINT),THETA(TPOINT),PHI(TPOINT),
     2                PX(TPOINT),PY(TPOINT),PZ(TPOINT),NPART,TPOINT)
C              WRITE(6,*) '*',TPOINT,X,Y
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(TPOINT)=MINDIV
               ELSE
                  LEVEL(TPOINT)=NDIV
               ENDIF
               TRJADD(2,CPOINT)=TPOINT
               TRJADD(1,CPOINT+1)=TPOINT
               TPOINT=TPOINT+1
               IF(TPOINT.GT.NARRAY) GO TO 6666
            ENDIF
C
C ... FOLLOWED BY THE FRIGID AND EVERPCERILOUS NORTH.
            EDGE=8
            NBOR=SEARCH(EDGE,PARENT,PSUB,PADD,SUBADD)
            IF(NBOR.NE.0 .AND. SUBADD(1,NBOR).NE.0) THEN
C                   THE TRAJECTORY IS FOUND IN A SUBCELL OF NBOR.
               TRJADD(4,CPOINT+2)=TRJADD(2,SUBADD(1,NBOR))
               TRJADD(3,CPOINT+3)=TRJADD(4,CPOINT+2)
            ELSE
C                      THE TRAJECTORY IS NOT FOUND. COMPUTE IT.
               XTRAJ(TPOINT) = XLL(CPOINT+3)
               YTRAJ(TPOINT) = YLL(CPOINT+3)+AYC
               X = XTRAJ(TPOINT) -OFFX
               Y = YTRAJ(TPOINT) -OFFY
               ITRAJ=TPOINT
               CALL SCATTR(X,Y,Z1,PX0,PY0,PZ1,
     1                ENRGY(TPOINT),THETA(TPOINT),PHI(TPOINT),
     2                PX(TPOINT),PY(TPOINT),PZ(TPOINT),NPART,TPOINT)
C              WRITE(6,*) '*',TPOINT,X,Y
               IF(NDIV.LT.MINDIV) THEN
                  LEVEL(TPOINT)=MINDIV
               ELSE
                  LEVEL(TPOINT)=NDIV
               ENDIF
               TRJADD(4,CPOINT+2)=TPOINT
               TRJADD(3,CPOINT+3)=TPOINT
               TPOINT=TPOINT+1
               IF(TPOINT.GT.NARRAY) GO TO 6666
            ENDIF
C
C
            CPOINT=CPOINT+4
            IF(CPOINT.GT.(NARRAY-3)) GO TO 6667
C
C THE TRAJECTORIES AT THE CORNERS OF THE SUBCELLS ARE ALL COMPUTED.
*            IF(NDIV.EQ.MAXDIV) THEN
C              WRITE(6,8888)
*            ENDIF
C8888        FORMAT(' AT SMALLEST GRID SIZE.')
C
C LOOP THROUGH THE NEW CELLS. TRY TO STORE DATA IN DETECT, IF IMPOSSIBLE
C THEN SUBDIVIDE (I.E. GO TO 100).
            CCELL(NDIV)=SUBADD(1,PARENT)
C
150         CONTINUE
C       SUBDIVIDE IF THE GRID IS STILL TOO COARSE, REGARDLESS OF TRAJECT
            IF(NDIV.LT.MINDIV) GO TO 100
C           WRITE(0,*) 'CALLING DTECT:NDIV=',NDIV,' CELL=',CCELL(NDIV)
            IF(DTECT(CCELL(NDIV),NDIV,MAXDIV)) GO TO 160
            GO TO 100
C
C       TRAJECTORIES HAVE BEEN DETECTED. GO TO NEXT CELL.
160         CONTINUE
C           WRITE(6,*) 'DTECT = .TRUE.'
            IF(PSUB(CCELL(NDIV)).EQ.SW) THEN
               CCELL(NDIV)=SUBADD(2,PADD(CCELL(NDIV)))
            ELSE IF(PSUB(CCELL(NDIV)).EQ.SE) THEN
               CCELL(NDIV)=SUBADD(3,PADD(CCELL(NDIV)))
            ELSE IF(PSUB(CCELL(NDIV)).EQ.NW) THEN
               CCELL(NDIV)=SUBADD(4,PADD(CCELL(NDIV)))
            ELSE IF(PSUB(CCELL(NDIV)).EQ.NE) THEN
C               DONE WITH ALL SUBCELLS OF THE IMMEDIATEPARENT.
               NDIV=NDIV-1
C               IS THE UNIT CELL FINISHED?
               IF(NDIV.EQ.1) GO TO 300
C               GET NEXT CELL OF CURRENT LEVEL.
               GO TO 160
            ENDIF
C
            GO TO 150
C
C
C DONE WITH DATA ACQUISITION.
300         CONTINUE
            ITOTJ=ITOTJ+TPOINT-1
            KK=0
C
C DO NEXTPCRIMARY CELL.
            Call Output(Tpoint)
12345    CONTINUE
C GET NEXT THERMAL CONFIGURATION
2345  CONTINUE
C
      WRITE(10,3533) ITOTJ
3533  FORMAT(1X,'NUMBER OF TRAJS. TOTAL = ',I6)
      WRITE(10,3534) NONRES
3534  FORMAT(1X, 'NUMBER OF UNSATISFACTORY CELLS =',I6)
      WRITE(10,9001) (1.*NONRES)/(1.*NUMCEL)
9001  FORMAT(1X,'FRACTION OF CELLS UNSATISFACTORY = ',F12.6)
      WRITE(10,3535) AMISS
3535  FORMAT(1X,'FRACTION OF UNIT CELL UNSATIS. = ',D14.8)
      IF(ATOT.GT.0.0D0) THEN
         WRITE(10,3536) AMISS/ATOT
3536     FORMAT(1X,'FRACTION OF DETECTED WEIGHT UNSATIS. = ',D14.8)
C COMPUTE ENERGY AND ANGLE AVERAGES
         WRITE(10,3537) (EAV+AMULT*ESIZE)/ATOT
3537     FORMAT(1X,'ENERGY ERROR AVERAGE = ',D14.8)
         WRITE(10,3538) (AAV+AMULT*ASIZE)/ATOT
3538     FORMAT(1X,'ANGLE ERROR AVERAGE = ',D14.8)
         WRITE(10,*) 'TOTAL DETECTED WEIGHT = ',ATOT
      ELSE
         WRITE(10,*) 'ATOT= 0.0D0 !!!'
      ENDIF
C
      WRITE(10,7334) EDIF,ADIF
7334  FORMAT(1X,'MAX EDIF = ',F12.6,' MAX ADIF = ',F12.6)

*     Conclude Timer
      TIMER=dtime(tarray)
      write(10,9101) tarray(1)
      write(10,9102) tarray(2)

      close(13)
      close(9)
      close(10)
      close(66)
      STOP

777   CONTINUE
*     Conclude Timer
      timer=dtime(tarray)

*     Write to the param file.
      write(10,5533) numcha
      write(10,9101) tarray(1)
      write(10,9102) tarray(2)
      write(10,9103) 1000. * tarray(1)/numcha

5533  format(1X,'NUMBER OF TRAJS. TOTAL = ',i6)
9101  format(1x,'CPU time = ',f16.4,' secs')
9102  format(1x,'System paging time = ',f16.4,' secs')
9103  format(1x,'CPU time Per Particle= ',f16.4,' ms')
      close(13)
      close(9)
      close(10)
      close(66)
      if(PLOT.NE.0) then
        close(PLOT)
      endif

      stop

C
C
C
C667   CONTINUE
C      WRITE(6,6020) TPOINT
C6020  FORMAT('???? ERROR OPENING FILE SFDUMP ON RESTART????'/
C     1   '     TPOINT IS ',I6)
C      STOP
C
C668   CONTINUE
C      WRITE(6,6025)
C      WRITE(10,6025)
C6025  FORMAT('???? ERROR OPENING FILE SFDUMP FOR WRITING????')
C      STOP
C
6666  CONTINUE
      WRITE(0,6002) NARRAY
      WRITE(10,6002) NARRAY
6002  FORMAT(' ??',I6,' TRAJECTORIES COMPUTED. ARRAYS TOO SMALL??')
      CALL OUTPUT(TPOINT)
      STOP
C
6667  CONTINUE
      WRITE(0,6003) NARRAY
      WRITE(10,6003) NARRAY
6003  FORMAT('???? ',I6,' CELLS USED. ARRAYS TOO SMALL. ????')
      CALL OUTPUT(TPOINT)
      STOP
      END
