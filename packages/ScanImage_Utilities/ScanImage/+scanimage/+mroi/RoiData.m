classdef RoiData < handle & matlab.mixin.Copyable
    % class defining image data for one roi at multiple z depths
    % ro get the scanfield for a specific z use obj.roi.get(z);
    properties
        hRoi;                          % handle to roi
        zs;                            % [numeric] array of zs
        channels;                      % [numeric] array of channelnumbers in imageData
        imageData;                     % cell of cell arrays of image data for
                                       %     channels(1st index) and zs (2nd index)
                                       %     image data is transposed
        stripePosition = {};           % cell array of 1x2 start and end line of the current stripe for each z. if empty, current stripe is full frame
        stripeFullFrameNumLines = [];  % stripeFullFrameNumLines indicates the number of lines in the full frame for each z
        
        transposed = true;
        acqNumber;                     % [numeric] acquisition number
        frameNumberAcq;                % [numeric] frame number in current acquisition (taken from stripe data)
        frameNumberAcqMode;            % [numeric] frame number in current acquisition mode (taken from stripe data)
        frameTimestamp;                % [numeric] time stamp in current acquisition mode (taken from stripe data)
        motionOffset;                  % 2 x n array of x,y offsets for all zs in pixel coordinates
    end
    
    properties
        acqParamBuffer;                % buffer holding frequently used parameters to limit parameter recomputation
    end
    
    methods
        function set.channels(obj,val)
            assert(issorted(val),'RoiData: channels need to be sorted'); % we use ismembc2(a,channels) on this in RoiIntegrator, where channels needs to be sorted
            obj.channels = val(:)';       
        end
        
        function set.zs(obj,val)
            assert(issorted(val),'RoiData: zs need to be sorted'); % we use ismembc2(a,zs) on this in RoiIntegrator, where zs needs to be sorted
            obj.zs = val(:)';    
        end
        
        function s = saveobj(obj)
            s = struct();
            
            if ~isempty(obj.hRoi)
                s.hRoi = obj.hRoi.saveobj();
            else
                s.hRoi = [];
            end
            
            s.zs = obj.zs;
            s.channels = obj.channels;
            s.imageData = obj.imageData;
            s.stripePosition = obj.stripePosition;
            s.stripeFullFrameNumLines = obj.stripeFullFrameNumLines;
            s.transposed = obj.transposed;
            s.acqNumber = obj.acqNumber;
            s.frameNumberAcq = obj.frameNumberAcq;
            s.frameNumberAcqMode = obj.frameNumberAcqMode;
            s.frameTimestamp = obj.frameTimestamp;
            s.motionOffset = obj.motionOffset;
        end
    end
    
    methods
        function obj = castImageData(obj,newType)
            for iterChannels = 1:length(obj.imageData)
                for iterZs = 1:length(obj.imageData{iterChannels})
                    obj.imageData{iterChannels}{iterZs} = cast(obj.imageData{iterChannels}{iterZs},newType);
                end
            end
        end
        
        function obj = multiplyData(obj,factor)
            for iterChannels = 1:length(obj.imageData)
                for iterZs = 1:length(obj.imageData{iterChannels})
                    obj.imageData{iterChannels}{iterZs} = cast(double(obj.imageData{iterChannels}{iterZs}) .* factor,'like',obj.imageData{iterChannels}{iterZs});
                end
            end
        end
        
        function merge(obj,hRoiData)
            % merge hRoiData into obj
            if isempty(hRoiData) || isempty(hRoiData.imageData)
                return
            end
            
            for iterChannels = 1:length(obj.imageData)
                for iterZs = 1:length(obj.imageData{iterChannels})
                    pos = obj.stripePosition{iterZs};
                    if obj.transposed
                        obj.imageData{iterChannels}{iterZs}(:,1:(pos(1)-1)) = cast(hRoiData.imageData{iterChannels}{iterZs}(:,1:(pos(1)-1)),'like',obj.imageData{iterChannels}{iterZs});
                        obj.imageData{iterChannels}{iterZs}(:,(pos(2)+1):end) = cast(hRoiData.imageData{iterChannels}{iterZs}(:,(pos(2)+1):end),'like',obj.imageData{iterChannels}{iterZs});
                    else
                        obj.imageData{iterChannels}{iterZs}(1:(pos(1)-1),:) = cast(hRoiData.imageData{iterChannels}{iterZs}(1:(pos(1)-1),:),'like',obj.imageData{iterChannels}{iterZs});
                        obj.imageData{iterChannels}{iterZs}((pos(2)+1):end,:) = cast(hRoiData.imageData{iterChannels}{iterZs}((pos(2)+1):end,:),'like',obj.imageData{iterChannels}{iterZs});
                    end
                end
            end
        end
        
        function resetData(obj)
            % merge hRoiData into obj            
            for iterChannels = 1:length(obj.imageData)
                for iterZs = 1:length(obj.imageData{iterChannels})
                    pos = obj.stripePosition{iterZs};
                    if obj.transposed
                        obj.imageData{iterChannels}{iterZs}(:,1:(pos(1)-1)) = 0;
                        obj.imageData{iterChannels}{iterZs}(:,(pos(2)+1):end) = 0;
                    else
                        obj.imageData{iterChannels}{iterZs}(1:(pos(1)-1),:) = 0;
                        obj.imageData{iterChannels}{iterZs}((pos(2)+1):end,:) = 0;
                    end
                end
            end
        end
        
        function resetDataToZero(obj)
            % merge hRoiData into obj            
            for iterChannels = 1:length(obj.imageData)
                for iterZs = 1:length(obj.imageData{iterChannels})
                    dims = size(obj.imageData{iterChannels}{iterZs});
                    obj.imageData{iterChannels}{iterZs} = zeros(dims,'like',obj.imageData{iterChannels}{iterZs});
                end
            end
        end
        
        function onlyKeepChannels(obj,chs)
            validateattributes(chs,{'numeric'},{'vector','integer','positive'});
            channelKeepMask = ismember(obj.channels,chs);
            obj.deleteChannels(obj.channels(~channelKeepMask));
        end
        
        function deleteChannels(obj,chs)
            if isempty(chs) || isempty(obj.imageData)
                return
            end
            
            validateattributes(chs,{'numeric'},{'vector','integer','positive'});
            channelDelmask = ismember(obj.channels,chs);
            obj.channels(channelDelmask) = [];
            obj.imageData(channelDelmask) = [];
        end
        
        function onlyKeepZs(obj,zs)
            validateattributes(zs,{'numeric'},{'vector'});
            zsKeepmask = ismember(obj.zs,zs);
            obj.deleteZs(obj.zs(~zsKeepmask));
        end
        
        function deleteZs(obj,zs)
            if isempty(zs) || isempty(obj.imageData)
                return
            end
            
            validateattributes(zs,{'numeric'},{'vector'});
            zDelmask = ismember(obj.zs,zs);
            obj.zs(zDelmask) = [];
            
            for chIdx = 1:numel(obj.imageData)
                obj.imageData{chIdx}(zDelmask) = [];
            end
        end
    end
    
    methods (Static)
        function obj = loadobj(s)
            obj = scanimage.mroi.RoiData();
            
            if ~isempty(s.hRoi)
                obj.hRoi = scanimage.mroi.Roi.loadobj(s.hRoi);
            end
            
            obj.zs = s.zs;
            obj.channels = s.channels;
            obj.imageData = s.imageData;
            obj.stripePosition = s.stripePosition;
            obj.stripeFullFrameNumLines = s.stripeFullFrameNumLines;
            obj.transposed = s.transposed;
            obj.acqNumber = s.acqNumber;
            obj.frameNumberAcq = s.frameNumberAcq;
            obj.frameNumberAcqMode = s.frameNumberAcqMode;
            obj.frameTimestamp = s.frameTimestamp;
            obj.motionOffset = s.motionOffset;
        end
    end
end


%--------------------------------------------------------------------------%
% RoiData.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
