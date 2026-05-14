#!/bin/bash
# CHARMM c51a2 GPU+BLaDE build for CIRCE
# Target: snsm_itn19 nodes (GTX 1070 Ti, compute capability 6.1)
# Toolchain: Intel 2021.2 + CUDA 12.2.2 + MKL FFTW3 wrappers
# Run inside an interactive GPU compute node (use get-gpu-node.sh).
# Prerequisite: MKL FFTW3 wrapper built via build-mkl-wrapper.sh
set -e

# CUDA module first (it auto-loads gcc 6.2.0; we'll let it then load Intel after)
module purge
module load apps/cmake/3.27.5
module load apps/python/3.8.5
module load apps/cuda/12.2.2

# Force-unload the gcc that CUDA dragged in
module unload compilers/gcc/6.2.0 2>/dev/null || true

# Now Intel - its compilers will take precedence in PATH
module load compilers/intel/2021.2

# Confirm we're using the right tools
echo "=== Compiler tools ==="
which icc ifort nvcc cmake
echo "MKLROOT=$MKLROOT"
echo "CUDA_HOME=$CUDA_HOME"

# Link flags: same as CPU build
MKL_LIBS="-L$MKLROOT/lib/intel64 -lmkl_intel_lp64 -lmkl_sequential -lmkl_core -lpthread -lm -ldl"
WRAPPER="-Wl,--whole-archive $HOME/charmm/mkl-wrappers/fftw3xf/libfftw3xf_intel.a -Wl,--no-whole-archive"
LINKER_FLAGS="$WRAPPER $MKL_LIBS"

cd "$HOME/charmm/build/c51a2"
rm -rf build-gpu
mkdir -p build-gpu
cd build-gpu

cmake \
    -DCMAKE_INSTALL_PREFIX="$HOME/charmm/build/c51a2/install-gpu" \
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
    -DCUDAToolkit_ROOT=/apps/cuda/12.2.2 \
    -DCMAKE_CUDA_COMPILER=/apps/cuda/12.2.2/bin/nvcc \
    -DCMAKE_CUDA_ARCHITECTURES=61 \
    -Du=ON \
    -Dblade=ON \
    -Dfftdock=ON \
    -Dopenmm=OFF \
    ../dev-release-master 2>&1 | tee configure-gpu.log

make -j8 2>&1 | tee make-gpu.log
make install 2>&1 | tee install-gpu.log

echo ""
echo "=== Build complete ==="
ls -la "$HOME/charmm/build/c51a2/install-gpu/bin/charmm"
file "$HOME/charmm/build/c51a2/install-gpu/bin/charmm"
