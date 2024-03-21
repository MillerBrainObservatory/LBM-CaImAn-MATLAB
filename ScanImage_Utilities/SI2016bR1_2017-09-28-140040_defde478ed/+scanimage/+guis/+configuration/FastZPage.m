classdef FastZPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hMotorPanel;
        hActuatorList;
        hRemove;
        hNoSelText;
        hScannerTable;
        hParamTable;
        hLimitTable;
        hComPortPopup;
        
        actuators;
    end
    
    properties (SetObservable)
        actuatorList = {};
        mtrChoices = {};
        
        controllerType = '';
        
        comPort = '';
        comChoices = {};
        
        daqChoices = {};
        
        additionalParamStr;
        
        daqName = '';
        
        aoOptions = {};
        aiOptions = {};
        pfiOptions = {};
        
        aoChan;
        aiChan;
        pfiChan;
    end
    
    properties (Constant)
        defaultPagePath = '+scanimage\+components\private\FastZ_model.m';
    end
    
    methods
        function obj = FastZPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'FastZ Actuator Setup';
            obj.heading = 'FastZ';
            obj.descriptionText = 'FastZ hardware is used for fast axial motion, supporting fast stacks and/or volume imaging. Multiple FastZ actuators can be defined with each either globally affecting all scan systems or only affecting the focus of one scan system.';
            
            ph = 875;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 990 ph]);
        
            uicontrol('parent', obj.hPanel, ...
                'Style', 'text', ...
                'HorizontalAlignment', 'left', ...
                'String', 'Configured FastZ Actuators', ...
                'fontsize',10,...
                'Units', 'pixels', ...
                'Position', [46 ph-44 200 16]);
            
            obj.hActuatorList = most.gui.uicontrol('parent', obj.hPanel, ...
                'Style', 'listbox', ...
                'callback',@obj.selectionChanged,...
                'Units', 'pixels', ...
                'Bindings',{obj 'actuatorList' 'choices'},...
                'Position', [46 ph-97 190 49]);
            
            uicontrol('parent', obj.hPanel, ...
                'string','Add New',...
                'Units', 'pixels', ...
                'Position', [46 ph-132 74 28], ...
                'callback',@obj.addNew);
            
            obj.hRemove = uicontrol('parent', obj.hPanel, ...
                'string','Remove Selected',...
                'Units', 'pixels', ...
                'Position', [126 ph-132 110 28], ...
                'callback',@obj.removeSelected);
        
            mph = 670;
            mpw = 780;
            obj.hMotorPanel = uipanel( ...
                'parent', obj.hPanel, ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 ph-164-mph mpw mph]);
            
            uicontrol( ...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Configure controller connection settings and DAQ channels for control and position feedback of the actuator.', ...  
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 mph-54 676 16]);
            
            obj.hNoSelText = uicontrol( ...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Add or select a FastZ actuator above in order to configure it...', ...  
                'HorizontalAlignment', 'center', ...
                'FontSize',11,...
                'ForegroundColor',.5*ones(1,3),...
                'Units', 'pixels', ...
                'Visible','off',...
                'Position', [1 mph-56 mpw-2 30]);
            
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Controller Type', ...
                'TooltipString', '', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 mph-94 108 14]);
        
            most.gui.uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'popupmenu', ...
                'String', {'None'}, ...
                'TooltipString', '', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings',{{obj.hConfigEditor 'fastZMotors' 'choices'} {obj 'controllerType' 'choice'}},...
                'Position', [206 mph-98 150 22]);
                
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Serial COM Port', ...
                'TooltipString', 'If using serial communication, enter COM Port for the controller.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 mph-134 108 14]);
            
            obj.hComPortPopup = most.gui.popupMenuEdit(...
                'parent', obj.hMotorPanel, ...
                'Position', [206 mph-138 60 22],...
                'validationFunc',@obj.validateComChoice,...
                'Bindings',{{obj 'comPort' 'string'} {obj 'comChoices' 'choices'}});
            
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Additional Params (Optional)', ...
                'TooltipString', 'Some motor controllers take optional parameters. Specify these as property-value pairs ie: {''baudRate'' 9600}.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 mph-174 148 14]);
        
            most.gui.uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'edit', ...
                'String', '', ...
                'TooltipString', 'Some motor controllers take optional parameters. Specify these as property-value pairs ie: {''baudRate'' 9600}.', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'Bindings',{{obj 'additionalParamStr' 'string'}},...
                'Position', [206 mph-178 150 22]);
            
            
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'DAQ Device Name', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [400 mph-94 106 14]);
            
            most.gui.popupMenuEdit(...
                'parent', obj.hMotorPanel, ...
                'Position', [575 mph-98 150 22],...
                'validationFunc',@obj.validateDaqChoice,...
                'Bindings',{{obj 'daqName' 'string'} {obj 'daqChoices' 'choices'}});
        
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Position Control AO Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [400 mph-134 160 14]);
        
            most.gui.uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'Units', 'pixels', ...
                'Bindings',{{obj 'aoOptions' 'choices'} {obj 'aoChan' 'value'}},...
                'Position', [575 mph-137 60 20]);
        
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Position Sensor AI Channel ID', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [400 mph-174 160 14]);
        
            most.gui.uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'Units', 'pixels', ...
                'Bindings',{{obj 'aiOptions' 'choices'} {obj 'aiChan' 'value'}},...
                'Position', [575 mph-177 60 20]);
            
            
            uicontrol( ...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Select XY scan systems that are focused by this actuator. If none are selected, actuator applies to all scanners.', ...  
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 mph-234 676 16]);
            
            obj.hScannerTable = uitable( ... 
                'parent', obj.hMotorPanel, ...
                'ColumnName', {'Select', 'Scan System'}, ...
                'ColumnFormat', {'logical', 'char'}, ...
                'ColumnEditable', [true, false], ...
                'ColumnWidth', {50, 200}, ...
                'RowName', [], ...
                'Units', 'pixels', ...
                'CellEditCallback',@obj.scannerTblCb,...
                'Position', [46 mph-342 274 100]);
            
            
            uicontrol( ...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Configure analog control and sensor signal parameters (if using generic analog controller) and position range limits.', ...  
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 mph-400 676 16]);
            
            
            obj.hParamTable = uitable( ... 
                'parent', obj.hMotorPanel, ...
                'ColumnName', {'Parameter' 'Units' 'Value'}, ...
                'ColumnFormat', {'char' 'char' 'numeric'}, ...
                'ColumnEditable', [false false true], ...
                'ColumnWidth', {200, 50, 52}, ...
                'Data',{'Command Signal Scale Factor' cntr('V/um',50) []; 'Command Signal Offset' cntr('V',50) [];...
                'Sensor Signal Scale Factor (Optional)' cntr('V/um',50) []; 'Sensor Signal Offset (Optional)' cntr('V',50) []},...
                'RowName', [], ...
                'Units', 'pixels', ...
                'CellEditCallback',@obj.paramTblCb,...
                'Position', [46 mph-505 304 94]);
            
            obj.hLimitTable = uitable( ... 
                'parent', obj.hMotorPanel, ...
                'ColumnName', {'Parameter' 'Units' 'Value'}, ...
                'ColumnFormat', {'char' 'char' 'numeric'}, ...
                'ColumnEditable', [false false true], ...
                'ColumnWidth', {170, 50, 52}, ...
                'Data',{'Maximum Command Position' cntr('um',50) []; 'Maximum Command Voltage' cntr('V',50) [];...
                'Minimum Command Position' cntr('um',50) []; 'Minimum Command Voltage' cntr('V',50) []},...
                'RowName', [], ...
                'Units', 'pixels', ...
                'CellEditCallback',@obj.limitTblCb,...
                'Position', [400 mph-505 274 94]);
            
            
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', ['Trigger routing must be set manually for some hardware configurations. For resonant scanning, automatic routing can be used if FastZ DAQ is in the same PXI '...
                'chassis as the FPGA/digitizer. For linear scanning, automatic routing can be used if the FastZ DAQ is in the same PXI chassis as or connected via RTSI cable to the '...
                'Auxilliary Clock Device. Otherwise the frame clock must be wired and configured below.'], ...
                'HorizontalAlignment', 'left', ...
                'fontsize',10,...
                'Units', 'pixels', ...
                'Position', [46 mph-610 690 64]);
        
            uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'text', ...
                'String', 'Frame Clock Input Terminal', ...
                'TooltipString', 'Select Automatic Routing if done through the PXI bus.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 mph-635 150 14]);
        
            most.gui.uicontrol(...
                'parent', obj.hMotorPanel, ...
                'Style', 'popupmenu', ...
                'String', {'Auto'}, ...
                'Bindings',{{obj 'pfiOptions' 'choices'} {obj 'pfiChan' 'value'}},...
                'TooltipString', 'Select Automatic Routing if done through the PXI bus.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [220 mph-638 60 20]);
            
            obj.reload();
        end
        
        function delete(obj)
        end
        
        function refreshPageDependentOptions(obj)
            sv = obj.hScannerTable.Data;
            if ~isempty(sv)
                nms = sv([sv{:,1}],2);
            else
                nms = {};
            end
            
            obj.hScannerTable.Data = [num2cell(false(numel(obj.hConfigEditor.scannerNames),1)) obj.hConfigEditor.scannerNames];
            
            if ~isempty(nms)
                obj.hScannerTable.Data(:,1) = num2cell(ismember(obj.hScannerTable.Data(:,2),nms));
            end
            
            obj.comChoices = [{'None'}; obj.hConfigEditor.availableComPorts];
            
            obj.daqChoices = obj.hConfigEditor.availableDaqs([obj.hConfigEditor.daqInfo.isXSer])';
        end
        
        function reload(obj)
            obj.refreshPageDependentOptions();
            
            mdfData = obj.getCurrentMdfDataStruct();
            emps = arrayfun(@(s)isempty(s.controllerType),mdfData.actuators);
            obj.actuators = mdfData.actuators(~emps);
            obj.updateActuatorListNames();
            obj.hActuatorList.Value = 1;
            obj.selectionChanged();
        end
        
        function updateActuatorListNames(obj)
            if isempty(obj.actuators)
                obj.actuatorList = {};
            else
                names = {obj.actuators.controllerType};
                dat = cellfun(@(x)obj.hConfigEditor.hMotorRegistry.getControllerInfo(x),names);
                obj.actuatorList = arrayfun(@(rd,d){[rd.ListName ' (' scnnrs(d) ')']},dat,obj.actuators);
            end
            
            function s = scnnrs(data)
                if isempty(data.affectedScanners)
                    s = 'Default';
                else
                    s = data.affectedScanners{1};
                    for i = 2:numel(data.affectedScanners)
                        s = [s ', ' data.affectedScanners{i}];
                    end
                end
            end
        end
        
        function s = getNewVarStruct(obj)
            s = obj.getCurrentMdfDataStruct();
            
            % if there used to be more motors than there are now, make sure
            % the controller is blanked on the extra entries
            s.actuators = arrayfun(@(s)setfield(s, 'controllerType', ''),s.actuators);
            
            s.actuators(1:numel(obj.actuators)) = obj.actuators;
        end
        
        function [lvl,v,errMsg] = validateDaqChoice(obj,v,oldV)
%             if ~isvarname(v)
%                 v = oldV;
%             end
            
            lvl = 1 - ismember(v,obj.daqChoices);
            if lvl
                errMsg = 'DAQ not found.';
            else
                errMsg = '';
            end
        end
        
        function [lvl,v,errMsg] = validateComChoice(obj,v,~)
            errMsg = '';
            if all(isstrprop(v, 'digit'))
                v = ['COM' v];
            elseif strncmpi(v,'com',3) && (length(v) > 3) && all(isstrprop(v(4:end), 'digit'))
                v(1:3) = 'COM';
            else
                if strcmp(v,'None')
                    lvl = 0;
                else
                    lvl = 2;
                    errMsg = 'Must be a numeric COM port ID.';
                end
                return;
            end
            
            if ismember(v,obj.comChoices)
                lvl = 0;
            else
                lvl = 1;
                errMsg = 'COM port not found. If ScanImage is running, this could be because the port is currently open.';
            end
        end
        
        function scannerTblCb(obj,src,~)
            sv = src.Data;
            if ~isempty(sv)
                idx = obj.hActuatorList.Value;
                
                nms = sv([sv{:,1}],2)';
                if isempty(nms)
                    obj.actuators(idx).affectedScanners = {};
                else
                    obj.actuators(idx).affectedScanners = nms;
                end
                
                obj.updateActuatorListNames();
                v = obj.hActuatorList.Value;
                obj.hMotorPanel.Title = ['Actuator Settings: ' obj.actuatorList{v}];
            end
        end
        
        function paramTblCb(obj,src,~)
            idx = obj.hActuatorList.Value;
            
            nans = cellfun(@(x)~isempty(x)&&isnan(x),src.Data(:,3));
            src.Data(nans,3) = {[]};
            
            obj.actuators(idx).commandVoltsPerMicron = src.Data{1,3};
            obj.actuators(idx).commandVoltsOffset = src.Data{2,3};
            obj.actuators(idx).sensorVoltsPerMicron = src.Data{3,3};
            obj.actuators(idx).sensorVoltsOffset = src.Data{4,3};
        end
        
        function limitTblCb(obj,src,~)
            idx = obj.hActuatorList.Value;
            
            nans = cellfun(@(x)~isempty(x)&&isnan(x),src.Data(:,3));
            src.Data(nans,3) = {[]};
            
            obj.actuators(idx).maxCommandPosn = src.Data{1,3};
            obj.actuators(idx).maxCommandVolts = src.Data{2,3};
            obj.actuators(idx).minCommandPosn = src.Data{3,3};
            obj.actuators(idx).minCommandVolts = src.Data{4,3};
        end
    end
    
    methods
        function addNew(obj,varargin)
            obj.actuators(end+1).controllerType = 'analog';
            obj.actuators(end).customArgs = {};
            obj.actuators(end).cmdOutputChanID = 0;
            obj.actuators(end).sensorInputChanID = 0;
            obj.actuators(end).affectedScanners = {};
            
            if ~isempty(obj.daqChoices)
                obj.actuators(end).daqDeviceName = obj.daqChoices{1};
            end
            
            obj.updateActuatorListNames();
            obj.hActuatorList.Value = numel(obj.actuators);
            obj.selectionChanged();
        end
        
        function removeSelected(obj,varargin)
            v = obj.hActuatorList.Value;
            if (v > 0) && (v <= numel(obj.actuators))
                obj.actuators(v) = [];
            end
            
            obj.updateActuatorListNames();
            obj.hActuatorList.Value = min(obj.hActuatorList.Value,numel(obj.actuatorList));
            obj.selectionChanged();
        end
        
        function selectionChanged(obj,varargin)
            if isempty(obj.actuators)
                obj.hMotorPanel.Title = '';
                obj.hActuatorList.Value = 1;
                set(obj.hMotorPanel.Children, 'visible', 'off');
                obj.hNoSelText.Visible = 'on';
                obj.hRemove.Enable = 'off';
            else
                v = obj.hActuatorList.Value;
                
                obj.controllerType = obj.hConfigEditor.hMotorRegistry.getControllerInfo(obj.actuators(v).controllerType).ListName;
                
                comP = obj.actuators(v).comPort;
                if isempty(comP)
                    obj.comPort = 'None';
                elseif isnumeric(comP)
                    obj.comPort = sprintf('COM%d',comP);
                else
                    obj.comPort = comP;
                end
                
                obj.additionalParamStr = most.util.cell2str(obj.actuators(v).customArgs);
                
                obj.daqName = obj.actuators(v).daqDeviceName;
                
                obj.aoChan = min(obj.actuators(v).cmdOutputChanID+1,numel(obj.aoOptions));
                
                if isempty(obj.actuators(v).sensorInputChanID)
                    obj.aiChan = 1;
                else
                    obj.aiChan = min(obj.actuators(v).sensorInputChanID + 2,numel(obj.aiOptions));
                end
                
                if isempty(obj.actuators(v).frameClockIn)
                    obj.pfiChan = 1;
                else
                    obj.pfiChan = min(str2double(obj.actuators(v).frameClockIn(4:end)) + 2,numel(obj.pfiOptions));
                end
                
                obj.hScannerTable.Data(:,1) = num2cell(ismember(obj.hScannerTable.Data(:,2),obj.actuators(v).affectedScanners));
                
                obj.hParamTable.Data(:,3) = {obj.actuators(v).commandVoltsPerMicron; obj.actuators(v).commandVoltsOffset; obj.actuators(v).sensorVoltsPerMicron; obj.actuators(v).sensorVoltsOffset};
                obj.hLimitTable.Data(:,3) = {obj.actuators(v).maxCommandPosn; obj.actuators(v).maxCommandVolts; obj.actuators(v).minCommandPosn; obj.actuators(v).minCommandVolts};
                
                obj.hMotorPanel.Title = ['Actuator Settings: ' obj.actuatorList{v}];
                set(obj.hMotorPanel.Children, 'visible', 'on');
                obj.hNoSelText.Visible = 'off';
                obj.hRemove.Enable = 'on';
            end
        end
    end
    
    methods
        function set.controllerType(obj,v)
            obj.controllerType = v;
            
            idx = obj.hActuatorList.Value;
            obj.actuators(idx).controllerType = obj.hConfigEditor.motorName2RegMap(v);
            obj.updateActuatorListNames();
            
            isAnalog = strcmp(obj.actuators(idx).controllerType, 'analog');
            isSim = strcmp(obj.actuators(idx).controllerType, 'simulated.piezo');
            obj.hParamTable.Enable = obj.hConfigEditor.tfMap(isAnalog);
            obj.hComPortPopup.enable = obj.hConfigEditor.tfMap(~isAnalog && ~isSim);
        end
        
        function set.daqName(obj,v)
            if isempty(v)
                v = '';
            end
            obj.daqName = v;
            
            idx = obj.hActuatorList.Value;
            obj.actuators(idx).daqDeviceName = v;
            
            % update channel options
            [tf,did] = ismember(v,obj.hConfigEditor.availableDaqs);
            if tf
                aos = obj.hConfigEditor.daqInfo(did).allAOs;
                ais = obj.hConfigEditor.daqInfo(did).allAIs;
                numPfis = obj.hConfigEditor.daqInfo(did).numPFIs;
            else
                aos = {'AO0' 'AO1'};
                ais = arrayfun(@(n){sprintf('AI%d',n)},0:15);
                numPfis = 16;
            end
            obj.aoOptions = aos;
            obj.aiOptions = [{'None'} ais];
            obj.pfiOptions = [{'Auto'} arrayfun(@(n){sprintf('PFI%d',n)},0:(numPfis-1))];
        end
        
        function set.comPort(obj,v)
            obj.comPort = v;
            
            idx = obj.hActuatorList.Value;
            
            if strcmp(v,'None')
                obj.actuators(idx).comPort = [];
            elseif strncmpi(v,'com',3) && (length(v) > 3) && all(isstrprop(v(4:end), 'digit'))
                obj.actuators(idx).comPort = str2double(v(4:end));
            else
                obj.actuators(idx).comPort = v;
            end
        end
        
        function set.additionalParamStr(obj,v)
            obj.additionalParamStr = v;
            
            idx = obj.hActuatorList.Value;
            
            msg = 'The additional parameter string should be a cell array of property-value pairs.';
            try
                p = eval(v);
                assert(iscell(p) && ~mod(numel(p),2),msg);
                obj.actuators(idx).customArgs = p;
            catch
                msgbox(msg,'Controller Configuration','warn');
            end
        end
        
        function set.aoChan(obj,v)
            obj.aoChan = v;
            
            idx = obj.hActuatorList.Value;
            obj.actuators(idx).cmdOutputChanID = v-1;
        end
        
        function set.aiChan(obj,v)
            obj.aiChan = v;
            
            idx = obj.hActuatorList.Value;
            if v == 1
                obj.actuators(idx).sensorInputChanID = [];
            else
                obj.actuators(idx).sensorInputChanID = v-2;
            end
        end
        
        function set.pfiChan(obj,v)
            obj.pfiChan = v;
            
            idx = obj.hActuatorList.Value;
            if v == 1
                obj.actuators(idx).frameClockIn = '';
            else
                obj.actuators(idx).frameClockIn = sprintf('PFI%d',v-2);
            end
        end
    end
end

function s = cntr(s,w)
    w = num2str(w);
    s = ['<html><table border=0 width=' w '><TR><TD><center>' s '</center></TD></TR></table></html>'];
end


%--------------------------------------------------------------------------%
% FastZPage.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
