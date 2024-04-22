classdef WSConnector < scanimage.interfaces.Component
%classdef WSConnector < most.Model & most.HasMachineDataFile
%

%+++ removed MachineDataFile addition for now. This must be reintegrated

%classdef WSConnectorModel < most.Model & most.MachineDataFile
    %WSCONNECTORMODEL Module for integrating SI4 with WaveSurfer 0.5 bys 
    % Points of integration:
    %   * Unified CFG/USR file save/load
    %   * Coordinated data file names
    %   % Coordinated start/stop
        
    %% PUBLIC PROPS
    properties (SetObservable)
        enable = false; %Logical specifying whether WaveSurfer master mode is enabled
    end
    
    %% LIFE CYCLE
    methods
        function obj = WSConnector(hSI)
            %assert(scim_isRunning == 4, 'ScanImage 4.x must be running to use class ''%s''',mfilename('class'));
            %obj.hSI = evalin('base','hSI');
            obj = obj@scanimage.interfaces.Component(hSI,[]);
            
            obj.hAcqStateListener  = addlistener(obj.hSI,'acqState','PostSet',@obj.zzChangedAcqState);
            
            obj.hPollTimer = timer( 'Name', 'WSConnector timer',...
                                    'Period', obj.POLL_INTERVAL,...
                                    'StartDelay',obj.POLL_INTERVAL,...
                                    'ExecutionMode','fixedRate',...
                                    'TimerFcn',@obj.zzPollTimerFcn);
        end
        
        function delete(obj)
            obj.enable = false;
            most.idioms.safeDeleteObj(obj.hAcqStateListener);
            most.idioms.safeDeleteObj(obj.hPollTimer);
        end
    end
    
    %% PROP ACCESS METHODS
    methods
        function set.enable(obj,val)
            %This is not working correctly???+++
            val = obj.validatePropArg('enable',val);
            obj.enable = val;
            
            isIdle = strcmpi(obj.hSI.acqState,'idle');
            if isIdle && obj.enable
                stop(obj.hPollTimer); %defensive - why is this ever needed?
                start(obj.hPollTimer);
            else
                stop(obj.hPollTimer);
            end
        end
    end
    
    %% PUBLIC METHODS
    methods
    end
    
    

    %% HIDDEN METHODS
    methods (Hidden)
        
        function zzSaveSIPropFile(obj,fid,fileType)
            %Save ScanImage prop file (CFG or USR), cloning file stem of
            %corresponding WaveSurfer prop file
            
            fileType = lower(fileType);
            assert(ismember(fileType,{'cfg' 'usr'}));

            %Get WS filename parts
            fileNameToken  = '|';
            [~,wsFileName] = strtok(fgetl(fid),fileNameToken);
            wsFileName = strtrim(wsFileName(2:end));
            
            [wsPath,wsFileStem] = fileparts(wsFileName);
            
            %Determine SI path and filename
            %   For now, it is required to have a usr/cfg file loaded before yoking to WS
            %   The spec should be revised in regards to this behavior +++
            currentSIFile = obj.hSI.hConfigurationSaver.(sprintf('%sFilename',fileType));
            if isempty(currentSIFile)
                most.idioms.dispError('WARNING (%s): No ScanImage directory has been created for ''%s'' file types. Unable to save yoked ScanImage file.\n',mfilename('class'),fileType);
                return;
            else
                siPath = fileparts(currentSIFile);
            end
            
            siFileName = fullfile(siPath,[wsFileStem '.' fileType]); 
            
            %Save SI prop file            
            switch fileType
                case 'cfg'
                    funcName = 'cfgSaveConfig';
                case 'usr'
                    funcName = 'usrSaveUsr';
            end
            
            %When saving the file
            %   If the filename is the same as the one already in ScanImage,
            %       save it
            %   Else, 
            %       Call 'Save As ...' mode
            if strcmpi(siFileName,currentSIFile)
                feval(funcName,obj.hSI.hConfigurationSaver);
            else
                feval([funcName 'As'],obj.hSI.hConfigurationSaver,siFileName);
                %If it exists, will get a message dialog - should
                %we prevent?
            end
            
        end
                
        function zzLoadSIPropFile(obj,fid,fileType)
            %Load ScanImage prop file (CFG or USR), cloning file stem of
            %corresponding WaveSurfer prop file
            
            fileType = lower(fileType);
            assert(ismember(fileType,{'cfg' 'usr'}));
                      
            %Get WS filename parts
            fileNameToken  = '|';
            [~,wsFileName] = strtok(fgetl(fid),fileNameToken);
            wsFileName = strtrim(wsFileName(2:end));
            
            [wsPath,wsFileStem] = fileparts(wsFileName);
            
            %Determine SI path and filename
            currentSIFile = obj.hSI.hConfigurationSaver.(sprintf('%sFilename',fileType));
            if isempty(currentSIFile)
                most.idioms.dispError('WARNING (%s): No ScanImage directory has been created for ''%s'' file types. Unable to load yoked ScanImage file.\n',mfilename('class'),fileType);
                return;
            else
                siPath = fileparts(currentSIFile);
            end
            
            siFileName = fullfile(siPath,[wsFileStem '.' fileType]); 
            
            %Load SI prop file            
            switch fileType
                case 'cfg'
                    funcName = 'cfgLoadConfig';
                case 'usr'
                    funcName = 'usrLoadUsr';
            end
            
            % Only call uigetfile-using functions when the file doesn't exist
            % hConfigurationSaver's function for opening already has these tests
            feval(funcName,obj.hSI.hConfigurationSaver,siFileName);

        end
                
        
        function zzChangedAcqState(obj,src,evnt)
            isIdle = strcmpi(obj.hSI.acqState,'idle');
            if isIdle && obj.enable
                stop(obj.hPollTimer); %defensive - why is this ever needed?
                start(obj.hPollTimer);
            else
                stop(obj.hPollTimer);
            end            
        end
        
        function zzPollTimerFcn(obj,src,evnt)
            
            %Ignore timer calls started while SI is active
            isIdle = strcmpi(obj.hSI.acqState,'idle');
            if ~isIdle
                return;
            end

            %Look for Wavesurfer command file
            wsCmdFile = fullfile(tempdir,'si_command.txt');
            if ~exist(wsCmdFile,'file')
                return;
            end
            
            fid = fopen(wsCmdFile,'r');
           
            ME = [];
            try
                cmd = fgetl(fid);
                
                switch cmd
                    case 'Arming'
                        C = textscan(fid,'%s %s','Delimiter','|');
                        
                        paramNames = C{1};
                        paramVals = C{2};
                        paramVals = cellfun(@strtrim,paramVals,'UniformOutput',false);
                        
                        %+++ Add better validation
                        %If the contents of si_command are not exactly as shown here
                        %this error might be hard to debug.
                        %trigPFI = str2double(paramVals{1});
                        %trigEdge = paramVals{2};
                        firstAcqNum = str2double(paramVals{1});
                        numAcqs = str2double(paramVals{2});
                        isLogging =  str2num(paramVals{3});
                        dataFullFileName = paramVals{4};
                        dataFileStem = paramVals{5};
                        
                        %Set acq/file props
                        if isLogging
                            obj.hSI.hChannels.loggingEnable = true;
                            %+++NOTE: Consider making this an option.
                            % The following line must be removed to let the user set the save path
                            % as opposed to WS setting it
                            obj.hSI.hScan2D.logFilePath = fileparts(dataFullFileName);
                            obj.hSI.hScan2D.logFileStem = dataFileStem;
                            obj.hSI.hScan2D.logFileCounter = firstAcqNum;                            
                        else
                            obj.hSI.hChannels.loggingEnable = false;
                        end
                        
                        if numAcqs == 1
                            obj.hSI.startGrab();
                        elseif numAcqs > 1
                            obj.hSI.acqsPerLoop = numAcqs;
                            obj.hSI.startLoop();
                        end
                        
                        stop(src);                        
                        
                    %+++Restore functionality to the following 4 cases
                    case 'Saving protocol file'
                        obj.zzSaveSIPropFile(fid,'cfg');
                        
                    case 'Saving user settings file'
                        obj.zzSaveSIPropFile(fid,'usr');

                    case 'Opening protocol file'
                        obj.zzLoadSIPropFile(fid,'cfg');
                        
                    case 'Opening user settings file'
                        obj.zzLoadSIPropFile(fid,'usr');
                        
                    otherwise
                        error('Unsupported command detected: ''%s''',cmd);
                end
            catch MEtemp
                ME = MEtemp;
            end
            
            fclose(fid);
            if exist(wsCmdFile,'file')
                delete(wsCmdFile);
            end
            
            if ~isempty(ME)
                ME.rethrow()
            else
                %SEnd reply
                fid = fopen(fullfile(tempdir,'si_response.txt'),'w');
                fprintf(fid,'OK\n');
                fclose(fid);
            end
        end
        
    end
    
    
    %% HIDDEN PROPS
    properties (Hidden, SetAccess=protected)
        %hSI;
        
        hAcqStateListener; 
        hPollTimer;        
        
    end
    
    properties (Hidden, Constant)
       POLL_INTERVAL = 0.5; 
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlInitSetExcludeProps;
        mdlHeaderExcludeProps;
    end

    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.Model)
    %properties (Hidden,SetAccess=protected)
    %end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.MachineDataFile)
    properties (Constant, Hidden)
        COMPONENT_NAME = 'WSConnector';                 % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                     % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};               % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'enable'};             % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};                  % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};            % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end

    %%% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            %stop(obj.hDisplayRefreshTimer);
        end
    end

end

%% LOCAL
function s = ziniInitPropAttributes()
s = struct();
s.enable = struct('Classes','binarylogical');
end


%--------------------------------------------------------------------------%
% WSConnector.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
