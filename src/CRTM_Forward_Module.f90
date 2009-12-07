!
! CRTM_Forward_Module
!
! Module containing the CRTM forward model function.
!
!
! CREATION HISTORY:
!       Written by:     Paul van Delst, CIMSS/SSEC 29-Jun-2004
!                       paul.vandelst@ssec.wisc.edu
!

MODULE CRTM_Forward_Module


  ! ------------
  ! Module usage
  ! ------------
  USE Type_Kinds,               ONLY: fp
  USE Message_Handler,          ONLY: SUCCESS, FAILURE, WARNING, Display_Message
  USE CRTM_Parameters,          ONLY: SET,NOT_SET,ZERO,ONE, &
                                      MAX_N_PROFILES      , &
                                      MAX_N_PHASE_ELEMENTS, &
                                      MAX_N_LEGENDRE_TERMS, &
                                      MAX_N_STOKES        , &
                                      MAX_N_ANGLES        , &
                                      MAX_N_AZI           , &
                                      MAX_SOURCE_ZENITH_ANGLE
  USE CRTM_SpcCoeff,            ONLY: SC, VISIBLE_SENSOR
  USE CRTM_Atmosphere_Define,   ONLY: CRTM_Atmosphere_type, &
                                      CRTM_Destroy_Atmosphere
  USE CRTM_Surface_Define,      ONLY: CRTM_Surface_type
  USE CRTM_GeometryInfo_Define, ONLY: CRTM_GeometryInfo_type
  USE CRTM_ChannelInfo_Define,  ONLY: CRTM_ChannelInfo_type
  USE CRTM_Options_Define,      ONLY: CRTM_Options_type
  USE CRTM_Atmosphere,          ONLY: CRTM_AddLayers_Atmosphere, &
                                      iAtm_type, &
                                      Destroy_iAtm
  USE CRTM_GeometryInfo,        ONLY: CRTM_Compute_GeometryInfo
  USE CRTM_AtmAbsorption,       ONLY: CRTM_AAVariables_type      , &
                                      CRTM_APVariables_type      , &
                                      CRTM_Compute_AtmAbsorption , &
                                      CRTM_Destroy_Predictor     , &
                                      CRTM_Allocate_Predictor    , &
                                      CRTM_Compute_Predictors    , &
                                      CRTM_Predictor_type    
  USE CRTM_AtmScatter_Define,   ONLY: CRTM_AtmScatter_type    , &
                                      CRTM_Allocate_AtmScatter, &
                                      CRTM_Destroy_AtmScatter
  USE CRTM_AerosolScatter,      ONLY: CRTM_ASVariables_type      , &
                                      CRTM_Compute_AerosolScatter
  USE CRTM_CloudScatter,        ONLY: CRTM_CSVariables_type    , &
                                      CRTM_Compute_CloudScatter
  USE CRTM_AtmOptics,           ONLY: CRTM_AOVariables_type , &
                                      CRTM_Combine_AtmOptics
  USE CRTM_SfcOptics,           ONLY: CRTM_SfcOptics_type    , &
                                      CRTM_Allocate_SfcOptics, &
                                      CRTM_Destroy_SfcOptics , &
                                      CRTM_Compute_SurfaceT 
  USE CRTM_RTSolution,          ONLY: CRTM_RTSolution_type    , &
                                      CRTM_Compute_nStreams   , &
                                      CRTM_Compute_RTSolution
  USE RTV_Define,               ONLY: CRTM_RTVariables_type   , &
                                      Allocate_RTV            , &
                                      Destroy_RTV
  USE CRTM_AntCorr,             ONLY: CRTM_Compute_AntCorr
  USE CRTM_MoleculeScatter,     ONLY: CRTM_Compute_MoleculeScatter
  USE CRTM_SensorInput_Define,  ONLY: CRTM_SensorInput_type, &
                                      ASSIGNMENT(=)

  ! -----------------------
  ! Disable implicit typing
  ! -----------------------
  IMPLICIT NONE


  ! ------------
  ! Visibilities
  ! ------------
  ! Everything private by default
  PRIVATE
  ! Public procedures
  PUBLIC :: CRTM_Forward


  ! -----------------
  ! Module parameters
  ! -----------------
  ! RCS Id for the module
  CHARACTER(*), PARAMETER :: MODULE_RCS_ID = &
  '$Id$'
 

CONTAINS


!--------------------------------------------------------------------------------
!:sdoc+:
!
! NAME:
!       CRTM_Forward
!
! PURPOSE:
!       Function that calculates top-of-atmosphere (TOA) radiances
!       and brightness temperatures for an input atmospheric profile or
!       profile set and user specified satellites/channels.
!
! CALLING SEQUENCE:
!       Error_Status = CRTM_Forward( Atmosphere             , &
!                                    Surface                , &
!                                    GeometryInfo           , &
!                                    ChannelInfo            , &
!                                    RTSolution             , &
!                                    Options    =Options    , &
!                                    RCS_Id     =RCS_Id     , &
!                                    Message_Log=Message_Log  )
!
! INPUT ARGUMENTS:
!       Atmosphere:     Structure containing the Atmosphere data.
!                       UNITS:      N/A
!                       TYPE:       CRTM_Atmosphere_type
!                       DIMENSION:  Rank-1 (n_Profiles)
!                       ATTRIBUTES: INTENT(IN)
!
!       Surface:        Structure containing the Surface data.
!                       UNITS:      N/A
!                       TYPE:       CRTM_Surface_type
!                       DIMENSION:  Same as input Atmosphere structure
!                       ATTRIBUTES: INTENT(IN)
!
!       GeometryInfo:   Structure containing the view geometry
!                       information.
!                       UNITS:      N/A
!                       TYPE:       CRTM_GeometryInfo_type
!                       DIMENSION:  Same as input Atmosphere structure
!                       ATTRIBUTES: INTENT(IN)
!
!       ChannelInfo:    Structure returned from the CRTM_Init() function
!                       that contains the satellite/sensor channel index
!                       information.
!                       UNITS:      N/A
!                       TYPE:       CRTM_ChannelInfo_type
!                       DIMENSION:  Rank-1 (n_Sensors)
!                       ATTRIBUTES: INTENT(IN)
!
! OUTPUT ARGUMENTS:
!       RTSolution:     Structure containing the soluition to the RT equation
!                       for the given inputs.
!                       UNITS:      N/A
!                       TYPE:       CRTM_RTSolution_type
!                       DIMENSION:  Rank-2 (n_Channels x n_Profiles)
!                       ATTRIBUTES: INTENT(IN OUT)
!
! OPTIONAL INPUT ARGUMENTS:
!       Options:        Options structure containing the optional arguments
!                       for the CRTM.
!                       UNITS:      N/A
!                       TYPE:       CRTM_Options_type
!                       DIMENSION:  Same as input Atmosphere structure
!                       ATTRIBUTES: INTENT(IN), OPTIONAL
!
!       Message_Log:    Character string specifying a filename in which any
!                       messages will be logged. If not specified, or if an
!                       error occurs opening the log file, the default action
!                       is to output messages to the screen.
!                       UNITS:      N/A
!                       TYPE:       CHARACTER(*)
!                       DIMENSION:  Scalar
!                       ATTRIBUTES: INTENT(IN), OPTIONAL
!
! OPTIONAL OUTPUT ARGUMENTS:
!       RCS_Id:         Character string containing the Revision Control
!                       System Id field for the module.
!                       UNITS:      N/A
!                       TYPE:       CHARACTER(*)
!                       DIMENSION:  Scalar
!                       ATTRIBUTES: INTENT(OUT), OPTIONAL
!
! FUNCTION RESULT:
!       Error_Status:   The return value is an integer defining the error status.
!                       The error codes are defined in the Message_Handler module.
!                       If == SUCCESS the computation was sucessful
!                          == FAILURE an unrecoverable error occurred
!                       UNITS:      N/A
!                       TYPE:       INTEGER
!                       DIMENSION:  Scalar
!
! COMMENTS:
!       - The Options optional input structure argument contains
!         spectral information (e.g. emissivity) that must have the same
!         spectral dimensionality (the "L" dimension) as the output
!         RTSolution structure.
!
!       - The INTENT on the output RTSolution argument is IN OUT rather
!         than just OUT. This is necessary because the argument may be defined
!         upon input. To prevent memory leaks, the IN OUT INTENT is a must.
!
!:sdoc-:
!--------------------------------------------------------------------------------

  FUNCTION CRTM_Forward( Atmosphere  , &  ! Input, M
                         Surface     , &  ! Input, M    
                         GeometryInfo, &  ! Input, M    
                         ChannelInfo , &  ! Input, n_Sensors
                         RTSolution  , &  ! Output, L x M   
                         Options     , &  ! Optional input, M    
                         RCS_Id      , &  ! Revision control
                         Message_Log ) &  ! Error messaging
                       RESULT( Error_Status )
    ! Arguments
    TYPE(CRTM_Atmosphere_type),        INTENT(IN)     :: Atmosphere(:)     ! M
    TYPE(CRTM_Surface_type),           INTENT(IN)     :: Surface(:)        ! M
    TYPE(CRTM_GeometryInfo_type),      INTENT(IN OUT) :: GeometryInfo(:)   ! M
    TYPE(CRTM_ChannelInfo_type),       INTENT(IN)     :: ChannelInfo(:)    ! n_Sensors 
    TYPE(CRTM_RTSolution_type),        INTENT(IN OUT) :: RTSolution(:,:)   ! L x M
    TYPE(CRTM_Options_type), OPTIONAL, INTENT(IN)     :: Options(:)        ! M
    CHARACTER(*),            OPTIONAL, INTENT(OUT)    :: RCS_Id
    CHARACTER(*),            OPTIONAL, INTENT(IN)     :: Message_Log
    ! Function result
    INTEGER :: Error_Status
    ! Local parameters
    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CRTM_Forward'
    ! Local variables
    CHARACTER(256) :: Message
    LOGICAL :: Options_Present
    LOGICAL :: User_Emissivity
    LOGICAL :: User_Direct_Reflectivity
    LOGICAL :: User_AntCorr
    LOGICAL :: Compute_AntCorr
    INTEGER :: n, n_Sensors,  SensorIndex
    INTEGER :: l, n_Channels, ChannelIndex
    INTEGER :: m, n_Profiles
    INTEGER :: ln
    INTEGER :: n_Full_Streams, mth_Azi
    INTEGER, DIMENSION(2) :: AllocStatus
    REAL(fp) :: Wavenumber
    ! Local sensor input structure
    TYPE(CRTM_SensorInput_type) :: SensorInput
    ! Local atmosphere structure for extra layering
    TYPE(CRTM_Atmosphere_type) :: Atm
    ! Component variables
    TYPE(CRTM_Predictor_type)     :: Predictor
    TYPE(CRTM_AtmScatter_type)    :: AtmOptics 
    TYPE(CRTM_SfcOptics_type)     :: SfcOptics
    ! Component variable internals
    TYPE(iAtm_type) :: iAtm             ! Atmosphere
    TYPE(CRTM_APVariables_type) :: APV  ! Predictor
    TYPE(CRTM_AAVariables_type) :: AAV  ! AtmAbsorption
    TYPE(CRTM_CSVariables_type) :: CSV  ! CloudScatter
    TYPE(CRTM_ASVariables_type) :: ASV  ! AerosolScatter
    TYPE(CRTM_AOVariables_type) :: AOV  ! AtmOptics
    TYPE(CRTM_RTVariables_type) :: RTV  ! RTSolution

 
    ! ------
    ! Set up
    ! ------
    Error_Status = SUCCESS
    IF ( PRESENT( RCS_Id ) ) RCS_Id = MODULE_RCS_ID


    ! ----------------------------------------
    ! If no sensors or channels, simply return
    ! ----------------------------------------
    n_Sensors  = SIZE(ChannelInfo)
    n_Channels = SUM(ChannelInfo%n_Channels)
    IF ( n_Sensors == 0 .OR. n_Channels == 0 ) RETURN


    ! ---------------------------------
    ! Output RTSolution array too small
    ! ---------------------------------
    IF ( SIZE(RTSolution,DIM=1) < n_Channels ) THEN
      Error_Status = FAILURE
      WRITE(Message,'("Output RTSolution structure array too small (",i0,&
                     &") to hold results for the number of requested channels (",i0,")")') &
                     SIZE(RTSolution,DIM=1), n_Channels
      CALL Display_Message( ROUTINE_NAME, &
                            TRIM(Message), &
                            Error_Status, &
                            Message_Log=Message_Log )
      RETURN
    END IF


    ! ----------------------------
    ! Check the number of profiles
    ! ----------------------------
    ! Number of atmospheric profiles.
    n_Profiles = SIZE(Atmosphere)

    ! Check that the number of profiles is not greater than
    ! MAX_N_PROFILES. This is simply a limit to restrict the
    ! size of the input arrays so they're not TOO big.
    IF ( n_Profiles > MAX_N_PROFILES ) THEN
      Error_Status = FAILURE
      WRITE(Message,'("Number of passed profiles (",i0,&
                     &") > maximum number of profiles allowed(",i0,")")') &
                    n_Profiles, MAX_N_PROFILES
      CALL Display_Message( ROUTINE_NAME, &
                            TRIM(Message), &
                            Error_Status, &
                            Message_Log=Message_Log )
      RETURN
    END IF

    ! Check the profile dimensionality
    ! of the other mandatory arguments
    IF ( SIZE(Surface)          /= n_Profiles .OR. &
         SIZE(GeometryInfo)     /= n_Profiles .OR. &
         SIZE(RTSolution,DIM=2) /= n_Profiles      ) THEN
      Error_Status = FAILURE
      CALL Display_Message( ROUTINE_NAME, &
                            'Inconsistent profile dimensionality for '//&
                            'input arguments.', &
                            Error_Status, &
                            Message_Log=Message_Log )
      RETURN
    END IF

    ! Check the profile dimensionality
    ! of the other optional arguments
    Options_Present = .FALSE.
    IF ( PRESENT(Options) ) THEN
      Options_Present = .TRUE.
      IF ( SIZE(Options) /= n_Profiles ) THEN
        Error_Status = FAILURE
        CALL Display_Message( ROUTINE_NAME, &
                              'Inconsistent profile dimensionality for '//&
                              'Options optional input argument.', &
                              Error_Status, &
                              Message_Log=Message_Log )
        RETURN
      END IF
    END IF


    !#--------------------------------------------------------------------------#
    !#                           -- PROFILE LOOP --                             #
    !#--------------------------------------------------------------------------#
    Profile_Loop: DO m = 1, n_Profiles


      ! ---------------------------------------------
      ! Check the optional Options structure argument
      ! ---------------------------------------------
      ! Default action is NOT to use user specified Options
      User_Emissivity = .FALSE.
      User_AntCorr    = .FALSE.
      !.... other User_XXX flags as added.

      ! Check the Options argument
      IF (Options_Present) THEN

        ! Check if the supplied emissivity should be used
        IF ( Options(m)%Emissivity_Switch == SET ) THEN
          ! Are the channel dimensions consistent
          IF ( Options(m)%n_Channels < n_Channels ) THEN
            Error_Status = FAILURE
            WRITE( Message, '( "Input Options channel dimension (", i0, ") is less ", &
                              &"than the number of requested channels (",i0, ")" )' ) &
                            Options(m)%n_Channels, n_Channels
            CALL Display_Message( ROUTINE_NAME, &
                                  TRIM(Message), &
                                  Error_Status, &
                                  Message_Log=Message_Log )
            RETURN
          END IF
          ! Set to use the supplied emissivity
          User_Emissivity = .TRUE.
          ! Check if the supplied direct reflectivity should be used
          User_Direct_Reflectivity = .FALSE.
          IF ( Options(m)%Direct_Reflectivity_Switch == SET ) User_Direct_Reflectivity = .TRUE.
        END IF
        
        ! Check if antenna correction should be attempted
        IF ( Options(m)%Antenna_Correction == SET ) User_AntCorr = .TRUE.

        ! Copy over sensor-specific input
        SensorInput = Options(m)%SensorInput 
      END IF


      ! ------------------------
      ! Compute derived geometry
      ! ------------------------
      Error_Status = CRTM_Compute_GeometryInfo( GeometryInfo(m), &
                                                Message_Log=Message_Log )
      IF ( Error_Status /= SUCCESS ) THEN
        Error_Status = FAILURE
        WRITE( Message,'("Error computing derived GeometryInfo components for profile #",i0)' ) m
        CALL Display_Message( ROUTINE_NAME, &
                              TRIM(Message), &
                              Error_Status, &
                              Message_Log=Message_Log )
        RETURN
      END IF


      ! ----------------------------------------------
      ! Add extra layers to current atmosphere profile
      ! if necessary to handle upper atmosphere
      ! ----------------------------------------------
      Error_Status = CRTM_AddLayers_Atmosphere( Atmosphere(m)          , &  ! Input
                                                Atm                    , &  ! Output
                                                iAtm                   , &  ! Internal variable output
                                                Message_Log=Message_Log  )  ! Error messaging
      IF ( Error_Status /= SUCCESS ) THEN
        Error_Status = FAILURE
        WRITE( Message,'("Error adding extra layers to profile #",i0)' ) m
        CALL Display_Message( ROUTINE_NAME, &
                              TRIM(Message), &
                              Error_Status, &
                              Message_Log=Message_Log )
        RETURN
      END IF


      ! -----------------------------
      ! Allocate all local structures
      ! -----------------------------
      ! The AtmOptics structure
      AllocStatus(1)=CRTM_Allocate_AtmScatter( Atm%n_Layers           , &  ! Input
                                               MAX_N_LEGENDRE_TERMS   , &  ! Input
                                               MAX_N_PHASE_ELEMENTS   , &  ! Input
                                               AtmOptics              , &  ! Output
                                               Message_Log=Message_Log  )  ! Error messaging
      ! The SfcOptics structure
      AllocStatus(2)=CRTM_Allocate_SfcOptics( MAX_N_ANGLES           , &  ! Input
                                              MAX_N_STOKES           , &  ! Input
                                              SfcOptics              , &  ! Output
                                              Message_Log=Message_Log  )  ! Error messaging
      IF ( ANY(AllocStatus /= SUCCESS) ) THEN
        Error_Status=FAILURE
        WRITE( Message,'("Error allocating local data structures for profile #",i0)' ) m
        CALL Display_Message( ROUTINE_NAME, &
                              TRIM(Message), &
                              Error_Status, &
                              Message_Log=Message_Log )
        RETURN
      END IF

      ! --------------------------                                
      ! Preprocess some input data                                
      ! --------------------------                                
      ! Average surface skin temperature for multi-surface types  
      CALL CRTM_Compute_SurfaceT( Surface(m), SfcOptics )         

      ! -----------
      ! Sensor loop
      ! -----------
      ! Initialise channel counter for channel(l)/sensor(n) count
      ln = 0
      
      Sensor_Loop: DO n = 1, n_Sensors

        ! Shorter name
        SensorIndex = ChannelInfo(n)%Sensor_Index

        ! Check if antenna correction to be applied for current sensor
        IF ( User_AntCorr .AND. SC(SensorIndex)%AC_Present .AND. GeometryInfo(m)%iFOV /= 0 ) THEN
          Compute_AntCorr = .TRUE.
        ELSE
          Compute_AntCorr = .FALSE.
        END IF

        ! -----------------------------
        ! Allocate predictor structure
        ! -----------------------------
        AllocStatus(1)=CRTM_Allocate_Predictor( SensorIndex            , &  ! Input
                                                Atm%n_Layers           , &  ! Input
                                                GeometryInfo(m)        , &  ! Input
                                                Predictor              , &  ! Output
                                                Message_Log=Message_Log  )  ! Error messaging
        ! The RTV structure
        AllocStatus(2) = SUCCESS
        IF(Atm%n_Clouds > 0 .OR. Atm%n_Aerosols > 0 &
                            .OR. SC(SensorIndex)%Sensor_Type == VISIBLE_SENSOR)THEN
          AllocStatus(2) = Allocate_RTV(RTV, &  ! Output
                                Message_Log=Message_Log ) ! Error messaging
        ENDIF                                   
        IF ( AllocStatus(1)    /= SUCCESS .OR. AllocStatus(2) /= SUCCESS ) THEN                    
          Error_Status=FAILURE                                                                      
          WRITE( Message,'("Error allocating predictor or RTV data structures for profile #",i0, &
                 &" and Sensor #", i0)' ) m, n       
          CALL Display_Message( ROUTINE_NAME, &                                                    
                                TRIM(Message), &                                                   
                                Error_Status, &                                                    
                                Message_Log=Message_Log )                                          
          RETURN                                                                                    
        END IF                                                                                      
 
        ! ------------------------------------------
        ! Compute predictors for AtmAbsorption calcs
        ! ------------------------------------------
        CALL CRTM_Compute_Predictors( SensorInput    , &  ! Input
                                      SensorIndex    , &  ! Input
                                      Atm            , &  ! Input
                                      GeometryInfo(m), &  ! Input
                                      Predictor      , &  ! Output
                                      APV              )  ! Internal variable output

        ! ------------
        ! Channel loop
        ! ------------
        Channel_Loop: DO l = 1, ChannelInfo(n)%n_Channels
 
          ! Shorter name
          ChannelIndex = ChannelInfo(n)%Channel_Index(l)
          
          ! Increment channel counter
          ln = ln + 1
          
          !#--------------------------------------------------------------------------#
          !#                -- INITIALISE OUTPUT STRUCTURE VARIABLES --               #
          !#                                                                          #
          !# These forward variables are only computed if there is significant        #
          !# scattering. Otherwise, they're set to zero                               #
          !#--------------------------------------------------------------------------#

            AtmOptics%Phase_Coefficient     = ZERO
            AtmOptics%Delta_Truncation      = ZERO
            AtmOptics%Single_Scatter_Albedo = ZERO               
!            AtmOptics%Optical_Depth = ZERO   
          ! ---------------------------------------------------------------
          ! Determine the number of streams (n_Full_Streams) in up+downward
          ! directions. Currently, n_Full_Streams is determined from the
          ! cloud parameters only. It will also use the aerosol parameters 
          ! when aerosol scattering is included.
          ! ---------------------------------------------------------------
          n_Full_Streams = CRTM_Compute_nStreams( Atm             , &  ! Input
                                                  SensorIndex     , &  ! Input
                                                  ChannelIndex    , &  ! Input
                                                  RTSolution(ln,m)  )  ! Output
          ! Transfer the number of streams
          ! to all the scattering structures
          AtmOptics%n_Legendre_Terms = n_Full_Streams


          ! --------------------------
          ! Compute the gas absorption
          ! --------------------------
          CALL CRTM_Compute_AtmAbsorption( SensorInput  , &  ! Input
                                           SensorIndex  , &  ! Input
                                           ChannelIndex , &  ! Input
                                           Predictor    , &  ! Input
                                           AtmOptics    , &  ! Output
                                           AAV            )  ! Internal variable output


          ! -------------------------------------------
          ! Compute the molecular scattering properties
          ! -------------------------------------------
          ! Solar radiation
          IF( SC(SensorIndex)%Solar_Irradiance(ChannelIndex) > ZERO .AND. &
              GeometryInfo(m)%Source_Zenith_Angle < MAX_SOURCE_ZENITH_ANGLE) THEN
             RTV%Solar_Flag_true = .TRUE.
          END IF
          
          IF( SC(SensorIndex)%Sensor_Type == VISIBLE_SENSOR .and. RTV%Solar_Flag_true ) THEN 
            RTV%Visible_Flag_true = .TRUE.
            RTV%n_Azi = MAX_N_AZI            
            ! Rayleigh phase function has 0, 1, 2 components.
            IF( AtmOptics%n_Legendre_Terms < 4 ) THEN
              AtmOptics%n_Legendre_Terms = 4
              RTSolution(ln,m)%Scattering_FLAG = .TRUE.
              RTSolution(ln,m)%n_Full_Streams = AtmOptics%n_Legendre_Terms + 2
            END IF
            ! Get molecular scattering and extinction
            Wavenumber = SC(SensorIndex)%Wavenumber(ChannelIndex)
            Error_Status = CRTM_Compute_MoleculeScatter( Wavenumber,Atm,AtmOptics, &
                                                         Message_Log=Message_Log  )
            IF ( Error_Status /= SUCCESS ) THEN
              WRITE(Message,'("Error computing MoleculeScatter for ",a,&
                             &", channel ",i0,", profile #",i0)') &
                              TRIM(ChannelInfo(n)%Sensor_ID), &
                              ChannelInfo(n)%Sensor_Channel(l), &
                              m
              CALL Display_Message( ROUTINE_NAME, &
                                    TRIM(Message), &
                                    Error_Status, &
                                    Message_Log=Message_Log )
              RETURN
            END IF
          ELSE
            RTV%Visible_Flag_true = .FALSE.
            RTV%n_Azi = 0
          END IF        
                   

          ! -----------------------------------------------------------
          ! Compute the cloud particle absorption/scattering properties
          ! -----------------------------------------------------------
          IF( Atm%n_Clouds > 0 ) THEN
            Error_Status = CRTM_Compute_CloudScatter( Atm                    , &  ! Input
                                                      SensorIndex            , &  ! Input
                                                      ChannelIndex           , &  ! Input
                                                      AtmOptics              , &  ! Output
                                                      CSV                    , &  ! Internal variable output
                                                      Message_Log=Message_Log  )  ! Error messaging
            IF ( Error_Status /= SUCCESS ) THEN
              WRITE(Message,'("Error computing CloudScatter for ",a,&
                             &", channel ",i0,", profile #",i0)') &
                              TRIM(ChannelInfo(n)%Sensor_ID), &
                              ChannelInfo(n)%Sensor_Channel(l), &
                              m
              CALL Display_Message( ROUTINE_NAME, &
                                    TRIM(Message), &
                                    Error_Status, &
                                    Message_Log=Message_Log )
              RETURN
            END IF
          END IF


          ! ----------------------------------------------------
          ! Compute the aerosol absorption/scattering properties
          ! ----------------------------------------------------
          IF ( Atm%n_Aerosols > 0 ) THEN
            Error_Status = CRTM_Compute_AerosolScatter( Atm                    , &  ! Input
                                                        SensorIndex            , &  ! Input
                                                        ChannelIndex           , &  ! Input
                                                        AtmOptics              , &  ! In/Output
                                                        ASV                    , &  ! Internal variable output
                                                        Message_Log=Message_Log  )  ! Error messaging
            IF ( Error_Status /= SUCCESS ) THEN
              WRITE(Message,'("Error computing AerosolScatter for ",a,&
                             &", channel ",i0,", profile #",i0)') &
                              TRIM(ChannelInfo(n)%Sensor_ID), &
                              ChannelInfo(n)%Sensor_Channel(l), &
                              m
              CALL Display_Message( ROUTINE_NAME, &
                                    TRIM(Message), &
                                    Error_Status, &
                                    Message_Log=Message_Log )
              RETURN
            END IF
          END IF


          ! ---------------------------------------------------
          ! Compute the combined atmospheric optical properties
          ! ---------------------------------------------------
          CALL CRTM_Combine_AtmOptics( AtmOptics     , & ! In/Output
                                       AOV             ) ! Internal variable output


          ! ------------------------------------
          ! Fill the SfcOptics structure for the
          ! optional emissivity input case.
          ! ------------------------------------
          ! Indicate SfcOptics ARE to be computed
          SfcOptics%Compute_Switch = SET
          ! Change SfcOptics emissivity/reflectivity
          ! contents/computation status
          IF ( User_Emissivity ) THEN
            SfcOptics%Compute_Switch  = NOT_SET
            SfcOptics%Emissivity(1,1)       = Options(m)%Emissivity(ln)
            SfcOptics%Reflectivity(1,1,1,1) = ONE - Options(m)%Emissivity(ln)

            IF ( User_Direct_Reflectivity ) THEN
              SfcOptics%Direct_Reflectivity(1,1) = Options(m)%Direct_Reflectivity(ln)
            ELSE
              SfcOptics%Direct_Reflectivity(1,1) = SfcOptics%Reflectivity(1,1,1,1)
            END IF

          END IF


        ! ------------
        ! Fourier component loop for azimuth angles,
        ! mth_Azi = 0 is for an azimuth-averaged value,
        ! for example IR and MW thermal radiation
        ! ------------
        
        RTSolution(ln,m)%Radiance = ZERO
        
        Azi_Fourier_Loop: DO mth_Azi = 0, RTV%n_Azi
          RTV%mth_Azi = mth_Azi
          SfcOptics%mth_Azi = mth_Azi
          
          ! ------------------------------------
          ! Solve the radiative transfer problem
          ! ------------------------------------
          Error_Status = CRTM_Compute_RTSolution( Atm                    , &  ! Input
                                                  Surface(m)             , &  ! Input
                                                  AtmOptics              , &  ! Input
                                                  SfcOptics              , &  ! Input
                                                  GeometryInfo(m)        , &  ! Input
                                                  SensorIndex            , &  ! Input
                                                  ChannelIndex           , &  ! Input
                                                  RTSolution(ln,m)       , &  ! Output
                                                  RTV                    , &  ! Internal variable output
                                                  Message_Log=Message_Log  )  ! Error messaging
         
          IF ( Error_Status /= SUCCESS ) THEN
            WRITE( Message, '( "Error computing RTSolution for ", a, &
                              &", channel ", i0,", profile #",i0)') &
                              TRIM(ChannelInfo(n)%Sensor_ID), &
                              ChannelInfo(n)%Sensor_Channel(l), &
                              m
            CALL Display_Message( ROUTINE_NAME, &
                                  TRIM(Message), &
                                  Error_Status, &
                                  Message_Log=Message_Log )
            RETURN
          END IF
        END DO Azi_Fourier_Loop
        
          ! --------------------------------------                  
          ! Compute Antenna correction if required                  
          ! --------------------------------------                  
          IF ( Compute_AntCorr ) THEN                               
            CALL CRTM_Compute_AntCorr( GeometryInfo(m) , &  ! Input 
                                       SensorIndex     , &  ! Input 
                                       ChannelIndex    , &  ! Input 
                                       RTSolution(ln,m)  )  ! Output
          END IF                                                    
        END DO Channel_Loop

        ! -------------------------------
        ! Deallocate Predictor structure
        ! -------------------------------
        AllocStatus(1) = CRTM_Destroy_Predictor( SensorIndex, Predictor )                     
        AllocStatus(2) = SUCCESS
        IF( RTV%mAllocated )THEN
          AllocStatus(2) = Destroy_RTV( RTV )
        END IF
        IF ( AllocStatus(1) /= SUCCESS .OR. AllocStatus(2) /= SUCCESS ) THEN
          Error_Status = WARNING
          WRITE( Message,'("Error deallocating predictor or RTV data structures for profile #",i0, &
                 &" and Sensor #", i0)' ) m, n       
          CALL Display_Message( ROUTINE_NAME, &
                                TRIM(Message), &
                                Error_Status, &
                                Message_Log=Message_Log )
        END IF
 
      END DO Sensor_Loop


      ! ---------------------------
      ! Deallocate local structures
      ! ---------------------------
      AllocStatus(1) = CRTM_Destroy_SfcOptics( SfcOptics )
      AllocStatus(2) = CRTM_Destroy_AtmScatter( AtmOptics )

      IF ( ANY(AllocStatus /= SUCCESS ) ) THEN
        Error_Status = FAILURE
        WRITE( Message,'("Error deallocating local data structures for profile #",i0)' ) m
        CALL Display_Message( ROUTINE_NAME, &
                              TRIM(Message), &
                              Error_Status, &
                              Message_Log=Message_Log )
        RETURN
      END IF

    END DO Profile_Loop

    ! ---------------------------------
    ! Destroy "extra layers" structures
    ! ---------------------------------
    ! The atmosphere copy
    Error_Status = CRTM_Destroy_Atmosphere( Atm )
    IF ( Error_Status /= SUCCESS ) THEN
      Error_Status = WARNING
      CALL Display_Message( ROUTINE_NAME, &                                      
                            'Error deallocating extra layers Atmosphere structure', & 
                            Error_Status, &                                      
                            Message_Log=Message_Log )                            
    END IF                                                                       
    ! The internal variable
    Error_Status = Destroy_iAtm( iAtm )
    IF ( Error_Status /= SUCCESS ) THEN
      Error_Status = WARNING
      CALL Display_Message( ROUTINE_NAME, &                                      
                            'Error deallocating extra layers iAtm structure', & 
                            Error_Status, &                                      
                            Message_Log=Message_Log )                            
    END IF

  END FUNCTION CRTM_Forward

END MODULE CRTM_Forward_Module
