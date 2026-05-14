#!/bin/bash
# Request an interactive GPU compute node for CHARMM GPU building (CIRCE)
# snsm_itn19 has GTX 1070 Ti nodes (compute capability 6.1)
srun --pty \
     --partition=snsm_itn19 \
     --qos=snsm19_long \
     --gres=gpu:1 \
     --nodes=1 --ntasks=1 --cpus-per-task=8 --mem=16G \
     --time=8:00:00 \
     -J charmm-gpu \
     bash
