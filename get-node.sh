#!/bin/bash
# Request an interactive compute node for CHARMM building (CIRCE)
srun --pty \
     --partition=snsm_itn19 \
     --qos=snsm19_long \
     --nodes=1 --ntasks=1 --cpus-per-task=8 --mem=16G \
     --time=8:00:00 \
     -J charmm-build \
     bash
