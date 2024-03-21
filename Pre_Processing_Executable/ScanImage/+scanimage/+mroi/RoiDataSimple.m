classdef RoiDataSimple < handle & matlab.mixin.Copyable
    % class defining image data for one roi at multiple z depths
    properties
        hRoi;                          % handle to roi
        zs;                            % [numeric] array of zs
        channels;                      % [numeric] array of channelnumbers in imageData
        imageData;                     % cell of cell arrays of image data for
                                       %      channels (1st index) 
                                       %      volume (2nd index) 
                                       %      zs (3rd index)
    end
    
    methods
        %+++Test me
        function obj = castImageData(obj,newType)
            for iterChannels = 1:length(obj.imageData)
                for iterVolumes = 1:length(obj.imageData{iterChannels})
                    for iterZs = 1:length(obj.imageData{iterChannels}{iterVolumes})
                        obj.imageData{iterChannels}{iterVolumes}{iterZs} = cast(obj.imageData{iterChannels}{iterVolumes}{iterZs},newType);
                    end
                end
            end
        end
        
        %+++Test me
        function obj = multiplyImageData(obj,factor)
            for iterChannels = 1:length(obj.imageData)
                for iterVolumes = 1:length(obj.imageData{iterChannels})
                    for iterZs = 1:length(obj.imageData{iterChannels}{iterVolumes})
                        obj.imageData{iterChannels}{iterVolumes}{iterZs} = obj.imageData{iterChannels}{iterVolumes}{iterZs} .* cast(factor,'like',obj.imageData{iterChannels}{iterVolumes}{iterZs});
                    end
                end
            end
        end
    end
end


%--------------------------------------------------------------------------%
% RoiDataSimple.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
