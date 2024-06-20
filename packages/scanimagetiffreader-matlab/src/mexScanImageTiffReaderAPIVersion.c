#include <stdint.h>
#define char16_t int16_t
#include "mex.h"
#include "tiff.reader.api.h"

MEXFUNCTION_LINKAGE
void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray* prhs[]) {
	mxAssert(nrhs==0,"Expected no right-hand side arguments.");
	plhs[0]=mxCreateString(ScanImageTiffReader_APIVersion());
}
