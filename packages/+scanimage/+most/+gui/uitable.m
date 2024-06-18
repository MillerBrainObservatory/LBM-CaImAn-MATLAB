classdef uitable < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        UserData;
        CellEditCallback;
        CellSelectionCallback;
        DeleteFcn;
        Data;
        selection = [];
        Visible;
    end
    
    properties (Hidden)
        hPnl;
        hCtl;
        hScrl;
        hBindingListener;
        
        data_;
        numRows = 0;
        numVisibleRows;
        maxTopRow;
        firstRowIdx = 1;
        needSizeCalc = true;
    end
    
    methods
        function obj = uitable(varargin)
            obj.hCtl = uitable(varargin{:});
            obj.hPnl = uipanel('Parent',obj.hCtl.Parent,'Units',obj.hCtl.Units,'Position',obj.hCtl.Position,'BorderType','none');
            obj.hCtl.Parent = obj.hPnl;
            obj.hCtl.Units = 'normalized';
            obj.hCtl.Position = [0 0 1 1];
            
            obj.hScrl = most.gui.uicontrol('Parent',obj.hPnl,'style','slider','callback',@obj.scrlCB,'LiveUpdate',true);
            
            obj.hPnl.SizeChangedFcn = @obj.szCallback;
            obj.szCallback();
            
            obj.UserData = get(obj.hCtl, 'userdata');
            obj.CellEditCallback = get(obj.hCtl, 'CellEditCallback');
            obj.CellSelectionCallback = get(obj.hCtl, 'CellSelectionCallback');
            obj.DeleteFcn = get(obj.hCtl, 'DeleteFcn');
            set(obj.hCtl, 'userdata', obj);
            set(obj.hCtl, 'CellEditCallback', @obj.editCallback);
            set(obj.hCtl, 'CellSelectionCallback', @obj.selCallback);
            set(obj.hCtl, 'DeleteFcn', @obj.delFcn);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hBindingListener);
        end
        
        function v = get.Data(obj)
            v = obj.data_;
        end
        
        function set.Data(obj, val)
            obj.needSizeCalc = true;
            obj.data_ = val;
            obj.numRows = size(val,1);
            obj.maxTopRow = max(1,obj.numRows - obj.numVisibleRows + 1);
            obj.firstRowIdx = min(obj.firstRowIdx, obj.maxTopRow);
        end
        
        function set.firstRowIdx(obj,v)
            obj.firstRowIdx = v;
            obj.redrawTable();
        end
        
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj, val)
            obj.hPnl.Visible = val;
        end
    end
    
    methods (Hidden)
        function editCallback(obj,varargin)
            % update obj.data
            nd = min(obj.numRows, obj.firstRowIdx+obj.numVisibleRows-1);
            obj.data_(obj.firstRowIdx:nd,:) = obj.hCtl.Data;
            
            if ~isempty(obj.CellEditCallback)
                obj.CellEditCallback(varargin{:});
            end
        end
        
        function selCallback(obj,hTbl,data)
            % update cell selectionid
            if numel(data.Indices) == 1
                obj.selection = data.Indices + [obj.firstRowIdx-1 0];
                
                if ~isempty(obj.CellSelectionCallback)
                    evt.Indices = obj.selection;
                    evt.Source = obj;
                    evt.EventName = 'CellSelection';
                    obj.CellSelectionCallback(hTbl,evt);
                end
            else
                obj.selection = [];
            end
        end
        
        function szCallback(obj,varargin)
            obj.hCtl.Units = 'pixels';
            obj.numVisibleRows = max(1,floor((obj.hCtl.Position(4) - 22) / 18));
            obj.needSizeCalc = true;
            obj.redrawTable();
            
            obj.hPnl.Units = 'pixels';
            obj.hScrl.hCtl.Units = 'pixels';
            obj.hCtl.Units = 'normalized';
            p = obj.hPnl.Position;
            w = 18;
            obj.hScrl.hCtl.Position = [p(3)-w+1 1 w p(4)-1];
            obj.hCtl.Position = [0 0 1 1];
        end
        
        function scrlCB(obj,varargin)
            obj.firstRowIdx = floor(obj.maxTopRow-obj.hScrl.hCtl.Value+1);
            obj.hScrl.hCtl.Value = obj.maxTopRow - obj.firstRowIdx + 1;
        end
        
        function delFcn(obj,varargin)
            if ~isempty(obj.DeleteFcn)
                obj.DeleteFcn(varargin{:});
            end
            delete(obj);
        end
        
        function redrawTable(obj)
            if ~isempty(obj.data_)
                nd = min(obj.numRows, obj.firstRowIdx+obj.numVisibleRows-1);
                obj.hCtl.Data = obj.data_(obj.firstRowIdx:nd,:);
                
                if obj.needSizeCalc
                    if size(obj.Data,1) > obj.numVisibleRows
                        obj.hScrl.hCtl.Min = 1;
                        obj.hScrl.hCtl.Max = obj.maxTopRow;
                        a = obj.numVisibleRows / (obj.numRows - obj.numVisibleRows);
                        obj.hScrl.hCtl.SliderStep = [1/(obj.maxTopRow-1) a];
                        obj.hScrl.hCtl.Value = obj.maxTopRow - obj.firstRowIdx + 1;
                        obj.hScrl.hCtl.Enable = 'on';
                    else
                        obj.hScrl.hCtl.Enable = 'off';
                    end
                    obj.needSizeCalc = false;
                end
            else
                obj.hCtl.Data = [];
                obj.hScrl.hCtl.Enable = 'off';
            end
        end
        
        function set(obj,prop,val)
            switch(lower(prop))
                case 'Celleditcallback'
                    obj.cellEditCallback = val;
                    
                case 'Cellselectioncallback'
                    obj.cellSelectionCallback = val;
                    
                case 'DeleteFcn'
                    obj.DeleteFcn = val;
                    
                case 'userdata'
                    obj.UserData = val;
                    
                case 'data'
                    obj.Data = val;
                    
                case {'visible' 'position'}
                    set(obj.hPnl,prop,val);
                    
                otherwise
                    set(obj.hCtl,prop,val);
            end
        end
        
        function v = get(obj,prop)
            switch(lower(prop))
                case 'Celleditcallback'
                    v = obj.cellEditCallback;
                    
                case 'Cellselectioncallback'
                    v = obj.cellSelectionCallback;
                    
                case 'DeleteFcn'
                    v = obj.DeleteFcn;
                    
                case 'userdata'
                    v = obj.UserData;
                    
                case 'data'
                    v = obj.Data;
                    
                case {'visible' 'position'}
                    v = get(obj.hPnl,prop);
                    
                otherwise
                    v = get(obj.hCtl,prop);
            end
        end
        
        function hL = addlistener(obj,varargin)
            hL = addlistener(obj.hCtl,varargin{:});
        end
    end
end



%--------------------------------------------------------------------------%
% uitable.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
