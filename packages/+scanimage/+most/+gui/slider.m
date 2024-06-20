classdef slider < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hPnl;
        hLis;
        
        hAx;
        hBar;
        hCar;
        
        hBindingListeners = {};
        
        barWidth = 0.4;
        value = 0.5;
        xld = 1;
        
        min = 0;
        max = 1;
        normValue;
        
        callback = [];
        bindings = {};
        
        Visible;
        liveUpdate = true;
    end
    
    methods
        function obj = slider(varargin)
            ip = most.util.InputParser;
            ip.addOptional('units','');
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('Bindings',{});
            ip.addOptional('min',0);
            ip.addOptional('max',1);
            ip.parse(varargin{:});
            othrs = most.util.structPV2cellPV(ip.Unmatched);
            
            if ~isempty(ip.Results.units)
                obj.hPnl = uipanel('units',ip.Results.units,othrs{:},'BorderType','None','SizeChangedFcn',@obj.resize);
            else
                obj.hPnl = uipanel(othrs{:},'BorderType','None','SizeChangedFcn',@obj.resize);
            end
    
            if ~isempty(ip.Results.WidthLimits)
                lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
                set(obj.hPnl, 'WidthLimits', lms(1:2));
            end
            if ~isempty(ip.Results.HeightLimits)
                lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
                set(obj.hPnl, 'HeightLimits', lms(1:2));
            end
            
            obj.hAx = axes('parent',obj.hPnl,'color','none','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',...
                [],'xcolor','none','ycolor','none','position',[0 0 1 1],'xlim',[0 1],'ylim',[0 1]);
            obj.hBar = patch('parent',obj.hAx,'xdata',[],'ydata',[],'zdata',[],'FaceColor','w','LineWidth',1.5);
            obj.hCar = patch('parent',obj.hAx,'xdata',[],'ydata',[],'zdata',[],'FaceColor',.5*ones(1,3),'LineWidth',1.5,'ButtonDownFcn',@obj.drag);
            
            obj.min = ip.Results.min;
            obj.max = ip.Results.max;
            
            obj.hLis = addlistener(obj.hPnl.Parent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.bindings = ip.Results.Bindings;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLis);
            most.idioms.safeDeleteObj(obj.hAx);
            most.idioms.safeDeleteObj(obj.hPnl);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
        end
    end
    
    methods (Hidden)
        function resize(obj,varargin)
            if most.idioms.isValidObj(obj.hCar)
                obj.hPnl.Units = 'pixels';
                p = obj.hPnl.Position;
                
                barW = p(4) * obj.barWidth;
                xmarg = p(4)*.6 / p(3);
                obj.hAx.XLim = [-xmarg 1+xmarg];
                obj.xld = 1+2*xmarg;
                
                xs = [-.5*barW*sind(0:10:180) (p(3) + .5*barW*sind(0:10:180))];
                ys = p(4)/2 + [.5*barW*cosd(0:10:180) -.5*barW*cosd(0:10:180)];
                
                obj.hBar.XData = xs/p(3);
                obj.hBar.YData = ys/p(4);
                
                obj.drawCar();
            end
        end
        
        function drawCar(obj)
            if most.idioms.isValidObj(obj.hCar)
                obj.hPnl.Units = 'pixels';
                p = obj.hPnl.Position;
                
                carR = (p(4) - 4)/2;
                
                xs = carR*cosd(0:10:360);
                ys = carR*sind(0:10:360);
                
                obj.hCar.XData = xs*obj.xld/p(3) + obj.normValue;
                obj.hCar.YData = ys/p(4) + .5;
            end
        end
        
        function drag(obj,~,evt)
            persistent hFig
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent v
            
            if strcmp(evt.EventName, 'Hit') && (evt.Button == 1)
                hFig = gcbf;
                prevWindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = hFig.WindowButtonUpFcn;
                set(hFig,'WindowButtonMotionFcn',@obj.drag,'WindowButtonUpFcn',@obj.drag);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                if obj.liveUpdate
                    obj.normValue = obj.hAx.CurrentPoint(1);
                    obj.ctlCallback();
                else
                    v = obj.hAx.CurrentPoint(1);
                end
            else
                if ~obj.liveUpdate
                    obj.normValue = v;
                    obj.ctlCallback();
                end
                set(hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
            end
        end
        
        function set(obj,prop,val)
            if ismember(lower(prop), {})
                set(obj.hAx,prop,val);
            else
                set(obj.hPnl,prop,val);
            end
        end
        
        function v = get(obj,prop)
            if ismember(lower(prop), {})
                v = obj.hAx.(prop);
            else
                v = obj.hPnl.(prop);
            end
        end
        
        function ctlCallback(obj)
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                binding{1}.(binding{2}) = obj.value * binding{3};
            end
            
            if ~isempty(obj.callback)
                obj.callback();
            end
        end
        
        function model2view(obj)
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                obj.value = binding{1}.(binding{2}) / binding{3};
            end
        end
    end
    
    methods
        function v = get.normValue(obj)
            v = (obj.value - obj.min) / (obj.max-obj.min);
        end
        
        function set.normValue(obj,v)
            obj.value = v * (obj.max-obj.min) + obj.min;
        end
        
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj,v)
            obj.hPnl.Visible = v;
        end
        
        function set.value(obj,v)
            obj.value = max(obj.min,min(obj.max,v));
            obj.drawCar();
        end
        
        function set.callback(obj,v)
            assert(isempty(v) || isa(v,'function_handle'),'Must be function handle.');
            obj.callback = v;
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
                    obj.hBindingListeners{end+1} = binding{1}.addlistener(binding{2},'PostSet',@(varargin)obj.model2view);
                end
                
                obj.hBindingListeners = [obj.hBindingListeners{:}];
                
                obj.model2view();
            end
        end
    end
end



%--------------------------------------------------------------------------%
% slider.m                                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
