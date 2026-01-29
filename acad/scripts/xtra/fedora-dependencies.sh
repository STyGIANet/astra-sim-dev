#!/bin/bash
sudo dnf -y update
sudo dnf -y install coreutils wget vim git
sudo dnf -y install gcc-13 g++-13 make cmake
sudo dnf -y install clang-format
sudo dnf -y install boost-devel
sudo dnf -y install python3-pip
sudo dnf -y install protobuf-devel protobuf-compiler
sudo dnf -y install openmpi-devel openmpi-doc
# Python packages
if command -v conda &> /dev/null; then
    conda uninstall -y libprotobuf
fi
pip3 install --upgrade pip
pip3 install protobuf==5.28.2
pip3 install graphviz pydot

# Brace yourself for compilation erros if you have protoc installed in conda :D
# I had to uninstall it from conda to get it working