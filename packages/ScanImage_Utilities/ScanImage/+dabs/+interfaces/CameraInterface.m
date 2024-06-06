classdef CameraInterface < most.util.Uuid
    %% CameraInterface
    %
    % Defines a common interface for all cameras.
    %
    
    %% Abstract properties
    properties (Abstract, SetObservable)
        cameraExposureTime;                             % Numeric indicating the current exposure time of a camera.
    end
    
    properties (Abstract, Constant)
        isTransposed;                                   % Boolean indicating whether camera frame data is column-major order (false) OR row-major order (true)
    end
    
    properties (Abstract, SetAccess =  private)
        bufferedAcqActive;                              % Boolean indicating whether a bufferd continuous acquisition is active.
        datatype;                                       % String indicating the data type of returned frame data.
        resolutionXY;                                   % Numeric array [X Y] indicating the resolution of returned frame data.
    end
    
    %% CameraInterface properties
    properties (SetAccess = immutable)
        cameraName;                                     % String indicating the name of the camera.
    end
    
    properties (SetAccess=protected, SetObservable)
        lastFrame = [];                                  % Property containing the last frame acquired by the camera for reference.
    end
    
    %% LIFECYCLE METHODS
    methods
        %% Constructor
        function obj = CameraInterface(cameraName)
            if nargin < 1 || isempty(cameraName)
                cameraName = 'My unnamed camera';
            end
            
            if ~isempty(cameraName)
                validateattributes(cameraName,{'char'},{'row'});
            end
            
            obj.cameraName = cameraName;
            obj.hTimer = timer('Name','Live Camera Timer');
            obj.hTimer.ExecutionMode = 'fixedSpacing';
        end
        
        %% Destructor
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTimer);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% ABSTRACT METHODS
    methods (Abstract)
        %% startAcq(obj)
        %
        % Abstract function to begin a continuous buffered acquisition of
        % frames from the camera. Specifics to be implmented in subclass.
        %
        startAcq(obj)
        
        %% stopAcq(obj)
        %
        % Abstract function to stop a continuous buffered acquisition of
        % frames from the camera if currently active. Specifics to be
        % implemented in subclass.
        %
        stopAcq(obj)
        
        %% grabFrame(obj)
        %
        % Abstract function to return a single frame from the camera. If
        % the camera supports continous buffered acquisitions and such and
        % acquisition is currently active this function should simply
        % return the most recent frame acquired by the camera. Otherwise
        % this function should directly call the camera to acquire a single
        % frame. At the end of this function the returned frame should be
        % stored in the lastFrame property. Specifics on acquiring a frame
        % to be implemented in subclass.
        %
        img = grabFrame(obj)
        
        %% getLastFrame(obj)
        %
        % Abstract function intended to return the last acquired frame
        % without a new acquisition, generally by returning the frame
        % stored in the lastFrame property.
        %
        img = getLastFrame(obj)
    end
    
    %% User Methods
    methods
        %% startLiveMode(obj, liveModeCallbackFcn, interval)
        %
        % Function to begin a peseudo live video stream of camera images
        % using fixed timer intervals. Accepts as arguments a callback
        % function to be fired when the timer times out and the interval
        % between timer timeouts.
        %
        function startLiveMode(obj,liveModeCallbackFcn,interval)
            if nargin < 3 || isempty(interval)
                interval = 0.3;
            end
            
            assert(~obj.videoTimerActive,...
                'Cannot start live mode when live mode is already active')
            obj.hTimer.StartDelay = 0.2;
            obj.hTimer.Period = ceil(interval*1000)/1000;
            obj.hTimer.TimerFcn = ...
                @(varargin)liveModeCallbackFcn(obj.grabFrameNoThrow());
            if ~obj.bufferedAcqActive
                obj.startAcq();
            end
            start(obj.hTimer);
        end
        
        %% abort(obj)
        %
        % General function to abort pseudo live video mode camera acquisitions.
        %
        function abort(obj)
            obj.abortLiveMode();
        end
        
        %% abortLiveMode(obj)
        %
        % Specific function to abort pseudo live video mode camera
        % acquisitions. This functon is called by the general abort()
        % function.
        %
        function abortLiveMode(obj)
            if obj.videoTimerActive
                stop(obj.hTimer);
            end
            
            if obj.bufferedAcqActive
                try
                    obj.stopAcq();
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
        
        %% showGUI(obj)
        %
        % Function to launch simple camera interface GUI. Intended for
        % command line testing of cameras outside of ScanImage.
        %
        function showGUI(obj)
            if isempty(obj.hFig)
                obj.initGUI();
            end
            
            obj.hFig.Visible = 'on';
        end
    end
    
    %% Internal Properties
    properties (Hidden, SetAccess = private)
        hTimer;                                         % Timer object to grab new frames at fixed intervals for a pseudo live video mode.
    end
    
    properties (Hidden, Dependent, SetAccess = private)
        videoTimerActive;                               % Boolean to indicate whether live mode is active.
    end
    
    properties (Access = private)
        hFig;
        hFOVPanel;
        hFOVAxes;
        hMainFlow;
        hSurf;
    end
    
    %% INTERNAL METHODS
    methods(Hidden)
        function initGUI(obj)
            obj.hFig = figure('numbertitle','off','name',obj.cameraName,'menubar','none','units','pixels',...
                'position',most.gui.centeredScreenPos([800 800]),'CloseRequestFcn',@hideGUI);
            
            obj.hMainFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown','Margin',0.0001);
            obj.hFOVPanel = uipanel('parent',obj.hMainFlow,'bordertype','none');
            obj.hFOVAxes = axes('parent',obj.hFOVPanel,'box','off','Color','k','GridColor',.9*ones(1,3),...
                'xgrid','off','ygrid','off','GridAlpha',.25,'XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',[],'units','normalized','position',[0 0 1 1],'DataAspectRatio',[1 1 1]);
            
            hBottomFlow = most.gui.uiflowcontainer('Parent',obj.hMainFlow,'FlowDirection','LeftToRight','HeightLimits',[100 100], 'Margin', 16);
            
            pbSS = most.gui.uicontrol('parent',hBottomFlow,'string','Snap Shot','FontSize',10,'HorizontalAlignment','center','Callback', @obj.GuiSnap);
            
            [xx,yy,zz] = meshgrid([0 obj.resolutionXY(1)-1],[0 obj.resolutionXY(2)-1],1);
            if obj.isTransposed
                yy = yy';
                xx = xx';
            end
            obj.hSurf = surface('parent',obj.hFOVAxes,'CData','','FaceColor','texturemap','EdgeColor','none','XData',xx,'YData',yy,'ZData',zz);
            obj.hFOVAxes.XLim = [0 obj.resolutionXY(1)-1];
            obj.hFOVAxes.YLim = [0 obj.resolutionXY(2)-1];
            
            colormap gray;
            
            function hideGUI(varargin)
                obj.abort();
                obj.hFig.Visible = 'off';
            end
        end
        
        function GuiSnap(obj, varargin)
            img = obj.grabFrame();
            obj.displayImage(img);
        end
        
        function displayImage(obj,image)
            obj.hSurf.CData = image;
        end
        
        function propNames = getUserPropertyList(obj)
            mc = metaclass(obj);
            
            mStaticProps = mc.PropertyList;
            
            % get static properties
            mask = filterProps(mStaticProps);
            
            mValidProps = mStaticProps(mask);
            
            % get dynamic properties
            allPropNames = properties(obj);
            dynPropNames = setdiff(allPropNames,{mStaticProps.Name});
            
            if ~isempty(dynPropNames)
                for i=1:numel(dynPropNames)
                    mDynProps(i) = findprop(obj, dynPropNames{i});
                end
                
                mask = filterProps(mDynProps);
                mValidProps = [mValidProps;mDynProps(mask) .'];
            end
            propNames = {mValidProps.Name};
            
            %%% local function
            function mask = filterProps(metaProps)
                if isempty(metaProps)
                    mask = [];
                    return;
                end
                isHidden     = [metaProps.Hidden];
                isObservable = [metaProps.SetObservable];
                isTransient  = [metaProps.Transient];
                setPublic    = strcmp({metaProps.SetAccess}, 'public');
                getPublic    = strcmp({metaProps.GetAccess}, 'public');
                
                mask = (~isHidden) & (~isTransient) & isObservable & (setPublic & getPublic);
            end
        end
        
        function metaProps = filterUserProps(obj,metaProps)
            % override this function if needed
        end
        
        function s = saveUserProps(obj)
            s = struct();
            s.cameraClass__ = class(obj);
            propnames = obj.getUserPropertyList();
            for idx = 1:length(propnames)
                propname = propnames{idx};
                s.(propname) = obj.(propname);
            end
        end
        
        function loadUserProps(obj,s)
            assert(strcmp(s.cameraClass__,class(obj)),'Properties do not match camera class');
            s = rmfield(s,'cameraClass__');
            
            propnames = fieldnames(s);
            for idx = 1:length(propnames)
                propname = propnames{idx};
                try
                    obj.(propname) = s.(propname);
                catch ME
                    % no op
                end
            end
        end
    end
    
    methods(Access=private)
        function img = grabFrameNoThrow(obj)
            img = [];
            try
                img = obj.grabFrame();
            catch ME
                most.idioms.reportError(ME);
            end
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function val = get.videoTimerActive(obj)
            val = false;
            
            if most.idioms.isValidObj(obj.hTimer)
                val = strcmpi(obj.hTimer.Running,'on');
            end
        end
    end
end

%--------------------------------------------------------------------------%
% CameraInterface.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
