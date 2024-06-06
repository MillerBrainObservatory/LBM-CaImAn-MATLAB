classdef constrastSlider < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hPnl;
        hLis;
        
        hAx;
        hBar;
        hCar;
        hCarL;
        hCarH;
        
        hBindingListeners = {};
        
        barWidth = 0.4;
        value = [.4 .7];
        min = 0;
        max = 1;
        
        callback = [];
        bindings = {};
        
        integerVals = false;
        
        Visible;
    end
    
    methods
        function obj = constrastSlider(varargin)
            ip = most.util.InputParser;
            ip.addOptional('units','');
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('min',0);
            ip.addOptional('max',1);
            ip.addOptional('Bindings',{});
            ip.addOptional('BackgroundColor',[]);
            ip.addOptional('DarkColor',[]);
            ip.addOptional('BrightColor',[]);
            ip.addOptional('BorderColor','b');
            ip.addOptional('BarColor','w');
            ip.parse(varargin{:});
            othrs = most.util.structPV2cellPV(ip.Unmatched);
            
            if ~isempty(ip.Results.units)
                obj.hPnl = uipanel('units',ip.Results.units,othrs{:},'BorderType','None','SizeChangedFcn',@obj.resize);
            else
                obj.hPnl = uipanel(othrs{:},'BorderType','None','SizeChangedFcn',@obj.resize);
            end
            
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
            
            obj.min = ip.Results.min;
            obj.max = ip.Results.max;
            
            obj.hAx = axes('parent',obj.hPnl,'color','none','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',...
                [],'xcolor','none','ycolor','none','position',[0 0 1 1],'xlim',[0 1],'ylim',[0 1]);
            obj.hBar = patch('parent',obj.hAx,'xdata',[],'ydata',[],'zdata',[],'FaceColor',ip.Results.BarColor,'LineWidth',1.5,'edgecolor',ip.Results.BorderColor);
            obj.hCar = surface('parent',obj.hAx,'xdata',[],'ydata',[],'zdata',[],'FaceColor',.5*ones(1,3),'LineWidth',0.5,'ButtonDownFcn',@obj.drag,'edgecolor',ip.Results.BorderColor);
            obj.hCarL = patch('parent',obj.hAx,'xdata',[],'ydata',[],'zdata',[],'FaceColor',zeros(1,3),'LineWidth',1.5,'ButtonDownFcn',@obj.drag,'edgecolor',ip.Results.BorderColor);
            obj.hCarH = patch('parent',obj.hAx,'xdata',[],'ydata',[],'zdata',[],'FaceColor',ones(1,3),'LineWidth',1.5,'ButtonDownFcn',@obj.drag,'edgecolor',ip.Results.BorderColor);
            
            if ~isempty(ip.Results.DarkColor) && ~isempty(ip.Results.BrightColor)
                dc = ip.Results.DarkColor;
                bc = ip.Results.BrightColor;
                colormap(obj.hAx,[linspace(dc(1),bc(1),101)' linspace(dc(2),bc(2),101)' linspace(dc(3),bc(3),101)']);
                obj.hCar.FaceColor = 'texturemap';
                obj.hCar.CData = 0:.01:1;
            end
            
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
                
                barT = p(4) * obj.barWidth;
                xmarg = p(4)*.6 / p(3);
                obj.hAx.XLim = [-xmarg 1+xmarg];
                
                xs = [-.5*barT*sind(0:10:180) (p(3) + .5*barT*sind(0:10:180))];
                ys = p(4)/2 + [.5*barT*cosd(0:10:180) -.5*barT*cosd(0:10:180)];
                
                obj.hBar.XData = xs/p(3);
                obj.hBar.YData = ys/p(4);
                obj.hBar.ZData = [];
                
                obj.drawCars();
            end
        end
        
        function drawCars(obj)
            if most.idioms.isValidObj(obj.hCar)
                obj.hPnl.Units = 'pixels';
                p = obj.hPnl.Position;
                
                carR = (p(4) - 4)/2;
                barHT = p(4) * obj.barWidth *.5;
                v = (obj.value - obj.min) / (obj.max - obj.min);
                
                % carL
                xs = [-carR*sind(0:10:180) 0];
                ys = [carR*cosd(0:10:180) carR];
                obj.hCarL.XData = xs/p(3) + v(1);
                obj.hCarL.YData = ys/p(4) + .5;
                
                % carH
                xs = [carR*sind(0:10:180) 0];
                ys = [carR*cosd(0:10:180) carR];
                obj.hCarH.XData = xs/p(3) + v(2);
                obj.hCarH.YData = ys/p(4) + .5;
                
                % car
                xs = [v(1) v(2); v(1) v(2)];
                ys = [barHT barHT; -barHT -barHT];
                obj.hCar.XData = xs;
                obj.hCar.YData = ys/p(4) + .5;
                obj.hCar.ZData = zeros(size(xs));
            end
        end
        
        function drag(obj,src,evt)
            persistent hFig
            persistent ppt
            persistent ind
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            
            if strcmp(evt.EventName, 'Hit') && (evt.Button == 1)
                hFig = gcbf;
                prevWindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = hFig.WindowButtonUpFcn;
                
                if src == obj.hCar
                    ppt = obj.hAx.CurrentPoint(1);
                else
                    ppt = [];
                    ind = src == [obj.hCarL obj.hCarH];
                end
                
                set(hFig,'WindowButtonMotionFcn',@obj.drag,'WindowButtonUpFcn',@obj.drag);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                npt = obj.hAx.CurrentPoint(1);
                if isempty(ppt)
                    obj.value(ind) = npt*(obj.max - obj.min) + obj.min;
                else
                    obj.value = obj.value + (npt - ppt)*(obj.max - obj.min);
                    ppt = npt;
                end
                obj.ctlCallback();
            else
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
            if obj.integerVals
                v = round(obj.value);
            else
                v = obj.value;
            end
            
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                binding{1}.(binding{2}) = v;
            end
            
            if ~isempty(obj.callback)
                obj.callback();
            end
        end
        
        function model2view(obj)
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                obj.value = binding{1}.(binding{2});
            end
        end
    end
    
    methods
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj,v)
            obj.hPnl.Visible = v;
        end
        
        function set.value(obj,v)
            v = double(max(obj.min,min(obj.max,v)));
            obj.value = [v(1) max(v(1),v(2))];
            obj.drawCars();
        end
        
        function set.callback(obj,v)
            assert(isa(v,'function_handle'),'Must be function handle.');
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
% constrastSlider.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
