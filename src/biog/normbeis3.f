
        PROGRAM NORMBEIS3

C***********************************************************************
C
C  DESCRIPTION:  Produces normalized biogenic emissions for use with
C                SMOKE-BEIS versions 3.09 or 3.12
C
C  SUBROUTINES AND FUNCTIONS CALLED: Calls Normbeis309 or Normbeis312
C
C  REVISION  HISTORY: 3/00 Prototype, Jeff Vukovich
C                     8/04 Integrated v3.12, C. Seppanen
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
C All Rights Reserved
C 
C Carolina Environmental Program
C University of North Carolina at Chapel Hill
C 137 E. Franklin St., CB# 6116
C Chapel Hill, NC 27599-6116
C 
C smoke@unc.edu
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***********************************************************************

        IMPLICIT NONE

C.........  Includes
        INCLUDE 'IODECL3.EXT'   ! I/O API function declarations
        
C.........  Local parameters
        CHARACTER(50), PARAMETER :: CVSW = '$Name$' ! CVS release tag
  
C.........  External functions
        LOGICAL, EXTERNAL :: ENVYN

C.........  Logical names and unit numbers
        INTEGER         LDEV    !  unit number for log device

C.........  Other local variables
        INTEGER         IOS     !  I/O status
        
        CHARACTER(16)   BEISVER !  version of BEIS3 to use
        CHARACTER(300)  MESG    !  message buffer
        
        CHARACTER(16) :: PROGNAME = 'NORMBEIS3'   !  program name

C***********************************************************************
C   begin body of program NORMBEIS3

        LDEV = INIT3()

C.........  Write out copyright, version, web address, header info, and prompt
C           to continue running the program.
        CALL INITEM( LDEV, CVSW, PROGNAME )

C.........  Get the BEIS3 model version to use
        MESG = 'Version of BEIS3 to use'
        CALL ENVSTR( 'BEIS_VERSION', MESG, '3.12', BEISVER, IOS )
        
        SELECT CASE( BEISVER )
        CASE( '3.09' )
            CALL NORMBEIS309( CVSW )
        CASE( '3.12' )
            CALL NORMBEIS312( CVSW )
        CASE DEFAULT
            MESG = 'ERROR: Unrecognized BEIS_VERSION setting; valid ' //
     &             'settings are 3.09 and 3.12'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END SELECT

C.........  End of program
        CALL M3EXIT( PROGNAME, 0, 0, ' ', 0 )

        END PROGRAM NORMBEIS3 

