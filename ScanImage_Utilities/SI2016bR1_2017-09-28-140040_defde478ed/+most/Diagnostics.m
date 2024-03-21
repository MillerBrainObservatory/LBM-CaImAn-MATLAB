classdef Diagnostics < handle
    %Diagnostics Control diagnostic output at the command line and in log files.
    %
    %   The Diagnostics class can be used to provide control over the vebosity of
    %   diagnostic output at the command line and in log files for most classes and
    %   derived applications.  Functions and class methods can query the LogLevel to
    %   determine how much information to display, if any.  Applications can also
    %   set and change the LogLevel at any time.
    %
    %   
    %   See also most.util.LogLevel.
    
    properties
        LogLevel = most.util.LogLevel.Info; %Specifies the verbosity of command line and log file output.
    end
    
    methods (Access = private)
        function self = Diagnostics()
            %Diagnostics Default class constructor.
            %
            %   Diagnostics is a singleton class per MATLAB instance and therefore has a
            %   private constructor.
        end
    end
    
    methods
        function set.LogLevel(self, value)
            validateattributes(value, {'numeric', 'logical', 'most.util.LogLevel'}, {'scalar'});
            
            if ~isa(value, 'most.util.LogLevel')
                value = most.util.LogLevel(value);
            end
            
            self.LogLevel = value;
        end
    end
    
    methods (Static = true)
        function out = shareddiagnostics()
            %shareddiagnostics Return Diagnostics class singleton.
            
            persistent sharedInstance;
            if isempty(sharedInstance)
                sharedInstance = most.Diagnostics();
            end
            out = sharedInstance;
        end
    end
end


%--------------------------------------------------------------------------%
% Diagnostics.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
