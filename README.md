# Neurons-Macrophags-colcalization-in-lung
Calculate the distance between neurons and different macrophage cells in the lung
## Overview
Given a Z-stack image of the lung with at least three channels: Neuorns (blue), GMP (red) and DMP (green), we do the following:
1. Use Ilastik to identify the neurons
2. Use Cellpose to identify cells macrophags in the red and green channels
3. Use Fiji to calculate the distance between the neurons and the macrophags/cells

The Fiji macro orchestrating all these steps is available at the [Fiji folder](../../tree/main/Fiji).

## Ilastik modelling
To prepare the images used for training the Ilastik model we first "cleaned" the blue channel image: As both the Blue channel (neurons) and the Green channel (macrophages originated from DMP monocytes) show lung autofluorescence, we usde the green channel to clean the Blue channel by subtracting it twice:
<center>Blue_ autofluorescence = Blue – 2*Green</center>

We trained an auto-context Ilastik model to identify fibrillated structures in an image. To optimize the identification, three independent models were developed for each type of fibrillated structure: for bundles inside and outside a gland, and for the fibers at the nano-fibrlis stage. For each model the training used at least 3 representative images (available in the Ilastik folder).

The Ilastik version used to train and run the models is 1.3.3post3
