function [header,Aout,imgInfo,rawStream] = opentif(varargin)
%% OPENTIF   
% Reads a ScanImage TIFF file
%% Description
% Opens a ScanImage TIF file, extracting its header information and, if specified, stores all of image contents as output array Aout if specified. 
% By default, Aout, if specified for output, is of size MxNxCxFxSxV, where C spans the channel indices, F spans the frame indicies, S spans the 
% slice indices, and V the volume indices.
%
% NOTE: IF the second output argument (Aout) is not assigned to output variable
%     THEN image file is not actually read -- only  header information is extracted
%     
% IMPORTANT: opentif currently only exports the header and sequential image data. Once the tiff header specification reaches a stable 
%	    point, parsing and data organization will be reincorporated ++++
%
%% SYNTAX
%   opentif()
%   opentif(filename)
%   header = opentif(...)
%   [header,Aout] = opentif(...)
%   [header,Aout,imgInfo] = opentif(...)
%		INPUT
%       	filename: Name of TIF file, with or without '.tif' extension. If omitted, a dialog is launched to allow interactive selection.
%       	flagN/flagNArg: Flags (string-valued) and/or flag/value pairs, in any order, specifying options to use in opening specified file
%
%		OUTPUT
%       	header: Structure comprising information stored by ScanImage into TIF header
%       	Aout: MxNxCxFxSxV array, with images of size MxN for C channels, F frames, S slices, and V volumes. Default type is uint16. 
%       	imgInfo: Structure comprising basic information about the structure of the output array Aout
%
% NOTE: IF the second output argument (Aout) is not assigned to output variable
%       THEN image file is not actually read -- only header information is extracted
%
%% FLAGS (case-insensitive)
%
%   WITH ARGUMENTS
%       'channel' or 'channels': Argument specifies subset of channel(s) to extract. Ex: 1,[1 3], 2:4. 
%       'frame' or 'frames': Argument specifies subset of frames present to extract. Use 'inf' to specify all frames above highest specified value. Ex: 1:30, [50 inf], [1:9 11:19 21 inf]
%       'slice' or 'slices': Argument specifies subset of slices present to extract. Use 'inf' to specify all slices above highest specified value. Ex: 1:30, [50 inf], [1:9 11:19 21 inf]
%       'volume' or 'volumes': Argument specifies subset of volumes present to extract. Use 'inf' to specify all slices above highest specified value. Ex: 1:30, [50 inf], [1:9 11:19 21 inf]
%       'transpose': Argument specifies if output data should be in (TRUE, default) Matlab column major format OR in (FALSE) C row major format
%
%% NOTES
%   This function replaces the scim_openTif() function supplied with ScanImage 4.2
%  	
%	In case of errors, the program will attempt to output whatever image data is available to it as an uncategorized stream of images
%	This stream will be an array of the form MxNxImg raw ouput without any post-processing, containing all the frames found within the file, where Img is the number of images
%
%   TODO: Port more advanced features to ScanImage 5 from SI3/4 scim_openTif
%   TODO: Add a flag to discard fastZ-flyback frames if present
%

    % Initialize output variables
    header = [];
    Aout   = [];
    imgInfo = struct();
    rawStream = false;

    % Constants/Inits
    if nargout < 0 || nargout > 4
        most.idioms.warn('Invalid output arguments'); 
        return
    end

    % Parse input arguments

    flagNames = {'channel' 'channels' 'slice' 'slices' 'frame' 'frames' 'volume' 'volumes' 'raw' 'transpose'};

    flagIndices = find(cellfun(@(x)ischar(x) && ismember(lower(x),flagNames),varargin));

    flags = cellfun(@lower,varargin(flagIndices),'UniformOutput',false);
    if isempty(flags)
        flags = {};
    end
    
    if any(strcmpi(flags,'transpose'))
        doTranspose = scanimage.util.private.getArg(varargin,{'transpose'},flags,flagIndices);
    else
        doTranspose = true;
    end

    % DEPRECATED
    % bStreamOutput = false;

    % Determine input file
    if isempty(find(flagIndices==1)) && nargin>=1 && ischar(varargin{1})
        fileName = varargin{1};
    else
        fileName = '';
    end

    if isempty(fileName)
        [f, p] = uigetfile({'*.tif;*.tiff'},'Select Image File');
        if f == 0
            most.idioms.warn('Invalid arguments'); 
            return;
        end
        fileName = fullfile(p,f); 
    end

    % Read TIFF file; extract # frames & image header
    if ~exist(fileName, 'file')
        if exist([fileName '.tif'], 'file')
            fileName = [fileName '.tif'];
        elseif exist([fileName '.tiff'],'file')
            fileName = [fileName '.tiff'];
        else
          error('''%s'' is not a recognized flag or filename. Aborting.',fileName);
        end
    end
    
    hTif = scanimage.util.ScanImageTiffReader(fileName);

    [fileHeader, frameDescs] = scanimage.util.private.getHeaderData(hTif);

    bErrorFound = false;
    try
        verInfo = scanimage.util.private.getSITiffVersionInfo(fileHeader);
        header = scanimage.util.private.parseFrameHeaders(fileHeader,frameDescs,verInfo);
        si_ver = verInfo.SI_MAJOR;
    catch
        bErrorFound = true;
        si_ver = '';
    end

    numImages = numel(frameDescs);

    %Reincorporate conditional once header spec is stable
    if numImages == 0 || isempty(si_ver)
        bErrorFound = true;
    end

    if bErrorFound
        Aout = hTif.data();
        imgInfo.numImages = numImages;	% Only the number of images is reliable
        imgInfo.filename = fileName;	% As well as the filename, of course
        imgInfo.si_ver = si_ver;	% ScanImage version
        rawStream = true;
        return;
    end

    hdr = scanimage.util.private.extractHeaderData(header,verInfo);

    % Read image meta-data
    savedChans = hdr.savedChans;
    numChans = length(savedChans);
    %numPixels = hdr.numPixels;
    %numLines = hdr.numLines;
    numSlices = hdr.numSlices; % sans flyback frames
    numVolumes = hdr.numVolumes;
    numFrames = hdr.numFrames; % per slice
    %numDiscardFrames = hdr.numDiscardFrames;
    %discardFlybackframesEnabled = hdr.discardFlybackframesEnabled;
    
    if any(strcmpi('raw',flags))
        Aout = hTif.data(); % this reads in all the data from the Tiff
        if (numImages ~= size(Aout,3))
            Aout = Aout(:,:,1:numImages); % filter by frame idxs
        end
        
        if doTranspose
            Aout = most.memfunctions.inPlaceTranspose(Aout); % the ScanImageTiffReader reads data in row major order
        end
        
        imgInfo.numImages = numImages;
        imgInfo.numChans = numChans;
        imgInfo.numSlices = numSlices;
        imgInfo.numVolumes = numVolumes;
        imgInfo.numFrames = numFrames;
        imgInfo.filename = fileName;
        imgInfo.si_ver = si_ver;
        
        rawStream = true;
        return;
    end

    % If using FastZ, use slices value that contains potential flyback frames
    % for proper organization of output image-array
    % numFramesPerVolume = number frames per slice * number of slices per volume
    % if FastZ is on, numFrames should be 1
    numSlicesPlusFlyback = hdr.numFramesPerVolume / numFrames;

    % Make sure there are no issues with nextTrigger data
    if numImages ~= numChans*numFrames*numSlicesPlusFlyback*numVolumes
        % We are working under the assumption that only volumes can have multiple "slices"
        if numSlicesPlusFlyback > 1
            numVolumes = floor(numImages/numChans/numSlicesPlusFlyback);
            numFrames = 1;  % This should already be the case
        elseif numFrames > 1
            % In this case there are no volumes, since we only can have 1 frame and multiple slices in a volume
            numVolumes = 1; % This should already be the case
            numSlicesPlusFlyback = 1;  % This should already be the case
            % We discard the previous value of frames and adjust to what was acquired before the next-trigger came in
            numFrames = floor(numImages/numChans);  
        end

        if numImages ~= numChans*numFrames*numSlicesPlusFlyback*numVolumes
            most.idioms.warn('Unexpected number of images.');
            Aout = hTif.data(); % this reads in all the data from the Tiff
            if (numImages ~= size(Aout,3))
                Aout = Aout(:,:,1:numImages); % filter by frame idxs
            end
            
            if doTranspose
                Aout = most.memfunctions.inPlaceTranspose(Aout); % the ScanImageTiffReader reads data in row major order
            end
            
            imgInfo.numImages = numImages;	% Only the number of images is reliable
            imgInfo.filename = fileName;	% As well as the filename, of course
            imgInfo.si_ver = si_ver;        % ScanImage version
            
            rawStream = true;
            return;
        end
    end

    if ~(numFrames && numSlices)
        most.idioms.warn('Acquisition did not complete a single frame or slice. Aborting.');
        Aout = hTif.data(); % this reads in all the data from the Tiff
        if (numImages ~= size(Aout,3))
            Aout = Aout(:,:,1:numImages); % filter by frame idxs
        end
        
        if doTranspose
            Aout = most.memfunctions.inPlaceTranspose(Aout); % the ScanImageTiffReader reads data in row major order
        end
        
        imgInfo.numImages = numImages;	% Only the number of images is reliable
        imgInfo.filename = fileName;	% As well as the filename, of course
        imgInfo.si_ver = si_ver;        % ScanImage version

        rawStream = true;
        return;
    end

    %VI120910A: Detect/handle header-only operation (don't read data)
    if nargout <= 1
        return;
    end

    % Process Flags

    %Determine channels to extract
    if any(ismember({'channel' 'channels'},flags))
        selectedChans = scanimage.util.private.getArg(varargin,{'channel' 'channels'},flags,flagIndices);

        if ~isempty(setdiff(selectedChans,savedChans))
            selectedChans(find(setdiff(selectedChans,savedChans))) = [];
            warning('Some specified channels to extract not detected in file and, hence, ignored');
            if isempty(selectedChans)
                warning('No saved channels are specified to extract. Aborting.');
                return;
            end
        end
    else
        selectedChans = savedChans;
    end

    %Determine slices to extract
    if numSlices >= 1 && any(ismember({'slice' 'slices'},flags))
        selectedSlices = scanimage.util.private.selectImages(varargin,{'slice' 'slices'},numSlices, flags, flagIndices);
    else
        %Extract all slices
        selectedSlices = 1:numSlices;
    end

    % RRR Extract all frames for now
    %Determine frames to extract
    if numFrames >= 1 && any(ismember({'frame' 'frames'},flags))
        selectedFrames = scanimage.util.private.selectImages(varargin,{'frame' 'frames'},numFrames, flags, flagIndices);
    else
        %Extract all frames
        selectedFrames = 1:numFrames;
    end

    %Determine volumes to extract
    if numVolumes >= 1 && any(ismember({'volume' 'volumes'},flags))
        selectedVolumes = scanimage.util.private.selectImages(varargin,{'volume' 'volumes'},numVolumes, flags, flagIndices);
    else
        %Extract all frames
        selectedVolumes = 1:numVolumes;
    end

    lenTotalChans = length(savedChans);
    lenTotalSlices = numSlicesPlusFlyback;
    lenTotalFrames = numFrames;
    %lenTotalVolumes = numVolumes;

    % Read image data
    selectedChans = selectedChans';

    % DEPRECATED / NEVER RUN
    %if bStreamOutput
        % This mode is for the case in which the selection parameters cannot be 
        % trusted. For instance, when the number of images is different than 
        % expected, but we would still like to 
        % Checking this mode has priority given that it will always output existing data
        % No postprocessing for data (such as removing discard frames) at this point
    %    most.idioms.warn('Insufficient or incorrect header data.')

        % Preallocate image data
    %    Aout = zeros(numLines,numPixels,numImages,imageDataType);    

    %    for idx = 1:numImages
    %        hTif.setDirectory(idx);
    %        Aout(:,:,idx) = hTif.read();
    %    end

    %    most.idioms.warn('Returning default, uncategorized stream of Tiff frames')
    %end
    
    if isfield(header,'FrameNumberAcquisition')
        % for legacy files, the f in frameNumberAcquisition is capitalized
        frameIdxs = 1:length(header.FrameNumberAcquisition);
    else
        frameIdxs = 1:length(header.frameNumberAcquisition);
    end
    %frameIdxs = (1:(lenTotalChans * hdr.numFramesPerVolume * numVolumes))';
    % shape indices to map to tiff image
    frameIdxs = reshape(frameIdxs,lenTotalChans,lenTotalFrames,lenTotalSlices,[]);
    %filter to selected indices only
    frameIdxs = frameIdxs(find(savedChans == selectedChans(:)),selectedFrames,selectedSlices,selectedVolumes);
    
    Aout = hTif.data(); % this reads in all the data from the Tiff
    Aout = Aout(:,:,frameIdxs); % filter by frame idxs
    
    if doTranspose
        Aout = most.memfunctions.inPlaceTranspose(Aout); % the ScanImageTiffReader reads data in row major order
    end
   
    %HACK! For now there seems to be an issue with the flyback possibly due to mroi
    %still being developed. We need to take only the last section of the following values: 
    %The following also takes care of MROI mode discrepancies, since we don't have access
    %to the properties of MROI captures through the TIFF header at the moment
    numLines  = size(Aout,1);
    numPixels = size(Aout,2);
    
    %re-expand Aout to dimensions (col, row, channel, frame, slice, volume)
    Aout = reshape(Aout,[size(Aout,1) size(Aout,2) size(frameIdxs)]);

    % Prepare imgInfo
    imgInfo.numImages = numImages;
    imgInfo.numChans = numChans;
    imgInfo.numPixels = numPixels;
    imgInfo.numLines = numLines;
    imgInfo.numSlices = numSlices;
    imgInfo.numVolumes = numVolumes;
    imgInfo.numFrames = numFrames;
    imgInfo.filename = fileName;	
    imgInfo.si_ver = si_ver;	
end

%--------------------------------------------------------------------------%
% opentif.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
