function s = extractHeaderData(header, verInfo)
    if isfield(header,'SI')
        localHdr = header.SI;
    elseif isfield(header.scanimage,'SI')
        localHdr = header.scanimage.SI;
    else
        assert(false);  % We no longer support the original SI5 format
    end

    % If it's any of the currently supported SI2015 versions 
    if verInfo.infoFound
        s.savedChans = localHdr.hChannels.channelSave;
        s.numPixels = localHdr.hRoiManager.pixelsPerLine;
        s.numLines = localHdr.hRoiManager.linesPerFrame;

        if localHdr.hFastZ.enable
            s.numVolumes = localHdr.hFastZ.numVolumes;
            try
                s.numSlices = localHdr.hStackManager.slicesPerAcq;
            catch
                s.numSlices = max(localHdr.hStackManager.numSlices, numel(localHdr.hStackManager.zs));
            end
            s.numFrames = 1;

            % Assuming that we only have discard frames during FastZ acquisitions
            s.discardFlybackframesEnabled = localHdr.hFastZ.discardFlybackFrames;
            s.numDiscardFrames = localHdr.hFastZ.numDiscardFlybackFrames; 
            s.numFramesPerVolume = localHdr.hFastZ.numFramesPerVolume;  %Includes flyback frames
        else
            s.numVolumes = 1;
            s.numFrames = localHdr.hStackManager.framesPerSlice / localHdr.hScan2D.logAverageFactor;
            try
                s.numSlices = localHdr.hStackManager.slicesPerAcq;
            catch
                s.numSlices = localHdr.hStackManager.numSlices;
            end
            s.discardFlybackframesEnabled = false;
            s.numDiscardFrames = 0;    
            s.numFramesPerVolume = s.numFrames * s.numSlices;
        end
    else
        assert(false);
    end
end



%--------------------------------------------------------------------------%
% extractHeaderData.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
