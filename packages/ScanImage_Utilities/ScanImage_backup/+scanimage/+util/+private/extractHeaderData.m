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
            s.numFrames = localHdr.hStackManager.framesPerSlice;
            try
                s.numSlices = localHdr.hStackManager.slicesPerAcq;
            catch
                s.numSlices = localHdr.hStackManager.numSlices;
            end
            s.discardFlybackframesEnabled = false;
            s.numDiscardFrames = localHdr.hFastZ.numDiscardFlybackFrames;    
            s.numFramesPerVolume = localHdr.hFastZ.numFramesPerVolume;  %Includes flyback frames
        end

        % NOTE: This assumes you are using tiff files generated on non-simulated
        %       mode. In this case, non-FastZ tiff files seem to differ between these modes
        if s.numSlices > 1
            s.numFrames = 1;
        end
    else
        assert(false);
    end
end



%--------------------------------------------------------------------------%
% extractHeaderData.m                                                      %
% Copyright � 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
