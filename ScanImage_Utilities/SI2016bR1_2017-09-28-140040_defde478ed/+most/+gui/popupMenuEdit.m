classdef popupMenuEdit < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hPopup;
        hEdit;
        hPanel;
        
        % pass through to hCtl
        string;
        selectionIdx;
        choices;
        visible;
        enable;
        callback;
        position;
        tooltipString;
        validationFunc; % [result,newString,errMsg] = validationFunc(newString,oldString);
                        % result: 0=OK, 1=WARN, 2=ERROR
    end
    
    properties (Hidden)
        bindings = {};
        hBindingListeners = {};
        hDelLis;
        oldString = '';
        forceSet = false;
        tooltipStringRaw = '';
        currErrMsg = '';
    end
    
    methods
        function obj = popupMenuEdit(varargin)
            ip = most.util.InputParser;
            ip.addRequiredParam('position');
            ip.addOptional('bindings', {});
            ip.addOptional('callback', {});
            ip.addOptional('horizontalalignment', 'left');
            ip.addOptional('tooltipstring', '');
            ip.addOptional('validationFunc', {});
            ip.parse(varargin{:});
            otherPVArgs = most.util.structPV2cellPV(ip.Unmatched);
            
            obj.hPanel = uipanel(otherPVArgs{:},'bordertype','none','sizechangedfcn',@obj.sizeChg);
            obj.hPopup = uicontrol('parent',obj.hPanel,'style','popupmenu','string',{' '}, 'callback', @obj.ctlCallback);
            obj.hEdit = uicontrol('parent',obj.hPanel,'style','edit', 'callback', @obj.ctlCallback,'horizontalalignment',ip.Results.horizontalalignment);
            obj.position = ip.Results.position;
            
            set(obj.hPanel, 'userdata', obj);
            set(obj.hPopup, 'userdata', obj);
            set(obj.hEdit, 'userdata', obj);
            
            obj.callback = ip.Results.callback;
            obj.bindings = ip.Results.bindings;
            obj.validationFunc = ip.Results.validationFunc;
            obj.tooltipString = ip.Results.tooltipstring;
            
            obj.hDelLis = addlistener(obj.hPanel,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDelLis);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
            most.idioms.safeDeleteObj(obj.hPopup);
            most.idioms.safeDeleteObj(obj.hEdit);
            most.idioms.safeDeleteObj(obj.hPanel);
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
        
        function v = get.visible(obj)
            v = obj.hPanel.Visible;
        end
        
        function set.visible(obj,v)
            obj.hPanel.Visible = v;
        end
        
        function v = get.enable(obj)
            v = obj.hEdit.Enable;
        end
        
        function set.enable(obj,v)
            obj.hEdit.Enable = v;
            obj.hPopup.Enable = v;
        end
        
        function v = get.tooltipString(obj)
            v = obj.tooltipStringRaw;
        end
        
        function set.tooltipString(obj,v)
            obj.tooltipStringRaw = v;
            obj.updateTooltip();
        end
        
        function v = get.position(obj)
            obj.hPanel.Units = 'pixels';
            v = obj.hPanel.Position;
        end
        
        function set.position(obj,v)
            obj.hPanel.Units = 'pixels';
            obj.hPanel.Position = v;
        end
        
        function set.string(obj,v)
            % check validation
            if ~isempty(obj.validationFunc)
                [lvl,v,obj.currErrMsg] = obj.validationFunc(v,obj.oldString);
                if ~strcmp(v,obj.oldString)
                    switch lvl
                        case 0
                            obj.hEdit.BackgroundColor = [1 1 1];
                            
                        case 1
                            obj.hEdit.BackgroundColor = [1 1 .6];
                            
                        case 2
                            obj.hEdit.BackgroundColor = [1 .6 .6];
                    end
                end
                obj.updateTooltip();
            end
            
            obj.hEdit.String = v;
            obj.oldString = v;
            
            [tf,i] = ismember(v,obj.choices);
            if tf
                obj.hPopup.Value = i;
            end
        end
        
        function v = get.string(obj)
            v = obj.hEdit.String;
        end
        
        function set.selectionIdx(~,~)
            error('Cannot set by index. Use string instead.');
        end
        
        function v = get.selectionIdx(obj)
            [tf,v] = ismember(obj.string,obj.choices);
            if ~tf
                v = nan;
            end
        end
        
        function set.choices(obj,v)
            if isempty(v)
                obj.hPopup.String = {''};
            else
                obj.hPopup.String = v;
            end
            
            chcs = obj.choices;
            [tf,i] = ismember(obj.string,chcs);
            if tf
                obj.hPopup.Value = i;
            elseif obj.hPopup.Value > numel(chcs)
                obj.hPopup.Value = 1;
            end
        end
        
        function v = get.choices(obj)
            v = obj.hPopup.String;
            
            if ~iscell(v)
                v = cellstr(v);
            end
            
            if numel(v) == 1 && isempty(v{1})
                v = {};
            end
        end
    end
    
    methods (Hidden)
        function sizeChg(obj,varargin)
            if most.idioms.isValidObj(obj.hPopup)
                obj.hPanel.Units = 'pixels';
                obj.hPopup.Units = 'pixels';
                obj.hEdit.Units = 'pixels';
                
                v = obj.hPanel.Position;
                obj.hPopup.Position = [1 1 v(3) 22];
                obj.hEdit.Position = [1 1 max(1,v(3)-16) v(4)];
            end
        end
        
        function ctlCallback(obj,src,~)
            % propegate change between edit and popup
            if src == obj.hPopup
                nwStr = obj.choices{src.Value};
            else
                nwStr = obj.string;
            end
            
            obj.string = nwStr;
            
            % evaluate bindings
            if ~isempty(obj.bindings)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            end
            
            % fire user defined callback
            if ~isempty(obj.callback)
                obj.callback(obj);
            end
        end
        
        function view2model(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            else
                binding = obj.bindings{bindingIdx};

                if strcmpi(binding{3}, 'string')
                    binding{1}.(binding{2}) = obj.string;
                end
            end
        end
        
        function model2view(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.model2view(i);
                end
            else
                binding = obj.bindings{bindingIdx};
                
                if strcmpi(binding{3}, 'callback')
                    feval(binding{4},obj.hCtl);
                elseif strcmpi(binding{3}, 'string')
                    obj.forceSet = true;
                    try
                        obj.string = binding{1}.(binding{2});
                        obj.forceSet = false;
                    catch ME
                        obj.forceSet = false;
                        ME.rethrow();
                    end
                elseif strcmpi(binding{3}, 'choices')
                    obj.choices = binding{1}.(binding{2});
                end
            end
        end
        
        function updateTooltip(obj)
            v = obj.tooltipStringRaw;
            if ~isempty(obj.currErrMsg)
                if isempty(v)
                    v = obj.currErrMsg;
                else
                    v = sprintf('%s\n%s',v,obj.currErrMsg);
                end
            end
            
            obj.hEdit.TooltipString = v;
            obj.hPopup.TooltipString = v;
        end
        
        function set(obj,prop,val)
            set(obj.hPanel,prop,val);
        end
        
        function v = get(obj,prop)
            v = get(obj.hPanel,prop);
        end
        
        function hL = addlistener(obj,varargin)
            hL = addlistener(obj.hPanel,varargin{:});
        end
    end
end



%--------------------------------------------------------------------------%
% popupMenuEdit.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
