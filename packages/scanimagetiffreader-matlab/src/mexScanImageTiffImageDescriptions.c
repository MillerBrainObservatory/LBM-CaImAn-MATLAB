#include <stdint.h>
#define char16_t int16_t
#include "mex.h"
#include "tiff.reader.api.h"

/// \returns a cell array of image description strings
/// Usage: out=mexScanImageTiffImageDescriptions(handle);
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

    mwSize n=ScanImageTiffReader_GetImageDescriptionCount(&reader);
    if(reader.log) mexErrMsgTxt(reader.log);

    plhs[0]=mxCreateCellArray(1,&n);
    for(mwSize i=0;i<n;++i) {
        size_t nbytes=ScanImageTiffReader_GetImageDescriptionSizeBytes(&reader,(int)i);
        if(reader.log) mexErrMsgTxt(reader.log);

        if(nbytes){
            void* buf=mxCalloc(1,nbytes);
            mxAssert(buf,"Allocation failed");
            ScanImageTiffReader_GetImageDescription(&reader,(int)i,buf,nbytes);
            if(reader.log) mexErrMsgTxt(reader.log);
        
            mxArray* a=mxCreateString(buf);
            mxAssert(a,"Allocation failed");
            mxFree(buf);
            mxSetCell(plhs[0],i,a);
        } else {
            mxSetCell(plhs[0],i,mxCreateString(""));
        }

        
        
    }
}

