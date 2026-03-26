#!/bin/bash

set -e

APP=~/projects/jiangtun/jiangtun-opt
INPUT=tj_01_bicrystal_singleOP_circle_shrink_bounds_param.i
NPROC=38

echo "=================================================="
echo "Start m*sigma scaling test for tj_01 benchmark"
echo "App   : ${APP}"
echo "Input : ${INPUT}"
echo "MPI   : ${NPROC}"
echo "=================================================="

run_case () {
  local SIGMA=$1
  local MOBILITY=$2
  local NAME=$3

  echo "--------------------------------------------------"
  echo "Running case: ${NAME}"
  echo "sigma    = ${SIGMA}"
  echo "mobility = ${MOBILITY}"
  echo "m*sigma  = $(awk "BEGIN {print ${SIGMA} * ${MOBILITY}}")"
  echo "Start time: $(date)"
  echo "--------------------------------------------------"

  mpiexec -np ${NPROC} ${APP} -i ${INPUT} \
    sigma=${SIGMA} \
    mobility=${MOBILITY} \
    my_filename="'${NAME}'"

  echo "Finished case: ${NAME}"
  echo "End time: $(date)"
  echo
}

run_case 1.0 1.0 tj_01_bi_circle_shrink_bounds_ms1
run_case 2.0 1.0 tj_01_bi_circle_shrink_bounds_ms2
run_case 4.0 1.0 tj_01_bi_circle_shrink_bounds_ms4

echo "=================================================="
echo "All m*sigma scaling cases finished."
echo "=================================================="