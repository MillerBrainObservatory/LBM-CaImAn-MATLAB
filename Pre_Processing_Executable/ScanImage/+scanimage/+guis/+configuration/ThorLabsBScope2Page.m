classdef ThorLabsBScope2Page < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hScannerNameText;
        hScannerNamePopUp;
        hECU2ComPortText;
        hECU2ComPortPopUp;
        hGalvoGalvoMirrorComPortText;
        hGalvoGalvoMirrorComPortPopUp;
        hGalvoGalvoMirrorInvertCheckBox;
        hGalvoResonantMirrorComPortText;
        hGalvoResonantMirrorComPortPopUp;
        hGalvoResonantMirrorInvertCheckBox;
        hFlipperMirrorComPortText;
        hFlipperMirrorComPortPopUp;
        hFlipperMirrorInvertCheckBox;
        hPmtControllerTable;
        
        menuItemsComPorts;        
        numPMTControllers = 0;

        pmtControllerActualValues;
        pmtTableDeleteField = 2;
    end
    
    properties (Constant)
        defaultPagePath = '+dabs\+thorlabs\private\BScope2_model.m';
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
    end

    properties
        keyDown = false;
    end
    
    methods
        function obj = ThorLabsBScope2Page(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'ThorLabs BScope2 Setup';
            obj.heading =  'Thorlabs BScope2';          %Note: This value MUST match the '%%' Heading value in the Machine Data File.
            obj.descriptionText = 'Configure a Thorlabs B-Scope 2. Select a resonant scanner to link to the Thorlabs ECU2 on the selected serial COM port. If USB mirror controllers are available select the appropriate COM port. If USB PMT''s are available enter the VISA address or 6 digit serial numbers.';

            ph = 400;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 600 ph]);

            obj.menuItemsComPorts = cellstr(cat(2, 'None', obj.hConfigEditor.availableComPorts()')); % Ensures value is always cell array
            
            % ScannerNameText
            obj.hScannerNameText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ScannerNameText', ...
                'Style', 'text', ...
                'String', 'Scanner Name', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Scanner name (from first MDF section) to link to. Must be a resonant scanner. Leave empty if not using a resonant scanner.', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 130 14]);
        
            % ScannerNamePopUp 
            obj.hScannerNamePopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ScannerNamePopUp', ...
                'Style', 'popupmenu', ...
                'String', cat(2, 'None', obj.hConfigEditor.scannerNames()'), ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Scanner name (from first MDF section) to link to. Must be a resonant scanner. Leave empty if not using a resonant scanner.', ...
                'Units', 'pixels', ...
                'Position', [246 ph-44 150 20]);
        
            % ECU2ComPortText
            obj.hECU2ComPortText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ECU2ComPortText', ...
                'Style', 'text', ...
                'String', 'ECU COM Port', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Serial COM port for ECU commands.', ...
                'Units', 'pixels', ...
                'Position', [46 ph-86 189 14]);
        
            % ECU2ComPortPopUp 
            obj.hECU2ComPortPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ECU2ComPortPopUp', ...
                'Style', 'popupmenu', ...
                'String', obj.menuItemsComPorts, ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Serial COM port for ECU commands.', ...
                'Units', 'pixels', ...
                'Position', [246 ph-88 60 20]);
        
            % GalvoGalvoMirrorComPortText
            obj.hGalvoGalvoMirrorComPortText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoGalvoMirrorComPortText', ...
                'Style', 'text', ...
                'String', 'Galvo-Galvo Flipper Mirror COM Port', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Serial COM port for controlling Galvo-Galvo mirror. Leave empty is mirrors are connected to stage controller (MCM5000).', ...
                'Units', 'pixels', ...
                'Position', [46 ph-130 195 14]);
        
            % GalvoGalvoMirrorComPortPopUp 
            obj.hGalvoGalvoMirrorComPortPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoGalvoMirrorComPortPopUp', ...
                'Style', 'popupmenu', ...
                'String', obj.menuItemsComPorts, ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Serial COM port for controlling Galvo-Galvo mirror. Leave empty is mirrors are connected to stage controller (MCM5000).', ...
                'Units', 'pixels', ...
                'Position', [246 ph-131 60 20]);
        
            % GalvoGalvoMirrorInvertCheckBox 
            obj.hGalvoGalvoMirrorInvertCheckBox = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoGalvoMirrorInvertCheckBox', ...
                'Style', 'checkbox', ...
                'String', 'Invert Mirror Position', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Reverse mirror position polarity.', ...
                'Units', 'pixels', ...
                'Position', [323 ph-132 129 20]);
        
            % GalvoResonantMirrorComPortText
            obj.hGalvoResonantMirrorComPortText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoResonantMirrorComPortText', ...
                'Style', 'text', ...
                'String', 'Resonant-Galvo Flipper Mirror COM Port', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Serial COM port for controlling Galvo-Resonant mirror. Leave empty is mirrors are connected to stage controller (MCM5000).', ...
                'Units', 'pixels', ...
                'Position', [46 ph-175 195 14]);
        
            % GalvoResonantMirrorComPortPopUp 
            obj.hGalvoResonantMirrorComPortPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoResonantMirrorComPortPopUp', ...
                'Style', 'popupmenu', ...
                'String', obj.menuItemsComPorts, ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Serial COM port for controlling Galvo-Resonant mirror. Leave empty is mirrors are connected to stage controller (MCM5000).', ...
                'Units', 'pixels', ...
                'Position', [246 ph-176 60 20]);
        
            % GalvoResonantMirrorInvertCheckBox 
            obj.hGalvoResonantMirrorInvertCheckBox = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'GalvoResonantMirrorInvertCheckBox', ...
                'Style', 'checkbox', ...
                'String', 'Invert Mirror Position', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Reverse mirror position polarity.', ...
                'Units', 'pixels', ...
                'Position', [323 ph-177 129 20]);
        
            % FlipperMirrorComPortText
            obj.hFlipperMirrorComPortText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'FlipperMirrorComPortText', ...
                'Style', 'text', ...
                'String', 'Camera PMT Flipper Mirror COM Port', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Serial COM port for controlling Flipper mirror. Leave empty is mirrors are connected to stage controller (MCM5000).', ...
                'Units', 'pixels', ...
                'Position', [46 ph-219 195 14]);
        
            % FlipperMirrorComPortPopUp 
            obj.hFlipperMirrorComPortPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'FlipperMirrorComPortPopUp', ...
                'Style', 'popupmenu', ...
                'String', obj.menuItemsComPorts, ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Serial COM port for controlling Flipper mirror. Leave empty is mirrors are connected to stage controller (MCM5000).', ...
                'Units', 'pixels', ...
                'Position', [246 ph-220 60 20]);
        
            % FlipperMirrorInvertCheckBox 
            obj.hFlipperMirrorInvertCheckBox = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'FlipperMirrorInvertCheckBox', ...
                'Style', 'checkbox', ...
                'String', 'Invert Mirror Position', ...
                'HorizontalAlignment', 'center', ...
                'TooltipString', 'Reverse mirror position polarity.', ...
                'Units', 'pixels', ...
                'Position', [323 ph-221 129 20]);
        
            % PMTController Table
            pmtControllerColumnNames      = {'USB PMT Controller|Serial Number or VISA Address', 'Delete'};
            pmtControllerColumnFormats    = {'char', 'char'};
            pmtControllerColumnEditable   = [true, false];
            pmtControllerColumnWidths     = {200, 50};
            pmtControllerBlankRow         = {'' obj.delChar};
            
            obj.hPmtControllerTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'pmtControllerTable', ...
                'Data', pmtControllerBlankRow, ...
                'ColumnName', pmtControllerColumnNames, ...
                'ColumnFormat', pmtControllerColumnFormats, ...
                'ColumnEditable', pmtControllerColumnEditable, ...
                'ColumnWidth', pmtControllerColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'Position', [46 ph-369 253 117], ...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'CellEditCallback', @obj.cellEditFcn, ...
                'CellSelectionCallback', @obj.cellSelectFcn);
        
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
            else
                obj.hScannerNamePopUp.String = {'None'};
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
            
            % reload settings from the file
            mdfData = obj.getCurrentMdfDataStruct();
            
            % fix old named fields
            if isfield(mdfData, 'pmtDevNames')
                obj.hConfigEditor.hMDF.removeVarFromHeading('Thorlabs BScope2','pmtDevNames');
                obj.hConfigEditor.hMDF.writeVarToHeading('Thorlabs BScope2','pmtDevAddresses',mdfData.pmtDevNames);
                mdfData.pmtDevAddresses = mdfData.pmtDevNames;
            elseif isfield(mdfData, 'pmtDevAdresses')
                obj.hConfigEditor.hMDF.removeVarFromHeading('Thorlabs BScope2','pmtDevAdresses');
                obj.hConfigEditor.hMDF.writeVarToHeading('Thorlabs BScope2','pmtDevAddresses',mdfData.pmtDevAdresses);
                mdfData.pmtDevAddresses = mdfData.pmtDevAdresses;
            elseif ~isfield(mdfData, 'pmtDevAddresses')
                mdfData.pmtDevAddresses = {'' '' '' ''};
                obj.hConfigEditor.hMDF.writeVarToHeading('Thorlabs BScope2','pmtDevAddresses',mdfData.pmtDevAddresses);
            end
            
            obj.pmtControllerActualValues = mdfData.pmtDevAddresses;
            nums = cellfun(@(x)~ischar(x),obj.pmtControllerActualValues);
            obj.pmtControllerActualValues(nums) = cellfun(@(x){num2str(x)},obj.pmtControllerActualValues(nums));
            
            dat = cellfun(@(v){v obj.delChar}, obj.pmtControllerActualValues,'UniformOutput',false);           
            dat = vertcat(dat{:});
            
            sz = size(obj.pmtControllerActualValues, 2);
            
            for dx = 0:(sz-1)
                if isempty(strtrim(obj.pmtControllerActualValues{(sz-dx)}))
                    dat((sz-dx),:) = [];
                end
            end
            
            % make sure there is a blank row
            rows = size(dat,1);
            
            if rows < 1
                dat = {'' obj.delChar};
            else
                if ~isempty(dat{end,2}) && (rows < 4)
                    dat(end+1,:) = {'' obj.delChar};
                end
            end
            
            obj.hPmtControllerTable.Data = dat;
            
            if isfield(mdfData, 'galvoGalvoMirrorInvert')
                obj.hGalvoGalvoMirrorInvertCheckBox.Value = mdfData.galvoGalvoMirrorInvert;
            else
                obj.hGalvoGalvoMirrorInvertCheckBox.Value = false;
            end
            
            if isfield(mdfData, 'galvoResonantMirrorInvert')
                obj.hGalvoResonantMirrorInvertCheckBox.Value = mdfData.galvoResonantMirrorInvert;
            else
                obj.hGalvoResonantMirrorInvertCheckBox.Value = false;
            end
            
            if isfield(mdfData, 'flipperMirrorInvert')
                obj.hFlipperMirrorInvertCheckBox.Value = mdfData.flipperMirrorInvert;
            else
                obj.hFlipperMirrorInvertCheckBox.Value = false;
            end
        
            % Scanner Name
            strDx=find(ismember(obj.hScannerNamePopUp.String,mdfData.scannerName));            
            
            if isempty(strDx)
                obj.hScannerNamePopUp.Value = 1;
            else
                obj.hScannerNamePopUp.Value = strDx;
            end
            
            % ECU2 Com Port
            obj.setComPopup(obj.hECU2ComPortPopUp,mdfData.ecuComPort);
                        
            % Galvo-Galvo Com Port
            obj.setComPopup(obj.hGalvoGalvoMirrorComPortPopUp,mdfData.galvoGalvoMirrorComPort);

            % Galvo-Resonant Com Port
            obj.setComPopup(obj.hGalvoResonantMirrorComPortPopUp,mdfData.galvoResonantMirrorComPort);

            % Flipper Com Port
            obj.setComPopup(obj.hFlipperMirrorComPortPopUp,mdfData.flipperMirrorComPort);
            
        end % function - reload
        
        function setComPopup(obj,hCtl,comPrt)
            hCtl.String = obj.menuItemsComPorts;
            
            if isempty(comPrt)
                hCtl.Value = 1;
            else
                cm = sprintf('COM%d', comPrt);
                [tf,strDx] = ismember(cm,obj.menuItemsComPorts);
                
                if tf
                    hCtl.Value = strDx;
                else
                    hCtl.String = [obj.menuItemsComPorts {cm}];
                    hCtl.Value = numel(obj.menuItemsComPorts) + 1;
                end
            end
        end
        
        function s = getNewVarStruct(obj)

            selectedItemScannerNames = get(obj.hScannerNamePopUp, 'String');

            scannerNameValue = strtrim(selectedItemScannerNames{obj.hScannerNamePopUp.Value});
            
            if strcmp(scannerNameValue, 'None')
                scannerNameValue = '';
            end
            
            s = struct('scannerName',scannerNameValue, ...
                'ecuComPort', obj.getComPortValue(obj.hECU2ComPortPopUp), ...
                'galvoGalvoMirrorComPort', obj.getComPortValue(obj.hGalvoGalvoMirrorComPortPopUp), ...
                'galvoResonantMirrorComPort', obj.getComPortValue(obj.hGalvoResonantMirrorComPortPopUp), ...
                'flipperMirrorComPort', obj.getComPortValue(obj.hFlipperMirrorComPortPopUp));

            dat = cellfun(@strtrim,obj.hPmtControllerTable.Data(:,1)','uniformoutput',false);
            nums = cellfun(@(x)~isempty(x)&&(length(x)<10)&&all(isstrprop(x, 'digit')),dat);
            dat(nums) = cellfun(@str2double, dat(nums), 'uniformoutput',false);
            
            while numel(dat) < 4
                dat{end+1} = '';
            end
            
            s.pmtDevAddresses = dat;
            s.galvoGalvoMirrorInvert = logical(obj.hGalvoGalvoMirrorInvertCheckBox.Value);
            s.galvoResonantMirrorInvert = logical(obj.hGalvoResonantMirrorInvertCheckBox.Value);
            s.flipperMirrorInvert = logical(obj.hFlipperMirrorInvertCheckBox.Value);
            
        end % function - getNewVarStruct
        
        function comPortValue = getComPortValue(~, hComPortObj)

            selectedItemComPorts = get(hComPortObj, 'String');
            
            comPortValue = strtrim(selectedItemComPorts{hComPortObj.Value});
            comPortValue = str2double(comPortValue(4:end));
            
            if isempty(comPortValue) || isnan(comPortValue)
                comPortValue = [];
            end
            
        end % function - getComPortValue
        
        function v = get.numPMTControllers(obj)
            
            v = size(obj.hPmtControllerTable.Data, 1) - 1;
        
        end % function - get.numPMTControllers

        function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
        end
        
        function cellEditFcn(obj,varargin)
            
            dat = obj.hPmtControllerTable.Data;
            
            % make sure there is a blank row
            rows = size(dat,1);
            
            if rows < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || (rows < 4 && ~isempty(strtrim(lr{1})))
                dat(end+1,:) = {'' obj.delChar};
            end
            
            obj.hPmtControllerTable.Data = dat;
        
        end % function - cellEditFcn
        
        function cellSelectFcn(obj, varargin)
            if ~isempty(varargin{2}.Indices)
                if varargin{2}.Indices(2) == obj.pmtTableDeleteField
                    
                    if ~obj.keyDown
                        dat = obj.hPmtControllerTable.Data;
                        dat(varargin{2}.Indices(1),:) = [];
                        obj.hPmtControllerTable.Data = dat;                
                    end % if - not keyDown
                    
                    obj.cellEditFcn(varargin);
                    
                end % if - delete field
                
            end % if - not empty
            
        end % function - cellSelectFcn
        
    end % methods
    
end % classdef - ThorLabsBScope2Page


%--------------------------------------------------------------------------%
% ThorLabsBScope2Page.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
