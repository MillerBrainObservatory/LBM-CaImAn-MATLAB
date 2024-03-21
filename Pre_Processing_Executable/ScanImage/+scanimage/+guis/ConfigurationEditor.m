classdef ConfigurationEditor < most.Gui
    
    properties
        hMdfSectionPanel;
        hActivePage;
        
        initDone = false;
        
        % known sections that must be there
        hAllPages = {};
        hSIPage = {};
        hShuttersPage = {};
        hBeamsPage = {};
        hResScanPages = {};
        hLinScanPages = {};
        hSlmScanPages = {};
        hMotorsPage = {};
        hFastZPage = {};
        hPhotostimPage = {};
        hIntegrationRoiOutputsPage = {};
        hThorLabsBScope2Page = {};
        hThorLabsECUScannersPage = {};
        hPMTControllersPage = {};
        hLSCPureAnalogPage = {};
        hOtherPages = {};
        
        hSecPanel
        hRawTable;
        hButtonFlow;
        hButtons = [];
        hTitleSt;
        hDescSt;
        hAdditionalComponentsPanel;
        
        hMDF;
        mdfHdgs;
        
        daqInfo;
        allDigChans;
        
        availableRios
        rioInfo;
        simRioAdded;
        
        hSlmRegistry;
        slmName2RegMap;
        
        hMotorRegistry;
        motorName2RegMap;
        
        buttonsWidth = 260;
        
        isWizardMode = false;
        wizardDone = false;
        wizardAddedMotors;
        wizardAddedFastZ;
        wizardAddedPhotostim;
        wizardAddedIntegration;
        contHit = false;
        pageSeenBefore;
        
        rawView = false;
        
        scannerMap;
    end
    
    properties (SetObservable)
        rioChoices;
        availableDaqs;
        availableComPorts;
        fastZMotors;
    end
    
    properties (Dependent)
        scannerNames;
        scannerTypes;
        numShutters;
        shutterNames;
        numBeamDaqs;
        beamDaqNames;
        simulated;
        selectedPage;
    end
    
    events
        mdfUpdate;
    end
    
    %% Lifecycle
    methods
        function obj = ConfigurationEditor(mdfPath,initNow,persist)
            if ~nargin
                mdfPath = [];
            end
            
            if nargin < 2 || isempty(initNow)
                initNow = true;
            end
            
            if nargin < 3 || isempty(persist)
                persist = false;
            end
            
            obj = obj@most.Gui([], [], [250 60]);
            set(obj.hFig,'Name','ScanImage Machine Configuration Editor','Resize','on');
            
            if persist
                set(obj.hFig,'CloseRequestFcn',@(varargin)obj.set('Visible',false));
            end
            
            if initNow
                obj.init(mdfPath);
                if most.idioms.isValidObj(obj)
                    obj.selectedPage = 1;
                    obj.Visible = true;
                end
            end
        end
        
        function justInit = init(obj,mdfPath)
            h = msgbox('Loading configuration editor...');
            delete(h.Children(1));
            h.Children.Position = [0 -.15 1 .5];
            drawnow();
            
            if nargin > 1 && ~isempty(mdfPath)
                obj.hMDF = most.MachineDataFile.getInstance();
                obj.hMDF.load(mdfPath);
            end
            
            justInit = ~obj.initDone;
            if justInit
                
                obj.hMDF = most.MachineDataFile.getInstance();
                if ~obj.hMDF.isLoaded
                    [mdffile, mdfpath] = uigetfile('*.m','Select machine data file...');
                    if length(mdffile) > 1
                        obj.hMDF.load([mdfpath mdffile]);
                    else
                        delete(obj);
                        return;
                    end
                end
                
                obj.migrateSettings();
                
                mainContainer = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown','Units','norm','Position',[0 0 1 1]);
                topContainer = most.gui.uiflowcontainer('Parent',mainContainer,'FlowDirection','LeftToRight');
                
                obj.hButtonFlow = most.gui.uiflowcontainer('Parent',topContainer,'FlowDirection','TopDown','margin',0.00001);
                set(obj.hButtonFlow, 'WidthLimits', obj.buttonsWidth*ones(1,2));
                
                buttonContainer = most.gui.uiflowcontainer('Parent',mainContainer,'FlowDirection','RightToLeft');
                obj.addUiControl('Parent',buttonContainer,'string','Cancel','tag','pbCancel','callback',@(varargin)set(obj,'Visible',false));
                obj.addUiControl('Parent',buttonContainer,'string','Revert','tag','pbRevert','callback',@obj.pbRevertCb);
                obj.addUiControl('Parent',buttonContainer,'string','Apply','tag','pbApply','callback',@obj.pbApplyCb);
                obj.addUiControl('Parent',buttonContainer,'string','OK','tag','pbOk','callback',@obj.pbOkCb);
                set(buttonContainer, 'HeightLimits', [32 32]);
                set([obj.pbCancel.hCtl obj.pbRevert.hCtl obj.pbApply.hCtl obj.pbOk.hCtl], 'WidthLimits', [100 100]);
                
                obj.hSecPanel = uipanel('Parent', topContainer);
                secContainer = most.gui.uiflowcontainer('Parent',obj.hSecPanel,'FlowDirection','TopDown','margin',0.00001);
                
                titlePanel = uipanel('Parent', secContainer,'BorderType', 'none');
                set(titlePanel, 'HeightLimits', 96*ones(1,2));
                obj.hTitleSt = uicontrol('parent', titlePanel, 'style', 'text','units','pixels','position',[46 56 500 30],'FontSize',14,'horizontalalignment','left');
                obj.hDescSt = uicontrol('parent', titlePanel, 'style', 'text','units','pixels','position',[46 10 750 48],'FontSize',10,'horizontalalignment','left');
                annotation(titlePanel,'line',[.02 .98],.01*ones(1,2), 'LineWidth', 1);
                
                secScrlContainer = most.gui.uiflowcontainer('Parent',secContainer,'FlowDirection','RightToLeft');
                obj.addUiControl('Parent',secScrlContainer,'Style','slider','tag', 'slSecScroll','LiveUpdate',true,'callback',@obj.srcllCb);
                set(obj.slSecScroll.hCtl, 'WidthLimits', [18 18]);
                obj.hMdfSectionPanel = uipanel('Parent', secScrlContainer,'BorderType', 'none','SizeChangedFcn',@obj.resizePnl);
                
                obj.hRawTable = uitable('Parent', topContainer,...
                    'Data', {false '' '' ''}, ...
                    'ColumnName', {'Delete' 'Variable Name' 'Value' 'Comment'}, ...
                    'ColumnFormat', {'logical' 'char' 'char' 'char'}, ...
                    'ColumnEditable', [true true true true], ...
                    'ColumnWidth', {50 200 200 700}, ...
                    'RowName', [], ...
                    'RowStriping', 'Off', ...
                    'Visible', 'Off', ...
                    'CellEditCallback', @obj.rawTableCellEditFcn);
                
                obj.hFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;
                obj.hFig.WindowKeyPressFcn = @obj.keyPressFcn;
                
                obj.scannerMap = containers.Map;
                obj.initDone = true;
                
                obj.initDaqInfo();
                obj.initMotorSlmInfo();
                obj.refreshPages();
                obj.reportDaqUsage();
                
                if obj.simulated
                    % refresh again to add simulated RIO device
                    obj.addSimRio();
                end
            else
                obj.migrateSettings();
                obj.initDaqInfo();
                obj.refreshPages();
            end
            
            delete(h);
        end
        
        function constructAddlCompsPnl(obj)
            if ~most.idioms.isValidObj(obj.hAdditionalComponentsPanel)
                ph = 525;
                obj.hAdditionalComponentsPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 400 ph]);
                
                args = {'parent', obj.hAdditionalComponentsPanel, 'units','pixels','fontsize',10};
                uicontrol(args{:},'string', 'Add Stage Controller(s)','position',[46 ph-76 300 50],'callback',@(varargin)addComp('wizardAddedMotors','Motors'));
                uicontrol(args{:},'string', 'Add FastZ Actuator','position',[46 ph-136 300 50],'callback',@(varargin)addComp('wizardAddedFastZ','FastZ'));
                b1 = uicontrol(args{:},'string', 'Configure Photostimulation','position',[46 ph-196 300 50],'callback',@(varargin)addComp('wizardAddedPhotostim','Photostim'));
                b2 = uicontrol(args{:},'string', 'Configure Closed Loop Experiment Outputs','position',[46 ph-256 300 50],'callback',@(varargin)addComp('wizardAddedIntegration','IntegrationRoiOutputs'));
                uicontrol(args{:},'string', 'Finish and Run ScanImage','position',[46 ph-316 300 50],'callback',@obj.pbApplyCb);
            end
            
            function addComp(nm,hdg)
                obj.(nm) = true;
                obj.refreshPages();
                obj.selectedPage = hdg;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
            arrayfun(@delete,obj.hAllPages);
            most.idioms.safeDeleteObj(obj.scannerMap);
        end
    end
    
    methods
        function resizePnl(obj,varargin)
            if isa(obj.hActivePage, 'matlab.ui.container.Panel')
                obj.slSecScroll.hCtl.Visible = 'off';
                obj.hMdfSectionPanel.Units = 'pixels';
                cSz = obj.hMdfSectionPanel.Position;
                
                obj.hActivePage.Units = 'pixels';
                pSz = obj.hActivePage.Position;
                pSz(2) = cSz(4) - pSz(4);
                obj.hActivePage.Position = pSz;
            elseif ~isempty(obj.hActivePage)
                obj.hMdfSectionPanel.Units = 'pixels';
                cSz = obj.hMdfSectionPanel.Position;
                obj.hActivePage.resizePnl(cSz(3));
                
                ph = obj.hActivePage.hPanel.Position(4);
                
                if ph > cSz(4)
                    obj.slSecScroll.hCtl.Visible = 'on';
                    pv = obj.slSecScroll.hCtl.Max - obj.slSecScroll.hCtl.Value;
                    m = ph - cSz(4);
                    obj.slSecScroll.hCtl.Max = m;
                    obj.slSecScroll.hCtl.Value = max(m - pv, 0);
                    obj.slSecScroll.hCtl.SliderStep = [min(1,.1*cSz(4)/m) cSz(4)/m];
                else
                    obj.slSecScroll.hCtl.Visible = 'off';
                end
                obj.srcllCb();
            else
                if ~isempty(obj.hMdfSectionPanel)
                    while ~isempty(obj.hMdfSectionPanel.Children)
                        obj.hMdfSectionPanel.Children(1).Parent = [];
                    end
                    obj.slSecScroll.hCtl.Visible = 'off';
                end
            end
        end
        
        function srcllCb(obj,varargin)
            if ~isempty(obj.hActivePage)
                obj.hActivePage.hPanel.Units = 'pixels';
                obj.hMdfSectionPanel.Units = 'pixels';
                
                ph = obj.hActivePage.hPanel.Position(4);
                ch = obj.hMdfSectionPanel.Position(4);
                
                if ph > ch
                    obj.hActivePage.hPanel.Position(1:2) = [0 -obj.slSecScroll.hCtl.Value];
                else
                    obj.hActivePage.hPanel.Position(1:2) = [0 ch-ph];
                end
            end
        end
        
        function scrollToTop(obj)
            obj.slSecScroll.hCtl.Value = obj.slSecScroll.hCtl.Max;
        end
        
        function initDaqInfo(obj)
            hDaqSys = dabs.ni.daqmx.System;
            
            obj.availableDaqs = strtrim(strsplit(hDaqSys.devNames,','))';
            obj.allDigChans = {};
            maxNumPfis = 0;
            for i = 1:numel(obj.availableDaqs)
                dev = obj.availableDaqs{i};
                hDev = dabs.ni.daqmx.Device(dev);
                devstr = struct('numAOs',[],'numAIs',[],'numPFIs',16,'numPorts',[],'portNumLines',[],'ao',[],'ai',[],'pfi',[],'port',[]);
                devstr.productCategory = hDev.productCategory;
                devstr.isXSer = strcmp(devstr.productCategory,'DAQmx_Val_XSeriesDAQ');
                devstr.simultaneousSampling = get(hDev,'AISimultaneousSamplingSupported');
                devstr.busType = get(hDev,'busType');
                devstr.simulated = get(hDev,'isSimulated');
                devstr.maxSingleChannelRate = get(hDev,'AIMaxSingleChanRate');
                devstr.maxMultiChannelRate = get(hDev,'AIMaxMultiChanRate');
                if strncmp(devstr.busType,'DAQmx_Val_PXI',13)
                    devstr.pxiNum = get(hDev,'PXIChassisNum');
                else
                    devstr.pxiNum = nan;
                end
                
                astr = struct();
                astr.users = {};
                astr.bufferedUsers = {};
                
                [r, a] = hDaqSys.apiCall('DAQmxGetDevAOPhysicalChans',dev,blanks(5000),5000);
                devstr.numAOs = numel(strsplit(a,','));
                devstr.ao = repmat(astr,1,devstr.numAOs);
                
                [r, a] = hDaqSys.apiCall('DAQmxGetDevAIPhysicalChans',dev,blanks(5000),5000);
                devstr.numAIs = numel(strsplit(a,','));
                devstr.ai = repmat(astr,1,devstr.numAIs);
                
                devstr.allAOs = arrayfun(@(x)strcat('AO',num2str(x)),0:devstr.numAOs-1,'uniformoutput',false);
                devstr.allAIs = arrayfun(@(x)strcat('AI',num2str(x)),0:devstr.numAIs-1,'uniformoutput',false);
                
                %still dont know how to actually determine number of PFIs
                maxNumPfis = max(maxNumPfis, devstr.numPFIs);
                devstr.pfi = cell(1,devstr.numPFIs);
                
                [r, a] = hDaqSys.apiCall('DAQmxGetDevDIPorts',dev,blanks(5000),5000);
                devstr.numPorts = numel(strsplit(a,','));
                
                [r, a] = hDaqSys.apiCall('DAQmxGetDevDILines',dev,blanks(5000),5000);
                lines = cellfun(@(s)s(length(dev)+2:end),strtrim(strsplit(a,',')),'uniformoutput',false)';
                devstr.lines = lines;
                for j = 1:numel(lines)
                    ls = strfind(lines{j},'port');
                    le = strfind(lines{j}(ls:end),'/');
                    prt = str2double(lines{j}(ls+4:ls+le-2))+1;
                    
                    ls = strfind(lines{j},'line');
                    ln = str2double(lines{j}(ls+4:end))+1;
                    
                    if numel(devstr.portNumLines) < prt || isempty(devstr.portNumLines(prt))
                        devstr.portNumLines(prt) = ln;
                    else
                        devstr.portNumLines(prt) = max(ln,devstr.portNumLines(prt));
                    end
                end
                
                for j = 1:devstr.numPorts
                    devstr.port{j} = cell(1,devstr.portNumLines(j));
                end
                
                obj.allDigChans = unique([obj.allDigChans; devstr.lines; ]);
                
                s(i) = devstr;
            end
            
            obj.allDigChans = sort(obj.allDigChans); 
            if maxNumPfis
                obj.allDigChans = [arrayfun(@(x)strcat('PFI',num2str(x)),0:maxNumPfis-1,'uniformoutput',false)'; obj.allDigChans];
            end
            
            % RIO devices
            obj.daqInfo = s;
            obj.simRioAdded = false;
            obj.rioInfo = dabs.ni.configuration.findFlexRios();
            obj.availableRios = fieldnames(obj.rioInfo);
            for i = 1:numel(obj.availableRios)
                nm = obj.availableRios{i};
                pn = strrep(obj.rioInfo.(nm).productName(1:end-1),' PXIe-','');
                obj.rioInfo.(nm).productName = pn;
                if ~isempty(strfind(pn,'NI517'))
                    obj.rioInfo.(nm).productName = strrep(pn(1:end-2),'R (','-');
                    obj.rioInfo.(nm).adapterModule = 'NI517x';
                    obj.rioInfo.(nm).desc = [nm ' (' obj.rioInfo.(nm).productName ')'];
                else
                    if ~isfield(obj.rioInfo.(nm), 'adapterModule')
                        obj.rioInfo.(nm).adapterModule = '';
                    end
                    obj.rioInfo.(nm).adapterModule = strrep(obj.rioInfo.(nm).adapterModule,' ','');
                    obj.rioInfo.(nm).desc = [nm ' (' obj.rioInfo.(nm).productName ', ' obj.rioInfo.(nm).adapterModule ')'];
                end
            end
            obj.addSimRio();
            
            obj.findComPorts();
        end
        
        function initMotorSlmInfo(obj)
            obj.hMotorRegistry = scanimage.components.motors.MotorRegistry;
            obj.motorName2RegMap = containers.Map;
            ks = obj.hMotorRegistry.controllerMap.keys;
            for i = 1:numel(ks)
                dn = obj.hMotorRegistry.controllerMap(ks{i}).ListName;
                obj.motorName2RegMap(dn) = ks{i};
            end
            
            s = cell2mat(obj.hMotorRegistry.controllerMap.values);
            obj.fastZMotors = unique({s([s.SupportFastZ]).ListName});
            
            
            obj.slmName2RegMap = containers.Map;
            
            obj.hSlmRegistry = scanimage.components.scan2d.slmscan.SlmRegistry.slmMap;
            ks = obj.hSlmRegistry.keys;
            for i = 1:numel(ks)
                dn = obj.hSlmRegistry(ks{i}).DisplayName;
                obj.slmName2RegMap(dn) = ks{i};
            end
        end
        
        function addSimRio(obj)
            sim = isempty(obj.availableDaqs) || all([obj.daqInfo.simulated]);
            if (obj.simulated || sim) && ~obj.simRioAdded
                if ~isempty(obj.availableRios)
                    n = max(str2double(strrep(obj.availableRios,'RIO','')))+1;
                    rn = ['RIO' num2str(n)];
                else
                    rn = 'RIO0';
                end
                obj.rioInfo.(rn) = struct('productName','NI7961','pxiNumber',1,'adapterModule','NI5734','desc',[rn ' (NI7961, NI5734)']);
                obj.availableRios{end+1} = rn;
                obj.simRioAdded = true;
            end
            
            obj.availableRios = obj.availableRios(:);
            obj.rioChoices = cellfun(@(x)obj.rioInfo.(x).desc,obj.availableRios,'uniformoutput',false);
        end
        
        function findComPorts(obj)
            obj.availableComPorts = arrayfun(@(x){sprintf('COM%d',x)},sort(dabs.generic.serial.findComPorts()));
        end
        
        function refreshPages(obj,varargin)
            % reload the mdf
            obj.hMDF.load(obj.hMDF.fMDFName);
            obj.mdfHdgs = {obj.hMDF.fHData(2:end).heading};
            remHdgs = obj.mdfHdgs;
            
            % clear unknown pages
            cellfun(@delete,obj.hOtherPages);
            obj.hOtherPages = {};
            obj.hAllPages = {};
            
            if isempty(remHdgs)
                obj.isWizardMode = true;
                obj.wizardDone = false;
                obj.wizardAddedMotors = false;
                obj.wizardAddedFastZ = false;
                obj.wizardAddedPhotostim = false;
                obj.wizardAddedIntegration = false;
                obj.pageSeenBefore = struct();
                
                delete(obj.hButtons);
                obj.hButtons = [];
                
                obj.hSIPage = scanimage.guis.configuration.SIPage(obj,true);
                obj.hShuttersPage = scanimage.guis.configuration.ShuttersPage(obj,true);
                obj.hBeamsPage = scanimage.guis.configuration.BeamsPage(obj,true);
                obj.hMotorsPage = scanimage.guis.configuration.MotorsPage(obj,true);
                obj.hFastZPage = scanimage.guis.configuration.FastZPage(obj,true);
                obj.hPhotostimPage = scanimage.guis.configuration.PhotostimPage(obj,true);
                obj.hIntegrationRoiOutputsPage = scanimage.guis.configuration.IntegrationROIOutputsPage(obj,true);
            else
                obj.hSIPage = isPageThere('ScanImage', obj.hSIPage, @scanimage.guis.configuration.SIPage);
                obj.hShuttersPage = isPageThere('Shutters', obj.hShuttersPage, @scanimage.guis.configuration.ShuttersPage);
                obj.hBeamsPage = isPageThere('Beams', obj.hBeamsPage, @scanimage.guis.configuration.BeamsPage);
            end
            
            % scanner pages
            r = 0;
            l = 0;
            s = 0;
            scHdgs = [];
            obj.scannerMap.remove(obj.scannerMap.keys);
            for i = 1:numel(remHdgs)
                thsHdg = remHdgs{i};
                nm = thsHdg(10:end-1);
                if strncmp('ResScan (', thsHdg, 9)
                    % check (based on SI MDF section) if this section
                    % should be here. if not, remove it!
                    if ~most.idioms.isValidObj(obj.hSIPage) || ismember(nm,obj.scannerNames)
                        r = r + 1;
                        if numel(obj.hResScanPages) >= r
                            obj.hResScanPages{r}.reload(nm);
                        else
                            obj.hResScanPages{r} = scanimage.guis.configuration.ResScanPage(obj,nm);
                        end
                        obj.scannerMap(obj.hResScanPages{r}.scannerName) = obj.hResScanPages{r};
                    end
                elseif strncmp('LinScan (', thsHdg, 9)
                    if ~most.idioms.isValidObj(obj.hSIPage) || ismember(nm,obj.scannerNames)
                        l = l + 1;
                        if numel(obj.hLinScanPages) >= l
                            obj.hLinScanPages{l}.reload(nm);
                        else
                            obj.hLinScanPages{l} = scanimage.guis.configuration.LinScanPage(obj,nm);
                        end
                        obj.scannerMap(obj.hLinScanPages{l}.scannerName) = obj.hLinScanPages{l};
                    end
                elseif strncmp('SlmScan (', thsHdg, 9)
                    if ~most.idioms.isValidObj(obj.hSIPage) || ismember(nm,obj.scannerNames)
                        s = s + 1;
                        if numel(obj.hSlmScanPages) >= s
                            obj.hSlmScanPages{s}.reload(nm);
                        else
                            obj.hSlmScanPages{s} = scanimage.guis.configuration.SlmScanPage(obj,nm);
                        end
                        obj.scannerMap(obj.hSlmScanPages{s}.scannerName) = obj.hSlmScanPages{s};
                    end
                else
                    continue;
                end
                scHdgs(end+1) = i;
            end
            cellfun(@delete,obj.hResScanPages(r+1:end));
            obj.hResScanPages(r+1:end) = [];
            cellfun(@delete,obj.hLinScanPages(l+1:end));
            obj.hLinScanPages(l+1:end) = [];
            cellfun(@delete,obj.hSlmScanPages(s+1:end));
            obj.hSlmScanPages(s+1:end) = [];
            remHdgs(scHdgs) = [];
            
            obj.hMotorsPage = isPageThere('Motors', obj.hMotorsPage, @scanimage.guis.configuration.MotorsPage);
            obj.hFastZPage = isPageThere('FastZ', obj.hFastZPage, @scanimage.guis.configuration.FastZPage);
            obj.hPhotostimPage = isPageThere('Photostim', obj.hPhotostimPage, @scanimage.guis.configuration.PhotostimPage);
            obj.hIntegrationRoiOutputsPage = isPageThere('IntegrationRoiOutputs', obj.hIntegrationRoiOutputsPage, @scanimage.guis.configuration.IntegrationROIOutputsPage);
            obj.hThorLabsBScope2Page = isPageThere('Thorlabs BScope2', obj.hThorLabsBScope2Page, @scanimage.guis.configuration.ThorLabsBScope2Page);
            obj.hThorLabsECUScannersPage = isPageThere('Thorlabs ECU1', obj.hThorLabsECUScannersPage, @scanimage.guis.configuration.ThorLabsECUScannersPage);
            obj.hPMTControllersPage = isPageThere('GenericPmtController', obj.hPMTControllersPage, @scanimage.guis.configuration.PMTControllersPage);
            obj.hLSCPureAnalogPage = isPageThere('LSC Pure Analog', obj.hLSCPureAnalogPage, @scanimage.guis.configuration.LSCPureAnalogPage);
            
            remHdgs = setdiff(remHdgs, {'ScanImage' 'Shutters' 'Beams' 'Motors' 'FastZ' 'Photostim' 'IntegrationRoiOutputs', 'Thorlabs BScope2', 'Thorlabs ECU1', 'GenericPmtController', 'LSC Pure Analog'});
            
            for i = 1:numel(remHdgs)
                obj.hOtherPages{end+1} = scanimage.guis.configuration.GenericPage(obj,remHdgs{i});
            end
            
            obj.hAllPages = [obj.hSIPage obj.hShuttersPage obj.hBeamsPage obj.hResScanPages{:} obj.hLinScanPages{:} obj.hSlmScanPages{:} obj.hMotorsPage obj.hFastZPage obj.hPhotostimPage obj.hIntegrationRoiOutputsPage obj.hThorLabsBScope2Page obj.hThorLabsECUScannersPage obj.hPMTControllersPage obj.hLSCPureAnalogPage obj.hOtherPages{:}];
            
            if obj.isWizardMode
                wizardPage = obj.selectedPage;
                
                if isempty(wizardPage)
                    wizardPage = 1;
                else
                    wizardPage = wizardPage + 1;
                end
                
                if numel(obj.hResScanPages) + numel(obj.hLinScanPages) + numel(obj.hSlmScanPages)
                    sc = [obj.hResScanPages{:} obj.hLinScanPages{:} obj.hSlmScanPages{:}];
                    spn = {sc.listLabel};
                else
                    spn = {'Scanner Settings'};
                    
                    if wizardPage > 1
                        warndlg('Please add at least one scanning system before continuing.', 'ScanImage Configuration');
                        return;
                    end
                end
                
                extraComps = {obj.hThorLabsBScope2Page obj.hThorLabsECUScannersPage obj.hPMTControllersPage};
                if obj.wizardAddedMotors
                    extraComps{end+1} = obj.hMotorsPage;
                end
                if obj.wizardAddedFastZ
                    extraComps{end+1} = obj.hFastZPage;
                end
                if obj.wizardAddedPhotostim
                    extraComps{end+1} = obj.hPhotostimPage;
                end
                if obj.wizardAddedIntegration
                    extraComps{end+1} = obj.hIntegrationRoiOutputsPage;
                end
                extraComps{end+1} = obj.hLSCPureAnalogPage;
                extraComps = horzcat(extraComps{:});
                if numel(extraComps)
                    extraComps = {extraComps.listLabel};
                end
                
                btns = [{'General ScanImage Settings' 'Shutter Configuration' 'Power Modulation (Beams)'} spn extraComps {'Additional Components'}];
                obj.recreateButtons(btns);
                
                obj.selectedPage = wizardPage;
                
                if wizardPage == numel(btns)
                    % show the finishing page
                    obj.showFinishPage();
                else
                    hdg = matlab.lang.makeValidName(obj.hActivePage.heading);
                    if ~isfield(obj.pageSeenBefore,hdg) || ~obj.pageSeenBefore.(hdg)
                        obj.pageSeenBefore.(hdg) = true;
                        obj.hActivePage.applySmartDefaultSettings();
                    end
                end
            else
                obj.recreateButtons({obj.hAllPages.listLabel});
            end
            
            function hPg = isPageThere(hdg, hPg, pgFnc)
                if ismember(hdg, obj.mdfHdgs)
                    if most.idioms.isValidObj(hPg)
                        hPg.reload();
                    else
                        hPg = pgFnc(obj);
                    end
                else
                    most.idioms.safeDeleteObj(hPg);
                    hPg = [];
                end
            end
        end
        
        function showFinishPage(obj)
            obj.selectedPage = numel(obj.hButtons);
            obj.wizardDone = true;
            obj.hActivePage = obj.hAdditionalComponentsPanel;
            obj.hAdditionalComponentsPanel.Parent = obj.hMdfSectionPanel;
            obj.resizePnl();
            obj.hTitleSt.String = 'Finish Setup';
            obj.hDescSt.String = 'Add any of the optional featured below or click finish to launch ScanImage. These features can also be added later.';
        end
        
        function reportDaqUsage(obj)
            for hPg = obj.hAllPages
                obj.daqInfo = hPg.reportDaqUsage(obj.daqInfo);
            end
        end
        
        function mdfData = getCurrentMdfDataStruct(obj,heading)
            try
                obj.hMDF.load(obj.hMDF.fileName);
                [~,mdfData] = obj.hMDF.getVarsUnderHeading(heading);
            catch
                mdfData = [];
            end
        end
        
        function applyVarStruct(obj,heading,varStruct)
            nms = fieldnames(varStruct);
            for i=1:numel(nms)
                obj.hMDF.writeVarToHeading(heading,nms{i},varStruct.(nms{i}));
            end
        end
        
        function pbRevertCb(obj,varargin)
            if obj.isWizardMode
                v = obj.selectedPage;
                if v > 1
                    obj.selectedPage = v - 1;
                end
            else
                if strcmp(obj.hRawTable.Visible, 'on')
                    obj.refreshRawTable();
                else
                    obj.hActivePage.reload();
                end
            end
        end
        
        function pbApplyCb(obj,varargin)
            if strcmp(obj.hRawTable.Visible, 'on')
                obj.applyRawTable();
            elseif isa(obj.hActivePage, 'scanimage.guis.configuration.ConfigurationPage')
                s = obj.hActivePage.getNewVarStruct();
                obj.applyVarStruct(obj.hActivePage.heading,s);
            end
            
            pc = false;
            
            if obj.hActivePage == obj.hSIPage
                vs = ismember(obj.scannerNames, obj.scannerMap.keys);
                if ~all(vs)
                    for i = find(~vs)'
                        if strcmpi(obj.scannerTypes{i}, 'resonant')
                            obj.hResScanPages{end+1} = scanimage.guis.configuration.ResScanPage(obj,obj.scannerNames{i},true);
                        elseif strcmpi(obj.scannerTypes{i}, 'linear')
                            obj.hResScanPages{end+1} = scanimage.guis.configuration.LinScanPage(obj,obj.scannerNames{i},true);
                        elseif strcmpi(obj.scannerTypes{i}, 'slm')
                            obj.hSlmScanPages{end+1} = scanimage.guis.configuration.SlmScanPage(obj,obj.scannerNames{i},true);
                        end
                        pc = true;
                    end
                end
                
                if obj.hSIPage.hasThorECU
                    if ~ismember('Thorlabs ECU1',obj.mdfHdgs)
                        obj.hThorLabsECUScannersPage = scanimage.guis.configuration.ThorLabsECUScannersPage(obj,true);
                        pc = true;
                    end
                else
                    if ismember('Thorlabs ECU1',obj.mdfHdgs)
                        % Page is here but not needed! remove it? hide the button?
%                         pc = true;
                    end
                end
                
                if obj.hSIPage.hasBScope2
                    if ~ismember('Thorlabs BScope2',obj.mdfHdgs)
                        obj.hThorLabsBScope2Page = scanimage.guis.configuration.ThorLabsBScope2Page(obj,true);
                        pc = true;
                    end
                else
                    if ismember('Thorlabs BScope2',obj.mdfHdgs)
                        % Page is here but not needed! remove it? hide the button?
%                         pc = true;
                    end
                end
                
                if obj.hSIPage.hasPMTController
                    if ~ismember('GenericPmtController',obj.mdfHdgs)
                        obj.hPMTControllersPage = scanimage.guis.configuration.PMTControllersPage(obj,true);
                        pc = true;
                    end
                else
                    if ismember('GenericPmtController',obj.mdfHdgs)
                        % Page is here but not needed! remove it? hide the button?
%                         pc = true;
                    end
                end
            end
            
            if obj.isWizardMode
                if obj.selectedPage == numel(obj.hButtons)
                    obj.isWizardMode = false;
                    obj.contHit = true;
                    obj.Visible = false;
                end
                obj.refreshPages();
            elseif pc
                obj.refreshPages();
            end
            
            obj.notify('mdfUpdate');
        end
        
        function pbOkCb(obj,varargin)
            for hPage = obj.hAllPages
                if ~strcmp(obj.hRawTable.Visible, 'on') || hPage ~= obj.hActivePage
                    s = hPage.getNewVarStruct();
                    obj.applyVarStruct(hPage.heading,s);
                end
            end
            
            if strcmp(obj.hRawTable.Visible, 'on')
                obj.applyRawTable();
            end
            
            obj.Visible = false;
            obj.contHit = true;
            obj.notify('mdfUpdate');
        end
        
        function recreateButtons(obj,nms)
            delete(obj.hButtons);
            obj.hButtons = [];
            for i = 1:numel(nms)
                obj.hButtons(end+1) = uicontrol('parent',obj.hButtonFlow,'string',nms{i},'style','toggleButton','callback',@obj.buttCb,'userdata',i,'FontSize',10);
            end
            set(obj.hButtons, 'HeightLimits', [10 50]);
            
            if obj.isWizardMode && ~obj.wizardDone
                set(obj.hButtons, 'Enable', 'off');
            end
            %need some style!
            
            obj.hButtons = handle(obj.hButtons);
        end
        
        function buttCb(obj,src,~)
            i = src.UserData;
            if obj.isWizardMode && i == numel(obj.hButtons)
                obj.showFinishPage();
            else
                obj.selectedPage = i;
            end
        end
        
        function scrollWheelFcn(obj,~,evt)
            obj.hFig.Units = 'pixels';
            x = obj.hFig.CurrentPoint(1);
            
            if x > obj.buttonsWidth
                v = obj.slSecScroll.hCtl.Value - 50*evt.VerticalScrollCount;
                v = max(min(v,obj.slSecScroll.hCtl.Max),obj.slSecScroll.hCtl.Min);
                obj.slSecScroll.hCtl.Value = v;
            elseif ~obj.isWizardMode
                n = numel(obj.hAllPages);
                if n
                    sp = obj.selectedPage;
                    i = sp + sign(evt.VerticalScrollCount);
                    i = max(min(i,n),1);
                    if i ~= sp
                        obj.selectedPage = i;
                    end
                end
            end
        end
        
        function keyPressFcn(obj,~,evt)
            if ~obj.isWizardMode && ~obj.hActivePage.isGeneric && ismember('control',evt.Modifier) && strcmp(evt.Key,'r')
                obj.rawView = ~obj.rawView;
            end
        end
        
        function tfContinue = doModalSectionEdit(obj,page)
            obj.init();
            
            obj.contHit = false;
            obj.pbApply.Visible = 'off';
            obj.pbOk.String = 'Continue';
            
            try
                obj.selectedPage = page;
                obj.Visible = true;
                waitfor(obj.hFig,'Visible','off');
                drawnow();
            catch ME
                obj.pbApply.Visible = 'on';
                obj.pbOk.String = 'Ok';
                ME.rethrow();
            end
            
            obj.pbApply.Visible = 'on';
            obj.pbOk.String = 'Ok';
            
            tfContinue = obj.contHit;
        end
        
        function refreshRawTable(obj)
            try
                obj.hMDF.load(obj.hMDF.fileName);
                rows = obj.hMDF.getRowsForHeading(obj.hActivePage.heading);
            catch
            end
            
            em = cellfun(@(x)isempty(strtrim(x)),rows);
            rows(em) = [];
            dat = cellfun(@(s)splitRow(s),rows(2:end),'uniformoutput',false);
            obj.hRawTable.Data = [vertcat(dat{:}); {false '' '' ''}];
            
            function c = splitRow(s)
                c1 = findComment(s);
                c2 = findeqls(c1{1});
                
                c = [{false} c2 c1(2)];
                
                function c = findComment(s)
                    ccnt = 0;
                    
                    for i = 1:length(s)
                        if s(i) == ''''
                            ccnt = ccnt + 1;
                        end
                        
                        if ~mod(ccnt,2) && s(i) == '%'
                            for j = i+1:length(s);
                                if s(j) ~= '%'
                                    c = {strtrim(s(1:i-1)) strtrim(s(j:end))};
                                    return;
                                end
                            end
                            c = {strtrim(s(1:i-1)) ''};
                            return;
                        end
                    end
                    c = {strtrim(s) ''};
                end
                
                function c = findeqls(s)
                    for i = 1:length(s)
                        if s(i) == '='
                            c = {strtrim(s(1:i-1)) strtrim(s(i+1:end))};
                            if c{2}(end) == ';'
                                c{2}(end) = [];
                            end
                            return;
                        end
                    end
                    c = {strtrim(s) ''};
                end
            end
        end
        
        function rawTableCellEditFcn(obj,~,evt)
            dat = obj.hRawTable.Data;
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || ~isempty(lr{2}) || ~isempty(lr{3}) || ~isempty(lr{4})
                dat(end+1,:) = {false '' '' ''};
                obj.hRawTable.Data = dat;
            end
        end
        
        function applyRawTable(obj)
            dat = obj.hRawTable.Data;
            
            for i = 1:size(dat,1)-1
                var = dat{i,2};
                if ~isempty(var)
                    if dat{i,1}
                        obj.hMDF.removeVarFromHeading(obj.hActivePage.heading,var);
                    else
                        if isempty(dat{i,4})
                            cm = '';
                        else
                            cm = ['    %' dat{i,4}];
                        end
                        obj.hMDF.writeVarToHeading(obj.hActivePage.heading,var,eval(dat{i,3}),cm);
                    end
                end
            end
            
            obj.refreshRawTable();
        end
        
        function daqName = getScannerGalvoDaq(obj,scannerName)
            daqName = '';
            
            if obj.scannerMap.isKey(scannerName)
                hPg = obj.scannerMap(scannerName);
                if most.idioms.isValidObj(hPg)
                    daqName = strtrim(hPg.galvoDaq);
                end
            end
        end
        
        function daqName = getScannerGalvoFeedbackDaq(obj,scannerName)
            daqName = '';
            
            if obj.scannerMap.isKey(scannerName)
                hPg = obj.scannerMap(scannerName);
                if most.idioms.isValidObj(hPg)
                    daqName = strtrim(hPg.galvoFeedbackDaq);
                end
            end
        end
        
        function addMdfPageToFile(obj,path,varargin)
           mdlPth = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),path);
           obj.hMDF.copyModelFile(mdlPth,varargin{:});
           
           obj.hMDF.load(obj.hMDF.fMDFName);
           obj.mdfHdgs = {obj.hMDF.fHData(2:end).heading};
        end
        
        function removeMdfSections(obj,hdingsToRemove)
            obj.hMDF.removeSections(hdingsToRemove);
            obj.hMDF.load(obj.hMDF.fMDFName);
        end
        
        function migrateSettings(obj)
            % migrate old format of motor and fast z settings
            hdgs = {obj.hMDF.fHData(2:end).heading};
            fileBacked = false;
            
            oldMotorFmt = false;
            if ismember('Motors',hdgs)
                [~, mtrs] = obj.hMDF.getVarsUnderHeading('Motors');
                if isfield(mtrs,'motorControllerType')
                    oldMotorFmt = true;
                    backupMdf();
                    obj.removeMdfSections({'Motors'});
                    obj.addMdfPageToFile('+scanimage\+components\private\Motors_model.m');
                end
            end
            
            oldFastZFmt = false;
            if ismember('FastZ',hdgs)
                [~, fzs] = obj.hMDF.getVarsUnderHeading('FastZ');
                if isfield(fzs,'fastZControllerType')
                    oldFastZFmt = true;
                    backupMdf();
                    obj.removeMdfSections({'FastZ'});
                    obj.addMdfPageToFile('+scanimage\+components\private\FastZ_model.m');
                end
            end
            
            if oldFastZFmt
                s = struct;
                
                if strcmp(fzs.fastZControllerType, 'useMotor2') && oldMotorFmt
                    s.actuators.controllerType = mtrs.motor2ControllerType;
                    s.actuators.comPort = mtrs.motor2COMPort;
                    
                    if ~isempty(mtrs.motor2BaudRate)
                        s.customArgs = {'baudRate' mtrs.motor2BaudRate};
                    end
                    
                    mtrs.motor2ControllerType = '';
                else
                    s.actuators.controllerType = fzs.fastZControllerType;
                    s.actuators.comPort = fzs.fastZCOMPort;
                    
                    if ~isempty(fzs.fastZBaudRate)
                        s.customArgs = {'baudRate' fzs.fastZBaudRate};
                    end
                end
                
                s.actuators.daqDeviceName = fzs.fastZDeviceName;
                s.actuators.frameClockIn = fzs.frameClockIn;
                s.actuators.cmdOutputChanID = fzs.fastZAOChanID;
                s.actuators.sensorInputChanID = fzs.fastZAIChanID;
                
                if strcmp(s.actuators.controllerType, 'analog') && ismember('LSC Pure Analog',hdgs)
                    [~, ana] = obj.hMDF.getVarsUnderHeading('LSC Pure Analog');
                    
                    s.actuators.commandVoltsPerMicron = ana.commandVoltsPerMicron;
                    s.actuators.sensorVoltsPerMicron = ana.sensorVoltsPerMicron;
                    s.actuators.commandVoltsOffset = ana.commandVoltsOffset;
                    s.actuators.sensorVoltsOffset = ana.sensorVoltsOffset;
                    s.actuators.maxCommandVolts = ana.maxCommandVolts;
                    s.actuators.maxCommandPosn = ana.maxCommandPosn;
                    s.actuators.minCommandVolts = ana.minCommandVolts;
                    s.actuators.minCommandPosn = ana.minCommandPosn;
                    
                    if isempty(s.actuators.daqDeviceName)
                        s.actuators.daqDeviceName = ana.analogCmdBoardID;
                    end
                    
                    if isempty(s.actuators.cmdOutputChanID)
                        s.actuators.cmdOutputChanID = ana.analogCmdChanIDs;
                    end
                    
                    if isempty(s.actuators.sensorInputChanID)
                        s.actuators.sensorInputChanID = ana.analogSensorChanIDs;
                    end

                    obj.removeMdfSections({'LSC Pure Analog'});
                end
                
                obj.applyVarStruct('FastZ',s);
            end
            
            if oldMotorFmt
                s = struct;
                
                if ~isempty(mtrs.motorControllerType) && ~strcmp('dummy', mtrs.motorControllerType)
                    s.motors = motorStruct(mtrs,'motor');
                end
                
                if ~isempty(mtrs.motor2ControllerType) && ~strcmp('dummy', mtrs.motor2ControllerType)
                    m = motorStruct(mtrs,'motor2');
                    if isfield(s,'motors')
                        s.motors(2) = m;
                    else
                        s.motors = m;
                    end
                end
                
                obj.applyVarStruct('Motors',s);
            end
            
            if oldMotorFmt || oldFastZFmt
                msgbox('Motor and FastZ settings have been migrated from an older format. Please check the settings for accuracy.','Settings Migration','warn');
            end
            
            function s = motorStruct(in,pfx)
                s.controllerType = in.([pfx 'ControllerType']);
                
                if isfield(in,[pfx 'Dimensions'])
                    if isempty(in.([pfx 'Dimensions']))
                        s.dimensions = 'XYZ';
                    else
                        s.dimensions = in.([pfx 'Dimensions']);
                    end
                else
                    % motor 2 did not have this field and motor 2 is always a Z motor
                    s.dimensions = 'Z';
                end
                
                s.comPort = in.([pfx 'COMPort']);
                
                if isempty(in.([pfx 'BaudRate']))
                    s.customArgs = {};
                else
                    s.customArgs = {'baudRate' in.([pfx 'BaudRate'])};
                end
                
                if ~isempty(in.([pfx 'StageType']))
                    s.customArgs = [s.customArgs {'stageType' in.([pfx 'StageType'])}];
                end
                s.invertDim = repmat('+',1,numel(s.dimensions));
                
                if isfield(in, [pfx 'USBName']) && ~isempty(in.([pfx 'USBName']))
                    s.customArgs = [s.customArgs {'usbName' in.([pfx 'USBName'])}];
                end
                
                s.positionDeviceUnits = in.([pfx 'PositionDeviceUnits']);
                s.velocitySlow = in.([pfx 'VelocitySlow']);
                s.velocityFast = in.([pfx 'VelocityFast']);
                s.moveCompleteDelay = mtrs.moveCompleteDelay;
                s.moveTimeout = [];
                s.moveTimeoutFactor = [];
            end
            
            function backupMdf()
                if ~fileBacked
                    [pth, nm] = fileparts(obj.hMDF.fMDFName);
                    newName = fullfile(pth,[nm '.bak' datestr(now,'yyyy-mm-dd-HHMMSS') '.m']);
                    copyfile(obj.hMDF.fMDFName, newName);
                    fileBacked = true;
                end
            end
        end
    end
    
    methods
        function v = get.scannerNames(obj)
            if isempty(obj.hSIPage)
                v = {};
            else
                v = obj.hSIPage.scannerNames;
            end
        end
        
        function v = get.scannerTypes(obj)
            if isempty(obj.hSIPage)
                v = {};
            else
                v = obj.hSIPage.scannerTypes;
            end
        end
        
        function v = get.numShutters(obj)
            if isempty(obj.hShuttersPage)
                v = 0;
            else
                v = obj.hShuttersPage.numShutters;
            end
        end
        
        function v = get.shutterNames(obj)
            if isempty(obj.hShuttersPage)
                v = {};
            else
                v = obj.hShuttersPage.shutterNames;
            end
        end
        
        function v = get.numBeamDaqs(obj)
            if isempty(obj.hBeamsPage)
                v = 0;
            else
                v = numel(obj.hBeamsPage.beamDaqNames);
            end
        end
        
        function v = get.beamDaqNames(obj)
            if isempty(obj.hBeamsPage)
                v = {};
            else
                v = obj.hBeamsPage.beamDaqNames;
            end
        end
        
        function v = get.simulated(obj)
            if isempty(obj.hSIPage)
                v = false;
            else
                v = obj.hSIPage.simulated;
            end
        end
        
        function set.isWizardMode(obj,v)
            obj.isWizardMode = v;
            
            obj.constructAddlCompsPnl();
            
            if obj.initDone
                obj.pbOk.Visible = obj.tfMap(~v);
                
                if v
                    obj.pbRevert.String = 'Previous';
                else
                    obj.pbApply.String = 'Apply';
                    obj.pbRevert.String = 'Revert';
                end
            end
        end
        
        function set.rawView(obj,v)
            obj.rawView = v;
            
            obj.hSecPanel.Visible = obj.tfMap(~v);
            obj.hRawTable.Visible = obj.tfMap(v);
            if v
                obj.refreshRawTable();
            end
        end
        
        function v = get.selectedPage(obj)
            vs = get(obj.hButtons, 'Value');
            if isempty(vs)
                v = [];
            else
                v = find([vs{:}],1);
            end
        end
        
        function set.selectedPage(obj,btnIdx)
            set(obj.hButtons, 'Value', false);
            if isempty(btnIdx)
                btnIdx = 1;
                [tfPg,pgIdx] = ismember(get(obj.hButtons(btnIdx),'String'),{obj.hAllPages.listLabel});
            elseif ischar(btnIdx)
                [tfPg,pgIdx] = ismember(btnIdx,{obj.hAllPages.heading});
                if ~tfPg
                    [tfPg,pgIdx] = ismember(btnIdx,{obj.hAllPages.listLabel});
                    if ~tfPg
                        return
                    end
                end
                
                [~,btnIdx] = ismember(obj.hAllPages(pgIdx).listLabel,{obj.hButtons.String});
            else
                [tfPg,pgIdx] = ismember(obj.hButtons(btnIdx).String,{obj.hAllPages.listLabel});
            end
            
            if btnIdx
                set(obj.hButtons(btnIdx), 'Value', true);
            end
            
            if obj.isWizardMode
                set(obj.hButtons(1:btnIdx), 'Enable', 'on');
                if btnIdx == numel(obj.hButtons)
                    obj.pbApply.String = 'Finish';
                else
                    obj.pbApply.String = 'Next';
                end
            end
            
            while ~isempty(obj.hMdfSectionPanel.Children)
                obj.hMdfSectionPanel.Children(1).Parent = [];
            end
            
            if tfPg
                obj.hActivePage = obj.hAllPages(pgIdx);
                
                obj.hTitleSt.String = obj.hActivePage.listLabel;
                obj.hDescSt.String = obj.hActivePage.descriptionText;
                
                obj.hActivePage.refreshPageDependentOptions();
                if obj.hActivePage.isGeneric
                    obj.hSecPanel.Visible = obj.tfMap(false);
                    obj.hRawTable.Visible = obj.tfMap(true);
                    obj.refreshRawTable();
                else
                    obj.rawView = obj.rawView;
                end
                obj.hActivePage.hPanel.Parent = obj.hMdfSectionPanel;
                obj.resizePnl();
                obj.scrollToTop();
            end
        end
    end
end


%--------------------------------------------------------------------------%
% ConfigurationEditor.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
