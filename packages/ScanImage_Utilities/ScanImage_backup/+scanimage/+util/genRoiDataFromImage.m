function [roiData roiGroup] = genRoiDataFromImage(imgData, defaultRoiGroup)
%% function [roiData] = genRoiDataFromImage(varargin)
% Generates a roiDataSimple object from an image using a provided "default" RoiGroup
% If more than one image is supplied. It assumes they are all consecutive slices in the 
% same volume and assigns the appropriate stackZs values. 
%
%% SYNTAX
%   
%   [roiData] = genRoiDataFromImage(imgData, defaultRoiGroup)
%   [roiData roiGroup] = genRoiDataFromImage(imgData, defaultRoiGroup)
%
%	INPUT
%   imgData:          2D array containing image data
%   defaultRoiGroup:  desired roiGroup to use 
%	OUTPUT
%		roiData:	cell array of a single scanimage.mroi.RoiDataSimple object containing the combined information from the image and the defaultRoiGroup
%		roiGroup:	defaultRoiGroup used
%
    roiData = [];

    if nargin ~= 2
        most.idioms.warn('Unexpected number of inputs');
		return;
    end

    dataDims = size(imgData);
    dataNumDims = length(dataDims);
    if dataNumDims == 2
		numSlices = 1;
	elseif dataNumDims == 3
		numSlices = dataDims(3);
	else
		numSlices = dataDims(3);
		most.idioms.warn('Unexpected number of image dimensions');
	end

    numImageCategories = 1;
    numChannels = 1;
    numFrames = 1;
    numVolumes = 1;

    [roiGroup] = defaultRoiGroup;

    % Get the number of rois and other general mroi information
    numRois = 1;
    numLinesBetweenScanfields = 0;
    stackZsAvailable = 0:numSlices-1;
    channelSave = 1;

    % Description array for mapping roi-image data to each roiData object
    roiInfo = zeros(numRois,length(stackZsAvailable));
    roiImgHeightInfo = zeros(numRois,length(stackZsAvailable));

    % Processing rois
    for i = 1:numRois
        roiData{i} = scanimage.mroi.RoiDataSimple();
        roiData{i}.hRoi = roiGroup.rois(i);
        roiData{i}.channels = channelSave;

        % If there's a single roi defined, then project to all available z spaces
        % If there's more, interpolate between them
        %+++ Must take into account discarded frames?
        zsAvailable = stackZsAvailable;
        zsHasRoi = zeros(size(zsAvailable));


        lenRoiZs = length(roiData{i}.hRoi.zs);
        %+++ This value shouldn't be 0, add error checking?
        if lenRoiZs == 1
            % The roi extends from -Inf to Inf
            zsHasRoi = ones(size(zsAvailable));
            %The height doesn't change for the case of single-scanfields
            roiImgHeightInfo(i,:) = roiData{i}.hRoi.scanfields(1).pixelResolution(2) * ones(size(zsAvailable));
        else
            %If opentif removes the discard-frames correctly we can assume that roi indices are between 0 and numSlices -1
            minIdx = roiData{i}.hRoi.zs(1) + 1;
            maxIdx = roiData{i}.hRoi.zs(end) + 1;
            zsHasRoi(1,minIdx:maxIdx) = ones(1,maxIdx - minIdx + 1);
            numScanfields = length(roiData{i}.hRoi.scanfields);  % This will be 2 for our tests

            % This handles multiple interpolation sections
            for m = 1:numScanfields - 1
                fstIdx = roiData{i}.hRoi.zs(m) + 1;
                lstIdx = roiData{i}.hRoi.zs(m+1) + 1;

                cntImg = 1;
                numIntSections = lstIdx-fstIdx+1;
                for k = fstIdx:lstIdx
                    interVal = (cntImg-1)/(numIntSections-1);
                    currScanfield = roiData{i}.hRoi.scanfields(1).interpolate(roiData{i}.hRoi.scanfields(2),interVal);
                    roiImgHeightInfo(i,k) = currScanfield.pixelResolution(2);
                    cntImg = cntImg+1;
                end
            end
        end
        roiInfo(i,:) = zsHasRoi;
        roiData{i}.zs = zsAvailable(find(zsHasRoi == 1));
    end

	% NOTE: Currently we only support slices within a volume for this particular method
	roiImageCnt = zeros(1,numRois);
	currChan = 1;
	currVol = 1;
	for currSlc = 1:numSlices 
		
		% See if which rois are in the current image, if any
		numCurrImageRois = sum(roiInfo(:,currSlc));
		roiIds = find(roiInfo(:,currSlc) == 1)';

		cnt = 1;
		prevRoiImgHeight = 0;
		for roiIdx = roiIds
			% The width of the scanfield doesn't change
			roiImgWidth = roiData{roiIdx}.hRoi.scanfields(1).pixelResolution(1);
			% The height of the scanfield depends on the interpolation of scanfields within existing fields
			roiImgHeight = roiImgHeightInfo(roiIdx,currSlc);

			roiImgWidthRange = 1:roiImgWidth;
			roiImgHeightRange = 1:roiImgHeight;
			roiImageCnt(roiIdx) = roiImageCnt(roiIdx) + 1;

			if cnt == 1 
				% The first one will be at the very top
				imgOffsetX = 0; 
				imgOffsetY = 0; 
			else
				% For the rest of the rois, there will be a recurring numLinesBetweenScanfields spacing
				imgOffsetY = imgOffsetY + prevRoiImgHeight + numLinesBetweenScanfields;
			end
			% The third cell in imageData is for the subset of i corresponding to the existing zs in that 
			% roiData object
			roiData{roiIdx}.imageData{currChan}{currVol}{roiImageCnt(roiIdx)} = ...
				imgData(imgOffsetY+roiImgHeightRange, imgOffsetX+roiImgWidthRange,currSlc);
			cnt = cnt+1;
			%+++ change to allow for different scanfields sizes
			prevRoiImgHeight = roiData{roiIdx}.hRoi.scanfields(1).pixelResolution(2);
		end
	end
end


%--------------------------------------------------------------------------%
% genRoiDataFromImage.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
