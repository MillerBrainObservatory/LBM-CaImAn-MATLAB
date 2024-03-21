classdef PhotostimPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hPhotoStimulationScannerText;
        hPhotoStimulationScannerPopUp;
        hScannerErrorText;
        hSubPanel;
        hAnalogInputChannelText;
        hAnalogInputChannelPopUp;
        hLoggingStartTriggerText;
        hLoggingStartTriggerPopUp;
        
        holdLastSelectedScanner = -1;
    end
    
    properties (Constant)
        defaultPagePath = '+scanimage\+components\private\Photostim_model.m';
    end

    methods
        function obj = PhotostimPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'Photostimulation';
            obj.heading =  'Photostim';
            obj.descriptionText = 'Select a Linear Scanner to use for photostimulation. Configure a channel for beam power feedback and a start trigger where the frame clock is wired to synchronize logging with imaging.';
            
            ph = 235;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 982 ph]); 

            % PhotoStimulationScannerText
            obj.hPhotoStimulationScannerText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'PhotoStimulationScannerText', ...
                'Style', 'text', ...
                'String', 'Photostimulation Scanner', ...
                'TooltipString', 'Name of scanner (listed in the ScanImage Main section) to use for photostimulation. Must be a linear scanner.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 135 14]);
        
            % PhotoStimulationScannerPopUp
            obj.hPhotoStimulationScannerPopUp = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'PhotoStimulationScannerPopUp', ...
                'Style', 'popupmenu', ...
                'String', cat(2, 'None', obj.hConfigEditor.scannerNames()'), ...
                'TooltipString', 'Name of scanner (listed in the ScanImage Main section) to use for photostimulation. Must be a linear scanner.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [246 ph-44 150 20], ...
                'Callback', @obj.cellEditFcn);

            % ScannerErrorText
            obj.hScannerErrorText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ScannerErrorText', ...
                'Style', 'text', ...
                'String', '*No linear scanning systems have been configured. Please see the "Scanning Systems Table" in the "General ScanImage Settings" section.', ...
                'HorizontalAlignment', 'left', ...
                'ForegroundColor', [1.0 0.0 0.0], ...
                'Visible', 'off', ...
                'Units', 'pixels', ...
                'Position', [426 ph-56 350 33]);
        
            % Sub-Panel
            sph = 141;
            obj.hSubPanel = uipanel( ...
                'parent', obj.hPanel, ...
                'Tag', 'SubPanel', ...
                'Title', '', ...    
                'Units', 'pixels', ...
                'Position', [46 ph-218 315 sph]);
            
            % AnalogInputChannelText
            obj.hAnalogInputChannelText = uicontrol(...
                'parent', obj.hSubPanel, ...
                'Tag', 'AnalogInputChannelText', ...
                'Style', 'text', ...
                'String', 'Beam Power Feedback AI Channel', ...
                'TooltipString', 'This is used for monitoring the Pockels cell Output.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [24 sph-53 170 14]);
        
            % AnalogInputChannelPopUp
            obj.hAnalogInputChannelPopUp = uicontrol(...
                'parent', obj.hSubPanel, ...
                'Tag', 'AnalogInputChannelPopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'TooltipString', 'This is used for monitoring the Pockels cell Output.', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'Position', [221 sph-56 60 20]);
                
            % LoggingStartTriggerText
            obj.hLoggingStartTriggerText = uicontrol(...
                'parent', obj.hSubPanel, ...
                'Tag', 'LoggingStartTriggerText', ...
                'Style', 'text', ...
                'String', 'Logging Start Trigger Terminal', ...
                'TooltipString', 'One of {PFI#} to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [24 sph-99 160 14]);
        
            % LoggingStartTriggerPopUp
            obj.hLoggingStartTriggerPopUp = uicontrol(...
                'parent', obj.hSubPanel, ...
                'Tag', 'LoggingStartTriggerPopUp', ...
                'Style', 'popupmenu', ...
                'String', ' ', ...
                'TooltipString', 'One of {PFI#} to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus.', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'Position', [221 sph-102 60 20]);
                
            obj.reload();
        end % Constructor - PhotostimPage
        
        function delete(obj)
        end % delete
        
        function applySmartDefaultSettings(obj)
            % change settings to appropriate default values
            s = struct();
            obj.applyVarStruct(s);
            obj.reload();
        end

        function refreshPageDependentOptions(obj, mdfData)
            if nargin < 2 || isempty(mdfData)
                selectedItemScannerNames = get(obj.hPhotoStimulationScannerPopUp, 'String');
                scannerName = selectedItemScannerNames{obj.hPhotoStimulationScannerPopUp.Value};
                if strcmp(scannerName, 'None')
                    scannerName = '';
                end
                mdfData = [];
            else
                if isfield(mdfData, 'photostimScannerName')
                    scannerName = mdfData.photostimScannerName;
                else
                    scannerName = '';
                end
            end
            
            scannerNames = obj.hConfigEditor.scannerNames()';
            scannerNames(cellfun(@(x)(~strcmp(x,'Linear'))&&(~strcmp(x,'SLM')),obj.hConfigEditor.scannerTypes)) = [];

            if ~isempty(scannerNames)
                obj.hPhotoStimulationScannerPopUp.String = cat(2, 'None', scannerNames);
            else
                obj.hPhotoStimulationScannerPopUp.String = {'None'};
            end
            
            if ~isempty(scannerName)
                [tf,idx] = ismember(scannerName,scannerNames);
                if tf
                    obj.hPhotoStimulationScannerPopUp.Value = idx+1;
                else
                    obj.hPhotoStimulationScannerPopUp.Value = 1;
                end
            else
                obj.hPhotoStimulationScannerPopUp.Value = 1;
            end
            
            obj.updateSubPanel(mdfData);
        end % function - refreshPageDependentOptions

        function reload(obj)
            obj.refreshPageDependentOptions(obj.getCurrentMdfDataStruct());
        end % function - reload

        function updateSubPanel(obj, mdfData)
            
            if size(obj.hPhotoStimulationScannerPopUp.String, 1) < 2
                obj.hScannerErrorText.Visible = 'on';
                obj.hSubPanel.Title = '';
                obj.hAnalogInputChannelText.Enable = 'off';
                obj.hAnalogInputChannelPopUp.Enable = 'off';
                obj.hLoggingStartTriggerText.Enable = 'off';
                obj.hLoggingStartTriggerPopUp.Enable = 'off';   
                obj.hAnalogInputChannelPopUp.Value = 1;
                obj.hAnalogInputChannelPopUp.String = {' '};
                obj.hLoggingStartTriggerPopUp.Value = 1;
                obj.hLoggingStartTriggerPopUp.String = {' '};
                return;
            else
                obj.hScannerErrorText.Visible = 'off';
            end
            
            scannerSelectionStr =obj.hPhotoStimulationScannerPopUp.String{obj.hPhotoStimulationScannerPopUp.Value};
            
            if ~isempty(scannerSelectionStr) && ~strcmpi(scannerSelectionStr, 'None')
                daqName = obj.hConfigEditor.getScannerGalvoFeedbackDaq(scannerSelectionStr);

                if ~isempty(daqName) && ~strcmpi(daqName, 'None')
                    % Analog Input Channel
                    %strDx=find(ismember(obj.hAnalogInputChannelPopUp.String,strcat('AI', num2str(mdfData.BeamAiId))));
                    if isempty(mdfData)
                        BeamAiId = obj.hAnalogInputChannelPopUp.Value;
                        loggingStartTrigger = obj.hLoggingStartTriggerPopUp.Value;
                    else
                        BeamAiId = mdfData.BeamAiId + 1;

                        if isfield(mdfData, 'loggingStartTrigger')
                            if isempty(mdfData.loggingStartTrigger)
                                loggingStartTrigger = 1;
                            else
                                loggingStartTrigger = str2double(mdfData.loggingStartTrigger(4:end))+2;
                            end
                        else
                            loggingStartTrigger = 1;
                        end
                    end

                    str = obj.getAnalogInputChannelList(daqName);
                    obj.hAnalogInputChannelPopUp.String = str;
                    obj.hAnalogInputChannelPopUp.Value = min(BeamAiId, numel(str));

                    str = obj.getLoggingStartTriggerList(daqName);
                    obj.hLoggingStartTriggerPopUp.String = str;
                    obj.hLoggingStartTriggerPopUp.Value = min(loggingStartTrigger, numel(str));

                    obj.hSubPanel.Title = daqName;
                    obj.hAnalogInputChannelText.Enable = 'on';
                    obj.hAnalogInputChannelPopUp.Enable = 'on';
                    obj.hLoggingStartTriggerText.Enable = 'on';
                    obj.hLoggingStartTriggerPopUp.Enable = 'on';                
                else
                    obj.hSubPanel.Title = '';
                    obj.hAnalogInputChannelText.Enable = 'off';
                    obj.hAnalogInputChannelPopUp.Enable = 'off';
                    obj.hLoggingStartTriggerText.Enable = 'off';
                    obj.hLoggingStartTriggerPopUp.Enable = 'off';   
                    obj.hAnalogInputChannelPopUp.Value = 1;
                    obj.hAnalogInputChannelPopUp.String = {' '};
                    obj.hLoggingStartTriggerPopUp.Value = 1;
                    obj.hLoggingStartTriggerPopUp.String = {' '};
                    obj.hScannerErrorText.Visible = 'on';
                    obj.hScannerErrorText.String = 'Warning: No Galvo Position Feedback DAQ has been selected on the LinScanner, Scanner Settings.'; 
                                
                end % daqName is empty or None

            else
                obj.hSubPanel.Title = '';
                obj.hAnalogInputChannelText.Enable = 'off';
                obj.hAnalogInputChannelPopUp.Enable = 'off';
                obj.hLoggingStartTriggerText.Enable = 'off';
                obj.hLoggingStartTriggerPopUp.Enable = 'off';   
                obj.hAnalogInputChannelPopUp.Value = 1;
                obj.hAnalogInputChannelPopUp.String = {' '};
                obj.hLoggingStartTriggerPopUp.Value = 1;
                obj.hLoggingStartTriggerPopUp.String = {' '};              
            end % scannerSelectionStr is empty or None
            
        end % function - updateSubPanel
        
        function s = getNewVarStruct(obj)
            
            selectedItemScannerNames = get(obj.hPhotoStimulationScannerPopUp, 'String');
            
            scannerName = selectedItemScannerNames{obj.hPhotoStimulationScannerPopUp.Value};
            if strcmp(scannerName, 'None')
                scannerName = '';
            end
            
            v = obj.hLoggingStartTriggerPopUp.Value;
            if v == 1
                loggingTrigger = '';
            else
                loggingTrigger = sprintf('PFI%d',v-2);
            end
            
            aiChan = obj.hAnalogInputChannelPopUp.Value - 1;
            
            s = struct('photostimScannerName', scannerName, 'BeamAiId', aiChan, 'loggingStartTrigger', loggingTrigger);
        end % function - getNewVarStruct

        function aiList = getAnalogInputChannelList(obj, daqName)
            
            [tf, idx] = ismember(daqName, obj.hConfigEditor.availableDaqs);
            
            if tf
                aiList = obj.hConfigEditor.daqInfo(idx).allAIs;
            else
                aiList = arrayfun(@(x)sprintf('AI%d',x),0:15,'uniformoutput',false);
            end
            
        end % function - getAnalogInputChannelList
        
        function triggerList = getLoggingStartTriggerList(obj, daqName)
            
            [tf, idx] = ismember(daqName, obj.hConfigEditor.availableDaqs);
            
            if tf
                triggerList = [{'None'} arrayfun(@(x)sprintf('PFI%d',x),0:(obj.hConfigEditor.daqInfo(idx).numPFIs - 1),'uniformoutput',false)];
            else
                triggerList = {'None'};
            end

        end % function - getLoggingStartTriggerList
        
    end % methods
    
    methods % callback methods
        
        function cellEditFcn(obj,varargin)
            
            mdfData = obj.getCurrentMdfDataStruct();
            
            if obj.holdLastSelectedScanner ~= obj.hPhotoStimulationScannerPopUp.Value
                obj.updateSubPanel(mdfData);

                obj.hAnalogInputChannelPopUp.Value = 1;
                obj.hLoggingStartTriggerPopUp.Value = 1;
                obj.holdLastSelectedScanner = obj.hPhotoStimulationScannerPopUp.Value;
            end
 
        end % function - cellEditFcn
        
    end % callback methods    
   
end % classdef - PhotostimPage


%--------------------------------------------------------------------------%
% PhotostimPage.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
