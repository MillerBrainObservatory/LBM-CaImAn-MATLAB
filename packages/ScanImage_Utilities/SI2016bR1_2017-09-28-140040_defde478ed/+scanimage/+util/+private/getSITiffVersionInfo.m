function [verInfo] = getSITiffVersionInfo(fileHeader)
%   Analize a tiff-header frame-string to determine the scanimage version it came from
%   The tags provided by the ScanImage header are insufficient to keep track of released 
%   versions of ScanImage, hence we'll provide a structure called verInfo to help us simplify
%   version detection

    verInfo = struct();
    verInfo.infoFound = false;

    %TODO: Make sure this works for the case where this property doesn't exist?
    try
        verInfo.SI_MAJOR = fileHeader.SI.VERSION_MAJOR;
        verInfo.SI_MINOR = fileHeader.SI.VERSION_MINOR;
        verInfo.TIFF_FORMAT_VERSION = fileHeader.SI.TIFF_FORMAT_VERSION;
        verInfo.infoFound = true;
    catch
        most.idioms.dispError('Cannot find SI and/or Tiff version properties in Tiff header.\n');
        return;
    end

    %% Determine if the scanner is linear or resonant
    try
        verInfo.ImagingSystemType = fileHeader.SI.hScan2D.scannerType;
    catch
        verInfo.ImagingSystemType = fileHeader.SI.imagingSystem;
    end
end


%--------------------------------------------------------------------------%
% getSITiffVersionInfo.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
