classdef nonBlockingDialog < handle
    properties (Hidden)
        hFig;
        containers = struct();
        hPbs = gobjects(1,0);
    end
    
    methods
        function obj = nonBlockingDialog(message1,message2,buttons,varargin)
            obj.hFig = figure('Toolbar','none','NumberTitle','off','MenuBar','none','CloseRequestFcn',@(varargin)obj.delete(),'Visible','off',varargin{:});
            movegui(obj.hFig,'center');
            
            obj.containers.main = most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
            if ~isempty(message1)
                obj.containers.message1 = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','LeftToRight');
                msg1 = uicontrol('Parent',obj.containers.message1,'Style','text','String',message1,...
                    'ForegroundColor','r','FontSize',14);
            end
            
            if ~isempty(message2)
                obj.containers.message2 = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','LeftToRight');
                msg2 = uicontrol('Parent',obj.containers.message2,'Style','text','String',message2);
            end
            
            obj.containers.buttons = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','LeftToRight');
            obj.containers.buttons.HeightLimits = [40 40];
            
            for idx = 1:length(buttons)
                button = buttons{idx};
                assert(iscell(button) && ischar(button{1}),'Input parameter ''buttons'' needs to be of format {{''string1'',@callback1},{''stringN'',@callbackN}}')
                str = button{1};
                
                if length(button) >= 2 && ~isempty(button{2})
                    assert(isa(button{2},'function_handle'),'Input parameter ''buttons'' needs to be of format {{''string1'',@callback1},{''stringN'',@callbackN}}');
                    cb = button{2};
                else
                    cb = [];
                end
                
                obj.hPbs(end+1) = uicontrol('Parent',obj.containers.buttons,'String',str,'Callback',@(varargin)obj.dispatchCallback(cb));
            end
            
            obj.hFig.Visible = 'on';
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods (Hidden)     
        function dispatchCallback(obj,cb)
            delete(obj);
            if ~isempty(cb)
                cb();
            end
        end        
    end
end

%--------------------------------------------------------------------------%
% nonBlockingDialog.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
