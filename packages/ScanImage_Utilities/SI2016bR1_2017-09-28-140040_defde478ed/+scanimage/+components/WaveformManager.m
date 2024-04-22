classdef WaveformManager < scanimage.interfaces.Component
    %WaveformManager     Functionality to manage and optimize output waveforms

    %%% User Props
    properties (SetObservable, SetAccess = protected, Transient)
        scannerAO = struct();   % Struct containing command waveforms for scanners
    end
    
    properties (Dependent, Transient)
        optimizedScanners;      % Cell array of strings, indicating the scanners for which optimized waveforms are available
    end
    
    properties (SetAccess = immutable, Hidden)
        waveformCacheBasePath;
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'scannerAO'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'WaveformManager'                  % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {} ;                  % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'calibrateScanner','clearCachedWaveform','optimizeWaveforms','clearCache'};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods
        function obj = WaveformManager(hSI)
            obj = obj@scanimage.interfaces.Component(hSI);
            obj.waveformCacheBasePath = fullfile(obj.hSI.classDataDir, sprintf('Waveforms_Cache'));
        end
        
        function delete(obj)
            % No-op
        end
    end
    
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@most.Model(obj);
        end
    end
    
    %% INTERNAL METHODS
    methods (Access = protected, Hidden)
        function componentStart(obj)
        end
        
        function componentAbort(obj)
        end
    end
    
        
    %% Getter/Setter Methods
    methods
        function val = get.optimizedScanners(obj)
            val = {};
            if isfield(obj.scannerAO,'ao_volts') && isfield(obj.scannerAO.ao_volts,'isOptimized');
                fieldnames_ = fieldnames(obj.scannerAO.ao_volts.isOptimized);
                tf = cellfun(@(fn)obj.scannerAO.ao_volts.isOptimized.(fn),fieldnames_);
                val = fieldnames_(tf);
            end
        end
    end
    
    %% USER METHODS
    methods
        function updateWaveforms(obj,forceOptimizationCheck)
            % function to regenerate command waveforms for scanner control
            % automatically checks waveform cache for optimized waveforms
            % waveforms are stored in hSI.hWaveformManger.scannerAO
            %
            % usage:
            %     hSI.hWaveformManager.updateWaveforms()
            %     hSI.hWaveformManager.updateWaveforms(true)  % checks waveform cache even if command waveform has not changed since last call
            
            
            if nargin < 2 || isempty(forceOptimizationCheck)
                forceOptimizationCheck = false;
            end
            
            % generate planes to scan based on motor position etc
            rg = obj.hSI.hScan2D.currentRoiGroup;
            ss = obj.hSI.hScan2D.scannerset;
            sliceScanTime = [];
            if obj.hSI.hStackManager.isFastZ
                zPowerReference = obj.hSI.hStackManager.zPowerReference;
                zs = obj.hSI.hStackManager.zs;
                fb = obj.hSI.hFastZ.numDiscardFlybackFrames;
                waveform = obj.hSI.hFastZ.waveformType;
                zActuator = 'fast';
            elseif obj.hSI.hStackManager.isSlowZ
                zPowerReference = obj.hSI.hStackManager.zPowerReference;
                slc = obj.hSI.hStackManager.slowStackSlicesDone + 1;
                zs = obj.hSI.hStackManager.zs(slc);
                fb = 0;
                waveform = 'slow';
                if obj.hSI.hStackManager.slowStackWithFastZ
                    zActuator = 'fast';
                else
                    zActuator = 'slow';
                end
                if slc == 1
                    sliceScanTime = max(arrayfun(@(z)rg.sliceTime(ss,z),obj.hSI.hStackManager.zs));
                else
                    sliceScanTime =  obj.scannerAO.sliceScanTime;
                end
            else
                if obj.hSI.hStackManager.stageDependentZs
                    zPowerReference = obj.hSI.hStackManager.zPowerReference;
                    zs = obj.hSI.hMotors.motorPosition(3);
                    % if this is a slow stack use hSI.hMotors.stackCurrentMotorZPos
                    % this will better support slow mroi stack
                else
                    zPowerReference = 0;
                    zs = 0;
                end
                
                if obj.hSI.hFastZ.hasFastZ
                    zPowerReference = obj.hSI.hStackManager.zPowerReference;
                    zs = zs + obj.hSI.hFastZ.positionTarget;
                end
                
                fb = 0;
                waveform = '';
                zActuator = '';
            end
            
            % generate ao using scannerset
            [ao_volts_raw, ao_samplesPerTrigger, sliceScanTime, pathFOV] = ...
                rg.scanStackAO(ss,zPowerReference,zs,waveform,fb,zActuator,sliceScanTime,[]);

            if isfield(ao_volts_raw,'G')
                assert(size(ao_volts_raw(1).G,1) > 0, 'Generated AO is empty. Ensure that there are active ROIs with scanfields that exist in the current Z series.');
            end
            
            
            if ~forceOptimizationCheck && ...
               isfield(obj.scannerAO,'ao_volts_raw') && isequal(obj.scannerAO.ao_volts_raw,ao_volts_raw) && ...
               isfield(obj.scannerAO,'ao_samplesPerTrigger') && isequal(obj.scannerAO.ao_samplesPerTrigger,ao_samplesPerTrigger) && ...
               isfield(obj.scannerAO,'sliceScanTime') && isequal(obj.scannerAO.sliceScanTime,sliceScanTime) && ...
               isfield(obj.scannerAO,'pathFOV') && isequal(obj.scannerAO.pathFOV,pathFOV)
                % the newly generated AO is the same as the previous one.
                % no further action required
                return
            else
                %%% check for optimized versions of waveform
                allScanners = fieldnames(ao_volts_raw);
                
                % initialize isOptimized struct
                isOptimized = struct();
                for idx = 1:length(allScanners)
                    isOptimized.(allScanners{idx}) = false;
                end
                
                ao_volts = ao_volts_raw;
                optimizableScanners = intersect(allScanners,ss.optimizableScanners);
                for idx = 1:length(optimizableScanners)
                    scanner = optimizableScanners{idx};
                    waveform = ss.retrieveOptimizedAO(scanner,ao_volts_raw.(scanner));
                    if ~isempty(waveform)
                        ao_volts.(scanner) = waveform;
                        isOptimized.(scanner) = true;
                    end
                end
            end
            
            scannerAO_ = struct();
            scannerAO_.ao_volts_raw         = ao_volts_raw;
            scannerAO_.ao_volts             = ao_volts;
            scannerAO_.ao_volts.isOptimized = isOptimized;
            scannerAO_.ao_samplesPerTrigger = ao_samplesPerTrigger;
            scannerAO_.sliceScanTime        = sliceScanTime;
            scannerAO_.pathFOV              = pathFOV;
            
            obj.scannerAO = scannerAO_;
        end
        
        function resetWaveforms(obj)
            % function to clear hSI.hWaveformManager.scannerAO
            %
            % usage:
            %   hSI.hWaveformManager.resetWaveforms()
            obj.scannerAO = [];
        end
        
        function calibrateScanner(obj,scanner)
            % function to calibrate scanner feedback and offset
            %
            % usage:
            %   hSI.hWaveformManager.calibrateScanner('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('calibrateScanner',scanner)
                assert(~isempty(obj.scannerAO) && isfield(obj.scannerAO,'ao_volts'));
                assert(isfield(obj.scannerAO.ao_volts,scanner));
                
                hWb = waitbar(0,'Calibrating Scanner','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
                try
                    ss = obj.hSI.hScan2D.scannerset;    % Used as the base to reference particular scanners.
                    ss.calibrateScanner(scanner,hWb);
                catch ME
                    hWb.delete();
                    msgbox(ME.message, 'Error','error');
                    rethrow(ME);
                end
                hWb.delete();
            end
        end
        
        function plotWaveforms(obj,scanner)
            % function to plot scanner command waveform for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.plotWaveforms('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            
            assert(~isempty(obj.scannerAO) && isfield(obj.scannerAO,'ao_volts'),'scannerAO is empty');
            assert(isfield(obj.scannerAO.ao_volts,scanner),'scannerAO is empty');
            
            hFig = figure('NumberTitle','off','Name','Waveform Output');
            if obj.scannerAO.ao_volts.isOptimized.(scanner)
                [optimized,metaData] = obj.retrieveOptimizedAO(scanner);
                desired = obj.scannerAO.ao_volts_raw.(scanner);
                numWaveforms = size(metaData,2);
                
                feedback = zeros(size(desired));
                for idx = 1:numWaveforms
                    feedbackWaveformFileName = fullfile(metaData(idx).path,metaData(idx).feedbackWaveformFileName);
                    assert(logical(exist(feedbackWaveformFileName,'file')),'The file %s was not found on disk.',feedbackWaveformFileName);
                    hFile = matfile(feedbackWaveformFileName);
                    feedback(:,idx) = repmat(hFile.volts,metaData(idx).periodCompressionFactor,1);
                end
                
                sampleRateHz = unique([metaData.sampleRateHz]);
                assert(length(sampleRateHz)==1);
                
                tt = (1:size(desired,1))'/sampleRateHz;
                tt = repmat(tt,1,size(desired,2));
                err = feedback - desired;
                
                hAx1 = subplot(4,1,1:3,'Parent',hFig,'NextPlot','add');
                hAx2 = subplot(4,1,  4,'Parent',hFig,'NextPlot','add');
                title(hAx1,'Waveform Output');
                ylabel(hAx1,'Volts');
                xlabel(hAx2,'Time [s]');
                ylabel(hAx2,'Volts');
                set([hAx1,hAx2],'XGrid','on','YGrid','on','Box','on');
                
                linkaxes([hAx1,hAx2],'x');
                set([hAx1,hAx2],'XLim',[tt(1),tt(end)*1.02]);
                
                for idx = 1:numWaveforms
                    scannerName = metaData(idx).linearScannerName;
                    plot(hAx1,tt(:,idx),  desired(:,idx),'--','LineWidth',2,'DisplayName',sprintf('%s desired',scannerName));
                    plot(hAx1,tt(:,idx),optimized(:,idx),'DisplayName',sprintf('%s command',scannerName));
                    plot(hAx1,tt(:,idx), feedback(:,idx),'DisplayName',sprintf('%s feedback',scannerName));
                    
                    plot(hAx2,tt(:,idx),err(:,idx),'DisplayName',sprintf('%s error',scannerName));
                end
                
                legend(hAx1,'show');
                legend(hAx2,'show');
                
                rms = sqrt(sum(err.^2,1) / size(err,1));
                uimenu('Parent',hFig,'Label','Optimization Info','Callback',@(varargin)showInfo(metaData,rms));
                
            else
                hAx = axes('Parent',hFig,'XGrid','on','YGrid','on','Box','on');
                
                if strcmpi(scanner,'SLMxyz')
                    xy = obj.scannerAO.ao_volts.(scanner);
                    plot(hAx,xy(:,1),xy(:,2),'*-');
                    title(hAx,'SLM Output');
                    hAx.YDir = 'reverse';
                    hAx.DataAspectRatio = [1 1 1];
                    xlabel(hAx,'x');
                    ylabel(hAx,'y');
                    grid(hAx,'on');
                else
                    plot(hAx,obj.scannerAO.ao_volts.(scanner));
                    title(hAx,'Waveform Output');
                    xlabel(hAx,'Samples');
                    ylabel(hAx,'Volts');
                    grid(hAx,'on');
                end
            end
            
            function showInfo(metaData,rms)
                infoTxt = {};
                for i = 1:length(metaData);
                    md = metaData(i);
                    infoTxt{i} = sprintf([...
                        '%s\n'...
                        '    Optimization function: %s\n'...
                        '    Optimization date: %s\n'...
                        '    Sample rate: %.1fkHz\n'...
                        '    Iterations: %d\n'...
                        '    RMS: %fV'
                            ],...
                        md.linearScannerName,regexp(md.optimizationFcn,'[^\.]*$','match','once'),...
                        datestr(md.clock),md.sampleRateHz/1e3,md.info.numIterations,rms(i)...
                        );
                end
                infoTxt = strjoin(infoTxt,'\n\n');
                msgbox(infoTxt,'Optimization Info');
            end
        end
    end
    
    methods
        function clearCachedWaveform(obj, scanner)
            % function to clear optimized version of current waveform for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.clearCachedWaveform('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('clearCachedWaveform',scanner)
                ss = obj.hSI.hScan2D.scannerset;
                obj.updateWaveforms();
                assert(~isempty(obj.scannerAO) && isfield(obj.scannerAO,'ao_volts_raw') && isfield(obj.scannerAO.ao_volts_raw,scanner) && ~isempty(obj.scannerAO.ao_volts_raw.(scanner)))
                ss.ClearCachedWaveform(scanner, obj.scannerAO.ao_volts_raw.(scanner));
                obj.updateWaveforms(true);          % Recreate the waveforms
            end
        end
        
        function clearCache(obj, scanner)
            % function to clear all optimized waveforms for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.clearCache('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('clearCache',scanner)
                ss = obj.hSI.hScan2D.scannerset;
                ss.ClearCache(scanner);
                obj.updateWaveforms(true);          % Regenerate waveforms
            end
        end
        
        function optimizeWaveforms(obj,scanner)
            % function to optimized and cache command waveform for specified scanner
            %
            % usage:
            %   hSI.hWaveformManager.optimizeWaveforms('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            if obj.componentExecuteFunction('optimizeWaveforms',scanner)
                try
                    ss = obj.hSI.hScan2D.scannerset;    % Used as the base to reference particular scanners.
                    obj.updateWaveforms();              % Ensure the output waveforms are up to date
                    assert(~isempty(obj.scannerAO.ao_volts_raw) && isfield(obj.scannerAO.ao_volts_raw,scanner)&& ~isempty(obj.scannerAO.ao_volts_raw.(scanner)),...
                        'No waveform for scanner %s generated', scanner);
                    ss.optimizeAO(scanner, obj.scannerAO.ao_volts_raw.(scanner));
                    obj.updateWaveforms(true);          % Recreate the waveforms, force recheck of optimization cache
                catch ME
                    msgbox(ME.message, 'Error','error');
                    rethrow(ME);
                end
            end
        end
        
        function [waveform,metaData] = retrieveOptimizedAO(obj, scanner)
            % function to retrieve optimized waveform from cache for specified scanner
            %
            % usage:
            %   [waveform,metaData] = hSI.hWaveformManager.retrieveOptimizedAO('<scannerName>')
            %       where <scannerName> is one of {'G','Z'}
            
            ss = obj.hSI.hScan2D.scannerset;
            obj.updateWaveforms();
            assert(~isempty(obj.scannerAO.ao_volts_raw) && isfield(obj.scannerAO.ao_volts_raw,scanner) && ~isempty(obj.scannerAO.ao_volts_raw.(scanner)))
            
            [waveform,metaData] = ss.retrieveOptimizedAO(scanner, obj.scannerAO.ao_volts_raw.(scanner));
        end
    end
end

%% LOCAL (after classdef)
function s = ziniInitPropAttributes()
s = struct();
end


%--------------------------------------------------------------------------%
% WaveformManager.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
