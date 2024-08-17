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
		runAnalysis("Specific", batchpath);
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
		for (i = 0; i < lengthOf(filelist); i++) {
		    if (endsWith(filelist[i], ".czi")) {
		    	// Iterate through the columns in the preset array and setup table 
		    	for (j = 0; j < cols; j++) {
		    		// First column should be image name
		    		if (j==0){
		    			Table.set(bmCols[j], i, filelist[i]);
		    		}else if (j==1){
		    			Table.set(bmCols[j], i, "No");
		    		}else{
						Table.set(bmCols[j], i, "TBD");
		    		}
		    	}
			} 
		}
		Table.save(dirAna+fBM);
	} else { 
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
					for (j = 0; j < cols; j++) {
			    		// First column should be image name
			    		if (j==0){
			    			Table.set(bmCols[j], i, filelist[i]);
			    		}else if (j==1){
			    			Table.set(bmCols[j], i, "No");
			    		}else{
							Table.set(bmCols[j], i, "TBD");
			    		}
			    	}
				}
		    }
		}
		
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
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	ims = Table.getColumn("ImageName"); 
	close(".csv");
	//  . Get list of files available
	filelist = getFileList(batchpath+"RawImages/");
	// 2. Setup trackers for while loop
	//  . Set batch to "Go" to enter while loop at least once
	batch = "Go";
	//  . Set counter for iterating through all files
	i = 0; 
	// 3. Go through while loop once for specific image mode, or until the user says stop for batch mode
	while (batch != "Exit") {
		// 3.1 Allow user to choose image if specific image mode is running
		if (mode == "Specific Image"){
			Dialog.create("Choose a file to analyze")
			Dialog.addChoice("Available Files", filelist);
			Dialog.show();
			file = Dialog.getChoice();
			// Set batch to Stop so that it exists the while-loop after analysis
			batch = "Exit";
		}else if (mode == "Batch"){
			file = filelist[i];
		}
		// 3.2 Verify that the image file is available and has matching XYZ datasets
		imStatus = verifyIm(batchpath, file);
	}
}

// VERIFY FILE -- FX FOR CHECKING THAT FILE CAN BE ANALYZED
function verifyIm(batchpath, file){
	// 1. Notify user that image verification is beginning
	waitForUser("Proceeding with Image Verification");
	// 2. Check that the file type is acceptable
	if (endsWith(file, imFType)) { 
	
	return status;
}










	
}
