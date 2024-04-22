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
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (Constant)
        queueAvailable = false;
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
    
    methods (Access = protected)
        function resizeSlmQueue(obj,length)
        end
        
        function writeSlmQueue(obj,frames)
        end
        
        function startSlmQueue(obj)
        end
        
        function abortSlmQueue(obj)
        end
    end
end

function s = defaultMdfSection()
    s = [...
        makeEntry('pixelResolutionXY',[512,512],'[1x2 numeric] pixel resolution of SLM')...
        makeEntry('pixelPitchXY',[15 15],'[1x2 numeric] distance from pixel center to pixel center in microns')...
        makeEntry('pixelBitDepth',8)...
        makeEntry('interPixelGapXY',[0 0],'[1x2 numeric] gap in between pixels in microns')...
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
% SLM.m                                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
