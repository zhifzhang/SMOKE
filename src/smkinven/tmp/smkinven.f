
         PROGRAM SMKINVEN

C***********************************************************************
C  program body starts at line 167
C
C  DESCRIPTION:
C    The smkinven program reads the any source inventory in one of four
C    formats: EMS-95, EPS, IDA, and SMOKE list format.  It permits a flexible
C    definition of a point source, which depends on the inventory input
C    formats.  It allows any number of inventory pollutants, within the limit
C    of I/O API (this works out to only 15 pollutants per file).
C
C  PRECONDITIONS REQUIRED:
C    Set environment variables:
C      PROMPTFLAG:    If N, default inputs are used
C      RAW_SRC_CHECK: If Y, missing species disallowed
C      RAW_DUP_CHECK: If Y, duplicate sources disallowed
C      VELOC_RECALC:  If Y, recalculates velocity based on flow
C      WEST_HSPHERE:  If N, does not reset positive longitudes to negative
C    Input files:  
C      PTINV: ASCII point sources inventory
C      PSTK: Replacement stack parameters file
C      ZONES: Time zones files
C      SIPOLS: Master list of pollutant codes and names (in output order)
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C    Subroutines: I/O API subroutines, INITEM, CHECKMEM, RDTZONE, RDSIPOLS, 
C       RDPTINV, FMTCSRC, FIXSTK, WRPTSCC, WRPTREF, OPENPNTS, WPNTSCHR, 
C       WPNTSPOL
C    Functions: I/O API functions, GETFLINE, GETTZONE 
C
C  REVISION  HISTORY:
C    started 10/98 by M Houyoux as rawpoint.f from emspoint.F 4.3
C    smkinven changes started 4/98
C
C****************************************************************************
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
C***************************************************************************

C...........   MODULES for public variables
C...........   This module is the inventory arrays
        USE MODSOURC

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES:
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C...........   EXTERNAL FUNCTIONS and their descriptions:
        
        CHARACTER*2   CRLF
        INTEGER       ENVINT
        LOGICAL       ENVYN
        INTEGER       GETFLINE
        INTEGER       GETTZONE

        EXTERNAL      CRLF, ENVINT, ENVYN, GETFLINE, GETTZONE

C...........  LOCAL PARAMETERS and their descriptions:

        CHARACTER*50, PARAMETER :: SCCSW = '@(#)$Id$'

C.........  LOCAL VARIABLES and their descriptions:

C.........  Full list of inventory pollutants/activities (in output order)
        INTEGER                  :: MXIDAT = 0   ! Max no of inv pols & acvtys
        INTEGER     , ALLOCATABLE:: INVDCOD( : ) ! 5-digit pollutant/actvty code
        INTEGER     , ALLOCATABLE:: INVSTAT( : ) ! Status (<0 activity; >0 pol)
        CHARACTER(LEN=IOVLEN3), ALLOCATABLE:: INVDNAM( : ) ! Name of pollutant

C.........  Day-specific and hour-specific variable indices
        INTEGER         DEAIDX( MXVARS3 )
        INTEGER         HEAIDX( MXVARS3 )

C.........  Array that contains the names of the inventory variables needed for
C           this program
        CHARACTER(LEN=IOVLEN3) IVARNAMS( MXINVARR )

C.........  File units and logical/physical names

        INTEGER    :: DDEV = 0  !  unit no. for day-specific input file 
        INTEGER    :: EDEV = 0  !  unit no. for speeds file
        INTEGER    :: HDEV = 0  !  unit no. for hour-specific input file 
        INTEGER    :: IDEV = 0  !  unit no. for inventory file (various formats)
        INTEGER    :: LDEV = 0  !  unit no. for log file
        INTEGER    :: PDEV = 0  !  unit number for pollutants codes/names file
        INTEGER    :: RDEV = 0  !  unit no. for def stack pars or mobile codes
        INTEGER    :: SDEV = 0  !  unit no. for ASCII output inventory file
        INTEGER    :: VDEV = 0  !  unit no. for activity codes/names file
        INTEGER    :: XDEV = 0  !  unit no. for VMT mix file
        INTEGER    :: ZDEV = 0  !  unit no. for time zone file

        CHARACTER(LEN=NAMLEN3) :: ANAME = ' '! inven ASCII output logical name
        CHARACTER(LEN=NAMLEN3) :: DNAME = ' '! day-specific input logical name
        CHARACTER(LEN=NAMLEN3) :: ENAME = ' '! inven I/O API output logical name
        CHARACTER(LEN=NAMLEN3) :: HNAME = ' '! hour-specific input logical name
        CHARACTER(LEN=NAMLEN3) :: INAME = ' '! inven input logical name

C...........   Other local variables
                                
        INTEGER         S, I, J, J1, J2, K, L, L2, V !  counters and indices

        INTEGER      :: DNSTEP = 0 ! day-specific data time step number
        INTEGER      :: DSDATE = 0 ! day-specific data start date
        INTEGER      :: DSTIME = 0 ! day-specific data start time

        INTEGER         FILFMT     ! input file(s) format code
        INTEGER         FIP        ! Temporary FIPS code
        INTEGER      :: HNSTEP = 0 ! day-specific data time step number
        INTEGER      :: HSDATE = 0 ! day-specific data start date
        INTEGER      :: HSTIME = 0 ! day-specific data start time
        INTEGER         IOS        ! I/O status
        INTEGER         MAXK       ! test for maximum value of K in output loop
        INTEGER      :: MXSRCDY= 0 ! max no. day-specific sources
        INTEGER      :: MXSRCHR= 0 ! max no. hour-specific sources
        INTEGER      :: NDAT = 0   ! tmp no. actual pols & activities
        INTEGER         NFIPLIN    ! number of lines in ZDEV
        INTEGER         NINVARR    ! no. inventory variables to read
        INTEGER         NRAWBP     ! number of sources x pollutants
        INTEGER      :: NVARDY = 0 ! no. day-specific variables
        INTEGER      :: NVARHR = 0 ! no. day-specific variables
        INTEGER         TSTEP      ! time step HHMMSS
        INTEGER         TZONE      ! output time zone for day- & hour-specific

        REAL            PRATIO  !  position ratio

        LOGICAL         DFLAG            ! true: day-specific inputs used
        LOGICAL         HFLAG            ! true: hour-specific inputs used
        LOGICAL         IFLAG            ! true: average inventory inputs used
        LOGICAL      :: TFLAG = .FALSE.  ! TRUE if temporal x-ref output

        CHARACTER*5     TYPNAM  !  'day' or 'hour' for import
        CHARACTER*300   MESG    !  message buffer

        CHARACTER*16  :: PROGNAME = 'SMKINVEN'   !  program name

        integer bdev
C***********************************************************************
C   begin body of program SMKINVEN

        LDEV = INIT3()

C.........  Write out copywrite, version, web address, header info, and prompt
C           to continue running the program.
        CALL INITEM( LDEV, SCCSW, PROGNAME )

C.........  Set source category based on environment variable setting
        CALL GETCTGRY

C.........  Output time zone
        TZONE = ENVINT( 'OUTZONE', 'Output time zone', 0, IOS )

C.........  Get names of input files
        CALL OPENINVIN( CATEGORY, IDEV, DDEV, HDEV, RDEV, SDEV, XDEV,
     &                  EDEV, PDEV, VDEV, ZDEV, ENAME, INAME, 
     &                  DNAME, HNAME )

C.........  Set controller flags depending on unit numbers
        DFLAG = ( DDEV .NE. 0 )
        HFLAG = ( HDEV .NE. 0 )
        IFLAG = ( IDEV .NE. 0 )

        MESG = 'Setting up to read inventory data...'
        CALL M3MSG2( MESG )

C.........  Get no. lines in pollutant codes & activities files for allocating
C           memory     
        IF( PDEV .GT. 0 ) THEN
            MXIDAT = GETFLINE( PDEV, 'Pollutant codes and names file' )
        END IF
        IF( VDEV .GT. 0 ) THEN
            I = GETFLINE( VDEV, 'Activity names file' )
            MXIDAT = MXIDAT + I
        END IF
        
C.........  Allocate memory for storing contents of pollutants & activities
C           files
        ALLOCATE( INVDCOD( MXIDAT ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INVDCOD', PROGNAME )
        ALLOCATE( INVDNAM( MXIDAT ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INVDNAM', PROGNAME )
        ALLOCATE( INVSTAT( MXIDAT ), STAT=IOS )
        CALL CHECKMEM( IOS, 'INVSTAT', PROGNAME )

C.........  Read country, state, and county file for time zones
        IF( ZDEV .GT. 0 ) CALL RDSTCY( ZDEV, 1, I )   !  "I" used as a dummy

C.........  Initialize inventory data status.  PROCINVEN will expect this
C           type of initialization.
        INVSTAT = 1   ! array

C.........  Read, sort, and store pollutant codes/names file
        IF( PDEV .GT. 0 ) THEN
            CALL RDCODNAM( PDEV, MXIDAT, NDAT, INVDCOD, 
     &                     INVDNAM )
        END IF

C.........  Read, sort, and store activity codes/names file
        IF( VDEV .GT. 0 ) THEN

            INVSTAT( NDAT+1:MXIDAT ) = -1

            CALL RDCODNAM( VDEV, MXIDAT, NDAT, INVDCOD, 
     &                     INVDNAM )
        END IF

        MXIDAT = NDAT

C.........  Read mobile-source files
        IF( CATEGORY .EQ. 'MOBILE' ) THEN          

C.............  Fill tables for translating mobile road classes & vehicle types
C.............  The tables are passed through MODMOBIL
            CALL RDMVINFO( RDEV )

        END IF

C.........  Process for average day or annual inventory
        IF( IFLAG ) THEN

C.............  Read the raw inventory data, and store in unsorted order
C.............  The arrays that are populated by this subroutine call
C               are contained in the module MODSOURC
            CALL M3MSG2( 'Reading average raw inventory data...' )

            CALL RDINVEN( IDEV, XDEV, EDEV, INAME, MXIDAT, INVDCOD, 
     &                    INVDNAM, FILFMT, NRAWBP, PRATIO, TFLAG )

            CALL M3MSG2( 'Sorting raw inventory data...' )

C.............  Sort inventory and pollutants (sources x pollutants). Note that
C               sources are sorted based on character string definition of the 
C                source so that source definition can be consistent with that of
C                the input format.

            CALL SORTIC( NRAWBP, INDEXA, CSOURCA )

            CALL M3MSG2( 'Processing inventory data...' )

C.............  Processing inventory records and store in sorted order

            CALL PROCINVEN( NRAWBP, MXIDAT, FILFMT, PRATIO, INVSTAT )

C.............  Determine memory needed for actual pollutants list and actual
C               activities list and allocate them. Invstat has been updated
C               to be +/- 2 depending on whether the pollutant or activity was
C               present in the inventory.
            NIPOL = 0
            NIACT = 0
            DO I = 1, MXIDAT
        	IF( INVSTAT( I ) .GT.  1 ) NIPOL = NIPOL + 1
        	IF( INVSTAT( I ) .LT. -1 ) NIACT = NIACT + 1
            ENDDO

            NIPPA = NIPOL + NIACT

            ALLOCATE( EIIDX( NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EIIDX', PROGNAME )
            ALLOCATE( EINAM( NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EINAM', PROGNAME )
            ALLOCATE( AVIDX( NIACT ), STAT=IOS )
            CALL CHECKMEM( IOS, 'AVIDX', PROGNAME )
            ALLOCATE( ACTVTY( NIACT ), STAT=IOS )
            CALL CHECKMEM( IOS, 'ACTVTY', PROGNAME )
            ALLOCATE( EANAM( NIPPA ), STAT=IOS )
            CALL CHECKMEM( IOS, 'EANAM', PROGNAME )

C.............  Create list of actual pollutants and activities and indexes to 
C               the master list. The order in EINAM and ACTVTY will be the  
C               output order. The indexes are for accessing INVDCOD, if needed.
C.............  These are for opening output file and processing output data
            J1 = 0
            J2 = 0
            DO I = 1, MXIDAT

               IF( INVSTAT( I ) .GT. 0 ) THEN
        	   J1 = J1 + 1
        	   EIIDX( J1 ) = I
        	   EINAM( J1 ) = INVDNAM( I )
                   EANAM( J1 ) = INVDNAM( I )
               END IF

               IF( INVSTAT( I ) .LT. 0 ) THEN
        	   J1 = J1 + 1
        	   J2 = J2 + 1
        	   AVIDX ( J2 ) = I
        	   ACTVTY( J2 ) = INVDNAM( I )
                   EANAM ( J1 ) = INVDNAM( I )
               END IF

            END DO

C.............   Fix stack parameters for point sources
C.............   Some of these arguments are variables that are defined in the
C                module MODSOURC
            IF( CATEGORY .EQ. 'POINT' ) CALL FIXSTK( RDEV, NSRC )

C.............  Set time zones based on country/state/county code. Note that a
C               few counties in the Western U.S. are divided by a time zone, so 
C               this is not perfectly accurate for all counties.
            ALLOCATE( TZONES( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'TZONES', PROGNAME )

            DO S = 1, NSRC
        	FIP   = IFIP( S )
        	TZONES( S ) = GETTZONE( FIP )
            END DO

C.............  Write out primary inventory files. Do this before the day- or 
C               hour-specific processing so that if there is a problem, the
C               lengthy inventory import does not need to be redone...

C.............  Write out SCC file
            CALL WRCHRSCC( CSCC )

C.............  Write out temporal x-ref file. (TFLAG is true for EMS-95 format
C               for point sources only)
C.............  NOTE - Monthly not currently supported
            IF( TFLAG ) CALL WRPTREF( NSRC, IDIU, IWEK, IWEK ) 

C.............  Generate message to use just before writing out inventory files
C.............  Open output I/O API and ASCII files 
            CALL OPENINVOUT( MXIDAT, INVDNAM, ENAME, ANAME, SDEV )

            MESG = 'Writing SMOKE ' // CATEGORY( 1:CATLEN ) // 
     &             ' SOURCE INVENTORY file...'

            CALL M3MSG2( MESG )

C.............  Write source characteristics to inventory files (I/O API and
C               ASCII)
            CALL WRINVCHR( ENAME, SDEV )

C.............  Deallocate sorted inventory info arrays, except CSOURC
            CALL SRCMEM( CATEGORY, 'SORTED', .FALSE., .FALSE., 1, 1, 1 )

C.............  Write out average inventory data values
C.............  Compute inventory data values, if needed
            CALL WRINVEMIS( ENAME )

C.............  Deallocate sorted inventory info arrays
            CALL SRCMEM( CATEGORY, 'SORTED', .FALSE., .TRUE., 1, 1, 1 )

C.........  If the inventory is not being imported, then read necessary
C           information from existing inventory files.
        ELSE

C.............  Get header description of inventory file 
            IF( .NOT. DESC3( ENAME ) ) THEN
                MESG = 'Could not get description of file "' //
     &                 ENAME( 1:LEN_TRIM( ENAME ) ) // '"'
        	CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.............  Otherwise, store source-category-specific header information, 
C               including the inventory pollutants in the file (if any).   
C               Note that the I/O API head info is passed by include file and 
C               the results are stored in module MODINFO.
            ELSE

                NSRC    = NROWS3D
                NINVARR = 1
                IVARNAMS( 1 ) = 'CSOURC'

                CALL RDINVCHR( CATEGORY, ENAME, SDEV, NSRC, 
     &                         NINVARR, IVARNAMS )

        	CALL GETSINFO

            END IF

        END IF !   End processing of average annual import or not

C.........  Read in daily emission values and output to a SMOKE file
        IF( DFLAG ) THEN

            TSTEP  = 240000
            TYPNAM = 'day'

C.............  Preprocess day-specific file(s) to determine memory needs.
C               Also determine maximum and minimum dates for output file.
            CALL GETPDINFO( DDEV, MXIDAT, TZONE, TSTEP, TYPNAM, DNAME, 
     &                      DSDATE, DSTIME, DNSTEP, NVARDY, MXSRCDY, 
     &                      DEAIDX, INVDCOD, INVDNAM )

C.............  Read and output day-specific data
            CALL GENPDOUT( DDEV, MXIDAT, TZONE, DSDATE, DSTIME, DNSTEP, 
     &                     TSTEP, NVARDY, MXSRCDY, TYPNAM, DNAME, 
     &                     DEAIDX, INVDCOD, INVDNAM )

        END IF

C.........  Read in hourly emission values and output to a SMOKE file
        IF( HFLAG ) THEN

            TSTEP = 10000
            TYPNAM = 'hour'

C.............  Preprocess hour-specific file(s) to determine memory needs.
C               Also determine maximum and minimum dates for output file.
            CALL GETPDINFO( HDEV, MXIDAT, TZONE, TSTEP, TYPNAM, HNAME, 
     &                      HSDATE, HSTIME, HNSTEP, NVARHR, MXSRCHR,  
     &                      HEAIDX, INVDCOD, INVDNAM )

C.............  Read and output hour-specific data
            CALL GENPDOUT( HDEV, MXIDAT, TZONE, HSDATE, HSTIME, HNSTEP, 
     &                     TSTEP, NVARHR, MXSRCHR, TYPNAM, HNAME,  
     &                     HEAIDX, INVDCOD, INVDNAM )

        END IF

C.........  End program successfully
        MESG = ' '
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 0 )

C******************  FORMAT  STATEMENTS   ******************************

C...........   Informational (LOG) message formats... 92xxx

92000   FORMAT( 5X, A )

92010   FORMAT( 5X, A, :, I10 )


C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

C93041   FORMAT( I5, X, I5, X, I3, X, I8, X, I5.5, 3( X, I3 ) )

93060   FORMAT( 10( A, :, E10.3, :, 1X ) )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94020   FORMAT( A, 1X, I5.5, 1X, A, 1X, I8.8, 1X,
     &          A, I6, 1X, A, I6, 1X, A, :, I6 )

94040   FORMAT( A, I2.2 )

94060   FORMAT( 10( A, :, E10.3, :, 1X ) )

94080   FORMAT( '************  ', A, I7, ' ,  ' , A, I12 )

        END PROGRAM SMKINVEN
