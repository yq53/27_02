cmake_minimum_required(VERSION 3.16)
project(exam2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(task1 src/task1.cpp)
add_executable(task3 src/task3.cpp)
add_executable(task4 src/task4.cpp)

target_include_directories(task3 PRIVATE include)

find_package(yaml-cpp REQUIRED)

target_link_libraries(task1 PRIVATE yaml-cpp::yaml-cpp)