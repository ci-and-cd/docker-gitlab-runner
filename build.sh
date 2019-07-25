#!/usr/bin/env bash

set -e

docker version
docker-compose version

WORK_DIR=$(pwd)

if [ -n "${CI_OPT_DOCKER_REGISTRY_PASS}" ] && [ -n "${CI_OPT_DOCKER_REGISTRY_USER}" ]; then echo ${CI_OPT_DOCKER_REGISTRY_PASS} | docker login --password-stdin -u="${CI_OPT_DOCKER_REGISTRY_USER}" docker.io; fi

export IMAGE_PREFIX=${IMAGE_PREFIX:-cirepo/};
export IMAGE_NAME=${IMAGE_NAME:-gitlab-runner}
export IMAGE_TAG=${IMAGE_ARG_VERSION:-12.1.0}-${IMAGE_ARG_LOCALE:-en_US}.${IMAGE_ARG_ENCODING:-UTF-8}_${IMAGE_ARG_TZ_AREA:-Etc}.${IMAGE_ARG_TZ_ZONE:-UTC}-bionic
if [ "${TRAVIS_BRANCH}" != "master" ]; then export IMAGE_TAG=${IMAGE_TAG}-SNAPSHOT; fi

sed "s#%IMAGE_ARG_ENCODING%#${IMAGE_ARG_ENCODING:-UTF-8}#g" Dockerfile_template | \
  sed "s#%IMAGE_ARG_LOCALE%#${IMAGE_ARG_LOCALE:-en_US}#g" | \
  sed "s#%IMAGE_ARG_TZ_AREA%#${IMAGE_ARG_TZ_AREA:-Etc}#g" | \
  sed "s#%IMAGE_ARG_TZ_ZONE%#${IMAGE_ARG_TZ_ZONE:-UTC}#g" > Dockerfile

# Build image
if [[ "$(docker images -q ${IMAGE_PREFIX}${IMAGE_NAME}:${IMAGE_TAG} 2> /dev/null)" == "" ]]; then
    docker-compose build
fi

docker-compose push
