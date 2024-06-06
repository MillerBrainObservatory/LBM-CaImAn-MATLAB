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
    end

    methods
        function obj = CycleDataGroup(nm)
            if nargin > 0 && ~isempty(nm)
                obj.name = nm;
            else
                obj.reset();
            end
        end      

        function reset(obj)
            obj.name = '';

            obj.goHomeAtCycleEndEnabled = true;
            obj.autoResetModeEnabled = true;
            obj.restoreOriginalCFGEnabled = true;

            obj.cycleIters = [];
        end

        function update(obj,cycleDataGroup)
            obj.name = cycleDataGroup.name;

            obj.goHomeAtCycleEndEnabled = cycleDataGroup.goHomeAtCycleEndEnabled;
            obj.autoResetModeEnabled = cycleDataGroup.autoResetModeEnabled;
            obj.restoreOriginalCFGEnabled = cycleDataGroup.restoreOriginalCFGEnabled;

            obj.cycleIters = copy(cycleDataGroup.cycleIters);
        end
    end            

    %% Public methods for operating on the cycle iteration list -- mostly for UI
    methods
        % Refresh
        function refresh(obj)
            obj.cycleIters = obj.cycleIters;
            obj.goHomeAtCycleEndEnabled = obj.goHomeAtCycleEndEnabled;
            obj.autoResetModeEnabled = obj.autoResetModeEnabled;
            obj.restoreOriginalCFGEnabled = obj.restoreOriginalCFGEnabled;
            obj.name = obj.name;
        end

        % CREATE
        function add(obj,cycleIterData)
        % Adds a CycleData object to the group
        %
            if ~isa(cycleIterData, 'scanimage.components.cycles.CycleData')
                error('CycleDataGroup','Expected an object of type scanimage.components.cycles.CycleData');
            end
            cycleIterData.idx = numel(obj.cycleIters) + 1;
            obj.cycleIters = [obj.cycleIters cycleIterData];
        end

        function insertAfterIdx(obj,idx,insertedIterData)
            obj.cycleIters = [obj.cycleIters(1:idx) insertedIterData obj.cycleIters(idx+1:end)];
            insertedIterData.idx = idx + 1;
            for i = idx + 2 : numel(obj.cycleIters)
                obj.cycleIters(i).idx = obj.cycleIters(i).idx + 1;
            end
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
            for i =idx:numel(obj.cycleIters)
                obj.cycleIters(i).idx = obj.cycleIters(i).idx - 1;
            end
        end

        function clear(obj)
            obj.cycleIters = [];
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

            % Make a deep copy of the iterations
            if ~isempty(obj.cycleIters)
                cpObj.cycleIters = copy(obj.cycleIters);
            else
                cpObj.cycleIters = [];
            end
        end
    end

    methods
        function set.goHomeAtCycleEndEnabled(obj,val)
            obj.goHomeAtCycleEndEnabled = val;
        end

        function set.autoResetModeEnabled(obj,val)
            obj.autoResetModeEnabled = val;
        end

        function set.restoreOriginalCFGEnabled(obj,val)
            obj.restoreOriginalCFGEnabled = val;
        end
    end
end


%--------------------------------------------------------------------------%
% CycleDataGroup.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
