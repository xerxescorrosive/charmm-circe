# CHARMM on USF CIRCE — Build Recipes

Working build recipes for CHARMM molecular dynamics on USF's CIRCE cluster.

## Status

| Build | Version | Status | Date |
|---|---|---|---|
| CPU + MPI | c50b2 stable | Working (mpirun -n 2 verified) | 2026-05-14 |
| GPU + BLaDE | c51a2 dev (sm_61, CUDA 11.3.1) | Working (10/10 BLaDE tests pass) | 2026-05-14 |

## What this documents

USF CIRCE has an older module stack (gcc 8.5 max, no FFTW module, OpenMPI without compiler tags) that does not match recipes from other clusters. This repo captures the actual working configuration: Intel 2021.2 classic compilers, MKL's FFTW3 interface, with the specific link-line workarounds CHARMM needs.

## Quick start

On CIRCE:

    # One-time setup (build MKL FFTW3 wrapper with -fPIC)
    bash build-mkl-wrapper.sh

    # Get an interactive compute node
    bash get-node.sh

    # Then on the compute node:
    bash build-c50b2-cpu.sh

## File layout

    ~/charmm/
      modules.sh                  Loads cmake/python/intel modules
      get-node.sh                 srun an interactive compute node
      build-mkl-wrapper.sh        Builds MKL FFTW3 Fortran wrapper with -fPIC
      build-c50b2-cpu.sh          Full CPU/MPI build recipe
      mkl-wrappers/fftw3xf/       Built MKL FFTW3 wrapper
      build -> /work_bgfs/.../    Symlink to source/build dir

Heavy data lives on /work_bgfs/e/ekukole/charmm-build/ (faster filesystem, 2 TB quota). Home directory holds scripts and shortcuts only - /home on CIRCE is a 100%-full shared filesystem with limited free space.

## Cluster context

CIRCE module conventions discovered during this work:

- compilers/gcc/8.5.0 is the newest gcc available. No SCL, no gcc-toolset, no 9/10/11/12.
- compilers/intel/2021.2 is the newest Intel. Provides classic icc/ifort plus newer icx/ifx, Intel MPI, MKL.
- No FFTW module exists. Amber bundles an FFTW but it is icc-built and not directly reusable.
- OpenMPI 4.1.1 is available but built against system gcc 7.5. Use Intel MPI instead for the Intel toolchain.
- CUDA 12.2.2 is available; auto-loads gcc 6.2.0 which conflicts with newer gcc modules.
- Use partition=snsm_itn19 qos=snsm19_long for multi-hour compilation jobs.

## CPU build: technical decisions

The CPU/MPI build of c50b2 required five non-obvious decisions beyond the recipe provided to me.

1. Force classic icc/ifort instead of icx/ifx. CHARMM's --with-intel selects icx/ifx (LLVM-based) by default in Intel 2021.2. ifx 2021.2 was released as Beta and segfaults internally on raise.F90. Bypass with explicit -DCMAKE_Fortran_COMPILER=ifort.

2. Suppress icc diagnostic 15551. source/domdec/sse_utils.h uses #pragma simd assert. icc 2021.2 fatal-errors on this pragma when vectorization fails. Pass -diag-disable=15551 to downgrade.

3. Build MKL's FFTW3 Fortran wrapper from source. MKL ships only the wrapper source at $MKLROOT/interfaces/fftw3xf/. Build with make libintel64 compiler=intel CFLAGS="-fPIC". The -fPIC is critical since CHARMM's libchmm.so is shared.

4. Force the wrapper into libchmm.so with --whole-archive. Shared library linking tolerates undefined symbols, so by default the wrapper objects do not get pulled in. -Wl,--whole-archive ... -Wl,--no-whole-archive forces inclusion.

5. Link MKL libraries explicitly. Classic ifort does not recognize CMake's -qmkl=sequential flag, so MKL itself does not get linked. Add -L$MKLROOT/lib/intel64 -lmkl_intel_lp64 -lmkl_sequential -lmkl_core -lpthread -lm -ldl.

Also: do NOT use both libfftw3xf_intel.a (Fortran wrapper) and libfftw3xc_intel.a (C wrapper). They have overlapping symbols and --whole-archive causes multiple-definition errors.

Also: invoke cmake directly. CHARMM's configure shell wrapper mangles -D arguments containing spaces.

## Verification

After build, the binary should produce a clean banner and NORMAL TERMINATION when given a minimal title-block input:

    ~/charmm/build/c50b2/install-cpu/bin/charmm <<EOF
    * Test
    *
    stop
    EOF

2-rank MPI test:

    mpirun -n 2 ~/charmm/build/c50b2/install-cpu/bin/charmm <<EOF
    * MPI test
    *
    stop
    EOF

## CUDA toolkit version selection

The CUDA toolkit must be compatible with the GPU driver installed on the compute nodes — not the highest available toolkit. Run `nvidia-smi` on a target node and read the `CUDA Version` line in the header; that's the maximum toolkit version that driver supports. As of 2026-05-14, snsm_itn19 GPU nodes report driver 465.27 with CUDA 11.3 max. Building against CUDA 12.2 produces a binary that compiles and passes banner tests but fails at the first real CUDA call with
`cudaErrorInsufficientDriver` (error 35). Rebuild against CUDA 11.3.1 to match.

Rule: pick the newest CUDA toolkit \u2264 the driver's maximum supported version.

## Why two CHARMM versions?

Two versions are built because Arjan provided two source tarballs with different intended roles:

- **c50b2** is a stable release. Stable releases are frozen, well-tested, and used for production CPU/MPI work where reproducibility matters. The CPU/MPI DOMDEC parallel code path has been mature for years, so a stable version is the right choice here.

- **c51a2** is a development release. Dev releases contain newer features that have not yet folded into a stable release. The BLaDE GPU molecular dynamics engine and its surrounding infrastructure (MSLD piecewise lambda dynamics, refined PME on GPU, FFTDock GPU kernels, etc.) live in c51a2.

Building each version with its target configuration isolates risk: production CPU simulations are unaffected by anything still being developed in dev, while GPU work gets access to the newest BLaDE features. When c51 eventually reaches stable (c51b1 or similar), the two builds could be unified.

This split also matches the lab's existing build pattern.

## Acknowledgments

Build performed by Emmanuel Eni, USF Computational Chemistry. CHARMM source provided by Arjan van der Vaart.
