classdef RoiTree < matlab.mixin.Copyable & most.util.Uuid
    %% Parent class of RoiGroup, Roi and ScanField    
    properties (Hidden, SetAccess = private)
        statusId = uint32(0);  % random number that increments when obj.fireChangedEvent() is executed; used to detect a change in gui
    end
    
    properties (SetObservable,Dependent)
        name            % [string] description of roi. if unset, first 8 characters of uuid are returned
    end
    
    properties (Hidden, SetAccess = protected)
        name_ = ''; 
    end
    
    properties (Hidden)
        UserData = [];  % used to store additional data
    end
    
    %% Events
    events (NotifyAccess = protected)
        changed;
    end
    
    %% lifecycle
    methods
        function obj = RoiTree()            
            obj.updateStatusId();
            updateObjectCount(obj,'add');
        end
        
        function delete(obj)
            updateObjectCount(obj,'remove');
        end
    end
    
    methods
        function s = saveobj(obj,s)
            if nargin < 2 || isempty(s)
                s = struct();
            end
            s.ver = 1;
            s.classname = class(obj);
            s.name = obj.name_;
            
            % added with ScanImage 2018b
            s.UserData = obj.UserData;
            s.roiUuid = obj.uuid;
            s.roiUuiduint64 = obj.uuiduint64;
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
                if isfield(s,'UserData')
                    obj.UserData = s.UserData;
                end
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
        
        function fireChangedEvent(obj,evtData)
            obj.updateStatusId();
            
            if nargin < 2
                notify(obj,'changed');
            else
                notify(obj,'changed',evtData);
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
            updateObjectCount(obj,'update');
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
        function val = objectcount()
            val = updateObjectCount();
        end
    end
    
    methods (Abstract)
        tf = isequalish(objA, objB);
        h = hashgeometry(obj);
    end
end

%% Local functions
function val = updateObjectCount(obj,action)
    persistent count
    if isempty(count)
        count = struct();
    end

    if nargin < 1 || isempty(obj)
        val = count;
        return
    end

    classname = regexprep(class(obj),'\.','_');
    if ~isfield(count,classname)
        count.(classname) = 0;
        count.([classname '_uuids']) = {};
        count.([classname '_names']) = {};
    end

    mask = strcmpi(count.([classname '_uuids']),obj.uuid);
    
    switch action
        case {'add','update'}
            if any(mask)
                updateObjectCount(obj,'remove');
            end
            
            count.(classname) = count.(classname) + 1;
            count.([classname '_uuids']){end+1} = obj.uuid;
            count.([classname '_names']){end+1} = obj.name;
        case 'remove'
            if any(mask)
                count.(classname) = count.(classname) - 1;
                count.([classname '_uuids'])(mask) = [];
                count.([classname '_names'])(mask) = [];
            end
    end
end

%--------------------------------------------------------------------------%
% RoiTree.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
