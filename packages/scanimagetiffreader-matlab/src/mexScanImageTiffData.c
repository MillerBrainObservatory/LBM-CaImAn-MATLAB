#include <stdint.h>
#define char16_t int16_t
#include <nd.h>
#include "mex.h"
#include "tiff.reader.api.h"

static mxClassID mxtypeof(enum nd_type t) {
    static const mxClassID table[]={
        mxUINT8_CLASS,  /* nd_u8 */
        mxUINT16_CLASS, /* nd_u16 */
        mxUINT32_CLASS, /* nd_u32 */
        mxUINT64_CLASS, /* nd_u64 */
        mxINT8_CLASS,   /* nd_i8  */
        mxINT16_CLASS,  /* nd_i16 */
        mxINT32_CLASS,  /* nd_i32 */
        mxINT64_CLASS,  /* nd_i64 */
        mxSINGLE_CLASS, /* nd_f32 */
        mxDOUBLE_CLASS  /* nd_f64 */
    };
    return table[t];
}

static size_t bytesof(const struct nd *shape) {
    static const size_t bpp[]={
        1,/* nd_u8 */
        2,/* nd_u16 */
        4,/* nd_u32 */
        8,/* nd_u64 */
        1,/* nd_i8  */
        2,/* nd_i16 */
        4,/* nd_i32 */
        8,/* nd_i64 */
        4,/* nd_f32 */
        8,/* nd_f64 */
    };
    return bpp[shape->type]*shape->strides[shape->ndim];
}

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

    struct nd shape=ScanImageTiffReader_GetShape(&reader);
    if(reader.log) mexErrMsgTxt(reader.log);
    mwSize dims[10]={0};
    for(int i=0;i<10;++i)
      dims[i]=(mwSize)shape.dims[i];
    plhs[0]=mxCreateNumericArray(shape.ndim,dims,mxtypeof(shape.type),mxREAL);
    void *data=mxGetData(plhs[0]);
    ScanImageTiffReader_GetData(&reader,data,bytesof(&shape));
    if(reader.log) mexErrMsgTxt(reader.log);
}
