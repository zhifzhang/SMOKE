
        SUBROUTINE RDUNCERT( FDEV )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine reads in the uncertainty file and sets arrays from
C      the MODUNCERT module.
C
C  PRECONDITIONS REQUIRED:
C      Input file unit FDEV opened
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C      Subroutines: I/O API subroutines, BLDENAMS, CHECKMEM, UPCASE, 
C			PARSLINE, PRCLINUC, SORTIC, XREFTBL,
C                       ASGNUNCERT, OPENUCOUT, WRUCOUT 
C      Functions: I/O API functions, CRLF, BLKORCMT, GETNLIST
C
C  REVISION  HISTORY:
C      Created 8/2001 by A. Holland
C
C**************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2001, MCNC--North Carolina Supercomputing Center
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
C.........  This module contains uncertainty-specific settings
	USE MODUNCERT
        
C.........  This module is for cross reference tables
        USE MODXREF        
        
C.........  This module contains the information about the source category
        USE MODINFO        
        
C.........  This module contains the lists of unique source characteristics
        USE MODLISTS        


        IMPLICIT NONE

C...........   INCLUDES
    	INCLUDE 'EMCNST3.EXT'
        INCLUDE 'PARMS3.EXT'
        INCLUDE 'IODECL3.EXT'
        INCLUDE 'FDESC3.EXT'        

C...........   EXTERNAL FUNCTIONS and their descriptions:
        
	CHARACTER*2 	CRLF
        LOGICAL         BLKORCMT
        INTEGER         GETNLIST
        INTEGER         INDEX1

        EXTERNAL        CRLF, BLKORCMT, GETNLIST, INDEX1  

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT (IN) :: FDEV            ! unit no. of uncert file
        
C...........   Possible pollutant prefixes
	CHARACTER*3, PARAMETER  ::
     &              PREFIX( 5 ) =
     &                      ( / 'OS_',
     &                          'EF_',
     &                          'CE_',
     &                          'RE_',
     &                          'RP_' / )
     
C...........   Sorted pollutant/emission type names
        INTEGER                   INDXP  ( NIPPA ) !  sorting index for pol/etyp
        CHARACTER(LEN=IOVLEN3) :: SRTINAM( NIPPA ) !  sorted pol/act names        
        
C...........   Other arrays
        CHARACTER(LEN=IOVLEN3)  PNAMES( NIPOL, NPPOL ) ! names for pol-spec
        CHARACTER(LEN=IOVLEN3)  ANAMES( NIACT, NPACT ) ! names for act-spec
	CHARACTER*300	SEGMENT( 100 )  ! segments of parsed packet lines
        
        CHARACTER(LEN=IOVLEN3), ALLOCATABLE :: POLBUF( : )  ! tmp. poll-spec. names
        CHARACTER(LEN=IOVLEN3), ALLOCATABLE :: ACTBUF( : )  ! tmp. act-spec. names

C...........   Other local variables
        INTEGER         I, J, K, L, L2, L3, M, N, V  ! counters and indices

        INTEGER         IOS         !  i/o status
        INTEGER         IREC        !  record counter
        INTEGER      :: NS = 1      !  number of segments in line
	INTEGER		NF	    !  number of factor assignment pkts.
	INTEGER         NE	    !  number of empirical pkts.
	INTEGER		NP	    !  number of parametric pkts.
        INTEGER      :: IDUM = 0    !  tmp dummy integer
        INTEGER         JSPC        !  tmp index to master pol/etype list
        INTEGER         NREF        !  no. of x-ref entries before filtering
        INTEGER         NXREF       !  no. of valid x-ref entries
        INTEGER		NTPOL       !  no. of poll-spec. names
        INTEGER		NTACT       !  no. of act-spec. names
        
        REAL            RIMISS3	    !  real value of integer missing

        LOGICAL      :: EFLAG  = .FALSE.  ! true: error occured
        LOGICAL      :: PFLAG  = .FALSE.  ! true: pl/act-spec entries skipped
        LOGICAL      :: SKIPREC = .FALSE. ! true: skip this x-ref entry

        CHARACTER*5     CPOS        !  tmp. sorted position of pol/act
        CHARACTER*300   BUFFER      !  line work buffer
        CHARACTER*300   LINE        !  line input buffer
        CHARACTER*300   MESG        !  message buffer
        CHARACTER*100   CBUF        !  tmp. char
        
        CHARACTER(LEN=SICLEN3)  :: CDUM = '0'  ! dummy character field for SIC
        CHARACTER(LEN=IODLEN3)  CDUMA( NIPPA, NPPOL ) ! char dummy
        CHARACTER(LEN=ALLLEN3)  CSRCALL   !  buffer for source char
        CHARACTER(LEN=FIPLEN3)  CFIP      !  buffer for CFIPS code
        CHARACTER(LEN=FIPLEN3)  FIPZERO   !  buffer for zero FIPS code
        CHARACTER(LEN=SCCLEN3)  TSCC      !  temporary SCC
        CHARACTER(LEN=SCCLEN3)  SCCZERO   !  buffer for zero SCC
        CHARACTER(LEN=SCCLEN3)  PSCCL     !  left digits of TSCC of prev. iter.
        CHARACTER(LEN=SCCLEN3)  SCCL      !  left digits of TSCC
        CHARACTER(LEN=SCCLEN3)  SCCR      !  right 5 digits of TSCC
        CHARACTER(LEN=SCCLEN3)  SCRZERO   !  buffer for zero SCCR
        CHARACTER(LEN=IOVLEN3)  CPOA      !  temp. pollutant/emission type
        CHARACTER(LEN=RWTLEN3)  CRWT      !  roadway type no.
        CHARACTER(LEN=VIDLEN3)  CVID      !  vehicle type ID no.
        CHARACTER(LEN=PLTLEN3)  PLT       !  tmp plant ID
        CHARACTER(LEN=CHRLEN3)  CHARS1    !  tmp source char.
        CHARACTER(LEN=CHRLEN3)  CHARS2    !  tmp source char.
        CHARACTER(LEN=CHRLEN3)  CHARS3    !  tmp source char.
        CHARACTER(LEN=CHRLEN3)  CHARS4    !  tmp source char.
        CHARACTER(LEN=CHRLEN3)  CHARS5    !  tmp source char.

        CHARACTER*16 :: PROGNAME =  'RDUNCERT' ! program name

C***********************************************************************
C   begin body of subroutine RDUNCERT

	UCFLAG = .TRUE.
        
        MESG = 'Reading uncertainty file...'
        CALL M3MSG2( MESG )

C.........  Compute real value of integer missing
        RIMISS3 = REAL( IMISS3 )
        
C.........  Compute total number of output variables
        NUOVAR = ( NIPOL * NPPOL ) + ( NIACT * NPACT )
        NTPOL  = NIPOL * NPPOL
        NTACT  = NIACT * NPACT

C.........  Allocate memory for uncertainty arrays based on previous read 
	ALLOCATE ( FAPCKT ( FPKTENT ), STAT=IOS )	! factor assignment pkt.
	CALL CHECKMEM ( IOS, 'FAPCKT', PROGNAME )
        ALLOCATE ( EMPPCKT ( NEPCKT ), STAT=IOS )	! empirical packet
	CALL CHECKMEM ( IOS, 'EMPPCKT', PROGNAME )
	ALLOCATE ( PARPCKT ( NPPCKT ), STAT=IOS )	! parametric packet
	CALL CHECKMEM ( IOS, 'PARPCKT', PROGNAME )
	ALLOCATE ( EFVAL ( NEPCKT, MXEMPDAT ), STAT=IOS ) ! emission fac. value
	CALL CHECKMEM ( IOS, 'EFVAL', PROGNAME )
	ALLOCATE ( PROB ( NEPCKT, MXEMPDAT ), STAT=IOS )  ! probability
	CALL CHECKMEM ( IOS, 'PROB', PROGNAME )
	ALLOCATE ( PARAMET ( NPPCKT, MXPARDAT ), STAT=IOS ) ! parameters
	CALL CHECKMEM ( IOS, 'PARAMET', PROGNAME )
        ALLOCATE ( USEPOLL ( NUOVAR ), STAT=IOS )       !  flag for pol in pkt
        CALL CHECKMEM ( IOS, 'USEPOLL', PROGNAME )
        ALLOCATE ( UONAMES ( NUOVAR ), STAT=IOS )       !  output names
        CALL CHECKMEM ( IOS, 'UONAMES', PROGNAME )
        ALLOCATE ( POLBUF ( NTPOL ), STAT=IOS )         !  tmp. poll names
        CALL CHECKMEM ( IOS, 'POLBUF', PROGNAME )
        ALLOCATE ( ACTBUF ( NTACT ), STAT=IOS )         !  tmp. act. names
        CALL CHECKMEM ( IOS, 'ACTBUF', PROGNAME )

C.........  Initailize arrays
	FAPCKT%CFIP  = ' ' 	!array
	FAPCKT%TSCC  = ' ' 	!array
        FAPCKT%CPOL  = ' '      !array
	FAPCKT%METH  = ' '	!array
	FAPCKT%NDIST = ' '	!array
	FAPCKT%APRCH = ' '	!array
	FAPCKT%PLT   = ' '	!array
	FAPCKT%CHAR1 = ' '	!array
	FAPCKT%CHAR2 = ' '	!array
        FAPCKT%CHAR3 = ' '	!array
        FAPCKT%CHAR4 = ' '	!array
        FAPCKT%CHAR5 = ' '	!array
        FAPCKT%INDX  = 0        !array

	EMPPCKT%EPKTENT= 0	!array
	EMPPCKT%ETYPE  = ' '	!array
	EMPPCKT%EMPNAM = ' '	!array

	PARPCKT%PARNAM = ' '	!array
	PARPCKT%PTYPE  = ' '	!array
	PARPCKT%NUMP   = 0	!array

	EFVAL   = RIMISS3       !array
	PROB    = RIMISS3       !array
	PARAMET = RIMISS3       !array
	PARA    = RIMISS3       !array
        
        UONAMES = ' '           !array
        USEPOLL = .FALSE.       !array
        
        POLBUF  = ' '           !array
        ACTBUF  = ' '           !array

C.........  Get the list of variable names per pollutant
        CALL BLDENAMS( CATEGORY, NIPOL, NPPOL, EINAM, PNAMES,
     &                 CDUMA, CDUMA, CDUMA )
     
C.........  Get the list of variable names per activity
        CALL BLDENAMS( CATEGORY, NIACT, NPACT, ACTVTY, ANAMES,
     &                 CDUMA, CDUMA, CDUMA )

C.........  Combine PNAMES and ANAMES into a one-dimensional array
	K = 1
        DO I = 1, NIPOL
            DO J = 1, NPPOL
            
                UONAMES( K ) = PNAMES( I, J )
                POLBUF( K ) = PNAMES( I, J )
                K = K + 1
            END DO
        END DO

        L = 1
        DO I = 1, NIACT
            DO J = 1, NPACT
            
                UONAMES( K ) = ANAMES( I, J )
                ACTBUF( L ) = ANAMES( I, J )
                K = K + 1
                L = L + 1
            END DO
        END DO

C.........  Read line of file and store uncertainty data
	IREC = 0
        
	DO I = 1, NLINE_UC

	    READ( FDEV, 93000, END=999, IOSTAT=IOS ) LINE
	    IREC = IREC + 1

	    IF ( IOS .NE. 0 ) THEN
		EFLAG = .TRUE.
		WRITE( MESG,94010 )
     &              'I/O error', IOS,
     &              'reading uncertainty file at line', IREC
		CALL M3MESG( MESG )
		CYCLE
	    END IF

C.........  Skip blank and comment lines
	    IF( BLKORCMT( LINE ) ) CYCLE

C.........  Left-justify and convert line to upper case
	    LINE = ADJUSTL( LINE )
	    BUFFER = LINE
	    CALL UPCASE( BUFFER )

C.........  Initialize segment from previous iteration
	    SEGMENT( 1:NS ) = ' '

C.........  Parse line into segments
            L = LEN_TRIM( BUFFER )
	    NS = GETNLIST( L, BUFFER )
	    CALL PARSLINE( BUFFER, NS, SEGMENT )

C.........  Interpret line of code.  Set variables in MODUNCERT.
	    CALL PRCLINUC( IREC, NS, LINE, SEGMENT )

C.........  If in factor assignment packet
	    IF( INFAPKT ) THEN

C.........  Get count of factor assignment packets and check to make sure there
C	    is only one
		IF( FASTART ) THEN
	          NF = PKTCOUNT( FA_IDX )
		  IF ( PKTCOUNT( FA_IDX ) .GT. 1 ) THEN
		      WRITE( MESG, 94010 )
     &                 'Found a second factor assignment packet
     &                 at line', IREC, '.  Please remove.'
	              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
		  END IF

C.........  Store settings for factor assignment packet
		ELSE 
		    FAPCKT( FAENTN ) = FA_ 
                
C.........  Set status of pollutants for current packet
     
                    IF( FAPCKT( FAENTN )%CPOL .EQ. '0' .OR.  
     &                  FAPCKT( FAENTN )%CPOL.EQ. '-9' ) THEN
                        USEPOLL = .TRUE.
                    ELSE                    
                      K = INDEX1( FAPCKT(FAENTN)%CPOL, 
     &                            NUOVAR, UONAMES )
                      IF( K .LE. 0 ) THEN
                        L = INDEX( FAPCKT(FAENTN)%CPOL(1:3),'ALL' )
                        IF( L .GT. 0 ) THEN
                          DO J = 1, NIPOL
                            M = INDEX1( EINAM(J), NUOVAR, UONAMES )
                            IF( M .GT. 0 ) THEN
                                USEPOLL( M ) = .TRUE.
                            END IF
                          END DO
                        ELSE
                          M = INDEX1( FAPCKT(FAENTN)%CPOL(1:3),
     &                        5, PREFIX )
                          IF( M .GT. 0 ) THEN
                            DO J = 1, NIPOL
                              L2 = LEN_TRIM( EINAM(J) )
                              CBUF = PREFIX(M)//EINAM(J)(1:L2)
                              L3 = LEN_TRIM( CBUF )
                              N = INDEX1( CBUF(1:L3),NUOVAR,UONAMES )
                              IF( N .GT. 0 ) THEN
                                USEPOLL( N ) = .TRUE.
                              END IF
                            END DO
                          ELSE
                            MESG = 
     &                      'Cannot assign uncertainty to "'// 
     &                             FAPCKT(FAENTN)%CPOL //
     &                             '", it is not valid.'
                            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                          END IF
                        END IF
                      ELSE IF( K .GT. 0 ) THEN
                            USEPOLL( K ) = .TRUE.
                      END IF
                    END IF
                    
                    IF( INDEX( FAPCKT( FAENTN )%CPOL, 'ALL' )
     &                  .GT. 0 ) FAPCKT( FAENTN )%CPOL = '0'

	   	END IF

            END IF
            
C.........  If in empirical packet
	    IF( INEMPPKT ) THEN

C.........  Get count of empirical packets
C.........  Store settings for empirical packet
		IF( EMPSTART ) THEN
		  NE = PKTCOUNT( EMP_IDX )		
		  EMPPCKT( NE ) = EMP_
		ELSE
		  EFVAL( NE, EMPENTN ) = EMISFAC
		  PROB(NE, EMPENTN ) = EMPROB
		  EMPPCKT( NE )%EPKTENT = EMPENTN
		END IF

	    END IF

C.........  If in parametric packet
	    IF( INPARPKT ) THEN

C.........  Get count of parametric packets
		NP = PKTCOUNT( PAR_IDX )

C.........  Store settings for parametric packet
		PARPCKT( NP ) = PAR_
		
		DO J = 1, PARPCKT( NP )%NUMP
		  PARAMET( NP, J ) = PARA( J )
		END DO

	    END IF
	    
	    
	END DO		! End read loop of uncertainties file
        
C.........  Get a count of the uncertain pollutants and activites and 
C           create an array of their names
	    DO J = 1, NUOVAR
              IF( USEPOLL( J ) ) THEN
                CBUF = UONAMES( J )
                V = INDEX1( CBUF, NTPOL, POLBUF )
                IF( V .GT. 0 ) THEN
                  UNIPOL = UNIPOL + 1
                ELSE
                  V = INDEX1( CBUF, NTACT, ACTBUF )
                  IF( V .GT. 0 ) THEN
                    UNIACT = UNIACT + 1
                  END IF
                END IF
              END IF
            END DO
            
            UNVAR = UNIPOL + UNIACT
            
            ALLOCATE ( UNAMES( UNVAR ), STAT=IOS )          !  uncert. vars.
            CALL CHECKMEM( IOS, 'UNAMES', PROGNAME )
            
            N = 1
            DO J = 1, NUOVAR
              IF( USEPOLL( J ) ) THEN
                UNAMES( N ) = UONAMES( J )
                N = N + 1
              END IF
            END DO
            

        DO I = 1, FPKTENT
        
            IF ( FAPCKT( I )%METH .EQ. 'E' ) THEN
                DO J = 1, NEPCKT
                    IF ( EMPPCKT( J )%EMPNAM .EQ.
     &                  FAPCKT( I )%NDIST ) THEN
                        FAPCKT( I )%INDX = J
                    END IF
                END DO
            ELSE IF ( FAPCKT( I )%METH .EQ. 'P' ) THEN
                DO J = 1, NPPCKT
                    IF ( PARPCKT( J )%PARNAM .EQ.
     &                  FAPCKT( I )%NDIST ) THEN
                        FAPCKT( I )%INDX = J
                    END IF
                END DO                                          
            END IF
            
            IF ( FAPCKT( I )%INDX .EQ. 0 ) THEN
                WRITE( MESG, 94010 )
     &                  'No method and distribution name match for
     &                  factor assignment entry', FPKTENT
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF
                            
        END DO        
        

C.........  Build unique lists of SCCs per SIC from the inventory arrays
        CALL GENUSLST        
        
        FIPZERO = REPEAT( '0', FIPLEN3 )
        SCCZERO = REPEAT( '0', SCCLEN3 )
        SCRZERO = REPEAT( '0', SCCLEN3 - LSCCEND )  
        
C.........  Sort the actual list of pollutant/emission type names and store it
        DO I = 1, NIPPA
            INDXP( I ) = I
        END DO

        CALL SORTIC( NIPPA, INDXP, EANAM )

        DO I = 1, NIPPA
            J = INDXP( I )
            SRTINAM( I ) = EANAM( J )
        END DO
        
C.........  First pass through cross reference entries.  Count the number
C           of entries matching SCC list and pol/act list.  Do this so 
C           that we know how much memory to allocate for the unsorted,
C           unprocessed arrays.                          
                    
        NREF = 0
        DO I = 1, FPKTENT
        
C.............  Make sure SCC is set to SCCZERO if it is missing        
            TSCC = ADJUSTL( FAPCKT( I )%TSCC )
            CALL FLTRNEG( TSCC )
            CALL PADZERO( TSCC )

            CPOA = FAPCKT( I )%CPOL    !  pollutant/emission type name
            CFIP = FAPCKT( I )%CFIP    !  county/state/county code
            
C.............  Post-process x-ref information to scan for '-9', pad
C               with zeros, compare SCC version master list, compare
C               SIC version to master list, and compare pol/act name 
C               with master list.            
            
            CALL FLTRXREF( CFIP, CDUM, TSCC, CPOA, IDUM, IDUM,
     &                     JSPC, PFLAG, SKIPREC )

            IF( SKIPREC ) CYCLE
            
            NREF = NREF + 1
            
        END DO

        REWIND( FDEV )
        
        ALLOCATE ( INDXTA( NREF ), STAT=IOS )		! sorting index
        CALL CHECKMEM ( IOS, 'INDXTA', PROGNAME ) 
        ALLOCATE ( ISPTA( NREF ), STAT=IOS )		! pollutant index
        CALL CHECKMEM ( IOS, 'ISPTA', PROGNAME )
        ALLOCATE ( CSCCTA ( NREF ), STAT=IOS )          ! SCC
        CALL CHECKMEM ( IOS, 'CSCCTA', PROGNAME )
        ALLOCATE ( CSRCTA ( NREF ), STAT=IOS )          ! source chars
        CALL CHECKMEM ( IOS, 'CSRCTA', PROGNAME )
	ALLOCATE ( FAINDX( NREF ), STAT=IOS )           ! fac. assig. ent. index
	CALL CHECKMEM ( IOS, 'FAINDX', PROGNAME )
        
C.........  Second pass through cross reference entries.  Store unsorted
C           data for the source category of interest.        
        N = 0
        DO I = 1, FPKTENT

C.............  Make sure SCC is set to SCCZERO if it is missing              
            TSCC = ADJUSTL ( FAPCKT( I )%TSCC )
            CALL FLTRNEG( TSCC )
            CALL PADZERO( TSCC )
            
            CPOA = FAPCKT( I )%CPOL    !  pollutant/emission type name
            CFIP = FAPCKT( I )%CFIP    !  country/state/county code

C.............  Post-process x-ref information to scan for '-9', pad
C               with zeros, compare SCC version master list, compare
C               SIC version to master list, and compare pol/act name 
C               with master list.             
            
            CALL FLTRXREF( CFIP, CDUM, TSCC, CPOA, IDUM, IDUM,
     &                     JSPC, PFLAG, SKIPREC )

            IF( SKIPREC ) CYCLE
            
            WRITE ( CPOS, '(I5)' ) JSPC
            
            N = N + 1
            IF( N .GT. NREF ) CYCLE
            
            CSRCALL = ' '
            
C.............  Store sorting criteria as right-justified in fields
C.............  For mobile sources, retrieve link from character field
C               and extract road class and vehicle type from SCC
C.............  For point sources, retrieve plant + characteristics            
            
            SELECT CASE( CATEGORY )
                
                CASE( 'AREA' )
                    
                    CALL BLDCSRC( CFIP, TSCC, CHRBLNK3, CHRBLNK3,
     &                            CHRBLNK3, CHRBLNK3, CHRBLNK3,
     &                            POLBLNK3, CSRCALL )
     
                CASE( 'MOBILE' )
                
C.....................  Convert TSCC to internal value
c                    CALL MBSCCADJ( I, TSCC, CRWT, CVID, TSCC, EFLAG )

                    CALL BLDCSRC( CFIP, TSCC, CHRBLNK3, CHRBLNK3,
     &                            CHRBLNK3, CHRBLNK3, CHRBLNK3,
     &                            POLBLNK3, CSRCALL )
     
                CASE( 'POINT' )
                
C.....................  Store string source characteristics
                     PLT    = FAPCKT( I )%PLT
                     CHARS1 = FAPCKT( I )%CHAR1
                     CHARS2 = FAPCKT( I )%CHAR2 
                     CHARS3 = FAPCKT( I )%CHAR3
                     CHARS4 = FAPCKT( I )%CHAR4
                     CHARS5 = FAPCKT( I )%CHAR5

                     CALL BLDCSRC( CFIP, PLT, CHARS1, CHARS2,
     &                             CHARS3, CHARS4, CHARS5,
     &                             POLBLNK3, CSRCALL )

            END SELECT 

C.............  Store fields
            CSCCTA( N ) = TSCC
            CSRCTA( N ) = CSRCALL( 1: SRCLEN3 ) // TSCC // CPOS

C.............  Store case-indepentdent fields            
            INDXTA( N ) = N
            ISPTA ( N ) = JSPC
	    FAINDX( N ) = I

        END DO

C.........  Set actual number of cross-reference entries
        NXREF = N
        
C.........  Check if no cross-reference entries were found
        IF( NXREF .EQ. 0 ) THEN
            MESG = 'ERROR:  No valid uncertainty cross-references '//
     &             'entries were found'
            CALL M3MSG2( MESG )
            EFLAG = .TRUE.
        END IF
        
C.........  Check for errors reading cross-reference file, and abort
        IF( EFLAG ) THEN
            MESG = 'Problem reading uncertainty cross-reference file.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF
        
        CALL M3MSG2( 'Processing uncertainty cross-reference file...' )
        
C.........  Sort uncertainty cross-reference entries.  Since CPOS was used in
C           building CSRCTA, and CPOS will equal "0" when the x-ref entry is
C           not pol/act-specific, the non-pol/act-specific entries will
C           always appear first.  This is necessary for the table-generating
C           subroutines.                                    
	
        CALL SORTIC ( NXREF, INDXTA, CSRCTA )

        CALL XREFTBL ( 'UNCERT', NXREF )
        
C.........  Deallocate temporary unsorted arrays        
        DEALLOCATE ( INDXTA, CSRCTA )
        
        
C.........  Rewind file        
        REWIND( FDEV )                                                  

	RETURN

C.........  Error message for reaching the end of file too soon
999	WRITE( MESG,94010 )
     &		'End of file reached unexpectedly at line', IREC, CRLF()
     &		//BLANK10 //'Check format of uncertainty file.'
	CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )


C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000	FORMAT( A )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I10, :, 1X ) )


        END SUBROUTINE RDUNCERT
