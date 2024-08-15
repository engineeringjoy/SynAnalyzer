/*
 * SynAnalyzer_GenSynArray.ijm
 * Created by JFranco, 02 MAY 2024
 * Last update: 02 JUL 2024
 * 
 * RETIRED - A newer version of the macro is being developed to add in functionality.
 * See SynAnalyzer.ijm.
 * 
 * This .ijm macro is a work in progress. The ultimate goal is to read in an .xlsx file that contains the XYZ positions of 
 * all CtBP2 surfaces and to generate thumbnail views of a 1.5 um cube centered at the XYZ position as in  
 * Liberman, Wang, and Liberman 2011 (DOI:10.1523/JNEUROSCI.3389-10.2011).
 * 
 */
 
 /* 
 ************************** SynAnalyzer_GenSynArray.ijm ******************************
 */

// USER PARAMETERS
// Specify the name of the folder in which the images are saved
fdIms = "RawImages_63x";
fdXYZ = "CtBP2Positions";
ext = ".CtBP2.XYZ";

// Specify the width and height of the desired bounding box based (in microns)
tnW = 1.5;
tnH = 1.5;
tnZ = 1.5;

// *** HOUSEKEEPING ***
run("Close All");										// Close irrelevant images

// *** GET THE FILE TO ANALYZE ***
Dialog.create("SynAnalyzer Bootup");
Dialog.addMessage("This macro will open your z-stack of choice\n"+
	"and create a thumbnail array of the synaptic regions\n"+
	"based on the accompanying .csv file of XYZ coordinates of CtBP2\n"+
	"puncta. Please see GitHub Repo for file structure requirements.\n"+
	"Click 'OK' when you're ready to choose an image.");
Dialog.show();
impath = File.openDialog("Choose image to open");    	// Ask user to find file 
open(impath);	

// *** SETUP VARIABLES BASED ON FILENAME & PATH ***
fn = File.name;											// Save the filename (with extension)
fnBase = File.getNameWithoutExtension(impath);			// Get image name
fnTN = fnBase+".TN.";									// Filenmae for max projection generated
fnTnArr= fnBase+".ThumbnailArray";						// Filename for the thumbnail array 
fnMD= fnBase+".Metadata.csv";						// Filename for metadata from the cropping calculation
fnSCs= fnBase+".SynCounts.csv";						// Filename for metadata from the cropping calculation
fnXYZ = fnBase+ext+".csv"
wd = File.getDirectory(impath);							// Gets path to where the image is stored
rootInd = lastIndexOf(wd, fdIms);					    // Gets index in string for where root directory ends
root = substring(wd, 0, rootInd);						// Creates path to root directory
dirXYZ = root+fdXYZ+"/";								// Location of CSV files to be loaded
dirSA = root+"/SynAnalyzerResults/";				    // Main directory for all things generated via this macro
dirTNs = dirSA+"TNs/";								    // Main directory for storing subdirectories of thumbnail images
dirTR = dirTNs+fnBase+"/";								// Place to save thumbnails for this specific image
dirArs = dirSA+"SynapseArrays/";						// Subdirectory for storing synapses arrays for every image in the prep 
dirMPs = dirSA+"SynCounts/";						    // Subdirectory for storing csv files that have synapse counts for every image in the prep


// *** SETUP DIRECTORIES IF APPLICABLE ***
// Make directory for storing files related to this analysis
//  only needs to be done once.
if (!File.isDirectory(dirSA)) {
	File.makeDirectory(dirSA);
	File.makeDirectory(dirTNs);
	File.makeDirectory(dirArs);
	File.makeDirectory(dirMPs);
	if (!File.isDirectory(dirTR)) {
		File.makeDirectory(dirTR);
	}
}

// *** BEGIN ANALYSIS ***

// -- Allow the user to specify the channels to include
Stack.getDimensions(width, height, channels, slices, frames);
Dialog.create("Create Substack");
Dialog.addMessage("Indicate the channels and slices to include in the analysis.");
Dialog.addString("Channel Start","2");
Dialog.addString("Channel End","3");
Dialog.addString("Slice Start","1");
Dialog.addString("Slice End", slices);
Dialog.show();
// -- Read in values from dialog box
chStart = Dialog.getString();
chEnd = Dialog.getString();
slStart = Dialog.getString();
slEnd = Dialog.getString();
// -- Make the substack to spec and save
run("Make Substack...", "channels="+chStart+"-"+chEnd+" slices="+slStart+"-"+slEnd);
close("\\Others");
// -- Get updated information about the stack
Stack.getDimensions(width, height, channels, slices, frames);
// -- Get the pixel size and calculate the width and height for cropping (um/px)
getVoxelSize(vxW, vxH, vxD, unit);


// -- Load the XYZ positions for each CtBP2 surface
// -- Calculate the cropping information for each CtBP2 punctum
setupXYZ(dirXYZ+fnXYZ, tnW, tnH, tnZ, vxD);


// -- Subtract background from the entire z-stack
run("Subtract Background...", "rolling=50 stack");

// -- Allow the user to perform manual adjustments if necessary
waitForUser("Peform any desired adjustments to the image (such as changing the LUT or autoscaling the pixel intensity),"+
			"\nthen close this dialog box.");

// -- Iterate through the puncta & generate thumbnails
for (i = 0; i < nResults(); i++) {
    // Ensure the right image is selected and others are closed
    selectImage(fnBase+"-1.czi");
    close("\\Others");
    
    // Generate a max projection for only the slices of interest 
    zSt = getResult("ZStart", i);
    zEnd = getResult("ZEnd", i);
    run("Z Project...", "start="+zSt+" stop="+zEnd+" projection=[Max Intensity]");
    // Create a cropping box for each punctum and add it to the ROI manager
    x = getResult("CropX", i);
    y = getResult("CropY", i);
    run("Specify...", "width="+tnW+" height="+tnH+" x="+x+" y="+y+" slice=1 scaled");
    run("Crop");
    run("Make Composite");
	run("Flatten");
	saveAs("PNG", dirTR+fnTN+i+".png");
	close(fnTN+i+".png");
}

run("Close All");

for (i = 0; i < nResults(); i++) {
    // Open the thumbnail
    open(dirTR+fnTN+i+".png");
}

// Make montage
nCols = 10;
nRows = round(nResults/nCols);
run("Images to Stack");
run("Make Montage...", "columns="+nCols+" rows="+nRows+" scale=1");

/*
// Add cropping information to the results table
for (i = 0; i < nResults(); i++) {
	// Get XYZ positions as listed in the results table (um)
    posX = getResult("Position X", i);
    posY = getResult("Position Y", i);
    posZ = getResult("Position Z", i);
    // Convert XYZ positions to voxel units 
    vposX = round(posX/vxW);
    vposY = round(posY/vxH);
    vposZ = round(posZ/vxD);
    setResult("PosX_vx",i,vposX);
    setResult("PosY_vx",i,vposY);
    setResult("PosZ_vx",i,vposZ);
    // Set the starting positions for the cropping rectangle by getting the XY coordinates
    //    and then subtracting the number requisite pixels based on bixel size
    cropX = vposX-round((cropW/2));
    cropY = vposY-round((cropH/2));
    setResult("CropX_vx",i,cropX);
    setResult("CropY_vx",i,cropY);
}
updateResults();

// *** Code development test: make sure that the cropping boxes are accurate ***

}


*/

// THIS FUNCTION READS IN A CSV FILE WITH ALL CTBP2 PUNCTA LOCATIONS AND LOADS THEM INTO THE RESULTS FILE
//   IT ALSO COMPUTES THE NEAREST PIXEL XYZ 
function setupXYZ(fPath, tnW, tnH, tnZ, vxD){
// FX Reads in csv file and setsup info as a Results table
	run("Clear Results");
	lineseparator = "\n";
	cellseparator = ",\t";

	// Opens the CSV file and splits the full string into separate lines (one for each CtBP2 punctum)
	rows=split(File.openAsString(fPath), lineseparator);

	// Generate an array of column headers 
	cols=split(rows[0], cellseparator);
	print(cols[0]);
	if (cols[0]==" "){
		k=1; // it is an ImageJ Results table, skip first column
	}else{
		k=0; // it is not a Results table, load all columns
	}

	// Iterates through all of the column headers and sets up the Results table to match
	noPos = 3;
	//for (j=k; j<(noPos+k); j++){
		//setResult(cols[j],0,0);
	//}
	
	// Housekeeping to make sure no random values are stored in the table		
	//run("Clear Results");
	
	// Iterate through each row of the original CSV file to enter the values into the results table
	for (i=1; i<rows.length; i++) {
		// Reformat the string as an array with each entry corresponding to a unique column
		pmInfo=split(rows[i], cellseparator);
		// Iterate through each column in the row for this punctum & set the value for the respective column
		//   based on the information in that specific row
		for (j=k; j<(noPos+k+1); j++){
			setResult(cols[j],i-1,pmInfo[j]);
			// By casting the actual value as an integer the position gets rounded to the nearest pixel
			// Saving code as option: setResult(cols[j],i-1,parseInt(pmInfo[j]));
		}
		
		// Caclulate and store the XYZ coordinates for the upper left corner of the cropping box
		cropX = getResult("Position X", i-1) - (tnW/2);
		cropY = getResult("Position Y", i-1) - (tnH/2); 
		setResult("CropX", i-1, cropX);
		setResult("CropY", i-1, cropY);
		
		// Calculate and store the start and end slice numbers for the z-stack
		zSt = round((getResult("Position Z", i-1)-(tnZ/2))*(1/vxD));
		zEnd = round((getResult("Position Z", i-1)+(tnZ/2))*(1/vxD));	
		setResult("ZStart", i-1, zSt);
		setResult("ZEnd", i-1, zEnd);
	}
	//Table.deleteRows(0, 0);
	updateResults();
	
}