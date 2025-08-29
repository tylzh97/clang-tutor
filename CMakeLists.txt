cmake_minimum_required(VERSION 3.20)
project(clang-tutor)

#===============================================================================
# 1. FIND AND VALIDATE LLVM/CLANG
#===============================================================================

# Find the llvm-config executable. It's our source of truth for the
# version and compiler flags. FATAL_ERROR if not found.
find_program(LLVM_CONFIG_EXECUTABLE llvm-config
    REQUIRED
    DOC "Path to llvm-config executable"
)
message(STATUS "Found llvm-config: ${LLVM_CONFIG_EXECUTABLE}")

# Helper macro to execute llvm-config and handle errors.
macro(execute_llvm_config option output_var)
    execute_process(
        COMMAND ${LLVM_CONFIG_EXECUTABLE} ${option}
        OUTPUT_VARIABLE ${output_var}
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE result
    )
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "llvm-config ${option} failed with exit code ${result}")
    endif()
endmacro()

# Get and check the LLVM version from llvm-config.
execute_llvm_config(--version LLVM_PACKAGE_VERSION)
if("${LLVM_PACKAGE_VERSION}" VERSION_LESS 19)
  message(FATAL_ERROR "Found LLVM ${LLVM_PACKAGE_VERSION}, but need LLVM 19 or above.")
endif()
message(STATUS "Found LLVM/Clang version: ${LLVM_PACKAGE_VERSION}")

#===============================================================================
# 2. LOAD CLANG CONFIGURATION
#
# We let find_package do the heavy lifting. It will automatically use hints
# from the environment (like CMAKE_PREFIX_PATH set by Nix) or from user-
# provided variables (-DClang_DIR=...). This is more robust than assuming
# a specific directory layout.
#===============================================================================

# Find the Clang package, requiring the same version we found via llvm-config.
# The CONFIG mode ensures it uses ClangConfig.cmake.
find_package(Clang ${LLVM_PACKAGE_VERSION} REQUIRED CONFIG)

message(STATUS "Successfully loaded Clang package configuration.")
message(STATUS "  LLVM Includes: ${LLVM_INCLUDE_DIRS}")
message(STATUS "  Clang Includes: ${CLANG_INCLUDE_DIRS}")

# Set the LLVM and Clang header paths for the project.
include_directories(SYSTEM ${LLVM_INCLUDE_DIRS} ${CLANG_INCLUDE_DIRS})

#===============================================================================
# 3. CLANG-TUTOR BUILD CONFIGURATION
#===============================================================================

# Set the C++ standard.
set(CMAKE_CXX_STANDARD 17 CACHE STRING "C++ standard")
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set a default build type if none is specified.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type (Default: Debug)" FORCE)
endif()

# Get the recommended CXX flags from llvm-config. This is the most reliable way
# to match the compiler options (like -fno-rtti) that LLVM/Clang was built with.
execute_llvm_config(--cxxflags CMAKE_CXX_FLAGS_INIT)

# Append project-specific flags.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_INIT} -Wall -fdiagnostics-color=always" CACHE STRING "Compiler flags")

# Set the output directories for binaries and libraries.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")

#===============================================================================
# 4. ADD SUB-TARGETS
#===============================================================================
add_subdirectory(test)
add_subdirectory(lib)
add_subdirectory(tools)
add_subdirectory(HelloWorld)
