/*
 * SynAnalyzer.ijm
 * Created by JFranco, 02 JUL 2024
 * Last update: 15 JUL 2024
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
defBP = "/Users/joyfranco/Partners HealthCare Dropbox/Joy Franco/JF_Shared/Data/WSS/BatchAnalysis/SynAnalysis_BclwSNHL_NeonatalAAV/";
// Thumbnail bounding box dimesions in um
tnW = 3;
tnH = 3;
tnZ = 1.5;
// Annotated Image Size - Currently based on the output width of the SynArray
annImW = 1650;

// *** HOUSEKEEPING ***
run("Close All");
run("Labels...", "color=white font=12 show use draw bold");
close("*.csv");

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
	}else if (choice == "Specific Image") {
		// Specific Image mode allows the user to select a specific image and only analyzes that one.
		runSpecific(batchpath);
	}else if (choice == "Specific Task") {
		// Allows the user to complete one task for an existing dataset
		specificTask(batchpath);
	}
	choice = getUserChoice();
	close("*");
	close("*.csv");
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
	if (!File.isDirectory(dirAna)) {
		File.makeDirectory(dirAna);
		File.makeDirectory(dirSI);
		File.makeDirectory(dirSA);
		File.makeDirectory(dirPM);
		File.makeDirectory(dirAM);
		File.makeDirectory(dirRM);
		File.makeDirectory(dirTN);
		
		// *** SETUP BATCH MASTER RESULTS TABLE ***
		// FUTURE WORK: TURN THIS INTO A FOR LOOP THAT ITERATES THROUGH ARRAY WITH COLUMN NAMES
		Table.create("SynAnalyzerBatchMaster.csv");
		for (i = 0; i < lengthOf(filelist); i++) {
		    if (endsWith(filelist[i], ".czi")) { 
		        Table.set("ImageName", i, filelist[i]);
				Table.set("Analyzed?", i, "No");
				Table.set("AvailXYZData", i, "TBD");
				Table.set("ZStart", i, "TBD");
				Table.set("ZEnd", i, "TBD");
				Table.set("Synaptic Marker Channels", i, "TBD");
				Table.set("Terminal Marker Channels", i, "TBD");
				Table.set("Pillar-Modiolar Marker Channels", i, "TBD");
				Table.set("Voxel Width (um)", i, "TBD");
				Table.set("Voxel Depth (um)", i, "TBD");
				Table.set("BB X0", i, "TBD");
				Table.set("BB X1", i, "TBD");
				Table.set("BB Y0", i, "TBD");
				Table.set("BB Y2", i, "TBD");
				Table.set("NumberOfHairCells", i, "TBD");
				Table.set("PreSynXYZinROI", i, "TBD");
				Table.set("PostSynXYZinROI", i, "TBD");
				Table.set("PreSyn_nSynapses", i, "TBD");
				Table.set("PreSyn_Synapses", i, "TBD");
				Table.set("PostSyn_nSynapses", i, "TBD");
				Table.set("PostSyn_Synapses", i, "TBD");
				Table.set("PreSyn_nDoublets", i, "TBD");
				Table.set("PreSyn_Doublets", i, "TBD");
				Table.set("PostSyn_nDoublets", i, "TBD");
				Table.set("PostSyn_Doublets", i, "TBD");
				Table.set("PreSyn_nOrphans", i, "TBD");
				Table.set("PreSyn_Orphans", i, "TBD");
				Table.set("PostSyn_nOrphans", i, "TBD");
				Table.set("PostSyn_Orphans", i, "TBD");
				Table.set("PreSyn_nGarbage", i, "TBD");
				Table.set("PreSyn_Garbage", i, "TBD");
				Table.set("PostSyn_nGarbage", i, "TBD");
				Table.set("PostSyn_Garbage", i, "TBD");
				Table.set("PreSyn_nUnclear", i, "TBD");
				Table.set("PreSyn_Unclear", i, "TBD");
				Table.set("PostSyn_nUnclear", i, "TBD");
				Table.set("PostSyn_Unclear", i, "TBD");
				Table.set("PreSyn_nWMarker", i, "TBD");
				Table.set("PreSyn_WMarker", i, "TBD");
				Table.set("PostSyn_nWMarker", i, "TBD");
				Table.set("PostSyn_WMarker", i, "TBD");
				Table.set("PreSyn_nPillar", i, "TBD");
				Table.set("PreSyn_nPModiolar", i, "TBD");
				Table.set("PostSyn_nPillar", i, "TBD");
				Table.set("PostSyn_nPModiolar", i, "TBD");
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
				// FUTURE WORK: TURN THIS INTO A FOR LOOP THAT ITERATES THROUGH ARRAY WITH COLUMN NAMES
				if (bool == "False") {
					row = Table.size;
					Table.set("ImageName",row, filelist[i]);
					Table.set("Analyzed?", row, "No");
					Table.set("ZStart", row, "TBD");
					Table.set("ZEnd", row, "TBD");
					Table.set("Synaptic Marker Channels", row, "TBD");
					Table.set("Terminal Marker Channels", row, "TBD");
					Table.set("Pillar-Modiolar Marker Channels", i, "TBD");
					Table.set("Voxel Width (um)", row, "TBD");
					Table.set("Voxel Depth (um)", row, "TBD");
					Table.set("BB X0", row, "TBD");
					Table.set("BB X1", row, "TBD");
					Table.set("BB Y0", row, "TBD");
					Table.set("BB Y2", row, "TBD");      
					Table.set("NumberOfHairCells", row, "TBD");
					Table.set("PreSynXYZinROI", row, "TBD");
					Table.set("PostSynXYZinROI", row, "TBD");
					Table.set("PreSyn_nSynapses", row, "TBD");
					Table.set("PreSyn_Synapses", row, "TBD");
					Table.set("PostSyn_nSynapses", row, "TBD");
					Table.set("PostSyn_Synapses", row, "TBD");
					Table.set("PreSyn_nDoublets", row, "TBD");
					Table.set("PreSyn_Doublets", row, "TBD");
					Table.set("PostSyn_nDoublets", row, "TBD");
					Table.set("PostSyn_Doublets", row, "TBD");
					Table.set("PreSyn_nOrphans", row, "TBD");
					Table.set("PreSyn_Orphans", row, "TBD");
					Table.set("PostSyn_nOrphans", row, "TBD");
					Table.set("PostSyn_Orphans", row, "TBD");
					Table.set("PreSyn_nGarbage", row, "TBD");
					Table.set("PreSyn_Garbage", row, "TBD");
					Table.set("PostSyn_nGarbage", row, "TBD");
					Table.set("PostSyn_Garbage", row, "TBD");
					Table.set("PreSyn_nUnclear", row, "TBD");
					Table.set("PreSyn_Unclear", row, "TBD");
					Table.set("PostSyn_nUnclear", row, "TBD");
					Table.set("PostSyn_Unclear", row, "TBD");
					Table.set("PreSyn_nWMarker", row, "TBD");
					Table.set("PreSyn_WMarker", row, "TBD");
					Table.set("PostSyn_nWMarker", row, "TBD");
					Table.set("PostSyn_WMarker", row, "TBD");
					Table.set("PreSyn_nPillar", row, "TBD");
					Table.set("PreSyn_nPModiolar", row, "TBD");
					Table.set("PostSyn_nPillar", row, "TBD");
					Table.set("PostSyn_nPModiolar", row, "TBD");
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
	choiceArray = newArray("Batch", "Specific Image", "Specific Task", "EXIT");
	Dialog.create("SynAnalyzer GetChoice");
	Dialog.addMessage("Choose analysis mode:");
	Dialog.addRadioButtonGroup("Choices",choiceArray, 4, 1, "Batch");
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
		if (exists != "Skip"){
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

// PERFORM A SPECIFIC TASK
//   This function is being added so that a user could repeat a specific portion of analysis process on an existing dataseet
function specificTask(batchpath){
	// *** ASK THE USER WHAT THEY WANT TO TASK THEY WANT TO PERFORM ***
	// This function is a work in progress and new tasks will be added as they become necessary
	choiceArray = newArray("Pillar-Modiolar Mapping");
	Dialog.create("SynAnalyzer GetChoice");
	Dialog.addMessage("Choose analysis mode:");
	Dialog.addRadioButtonGroup("Choices",choiceArray, 1, 1, "Pillar-Modiolar Mapping");
	Dialog.show();
	choice = Dialog.getRadioButton();
	// Open batch master and begin iterating through registered images
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	nIms = Table.size;
	close("*.csv");
	if (choice == "Pillar-Modiolar Mapping") {
		// Check if the user wants to repeat the initialization process
		Dialog.create("Get Analysis Info");
		Dialog.addString("Specify XYZ data set to use for mapping:", "PreSyn");
		Dialog.addString("Specify the channel to use for PM Mapping:", "3");
		Dialog.show();
		fName = Dialog.getString();
		pmCh = Dialog.getString();
	}
	for (imIndex = 0; imIndex < nIms; imIndex++) {
		Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
		pmDone = Table.getString("Pillar-Modiolar Marker Channels", imIndex);
		if (pmDone == "Not Included"){
			imName = Table.getString("ImageName", imIndex);
			imName = replace(imName, ".czi", "");
			Table.set("Pillar-Modiolar Marker Channels", imIndex, "["+pmCh+"]");
			Table.update;
			Table.save(batchpath+"SAR.Analysis/SynAnalyzerBatchMaster.csv");
			close("*.csv");
			mapPillarModiolar(batchpath, imName, fName, imIndex);
			// Check if the user wants to continue
			Dialog.create("Get Analysis Info");
			Dialog.addString("Continue with pillar-modiolar mapping for the next image?", "Yes");
			Dialog.show();
			choice = Dialog.getString();
			if (choice == "No"){
				exit;
			}
		}
	}
}

// VERIFY THAT THAT THE IMAGE IS VALID BEFORE CALLING ANALYSIS MODULE
// i = index of filename in filelist, filelist = all files in RawImages, ims = all images in Batch Master
// Can probably get rid of "i" but will need to double check that it doesn't break anything.
// I think I can drop filelist as well
function imVerification(i, filename, filelist, ims, batchpath){
	// Update the user about the analysis stage
	//waitForUser("Proceeding with Image Verification");
	// Ensure that the Batch Master is open and available
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
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
				analyBool = Table.getString("PreSyn_nSynapses", j);
				// If the image hasn't been analyzed, check that it has XYZs available
				if (analyBool == "TBD"){
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
					exists = "Check again";
				}else{
					exists = "Skip";
					/*
					Dialog.create("Check to proceed");
					Dialog.addString("Image has been analyzed. Repeat the process?", "No");
					Dialog.show();
					check = Dialog.getString();
					if (check == "Yes"){
						// Update information about the analysis for this image
						Table.set("Analyzed?", j, "No");
						Table.update;
						Table.save(batchpath+"SAR.Analysis/SynAnalyzerBatchMaster.csv");
						j=j-1;
					}else{
						print("User opted to skip re-analysis. Returning to menu.");
					}
					*/
				}
			}
		}
    }
    return exists;
}

// ***** MAIN FUNCTION FOR ANALYZING AN IMAGE *****
// PERFORM ANALYSIS OF ALL AVAILABLE XYZ DATASETS
function analyzeIm(batchpath, imName, adXYZ, imIndex){
	// Update the user about the analysis stage
	//waitForUser("Image & XYZ datasets have been verified. Proceeding with analysis for "+imName);
	// *** SET THE NUMBER OF ITERRUNS BASED ON DATA ***
	if (adXYZ == "Both Pre- and Post-") {
		ir = 2;
		fName = newArray("PreSyn","PostSyn");
	}else {
		ir = 1;
		if (adXYZ=="Only Pre-"){
			fName = newArray("PreSyn");
		}else{
			fName = newArray("PostSyn");
		}
	}
	// *** 1. OPEN THE IMAGE AND GET KEY INFO ***
	// Check if the analysis has already been started
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	anaInChk = Table.getString("ZStart", imIndex);
	close("*.csv");
	if (anaInChk != "TBD"){
		// Check if the user wants to repeat the initialization process
		Dialog.create("Check to proceed");
		Dialog.addString("Analysis has been initialized. Repeat initialization?", "No");
		Dialog.show();
		check = Dialog.getString();
		if (check == "Yes"){
			getAnalysisInfo(batchpath, imName, imIndex);	
		}
	}else{
		// Image analysis info has not been acquired yet
		getAnalysisInfo(batchpath, imName, imIndex);
	}
	// *** 2. ITERATE THROUGH AVAILABLE XYZ DATA SETS & GEN THUMBNAILS ***
	for (i = 0; i < ir; i++) {
		// Reset variable for verifying XYZ data match
		match = "No";
		//   Generate thumbnails if the XYZ data matches
		//     but check if the user wants to repeat thumbnail generation if it was already done.
		if (File.exists(batchpath+"/SAR.Thumbnails/"+imName+"."+fName[i]+"/")){
			Dialog.create("Check to proceed");
			Dialog.addString("Thumbnails have been generated. Repeat thumbnail generation?", "No");
			Dialog.show();
			check = Dialog.getString();
			if (check == "Yes"){
				match = verifyXYZMatch(batchpath, imName, fName[i], imIndex);
				if (match == "Yes"){
					genThumbnails(batchpath, imName, fName[i], imIndex);
				}
			}
			Dialog.create("Check to proceed");
			Dialog.addString("Arrays have been generated. Repeat array generation?", "Yes");
			Dialog.show();
			check = Dialog.getString();
			if (check == "Yes"){
				genArrays(batchpath, imName, fName[i], imIndex);
			}
		}else{
			match = verifyXYZMatch(batchpath, imName, fName[i], imIndex);
			if (match == "Yes"){
				genThumbnails(batchpath, imName, fName[i], imIndex);
				genArrays(batchpath, imName, fName[i], imIndex);
			}
		}
		
		
		// 2.3 Count Synapses from Arrays
		Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
		synAnaChk = Table.getString(fName[i]+"_nSynapses", imIndex);
		close("*.csv");
		if (synAnaChk != "TBD"){
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
		
		// PILLAR-MODIOLAR MAPPING
		Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
		pmAnaChk = Table.getString("Pillar-Modiolar Marker Channels", imIndex);
		print(pmAnaChk);
		close("*.csv");
		if (pmAnaChk != "Not Included"){
			if (File.exists(batchpath+"/SAR.PillarModiolarMaps/"+imName+".PMMap."+fName[i]+".png")){
				Dialog.create("Check to proceed");
				Dialog.addString("Pillar-modiolar mapping is complete. Repeat mapping?", "No");
				Dialog.show();
				check = Dialog.getString();
				if (check == "Yes"){
					mapPillarModiolar(batchpath, imName, fName[i], imIndex);
				}
			}else{
				mapPillarModiolar(batchpath, imName, fName[i], imIndex);
			}
		}
		j=i+1;
	}
	// ANALYZE AFFERENT TERMINALS ***
	// Check if the user indicated they wanted to analyze terminals during the initialization step
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	terAnaChk = Table.getString("Terminal Marker Channels", imIndex);
	close("*.csv");
	if (terAnaChk != "NA") {
		// Check if terminals have already been analyzed and check if the user wants to repeat
		if (File.isDirectory(batchpath+"/SAR.Thumbnails/"+imName+".Terminals/")){
			Dialog.create("Check to proceed");
			Dialog.addString("Terminals thumbnails have been generated and analyzed. Repeat process?", "No");
			Dialog.show();
			check = Dialog.getString();
			if (check == "Yes"){
				countTerMarker(batchpath, imName, imIndex);	
			}
		}else{
			countTerMarker(batchpath, imName, imIndex);	
		}
	}
	
	// Check if all XYZ datasets have been analyzed and if so mark analysis as complete
	if (j==ir) {
		/*
		// Ask the user if they want to mark the analysis complete 
		Dialog.create("Check");
		Dialog.addString("All available synaptic marker XYZ sets have been analyzed.\n"+
						 "Mark analysis as complete?", "No");
		Dialog.show();
		complete =  Dialog.getString();
		if (complete == "Yes"){
			print("Analysis for "+imName+" is complete.");
			Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
			Table.set("Analyzed?",imIndex,complete);
			Table.update;
			Table.save(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
			//close("*.csv");
			genSummaryImage(batchpath, imName, imIndex);
		}
		*/
	}
}
// ***** ANALYSIS RELATED FUNCTIONS *****
// GET INFORMATION ABOUT HOW TO ANALYZE THIS IMAGE
function getAnalysisInfo(batchpath, imName, imIndex){
	// Update the user about the analysis stage
	//waitForUser("Follow the prompts to add analysis parameters.");
	// Housekeeping
	roiManager("reset");
	// Open the image and get basic information
	open(batchpath+"RawImages/"+imName+".czi");
	getVoxelSize(vxW, vxH, vxD, unit);
	Stack.getDimensions(width, height, channels, slices, frames);
	// Open the Batch Master table
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	Table.set("Voxel Width (um)", imIndex, vxW);
	Table.set("Voxel Depth (um)", imIndex, vxD);
	Table.update;
	// SPECIFY SYNAPTIC MARKER CHANNELS
	//waitForUser("Review the image and choose slices to include. Enter these values in the next dialog box");
	// Setup Checkbox Group to use in dialog box based on the image information
	labels = newArray(channels);
	defaults = newArray(channels);
	for (i = 0; i < lengthOf(labels); i++) {
		// Channel indexing starts at 1
		labels[i] = "Channel "+toString(i+1);
		// One = box is checked, Zero = unchecked
		defaults[i] = 0;
		if ((i==0) || (i==3)){
			defaults[i]=1;
		}
	}
	// Ask the user to specify the synaptic marker channels
	Dialog.create("Get Analysis Info");
	Dialog.addMessage("Indicate the pre- and post- synaptic channels\n"+
					  "and the slices to include in the analysis region.");
	Dialog.addCheckboxGroup(channels, 2, labels, defaults);
	Dialog.addString("Slice Start","1");
	Dialog.addString("Slice End", slices);
	Dialog.show();
	//   Get the information from the dialog box
	synChCount = 0;
	include = newArray(channels);
	for (i = 0; i < lengthOf(labels); i++) {
		// Count the number of channels to include
		if (Dialog.getCheckbox() == 1){
			synChCount++;
			include[i] = "Yes";
		}else{
			include[i] = "No";
		}
	}
	// Make an array of the channels to include
	synCh = newArray(synChCount);
	chCount = 0;
	for (i = 0; i < channels; i++) {
		if (include[i] == "Yes") {
			// Channel indexing starts at 1
			synCh[chCount] = i+1;
			chCount++;
		}
	}
	synChArr = "["+String.join(synCh)+"]";
	Table.set("Synaptic Marker Channels", imIndex, synChArr);
	Table.update;
	// Get the information about which slices to include
	slStart = Dialog.getString();
	slEnd = Dialog.getString();
	Table.set("ZStart", imIndex, slStart);
	Table.set("ZEnd", imIndex, slEnd);
	Table.update;
	// SPECIFY AFFERENT TERMINAL MARKERS
	for (i = 0; i < lengthOf(labels); i++) {
		// Channel indexing starts at 1
		labels[i] = "Channel "+toString(i+1);
		// One = box is checked, Zero = unchecked
		defaults[i] = 0;
		if (i==1){
			defaults[i]=1;
		}
	}
	Dialog.create("Get Analysis Info");
	Dialog.addString("Include terminal marker in analysis?", "No");
	Dialog.addMessage("If applicable, indicate the channels to use for afferent terminal marker analysis.");
	Dialog.addCheckboxGroup(channels, 2, labels, defaults);
	Dialog.show();
	terCheck = Dialog.getString();
	if (terCheck == "Yes"){
		//   Get the information from the dialog box
		terChCount = 0;
		include = newArray(channels);
		for (i = 0; i < lengthOf(labels); i++) {
			// Count the number of channels to include
			if (Dialog.getCheckbox() == 1){
				terChCount++;
				include[i] = "Yes";
			}else{
				include[i] = "No";
			}
		}
		// Make an array of the channels to include
		terCh = newArray(terChCount);
		chCount = 0;
		for (i = 0; i < channels; i++) {
			if (include[i] == "Yes") {
				// Channel indexing starts at 1
				terCh[chCount] = i+1;
				chCount++;
			}
		}
		terChArr = "["+String.join(terCh)+"]";
		Table.set("Terminal Marker Channels", imIndex, terChArr);
		Table.update;
	}else{
		Table.set("Terminal Marker Channels", imIndex, "NA");
		Table.update;
	}
	// SPECIFY PILLAR-MODIOLAR MARKER CHANNELS
	for (i = 0; i < lengthOf(labels); i++) {
		// Channel indexing starts at 1
		labels[i] = "Channel "+toString(i+1);
		// One = box is checked, Zero = unchecked
		defaults[i] = 0;
		if (i==2){
			defaults[i]=0;
		}
	}
	Dialog.create("Get Analysis Info");
	Dialog.addString("Include pillar-mdiolar mapping in analysis?", "No");
	Dialog.addMessage("If applicable, indicate the channels to use for pillar-modiolar mapping.");
	Dialog.addCheckboxGroup(channels, 2, labels, defaults);
	Dialog.show();
	pmCheck = Dialog.getString();
	if (pmCheck == "Yes"){
		//   Get the information from the dialog box
		pmChCount = 0;
		include = newArray(channels);
		for (i = 0; i < lengthOf(labels); i++) {
			// Count the number of channels to include
			if (Dialog.getCheckbox() == 1){
				pmChCount++;
				include[i] = "Yes";
			}else{
				include[i] = "No";
			}
		}
		// Make an array of the channels to include
		pmCh = newArray(pmChCount);
		chCount = 0;
		for (i = 0; i < channels; i++) {
			if (include[i] == "Yes") {
				// Channel indexing starts at 1
				pmCh[chCount] = i+1;
				chCount++;
			}
		}
		pmChArr = "["+String.join(pmCh)+"]";
		Table.set("Pillar-Modiolar Marker Channels", imIndex, pmChArr);
		Table.update;
	}else{
		Table.set("Pillar-Modiolar Marker Channels", imIndex, "Not Included");
		Table.update;
	}
	// Make & save a max proj to help user with visualizing surfaces based on inclusion criteria
	//waitForUser("Adjust the brightness/contrast of the image as necessary for the maximum projection.");
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
	/*
	setTool("rectangle");
	waitForUser("Draw a rectangle around the hair cells to include in the analysis then press [t] to add to the ROI Manager.\n"+
				"Start with the upper left corner and move down and right across the image."+
				"Make sure the rectangle is still visible when pressing 'Ok' to proceed."+
				"Take note of the number of hair cells included in the analysis area.");
	*/
	// Get the coordinates for the rectangle
	/*
	Roi.getCoordinates(xpoints, ypoints);
	Roi.remove;
	Table.set("BB X0", imIndex, xpoints[0]);
	Table.set("BB X1", imIndex, xpoints[1]);
	Table.set("BB Y0", imIndex, ypoints[0]);
	Table.set("BB Y2", imIndex, ypoints[2]);
	*/
	Table.set("BB X0", imIndex, 0);
	Table.set("BB X1", imIndex, width);
	Table.set("BB Y0", imIndex, 0);
	Table.set("BB Y2", imIndex, height);
	Table.update;
	// Have the user enter the number of hair cells included in the analysis
	/*
	Dialog.create("Get Analysis Info");
	Dialog.addMessage("Indicate the number of hair cells included in the analysis area.");
	Dialog.addNumber("Number of Inner Hair Cells", 10);
	Dialog.show();
	nHCs = Dialog.getNumber();
	Table.set("NumberOfHairCells", imIndex, nHCs);
	*/
	Table.set("NumberOfHairCells", imIndex, "TBD");
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	close("*");
}

// VERIFY THAT THE XYZ POSITIONS MATCH THE IMAGE
function verifyXYZMatch(batchpath, imName, fName, imIndex){
	// Update the user about the analysis stage
	//waitForUser("Begining verification of XYZ dataset-image match.");
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
	Table.update;
	for (i = 0; i < tableRows; i++) {
		id = Table.get("ID", i);
		Table.set("SynapseStatus", i, "Synapse");
		xPos = (Table.get("Position X", i)*(1/vxW));
		//xPos=xPos+(xPos*2.222);
		yPos = (Table.get("Position Y", i)*(1/vxW));
		zPos = (Table.get("Position Z", i)*(1/vxD));
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
	// Save the updated Batch Master
	Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	// Save the annotated RAW MPI
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".RawMPI.AllXYZs."+fName+".png");
	// Rescale the image for visualization and summary image generation
	// . Get the dimensions of the image
	getDimensions(width, height, channels, slices, frames);
	// . Calculate the scaling factor and output dimensions
	scaleF = round(annImW/width);
	outputW = scaleF*width;
	outputH = scaleF*height;
	// .  Scale the annotated image
	run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+" interpolation=Bilinear average create");
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".RawMPI.AllXYZs."+fName+".png");
	// Ask the user to verify that the XYZ data matches the image
	choiceArray = newArray("Yes", "No");
	Dialog.create("Checkin");
	Dialog.addRadioButtonGroup("Do these XYZ points match the image?", choiceArray, 2, 1, "Yes");
	Dialog.show();
	match = Dialog.getRadioButton();
	close("*");
	close("*.csv");
	return match;
}

// GENERATE THUMBNAILS 
function genThumbnails(batchpath, imName, fName, imIndex) {
	// 1. Setup subfolders for storing thumbnails associated with this image
	File.makeDirectory(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/");
	// .  Open the substack MPI for labelling purposes
	open(batchpath+"SAR.RawMPIs/"+imName+".RawMPI.tif");
	// 2. Get parameters for substack
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	synChStr = Table.getString("Synaptic Marker Channels", imIndex);
	synCh = split(synChStr, "'[',',',']',' ',");
	// .  Had trouble with these values and rounding. Trying a diff approach with parseFloat
	vxW = parseFloat(Table.getString("Voxel Width (um)", imIndex));
	vxD = parseFloat(Table.getString("Voxel Depth (um)", imIndex));
	slStart = Table.get("ZStart", imIndex);
	slEnd = Table.get("ZEnd", imIndex);
	bbXZ = Table.get("BB X0", imIndex);
	bbXO = Table.get("BB X1", imIndex);
	bbYZ = Table.get("BB Y0", imIndex);
	bbYT = Table.get("BB Y2", imIndex);
	close("*.csv");
	// 3. Open the zstack and preprocess for the user
	// .  Make sure the user knows which settings to use for bioformats
	// .  Load XYZ data
	/*
	waitForUser("Beginning thumbnail generation process.\n"+
				"Please use the following settings for Bioformats Importer:\n"+
				"- Open as Hyperstack\n- Use Default color settings\n - Do not split channels\n- Do not autoscale\n"+
				"No boxes should be checked.");
				*/
	//    Open the raw image & get rid of channels that are not synaptic markers
	open(batchpath+"RawImages/"+imName+".czi");
	Stack.getDimensions(width, height, channels, slices, frames);
	run("Split Channels");
	for (i = 0; i < channels; i++) {
		ch = i+1;
		selectImage("C"+toString(ch)+"-"+imName+".czi");
		if ((ch != synCh[0]) && (ch != synCh[1])){
			close();
		}//else{
			// -- Subtract background from the entire z-stack
			//run("Subtract Background...", "rolling="+rbRadius+" stack");
		//}
	}
	// .  Create a composite image of the two synaptic marker channels
	// .   c2 is green, c6 is magenta
	cTwoIm = "C"+toString(synCh[0])+"-"+imName+".czi";
	cSixIm = "C"+toString(synCh[1])+"-"+imName+".czi";
	run("Merge Channels...", "c2="+cTwoIm+" c6="+cSixIm+" create keep");
	run("Make Composite");
	// .  Allow the user to make any adjustments to the display properties before proceeding 
	//waitForUser("Make any necessary adjustments to brightness/constrast, etc. before thumbnail generation begins.");
	// 4. Generate the three different thumbnails for every XYZ (i.e., ch1, ch2, and composite
	// .   Iterate through XYZs and perform cropping
	wbIn = 0;  // counter for tracking the number of XYZs within bounds and cropped
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	nXYZs = Table.size;
	tempImNames = newArray("C"+toString(synCh[0])+"-"+imName, "C"+toString(synCh[1])+"-"+imName, imName);
	fsExt = newArray("C1", "C2", "Comp");
	for (i = 0; i < lengthOf(fsExt); i++) {
		imTempName = tempImNames[i];
		fs = fsExt[i];
		selectImage(imTempName+".czi");
		for (j = 0; j < nXYZs; j++) {
			// . Get the XYZ info
			// . X and Y should be in terms of voxels
			// . Z needs to be in the slice number
			id = Table.get("ID", j);
			xPos = Table.get("Position X (voxels)", j);
			yPos = Table.get("Position Y (voxels)", j);
			zPos = Table.get("Position Z (voxels)", j);
			slZ = round(zPos);
			// . Verify that the XYZ is within the user defined main bounding box
			if ((xPos >= bbXZ) && (xPos <= bbXO)) { 
				if ((yPos >= bbYZ) && (yPos <= bbYT)) {
					if ((slZ >= slStart) && (slZ <= slEnd)){
						// Update information to include the XYZ
						Table.set("XYZinROI?", j, "Yes");
						// Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
						cropX = xPos - ((tnW/vxW)/2);
						cropY = yPos - ((tnH/vxW)/2); 
						Table.set("CropX", j, cropX);
						Table.set("CropY", j, cropY);
						// Calculate and store the start and end slice numbers for the z-stack
						zSt = round(slZ-((tnZ/vxD)/2));
						zEnd = floor(slZ+((tnZ/vxD)/2));
						Table.set("ZStart", j, zSt);
						Table.set("ZEnd", j, zEnd);
						Table.update;
						// Make a max projection for just this XYZ
						selectImage(imTempName+".czi");
						run("Z Project...", "start="+toString(zSt)+" stop="+toString(zEnd)+" projection=[Max Intensity]");
						run("Flatten");
						// Crop the region around the XYX
					    makeRectangle(cropX, cropY, (tnW/vxW), (tnH/vxW));
					    run("Crop");
					    // Add cross hairs for center
						setFont("SansSerif",3, "antiliased");
					    setColor(255, 255, 0);
						drawString(".", ((tnW/vxW)/2), ((tnW/vxW)/2));
					    setFont("SansSerif",8, "antiliased");
					    setColor(255, 255, 255);
						drawString(id, 1, ((tnW/vxW)-1));
						// Save the thumbnail image
						save(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/"+imName+".TN."+id+"."+fs+".png");
						// Close images
						close(imName+".TN."+id+"."+fs+".png");
						close("MAX_"+imTempName+"-1.czi");
						close("MAX_"+imTempName+".czi");
						wbIn++;
						// Update the annotated MPI
						//selectImage(imName+".RawMPI.tif");
						//makePoint(xPos, yPos, "tiny yellow dot add");
						//setFont("SansSerif",10, "antiliased");
					    //setColor(255, 255, 255);
						//drawString(id, xPos, yPos);
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
	}
	
	//    Close unnecessary images
	for (i = 0; i < lengthOf(tempImNames); i++) {
		close(tempImNames[i]+".czi");
	}
	// 5. Save the updated XYZ data
	Table.update;
	Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	close("*.csv");
	// 6. Save the annotated MPI as png to allow for annotating
	selectImage(imName+".RawMPI.tif");
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName+".png");
	//    Rescale the image for visualization and summary image generation
	//    Get the dimensions of the image
	getDimensions(width, height, channels, slices, frames);
	//    Calculate the scaling factor and output dimensions
	scaleF = round(annImW/width);
	outputW = scaleF*width;
	outputH = scaleF*height;
	//     Scale the image to play nicely with summary image
	run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+" interpolation=Bilinear average create");
	//    Add the original ROI as defined by the user
	makeRectangle(bbXZ*scaleF, bbYZ*scaleF, bbXO-bbXZ*scaleF, bbYT-bbYZ*scaleF);
	run("Draw", "slice");
	//    Save the new annotated image
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName+".png");
	close("*");
	
	// 8. Update Batch Master with number of XYZs in the ROI
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	Table.set(fName+"XYZinROI", imIndex, wbIn);
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	close("*.csv");
}

// GENERATE ARRAYS FROM THUMBNAILS
function genArrays(batchpath, imName, fName, imIndex){
	// Generate thumbnail arrays for each "channel"
	fsExt = newArray("C1", "C2", "Comp");
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	for (i = 0; i < 3; i++) {
		// Iterate through all of the XYZs and open the appropriate images
		nXYZs = Table.size;
		for (j = 0; j < nXYZs; j++) {
			inBounds = Table.getString("XYZinROI?", j);
			if (inBounds=="Yes"){
				id = Table.getString("ID", j);
				open(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/"+imName+".TN."+id+"."+fsExt[i]+".png");
			}
		}
		// Once all images are open, create the array
		run("Images to Stack", "use");
		Stack.getDimensions(width, height, channels, slices, frames);
		nRows = -floor(-(slices/10));
		run("Make Montage...", "columns=10 rows="+nRows+" scale=5");
		save(batchpath+"SAR.SynArrays/"+imName+".SynArray."+fName+"."+fsExt[i]+".png");
		close("*");
	}
	close("*.csv");
}

// WALK THE USER THROUGH COUNTING SYNAPSES ON AN ARRAY
function countSyns(batchpath, imName, fName, imIndex) {
	// Update the user about the analysis stage
	//waitForUser("Begining Synapse Counting.");
	// 1. Open the images that the user will neeed for synapse counting
	//    1a. Open the array files - composite and zstack
	arrList = getFileList(batchpath+"SAR.SynArrays/"); 
	for (i = 0; i < lengthOf(arrList); i++) {
	    if (startsWith(arrList[i], imName+".SynArray."+fName)) { 
	        open(batchpath+"SAR.SynArrays/"+ arrList[i]);
	    } 
	}
	run("Images to Stack", "use");
	//    1b. Open the annotated MPI 
	//open(batchpath+"SAR.AnnotatedMPIs/"+imName+".RawMPI.AllXYZs."+fName+".png");
	// 2. Have the user open the CSV file and manually update the information for each synapse
	waitForUser("*DO NOT CLICK OK UNTIL ANNOTATION IS COMPLETE*\n"+
				"Open the XYZ csv file for this image and edit the 'SynapseStatus' column.\n"+
				"Enter either (1) 'Synapse', (2) 'Orphan', (3) 'Doublet', or (4) 'Garbage'"+
				"Click ok when all XYZs have been reviewed AND the csv file has been saved (as a csv) and closed."+
				"Note: typos and/or incorrect lettercase may result in runtime errors.");
	// 2. Iterate through the XYZs and count the numbers of each type
	//    Setup counters for tracking the numbers of each category
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	sCount = 0;
	syns = newArray(0);
	orphs = newArray(0);
	dubs = newArray(0);
	garbs = newArray(0);
	uncs = newArray(0);
	for (i = 0; i < Table.size; i++) {
		id = Table.getString("ID",i);
		included = Table.getString("XYZinROI?", i);
		if (included == "Yes"){
			status = Table.getString("SynapseStatus",i);
			if(status=="Synapse"){              // Case where XYZ is a synapse
				syns = Array.concat(syns,id);
			}else if (status=="Orphan"){			// Case where XYZ is an orphan
				orphs = Array.concat(orphs,id);
			}else if (status=="Doublet"){	   // Case where XYZ is a doublet
				dubs = Array.concat(dubs,id);
			}else if (status=="Garbage"){	   // Case where XYZ is gabage
				garbs = Array.concat(garbs,id);
			}else{								// Case where category for XYZ is unclear
				uncs = Array.concat(uncs,id);
			}
		}
	}
	// 5. Open Batch Master and update information about XYZs
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	Table.set(fName+"_nSynapses", imIndex, lengthOf(syns)+lengthOf(dubs));
	Table.set(fName+"_Synapses", imIndex, "["+String.join(syns)+"]");
	Table.set(fName+"_nDoublets", imIndex, lengthOf(dubs));
	Table.set(fName+"_Doublets", imIndex, "["+String.join(dubs)+"]");
	Table.set(fName+"_nOrphans", imIndex, lengthOf(orphs));
	Table.set(fName+"_Orphans", imIndex, "["+String.join(orphs)+"]");
	Table.set(fName+"_nGarbage", imIndex, lengthOf(garbs));
	Table.set(fName+"_Garbage", imIndex, "["+String.join(garbs)+"]");
	Table.set(fName+"_nUnclear", imIndex, lengthOf(uncs));
	Table.set(fName+"_Unclear", imIndex, "["+String.join(uncs)+"]");
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	//waitForUser("Synapse Analysis for the "+fName+" dataset is complete.");
	close("*");
	close("*.csv");
}

// MAP PILLAR-MODIOLAR POSITIONS FOR ALL XYZs within ROI 
function mapPillarModiolar(batchpath, imName, fName, imIndex){
	// Update the user about the analysis stage
	waitForUser("Beginning pillar-modiolar mapping.");
	// Get the information about the ROI 
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	pmChStr = Table.getString("Pillar-Modiolar Marker Channels", imIndex);
	pmCh = split(pmChStr, "'[',',',']',' ',");
	xSt = Table.get("BB X0", imIndex);
	xEnd = Table.get("BB X1", imIndex);
	zSt = Table.get("ZStart", imIndex);
	zEnd = Table.get("ZEnd", imIndex);
	// Open the raw image
	open(batchpath+"RawImages/"+imName+".czi");
	// Make a new stack based on the channels to include
	Stack.getDimensions(width, height, channels, slices, frames);
	getDimensions(width, height, channels, slices, frames);
	getVoxelSize(vW, vH, vD, unit);
	// NEED TO FIX THIS SECTION -- CURRENTLY NOT SETUP FOR MORE THAN ONE CHANNEL
	run("Split Channels");
	for (i = 0; i < channels; i++) {
		ch = i+1;
		selectImage("C"+toString(ch)+"-"+imName+".czi");
		if (ch != pmCh[0]){
			close();
		}
	}
	// .  Create a composite image of the two synaptic marker channels
	// .   c2 is green, c6 is magenta
	//cTwoIm = "C"+toString(synCh[0])+"-"+imName+".czi";
	//cSixIm = "C"+toString(synCh[1])+"-"+imName+".czi";
	//run("Merge Channels...", "c2="+cTwoIm+" c6="+cSixIm+" create keep");
	//run("Make Composite");
	// Crop the z-stack accordingly
	makeRectangle(xSt, 0, xEnd-xSt, height);
	run("Crop");
	// Make the ortho projection
	run("Reslice [/]...", "output="+vD+" start=Left flip");
	run("Z Project...", "projection=[Max Intensity]");
	//run("Make Composite");
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
	pCount = 0;
	mCount = 0;
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
				Table.update;
				pCount++;
			}else{
				// Add an annotation to the MPI for verification purposes
				makePoint(xPos, yPos, "medium cyan dot add");
				setFont("SansSerif",8, "antiliased");
			    setColor(255, 255, 255);
				drawString(id, xPos, yPos);
				Table.set("PMStatus", i, "Modiolar");
				Table.update;
				mCount++;
			}
		}
		else {
			Table.set("PMStatus", i, "Invalid XYZ");
		}
	}
	// Increase the size of the image to help with visualization
	// . Get the dimensions of the image
	getDimensions(width, height, channels, slices, frames);
	// . Calculate the scaling factor and output dimensions
	scaleF = round(annImW/width);
	outputW = scaleF*width;
	outputH = scaleF*height;
	// .  Scale the annotated image
	run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+" interpolation=Bilinear average create");
	// Save the annotated image
	save(batchpath+"/SAR.PillarModiolarMaps/"+imName+".PMMap."+fName+".png");
	waitForUser("Pillar-Modiolar mapping for "+imName+" is complete.");
	close("*");	
	close("*.csv");
	// Add counts to Batch Master
	Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
	Table.set(fName+"_nPillar", imIndex, pCount);
	Table.set(fName+"_nModiolar", imIndex, mCount);
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	close("*.csv");
}

// Generate a thumbnail array using only the terminal marker channel and allow the user to review
function countTerMarker(batchpath, imName, imIndex){	
	// Update user on satus
	waitForUser("Beginning afferent terminal marker analysis.");
	// Setup subfolders for storing thumbnails associated with this image
	File.makeDirectory(batchpath+"SAR.Thumbnails/"+imName+".Terminals/");
	// Get parameters for substack
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	terChArr = Table.getString("Terminal Marker Channels", imIndex);
	vxW = Table.get("Voxel Width (um)", imIndex);
	vxD = Table.get("Voxel Depth (um)", imIndex);
	slStart = Table.get("ZStart", imIndex);
	slEnd = Table.get("ZEnd", imIndex);
	bbXZ = Table.get("BB X0", imIndex);
	bbXO = Table.get("BB X1", imIndex);
	bbYZ = Table.get("BB Y0", imIndex);
	bbYT = Table.get("BB Y2", imIndex);
	adXYZ = Table.getString("AvailXYZData", imIndex);
	// Set the filename based on the XYZ datasets available
	if ((adXYZ == "Both Pre- and Post-") || (adXYZ=="Only Pre-")){
		fName = "PreSyn";
	}else {
		fName = "PostSyn";
	}
	// Open the raw image
	open(batchpath+"RawImages/"+imName+".czi");
	// -- Subtract background from the entire z-stack
	run("Subtract Background...", "rolling=50 stack");
	// Generate a max projection composite image that will be labelled with points of interest
	run("Make Substack...", "channels="+terChArr+" slices="+slStart+"-"+slEnd);
	run("Make Composite");
	selectImage(imName+".czi");
	close();
	// Allow the user to make any adjustments to the display properties before proceeding 
	//waitForUser("Make any necessary adjustments to brightness/constrast, etc. before thumbnail generation begins.");
	// Load the XYZs & allow the user to specify the sorting order
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	labels = newArray("ID", "Volume");
	defaults = newArray("0", "1");
	Dialog.create("Get Sorting Order");
	Dialog.addMessage("Indicate the desired sorting order for thumbnail generation."+
					  "Using the same sorting order that was used for synapses is suggested.");
	Dialog.addCheckboxGroup(2, 2, labels, defaults);
	Dialog.show();
	chkID = Dialog.getCheckbox();
	chkVol = Dialog.getCheckbox();
	if ((chkID == 1) && (chkVol == 0)){
		sort = "ID";
	}else if ((chkID == 0) && (chkVol == 1)){
		sort = "Volume_um3";
	}else {
		print("Sorting order error: both or no options selected.\n"+
			  "Defaulting to sorting by volume.");
		sort = "Volume_um3";
	}
	Table.sort(sort);
	// Iterate through XYZs and perform cropping
	wbIn = 0; // Counter for tracking the number of XYZs within bounds and cropped
	for (i = 0; i < Table.size; i++) {
		// Get the XYZ info
		id = Table.getString("ID", i);
		included = Table.getString("XYZinROI?", i);
		// First verify that the XYZ is within the user defined main bounding box
		if (included == "Yes"){
		    // Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
			cropX = Table.get("CropX", i);
			cropY = Table.get("CropY", i);
			// Calculate and store the start and end slice numbers for the z-stack
			zSt = Table.get("ZStart", i);
			zEnd = Table.get("ZEnd", i);
			
			// Code for projecting into the Z direction (generating a XY-view of the image)
			selectImage(imName+"-1.czi");
			run("Z Project...", "start="+toString(zSt)+" stop="+toString(zEnd)+" projection=[Max Intensity]");
			run("Flatten");
			// Crop the region around the XYX
		    makeRectangle(cropX, cropY, (tnW/vxW), (tnH/vxW));
		    run("Crop");
		    
		    // Add center mark
			setFont("SansSerif",3, "antiliased");
		    setColor(255, 255, 0);
			drawString(".", ((tnW/vxW)/2), ((tnW/vxW)/2));
		    setFont("SansSerif",8, "antiliased");
		    setColor(255, 255, 255);
			drawString(id, 1, ((tnW/vxW)-1));
			// Make and save the maximum projection
			if (sort == "Volume_um3"){
				save(batchpath+"SAR.Thumbnails/"+imName+".Terminals/"+imName+".TN."+toString(i)+"."+id+".png");
			}else{
				save(batchpath+"SAR.Thumbnails/"+imName+".Terminals/"+imName+".TN."+id+".png");
			}
			// Close images
			close(imName+".TN."+id+".png");
			close("MAX_"+imName+"-1.czi");
			close("MAX_"+imName+"-2.czi");
			wbIn++;
		}
	}
	// Housekeeping - Close irrelevant images
	close("*");
	// Generate the thumbnail array
	File.openSequence(batchpath+"SAR.Thumbnails/"+imName+".Terminals/");
	nRows = -floor(-(wbIn/10));
	run("Make Montage...", "columns=10 rows="+nRows+" scale=5");
	save(batchpath+"SAR.SynArrays/"+imName+".TerArray."+fName+".png");
	// Proceed with having the user add IDs for terminals with the marker
	Dialog.create("Get Terminal Marker Info");
	Dialog.addString("Enter the ID numbers for all thumbnails showing\n"+
					 "the terminal marker.", "247, 253, 246, 252, 279", 50);
	Dialog.show();
	terIDs = Dialog.getString();
	terIDArr = split(terIDs, ",");
	// Since there are limited table tools have to do this a dirty way 
	Table.sort("ID");
	Table.update;
	terIDArr = Array.sort(terIDArr);
	// Add column for storing marker status to the CSV
	for (i = 0; i < Table.size; i++) {
		Table.set("MarkerStatus",i,"TBD");
		included=Table.getString("XYZinROI?",i);
		// Mark all XYZs within the ROI first as not having the marker 
		if(included=="Yes"){
			Table.set("MarkerStatus",i,"Negative");
			Table.update;
		}
	}
	// Change marker status for those XYZs that the user identified
	for (i = 0; i < lengthOf(terIDArr); i++) {
		Table.set("MarkerStatus",terIDArr[i],"Positive");
		Table.update;
	}
	Table.save(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	// Update Batch Master
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	Table.set(fName+"WMarker", imIndex, toString(lengthOf(terIDArr)));
	Table.update;
	Table.save(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	waitForUser("Terminal Marker Analysis is complete.");
	close("*");
	close("*.csv");
}

// Generate a summary image that has the main components from the analysis
function genSummaryImage(batchpath, imName, imIndex){
	// Update the user about the analysis stage
	waitForUser("Beginning Summary Image Generation.");
	// Set the location for saving the summary images
	dirSV = batchpath+"SAR.SummaryImages/";
	// Determine how many syn-marker summary panels need to be generated
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	if (adXYZ=="Only Pre-"){
		fName = newArray("PreSyn");
	}else if (adXYZ == "Both Pre- and Post-"){
		fName = newArray("PreSyn","PostSyn");
	}else{
		fName = newArray("PostSyn");
	}
	// Default number of rows for the montage image is 3 
	rows = "3";
	for (i = 0; i < lengthOf(fName); i++) {
		// Setup name for the summary image
		svName = imName+".SummaryImage."+fName[i]+".png";
		// Generate the montage summary image - It must be done in two steps to avoid excess boundary space
		// Open the two MPIs, create and save a montage of those two first 
		open(batchpath+"SAR.AnnotatedMPIs/"+imName+".RawMPI.AllXYZs."+fName[i]+".png");
		open(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName[i]+".png");
		run("Images to Stack", "use");
		run("Make Montage...", "columns=1 rows=2 scale=1 font = 48 label");
		save(dirSV+svName);
		close("*");
		// Organize the available arrays
		if (File.exists(batchpath+"SAR.SynArrays/"+imName+".TerArray."+fName[i]+".png")){
			open(batchpath+"SAR.SynArrays/"+imName+".SynArray."+fName[i]+".Comp.png");
			open(batchpath+"SAR.SynArrays/"+imName+".TerArray."+fName[i]+".png");
			run("Images to Stack", "method=[Copy (center)]");
			run("Make Montage...", "columns=1 rows=2 scale=1");	
			close("Stack");
			
		}else{
			open(batchpath+"SAR.SynArrays/"+imName+".SynArray."+fName[i]+".Comp.png");
		}
		// Add the field of view MPIs
		open(dirSV+svName);
		// Add in the PM Map
		open(batchpath+"SAR.PillarModiolarMaps/"+imName+".PMMap."+fName[i]+".png");
		// Create and save a new summary montage
		run("Images to Stack", "method=[Copy (center)]");
		run("Make Montage...", "columns=1 rows=3 scale=1");	
		close("Stack");
		// Save the Summary Image
		save(dirSV+svName);
	}
	// If there were pre- and post-synaptic marker XYZ datasets available, make a double image
	if(lengthOf(fName)==2){
		open(batchpath+"SAR.PillarModiolarMaps/"+imName+".PMMap."+fName[0]+".png");
		open(batchpath+"SAR.PillarModiolarMaps/"+imName+".PMMap."+fName[1]+".png");
		run("Images to Stack", "method=[Copy (center)]");
		run("Make Montage...", "columns=2 rows=1 scale=1");
	}
	waitForUser("Summary image for "+imName+" has been generated and saved.");
	close("*");
	close("*.csv");
}
