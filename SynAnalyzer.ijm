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
				Table.set("BBCoordinates", i, "TBD");        
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
					Table.set("BBCoordinates", row, "TBD");        
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
						analyzeIm(batchpath, imName);
					}	
				}
			}
		}
    }
    return exists;
}

// MAIN FUNCTION FOR ANALYZING AN IMAGE
function analyzeIm(batchpath, imName){
	// *** PICK UP HERE
	Proceed with analyzing an image - 
	So what does that look like? What information is needed for that image? -Imagename, batchpath to make things easy, row in the batch master table.
	
}
