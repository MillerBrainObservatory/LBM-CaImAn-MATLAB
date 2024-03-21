classdef PMTControllersPage < scanimage.guis.configuration.ConfigurationPage
    
    properties (SetObservable)
        hPMTControllersText;
        hPMTControllersTable;
        
        numPMTControllers = 0;
        pmtTableDeleteField = 10;
        celldata;
        boolContextMenuSet = false;
    end
    
    properties (Constant)
        defaultPagePath = '+dabs\+generic\private\GenericPmtController_model.m';
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
    end

    properties
        keyDown = false;
    end

    methods
        function obj = PMTControllersPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'PMT Controllers';
            obj.heading = 'GenericPmtController';
            obj.descriptionText = 'Configure DAQ channels for communicating with remote controllable PMT amplifier/power supply devices.';
             
            charUnitHeightAdjust = 15.77;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 982 525]);   

             % PMTControllersTableText
            obj.hPMTControllersText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'PMTControllersTableText', ...
                'Style', 'text', ...
                'String', 'PMT Controller(s)', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'characters', ...
                'Position', [9.0 51.39-charUnitHeightAdjust 17.4 1.08]);
        
            % PMTControllersTable
            digitalChannelsList = cat(2, 'None', obj.hConfigEditor.allDigChans');
            formatDeviceNames = obj.hConfigEditor.availableDaqs';
            formatPowerDOChannels = digitalChannelsList; 
            formatTrippedDIChannels = digitalChannelsList;
            formatTripResetDOChannls = digitalChannelsList;
            
            N = max([obj.hConfigEditor.daqInfo.numAOs]);
            formatGainAOChannels = [{'None'} arrayfun(@(i){sprintf('AO%02d',i)},0:N-1)];
            
            pmtControllersColumnNames      = {'PMT Name', 'DAQ Name', 'Gain AO|Channel', 'Power DO|Channel', 'Tripped DI|Channel', 'Trip Reset|DO Channel', 'Min Control|Voltage', 'Max Control|Voltage', 'Max|Gain', 'Delete'};
            pmtControllersColumnFormats    = {'char', formatDeviceNames, formatGainAOChannels, formatPowerDOChannels, formatTrippedDIChannels, formatTripResetDOChannls, 'numeric', 'numeric', 'numeric', 'char'};
            pmtControllersColumnEditable   = [true, true, true, true, true, true, true, true, true, false];
            pmtControllersColumnWidths     = {100, 100, 60, 90, 90, 90, 90, 90, 50, 50};
            
            obj.celldata = {'', ...
                        ' ', ...
                        'None', ...
                        'None', ...
                        'None', ...
                        'None', ...
                        [], ...
                        [], ...
                        [], ...
                        obj.delChar};

            obj.hPMTControllersTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'PMTControllersTable', ...
                'Data', obj.celldata, ...   
                'ColumnName', pmtControllersColumnNames, ...
                'ColumnFormat', pmtControllersColumnFormats, ...
                'ColumnEditable', pmtControllersColumnEditable, ...
                'ColumnWidth', pmtControllersColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...  
                'Units', 'characters', ...
                'Position', [9.0 36.01-charUnitHeightAdjust 162.4000 14.69], ...  
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'CellEditCallback', @obj.cellEditFcn, ...
                'CellSelectionCallback', @obj.cellSelectFcn);
                   
%            addlistener(obj.hPanel, 'Parent', 'PostSet', @obj.myCallbackFcn);

            obj.reload();
        
        end % Constructor - PMTControllersPage
        
        function outHtml = colText(obj, inText, inColor)
           outHtml = strcat(['<html><body style="text-align:center" bgcolor="' inColor '"  >'], inText); 
%            outHtml = strcat('<html><body style="text-align:center" >', inText); 
%outHtml = strcat(['<html><body style="text-align:center bgcolor="' inColor '"  >'], inText);
%            outHtml = strcat(outHtml, '</body></html>');
        end

        function outHtml = colLogical(obj, inColor)
            outHtml = true;
            
            %outHtml = ['<html><table bgcolor=red><TR><TD>','true','</TD></TR> </table></html>'];
        end

        function delete(obj)
        end % function - delete
        
        function applySmartDefaultSettings(obj)
            % change settings to appropriate default values
            s = struct();
            obj.applyVarStruct(s);
            obj.reload();
        end
        
        function reload(obj)
            
            % reload settings from the file
            mdfData = obj.getCurrentMdfDataStruct();
            
            if isempty(mdfData) || ~numel(mdfData.pmtDaqDeviceName) || ~numel(mdfData.pmtDaqPowerDOChannels)|| ~numel(mdfData.pmtDaqTrippedDIChannels)|| ~numel(mdfData.pmtDaqTripResetDOChannels)
                dat = obj.celldata;   
            else                                    
                numberPmts = numel(mdfData.pmtNames);   
                delValues = repmat({obj.colLogical('red')}, 1,numberPmts);   
                maxVoltages = [];
                minVoltages = [];    
                gainValues = [];
                gainAOChannels = {};
                    
                gainCells = num2cell(mdfData.pmtMaxGainValue);
                
                for dx = 1:numberPmts
                    voltageRange = mdfData.pmtDaqAOVoltageRange{1,dx};
                    gain = gainCells(1, dx);
                    gainChannel = mdfData.pmtDaqGainAOChannels(1, dx);
                    
                    if (~isempty(gain))
                        gainValues = cat(2, gainValues, gain);
                    else
                        gainValues = cat(2, gainValues, NaN);
                    end
                    
                    if (~isempty(gainChannel))
                        gainAOChannels = cat(2, gainAOChannels, obj.convertAOPortValue2Str(gainChannel));
                    else
                        gainAOChannels = cat(2, gainAOChannels, 'None');
                    end
                    
                    if (~isempty(voltageRange))
                        minVoltages = cat(2, minVoltages, voltageRange(2));
                        maxVoltages = cat(2, maxVoltages, voltageRange(1)); 
                    else
                        minVoltages = cat(2, minVoltages, NaN);
                        maxVoltages = cat(2, maxVoltages, NaN); 
                    end
                end
                                 
                minVoltagesArray = num2cell(minVoltages,1);
                minVoltagesArray(cellfun(@isnan,minVoltagesArray))={NaN}; 
                maxVoltagesArray = num2cell(maxVoltages,1);
                maxVoltagesArray(cellfun(@isnan,maxVoltagesArray))={NaN}; 
                pmtMaxGainValueArray = num2cell(mdfData.pmtMaxGainValue, 1);
                pmtMaxGainValueArray(cellfun(@isnan,pmtMaxGainValueArray))={NaN}; 
                                   
                emptyCells = cellfun(@isempty,mdfData.pmtDaqPowerDOChannels);       
                mdfData.pmtDaqPowerDOChannels(emptyCells) = {'None'};               

                emptyCells = cellfun(@isempty,mdfData.pmtDaqTrippedDIChannels);       
                mdfData.pmtDaqTrippedDIChannels(emptyCells) = {'None'};               

                emptyCells = cellfun(@isempty,mdfData.pmtDaqTripResetDOChannels);       
                mdfData.pmtDaqTripResetDOChannels(emptyCells) = {'None'};               

                dat = cellfun(@(c1,c2,c3,c4,c5,c6,c7,c8,c9) ...
                    {c1 c2 c3 c4 c5 c6 c7 c8 c9 obj.delChar}, ...
                    mdfData.pmtNames, ...
                    mdfData.pmtDaqDeviceName, ...
                    gainAOChannels, ...
                    mdfData.pmtDaqPowerDOChannels, ...
                    mdfData.pmtDaqTrippedDIChannels, ...
                    mdfData.pmtDaqTripResetDOChannels, ...
                    maxVoltagesArray, ...
                    minVoltagesArray, ...
                    pmtMaxGainValueArray, ...
                    'UniformOutput',false);
                
                dat = vertcat(dat{:});
                dat(end+1,:) = obj.celldata;   

            end
            
            obj.hPMTControllersTable.Data = dat;
        
        end % function - reload
        
        function s = getNewVarStruct(obj)
            dat = obj.hPMTControllersTable.Data;
            dat(end,:) = [];
            
            v = dat(:,7);
            if ~isempty(v)
                v(cellfun(@isempty,v))={NaN}; 
            else
                v = {NaN};
            end
            voltageRangeMin = cell2mat(v);
            
            v = dat(:,8);
            if ~isempty(v)
                v(cellfun(@isempty,v))={NaN}; 
            else
                v = {NaN};
            end
            voltageRangeMax = cell2mat(v);

            voltageRange = cat(2,voltageRangeMin,voltageRangeMax);
            
            vrCell = mat2cell(voltageRange, ones(1, size(voltageRange,1)),2)';
            
            tmpChannels = strtrim({dat(:,3)'});
            
            tmpChannels = tmpChannels{:};
            
            gainAOChannels = [];
            
            if ~isempty(tmpChannels)    
                for dx = 1:size(tmpChannels, 2)
                     gainAOChannels = cat(2, gainAOChannels, obj.convertAOPortStr2Value(tmpChannels(dx)));
                end
            end
                        
            v = dat(:,9)';
            v(cellfun(@isempty,v))={NaN}; 
            maxGainValues = cell2mat(v);

            tmpChannels = strtrim({dat(:,4)'});
            powerDOChannels = strrep(tmpChannels{:}, 'None', '');
            
            tmpChannels = strtrim({dat(:,5)'});
            trippedDIChannels = strrep(tmpChannels{:}, 'None', '');
            
            tmpChannels = strtrim({dat(:,6)'});
            tripResetDOChannels = strrep(tmpChannels{:}, 'None', '');
            
            s = struct(...
                'pmtNames', strtrim({dat(:,1)'}), ...
                'pmtDaqDeviceName', strtrim({dat(:,2)'}), ...
                'pmtDaqGainAOChannels', gainAOChannels, ...
                'pmtDaqPowerDOChannels', {powerDOChannels}, ...
                'pmtDaqTrippedDIChannels', {trippedDIChannels}, ... 
                'pmtDaqTripResetDOChannels', {tripResetDOChannels}, ...
                'pmtDaqAOVoltageRange', {vrCell}, ...
                'pmtMaxGainValue', maxGainValues);
            
        end % function - getNewVarStruct

        function aoPortValue = convertAOPortStr2Value(obj, aoPortStr)

            aoPortValue = NaN;
            
            if ~isempty(strtrim(aoPortStr)) && ~isempty(strtrim(aoPortStr{1}))&& ~strcmp(aoPortStr, 'None')
                tmpAOPortValue = strtrim(aoPortStr);
                tmpAODx = strfind(tmpAOPortValue, 'AO');
                
                if ~isempty(tmpAODx)
                    tmpAOPortValue = strrep(tmpAOPortValue, 'AO', '');

                    if ~isempty(tmpAOPortValue)
                        aoPortValue = str2num(tmpAOPortValue{1});
                    end

                end
                
            end % if 
            
        end % function - convertAOPortStr2Value
        
        function aoPortStr = convertAOPortValue2Str(obj, aoPortValue)

            aoPortStr = 'None';
            
            if ~isempty(aoPortValue) && ~isnan(aoPortValue) && ~isinf(aoPortValue)
                
                aoPortStr = strcat('AO', num2str(aoPortValue));

            end % if 
            
        end % function - convertAOPortValue2Str
        
    end % methods
    
    methods % callback methods

        function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
        end
                
        function myCallbackFcn(obj,varargin)           
            if ~obj.boolContextMenuSet
                p = obj.hPanel;

               while ~isa(p, 'matlab.ui.Figure')
                    p = p.Parent;
               end

               cMenu = uicontextmenu(p);
               uimenu(cMenu, 'Label', 'Delete');

               set(obj.hPMTControllersTable, 'UIContextMenu', cMenu);

               obj.boolContextMenuSet = true;
            end
        end
            
        function cellEditFcn(obj,varargin)
            
            dat = obj.hPMTControllersTable.Data;
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || ~isempty(strtrim(lr{1})) || ~isempty(strtrim(lr{2})) || ~strcmp(lr{3}, 'None') || ~strcmp(lr{4}, 'None') || ~strcmp(lr{5}, 'None') || ~strcmp(lr{6}, 'None')
                dat(end+1,:) = obj.celldata;     
            end
            
            obj.hPMTControllersTable.Data = dat;
        
        end % function - cellEditFcn
        
        function cellSelectFcn(obj, varargin)
            if ~isempty(varargin{2}.Indices)
                if varargin{2}.Indices(2) == obj.pmtTableDeleteField
                    
                    if ~obj.keyDown
                        dat = obj.hPMTControllersTable.Data;
                        dat(varargin{2}.Indices(1),:) = [];
                        obj.hPMTControllersTable.Data = dat; 
                        obj.cellEditFcn(varargin);
                    end % if - not keyDown
                    
                end % if - delete field
                
            end % if - not empty
            
        end % function - cellSelectFcn
               
        function v = get.numPMTControllers(obj)
            
            v = size(obj.hPMTControllersTable.Data, 1) - 1;
        
        end % function - get.numPMTControllers
        
    end % callback methods
    
end % classdef - PMTControllersPage



%--------------------------------------------------------------------------%
% PMTControllersPage.m                                                     %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
