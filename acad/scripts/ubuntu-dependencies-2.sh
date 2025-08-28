#!/bin/bash

source config.sh

PROFILE="$HOME/.bashrc"

add_if_missing() {
  grep -qxF "$1" "$PROFILE" || echo "$1" >> "$PROFILE"
}

add_if_missing_path() {
  grep -qF "$1" "$PROFILE" || echo "$2" >> "$PROFILE"
}

sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev libffi-dev liblzma-dev libncurses-dev
if pyenv versions --bare | grep -q '^3.10.18$'; then
  echo "Python 3.10.18 already installed. Uninstalling first..."
  pyenv uninstall -f 3.10.18
fi

echo "Installing Python 3.10.18..."
pyenv install 3.10.18
cd $PROJECT_DIR
$HOME/.pyenv/versions/3.10.18/bin/python -m venv .venv
source .venv/bin/activate
# export PS1='[$(realpath --relative-to="$PROJECT_DIR" "$PWD")] astra-sim> '
##################################################

sudo apt -y install openmpi-bin openmpi-doc libopenmpi-dev
# Python packages
pip3 install --upgrade pip
# if command -v conda &> /dev/null; then
#     conda uninstall -y libprotobuf
# fi
pip3 uninstall -y protobuf && pip3 install protobuf==5.28.3
pip3 install graphviz pydot

cd $PROJECT_DIR
./utils/install_chakra.sh
cd .venv/bin
source activate
# export PS1='[$(realpath --relative-to="$PROJECT_DIR" "$PWD")] astra-sim> '
source ~/.protocPaths
cd $PROJECT_DIR/.venv
find . -name "*_pb2.py" -delete && find . -name "*.proto" -exec bash -c 'for f; do d=$(dirname "$f"); b=$(basename "$f"); /opt/protobuf-28.3/install/bin/protoc --proto_path="$d" --python_out="$d" "$b"; done' bash {} +
cd $PROJECT_DIR
find . -name "*_pb2.py" -delete && find . -name "*.proto" -exec bash -c 'for f; do d=$(dirname "$f"); b=$(basename "$f"); /opt/protobuf-28.3/install/bin/protoc --proto_path="$d" --python_out="$d" "$b"; done' bash {} +