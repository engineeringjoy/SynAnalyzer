/* ***   Setup the arrays for indexing the XYZ    ****
	nRows = -floor(-(Table.size/10));
	arrLet = newArray("A","B","C","D","E","F","G","H","I","J","K");
	arrNum = newArray(nRows);
	for (i = 0; i < nRows; i++) {
		arrNum[i]=i+1;
	}
	// Iterate through each XYZ, assign an index, make/save thumbnail, update XYZ table
	inL = 0;
	inN = 0;
	
	if (inL == lengthOf(arrLet)) {
			inL = 0;
			inN++;
		}
	inXYZ = arrLet[inL]+toString(arrNum[inN]);
	inL++;
	// Set the index for this XYZ
	Table.set("XYZ_Index",i,inXYZ);
*/

// SYNAPSE COUNTING 
/* -- Original method for synapse counting--
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
*/ 

/* Original code for updating synapse status based on user input
 // Proceed with having the user add IDs for terminals with the marker
	Dialog.create("Get SynapseMarker Info");
	Dialog.addMessage("For all fields below, enter the ID numbers for each category (e.g., '234, 214'):");
	Dialog.addString("Doublets:", "0, 1, 2", 50);
	Dialog.addString("Orphans:", "3, 4, 5", 50);
	Dialog.addString("Garbage:", "247, 253", 50);
	Dialog.show();
	idsDbArr= split(Dialog.getString(), ",");
	idsOrArr = split(Dialog.getString(), ",");
	idsGrArr = split(Dialog.getString(), ","); 
 // Change synapse status for those XYZs that the user identified
	// Mark doublets
	for (i = 0; i < lengthOf(idsDbArr); i++) {
		Table.set("SynapseStatus",idsDbArr[i],"Doublet");
	}
	// Mark orphans
	for (i = 0; i < lengthOf(idsOrArr); i++) {
		Table.set("SynapseStatus",idsOrArr[i],"Orphan");

	}
	// Mark garbage
	for (i = 0; i < lengthOf(idsGrArr); i++) {
		Table.set("SynapseStatus",idsGrArr[i],"Garbage");
	}
	Table.update;
	
	// Calculate the number of synapses based on information given
	nT = Table.get(fName+"XYZinROI", imIndex);
	nSyn = nT+lengthOf(idsDbArr)-lengthOf(idsOrArr)-lengthOf(idsGrArr);
 */

/*
	// Code for projecting into the X direction (generating a YZ-view of the image)
	// I don't think this is any better than the other projection approach but keeping the code in place
	//  in case a user wants to try it. 
	selectImage(imName+"-1.czi");
	run("Make Substack...", "slices="+zSt+"-"+zEnd);
	makeRectangle(cropX, cropY, (tnW/vxW), (tnH/vxW));
	run("Crop");
	run("Reslice [/]...", "output="+vxD+" start=Left flip");
	run("Z Project...", "projection=[Max Intensity]");
	run("Make Composite");
	run("Flatten");
*/

/*  ORIGINAL FUNCTION FOR GENERATING THUMBNAILS - PRE 8/5/24 UPDATES
 // GENERATE THUMBNAILS 
function genThumbnails(batchpath, imName, fName, imIndex) {
	// Update the user about the analysis stage
	waitForUser("Beginning thumbnail generation process.");
	// Setup subfolders for storing thumbnails associated with this image
	File.makeDirectory(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/");
	// Get parameters for substack
	Table.open(batchpath+"/SAR.Analysis/"+"SynAnalyzerBatchMaster.csv");
	synChArr = Table.getString("Synaptic Marker Channels", imIndex);
	vxW = Table.get("Voxel Width (um)", imIndex);
	vxD = Table.get("Voxel Depth (um)", imIndex);
	slStart = Table.get("ZStart", imIndex);
	slEnd = Table.get("ZEnd", imIndex);
	bbXZ = Table.get("BB X0", imIndex);
	bbXO = Table.get("BB X1", imIndex);
	bbYZ = Table.get("BB Y0", imIndex);
	bbYT = Table.get("BB Y2", imIndex);
	// Open the raw image
	open(batchpath+"RawImages/"+imName+".czi");
	// -- Subtract background from the entire z-stack
	run("Subtract Background...", "rolling=50 stack");
	// Generate a max projection composite image that will be labelled with points of interest
	run("Make Substack...", "channels="+synChArr+" slices="+slStart+"-"+slEnd);
	selectImage(imName+".czi");
	close();
	// Allow the user to make any adjustments to the display properties before proceeding 
	waitForUser("Make any necessary adjustments to brightness/constrast, etc. before thumbnail generation begins.");
	// Load the XYZs & allow the user to specify the sorting order
	Table.open(batchpath+"SAR.Analysis/"+imName+".XYZ."+fName+".csv");
	labels = newArray("ID", "Volume");
	defaults = newArray("0", "1");
	Dialog.create("Get Sorting Order");
	Dialog.addMessage("Indicate the desired sorting order for thumbnail generation.");
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
			  "Defaulting to sorting by ID.");
		sort = "ID";
	}
	Table.sort(sort);
	Table.update;
	// Open the substack MPI for labelling purposes
	open(batchpath+"SAR.RawMPIs/"+imName+".RawMPI.tif");
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
		vol = Table.get("Volume_um3", i);
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
					if (sort == "Volume_um3"){
						save(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/"+imName+".TN."+i+"."+id+".png");
					}else{
						save(batchpath+"SAR.Thumbnails/"+imName+"."+fName+"/"+imName+".TN."+id+".png");
					}
					
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
	// Save the annotated MPI as png to allow for annotating
	selectImage(imName+".RawMPI.tif");
	save(batchpath+"SAR.AnnotatedMPIs/"+imName+".AnnotatedMPI.ROIXYZ."+fName+".png");
	// Rescale the image for visualization and summary image generation
	// . Get the dimensions of the image
	getDimensions(width, height, channels, slices, frames);
	// . Calculate the scaling factor and output dimensions
	scaleF = round(annImW/width);
	outputW = scaleF*width;
	outputH = scaleF*height;
	run("Scale...", "x="+scaleF+" y="+scaleF+" width="+outputW+" height="+outputH+" interpolation=Bilinear average create");
	// Add the original ROI as defined by the user
	makeRectangle(bbXZ*scaleF, bbYZ*scaleF, bbXO-bbXZ*scaleF, bbYT-bbYZ*scaleF);
	run("Draw", "slice");
	// .  Scale the annotated image
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
	close("*.csv");
	
}
 */