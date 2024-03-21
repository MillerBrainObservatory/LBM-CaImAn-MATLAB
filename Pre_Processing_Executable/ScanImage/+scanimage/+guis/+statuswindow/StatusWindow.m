classdef StatusWindow < most.Gui
    %STATUSWINDOW Summary of this class goes here
    %   Detailed explanation goes here
    properties
        stayOnTop = false;
        shuttersOpen = [];
        pockelsValue = [];
        pockelsCalibrated = [];
        acqState = '';
        
        cmdCloneVisible = true;
        cmdClonePinned = false;
        
        figureWidthCollapsed = 118;
        figureWidthExpanded = 300;
    end
    
    properties (Access = private)
        containers;
        controls;
        
        mouseHistory;
        mouseTrackingTimer;
    end
    
    methods
        function obj = StatusWindow(hModel,hController)
            if nargin < 2 || isempty(hModel)
                hModel = [];
            end
            
            if nargin < 2 || isempty(hController)
                hController = [];
            end
            
            obj = obj@most.Gui(hModel,hController);
            
            obj.hFig.CloseRequestFcn = @obj.closeRequestFcn;
            obj.hFig.Name = 'Status Window';
            obj.hFig.Visible = 'off';
            
            obj.containers.main = most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
                obj.containers.cmwClone = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','TopDown');
                    % wait with creation of cmwClone until all other
                    % controls are created. cmwClone will make the figure
                    % visible, so that the layout should be complete at
                    % that point
                obj.containers.indicators = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','TopDown');
                    obj.containers.indicators.WidthLimits = [110,110];
                    numShutters = createShutterDisplays(obj.containers.indicators);
                    numPockels  = createPockelsDisplays(obj.containers.indicators);

                    obj.controls.hCbStayOnTop = uicontrol('Parent',obj.containers.indicators,'Style','checkbox','Value',obj.stayOnTop,'String','Stay on top','Tooltip','Keep status window on top of other windows.','Callback',@(varargin)obj.toggleStayOnTop());
                    obj.controls.hCbStayOnTop.HeightLimits = [20 20];
                    
                    obj.controls.hPbRaiseWindows = uicontrol('Parent',obj.containers.indicators,'Style','pushbutton','String','Raise Windows','Tooltip','Show all ScanImage windows','Callback',@(varargin)obj.raiseWindows());
                    obj.controls.hPbRaiseWindows.HeightLimits = [25 25];
                    
                    obj.containers.bottom = most.idioms.uiflowcontainer('Parent',obj.containers.indicators,'FlowDirection','LeftToRight');
                        obj.controls.hPbPinCmdWindow = uicontrol('Parent',obj.containers.bottom,'Style','pushbutton','String','<','TooltipString','Pin command window open','Callback',@obj.toggleCmdClonePinned);
                        obj.controls.hPbPinCmdWindow.WidthLimits = [20 20];
                        obj.controls.hSIAbort = uicontrol('Parent',obj.containers.bottom,'Style','pushbutton','HorizontalAlignment','center','Tooltip','Click to abort ScanImage immediately and close all shutters','Callback',@obj.siAbort,'FontWeight','bold');
                
                    % now create cmwClone in obj.containers.cmwClone
                    obj.controls.hCmwClone = scanimage.guis.statuswindow.CmwClone(obj.containers.cmwClone);

                    
%             obj.stayOnTop = obj.stayOnTop;
            obj.cmdCloneVisible = false;
            
            numButtons = numShutters + numPockels;
            buttonHeight = 50 * numButtons;
            staticHeight = 70;
            
            height = buttonHeight + staticHeight;
            height = max(200,height);
            obj.hFig.Position(4) = height;
            
            movegui(obj.hFig,'northeast');
            
            obj.mouseTrackingTimer = timer('Name','Mouse Tracking Timer Status Window','ExecutionMode','fixedSpacing','Period',0.5,'TimerFcn',@obj.mouseTrackingTimerCb);
            obj.hFig.WindowButtonMotionFcn = @obj.startMouseTracking;
            obj.hFig.KeyPressFcn = @obj.keyPressFcn;
            
            %%% local functions                
            function numShutters = createShutterDisplays(container)                
                if isempty(hModel)
                    % for testing
                    numShutters = 3;
                    shutterNames = {'Shutter 1','Shutter 2','Shutter 3'};
                else
                    numShutters = hModel.hShutters.numInstances;
                    shutterNames = hModel.hShutters.mdfData.shutterNames;
                end
                
                obj.controls.shutterDisplays = scanimage.guis.statuswindow.ShutterDisplaySimple.empty(1,0);
                for idx = 1:numShutters
                    name = shutterNames{idx};
                    obj.controls.shutterDisplays(end+1) = scanimage.guis.statuswindow.ShutterDisplaySimple(container,name);
                    obj.controls.shutterDisplays(end).hSI = hModel;
                    obj.controls.shutterDisplays(end).shutterID = idx;
                end
            end
            
            function numPockels = createPockelsDisplays(container)
                if isempty(hModel)
                    % for testing
                    numPockels = 3;
                    pockelsNames = {'Beam 1','Beam 2','Beam 3'};
                else
                    numPockels = hModel.hBeams.totalNumBeams;
                    pockelsNames = hModel.hBeams.displayNames;
                end
                
                obj.controls.pockelsDisplays = scanimage.guis.statuswindow.PockelsDisplay.empty(1,0);
                for idx = 1:numPockels
                    obj.controls.pockelsDisplays(end+1) = scanimage.guis.statuswindow.PockelsDisplay(container,pockelsNames{idx});
                end
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.mouseTrackingTimer);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods (Hidden, Access=protected)
        function visibleChangedHook(obj)
            if obj.Visible
                obj.controls.hCmwClone.initVisProps();
                obj.stayOnTop = obj.stayOnTop;
            end
        end
    end
    
    methods (Hidden)
        function startMouseTracking(obj,varargin)
            persistent lock
            if isempty(lock)
                lock = false;
            elseif lock
                return % prevents reentry
            end
            
            obj.hFig.WindowButtonMotionFcn = [];
            try
                obj.mouseEnteredWindow();
            catch ME
                most.idioms.reportError(ME);
            end
            start(obj.mouseTrackingTimer);
        end
        
        function stopMouseTracking(obj,varargin)
            stop(obj.mouseTrackingTimer);
            try
                obj.mouseExitedWindow();
            catch ME
                most.idioms.reportError(ME);
            end
            obj.hFig.WindowButtonMotionFcn = @obj.startMouseTracking;
        end
        
        function mouseTrackingTimerCb(obj,varargin)
            groot_ = groot();
            groot_.Units = 'pixels';
            pt = groot_.PointerLocation;
            
            obj.hFig.Units = 'pixels';
            pos = obj.hFig.OuterPosition;
            
            if pt(1) <= pos(1) || pt(1) >= sum(pos([1,3])) || pt(2) <= pos(2) || pt(2) >= sum(pos([2,4]))
                obj.stopMouseTracking();
            end
        end
        
        function mouseEnteredWindow(obj)
            if ~obj.cmdCloneVisible
                obj.cmdCloneVisible = true;
            end
            
            if ~obj.stayOnTop
                figure(obj.hFig); % is this too intrusive?
            end
        end
        
        function mouseExitedWindow(obj)
            if obj.cmdCloneVisible && ~obj.cmdClonePinned
                obj.cmdCloneVisible = false;
            end
        end
        
        function keyPressFcn(obj,varargin)
            uicontrol(obj.controls.hCmwClone.controls.cmwprompt);
        end
        
        function toggleCmdClonePinned(obj,src,evt)
            obj.cmdClonePinned = ~obj.cmdClonePinned;
        end
    end
    
    methods
        function raiseWindows(obj)
            drawnow();
            obj.hController.raiseAllGUIs();
        end
        
        function toggleStayOnTop(obj)
            obj.stayOnTop = ~obj.stayOnTop;
        end
        
        function changedStayOnTop(obj)
            obj.controls.hCbStayOnTop.Value = obj.stayOnTop;
        end
        
        function closeRequestFcn(obj,varargin)
            if isempty(obj.hModel)
                obj.delete();
            else
                % no-op
            end
        end
        
        function set.shuttersOpen(obj,val)
            assert(numel(val)==numel(obj.controls.shutterDisplays));
            for idx = 1:length(obj.controls.shutterDisplays)
                obj.controls.shutterDisplays(idx).shutterOpen = val(idx);
            end
            obj.shuttersOpen = val;
        end
        
        function set.pockelsValue(obj,val)
            assert(numel(val)==numel(obj.controls.pockelsDisplays));
            
            for idx = 1:length(obj.controls.pockelsDisplays)
                obj.controls.pockelsDisplays(idx).value = val(idx);
            end
            obj.pockelsValue = val;
        end
        
        function set.pockelsCalibrated(obj,val)
            assert(numel(val)==numel(obj.controls.pockelsDisplays));
            
            for idx = 1:length(obj.controls.pockelsDisplays)
                obj.controls.pockelsDisplays(idx).calibrated = val(idx);
            end
            obj.pockelsCalibrated = val;
        end
        
        function set.stayOnTop(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            
            wasVisible = obj.hFig.Visible;
            obj.hFig.Visible = 'on';
            if val
                most.gui.winOnTop(obj.hFig,true);
            else
                most.gui.winOnTop(obj.hFig,false);
            end
            
            if ~val
                obj.hFig.Visible = wasVisible;
            end
                
            obj.stayOnTop = val;
            
            obj.changedStayOnTop();
        end
        
        function set.acqState(obj,val)
            if isempty(val)
                val = ''; % esnure correct type
            else
                validateattributes(val,{'char'},{'vector'});
            end
            
            obj.acqState = val;
            
            if strcmpi(val,'idle')
               hFig = ancestor(obj.controls.hSIAbort,'figure');
               obj.controls.hSIAbort.BackgroundColor = hFig.Color;
               obj.controls.hSIAbort.ForegroundColor = [0 0 0];
               obj.controls.hSIAbort.String = upper(val);
            else
               obj.controls.hSIAbort.BackgroundColor = [1 0 0];
               obj.controls.hSIAbort.ForegroundColor = [0 0 0];
               obj.controls.hSIAbort.String = sprintf('ABORT %s', upper(val));
            end
        end
        
        function set.cmdClonePinned(obj,val)
            obj.cmdClonePinned = val;
            if val && ~obj.cmdCloneVisible
                obj.cmdCloneVisible = true;
            end
            
            if val
                obj.controls.hPbPinCmdWindow.String = '>';
            else
                obj.controls.hPbPinCmdWindow.String = '<';
            end
        end
        
        function set.cmdCloneVisible(obj,val)
            if obj.cmdClonePinned
                val = true;
            end
            
            oldVal = obj.cmdCloneVisible;
            obj.cmdCloneVisible = val;
            
            if val
                vis = 'on';
            else
                vis = 'off';
            end
            obj.containers.cmwClone.Visible = vis;
            
            obj.hFig.Units = 'pixels';
            figPosition = obj.hFig.Position;
            
            if val && ~oldVal
                newWidth = obj.figureWidthExpanded;
                %obj.figureWidthCollapsed = figPosition(3);
            elseif ~val && oldVal
                newWidth = obj.figureWidthCollapsed;
                obj.figureWidthExpanded = figPosition(3);
            else
                newWidth = [];
            end
            
            if ~isempty(newWidth)
                obj.hFig.Position([1,3]) = [figPosition(1)+figPosition(3)-newWidth, newWidth];
                drawnow();
                actualPosition = obj.hFig.Position;
                if newWidth ~= actualPosition(3)
                    obj.hFig.Position(1) = actualPosition(1)-actualPosition(3)+newWidth; % protects against unsettable value for newWidth
                end
            end
        end
        
        function siAbort(obj,varargin)
            if ~isempty(obj.hModel) && isvalid(obj.hModel)
                obj.hModel.abort();
            else
                msgbox('Cannot abort ScanImage, Invalid handle');
            end
        end
    end
    
end



%--------------------------------------------------------------------------%
% StatusWindow.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
