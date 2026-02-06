cmake_minimum_required(VERSION 3.16)
project(blunux-installer VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Compiler flags
add_compile_options(-Wall -Wextra -pedantic)

# Release optimizations
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_compile_options(-O2)
endif()

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_SOURCE_DIR}/vendor)

# Source files
set(SOURCES
    src/main.cpp
    src/config.cpp
    src/tui.cpp
    src/installer.cpp
    src/disk.cpp
)

# Executable
add_executable(blunux-installer ${SOURCES})

# Installation
install(TARGETS blunux-installer DESTINATION bin)
