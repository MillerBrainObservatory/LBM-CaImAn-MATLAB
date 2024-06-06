classdef uicontrol < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hCtl;
        
        % pass through to hCtl
        Value;
        String;
        Visible;
        Enable;
        Style;
    end
    
    properties (Hidden)
        userdata;
        callback;
        bindings = {};
        hLiveListener;
        hBindingListeners = {};
        ctlStyle;
        hDelLis;
        
        HeightLimits;
        WidthLimits;
        
        tfMap = containers.Map({true false}, {'on' 'off'});
    end
    
    methods
        function obj = uicontrol(varargin)
            ip = most.util.InputParser;
            ip.addOptional('Bindings', {});
            ip.addOptional('LiveUpdate',false);
            ip.parse(varargin{:});
            [~,otherPVArgs] = most.util.filterPVArgs(varargin,{'Bindings' 'LiveUpdate'});
            
            obj.hCtl = uicontrol(otherPVArgs{:});
            obj.ctlStyle = get(obj.hCtl,'style');
            
            obj.userdata = get(obj.hCtl, 'userdata');
            obj.callback = get(obj.hCtl, 'callback');
            set(obj.hCtl, 'userdata', obj);
            set(obj.hCtl, 'callback', @obj.ctlCallback);
            
            obj.bindings = ip.Results.Bindings;
            
            if ip.Results.LiveUpdate
                switch obj.ctlStyle
                    case 'slider'
                        obj.hLiveListener = addlistener(obj.hCtl,'Value','PostSet',@obj.ctlCallback);
                        
                    otherwise
                        most.idioms.warn('Live update not supported for control type ''%s''.', obj.ctlStyle);
                end
            end
            
            obj.hDelLis = addlistener(obj.hCtl,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDelLis);
            most.idioms.safeDeleteObj(obj.hLiveListener);
            most.idioms.safeDeleteObj(obj.hBindingListeners);
            most.idioms.safeDeleteObj(obj.hCtl);
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
        
        function v = get.Value(obj)
            v = obj.hCtl.Value;
        end
        
        function set.Value(obj,v)
            obj.hCtl.Value = v;
        end
        
        function v = get.String(obj)
            v = obj.hCtl.String;
        end
        
        function set.String(obj,v)
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
        
        function v = get.Enable(obj)
            v = obj.hCtl.Enable;
        end
        
        function set.Enable(obj,v)
            if islogical(v)
                v = obj.tfMap(v);
            end
            
            obj.hCtl.Enable = v;
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
        
        function set.Style(obj,v)
            obj.hCtl.Style = v;
        end
        
        function v = get.Style(obj)
            v = obj.hCtl.Style;
        end
    end
    
    methods (Hidden)
        function ctlCallback(obj,varargin)
            if ~isempty(obj.bindings)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            end
            
            if ~isempty(obj.callback)
                obj.callback(varargin{:});
            end
        end
        
        function view2model(obj,bindingIdx)
            if nargin < 2 || isempty(bindingIdx)
                for i = 1:numel(obj.bindings)
                    obj.view2model(i);
                end
            else
                binding = obj.bindings{bindingIdx};

                switch obj.ctlStyle
                    case {'edit'}
                        vt = 'string';
                        propVal = get(obj.hCtl,'string');
                        propStr = propVal;
                    case {'slider' 'checkbox' 'togglebutton' 'radiobutton'}
                        vt = 'value';
                        propVal = get(obj.hCtl,'Value');
                    case 'listbox'
                        vt = 'string';
                        items = get(obj.hCtl,'String');
                        propVal = items(get(obj.hCtl,'Value')); %Encode as cell array of selected options
                        propStr = propVal;
                        if ~isempty(propVal)
                            propChoice = propVal{1}; %Encode as string of the one-and-only selected option
                        else
                            propChoice = '';
                        end
                    case 'popupmenu'
                        vt = 'string';
                        propVal = get(obj.hCtl,'Value');
                        propStr = get(obj.hCtl,'String');
                        propChoice = propStr{propVal}; %Encode as string of the one-and-only selected option
                    otherwise
                        error('Binding control of type ''%s'' is not supported', obj.ctlStyle);
                end

                if strcmpi(binding{3}, 'value')
                    if isnumeric(propVal);
                        if numel(binding) > 4 && strcmpi(binding{5},'scaling')
                            scl = binding{6};
                        else
                            scl = 1;
                        end
                        
                        binding{1}.(binding{2}) = propVal/scl;
                    elseif strcmp(vt, 'string');
                        if numel(binding) > 4 && strcmpi(binding{5},'scaling')
                            scl = binding{6};
                        else
                            scl = 1;
                        end
                        
                        if numel(binding) > 3
                            switch binding{4}
                                case '%f'
                                    binding{1}.(binding{2}) = str2double_(propVal)/scl;
                                case '%h'
                                    binding{1}.(binding{2}) = hex2num(propVal);
                                otherwise
                                    error('Unsupported conversion format');
                            end
                        else
                            binding{1}.(binding{2}) = str2double_(propVal)/scl;
                        end
                    end

                elseif strcmpi(binding{3}, 'string')
                    if strcmpi(vt, 'string');
                        binding{1}.(binding{2}) = propVal;
                    end

                elseif strcmpi(binding{3}, 'choice')
                    if exist('propChoice');
                        binding{1}.(binding{2}) = propChoice;
                    end
                elseif strcmpi(binding{3}, 'match')
                    if numel(binding) > 3
                        matchVal = binding{4};
                    else
                        matchVal = obj.hCtl.String;
                    end
                    binding{1}.(binding{2}) = matchVal;
                end
            end
            
            function v = str2double_(v)
                if ~isempty(regexpi(v,'^[0-9\s\.;:]*$'))
                    v = eval(v);
                else
                    v = str2double(v);
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
                    return;
                end
                
                switch obj.ctlStyle
                    case {'edit'}
                        if strcmpi(binding{3}, 'value')
                            if numel(binding) > 4 && strcmpi(binding{5},'scaling')
                                scl = binding{6};
                            else
                                scl = 1;
                            end
                            
                            propVal = binding{1}.(binding{2}) * scl;
                            if isempty(propVal)
                                s = '';
                            else
                                s = mat2str(propVal);
                            end
                            set(obj.hCtl, 'String', s);
                            
                        elseif strcmpi(binding{3}, 'String')
                            set(obj.hCtl, 'String', binding{1}.(binding{2}));
                            
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    case {'slider' 'checkbox'}
                        if strcmpi(binding{3}, 'value')
                            set(obj.hCtl, 'Value', binding{1}.(binding{2}));
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    case {'togglebutton' 'radiobutton'}
                        if strcmpi(binding{3}, 'value')
                            set(obj.hCtl, 'Value', binding{1}.(binding{2}));
                            
                        elseif strcmpi(binding{3}, 'String')
                            set(obj.hCtl, 'String', binding{1}.(binding{2}));
                        elseif strcmpi(binding{3}, 'match')
                            if numel(binding) > 3
                                matchVal = binding{4};
                            else
                                matchVal = obj.hCtl.String;
                            end
                            
                            if ischar(matchVal)
                                obj.hCtl.Value = strcmp(binding{1}.(binding{2}),matchVal);
                            else
                                obj.hCtl.Value = binding{1}.(binding{2}) == matchVal;
                            end
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    case {'popupmenu' 'listbox'}
                        if strcmpi(binding{3}, 'Choice')
                            [tf,v] = ismember(binding{1}.(binding{2}), get(obj.hCtl,'String'));
                            if tf
                                set(obj.hCtl, 'Value', v);
                            end
                            
                        elseif strcmpi(binding{3}, 'Choices')
                            v = binding{1}.(binding{2});
                            if ~iscell(v)
                                v = num2cell(v);
                            end
                            set(obj.hCtl, 'String', v);
                            
                        elseif strcmpi(binding{3}, 'Value')
                            set(obj.hCtl, 'Value', binding{1}.(binding{2}));
                            
                        elseif strcmpi(binding{3}, 'String')
                            set(obj.hCtl, 'String', binding{1}.(binding{2}));
                            
                        else
                            error('Binding type ''%s'' unsupported for control of type ''%s''', binding{3}, obj.ctlStyle);
                        end
                        
                    otherwise
                        error('Binding control of type ''%s'' is not supported', obj.ctlStyle);
                end
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
    end
end



%--------------------------------------------------------------------------%
% uicontrol.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
