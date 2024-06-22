classdef button < handle
    
    properties
        hFig;
        hPnl;
        hAx;
        
        hFrm;
        hTxt;
        
        hLis;
        
        BackgroundColor;
        BorderColor;
        FontColor;
        FontSize;
        FontWeight = 'normal';
        
        Visible;
        callback;
        Position;
        Units;
    end
    
    methods
        function obj = button(varargin)
            ip = most.util.InputParser;
            ip.addOptional('units','');
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('Callback',{});
            ip.addOptional('String','');
            ip.addOptional('BackgroundColor',[]);
            ip.addOptional('BorderColor','b');
            ip.addOptional('FontSize',8);
            ip.addOptional('FontWeight',[]);
            ip.addOptional('FontColor','k');
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
                obj.BackgroundColor = ip.Results.BackgroundColor;
            else
                obj.BackgroundColor = obj.hPnl.BackgroundColor;
            end
            obj.BorderColor = ip.Results.BorderColor;
    
            if ~isempty(ip.Results.WidthLimits)
                lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
                set(obj.hPnl, 'WidthLimits', lms(1:2));
            end
            if ~isempty(ip.Results.HeightLimits)
                lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
                set(obj.hPnl, 'HeightLimits', lms(1:2));
            end
            
            obj.hAx = axes('parent',obj.hPnl,'color','none','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',...
                [],'xcolor','none','ycolor','none','position',[0 0 1 1],'xlim',[0 1],'ylim',[0 1],'hittest','off');
            obj.hFrm = patch('parent',obj.hAx,'xdata',[0 1 1 0 0],'ydata',[0 0 1 1 0],'LineWidth',2,'edgecolor',ip.Results.BorderColor,'FaceColor','none','hittest','off');
            obj.hTxt = text(.5,.5,0,ip.Results.String,'parent',obj.hAx,'HorizontalAlignment','center','VerticalAlignment','middle',...
                'units','normalized','FontSize',ip.Results.FontSize,'Color',ip.Results.FontColor,'hittest','off');
            
            obj.FontColor = ip.Results.FontColor;
            obj.FontSize = ip.Results.FontSize;
            if ~isempty(ip.Results.FontWeight)
                obj.hTxt.FontWeight = ip.Results.FontWeight;
                obj.FontWeight = ip.Results.FontWeight;
            end
            
            obj.callback = ip.Results.Callback;
            
            obj.hLis = addlistener(obj.hPnl.Parent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hPnl.SizeChangedFcn = @obj.resize;
            obj.resize();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLis);
            most.idioms.safeDeleteObj(obj.hAx);
            most.idioms.safeDeleteObj(obj.hPnl);
        end
    end
    
    methods (Hidden)
        function resize(obj,varargin)
            obj.hPnl.Units = 'pixels';
            p = obj.hPnl.Position;
            
            %% border
            marg = 1;
            R = 10;
            cb = marg+R;
            crvS = R*sin(linspace(0,pi/2,20));
            crvC = R*cos(linspace(0,pi/2,20));
            
            xs = [cb-crvC       p(3)-cb+crvS  p(3)-cb+crvC  cb-crvS      marg];
            ys = [p(4)-cb+crvS  p(4)-cb+crvC  cb-crvS       marg+R-crvC  p(4)-cb];
            
            obj.hFrm.XData = xs/p(3);
            obj.hFrm.YData = ys/p(4);
            
            %% text
            txtmargV = .5 + 1/p(4);
            obj.hTxt.Position(2) = txtmargV;
        end
        
        function clickDD(obj,~,evt)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent tfInAxes
            
            if strcmp(evt.EventName, 'ButtonDown')
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                
                obj.hFrm.FaceColor = obj.BorderColor;
                obj.hTxt.Color = obj.BackgroundColor;
                tfInAxes = true;
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.clickDD,'WindowButtonUpFcn',@obj.clickDD);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                tfInAxes = mouseIsInAxes(obj.hAx);
                if tfInAxes
                    obj.hFrm.FaceColor = obj.BorderColor;
                    obj.hTxt.Color = obj.BackgroundColor;
                else
                    obj.hFrm.FaceColor = 'none';
                    obj.hTxt.Color = obj.BorderColor;
                end
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
                obj.hFrm.FaceColor = 'none';
                obj.hTxt.Color = obj.BorderColor;
                
                if tfInAxes && isa(obj.callback,'function_handle')
                    obj.callback();
                end
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
        
        function v = get.Position(obj)
            v = obj.hPnl.Position;
        end
        
        function set.Position(obj,v)
            obj.hPnl.Position = v;
        end
        
        function v = get.Units(obj)
            v = obj.hPnl.Units;
        end
        
        function set.Units(obj,v)
            obj.hPnl.Units = v;
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
% button.m                                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
