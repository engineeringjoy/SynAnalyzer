/*
 * SynAnalyzer_GenSynArray.ijm
 * Created by JFranco, 02 MAY 2024
 * Last update: 02 MAY 2024
 * 
 * This .ijm macro is a work in progress. The ultimate goal is to read in an .xlsx file that contains the XYZ positions of 
 * all CtBP2 surfaces and to generate thumbnail views of a 1.5 um cube centered at the XYZ position as in  
 * Liberman, Wang, and Liberman 2011 (DOI:10.1523/JNEUROSCI.3389-10.2011).
 * 
 * LAST STOPPING POINT: Got the code to the point where a CSV file with XYZ positions can be loaded into the results table.
 * 
 * NEXT STEPS: 
 * 	1. Calculate the starting x and y positions for the bounding box and add these to the results table
 * 	2. Setup code for calculating width and height in pixels based on the pixel size 
 * 	3. Setup the code for reading in the image
 * 	4. Write code to iterate through the entries in the results table and for each entry:
 * 	    -> generate a substack 
 * 	    -> makeRectangle
 * 	    -> crop
 * 	    -> make maximum projection
 * 	    -> save thumbnail
 * 	    -> close thumbnail
 *  5. After all thumbnails are generated, open the folder of thumbnails and generate the array image 
 * 
 */
 
 /* 
 ************************** SynAnalyzer_GenSynArray.ijm ******************************
 */

// USER PARAMETERS
// Specify the width and height of the desired bounding box based (in microns)
tnW = 1.5
tnH = 1.5 <- these values will need to get converted to pixels

// First test is to see if I can just load a CSV file that has the XYZ positions for each surface into the results table. 
// *** HOUSEKEEPING ***
run("Close All");										// Close irrelevant images
dirData = "/Users/joyfranco/Dropbox (Partners HealthCare)/JF_Shared/Data/CodeDev/SynAnalyzer/";		
fnXYZ = "WSS_002.A.T2.02.Zs.4C.CtBP2Puncta.csv"

setupXYZ(dirData+fnXYZ);


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
	if (cols[0]==" "){
		k=1; // it is an ImageJ Results table, skip first column
	}else{
		k=0; // it is not a Results table, load all columns
	}

	// Iterates through all of the column headers and sets up the Results table to match
	noPos = 3;
	for (j=k; j<(noPos+k); j++){
		setResult(cols[j],0,0);
	}
	// Housekeeping to make sure no random values are stored in the table		
	run("Clear Results");
	
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
