/*
 * SynAnalyzer_GenSynArray.ijm
 * Created by JFranco, 02 MAY 2024
 * Last update: 04 MAY 2024
 * 
 * This .ijm macro is a work in progress. The ultimate goal is to read in an .xlsx file that contains the XYZ positions of 
 * all CtBP2 surfaces and to generate thumbnail views of a 1.5 um cube centered at the XYZ position as in  
 * Liberman, Wang, and Liberman 2011 (DOI:10.1523/JNEUROSCI.3389-10.2011).
 * 
 * LAST STOPPING POINT: Got the code to the point where a CSV file with XYZ positions can be loaded into the results table.
 * 
 * NEXT STEPS: 
 * 	1. Code for user to select the image to open and specify the channels to include but not slices
 * 	2. Create a directory for saving image thumbnails
 * 	3. Write code to iterate through the entries in the results table and for each entry:
 * 	    -> Make composite
 * 	    -> Flatten
 * 	    -> Save thumbnail
 * 	    -> Close thumbnail
 * 	    -> Close the substack
 *  4. Close the Z-stack 
 *  5. After all thumbnails are generated, open the folder of thumbnails and generate the array image 
 * 
 */
 
 /* 
 ************************** SynAnalyzer_GenSynArray.ijm ******************************
 */

// USER PARAMETERS
// Specify the width and height of the desired bounding box based (in microns)
tnW = 1.5;
tnH = 1.5;
tnZ = 1.5;

// First test is to see if I can just load a CSV file that has the XYZ positions for each surface into the results table. 
// *** HOUSEKEEPING ***
run("Close All");										// Close irrelevant images
dirData = "/Users/joyfranco/Dropbox (Partners HealthCare)/JF_Shared/Data/CodeDev/SynAnalyzer/";
fnIm = "WSS_002.A.T2.02.Zs.4C.czi"		
fnXYZ = "WSS_002.A.T2.02.Zs.4C.CtBP2Puncta.csv"

// Load the XYZ positions for each CtBP2 surface
setupXYZ(dirData+fnXYZ);

// Load the Z-stack 
//open(dirData);
run("Bio-Formats Importer");
// Get information about the stack
Stack.getDimensions(width, height, channels, slices, frames);

// Select the bare minimum number of channels and slices to include
waitForUser("Examine the Z-stack and choose which images to include in the max projection.\n"+
	"You will enter the specifications in the next dialog box.");
	
// Create dialog box	
Dialog.create("Create Substack");
Dialog.addMessage("Indicate the channels and slices to include in the analysis.");
Dialog.addString("Channel Start","2");
Dialog.addString("Channel End",channels);
Dialog.addString("Slice Start","1");
Dialog.addString("Slice End", slices);
Dialog.show();
// Read in values from dialog box
chStart = Dialog.getString();
chEnd = Dialog.getString();
slStart = Dialog.getString();
slEnd = Dialog.getString();
// Make the substack to spec and save
run("Make Substack...", "channels="+chStart+"-"+chEnd+" slices="+slStart+"-"+slEnd);
close("\\Others");
// Get updated information about the stack
Stack.getDimensions(width, height, channels, slices, frames);

// Get the pixel size and calculate the width and height for cropping
getVoxelSize(vxW, vxH, vxD, unit);
print(vxD);
cropW = round(tnW/vxW);
cropH = round(tnH/vxH);
cropD = round(tnZ/vxD);

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
for (i = 10; i < nResults(); i++) {
    // Generate a max projection for only the slices of interest
    z = getResult("PosZ_vx", i);
    zSt = z-round(cropD/2);
    zEnd = z+round(cropD/2);
    run("Z Project...", "start="+zSt+" stop="+zEnd+" projection=[Max Intensity]");
    // Create a cropping box for each punctum and add it to the ROI manager
    x = getResult("CropX_vx", i);
    y = getResult("CropY_vx", i);
    makeRectangle(x, y, cropW, cropH);
    run("Crop");
    exit;
}

// THIS FUNCTION READS IN A CSV FILE WITH ALL CTBP2 PUNCTA LOCATIONS AND LOADS THEM INTO THE RESULTS FILE
//   IT ALSO COMPUTES THE NEAREST PIXEL XYZ 
function setupXYZ(fPath){
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
		k=2; // it is an ImageJ Results table, skip first column
	}else{
		k=1; // it is not a Results table, load all columns
	}

	// Iterates through all of the column headers and sets up the Results table to match
	noPos = 3;
	for (j=k; j<(noPos+k); j++){
		setResult(cols[j],0,0);
	}
	
	// Housekeeping to make sure no random values are stored in the table		
	//run("Clear Results");
	
	// Iterate through each row of the original CSV file to enter the values into the results table
	for (i=1; i<rows.length; i++) {
		// Reformat the string as an array with each entry corresponding to a unique column
		pmInfo=split(rows[i], cellseparator);
		// Iterate through each column in the row for this punctum & set the value for the respective column
		//   based on the information in that specific row
		for (j=k; j<(noPos+k); j++)
			//setResult(cols[j],i-1,pmInfo[j]);
			// By casting the actual value as an integer the position gets rounded to the nearest pixel
			setResult(cols[j],i-1,parseInt(pmInfo[j]));
	}
	
	updateResults();
}

