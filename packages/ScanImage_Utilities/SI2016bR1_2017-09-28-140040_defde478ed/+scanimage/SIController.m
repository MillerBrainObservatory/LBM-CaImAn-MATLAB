classdef SIController < most.Controller & scanimage.interfaces.Class
    % SIController Controller class for the ScanImage application
    %   handles ScanImage GUI bindings
    
    %% USER PROPS
    properties
        beamDisplayIdx=1;                   % Index of beam whose properties are currently displayed/controlled
        enablePhotostimHotkeys = false;     % enable hotkeys for on demand photostim while that gui is in the foreground
        hConfigEditor;
        pzCustomHistory = [0];                    % Keeps track of custom pz settings to deal with errors
    end
    
    properties (Hidden)
        % Legacy properties, might be removed in future version
        channelsTargetDisplay;              % A value indicating 'active' channel display, or Inf, indicating the merge display figure. If empty, no channel is active.
        lastZoomOnes = 1;
        lastZoomTens = 0;
        lastZoomFrac = 0;
    end
    
    %%% Read-only sub-controller handles
    %properties (SetAccess=immutable,Transient)
    properties (Hidden)
        hCycleManagerCtrl;
        hConfigEditorLis;
        openedBef = false;
    end

    %% FRIEND PROPS
    properties (Hidden)
        defaultGuis = {};                   % cell array of guis that are displayed by default on startup
        motorStepSize = [0.1 0.1 0.1 0.1];  %Step size to use, in um, for motor increment/decrement operations in X,Y,Z axes. Z axis value pertains to active Z controller, if secondary is present.
        pbIdx;
        hCycleWaitTimer;
        tfMap = containers.Map({true false}, {'on' 'off'});
    end
    
    properties (Hidden, Dependent,SetAccess={?scanimage.interfaces.Class})
        mainControlsStatusString;
    end
    
    properties (Hidden, SetAccess=?scanimage.interfaces.Class)
        beamProp2Control;       %Scalar struct. Fields: SI beam property name. values: uicontrol handle arrays for that prop. The properties in this struct must be beam-indexed (with round brackets).
        waitCursorProps = {'acqInitInProgress' 'hPhotostim.initInProgress'};
        cancelStart = false;
    end
    
    %% INTERNAL PROPS
    properties (SetAccess=private,Hidden)
        motorListeners = [];
        addedPaths = {};                % cell array of paths that were added to the Matlab search path by scanimage
        initComplete = false;
        stimRoiGroupNameListeners = {};
        
        pshk_zeroshit = 0;              % love this variable name.
        temp_fname;
    end
    
    properties (Constant,Hidden)
        motorMaxNumUserDefinedPositions = 100;
        WINDOW_BORDER_SPACING = 8; % [pixels] space between tethered guis
    end
    
    properties(Hidden,SetAccess=private)
        usrSettingsPropListeners; % col vec of listener objects used for userSettingsV4
        hSliderListener = [];
        hWaitCursorListeners = [];
        
        hPowbAx;
        hPowbCtxIm;
        hPowbBoxSurf;
        hPowbBoxTL;
        hPowbBoxTR;
        hPowbBoxBL;
        hPowbBoxBR;
        hPowbBoxT;
        hPowbBoxB;
        hPowbBoxL;
        hPowbBoxR;
        hPowbBoxCtr;
        hText;
        hPowbOthers;
        hOthTexts;
        
        hFastZTuneFig;
        hFastZTuneAxes;
        hFastZDesiredWvfmPlot;
        hFastZPlotLines;
        hFastZCmdSigPlot;
        hFastZResponsePlot;
        
        hPmtListener = [];
        gPowers;
        gGains;
        gTrips;
        gOffs;
        gBands;
    end
    
    properties(Hidden,Dependent,SetAccess=private)
        hMainPbFastCfg;  % 6x1 vector of MainControls fastCfg buttons
    end
    
    %%% USER FUNCTION RELATED PROPERTIES
    properties(Hidden,Dependent)
        userFunctionsViewType; % string enum; either 'CFG', 'USR', or 'none'.
        userFunctionsCurrentEvents;
        userFunctionsCurrentProp;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.Controller)
    properties (SetAccess=protected)
        propBindings = [];
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = SIController(hModel)
            baseDirectory = fileparts(which('scanimage'));
            requiredPaths{1} = fullfile(baseDirectory, 'guis');
            requiredPaths{2} = fullfile(baseDirectory, 'guis', 'icons');
            addedPaths_ = most.idioms.addPaths(requiredPaths);
            
            visibleGuis = {'mainControlsV4' 'configControlsV4' 'imageControlsV4' 'channelControlsV4' 'scanimage.guis.statuswindow.StatusWindow'};
            hiddenGuis = {'motorControlsV5' 'posnControlsV5' 'fastZControlsV4' 'powerControlsV4'...
                'fastConfigurationV4' 'userFunctionControlsV4' 'triggerControlsV5' 'userSettingsV4'...
                'photostimControlsV5' 'pmtControlsV5' 'powerBoxControlsV4' 'waveformControls'...
                'scanimage.guis.ScanfieldDisplayControls' 'scanimage.guis.RoiGroupEditor'...
                'integrationRoiOutputChannelControlsV5' 'roiIntegratorDisplay'...
                'scanimage.guis.AlignmentControls' 'motorsAlignmentControls' 'motionCorrectionControls'...
                'slmControls','scanimage.guis.SlmCalibrationControls','slmAlignmentControls','scanimage.guis.slmZAlignmentControls'};
            
            hiddenGuis(cellfun(@(x)~exist(x),hiddenGuis)) = [];
            allGuis = union(visibleGuis, hiddenGuis);
            
            for i = 1:numel(hModel.OptionalComponents)
                compName = hModel.OptionalComponents{i};
                if isprop(hModel.(compName), 'guis') && ~isempty(hModel.(compName).guis)
                    allGuis = union(allGuis, hModel.(compName).guis);
                    visibleGuis = [visibleGuis hModel.(compName).guis];
                end
            end
            obj = obj@most.Controller(hModel,{},unique(allGuis));
            obj.addedPaths = addedPaths_; % this call has to occur after the superclass constructor
            obj.defaultGuis = visibleGuis;
            
            obj.hCycleWaitTimer = timer('Name','Cycle Wait Timer');
            obj.hCycleWaitTimer.StartDelay = 0.1;
            obj.hCycleWaitTimer.TimerFcn = @obj.updateCycleWaitStatus;
            obj.hCycleWaitTimer.ExecutionMode = 'fixedSpacing';
            %Capture keypresses for FastCfg F-key behavior. At moment, set
            %KeyPressFcn for all figures, uicontrols, etc so that all
            %keypresses over SI guis are captured. This can be modified
            %if/when certain figures/uicontrols need their own KeyPressFcns.
            structfun(@(handles)obj.ziniSetKeyPressFcn(handles),obj.hGUIData);
            
            %GUI Initializations
            obj.ziniMainControls();
            obj.ziniConfigControls();
            obj.ziniImageControls();
            obj.ziniPowerControls();
            obj.ziniPowerBoxControls();
            obj.ziniPmtControls();
            obj.ziniMotorControls();
            obj.ziniPosnControls();
            obj.ziniUsrSettingsGUI();
            obj.ziniTriggers();
            obj.ziniFastZControls();
            obj.ziniChannelControls();
            obj.ziniRegisterFigs();
            obj.ziniRoiIntegratorsDisplay();
            obj.ziniIntegrationRoiOutputChannelControls();
            obj.ziniPhotostimControls();
            obj.ziniMotionCorrectionControls();
            obj.ziniSlmControls();

            obj.hCycleManagerCtrl = scanimage.guis.CycleManagerController(hModel.hCycleManager);
            obj.registerGUI(obj.hCycleManagerCtrl.view.gui);
            
            obj.pzCustomHistory = repmat(obj.pzCustomHistory, 1, obj.hModel.hBeams.totalNumBeams);
            
            %Listener Initializations
            for i = 1:numel(obj.waitCursorProps)
                lobj = obj.hModel;
                c = strsplit(obj.waitCursorProps{i}, '.');
                if numel(c) > 1
                    for j = 1:numel(c)-1
                        lobj = lobj.(c{j});
                    end
                end
                obj.hWaitCursorListeners{end+1} = addlistener(lobj,c{end},'PostSet',@(varargin)waitCursorUpdate);
            end
            obj.hWaitCursorListeners = [obj.hWaitCursorListeners{:}];
            
            %Initialize controller properties with set-access side-effects
            obj.motorStepSize = obj.motorStepSize;
            
            function waitCursorUpdate
                persistent curscache
                wt = cellfun(@(x)evalin('caller',x),strcat('obj.hModel.', obj.waitCursorProps));
                if any(wt)
                    if isempty(curscache)
                        nms = fieldnames(obj.hGUIs);
                        for k = 1:numel(nms)
                            try
                                curscache.(nms{k}) = get(obj.hGUIs.(nms{k}), 'pointer');
                            catch
                            end
                        end
                    end
                    set(obj.hGUIsArray, 'pointer', 'watch');
                    drawnow
                else
                    if ~isempty(curscache)
                        nms = fieldnames(curscache);
                        for k = 1:numel(nms)
                            try
                                set(obj.hGUIs.(nms{k}), 'pointer', curscache.(nms{k}));
                            catch
                            end
                        end
                    end
                    
                    drawnow
                    curscache = [];
                end
            end
        end
        
        function initialize(obj,varargin)
            if most.idioms.isValidObj(obj.hConfigEditor)
                obj.hConfigEditor.Visible = false;
                obj.hConfigEditor.isWizardMode = false;
                obj.hConfigEditorLis = obj.hConfigEditor.addlistener('mdfUpdate', @obj.mdfUpdate);
            end
            
            initialize@most.Controller(obj);
            
            %Load user file (which adjusts figure positions). If no user
            %file is loaded raise default guis in default positions
            if ~obj.hModel.hConfigurationSaver.usrLoadUsr(varargin{:})
                obj.ziniFigPositions();
                cellfun(@(gui)obj.showGUI(obj.hGUIs.(regexp(gui,'[^\.]*$','match','once'))),obj.defaultGuis);
                arrayfun(@(figNum)figure(obj.hModel.hDisplay.hFigs(figNum)),obj.hModel.hChannels.channelDisplay);
            end
            
            %Do final pass of row labelling on channels GUI.
            obj.hGUIData.channelControlsV4.pcChannelConfig.resize(obj.hModel.hChannels.channelsAvailable);
            
            %Set status window to be on top
%             statusWindow = obj.hGuiClasses.StatusWindow;
%             statusWindow.stayOnTop = true;
            
            %Mark initialization as complete.
            obj.initComplete = true;
            
            obj.hModel.hUserFunctions.notify('applicationOpen');
        end
        
        function exit(obj)
            obj.hModel.exit();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFastZTuneFig);
            most.idioms.safeDeleteObj(obj.hCycleManagerCtrl);
            most.idioms.safeDeleteObj(obj.hCycleWaitTimer);
            delete@most.Controller(obj);
            most.idioms.safeDeleteObj(obj.hSliderListener);
            most.idioms.safeDeleteObj(obj.hWaitCursorListeners);
            most.idioms.safeDeleteObj(obj.motorListeners);
            most.idioms.safeDeleteObj(obj.hPmtListener);
            most.idioms.safeDeleteObj(obj.hConfigEditor);
            most.idioms.safeDeleteObj(obj.hConfigEditorLis);
            cellfun(@(lh)most.idioms.safeDeleteObj(lh),obj.stimRoiGroupNameListeners);
            % most.idioms.removePaths(obj.addedPaths);
        end
        
        function resetScanImage(obj)
            ans_ = questdlg('ScanImage needs to exit to reset. Do you want to proceed?',...
                'Exit ScanImage Confirmation','Yes','No','No');
            if strcmpi(ans_,'No')
                return; %Abort this exit function
            end
            classDataDir_ = obj.hModel.classDataDir; % obj.exit will delete the model cache the classDataDir property
            obj.exit()
            scanimage.util.resetClassDataFiles(classDataDir_);
        end
        
        function resetDaqDevices(obj)
            ans_ = questdlg('ScanImage needs to exit to reset all NI DAQ devices. Do you want to proceed?',...
                'Exit ScanImage Confirmation','Yes','No','No');
            if strcmpi(ans_,'No')
                return; %Abort this exit function
            end
            obj.exit()
            scanimage.util.resetDaqDevices();
        end
        
        function ziniChannelControls(obj)
            %obj.hGUIData.channelControlsV4.pcChannelConfig.resize(obj.hModel.MAX_NUM_CHANNELS);
            %numChan = obj.hModel.hScan2D.channelsAvailable;
            numChan = obj.hModel.hChannels.channelsAvailable;
            
           obj.hGUIData.channelControlsV4.pcChannelConfig.resize(numChan);
           obj.hGUIData.channelControlsV4.channelImageHandler.initColorMapsInTable(); % re-init to deal with resize

            % set the input ranges to the available ranges of hScan2D
            cellNumRanges = obj.hModel.hChannels.channelAvailableInputRanges;
            cellStringRanges = cellfun(@(numRange)sprintf('[%s %s]',num2str(numRange(1)),num2str(numRange(2))),cellNumRanges,'UniformOutput',false);

            hTable = obj.hGUIData.channelControlsV4.tblChanConfig;
            colFormat = get(hTable,'ColumnFormat');
            colFormat{3} = cellStringRanges;
            set(hTable,'ColumnFormat',colFormat);
                    
            % This re-registers figure windows with specific channels in the channel window. Not sure what this does
            % as virtually everything is handled via most MVC. Why change
            % use numChan?
            %
            %obj.hModel.hDisplay.prepareDisplayFigs();
            obj.hGUIData.channelControlsV4.channelImageHandler.registerChannelImageFigs(obj.hModel.hDisplay.hFigs(1:numChan));
            % obj.hGUIData.channelControlsV4.channelImageHandler.registerChannelImageFigs(obj.hModel.hDisplay.hFigs);
        end
        
        function ziniFigPositions(obj)
%             movegui(obj.hGUIs.mainControlsV4,'northwest');
%             drawnow expose % otherwise the main gui is not always moved to the correct position
            most.gui.tetherGUIs([],obj.hGUIs.mainControlsV4,'northwest',[]);
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4,obj.hGUIs.configControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.mainControlsV4,obj.hGUIs.imageControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.configControlsV4,obj.hGUIs.channelControlsV4,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.imageControlsV4,obj.hGUIs.powerControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.imageControlsV4,obj.hGUIs.motorControlsV5,'righttop',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.motorControlsV5,obj.hGUIs.fastZControlsV4,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.fastZControlsV4,obj.hGUIs.pmtControlsV5,'bottomleft',obj.WINDOW_BORDER_SPACING);
            most.gui.tetherGUIs(obj.hGUIs.motorControlsV5,obj.hGUIs.photostimControlsV5,'righttop',obj.WINDOW_BORDER_SPACING);
            
            % stack channel display figures
            initialPosition = [700 300];
            offset = 30;
            numFigs = length(obj.hModel.hDisplay.hFigs);
            for i = 1:numFigs
                figNum = numFigs - i + 1;
                offset_ = offset * (i-1);
                position = [initialPosition(1)+offset_, initialPosition(2)-offset_];
                setpixelposition(obj.hModel.hDisplay.hFigs(figNum),[position(1,:) 408 408]);
            end
            setpixelposition(obj.hModel.hDisplay.hMergeFigs,[700 250 490 490]);     %Invisible by default
        
            % ensure no figure is located outside the visible part of the screen
            allFigs = [obj.hGUIsArray(:)' obj.hModel.hDisplay.hFigs(:)' obj.hModel.hDisplay.hMergeFigs(:)'];
            for hFig = allFigs
               most.gui.moveOntoScreen(hFig);
            end
        end
        
        function ziniRegisterFigs(obj)
            % makes channel windows 'managed' figures so that they are
            % saved in the user settings file
            for i = 1:obj.hModel.hChannels.channelsAvailable
                hFig = obj.hModel.hDisplay.hFigs(i);
                obj.registerGUI(hFig);
            end
%             keyboard
%             for hDisp = obj.hModel.hDisplay.scanfieldDisplays
%                 obj.registerGUI(hDisp.hFig);
%             end
            obj.registerGUI(obj.hModel.hDisplay.hMergeFigs);
        end
        
        function ziniRoiIntegratorsDisplay(obj)
            obj.hGUIData.roiIntegratorDisplay.hDisplay;
        end
        
        function updateIntegrationRoiDisplay(obj,hIntegrationRois,integrationValues,timestamps)
            obj.hGUIData.roiIntegratorDisplay.hDisplay.updateDisplay(hIntegrationRois,integrationValues,timestamps)
        end
        
        function ziniIntegrationRoiOutputChannelControls(obj)
            if obj.hModel.hIntegrationRoiManager.numInstances <= 0
                set(obj.hGUIs.integrationRoiOutputChannelControlsV5,'Visible','off');
                return
            end
            
            channelNames = {obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels.channelName};
            if isempty(channelNames)
                set(obj.hGUIs.integrationRoiOutputChannelControlsV5,'Visible','off');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String',{''});
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value',1);
                return
            end
            
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String',channelNames);
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value',1);
            obj.changedIntegrationRoiOutputChannel();
        end
        
        function hChannel = getCurrentlyEditedRoiOutputChannel(obj)        
            strings = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'String');
            val = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.pmOutputChannel,'Value');
            name = strings{val};
            
            channelNames = {obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels.channelName};
            [~,idx] = ismember(name,channelNames);
            
            if idx > 0
                hChannel = obj.hModel.hIntegrationRoiManager.hIntegrationRoiOutputChannels(idx);
            else
                hChannel = [];
            end
        end
        
        function changedIntegrationRoiOutputChannel(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            
            if isempty(hChannel)
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.cbEnableOutput,'Value',false);
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.etOutputFunction,'String','');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.outputParameterGroup,'Title','');
                set(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'Data',{},'UserData',[]);
                return
            end
            
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.cbEnableOutput,'Value',hChannel.enable);
            if isempty(hChannel.outputFunction)
                functionstring = '';
            else
                functionstring = func2str(hChannel.outputFunction);
            end
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.etOutputFunction,'String',functionstring);
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.outputParameterGroup,'Title',sprintf('%s output on %s',hChannel.outputMode,hChannel.physicalChannelName));
            
            rois = obj.hModel.hIntegrationRoiManager.roiGroup.rois;
            roiNames = {obj.hModel.hIntegrationRoiManager.roiGroup.rois.name};
            [~,idx] = ismember(hChannel.hIntegrationRois,rois);
            roisSelected = false(1,length(rois));
            if ~isequal(idx,0)
                roisSelected(idx) = true;
            end
            roisSelected = num2cell(roisSelected);
            
            tblData = horzcat(roisSelected',roiNames');
            set(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'Data',tblData,'UserData',rois);
        end
        
        function changeIntegrationRoiOutputChannelRoiSelection(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            
            if isempty(hChannel)
                obj.changedIntegrationRoiOutputChannel();
                return
            end
            
            tblData = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'Data');
            roiSelection = [tblData{:,1}];
            rois = get(obj.hGUIData.integrationRoiOutputChannelControlsV5.tbRoiSelection,'UserData');
            hChannel.hIntegrationRois = rois(roiSelection);
        end
        
        function changeIntegraionRoiOutputChannelEnable(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            if isempty(hChannel)
                obj.changedIntegrationRoiOutputChannel();
                return
            end
            
            hChannel.enable = logical(get(obj.hGUIData.integrationRoiOutputChannelControlsV5.cbEnableOutput,'Value'));
        end
        
        function editIntegrationRoiOutputChannelFunction(obj,varargin)
            hChannel = obj.getCurrentlyEditedRoiOutputChannel();
            if isempty(hChannel)
                obj.changedIntegrationRoiOutputChannel();
                return
            end
            
            prompt = 'Function editor';
            name = 'Function call';
            numlines = [1,100];
            defaultans = {func2str(hChannel.outputFunction)};
            answer = inputdlg(prompt,name,numlines,defaultans);
            if isempty(answer)
                % user clicked cancel
            else
                hChannel.outputFunction = answer{1};
            end
        end
        
        function zcbkKeyPress(obj,~,evt)
            % Currently this handles keypresses for all SI guis
            switch evt.Key
                % Keys that should be captured over all guis go in this top level case structure
                case {'f1' 'f2' 'f3' 'f4' 'f5' 'f6'}
                    idx = str2double(evt.Key(2));
                    tfRequireCtrl = get(obj.hGUIData.fastConfigurationV4.cbRequireControl,'Value');
                    tfLoadFastCfg = ~tfRequireCtrl || ismember('control',evt.Modifier);
                    tfBypassAutoStart = ismember('shift',evt.Modifier);
                    if tfLoadFastCfg
                        obj.hModel.hConfigurationSaver.fastCfgLoadConfig(idx,tfBypassAutoStart);
                    end
                    
                % Gui specific keys
                otherwise
                    [tf, i] = ismember(gcf, obj.hGUIsArray);
                    if tf
                        switch obj.guiNames{i}
                            case 'photostimControlsV5'
                                obj.photostimHotKey(evt.Key);
                        end
                    end
            end
        end
        
        function ziniSetKeyPressFcn(obj,handles)
            tags = fieldnames(handles);
            for c = 1:numel(tags)
                h = handles.(tags{c});
                if isprop(h,'KeyPressFcn')
                    set(h,'KeyPressFcn',@(src,evt)obj.zcbkKeyPress(src,evt));
                end
            end
        end
        
        function ziniMainControls(obj)
            %Disable controls for currently unimplemented features
            disabledControls = {'stCycleIteration' 'stCycleIterationOf' ...
                'etIterationsDone' 'etIterationsTotal' ...
                'tbCycleControls' 'pbLastLineParent' ...
                'centerOnSelection' 'zoomhundredsslider' ...
                'zoomhundreds' 'pbLastLine' ...
                'pbBase' 'pbSetBase' 'pbRoot'};
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledControls);
            
            hiddenControls = {'xstep' 'ystep'};
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Visible','off'),hiddenControls);
            
            %Disable menu items for currently unimplemented features
            disabledMenuItems = {};
            
            % View MenuChannel 1 is never disabled.
            viewMenuChannelsEnabled = {};
            
            switch (obj.hModel.hChannels.channelsAvailable)
                case {1}
                    disabledMenuItems = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                case {2}
                    disabledMenuItems = {'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display'};
                case {3}
                    disabledMenuItems = {'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display'};
               case {4}
                   viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
            end
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','on'),viewMenuChannelsEnabled);
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),disabledMenuItems);
            set(obj.hGUIData.mainControlsV4.figure1,'closeRequestFcn',@lclCloseEventHandler);

			%+++
            set(obj.hGUIData.mainControlsV4.mnu_Settings_YokeWS,'Checked','off');
            
            function lclCloseEventHandler(src,evnt)
                ans_ = questdlg('Are you sure you want to exit ScanImage?','Exit ScanImage Confirmation','Yes','No','No');
                if strcmpi(ans_,'No')
                    return; %Abort this exit function
                end
                set(src,'CloseRequestFcn',[]); % User clicked yes, don't ask again even if exit fails
                obj.exit();
            end
        end
        
        function ziniConfigControls(obj)
                      
            %Configure imaging system list
            nms = cellfun(@(x)x.name,obj.hModel.hScanners, 'UniformOutput', false);
            set(obj.hGUIData.configControlsV4.pmImagingSystem, 'string', nms);
            
            set(obj.hGUIData.configControlsV4.pmScanType, 'string',{'Frame Scan', 'Line Scan'});
            
            %Hide controls not used
            hideControls = {'rbScanPhaseHardware'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Visible','off'), hideControls);
            
            %Disable controls with features not supported
            disableControls = {'rbScanPhaseSoftware'};
            cellfun(@(s)set(obj.hGUIData.configControlsV4.(s),'Enable','off'), disableControls);
            
            %fix issue with last item in popup list
            itms = get(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string');
            itms{end} = strtrim(itms{end});
            set(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string', itms);
            
            %Set properties of line phase slider
            obj.cfgLinePhaseSlider();
            obj.changedLineRateVar();
           
        end % function - ziniConfigControls
        
        function ziniImageControls(obj)            
            %Initialize channel LUT controls
            for i=1:4
                if i > obj.hModel.hChannels.channelsAvailable %Disable controls for reduced channel count devices
                    set(findobj(obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i)),'Type','uicontrol'),'Enable','off');
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',0,'Max',1,'SliderStep',[.01 .1],'Value',0);
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',i)),'String',num2str(0));
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',i)),'String',num2str(100));
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',i)), 'Enable', 'off');
                else
                    %Allow 10-percent of negative range, if applicable
                    set(findobj(obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i)),'Type','uicontrol'),'Enable','on');
                    chanLUTMin = round(obj.hModel.hChannels.channelLUTRange(1) * 0.1);
                    chanLUTMax = obj.hModel.hChannels.channelLUTRange(2);
                    blackVal = max(chanLUTMin,obj.hModel.hChannels.channelLUT{i}(1));
                    whiteVal = min(chanLUTMax,obj.hModel.hChannels.channelLUT{i}(2));
                    set(obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',i)),'Min',chanLUTMin,'Max',chanLUTMax,'SliderStep',[.001 .05],'Value',blackVal);
                    set(obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',i)),'Min',chanLUTMin,'Max',chanLUTMax,'SliderStep',[.001 .05],'Value',whiteVal);
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',i)), 'Enable', 'on');
                end
            end
            
            %JLF Tag -- Why is this line here?? Edit for 3rd Option.
            set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'string',{'3D', 'Tiled', 'Current', 'Max'});
            
            %Move Frame Averaging/Selection panel up if there are 2 or less channels
            if obj.hModel.MAX_NUM_CHANNELS <= 2
                charShift = (obj.hModel.MAX_NUM_CHANNELS - 2) * 5;
                
                for i=3:obj.hModel.MAX_NUM_CHANNELS
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Visible','off');
                    set(findall(hPnl),'Visible','off');
                end
                
                for i=1:2
                    hPnl = obj.hGUIData.imageControlsV4.(sprintf('pnlChan%d',i));
                    set(hPnl,'Position',get(hPnl,'Position') + [0 -charShift 0 0]);
                end
                
                hFig = obj.hGUIs.imageControlsV4;
                set(hFig,'Position',get(hFig,'Position') + [0 charShift 0 -charShift]);
            end
            
        end
        
        function ziniPowerControls(obj)
            hAx = obj.hGUIData.powerControlsV4.axPowerZProfile;
            grid(hAx,'on');
            hAx.NextPlot = 'add';
            hAx.Box = 'on';
            xlabel(hAx,'z (um)')
            ylabel(hAx,'Power (%)')
            hAx.XLim = [0 10];
            hAx.YLim = [0 105];
            
            obj.toggleShowPowerZProfile(false);
            
            if obj.hModel.hBeams.numInstances
                znstConnectBeamPropToBeamControl('powers',[findobj(obj.hGUIs.powerControlsV4,'Tag','etBeamPower');...
                    findobj(obj.hGUIs.powerControlsV4,'Tag','sldBeamPower')]);
                znstConnectBeamPropToBeamControl('powerLimits',[findobj(obj.hGUIs.powerControlsV4,'Tag','etMaxLimit');...
                    findobj(obj.hGUIs.powerControlsV4,'Tag','sldMaxLimit')]);
                znstConnectBeamPropToBeamControl('lengthConstants',findobj(obj.hGUIs.powerControlsV4,'Tag','etZLengthConstant'));
                znstConnectBeamPropToBeamControl('pzAdjust',findobj(obj.hGUIs.powerControlsV4,'Tag','cbPzAdjust'));
                znstConnectBeamPropToBeamControl('directMode',findobj(obj.hGUIs.powerControlsV4,'Tag','cbDirectMode'));
                znstConnectBeamPropToBeamControl('interlaceDecimation',findobj(obj.hGUIs.powerControlsV4,'Tag','etInterlaceDecimation'));
                znstConnectBeamPropToBeamControl('interlaceOffset',findobj(obj.hGUIs.powerControlsV4,'Tag','etInterlaceOffset'));
                set(obj.hGUIData.powerControlsV4.pumBeamIdx,'Value',1);
                set(obj.hGUIData.powerControlsV4.pumBeamIdx,'String',obj.hModel.hBeams.displayNames);
                obj.beamDisplayIdx = 1;
                obj.defaultGuis{end+1} = 'powerControlsV4';
            else
                most.gui.enableAll(obj.hGUIs.powerControlsV4,'off');
            end
            
            %TODO: Support this 'dynamic' binding of control to a property as a Controller method OR support a Pcontrol for binding to array vals with display/control of 1 index at a time determined by an index control
            function znstConnectBeamPropToBeamControl(propName,hControls)
                propName = sprintf('hBeams___%s',propName);
                obj.beamProp2Control.(propName) = hControls;
                set(hControls,'UserData',propName);
            end
        end
        
        function ziniPowerBoxControls(obj)            
            if obj.hModel.hBeams.numInstances
                if ~most.idioms.isValidObj(obj.hPowbAx)
                    obj.hPowbAx = obj.hGUIData.powerBoxControlsV4.axBoxPos;
                    set(obj.hPowbAx,'XLim',[0 1],'YLim',[0 1],'ButtonDownFcn',@(varargin)obj.powbPanFcn(true))
                    obj.hPowbCtxIm = surface([0 1],[0 1],zeros(2),'Parent',obj.hPowbAx,'Hittest','off','FaceColor','texturemap',...
                        'CData',zeros(2,2,3),'EdgeColor','none','FaceLighting','none','FaceAlpha',1);
                    obj.hPowbBoxSurf = surface([.25 .75],[.25 .75],ones(2),'Parent',obj.hPowbAx,'Hittest','off','FaceColor','r',...
                        'EdgeColor','none','FaceLighting','none','FaceAlpha',0.2);
                    
                    args = {'Parent',obj.hPowbAx,'ZData',2,'Color','r','Hittest','on','Marker','.','MarkerSize',25};
                    obj.hPowbBoxTL = line('XData',.25,'YData',.25,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 1 0 0],true),args{:});
                    obj.hPowbBoxTR = line('XData',.75,'YData',.25,'ButtonDownFcn',@(varargin)obj.powbCpFunc([0 1 1 0],true),args{:});
                    obj.hPowbBoxBL = line('XData',.25,'YData',.75,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 0 0 1],true),args{:});
                    obj.hPowbBoxBR = line('XData',.75,'YData',.75,'ButtonDownFcn',@(varargin)obj.powbCpFunc([0 0 1 1],true),args{:});
                    obj.hPowbBoxCtr = line('XData',.5,'YData',.5,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 1 1 1],true),args{:});
                    obj.hText = text(.25,.25,2,'Power Box','Parent',obj.hPowbAx,'color','y','Hittest','off');
                    if obj.graphics2014b
                        obj.hText.PickableParts = 'none';
                    end
                    
                    args = {'Parent',obj.hPowbAx,'ZData',[1.5 1.5],'Color','r','Hittest','on','LineWidth',1.5,'ButtonDownFcn',@(varargin)obj.powbCpFunc([1 1 1 1],true)};
                    obj.hPowbBoxT = line('XData',[.25 .75],'YData',[.25 .25],args{:});
                    obj.hPowbBoxB = line('XData',[.25 .75],'YData',[.75 .75],args{:});
                    obj.hPowbBoxL = line('XData',[.25 .25],'YData',[.25 .75],args{:});
                    obj.hPowbBoxR = line('XData',[.75 .75],'YData',[.25 .75],args{:});
                    
                    set(obj.hGUIs.powerBoxControlsV4,'WindowScrollWheelFcn',@obj.powbScrollWheelFcn)
                end
                
                %hide unusable controls
                for iterChannels = 1:4
                    if iterChannels <= obj.hModel.hChannels.channelsAvailable
                        set(obj.hGUIData.powerBoxControlsV4.(sprintf('pbCopy%d',iterChannels)),'Enable','on');
                    else
                        set(obj.hGUIData.powerBoxControlsV4.(sprintf('pbCopy%d',iterChannels)),'Enable','off');
                    end
                end
                
                %power box dropdown
                nms = {};
                for pb = obj.hModel.hBeams.powerBoxes
                    nms{end+1} = pb.name;
                    if isempty(nms{end})
                        nms{end} = sprintf('Power Box %d', numel(nms));
                    end
                end
                nms{end+1} = 'New Power Box';
                set(obj.hGUIData.powerBoxControlsV4.pmPbSel,'String',nms);
                
                i = obj.pbIdx;
                if i <= numel(obj.hModel.hBeams.powerBoxes)
                    set([obj.hPowbBoxSurf obj.hPowbBoxTL obj.hPowbBoxTR obj.hPowbBoxBL obj.hPowbBoxBR obj.hText...
                        obj.hPowbBoxCtr obj.hPowbBoxT obj.hPowbBoxB obj.hPowbBoxL obj.hPowbBoxR],'visible','on');
                    set([obj.hGUIData.powerBoxControlsV4.etPowers...
                        obj.hGUIData.powerBoxControlsV4.etPosition],'enable','on');
                    set(obj.hGUIData.powerBoxControlsV4.pnPbSettings,'Title',['Power Box Settings (' nms{i} ')']);
                else
                    set([obj.hPowbBoxSurf obj.hPowbBoxTL obj.hPowbBoxTR obj.hPowbBoxBL obj.hPowbBoxBR obj.hText...
                        obj.hPowbBoxCtr obj.hPowbBoxT obj.hPowbBoxB obj.hPowbBoxL obj.hPowbBoxR],'visible','off');
                    set([obj.hGUIData.powerBoxControlsV4.etPowers...
                        obj.hGUIData.powerBoxControlsV4.etPosition],'enable','off');
                    set([obj.hGUIData.powerBoxControlsV4.etPowers...
                        obj.hGUIData.powerBoxControlsV4.etPosition],'string','');
                    set(obj.hGUIData.powerBoxControlsV4.pnPbSettings,'Title','Power Box Settings');
                end
            else
                most.gui.enableAll(obj.hGUIs.powerBoxControlsV4,'off');
            end
        end
        
        function ziniPmtControls(obj)
            numPmts = obj.hModel.hPmts.numPmts;
            if numPmts < 1
                most.gui.enableAll(obj.hGUIs.pmtControlsV5,'off');
            else
                %Leaving pmt names general for now
%                 for i = 1:numPmts
%                     stTag = sprintf('stPmt%d',i);
%                     pmtName = obj.hModel.hPmts.names{i};
%                     set(obj.hGUIData.pmtControlsV5.(stTag),'String',pmtName);
%                 end
                
                for i = numPmts+1:4                    
                    pbTag = sprintf('pbPmt%dPower',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                    
                    etTag = sprintf('etPmt%dGain',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'Enable','off');
                    
                    etTag = sprintf('etPmt%dOffset',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'Enable','off');
                    
                    etTag = sprintf('etPmt%dBandwidth',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'Enable','off');
                    
                    pbTag = sprintf('etPmt%dStatus',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                    
                    pbTag = sprintf('pbResetPmt%d',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                    
                    pbTag = sprintf('cbPmt%dAutoPwr',i);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Enable','off');
                end
                
                for i = 1:(min(numPmts,4))
                    stTag = sprintf('stPmt%d',i);
                    pmtName = obj.hModel.hPmts.names{i};
                    set(obj.hGUIData.pmtControlsV5.(stTag),'String',pmtName);
                end
                
                % listen for updates
                obj.gPowers = nan(1, numPmts);
                obj.gGains = nan(1, numPmts);
                obj.gTrips = nan(1, numPmts);
                obj.gOffs = nan(1, numPmts);
                obj.gBands = nan(1, numPmts);
                obj.changedPmtsStatus();
                obj.hPmtListener = obj.hModel.hPmts.addlistener('statusChanged', @obj.changedPmtsStatus);
                obj.defaultGuis{end+1} = 'pmtControlsV5';
            end
        end
        
        function ziniMotorControls(obj)
            %Disable all if motor is disabled
            if obj.hModel.hMotors.numInstances <= 0
                most.gui.enableAll(obj.hGUIs.motorControlsV5,'off');
                return;
            end
            
            listners = event.listener.empty(1,0);
            
            
            obj.switchMotorConfig();
            
            % todo: support failure of motor to init at startup and init later
            set(obj.hGUIData.motorControlsV5.pbLSCInit,'Visible','off');
            
            %initialize listeners
            for hMtr = obj.hModel.hMotors.hMotor
                listners(end+1) = hMtr.addlistener('LSCError',@(src,evt)obj.motorErrorCbk(src,evt));
            end
            for hMtr = obj.hModel.hFastZ.hStages
                listners(end+1) = hMtr.addlistener('LSCError',@(src,evt)obj.motorErrorCbk(src,evt));
            end
            
            listners(end+1) = obj.hModel.hUserFunctions.addlistener('motorPositionUpdate',@(src,evnt)obj.changedMotorPosition);
            
            if numel(obj.hModel.hMotors.hMotor) || obj.hModel.hFastZ.numInstances
                obj.defaultGuis{end+1} = 'motorControlsV5';
            end
            obj.motorListeners = listners;
        end
        
        function switchMotorConfig(obj)
            if obj.hModel.hMotors.numInstances
                if obj.hModel.hFastZ.hasFastZ
                    set(obj.hGUIData.motorControlsV5.pbZeroXY,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.pbZeroZ,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.pbAltZeroXY,'Visible','on');
                    set(obj.hGUIData.motorControlsV5.pbAltZeroZ,'Visible','on');
                    set(obj.hGUIData.motorControlsV5.etPosZZ,'Visible','on');
                    set(obj.hGUIData.motorControlsV5.etPosZZTarget,'Visible','on');
                    
                    set(obj.hGUIData.motorControlsV5.etPosZZTarget,'Enable','on');
                    set(obj.hGUIData.motorControlsV5.cbSecZ,'Visible','on');
                    obj.changedFastZPosition();
                else
                    set(obj.hGUIData.motorControlsV5.pbZeroXY,'Visible','on');
                    set(obj.hGUIData.motorControlsV5.pbZeroZ,'Visible','on');
                    set(obj.hGUIData.motorControlsV5.pbAltZeroXY,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.pbAltZeroZ,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.cbSecZ,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.etPosZZ,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.etPosZZTarget,'Visible','off');
                    set(obj.hGUIData.motorControlsV5.etStepSizeZZ,'Enable','off');
                    set(obj.hGUIData.motorControlsV5.pbStepZZInc,'Enable','off');
                    set(obj.hGUIData.motorControlsV5.pbStepZZDec,'Enable','off');
                    set(obj.hGUIData.motorControlsV5.stStepZZ,'Enable','off');
                    set(obj.hGUIData.motorControlsV5.pbLSCInit,'Visible','off');
                end
            end
            
            if (numel(obj.hModel.hMotors.hMotor) && any([obj.hModel.hMotors.hMotor.lscErrPending])) || ...
                    (numel(obj.hModel.hFastZ.hStages) && any([obj.hModel.hFastZ.hStages.lscErrPending]))
                obj.motorErrorCbk();
            end
        end
        
        function ziniMotionCorrectionControls(obj)
            if most.util.gpuComputingAvailable 
                set(obj.hGUIData.motionCorrectionControls.cbGpuAcceleration,'Enable','on');
            else
                set(obj.hGUIData.motionCorrectionControls.cbGpuAcceleration,'Enable','off');
            end
        end
        
        function ziniSlmControls(obj)
            str = {};
            scanners = [];
            for scanner = obj.hModel.hScanners
                scanner = scanner{1};
                if isa(scanner,'scanimage.components.scan2d.SlmScan');
                    str{end+1} = scanner.name;
                    scanners = [scanners scanner];
                end
            end
            
            if isempty(scanners)
                most.gui.enableAll(obj.hGUIs.slmControls,'off');
                ctl = obj.hGUIData.mainControlsV4.mnu_View_SlmControls;
                ctl.Enable = 'off';
            else
                pmSlmSelect = obj.hGUIData.slmControls.pmSlmSelect;
                pmSlmSelect.String = str;
                pmSlmSelect.Value = 1;
                userData = struct('scanners',scanners);
                pmSlmSelect.UserData = userData;
                obj.changeSlmControlsScanner();
                
                obj.defaultGuis{end+1} = 'slmControls';
            end
        end
        
        function ziniPosnControls(obj)
            %Disable all if motor is disabled
            if obj.hModel.hMotors.numInstances <= 0
                most.gui.enableAll(obj.hGUIs.posnControlsV5,'off');
                return;
            else
                gd = obj.hGUIData.posnControlsV5;
                cbs = [gd.cbX gd.cbY gd.cbZ gd.cbZZ];
                nDims = numel(obj.hModel.hMotors.motorPosition);
                set(cbs(1:nDims), 'enable', 'on');
                set(cbs(nDims+1:end), 'enable', 'off');
                set(cbs(nDims+1:end), 'Value', false);
                set(gd.lbPosns, 'Value', 1);
            end
        end
        
        function ziniFastZControls(obj)
            if obj.hModel.hFastZ.numInstances
                obj.defaultGuis{end+1} = 'fastZControlsV4';
            end
            
            obj.changeFastZCfg();
            
            hiddenCtls = {'cbSpecifyZs' 'lblUserZs' 'etUserZs'};
            cellfun(@(s)set(obj.hGUIData.fastZControlsV4.(s),'Visible','off'),hiddenCtls);
        end
        
        function changeFastZCfg(obj)
            if obj.hModel.hFastZ.hasFastZ
                most.gui.enableAll(obj.hGUIs.fastZControlsV4,'on');
                if ~obj.hModel.hFastZ.hasFieldCurveCorrection
                    set(obj.hGUIData.fastZControlsV4.cbCurvatureCorrection, 'enable', 'off');
                end
            else
                most.gui.enableAll(obj.hGUIs.fastZControlsV4,'off');
            end
        end
        
        function ziniPhotostimControls(obj)
            set(obj.hGUIData.photostimControlsV5.pbSoftTrig,'Enable','off');
            set(obj.hGUIData.photostimControlsV5.pbSync,'Enable','off');
            if obj.hModel.hPhotostim.numInstances > 0
                set(obj.hGUIData.photostimControlsV5.pbStart,'Enable','on');
            else
                CtlNames = setdiff(fieldnames(obj.hGUIData.photostimControlsV5),...
                       {'output' 'hController' 'hModel' 'figure1' 'lbStimGroups' 'extStimSelPanel'...
                        'pbUp' 'pbDown' 'pbCopy' 'pbNew' 'pbEdit' 'pbDelete' 'text1' 'uipanel2'});
                Ctls = cellfun(@(s)obj.hGUIData.photostimControlsV5.(s), CtlNames, 'UniformOutput', false);
                cellfun(@(c)set(c,'Enable','off'), Ctls);
            end
        end
        
        function ziniTriggers(obj)
            set(obj.hGUIData.triggerControlsV5.pmTrigAcqInTerm,'String',obj.hModel.hScan2D.trigAcqInTermAllowed,'Value',1);
            set(obj.hGUIData.triggerControlsV5.pmTrigStopInTerm,'String',obj.hModel.hScan2D.trigStopInTermAllowed,'Value',1);
            set(obj.hGUIData.triggerControlsV5.pmTrigNextInTerm,'String',obj.hModel.hScan2D.trigNextInTermAllowed,'Value',1);
        end
        
        function ziniUsrSettingsGUI(obj)
            availableUsrProps = obj.hModel.mdlGetConfigurableProps()';
            % Throw a warning if any available user prop is not
            % SetObservable. This can happen b/c SetObservable-ness of usr
            % properties is required neither by the Model:mdlConfig
            % infrastructure nor by SI (this is arguably the right
            % thing to do). Meanwhile, the userSettings GUI provides a view
            % (via a propTable) into the current usrProps; this is
            % implemented via listeners. (Side note: ML silently allows
            % adding a listener to an obj for a prop that is not
            % SetObservable.)
            %
            % At the moment I believe all available usr props for SI3/4 are
            % indeed SetObservable, but this warning will be good for
            % maintenance moving forward.
            data(:,1) = sort(availableUsrProps); %#ok<TRSRT>
            data(:,2) = {false};                 %will get initted below
            set(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data',data);
            obj.changedUsrPropList();
        end
    end
    
    %% PROP ACCESS
    methods
        function viewType = get.userFunctionsViewType(obj)
            viewBtn = get(obj.hGUIData.userFunctionControlsV4.bgView,'SelectedObject');
            if ~isempty(viewBtn)
                switch get(viewBtn,'Tag')
                    case 'tbUsr'
                        viewType = 'USR';
                    case 'tbCfg'
                        viewType = 'CFG';
                end
            else
                viewType = 'none';
            end
        end
        
        function evtNames = get.userFunctionsCurrentEvents(obj)
            switch obj.userFunctionsViewType
                case 'none'
                    evtNames = cell(0,1);
                case 'CFG'
                    evtNames = unique(obj.hModel.hUserFunctions.userFunctionsEvents);
                case 'USR'
                    evtNames = unique([obj.hModel.hUserFunctions.userFunctionsEvents;...
                                     obj.hModel.hUserFunctions.userFunctionsUsrOnlyEvents]);
            end
        end
        
        function propName = get.userFunctionsCurrentProp(obj)
            switch obj.userFunctionsViewType
                case 'none'
                    propName = '';
                case 'CFG'
                    propName = 'userFunctionsCfg';
                case 'USR'
                    propName = 'userFunctionsUsr';
            end
        end
        
        function val = get.propBindings(obj)
            if isempty(obj.propBindings)
                obj.propBindings = lclInitPropBindings(obj.hModel);
            end
            
            val = obj.propBindings;
        end
        
        function val = get.pbIdx(obj)
            val = get(obj.hGUIData.powerBoxControlsV4.pmPbSel,'Value');
        end
        
        function set.pbIdx(obj,val)
            set(obj.hGUIData.powerBoxControlsV4.pmPbSel,'Value',val);
            obj.changedPowerBoxes();
        end
 
        function val = get.hMainPbFastCfg(obj)
            val = [obj.hGUIData.mainControlsV4.pbFastConfig1; ...
                obj.hGUIData.mainControlsV4.pbFastConfig2; ...
                obj.hGUIData.mainControlsV4.pbFastConfig3; ...
                obj.hGUIData.mainControlsV4.pbFastConfig4; ...
                obj.hGUIData.mainControlsV4.pbFastConfig5; ...
                obj.hGUIData.mainControlsV4.pbFastConfig6];
        end
        
        % This sets the GUI-displayed status string, NOT the hModel status string.
        function set.mainControlsStatusString(obj,val)
            set(obj.hGUIData.mainControlsV4.statusString,'String',val);
        end
        
        % This gets the GUI-displayed status string, NOT the hModel status
        % string.
        function val = get.mainControlsStatusString(obj)
            val = get(obj.hGUIData.mainControlsV4.statusString,'String');
        end
        
        %%% Beams
        function set.beamDisplayIdx(obj,val)
            if obj.hModel.hBeams.numInstances <= 0
                return;
            end
            
            assert(ismember(val,1:obj.hModel.hBeams.totalNumBeams));
            if val~=obj.beamDisplayIdx
                obj.beamDisplayIdx = val;
                beamPropNames = fieldnames(obj.beamProp2Control);
                for i = 1:numel(beamPropNames)
                   obj.changedBeamParams(beamPropNames{i});
                end
                
                set(obj.hGUIData.powerControlsV4.pumBeamIdx,'Value',val); %#ok<*MCSUP>
            end
            
            data = get(obj.hGUIData.powerControlsV4.tblBeams,'Data');
            data(:,1) = {false};
            data(val,1) = {true};
            set(obj.hGUIData.powerControlsV4.tblBeams,'Data',data);
        end
        
        %%% Motors
        function set.motorStepSize(obj,val)
            currVal = obj.motorStepSize;
            assert(numel(val) == numel(currVal),'The motorStepSize value must have %d elements',numel(currVal));
            
            %Only change dimensions with valid values (positive, finite, smaller than fastMotionThreshold)
            val(val <= 0 | val > obj.hModel.hMotors.motorFastMotionThreshold | isinf(val)) = nan;
            unchangedDims = isnan(val);
            val(unchangedDims) = currVal(unchangedDims);
            
            %Set property & update view
            obj.motorStepSize = val;
            
            set(obj.hGUIData.motorControlsV5.etStepSizeX,'String',num2str(val(1),'%0.5g'));
            set(obj.hGUIData.motorControlsV5.etStepSizeY,'String',num2str(val(2),'%0.5g'));
            set(obj.hGUIData.motorControlsV5.etStepSizeZ,'String',num2str(val(3),'%0.5g'));
            set(obj.hGUIData.motorControlsV5.etStepSizeZZ,'String',num2str(val(4),'%0.5g'));
        end
    end
    
    %% USER METHODS
    %%% ACTION CALLBACKS
    methods (Hidden)
        %%% MAIN %%%
        function focusButton(obj)
            if strcmpi(obj.hModel.acqState,'idle')
                try
                    obj.hModel.startFocus();

                    if obj.cancelStart
                        obj.cancelStart = false;
                        obj.hModel.abort();
                    end
                catch ME
                    warndlg(ME.message,'ScanImage');
                    rethrow(ME);
                end
            end
        end
        
        function grabButton(obj)
            if strcmpi(obj.hModel.acqState,'idle')
                try
                    obj.hModel.startGrab();

                    if obj.cancelStart
                        obj.cancelStart = false;
                        obj.hModel.abort();
                    end
                catch ME
                    warndlg(ME.message,'ScanImage');
                    rethrow(ME);
                end
            end
        end
        
        function loopButton(obj)
            if strcmpi(obj.hModel.acqState,'idle')
                try
                    if ~obj.hModel.hCycleManager.enabled
                        obj.hModel.startLoop();
                    else
                        obj.hModel.startCycle();
                    end

                    if obj.cancelStart
                        obj.cancelStart = false;
                        obj.hModel.abort();
                    end
                catch ME
                    warndlg(ME.message,'ScanImage');
                    rethrow(ME);
                end
            end
        end
        
        function abortButton(obj)
            if obj.hModel.hCycleManager.enabled
                obj.hModel.hCycleManager.abort();
            end

            if obj.hModel.acqInitInProgress
                fAbort = obj.hGUIData.mainControlsV4.fAbort;
                gAbort = obj.hGUIData.mainControlsV4.gAbort;
                lAbort = obj.hGUIData.mainControlsV4.lAbort;
                
                obj.cancelStart = true;
                set([fAbort gAbort lAbort],'Enable','off');
            else
                obj.hModel.abort();
            end
        end
        
        %%% BEAM FUNCTION CALLBACKS
        function calibrateBeam(obj)
            beamIdx = obj.beamDisplayIdx;
            obj.hModel.hBeams.beamsCalibrate(beamIdx);
        end
        
        function showCalibrationCurve(obj)
            beamIdx = obj.beamDisplayIdx;
            obj.hModel.hBeams.beamsShowCalibrationCurve(beamIdx);
        end
        
        function measureCalibrationOffset(obj)
            beamIdx = obj.beamDisplayIdx;
            offset = obj.hModel.hBeams.beamsMeasureCalOffset(beamIdx,true);
            if ~isnan(offset)
                msg = sprintf('Calibration offset voltage: %.3g. Result saved to Machine Data file.',offset);
                msgbox(msg,'Calibration offset measured');
            end
        end
        
        %%% IMAGE FUNCTION CALLBACKS
        function showChannelDisplay(obj,channelIdx)
            set(obj.hModel.hDisplay.hFigs(channelIdx),'visible','on');
        end
        
        function showMergeDisplay(obj,channelIdx)
            if ~obj.hModel.hDisplay.channelsMergeEnable
                obj.hModel.hDisplay.channelsMergeEnable = true;
            end
        end
        
        function linePhaseImageFunction(obj,fcnName)
            hFig = obj.zzzSelectImageFigure();
            if isempty(hFig)
                return;
            end
            
            allChannelFigs = [obj.hModel.hDisplay.hFigs(1:obj.hModel.hChannels.channelsAvailable)];
            [tf,chanIdx] = ismember(hFig,allChannelFigs);
            if tf
                feval(fcnName,obj.hModel.hScan2D,chanIdx);
            end

        end

        %%% MOTOR CALLBACKS
        function motorZeroAction(obj,action)
            feval(action,obj.hModel.hMotors);
            obj.changedMotorPosition();
        end
        
        function motorClearZero(obj)
            obj.hModel.hMotors.motorClearZeroSoft();
            obj.changedMotorPosition();
        end
        
        function motorStepPosition(obj,stepSign,stepDim)
            persistent semaphore
            if isempty(semaphore)
                semaphore = false;
            end
            
            if stepDim < 4
                if ~obj.hModel.hMotors.dimNonblockingMoveInProgress(stepDim)
                    posn = nan(1,3);
                    posn(stepDim) = obj.hModel.hMotors.motorPosition(stepDim) + (stepSign * obj.motorStepSize(stepDim));
                else
                    most.idioms.warn('Motor is currently executing a move operation. New command ignored.');
                    return;
                end
            elseif stepDim == 4
                if ~obj.hModel.hFastZ.nonblockingMoveInProgress
                    posn = obj.hModel.hFastZ.positionTarget + (stepSign * obj.motorStepSize(stepDim));
                else
                    most.idioms.warn('Motor is currently executing a move operation. New command ignored.')
                    return;
                end
            end
            
            % since this is a gui callback, there can be race
            % conditions here. block reentrant execution to prevent motor errors
            if semaphore
                most.idioms.warn('Motor is currently executing a move operation. New command ignored.')
            else
                semaphore = true; %#ok<NASGU>
                %%% start of critical section
                
                try
                    if stepDim < 4
                        obj.hModel.hMotors.motorPosition = posn;
                    elseif stepDim == 4
                        obj.hModel.hFastZ.positionTarget = posn;
                    end
                catch ME
                    semaphore = false;
                    rethrow(ME);
                end
                
                %%% end of critical section
                semaphore = false;
            end
            
            obj.changedMotorPosition();
        end
        
        function motorRecover(obj)
            recovered = true;
            for i = 1:numel(obj.hModel.hMotors.hMotor)
                tryRec(obj.hModel.hMotors.hMotor(i), sprintf('Stage controller #%d',i));
            end
            for i = 1:numel(obj.hModel.hFastZ.hStages)
                tryRec(obj.hModel.hFastZ.hStages(i), sprintf('FastZ actuator #%d',i));
            end
            
            if recovered
                structfun(@nstEnable,obj.hGUIData.motorControlsV5);
                set(obj.hGUIData.motorControlsV5.pbRecover,'Visible','off');
                set(obj.hGUIData.motorControlsV5.pbRecover,'Enable','off');
                obj.changedMotorPosition();
            end
            
            function nstEnable(h)
                if isprop(h,'Enable')
                    if ismember(h.Tag,{'etPosZZ' 'etPosR'})
                        en = 'inactive';
                    else
                        en = 'on';
                    end
                    set(h,'Enable',en);
                end
            end
            
            function tryRec(hMtr,nm)
                if hMtr.lscErrPending
                    try
                        hMtr.recover();
                    catch ME
                        fprintf(2,'%s failed to recover. Error message: %s\n',nm,ME.message);
                        warndlg(sprintf('%s failed to recover. %s\n',nm,ME.message),'ScanImage');
                        recovered = false;
                    end
                end
            end
        end
        
        function stackSetStackStart(obj)
            obj.hModel.hStackManager.setStackStart();
            % xxx DOC why it would be a bad idea for hModel to have a
            % dependent, setAccess=private, setobservable prop called
            % "tfStackStartEndPowersDefined" and for appC to listen to that
            % prop.
            if obj.hModel.hBeams.stackStartEndPowersDefined
                set(obj.hGUIData.motorControlsV5.cbOverrideLz,'Enable','on');
            end
        end
        
        function stackSetStackEnd(obj)
            obj.hModel.hStackManager.setStackEnd();
            if obj.hModel.hBeams.stackStartEndPowersDefined
                set(obj.hGUIData.motorControlsV5.cbOverrideLz,'Enable','on');
            end
        end
        
        function stackClearStartEnd(obj)
            obj.hModel.hStackManager.clearStackStartEnd();
            set(obj.hGUIData.motorControlsV5.cbOverrideLz,'Enable','off');
        end
        
        function stackClearEnd(obj)
            obj.hModel.hStackManager.clearStackEnd();
            set(obj.hGUIData.motorControlsV5.cbOverrideLz,'Enable','off');
        end
        
        function changedPosnID(obj,guiObj,goButton)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            v = get(guiObj, 'string');
            if ~all(isstrprop(v, 'digit'))
                set(guiObj, 'string', '');
                set(goButton, 'enable', 'off');
            else
                v = str2double(v);
                if v > 0 && v <= numel(obj.hModel.hMotors.userDefinedPositions)
                    set(goButton, 'enable', 'on');
                else
                    set(goButton, 'enable', 'off');
                end
            end
        end
        
        function changedPosns(obj,~,~)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.motorControlsV5;
            ets = [gd.etPosnID1 gd.etPosnID2 gd.etPosnID3];
            pbs = [gd.pbGo1 gd.pbGo2 gd.pbGo3];
            N = numel(obj.hModel.hMotors.userDefinedPositions);
            for i = 1:3
                guiObj = ets(i);
                goButton = pbs(i);
                v = str2double(get(guiObj, 'string'));
                if v > 0 && v <= N
                    set(goButton, 'enable', 'on');
                else
                    set(goButton, 'enable', 'off');
                end
            end
            
            gd = obj.hGUIData.posnControlsV5;
            nms = cell(1,N+1);
            for i = 1:N+1
                if i == N+1
                    nms{i} = 'New Position';
                else
                    n = obj.hModel.hMotors.userDefinedPositions(i).name;
                    c = obj.hModel.hMotors.userDefinedPositions(i).coords;
                    if ~isempty(n)
                        n = [n ': '];
                    end
                    nms{i} = sprintf('%d: %s[%s]', i, n, num2str(c,'%.1f '));
                end
            end
            v = get(gd.lbPosns, 'Value');
            set(gd.lbPosns, 'Value', min(v, numel(nms)));
            set(gd.lbPosns, 'String', nms);
            obj.changedSelectedPosn();
        end
        
        function changedSelectedPosn(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            posns = obj.hModel.hMotors.userDefinedPositions;
            N = numel(posns);
            v = get(gd.lbPosns, 'Value');
            
            motorPos = obj.hModel.hMotors.motorPosition;
            nDims = numel(motorPos);
            cbs = [gd.cbX gd.cbY gd.cbZ gd.cbZZ];
            cbs(nDims+1:end) = [];
            
            if v > N
                enDims = get(cbs, 'Value');
                enDims = [enDims{:}];
                motorPos(~enDims) = nan;
                
                set(gd.etName, 'String', '');
                set(gd.etPosn, 'String', sprintf('[%s]', num2str(motorPos,'%.1f  ')));
                set(gd.pbAdd, 'String', 'Add');
            else
                set(gd.etName, 'String', posns(v).name);
                set(gd.etPosn, 'String', sprintf('[%s]', num2str(posns(v).coords,'%.1f  ')));
                arrayfun(@(a,b)set(a, 'Value', b), cbs, ~isnan(posns(v).coords));
                set(gd.pbAdd, 'String', 'Set');
            end
        end
        
        function changedDimCbs(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            motorPos = obj.hModel.hMotors.motorPosition;
            nDims = numel(motorPos);
            cbs = [gd.cbX gd.cbY gd.cbZ gd.cbZZ];
            cbs(nDims+1:end) = [];
            enDims = get(cbs, 'Value');
            enDims = logical([enDims{:}]);
            
            posn = get(gd.etPosn, 'String');
            posn = str2num(posn(2:end-1));
            
            posn(~enDims) = nan;
            posn(and(enDims, isnan(posn))) = motorPos(and(enDims, isnan(posn)));
            
            set(gd.etPosn, 'String', sprintf('[%s]', num2str(posn,'%.1f  ')));
        end
        
        function changedPosnEt(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            motorPos = obj.hModel.hMotors.motorPosition;
            nDims = numel(motorPos);
            cbs = [gd.cbX gd.cbY gd.cbZ gd.cbZZ];
            cbs(nDims+1:end) = [];
            enDims = get(cbs, 'Value');
            enDims = logical([enDims{:}]);
            motorPos(~enDims) = nan;
            
            nwStr = get(gd.etPosn, 'String');
            if nwStr(1) == '['
                nwStr = nwStr(2:end-1);
            end
            nwVal = str2num(nwStr);
            if isempty(nwVal)
                nwVal = motorPos;
            else
                nwVal(nDims+1:end) = [];
                nwVal(end+1:nDims) = motorPos(numel(nwVal)+1:end);
                arrayfun(@(a,b)set(a, 'Value', b), cbs, ~isnan(nwVal));
            end
            
            set(gd.etPosn, 'String', sprintf('[%s]', num2str(nwVal,'%.1f  ')));
        end
        
        function addPosn(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            posns = obj.hModel.hMotors.userDefinedPositions;
            N = numel(posns);
            v = get(gd.lbPosns, 'Value');
            
            nm = get(gd.etName, 'String');
            posn = get(gd.etPosn, 'String');
            posn = str2num(posn(2:end-1));
            
            if v > N
                obj.hModel.hMotors.defineUserPosition(nm,posn);
                set(gd.lbPosns, 'Value', v+1);
            else
                posns(v).name = nm;
                posns(v).coords = posn;
                obj.hModel.hMotors.userDefinedPositions = posns;
            end
        end
        
        function readPosn(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            motorPos = obj.hModel.hMotors.motorPosition;
            nDims = numel(motorPos);
            cbs = [gd.cbX gd.cbY gd.cbZ gd.cbZZ];
            cbs(nDims+1:end) = [];
            enDims = get(cbs, 'Value');
            enDims = logical([enDims{:}]);
            motorPos(~enDims) = nan;
            
            set(gd.etPosn, 'String', sprintf('[%s]', num2str(motorPos,'%.1f  ')));
        end
        
        function movePosnUp(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            posns = obj.hModel.hMotors.userDefinedPositions;
            N = numel(posns);
            v = get(gd.lbPosns, 'Value');
            
            if v <= N && v > 1
                tmp = posns(v-1);
                posns(v-1) = posns(v);
                posns(v) = tmp;
                obj.hModel.hMotors.userDefinedPositions = posns;
                set(gd.lbPosns, 'Value', v-1);
            end
        end
        
        function movePosnDown(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            posns = obj.hModel.hMotors.userDefinedPositions;
            N = numel(posns);
            v = get(gd.lbPosns, 'Value');
            
            if v < N
                tmp = posns(v);
                posns(v) = posns(v+1);
                posns(v+1) = tmp;
                obj.hModel.hMotors.userDefinedPositions = posns;
                set(gd.lbPosns, 'Value', v+1);
            end
        end
        
        function removePosn(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            posns = obj.hModel.hMotors.userDefinedPositions;
            N = numel(posns);
            v = get(gd.lbPosns, 'Value');
            
            if v <= N
                obj.hModel.hMotors.userDefinedPositions(v) = [];
                if v > 1
                    set(gd.lbPosns, 'Value', v-1);
                end
            end
        end
        
        function dblClickPosn(obj)
            if obj.hModel.hMotors.numInstances <= 0
                return;
            end
            
            gd = obj.hGUIData.posnControlsV5;
            posns = obj.hModel.hMotors.userDefinedPositions;
            N = numel(posns);
            v = get(gd.lbPosns, 'Value');
            
            if v <= N
                obj.hModel.hMotors.gotoUserDefinedPosition(v)
            end
        end
        
        function toggleLineScan(obj,src,evnt)
            lineScanEnable = get(src,'Value');
            if lineScanEnable
                obj.hModel.lineScanCacheParams();
                obj.hModel.hRoiManager.forceSquarePixels = false;
                obj.hModel.hRoiManager.scanAngleMultiplierSlow = 0;
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','inactive');
            else
                set(obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow,'Enable','on');
                obj.hModel.lineScanRestoreParams();
            end
        end
        
        function changedUserFunctionsCfg(obj,~,~)
            switch obj.userFunctionsViewType
                case 'CFG'
                    obj.hGUIData.userFunctionControlsV4.uft.refresh();
            end
        end
        
        function changedUserFunctionsUsr(obj,~,~)
            switch obj.userFunctionsViewType
                case 'USR'
                    obj.hGUIData.userFunctionControlsV4.uft.refresh();
            end
        end
        
        function changedUserFunctionsOverride(obj,~,~)
            obj.hGUIData.userFunctionControlsV4.uftOverride.refresh();
        end
        
        function activateMotionCorrectionSimple(obj)
            channels = obj.hModel.hChannels.channelsActive;
            
            if isempty(channels)
                msg = 'Cannot activate motion correction if no channels are selected for display.';
                warndlg(msg,'ScanImage');
                error(msg);
            end
            
            if isscalar(channels)
                channel = channels(1);
            else
                answer = inputdlg(sprintf('Which channel do you want to use for motion correction?\nAvailable channels:  %s',mat2str(channels)),...
                    'Select channel for motion correction',1,{num2str(channels(1))});
                
                if isempty(answer)
                    return
                end
                
                channel = str2double(answer{1});
                
                if ~ismember(channel,channels)
                    msg = 'Invalid input.';
                    warndlg(msg,'ScanImage');
                    error(msg);
                end
            end
            
            obj.hModel.hMotionManager.activateMotionCorrectionSimple(channel);
        end
        
        function addMotorCalibrationPoints(obj)
            autoRead = get(obj.hGUIData.motorsAlignmentControls.cbStagePositionAutoRead,'Value');
            if autoRead
                obj.hModel.hMotors.addCalibrationPoint();
            else
                x = str2double(get(obj.hGUIData.motorsAlignmentControls.etXStagePosition,'String'));
                y = str2double(get(obj.hGUIData.motorsAlignmentControls.etYStagePosition,'String'));
                obj.hModel.hMotors.addCalibrationPoint([x,y]);
            end
        end
        
        function changedMotorsCalibrationPoints(obj,~,~)
            numPts = size(obj.hModel.hMotors.calibrationPoints,1);
            set(obj.hGUIData.motorsAlignmentControls.etNumberCalibrationPoints,'String',num2str(numPts));
            
            pts = double.empty(0,3);
            for idx = 1:size(obj.hModel.hMotors.calibrationPoints,1)
                motion = obj.hModel.hMotors.calibrationPoints{idx,2};
                pts(idx,:) = scanimage.mroi.util.xformPoints([obj.hModel.hMotionManager.referenceBuffer.centerXY 0],motion);
            end
            
            obj.hModel.hMotionManager.markerPositionsXY = pts(:,1:2);
            if size(pts,1)>0
                obj.hModel.hMotionManager.showMotionDisplay = true;
            end
        end
        
        function changedMotorToRefTransform(obj,~,~)
            [offsetX,offsetY,scaleX,scaleY,rotation,shear] = scanimage.mroi.util.paramsFromTransform(obj.hModel.hMotors.motorToRefTransform);
            set(obj.hGUIData.motorsAlignmentControls.etStageRotation,'String',sprintf('%.2f',rotation));
            set(obj.hGUIData.motorsAlignmentControls.etStageShear,'String',sprintf('%.2f',shear));
            set(obj.hGUIData.motorsAlignmentControls.etStageAspectRatio,'String',sprintf('%.2f',scaleX/scaleY));
        end
        
        function updateScanType(obj,varargin)
            switch obj.hModel.hRoiManager.scanType
                case 'frame'
                    set(obj.hGUIData.configControlsV4.pmScanType, 'value', 1);
            
                case 'line'
                    set(obj.hGUIData.configControlsV4.pmScanType, 'value', 2);
            end
            
            obj.updateScanControls();
        end
        
        function changeScanType(obj,v)
            v = strsplit(v);
            obj.hModel.hRoiManager.scanType = lower(v{1});
        end
        
        function updateScanControls(obj,varargin)
            if obj.hModel.hConfigurationSaver.cfgLoadingInProgress
                return;
            end
            
            stdCtls = [obj.hGUIData.mainControlsV4.stScanRotation obj.hGUIData.mainControlsV4.scanRotation obj.hGUIData.mainControlsV4.scanRotationSlider obj.hGUIData.mainControlsV4.zeroRotate...
                obj.hGUIData.mainControlsV4.stScanShiftFast obj.hGUIData.mainControlsV4.scanShiftFast obj.hGUIData.mainControlsV4.stScanShiftSlow obj.hGUIData.mainControlsV4.scanShiftSlow...
                obj.hGUIData.mainControlsV4.zoomText obj.hGUIData.mainControlsV4.zoomtens obj.hGUIData.mainControlsV4.zoomtensslider obj.hGUIData.mainControlsV4.zoomones...
                obj.hGUIData.mainControlsV4.zoomonesslider obj.hGUIData.mainControlsV4.stScanAngleMultiplier obj.hGUIData.mainControlsV4.zoomfrac obj.hGUIData.mainControlsV4.zoomfracslider...
                obj.hGUIData.mainControlsV4.fullfield obj.hGUIData.mainControlsV4.up obj.hGUIData.mainControlsV4.down obj.hGUIData.mainControlsV4.left obj.hGUIData.mainControlsV4.right...
                obj.hGUIData.mainControlsV4.zero obj.hGUIData.mainControlsV4.ystep obj.hGUIData.mainControlsV4.xstep obj.hGUIData.mainControlsV4.text50 obj.hGUIData.configControlsV4.pmPixelsPerLine...
                obj.hGUIData.mainControlsV4.stScanAngleMultiplierFast obj.hGUIData.mainControlsV4.etScanAngleMultiplierFast obj.hGUIData.mainControlsV4.stScanAngleMultiplierSlow...
                obj.hGUIData.mainControlsV4.etScanAngleMultiplierSlow obj.hGUIData.mainControlsV4.tbToggleLinescan obj.hGUIData.configControlsV4.text3 obj.hGUIData.configControlsV4.etPixelsPerLine...
                obj.hGUIData.configControlsV4.text1 obj.hGUIData.configControlsV4.etLinesPerFrame obj.hGUIData.configControlsV4.cbForceSquarePixelation obj.hGUIData.configControlsV4.cbForceSquarePixel];
            
            nonLineCtlsEn = [obj.hGUIData.configControlsV4.etScanPhase obj.hGUIData.configControlsV4.etScanPhase...
                obj.hGUIData.configControlsV4.pbCalibrateLinePhase obj.hGUIData.configControlsV4.etLineRate...
                obj.hGUIData.configControlsV4.scanPhaseSlider obj.hGUIData.imageControlsV4.pmVolumeStyle];
            nonLineCtlsVis = [obj.hGUIData.configControlsV4.text3 obj.hGUIData.configControlsV4.etPixelsPerLine...
                obj.hGUIData.configControlsV4.pmPixelsPerLine obj.hGUIData.configControlsV4.text1...
                obj.hGUIData.configControlsV4.etLinesPerFrame obj.hGUIData.configControlsV4.cbForceSquarePixelation...
                obj.hGUIData.configControlsV4.cbForceSquarePixel obj.hGUIData.imageControlsV4.etZSelection];
            lineCtls = [obj.hGUIData.configControlsV4.cbFeedback obj.hGUIData.configControlsV4.pbCalibrateFeedback obj.hGUIData.imageControlsV4.etLineHistoryLength];
            
            if obj.hModel.hRoiManager.mroiEnable || strcmp(obj.hModel.hRoiManager.scanType, 'line')
                set(stdCtls,'Enable','off');
            else
                set(stdCtls,'Enable','on');
            end
            
            tfLine = strcmp(obj.hModel.hRoiManager.scanType, 'line');
            set(nonLineCtlsEn,'Enable',obj.tfMap(~tfLine));
            set(nonLineCtlsVis,'Visible',obj.tfMap(~tfLine));
            set(obj.hGUIData.mainControlsV4.cbEnableMroi,'Enable',obj.tfMap(~tfLine));
            set(obj.hGUIData.configControlsV4.cbBidirectionalScan,'Visible',obj.tfMap(~tfLine));
            set(obj.hGUIData.configControlsV4.pbEditRois,'Visible',obj.tfMap(tfLine));
            set(lineCtls,'Visible',obj.tfMap(tfLine));
            if tfLine
                set(obj.hGUIData.configControlsV4.stFrameRate,'string','Cycle Rate (Hz)');
                
                set(obj.hGUIData.configControlsV4.pmScanRateVar, 'String', {'Sample Rate (MHz)'});
                set(obj.hGUIData.configControlsV4.pmScanRateVar, 'Value', 1);
                set(obj.hGUIData.configControlsV4.slLineRate,'Enable','on');
                set(obj.hGUIData.configControlsV4.etLineRate, 'Enable', 'on');
                
                set(obj.hGUIData.configControlsV4.cbFeedback, 'Enable', obj.tfMap(obj.hModel.hScan2D.hTrig.enabled));
                
                set(obj.hGUIData.imageControlsV4.stZsel, 'String', 'History Frame Length');
            else
                set(obj.hGUIData.configControlsV4.stFrameRate,'string','Frame Rate (Hz)');
                
                set(obj.hGUIData.configControlsV4.pmScanRateVar, 'String', {'Pixel Dwell Time (ns)' 'Line Rate (Hz)' 'Line Period (us)'});
                
                tfRes = isa(obj.hModel.hScan2D, 'scanimage.components.scan2d.ResScan');
                set(obj.hGUIData.configControlsV4.slLineRate,'Enable',obj.tfMap(~tfRes));
                if tfRes
                    set(obj.hGUIData.configControlsV4.etLineRate,'Enable','inactive');
                else
                    set(obj.hGUIData.configControlsV4.etLineRate,'Enable','on');
                end
                
                set(obj.hGUIData.imageControlsV4.stZsel, 'String', 'Display Z Selection');
            end
            
            obj.changedLineRateVar();
        end
        
%         function editImagingRoiGroup(obj)
%             obj.mroiGuiSetGroup(obj.hModel.hRoiManager.roiGroupMroi, 'ImagingField');
%             obj.showGUI('RoiGroupEditor');
%         end

        function editImagingRoiGroup(obj,tfShow)
            if obj.hModel.hRoiManager.isLineScan
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hRoiManager.roiGroupLineScan,obj.hModel.hScan2D.scannerset,'stimulation');
                obj.hRoiGroupEditor.defaultStimPower = [];
            else
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hRoiManager.roiGroupMroi,obj.hModel.hScan2D.scannerset,'imaging');
            end
            
            if nargin < 2 || tfShow
                obj.showGUI('RoiGroupEditor');
            end
        end
    end
    
    %% FRIEND METHODS
    %%%  APP PROPERTY CALLBACKS 
    %%%  Methods named changedXXX(src,...) respond to changes to model, which should update the controller/GUI
    %%%  Methods named changeXXX(hObject,...) respond to changes to GUI, which should update the model %}
    methods (Hidden)
        %%% IMAGING SYSTEM METHODS
        function changedImagingSystem(obj,~,~)
            nms = cellfun(@(x)x.name,obj.hModel.hScanners, 'UniformOutput', false);
            [~,id] = ismember(obj.hModel.imagingSystem, nms);
            set(obj.hGUIData.configControlsV4.pmImagingSystem, 'Value', id);
            
            persistent hImagingSystem_
            if ~isempty(hImagingSystem_) && isequal(hImagingSystem_,obj.hModel.hScan2D)
                return
            end
            
            obj.ziniChannelControls();
            obj.ziniTriggers();
            obj.switchMotorConfig();
            obj.changeFastZCfg();
            
            obj.reprocessSubMdlPropBindings('hScan2D');
            
            slmDisableControls = {'scanPhaseSlider' 'pmScanRateVar' 'etLineRate' 'etFillFrac' 'etFillFracSpatial' 'etPixelTimeMean' 'etPixelTimeMaxMinRatio' 'etLinePeriod' 'etPixelBinFactor' 'etFlybackTimePerFrameMs' 'etFlytoTimePerScanfieldMs'};
            enableControls(slmDisableControls,'on');
            switch class(obj.hModel.hScan2D)
                case 'scanimage.components.scan2d.ResScan'
                    set(obj.hGUIData.configControlsV4.cbKeepScannerOn, 'Visible', 'on');
                    set(obj.hGUIData.configControlsV4.pbMeasureFrameRate, 'enable', 'on');
                    
                    set(obj.hGUIData.configControlsV4.pmScanType, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.stScanType, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.etPixelBinFactor, 'Enable', 'inactive');
                    set(obj.hGUIData.configControlsV4.etSampleRateMHz, 'Enable', 'inactive');
                    
                    set(obj.hGUIData.configControlsV4.pbShowSlmControls, 'Visible', 'off');
                case 'scanimage.components.scan2d.LinScan'
                    set(obj.hGUIData.configControlsV4.cbKeepScannerOn, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.pbMeasureFrameRate, 'enable', 'off');
                    
                    set(obj.hGUIData.configControlsV4.pmScanType, 'Visible', 'on');
                    set(obj.hGUIData.configControlsV4.stScanType, 'Visible', 'on');
                    
                    set(obj.hGUIData.configControlsV4.etPixelBinFactor, 'Enable', 'on');
                    set(obj.hGUIData.configControlsV4.etSampleRateMHz, 'Enable', 'on');
                    
                    set(obj.hGUIData.configControlsV4.pbShowSlmControls, 'Visible', 'off');
                case 'scanimage.components.scan2d.SlmScan'
                    set(obj.hGUIData.configControlsV4.cbKeepScannerOn, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.pbMeasureFrameRate, 'enable', 'off');
                    
                    set(obj.hGUIData.configControlsV4.pmScanType, 'Visible', 'off');
                    set(obj.hGUIData.configControlsV4.stScanType, 'Visible', 'off');
                    
                    set(obj.hGUIData.configControlsV4.etPixelBinFactor,'Enable', 'off');
                    set(obj.hGUIData.configControlsV4.etSampleRateMHz, 'Enable', 'on');
                    
                    set(obj.hGUIData.configControlsV4.pbShowSlmControls, 'Visible', 'on');
                    
                    enableControls(slmDisableControls,'off');
                otherwise
                    error('Unknown Scan2D class: %s',class(obj.hModel.hScan2D));
            end
            
            % View MenuChannel 1 is never disabled.
            viewMenuChannelsEnabled = {};
            viewMenuChannelsDisabled = {};
            
            switch (obj.hModel.hChannels.channelsAvailable)
                case {1}
                    viewMenuChannelsDisabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                case {2}
                    viewMenuChannelsDisabled = {'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display'};
                case {3}
                    viewMenuChannelsDisabled = {'mnu_View_Channel4Display'};
                    viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display'};
               case {4}
                   viewMenuChannelsEnabled = {'mnu_View_Channel2Display' 'mnu_View_Channel3Display' 'mnu_View_Channel4Display'};
            end
            
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','off'),viewMenuChannelsDisabled);
            cellfun(@(s)set(obj.hGUIData.mainControlsV4.(s),'Enable','on'),viewMenuChannelsEnabled);

            obj.ziniImageControls();
            obj.ziniPowerBoxControls();
            obj.cfgLinePhaseSlider();
            obj.updateScanControls();
            
            hImagingSystem_ = obj.hModel.hScan2D;
            
            function enableControls(ctrls,status) 
                cellfun(@(ctrl)set(obj.hGUIData.configControlsV4.(ctrl),'Enable',status),ctrls);
            end
        
        end % function - changedImagingSystem
        
        function changeImagingSystem(obj,hObject)
            sys = get(hObject,'String');
            obj.hModel.imagingSystem = sys{get(hObject,'Value')};
        end
        
        %%% TIMER METHODS
        function changedSecondsCounter(obj,~,~)
            %TODO: make value of 0 'sticky' for 0.3-0.4s using a timer object here
            hSecCntr = obj.hGUIData.mainControlsV4.secondsCounter;
            
            switch obj.hModel.secondsCounterMode
                case 'up' %countup timer
                    set(hSecCntr,'String',num2str(max(0,floor(obj.hModel.secondsCounter))));
                case 'down'  %countdown timer
                    set(hSecCntr,'String',num2str(max(0,ceil(obj.hModel.secondsCounter))));
                otherwise
                    set(hSecCntr,'String','0');
            end
        end
        
        %%% DISPLAY METHODS
        function changedDisplayRollingAverageFactorLock(obj,~,~)
            if obj.hModel.hDisplay.displayRollingAverageFactorLock
                set(obj.hGUIData.imageControlsV4.etRollingAverage,'Enable','off');
            else
                set(obj.hGUIData.imageControlsV4.etRollingAverage,'Enable','on');
            end
        end
        
        function displaySelectedZsChanged(obj,varargin)
            if isempty(obj.hModel.hDisplay.selectedZs);
                str = '[All]';
            else
                str = mat2str(obj.hModel.hDisplay.selectedZs);
            end
            set(obj.hGUIData.imageControlsV4.etZSelection,'string',str)
        end
        
        function displayChangeSelectedZs(obj,str)
            if isempty(str) || strcmp(str,'[All]')
                obj.hModel.hDisplay.selectedZs = [];
            else
                obj.hModel.hDisplay.selectedZs = str2num(str);
            end
        end
        
        function displayChange3dStyle(obj,v)
            obj.hModel.hDisplay.volumeDisplayStyle = v;
        end
        
        function display3dStyleChanged(obj,varargin)
            switch obj.hModel.hDisplay.volumeDisplayStyle
                case '3D'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 1);
            
                case 'Tiled'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 2);
                    
                case 'Current'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 3);
                    
                case 'Max'
                    set(obj.hGUIData.imageControlsV4.pmVolumeStyle, 'value', 4);
            end
        end
        
        function channelAutoScale(obj,ch)
            obj.hModel.hDisplay.channelAutoScale(ch);
        end
        
        function channelToggleButton(obj,ch)
            if ch
                % channel N
                didx = ch == obj.hModel.hChannels.channelDisplay;
                dsplyed = any(didx);
                if ~dsplyed
                    obj.hModel.hChannels.channelDisplay = [obj.hModel.hChannels.channelDisplay ch];
                    
                    %make sure the line above succeeded
                    if ~any(ch == obj.hModel.hChannels.channelDisplay)
                        set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', false);
                        return;
                    end
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', true);
                end
                
                if obj.hModel.active
                    figure(obj.hModel.hDisplay.hFigs(ch));
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', true);
                else
                    if dsplyed
                        obj.hModel.hChannels.channelDisplay(didx) = [];
                        obj.hModel.hDisplay.hFigs(ch).Visible = 'off';
                        set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',ch)), 'Value', false);
                    else
                        figure(obj.hModel.hDisplay.hFigs(ch));
                    end
                end
            else
                % merge
                obj.hModel.hDisplay.channelsMergeEnable = ~obj.hModel.hDisplay.channelsMergeEnable;
            end
        end
        
        function saStep(obj,fast,slow)
            mult = 0.1 / obj.hModel.hRoiManager.scanZoomFactor;
            if fast ~= 0
                obj.hModel.hRoiManager.scanAngleShiftFast = obj.hModel.hRoiManager.scanAngleShiftFast + fast*mult;
            end
            if slow ~= 0
                obj.hModel.hRoiManager.scanAngleShiftSlow = obj.hModel.hRoiManager.scanAngleShiftSlow + slow*mult;
            end
        end
        
        function zeroScanAngle(obj)
            obj.hModel.hRoiManager.scanAngleShiftFast = 0;
            obj.hModel.hRoiManager.scanAngleShiftSlow = 0;
        end
        
        %% BEAM METHODS
        function changeBeamParams(obj,src,~,~)
            %Change occurred to beam-indexed params in view/controller
            %obj.hModel.hBeams.pzCustom = [];
            %obj.updatePowerCurve();
            switch get(src,'Style')
                case 'edit'
                    newVal = str2double(get(src,'String'));
                case {'slider' 'checkbox'}
                    newVal = get(src,'Value');
                otherwise
                    assert(false,'Unsupported control style.');
            end
            propName = get(src,'UserData');
            propNameBeams = strrep(propName,'hBeams___','');
            
            try
                obj.hModel.hBeams.(propNameBeams)(obj.beamDisplayIdx) = newVal;
            catch ME
                % Error setting beam-indexed model prop; revert GUI
                obj.changedBeamParams(propName);
                
                % TODO what is the right thing here
                switch ME.identifier
                    % currently don't throw any warnings/errs
                end
            end
        end
        
        function changeBeamPowersDisplay(obj,src,~,~)
            if obj.hModel.hBeams.numInstances <= 0
                return;
            end
            
            switch get(src,'Style')
                case 'edit'
                    newVal = str2double(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                otherwise
                    assert(false,'Unsupported control style.');
            end
            
            try
                obj.hModel.hBeams.powers(obj.beamDisplayIdx) = newVal;
            catch ME
                switch ME.identifier
                    % currently don't throw any warnings/errs
                end
            end
        end
        
        function changedBeamPowersDisplay(obj,src,evnt)
            %Do nothing.
        end
        
        function changedBeamParams(obj,src,evnt)
            % Change occurred to beam-indexed property in model; refresh
            % controls tied to that prop.
            % src: either a meta.prop object (when changedBeamParams used as
            % prop listener), or a propName string
            if obj.hModel.hBeams.numInstances <= 0
                return;
            end
            
            if ischar(src)
                propName = src;
            elseif isa(src,'meta.property')
                propName = sprintf('hBeams___%s',src.Name);
            else
                assert(false,'Invalid src input arg.');
            end
            
            propNameBeams = strrep(propName,'hBeams___','');
            newVal = obj.hModel.hBeams.(propNameBeams)(obj.beamDisplayIdx);
            
            hControls = obj.beamProp2Control.(propName);
            for c = 1:numel(hControls)
                switch get(hControls(c),'Style')
                    case 'edit'
                        set(hControls(c),'String',num2str(newVal));
                    case {'slider' 'checkbox'}
                        set(hControls(c),'Value',newVal);
                    otherwise
                        assert(false,'Unsupported control style.');
                end
            end
            
            v = 0.9412 * double(~any(obj.hModel.hBeams.directMode)) * ones(1,3) + [double(any(obj.hModel.hBeams.directMode)) 0 0];
            set(obj.hGUIData.powerControlsV4.cbDirectMode, 'BackgroundColor', v)
            
            obj.updatePowerCurve();
        end
        
        function changedBeamPzAdjust(obj,src,evnt)
            if obj.hModel.hBeams.numInstances <= 0
                return;
            end
            
            currBeamActive = obj.hModel.hBeams.pzAdjust(obj.beamDisplayIdx);
            
            set(obj.hGUIData.powerControlsV4.cbPzAdjust,'Value',currBeamActive);
            
            if currBeamActive
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','on');
            else
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off');
            end
            
            obj.updatePowerCurve();
        end
        
        % Function to update P/z profile according to non-default settings.
        % i.e. custom power function. This is the logic that is called when
        % the related GUI fields are edited.
        function customPzEnable(obj,src,~,~)
            val = get(obj.hGUIData.powerControlsV4.pzAdjust, 'Value');  % Get the value of the drop down menu. This equates to your Power/Depth Adjustment Setting.

            if(val == 1)    % Value of 1 indicates no Power/Depth Correction
                
                obj.hModel.hBeams.pzAdjust(obj.beamDisplayIdx) = false; % Set Power/Depth Correction Boolean to false.
                obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = [];    % Set the custom Power/Depth Correction parameter to its default
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'off');    % Disables GUI objects.....
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'off');
                set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'off');
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off');
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','off');
                set(obj.hGUIData.powerControlsV4.text71,'Visible','off');
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String','');
                
                obj.pzCustomHistory(obj.beamDisplayIdx) = val;
                obj.updatePowerCurve();
            elseif(val == 2)    % Value of 2 indicates Power/Depth Correction is set to default. 
                
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'off');    % Disables GUI objects.....
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'off');
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','on');  % Enables length constant field
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','on');
                set(obj.hGUIData.powerControlsV4.text71,'Visible','on');
                set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'off');
                obj.hModel.hBeams.pzAdjust(obj.beamDisplayIdx) = true;  % Sets the boolean to true
                obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = [];    % Sets custom parameter to default
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String','');
                
                obj.pzCustomHistory(obj.beamDisplayIdx) = val;
                obj.updatePowerCurve();
            elseif(val == 3)    % Value of 3 indicates the Power/Depth Correction is set to Function.
                obj.hModel.hBeams.pzAdjust(obj.beamDisplayIdx) = true;
                if(obj.pzCustomHistory(obj.beamDisplayIdx) ~= val)
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String', '');
                end
                
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off'); % Disable length constant fields (Uneccessary for custom function)
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','off');
                set(obj.hGUIData.powerControlsV4.text71,'Visible','off');
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'on');     % Enables custom function source field.
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'on');
                set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'on');
                str = char(get(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String'));% Sets str to the string contained in the custom function field. 
                obj.updatePowerCurve();

                if(isempty(str))    % If the field is blank, display a message asking user to fill the field instead of giving and Error/Warning
                    
                    disp('Make sure to set the function name.');
                    
                elseif((exist(str, 'file') == 0) || (~isempty(strfind(str, '.')))) % If the function named entered does not exist (i.e. garbage) display a message asking the user to fix this. 
                    
                    disp('Invalid Function name.')
                    disp('Please make sure the file that contains the function has the same name as the function and is in the working directory.');
                    disp('Function Reset to Default!');
                    obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = [];
                    obj.updatePowerCurve();
                    
                else
                    
                    try
                        
                        obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = str2func(str);     % Converts the string in the custom function field to an official handle to that function.
                        obj.updatePowerCurve();                % Update the power curve to display the curve set by the custom function. 
                        %disp('Custom Function Loaded.');
                        
                    catch
                        
                        disp('ERROR! - The entry is valid but does not work as intended');
                        disp('Most likely cause: CASE MISMATCH! Function Entry Is Case Sensitive!');
                        disp('Function Reset to Default!');
                        obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = []; 
                        set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String','');
                        obj.updatePowerCurve();
                        
                    end
                end
                
                obj.pzCustomHistory(obj.beamDisplayIdx) = val;
                
            elseif(val == 4)    % Value of 4 indicates the users wishes to use a lookup table to manually indicate the power for each z depth.
                obj.hModel.hBeams.pzAdjust(obj.beamDisplayIdx) = true;                
                if(obj.pzCustomHistory(obj.beamDisplayIdx) ~= val)
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String', '');
                end
                
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off'); % Disable length constant fields (Uneccessary for custom function)
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','off');
                set(obj.hGUIData.powerControlsV4.text71,'Visible','off');
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'on');     % Enables custom function source field.
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'on');
                set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'on');
                
                str = char(get(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String'));% Sets str to the string contained in the custom function field. 
                obj.temp_fname = str;
                obj.updatePowerCurve();
                if(isempty(str))    % If the field is blank, display a message asking user to fill the field instead of giving and Error/Warning
                    
                    disp('Make sure to set the file name.');
                    
                elseif((exist(str, 'file') == 0) || (isempty(strfind(str, '.')))) % If the function named entered does not exist (i.e. garbage) display a message asking the user to fix this. 
                    
                    disp('Invalid File name. File Not Found.')
                    disp('Please make sure the file is in the working directory.');
                    disp('Function Reset to Default!');
                    obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = [];
                    obj.updatePowerCurve();
                    
                else
                    try
                        obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = importdata(str);     % Converts the string in the custom function field to an official handle to that function.
                        obj.updatePowerCurve();                % Update the power curve to display the curve set by the custom function. 
                        %disp('Look Up Table Loaded');
                    catch % Doens't Work/Not Needed For Files? Matlab's inherent Case handling system is funky... 
                        disp('ERROR! - The entry is valid but does not work as intended');
                        disp('Most likely cause: CASE MISMATCH! File Entry Is Case Sensitive!');
                        disp('Function Reset to Default!');
                        obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = []; 
                        set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String','');
                        obj.updatePowerCurve();
                    end
                end
                
                obj.pzCustomHistory(obj.beamDisplayIdx) = val;
                
            else
                
                disp('Error - Unknown GUI Value');  % If by some insanity the value is not 1, 2, 3, or 4 than display a message rather than trying to do something special. 
                
            end

        end
        
        function pzGUI(obj)
            if(obj.hModel.hBeams.pzAdjust(obj.beamDisplayIdx) == true)
                %
                if (isempty(obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx}))
                    %Default
                    set(obj.hGUIData.powerControlsV4.pzAdjust, 'Value', 2);
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'off');    % Disables GUI objects.....
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'off');
                    set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','on');  % Enables length constant field
                    set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','on');
                    set(obj.hGUIData.powerControlsV4.text71,'Visible','on');
                    set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'off');
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String','');
                    obj.updatePowerCurve();
                    
                elseif (isa(obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx}, 'function_handle'))
                    %custom function
                    set(obj.hGUIData.powerControlsV4.pzAdjust, 'Value', 3);
                    set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off'); % Disable length constant fields (Uneccessary for custom function)
                    set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','off');
                    set(obj.hGUIData.powerControlsV4.text71,'Visible','off');
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'on');     % Enables custom function source field.
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'on');
                    set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'on');
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String',char(func2str(obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx})));
                    obj.updatePowerCurve();
                    
                elseif (ismatrix(obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx})&&~isempty(obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx}))
                    %LUT
                    set(obj.hGUIData.powerControlsV4.pzAdjust, 'Value', 4);
                    set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off'); % Disable length constant fields (Uneccessary for custom function)
                    set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','off');
                    set(obj.hGUIData.powerControlsV4.text71,'Visible','off');
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'on');     % Enables custom function source field.
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'on');
                    set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'on');
                    set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String',obj.temp_fname);
                    obj.updatePowerCurve();
                    
                else
                    %error
                    disp('Something went horribly awry!');
                end
            else
                set(obj.hGUIData.powerControlsV4.pzAdjust, 'Value', 1);
                obj.hModel.hBeams.pzCustom{obj.beamDisplayIdx} = [];
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Enable', 'off');    % Disables GUI objects.....
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'Visible', 'off');
                set(obj.hGUIData.powerControlsV4.pzSource, 'Visible', 'off');
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Enable','off');
                set(obj.hGUIData.powerControlsV4.etZLengthConstant,'Visible','off');
                set(obj.hGUIData.powerControlsV4.text71,'Visible','off');
                set(obj.hGUIData.powerControlsV4.pzSourceEdit, 'String','');
                obj.updatePowerCurve();
                
            end
%             obj.customPzEnable();
        end
        
        
        %GUI
        function updatePowerCurve(obj,varargin)
            if obj.hModel.hBeams.numInstances <= 0
                return;
            end
            
%             if obj.hModel.active && obj.hModel.hStackManager.isSlowZ
%                 % do not update the curve during a slow z acquisition
%                 return
%             end
            
            powersNominal = obj.hModel.hBeams.powers(obj.beamDisplayIdx); % in percent
            zPowerReference = obj.hModel.hStackManager.zPowerReference;
            zs = obj.hModel.hStackManager.zs;
            lz = obj.hModel.hBeams.acqLengthConstants(obj.beamDisplayIdx);
            lim = obj.hModel.hBeams.powerLimits(obj.beamDisplayIdx);
            samplingMask = 1:length(zs);
            
            if ~isscalar(zs) && obj.hModel.hStackManager.isFastZ && strcmpi(obj.hModel.hFastZ.waveformType,'sawtooth')
                zs = [zs 2*zs(end)-zs(end-1)];
            end
            
            powers = obj.hModel.hBeams.zprvBeamsDepthPowerCorrection(obj.beamDisplayIdx, powersNominal, zPowerReference, zs(:), lz);
            powers(powers>lim) = lim; % enforce power limit
            
            if isscalar(zs)
                zs = [zs-1;zs;zs+1];
                powers = repmat(powers,3,1);
                samplingMask = 2;
            end
            
            hAx = obj.hGUIData.powerControlsV4.axPowerZProfile;
            cla(hAx);
            
            color = [0 0.4470 0.7410];
            line('Parent',hAx,'XData',zs,'YData',powers,'Color',color);
            line('Parent',hAx,'XData',zs(samplingMask),'YData',powers(samplingMask),'Color',color,'Marker','o','LineStyle','none');
            
            xRange = [min(zs),max(zs)];
            xRange = mean(xRange) + [-diff(xRange) diff(xRange)] * 0.6; % expand xRange
            if xRange(1) == xRange(2)
                xRange = [xRange(1)-1 xRange(2)+1]; % for sanity
            end
            
            hAx.XLim = xRange;
        end
        
        function toggleShowPowerZProfile(obj,varargin)
            hGui = obj.hGUIs.powerControlsV4;
            hAx = obj.hGUIData.powerControlsV4.axPowerZProfile;
            hPb = obj.hGUIData.powerControlsV4.pbShowPowerZProfile;
            
            oldUnits = obj.hGUIs.powerControlsV4.Units;
            hGui.Units = 'characters';
            
            if ~isempty(varargin) && ~isempty(varargin{1}) && islogical(varargin{1})
                showTf = varargin{1};
            else
                currentlyVisible = strcmpi(hAx.Visible,'on') || hGui.Position(3) > 60;
                showTf = ~currentlyVisible;
            end
            
            if showTf
                hAx.Visible = 'on';
                hGui.Position(3) = 108.5;
                hPb.String = '<';
            else
                hGui.Position(3) = 51;
                hAx.Visible = 'off';
                hPb.String = '>';
            end            
            
            hGui.Units = oldUnits;
        end
        
        function changedPowerBoxes(obj,~,~)
            obj.ziniPowerBoxControls();
            
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                pb = obj.hModel.hBeams.powerBoxes(i);
                set(obj.hGUIData.powerBoxControlsV4.etPowers,'String',num2str(pb.powers));
                if obj.hGUIData.powerBoxControlsV4.rbFraction == get(obj.hGUIData.powerBoxControlsV4.unitPanel, 'SelectedObject')
                    %units are fraction
                    r = pb.rect;
                    s = num2str(r,'%.3f ');
                else
                    %units are pixels
                    sz = [obj.hModel.hRoiManager.pixelsPerLine obj.hModel.hRoiManager.linesPerFrame];
                    r = floor(pb.rect .* [sz sz]);
                    s = num2str(r,'%d   ');
                end
                set(obj.hGUIData.powerBoxControlsV4.etPosition,'String',s);
                obj.powerBoxUpdateBoxFigure();
            end
            
            obj.updateOtherPbs();
        end
        
        function updateOtherPbs(obj)
            i = obj.pbIdx;
            n = numel(obj.hModel.hBeams.powerBoxes);
            nOth = n - (i <= n);
            while numel(obj.hPowbOthers) < (nOth)
                obj.hPowbOthers(end+1) = surface([.25 .75],[.25 .75],0.5*ones(2),'Parent',obj.hPowbAx,'Hittest','off','FaceColor',[.5 .5 .5],...
                    'EdgeColor',[.5 .5 .5],'LineWidth',1.5,'FaceLighting','none','FaceAlpha',0.2,'visible','off');
                obj.hOthTexts(end+1) = text(.25,.25,.5,'Power Box','Parent',obj.hPowbAx,'visible','off','color','y','Hittest','on');
            end
            delete(obj.hPowbOthers(nOth+1:end));
            delete(obj.hOthTexts(nOth+1:end));
            obj.hPowbOthers(nOth+1:end) = [];
            obj.hOthTexts(nOth+1:end) = [];
            
            nms = {};
            for pb = obj.hModel.hBeams.powerBoxes
                nms{end+1} = pb.name;
                if isempty(nms{end})
                    nms{end} = sprintf('Power Box %d', numel(nms));
                end
            end
            
            oths = setdiff(1:n,i);
            for i = 1:nOth
                r = obj.hModel.hBeams.powerBoxes(oths(i)).rect;
                set(obj.hPowbOthers(i), 'XData', [r(1) r(1)+r(3)]);
                set(obj.hPowbOthers(i), 'YData', [r(2) r(2)+r(4)]);
                set(obj.hPowbOthers(i), 'visible','on');
                set(obj.hOthTexts(i), 'Position', [r(1)+.01 r(2)+.03 .75],'visible','on');
                set(obj.hOthTexts(i), 'String', nms{oths(i)});
                set(obj.hOthTexts(i), 'ButtonDownFcn', @(varargin)selPb(oths(i)));
            end
            
            function selPb(n)
                obj.pbIdx = n;
            end
        end
        
        function changePowerBoxRect(obj,~,~)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                pb = obj.hModel.hBeams.powerBoxes(i);
                u = str2num(get(obj.hGUIData.powerBoxControlsV4.etPosition,'String'));
                if obj.hGUIData.powerBoxControlsV4.rbFraction == get(obj.hGUIData.powerBoxControlsV4.unitPanel, 'SelectedObject')
                    %units are fraction
                    pb.rect = u;
                else
                    %units are pixels
                    sz = [obj.hModel.hRoiManager.pixelsPerLine obj.hModel.hRoiManager.linesPerFrame];
                    pb.rect = u ./ [sz sz];
                end
                obj.hModel.hBeams.powerBoxes(i) = pb;
            end
        end
        
        function changePowerBoxPowers(obj,~,~)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                v = str2num(get(obj.hGUIData.powerBoxControlsV4.etPowers,'String'));
                obj.hModel.hBeams.powerBoxes(i).powers = v;
            end
        end
        
        function powerBoxUpdateBoxFigure(obj)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                pb = obj.hModel.hBeams.powerBoxes(i);
                x1 = pb.rect(1);
                x2 = pb.rect(1)+pb.rect(3);
                y1 = pb.rect(2);
                y2 = pb.rect(2)+pb.rect(4);
                
                set(obj.hPowbBoxSurf,'XData',[x1 x2],'YData',[y1 y2]);
                set(obj.hPowbBoxCtr,'XData',(x1+x2)*.5,'YData',(y1+y2)*.5);
                set([obj.hPowbBoxTL obj.hPowbBoxBL],'XData',x1);
                set([obj.hPowbBoxTR obj.hPowbBoxBR],'XData',x2);
                set([obj.hPowbBoxTL obj.hPowbBoxTR],'YData',y1);
                set([obj.hPowbBoxBL obj.hPowbBoxBR],'YData',y2);
                
                set([obj.hPowbBoxT obj.hPowbBoxB],'XData',[x1 x2]);
                set(obj.hPowbBoxL,'XData',[x1 x1]);
                set(obj.hPowbBoxR,'XData',[x2 x2]);
                set([obj.hPowbBoxL obj.hPowbBoxR],'YData',[y1 y2]);
                set(obj.hPowbBoxT,'YData',[y1 y1]);
                set(obj.hPowbBoxB,'YData',[y2 y2]);
                
                if isempty(pb.name)
                    nm = sprintf('Power Box %d', i);
                else
                    nm = pb.name;
                end
                set(obj.hText, 'Position', [x1+.01 y1+.03 2]);
                set(obj.hText, 'String', nm);
            end
        end
        
        function deletePowerBox(obj)
            i = obj.pbIdx;
            if i <= numel(obj.hModel.hBeams.powerBoxes)
                if i > 1
                    set(obj.hGUIData.powerBoxControlsV4.pmPbSel,'Value',i-1);
                end
                obj.hModel.hBeams.powerBoxes(i) = [];
                obj.ziniPowerBoxControls();
            end
        end
        
        function selectPowerBox(obj)
            if obj.pbIdx > numel(obj.hModel.hBeams.powerBoxes)
                obj.hModel.hBeams.powerBoxes(obj.pbIdx) = struct('rect', [.25 .25 .5 .5], 'powers', NaN, 'name', '','oddLines',true,'evenLines',true);
                obj.ziniPowerBoxControls();
            else
                obj.changedPowerBoxes();
            end
        end
        
        function powerBoxGuiCopyChannel(obj,idx)
            try
                imdata = single(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.imageData{idx}{1})' ./ obj.hModel.hDisplay.displayRollingAverageFactor; %Transpose image data in SI2015.
                lut = single(obj.hModel.hChannels.channelLUT{idx});
                maxVal = single(255);
                scaledData = uint8((imdata - lut(1)) .* (maxVal / (lut(2)-lut(1))));
                set(obj.hPowbCtxIm, 'cdata', repmat(scaledData,1,1,3));
            catch
                most.idioms.warn('No image data found.');
                set(obj.hPowbCtxIm, 'cdata', zeros(2,2,3,'uint8'));
            end
        end
        
        function p = getPbPt(obj)
            p = get(obj.hPowbAx,'CurrentPoint');
            p = p([1 3]);
        end
        
        function powbScrollWheelFcn(obj, ~, evt)
            mv = double(evt.VerticalScrollCount) * 1;%evt.VerticalScrollAmount;
            
            % find old range and center
            xlim = get(obj.hPowbAx,'xlim');
            ylim = get(obj.hPowbAx,'ylim');
            rg = xlim(2) - xlim(1);
            ctr = 0.5*[sum(xlim) sum(ylim)];
            
            % calc and constrain new half range
            nrg = min(1,rg*.75^-mv);
            nrg = max(0.0078125,nrg);
            nhrg = nrg/2;
            
            %calc new center based on where mouse is
            pt = obj.getPbPt;
            odfc = pt - ctr; %original distance from center
            ndfc = odfc * (nrg/rg); %new distance from center
            nctr = pt - [ndfc(1) ndfc(2)];
            
            %constrain center
            nctr = max(min(nctr,1-nhrg),nhrg);
            
            % new lims
            xlim = [-nhrg nhrg] + nctr(1);
            ylim = [-nhrg nhrg] + nctr(2);
            set(obj.hPowbAx,'xlim',xlim,'ylim',ylim);
        end
        
        function powbPanFcn(obj,starting,stopping)
            persistent prevpt;
            persistent ohrg;
            
            if starting
                if strcmp(get(obj.hGUIs.powerBoxControlsV4,'SelectionType'), 'normal')
                    % left click
                    prevpt = obj.getPbPt;
                    
                    xlim = get(obj.hPowbAx,'xlim');
                    ohrg = (xlim(2) - xlim(1))/2;
                    
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',@(varargin)obj.powbPanFcn(false,false),'WindowButtonUpFcn',@(varargin)obj.powbPanFcn(false,true));
                    waitfor(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[]);
                end
            else
                % find prev center
                xlim = get(obj.hPowbAx,'xlim');
                ylim = get(obj.hPowbAx,'ylim');
                octr = 0.5*[sum(xlim) sum(ylim)];
                
                % calc/constrain new center
                nwpt = obj.getPbPt;
                nctr = octr - (nwpt - prevpt);
                nctr = max(min(nctr,1-ohrg),ohrg);
                
                nxlim = nctr(1) + [-ohrg ohrg];
                nylim = nctr(2) + [-ohrg ohrg];
                
                set(obj.hPowbAx,'xlim',nxlim);
                set(obj.hPowbAx,'ylim',nylim);

                prevpt = obj.getPbPt;
                
                if stopping
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                end
            end
        end
        
        function powbCpFunc(obj,chgng,starting,stopping)
            persistent prevpt;
            
            if starting
                if strcmp(get(obj.hGUIs.powerBoxControlsV4,'SelectionType'), 'normal')
                    % left click
                    prevpt = obj.getPbPt;
                    
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',@(varargin)obj.powbCpFunc(chgng,false,false),'WindowButtonUpFcn',@(varargin)obj.powbCpFunc(chgng,false,true));
                    waitfor(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[]);
                end
            else
                nwpt = obj.getPbPt;
                mv = nwpt - prevpt;
                i = obj.pbIdx;
                if i <= numel(obj.hModel.hBeams.powerBoxes)
                    pb = obj.hModel.hBeams.powerBoxes(i);
                    r = pb.rect;
                    osz = r([3 4]);
                    r([3 4]) = osz + r([1 2]);
                    
                    if chgng(1)
                        r(1) = r(1) + mv(1);
                    end
                    
                    if chgng(2)
                        r(2) = r(2) + mv(2);
                    end
                    
                    if chgng(3)
                        r(3) = r(3) + mv(1);
                    end
                    
                    if chgng(4)
                        r(4) = r(4) + mv(2);
                    end
                    
                    if all(chgng)
                        r([3 4]) = osz;
                        lims = 1 - osz;
                        r([1 2]) = min(lims,max(0,r([1 2])));
                    else
                        r([3 4]) = r([3 4]) - r([1 2]);
                    end
                    
                    r(3) = max(0,r(3)); % prevent negative width
                    r(4) = max(0,r(4)); % prevent negative height
                    
                    pb.rect = r;
                    obj.hModel.hBeams.powerBoxes(i) = pb;
                end
                
                if stopping
                    set(obj.hGUIs.powerBoxControlsV4,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                else
                    prevpt = nwpt;
                end
            end
        end
        
        %%% Trigger Methods
        function changedTrigNextStopEnable(obj,src,evnt)
            if obj.hModel.hScan2D.trigNextStopEnable
                buttonEnable = 'on';
            else
                buttonEnable = 'off';
            end
            set(obj.hGUIData.triggerControlsV5.pbAcqStop,'Enable',buttonEnable);
            set(obj.hGUIData.triggerControlsV5.pbNextFileMarker,'Enable',buttonEnable);
        end
        
        function changedTrigAcqInTerm(obj,src,evnt)
            if isempty(obj.hModel.hScan2D.trigAcqInTerm)
                triggerButtonEnable = 'off';
            else
                triggerButtonEnable = 'on';
            end
            set(obj.hGUIData.mainControlsV4.cbExternalTrig,'Enable',triggerButtonEnable);
            set(obj.hGUIData.triggerControlsV5.pbAcqStart,'Enable',triggerButtonEnable);
        end
        
        %%% CHANNEL METHODS        
        function changedChannelsMergeEnable(obj,src,evt)
            val = obj.hModel.hDisplay.channelsMergeEnable;
            set(obj.hGUIData.imageControlsV4.tbMrg, 'Value', val);
            if val
                set(obj.hGUIData.channelControlsV4.cbChannelsMergeFocusOnly,'Enable','on');
                set(obj.hModel.hDisplay.hMergeFigs,'visible','on');
            else
                set(obj.hGUIData.channelControlsV4.cbChannelsMergeFocusOnly,'Enable','off');
            end
        end
        
        function changedChanLUT(obj,src,evnt)
            chanNum = str2double(regexpi(src.Name,'[0-9]*','Match','Once'));
            
            chanProp = sprintf('chan%dLUT',chanNum);            
            blackVal = obj.hModel.hDisplay.(chanProp)(1);
            whiteVal = obj.hModel.hDisplay.(chanProp)(2);
            
            set(obj.hGUIData.imageControlsV4.(sprintf('blackEditChan%d',chanNum)),'String',num2str(blackVal));
            set(obj.hGUIData.imageControlsV4.(sprintf('whiteEditChan%d',chanNum)),'String',num2str(whiteVal));
            
            hBlackSlider = obj.hGUIData.imageControlsV4.(sprintf('blackSlideChan%d',chanNum));
            hWhiteSlider = obj.hGUIData.imageControlsV4.(sprintf('whiteSlideChan%d',chanNum));
            
            minSliderVal = fix(hBlackSlider.Min);
            maxSliderVal = fix(hWhiteSlider.Max);
            
            blackValSliderVal = min(max(blackVal,minSliderVal),maxSliderVal);
            whiteValSliderVal = min(max(whiteVal,minSliderVal),maxSliderVal);
            
            hBlackSlider.Value = blackValSliderVal;
            hWhiteSlider.Value = whiteValSliderVal;
        end
        
        function changeChannelsLUT(obj,src,blackOrWhite,chanIdx)
            %blackOrWhite: 0 if black, 1 if white
            %chanIdx: Index of channel whose LUT value to change
            switch get(src,'Style')
                case 'edit'
                    newVal = str2double(get(src,'String'));
                case 'slider'
                    newVal = get(src,'Value');
                    %Only support integer values, from slider controls
                    newVal = round(newVal);         
            end
            
            %Erroneous entry
            if isempty(newVal)
                %refresh View
                obj.changedChanLUT(); 
            else
                chanProp = sprintf('chan%dLUT',chanIdx);
                try
                    obj.hModel.hDisplay.(chanProp)(2^blackOrWhite) = newVal;
                catch ME
                    obj.changedChanLUT();
                    obj.updateModelErrorFcn(ME);
                end
            end
        end
        
        %%% PHOTOSTIM METHODS
        function changedPhotostimState(obj,src,evnt)
            obj.pshk_zeroshit = 0;
            ctrls = [obj.hGUIData.photostimControlsV5.pbMode,...
                     obj.hGUIData.photostimControlsV5.etTrigTerm,...
                     obj.hGUIData.photostimControlsV5.etSyncTerm,...
                     obj.hGUIData.photostimControlsV5.etExtStimSelTriggerTerm,...
                     obj.hGUIData.photostimControlsV5.etExtStimSelTerms,...
                     obj.hGUIData.photostimControlsV5.etSequence,...
                     obj.hGUIData.photostimControlsV5.etNumSequences,...
                     obj.hGUIData.photostimControlsV5.pmTrigSource,...
                     obj.hGUIData.photostimControlsV5.pmSyncSource];
            
            if obj.hModel.hPhotostim.numInstances == 0
                return;
            elseif strcmp(obj.hModel.hPhotostim.status, 'Offline')
                set(obj.hGUIData.photostimControlsV5.pbStart,'String','START','Enable','on');
                set(obj.hGUIData.photostimControlsV5.pbSoftTrig,'Enable','off');
                set(obj.hGUIData.photostimControlsV5.pbSync,'Enable','off');
                set(obj.hGUIData.photostimControlsV5.lbStimGroups, 'BackgroundColor', [1 1 1])
                ctlState = 'on';
            elseif strcmp(obj.hModel.hPhotostim.status(1:4), 'Init')
                set(obj.hGUIData.photostimControlsV5.pbStart,'Enable','off');
                set(obj.hGUIData.photostimControlsV5.lbStimGroups, 'BackgroundColor', [1 1 1])
                ctlState = 'off';
            else
                set(obj.hGUIData.photostimControlsV5.pbStart,'String','ABORT','Enable','on');
                set(obj.hGUIData.photostimControlsV5.pbSoftTrig,'Enable','on');
                if ~isempty(obj.hModel.hPhotostim.syncTriggerTerm)
                    set(obj.hGUIData.photostimControlsV5.pbSync,'Enable','on');
                end
                if strcmp(obj.hModel.hPhotostim.stimulusMode, 'onDemand')
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups, 'BackgroundColor', [1 .9 .9])
                end
                ctlState = 'off';
            end
            
            set(ctrls, 'Enable', ctlState);
        end
        
        function changePhotostimMode(obj, idx)
            try
                switch idx
                    case 1
                        obj.hModel.hPhotostim.stimulusMode = 'sequence';
                    case 2
                        obj.hModel.hPhotostim.stimulusMode = 'onDemand';
                end
            catch ME
                most.idioms.dispError([ME.message, '\n']);
            end
            obj.changedPhotostimMode();
        end
        
        function changedPhotostimMode(obj,~,~)
            if strcmp(obj.hModel.hPhotostim.stimulusMode, 'sequence')
                set(obj.hGUIData.photostimControlsV5.pbMode,'value',1);
                seq = 'on';
                od = 'off';
            else
                set(obj.hGUIData.photostimControlsV5.pbMode,'value',2);
                seq = 'off';
                od = 'on';
            end
            
            set(obj.hGUIData.photostimControlsV5.lblSeqSel,'visible',seq);
            set(obj.hGUIData.photostimControlsV5.etSequence,'visible',seq);
            set(obj.hGUIData.photostimControlsV5.lblNumSeq,'visible',seq);
            set(obj.hGUIData.photostimControlsV5.etNumSequences,'visible',seq);
            
            set(obj.hGUIData.photostimControlsV5.cbAllowMult,'visible',od);
            set(obj.hGUIData.photostimControlsV5.cbEnableHotkeys,'visible',od);
            set(obj.hGUIData.photostimControlsV5.extStimSelPanel,'visible',od);
        end
        
        function changedStimRoiGroups(obj,src,evnt)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                % update list
                nms = {obj.hModel.hPhotostim.stimRoiGroups.name};
                nms = cellfun(@(str,idx)sprintf('%d: %s', idx, str), nms, num2cell(1:numel(nms)), 'UniformOutput', false);
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'string',nms);
                
                % make sure value is valid
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                if isempty(v)
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',1);
                elseif v > numel(nms)
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',numel(nms));
                end
            else
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'string',{});
            end
                
            % add listener to name properties
            cellfun(@(lh)most.idioms.safeDeleteObj(lh),obj.stimRoiGroupNameListeners);
            obj.stimRoiGroupNameListeners = arrayfun(@(hRoiGroup)hRoiGroup.addlistener('name', 'PostSet', @obj.changedStimRoiGroupName),...
                obj.hModel.hPhotostim.stimRoiGroups,'UniformOutput',false);
        end
        
        function changedStimRoiGroupName(obj,~,~)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                % update list
                nms = {obj.hModel.hPhotostim.stimRoiGroups.name};
                nms = cellfun(@(str,idx)sprintf('%d: %s', idx, str), nms, num2cell(1:numel(nms)), 'UniformOutput', false);
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'string',nms);
            end
        end
        
        function addStimGroup(obj,src,evnt)
            if isempty(obj.hModel.hPhotostim.stimRoiGroups)
                obj.hModel.hPhotostim.stimRoiGroups = scanimage.mroi.RoiGroup('New stimulus group');
            else
                obj.hModel.hPhotostim.stimRoiGroups(end+1) = scanimage.mroi.RoiGroup('New stimulus group');
            end
            set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',numel(obj.hModel.hPhotostim.stimRoiGroups));
        end
        
        function remStimGroup(obj,src,evnt)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                obj.hModel.hPhotostim.stimRoiGroups(v) = [];
            end
        end
        
        function editStimGroup(obj,~,~)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
%                 obj.mroiGuiSetGroup(obj.hModel.hPhotostim.stimRoiGroups(v), 'StimulusField');
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hPhotostim.stimRoiGroups(v),obj.hModel.hPhotostim.stimScannerset,'stimulation');
                obj.hRoiGroupEditor.defaultStimPower = inf;
                obj.showGUI('RoiGroupEditor');
            end
        end
        
        function copyStimGroup(obj)
            if numel(obj.hModel.hPhotostim.stimRoiGroups)
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                obj.hModel.hPhotostim.stimRoiGroups(end+1) = obj.hModel.hPhotostim.stimRoiGroups(v).copy();
                set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',numel(obj.hModel.hPhotostim.stimRoiGroups));
            end
        end
        
        function moveStimGroup(obj,dir)
            n = numel(obj.hModel.hPhotostim.stimRoiGroups);
            if n
                v = get(obj.hGUIData.photostimControlsV5.lbStimGroups,'value');
                nv = v + dir;
                
                if (nv > 0) && (nv <= n)
                    obj.hModel.hPhotostim.stimRoiGroups([v,nv]) = obj.hModel.hPhotostim.stimRoiGroups([nv,v]);
                    set(obj.hGUIData.photostimControlsV5.lbStimGroups,'value',nv);
                end
            end
        end
        
        function photostimHotKey(obj,v)
            if obj.enablePhotostimHotkeys && strcmp(obj.hModel.hPhotostim.stimulusMode, 'onDemand') && obj.hModel.hPhotostim.active
                n = str2double(strrep(v,'numpad',''));
                if isnan(n)
                    switch v
                        case 't';
                            disp('Sending photostim trigger...');
                            obj.hModel.hPhotostim.triggerStim();
                            
                        case 's';
                            disp('Sending photostim sync...');
                            obj.hModel.hPhotostim.triggerSync();
                            
                        case 'a';
                            disp('Aborting photostim...');
                            obj.hModel.hPhotostim.abort();
                    end
                    obj.pshk_zeroshit = 0;
                else
                    if n ~= 0
                        v = 10 * obj.pshk_zeroshit + n;
                        fprintf('Sending stimulus %d command...\n', v);
                        obj.hModel.hPhotostim.onDemandStimNow(v);
                        
                        obj.pshk_zeroshit = 0;
                    else
                        obj.pshk_zeroshit = obj.pshk_zeroshit + 1;
                        fprintf('Enter second digit to output stimulus %d*...\n',obj.pshk_zeroshit);
                    end
                end
            end
        end
        
        function dblClickStimGroup(obj, idx)
            if obj.hModel.hPhotostim.active
                if strcmp(obj.hModel.hPhotostim.stimulusMode, 'onDemand')
                    fprintf('Sending stimulus %d command...\n', idx);
                    obj.hModel.hPhotostim.onDemandStimNow(idx);
                end
            else
%                 obj.mroiGuiSetGroup(obj.hModel.hPhotostim.stimRoiGroups(idx), 'StimulusField');
                obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hPhotostim.stimRoiGroups(idx),obj.hModel.hPhotostim.stimScannerset,'stimulation');
                obj.hRoiGroupEditor.defaultStimPower = inf;
                obj.showGUI('RoiGroupEditor');
            end
        end
        
        function changePhotostimTrigger(obj)
            try
                sel = get(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value');
                v = get(obj.hGUIData.photostimControlsV5.etTrigTerm, 'string');
                
                switch sel
                    case 1 %PFI term
                        v = round(str2double(v));
                        if isnan(v) || v < 1
                            v = 1;
                        end
                        obj.hModel.hPhotostim.autoTriggerPeriod = 0;
                        obj.hModel.hPhotostim.stimTriggerTerm = v;
                    case 2 %Frame clock
                        obj.hModel.hPhotostim.autoTriggerPeriod = 0;
                        obj.hModel.hPhotostim.stimTriggerTerm = -1;
                    case 3 %Auto s
                        obj.hModel.hPhotostim.autoTriggerPeriod = str2double(v);
                        obj.hModel.hPhotostim.stimTriggerTerm = 1;
                end
            catch ME
                obj.changedPhotostimTrigger();
                ME.rethrow();
            end
        end
        
        function changedPhotostimTrigger(obj,~,~)
            if obj.hModel.hPhotostim.stimTriggerTerm < 0
                set(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value', 2)
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'visible', 'off');
            elseif obj.hModel.hPhotostim.autoTriggerPeriod > 0
                set(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value', 3)
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'visible', 'on');
                v = num2str(obj.hModel.hPhotostim.autoTriggerPeriod);
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'string', v);
            else 
                set(obj.hGUIData.photostimControlsV5.pmTrigSource, 'value', 1)
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'visible', 'on');
                v = num2str(obj.hModel.hPhotostim.stimTriggerTerm);
                set(obj.hGUIData.photostimControlsV5.etTrigTerm, 'string', v);
            end
        end
        
        function changePhotostimSync(obj)
            try
                sel = get(obj.hGUIData.photostimControlsV5.pmSyncSource, 'value');
                v = get(obj.hGUIData.photostimControlsV5.etSyncTerm, 'string');

                switch sel
                    case 1 %PFI term
                        v = str2double(v);
                        if isnan(v) || v < 0
                            v = [];
                        end
                        obj.hModel.hPhotostim.syncTriggerTerm = v;
                    case 2 %Frame clock
                        obj.hModel.hPhotostim.syncTriggerTerm = -1;
                end
            catch ME
                obj.changedPhotostimSync();
                ME.rethrow();
            end
        end
        
        function changedPhotostimSync(obj,~,~)
            if obj.hModel.hPhotostim.syncTriggerTerm < 0
                set(obj.hGUIData.photostimControlsV5.pmSyncSource, 'value', 2)
                set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'visible', 'off');
            else 
                set(obj.hGUIData.photostimControlsV5.pmSyncSource, 'value', 1)
                v = num2str(obj.hModel.hPhotostim.syncTriggerTerm);
                set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'string', v);
                set(obj.hGUIData.photostimControlsV5.etSyncTerm, 'visible', 'on');
            end
        end
        
        function setPhotostimLogging(obj,v)
            try
                obj.hModel.hPhotostim.logging = v;
            catch ME
                obj.loggingErr(ME,'logging');
            end
        end
        
        function setPhotostimMonitor(obj,v)
            try
                obj.hModel.hPhotostim.monitoring = v;
            catch ME
                obj.loggingErr(ME,'monitoring');
            end
        end
        
        function loggingErr(obj, ME, var)
            obj.hModel.hPhotostim.logging = obj.hModel.hPhotostim.logging;
            
            if strncmp(ME.message, 'Photostim feedback calibration is invalid.',42);
                msg = [ME.message ' Calibrate now?'];
                if strcmp('Calibrate', questdlg(msg,'ScanImage','Cancel','Calibrate','Cancel'))
                    v = obj.calibratePhotostimMonitor();
                    obj.hModel.hPhotostim.(var) = v;
                else
                    obj.hModel.hPhotostim.(var) = false;
                end
            else
                obj.hModel.hPhotostim.(var) = obj.hModel.hPhotostim.(var);
                warndlg(ME.message,'ScanImage');
            end
        end
        
        function v = calibratePhotostimMonitor(obj)
            try
                obj.hModel.hPhotostim.calibrateMonitorAndOffset();
                v = true;
            catch ME
                warndlg(ME.message,'ScanImage');
                v = false;
            end
        end
        
        function editIntegrationFieldGroup(obj,src,evnt)
%             obj.mroiGuiSetGroup(obj.hModel.hIntegrationRoiManager.roiGroup, 'IntegrationField');
            obj.hRoiGroupEditor.setEditorGroupAndMode(obj.hModel.hIntegrationRoiManager.roiGroup,obj.hModel.hScan2D.scannerset,'analysis');
            obj.showGUI('RoiGroupEditor');
        end
        
        function changedExtTrigEnable(obj,src,evnt)
            h=obj.hGUIData.mainControlsV4.pbExternalTrig;
            if obj.hModel.extTrigEnable
                set(h,'BackgroundColor','green');
            else
                set(h,'BackgroundColor',[0.9412 0.9412 0.9412]);
            end
        end
        
        function changedAcqState(obj,~,~)
            hFocus = obj.hGUIData.mainControlsV4.focusButton;
            hGrab = obj.hGUIData.mainControlsV4.grabOneButton;
            hLoop = obj.hGUIData.mainControlsV4.startLoopButton;
            fAbort = obj.hGUIData.mainControlsV4.fAbort;
            gAbort = obj.hGUIData.mainControlsV4.gAbort;
            lAbort = obj.hGUIData.mainControlsV4.lAbort;
            hPoint = obj.hGUIData.mainControlsV4.tbPoint;
            hStat = obj.hGUIData.mainControlsV4.statusString;
            
            statusWindow = obj.hGuiClasses.StatusWindow;
            statusWindow.acqState = obj.hModel.acqState;
            saveButtonUsr = obj.hGUIData.mainControlsV4.pbSaveUsr;
            saveButtonCfg = obj.hGUIData.mainControlsV4.pbSaveCfg;
            loadButtonUsr = obj.hGUIData.mainControlsV4.pbLoadUsr;
            loadButtonCfg = obj.hGUIData.mainControlsV4.pbLoadCfg;
            
            switch obj.hModel.acqState
                case 'idle'
                    if obj.hModel.hCycleManager.active
                        obj.startCycleWaitStatusTimer();
                        obj.updateCycleWaitStatus();
                        loopButtonState();
                    else
                        stop(obj.hCycleWaitTimer);
                        hStat.String = obj.hModel.acqState;
                        
                        set([hFocus hGrab hLoop],'Enable','on');
                        set([hFocus hGrab hLoop],'Visible','on');
                        set([fAbort gAbort lAbort],'Visible','off');
                        set([fAbort gAbort lAbort],'Enable','on');
                        
                        set(hPoint,'String','POINT','ForegroundColor',[0 .6 0],'Enable','on');
                        set(hPoint,'Value',false);
                        set([saveButtonUsr saveButtonCfg], 'Enable', 'on');
                        set([loadButtonUsr loadButtonCfg], 'Enable', 'on');
                    end
                    
                case 'focus'
                    hStat.String = obj.hModel.acqState;
                    set([hFocus hGrab hLoop],'Visible','off');
                    set([fAbort gAbort lAbort],'Visible','off');
                    set([fAbort gAbort lAbort],'Enable','on');
                    set(hPoint,'Enable','off');
                    set(fAbort,'Visible','on');
                    set([saveButtonUsr saveButtonCfg], 'Enable', 'off');
                    set([loadButtonUsr loadButtonCfg], 'Enable', 'off');
                    
                case 'grab'
                    hStat.String = obj.hModel.acqState;
                    set([hFocus hGrab hLoop],'Visible','off');
                    set([fAbort gAbort lAbort],'Visible','off');
                    set([fAbort gAbort lAbort],'Enable','on');
                    set(hPoint,'Enable','off');
                    set(gAbort,'Visible','on');
                    set([saveButtonUsr saveButtonCfg], 'Enable', 'off');
                    set([loadButtonUsr loadButtonCfg], 'Enable', 'off')
                    
                case {'loop' 'loop_wait'}
                    hStat.String = strrep(obj.hModel.acqState,'_',' ');
                    loopButtonState();
                    
                case 'point'
                    hStat.String = obj.hModel.acqState;
                    set(hPoint,'String','PARK','ForegroundColor','r');
                    set(hPoint,'Value',true);
                    set([hFocus hGrab hLoop],'enable','off');
                    
                    %TODO: Maybe add 'error' state??
            end
            
            drawnow();
            
            function loopButtonState
                set([hFocus hGrab hLoop],'Visible','off');
                set([fAbort gAbort lAbort],'Visible','off');
                set([fAbort gAbort lAbort],'Enable','on');
                set(hPoint,'Enable','off');
                set(lAbort,'Visible','on');
                set([saveButtonUsr saveButtonCfg], 'Enable', 'off');
                set([loadButtonUsr loadButtonCfg], 'Enable', 'off')
            end
        end
        
        function startCycleWaitStatusTimer(obj)
            if ~strcmp(obj.hCycleWaitTimer.Running, 'on')
                start(obj.hCycleWaitTimer);
            end
        end
        
        function updateCycleWaitStatus(obj,varargin)
            hStat = obj.hGUIData.mainControlsV4.statusString;
            wp = obj.hModel.hCycleManager.waitParams;
            if isempty(wp)
                stop(obj.hCycleWaitTimer);
            else
                rem = wp.delay - toc(wp.waitStartTime);
                if rem >= 0
                    hStat.String = sprintf('cycle delay (%d)',floor(rem));
                else
                    stop(obj.hCycleWaitTimer);
                end
            end
        end
        
        function changedScanAngleMultiplierSlow(obj,~,~)
            s = obj.hGUIData.configControlsV4;
            hForceSquareCtls = [s.cbForceSquarePixel s.cbForceSquarePixelation];
            
            if obj.hModel.hRoiManager.scanAngleMultiplierSlow == 0
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',1);
                set(hForceSquareCtls,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.tbToggleLinescan,'Value',0);
                set(hForceSquareCtls,'Enable','on');
            end
        end
        
        function changedisprope(obj,~,~)
            obj.cfgLinePhaseSlider();
        end
        
        function changedScanFramePeriod(obj,~,~)
            if isnan(obj.hModel.hRoiManager.scanFramePeriod)
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',[0.9 0 0]);
                set(obj.hGUIData.fastZControlsV4.etVolumeRate,'BackgroundColor',[0.9 0 0]);
            else
                set(obj.hGUIData.configControlsV4.etFrameRate,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
                set(obj.hGUIData.fastZControlsV4.etVolumeRate,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
            end
        end
        
        function changedChannelDisplay(obj,~,~)
            for chan = 1:obj.hModel.hChannels.channelsAvailable
                hFig = obj.hModel.hDisplay.hFigs(chan);
                wasVisible = strcmp(get(hFig,'visible'),'on');
                activate = ismember(chan,obj.hModel.hChannels.channelDisplay);
                
                if activate
                    if ~wasVisible && obj.initComplete
                        set(hFig,'visible','on'); % only set property when it is changed to reduce flickering of the figure window
                    end
                    set(hFig,'UserData','active');
                else
                    set(hFig,'UserData','');
                end
                
                if chan < 5
                    set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',chan)), 'Value', activate);
                end
            end
            
            for chan = obj.hModel.hChannels.channelsAvailable+1:4
                set(obj.hGUIData.imageControlsV4.(sprintf('tbCh%d',chan)), 'Value', false);
            end
            
            for chan = obj.hModel.hChannels.channelsAvailable+1:numel(obj.hModel.hDisplay.hFigs)
                set(obj.hModel.hDisplay.hFigs(chan),'visible','off');
            end
        end
        
        function changedForceSquarePixelation(obj,~,~)
            if obj.hModel.hRoiManager.forceSquarePixelation
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','off');
            else
                set(obj.hGUIData.configControlsV4.etLinesPerFrame,'Enable','on');
            end
        end
        
        function pixPerLineCB(obj,~,~)
            itms = get(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string');
            [tf, v] = ismember(num2str(obj.hModel.hRoiManager.pixelsPerLine), itms);
            if ~tf
                itms{end+1} = num2str(obj.hModel.hRoiManager.pixelsPerLine);
                set(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'string', itms);
                v = numel(itms);
            end
            set(obj.hGUIData.configControlsV4.pmPixelsPerLine, 'value', v);
            
            obj.changedPowerBoxes();
        end
        
        function changeScanZoomFactor(obj,hObject,absIncrement,lastVal, handles)
            newVal = get(hObject,'Value');
            currentZoom = obj.hModel.hRoiManager.scanZoomFactor;
            
            if newVal > lastVal
                if currentZoom + absIncrement > 99.9
                    newZoom = 99.9;
                else
                    newZoom = currentZoom + absIncrement;
                end
            elseif newVal < lastVal
                if currentZoom - absIncrement < 1
                    newZoom = 1;
                else
                    newZoom = currentZoom - absIncrement;
                end
            else
                newZoom = currentZoom;
            end

            obj.hModel.hRoiManager.scanZoomFactor = newZoom;
                    
            obj.lastZoomFrac = str2double(get(handles.zoomfrac, 'String'));
            obj.lastZoomOnes = str2double(get(handles.zoomones, 'String'));
            obj.lastZoomTens = str2double(get(handles.zoomtens, 'String'));

        end % function - changeScanZoomFactor
        
        function changeScanZoomFactorForEdit(obj,hObject,absIncrement,handles)

            lastZoomVal = 0;
            currVal = 0;

            switch (absIncrement)
                case .1
                    currVal = str2double(get(handles.zoomfrac,'String'));
                    lastZoomVal = obj.lastZoomFrac;
                case 1
                    currVal = str2double(get(handles.zoomones,'String'));
                    lastZoomVal = obj.lastZoomOnes;
                case 10
                    currVal = str2double(get(handles.zoomtens,'String'));
                    lastZoomVal = obj.lastZoomTens;
            end

            if isempty(currVal) || isnan(currVal) || isinf(currVal) || (currVal < 0) || (currVal > 10) || (round(currVal) ~= currVal)             
                set(hObject, 'String', num2str(lastZoomVal));
                most.idioms.warn('An invalid value was entered for the Zoom edit field.');
            else
    
                switch (absIncrement)
                    case .1
                        obj.lastZoomFrac = currVal;
                    case 1
                        obj.lastZoomOnes = currVal;
                    case 10
                        obj.lastZoomTens = currVal;
                end
                newZoom = (obj.lastZoomTens * 10) + (obj.lastZoomOnes) + (obj.lastZoomFrac * 0.1);    %currentZoom + absIncrement;

                if (newZoom < 1)
                    newZoom = 1;
                    obj.lastZoomFrac = 0;
                    obj.lastZoomOnes = 1;
                    obj.lastZoomTens = 0;
                    set(handles.zoomfrac, 'String', '0');
                    set(handles.zoomones, 'String', '1');
                    set(handles.zoomtens, 'String', '0');
                end
            
                obj.hModel.hRoiManager.scanZoomFactor = newZoom;
        
            end % else
            
        end % function - changeScanZoomFactorForEdit
        
        function changedLogEnable(obj,~,~)
            hLoggingControls = [obj.hGUIData.mainControlsV4.baseName obj.hGUIData.mainControlsV4.baseNameLabel ...
                obj.hGUIData.mainControlsV4.fileCounter obj.hGUIData.mainControlsV4.fileCounterLabel ...
                obj.hGUIData.mainControlsV4.stFramesPerFile obj.hGUIData.mainControlsV4.etFramesPerFile ...
                obj.hGUIData.mainControlsV4.cbFramesPerFileLock obj.hGUIData.mainControlsV4.etNumAvgFramesSave ...
                obj.hGUIData.mainControlsV4.stNumAvgFramesSave obj.hGUIData.mainControlsV4.pbIncAcqNumber];
            
            if obj.hModel.hChannels.loggingEnable
                set(obj.hGUIData.mainControlsV4.cbAutoSave,'BackgroundColor',[0 .8 0]);
                set(hLoggingControls,'Enable','on');
            else
                set(obj.hGUIData.mainControlsV4.cbAutoSave,'BackgroundColor',[1 0 0]);
                set(hLoggingControls,'Enable','off');
            end
        end
        
        function setSavePath(obj,~,~)
          %  'entry function'
            folder_name = uigetdir(obj.hModel.hScan2D.logFilePath);
            
            if folder_name ~= 0
                obj.hModel.hScan2D.logFilePath = folder_name;
            end
            %'exit function'
        end
        
        function changedLogFilePath(obj,~,~)
            path_ = obj.hModel.hScan2D.logFilePath;
            if isempty(path_)
                path_ = ''; % ensure datatype char
            end 
            set(obj.hGUIData.mainControlsV4.pbSetSaveDir,'TooltipString',path_);
        end
        
        %%% CFG CONFIG 
        function changedCfgFilename(obj,~,~)
            cfgFilename = obj.hModel.hConfigurationSaver.cfgFilename;
            [~,fname] = fileparts(cfgFilename);
            
            hCtl = obj.hGUIData.mainControlsV4.configName;
            hCtl.String = fname;
        end
        
        %%% FASTCFG 
        function changedFastCfgCfgFilenames(obj,~,~)
            fastCfgFNames = obj.hModel.hConfigurationSaver.fastCfgCfgFilenames;
            tfEmpty = cellfun(@isempty,fastCfgFNames);
            set(obj.hMainPbFastCfg(tfEmpty),'Enable','off');
            set(obj.hMainPbFastCfg(~tfEmpty),'Enable','on');
            
            obj.changedFastCfgAutoStartTf();
        end
        
        function changedFastCfgAutoStartTf(obj,~,~)
            autoStartTf = obj.hModel.hConfigurationSaver.fastCfgAutoStartTf;
            
            defaultBackgroundColor = get(0,'defaultUicontrolBackgroundColor');
            set(obj.hMainPbFastCfg(autoStartTf),'BackGroundColor',[0 1 0]);
            set(obj.hMainPbFastCfg(~autoStartTf),'BackGroundColor',defaultBackgroundColor);
        end
        
        %%% USR CONFIG
        function changedUsrFilename(obj,~,~)
            usrFilename = obj.hModel.hConfigurationSaver.usrFilename;
            [~,fname] = fileparts(usrFilename);
            
            hCtl = obj.hGUIData.mainControlsV4.userSettingsName;
            hCtl.String = fname;
        end
        
        function changedCfgLoading(obj,~,~)
            if ~obj.hModel.hConfigurationSaver.cfgLoadingInProgress
                %cfg just finished loading. set mroi gui roi group to imaging so that
                %it is not left editing a roi group that no longer exists
                obj.editImagingRoiGroup(false);
                obj.updateScanControls();
            end
        end
        
        function changedUsrPropList(obj,~,~)
            % This is done because the user is given the ability to modify
            % the values of properties in the "User Settings" GUI.
            usrPropSubsetCurrent = obj.hModel.hConfigurationSaver.usrPropList;
            usrPropSubsetCurrent_ = obj.hModel.hConfigurationSaver.usrPropList;
            NUsrPropSubsetCurrent = numel(usrPropSubsetCurrent);
            
            % remove previous listeners for userSettingsV4
            delete(obj.usrSettingsPropListeners);
            
            % add new listeners
            listenerObjs = event.proplistener.empty(0,1);
            for c = 1:NUsrPropSubsetCurrent
                pname = usrPropSubsetCurrent{c};
                %The problem here is that the function
                %changedCurrentUsrProp carries only the property name in
                %the object that holds the signal. What I really need to do
                %is encode the full property somehow.
                listenerObjs(c) = obj.hModel.mdlSetPropListenerFcn(pname,'PostSet',@(src,evt,fullname)obj.changedCurrentUsrPropCallback(src,evt,pname));
                usrPropSubsetCurrent_{c} = regexprep(pname,'\.','_');
            end
            obj.usrSettingsPropListeners = listenerObjs;
            
            % BEGIN CODE TO SET USER SETTINGS STRUCT AND PASS TO GUI.
            % Update currentUsrProps table to use new property subset
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.reset();
            formatStruct = struct('format','char','info',[]); % xxx explain char
            formatCell = num2cell(repmat(formatStruct,NUsrPropSubsetCurrent,1));
            
            % The following is used to create the struct that is passed
            % onto the User Settings GUI. This struct is used by
            % most.gui.control.PropertyTable to fill in the "Current USR
            % Properties" table. The current issue is that the names of the
            % properties are used as keys, and therefore they cause
            % cell2struct to break because the properties have '.'s in
            % their name.
            metadata = cell2struct(formatCell,usrPropSubsetCurrent_,1);
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.addProps(metadata);
            
            % Manually fire listeners for each prop in usrPropSubsetCurrent
            % so that the currentUsrProps table updates
            for c = 1:NUsrPropSubsetCurrent
                pname = usrPropSubsetCurrent{c};
                obj.changedCurrentUsrProp(pname);
            end
            
            % Update specifyCurrentUsrProps table
            data = get(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data');
            availableUsrProps = data(:,1);
            tfInCurrentUsrSubset = ismember(availableUsrProps,usrPropSubsetCurrent);
            data(:,2) = num2cell(tfInCurrentUsrSubset);
            set(obj.hGUIData.userSettingsV4.tblSpecifyUsrProps,'Data',data);
        end
        
        function changedCurrentUsrPropCallback(obj,~,~,fullname)
            % propName = src.Name;
            % propObj = evt.AffectedObject;
            % src and evt are unused - they are only there so I can pass in
            % the constant property name 'fullname' in the callback
            val = lclRecursePropGet(obj.hModel,fullname);
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.encodeFcn(regexprep(fullname,'\.','_'),val);
            
            function val = lclRecursePropGet(obj, propName)
                %Detect if pname is a submodel reference by looking for a '.'.
                [baseName, propName] = strtok(propName,'.');
                if ~isempty(propName)
                    propName = propName(2:end);
                    val = lclRecursePropGet(obj.(baseName),propName);
                else
                    val = obj.(baseName);
                end
            end
        end
        
        function changedCurrentUsrProp(obj,varargin)
            switch nargin
                case 2
                    propName = varargin{1};
                    propObj  = [];
                case 3
                    src = varargin{1};
                    propName = src.Name;
                    propObj  = varargin{2}.AffectedObject;
                otherwise
                    assert(false,'Invalid number of args.');
            end
            propName = regexprep(propName,'_','\.');
            
            if isempty(propObj)
                val = lclRecursePropGet(obj.hModel, propName);
            else
                val = propObj.(propName);
            end
            
            obj.hGUIData.userSettingsV4.pcCurrentUSRProps.encodeFcn(regexprep(propName,'\.','_'),val);
            
            function val = lclRecursePropGet(obj, propName)
                %Detect if pname is a submodel reference by looking for a '.'.
                [baseName, propName] = strtok(propName,'.');
                if ~isempty(propName)
                    propName = propName(2:end);
                    val = lclRecursePropGet(obj.(baseName),propName);
                else
                    val = obj.(baseName);
                end
            end
        end
        
        % This looks similar to Controller.updateModel for PropControls.
        % However updateModel() does not quite work as when there is a
        % failure, it reverts using Controller.updateViewHidden. This will
        % not work as the currentUsrProps are not currently participating
        % in the prop2Control struct business.
        function changeCurrentUsrProp(obj,hObject,eventdata,handles)
            [status,propName,propVal] = ...
                obj.hGUIData.userSettingsV4.pcCurrentUSRProps.decodeFcn(hObject,eventdata,handles);
            propName = regexprep(propName,'_','\.');
            
            switch status
                case 'set'
                    try
                        % obj.hModel.(propName) = propVal;
                        lclRecursePropSet(obj.hModel, propName, propVal);
                    catch ME
                        obj.changedCurrentUsrProp(propName);
                        switch ME.identifier
                            case 'most:InvalidPropVal'
                                % no-op
                            case 'PDEPProp:SetError'
                                throwAsCaller(obj.DException('','ModelUpdateError',ME.message));
                            otherwise
                                ME.rethrow();
                        end
                    end
                case 'revert'
                    obj.changedCurrentUsrProp(propName);
                otherwise
                    assert(false);
            end
            
            function lclRecursePropSet(obj, propName, val)
                %Detect if pname is a submodel reference by looking for a '.'.
                [baseName, propName] = strtok(propName,'.');
                if ~isempty(propName)
                    propName = propName(2:end);
                    lclRecursePropSet(obj.(baseName),propName,val);
                else
                    obj.(baseName) = val;
                end
            end
        end
        
        function specifyCurrentUsrProp(obj,hObject,eventdata,handles)
            data = get(hObject,'data');
            availableUsrProps = data(:,1);
            tf = cell2mat(data(:,2));
            obj.hModel.hConfigurationSaver.usrPropList = availableUsrProps(tf);
        end
        
        %%% MOTOR 
        function changeMotorPosition(obj,src,coordinateIdx)
            newVal = str2double(get(src,'String'));
            try
                % NOTE: Indexing operation forces read of motorPosition prior to setting
                % obj.hModel.hMotors.motorPosition(coordinateIdx) = newVal;
                if coordinateIdx < 4
                    if obj.hModel.hMotors.dimNonblockingMoveInProgress(coordinateIdx)
                        most.idioms.warn('Motor is currently executing a move operation. New command ignored.');
                    else
                        pos = nan(1,3);
                        pos(coordinateIdx) = newVal;
                        obj.hModel.hMotors.motorPosition = pos;
                    end
                elseif coordinateIdx == 4 && obj.hModel.hFastZ.hasFastZ
                    if obj.hModel.hFastZ.nonblockingMoveInProgress
                        most.idioms.warn('Motor is currently executing a move operation. New command ignored.')
                        return;
                    end
                    obj.hModel.hFastZ.positionTarget = newVal;
                    obj.changedMotorPosition();
                end
            catch ME
                obj.changedMotorPosition(); % refreshes motor-Position-related GUI components
                most.idioms.reportError(ME,false);
            end
        end
        
        function changedMotorPosition(obj,~,~)
            motorPos = obj.hModel.hMotors.motorPosition;
            if ~isempty(motorPos)
                formatStr = '%.2f';
                set(obj.hGUIData.motorControlsV5.etPosX,'String',num2str(motorPos(1),formatStr));
                set(obj.hGUIData.motorControlsV5.etPosY,'String',num2str(motorPos(2),formatStr));
                set(obj.hGUIData.motorControlsV5.etPosZ,'String',num2str(motorPos(3),formatStr));
                set(obj.hGUIData.motorControlsV5.etPosR,'String',num2str(norm(motorPos(1:3)),formatStr));
                
                obj.changedFastZPosition();
            end
        end
        
        function changedFastZPosition(obj,~,~)
            if obj.hModel.hFastZ.hasFastZ
                formatStr = '%.2f';
                set(obj.hGUIData.motorControlsV5.etPosZZTarget,'String',num2str(obj.hModel.hFastZ.positionTarget,formatStr));
                set(obj.hGUIData.motorControlsV5.etPosZZ,'String',num2str(obj.hModel.hFastZ.positionAbsolute,formatStr));
            end
        end
        
        function changedStackStartEndPositionPower(obj,~,~)
            startPos = obj.hModel.hStackManager.stackZStartPos;
            endPos = obj.hModel.hStackManager.stackZEndPos;
            startPower = obj.hModel.hBeams.stackStartPower; % todo multibeam
            endPower = obj.hModel.hBeams.stackEndPower;     % todo multibeam
            
            set(obj.hGUIData.motorControlsV5.etStartPower,'String',num2str(startPower));
            set(obj.hGUIData.motorControlsV5.etEndPower,'String',num2str(endPower));
            
            if obj.hModel.hFastZ.enable
                hStartEndCtls = {'etStackStart' 'etStackEnd'};
                cellfun(@(x)set(obj.hGUIData.motorControlsV5.(x),'Enable','off'),hStartEndCtls);
            else
                zlclEnableUIControlBasedOnVal(obj.hGUIData.motorControlsV5.etStackStart,startPos,'inactive');
                zlclEnableUIControlBasedOnVal(obj.hGUIData.motorControlsV5.etStackEnd,endPos,'inactive');
            end
            
            if ~isnan(startPower)
                set(obj.hGUIData.motorControlsV5.cbUseStartPower,'Enable','on');
            else
                set(obj.hGUIData.motorControlsV5.cbUseStartPower,'Enable','off');
            end
            
            if obj.hModel.hStackManager.stackStartEndPointsDefined && obj.hModel.hBeams.stackStartEndPowersDefined
                set(obj.hGUIData.motorControlsV5.cbOverrideLz,'Enable','on');
                set(obj.hGUIData.motorControlsV5.pbOverrideLz,'Enable','on');
            else
                set(obj.hGUIData.motorControlsV5.cbOverrideLz,'Enable','off');
                set(obj.hGUIData.motorControlsV5.pbOverrideLz,'Enable','off');
            end
        end
        
        function changedStackUseStartPower(obj,~,~)
            tfUseStartPower = obj.hModel.hBeams.stackUseStartPower;
            if tfUseStartPower && ~obj.hModel.hFastZ.enable
                set(obj.hGUIData.motorControlsV5.etStartPower,'Enable','inactive');
            else
                set(obj.hGUIData.motorControlsV5.etStartPower,'Enable','off');
            end
        end
        
        function toggleShowObjectiveAngles(obj,varargin)
            hPb = obj.hGUIData.motorControlsV5.pbEnableObjectiveAngles;
            hGui = obj.hGUIs;
            
            
            if ~isempty(varargin) && ~isempty(varargin{1}) && islogical(varargin{1})
                showTf = varargin{1};
            else
                currentlyVisible = hGui.motorControlsV5.Position(3) > 70.0;
                showTf = ~currentlyVisible;
            end
            
            if showTf
                hGui.motorControlsV5.Position(3) = 109;
                hPb.String = '<';
            else
                hGui.motorControlsV5.Position(3) = 69.0;
                hPb.String = '>';
            end            
            
        end
        
        
        %%% FAST Z        
        function changedOverrideLz(obj,~,~)
            tf = obj.hModel.hBeams.stackUserOverrideLz;
            if tf && ~obj.hModel.hFastZ.enable
                set(obj.hGUIData.motorControlsV5.etEndPower,'Enable','inactive');
            else
                set(obj.hGUIData.motorControlsV5.etEndPower,'Enable','off');
            end
        end
        
        function changedFastZEnable(obj,~,~)
            obj.changedStackStartEndPositionPower();
            obj.changedStackUseStartPower();
            obj.changedOverrideLz();
            if obj.hModel.hFastZ.enable && ~obj.hModel.hRoiManager.isLineScan
                set(obj.hGUIData.mainControlsV4.framesTotal,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.framesTotal,'Enable','on');
            end
        end
        
        function changedWaveformType(obj,~,~)
            switch obj.hModel.hFastZ.waveformType
                case 'sawtooth'
                    set(obj.hGUIData.fastZControlsV4.pmScanType, 'Value', 1);
                    set(obj.hGUIData.fastZControlsV4.cbSpecifyZs, 'Visible', 'off');
                    
                case 'step'
                    set(obj.hGUIData.fastZControlsV4.pmScanType, 'Value', 2);
                    set(obj.hGUIData.fastZControlsV4.cbSpecifyZs, 'Visible', 'on');
            end
            
            obj.changedArbZs();
        end
        
        function changedArbZs(obj,~,~)
            uz = {'lblUserZs' 'etUserZs'};
            nz = {'stNumZSlices' 'etNumZSlices' 'stZStepPerSlice' 'etZStepPerSlice' 'cbCenteredStack'};
            
            if obj.hModel.hFastZ.useArbitraryZs && strcmp(obj.hModel.hFastZ.waveformType, 'step')
                cellfun(@(s)set(obj.hGUIData.fastZControlsV4.(s),'Visible','off'),nz);
                cellfun(@(s)set(obj.hGUIData.fastZControlsV4.(s),'Visible','on'),uz);
            else
                cellfun(@(s)set(obj.hGUIData.fastZControlsV4.(s),'Visible','off'),uz);
                cellfun(@(s)set(obj.hGUIData.fastZControlsV4.(s),'Visible','on'),nz);
            end
        end
        
        function changeWaveformType(obj, val)
            switch val
                case 1
                    obj.hModel.hFastZ.waveformType = 'sawtooth';
                    
                case 2
                    obj.hModel.hFastZ.waveformType = 'step';
            end
        end
        
        function tuneActuator(obj)
            if ~obj.hModel.hFastZ.hasFastZ
                return;
            end
            
            if most.idioms.isValidObj(obj.hFastZTuneFig)
                figure(obj.hFastZTuneFig);
            else
                resp = [];
                pltResp = [];
                avg = 10;
                obj.hFastZTuneFig = figure('Name','FastZ Actuator Tuning','NumberTitle','off','Color','White','MenuBar','none','ToolBar','figure','tag','FASTZTUNING');
                obj.registerGUI(obj.hFastZTuneFig);
                hmain=most.idioms.uiflowcontainer('Parent',obj.hFastZTuneFig,'FlowDirection','TopDown');
                    obj.hFastZTuneAxes = axes('Parent',hmain,'FontSize',12,'FontWeight','Bold');
                    hold(obj.hFastZTuneAxes,'on');
                    xlabel('Time (ms)','FontWeight','Bold');
                    ylabel('Position (um)','FontWeight','Bold');
                    grid(obj.hFastZTuneAxes,'on');
                    
                    hbottom = most.idioms.uiflowcontainer('Parent',hmain,'FlowDirection','LeftToRight');
                    set(hbottom,'HeightLimits',[32 32]);
                        ctl1 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@updatePlot,'string','Update Waveform');
                        ctl2 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@testWvfm,'string','Test Actuator');
                        ctl3 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@clrFigure,'string','Clear Figure');
                        set([ctl1 ctl2 ctl3],'WidthLimits',[120 120]);
                        
                        stAF = uicontrol('parent',hbottom,'style','text','string','Sample Average Factor', 'HorizontalAlignment', 'right');
                        etAF = uicontrol('parent',hbottom,'style','edit','string',num2str(avg),'Callback',@changeAvgFac);
                        set(etAF,'WidthLimits',[40 40]);
                        set([stAF etAF],'HeightLimits',[20 20]);
                    
                    updatePlot();
            end
            
            function changeAvgFac(varargin)
                avg = floor(str2double(get(etAF,'String')));
                avg(isnan(avg)) = 1;
                avg(avg < 1) = 1;
                avg(avg > 1000) = 1000;
                set(etAF,'String',num2str(avg));
                
                if most.idioms.isValidObj(obj.hFastZResponsePlot)
                    avgSamples();
                    set(obj.hFastZResponsePlot, 'YData', repmat(pltResp,3,1));
                end
            end
            
            function avgSamples()
                if avg > 1
                    N = length(resp);
                    inds = (1:avg) - ceil(avg/2);
                    inds = repmat(inds,N,1) + repmat((1:N)',1,avg);
                    inds(inds<1) = inds(inds<1) + N;
                    inds(inds>N) = inds(inds>N) - N;
                    pltResp = resp(inds);
                    pltResp = mean(pltResp,2);
                else
                    pltResp = resp;
                end
            end
            
            function testWvfm(varargin)
                most.idioms.safeDeleteObj(obj.hFastZCmdSigPlot);
                
                [to,desPos,cmd,ti,resp] = obj.hModel.hFastZ.testActuator();
                avgSamples();
                updatePlot([],[],to,desPos,cmd,ti,pltResp);
            end
        
            function updatePlot(~,~,totput,desWvfm,cmdWvfm,tinput,respWvfm)
                if most.idioms.isValidObj(obj.hFastZTuneFig)
                    if obj.hModel.hFastZ.hasFastZ
                        if nargin < 3 && most.idioms.isValidObj(obj.hFastZResponsePlot)
                            set(obj.hFastZResponsePlot,'LineWidth',1,'LineStyle','--');
                        else
                            most.idioms.safeDeleteObj(obj.hFastZResponsePlot);
                        end
                        most.idioms.safeDeleteObj(obj.hFastZDesiredWvfmPlot);
                        most.idioms.safeDeleteObj(obj.hFastZCmdSigPlot);
                        most.idioms.safeDeleteObj(obj.hFastZPlotLines);
                        
                        if obj.hModel.hStackManager.isFastZ
                            zs = obj.hModel.hStackManager.zs;
                        else
                            zs = obj.hModel.hFastZ.positionTarget;
                        end
                        
                        scannerSet = obj.hModel.hScan2D.scannerset;
                        if nargin < 3
                            fb = obj.hModel.hFastZ.numDiscardFlybackFrames;
                            wvType = obj.hModel.hFastZ.waveformType;
                            zPowerReference = 0;
                            [totput, desWvfm, cmdWvfm] = scannerSet.zWvfm(obj.hModel.hScan2D.currentRoiGroup,zPowerReference,zs,fb,wvType);
                            respWvfm = [];
                        end
                        
                        totput = totput*1000;
                        trg = totput(end);
                        totput = [totput-totput(end);totput;totput+totput(end)];
                        desWvfm = repmat(desWvfm,3,1);
                        cmdWvfm = repmat(cmdWvfm,3,1);
                        
                        fp = obj.hModel.hRoiManager.scanFramePeriod*1000;
                        fbt = scannerSet.scanners{2}.flybackTimeSeconds*1000;
                        if numel(zs) > 1
                            obj.hFastZPlotLines = plot([0 0],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            obj.hFastZPlotLines(end+1) = plot((fp-fbt)*ones(1,2),[-10e8,10e8],'r--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            for i = 1:(numel(zs)-1)
                                obj.hFastZPlotLines(end+1) = plot(i*(fp)*ones(1,2),[-10e8,10e8],'g--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                                obj.hFastZPlotLines(end+1) = plot(((i+1)*fp-fbt)*ones(1,2),[-10e8,10e8],'r--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            end
                            obj.hFastZPlotLines(end+1) = plot([trg trg],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                        else
                            obj.hFastZPlotLines = plot([0 0],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            obj.hFastZPlotLines(end+1) = plot((fp-fbt)*ones(1,2),[-10e8,10e8],'r--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                            obj.hFastZPlotLines(end+1) = plot([trg trg],[-10e8,10e8],'k--','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                        end
                        
                        obj.hFastZDesiredWvfmPlot = plot(totput,desWvfm,'k-','Parent',obj.hFastZTuneAxes,'LineWidth',2);
                        obj.hFastZCmdSigPlot = plot(totput,cmdWvfm,'b-','Parent',obj.hFastZTuneAxes,'LineWidth',1);
                        
                        if ~isempty(respWvfm)
                            tinput = tinput*1000;
                            tinput = [tinput-tinput(end);tinput;tinput+tinput(end)];
                            respWvfm = repmat(respWvfm,3,1);
                            obj.hFastZResponsePlot = plot(tinput,respWvfm,'r-','Parent',obj.hFastZTuneAxes,'LineWidth',2);
                            uistack(obj.hFastZDesiredWvfmPlot, 'top')
                            uistack(obj.hFastZCmdSigPlot, 'top')
                        end
                        
                        xlim(obj.hFastZTuneAxes,[-.1*trg 1.1*trg]);
                        mm = [min([desWvfm; respWvfm]) max([desWvfm; respWvfm])];
                        rg = mm(2)-mm(1);
                        if rg == 0
                            rg = 1;
                        end
                        ylim(obj.hFastZTuneAxes,[mm(1)-rg*.1 mm(2)+rg*.1]);
                        
                        if most.idioms.isValidObj(obj.hFastZResponsePlot)
                            if isempty(respWvfm)
                                n = 'Actual (old)';
                            else
                                n = 'Actual';
                            end
                            l = legend([obj.hFastZDesiredWvfmPlot obj.hFastZCmdSigPlot obj.hFastZResponsePlot], {'Desired' 'Cmd' n},'location','NorthWest');
                        else
                            l = legend([obj.hFastZDesiredWvfmPlot obj.hFastZCmdSigPlot], {'Desired' 'Cmd'},'location','NorthWest');
                        end
                        
                        l.Units = 'normalized';
                        l.Position(1) = .25;
                    else
                        clrFigure();
                    end
                end
            end
            
            function clrFigure(varargin)
                most.idioms.safeDeleteObj(obj.hFastZDesiredWvfmPlot);
                most.idioms.safeDeleteObj(obj.hFastZCmdSigPlot);
                most.idioms.safeDeleteObj(obj.hFastZResponsePlot);
                most.idioms.safeDeleteObj(obj.hFastZPlotLines);
                legend(obj.hFastZTuneAxes, 'off');
            end
        end
        
        %%% Main Controls
        function changedPointButton(obj,src,~)
            if get(src,'Value')
                obj.hModel.scanPointBeam();
            else
                obj.hModel.abort();
            end
        end
        
        function changedLogFramesPerFileLock(obj,~,~)
            if obj.hModel.hScan2D.logFramesPerFileLock
                set(obj.hGUIData.mainControlsV4.etFramesPerFile,'Enable','off');
            else
                set(obj.hGUIData.mainControlsV4.etFramesPerFile,'Enable','on');
            end
        end
        
        function openConfigEditor(obj)
            if ~most.idioms.isValidObj(obj.hConfigEditor)
                obj.hConfigEditor = scanimage.guis.ConfigurationEditor([],true,true);
                obj.hConfigEditorLis = obj.hConfigEditor.addlistener('mdfUpdate', @obj.mdfUpdate);
            else
                p = obj.hConfigEditor.selectedPage;
                obj.hConfigEditor.init();
                
                if obj.openedBef && ~isempty(p);
                    obj.hConfigEditor.selectedPage = p;
                else
                    obj.hConfigEditor.selectedPage = 1;
                end
                
                obj.openedBef = true;
                obj.hConfigEditor.Visible = true;
            end
            figure(obj.hConfigEditor.hFig);
        end
        
        function mdfUpdate(obj,varargin)
            hMDF = most.MachineDataFile.getInstance();
            hMDF.load(hMDF.fileName);
            obj.hModel.reloadMdf();
        end
        
        %%% Cfg controls
        function cfgLinePhaseSlider(obj,varargin)
            sliderMin  = -1000 * obj.hModel.hScan2D.linePhaseStep;
            sliderMax  =  1000 * obj.hModel.hScan2D.linePhaseStep;
            sliderStep = obj.hModel.hScan2D.linePhaseStep / (sliderMax - sliderMin);
            Value  =  obj.hModel.hScan2D.linePhase;
            set(obj.hGUIData.configControlsV4.scanPhaseSlider,'Min',sliderMin,'Max',sliderMax,'SliderStep',[sliderStep 10*sliderStep],'Value',Value);
        end
        
        function cfgAdvancedPanel(obj,show)
            u = get(obj.hGUIs.configControlsV4,'units');
            set(obj.hGUIs.configControlsV4,'units','characters');
            
            p = get(obj.hGUIs.configControlsV4,'Position');
            if show && p(3) < 70
                p(3) = 127;
                set(obj.hGUIs.configControlsV4,'Position',p);
            elseif ~show && p(3) > 70
                p(3) = 65.4;
                set(obj.hGUIs.configControlsV4,'Position',p);
            end
            
            set(obj.hGUIs.configControlsV4,'units',u);
        end
        
        function changeScanPhaseSlider(obj,src)
            val = get(src,'Value');
            obj.hModel.hScan2D.linePhase = val;
        end
        
        function changeScanPhase(obj)
            val = get(obj.hGUIData.configControlsV4.etScanPhase,'String');
            val = str2double(val);
            
            switch obj.hModel.hScan2D.linePhaseUnits
                case 'seconds'
                    viewScaling = 1e6;
                case 'pixels'
                    viewScaling = 1;
                otherwise
                    assert(false);
            end
            
            obj.hModel.hScan2D.linePhase = val/viewScaling;
        end
        
        function changedScanPhase(obj,~,~)
            val = obj.hModel.hScan2D.linePhase;
            
            switch obj.hModel.hScan2D.linePhaseUnits
                case 'seconds'
                    viewScaling = 1e6;
                case 'pixels'
                    viewScaling = 1;
                otherwise
                    assert(false);
            end
            
            set(obj.hGUIData.configControlsV4.etScanPhase,'String',num2str(val*viewScaling));
            
            minSliderVal = get(obj.hGUIData.configControlsV4.scanPhaseSlider,'Min');
            maxSliderVal = get(obj.hGUIData.configControlsV4.scanPhaseSlider,'Max');
            
            % enforce limits
            if val < minSliderVal
                val = minSliderVal;
            elseif val > maxSliderVal
                val = maxSliderVal;
            end
            
            set(obj.hGUIData.configControlsV4.scanPhaseSlider,'Value',val);
        end
        
        function calibrateLinePhase(obj)
            %assert(~strcmp(obj.hModel.acqState, 'idle'),'This operation is only available while imaging.');
            %assert(obj.hModel.hScan2D.bidirectional,'This operation must be done with bidirectional scanning enabled');
            %assert(numel(obj.hModel.hChannels.channelDisplay) > 0,'At least one channel must be selected for display');
            
            if strcmp(obj.hModel.acqState, 'idle')
                most.idioms.warn('This operation is only available while imaging.');
            elseif ~obj.hModel.hScan2D.bidirectional
                most.idioms.warn('This operation must be done with bidirectional scanning enabled');
            elseif (numel(obj.hModel.hChannels.channelDisplay) <= 0)
                most.idioms.warn('At least one channel must be selected for display');
            else
                obj.hModel.hScan2D.calibrateLinePhase();
            end
            
        end % function - calibrateLinePhase
        
        function setLineRate(obj, val)
            if ~isnan(val)
                hVarSel = obj.hGUIData.configControlsV4.pmScanRateVar;
                switch hVarSel.Value
                    case 1
                        if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                            % sample rate
                            obj.hModel.hScan2D.sampleRate = val*1e6;
                            return;
                        else
                            % pixel dwell time (ns)
                            pixelTime = val*1e-9;
                        end
                    case 2 % line rate (Hz)
                        ppl = obj.hModel.hRoiManager.linePeriod / obj.hModel.hScan2D.scanPixelTimeMean;
                        pixelTime = 1/(val * ppl);
                    case 3 % line period (us)
                        ppl = obj.hModel.hRoiManager.linePeriod / obj.hModel.hScan2D.scanPixelTimeMean;
                        pixelTime = val*1e-6/ppl;
                    otherwise
                        return
                end
                
                % calculate appropriate sample rate and pixel bin factor to
                % achieve desired pixelTime
                sampleRates = obj.hModel.hScan2D.hAcq.hAI.validSampleRates;
                sampleRates = sampleRates(sampleRates > (200000));
                
                binFs = pixelTime .* sampleRates;
                binFs(binFs < .5) = [];
                binFsR = round(binFs);
                diffs = abs(binFsR - binFs) ./ binFs;
                binFsR(diffs > 0.01) = [];
                if isempty(binFsR)
                    if isempty(binFs)
                        obj.changedLineRate();
                        return;
                    else
                        binFsR = round(binFs);
                        [~,i] = min(diffs);
                        binF = binFsR(i);
                    end
                else
                    binF = min(binFsR);
                end
                
                dts = abs(binF ./ sampleRates - pixelTime);
                [~,i] = min(dts);
                
                obj.hModel.hScan2D.pixelBinFactor = binF;
                obj.hModel.hScan2D.sampleRate = sampleRates(i);
            else
                obj.changedLineRate();
            end
        end
        
        function changedLineRateVar(obj)
            hVarSel = obj.hGUIData.configControlsV4.pmScanRateVar;
            hSldr = obj.hGUIData.configControlsV4.slLineRate;
            switch hVarSel.Value
                case 1
                    if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                        % sample rate (MHz)
                        sliderMax = obj.hModel.hScan2D.maxSampleRate*1e-6;
                        sliderMin = 1e-3;
                    else
                        % pixel dwell time (ns)
                        sliderMax = 10000;
                        sliderMin = 10;
                    end
                case 2 % line rate (Hz)
                    sliderMax = 5000;
                    sliderMin = 10;
                case 3 % line period (us)
                    sliderMax = 10000;
                    sliderMin = 10;
                otherwise
                    return
            end
            
            % configure the slider max and min
            sliderStep = min(1 / (sliderMax - sliderMin),1);
            set(hSldr,'Min',sliderMin,'Max',sliderMax,'SliderStep',[sliderStep sliderStep]);
            
            obj.changedLineRate();
        end
        
        function changedLineRate(obj,~,~)
            hVarSel = obj.hGUIData.configControlsV4.pmScanRateVar;
            hSldr = obj.hGUIData.configControlsV4.slLineRate;
            
            switch hVarSel.Value
                case 1
                    if strcmp(obj.hModel.hRoiManager.scanType, 'line')
                        % sample rate
                        v = obj.hModel.hScan2D.sampleRate * 1e-6;
                        set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.3f',v));
                    else
                        % pixel dwell time
                        v = obj.hModel.hScan2D.scanPixelTimeMean * 1e9;
                        set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.1f',v));
                    end
                case 2 % line rate (Hz)
                    v = 1/obj.hModel.hRoiManager.linePeriod;
                    set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.1f',v));
                case 3 % line period (us)
                    v = obj.hModel.hRoiManager.linePeriod * 1e6;
                    set(obj.hGUIData.configControlsV4.etLineRate,'String',sprintf('%.1f',v));
                otherwise
                    return
            end
            
            v(isnan(v)) = 0;
            switch class(obj.hModel.hScan2D)
                case 'scanimage.components.scan2d.ResScan'
                    set(hSldr, 'Value', 10);
                case 'scanimage.components.scan2d.LinScan'
                    v = min(max(v, hSldr.Min), hSldr.Max);
                    set(hSldr, 'Value', v);
                case 'scanimage.components.scan2d.SlmScan'
                    set(hSldr, 'Value', 10);
                otherwise
                    error('Unknown Scan2D class: %s',class(obj.hModel.hScan2D));
            end
        end
        
        %%% PMTs
        function changePmtsPowersOn(obj,pmtNum,val)
            if nargin < 3 || isempty(val)
                val = false;
            end
            
            numPmts = obj.hModel.hPmts.numPmts;
            
            if numPmts > 0
                if isempty(pmtNum)
                    obj.hModel.hPmts.powersOn = repmat(val,1,numPmts);
                else
                    [powersOn, ~, ~, ~, ~] = obj.hModel.hPmts.getLastStatus();
                    obj.hModel.hPmts.setPmtPower(pmtNum, ~powersOn(pmtNum));
                end

                obj.hModel.hPmts.updateStatus();
            end
        end
        
        function changePmtsGains(obj,pmtNum,val)
            obj.gGains(:) = nan;
            obj.hModel.hPmts.setPmtGain(pmtNum, val);
            obj.hModel.hPmts.updateStatus();
            obj.changedPmtsStatus();
        end
        
        function changePmtsOffsets(obj,pmtNum,val)
            obj.gOffs(:) = nan;
            obj.hModel.hPmts.setPmtOffset(pmtNum, val);
            obj.hModel.hPmts.updateStatus();
            obj.changedPmtsStatus();
        end
        
        function changePmtsBandwidths(obj,pmtNum,val)
            obj.gBands(:) = nan;
            obj.hModel.hPmts.setPmtBandwidth(pmtNum, val);
            obj.hModel.hPmts.updateStatus();
            obj.changedPmtsStatus();
        end
        
        function pmtsResetTripped(obj,pmtNum)
            obj.hModel.hPmts.resetTripStatus(pmtNum);
            obj.hModel.hPmts.updateStatus();
        end
        
        function setPmtAutoPwr(obj,pmtNum,val)
            obj.hModel.hPmts.autoPower(pmtNum) = val;
        end
        
        function changedPmtsAutoPwr(obj,varargin)
            v = obj.hModel.hPmts.autoPower;
            for i = 1:(min(numel(v),4))
                set(obj.hGUIData.pmtControlsV5.(sprintf('cbPmt%dAutoPwr',i)), 'Value', v(i));
            end
        end
        
        function changedPmtsStatus(obj,~,~)
            [powersOn, gains, pmtsTripped, offs, bands] = obj.hModel.hPmts.getLastStatus();
            
            numControlsOnGui = 4;
            tfDr = false;
            
            if any(powersOn ~= obj.gPowers) || any(pmtsTripped ~= obj.gTrips)
                obj.gPowers = powersOn;
                obj.gTrips = pmtsTripped;
                for i = 1:min(numel(pmtsTripped),numControlsOnGui)
                    pbTag = sprintf('pbPmt%dPower',i);
                    etTag = sprintf('etPmt%dStatus',i);
                    
                    if powersOn(i)
                        pbString = 'On';
                    else
                        pbString = 'Off';
                    end
                    
                    if pmtsTripped(i)
                        etString = 'Tripped';
                        bgColor = 'r';
                    else
                        etString = 'OK';
                        if powersOn(i)
                            bgColor = 'g';
                        else
                            bgColor = 'w';
                        end
                    end
                    
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'String',pbString);
                    set(obj.hGUIData.pmtControlsV5.(pbTag),'Value',powersOn(i));
                    
                    set(obj.hGUIData.pmtControlsV5.(etTag),'String',etString);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'BackgroundColor',bgColor);
                end
                tfDr = true;
            end
            
            if any(gains ~= obj.gGains)
                obj.gGains = gains;
                for i = 1:min(numel(gains),numControlsOnGui)
                    etTag = sprintf('etPmt%dGain',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'String',gains(i));
                end
                tfDr = true;
            end
            
            if any(offs ~= obj.gOffs)
                obj.gOffs = offs;
                for i = 1:(min(numel(offs),numControlsOnGui))
                    etTag = sprintf('etPmt%dOffset',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'String',sprintf('%.3f',offs(i)));
                end
                tfDr = true;
            end
            
            if any(bands ~= obj.gBands)
                obj.gBands = bands;
                for i = 1:(min(numel(bands),numControlsOnGui))
                    etTag = sprintf('etPmt%dBandwidth',i);
                    set(obj.hGUIData.pmtControlsV5.(etTag),'String',bands(i));
                end
                tfDr = true;
            end
            
            if tfDr
                drawnow('nocallbacks');
            end
        end
        
        function changeScanRotation(obj,src,inc)
            obj.hModel.hRoiManager.scanRotation = obj.hModel.hRoiManager.scanRotation + inc;
        end
        
        function zeroScanRotation(obj,src)
            obj.hModel.hRoiManager.scanRotation = 0;
        end
        
        function changedWSConnectorEnable(obj,varargin)
            hMnuEntry = obj.hGUIData.mainControlsV4.mnu_Settings_YokeWS;            
            
            if obj.hModel.hWSConnector.enable
                hMnuEntry.Checked = 'on';
            else
                hMnuEntry.Checked = 'off';
            end
        end
		
        function changedShutterStatus(obj,src,evt)
            statusWindow = obj.hGuiClasses.StatusWindow;
            statusWindow.shuttersOpen = obj.hModel.hShutters.status;
        end
        
        function changedBeamStatus(obj,src,evt)
            statusWindow = obj.hGuiClasses.StatusWindow;
            statusWindow.pockelsValue = obj.hModel.hBeams.beamStatus;
        end
        
        function changedBeamCalibratedStatus(obj,src,evt)
            statusWindow = obj.hGuiClasses.StatusWindow;
            statusWindow.pockelsCalibrated = obj.hModel.hBeams.beamCalibratedStatus;
        end
        
        function changeDetectMotionFcn(obj,val)
            if nargin < 2 || isempty(val)
                val = [];
            end
            
            if isempty(val)
                defaultPath = fullfile(fileparts(which('scanimage')),obj.hModel.hMotionManager.FCN_BASE_PATH);
                val = most.util.selectFunctionDialog('Select a motion detection function',defaultPath);
            end
            
            if ischar(val)
                val = str2func(val);
            end
            
            obj.hModel.hMotionManager.detectMotionFcn = val;
        end
        
        function changedDetectMotionFcn(obj,src,evt)
           f = func2str(obj.hModel.hMotionManager.detectMotionFcn);
           f = regexp(f,'[^\.]*$','match','once'); % only display the function name without the package because of limit space
           set(obj.hGUIData.motionCorrectionControls.etMotionDetectionFcn, 'String', f);
        end
        
        function changeReferenceImagePreprocessFcn(obj,val)
            if nargin < 2 || isempty(val)
                val = [];
            end
            
            if isempty(val)
                defaultPath = fullfile(fileparts(which('scanimage')),obj.hModel.hMotionManager.FCN_BASE_PATH);
                val = most.util.selectFunctionDialog('Select a preprocess function',defaultPath);
            end
            
            if ischar(val)
                val = str2func(val);
            end
            
            obj.hModel.hMotionManager.referenceImagePreprocessFcn = val;
        end
        
        function changedReferenceImagePreprocessFcn(obj,src,evt)
            f = func2str(obj.hModel.hMotionManager.referenceImagePreprocessFcn);
            f = regexp(f,'[^\.]*$','match','once'); % only display the function name without the package because of limit space
            set(obj.hGUIData.motionCorrectionControls.etPreProcessFcn, 'String', f);
        end
        
        function loadMotionReferenceImage(obj)
            obj.hModel.hMotionManager.loadReferenceImageFromFile();
        end
        
        function changeSlmControlsScanner(obj)
            selectedSlmIdx = obj.hGUIData.slmControls.pmSlmSelect.Value;
            
            if ~isempty(obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners)
                obj.hModel.hSlmScan = obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners(selectedSlmIdx);
                obj.changedSlmScan();
            end
        end
        
        function changedSlmScan(obj,varargin)
            if isempty(obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners)
                return
            end
            
            [tf,idx] = ismember(obj.hModel.hSlmScan,obj.hGUIData.slmControls.pmSlmSelect.UserData.scanners);
            
            if ~isempty(obj.hModel.hSlmScan) && ~isempty(tf) && tf
                obj.reprocessSubMdlPropBindings('hSlmScan');
                ctl = obj.hGUIData.slmControls.pmSlmSelect;
                ctl.Value = idx;
                obj.changedSlmControls();
            end
        end
        
        function changedSlmControls(obj,varargin)
            persistent bgColorDefault
            
            pbCalibrateLut = obj.hGUIData.slmControls.pbCalibrateLut;
            pbLoadWavefrontCorrection = obj.hGUIData.slmControls.pbLoadWavefrontCorrection;
            
            if isempty(bgColorDefault)
                bgColorDefault = pbCalibrateLut.BackgroundColor;
            end
            
            highlightColor = [1 0.7 0.7];
            
            if isempty(obj.hModel.hSlmScan.lut)
                pbCalibrateLut.BackgroundColor = highlightColor;
            else
                pbCalibrateLut.BackgroundColor = bgColorDefault;
            end
            
            if isempty(obj.hModel.hSlmScan.wavefrontCorrectionNominal)
                pbLoadWavefrontCorrection.BackgroundColor = highlightColor;
            else
                pbLoadWavefrontCorrection.BackgroundColor = bgColorDefault;
            end
            
            pbAlign = obj.hGUIData.slmControls.pbAlign;
            if isempty(obj.hModel.hSlmScan.hLinScan)
                pbAlign.Enable = 'off';
            else
                pbAlign.Enable = 'on';
            end
            
            calWl_nm = obj.hModel.hSlmScan.calibratedWavelengths * 1e9;
            if isempty(calWl_nm)
                str = {' '};
            else
                str = arrayfun(@(wl)num2str(wl),calWl_nm,'Uniformoutput',false);
            end
            pmWavelength_nm = obj.hGUIData.slmControls.pmWavelength_nm;
            pmWavelength_nm.String = str;
            pmWavelength_nm.Value = 1;
            
            pos = obj.hModel.hSlmScan.parkPosition * 1e6; % convert to um
            ctl = obj.hGUIData.slmControls.etParkPositionX;
            ctl.String = sprintf('%.1f',pos(1));
            ctl = obj.hGUIData.slmControls.etParkPositionY; 
            ctl.String = sprintf('%.1f',pos(2));
            ctl = obj.hGUIData.slmControls.etParkPositionZ;
            ctl.String = sprintf('%.1f',pos(3));
            
            pos = obj.hModel.hSlmScan.staticOffset * 1e6; % convert to um
            ctl = obj.hGUIData.slmControls.etStaticOffsetX;
            ctl.String = sprintf('%.1f',pos(1));
            ctl = obj.hGUIData.slmControls.etStaticOffsetY; 
            ctl.String = sprintf('%.1f',pos(2));
            ctl = obj.hGUIData.slmControls.etStaticOffsetZ;
            ctl.String = sprintf('%.1f',pos(3));
        end
        
        function changeWavelengthPm(obj,varargin)
            idx = obj.hGUIData.slmControls.pmWavelength_nm.Value;
            str = obj.hGUIData.slmControls.pmWavelength_nm.String{idx};
            
            wl = str2double(str) / 1e9; %convert to meter
            if ~isempty(wl) && ~isnan(wl)
                obj.hModel.hSlmScan.wavelength = wl;
            end
        end
        
        function changeSlmParkPosition(obj,varargin)
            try
                x = str2double(obj.hGUIData.slmControls.etParkPositionX.String);
                y = str2double(obj.hGUIData.slmControls.etParkPositionY.String);
                z = str2double(obj.hGUIData.slmControls.etParkPositionZ.String);
                
                pos = [x y z] / 1e6; % convert to um
                obj.hModel.hSlmScan.parkPosition = pos;
            catch ME
                obj.changedSlmControls();
            end
        end
        
        function changeSlmStaticOffset(obj,varargin)
            try
                x = str2double(obj.hGUIData.slmControls.etStaticOffsetX.String);
                y = str2double(obj.hGUIData.slmControls.etStaticOffsetY.String);
                z = str2double(obj.hGUIData.slmControls.etStaticOffsetZ.String);
                
                pos = [x y z] / 1e6; % convert to um
                obj.hModel.hSlmScan.staticOffset = pos;
            catch ME
                obj.changedSlmControls();
            end
        end
        
        function changedSlmAlignmentPoints(obj,~,~)
            if ~isempty(obj.hModel.hSlmScan)
                numPts = size(obj.hModel.hSlmScan.alignmentPoints,1);
                set(obj.hGUIData.slmAlignmentControls.etNumAlignmentPts,'String',num2str(numPts));

                pts = double.empty(0,3);
                for idx = 1:numPts
                    motion = obj.hModel.hSlmScan.alignmentPoints{idx,2};
                    pts(idx,:) = scanimage.mroi.util.xformPoints([obj.hModel.hMotionManager.referenceBuffer.centerXY 0],motion);
                end

                obj.hModel.hMotionManager.markerPositionsXY = pts(:,1:2);
                if size(pts,1)>0
                    obj.hModel.hMotionManager.showMotionDisplay = true;
                end
            else
                set(obj.hGUIData.slmAlignmentControls.etNumAlignmentPts,'String','');
            end
        end
        
        function changedScannerAO(obj,varargin)
            hTable = obj.hGUIData.waveformControls.tbWaveformControls;
            ss = obj.hModel.hScan2D.scannerset;
            optimizableScanners = ss.optimizableScanners;
            
            if isempty(obj.hModel.hWaveformManager.scannerAO) || ~isfield(obj.hModel.hWaveformManager.scannerAO,'ao_volts')    
                data = {};
                rowNames = '';
            else
                ao_volts = obj.hModel.hWaveformManager.scannerAO.ao_volts;
                isOptimized = ao_volts.isOptimized;
                ao_volts = rmfield(ao_volts,'isOptimized');

                scannerNames = fieldnames(ao_volts);

                rowNames = scannerNames;
                data = {};

                for idx = 1:length(scannerNames)
                    scanner = scannerNames{idx};
                    data{idx,1} = isOptimized.(scanner);
                    data{idx,2} = 'Plot';
                    if ismember(scanner,optimizableScanners);
                        data{idx,3} = 'Optimize';
                        data{idx,4} = 'Reset';
                        data{idx,5} = 'Calibrate';
                    else
                        data{idx,3} = '';
                        data{idx,4} = '';
                        data{idx,5} = '';
                    end
                end
            end
            
            hTable.RowName = rowNames;
            hTable.Data = data;
            hTable.TooltipString = sprintf([...
                'Optimized: Indicates if current waveform is optimized\n', ...
                'Plot: Plots the current waveform\n', ...
                'Optimize: Optimizes the current waveform\n', ...
                'Reset: Delete the optimization for the current waveform\n', ...
                'Calibrate: Calibrates the scanner feedback' ...
                ]);
        end
        
        function tbWaveformControlsCellSelected(obj,evt)
            persistent busy
            if isempty(busy)
                busy = false;
            end
            
            if busy
                return
            end
            
            busy = true;
            try
            hTable = obj.hGUIData.waveformControls.tbWaveformControls;
            
            if isempty(evt.Indices)
                return
            end
            
            row = evt.Indices(end,1);
            col = evt.Indices(end,2);
            rowNames = hTable.RowName;
            data = hTable.Data;
            
            %%%% refresh table to remove focus
            hTable.RowName = {};
            hTable.Data = {};
            %drawnow();
            hTable.RowName = rowNames;
            hTable.Data = data;
            drawnow();
            %%%%
            scanner = rowNames{row};
            
            ss = obj.hModel.hScan2D.scannerset;
            optimizableScanners = ss.optimizableScanners;
            isOptimizable = ismember(scanner,optimizableScanners);
            
            switch lower(hTable.Data{row,col})
                case 'plot'
                    obj.hModel.hWaveformManager.plotWaveforms(scanner);
                case 'optimize'
                    if isOptimizable
                        obj.hModel.hWaveformManager.optimizeWaveforms(scanner);
                    end
                case 'reset'
                    if isOptimizable
                        obj.hModel.hWaveformManager.clearCachedWaveform(scanner);
                    end
                case 'calibrate'
                    if isOptimizable
                        obj.hModel.hWaveformManager.calibrateScanner(scanner);
                    end
                otherwise
                    % No-op
            end
            catch ME
                busy = false;
                rethrow(ME);
            end
            busy = false;
        end
        
        function xGalvoPlot(obj)
            [fsOut,desiredWvfm,cmdWvfm,fsIn,respWvfm,T,Ta] = obj.hModel.hScan2D.waveformTest();
            
            No = length(cmdWvfm);
            outTs = linspace(1/fsOut, No/fsOut, No);
            Ni = length(respWvfm);
            inTs = linspace(1/fsIn, Ni/fsIn, Ni);
            
            bth = [cmdWvfm;respWvfm];
            rg = max(bth) - min(bth);
            
            Td=(T-Ta)/2;
            vertlines = [Td Ta+Td];
            vertlines = [vertlines vertlines+T];
            
            %% plot not accounting phase adjust
            figure;
            subplot(2,1,1);
            hold on;
            plot(outTs, desiredWvfm);
            plot(outTs, cmdWvfm);
            plot(inTs, respWvfm);
            grid on;
            title('Real time plot')
            legend('Desired','Command','Feedback');
            ylabel('Amplitude [V]');
            
            ylim([min(bth)-rg/20 max(bth)+rg/20]);
            
            for x = vertlines
                plot([x x], [-15 15], '--k');
            end
            
            %% plot accounting phase adjust
            sampShift = ceil(obj.hModel.hScan2D.linePhase * fsIn);
            subplot(2,1,2);
            hold on;
            hAx = plotyy([outTs(:),outTs(:),outTs(:)], [desiredWvfm(:),circshift(cmdWvfm(:),-sampShift),circshift(respWvfm(:),-sampShift)],...
                outTs(:),circshift(respWvfm(:),-sampShift)-desiredWvfm(:));

            grid(hAx(1),'on');
            title('Phase setting adjusted plot')
            legend('Desired','Command','Feedback','Error');
            
            ylabel(hAx(1),'Amplitude [V]');
            xlabel(hAx(1),'Time [s]');

            ylim(hAx(1),[min(bth)-rg/20 max(bth)+rg/20]);
            hAx(1).YTickMode = 'Auto';
            
            for x = vertlines
                plot(hAx(1),[x x], [-15 15], '--k');
            end
        end
    end
    
    %% INTERNAL METHODS
    %%% MOTOR ERROR CALLBACKS
    methods (Hidden, Access=private)
        function motorErrorCbk(obj,~,~) 
            structfun(@nstDisable,obj.hGUIData.motorControlsV5);
            set(obj.hGUIData.motorControlsV5.pbRecover,'Visible','on');
            set(obj.hGUIData.motorControlsV5.pbRecover,'Enable','on');
            uistack(obj.hGUIData.motorControlsV5.pbRecover,'top');
            
            function nstDisable(h)
                if isprop(h,'Enable')
                    set(h,'Enable','off');
                end
            end
        end
    end
    
    %%% CONTROLLER PROPERTY CALLBACKS    
    methods (Hidden, Access=private)
        function hFig = zzzSelectImageFigure(obj)
            %Selects image figure, either from channelsTargetDisplay property or by user-selection
            if isempty(obj.channelsTargetDisplay)
                obj.mainControlsStatusString = 'Select image...';
                chanFigs = [ obj.hModel.hDisplay.hFigs obj.hModel.hDisplay.hMergeFigs ] ;
                hFig = most.gui.selectFigure(chanFigs);
                obj.mainControlsStatusString = '';
            elseif isinf(obj.channelsTargetDisplay)
                hFig = obj.hModel.hDisplay.hMergeFigs;
            else
                hFig = obj.hModel.hDisplay.hFigs(obj.channelsTargetDisplay);
            end
        end
    end
end

%% LOCAL
function v = zlclShortenFilename(v)
assert(ischar(v));
[~,v] = fileparts(v);
end

%helper for changedStackStartEndPositionPower
function zlclEnableUIControlBasedOnVal(hUIC,val,enableOn)
if isnan(val)
    set(hUIC,'Enable','off');
else
    set(hUIC,'Enable',enableOn);
end
end

function s = lclInitPropBindings(hModel)
    %NOTE: In this prop metadata list, order does NOT matter!
    %NOTE: These are properties for which some/all handling of model-view linkage is managed 'automatically' by this class
    %TODO: Some native approach for dependent properties could be specified here, to handle straightforward cases where change in one property affects view of another -- these are now handled as 'custom' behavior with 'Callbacks'
    %For example: scanLinePeriodUS value depends on scanMode
    s = struct();

    %%SI Root Model
    s.imagingSystem             = struct('Callback','changedImagingSystem');
    s.acqsPerLoop               = struct('GuiIDs',{{'mainControlsV4','repeatsTotal'}});
    s.loopAcqInterval           = struct('GuiIDs',{{'mainControlsV4','etRepeatPeriod'}});
    s.extTrigEnable             = struct('GuiIDs',{{'mainControlsV4' 'cbExternalTrig'}},'Callback','changedExtTrigEnable');

    % acquisition State
    s.frameCounterForDisplay = struct('GuiIDs',{{'mainControlsV4','framesDone'}});
    s.loopAcqCounter         = struct('GuiIDs',{{'mainControlsV4','repeatsDone'}});
    s.acqState               = struct('Callback','changedAcqState');
    s.acqInitInProgress      = struct('Callback','changedAcqState');
    s.secondsCounter         = struct('Callback','changedSecondsCounter');

    %%% Stack props
    s.hStackManager.framesPerSlice     = struct('GuiIDs',{{'mainControlsV4','framesTotal'}});
    s.hStackManager.slicesPerAcq       = struct('GuiIDs',{{'mainControlsV4','slicesTotal'}});
    s.hStackManager.numSlices          = struct('GuiIDs',{{'motorControlsV5','etNumberOfZSlices','fastZControlsV4','etNumZSlices'}});
    s.hStackManager.stackSlicesDone    = struct('GuiIDs',{{'mainControlsV4','slicesDone'}});
    s.hStackManager.stackZStartPos     = struct('GuiIDs',{{'motorControlsV5','etStackStart'}},'Callback','changedStackStartEndPositionPower');
    s.hStackManager.stackZEndPos       = struct('GuiIDs',{{'motorControlsV5','etStackEnd'}},'Callback','changedStackStartEndPositionPower');
    s.hStackManager.stackZStepSize     = struct('GuiIDs',{{'motorControlsV5','etZStepPerSlice','fastZControlsV4','etZStepPerSlice'}});
    s.hStackManager.stackReturnHome    = struct('GuiIDs',{{'motorControlsV5','cbReturnHome','fastZControlsV4','cbReturnHome'}});
    s.hStackManager.stackStartCentered = struct('GuiIDs',{{'motorControlsV5','cbCenteredStack','fastZControlsV4','cbCenteredStack'}});
    s.hStackManager.slowStackWithFastZ = struct('GuiIDs',{{'motorControlsV5','cbSecZ'}});
    s.hStackManager.zs                 = struct('Callback','updatePowerCurve');


    %%% Submodels (sub-components)
    %%% Display component
    s.hDisplay.displayRollingAverageFactor     = struct('GuiIDs',{{'imageControlsV4','etRollingAverage'}});
    s.hDisplay.lineScanHistoryLength           = struct('GuiIDs',{{'imageControlsV4','etLineHistoryLength'}});
    s.hDisplay.displayRollingAverageFactorLock = struct('GuiIDs',{{'imageControlsV4','cbLockRollAvg2AcqAvg'}},'Callback','changedDisplayRollingAverageFactorLock');
    s.hDisplay.selectedZs                      = struct('Callback','displaySelectedZsChanged');
    s.hDisplay.volumeDisplayStyle              = struct('Callback','display3dStyleChanged');
    
    s.hDisplay.chan1LUT = struct('Callback','changedChanLUT');
    s.hDisplay.chan2LUT = struct('Callback','changedChanLUT');
    s.hDisplay.chan3LUT = struct('Callback','changedChanLUT');
    s.hDisplay.chan4LUT = struct('Callback','changedChanLUT');
    
    %s.hDisplay.channelsMergeColor      = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',6,'format','options','prettyOptions',{{'Green' 'Red' 'Blue' 'Gray' 'None'}}));
    s.hDisplay.channelsMergeEnable     = struct('GuiIDs',{{'channelControlsV4','cbMergeEnable'}},'Callback','changedChannelsMergeEnable');
    s.hDisplay.channelsMergeFocusOnly  = struct('GuiIDs',{{'channelControlsV4','cbChannelsMergeFocusOnly'}});
    
    %%% Scan2D component
    % channels
    %s.hScan2D.channelsAcquire          = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',2,'format','logicalindices','formatInfo',[]),'Callback','changedChannelsAcquire');
    %s.hScan2D.logChannels              = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',1,'format','logicalindices','formatInfo',[]));
    %s.hScan2D.channelsInputRanges      = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',3,'format','options'));
    %s.hScan2D.channelsOffsets          = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',4,'format','numeric'));
    %s.hScan2D.channelsSubtractOffsets  = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',5,'format','logical'));
    s.hScan2D.channelsAutoReadOffsets  = struct('GuiIDs',{{'channelControlsV4','cbAutoReadOffsets'}});

    s.hChannels.loggingEnable          = struct('GuiIDs',{{'mainControlsV4','cbAutoSave'}},'Callback','changedLogEnable');
    s.hChannels.channelName            = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',0,'format','cellstr'));
    s.hChannels.channelSave            = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',1,'format','logicalindices','formatInfo',[]));
    s.hChannels.channelDisplay         = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',2,'format','logicalindices','formatInfo',[]),'Callback','changedChannelDisplay');
    s.hChannels.channelInputRange      = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',3,'format','options'));
    s.hChannels.channelOffset          = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',4,'format','numeric'));
    s.hChannels.channelSubtractOffset  = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',5,'format','logical'));
    s.hChannels.channelMergeColor      = struct('GuiIDs',{{'channelControlsV4','pcChannelConfig'}},'PropControlData',struct('columnIdx',6,'format','options','prettyOptions',{{'Green' 'Red' 'Blue' 'Gray' 'None'}}));
    
    % SCAN
    s.hScan2D.bidirectional            = struct('GuiIDs',{{'configControlsV4','cbBidirectionalScan'}});
    s.hScan2D.fillFractionTemporal     = struct('GuiIDs',{{'configControlsV4','etFillFrac'}},'ViewPrecision','%0.3f');
    s.hScan2D.fillFractionSpatial      = struct('GuiIDs',{{'configControlsV4','etFillFracSpatial'}},'ViewPrecision','%0.3f');
    s.hScan2D.scanPixelTimeMean        = struct('GuiIDs',{{'configControlsV4','etPixelTimeMean'}},'ViewScaling',1e9,'ViewPrecision','%.1f');
    s.hScan2D.scanPixelTimeMaxMinRatio = struct('GuiIDs',{{'configControlsV4','etPixelTimeMaxMinRatio'}},'ViewPrecision','%.1f');
    s.hScan2D.linePhase                = struct('Callback','changedScanPhase');
    s.hScan2D.sampleRate               = struct('GuiIDs',{{'configControlsV4','etSampleRateMHz'}},'ViewPrecision','%.3f','ViewScaling',1e-6,'Callback','cfgLinePhaseSlider');
    s.hScan2D.trigAcqInTerm            = struct('GuiIDs',{{'triggerControlsV5','pmTrigAcqInTerm'}},'Callback','changedTrigAcqInTerm');
    s.hScan2D.trigStopInTerm           = struct('GuiIDs',{{'triggerControlsV5','pmTrigStopInTerm'}});
    s.hScan2D.trigNextInTerm           = struct('GuiIDs',{{'triggerControlsV5','pmTrigNextInTerm'}});
    s.hScan2D.trigAcqEdge              = struct('GuiIDs',{{'triggerControlsV5','pmTrigAcqEdge'}});
    s.hScan2D.trigStopEdge             = struct('GuiIDs',{{'triggerControlsV5','pmTrigStopEdge'}});
    s.hScan2D.trigNextEdge             = struct('GuiIDs',{{'triggerControlsV5','pmTrigNextEdge'}});
    s.hScan2D.trigNextStopEnable       = struct('GuiIDs',{{'triggerControlsV5','cbTrigNextStopEnable'}},'Callback', 'changedTrigNextStopEnable');
    s.hScan2D.pixelBinFactor           = struct('GuiIDs',{{'configControlsV4','etPixelBinFactor'}});
    s.hScan2D.flytoTimePerScanfield    = struct('GuiIDs',{{'configControlsV4','etFlytoTimePerScanfieldMs'}},'ViewPrecision','%.3f','ViewScaling',1e3);
    s.hScan2D.flybackTimePerFrame      = struct('GuiIDs',{{'configControlsV4','etFlybackTimePerFrameMs'}},'ViewPrecision','%.3f','ViewScaling',1e3);
    s.hScan2D.keepResonantScannerOn    = struct('GuiIDs',{{'configControlsV4','cbKeepScannerOn'}});
    s.hScan2D.logFilePath              = struct('Callback','changedLogFilePath');
    s.hScan2D.recordScannerFeedback    = struct('GuiIDs',{{'configControlsV4','cbFeedback'}});
    
    % logging
    s.hScan2D.logFileStem           = struct('GuiIDs',{{'mainControlsV4' 'baseName'}});
    s.hScan2D.logFileCounter        = struct('GuiIDs',{{'mainControlsV4' 'fileCounter'}});
    s.hScan2D.logFramesPerFile      = struct('GuiIDs',{{'mainControlsV4' 'etFramesPerFile'}});
    s.hScan2D.logFramesPerFileLock  = struct('GuiIDs',{{'mainControlsV4' 'cbFramesPerFileLock'}},'Callback','changedLogFramesPerFileLock');
    s.hScan2D.logAverageFactor      = struct('GuiIDs',{{'mainControlsV4','etNumAvgFramesSave'}});
    
    %%% ROIMANAGER component
    s.hRoiManager.forceSquarePixelation    = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixelation'}},'Callback','changedForceSquarePixelation');
    s.hRoiManager.forceSquarePixels        = struct('GuiIDs',{{'configControlsV4','cbForceSquarePixel'}});
    s.hRoiManager.linesPerFrame            = struct('GuiIDs',{{'configControlsV4','etLinesPerFrame'}},'Callback','changedPowerBoxes');
    s.hRoiManager.pixelsPerLine            = struct('GuiIDs',{{'configControlsV4','etPixelsPerLine'}},'Callback','pixPerLineCB');
    s.hRoiManager.scanAngleMultiplierFast  = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierFast'}});
    s.hRoiManager.scanAngleMultiplierSlow  = struct('GuiIDs',{{'mainControlsV4','etScanAngleMultiplierSlow'}});
    s.hRoiManager.scanAngleShiftSlow       = struct('GuiIDs',{{'mainControlsV4','scanShiftSlow'}});
    s.hRoiManager.scanAngleShiftFast       = struct('GuiIDs',{{'mainControlsV4','scanShiftFast'}});
    s.hRoiManager.scanFrameRate            = struct('GuiIDs',{{'configControlsV4','etFrameRate'}},'ViewPrecision','%.2f');
    s.hRoiManager.linePeriod               = struct('GuiIDs',{{'configControlsV4','etLinePeriod'}},'ViewScaling',1e6,'ViewPrecision','%.2f','Callback','changedLineRate');
    s.hRoiManager.scanRotation             = struct('GuiIDs',{{'mainControlsV4','scanRotation'}});
    s.hRoiManager.scanZoomFactor           = struct('GuiIDs',{{'mainControlsV4' 'pcZoom'}});
    s.hRoiManager.scanVolumeRate           = struct('GuiIDs',{{'fastZControlsV4', 'etVolumeRate'}},'ViewPrecision','%.2f');
    s.hRoiManager.mroiEnable               = struct('GuiIDs',{{'mainControlsV4', 'cbEnableMroi'}},'Callback','updateScanControls');
    s.hRoiManager.scanType                 = struct('Callback','updateScanType');
    
    %%% FASTZ component
    s.hFastZ.enable                        = struct('GuiIDs',{{'fastZControlsV4','cbEnable'}},'Callback','changedFastZEnable');
    s.hFastZ.numVolumes                    = struct('GuiIDs',{{'fastZControlsV4','etNumVolumes'}});
    s.hFastZ.volumesDone                   = struct('GuiIDs',{{'fastZControlsV4','etVolumesDone'}});
    s.hFastZ.volumePeriodAdjustment        = struct('GuiIDs',{{'fastZControlsV4','pcFramePeriodAdjust'}},'ViewPrecision',3,'ViewScaling',1e3);
    s.hFastZ.flybackTime                   = struct('GuiIDs',{{'fastZControlsV4','etFlybackTime'}},'ViewPrecision',3,'ViewScaling',1e3);
    s.hFastZ.actuatorLag                   = struct('GuiIDs',{{'fastZControlsV4','etActuatorLag'}},'ViewPrecision',3,'ViewScaling',1e3);
    s.hFastZ.enableFieldCurveCorr          = struct('GuiIDs',{{'fastZControlsV4','cbCurvatureCorrection'}});
    s.hFastZ.numDiscardFlybackFrames       = struct('GuiIDs',{{'fastZControlsV4','etNumDiscardFrames'}});
    s.hFastZ.waveformType                  = struct('Callback','changedWaveformType');
    s.hFastZ.useArbitraryZs                = struct('GuiIDs',{{'fastZControlsV4','cbSpecifyZs'}},'Callback','changedArbZs');
    s.hFastZ.userZs                        = struct('GuiIDs',{{'fastZControlsV4','etUserZs'}});
    s.hFastZ.positionTarget                = struct('Callback','changedFastZPosition');
    
    %%% ConfigurationSaver component
    s.hConfigurationSaver.cfgFilename          = struct('Callback','changedCfgFilename');
    s.hConfigurationSaver.usrFilename          = struct('Callback','changedUsrFilename');
    s.hConfigurationSaver.usrPropList   = struct('Callback','changedUsrPropList');
    s.hConfigurationSaver.cfgLoadingInProgress = struct('Callback','changedCfgLoading');
    s.hConfigurationSaver.fastCfgCfgFilenames  = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',struct('columnIdx',3,'format','cellstr','customEncodeFcn',@zlclShortenFilename),'Callback','changedFastCfgCfgFilenames');
    s.hConfigurationSaver.fastCfgAutoStartTf   = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',struct('columnIdx',4,'format','logical'),'Callback','changedFastCfgAutoStartTf');
    s.hConfigurationSaver.fastCfgAutoStartType = struct('GuiIDs',{{'fastConfigurationV4','pcFastCfgTable'}},'PropControlData',struct('columnIdx',5,'format','options'));
    
    %%% UserFcns component
    s.hUserFunctions.userFunctionsCfg      = struct('Callback','changedUserFunctionsCfg');
    s.hUserFunctions.userFunctionsUsr      = struct('Callback','changedUserFunctionsUsr');
    s.hUserFunctions.userFunctionsOverride = struct('Callback','changedUserFunctionsOverride');
    
    %%% Beam component
    s.hScan2D.beamClockDelay     = struct('GuiIDs',{{'powerControlsV4','etBeamLead'}},'ViewScaling',1e6);
    s.hBeams.flybackBlanking     = struct('GuiIDs',{{'powerControlsV4','cbBlankFlyback'}});
    s.hBeams.displayNames        = struct('GuiIDs',{{'powerControlsV4','powerTbl'}},'PropControlData',struct('columnIdx',0,'format','cellstr'));
    s.hBeams.powers              = struct('Callback','changedBeamParams','GuiIDs',{{'powerControlsV4','powerTbl'}},'PropControlData',struct('columnIdx',2,'format','numeric'));
    s.hBeams.pzAdjust            = struct('Callback','changedBeamParams','GuiIDs',{{'powerControlsV4','powerTbl'}},'PropControlData',struct('columnIdx',3,'format','logical'));
    s.hBeams.lengthConstants     = struct('Callback','changedBeamParams','GuiIDs',{{'powerControlsV4','powerTbl'}},'PropControlData',struct('columnIdx',4,'format','numeric'));
    s.hBeams.powerLimits         = struct('Callback','changedBeamParams');
    s.hBeams.directMode          = struct('Callback','changedBeamParams');
    s.hBeams.interlaceDecimation = struct('Callback','changedBeamParams');
    s.hBeams.interlaceOffset     = struct('Callback','changedBeamParams');
    s.hBeams.stackStartPower     = struct('GuiIDs',{{'motorControlsV5','etStartPower'}},'Callback','changedStackStartEndPositionPower');
    s.hBeams.stackEndPower       = struct('GuiIDs',{{'motorControlsV5','etEndPower'}},'Callback','changedStackStartEndPositionPower');
    s.hBeams.stackUseStartPower  = struct('GuiIDs',{{'motorControlsV5','cbUseStartPower'}},'Callback','changedStackUseStartPower');
    s.hBeams.stackUserOverrideLz = struct('GuiIDs',{{'motorControlsV5','cbOverrideLz'}},'Callback','changedOverrideLz');
    s.hBeams.enablePowerBox      = struct('GuiIDs',{{'powerControlsV4','cbEnablePowerBox'}});
    s.hBeams.beamStatus          = struct('Callback','changedBeamStatus');
    s.hBeams.beamCalibratedStatus= struct('Callback','changedBeamCalibratedStatus');
    s.hBeams.pzCustom     = struct('Callback','updatePowerCurve');
    
    %%% Power box
    s.hBeams.powerBoxes          = struct('Callback','changedPowerBoxes');
    s.hBeams.powerBoxStartFrame  = struct('GuiIDs',{{'powerBoxControlsV4','etStartFrame'}});
    s.hBeams.powerBoxEndFrame    = struct('GuiIDs',{{'powerBoxControlsV4','etEndFrame'}});

    %%% Motors component
    s.hMotors.motorStepLimit          = struct('GuiIDs',{{'motorControlsV5','etStepLimit'}});
    s.hMotors.motorPosition           = struct('Callback','changedMotorPosition');
    
    
    
    s.hMotors.azimuth                 = struct('GuiIDs',{{'motorControlsV5','edit_azimuth'}});
    s.hMotors.elevation               = struct('GuiIDs',{{'motorControlsV5','edit_elevation'}});
    s.hMotors.userDefinedPositions    = struct('Callback','changedPosns');
    s.hMotors.motorToRefTransform     = struct('Callback','changedMotorToRefTransform');
    s.hMotors.calibrationPoints       = struct('Callback','changedMotorsCalibrationPoints');

    %%% Photostim component
    s.hPhotostim.status                     = struct('GuiIDs',{{'photostimControlsV5','etStatus'}}, 'Callback','changedPhotostimState');
    s.hPhotostim.stimulusMode               = struct('Callback','changedPhotostimMode');
    s.hPhotostim.stimRoiGroups              = struct('Callback','changedStimRoiGroups');
    s.hPhotostim.stimImmediately            = struct('GuiIDs',{{'photostimControlsV5','cbStimImmediately'}});
    s.hPhotostim.numSequences               = struct('GuiIDs',{{'photostimControlsV5','etNumSequences'}});
    s.hPhotostim.stimTriggerTerm            = struct('Callback','changedPhotostimTrigger');
    s.hPhotostim.autoTriggerPeriod          = struct('Callback','changedPhotostimTrigger');
    s.hPhotostim.syncTriggerTerm            = struct('Callback','changedPhotostimSync');
    s.hPhotostim.sequenceSelectedStimuli    = struct('GuiIDs',{{'photostimControlsV5','etSequence'}});
    s.hPhotostim.allowMultipleOutputs       = struct('GuiIDs',{{'photostimControlsV5','cbAllowMult'}});
    s.hPhotostim.stimSelectionTriggerTerm   = struct('GuiIDs',{{'photostimControlsV5','etExtStimSelTriggerTerm'}});
    s.hPhotostim.stimSelectionTerms         = struct('GuiIDs',{{'photostimControlsV5','etExtStimSelTerms'}});
    s.hPhotostim.stimSelectionAssignment    = struct('GuiIDs',{{'photostimControlsV5','etExtStimSelAssignments'}});
    s.hPhotostim.monitoring                 = struct('GuiIDs',{{'photostimControlsV5','cbShowMonitor'}});
    s.hPhotostim.logging                    = struct('GuiIDs',{{'photostimControlsV5','cbLogging'}});
    
    %%% PMTs component
    s.hPmts.autoPower                       = struct('Callback','changedPmtsAutoPwr');
    
    %%% IntegrationManager component
    s.hIntegrationRoiManager.enable         = struct('GuiIDs',{{'integrationRoiOutputChannelControlsV5','cbEnableIntegration','mainControlsV4','cbIntegration'}});
    s.hIntegrationRoiManager.enableDisplay  = struct('GuiIDs',{{'integrationRoiOutputChannelControlsV5','cbEnableDisplay'}});
    s.hIntegrationRoiManager.roiGroup       = struct('Callback','changedIntegrationRoiOutputChannel');
    s.hIntegrationRoiManager.hIntegrationRoiOutputChannels = struct('Callback','changedIntegrationRoiOutputChannel');
    
    %%% MotionManager component
    s.hMotionManager.enable = struct('GuiIDs',{{'motionCorrectionControls','cbEnableMotionCorrection'}});
    s.hMotionManager.showMotionDisplay = struct('GuiIDs',{{'motionCorrectionControls','cbShowMotionDisplay'}});
    s.hMotionManager.gpuAcceleration = struct('GuiIDs',{{'motionCorrectionControls','cbGpuAcceleration'}});
    s.hMotionManager.detectMotionFcn = struct('Callback','changedDetectMotionFcn');
    s.hMotionManager.referenceImagePreprocessFcn = struct('Callback','changedReferenceImagePreprocessFcn');
	
	%%% WaveformManager component
    s.hWaveformManager.scannerAO = struct('Callback','changedScannerAO');
    
    %%% SLM component
    if ~isempty(hModel.hSlmScan)
        s.hSlmScan.focalLength = struct('GuiIDs',{{'slmControls','etFocalLength_mm'}},'ViewScaling',1e3,'ViewPrecision','%.1f');
        s.hSlmScan.wavelength  = struct('GuiIDs',{{'slmControls','etWavelength_nm'}},'ViewScaling',1e9,'ViewPrecision','%.0f','Callback','changedSlmControls');
        s.hSlmScan.parkPosition= struct('Callback','changedSlmControls');
        s.hSlmScan.staticOffset= struct('Callback','changedSlmControls');
        s.hSlmScan.lut         = struct('Callback','changedSlmControls');
        s.hSlmScan.wavefrontCorrectionNominal = struct('Callback','changedSlmControls');
        s.hSlmScan.alignmentPoints = struct('Callback','changedSlmAlignmentPoints');
    end
    
    %%% WaveSurfer connector
    s.hWSConnector.enable = struct('Callback','changedWSConnectorEnable');
    
    %%% Shutter component
    s.hShutters.status = struct('Callback','changedShutterStatus');
    
    %%% Cycle Manager
    s.hCycleManager.active = struct('Callback','changedAcqState');
    s.hCycleManager.waitParams = struct('Callback','changedAcqState');

    %%% Optional components
    for i = 1:numel(hModel.OptionalComponents)
        if isprop(hModel.(hModel.OptionalComponents{i}), 'propBindings')
            s.(hModel.OptionalComponents{i}) = hModel.(hModel.OptionalComponents{i}).propBindings;
        end
    end
end


%--------------------------------------------------------------------------%
% SIController.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
