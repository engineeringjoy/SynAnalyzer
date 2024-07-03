/*
 * SynAnalyzer.ijm
 * Created by JFranco, 02 JUL 2024
 * Last update: 02 JUL 2024
 * 
 * This .ijm macro is a work in progress. The ultimate goal is to read in an .xlsx file that contains the XYZ positions of 
 * all CtBP2 surfaces and to generate thumbnail views of a 1.5 um cube centered at the XYZ position as in  
 * Liberman, Wang, and Liberman 2011 (DOI:10.1523/JNEUROSCI.3389-10.2011). 
 * 
 * Status: Currently building off of SynAnalyzer_GenSynArray.ijm to add in the functionality
 * discussed by the Bclw team rather than just generating a synapse array.
 */
 
/* 
************************** SynAnalyzer.ijm ******************************
* 						      MAIN MACRO
*/
 
// *** HOUSEKEEPING ***
run("Close All");
run("Labels...", "color=white font=12 show use draw bold");

// *** INITIALIZE SYNAPSE ANALYZER ***
// Function will check if this is the first time the analysis has been run and setup
//   the batch folder accordingly
batchpath = initSynAnalyzer();

// *** PROCEED WITH ANALYSIS ***
choice = getChoice();
while (choice != "EXIT") {
	if (choice == "Batch") {
		// Batch mode iterates through all unalyzed images until the user says to stop
		runBatch(batchpath);
	}else{
		
	}
	choice = getChoice();
}

/* 
************************** FUNCTIONS ****************************** 						      
*/

// INITIALIZE SYNANLAYZER FOR THIS BATCH
function initSynAnalyzer() { 
	// *** GET PATH TO BATCH FOLDER ***
	Dialog.create("SynAnalyzer Bootup");
	Dialog.addMessage("This macro will open your z-stack of choice\n"+
	"and create a thumbnail array of regions surrounding specific XYZ coordinates\n"+
	"based on the accompanying .csv file(s).\n"+
	"Please see GitHub Repo for file structure requirements.");
	Dialog.addString("Enter the path to the batch folder:", "/Users/joyfranco/Partners HealthCare Dropbox/Joy Franco/JF_Shared/Data/CodeDev/SynAnalyzerBatch/");
	Dialog.show();
	batchpath = Dialog.getString();
	
	// *** SETUP PATHNAMES FOR SUBDIRECTORIES ***
	dirIms = batchpath+"RawImages/";
	dirSI = batchpath+"SAR.SummaryImages/";
	dirSA = batchpath+"SAR.SynArrays/";
	dirPM = batchpath+"SAR.PillarModiolarMaps/";
	dirAM = batchpath+"SAR.AnnotatedMPIs/";
	dirAM = batchpath+"SAR.POIAnnotations/";            // Point of interest annotations - stores CSV of details for each surface
	dirMD = batchpath+"Metadata/";
	fBM = "SynAnalyzerBatchMaster.csv";
	
	// *** GET LIST OF BATCH IMAGES ***
	filelist = getFileList(dirIms);
	
	// *** CREATE SUBFOLDERS IF THEY DO NOT EXIST ***
	if (!File.isDirectory(dirSI)) {
		File.makeDirectory(dirSI);
		File.makeDirectory(dirSA);
		File.makeDirectory(dirPM);
		File.makeDirectory(dirAM);
		
		// *** SETUP BATCH MASTER RESULTS TABLE ***
		Table.create("SynAnalyzerBatchMaster.csv");
		for (i = 0; i < lengthOf(filelist); i++) {
		    if (endsWith(filelist[i], ".czi")) { 
		        Table.set("ImageName", i, filelist[i]);
				Table.set("Analyzed?", i, "No");
				Table.set("AvailXYZData", i, "TBD");
				Table.set("ZStart", i, "TBD");
				Table.set("ZEnd", i, "TBD");
				Table.set("Voxel Width (um)", i, "TBD");
				Table.set("Voxel Height (um)", i, "TBD");
				Table.set("BB X0", i, "TBD");
				Table.set("BB X1", i, "TBD");
				Table.set("BB Y0", i, "TBD");
				Table.set("BB Y2", i, "TBD");
				Table.set("NumberOfHairCells", i, "TBD");
				Table.set("PreSynCentSynapses", i, "TBD");
				Table.set("PostSynCentSynapses", i, "TBD");
				Table.set("PreSynCentDoublets", i, "TBD");
				Table.set("PostSynCentDoublets", i, "TBD");
				Table.set("PreSynOrphans", i, "TBD");
				Table.set("PostSynOrphans", i, "TBD");
		    } 
		}
		Table.save(dirMD+fBM);
	}else { 
		Table.open(dirMD+fBM);
		// *** CHECK IF THERE ARE ADDITIONAL IMAGES THAT SHOULD BE ADDED ***
		// Get the list of images currently in the table
		ims = Table.getColumn("ImageName");
		// Iterate through every file from the list of files in the RawImages directory
		for (i = 0; i < lengthOf(filelist); i++) {
			// Boolean Value
			bool = "False";
		    if (endsWith(filelist[i], ".czi")) { 
		        // Check if the current file in question is in the list of existing images
		        for (j = 0; j < lengthOf(ims); j++) {
					if (filelist[i] == ims[j]) {
						bool = "True";
					}
				}
				// Add the filename to the table if bool did not switch to being true
				if (bool == "False") {
					row = Table.size;
					Table.set("ImageName",row, filelist[i]);
					Table.set("Analyzed?", row, "No");
					Table.set("ZStart", row, "TBD");
					Table.set("ZEnd", row, "TBD");
					Table.set("Voxel Width (um)", row, "TBD");
					Table.set("Voxel Height (um)", row, "TBD");
					Table.set("BB X0", row, "TBD");
					Table.set("BB X1", row, "TBD");
					Table.set("BB Y0", row, "TBD");
					Table.set("BB Y2", row, "TBD");      
					Table.set("NumberOfHairCells", row, "TBD");
					Table.set("PreSynCentSynapses", row, "TBD");
					Table.set("PostSynCentSynapses", row, "TBD");
					Table.set("PreSynCentDoublets", row, "TBD");
					Table.set("PostSynCentDoublets", row, "TBD");
					Table.set("PreSynOrphans", row, "TBD");
					Table.set("PostSynOrphans", row, "TBD");
					Table.update;
				}	
		    }
		}
		Table.save(dirMD+fBM);
	}
	return batchpath;
}

// ALLOW USER TO CHOOSE HOW TO PROCEED
function getChoice() {
	// *** ASK THE USER WHAT THEY WANT TO DO ***
	choiceArray = newArray("Batch", "Specific Image", "EXIT");
	Dialog.create("SynAnalyzer GetChoice");
	Dialog.addMessage("Choose analysis mode:");
	Dialog.addRadioButtonGroup("Choices",choiceArray, 3, 1, "Batch");
	Dialog.show();
	choice = Dialog.getRadioButton();
	return choice;
}

// ITERATE THROUGH ALL AVAILABLE IMAGES IN THE BATCH
function runBatch(batchpath) {
	// Iterate through these images, analyzing those that have not been
	//   analyzed yet, until user says to stop
	batch = "Go";
	// *** ITERATE THROUGH THE AVAILABLE IMAGES ***
	// Get the Batch Master list of images
	ims = Table.getColumn("ImageName");
	// Get a list of images available to analyze
	filelist = getFileList(batchpath+"RawImages/");
	// Batch Mode Go 
	i = 0;
	while (batch != "Stop") {
		// *** GO THROUGH THE STEPS OF VALIDATION THEN PROCEEDING WITH ANALYSIS ***
		// Verify that the image exists, has XYZ data, and then proceed with analysis
		exists = imVerification(i, filelist[i], filelist, ims, batchpath);
		// If true, then the image file was not in RawImages when the macro was started 
		if (exists == "No") {
			// The Batch Master list needs to be updated. Easiest is to have the user restart. 
			print(filelist[i]+" is not registered with Batch Master.\nRecommend restarting the macro if you want to analyze this image.");
		}
		// Increment index to include this run before checking count 
		i++;
		// Stop batch mode if all of the images have been iterated through
		if(i<lengthOf(filelist)){
			choiceArray = newArray("Go", "Stop");
			Dialog.create("Checkin");
			Dialog.addRadioButtonGroup("Proceed with batch mode?", choiceArray, 2, 1, "Go");
			Dialog.show();
			batch = Dialog.getRadioButton();
		}else{
			batch = "Stop";
			print("All available files have been checked for analysis. Exiting batch mode.");
		}
	}

}

// VERIFY THAT THAT THE IMAGE IS VALID BEFORE CALLING ANALYSIS MODULE
function imVerification(i, filename, filelist, ims, batchpath){
	// Check that the file is an acceptable format
    if (endsWith(filename, ".czi")) { 
        // Boolean for tracking if the image is registered with the Batch Master
        exists = "No";
        // Go through the list of images in the Batch Master and check if the filename
        //   matches the registered image name
        for (j = 0; j < lengthOf(ims); j++) {
			// CASE WHERE IT EXISTS
			if (filename == ims[j]) {
				// Update the boolean
				exists = "Yes";
				// Check if the image has been analyzed or not
				analyBool = Table.getString("Analyzed?", j);
				// If the image hasn't been analyzed, check that it has XYZs available
				if (analyBool == "No"){
					imName = substring(filename, 0, indexOf(filename, ".czi"));
					pESxyz = batchpath+"/XYZCSVs/"+imName+".XYZ.PreSyn.csv";
					pTSxyz = batchpath+"/XYZCSVs/"+imName+".XYZ.PostSyn.csv";
					// First check if the file has presynaptic XYZ data
					if (File.exists(pESxyz)) {
						// Check if it also has postsynaptic XYZ data
						if (File.exists(pTSxyz)) {
							// Great, proceed with full analysis
							adXYZ ="Both Pre- and Post-";
						}else{
							// Great, proceed with full analysis
							adXYZ ="Only Pre-";
						}
						
					}else if(File.exists(pTSxyz)){ // If it doesn't have presyn XYZ data, check if it has postsyn...
						// If it does have postsynaptic XYZs, just verify that the user wants to continue
						adXYZ ="Only Post-";
					}else{
						adXYZ ="None";
					}
					// Update information about the analysis for this image
					Table.set("AvailXYZData", j, adXYZ);
					Table.update;
					Table.save(batchpath+"Metadata/SynAnalyzerBatchMaster.csv");
					
					if (adXYZ=="None"){
						// The Batch Master list needs to be updated. Easiest is to have the user restart. 
						print(imName+" exists but does not have XYZ data associated with the image. Skipping to the next image.");
					}else{
						// For all other cases, proceed with the analysis with the available XYZ data. 
						print(imName+" exists and has "+adXYZ+"XYZ data associated with the image. Proceeding with analysis.");
						// *** PROCEED TO ANALYSIS HERE ***
						imIndex = j;
						analyzeIm(batchpath, imName, adXYZ, imIndex);
					}	
				}
			}
		}
    }
    return exists;
}

// MAIN FUNCTION FOR ANALYZING AN IMAGE
function analyzeIm(batchpath, imName, adXYZ, imIndex){
	// *** SET THE NUMBER OF ITERRUNS BASED ON DATA ***
	if (adXYZ == "Both Pre- and Post-") {
		ir = 2;
		fName = newArray("PreSyn","PostSyn");
	}else {
		ir =  1;
		if (adXYZ=="Only Pre-"){
			fName = newArray("PreSyn");
		}else{
			fName = newArray("PostSyn");
		}
	}
	
	// *** 1. OPEN THE IMAGE AND GET KEY INFO ***
	getAnalysisInfo(batchpath, imName, imIndex);

	// *** 2. ITERATE THROUGH AVAILABLE XYZ DATA SETS ***
	for (i = 0; i < ir; i++) {
		//2.1. Verify that the XYZs seem to match the image
		match = verifyXYZMatch(batchpath, imName, fName, imIndex);
		if (match == "Yes"){
			//2.2 Generate thumbnails
			// *** PICK BACK UP HERE ***
		}
	}
	*/
}

// GET INFORMATION ABOUT HOW TO ANALYZE THIS IMAGE
function getAnalysisInfo(batchpath, imName, imIndex){
	roiManager("reset");
	open(batchpath+"RawImages/"+imName+".czi");
	//Allow the user to specify the channels to include
	waitForUser("Review the image and choose slices to include. Enter these values in the next dialog box");
	Stack.getDimensions(width, height, channels, slices, frames);
	Dialog.create("Create Substack");
	Dialog.addMessage("Indicate the slices to include in the analysis.");
	Dialog.addString("Slice Start","1");
	Dialog.addString("Slice End", slices);
	Dialog.show();
	slStart = Dialog.getString();
	slEnd = Dialog.getString();
	
	//Get the pixel size and calculate the width and height for cropping (um/px)
	getVoxelSize(vxW, vxH, vxD, unit);
	
	//Make a max proj to help user with visualizing surfaces
	run("Make Substack...", "slices="+slStart+"-"+slEnd);
	run("Z Project...", "projection=[Max Intensity]");
	run("Make Composite");
	run("Flatten");
	selectImage(imName+".czi");
	close();
	selectImage(imName+"-1.czi");
	close();
	selectImage("MAX_"+imName+"-1.czi");
	close();
	//Have the user draw a rectangle around the region to analyze
	waitForUser("Draw a rectangle around the hair cells to include in the analysis then press [t] to add to the ROI Manager.\n"+
				"Start with the upper left corner and move down and right across the image."+
				"Make sure the rectangle is still visible when pressing 'Ok' to proceed.");
	// Get the coordinates for the rectangle
	Roi.getCoordinates(xpoints, ypoints);
	Roi.remove;
	// Update the Batch Master table
	Table.open(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
	Table.set("ZStart", imIndex, slStart);
	Table.set("ZEnd", imIndex, slEnd);
	Table.set("Voxel Width (um)", imIndex, vxW);
	Table.set("Voxel Height (um)", imIndex, vxH);
	Table.set("BB X0", imIndex, xpoints[0]);
	Table.set("BB X1", imIndex, xpoints[1]);
	Table.set("BB Y0", imIndex, ypoints[0]);
	Table.set("BB Y2", imIndex, ypoints[2]);
	Table.save(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
	waitForUser;
	// Test
	makeRectangle(xpoints[0], ypoints[0], xpoints[1]-xpoints[0], ypoints[2]-ypoints[0]);
}

// VERIFY THAT THE XYZ POSITIONS MATCH THE IMAGE
function verifyXYZMatch(batchpath, imName, fName, imIndex){
	open(batchpath+"RawImages/"+imName+".czi");
	// Get parameters for substack
	Table.open(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
	slStart = Table.get("ZStart", rowIndex);
	slEnd = Table.get("ZEnd", rowIndex);
	// Generate a max projection composite image that will be labelled with points of interest
	run("Make Substack...", "slices="+slStart+"-"+slEnd);
	run("Z Project...", "projection=[Max Intensity]");
	run("Make Composite");
	run("Flatten");
	selectImage(imName+".czi");
	close();
	selectImage(imName+"-1.czi");
	close();
	selectImage("MAX_"+imName+"-1.czi");
	close();
	// Loat the XYZ points
	Table.open(batchpath+"XYZCSVs/"+imName+".XYZ."+fName[i]+".csv");
	// Calculate the conversion factor
	getPixelSize(unit, pixelWidth, pixelHeight);
	// Iterate through the rows of the XYZ table and add points to image
	tableRows = Table.size;
	for (i = 0; i < tableRows; i++) {
		xPos = (Table.get("Position X", i))*(1/pixelWidth);
		yPos = (Table.get("Position Y", i))*(1/pixelWidth);
		Table.set("Position X (pixels)", i, xPos);
		Table.set("Position Y (pixels)", i, yPos);
		makePoint(xPos, yPos, "small yellow hybrid");
		roiManager("Add");
	}
	roiManager("show all with labels");
	// Ask the user to verify that the XYZ data matches the image
	choiceArray = newArray("Yes", "No");
	Dialog.create("Checkin");
	Dialog.addRadioButtonGroup("Do these XYZ points match the image?", choiceArray, 2, 1, "Go");
	Dialog.show();
	return Dialog.getRadioButton();
}
