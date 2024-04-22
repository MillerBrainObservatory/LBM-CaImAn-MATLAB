classdef IntegrationRoiManager < scanimage.interfaces.Component & most.HasMachineDataFile
    % IntegrationRoiManager
    % contains functionality to define ROIs and analyze the intensity
    % change of ROIs in real-time
    
    % ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'IntegrationRoiManager';  % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};          % Cell array of strings specifying properties that can be set while focusing
        PROP_TRUE_LIVE_UPDATE = {'enableDisplay'}; % Cell array of strings specifying properties that can be set while the component is active
        DENY_PROP_LIVE_UPDATE = {};                % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};             % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};       % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};             % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'roiGroup','hIntegrationRoiOutputChannels',...
            'outputChannelsNames' 'outputChannelsPhysicalNames' 'outputChannelsEnabled'...
            'outputChannelsFunctions' 'outputChannelsRoiNames'}
    end
     
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'IntegrationRoiOutputs';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %%% CLASS PROPERTIES
    properties (SetObservable, Transient)
        roiGroup;
    end
        
    properties (SetObservable)
        enable = false;                     % (logical) enable the calculation of intensity traces
        enableDisplay = true;               % (logical) enable potting intensity traces
        integrationHistoryLength = 1000;    % (numerical) buffer length for integration value history
        postProcessFcn = [];                % (function handle) to user defined integration value postprocessing function
    end
    
    properties (SetObservable, Dependent)
        outputChannelsNames;                % (cellstring) with names for the output channels used to drive analog or digital signals
        outputChannelsPhysicalNames;        % (cellstring) with the physical names of the output channels
        outputChannelsEnabled;              % (logical array) specifying for each output channel if enabled/disabled
        outputChannelsFunctions;            % (cell array of function handles) specifying the output funcction for each output channel
        outputChannelsRoiNames;             % (cellstr) of roi to be evaluated by each output channel
    end
    
    properties (SetAccess = private, SetObservable, Transient, Hidden)
        hIntegrationRoiOutputChannels = scanimage.components.integrationRois.IntegrationRoiOutputChannel.empty(1,0); % array of integration roi output channel objects
    end
    
    %%% internal properties
    properties (Hidden, SetAccess = private)
        integrationRegions = {};
        csv_fid;                % Handle to the CSV file used for logging integration information
        hIntegrationRoiOutputChannelsListeners = [];
        integrationValueHistory;
        integrationValueHistoryPostProcessed;
        integrationTimestampHistory;
        integrationFrameNumberHistory;
        integrationValueCursor;
        integrationValueCursorIntoArray;
        
        intParams = [];
    end
    
    properties (Hidden, SetAccess = private)
        hRoiGroupDelayedEventListener;
    end
    
    %% Lifecycle
    methods
        function obj = IntegrationRoiManager(hSI)
            obj@scanimage.interfaces.Component(hSI);
            try
                obj.roiGroup = scanimage.mroi.RoiGroup();
                obj.roiGroupAttachListener();
                
                % check mdf settings for channel configuration
                numChannels = length(obj.mdfData.channelNames);
                assert(length(obj.mdfData.deviceNames) == numChannels,'IntegrationRoiManager: The number of channel names in the MDF does not match the number of device names.');
                assert(length(obj.mdfData.deviceChannels) == numChannels,'IntegrationRoiManager: The number of channel names in the MDF does not match the number of device channels.');
                
                % create integration roi output channels
                for idx = 1:numChannels
                    try
                        obj.hIntegrationRoiOutputChannels(end+1) = scanimage.components.integrationRois.IntegrationRoiOutputChannel( ...
                            obj.mdfData.channelNames{idx},obj.mdfData.deviceNames{idx},obj.mdfData.deviceChannels{idx});
                        listener = addlistener(obj.hIntegrationRoiOutputChannels(end),'changed',@obj.integrationRoiOutputChannelsChanged);
                        obj.hIntegrationRoiOutputChannelsListeners = [obj.hIntegrationRoiOutputChannelsListeners, listener];
                    catch ME
                        fprintf(2,'Error during setup of output channel ''%s'':\n',obj.mdfData.channelNames{idx});
                        most.idioms.reportError(ME);
                    end
                end
                obj.numInstances = 1;
            catch ME
                obj.numInstances = 0;
                most.idioms.reportError(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hRoiGroupDelayedEventListener);
            delete(obj.hIntegrationRoiOutputChannelsListeners);
            delete(obj.hIntegrationRoiOutputChannels);
        end
    end
    
    %% ABSTRACT METHOD REALIZATION (scanimage.interaces.Component)
    methods (Hidden, Access = protected)
        function componentAbort(obj)
            arrayfun(@(outchan)outchan.abort(),obj.hIntegrationRoiOutputChannels);
            
            if ~isempty(obj.csv_fid) && ~isnan(obj.csv_fid) && (obj.csv_fid > 0)
                fclose(obj.csv_fid);
                obj.csv_fid = 0;
            end
        end

        function componentStart(obj)
            obj.integrationRegions = {};
            if ~obj.enable || (numel(obj.roiGroup.rois) == 0)  %% checking the condition for no integration ROIs defined
                return
            end

            % Open a CSV file for logging the integrationValue for each integration roi IntegrationRoiManager roigroup
            if obj.hSI.hChannels.loggingEnable
                obj.csv_fid = fopen(fullfile(obj.hSI.hScan2D.logFilePath, ...
                    [obj.hSI.hScan2D.logFileStem '_IntegrationRois_' sprintf('%05d', obj.hSI.hScan2D.logFileCounter) '.csv'] ),'W');

                csvHeader = strjoin({obj.roiGroup.rois.name},',');
                if numel({obj.roiGroup.rois.name}) == 0
                    assert(false);
                else
                    fprintf(obj.csv_fid, 'timestamp,frameNumber,%s\r\n', csvHeader);
                end
            end
            
            % Get the required user-interface information for the desired rois
            try
                obj.setupCpuIntegration(true);
            catch
                % fail safe mechanism
                most.idioms.warn('Something went wrong during selective update of integration rois. Resetting all.');
                obj.setupCpuIntegration(true);
            end
            
            arrayfun(@(outchan)outchan.start(),obj.hIntegrationRoiOutputChannels);
        end
    end
    
    %% Private methods
    methods (Hidden)        
        function setupCpuIntegration(obj,reparseAll)
            if nargin < 2 || isempty(reparseAll)
                reparseAll = false;
            end
            
            imagingRoiGroup = obj.hSI.hRoiManager.currentRoiGroup;
            
            if isempty(obj.intParams)
                reparseAll = true;
            else
                % in case the imagingRoiGroup, the zs or the channels changed,
                % we need to reparse all
                reparseAll = reparseAll || ...
                             obj.intParams.imagingRoiGroupUuiduint64 ~= imagingRoiGroup.uuiduint64 || ...
                             obj.intParams.imagingRoiGroupStatusId ~= imagingRoiGroup.statusId || ...
                             ~isequal(obj.intParams.zs,obj.hSI.hStackManager.zs) || ...
                             ~isequal(obj.intParams.channels,obj.hSI.hChannels.channelsActive);
            end
            
            if reparseAll
                zs = obj.hSI.hStackManager.zs;
                assert(length(zs)==length(unique(zs)),'z series is not unique'); % sanity check: zs must be unique
                
                zssorted = sort(zs);
                
                channels = obj.hSI.hChannels.channelsActive;
                assert(issorted(channels)); % Sanity check
                
                obj.intParams = struct();
                obj.intParams.imagingRoiGroup = imagingRoiGroup;
                obj.intParams.imagingRoiGroupUuiduint64 = imagingRoiGroup.uuiduint64;
                obj.intParams.imagingRoiGroupStatusId = imagingRoiGroup.statusId;
                obj.intParams.zs = zssorted(:)';
                obj.intParams.zsMasks = {};
                obj.intParams.channels = channels(:)';
                obj.intParams.numIntRois = 0;
                obj.intParams.zsIntRoiDone = false(0,length(zssorted));
                obj.intParams.intRois = scanimage.mroi.Roi.empty(1,0);
                obj.intParams.intRoisUuiduint64 = zeros(1,0,'like',imagingRoiGroup.uuiduint64);
                obj.intParams.intRoisStatusId = zeros(1,0,'like',imagingRoiGroup.statusId);
                obj.intParams.intRoiWeights = zeros(1,0);
                obj.intParams.intRoiWeightsInverse = zeros(1,0);
                obj.intParams.intRoisTempVal = zeros(1,0);
                
                obj.integrationValueHistory = zeros(obj.integrationHistoryLength,0);
                obj.integrationValueHistoryPostProcessed = zeros(obj.integrationHistoryLength,0);
                obj.integrationTimestampHistory = zeros(obj.integrationHistoryLength,0);
                obj.integrationFrameNumberHistory = zeros(obj.integrationHistoryLength,0);
                
                obj.integrationValueCursor = zeros(1,0);
                
                enableMask = [obj.hSI.hIntegrationRoiManager.roiGroup.rois.enable];
                toAdd = obj.roiGroup.rois(enableMask);
                toUpdate = [];
                toRemove = [];
            else
                enableMask = [obj.hSI.hIntegrationRoiManager.roiGroup.rois.enable];
                intRois = obj.roiGroup.rois(enableMask);
                intRoisUuiduint64 = [intRois.uuiduint64];
                
                % determine intRois that need to be added
                [tf,idx] = ismember(intRoisUuiduint64,obj.intParams.intRoisUuiduint64);
                toAdd = intRois(~tf);
                
                % determine intRois that need to be updated
                existingRois = intRois(tf);
                if ~isempty(existingRois)
                    changed = [existingRois.statusId] ~= obj.intParams.intRoisStatusId(idx(tf));
                else
                    changed = [];
                end
                toUpdate = existingRois(changed);
                
                % determine existing intRois that need to be removed
                tf = ismember(obj.intParams.intRoisUuiduint64,intRoisUuiduint64);
                toRemove = obj.intParams.intRois(~tf);
            end
            
            arrayfun(@(hIntRoi)obj.removeParsedCpuRoi(hIntRoi),toRemove);
            arrayfun(@(hIntRoi)obj.parseCpuRoi(hIntRoi),toAdd);
            arrayfun(@(hIntRoi)obj.parseCpuRoi(hIntRoi),toUpdate);
        end
        
        function removeParsedCpuRoi(obj,hIntRoi)
            [tf,roiIdx] = ismember(hIntRoi.uuiduint64,obj.intParams.intRoisUuiduint64);
            assert(tf,'Roi is not part of parsed list');
            
            for zidx = 1:length(obj.intParams.zs)
                for chidx = 1:length(obj.intParams.channels)
                    obj.intParams.zsMasks{zidx}{chidx}(:,roiIdx) = [];
                end
            end
            
            obj.intParams.zsIntRoiDone(roiIdx,:) = [];
            obj.intParams.intRois(roiIdx) = [];
            obj.intParams.intRoisUuiduint64(roiIdx) = [];
            obj.intParams.intRoisStatusId(roiIdx) = [];
            obj.intParams.intRoiWeights(roiIdx) = [];
            obj.intParams.intRoiWeightsInverse(roiIdx) = [];
            obj.intParams.intRoisTempVal(roiIdx) = [];
            
            obj.integrationValueHistory(:,roiIdx) = [];
            obj.integrationValueHistoryPostProcessed(:,roiIdx) = [];
            obj.integrationTimestampHistory(:,roiIdx) = [];
            obj.integrationFrameNumberHistory(:,roiIdx) = [];
            
            obj.integrationValueCursor(roiIdx) = [];
        end
            
        function parseCpuRoi(obj,hIntRoi)
            if isempty(obj.intParams.intRois)
                roiIdx = 1;
            else
                [tf,roiIdx] = ismember(hIntRoi.uuiduint64,obj.intParams.intRoisUuiduint64);
                if ~tf
                    roiIdx = length(obj.intParams.intRois) + 1; % add Roi to end of the list
                end
            end
            
            assert(issorted(obj.intParams.zs));
            assert(issorted(obj.intParams.channels));
            
            roiWeight = 0;
            zsIntRoiDone = false(1,length(obj.intParams.zs));
            
            zsMasks = cell(length(obj.intParams.zs),1);
            
            for zidx = 1:length(obj.intParams.zs);
                z = obj.intParams.zs(zidx);
                
                sfsMask = {}; % masks for each imaging scanfields on current z
                hIntSf = hIntRoi.get(z);
                
                for imRoi = obj.intParams.imagingRoiGroup.rois(:)'
                    sf = imRoi.get(z);
                    
                    if ~isempty(sf);      
                        pixelResolution = sf.pixelResolution;
                        sfsMask{end+1} = sparse(prod(pixelResolution),length(obj.intParams.channels));
                        
                        if ~isempty(hIntSf);
                            [tf,chIdx] = ismember(hIntSf.channel,obj.intParams.channels);
                            if tf
                                imSf = hIntSf.owningImagingScanField(sf,[]);
                                if ~isempty(imSf)
                                    mask_ = hIntSf.maskImagingScanfield(imSf)'; % assumption: stripeData.roiData.imageData is transposed
                                    sfsMask{end}(:,chIdx) = mask_(:);
                                    roiWeight = roiWeight + sum(mask_(:));
                                end
                            end
                            
                            tf = ismember(hIntRoi.zs,obj.intParams.zs(zidx+1:end)); % check if this is the last scanfield in the z series
                            if ~all(tf);
                                zsIntRoiDone(zidx) = true;
                            end
                        end
                    end
                end
                sfsMask = vertcat(sfsMask{:});
                zsMasks{zidx} = mat2cell(sfsMask,size(sfsMask,1),ones(1,size(sfsMask,2)));
            end
                        
            for zidx = 1:length(obj.intParams.zs)
                for chidx = 1:length(obj.intParams.channels)
                    obj.intParams.zsMasks{zidx}{chidx}(:,roiIdx) = zsMasks{zidx}{chidx};
                end
            end
            
            obj.intParams.zsIntRoiDone(roiIdx,:) = zsIntRoiDone;
            obj.intParams.intRois(roiIdx) = hIntRoi;
            obj.intParams.intRoisUuiduint64(roiIdx) = hIntRoi.uuiduint64;
            obj.intParams.intRoisStatusId(roiIdx) = hIntRoi.statusId;
            obj.intParams.intRoiWeights(roiIdx) = roiWeight;
            obj.intParams.intRoiWeightsInverse(roiIdx) = 1./roiWeight;
            obj.intParams.intRoisTempVal(roiIdx) = 0;
            
            obj.integrationValueHistory(:,roiIdx) = zeros(obj.integrationHistoryLength,1);
            obj.integrationValueHistoryPostProcessed(:,roiIdx) = zeros(obj.integrationHistoryLength,1);
            obj.integrationTimestampHistory(:,roiIdx) = zeros(obj.integrationHistoryLength,1);
            obj.integrationFrameNumberHistory(:,roiIdx) = zeros(obj.integrationHistoryLength,1);
            
            obj.integrationValueCursor(roiIdx) = obj.integrationHistoryLength;
        end
        
        function roiGroupAttachListener(obj)
            most.idioms.safeDeleteObj(obj.hRoiGroupDelayedEventListener);
            obj.hRoiGroupDelayedEventListener = most.util.DelayedEventListener(0.5,obj.roiGroup,'changed',@(varargin)obj.roiGroupChanged);
        end
        
        function roiGroupChanged(obj,varargin)
            arrayfun(@(channel)channel.deleteOutdatedRois(obj.roiGroup),obj.hIntegrationRoiOutputChannels);
            obj.roiGroup = NaN; % dummy set to update gui
            
            if obj.active && obj.enable
                obj.setupCpuIntegration();
            end
        end
        
        function integrationRoiOutputChannelsChanged(obj,varargin)
            obj.hIntegrationRoiOutputChannels = NaN; % dummy set to update gui
        end
        
        function update(obj,stripeData)
            % Disable roi integration if the component is disabled or if we aren't using the CPU for integrating ROIs
            if ~obj.enable || (numel(obj.roiGroup.rois) == 0)
                return
            end
            
            if ~(stripeData.startOfFrame && stripeData.endOfFrame)
                most.idioms.dispError('Roi Integration is not supported when striping display is used.');
                return
            end
            
            integrationDone = obj.updateIntegrationValues(stripeData);
            arrayIdxs = obj.integrationValueCursorIntoArray;
            integrationValues = obj.postProcessFcn(obj.intParams.intRois,integrationDone,arrayIdxs,obj.integrationValueHistory,obj.integrationTimestampHistory,obj.integrationFrameNumberHistory);
            obj.integrationValueHistoryPostProcessed(arrayIdxs(integrationDone)) = integrationValues(integrationDone);
            timestamps = obj.integrationTimestampHistory(arrayIdxs);
            
            if any(integrationDone)
                for outChannel = obj.hIntegrationRoiOutputChannels
                    outChannel.updateOutput(obj.intParams.intRois,integrationDone,obj.integrationValueHistoryPostProcessed,obj.integrationTimestampHistory,arrayIdxs);
                end
            end

            if stripeData.endOfVolume
                % Log data to csv file
                if obj.hSI.hChannels.loggingEnable
                    intValStrings = sprintf(',%f', integrationValues);
                    fprintf(obj.csv_fid, '%f,%i%s\r\n', stripeData.frameTimestamp, stripeData.frameNumberAcqMode, intValStrings);
                end
                
                % Refresh display
                if obj.enableDisplay && ~isempty(obj.hSI.hController)
                    hSICtl = obj.hSI.hController{1};
                    hSICtl.updateIntegrationRoiDisplay(obj.intParams.intRois,integrationValues,timestamps);
                end
            end
        end
        
        function integrationDone = updateIntegrationValues(obj,stripeData)
            numIntRois = length(obj.intParams.intRois);

            if numIntRois <= 0 || isempty(stripeData.roiData)
                integrationDone = false(1,0);
               return
            end
            
            z = stripeData.roiData{1}.zs; % assumption: only one z in stripedata
            
            numChannels = length(obj.intParams.channels);
            
            % extract image data from stripe data
            imData = cell(length(stripeData.roiData),numChannels);
            for roiIdx = 1:length(stripeData.roiData)
                roiData = stripeData.roiData{roiIdx};
                
                for chIdx = 1:numChannels
                    data = roiData.imageData{chIdx}{1}; % assumption: only one z in stripedata
                    if ~isempty(roiData.motionOffset)
                        motionOffset = round( -roiData.motionOffset(:,1) );
                        data = circshift(data,motionOffset);
                        datadbl = double(data);
                        
                        % set regions that moved out of bounds to NaN
                        if motionOffset(1) > 0
                            datadbl(1:motionOffset(1),:) = NaN;
                        elseif motionOffset(1) < 0
                            datadbl(end+motionOffset(1):end,:) = NaN;
                        end
                        
                        if motionOffset(2) > 0
                            datadbl(:,1:motionOffset(2)) = NaN;
                        elseif motionOffset(2) < 0
                            datadbl(:,end+motionOffset(2)+1:end) = NaN;
                        end
                    else
                        datadbl = double(data);
                    end
                    
                    imData{roiIdx,chIdx} = reshape(datadbl,1,[]);
                end
            end
            
            zIdx = ismembc2(z,obj.intParams.zs);
            assert(zIdx > 0); % sanity check
            
            roiVals = zeros(1,numIntRois);
            for chIdx = 1:numChannels;
                chdata = horzcat(imData{:,chIdx});
                roiVals = roiVals + (chdata * obj.intParams.zsMasks{zIdx}{chIdx});
            end
            obj.intParams.intRoisTempVal = obj.intParams.intRoisTempVal + roiVals; % add to accumulator

            
            integrationDone = obj.intParams.zsIntRoiDone(:,zIdx);
            obj.intParams.intRoisTempVal(integrationDone) = obj.intParams.intRoisTempVal(integrationDone) .* obj.intParams.intRoiWeightsInverse(integrationDone);
            
            timeStamp = stripeData.frameTimestamp;
            frameNumber = stripeData.frameNumberAcqMode;
            roiIdxs = 1:numIntRois;
            roiIdxs = roiIdxs(integrationDone);
            
            obj.integrationValueCursor(integrationDone) = obj.integrationValueCursor(integrationDone) + 1;
            obj.integrationValueCursor(obj.integrationValueCursor>obj.integrationHistoryLength) = 1;
            
            valIdxs = obj.integrationValueCursorIntoArray(integrationDone);
            obj.integrationValueHistory(valIdxs) = obj.intParams.intRoisTempVal(integrationDone);
            obj.integrationTimestampHistory(valIdxs) = timeStamp;
            obj.integrationFrameNumberHistory(valIdxs) = frameNumber;
            
            obj.intParams.intRoisTempVal(integrationDone) = 0; % reset accumulator
        end

        function backupRoiGroup(obj)
            siDir = fileparts(which('scanimage'));
            filename = fullfile(siDir, 'roigroupIntegration.backup');
            roigroupIntegration = obj.roiGroup; %#ok<NASGU>
            save(filename,'roigroupIntegration','-mat');
        end
    end
    
    %% USER METHODS
    methods
        function [intRois,values,timestamps,framenumbers] = getIntegrationValues(obj)
            % retrieve current integration values for each analyzed ROI
            
            if isempty(obj.intParams) || ~isfield(obj.intParams,'intRois') || isempty(obj.intParams.intRois)
                intRois = [];
                values = [];
                timestamps = [];
                framenumbers = [];
            else
                intRois = obj.intParams.intRois;
                cursor = obj.integrationValueCursorIntoArray;
                values = reshape(obj.integrationValueHistoryPostProcessed(cursor),1,[]);
                timestamps = reshape(obj.integrationTimestampHistory(cursor),1,[]);
                framenumbers = reshape(obj.integrationFrameNumberHistory(cursor),1,[]);
            end
        end
        
        function [intRois,valueHistory,timestampHistory,framenumberHistory] = getIntegrationHistory(obj)
            % retrieve integration history for each analyzed ROI
            % note: this function can be slow for a large number of ROIs
            %       use with caution during a live acquisition
            
            if isempty(obj.intParams) || ~isfield(obj.intParams,'intRois') || isempty(obj.intParams.intRois)
                intRois = [];
                valueHistory = [];
                timestampHistory = [];
                framenumberHistory = [];
            else
                intRois = obj.intParams.intRois;
                valueHistory = [];
                timestampHistory = [];
                framenumberHistory = [];
                cursor = obj.integrationValueCursorIntoArray;
                
                [is,js] = ind2sub(size(obj.integrationValueHistoryPostProcessed),cursor);
                
                if nargout>1; valueHistory = shiftArray(obj.integrationValueHistoryPostProcessed,is,js); end
                if nargout>2; timestampHistory = shiftArray(obj.integrationTimestampHistory,is,js); end
                if nargout>3; framenumberHistory = shiftArray(obj.integrationFrameNumberHistory,is,js); end
            end
            
            %%% local function
            function vals = shiftArray(vals,is,js)
                if isscalar(unique(is))
                    vals = circshift(vals,-is(1),1);
                else
                    for idx = 1:length(is)
                        i = is(idx);
                        j = js(idx);
                        vals(:,j) = circshift(vals(:,j),-i,1);
                    end
                end
            end
        end
    end


    %% Property Access methods
    methods
        function set.roiGroup(obj,val)
            if ~isobject(val) && isnan(val)
                return % dummy set to update gui
            end
            
            if isempty(val)
                val = scanimage.mroi.RoiGroup();
            end
            
            assert(isa(val,'scanimage.mroi.RoiGroup'));
            
            obj.roiGroup = val;
            obj.roiGroupAttachListener()
            obj.roiGroupChanged();
        end
        
        function set.hIntegrationRoiOutputChannels(obj,val)
            if isempty(val)
                val = scanimage.components.integrationRois.empty(1,0);            
            elseif ~isobject(val) && isnan(val)
                return % dummy set to update gui
            end
            
            obj.hIntegrationRoiOutputChannels = val;
        end
        
        function set.enable(obj,val)
            val = obj.validatePropArg('enable',val);
            
            if obj.componentUpdateProperty('enable',val)
                obj.enable = logical(val);
            end
        end
        
        function set.enableDisplay(obj,val)
            val = obj.validatePropArg('enableDisplay',val);
            
            if obj.componentUpdateProperty('enableDisplay',val)
                obj.enableDisplay = logical(val);
            end
        end
        
        function set.integrationHistoryLength(obj,val)
            val = obj.validatePropArg('integrationHistoryLength',val);
            
            if obj.componentUpdateProperty('integrationHistoryLength',val)
                obj.integrationHistoryLength = val;
            end
        end 
        
        function set.postProcessFcn(obj,val)
            if isempty(val)
                val = @scanimage.components.integrationRois.integrationPostProcessingFcn;
            end
            
            if obj.componentUpdateProperty('postProcessFcn',val)
                obj.postProcessFcn = val;
            end
        end
        
        function val = get.integrationValueCursorIntoArray(obj)
            roiColumns = 0:size(obj.integrationValueHistory,2)-1;
            val = obj.integrationValueCursor(:)+roiColumns(:).*size(obj.integrationValueHistory,1);
        end
        
        function val = get.outputChannelsNames(obj)
            val = {obj.hIntegrationRoiOutputChannels.channelName};
        end
        
        function val = get.outputChannelsPhysicalNames(obj)
            val = {obj.hIntegrationRoiOutputChannels.physicalChannelName};
        end
        
        function val = get.outputChannelsEnabled(obj)
            val = [obj.hIntegrationRoiOutputChannels.enable];
        end
        
        function set.outputChannelsEnabled(obj,val)
            val = obj.validatePropArg('outputChannelsEnabled',val);
            assert(length(val)==length(obj.hIntegrationRoiOutputChannels));
            
            if obj.componentUpdateProperty('outputChannelsEnabled',val)
                for idx = 1:length(obj.hIntegrationRoiOutputChannels)
                    obj.hIntegrationRoiOutputChannels(idx).enable = val(idx);
                end
            end
        end
        
        function val = get.outputChannelsFunctions(obj)
            val = arrayfun(@(ch)func2str(ch.outputFunction),obj.hIntegrationRoiOutputChannels,'UniformOutput',false);
        end
        
        function set.outputChannelsFunctions(obj,val)
            val = obj.validatePropArg('outputChannelsFunctions',val);
            assert(length(val)==length(obj.hIntegrationRoiOutputChannels));
            
            if obj.componentUpdateProperty('outputChannelsFunctions',val)
                for idx = 1:length(obj.hIntegrationRoiOutputChannels)
                    vali = val{idx};
                    assert(ischar(vali) || isa(vali,'function_handle'));
                    obj.hIntegrationRoiOutputChannels(idx).outputFunction = val{idx};
                end
            end
        end
        
        function val = get.outputChannelsRoiNames(obj)
            val = {};
            for idx = 1:length(obj.hIntegrationRoiOutputChannels)
                rois = obj.hIntegrationRoiOutputChannels(idx).hIntegrationRois;
                val{idx} = {rois.name}; %#ok<AGROW>
            end
        end
        
        function set.outputChannelsRoiNames(obj,val)
            val = obj.validatePropArg('outputChannelsRoiNames',val);            
            assert(length(val)==length(obj.hIntegrationRoiOutputChannels));
            
            if obj.componentUpdateProperty('outputChannelsRoiNames',val)
                rois = obj.roiGroup.rois;
                
                for idx = 1:length(obj.hIntegrationRoiOutputChannels)
                    vali = val{idx};
                    if isempty(vali)
                        continue
                    end
                    
                    [tf,pos] = ismember(vali,{rois.name});
                    pos = pos(tf);
                    obj.hIntegrationRoiOutputChannels(idx).hIntegrationRois = rois(pos);
                end
            end
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct();
    s.enable = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.enableDisplay = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.postProcessFcn = struct('Classes','function_handle','Attributes',{{'scalar'}});
    s.roiGroup = struct('Classes','scanimage.mroi.RoiGroup','Attributes',{{'scalar'}});
    s.hIntegrationRoiOutputChannels = struct();
    s.integrationHistoryLength = struct('Classes','numeric','Attributes',{{'scalar','positive','finite'}});
    s.outputChannelsNames = struct('Classes','cell','Attributes',{{'vector'}},'AllowEmpty',1);
    s.outputChannelsPhysicalNames = struct('Classes','cell','Attributes',{{'vector'}},'AllowEmpty',1);
    s.outputChannelsEnabled = struct('Classes','binaryflex','Attributes',{{'vector'}},'AllowEmpty',1);
    s.outputChannelsFunctions = struct('Classes','cell','Attributes',{{'vector'}},'AllowEmpty',1);
    s.outputChannelsRoiNames = struct('Classes','cell','Attributes',{{'vector'}},'AllowEmpty',1);
end



%--------------------------------------------------------------------------%
% IntegrationRoiManager.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
