classdef Channels < scanimage.interfaces.Component
    % Channels  Manages channel saving, display and merging among other configurations
    %
    % General Design Principles:
    %
    % * Bind properly to the ColumnArrayTable format requirements.
    % * Handle channels in the ScanImage architecture so that they are
    %   decoupled from pure hardware definitions.
    % * Allow for user to select multiple data sources for channels,
    %   and push that data to different types of targets.
    %
    % TODO;
    % Get rid of the cell array notation and make each channel an object.
    % Or at least a struct.
    %
    % Update ColumnArrayTable so that it no longer has contradictory
    % referencing schemes. For example, the way that ChannelDisplay is
    % referenced is totally different from the way that AutoReadOffsets is
    % referenced - even though both are basically logicals and columns in
    % the same table!!
    %
    % Important Notes:
    %
    % The two most critical properties of Channels are the following:
    %   channelDisplayFunction
    %      This is a 1D cell array that holds function handles. Each
    %      function should take the channel number of the channel as an
    %      argument. If a function handle is not defined for a channel,
    %      then nothing will be displayed to the user.
    %
    %   channelDataSource
    %      This is a reference to an array, cell array, or other buffer
    %      that contains the data used by the channelDisplayFunction.
    %
    %      If there is no channelDataSource defined for a channel, then
    %      the channel will display some text showing that no
    %      channelDataSource is defined (assuming a channelDisplayFunction
    %      is defined for the channel.)
    %     
    %      Exception: Currently the displayStripe routine ignores the
    %      channelDataSource and addresses a hardcoded buffer.
    %
    % NOTES:
    %   A 'stripe' channelType is specifically designed to be able to
    %   display stripe data types. 'stripe' channelTypes can also be used
    %   in 3D mode.
    %
    %   A 'raster' channelType is designed to display 2D data.
    %
    
    %% PROPS FOR CONTROLLER BINDING
    properties (SetObservable, SetAccess = private)
        channelsAvailable;                                  % number of total channels available
    end
    
    properties (SetObservable)
        imagingSystemSettings = struct();                   % Structure storing channel settings for each imaging system
        displaySettings = struct();                         % Structure storing display settings for each imaging system
        
        loggingEnable = false;                                             % logical, enabling hScan2D file logging features during GRAB/LOOP acquisitions % Why not exclude from header? So files logged during acq can be distinguished from files saved after acq
    end
    
    properties (SetObservable, Dependent)
        channelOffset;                          % [native] 1D Array of offsets to be subtracted from image data
        channelInputRange;                      % [V] 1D cell array of [min max] input ranges for each channel
        channelSubtractOffset;                  % [logical] 1D Array specifying for each channel if the offset is subtracted
        channelAvailableInputRanges;            % [V] 1D cell array of settable [min, max] input ranges of the digitizer
    end
    
    properties (SetObservable, Transient)
        channelsActive;                                                    % number of total active channels available. The definition of an active channel is one that is displayed OR saved.
        
        % transient because they are in imagingSystemSettings. Don't want to cfg twice
        channelName = {'Channel 1'};                        % [V] 1D cell array of channel name strings
        channelType = {'stripe' };                          % [V] 1D cell array of channel type strings.
        channelLUT = {[100 0]};                             % LUT value for channel.
        channelDisplayFunction = { [] };                    % [handles] 1D cell array of display functions
        channelAdcResolution;                               % [bits] resolution of ADC        
        channelMergeColor = {'green'};                     % String cell array of color names, one of {'red' 'green' blue' 'gray' 'none'}.
        channelDisplay = [];                                % array of channel numbers that are being displayed to the user.
        channelSave = [];                                   % array of channel numbers that are being saved to disk ("logged").
    end
       
    %% INTERNAL PROPS
    properties (SetAccess = protected, Hidden)
        currentImagingSystem = {};
        channelLUTRange;                                 % 2 element array specifying min-max values allowed for channelLUT
    end
    
    properties (Constant, Hidden)
        IMAGING_SYSTEM_SETTINGS_PROPS = {'channelName' 'channelType' 'channelDisplayFunction' 'channelLUT'...
                    'channelAdcResolution' 'channelMergeColor' 'channelDisplay' 'channelSave'};
        DISPLAY_SETTINGS_PROPS = {'displayRollingAverageFactor'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden,SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'imagingSystemSettings' 'channelAvailableInputRanges' 'channelDisplayFunction'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Channels';                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {'channelMergeColor'};   % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {'channelOffset','channelSubtractOffset','channelLUT'}; % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                      % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};                   % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};             % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                   % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods
        function obj = Channels(hSI)
            obj = obj@scanimage.interfaces.Component(hSI);
        end
    end
    
    %% PROP ACCESS
    methods
        function val = get.channelLUTRange(obj)
            n = double(obj.hSI.hScan2D.channelsAdcResolution);
            %Set maximum LUT value at 100% of maximum range from framegrabber
            val = [(-2^(n-1)) 2^(n-1)-1];
        end
        
        function set.channelLUT(obj, val)
            ov = obj.channelLUT;
            obj.channelLUT = val;
            
            % hDisplay will only automatically update channels 1:4
            for i = 5:min([numel(ov) numel(val) obj.channelsAvailable])
                if any(val{i} ~= ov{i})
                    obj.hSI.hDisplay.zprpUpdateChanLUT(i,val{i});
                end
            end
            for i = 1:min(4,obj.channelsAvailable)
                obj.hSI.hDisplay.(sprintf('chan%dLUT',i)) = val{i};
            end
            for i = (obj.channelsAvailable+1):4
                obj.hSI.hDisplay.(sprintf('chan%dLUT',i)) = [0 100];
            end
        end
        
        function val = get.channelLUT(obj)
            val = obj.channelLUT;
            for i = 1:min(4,obj.channelsAvailable)
                val{i} = obj.hSI.hDisplay.(sprintf('chan%dLUT',i));
            end
        end
        
        function set.channelsActive(obj,val)
            obj.mdlDummySetProp(val,'channelsActive');
        end
        
        function val = get.channelsActive(obj)
            val = union(obj.channelDisplay,obj.channelSave);
        end

        function set.channelMergeColor(obj,val)
            val = obj.validatePropArg('channelMergeColor',val); %allow during acq
            if obj.componentUpdateProperty('channelMergeColor',val)
                val = obj.zprpEnsureChannelPropSize(val);
                obj.channelMergeColor = val;
            end
        end
        
        function set.channelName(obj,val)
            if obj.componentUpdateProperty('channelName',val)
                obj.channelName = val;
                if ~obj.hSI.imagingSystemChangeInProgress
                    obj.hSI.hDisplay.resetDisplayFigs(1:length(val),false);
                end
            end
        end
        
        function set.channelDisplay(obj,val)
            val = obj.validatePropArg('channelDisplay',val);
            if isempty(union(val,obj.channelSave))
                most.idioms.warn('At least one channel must be selected for display or logging');
            end
            
            if obj.componentUpdateProperty('channelDisplay',val)
                oldVal = obj.channelDisplay;
                activatedChans = setdiff(val,oldVal);
                
                obj.channelDisplay = val;
                
                if obj.mdlInitialized && ~obj.hSI.imagingSystemChangeInProgress
                    obj.hSI.hDisplay.resetDisplayFigs(activatedChans,false);
                end
            end
        end

        function set.channelSave(obj,val)
            val = obj.validatePropArg('channelSave',val);
            if isempty(union(val,obj.channelDisplay))
                most.idioms.warn('At least one channel must be selected for display or logging');
            end
            
            if obj.componentUpdateProperty('channelSave',val)
                obj.channelSave = val;
            end
        end
        
        function set.channelOffset(obj,val)
            if ~isempty(obj.hSI.hScan2D) && ~any(isnan(val))
                val = obj.validatePropArg('channelOffset',val);
                if obj.componentUpdateProperty('channelOffset',val)
                    val = obj.ensureChannelPropSize(val,'row');
                    obj.hSI.hScan2D.channelOffsets = val(1:obj.channelsAvailable);
                end
            end
        end
        
        function val = get.channelOffset(obj)
            val = [];
            if ~isempty(obj.hSI.hScan2D)
                val = [obj.hSI.hScan2D.channelOffsets];
            end
        end
        
        function set.channelInputRange(obj,val)
            if ~isempty(obj.hSI.hScan2D) && (iscell(val) || ~any(isnan(val)))
                val = obj.validatePropArg('channelInputRange',val);
                if obj.componentUpdateProperty('channelInputRange',val)
                    val = obj.ensureChannelPropSize(val,'row');
                    obj.hSI.hScan2D.channelsInputRanges = val(1:obj.channelsAvailable);
                end
            end
        end
        
        function val = get.channelInputRange(obj)
            val = [];
            if ~isempty(obj.hSI.hScan2D)
                val = obj.hSI.hScan2D.channelsInputRanges;
            end
        end
        
        function set.channelAvailableInputRanges(~,~)
        end
        
        function val = get.channelAvailableInputRanges(obj)
            val = obj.hSI.hScan2D.channelsAvailableInputRanges;
        end
        
        function set.channelSubtractOffset(obj,val)
            if ~isempty(obj.hSI.hScan2D) && ~any(isnan(val))
                val = obj.validatePropArg('channelSubtractOffset',val);
                if obj.componentUpdateProperty('channelSubtractOffset',val)
                    val = obj.ensureChannelPropSize(val,'row');
                    obj.hSI.hScan2D.channelsSubtractOffsets = logical(val(1:obj.channelsAvailable));
                end
            end
        end
        
        function val = get.channelSubtractOffset(obj)
            val = [];
            if ~isempty(obj.hSI.hScan2D)
                val = obj.hSI.hScan2D.channelsSubtractOffsets;
            end
        end
        
        function set.imagingSystemSettings(obj,val)
            val = obj.validatePropArg('imagingSystemSettings',val);
            if obj.componentUpdateProperty('imagingSystemSettings',val)
                obj.imagingSystemSettings = val;
            end
        end
    end
    
    %% USER METHODS
    methods
        function registerChannels(obj)
            % Save settings for the current system
            obj.saveCurrentImagingSettings();
            
            obj.currentImagingSystem = obj.hSI.imagingSystem;
            % Restore settings for this imaging system
            obj.channelsAvailable = obj.hSI.hScan2D.channelsAvailable;

            if ~isfield(obj.imagingSystemSettings, obj.hSI.imagingSystem)
                % No settings for this imaging system. Create them
                for iter = 1:obj.channelsAvailable
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelName{iter} = sprintf('Channel %d',iter);
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelType{iter} = 'stripe';
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelDisplayFunction{iter} = 'displayStripe';
                    
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelAdcResolution{iter} = obj.hSI.hScan2D.channelsAdcResolution;
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelMergeColor{iter} = 'red';
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelLUT{iter} = [0 100];
                end
                
                %Default set the first channel to display.
                obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelDisplay(1) = 1;
                %Default set the first channel to save. Logging won't be enabled until the Main window's enable button is.
                obj.imagingSystemSettings.(obj.hSI.imagingSystem).channelSave(1) = 1;
                obj.imagingSystemSettings.(obj.hSI.imagingSystem).displayRollingAverageFactor = 1;
            end
                        
            props = fieldnames(obj.imagingSystemSettings.(obj.hSI.imagingSystem));
            for i = 1:numel(props)
                if ismember(props{i}, obj.IMAGING_SYSTEM_SETTINGS_PROPS);
                    obj.(props{i}) = obj.imagingSystemSettings.(obj.hSI.imagingSystem).(props{i});
                elseif ismember(props{i}, obj.DISPLAY_SETTINGS_PROPS)
                    obj.hSI.hDisplay.(props{i}) = obj.imagingSystemSettings.(obj.hSI.imagingSystem).(props{i});
                else
                    obj.imagingSystemSettings.(obj.hSI.imagingSystem) = rmfield(obj.imagingSystemSettings.(obj.hSI.imagingSystem), props{i});
                end
            end
            
            obj.channelSubtractOffset = NaN; % update GUI
        end
        
        function saveCurrentImagingSettings(obj)
        %   Save settings for the current system, making sure that cfg/usr loading is not being updated
        %
            if ~isempty(obj.currentImagingSystem) && ~obj.hSI.hConfigurationSaver.cfgLoadingInProgress && ~obj.hSI.hConfigurationSaver.usrLoadingInProgress
                props = obj.IMAGING_SYSTEM_SETTINGS_PROPS;
                
                for i = 1:numel(props)
                    obj.imagingSystemSettings.(obj.currentImagingSystem).(props{i}) = obj.(props{i});
                end
                
                props = obj.DISPLAY_SETTINGS_PROPS;
                for i = 1:numel(props)
                    obj.imagingSystemSettings.(obj.currentImagingSystem).(props{i}) = obj.hSI.hDisplay.(props{i});
                end
            end
        end
    end
    
    %% FRIEND METHODS
    methods (Access = ?scanimage.interfaces.Class)
        function val = registerDisplayFunction(obj,channelNumber,displayFunction)
            val = displayFunction;
            if channelNumber <= obj.channelsAvailable && channelNumber >= 0
                fprintf('Registering display function with channel manager for channel %d.\n',channelNumber);
                obj.channelDisplayFunction{channelNumber} = displayFunction;
            else
                val = [];
            end
        end
    end
    
    %% INTERNAL METHODS 
    methods (Access = protected, Hidden)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            % Do nothing...yet
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            % Do nothing...yet
        end
    end
    
    methods (Access = private)        
        function val = ensureChannelPropSize(obj,val,orientation)
            %Ensure correct size of channel property
            
            if nargin < 3 || isempty(orientation)
                orientation = 'unspecified';
            end
            
            assert(isvector(val),'property value cannot be multi dimensional');            
            numChans = obj.channelsAvailable;
            if length(val) < numChans
                if iscell(val)
                    [val{end+1:numChans}] = deal(val{end});
                else
                    val(end+1:numChans) = val(end);
                end
            else
                val = val(1:numChans);
            end
            
            switch orientation
                case 'unspecified'
                    % nothing to do
                case 'row'
                    val = reshape(val,[1,numChans]);
                case 'column'
                    val = reshape(val,[numChans,1]);
                otherwise
                    error('unknown orientation: %s',orientation);
            end
        end
        
        function val = zprpEnsureChannelPropSize(obj,val)
            %Ensure correct size of channel property
            numChans = obj.channelsAvailable;
            if length(val) < numChans
                if iscell(val)
                    [val{end+1:numChans}] = deal(val{end});
                else
                    val(end+1:numChans) = val(end);
                end
            else
                val = val(1:numChans);
            end
        end
    end
    %% USER EVENTS
    %% FRIEND EVENTS
    %% INTERNAL EVENTS
    
end

%% LOCAL
function s = ziniInitPropAttributes()
%At moment, only application props, not pass-through props, stored here -- we think this is a general rule
%NOTE: These properties are /ordered/..there may even be cases where a property is added here for purpose of ordering, without having /any/ metadata.
%       Properties are initialized/loaded in specified order.
%
s = struct();

s.channelOffset                 = struct('Classes','numeric','Attributes',{{'integer','finite','vector'}},'DependsOn',{{'hSI.imagingSystem','hSI.hScan2D.channelOffsets'}});
s.channelInputRange             = struct('Options','channelAvailableInputRanges','List','fullVector','DependsOn',{{'hSI.imagingSystem','hSI.hScan2D.channelsInputRanges'}});
s.channelAvailableInputRanges   = struct('DependsOn',{{'hSI.imagingSystem','hSI.hScan2D.channelsAvailableInputRanges'}});

s.loggingEnable          = struct('Classes', 'binaryflex', 'Attributes', 'scalar');
s.channelsActive         = struct('DependsOn',{{'channelDisplay','channelSave'}});
s.channelDisplay         = struct('Classes','numeric','Attributes',{{'finite','vector','positive','integer'}},'AllowEmpty',1);
s.channelSave            = struct('Classes','numeric','Attributes',{{'finite','vector','positive','integer'}},'AllowEmpty',1);
s.channelSubtractOffset  = struct('Classes','binaryflex','Attributes',{{'vector'}},'DependsOn',{{'hSI.hScan2D.channelsSubtractOffsets'}});
s.channelMergeColor      = struct('Options',{{'green' 'red' 'blue' 'gray' 'none'}},'List','fullVector');
s.imagingSystemSettings  = struct('Classes','struct');
end


%--------------------------------------------------------------------------%
% Channels.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
