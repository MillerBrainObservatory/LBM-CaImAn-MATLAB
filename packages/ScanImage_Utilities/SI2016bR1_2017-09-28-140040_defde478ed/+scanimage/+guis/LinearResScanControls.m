classdef LinearResScanControls < most.Gui
    
    properties (Hidden)
        hSI;
        hScanner;
        
        hListeners = [];
    end
    
    %% Lifecycle
    methods
        function obj = LinearResScanControls()
            
            obj = obj@most.Gui([], [], [40 15.6]);
            set(obj.hFig,'Name','LINEAR RESSCAN SCAN CONTROLS','Resize','off','CloseRequestFcn',@(varargin)obj.figCloseEventHandler(),'Tag','CORNELLC');
            
            try
                obj.hSI = evalin('base','hSI');
            catch
                obj.hSI = [];
            end
            assert(~isempty(obj.hSI), 'ScanImage must be running.');
            obj.hScanner = obj.hSI.hResMirrorSim.hScan;
            
            
            hMainFlow = most.gui.uiflowcontainer('Parent', obj.hFig,'FlowDirection','TopDown','Margin',0.0001);
            hTopFlow = most.gui.uiflowcontainer('Parent', hMainFlow,'FlowDirection','TopDown','Margin',0.0001);
            hBottomFlow = most.gui.uiflowcontainer('Parent', hMainFlow,'FlowDirection','BottomUp','Margin',0.0001);
            
            marg = 4;
            hTopFlow1 = most.gui.uiflowcontainer('Parent', hTopFlow,'FlowDirection','LeftToRight','Margin',marg);
            hTopFlow2 = most.gui.uiflowcontainer('Parent', hTopFlow,'FlowDirection','RightToLeft','Margin',marg);
            hTopFlow3 = most.gui.uiflowcontainer('Parent', hTopFlow,'FlowDirection','LeftToRight','Margin',marg);
            hTopFlow4 = most.gui.uiflowcontainer('Parent', hTopFlow,'FlowDirection','LeftToRight','Margin',marg);
            
            hBottomFlow1 = most.gui.uiflowcontainer('Parent', hBottomFlow,'FlowDirection','LeftToRight','Margin',marg);
            hBottomFlow2 = most.gui.uiflowcontainer('Parent', hBottomFlow,'FlowDirection','LeftToRight','Margin',marg);
            
            set([hTopFlow1 hTopFlow2 hTopFlow3 hTopFlow4 hBottomFlow1 hBottomFlow2], 'HeightLimits', 24*ones(1,2));
            
            most.gui.staticText('Parent',hTopFlow1,'String','X Galvo Cycle Rate (Hz):','HorizontalAlignment','right');
            hC = obj.addUiControl(...
                'Parent',hTopFlow1,...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','500',...
                'Style','edit',...
                'callback',@(varargin)obj.setCyclePeriod,...
                'tag','etCycleRate');
            set(hC, 'WidthLimits', 60*ones(1,2));
            
            
            most.gui.staticText('Parent',hTopFlow3,'String','Pixel Bin Factor:','HorizontalAlignment','right');
            hC = obj.addUiControl(...
                'Parent',hTopFlow3,...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','1',...
                'Style','edit',...
                'Bindings',{obj.hScanner 'pixelBinFactor' 'Value'},...
                'tag','etPBF');
            set(hC, 'WidthLimits', 60*ones(1,2));
            
            
            hC = obj.addUiControl(...
                'Parent',hTopFlow2,...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','Uniform Sampling',...
                'Bindings',{{obj.hScanner 'uniformSampling' 'Value'} {obj.hScanner 'uniformSampling' 'callback' @obj.usChanged}},...
                'Style','checkbox','tag','cbUniformSampling');
            set(hC, 'WidthLimits', 110*ones(1,2));
            st = most.gui.staticText('Parent',hTopFlow2,'String','','HorizontalAlignment','right');
            set(st, 'WidthLimits', [1 190]);
            
            
            most.gui.staticText('Parent',hTopFlow4,'String','Fill Fraction:','HorizontalAlignment','right');
            hC = obj.addUiControl(...
                'Parent',hTopFlow4,...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','.7',...
                'Style','edit',...
                'Bindings',{obj.hScanner 'fillFractionSpatial' 'Value'},...
                'tag','etFillFraction');
            set(hC, 'WidthLimits', 60*ones(1,2));
            
            
            most.gui.staticText('Parent',hBottomFlow2,'String','Pixels per Line:','HorizontalAlignment','right');
            hC = obj.addUiControl(...
                'Parent',hBottomFlow2,...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','500',...
                'Style','edit',...
                'enable', 'inactive',...
                'BackgroundColor', obj.hFig.Color*1.01,...
                'Bindings',{obj.hScanner 'scanPixelTimeMean' 'Callback' @obj.updatePPL},...
                'tag','etPPL');
            set(hC, 'WidthLimits', 60*ones(1,2));
            
            
            most.gui.staticText('Parent',hBottomFlow1,'String','Data Rate (MB/s):','HorizontalAlignment','right');
            hC = obj.addUiControl(...
                'Parent',hBottomFlow1,...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','0',...
                'Style','edit',...
                'enable', 'inactive',...
                'BackgroundColor', obj.hFig.Color*1.01,...
                'Bindings',{{obj.hScanner 'bidirectional' 'Callback' @obj.updateDR} {obj.hSI.hChannels 'channelsActive' 'Callback' @obj.updateDR}},...
                'tag','etDR');
            set(hC, 'WidthLimits', 60*ones(1,2));
            
            obj.updatePPL();
            obj.hListeners = obj.hSI.addlistener('ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.Visible = true;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
        end
        
        function figCloseEventHandler(obj)
            delete(obj);
        end
    end
    
    methods (Hidden)
        function setCyclePeriod(obj)
            f = str2double(obj.etCycleRate.hCtl.String);
            obj.hScanner.mdfData.nominalResScanFreq = f;
            obj.hSI.hResMirrorSim.cyclePeriod = 1/f;
            obj.hScanner.measureScannerFrequency();
            
            obj.updatePPL();
        end
        
        function updatePPL(obj,varargin)
            if isprop(obj,'etPPL')
                [~] = obj.hScanner.scanPixelTimeMean;
                ppl = obj.hScanner.hAcq.pixelsPerLine;
                obj.etPPL.hCtl.String = num2str(ppl);
                
                if ppl > 2^16
                    obj.etPPL.hCtl.ForegroundColor = 'r';
                else
                    obj.etPPL.hCtl.ForegroundColor = 'k';
                end
                
                obj.updateDR();
            end
        end
        
        function updateDR(obj,varargin)
            if isprop(obj,'etDR')
                dr = obj.hScanner.hAcq.dataRate;
                obj.etDR.hCtl.String = sprintf('%.2f',dr);
                
                if dr > 200
                    obj.etDR.hCtl.ForegroundColor = 'r';
                else
                    obj.etDR.hCtl.ForegroundColor = 'k';
                end
            end
        end
        
        function usChanged(obj,varargin)
            if obj.hScanner.uniformSampling
                obj.etPBF.hCtl.Enable = 'on';
            else
                obj.etPBF.hCtl.Enable = 'off';
            end
        end
    end
end


%--------------------------------------------------------------------------%
% LinearResScanControls.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
