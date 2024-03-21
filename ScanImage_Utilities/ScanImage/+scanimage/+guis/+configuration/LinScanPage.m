classdef LinScanPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        scannerName;
        numChans;
        aisFixed = false;
        numFdbkAIs = 16;
        termCfgMap = containers.Map({0 1 2}, {'Differential' 'RSE' 'NRSE'});
        termCfgRevMap = containers.Map({'Differential' 'RSE' 'NRSE'}, {0 1 2});
        
        hPMTInputDeviceText;
        hPMTInputDevicePopUp;
        hGalvoCtlDaqText;
        hGalvoCtlDaqPopUp;
        hGalvoFdbkDaqText;
        hGalvoFdbkDaqPopUp;
        hAuxilliaryClockDeviceText;
        hAuxilliaryClockDevicePopUp;
        hBeamText;
        hBeamPopUp;
        hReferenceClockInputChannelText;
        hReferenceClockInputChannelPopUp;
        hEnableReferenceClockExportCheckBox;
        hMotionCorrDaqText;
        hMotionCorrDaqPopUp;
        hChannelTable;
        hShutterTable;
        
        hXGalvoPanel;
        hXGalvoAnalogOutputChannelIDText;
        hXGalvoAnalogOutputChannelIDPopUp;
        hXGalvoMaxAngularRangeText;
        hXGalvoMaxAngularRangeEdit;
        hXGalvoOpticalConversionFactorText;
        hXGalvoOpticalConversionFactorEdit;
        hXGalvoParkAngleText;
        hXGalvoParkAngleEdit;
        
        
        hXGalvoInputChannelIDText;
        hXGalvoInputChannelIDPopUp;
        hXGalvoAnalogOutputOffsetPopUp;
        hXGalvoMaximumVoltageOutputText;
        hXGalvoMaximumVoltageOutputEdit;
        
        hYGalvoPanel;
        hYGalvoAnalogOutputChannelIDText;
        hYGalvoAnalogOutputChannelIDPopUp;
        hYGalvoInputChannelIDText;
        hYGalvoInputChannelIDPopUp;
        hYGalvoMaxAngularRangeText;
        hYGalvoMaxAngularRangeEdit;
        hYGalvoParkAngleText;
        hYGalvoParkAngleEdit;
        hYGalvoOpticalConversionFactorText;
        hYGalvoOpticalConversionFactorEdit;
        hYGalvoAnalogOutputOffsetPopUp;
        hYGalvoMaximumVoltageOutputText;
        hYGalvoMaximumVoltageOutputEdit;
        
        hBitfileVersionText;
        hBitfileVersionIDPopUp;
        
        hSyncPanel;
        hAdvButton;
        hLaserPortPop;
        
        tfMap = containers.Map({true false}, {'on' 'off'});
        ADAPTER_MODULE_CHANNEL_COUNT = containers.Map({'','NI5732','NI5733','NI5734','NI5751','NI517x','NI5771'},{0,2,2,4,4,4,4});
    end
    
    properties (SetObservable)
        acqDev = ' ';
        auxDev = ' ';
        galvoDaq = ' ';
        galvoFeedbackDaq = ' ';
        motionDaq = ' ';
    end
    
    properties (Constant)
        modelClass = 'scanimage.components.scan2d.LinScan';
    end
    
    methods
        function obj = LinScanPage(hConfigEditor, scannerName, create)
            if nargin < 3 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create,false,sprintf('LinScan (%s)',scannerName));
            
            ph = 890;
            obj.minimumWidth = 836;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 obj.minimumWidth ph]);
                        
            % PMTInputDeviceText
            obj.hPMTInputDeviceText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'PMTInputDeviceText', ...
                'Style', 'text', ...
                'String', 'Signal Acquisition DAQ', ...
                'TooltipString', 'NI DAQ board or FPGA where PMT signal is connected for acquisition.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 200 14]);
        
            % PMTInputDevicePopUp 
            obj.hPMTInputDevicePopUp = most.gui.uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'PMTInputDevicePopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board or FPGA where PMT signal is connected for acquisition.', ...
                'Units', 'pixels', ...
                'Position', [280 ph-44 150 20],...
                'Bindings',{obj 'acqDev' 'choice'});
        
            % AuxilliaryClockDeviceText
            obj.hAuxilliaryClockDeviceText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'AuxilliaryClockDeviceText', ...
                'Style', 'text', ...
                'String', 'Auxiliary Digital I/O DAQ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board for outputting clocks. Leave blank if not used. Must be a X-series board.', ...
                'Units', 'pixels', ...
                'Position', [46 ph-89 150 14]);
        
            % AuxilliaryClockDevicePopUp 
            obj.hAuxilliaryClockDevicePopUp = most.gui.uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'AuxilliaryClockDevicePopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board for outputting clocks. Leave blank if not used. Must be a X-series board.', ...
                'Units', 'pixels',...
                'Bindings',{obj 'auxDev' 'choice'}, ...
                'Position', [280 ph-91 150 20]);
        
            % BeamText
            obj.hBeamText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BeamText', ...
                'Style', 'text', ...
                'String', 'Beam DAQ', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-136 100 14]);
        
            % BeamPopUp 
            obj.hBeamPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BeamPopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [280 ph-138 150 20]);
            
            
            % shutter table text
            uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Select shutters that must be open when using this scanner.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-180 300 14]);
        
            % ShutterTable
            shutterColumnNames      = {'Select', 'Shutter Device'};
            shutterColumnFormats    = {'logical', 'char'};
            shutterColumnEditable   = [true, false];
            shutterColumnWidths     = {50, 210};
            shutterBlankRow         = {false '';};
            
            obj.hShutterTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'ShutterTable', ...
                'Data', shutterBlankRow, ...
                'ColumnName', shutterColumnNames, ...
                'ColumnFormat', shutterColumnFormats, ...
                'ColumnEditable', shutterColumnEditable, ...
                'ColumnWidth', shutterColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'Position', [46 ph-284 284 100]);
            
            %channel table text
            uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Select DAQ channels and and indicate those with an inverted PMT signal.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [518 ph-37 380 14]);
            
            % channel table
            obj.hChannelTable = uitable( ... 
                'parent', obj.hPanel, ...
                'ColumnName', {'DAQ Channel', 'Invert'}, ...
                'ColumnFormat', {'char', 'logical'}, ...
                'ColumnEditable', [false, true], ...
                'ColumnWidth', {110 50}, ...
                'RowName', {}, ...
                'Data', {}, ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'Position', [518 ph-142 284 100]);
            
            
            % GalvoPanel
            gph = 470;
            hGalvoPanel = uipanel( ...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoPanel', ...
                'Title', 'Galvo Settings', ...    
                'Units', 'pixels', ...
                'Position', [46 ph-777 810 gph]);
            
            texttop = gph-50;
            buttop = texttop-20;
            w = 170;
            h = 20;
            spc = 270;
        
            % GalvoDeviceText
            obj.hGalvoCtlDaqText = uicontrol(...
                'parent', hGalvoPanel, ...
                'Tag', 'GalvoDeviceText', ...
                'Style', 'text', ...
                'String', 'Galvo Position Control DAQ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board for controlling the X/Y galvos.', ...
                'Units', 'pixels', ...
                'Position', [46 texttop w h]);
        
            % GalvoDevicePopUp 
            obj.hGalvoCtlDaqPopUp = most.gui.uicontrol(...
                'parent', hGalvoPanel, ...
                'Tag', 'GalvoDevicePopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board for controlling the X/Y galvos.', ...
                'Units', 'pixels', ...
                'Bindings', {obj 'galvoDaq' 'Choice'},...
                'Position', [46 buttop w h]);
            
            % GalvoFeedbackText
            obj.hGalvoFdbkDaqText = uicontrol(...
                'parent', hGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Galvo Position Feedback DAQ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board for reading the position of the X/Y galvos.', ...
                'Units', 'pixels', ...
                'Position', [46+spc texttop w h]);
        
            % GalvoFeedbackPopUp 
            obj.hGalvoFdbkDaqPopUp = most.gui.uicontrol(...
                'parent', hGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'NI DAQ board for reading the position of the X/Y galvos.', ...
                'Units', 'pixels', ...
                'Bindings', {obj, 'galvoFeedbackDaq', 'Choice'}, ...
                'Position', [46+spc buttop w h]);
            
            % OffsetAnalogOutputHostText
            obj.hMotionCorrDaqText = uicontrol(...
                'parent', hGalvoPanel, ...
                'Tag', 'OffsetAnalogOutputHostText', ...
                'Style', 'text', ...
                'String', 'Motion Correction Offset DAQ', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46+spc*2 texttop w h]);
        
            % OffsetAnalogOutputHostPopUp 
            obj.hMotionCorrDaqPopUp = most.gui.uicontrol(...
                'parent', hGalvoPanel, ...
                'Tag', 'OffsetAnalogOutputHostPopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings', {obj, 'motionDaq', 'Choice'}, ...
                'Position', [46+spc*2 buttop w h]);

            
            % GalvoXGalvoPanel
            xygph = 350;
            obj.hXGalvoPanel = uipanel( ...
                'parent', hGalvoPanel, ...
                'Title', 'X Galvo', ...    
                'Units', 'pixels', ...
                'Position', [46 gph-444 332 xygph]);

            % XGalvoAnalogOutputChannelIDText
            obj.hXGalvoAnalogOutputChannelIDText = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Position Control AO Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-53 198 14]);
        
            % XGalvoAnalogOutputChannelIDPopUp 
            obj.hXGalvoAnalogOutputChannelIDPopUp = most.gui.uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-55 50 20]);

            % XGalvoMaxAngularRangeText
            obj.hXGalvoMaxAngularRangeText = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Max Angular Range (optical deg pk-pk)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-94 189 14]);
        
            % XGalvoMaxAngularRangeEdit 
            obj.hXGalvoMaxAngularRangeEdit = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'edit', ...
                'String', '15', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-98 50 22]);
        
            % XGalvoOpticalConversionFactorText
            obj.hXGalvoOpticalConversionFactorText = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Command Scaling Factor (V/optical deg)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-137 198 14]);
        
            % XGalvoOpticalConversionFactorEdit 
            obj.hXGalvoOpticalConversionFactorEdit = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'edit', ...
                'String', '1', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-141 50 22]);
        
            % XGalvoParkAngleText
            obj.hXGalvoParkAngleText = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Park Angle (optical deg)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-182 140 14]);
        
            % XGalvoParkAngleEdit 
            obj.hXGalvoParkAngleEdit = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'edit', ...
                'String', '-8', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-184 50 22]);

            % XGalvoAnalogOutputChannelIDText
            uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Position Feedback AI Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-225 198 14]);
        
            % XGalvoAnalogOutputChannelIDPopUp 
            obj.hXGalvoInputChannelIDPopUp = most.gui.uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-227 50 20]);

            % XGalvoAnalogOutputChannelIDText
            obj.hXGalvoInputChannelIDText = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Motion Correction AO Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-268 198 14]);
        
            % XGalvoAnalogOutputChannelIDPopUp 
            obj.hXGalvoAnalogOutputOffsetPopUp = most.gui.uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-270 50 20]);

            % XGalvoMaxAngularRangeText
            obj.hXGalvoMaximumVoltageOutputText = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Max Motion Correction Cmd (V)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-311 189 14]);
        
            % XGalvoMaxAngularRangeEdit 
            obj.hXGalvoMaximumVoltageOutputEdit = uicontrol(...
                'parent', obj.hXGalvoPanel, ...
                'Style', 'edit', ...
                'String', '1', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-315 50 22]);

            
            % GalvoYGalvoPanel
            obj.hYGalvoPanel = uipanel( ...
                'parent', hGalvoPanel, ...
                'Title', 'Y Galvo', ...    
                'Units', 'pixels', ...
                'Position', [424 gph-444 332 xygph]);

            % YGalvoAnalogOutputChannelIDText
            obj.hYGalvoAnalogOutputChannelIDText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Position Control AO Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-53 198 14]);
        
            % YGalvoAnalogOutputChannelIDPopUp 
            obj.hYGalvoAnalogOutputChannelIDPopUp = most.gui.uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-55 50 20]);

            % YGalvoMaxAngularRangeText
            obj.hYGalvoMaxAngularRangeText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Max Angular Range (optical deg pk-pk)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-94 189 14]);
        
            % YGalvoMaxAngularRangeEdit 
            obj.hYGalvoMaxAngularRangeEdit = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'edit', ...
                'String', '15', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-98 50 22]);
        
            % YGalvoOpticalConversionFactorText
            obj.hYGalvoOpticalConversionFactorText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Command Scaling Factor (V/optical deg)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-137 198 14]);
        
            % YGalvoOpticalConversionFactorEdit 
            obj.hYGalvoOpticalConversionFactorEdit = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'edit', ...
                'String', '1', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-141 50 22]);
        
            % YGalvoParkAngleText
            obj.hYGalvoParkAngleText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Park Angle (optical deg)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-182 140 14]);
        
            % YGalvoParkAngleEdit 
            obj.hYGalvoParkAngleEdit = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'edit', ...
                'String', '-8', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-184 50 22]);

            % YGalvoAnalogOutputChannelIDText
            obj.hYGalvoInputChannelIDText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Position Feedback AI Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-225 198 14]);
        
            % YGalvoAnalogOutputChannelIDPopUp 
            obj.hYGalvoInputChannelIDPopUp = most.gui.uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-227 50 20]);

            % YGalvoAnalogOutputChannelIDText
            obj.hYGalvoInputChannelIDText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Motion Correction AO Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-268 198 14]);
        
            % YGalvoAnalogOutputChannelIDPopUp 
            obj.hYGalvoAnalogOutputOffsetPopUp = most.gui.uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-270 50 20]);

            % YGalvoMaxAngularRangeText
            obj.hYGalvoMaximumVoltageOutputText = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'text', ...
                'String', 'Max Motion Correction Cmd (V)', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [36 xygph-311 189 14]);
        
            % YGalvoMaxAngularRangeEdit 
            obj.hYGalvoMaximumVoltageOutputEdit = uicontrol(...
                'parent', obj.hYGalvoPanel, ...
                'Style', 'edit', ...
                'String', '1', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [246 xygph-315 50 22]);
            
            
            obj.hAdvButton = uicontrol('parent',obj.hPanel,'units','pixels','position',[44 ph-826 200 26],'string','Show Advanced Settings...','callback',@obj.showAdvanced);
            
             % FlexRIODeviceIDText
            obj.hBitfileVersionText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BitfileVersionText', ...
                'Style', 'text', ...
                'String', 'Custom FPGA Signal Conditioning Option', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-827 200 14],...
                'visible','off');
        
            obj.hBitfileVersionIDPopUp = most.gui.popupMenuEdit(...
                'parent', obj.hPanel, ...
                'Position', [280 ph-829 150 22],...
                'visible','off');
            
            %sync panel
            sph = 120;
            obj.hSyncPanel = uipanel( ...
                'parent', obj.hPanel, ...
                'Title', 'Advanced Clock Synchronization', ...    
                'Units', 'pixels', ...
                'Position', [46 ph-974 390 sph],...
                'visible','off');
        
            % ReferenceClockInputChannelText
            obj.hReferenceClockInputChannelText = uicontrol(...
                'parent', obj.hSyncPanel, ...
                'Tag', 'ReferenceClockInputChannelText', ...
                'Style', 'text', ...
                'String', 'Reference Clock Input Channel', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '10MHz reference clock that is connected on the Auxilliary board. Select Automatic Routing if done through the PXI bus.', ...
                'Units', 'pixels', ...
                'Position', [46 sph-55 155 14]);
        
            % ReferenceClockInputChannelPopUp 
            obj.hReferenceClockInputChannelPopUp = uicontrol(...
                'parent', obj.hSyncPanel, ...
                'Tag', 'ReferenceClockInputChannelPopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '10MHz reference clock that is connected on the Auxilliary board. Select Automatic Routing if done through the PXI bus.', ...
                'Units', 'pixels', ...
                'Position', [226 sph-55 120 20]);
        
            % EnableReferenceClockExportCheckBox 
            obj.hEnableReferenceClockExportCheckBox = uicontrol(...
                'parent', obj.hSyncPanel, ...
                'Tag', 'EnableReferenceClockExportCheckBox', ...
                'Style', 'checkbox', ...
                'String', 'Enable export of 10MHz Reference Clock on PFI14', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 sph-102 270 23]);
            
            uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Laser Clock Port', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Digital input where laser trigger is connected.', ...
                'Units', 'pixels', ...
                'Position', [46 ph-1017 140 14]);
        
            
            obj.hLaserPortPop = uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'popupmenu', ...
                'String', [{''} arrayfun(@(v){sprintf('(FPGA) DIO0.%d',v)},0:3) arrayfun(@(v){sprintf('(Aux DAQ) PFI%d',v)},0:23)], ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Digital input where laser trigger is connected.', ...
                'Units', 'pixels', ...
                'Position', [280 ph-1018 110 20]);
            
            obj.hConfigEditor.addSimRio();
            obj.reload(scannerName);
        end
        
        function delete(~)
        end
        
        function applySmartDefaultSettings(obj,scannerName)
            if nargin > 1 && ~isempty(scannerName)
                obj.heading = ['LinScan (' scannerName ')'];
            end
            
            if isempty(obj.hConfigEditor.availableDaqs)
                % no daqs. just leave defaults
                return
            end
            
            s.deviceNameAcq = '';
            
            % choose acq device. FPGA > SS DAQ > Highest sample rate DAQ
            if ~isempty(obj.hConfigEditor.availableRios)
                % there must be an x series daq in the same chassis for
                % this to work
                rio = obj.hConfigEditor.availableRios{1};
                pxiNum = obj.hConfigEditor.rioInfo.(rio).pxiNumber;
                
                dq = [];
                if ~isempty(obj.hConfigEditor.availableDaqs)
                    dq = find([obj.hConfigEditor.daqInfo.pxiNum] == pxiNum,1);
                end
                
                if ~isempty(dq)
                    s.deviceNameAcq = rio;
                    s.deviceNameAux = obj.hConfigEditor.availableDaqs{dq};
                    s.deviceNameGalvo = s.deviceNameAux;
                end
            end
            
            % no FPGA. SS DAQ > Highest sample rate DAQ
            if isempty(s.deviceNameAcq) && ~isempty(obj.hConfigEditor.availableDaqs)
                dq = find([obj.hConfigEditor.daqInfo.simultaneousSampling]);
                [~,i] = max([obj.hConfigEditor.daqInfo(dq).maxMultiChannelRate]);
                dq = dq(i);
                
                if isempty(dq)
                    % no SS DAQ. pick daq with max sample rate. choose a
                    % daq in a pxi if possible
                    dq = find(~isnan([obj.hConfigEditor.daqInfo.pxiNum]));
                    if isempty(dq)
                        dq = 1:numel(obj.hConfigEditor.availableDaqs);
                    end
                    
                    [~,i] = max([obj.hConfigEditor.daqInfo(dq).maxSingleChannelRate]);
                    dq = dq(i);
                end
                
                s.deviceNameAcq = obj.hConfigEditor.availableDaqs{dq};
                s.deviceNameGalvo = s.deviceNameAcq;
                
                if obj.hConfigEditor.daqInfo(dq).isXSer
                    s.deviceNameAux = s.deviceNameAcq;
                else
                    pxiNum = obj.hConfigEditor.daqInfo(dq).pxiNum;
                    if isnan(pxiNum)
                        % find a daq connected by RTSI. dont know how right
                        % now. just pick an x series pci daq
                        dq = find(isnan([obj.hConfigEditor.daqInfo.pxiNum]) & [obj.hConfigEditor.daqInfo.isXSer],1);
                    else
                        dq = find(([obj.hConfigEditor.daqInfo.pxiNum] == pxiNum) & [obj.hConfigEditor.daqInfo.isXSer],1);
                    end
                    
                    if isempty(dq)
                        s.deviceNameAux = '';
                    else
                        s.deviceNameAux = obj.hConfigEditor.availableDaqs{dq};
                    end
                end
            end
            
            % if we have an aux device and there is a beam daq, pick it
            if ~isempty(s.deviceNameAux) && obj.hConfigEditor.numBeamDaqs
                % get smarter about which beam daq to choose?
                s.beamDaqID = 1;
            end
            
            obj.applyVarStruct(s);
            obj.reload();
        end
        
        function refreshPageDependentOptions(obj)
            shutterIDs = find([obj.hShutterTable.Data{:,1}]);
            
            shutters = obj.hConfigEditor.shutterNames;
            shutterDat = [repmat({false},numel(shutters),1) shutters];
            obj.hShutterTable.Data = shutterDat;
            
            if ~isempty(shutterIDs)
                shutterIDs(shutterIDs > numel(shutters)) = [];
                obj.hShutterTable.Data(:,1) = {false};
                obj.hShutterTable.Data(shutterIDs,1) = {true};
            end
            
            str = [{'None'} obj.hConfigEditor.beamDaqNames];
            v = min(numel(str),obj.hBeamPopUp.Value);
            obj.hBeamPopUp.String = str;
            obj.hBeamPopUp.Value = v;
        end
        
        function reload(obj,scannerName)
            if nargin > 1
                obj.scannerName = scannerName;
                obj.listLabel = ['Scanner Settings (' scannerName ')'];
                obj.heading = ['LinScan (' scannerName ')'];
                obj.descriptionText = ['Configure DAQ and scan mirror settings for the ''' scannerName ''' linear scanning system. Previously configured beam DAQs and shutters can be assigned to this scanner.'];
            end
            
            obj.refreshPageDependentOptions();
            
            sigAcqChcs = obj.hConfigEditor.availableDaqs;
            if ~isempty(obj.hConfigEditor.rioChoices)
                sigAcqChcs = [sigAcqChcs; obj.hConfigEditor.rioChoices];
            end
            obj.hPMTInputDevicePopUp.String = sigAcqChcs;
            
            isXSer = [];
            if ~isempty(obj.hConfigEditor.availableDaqs)
                isXSer = [obj.hConfigEditor.daqInfo.isXSer];
            end
            
            obj.hAuxilliaryClockDevicePopUp.String = [{'None'}; obj.hConfigEditor.availableDaqs(isXSer)];
            
            obj.hGalvoCtlDaqPopUp.String = obj.hConfigEditor.availableDaqs;
            
            obj.hGalvoFdbkDaqPopUp.String = [{'None'}; obj.hConfigEditor.availableDaqs(isXSer)];
            
            obj.hMotionCorrDaqPopUp.String = [{'None'}; obj.hConfigEditor.availableDaqs];
            
            % reload the settings
            mdfData = obj.getCurrentMdfDataStruct();
            
            if ~isempty(mdfData.beamDaqID) && mdfData.beamDaqID <= obj.hConfigEditor.numBeamDaqs
                obj.hBeamPopUp.Value = mdfData.beamDaqID+1;
            else
                obj.hBeamPopUp.Value = 1;
            end
            
            if ~isfield(mdfData,'deviceNameGalvoFeedback')
                mdfData.deviceNameGalvoFeedback = '';
            end
            if ~isfield(mdfData,'deviceNameOffset')
                mdfData.deviceNameOffset = '';
            end
            
            obj.acqDev = mdfData.deviceNameAcq;
            obj.galvoDaq = mdfData.deviceNameGalvo;
            obj.auxDev = mdfData.deviceNameAux;
            obj.galvoFeedbackDaq = mdfData.deviceNameGalvoFeedback;
            obj.motionDaq = mdfData.deviceNameOffset;
            
            mdfData.channelsInvert(end+1:obj.numChans) = mdfData.channelsInvert(1);
            mdfData.channelsInvert(obj.numChans+1:end) = [];
            obj.hChannelTable.Data(:,2) = num2cell(mdfData.channelsInvert(:));
            
            mdfData.shutterIDs(mdfData.shutterIDs > obj.hConfigEditor.numShutters) = [];
            obj.hShutterTable.Data(:,1) = {false};
            obj.hShutterTable.Data(mdfData.shutterIDs,1) = {true};
            
            if ~obj.aisFixed
                chIds = 0:obj.numChans-1;
                ns = 1:min(numel(mdfData.channelIDs),obj.numChans);
                chIds(ns) = mdfData.channelIDs(ns);
                obj.hChannelTable.Data(:,1) = arrayfun(@(x)sprintf('AI%d',x),chIds,'uniformoutput',false);
            end
            
            if ~isfield(mdfData,'internalRefClockSrc')
                mdfData.internalRefClockSrc = '';
            end
            switch mdfData.internalRefClockSrc
                case '20MHzTimebase'
                    obj.hReferenceClockInputChannelPopUp.Value = 2;
                    
                case '100MHzTimebase'
                    obj.hReferenceClockInputChannelPopUp.Value = 3;
                    
                otherwise
                    [tf, idx] = ismember(['External: ' mdfData.referenceClockIn],obj.hReferenceClockInputChannelPopUp.String);
                    if ~tf
                        idx = 1;
                    end
                    obj.hReferenceClockInputChannelPopUp.Value = idx;
            end
            
            if isfield(mdfData,'enableRefClkOutput')
                obj.hEnableReferenceClockExportCheckBox.Value = mdfData.enableRefClkOutput;
            else
                obj.hEnableReferenceClockExportCheckBox.Value = false;
            end
            
            obj.hXGalvoAnalogOutputChannelIDPopUp.Value = mdfData.XMirrorChannelID + 1;
            if isfield(mdfData,'XMirrorPosChannelID') && ~isempty(mdfData.XMirrorPosChannelID)
                if isfield(mdfData,'XMirrorPosTermCfg') && ~isempty(mdfData.XMirrorPosTermCfg)
                    dd = obj.termCfgRevMap(mdfData.XMirrorPosTermCfg) * obj.numFdbkAIs;
                else
                    dd = 0;
                end
                obj.hXGalvoInputChannelIDPopUp.Value = mdfData.XMirrorPosChannelID + 2 + dd;
            else
                obj.hXGalvoInputChannelIDPopUp.Value = 1;
            end
            if isfield(mdfData,'XMirrorOffsetChannelID') && ~isempty(mdfData.XMirrorOffsetChannelID)
                obj.hXGalvoAnalogOutputOffsetPopUp.Value = mdfData.XMirrorOffsetChannelID + 2;
            else
                obj.hXGalvoAnalogOutputOffsetPopUp.Value = 1;
            end
            if isfield(mdfData,'XMirrorOffsetMaxVoltage')
                obj.hXGalvoMaximumVoltageOutputEdit.String = mdfData.XMirrorOffsetMaxVoltage;
            else
                obj.hXGalvoMaximumVoltageOutputEdit.String = 1;
            end
            
            obj.hYGalvoAnalogOutputChannelIDPopUp.Value = mdfData.YMirrorChannelID + 1;
            if isfield(mdfData,'YMirrorPosChannelID') && ~isempty(mdfData.YMirrorPosChannelID)
                if isfield(mdfData,'YMirrorPosTermCfg') && ~isempty(mdfData.YMirrorPosTermCfg)
                    dd = obj.termCfgRevMap(mdfData.YMirrorPosTermCfg) * obj.numFdbkAIs;
                else
                    dd = 0;
                end
                obj.hYGalvoInputChannelIDPopUp.Value = mdfData.YMirrorPosChannelID + 2 + dd;
            else
                obj.hYGalvoInputChannelIDPopUp.Value = 1;
            end
            if isfield(mdfData,'YMirrorOffsetChannelID') && ~isempty(mdfData.YMirrorOffsetChannelID)
                obj.hYGalvoAnalogOutputOffsetPopUp.Value = mdfData.YMirrorOffsetChannelID + 2;
            else
                obj.hYGalvoAnalogOutputOffsetPopUp.Value = 1;
            end
            if isfield(mdfData,'YMirrorOffsetMaxVoltage')
                obj.hYGalvoMaximumVoltageOutputEdit.String = mdfData.YMirrorOffsetMaxVoltage;
            else
                obj.hYGalvoMaximumVoltageOutputEdit.String = 1;
            end
            
            obj.hXGalvoOpticalConversionFactorEdit.String = mdfData.voltsPerOpticalDegreeX;
            obj.hXGalvoMaxAngularRangeEdit.String = mdfData.xGalvoAngularRange;
            obj.hXGalvoParkAngleEdit.String = mdfData.scanParkAngleX;
            obj.hYGalvoOpticalConversionFactorEdit.String = mdfData.voltsPerOpticalDegreeY;
            obj.hYGalvoMaxAngularRangeEdit.String = mdfData.yGalvoAngularRange;
            obj.hYGalvoParkAngleEdit.String = mdfData.scanParkAngleY;
            
            if isfield(mdfData,'LaserTriggerPort')
                if strncmp(mdfData.LaserTriggerPort, 'DIO0.', 5)
                    idx = 2 + str2num(mdfData.LaserTriggerPort(6));
                elseif strncmp(mdfData.LaserTriggerPort, 'PFI', 3)
                    idx = 6 + str2num(mdfData.LaserTriggerPort(4:end));
                else
                    idx = 1;
                end
                obj.hLaserPortPop.Value = idx;
            else
                obj.hLaserPortPop.Value = 1;
            end
            
            if isfield(mdfData, 'customSigCondOption') && ~isempty(mdfData.customSigCondOption)
                obj.hBitfileVersionIDPopUp.string = mdfData.customSigCondOption;
            else
                obj.hBitfileVersionIDPopUp.string = 'None';
            end
        end
        
        function s = getNewVarStruct(obj)
            s.beamDaqID = obj.hBeamPopUp.Value - 1;
            if s.beamDaqID < 1
                s.beamDaqID = [];
            end
            
            s.shutterIDs = find([obj.hShutterTable.Data{:,1}]);
            if isempty(s.shutterIDs)
                s.shutterIDs = [];
            end
            
            if ~obj.aisFixed
                s.channelIDs = str2double(strrep(obj.hChannelTable.Data(:,1),'AI',''))';
            else
                s.channelIDs = [];
            end
            s.channelsInvert = [obj.hChannelTable.Data{:,2}];
            
            rio = strsplit(obj.acqDev,' (');
            if strncmp(rio{1},'RIO',3)
                s.deviceNameAcq = rio{1};
                if isempty(strfind(rio{2},'not found'))
                    fpgaDig = strsplit(strrep(rio{2},')',''),',');
                    s.fpgaModuleType = fpgaDig{1};
                    if numel(fpgaDig) > 1
                        s.digitizerModuleType = strtrim(fpgaDig{2});
                    else
                        if strncmp(s.fpgaModuleType,'NI5171',6)
                            s.fpgaModuleType = 'NI5171';
                        end
                        s.digitizerModuleType = '';
                    end
                else
                    s.fpgaModuleType = 'NI7961';
                    s.digitizerModuleType = 'NI5732';
                end
            else
                s.deviceNameAcq = obj.acqDev;
            end
            
            s.deviceNameGalvo = obj.galvoDaq;
            
            s.deviceNameAux = opDaqNm(obj.auxDev);
            s.deviceNameGalvoFeedback = opDaqNm(obj.galvoFeedbackDaq);
            s.deviceNameOffset = opDaqNm(obj.motionDaq);
            
            switch obj.hReferenceClockInputChannelPopUp.Value
                case 1
                    s.internalRefClockSrc = '';
                    s.referenceClockIn = '';
                    
                case 2
                    s.internalRefClockSrc = '20MHzTimebase';
                    s.internalRefClockRate = 20e6;
                    s.referenceClockIn = '';
                    
                case 3
                    s.internalRefClockSrc = '100MHzTimebase';
                    s.internalRefClockRate = 100e6;
                    s.referenceClockIn = '';
                    
                otherwise
                    s.internalRefClockSrc = '';
                    str = obj.hReferenceClockInputChannelPopUp.String;
                    str = str{obj.hReferenceClockInputChannelPopUp.Value};
                    s.referenceClockIn = str(11:end);
            end
            
            s.enableRefClkOutput = obj.hEnableReferenceClockExportCheckBox.Value;
            
            s.XMirrorChannelID = obj.hXGalvoAnalogOutputChannelIDPopUp.Value-1;
            s.XMirrorPosChannelID = opDaqCh(obj.hXGalvoInputChannelIDPopUp.Value-2);
            if ~isempty(s.XMirrorPosChannelID)
                s.XMirrorPosTermCfg = obj.termCfgMap(floor(s.XMirrorPosChannelID/obj.numFdbkAIs));
                s.XMirrorPosChannelID = mod(s.XMirrorPosChannelID,obj.numFdbkAIs);
            end
            s.XMirrorOffsetChannelID = opDaqCh(obj.hXGalvoAnalogOutputOffsetPopUp.Value-2);
            
            s.voltsPerOpticalDegreeX = str2double(obj.hXGalvoOpticalConversionFactorEdit.String);
            s.xGalvoAngularRange = str2double(obj.hXGalvoMaxAngularRangeEdit.String);
            s.scanParkAngleX = str2double(obj.hXGalvoParkAngleEdit.String);
            s.XMirrorOffsetMaxVoltage = str2double(obj.hXGalvoMaximumVoltageOutputEdit.String);
            
            s.YMirrorChannelID = obj.hYGalvoAnalogOutputChannelIDPopUp.Value-1;
            s.YMirrorPosChannelID = opDaqCh(obj.hYGalvoInputChannelIDPopUp.Value-2);
            if ~isempty(s.YMirrorPosChannelID)
                s.YMirrorPosTermCfg = obj.termCfgMap(floor(s.YMirrorPosChannelID/obj.numFdbkAIs));
                s.YMirrorPosChannelID = mod(s.YMirrorPosChannelID,obj.numFdbkAIs);
            end
            s.YMirrorOffsetChannelID = opDaqCh(obj.hYGalvoAnalogOutputOffsetPopUp.Value-2);
            
            s.voltsPerOpticalDegreeY = str2double(obj.hYGalvoOpticalConversionFactorEdit.String);
            s.yGalvoAngularRange = str2double(obj.hYGalvoMaxAngularRangeEdit.String);
            s.scanParkAngleY = str2double(obj.hYGalvoParkAngleEdit.String);
            s.YMirrorOffsetMaxVoltage = str2double(obj.hYGalvoMaximumVoltageOutputEdit.String);
            
            s.LaserTriggerPort = strrep(strrep(obj.hLaserPortPop.String{obj.hLaserPortPop.Value},'(FPGA) ',''),'(Aux DAQ) ','');
            
            str = obj.hBitfileVersionIDPopUp.string;
            if strcmp(str, 'None')
                str = '';
            end
            s.customSigCondOption = str;
        end
        
        function showAdvanced(obj,varargin)
            addH = 165;
            obj.hPanel.Units = 'pixels';
            p = obj.hPanel.Position;
            obj.hPanel.Position = p + [0 0 0 addH];
            
            set(obj.hPanel.Children,'units','pixels');
            arrayfun(@(h)set(h,'Position',h.Position + [0 addH 0 0]),obj.hPanel.Children);
            obj.hConfigEditor.slSecScroll.hCtl.Value = -addH;
            
            obj.hAdvButton.Visible = 'off';
            obj.hSyncPanel.Visible = 'on';
            
            obj.hBitfileVersionText.Visible = 'on';
            obj.hBitfileVersionIDPopUp.visible = 'on';
            
            obj.hConfigEditor.resizePnl();
        end
    end
    
    %% prop access
    methods
        function set.acqDev(obj, v)
            chcs = obj.hPMTInputDevicePopUp.String;
            [tf,idx] = ismember(v,obj.hConfigEditor.availableDaqs);
            if tf
                if obj.hConfigEditor.daqInfo(idx).simultaneousSampling
                    obj.numChans = min(4,obj.hConfigEditor.daqInfo(idx).numAIs);
                else
                    obj.numChans = 1;
                end
                obj.aisFixed = false;
                numAvailChans = obj.hConfigEditor.daqInfo(idx).numAIs;
                
                obj.hBitfileVersionText.Enable = 'off';
                obj.hBitfileVersionIDPopUp.enable = 'off';
                obj.hBitfileVersionIDPopUp.string = 'None';
            else
                rio = strsplit(v,' ');
                rio = rio{1};
                
                if isfield(obj.hConfigEditor.rioInfo, rio)
                    am = obj.hConfigEditor.rioInfo.(rio).adapterModule;
                    am = regexp(am,'^[^()]+','match','once');
                    if ismember(am,obj.ADAPTER_MODULE_CHANNEL_COUNT.keys)
                        obj.numChans = obj.ADAPTER_MODULE_CHANNEL_COUNT(am);
                    else
                        obj.numChans = 0;
                    end
                    obj.aisFixed = true;
                    
                    idx = find(strncmp(rio, chcs, length(rio)),1);
                    if ~isempty(idx)
                        v = chcs{idx};
                    end
                    
                    obj.hBitfileVersionText.Enable = 'on';
                    obj.hBitfileVersionIDPopUp.enable = 'on';
                    obj.hBitfileVersionIDPopUp.string = 'None';
                    obj.hBitfileVersionIDPopUp.choices = {'None'};
                else
                    obj.numChans = 1;
                    obj.aisFixed = true;
                    v = [v ' (not found)'];
                    
                    obj.hBitfileVersionText.Enable = 'off';
                    obj.hBitfileVersionIDPopUp.enable = 'off';
                    obj.hBitfileVersionIDPopUp.string = 'None';
                end
            end
            
            if ~ismember(v,chcs)
                obj.hPMTInputDevicePopUp.String{end+1} = v;
            end
            obj.acqDev = v;
            
            % update channel table
            if obj.numChans
                dat = obj.hChannelTable.Data;
                dat(end+1:obj.numChans,2) = {false};
                dat(obj.numChans+1:end,:) = [];
                
                if obj.aisFixed
                    obj.hChannelTable.ColumnEditable = [false true];
                    obj.hChannelTable.ColumnFormat = {'char' 'logical'};
                    dat(:,1) = arrayfun(@(x)sprintf('AI%d',x),0:(obj.numChans-1),'uniformoutput',false);
                else
                    obj.hChannelTable.ColumnEditable = [true true];
                    obj.hChannelTable.ColumnFormat = {arrayfun(@(x)sprintf('AI%d',x),0:(numAvailChans-1),'uniformoutput',false) 'logical'};
                    dat(:,1) = arrayfun(@(x)sprintf('AI%d',x),0:(obj.numChans-1),'uniformoutput',false);
                end
                
                obj.hChannelTable.RowName = arrayfun(@(x)sprintf('Channel %d',x),1:obj.numChans,'uniformoutput',false);
            else
                dat = {};
                obj.hChannelTable.RowName = dat;
            end
            obj.hChannelTable.Data = dat;
        end
        
        function set.auxDev(obj,v)
            if isempty(v)
                v = 'None';
            end
            if ~ismember(v,obj.hAuxilliaryClockDevicePopUp.String)
                obj.hAuxilliaryClockDevicePopUp.String{end+1} = v;
            end
            obj.auxDev = v;
            
            b = ~strcmp(v,'None');
            obj.hReferenceClockInputChannelPopUp.Enable = obj.tfMap(b);
            obj.hReferenceClockInputChannelText.Enable = obj.tfMap(b);
            obj.hEnableReferenceClockExportCheckBox.Enable = obj.tfMap(b);
            
            [tf,idx] = ismember(v,obj.hConfigEditor.availableDaqs);
            if b && tf
                numPfi = obj.hConfigEditor.daqInfo(idx).numPFIs;
            else
                numPfi = 32;
            end
            
            obj.hReferenceClockInputChannelPopUp.String = [{'Automatic' '20MHzTimebase' '100MHzTimebase'} arrayfun(@(x)sprintf('External: PFI%d',x),setdiff(1:(numPfi-1),[10 14]),'uniformoutput',false)];
        end
        
        function set.galvoDaq(obj,v)
            if ~ismember(v,obj.hGalvoCtlDaqPopUp.String)
                obj.hGalvoCtlDaqPopUp.String{end+1} = v;
            end
            obj.galvoDaq = v;
            
            [tf,idx] = ismember(v,obj.hConfigEditor.availableDaqs);
            if tf
                numAOs = obj.hConfigEditor.daqInfo(idx).numAOs;
            else
                numAOs = 2;
            end
            aos = arrayfun(@(x)sprintf('AO%d',x),0:(numAOs-1),'uniformoutput',false);
            
            % Event when new daq has fewer outputs/inputs than previous
            [tf_xGalvoAO, idx_xGalvoAO] = ismember(obj.hXGalvoAnalogOutputChannelIDPopUp.String(obj.hXGalvoAnalogOutputChannelIDPopUp.Value), aos);
            if tf_xGalvoAO
                obj.hXGalvoAnalogOutputChannelIDPopUp.Value = idx_xGalvoAO;
            else
                obj.hXGalvoAnalogOutputChannelIDPopUp.Value = 1;
            end
            
            obj.hXGalvoAnalogOutputChannelIDPopUp.String = aos;
            
            % Event when new daq has fewer outputs/inputs than previous
            [tf_yGalvoAO, idx_yGalvoAO] = ismember(obj.hYGalvoAnalogOutputChannelIDPopUp.String(obj.hYGalvoAnalogOutputChannelIDPopUp.Value), aos);
            if tf_yGalvoAO
                obj.hYGalvoAnalogOutputChannelIDPopUp.Value = idx_yGalvoAO;
            else
                obj.hYGalvoAnalogOutputChannelIDPopUp.Value = 2;
            end

            obj.hYGalvoAnalogOutputChannelIDPopUp.String = aos;
        end
        
        function set.galvoFeedbackDaq(obj,v)
            if isempty(v)
                v = 'None';
            end
            if ~ismember(v,obj.hGalvoFdbkDaqPopUp.String)
                obj.hGalvoFdbkDaqPopUp.String{end+1} = v;
            end
            obj.galvoFeedbackDaq = v;
            
            b = ~strcmp(v,'None');
            obj.hXGalvoInputChannelIDPopUp.Enable = obj.tfMap(b);
            obj.hYGalvoInputChannelIDPopUp.Enable = obj.tfMap(b);
            
            [tf,idx] = ismember(v,obj.hConfigEditor.availableDaqs);
            if b && tf
                obj.numFdbkAIs = obj.hConfigEditor.daqInfo(idx).numAIs;
            else
                obj.numFdbkAIs = 32;
            end
            ais = [{'None'} arrayfun(@(x)sprintf('AI%d',x),0:(obj.numFdbkAIs-1),'uniformoutput',false)...
                arrayfun(@(x)sprintf('AI%d (RSE)',x),0:(obj.numFdbkAIs-1),'uniformoutput',false)...
                arrayfun(@(x)sprintf('AI%d (NRSE)',x),0:(obj.numFdbkAIs-1),'uniformoutput',false)];
            
            % Event when new daq has fewer outputs/inputs than previous
            [tf_xGalvoInput, idx_xGalvoInput] = ismember(obj.hXGalvoInputChannelIDPopUp.String(obj.hXGalvoInputChannelIDPopUp.Value), ais);
            if tf_xGalvoInput
                obj.hXGalvoInputChannelIDPopUp.Value = idx_xGalvoInput;
            else
                obj.hXGalvoInputChannelIDPopUp.Value = 1;
            end
            
            obj.hXGalvoInputChannelIDPopUp.String = ais;
            
            % Event when new daq has fewer outputs/inputs than previous
            [tf_yGalvoInput, idx_yGalvoInput] = ismember(obj.hYGalvoInputChannelIDPopUp.String(obj.hYGalvoInputChannelIDPopUp.Value), ais);
            if tf_yGalvoInput
                obj.hYGalvoInputChannelIDPopUp.Value = idx_yGalvoInput;
            else
                obj.hYGalvoInputChannelIDPopUp.Value = 1;
            end
            
            obj.hYGalvoInputChannelIDPopUp.String = ais;
        end
        
        function set.motionDaq(obj,v)
            if isempty(v)
                v = 'None';
            end
            if ~ismember(v,obj.hMotionCorrDaqPopUp.String)
                obj.hMotionCorrDaqPopUp.String{end+1} = v;
            end
            obj.motionDaq = v;
            
            b = ~strcmp(v,'None');
            obj.hXGalvoAnalogOutputOffsetPopUp.Enable = obj.tfMap(b);
            obj.hXGalvoMaximumVoltageOutputEdit.Enable = obj.tfMap(b);
            obj.hYGalvoAnalogOutputOffsetPopUp.Enable = obj.tfMap(b);
            obj.hYGalvoMaximumVoltageOutputEdit.Enable = obj.tfMap(b);
            
            [tf,idx] = ismember(v,obj.hConfigEditor.availableDaqs);
            if b && tf
                numAOs = obj.hConfigEditor.daqInfo(idx).numAOs;
            else
                numAOs = 2;
            end
            ais = [{'None'} arrayfun(@(x)sprintf('AO%d',x),0:(numAOs-1),'uniformoutput',false)];
            
            % Event when new daq has fewer outputs/inputs than previous
            [tf_xGalvoOutput, idx_xGalvoOutput] = ismember(obj.hXGalvoAnalogOutputOffsetPopUp.String(obj.hXGalvoAnalogOutputOffsetPopUp.Value), ais);
            if tf_xGalvoOutput
                obj.hXGalvoAnalogOutputOffsetPopUp.Value = idx_xGalvoOutput;
            else
                obj.hXGalvoAnalogOutputOffsetPopUp.Value = 1;
            end
            
            obj.hXGalvoAnalogOutputOffsetPopUp.String = ais;
            
            % Event when new daq has fewer outputs/inputs than previous
            [tf_yGalvoOutput, idx_yGalvoOutput] = ismember(obj.hYGalvoAnalogOutputOffsetPopUp.String(obj.hYGalvoAnalogOutputOffsetPopUp.Value), ais);
            if tf_yGalvoOutput
                obj.hYGalvoAnalogOutputOffsetPopUp.Value = idx_yGalvoOutput;
            else
                obj.hYGalvoAnalogOutputOffsetPopUp.Value = 1;
            end
             
            obj.hYGalvoAnalogOutputOffsetPopUp.String = ais;
        end
    end
end

function nm = opDaqNm(nm)
    if strcmp(nm, 'None')
        nm = '';
    end
end

function i = opDaqCh(i)
    if i < 0
        i = [];
    end
end


%--------------------------------------------------------------------------%
% LinScanPage.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
