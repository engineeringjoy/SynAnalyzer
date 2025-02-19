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
defBP = "/Users/joyfranco/Partners HealthCare Dropbox/Joy Franco/JF_Shared/Data/WSS/BatchAnalysis/SynAnalyzer_BclwTGAging/";
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
vxD = 0.34;
zSl = 4;
// Annotated Image Size - Currently based on the output width of the SynArray
annImW = 1650;
scaleF = 0.5;
// Rolling ball radius for background subtraction (in pixels)
rbRadius = 50;
// Image file type
imFType = ".czi";
// Image analysis info - Columns for Batch Master
bmCols = newArray("ImageName","ImInitialized?", "AnalysisStatus", "genThumbnailsStatus", "genArraysStatus",
				  "reviewArraysStatus", "mapPillarModiolarStatus","AvailXYZData", "ZStart", "ZEnd", 
				  "Voxel Width (um)", "Voxel Depth (um)", 
				  "Synaptic Marker Channels", "Terminal Marker Channels", "Pillar-Modiolar Marker Channels",
				  "PreSynXYZ", "PostSynXYZ", "PreSyn_nSynapses", "PostSyn_nSynapses", 
				  "PreSyn_nDoublets", "PostSyn_nDoublets",  "PreSyn_nOrphans", "PostSyn_nOrphans",
				  "PreSyn_nGarbage",  "PostSyn_nGarbage",  "PreSyn_nUnclear", "PostSyn_nUnclear",  
				  "PreSyn_nPMarker",  "PostSyn_nPMarker", "PreSyn_nNMarker", "PostSyn_nNMarker",
				  "PreSyn_uncMarker", "PostSyn_uncMarker",
				  "PreSyn_nPillar", "PreSyn_nModiolar", "PostSyn_nPillar", "PostSyn_nModiolar");
cols = lengthOf(bmCols);
// Default channel arrays for analysis
//    Not sure yet if the order here matters (i.e., if pre syn needs to be listed first but guessing it should match
//     LUT assignement below
// There's a weird issue here where the code saves the adjusted tiff in a channel order that may not match the original one
// . for Bclw Aging the pre and post syn channels end up being 1 & 3
defSynCh="[1,3]";
defTerCh="[2]";
// Default LUT assignments for thumbnails: c2 = green, c5 = cyan, c6 = magenta, c7 = yellow
defSynLUT = newArray("c2","c6");
defTerLUT = newArray("c3");
// LUT to use for max projection -- we keep the LUTs the same for types of markers 
// .   Hair cell => blue => c3; Presyn => green => c2; Postsyn => magenta => c6; Terminal => yellow = c7
// .   Ntng1 CHs: HC => C4; CtBP2 => C3; Homer1 => C1; tdTOM => C2;
defMPILUT = newArray("c7","c2","c3","c6"); // LUT to use for each channel when making the max projection
defMPICH = newArray("C1","C2","C3","C4");  // paired channel name for the LUT above
// Default extensions to add to thumbnails when saving
defTNExt = newArray("C1", "C2", "Comp");
tnExtCount = lengthOf(defTNExt);
// Default LUT to assign to summed intensity thumbnails
defSynColors = newArray("Green", "Magenta");
defTerColors = newArray("Cyan", "Magenta");
// Default channels for pillar-modiolar mapping
defPMCh = "[3,4]";
// Default LUT for pillar-modiolar mapping
defPMLUT = newArray("c2","c3");

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
		    		if(j==0){
		    			Table.set(bmCols[j], i, fileList[i]);
		    		}else if(j==1){
		    			Table.set(bmCols[j], i, "No");
		    		}else{
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
			// 3.2.2. Generate thumbnails 
			genThumbnails(batchpath, imName, imIndex);
			// 3.2.3. Generate arrays
			genArray(batchpath, imName, imIndex);
			// 3.2.4. Walk user through the process of reviewing arrays and assigning synapse/terminal status
			reviewArrays(batchpath, imName, imIndex);
			// 3.2.5. Perform pillar-modiolar mapping
			mapPillarModiolar(batchpath, imName, imIndex);
			// 3.2.6 Ask user about updating status
			Table.open(batchpath+sdAna+fBM);
			imStatus = Table.getString("AnalysisStatus", imIndex);
			Dialog.create("Update Analysis Status?");
			Dialog.addMessage("All available analysis steps have been performed.");
			Dialog.addMessage("To update status, change the text in the box below.");
			Dialog.addString("Analysis Status: ", imStatus);
			Dialog.show();
			newStatus=Dialog.getString();
			Table.set("AnalysisStatus", imIndex, newStatus);
			Table.update;
			Table.save(batchpath+sdAna+fBM);
			close("*.csv");
			// Increase counter to move on to next file in fileList
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
	// 1. Check if the image has already been initialized
	Table.open(batchpath+sdAna+fBM);
	imStatus = Table.getString("ImInitialized?", imIndex);
	xyzStatus = Table.getString("AvailXYZData", imIndex);
	close("*.csv");
	// 2. Determine how to proceed if already initialized
	if(imStatus=="Yes"){
		// . Check in with user 
		Dialog.create("Check to proceed");
		Dialog.addString("Image has been initialized. Repeat the process?", "No");
		Dialog.show();
		check = Dialog.getString();
		if (check == "Yes"){
			// Update information about the analysis for this image
			imStatus = "No";
			xyzStatus = "TBD";
		}
	}

	// 3.0 Check if the image has been initialized
	if(imStatus == "No"){
		// 3. Check for available XYZ datasets
		if(xyzStatus=="TBD"){
			print(xyzStatus);
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
			
			// 3.1 Initialize image 
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
				run("Merge Channels...", defMPILUT[0]+"="+defMPICH[0]+"-"+imName+imFType+
										 " "+defMPILUT[1]+"="+defMPICH[1]+"-"+imName+imFType+
										 " "+defMPILUT[2]+"="+defMPICH[2]+"-"+imName+imFType+
										 " "+defMPILUT[3]+"="+defMPICH[3]+"-"+imName+imFType+" create ignore");
				print(defMPILUT[0]+"="+defMPICH[0]+"-"+imName+imFType+
										 " "+defMPILUT[1]+"="+defMPICH[1]+"-"+imName+imFType+
										 " "+defMPILUT[2]+"="+defMPICH[2]+"-"+imName+imFType+
										 " "+defMPILUT[3]+"="+defMPICH[3]+"-"+imName+imFType);
				// . Ask the user for z-slices to include
				Dialog.create("Get Analysis Info");
				Dialog.addMessage("Indicate the slices to include in the analysis region.");
				Dialog.addString("Slice Start","1");
				Dialog.addString("Slice End", slices);
				Dialog.show();
				slStart = Dialog.getString();
				slEnd = Dialog.getString();
				// . Add image information to the table
				Table.open(batchpath+sdAna+fBM);
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
							Table.set("TerminalStatus", j, "TBD");
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
						//scaleF = round(annImW/width);
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
			// 4. Update Batch Master to indicate initialization as complete
			Table.open(batchpath+sdAna+fBM);
			Table.set("ImInitialized?", imIndex, "Yes");
			Table.set("AvailXYZData", imIndex, adXYZ);
			Table.update;
			Table.save(batchpath+sdAna+fBM);
			close("*.csv");
			}
		}
	}
}

// GEN THUMBNAILS -- FX FOR GENERATING THUMBNAILS 
function genThumbnails(batchpath, imName, imIndex){
	// 1. Get the status for this function
	Table.open(batchpath+sdAna+fBM);
	fxStatusTemp = Table.getString("genThumbnailsStatus", imIndex);
	fxStatArr = split(fxStatusTemp);
	// 2. Check with user to proceed with thumbnail generation
	Dialog.create("Generating Thumbnails");
	Dialog.addMessage("Function status: ");
	for (i = 0; i < lengthOf(fxStatArr); i++) {
		Dialog.addMessage(fxStatArr[i]);
	}
	Dialog.addRadioButtonGroup("Proceed with thumbnail generation?", newArray("Yes", "No"), 2, 1, "Yes");
	Dialog.show();
	if(Dialog.getRadioButton()=="Yes"){
		if(fxStatusTemp=="TBD"){
			fxStatusTemp="Initialized";
		}
		// 2.1 Have the user draw an ROI for the area to work on 
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
		// 2.2 Get available XYZ data information
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
		// 2.3 Iterate through possibile thumbnail generation steps for synapse thumbnails
		//  . Run through main for-loop once for synapses and once for terminals
		tnSteps = newArray("Synaptic","Terminal");
		tnCount = lengthOf(tnSteps);
		defChs = newArray(defSynCh,defTerCh);
		//  . Update fxStatus
		fxStatus = newArray((xyzFCount*tnCount)+1);
		fxStatus[0]=fxStatusTemp; 
		f = 0;
		for (i = 0; i < tnCount; i++) {
			for (j = 0; j < xyzFCount; j++) {
				Dialog.create("Checkin");
				Dialog.addString("Generate "+tnSteps[i]+" thumbnails for "+availXYZ[j]+" XYZs?","Yes");
				Dialog.addMessage("If yes, indicate channels to include for thumbnails:");
				Dialog.addString("Channels to use for synaptic thumbnails:",defChs[i]);
				Dialog.show();
				include = Dialog.getString();
				if (include == "Yes"){
					// 2.3.1 Setup subfolder for storing thumbnails associated with this image/XYZ set
					if (!File.isDirectory(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/")) {
						File.makeDirectory(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/");
					}
					// 2.3.2 Get the information from the dialog box & add to Batch Master
					chStr = Dialog.getString();
					chArr = split(chStr, "'[',',',']',' ',");
					chCount = lengthOf(chArr);
					Table.open(batchpath+sdAna+fBM);
					Table.set(tnSteps[i]+" Marker Channels", imIndex,chStr);
					Table.update;
					Table.save(batchpath+sdAna+fBM);
					close("*.csv");
					// 2.3.3 Open the image & get rid of channels that are not synaptic markers
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
								print(ch);
							}
						}
						if(keepOpen=="False"){
							close();
						}
					}
					// 2.3.4 Create a composite image of the channels based on defaults
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
					// 2.3.5 Generate the thumbnails for each of the available images
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
										Table.set("SynapseStatus", l, "Synapse?");
										Table.set("TerminalStatus", l, "Positive?");
										// Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
										cropX = xPos - ((tnW/vxW)/2);
										cropY = yPos - ((tnH/vxW)/2); 
										Table.set("CropX", l, cropX);
										Table.set("CropY", l, cropY);
										// Calculate and store the start and end slice numbers for the z-stack
										//zSt = round(slZ-((tnZ/vxD)/2));
										//zEnd = floor(slZ+((tnZ/vxD)/2));
										zSt = slZ-zSl;
										zEnd = slZ+zSl;
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
										//Table.set("XYZinROI?", l, "No");
									}
								}else{
									// XYZ is not within Y bounds
									//Table.set("XYZinROI?", l, "No");
								}
							}else{
								// XYZ is not within X bounds
								//Table.set("XYZinROI?", l, "No");
							}
						}
					}
					// 2.3.6 Close unnecessary images
					for (k = 0; k < tnExtCount; k++) {
						close(compChArr[k]);
					}
					// 2.3.7 Save the updated XYZ data
					Table.update;
					Table.save(batchpath+sdAna+imName+".XYZ."+availXYZ[j]+".csv");
					close("*.csv");
					// 2.3.8 Update Batch Master with number of XYZs 
					Table.open(batchpath+sdAna+fBM);
					Table.set(availXYZ[j]+"XYZ", imIndex, nXYZs);
					Table.update;
					Table.save(batchpath+sdAna+fBM);
					close("*.csv");
					// 2.3.9 Update status
					fxStatus[f+1] = "Comp_"+availXYZ[j]+tnSteps[i];
					f++;
				}
			}
		}
		Table.open(batchpath+sdAna+fBM);
		fxStr = String.join(fxStatus);
		Table.set("genThumbnailsStatus",imIndex,fxStr);
		Table.update;
		Table.save(batchpath+sdAna+fBM);
		close("*.csv");
	}
}

// GEN ARRAYS -- FX FOR GENERATING ARRAYS FOR AVAILABLE THUMBNAILS
function genArray(batchpath, imName, imIndex){
	// 1. Get the status for this function
	Table.open(batchpath+sdAna+fBM);
	fxStatusTemp = Table.getString("genArraysStatus", imIndex);
	fxStatArr = split(fxStatusTemp);
	// 2. Check with user to proceed with thumbnail generation
	Dialog.create("Generating Arrays");
	Dialog.addMessage("Function status: ");
	for (i = 0; i < lengthOf(fxStatArr); i++) {
		Dialog.addMessage(fxStatArr[i]);
	}
	Dialog.addRadioButtonGroup("Proceed with array generation?", newArray("Yes", "No"), 2, 1, "Yes");
	Dialog.show();
	proceed = Dialog.getRadioButton();
	if(proceed=="Yes"){
		if(fxStatusTemp=="TBD"){
			fxStatusTemp="Initialized";
		}
		// 1.1 Get available XYZ data information
		Table.open(batchpath+sdAna+fBM);
		xyzStatus = Table.getString("AvailXYZData", imIndex);
		close("*.csv");
		if(xyzStatus == "Both Pre- and Post-"){
			availXYZ = newArray("PreSyn", "PostSyn");
		}else if(xyzStatus == "Only Pre-"){
			availXYZ = newArray("PreSyn");
		}else if(xyzStatus == "Only Post-"){
			availXYZ = newArray("PostSyn");
		}
		xyzFCount = lengthOf(availXYZ);
		// 1.2 Iterate through possibile array generation steps for thumbnails
		tnSteps = newArray("Synaptic","Terminal");
		tnCount = lengthOf(tnSteps);
		//  . Update fxStatus
		fxStatus = newArray((xyzFCount*tnCount)+1);
		fxStatus[0]=fxStatusTemp; 
		f = 0;
		for (i = 0; i < tnCount; i++) {
			for (j = 0; j < xyzFCount; j++) {
				Dialog.create("Checkin");
				Dialog.addString("Generate "+tnSteps[i]+" array for "+availXYZ[j]+" XYZs?","Yes");
				Dialog.show();
				include = Dialog.getString();
				if (include == "Yes"){
					// 1.3.0 Verify that directory with thumbnails is available
					if (File.isDirectory(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/")) {
						// 1.3.1 Generate thumbnail arrays for each "channel"
						for (k = 0; k < tnExtCount; k++) {
							fs = defTNExt[k];
							// 1.3.1.1 Iterate through all of the XYZs and open the appropriate images
							Table.open(batchpath+sdAna+imName+".XYZ."+availXYZ[j]+".csv");
							nXYZs = Table.size;
							for (l = 0; l < nXYZs; l++) {
								inBounds = Table.getString("XYZinROI?", l);
								if (inBounds=="Yes"){
									id = Table.getString("ID", l);
									if(File.exists(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/"+imName+".TN."+id+"."+fs+".png")){
										open(batchpath+sdTN+imName+"."+tnSteps[i]+"."+availXYZ[j]+"/"+imName+".TN."+id+"."+fs+".png");
									}
								}
							}
							// Once all images are open, create the array
							run("Images to Stack", "use");
							Stack.getDimensions(width, height, channels, slices, frames);
							nRows = -floor(-(slices/10));
							run("Make Montage...", "columns=10 rows="+nRows+" scale=2");
							save(batchpath+sdSA+imName+"."+tnSteps[i]+"Array."+availXYZ[j]+"."+fs+".png");
							close("*");
						}
						close("*.csv");
						// 2.3.9 Update status
						fxStatus[f+1] = "Comp_"+availXYZ[j]+tnSteps[i];
						f++;
					}
				}
			}
		}
		Table.open(batchpath+sdAna+fBM);
		fxStr = String.join(fxStatus);
		Table.set("genArraysStatus",imIndex,fxStr);
		Table.update;
		Table.save(batchpath+sdAna+fBM);
		close("*.csv");
	}
}

// REVIEW ARRAYS -- FX FOR REVIEWING ARRAYS AND DENOTING STATUS
function reviewArrays(batchpath, imName, imIndex){
	// 1. Get the status for this function
	Table.open(batchpath+sdAna+fBM);
	fxStatusTemp = Table.getString("reviewArraysStatus", imIndex);
	fxStatArr = split(fxStatusTemp);
	// 2. Check with user to proceed with thumbnail generation
	Dialog.create("Generating Arrays");
	Dialog.addMessage("Function status: ");
	for (i = 0; i < lengthOf(fxStatArr); i++) {
		Dialog.addMessage(fxStatArr[i]);
	}
	Dialog.addRadioButtonGroup("Proceed with array review?", newArray("Yes", "No"), 2, 1, "Yes");
	Dialog.show();
	if(Dialog.getRadioButton()=="Yes"){
		if(fxStatusTemp=="TBD"){
			fxStatusTemp="Initialized";
		}
		// 1.1 Get available XYZ data information
		Table.open(batchpath+sdAna+fBM);
		xyzStatus = Table.getString("AvailXYZData", imIndex);
		print(Table.getString("ImageName", imIndex));
		close("*.csv");
		if(xyzStatus == "Both Pre- and Post-"){
			availXYZ = newArray("PreSyn", "PostSyn");
		}else if(xyzStatus == "Only Pre-"){
			availXYZ = newArray("PreSyn");
		}else if(xyzStatus == "Only Post-"){
			availXYZ = newArray("PostSyn");
		}
		xyzFCount = lengthOf(availXYZ);
		// 1.2 Iterate through possibile thumbnail arrays
		tnSteps = newArray("Synaptic","Terminal");
		tnCount = lengthOf(tnSteps);
		txtArr = newArray("Enter 'Synapse', 'Orphan','Doublet', 'Garbage', or a custom flag as needed.",
						  "Enter 'Positive', 'Negative', or a custom flag as needed.");
		//  . Update fxStatus
		fxStatus = newArray((xyzFCount*tnCount)+1);
		fxStatus[0]=fxStatusTemp; 
		f = 0;
		for (i = 0; i < tnCount; i++) {
			// 1.2.1 Iterate through the possible XYZ data sets
			for (j = 0; j < xyzFCount; j++) {
				fs = defTNExt[0];
				// 1.2.2 Verify that the array file exists
				if(File.exists(batchpath+sdSA+imName+"."+tnSteps[i]+"Array."+availXYZ[j]+"."+fs+".png")){
					Dialog.create("Checkin");
					Dialog.addString("Review "+tnSteps[i]+" array for "+availXYZ[j]+" XYZs?","Yes");
					Dialog.show();
					include = Dialog.getString();
					if (include == "Yes"){
						// 1.2.2.1 Open all versions of the array and create stack for user review
						for (k = 0; k < tnExtCount; k++) {
							open(batchpath+sdSA+imName+"."+tnSteps[i]+"Array."+availXYZ[j]+"."+defTNExt[k]+".png");
						}
						run("Images to Stack", "use");
					// 1.2.3 Have the user open the CSV file and manually update the information for each synapse
					waitForUser("*DO NOT CLICK OK UNTIL ANNOTATION IS COMPLETE*\n"+
								"Open the"+availXYZ[j]+" XYZ csv file for this image and edit the\n"+
								"'"+tnSteps[i]+"Status' column.\n"+txtArr[i]+"\n"+
								"Click ok when all XYZs have been reviewed AND the csv file has been saved\n"+
								"(as a csv) and closed.\n"+
								"Note: typos and/or incorrect lettercase may result in runtime errors.");
					// 1.2.4 Iterate through the XYZs and count the numbers of each type
					if(i==0){
						sCount = 0;
						oCount = 0;
						dCount = 0;
						gCount = 0;
						uCount = 0;
						Table.open(batchpath+sdAna+imName+".XYZ."+availXYZ[j]+".csv");
						for (k = 0; k < Table.size; k++) {
							id = Table.getString("ID",i);
							included = Table.getString("XYZinROI?", k);
							if (included == "Yes"){
								status = Table.getString("SynapseStatus",k);
								if(status=="Synapse"){              
									sCount++;
								}else if (status=="Orphan"){			
									oCount++;
								}else if (status=="Doublet"){	   
									dCount++;
								}else if (status=="Garbage"){	   
									gCount++;
								}else{								
									uCount++;
								}
							}
						}
						//close("*.csv");
						// 1.2.4.1 Open Batch Master and update information about XYZs
						Table.open(batchpath+sdAna+fBM);
						Table.set(availXYZ[j]+"_nSynapses", imIndex, sCount);
						Table.set(availXYZ[j]+"_nDoublets", imIndex, dCount);
						Table.set(availXYZ[j]+"_nOrphans", imIndex, oCount);
						Table.set(availXYZ[j]+"_nGarbage", imIndex, gCount);
						Table.set(availXYZ[j]+"_nUnclear", imIndex, uCount);
						Table.update;
						Table.save(batchpath+sdAna+fBM);
						close("*.csv");
						close("*");
					}else if(i==1){
						Table.open(batchpath+sdAna+imName+".XYZ."+availXYZ[j]+".csv");
						posCount = 0;
						negCount = 0;
						uncCount = 0;
						for (k = 0; k < Table.size; k++) {
							id = Table.getString("ID",k);
							included = Table.getString("XYZinROI?", k);
							if (included == "Yes"){
								status = Table.getString("TerminalStatus",k);
								if(status=="Positive"){              
									posCount++;
								}else if (status=="Negative"){			
									negCount++;
								}else{								
									uncCount++;
								}
							}
						}
						// 1.2.4.1 Open Batch Master and update information about XYZs
						Table.open(batchpath+sdAna+fBM);
						Table.set(availXYZ[j]+"_nSynapses", imIndex, posCount);
						Table.set(availXYZ[j]+"_nDoublets", imIndex, negCount);
						Table.set(availXYZ[j]+"_nOrphans", imIndex, uncCount);
						Table.update;
						Table.save(batchpath+sdAna+fBM);
						close("*.csv");
						close("*");
					}
					// 2.3.9 Update status
					fxStatus[f+1] = "Comp_"+availXYZ[j]+tnSteps[i];
					f++;
				}
			}
		}
	}
	Table.open(batchpath+sdAna+fBM);
	fxStr = String.join(fxStatus);
	Table.set("reviewArraysStatus",imIndex,fxStr);
	Table.update;
	Table.save(batchpath+sdAna+fBM);
	close("*.csv");
	}
}


// PERFORM PILLAR-MODIOLAR MAPPING -- FX FOR ASSIGNING PILLAR-MODIOLAR STATUS BASED ON USER DEFINED AXIS
function mapPillarModiolar(batchpath, imName, imIndex){
	// 1. Get the status for this function
	Table.open(batchpath+sdAna+fBM);
	fxStatusTemp = Table.getString("mapPillarModiolarStatus", imIndex);
	fxStatArr = split(fxStatusTemp);
	// 2. Check with user to proceed with thumbnail generation
	Dialog.create("Mapping Pillar-Modiolar");
	Dialog.addMessage("Function status: ");
	for (i = 0; i < lengthOf(fxStatArr); i++) {
		Dialog.addMessage(fxStatArr[i]);
	}
	Dialog.addString("Proceed with pillar-modiolar mapping for all available XYZ data sets?","Yes");
	Dialog.addMessage("If yes, indicate channels to include for mapping:");
	Dialog.addString("Channels to use for pillar-modiolar:",defPMCh);
	Dialog.show();
	proceed=Dialog.getString();
	if(proceed=="Yes"){
		if(fxStatusTemp=="TBD"){
			fxStatusTemp="Initialized";
		}
		// 1.1 Get and set information about channels to include
		chStr = Dialog.getString();
		chArr = split(chStr, "'[',',',']',' ',");
		chCount = lengthOf(chArr);
		Table.open(batchpath+sdAna+fBM);
		Table.set("Pillar-Modiolar Marker Channels", imIndex, chStr);
		Table.update;
		Table.save(batchpath+sdAna+fBM);
		// 1.2 Have the user draw an ROI for the area to work on 
		open(batchpath+sdRM+imName+".MPI.tif");
		setTool("rectangle");
		waitForUser("Draw a rectangle around the region to include in pillar-modiolar mapping.\n"+
					"Then press [t] to add to the ROI Manager.\n"+
					"Make sure the rectangle is still visible when pressing 'Ok' to proceed.");
		Roi.getCoordinates(xpoints, ypoints);
		Array.print(xpoints);
		Array.print(ypoints);
		xSt = xpoints[0];
		xEnd = xpoints[1];
		bbXZ = xpoints[0];
		bbXO = xpoints[1];
		bbYZ = ypoints[0];
		bbYT = ypoints[2];
		close();
		// 1.3 Get available XYZ data information
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
		//  . Update fxStatus
		fxStatus = newArray(xyzFCount+1);
		fxStatus[0]=fxStatusTemp; 
		f = 0;
		
		// ---- This section was originally within the for-loop
		// 1.4.1 Open the User Adjusted tif to generate YZ projection & create a composite
		//   using default LUT
		open(batchpath+sdTIF+imName+".UserAdj.tif");
		rename(imName+imFType);
		Stack.getDimensions(width, height, channels, slices, frames);
		run("Split Channels");
		for (j = 0; j < channels; j++) {
			ch = j+1;
			selectImage("C"+toString(ch)+"-"+imName+imFType);
			keepOpen = "False";
			for (k = 0; k < chCount; k++) {
				if(chArr[k]==ch){
					keepOpen = "True";
				}
			}
			if(keepOpen=="False"){
				close();
			}
		}
		compChArr = newArray(chCount+1);
		compChStr = "";
		for (j = 0; j < chCount; j++) {
			// . Create an array of image file names for calling windows
			compChArr[j] = "C"+chArr[j]+"-"+imName+imFType;
			// . Create string for Merge Channels argument 
			compChStr = compChStr+defPMLUT[j]+"="+compChArr[j]+" ";
			// . When all single channel names have been setup, add final name for comp image
			if(j==(chCount-1)){
				compChArr[j+1]=imName+imFType;
			}
		}
		run("Merge Channels...", compChStr+" create ignore");
		rename(imName+imFType);
		
		// 1.4.2 Create the YZ projection
		makeRectangle(xSt, 0, xEnd-xSt, height);
		run("Crop");
		run("Reslice [/]...", "output="+vxD+" start=Left flip");
		run("Z Project...", "projection=[Sum Slices]");
		getPixelSize(unit, pixW, pixH);
		run("Flatten");
		close("\\Others");
		// . Save a version of the image with no annotations
		getDimensions(width, height, channels, slices, frames);
		scaleF = round(annImW/width);
		outputW = scaleF*width;
		outputH = scaleF*height;
		run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+
			" interpolation=Bilinear average create");
		save(batchpath+sdPM+imName+".PMMap.png");
		close();
		// 1.4.3 Have the user draw the p-m axis
		setTool("line");
		waitForUser("Draw the pillar-modilar axis across the\nbasolateral region of the hair cell.\n"+
					"Make sure that the line is still visible before closing this window.");
		getLine(x1, y1, x2, y2, lineWidth);
		getDimensions(width, height, channels, slices, frames);
		// . Find the midpoint of the line
		xMid = (x1+x2)/2;
		yMid = (y1+y2)/2;
		// . Find the equation of the line
		slope = (y2-y1)/(x2-x1);
		int = y1-(slope*x1);
		// . Find the equation of the perpendicular line
		pSlope = -1/slope;
		pInt = yMid-(pSlope*xMid);
		// . Get the start and end points for the perpendicular line
		xSt = 0;
		xEnd = width;
		ySt = pInt;
		yEnd = (pSlope*xEnd)+pInt;
		// 1.4.4 Add annotations to the image
		makePoint(xMid, yMid, "small yellow hybrid add");
		setLineWidth(3);
		setColor("yellow");
		drawLine(x1, y1, x2, y2);
		setColor("white");
		drawLine(xSt, ySt, xEnd, yEnd);
		// ----------------------------------------------
		
		
		// 1.4 Iterate through the possible XYZ data sets
		for (i = 0; i < xyzFCount; i++) {
			selectWindow("SUM_Reslice of "+imName+"-1"+imFType);	
			// 1.4.5 Iterate through the XYZs and assign P-M status based on position above or below the 
			// . the apical-basal axis. 
			Table.open(batchpath+sdAna+imName+".XYZ."+availXYZ[i]+".csv");
			nXYZs = Table.size;
			pCount = 0;
			mCount = 0;
			for (j = 0; j < nXYZs; j++) {
				xPos = Table.get("Position X (voxels)", j);
				yPos = Table.get("Position Y (voxels)", j);
				slZ = Table.get("Position Z (voxels)", j);
				// . Verify that the XYZ is within the user defined main bounding box
				if ((xPos >= bbXZ) && (xPos <= bbXO)) { 
					if ((yPos >= bbYZ) && (yPos <= bbYT)) {
						if ((slZ >= slStart) && (slZ <= slEnd)){
							id = Table.get("ID", j);
							// New coordinate system means original x-coords are now y
							// . will need to add info in Readme about this
							xPos = Table.get("Position Y (voxels)", j);
							// The y-coord is weird because it was z-coord prior to the transformation
							//  and the reslicing generates pixels in the new y-direction using interpolation.
							// . So now thew new y-coordinate has to be scaled and subracted from the total image height. 
							yPos = height-(Table.get("Position Z", j))/pixH;
							// Now we determine if it's above or below the AB-axis
							if(yPos > ((pSlope*xPos)+pInt)){
								if(i==01){
									ptColor = "cyan";
								}else{
									ptColor = "purple";
								}
								// Add an annotation to the MPI for verification purposes
								makePoint(xPos, yPos, "medium "+ptColor+" dot add");
								setFont("SansSerif",8, "antiliased");
							    setColor(255, 255, 255);
								drawString(id, xPos, yPos);
								Table.set("PMStatus", j, "Modiolar");
								Table.update;
								mCount++;
							}else{
								if(i==01){
									ptColor = "green";
								}else{
									ptColor = "pink";
								}
								// Add an annotation to the MPI for verification purposes
								makePoint(xPos, yPos, "medium "+ptColor+" dot add");
								setFont("SansSerif",8, "antiliased");
							    setColor(255, 255, 255);
								drawString(id, xPos, yPos);
								Table.set("PMStatus", j, "Pillar");
								Table.update;
								pCount++;
							}
						}
					}
				}
			}
			Table.save(batchpath+sdAna+imName+".XYZ."+availXYZ[i]+".csv");
			// 1.4.6 Rescale the image and save with annotations
			getDimensions(width, height, channels, slices, frames);
			// . Calculate the scaling factor and output dimensions
			scaleF = round(annImW/width);
			outputW = scaleF*width;
			outputH = scaleF*height;
			// .  Scale the annotated image
			run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+
				" interpolation=Bilinear average create");
			// . Save the annotated image
			save(batchpath+sdPM+imName+".AnnPMMap."+availXYZ[i]+".png");
			close(imName+".AnnPMMap."+availXYZ[i]+".png");
			close("*.csv");
			// Add counts to Batch Master
			Table.open(batchpath+sdAna+fBM);
			Table.set(availXYZ[i]+"_nPillar", imIndex, pCount);
			Table.set(availXYZ[i]+"_nModiolar", imIndex, mCount);
			Table.update;
			Table.save(batchpath+sdAna+fBM);
			close("*.csv");
			// 2.3.9 Update status
			fxStatus[f+1] = "Comp_"+availXYZ[i];
			f++;
		}
	Table.open(batchpath+sdAna+fBM);
	fxStr = String.join(fxStatus);
	Table.set("mapPillarModiolarStatus",imIndex,fxStr);
	Table.update;
	Table.save(batchpath+sdAna+fBM);
	close("*.csv");
	}
	close("*");
}
