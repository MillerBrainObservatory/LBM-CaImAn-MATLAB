classdef PhotonDiscriminator < handle   
    properties (SetObservable)
        autoApplyChanges = false;
        
        %%% Photon Discriminator
        rawDataScaleByPowerOf2 = 0;
        staticNoise = 0;
        differentiate = false;
        filterCoefficients = [-21 14 39 54 59 54 39 14 -21]; % Savitzky-Golay filter kernel, 9 tap
        filterEnabled = false;
        peakThreshold = 0;
        peakDetectionWindowSize = 17;
        peakDebounceSamples = 8;
        phase = 0;
        
        %%% Photon Integrator
        enableIntegrationThreshold = false;
        integrationThreshold = 0;
        differentiateBeforeIntegration = false;
        absoluteValueBeforeIntegration = false;
    end
    
    properties (SetAccess = private, Hidden)
        hSampler;
        hFpga;
        hDelayedEventListener;
        needsUpdate = true;
        simulated = false;
        physicalChannelNumber;
        
        hConfigurationGUI;
    end
    
    properties (Dependent, SetObservable)
        filterDelay;
    end
    
    events (NotifyAccess = private)
        configurationChanged;
    end
    
    methods
        function obj = PhotonDiscriminator(hSampler,physicalChannelNumber)
            if nargin < 1 || isempty(hSampler)
                obj.simulated = true;
                obj.physicalChannelNumber = 0;
            else
                obj.hSampler = hSampler;
                obj.hFpga = obj.hSampler.hFpga;
                obj.physicalChannelNumber = physicalChannelNumber;
            end

            obj.hDelayedEventListener = most.util.DelayedEventListener(0.5,obj,'configurationChanged',@obj.autoUpdateConfigurationCallback);
            obj.autoApplyChanges = true;
            obj.hConfigurationGUI = scanimage.guis.photondiscriminator.PhotonDiscriminatorControl(obj,'off');
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hConfigurationGUI);
            most.idioms.safeDeleteObj(obj.hDelayedEventListener);
        end
        
        function showConfigurationGUI(obj)
            obj.hConfigurationGUI.showFigure();
        end
        
        function s = saveStruct(obj)
            s = struct();
            s.autoApplyChanges = obj.autoApplyChanges;
            s.rawDataScaleByPowerOf2 = obj.rawDataScaleByPowerOf2;
            s.staticNoise = obj.staticNoise;
            s.differentiate = obj.differentiate;
            s.filterCoefficients = obj.filterCoefficients;
            s.peakThreshold = obj.peakThreshold;
            s.peakDetectionWindowSize = obj.peakDetectionWindowSize;
            s.peakDebounceSamples = obj.peakDebounceSamples;
            s.phase = obj.phase;
            s.filterEnabled = obj.filterEnabled;
            s.enableIntegrationThreshold = obj.enableIntegrationThreshold;
            s.integrationThreshold = obj.integrationThreshold;
            s.differentiateBeforeIntegration = obj.differentiateBeforeIntegration;
            s.absoluteValueBeforeIntegration = obj.absoluteValueBeforeIntegration;
        end
        
        function loadStruct(obj,s)
            assert(isa(s,'struct'));
            
            props = fieldnames(s);
            for idx = 1:length(props)
                prop = props{idx};
                try
                    obj.(prop) = s.(prop);
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
    end
    
    methods (Hidden)        
        function propertyChanged(obj)
            obj.needsUpdate = true;
            notify(obj,'configurationChanged');
        end
        
        function autoUpdateConfigurationCallback(obj,src,evt)
            if obj.needsUpdate
                obj.configurePhotonCountingFPGA();
                obj.needsUpdate = false;
            end
        end
        
        function configurePhotonCountingFPGA(obj)
            if obj.simulated
                return
            end
            
            if obj.filterEnabled
                filterCoefficients_ = obj.filterCoefficients;
            else
                filterCoefficients_ = zeros(32,1);
                filterCoefficients_(1) = 1;
            end
            
            chStr = num2str(obj.physicalChannelNumber);
            
            % Photon Discriminator
            obj.hFpga.(['NI5771PhotonCountingRawDataScaleByPowerOf2Channel' chStr]) = obj.rawDataScaleByPowerOf2;
            obj.hFpga.(['NI5771PhotonCountingStaticNoiseChannel' chStr]) = expandStaticNoise(obj.staticNoise);
            obj.hFpga.(['NI5771PhotonCountingDifferentiateChannel' chStr]) = obj.differentiate;
            obj.hFpga.(['NI5771PhotonCountingFilterCoefficientsChannel' chStr]) = filterCoefficients_;
            obj.hFpga.(['NI5771PhotonCountingRawDataDelayChannel' chStr]) = obj.filterDelay; % keep photon counting in sync with integration
            obj.hFpga.(['NI5771PhotonCountingPeakMaskChannel' chStr]) = makePeakWindowMask(obj.peakDetectionWindowSize);
            obj.hFpga.(['NI5771PhotonCountingPeakDebounceMaskChannel' chStr]) = makeDebounceMask(obj.peakDebounceSamples);
            obj.hFpga.(['NI5771PhotonCountingPeakThresholdChannel' chStr]) = obj.peakThreshold;
            obj.hFpga.(['NI5771PhotonCountingPhaseChannel' chStr]) = obj.phase;
            
            % Photon Integrator
            obj.hFpga.(['NI5771PhotonCountingIntegrationThresholdChannel' chStr]) = most.idioms.ifthenelse(obj.enableIntegrationThreshold,obj.integrationThreshold,-2^31);
            obj.hFpga.(['NI5771PhotonCountingDifferentiateIntegrationChannel' chStr]) = obj.differentiateBeforeIntegration;
            obj.hFpga.(['NI5771PhotonCountingAbsoluteValueIntegrationChannel' chStr]) = obj.absoluteValueBeforeIntegration;
            
            function peakMask_uint16 = makePeakWindowMask(windowSize)
                validateattributes(windowSize,{'numeric'},{'scalar','integer','positive','>=',3,'<=',17});
                assert(mod(windowSize,2)==1);
                
                peakMask_uint16 = uint16(0);
                
                for idx = 1:((windowSize-1)/2)
                    peakMask_uint16 = bitset(peakMask_uint16,idx,1);    % peak mask before
                    peakMask_uint16 = bitset(peakMask_uint16,idx+8,1);  % peak mask after
                end
            end
            
            function debounceMask_uint16 = makeDebounceMask(debounceSamples)
                debounceMask_uint16 = zeros(1,1,'uint16');
                for bitidx = 1:debounceSamples
                    debounceMask_uint16 = bitset(debounceMask_uint16,bitidx,true);
                end
            end
            
            function noise = expandStaticNoise(noise)                
                validateattributes(noise,{'numeric'},{'vector','integer','>=',-2^15,'<',2^15});
                assert(length(noise)<=128);
                assert(mod(128,length(noise))==0);
                noise = repmat(noise(:),128/length(noise),1);
            end
        end
    end
    
    methods
        function [denoised,filtered,photonIdxs,photonHistogram] = processDataPipeline(obj,data,plotTF)
            if nargin<3 || isempty(plotTF)
                plotTF = false;
            end
            
            [denoised,filtered] = obj.processData(data);
            [photonIdxs,photonHistogram] = obj.findPhotons(filtered,plotTF);
        end
        
        function [denoised,filtered] = processData(obj,data)            
            data = double(data);
            
            %%% pre-scaling
            validateattributes(obj.rawDataScaleByPowerOf2,{'numeric'},{'integer','nonnegative','<=',8});
            data = bitshift(data,obj.rawDataScaleByPowerOf2,'int16');
            % output of bitshift on FPGA is int16
            
            data = circshift(data,-obj.phase);
            data(end-obj.phase+1:end) = 0;
            
            %%% noise subtraction
            if any(obj.staticNoise~=0)
                validateattributes(obj.staticNoise,{'numeric'},{'vector','integer','>=',-2^15,'<',2^15});
                data = reshape(data,numel(obj.staticNoise),[]);
                data = bsxfun(@minus,data,obj.staticNoise(:));
                denoised = data(:);
                % output of subtraction on FPGA is <+-17,17> -> should not be
            else
                denoised = data;
            end
            
            if obj.differentiate
                denoised = denoised(3:end)-denoised(1:end-2); % centered differentiation
                denoised = [0; denoised; 0];
            end
            
            %%% filter
            if obj.filterEnabled && (obj.filterCoefficients(1)~=1 || any(obj.filterCoefficients(2:end)~=0))
                validateattributes(obj.filterCoefficients,{'numeric'},{'vector','numel',32,'integer','>=',-2^29,'<',2^29});
                filtered = filter(double(obj.filterCoefficients),1,denoised);
                % output on FPGA is <+-,48,48>; we cannot easily bound-check
                % each individual filter stage here
                assert(all((filtered >=-2^47) & (filtered<2^47)),'Overflow in filter stage');
            else
                filtered = denoised;
            end 
        end
        
        function [photonIdxs,photonHistogram,canceled] = findPhotons(obj,processedData,plotTF,progress_cancelFcn)            
            if obj.simulated || obj.hSampler.twoGroups
                numBinsHistogram = 16;
            else
                numBinsHistogram = 8;
            end
            
            if nargin<3 || isempty(plotTF)
                plotTF = false;
            end
            
            if nargin<4 || isempty(progress_cancelFcn)
                progress_cancelFcn = [];
            end
            
            if ~isempty(progress_cancelFcn)
                validateattributes(progress_cancelFcn,{'function_handle'},{'scalar'});
                validateattributes(progress_cancelFcn(),{'numeric','logical'},{'scalar','binary'});
            end
            
            %%% peakDetection
            validateattributes(obj.peakThreshold,{'numeric'},{'scalar','integer','>=',-2^47,'<',2^47});
            validateattributes(obj.peakDebounceSamples,{'numeric'},{'scalar','integer','positive','>=',1,'<=',16});
            validateattributes(obj.peakDetectionWindowSize,{'numeric'},{'scalar','integer','positive','>=',3,'<=',17});
            assert(mod(obj.peakDetectionWindowSize,2)==1,'peakDetectionWindowSize must be an odd number');
            maskBefore = true(1,(obj.peakDetectionWindowSize-1)/2);
            maskAfter  = true(1,(obj.peakDetectionWindowSize-1)/2);
            [photonIdxs,canceled] = scanimage.guis.photondiscriminator.NI5771Sampler.findPeaks(processedData,obj.peakThreshold,maskBefore,maskAfter,obj.peakDebounceSamples,progress_cancelFcn);
            
            if canceled || ~isempty(progress_cancelFcn) && progress_cancelFcn()
                photonIdxs = [];
                photonHistogram = [];
                canceled = true;
                return
            end
            
            photonHistogram = zeros(numBinsHistogram,1);
            photonIdxs_ = mod(photonIdxs-1,numBinsHistogram) + 1;
            
            if nargout>1 || plotTF
                for phtIdx = 1:length(photonIdxs_)
                    photonHistogram(photonIdxs_(phtIdx)) = photonHistogram(photonIdxs_(phtIdx)) + 1;
                end
            end
            
            if plotTF
                hFig = figure();
                hAx1 = subplot(3,1,1);
                plot(hAx1,0:(length(data)-1),data);
                title(hAx1,sprintf('%s\nRaw Data',title_));
                ylabel(hAx1,'ADC value');
                hAx2 = subplot(3,1,2);
                hold on;
                plot(hAx2,0:(length(filtered)-1),filtered);
                plot(hAx2,photonIdxs-1,filtered(photonIdxs),'ro');
                plot(hAx2,[0;(length(filtered)-1)],[threshold,threshold],'r--');
                
                phts = false(size(data));
                phts(photonIdxs) = true;
                
                title(hAx2,sprintf('Peak Detection, Mean= %e Var= %e',mean(phts),std(phts)^2));
                xlabel(hAx2,'Sample #');
                linkaxes([hAx1,hAx2],'x');
                hold off;
                hAx3 = subplot(3,1,3);
                hBarHist = bar(hAx3,0:(length(histogram_)-1),photonHistogram,...
                    'BarWidth',1,'LineStyle','none','FaceColor',most.idioms.vidrioBlue()); 
                title(hAx3,'Photon Histogram');
                xlabel(hAx3,'Sample #');
                ylabel(hAx3,'Photons');
                hAx3.XLim = [-0.5,(length(histogram_)-0.5)];
            end
        end
    end
    
    %% Property Access
    methods
        function set.autoApplyChanges(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.autoApplyChanges = val;
            obj.hDelayedEventListener.enabled = val;
            if val
                obj.propertyChanged();
            end
        end
        
        function set.filterEnabled(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            val = logical(val);
            obj.filterEnabled = val;
            obj.propertyChanged();
        end
        
        function set.filterCoefficients(obj,val)
            if isempty(val)
                val = zeros(1,32);
                val(1) = 1;
            end
            val(end+1:32) = 0;            
            validateattributes(val,{'numeric'},{'vector','numel',32,'integer','>=',-2^29,'<',2^29});
            obj.filterCoefficients = val(:)';
            obj.propertyChanged();
        end
        
        function val = get.filterDelay(obj)
            val = getFilterDelay(obj.filterCoefficients);
        end
        
        function set.peakThreshold(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','>=',-2^47,'<',2^47});
            obj.peakThreshold = val;
            obj.propertyChanged();
        end
        
        function set.peakDetectionWindowSize(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','positive','>=',3,'<=',17});
            assert(mod(val,2)==1,'peakDetectionWindowSize must be an odd number');
            obj.peakDetectionWindowSize = val;
            obj.propertyChanged();
        end
        
        function set.peakDebounceSamples(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','positive','>=',1,'<=',16});
            obj.peakDebounceSamples = val;
            obj.propertyChanged();
        end
        
        function set.phase(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','nonnegative','<=',15});
            obj.phase = val;
            obj.propertyChanged();
        end
        
        function set.rawDataScaleByPowerOf2(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','nonnegative','<=',8});
            obj.rawDataScaleByPowerOf2 = val;
            obj.propertyChanged();
        end
        
        function set.staticNoise(obj,val)
            if isempty(val)
                val = 0;
            end
            validateattributes(val,{'numeric'},{'vector','integer','>=',-2^15,'<',2^15});
            assert(length(val)<=128);
            assert(mod(128,length(val))==0);
            obj.staticNoise = val;
            obj.propertyChanged();
        end
        
        function set.differentiate(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.differentiate = logical(val);
            obj.propertyChanged();
        end
        
        function set.enableIntegrationThreshold(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.enableIntegrationThreshold = val;
            obj.propertyChanged();
        end
        
        function set.integrationThreshold(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','>=',-2^31,'<',2^31});
            obj.integrationThreshold = val;
            obj.propertyChanged();
        end
        
        function set.differentiateBeforeIntegration(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.differentiateBeforeIntegration = val;
            obj.propertyChanged();
        end
        
        function set.absoluteValueBeforeIntegration(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.absoluteValueBeforeIntegration = val;
            obj.propertyChanged();
        end
    end
end

function val = getFilterDelay(filterCoefficients)
    impulse = zeros(size(filterCoefficients));
    impulse(1) = 1;
    y = filter(filterCoefficients,1,impulse);
    [~,idx] = max(y); % find first peak
    val = idx-1;
end

%--------------------------------------------------------------------------%
% PhotonDiscriminator.m                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
