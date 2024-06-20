classdef uicontrolLayout < handle
    events (NotifyAccess = private)
        layoutModeChanged
    end
    
    properties
        layoutModeEnable = false;
    end
    
    properties (Hidden, SetAccess = private)
        currentUiControl;
        currentFig;
        figInfo;
        undoInfo;
        hFig;
        buttonMode = 'position';
        buttonIncrement = 1;
        Ctls;
        grid = false;
        coarse = 1;
    end
    
    properties (Hidden, Dependent)
        gridFcn;
    end
    
    methods
        function obj = uicontrolLayout()
            singletonObj = Singleton();

            if isempty(singletonObj) || ~isvalid(singletonObj)
                % retrieved singleton is invalid; store this object as singleton
                Singleton(obj);
                obj.initFig();
            else
                % delete this object and replace with retrieved singleton
                delete(obj);
                obj = singletonObj;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods (Access = private)
        function initFig(obj)
            obj.hFig = figure('Name','Layout','NumberTitle','off','MenuBar','none','CloseRequestFcn',@(varargin)deactivateLayoutMode,'Visible','off');
            obj.hFig.WindowKeyPressFcn = @obj.keyPressFcn;
            obj.hFig.Position(3:4) = [160 205];
            
            flowMargin = 1;
            arrowSize = 50;
            
            topflow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown','Margin',flowMargin);
            
            arrowFlow = most.gui.uiflowcontainer('Parent',topflow,'FlowDirection','LeftToRight','Margin',flowMargin,'HeightLimits',3*arrowSize);
                arrowFlow_vert = most.gui.uiflowcontainer('Parent',arrowFlow,'FlowDirection','TopDown','Margin',flowMargin,'WidthLimits',3*arrowSize);
                    arrowFlowTopRow    = most.gui.uiflowcontainer('Parent',arrowFlow_vert,'FlowDirection','LeftToRight','Margin',flowMargin);
                    arrowFlowMiddleRow = most.gui.uiflowcontainer('Parent',arrowFlow_vert,'FlowDirection','LeftToRight','Margin',flowMargin);
                    arrowFlowBottomRow = most.gui.uiflowcontainer('Parent',arrowFlow_vert,'FlowDirection','LeftToRight','Margin',flowMargin);
                    
            labelFlow = most.gui.uiflowcontainer('Parent',topflow,'FlowDirection','LeftToRight','Margin',flowMargin,'HeightLimits',[25 25]);
            posFlow   = most.gui.uiflowcontainer('Parent',topflow,'FlowDirection','LeftToRight','Margin',flowMargin,'HeightLimits',[25 25]);

            obj.Ctls = struct();
            buttonProps = {'Style', 'pushbutton'};
            obj.Ctls.buttonMode = uicontrol('Parent', arrowFlowTopRow,    'String', 'Pos', 'Callback', @(varargin)toggleMode(), buttonProps{:});
            uicontrol('Parent', arrowFlowTopRow,    'String', 'Up', 'Callback', @(varargin)obj.buttonPressed([0 1]), buttonProps{:});
            obj.Ctls.coarse = uicontrol('Parent', arrowFlowTopRow,    'String',   'Coarse', 'Callback', @(varargin)toggleCoarse, buttonProps{:});
            
            uicontrol('Parent', arrowFlowMiddleRow, 'String', 'L', 'Callback', @(varargin)obj.buttonPressed([-1 0]), buttonProps{:});
            uicontrol('Parent', arrowFlowMiddleRow, 'String', 'X', 'Callback', @(varargin)obj.done(), buttonProps{:});
            uicontrol('Parent', arrowFlowMiddleRow, 'String', 'R', 'Callback', @(varargin)obj.buttonPressed([1 0]), buttonProps{:});
            
            uicontrol('Parent', arrowFlowBottomRow, 'String', 'Undo', 'Callback', @(varargin)obj.undo, buttonProps{:});
            uicontrol('Parent', arrowFlowBottomRow, 'String', 'D', 'Callback', @(varargin)obj.buttonPressed([0 -1]), buttonProps{:});
            obj.Ctls.grid = uicontrol('Parent', arrowFlowBottomRow, 'String', 'Grid', 'Callback', @(varargin)toggleGrid, buttonProps{:});
            
            obj.Ctls.label = uicontrol('Parent', labelFlow, 'String', '', 'Style', 'edit', 'Enable', 'inactive');
            obj.Ctls.position = uicontrol('Parent', posFlow, 'String', '', 'Style', 'edit', 'Callback', @(varargin)obj.changePosition());
            
            function toggleMode()
                switch obj.buttonMode
                    case 'position'
                        obj.buttonMode = 'size';
                    case 'size'
                        obj.buttonMode = 'position';
                end
            end
            
            function toggleGrid()
                obj.grid = ~obj.grid;
            end
            
            function toggleCoarse()
                if obj.coarse == 1
                    obj.coarse = 10;
                else
                    obj.coarse = 1;
                end
            end
            
            function deactivateLayoutMode()
                obj.layoutModeEnable = false;
            end
        end
        
        function changePosition(obj)
            try
                pos = eval(obj.Ctls.position.String);
                validateattributes(pos,{'numeric'},{'row','numel',4,'nonnan','positive','finite','real'});
                
                obj.currentUiControl.hCtl.Position = pos;
            catch ME
                obj.changedPosition();
                rethrow(ME);
            end
        end
        
        function changedPosition(obj)
            if isempty(obj.currentUiControl)
                posStr = '';
            else
                pos = obj.currentUiControl.hCtl.Position;
                posStr = mat2str(pos);
            end
            
            obj.Ctls.position.String = posStr;
        end
        
        function buttonPressed(obj,drXY)
            if isempty(obj.currentUiControl)
                return
            end
            
            switch obj.buttonMode
                case 'position'
                    obj.move(drXY * obj.buttonIncrement * obj.coarse);
                case 'size'
                    obj.changeSize(drXY * obj.buttonIncrement * obj.coarse);
                otherwise
                    error('Unknown buttonMode: %s', obj.buttonMode);
            end
        end
        
        function keyPressFcn(obj,src,evt)
            switch evt.Key
                case 'rightarrow'
                    obj.buttonPressed([1 0]);
                case 'leftarrow'
                    obj.buttonPressed([-1 0]);
                case 'uparrow'
                    obj.buttonPressed([0 1]);
                case 'downarrow'
                    obj.buttonPressed([0 -1]);
                    
                otherwise
                    if ~isempty(obj.currentFig) && ~isequal(src,obj.hFig)
                        obj.figInfo.WindowKeyPressFcn(src,evt); % forward event
                    end
            end
        end
    end
    
    methods
        function undo(obj)
            if ~isempty(obj.currentUiControl)
                obj.currentUiControl.hCtl.Position = obj.undoInfo.Position;
            end
        end
        
        function done(obj)
            obj.currentUiControl = [];
        end
        
        function updateLayoutDefinition(obj)
            if ~isempty(obj.currentUiControl)
                if ~isequal(obj.currentUiControl.hCtl.Position,obj.undoInfo.Position)
                    try
                        obj.currentUiControl.updateLayoutDefinition();
                    catch ME
                        most.idioms.reportError(ME);
                    end
                end
            end
        end
        
        function move(obj,drXY)
            assert(~isempty(obj.currentUiControl));
            
            obj.currentUiControl.hCtl.Position(1:2) = obj.gridFcn( obj.currentUiControl.hCtl.Position(1:2)+drXY );
            obj.changedPosition();
        end
        
        function changeSize(obj,drXY)
            assert(~isempty(obj.currentUiControl));
            
            obj.currentUiControl.hCtl.Position(3:4) = obj.gridFcn( obj.currentUiControl.hCtl.Position(3:4)+drXY );
            obj.changedPosition();
        end
    end
    
    methods (Static)
        function toggleLayoutMode()
            constructor = str2func( mfilename('class') );
            obj = constructor();
            
            obj.layoutModeEnable = ~obj.layoutModeEnable;
        end        
    end
    
    methods (Hidden)
        function editUiControl(obj,uiControl)
            assert(isa(uiControl,'most.gui.uicontrol'));
            obj.currentUiControl = uiControl;
            
            windowButtonMotionFcn = obj.currentFig.WindowButtonMotionFcn;
            windowButtonUpFcn = obj.currentFig.WindowButtonUpFcn;
            figUnits = obj.currentFig.Units;
            ctlUnits = obj.currentUiControl.hCtl.Units;
            obj.currentFig.Units = 'pixels';
            obj.currentUiControl.hCtl.Units = 'pixels';
            
            startPt = obj.currentFig.CurrentPoint;
            startPos = obj.currentUiControl.hCtl.Position;
            
            obj.currentFig.WindowButtonMotionFcn = @move;
            obj.currentFig.WindowButtonUpFcn = @abortMove;            

            function move(varargin)
                try
                    pt = obj.currentFig.CurrentPoint;
                    obj.currentUiControl.hCtl.Position(1:2) = obj.gridFcn(startPos(1:2) + pt-startPt);
                    obj.changedPosition();
                catch ME
                    abortMove();
                    rethrow(ME);
                end
            end
            
            function abortMove(varargin)
                obj.currentFig.WindowButtonMotionFcn = windowButtonMotionFcn;
                obj.currentFig.WindowButtonUpFcn = windowButtonUpFcn;
                obj.currentFig.Units = figUnits;
                obj.currentUiControl.hCtl.Units = ctlUnits;
            end
        end
    end
    
    %% property getter/setter
    methods
        function set.layoutModeEnable(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            
            if val ~= obj.layoutModeEnable
                if val
                    obj.hFig.Visible = 'on';
                    figure(obj.hFig);
                else
                    obj.hFig.Visible = 'off';
                    obj.currentUiControl = [];
                end
                
                obj.layoutModeEnable = logical(val);
                obj.notify('layoutModeChanged');
            end
        end
        
        function set.currentUiControl(obj,val)
            assert(obj.layoutModeEnable);
            oldVal = obj.currentUiControl;
            if ~isempty(val)
                validateattributes(val,{'most.gui.uicontrol'},{'scalar'});
            end
            
            if isequal(oldVal,val)
                return
            end
            
            if ~isempty(oldVal)
                obj.updateLayoutDefinition(); % update old UiControl
            end
            
            obj.currentUiControl = val;
            obj.undoInfo = [];
            
            if isempty(obj.currentUiControl)
                obj.Ctls.label.String = '';
                obj.currentFig = [];
            else
                obj.undoInfo = struct();
                obj.undoInfo.Position = obj.currentUiControl.hCtl.Position;
                
                obj.hFig.Visible = 'on';
                figure(obj.hFig);
                
                obj.Ctls.label.String = obj.currentUiControl.hCtl.Tag;
                obj.currentFig = ancestor(obj.currentUiControl.hCtl,'figure');
            end
            
            obj.changedPosition();
        end
        
        function set.currentFig(obj,val)
            oldFig = obj.currentFig;
            oldFigInfo = obj.figInfo;
            
            if isequal(oldFig,val)
                return
            end
            
            if ~isempty(oldFig)
                oldFig.WindowKeyPressFcn = oldFigInfo.WindowKeyPressFcn;
            end
            
            obj.currentFig = val;
            obj.figInfo = [];
            
            if ~isempty(obj.currentFig)
                obj.figInfo.WindowKeyPressFcn = obj.currentFig.WindowKeyPressFcn;
                obj.currentFig.WindowKeyPressFcn = @obj.keyPressFcn;
            end
        end
        
        function set.buttonMode(obj,val)
            mask = strcmp(val,{'size','position'});
            assert(sum(mask) == 1,'Unknown mode: %s',val);
            
            obj.buttonMode = val;
            switch obj.buttonMode
                case 'size'
                    obj.Ctls.buttonMode.String = 'Sz';
                case 'position'
                    obj.Ctls.buttonMode.String = 'Pos';
            end
        end
        
        function set.grid(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar'});
            obj.grid = logical(val);
            
            if obj.grid
                obj.Ctls.grid.BackgroundColor = [0.5 1 0.5];
            else
                obj.Ctls.grid.BackgroundColor = ones(1,3) * 0.94;
            end
        end
        
        function set.coarse(obj,val)
            validateattributes(val,{'numeric'},{'scalar'});
            obj.coarse = val;
            
            if obj.coarse > 1
                obj.Ctls.coarse.BackgroundColor = [0.5 1 0.5];
            else
                obj.Ctls.coarse.BackgroundColor = ones(1,3) * 0.94;
            end
        end
        
        function val = get.gridFcn(obj)
            if obj.grid
                val = @(d)round(d/obj.coarse)*obj.coarse;
            else
                val = @(d)d;
            end
        end
    end
end

%% Local functions
function obj = Singleton(newObj)
    persistent localObj
    
    if nargin > 0 && ~isempty(newObj)
        localObj = newObj;
    end
    
    obj = localObj;
end

%--------------------------------------------------------------------------%
% uicontrolLayout.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
