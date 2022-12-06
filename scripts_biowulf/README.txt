This directory contains the main processing scripts for analyzing the
raw FMRI and anatomical data.  These scripts include nonlinear warp
estimation to standard space, full single subject processing through
regression modeling, and a couple different forms of group level
modeling.

These scripts were run on the NIH's Biowulf computing cluster, hence
there are considerations for batch processing with the slurm system.
Each processing step is divided into a pair of associated scripts:

+ **do_SOMETHING.tcsh**: a script that mostly contains the processing
  options and commands for a single subject, with subject ID and any
  other relevant information passed in as a command line argument when
  using it.  Most of the lines at the top of the file set up the
  processing, directory structure (most every step generates a new
  filetree called `data_SOMETHING/`), and usage of a scratch disk for
  intermediate outputs.  At some point, actual processing commands are
  run, and then there is a bit of checking, copying from the scratch
  disk and verifying permissions, and then exiting.

+ **run_SOMETHING.tcsh**: mostly manage the group-level aspects of
  things, to set up processing over all subjects of interest and start
  a swarm job running on the cluster.

---------------------------------------------------------------------------
The enumeration in script names is to help to organize the order of
processing (kind of a Dewey Decimal-esque system).  Gaps between
numbers are fine---they just leave space for other processing steps to
have been inserted, as might be necessary.  Loosely, each "decade" of
enumeration corresponds to a different stage of processing:

+ the 10s are preliminary processing steps (skullstripping and
  nonlinear alignment for the anatomical)
+ the 20s are afni_proc.py processing of the FMRI data

---------------------------------------------------------------------------

The script details (recall: just listing the do_* scripts, since the
run_* ones just correspond to a swarming that step):

+ do_13_ssw.tcsh
  Run AFNI's @SSwarper (SSW) for skullstripping (ss) and nonlinear
  alignment (warping) to MNI template space

+ do_24_ap_task_NL.tcsh
  Run AFNI's afni_proc.py (AP) for full processing of the FMRI data,
  through single subject regression modeling (here, with blurring, to
  be used for voxelwise analyses); uses results of earlier stages;
  also produces QC HTML
