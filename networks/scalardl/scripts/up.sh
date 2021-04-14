#!/bin/sh

SLEEP_SEC=$1
SCALAR_CONFIG_DIR=networks/scalardl

error_exit() {
  msg=$1
  printf "\e[31m${msg}\e[m\n"
  exit 1
}

echo "===> Moving from ${PWD} to ${SCALAR_CONFIG_DIR}"
cd ${SCALAR_CONFIG_DIR}

# clone (if needed) scalar-labs/scalar-samples
if [ -d scalar-samples ]; then
  # If scalar-samples repo already cloned and in current directory,
  # cd scalar-samples and checkout corresponding version
  echo "===> Checking out latest version of scalar-labs/scalar-samples"
  cd scalar-samples && git pull
else
  echo "===> Cloning scalar-labs/scalar-samples repo"
  git clone -b master https://github.com/scalar-labs/scalar-samples.git && cd scalar-samples
fi

rm -f ./cfssl/data/*
yes | docker-compose -p caliper-scalar-samples up -d || error_exit "!!! Docker compose failed. If you do not have Scalar DL images, make sure that you have done 'docker login' in advance"

echo "Waiting for starting Scalar DL servers (${SLEEP_SEC} seconds)"
sleep ${SLEEP_SEC}
