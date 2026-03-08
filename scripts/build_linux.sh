#!/bin/sh
#
# Mac ARM users, rosetta can be flaky, so to use a remote x86 builder
#
# docker context create amd64 --docker host=ssh://mybuildhost
# docker buildx create --name mybuilder amd64 --platform linux/amd64
# docker buildx create --name mybuilder --append desktop-linux --platform linux/arm64
# docker buildx use mybuilder


set -eu


cd $(dirname $0)/..
. ollama/scripts/env.sh

mkdir -p dist


docker buildx build \
    --output type=local,dest=./dist/ \
    --platform=linux/amd64 \
    ${OLLAMA_COMMON_BUILD_ARGS} \
    --target archive \
    -f Dockerfile \
    .
