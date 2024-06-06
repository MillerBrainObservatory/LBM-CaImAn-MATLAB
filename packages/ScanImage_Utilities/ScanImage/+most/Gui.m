classdef Gui < matlab.mixin.SetGet & dynamicprops
    %GUI Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetObservable)
        Visible;
    end
    
    properties (Hidden)
        hFig;
        hModel;
        hController;
        
        hCtls = {};
        hLis;
        tfMap = containers.Map({true false}, {'on' 'off'});
    end
    
    methods
        function obj = Gui(hModel, hController, size, units, varargin)
            if nargin > 0
                obj.hModel = hModel;
            end
            
            if nargin > 1
                obj.hController = hController;
            end
            
            if nargin < 3
                size = [];
            end
            
            if nargin < 4 || isempty(units)
                units = 'pixels';
            end
            
            obj.hFig = figure('numbertitle', 'off', 'visible', 'off', 'menubar', 'none','Units',units,...
                'Color', get(0,'defaultfigureColor'), 'PaperPosition',get(0,'defaultfigurePaperPosition'),...
                'ScreenPixelsPerInchMode','manual', 'ParentMode', 'manual', 'HandleVisibility','callback',varargin{:});
            
            if ~isempty(size)
                p = most.gui.centeredScreenPos(size,units);
                set(obj.hFig, 'position', p)
            end
            
            %note this handle keeps this object in context as long as the
            %figure is still open even if all handles to the object go out
            %of scope
            set(obj.hFig,'UserData',obj);
            set(obj.hFig,'DeleteFcn',@(varargin)obj.figDeleted());
            
            obj.hLis = obj.hFig.addlistener('ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hLis(2) = obj.hFig.addlistener('Visible','PostSet',@(varargin)obj.visibleChangedHook);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLis);
            
            for i = 1:numel(obj.hCtls)
                most.idioms.safeDeleteObj(obj.hCtls{i});
            end
            
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% Public methods
    methods
        function hCtl = addUiControl(obj,varargin)
            if ~any(strcmpi(varargin,'Parent'))
                varargin{end+1} = 'Parent';
                varargin{end+1} = obj.hFig;
            end
            hCtl = most.gui.uicontrol(varargin{:});
            name = get(hCtl, 'Tag');
            obj.hCtls{end+1} = hCtl;
            
            if isvarname(name)
                hProp = obj.addprop(name);
                hProp.Hidden = true;
                obj.(name) = hCtl;
            end
        end
        
        function convertToRelPosition(obj)
            for i = 1:numel(obj.hCtls)
                obj.hCtls{i}.convertToRelPosition();
            end
        end
    end
    
    %% Internal
    methods (Hidden)
        function figDeleted(obj)
            % called if the figure is deleted. Default behavior is do
            % nothing
        end
        
        function val = validatePropArg(obj,propname,val)
            
        end
    end
    
    %% Prop Access
    methods
        function val = get.Visible(obj)
            val = strcmp(get(obj.hFig,'Visible'),'on');
        end
        
        function set.Visible(obj,val)
            if val
            	set(obj.hFig,'Visible','on');
            else
            	set(obj.hFig,'Visible','off');
            end
        end
    end
    
    methods (Hidden,Access=protected)
        function visibleChangedHook(~)
            % can be overloaded by child class
        end
    end
end



%--------------------------------------------------------------------------%
% Gui.m                                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
