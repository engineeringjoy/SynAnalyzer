/*
 * SynAnalyzer.ijm
 * Created by JFranco, 02 JUL 2024
 * Last update: 06 JUL 2024
 * 
 * ** STILL IN BETA MODE ***
 * 
 * This ImageJ macro reads in a .csv file that was formatted using the SynAnalyzer Python notebook that converts
 * .xlsx files from Imaris into the format required for this macro. From that .csv file, the macro walks a user
 * through the process of analyzing pre- and post-synaptic regions as in Liberman, Wang, and Liberman 2011
 * (DOI:10.1523/JNEUROSCI.3389-10.2011). 
 * 
 * Status: Macro is largely function and has been tested. There are still some functions that I want to add
 * and additional tests that will be important to run before handing it off to users. README documentation
 * and User tutorials stil need to be made. At some point the macro will be converted into a Plugin for those
 * who prefer that approach. 
 */
 
/* 
************************** SynAnalyzer.ijm ******************************
* 						      MAIN MACRO
*/
// *** USER PRESETS ***
// Default batch path
defBP = "/Users/joyfranco/Partners HealthCare Dropbox/Joy Franco/JF_Shared/Data/CodeDev/SynAnalyzerBatch/";
// Thumbnail bounding box dimesions in um
tnW = 2;
tnH = 2;
tnZ = 1.5;

// *** HOUSEKEEPING ***
run("Close All");
run("Labels...", "color=white font=12 show use draw bold");

// *** INITIALIZE SYNAPSE ANALYZER ***
// Function will check if this is the first time the analysis has been run and setup
//   the batch folder accordingly
batchpath = initSynAnalyzer();

// *** PROCEED WITH ANALYSIS ***
choice = getUserChoice();
while (choice != "EXIT") {
	if (choice == "Batch") {
		// Batch mode iterates through all unalyzed images until the user says to stop
		runBatch(batchpath);
	}else{
		// Specific Image mode allows the user to select a specific image and only analyzes that one.
		runSpecific(batchpath);
	}
	choice = getUserChoice();
}
// *END MAIN MACRO*

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
	Dialog.addString("Enter the path to the batch folder:", defBP);
	Dialog.show();
	batchpath = Dialog.getString();
	
	// *** SETUP PATHNAMES FOR SUBDIRECTORIES ***
	dirIms = batchpath+"RawImages/";
	dirMD = batchpath+"Metadata/";
	dirAna = batchpath+"SAR.Analysis/";
	dirSI = batchpath+"SAR.SummaryImages/";
	dirSA = batchpath+"SAR.SynArrays/";
	dirPM = batchpath+"SAR.PillarModiolarMaps/";
	dirAM = batchpath+"SAR.AnnotatedMPIs/";
	dirPA = batchpath+"SAR.POIAnnotations/";            // Point of interest annotations - stores CSV of details for each surface
	dirRM = batchpath+"SAR.RawMPIs/";
	dirTN = batchpath+"SAR.Thumbnails/";
	fBM = "SynAnalyzerBatchMaster.csv";
	
	// *** GET LIST OF BATCH IMAGES ***
	filelist = getFileList(dirIms);
	
	// *** CREATE SUBFOLDERS IF THEY DO NOT EXIST ***
	if (!File.isDirectory(dirSI)) {
		File.makeDirectory(dirAna);
		File.makeDirectory(dirSI);
		File.makeDirectory(dirSA);
		File.makeDirectory(dirPM);
		File.makeDirectory(dirAM);
		File.makeDirectory(dirRM);
		File.makeDirectory(dirTN);
		
		// *** SETUP BATCH MASTER RESULTS TABLE ***
		Table.create("SynAnalyzerBatchMaster.csv");
		for (i = 0; i < lengthOf(filelist); i++) {
		    if (endsWith(filelist[i], ".czi")) { 
		        Table.set("ImageName", i, filelist[i]);
				Table.set("Analyzed?", i, "No");
				Table.set("AvailXYZData", i, "TBD");
				Table.set("ZStart", i, "TBD");
				Table.set("ZEnd", i, "TBD");
				Table.set("Included Channels", i, "TBD");
				Table.set("Voxel Width (um)", i, "TBD");
				Table.set("Voxel Depth (um)", i, "TBD");
				Table.set("BB X0", i, "TBD");
				Table.set("BB X1", i, "TBD");
				Table.set("BB Y0", i, "TBD");
				Table.set("BB Y2", i, "TBD");
				Table.set("NumberOfHairCells", i, "TBD");
				Table.set("PreSynXYZinROI", i, "TBD");
				Table.set("PostSynXYZinROI", i, "TBD");
				Table.set("PreSynSynapses", i, "TBD");
				Table.set("PostSynSynapses", i, "TBD");
				Table.set("PreSynDoublets", i, "TBD");
				Table.set("PostSynDoublets", i, "TBD");
				Table.set("PreSynOrphans", i, "TBD");
				Table.set("PostSynOrphans", i, "TBD");
				Table.set("PreSynGarbage", i, "TBD");
				Table.set("PostSynGarbage", i, "TBD");
				Table.set("PreSynWMarker", i, "TBD");
				Table.set("PostSynWMarker", i, "TBD");
		    } 
		}
		Table.save(dirAna+fBM);
	}else { 
		Table.open(dirAna+fBM);
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
					Table.set("Included Channels", row, "TBD");
					Table.set("Voxel Width (um)", row, "TBD");
					Table.set("Voxel Depth (um)", row, "TBD");
					Table.set("BB X0", row, "TBD");
					Table.set("BB X1", row, "TBD");
					Table.set("BB Y0", row, "TBD");
					Table.set("BB Y2", row, "TBD");      
					Table.set("NumberOfHairCells", row, "TBD");
					Table.set("PreSynXYZinROI", row, "TBD");
					Table.set("PostSynXYZinROI", row, "TBD");
					Table.set("PreSynSynapses", row, "TBD");
					Table.set("PostSynSynapses", row, "TBD");
					Table.set("PreSynDoublets", row, "TBD");
					Table.set("PostSynDoublets", row, "TBD");
					Table.set("PreSynGarbage", row, "TBD");
					Table.set("PostSynGarbage", row, "TBD");
					Table.set("PreSynWMarker", row, "TBD");
					Table.set("PostSynWMarker", row, "TBD");
					Table.update;
				}	
		    }
		}
		Table.save(dirAna+fBM);
	}
	return batchpath;
}

// ALLOW USER TO CHOOSE HOW TO PROCEED
function getUserChoice() {
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
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	ims = Table.getColumn("ImageName");
	// Get a list of images available to analyze
	filelist = getFileList(batchpath+"RawImages/");
	// Batch Mode Go 
	i = 0; // Counter for iterating through filelist from within the while-loop
	while (batch != "Stop") {
		// *** GO THROUGH THE STEPS OF VALIDATION THEN PROCEEDING WITH ANALYSIS ***
		// Verify that the image exists, has XYZ data, and then proceed with analysis
		// . from within the verification function <- I don't love this and want to restructure in the future.
		exists = imVerification(i, filelist[i], filelist, ims, batchpath);
		// If true, then the image file was not in RawImages when the macro was started 
		if (exists == "No") {
			// The Batch Master list needs to be updated. Easiest is to have the user restart. 
			print(filelist[i]+" is not registered with Batch Master.\n"+
				  "Recommend restarting the macro if you want to analyze this image.");
		}
		// Increment index to the next in filelist
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

// ANALYZE A SPECIFIC IMAGE CHOSEN BY THE USER
function runSpecific(batchpath){
	// Get the Batch Master list of images - This is how we will check if the 
	// . chosen image has already been initialized, etc.
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	ims = Table.getColumn("ImageName");
	// Get list of available files in the RawImages folder, just in case an image on Batch Master
	// . has been moved and is no longer available.
	filelist = getFileList(batchpath+"RawImages/");
	Dialog.create("Choose a file to analyze")
	Dialog.addChoice("Available Files", filelist);
	Dialog.show();
	file = Dialog.getChoice();
	// Verify that the image exists, has XYZ data, and then proceed with analysis
	exists = imVerification(0, file, filelist, ims, batchpath);
	// If true, then the image file was not in RawImages when the macro was started 
	if (exists == "No") {
		// The Batch Master list needs to be updated. Easiest is to have the user restart. 
		print(filelist[i]+" is not registered with Batch Master.\n"+
			  "Recommend restarting the macro if you want to analyze this image.");
	}
}

// VERIFY THAT THAT THE IMAGE IS VALID BEFORE CALLING ANALYSIS MODULE
// i = index of filename in filelist, filelist = all files in RawImages, ims = all images in Batch Master
// Can probably get rid of "i" but will need to double check that it doesn't break anything.
// I think I can drop filelist as well
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
					Table.save(batchpath+"SAR.Analysis/SynAnalyzerBatchMaster.csv");
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

// ***** MAIN FUNCTION FOR ANALYZING AN IMAGE *****
// PERFORM ANALYSIS OF ALL AVAILABLE XYZ DATASETS
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
	match = "No";
	// Check if the analysis has already been started
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	test = Table.getString("ZStart", imIndex);
	if (test != "TBD"){
		// Check if the user wants to repeat the initialization process
		Dialog.create("Check to proceed");
		Dialog.addString("Analysis has been initialized. Repeat initialization?", "No");
		Dialog.show();
		check = Dialog.getString();
		if (check == "Yes"){
			getAnalysisInfo(batchpath, imName, imIndex);
			match = verifyXYZMatch(batchpath, imName, fName[i], imIndex);
		}else{
			match="Yes";
		}
	}else{
		// Image analysis info has not been acquired yet
		getAnalysisInfo(batchpath, imName, imIndex);
		match = verifyXYZMatch(batchpath, imName, fName[i], imIndex);
	}
	// *** 2. ITERATE THROUGH AVAILABLE XYZ DATA SETS & GEN THUMBNAILS ***
	for (i = 0; i < ir; i++) {
		if (match == "Yes"){
			// 2.2 Generate thumbnails if the XYZ data matches
			//  but check if the user wants to repeat thumbnail generation if it was already done.
			if (File.exists(batchpath+"/SAR.Thumbnails/"+imName+"."+fName[i]+"/")){
				Dialog.create("Check to proceed");
				Dialog.addString("Thumbnails have been generated. Repeat thumbnail generation?", "No");
				Dialog.show();
				check = Dialog.getString();
				if (check == "Yes"){
					genThumbnails(batchpath, imName, fName[i], imIndex);
				}
			}else{
				genThumbnails(batchpath, imName, fName[i], imIndex);
			}
			// 2.3 Have the user analyze the array if analysis was sucessfuly completed
			//  but check if the user wants to repeat counting if it was already done.
			// Check if the analysis has already been started
			Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
			test = Table.getString(fName[i]+"Synapses", imIndex);
			if (test != "TBD"){
				Dialog.create("Check to proceed");
				Dialog.addString("Synapses have been counted. Repeat counting?", "No");
				Dialog.show();
				check = Dialog.getString();
				if (check == "Yes"){
					countSyns(batchpath, imName, fName[i], imIndex);
				}
			}else{
				countSyns(batchpath, imName, fName[i], imIndex);
			}
			// *** 3. PROCEED WITH PILLAR-MODIOLAR MAPPING FOR MATCHED DATASETS ***
			//  but check if the user wants to repeat counting if it was already done.
			// Check if the analysis has already been started
			if (File.exists(batchpath+"/SAR.PillarModiolarMaps/"+imName+".PMMap."+fName[i]+".png")){
				Dialog.create("Check to proceed");
				Dialog.addString("Pillar-modiolar mapping is complete. Repeat mapping?", "No");
				Dialog.show();
				check = Dialog.getString();
				if (check == "Yes"){
					complete = mapPillarModiolar(batchpath, imName, fName[i], imIndex);
					genSummaryImage(batchpath, batchpath, imName, fName[i]);
				}else {
					genSummaryImage(batchpath, batchpath, imName, fName[i]);
					// Check that these match before proceeding
					Dialog.create("Check");
					Dialog.addMessage("A new summary image has been generated.");
					Dialog.addString("Mark analysis as complete?", "Yes");
					Dialog.show();
					complete =  Dialog.getString();
				}
			}else{
				complete = mapPillarModiolar(batchpath, imName, fName[i], imIndex);
				genSummaryImage(batchpath, batchpath, imName, fName[i]);
			}
			j=i+1;
		}else{
			print("User decided XYZ data does not match."+
				  "Update the file and restarting macro before proceeding.");
			i=ir;
		}
	}
	if (j==ir) {
		if (complete == "Yes"){
			print("Analysis for "+imName+" is complete.");
			Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
			Table.set("Analyzed?",imIndex,complete);
			Table.update;
			Table.save(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
		}
	}
}
// ***** ANALYSIS RELATED FUNCTIONS *****
// GET INFORMATION ABOUT HOW TO ANALYZE THIS IMAGE
function getAnalysisInfo(batchpath, imName, imIndex){
	// Housekeeping
	roiManager("reset");
	// Open the image and get basic information
	open(batchpath+"RawImages/"+imName+".czi");
	getVoxelSize(vxW, vxH, vxD, unit);
	Stack.getDimensions(width, height, channels, slices, frames);
	// Allow the user to specify the channels to include
	waitForUser("Review the image and choose slices to include. Enter these values in the next dialog box");
	// Setup Checkbox group based on z-stack dimensions
	labels = newArray(channels);
	defaults = newArray(channels);
	for (i = 0; i < lengthOf(labels); i++) {
		// Channel indexing starts at 1
		labels[i] = "Channel "+toString(i+1);
		// One = box is checked, Zero = unchecked
		defaults[i] = 1;
	}
	// Setup and show the dialog box
	Dialog.create("Get Analysis Info");
	Dialog.addMessage("Indicate the pre- and post- synaptic channels to use for thumbnail generation\n"+
					  "and the slices to include in the analysis region.");
	Dialog.addCheckboxGroup(channels, 2, labels, defaults);
	Dialog.addString("Slice Start","1");
	Dialog.addString("Slice End", slices);
	Dialog.show();
	// Get the information from the dialog box
	inCount = 0;
	include = newArray(channels);
	for (i = 0; i < lengthOf(labels); i++) {
		// Count the number of channels to include
		if (Dialog.getCheckbox() == 1){
			inCount++;
			include[i] = "Yes";
		}else{
			include[i] = "No";
		}
	}
	slStart = Dialog.getString();
	slEnd = Dialog.getString();
	// Create an array that will be used to make the substack
	chToInclude = newArray(inCount);
	chCount = 0;
	for (i = 0; i < channels; i++) {
		if (include[i] == "Yes") {
			// Channel indexing starts at 1
			chToInclude[chCount] = i+1;
			chCount++;
		}
	}
	// Make an array of the channels to include
	chStrArr = "["+String.join(chToInclude)+"]";
	// Make & save a max proj to help user with visualizing surfaces based on inclusion criteria
	run("Make Substack...", "slices="+slStart+"-"+slEnd);
	run("Z Project...", "projection=[Max Intensity]");
	run("Make Composite");
	run("Flatten");
	save(batchpath+"SAR.RawMPIs/"+imName+".RawMPI.tif");
	selectImage(imName+".czi");
	close();
	selectImage(imName+"-1.czi");
	close();
	selectImage("MAX_"+imName+"-1.czi");
	close();
	// Have the user draw a rectangle around the region to analyze
	setTool("rectangle");
	waitForUser("Draw a rectangle around the hair cells to include in the analysis then press [t] to add to the ROI Manager.\n"+
				"Start with the upper left corner and move down and right across the image."+
				"Make sure the rectangle is still visible when pressing 'Ok' to proceed."+
				"Take note of the number of hair cells included in the analysis area.");
	// Get the coordinates for the rectangle
	Roi.getCoordinates(xpoints, ypoints);
	Roi.remove;
	// Have the user enter the number of hair cells included in the analysis
	Dialog.create("Get Analysis Info");
	Dialog.addMessage("Indicate the number of hair cells included in the analysis area.");
	Dialog.addNumber("Number of Inner Hair Cells", 10);
	Dialog.show();
	nHCs = Dialog.getNumber();
	// Update the Batch Master table
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	Table.set("ZStart", imIndex, slStart);
	Table.set("ZEnd", imIndex, slEnd);
	Table.set("Included Channels", imIndex, chStrArr);
	Table.set("Voxel Width (um)", imIndex, vxW);
	Table.set("Voxel Depth (um)", imIndex, vxD);
	Table.set("BB X0", imIndex, xpoints[0]);
	Table.set("BB X1", imIndex, xpoints[1]);
	Table.set("BB Y0", imIndex, ypoints[0]);
	Table.set("BB Y2", imIndex, ypoints[2]);
	Table.set("NumberOfHairCells", imIndex, nHCs);
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	close("*");
}

// VERIFY THAT THE XYZ POSITIONS MATCH THE IMAGE
function verifyXYZMatch(batchpath, imName, fName, imIndex){
	// Load the Batch Master to get the voxel dimensions
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	vxW = Table.get("Voxel Width (um)", imIndex);
	vxD = Table.get("Voxel Depth (um)", imIndex);
	// Open the substack MPI for labelling purposes
	open(batchpath+"SAR.RawMPIs/"+imName+".RawMPI.tif");
	// Load the raw XYZ points
	Table.open(batchpath+"XYZCSVs/"+imName+".XYZ."+fName+".csv");
	// Save a clean version of the XYZ file to add analysis info
	Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	// Iterate through the rows of the XYZ table and add points to image
	//  also adding converted positions in this step for ease 
	tableRows = Table.size;
	Table.sort("ID");
	for (i = 0; i < tableRows; i++) {
		id = Table.get("ID", i);
		xPos = (Table.get("Position X", i))*(1/vxW);
		yPos = (Table.get("Position Y", i))*(1/vxW);
		zPos = (Table.get("Position Z", i))*(1/vxD);
		Table.set("Position X (voxels)", i, xPos);
		Table.set("Position Y (voxels)", i, yPos);
		Table.set("Position Z (voxels)", i, zPos);
		Table.update;
		// Add an annotation to the MPI for verification purposes
		makePoint(xPos, yPos, "small yellow dot add");
		setFont("SansSerif",10, "antiliased");
	    setColor(255, 255, 255);
		drawString(id, xPos, yPos);
	}
	// Save the annotated raw MPI
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".RawMPI.AllXYZs."+fName+".png");
	Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	// Ask the user to verify that the XYZ data matches the image
	choiceArray = newArray("Yes", "No");
	Dialog.create("Checkin");
	Dialog.addRadioButtonGroup("Do these XYZ points match the image?", choiceArray, 2, 1, "Yes");
	Dialog.show();
	match = Dialog.getRadioButton();
	close("*");
	return match;
}

// GENERATE THUMBNAILS 
function genThumbnails(batchpath, imName, fName, imIndex) {
	// Setup subfolders for storing thumbnails associated with this image
	File.makeDirectory(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/");
	// Open the substack MPI for labelling purposes
	open(batchpath+"SAR.RawMPIs/"+imName+".RawMPI.tif");
	// Open the raw image
	open(batchpath+"RawImages/"+imName+".czi");
	// -- Subtract background from the entire z-stack
	run("Subtract Background...", "rolling=50 stack");
	// Get parameters for substack
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	chStrArr = Table.getString("Included Channels", imIndex);
	vxW = Table.get("Voxel Width (um)", imIndex);
	vxD = Table.get("Voxel Depth (um)", imIndex);
	slStart = Table.get("ZStart", imIndex);
	slEnd = Table.get("ZEnd", imIndex);
	bbXZ = Table.get("BB X0", imIndex);
	bbXO = Table.get("BB X1", imIndex);
	bbYZ = Table.get("BB Y0", imIndex);
	bbYT = Table.get("BB Y2", imIndex);
	// Generate a max projection composite image that will be labelled with points of interest
	run("Make Substack...", "channels="+chStrArr+" slices="+slStart+"-"+slEnd);
	selectImage(imName+".czi");
	close();
	// Allow the user to make any adjustments to the display properties before proceeding 
	waitForUser("Make any necessary adjustments to brightness/constrast, etc. before thumbnail generation begins.");
	// Load the XYZs
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	// Iterate through XYZs and perform cropping
	wbIn = 0; // counter for tracking the number of XYZs within bounds and cropped
	for (i = 0; i < Table.size; i++) {
		// Get the XYZ info
		// . X and Y should be in terms of voxels
		// . Z needs to be in the slice number
		id = Table.get("ID", i);
		xPos = Table.get("Position X (voxels)", i);
		yPos = Table.get("Position Y (voxels)", i);
		zPos = Table.get("Position Z (voxels)", i);
		slZ = round(zPos);
		//print(posX+" "+bbXZ+" "+bbXO+" "+posY+" "+bbYZ+" "+bbYT+" "+posZ+" "+slZ);
		// First verify that the XYZ is within the user defined main bounding box
		if ((xPos >= bbXZ) && (xPos <= bbXO)) {
			if ((yPos >= bbYZ) && (yPos <= bbYT)) {
				if ((slZ >= slStart) && (slZ <= slEnd)){
					// Update information to include the XYZ
					Table.set("XYZinROI?", i, "Yes");
					selectImage(imName+"-1.czi");
				    // Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
					cropX = xPos - ((tnW/vxW)/2);
					cropY = yPos - ((tnH/vxW)/2); 
					Table.set("CropX", i, cropX);
					Table.set("CropY", i, cropY);
					// Calculate and store the start and end slice numbers for the z-stack
					zSt = round(slZ-((tnZ/vxD)/2));
					zEnd = floor(slZ+((tnZ/vxD)/2));
					Table.set("ZStart", i, zSt);
					Table.set("ZEnd", i, zEnd);
					Table.update;
					// Make a max projection for just this XYZ
					run("Make Composite");
					run("Z Project...", "start="+toString(zSt)+" stop="+toString(zEnd)+" projection=[Max Intensity]");
					run("Flatten");
					// Crop the region around the XYX
				    //run("Specify...", "width="+tnW+" height="+tnH+" x="+cropX+" y="+cropY+" slice=1 scaled");
				    makeRectangle(cropX, cropY, (tnW/vxW), (tnH/vxW));
				    run("Crop");
				    // Add cross hairs for center
					setFont("SansSerif",3, "antiliased");
				    setColor(255, 255, 0);
					drawString(".", ((tnW/vxW)/2), ((tnW/vxW)/2));
				    //makePoint(((tnW/vxW)/2), ((tnW/vxW)/2), "tiny yellow cross add");
				    setFont("SansSerif",8, "antiliased");
				    setColor(255, 255, 255);
					drawString(id, 1, ((tnW/vxW)-1));
					// Make and save the maximum projection
					save(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/"+imName+".TN."+id+".png");
					// Close images
					close(imName+".TN."+id+".png");
					close("MAX_"+imName+"-1.czi");
					close("MAX_"+imName+"-2.czi");
					wbIn++;
					// Update the annotated MPI
					selectImage(imName+".RawMPI.tif");
					makePoint(xPos, yPos, "tiny yellow dot add");
					setFont("SansSerif",10, "antiliased");
				    setColor(255, 255, 255);
					drawString(id, xPos, yPos);
				}else{
					// XYZ is not within Z bounds
					Table.set("XYZinROI?", i, "No");
				}
			}else{
				// XYZ is not within Y bounds
				Table.set("XYZinROI?", i, "No");
			}
		}else{
			// XYZ is not within X bounds
			Table.set("XYZinROI?", i, "No");
		}
	}
	// Save the XYZ data
	Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	// Save the annotated MPI
	selectImage(imName+".RawMPI.tif");
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName+".png");
	makeRectangle(bbXZ, bbYZ, bbXO-bbXZ, bbYT-bbYZ);
	run("Draw", "slice");
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName+".png");
	// Generate the thumbnail array
	close(imName+"-1.czi");
	File.openSequence(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/");
	nRows = -floor(-(wbIn/10));
	run("Make Montage...", "columns=10 rows="+nRows+" scale=5");
	save(batchpath+"SAR.SynArrays/"+imName+".SynArray."+fName+".png");
	close("*");
	// Update Batch Master with number of XYZs in the ROI
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	Table.set(fName+"XYZinROI", imIndex, wbIn);
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	
}

// WALK THE USER THROUGH COUNTING SYNAPSES ON AN ARRAY
function countSyns(batchpath, imName, fName, imIndex) {
	// Open the array file
	open(batchpath+"SAR.SynArrays/"+imName+".SynArray."+fName+".png");
	// Create a dialog box for the user to enter values
	Dialog.create("SynAnalyzer");
	Dialog.addMessage("Review the synapse array and enter information for each category below:");
	Dialog.addNumber("Number of doublets", 0);
	Dialog.addNumber("Number of orphans", 0);
	Dialog.addNumber("Number of garbage XYZs", 0);
	Dialog.addNumber("Number of synapses with marker", 0);
	Dialog.show();
	nDs = Dialog.getNumber();
	nOs = Dialog.getNumber();
	nGs = Dialog.getNumber();
	nWM = Dialog.getNumber();
	// Open Batch Master and add information 
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	Table.set(fName+"Doublets", imIndex, nDs);
	Table.set(fName+"Orphans", imIndex, nOs);
	Table.set(fName+"Garbage", imIndex, nGs);
	Table.set(fName+"WMarker", imIndex, nWM);
	// Calculate the number of synapses based on information given
	nT = Table.get(fName+"XYZinROI", imIndex);
	nSyn = nT-nOs-nGs;
	Table.set(fName+"Synapses", imIndex, nSyn);
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	close(imName+".SynArray."+fName+".png");
}

// MAP PILLAR-MODIOLAR POSITIONS FOR ALL XYZs within ROI 
function mapPillarModiolar(batchpath, imName, fName, imIndex){
	close("*");
	// Get the information about the ROI 
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	xSt = Table.get("BB X0", imIndex);
	xEnd = Table.get("BB X1", imIndex);
	zSt = Table.get("ZStart", imIndex);
	zEnd = Table.get("ZEnd", imIndex);
	// Open the raw image
	open(batchpath+"RawImages/"+imName+".czi");
	getDimensions(width, height, channels, slices, frames);
	getVoxelSize(vW, vH, vD, unit);
	// Crop the z-stack accordingly
	//setTool("rectangle");
	//drawRect(xSt, 0, xEnd-xSt, height);
	makeRectangle(xSt, 0, xEnd-xSt, height);
	//roiManager("add");
	run("Crop");
	//Roi.remove;
	// Make the ortho projection
	run("Reslice [/]...", "output="+vD+" start=Left flip");
	run("Z Project...", "projection=[Max Intensity]");
	run("Make Composite");
	getPixelSize(unit, pixW, pixH);
	run("Flatten");
	// Close unused images
	close("\\Others");
	// Have the user draw the p-m axis
	setTool("line");
	waitForUser("Draw the pillar-modilar axis across the\nbasolateral region of the hair cell.\n"+
				"Make sure that the line is still visible before closing this window.");
	getLine(x1, y1, x2, y2, lineWidth);
	getDimensions(width, height, channels, slices, frames);
	// Find the midpoint of the line
	xMid = (x1+x2)/2;
	yMid = (y1+y2)/2;
	// Find the equation of the line
	slope = (y2-y1)/(x2-x1);
	int = y1-(slope*x1);
	// Find the equation of the perpendicular line
	pSlope = -1/slope;
	pInt = yMid-(pSlope*xMid);
	// Get the start and end points for the perpendicular line
	xSt = 0;
	xEnd = width;
	ySt = pInt;
	yEnd = (pSlope*xEnd)+pInt;
	// Add annotations to the image
	makePoint(xMid, yMid, "small yellow hybrid add");
	setLineWidth(3);
	setColor("yellow");
	drawLine(x1, y1, x2, y2);
	setColor("cyan");
	drawLine(xSt, ySt, xEnd, yEnd);
	// Iterate through the XYZs and assign P-M status based on position above or below the 
	// . the apical-basal axis. 
	// Open the Batch Master to get the number of valid XYZs
	//Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	//nXYZs = Table.get(fName+"XYZinROI",imIndex);
	// Open the XYZ data
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	nXYZs = Table.size;
	for (i = 0; i < nXYZs; i++) {
		// Check if the XYZ should be included
		valid = Table.getString("XYZinROI?", i);
		if (valid == "Yes") {
			id = Table.get("ID", i);
			// New coordinate system means original x-coords are now y
			// . will need to add info in Readme about this
			xPos = Table.get("Position Y (voxels)", i);
			// The y-coord is weird because it was z-coord prior to the transformation
			//  and the reslicing generates pixels in the new y-direction using interpolation.
			// . So now thew new y-coordinate has to be scaled and subracted from the total image height. 
			yPos = height-(Table.get("Position Z", i))/pixH;
			// Now we determine if it's above or below the AB-axis
			if (yPos > ((pSlope*xPos)+pInt)) {
				// Add an annotation to the MPI for verification purposes
				makePoint(xPos, yPos, "medium yellow dot add");
				setFont("SansSerif",8, "antiliased");
			    setColor(255, 255, 255);
				drawString(id, xPos, yPos);
				Table.set("PMStatus", i, "Pillar");
			}else{
				// Add an annotation to the MPI for verification purposes
				makePoint(xPos, yPos, "medium cyan dot add");
				setFont("SansSerif",8, "antiliased");
			    setColor(255, 255, 255);
				drawString(id, xPos, yPos);
				Table.set("PMStatus", i, "Modiolar");
			}
		}
		else {
			Table.set("PMStatus", i, "Invalid XYZ");
		}
	}
	// Check that these match before proceeding
	Dialog.create("Check");
	Dialog.addString("Mark analysis as complete?", "Yes");
	Dialog.show();
	complete =  Dialog.getString();
	// Only save the map if complete is "Yes"
	if (complete == "Yes"){
		// Save the annotated image
		save(batchpath+"/SAR.PillarModiolarMaps/"+imName+".PMMap."+fName+".png");
		close("*");
	}

	return complete
}

// Generate a summary image that has the main components from the analysis
function genSummaryImage(batchpath, batchpath, imName, fName){
	// Open the two MPIs and create a montage of those two first 
	open(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName+".png");
	getDimensions(width, height, channels, slices, frames);
	open(batchpath+"SAR.AnnotatedMPIs/"+imName+".RawMPI.AllXYZs."+fName+".png");
	getDimensions(width, height, channels, slices, frames);
	run("Images to Stack", "method=[Copy (top-left)] use");
	run("Make Montage...", "columns=1 rows=2 scale=1 label");
	// Need to save the montage as is, close it, then reopen it later
	// Open the synapse array and the PM map. Turn these two into a montage
	open("WSS_029.02.T3.01.Zs.4C.SynArray.PreSyn.png");
	open("WSS_029.02.T3.01.Zs.4C.PMMap.PreSyn.png");
	run("Images to Stack", "method=[Copy (center)] use");
	run("Make Montage...", "columns=1 rows=2 scale=1");
	// Now reopen the first montage and make the two into one. 
}
