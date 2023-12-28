# Neurons-Macrophags-colcalization-in-lung
Calculate the distance between neurons and different macrophage cells in the lung
## Overview
Given a Z-stack image of the lung with at least three channels: Neuorns (blue), GMP (red) and DMP (green), we do the following:
1. Use Ilastik to identify the neurons
2. Use Cellpose to identify cells macrophags in the red and green channels
3. Use Fiji to calculate the distance between the neurons and the macrophags/cells and the overlap between identified cells in the Green and red channels

The Fiji macro orchestrating all these steps is available at the [Fiji folder](../../tree/main/Fiji).

## Neuron segmentation
To prepare the images used for training the Ilastik model we first "cleaned" the blue channel image: As both the Blue channel (neurons) and the Green channel (macrophages originated from DMP monocytes) show lung autofluorescence, we usde the green channel to clean the Blue channel by subtracting it twice:
<p align="center">
Blue_ autofluorescence = Blue – 2*Green
</p>
We then took the max intensity projection of the manipulated Z-stack and used that to train the Ilastik model (avalable at [Ilastik folder](../../tree/main/Ilastik).

![Neurons](https://github.com/WIS-MICC-CellObservatory/Neurons-Macrophags-colcalization-in-lung/assets/64706090/2f20a55e-e50b-4959-a9a9-a5e466d96f69)

The Ilastik version used to train and run the models is 1.3.3post3
## Cells/Macrophages segmentation
We used out-of-the-box Cellpose’s “cyto2” model to identify cells: We used cell diameter = 20pixels for identifying the GMP originated cells and macrophages, and cell diameter = 10pixels for identifying the MDP macrophages.

![Macrophages](https://github.com/WIS-MICC-CellObservatory/Neurons-Macrophags-colcalization-in-lung/assets/64706090/ba562be6-c9dd-4514-b874-25dfa0aa6ec9)


## Distance analysis
As the Ilastile model also capture small fractions of neurons, before generating Fiji's distance transform, we removed small identified neuron fregments (trying both 100 microns^2 and 200 microns^2). 

![Distance map](https://github.com/WIS-MICC-CellObservatory/Neurons-Macrophags-colcalization-in-lung/assets/64706090/439ee7b8-2b10-4c9a-916e-6b8c3f42b97b)

## GMD MDP overlap 
For each two identified cells of different types (i.e., GMD and DMP) that overlap, the level of overlap is given by:

    ([CELL]∩[CELL of OTHER TYPE] area)/Min([CELL] area ,[CELL of OTHER TYPE] area)


