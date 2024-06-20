classdef StdoutListener < scanimage.guis.statuswindow.streams.StreamInterface
    % This class should only be used by the compiled version of scanimage
    % Since there is no command window in compiled mode, we do two things:
    % 1) force everything through Java's stdout (which MATLAB does not use for
    % output for some reason)
    % 2) redirect Java's stdout back through this listener.
    % This allows us to control and reflect stdout back into the status window.
    properties (Access = private)
        interceptor;
    end
    
    methods
        function obj = StdoutListener(varargin)
            if nargin > 0 && strcmp(varargin{1},'singleton')
                import java.lang.System;
                import java.io.PrintStream;
                ic = InterceptorStream();
                ps = PrintStream(ic, true);
                System.setOut(ps);
                System.setOut(ps);
                
                obj.interceptor = handle(ic, 'CallbackProperties');
                set(obj.interceptor, 'PrintEventCallback', @(varargin)notify(obj, 'Updated'));
            else
                % return the singleton object
                obj.delete; %TMW: Deleting existing handle allows one to use factory method from constructor(!)
                obj = scanimage.guis.statuswindow.streams.StdoutListener.getHandle(varargin{:});
            end
        end
        
        function doClc(obj)
            obj.interceptor.clearBuffer();
            notify(obj, 'Updated');
        end
        
        function delete(obj)
            set(obj.interceptor, 'PrintEventCallback', []);
        end
        
        function str = getString(obj)
            str = char(obj.interceptor.getBuffer());
        end
    end
    
    
    %% STATIC METHODS
    methods (Static,Hidden)
        function obj = getHandle(varargin)
            %Get a handle to the singleton System object
            persistent localObj;
            if isempty(localObj) || ~isvalid(localObj)
                localObj = scanimage.guis.statuswindow.streams.StdoutListener('singleton',varargin{:});
            end
            obj = localObj;
        end
    end
end

%--------------------------------------------------------------------------%
% StdoutListener.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
