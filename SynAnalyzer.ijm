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
// .  the batch folder accordingly
//batchpath = initSynAnalyzer();

// *** PROCEED WITH ANALYSIS ***
choice = getChoice();
while (choice != "EXIT") {
	
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
	dirSI = batchpath+"SAR.SummaryImages/";
	dirSA = batchpath+"SAR.SynArrays/";
	dirPM = batchpath+"SAR.PillarModiolarMaps/";
	dirAM = batchpath+"SAR.AnnotatedMPIs/";
	dirAM = batchpath+"SAR.POIAnnotations/";            // Point of interest annotations - stores CSV of details for each surface
	
	// *** CREATE SUBFOLDERS IF THEY DO NOT EXIST ***
	if (!File.isDirectory(dirSI)) {
		File.makeDirectory(dirSI);
		File.makeDirectory(dirSA);
		File.makeDirectory(dirPM);
		File.makeDirectory(dirAM);
		
		// *** SETUP BATCH MASTER RESULTS TABLE ***
		Table.create("Batch Master");
		Table.set("ImageName", 0, "");
		Table.set("BBCoordinates", 0, "");        
		Table.set("NumberOfHairCells", 0, "");
		Table.set("PreSynCentSynapses", 0, "");
		Table.set("PostSynCentSynapses", 0, "");
		Table.set("PreSynOrphans", 0, "");
		Table.set("PostSynOrphans", 0, "");
		Table.save(batchpath+"/Metadata/SynAnalyzerBatchMaster.csv");
	}
	return batchpath;
}

// ALLOW USER TO CHOOSE HOW TO PROCEED
function getChoice() {
	// *** ASK THE USER WHAT THEY WANT TO DO ***
	choiceArray = newArray("Batch Mode", "Select Image", "EXIT");
	Dialog.create("SynAnalyzer GetChoice");
	Dialog.addMessage("Choose analysis mode:");
	Dialog.addRadioButtonGroup("Choices",choiceArray, 3, 1, "Batch Mode");
	Dialog.show();
	choice = Dialog.getRadioButton();
	return choice;
}
