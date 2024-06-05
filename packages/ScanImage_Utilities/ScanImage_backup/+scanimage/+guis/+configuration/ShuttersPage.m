classdef ShuttersPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hShutterTableText;
        hShutterTable;
        hTimeDelayText;
        hTimeDelayEdit;
    end
    
    % props that the configuration editor wants to know
    properties
        numShutters = 0;
        shutterNames = {};
        
        lvlMap = containers.Map({true false}, {'High' 'Low'});
        revLvlMap = containers.Map({'High' 'Low' ''}, {true false true});
        
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
        keyDown = false;
    end
    
    properties (Constant)
        defaultPagePath = '+scanimage\+components\private\Shutters_model.m';
    end

    methods
        function obj = ShuttersPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'Shutter Configuration';
            obj.heading = 'Shutters';
            obj.descriptionText = ['Enter Shutter(s) used to prevent any beam exposure from reaching specimen during idle periods. '...
                'Multiple shutters can be specified and will be assigned IDs in the order entered below. '...
                'Later these IDs can be used to assign shutters to scanners.'];
            
            ph = 300;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 700 ph]);
        
            % ShutterTableText
            obj.hShutterTableText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ShutterTableText', ...
                'Style', 'text', ...
                'String', 'Shutter DAQ Devices and Channels', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 250 14]);
        
            % ShutterTable
            shutterColumnNames      = {'Shutter Name' 'DAQ Name', 'Channel ID', 'Shutter Open|Digital Level' 'Delete|Row'};
            shutterColumnFormats    = {'char' obj.hConfigEditor.availableDaqs' obj.hConfigEditor.allDigChans' {'High' 'Low'} 'char'};
            shutterColumnEditable   = [true, true, true, true, false];
            shutterColumnWidths     = {125 125 100 100 50};
            shutterBlankRow         = {'' '' '' '' obj.delChar};
            
            obj.hShutterTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'ShutterTable', ...
                'Data', shutterBlankRow, ...
                'ColumnName', shutterColumnNames, ...
                'ColumnFormat', shutterColumnFormats, ...
                'ColumnEditable', shutterColumnEditable, ...
                'ColumnWidth', shutterColumnWidths, ...
                'RowName', 'numbered', ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'Position', [46 ph-169 550 120],...
                'CellSelectionCallback',@obj.cellSelFcn,...
                'CellEditCallback',@obj.cellEditFcn);
            
            % TimeDelayText
            obj.hTimeDelayText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'TimeDelayText', ...
                'Style', 'text', ...
                'String', 'Shutter Transition Time (seconds)', ...
                'TooltipString', 'Time to delay following certain shutter open commands (e.g. between stack slices), allowing shutter to fully open before proceeding.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-230 200 15]);
        
            % TimeDelayEdit
            obj.hTimeDelayEdit = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'TimeDelayEdit', ...
                'Style', 'edit', ...
                'String', '0.1', ...
                'TooltipString', 'Time to delay following certain shutter open commands (e.g. between stack slices), allowing shutter to fully open before proceeding.', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'Position', [240 ph-233 51 22]);
        
            obj.reload();
        end
        
        function delete(obj)
        end
        
        function applySmartDefaultSettings(obj)
            % pick a default daq for the shutter. If there is a PXI chassis
            % choose a daq in the chassis
            if isempty(obj.hConfigEditor.availableDaqs)
                s.shutterDaqDevices = {};
                s.shutterChannelIDs = {};
                s.shutterNames = {};
            else
                [tf,idx] = ismember('PXI1Slot3', obj.hConfigEditor.availableDaqs);
                if ~tf
                    idx = find(~isnan([obj.hConfigEditor.daqInfo.pxiNum]),1);
                    if isempty(idx)
                        idx = 1;
                    end
                end
                
                pfinum = min(12, obj.hConfigEditor.daqInfo(idx).numPFIs);
                
                s.shutterDaqDevices = obj.hConfigEditor.availableDaqs(idx);
                s.shutterChannelIDs = {sprintf('PFI%d',pfinum)};
                s.shutterNames = {'Main Shutter'};
                s.shutterOpenLevel = 1;
            end
            obj.applyVarStruct(s);
            obj.reload();
        end
        
        function refreshPageDependentOptions(obj)
            obj.hShutterTable.ColumnFormat = {'char' obj.hConfigEditor.availableDaqs' obj.hConfigEditor.allDigChans' {'High' 'Low'} 'char'};
        end
        
        function reload(obj)
            % reload settings from the file
            mdfData = obj.getCurrentMdfDataStruct();
            
            if isempty(mdfData) || ~numel(mdfData.shutterDaqDevices) || ~numel(mdfData.shutterChannelIDs)
                dat = {'' '' '' '' obj.delChar};
            else
                if ~isfield(mdfData,'shutterNames')
                    mdfData.shutterNames = arrayfun(@(a)sprintf('Shutter %d',a),1:numel(mdfData.shutterDaqDevices)','UniformOutput',false);
                else
                    mdfData.shutterNames(numel(mdfData.shutterDaqDevices)+1:end) = [];
                    mdfData.shutterNames(end+1:numel(mdfData.shutterDaqDevices)) = arrayfun(@(a)sprintf('Shutter %d',a),(numel(mdfData.shutterNames)+1:numel(mdfData.shutterDaqDevices))','UniformOutput',false);
                end
                
                if numel(mdfData.shutterOpenLevel) ~= numel(mdfData.shutterDaqDevices)
                    lvls = repmat({logical(mdfData.shutterOpenLevel)},1,numel(mdfData.shutterDaqDevices));
                else
                    lvls = num2cell(logical(mdfData.shutterOpenLevel));
                end
                dat = cellfun(@(c1,c2,c3,c4){c1 c2 c3 obj.lvlMap(c4) obj.delChar},mdfData.shutterNames,mdfData.shutterDaqDevices,mdfData.shutterChannelIDs,lvls,'UniformOutput',false);
                dat = vertcat(dat{:});
                dat(end+1,:) = {'' '' '' '' obj.delChar};
            end
            
            obj.hShutterTable.Data = dat;
        end
        
        function s = getNewVarStruct(obj)
            dat = obj.hShutterTable.Data;
            dat(end,:) = [];
            
            s = struct('shutterNames', {dat(:,1)'}, 'shutterDaqDevices', {dat(:,2)'}, 'shutterChannelIDs',{dat(:,3)'}, 'shutterOpenLevel', cellfun(@(x)obj.revLvlMap(x),dat(:,4)'), 'shutterOpenTime', str2double(obj.hTimeDelayEdit.String));
            if isempty(s.shutterOpenLevel)
                s.shutterOpenLevel = 1;
            end
        end
    end
    
    methods
        function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
        end
        
        function cellSelFcn(obj,~,evt)
            if size(evt.Indices,1) == 1 && evt.Indices(2) == 5
                if obj.keyDown
                    d = obj.hShutterTable.Data;
                    obj.hShutterTable.Data = {};
                    obj.hShutterTable.Data = d;
                    obj.keyDown = false;
                else
                    obj.hShutterTable.Data(evt.Indices(1),:) = [];
                end
                obj.cellEditFcn();
            end
        end
        function cellEditFcn(obj,varargin)
            dat = obj.hShutterTable.Data;
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || ~isempty(lr{1}) || ~isempty(lr{2}) || ~isempty(lr{3})
                dat(end+1,:) = {'' '' '' '' obj.delChar};
            end
            
            obj.hShutterTable.Data = dat;
        end
        
        function v = get.numShutters(obj)
            v = size(obj.hShutterTable.Data,1) - 1;
        end
        
        function v = get.shutterNames(obj)
            dat = obj.hShutterTable.Data;
            dat(end,:) = [];
            v = cellfun(@(a,b,c)sprintf('%s (%s - %s)',a,b,c),dat(:,1),dat(:,2),dat(:,3),'UniformOutput',false);
        end
    end
end


%--------------------------------------------------------------------------%
% ShuttersPage.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
