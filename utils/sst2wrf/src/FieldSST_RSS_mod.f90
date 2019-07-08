!------------------------------------------------------------------------------
! NASA/GSFC, Software Integration & Visualization Office, Code 610.3
!------------------------------------------------------------------------------
!
! MODULE:  FieldSST_RSS_mod
!
! AUTHOR:
! Eric Kemp, NGIS 
!
! DESCRIPTION:
! Defines FieldSST_RSS data type and associated routines, for retrieving
! sea surface temperature data generated by Remote Sensing Systems (RSS).
!
! REVISION HISTORY:
! 05 Apr 2010 - Initial version
! 15 Apr 2010 - Added method to reset missing/bad SST values to 0 K (will be
!               rejected by REAL).
! 27 May 2010 - Missing/bad SST values changed to -9999.
! 28 May 2010 - Sea ice SST values changed to 270.
! 31 Oct 2014 - Updated for v4.0 MW and v3.0 mw_ir (Jossy P. Jacob)
!------------------------------------------------------------------------------

module FieldSST_RSS_mod

  ! Use external modules
  use TimeUtil_mod, only: calcMonthDayOfMonth

  ! Force explicit variable declarations
  implicit none

  ! Force explicit public declarations
  private

  ! Internal parameters
  integer,parameter :: MAX_FILENAME = 150
  real,parameter :: MISSING = -9999
  real,parameter :: BAD_SST = -9999
  real,parameter :: LAND_SST = -9999
  real,parameter :: SEAICE_SST = 270
  real,parameter :: MISSING_SST = -1.E30

  ! Parameters for MWIR file
  integer,parameter :: FILETYPE_MWIR = 1
  integer,parameter :: LON_DIM_MWIR = 4096
  integer,parameter :: LAT_DIM_MWIR = 2048
  real,parameter :: DLON_MWIR = 360./4096.
  real,parameter :: DLAT_MWIR = 180./2048.
  real,parameter :: SW_LON_MWIR = DLON_MWIR - (DLON_MWIR/2.)
  real,parameter :: SW_LAT_MWIR = DLAT_MWIR - (90+DLAT_MWIR/2.)
  ! Parameter for MW file
  integer,parameter :: FILETYPE_MW = 2
  integer,parameter :: LON_DIM_MW = 1440
  integer,parameter :: LAT_DIM_MW = 720
  real,parameter :: DLON_MW = 360./1440.
  real,parameter :: DLAT_MW = 180./720.
  real,parameter :: SW_LON_MW = DLON_MW - 0.125
  real,parameter :: SW_LAT_MW = DLAT_MW - 90.125

  ! Parameter for TMI AMSRE file
  integer,parameter :: FILETYPE_TMI_AMSRE = 3
  integer,parameter :: LON_DIM_TMI_AMSRE = 1440
  integer,parameter :: LAT_DIM_TMI_AMSRE = 720
  real,parameter :: DLON_TMI_AMSRE = 360./1440.
  real,parameter :: DLAT_TMI_AMSRE = 180./720.
  real,parameter :: SW_LON_TMI_AMSRE = DLON_TMI_AMSRE - 0.125
  real,parameter :: SW_LAT_TMI_AMSRE = DLAT_TMI_AMSRE - 90.125

  real,parameter :: MISSING_DATA_1 = 251
  real,parameter :: SEA_ICE = 252
  real,parameter :: MISSING_DATA_2 = 253
  real,parameter :: MISSING_DATA_3 = 254
  real,parameter :: LAND_MASS = 255
  real,parameter :: POSSIBLE_SEA_ICE = 2252 ! EMK NUWRF

  ! Define public data type
  public :: FieldSST_RSS
  type FieldSST_RSS
     character(len=MAX_FILENAME) :: filename
     integer :: nx
     integer :: ny
     real :: dLon
     real :: dLat
     real(4),allocatable :: sstData(:,:)
     real, allocatable :: sstMask(:,:)
     real, allocatable :: sstErr(:,:)
     real :: swLat
     real :: swLon
     integer :: year
     integer :: month
     integer :: day
     integer :: hour
     character(len=1) :: units
  end type FieldSST_RSS

  ! Declare public "methods"
  public :: createFieldSST_RSS
  public :: destroyFieldSST_RSS
  public :: convertToKelvin
  public :: setMissingSST

contains

  !----------------------------------------------------------------------------
  ! ROUTINE:
  ! createFieldSST_RSS
  !
  ! DESCRIPTION:
  ! Public "constructor method" for FieldSST_RSS data type.
  !----------------------------------------------------------------------------

  function createFieldSST_RSS(inputDirectory,instrument,year,dayOfYear, &
       version) result (this)
    
    ! Force explicit variable declarations
    implicit none

    ! Arguments
    character(len=*),intent(in) :: inputDirectory
    character(len=*),intent(in) :: instrument
    integer,intent(in) :: year
    integer,intent(in) :: dayOfYear
    character(len=*),intent(in) :: version

    ! Return variable
    type(FieldSST_RSS) :: this

    ! Local variables
    character(len=256) :: sstFileName
    integer :: sstFileType
    integer(4) :: file_exists
    integer :: i,j

    ! Check instruments
    if (trim(instrument) == trim("mw_ir")) then
       sstFileType = FILETYPE_MWIR
    else if ( trim(instrument) == "mw") then
       sstFileType = FILETYPE_MW
    else if (trim(instrument) == trim("tmi_amsre") .or. &
         trim(instrument) == trim("amsre") .or. &
         trim(instrument) == trim("tmi")) then
       sstFileType = FILETYPE_TMI_AMSRE

    else
       print*,'ERROR, invalid instrument type selected!'
       print*,'Supported are mw_ir, mw, tmi_amsre, amsre, and tmi'
       print*,'instrument = ',trim(instrument)
       stop
    end if

    if (sstFileType == FILETYPE_MWIR) then
    ! Build SST filename
       write(sstFilename,'(A,A,A,A,I4.4,A,I3.3,A,A)') &
       trim(inputDirectory),'/',trim(instrument), &
       ".fusion.",year,".",dayOfYear,".", &
       trim(version)
       print *, sstFilename, trim(sstFilename)
       this%nx = LON_DIM_MWIR
       this%ny = LAT_DIM_MWIR
       this%dLon = DLON_MWIR
       this%dLat = DLAT_MWIR
       this%swLon = SW_LON_MWIR
       this%swLat = SW_LAT_MWIR
       allocate(this%sstData(this%nx,this%ny))
       allocate(this%sstErr(this%nx,this%ny))
       allocate(this%sstMask(this%nx,this%ny))
       call read_rss_mwir_sst(sstFileName,this%sstData,this%sstErr, this%sstMask, file_exists)
    else if (sstFileType == FILETYPE_TMI_AMSRE) then
    ! Build SST filename
       write(sstFilename,'(A,A,A,A,I4.4,A,I3.3,A,A)') &
       trim(inputDirectory),'/',trim(instrument), &
       ".fusion.",year,".",dayOfYear,".",trim(version)
       print *, sstFilename, trim(sstFilename)
       this%nx = LON_DIM_TMI_AMSRE
       this%ny = LAT_DIM_TMI_AMSRE
       this%dLon = DLON_TMI_AMSRE
       this%dLat = DLAT_TMI_AMSRE
       this%swLon = SW_LON_TMI_AMSRE
       this%swLat = SW_LAT_TMI_AMSRE
       allocate(this%sstData(this%nx,this%ny))
       allocate(this%sstErr(this%nx,this%ny))
       allocate(this%sstMask(this%nx,this%ny))
       call read_rss_oisst_v4(sstFileName,this%sstData,this%sstErr,this%sstMask,file_exists)
    else if (sstFileType == FILETYPE_MW) then                                                                                             
    ! Build SST filename                                                                                                                  
       write(sstFilename,'(A,A,A,A,I4.4,A,I3.3,A,A,A)') &                                                                                 
       trim(inputDirectory),'/',trim(instrument), &                                                                                       
       ".fusion.",year,".",dayOfYear,".", &                                                                                               
       trim(version)                                                                                                                 
       print *, sstFilename, trim(sstFilename)                                                                                            
       this%nx = LON_DIM_MW                                                                                                        
       this%ny = LAT_DIM_MW                                                                                                        
       this%dLon = DLON_MW                                                                                                         
       this%dLat = DLAT_MW                                                                                                         
       this%swLon = SW_LON_MW                                                                                                      
       this%swLat = SW_LAT_MW                                                                                                      
       allocate(this%sstData(this%nx,this%ny))                                                                                            
       allocate(this%sstErr(this%nx,this%ny))                                                                                             
       allocate(this%sstMask(this%nx,this%ny))                                                                                            
       call read_rss_oisst_v4(sstFileName,this%sstData,this%sstErr,this%sstMask,file_exists)    
    else
       print*,'ERROR, invalid SST file type selected!'
       print*,'Valid options are:'
       print*,'   MWIR data =      ',FILETYPE_MWIR
       print*,'   MW data = ',FILETYPE_MW
       print*,'   TMI_AMSRE data = ',FILETYPE_TMI_AMSRE
       print*,'sstFileType = ',sstFileType
       stop
    end if

    if (file_exists /= 0) then
       print*,'ERROR, file ',trim(sstFileName),' does not exist!'
       stop
    end if

    this%units = 'C'

    ! Save time information
    this%year = year
    call calcMonthDayOfMonth(year,dayOfYear,this%month,this%day)

    if (sstFileType == FILETYPE_MWIR) then
       this%hour = 12 ! Valid at 12 UTC
    else
       ! SST data is defined as valid for 8 am local time for entire grid.
       ! We arbitrarily set the UTC time as 8:00, since that is the local time
       ! for 0 deg longitude.
       this%hour = 8 
    end if

    ! Build SST Mask
    !allocate(this%sstMask(this%nx,this%ny))
    do j = 1,this%ny
       do i = 1,this%nx
          if (this%sstData(i,j) == LAND_MASS) then
             this%sstMask(i,j) = 1
          else if (this%sstData(i,j) == SEA_ICE) then
             this%sstMask(i,j) = 2
          else if (this%sstData(i,j) == MISSING_DATA_1 .or. &
                   this%sstData(i,j) == MISSING_DATA_2 .or. &
                   this%sstData(i,j) == MISSING_DATA_3) then
             this%sstMask(i,j) = 3
          !EMK NUWRF...Retain "possible" sea ice flag
          else if (this%sstErr(i,j) == POSSIBLE_SEA_ICE) then
             this%sstMask(i,j) = -2
          else
             this%sstMask(i,j) = 0
          end if
       end do
    end do
    print *, 'Create: max and min',maxval(this%sstData), minval(this%sstData)

    return
  end function createFieldSST_RSS

  !----------------------------------------------------------------------------
  ! ROUTINE:
  ! destroyFieldSST_RSS
  !
  ! DESCRIPTION:
  ! Public "destructor method" for FieldSST_RSS data type.
  !----------------------------------------------------------------------------

  subroutine destroyFieldSST_RSS(this)
    
    ! Force explicit variable declarations
    implicit none

    ! Arguments
    type(FieldSST_RSS),intent(inout) :: this

    ! Clean up data structure
    this%nx = 0
    this%ny = 0
    this%dLon = MISSING
    this%dLat = MISSING
    this%swLat = MISSING
    this%swLon = MISSING
    if (allocated(this%sstData)) deallocate(this%sstData)
    if (allocated(this%sstMask)) deallocate(this%sstMask)
    this%year = MISSING
    this%month = MISSING
    this%day = MISSING
    this%hour = MISSING
    this%units = ' '
    return
  end subroutine destroyFieldSST_RSS

  !----------------------------------------------------------------------------
  ! ROUTINE:
  ! convertToKelvin
  !
  ! DESCRIPTION:
  ! Public method for converting SST units from Celsius to Kelvin.
  !----------------------------------------------------------------------------

  subroutine convertToKelvin(this)

    ! Force explicit variable declarations
    implicit none

    ! Arguments
    type(FieldSST_RSS),intent(inout) :: this

    ! Local variables
    integer :: i,j

    ! Sanity check
    if (.not. allocated(this%sstData)) then
       print*,'ERROR, trying to convert SST from Celsius to Kelvin'
       print*,' but array is not allocated!'
       stop
    end if

    if (this%units /= 'C') then
       print*,'ERROR, expecting current SST units to be Celsius!'
       print*,'units = ',this%units
       stop
    end if

    ! Convert SST to Kelvin
    do j = 1,this%ny
       do i = 1,this%nx
          if (this%sstMask(i,j) > 0) cycle
          this%sstData(i,j) = this%sstData(i,j) + 273.15
       end do
    end do
    this%units='K'

    return
  end subroutine convertToKelvin

  !----------------------------------------------------------------------------
  ! ROUTINE:
  ! setMissingSST
  !
  ! DESCRIPTION:
  ! Public method for resetting missing/bad SST values to a specific value
  !----------------------------------------------------------------------------

  subroutine setMissingSST(this)

    ! Force explicit declarations
    implicit none

    ! Arguments
    type(FieldSST_RSS), intent(inout) :: this

    ! Local variables
    integer :: i,j

    ! Loop through and reset missing SST values
    do j = 1,this%ny
       do i = 1,this%nx
          if (this%sstMask(i,j) == 1) then
             this%sstData(i,j) = LAND_SST
          else if (this%sstMask(i,j) == 2) then
             this%sstData(i,j) = SEAICE_SST
          else if (this%sstMask(i,j) == 3) then
             this%sstData(i,j) = BAD_SST
          ! EMK NUWRF...Set "possible sea ice" data to missing
!          else if (this%sstMask(i,j) == -2) then
!             this%sstData(i,j) = BAD_SST             
          end if
       end do
    end do
   ! Mask the SST data for sstMask
     
     where (this%sstData < MISSING_DATA_1 ) this%sstData = MISSING_SST 
    print *, 'SetMissing: max and min',maxval(this%sstData), minval(this%sstData)
    print *, MISSING_SST 
   ! do j = 1,this%ny
   !    do i = 1,this%nx
   !       if (this%sstData(i,j) < MISSING_DATA_1 ) then
   !          this%sstData(i,j) = MISSING_SST
   !       endif
   !    enddo
   ! enddo
   ! print *, 'max and min',maxval(this%sstData), minval(this%sstData)

    return
  end subroutine setMissingSST
end module FieldSST_RSS_mod
