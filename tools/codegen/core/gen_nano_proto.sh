#!/bin/bash

# Copyright 2016 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Example usage:
#   tools/codegen/core/gen_nano_proto.sh \
#     src/proto/grpc/lb/v1/load_balancer.proto \
#     $PWD/src/core/ext/filters/client_channel/lb_policy/grpclb/proto/grpc/lb/v1 \
#     src/core/ext/filters/client_channel/lb_policy/grpclb/proto/grpc/lb/v1
#
# Exit statuses:
# 1: Incorrect number of arguments
# 2: Input proto file (1st argument) doesn't exist or is not a regular file.
# 3: Options file for nanopb not found in same dir as the input proto file.
# 4: Output dir not an absolute path.
# 5: Couldn't create output directory (2nd argument).

set -ex
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 <input.proto> <absolute path to output dir> [grpc path]"
  exit 1
fi

readonly GRPC_ROOT="$PWD"
readonly INPUT_PROTO="$1"
readonly OUTPUT_DIR="$2"
readonly GRPC_OUTPUT_DIR="${3:-$OUTPUT_DIR}"
readonly EXPECTED_OPTIONS_FILE_PATH="${1%.*}.options"

if [[ ! -f "$INPUT_PROTO" ]]; then
  echo "Input proto file '$INPUT_PROTO' doesn't exist."
  exit 2
fi

if [[ ! -f "${EXPECTED_OPTIONS_FILE_PATH}" ]]; then
  echo "Input proto file may need .options file to be correctly compiled."
fi

if [[ "${OUTPUT_DIR:0:1}" != '/' ]]; then
  echo "The output directory must be an absolute path. Got '$OUTPUT_DIR'"
  exit 4
fi

mkdir -p "$OUTPUT_DIR"
if [ $? != 0 ]; then
  echo "Error creating output directory $OUTPUT_DIR"
  exit 5
fi

readonly VENV_DIR=$(mktemp -d)
readonly VENV_NAME="nanopb-$(date '+%Y%m%d_%H%M%S_%N')"
pushd $VENV_DIR
virtualenv $VENV_NAME
. $VENV_NAME/bin/activate
popd

# this should be the same version as the submodule we compile against
# ideally we'd update this as a template to ensure that
pip install protobuf==3.6.0

pushd "$(dirname $INPUT_PROTO)" > /dev/null

protoc \
--plugin=protoc-gen-nanopb="$GRPC_ROOT/third_party/nanopb/generator/protoc-gen-nanopb" \
--nanopb_out='-T -Q#include\ \"'"${GRPC_OUTPUT_DIR}"'/%s\" -L#include\ \"pb.h\"'":$OUTPUT_DIR" \
"$(basename $INPUT_PROTO)"

deactivate
rm -rf $VENV_DIR

popd > /dev/null
