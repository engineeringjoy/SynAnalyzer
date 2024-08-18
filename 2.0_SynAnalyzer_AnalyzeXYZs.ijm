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
sdRI = "RawImages/";
sdMD = "Metadata/";
sdAna = "SAR.Analysis/";
sdSI = "SAR.SummaryImages/";
sdSA = "SAR.SynArrays/";
sdPM = "SAR.PillarModiolarMaps/";
sdAM = "SAR.AnnotatedMPIs/";
sdPA = "SAR.POIAnnotations/";            
sdRM = "SAR.RawMPIs/";
sdTN = "SAR.Thumbnails/";
// Batch Master file name
fBM = "SynAnalyzerBatchMaster.csv";
// Thumbnail bounding box dimesions in um
tnW = 2;
tnH = 2;
tnZ = 1.5;
// Annotated Image Size - Currently based on the output width of the SynArray
annImW = 1650;
// Rolling ball radius for background subtraction (in pixels)
rbRadius = 50;
// Image file type
imFType = ".czi";
// Image analysis info - Columns for Batch Master
bmCols = newArray("ImageName","Analyzed?","AvailXYZData", "ZStart", "ZEnd", "Synaptic Marker Channels",
	 			  "Terminal Marker Channels", "Pillar-Modiolar Marker Channels", "Voxel Width (um)", 
	 			  "Voxel Depth (um)", "BB X0", "BB X1", "BB Y0", "BB Y2", "PreSynXYZinROI", 
	 			  "PostSynXYZinROI", "PreSyn_nSynapses", "PreSyn_Synapses", "PostSyn_nSynapses", 
	 			  "PostSyn_Synapses", "PreSyn_nDoublets", "PreSyn_Doublets", "PostSyn_nDoublets", 
	 			  "PostSyn_Doublets", "PreSyn_nOrphans", "PreSyn_Orphans", "PostSyn_nOrphans", 
	 			  "PostSyn_Orphans", "PreSyn_nGarbage", "PreSyn_Garbage", "PostSyn_nGarbage", 
	 			  "PostSyn_Garbage", "PreSyn_nUnclear", "PreSyn_Unclear", "PostSyn_nUnclear", 
	 			  "PostSyn_Unclear", "PreSyn_nWMarker", "PreSyn_WMarker", "PostSyn_nWMarker", 
	 			  "PostSyn_WMarker", "PreSyn_nPillar", "PreSyn_nPModiolar", "PostSyn_nPillar", 
	 			  "PostSyn_nPModiolar");
cols = lengthOf(bmCols);

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
	dirIms = batchpath+sdRI;
	dirMD = batchpath+sdMD;
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
		    		}else if (j==1){
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
			    		}else if (j==1){
			    			Table.set(bmCols[j], i, "No");
			    		}else{
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
		if(fStatus == "Acceptable"){
			print("File "+fileName+" is valid and has been registered. Proceeding with analysis.");
			// 3.2.1. Initialize the image
			initializeIm(batchpath, fileName, imIndex);
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
			choiceArray = newArray("Go", "Stop");
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
	// 1. Notify user that image verification is beginning
	waitForUser("Proceeding with Image Verification");
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
function initializeIm(batchpath, fileName, imIndex){
	// 1. Notify user that image initialization is beginning
	waitForUser("Initializing image "+ fileName);
	// 2. Check if the image has already been initialized
	Table.open(batchpath+sdAna+fBM);
	xyzStatus = Table.getString("AvailXYZData", imIndex);
	close("*.csv");
	// 3. Determine how to proceed if already initialized
	if(xyzStatus!="TBD"){
		// . Check in with user 
		Dialog.create("Check to proceed");
		Dialog.addString("Image has bee initialized. Repeat the process?", "Yes");
		Dialog.show();
		check = Dialog.getString();
		if (check == "Yes"){
			// Update information about the analysis for this image
			xyzStatus == "TBD";
		}else{
			imStatus = "Skip";
		}
	}
	// 4. Check for available XYZ datasets
	if(xyzStatus=="TBD"){
		imName = substring(fileName, 0, indexOf(fileName, ".czi"));
		pESxyz = batchpath+"/XYZCSVs/"+imName+".XYZ.PreSyn.csv";
		pTSxyz = batchpath+"/XYZCSVs/"+imName+".XYZ.PostSyn.csv";
		xyzFiles = newArray("PreSyn", "PostSyn");
		// . Check for pre-synaptic XYZ data
		if (File.exists(pESxyz)) {
			// . Check if it also has postsynaptic XYZ data
			if (File.exists(pTSxyz)) {
				adXYZ ="Both Pre- and Post-";
				xyzFCount = 2;
			}else{
				adXYZ ="Only Pre-";
				xyzFCount = 1;
				xyzFiles = xyzFiles[0];
			}
		}else if(File.exists(pTSxyz)){ 
			adXYZ ="Only Post-";
			xyzFCount = 1;
			xyzFiles = xyzFiles[1];
		}else{
			adXYZ ="None";
		}
		// . Update information about the analysis for this image
		Table.open(batchpath+sdAna+fBM);
		Table.set("AvailXYZData", imIndex, adXYZ);
		Table.update;
		Table.save(batchpath+sdAna+fBM);
		// 4.1 Initialize image information
		if (adXYZ=="None"){
			// . The Batch Master list needs to be updated. Easiest is to have the user restart. 
			print(imName+" exists but does not have XYZ data associated with the image.");
			imStatus = "Skip";
		}else{
			// . Open the image and get basic information
			open(batchpath+sdRI+fileName);
			getVoxelSize(vxW, vxH, vxD, unit);
			Stack.getDimensions(width, height, channels, slices, frames);
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
			// . Create a max projection of the image
			waitForUser("Adjust the brightness/contrast of the image as necessary for the maximum projection.");
			run("Make Substack...", "slices="+slStart+"-"+slEnd);
			run("Z Project...", "projection=[Max Intensity]");
			run("Make Composite");
			run("Flatten");
			save(batchpath+sdRM+imName+".RawMPI.tif");
			close("*");
			// . Verify that XYZ datasets match the image
			for (i = 0; i < lengthOf(xyzFiles); i++) {
				// Open the substack MPI for labelling purposes
				open(batchpath+sdRM+imName+".RawMPI.tif");
				// Load the raw XYZ points
				Table.open(batchpath+sdXYZs+imName+".XYZ."+xyzFiles[i]+".csv");
				// Save a clean version of the XYZ file to add analysis info
				Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+xyzFiles[i]+".csv");
				// Iterate through the rows of the XYZ table and add points to image
				//  also adding converted positions in this step for ease 
				tableRows = Table.size;
				Table.sort("ID");
				Table.update;
			}
		}
	}
	return imStatus;
}



















