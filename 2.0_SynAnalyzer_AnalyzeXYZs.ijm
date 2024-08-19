/*
 * 2.0_SynAnalyzer_AnalyzeXYZs.ijm
 * Created by JFranco | 16 AUG 2024
 * Last update: 16 JUL 2024
 * https://github.com/engineeringjoy/SynAnalyzer
 * 
 * This is the second module in the SynAnalyzer image analyze pipeline. The macro analyzes XYZ coordinates
 * associated with an image file and walks the user through the various steps in the analysis process. 
 * The main output of the macro is a synapse thumbnail array that was inspired by the publication by 
 * Liberman, Wang, and Liberman 2011 (DOI:10.1523/JNEUROSCI.3389-10.2011). 
 * 
 * Requirements:
 * - Original XYZ coordinate files were converted into the required format. 
 * 	 - For use in the Goodrich Lab, these XYZ files are output by Imaris and converted using the
 * 	   1.0_SynAnalyzer_ConvertImarisStatsFile Python notebook
 * - Raw image files are saved in a dedicated subfolder that is in a shared directory with the 
 *   converted XYZ files
 *   
 * Inputs: 
 * - CSV files with XYZ coordinates
 * 
 * Outputs:
 * - Batch Master csv file that has all analysis information for every image
 * - Csv file for every image that has all analysis information for every XYZ
 * - Thumbnails for synapses and terminals
 * - Thumbnail arrays for synapses and terminals
 * - Pillar-Modiolar map 
 */
 
/* 
************************** 2.0_SynAnalyzer_AnalyzeXYZs.ijm ******************************
* **************************  		MAIN MACRO 		************************** 
*/
// *** USER PRESETS ***
// Default batch path
defBP = "/Users/joyfranco/Partners HealthCare Dropbox/Joy Franco/JF_Shared/Data/WSS/BatchAnalysis/SynAnalysis_TestBatch/";
// Subdirectory folder names 
sdXYZs = "XYZCSVs/";
sdMD = "Metadata/";
sdRI = "RawImages/";
sdTIF = "SAR.AdjTifs/";
sdAna = "SAR.Analysis/";
sdSI = "SAR.SummaryImages/";
sdSA = "SAR.SynArrays/";
sdPM = "SAR.PillarModiolarMaps/";
sdAM = "SAR.AnnotatedMPIs/";
sdPA = "SAR.POIAnnotations/";            
sdRM = "SAR.MPIs/";
sdTN = "SAR.Thumbnails/";
// Batch Master file name
fBM = "SynAnalyzerBatchMaster.csv";
// Thumbnail bounding box dimesions in um
tnW = 2;
tnH = 2;
tnZ = 1.5;
vxW = 0.0495;
vxD = 0.31;
// Annotated Image Size - Currently based on the output width of the SynArray
annImW = 1650;
// Rolling ball radius for background subtraction (in pixels)
rbRadius = 50;
// Image file type
imFType = ".czi";
// Image analysis info - Columns for Batch Master
bmCols = newArray("ImageName","ImInitialized?", "Analyzed?", "PreSynAnaComplete?","PostSynAnaComplete?",
				  "PreSynTermAnaComplete?","PostSynTermAnaComplete?", "PreSynPMAnaComplete?","PostSynPMAnaComplete?",
				  "AvailXYZData", "ZStart", "ZEnd", "Voxel Width (um)", "Voxel Depth (um)", 
				  "Synaptic Marker Channels", "Terminal Marker Channels", "Pillar-Modiolar Marker Channels",
				  "PreSynXYZ", "PostSynXYZ", "PreSyn_nSynapses", "PostSyn_nSynapses", 
				  "PreSyn_nDoublets", "PostSyn_nDoublets",  "PreSyn_nOrphans", "PostSyn_nOrphans",
				  "PreSyn_nGarbage",  "PostSyn_nGarbage",  "PreSyn_nUnclear", "PostSyn_nUnclear",  
				  "PreSyn_nWMarker",  "PostSyn_nWMarker", 
				  "PreSyn_nPillar", "PreSyn_nModiolar", "PostSyn_nPillar", "PostSyn_nModiolar");
cols = lengthOf(bmCols);
// Default channel arrays for analysis
defSynCh="[1,4]";
defTerCh="[2,4]";
// Default LUT assignments for thumbnails: c2 = green, c5 = cyan, c6 = magenta, c7 = yellow
defSynLUT = newArray("c2","c6");
defTerLUT = newArray("c5","c6");
// Default extensions to add to thumbnails when saving
defTNExt = newArray("C1", "C2", "Comp");
tnExtCount = lengthOf(defTNExt);
// Default LUT to assign to summed intensity thumbnails
defSynColors = newArray("Green", "Magenta");
defTerColors = newArray("Cyan", "Magenta");

// *** HOUSEKEEPING ***
run("Close All");
run("Labels...", "color=white font=12 show use draw bold");
close("*.csv");

// *** INITIALIZE SYNAPSE ANALYZER ***
// Function will check if this is the first time the analysis has been run and setup
//   the batch folder accordingly
batchpath = initSynAnalyzer();

// *** ITERATE THROUGH ANALYSIS IN BATCH OR SPECIFIC IMAGE MODE ***
// Go until the user says stop
choice = getUserChoice();
while (choice != "EXIT") {
	if (choice == "Batch") {
		// Batch mode iterates through all unalyzed images until the user says to stop
		runAnalysis("Batch", batchpath);
	}else if (choice == "Specific Image") {
		// Specific Image mode allows the user to select a specific image and only analyzes that one.
		runAnalysis("Specific Image", batchpath);
	}
	choice = getUserChoice();
}

// *************************** END MAIN MACRO*************************** 


/* 
**************************       FUNCTIONS       ****************************** 						      
*/

// INITIALIZE SYNANLAYZER FOR THIS BATCH
function initSynAnalyzer() { 
	// *** GET PATH TO BATCH FOLDER ***
	Dialog.create("SynAnalyzer Bootup");
	Dialog.addMessage("This macro will open your z-stack of choice\n"+
	"and create a thumbnail array of regions surrounding specific XYZ coordinates\n"+
	"based on the accompanying .csv file(s).\n"+
	"Please see GitHub Repo for file structure requirements.");
	Dialog.addString("Enter the path to the batch folder:", defBP);
	Dialog.show();
	batchpath = Dialog.getString();
	
	// *** SETUP PATHNAMES FOR SUBDIRECTORIES ***
	dirMD = batchpath+sdMD;
	dirIms = batchpath+sdRI;
	dirTIF = batchpath+sdTIF;
	dirAna = batchpath+sdAna;
	dirSI = batchpath+sdSI;
	dirSA = batchpath+sdSA;
	dirPM = batchpath+sdPM;
	dirAM = batchpath+sdAM;
	dirPA = batchpath+sdPA;            // Point of interest annotations - stores CSV of details for each surface
	dirRM = batchpath+sdRM;
	dirTN = batchpath+sdTN;

	// *** GET LIST OF BATCH IMAGES ***
	fileList = getFileList(dirIms);
	fileCount = lengthOf(fileList);
	
	// *** INITIALIZE BATCH FOLDER IF IT HASN'T BEEN DONE ***
	// *** CREATE SUBFOLDERS IF THEY DO NOT EXIST ***
	if (!File.isDirectory(dirAna)) {
		File.makeDirectory(dirAna);
		File.makeDirectory(dirTIF);
		File.makeDirectory(dirSI);
		File.makeDirectory(dirSA);
		File.makeDirectory(dirPM);
		File.makeDirectory(dirAM);
		File.makeDirectory(dirRM);
		File.makeDirectory(dirTN);
		// *** SETUP BATCH MASTER RESULTS TABLE ***
		Table.create("SynAnalyzerBatchMaster.csv");
		for (i = 0; i < fileCount; i++) {
		    if (endsWith(fileList[i], ".czi")) {
		    	// Iterate through the columns in the preset array and setup table 
		    	for (j = 0; j < cols; j++) {
		    		// First column should be image name
		    		if (j==0){
		    			Table.set(bmCols[j], i, fileList[i]);
		    		}else if (j>0 && j<9){
		    			Table.set(bmCols[j], i, "No");
		    		}else if (j>8){
						Table.set(bmCols[j], i, "TBD");
		    		}
		    	}
			} 
		}
		Table.update;
		Table.save(dirAna+fBM);
	} else { 
		// *** CHECK IF THERE ARE ADDITIONAL IMAGES THAT SHOULD BE ADDED ***
		// Get the list of images currently in the table
		Table.open(dirAna+fBM);
		imList = Table.getColumn("ImageName");
		// Iterate through every file from the list of files in the RawImages directory
		for (i = 0; i < fileCount; i++) {
			// Boolean Value
			bool = "False";
		    if (endsWith(fileList[i], imFType)) { 
		        // Check if the current file in question is in the list of existing images
		        for (j = 0; j < lengthOf(imList); j++) {
					if (fileList[i] == imList[j]) {
						bool = "True";
					}
				}
				// If file has not been registered, add it to Batch Master
				if (bool == "False") {
					row = Table.size;
					for (j = 0; j < cols; j++) {
			    		if (j==0){
			    			Table.set(bmCols[j], i, fileList[i]);
			    		}else if (j>0 && j<9){
			    			Table.set(bmCols[j], i, "No");
			    		}else if (j>8){
						Table.set(bmCols[j], i, "TBD");
		    			}	
			    	}
				Table.update;
				Table.save(dirAna+fBM);
				}
		    }
		}
	}
	close("*.csv");	
	return batchpath;
}
		
// GET USER CHOICE FOR HOW TO PROCEED -- FX FOR CHOO
function getUserChoice(){
	// *** ASK THE USER WHAT THEY WANT TO DO ***
	choiceArray = newArray("Batch", "Specific Image", "EXIT");
	Dialog.create("SynAnalyzer GetChoice");
	Dialog.addMessage("Choose analysis mode:");
	Dialog.addRadioButtonGroup("Choices",choiceArray, 3, 1, "Batch");
	Dialog.show();
	choice = Dialog.getRadioButton();
	return choice;
}	

// RUN ANALYSIS -- FX FOR STEPPING THROUGH ANALYSIS FUNCTIONS
function runAnalysis(mode, batchpath){
	// 1. Get list of registered images
	Table.open(batchpath+sdAna+fBM);
	imList = Table.getColumn("ImageName"); 
	close("*.csv");
	//  . Get list of files available
	fileList = getFileList(batchpath+sdRI);
	fileCount = lengthOf(fileList);
	// 2. Setup trackers for while loop
	//  . Set batch to "Go" to enter while loop at least once
	batch = "Go";
	//  . Set counter for iterating through all files
	i = 0; 
	// 3. Go through while loop once for specific image mode, until the user says stop for batch mode,
	//    or until all files have been checked for batch mode.
	while (batch != "Exit") {
		// 3.1 Allow user to choose image if specific image mode is running
		if(mode == "Specific Image"){
			Dialog.create("Choose a file to analyze")
			Dialog.addChoice("Available Files", fileList);
			Dialog.show();
			fileName = Dialog.getChoice();
			// Set batch to Stop so that it exists the while-loop after analysis
			batch = "Exit";
		}else if (mode == "Batch"){
			fileName = fileList[i];
		}
		// 3.2 Verify that the image file is available and has been registered
		vfReturn = verifyFile(batchpath, fileName, imList);
		fStatus = vfReturn[0];
		imIndex = vfReturn[1];
		imName = substring(fileName, 0, indexOf(fileName, imFType));
		if(fStatus == "Acceptable"){
			print("File "+imName+" is valid and has been registered. Proceeding with analysis.");
			// 3.2.1. Initialize the image
			initializeIm(batchpath, imName, imIndex);
			// 3.2.2. Generate thumbnails for synaptic markers
			genThumbnails(batchpath, imName, imIndex);
			i++;
		}else if(fStatus == "Unregistered"){
			print("File "+fileName+" is valid type but has not been registered.\n"+
				  "Restart macro to register image with Batch Master.");
		    batch = "Exit";
		}else{
			if(mode=="Batch"){
				print("Skipping "+fileName+". Invalid file type.");
				i++;
			}else{
				print(fStatus);
				batch = "Exit";
			}
		}
		// 3.3 Stop batch mode if all of the images have been iterated through
		if((mode == "Batch") && (i<fileCount)){
			choiceArray = newArray("Go", "Exit");
			Dialog.create("Checkin");
			Dialog.addRadioButtonGroup("Proceed with batch mode?", choiceArray, 2, 1, "Go");
			Dialog.show();
			batch = Dialog.getRadioButton();
		}else if ((mode == "Batch") && (i==fileCount)){
			batch = "Exit";
			print("All available files have been checked for analysis. Exiting batch mode.");
		}
	}
}

// VERIFY FILE -- FX FOR CHECKING THAT FILE CAN BE ANALYZED
function verifyFile(batchpath, fileName, imList){
	// 2. Check that the file type is acceptable
	if (endsWith(fileName, imFType)) { 
		// 2.1 If the file is an acceptable format, proceed with verifying registration
		//  . Iterate through imList and check if file has been registered
		imCount = lengthOf(imList);
		//  . Set default status to unregistered
		fStatus = "Unregistered";
		for (i = 0; i < imCount; i++) {
			// . Check if file matches imagename
			if (fileName == imList[i]) {
				// . Update status for the file
				fStatus = "Acceptable";
				// . Get the index of the image
				imIndex = i;
				// . Set the count to max to exit the for-loop
				i = imCount;
			}
		}
	}else{
		fStatus = "Invalid file type";
		imIndex = imCount+1;
	}
	returnArray = newArray(fStatus, imIndex);
	return returnArray;
}

// INITIALIZE IMAGE -- FX FOR SETTING UP IMAGE FOR ANALYSIS 
function initializeIm(batchpath, imName, imIndex){
	// 2. Check if the image has already been initialized
	Table.open(batchpath+sdAna+fBM);
	imStatus = Table.getString("ImInitialized?", imIndex);
	xyzStatus = Table.getString("AvailXYZData", imIndex);
	close("*.csv");
	// 3. Determine how to proceed if already initialized
	if(imStatus=="Yes"){
		// . Check in with user 
		Dialog.create("Check to proceed");
		Dialog.addString("Image has been initialized. Repeat the process?", "No");
		Dialog.show();
		check = Dialog.getString();
		if (check == "Yes"){
			// Update information about the analysis for this image
			imStatus = "TBD";
			xyzStatus = "TBD";
		}
	}
	// 4. Check for available XYZ datasets
	if(xyzStatus=="TBD"){
		pESxyz = batchpath+"/XYZCSVs/"+imName+".XYZ.PreSyn.csv";
		pTSxyz = batchpath+"/XYZCSVs/"+imName+".XYZ.PostSyn.csv";
		// . Check for pre-synaptic XYZ data
		if (File.exists(pESxyz)) {
			// . Check if it also has postsynaptic XYZ data
			if (File.exists(pTSxyz)) {
				adXYZ ="Both Pre- and Post-";
				xyzFCount = 2;
				xyzFiles = newArray("PreSyn", "PostSyn");
			}else{
				adXYZ ="Only Pre-";
				xyzFCount = 1;
				xyzFiles = newArray("PreSyn");
			}
		}else if(File.exists(pTSxyz)){ 
			adXYZ ="Only Post-";
			xyzFCount = 1;
			xyzFiles = newArray("PostSyn");
		}else{
			adXYZ ="None";
		}
		// . Update information about the analysis for this image
		Table.open(batchpath+sdAna+fBM);
		Table.set("AvailXYZData", imIndex, adXYZ);
		Table.update;
		Table.save(batchpath+sdAna+fBM);
		// 4.1 Initialize image 
		if (adXYZ=="None"){
			// . The Batch Master list needs to be updated. Easiest is to have the user restart. 
			print(imName+" exists but does not have XYZ data associated with the image.");
			imStatus = "Skip";
		}else{
			// . GET INFORMATION ABOUT THE IMAGE & WHAT TO ANALYZE
			// . Open the image and get basic information
			waitForUser("!Wait to click ok! When Bio-Formats opens, ensure that default settings are used,\n"+
						"and that no boxes are checked. Do not split channels and do not autoscale.");
			open(batchpath+sdRI+imName+imFType);
			getVoxelSize(vxW, vxH, vxD, unit);
			Stack.getDimensions(width, height, channels, slices, frames);
			run("Split Channels");
			waitForUser("!WAIT TO CLICK OK! Perform stack-wide background subtraction & brightness contrast adjustments.\n"+
						"The adjustments set here will be used for all subsequent analysis steps.");
			run("Merge Channels...", "c2=C1-"+imName+imFType+" c3=C2-"+imName+imFType+" c5=C3-"+imName+imFType+" c6=C4-"+imName+imFType);
			// . Ask the user for z-slices to include
			Dialog.create("Get Analysis Info");
			Dialog.addMessage("Indicate the slices to include in the analysis region.");
			Dialog.addString("Slice Start","1");
			Dialog.addString("Slice End", slices);
			Dialog.show();
			slStart = Dialog.getString();
			slEnd = Dialog.getString();
			// . Add image information to the table
			Table.set("ZStart", imIndex, slStart);
			Table.set("ZEnd", imIndex, slEnd);
			Table.set("Voxel Width (um)", imIndex, vxW);
			Table.set("Voxel Depth (um)", imIndex, vxD);
			Table.update;
			Table.save(batchpath+sdAna+fBM);
			close("*.csv");
			// 4.2 CREATE A MAXIMUM PROJECTION OF THE IMAGE FOR ANNOTATION
			run("Make Substack...", "slices="+slStart+"-"+slEnd);
			save(batchpath+sdTIF+imName+".UserAdj.tif");
			run("Z Project...", "projection=[Max Intensity]");
			run("Make Composite");
			run("Flatten");
			save(batchpath+sdRM+imName+".MPI.tif");
			close("*");
			// 4.3 VERIFY THAT XYZ DATA MATCHES IMAGE
			writeFile = "Yes";
			for (i = 0; i < lengthOf(xyzFiles); i++) {
				// *** IMPORTANT CHECK: IF SAR.XYZ FILE ALREADY EXISTS
				if(File.exists(batchpath+sdAna+imName+".XYZ."+xyzFiles[i]+".csv")){
					Dialog.create("Check to proceed");
					Dialog.addString("SAR.XYZ for "+xyzFiles[i]+" has already been created.\n"+
									 "Overwrite existing file? (Enter 'Yes' or 'No')", "No");
					Dialog.show();
					writeFile = Dialog.getString();
				}
				if(writeFile=="Yes"){
					// Open the substack MPI -- to be annotated
					open(batchpath+sdRM+imName+".MPI.tif");
					// Load the raw XYZ points
					Table.open(batchpath+sdXYZs+imName+".XYZ."+xyzFiles[i]+".csv");
					// Save a clean version of the XYZ file to add analysis info
					Table.save(batchpath+sdAna+imName+".XYZ."+xyzFiles[i]+".csv");
					// Iterate through the rows of the XYZ table and add points to image
					xyzCount = Table.size;
					Table.sort("ID");
					Table.update;
					for (j = 0; j < xyzCount; j++) {
						id = Table.get("ID", j);
						Table.set("SynapseStatus", j, "TBD");
						Table.set("TerminalMarkerStatus", j, "TBD");
						Table.set("PillarModiolarStatus", j, "TBD");
						xPos = (Table.get("Position X (voxels)", j));
						yPos = (Table.get("Position Y (voxels)", j));
						zPos = (Table.get("Position Z (voxels)", j));
						Table.update;
						// ANNOTATE MAX PROJECTION
						makePoint(xPos, yPos, "small yellow dot add");
						setFont("SansSerif",10, "antiliased");
					    setColor(255, 255, 255);
						drawString(id, xPos, yPos);
					}
					// Save the updated Batch Master
					Table.save(batchpath+sdAna+imName+".XYZ."+xyzFiles[i]+".csv");
					// Save the annotated MPI
					save(batchpath+sdAM+imName+".AnnMPI."+xyzFiles[i]+".png");
					// Rescale the image for visualization and summary image generation
					// . Get the dimensions of the image
					getDimensions(width, height, channels, slices, frames);
					// . Calculate the scaling factor and output dimensions
					scaleF = round(annImW/width);
					outputW = scaleF*width;
					outputH = scaleF*height;
					// .  Scale the annotated image
					run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+" interpolation=Bilinear average create");
					save(batchpath+sdAM+imName+".AnnMPI."+xyzFiles[i]+".png");
					// . Ask the user to verify that the XYZ data matches the image
					choiceArray = newArray("Yes", "No");
					Dialog.create("Checkin");
					Dialog.addRadioButtonGroup("Do these XYZ points match the image?", choiceArray, 2, 1, "Yes");
					Dialog.show();
					match = Dialog.getRadioButton();
					close("*");
					close("*.csv");
				}
			}
		}
	}
	// 5. Update Batch Master to indicate initialization as complete
	Table.open(batchpath+sdAna+fBM);
	Table.set("ImInitialized?", imIndex, "Yes");
	Table.update;
	Table.save(batchpath+sdAna+fBM);
	close("*.csv");
	return;
}

// GEN THUMBNAILS -- FX FOR GENERATING THUMBNAILS 
function genThumbnails(batchpath, imName, imIndex){
	// 1. Check with user to proceed with thumbnail generation
	Dialog.create("Checkin");
	Dialog.addRadioButtonGroup("Proceed with thumbnail generation?", newArray("Yes", "No"), 2, 1, "Yes");
	Dialog.show();
	if(Dialog.getRadioButton()=="Yes"){
		// 1.1 Have the user draw an ROI for the area to work on 
		//  . Open the substack MPI 
		open(batchpath+sdRM+imName+".MPI.tif");
		setTool("rectangle");
		waitForUser("Draw a rectangle around the region to include in thumbnail generation.\n"+
					"Then press [t] to add to the ROI Manager.\n"+
					"Make sure the rectangle is still visible when pressing 'Ok' to proceed.");
		//  . Get the coordinates for the rectangle
		Roi.getCoordinates(xpoints, ypoints);
		bbXZ = xpoints[0];
		bbXO = xpoints[1];
		bbYZ = ypoints[0];
		bbYT = ypoints[2];
		close();
		// 1.2 Get available XYZ data information
		Table.open(batchpath+sdAna+fBM);
		xyzStatus = Table.getString("AvailXYZData", imIndex);
		slStart = Table.get("ZStart", imIndex);
		slEnd = Table.get("ZEnd", imIndex);
		close("*.csv");
		if(xyzStatus == "Both Pre- and Post-"){
			availXYZ = newArray("PreSyn", "PostSyn");
		}else if(xyzStatus == "Only Pre-"){
			availXYZ = newArray("PreSyn");
		}else if(xyzStatus == "Only Post-"){
			availXYZ = newArray("PostSyn");
		}
		xyzFCount = lengthOf(availXYZ);
		// 1.3 Iterate through possibile thumbnail generation steps for synapse thumbnails
		//  . Run through main for-loop once for synapses and once for terminals
		tnSteps = newArray("Synaptic","Terminal");
		tnCount = lengthOf(tnSteps);
		defChs = newArray(defSynCh,defTerCh);
		for (i = 0; i < tnCount; i++) {
			for (j = 0; j < xyzFCount; j++) {
				Dialog.create("Checkin");
				Dialog.addString("Generate "+tnSteps[i]+" thumbnails for "+availXYZ[j]+" XYZs?","Yes");
				Dialog.addMessage("If yes, indicate channels to include for thumbnails:");
				Dialog.addString("Channels to use for synaptic thumbnails:",defChs[i]);
				Dialog.show();
				include = Dialog.getString();
				if (include == "Yes"){
					// 1.3.01 Setup subfolder for storing thumbnails associated with this image/XYZ set
					if (!File.isDirectory(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/")) {
						File.makeDirectory(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/");
					}
					// 1.3.1 Get the information from the dialog box & add to Batch Master
					chStr = Dialog.getString();
					chArr = split(chStr, "'[',',',']',' ',");
					chCount = lengthOf(chArr);
					Table.open(batchpath+sdAna+fBM);
					Table.set(tnSteps[i]+" Marker Channels", imIndex,chStr);
					Table.update;
					Table.save(batchpath+sdAna+fBM);
					close("*.csv");
					// 1.3.2 Open the raw image & get rid of channels that are not synaptic markers
					open(batchpath+sdTIF+imName+".UserAdj.tif");
					rename(imName+imFType);
					Stack.getDimensions(width, height, channels, slices, frames);
					run("Split Channels");
					for (k = 0; k < channels; k++) {
						ch = k+1;
						selectImage("C"+toString(ch)+"-"+imName+imFType);
						keepOpen = "False";
						for (l = 0; l < lengthOf(chArr); l++) {
							if(chArr[l]==ch){
								keepOpen = "True";
							}
						}
						if(keepOpen=="False"){
							close();
						}
					}
					// .  Create a composite image of the channels based on defaults
					compChArr = newArray(chCount+1);
					compChStr = "";
					for (k = 0; k < chCount; k++) {
						compChArr[k] = "C"+chArr[k]+"-"+imName+imFType;
						// . Create string for Merge Channels argument based on Synaptic or Terminal 
						if(i==0){
							compChStr = compChStr+defSynLUT[k]+"="+compChArr[k]+" ";
						}else if(i==1){
							compChStr = compChStr+defTerLUT[k]+"="+compChArr[k]+" ";
						}
						// . When all single channel names have been setup, add final name for comp image
						if(k==(chCount-1)){
							compChArr[k+1]=imName+imFType;
						}
					}
					run("Merge Channels...", compChStr+" create keep ignore");
					rename(imName+imFType);
					// 1.3.3 Generate the thumbnails for each of the available images
					Table.open(batchpath+sdAna+imName+".XYZ."+availXYZ[j]+".csv");
					nXYZs = Table.size;
					for (k = 0; k < tnExtCount; k++) {
						imTempName = compChArr[k];
						fs = defTNExt[k];
						// .  Iterate through the three different images to generate thumbnails from each
						selectImage(imTempName);
						for (l = 0; l < nXYZs; l++) {
							id = Table.get("ID", l);
							xPos = Table.get("Position X (voxels)", l);
							yPos = Table.get("Position Y (voxels)", l);
							slZ = Table.get("Position Z (voxels)", l);
							// . Verify that the XYZ is within the user defined main bounding box
							if ((xPos >= bbXZ) && (xPos <= bbXO)) { 
								if ((yPos >= bbYZ) && (yPos <= bbYT)) {
									if ((slZ >= slStart) && (slZ <= slEnd)){
										// Update information to include the XYZ
										Table.set("XYZinROI?", l, "Yes");
										// Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
										cropX = xPos - ((tnW/vxW)/2);
										cropY = yPos - ((tnH/vxW)/2); 
										Table.set("CropX", l, cropX);
										Table.set("CropY", l, cropY);
										// Calculate and store the start and end slice numbers for the z-stack
										zSt = round(slZ-((tnZ/vxD)/2));
										zEnd = floor(slZ+((tnZ/vxD)/2));
										Table.set("ZStart", l, zSt);
										Table.set("ZEnd", l, zEnd);
										Table.update;
										// Make a max projection for just this XYZ
										selectImage(imTempName);
										// For alternate types of project change to:
										// "Sum Slices",  "Average Intensity", or "Max Intensity"
										run("Z Project...", "start="+toString(zSt)+" stop="+toString(zEnd)+" projection=[Sum Slices]");
										run("Flatten");
										// Crop the region around the XYX
									    makeRectangle(cropX, cropY, (tnW/vxW), (tnH/vxW));
									    run("Crop");
									    run("Subtract Background...", "rolling="+rbRadius);
									    // . Assign LUT if Sum intensity is used--not necessary for max or average
									    if(i==0){
									    	if(k<(tnExtCount-1)){
									    		run("32-bit");
									    		run(defSynColors[k]);
									    	}
									    }else if(i==1){
									    	if(k<(tnExtCount-1)){
									    		run("32-bit");
									    		run(defTerColors[k]);
									    	}
									    }
									    // Add cross hairs for center
										setFont("SansSerif",3, "antiliased");
									    setColor(255, 255, 0);
										drawString(".", ((tnW/vxW)/2), ((tnW/vxW)/2));
									    setFont("SansSerif",8, "antiliased");
									    setColor(255, 255, 255);
										drawString(id, 1, ((tnW/vxW)-1));
										// Save the thumbnail image
										save(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/"+imName+".TN."+id+"."+fs+".png");
										// Close images
										close();
										// For alternate types of project change to:
										// "SUM", "AVG", or "MAX"
										close("SUM_"+imTempName);
									}else{
										// XYZ is not within Z bounds
										Table.set("XYZinROI?", l, "No");
									}
								}else{
									// XYZ is not within Y bounds
									Table.set("XYZinROI?", l, "No");
								}
							}else{
								// XYZ is not within X bounds
								Table.set("XYZinROI?", l, "No");
							}
						}
					
					}
					// . Close unnecessary images
					for (k = 0; k < tnExtCount; k++) {
						close(compChArr[k]);
					}
					// . Save the updated XYZ data
					Table.update;
					Table.save(batchpath+sdAna+imName+".XYZ."+availXYZ[j]+".csv");
					close("*.csv");
					// . Update Batch Master with number of XYZs 
					Table.open(batchpath+sdAna+fBM);
					Table.set(availXYZ[j]+"XYZ", imIndex, nXYZs);
					Table.update;
					Table.save(batchpath+sdAna+fBM);
					close("*.csv");
				}
			}
		}
	}
}