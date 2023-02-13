#!/bin/tcsh

# Make images for Fig. 9 of Chen et al.'s HRF-related paper, "BOLD
# response is more than just magnitude...".  These images show the
# patterns, similarities and differences of scalar relations within a
# BOLD HRF.
#
# Find the nadir (of undershoot) first, and use that to truncate the
# input, and then find the peak (of the overshoot, which should/must
# precede the undershoot) within that
#
# [Feb 13, 2022] add constraint: time-to-peak < time-to-nadir
#
# auth = PA Taylor (SSCC, NIMH, NIH, USA)
# ----------------------------------------------------------------------

# inputs
set dset_stat   = HV-con-MSS2-stats+tlrc.HEAD    # stat file; not used here
set dset_hrf_00 = HV-con-MSS2+tlrc.HEAD          # HRF: w/ anticip, w/o del_t
set delt_hrf    = 0.3125                         # time int in sample HRF

# dsets to create
set dset_hrf    = feature_HV-con-MSS2-hrf.nii.gz # HRF: w/o anticip, w/ del_t
set dset_peaktime             = feature_HV-con-hrf_time-to-peak.nii
set dset_peakval              = feature_HV-con-hrf_peak.nii
set dset_nadirtime            = feature_HV-con-hrf_time-to-nadir.nii
set dset_nadirval             = feature_HV-con-hrf_nadir.nii
set dset_peaknadirratio       = feature_HV-con-hrf_peak_nadir_ratio.nii
set dset_peaknadirratio_log10 = feature_HV-con-hrf_peak_nadir_ratio_log10.nii

set dset_nadir_freeze_tmp     = _tmp_freeze_nadir_value.nii.gz

# ----------------------------------------------------------------------
# prepare the HRF

# remove first 8 time points, which were for 'anticipation'
3dTcat \
    -overwrite \
    -prefix ${dset_hrf} ${dset_hrf_00}'[8..$]'

# set appropriate del_t for volumes
3drefit -TR ${delt_hrf} "${dset_hrf}"

# ----------------------------------------------------------------------
# nadir calculations

# time to nadir
3dTstat                                                             \
    -overwrite                                                      \
    -argmin                                                         \
    -prefix ${dset_nadirtime}                                       \
    "${dset_hrf}"

3dcalc                                                              \
    -overwrite                                                      \
    -a         ${dset_nadirtime}                                    \
    -expr      "a*${delt_hrf}"                                      \
    -prefix    ${dset_nadirtime}

# nadir value...
3dTstat                                                             \
    -overwrite                                                      \
    -min                                                            \
    -prefix ${dset_nadirval}                                        \
    "${dset_hrf}"
# ... *** times neg 1, for colorbar ***
3dcalc                                                              \
    -overwrite                                                      \
    -a         ${dset_nadirval}                                     \
    -expr      "-a"                                                 \
    -prefix    ${dset_nadirval}

# ----------------------------------------------------------------------
# peak calculations
# + with the constraint that time-to-peak < time-to-nadir

# make intermediate dataset: for each HRF, freeze the nadir value for
# all timepoints after the nadir (this makes it easier to use the
# constraint that the peak must come before the nadir when hunting for
# it); and use '-c' in the expression, because the c dataset had a
# minus sign multiplying it above, for the colorbar's sake
3dcalc                                                              \
    -overwrite                                                      \
    -a          "${dset_hrf}"                                       \
    -b          ${dset_nadirtime}                                   \
    -c          ${dset_nadirval}                                    \
    -expr       '-c*within(t,b,100)+a*not(within(t,b,100))'         \
    -prefix     ${dset_nadir_freeze_tmp}

# time-to-peak
3dTstat                                                             \
    -overwrite                                                      \
    -argmax                                                         \
    -prefix ${dset_peaktime}                                        \
    ${dset_nadir_freeze_tmp}

3dcalc                                                              \
    -overwrite                                                      \
    -a         ${dset_peaktime}                                     \
    -expr      "a*${delt_hrf}"                                      \
    -prefix    ${dset_peaktime}

# peak value 
3dTstat                                                             \
    -overwrite                                                      \
    -max                                                            \
    -prefix ${dset_peakval}                                         \
    ${dset_nadir_freeze_tmp}

# ----------------------------------------------------------------------
# peak-nadir ratio

3dcalc                                                              \
    -overwrite                                                      \
    -a         ${dset_peakval}                                      \
    -b         ${dset_nadirval}                                     \
    -expr      "abs(a)/abs(b)"                                      \
    -prefix    ${dset_peaknadirratio}

3dcalc                                                              \
    -overwrite                                                      \
    -a         ${dset_peakval}                                      \
    -b         ${dset_nadirval}                                     \
    -expr      "log10(abs(a)/abs(b))"                               \
    -prefix    ${dset_peaknadirratio_log10}

# ----------------------------------------------------------------------
# imagize

set ulay = ~/REF_TEMPLATES/MNI152_T1_2009c+tlrc.HEAD 

set olay   = ${dset_peakval}
set opref  = img_peak
set frange = 0.3

@chauffeur_afni                                                              \
    -ulay              ${ulay}                                               \
    -ulay_range        "2%" "110%"                                           \
    -olay              ${olay}                                               \
    -set_dicom_xyz     0 0 32                                                \
    -delta_slices      20 20 20                                              \
    -set_subbricks     0 0 0                                                 \
    -func_range        ${frange}                                             \
    -pbar_posonly                                                            \
    -cbar              GoogleTurbo                                           \
    -opacity           7                                                     \
    -prefix            ${opref}                                              \
    -pbar_saveim       ${opref}_pbar                                         \
    -montx             6                                                     \
    -monty             1                                                     \
    -set_xhairs        OFF                                                   \
    -zerocolor         white                                                 \
    -label_color       black                                                 \
    -label_mode        0                                                     \
    -label_size        3                                                     \
    -no_cor                                                                  \
    -no_sag


set olay   = ${dset_peaktime}
set opref  = img_time-to-peak
set frange = 10 #13.75

@chauffeur_afni                                                              \
    -ulay              ${ulay}                                               \
    -ulay_range        "2%" "110%"                                           \
    -olay              ${olay}                                               \
    -set_dicom_xyz     0 0 32                                                \
    -delta_slices      20 20 20                                              \
    -set_subbricks     0 0 0                                                 \
    -func_range        ${frange}                                             \
    -pbar_posonly                                                            \
    -cbar              GoogleTurbo                                           \
    -opacity           7                                                     \
    -prefix            ${opref}                                              \
    -pbar_saveim       ${opref}_pbar                                         \
    -montx             6                                                     \
    -monty             1                                                     \
    -set_xhairs        OFF                                                   \
    -zerocolor         white                                                 \
    -label_color       black                                                 \
    -label_mode        0                                                     \
    -label_size        3                                                     \
    -no_cor                                                                  \
    -no_sag


### discretized pbar for peak
set olay   = ${dset_peaktime}
set opref  = img_time-to-peak_DISC
set frange = 10 #13.75

@chauffeur_afni                                                              \
    -ulay              ${ulay}                                               \
    -ulay_range        "2%" "110%"                                           \
    -olay              ${olay}                                               \
    -set_dicom_xyz     0 0 32                                                \
    -delta_slices      20 20 20                                              \
    -set_subbricks     0 0 0                                                 \
    -func_range        ${frange}                                             \
    -pbar_posonly                                                            \
    -cbar_ncolors 10                                                         \
    -cbar_topval ""                                                          \
    -cbar "10=#c32503 9=#ef5811 8=#fea130 7=#e5d938 6=rbgyr20_09  5=rbgyr20_08 4=#18ddc2 3=#38a5fb 2=dk-blue 1=navy  0=none" \
    -opacity           7                                                     \
    -prefix            ${opref}                                              \
    -pbar_saveim       ${opref}_pbar                                         \
    -montx             6                                                     \
    -monty             1                                                     \
    -set_xhairs        OFF                                                   \
    -zerocolor         white                                                 \
    -label_color       black                                                 \
    -label_mode        0                                                     \
    -label_size        3                                                     \
    -no_cor                                                                  \
    -no_sag


set olay   = ${dset_nadirval}
set opref  = img_nadir
set frange = 0.3

@chauffeur_afni                                                              \
    -ulay              ${ulay}                                               \
    -ulay_range        "2%" "110%"                                           \
    -olay              ${olay}                                               \
    -set_dicom_xyz     0 0 32                                                \
    -delta_slices      20 20 20                                              \
    -set_subbricks     0 0 0                                                 \
    -func_range        ${frange}                                             \
    -pbar_posonly                                                            \
    -cbar              GoogleTurbo                                           \
    -opacity           7                                                     \
    -prefix            ${opref}                                              \
    -pbar_saveim       ${opref}_pbar                                         \
    -montx             6                                                     \
    -monty             1                                                     \
    -set_xhairs        OFF                                                   \
    -zerocolor         white                                                 \
    -label_color       black                                                 \
    -label_mode        0                                                     \
    -label_size        3                                                     \
    -no_cor                                                                  \
    -no_sag


set olay   = ${dset_nadirtime}
set opref  = img_time-to-nadir
set frange = 13.75

@chauffeur_afni                                                              \
    -ulay              ${ulay}                                               \
    -ulay_range        "2%" "110%"                                           \
    -olay              ${olay}                                               \
    -set_dicom_xyz     0 0 32                                                \
    -delta_slices      20 20 20                                              \
    -set_subbricks     0 0 0                                                 \
    -func_range        ${frange}                                             \
    -pbar_posonly                                                            \
    -cbar              GoogleTurbo                                           \
    -opacity           7                                                     \
    -prefix            ${opref}                                              \
    -pbar_saveim       ${opref}_pbar                                         \
    -montx             6                                                     \
    -monty             1                                                     \
    -set_xhairs        OFF                                                   \
    -zerocolor         white                                                 \
    -label_color       black                                                 \
    -label_mode        0                                                     \
    -label_size        3                                                     \
    -no_cor                                                                  \
    -no_sag


set olay   = ${dset_peaknadirratio_log10}
set opref  = img_peaknadirratio_log10
set frange = 1

@chauffeur_afni                                                              \
    -ulay              ${ulay}                                               \
    -ulay_range        "2%" "110%"                                           \
    -olay              ${olay}                                               \
    -set_dicom_xyz     0 0 32                                                \
    -delta_slices      20 20 20                                              \
    -set_subbricks     0 0 0                                                 \
    -func_range        ${frange}                                             \
    #-pbar_posonly                                                            \
    -cbar              Reds_and_Blues_Inv                                    \
    -opacity           7                                                     \
    -prefix            ${opref}                                              \
    -pbar_saveim       ${opref}_pbar                                         \
    -montx             6                                                     \
    -monty             1                                                     \
    -set_xhairs        OFF                                                   \
    -zerocolor         white                                                 \
    -label_color       black                                                 \
    -label_mode        0                                                     \
    -label_size        3                                                     \
    -no_cor                                                                  \
    -no_sag


cat <<EOF

++ DONE.  

See images can colorbars, respectively, with: 
eog img_*axi*png
eog img*pbar*

EOF

exit 0



