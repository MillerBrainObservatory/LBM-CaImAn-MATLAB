classdef CycleManager < scanimage.interfaces.Component
% CYCLEMANAGER      Model class for cycle mode

    properties (SetObservable)
        cycleDataGroup;             % Struct array for setting up cycle iteration properties.
        enabled;                    % Flag for enabling (true) or disabling (false) the cycle mode.

        totalCycles;                % Integer indicating the total number of cycles to run
    end

    properties (SetObservable, SetAccess=private)
        cyclesCompleted;               % Integer indicating number of cycles completed
        itersCompleted;           % Integer indicating number of iterations completed for the current cycle
    end

    properties (SetObservable, SetAccess=private, Dependent)
        cycleIterIdxTotal;          % Integer containing the total number of cycle iterations.
    end
    
    properties (Hidden, SetObservable)
        activeIter;
        waitParams = [];
    end

    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {};
    end

    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end

    properties (Constant, Hidden)
        COMPONENT_NAME = 'CycleManager';                    % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'.
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active.
        PROP_FOCUS_TRUE_LIVE_UPDATE = {...                  % Cell array of strings specifying properties that can be set while focusing.
            };
        DENY_PROP_LIVE_UPDATE = {};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus).
        
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active.
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing.
        DENY_FUNC_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus).
    end

    %% LIFECYCLE
    methods(Hidden)
        function obj = CycleManager(hSI)
        %   Model class constructor for the cycle manager. The constructor
        %   initializes the cycle mode state and returns the initialized
        %   cycle mode object.
        %
        %   Syntax
        %       NA. This is called during scanimage initialization. 
        %
        %   Parameters
        %       hSI - This is an instance of scanimage.SI.
        %
        %   Returns
        %       Returns the created and initialized cycle mode object.
            obj = obj@scanimage.interfaces.Component(hSI,false,true);
            try
                obj.reset();
                obj.numInstances = 1;
            catch ME
                obj.numInstances = 0;
                most.idioms.warn('CycleManager module initialization failed. Error:\n%s', ME.message);
            end
        end
    end

    methods
        function reset(obj)
        %   Resets the cycle mode properties for the associated CycleManager object.
        %
        %   Syntax
        %       cycleManagerObj.reset()
            obj.active = false;
            obj.cycleDataGroup = scanimage.components.cycles.CycleDataGroup;
            obj.enabled = false;

            obj.cyclesCompleted = 0;  
            obj.totalCycles = 1;  
            obj.itersCompleted = 0;
        end

        function refresh(obj)
        %   Refreshes the cycle mode properties for the associated
        %   CycleManager object.  
        %
        %   Syntax
        %      cycleManagerObj.refresh()
 
        %   Developer Comment: This is useful for updating non-most.Controller GUIs
 
            obj.cycleDataGroup.refresh();
            obj.active = obj.active;
            obj.enabled = obj.enabled; 
            obj.totalCycles = obj.totalCycles;

            obj.cyclesCompleted = obj.cyclesCompleted;
            obj.itersCompleted = obj.itersCompleted;
        end

        function appendNewIteration(obj)
        %   Appends a new iteration to the current cycle within the
        %   associated CycleManager object. 
        %   
        %   Syntax
        %       cycleManagerObj.appendNewIteration()
            newRow = scanimage.components.cycles.CycleData;
            obj.cycleDataGroup.add(newRow);
        end

        function removeLastIteration(obj)
        %   Removes the last iteration from the current cycle within the
        %   associated CycleManager object.
        %
        %   Syntax
        %       cycleManagerObj.removeLastIteration()
            numTotalIters = numel(obj.cycleDataGroup.cycleIters);
            if numTotalIters > 0
                obj.cycleDataGroup.removeByIdx(numTotalIters);
            end
        end
        
        function removeIterationAt(obj, iterationIndex)
        %   Removes the last iteration from the current cycle within the
        %   associated CycleManager object.
        %
        %   Syntax
        %       cycleManagerObj.removeIterationAt(index)
            numTotalIters = numel(obj.cycleDataGroup.cycleIters);
            if (numTotalIters > 0) && (iterationIndex > 0)
                obj.cycleDataGroup.removeByIdx(iterationIndex);
            end
        end
        
        function acqModeCompleted(obj)
        end

        function start(obj)
        %   Starts the cycle mode for the associated CycleManager object.
        %
        %   Syntax
        %       hSI.hCycleManager.start()
            assert(obj.enabled && numel(obj.cycleDataGroup.cycleIters), 'Cycle-Mode must be enabled to run');
            
            obj.active = true;
            
            % reset counters
            obj.cyclesCompleted = 0;
            obj.itersCompleted = 0;
            
            % Save current ScanImage state
            if obj.cycleDataGroup.restoreOriginalCFGEnabled
                obj.hSI.hConfigurationSaver.cfgSaveConfigAs('sitemp_cyclemode_backup.cfg',true);
            end
            
            % Enable return home for the last iteration of the last cycle
            if obj.cycleDataGroup.goHomeAtCycleEndEnabled && obj.totalCycles == 1 && obj.cycleIterIdxTotal == 1
                obj.hSI.hStackManager.stackReturnHome = obj.cycleDataGroup.goHomeAtCycleEndEnabled;
            end
            
            % start first iteration
            obj.activeIter = obj.cycleDataGroup.cycleIters(1);
            obj.waitParams = obj.activeIter.go(obj.hSI);
        end
        
        function iterationCompleted(obj)
            if obj.active
                obj.activeIter.active = false;
                obj.itersCompleted = obj.itersCompleted + 1;
                
                if obj.itersCompleted >= numel(obj.cycleDataGroup.cycleIters)
                    obj.cyclesCompleted = obj.cyclesCompleted + 1;
                    
                    if obj.cyclesCompleted >= obj.totalCycles
                        obj.activeIter = [];
                    else
                        obj.itersCompleted = 0;
                        obj.activeIter = obj.cycleDataGroup.cycleIters(1);
                    end
                else
                    obj.activeIter = obj.cycleDataGroup.cycleIters(obj.itersCompleted+1);
                end
                
                if isempty(obj.activeIter)
                    % cycle is done!
                    obj.active = false;
                    
                    if obj.cycleDataGroup.autoResetModeEnabled
                        obj.cyclesCompleted = 0;
                        obj.itersCompleted = 0;
                    end
                    
                    % CLEAN-UP CYCLE
                    % Revert to original state if enabled
                    if obj.cycleDataGroup.restoreOriginalCFGEnabled
                        obj.hSI.hConfigurationSaver.cfgLoadConfig('sitemp_cyclemode_backup.cfg',true);
                        delete('sitemp_cyclemode_backup.cfg');
                    end
                else
                    if obj.cycleDataGroup.goHomeAtCycleEndEnabled && (obj.cyclesCompleted + 1) == obj.totalCycles && (obj.itersCompleted + 1) == numel(obj.cycleDataGroup.cycleIters)
                        obj.hSI.hStackManager.stackReturnHome = obj.cycleDataGroup.goHomeAtCycleEndEnabled;
                    end
                    obj.waitParams = obj.activeIter.go(obj.hSI);
                end
            end
        end

        function abort(obj)
        %   Aborts the current cycle mode for the associated CycleManager
        %   object.
        %
        %   Syntax
        %       cycleManagerObj.abort()
        %
            if strcmp(obj.hSI.acqState,'idle')
                if most.idioms.isValidObj(obj.activeIter)
                    obj.activeIter.abort();
                    obj.activeIter = [];
                end
                obj.active = false;
                obj.waitParams = [];
            else
                obj.hSI.abort();
            end
        end
        
        function resetCyclesCounter(obj)
            %   Resets the cycle counter for the associated CycleManager
            %   object.
            %
            %   Syntax
            %       cycleManagerObj.resetCyclesCounter()
            obj.cyclesCompleted = 0;
        end
        
        function resetIterationsCounter(obj)
            %   Resets the iteration counter for the associated CycleManager
            %   object.
            %
            %   Syntax
            %       cycleManagerObj.resetIterationsCounter()
            obj.itersCompleted = 0;
        end
        
        function resetCounters(obj)
            %   Resets all of the cycle mode counters for the associated
            %   CycleManager object.
            %
            %   Syntax
            %       cycleManagerObj.resetCounters()
            obj.resetCyclesCounter();
            obj.resetIterationsCounter();
        end

        function saveCycle(obj,filename)
        %   Saves the current cycle information for the associated
        %   CycleManager, in a file specified by filename.
        %
        %   Parameters
        %       filename - The name of the file in which the current cycle
        %       information is to be written.
        %
        %   Syntax
        %       cycleManagerObj.saveCycle(filename)
        %
            if nargin < 2 || isempty(filename)
                [filename,pathname] = uiputfile('.cyc','Choose filename to save cycle','cycle.cyc');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            %cycleDataGroup = obj.cycleDataGroup; 
            cycleDataGroup = copy(obj.cycleDataGroup); 
            cycleDataGroup.name = filename; 
            save(filename,'cycleDataGroup','-mat');

            % Update cycle-name field
            obj.cycleDataGroup.name = filename; 
        end

        function loadCycle(obj,filename)
        %   Loads cycle information from the file with the given filename
        %   and sets it as the current cycle within the associated
        %   CycleManager object. 
        %
        %   Parameters
        %       filename - The name of the file that contains the cycle
        %       information.
        %
        %   Syntax
        %       cycleManagerObj.loadCycle(filename)
        %
            if nargin < 2 || isempty(filename)
                [filename,pathname] = uigetfile('.cyc','Choose file to load cycle','cycle.cyc');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            
            cycleDataGroupContainer = load(filename,'-mat','cycleDataGroup');
            cycleDataGroup = cycleDataGroupContainer.cycleDataGroup;

            %obj.cycleDataGroup = copy(cycleDataGroup);
            obj.cycleDataGroup.update(cycleDataGroup);

            %obj.cycleDataGroup.name = filename;    %This should be unnecessary

            %perform a refresh
            obj.refresh();
        end
    end

    %% INTERNAL METHODS
    methods (Access = protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            %obj.refresh();
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
        end
    end
        

    % PROPERTY ACCESS METHODS
    methods
        function val = get.cycleIterIdxTotal(obj)
        %   Returns the number of cycle iterations within the
        %   associated CycleManager object.
            val = numel(obj.cycleDataGroup.cycleIters);
            % Side effects
            if obj.itersCompleted > 1 && obj.itersCompleted > val
                obj.itersCompleted = val;
            end
        end
    end

end

%% LOCAL (after classdef)
function s = ziniInitPropAttributes()
s = struct();

end


%--------------------------------------------------------------------------%
% CycleManager.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
