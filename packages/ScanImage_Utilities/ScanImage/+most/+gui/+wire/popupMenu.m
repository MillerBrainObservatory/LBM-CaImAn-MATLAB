classdef popupMenu < handle
    
    properties
        hFig;
        hPnl;
        hAx;
        
        hPopPnl;
        hPopAx;
        hPopFrm;
        hPopBacks = matlab.graphics.primitive.Patch.empty;
        hPopTexts = matlab.graphics.primitive.Text.empty;
        
        hFrm;
        hTxt;
        hArr;
        
        hLis;
        hBindingListeners;
        
        bindings;
        
        BackgroundColor;
        BorderColor;
        FontColor;
        FontSize;
        FontWeight = 'normal';
        
        value;
        choices;
        selection;
        Visible;
        
        prevWindowButtonDownFcn;
        tfMap = containers.Map({true false}, {'on' 'off'});
    end
    
    methods
        function obj = popupMenu(varargin)
            ip = most.util.InputParser;
            ip.addOptional('units','');
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('Bindings',{});
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
            obj.hArr = patch('parent',obj.hAx,'xdata',[0 1 1 0 0],'ydata',[0 0 1 1 0],'edgecolor',ip.Results.BorderColor,'FaceColor',ip.Results.BorderColor,'hittest','off');
            obj.hTxt = text(.1,.5,0,'','parent',obj.hAx,'HorizontalAlignment','left','VerticalAlignment','middle',...
                'units','normalized','FontSize',ip.Results.FontSize,'Color',ip.Results.FontColor,'hittest','off');
            
            obj.FontColor = ip.Results.FontColor;
            obj.FontSize = ip.Results.FontSize;
            if ~isempty(ip.Results.FontWeight)
                obj.hTxt.FontWeight = ip.Results.FontWeight;
                obj.FontWeight = ip.Results.FontWeight;
            end
            
            obj.hLis = addlistener(obj.hPnl.Parent,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.bindings = ip.Results.Bindings;
            obj.hPnl.SizeChangedFcn = @obj.resize;
            obj.resize();
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
            
            %% arrow
            marg = 8;
            w = 16;
            cb = marg+w;
            xs = [p(3)-cb p(3)-marg];
            xs = [xs mean(xs) xs(1)];
            ys = [.65 .65 .35 .65];
            obj.hArr.XData = xs/p(3);
            obj.hArr.YData = ys;
            
            %% text
            txtmarg = 8;
            txtmargV = .5 + 1/p(4);
            obj.hTxt.Position = [txtmarg/p(3) txtmargV 0];
        end
        
        function clickDD(obj,~,evt)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent tfInAxes
            
            if strcmp(evt.EventName, 'ButtonDown')
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                
                obj.hFrm.FaceColor = obj.BorderColor;
                obj.hArr.FaceColor = obj.BackgroundColor;
                obj.hTxt.Color = obj.BackgroundColor;
                tfInAxes = true;
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.clickDD,'WindowButtonUpFcn',@obj.clickDD);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                tfInAxes = mouseIsInAxes(obj.hAx);
                if tfInAxes
                    obj.hFrm.FaceColor = obj.BorderColor;
                    obj.hArr.FaceColor = obj.BackgroundColor;
                    obj.hTxt.Color = obj.BackgroundColor;
                else
                    obj.hFrm.FaceColor = 'none';
                    obj.hArr.FaceColor = obj.BorderColor;
                    obj.hTxt.Color = obj.BorderColor;
                end
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
                obj.hFrm.FaceColor = 'none';
                obj.hArr.FaceColor = obj.BorderColor;
                obj.hTxt.Color = obj.BorderColor;
                
                if tfInAxes && (numel(obj.choices) > 1)
                    obj.openPopup();
                end
            end
        end
        
        function openPopup(obj)
            N = numel(obj.choices);
            if N
                p = getpixelposition(obj.hAx,true);
                
                bmarg = 2;
                
                elsz = p(4)-bmarg*2;
                s = elsz*N+bmarg*2;
                p(4) = s;
                
                obj.hPopPnl = uipanel('parent',obj.hFig,'units','pixels','position',p,'BorderType','None','BackgroundColor',obj.BackgroundColor);
                obj.hPopAx = axes('parent',obj.hPopPnl,'color','none','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',...
                    [],'xcolor','none','ycolor','none','units','normalized','position',[0 0 1 1],'xlim',[0 1],'ylim',[0 1],'hittest','off');
                
                %% border
                marg = 1;
                R = 10;
                cb = marg+R;
                crvS = R*sin(linspace(0,pi/2,20));
                crvC = R*cos(linspace(0,pi/2,20));
                
                xs = [cb-crvC       p(3)-cb+crvS  p(3)-cb+crvC  cb-crvS      marg];
                ys = [p(4)-cb+crvS  p(4)-cb+crvC  cb-crvS       marg+R-crvC  p(4)-cb];
                obj.hPopFrm = patch('parent',obj.hPopAx,'xdata',xs/p(3),'ydata',ys/p(4),'LineWidth',2,'edgecolor',obj.BorderColor,'FaceColor','none','hittest','off');
                
                %% names
                offs = elsz * (N-1);
                txtmarg = 8;
                for i = 1:N
                    %% back
                    if i == 1
                        xs = [cb-crvC       p(3)-cb+crvS];
                        ys = [p(4)-cb+crvS  p(4)-cb+crvC];
                    else
                        xs = [marg       p(3)-marg];
                        ys = [p(4)-marg  p(4)-marg];
                    end
                    
                    if i == N
                        xs = [xs  p(3)-cb+crvC  cb-crvS];
                        ys = [ys  offs+cb-crvS  offs+marg+R-crvC];
                    else
                        xs = [xs  p(3)-marg  marg];
                        ys = [ys  offs+marg  offs+marg];
                    end
                    xs = [xs xs(1)];
                    ys = [ys ys(1)] - (i-1)*elsz;
                    ys = ys/p(4);
                    rg = [max(ys) min(ys)];
                    if i == obj.value
                        c = obj.BorderColor;
                    else
                        c = 'none';
                    end
                    obj.hPopBacks(i) = patch('parent',obj.hPopAx,'xdata',xs/p(3),'ydata',ys,'edgecolor','none','FaceColor',c,'hittest','off','UserData',rg);
                    
                    %% text
                    txtmargV = 1 / p(4);
                    if i == obj.value
                        c = obj.BackgroundColor;
                    else
                        c = obj.FontColor;
                    end
                    obj.hPopTexts(i) = text(txtmarg/p(3),mean(rg)+txtmargV,0,obj.choices{i},'parent',obj.hPopAx,'HorizontalAlignment','left','VerticalAlignment','middle',...
                        'units','normalized','FontSize',obj.FontSize,'FontWeight',obj.FontWeight,'Color',c,'hittest','off');
                end
                
                obj.prevWindowButtonDownFcn = obj.hFig.WindowButtonDownFcn;
                obj.hFig.WindowButtonDownFcn = @obj.popupClick;
            end
        end
        
        function popupClick(obj,~,evt)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent tfStartInAxes
            persistent tfInAxes
            persistent sel
            persistent scl
            persistent N
            
            if strcmp(evt.EventName, 'WindowMousePress')
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                
                tfStartInAxes = mouseIsInAxes(obj.hPopAx);
                
                if tfStartInAxes
                    scl = obj.hPopPnl.Position(4);
                    N = numel(obj.choices);
                    updateColors();
                else
                    tfInAxes = false;
                    closePopup();
                end
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.popupClick,'WindowButtonUpFcn',@obj.popupClick);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                if tfStartInAxes
                    updateColors();
                end
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
                obj.hFig.WindowButtonDownFcn = obj.prevWindowButtonDownFcn;
                
                closePopup();
                
                if tfInAxes
                    obj.value = sel;
                    obj.view2model();
                end
            end
            
            function updateColors()
                set(obj.hPopTexts, 'Color', obj.FontColor);
                set(obj.hPopBacks, 'FaceColor', 'none');
                
                tfInAxes = mouseIsInAxes(obj.hPopAx);
                
                if tfInAxes
                    marg = 2;
                    cp = obj.hPopAx.CurrentPoint(1,2)*scl;
                    sel = min(max( N -  floor(N*(cp - marg)/(scl-marg*2)),1),N);
                    obj.hPopBacks(sel).FaceColor = obj.BorderColor;
                    obj.hPopTexts(sel).Color = obj.BackgroundColor;
                end
            end
            
            function closePopup()
                most.idioms.safeDeleteObj(obj.hPopAx);
                most.idioms.safeDeleteObj(obj.hPopPnl);
                most.idioms.safeDeleteObj(obj.hPopBacks);
                most.idioms.safeDeleteObj(obj.hPopTexts);
            end
        end
        
        function model2view(obj)
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                obj.value = binding{1}.(binding{2});
            end
        end
        
        function view2model(obj)
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                binding{1}.(binding{2}) = obj.value;
            end
        end
    end
    
    methods
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj,v)
            if isa(v,'logical')
                v = obj.tfMap(v);
            end
            obj.hPnl.Visible = v;
        end
        
        function set.value(obj,v)
            obj.value = v;
            if numel(obj.choices)
                obj.hTxt.String = obj.choices{v};
            else
                obj.hTxt.String = '';
            end
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

function tf = mouseIsInAxes(hAx)
    coords =  hAx.CurrentPoint(1,1:2);
    xlim = hAx.XLim;
    ylim = hAx.YLim;
    tf = (coords(1) > xlim(1)) && (coords(1) < xlim(2)) && (coords(2) > ylim(1)) && (coords(2) < ylim(2));
end


%--------------------------------------------------------------------------%
% popupMenu.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
