      LOGICAL FUNCTION RDATA(NARRAY,TPOINT,XTRAJ,YTRAJ,ztraj,
     &                  ENRGY,THETA,PHI,AREA,LEVEL,LUNIT)
C
C READ DATA FROM DATA FILE.
C
      REAL*4 ENRGY(NARRAY),THETA(NARRAY),PHI(NARRAY),AREA(NARRAY)
      REAL*4 XTRAJ(NARRAY),YTRAJ(NARRAY),ztraj(narray)
      REAL*8 EMIN,EMAX,ESIZE,ASIZE,DPARAM(10)
      INTEGER LEVEL(NARRAY)
      INTEGER TPOINT,NPTS
      LOGICAL FACC
C
      COMMON/RESOLV/EMIN,EMAX,ESIZE,ASIZE
      COMMON/DPARAM/DPARAM,NDTECT
      COMMON/FACC/FACC
C
      TPOINT=0
      IF(FACC) THEN
C     FIRST TIME THROUGH.  GET DETECTOR PARAMETERS
         READ(LUNIT) EMIN,EMAX,ESIZE,ASIZE
         READ(LUNIT) NDTECT
         READ(LUNIT) (DPARAM(I),I=1,5)
         READ(LUNIT) (DPARAM(I),I=6,10)
         FACC=.FALSE.
         Rdata=.true.
         RETURN
      ENDIF
C
      READ(LUNIT,END=1000) NPTS
      IF(NPTS.GT.NARRAY) THEN
         WRITE(0,*) ' NOT ENOUGH ROOM FOR ',NPTS,' MORE TRAJECTORIES.'
         GOTO 1000
      ENDIF
      DO 10 NREAD = 1, NPTS
         READ(LUNIT,ERR=888,END=777) XTRAJ(NREAD), YTRAJ(NREAD),
     &           LEVEL(NREAD)
         READ(lunit,err=888,end=777) ztraj(NREAD)
         READ(LUNIT,ERR=888,END=777) ENRGY(NREAD), THETA(NREAD),
     &           PHI(NREAD), AREA(NREAD)
10    CONTINUE
      TPOINT=NPTS
C
C
      RDATA=.TRUE.
      RETURN
C
1000  RDATA=.FALSE.
      RETURN
C
C
777   CONTINUE
      WRITE(0,7777) NREAD
7777  FORMAT(' **** WARNING **** EOF ENCOUNTERED AFTER READING ',
     &                                  I6,' TRAJECTORIES.')
      GOTO 1000
C
888   CONTINUE
      WRITE(0,8888) NREAD
8888  FORMAT(' **** ERROR AT TRAJECTORY ',I6,' ****')
      GOTO 1000
C
      END
