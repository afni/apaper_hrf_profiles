# apaper_hrf_profiles
Scripts accompanying Chen et al. (2023) work on modeling, visualizing and understanding FMRI hemodynamic response.

---------------------------------------------------------------------------
Essentially all scripts here use AFNI.

The `scripts_biowulf` directory contains the main processing scripts,
including:
+ Checking the data
+ Estimating nonlinear alignment to template space and skullstripping
  with `@SSwarper`
+ Full FMRI time series processing through regression modeling and QC
  generation with `afni_proc.py`

... and more.
