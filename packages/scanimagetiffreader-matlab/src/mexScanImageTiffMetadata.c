#include <stdint.h>
#define char16_t int16_t
#include "mex.h"
#include "tiff.reader.api.h"

MEXFUNCTION_LINKAGE
void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray* prhs[]) {
    mxAssert(nrhs==1,"Expected one right-hand side argument.");
    mxAssert(nlhs==1,"Expected one left-hand side arguments.");
    mxAssert(mxGetClassID(prhs[0])==mxUINT64_CLASS,"Expected first argument to be a handle.");
    void** ph=mxGetData(prhs[0]);
    struct ScanImageTiffReader reader={
        .handle=*ph,
        .log=0
    };

    size_t nbytes=ScanImageTiffReader_GetMetadataSizeBytes(&reader);
    if(reader.log) mexErrMsgTxt(reader.log);

    if(nbytes){
        char* buf=mxCalloc(1,nbytes);
        mxAssert(buf,"Allocation failed.");
        ScanImageTiffReader_GetMetadata(&reader,buf,nbytes);
        if(reader.log) mexErrMsgTxt(reader.log);
        plhs[0]=mxCreateString(buf);
    } else {
        plhs[0]=mxCreateString("");
    }

}

