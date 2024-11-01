classdef TestDLLClass < handle
    %TEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        dllHeaderFile= 'C:\Program Files\National Instruments\NI-DAQ\DAQmx ANSI C Dev\include\NIDAQmx.h';
        libName = 'nicaiu';
    end
    
    methods
        function obj = TestDLLClass()
            if ~libisloaded(obj.libName)
                %disp([obj.driverPrettyName ': Initializing...']);
                warning('off','MATLAB:loadlibrary:parsewarnings');
                loadlibrary([obj.libName '.dll'],obj.dllHeaderFile);
                warning('on','MATLAB:loadlibrary:parsewarnings');
            end           
        end
        
        function delete(obj)
            if libisloaded(obj.libName)
                unloadlibrary(obj.libName);
            end
        end
    end
    
end



%--------------------------------------------------------------------------%
% TestDLLClass.m                                                           %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
