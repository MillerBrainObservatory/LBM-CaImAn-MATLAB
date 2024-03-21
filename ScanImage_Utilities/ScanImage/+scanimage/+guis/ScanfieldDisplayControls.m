classdef ScanfieldDisplayControls < most.Gui
    
    properties (SetObservable)
        showDisplay = false;
        displayRefreshPeriod = 0.03;
    end
    
    properties (Hidden, SetObservable)
        hDisplayFig;
        hDisplayAxes;
        hDisplayMenu;
        hSurfs;
        hTexts;
        
        utSfTable;
        hDispListener;
        hAveListener;
        hTblLstener;
        hRstLstener;
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
        dispIds = [];
        dispUids;
        asps;
        sfs;
        
        upChar =  ['<html><table border=0 width=16><TR><TD><center>' char(8593)  '</center></TD></TR></table></html>'];
        dnChar =  ['<html><table border=0 width=16><TR><TD><center>' char(8595)  '</center></TD></TR></table></html>'];
        delChar = ['<html><table border=0 width=20><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
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
            
            obj = obj@most.Gui(hModel, hController, [95 14.5], 'characters');
            set(obj.hFig,'Name','SCANFIELD DISPLAY CONTROLS','Resize','off');
            
            obj.utSfTable = uitable(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuitableFontUnits'),...
                'Units','characters',...
                'BackgroundColor',get(0,'defaultuitableBackgroundColor'),...
                'ColumnName',{'On'; 'Name'; 'Chan'; 'Roi'; 'Z'; ''; ''; ''},...
                'ColumnWidth',{ 26 89 35 25 43 16 16 20},...
                'RowName',get(0,'defaultuitableRowName'),...
                'Position',[1 2.5 64 11.5],...
                'ColumnEditable',[true true true true true false false false],...
                'ColumnFormat',{'logical' 'char' 'numeric' 'numeric' 'numeric' 'char' 'char' 'char'},...
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
                'Position',[40.2 .62 10 1.07692307692308]);
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{'0' '1' '2'},...
                'Style','popupmenu',...
                'Value',1,...
                'enable','off',...
                'ValueMode',get(0,'defaultuicontrolValueMode'),...
                'Position',[51 .52 14 1.53846153846154],...
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
                'Position',[51 .44 10.8 1.6],...
                'Bindings', {obj 'selZ' 'Value'},...
                'Tag','etZ');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Show scanfield display',...
                'Style','checkbox',...
                'Position',[66.7 12.5923076923077 29.6 1.76923076923077],...
                'Bindings',{obj 'showDisplay' 'Value'},...
                'Tag','cbShowSfDisplay');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Delete All',...
                'Style',get(0,'defaultuicontrolStyle'),...
                'Position',[.8 0.4 16 1.69230769230769],...
                'Callback',@obj.mnuRemoveAll,...
                'Tag','pbDeleteAll');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Enable scanfield display',...
                'Style','checkbox',...
                'Position',[66.7 10.5923076923077 29.6 1.76923076923077],...
                'Bindings',{{obj.hModel.hDisplay 'enableScanfieldDisplays' 'Value'} {obj.hModel.hDisplay 'enableScanfieldDisplays' 'callback' @(varargin)obj.chgdEnable}},...
                'Tag','cbEnableSfDisplay');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Show names',...
                'Style','checkbox',...
                'Position',[66.7 8.5923076923077 29.6 1.76923076923077],...
                'Bindings',{{obj.hModel.hDisplay 'showScanfieldDisplayNames' 'Value'} {obj.hModel.hDisplay 'showScanfieldDisplayNames' 'Callback' @(varargin)obj.resetDisplay()}},...
                'Tag','cbShowNames');
            
            h9 = uipanel(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuipanelFontUnits'),...
                'Units','characters',...
                'Title','Display Tiling',...
                'Position',[67.2 .5 21.8 7.92307692307692]);
            
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
            
            %reset when main display resets
            obj.hRstLstener = obj.hModel.hDisplay.addlistener('displayReset', @(varargin)obj.resetDisplay());
            
            %draw new frame
            obj.hDispListener = obj.hModel.hUserFunctions.addlistener('frameAcquired', @(varargin)obj.displayUpdate());
            
            %ave factor changed
            obj.hAveListener = obj.hModel.hDisplay.addlistener('displayRollingAverageFactor', 'PostSet', @(varargin)obj.updateLuts());
            
            %luts changed
            obj.hLutList = [obj.hModel.hDisplay.addlistener('chan1LUT', 'PostSet', @(varargin)obj.updateLuts())...
                obj.hModel.hDisplay.addlistener('chan2LUT', 'PostSet', @(varargin)obj.updateLuts())...
                obj.hModel.hDisplay.addlistener('chan3LUT', 'PostSet', @(varargin)obj.updateLuts())...
                obj.hModel.hDisplay.addlistener('chan4LUT', 'PostSet', @(varargin)obj.updateLuts())];
            
            %Update the table and create the figure
            obj.initialized = true;
            obj.updateTable();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDispListener);
            most.idioms.safeDeleteObj(obj.hAveListener);
            most.idioms.safeDeleteObj(obj.hTblLstener);
            most.idioms.safeDeleteObj(obj.hDisplayFig);
            most.idioms.safeDeleteObj(obj.hRstLstener);
            most.idioms.safeDeleteObj(obj.hLutList);
        end
        
    end
    
    %% Internal Gui Methods
    methods (Hidden)
        function tableCB(obj,~,evt)
            data = get(obj.utSfTable, 'Data');
            szs = logical(cellfun(@length,data));
            if ~any(szs(end,:))
                data(end,:) = [];
            end
            
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
            
            def = {true '' 1 1 0 '' '' ''};
            
            for i = 1:N
                data(i,~szs(i,:)) = def(~szs(i,:));
                
                nwArr(i).enable = data{i,1};
                nwArr(i).name = data{i,2};
                nwArr(i).channel = data{i,3};
                nwArr(i).roi = data{i,4};
                nwArr(i).z = data{i,5};
            end
            
            obj.hModel.hDisplay.scanfieldDisplays = nwArr; 
        end
        
        function updateTable(obj,varargin)
            dat = obj.hModel.hDisplay.scanfieldDisplays;
            N = numel(dat);
            
            tblDat = cell(N+1,8);
            for i = 1:N
                tblDat{i,1} = dat(i).enable;
                tblDat{i,2} = dat(i).name;
                tblDat{i,3} = dat(i).channel;
                tblDat{i,4} = dat(i).roi;
                tblDat{i,5} = dat(i).z;
                tblDat{i,6} = obj.upChar;
                tblDat{i,7} = obj.dnChar;
                tblDat{i,8} = obj.delChar;
            end
            
            set(obj.utSfTable, 'Data', tblDat);
            obj.resetDisplay();
        end
        
        function tableSelCB(obj,~,evt)
            i = evt.Indices;
            en = 'off';
            
            if ~isempty(i)
                sd = obj.hModel.hDisplay.scanfieldDisplays;
                N = numel(sd);
                i = evt.Indices(1);
                c = evt.Indices(2);
                
                if c > 5
                    
                    if i <= N
                        switch c
                            case 6 %move up
                                if i > 1
                                    s = sd(i - 1);
                                    sd(i-1) = sd(i);
                                    sd(i) = s;
                                    obj.hModel.hDisplay.scanfieldDisplays = sd;
                                end
                                
                            case 7 %move down
                                if i < N
                                    s = sd(i + 1);
                                    sd(i+1) = sd(i);
                                    sd(i) = s;
                                    obj.hModel.hDisplay.scanfieldDisplays = sd;
                                end
                                
                            case 8 %del
                                obj.hModel.hDisplay.scanfieldDisplays(i) = [];
                                
                        end
                    end
                    
                else
                    obj.tblSel = i;
                    
                    if i <= N
                        set(obj.etZ, 'String', num2str(obj.hModel.hDisplay.scanfieldDisplays(i).z));
                    end
                    
                    en = 'on';
                end
            end
            
            set([obj.pmZ.hCtl obj.etZ.hCtl obj.stZ.hCtl], 'enable', en);
        end
        
        function pmZCB(obj,varargin)
            try
                ch = get(obj.pmZ, 'String');
                str = ch{get(obj.pmZ, 'Value')};
                set(obj.etZ, 'String', str);
                obj.selZ = str2double(str);
            catch
            end
        end
        
        function setZ(obj,z)
            obj.utSfTable.Data{obj.tblSel,5} = z;
            obj.tableCB([],[]);
        end
        
        function chgdEnable(obj)
            if obj.hModel.hDisplay.enableScanfieldDisplays
                obj.showDisplay = true;
            end
        end
        
        function addDisp(obj, name, channel, roi, z)
            obj.hModel.hDisplay.scanfieldDisplays(end+1) = struct('enable', true, 'name', name, 'channel', channel, 'roi', roi,'z',z);
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
            obj.setZ(v);
        end
        
        function v = get.selZ(obj)
            try
                v = obj.hModel.hDisplay.scanfieldDisplays(obj.tblSel).z;
            catch
                v = 0;
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
            end
        end
        
        function resetDisplay(obj)
            if ~obj.initialized
                return
            end
            
            persistent sgl
            
            if isempty(sgl)
                try
                    sgl = true;
                    
                    nwDisps = obj.hModel.hDisplay.scanfieldDisplays;
                    obj.disps = nwDisps([nwDisps.enable]);
                    obj.dispIds = 1:numel(nwDisps);
                    obj.dispIds(~[nwDisps.enable]) = [];
                    N = numel(obj.disps);
                    obj.dispUids = zeros(N,1,'uint64');
                    
                    fc = .05*ones(3,1);
                    if ~most.idioms.isValidObj(obj.hDisplayFig)
                        obj.hDisplayFig = figure('Name','Scanfield Display','Visible','off','NumberTitle','off','SizeChangedFcn',@(varargin)obj.resetDisplay(),...
                            'Menubar','none','Tag','sfDisplay','CloseRequestFcn',@obj.figCloseEventHandler,'WindowScrollWheelFcn',@obj.scrollWheelFcn,'Color', fc);
                        
                        obj.hDisplayMenu = handle(uicontextmenu('Parent',obj.hDisplayFig));
                            uimenu('Parent',obj.hDisplayMenu,'Label','Hide From Display','Callback',@obj.mnuHideDisp);
                            uimenu('Parent',obj.hDisplayMenu,'Label','Remove From Display','Callback',@obj.mnuRemoveDisp);
                            uimenu('Parent',obj.hDisplayMenu,'Label','Remove All','Callback',@obj.mnuRemoveAll);
                        
                        try
                            obj.hController.registerGUI(obj.hDisplayFig);
                        catch
                            most.idioms.warn('Could not register display window to be managed by controller.');
                        end
                        
                        delete(obj.hDisplayAxes);
                        obj.hDisplayAxes = matlab.graphics.axis.Axes.empty(1,0);
                    else
                        if numel(obj.hDisplayAxes) > N
                            delete(obj.hDisplayAxes(N+1:end));
                            obj.hDisplayAxes(N+1:end) = [];
                        end
                    end
                    
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
                    
                    %window props
                    set(obj.hDisplayFig,'units','pixels');
                    p = get(obj.hDisplayFig,'position');
                    wndoSz = p([3 4]);
                    wndoAsp = wndoSz(1)/wndoSz(2);
                    gapThickness = 12;
                    
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
                    frW = (wndoSz(1) - gapThickness*(1+cols))/cols;
                    frH = (wndoSz(2) - gapThickness*(1+rows))/rows;
                    
                    fontSz = 11;
                    if obj.hModel.hDisplay.showScanfieldDisplayNames
                        nameH = fontSz*2;
                        textv = 'on';
                    else
                        nameH = 0;
                        textv = 'off';
                    end
                    
                    %apply the desired properties
                    for i = 0:N-1
                        iFrm = mod(i,cols);
                        jFrm = floor(i/cols);
                        frmP = [(gapThickness + (frW+gapThickness)*iFrm) (wndoSz(2) - (frH+gapThickness)*(jFrm+1)) frW (frH-nameH)];
                        
                        if (i+1) > numel(obj.hDisplayAxes) || ~most.idioms.isValidObj(obj.hDisplayAxes(i+1))
                            obj.hDisplayAxes(i+1) = axes('Parent',obj.hDisplayFig,'units','pixels','Position',frmP,'YDir','reverse','XTick',[],...
                                'YTick',[],'CLim',[0 1],'box','off','YTickLabelMode','manual', 'XTickLabelMode','manual','XTickLabel',[],'YTickLabel',[],...
                                'Color',fc,'XLim',[0 1],'YLim',[0 1],'XColor',fc,'YColor',fc,'ButtonDownFcn',@obj.axMouseFunc,'UIContextMenu',obj.hDisplayMenu);
                        else
                            % fix bug where scanfield display randomly stops working
                            obj.hDisplayAxes(i+1).CameraUpVector = [0 -1 0];
                            obj.hDisplayAxes(i+1).Position = frmP;
                        end
                        
                        if ~isnan(obj.asps(i+1))
                            frmAsp = frmP(3) / frmP(4);
                            sfAsp = obj.asps(i+1);
                            
                            if sfAsp > frmAsp
                                W = .99;
                                H = W * frmAsp/sfAsp;
                            else
                                H = .99;
                                W = H * sfAsp/frmAsp;
                            end
                            
                            xs = [(1-W) (1+W)] / 2;
                            ys = [(1-H) (1+H)] / 2;
                            vis = 'on';
                            
                            tp = [frmP(1) (frmP(2)+frmP(4)) frmP(3) nameH];
                            tv = textv;
                        else
                            xs = [0 1];
                            ys = [0 1];
                            vis = 'off';
                            
                            tp = [0 0 0 0];
                            tv = 'off';
                        end
                        
                        %rotate the surf to avoid needing to transpose image
                        xsf = [xs(1) xs(1); xs(2) xs(2)];
                        ysf = [ys(1) ys(2); ys(1) ys(2)];
                        
                        if (i+1) > numel(obj.hSurfs) || ~most.idioms.isValidObj(obj.hSurfs(i+1))
                            %need a new surf
                            obj.hSurfs(i+1) = surface(xsf, ysf, zeros(2), 'Parent',obj.hDisplayAxes(i+1),'Hittest','off','visible',vis,...
                                'FaceColor','texturemap','CData',zeros(2,2,3),'EdgeColor','b','FaceLighting','none');
                        else
                            set(obj.hSurfs(i+1), 'xdata', xsf, 'ydata', ysf, 'visible', vis);
                        end
                        
                        if isempty(obj.disps(i+1).name)
                            txt = sprintf('Roi %d, z=%.2f',obj.disps(i+1).roi,obj.disps(i+1).z);
                        else
                            txt = sprintf('%s (Roi %d, z=%.2f)',obj.disps(i+1).name,obj.disps(i+1).roi,obj.disps(i+1).z);
                        end
                        
                        if (i+1) > numel(obj.hTexts) || ~most.idioms.isValidObj(obj.hTexts(i+1))
                            %need a new surf
                            obj.hTexts(i+1) = uicontrol('parent',obj.hDisplayFig,'style','text','BackgroundColor',fc,'ForegroundColor','w','FontSize',fontSz,'HorizontalAlignment','center','FontWeight','bold');
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
                    obj.updateLuts();
                    sgl = [];
                catch ME
                    sgl = [];
                    ME.rethrow
                end
            end
        end
        
        function updateLuts(obj)
            luts = obj.hModel.hChannels.channelLUT;
            aveFac = obj.hModel.hDisplay.displayRollingAverageFactor;
            
            for i = 1:numel(obj.disps)
                if i <= numel(obj.hDisplayAxes) && most.idioms.isValidObj(obj.hDisplayAxes(i))
                    obj.hDisplayAxes(i).CLim = double(luts{obj.disps(i).channel}) * aveFac;
                end
            end
        end
        
        function displayUpdate(obj)
            try
                if obj.hModel.hDisplay.enableScanfieldDisplays && obj.hModel.hRoiManager.mroiEnable
                    SD = obj.hModel.hDisplay.lastStripeData;
                    
                    N = numel(obj.disps);
                    for i = 1:N
                        try
                            dispi = obj.disps(i);
                            
                            chIdx = ismembc2(dispi.channel, SD.channelNumbers);
                            if ~chIdx
                                % the channel desired for this sf display is not acquired. move on to the next
                                continue;
                            end
                            
                            % allow for some tolerance in the z value
                            tz = SD.roiData{1}.zs;
                            if isempty(SD.roiData) || (abs(dispi.z - tz) > 1E-6)
                                % roi data is empty or this is not acquired on the desired z plane (assumes all roi datas are on the same z plane)
                                continue;
                            else
                                % find the entry in the rolling stripe data buffer
                                RDs = obj.hModel.hDisplay.rollingStripeDataBuffer{tz == obj.hModel.hDisplay.displayZs}{1}.roiData;
                            end
                            
                            Nr = numel(RDs);
                            diuuid = obj.dispUids(i);
                            for j = 1:Nr
                                rd = RDs{j};
                                if rd.hRoi.uuiduint64 == diuuid
                                    set(obj.hSurfs(i),'CData',rd.imageData{chIdx}{1});
                                    continue;
                                end
                            end
                        catch
                        end
                    end
                end
            catch
            end
        end
        
        function scrollWheelFcn(obj, ~, evt)
            hAx = [];
            for i = 1:numel(obj.hDisplayAxes)
                if most.idioms.isValidObj(obj.hDisplayAxes(i)) && mouseIsInAxes(obj.hDisplayAxes(i))
                    hAx = obj.hDisplayAxes(i);
                    break;
                end
            end
            
            if isempty(hAx)
                return;
            end
            
            mv = double(evt.VerticalScrollCount);
            
            % find old range and center
            xlim = get(hAx,'xlim');
            ylim = get(hAx,'ylim');
            rg = xlim(2) - xlim(1);
            ctr = 0.5*[sum(xlim) sum(ylim)];
            
            % calc and constrain new half range
            nrg = min(1,rg*1.2^mv);
            nrg = max(.01,nrg);
            nhrg = nrg/2;
            
            % calc new center based on where mouse is
            pt = axPt(hAx);
            odfc = pt - ctr; %original distance from center
            ndfc = odfc * (nrg/rg); %new distance from center
            nctr = pt - [ndfc(1) ndfc(2)];
            
            % constrain new center
            nctr = min(max(nctr,nhrg),1-nhrg);
            
            % new lims
            xlim = [-nhrg nhrg] + nctr(1);
            ylim = [-nhrg nhrg] + nctr(2);
            set(hAx,'xlim',xlim,'ylim',ylim);
        end
        
        function axMouseFunc(obj,src,evt)
            persistent ax
            persistent ppt
            
            if strcmp(evt.EventName, 'Hit') && (evt.Button == 1)
                ax = src;
                ppt = axPt(ax);
                set(obj.hDisplayFig,'WindowButtonMotionFcn',@obj.axMouseFunc,'WindowButtonUpFcn',@obj.axMouseFunc);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                npt = axPt(ax);
                
                xl = ax.XLim;
                yl = ax.YLim;
                hrg = diff(xl)/2;
                ctr = [mean(xl) mean(yl)];
                ctr = min(max(ctr + ppt - npt,hrg),1-hrg);
                ax.XLim = [-hrg hrg] + ctr(1);
                ax.YLim = [-hrg hrg] + ctr(2);
                
                ppt = axPt(ax);
            else
                set(obj.hDisplayFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function figCloseEventHandler(obj, varargin)
            obj.showDisplay = false;
        end
        
        function mnuHideDisp(obj,~,~)
            id = obj.hDisplayFig.CurrentObject == obj.hDisplayAxes;
            obj.hModel.hDisplay.scanfieldDisplays(obj.dispIds(id)).enable = false;
        end
        
        function mnuRemoveDisp(obj,~,~)
            id = obj.hDisplayFig.CurrentObject == obj.hDisplayAxes;
            obj.hModel.hDisplay.scanfieldDisplays(obj.dispIds(id)) = [];
        end
        
        function mnuRemoveAll(obj,~,~)
            obj.hModel.hDisplay.scanfieldDisplays = [];
        end
    end
end


%% LOCAL
function tf = mouseIsInAxes(hAx)
    coords = axPt(hAx);
    xlim = hAx.XLim;
    ylim = hAx.YLim;
    tf = (coords(1) > xlim(1)) && (coords(1) < xlim(2)) && (coords(2) > ylim(1)) && (coords(2) < ylim(2));
end

function pt = axPt(hAx)
    cp = hAx.CurrentPoint(1,1:2);
    
    % for some reason the point it returns is flipped. correct it
    xl = hAx.XLim;
    yl = hAx.YLim;
    pt = [xl(2) yl(2)] - cp + [xl(1) yl(1)];
end


%--------------------------------------------------------------------------%
% ScanfieldDisplayControls.m                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
