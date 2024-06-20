classdef checkbox < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hTxt;
        hAx;
        hPnl;
        hLis;
        hFig;
        
        bindings = {};
        hBindingListeners = {};
        
        % pass through to hCtl
        String;
        Visible;
        Style = 'checkbox';
        Value = 1;
    end
    
    methods
        function obj = checkbox(varargin)
            ip = most.util.InputParser;
            ip.addOptional('Bindings', {});
            ip.addOptional('HorizontalAlignment', 'left');
            ip.addOptional('VerticalAlignment','middle');
            ip.addOptional('FontSize',8);
            ip.addOptional('FontWeight',[]);
            ip.addOptional('ForegroundColor','k');
            ip.addOptional('String','');
            ip.addOptional('units','');
            ip.addOptional('BackgroundColor',[]);
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.parse(varargin{:});
            othrs = most.util.structPV2cellPV(ip.Unmatched);
            
            if ~isempty(ip.Results.units)
                obj.hPnl = uipanel('units',ip.Results.units,othrs{:},'BorderType','None','ButtonDownFcn',@obj.clickDD);
            else
                obj.hPnl = uipanel(othrs{:},'BorderType','None','ButtonDownFcn',@obj.clickDD);
            end
            
            obj.hFig = ancestor(obj.hPnl,'figure');
            
            if ~isempty(ip.Results.BackgroundColor)
                obj.hPnl.BackgroundColor = ip.Results.BackgroundColor;
            end
    
            if ~isempty(ip.Results.WidthLimits)
                lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
                set(obj.hPnl, 'WidthLimits', lms(1:2));
            end
            if ~isempty(ip.Results.HeightLimits)
                lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
                set(obj.hPnl, 'HeightLimits', lms(1:2));
            end
            
            obj.hAx = axes('parent',obj.hPnl,'color','none','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',[],'xcolor','none','ycolor','none','position',[0 0 1 1],'hittest','off');
            
            switch lower(ip.Results.HorizontalAlignment)
                case 'left'
                    pos = 0;
                case 'center'
                    pos = 0.5;
                case 'right'
                    pos = 1;
            end
            
            switch lower(ip.Results.VerticalAlignment)
                case 'top'
                    pos(2) = 1;
                case 'middle'
                    pos(2) = 0.55;
                case 'bottom'
                    pos(2) = 0;
            end
            
            obj.hTxt = text(pos(1),pos(2),0,[char(9745) ' ' ip.Results.String],'parent',obj.hAx,'HorizontalAlignment',ip.Results.HorizontalAlignment,...
                'VerticalAlignment',ip.Results.VerticalAlignment,'units','normalized','FontSize',ip.Results.FontSize,'Color',ip.Results.ForegroundColor,'hittest','off');
            
            if ~isempty(ip.Results.FontWeight)
                obj.hTxt.FontWeight = ip.Results.FontWeight;
            end
            
            obj.bindings = ip.Results.Bindings;
            obj.hLis = addlistener(obj.hPnl.Parent,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLis);
            most.idioms.safeDeleteObj(obj.hTxt);
            most.idioms.safeDeleteObj(obj.hAx);
            most.idioms.safeDeleteObj(obj.hPnl);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
        end
    end
    
    methods (Hidden)
        function clickDD(obj,~,evt)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent tfInAxes
            persistent cv
            persistent ov
            
            if strcmp(evt.EventName, 'ButtonDown')
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                
                if obj.Value
                    cv = 9744;
                    ov = 9745;
                else
                    cv = 9745;
                    ov = 9744;
                end
                
                obj.hTxt.String(1) = cv;
                tfInAxes = true;
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.clickDD,'WindowButtonUpFcn',@obj.clickDD);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                tfInAxes = mouseIsInAxes(obj.hAx);
                if tfInAxes
                    obj.hTxt.String(1) = cv;
                else
                    obj.hTxt.String(1) = ov;
                end
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
                
                if tfInAxes
                    obj.Value = ~obj.Value;
                    obj.view2model();
                end
            end
        end
        
        function set(obj,prop,val)
            switch lower(prop)
                case 'horizontalalignment'
                    pos = obj.hTxt.Position;
                    switch lower(val)
                        case 'left'
                            pos(0) = 0;
                        case 'center'
                            pos(0) = 0.5;
                        case 'right'
                            pos(0) = 1;
                    end
                    obj.hTxt.Position = pos;
                    obj.hTxt.(prop) = val;
                    
                case 'verticalalignment'
                    pos = obj.hTxt.Position;
                    switch lower(val)
                        case 'top'
                            pos(2) = 1;
                        case 'middle'
                            pos(2) = 0.5;
                        case 'bottom'
                            pos(2) = 0;
                    end
                    obj.hTxt.Position = pos;
                    obj.hTxt.(prop) = val;
                    
                case 'string'
                    obj.hTxt.(prop) = val;
                
                otherwise
                    set(obj.hPnl,prop,val);
            end
        end
        
        function v = get(obj,prop)
            if ismember(lower(prop), {'horizontalalignment' 'verticalalignment' 'string'})
                v = obj.hTxt.(prop);
            else
                v = obj.hAx.(prop);
            end
        end
        
        function view2model(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            else
                binding = obj.bindings{bindingIdx};
                binding{1}.(binding{2}) = obj.Value;
            end
        end
        
        function model2view(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.model2view(i);
                end
            else
                binding = obj.bindings{bindingIdx};
                obj.Value = binding{1}.(binding{2});
            end
        end
    end
    
    methods
        function v = get.String(obj)
            v = obj.hTxt.String;
        end
        
        function set.String(obj,v)
            obj.hTxt.String = v;
        end
        
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj,v)
            obj.hPnl.Visible = v;
        end
        
        function set.bindings(obj,v)
            if ~isempty(obj.bindings)
                most.idioms.safeDeleteObj(obj.hBindingListeners);
                obj.hBindingListeners = {};
                obj.bindings = {};
            end
            
            if ~isempty(v)
                if ~iscell(v{1})
                    obj.bindings = {v};
                else
                    obj.bindings = v;
                end
                
                for i = 1:numel(obj.bindings)
                    binding = obj.bindings{i};
                    obj.hBindingListeners{end+1} = binding{1}.addlistener(binding{2},'PostSet',@(varargin)obj.model2view(i));
                    obj.model2view(i);
                end
                
                obj.hBindingListeners = [obj.hBindingListeners{:}];
            end
        end
        
        function set.Value(obj,v)
            obj.Value = v;
            if v
                obj.hTxt.String(1) = 9745;
            else
                obj.hTxt.String(1) = 9744;
            end
        end
    end
end

function tf = mouseIsInAxes(hAx)
    coords =  hAx.CurrentPoint(1,1:2);
    xlim = hAx.XLim;
    ylim = hAx.YLim;
    tf = (coords(1) > xlim(1)) && (coords(1) < xlim(2)) && (coords(2) > ylim(1)) && (coords(2) < ylim(2));
end


%--------------------------------------------------------------------------%
% checkbox.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
