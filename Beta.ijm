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
tnW = 1.5;
tnH = 1.5;
tnZ = 1.5;
vxW = 0.062;
makeRectangle(2002, 259, (tnW/vxW), (tnH/vxW));
run("Crop");
// Add cross hairs for center
makePoint(((tnW/vxW)/2), ((tnW/vxW)/2), "tiny yellow dot add");
setFont("SansSerif",4);
//makeText(id, 1, ((tnW/vxW)-2), "add");
drawString(id, 1, ((tnW/vxW)-2));