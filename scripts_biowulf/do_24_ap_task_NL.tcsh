#!/bin/tcsh

# AP_TASK_NL: use stims and full SSW.
# --> This uses 3dLocalUnifize to help AEA.  Also puts back rad_cor

# NOTES
#
# + This is a Biowulf script (has slurm stuff)
# + Run this script in the scripts/ dir, via the corresponding run_*tcsh
# + The ${dir_basic} is in a different spot than in present ${inroot}
# + Filenames are not quite fully BIDSy (e.g., see ${dset_anat_00})
# + There is no session level ${ses} 
# + Module loading Python 3.9 here, but not necessary

# ----------------------------- biowulf-cmd ---------------------------------
# load modules
source /etc/profile.d/modules.csh
module load afni python/3.9 

# set N_threads for OpenMP
# + consider using up to 4 threads, because of "-parallel" in recon-all
setenv OMP_NUM_THREADS $SLURM_CPUS_PER_TASK

# compress BRIK files
setenv AFNI_COMPRESSOR GZIP

# initial exit code; we don't exit at fail, to copy partial results back
set ecode = 0
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# top level definitions (constant across demo)
# ---------------------------------------------------------------------------

# labels
set subj           = $1
set ses            = $2

set template       = MNI152_2009_template_SSW.nii.gz 

# upper directories
set dir_inroot     = ${PWD:h}                        # one dir above scripts/
set dir_log        = ${dir_inroot}/logs
set dir_basic      = ${dir_inroot}/BIDS
set dir_fs         = ${dir_inroot}/data_12_fs
set dir_ssw        = ${dir_inroot}/data_13_ssw
set dir_physio     = ${dir_inroot}/data_14_physio
set dir_timing     = ${dir_inroot}/data_15_timing
set dir_ap         = ${dir_inroot}/data_24_ap_task_NL

# subject directories
set sdir_basic     = ${dir_basic}/${subj}/${ses}
set sdir_epi       = ${sdir_basic}/func
set sdir_fs        = ${dir_fs}/${subj}/${ses}
set sdir_suma      = ${sdir_fs}/SUMA
set sdir_ssw       = ${dir_ssw}/${subj}/${ses}
set sdir_physio    = ${dir_physio}/${subj}/${ses}
set sdir_timing    = ${dir_timing}/${subj}/${ses}
set sdir_ap        = ${dir_ap}/${subj}/${ses}

# --------------------------------------------------------------------------
# data and control variables
# --------------------------------------------------------------------------

# dataset inputs
set dsets_epi   = ( ${sdir_basic}/func/${subj}_${ses}_task-Weissman?_bold.nii* )
set dset_anat_00  = ${sdir_basic}/anat/${subj}_${ses}_T1w.nii.gz
set anat_cp       = ${sdir_ssw}/anatSS.${subj}.nii*

# SSW alignment data
set dsets_NL_warp = ( ${sdir_ssw}/anatQQ.${subj}.nii                    \
                      ${sdir_ssw}/anatQQ.${subj}.aff12.1D               \
                      ${sdir_ssw}/anatQQ.${subj}_WARP.nii  )

# timing files
set stim_dir      = ${sdir_timing} 
set timing_files  = ( ${stim_dir}/Con_corr_${subj:gas/sub-//}-*AM.1D    \
                      ${stim_dir}/Incon_cor_${subj:gas/sub-//}-*AM.1D   \
                      ${stim_dir}/Error_${subj:gas/sub-//}-*.1D  )
set stim_classes  = ( Congruent Incongruent Error )

# control variables
set nt_rm         = 6
set warp_dxyz     = 3.5                    # final (isotropic) voxel size
set blur_size     = 6.5
set cen_motion    = 0.3
set cen_outliers  = 0.05
set run_csim      = yes
set njobs         = `afni_check_omp`


# check available N_threads and report what is being used
set nthr_avail = `afni_system_check.py -disp_num_cpu`
set nthr_using = `afni_check_omp`

echo "++ INFO: Using ${nthr_avail} of available ${nthr_using} threads"

# ----------------------------- biowulf-cmd --------------------------------
# try to use /lscratch for speed 
if ( -d /lscratch/$SLURM_JOBID ) then
    set usetemp  = 1
    set sdir_BW  = ${sdir_ap}
    set sdir_ap = /lscratch/$SLURM_JOBID/${subj}  #_${ses}

    # do here bc of group permissions
    \mkdir -p ${sdir_BW}
    set grp_own = `\ls -ld ${sdir_BW} | awk '{print $4}'`
else
    set usetemp  = 0
endif
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# run programs
# ---------------------------------------------------------------------------

set ap_cmd = ${sdir_ap}/ap.cmd.${subj}

\mkdir -p ${sdir_ap}

# write AP command to file 
cat << EOF >! ${ap_cmd}

# This adds useful APQC HTML items, radial correlation images of initial
# and volume-registered data (might see artifacts):
#   -radial_correlate_blocks  tcat volreg
# 
# Even though we load the skullstripped anatomical (proc'ed by @SSwarper), 
# having the original, skull-on dataset brought along as a follower dset
# can be useful for verifying EPI-anatomical alignment if the CSF is bright:
#   -anat_follower            anat_w_skull anat \${anat_skull}
#
# Generally recommended to run @SSwarper prior to afni_proc.py for 
# skullstripping (SS) the anatomical and estimating nonlinear warp to
# template;  then provide those results in options here:
#   -copy_anat                \${anat_cp}
#   ...
#   -tlrc_base                \${template}
#   -tlrc_NL_warp                               
#   -tlrc_NL_warped_dsets     \${dsets_NL_warp} 
#
# This option can help improve EPI-anatomical alignment, esp. if the EPI
# has brightness inhomogeneity (and it doesn't seem to hurt alignment even
# if that is not the case); generally recommended with human FMRI 
# data processing nowadays:
#   -align_unifize_epi        local 
#
# Generally recommended starting point for EPI-anatomical alignment in human
# FMRI proc (left-right flipping can still occur...):
#   -align_opts_aea           -check_flip -cost lpc+ZZ -giant_move -AddEdge
#
# Which EPI should be a consistently good choice to serve as a
# reference for both motion correction and EPI-anatomical alignment?  
# The one with the fewest outliers sounds good:
#   -volreg_align_to          MIN_OUTLIER
#
# Add a post-volreg TSNR plot to the APQC HTML:
#   -volreg_compute_tsnr      yes
#
# Blur data for voxelwise analysis; min voxel dim is 3.75 mm, and blur rad
# was 6.5 mm:
#   -blur_size                \${blur_size} 
#
# Create useful mask from EPI-anatomical mask intersection (not applied
# to the EPI data here, but used to identify brain region):
#   -mask_epi_anat            yes
#
# Modeling the HRF with TENT functions, setting 'knot' number and timing:
#   -regress_basis            'TENT(-2.5,13.75,14)' 
#
# Keep the stimulus timing consistent with FMRI volumes, when 6 initial 
# volumes are removed at start of processing (TR = 1.25 s)
#    -regress_stim_times_offset  -7.5
#
# Try to use Python's Matplotlib module when making the APQC HTML doc, for
# prettier (and more informative) plots; this is actually the default now:
#   -html_review_style        pythonic
#

afni_proc.py                                                                 \
    -subj_id                  ${subj}                                        \
    -blocks                   despike tshift align tlrc volreg mask blur     \
                              scale regress                                  \
    -dsets                    ${dsets_epi}                                   \
    -tcat_remove_first_trs    ${nt_rm}                                       \
    -radial_correlate_blocks  tcat volreg                                    \
    -copy_anat                ${anat_cp}                                     \
    -anat_has_skull           no                                             \
    -anat_follower            anat_w_skull anat ${dset_anat_00}              \
    -volreg_align_to          MIN_OUTLIER                                    \
    -volreg_align_e2a                                                        \
    -volreg_tlrc_warp                                                        \
    -volreg_warp_dxyz         ${warp_dxyz}                                   \
    -align_opts_aea           -check_flip -cost lpc+ZZ -giant_move -AddEdge  \
    -align_unifize_epi        local                                          \
    -tlrc_base                ${template}                                    \
    -tlrc_NL_warp                                                            \
    -tlrc_NL_warped_dsets     ${dsets_NL_warp}                               \
    -mask_epi_anat            yes                                            \
    -blur_in_mask             yes                                            \
    -blur_size                ${blur_size}                                   \
    -blur_to_fwhm                                                            \
    -regress_stim_times       ${timing_files}                                \
    -regress_stim_labels      ${stim_classes}                                \
    -regress_stim_times_offset  -7.5                                         \
    -regress_basis            'TENT(-2.5,13.75,14)'                          \
    -regress_stim_types       AM2 AM2 times                                  \
    -regress_local_times                                                     \
    -regress_motion_per_run                                                  \
    -regress_censor_motion    ${cen_motion}                                  \
    -regress_censor_outliers  ${cen_outliers}                                \
    -regress_compute_fitts                                                   \
    -regress_make_ideal_sum   sum_ideal.1D                                   \
    -regress_est_blur_epits                                                  \
    -regress_est_blur_errts                                                  \
    -regress_run_clustsim     ${run_csim}                                    \
    -regress_reml_exec                                                       \
    -regress_opts_reml        -GOFORIT 99                                    \
    -regress_opts_3dD                                                        \
        -bout                                                                \
        -jobs                 ${njobs}                                       \
        -allzero_OK                                                          \
        -GOFORIT              99                                             \
        -num_glt              11                                             \
        -gltsym               'SYM: +Incongruent -Congruent'                 \
        -glt_label            1 InconCon                                     \
        -gltsym               'SYM: +.5*Incongruent +.5*Congruent'           \
        -glt_label            2 ImgvFix                                      \
        -gltsym               'SYM: +2*Error -Incongruent -Congruent'        \
        -glt_label            3 ErrorvCorrect                                \
        -gltsym               'SYM: +Incongruent[1] -Congruent[1]'           \
        -glt_label            4 InconConAM                                   \
        -gltsym               'SYM: +.5*Incongruent[1] +.5*Congruent[1]'     \
        -glt_label            5 ImgvFixAM                                    \
        -gltsym               'SYM: +.3333*Incongruent[4] +.3333*Incongruent[5] +.3333*Incongruent[6]' \
        -glt_label            6 PeakTentIncon                                \
        -gltsym               'SYM: +.3333*Congruent[4] +.3333*Congruent[5] +.3333*Congruent[6]' \
        -glt_label            7 PeakTentCon                                  \
        -gltsym              'SYM: +.3333*Incongruent[4] +.3333*Incongruent[5] +.3333*Incongruent[6] -.3333*Congruent[4] -.3333*Congruent[5] -.3333*Congruent[6]'                                       \
        -glt_label            8 PeakTentInconCon                             \
        -gltsym               'SYM: +.3333*Incongruent[18] +.3333*Incongruent[19] +.3333*Incongruent[20]' \
        -glt_label            9 PeakAMIncon                                  \
        -gltsym               'SYM: +.3333*Congruent[18] +.3333*Congruent[19] +.3333*Congruent[20]' \
        -glt_label            10 PeakAMCon                                    \
        -gltsym              'SYM: +.3333*Incongruent[18] +.3333*Incongruent[19] +.3333*Incongruent[20] -.3333*Congruent[18] -.3333*Congruent[19] -.3333*Congruent[20]'                                     \
        -glt_label            11 PeakAMInconCon                              \
    -regress_3dD_stop                                                        \
    -html_review_style        pythonic
 

EOF

if ( ${status} ) then
    set ecode = 1
    goto COPY_AND_EXIT
endif

cd ${sdir_ap}

# run AP to make proc script
tcsh -xef ${ap_cmd} |& tee output.run_ap_${subj}.txt

if ( ${status} ) then
    set ecode = 2
    goto COPY_AND_EXIT
endif

# run proc script
time tcsh -xef proc.${subj} |& tee output.${subj}.txt

if ( ${status} ) then
    set ecode = 3
    goto COPY_AND_EXIT
endif

echo "++ done proc ok"

# ---------------------------------------------------------------------------

COPY_AND_EXIT:

# ----------------------------- biowulf-cmd --------------------------------
# copy back from /lscratch to "real" location
if( ${usetemp} && -d ${sdir_ap} ) then
    echo "++ Used /lscratch"
    echo "++ Copy from: ${sdir_ap}"
    echo "          to: ${sdir_BW}"
    #\mkdir -p ${sdir_BW}
    \cp -pr   ${sdir_ap}/* ${sdir_BW}/.
    
    # reset grp permissions
    chgrp -R ${grp_own} ${sdir_BW}
endif
# ---------------------------------------------------------------------------

if ( ${ecode} ) then
    echo "++ BAD FINISH: AP_TASK_NL (ecode = ${ecode})"
else
    echo "++ GOOD FINISH: AP_TASK_NL"
endif

exit $ecode

