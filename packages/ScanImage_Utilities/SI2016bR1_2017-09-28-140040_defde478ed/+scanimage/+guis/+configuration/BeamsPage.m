classdef BeamsPage < scanimage.guis.configuration.ConfigurationPage
    
    properties
        hBeamDaqDevicesText;
        hBeamDaqDevicesList;
        hBeamDaqAddButton;
        hBeamDaqRemoveButton;
        hAvailableDaqDevicesText;
        hAvailableDaqDevicesList;
        hBeamDaqDevicePanel;
        hAutomaticRoutingText;
        hLineClockInText;
        hLineClockInPopUp;
        hFrameClockInText;
        hFrameClockInPopUp;
        hReferenceClockInText;
        hReferenceClockInPopUp;
        hChannelTable;
        hShutterTableText;
        hShutterTable;
        hNoSelText;
        
        beamDaqs;
        daqSettingList;
        currDaqSel = nan;
        beamDaqNames;
        
        scMap = containers.Map({true false}, {'Rejected Light' 'Transmitted Light'});
        revScMap = containers.Map({'Rejected Light' 'Transmitted Light' ''}, {true false false});
        
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
        keyDown = false;
    end
    
    properties (SetObservable)
        lineClockSel;
        frameClockSel;
        refClockSel;
    end
    
    properties (Constant)
        defaultPagePath = '+scanimage\+components\private\Beams_model.m';
    end
    
    methods
        function obj = BeamsPage(hConfigEditor, create)
            if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'Power Modulation (Beams)';
            obj.heading = 'Beams';
            obj.descriptionText = ['Configure DAQs for beam power modulation. Each scanner can be assigned one beam DAQ. Multiple scanners can be assigned the same beam DAQ, but cannot be used simultaneously in that case. '...
                'To add a beam DAQ, select the desired DAQ and click the ">>" button. Then configure one or more beam channels below.'];
            
            obj.minimumWidth = 500;
            ph = 740;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position', [0 0 obj.minimumWidth ph]);
              
            % BeamDaqDevicesText
            obj.hBeamDaqDevicesText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BeamDaqDevicesText', ...
                'Style', 'text', ...
                'String', 'Selected Beam DAQ Devices', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [283 ph-42 150 14]);
        
            % BeamDaqDevicesList 
            obj.hBeamDaqDevicesList = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BeamDaqDevicesList', ...
                'Style', 'listbox', ...
                'String', '', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString','Devices selected to be used. Configure properties for each below.',...
                'Units', 'pixels', ...
                'callback',@obj.daqListSel,...
                'Position', [283 ph-144 169 98]);
        
            % BeamDaqAddButton 
            obj.hBeamDaqAddButton = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BeamDaqAddButton', ...
                'Style', 'pushbutton', ...
                'String', '>>', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'callback', @obj.addBeamDaq,...
                'Position', [228 ph-89 39 22]);
        
            % BeamDaqRemoveButton 
            obj.hBeamDaqRemoveButton = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'BeamDaqRemoveButton', ...
                'Style', 'pushbutton', ...
                'String', '<<', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'callback', @obj.remBeamDaq,...
                'Position', [228 ph-129 39 22]);
        
            % AvailableDaqDevicesText
            obj.hAvailableDaqDevicesText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'AvailableDaqDevicesText', ...
                'Style', 'text', ...
                'String', 'Available DAQ Devices', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 114 14]);
        
            % AvailableDaqDevicesList 
            obj.hAvailableDaqDevicesList = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'AvailableDaqDevicesList', ...
                'Style', 'listbox', ...
                'String', '', ...
                'HorizontalAlignment', 'left', ...
                'TooltipString','Devices available to be selected. Only compatible X-Series DAQs are listed.',...
                'Units', 'pixels', ...
                'Position', [46 ph-144 169 98]);
        
            % BeamDaqDevicePanel 
            ddph = 535;
            ddpw = 780;
            obj.hBeamDaqDevicePanel = uipanel( ...
                'parent', obj.hPanel, ...
                'Tag', 'BeamDaqDevicePanel', ...
                'Title', '', ...    
                'Units', 'pixels', ...
                'Position', [46 ph-708 ddpw ddph]);
            
            uicontrol( ...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Style', 'text', ...
                'String', 'Configure a channel for each beam power modulation device (pockels cell, AOM, ect.) to be controlled by this beam DAQ. Note, the offset can be measured later.', ...  
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 ddph-72 676 32]);
            
            obj.hNoSelText = uicontrol( ...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Style', 'text', ...
                'String', 'Select a beam DAQ above in order to configure and add channels to it...', ...  
                'HorizontalAlignment', 'center', ...
                'FontSize',11,...
                'ForegroundColor',.5*ones(1,3),...
                'Units', 'pixels', ...
                'Position', [1 ddph-46 ddpw-2 30]);
        
            % Channel Table
            channelColumnNames      = {'Control|AO Channel', 'Display Name', 'Max Cmd|Voltage', 'Calibration|AI Channel', 'Calibration|Offset Voltage', 'Calibration|Signal Source' 'Delete'};
            channelColumnFormats    = {{' '}, 'char', 'numeric', {' '}, 'numeric', {'Transmitted Light' 'Rejected Light'}, 'char'};
            channelColumnEditable   = [true, true, true, true, true, true, false];
            channelColumnWidths     = {75, 200, 80, 75, 96, 106, 50};
            channelBlankRow         = {'' '' [] '' [] '' obj.delChar};
            
            obj.hChannelTable = uitable( ... 
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'channelTable', ...
                'Data', channelBlankRow, ...
                'ColumnName', channelColumnNames, ...
                'ColumnFormat', channelColumnFormats, ...
                'ColumnEditable', channelColumnEditable, ...
                'ColumnWidth', channelColumnWidths, ...
                'RowName', [], ...
                'Units', 'pixels', ...
                'RowStriping', 'Off', ...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'CellEditCallback',@obj.channelCellEditFcn,...
                'CellSelectionCallback',@obj.channelCellSelFcn,...
                'Position', [46 ddph-191 686 115]);
            
            % ShutterTableText
            obj.hShutterTableText = uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'ShutterTableText', ...
                'Style', 'text', ...
                'String', 'Select which shutters (if any) must be opened during the power modulation calibration of this beam DAQ.', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 ddph-240 700 20]);
        
            % ShutterTable
            shutterColumnNames      = {'Select', 'Shutter Device'};
            shutterColumnFormats    = {'logical', 'char'};
            shutterColumnEditable   = [true, false];
            shutterColumnWidths     = {50, 200};
            shutterBlankRow         = {false '';};
            
            obj.hShutterTable = uitable( ... 
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'ShutterTable', ...
                'Data', shutterBlankRow, ...
                'ColumnName', shutterColumnNames, ...
                'ColumnFormat', shutterColumnFormats, ...
                'ColumnEditable', shutterColumnEditable, ...
                'ColumnWidth', shutterColumnWidths, ...
                'RowName', [], ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'CellEditCallback',@obj.shutterCellEditFcn,...
                'Position', [46 ddph-342 274 100]);
            
            
            uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Style', 'text', ...
                'String', ['Trigger routing must be set manually for some hardware configurations. For resonant scanning, automatic routing can be used if beam DAQ is in the same PXI '...
                'chassis as the FPGA/digitizer. Otherwise, the line clock must be wired and configured below. For linear scanning, automatic routing works if the beam DAQ is in the '...
                'same PXI chassis as or connected via RTSI cable to the Auxilliary Clock Device. Otherwise both the frame clock and reference clock must be wired and configured below.'], ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'fontsize',10,...
                'Position', [46 ddph-447 690 80]);
            
            
            texttop = ddph-487;
            buttop = ddph-506;
            w = 160;
            h = 20;
            spc = 260;
            
            % LineClockInText
            obj.hLineClockInText = uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'LineClockInText', ...
                'Style', 'text', ...
                'String', 'Line Clock Input Terminal', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 texttop w h]);
            
            % LineClockInPopUp
            obj.hLineClockInPopUp = most.gui.uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'LineClockInPopUp', ...
                'Style', 'popupmenu', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings',{obj 'lineClockSel' 'choice'},...
                'Position', [46 buttop w h]);
        
            % FrameClockInText
            obj.hFrameClockInText = uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'FrameClockInText', ...
                'Style', 'text', ...
                'String', 'Frame Clock Input Terminal', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46+spc texttop w h]);
        
            % FrameClockInPopUp 
            obj.hFrameClockInPopUp = most.gui.uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'FrameClockInPopUp', ...
                'Style', 'popupmenu', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings',{obj 'frameClockSel' 'choice'},...
                'Position', [46+spc buttop w h]);
        
            % ReferenceClockInText
            obj.hReferenceClockInText = uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'ReferenceClockInText', ...
                'Style', 'text', ...
                'String', 'Reference Clock Input Terminal', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46+spc*2 texttop w h]);
        
            % ReferenceClockInPopUp 
            obj.hReferenceClockInPopUp = most.gui.uicontrol(...
                'parent', obj.hBeamDaqDevicePanel, ...
                'Tag', 'ReferenceClockInPopUp', ...
                'Style', 'popupmenu', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings',{obj 'refClockSel' 'choice'},...
                'Position', [46+spc*2 buttop w h]);
            
            obj.reload();
        end
        
        function refreshPageDependentOptions(obj)
            shutters = obj.hConfigEditor.shutterNames;
            shutters = [repmat({false},numel(shutters),1) shutters];
            obj.hShutterTable.Data = shutters;
            
            obj.updateDaqLists();
        end
        
        function delete(obj)
        end
        
        function reload(obj)
            obj.refreshPageDependentOptions();
            
            % reload settings from the file
            mdfData = obj.getCurrentMdfDataStruct();
            
            if isempty(mdfData)
                obj.beamDaqs = {};
                obj.updateDaqLists();
                obj.currDaqSel = [];
            else
                obj.beamDaqs = mdfData.beamDaqDevices;
                
                if ~isfield(mdfData, 'beamDaqs')
                    mdfData.beamDaqs = newDaqStruct();
                end
                
                obj.beamDaqs(numel(mdfData.beamDaqs)+1:end) = [];
                
                if ~isfield(mdfData.beamDaqs, 'referenceClockRate')
                    mdfData.beamDaqs = arrayfun(@(v)setfield(v,'referenceClockRate',10e6),mdfData.beamDaqs);
                end
                obj.daqSettingList = orderfields(mdfData.beamDaqs, newDaqStruct());
                
                obj.updateDaqLists();
                
                for i = 1:numel(obj.daqSettingList)
                    numChans = numel(obj.daqSettingList(i).chanIDs);
                    
                    nms = arrayfun(@(x)sprintf('Beam DAQ %d CH %d',i,x),1:numChans,'uniformoutput',false);
                    if isempty(obj.daqSettingList(i).displayNames) || numel(obj.daqSettingList(i).displayNames) ~= numChans
                        if isempty(nms)
                            obj.daqSettingList(i).displayNames = {};
                        else
                            obj.daqSettingList(i).displayNames = nms;
                        end
                    else
                        empts = cellfun(@isempty,obj.daqSettingList(i).displayNames);
                        obj.daqSettingList(i).displayNames(empts) = nms(empts);
                    end
                    
                    if numel(obj.daqSettingList(i).voltageRanges) ~= numChans
                        obj.daqSettingList(i).voltageRanges = repmat(obj.daqSettingList(i).voltageRanges(1),1,numChans);
                    end
                    
                    cicids  = obj.daqSettingList(i).calInputChanIDs;
                    if isempty(cicids)
                        c = nan(1,numChans);
                        if isempty(c)
                            obj.daqSettingList(i).calInputChanIDs = [];
                        else
                            obj.daqSettingList(i).calInputChanIDs = c;
                        end
                    elseif numel(cicids) ~= numChans
                        obj.daqSettingList(i).calInputChanIDs = repmat(cicids(1),1,numChans);
                    end
                    
                    if numel(obj.daqSettingList(i).calOffsets) ~= numChans
                        obj.daqSettingList(i).calOffsets(end+1:numChans) = 0;
                        obj.daqSettingList(i).calOffsets(numChans+1:end) = [];
                    end
                    
                    if numel(obj.daqSettingList(i).calUseRejectedLight) ~= numChans
                        obj.daqSettingList(i).calUseRejectedLight = repmat(obj.daqSettingList(i).calUseRejectedLight(1),1,numChans);
                    end
                end
                
                obj.currDaqSel = 1;
            end
        end
        
        function s = getNewVarStruct(obj)
            s.beamDaqDevices = obj.beamDaqs;
            s.beamDaqs = obj.daqSettingList;
        end
        
        function updateDaqLists(obj)
            obj.hAvailableDaqDevicesList.String = setdiff(obj.hConfigEditor.availableDaqs([obj.hConfigEditor.daqInfo.isXSer])',obj.beamDaqs);
            if numel(obj.beamDaqs)
                obj.hBeamDaqDevicesList.String = obj.beamDaqNames;
                obj.hBeamDaqRemoveButton.Enable = 'on';
                obj.daqSettingList(numel(obj.beamDaqs)+1:end) = [];
            else
                obj.hBeamDaqDevicesList.String = {};
                obj.daqSettingList = repmat(newDaqStruct(),1,0);
                obj.hBeamDaqRemoveButton.Enable = 'off';
            end
            
            N = numel(obj.hAvailableDaqDevicesList.String);
            if N
                obj.hBeamDaqAddButton.Enable = 'on';
                obj.hAvailableDaqDevicesList.Value = min(N,obj.hAvailableDaqDevicesList.Value);
            else
                obj.hBeamDaqAddButton.Enable = 'off';
            end
        end
    end
    
    %% ui callbacks
    methods
        function daqListSel(obj,varargin)
            obj.currDaqSel = obj.hBeamDaqDevicesList.Value;
        end
        
        function remBeamDaq(obj,varargin)
            if ~isnan(obj.currDaqSel)
                obj.beamDaqs(obj.currDaqSel) = [];
                obj.daqSettingList(obj.currDaqSel) = [];
                obj.updateDaqLists();
                obj.currDaqSel = obj.currDaqSel;
            end
        end
        
        function addBeamDaq(obj,varargin)
            daqToAdd = obj.hAvailableDaqDevicesList.String{obj.hAvailableDaqDevicesList.Value};
            obj.beamDaqs{end+1} = daqToAdd;
            i = numel(obj.beamDaqs);
            obj.daqSettingList(end+1) = newDaqStruct(i);
            obj.updateDaqLists();
            obj.currDaqSel = i;
        end
        
        function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
        end
        
        function channelCellSelFcn(obj,~,evt)
            if size(evt.Indices,1) == 1 && evt.Indices(2) == 7
                if obj.keyDown
                    d = obj.hChannelTable.Data;
                    obj.hChannelTable.Data = {};
                    obj.hChannelTable.Data = d;
                    obj.keyDown = false;
                else
                    ind = evt.Indices(1);
                    if ind <= numel(obj.daqSettingList(obj.currDaqSel).chanIDs)
                        if numel(obj.daqSettingList(obj.currDaqSel).chanIDs) == 1
                            obj.daqSettingList(obj.currDaqSel).chanIDs = [];
                            obj.daqSettingList(obj.currDaqSel).displayNames = {};
                            obj.daqSettingList(obj.currDaqSel).voltageRanges = [];
                            obj.daqSettingList(obj.currDaqSel).calInputChanIDs = [];
                            obj.daqSettingList(obj.currDaqSel).calOffsets = [];
                            obj.daqSettingList(obj.currDaqSel).calUseRejectedLight = [];
                        else
                            obj.daqSettingList(obj.currDaqSel).chanIDs(ind) = [];
                            obj.daqSettingList(obj.currDaqSel).displayNames(ind) = [];
                            obj.daqSettingList(obj.currDaqSel).voltageRanges(ind) = [];
                            obj.daqSettingList(obj.currDaqSel).calInputChanIDs(ind) = [];
                            obj.daqSettingList(obj.currDaqSel).calOffsets(ind) = [];
                            obj.daqSettingList(obj.currDaqSel).calUseRejectedLight(ind) = [];
                        end
                    end
                    obj.hChannelTable.Data(ind,:) = [];
                end
                obj.channelCellEditFcn([],evt);
            end
        end
        function channelCellEditFcn(obj,~,evt)
            dat = obj.hChannelTable.Data;
            
            % respond to changed data
            if evt.Indices(2) < 7
                i = evt.Indices(1);
                obj.daqSettingList(obj.currDaqSel).chanIDs(i) = str2double(dat{i,1}(3:end));
                
                if isempty(dat{i,2})
                    dat{i,2} = sprintf('Beam DAQ %d CH %d',obj.currDaqSel,i);
                end
                obj.daqSettingList(obj.currDaqSel).displayNames{i} = dat{i,2};
                
                vr = dat{i,3};
                if isempty(vr) || isnan(vr)
                    vr = 1.5;
                    dat{i,3} = vr;
                end
                obj.daqSettingList(obj.currDaqSel).voltageRanges(i) = vr;
                
                inCh = dat{i,4};
                if isempty(inCh)
                    inCh = 'None';
                    dat{i,4} = inCh;
                end
                if strcmp(inCh,'None')
                    inCh = nan;
                else
                    inCh = str2double(inCh(3:end));
                end
                obj.daqSettingList(obj.currDaqSel).calInputChanIDs(i) = inCh;
                
                ofst = dat{i,5};
                if isempty(ofst) || isnan(ofst)
                    ofst = 0;
                    dat{i,5} = ofst;
                end
                obj.daqSettingList(obj.currDaqSel).calOffsets(i) = ofst;
                
                calSc = obj.revScMap(dat{i,6});
                obj.daqSettingList(obj.currDaqSel).calUseRejectedLight(i) = calSc;
                dat{i,6} = obj.scMap(calSc);
            end
            
            % make sure there is a blank row
            if size(dat,1) < 1
                lr = [];
            else
                lr = dat(end,:);
            end
            
            [tf,idx] = ismember(obj.beamDaqs{obj.currDaqSel},obj.hConfigEditor.availableDaqs);
            if tf
                dprops = obj.hConfigEditor.daqInfo(idx);
            end
            
            if (isempty(lr) || ~isempty(lr{1})) && tf && size(dat,1) < dprops.numAOs
                dat(end+1,:) = {'', '', '', '', '', '' obj.delChar};
            end
            
            obj.hChannelTable.Data = dat;
        end
        
        function shutterCellEditFcn(obj,varargin)
            dat = obj.hShutterTable.Data;
            d = find([dat{:,1}]);
            if isempty(d)
                d = [];
            end
            obj.daqSettingList(obj.currDaqSel).calOpenShutterIDs = d;
        end
    end
    
    %% prop access
    methods
        function set.currDaqSel(obj,v)
            N = numel(obj.beamDaqs);
            if N
                if isempty(v) || isnan(v) || v < 1
                    v = 1;
                else
                    v(v>N) = N;
                end
            else
                v = nan;
            end
            
            obj.currDaqSel = v;
            
            if isempty(v) || isnan(v)
                obj.hBeamDaqDevicePanel.Title = '';
                disablePanel();
            else
                dn = obj.beamDaqs{v};
                [tf,idx] = ismember(dn,obj.hConfigEditor.availableDaqs);
                tf = tf && obj.hConfigEditor.daqInfo(idx).isXSer;
                
                if tf
                    obj.hBeamDaqDevicePanel.Title = sprintf('Beam DAQ %d: %s',v,dn);
                    set(obj.hBeamDaqDevicePanel.Children, 'visible', 'on');
                    obj.hNoSelText.Visible = 'off';
                    
                    dprops = obj.hConfigEditor.daqInfo(idx);
                    ds = obj.daqSettingList(v);
                    
                    % channel table
                    obj.hChannelTable.ColumnFormat = {dprops.allAOs, 'char', 'numeric', [{'None'} dprops.allAIs], 'numeric', {'Transmitted Light' 'Rejected Light'} 'char'};
                    if isempty(ds.chanIDs)
                        dat = {};
                    else
                        dat = arrayfun(@(a,b,c,d,e,f){strcat('AO', num2str(a)) b{1} c strcat('AI', num2str(d)) e obj.scMap(f) obj.delChar},ds.chanIDs,...
                            ds.displayNames,ds.voltageRanges,ds.calInputChanIDs,ds.calOffsets,ds.calUseRejectedLight,'uniformoutput',false);
                        dat = vertcat(dat{:});
                        dat(strcmp(dat(:,4), 'AINaN'),4) = {'None'};
                    end
                    if size(dat,1) < dprops.numAOs
                        dat(end+1,:) = {'', '', '', '', '', '' obj.delChar};
                    end
                    obj.hChannelTable.Data = dat;
                    
                    % shutter table
                    ds.calOpenShutterIDs(ds.calOpenShutterIDs > obj.hConfigEditor.numShutters) = [];
                    obj.hShutterTable.Data(:,1) = {false};
                    obj.hShutterTable.Data(ds.calOpenShutterIDs,1) = {true};
                    
                    % routing section
                    rtCh = [{'Automatic Routing'} arrayfun(@(x)strcat('PFI',num2str(x)),0:dprops.numPFIs-1,'uniformoutput',false)];
                    obj.hLineClockInPopUp.hCtl.String = rtCh;
                    obj.hFrameClockInPopUp.hCtl.String = rtCh;
                    obj.hReferenceClockInPopUp.hCtl.String = rtCh;
                    
                    if ~ismember(ds.modifiedLineClockIn,rtCh)
                        ds.modifiedLineClockIn = '';
                    end
                    if ~ismember(ds.frameClockIn,rtCh)
                        ds.frameClockIn = '';
                    end
                    if ~ismember(ds.referenceClockIn,rtCh)
                        ds.referenceClockIn = '';
                    end
                    
                    obj.lineClockSel = ds.modifiedLineClockIn;
                    obj.frameClockSel = ds.frameClockIn;
                    obj.refClockSel = ds.referenceClockIn;
                    obj.daqSettingList(v) = ds;
                else
                    obj.hBeamDaqDevicePanel.Title = sprintf('Beam DAQ %d: %s (Invalid DAQ Selection!)',v,dn);
                    disablePanel();
                end
                obj.hBeamDaqDevicesList.Value = v;
            end
            
            function disablePanel
                set(obj.hBeamDaqDevicePanel.Children, 'visible', 'off');
                obj.hNoSelText.Visible = 'on';
                obj.hShutterTable.Data(:,1) = {false};
                obj.hChannelTable.Data = {};
                obj.hLineClockInPopUp.hCtl.String = {'Automatic Routing'};
                obj.hFrameClockInPopUp.hCtl.String = {'Automatic Routing'};
                obj.hReferenceClockInPopUp.hCtl.String = {'Automatic Routing'};
                obj.lineClockSel = 'Automatic Routing';
                obj.frameClockSel = 'Automatic Routing';
                obj.refClockSel = 'Automatic Routing';
            end
        end
        
        function set.lineClockSel(obj,v)
            if isempty(v)
                obj.lineClockSel = 'Automatic Routing';
            else
                obj.lineClockSel = v;
            end
            
            if ~isnan(obj.currDaqSel)
                if strcmp(v,'Automatic Routing')
                    v = '';
                end
                obj.daqSettingList(obj.currDaqSel).modifiedLineClockIn = v;
            end
        end
        
        function set.frameClockSel(obj,v)
            if isempty(v)
                obj.frameClockSel = 'Automatic Routing';
            else
                obj.frameClockSel = v;
            end
            
            if ~isnan(obj.currDaqSel)
                if strcmp(v,'Automatic Routing')
                    v = '';
                end
                obj.daqSettingList(obj.currDaqSel).frameClockIn = v;
            end
        end
        
        function set.refClockSel(obj,v)
            if isempty(v)
                obj.refClockSel = 'Automatic Routing';
            else
                obj.refClockSel = v;
            end
            
            if ~isnan(obj.currDaqSel)
                if strcmp(v,'Automatic Routing')
                    v = '';
                end
                obj.daqSettingList(obj.currDaqSel).referenceClockIn = v;
            end
        end
        
        function v = get.beamDaqNames(obj)
            n = numel(obj.beamDaqs);
            if n
                v = cellfun(@(x,y)sprintf('%d: %s',x,y),num2cell(1:n),obj.beamDaqs,'uniformoutput',false);
            else
                v = {};
            end
        end
    end
end

function s = newDaqStruct(i)
    if nargin < 1
        i = 1;
    end
    s = struct('modifiedLineClockIn','','frameClockIn','','referenceClockIn','','referenceClockRate',10e6,'chanIDs',0,'displayNames',{{sprintf('Beam DAQ %d CH 1',i)}},...
                'voltageRanges',1.5,'calInputChanIDs',nan,'calOffsets',0,'calUseRejectedLight',false,'calOpenShutterIDs',[]);
end



%--------------------------------------------------------------------------%
% BeamsPage.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
