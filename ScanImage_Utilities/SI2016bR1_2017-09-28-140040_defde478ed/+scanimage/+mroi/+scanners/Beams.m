classdef Beams < handle
    properties
        beamIDs; %1
        sampleRateHz; %2
        
        powers; %3
        powerLimits; %4
        flybackBlanking; %5
        
        pzAdjust; %6
        Lzs; %7
        
        interlaceDecimation; %8
        interlaceOffset; %9
        
        powerFracToVoltageFunc; %10
        
        %new
        powerDepthCorrectionFunc; %11
        % end new
        
        linePhase;          % [seconds] 12
        beamClockDelay;     % [s] 13
        beamClockExtend;    % [s] 14
        
        powerBoxes = []; %15
    end

    methods(Static)
        function obj = default
            obj=scanimage.mroi.scanners.Beams(1,200000,0,100,true,false,Inf,1,0,[],[],0,0,0);
        end
    end

    methods
        function obj=Beams(...
                beamIDs,...
                sampleRateHz,...
                powers,...
                powerLimits,...
                flybackBlanking,...
                pzAdjust,...
                Lzs,...
                interlaceDecimation,...
                interlaceOffset,...
                powerFracToVoltageFunc,...
                powerDepthCorrectionFunc,...
                linePhase,...
                beamClockDelay,...
                beamClockExtend,...
                powerBoxes)
            
            obj.beamIDs     = beamIDs;
            obj.sampleRateHz = sampleRateHz;
            obj.powers = powers;
            obj.powerLimits = powerLimits;
            obj.flybackBlanking = flybackBlanking;
            obj.pzAdjust = pzAdjust;
            obj.Lzs = Lzs;
            obj.interlaceDecimation = interlaceDecimation;
            obj.interlaceOffset = interlaceOffset;
            obj.powerFracToVoltageFunc = powerFracToVoltageFunc;
            obj.powerDepthCorrectionFunc = powerDepthCorrectionFunc;
            obj.linePhase = linePhase;
            obj.beamClockDelay = beamClockDelay;
            obj.beamClockExtend = beamClockExtend;
            
            if nargin > 14
                obj.powerBoxes = powerBoxes;
            end
        end
        
        function path_FOV = generateBeamsPathStimulus(obj,path_FOV,scanfield,parkfunctiondetected,repetitionsInteger,durationPerRepetitionInt,durationPerRepetitionFrac,totalduration,maxPoints)
            if nargin < 9
                maxPoints = inf;
            end
            
            if isempty(scanfield.powers)
                pwrs = obj.powers;
            elseif numel(scanfield.powers) == 1;
                pwrs = repmat(scanfield.powers,1,numel(obj.powers));
            else
                assert(numel(scanfield.powers) == numel(obj.powers),...
                    'Number of defined beam powers for stimulus %s does not match number of beams',...
                    scanfield.name);
                pwrs = scanfield.powers(:)';
            end
            
            [tf, idx] = ismember('poweredPause',scanfield.stimparams(1:2:end));
            poweredPause = tf && scanfield.stimparams{idx*2};
            
            isn = isfield(path_FOV, 'G') && all(all(isnan(path_FOV.G)));
            
            if (isn || parkfunctiondetected) && (~poweredPause)
                % detected output from the pause/park stimulus function. set
                % beam powers to zero
                numsamples = round(totalduration * obj.sampleRateHz);
                allRepetitions = zeros(numsamples,numel(pwrs));
            else
                powerFracs = pwrs ./ 100; % scale from percent to powerfraction
                
                numsamples = round(durationPerRepetitionInt * obj.sampleRateHz);
                tt = linspace(0,(numsamples-1)/obj.sampleRateHz,min(numsamples,maxPoints));
                numsamples = length(tt); % recalculate in case maxPoints < numsamples
                
                pwrs = scanfield.beamsfcnhdl(tt,powerFracs,'actualDuration',durationPerRepetitionInt,'scanfield',scanfield);
                assert(size(pwrs,1) == numsamples,...
                    ['Beams generation function ''%s'' returned incorrect number of samples:',...
                    'Expected: %d Returned: %d'],...
                    func2str(scanfield.beamsfcnhdl),numsamples,size(pwrs,1));
                assert(size(pwrs,2) == numel(obj.powers),...
                    ['Beams generation function ''%s'' returned incorrect number of beams:',...
                    'Expected: %d Returned: %d'],...
                    func2str(scanfield.beamsfcnhdl),numel(obj.powers),size(pwrs,2));
                
                % enforce power Limits
                for iter = 1:numel(obj.powers)
                    pwrs(iter) = min(pwrs(iter),obj.powerLimits(iter)./100);
                end
                
                % apply repetitions
                allRepetitions = repmat(pwrs,repetitionsInteger,1);
                
                % fractional repetitions
                numsamples = round(durationPerRepetitionFrac * obj.sampleRateHz);
                allRepetitions(end+1:end+numsamples,:) = pwrs(1:numsamples,:);
            end
            path_FOV.B = allRepetitions(:,obj.beamIDs);
            path_FOV.B(end,:) = 0;
        end
    end
end


%--------------------------------------------------------------------------%
% Beams.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
