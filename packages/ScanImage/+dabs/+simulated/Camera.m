classdef Camera < most.HasMachineDataFile & dabs.interfaces.CameraInterface
    %% CameraInterface Properties
    properties (SetObservable)
        cameraExposureTime = 10; % Numeric indicating the current exposure time of a camera.
        testPattern;
    end
    
    properties (Constant)
        isTransposed = true;   % Boolean indicating whether camera frame data is column-major order (false) OR row-major order (true)
    end
    
    properties (SetAccess = private)
        bufferedAcqActive = false;  % Boolean indicating whether a bufferd continuous acquisition is active.
        datatype = 'uint8'; % String indicating the data type of returned frame data.
        resolutionXY = [512 512];   % Numeric array [X Y] indicating the resolution of returned frame data.
    end
    
    %% ABSTRACT PROPERTY (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Simulated Camera';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% Simulation Properties
    properties
        cameraHz = 30; % per second
    end
    
    properties(Constant)
        ALL_TEST_PATTERNS = {'Random', 'Gradient'};
    end
    
    %% Private Properties
    properties(Hidden)
        frameGenerator;
        frameAvgNum;
        frameBufferIdx = 1;
        frameBuffer;
        minval;
        typescale;
    end
    
    %% CameraInterface Methods
    methods
        function startAcq(obj)
            if strcmp(obj.frameGenerator.Running, 'off')
                obj.frameGenerator.Period = round(1/obj.cameraHz, 3);
                obj.frameAvgNum = max(obj.cameraHz / (obj.cameraExposureTime * 1000), 1);
                obj.frameBuffer = single(zeros([obj.resolutionXY obj.frameAvgNum]));
                start(obj.frameGenerator);
            end
            obj.bufferedAcqActive = true;
        end
        
        function stopAcq(obj)
            stop(obj.frameGenerator);
            obj.bufferedAcqActive = false;
        end
        
        function img = grabFrame(obj)
            if strcmp(obj.frameGenerator.Running, 'on')
                img = (mean(obj.frameBuffer, 3) * obj.typescale) + obj.minval;
                img = cast(img,obj.datatype);
                obj.lastFrame = img;
            else
                img = obj.lastFrame;
            end
        end
        
        function img = getLastFrame(obj)
            img = obj.lastFrame;
        end
    end
    
    %% Lifecycle
    methods
        function obj = Camera(cameraName)
            custMdfHeading = sprintf('Simulated Camera (%s)', cameraName);
            obj = obj@most.HasMachineDataFile(true, custMdfHeading);
            obj = obj@dabs.interfaces.CameraInterface(cameraName);
            obj.datatype = obj.mdfData.simcamDatatype;
            obj.resolutionXY = obj.mdfData.simcamResolution;
            
            obj.minval = single(intmin(obj.datatype));
            obj.typescale = diff([obj.minval single(intmax(obj.datatype))]);
            
            obj.frameGenerator = timer('BusyMode', 'drop',...
                'ExecutionMode', 'fixedSpacing',...
                'TimerFcn', @(~,~)obj.generateBufferData());
            obj.testPattern = obj.ALL_TEST_PATTERNS{1};
        end
        
        function delete(obj)
            stop(obj.frameGenerator);
            delete(obj.frameGenerator);
        end
    end
    
    %% External + Property Methods
    methods
        function set.cameraExposureTime(obj, val)
            assert(val > 0);
            obj.cameraExposureTime = val;
            if strcmp(obj.frameGenerator.Running, 'on')
                obj.stopAcq();
                obj.startAcq();
            end
        end
        
        function set.cameraHz(obj, val)
            assert(val > 0 && val <= 1000,...
                'Simulated Camera Hz cannot exceed 1000, zero, or lower than zero.');
            obj.cameraHz = val;
            obj.framesPerGrab = getFramesPerGrab(obj.cameraExposureTime, obj.cameraHz);
        end
        
        function set.testPattern(obj, val)
            assert(isnumeric(val) || ischar(val) && any(strcmpi(val, obj.ALL_TEST_PATTERNS)),...
                'Test Pattern must be a string and one of `%s`',...
                strjoin(obj.ALL_TEST_PATTERNS, '|'));
            
            if isnumeric(val)
                assert(val > 0 && val <= length(obj.ALL_TEST_PATTERNS),...
                    'Test Pattern Index must be 1-%d',...
                    length(obj.ALL_TEST_PATTERNS));
            else
                patternIdx = strcmpi(val, obj.ALL_TEST_PATTERNS);
                assert(any(patternIdx),...
                'Test Pattern string must be one of `%s` (case insensitive)',...
                strjoin(obj.ALL_TEST_PATTERNS, '|'));
                val = find(patternIdx, 1);
            end
            obj.testPattern = obj.ALL_TEST_PATTERNS{val};
        end
    end
    
    %% Internal Methods
    methods(Access=private)
        function generateBufferData(obj)
            if obj.isTransposed
                res = obj.resolutionXY;
            else
                res = flip(obj.resolutionXY);
            end
            
            switch obj.testPattern
                case 'Random'
                    fb = rand(res, 'single');
                case 'Gradient'
                    fb = repmat(sin(linspace(0,pi,res(1))) .',1,res(2));
            end
            obj.frameBuffer(:,:,obj.frameBufferIdx) = fb;
            if obj.frameBufferIdx == obj.frameAvgNum
                obj.frameBufferIdx = 1;
            else
                obj.frameBufferIdx = obj.frameBufferIdx + 1;
            end
        end
    end
end

%% Default MDF Values
function s = defaultMdfSection()
datatype = struct('name', 'simcamDatatype',...
    'value', 'uint8',...
    'comment', ['Datatype of the Simulated Camera. e.g. uint8, uint16.',...
    '  Must be unsigned.  See `randi` for compatible types'],...
    'liveUpdate', false);
resolution = struct('name', 'simcamResolution',...
    'value', [512 512],...
    'comment', ['Resolution of the simulated camera in form [X Y].'...
    '  Cannot have negative values.'],...
    'liveUpdate', false);
s = [datatype resolution];
end

%--------------------------------------------------------------------------%
% Camera.m                                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
