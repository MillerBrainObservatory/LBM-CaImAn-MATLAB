classdef CycleManagerView < handle
% CYCLEMANAGER Model class for cycle mode
    properties
        gui
        model
        controller
    end

    methods
        function obj = CycleManagerView(controller)
            obj.controller = controller;
            obj.model = controller.model;
            policy = 'reuse';
            visibility = false;
            obj.gui = cycleModeControlsV5(policy,visibility,controller);


            addlistener(obj.model,'enabled','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));

            addlistener(obj.model,'cyclesCompleted','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            addlistener(obj.model,'totalCycles','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            addlistener(obj.model,'itersCompleted','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            % cycleIterIdxTotal doesn't need a listener, since it's dependent on cycleDataGroup.cycleIters

            addlistener(obj.model.cycleDataGroup,'name','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            addlistener(obj.model.cycleDataGroup,'goHomeAtCycleEndEnabled','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            addlistener(obj.model.cycleDataGroup,'autoResetModeEnabled','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            addlistener(obj.model.cycleDataGroup,'restoreOriginalCFGEnabled','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));
            addlistener(obj.model.cycleDataGroup,'cycleIters','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));

            addlistener(obj.controller,'showAdvancedParameters','PostSet',...
                @(src,evnt)scanimage.guis.CycleManagerView.handlePropEvents(obj,src,evnt));

            % Refresh the model to trigger listeners for GUI initialization (reduces code duplication)
            obj.model.refresh;
        end

        function delete(obj)
            if ishandle(obj.gui)
                close(obj.gui);
                delete(obj.gui);
            end
        end
    end

    methods (Static)
        function handlePropEvents(obj,src,evnt)
            evntobj = evnt.AffectedObject;
            handles = guidata(obj.gui);

            switch src.Name
                case 'enabled'
                    hCtl = obj.model.hSI.hController{1};
                    if evntobj.enabled
                        valOnOff = 'on';
                        if most.idioms.isValidObj(hCtl)
                            hB = hCtl.hGUIData.mainControlsV4.startLoopButton;
                            hB.String = 'CYCLE';
                        end
                    else
                        valOnOff = 'off';
                        if most.idioms.isValidObj(hCtl)
                            hB = hCtl.hGUIData.mainControlsV4.startLoopButton;
                            hB.String = 'LOOP';
                        end
                    end
                case 'cycleIters'
                    % Populate uitable
                    tableData = scanimage.guis.CycleManagerView.cycleDataGroupIterationsToTableData(evntobj.cycleIters);
                    set(handles.tblCycle, 'Data',tableData);
                    set(handles.etCycleLength, 'String',num2str(obj.model.cycleIterIdxTotal));
                case 'showAdvancedParameters'
                    rectPrev = get(handles.output,'Position');
                    if evntobj.showAdvancedParameters
                        set(handles.output,'Position',[rectPrev(1) rectPrev(2) 195.5 rectPrev(4)]);
                        set(handles.tbShowAdvanced,'String','<<');
                    else
                        set(handles.output,'Position',[rectPrev(1) rectPrev(2) 41.5 rectPrev(4)]);
                        set(handles.tbShowAdvanced,'String','>>');
                    end
                case 'cyclesCompleted'
                    set(handles.etCycleCount, 'String',num2str(obj.model.cyclesCompleted));
                case 'itersCompleted'
                    set(handles.etCycleIteration, 'String',num2str(evntobj.itersCompleted));
                case 'totalCycles'
                    set(handles.etNumCycleRepeats, 'String',num2str(obj.model.totalCycles));
                case 'name'
                    %set(handles.etCycleName, 'String', evntobj.name);
                    [~,fname,~] = fileparts(evntobj.name);
                    set(handles.etCycleName, 'String', fname);
                case 'goHomeAtCycleEndEnabled'
                    set(handles.cbGoHomeAtCycleEnd, 'Value', evntobj.goHomeAtCycleEndEnabled);
                case 'autoResetModeEnabled'
                    set(handles.cbCycleAutoReset, 'Value', evntobj.autoResetModeEnabled);
                    if evntobj.autoResetModeEnabled
                        set(handles.etIterationsPerLoop, 'Enable', 'off');
                        set(handles.pbCycleReset, 'Enable', 'off');
                    else
                        set(handles.etIterationsPerLoop, 'Enable', 'on');
                        set(handles.pbCycleReset, 'Enable', 'on');
                    end
                case 'restoreOriginalCFGEnabled'
                    set(handles.cbRestoreOriginalCFG, 'Value', evntobj.restoreOriginalCFGEnabled);
            end
        end

        function tableData = cycleDataGroupIterationsToTableData(cycleIterGroup)
            if isempty(cycleIterGroup)
                % This is an artifice.
                %tableData = {blanks(0) [] 'Posn #' blanks(0) [] [] [] [] [] blanks(0) [] [] []};
                tableData = {};
                return;
            end

            %+++ CAREFUL! Setting manually for now
            numCols = 13;
            numRows = numel(cycleIterGroup);
            tableData = cell([numRows, numCols]);

            for i = 1:numRows
                cycleIter = cycleIterGroup(i);
                if cycleIter.cfgName
                    [~,fname,~] = fileparts(cycleIter.cfgName);
                else
                    fname = '';
                end
                tableData{i,1} = fname;
                tableData{i,2} = cycleIter.iterDelay;
                tableData{i,3} = cycleIter.motorAction;
                tableData{i,4} = cycleIter.motorStep;
                tableData{i,5} = cycleIter.repeatPeriod;
                tableData{i,6} = cycleIter.numRepeats;
                tableData{i,7} = cycleIter.numSlices;
                tableData{i,8} = cycleIter.zStepPerSlice;
                tableData{i,9} = cycleIter.numFrames;
                tableData{i,10} = cycleIter.power;
                tableData{i,11} = cycleIter.numAvgFrames;
                tableData{i,12} = cycleIter.framesPerFile;
                tableData{i,13} = cycleIter.lockFramesPerFile;
            end
        end


    end
end

%% +++ Make a static method to parse CycldeDataGroup into strings for the uitable
%'ColumnName',{  'Config|Name'; 'Iteration|Delay'; 'Motor|Action'; 'Motor Step/|Posn #/ROI #'; 'Repeat|Period'; '#|Repeats'; '#|Slices'; 'Z Step|/Slice'; '#|Frames'; 'Power'; '# Avg|Frames'; 'Frames|/File'; 'Lock|Frames/File' },...
%'ColumnFormat',{  'char' 'numeric' {  'Posn #' 'ROI #' 'Step' } 'char' 'numeric' 'numeric' 'numeric' 'numeric' 'numeric' 'char' 'numeric' 'numeric' 'logical' },...
%'Data',{  blanks(0) [] 'Posn #' blanks(0) [] [] [] [] [] blanks(0) [] [] []; blanks(0) [] 'Posn #' blanks(0) [] [] [] [] [] blanks(0) [] [] [] },...



%--------------------------------------------------------------------------%
% CycleManagerView.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
