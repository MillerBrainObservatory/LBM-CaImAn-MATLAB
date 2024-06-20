classdef TimePlot < handle
    properties
        visible = false;
        historyLength = 30;
        xLabel = 'Time';
        yLabel = 'Y';
        XLim = [NaN NaN];
        YLim = [NaN NaN];
        
        yLimAnimationEnabled = true;
        maxDisplayRate = 20; % in Hz
        changedCallback = function_handle.empty(0,1);
        lineSpecs = {};
        legend = {};
        colorOrder = get(0,'DefaultAxesColorOrder');
    end
    
    properties (Hidden, SetAccess = private)
        vHistory
        tHistory
        
        hTimer
        
        hFig
        hAx
        axXLim
        axYLim
        hLines = matlab.graphics.primitive.Line.empty(1,0);
        hLinesXData = {};
        
        plotNeedsUpdate = true;
        lastDisplayUpdate = zeros(1,1,'like',tic());
    end
    
    events
        changed;
    end
    
    %% Lifecycle
    methods
        function obj = TimePlot(name, visible)
            if nargin < 1 || isempty(name)
                name = 'Time Plot';
            end
            
            if nargin < 2 || isempty(visible)
                visible = true;
            end
            
            obj.hFig = figure('NumberTitle','off','Name','Time Plot','MenuBar','none','Visible','off');
            obj.hAx = axes('Parent',obj.hFig);
            obj.hFig.CloseRequestFcn = @(varargin)obj.toggleVisible;
            
            grid(obj.hAx,'on');
            box(obj.hAx,'on');
            title(obj.hAx,name);
            xlabel(obj.hAx,obj.xLabel);
            ylabel(obj.hAx,obj.yLabel);
            
            obj.hTimer = timer('Name','Time Plot Plot Timer');
            obj.hTimer.ExecutionMode = 'fixedSpacing';
            obj.hTimer.TimerFcn = @(varargin)obj.plotLimitedRate;
            obj.hTimer.Period = 1;
            
            obj.visible = visible;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTimer);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% Public methods
    methods
        function addTimePoint(obj,val,t)
            if nargin < 3 || isempty(t)
                t = NaN;
            end
            
            obj.tHistory = append(obj.tHistory,t,obj.historyLength);
            obj.vHistory = append(obj.vHistory,val,obj.historyLength);
            
            obj.plotNeedsUpdate = true;
            obj.plotLimitedRate();
        end

        
        function reset(obj)
            most.idioms.safeDeleteObj(obj.hLines);
            obj.hLines = matlab.graphics.primitive.Line.empty(1,0);
            obj.hLinesXData = {};
            obj.tHistory = [];
            obj.vHistory = [];
            cla(obj.hAx);
        end
    end
    
    %% Private methods
    methods (Access = private)
        function plotLimitedRate(obj)
            if obj.plotNeedsUpdate && toc(obj.lastDisplayUpdate) > 1/obj.maxDisplayRate
                obj.plot();
            end
        end
        
        function plot(obj)
            if ~obj.visible || isempty(obj.tHistory)
                return
            end
            
            multiPoint = size(obj.vHistory,1) > 1;
            
            if multiPoint
                xData = 1:size(obj.vHistory,1);
            else
                if any(isnan(obj.tHistory))
                    xData = (-numel(obj.tHistory)+1:0)';
                else
                    xData = reshape(obj.tHistory,[],1,1);
                    xData = xData - xData(end); 
                end
            end
            
            numChs = size(obj.vHistory,2);
            if numel(obj.hLines) < numChs
                for idx = numel(obj.hLines)+1 : numChs
                    colorIdx = mod(idx-1,size(obj.colorOrder,1)) + 1;
                    obj.hLines(idx) = line('Parent',obj.hAx,'Xdata',xData,'YData',nan(1,numel(xData)),'Color',obj.colorOrder(colorIdx,:),'LineWidth',1);
                    if numel(obj.lineSpecs) >= idx && ~isempty(obj.lineSpecs{idx})
                        set(obj.hLines(idx),obj.lineSpecs{idx}{:});
                    end
                    obj.hLinesXData{idx} = [];
                end
                
                if ~isempty(obj.legend)
                    w = warning();
                    warning('off','MATLAB:legend:IgnoringExtraEntries');
                    legend(obj.hAx,obj.legend{:}); %#ok<CPROP>
                    warning(w);
                end
            end
            
            % determine xLim
            xLim = [min(xData) max(xData)];
            if diff(xLim) <= 0
                xLim = xLim + [-1 0];
            end
            
            xLim(~isnan(obj.XLim)) = obj.XLim(~isnan(obj.XLim));
            xLim = sort(xLim);
            xLim = xLim + [-1 0]*(xLim(1)==xLim(2));
            
            % determine yLim
            yLim =  [min(obj.vHistory(:)) max(obj.vHistory(:))];
            d = diff(yLim);
            if isnan(d)
                yLim = [-1 1];
            elseif d <= 0
                yLim = yLim + [-1 11];
            else
                yLim = yLim + [-d d]*0.01;
                N = fix(log10(diff(yLim)));
                yLim = [floor(yLim(1),-N) ceil(yLim(2),-N)];
            end
            yLim(~isnan(obj.YLim)) = obj.YLim(~isnan(obj.YLim));
            yLim = sort(yLim);
            yLim = yLim + [-1 1]*(yLim(1)==yLim(2));
            
            % set new axes limits only if neccessary for performance
            if ~isequal(xLim,obj.axXLim)
                obj.hAx.XLim = xLim;
                obj.axXLim = xLim;
            end
            
            if ~isequal(yLim,obj.axYLim)
                if obj.yLimAnimationEnabled
                    most.gui.Transition(1,obj.hAx,'YLim',double(yLim),'expOut');
                end
                %obj.hAx.YLim = yLim;
                obj.axYLim = yLim;
            end
            
            for idx = 1:numChs
                if size(obj.vHistory,1) > 1 
                    YData = mean(obj.vHistory(:,idx,:),3);
                else
                    YData = reshape(obj.vHistory(:,idx,:),[],1,1);
                end
                
                if ~isequal(xData,obj.hLinesXData{idx})
                    obj.hLines(idx).XData = xData;
                    obj.hLinesXData{idx} = xData;
                end
                obj.hLines(idx).YData = YData;
            end
            
            obj.plotNeedsUpdate = false;
            obj.lastDisplayUpdate = tic();
        end
        
        function toggleVisible(obj)
            obj.visible = ~obj.visible;
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.visible(obj,val)
            validateattributes(val,{'logical','numeric'},{'binary','scalar'});
            
            oldVal = obj.visible;
            obj.visible = val;
            
            if val ~= oldVal
                obj.plot();
                obj.hFig.Visible = most.idioms.ifthenelse(val,'on','off');
                
                if val
                    start(obj.hTimer);
                else
                    stop(obj.hTimer);
                end
                
                obj.notify('changed');
                if ~isempty(obj.changedCallback)
                    obj.changedCallback(obj);
                end
            end
        end
        
        function set.historyLength(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','integer'});
            
            oldVal = obj.historyLength;
            obj.historyLength = val;
            
            % trim arrays
            if oldVal ~= val
                obj.tHistory = trimVec(obj.tHistory,obj.historyLength);
                obj.vHistory = trimVec(obj.vHistory,obj.historyLength);
                obj.plot();
            end            
        end
        
        function set.xLabel(obj,val)
            validateattributes(val,{'char'},{'row'});
            obj.xLabel = val;
            if most.idioms.isValidObj(obj.hAx)
                xlabel(obj.hAx,val);
            end
        end
        
        function set.yLabel(obj,val)
            validateattributes(val,{'char'},{'row'});
            obj.yLabel = val;
            if most.idioms.isValidObj(obj.hAx)
                ylabel(obj.hAx,val);
            end
        end
        
        function set.changedCallback(obj,val)
            if isempty(val)
                val = function_handle.empty(0,1);
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            obj.changedCallback = val; 
        end
        
        function set.XLim(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'real'});
            if ~any(isnan(val))
                assert(issorted(val),'Axes limits must be sorted');
            end
            obj.XLim = val;
        end
        
        function set.YLim(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'real'});
            if ~any(isnan(val))
                assert(issorted(val),'Axes limits must be sorted');
            end
            obj.YLim = val;
        end
        
        function set.colorOrder(obj,val)
            validateattributes(val,{'numeric'},{'ncols',3,'>=',0,'<=',1,'real','nonempty','nonsparse'});
            obj.colorOrder = val;
        end
        
        function set.lineSpecs(obj,val)
            validateattributes(val,{'cell'},{});
            obj.lineSpecs = val;
        end
        
        function set.legend(obj,val)
            validateattributes(val,{'cell'},{});
            obj.legend = val;
        end
        
        function set.yLimAnimationEnabled(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'});
            obj.yLimAnimationEnabled = logical(val);
        end
    end
end

function vec = append(vec,v,veclength)    
    if isempty(vec)
        vec = v;
    else
        vChs = size(v,2);
        vecChs = size(vec,2);
        vPts = size(v,1);
        vecPts = size(vec,1);
        
        if vChs <= vecChs
            v(:,end+1:vecChs,:) = NaN;
        else
            vec(:,end+1:vChs,:) = NaN;
        end
        
        if vPts <= vecPts
            v(end+1:vecPts,:,:) = NaN;
        else
            vec(end+1:vPts,:,:) = NaN;
        end        
        
        if size(vec,3) < veclength
            vec(:,:,end+1) = v;
        else
            vec = vec(:,:,end-veclength+1:end);
            vec = circshift(vec,-1,3);
            vec(:,:,end) = v;
        end
    end
end

function vec = trimVec(vec,vlength)
    if size(vec,3) > vlength
        vec(:,:,1:size(vec,3)-vlength) = [];
    end
end

function X = ceil(X,N,base)
    if nargin < 2 || isempty(N)
        N = 0;
    end
    
    if nargin < 3 || isempty(base)
        base = 10;
    end
    
    X = X * base^N;
    X = builtin('ceil',X);
    X = X / base^N;
end

function X = floor(X,N,base)
    if nargin < 2 || isempty(N)
        N = 0;
    end
    
    if nargin < 3 || isempty(base)
        base = 10;
    end

    X = X * base^N;
    X = builtin('floor',X);
    X = X / base^N;
end

function X = ceilfix(X)
X = ceil(abs(X)) * sign(X);
end

%--------------------------------------------------------------------------%
% TimePlot.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
