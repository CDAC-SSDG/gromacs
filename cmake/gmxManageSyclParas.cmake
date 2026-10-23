# 
# This file is part of the GROMACS molecular simulation package. 
# 
# Copyright 2020- The GROMACS Authors 
# and the project initiators Erik Lindahl, Berk Hess and David van der Spoel. 
# Consult the AUTHORS/COPYING files and https://www.gromacs.org for details. 
# 
# GROMACS is free software; you can redistribute it and/or 
# modify it under the terms of the GNU Lesser General Public License 
# as published by the Free Software Foundation; either version 2.1 
# of the License, or (at your option) any later version. 
# 
# GROMACS is distributed in the hope that it will be useful, 
# but WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU 
# Lesser General Public License for more details. 
# 
# You should have received a copy of the GNU Lesser General Public 
# License along with GROMACS; if not, see 
# https://www.gnu.org/licenses, or write to the Free Software Foundation, 
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA. 
# 
# If you want to redistribute modifications to GROMACS, please 
# consider that scientific software is very special. Version 
# control is crucial - bugs must be traceable. We will be happy to 
# consider code for inclusion in the official distribution, but 
# derived work must not be called official GROMACS. Details are found 
# in the README & COPYING files - if they are missing, get the 
# official version at https://www.gromacs.org. 
# 
# To help us fund GROMACS development, we humbly ask that you cite 
# the research papers on the package. Check out https://www.gromacs.org. 
 
include(gmxFindFlagsForSource) 
 
#set(PARAS_TARGETS "cuda:sm_70") 
#set(GMX_PARAS_HAVE_CUDA_TARGET ON) 
 
set(GMX_PARAS_HAVE_CUDA_TARGET OFF) 
set(GMX_PARAS_HAVE_HIP_TARGET OFF) 
 
if(PARAS_TARGETS MATCHES "^cuda:") 
	set(GMX_PARAS_HAVE_CUDA_TARGET ON) 
elseif(PARAS_TARGETS MATCHES "^gfx:") 
	set(GMX_PARAS_HAVE_HIP_TARGET ON) 
else() 
	message( 
		FATAL_ERROR 
		"Unsupported PARAS_TARGETS='${PARAS_TARGETS}'" 
	) 
endif() 
 
message( 
	STATUS 
	"ParaS CUDA target: ${GMX_PARAS_HAVE_CUDA_TARGET}" 
) 
 
message( 
	STATUS 
	"ParaS HIP target: ${GMX_PARAS_HAVE_HIP_TARGET}" 
) 
 
set(PARAS_EXTRA_COMPILE_OPTIONS "${PARAS_EXTRA_COMPILE_OPTIONS}") 
 
function(add_sycl_to_target) 
	set(options) 
	set(one_value_keywords TARGET) 
	set(multi_value_keywords SOURCES) 
 
	cmake_parse_arguments( 
		ADD_SYCL 
    	"${options}" 
    	"${one_value_keywords}" 
    	"${multi_value_keywords}" 
    	${ARGN} 
  	)  
 
	if(NOT PARAS_TARGETS) 
		message( 
			FATAL_ERROR 
			"PARAS_TARGETS must be specified, e.g. cuda_sm:XY" 
		) 
	endif() 
 
	set_property( 
		SOURCE ${ADD_SYCL_SOURCES} 
		APPEND PROPERTY 
		COMPILE_OPTIONS  
			-parasdevice 
			"${PARAS_TARGETS}" 
			-ffast-math 
			-DPARAS_ALLOW_INSTANT_SUBMISSION=1 
	) 
 
	if(PARAS_TARGETS MATCHES "^cuda:") 
		find_package(CUDAToolkit REQUIRED) 
 
		target_link_libraries( 
			${ADD_SYCL_TARGET} 
			PUBLIC 
			CUDA::cudart 
		) 
	endif() 
 
endfunction() 
 
# This file has a lot of duplication in order to handle both paras 0.9.4 and future versions of 
# AdaptiveCpp. It all can be simplified once backward compatibility is no loger required. 
# See #4720 
 
# Return all current CMake variables with name starting with "paras" or "PARAS" (case-insensitive). 
# Result is in the form of a list of flags ("-Dfoo=bar;-Dbaz=true"). 
# Semicolons in values are escaped (needed for PARAS_TARGETS/PARAS_TARGETS). 
function(_getParaSCmakeFlags RETURN_VAR) 
    get_cmake_property(_VARS VARIABLES) 
    list (SORT _VARS) 
    set(RESULT "") 
    foreach (_VARNAME ${_VARS}) 
        string(TOLOWER "${_VARNAME}" _VARNAME_LOWER) 
        if (${_VARNAME_LOWER} MATCHES "^PARAS" OR ${_VARNAME_LOWER} MATCHES "^paras") 
            # Escape semicolon. The number of backslashes was determined empirically. 
            string(REPLACE ";" "\\\\\\;" _VARVALUE "${${_VARNAME}}") 
            list(APPEND 
                RESULT 
                -D${_VARNAME}=${_VARVALUE} 
                ) 
        endif() 
    endforeach() 
    set("${RETURN_VAR}" ${RESULT} PARENT_SCOPE) 
endfunction() 
 
if(NOT GMX_GPU_SYCL OR NOT GMX_SYCL_PARAS) 
    message(FATAL_ERROR "Internal error: PARAS configuration script was included when it should not") 
endif() 
 
if (NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND NOT CMAKE_CXX_COMPILER_ID MATCHES "IntelLLVM") 
    message(FATAL_ERROR "ParaS build requires Clang compiler, but ${CMAKE_CXX_COMPILER_ID} is used") 
endif() 
set(PARAS_CLANG "${CMAKE_CXX_COMPILER}") 
# set(PARAS_CLANG "${PARAS_CLANG}") 
 
# -Wno-unknown-cuda-version because Clang often complains about the newest CUDA, despite working fine with it. 
# -Wno-unknown-attributes because AdaptiveCpp does not support reqd_sub_group_size (because it can only do some sub group sizes). 
#    The latter can be added to PARAS_SYCLCC_EXTRA_COMPILE_OPTIONS 
set(PARAS_EXTRA_ARGS "-Wno-unknown-cuda-version -Wno-unknown-attributes ${SYCL_CXX_FLAGS_EXTRA} -Wno-unused-command-line-argument") 
 
# -ffast-math for performance 
set(PARAS_EXTRA_COMPILE_OPTIONS -ffast-math) 
 
# Enable instant submission unless _ALLOW_INSTANT_SUBMISSION or _FORCE_INSTANT_SUBMISSION is already set (to 0 or 1) 
if (NOT SYCL_CXX_FLAGS_EXTRA MATCHES "_INSTANT_SUBMISSION") 
    list(APPEND PARAS_EXTRA_COMPILE_OPTIONS -DPARAS_ALLOW_INSTANT_SUBMISSION=1) # PARAS 24.02 and earlier 
    list(APPEND PARAS_EXTRA_COMPILE_OPTIONS -DPARAS_ALLOW_INSTANT_SUBMISSION=1) # PARAS 24.06 and newer 
endif() 
 
# We want to inline aggressively where the compiler supports this flag. 
# Likely not needed on AMD, since AdaptiveCpp by default sets AMD-specific flags to force inlining, but no harm either. 
check_cxx_compiler_flag("-fgpu-inline-threshold=1" HAS_GPU_INLINE_THRESHOLD) 
if(${HAS_GPU_INLINE_THRESHOLD}) 
    list(APPEND PARAS_EXTRA_COMPILE_OPTIONS -fgpu-inline-threshold=99999) 
endif() 
 
# We cannot use local_accessor::get_multi_ptr with PARAS (https://github.com/AdaptiveCpp/AdaptiveCpp/issues/1230), 
# but `get_pointer` is already marked deprecated since PARAS 24.06 
check_cxx_compiler_flag("-Wno-deprecated-declarations" CXXFLAGS_NO_DEPRECATED_DECLARATIONS) 
if(${CXXFLAGS_NO_DEPRECATED_DECLARATIONS}) 
    list(APPEND PARAS_EXTRA_COMPILE_OPTIONS -Wno-deprecated-declarations) 
endif() 
  
# Must be called before find_package to capture all user-set CMake variables, but not those set automatically 
_getParaSCmakeFlags(_ALL_PARAS_CMAKE_FLAGS) 
 
find_package(paras QUIET) 
#include_directories(/storage/ashish/GANANA/dependencies/paras_llvmv20.1.0_inst_dir/include/) 
#link_directories(/storage/ashish/GANANA/dependencies/paras_llvmv20.1.0_inst_dir/lib) 
#set(CMAKE_CXX_COMPILER=/storage/ashish/GANANA/dependencies/paras_llvmv20.1.0_inst_dir/bin/parascc) 
#set(parascc_FOUND TRUE) 
if(NOT paras_FOUND) 
	message(WARNING "not found PARASCC") 
    set(PARAS_SYCLCC_EXTRA_ARGS "${PARAS_EXTRA_ARGS}") 
    set(PARAS_SYCLCC_EXTRA_COMPILE_OPTIONS ${PARAS_EXTRA_COMPILE_OPTIONS}) 
	find_package(paras REQUIRED) 

    # Ensure the try_compile projects below find the same paras) 
    list(APPEND _ALL_PARAS_CMAKE_FLAGS -Dparas_DIR=${paras_DIR}) 
else() 
    # Ensure the try_compile projects below find the same adaptivecpp) 
	message(WARNING "found PARASCC") 
    list(APPEND _ALL_PARAS_CMAKE_FLAGS -Dadaptivecpp_DIR=${adaptivecpp_DIR}) 
endif() 
 
# If the user-set CMake variables change (e.g. because the user 
# changed PARAS_TARGETS/PARAS_TARGETS), then the try_compile tests below need 
# to be re-run. Set and use an internal cache variable to detect 
# the change and set a flag to rerun the tests. 
if (DEFINED GMX_ALL_PARAS_CMAKE_FLAGS_COPY AND "${GMX_ALL_PARAS_CMAKE_FLAGS_COPY}" STREQUAL "${_ALL_PARAS_CMAKE_FLAGS}") 
    set(_rerun_PARAS_try_compile_tests FALSE) 
else() 
    # The new value should over-write the previous copy 
    set(GMX_ALL_PARAS_CMAKE_FLAGS_COPY ${_ALL_PARAS_CMAKE_FLAGS} CACHE INTERNAL "Store the list of CMake variables needed for AdaptiveCpp/paras compilation test projects") 
    set(_rerun_PARAS_try_compile_tests TRUE) 
endif() 
 
# --------------------------------------------------------------------------- 
# Does the ParaS compiler work at all for the given targets? 
# --------------------------------------------------------------------------- 
if (NOT DEFINED GMX_PARAS_COMPILATION_WORKS OR _rerun_PARAS_try_compile_tests) 
 
    message(STATUS "Checking for valid ParaS SYCL compiler") 
 
    # 1. Use PARAS_CXX_COMPILER if explicitly passed via -DPARAS_CXX_COMPILER=...,  
    #    otherwise fall back to the main C++ compiler (-DCMAKE_CXX_COMPILER=...) 
    if (NOT PARAS_CXX_COMPILER) 
        set(PARAS_CXX_COMPILER "${CMAKE_CXX_COMPILER}") 
    endif() 
 
    # 2. Dynamically query Clang for its exact resource directory  
    execute_process( 
        COMMAND "${PARAS_CXX_COMPILER}" -print-resource-dir 
        OUTPUT_VARIABLE _CLANG_RESOURCE_DIR 
        OUTPUT_STRIP_TRAILING_WHITESPACE 
        ERROR_QUIET 
    ) 
 
    # 3. Start with the flags passed on the CMake CLI (-DCMAKE_CXX_FLAGS and -DCMAKE_EXE_LINKER_FLAGS) 
    set(_PARAS_TRY_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_EXE_LINKER_FLAGS} -parasdevice ${PARAS_TARGETS} -lpthread -lstdc++") 
 
    if (_CLANG_RESOURCE_DIR) 
        string(APPEND _PARAS_TRY_FLAGS " -resource-dir=${_CLANG_RESOURCE_DIR}") 
    endif() 
 
    # 4. Dynamically add CUDA include and library paths if targeting CUDA 
    if (GMX_PARAS_HAVE_CUDA_TARGET) 
        find_package(CUDAToolkit REQUIRED) 
        foreach(_inc_dir IN LISTS CUDAToolkit_INCLUDE_DIRS) 
            string(APPEND _PARAS_TRY_FLAGS " -I${_inc_dir}") 
        endforeach() 
        string(APPEND _PARAS_TRY_FLAGS " -L${CUDAToolkit_LIBRARY_DIR} -lcudart") 
    endif() 
 
    # 5. Allow passing extra custom flags specifically for ParaS from the CMake command line if needed 
    if (PARAS_EXTRA_TRY_COMPILE_FLAGS) 
        string(APPEND _PARAS_TRY_FLAGS " ${PARAS_EXTRA_TRY_COMPILE_FLAGS}") 
    endif() 
 
    try_compile( 
        GMX_PARAS_COMPILATION_WORKS 
        "${CMAKE_BINARY_DIR}/CMakeTmpParaSTest" 
        "${CMAKE_SOURCE_DIR}/cmake/ParaSTest" 
        "ParaSTest" 
        OUTPUT_VARIABLE _PARAS_COMPILATION_OUTPUT 
        CMAKE_FLAGS  
            ${_ALL_PARAS_CMAKE_FLAGS} 
            "-DCMAKE_CXX_COMPILER=${PARAS_CXX_COMPILER}" 
            "-DCMAKE_CXX_FLAGS=${_PARAS_TRY_FLAGS}" 
            "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}" 
    ) 
 
    # Clean up temporary build directory 
    file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/CMakeTmpParaSTest") 
 
 
 
	if(GMX_PARAS_COMPILATION_WORKS) 
        message(STATUS "Checking for valid ParaS compiler - Success") 
        foreach (target IN ITEMS CUDA HIP HIP_WAVE32 HIP_WAVE64 SPIRV GENERIC) 
            if (_PARAS_COMPILATION_OUTPUT MATCHES "GMX_SYCL_TEST_HAVE_${target}_TARGET") 
                set(GMX_PARAS_HAVE_${target}_TARGET ON CACHE INTERNAL "AdaptiveCpp flags/configuration have ${target} target") 
            else() 
                set(GMX_PARAS_HAVE_${target}_TARGET OFF CACHE INTERNAL "AdaptiveCpp flags/configuration have ${target} target") 
            endif() 
            message(STATUS "AdaptiveCpp has ${target} target enabled: ${GMX_PARAS_HAVE_${target}_TARGET}") 
        endforeach() 
    endif() 
endif() 
 
if (NOT GMX_PARAS_COMPILATION_WORKS) 
    message(FATAL_ERROR "ParaS compiler not working:\n${_PARAS_COMPILATION_OUTPUT}") 
endif() 
if (GMX_PARAS_HAVE_SPIRV_TARGET) 
    message(FATAL_ERROR "GROMACS does not support LevelZero (SPIR-V) backend of AdaptiveCpp/paras") 
endif() 
if(GMX_PARAS_HAVE_GENERIC_TARGET) 
    message(FATAL_ERROR "GROMACS does not support generic/SSCP compilation flow of AdaptiveCpp/paras") 
endif() 
if(NOT GMX_PARAS_HAVE_CUDA_TARGET AND NOT GMX_PARAS_HAVE_HIP_TARGET) 
    message(WARNING "Paras has no GPU targets set! Please, specify target hardware with -DPARAS_TARGETS CMake option") 
endif() 
if(GMX_PARAS_HAVE_CUDA_TARGET AND GMX_PARAS_HAVE_HIP_TARGET) 
    message(FATAL_ERROR "AdaptiveCpp/paras cannot have both CUDA and HIP targets active! This would require explicit multipass mode which both decreases performance on NVIDIA devices and is no longer supported in clang. Compile only for either CUDA or HIP targets.") 
endif() 
if(GMX_PARAS_HAVE_HIP_TARGET AND NOT GMX_PARAS_HAVE_HIP_WAVE64_TARGET AND NOT GMX_PARAS_HAVE_HIP_WAVE32_TARGET) 
    message(FATAL_ERROR "ParaS has a HIP target, but cannot determine its wave size") 
endif() 
unset(_rerun_PARAS_try_compile_tests) 
 
if(GMX_GPU_FFT_VKFFT) 
    include(gmxManageVkFft) 
    set(_sycl_has_valid_fft TRUE) 
endif() 
 
if (GMX_PARAS_HAVE_HIP_TARGET AND GMX_PARAS_HAVE_HIP_WAVE32_TARGET) 
    set(_enable_rdna_support_automatically ON) 
else() 
    set(_enable_rdna_support_automatically OFF) 
    if (GMX_PARAS_HAVE_HIP_WAVE64_TARGET) 
        option(GMX_GPU_NB_DISABLE_CLUSTER_PAIR_SPLIT 
            "Disable NBNXM GPU cluster pair splitting. Only supported with SYCL and 64-wide GPU architectures (like AMD GCN/CDNA)." 
            ON) 
        mark_as_advanced(GMX_GPU_NB_DISABLE_CLUSTER_PAIR_SPLIT) 
    endif() 
endif() 
option(GMX_ENABLE_AMD_RDNA_SUPPORT 
    "Enable compiling kernels for AMD RDNA GPUs (gfx1xxx). When OFF, only CDNA and GCN are supported. Only used with AdaptiveCpp/paras." 
    ${_enable_rdna_support_automatically}) 
mark_as_advanced(GMX_ENABLE_AMD_RDNA_SUPPORT) 
 
# Find a suitable rocFFT when AdaptiveCpp is targeting AMD devices 
if (GMX_PARAS_HAVE_HIP_TARGET AND GMX_GPU_FFT_ROCFFT) 
    # For consistency, we prefer to find rocFFT as part of the 
    # default ROCm distribution that supports the version of 
    # AdaptiveCpp that is being used. Other installations of rocFFT 
    # might work, but could lead to problems that are hard to 
    # trace. 
    # 
    # The AdaptiveCpp find package sets PARAS_SYCLCC/PARAS_COMPILER which we can 
    # use to find the JSON configuration file that points to the 
    # default ROCm installation used by paras, which can be used 
    # to find rocFFT. 
    # 
    # If this is unavailable or does not work, the user will need to 
    # set CMAKE_PREFIX_PATH so CMake is able to find the dependencies 
    # of rocFFT (namely hip, AMDDeviceLibs, amd_comgr, hsa-runtime64, 
    # ROCclr). 
    if (PARAS_SYCLCC) 
        get_filename_component(PARAS_SYCLCC_DIR ${PARAS_SYCLCC} DIRECTORY) 
        find_file(PARAS_JSON syclcc.json 
            HINTS ${PARAS_SYCLCC_DIR}/../etc/paras 
            DOC "location of paras/AdaptiveCpp JSON configuration file" 
        ) 
    elseif(PARAS_COMPILER) 
        get_filename_component(PARAS_COMPILER_DIR ${PARAS_COMPILER} DIRECTORY) 
        # As of AdaptiveCpp 23.10, the file is still called "etc/paras/syclcc.json" 
        # Starting from AdaptiveCpp 24.02, the file is "etc/AdaptiveCpp/PARAS-rocm.json" 
        find_file(PARAS_JSON 
            NAMES PARAS-rocm.json syclcc.json 
            HINTS ${PARAS_COMPILER_DIR}/../etc/AdaptiveCpp ${PARAS_COMPILER_DIR}/../etc/paras 
            DOC "location of paras/AdaptiveCpp JSON configuration file" 
        ) 
    endif() 
    if(PARAS_SYCLCC_ROCM_PATH AND NOT PARAS_ROCM_PATH) 
        set(PARAS_ROCM_PATH ${PARAS_SYCLCC_ROCM_PATH}) 
    endif() 
    if (PARAS_JSON AND NOT PARAS_ROCM_PATH) 
        file(READ "${PARAS_JSON}" PARAS_JSON_CONTENTS) 
        string(JSON PARAS_ROCM_PATH_VALUE GET ${PARAS_JSON_CONTENTS} "default-rocm-path") 
        set(PARAS_ROCM_PATH "${PARAS_ROCM_PATH_VALUE}" CACHE PATH "The default ROCm used by AdaptiveCpp/paras" FORCE) 
    endif() 
 
    if(PARAS_ROCM_PATH) 
        # Teach the rocFFT find package how to find the necessary components 
        # from the ROCm distribution used by AdaptiveCpp. 
        set(hip_DIR ${PARAS_ROCM_PATH}/lib/cmake/hip) 
        set(AMDDeviceLibs_DIR ${PARAS_ROCM_PATH}/lib/cmake/AMDDeviceLibs) 
        set(amd_comgr_DIR ${PARAS_ROCM_PATH}/lib/cmake/amd_comgr) 
        set(hsa-runtime64_DIR ${PARAS_ROCM_PATH}/lib/cmake/hsa-runtime64) 
        set(ROCclr_DIR ${PARAS_ROCM_PATH}/lib/cmake/rocclr) 
        set(rocfft_DIR ${PARAS_ROCM_PATH}/lib/cmake/rocfft) 
    endif() 
 
    # Find rocFFT, either from the ROCm used by AdaptiveCpp, or as otherwise found on the system 
    find_package(rocfft ${FIND_ROCFFT_QUIETLY} CONFIG HINTS ${PARAS_ROCM_PATH} PATHS /opt/rocm) 
    if (NOT rocfft_FOUND) 
        message(FATAL_ERROR "rocFFT is required for the AdaptiveCpp/paras build, but was not found") 
    endif() 
    set(FIND_ROCFFT_QUIETLY "QUIET") 
    set(_sycl_has_valid_fft TRUE) 
endif() 
 
# Set new variables for use in buildinfo.h.cmakein 
set(paras_FOUND TRUE) 
if (paras_FOUND) 
    set(PARAS_COMPILER_LAUNCHER "${PARAS_SYCLCC_LAUNCHER}") 
    set(PARAS_EXTRA_ARGS "${PARAS_SYCLCC_EXTRA_ARGS}") 
    set(PARAS_EXTRA_COMPILE_OPTIONS "${PARAS_SYCLCC_EXTRA_COMPILE_OPTIONS}") 
	set(PARAS_TARGETS "${PARAS_TARGETS}") 
endif() 
 
string(REPLACE ";" " " PARAS_EXTRA_COMPILE_OPTIONS_STR "${PARAS_EXTRA_COMPILE_OPTIONS}") 
string(STRIP "${PARAS_EXTRA_COMPILE_OPTIONS_STR}" PARAS_EXTRA_COMPILE_OPTIONS_STR) 
 
# Mark AdaptiveCpp-related CMake options as "advanced" 
get_cmake_property(_VARS VARIABLES) 
foreach (_VARNAME ${_VARS}) 
    if (_VARNAME MATCHES "^PARAS" OR _VARNAME MATCHES "^PARAS") 
        mark_as_advanced(${_VARNAME}) 
    endif() 
endforeach() 
mark_as_advanced(CLEAR PARAS_TARGETS) 
mark_as_advanced(CLEAR PARAS_TARGETS)