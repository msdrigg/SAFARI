C
C***********************************************************************
C
      SUBROUTINE SCATTR(X,Y,Z,PX,PY,PZ,E,TH,PH,PX3,PY3,PZ3,NPART,II)
C
C SUBROUTINE TO CALL SUBROUTINE SCAT.
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
      REAL*8 MASS(10),MION
      REAL*8 MASS1(10),MION1
      REAL*4 E,TH,PH,PX3,PY3,PZ3
      LOGICAL Image
      INTEGER TYPEAT(100)
      LOGICAL STUCK,BURIED
C
      COMMON/FLAGS/STUCK,BURIED
      COMMON/MASS/MASS,MION,TYPEAT
      COMMON/MINV/MASS1,MION1
      COMMON/IMAGE/IMAGE
      COMMON/UTILTY/DZERO, XNULL(4), PI
C
C
      CALL SCAT(X,Y,Z,PX,PY,PZ,Z2,PX2,PY2,PZ2,NPART,II)
C
C
      IF(STUCK.OR.BURIED) THEN
         if(stuck) e=-100.0
         if(buried) e=-200.0
         TH=0.
         ph=90.0
         go to 22
      ELSE
C          FIND MOMENTUM AT Z = INFINITY.
C
C ASSUME THE USER WANTS AN IMAGE ON THE WAY OUT
C SO COMMENT OUT THE IF STATEMENT

C         IF(IMAGE) THEN
            PP=PZ2*PZ2+2.0D0*MION*VIM(0.0D0,0.0D0,Z2)
            if(pp.lt.0.0d0) then
               pzz=-dsqrt(-pp)
            else
               pzz=dsqrt(pp)
            endif
C         ELSE
C            PP=PZ2*PZ2
C            pzz=pz2
C         ENDIF
         IF(pzz .LE. 0.0D0) THEN
C                   ION DOESN'T HAVE ESCAPE VELOCITY.
C           WRITE(6,4100)
C4100       FORMAT(' NE')
            E=-10.0
            TH=0.
            PH=90.
            go to 22
         ELSE
C             PSQR IS THE TOTAL MOMENTUM SQUARED AT INFINITY.
            PSQR=PP+PX2*PX2+PY2*PY2
C           WRITE(6,4200)
C4200       FORMAT(' E')
C             PZZ IS THE Z MOMENTUM AT INFINITY.
c           PZZ=DSQRT(PP)
c           IF(PZ2.LT.0.0D0) PZZ=-DSQRT(PP)
            E=PSQR*MION1*.5D0
C           WRITE(40,*) E
            TH=DACOS(PZZ/DSQRT(PSQR))*180.0D0/PI
            if(px2.eq.0.0d0 .and. py2.eq.0.0d0) THEN
               PH=90.0D0
            else
               PH=DATAN2(PY2,PX2)*180.D0/PI
            endif
         ENDIF
      ENDIF

22    PX3=PX2
      PY3=PY2
      PZ3=pzz
c     WRITE(6,7000) X,Y,E,TH,PH
C7000  FORMAT(F8.3,3X,F8.3,4X,3(E10.4,2X))
      RETURN
      END
C
C***********************************************************************
C
C
      INTEGER FUNCTION SEARCH(EDGE,START,PSUB,PADDR,SUBADD)
C
C SEARCH RETURNS THE ADDRESS OF THE EDGE NEIGHBOR OF THE CURRENT CELL
C (START). EDGE IS EITHER N (8), S (4), E (2), OR W (1). IF THE
C NEIGHBOR DOES NOT EXIST, SEARCH RETURNS 0.
C
C NEIGHBORING CELLS OF THE SAME SIZE EITHER HAVE A COMMON PARENT OR
C NEIGHBORING PARENTS, SO THEY MUST HAVE A COMMON ANCESTOR SOMEWHERE.
C FURTHERMORE, IF THE CELL BEING SOUGHT IS TO THE WEST, FOR EXAMPLE,
C THEN ALL ANCESTORS OF THE ORIGINAL CELL (INCLUDING THE ORIGINAL CELL
C AND EXCLUDING THE COMMON ANCESTOR AND ITS IMMEDIATE DESCENDENT) MUST
C BE EASTERN SUBCELLS. THINK ABOUT IT. THE HEREDITARY LINE BETWEEN
C THE CURRENT CELL AND THE COMMON ANCESTOR IS STORED IN PATH. PATH IS
C THEN REFLECTED AROUND THE NS AXIS IF EDGE IS E OR W (AND V.V.) AND
C FOLLOWED BACK DOWN TO FIND THE NEIGHBOR. IF THIS IS NOT POSSIBLE, THE
C NEIGHBOR DOES NOT EXIST.
C
      PARAMETER ( NARRAY=100000 )
      IMPLICIT INTEGER (A-Z)
      INTEGER PATH(10),EDGE,STEPS
      INTEGER PARENT,ANCEST,CHILD,MASK
      INTEGER START
      INTEGER PSUB(NARRAY),PADDR(NARRAY),SUBADD(4,NARRAY)
      INTEGER SW,SE,NW,NE
      LOGICAL PBC
      COMMON/PBC/PBC,NWRITX,NWRITY
C
      DATA SW,SE,NW,NE/5,6,9,10/
C
      STEPS=0
      PARENT=START
C              CURRENT CELL IS ITS OWN 0TH PARENT, IN SOME SENSE.
C
      IF(PARENT.EQ.1) THEN
C            THE ORIGINAL SURFACE CELL HAS NO NEIGHBORS.
         SEARCH=0
         RETURN
      ENDIF
C
C FIND THE PATH TO THE CHILD OF THE COMMON ANCESTOR.
10    CONTINUE
      IF(IAND(PSUB(PARENT),EDGE).NE.0) THEN
C            THIS PARENT IS NOT THE CHILD OF THE COMMON ANCESTOR.
         STEPS=STEPS+1
         PATH(STEPS)=PSUB(PARENT)
         PARENT=PADDR(PARENT)
         GO TO 10
      ENDIF
C
C FIND THE COMMON ANCESTOR.
      IF(PARENT.NE.1) THEN
C              PARENT IS THE SON OF THE COMMON ANCESTOR.
         STEPS=STEPS+1
         PATH(STEPS)=PSUB(PARENT)
         ANCEST=PADDR(PARENT)
      ELSE
C               PARENT IS THE ORIGINAL UNIT CELL, AND IS THE COMMON ANCE
C               THE REQUIRED TRAJECTORY IS ON THE EDGE OF THE UNIT CELL.
C               THERE ARE NO PERIODIC BOUNDARY CONDITIONS, THE SEARCH FA
         IF(PBC) THEN
            ANCEST=1
         ELSE
            SEARCH=0
            RETURN
         ENDIF
      ENDIF
C
C
C CHANGE PATH SO THAT IT LEADS FROM COMMON ANCESTOR TO NEIGHBOR.
C THE SET BITS OF MASK INDICATE WHICH BITS OF PATH ARE NOT TO BE REVERSE
      IF(EDGE.LE.2) THEN
C          E OR W. MASK = 1100.
         MASK=12
      ELSE
C          N OR S. MASK = 0011.
         MASK=3
      ENDIF
      DO 20 I=1,STEPS
         PATH(I)=IAND(NOT(IEOR(PATH(I),MASK)),15)
20    CONTINUE
C
C FOLLOW THE REVISED PATH IN REVERSE.
C SUBADD GIVES THE ADDRESS OF A PARTICULAR SUBCELL. IF THERE ARE NO
C SUBCELLS, SUBADD IS ZERO.
      CHILD=ANCEST
30    CONTINUE
      IF(PATH(STEPS).EQ.SW) THEN
         CHILD=SUBADD(1,CHILD)
      ELSE IF(PATH(STEPS).EQ.SE) THEN
         CHILD=SUBADD(2,CHILD)
      ELSE IF(PATH(STEPS).EQ.NW) THEN
         CHILD=SUBADD(3,CHILD)
      ELSE IF(PATH(STEPS).EQ.NE) THEN
         CHILD=SUBADD(4,CHILD)
      ENDIF
      STEPS=STEPS-1
      IF(STEPS.EQ.0 .OR. CHILD.EQ.0) THEN
         SEARCH=CHILD
         RETURN
      ENDIF
      GO TO 30
      END
