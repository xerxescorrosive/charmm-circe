#!/bin/bash
# Build MKL's FFTW3 Fortran wrapper with -fPIC for CHARMM linkage.
# -fPIC is mandatory because the wrapper is linked into libchmm.so (shared).
set -e

source ~/charmm/modules.sh

mkdir -p ~/charmm/mkl-wrappers
cd ~/charmm/mkl-wrappers
rm -rf fftw3xf
cp -r "$MKLROOT/interfaces/fftw3xf" .
cd fftw3xf

make libintel64 compiler=intel INSTALL_DIR="$PWD" CFLAGS="-fPIC" 2>&1 | tee build-fpic.log

echo ""
echo "=== Build verification ==="
echo "Lines containing -fPIC: $(grep -c fPIC build-fpic.log)"
echo "Archive:"
ls -la libfftw3xf_intel.a
