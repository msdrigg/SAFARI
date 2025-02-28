      SUBROUTINE SCAT(X0,Y0,Z0,PX0,PY0,PZ0,Z2,PX2,PY2,PZ2,NPART,IIII)
c modified to use bigger set of cells
C CAN COMPUTE TRAJECTORIES AT FINITE SURFACE TEMPERATURE
C THERMAL EFFECTS REQUIRE THAT NITER BE GREATER THAN 1
C
C
C THIS VERSION INCLUDES ATOM-LATTICE SPRINGS.
C
C
C SUBROUTINE SCAT TAKES THE INITIAL COORDINATES (X0 Y0 Z0) OF
C AN ION, SCATTERS IT FROM THE SURFACE (INTERACTING WITH NPART
C ATOMS AT ONCE AND USING TIME STEP DELT), AND RETURNS THE ION'S
C FINAL ANGLES (PHI AND THETA) AND ENERGY E. THE INITIAL ANGLES
C AND ION ENERGY ARE TRANSMITTED IN COMMON/BEAM/.
C
C  METHOD:
C     1. FIND OUT WHICH SURFACE CELL THE ION IS ABOVE.
C        THE 'LOCAL REGION' OF THE SURFACE CONSISTS OF
C        THIS CELL AND THE EIGHT NEIGHBORING CELLS.
C        (INFORMATION ON CELL SIZE AND THE POSITION AND TYPE OF
C        THE BASIS ATOMS IS CONTAINED IN COMMON/XTAL/.)
C     2. CREATE ARRAYS OF POSITION AND MOMENTUM FOR THE
C        ATOMS IN THE LOCAL REGION. THESE ARRAYS ARE ONE
C        DIMENSIONAL; THEY ARE FILLED BY LOOPING THROUGH
C        THE BASIS IN ONE CELL, THEN LOOPING THROUGH THE CELLS.
C        THE LOOP THROUGH CELLS IS IN THE FOLLOWING ORDER:
C
C           Y ^     7 | 8 | 9
C             |    ------------
C             |     4 | 5 | 6
C             |    ------------
C                   1 | 2 | 3
C                  ------------
C                           ----> X
C
C       THE ION IS OVER CELL 5.
C
C     3. MAKE A LIST OF THE NPART ATOMS THAT ARE CLOSEST TO THE
C        ION. STORE THE POSITIONS, MOMENTA, AND TYPE OF THESE
C        ATOMS IN XAT AND PAT. ARRAY NEAR REMEMBERS WHERE IN
C        XLOC EACH ATOM IN XAT CAME FROM -- XAT(J,I) IS THE SAME AS
C        XLOC(J,NEAR(I)).
C        THE FIRST SUBSCRIPT OF XAT,PAT,AND XLOC REPRESENTS THE
C        COORDINATE AXIS, THE SECOND REFERS TO THE SPECIFIC ATOM.
C     4. SEND THE COORDINATES AND MOMENTA OF THE NPART NEAREST ATOMS
C        TO TRAJ, WHICH INTEGRATES THE EQUATIONS OF MOTION FOR
C        THE ATOMS AND THE ION OVER MANY TIME STEPS DELT. THE NEW
C        VALUES OF THE POSITIONS AND MOMENTA ARE STORED IN XAT1, ETC.
C        INTEGRATE UNTIL THE ION HAS MOVED A DISTANCE XDIST IN THE
C        X DIRECTION, OR YDIST IN Y, OR ZDIST IN Z.
C     6. IF THE ION HAS RISEN AGAIN TO ITS ORIGINAL HEIGHT Z0, THEN
C        THE ROUTINE IS FINISHED. COMPUTE THE FINAL ANGLES AND ENERGY,
C        AND EXIT.
C     6A. IF THE ION HAS PENETRATED THE SURFACE TO A DEPTH -Z0, THEN
C        GIVE IT UP FOR LOST. EXIT.
C     7. UPDATE THE ARRAYS OF POSITIONS AND MOMENTA IN THE LOCAL
C        REGION.
C     8. IS THE ION STILL OVER THE SAME CELL? IF IT IS, THEN THE
C        LOCAL REGION HAS NOT CHANGED. GO TO STEP 3 TO FIND OUT
C        WHICH NPART ATOMS ARE NOW CLOSEST TO THE ION.
C     9. IF THE ION IS OVER A NEW CELL OF THE SURFACE, THEN THE
C        LOCAL REGION MUST BE MODIFIED.
C        SOME CELLS OF THE OLD LOCAL REGION WILL BE IN THE NEW REGION,
C        AND THE POSITIONS AND MOMENTA OF THE ATOMS IN THESE CELLS
C        WILL GENERALLY NOT HAVE THEIR INITIAL VALUES.
C        THEREFORE, TO AVOID LOSING INFORMATION THESE POSITIONS
C        AND MOMENTA MUST BE RELOCATED
C        TO THE REGISTERS IN XLOC ET AL. CORRESPONDING TO THEIR NEW
C        COORDINATES WITHIN THE LOCAL REGION. SOME CELLS OF THE
C        NEW LOCAL REGION WILL NOT HAVE BEEN PART OF THE OLD, SO
C        THE CORRESPONDING REGISTERS IN XLOC, ET AL. MUST BE FILLED
C        WITH INITIAL VALUES.
C        -- THE NEW CENTRAL CELL HAS COORDINATES (NSX,NSY) RELATIVE
C           TO THE OLD CENTRAL CELL. (NSX,NSY = -1,0,1.)
C        -- THE NUMBER OF SPACES EACH ELEMENT OF XLOC, ET AL. MUST
C           BE MOVED IS GIVEN BY MOVE = (NSX + 3*NSY) * NBASIS.
C           THIS IS A CONSEQUENCE OF THE METHOD OF NUMBERING THE
C           CELLS AND OF LOADING XLOC, ET AL. NBASIS IS THE NUMBER OF
C           ATOMS PER CELL.
C        -- NOTICE THAT IF NSX = 1 (-1) THEN THE RIGHT (LEFT)
C           COLUMN OF CELLS WILL BE NEW CELLS.
C       AFTER ADJUSTING THE LOCAL REGION, GO TO STEP 3.
C
C VARIABLES:
C
      IMPLICIT REAL*8 (A-H,O-Z)
      INCLUDE "params.txt"
      REAL*8 EMO
      REAL*8 X0,Y0,Z0,PX0,PY0,PZ0
C           INITIAL POSITION AND MOMENTUM OF ION.
      REAL*8 X(3),P(3)
C           CURRENT POSITION AND MOMENTUM OF ION.
      REAL*8 X1(3),P1(3)
C           NEXT POSITION AND MOMENTUM OF ION, RETURNED BY TRAJ.
C
      REAL*8 PX2,PY2,PZ2,Z2
C           FINAL MOMENTUM AND Z COORDINATE OF ION.
C
      REAL*8 MION
C           ION MASS.
C
C
      REAL*8 XAT(NPARTMAX,3),PAT(NPARTMAX,3)
      INTEGER TYPEAT(NPARTMAX)
C           POSITIONS, MOMENTA,AND TYPE OF ATOMS TO BE SENT TO TRAJ.
C
      REAL*8 XAT1(NPARTMAX,3),PAT1(NPARTMAX,3)
C           POSITIONS, MOMENTA,AND TYPE OF ATOMS RECEIVED FROM TRAJ.
C
      REAL*8 XLAT(NPARTMAX,3)
C               POSITIONS OF LATTICE POINTS ASSOCIATED WITH ATOMS IN XAT
C
      REAL*8 XLOC(3,NPARTMAX),PLOC(3,NPARTMAX)
      INTEGER TYPLOC(NPARTMAX)
C           POSITIONS, MOMENTA, AND TYPE OF ATOMS IN LOCAL REGION.
      REAL*8 XLCLAT(3,NPARTMAX)
C               LATTICE POSITIONS.
C
      INTEGER TYPBAS(NBASISMAX)
C           BASIS VECTORS AND TYPE OF ATOMS WITHIN ONE CELL.
C           ALL INFORMATION ABOUT MASS AND THE POTENTIAL OF THE
C           ATOM IS GIVEN BY THE VALUE OF TYPBAS. ROUTINES WHICH
C           CALCULATE POTENTIALS DUE TO AN ION LOOK AT THE ION
C           TYPE. THE ATOMIC MASSES ARE STORED IN MASS(TYPBAS()).
      REAL*8 MASS(NTYPEMAX)
C
      INTEGER NEAR(NPARTMAX)
C           SUBSCRIPTS IN XLOC, ET AL. OF ATOMS NEAREST TO ION.
      REAL*8 R(NPARTMAX)
C           SQUARED DISTANCES TO ION OF THE SAME ATOMS.
C
      INTEGER NXC,NYC
C           ABSOLUTE POSITION OF CENTRAL CELL, IN UNITS OF AX,AY.
      INTEGER NXC1,NYC1
C           ABSOLUTE POSITION OF NEW CENTRAL CELL.
C
      REAL*8 DELT0,DELT,DELMIN,DELLOW
C           TIME STEP SENT TO TRAJ, INITIALLY SET TO DELT0, BUT
C           MODIFIED IF NECESSARY.
C           THE LOWEST VALUE ACTUALLY USED IS DELMIN.
C           THE LOWEST VALUE ALLOWED IS DELLOW
      REAL*8 TIME
C           TOTAL TIME OF FLIGHT.
      REAL*8 XDIST,YDIST,ZDIST,DSURF
C           DISTANCE THAT ION MAY MOVE BEFORE SET OF LOCAL ATOMS IS
C               RECOMPUTED.
C               DSURF IS A CHARACTERISTIC SURFACE DISTANCE.
C
      REAL*8 DEMAX,DEMIN,ABSERR
C           MAXIMUM AND MINIMUM TOLERANCES FOR FRACTIONAL ENERGY
C           NONCONSERVATION, AND MAXIMUM ABSOLUTE ENERGY CHANGE
C           (USED ONLY NEAR ZERO ENERGY).
C
      INTEGER NSTEPS,NCALLS
C           NUMBER OF TIME STEPS USED, AND NUMBER OF CALLS TO TRAJ.
C
      LOGICAL STUCK,BURIED
C               IS THE ION STUCK OR BURIED?
      REAL*8 SENRGY,BDIST
C
      REAL*8 ztraj(narray)
*     This is the z-coordinates for the trajectory

      COMMON/NRG/DEMAX,DEMIN,ABSERR,DELLOW,DELT0
      COMMON/STATS/DELMIN,NCALLS,NSTEPS,TIME
      COMMON/FLAGS/STUCK,BURIED
      COMMON/XTAL/AX,AY,XBASIS(3,NBASISMAX),TYPBAS,NBASIS
      COMMON/MASS/MASS,MION,TYPEAT
      COMMON/RK/X,X1,P,P1,XAT,XAT1,PAT,PAT1
      COMMON/LAT/XLAT
      COMMON/CUTOFF/SENRGY,BDIST
C
      COMMON/RANDOM/SEED,NITER
      common/ztraj/ztraj
*     This is the lowest z that the projectile reached.
      common/depth/depth
      common/nat1/nat1
      depth=1.d22
C
C UNITS! DISTANCES ARE IN ANGSTROMS, ENERGIES IN EV, MASSES IN AMU.
C TIME IS IN ANGSTROMS*SQRT(AMU/EV).
C
C INITIALIZE.
      DELT=DELT0
      IF(DELLOW.NE.0.0D0) DELT=DELLOW
      DELMIN=DELT
      TIME=0.0D0
      DSURF=DSQRT(AX*AY/NBASIS/10.0D0)
      NSTEPS=0
      STUCK=.FALSE.
      BURIED=.FALSE.
C    ION COORDINATES.
      X(1)=X0
      X(2)=Y0
      X(3)=Z0
      P(1)=PX0
      P(2)=PY0
      P(3)=PZ0
      EMO=DMAX1(DABS(PX0),DABS(PY0))
      EMO=DMAX1(EMO,DABS(PZ0))

C WHICH CELL IS THE ION ABOVE?
      NXC=IDINT(X(1)/AX)
      NYC=IDINT(X(2)/AY)
C     UNFORTUNATELY, INT() TRUNCATES, RATHER THAN FINDING THE GREATEST I
      IF(X(1).LT.0.0D0) NXC=NXC-1
      IF(X(2).LT.0.0D0) NYC=NYC-1
C
C CREATE INITIAL LIST OF ATOMS IN THE LOCAL REGION.
C
      N=0
C     N IS THE NUMBER OF ATOMS IN THE LIST.
C     LOOP THROUGH CELLS IN THE REGION.
      XBIG=-1.D6
      XSMALL=1.D6
      YBIG=-1.D6
      YSMALL=1.D6
      DO 30 IY=-2,2
         YC=AY*(NYC+IY)
         DO 30 IX=-2,2
            XC=AX*(NXC+IX)
C           XC,YC ARE THE COORDINATES OF THE LOWER LEFT CORNER OF THE CE
C           LOOP THROUGH THE BASIS.
            DO 30 J=1,NBASIS
               N=N+1
               TYPLOC(N)=TYPBAS(J)
               XLOC(1,N)=XC+XBASIS(1,J)
               XLOC(2,N)=YC+XBASIS(2,J)
               XLOC(3,N)=XBASIS(3,J)
               XLCLAT(1,N)=XLOC(1,N)
               XLCLAT(2,N)=XLOC(2,N)
               XLCLAT(3,N)=XLOC(3,N)
               PLOC(1,N)=0.0D0
               PLOC(2,N)=0.0D0
               PLOC(3,N)=0.0D0
C GET ACTUAL THERMALLY DISTRIBUTED POSITIONS AND MOMENTA
               IF(NITER.NE.1) CALL THERM(SEED,XLCLAT(1,N),
     &                              XLOC(1,N),PLOC(1,N),TYPLOC(N))
C
30    CONTINUE
      NTOT=N
C
C
C NOW, START WORKING. FIND THE NPART CLOSEST ATOMS.
40    CONTINUE
C
      IF(NPART.NE.0) THEN
C
C        PUT A RIDICULOUSLY LARGE NUMBER IN R() SO THAT THE FIRST
C        ATOMS LOOKED AT WILL BE CONSIDERED TO BE CLOSE.
         DO 41 I=1,NPARTMAX
            R(I)=1.D+22
41       CONTINUE
         XMIN=1.D+22
         YMIN=1.D+22
         ZMIN=1.D+22
C
C        WILL LOOK FOR NN CLOSEST ATOMS, NN IS AT MOST NPARTMAX.
C        WILL ONLY USE NPART ATOMS UNLESS THE NEXT ATOM IS JUST A
         NN=NPART*2
         IF(NN.GT.NPARTMAX) NN=NPARTMAX
         IF(NN.GT.N) NN=N
C
C        LOOP THROUGH THE LOCAL ATOMS IN XLOC.
         DO 50 I=1,N
C           PUT ION-ATOM DISPLACEMENT IN TEMPORARY REGISTERS
            XT=XLOC(1,I)-X(1)
            YT=XLOC(2,I)-X(2)
            ZT=XLOC(3,I)-X(3)
C           FIND THE SQUARED DISTANCE RR TO THE ION.
            RR=XT*XT+YT*YT+ZT*ZT
C           LOOP THROUGH THE CLOSEST ATOMS ALREADY FOUND, AN
C           SEE IF THIS ONE IS CLOSER.
            DO 45 J=1,NN
               IF(RR.GE.R(J)) GO TO 45
C                   THE ATOM IS CLOSER THAN THE PREVIOUS JTH CLOSEST.
C                   IF IT IS NOT THE LAST IN THE LIST OF CLOSEST ATOMS,
C                   THEN THE LIST MUST BE SHIFTED.
               IF(J.EQ.NN) GO TO 43
C                   SHIFT THE LIST.
               DO 42 K=NN,J+1,-1
                  NEAR(K)=NEAR(K-1)
                  R(K)=R(K-1)
42             CONTINUE
43             CONTINUE
C              INSTALL THE ITH ATOM IN THE LIST AS THE NEW JTH CLOSES
               NEAR(J)=I
               R(J)=RR
C              GET THE NEXT ATOM IN THE LOCAL REGION.
               GO TO 50
45          CONTINUE
50       CONTINUE
c
         NPART1=NPART
52       CONTINUE
         IF(DABS(R(NPART1+1)-R(NPART)) .LE. .01D0*R(NPART)) THEN
            NPART1=NPART1+1
            IF(NPART1 .LT. NPARTMAX) GO TO 52
         ENDIF
C
C        MAKE THE LIST OF PARTICIPATING ATOMS (THE NPART CLOSEST)
C        SEND TO TRAJ.
         nat1=typloc(near(1))
         DO 60 J=1,NPART1
            DO 58 I=1,3
               XAT(J,I)=XLOC(I,NEAR(J))
               XLAT(J,I)=XLCLAT(I,NEAR(J))
               PAT(J,I)=PLOC(I,NEAR(J))
58          CONTINUE
            XT=DABS(XAT(J,1)-X(1))
            IF(XT.LT.XMIN) XMIN=XT
            YT=DABS(XAT(J,2)-X(2))
            IF(YT.LT.YMIN) YMIN=YT
            ZT=DABS(XAT(J,3)-X(3))
            IF(ZT.LT.ZMIN) ZMIN=ZT
            TYPEAT(J)=TYPLOC(NEAR(J))
60       CONTINUE
C
C        HOW FAR SHOULD THE ION MOVE IN ONE CALL TO TRAJ?
C        ONE THIRD OF THE DISTANCE TO THE CLOSEST ATOM.
C        IF THE CLOSEST ATOM IS TOO CLOSE, USE THE SECOND CLOSEST
         IF(NPART1.GT.1) THEN
            XDIST=XMIN/3.0D0
            YDIST=YMIN/3.0D0
            ZDIST=ZMIN/3.0D0
            IF(XDIST.LT.DSURF) XDIST=DSURF
            IF(YDIST.LT.DSURF) YDIST=DSURF
            IF(ZDIST.LT.DSURF) ZDIST=DSURF
         ELSE
            XDIST=DSURF
            YDIST=DSURF
            ZDIST=DSURF
         ENDIF
C
C
      ELSE
         NPART1=0
      ENDIF
C
      CALL TRAJ(DELT,XDIST,YDIST,ZDIST,NPART1,NPART)
C
      NCALLS=NCALLS+1
C
      IF(STUCK) GO TO 100
      IF(BURIED) GO TO 100
C               RETURN WITH CURRENT POSITION. ION ISN'T GOING ANYWHERE.
C HAS THE ION LEFT THE SURFACE?
      IF(X1(3).GT.Z0) GO TO 100
C
C UPDATE POSITIONS AND MOMENTA OF ATOMS INVOLVED IN THE SCATTERING.
      DO 65 I=1,3
         X(I)=X1(I)
         P(I)=P1(I)
65    CONTINUE
      DO 70 J=1,NPART1
         DO 70 I=1,3
            XLOC(I,NEAR(J))=XAT1(J,I)
            PLOC(I,NEAR(J))=PAT1(J,I)
70    CONTINUE
C
C WHICH CELL IS THE ION NOW OVER?
      NXC1=IDINT(X(1)/AX)
      NYC1=IDINT(X(2)/AY)
      IF(X(1).LT.0.0D0) NXC1=NXC1-1
      IF(X(2).LT.0.0D0) NYC1=NYC1-1
C
C IF ION IS OVER THE SAME CELL AS IT WAS BEFORE TRAJ WAS CALLED,
C FIND THE NPART NEAREST ATOMS AND CALL TRAJ AGAIN.
      IF(NXC.EQ.NXC1 .AND. NYC.EQ.NYC1) GO TO 40
C
C THE ION IS OVER A DIFFERENT CELL.
C
C
C GET RELATIVE SHIFT IN UNITS OF THE LATTICE SPACING.
C IF THE SHIFT IS GREATER THAN 1, SOMETHING IS WRONG.
      NSX=NXC1-NXC
      NSY=NYC1-NYC
      IF(IABS(NSX).GT.1 .OR. IABS(NSY).GT.1) GO TO 666
C CALCULATE HAW FAR ELEMENTS IN XLOC, ET AL. MUST BE SHIFTED.
      MOVE=(NSX+5*NSY)*NBASIS
C SHIFT THE ELEMENTS. THE ORDER IN WHICH THIS IS DONE DEPENDS ON THE
C DIRECTION IN WHICH THE CELLS ARE TO BE MOVED.
      MSIGN=1
      IF(MOVE.LT.0) MSIGN=-1
C LOOP THROUGH THE CELLS, GOING BACKWARDS IF MOVE<0.
      DO 90 IY=-2*MSIGN,2*MSIGN,MSIGN
         DO 90 IX=-2*MSIGN,2*MSIGN,MSIGN
C           FIND LOCATION IN XLOC, ET AL. OF THE FIRST ATOM IN THE CELL.
            INDEX0=((IX+2)+5*(IY+2))*NBASIS+1
C           FIND THE COORDINATES OF THE LOWER LEFT CORNER OF THE CELL.
            XC=AX*(NXC1+IX)
            YC=AY*(NYC1+IY)
C           IF THIS CELL WAS NOT IN THE OLD LOCAL REGION INITIALIZE
C           XLOC, ET AL; OTHERWISE SHIFT THE VALUES IN XLOC FROM THE
C           OLD CELL TO THE NEW. IF NSX = -2 THEN THE CELLS WITH
C           IX = -1 (THOSE ON THE LEFT HAND EDGE OF THE REGION) WILL
C           BE NEW TO THE REGION.
            IF(NSX*IX.EQ.2 .OR. NSY*IY.EQ.2) THEN
C                A VIRGIN CELL. PUT INITIAL VALUES IN XLOC, ET AL.
               DO 85 J=1,NBASIS
                  INDEX=INDEX0+J-1
                  TYPLOC(INDEX)=TYPBAS(J)
                  XLOC(1,INDEX)=XC+XBASIS(1,J)
                  XLOC(2,INDEX)=YC+XBASIS(2,J)
                  XLOC(3,INDEX)=XBASIS(3,J)
                  XLCLAT(1,INDEX)=XLOC(1,INDEX)
                  XLCLAT(2,INDEX)=XLOC(2,INDEX)
                  XLCLAT(3,INDEX)=XLOC(3,INDEX)
                  PLOC(1,INDEX)=0.0D0
                  PLOC(2,INDEX)=0.0D0
                  PLOC(3,INDEX)=0.0D0
                  IF(NITER.NE.1) CALL THERM(SEED,XLCLAT(1,INDEX),
     &                     XLOC(1,INDEX),PLOC(1,INDEX),TYPLOC(INDEX))
85             CONTINUE
            ELSE
C              A CELL FROM THE PREVIOUS LOCAL REGION.
               DO 87 J=1,NBASIS
                  INDEX=INDEX0+J-1
                  IDUM=TYPLOC(INDEX+MOVE)
                  TYPLOC(INDEX)=IDUM
                  DO 86 II=1,3
                     XDUM=XLOC(II,INDEX+MOVE)
                     XLOC(II,INDEX)=XDUM
                     XDUM=XLCLAT(II,INDEX+MOVE)
                     XLCLAT(II,INDEX)=XDUM
                     XDUM=PLOC(II,INDEX+MOVE)
                     PLOC(II,INDEX)=XDUM
86                CONTINUE
87             CONTINUE
            ENDIF
90    CONTINUE
C THE NEW LOCAL REGION IS NOW INSTALLED.
C FORGET THE OLD ONE AND CONTINUE SCATTERING.
      NXC=NXC1
      NYC=NYC1
      GO TO 40
C
C
C
C
C DONE!
C
100   CONTINUE
C
C     WRITE(6,*) ITOT
C
      Z2=X1(3)
      PX2=P1(1)
      PY2=P1(2)
      PZ2=P1(3)
      ztraj(iiii)=depth
      RETURN
C
C
C ERROR?
666   CONTINUE
C  DO WHATEVER IS CALLED FOR.
      WRITE(0,6666)
6666  FORMAT(' ???ERROR IN SCAT???')
      RETURN
      END
