#!/bin/bash

set -e

APP=~/projects/jiangtun/jiangtun-opt
INPUT=tj_01_bicrystal_singleOP_circle_shrink_bounds_param.i
NPROC=38

echo "=================================================="
echo "Start interface-width scan for tj_01 benchmark"
echo "App   : ${APP}"
echo "Input : ${INPUT}"
echo "MPI   : ${NPROC}"
echo "=================================================="

run_case () {
  local H=$1
  local NAME=$2

  echo "--------------------------------------------------"
  echo "Running case: ${NAME}"
  echo "int_width = ${H}"
  echo "Start time: $(date)"
  echo "--------------------------------------------------"

  mpiexec -np ${NPROC} ${APP} -i ${INPUT} \
    int_width=${H} \
    my_filename="'${NAME}'"

  echo "Finished case: ${NAME}"
  echo "End time: $(date)"
  echo
}

run_case 6.0  tj_01_bi_circle_shrink_bounds_h6
run_case 8.0  tj_01_bi_circle_shrink_bounds_h8
run_case 10.0 tj_01_bi_circle_shrink_bounds_h10

echo "=================================================="
echo "All interface-width cases finished."
echo "=================================================="