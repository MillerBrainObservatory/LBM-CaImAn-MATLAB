classdef WSConnector < scanimage.interfaces.Component
%classdef WSConnectorModel < most.Model
    %WSCONNECTORMODEL Module for integrating SI4 with WaveSurfer 0.5 bys 
    % Points of integration:
    %   * Unified CFG/USR file save/load
    %   * Coordinated data file names
    %   % Coordinated start/stop
        
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlInitSetExcludeProps;
        mdlHeaderExcludeProps = 'PROTOCOL_VERSION';
    end

    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'WSConnector';                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                   % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% HIDDEN PROPS
    properties (SetObservable)
        communicationTimeout = 5;   % communication timeout in seconds
    end
    
    properties (Constant, Transient)
        PROTOCOL_VERSION = '2.0.0';
    end
    
    properties (Hidden, SetAccess=private)
        hPollTimer;
        hListeners;
    end
    
    properties (Hidden, Constant)
       POLL_INTERVAL = 0.5;
    end
        
    %% PUBLIC PROPS
    properties (SetObservable, Transient)
        enable = false; %Logical specifying whether WaveSurfer master mode is enabled
    end
    
    properties (Hidden, SetAccess = private)
        executingWaveSurferCommandNow = false;
    end
    
    properties (Hidden)
        communicationDir = tempdir();
        
        wsCmdFileName = 'ws_command.txt';
        wsRspnsFileName = 'ws_response.txt';
        
        siCmdFileName = 'si_command.txt';
        siRspnsFileName = 'si_response.txt';
    end
    
    properties (Hidden, Dependent)
        wsCmdFullPath;
        wsRspnsFullPath;
        siCmdFullPath;
        siRspnsFullPath;
    end
    
    %% LIFE CYCLE
    methods
        function obj = WSConnector(hSI)
            %assert(scim_isRunning == 4, 'ScanImage 4.x must be running to use class ''%s''',mfilename('class'));
            %obj.hSI = evalin('base','hSI');
            obj = obj@scanimage.interfaces.Component(hSI,[]);
            
            obj.hPollTimer = timer( 'Name', 'WSConnector timer',...
                                    'Period', obj.POLL_INTERVAL,...
                                    'StartDelay',obj.POLL_INTERVAL,...
                                    'ExecutionMode','fixedSpacing',...
                                    'TimerFcn',@obj.zzPollTimerFcn,...
                                    'ErrorFcn',@(src,evt)obj.disableYoking);
                                
            obj.ensureCommunicationFilesGone();
            
            obj.hListeners = addlistener(obj.hSI.hUserFunctions,'usrFileSaved',@obj.saveUserFile);
            obj.hListeners(end+1) = addlistener(obj.hSI.hUserFunctions,'usrFileLoaded',@obj.loadUserFile);
            obj.hListeners(end+1) = addlistener(obj.hSI.hUserFunctions,'cfgFileSaved',@obj.saveConfigurationFile);
            obj.hListeners(end+1) = addlistener(obj.hSI.hUserFunctions,'cfgFileLoaded',@obj.loadConfigurationFile);
        end
        
        function delete(obj)
            obj.enable = false;
            most.idioms.safeDeleteObj(obj.hPollTimer);
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.ensureCommunicationFilesGone();
        end
    end
    
    %% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(obj,acqType)
            if ~obj.enable
                return
            end
            
            if ~ismember(acqType,{'loop','grab'})
                return
            end
            
            if strcmpi(acqType,'loop')
                numAcqs = obj.hSI.acqsPerLoop;
            else
                numAcqs = 1;
            end
            
            cmds = {};
            params = {};
            
            if obj.hSI.hChannels.loggingEnable
                executionMode = 'record';
                if isempty(obj.hSI.hScan2D.logFilePath)
                    logFilePath_ = pwd();
                else
                    logFilePath_ = obj.hSI.hScan2D.logFilePath;
                end
                
                cmds{end+1} = 'set-data-file-folder-path';
                params{end+1} = logFilePath_;
                
                cmds{end+1} = 'set-data-file-base-name';
                params{end+1} = obj.hSI.hScan2D.logFileStem;
                
                cmds{end+1} = 'set-is-session-number-included-in-data-file-name';
                params{end+1} = 0;
                
                
                cmds{end+1} = 'set-is-date-included-in-data-file-name';
                params{end+1} = 0;
            else
                executionMode = 'play';
            end
            
            cmds{end+1} = 'set-index-of-first-sweep-in-run';
            params{end+1} = obj.hSI.hScan2D.logFileCounter;
            
            cmds{end+1} = 'set-number-of-sweeps-in-run';
            params{end+1} = numAcqs;

            obj.sendWsCommands(cmds,params);
            obj.sendWsCommands(executionMode); % this cannot be appended to cmds because WS does not acknowledge correctly
        end
        
        function componentAbort(obj,completedAcquisitionSuccessfully)
            if ~obj.enable
                return
            end
            
            if nargin < 2 || isempty(completedAcquisitionSuccessfully)
                completedAcquisitionSuccessfully = false;
            end
            
            % aborting wavesurfer currently does not work, because the
            % wavesurfer play and record commands are blocking,
            % uninterruptable function calls
            if completedAcquisitionSuccessfully
                obj.sendWsCommands('did-complete-acquisition-mode-normally');
            else
                obj.sendWsCommands('stop');
            end
        end
    end
    
    %% PROP ACCESS METHODS
    methods
        function set.enable(obj,val)
            oldVal = obj.enable;
            val = obj.validatePropArg('enable',val);
            
            errorMsg = [];
            if ~oldVal && val && ~strcmpi(obj.hSI.acqState,'idle')
                errorMsg = 'Cannot enable Yoking while ScanImage is active';
                val = false;
            end
            
            if val ~= oldVal
                try
                    obj.ensureCommunicationFilesGone(); % delete all communication files on status change
                catch
                    val = false;
                    errorMsg = 'Cannot remove WaveSurfer Yoking files.';
                end
                
                if ~val
                    obj.disconnect(); %TODO: CLEAN THIS UP
                end
            end
            
            obj.enable = val;
            
            obj.ensurePollingTimerState();
            
            try
                obj.connect();
            catch ME
                obj.enable = false;
                errordlg('Could not connect to WaveSurfer. Is WaveSurfer running?','Connection Error');
                rethrow(ME);
            end
            
            if ~isempty(errorMsg)
                error(errorMSg);
            end
        end
        
        function connect(obj)
            if obj.enable
                obj.sendWsCommands('connect',obj.PROTOCOL_VERSION);
                fprintf('WaveSurfer connection successful\n');
            end
        end
        
        function ping(obj)
            assert(obj.enable,'WaveSurfer is not connected');
            obj.sendWsCommands('ping');
        end
        
        function disconnect(obj)
            if obj.enable
                obj.sendWsCommands('disconnect');
                fprintf('WaveSurfer disconnected\n');
            end
        end
        
        function sendErrorMsg(obj,ME)
            if obj.enable
                obj.sendWsCommands('error',ME.message);
            end
        end
        
        function ensurePollingTimerState(obj)
            timerActive = strcmpi(obj.hPollTimer.Running,'on');
            if obj.enable && ~timerActive
                start(obj.hPollTimer);
            elseif ~obj.enable && timerActive
                stop(obj.hPollTimer);
            end
        end
        
        function val = get.wsCmdFullPath(obj)
            val = fullfile(obj.communicationDir,obj.wsCmdFileName);
        end
        
        function val = get.wsRspnsFullPath(obj)
            val = fullfile(obj.communicationDir,obj.wsRspnsFileName);
        end
        
        function val = get.siCmdFullPath(obj)
            val = fullfile(obj.communicationDir,obj.siCmdFileName);
        end
        
        function val = get.siRspnsFullPath(obj)
            val = fullfile(obj.communicationDir,obj.siRspnsFileName);
        end
        
        function set.communicationDir(obj,val)
            if obj.enable
                obj.enable = false;
            end
            
            if isempty(val)
                val = tempdir();
            end
            
            validateattributes(val,{'char'},{'vector'});
            assert(exist(val,'dir')==7,'Folder %s does not exist / cannot be accessed',val);
            
            obj.communicationDir = val;
        end
    end    

    %% HIDDEN METHODS
    methods (Hidden)  
        function saveUserFile(obj,varargin)
            if ~obj.enable || obj.executingWaveSurferCommandNow
                return
            end
            fname = obj.hSI.hConfigurationSaver.usrFilename;
            obj.sendWsCommands('saving-user-file-at-full-path',fname);
        end
        
        function loadUserFile(obj,varargin)
            if ~obj.enable || obj.executingWaveSurferCommandNow
                return
            end
            fname = obj.hSI.hConfigurationSaver.usrFilename;
            obj.sendWsCommands('loading-user-file-at-full-path',fname);
        end
        
        function saveConfigurationFile(obj,varargin)
            if ~obj.enable || obj.executingWaveSurferCommandNow
                return
            end
            fname = obj.hSI.hConfigurationSaver.cfgFilename;
            obj.sendWsCommands('saving-configuration-file-at-full-path',fname);
        end
        
        function loadConfigurationFile(obj,varargin)
            if ~obj.enable || obj.executingWaveSurferCommandNow
                return
            end
            fname = obj.hSI.hConfigurationSaver.cfgFilename;
            obj.sendWsCommands('loading-configuration-file-at-full-path',fname);
        end
        
        function sendWsCommands(obj,cmds,params,timeout)
            if obj.executingWaveSurferCommandNow
                return
            end
            
            if nargin<4 || isempty(timeout)
                timeout = [];
            end
            
            if ischar(cmds)
                cmds = {cmds};
                if nargin>2 && ~isempty(params)
                    params = {params};
                else
                    params = {[]};
                end
            end
            
            strcmd = sprintf('%d\n',length(cmds));
            
            for idx = 1:length(cmds)
                cmd = cmds{idx};
                param = params{idx};
                if isempty(param)
                    strcmd = sprintf('%s%s\n',strcmd,cmd);
                else
                    switch class(param)
                        case {'double'}
                            strcmd = sprintf('%s%s| %d\n',strcmd,cmd,param);
                        case {'char'}
                            strcmd = sprintf('%s%s| %s\n',strcmd,cmd,param);
                        otherwise
                            error('Unknown parameter datatype: ''%s''',class(param));
                    end
                end
            end
            
            obj.sendWsCommandRaw(strcmd,timeout);
        end
        
        function sendWsCommandRaw(obj,cmd,timeout)
            if nargin<3 || isempty(timeout)
                timeout = obj.communicationTimeout;
            end
            
            if obj.executingWaveSurferCommandNow
                % this prevents infinite loops
                return
            end
            
            obj.ensureWsCommunicationFilesGone();
            
            fid = fopen(obj.wsCmdFullPath,'w');
            fprintf(fid,'%s',cmd);
            fclose(fid);
            
            pollingInterval = 0.1;
            
            startTime = tic();
            while toc(startTime) < timeout
                pause(pollingInterval);
                if exist(obj.wsRspnsFullPath,'file')
                    fid = fopen(obj.wsRspnsFullPath);
                    resp = fgetl(fid);
                    fclose(fid);
                    
                    if strcmpi(resp,'OK')
                        obj.ensureWsCommunicationFilesGone();
                        return
                    else
                        obj.ensureWsCommunicationFilesGone();
                        error('Wavesurfer responded with code %s',resp);
                    end
                end
            end
            
            obj.ensureWsCommunicationFilesGone();
            error('WaveSurfer did not respond before timeout');
        end
        
        function zzPollTimerFcn(obj,src,evnt)            
            %Look for Wavesurfer command file
            if exist(obj.siCmdFullPath,'file') 
                str = obj.readAllLines(obj.siCmdFullPath);
                [isComplete,commands] = scanimage.components.WSConnector.parseIncomingCommandFile(str);
                if ~isComplete
                    return
                end
                obj.ensureSiCommunicationFilesGone();
                
                MEtemp = [];
                try
                    obj.executeWsCommands(commands);
                catch ME
                    MEtemp = ME;
                end
                
                % Acknowledge command to wavesurfer
                fid = fopen(obj.siRspnsFullPath,'wt');
                if isempty(MEtemp)
                    fprintf(fid,'OK\n');
                    fclose(fid);
                else
                    fprintf(fid,'ERROR\n');
                    fclose(fid);
                    most.idioms.reportError(MEtemp);
                end
            end
        end
        
        function text = readAllLines(obj,fileName)
            fid = fopen(fileName,'r');
            
            text = {};
            while true
                text_ = fgetl(fid);
                if isequal(text_,-1)
                    break;
                else
                    text{end+1} = text_; %#ok<AGROW>
                end
            end
            
            fclose(fid);
        end
        
        function [cmd,parameters] = parseStr(obj,str) 
            cmd = str{1}; % first line is command
            str(1) = [];
            parameters = cellfun(@(s)strsplit(s,'\s*\|\s*','DelimiterType','RegularExpression'),str,'UniformOutput',false);
        end
        
        function executeWsCommands(obj,commands)
            if obj.executingWaveSurferCommandNow
                error('Cannot interrupt current Wavesurfer command');
            end
            
            if isempty(commands)
                return
            end
            
            obj.executingWaveSurferCommandNow = true;
            try
                for idx = 1:length(commands)
                    obj.executeWsCommand(commands(idx));
                end
            catch ME
                obj.executingWaveSurferCommandNow = false;
                ME.rethrow()
            end
            obj.executingWaveSurferCommandNow = false;
        end
        
        function executeWsCommand(obj,command)
            cmd = command.name;
            params = command.parameters;
            
            switch lower(cmd)
                case 'saving-protocol-file-at-full-path'
                    [fpath,fname,~] = fileparts(params{1}); % strip extension from filepath
                    fullfilepath = fullfile(fpath,[fname '.cfg']);
                    obj.hSI.hConfigurationSaver.cfgSaveConfigAs(fullfilepath);
                case 'opening-protocol-file-at-full-path'
                    [fpath,fname,~] = fileparts(params{1}); % strip extension from filepath
                    fullfilepath = fullfile(fpath,[fname '.cfg']);
                    obj.hSI.hConfigurationSaver.cfgLoadConfig(fullfilepath);
                case 'saving-user-file-at-full-path'
                    [fpath,fname,~] = fileparts(params{1}); % strip extension from filepath
                    fullfilepath = fullfile(fpath,[fname '.usr']);
                    obj.hSI.hConfigurationSaver.usrSaveUsrAs(fullfilepath);
                case 'opening-user-file-at-full-path'
                    [fpath,fname,~] = fileparts(params{1}); % strip extension from filepath
                    fullfilepath = fullfile(fpath,[fname '.usr']);
                    obj.hSI.hConfigurationSaver.usrLoadUsr(fullfilepath);
                case 'set-log-file-counter'
                    obj.hSI.hScan2D.logFileCounter = str2double(params{1});
                case 'set-log-file-folder-path'
                    obj.hSI.hScan2D.logFilePath = params{1};   % what is the difference to data file?
                case 'set-log-file-base-name'
                    obj.hSI.hScan2D.logFileStem = params{1};
                case 'set-acq-count-in-loop'
                    obj.hSI.acqsPerLoop = str2double(params{1});
                case 'set-log-enabled'
                    obj.hSI.hChannels.loggingEnable = logical(str2double(params{1}));
                case 'set-data-file-folder-path'
                    obj.hSI.hScan2D.logFilePath = params{1};
                case 'set-data-file-base-name'
                    obj.hSI.hScan2D.logFileStem = params{1};
                case {'run-complete','acquisition-complete'}
%                    obj.hSI.abort();
                case 'loop'
                    obj.hSI.startLoop();
                case 'grab'
                    obj.hSI.startGrab();
                case 'focus'
                    obj.hSI.startFocus();
                case 'did-complete-run-normally'
                    % No-Op
                case 'abort'
                    obj.hSI.abort();
                    error('WS reported an error. Aborting ScanImage acquisition');
                case 'ping'
                    % No-Op
                case 'disconnect'
                    obj.enable = false;
                case 'wavesurfer-is-quitting'
                    obj.enable = false;
                case 'exit'
                    obj.hSI.exit();
                case 'error'
                    % params will specify the error type
                    obj.hSI.abort();
                otherwise
                    error('Received unknown wavesurfer command: %s',cmd);
            end
        end
        
        function disableYoking(obj)
            obj.enable = false;
            fprintf(2,'Error polling WaveSurfer Yoking file. Disabled Yoking.\n');
        end
        
        function ensureCommunicationFilesGone(obj)
            obj.ensureWsCommunicationFilesGone();
            obj.ensureSiCommunicationFilesGone();
        end
        
        function ensureWsCommunicationFilesGone(obj)
            successCmd   = obj.deleteFileWithTimeout(obj.wsCmdFullPath);
            successRspns = obj.deleteFileWithTimeout(obj.wsRspnsFullPath);
            
            assert(successCmd);
            assert(successRspns);
        end
        
        function ensureSiCommunicationFilesGone(obj)
            successCmd = obj.deleteFileWithTimeout(obj.siCmdFullPath);
            successRspns = obj.deleteFileWithTimeout(obj.siRspnsFullPath);
            
            assert(successCmd);
            assert(successRspns);
        end
        
        function success = deleteFileWithTimeout(obj,filePath)
            if ~exist(filePath,'file')
                success = true;
                return
            end
            
            if exist(filePath,'file')
                timeout = 1;
                
                success = false;
                s = tic();
                while true                    
                    success = ~exist(filePath,'file');
                    
                    if success || (toc(s) > timeout)
                        break
                    else
                        try
                            state = warning('off','MATLAB:DELETE:Permission');
                            delete(filePath);
                            warning(state);
                        catch
                            % File might be write protected, or we might not have
                            % permissions
                        end
                        pause(0.1);
                    end
                end
            else
                success = true;
            end
        end
    end
    
    methods (Static)
        function [isComplete, commands] = parseIncomingCommandFile(commandFileText)
            % Each command file from SI contains a set of mini-commands.
            % This thing will not throw if the command file text is merely incomplete, only
            % if it seems to be malformed.
            lines = commandFileText;
            lineCount = length(lines) ;
            if lineCount == 0 ,
                % this is presumably an incomplete file
                isComplete = false ;
                commands = [] ;
            else
                firstLine = lines{1} ;  % should contain number of mini-commands
                commandCount = str2double(firstLine) ;
                if isfinite(commandCount) && commandCount>=0 && round(commandCount)==commandCount ,
                    if lineCount >= commandCount+1 ,
                        commands = struct('name', cell(commandCount,1), ...
                            'parameters', cell(commandCount,1)) ;
                        for commandIndex = 1:commandCount ,
                            line = lines{commandIndex+1} ;
                            if isempty(line) ,
                                % This is odd, but we'll allow it, I guess...
                                name = '' ;
                                parameters = cell(1,0) ;
                            else
                                % Parse the line to get the minicommand and the parameters for it
                                split_line = strsplit(line,'\s*\|\s*','DelimiterType','RegularExpression');
                                name = lower(split_line{1}) ;
                                parameters = split_line(2:end) ;
                            end
                            command = struct('name', {name},  ...
                                'parameters', {parameters}) ;  % a scalar struct
                            commands(commandIndex) = command ;
                        end
                        isComplete = true ;
                    else
                        % There are fewer lines than there should be, so this file is presumably
                        % incomplete.
                        isComplete = false ;
                        commands = [] ;
                    end
                else
                    % the first line does not seem to contain a number of minicommands
                    error('ws:CommandServer:badCommandFile', ...
                        'The command file seems to be badly formed') ;
                end
            end
        end  % function
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
s = struct();
s.enable = struct('Classes','binarylogical');
end

%--------------------------------------------------------------------------%
% WSConnector.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
