classdef ZAlignmentControls < most.Gui & most.HasClassDataFile
    %% USER PROPS
    properties (SetObservable)
       zAlignment;
    end
    
    properties (Hidden)
        hAx;
        hLine;
        hLineMarkers;
        hPositionMarker;
        hEtScannerIncrement;
        hEtMotorIncrement;
        hPmReferenceMotor;
        hTxtAlignment;
        hPmScanner;
                
        hVisibleListener;
        hScan2DListener;
        hZAlignmentListener;
        hVideoImToRefImListener;
        
        zeroPointRef = 0;
        linkMovement = true;
        
        currentPosition = [0 0];
        referenceMotor = 'Motor';
        scanner = 'SLM';
        
        displayUnits = 1e-6; %um
    end
    
    properties (Hidden,Dependent)
        scannerIncrement;
        motorIncrement;
    end
    
    %% LIFECYCLE
    methods
        function obj = ZAlignmentControls(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            obj = obj@most.Gui(hModel, hController, [100 30], 'characters');
            set(obj.hFig,'Name','Z ALIGNMENT CONTROLS','Resize','off',...
                'KeyPressFcn',@obj.figKeyPressed,'Interruptible','off','BusyAction','cancel'); % don't allow figKeyPressed fcn to be interrupted to avoid moving motor to far
            
            flowmain = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                flowAlignTxt = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
                    flowAlignTxt.HeightLimits = [25 25];
                flowAx = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
                flow1 = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
                    flow1.HeightLimits = [50,50];
                    pnlRead = uipanel('Parent',flow1,'Title','Position');
                        pnlRead.WidthLimits = [60 60];
                        flowRead = most.gui.uiflowcontainer('Parent',pnlRead,'FlowDirection','LeftToRight');
                    pnlMotor = uipanel('Parent',flow1,'Title','Reference Motor');
                        pnlMotor.WidthLimits = [230 Inf];
                        flowMotor = most.gui.uiflowcontainer('Parent',pnlMotor,'FlowDirection','LeftToRight');
                    pnlScanner = uipanel('Parent',flow1,'Title','Scanner');
                        flowScanner = most.gui.uiflowcontainer('Parent',pnlScanner,'FlowDirection','LeftToRight');
                flow2 = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
                    set(flow2,'HeightLimits',[40,40]);
                flow3 = most.gui.uiflowcontainer('Parent',flowmain,'FlowDirection','LeftToRight');
                    set(flow3,'HeightLimits',[40,40]);
            
            cmenu = uicontextmenu(obj.hFig);
            uimenu(cmenu,'Label','Goto','Callback',@obj.gotoPoint);
            uimenu(cmenu,'Label','Delete','Callback',@obj.deletePoint);
            
            obj.hAx = axes('Parent',flowAx);
            grid(obj.hAx,'on');
            box(obj.hAx,'on');
            obj.hLine = line('Parent',obj.hAx,'XData',NaN','YData',NaN,'Color','blue','Marker','none','Hittest','off','PickableParts','none');
            obj.hLineMarkers = line('Parent',obj.hAx,'XData',NaN','YData',NaN,'Color','blue','LineStyle','none','Marker','o','MarkerFaceColor',[0.75 0.75 1],'UIContextMenu',cmenu);
            obj.hPositionMarker = line('Parent',obj.hAx,'XData',NaN','YData',NaN,'ZData',1,'Color','red','Marker','o','MarkerSize',10,'LineWidth',1.5,'Hittest','off','PickableParts','none');
            xlabel(obj.hAx,'Reference Z Motor [um]');
            ylabel(obj.hAx,'Z Scanner (Raw) [um]');
            
            uicontrol('Parent',flowRead,'Style','pushbutton','String','Read','Callback',@(src,evt)obj.readCurrentPosition());
            
            obj.hPmReferenceMotor = uicontrol('Parent',flowMotor,'Style','popupmenu','String',{'Motor','FastZ'},'Value',1,'Callback',@obj.changeMotor);
            hButtonLeft = uicontrol('Parent',flowMotor,'Style','pushbutton','String',char(8592),'Callback',@(src,evt)obj.incrementMotor(-1),'Interruptible','off','BusyAction','cancel');
            obj.hEtMotorIncrement = uicontrol('Parent',flowMotor,'Style','edit','String','10');
            hButtonRight = uicontrol('Parent',flowMotor,'Style','pushbutton','String',char(8594),'Callback',@(src,evt)obj.incrementMotor(+1),'Interruptible','off','BusyAction','cancel');
            
            obj.hPmScanner = uicontrol('Parent',flowScanner,'Style','popupmenu','String',{'SLM','FastZ'},'Value',1,'Callback',@obj.changeScanner);
            hButtonDown = uicontrol('Parent',flowScanner,'Style','pushbutton','String',char(8595),'Callback',@(src,evt)obj.incrementScanner(-1),'Interruptible','off','BusyAction','cancel');
            obj.hEtScannerIncrement = uicontrol('Parent',flowScanner,'Style','edit','String','10');
            hButtonUp = uicontrol('Parent',flowScanner,'Style','pushbutton','String',char(8593),'Callback',@(src,evt)obj.incrementScanner(+1),'Interruptible','off','BusyAction','cancel');
            
            uicontrol('Parent',flow2,'Style','pushbutton','String','Set Reference Zero','Callback',@(varargin)obj.setZero());
            uicontrol('Parent',flow2,'Style','pushbutton','String','Clear Reference Zero','Callback',@(varargin)obj.clearZero());
            hButtonAddPoint = uicontrol('Parent',flow2,'Style','pushbutton','String','Add Point','Callback',@(varargin)obj.addPoint());
            
            uicontrol('Parent',flow3,'Style','pushbutton','String','Save Z-Alignment','Callback',@(src,evt)obj.saveAlignment());
            uicontrol('Parent',flow3,'Style','pushbutton','String','Delete Z-Alignment','Callback',@(src,evt)obj.deleteAlignment());
            
            tooltipstring = sprintf('Arrow keys (left right) move motor.\nArrow keys (up down) move scanner.\nSpace bar/Enter adds a point\nUse control or shift to step in smaller increments.');
            set([hButtonLeft hButtonRight hButtonDown hButtonUp hButtonAddPoint],'TooltipString',tooltipstring);
            
            obj.hTxtAlignment = uicontrol('Parent',flowAlignTxt,'Style','pushbutton','String','','Callback',@(src,evt)obj.showAlignmentWindow());
            
            obj.zAlignment = []; % initialize zAlignment
            
            obj.hScan2DListener = addlistener(obj.hModel,'imagingSystem','PostSet',@(src,evt)obj.importZAlignment());
            obj.initAlignmentWindowListener();
            
            obj.hVisibleListener = addlistener(obj.hFig,'Visible','PostSet',@obj.changedVisible);
            obj.Visible = obj.Visible;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hVisibleListener);
            most.idioms.safeDeleteObj(obj.hScan2DListener);
            most.idioms.safeDeleteObj(obj.hZAlignmentListener);
            most.idioms.safeDeleteObj(obj.hVideoImToRefImListener);
        end
    end
    
    methods (Hidden)
        function initAlignmentListener(obj)
            most.idioms.safeDeleteObj(obj.hZAlignmentListener);
            
            switch lower(obj.scanner)
                case 'slm'
                    if ~isempty(obj.hModel.hSlmScan)
                        obj.hZAlignmentListener = addlistener(obj.hModel.hSlmScan,'zAlignment','PostSet',@(src,evt)obj.importZAlignment());
                        obj.importZAlignment();
                    end
                case 'fastz'
                    obj.hZAlignmentListener = addlistener(obj.hModel.hFastZ,'zAlignment','PostSet',@(src,evt)obj.importZAlignment());
                    obj.importZAlignment();
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
                
        end
        
        function initAlignmentWindowListener(obj)
            obj.hVideoImToRefImListener = addlistener(obj.hController.hGuiClasses.AlignmentControls,'videoImToRefImTransform','PostSet',@(src,evt)obj.changedVideoImToRefImTransform);
        end
        
        function importZAlignment(obj)
            switch lower(obj.scanner)
                case 'fastz'
                    obj.zAlignment = obj.hModel.hFastZ.zAlignment;
                case 'slm'
                    if ~isempty(obj.hModel.hSlmScan)
                        obj.zAlignment = obj.hModel.hSlmScan.zAlignment;
                    else
                        obj.zAlignment = [];
                    end
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
        end
        
        function saveAlignment(obj)
            switch lower(obj.scanner)
                case 'fastz'
                    obj.hModel.hFastZ.zAlignment = obj.zAlignment;
                case 'slm'
                    obj.hModel.hSlmScan.zAlignment = obj.zAlignment;
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
        end
        
        function deleteAlignment(obj)
            switch lower(obj.scanner)
                case 'fastz'
                    obj.hModel.hFastZ.zAlignment = [];
                case 'slm'
                    obj.hModel.hSlmScan.zAlignment = [];
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
        end
        
        function changedVideoImToRefImTransform(obj)
            if strcmpi(obj.hFig.Visible,'off')
                return
            end
            
            switch lower(obj.scanner)
                case 'fastz'
                    % No-op
                case 'slm'
                    refZ_ = obj.currentPosition(1);
                    scannerZ_ = obj.currentPosition(2);
                    alignment_ = obj.hController.hGuiClasses.AlignmentControls.videoImToRefImTransform;
                    obj.zAlignment = obj.zAlignment.addPoint(-refZ_,scannerZ_,alignment_);
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
        end
        
        function changedVisible(obj,varargin)
            if obj.Visible
                obj.readCurrentPosition();
            end
        end
        
        function redraw(obj)
            allXs = zeros(0,1);
            allYs = zeros(0,1);
                        
            if isempty(obj.currentPosition)
                obj.hPositionMarker.Visible = 'off';
            else
                obj.hPositionMarker.XData = toMicron(obj.currentPosition(1));
                obj.hPositionMarker.YData = toMicron(obj.currentPosition(2));
                obj.hPositionMarker.Visible = 'on';
                
                allXs = vertcat(allXs,toMicron(obj.currentPosition(1)));
                allYs = vertcat(allYs,toMicron(obj.currentPosition(2)));
            end
            
            if isempty(obj.zAlignment) || isempty(obj.zAlignment.refZ)
                obj.hLine.Visible = 'off';
                obj.hLineMarkers.Visible = 'off';
            else                
                obj.hLineMarkers.XData = -toMicron(obj.zAlignment.refZ);
                obj.hLineMarkers.YData = toMicron(obj.zAlignment.scannerZ);
                obj.hLineMarkers.Visible = 'on';
                
                refZSmooth = linspace(obj.zAlignment.refZ(1),obj.zAlignment.refZ(end),1000);
                scannerZSmooth = obj.zAlignment.refZtoScannerZ(refZSmooth);                
                obj.hLine.XData = toMicron(-refZSmooth);
                obj.hLine.YData = toMicron(scannerZSmooth);
                obj.hLine.Visible = 'on';
                
                allXs = vertcat(allXs,toMicron(-obj.zAlignment.refZ));
                allYs = vertcat(allYs,toMicron(obj.zAlignment.scannerZ));
            end            
            
            % determine XLim/YLim
            allXs = unique(allXs);
            allYs = unique(allYs);
            
            if length(unique(allXs)) < 2
                obj.hAx.XLimMode = 'auto';
            else
                obj.hAx.XLim = growRange([min(allXs) max(allXs)],0.2);
            end
            
            if length(unique(allYs)) < 2
                obj.hAx.YLimMode = 'auto';
            else
                obj.hAx.YLim = growRange([min(allYs) max(allYs)],0.2);
            end
            
            
            function range = growRange(range,factor)
                d = diff(range)*factor/2;
                range = range + [-d d];
            end
            
            function um = toMicron(m)
                um = m/obj.displayUnits;
            end
        end
        
        function gotoPoint(obj,src,evt)
            idx = obj.getSelection();
            if ~isempty(idx)
                obj.setReferenceMotorPositionRelative(-obj.zAlignment.refZ(idx));
            end
        end
        
        function deletePoint(obj,varargin)
            idx = obj.getSelection();
            if ~isempty(idx)
                obj.zAlignment = obj.zAlignment.removePointByIdx(idx);
            end                
        end
        
        function idx = getSelection(obj,varargin)
            pt = obj.hAx.CurrentPoint(1,[1:2]) * obj.displayUnits;
            pts = [-obj.zAlignment.refZ obj.zAlignment.scannerZ];
            
            d = bsxfun(@minus,pts,pt);
            d = sqrt(sum(d.^2,2));
            
            [~,idx] = min(d);
        end
        
        function figKeyPressed(obj,src,evt)
            shift = ismember('shift',evt.Modifier);
            ctrl = ismember('control',evt.Modifier);
            if ctrl && ~shift
                step = 0.1;
            elseif shift && ~ctrl
                step = 0.01;
            elseif shift && ctrl
                step = 0.001;
            else
                step = 1;
            end
            
            switch evt.Key
                case 'downarrow'
                    obj.incrementScanner(-step)
                case 'uparrow'
                    obj.incrementScanner(step)
                case 'leftarrow'
                    obj.incrementMotor(-step)
                case 'rightarrow'
                    obj.incrementMotor(step)
                case {'space','return'}
                    obj.addPoint();
                otherwise
                    % No-op
            end
        end
        
        function setZero(obj)
            obj.zeroPointRef = obj.getReferenceMotorPosition();
            obj.readCurrentPosition();
        end
        
        function clearZero(obj)
            obj.zeroPointRef = 0;
            obj.readCurrentPosition();
        end
    end
        
    
    %% Property Getter/Setter
    methods
        function set.referenceMotor(obj,val)
            assert(ismember(val,{'Motor','FastZ'}));
            obj.referenceMotor = val;
            obj.zeroPointRef = 0;
            obj.readCurrentPosition();
            
            [tf,idx] = ismember(lower(val),lower(obj.hPmReferenceMotor.String));
            if tf
                obj.hPmReferenceMotor.Value = idx;
            end
        end
        
        function set.scanner(obj,val)
            assert(ismember(val,{'SLM','FastZ'}));
            obj.scanner = val;
            obj.readCurrentPosition();
            
            obj.initAlignmentListener();
            obj.importZAlignment();
            
            [tf,idx] = ismember(lower(val),lower(obj.hPmScanner.String));
            if tf
                obj.hPmScanner.Value = idx;
            end
        end
        
        function set.zeroPointRef(obj,val)
            validateattributes(val,{'numeric'},{'nonnan','finite'});
            obj.zeroPointRef = val;
        end
        
        function set.zAlignment(obj,val)
            if isempty(val)
                val = scanimage.mroi.util.zAlignmentData();
            end
            assert(isa(val,'scanimage.mroi.util.zAlignmentData'));
            
            obj.zAlignment = val;
            obj.redraw();
            obj.updateAlignmentText();
        end
        
        function val = get.scannerIncrement(obj)
            val = str2double(obj.hEtScannerIncrement.String) * obj.displayUnits; % microns
        end
        
        function val = get.motorIncrement(obj)
            val = str2double(obj.hEtMotorIncrement.String) * obj.displayUnits; % microns
        end
        
        function set.currentPosition(obj,val)
            obj.currentPosition = val;
            obj.redraw();
            obj.updateAlignmentText();
        end
    end
    
    methods
        function changeMotor(obj,src,evt)
            val = src.String{src.Value};
            obj.referenceMotor = val;
        end
        
        function changeScanner(obj,src,evt)
            val = src.String{src.Value};
            obj.scanner = val;
        end
        
        function incrementScanner(obj,sign)
            obj.moveScannerPosition(obj.getScannerPosition+obj.scannerIncrement*sign);
        end
        
        function incrementMotor(obj,sign)
            obj.moveReferenceMotorRelative(obj.motorIncrement*sign);
        end
        
        function moveReferenceMotorRelative(obj,d)
            currentPos = obj.getReferenceMotorPositionRelative();
            obj.setReferenceMotorPositionRelative(currentPos+d);
        end
        
        function val = getReferenceMotorPositionRelative(obj)
            val = obj.getReferenceMotorPosition() - obj.zeroPointRef;
        end
        
        function setReferenceMotorPositionRelative(obj,val)
            obj.setReferenceMotorPosition(val + obj.zeroPointRef);
            if obj.linkMovement
                obj.updateScanner();
            end
        end
        
        function val = getReferenceMotorPosition(obj) 
            switch lower(obj.referenceMotor)
                case 'motor'
                    val = obj.hModel.hMotors.motorPositionMeter(3);
                case 'fastz'
                    val = obj.hModel.hFastZ.positionTargetRawMeter;
                otherwise
                    error('Unknown motor: %s',obj.referenceMotor);
            end
        end
        
        function setReferenceMotorPosition(obj,val)
            switch lower(obj.referenceMotor)
                case 'motor'
                    obj.hModel.hMotors.motorPositionMeter(3) = val;
                case 'fastz'
                    obj.hModel.hFastZ.positionTargetRawMeter = val;
                otherwise
                    error('Unknown motor: %s',obj.referenceMotor);
            end                    
            
            %obj.currentPosition(1) = obj.getReferenceMotorPositionRelative();
            obj.readCurrentPosition();
        end
        
        function val = getScannerPosition(obj)
            switch lower(obj.scanner)
                case 'fastz'
                    val = obj.hModel.hFastZ.positionTargetRawMeter;
                case 'slm'
                    if ~isempty(obj.hModel.hSlmScan)
                        val = obj.hModel.hSlmScan.hSlm.lastWrittenPoint(1,3);
                    else
                        val = NaN;
                    end
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
        end
        
        function moveScannerPosition(obj,z)
            switch lower(obj.scanner)
                case 'fastz'
                    obj.hModel.hFastZ.positionTargetRawMeter = z;
                case 'slm'
                    if ~isempty(obj.hModel.hSlmScan)
                        xy = obj.hModel.hSlmScan.hSlm.lastWrittenPoint(1,1:2);
                        obj.hModel.hSlmScan.hSlm.pointScanner([xy z]);
                    end
                otherwise
                    error('Unknown scanner: %s',obj.scanner);
            end
            
            %obj.currentPosition(2) = obj.getScannerPosition();
            obj.readCurrentPosition();
        end
        
        function addPoint(obj)
            obj.readCurrentPosition();
            pos = obj.currentPosition;
            refZ = pos(1);
            scannerZ = pos(2);
            obj.zAlignment.removePoint(-refZ);
            alignmentCompensation = obj.interpolateAlignment(scannerZ);
            if isempty(alignmentCompensation)
                alignmentCompensation = eye(3);
            end
            obj.zAlignment = obj.zAlignment.addPoint(-refZ,scannerZ,alignmentCompensation);            
            obj.redraw();
        end
        
        function readCurrentPosition(obj)
            motorPos = obj.getReferenceMotorPositionRelative();
            scannerPos = obj.getScannerPosition();
            obj.currentPosition = [motorPos,scannerPos];
        end
        
        function updateScanner(obj)
            refZ = obj.currentPosition(1);
            scannerZ = obj.interpolateScannerPos(refZ);
            if ~isempty(scannerZ)
                alignment = obj.interpolateAlignment(scannerZ);
                obj.moveScannerPosition(scannerZ);
                switch lower(obj.scanner)
                    case 'fastz'
                        % No-op
                    case 'slm'
                        obj.setVideoToImTransform(alignment);
                    otherwise
                        error('Unknown scanner: %s',obj.scanner);
                end                
                obj.currentPosition(2) = scannerZ;
            end
            obj.redraw();
        end
        
        function scannerPos = interpolateScannerPos(obj,refPos)
            if isempty(obj.zAlignment.refZ) || isscalar(obj.zAlignment.refZ)
                scannerPos = [];
            else
                scannerPos = obj.zAlignment.interpolateZ(-refPos);
            end
        end
        
        function alignment = interpolateAlignment(obj,scannerZ)
            if isempty(obj.zAlignment.refZ)
                alignment = [];
            elseif isscalar(obj.zAlignment.refZ)
                alignment = obj.zAlignment.alignmentCompensation(:,:,1);
            else
                alignment = obj.zAlignment.interpolateAlignment(scannerZ);
            end
        end
        
        function setVideoToImTransform(obj,T)
            if ~isempty(T)
                obj.hVideoImToRefImListener.Enabled = false;
                hAlignmentControls = obj.hController.hGuiClasses.AlignmentControls;
                hAlignmentControls.videoImToRefImTransform = T;
                obj.hVideoImToRefImListener.Enabled = true;
            end
        end
        
        function updateAlignmentText(obj)
            str = '';
            
            if ~isempty(obj.currentPosition) && ~isnan(obj.currentPosition(2))
                alignment = obj.interpolateAlignment(obj.currentPosition(2));
                if ~isempty(alignment)
                    str = sprintf('Lateral Alignment: %s',mat2str(alignment));
                end
            end
            
            obj.hTxtAlignment.String = str;
        end
        
        function showAlignmentWindow(obj)
            obj.hController.showGUI('AlignmentControls');
            obj.hController.raiseGUI('AlignmentControls');
            hGuiClasses_ = obj.hController.hGuiClasses;
            hGuiClasses_.AlignmentControls.showWindow = true;
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct();
end

%--------------------------------------------------------------------------%
% ZAlignmentControls.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
