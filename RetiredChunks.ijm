// Setup the arrays for indexing the XYZ
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