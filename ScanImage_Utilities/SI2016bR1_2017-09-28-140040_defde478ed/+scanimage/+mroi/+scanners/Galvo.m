classdef Galvo < scanimage.mroi.scanners.LinearScanner
    properties
        flytoTimeSeconds;
        flybackTimeSeconds;
    end
    
    properties (Hidden)
        impulseResponseDuration = 4e-4;
    end

    methods(Static)
        function obj = default
            obj=scanimage.mroi.scanners.Galvo(27,20/27,27/128,1e-3,-27/2,200000);
        end
    end

    methods
        % See Note (1)
        function obj=Galvo(fullAngleDegrees,...
                           voltsPerDegree,...
                           flytoTimeSeconds,...
                           flybackTimeSeconds,...
                           parkAngleDegrees,...
                           sampleRateHz)
            
            obj.name = 'Galvo Scanner';
                       
            if nargin>=1 && ~isempty(fullAngleDegrees)
               obj.travelRange  = [-fullAngleDegrees fullAngleDegrees]./2;
            end

            if nargin>=2 && ~isempty(voltsPerDegree)
               obj.voltsPerDistance = voltsPerDegree;
            end

            if nargin>=3 && ~isempty(flytoTimeSeconds)
               obj.flytoTimeSeconds = flytoTimeSeconds;
            end

            if nargin>=4 && ~isempty(flybackTimeSeconds)
               obj.flybackTimeSeconds = flybackTimeSeconds;
            end
            
            if nargin>=5 && ~isempty(parkAngleDegrees)
               obj.parkPosition = parkAngleDegrees;
            end
            
            if nargin>=6 && ~isempty(sampleRateHz)
               obj.sampleRateHz = sampleRateHz;
            end
            
            obj.bandwidth = 3000;
        end
    end
end

%--------------------------------------------------------------------------%
% Galvo.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
