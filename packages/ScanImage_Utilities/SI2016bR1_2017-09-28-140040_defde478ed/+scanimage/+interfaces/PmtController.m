classdef PmtController < scanimage.interfaces.Class
    % Abstract class describing an interface to a PMT controller
    % one PMT controller can manage multiple PMTs
    
    %% USER PROPS    
    properties (Abstract, SetAccess = protected)
        numPmts;                 % [numerical] number of PMTs managed by the PMT controller
        pmtNames;                % Cell array of strings with a short name for each PMT
        pmtInitSuccessful;       % Indicates PMT control is ready
        pmtsStatusLastUpdated;   % time of last pmt status update
    end
    
    %% FRIEND PROPS
    properties (Dependent, Abstract)
        pmtsPowerOn;             % [logical]   array containing power status for each PMT 
        pmtsGain;                % [numerical] array containing gain setting for each PMT
        pmtsOffsets;            % [numeric] array containing offset for each PMT
        pmtsBandwidths          % [numeric] array containing amplifier bandwidth for each PMT
    end
    
    properties (Abstract, Dependent, SetAccess=private)
        pmtsTripped;            % [logical] array containing trip status for each PMT
    end
    
    %% USER EVENTS
    events
        pmtStatusChanged;
    end
    
    %% USER METHODS
    methods (Abstract)
        setPmtPower(obj, pmtNum, val);
        setPmtGain(obj, pmtNum, val);
        setPmtBandwidth(obj, pmtNum, val);
        setPmtOffset(obj, pmtNum, val);
        resetPmtTripStatus(obj, pmtNum);
        
        updatePmtsStatus(obj);   % requests the PMT controller to update its properties after the update, obj.statusUpdateFcn() is executed
        [powerOn, gain, tripped, offsets, bandwidths] = getLastPmtStatus(obj); % returns the last read status *without actually querrying the hardware device*
    end
end



%--------------------------------------------------------------------------%
% PmtController.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
