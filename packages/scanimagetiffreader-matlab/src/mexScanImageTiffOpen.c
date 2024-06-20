#include <stdint.h>
#define char16_t int16_t
#include "mex.h"
#include "tiff.reader.api.h"

/** Usage: out=mexScanImageTiffOpen(filename) */
MEXFUNCTION_LINKAGE
void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray* prhs[]) {
    mxAssert(nrhs==1,"Expected one right-hand side argument.");
    mxAssert(nlhs==1,"Expected one left-hand side argument.");
    mxAssert(mxGetClassID(prhs[0])==mxCHAR_CLASS,"Expected first argument to be a string.");
    char filename[1024]={0};
    mxGetString(prhs[0],filename,sizeof(filename));

    ScanImageTiffReader reader=ScanImageTiffReader_Open(filename);
    if(reader.log) mexErrMsgTxt(reader.log);

    mwSize dims[]={1};
    plhs[0] = mxCreateNumericArray(1,dims,mxUINT64_CLASS,mxREAL);
    void **data=mxGetData(plhs[0]);
    *data=reader.handle;
}

/*
FIXME: imput text encoding
*/
