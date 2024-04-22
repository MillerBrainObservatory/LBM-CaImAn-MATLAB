classdef ScanfieldDisplayControls < most.Gui
    
    properties (SetObservable)
        showDisplay = false;
        displayRefreshPeriod = 0.03;
    end
    
    properties (Hidden, SetObservable)
        hDisplayFig;
        hDisplayAx;
        hSurfs;
        hTexts;
        
        utSfTable;
        hTblLstener;
        hRstLstener;
        hDisplayTimer;
        hLutList;
        
        tblSel;
        selZ;
        
        highlightFrame;
        highlightStart;
        
        initialized = false;
        
        obsRows = 5;
        obsColumns = 5;
    end
    
    properties (Hidden)
        %info cache
        disps = repmat(struct('enable', false, 'name', 'Display 1', 'channel', 1, 'roi', 1,'z',0),0,0);
        dispUids;
        lastFrmi;
        asps;
        sfs;
        lastFrm = 0;
        lutCache;
    end
    
    %% Lifecycle
    methods
        function obj = ScanfieldDisplayControls(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            obj = obj@most.Gui(hModel, hController, [85.3 15.6]);
            set(obj.hFig,'Name','SCANFIELD DISPLAY CONTROLS','Resize','off');
            
            obj.utSfTable = uitable(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuitableFontUnits'),...
                'Units','characters',...
                'BackgroundColor',get(0,'defaultuitableBackgroundColor'),...
                'ColumnName',{'On'; 'Name'; 'Chan'; 'Roi'; 'Z'; },...
                'ColumnWidth',{ 26 89 35 25 43 },...
                'RowName',get(0,'defaultuitableRowName'),...
                'Position',[1 4.3 54 10.9],...
                'ColumnEditable',[true true true true true],...
                'ColumnFormat',{'logical' 'char' 'numeric' 'numeric' 'numeric'},...
                'RearrangeableColumns','off',...
                'RowStriping','on',...
                'CellEditCallback',@obj.tableCB,...
                'CellSelectionCallback',@obj.tableSelCB,...
                'ForegroundColor',get(0,'defaultuitableForegroundColor'),...
                'Tag','utSfTable');
            obj.hTblLstener = addlistener(obj.hModel.hDisplay, 'scanfieldDisplays', 'PostSet', @obj.updateTable);
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','Select Z:',...
                'Style','text',...
                'enable','off',...
                'tag', 'stZ',...
                'Position',[30.2 2.5 10 1.07692307692308]);
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{'0' '1' '2'},...
                'Style','popupmenu',...
                'Value',1,...
                'enable','off',...
                'ValueMode',get(0,'defaultuicontrolValueMode'),...
                'Position',[41 2.4 14 1.53846153846154],...
                'Bindings', {obj.hModel.hStackManager 'zs' 'Choices'},...
                'Callback',@obj.pmZCB,...
                'Tag','pmZ');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','',...
                'Style','edit',...
                'Value',1,...
                'enable','off',...
                'ValueMode',get(0,'defaultuicontrolValueMode'),...
                'Position',[41 2.38 10.8 1.6],...
                'Bindings', {obj 'selZ' 'Value'},...
                'Tag','etZ');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Add',...
                'Style',get(0,'defaultuicontrolStyle'),...
                'Position',[.8 0.4 7.2 1.69230769230769],...
                'Callback',@(varargin)obj.tableCB([],[],'add'),...
                'Tag','pbAdd');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Del',...
                'Style',get(0,'defaultuicontrolStyle'),...
                'Position',[8.6 0.4 7 1.69230769230769],...
                'Callback',@(varargin)obj.tableCB([],[],'remove'),...
                'Tag','pbRemove');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Move Down',...
                'Style',get(0,'defaultuicontrolStyle'),...
                'Position',[40.2 0.4 15 1.69230769230769],...
                'Callback',@(varargin)obj.tableCB([],[],'move down'),...
                'Tag','pbDown');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Move Up',...
                'Style',get(0,'defaultuicontrolStyle'),...
                'Position',[27.5 0.4 12 1.69230769230769],...
                'Callback',@(varargin)obj.tableCB([],[],'move up'),...
                'Tag','pbUp');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Show scanfield display',...
                'Style','checkbox',...
                'Position',[56.7 13.6923076923077 29.6 1.76923076923077],...
                'Bindings',{obj 'showDisplay' 'Value'},...
                'Tag','cbShowSfDisplay');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Enable scanfield display',...
                'Style','checkbox',...
                'Position',[56.7 11.6923076923077 29.6 1.76923076923077],...
                'Bindings',{{obj.hModel.hDisplay 'enableScanfieldDisplays' 'Value'} {obj.hModel.hDisplay 'enableScanfieldDisplays' 'callback' @(varargin)obj.chgdEnable}},...
                'Tag','cbEnableSfDisplay');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Show names',...
                'Style','checkbox',...
                'Position',[56.7 9.6923076923077 29.6 1.76923076923077],...
                'Bindings',{{obj.hModel.hDisplay 'showScanfieldDisplayNames' 'Value'} {obj.hModel.hDisplay 'showScanfieldDisplayNames' 'Callback' @(varargin)obj.resetDisplay(true)}},...
                'Tag','cbShowNames');
            
            h9 = uipanel(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuipanelFontUnits'),...
                'Units','characters',...
                'Title','Display Tiling',...
                'Position',[57.2 1.61538461538462 21.8 7.92307692307692]);
            
            obj.addUiControl(...
                'Parent',h9,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Columns:',...
                'HorizontalAlignment','right',...
                'Style','text',...
                'Position',[1.4 2.8 10 1.07692307692308],...
                'Tag','stColumns');
            
            obj.addUiControl(...
                'Parent',h9,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','100',...
                'Style','edit',...
                'Position',[11.8 2.6 7.6 1.69230769230769],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{{obj 'obsColumns' 'Value'} {obj.hModel.hDisplay 'scanfieldDisplayColumns' 'Value'} {obj.hModel.hDisplay 'scanfieldDisplayColumns' 'Callback' @(varargin)obj.resetDisplay()}},...
                'Tag','etColumns');
            
            obj.addUiControl(...
                'Parent',h9,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Rows:',...
                'HorizontalAlignment','right',...
                'Style','text',...
                'Position',[1.4 .6 10 1.07692307692308],...
                'Tag','stRows');
            
            obj.addUiControl(...
                'Parent',h9,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','100',...
                'Style','edit',...
                'Position',[11.8 0.4 7.6 1.69230769230769],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{{obj 'obsRows' 'Value'} {obj.hModel.hDisplay 'scanfieldDisplayRows' 'Value'} {obj.hModel.hDisplay 'scanfieldDisplayRows' 'Callback' @(varargin)obj.resetDisplay()}},...
                'Tag','etRows');

%%%                            'Bindings',{{obj.hModel.hDisplay 'scanfieldDisplayRows' 'Value'} {obj.hModel.hDisplay 'scanfieldDisplayRows' 'Callback' @(varargin)obj.resetDisplay()}},...

            obj.addUiControl(...
                'Parent',h9,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{'Auto';'Set Columns';'Set Rows'},...
                'Style','popupmenu',...
                'Value',1,...
                'ValueMode',get(0,'defaultuicontrolValueMode'),...
                'Position',[1.6 4.76923076923077 17.8 1.53846153846154],...
                'Bindings',{{obj.hModel.hDisplay 'scanfieldDisplayTilingMode' 'Choice'} {obj.hModel.hDisplay 'scanfieldDisplayTilingMode' 'Callback' @obj.tilingModeChanged}},...
                'Tag','pmTilingMode');
            
            obj.hDisplayTimer = timer(...
                'Name','Scanfield Display Timer',...
                'TimerFcn',@(varargin)obj.displayUpdate(),...
                'ExecutionMode','fixedSpacing',...
                'Period',obj.displayRefreshPeriod);
            start(obj.hDisplayTimer);
            
            %reset when main display resets
            obj.hRstLstener = obj.hModel.hDisplay.addlistener('displayReset', @(varargin)obj.resetDisplay());
            
            %luts changed
            obj.hLutList = [obj.hModel.hDisplay.addlistener('chan1LUT', 'PostSet', @(varargin)obj.updateColorMaps())...
                obj.hModel.hDisplay.addlistener('chan2LUT', 'PostSet', @(varargin)obj.updateColorMaps())...
                obj.hModel.hDisplay.addlistener('chan3LUT', 'PostSet', @(varargin)obj.updateColorMaps())...
                obj.hModel.hDisplay.addlistener('chan4LUT', 'PostSet', @(varargin)obj.updateColorMaps())];
            
            %Update the table and create the figure
            obj.initialized = true;
            obj.updateTable();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTblLstener);
            most.idioms.safeDeleteObj(obj.hDisplayFig);
            most.idioms.safeDeleteObj(obj.hDisplayTimer);
            most.idioms.safeDeleteObj(obj.hRstLstener);
            most.idioms.safeDeleteObj(obj.hLutList);
        end
        
    end
    
    %% User methods
    methods
        function addDisp(obj, name, channel, roi, z)
            obj.tableCB([], [], 'add', name, channel, roi, z);
        end
    end
    
    %% Internal Gui Methods
    methods (Hidden)
        function tableCB(obj,~,evt,op,name,channel,roi,z)
            data = get(obj.utSfTable, 'Data');
            N = size(data,1);
            nwArr = repmat(struct('enable', true, 'name', '', 'channel', 1, 'roi', 1,'z',0), N, 1);
            
            if ~isempty(evt) 
                switch (evt.Indices(2))
                    case 3
                        if isnan(evt.NewData) || isinf(evt.NewData) || (round(evt.NewData) ~= evt.NewData) || (evt.NewData <= 0)
                             most.idioms.warn('Channel must be an integer greater than zero. Resetting to previous value.');
                             data(evt.Indices(1), evt.Indices(2)) = num2cell(evt.PreviousData);
                        end
                    case 4
                        if isnan(evt.NewData) || isinf(evt.NewData) || (round(evt.NewData) ~= evt.NewData) || (evt.NewData <= 0)
                            most.idioms.warn('ROI  must be an integer greater than zero. Resetting to previous value.');
                            data(evt.Indices(1), evt.Indices(2)) = num2cell(evt.PreviousData);
                        end
                    case 5
                        if isnan(evt.NewData) || isinf(evt.NewData)
                            most.idioms.warn('Z value must be a valid numeric value. NaN and Inf are not allowed. Resetting to previous value.');
                            data(evt.Indices(1), evt.Indices(2)) = num2cell(evt.PreviousData);
                        else
                            try
                                set(obj.etZ, 'String', num2str(nwArr(evt.Indices(1)).z));
                            catch
                            end
                            
                        end
                end % switch
                
            end % if - ~isempty
            
            for i = 1:N
                nwArr(i).enable = data{i,1};
                nwArr(i).name = data{i,2};
                nwArr(i).channel = data{i,3};
                nwArr(i).roi = data{i,4};
                nwArr(i).z = data{i,5};
            end
            
            if nargin > 3
                if strcmp(op, 'add')
                    if nargin < 5
                        name = '';
                        channel = 1;
                        roi = 1;
                        z = 0;
                    end
                    
                    nwArr(N+1) = struct('enable', true, 'name', name, 'channel', channel, 'roi', roi,'z',z);
                elseif ~isempty(obj.tblSel)
                    switch op
                        case 'remove'
                            if N > 0 && obj.tblSel <= N
                                nwArr(obj.tblSel) = [];
                            end
                            
                        case 'move up'
                            if N > 1 && obj.tblSel > 1
                                tmp = nwArr(obj.tblSel - 1);
                                nwArr(obj.tblSel - 1) = nwArr(obj.tblSel);
                                nwArr(obj.tblSel) = tmp;
                                obj.tblSel = obj.tblSel - 1;
                            end
                            
                        case 'move down'
                            if N > 1 && obj.tblSel < N
                                tmp = nwArr(obj.tblSel + 1);
                                nwArr(obj.tblSel + 1) = nwArr(obj.tblSel);
                                nwArr(obj.tblSel) = tmp;
                                obj.tblSel = obj.tblSel + 1;
                            end
                    end
                end
            end
            
            obj.hModel.hDisplay.scanfieldDisplays = nwArr; 
        end
        
        function updateTable(obj,varargin)
            dat = obj.hModel.hDisplay.scanfieldDisplays;
            N = numel(dat);
            
            tblDat = cell(N,5);
            for i = 1:N
                tblDat{i,1} = dat(i).enable;
                tblDat{i,2} = dat(i).name;
                tblDat{i,3} = dat(i).channel;
                tblDat{i,4} = dat(i).roi;
                tblDat{i,5} = dat(i).z;
            end
            
            set(obj.utSfTable, 'Data', tblDat);
            obj.resetDisplay();
        end
        
        function tableSelCB(obj,~,evt)
            i = evt.Indices;
            en = 'off';
            
            if ~isempty(i)
                obj.tblSel = i(1);
                set(obj.etZ, 'String', num2str(obj.hModel.hDisplay.scanfieldDisplays(i(1)).z));
                
                if numel(obj.hModel.hDisplay.scanfieldDisplays)
                    en = 'on';
                end
            end
            
            set([obj.pmZ.hCtl obj.etZ.hCtl obj.stZ.hCtl obj.pbAdd.hCtl...
                obj.pbRemove.hCtl obj.pbUp.hCtl obj.pbDown.hCtl], 'enable', en);
        end
        
        function pmZCB(obj,varargin)
            try
                ch = get(obj.pmZ, 'String');
                str = ch{get(obj.pmZ, 'Value')};
                set(obj.etZ, 'String', str);
                obj.hModel.hDisplay.scanfieldDisplays(obj.tblSel).z = str2double(str);
            catch
            end
        end
        
        function chgdEnable(obj)
            if obj.hModel.hDisplay.enableScanfieldDisplays
                obj.showDisplay = true;
            end
        end
        
        function tilingModeChanged(obj,varargin)
            switch obj.hModel.hDisplay.scanfieldDisplayTilingMode
                case 'Auto'
                    set([obj.stColumns.hCtl obj.etColumns.hCtl], 'enable', 'off');
                    set([obj.stRows.hCtl obj.etRows.hCtl], 'enable', 'off');
                    
                case 'Set Columns'
                    set([obj.stColumns.hCtl obj.etColumns.hCtl], 'enable', 'on');
                    set([obj.stRows.hCtl obj.etRows.hCtl], 'enable', 'off');
                    
                case 'Set Rows'
                    set([obj.stColumns.hCtl obj.etColumns.hCtl], 'enable', 'off');
                    set([obj.stRows.hCtl obj.etRows.hCtl], 'enable', 'on');
            end
            
            obj.resetDisplay();
        end
    end
    
    methods
        function v = get.showDisplay(obj)
            if most.idioms.isValidObj(obj.hDisplayFig)
                v = strcmp(get(obj.hDisplayFig,'visible'), 'on');
            else
                v = false;
            end
        end
        
        function set.showDisplay(obj,v)
            if obj.hController.initComplete
                if most.idioms.isValidObj(obj.hDisplayFig)
                    if v
                        vis = 'on';
                    else
                        vis = 'off';
                        obj.hModel.hDisplay.enableScanfieldDisplays = false;
                    end
                    set(obj.hDisplayFig,'visible', vis);
                elseif v
                    obj.resetDisplay();
                    set(obj.hDisplayFig,'visible', 'on');
                end
            end
        end
        
        function set.selZ(obj,v)
            try
                obj.hModel.hDisplay.scanfieldDisplays(obj.tblSel).z = v;
            catch
            end
        end
        
        function v = get.selZ(obj)
            try
                v = obj.hModel.hDisplay.scanfieldDisplays(obj.tblSel).z;
            catch
                v = 0;
            end
        end
        
        function set.displayRefreshPeriod(obj,v)
            rstrt = strcmp(obj.hDisplayTimer.running, 'on');
            stop(obj.hDisplayTimer);
            
            obj.hDisplayTimer.Period = v;
            obj.displayRefreshPeriod = v;
            
            if rstrt
                start(obj.hDisplayTimer);
            end
        end
    end
    
    methods
        function set.obsRows(obj,v)
            if ~isnan(v) && ~isinf(v) && (v > 0) && (round(v) == v)
                obj.obsRows = v;
            end           
        end

        function set.obsColumns(obj,v)
            if ~isnan(v) && ~isinf(v) && (v > 0) && (round(v) == v)
                obj.obsColumns = v;
            end           
        end
    end
    
    %% Internal display methods
    methods (Hidden)
        function updateColorMaps(obj)
            if most.idioms.isValidObj(obj.hDisplayFig)
                hCIN = obj.hController.hGUIData.channelControlsV4.channelImageHandler;
                cmf = hCIN.hChannelControlsUITable.Data{1,7};
                if strncmp(cmf, 'obj.', 4)
                    cmf = ['hCIN.' cmf(5:end)];
                end
                cm = eval(cmf);
                set(obj.hDisplayFig, 'Colormap', cm);
                
                luts = obj.hModel.hChannels.channelLUT;
                N = numel(luts);
                obj.lutCache = zeros(N,2);
                for i = 1:N
                    lut = double(luts{i});
                    obj.lutCache(i,:) = [lut(1) 1/(lut(2) - lut(1))];
                end
            end
        end
        
        function resetDisplay(obj,forceFullReset)
            if ~obj.initialized
                return
            end
            
            if nargin < 2 || isempty(forceFullReset)
                forceFullReset = false;
            end
            
            persistent sgl
            
            if isempty(sgl)
                try
                    sgl = true;
                    stop(obj.hDisplayTimer);
                    
                    if ~most.idioms.isValidObj(obj.hDisplayFig)
                        obj.hDisplayFig = figure('Name','Scanfield Display','Visible','off','NumberTitle','off','SizeChangedFcn',@(varargin)obj.resetDisplay(),...
                            'Menubar','none','Tag','sfDisplay','CloseRequestFcn',@obj.figCloseEventHandler,'Color', .05*ones(3,1));
                        try
                            obj.hController.registerGUI(obj.hDisplayFig);
                        catch
                            most.idioms.warn('Could not register display window to be managed by controller.');
                        end
                        
                        obj.hDisplayAx = axes('Parent',obj.hDisplayFig,'Position',[0 0 1 1],'YDir','reverse','XTick',[],'YTick',[],'CLim',[0 1],...
                            'YTickLabelMode','manual','XTickLabelMode','manual','XTickLabel',[],'YTickLabel',[],'Color', .05*ones(3,1));
                        hold(obj.hDisplayAx, 'on');
                    else
                        set(obj.hDisplayAx,'units','normalized','position',[0 0 1 1]);
                        
                        % fix bug where scanfield display randomly stops working
                        obj.hDisplayAx.CameraUpVector = [0 -1 0];
                    end
                    
                    xlim(obj.hDisplayAx, [0 1]);
                    ylim(obj.hDisplayAx, [0 1]);
                    
                    nwDisps = obj.hModel.hDisplay.scanfieldDisplays;
                    nwDisps = nwDisps([nwDisps.enable]);
                    N = numel(nwDisps);
                    
                    % compare nwDisps to obj.disps to see if deep reset is needed
                    forceFullReset = forceFullReset || ~isequal(rmfield(nwDisps,'channel'), rmfield(obj.disps,'channel'));
                    
                    if forceFullReset
                        obj.disps = nwDisps;
                        obj.dispUids = zeros(N,1,'uint64');
                        obj.lastFrmi = zeros(N,1);
                        
                        %determine scanfields, get scanfield aspect ratios
                        for i = 1:N
                            try
                                hRoi = obj.hModel.hRoiManager.roiGroupMroi.rois(obj.disps(i).roi);
                                obj.sfs{i} = hRoi.get(obj.disps(i).z);
                                if ~isempty(obj.sfs{i})
                                    bb = obj.sfs{i}.boundingbox();
                                    obj.asps(i) = bb(3) / bb(4);
                                else
                                    obj.asps(i) = nan;
                                end
                                obj.dispUids(i) = hRoi.uuiduint64;
                            catch
                                obj.sfs{i} = [];
                                obj.asps(i) = nan;
                            end
                        end
                    end
                    
                    
                    %windows props
                    set(obj.hDisplayAx,'units','points');
                    p = get(obj.hDisplayAx,'position');
                    wndoSz = p([3 4]);
                    wndoAsp = wndoSz(1)/wndoSz(2);
                    gapThickness = 10;
                    
                    %determine number of frames
                    switch obj.hModel.hDisplay.scanfieldDisplayTilingMode
                        case 'Set Columns'
                            cols = obj.hModel.hDisplay.scanfieldDisplayColumns;
                            rows = ceil(N/cols);
                            
                        case 'Set Rows'
                            rows = obj.hModel.hDisplay.scanfieldDisplayRows;
                            cols = ceil(N/rows);
                            
                        otherwise
                            avgAsp = mean(obj.asps(~isnan(obj.asps)));
%                             rows = max(min(round((N*avgAsp/wndoAsp)^.5),N),1);
%                             cols = ceil(N/rows);
                            cols = max(min(round((N*wndoAsp/avgAsp)^.5),N),1);
                            rows = ceil(N/cols);
                    end
                    
                    %frame props
                    frW = wndoSz(1)/cols;
                    frH = wndoSz(2)/rows;
                    
                    fontSz = 8;
                    if obj.hModel.hDisplay.showScanfieldDisplayNames
                        nameH = fontSz;
                        textv = 'on';
                    else
                        nameH = 0;
                        textv = 'off';
                    end
                    
                    %apply the desired properties
                    for i = 0:N-1
                        if ~isnan(obj.asps(i+1))
                            %determine position
                            %bounds of this frame
                            iFrm = mod(i,cols);
                            jFrm = floor(i/cols);

                            frm = [((gapThickness/2) + frW*iFrm) ((gapThickness/2) + frH*jFrm + nameH) (frW-gapThickness) (frH-gapThickness-nameH)];
                            frmAsp = frm(3) / frm(4);
                            
                            sfAsp = obj.asps(i+1);
                            
                            if sfAsp > frmAsp
                                W = frm(3);
                                H = W/sfAsp;
                            else
                                H = frm(4);
                                W = H*sfAsp;
                            end

                            L = frm(1) + (frm(3)-W)/2;
                            T = frm(2) + (frm(4)-H)/2;
                            xs = [L L+W]/wndoSz(1);
                            ys = [T T+H]/wndoSz(2);
                            vis = 'on';
                            
                            tp = [(frm(1)+frm(3)*.5) T-nameH] ./ wndoSz;
                            tv = textv;
                        else
                            xs = [0 1];
                            ys = [0 1];
                            vis = 'off';
                            
                            tp = [0 0];
                            tv = 'off';
                        end
                        
                        if (i+1) > numel(obj.hSurfs) || ~most.idioms.isValidObj(obj.hSurfs(i+1))
                            %need a new surf
                            obj.hSurfs(i+1) = surface(xs, ys, zeros(2), 'Parent',obj.hDisplayAx,'Hittest','off','visible',vis,...
                                'FaceColor','texturemap','CData',zeros(2,2,3),'EdgeColor','b','FaceLighting','none');
                        else
                            set(obj.hSurfs(i+1), 'xdata', xs, 'ydata', ys, 'visible', vis);
                        end
                        
                        if isempty(obj.disps(i+1).name)
                            txt = sprintf('Roi %d, z=%.2f',obj.disps(i+1).roi,obj.disps(i+1).z);
                        else
                            txt = sprintf('%s (Roi %d, z=%.2f)',obj.disps(i+1).name,obj.disps(i+1).roi,obj.disps(i+1).z);
                        end
                        
                        if (i+1) > numel(obj.hTexts) || ~most.idioms.isValidObj(obj.hTexts(i+1))
                            %need a new surf
                            obj.hTexts(i+1) = text(tp(1), tp(1), txt, 'Parent',obj.hDisplayAx,'Hittest','off','color','w','FontSize',fontSz,'HorizontalAlignment','center');
                        end
                        set(obj.hTexts(i+1), 'string', txt, 'position', tp, 'visible', tv,'FontSize',fontSz);
                    end
                    
                    %delete extra surfs and texts
                    for i = N+1:numel(obj.hSurfs)
                        most.idioms.safeDeleteObj(obj.hSurfs(i));
                    end
                    obj.hSurfs(N+1:numel(obj.hSurfs)) = [];
                    
                    for i = N+1:numel(obj.hTexts)
                        most.idioms.safeDeleteObj(obj.hTexts(i));
                    end
                    obj.hTexts(N+1:numel(obj.hTexts)) = [];
                    
                    obj.updateColorMaps();
                    
                    start(obj.hDisplayTimer);
                    sgl = [];
                catch ME
                    start(obj.hDisplayTimer);
                    sgl = [];
                    ME.rethrow
                end
            end
        end
        
        function displayUpdate(obj)
            try
                if obj.hModel.hDisplay.enableScanfieldDisplays
                    frm = obj.hModel.hDisplay.lastFrameNumber;
                    
                    if isempty(frm)
                        frm = 0;
                    end
                    
                    if obj.hModel.hRoiManager.mroiEnable && (obj.lastFrm ~= frm)
                        
                        obj.lastFrm = frm;
                        locLutCache = obj.lutCache;
                        aveFac = 1/obj.hModel.hDisplay.displayRollingAverageFactor;
                        
                        N = numel(obj.disps);
                        for i = 1:N
                            try
                                dispi = obj.disps(i);
                                
                                % allow for some tolerance in the z value
                                dz = abs(dispi.z - obj.hModel.hDisplay.displayZs);
                                [diff,frameIdx] = min(dz);
                                
                                if diff < 1E-6
                                    [tf,chIdx] = ismember(dispi.channel,obj.hModel.hChannels.channelDisplay);
                                    if tf
                                        tfrd = obj.hModel.hDisplay.rollingStripeDataBuffer{frameIdx}{1}.roiData;
                                        uuids = cellfun(@(x)x.hRoi.uuiduint64,tfrd);
                                        [tf,idx] = ismember(obj.dispUids(i), uuids);
                                        
                                        if tf && obj.lastFrmi(i) ~= tfrd{1}.frameNumberAcq
                                            displayData = double(tfrd{idx}.imageData{chIdx}{1})' * aveFac;
                                            displayData = (displayData - locLutCache(dispi.channel,1)) * locLutCache(dispi.channel,2);
                                            set(obj.hSurfs(i),'CData',displayData);
                                            obj.lastFrmi(i) = tfrd{1}.frameNumberAcq;
                                        end
                                    end
                                end
                            catch
                            end
                        end
                    end
                end
            catch
            end
        end
        
        
        function figCloseEventHandler(obj, varargin)
            obj.showDisplay = false;
        end
    end
end


%--------------------------------------------------------------------------%
% ScanfieldDisplayControls.m                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
