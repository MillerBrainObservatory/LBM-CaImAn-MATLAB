#include <stdint.h>
#define char16_t int16_t
#include "mex.h"
#include "tiff.reader.api.h"

/** Usage: mexScanImageTiffClose(handle) */
MEXFUNCTION_LINKAGE
void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray* prhs[]) {
    mxAssert(nrhs==1,"Expected one right-hand side argument.");
    mxAssert(nlhs==0,"Expected no left-hand side arguments.");
    mxAssert(mxGetClassID(prhs[0])==mxUINT64_CLASS,"Expected first argument to be a handle.");
    void** ph=mxGetData(prhs[0]);
    struct ScanImageTiffReader reader={
        .handle=*ph,
        .log=0
    };

    ScanImageTiffReader_Close(&reader);
    if(reader.log) mexErrMsgTxt(reader.log);
}
