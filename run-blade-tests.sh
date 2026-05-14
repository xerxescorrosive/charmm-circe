#!/bin/bash
# Run Arjan's requested BLaDE test inputs against the GPU build of CHARMM.
# All tests run from the test/ directory with scratch/ available.
set +e

source ~/charmm/modules.sh
export CUDA_HOME=/apps/cuda/11.3.1
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

CHARMM=$HOME/charmm/build/c51a2/install-gpu/bin/charmm
TESTROOT=$HOME/charmm/build/c51a2/dev-release-master/test
RESULTS=$HOME/charmm/blade-test-results
mkdir -p "$RESULTS"
mkdir -p "$TESTROOT/scratch"

declare -a TESTS=(
    "c47test/blade_energy.inp"
    "c47test/blade_md.inp"
    "c47test/blade_msld.inp"
    "c47test/blade_switch.inp"
    "c49test/blade_minimize.inp"
    "c51test/blade_cons_dihe.inp"
    "c51test/blade_cutoffs.inp"
    "c51test/blade_msld_piecewise.inp"
    "c51test/blade_pmel_energy.inp"
    "c51test/blade_vshift.inp"
)

declare -a STATUS=()

cd "$TESTROOT"

for t in "${TESTS[@]}"; do
    name=$(basename "$t" .inp)
    outfile="$RESULTS/${name}.out"

    echo ""
    echo "==========================================="
    echo "Test: $t"
    echo "Output: $outfile"
    echo "==========================================="

    timeout 600 "$CHARMM" < "$t" > "$outfile" 2>&1
    rc=$?

    if [ $rc -eq 124 ]; then
        STATUS+=("TIMEOUT  $t")
        echo "RESULT: TIMEOUT (>10 min)"
    elif grep -q "Error in file.*blade" "$outfile"; then
        err=$(grep "Error string" "$outfile" | head -1 | sed 's/^.*Error string: //')
        STATUS+=("FAIL_BLADE $t -- $err")
        echo "RESULT: BLaDE error: $err"
    elif grep -q "NORMAL TERMINATION" "$outfile"; then
        if grep -q "NO WARNINGS WERE ISSUED" "$outfile"; then
            STATUS+=("PASS     $t (no warnings)")
            echo "RESULT: PASS"
        else
            nwarn=$(grep -c "WARNING" "$outfile")
            STATUS+=("PASS_W   $t ($nwarn warnings)")
            echo "RESULT: PASS with $nwarn warnings"
        fi
    else
        STATUS+=("FAIL_RC$rc $t")
        echo "RESULT: FAILED (rc=$rc, no NORMAL TERMINATION)"
    fi
done

echo ""
echo "==========================================="
echo "Summary of all 10 tests"
echo "==========================================="
for s in "${STATUS[@]}"; do
    echo "  $s"
done
echo ""
echo "Full outputs: $RESULTS/"
