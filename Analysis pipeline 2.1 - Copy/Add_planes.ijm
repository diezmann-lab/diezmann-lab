// set up
run("Bio-Formats Macro Extensions"); // to help open images "automatically"
dir = getDir("Select experimental day folder"); // Experiment folder
nads = getFileList(dir); // lists every folder, i.e. Early_Pach_S1G1R1/

//for (i = 0; i < nads.length; i++) {
	//print(i + ": " + nads[i]);
//}

//open("E:/File management testing/Experiments/Early_Pach_S1G1R1/")

Nnads = nads.length;
// currently opens all files at once lol
for (i = 0; i < Nnads; i++) {
	nadpath = dir + nads[i]; 
	imgpath = getFileList(nadpath);
	for (j = 0; j < imgpath.length; j++) {
		img = nadpath + imgpath[j];
		size = File.length(img); // in bytes
		if ((endsWith(img, ".tif")||endsWith(img,".tiff"))&&size<10000000) { // 10 MB for now...
			Ext.openImagePlus(img);
		} 
		}
	// run image processing here
	list = getList("image.titles");
	im1 = list[0];
	im2 = list[1];
	selectImage(1);
	imagedir = getInfo("image.directory"); //grab directory
	imageCalculator("Add create stack",im1,im2); // add planes
	selectImage(3);
	run("Flip Vertically", "stack");
	run("8-bit");
	run("Brightness/Contrast...");
	waitForUser("Adjust if needed, hit apply, then click OK");
	selectImage(3);
	run("32-bit");
	saveAs(imagedir + "Add_planes.tif");
	close('*'); // close all windows to start fresh
	}
	

