//==================Introduction==================
//We are looking at two types of macrophages: 
//1.	Originated from MDP monocytes (dyed green). Notice, the lung structure is also green (autofluorescence)
//2.	Originated from GMP monocytes (dyed red) but also expressing the green gene. Notice, non-macrophage-cells that were also originated from GMP monocytes are dyed red (and do not express the green gene)
//Neurons are expressing TUB3 (blue). Notice, the lung structure is also blue (autofluorescence)
//We want to analyze the co-localization of the two macrophage types to the neurons; Comparing them to one another and to the co-localization of the non-macrophage-cells to the neurons (regarded as control).

//==================Analysis pipeline==================
//==========Identify the neurons==========
//1. Clean background
//1.1 As both the Blue channel (neurons) and the Green channel (macrophages originated from MDP monocytes) show lung autofluorescence, we use the green channel to clean the Blue channel by subtracting it (actually twice):
//			Blue_ autofluorescence = Blue – 2*Green
//1.2 The remaining background is reduced using background substruction.
//2. Tubeness: a filter that enhance the signal that supports a tube like structure. The sigma parameter is correlated to the minimal tube radius – the higher it is, the thicker tubes will be enhanced (uses 2.0 as default)
//The above steps are done on the Z-stack
//3. Max Intensity of the resulting stack
//4. Ilastik model on the max intensity image. Notice, different models should be trained and used for different Tubeness’ sigma.
//5. Remove small neuron segments
//==========Identify the macrophages originated from MDP monocytes (Green Channel)==========
//1. Max intensity of the Green channel
//2. Cellpose with cyto2 out-of-the-box model and cell-size=10;
//==========Identify cells originated from GMP monocytes (Green Channel)==========
//Notice the analysis identifies any cell originated from GMP monocytes and not just macrophages. The decision whether such a cell is a macrophage or not is something the user will be able to determine in the next stage (using an excel spreadsheet). 
//The steps to identify these cells are:
//1. Max intensity of the Green channel
//2. Cellpose with cyto2 out-of-the-box model and cell-size=15;
//==========Distance between cells and neurons==========
//1. Create a distance map of the neurons identified by the Ilastik model
//2. Measure the mean/min distance of each cell to the closest neuron

//==================Output==================
//1. CSV file with information for each identified CELL with the following information
//1.1 CELL Type (red/green)
//1.2 CELL mean distance to closest neuron (microns)
//1.3 CELL min distance to closest neuron (microns)
//1.4 CELL area
//1.5 CELL Mean Intensity
//1.6 CELL Mean Intensity of other type (green/red)
//1.7 CELL Level of overlap with other type: 
//Given that a CELL of OTHER TYPE, that overlaps the CELL, exists, then the level of overlap is given by:
//(([CELL area]∩[CELL of OTHER TYPE  area]))/Min([CELL area]  ,[CELL of OTHER TYPE area]) 
//1.8 Mean distance to edge (microns)
//1.9 Min distance to edge (microns)
//2.The resulting max intensity of the red/green/blue channels
//3 rois of:
//3.1 Red/green cells
//3.2 Identified neurons

//----Macro parameters-----------
var pMacroName = "neurons and macrophags co-localization";
var pMacroVersion = "1.0.0";

#@ File(label="Image",value="", persist=true, description="Image to process") iImageFile
#@ File(label="Output directory",value="", persist=true, style="directory") iOutputDir
//@ Boolean(label="Stop run before tubness",value=false, persist=true, description="Check this field to determine tubeness value") iStopRunBeforeTubeness
#@ Boolean(label="Stop run before Ilastik",value=false, persist=true, description="Check this field to generate images for ilastik training") iStopRunBeforeIlastik
#@ File (label="Neurons Ilastik model path",value="A:/ehuds/Projects/Ayala/MyProject.ilp", persist=true, description="Ilastik model path") iIlastikModelPath
#@ Boolean(label="Ilastik, use previous run",value=true, persist=true, description="for quicker runs, use previous Ilastik results, if exists") iUseIlastikPrevRun
//@ String(label="Tubness sigma",value="2.0", persist=true, description="The higher this value is, the thicker tubes identified") iTubenesSigma
#@ Integer(label="Neuron min area (micron)",value="100", persist=true, description="smaller neuron fragments are removed") iMinNeuronArea
#@ Integer(label="MDP macrophages size",value="10", persist=true, description="For Cellpose segmentation") iMDP
#@ Boolean(label="MDP Cellpose, use previous run",value=true, persist=true, description="for quicker runs, use previous Ilastik results, if exists") iUseMDPCellposePrevRun
#@ String(label="MDP min. mean intensity",value=0, persist=true) iMDPMinMeanIntensity
#@ String(label="MDP min. area (micron)",value=0, persist=true) iMDPMinArea
#@ String(label="MDP max. area (micron)",value=1000, persist=true) iMDPMaxArea
#@ Integer(label="GMP cell size",value="20", persist=true, description="For Cellpose segmentation") iGMP
#@ Boolean(label="GMP Cellpose, use previous run",value=true, persist=true, description="for quicker runs, use previous Ilastik results, if exists") iUseGMPCellposePrevRun
#@ String(label="GMP min. mean intensity",value=0, persist=true) iGMPMinMeanIntensity
#@ String(label="GMP min. area (micron)",value=0, persist=true) iGMPMinArea
#@ String(label="GMP max. area (micron)",value=1000, persist=true) iGMPMaxArea
//@ Integer(label="Backgroun substraction window size",value="300", persist=true, description="Size of sliding window used in background substraction") iBGSlidingWindowSize
#@ File(label="Ilastik, executable",value="C:\\Program Files\\ilastik-1.3.3post3\\ilastik.exe", persist=true, description="Ilastik executable") iIlastikExe
#@ File(label="Cellpose, Enviorenment",value="D:\\Users\\ehuds\\Anaconda3\\envs\\Cellpose", style="directory", persist=true, description="Cellpose env.") iCellposeEnv

//----- global variables-----------
var gImageId = "uninitialized";
var gBlueStackImageId = "uninitialized";
var gGreenStackImageId = "uninitialized";
var gMaxBlueImageId = "uninitialized";
var gMaxRedImageId = "uninitialized";
var gMaxGreenImageId = "uninitialized";
var gDitanceMapImageId = "uninitialized";

var gNeuronsFileName = "neurons";

var gIlastikSegmentationExtention = "_Segmentations Stage 2.h5"; // "_Segmentations.h5"
var gSaveRunDir = "SaveRun"
var	gCompositeTable = "FijiOutput.csv";

//-----debug variables--------
var gDebugFlag = false;
var gBatchModeFlag = false;

Initialization();
if(!checkInput()){
	print("Macro failed");
}
else{
	Process_file();
	print("Macro ended successfully");
}
waitForUser("=================== Done ! ===================");
CleanUp(true);

function Process_file(){
	Identify_neurons();
	//if(iStopRunBeforeTubeness){
	//	waitForUser("Stopping run  before tubness. No other images are generated");
	//	return;
	//}
	if(iStopRunBeforeIlastik){
		waitForUser("Stopping run  before Ilastik. No other images are generated");
		return;
	}
	Save_file_and_roi(gMaxBlueImageId, gNeuronsFileName);
	gDitanceMapImageId = GenerateDistanceMap();
	roi_MDP_path = Identify_macrophages(gMaxGreenImageId, iMDP, iUseMDPCellposePrevRun,"MDP", gMaxRedImageId, "GMP");
	roi_GMP_path = Identify_macrophages(gMaxRedImageId, iGMP, iUseGMPCellposePrevRun,"GMP", gMaxGreenImageId, "MDP");
	Calc_macrophag_measurments(gMaxGreenImageId,"MDP", gMaxRedImageId, "GMP");
	Calc_macrophag_measurments(gMaxRedImageId,"GMP", gMaxGreenImageId, "MDP");

	Calc_macrophag_overlap(gMaxGreenImageId,roi_MDP_path, gMaxRedImageId, roi_GMP_path);
	Table.save(iOutputDir+"/GMP.csv","GMP");
	Table.save(iOutputDir+"/MDP.csv","MDP");
}
function Calc_macrophag_overlap(MDP_image_id, roi_MDP_path, GMP_image_id, roi_GMP_path){
	roiManager("reset");
	roiManager("open", roi_GMP_path);
	nGMP = roiManager("count");
	roiManager("open", roi_MDP_path);
	nMDP = 	roiManager("count") - nGMP;
	
	for (i=0;i<nGMP;i++){
  		for (j=0;j<nMDP;j++){
		    roiManager("select",newArray(i,j+nGMP));
		    roiManager("AND");
		    if (selectionType>-1) {
		      getStatistics(co_area, mean);
		      roiManager("select",i);
		      getStatistics(gmp_area, mean);      
		      roiManager("select",j+nGMP);
		      getStatistics(mdp_area, mean);
		      overlap = co_area/minOf(gmp_area, mdp_area);
		      Table.set("Overlap",i,overlap,"GMP");
		      Table.set("Overlap",j,overlap,"MDP");
		    }
  		}
	}
}
function Identify_macrophages(imageId, cellposeCellDiameter, iUseCellposePrevRun,macrophageType, otherImageId, otherType){
	labelImage = RunCellposeModel(imageId, cellposeCellDiameter, iUseCellposePrevRun,macrophageType);
	roiManager("reset");
	Table.create(macrophageType);
	run("Label image to ROIs");
	Filter_rois(imageId, macrophageType);
	//store output
	path_to_roi_file = Save_file_and_roi(imageId, macrophageType);
	//calc macrophag measurments
	
	return path_to_roi_file;
}

function Calc_macrophag_measurments(imageId ,table, otherImageId, otherType){
	
	//using macrophag image set the area, intensity and distance to edge
	close("Results");
	selectImage(imageId);
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit,pixelWidth, pixelHeight);

	roiManager("deselect");
	roiManager("measure");
	n = roiManager("count");
	for(i=0;i<n;i++){
		roiManager("select", i);
		label = Roi.getName();
		Table.set("Label",i,label,table);
		
		//getStatistics(s_area, s_mean);
		area = Table.get("Area",i,"Results");
		Table.set("Cell Area",i,area,table);
		
		mean_intensity = Table.get("Mean",i,"Results");
		Table.set(table + " Mean intensity",i,mean_intensity,table);
		
		//if(s_area != area || s_mean != mean_intensity){
		//	waitForUser("s_area ,area , s_mean , mean_intensity; " + s_area + ", " + area + ", " + s_mean + ", " + mean_intensity);
		//}
		Set_edge_measurments(i,width,height,pixelWidth, pixelHeight,table);
	}
	//using other macrophag image set the other intensity 
	close("Results");
	selectImage(otherImageId);
	roiManager("deselect");
	roiManager("measure");
	n = roiManager("count");
	for(i=0;i<n;i++){
		roiManager("select", i);
//		getStatistics(s_area, s_mean);
		mean_intensity = Table.get("Mean",i,"Results");
		Table.set(otherType + " Mean intensity within cell",i,mean_intensity,table);
	}
	//using distance image to get min and mean distance from neurons 
	selectImage(gDitanceMapImageId);
	close("Results");
	roiManager("deselect");
	roiManager("measure");
	n = roiManager("count");
	for(i=0;i<n;i++){
		roiManager("select", i);
//		getStatistics(s_area, s_mean, s_min, s_max);
		mean_distance = Table.get("Mean",i,"Results");
		min_distance = Table.get("Min",i,"Results");
		Table.set("Mean distance to neurons",i,mean_distance,table);
		Table.set("Min distance no neurons",i,min_distance,table);
	}	
}
function Set_edge_measurments(roiIndex,width,height,pixelWidth, pixelHeight, table){
	roiManager("select", roiIndex);
	Roi.getContainedPoints(xpoints, ypoints);
	min = maxOf(width,height);
	mean = 0;
	for(i = 0;i<xpoints.length;i++){
		x = minOf(xpoints[i], width-xpoints[i]) * pixelWidth;
		y = minOf(ypoints[i], height-ypoints[i]) * pixelHeight;
		min = minOf(min,minOf(x, y));
		mean = (mean*i + minOf(x, y))/(i+1);
	}
	Table.set("Min distance to edge", roiIndex, min, table);
	Table.set("Mean distance to edge", roiIndex, mean, table);
}
function Filter_rois(imageId, macrophageType){
	if(macrophageType == "GMP"){
		min_mean_intensity = iGMPMinMeanIntensity; min_area = iGMPMinArea; max_area = iGMPMaxArea;
	}
	else{
		min_mean_intensity = iMDPMinMeanIntensity; min_area = iMDPMinArea; max_area = iMDPMaxArea;		
	}
	n = roiManager("count");
	for(i=n-1;i>=0;i--){
		roiManager("select", i);
		getStatistics(area, mean);
		//area = Table.get("Area",i,"Results");
		//mean_intensity = Table.get("Mean",i,"Results");
		if(area > max_area || area < min_area || mean < min_mean_intensity){
			roiManager("delete");
		}
	}
}


function RunCellposeModel(imageId, cellposeCellDiameter, iUseCellposePrevRun, macrophageType)
{
	setBatchMode(false);
	selectImage(imageId);
	title = getTitle();
	found = false;
	CellposOutFilePath = iOutputDir+"/"+gSaveRunDir;
	File.makeDirectory(CellposOutFilePath);
	CellposOutFilePath += "/"+macrophageType+".tif";
	if (iUseCellposePrevRun)
	{
		if (File.exists(CellposOutFilePath))
		{
			print("Reading existing Cellpose model output ...");
			open(CellposOutFilePath);					
			found = true;
		}
	}
	if (!found){
		cellposeProbThreshold = 0.0; cellposeFlowThreshold=0.4;
		print("Progress Report: cellpose started. That might take a few minutes");	
		cellposeParms = "diameter="+cellposeCellDiameter
			+" cellproba_threshold="+cellposeProbThreshold
			+" flow_threshold="+cellposeFlowThreshold
			+" anisotropy=1.0 diam_threshold=12.0"
//			+" model_path="+File.getDirectory(cellposeModel)
			+" model=cyto2"
			+" nuclei_channel=0 cyto_channel=1 dimensionmode=2D stitch_threshold=-1.0 omni=false cluster=false additional_flags=";
//waitForUser("cellposeParms: "+cellposeParms);
		run("Cellpose Advanced", cellposeParms);

		//waitForUser("title:"+title);
		saveAs("Tiff", CellposOutFilePath);
		print("Progress Report: "+macrophageType+ " segmentation ended.");	
	}	
	labelImageId = getImageID();
	setBatchMode(gBatchModeFlag);
	rename(macrophageType + " label image");
	return labelImageId;
}

function Save_file_and_roi(imageId, fileName){
	selectImage(imageId);
	saveAs("Tiff", iOutputDir + fileName+".tif");	roiManager("deselect");
	path_to_roi = iOutputDir + fileName+"_roiSet.zip";
	roiManager("save", path_to_roi);
	return path_to_roi;
}

function GenerateDistanceMap(){
	selectImage(gMaxBlueImageId);
	roiManager("deselect");
	roiManager("combine");
	roiManager("Combine");
	roiManager("Deselect");
	roiManager("Delete");
	roiManager("Add");
	roiManager("select", 0);
	run("Create Mask");
	run("Distance Transform 3D");
	close("Mask");
	return getImageID();
}

function Identify_neurons(){
	clean_blue_stack_image_id = Clean_background();
	//Save_pre_tube_image(clean_blue_stack_image_id);
	//if(iStopRunBeforeTubeness){
	//	return;
	//}
	//tubed_blue_stack_image_id = Run_tubeness(clean_blue_stack_image_id);
	gMaxBlueImageId = Run_max_intensity(clean_blue_stack_image_id);
	rename(gNeuronsFileName);
	if(iStopRunBeforeIlastik){
		saveAs("Tiff", iOutputDir + gNeuronsFileName + ".tif");
		return;
	}

	model_image_id = Run_Ilastik_model(gMaxBlueImageId);
	selectImage(model_image_id);
	setThreshold(2, 255);
	run("Analyze Particles...", "size="+iMinNeuronArea+"-Infinity display summarize add composite"); 
	//Remove_small_neuron_fregments();
}
function Save_pre_tube_image(imagId){
	preTubeImageId = Run_max_intensity(imagId);
	saveAs("Tiff", iOutputDir + "Pre tube neurons image.tif");
	close();
}
function Run_Ilastik_model(imageId)
{
	setBatchMode(false);
	selectImage(imageId);
	title = getTitle();
	found = false;
	IlastikSegmentationOutFile = title+gIlastikSegmentationExtention;
	IlastikOutFilePath = iOutputDir+"/"+gSaveRunDir+"/";
	File.makeDirectory(IlastikOutFilePath);
	if (iUseIlastikPrevRun)
	{
		if (File.exists(IlastikOutFilePath+IlastikSegmentationOutFile))
		{
			print("Reading existing Ilastik AutoContext output ...");
			//run("Import HDF5", "select=[A:\yairbe\Ilastic Training\Cre off HD R.h5] datasetname=/data axisorder=tzyxc");
			//run("Import HDF5", "select=["+resFolderSub+IlastikSegmentationOutFile+"] datasetname=/exported_data axisorder=yxc");
			run("Import HDF5", "select=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] datasetname=/data axisorder=tzyxc");

			//rename("Segmentation");
			rename(IlastikSegmentationOutFile);
						
			found = true;
		}
	}
	if (!found)
	{
		print("Progress Report: Ilastik pixel classifier started. That might take a few minutes");	
		//run("Run Autocontext Prediction", "projectfilename=[A:\\yairbe\\Ilastic Training\\CreOFF-Axon-Classifier_v133post3.ilp] 
		//    inputimage=[A:\\yairbe\\Ilastic Training\\Cre off HD R.h5\\data] autocontextpredictiontype=Segmentation");
		run("Run Pixel Classification Prediction", "projectfilename=["+iIlastikModelPath+"] inputimage=["+title+"] pixelclassificationtype=Segmentation");
		//rename("Segmentation");
		rename(IlastikSegmentationOutFile);

		// save Ilastik Output File
		selectWindow(IlastikSegmentationOutFile);
		print("Saving Ilastik autocontext classifier output...");
		//run("Export HDF5", "select=["+resFolder+IlastikProbOutFile1+"] exportpath=["+resFolder+IlastikProbOutFile1+"] datasetname=data compressionlevel=0 input=["+IlastikProbOutFile1+"]");	
		run("Export HDF5", "select=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] exportpath=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] datasetname=data compressionlevel=0 input=["+IlastikSegmentationOutFile+"]");	
		print("Progress Report: Ilastik ended.");	
	}	
	rename(IlastikSegmentationOutFile);
	//setVoxelSize(width, height, depth, unit); multiplying area size instead
	setBatchMode(gBatchModeFlag);
	return getImageID();
}

function Run_max_intensity(stack_image_id){
	selectImage(stack_image_id);
	run("Z Project...", "projection=[Max Intensity]");
	return getImageID();
}
function Run_tubeness(stack_image_id){
	selectImage(stack_image_id);
	run("Tubeness", "sigma="+iTubenesSigma+"2 use");
	return getImageID();
}
function Clean_background(){
	//substract green channel from blue to remove autofloresence (twice);
	selectImage(gBlueStackImageId);
	blue_title = getTitle();
	selectImage(gGreenStackImageId);
	green_title = getTitle();
	imageCalculator("Subtract create stack", blue_title,green_title);
	mid_result_title = getTitle();
	imageCalculator("Subtract create stack", mid_result_title,green_title);
	//Run_background_substruction();
	return getImageID();
}

//1.1 As both the Blue channel (neurons) and the Green channel (macrophages originated from MDP monocytes) show lung autofluorescence, we use the green channel to clean the Blue channel by subtracting it (actually twice):
//			Blue_ autofluorescence = Blue – 2*Green
//1.2 The remaining background is reduced using background substruction.
//2. Tubeness: a filter that enhance the signal that supports a tube like structure. The sigma parameter is correlated to the minimal tube radius – the higher it is, the thicker tubes will be enhanced (uses 2.0 as default)
//The above steps are done on the Z-stack
//3. Max Intensity of the resulting stack
//4. Ilastik model on the max intensity image. Notice, different models should be trained and used for different Tubeness’ sigma.
//5. Remove small neuron segments


	//roiManager("select", 48);
	//run("Create Mask");
	//run("Distance Transform 3D");
	//close("Mask");
//}

function checkInput()
{
	run("Bio-Formats Importer", "open=["+iImageFile+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	getDimensions (ImageWidth, ImageHeight, ImageChannels, ImageSlices, ImageFrames);
	
	if(ImageChannels != 4)
	{
		print("Fatal error: input file must include 4 channels: Dapi, MDP - Green, GMP - Red and Neurons - Blue");
		return false;
	}
	getPixelSize(unit,pixelWidth, pixelHeight);
	if(!matches(unit, "microns") && !matches(unit, "um"))
	{
		print("Fatal error. File " + gFileNameNoExt + " units are "+ unit+ " and not microns");
		return false;
	}
	File.makeDirectory(iOutputDir);
	gFileNameNoExt = File.getNameWithoutExtension(iImageFile);
	iOutputDir += "/"+gFileNameNoExt+"/";
	File.makeDirectory(iOutputDir);
	
	gImageId = getImageID();
	run("Duplicate...", "duplicate channels=4");
	gBlueStackImageId = getImageID();
	selectImage(gImageId);
	run("Duplicate...", "duplicate channels=3");
	run("Z Project...", "projection=[Max Intensity]");
	gMaxRedImageId = getImageID();
	selectImage(gImageId);
	run("Duplicate...", "duplicate channels=2");
	gGreenStackImageId = getImageID();
	run("Z Project...", "projection=[Max Intensity]");
	gMaxGreenImageId = getImageID();
	
	SaveParms(iOutputDir);
	return true;
}

function Initialization()
{
	run("Configure ilastik executable location", "executablefile=["+iIlastikExe+"] numthreads=-1 maxrammb=150000");
	run("Cellpose setup...", "cellposeenvdirectory="+iCellposeEnv+" envtype=conda usegpu=true usemxnet=false usefastmode=false useresample=false version=2.0");		
	
	setBatchMode(false);
	close("*");
	close("\\Others");
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area mean min redirect=None decimal=3");	
	roiManager("Reset");

	CloseTable("Results");
	Table.create(gCompositeTable);

	run("Collect Garbage");

	if (gBatchModeFlag)
	{
		print("Working in Batch Mode, processing without opening images");
		setBatchMode(gBatchModeFlag);
	}	
}
function CleanUp(finalCleanUp)
{
	run("Collect Garbage");
	if (finalCleanUp) 
	{
		setBatchMode(false);
	}
}

function SaveParms(resFolder)
{
	//waitForUser("macro"+File.getNameWithoutExtension(getInfo("macro.filepath")));
	// print parameters to Prm file for documentation
	PrmFile = iOutputDir + "/" +pMacroName+"_Parameters.txt";
	File.saveString("macroVersion="+pMacroVersion, PrmFile);
	File.append("", PrmFile); 
	
	File.append("RunTime="+getTimeString(), PrmFile);
	
	// save user input

}

function getTimeString()
{
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+", Time: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
	return TimeString;
}

function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}