#-----------------------------
# Written in front
# author:Jety Cai
# data:2019/04/22
# the script is very basic and simple, learned from the Coursera course named 'Introduction to Neurohacking In R'
# Rule: you should replace your code to the {……}, and the information in the {} is the prompt with some examples below.

setwd('{PRINT_DATA_PATH}')
# --------E.G.--------#
setwd('./data')
# --------END---------#

#-----------------------------
# Load brain images, supporting the fomats of DICOM and NII(recommended), or others (using a special way)

# Load DICOM data
library(oro.dicom)
dcm <- readDICOMFile('{ONE_SLICE_DICOMIMAGE_PATH}')
dcm_all <- readDICOM('{ALL_DICOMIMAGES_PATH}')
# --------E.G.--------#
dcm_all <- readDICOM('./BRAINIX/DICOM/T1/')
dcm <- readDICOMFile('./BRAINIX/DICOM/T1/IM-0001-0010.dcm')
# --------END---------#
extractHeader(dcm$hdr, "Manufacturer", numeric=FALSE) # extract header information
image(t(dcm$img), col=grey(0:64/64), axes=FALSE, xlab="", ylab="", main="Example image from DICOM file") # visualization
nii_fr_dcm <- dicom2nifti(dcm_all) # transform into NII

# Load NII data
library(oro.nifti)
nii <- readNIfTI('{NIIIMAGE_PATH}',reorient=FALSE)
writeNIfTI(nim=nii_fr_dcm,filename='{NIIIMAGE_OUTPUT_PATH}') # gzipped=TRUE(default)
# --------E.G.--------#
nii <- readNIfTI('./kirby21/SUBJ0001-01-MPRAGE.nii.gz',reorient=FALSE)
writeNIfTI(nim=nii_fr_dcm,filename='./BRAINIX/T1')
# --------END---------#
image(1:dim(nii)[1],1:dim(nii)[2],nii[,,10],col=gray(0:64/64),xlab="",ylab="") # show one_slice_image
image(nii,z=10,plot.type="single") # another way to show one_slice_image
image(nii) # show all_images
orthographic(nii) # show from all planes: Coronal, Sagittal, Axial

# Load other formats, like nrrd
# Strategy: using the package of ants to load the image as an object of antsImage, then change to nii format
library(ANTsR)
library(extrantsr)
ants_img=antsImageRead("{IMAGE_PATH}")
# --------E.G.--------#
ants_img=antsImageRead("./t1.nrrd")
# --------END---------#
nii_fr_ants <- ants2oro(ants_img)

#-----------------------------
# Smoothing by GaussSmoothArray (Not very neccessary in our-deep-learning program)
library(AnalyzeFMRI)
# --------E.G.--------#
nii_smooth <- GaussSmoothArray(nii,voxdim=c(1,1,1),ksize=1,sigma=diag(3,3),mask=NULL,var.norm=FALSE)
# --------END---------#
orthographic(nii_smooth)

#-----------------------------
# Bias Field Correction
# using fsl
library(fslr)
nii_fast = fsl_biascorrect(nii, retimg=TRUE)
orthographic(nii_fast)

# using ANTsR
library(ANTsR)
nii_n3 = bias_correct(nii, correction = "N3",retimg=TRUE)
nii_n4 = bias_correct(nii, correction = "N4",retimg=TRUE) # recommended
orthographic(nii_n3)
orthographic(nii_n4)

#-----------------------------
# Brain Extraction (Not very neccessary in our-classification program)
# using fslr (basic-bet2) based the image processed by bias field correction
nii_bet <- fslbet(infile=nii_n4, retimg=TRUE)
nii_bet_mask <- niftiarr(nii_bet, 1)
nii_bet_mask[nii_bet<=0] <- NA
orthographic(nii_bet)
orthographic(nii_n4,nii_bet_mask)

# improving by fslr (one method of COG if only 'bet2' is not good enough, more details in the help of bet/bet2)
cog = cog(nii_bet, ceil=TRUE) # get the center of gravity (COG)
cog = paste("-c", paste(cog, collapse= " ")) # '-c ** ** **'
nii_bet2 = fslbet(infile=nii_n4,retimg=TRUE,opts=cog)
nii_bet2_mask <- niftiarr(nii_bet2, 1)
nii_bet2_mask[nii_bet2<=0] <- NA
orthographic(nii_bet2)
orthographic(nii_n4,nii_bet2_mask)
# loop above code to correct the COG until getting satisfactory result
cog = cog(nii_bet2, ceil=TRUE)
cog = paste("-c", paste(cog, collapse= " "))
nii_bet3 = fslbet(infile=nii_n4,retimg=TRUE,opts=cog)
nii_bet3_mask <- niftiarr(nii_bet3, 1)
nii_bet3_mask[nii_bet3<=0] <- NA
orthographic(nii_bet3)
orthographic(nii_n4,nii_bet3_mask)

# using wrapper function 'fslbet_robust' in extrantsr
# fslbet_robust: Robust Skull Stripping with COG estimation and Bias Correction (recommended)
nii_bet_robust <- fslbet_robust(img = nii_n4, correct = FALSE, verbose = FALSE) # using image after bias field correction
nii_bet_robust_mask <- niftiarr(nii_bet_robust, 1)
nii_bet_robust_mask[nii_bet_robust<=0] <- NA
orthographic(nii_bet_robust)
orthographic(nii_n4,nii_bet_robust_mask)
nii_bet_robust2 <- fslbet_robust(img = nii, correct = FALSE, verbose = FALSE) # using original image to skull skipping and bias field correction (N4) together
nii_bet_robust2_mask <- niftiarr(nii_bet_robust2, 1)
nii_bet_robust2_mask[nii_bet_robust2<=0] <- NA
orthographic(nii_bet_robust2)
orthographic(nii_n4,nii_bet_robust2_mask)

#-----------------------------
# Registration(with Co-registration)
# --------INTRODUCTION--------#
# FSL:
#  1. linear registration(rigid, affine),using FLIRT tool
#  2. non-linear registration (image after affine registration), using FNIRT tool
# ANTsR/extrantsr:
#  1. ants_regwrite with rigid, affine and non-linear
# Strategy:
#  1. Register the images with the skull on (due to the property of our program)
#  2. Bias field correction before registration
#  3. Co-Registration within the same subject among sequences using fewer degrees of freedom, like rigid
#  4. Registration to the template by the affine and non-linear, then applied to other sequences
#  warning: omit the process of registering the follow-up to the baseline, due to unneccesity in our-program, but the methods are the same.
# --------E.G.--------#

# 1. Prepare the data
mridir=file.path('kirby21', "visit_1", "113")
T1_file=file.path(mridir, "113-01-MPRAGE.nii.gz")
T1=readNIfTI(T1_file,reorient=FALSE)
T2_file=file.path(mridir, "113-01-T2w.nii.gz")
T2=readNIfTI(T2_file)
flair_file=file.path(mridir, "113-01-FLAIR.nii.gz")
flair=readNIfTI(flair_file)

# 2. Bias field correction
# [Omit]

# 3. Co-Registration within the same subject
# Note: in fact better to use corrected images, here using original images directly for convenience

# using fslr-flirt
T2_flirt = flirt(infile=T2, reffile=T1,dof = 6,verbose = FALSE)
double_ortho(T1, T2_flirt)

# using ants_regwrite (recommended)
T2_reg_ants = ants_regwrite(filename = T2,template.file=T1,typeofTransform="Rigid",verbose= FALSE)
flair_reg_ants = ants_regwrite(filename = flair,template.file=T1,typeofTransform="Rigid",verbose= FALSE)
double_ortho(T1, T2_reg_ants)
double_ortho(T1, flair_reg_ants)

# visualization of Overlay
library(scales)
ortho2(T1, flair_reg_ants, col.y = alpha(hotmetal(), 0.25))
ortho2(T1, T2_reg_ants, col.y = alpha(hotmetal(), 0.25))


# 2-3. using preprocess_mri_within or fslbet_robust to bias field correction and co-resgistration togethor
# preprocess_mri_within: within-visit registration using a rigid-body transformation, correction, skull stripping and potentially re-correcting after skull stripping.
# fslbet_robust: have example above, the shortage is no ability to performs in all sequences simutaneously

infiles = c(T1_file,T2_file,flair_file)
outfiles = sub(".nii.gz", "_cor.nii.gz", infiles)
pre_group_11301 = preprocess_mri_within(files = infiles,outfiles = outfiles,retimg = TRUE,
                                        correction = "N4",typeofTransform = "Rigid",skull_strip = FALSE)
T1_pre = pre_group_11301$outfiles1
T2_pre = pre_group_11301$outfiles2
flair_pre = pre_group_11301$outfiles3
double_ortho(T1_pre, T2_pre)
double_ortho(T1_pre, flair_pre)
ortho2(T1_pre, T2_pre, col.y = alpha(hotmetal(), 0.25))
ortho2(T1_pre, flair_pre, col.y = alpha(hotmetal(), 0.25))

# 4. Registration to the template
# affine
template_JHU_file = './Template/JHU_MNI_SS_T1.nii.gz'
outfile2 = sub(".nii.gz", "_AffinetoJHU.nii.gz", infiles)
T1_AffinetoJHU = ants_regwrite(filename = T1_pre,
                     outfile = outfile2[1],
                     other.files = list(T2_pre,flair_pre),
                     other.outfiles = outfile2[2:3],
                     template.file = template_JHU_file,
                     typeofTransform = "Affine",
                     verbose = FALSE)

# non-linear (using SyN)
outfile3 = sub(".nii.gz", "_SyNtoJHU.nii.gz", infiles)
T1_SyNtoJHU = ants_regwrite(filename = T1_AffinetoJHU,
                               outfile = outfile3[1],
                               other.files = outfile2[2:3],
                               other.outfiles = outfile3[2:3],
                               template.file = template_JHU_file,
                               typeofTransform = "SyN",
                               verbose = FALSE)
# --------END--------#

#-----------------------------
# Eamples of Registration with ROI
# Note: the method of ROI registration is the same with Co-registration

# --------E.G.--------#
# 1. Prepare the data
mridir=file.path('BRAINIX', "NIfTI")
T1_ROI_file=file.path(mridir, "T1.nii.gz")
T1_ROI=readNIfTI(T1_ROI_file,reorient=FALSE)
flair_ROI_file=file.path(mridir, "FLAIR.nii.gz")
flair_ROI=readNIfTI(flair_ROI_file,reorient = FALSE)
ROI_file=file.path(mridir, "ROI.nii.gz")
ROI=readNIfTI(ROI_file,reorient = FALSE)

orthographic(T1_ROI)
orthographic(flair_ROI)
ortho2(flair_ROI,ROI, xyz=c(200,155,12),col.y=alpha("red",0.2))

# 2. Bias field correction
infiles_ROI = c(T1_ROI_file,flair_ROI_file,ROI_file)
outfiles_ROI = sub(".nii.gz", "_cor.nii.gz", infiles_ROI[1:2])
T1_ROI_cor = bias_correct(T1_ROI, outfile = outfiles_ROI[1],correction = "N4",retimg=TRUE)
flair_ROI_cor = bias_correct(flair_ROI, outfile = outfiles_ROI[2],correction = "N4",retimg=TRUE)

# 3. Co-registration
outfiles2_ROI = sub(".nii.gz", "_RigidtoT1.nii.gz", infiles_ROI)
flair_ROI_RigidtoT1 = ants_regwrite(filename = flair_ROI_cor,
                                    template.file = T1_ROI_cor,
                                    outfile = outfiles2_ROI[2],
                                    typeofTransform = "Rigid",
                                    other.files = ROI_file,
                                    other.outfiles = outfiles2_ROI[3],
                                    verbose = FALSE)
ROI_RigidtoT1 = readNIfTI(outfiles2_ROI[3], reorient = FALSE)
double_ortho(T1_ROI_cor,flair_ROI_RigidtoT1)
ortho2(T1_ROI_cor,ROI_RigidtoT1,col.y=alpha("red",0.2))
# --------END--------#
