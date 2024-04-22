classdef CmwListener < scanimage.guis.statuswindow.streams.StreamInterface
    %% CONSTRUCTOR/DESTRUCTOR
    properties (Access = private)
        jTextArea;
    end
    
    methods 
        function obj = CmwListener(varargin)
            if nargin>0 && strcmp(varargin{1},'singleton')
                varargin(1) = [];
                
                jDesktop = com.mathworks.mde.desk.MLDesktop.getInstance;
                try
                    jCmdWin = jDesktop.getClient('Command Window');
                    jTextArea = jCmdWin.getComponent(0).getViewport.getView;
                    hjTextArea = handle(jTextArea, 'CallbackProperties');
                    set(hjTextArea,'CaretUpdateCallback',@(varargin)notifyCmwUpdated(obj));
                    obj.jTextArea = hjTextArea;
                catch
                    obj.jTextArea = [];
                end
                
            else
                % return the singleton object
                obj.delete; %TMW: Deleting existing handle allows one to use factory method from constructor(!)
                obj = scanimage.guis.statuswindow.streams.CmwListener.getHandle(varargin{:});
            end
            
            % use a closure for this callback; this still works if the
            % class is removed from the Matlab path
            function notifyCmwUpdated(obj_)
                try
                    notify(obj_,'Updated');
                catch ME
                    % if anything goes wrong, deactivate the caret update
                    % callback
                    set(hjTextArea,'CaretUpdateCallback',[]);
                    rethrow(ME);
                end
            end
        end
        
        function doClc(obj)
            evalin('base', 'clc');
        end
        
        function delete(obj)
            set(obj.jTextArea,'CaretUpdateCallback',[]);
        end
        
        function str = getString(obj)
            str = char(obj.jTextArea.getText);
            if ~isempty(str)
                i_nls = strfind(str, sprintf('\n'));
                
                if isempty(i_nls)
                    %newline character(s) dne so it's just one line
                    str = '';
                else
                    %remove the prompt.
                    str = str(1:i_nls(end)-1);
                end
            end
        end
    end
    
    
    %% STATIC METHODS
    methods (Static,Hidden)       
        function obj = getHandle(varargin)
            %Get a handle to the singleton System object
            persistent localObj;
            if isempty(localObj) || ~isvalid(localObj)
                localObj = scanimage.guis.statuswindow.streams.CmwListener('singleton',varargin{:});
            end
            obj = localObj;
        end
    end    
end

%--------------------------------------------------------------------------%
% CmwListener.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
