function [roiData, roiGroup, header, imageData, imgInfo] = getMroiDataFromTiff(varargin)
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
        [header, imageData, imgInfo, raw] = scanimage.util.opentif(varargin{1});
        assert(~raw,'Opentif was unable to parse data.');
    else
        roiData = [];
        roiGroup = [];
        header = [];
        imageData = [];
        imgInfo = [];
        disp('No filename provided');
		return;
    end

% even in non mroi mode there should still be roi data
%     mroiEnabled =  h.SI.hRoiManager.mroiEnable;
%     if mroiEnabled == 0
%         disp('No mroi data found');
%         return
%     end

    numImageCategories = length(size(imageData));
    numChannels = 1;
    numFrames = 1;
    numSlices = 1;
    numVolumes = 1;
    dataDim = size(imageData);
    switch numImageCategories
        case 2
            % Use parameter values set above and continue
        case 3
            % Use parameter values set above and continue
            numChannels = dataDim(3);
        case 4
            % Single plane acquisition
            numChannels = dataDim(3);
%             numVolumes = dataDim(4);
            numFrames = dataDim(4);
        case 5
            % Slices but only one volume
            numChannels = dataDim(3);
            numFrames = dataDim(4);
            numSlices = dataDim(5);
        case 6
            % Slices in multiple volumes 
            numChannels = dataDim(3);
            % Dont have to worry about frames, should alwasy be 1 for
            % multi-volume as volumes are more a fastZ mechanic.
            numSlices = dataDim(5);
            numVolumes = dataDim(6);
        otherwise
            disp('Unexpected image structure from opentif');
            return;
    end

    [roiGroup] = scanimage.util.readTiffRoiData(varargin{1},header);
    
    if isempty(roiGroup)
        error('This tiff does not contain ROI data.');
    end

    % Get the number of rois and other general mroi information
    numRois = numel(roiGroup.rois);
    
    if isfield(header, 'scanimage')
        header.SI = header.scanimage.SI;
    end
    
    numLinesBetweenScanfields = round(header.SI.hScan2D.flytoTimePerScanfield/header.SI.hRoiManager.linePeriod);
    stackZsAvailable = header.SI.hStackManager.zs(1:numSlices);
    %disp(['numLinesBetweenScanfields = ' num2str(numLinesBetweenScanfields)]);

    % Description array for mapping roi-image data to each roiData object
    roiInfo = zeros(numRois,length(stackZsAvailable));
    roiImgHeightInfo = zeros(numRois,length(stackZsAvailable));
    %roiImgHeightInfo = cell(numRois));

    % DEBUG
    if nargin == 2 && varargin{2} == true
      disp(['numChannels = ' num2str(numChannels)]);
      disp(['numFrames = ' num2str(numFrames)]);
      disp(['numSlices = ' num2str(numSlices)]);
      disp(['numVolumes = ' num2str(numVolumes)]);
      disp(['numRois = ' num2str(numRois)]);
    end

    % Processing rois
    for i = 1:numRois
        roiData{i} = scanimage.mroi.RoiDataSimple();
        roiData{i}.hRoi = roiGroup.rois(i);
        roiData{i}.channels = header.SI.hChannels.channelSave;

        % If there's a single roi defined, then project to all available z spaces
        % If there's more, interpolate between them
        %+++ Must take into account discarded frames?

        lenRoiZs = length(roiData{i}.hRoi.zs);
        %+++ This value shouldn't be 0, add error checking?
        if lenRoiZs == 1
            if roiData{i}.hRoi.discretePlaneMode
                zsHasRoi = stackZsAvailable == roiData{i}.hRoi.zs(1);
                roiImgHeightInfo(i,zsHasRoi) = roiData{i}.hRoi.scanfields(1).pixelResolution(2);
            else
                % The roi extends from -Inf to Inf
                zsHasRoi = ones(size(stackZsAvailable));
                %The height doesn't change for the case of single-scanfields
                roiImgHeightInfo(i,:) = roiData{i}.hRoi.scanfields(1).pixelResolution(2) * ones(size(stackZsAvailable));
            end
        else
            zsHasRoi = zeros(size(stackZsAvailable));
            % If opentif removes the discard-frames correctly we can assume that roi indices are between 0 and numSlices -1
            % The following assumes that all available zs are unique, which is not necessarily the case when the user
            % specifies zs. We might need to save a pair of the z value and its corresponding index to allow the latter mode
            minVal = roiData{i}.hRoi.zs(1);
            maxVal = roiData{i}.hRoi.zs(end);
            idxRange = intersect(find(stackZsAvailable >= minVal),find(stackZsAvailable <= maxVal));
            
            for j = 1:numel(idxRange)
                s = idxRange(j);
                sf = roiData{i}.hRoi.get(stackZsAvailable(s));
                if ~isempty(sf)
                    roiImgHeightInfo(i,s) = sf.pixelResolution(2);
                    zsHasRoi(s) = true;
                end
            end
        end
        roiInfo(i,:) = zsHasRoi;
        roiData{i}.zs = stackZsAvailable(find(zsHasRoi == 1));
    end

    for currChan = 1:numChannels
        for currVol = 1:numVolumes
            roiImageCnt = zeros(1,numRois);
            for currSlc = 1:numSlices 
                %+++Change me, must take into account frames without data at the end of a volume
                %+++ We are using the whole range of slices for now
                % This will only be the case where we have one scanfield defined 
                % In a roi
                
                % See if which rois are in the current image, if any
                numCurrImageRois = sum(roiInfo(:,currSlc));
                roiIds = find(roiInfo(:,currSlc) == 1)';

                cnt = 1;
                prevRoiImgHeight = 0;
                for roiIdx = roiIds
                    %this code needs revision for linscan mroi tiffs!!
                    if cnt == 1 
                        % The first one will be at the very top
                        imgOffsetX = 0; 
                        imgOffsetY = 0; 
                    else
                        % For the rest of the rois, there will be a recurring numLinesBetweenScanfields spacing
                        imgOffsetY = imgOffsetY + roiImgHeight + numLinesBetweenScanfields;
                    end
                    
                    % The width of the scanfield doesn't change
                    roiImgWidth = roiData{roiIdx}.hRoi.scanfields(1).pixelResolution(1);
                    % The height of the scanfield depends on the interpolation of scanfields within existing fields
                    roiImgHeight = roiImgHeightInfo(roiIdx,currSlc);
                    
                    roiImgWidthRange = 1:roiImgWidth;
                    roiImgHeightRange = 1:roiImgHeight;
                    roiImageCnt(roiIdx) = roiImageCnt(roiIdx) + 1;
                    
                    % The third cell in imageData is for the subset of i corresponding to the existing zs in that 
                    % roiData object
                    for currFrame = 1:numFrames
                        if numImageCategories == 4
                            roiData{roiIdx}.imageData{currChan}{currVol}{roiImageCnt(roiIdx)}{currFrame} = ...
                                imageData(imgOffsetY+roiImgHeightRange, imgOffsetX+roiImgWidthRange,currChan,currFrame);
                        else
                            roiData{roiIdx}.imageData{currChan}{currVol}{roiImageCnt(roiIdx)}{currFrame} = ...
                                imageData(imgOffsetY+roiImgHeightRange, imgOffsetX+roiImgWidthRange,currChan,currFrame,currSlc,currVol);
                        end
                    end
                    cnt = cnt+1;
                end
            end
        end
    end
end


%--------------------------------------------------------------------------%
% getMroiDataFromTiff.m                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
