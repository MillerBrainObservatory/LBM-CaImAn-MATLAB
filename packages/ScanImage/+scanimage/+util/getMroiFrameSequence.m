function [frames, roiGroup, header, imageData, imgInfo] = getMroiFrameSequence(varargin)
%% function [dum] = getMroiDataFromTiff(varargin)
% Opens a ScanImage TIF file and returns a cell array of scanimage.mroi.RoiDataSimple objects containing the information found in 
% the TIF file.
%
%% SYNTAX
%   getMroiDataFromTiff()
%   getMroiDataFromTiff(filename)
%   getMroiDataFromTiff(filename, debugMode)
%   [roiDataCellArray] = getMroiDataFromTiff(...)
%       filename: Name of TIF file, with or without '.tif' extension. If omitted, a dialog is launched to allow interactive selection.
%       roiDataCellArray: Cell array of scanimage.mroi.RoiDataSimple objects containing the Roi information found in the TIFF file
%
%	INPUT
%		filename:	full path to the tiff file containing mroi data
%		debug:	 	Set to true if displaying detailed information of the tiff file is desired
%	OUTPUT
%		roiData:	cell array of scanimage.mroi.RoiDataSimple objects containing the information found in the TIF file.
%		roiGroup:	roiGroup extracted from the tiff file
%       header:     image header info
%       imageData:  raw image data
%
%% NOTES
%   This function currently only supports RG-mode Rois information.  
%   If the TIFF file indicates that MROI mode was not enabled, the function returns a warning and an empty roiData cell array.
%   Previous versions of this utility did not support Step-FastZ when using non-default Zs
%       
    %+++ We might need support for different sized rois
    if nargin == 1 || nargin == 2
        % DEBUG
        if nargin == 2 && varargin{2} == true
          disp(varargin{1});
        end
        [header, imageData, imgInfo] = scanimage.util.opentif(varargin{1},'raw');
        roiGroup = scanimage.util.readTiffRoiData(varargin{1},header);
    else
        frames = [];
        roiGroup = [];
        header = [];
        imageData = [];
        imgInfo = [];
        disp('No filename provided');
		return;
    end
    
    if isfield(header, 'scanimage')
        header.SI = header.scanimage.SI;
    end
    
    % support for old free tifs
    if isempty(roiGroup)
        roiGroup = scanimage.mroi.RoiGroup;
        sf = scanimage.mroi.scanfield.fields.RotatedRectangle;
        sf.centerXY = mean(header.SI.hRoiManager.imagingFovDeg,1);
        sf.sizeXY = max(header.SI.hRoiManager.imagingFovDeg,[],1) - min(header.SI.hRoiManager.imagingFovDeg,[],1);
        roi = scanimage.mroi.Roi;
        roi.add(0,sf);
        roiGroup.add(roi);
    end
    
    zs = header.SI.hStackManager.zs;
    for idx = numel(zs) : -1 : 1
        z = zs(idx);
        [df, ind] = min(abs(z-roiGroup.zs));
        if df < 1e-4
            z = roiGroup.zs(ind);
        end
        
        [zSfs{idx},zRois{idx}] = roiGroup.scanFieldsAtZ(z);
        zSfs{idx} = [zSfs{idx}{:}];
        zRois{idx} = [zRois{idx}{:}];
    end
    
    Nfr = floor(imgInfo.numImages/imgInfo.numChans);
    frames = repmat(struct('timestamp',[],'z',[],'roiData',struct('roi',{},'scanfield',{},'imageData',{})),Nfr,1);
    fps = header.SI.hStackManager.framesPerSlice / header.SI.hScan2D.logAverageFactor;
    si = 1;
    di = 1;
    
    sfSkipLines = round(header.SI.hScan2D.flytoTimePerScanfield/header.SI.hRoiManager.linePeriod) * strcmp(header.SI.hScan2D.scannerType,'Resonant');
    
    while di <= Nfr
        for s = 1:imgInfo.numSlices
            z = zs(s);
            
            for f = 1:fps
                frames(di).timestamp = header.frameTimestamps_sec(si);
                frames(di).z = z;
                
                sl = 0;
                
                % rois
                for r = 1:numel(zRois{s})
                    res = fliplr(zSfs{s}(r).pixelResolutionXY);
                    dat = zeros([res imgInfo.numChans]);
                    % colors
                    for c = 1:imgInfo.numChans
                        dat(:,:,c) = imageData((1:res(1)) + sl,1:res(2),si+c-1);
                    end
                    frames(di).roiData(r) = struct('roi',zRois{s}(r),'scanfield',zSfs{s}(r),'imageData',dat);
                
                    sl = sl + sfSkipLines + res(1);
                end
                
                si = si+imgInfo.numChans; if si > imgInfo.numImages; return; end;
                di = di+1; if di > imgInfo.numImages; return; end;
            end
        end
    end
end


%--------------------------------------------------------------------------%
% getMroiFrameSequence.m                                                   %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
