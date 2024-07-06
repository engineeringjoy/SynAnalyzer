/*
 * For testing code before integrating into main macro
 */

// Current goal is to generate the summary image using the montage tool
//  Will need to scale the images so that they pair nicely.
selectImage("WSS_031.01.T3.01.Zs.4C.PMMap.PostSyn.png");
run("Images to Stack", "method=[Copy (top-left)] use keep");
run("Make Montage...", "columns=3 rows=1 scale=1 label");
selectImage("Stack");
run("Make Substack...", "slices=1");
selectImage("WSS_031.01.T3.01.Zs.4C.PMMap.PostSyn.png");
makeLine(16, 46, 16, 46);
run("Bin...");
run("Scale...", "x=2 y=2 width=1248 height=660 interpolation=Bilinear average create");