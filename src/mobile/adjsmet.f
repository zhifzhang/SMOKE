
        SUBROUTINE ADJSMET( NSRCIN, NALL, NVALID, MINV_MIN, MINV_MAX, 
     &                      MAXV_MIN, MAXV_MAX, VINTRVL, MXINTRVL, DESC, 
     &                      VALIDALL, VALIDMIN, VALIDMAX, MINBYSRC, 
     &                      MAXBYSRC, METIDX )

C***********************************************************************
C  subroutine ADJSMET body starts at line 121
C
C  DESCRIPTION:
C      Round values to interval and compute index for min/max
C
C  PRECONDITIONS REQUIRED:
C      The min/max criteria and the values by source should be in the same 
C      units.
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION HISTORY:
C
C***************************************************************************
C 
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C 
C COPYRIGHT (C) 2000, MCNC--North Carolina Supercomputing Center
C All Rights Reserved
C 
C See file COPYRIGHT for conditions of use.
C 
C Environmental Programs Group
C MCNC--North Carolina Supercomputing Center
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C env_progs@mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C****************************************************************************

C...........   MODULES for public variables
C...........   This module is the source inventory arrays
        USE MODSOURC

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters

C...........   EXTERNAL FUNCTIONS 
        CHARACTER*2  CRLF
        INTEGER      FINDR1
        INTEGER      FINDR2
        INTEGER      STR2INT

        EXTERNAL     CRLF, FINDR1, FINDR2, STR2INT

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT    (IN) :: NSRCIN              ! no. sources
        INTEGER     , INTENT    (IN) :: NALL                ! no. valid values
        INTEGER     , INTENT    (IN) :: NVALID              ! no. valid combos
        REAL        , INTENT    (IN) :: MINV_MIN            ! min of minimum vals
        REAL        , INTENT    (IN) :: MINV_MAX            ! max of minimum vals
        REAL        , INTENT    (IN) :: MAXV_MIN            ! min of maximum vals
        REAL        , INTENT    (IN) :: MAXV_MAX            ! max of maximum vals
        REAL        , INTENT    (IN) :: VINTRVL             ! interval for vals
        REAL        , INTENT    (IN) :: MXINTRVL            ! max allowed interval
        CHARACTER(*), INTENT    (IN) :: DESC                ! data description
        REAL        , INTENT    (IN) :: VALIDALL( NALL   )  ! values table
        REAL        , INTENT    (IN) :: VALIDMIN( NVALID )  ! min/max table
        REAL        , INTENT    (IN) :: VALIDMAX( NVALID )  ! min/max table
        REAL        , INTENT(IN OUT) :: MINBYSRC( NSRCIN,4 )! min values
        REAL        , INTENT(IN OUT) :: MAXBYSRC( NSRCIN,4 )! max values
        INTEGER     , INTENT   (OUT) :: METIDX( NSRCIN,4 )  ! idx to valid min/max

C...........   Other local variables
        INTEGER       J, L, S      ! counters and indices

        INTEGER       FIP          ! tmp country/state/county code
        INTEGER       K( 4 )       ! values
        INTEGER       LFIP         ! previous country/state/county code
        INTEGER       LRWT         ! previous roadway type
        INTEGER       RWT          ! tmp roadway type
        INTEGER       T1, T2       ! tmp indices

        DOUBLE PRECISION :: MNVMN       ! tmp min variable min
        DOUBLE PRECISION :: MNVMX       ! tmp min variable max
        DOUBLE PRECISION :: MXVMN       ! tmp max variable min
        DOUBLE PRECISION :: MXVMX       ! tmp max variable max
        DOUBLE PRECISION :: VMXIT       ! tmp max interval
        DOUBLE PRECISION :: VINTV       ! tmp tmpr interval

        REAL          MSAV         ! saved minimum value
        REAL          VAL          ! tmp value
        REAL          VMAX         ! tmp max value
        REAL          VMAX2        ! tmp max value
        REAL          VMIN         ! tmp min value
        REAL          VMIN2        ! tmp min value
        REAL          VTMP         ! even more tmp value

        LOGICAL          CHKDIFF            ! true: tmpr diffs are equal
        LOGICAL, SAVE :: FIRSTIME = .TRUE.  ! true: first time routine called
        LOGICAL       :: EFLAG    = .FALSE. ! true: error found
        LOGICAL       :: RFLAG    = .FALSE. ! true: reporting okay

        CHARACTER*300 BUFFER        ! formatted source info for messages
        CHARACTER*300 MESG          ! message buffer
        CHARACTER(LEN=SRCLEN3) CSRC ! tmp concat source characteristics

        CHARACTER*16 :: PROGNAME = 'ADJSMET' ! program name

C***********************************************************************
C   begin body of subroutine ADJSMET

C.........  Initialize index for the first time routine is called.  It is
C           initialized because when sources are not inside the grid, the
C           value will never be set.  Since the sources inside the grid are
C           constant over time, this only needs to be done the first time
C           the routine is called
        IF( FIRSTIME ) THEN

            METIDX = 0  ! array
            FIRSTIME = .FALSE.

        END IF

C.........  Set double precision temperature variables for computing and
C           matching
        MNVMN = DBLE( MINV_MIN )
        MNVMX = DBLE( MINV_MAX )
        MXVMN = DBLE( MAXV_MIN )
        MXVMX = DBLE( MAXV_MAX )
        VINTV = DBLE(  VINTRVL )

C.........  Reduce VMXIT by one interval so that VMIN,VMAX2 combination will 
C           work when VMAX - VMIN is very close to VMXIT before adjustment.
        VMXIT = DBLE( MXINTRVL ) - VINTV
        
C.........  Loop through sources and process for minimum and maximum daily
C           values
        LFIP = 0
        LRWT = 0
        DO S = 1, NSRCIN

            CSRC = CSOURC( S )
            FIP = STR2INT( CSRC( SC_BEGP(1):SC_ENDP(1) ) )
            RWT = STR2INT( CSRC( SC_BEGP(2):SC_ENDP(2) ) )

            VAL = DBLE( MINBYSRC( S,1 ) )

C.............  Screen for missing values
            IF( VAL .LT. AMISS3 ) CYCLE

C..............  Set report flag
            RFLAG = ( FIP .NE. LFIP .OR. RWT .NE. LRWT )

C..............  Round min value DOWN to nearest on interval
            IF    ( VAL .LT. MNVMN ) THEN

                IF ( RFLAG ) THEN
                    CALL FMTCSRC( CSRC, 2, BUFFER, L )
                    WRITE( MESG, 94020 )
     &                 'Increasing minimum '  // DESC // ' from',
     &                 VAL, 'to', MINV_MIN, 'for source' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L ) // '.'
                    CALL M3MESG( MESG )
                END IF

                MINBYSRC( S,1 ) = MINV_MIN 
                VMIN          = MNVMN

C.............  Set to two steps *below* max, because we need one extra space
C               to allow for interpolation, and we need another extra space
C               because the MNVMX is not valid in the min/max temperature
C               combinations because of roundoff error.
C.............  Don't reset MINBYSRC since interpolation will permit value
C               to be at VMIN2.
            ELSEIF( VAL .GT. MNVMX - VINTV ) THEN

C.................  Set VMIN to 2 less than MNVMX - this works.
                VMIN = MNVMN + VINTV *
     &                 INT( ( MNVMX - MNVMN - VINTV ) / VINTV )

                VTMP = REAL( VMIN )
                MINBYSRC( S,1 ) = REAL( VMIN )

                IF ( RFLAG ) THEN
                    CALL FMTCSRC( CSRC, 2, BUFFER, L )
                    WRITE( MESG, 94020 )
     &                 'Decreasing minimum '  // DESC // ' from',
     &                 VAL, ' to', VTMP, 'for source' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L ) // '.'
                    CALL M3MESG( MESG )
                END IF

            ELSE 
                VMIN = REAL( MNVMN + VINTV *
     &                       INT( ( VAL - MNVMN ) / VINTV ) )

            END IF

C.............  Round max value to nearest on interval
            VAL = MAXBYSRC( S,1 )

            IF    ( VAL .LT. MXVMN ) THEN

                IF ( RFLAG ) THEN
                    CALL FMTCSRC( CSRC, 2, BUFFER, L )
                    WRITE( MESG, 94020 )
     &                 'Increasing maximum '  // DESC // ' from',
     &                 VAL, ' to', MAXV_MIN, 'for source' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L ) // '.'
                    CALL M3MESG( MESG )
                END IF

                MAXBYSRC( S,1 ) = MAXV_MIN
                VMAX = MXVMN

C.............  Set to one step *below* max, because we need the extra space
C               to allow for interpolation.  No need to reset MAXBYSRC, because
C               interpolation will permit maximum value at the maximum.
            ELSE IF( VAL .GT. MXVMX ) THEN

                IF ( RFLAG ) THEN
                    CALL FMTCSRC( CSRC, 2, BUFFER, L )
                    WRITE( MESG, 94020 )
     &                 'Decreasing maximum '  // DESC // ' from', 
     &                 VAL, 'to', MAXV_MAX, 'for source' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L ) // '.'

                    CALL M3MESG( MESG )
                END IF

                MAXBYSRC( S,1 ) = MAXV_MAX 
                VMAX = MXVMX - VINTV

C.............  Compute VMAX from basis of MXVMN to compute in same way as 
C               the valid temperature lists are computed.
            ELSE  
                VMAX   = REAL( MNVMN + VINTV *
     &                         INT( ( VAL - MNVMN ) / VINTV ) )

            END IF

C..............  Ensure relationship between TMIN and TMAX is valid
C..............  When difference greater than the maximum interval
C                set VMIN from VMAX, and adjust down on interval
C..............  Set VMIN to interval greater than needed to ensure
C                max interval relationship holds for all min/max tmpr combos
C..............  VMXIT has already be reduced by one interval so that VMIN,VMAX2
C                combination will work when VMAX - VMIN is very close to 
C                VMXIT before adjustment.
            IF( VMAX - VMIN .GE. VMXIT ) THEN
                MSAV = VMIN
                VMIN = VMAX - ( VMXIT - 1. )
                VMIN = MNVMN + VINTV *
     &                 INT( ( VMIN - MNVMN ) / VINTV )

                IF ( RFLAG ) THEN
                    CALL FMTCSRC( CSRC, 2, BUFFER, L )
                    WRITE( MESG, 94020 ) 'Max - min '//DESC// ' is > '//
     &                 'defined maximum interval', MXINTRVL, 'for' //
     &                 CRLF() // BLANK10 // BUFFER( 1:L ) // '.' //
     &                 CRLF() // BLANK10 // 
     &                 'Increasing min from', MSAV, 'to', VMIN
                    CALL M3MESG( MESG )
                END IF

C.................  Store new minimum value for source
                MINBYSRC( S,1 ) = VMIN

            END IF

C.............  If minimum and maximum different by less than or equal to 
C               the interval, need to avoid bad index numbers. So, set indices
C               to zero. Use logical expression to test for equality 
            CHKDIFF = ( ABS( VMAX - VMIN - VINTV ) .LE. 1.0E-4 )
            IF( VMAX - VMIN .LT. VINTV .OR. CHKDIFF ) THEN

                VMIN = MNVMN + VINTV *
     &                 INT( ( VMAX - VINTV - 1. - MNVMN ) / VINTV )


C.................  Write our message for new country/state/county code
                IF ( RFLAG ) THEN
                    CALL FMTCSRC( CSRC, 2, BUFFER, L )
                    WRITE( MESG, 94020 ) 'Max - min ' // DESC // 
     &                 ' is < the processing interval', VINTRVL, 'for'//
     &                 CRLF() // BLANK10 // BUFFER( 1:L ) // '.' //
     &                 CRLF() // BLANK10 // 'The minumum ' //
     &                 'interval will be used for current day.'
                    CALL M3MESG( MESG )
                END IF

C.................  If adjustment has moved minimum out of range, set it to
C                   minimum and reset maximum to have a range with no overlap
C                   with minimum range.
                IF( VMIN .LE. MINV_MIN ) THEN

                    VMIN = MINV_MIN

                    VMAX = REAL( MNVMN + VINTV *
     &                     INT(( MINV_MIN+ 2*VINTV +1. -MNVMN)/ VINTV ))
                    MAXBYSRC( S,1 ) = VMAX - VINTV + 1.0E-4

                END IF

C.................  Store new minimum value for source
                MINBYSRC( S,1 ) = VMIN

            END IF

C.............  Find min/max in valid list and store to index array for source

C.............  Find min/max value in valid list of temperatures in order
C               to be sure that the values will match with the min/max
C               combos list
                
            T1 = FINDR1( VMIN, NALL, VALIDALL )
            T2 = FINDR1( VMAX, NALL, VALIDALL )

            IF( T1 .LE. 0 .OR. T2 .LE. 0 ) THEN

                EFLAG = .TRUE.
                CALL FMTCSRC( CSRC, NCHARS, BUFFER, L )

                WRITE( MESG,94010 )
     &                     'INTERNAL ERROR: Min/Max temperature '//
     &                     'processing invalid for:' //
     &                     CRLF() // BLANK10 // BUFFER( 1:L )
                CALL M3MSG2( MESG )
                CYCLE

            END IF

            VMIN2 = VALIDALL( T1 + 1 )
            VMAX2 = VALIDALL( MIN( T2 + 1, NALL ) ) 

            K(1)= FINDR2( VMIN , VMAX , NVALID, VALIDMIN, VALIDMAX ) 
            K(2)= FINDR2( VMIN2, VMAX , NVALID, VALIDMIN, VALIDMAX )
            K(3)= FINDR2( VMIN , VMAX2, NVALID, VALIDMIN, VALIDMAX )
            K(4)= FINDR2( VMIN2, VMAX2, NVALID, VALIDMIN, VALIDMAX )

            IF( K( 1 ) .LE. 0 .OR. K( 2 ) .LE. 0 .OR.
     &          K( 3 ) .LE. 0 .OR. K( 4 ) .LE. 0      ) THEN

                EFLAG = .TRUE.
                CALL FMTCSRC( CSRC, NCHARS, BUFFER, L )

                WRITE( MESG,94010 )
     &                     'INTERNAL ERROR: Min/Max temperature '//
     &                     'processing invalid for:' //
     &                     CRLF() // BLANK10 // BUFFER( 1:L )
                CALL M3MSG2( MESG )
                CYCLE

            END IF

            METIDX( S,1:4 ) = K( 1:4 )   ! array

            LFIP = FIP
            LRWT = RWT

        END DO

        IF( EFLAG ) THEN

            MESG = 'Problem processing temperatures'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        END IF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I9, :, 1X ) )

94020   FORMAT( A, 4( 1X, F8.2, 1X, A ) )
 
        END SUBROUTINE ADJSMET