function [A, B] = deInterleaveScanImage(vol)
%I is a 3D volume
 A = I(:,:,1:2:end);
 B = I(:,:,2:2:end);