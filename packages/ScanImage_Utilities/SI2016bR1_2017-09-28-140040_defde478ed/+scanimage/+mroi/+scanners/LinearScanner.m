classdef LinearScanner < handle
    properties (Abstract, Hidden)
        impulseResponseDuration;
    end
    
    properties
        waveformCacheBasePath = '';
        
        bandwidth = 1000;
        optimizationFcn = @scanimage.mroi.scanners.optimizationFunctions.deconvOptimization;
    end
    
    properties
        hDevice;
        deviceSelfInit = false;
        sampleRateHz = 500e3;
        impulseResponse;
        impulseResponseSampleRate;
    end
    
    properties (Dependent)
        optimizationAvailable;
        waveformCacheScannerPath;
        
        % the following are all passed to/from hDevice. here for convenience
        name;
        simulated;
        calibrationData;
        travelRange;
        voltsPerDistance;
        distanceVoltsOffset;
        parkPosition;
        positionAvailable;
        feedbackAvailable;
        offsetAvailable;
        feedbackCalibrated;
        offsetCalibrated;
        positionDeviceName;
        positionChannelID;
        feedbackDeviceName;
        feedbackChannelID;
        feedbackTermCfg;
        offsetDeviceName;
        offsetChannelID;
        feedbackVoltInterpolant;
        offsetVoltScaling;
        feedbackVoltFcn = [];
        position2VoltFcn = [];
        volt2PositionFcn = [];
    end
    
    %% Lifecycle
    methods
        function obj = LinearScanner(hDevice)
            if nargin < 1
                obj.hDevice = dabs.interfaces.LinearScanner();
                obj.deviceSelfInit = true;
            else
                obj.hDevice = hDevice;
            end
        end
        
        function delete(obj)
            if obj.deviceSelfInit
                most.idioms.safeDeleteObj(obj.hDevice);
            end
        end
    end
    
    %% Setter / Getter methods
    methods
        function set.impulseResponseSampleRate(obj,val)
            if isempty(val)
                val = [];
            else
                validateattributes(val,{'numeric'},{'scalar'});
            end
            
            obj.impulseResponseSampleRate = val;
        end
        
        function set.impulseResponse(obj,val)
            if isempty(val)
                val = [];
            else
                validateattributes(val,{'numeric'},{'vector'});
            end
            
            obj.impulseResponse = val(:);
        end
        
        function val = get.optimizationAvailable(obj)
            val = ~isempty(obj.impulseResponse) && ~isempty(obj.impulseResponseSampleRate);
        end
        
        function val = get.waveformCacheScannerPath(obj)
            if isempty(obj.waveformCacheBasePath) || isempty(obj.hDevice.name)
                val = [];
            else
                val = fullfile(obj.waveformCacheBasePath, obj.hDevice.name);
            end
        end
        
        function val = get.calibrationData(obj)
            val = obj.hDevice.calibrationData;
        end
        
        function set.calibrationData(obj,val)
            obj.hDevice.calibrationData = val;
        end
    end
    
    % Pass through
    methods
        function v = get.name(obj)
            v = obj.hDevice.name;
        end
        
        function v = get.simulated(obj)
            v = obj.hDevice.simulated;
        end
        
        function v = get.travelRange(obj)
            v = obj.hDevice.travelRange;
        end
        
        function v = get.voltsPerDistance(obj)
            v = obj.hDevice.voltsPerDistance;
        end
        
        function v = get.distanceVoltsOffset(obj)
            v = obj.hDevice.distanceVoltsOffset;
        end
        
        function v = get.parkPosition(obj)
            v = obj.hDevice.parkPosition;
        end
        
        function v = get.positionAvailable(obj)
            v = obj.hDevice.positionAvailable;
        end
        
        function v = get.feedbackAvailable(obj)
            v = obj.hDevice.feedbackAvailable;
        end
        
        function v = get.offsetAvailable(obj)
            v = obj.hDevice.offsetAvailable;
        end
        
        function v = get.feedbackCalibrated(obj)
            v = obj.hDevice.feedbackCalibrated;
        end
        
        function v = get.offsetCalibrated(obj)
            v = obj.hDevice.offsetCalibrated;
        end
        
        function v = get.positionDeviceName(obj)
            v = obj.hDevice.positionDeviceName;
        end
        
        function v = get.positionChannelID(obj)
            v = obj.hDevice.positionChannelID;
        end
        
        function v = get.feedbackDeviceName(obj)
            v = obj.hDevice.feedbackDeviceName;
        end
        
        function v = get.feedbackChannelID(obj)
            v = obj.hDevice.feedbackChannelID;
        end
        
        function v = get.feedbackTermCfg(obj)
            v = obj.hDevice.feedbackTermCfg;
        end
        
        function v = get.offsetDeviceName(obj)
            v = obj.hDevice.offsetDeviceName;
        end
        
        function v = get.offsetChannelID(obj)
            v = obj.hDevice.offsetChannelID;
        end
        
        function v = get.feedbackVoltInterpolant(obj)
            v = obj.hDevice.feedbackVoltInterpolant;
        end
        
        function v = get.offsetVoltScaling(obj)
            v = obj.hDevice.offsetVoltScaling;
        end
        
        function v = get.feedbackVoltFcn(obj)
            v = obj.hDevice.feedbackVoltFcn;
        end
        
        function v = get.position2VoltFcn(obj)
            v = obj.hDevice.position2VoltFcn;
        end
        
        function v = get.volt2PositionFcn(obj)
            v = obj.hDevice.volt2PositionFcn;
        end
        
        function set.name(obj,v)
            obj.hDevice.name = v;
        end
        
        function set.simulated(obj,v)
            obj.hDevice.simulated = v;
        end
        
        function set.travelRange(obj,v)
            obj.hDevice.travelRange = v;
        end
        
        function set.voltsPerDistance(obj,v)
            obj.hDevice.voltsPerDistance = v;
        end
        
        function set.distanceVoltsOffset(obj,v)
            obj.hDevice.distanceVoltsOffset = v;
        end
        
        function set.parkPosition(obj,v)
            obj.hDevice.parkPosition = v;
        end
        
        function set.positionAvailable(obj,v)
            obj.hDevice.positionAvailable = v;
        end
        
        function set.feedbackAvailable(obj,v)
            obj.hDevice.feedbackAvailable = v;
        end
        
        function set.offsetAvailable(obj,v)
            obj.hDevice.offsetAvailable = v;
        end
        
        function set.feedbackCalibrated(obj,v)
            obj.hDevice.feedbackCalibrated = v;
        end
        
        function set.offsetCalibrated(obj,v)
            obj.hDevice.offsetCalibrated = v;
        end
        
        function set.positionDeviceName(obj,v)
            obj.hDevice.positionDeviceName = v;
        end
        
        function set.positionChannelID(obj,v)
            obj.hDevice.positionChannelID = v;
        end
        
        function set.feedbackDeviceName(obj,v)
            obj.hDevice.feedbackDeviceName = v;
        end
        
        function set.feedbackChannelID(obj,v)
            obj.hDevice.feedbackChannelID = v;
        end
        
        function set.feedbackTermCfg(obj,v)
            obj.hDevice.feedbackTermCfg = v;
        end
        
        function set.offsetDeviceName(obj,v)
            obj.hDevice.offsetDeviceName = v;
        end
        
        function set.offsetChannelID(obj,v)
            obj.hDevice.offsetChannelID = v;
        end
        
        function set.feedbackVoltInterpolant(obj,v)
            obj.hDevice.feedbackVoltInterpolant = v;
        end
        
        function set.offsetVoltScaling(obj,v)
            obj.hDevice.offsetVoltScaling = v;
        end
        
        function set.feedbackVoltFcn(obj,v)
            obj.hDevice.feedbackVoltFcn = v;
        end
        
        function set.position2VoltFcn(obj,v)
            obj.hDevice.position2VoltFcn = v;
        end
        
        function set.volt2PositionFcn(obj,v)
            obj.hDevice.volt2PositionFcn = v;
        end
    end
    
    %% Public methods
    methods
        function [h,sampleRate] = estimateImpulseResponse(obj,preventTrip)
            if nargin < 2 || isempty(preventTrip)
                preventTrip = true;
            end
            
            %% test waveform
            duration = 100*obj.impulseResponseDuration;
            durationZero = 20*obj.impulseResponseDuration;
            sampleRate = min([obj.sampleRateHz get(obj.hDevice.feedbackTask, 'sampClkMaxRate')...
                get(obj.hDevice.positionTask, 'sampClkMaxRate')]);
            nSamples = ceil(duration * sampleRate);
            nSamples = nSamples+mod(nSamples,2); % ensure even number of samples
            nSamplesZero = ceil(durationZero * sampleRate);
            
            % correlation based method requires white gaussian noise as
            % stimulus with 0 mean
            voltageRange = obj.hDevice.position2Volts(obj.hDevice.travelRange);
            voltageRange = sort(voltageRange);
            
            std_ = diff(voltageRange) ./ 100;
            mean_ = mean(voltageRange);
            stimulus = std_ .* randn(nSamples,1) + mean_;
            stimulus = min(max(stimulus,voltageRange(1)),voltageRange(2)); % cap output
            stimulus(end+1:end+nSamplesZero) = mean_;

            response = obj.testWaveformVolts(stimulus,sampleRate,preventTrip,mean_);
            
            S = fft(stimulus-mean_);
            R = fft(response-mean(response));
            H = R./S;
            
            cutoffsample = round(obj.bandwidth * length(H) / sampleRate)+1; % low pass filter
            H(cutoffsample+1:end-cutoffsample+1) = 0;
            
            h = real(ifft(H));
            
%            h = h(1:ceil(obj.impulseResponseDuration*sampleRate));
            h = h(1:cutoffsample*2);
            h = h./sum(h); % normalize h, area under h needs to be 1
            
            obj.impulseResponse = h;
            obj.impulseResponseSampleRate = sampleRate;
            
%             figure;
%             plot([stimulus,response]);
%             legend('Stimulus','Response');
%             title('Time domain')
%             
%             figure
%             hold on
%             plot(abs(fftshift(S)));
%             plot(abs(fftshift(R)));
%             legend('Stimulus','Response');
%             title('Frequency domain')
%             hold off
%             
%             figure
%             plot(abs(fftshift(H)));
%             title('H');
%             
%             figure
%             plot(real(h));
%             title('Impulse response');
        end

        function plotImpulseResponse(obj)
            l = length(obj.impulseResponse);
            t = linspace(0,(l-1)./obj.impulseResponseSampleRate,l);
            hFig = figure();
            hAx = axes('Parent',hFig);
            plot(hAx,t,obj.impulseResponse);
            xlabel(hAx,'Time [s]');
            ylabel(hAx,'Amplitude [V]');
            title(hAx,sprintf('%s Impulse Response',obj.hDevice.name));
            grid(hAx,'on');
        end
        
        function [h, sampleRate] = resampleImpulseResponse(obj,sampleRate)
            if sampleRate==obj.impulseResponseSampleRate
                h = obj.impulseResponse;
                sampleRate = obj.impulseResponseSampleRate;
            else
                hSamples = length(obj.impulseResponse);
                hTime = hSamples./obj.impulseResponseSampleRate;
            
                newSamples = floor(hTime * sampleRate);
                newTime = newSamples./sampleRate;
            
                samplePoints = linspace(1,newTime./hTime*hSamples,newSamples)';
                h = interp1(obj.impulseResponse,samplePoints,'linear',0);
                h = h./sum(h); % renormalize
            end
        end

        function [waveform,sampleRate] = optimizeWaveform(obj,waveform,sampleRate,cap,preserveFinalPoint)
            if ~obj.optimizationAvailable
                return
            end
            
            if nargin < 4 || isempty(cap)
                cap = true;
            end
            
            if nargin < 5 || isempty(preserveFinalPoint)
                preserveFinalPoint = false;
            end
            
            finalPoint = waveform(end);
            
            h = obj.resampleImpulseResponse(sampleRate);
            
            % ensure h has same length as waveform
            h(length(waveform)+1:end) = []; % truncate if too long
            h(end+1:length(waveform)) = 0;  % pad if too short
            
            ffth = fft(h(:)); % get the frequency response of the scanner
%            ffth(abs(ffth)<0.01)=Inf; % when invert the frequency response, we want to avoid huge values
            
            % low pass filter signal
            cutoffsample = round(obj.bandwidth * length(ffth) / sampleRate); % low pass filter
            ffth(cutoffsample+1:end-cutoffsample+1) = Inf;
            
            deconvfilter = 1./ffth;
            waveformfft = fft(waveform(:)) .* deconvfilter;
            waveform = real(ifft(waveformfft)); % apply the deconvolution filter
            
            %Todo: clean up the start/end of the optimized waveform
            if cap
                voltageRange = sort(obj.hDevice.position2Volts(obj.hDevice.travelRange));
                waveform = min(max(waveform,voltageRange(1)),voltageRange(2)); % cap output
            end
            
            if preserveFinalPoint
                waveform(end) = finalPoint;
            end
        end
        
        function [path,hash] = computeWaveformCachePath(obj,sampleRateHz,desiredWaveform)
            hash = computeWaveformHash(sampleRateHz,desiredWaveform);
            if isempty(obj.waveformCacheScannerPath)
                path = [];
            else
                path = fullfile(obj.waveformCacheScannerPath,hash);
            end
        end
        
        %%
        % Caches the original waveform, sample rate, optimized waveform and
        % feedback (for error calculation) associated with the original
        % waveform. Original waveform and sample rate are used to create an
        % identifier hash to label the .mat file which stores the
        % associated data.        
        function cacheOptimizedWaveform(obj,sampleRateHz,desiredWaveform,outputWaveform,feedbackWaveform,optimizationData,info)
            if nargin<6 || isempty(optimizationData)
                optimizationData = [];
            end
            
            if nargin<7 || isempty(info)
                info = [];
            end
            
            [workingDirectory,hash] = obj.computeWaveformCachePath(sampleRateHz,desiredWaveform);
            if isempty(workingDirectory)
                warning('Could not cache waveform because waveformCacheBasePath or scanner name is not set');
                return
            end
            
            if ~exist(workingDirectory,'dir')
                [success,message] = mkdir(workingDirectory);
                if ~success
                    warning('Creating a folder to cache the optimized waveform failed:\n%s',message);
                    return
                end
            end
            
            metaDataFileName = 'metaData.mat';
            metaDataFileName = fullfile(workingDirectory,metaDataFileName);
            hMetaDataFile = matfile(metaDataFileName,'Writable',true);
            
            idx = 1;
            metaData = struct();
            if isfield(whos(hMetaDataFile),'metaData')
                metaData = hMetaDataFile.metaData;
                idx = numel(metaData)+1;
            end
            
            uuid = most.util.generateUUID;
            metaData(idx).linearScannerName = obj.hDevice.name;
            metaData(idx).hash = hash;
            metaData(idx).clock = clock();
            metaData(idx).optimizationFcn = func2str(obj.optimizationFcn);
            metaData(idx).sampleRateHz = sampleRateHz;
            metaData(idx).desiredWaveformFileName  = 'desiredWaveform.mat';
            metaData(idx).outputWaveformFileName   = sprintf('%s_outputWaveform.mat',uuid);
            metaData(idx).feedbackWaveformFileName = sprintf('%s_feedbackWaveform.mat',uuid);
            metaData(idx).optimizationDataFileName = sprintf('%s_optimizationData.mat',uuid);
            metaData(idx).info = info;
            
            desiredWaveformFileName  = fullfile(workingDirectory,metaData(idx).desiredWaveformFileName);
            outputWaveformFileName   = fullfile(workingDirectory,metaData(idx).outputWaveformFileName);
            feedbackWaveformFileName = fullfile(workingDirectory,metaData(idx).feedbackWaveformFileName);
            optimizationDataFileName = fullfile(workingDirectory,metaData(idx).optimizationDataFileName);
            
            if exist(desiredWaveformFileName,'file')
                delete(desiredWaveformFileName);
            end
            if exist(outputWaveformFileName,'file')
                delete(outputWaveformFileName);
            end
            if exist(feedbackWaveformFileName,'file')
                delete(feedbackWaveformFileName);
            end
            if exist(optimizationDataFileName,'file')
                delete(optimizationDataFileName);
            end
            
            hDesiredWaveformFile      = matfile(desiredWaveformFileName, 'Writable',true);
            hOutputWaveformFile       = matfile(outputWaveformFileName,  'Writable',true);
            hFeedbackWaveformFile     = matfile(feedbackWaveformFileName,'Writable',true);
            hOptimizationDataFileName = matfile(optimizationDataFileName,'Writable',true);
            
            hDesiredWaveformFile.sampleRateHz = sampleRateHz;
            hDesiredWaveformFile.volts = desiredWaveform;
            
            hOutputWaveformFile.sampleRateHz = sampleRateHz;
            hOutputWaveformFile.volts = outputWaveform;
            
            hFeedbackWaveformFile.sampleRateHz = sampleRateHz;
            hFeedbackWaveformFile.volts = feedbackWaveform;
            
            hOptimizationDataFileName.data = optimizationData;
            
            hMetaDataFile.metaData = metaData; % update metaData file
        end
        
        % Clears every .mat file in the caching directory indicated by dir
        % or if dir is left empty the default caching directory under
        % [MDF]\..\ConfigData\Waveforms_Cache\LinScanner_#_Galvo\
        function clearCache(obj)
            if isempty(obj.waveformCacheScannerPath)
                warning('Could not clear waveform cache because waveformCacheBasePath or scanner name is not set');
            else
                rmdir(obj.waveformCacheScannerPath,'s');
            end
        end

        % Clears a specific .mat file associated with the provided original
        % waveform and sample rate from the default directory or a specifc
        % caching directory (not yet implememted)
        function clearCachedWaveform(obj,sampleRateHz,originalWaveform)
            [available,metaData] = obj.isCached(sampleRateHz,originalWaveform);
            if available
                workingDirectory = metaData.path;
                
                desiredWaveformFileName  = fullfile(metaData.path,metaData.desiredWaveformFileName);
                outputWaveformFileName   = fullfile(metaData.path,metaData.outputWaveformFileName);
                feedbackWaveformFileName = fullfile(metaData.path,metaData.feedbackWaveformFileName);
                optimizationDataFileName = fullfile(metaData.path,metaData.optimizationDataFileName);
                
                if exist(outputWaveformFileName,'file')
                    delete(outputWaveformFileName)
                end
                
                if exist(feedbackWaveformFileName,'file')
                    delete(feedbackWaveformFileName)
                end
                
                if exist(optimizationDataFileName,'file')
                    delete(optimizationDataFileName)
                end
                
                metaDataFileName = fullfile(workingDirectory,'metaData.mat');
                m = matfile(metaDataFileName,'Writable',true);
                metaData_onDisk = m.metaData;
                metaData_onDisk(metaData.metaDataIdx) = [];
                m.metaData = metaData_onDisk;
                
                if isempty(metaData_onDisk)
                   rmdir(workingDirectory,'s');
                end
            end
        end
        
        % Checks whether a cached version of the associated waveform exists
        function [available,metaData] = isCached(obj,sampleRateHz,desiredWaveform)
            available = false;
            metaData = [];
            
            [period,numPeriods] = scanimage.mroi.util.findWaveformPeriodicity(desiredWaveform);
            desiredWaveform = desiredWaveform(1:period);
            
            workingDirectory = obj.computeWaveformCachePath(sampleRateHz,desiredWaveform);
            if isempty(workingDirectory)
                warning('Could not check waveform cache because waveformCacheBasePath or scanner name is not set');
                return
            end
            
            metaDataFileName = fullfile(workingDirectory,'metaData.mat');
            
            if ~exist(metaDataFileName,'file')
                return % did not file metadata
            end
            
            m = matfile(metaDataFileName);
            metaData = m.metaData;
            optFunctions = {metaData.optimizationFcn};
            [tf,idx] = ismember(func2str(obj.optimizationFcn),optFunctions);
            
            if ~tf
                return % did not find optimization for current optimization function
            else
                available = true;
                metaData = metaData(idx);
                metaData.path = workingDirectory;
                metaData.metaDataIdx = idx;
                metaData.periodCompressionFactor = numPeriods;
                metaData.linearScanner = obj;
            end            
        end
        
        % Using an original waveform and sample rate this function double
        % checks the existence of a cached version of the optimized
        % waveform and if it exists loads that cached waveform and the
        % associated error (feedback?)
        function [metaData, outputWaveform, feedbackWaveform, optimizationData] = getCachedOptimizedWaveform(obj,sampleRateHz,desiredWaveform)
            outputWaveform = [];
            feedbackWaveform = [];
            optimizationData = [];
            
            [available,metaData] = obj.isCached(sampleRateHz,desiredWaveform);
            
            if available
                desiredWaveformFileName  = fullfile(metaData.path,metaData.desiredWaveformFileName);
                outputWaveformFileName   = fullfile(metaData.path,metaData.outputWaveformFileName);
                feedbackWaveformFileName = fullfile(metaData.path,metaData.feedbackWaveformFileName);
                optimizationDataFileName = fullfile(metaData.path,metaData.optimizationDataFileName);
                
                numPeriods = metaData.periodCompressionFactor;
                if nargout>1
                    assert(logical(exist(outputWaveformFileName,'file')),'The file %s was not found on disk.',outputWaveformFileName);
                    hFile = matfile(outputWaveformFileName);
                    outputWaveform = hFile.volts;
                    outputWaveform = repmat(outputWaveform,numPeriods,1);
                end
                
                if nargout>2
                    assert(logical(exist(feedbackWaveformFileName,'file')),'The file %s was not found on disk.',feedbackWaveformFileName);
                    hFile = matfile(feedbackWaveformFileName);
                    feedbackWaveform = hFile.volts;
                    feedbackWaveform = repmat(feedbackWaveform,numPeriods,1);
                end
                
                if nargout>3
                    assert(logical(exist(optimizationDataFileName,'file')),'The file %s was not found on disk.',optimizationDataFileName);
                    hFile = matfile(optimizationDataFileName);
                    optimizationData = hFile.volts;
                end
            end
        end
        %%
        % waveformVolts is the desired, feedback is what the galvos
        % actually do, optimized is the adjusted AO out to make feedback ==
        % desired.
        function [optimizedWaveform,err] = optimizeWaveformIteratively(obj, waveformVolts, sampleRateHz, cache) % Perhaps call reCache reOptimize instead? Better clarity maybe. 
            if nargin<4 || isempty(cache)
                cache = true;
            end
            
            assert(obj.positionAvailable,'%s: Position output not initialized', obj.hDevice.name);
            assert(obj.feedbackAvailable,'%s: Feedback input not initialized', obj.hDevice.name);
            
            [period,numPeriods] = scanimage.mroi.util.findWaveformPeriodicity(waveformVolts);
            waveformVolts = waveformVolts(1:period);
            
            desiredWaveform = waveformVolts; % Preserve orignal waveform volts for caching.
            numReps = 5; % minimum of 3
            waveformVolts = waveformVolts(:);
            tt = linspace(0,(length(waveformVolts)-1)/sampleRateHz,length(waveformVolts))';
            
            hFig = figure('NumberTitle','off','MenuBar','none','Toolbar','figure','Name',sprintf('%s waveform optimization',obj.hDevice.name));
            hAx1 = subplot(4,1,[1,2],'NextPlot','add','Box','on');
            ylabel(hAx1,'Signal [V]')
            hPlotDesired = plot(hAx1,tt,zeros(size(tt)),'LineWidth',2);
            hPlotFeedback = plot(hAx1,tt,zeros(size(tt)));
            hPlotOutput = plot(hAx1,tt,zeros(size(tt)),'--');
            legend(hAx1,'Desired','Feedback','Output');
            hAx1.XTickLabel = {[]};
            grid(hAx1,'on');
            
            hAx2 = subplot(4,1,3,'Box','on');
            hPlotError = plot(hAx2,tt,zeros(size(tt)));
            linkaxes([hAx1,hAx2],'x')
            legend(hAx2,'Error');
            xlabel(hAx2,'Time [s]');
            ylabel(hAx2,'Error [V]');
            grid(hAx2,'on');
            
            set([hAx1,hAx2],'XLim',[tt(1),tt(end)*1.02]);
            
            hAx3 = subplot(4,1,4,'Box','on');
            hPlotRms = plot(hAx3,NaN,NaN,'o-');
            hAx3.YScale = 'log';
            xlabel(hAx3,'Iteration');
            ylabel(hAx3,'RMS [V]');
            hAx3.XLim = [1 numReps];
            grid(hAx3,'on');
            
            hWb = waitbar(0,sprintf('%s: Optimizing waveform',obj.hDevice.name),'CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
                
            try
                feedback = obj.hDevice.testWaveformVolts(prepareOutput(waveformVolts),sampleRateHz,true,waveformVolts(1),false,hWb);
                feedback = processFeedback(feedback);
                err = feedback - waveformVolts;
                optimizedWaveform = waveformVolts;
                rmsHistory = rms(err);
                plotWvfs();
                
                optimizationData = [];
                
                done = false;
                iterationNumber  = 0;
                while ~done
                    iterationNumber = iterationNumber+1;
                    [done,optimizedWaveform,optimizationData] = obj.optimizationFcn(obj,iterationNumber,sampleRateHz,waveformVolts,optimizedWaveform,feedback,optimizationData);
                    optimizedWaveform = min(max(optimizedWaveform,-10),10); % clamp output
                    
                    feedback = obj.hDevice.testWaveformVolts(prepareOutput(optimizedWaveform),sampleRateHz,false,optimizedWaveform(1),false,hWb);
                    feedback = processFeedback(feedback);
                    
                    err = feedback - waveformVolts;
                    rmsHistory(end+1) = rms(err);
                    
                    plotWvfs();
                end
                
                % park the galvo
                obj.hDevice.smoothTransitionVolts(waveformVolts(end),obj.hDevice.position2Volts(obj.hDevice.parkPosition));
                
                if cache
                    waitbar(1,hWb,sprintf('%s: Caching waveform',obj.hDevice.name));
                    optimizationData = []; % for later use
                    info = struct;
                    info.numIterations = iterationNumber;
                    info.calibrationData = obj.hDevice.calibrationData;
                    obj.cacheOptimizedWaveform(sampleRateHz,desiredWaveform,optimizedWaveform,feedback,optimizationData,info);
                end
                
                optimizedWaveform = repmat(optimizedWaveform,numPeriods,1);
                err = repmat(err,numPeriods,1);
            
            catch ME
                hWb.delete();
                rethrow(ME);
            end
            hWb.delete();
            
            %%% local functions
            function plotWvfs()
                if isvalid(hPlotDesired) && isvalid(hPlotFeedback) && isvalid(hPlotOutput)
                    hPlotDesired.YData = waveformVolts;
                    hPlotFeedback.YData = feedback;
                    hPlotOutput.YData = optimizedWaveform;
                end
                
                if isvalid(hPlotError)
                    hPlotError.YData = err;
                end
                
                if isvalid(hPlotRms)
                    hPlotRms.XData = 1:length(rmsHistory);
                    hPlotRms.YData = rmsHistory;
                    hAx_ = ancestor(hPlotRms,'axes');
                    hAx_.XLim = [1 max(length(rmsHistory),hAx_.XLim(2))];
                end
                drawnow('limitrate');
            end
            
            function output = prepareOutput(output)
                output = repmat(output,numReps,1);
            end
            
            function feedback = processFeedback(feedback)
                feedback = reshape(feedback,[],numReps);
                feedback = mean(feedback(:,2:end),2);
            end
            
            function v = rms(err)
                v = sqrt(sum(err.^2) / numel(err));
            end
        end
    end
    
    % pass thru
    methods
        function varargout = feedbackVolts2Position(obj,varargin)
            [varargout{1:nargout}] = obj.hDevice.feedbackVolts2Position(varargin{:});
        end
        
        function v = position2Volts(obj,v)
            v = obj.hDevice.position2Volts(v);
        end
    end
end

function hash = computeWaveformHash(sampleRateHz,originalWaveform)
    originalWaveform = round(originalWaveform * 1e6); % round to a precision of 1uV to eliminate rounding errors
    hash = most.util.dataHash({originalWaveform,sampleRateHz});
end


%--------------------------------------------------------------------------%
% LinearScanner.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
