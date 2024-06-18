function [hMroiRoiGroup,hStimRoiGroups,hIntegrationRoiGroup] = readTiffRoiData(filename,header)
    hMroiRoiGroup = [];
    hStimRoiGroups = [];
    hIntegrationRoiGroup = [];

    obj = Tiff(filename);
    
    try 
        roiStr = obj.getTag('Artist');
        delete(obj);
        
        if isempty(roiStr)
            return;
        end
        tiff_ver = 3;
    catch
        delete(obj);
        
        % legacy
        [roiStr, ~] = readAppendedString(filename);
        
        if nargin < 2
            [header] = scanimage.util.opentif(filename);
        end
        
        if ~isfield(header.SI, 'TIFF_FORMAT_VERSION')
            tiff_ver = [];
        else
            tiff_ver = header.SI.TIFF_FORMAT_VERSION;
        end
    end

    if isempty(tiff_ver)
        % NOTE: BACKWARDS COMPATIBILITY SUPPORT
        %       Be careful when editing
        try
            % NOTE:
            % This section reads data for develops/SI2015 TIFF versions from the May Release to 
            % e222103f21d165b6e528be6f052f4d8ae9b83265, where important optimizations were added

            eval(roiStr);
            % This evaluates 'appendedTiffData'. Necessary for this version

            mroiRoiGroupSerialized = appendedTiffData.currentRoiGroupSerialized;
            numStimRoiGroupsSerialized = numel(appendedTiffData.stimRoiGroupsSerializedCell);
            stimRoiGroupsSerializedCell = appendedTiffData.stimRoiGroupsSerializedCell;

            hMroiRoiGroup = scanimage.mroi.util.deserialize(mroiRoiGroupSerialized, 0);
            if numStimRoiGroupsSerialized ~= 0
                for i = 1:numStimRoiGroupsSerialized
                    hStimRoiGroups(i) = scanimage.mroi.util.deserialize(stimRoiGroupsSerializedCell{i}, 0); %#ok
                end
            end
        catch
            try
                % NOTE:
                % This section is meant to support Selmaan Chettih, since he was given a feature branch version
                % at bba3bb8b5afe3c92d568d58909ea89c34ce64240 and he used it to collect data

                eval(roiStr);

                appendedData = scanimage.mroi.util.deserialize(appendedDataSer, 2);

                %MROI group deserialization
                if isfield(appendedData,'mroiRoiGroup') 
                    hMroiRoiGroup = appendedData.mroiRoiGroup;
                end

                %Photostim groups deserialization
                if isfield(appendedData,'stimRoiGroups') 
                    if numel(appendedData.stimRoiGroups) ~= 0
                        hStimRoiGroups = appendedData.stimRoiGroups;
                    end
                end
            catch
                most.idioms.dispError('Error: Unable to read RoiGroups from appended TIFF data');
            end
        end

    else
        if tiff_ver > 1
            % TIFF version 2 moved to JSON for ROI groups
            roiStr(roiStr == 0) = []; % remove null termination
            data = most.json.loadjson(roiStr);
            
            hMroiRoiGroup = scanimage.mroi.RoiGroup.loadobj(data.RoiGroups.imagingRoiGroup);
            if ~isempty(data.RoiGroups.photostimRoiGroups)
                if iscell(data.RoiGroups.photostimRoiGroups)
                    hStimRoiGroups = arrayfun(@scanimage.mroi.RoiGroup.loadobj,[data.RoiGroups.photostimRoiGroups{:}],'UniformOutput',false);
                else
                    hStimRoiGroups = arrayfun(@scanimage.mroi.RoiGroup.loadobj,data.RoiGroups.photostimRoiGroups,'UniformOutput',false);
                end
                hStimRoiGroups = [hStimRoiGroups{:}];
            end
            if ~isempty(data.RoiGroups.integrationRoiGroup)
                hIntegrationRoiGroup = scanimage.mroi.RoiGroup.loadobj(data.RoiGroups.integrationRoiGroup);
            end
        else
            appendedData = scanimage.mroi.util.deserialize(roiStr, 1);
        
            % MROI group extraction
            if isfield(appendedData,'mroiRoiGroup')
                hMroiRoiGroup = appendedData.mroiRoiGroup;
            end
            
            % Photostim groups extraction
            if isfield(appendedData,'stimRoiGroups')
                if numel(appendedData.stimRoiGroups) ~= 0
                    hStimRoiGroups = appendedData.stimRoiGroups;
                end
            end
            
            % Integration RoiGroup extraction
            if isfield(appendedData,'integrationRoiGroup')
                hIntegrationRoiGroup = appendedData.integrationRoiGroup;
            end
        end
    end
end

% legacy
function [str, numBytes] = readAppendedString(filename)
    %readAppendedString - reads non-TIFF data appended string from a file
    % Usage :	writeraw(G, filename)
    % str:		string to append to the image
    % filename: file name of the file to append to 
    % count:	return value, the elements written to file

    str = [];
    %disp(['Reading '  filename ' ...']);

    % Get file ID
    fid = fopen(filename,'r');

    % Check if file exists
    if (fid == -1)
        error('Cannot open file\n');
        pause
    end

    %Move to the end of file
    numBytesSize = 4;
    ret = fseek(fid, -numBytesSize, 1);
    if ret ~= 0 
        disp('Error: fseek failed');
        fclose(fid);
        return;
    end
    numBytes = fread(fid,numBytesSize,'uint32');

    %Move to the beginning of the desired chunk
    ret = fseek(fid, -numBytesSize-numBytes, 1);
    if ret ~= 0 
        disp('Error: fseek failed');
        fclose(fid);
        return;
    end
    %str = fread(fid,numBytes,'uint8=>char');
    str = fread(fid,numBytes,'*char')';


    fclose(fid);
    %disp(['Closing '  filename ' ...']);

end %function


%--------------------------------------------------------------------------%
% readTiffRoiData.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
