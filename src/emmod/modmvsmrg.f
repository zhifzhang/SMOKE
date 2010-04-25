
        MODULE MODMVSMRG

!***********************************************************************
!  Module body starts at line
!
!  DESCRIPTION:
!     This module contains the public variables and allocatable arrays 
!     used by Movesmrg.
!
!  PRECONDITIONS REQUIRED:
!
!  SUBROUTINES AND FUNCTIONS CALLED:
!
!  REVISION HISTORY:
!     Created 4/10 by C. Seppanen
!
!***************************************************************************
!
! Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
!                System
! File: @(#)$Id$
!
! COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
! All Rights Reserved
! 
! Carolina Environmental Program
! University of North Carolina at Chapel Hill
! 137 E. Franklin St., CB# 6116
! Chapel Hill, NC 27599-6116
! 
! smoke@unc.edu
!
! Pathname: $Source$
! Last updated: $Date$ 
!
!****************************************************************************

        IMPLICIT NONE

        INCLUDE 'EMPRVT3.EXT'

C.........  Program settings
        LOGICAL, PUBLIC :: RPDFLAG  ! mode is rate-per-distance
        LOGICAL, PUBLIC :: RPVFLAG  ! mode is rate-per-vehicle/profile
        
        CHARACTER(300), PUBLIC :: MVFILDIR  ! directory for MOVES output files

C.........  Meteorology information
        CHARACTER(IOVLEN3), PUBLIC :: TVARNAME  ! name of temperature variable to read
        CHARACTER(16), PUBLIC :: METNAME        ! logical name for meteorology file

C.........  Text file unit numbers        
        INTEGER, PUBLIC :: XDEV         ! unit no. for county cross-reference file
        INTEGER, PUBLIC :: MDEV         ! unit no. for county fuel month file
        INTEGER, PUBLIC :: FDEV         ! unit no. for reference county file listing

C.........  Ungridding matrix data        
        CHARACTER(16), PUBLIC :: MGUNAME         ! logical name
        INTEGER,       PUBLIC :: MNGUMAT         ! number of ungridding matrix entries

C.........  Source to grid cell lookups
        INTEGER, ALLOCATABLE, PUBLIC :: NSRCCELLS( : )      ! no. cells for each source
        INTEGER, ALLOCATABLE, PUBLIC :: SRCCELLS( :,: )     ! list of cells for each source
        REAL,    ALLOCATABLE, PUBLIC :: SRCCELLFRACS( :,: ) ! grid cell fractions for each source

C.........  Reference county information
        INTEGER, ALLOCATABLE, PUBLIC :: NREFSRCS( : )       ! no. sources for each ref county
        INTEGER, ALLOCATABLE, PUBLIC :: REFSRCS( :,: )      ! list of srcs for each ref county
        CHARACTER(100), ALLOCATABLE, PUBLIC :: MRCLIST( : ) ! emfac file for each ref county

C.........  Emission factors data
        INTEGER, ALLOCATABLE, PUBLIC :: EMPROCIDX( : )    ! index of emission process name
        INTEGER, ALLOCATABLE, PUBLIC :: EMPOLIDX( : )     ! index of emission pollutant name

        INTEGER, PUBLIC :: NEMTEMPS                       ! no. temperatures for current emision factors
        REAL, ALLOCATABLE, PUBLIC :: EMTEMPS( : )         ! list of temps for emission factors

        REAL, ALLOCATABLE, PUBLIC :: RPDEMFACS( :,:,:,:,: )  ! rate-per-distance emission factors
                                                             ! SCC, speed bin, temp, process, pollutant

        REAL, ALLOCATABLE, PUBLIC :: RPVEMFACS( :,:,:,:,: )  ! rate-per-vehicle emission factors
                                                             ! SCC, hour, temp, process, pollutant

        END MODULE MODMVSMRG