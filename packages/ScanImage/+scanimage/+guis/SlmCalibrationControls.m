classdef  SlmCalibrationControls < most.Gui    
    %% GUI PROPERTIES
    properties (SetAccess = protected,SetObservable,Hidden)
        hListeners
        hAx1;
        hAx2;
        
        hSlmLutCurve;
        hSlmLutCurveSmooth;
        hSlmResponseCurve;
        hSlmSelectedCurve;
        hSlmSelectedPt1;
        hSlmSelectedPt2;
        hSlmSelectedMidPt;
    end
    
    properties (SetObservable)
        wavelength = 1064;
        numMeasurementPoints = 256;
        referencePixelValue = 0;
        checkerSize = 4;
        channelNumber = 1;
        polyDegree = 0;
    end
    
    properties (Hidden)
        slmSelectionPixelVals = [];
        pixelVals = [];
        intensities = [];
        
        lut = [];
    end
    
    %% LIFECYCLE
    methods
        function obj = SlmCalibrationControls(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            obj = obj@most.Gui(hModel, hController, [200 50], 'characters');
            set(obj.hFig,'Name','SLM LUT CALIBRATION');
            
            if ~isempty(obj.hModel.hSlmScan) && isvalid(obj.hModel.hSlmScan)
                obj.referencePixelValue = double(intmax(obj.hModel.hSlmScan.hSlm.pixelDataType));
            end
            
            hTop = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
            hLeft = most.gui.uiflowcontainer('Parent',hTop,'FlowDirection','TopDown');
            hRight = most.gui.uiflowcontainer('Parent',hTop,'FlowDirection','TopDown');
            
            hLeftTop = most.gui.uiflowcontainer('Parent',hLeft,'FlowDirection','LeftToRight');
            set(hLeftTop,'HeightLimits',[210 210]);
            hAx1Container = uicontainer('Parent',hLeft);
            hAx2Container = uicontainer('Parent',hRight);
            
            hPanelAx1 = uipanel('Parent',hAx1Container,'Title','SLM LUT','FontWeight','bold');
            obj.hAx1 = axes('Parent',hPanelAx1,'Box','on');
            
            hPanelAx2 = uipanel('Parent',hAx2Container,'Title','SLM Phase Response','FontWeight','bold');
            obj.hAx2 = axes('Parent',hPanelAx2,'Box','on');
            
            xlabel(obj.hAx1,'Phase');
            ylabel(obj.hAx1,'SLM Pixel Value');
            
            xlabel(obj.hAx2,'Checker Pattern Pixel Value');
            ylabel(obj.hAx2,'Measured Intensity');
            
            grid(obj.hAx1,'on');
            grid(obj.hAx2,'on');
            
            obj.hSlmResponseCurve = line('Parent',obj.hAx2,'Color','blue','HitTest','off','PickableParts','none','XData',NaN,'YData',NaN);
            obj.hSlmSelectedCurve = line('Parent',obj.hAx2,'Color','red','LineWidth',2,'HitTest','off','PickableParts','none','XData',NaN,'YData',NaN);
            obj.hSlmSelectedPt1   = line('Parent',obj.hAx2,'LineStyle','none','Marker','o','Color','red','ButtonDownFcn',@obj.startMove,'HitTest','on','PickableParts','all','XData',NaN,'YData',NaN);
            obj.hSlmSelectedPt2   = line('Parent',obj.hAx2,'LineStyle','none','Marker','o','Color','red','ButtonDownFcn',@obj.startMove,'HitTest','on','PickableParts','all','XData',NaN,'YData',NaN);
            obj.hSlmSelectedMidPt = line('Parent',obj.hAx2,'LineStyle','none','Marker','diamond','Color','red','HitTest','off','PickableParts','none','XData',NaN,'YData',NaN);
            obj.hSlmLutCurve      = line('Parent',obj.hAx1,'Color','blue','HitTest','off','PickableParts','none','XData',NaN,'YData',NaN);
            obj.hSlmLutCurveSmooth= line('Parent',obj.hAx1,'Color','red','HitTest','off','PickableParts','none','XData',NaN,'YData',NaN);
            
            hPanel = uipanel('Parent',hLeftTop,'Title','Pattern Controls','FontWeight','bold');
            
            hPanelFlCtr = most.gui.uiflowcontainer('Parent',hPanel,'FlowDirection','TopDown');
                hPanelFlCtr0 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr0,...
                        'Style','edit',...
                        'Bindings',{obj 'wavelength' 'Value'},...
                        'Tag','etWavelength');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr0,...
                        'Style','text',...
                        'String','Wavelength (nm)',...
                        'HorizontalAlignment','left');
                hPanelFlCtr1 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr1,...
                        'Style','edit',...
                        'Bindings',{obj 'numMeasurementPoints' 'Value'},...
                        'Tag','etNumMeasurementPts');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr1,...
                        'Style','text',...
                        'String','Number of Measurement Points',...
                        'HorizontalAlignment','left');
                hPanelFlCtr2 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr2,...
                        'Style','edit',...
                        'Bindings',{obj 'referencePixelValue' 'Value'},...
                        'Tag','etReferencePixelValue');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr2,...
                        'Style','text',...
                        'String','Reference Pixel Value',...
                        'HorizontalAlignment','left');
                hPanelFlCtr3 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr3,...
                        'Style','edit',...
                        'Bindings',{obj 'checkerSize' 'Value'},...
                        'Tag','etCeckerSize');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr3,...
                        'Style','text',...
                        'String','Checker Size (pixels)',...
                        'HorizontalAlignment','left');
                hPanelFlCtr4 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr4,...
                        'Style','edit',...
                        'Bindings',{obj 'channelNumber' 'Value'},...
                        'Tag','etChannelNumber');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr4,...
                        'Style','text',...
                        'String','Channel Number for Measurement',...
                        'HorizontalAlignment','left');
                hPanelFlCtr5 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr5,...
                        'Style','edit',...
                        'Bindings',{obj 'polyDegree' 'Value'},...
                        'Tag','etPolyDegree');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr5,...
                        'Style','text',...
                        'String','Polynomial Degree for LUT smoothing',...
                        'HorizontalAlignment','left');
                hPanelFlCtr6 = most.gui.uiflowcontainer('Parent',hPanelFlCtr,'FlowDirection','LeftToRight');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr6,...
                        'String','Measure',...
                        'Callback',@(varargin)obj.measureSlmResponse(),...
                        'Tag','pbMeasureSlmResponse');
                    obj.addUiControl(...
                        'Parent',hPanelFlCtr6,...
                        'String','Save LUT',...
                        'Callback',@(varargin)obj.saveLut(),...
                        'Tag','pbSaveLut');            
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% User Methods
    methods
        function measureSlmResponse(obj)
            if ~isempty(obj.hModel.hSlmScan.mdfData.beamDaqID)
                h = msgbox('User Action required: Set Pockels Cell to ''Direct Mode'' and adjust power to measure LUT.','Direct Mode','warn');
                waitfor(h);
            end
            
            obj.hModel.hSlmScan.pointScanner(0,0);
            pause(0.1);
            try
                [obj.pixelVals,obj.intensities] = obj.hModel.hSlmScan.hSlm.measureCheckerPatternResponse(@obj.measureIntensity,obj.checkerSize,obj.numMeasurementPoints,obj.referencePixelValue);
                obj.hModel.hSlmScan.parkScanner();
            catch ME
                obj.hModel.hSlmScan.parkScanner();
                rethrow(ME);
            end
            obj.plotSlmResponse();
        end
        
        function saveLut(obj)
            assert(~isempty(obj.lut));
            obj.hModel.hSlmScan.wavelength = obj.wavelength * 1e-9;
            obj.hModel.hSlmScan.lut = obj.lut;
            obj.hModel.hSlmScan.plotLut();
        end
        
        function val = measureIntensity(obj)
            val = obj.hModel.hSlmScan.acquireLutCalibrationSample(100);
            val = mean(val,1);
            assert(obj.channelNumber <= length(val),'Channel %d unavailable',obj.channelNumber);
            val = val(obj.channelNumber);
        end
        
        function plotSlmResponse(obj)
            hAx_ = ancestor(obj.hSlmResponseCurve,'axes');
            
            if isempty(obj.pixelVals) || isempty(obj.intensities)
                obj.hSlmResponseCurve.Visible = 'off';
            else 
                obj.hSlmResponseCurve.XData = obj.pixelVals;
                obj.hSlmResponseCurve.YData = obj.intensities;
                obj.hSlmResponseCurve.Visible = 'on';
                hAx_.XLim = [obj.pixelVals(1),obj.pixelVals(end)];
            end
            
            obj.initSlmSelection();
        end
        
        function initSlmSelection(obj)
            if isempty(obj.pixelVals) || isempty(obj.intensities)
                obj.slmSelectionPixelVals = [];
            else
                idx1 = round(0.2*length(obj.pixelVals));
                idx2 = round(0.8*length(obj.pixelVals));
                obj.slmSelectionPixelVals = [obj.pixelVals(idx1) obj.pixelVals(idx2)];
            end
        end
        
        function plotSlmSelection(obj)
            if isempty(obj.slmSelectionPixelVals) || isempty(obj.pixelVals) || isempty(obj.intensities)
                obj.hSlmSelectedPt1.Visible = 'off';
                obj.hSlmSelectedPt2.Visible = 'off';
                obj.hSlmSelectedMidPt.Visible = 'off';
                return
            end
            
            pixelIdxs = obj.slmSelectionValsToIdxs(obj.slmSelectionPixelVals);
            
            obj.hSlmSelectedCurve.XData = obj.pixelVals(pixelIdxs(1):pixelIdxs(2));
            obj.hSlmSelectedCurve.YData = obj.intensities(pixelIdxs(1):pixelIdxs(2));
            obj.hSlmSelectedCurve.Visible = 'on';
            
            obj.hSlmSelectedPt1.XData = obj.pixelVals(pixelIdxs(1));
            obj.hSlmSelectedPt1.YData = obj.intensities(pixelIdxs(1));
            obj.hSlmSelectedPt1.Visible = 'on';
            
            obj.hSlmSelectedPt2.XData = obj.pixelVals(pixelIdxs(2));
            obj.hSlmSelectedPt2.YData = obj.intensities(pixelIdxs(2));
            obj.hSlmSelectedPt2.Visible = 'on';
            
            [pkVal,pkIdx] = obj.hModel.hSlmScan.hSlm.findPeak(obj.intensities(pixelIdxs(1):pixelIdxs(2)));
            if isempty(pkIdx)
                obj.hSlmSelectedMidPt.Visible = 'off';
            else 
                obj.hSlmSelectedMidPt.XData = obj.pixelVals(pixelIdxs(1)+pkIdx-1);
                obj.hSlmSelectedMidPt.YData = pkVal;
                obj.hSlmSelectedMidPt.Visible = 'on';
            end
        end
        
        function plotLut(obj)
            idxs = obj.slmSelectionValsToIdxs(obj.slmSelectionPixelVals);
            
            try
                obj.lut = obj.hModel.hSlmScan.hSlm.calculateLut(obj.pixelVals(idxs(1):idxs(2)),obj.intensities(idxs(1):idxs(2)));
            catch
                obj.hSlmLutCurve.Visible = 'off';
                obj.lut = [];
                return
            end
            
            hAx_ = ancestor(obj.hSlmLutCurve,'axes');
            
            obj.hSlmLutCurve.XData = obj.lut(:,1);
            obj.hSlmLutCurve.YData = obj.lut(:,2);
            obj.hSlmLutCurve.Visible = 'on';
            
            hAx_.XLimMode = 'manual';
            hAx_.XLim = [0 2*pi];
            hAx_.YLim = [0 2^obj.hModel.hSlmScan.hSlm.pixelBitDepth-1];
            ticks = 0:(.25*pi):2*pi;
            hAx_.XTick = ticks;
            l = arrayfun(@(v){sprintf('%g\\pi',v)}, round(ticks/pi,2));
            
            try
                hAx_.XTickLabelMode = 'manual';
                hAx_.XTickLabel = strrep(l,'1\pi','\pi');
            catch
                hAx_.XTickLabelMode = 'auto';
            end
            
            if ~isempty(obj.polyDegree) && obj.polyDegree > 0 && ~isempty(obj.lut)
                [p,S,mu] = polyfit(obj.lut(:,1),obj.lut(:,2),obj.polyDegree);
                xx = linspace(0,2*pi,255)';
                yy = polyval(p,xx,S,mu);
                obj.lut = [xx,yy];
                
                obj.hSlmLutCurveSmooth.XData = obj.lut(:,1);
                obj.hSlmLutCurveSmooth.YData = obj.lut(:,2);
                obj.hSlmLutCurveSmooth.Visible = 'on';
            else
                obj.hSlmLutCurveSmooth.Visible = 'off';
            end
        end
    end
    
    %% Internal Methods
    methods
        function startMove(obj,src,evt)
            obj.hFig.WindowButtonMotionFcn = @obj.windowMotionFcn;
            obj.hFig.WindowButtonUpFcn = @obj.endMove;
        end
        
        function windowMotionFcn(obj,src,evt)
            hAx_ = ancestor(obj.hSlmResponseCurve,'axes');
            x = hAx_.CurrentPoint(1,1);
            [~,idx] = min(abs(obj.slmSelectionPixelVals-x)); % move the point closest to the mouse pointer
            obj.slmSelectionPixelVals(idx) = x;
        end
        
        function endMove(obj,src,evt)
            obj.hFig.WindowButtonMotionFcn = [];
            obj.hFig.WindowButtonUpFcn = [];
        end
        
        function idxs = slmSelectionValsToIdxs(obj,val)
            [tf,idxs] = ismember(val,obj.pixelVals);
            assert(all(tf));
        end
    end
    
    %% PROP ACCESS
    methods
        function set.slmSelectionPixelVals(obj,val)
            val = sort(val);
            val = bsxfun(@minus,val(:)',obj.pixelVals(:));
            val = abs(val);
            [~,idxs] = min(val,[],1);
            val = obj.pixelVals(idxs);
            
            obj.slmSelectionPixelVals = val;
            
            obj.plotSlmSelection();
            obj.plotLut();
        end
        
        function set.polyDegree(obj,val)
            obj.polyDegree = val;
            obj.plotLut();
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct();
end

%--------------------------------------------------------------------------%
% SlmCalibrationControls.m                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
