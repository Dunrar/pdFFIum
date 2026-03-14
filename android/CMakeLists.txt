cmake_minimum_required(VERSION 3.25.2)

add_library(libpdfium SHARED IMPORTED GLOBAL)
set_target_properties(libpdfium PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI}/libpdfium.so)