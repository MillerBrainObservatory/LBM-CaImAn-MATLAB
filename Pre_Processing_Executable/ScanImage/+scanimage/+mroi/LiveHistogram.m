classdef LiveHistogram < handle
    properties
        dataRange = [intmin('int16'),intmax('int16')];
        viewRange = [0 1];
        lut = [NaN NaN];
        title = '';
        channel = [];
    end
    
    properties (Hidden, SetAccess = private)
        hFig;
        hHist;
        hAx;
        hSI;
        hLutPatch;
        hSaturationPatch;
        numDataPoints = 0;
    end
    
    methods
        function obj = LiveHistogram(hSI)
            if nargin > 0
                obj.hSI = hSI;
            end

            obj.hFig = figure('NumberTitle','off','Name','Pixel Histogram','MenuBar','none',...
                'WindowScrollWheelFcn',@obj.scrollWheelFcn,'CloseRequestFcn',@obj.closeRequestFcn);
            obj.hAx = axes('Parent',obj.hFig);
            obj.hHist = histogram(obj.hAx,0,'Normalization','countdensity','EdgeColor','none','ButtonDownFcn',@obj.buttonDownFcn);
            
            obj.hAx.ButtonDownFcn = @obj.buttonDownFcn;
            set(get(obj.hAx,'XLabel'),'String','Pixel Value','FontWeight','bold','FontSize',12);
            set(get(obj.hAx,'YLabel'),'String','Number of Pixels','FontWeight','bold','FontSize',12);
            obj.hAx.YScale = 'log';
            obj.hAx.XGrid = 'on';
            obj.hAx.YGrid = 'on';
            obj.hAx.LooseInset = [0 0 0 0] + 0.01;
            
            obj.hLutPatch = patch('Parent',obj.hAx,...
                'XData',[0,0,1,1]','YData',[1,inf,inf,1]','ZData',[1,1,1,1]',...
                'FaceAlpha',0.1,'FaceColor',[0,0,0],'EdgeColor','none',...
                'HitTest','off','PickableParts','none');
            obj.hSaturationPatch = patch('Parent',obj.hAx,...
                'XData',[0,0,1,1]','YData',[1,inf,inf,1]','ZData',[1,1,1,1]',...
                'FaceAlpha',0.1,'FaceColor',[1,0,0],'EdgeColor','none',...
                'HitTest','off','PickableParts','none','Visible','off');
            
            obj.updateData(0);
            obj.viewRange = obj.dataRange;   
            obj.lut = obj.lut;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function updateData(obj,val)
            val = val(:);
            numDataPoints_ = numel(val);
            if obj.numDataPoints ~= numDataPoints_
                obj.numDataPoints = numDataPoints_;
            end
            
            obj.hHist.Data = val;
        end
    end
    
    %% Property getter/setter
    methods
        function set.dataRange(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'increasing'});
            val = round(double(val));
            obj.dataRange = val;
            
            obj.viewRange = obj.viewRange;
            
            s = obj.dataRange(1);
            e = obj.dataRange(2);
            w = (e-s) * 0.05; % saturation region
            z = 0.5;
            dP = obj.numDataPoints;
            obj.hSaturationPatch.Vertices = [s,0.8,z;...
                                             s,dP,z;...
                                             s+w,dP,z;...
                                             s+w,0.8,z;...
                                             ...
                                             e-w,0.8,z;...
                                             e-w,dP,z;...
                                             e,dP,z;...
                                             e,0.8,z];
            obj.hSaturationPatch.FaceVertexAlphaData = [1;1;0;0;0;0;1;1].*0.3;
            obj.hSaturationPatch.FaceAlpha = 'interp';
            obj.hSaturationPatch.AlphaDataMapping = 'none';
            obj.hSaturationPatch.Faces = [1:4;5:8];
            obj.hSaturationPatch.Visible = 'on';
        end
        
        
        function set.viewRange(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2,'increasing'});
            val = round(double(val));
            val(1) = max(val(1),double(obj.dataRange(1)));
            val(2) = min(val(2),double(obj.dataRange(2)));
            obj.viewRange = val;
            
            units_ = obj.hAx.Units;
            obj.hAx.Units = 'pixel';
            pixelWidth = obj.hAx.Position(4);
            obj.hAx.Units = units_;

            binEdges = linspace(val(1)-0.5,val(2)+0.5,diff(val)+2);
            obj.hAx.XLim = binEdges([1 end]);
            
            p = ceil(length(binEdges)./pixelWidth); % reduce number of bins for display
            binEdges = binEdges(1:p:end); % the last bin might be cut off
            binEdges(end+1) = binEdges(end) + diff(binEdges(end-1:end)); % add the last bin back in
            obj.hHist.BinEdges = binEdges;
        end
        
        function set.numDataPoints(obj,val)
            val = max(val,2);
            obj.numDataPoints = val;
            obj.hAx.YLim = [0.8,val];
            obj.hLutPatch.YData = [0.8 val val 0.8]';
            
            obj.dataRange = obj.dataRange;
        end
        
        function set.lut(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2});
            val = sort(round(double(val)));
            
            val(1) = max([val(1),double(obj.dataRange(1))],[],'includenan');
            val(2) = min([val(2),double(obj.dataRange(2))],[],'includenan');
           
            obj.lut = val;
            
            if ~any(isnan(val));
                obj.hLutPatch.Visible = 'on';
                obj.hLutPatch.XData = [val(1),val(1),val(2),val(2)]';
            else
                obj.hLutPatch.Visible = 'off';
            end
        end
        
        function set.title(obj,val)
            obj.title = val;
            title(obj.hAx,val); %#ok<CPROPLC>
        end
    end
    
    methods (Hidden)
        function scrollWheelFcn(obj,src,evt)
            mPt = obj.hAx.CurrentPoint(1,1);
            oldViewRange = obj.viewRange;
            
            zoomSpeedFactor = 1.2;
            scroll = zoomSpeedFactor ^ double(evt.VerticalScrollCount);
            obj.viewRange = (oldViewRange - mPt) * scroll + mPt;
        end
        
        function buttonDownFcn(obj,src,evt)
            axPt = obj.hAx.CurrentPoint(1,1);
            
            if abs(axPt-obj.lut(1)) < diff(obj.viewRange) * 0.02
                panLutMode = 'changeMin';
            elseif abs(axPt-obj.lut(2)) < diff(obj.viewRange) * 0.02
                panLutMode = 'changeMax';
            elseif axPt >= obj.lut(1) && axPt <= obj.lut(2)
                panLutMode = 'pan';
            else
                panLutMode = [];
            end
            
            if evt.Button == 1;
                if src == obj.hHist;
                    if any(strcmpi(panLutMode,{'changeMin','changeMax'}));
                        obj.lutPan('start',panLutMode);
                    else
                        obj.pan('start');
                    end
                elseif ~isempty(panLutMode)
                    obj.lutPan('start',panLutMode);
                else
                    obj.pan('start');
                end
            end
        end
        
        function pan(obj,mode)
            if nargin<2 || isempty(mode)
                mode = 'start';
            end
            
            persistent dragData
            persistent originalConfig
            
            try
                switch lower(mode)
                    case 'start'
                        dragData = struct();
                        dragData.startPoint = obj.hAx.CurrentPoint(1,1);
                        dragData.startViewRange = obj.viewRange;
                        
                        originalConfig = struct();
                        originalConfig.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        originalConfig.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        
                        obj.hFig.WindowButtonMotionFcn = @(varargin)obj.pan('move');
                        obj.hFig.WindowButtonUpFcn = @(varargin)obj.pan('stop');
                    case 'move'
                        currentPoint = obj.hAx.CurrentPoint(1,1);
                        currentViewRange = obj.viewRange;
                        
                        d = currentPoint(1) - currentViewRange(1) + dragData.startViewRange(1);
                        d = d - dragData.startPoint;
                        
                        newViewRange = dragData.startViewRange-d;
                        
                        if newViewRange(1) >= obj.dataRange(1) && newViewRange(2) <= obj.dataRange(2)
                            obj.viewRange = newViewRange;
                        end                        
                    case 'stop'
                        abort();
                    otherwise
                        assert(false);
                end
            catch ME
                abort();
                rethrow(ME);
            end
            
            %%% local function
            function abort()
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonMotionFcn');
                    obj.hFig.WindowButtonMotionFcn = originalConfig.WindowButtonMotionFcn;
                else
                    obj.hFig.WindowButtonMotionFcn = [];
                end
                
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonUpFcn');
                    obj.hFig.WindowButtonUpFcn = originalConfig.WindowButtonUpFcn;
                else
                    obj.hFig.WindowButtonUpFcn = [];
                end
                
                startPoint = [];
                originalConfig = struct();
            end
        end
        
        function lutPan(obj,mode,panMode)
            if nargin<2 || isempty(mode)
                mode = 'start';
            end
            
            if nargin<3 || isempty(panMode)
                panMode = 'pan';
            end
            
            persistent dragData
            persistent originalConfig
            
            try
                switch lower(mode)
                    case 'start'
                        dragData = struct();
                        dragData.startPoint = obj.hAx.CurrentPoint(1,1);
                        dragData.startLut = obj.lut;
                        
                        originalConfig = struct();
                        originalConfig.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        originalConfig.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        
                        obj.hFig.WindowButtonMotionFcn = @(varargin)obj.lutPan('move',panMode);
                        obj.hFig.WindowButtonUpFcn = @(varargin)obj.lutPan('stop');
                    case 'move'
                        currentPoint = obj.hAx.CurrentPoint(1,1);
                        
                        d = currentPoint(1) - dragData.startPoint;
                        
                        switch panMode
                            case 'changeMax'
                                newLut = dragData.startLut+[0 d];
                            case 'changeMin'
                                newLut = dragData.startLut+[d 0];
                            case 'pan'
                                newLut = dragData.startLut+d;
                                % constraint newLut
                                if newLut(1) < obj.dataRange(1)
                                    newLut = [obj.dataRange(1), obj.dataRange(1)+diff(newLut)];
                                elseif newLut(2) > obj.dataRange(2)
                                    newLut = [obj.dataRange(2)-diff(newLut), obj.dataRange(2)];
                                end
                            otherwise
                                assert(false);
                        end
                        
                        obj.lut = newLut;
                        
                        if ~isempty(obj.hSI) && isvalid(obj.hSI) && ~isempty(obj.channel)
                            obj.hSI.hChannels.channelLUT{obj.channel} = obj.lut;
                        end
                    case 'stop'
                        abort();
                    otherwise
                        assert(false);
                end
            catch ME
                abort();
                rethrow(ME);
            end
            
            %%% local function
            function abort()
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonMotionFcn');
                    obj.hFig.WindowButtonMotionFcn = originalConfig.WindowButtonMotionFcn;
                else
                    obj.hFig.WindowButtonMotionFcn = [];
                end
                
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonUpFcn');
                    obj.hFig.WindowButtonUpFcn = originalConfig.WindowButtonUpFcn;
                else
                    obj.hFig.WindowButtonUpFcn = [];
                end
                
                startPoint = [];
                originalConfig = struct();
            end
        end
        
        function closeRequestFcn(obj,src,evt)
            if isvalid(obj)
                obj.delete();
            end
        end
    end
end

%% Local functions
function f = factors(n)
f = find(rem(n, 1:floor(sqrt(n))) == 0);
f = unique([1, n, f, fix(n./f)]);
f = sort(f);
end

%--------------------------------------------------------------------------%
% LiveHistogram.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
