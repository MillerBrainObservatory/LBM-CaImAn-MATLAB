classdef GuiElement < handle
    properties
        Position
        hUIPanel
        hParent
        Units
        minSizePixel = [0 0];
        maxSizePixel = [Inf Inf];
        hFig;
    end
    
    events (Hidden)
        scrollWheel;
    end
    
    properties (SetAccess = private,Hidden)
        hScrollWheelListener;
    end
    
    methods
        function obj = GuiElement(hParent,varargin)
            obj.hParent = hParent;
            
            if isa(obj.hParent,'matlab.ui.Figure')
                obj.hParent.SizeChangedFcn = @(varargin)obj.panelResized;
                obj.hParent.WindowScrollWheelFcn = @obj.scrollWheelListenerFcn;
                obj.hUIPanel = uipanel('Parent',hParent,varargin{:});
            else
                assert(isa(obj.hParent,mfilename('class')),'GuiElement can only be a child of a figure or another GuiElement');
                obj.hUIPanel = uipanel('Parent',hParent.hUIPanel,varargin{:});
                obj.hScrollWheelListener = addlistener(obj.hParent,'scrollWheel',@obj.scrollWheelListenerFcn);
                obj.hScrollWheelListener.Recursive = true;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hUIPanel);
            most.idioms.safeDeleteObj(obj.hScrollWheelListener);
        end
        
        function scrollWheelListenerFcn(obj,src,evt)
            evt_ = most.gui.ScrollWheelData();
            evt_.VerticalScrollCount = evt.VerticalScrollCount;
            evt_.VerticalScrollAmount = evt.VerticalScrollAmount;
            obj.notify('scrollWheel',evt_);
            obj.scrollWheelFcn(src,evt);
        end
    end
    
    methods
        function set.Position(obj,val)
            obj.hUIPanel.Position = val;
            val = obj.getPositionInUnits('pixel');
            % scale around center
            sz = val(3:4);
            sz = max(sz,obj.minSizePixel);
            sz = min(sz,obj.maxSizePixel);
            val = [val(1)+(val(3)-sz(1))/2,val(2)+(val(4)-sz(2))/2,sz(1),sz(2)];
            
            obj.setPositionInUnits('pixel',val);
            obj.panelResized();
        end
        
        function maximize(obj)
            obj.setPositionInUnits('normalized',[0 0 1 1]);
            obj.panelResized();
        end
        
        function val = get.Position(obj)
            val = obj.hUIPanel.Position;
        end
        
        function set.Units(obj,val)
            obj.hUIPanel.Units = val;
        end
        
        function val = get.Units(obj) 
            val = obj.hUIPanel.Units;
        end
        
        function val = getPositionInUnits(obj,units)
            units_ = obj.Units;
            obj.Units = units;
            try
                val = obj.Position;
            catch ME
                obj.Units = units_;
                rethrow(ME);
            end
            obj.Units = units_;
        end
        
        function setPositionInUnits(obj,units,val)
            units_ = obj.Units;
            obj.Units = units;
            try
                obj.hUIPanel.Position = val;
            catch ME
                obj.Units = units_;
                rethrow(ME);
            end
            obj.Units = units_;
            obj.panelResized();
        end
        
        function val = get.hFig(obj)
            val = ancestor(obj.hUIPanel,'figure');
        end
    end
    
    methods (Abstract)
        panelResized(obj)
        init(obj)
        scrollWheelFcn(obj,src,evt)
    end
    
end

%--------------------------------------------------------------------------%
% GuiElement.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
