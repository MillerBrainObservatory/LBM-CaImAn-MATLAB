classdef FastZ < scanimage.mroi.scanners.LinearScanner
    % The following are taken from the LSC Pure Analog Controller, but seem
    % like reasonable things for piezo. Add more from FastZ as necessary.
    properties
        flybackTime;
        actuatorLag;
        enableFieldCurveCorr;
        fieldCurveParams;
        impulseResponseDuration = 0.1;
    end
    
    methods(Static)
        function obj = default
        %   NOTE: Adding temporary tweak to circumvent a bug where scanimage won't
        %         start with some MDFs.
        %
            obj=scanimage.mroi.scanners.FastZ();
        end
    end
    
    methods
        function obj=FastZ(varargin)
            obj = obj@scanimage.mroi.scanners.LinearScanner(varargin{:});
        end
        
        function path_FOV = scanPathFOV(obj,ss,zPowerReference,actz,dzdt,seconds,slowPathFov)
            path_FOV = linspace(actz,actz+dzdt*seconds,ss.nsamples(obj,seconds))';

            if obj.enableFieldCurveCorr
                zs = [obj.fieldCurveParams.Z0 obj.fieldCurveParams.Z1];
                rxs = [obj.fieldCurveParams.Rx0 obj.fieldCurveParams.Rx1];
                rys = [obj.fieldCurveParams.Ry0 obj.fieldCurveParams.Ry1];
                
                as = interp1(zs, rxs, path_FOV, 'linear', 'extrap');
                bs = interp1(zs, rys, path_FOV, 'linear', 'extrap');
                cs = (as + bs) * .5;
                
                %dont try to correct in the fast x = axis
%                 thxs = resamp(slowPathFov(:,1), numel(path_FOV))';
                nnx = slowPathFov(:,1);
                nnx = nnx(~isnan(nnx));
                thxs = mean(nnx)*ones(numel(path_FOV),1);
                thys = resamp(slowPathFov(:,2), numel(path_FOV))';
                
                ths = atand(thys./thxs);
                ths(isnan(ths)) = 0;
                
                phis = (thxs.^2 + thys.^2).^.5;
                rs = ( (((cosd(ths).*sind(phis)).^2)./(as.^2)) + (((sind(ths).*sind(phis)).^2)./(bs.^2)) + (((cosd(phis)).^2)./(cs.^2)) ).^(-.5);
                zs = rs .* cosd(phis);
                
                d = cs - zs;
                
                path_FOV = path_FOV + d;
            end
            
            function wvfm = resamp(owvfm,N)
                w = warning('off','MATLAB:chckxy:IgnoreNaN');
                wvfm = pchip(linspace(0,1,numel(owvfm)),owvfm,linspace(0,1,N));
                warning(w.state,'MATLAB:chckxy:IgnoreNaN');
            end
        end
        
        function path_FOV = scanStimPathFOV(obj,ss,startz,endz,seconds,maxPoints)
            if nargin < 6 || isempty(maxPoints)
                maxPoints = inf;
            end
            
            N = min(maxPoints,ss.nsamples(obj,seconds));
            
            if isinf(startz)
                path_FOV = nan(N,1);
                path_FOV(ceil(N/2)) = endz;
            else
                path_FOV = linspace(startz,endz,N)';
                if isnan(startz) && ~isnan(endz)
                    path_FOV(end-2:end) = endz;
                end
            end
        end
        
        function path_FOV = interpolateTransits(obj,ss,path_FOV,tune,zWaveformType)
            if length(path_FOV) < 1
                return
            end

            switch zWaveformType
                case 'sawtooth'
                    %flyback frames
                    if any(isinf(path_FOV))
                        N = numel(find(isinf(path_FOV)));
                        assert(all(isinf(path_FOV(end-N+1:end))));
                        
                        Nfb = min(N,ss.nsamples(obj,obj.flybackTime));
                        Nramp = N-Nfb;
                        dz = path_FOV(2) - path_FOV(1);
                        
                        path_FOV(end-N+1:end-Nramp) = nan;
                        path_FOV(end-Nramp+1:end) = linspace(path_FOV(1)-dz*Nramp,path_FOV(1),Nramp);
                    end
                    
                case 'step'
                    %replace
                    infInds = find(isinf(path_FOV));
                    if ~isempty(infInds)
                        rgends = find(infInds(1:end-1) ~= (infInds(2:end)-1));
                        rgstrts = [1; rgends+1];
                        rgends = [rgends; numel(infInds)];
                        
                        for i=1:numel(rgstrts)
                            if i == numel(rgstrts)
                                ev = path_FOV(1);
                            else
                                ev = path_FOV(infInds(rgends(i))+1);
                            end
                            
                            strt = infInds(rgstrts(i));
                            nd = infInds(rgends(i));
                            
                            %hard step
                            path_FOV(strt:nd) = ev;
                            
                            %slope
                            N =  nd - strt + 1;
                            pth = linspace(path_FOV(strt-1),ev,N/3)';
                            pth(ceil(N/3):N) = ev;
                            path_FOV(strt:nd) = pth;
                        end
                    end
            end
            
            assert(~any(isinf(path_FOV)),'Unexpected infs in data.');
            path_FOV = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV);
            
            % right now "tuning" is just voltage shift to advance actuator.
            if tune
                %Shift Z data to account for acquisition delay
                path_infs = isinf(path_FOV);
                zSlope = diff(path_FOV) * obj.sampleRateHz;
                zSlope(end+1) = zSlope(end);
                shiftZ = obj.actuatorLag * zSlope;
                path_FOV = path_FOV + shiftZ;
                path_FOV(path_infs) = Inf;
            end
            
            allowedTravelRange = [obj.travelRange(1) - diff(obj.travelRange) * .01, obj.travelRange(2) + diff(obj.travelRange) * .01];
            
            if any(path_FOV < allowedTravelRange(1)) || any(path_FOV > allowedTravelRange(2))
                most.idioms.warn('FastZ waveform exceeded actuator range. Clamped to max and min.');
                path_FOV(path_FOV < obj.travelRange(1)) = obj.travelRange(1);
                path_FOV(path_FOV > obj.travelRange(2)) = obj.travelRange(2);
            end
        end
        
        function path_FOV = transitNaN(obj,ss,dt)
            path_FOV = nan(ss.nsamples(obj,dt),1);
        end
        
        function path_FOV = zFlybackFrame(obj,ss,frameTime)
            path_FOV = inf(ss.nsamples(obj,frameTime),1);
        end
        
        function path_FOV = padFrameAO(obj, ss, path_FOV, frameTime, flybackTime, zWaveformType)
            padSamples = ss.nsamples(obj, frameTime + flybackTime) - size(path_FOV,1);
            switch zWaveformType
                case 'step'
                    path_FOV(end+1:end+padSamples,:) = inf;
                    
                otherwise
                    if isempty(path_FOV)
                        app = nan;
                    elseif isinf(path_FOV(end))
                        app = inf;
                    else
                        app = nan;
                    end
                    path_FOV(end+1:end+padSamples,:) = app;
            end
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,ss,outputData)
            samplesPerTrigger = sum(cellfun(@(frameAO)size(frameAO.Z,1),outputData));
        end
    end
end


%--------------------------------------------------------------------------%
% FastZ.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
