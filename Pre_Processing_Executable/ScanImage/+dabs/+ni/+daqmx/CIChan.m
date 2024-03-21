classdef CIChan < dabs.ni.daqmx.private.CounterChan
    %COCHANNEL A DAQmx Counter Input Channel
    
    properties (Constant)
        type = 'CounterInput';
    end
    
    properties (Constant, Hidden)
        typeCode = 'CI';
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = CIChan(varargin) 
            %%%TMW: Constructor required, as this is a concrete subclass of abstract lineage
            obj = obj@dabs.ni.daqmx.private.CounterChan(varargin{:});            
        end
    end
    
end



%--------------------------------------------------------------------------%
% CIChan.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
