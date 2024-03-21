function [header, pmtData, scannerPosData, roiGroup] = readLineScanDataFiles(fileName)
    
    if (length(fileName) > 7) && strcmp(fileName(end-8:end), '.meta.dat')
        fileNameStem = fileName(1:end-9);
        metaFileName = fileName;
    else
        fileNameStem = fileName;
        metaFileName = [fileName '.meta.txt'];
    end
    
    % read metadata
    fid = fopen(metaFileName,'rt');
    assert(fid > 0, 'Failed to open metadata file.');
    headerStr = fread(fid,'*char')';
    fclose(fid);
    
    % parse metadata
    if headerStr(1) == '{'
        data = most.json.loadjson(headerStr);
        header = data{1};
        rgData = data{2};
    else
        rows = textscan(headerStr,'%s','Delimiter','\n');
        rows = rows{1};
        
        rgDataStartLine = find(cellfun(@(x)strncmp(x,'{',1),rows),1);
        header = scanimage.util.private.decodeHeaderLines(rows(1:rgDataStartLine-1));
        
        rgStr = strcat(rows{rgDataStartLine:end});
        rgData = most.json.loadjson(rgStr);
    end
    roiGroup = scanimage.mroi.RoiGroup.loadobj(rgData.RoiGroups.imagingRoiGroup);
    
    % read and parse pmt data
    header.acqChannels = header.SI.hChannels.channelSave;
    nChannels = numel(header.acqChannels);
    fid = fopen([fileNameStem '.pmt.dat']);
    assert(fid > 0, 'Failed to open pmt data file.');
    pmtData = fread(fid,inf,'int16');
    fclose(fid);
    
    % add useful info to header struct
    header.sampleRate = header.SI.hScan2D.sampleRate;
    header.numSamples = size(pmtData,1)/nChannels;
    header.acqDuration = header.numSamples / header.sampleRate;
    header.samplesPerFrame = header.SI.hScan2D.lineScanSamplesPerFrame;
    header.frameDuration = header.samplesPerFrame / header.sampleRate;
    header.numFrames = ceil(header.numSamples / header.samplesPerFrame);
    N = header.samplesPerFrame * header.numFrames * nChannels;
    pmtData(end+1:N,:) = nan;
    pmtData = permute(reshape(pmtData,nChannels,header.samplesPerFrame,[]),[2 1 3]);
    
    % read and parse scanner position data
    fid = fopen([fileNameStem '.scnnr.dat']);
    if fid > 0
        dat = fread(fid,inf,'single');
        fclose(fid);
        
        nScnnrs = header.SI.hScan2D.lineScanNumFdbkChannels;
        header.feedbackSamplesPerFrame = header.SI.hScan2D.lineScanFdbkSamplesPerFrame;
        header.feedbackSampleRate = header.SI.hScan2D.sampleRateFdbk;
        header.numFeedbackSamples = size(dat,1)/nScnnrs;
        header.numFeedbackFrames = ceil(header.numFeedbackSamples / header.feedbackSamplesPerFrame);
        
        % pad data if last frame was partial
        N = header.feedbackSamplesPerFrame * header.numFeedbackFrames * nScnnrs;
        dat(end+1:N,:) = nan;
        
        dat = permute(reshape(dat,nScnnrs,header.feedbackSamplesPerFrame,[]),[2 1 3]);
        scannerPosData.G = dat(:,1:2,:);
        if nScnnrs > 2
            scannerPosData.Z = dat(:,3,:);
        end
    else
        scannerPosData = [];
    end
end

%--------------------------------------------------------------------------%
% readLineScanDataFiles.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
