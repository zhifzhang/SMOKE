
        SUBROUTINE RDDATANTIPT( LINE, READDATA, READPOL, IYEAR, DESC,
     &                          ERPTYP, SRCTYP, HT, DM, TK, FL, VL, SIC, 
     &                          MACT, NAICS, CTYPE, LAT, LON, UTMZ, 
     &                          HDRFLAG, EFLAG )

C***********************************************************************
C  subroutine body starts at line 156
C
C  DESCRIPTION:
C      This subroutine processes a line from an NTI format point-source inventory
C      file and returns the inventory data values.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C      Created by C. Seppanen (01/03) based on rddataidapt.f
C
C**************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2002, MCNC Environmental Modeling Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Modeling Center
C MCNC
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C smoke@emc.mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C...........   MODULES for public variables
C.........  This module contains the information about the source category
        USE MODINFO, ONLY: NEM, NDY, NEF, NCE, NRE, NC1, NC2

        IMPLICIT NONE

C...........   INCLUDES
         INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2            CRLF
        INTEGER                FINDC
        
        EXTERNAL   CRLF, FINDC

C...........   SUBROUTINE ARGUMENTS
        CHARACTER(LEN=*),       INTENT  (IN) :: LINE                  ! input line
        CHARACTER(LEN=*),       INTENT (OUT) :: READDATA( 1,NPTPPOL3 )! array of data values
        CHARACTER(LEN=IOVLEN3), INTENT (OUT) :: READPOL( 1 )          ! array of pollutant names
        INTEGER,                INTENT (OUT) :: IYEAR                 ! inventory year
        CHARACTER(LEN=40),      INTENT (OUT) :: DESC                  ! plant description
        CHARACTER(LEN=ERPLEN3), INTENT (OUT) :: ERPTYP                ! emissions release point type
        CHARACTER(LEN=STPLEN3), INTENT (OUT) :: SRCTYP                ! source type code
        CHARACTER(LEN=4),       INTENT (OUT) :: HT                    ! stack height
        CHARACTER(LEN=6),       INTENT (OUT) :: DM                    ! stack diameter
        CHARACTER(LEN=4),       INTENT (OUT) :: TK                    ! exit temperature
        CHARACTER(LEN=10),      INTENT (OUT) :: FL                    ! flow rate
        CHARACTER(LEN=9),       INTENT (OUT) :: VL                    ! exit velocity
        CHARACTER(LEN=SICLEN3), INTENT (OUT) :: SIC                   ! SIC
        CHARACTER(LEN=MACLEN3), INTENT (OUT) :: MACT                  ! MACT code
        CHARACTER(LEN=NAILEN3), INTENT (OUT) :: NAICS                 ! NAICS code
        CHARACTER(LEN=1),       INTENT (OUT) :: CTYPE                 ! coordinate type
        CHARACTER(LEN=9),       INTENT (OUT) :: LAT                   ! stack latitude
        CHARACTER(LEN=9),       INTENT (OUT) :: LON                   ! stack longitude
        CHARACTER(LEN=2),       INTENT (OUT) :: UTMZ                  ! UTM zone
        LOGICAL,                INTENT (OUT) :: HDRFLAG               ! true: line is a header line
        LOGICAL,                INTENT (OUT) :: EFLAG                 ! error flag

C...........   Local parameters, indpendent
        INTEGER, PARAMETER :: MXPOLFIL = 60  ! arbitrary maximum pollutants in file
        INTEGER, PARAMETER :: NSEG = 28      ! number of segments in line

C...........   Other local variables
        INTEGER         I       ! counters and indices

        INTEGER, SAVE:: ICC     !  position of CNTRY in CTRYNAM
        INTEGER, SAVE:: INY     !  inventory year
        INTEGER         IOS     !  i/o status
        INTEGER, SAVE:: NPOL    !  number of pollutants in file

        LOGICAL, SAVE:: FIRSTIME = .TRUE. ! true: first time routine is called
 
        CHARACTER(LEN=40)      SEGMENT( NSEG ) ! segments of line
        CHARACTER(LEN=CASLEN3) TCAS            ! tmp cas number
        CHARACTER(LEN=300)     MESG            ! message buffer

        CHARACTER*16 :: PROGNAME = 'RDDATANTIPT' ! Program name

C***********************************************************************
C   begin body of subroutine RDDATANTIPT

C.........  Scan for header lines and check to ensure all are set 
C           properly
        CALL GETHDR( MXPOLFIL, .TRUE., .TRUE., .FALSE., 
     &               LINE, ICC, INY, NPOL, IOS )

C.........  Interpret error status
        IF( IOS == 4 ) THEN
            WRITE( MESG,94010 ) 
     &             'Maximum allowed data variables ' //
     &             '(MXPOLFIL=', MXPOLFIL, CRLF() // BLANK10 //
     &             ') exceeded in input file'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ELSE IF( IOS > 0 ) THEN
            EFLAG = .TRUE.

        END IF

C.........  If a header line was encountered, set flag and return
        IF( IOS >= 0 ) THEN
            HDRFLAG = .TRUE.
            IYEAR = INY
            RETURN
        ELSE
            HDRFLAG = .FALSE.
        END IF

C.........  Separate line into segments
        CALL PARSLINE( LINE, NSEG, SEGMENT )

C.........  Use the file format definition to parse the line into
C           the various data fields
        DESC   = ADJUSTL( SEGMENT( 6 ) )   ! plant description
        ERPTYP = ADJUSTL( SEGMENT( 8 ) )   ! emissions release point type 
        SRCTYP = ADJUSTL( SEGMENT( 9 ) )   ! source type code    
        HT     = SEGMENT( 10 )             ! stack height
        DM     = SEGMENT( 11 )             ! stack diameter
        TK     = SEGMENT( 12 )             ! exit temperature
        FL     = SEGMENT( 13 )             ! flow rate
        VL     = SEGMENT( 14 )             ! exit velocity
        SIC    = SEGMENT( 15 )             ! SIC
        MACT   = ADJUSTL( SEGMENT( 16 ) )  ! MACT code
        NAICS  = ADJUSTL( SEGMENT( 17 ) )  ! NAICS code
        CTYPE  = ADJUSTL( SEGMENT( 18 ) )  ! coordinate type
        LAT    = SEGMENT( 19 )             ! stack latitude
        LON    = SEGMENT( 20 )             ! stack longitude
        UTMZ   = ADJUSTL( SEGMENT( 21 ) )  ! UTM zone

        READPOL ( 1     ) = SEGMENT( 22 )
        READDATA( 1,NEM ) = SEGMENT( 23 ) ! annual emissions
        READDATA( 1,NDY ) = SEGMENT( 24 ) ! average-day emissions
        READDATA( 1,NEF ) = ' '           ! emission factor
        READDATA( 1,NCE ) = SEGMENT( 25 ) ! control efficiency
        READDATA( 1,NRE ) = SEGMENT( 26 ) ! rule effectiveness
        READDATA( 1,NC1 ) = SEGMENT( 27 ) ! primary control equipment code
        READDATA( 1,NC2 ) = SEGMENT( 28 ) ! secondary control equipment code
            
C.........  Make sure routine knows it's been called already
        FIRSTIME = .FALSE.

C.........  Return from subroutine 
        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94120   FORMAT( I6.6 )

94125   FORMAT( I5 )

        END SUBROUTINE RDDATANTIPT