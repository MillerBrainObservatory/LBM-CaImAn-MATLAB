classdef CycleManagerController < handle
% CYCLEMANAGERCONTROLLER Controller class for cycle mode

    properties 
        model
        view 
    end

    % Observable properties
    properties(SetObservable)
        showAdvancedParameters      % Logical.
        lastSelectedCell            % [row col] of the last selected cell
    end

    % Internal properties
    properties
        iterationStrings = {...
                            'cfgName'...
                            'iterDelay'...
                            'motorAction'...
                            'motorStep'...
                            'repeatPeriod'...
                            'numRepeats'...
                            'numSlices'...
                            'zStepPerSlice'...
                            'numFrames'...
                            'power'...
                            'numAvgFrames'...
                            'framesPerFile'...
                            'lockFramesPerFile'...
                            };
    end

    % CONSTRUCTOR
    methods
        function obj = CycleManagerController(model)
            obj.model = model;
            obj.view = scanimage.guis.CycleManagerView(obj);

            obj.showAdvancedParameters = false; 
        end
    end


    % USER METHODS
    methods
        function raiseGUI(obj)
            figure(obj.view.gui);
        end

        function setCellContents(obj,tableData,eventdata)
            if isempty(eventdata.Error) 
                editIter = obj.model.cycleDataGroup.getIterByIdx(eventdata.Indices(1));   % This is a handle so we can just edit it directly
                editIter.(sprintf('%s', obj.iterationStrings{eventdata.Indices(2)})) = eventdata.NewData;
                % Trigger the GUI listener
                obj.model.cycleDataGroup.refresh;
            end
            % This should correct any issues in case of faulty input
            obj.model.cycleDataGroup.refresh;
        end

        function selectCell(obj,eventData)
            obj.lastSelectedCell = eventData.Indices;
        end

        function setCycleEnabledMode(obj, val)
            obj.model.enabled = val;
        end

        function setApplyToAllMode(obj, val)
            obj.model.enabled = val;
        end

        function addRow(obj)
            obj.model.appendNewIteration();
        end

        function dropRow(obj)
            if ~isempty(obj.lastSelectedCell) && (obj.lastSelectedCell(1) > 0)
                obj.model.removeIterationAt(obj.lastSelectedCell(1));
            else
                obj.model.removeLastIteration();
            end
        end

        function clearTable(obj)
            obj.model.cycleDataGroup.clear();
        end

        function setCycleName(obj,val)
            % Ignore the changed text and revert to the one in the model
            % The cycle name should only be editable through the save/load
            % commands
            obj.model.cycleDataGroup.name = obj.model.cycleDataGroup.name;
        end

        function setTotalCycleRepeats(obj,val)
            obj.model.totalCycles = floor(str2double(val));
        end

        function saveCycle(obj)
            obj.model.saveCycle();  % Force user input
        end

        function loadCycle(obj)
            obj.model.loadCycle(); % Force user input
        end

        function goHomeAtCycleEndModeChanged(obj,val)
            obj.model.cycleDataGroup.goHomeAtCycleEndEnabled = val;
        end

        function restoreOriginalCFGChanged(obj,val)
            obj.model.cycleDataGroup.restoreOriginalCFGEnabled = val;
        end

        function autoResetModeChanged(obj,val)
            obj.model.cycleDataGroup.autoResetModeEnabled = val;
            % Reset counters immediately if the toggle goes to true
            if val
                obj.model.resetIterationsCounter();
            end
        end

        function resetCycle(obj)
            obj.model.resetCounters;
        end

        function toggleShowAdvancedParameters(obj)
            obj.showAdvancedParameters = ~obj.showAdvancedParameters;
        end

        function addCFG(obj)
            % +++ A better approach could be used, but we would have to inherit from most.HasClassDataFile,
            % which might be overkill. We should come back to this.
            lastPath = most.idioms.startPath;
            cfgfilename = obj.zprvUserCfgFileHelper(...
                @()uigetfile('*.cfg','Select Config File',lastPath),...
                @(path,file,fullfile)assert(exist(fullfile,'file')==2,'Specified file does not exist.'));
            if isempty(cfgfilename) % user cancelled
                return;
            end
            % Get a handle to the iteration corresponding to the last selected cell
            editIter = obj.model.cycleDataGroup.getIterByIdx(obj.lastSelectedCell(1)); 
            % Replace the cfg file entry by the one we have just verified
            editIter.cfgName = cfgfilename;

            % Trigger the GUI listener
            obj.model.cycleDataGroup.refresh;
        end

        function clearSelectedCellContents(obj)
            if ~isempty(obj.lastSelectedCell)
                editIter = obj.model.cycleDataGroup.getIterByIdx(obj.lastSelectedCell(1)); 
                editIter.(sprintf('%s', obj.iterationStrings{obj.lastSelectedCell(2)})) = [];

                % Trigger the GUI listener
                obj.model.cycleDataGroup.refresh;
            end
        end
    end

    methods (Hidden, Access=private)
        function fname = zprvUserCfgFileHelper(~,fileFcn,verifyFcn) 
            % Get/preprocess/verify a config filename. Set 'lastConfigFilePath'
            % classdatavar, obj.cfgFilename.
            
            fname = [];
            if isempty(fname)
                [f,p] = fileFcn();
                if isnumeric(f)
                    fname = [];
                    return;
                end
                fname = fullfile(p,f);
            else
                [p,f,e] = fileparts(fname);
                if isempty(p)
                    p = cd;
                end
                if isempty(e)
                    e = '.cfg';
                end
                f = [f e];
                fname = fullfile(p,f);
            end
            verifyFcn(p,f,fname);
        end
    end

    methods(Static)
        function cycleIter = tableDataToCycleIteration(tableData)
            %cycleIter = scanimage.components.cycles.CycleData; 
            %cycleIter.cfgName = 'testCfg042.m';

                %switch eventdata.Indices(2)
        end
    end
end



%--------------------------------------------------------------------------%
% CycleManagerController.m                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
