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

getDimensions(width, height, channels, slices, frames);
getVoxelSize(vW, vH, vD, unit);
// Get the information about the ROI 
/*
Table.open(batchpath+"/SAR.Analysis/SynAnalyzerBatchMaster.csv");
xSt = Table.get("BB X0", imIndex);
xEnd = Table.get("BB X1", imIndex);
zSt = Table.get("ZStart", imIndex);
zEnd = Table.get("ZEnd", imIndex);
*/
xSt = 500;
xEnd = 1000;
zSt = 2;
zEnd = 66;
// Crop the z-stack accordingly
makeRectangle(xSt, 0, xEnd-xSt, height);
run("Crop");
// Make the ortho projection
run("Reslice [/]...", "output="+vD+" start=Left flip");
run("Z Project...", "projection=[Max Intensity]");
run("Make Composite");
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