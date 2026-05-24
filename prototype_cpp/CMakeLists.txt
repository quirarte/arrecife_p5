cmake_minimum_required(VERSION 3.20)
project(arrecife_vision_prototype LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(OpenCV REQUIRED)

add_executable(arrecife_vision_prototype
  src/main.cpp
  src/AppConfig.cpp
  src/RoiConfig.cpp
  src/AlphaSegmenter.cpp
  src/VisionPrototypeApp.cpp
)

target_include_directories(arrecife_vision_prototype PRIVATE src)
target_link_libraries(arrecife_vision_prototype PRIVATE ${OpenCV_LIBS})
