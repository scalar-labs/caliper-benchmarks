#!/bin/sh

CONFIG=$1
SCALAR_CONFIG_DIR=networks/scalardl

echo "===> Moving from ${PWD} to ${SCALAR_CONFIG_DIR}/scalar-samples"
cd ${SCALAR_CONFIG_DIR}/scalar-samples

docker-compose -p caliper-scalar-samples down
