#!/bin/bash

set -e

APP=~/projects/jiangtun/jiangtun-opt
INPUT=tj_01_bicrystal_singleOP_circle_shrink_bounds_param.i
NPROC=24

echo "=================================================="
echo "Start mesh convergence study for tj_01 benchmark"
echo "App   : ${APP}"
echo "Input : ${INPUT}"
echo "MPI   : ${NPROC}"
echo "=================================================="

run_case () {
  local NX=$1
  local NY=$2
  local NAME=$3

  echo "--------------------------------------------------"
  echo "Running case: ${NAME}"
  echo "Mesh: nx=${NX}, ny=${NY}"
  echo "Start time: $(date)"
  echo "--------------------------------------------------"

  mpiexec -np ${NPROC} ${APP} -i ${INPUT} \
    nx=${NX} \
    ny=${NY} \
    my_filename="'${NAME}'"

  echo "Finished case: ${NAME}"
  echo "End time: $(date)"
  echo
}

run_case 100 100 tj_01_bi_circle_shrink_bounds_n100
run_case 200 200 tj_01_bi_circle_shrink_bounds_n200
run_case 400 400 tj_01_bi_circle_shrink_bounds_n400

echo "=================================================="
echo "All mesh convergence cases finished."
echo "=================================================="