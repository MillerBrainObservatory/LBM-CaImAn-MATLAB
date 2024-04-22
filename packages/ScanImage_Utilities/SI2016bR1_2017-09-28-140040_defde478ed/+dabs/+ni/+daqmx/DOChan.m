classdef DOChan < dabs.ni.daqmx.private.DigitalChan
    %DOCHAN  A DAQmx Digital Output Channel
    %   Detailed explanation goes here
    
    properties (Constant)
        type = 'DigitalOutput';
    end
    
    properties (Constant, Hidden)
        typeCode = 'DO';
    end
    
    %%TMW: Should we really have to create a constructor when a simple pass-through to superclass would do?
    methods 
        function obj = DOChan(varargin)
            obj = obj@dabs.ni.daqmx.private.DigitalChan(varargin{:});            
        end        
    end
    
end



%--------------------------------------------------------------------------%
% DOChan.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
