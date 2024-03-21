classdef SLM < scanimage.mroi.scanners.SLM & most.HasMachineDataFile
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Simulated SLM';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfOptionalVars = struct(...
            'pixelBitDepth',8, ...
            'interPixelGapXY',[0,0] ... % [1x2 numeric] gap in between pixels in microns
            );
    end
    
    %% LifeCycle
    methods
        function obj = SLM()
            obj.description = 'Simulated SLM';
            obj.pixelResolutionXY = obj.mdfData.pixelResolutionXY;     
            obj.pixelPitchXY = obj.mdfData.pixelPitchXY / 1e6;          % convert from microns to meter 
            obj.interPixelGapXY = obj.mdfData.interPixelGapXY / 1e6;    % convert from microns to meter
            obj.pixelBitDepth = obj.mdfData.pixelBitDepth;              % numeric, one of {8,16,32,64} corresponds to uint8, uint16, uint32, uint64 data type
        end
        
        function delete(obj)
            % No-op
        end
    end
    
    % Abstract property realization
    methods        
        function writePhaseMaskRawToSlm(obj,varargin)
            % No-op
        end
    end
end

%--------------------------------------------------------------------------%
% SLM.m                                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
