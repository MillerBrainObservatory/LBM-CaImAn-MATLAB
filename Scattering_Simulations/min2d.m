function [mn,inds] = min2d(I)

[mnvec,indsy] = min(I);
[mn,indx]  = min(mnvec);
indy = indsy(indx);

inds = [indx indy];