classdef GenericSLM < scanimage.mroi.scanners.SLM & most.HasMachineDataFile    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Generic SLM';

        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfOptionalVars = struct(...
            'maxRefreshRate',60 ...
            );
    end
    
    %%% Class specific properties
    properties (SetAccess = immutable, GetAccess = private)
        hDisp = [];
    end
    
    %% LifeCycle    
    methods
        function obj = GenericSLM()
            validateattributes(obj.mdfData.monitorID,{'numeric'},{'scalar','>',0});
            validateattributes(obj.mdfData.pixelResolutionXY,{'numeric'},{'row','numel',2});
            
            obj.description = 'Generic SLM';
            obj.pixelResolutionXY = obj.mdfData.pixelResolutionXY;
            obj.pixelPitchXY = obj.mdfData.pixelPitchXY / 1e6; % conversion from microns to meter
            obj.pixelBitDepth = 8;
            obj.computeTransposedPhaseMask = true;
            obj.maxRefreshRate = obj.mdfData.maxRefreshRate;
            
            obj.hDisp = dabs.generic.FullScreenDisplay(obj.mdfData.monitorID);
            blankImage = zeros(obj.pixelResolutionXY(1),obj.pixelResolutionXY(2),'uint8');
            obj.writePhaseMaskRawToSlm(blankImage);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDisp);
        end
    end
    
    %% User Methods
    methods
        function writePhaseMaskRawToSlm(obj,phaseMaskRaw,waitForTrigger)
            if nargin < 3 || isempty(waitForTrigger)
                waitForTrigger = false;
            end
            assert(~waitForTrigger,'%s does not support external triggering',obj.description);
            
            sz = size(phaseMaskRaw);
            if obj.computeTransposedPhaseMask
                assert(sz(1)==obj.pixelResolutionXY(1) && sz(2)==obj.pixelResolutionXY(2),'Tried to send phase mask of wrong size to SLM');
            else
                assert(sz(1)==obj.pixelResolutionXY(2) && sz(2)==obj.pixelResolutionXY(1),'Tried to send phase mask of wrong size to SLM');
            end
            
            obj.hDisp.updateBitmap(phaseMaskRaw,obj.computeTransposedPhaseMask);
        end
    end
end



%--------------------------------------------------------------------------%
% GenericSLM.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
