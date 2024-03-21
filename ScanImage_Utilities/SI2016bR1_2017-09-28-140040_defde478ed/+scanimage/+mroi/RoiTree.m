classdef RoiTree < matlab.mixin.Copyable
    %% Parent class of RoiGroup, Roi and ScanField
    properties (SetAccess = immutable)
        uuid;           % string: human readable uuid
    end
    
    properties (SetAccess = immutable,Hidden)
        uuiduint64;     % uint64: represents the first 8 bytes from the uuid. should still be unique for all practical purposes
    end
    
    properties (Hidden, SetAccess = private)
        statusId = uint32(0);  % random number that increments when obj.fireChangedEvent() is executed; used to detect a change in gui
    end
    
    properties (SetObservable,Dependent)
        name            % [string] description of roi. if unset, first 8 characters of uuid are returned
    end
    
    properties (Hidden, SetAccess = protected)
        name_ = ''; 
    end
    
    %% Events
    events (NotifyAccess = protected)
        changed;
    end
    
    %% lifecycle
    methods
        function obj = RoiTree()
            [obj.uuiduint64,obj.uuid] = most.util.generateUUIDuint64();
            
            obj.updateStatusId();
            scanimage.mroi.RoiTree.objectcount(class(obj),+1);
        end
        
        function delete(obj)
            scanimage.mroi.RoiTree.objectcount(class(obj),-1);
        end
    end
    
    % only purpose is to overload the addlistener method to prevent reference leaks
    methods
        function lh = addlistener(varargin)
            lh = most.idioms.addweaklistener(varargin{:});
        end
        
        function s = saveobj(obj,s)
            if nargin < 2 || isempty(s)
                s = struct();
            end
            s.ver = 1;
            s.classname = class(obj);
            s.name = obj.name_;
        end
        
        function obj = loadobj(obj,s)
            if nargin < 2
                error('Missing paramter in loadobj: Cannot create new object within RoiTree');
            end
            
            if ~isfield(s,'ver')
                if isfield(s,'name_') % for backward compatibility
                    obj.name_ = s.name_;
                else
                    obj.name=s.name;
                end
            else
                % at this time the only version is v=1;
                obj.name = s.name;
            end
        end
    end
    
    methods (Hidden)
        function obj = copyobj(obj,other)
            obj.name_ = other.name_;
        end
    end
        
    methods (Access = protected)
        function cpObj = copyElement(obj,cpObj)
            assert(~isempty(cpObj) && isvalid(cpObj));
            
            if ~isempty(obj.name_)
                ctr = regexpi(obj.name_,'[0-9]+$','match','once');
                if ~isempty(ctr)
                    newCtr = sprintf(['%0' int2str(length(ctr)) 'd'],str2double(ctr)+1);
                    newName = [obj.name_(1:end-length(ctr)) newCtr];
                    cpObj.name_ = newName;
                else
                    cpObj.name_ = [obj.name_ '-01'];
                end
            end
        end
        
        function fireChangedEvent(obj,varargin)
            obj.updateStatusId();
            
            if length(varargin) > 2
                % varargin is typcially {src,evt}
                evt = varargin{2};
                notify(obj,'changed',evt);
            else
                notify(obj,'changed');
            end
        end
        
        function updateStatusId(obj)
            finished = false;
            while ~finished
                c = class(obj.statusId);
                newId = randi([intmin(c) intmax(c)],c);
                finished = newId ~= obj.statusId; % make sure the number actually changed
            end
            obj.statusId = newId;
        end
    end
    
    methods
        function set.name(obj,val)
            if isempty(val)
                val = '';
            else
                validateattributes(val,{'char'},{'row'});
            end
            
            obj.name_ = val;
            notify(obj,'changed');
        end
        
        function val = get.name(obj)
            val = obj.name_;
            if isempty(obj.name_) && ~isempty(obj.uuid)
               val = obj.uuid(1:8);
            end            
        end        
    end
    
    methods (Static)
        function val = objectcount(classname,inc)
            persistent count
            if isempty(count)
                count = struct();
            end
            
            if nargin < 1 || isempty(classname)
                val = count;
                return
            end
            
            classname = regexprep(classname,'\.','_');
            if ~isfield(count,classname)
                count.(classname) = 0;
            end
            
            if nargin < 2 || isempty(inc)
                inc = 0;
            end
            
            count.(classname) = count.(classname) + inc;
        end
    end
end

%--------------------------------------------------------------------------%
% RoiTree.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
