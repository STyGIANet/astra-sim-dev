#!/bin/bash


BASHRC="$HOME/.bashrc"
PROTOCPATH="$HOME/.protocPaths"
add_if_missing() {
  grep -qxF "$1" "$2" || echo "$1" >> "$2"
}

add_if_missing_path() {
  grep -qF "$1" "$3" || echo "$2" >> "$3"
}

# Compile Abseil
cd /opt
export ABSL_VER=20240722.0
sudo wget https://github.com/abseil/abseil-cpp/releases/download/${ABSL_VER}/abseil-cpp-${ABSL_VER}.tar.gz
sudo tar -xf abseil-cpp-${ABSL_VER}.tar.gz
sudo rm abseil-cpp-${ABSL_VER}.tar.gz
cd /opt/abseil-cpp-${ABSL_VER}/
sudo mkdir ./build
cd ./build
sudo cmake .. \
    -DCMAKE_CXX_STANDARD=14 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="/opt/abseil-cpp-${ABSL_VER}/install"
sudo cmake --build . --target install --config Release --parallel $(nproc)


add_if_missing "export absl_DIR="/opt/abseil-cpp-${ABSL_VER}/install"" $PROTOCPATH

add_if_missing "export absl_DIR="/opt/abseil-cpp-${ABSL_VER}/install"" $BASHRC

add_if_missing_path 'PATH=/opt/abseil-cpp' "export PATH="/opt/abseil-cpp-${ABSL_VER}/install:$PATH"" $BASHRC

source $PROTOCPATH
echo "##############################"
echo $absl_DIR
echo "##############################"

export PROTOBUF_VER=28.3
cd /opt
sudo wget https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VER}/protobuf-${PROTOBUF_VER}.tar.gz
sudo tar -xf protobuf-${PROTOBUF_VER}.tar.gz
sudo rm protobuf-${PROTOBUF_VER}.tar.gz

## Compile Protobuf
cd /opt/protobuf-${PROTOBUF_VER}/
sudo mkdir ./build
cd ./build
sudo -E cmake .. \
    -DCMAKE_CXX_STANDARD=14 \
    -DCMAKE_BUILD_TYPE=Release \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_ABSL_PROVIDER=package \
    -DCMAKE_INSTALL_PREFIX="/opt/protobuf-${PROTOBUF_VER}/install"
sudo cmake --build . --target install --config Release --parallel $(nproc)

add_if_missing "export protobuf_DIR="/opt/protobuf-${PROTOBUF_VER}/install"" $PROTOCPATH
add_if_missing "export protobuf_DIR="/opt/protobuf-${PROTOBUF_VER}/install"" $BASHRC

add_if_missing_path 'PATH=/opt/protobuf-' "export PATH="/opt/protobuf-${PROTOBUF_VER}/install/bin:$PATH"" $BASHRC
add_if_missing_path 'PATH=/opt/protobuf-' "export PATH="/opt/protobuf-${PROTOBUF_VER}/install/bin:$PATH"" $PROTOCPATH