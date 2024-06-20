classdef CycleDataGroup < handle & matlab.mixin.Copyable
%% CYCLEDATA Data structure for the relevant "iteration" information for cycle-mode
%   An iteration corresponds to a cycle iteration (an entry for each loop operation)
% 
    properties(SetObservable)
        name = '';

        goHomeAtCycleEndEnabled     % Logical. 
        autoResetModeEnabled        % Logical. If enabled, the Cycles Done and Cycle Iterations Done values are reset to 0, upon completion or abort of each Cycle-enabled LOOP acquisition. If disabled,
        restoreOriginalCFGEnabled   % Logical.
    end

    properties(SetAccess = private,SetObservable)
        cycleIters = [];     % Iterations
        cycleListeners = []; % cycle Listeners
    end
    
    events
        propertyChanged;
    end

    methods
        function obj = CycleDataGroup(nm)
            if nargin > 0 && ~isempty(nm)
                obj.name = nm;
            else
                obj.reset();
            end
        end
        
        function delete(obj)
            obj.clear();
        end

        function reset(obj)
            obj.name = '';

            obj.goHomeAtCycleEndEnabled = true;
            obj.autoResetModeEnabled = true;
            obj.restoreOriginalCFGEnabled = true;

            obj.clear();
        end

        function update(obj,cycleDataGroup)
            obj.name = cycleDataGroup.name;

            obj.goHomeAtCycleEndEnabled = cycleDataGroup.goHomeAtCycleEndEnabled;
            obj.autoResetModeEnabled = cycleDataGroup.autoResetModeEnabled;
            obj.restoreOriginalCFGEnabled = cycleDataGroup.restoreOriginalCFGEnabled;
            
            obj.clear();
            obj.cycleIters = copy(cycleDataGroup.cycleIters);
            for i=1:numel(obj.cycleIters)
                obj.cycleListeners = [obj.cycleListeners addlistener(obj.cycleIters(i), 'propertyChanged', @obj.refresh)];
            end
        end
        
        %make a copy for the purpose of saving to a matlab file
        function expObj = export(obj)
            expObj = obj.copy();
            %cannot re-import listeners so don't bother with exporting
            delete(expObj.cycleListeners);
            expObj.cycleListeners = [];
        end
    end            

    %% Public methods for operating on the cycle iteration list -- mostly for UI
    methods
        % Refresh
        function refresh(obj, varargin)
            notify(obj,'propertyChanged');
        end

        % CREATE
        function add(obj,cycleIterData)
        % Adds a CycleData object to the group
        %
            obj.insertAfterIdx(numel(obj.cycleIters), cycleIterData);
        end

        function insertAfterIdx(obj,idx,insertedIterData)
            if ~isa(insertedIterData, 'scanimage.components.cycles.CycleData')
                error('CycleDataGroup','Expected an object of type scanimage.components.cycles.CycleData');
            end
            
            if idx < numel(obj.cycleIters)
                for i = idx + 1 : numel(obj.cycleIters)
                    obj.cycleIters(i).idx = obj.cycleIters(i).idx + 1;
                end
            end
            
            listener = addlistener(insertedIterData, 'propertyChanged', @obj.refresh);
            
            if idx == 0
                obj.cycleIters = [insertedIterData obj.cycleIters];
                obj.cycleListeners = [listener obj.cycleListeners];
            else
                obj.cycleIters = [obj.cycleIters(1:idx) insertedIterData obj.cycleIters(idx+1:end)];
                obj.cycleListeners = [obj.cycleListeners(1:idx) listener obj.cycleListeners(idx+1:end)];
            end
            
            insertedIterData.idx = idx + 1;
        end


        %% UPDATE
        function updateByIdx(obj,idx,cycleIterData)
        % Updates an existing CycleData object in the group
        %
            if ~isa(cycleIterData, 'scanimage.components.cycles.CycleData')
                error('CycleDataGroup','Expected an object of type scanimage.components.cycles.CycleData');
            end
            hIter = obj.getIterByIdx(idx);
            hIter.update(cycleIterData);
        end

        % READ 
        function iter = getIterByIdx(obj,idx)
        % This is overkill with the current scheme, but it should allow us to change to uuid if we deem it 
        % necessary. 
        %
            iter = obj.cycleIters(idx);
        end

        % DELETE
        function removeByIdx(obj,idx)
        % Removes an existing CycleData object from the group
        % Bottleneck
        %
            obj.cycleIters(idx) = [];

            for i=idx:numel(obj.cycleIters)
                obj.cycleIters(i).idx = obj.cycleIters(i).idx - 1;
            end
            
            delete(obj.cycleListeners(idx));
            obj.cycleListeners(idx) = [];
            obj.refresh();
        end

        function clear(obj)
            delete(obj.cycleListeners);
            obj.cycleIters = [];
            obj.cycleListeners = [];
            obj.refresh();
        end
        

        %function newIdx = moveToFrontById(obj,id)
            %i=obj.idToIndex(id);
            %obj.rois=[obj.rois(i) obj.rois(1:i-1) obj.rois(i+1:end)];
            %newIdx = 1;
        %end

        %function newIdx = moveById(obj,id,step)
            %% changed index of roi from i to i+step
            %i=obj.idToIndex(id);
            %r=obj.rois(i);
            %rs=[obj.rois(1:i-1) obj.rois(i+1:end)]; %don't set obj.rois bc we don't want assoc. events to fire                                 
            %if i+step < 1
                %newIdx = obj.moveToFrontById(id);
            %elseif i+step > length(obj.rois)
                %newIdx = obj.moveToBackById(id);
            %else
                %obj.rois=[rs(1:i+step-1) r rs(i+step:end)];
                %newIdx = i+step;
            %end
        %end

        %function newIdx = moveToBackById(obj,id)
            %i=obj.idToIndex(id);
            %obj.rois=[obj.rois(1:i-1) obj.rois(i+1:end) obj.rois(i)];
            %newIdx = length(obj.rois);
        %end
    end % end public methods
    
    methods (Access = protected)
        % Override copyElement method
        function cpObj = copyElement(obj)
        % copyElement is a protected method that the copy method uses to perform the copy operation
        % on each object in the input array. Since it's not Sealed, we can override and customize it
        %
            % Make a shallow copy of the CycleDataGroup
            cpObj = copyElement@matlab.mixin.Copyable(obj);
            
            cpObj.cycleListeners = [];
            % Make a deep copy of the iterations
            if ~isempty(obj.cycleIters)
                cpObj.cycleIters = copy(obj.cycleIters);
                for i=1:numel(cpObj.cycleIters)
                    cpObj.cycleListeners = [cpObj.cycleListeners addlistener(cpObj.cycleIters(i), 'propertyChanged', @cpObj.refresh)];
                end
            else
                cpObj.cycleIters = [];
            end
        end
        

    end
    
    methods
        function set.goHomeAtCycleEndEnabled(obj,var)
            obj.goHomeAtCycleEndEnabled = var;
            obj.refresh();
        end
        
        function set.autoResetModeEnabled(obj,var)
            obj.autoResetModeEnabled = var;
            obj.refresh();
        end
        
        function set.restoreOriginalCFGEnabled(obj,var)
            obj.restoreOriginalCFGEnabled = var;
            obj.refresh();
        end
        
        function set.name(obj,var)
            obj.name = var;
            obj.refresh();
        end
    end
end


%--------------------------------------------------------------------------%
% CycleDataGroup.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
