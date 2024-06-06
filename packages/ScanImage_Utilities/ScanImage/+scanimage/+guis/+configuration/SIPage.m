classdef SIPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hObjectiveResolutionText;
        hObjectiveResolutionEdit;
        hScannerTable;
        hAddlComponentsTable;
        hSimulatedModeCheckBox;
        hCustStartupScrEdit;
        
        simulated;
        scannerNames;
        scannerTypes;
        hasThorECU;
        hasBScope2;
        hasPMTController;
        
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
        keyDown = false;
    end
    
    properties (SetObservable)
        customComponents = {};
        startupScript = '';
        
        knownComponents = {'Thorlabs ECU 1' 'Thorlabs B-Scope 2' 'Analog PMT Controller' 'Bruker Resonant Controller'};
        knownComponentMapping = {'dabs.thorlabs.ECU1' 'dabs.thorlabs.BScope2' 'dabs.generic.GenericPmtController' 'dabs.bruker.BrukerResonantControl'};
    end
    
    properties (Constant)
        modelClass = 'scanimage.SI';
    end
    
    methods
        function obj = SIPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'General ScanImage Settings';
            obj.heading = 'ScanImage';
            obj.descriptionText = ['List all scanning systems to control on this microscope. For each, specify whether it is a resonant (resonant-galvo scan mirror pair), linear (galvo-galvo scan mirror pair), or SLM system. '...
                'A custom startup script and plugins can also be specified.'];
            
            % create form layout
            ph = 520;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 400 ph]);
        
            % Scanner Table Text
             uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Scanning Systems', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 250 14]);
        
            % Scanner Table
            scannerColumnNames      = {'Scanner Type' 'Scanner Name' 'Delete'};
            scannerColumnFormats    = {{'Resonant' 'Linear' 'SLM'} 'char' 'char'};
            scannerColumnEditable   = [true true false];
            scannerColumnWidths     = {200 200 50};
            scannerBlankRow         = {'' '' obj.delChar};
            
            obj.hScannerTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'scannerTable', ...
                'Data', scannerBlankRow, ...
                'ColumnName', scannerColumnNames, ...
                'ColumnFormat', scannerColumnFormats, ...
                'ColumnEditable', scannerColumnEditable, ...
                'ColumnWidth', scannerColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'Position', [46 ph-169 472 120],...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'CellSelectionCallback',@obj.scannerTblCellSelFcn,...
                'CellEditCallback',@obj.scannerTblCellEditFcn);
            
            uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Additional Components and Plugins', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-220 265 14]);
            
            % Additional Components Table
            addlComponentsColumnNames      = {'Additional Component' 'Delete'};
            addlComponentsColumnFormats    = {[obj.knownComponents {'Custom...'}] 'char'};
            addlComponentsColumnEditable   = [true, false];
            addlComponentsColumnWidths     = {250 50};
            addlComponentsBlankRow         = {'' obj.delChar};
            
            obj.hAddlComponentsTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'addlComponentsTable', ...
                'Data', addlComponentsBlankRow, ...
                'ColumnName', addlComponentsColumnNames, ...
                'ColumnFormat', addlComponentsColumnFormats, ...
                'ColumnEditable', addlComponentsColumnEditable, ...
                'ColumnWidth', addlComponentsColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'Position', [46 ph-322 322 96],...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'CellSelectionCallback',@obj.compCellSelFcn,...
                'CellEditCallback',@obj.compCellEditFcn);
            
            uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Custom Startup Script', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-370 265 14]);
            
            obj.hCustStartupScrEdit = most.gui.uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'edit', ...
                'String', '', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [226 ph-374 200 22],...
                'Bindings',{obj 'startupScript' 'string'});
            
            uicontrol(...
                'parent', obj.hPanel, ...
                'String', 'Create/Edit', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'Position', [434 ph-374 80 22],...
                'callback',@obj.editScr);
            
            % SimulatedModeCheckBox
            obj.hSimulatedModeCheckBox = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'SimulatedModeCheckBox', ...
                'Style', 'checkbox', ...
                'String', 'Run in Simulated Mode', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-420 200 22]);
            
            uicontrol(...
                'parent', obj.hPanel, ...
                'Style', 'text', ...
                'String', 'Enter the conversion factor from scan mirror angles to scan size in units of microns per scan angle. This value can be calculated or measured later using a stage.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Fontsize',10,...
                'Position', [46 ph-485 600 32]);
            
            % ObjectiveResolutionText
            obj.hObjectiveResolutionText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ObjectiveResolutionText', ...
                'Style', 'text', ...
                'String', 'Scan Angle Resolution (um/deg)', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-510 265 14]);
        
            % ObjectiveResolutionEdit 
            obj.hObjectiveResolutionEdit = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'ObjectiveResolutionEdit', ...
                'Style', 'edit', ...
                'String', '15', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'Position', [226 ph-514 51 22]);
            
            obj.reload();
        end
        
        function delete(obj)
        end
        
        function applySmartDefaultSettings(obj)
            % pick a default daq for the shutter. If there is a PXI chassis
            % choose a daq in the chassis
            
            s.simulated = isempty(obj.hConfigEditor.availableDaqs) || all([obj.hConfigEditor.daqInfo.simulated]);
            
            if isempty(obj.hConfigEditor.availableRios)
                % didnt find an FPGA. lets change default to linear scanner
                s.scannerNames = {'LinScanner'};
                s.scannerTypes = {'Linear'};
            end
            
            if s.simulated || isempty(obj.hConfigEditor.availableRios)
                obj.applyVarStruct(s);
                obj.reload();
            end
        end
        
        function reload(obj)
            % reload settings from the file
            mdfData = obj.getCurrentMdfDataStruct();
            
            if ~isempty(mdfData)
                if isfield(mdfData, 'enableResonantScanning')
                    edit(obj.hConfigEditor.hMDF.fileName);
%                     resp = questdlg(['In order to use the configuration editor, your machine data file must be upgraded. This will cause some compatibility problems with old usr/cfg files and custom code. '...
%                         'See the scanimage documentation for details.'], 'Legacy MDF Upgrade', 'Upgrade and Continue', 'Cancel', 'Cancel');
                    error('The selected machine data file uses a legacy format and cannot be used with the configuration editor. <a href="matlab: edit(obj.hConfigEditor.hMDF.fileName);">Open the MDF as text file instead.</a>');
                end
                
                if numel(mdfData.scannerNames) && numel(mdfData.scannerTypes)
                    dat = cellfun(@(c1,c2){c1 c2 obj.delChar},mdfData.scannerTypes,mdfData.scannerNames,'UniformOutput',false);
                    dat = vertcat(dat{:});
                    dat(end+1,:) = {'' '' obj.delChar};
                else
                    dat = {'' '' obj.delChar};
                end
                
                obj.hScannerTable.Data = dat;
                
                if isfield(mdfData, 'objectiveResolution')
                    obj.hObjectiveResolutionEdit.String = mdfData.objectiveResolution;
                else
                    obj.hObjectiveResolutionEdit.String = '15';
                end
                
                if isfield(mdfData, 'startUpScript')
                    obj.startupScript = mdfData.startUpScript;
                else
                    obj.startupScript = '';
                end
                
                if numel(mdfData.components)
                    for i=1:numel(mdfData.components)
                        if isa(mdfData.components{i}, 'function_handle')
                            mdfData.components{i} = func2str(mdfData.components{i});
                        end
                        [tf, idx] = ismember(mdfData.components{i}, obj.knownComponentMapping);
                        if tf
                            mdfData.components{i} = obj.knownComponents{idx};
                        else
                            obj.customComponents{end+1} = mdfData.components{i};
                        end
                    end
                    obj.customComponents = unique(obj.customComponents);
                    obj.hAddlComponentsTable.ColumnFormat = {[obj.knownComponents obj.customComponents {'Custom...'}] 'char'};
                    
                    dat = cellfun(@(c1){c1 obj.delChar},mdfData.components,'UniformOutput',false);
                    dat = vertcat(dat{:});
                    dat(end+1,:) = {'' obj.delChar};
                    obj.hAddlComponentsTable.Data = dat;
                end
                
                obj.hSimulatedModeCheckBox.Value = mdfData.simulated;
            end
        end
        
        function s = getNewVarStruct(obj)
            comps = obj.hAddlComponentsTable.Data(1:end-1,1);
            [tf, idx] = ismember(comps, obj.knownComponents);
            idx(idx==0) = [];
            comps(tf) = obj.knownComponentMapping(idx);
            
            isFunc = cellfun(@(s)s(1)=='@',comps);
            comps(isFunc) = cellfun(@str2func,comps(isFunc),'UniformOutput',false);
            
            dat = obj.hScannerTable.Data;
            dat(end,:) = [];
            
            s = struct('scannerNames',{dat(:,2)'},'scannerTypes',{dat(:,1)'},'simulated', logical(obj.hSimulatedModeCheckBox.Value),'components',{comps'},...
                'objectiveResolution',str2double(obj.hObjectiveResolutionEdit.String), 'startUpScript', obj.startupScript);
        end
    end
    
    %% prop acces
    methods
        function set.startupScript(obj,v)
            if ~isempty(v) && ~isvarname(v)
                fprintf(2, 'Must be a valid MATLAB script name format.\n');
                v = matlab.lang.makeValidName(v);
            end
            obj.startupScript = v;
        end
        
        function v = get.simulated(obj)
            v = obj.hSimulatedModeCheckBox.Value;
        end
        
        function v = get.scannerNames(obj)
            v = obj.hScannerTable.Data(1:end-1,2);
        end
        
        function v = get.scannerTypes(obj)
            v = obj.hScannerTable.Data(1:end-1,1);
        end
        
        function v = get.hasThorECU(obj)
            v = ismember('Thorlabs ECU 1',obj.hAddlComponentsTable.Data(1:end-1,1));
        end
        
        function v = get.hasBScope2(obj)
            v = ismember('Thorlabs B-Scope 2',obj.hAddlComponentsTable.Data(1:end-1,1));
        end
        
        function v = get.hasPMTController(obj)
            v = ismember('Analog PMT Controller',obj.hAddlComponentsTable.Data(1:end-1,1));
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
        
        function scannerTblCellSelFcn(obj,~,evt)
            if size(evt.Indices,1) == 1 && evt.Indices(2) == 3
                if obj.keyDown
                    d = obj.hScannerTable.Data;
                    obj.hScannerTable.Data = {};
                    obj.hScannerTable.Data = d;
                    obj.keyDown = false;
                else
                    obj.hScannerTable.Data(evt.Indices(1),:) = [];
                end
                obj.scannerTblCellEditFcn();
            end
        end
        function scannerTblCellEditFcn(obj,varargin)
            dat = obj.hScannerTable.Data;
            
            % fix invalid names
            needFix = cellfun(@(x)~isempty(x)&&~isvarname(x),dat(:,2));
            dat(needFix,2) = matlab.lang.makeValidName(dat(needFix,2));
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || ~isempty(lr{1}) || ~isempty(lr{2})
                dat(end+1,:) = {'' '' obj.delChar};
            end
            
            obj.hScannerTable.Data = dat;
        end
        
        function compCellSelFcn(obj,~,evt)
            if size(evt.Indices,1) == 1 && evt.Indices(2) == 2
                if obj.keyDown
                    d = obj.hAddlComponentsTable.Data;
                    obj.hAddlComponentsTable.Data = {};
                    obj.hAddlComponentsTable.Data = d;
                    obj.keyDown = false;
                else
                    obj.hAddlComponentsTable.Data(evt.Indices(1),:) = [];
                end
                obj.compCellEditFcn();
            end
        end
        function compCellEditFcn(obj,varargin)
            dat = obj.hAddlComponentsTable.Data;
            
            % handle custom selection
            i = find(strcmp(dat(:,1),'Custom...'));
            if ~isempty(i)
                resp = inputdlg(['Enter a custom component. This can either be a class name (ex ''dabs.thorlabs.ECU1'') or an anonymous function. If it is a class, the constructor must'...
                    ' take the hSI model handle as a parameter. If it is an anonymous function, it must take the hSI model handle as a parameter and return an object handle.'],...
                    'Select Custom Component',1,{'@(hSI)myCustomComponentFunc(hSI)'});
                if isempty(resp)
                    dat(i,:) = [];
                else
                    dat(i,1) = resp;
                    obj.customComponents = unique([obj.customComponents resp]);
                    obj.hAddlComponentsTable.ColumnFormat = {[obj.knownComponents obj.customComponents {'Custom...'}] 'char'};
                end
            end
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            if isempty(lr) || ~isempty(lr{1})
                dat(end+1,:) = {'' obj.delChar};
            end
            
            obj.hAddlComponentsTable.Data = dat;
        end
        
        function editScr(obj,varargin)
            if isempty(obj.startupScript)
                resp = inputdlg('Enter the name of a matlab script on the current search path. If it does not exist it will be created in the current directory.','Select Script',1,{'myCustomScript'});
                if ~isempty(resp)
                    obj.startupScript = resp{1};
                    edit(obj.startupScript);
                end
            else
                edit(obj.startupScript);
            end
        end
    end
end


%--------------------------------------------------------------------------%
% SIPage.m                                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
