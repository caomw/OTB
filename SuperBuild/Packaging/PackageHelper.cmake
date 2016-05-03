macro(macro_super_package)
  cmake_parse_arguments(PKG  "" "STAGE_DIR" "SEARCHDIRS" ${ARGN} )

  if("${PKG_STAGE_DIR}" STREQUAL "")
    message(FATAL_ERROR "PKG_STAGE_DIR is emtpy. Just can't continue.")
  endif()

  set(loader_program_PATHS)
  if(WIN32)
      set(loader_program_names      "${MXE_ARCH}-w64-mingw32.shared-objdump")
      set(loader_program_PATHS      "${MXE_MXEROOT}/usr/bin")
      set(LOADER_PROGRAM_ARGS       "-p")
    else()
      if(APPLE)
        set(loader_program_names    otool)
        set(LOADER_PROGRAM_ARGS     "-l")
        set(loader_program_PATHS    /opt/local/bin) # a path that is already listed i path on apple
      else()
        set(loader_program_names    objdump)
        set(LOADER_PROGRAM_ARGS     "-p")
        set(loader_program_PATHS    /usr/bin) # a path that is already listed in default path on Linux
      endif()
      if(NOT DEPENDENCIES_INSTALL_DIR)
        message(FATAL_ERROR "DEPENDENCIES_INSTALL_DIR is not set of empty")
      endif()
  endif()

  find_program(LOADER_PROGRAM "${loader_program_names}" PATHS ${loader_program_PATHS})
  if(NOT EXISTS ${LOADER_PROGRAM})
    message(FATAL_ERROR "${loader_program_names} not found in ${loader_program_PATHS}. please check LOADER_PROGRAM variable is set correctly")
  endif()

  include(GetPrerequisites)

  set(PKG_SEARCHDIRS)
  if(WIN32)
    file(GLOB MXE_GCC_LIB_DIR "${DEPENDENCIES_INSTALL_DIR}/bin/gcc*")
    list(APPEND PKG_SEARCHDIRS ${MXE_GCC_LIB_DIR})
    list(APPEND PKG_SEARCHDIRS "${DEPENDENCIES_INSTALL_DIR}/qt/bin") #Qt
    list(APPEND PKG_SEARCHDIRS "${DEPENDENCIES_INSTALL_DIR}/qt/lib") #Qwt
    list(APPEND PKG_SEARCHDIRS "${DEPENDENCIES_INSTALL_DIR}/bin") #mxe dlls
  else() #unixes
    list(APPEND PKG_SEARCHDIRS "${OTB_INSTALL_DIR}/lib") #so
    list(APPEND PKG_SEARCHDIRS "${DEPENDENCIES_INSTALL_DIR}/lib") #superbuild .so /.dylib
    list(APPEND PKG_SEARCHDIRS "${MONTEVERDI_INSTALL_DIR}/lib/otb") #mvd so
  endif()

  #common for all platforms.
  set(OTB_APPLICATIONS_DIR "${OTB_INSTALL_DIR}/lib/otb/applications")
  list(APPEND PKG_SEARCHDIRS "${DEPENDENCIES_INSTALL_DIR}/bin") #superbuild, mxe binaries
  list(APPEND PKG_SEARCHDIRS "${MONTEVERDI_INSTALL_DIR}/bin") #monteverdi, mapla
  list(APPEND PKG_SEARCHDIRS "${OTB_INSTALL_DIR}/bin") #otbApplicationLauncherCommandLine..
  list(APPEND PKG_SEARCHDIRS "${OTB_APPLICATIONS_DIR}") #otb apps

  set(EXE_SEARCHDIRS ${OTB_INSTALL_DIR}/bin)
  list(APPEND  EXE_SEARCHDIRS ${MONTEVERDI_INSTALL_DIR}/bin)
  list(APPEND  EXE_SEARCHDIRS ${DEPENDENCIES_INSTALL_DIR}/bin)

  macro_empty_package_staging_directory()

  set(PKG_PEFILES)
  if(NOT WIN32)
    file(WRITE ${CMAKE_BINARY_DIR}/make_symlinks "#!/bin/sh\n")
    #NOTE: VAR_IN_PKGSETUP_CONFIGURE is copied to linux_pkgsetup.in during configure_file
    set(VAR_IN_PKGSETUP_CONFIGURE)
    set(PKG_SO_FILES)
  endif() # if(NOT WIN32)

  func_prepare_package()

  func_prepare_install_list(
    "${CMAKE_BINARY_DIR}/install_to_bin"
    ${PKG_GENERATE_XDK}
    bin_install_list
    )

  func_prepare_install_list(
    "${CMAKE_BINARY_DIR}/install_to_lib"
    ${PKG_GENERATE_XDK}
    lib_install_list
    )

  foreach(installable_item_in_bin ${bin_install_list})
    if(WIN32)
      #only install .exe files with install(PROGRAMS ..
      if("${installable_item_in_bin}" MATCHES "\\.exe$")
        install(PROGRAMS "${installable_item_in_bin}" DESTINATION ${PKG_STAGE_DIR}/bin)
      else()
        install(FILES "${installable_item_in_bin}" DESTINATION ${PKG_STAGE_DIR}/bin)
      endif()
    else()
      #install all executable with install(PROGRAMS on unix like
      install(PROGRAMS "${installable_item_in_bin}" DESTINATION ${PKG_STAGE_DIR}/bin)
    endif()
  endforeach()

  #install lib files into lib as install(FILES ..
  foreach(installable_item_in_lib ${lib_install_list})
    install(FILES "${installable_item_in_bin}" DESTINATION ${PKG_STAGE_DIR}/lib)
  endforeach()

  ############# install package configure script ################
  if(UNIX AND NOT WIN32)
    set(PKGSETUP_IN_FILENAME linux_pkgsetup.in)
    if(APPLE)
      set(PKGSETUP_IN_FILENAME macx_pkgsetup.in)
    endif()
    configure_file(${PACKAGE_SUPPORT_FILES_DIR}/${PKGSETUP_IN_FILENAME}
      ${CMAKE_BINARY_DIR}/pkgsetup @ONLY)

    install(PROGRAMS
      ${CMAKE_BINARY_DIR}/pkgsetup
      ${CMAKE_BINARY_DIR}/make_symlinks
      DESTINATION ${PKG_STAGE_DIR})

    ########### install patchelf( linux only) ##################
    if(NOT APPLE)
      install(PROGRAMS ${CMAKE_INSTALL_PREFIX}/tools/patchelf
        DESTINATION ${PKG_STAGE_DIR}/tools)
    endif()
  endif() # if(UNIX)

  if(PKG_GENERATE_XDK)
    func_install_xdk_files()
  endif()

endmacro(macro_super_package)

function(func_install_xdk_files)

  #The list of REQ_SHARE_DIR is made up from <mxe-target-dir>/share/
  #It may vary in future. I prefer not to glob on the share dir and
  #end up distributing man, info etc.. which ar irrelvant for windows
  foreach(REQ_SHARE_DIR
      aclocal
      Armadillo
      applications
      cmake
      dbus-1
      fontconfig
      libgta
      locale
      xml
      applications
      cmake
      icons
      OpenCV
      pixmaps
      pkgconfig
      )
    if(EXISTS "${DEPENDENCIES_INSTALL_DIR}/share/${REQ_SHARE_DIR}")
      func_install_without_message("${DEPENDENCIES_INSTALL_DIR}/share/${REQ_SHARE_DIR}" "share")
    endif()
  endforeach()

  file(GLOB LIB_CMAKE_DIRS "${DEPENDENCIES_INSTALL_DIR}/lib/cmake/*")
  foreach(LIB_CMAKE_DIR ${LIB_CMAKE_DIRS})
    get_filename_component(LIB_CMAKE_DIR_name_we ${LIB_CMAKE_DIR} NAME_WE)
    if(NOT "${LIB_CMAKE_DIR_name_we}" MATCHES "OTB")
      func_install_without_message("${LIB_CMAKE_DIR}" "lib/cmake")
    endif()
  endforeach()

  # #install ${DEPENDENCIES_INSTALL_DIR}/include silently
  func_install_without_message("${DEPENDENCIES_INSTALL_DIR}/include" "" "(may take a while)..")

  if(WIN32)
    #only affects windows due to regex on dll
    file(GLOB LIB_FILES "${DEPENDENCIES_INSTALL_DIR}/lib/*dll.*")
    install(FILES ${LIB_FILES}    DESTINATION ${PKG_STAGE_DIR}/lib )

    file(GLOB ITK_EXTRA_DLL_FILES_1 "${DEPENDENCIES_INSTALL_DIR}/bin/libITK*.dll")
    install(FILES ${ITK_EXTRA_DLL_FILES_1} DESTINATION ${PKG_STAGE_DIR}/bin)

    file(GLOB ITK_EXTRA_DLL_FILES_2 "${DEPENDENCIES_INSTALL_DIR}/bin/libitk*.dll")
    install(FILES ${ITK_EXTRA_DLL_FILES_2} DESTINATION ${PKG_STAGE_DIR}/bin)

    file(GLOB OPENCV_EXTRA_DLL_FILES "${DEPENDENCIES_INSTALL_DIR}/bin/libopencv*.dll")
    install(FILES ${OPENCV_EXTRA_DLL_FILES} DESTINATION ${PKG_STAGE_DIR}/bin)

    file(GLOB OPENCV_EXTRA_A_FILES "${DEPENDENCIES_INSTALL_DIR}/lib/libopencv*.a")
    install(FILES ${OPENCV_EXTRA_A_FILES} DESTINATION ${PKG_STAGE_DIR}/lib)

    #opencv cmake config files in two directories.
    # ${PKG_STAGE_DIR}/lib and ${PKG_STAGE_DIR}
    file(GLOB OPENCV_CONFIG_FILES_1 "${DEPENDENCIES_INSTALL_DIR}/lib/OpenCV*.cmake")
    install(FILES ${OPENCV_CONFIG_FILES_1} DESTINATION ${PKG_STAGE_DIR}/lib)

    file(GLOB OPENCV_CONFIG_FILES_2 "${DEPENDENCIES_INSTALL_DIR}/OpenCV*.cmake")
    install(FILES ${OPENCV_CONFIG_FILES_2} DESTINATION ${PKG_STAGE_DIR})

    #mxe install qt in a seperate directory under install prefix. So..
    foreach(REQ_DIR
        lib
        mkspecs
        include
        imports
        plugins
        translations
        )
      if(EXISTS "${DEPENDENCIES_INSTALL_DIR}/qt/${REQ_DIR}")
        func_install_without_message("${DEPENDENCIES_INSTALL_DIR}/qt/${REQ_DIR}" "")
      endif()
    endforeach()

    #qt/bin is a special case here.
    file(GLOB QT_EXTRA_DLL_FILES "${DEPENDENCIES_INSTALL_DIR}/qt/bin/*.dll")
    install(FILES ${QT_EXTRA_DLL_FILES} DESTINATION ${PKG_STAGE_DIR}/bin)

    file(GLOB QT_EXECUTABLES "${DEPENDENCIES_INSTALL_DIR}/qt/bin/*.exe")
    install(FILES ${QT_EXECUTABLES} DESTINATION ${PKG_STAGE_DIR}/bin)

    file(GLOB QT_EXTRA_EXECUTABLES "${Monteverdi_BINARY_DIR}/PACKAGE-TOOLS/src/PACKAGE-TOOLS/*.exe")
    install(FILES ${QT_EXTRA_EXECUTABLES} DESTINATION ${PKG_STAGE_DIR}/bin)

  endif(WIN32)

endfunction() #func_install_xdk_files

function(func_install_without_message src_dir dst_dir_suffix)
  set (extra_func_args ${ARGN})
  list(LENGTH extra_func_args num_extra_args)
  if (${num_extra_args} GREATER 0)
    list(GET extra_func_args 0 optional_msg)
  endif()

  if( "${dst_dir_suffix}" STREQUAL "")
    set(dst_dir "${PKG_STAGE_DIR}")
  else()
    set(dst_dir "${PKG_STAGE_DIR}/${dst_dir_suffix}")
  endif()

  get_filename_component(src_dir_name ${src_dir} NAME)
  set(install_msg "message(STATUS \"Installing: ${CMAKE_INSTALL_PREFIX}/${dst_dir}/${src_dir_name} ${optional_msg}\")")
  install(CODE "${install_msg}" )
  install(
    DIRECTORY   ${src_dir}
    DESTINATION ${dst_dir}
    MESSAGE_NEVER )
endfunction()

function(func_install_support_files include_mvd)

  #a convenient cmake var for storing <prefix>/bin
  set(PKG_STAGE_BIN_DIR "${PKG_STAGE_DIR}/bin")

  #<prefix>/share for gdal data files
  set(PKG_SHARE_DEST_DIR ${PKG_STAGE_DIR}/share)

  set(PKG_SHARE_SOURCE_DIR ${DEPENDENCIES_INSTALL_DIR}/share)

  # Just check if required variables are defined.
  foreach(req
      DEPENDENCIES_INSTALL_DIR
      OTB_APPLICATIONS_DIR
      PKG_STAGE_DIR
      PACKAGE_SUPPORT_FILES_DIR
      MONTEVERDI_INSTALL_DIR
      OTB_INSTALL_DIR
      )
    if(NOT DEFINED ${req})
      message(FATAL_ERROR "you must set ${req} before calling this method")
    endif()
    set(vars "${vars}  ${req}=[${${req}}]\n")
  endforeach(req)

  # one for debugging..
  # install(CODE "message(\"CMake/PackageHelper.cmake:install_supoport_files(${outdir})\n${vars}\n\")")
  if(NOT PKG_GENERATE_XDK)
    func_install_otb_support_files()

    if(include_mvd)
      func_install_monteverdi_support_files()
    endif(include_mvd)

  endif() #NOT PKG_GENERATE_XDK

  ####################### install GDAL data ############################
  set(GDAL_DATA ${PKG_SHARE_SOURCE_DIR}/gdal)
  if(NOT EXISTS "${GDAL_DATA}/epsg.wkt")
    message(FATAL_ERROR "Cannot generate package without GDAL_DATA : ${GDAL_DATA} ${DEPENDENCIES_INSTALL_DIR}")
  endif()

  install(DIRECTORY ${GDAL_DATA} DESTINATION ${PKG_SHARE_DEST_DIR})

  ####################### install GeoTIFF data ########################
  install(DIRECTORY ${PKG_SHARE_SOURCE_DIR}/epsg_csv DESTINATION ${PKG_SHARE_DEST_DIR})

  ####################### install OSSIM data ##########################
  install(DIRECTORY ${PKG_SHARE_SOURCE_DIR}/ossim DESTINATION ${PKG_SHARE_DEST_DIR})

  ####################### install proj share ##########################
  if(EXISTS ${PKG_SHARE_SOURCE_DIR}/proj)
    install(DIRECTORY ${PKG_SHARE_SOURCE_DIR}/proj DESTINATION ${PKG_SHARE_DEST_DIR})
  endif()

  ####################### Install copyrights ##########################
  if(WIN32)
    #do install license for windows package
  else()
    install(DIRECTORY ${PKG_SHARE_SOURCE_DIR}/copyright DESTINATION ${PKG_SHARE_DEST_DIR})
    install(FILES ${PKG_SHARE_SOURCE_DIR}/copyright/LICENSE DESTINATION ${PKG_STAGE_DIR})
  endif()

endfunction()

function(func_install_otb_support_files)
  foreach(req
      PKG_STAGE_DIR
      OTB_INSTALL_DIR
      MONTEVERDI_INSTALL_DIR
      DEPENDENCIES_INSTALL_DIR
      OTB_APPLICATIONS_DIR
      )
    if(NOT DEFINED ${req})
      message(FATAL_ERROR "you must set ${req} before calling this method")
    endif()
    set(vars "${vars}  ${req}=[${${req}}]\n")
  endforeach(req)

  #a convenient cmake var for storing <prefix>/bin
  set(PKG_STAGE_BIN_DIR "${PKG_STAGE_DIR}/bin")

  #root folder where otb applications are installed
  set(PKG_OTBLIBS_DIR "${PKG_STAGE_DIR}/lib/otb")

  #<prefix>/share for gdal data files
  set(PKG_SHARE_DEST_DIR ${PKG_STAGE_DIR}/share)

  set(PKG_SHARE_SOURCE_DIR ${DEPENDENCIES_INSTALL_DIR}/share)

  #For Unixes we make them in the *pkgsetup.in
  ##################### install environment source ##########################
  if(WIN32)
    foreach(ENV_SOURCE_FILE
        "${PACKAGE_SUPPORT_FILES_DIR}/otbenv.cmd"
        "${PACKAGE_SUPPORT_FILES_DIR}/otbenv.profile")
      if(EXISTS ${ENV_SOURCE_FILE})
        install(FILES ${ENV_SOURCE_FILE} DESTINATION ${PKG_STAGE_DIR})
      endif()
    endforeach()

    #we need startup files for mapla monteverdi in the root directory
    #For Unixes, we make them inside pkgsetup script!
    foreach(exe_file mapla monteverdi)
      install(
        PROGRAMS ${PACKAGE_SUPPORT_FILES_DIR}/${exe_file}.bat
        DESTINATION "${PKG_STAGE_DIR}"
        )
    endforeach()
  endif()

  ####################### install cli and gui scripts ###########################
  file(GLOB PKG_APP_SCRIPTS
    ${OTB_INSTALL_DIR}/bin/otbcli*
    ${OTB_INSTALL_DIR}/bin/otbgui*) #

  list(LENGTH PKG_APP_SCRIPTS PKG_APP_SCRIPTS_LENGTH)
  if (PKG_APP_SCRIPTS_LENGTH LESS 1)
    message(WARNING "PKG_APP_SCRIPTS is empty: ${PKG_APP_SCRIPTS}")
  endif()

  ##################### install cli and gui scripts #######################
  install(PROGRAMS ${PKG_APP_SCRIPTS}  DESTINATION ${PKG_STAGE_BIN_DIR})

  ####################### Install otb applications ####################
  install(DIRECTORY "${OTB_APPLICATIONS_DIR}"  DESTINATION ${PKG_OTBLIBS_DIR})

endfunction()

function(func_install_monteverdi_support_files)

  #name/ext of qt's sqlite plugin. Varies with platform/OS
  if(WIN32)
    set(PKG_QTSQLITE_FILENAME "qsqlite4.dll")
  elseif(APPLE)
    set(PKG_QTSQLITE_FILENAME "libqsqlite.dylib")
  elseif(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    set(PKG_QTSQLITE_FILENAME "libqsqlite.so")
  else()
    message(FATAL_ERROR "func_install_monteverdi_support_files: Unknown OS/Platform")
  endif()

  #root folder where qt plugins are installed
  set(PKG_QTPLUGINS_DIR "${PKG_STAGE_DIR}/lib/qt4/plugins")

  #qt4's distributes some translation of common message string used in Qt.
  #This are provided with any qt installation. We reuse them in otb package
  #so as not to reinvent the wheels.
  set(PKG_I18N_DIR "${PKG_STAGE_DIR}/lib/qt4/translations")

  #<prefix>/share for otb i18n directory. This is different from qt's i18N directory
  #which is <prefix>/share/qt4/translations.
  set(PKG_OTB_I18N_DIR "${PKG_STAGE_DIR}/${Monteverdi_INSTALL_DATA_DIR}/i18n")

  # Just check if required variables are defined.
  foreach(req
      Monteverdi_SOURCE_DIR
      PACKAGE_SUPPORT_FILES_DIR
      QT_PLUGINS_DIR
      PKG_STAGE_BIN_DIR
      PKG_QTSQLITE_FILENAME
      PKG_QTPLUGINS_DIR
      PKG_I18N_DIR
      PKG_OTB_I18N_DIR
      )
    if(NOT DEFINED ${req} OR "${${req}}" STREQUAL "")
      message(FATAL_ERROR "you must set ${req} before calling this method")
    endif()
    set(vars "${vars}  ${req}=[${${req}}]\n")
  endforeach(req)

  #install icon file for .app file. Monteverdi and Mapla has same icon!
  if(APPLE)
    install(FILES ${PACKAGE_SUPPORT_FILES_DIR}/Monteverdi.icns
      DESTINATION ${PKG_STAGE_DIR})
  endif()

  if(WIN32)
    ####################### install mingw qt.conf ##########################
    if(EXISTS ${PACKAGE_SUPPORT_FILES_DIR}/qt.conf)
      install(FILES ${PACKAGE_SUPPORT_FILES_DIR}/qt.conf
        DESTINATION ${PKG_STAGE_BIN_DIR})
    endif()
  endif()

  ####################### install sqldriver plugin ########################
  install(FILES ${QT_PLUGINS_DIR}/sqldrivers/${PKG_QTSQLITE_FILENAME}
    DESTINATION ${PKG_QTPLUGINS_DIR}/sqldrivers)

  ####################### install translations ###########################
  #get all translations already distributed with qt4
  get_qt_translation_files(QT_TRANSLATIONS_FILES)

  #install all files in ${QT_TRANSLATIONS_FILES}
  install(FILES ${QT_TRANSLATIONS_FILES}  DESTINATION ${PKG_I18N_DIR})

  #translation of monteverdi specific strings
  file(GLOB APP_TS_FILES ${Monteverdi_SOURCE_DIR}/i18n/*.ts) # qm files
  foreach(APP_TS_FILE ${APP_TS_FILES})
    get_filename_component(APP_TS_FILENAME ${APP_TS_FILE} NAME_WE)
    install(FILES ${Monteverdi_BINARY_DIR}/i18n/${APP_TS_FILENAME}.qm
      DESTINATION ${PKG_OTB_I18N_DIR}
      )
  endforeach()

  #set(PKG_OTB_ccSHARE_SOURCE_DIR "${MONTEVERDI_INSTALL_DIR}")
  # if(WIN32)
  #   set(PKG_OTB_ccSHARE_SOURCE_DIR "${MONTEVERDI_INSTALL_DIR}/share")
  # endif()
  if(NOT EXISTS "${MONTEVERDI_INSTALL_DIR}/share/otb/i18n")
    message(FATAL_ERROR "error ${MONTEVERDI_INSTALL_DIR}/share/otb/i18n not exists")
  endif()
  ####################### install otb share ###########################
  install(DIRECTORY ${MONTEVERDI_INSTALL_DIR}/share/otb DESTINATION ${PKG_SHARE_DEST_DIR})

endfunction()

macro(macro_empty_package_staging_directory)
  message(STATUS "Empty package staging directory: ${CMAKE_INSTALL_PREFIX}/${PKG_STAGE_DIR}")
  execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_INSTALL_PREFIX}/${PKG_STAGE_DIR}")
endmacro() #macro_empty_package_staging_directory

#NOTE:
# VAR_IN_PKGSETUP_CONFIGURE cmake variable is set below.
# This is important and useful running configure_file()
# over *pkgsetup.in

function(func_prepare_package)

  set(DEST_LIB_DIR lib)
  set(DEST_BIN_DIR bin)
  set(DEST_APP_DIR lib/otb/applications)
  set(EXE_EXT "")
  set(SCR_EXT ".sh")
  set(LIB_EXT "*so")
  if(WIN32)
    set(EXE_EXT ".exe")
    set(LIB_EXT "*dll")
    set(SCR_EXT ".bat")
    set(DEST_LIB_DIR bin)
  elseif(APPLE)
    set(LIB_EXT "*dylib")
  endif()

  file(WRITE ${CMAKE_BINARY_DIR}/install_to_bin "")
  file(WRITE ${CMAKE_BINARY_DIR}/install_to_lib "")

  #This must exist in any OTB Installation minimal or full
  set(VAR_IN_PKGSETUP_CONFIGURE "bin/otbApplicationLauncherCommandLine")
  set(PKG_PEFILES "${OTB_INSTALL_DIR}/bin/otbApplicationLauncherCommandLine${EXE_EXT}")
  if(NOT EXISTS "${OTB_INSTALL_DIR}/bin/otbApplicationLauncherCommandLine${EXE_EXT}")
    message(FATAL_ERROR "${OTB_INSTALL_DIR}/bin/otbApplicationLauncherCommandLine${EXE_EXT} not found.")
  endif()

  set(EXE_FILES)
  list(APPEND EXE_FILES "otbApplicationLauncherQt")
  list(APPEND EXE_FILES "iceViewer")
  list(APPEND EXE_FILES "otbTestDriver")

  #Q: why we need itkTestDriver?.
  #A: Because we need to get all dlls from ITK via itkTestDriver linkage.
  # itkvnl and itkvnl_algo are referenced in its lib/cmake/ITK-4.8/ITKTargets.cmake
  # But OTB didn't use them and hence not counted. However an erro has been observed when
  # using XDK on windows that the file is missing or damaged
  if(PKG_GENERATE_XDK)
    list(APPEND EXE_FILES "itkTestDriver")
  endif()

  list(APPEND EXE_FILES "monteverdi")
  list(APPEND EXE_FILES "mapla")

  foreach(EXE_FILE ${EXE_FILES})
    set(FOUND_${EXE_FILE} FALSE)
    foreach(EXE_SEARCHDIR ${EXE_SEARCHDIRS})
      if(NOT FOUND_${EXE_FILE})
        if(EXISTS "${EXE_SEARCHDIR}/${EXE_FILE}${EXE_EXT}")
          set(FOUND_${EXE_FILE} TRUE)
          #see the first comment about VAR_IN_PKGSETUP_CONFIGURE
          set(VAR_IN_PKGSETUP_CONFIGURE "${VAR_IN_PKGSETUP_CONFIGURE} bin/${EXE_FILE}${EXE_EXT}")
          list(APPEND PKG_PEFILES "${EXE_SEARCHDIR}/${EXE_FILE}${EXE_EXT}")
        endif()
      endif() #(NOT FOUND_${EXE_FILE})
    endforeach() #EXE_SEARCH_DIR
  endforeach()

  #loop again to report if anything is not found
  foreach( EXE_FILE ${EXE_FILES} )
    if(NOT FOUND_${EXE_FILE})
      message(STATUS "'${OTB_INSTALL_DIR}/bin/${EXE_FILE}${EXE_EXT}'(not found. skipping)")
    endif()
  endforeach()

  file(GLOB OTB_APPS_LIST ${OTB_APPLICATIONS_DIR}/otbapp_${LIB_EXT}) # /lib/otb

  #see the first comment about VAR_IN_PKGSETUP_CONFIGURE
  #NOTE: this is not used in windows yet..
  foreach(OTB_APP_SO ${OTB_APPS_LIST})
    get_filename_component(OTB_APP_SO_NAME ${OTB_APP_SO} NAME)
    set(VAR_IN_PKGSETUP_CONFIGURE "${VAR_IN_PKGSETUP_CONFIGURE} lib/otb/applications/${OTB_APP_SO_NAME}")
  endforeach()

  set(include_mvd 0)
  if(DEFINED Monteverdi_SOURCE_DIR)
    set(include_mvd 1)
  endif()

  list(APPEND PKG_PEFILES ${OTB_APPS_LIST})

  func_install_support_files(${include_mvd})

  execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/temp_so_names_dir")
  execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/temp_so_names_dir")

  set(alldlls)
  set(notfound_dlls)
  #message(STATUS "Processing start")
  foreach(infile ${PKG_PEFILES})
    get_filename_component(bn ${infile} NAME)
    func_process_deps(${bn})
  endforeach()
  #message(STATUS "Processing done")

  list(LENGTH notfound_dlls nos)
  if(${nos} GREATER 0)
    list(REMOVE_DUPLICATES notfound_dlls)
    #string(REPLACE ";" "\r" notfound_dlls ${notfound_dlls})
    message(FATAL_ERROR "Following dlls were not found: ${notfound_dlls}. Please consider adding their paths to PKG_SEARCHDIRS when calling superbuild_package macro.")
  endif()

  file(GLOB temp_files "${CMAKE_BINARY_DIR}/temp_so_names_dir/*") # /lib/otb
  foreach(temp_file ${temp_files})
    get_filename_component(basename_of_temp_file ${temp_file} NAME)
    set(VAR_IN_PKGSETUP_CONFIGURE "${VAR_IN_PKGSETUP_CONFIGURE} lib/${basename_of_temp_file}")
  endforeach()

  #remove this temporary directory
  execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/temp_so_names_dir")

  set(VAR_IN_PKGSETUP_CONFIGURE "${VAR_IN_PKGSETUP_CONFIGURE}" PARENT_SCOPE)

endfunction() #func_prepare_package

function(func_process_deps infile)

  if(APPLE)
    if( "${infile}" MATCHES "@rpath")
      string(REGEX REPLACE "@rpath." "" infile "${infile}")
    endif()
  endif()
  if(WIN32)
    string(TOLOWER "${infile}" infile_lower )
  endif()
  get_filename_component(bn ${infile} NAME)

  list_contains(contains "${bn}" "${alldlls}")
  if(NOT contains)
    set(DLL_FOUND FALSE)

    foreach(SEARCHDIR ${PKG_SEARCHDIRS})
      if(NOT DLL_FOUND)
        if(WIN32)
          if(NOT EXISTS ${SEARCHDIR}/${infile} )
            if(EXISTS ${SEARCHDIR}/${infile_lower} )
              set(infile ${infile_lower})
            endif()
          endif()
        endif()
        if(EXISTS ${SEARCHDIR}/${infile})
          set(DLL_FOUND TRUE)
          message(STATUS "Processing ${SEARCHDIR}/${infile}")
          is_file_executable("${SEARCHDIR}/${infile}" is_executable)
          if(is_executable)
            #install(PROGRAMS "${SEARCHDIR}/${infile}" DESTINATION ${PKG_STAGE_DIR}/bin)
            file(APPEND ${CMAKE_BINARY_DIR}/install_to_${DEST_BIN_DIR} "${SEARCHDIR}/${infile}\n")
          else(is_executable)
            get_filename_component(bn_we ${infile} NAME_WE)
            file(GLOB sofiles "${SEARCHDIR}/${bn_we}*")
            foreach(sofile ${sofiles})
              get_filename_component(sofile_ext ${sofile} EXT)
              set(is_valid TRUE)
              if ("${sofile_ext}" MATCHES ".la"
                  OR "${sofile_ext}" MATCHES ".prl"
                  OR "${sofile_ext}" MATCHES ".a")
                set(is_valid FALSE)
              endif()
              if(is_valid)
                get_filename_component(basename_of_sofile ${sofile} NAME)
                func_is_file_a_symbolic_link("${sofile}" is_symlink linked_to_file)
                if(is_symlink)
                  # NOTE: $OUT_DIR is set actually in pkgsetup.in. So don't try
                  # any pre-mature optimization on that variable names
                  file(APPEND
                    ${CMAKE_BINARY_DIR}/make_symlinks
                    "ln -sf $OUT_DIR/lib/${linked_to_file} $OUT_DIR/lib/${basename_of_sofile}\n"
                    )
                  #message("${sofile} is a symlink to ${linked_to_file}")
                else() # is_symlink
                  if(NOT "${basename_of_sofile}" MATCHES "otbapp_")
                    file(APPEND ${CMAKE_BINARY_DIR}/install_to_${DEST_LIB_DIR} "${sofile}\n")
                    #just install the so file to <staging-dir>/lib
                    #install(FILES "${sofile}" DESTINATION ${PKG_STAGE_DIR}/lib MESSAGE_NEVER)
                    # Finally touch a file in temp directory for globbing later
                    # message("touching ${basename_of_sofile}")
                    execute_process(COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/temp_so_names_dir/${basename_of_sofile}")
                  endif() #if(.. MATCHES "otbapp_")
                endif() #is_symlink
              endif() #is_valid
            endforeach()
          endif(is_executable)
          execute_process(
            COMMAND ${LOADER_PROGRAM} ${LOADER_PROGRAM_ARGS} "${SEARCHDIR}/${infile}"
            RESULT_VARIABLE loader_rv
            OUTPUT_VARIABLE loader_ov
            ERROR_VARIABLE loader_ev
            )
          if(loader_rv)
            message(FATAL_ERROR "loader_ev=${loader_ev}\n PACKAGE-OTB: result_variable is '${loader_rv}'")
          endif()

          if(WIN32)
            string(REGEX MATCHALL "DLL.Name..[A-Za-z(0-9\\.0-9)+_\\-]*" loader_ov "${loader_ov}")
            string(REGEX REPLACE "DLL.Name.." "" needed_dlls "${loader_ov}")
          else()  #case for unixes
            if(APPLE)
              string(REGEX REPLACE "[^\n]+cmd LC_LOAD_DYLIB\n[^\n]+\n[^\n]+name ([^\n]+).\\(offset[^\n]+\n" "rpath \\1\n" loader_ov "${loader_ov}")
              string(REGEX MATCHALL "rpath [^\n]+" loader_ov "${loader_ov}")
              string(REGEX REPLACE "rpath " "" needed_dlls "${loader_ov}")
            else(APPLE)
              string(REGEX MATCHALL "NEEDED\\ *[A-Za-z(0-9\\.0-9)+_\\-]*" loader_ov "${loader_ov}")
              string(REGEX REPLACE "NEEDED" "" needed_dlls "${loader_ov}")
            endif(APPLE)
          endif()

          foreach(needed_dll ${needed_dlls})
            string(STRIP ${needed_dll} needed_dll)
            func_process_deps(${needed_dll})
          endforeach()
        endif()
      endif(NOT DLL_FOUND)
    endforeach()

    if(NOT DLL_FOUND)
      is_system_dll(iss "${infile}")
      if(NOT iss)
        set(notfound_dlls "${notfound_dlls};${infile}")
      endif()
    else(NOT DLL_FOUND)
      set( alldlls "${alldlls};${bn}" PARENT_SCOPE )
    endif(NOT DLL_FOUND)
    set(notfound_dlls "${notfound_dlls}" PARENT_SCOPE )
  endif()

endfunction()

# The below function is modified from GetPrerequisities.cmake
# which is distributed with CMake.
function(func_is_file_a_symbolic_link file result_var1 result_var2)
  #
  # A file is not executable until proven otherwise:
  #
  set(${result_var1} 0 PARENT_SCOPE)
  set(${result_var2} "" PARENT_SCOPE)

  get_filename_component(file_full "${file}" ABSOLUTE)
  string(TOLOWER "${file_full}" file_full_lower)

  # If file name ends in .exe on Windows, *assume* executable:
  #
  if(WIN32 AND NOT UNIX)
    if("${file_full_lower}" MATCHES "\\.lnk$")
      set(${result_var1} 1 PARENT_SCOPE)
      #Assuming the file is linked to a file with same name without .lnk extension
      get_filename_component(name_we_lnk "${file_full_lower}" NAME_WE)
      set(${result_var2} "${name_we_lnk}" PARENT_SCOPE)
      return()
    endif()

    # A clause could be added here that uses output or return value of dumpbin
    # to determine ${result_var}. In 99%+? practical cases, the exe name
    # match will be sufficient...
    #
  endif()

  # Use the information returned from the Unix shell command "file" to
  # determine if ${file_full} should be considered an executable file...
  #
  # If the file command's output contains "executable" and does *not* contain
  # "text" then it is likely an executable suitable for prerequisite analysis
  # via the get_prerequisites macro.
  #
  if(UNIX)
    if(NOT file_cmd)
      find_program(file_cmd "file")
      mark_as_advanced(file_cmd)
    endif()

    if(file_cmd)
      execute_process(COMMAND "${file_cmd}" "${file_full}"
        RESULT_VARIABLE file_rv
        OUTPUT_VARIABLE file_ov
        ERROR_VARIABLE file_ev
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
      if(NOT file_rv STREQUAL "0")
        message(FATAL_ERROR "${file_cmd} failed: ${file_rv}\n${file_ev}")
      endif()

      # Replace the name of the file in the output with a placeholder token
      # (the string " _file_full_ ") so that just in case the path name of
      # the file contains the word "text" or "executable" we are not fooled
      # into thinking "the wrong thing" because the file name matches the
      # other 'file' command output we are looking for...
      #
      string(REPLACE "${file_full}" " _file_full_ " file_ov "${file_ov}")
      string(TOLOWER "${file_ov}" file_ov_lower)

      #message(FATAL_ERROR "file_ov='${file_ov}'")
      if("${file_ov_lower}" MATCHES "symbolic link")
        #message(STATUS "symbolic link!")
        set(${result_var1} 1 PARENT_SCOPE)
        #Now find where the symlink is linked to.
        #Do a regex replace
        if(UNIX)
          if(APPLE)
            string(REGEX REPLACE "_file_full_*.*symbolic.link.to."
              "" symlinked_to ${file_ov})
          else(APPLE)
            string(REGEX REPLACE "_file_full_*.*symbolic.link.to.."
              "" symlinked_to ${file_ov})
          endif(APPLE)
        endif(UNIX)
        #Take out last character which is a single quote
        string(REPLACE "'" "" symlinked_to "${symlinked_to}")
        #strip for our own sanity
        string(STRIP ${symlinked_to} symlinked_to)
        set(${result_var2} "${symlinked_to}" PARENT_SCOPE)
        #message(FATAL_ERROR "${file_full} is symlinked_to ${symlinked_to}")
        return()
      endif()

    else()
      message(STATUS "warning: No 'file' command, skipping execute_process...")
    endif()
  endif()
endfunction()


#function to prepare list of install files to bin and lib directory
#input_file is written by func_process_deps() macro
#with_xdk is flag to indicate wheather we are build xdk or not.
#Its value is same as PKG_GENERATE_XDK
# install_list_variable -output variable that store the final list
# This list is looped and all install() command are created there.
function(func_prepare_install_list input_file with_xdk install_list_variable )
  #message("-- input_file = '${input_file}'")
  set(install_to_ITEMS)
  file(STRINGS "${input_file}" install_to_ITEMS)
  foreach(install_to_ITEM ${install_to_ITEMS})
    get_filename_component(install_to_ITEM_BASENAME ${install_to_ITEM} NAME_WE)
    #MUST remove otb applications. Installed in other macro later
    if ("${install_to_ITEM_BASENAME}" MATCHES "otbapp_*")
      list(REMOVE_ITEM install_to_ITEMS "${install_to_ITEM}")
    endif()

    if(with_xdk)
      if ("${install_to_ITEM_BASENAME}"
          MATCHES
          "libOTB|libotb|otbApp|otbTest|libMonteverdi|monteverdi|mapla|iceViewer"
          )
        list(REMOVE_ITEM install_to_ITEMS "${install_to_ITEM}")
      endif()
    endif() #with_xdk
  endforeach()

  set(${install_list_variable} "${install_to_ITEMS}" PARENT_SCOPE)

endfunction() # func_prepare_install_list


set(WINDOWS_SYSTEM_DLLS
  msvc.*dll
  user32.dll
  gdi32.dll
  shell32.dll
  kernel32.dll
  ws2_32.dll
  wldap32.dll
  ole32.dll
  comdlg32.dll
  shfolder.dll
  secur32.dll
  wsock32.dll
  advapi32.dll
  crypt32.dll
  imm32.dll
  oleaut32.dll
  winmm.dll
  opengl32.dll
  glu32.dll
  rpcrt4.dll
  winspool.drv)

set(LINUX_SYSTEM_DLLS
  libm.so
  libc.so
  libstdc*
  libgcc_s.so
  librt.so
  libdl.so
  libpthread.so
  libidn.so
  libgomp.so*
  ld-linux-x86-64.so*
  libX11.so*
  libXext.so*
  libXau.so*
  libXdmcp.so*
  libXxf86vm.so*
  libdrm.so.2
  libGL.so*
  libGLU.so*
  )

# libgcc_s.*dylib and other *.framework are dragged by QT
set(APPLE_SYSTEM_DLLS
  libSystem.*dylib
  libiconv.*dylib
  libc\\+\\+.*dylib
  libstdc.*dylib
  libobjc.*dylib
  ApplicationServices.framework
  CoreFoundation.framework
  CoreServices.framework
  Security.framework
  Carbon.framework
  AppKit.framework
  Foundation.framework
  AGL.framework
  OpenGL.framework
  libgcc_s.*dylib
  )

if(WIN32)
  set(SYSTEM_DLLS "${WINDOWS_SYSTEM_DLLS}")
else() #case for unixes
  if(APPLE)
    set(SYSTEM_DLLS "${APPLE_SYSTEM_DLLS}")
  else()
    set(SYSTEM_DLLS "${LINUX_SYSTEM_DLLS}")
  endif()
endif(WIN32)

macro(is_system_dll matched value)
  set(${matched})
  string(TOLOWER ${value} value_)
  foreach (pattern ${SYSTEM_DLLS})
    string(TOLOWER ${pattern} pattern_)
    if("${value_}" MATCHES "${pattern_}")
      set(${matched} TRUE)
    endif()
  endforeach()
endmacro()

macro(list_contains var value)
  set(${var})
  foreach(value2 ${ARGN})
    if(${value} STREQUAL ${value2})
      set(${var} TRUE)
    endif()
  endforeach(value2)
endmacro()

# Get the translation files coming with Qt, and install them in the bundle
# They are loaded by Monteverdi.
function(get_qt_translation_files RESULT)
    # These files are the "qt_<localename>.qm" files
    # They are located in QT_TRANSLATIONS_DIR, which comes from FindQt4
    file(GLOB translation_files ${QT_TRANSLATIONS_DIR}/qt_*)

    # We need to remove the "qt_help_<localename>.qm" files from this list
    foreach(translation_item ${translation_files})
      if(${translation_item} MATCHES "qt_help")
        list(REMOVE_ITEM translation_files ${translation_item})
      endif()
    endforeach()

    set(${RESULT} ${translation_files} PARENT_SCOPE)
endfunction()