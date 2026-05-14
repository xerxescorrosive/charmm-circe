#!/bin/bash
# CHARMM c50b2 CPU/MPI build for CIRCE - working recipe (2026-05-14)
# Run inside an interactive compute node (use get-node.sh).
# Prerequisite: MKL FFTW3 wrapper built via build-mkl-wrapper.sh
set -e

source ~/charmm/modules.sh

MKL_LIBS="-L$MKLROOT/lib/intel64 -lmkl_intel_lp64 -lmkl_sequential -lmkl_core -lpthread -lm -ldl"
WRAPPER="-Wl,--whole-archive $HOME/charmm/mkl-wrappers/fftw3xf/libfftw3xf_intel.a -Wl,--no-whole-archive"
LINKER_FLAGS="$WRAPPER $MKL_LIBS"

cd "$HOME/charmm/build/c50b2"
rm -rf build-cpu
mkdir -p build-cpu
cd build-cpu

cmake \
    -DCMAKE_INSTALL_PREFIX="$HOME/charmm/build/c50b2/install-cpu" \
    -DCMAKE_C_COMPILER=icc \
    -DCMAKE_CXX_COMPILER=icpc \
    -DCMAKE_Fortran_COMPILER=ifort \
    -DMPI_C_COMPILER=mpiicc \
    -DMPI_CXX_COMPILER=mpiicpc \
    -DMPI_Fortran_COMPILER=mpiifort \
    -DCMAKE_C_FLAGS="-diag-disable=15551" \
    -DCMAKE_CXX_FLAGS="-diag-disable=15551" \
    -DCMAKE_EXE_LINKER_FLAGS="$LINKER_FLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$LINKER_FLAGS" \
    ../stable-release-master 2>&1 | tee configure-cpu.log

make -j8 2>&1 | tee make-cpu.log
make install 2>&1 | tee install-cpu.log

echo ""
echo "=== Build complete ==="
ls -la "$HOME/charmm/build/c50b2/install-cpu/bin/charmm"
file "$HOME/charmm/build/c50b2/install-cpu/bin/charmm"
