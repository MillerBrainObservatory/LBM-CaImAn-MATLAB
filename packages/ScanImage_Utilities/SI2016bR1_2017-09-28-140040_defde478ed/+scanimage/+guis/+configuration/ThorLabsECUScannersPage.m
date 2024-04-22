classdef ThorLabsECUScannersPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hScannerNameText;
        hScannerNamePopUp;
        hScannerErrorText;
        hECUComPortText;
        hECUComPortPopUp;
    end
    
    properties (Constant)
        defaultPagePath = '+dabs\+thorlabs\private\ECU1_model.m';
    end
    
    methods
        function obj = ThorLabsECUScannersPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'ThorLabs ECU Scanner';
            obj.heading =  'Thorlabs ECU1';
            obj.descriptionText = 'Configure a resonant scanner to link to a Thorlabs ECU1 device. This will configure the selected scanner to communicate with the ECU on the selected serial COM port.';
            
            ph = 110;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 450 ph]);    %,'BackgroundColor',[1 .8 1]);

             % ScannerNameText
            obj.hScannerNameText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ScannerNameText', ...
                'Style', 'text', ...
                'String', 'Scanner Name', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Scanner name (from first MDF section) to link to. Must be a resonant scanner.', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 130 14]);
        
            % ScannerNamePopUp 
            obj.hScannerNamePopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ScannerNamePopUp', ...
                'Style', 'popupmenu', ...
                'String', cat(2, 'None', obj.hConfigEditor.scannerNames()'), ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Scanner name (from first MDF section) to link to. Must be a resonant scanner.', ...
                'Units', 'pixels', ...
                'Position', [246 ph-44 150 20]);

            % ScannerErrorText
            obj.hScannerErrorText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ScannerErrorText', ...
                'Style', 'text', ...
                'String', '*No Scanning Systems have been configured. Please see the "Scanning Systems Table" in the "General ScanImage Settings" section.', ...
                'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1.0 0.0 0.0], ...
                'Visible', 'off', ...
                'Units', 'pixels', ...
                'Position', [426 ph-56 350 33]);
        
            % ECUComPortText
            obj.hECUComPortText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ECUComPortText', ...
                'Style', 'text', ...
                'String', 'ECU COM Port', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'ID of the ThorECU USB Serial Port (e.g. 12 for COM12).', ...
                'Units', 'pixels', ...
                'Position', [46 ph-86 189 14]);
        
            % ECUComPortPopUp 
            obj.hECUComPortPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ECUComPortPopUp', ...
                'Style', 'popupmenu', ...
                'String', cat(2, 'None', obj.hConfigEditor.availableComPorts()'), ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'ID of the ThorECU USB Serial Port (e.g. 12 for COM12).', ...
                'Units', 'pixels', ...
                'Position', [246 ph-88 60 20]);
        
            obj.reload();
        end
        
        function delete(obj)
        end
        
        function applySmartDefaultSettings(obj)
            % change settings to appropriate default values
            s = struct();
            obj.applyVarStruct(s);
            obj.reload();
        end

        function refreshPageDependentOptions(obj)
            selectedItemScannerNames = get(obj.hScannerNamePopUp, 'String');
            scannerName = selectedItemScannerNames{obj.hScannerNamePopUp.Value};
            if strcmp(scannerName, 'None')
                scannerName = '';
            end
            
            scannerNames = obj.hConfigEditor.scannerNames()';
            scannerNames(cellfun(@(x)~strcmp(x,'Resonant'),obj.hConfigEditor.scannerTypes)) = [];

            if ~isempty(scannerNames)
                obj.hScannerNamePopUp.String = [{'None'} scannerNames];
                obj.hECUComPortText.Enable = 'on';
                obj.hECUComPortPopUp.Enable = 'on';
                obj.hScannerErrorText.Visible = 'off';
            else
                obj.hScannerNamePopUp.String = {'None'};
                obj.hScannerNamePopUp.Value = 1;
                obj.hECUComPortText.Enable = 'off';
                obj.hECUComPortPopUp.Enable = 'off';
                obj.hScannerErrorText.Visible = 'on';
                return;
            end
            
            if ~isempty(scannerName)
                [tf,idx] = ismember(scannerName,scannerNames);
                if tf
                    obj.hScannerNamePopUp.Value = idx+1;
                else
                    obj.hScannerNamePopUp.Value = 1;
                end
            else
                obj.hScannerNamePopUp.Value = 1;
            end
        end

        function reload(obj)
            obj.refreshPageDependentOptions();
            
            % this or some other mdf section has changed. reload the settings
            mdfData = obj.getCurrentMdfDataStruct();
            
            strDx=find(ismember(obj.hScannerNamePopUp.String,mdfData.scannerName));
            
            if isempty(strDx)
                obj.hScannerNamePopUp.Value = 1;
            else
                obj.hScannerNamePopUp.Value = strDx;
            end

            % ECU Com Port
            obj.hECUComPortPopUp.String = cat(2, 'None', obj.hConfigEditor.availableComPorts()');
            
            if isempty(mdfData.comPort)
                obj.hECUComPortPopUp.Value = 1;
            else
                cm = sprintf('COM%d', mdfData.comPort);
                str = obj.hECUComPortPopUp.String;
                [tf,strDx] = ismember(cm,str);
                
                if tf
                    obj.hECUComPortPopUp.Value = strDx;
                else
                    obj.hECUComPortPopUp.String{end+1} = cm;
                    obj.hECUComPortPopUp.Value = numel(str) + 1;
                end
            end
            
        end % function - reload
        
        function s = getNewVarStruct(obj)
            
            selectedItemScannerNames = get(obj.hScannerNamePopUp, 'String');
            selectedItemComPorts = cellstr(get(obj.hECUComPortPopUp, 'String')); % Ensure value is a cell array.
            
            trimmedComPort = strtrim(selectedItemComPorts{obj.hECUComPortPopUp.Value});
            trimmedComPort = str2double(trimmedComPort(4:end));
            if isempty(trimmedComPort) || isnan(trimmedComPort)
                trimmedComPort = [];
            end
            
            tmpStr = strtrim(selectedItemScannerNames{obj.hScannerNamePopUp.Value});
            
            if strcmp(tmpStr, 'None')
                tmpStr = '';
            end
            
            s = struct('scannerName', tmpStr, 'comPort', trimmedComPort);

        end % function - getNewVarStruct

    end % methods

end % classdef - ThorLabsECUScannersPage


%--------------------------------------------------------------------------%
% ThorLabsECUScannersPage.m                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
