classdef CmwListener < handle
    %% CONSTRUCTOR/DESTRUCTOR
    properties (Access = private)
        jTextArea;
    end
    
    events (NotifyAccess = private)
        cmwUpdated; % no printing to the command line in this callback! not even error messages!
    end
    
    methods 
        function obj = CmwListener(varargin)
            if nargin>0 && strcmp(varargin{1},'singleton')
                varargin(1) = [];
                
                jDesktop = com.mathworks.mde.desk.MLDesktop.getInstance;
                jCmdWin = jDesktop.getClient('Command Window');
                jTextArea = jCmdWin.getComponent(0).getViewport.getView;

                set(jTextArea,'CaretUpdateCallback',@(varargin)notifyCmwUpdated(obj));
                obj.jTextArea = jTextArea;
            else
                % return the singleton object
                obj.delete; %TMW: Deleting existing handle allows one to use factory method from constructor(!)
                obj = scanimage.guis.statuswindow.CmwListener.getHandle(varargin{:});
            end
            
            % use a closure for this callback; this still works if the
            % class is removed from the Matlab path
            function notifyCmwUpdated(obj_)
                try
                    notify(obj_,'cmwUpdated');
                catch ME
                    % if anything goes wrong, deactivate the caret update
                    % callback
                    set(jTextArea,'CaretUpdateCallback',[]);
                    rethrow(ME);
                end
            end
        end
        
        function delete(obj)
            set(obj.jTextArea,'CaretUpdateCallback',[]);
        end
        
        function str = getCmwString(obj)
            str = char(obj.jTextArea.getText);
        end
    end
    
    
    %% STATIC METHODS
    methods (Static,Hidden)       
        function obj = getHandle(varargin)
            %Get a handle to the singleton System object
            persistent localObj;
            if isempty(localObj) || ~isvalid(localObj)
                localObj = scanimage.guis.statuswindow.CmwListener('singleton',varargin{:});
            end
            obj = localObj;
        end
    end    
end

%--------------------------------------------------------------------------%
% CmwListener.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
