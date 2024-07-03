/*
 * SynAnalyzer.ijm
 * Created by JFranco, 02 JUL 2024
 * Last update: 03 JUL 2024
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
// *** USER PRESETS ***
// Default batch path
defBP = "/Users/joyfranco/Partners HealthCare Dropbox/Joy Franco/JF_Shared/Data/CodeDev/SynAnalyzerBatch/";
// Thumbnail bounding box dimesions in um
tnW = 1.5;
tnH = 1.5;
tnZ = 1.5;

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
	dirSI = batchpath+"SAR.SummaryImages/";
	dirSA = batchpath+"SAR.SynArrays/";
	dirPM = batchpath+"SAR.PillarModiolarMaps/";
	dirAM = batchpath+"SAR.AnnotatedMPIs/";
	dirPA = batchpath+"SAR.POIAnnotations/";            // Point of interest annotations - stores CSV of details for each surface
	dirSM = batchpath+"SAR.SubstackMPIs/";
	dirTN = batchpath+"SAR.Thumbnails/";
	fBM = "SynAnalyzerBatchMaster.csv";
	
	// *** GET LIST OF BATCH IMAGES ***
	filelist = getFileList(dirIms);
	
	// *** CREATE SUBFOLDERS IF THEY DO NOT EXIST ***
	if (!File.isDirectory(dirSI)) {
		File.makeDirectory(dirSI);
		File.makeDirectory(dirSA);
		File.makeDirectory(dirPM);
		File.makeDirectory(dirAM);
		File.makeDirectory(dirSM);
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
					Table.set("Included Channels", row, "TBD");
					Table.set("Voxel Width (um)", row, "TBD");
					Table.set("Voxel Depth (um)", row, "TBD");
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
	//getAnalysisInfo(batchpath, imName, imIndex);
	
	// *** 2. ITERATE THROUGH AVAILABLE XYZ DATA SETS ***
	for (i = 0; i < ir; i++) {
		//2.1. Verify that the XYZs seem to match the image
		match = verifyXYZMatch(batchpath, imName, fName[i], imIndex);
		if (match == "Yes"){
			//2.2 Generate thumbnails if the XYZ data matches
			analyzed = genThumbnails(batchpath, imName, fName[i], imIndex);
		}else{
			print("User decided XYZ data does not match. Suggest updating file and restarting macro.")
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
	vxW = vxW+(0.0005);
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
	Dialog.addMessage("Indicate the channels and slices to include in the analysis.");
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
	run("Make Substack...", "channels="+chStrArr+" slices="+slStart+"-"+slEnd);
	run("Z Project...", "projection=[Max Intensity]");
	run("Make Composite");
	run("Flatten");
	save(batchpath+"SAR.SubstackMPIs/"+imName+".SubstackMPI.tif");
	selectImage(imName+".czi");
	close();
	selectImage(imName+"-1.czi");
	close();
	selectImage("MAX_"+imName+"-1.czi");
	close();
	// Have the user draw a rectangle around the region to analyze
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
	Table.open(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
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
	Table.save(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
	close("*");
}

// VERIFY THAT THE XYZ POSITIONS MATCH THE IMAGE
function verifyXYZMatch(batchpath, imName, fName, imIndex){
	// Load the Batch Master to get the voxel dimensions
	Table.open(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
	vxW = Table.get("Voxel Width (um)", imIndex);
	vxD = Table.get("Voxel Depth (um)", imIndex);
	// Open the substack MPI for labelling purposes
	open(batchpath+"SAR.SubstackMPIs/"+imName+".SubstackMPI.tif");
	// Load the XYZ points
	Table.open(batchpath+"XYZCSVs/"+imName+".XYZ."+fName+".csv");
	// Iterate through the rows of the XYZ table and add points to image
	//  also adding converted positions in this step for ease 
	tableRows = Table.size;
	Table.sort("ID");
	for (i = 0; i < tableRows; i++) {
		xPos = (Table.get("Position X", i))*(1/vxW);
		yPos = (Table.get("Position Y", i))*(1/vxW);
		zPos = (Table.get("Position Z", i))*(1/vxD);
		Table.set("Position X (voxels)", i, xPos);
		Table.set("Position Y (voxels)", i, yPos);
		Table.set("Position Z (voxels)", i, zPos);
		Table.update;
		makePoint(xPos, yPos, "small yellow hybrid");
		roiManager("Add");
	}
	Table.save(batchpath+"XYZCSVs/"+imName+".XYZ."+fName+".csv");
	roiManager("show all with labels");
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
	// Open the raw image
	open(batchpath+"RawImages/"+imName+".czi");
	// -- Subtract background from the entire z-stack
	run("Subtract Background...", "rolling=50 stack");
	// Get parameters for substack
	Table.open(batchpath+"/Metadata/"+"SynAnalyzerBatchMaster.csv");
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
	run("Make Substack...", "channels="+chStrArr);
	selectImage(imName+".czi");
	close();
	// Allow the user to make any adjustments to the display properties before proceeding 
	waitForUser("Make any necessary adjustments to brightness/constrast, etc. before thumbnail generation begins.");
	// Load the XYZs
	Table.open(batchpath+"XYZCSVs/"+imName+".XYZ."+fName+".csv");
	// Setup the arrays for indexing the XYZ
	nRows = -floor(-(Table.size/10));
	arrLet = newArray("A","B","C","D","E","F","G","H","I","J","K");
	arrNum = newArray(nRows);
	for (i = 0; i < nRows; i++) {
		arrNum[i]=i+1;
	}
	// Iterate through each XYZ, assign an index, make/save thumbnail, update XYZ table
	inL = 0;
	inN = 0;
	for (i = 0; i < Table.size; i++) {
		if (inL == lengthOf(arrLet)) {
			inL = 0;
			inN++;
		}
		inXYZ = arrLet[inL]+toString(arrNum[inN]);
		// Get the XYZ info
		// . X and Y should be in terms of voxels
		// . Z needs to be in the slice number
		posX = Table.get("Position X (voxels)", i);
		posY = Table.get("Position Y (voxels)", i);
		posZ = Table.get("Position Z (voxels)", i);
		slZ = round(posZ);
		//print(posX+" "+bbXZ+" "+bbXO+" "+posY+" "+bbYZ+" "+bbYT+" "+posZ+" "+slZ);
		// First verify that the XYZ is within the user defined main bounding box
		if ((posX >= bbXZ) && (posX <= bbXO)) {
			if ((posY >= bbYZ) && (posY <= bbYT)) {
				if ((slZ >= slStart) && (slZ <= slEnd)){
				// Set the index for this XYZ
				Table.set("XYZ_Index",i,inXYZ);
				selectImage(imName+"-1.czi");
			    // Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
				cropX = posX - (tnW/vxW);
				cropY = posY - (tnH/vxW); 
				Table.set("CropX", i, cropX);
				Table.set("CropY", i, cropY);
				// Calculate and store the start and end slice numbers for the z-stack
				zSt = round(slZ-(tnZ/2));
				zEnd = round(slZ+(tnZ/2));	
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
				 // Make and save the maximum projection
				saveAs("PNG", batchpath+"SAR.Thumbnails/"+imName+".TN."+inXYZ+".png");
				close(imName+".TN."+inXYZ+".png");
				close();
				}
			}
		}
		inL++;
	}
	Table.save(batchpath+"XYZCSVs/"+imName+".XYZ."+fName+".csv");
	return analyzed
}
