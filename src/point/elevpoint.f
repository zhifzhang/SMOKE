
        PROGRAM ELEVPOINT

C***********************************************************************
C  program body starts at line 
C
C  DESCRIPTION:
C       Identifies sources as elevated (major or plume-in-grid) or minor.
C       Major sources will get plume rise and minor sources will not, however,
C       the major/minor distinction is not required because SMOKE will compute
C       layer fractions for all sources efficiently when needed.  If desired,
C       the program can use an analytical computation (the PLUMRIS routine)
C       along with a cutoff height to determine the major sources.
C       
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C       Copied from elevpoint.F 4.2 by M Houyoux
C
C************************************************************************
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
C Last updated: %G 
C  
C***********************************************************************

C...........   MODULES for public variables
C...........   This module is the source inventory arrays
        USE MODSOURC

C.........  This module contains arrays for plume-in-grid and major sources
        USE MODELEV

C.........  This module contains the information about the source category
        USE MODINFO

C.........  This module contains the global variables for the 3-d grid
        USE MODGRID

        IMPLICIT NONE

C...........   INCLUDES:
        
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'CONST3.EXT'    !  physical and mathematical constants
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C...........   EXTERNAL FUNCTIONS and their descriptions:

        CHARACTER*2     CRLF
        LOGICAL         DSCM3GRD
        INTEGER         ENVINT
        REAL            ENVREAL
        LOGICAL         ENVYN
        LOGICAL         EVALCRIT
        INTEGER         FINDC
        REAL            PLUMRIS
        INTEGER         PROMPTFFILE
        CHARACTER*16    PROMPTMFILE

        EXTERNAL        CRLF, DSCM3GRD, ENVINT, ENVREAL, ENVYN, 
     &                  EVALCRIT, FINDC, PLUMRIS, PROMPTFFILE, 
     &                  PROMPTMFILE

C...........  LOCAL PARAMETERS and their descriptions:
        CHARACTER*50, PARAMETER :: CVSW = '$Name$' ! CVS release tag

        INTEGER, PARAMETER :: LAYPOINT_APPROACH   = 0
        INTEGER, PARAMETER :: NOPING_APPROACH     = 0
        INTEGER, PARAMETER :: PELVCONFIG_APPROACH = 1

C...........   Indicator for which public inventory arrays need to be read
        INTEGER               , PARAMETER :: NINVARR = 10
        CHARACTER(LEN=IOVLEN3), PARAMETER :: IVARNAMS( NINVARR ) = 
     &                                 ( / 'IFIP           '
     &                                   , 'TZONES         ' 
     &                                   , 'XLOCA          '
     &                                   , 'YLOCA          '
     &                                   , 'STKHT          '
     &                                   , 'STKDM          '
     &                                   , 'STKTK          '
     &                                   , 'STKVE          '
     &                                   , 'CSOURC         '
     &                                   , 'CPDESC         ' / )

C...........   Descriptions of plume-in-grid and elevated source approaches
        INTEGER, PARAMETER :: NELEVMTHD = 2
        INTEGER, PARAMETER :: NPINGMTHD = 2
        CHARACTER*60, PARAMETER :: ELEVMTHD( NELEVMTHD ) = 
     &(/ 'Allow Laypoint to determine elevated sources                ',
     &   'Use PELVCONFIG file to determine elevated sources           '
     &/)

        CHARACTER*60, PARAMETER :: PINGMTHD( NPINGMTHD ) = 
     &(/ 'No PinG sources                                             ',
     &   'Use PELVCONFIG file to determine PinG sources               '
     &/)

C...........   Allocateable arrays for using GENPTCEL routine to get grid-cell
C              numbers based on current projection
        INTEGER, ALLOCATABLE :: INDX ( : )  ! sorting index (unused)
        INTEGER, ALLOCATABLE :: GN   ( : )  ! cell numbers
        INTEGER, ALLOCATABLE :: SN   ( : )  ! stack group pos in list (unused)
        INTEGER, ALLOCATABLE :: NX   ( : )  ! no. stack groups per cell (unused)

C...........   Allocatable arrays for temporary storage of inventory group info
        INTEGER, ALLOCATABLE :: LOCGID ( : )  ! group number
        INTEGER, ALLOCATABLE :: LOCCNT ( : )  ! number sources in group
        LOGICAL, ALLOCATABLE :: LOCSTAT( : )  ! true: group reset during renumbering

C...........   Temporary by-source arrays
        INTEGER, ALLOCATABLE :: SRCGROUP( : ) ! group number in sorted src order

C...........   Other allocatable arrays
        REAL   , ALLOCATABLE :: VALS( : )  ! tmp test values
        REAL   , ALLOCATABLE :: RANK( : )  ! tmp ranked value
        LOGICAL, ALLOCATABLE :: EVSTAT( :,:,: ) ! tmp status of elev checks
        LOGICAL, ALLOCATABLE :: PGSTAT( :,:,: ) ! tmp status of PiNG checks

C...........   File units and logical/physical names
        INTEGER         CDEV    !  elevated source configuration file
c        INTEGER         GDEV    !  stack groups file
        INTEGER         LDEV    !  log-device
        INTEGER         PDEV    !  for output major/mepse src ID file
        INTEGER         RDEV    !  ASCII output report
        INTEGER         SDEV    !  ASCII part of inventory unit no.
c        INTEGER         TDEV    !  stack splits file

        CHARACTER*16    ANAME   !  logical name for ASCII inventory input file
        CHARACTER*16    ENAME   !  logical name for i/o api inventory input file
        CHARACTER*16    MNAME   !  plume-in-grid srcs stack groups output file
        CHARACTER*16    TNAME   !  logical name for hourly inventory input file

C...........   Other local variables
        INTEGER         G, I, J, K, S, L, L2, N, V    ! indices and counters

        INTEGER         COL           ! tmp column number
        INTEGER      :: ELEVTYPE = 0  ! code for elevated source approach
        INTEGER         ENLEN         ! inventory file name length
        INTEGER         IGRP          ! tmp group ID
        INTEGER         IOS           ! i/o status
        INTEGER         IOSCUT        ! i/o status for cutoff E.V.
        INTEGER         IREC          ! record counter
        INTEGER      :: NEXCLD = 0    ! no. stack groups exlcuded from the grid
        INTEGER         NINVGRP       ! no. inventory groups
        INTEGER      :: NMAJOR = 0    ! no. major sources
        INTEGER      :: NMJRGRP = 0   ! no. major sources incl groups
        INTEGER      :: NPING  = 0    ! no. plume-in-grid sources
        INTEGER      :: NPINGGRP = 0  ! no. plume-in-grid sources incl groups
        INTEGER         NSLINES       ! no. lines in stack splits file
        INTEGER      :: NSTEPS = 24   ! no. time steps
        INTEGER         OUTG          ! group number for output report
        INTEGER         MS            ! tmp src ID for major sources
        INTEGER         PGRP          ! group no. from previous iteration
        INTEGER      :: PINGTYPE = 0  ! code for PinG source approach
        INTEGER         PS            ! tmp src ID for plume in grid sources
        INTEGER         ROW           ! tmp row number
        INTEGER      :: SDATE = 0     ! Julian start date
        INTEGER      :: STIME = 0     ! start time
        INTEGER      :: TSTEP = 10000 ! time step HHMMSS
        INTEGER         TZONE         ! output time zone

        REAL            DM            ! tmp inside stack diameter [m]
        REAL            FL            ! tmp stack exit flow rate [m^3/s]
        REAL            HT            ! tmp inside stack diameter [m]
        REAL            LAT           ! tmp latitude [degrees]
        REAL            LON           ! tmp longitude [degrees]
        REAL            MINDM         ! min stack group diam
        REAL            MINFL         ! min stack group flow
        REAL            MINHT         ! min stack group height
        REAL            MINTK         ! min stack group temperature
        REAL            MINVE         ! min stack group velocity
        REAL            TK            ! tmp stack exit temperature [K]
        REAL            VE            ! tmp stack exit velocity diameter [m/s]

        LOGICAL :: CFLAG    = .FALSE. ! true: convert from English to metric
        LOGICAL :: EFLAG    = .FALSE. ! true: error detected
        LOGICAL :: SFLAG    = .FALSE. ! true: store group info
        LOGICAL :: WFLAG    = .FALSE. ! true: convert lon to western

        CHARACTER*80    GDESC     !  grid description
        CHARACTER*300   BUFFER
        CHARACTER*300   MESG

        CHARACTER(LEN=IOVLEN3) COORD3D  !  coordinate system name
        CHARACTER(LEN=IOVLEN3) COORUN3D !  coordinate system units 
        CHARACTER(LEN=ALLLEN3) CSRC     !  buffer for source char, incl pol/act

        CHARACTER*16 :: PROGNAME = 'ELEVPOINT'   !  program name

C***********************************************************************
C   begin body of program ELEVPOINT

        LDEV = INIT3()

C.........  Write out copywrite, version, web address, header info, and prompt
C           to continue running the program.
        CALL INITEM( LDEV, CVSW, PROGNAME )

C.........  Get environment variables that control this program
        MESG = 'Approach for create plume-in-grid outputs'
        PINGTYPE = ENVINT( 'SMK_PING_METHOD', MESG, 0, IOS )

        MESG = 'Approach for defining major/minor sources'
        ELEVTYPE = ENVINT( 'SMK_ELEV_METHOD', MESG, 0, IOS )

        MESG = 'Indicator for converting all longitudes to Western'
        WFLAG = ENVYN( 'WEST_HSPHERE', MESG, .TRUE., IOS )

        MESG = 'Indicator for English to metric units conversion'
        CFLAG = ENVYN( 'SMK_ENG2METRIC_YN', MESG, .FALSE., IOS )

C.........  End program for invalid settings
        IF ( ELEVTYPE .GT. PELVCONFIG_APPROACH .OR.
     &       PINGTYPE .GT. PELVCONFIG_APPROACH      ) THEN

            IF ( ELEVTYPE .GT. PELVCONFIG_APPROACH ) THEN
                MESG = 'WARNING: SMK_ELEV_METHOD value is invalid!'//
     &             CRLF() // BLANK10 // 'Valid values are: '// 
     &             CRLF() // BLANK10 // 
     &             '0 = Allow Laypoint to determine elevated sources'//
     &             CRLF() // BLANK10 // 
     &             '1 = Use PELVCONFIG to determine elevated sources.'//
     &             CRLF() // BLANK10 // 'Setting to 0.'
                ELEVTYPE = 0
                CALL M3MSG2( MESG )
            END IF

            IF ( PINGTYPE .GT. PELVCONFIG_APPROACH ) THEN
                MESG = 'WARNING: SMK_PING_METHOD value is invalid!'//
     &             CRLF() // BLANK10 // 'Valid values are: '// 
     &             CRLF() // BLANK10 // 
     &             '0 = No plume-in-grid sources'//
     &             CRLF() // BLANK10 // 
     &             '1 = Use PELVCONFIG to determine plume-in-grid ' //
     &             'sources.' //CRLF() // BLANK10 // 'Setting to 0.'
                PINGTYPE = 0
                CALL M3MSG2( MESG )
            END IF

        END IF

C.........  End program run if program inputs indicate it does not need to be
C           run
        IF( ELEVTYPE .LE. LAYPOINT_APPROACH .AND. 
     &      PINGTYPE .LE. NOPING_APPROACH         ) THEN
            MESG = 'ERROR: Neither plume-in-grid nor elevated '//
     &             'sources will be identified '// CRLF()// BLANK10//
     &             'based on SMK_ELEV_METHOD and SMK_PING_METHOD ' //
     &             'settings. Elevpoint ' // CRLF()// BLANK10// 
     &             'is not needed. Ending...'
            CALL M3MSG2( MESG )
            CALL M3EXIT( PROGNAME, 0, 0, ' ', 2 )

        END IF

C.........  Set source category based on environment variable setting
        CALL GETCTGRY

C.........  Get inventory file names given source category
        CALL GETINAME( CATEGORY, ENAME, ANAME )

C.........  Make sure only run for point sources
        IF( CATEGORY .NE. 'POINT' ) THEN
            MESG = 'ERROR: ' // PROGNAME( 1:LEN_TRIM( PROGNAME ) ) //
     &             ' is not valid for ' // CATEGORY( 1:CATLEN ) // 
     &             ' sources'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.........  Write out notes about elevated and PinG approachs
        IF ( ELEVTYPE .GT. 0 ) THEN
            MESG = 'NOTE: Elevated source approach is...' // CRLF() // 
     &              BLANK10 // ELEVMTHD( ELEVTYPE  )
            CALL M3MSG2( MESG )
        END IF

        MESG = 'NOTE: Plume-in-grid (PinG) approach is...'// CRLF() // 
     &         BLANK10 // PINGMTHD( PINGTYPE )
        CALL M3MSG2( MESG )

C.......   Get file name; open input point source and output
C.......   elevated points files

C.........   Get file names and open inventory files
        ENAME = PROMPTMFILE( 
     &          'Enter logical name for the I/O API INVENTORY file',
     &          FSREAD3, ENAME, PROGNAME )
        ENLEN = LEN_TRIM( ENAME )

        SDEV = PROMPTFFILE( 
     &         'Enter logical name for the ASCII INVENTORY file',
     &         .TRUE., .TRUE., ANAME, PROGNAME )

C.........  Get elevated source configuration file, if needed
        IF( PINGTYPE .EQ. PELVCONFIG_APPROACH .OR. 
     &      ELEVTYPE .EQ. PELVCONFIG_APPROACH      ) THEN

            CDEV = PROMPTFFILE( 
     &         'Enter logical name for the ELEVATED SOURCE ' //
     &         'CONFIGURATION file',
     &         .TRUE., .TRUE., CRL // 'ELVCONFIG', PROGNAME )

        END IF

C.........  Open ASCII report file
        RDEV = PROMPTFFILE(  
     &        'Enter name for ELEVATED SELECTION REPORT file',
     &        .FALSE., .TRUE., 'REP' // CRL // 'ELV', PROGNAME )

C.........  Get header description of inventory file, error if problem
        IF( .NOT. DESC3( ENAME ) ) THEN
            MESG = 'Could not get description of file "' //
     &             ENAME( 1:ENLEN ) // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  Otherwise, store source-category-specific header information, 
C           including the inventory pollutants in the file (if any).  Note that 
C           the I/O API header info is passed by include file and the
C           results are stored in module MODINFO.
        ELSE

            CALL GETSINFO

        END IF

C.........  Allocate memory for and read in required inventory characteristics
        CALL RDINVCHR( CATEGORY, ENAME, SDEV, NSRC, NINVARR, IVARNAMS )

C.........  Allocate memory for source status arrays and group numbers
        ALLOCATE( LMAJOR( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LMAJOR', PROGNAME )
        ALLOCATE( LPING( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LPING', PROGNAME )
        ALLOCATE( GROUPID( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GROUPID', PROGNAME )
        ALLOCATE( GINDEX( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GINDEX', PROGNAME )
        ALLOCATE( SRCGROUP( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SRCGROUP', PROGNAME )

C.........  Initialize source status and group number arrays
        LMAJOR  = .FALSE.   ! array
        LPING   = .FALSE.   ! array
        GROUPID = 0         ! array
        GINDEX  = 0         ! array

C.........  Get grid description for converting the stack coordinates
C           to grid cells for the STACK_GROUPS file.
        IF( .NOT. DSCM3GRD( GDNAM3D, GDESC, COORD3D, GDTYP3D, COORUN3D,
     &                P_ALP3D, P_BET3D, P_GAM3D, XCENT3D, YCENT3D,
     &                XORIG3D, YORIG3D, XCELL3D, YCELL3D,
     &                NCOLS3D, NROWS3D, NTHIK3D ) ) THEN

            MESG = 'Could not get Models-3 grid description.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ELSE
            GDTYP = GDTYP3D
            P_ALP = P_ALP3D
            P_BET = P_BET3D
            P_GAM = P_GAM3D
            XCENT = XCENT3D
            YCENT = YCENT3D
            NCOLS = NCOLS3D
            NROWS = NROWS3D
            NGRID = NCOLS * NROWS

        END IF            

C.........  Allocate memory so that we can use the GENPTCEL
        ALLOCATE( NX( NGRID ), STAT=IOS )
        CALL CHECKMEM( IOS, 'NX', PROGNAME )

C.........  If needed, read config file 

        IF( ELEVTYPE .EQ. PELVCONFIG_APPROACH .OR.
     &      PINGTYPE .EQ. PELVCONFIG_APPROACH      ) THEN

            CALL RPELVCFG( CDEV )
c NOTE: Need to debug this when spaces are not in PELVCFG file correctly
c    N: Known bad response for example "SO2 >=90." (missing space after =)
        END IF

C.........  Allocate memory for temporary arrays for use in Evalcrit
        I = MAX( NGRPVAR, NEVPVAR )
        ALLOCATE( VALS( I ), STAT=IOS )
        CALL CHECKMEM( IOS, 'VALS', PROGNAME )
        ALLOCATE( RANK( I ), STAT=IOS )
        CALL CHECKMEM( IOS, 'RANK', PROGNAME )
        ALLOCATE( EVSTAT( NELVCRIT, MXELVCHK, NEVPVAR ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EVSTAT', PROGNAME )
        ALLOCATE( PGSTAT( NPNGCRIT, MXPNGCHK, NEVPVAR ), STAT=IOS )
        CALL CHECKMEM( IOS, 'PGSTAT', PROGNAME )
        VALS = 0.
        RANK = 0

C.........  Allocate memory for analytical plume rise array, if it's needed
        IF( LCUTOFF ) THEN
            ALLOCATE( RISE( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'RISE', PROGNAME )
        END IF

C.........  Determine valid stack groups based on inventory. The stacks at the
C           same plant with the same stack parameters can be assigned to the
C           same group.  
C.........  There will be more groups possibly because of
C           major and PinG sources that aren't in the inventory groups will
C           get assigned their own group.
C.........  This routine populates arrays in MODELEV that contain the group-
C           specific information.  It allocates some of the group arrays.
        IF( NGRPCRIT .GT. 0 ) THEN
            CALL ASGNGRPS( NGRPVAR, NGRPCRIT, MXGRPCHK, 
     &                     GRPVALS, GRPTYPES, NINVGRP   )
        END IF

C.........  If emissions are needed as a criteria, determine maximum daily 
C           emissions over the time period being processed for each source
C           and inventory group.
C.........  Also get date and time information a different way if using
C           an emissions file on input
        IF( NEVPEMV .GT. 0 ) THEN

C.............  Get episode information for setting date and time of 
C               STACK_PING file
            MESG = 'NOTE: Getting date/time information to constrain '//
     &             'time period for emissions input file'
            CALL M3MSG2( MESG )

            CALL GETM3EPI( -9, SDATE, STIME, NSTEPS )

C.............  Create maximum daily emissions by stack group.  The stack
C               groups have already been set, and now the emissions for those
C               groups must be computed to assign MEPSEs and MPSs.
            CALL MXGRPEMIS( NINVGRP, TSTEP, SDATE, STIME, 
     &                      NSTEPS, TNAME ) 

        ELSE
            MESG = 'NOTE: Getting date/time information only for ' //
     &             'use in STACK_PING file'
            CALL M3MSG2( MESG )

            CALL GETM3EPI( -9, SDATE, STIME, -9 )

        END IF  ! End of whether emissions are needed as a criteria

        open(75,file='file1.txt')
        open(85,file='file2.txt')

C.........  Loop through sources to determine elevated and PinG sources.  If
C           source is in a stack group, use group settings to compare to
C           the elevated and/or PinG criteria.
C.........  Also, update stack parameters and emissions permanently for
C           program duration if it's in an inventory group
        NGROUP = 0
        PGRP   = -9
        DO J = 1, NSRC

            S    = GINDEX ( J )
            IGRP = GROUPID( S )

C.............  For sources in an inventory group...
            IF ( IGRP .GT. 0 ) THEN

C.................  Update stack parameters, if needed
                XLOCA( S ) = GRPLON( IGRP )
                YLOCA( S ) = GRPLAT( IGRP )
                STKDM( S ) = GRPDM ( IGRP )
                STKHT( S ) = GRPHT ( IGRP )
                STKTK( S ) = GRPTK ( IGRP )
                STKVE( S ) = GRPVE ( IGRP )

            END IF

C.............  Store reordered group IDs
            SRCGROUP( S ) = IGRP

C.............  Set temporary values for the current source
            CSRC = CSOURC ( S )
            HT   = STKHT  ( S )
            DM   = STKDM  ( S )
            TK   = STKTK  ( S )
            VE   = STKVE  ( S )

C.............  Set values to be compared in selection formulas for this 
C               source, depending on whether source is in a group or not...
C.............  Source arrays have already been updated with group info
C               (include emissions TOTAL for group).
            VALS( HT_IDX ) = HT
            VALS( DM_IDX ) = DM
            VALS( TK_IDX ) = TK
            VALS( VE_IDX ) = VE
            VALS( FL_IDX ) = 0.25 * PI * DM * DM * VE

C.............  If cutoff approach is used, compute and store plume rise
            IF( LCUTOFF ) THEN

                IF( HT .LT. 0. .OR. 
     &              TK .LE. 0. .OR.
     &              VE .LE. 0. .OR.
     &              DM .LE. 0.      ) THEN

                    EFLAG = .TRUE.
                    CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )

                    WRITE( MESG,94030 ) HT, DM, TK, VE

                    L = LEN_TRIM( MESG )
                    MESG = 'ERROR: Invalid stack parameters for:' //
     &                     CRLF() // BLANK10 // 
     &                     BUFFER( 1:L2 )// ' with'// CRLF()// BLANK10//
     &                     MESG( 1:L )                
                    CALL M3MESG( MESG )
                    VALS( RISE_IDX ) = 0.

C.................  When stack parameters are okay...
                ELSE

C.....................  Calculate estimated plume rise
                    RISE( S ) = PLUMRIS( HT, TK, VE, DM )
                    VALS( RISE_IDX ) = RISE( S )

                END IF        ! end bad stack parms or not

C.............  Otherwise, set value of rise to zero
            ELSE
                VALS( RISE_IDX ) = 0.

            END IF            ! end cutoff approach or not

C.............  Add pollutant value to VALS and set RANK for pollutants
            IF( NEVPEMV .GT. 0 ) THEN
                N = MAX( HT_IDX,DM_IDX,TK_IDX,VE_IDX,FL_IDX,RISE_IDX ) ! in case of code alteration
                DO K = 1, NEVPEMV
                    N = N + 1                    
                    VALS( N ) = MXEMIS( S,K )
                    RANK( N ) = REAL( MXRANK( S,K ) )
                END DO
            END IF

C.............  If PELVCONFIG used for elevated sources, check if source matches 
C               criteria given
            IF( ELEVTYPE .EQ. PELVCONFIG_APPROACH ) THEN

C.................  See if source matches criteria for elevated sources
                EVSTAT = .FALSE.  ! array
                IF ( EVALCRIT( NEVPVAR, NELVCRIT, MXELVCHK, VALS, VALS, 
     &                         RANK, ELVVALS, ELVTYPES, EVSTAT ) ) THEN
                    IF ( IGRP .NE. PGRP ) NMJRGRP = NMJRGRP + 1
                    NMAJOR = NMAJOR + 1
                    LMAJOR( S ) = .TRUE.

                END IF

            END IF            ! End elevated sources approach

C.............  If PELVCONFIG used for PinG sources, check if source matches 
C               criteria given
            IF( PINGTYPE .EQ. PELVCONFIG_APPROACH ) THEN

C.................  See if source matches criteria for PinG sources
                PGSTAT = .FALSE.  ! array
                IF ( EVALCRIT( NEVPVAR, NPNGCRIT, MXPNGCHK, VALS, VALS, 
     &                         RANK, PNGVALS, PNGTYPES, PGSTAT ) ) THEN
                    NPING = NPING + 1
                    IF ( IGRP .NE. PGRP ) NPINGGRP = NPINGGRP + 1
                    LPING( S ) = .TRUE.

                END IF
            END IF     ! End whether PinG approach is to use PELVCONFIG or not

C.............  If source is a major source or a PinG source, but it's not in 
C               a group, increase the total maximum group count. Since the
C               sources are not currently sorted by group number, this count
C               is a maximum value, not an actual value
            IF( ( LMAJOR( S )    .OR. 
     &            LPING ( S )         ) .AND.
     &          ( IGRP .EQ. 0    .OR. 
     &            IGRP .NE. PGRP      )      ) NGROUP = NGROUP + 1

            IF( LMAJOR( S ) .OR. 
     &          LPING ( S )      )  write( 75,'(3I10)') S,IGRP, J

            PGRP = IGRP

        END DO         ! End loop over sources

C.........  Now reset group arrays for major and PinG sources only. Groups
C           are not used by SMOKE for other point sources.

C.........  Allocate memory for and save inventory groups in local arrays
        ALLOCATE( LOCGID( NINVGRP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LOCGID', PROGNAME )
        ALLOCATE( LOCCNT( NINVGRP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LOCCNT', PROGNAME )
        ALLOCATE( LOCSTAT( NINVGRP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LOCSTAT', PROGNAME )

        LOCGID = GRPGID
        LOCCNT = GRPCNT
        LOCSTAT = .FALSE.  

C.........  Deallocate inventory groups so that these can be allocated 
        IF ( ALLOCATED( GRPLAT ) ) THEN

            DEALLOCATE( GRPLAT, GRPLON, GRPDM, GRPHT, GRPTK, 
     &                  GRPVE, GRPFL, GRPCNT )

        END IF

C.........  Reallocate group arrays based on inventory groups, major, and 
C           PinG settings.
C.........  The group sorting index is here in case we need to add back
C           in the reading of PSPLIT and PGROUP files, which might be
C           unsorted.  The WPINGSTK routine uses this index
        ALLOCATE( GRPGIDA( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPGIDA', PROGNAME )
        ALLOCATE( GRPIDX( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPIDX', PROGNAME )
        ALLOCATE( GRPLAT( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPLAT', PROGNAME )
        ALLOCATE( GRPLON( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPLON', PROGNAME )
        ALLOCATE( GRPDM( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPDM', PROGNAME )
        ALLOCATE( GRPHT( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPHT', PROGNAME )
        ALLOCATE( GRPTK ( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPTK', PROGNAME )
        ALLOCATE( GRPVE( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPVE', PROGNAME )
        ALLOCATE( GRPFL( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPFL', PROGNAME )
        ALLOCATE( GRPCNT( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPCNT', PROGNAME )
        ALLOCATE( GRPCOL( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPCOL', PROGNAME )
        ALLOCATE( GRPROW( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPROW', PROGNAME )
        ALLOCATE( GRPXL( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPXL', PROGNAME )
        ALLOCATE( GRPYL( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPYL', PROGNAME )
        ALLOCATE( INDX( NGROUP ), STAT=IOS )
        ALLOCATE( GN( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GN', PROGNAME )
        ALLOCATE( SN( NGROUP ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SN', PROGNAME )

        GRPGIDA = 0
        GRPIDX  = 0
        GRPLAT  = BADVAL3
        GRPLON  = BADVAL3
        GRPDM   = BADVAL3
        GRPHT   = BADVAL3
        GRPTK   = BADVAL3
        GRPVE   = BADVAL3
        GRPFL   = BADVAL3
        GRPCNT  = 0
        GRPCOL  = 0
        GRPROW  = 0
        GRPXL   = BADVAL3
        GRPYL   = BADVAL3
        GN      = 0
        SN      = 0

C.........  Loop over sources to fill in group settings with new group numbers 
C           and to populate group arrays for major and PinG sources. 
C           Groups that aren't major or PinG sources will be dropped.
C.........  Make sure to keep sources together that share a group ID from
C           the inventory grouping.
C.........  Source arrays have already been updated with group info.
C.........  OUTG is used because G is not necessarily going to stay in order
C           with the LOCGID construct.
        G = 0
        DO S = 1, NSRC

C.............  If major or PinG
            IF ( LMAJOR( S ) .OR. LPING( S ) ) THEN

C.................  Retrieve old group number
                IGRP = SRCGROUP( S )

C.................  If source is in an inventory group...
                IF ( IGRP .GT. 0 ) THEN

C.....................  If  it has already been assigned a new number, 
C                      retrieve number for the report.
                    IF ( LOCSTAT( IGRP ) ) THEN

                        GROUPID( S ) = LOCGID( IGRP )
                        OUTG = LOCGID( IGRP )
                        SFLAG = .FALSE.    ! controller for later in loop

C.....................  Otherwise, group information has not yet been stored and
C                       it needs to be
                    ELSE

C.........................  If source is in an inventory group...
                        G = G + 1
                        OUTG = G 
                        LOCGID ( IGRP ) = G          ! store for next iteration
                        LOCSTAT( IGRP ) = .TRUE.
                        SFLAG = .TRUE.    ! controller for later in loop

                        IF ( G .LE. NGROUP ) THEN
                            GROUPID( S ) = G
                            GRPIDX ( G ) = LOCGID( IGRP )
                            GRPGIDA( G ) = LOCGID( IGRP )
                            GRPCNT ( G ) = LOCCNT( IGRP )
                        END IF

                    END IF

C.................  If source not in an inventory group, it needs a grp no.
                ELSE 
                    G = G + 1
                    OUTG = G 
                    SFLAG = .TRUE.    ! controller for later in loop

                    IF ( G .LE. NGROUP ) THEN
                        GROUPID( S ) = G
                        GRPIDX ( G ) = G
                        GRPGIDA( G ) = G
                        GRPCNT ( G ) = 1
                    END IF

                END IF

C.................  Ensure no internal error overflow
                IF ( G .GT. NGROUP ) CYCLE

C.................  Store the rest of the group settings in output arrays
                IF( SFLAG ) THEN
                    GRPLAT( G ) = YLOCA ( S )
                    GRPLON( G ) = XLOCA ( S )
                    GRPDM ( G ) = STKDM ( S )
                    GRPHT ( G ) = STKHT ( S )
                    GRPTK ( G ) = STKTK ( S )
                    GRPVE ( G ) = STKVE ( S )
                    GRPFL ( G ) = 0.25 * PI * GRPDM(G)*GRPDM(G)*GRPVE(G)
                END IF

C.................  Write out report information...

C.................  Get setup for another call to EVALCRIT to get STATUS
                VALS = 0.           ! array
                VALS( HT_IDX ) = GRPHT ( OUTG )
                VALS( DM_IDX ) = GRPDM ( OUTG )
                VALS( TK_IDX ) = GRPTK ( OUTG )
                VALS( VE_IDX ) = GRPVE ( OUTG )
                VALS( FL_IDX ) = GRPFL ( OUTG )
                IF( LCUTOFF ) VALS( RISE_IDX ) = RISE( S )

C.................  Add pollutant value to VALS and set RANK for pollutants
                IF( NEVPEMV .GT. 0 ) THEN
                    N = MAX(HT_IDX,DM_IDX,TK_IDX,VE_IDX,FL_IDX,RISE_IDX) ! in case of code alteration
                    DO K = 1, NEVPEMV
                        N = N + 1                    
                        VALS( N ) = MXEMIS( S,K )
                        RANK( N ) = REAL( MXRANK( S,K ) )
                    END DO
                END IF

C.................  If source is PinG, write out for PinG
                IF ( LPING( S ) ) THEN

C..................... Evaluate PinG criteria again to get PGSTAT for writing;
C                      if valid, then write report fields
                    IF ( EVALCRIT( NEVPVAR, NPNGCRIT, MXPNGCHK, VALS, 
     &                             VALS, RANK, PNGVALS, PNGTYPES, 
     &                             PGSTAT ) ) THEN

                        CALL WRITE_REPORT( RDEV, S, OUTG, NEVPVAR, 
     &                       NPNGCRIT, MXPNGCHK, 'P', VALS, RANK, 
     &                       PNGVALS, PNGTYPES, PGSTAT )

C.....................  Otherwise, internal error
                    ELSE
                        EFLAG = .TRUE.
                        WRITE( MESG,94010 ) 'INTERNAL ERROR: ' //
     &                         'Second evaluation of PinG source ', S,
     &                         'inconsistent with first evaluation.'
                        CALL M3MESG( MESG )

                    END IF

C..................... Evaluate elevated criteria again to get PGSTAT for 
C                      writing; if valid, then write report fields
                ELSE 
                    IF ( EVALCRIT( NEVPVAR, NELVCRIT, MXELVCHK, VALS, 
     &                             VALS, RANK, ELVVALS, ELVTYPES, 
     &                             EVSTAT ) ) THEN

C.........................  Add source to report
                        CALL WRITE_REPORT( RDEV, S, OUTG, NEVPVAR, 
     &                       NELVCRIT, MXELVCHK, 'E', VALS, RANK, 
     &                       ELVVALS, ELVTYPES, EVSTAT )

C.....................  Otherwise, internal error
                    ELSE
                        EFLAG = .TRUE.
                        WRITE( MESG,94010 ) 'INTERNAL ERROR: ' //
     &                         'Second evaluation of elevated source ', 
     &                         S, 'inconsistent with first evaluation.'
                        CALL M3MESG( MESG )

                    END IF

                END IF

            END IF  ! End if major or PinG sources

        END DO      ! End loop on sources

C.........  Ensure that all is well with memory allocation
        IF ( G .NE. NGROUP ) THEN
            MESG = 'INTERNAL ERROR: Maximum number of groups was '//
     &             'wrong for memory allocation!'
            CALL M3MSG2( MESG )
            CALL M3EXIT( PROGNAME, 0, 0, ' ', 2 )
        END IF

C.............  Process the stack group coordinates for the current grid...

C.............  Convert x,y location to coordinates of the projected grid
        GRPXL = GRPLON
        GRPYL = GRPLAT
        CALL CONVRTXY( NGROUP, GDTYP, P_ALP, P_BET, 
     &                 P_GAM, XCENT, YCENT, GRPXL, GRPYL )

C.............  Determine grid cells for these coordinate locations
        CALL GENPTCEL( NGROUP, NGRID, GRPXL, GRPYL, NEXCLD, NX, 
     &                 INDX, GN, SN )

C.............  Convert grid cells to row and columns numbers
        DO I = 1, NGROUP

           ROW = 0
           COL = 0
           N   = GN( I )

           IF( N .GT. 0 ) THEN
               ROW = N / NCOLS          ! note: integer math
               IF( MOD( N, NCOLS ) .GT. 0. ) ROW = ROW + 1
               COL = N - ( ROW-1 ) * NCOLS
           END IF

           GRPROW( I ) = ROW
           GRPCOL( I ) = COL

        END DO

C.........  Abort if an error occurred
        IF( EFLAG ) THEN
            MESG = 'Problem selecting major/plume-in-grid sources'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.........  Write status of processing
        IF( NGROUP .GT. 0 ) THEN
            WRITE( MESG,94010 ) 'Number of stack groups:', NGROUP
            CALL M3MSG2( MESG )
        END IF

        IF( NMAJOR .GT. 0 ) THEN
            WRITE( MESG,94010 ) 'Number of major sources:', NMAJOR
            CALL M3MSG2( MESG )
        END IF

        IF( NMJRGRP .GT. 0 ) THEN
            WRITE(MESG,94010) 'Number of major source groups:', NMJRGRP
            CALL M3MSG2( MESG )
        END IF

        IF( NPING .GT. 0 ) THEN
            WRITE( MESG,94010 ) 'Number of plume-in-grid sources:',NPING
            CALL M3MSG2( MESG )
        END IF

        IF( NPINGGRP .GT. 0 ) THEN
            WRITE( MESG,94010 ) 
     &             'Number of plume-in-grid source groups:', NPINGGRP
            CALL M3MSG2( MESG )
        END IF

C.........  If all values are zero, give error
        IF ( NMAJOR .EQ. 0 .AND.
     &       NPING  .EQ. 0       ) THEN

            MESG = 'No groups, major sources, or '//
     &             'plume-in-grid sources.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        END IF

C.........  Open output files
        CALL OPENEOUT( NGROUP, SDATE, STIME, ENAME, PDEV, MNAME )

C.........  Write ASCII file
        MESG = 'Writing ELEVATED POINT SOURCE output file...'
        CALL M3MSG2( MESG )

        DO S = 1, NSRC

            IF( LMAJOR( S ) .OR. LPING( S ) ) THEN
 
                MS   = 0
                PS   = 0
                IF( LMAJOR( S ) ) MS = S
                IF( LPING ( S ) ) THEN
                    MS = 0
                    PS = S
                END IF
                IGRP = GROUPID( S )

                WRITE( PDEV, 93620 ) MS, PS, IGRP

            END IF

        END DO  

C.........  Sort and write plume-in-grid output file for Models-3 processing
C           or for elevated source identidied by cutoff method
        IF( NGROUP .GT. 0 ) THEN

C.............  Make sure that stack parameters are set for all groups
C.............  This is a simplistic way of doing this for now, later
C               add call to FIXSTK routine
            MINDM = MINVAL( GRPDM( 1:NGROUP ) )
            MINHT = MINVAL( GRPHT( 1:NGROUP ) )
            MINTK = MINVAL( GRPTK( 1:NGROUP ) )
            MINVE = MINVAL( GRPVE( 1:NGROUP ) )
            MINFL = MINVAL( GRPFL( 1:NGROUP ) )

            IF( MIN( MINDM, MINHT, MINTK, MINVE, MINFL ) .LE. 0. ) THEN
                MESG = 'Bad stack group or stack split file. ' //
     &                 'Unable to assign stack ' // CRLF()//BLANK10//
     &                 'parameters to all stack groups. Could be '//
     &                 'a source matching problem.'
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  Give warning if any plume-in-grid stack groups are outside the
C               grid
            IF( NEXCLD .GT. 0 ) THEN
                WRITE( MESG,94010 ) 'WARNING: ', NEXCLD, 'stack ' //
     &                 'groups are outside of grid "' // 
     &                 GDNAM3D( 1:LEN_TRIM( GDNAM3D ) ) // '"'
                CALL M3MSG2( MESG )
            END IF

            MESG='Writing ELEVATED/PING STACK PARAMETERS output file...'
            CALL M3MSG2( MESG )

            CALL WPINGSTK( MNAME, SDATE, STIME )

        END IF

C.........  Normal completion of program
        CALL M3EXIT( PROGNAME, 0, 0, ' ', 0 )

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93500   FORMAT( I6, A1, 21X, I5, F9.0, F9.0, 3X, F8.0, F7.0, F7.0, 
     &          F7.0, F10.0 )

93550   FORMAT( 6X, I6, A1, A1, I1, I2, I3, A15, A15, A11, 7X,
     &          F9.0, F9.0, F8.0, F7.0, F7.0, F7.0, F10.0 )

93620   FORMAT( 3(I8,1X) )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10 ( A, :, I8, :, 2X  ) )

94020   FORMAT( A, 1X, F8.2, 1X, A )

94030   FORMAT( 'H[m]:', 1X, F6.2, 1X, 'D[m]:'  , 1X, F4.2, 1X,
     &          'T[K]:', 1X, F7.1, 1X, 'V[m/s]:', 1X, F10.1 )

94300   FORMAT( A, I2.2, A, I2.2, A )

C******************  INTERNAL SUBPROGRAMS  *****************************

        CONTAINS

C.............  This internal subprogram writes one report record based
C               on interpretation of the STATUS argument using the 
C               contents of the other array arguments.
            SUBROUTINE WRITE_REPORT( FDEV, S, IGRP, NV, NORS, MXAND, 
     &                               LABEL, VALS, RANK, COMPARE, 
     &                               TYPES, STATUS )

C.............  Subprogram arguments
            INTEGER     , INTENT(IN):: FDEV    ! report file unit number
            INTEGER     , INTENT(IN):: S       ! source number
            INTEGER     , INTENT(IN):: IGRP    ! group number
            INTEGER     , INTENT(IN):: NV      ! Number of values
            INTEGER     , INTENT(IN):: NORS    ! Number of OR conditions
            INTEGER     , INTENT(IN):: MXAND   ! Max no.  ANDs for single data val
            CHARACTER(*), INTENT(IN):: LABEL   ! E=elevated, P=PinG
            REAL        , INTENT(IN):: VALS   ( NV )       ! Data values
            REAL        , INTENT(IN):: RANK   ( NV )       ! Ranking order
            REAL        , INTENT(IN):: COMPARE( NORS, MXAND, NV ) ! Formula values
            CHARACTER(*), INTENT(IN):: TYPES  ( NORS, MXAND, NV ) ! Condition
            LOGICAL     , INTENT(IN):: STATUS ( NORS, MXAND, NV ) ! true: condition met

            INTEGER, PARAMETER :: NHEADER  = 16
            CHARACTER*15, PARAMETER :: HEADERS( NHEADER ) = 
     &                              ( / 'Source ID      ',
     &                                  'Region         ',
     &                                  'Plant          ',
     &                                  'Char 1         ',
     &                                  'Char 2         ',
     &                                  'Char 3         ',
     &                                  'Char 4         ',
     &                                  'Char 5         ',
     &                                  'Plt Name       ',
     &                                  'Elevstat       ',
     &                                  'Group          ',
     &                                  'Stk Ht         ',
     &                                  'Stk Dm         ',
     &                                  'Stk Tmp        ',
     &                                  'Stk Vel        ',
     &                                  'Stk Flw        '  / )

C.............  Subprogram local allocatable arrays
            LOGICAL, ALLOCATABLE, SAVE :: LF( : )  ! true: output source chars 
            CHARACTER(LEN=IOVLEN3), ALLOCATABLE, SAVE :: VNAME( : )  ! var names

C.............  Subprogram local static arrays
            CHARACTER*32 CHARS ( MXCHRS ) !  source fields for output

C.............  Local subprogram variables
            INTEGER      K, L, L1, L2, M, N  ! indices and counters
            INTEGER      MX                 ! max of MXPNGCHK and MXELVCHK
            INTEGER      NC                 ! local no. of src chars to output
            INTEGER      NM                 ! local no. of max vals before emis

            LOGICAL      DFLAG              ! true: OR was true
            LOGICAL   :: FIRSTIME = .TRUE.  ! true: first time subprogram called

            CHARACTER*512 BUFFER
            CHARACTER*256 FMTBUF

C----------------------------------------------------------------------

C.............  If firstime routine called
            IF ( FIRSTIME ) THEN

C.................  Allocate local memory
        	ALLOCATE( LF( MXCHRS ), STAT=IOS )
        	CALL CHECKMEM( IOS, 'LF', PROGNAME )
        	ALLOCATE( VNAME( NV ), STAT=IOS )
        	CALL CHECKMEM( IOS, 'VNAME', PROGNAME )

C.................  Initialize output status of source characteristics
                LF = .FALSE.    ! array
                LF( 1:NCHARS ) = .TRUE.

C.................  Initialize variable names for report
                VNAME( HT_IDX )   = 'HT'
                VNAME( DM_IDX )   = 'DM'
                VNAME( TK_IDX )   = 'TK'
                VNAME( VE_IDX )   = 'VE'
                VNAME( FL_IDX )   = 'FL'
                VNAME( RISE_IDX ) = 'RISE'

                NM = MAX( HT_IDX,DM_IDX,TK_IDX,VE_IDX,FL_IDX,RISE_IDX ) ! in case of code alteration
                N = NM
                DO K = 1, NEVPEMV
                    N = N + 1                    
                    VNAME( N ) = EINAM( EVPEMIDX( K ) )
                END DO

C.................  Build header (this is sloppy job for now)
                N = 1
                M = 0
                BUFFER = HEADERS( 1 )
                DO WHILE( N < NHEADER )
                    
                    N = N + 1
                    L1 = LEN_TRIM( BUFFER )

                    IF ( N .GE. 4 .AND. N .LE. 8 ) THEN
                        M = M + 1
                        IF ( M .GT. NCHARS-2 ) CYCLE
                    END IF

                    BUFFER = BUFFER( 1:L1 ) //'; ' // HEADERS( N )

                END DO

C.................  Add plume rise onto header
                IF( LCUTOFF ) THEN
                    L1 = LEN_TRIM( BUFFER )
                    BUFFER = BUFFER( 1:L1 ) // '; Rise '
                END IF

C.................  Add pollutants onto header
                DO K = 1, NEVPEMV
                    L1 = LEN_TRIM( BUFFER )
                    BUFFER = BUFFER( 1:L1 ) // '; Group ' // 
     &                       EINAM( EVPEMIDX( K ) )
                END DO

C.................  Add results onto header
                MX = MAX( MXELVCHK, MXPNGCHK )
                DO K = 1, MX
                    L1 = LEN_TRIM( BUFFER )
                    WRITE( BUFFER, '(4(A,I1))' ) BUFFER( 1:L1 ) //
     &                     '; Var', K, '; Type', K, '; Test', K,
     &                     '; Val', K
                    IF( K .LT. MX ) THEN
                        L1 = LEN_TRIM( BUFFER )
                        WRITE( BUFFER, '(A)' ) BUFFER( 1:L1 ) //
     &                         '; AND'
                    END IF

                END DO

C.................  Write out header
                L1 = LEN_TRIM( BUFFER )
                WRITE( FDEV, '(A)' ) BUFFER( 1:L1 )

                BUFFER =  REPEAT( '-', L1 )
                WRITE( FDEV, '(A)' ) BUFFER( 1:L1 )

                FIRSTIME = .FALSE.

            END IF

C.............  Subdivide source description
            CALL PARSCSRC( CSOURC( S ), MXCHRS, SC_BEGP, SC_ENDP, 
     &                     LF, NC, CHARS )

C.............  Write source information format and then use format
            WRITE( FMTBUF, 94790 ) FIPLEN3, PLTLEN3, 
     &           ( CHRLEN3, N=1,NCHARS-2 ), DSCLEN3
            L1 = LEN_TRIM( FMTBUF )
            FMTBUF = FMTBUF( 1:L1 ) // ')'

            WRITE( BUFFER, FMTBUF ) S, ( CHARS( N ), N = 1, NCHARS ), 
     &                              CPDESC( S )

C.............  Add label, group number, stack parameters, and emissions
            L1 = LEN_TRIM( BUFFER )
            WRITE( BUFFER, 94791 ) BUFFER( 1:L1 ), LABEL, IGRP,
     &             VALS( HT_IDX ), VALS( DM_IDX ), VALS( TK_IDX ),
     &             VALS( VE_IDX ), VALS( FL_IDX )

C.............  If needed, add plume rise value
            IF ( LCUTOFF ) THEN
                L1 = LEN_TRIM( BUFFER )
                WRITE( BUFFER, 94792 ) BUFFER( 1:L1 ), RISE( S )
            END IF

C.............  Add emissions
            IF ( NEVPEMV .GT. 0 ) THEN
                L1 = LEN_TRIM( BUFFER )
                WRITE( BUFFER, 94792 ) BUFFER( 1:L1 ), 
     &                 ( VALS( K ), K = NM+1, NV ) 
            END IF

C.............  Write characteristics that caused matching
            DFLAG = .FALSE.
            DO L = 1, NORS
                DO M = 1, MXAND
                    DO N = 1, NV

C.........................  Check if the status was used to include source 
C                           or not
                        IF ( STATUS( L,M,N ) ) THEN

C.............................  Exit after this OR
                            DFLAG = .TRUE.

C.............................  Add to report for this OR and AND (if any)
                            L2 = LEN_TRIM( BUFFER )
                            IF ( TYPES( L,M,N ) .EQ. 'TOP' ) THEN

                                WRITE( BUFFER, 94793 ) BUFFER( 1:L2 ), 
     &                                 VNAME( N ), ' RANK;      =;', 
     &                                 INT( RANK( N ) )

                            ELSE IF ( TYPES( L,M,N ) .NE. ' ' ) THEN
                                WRITE( BUFFER, 94794 ) BUFFER( 1:L2 ), 
     &                                 VNAME( N ), TYPES( L,M,N ),  
     &                                 COMPARE( L,M,N )

                            END IF

                        END IF

                    END DO

C.....................  If this OR is valid and more than one AND, add AND
C                       to output buffer
                    IF( DFLAG .AND. M+1 .LE. MXAND ) THEN

                        DO N = 1, NV
                            IF ( STATUS( L,M+1,N ) ) THEN

                                L2 = LEN_TRIM( BUFFER ) 
                                BUFFER = BUFFER( 1:L2 ) // ' AND;'
                                EXIT  ! end loop

                            END IF
                        END DO

                    END IF

                END DO

C.................  Exit from "OR" loop if one of the OR criteria has been met
                IF( DFLAG ) EXIT

            END DO

C.............  Write buffer to report file
            L2 = LEN_TRIM( BUFFER )
            WRITE( FDEV, '(A)' ) BUFFER( 1:L2 )

C---------------------  FORMAT  STATEMENTS  -------------------------

94790       FORMAT( '(I7,";",A', I1, ',";"', 10(',A', I2.2,',";"') )

94791       FORMAT( A, 1X, A1, '; ', I6, ';', 5( F10.2, ';' ) )

94792       FORMAT( A, 1X, 20( F10.2, ';' ) )

94793       FORMAT( A, 1X, A16, ';', A, I10, ';' )

94794       FORMAT( A, 1X, A16, ';     ;', 1X, A6, '; ', F10.2 ';' )

            END SUBROUTINE WRITE_REPORT

        END PROGRAM ELEVPOINT

