classdef IntegrationROIOutputsPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hROIOutputChannelText;
        hChannelTable;
        
        numROIOutputs = 0;
        roiTableDeleteField = 4;
        roiDaqNameField = 1;
        roiChannelIdField = 2;
        
        formatDeviceNames;
    end
    
    properties (Constant)
        defaultPagePath = '+scanimage\+components\private\IntegrationRoiManager_model.m';
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
    end

    properties
        keyDown = false;
    end
    
    methods
        function obj = IntegrationROIOutputsPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'Closed-Loop Experiment Outputs';
            obj.heading =  'IntegrationRoiOutputs';
            obj.descriptionText = 'Configure channels to enable signal outputs based on real-time image analysis. These outputs can facilitate closed loop experiments that respond to imaging data.';
            
            ph = 195;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0.0 952.0 ph]);  %'pixels','position',[0 0.0 982.0 730.0]);   
            
            % ROIOutputChannelText
            obj.hROIOutputChannelText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ROIOutputChannelText', ...
                'Style', 'text', ...
                'String', 'ROI Output Channels', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', '', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 105 14]);
        
            % ChannelTable
            obj.formatDeviceNames = cat(2, 'None', obj.hConfigEditor.availableDaqs([obj.hConfigEditor.daqInfo.isXSer])');
            formatChannels = cat(2, 'None', cat(2, obj.getAnalogOutputChannelList(), obj.hConfigEditor.allDigChans'));

            channelColumnNames      = {'Daq Name', 'Channel ID', 'Channel Name', 'Delete'};
            channelColumnFormats    = {obj.formatDeviceNames, formatChannels, 'char', 'char'};
            channelColumnEditable   = [true, true, true, false];
            channelColumnWidths     = {200, 100, 300, 50};
            channelBlankRow         = {'None' 'None' '' obj.delChar;};
            
            obj.hChannelTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'ChannelTable', ...
                'Data', channelBlankRow, ...
                'ColumnName', channelColumnNames, ...
                'ColumnFormat', channelColumnFormats, ...
                'ColumnEditable', channelColumnEditable, ...
                'ColumnWidth', channelColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'Position', [46 ph-179 652 127], ...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'CellEditCallback', @obj.cellEditFcn, ...
                'CellSelectionCallback', @obj.cellSelectFcn);
            
            obj.reload();
        
        end
        
        function delete(obj)
        end
        
        function reload(obj)            
            % reload settings from the file
            mdfData = obj.getCurrentMdfDataStruct();
            
            if isempty(mdfData) || ~numel(mdfData.deviceNames) || ~numel(mdfData.deviceChannels)
                dat = {'None', 'None', '', obj.delChar;};
            else
                emptyCells = cellfun(@isempty,mdfData.deviceNames);       
                mdfData.deviceNames(emptyCells) = {'None'};               

                emptyCells = cellfun(@isempty,mdfData.deviceChannels);       
                mdfData.deviceChannels(emptyCells) = {'None'};               
                
                numCells = cellfun(@isnumeric,mdfData.deviceChannels);
                mdfData.deviceChannels(numCells) = cellfun(@(x)sprintf('AO%d',x),mdfData.deviceChannels(numCells),'UniformOutput',false);          

                dat = cellfun(@(c1,c2,c3){c1 c2 c3 obj.delChar},mdfData.deviceNames,mdfData.deviceChannels,mdfData.channelNames,'UniformOutput',false);
                dat = vertcat(dat{:});
                dat(end+1,:) = {'None', 'None', '', obj.delChar;};
            end
            
            obj.hChannelTable.Data = dat;
        
        end % function - reload
        
        function s = getNewVarStruct(obj)
            dat = obj.hChannelTable.Data;
            dat(end,:) = [];
                          
            tmpData = strtrim({dat(:,1)'});
            daqNames = strrep(tmpData{:}, 'None', '');

            tmpData = strtrim({dat(:,2)'});
            channels = strrep(tmpData{:}, 'None', '');
            
            aos = cellfun(@(x)strncmp(x,'AO',2),channels);
            channels(aos) = cellfun(@(x)str2double(x(3:end)),channels(aos),'UniformOutput',false);

            s = struct('deviceNames', {daqNames}, 'deviceChannels', {channels}, 'channelNames', strtrim({dat(:,3)'}));
        
        end % function - getNewVarStruct
        
        function aoList = getAnalogOutputChannelList(obj)
            
            aoList = [];
            
            daqs = obj.hConfigEditor.availableDaqs([obj.hConfigEditor.daqInfo.isXSer])';
            
            for dx = 1:numel(daqs)
                
                [tf, idx] = ismember(daqs(dx), obj.hConfigEditor.availableDaqs);
                
                aos = obj.hConfigEditor.daqInfo(idx).allAOs;
                
                if isempty(aoList)
                    aoList = aos;
                else
                    setdiff(aos, aoList);
                    aoList = cat(2, aoList, setdiff(aos, aoList));
                end
                    
            end % for - daqs
                
        end % function - getAnalogOutputChannelList
        
    end % methods
    
    methods       
         function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
        end
        
        function cellEditFcn(obj,varargin)
            
            dat = obj.hChannelTable.Data;
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || ~isempty(strtrim(lr{3})) || ~strcmp(lr{1}, 'None') || ~strcmp(lr{2}, 'None')
                dat(end+1,:) = {'None', 'None', '', obj.delChar;};
            end
            
            obj.hChannelTable.Data = dat;
        
        end % function - cellEditFcn

        function cellSelectFcn(obj, varargin)
            if ~isempty(varargin{2}.Indices)
                if varargin{2}.Indices(2) == obj.roiTableDeleteField
                
                    if ~obj.keyDown
                        dat = obj.hChannelTable.Data;
                        dat(varargin{2}.Indices(1),:) = [];
                        obj.hChannelTable.Data = dat;                
                    end % if - not keyDown
                    
                    obj.cellEditFcn(varargin);
                
                end % if - delete field
                
            end % if - not isempty           
        end % function - cellSelectFcn
          
        function v = get.numROIOutputs(obj)
            
            v = size(obj.hChannelTable.Data, 1) - 1;
        
        end % function - get.numROIOutputs
        
    end % methods
        
end % classdef


%--------------------------------------------------------------------------%
% IntegrationROIOutputsPage.m                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
