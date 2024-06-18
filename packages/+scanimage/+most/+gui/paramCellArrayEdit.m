classdef paramCellArrayEdit < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hCtl;
        
        hFig;
        hTable;
        pmAdd;
        
        hJA;
        hasL;
        
        % pass through to hCtl
        Value;
        DisplayString;
        ParameterOptions;
        
        Visible;
        Enable;
        Tag;
    end
    
    properties (Hidden)
        userdata;
        callback;
        bindings = {};
        hLiveListener;
        hBindingListeners = {};
        hDelLis;
        
        HeightLimits;
        WidthLimits;
        
        tfMap = containers.Map({true false}, {'on' 'off'});
        delChar = ['<html><table border=0 width=24><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
        keyDown = false;
    end
    
    methods
        function obj = paramCellArrayEdit(varargin)
            ip = most.util.InputParser;
            ip.addOptional('Bindings', {});
            ip.addOptional('WidthLimits',[]);
            ip.addOptional('HeightLimits',[]);
            ip.addOptional('callback',[]);
            ip.addOptional('userdata',[]);
            ip.addOptional('ParameterOptions',[]);
            ip.parse(varargin{:});
            [~,otherPVArgs] = most.util.filterPVArgs(varargin,{'Bindings' 'LiveUpdate' 'WidthLimits' 'HeightLimits' 'Style' 'style' 'ParameterOptions'});
            
            obj.hCtl = uicontrol(otherPVArgs{:},'style','edit','Enable', 'inactive','ButtonDownFcn',@obj.openEditPanel);
            
            set(obj.hCtl, 'userdata', obj);
            
            if ~isempty(ip.Results.WidthLimits)
                lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
                set(obj.hCtl, 'WidthLimits', lms(1:2));
            end
            if ~isempty(ip.Results.HeightLimits)
                lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
                set(obj.hCtl, 'HeightLimits', lms(1:2));
            end
            
            obj.bindings = ip.Results.Bindings;
            obj.userdata = ip.Results.userdata;
            obj.callback = ip.Results.callback;
            obj.ParameterOptions = ip.Results.ParameterOptions;
            obj.hDelLis = addlistener(obj.hCtl,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDelLis);
            most.idioms.safeDeleteObj(obj.hLiveListener);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
            most.idioms.safeDeleteObj(obj.hCtl);
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function set.bindings(obj,v)
            if ~isempty(obj.bindings)
                most.idioms.safeDeleteObj(obj.hBindingListeners);
                obj.hBindingListeners = {};
                obj.bindings = {};
            end
            
            if ~isempty(v)
                if ~iscell(v{1})
                    obj.bindings = {v};
                else
                    obj.bindings = v;
                end
                
                for i = 1:numel(obj.bindings)
                    binding = obj.bindings{i};
                    obj.hBindingListeners{end+1} = binding{1}.addlistener(binding{2},'PostSet',@(varargin)obj.model2view(i));
                    obj.model2view(i);
                end
                
                obj.hBindingListeners = [obj.hBindingListeners{:}];
            end
        end
        
        function set.Value(obj,v)
            obj.Value = v;
            
            if ~isempty(v)
                strs = cellfun(@(p,vl){[p ':' most.util.val2str(vl)]},v(1:2:end),v(2:2:end));
                obj.DisplayString = strjoin(strs,', ');
            else
                obj.DisplayString = '[none]';
            end
            
            obj.updateTable();
        end
        
        function v = get.DisplayString(obj)
            v = obj.hCtl.String;
        end
        
        function set.DisplayString(obj,v)
            obj.hCtl.String = v;
        end
        
        function v = get.Visible(obj)
            v = obj.hCtl.Visible;
        end
        
        function set.Visible(obj,v)
            if islogical(v)
                v = obj.tfMap(v);
            end
            
            obj.hCtl.Visible = v;
        end
        
        function v = get.Tag(obj)
            v = obj.hCtl.Tag;
        end
        
        function set.Tag(obj,v)
            obj.hCtl.Tag = v;
        end
        
        function set.Enable(obj,v)
            switch v
                case {'inactive' 'on'}
                    obj.hCtl.Enable = 'inactive';
                    
                case 'off'
                    obj.hCtl.Enable = 'off';
            end
            
            obj.Enable = v;
        end
        
        function set.HeightLimits(obj,v)
            set(obj.hCtl, 'HeightLimits', v);
        end
        
        function v = get.HeightLimits(obj)
            v = get(obj.hCtl, 'HeightLimits');
        end
        
        function set.WidthLimits(obj,v)
            set(obj.hCtl, 'WidthLimits', v);
        end
        
        function v = get.WidthLimits(obj)
            v = get(obj.hCtl, 'WidthLimits');
        end
        
        function set.ParameterOptions(obj,v)
            obj.ParameterOptions = v;
            
            if most.idioms.isValidObj(obj.hTable)
                if isempty(v)
                    obj.pmAdd.Visible = 'off';
                else
                    obj.pmAdd.String = [{'Add Parameter...'}; v(:)];
                    obj.pmAdd.Value = 1;
                    obj.pmAdd.Visible = 'on';
                end
            end
        end
    end
    
    methods (Hidden)
        function tableEdit(obj,varargin)
            d = obj.hTable.Data(:,1:2);
            
            ps = d(:,1);
            vs = d(:,2);
            
            % delete rows where both name and value is empty
            nem = cellfun(@(s)isempty(strtrim(s)),ps);
            vem = cellfun(@isempty,vs);
            bem = logical(nem.*vem);
            ps(bem) = [];
            vs(bem) = [];
            nem(bem) = [];
            vem(bem) = [];
            
            % fill in empty names
            ps(nem) = {'newParam'};
            
            % fill in empty vals
            vs(vem) = {[]};
            
            % eval string vals
            vem = cellfun(@ischar,vs);
            vs(vem) = cellfun(@evalpr,vs(vem),'UniformOutput',false);
            
            
            obj.Value = reshape([ps';vs'],1,[]);
            
            for i = 1:numel(obj.bindings)
                binding = obj.bindings{i};
                binding{1}.(binding{2}) = obj.Value;
            end
            
            if ~isempty(obj.callback)
                obj.callback(obj);
            end
        end
        
        function model2view(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.model2view(i);
                end
            else
                binding = obj.bindings{bindingIdx};
                
                obj.Value = binding{1}.(binding{2});
            end
        end
        
        function set(obj,prop,val)
            if ismember(lower(prop), {'callback' 'userdata'})
                obj.(lower(prop)) = val;
            else
                set(obj.hCtl,prop,val);
            end
        end
        
        function v = get(obj,prop)
            if ismember(lower(prop), {'callback' 'userdata'})
                v = obj.(lower(prop));
            else
                v = get(obj.hCtl,prop);
            end
        end
        
        function hL = addlistener(obj,varargin)
            hL = addlistener(obj.hCtl,varargin{:});
        end
        
        function openEditPanel(obj,varargin)
            hParentFig = gcbf;
            pu = hParentFig.Units;
            hParentFig.Units = 'pixels';
            p = hParentFig.Position;
            hParentFig.Units = pu;
            
            if most.idioms.isValidObj(obj.hFig)
                % center the figure
                obj.hFig.Units = 'pixels';
                obj.hFig.Position(1:2) = p(1:2) + p(3:4)*.5 - obj.hFig.Position(3:4)*.5;
                obj.updateTable(true);
                
                figure(obj.hFig);
                drawnow();
                obj.hJA.grabFocus();
            else
                sz = [300 150];
                obj.hFig = figure('numbertitle','off','name','Edit Parameters','menubar','none','units','pixels',...
                    'position',[(p(1:2) + p(3:4)*.5 - sz*.5) sz],'CloseRequestFcn',@obj.close,'visible','off');
                
                flw = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown','margin',8);
                obj.hTable = uitable('Parent',flw,...
                    'ColumnName', {'Parameter Name' 'Parameter Value' ''}, ...
                    'Data',{'' ''},...
                    'ColumnFormat', {'char' 'char' 'char'}, ...
                    'ColumnEditable', [true true false], ...
                    'ColumnWidth', {120 120 24}, ...
                    'RowName', [], ...
                    'RowStriping', 'on', ...
                    'KeyPressFcn',@obj.KeyFcn,...
                    'KeyReleaseFcn',@obj.KeyFcn,...
                    'CellSelectionCallback',@obj.tableSelect,...
                    'CellEditCallback', @obj.tableEdit);
                
                bflw = most.gui.uiflowcontainer('Parent',flw,'FlowDirection','LeftToRight','margin',0.00001,'HeightLimits',26);
                most.gui.uicontrol('Parent',bflw,'string','Done','WidthLimits',60,'callback',@obj.close);
                
                bflw = most.gui.uiflowcontainer('Parent',bflw,'FlowDirection','RightToLeft','margin',0.00001);
                obj.pmAdd = most.gui.uicontrol('Parent',bflw,'WidthLimits',200,'callback',@obj.addParam,'Visible','off','style','popupmenu');
                obj.ParameterOptions = obj.ParameterOptions;
                
                obj.updateTable(true);
                figure(obj.hFig);
                
                % detect loss of focus
                drawnow();
                warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
                obj.hJA = obj.hFig.JavaFrame.getAxisComponent;
                set(obj.hJA,'FocusLostCallback',@obj.lostFocus);
                obj.hJA.grabFocus();
            end
        end
        
        function addParam(obj,varargin)
            op = strsplit(obj.ParameterOptions{obj.pmAdd.Value-1},'(');
            obj.hTable.Data{end+1,1} = strtrim(op{1});
            obj.pmAdd.Value = 1;
            obj.tableEdit();
        end
        
        function lostFocus(obj,~,evt)
            oc = evt.getOppositeComponent();
            if ~isempty(oc) && obj.hJA.isAncestorOf(oc)
                % the new focused object is a child of the figure. make
                % sure we have a listener on it
                set(oc,'FocusLostCallback',@obj.lostFocus);
            else
                obj.hFig.Visible = 'off';
            end
        end
        
        function close(obj,varargin)
            obj.hFig.Visible = 'off';
        end
        
        function updateTable(obj,force)
            if ((nargin > 1) && force) || (most.idioms.isValidObj(obj.hFig) && strcmp(obj.hFig.Visible,'on'))
                ps = obj.Value(1:2:end)';
                vs = cellfun(@tostr,obj.Value(2:2:end)','UniformOutput',false);
                
                dat = [ps vs];
                dat(:,end+1) = {obj.delChar};
                dat(end+1,:) = {'' '' ''};
                obj.hTable.Data = dat;
            end
        end
        
        function tableSelect(obj,~,evt)
            if size(evt.Indices,1) == 1 && evt.Indices(2) == 3
                if obj.keyDown
                    d = obj.hTable.Data;
                    obj.hTable.Data = {};
                    obj.hTable.Data = d;
                else
                    obj.hTable.Data(evt.Indices(1),:) = [];
                    obj.tableEdit();
                end
            end
        end
        
        function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
        end
    end
end

function v = evalpr(s)
    s = strtrim(s);
    if isempty(s)
        v = [];
    else
        try
            v = eval(s);
        catch
            v = eval(['''' s '''']);
        end
    end
end

function s = tostr(v)
    if isempty(v)
        s = '';
    else
        s = most.util.val2str(v);
    end
end



%--------------------------------------------------------------------------%
% paramCellArrayEdit.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
