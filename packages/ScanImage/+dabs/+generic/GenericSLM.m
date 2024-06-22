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
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% Abstract property realizations (scanimage.mroi.scanners.SLM)
    properties (Constant)
        queueAvailable = false;
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
    
    methods (Access = protected)
        function resizeSlmQueue(obj,length)
            error('Unsupported');
        end
        
        function writeSlmQueue(obj,frames)
            error('Unsupported');
        end
        
        function startSlmQueue(obj)
            error('Unsupported');
        end
        
        function abortSlmQueue(obj)
            error('Unsupported');
        end
    end
end

function s = defaultMdfSection()
    s = [...
        makeEntry('monitorID',2,'Numeric: SLM monitor ID (1 is the main monitor)')...
        makeEntry('pixelResolutionXY',[1920,1080],'[x,y] pixel resolution of SLM')...
        makeEntry('pixelPitchXY',[6.4 6.4],'[1x2 numeric] distance from pixel center to pixel center in microns')...
        makeEntry()...
        makeEntry('maxRefreshRate',60)...
        ];
    
    function se = makeEntry(name,value,comment,liveUpdate)
        if nargin == 0
            name = '';
            value = [];
            comment = '';
        elseif nargin == 1
            comment = name;
            name = '';
            value = [];
        elseif nargin == 2
            comment = '';
        end
        
        if nargin < 4
            liveUpdate = false;
        end
        
        se = struct('name',name,'value',value,'comment',comment,'liveUpdate',liveUpdate);
    end
end


%--------------------------------------------------------------------------%
% GenericSLM.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
