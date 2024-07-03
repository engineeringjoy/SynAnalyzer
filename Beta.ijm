/*
 * Module for drawing pillar-modiolar axis:
 *	1. Generate the YZ projection
 *	2. Make a composite image
 *	3. Have the user draw a line
 *	
 *	Leaving off 1 JUL 2024 - 8:30 PM 
 *	The code below works when the .czi image is already open. 
 */

/*
run("Reslice [/]...", "output=0.310 start=Left");
run("Z Project...", "projection=[Max Intensity]");

run("Make Composite");
run("Flatten");
setTool("line");
waitForUser("Draw the pillar-modilar axis across the\nbasolateral region of the hair cell,\nthen press enter.");

roiManager("Add");
getLine(x1, y1, x2, y2, lineWidth);
print("X-Start = "+x1);
*/

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
Dialog.create("Create Substack");
Dialog.addMessage("Indicate the channels and slices to include in the analysis.");
Dialog.addCheckboxGroup(channels, 2, labels, defaults);
Dialog.addString("Slice Start","1");
Dialog.addString("Slice End", slices);
Dialog.show();
// Get the information from the dialog box
include = newArray(channels)
inCount = 0;
for (i = 0; i < lengthOf(labels); i++) {
	if (Dialog.getCheckbox() == 1){
		include[i] = "Yes";
		inCount++;
		print("Including channel "+toString(i));
	}else{
		include[i] = "No";
		print("Excluding channel "+toString(i));
	}
}
// Make an array of the channels to include
chToInclude = newArray(inCount);
for (i = 0; i < lengthOf(include); i++) {
	if (include[i] == "Yes") {
		// Channel indexing starts at 1
		chToInclude[i] = i+1;
	}
}
Array.print(chToInclude);
slStart = Dialog.getString();
slEnd = Dialog.getString();

//Make & save a max proj to help user with visualizing surfaces based on inclusion criteria
run("Make Substack...", "channels="+chToInclude+" slices="+slStart+"-"+slEnd);
run("Z Project...", "projection=[Max Intensity]");