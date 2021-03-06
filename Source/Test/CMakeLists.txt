

#configure_file("${EMsoft_SOURCE_DIR}/Source/Test/TestFileLocations.f90.in"
#  "${EMsoft_BINARY_DIR}/EMsoftPublicTestFileLocations.f90")


include("${EMsoft_SOURCE_DIR}/Source/EMsoft_Functions.cmake")
set(APP_DIR "${EMsoft_SOURCE_DIR}/Source/Test")
set(TMPLT_DIR "${EMsoft_SOURCE_DIR}/NamelistTemplates")

set(EMsoftTestDir "${EMsoft_SOURCE_DIR}/Source/Test")
include_directories("${EMsoftTestDir}")
include_directories("${EMsoft_BINARY_DIR}")
include_directories("${EMsoftHDFLib_BINARY_DIR}")


#------------------------------------------------------------------------------
# in order to add a new unit test the following needs to be performed:
# For a Unit Test called "foo":
# Create a fooTest.f90 file that implements the following function:
# module foo
#
# contains
#  subroutine fooExecuteTest(result) &
#  bind(c, name='fooExecuteTest') ! this routine is callable from a C/C++ program
#  !DEC$ ATTRIBUTES DLLEXPORT :: fooExecuteTest
#
# end subroutine fooExecuteTest
#
# end module foo
#
# Then add the proper cmake code below to instantiate the test:
# AddEMsoftUnitTest(TARGET fooTest
#                   SOURCES ${EMsoftTestDir}/fooTest.f90
#                   TEST_NAME fooTest
#                   LINK_LIBRARIES ${EXE_LINK_LIBRARIES}
#                   SOLUTION_FOLDER EMsoftPublic/Test)
#
# The argument LINK_LIBRARIES needs to have all the proper libraries that the
# test will link against. EXE_LINK_LIBRARIES is just a CMake variable that
# the EMsoft project uses internally to list the most common 3rd part and
# internal libraries that are used. Your test may have additional libraries
# such as JSON Fortran or BLAS/LAPACK for example that are also needed.

#  /NODEFAULTLIB:msvcrt.lib /NODEFAULTLIB:msvcmrt.lib /NODEFAULTLIB:msvcurt.lib /NODEFAULTLIB:msvcrtd.lib

if(EMsoft_ENABLE_HDF5_SUPPORT)
  
  set(lib_type "static")
  if(BUILD_SHARED_LIBS)
    set(lib_type "shared")
  endif()
  set(hdf5LinkLibs hdf5 hdf5_f90cstub hdf5_fortran hdf5_hl hdf5_hl_f90cstub hdf5_hl_fortran)
  set(comps ${hdf5LinkLibs})
  set(hdf5LinkLibs "")
  foreach(comp ${comps})
    if(TARGET hdf5::${comp}-${lib_type})
      set(hdf5LinkLibs ${hdf5LinkLibs} hdf5::${comp}-${lib_type})
    endif() 
  endforeach()

  set(EXE_LINK_LIBRARIES ${EXE_LINK_LIBRARIES} ${hdf5LinkLibs} EMsoftHDFLib)

  set(EMsoft_UNIT_TESTS 
    HDFtextfile
    HDFinteger
    HDFchar
    HDFfloat
    HDFdouble
    HDFhyperslab
    HDFstack
    MODcrystal
    MODMuellerCalculus
    MODRotations
    Image
  )

  foreach(test ${EMsoft_UNIT_TESTS})
    message(STATUS "Adding Unit test: ${test}" )
    AddEMsoftUnitTest(TARGET ${test}Test
                      SOURCES ${EMsoftTestDir}/${test}Test.f90
                      TEST_NAME ${test}
                      LINK_LIBRARIES ${EXE_LINK_LIBRARIES}
                      SOLUTION_FOLDER EMsoftPublic/Test)
    if(MSVC)
        target_compile_options( ${test}Test PRIVATE "/MT$<$<CONFIG:Debug>:d>")
        target_link_options(${test}Test PRIVATE "/NODEFAULTLIB:MSVCRT")
    endif()
  endforeach()

endif()

#------------------------------------------------------------------------------
# Create CTest entries for a basic indexing workflow
#------------------------------------------------------------------------------
# Use multiple CPU cores to Test
include(ProcessorCount)
ProcessorCount(EMsoft_TEST_CPU_COUNT)

set(EXE_EXT "")
if(WIN32)
  set(EXE_EXT ".exe")
endif()

#------------------------------------------------------------------------------
# This bit ensures that the EMsoftData_DIR is set correctly or errors out.
get_filename_component(EMSOFT_PARENT ${EMsoft_SOURCE_DIR} DIRECTORY CACHE)
if("${EMsoftData_DIR}" STREQUAL "")
  if(EXISTS "${EMSOFT_PARENT}/EMsoftData")
    set(EMsoftData_DIR ${EMSOFT_PARENT}/EMsoftData)
  else()
    message(WARNING "EMsoftData_DIR not found or empty folder, cloning automatically from https://github.com/emsoft-org/EMsoftData")
message(FATAL_ERROR "${EMSOFT_PARENT}/EMsoftData")
    include(ExternalProject)
    ExternalProject_Add("EMsoftDataClone"
      GIT_REPOSITORY https://github.com/emsoft-org/EMsoftData
      GIT_TAG "develop" # get the develop branch
      DOWNLOAD_DIR "${EMSOFT_PARENT}/EMsoftData"
      GIT_SHALLOW TRUE # we don't need version history
      GIT_PROGRESS TRUE # there may be some large datafiles
      # CONFIGURE_COMMAND "" # nothing needs to be configured
      # BUILD_COMMAND "" # nothing needs to be built
      # INSTALL_COMMAND "" # nothing needs to be installed
      # TEST_COMMAND "" # nothing needs to be tested
    )

    # message(FATAL_ERROR "EMsoftData CMake Variable must point to the path to the EMsoftData repository.\
    # We looked in the same directory as the 'EMsoft' directory for a directory called EMsoftData but did not find it.\
    # You can clone it from https://github.com/emsoft-org/EMsoftData using the 'develop' branch\
    # or you can set the EMsoftData_DIR variable to point to the location of the EMsoftData directory.\    
    # ")  
  endif()
endif()

#------------------------------------------------------------------------------
#  Function: create_workflow_test
#  brief: This creates a ctest for a specific EBSD DI Workflow
#
function(create_workflow_test)
  set(options )
  set(oneValueArgs EXE_NAME INDEX OUTPUT_DIR EXTRA_NML)
  set(multiValueArgs )
  cmake_parse_arguments(TEST "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  if(NOT EXISTS ${EMsoftData_DIR}/DItutorial/Ni/${TEST_EXE_NAME}.nml)
    message(FATAL_ERROR "NML File does not exist: ${EMsoftData_DIR}/DItutorial/Ni/${TEST_EXE_NAME}.nml\
    This file is part of the EMsoftData repository. Please ensure that the EMsoftData repository is\
    up to date via a 'git pull origin develop' command. The current value of the EMsoftData_DIR is \
    ${EMsoftData_DIR}")
  endif()

  configure_file(${EMsoftData_DIR}/DItutorial/Ni/${TEST_EXE_NAME}.nml
                  ${TEST_OUTPUT_DIR}/${TEST_EXE_NAME}.nml
  )

  if(NOT "${TEST_EXTRA_NML}" STREQUAL "")
    if(NOT EXISTS ${EMsoftData_DIR}/DItutorial/Ni/${TEST_EXTRA_NML})
      message(FATAL_ERROR "NML File does not exist: ${EMsoftData_DIR}/DItutorial/Ni/${TEST_EXTRA_NML}\
      This file is part of the EMsoftData repository. Please ensure that the EMsoftData repository is\
      up to date via a 'git pull origin develop' command. The current value of the EMsoftData_DIR is \
      ${EMsoftData_DIR}")
    endif()
  
    configure_file(${EMsoftData_DIR}/DItutorial/Ni/${TEST_EXTRA_NML}
                  ${EMsoft_NML_TEST_DIR}/${TEST_EXTRA_NML}
    )
  endif()
  message(STATUS "Adding Unit Test: EMsoft_${TEST_INDEX}_${TEST_EXE_NAME}")
  add_test(NAME EMsoft_${TEST_INDEX}_${TEST_EXE_NAME}
          COMMAND "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${TEST_EXE_NAME}${EXE_EXT}" "${TEST_OUTPUT_DIR}/${TEST_EXE_NAME}.nml" 
          WORKING_DIRECTORY ${EMsoft_NML_TEST_DIR})

endfunction()


#------------------------------------------------------------------------------
# 1: The Ni.xtal file should have been copied into the proper spot via some other external means
# We are just going to have to trust that it is there. We are numbering the tests
# so that CTest runs them in the correct order.
set(test_index  "1")
set(EMsoft_NML_TEST_DIR "${EMsoft_BINARY_DIR}/DItutorial/Ni")
file(MAKE_DIRECTORY ${EMsoft_NML_TEST_DIR})

#------------------------------------------------------------------------------
# 2: Setup the EMMCOpenCL executable
math(EXPR test_index "${test_index} + 1")
create_workflow_test( EXE_NAME EMMCOpenCL
                      INDEX ${test_index}
                      OUTPUT_DIR ${EMsoft_NML_TEST_DIR}
                    )


#------------------------------------------------------------------------------
# 3: Setup the EMEBSDmaster executable
math(EXPR test_index "${test_index} + 1")
create_workflow_test( EXE_NAME EMEBSDmaster
                      INDEX ${test_index}
                      OUTPUT_DIR ${EMsoft_NML_TEST_DIR}
                      EXTRA_NML BetheParameters.nml
                    )


#------------------------------------------------------------------------------
# 4: Setup the ADP executable
math(EXPR test_index "${test_index} + 1")
create_workflow_test( EXE_NAME EMgetADP
                      INDEX ${test_index}
                      OUTPUT_DIR ${EMsoft_NML_TEST_DIR}
                    )

#------------------------------------------------------------------------------
# 5: Setup the EMEBSDDIpreview executable
math(EXPR test_index "${test_index} + 1")
create_workflow_test( EXE_NAME EMEBSDDIpreview
                      INDEX ${test_index}
                      OUTPUT_DIR ${EMsoft_NML_TEST_DIR}
                    )


#------------------------------------------------------------------------------
# 6: Setup the EMEBSDDIpreview executable
math(EXPR test_index "${test_index} + 1")
create_workflow_test( EXE_NAME EMEBSDDI
                      INDEX ${test_index}
                      OUTPUT_DIR ${EMsoft_NML_TEST_DIR}
                    )

#------------------------------------------------------------------------------
# 7: Setup the EMFitOrientation executable
math(EXPR test_index "${test_index} + 1")
create_workflow_test( EXE_NAME EMFitOrientation
                      INDEX ${test_index}
                      OUTPUT_DIR ${EMsoft_NML_TEST_DIR}
                    )

