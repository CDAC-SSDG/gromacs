cmake_minimum_required(VERSION 3.18)
project(ParaSTest LANGUAGES CXX)

add_executable(ParaSTest test_paras_sycl.cpp)

# Use the compiler CMake was given (parascc)
set_target_properties(ParaSTest PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)

