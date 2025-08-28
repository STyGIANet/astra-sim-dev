#!/bin/bash

source config.sh

sudo apt -y update
sudo apt -y install coreutils wget vim git
sudo apt -y install gcc-13 g++-13 make cmake 
sudo apt -y install clang-format 
sudo apt -y install libboost-dev libboost-program-options-dev

./install-protobuf.sh
source ~/.protocPaths
# Install protobuf and dependencies
# sudo apt -y install libprotobuf-dev protobuf-compiler
# sudo ./install-protobuf.sh
# source ~/.protocPaths
# source ~/.bashrc

##################################################
# Install Python 3.10 and pip
if ! command -v pyenv >/dev/null 2>&1; then
  echo "pyenv not found. Installing..."
  curl https://pyenv.run | bash
else
  echo "pyenv is already installed."
fi
PROFILE="$HOME/.bashrc"

add_if_missing() {
  grep -qxF "$1" "$PROFILE" || echo "$1" >> "$PROFILE"
}

add_if_missing_path() {
  grep -qF "$1" "$PROFILE" || echo "$2" >> "$PROFILE"
}

add_if_missing_path 'pyenv/bin' 'export PATH="$HOME/.pyenv/bin:$PATH"'
add_if_missing 'export PROTOBUF_FROM_SOURCE="True"'
add_if_missing 'eval "$(pyenv init -)"'
add_if_missing 'eval "$(pyenv virtualenv-init -)"'