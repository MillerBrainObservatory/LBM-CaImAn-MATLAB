function [Aout,imgInfo] = streamOutputQuit(hTif,numImages,si_ver,silent)
% This function returns available data and should be followed by an exit call
% The header is assumed to have been set prior to calling this method
%
    if nargin < 4
        silent = false;
    end
    
    %% Preallocate image data
    switch hTif.getTag('SampleFormat')
        case 1
            imageDataType = 'uint16';
        case 2
            imageDataType = 'int16';
        otherwise
            assert('Unrecognized or unsupported SampleFormat tag found');
    end

    numLines = hTif.getTag('ImageLength');
    numPixels = hTif.getTag('ImageWidth');

    Aout = zeros(numLines,numPixels,numImages,imageDataType);    
    imgInfo.numImages = numImages;	% Only the number of images is reliable
    imgInfo.filename = hTif.FileName;	% As well as the filename, of course
    imgInfo.si_ver = si_ver;	% ScanImage version 

    for idx = 1:numImages
        hTif.setDirectory(idx);
        Aout(:,:,idx) = hTif.read();
    end

    if ~silent
        most.idioms.warn('Returning default, uncategorized stream of Tiff frames');
    end
end


%--------------------------------------------------------------------------%
% streamOutputQuit.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
