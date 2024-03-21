classdef CmwClone < handle
    properties
        enabled = true;
        visible = true;
        containers = struct();
        controls = struct();
    end
    
    properties (Access = private)
        hFig;
        hCmwListener;
        hListener;
        scrollLine = 0;
        cmwString = '';
    end
    
    properties (Hidden, SetAccess = private)
        visPropsDone = false;
    end
    
    methods
        function obj = CmwClone(hParent)
            if nargin < 1 || isempty(hParent)
                hParent = figure();
            end
            
            assert(ishghandle(hParent) && isvalid(hParent));
            
            obj.containers.main = most.idioms.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
                obj.containers.top = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','LeftToRight');
                    obj.containers.cmwecho = most.idioms.uiflowcontainer('Parent',obj.containers.top,'FlowDirection','TopDown');
                        obj.controls.cmwecho = uicontrol('Parent',obj.containers.cmwecho,'Style','text','String','','Tag','cmwecho','HorizontalAlignment','left','BackgroundColor',[1 1 1]);
                    obj.containers.cmwscrollbar = most.idioms.uiflowcontainer('Parent',obj.containers.top,'FlowDirection','TopDown');
                    obj.containers.cmwscrollbar.WidthLimits = [20 20];
                        obj.controls.cmwscrollbar = uicontrol('Parent',obj.containers.cmwscrollbar,'Style','Slider','Min',0,'Max',1,'Callback',@obj.scrollBarCb);
                obj.containers.bottom = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','LeftToRight');
                    obj.containers.bottom.HeightLimits = [25 25];
                    obj.controls.cmwlabel = uicontrol('Parent',obj.containers.bottom,'Tag','cmwprompt','style','text','String','>>','HorizontalAlignment','right');
                        obj.controls.cmwlabel.WidthLimits = [15 15];
                    obj.controls.cmwprompt = uicontrol('Parent',obj.containers.bottom,'Tag','cmwprompt','style','edit','String','','HorizontalAlignment','left','Callback',@obj.executeCommand);
                    obj.controls.cmwClc = uicontrol('Parent',obj.containers.bottom,'Tag','cmwClc','style','pushbutton','String','CLC','Tooltip','Clear the command window','Callback',@(varargin)evalin('base','clc'));
                        obj.controls.cmwClc.WidthLimits = [30 30];
            
            obj.controls.cmwecho.FontName = obj.controls.cmwprompt.FontName;
            obj.controls.cmwecho.FontWeight = obj.controls.cmwprompt.FontWeight;
            obj.controls.cmwecho.FontSize = obj.controls.cmwprompt.FontSize;
            
            obj.hFig = ancestor(obj.controls.cmwecho,'figure');
            obj.initVisProps();
            
            obj.controls.cmwecho.Enable = 'inactive';
            obj.controls.cmwecho.ButtonDownFcn = @cmwSelectCallback;
            
            hCmwListener_ = scanimage.guis.statuswindow.CmwListener();
            cmwCallback(hCmwListener_,[]);
            hListener_ = addlistener(hCmwListener_,'cmwUpdated',@cmwCallback);
%            hListener_ = most.util.DelayedEventListener(0.1,hCmwListener_,'cmwUpdated',@cmwCallback);
            obj.controls.cmwecho.DeleteFcn = @(varargin)delete(hListener_);
            
            obj.hCmwListener = hCmwListener_;
            obj.hListener = hListener_;
            
            obj.hFig.WindowScrollWheelFcn = @obj.scrollWhellFcn;
            
            % use a closure for this callback; this still works if the
            % class is removed from the Matlab path
            function cmwCallback(src,evt)
                try
                    maxNumChar = 10e3;
                    str = src.getCmwString();
                    str = str(max(length(str)-maxNumChar,1):end);
                    str = regexprep(str,'(^|\n)[\t ]*>>[\s ]*$',''); % remove the >> command prompt from the end
                    obj.cmwString = sprintf('%s\n',str);
                    obj.controls.cmwecho.String = obj.cmwString;
                    obj.scrollLine = 0;
                catch ME
                    % no command line output here or we end up in an infinite recursion
%                     errString = ME.getReport('basic','hyperlinks','off');
%                     msgbox(errString);
                end
            end
            
            function cmwSelectCallback(src,evt)
                hFig_ = ancestor(src,'figure');
                if any(strcmpi(hFig_.SelectionType,{'open','extend'}))
                    commandwindow();
                end
            end
        end
        
        function initVisProps(obj)
            if ~obj.visPropsDone && strcmp(obj.hFig.Visible,'on')
                % if the figure is not visible, these calls fail
                cmwechoj = most.gui.findjobj(obj.controls.cmwecho,'nomenu');
                cmwlabelj = most.gui.findjobj(obj.controls.cmwlabel,'nomenu');
                
                cmwechoj.setVerticalAlignment(3);
                cmwechoj.setLineWrap(0);
                cmwlabelj.setVerticalAlignment(0);
                
                obj.visPropsDone = true;
            end
        end
        
        function delete(obj)
            if ~isempty(obj.hListener) && isvalid(obj.hListener)
                delete(obj.hListener)
            end
            
            delete(obj.hCmwListener);            
            delete(obj.containers.main);
        end
    end
    
    methods
        function set.visible(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            if val
                obj.containers.main.Visible = 'on';
            else
                obj.containers.main.Visible = 'off';
            end
            obj.visible = val;
            obj.enabled = obj.enabled;
        end
        
        function set.enabled(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            if ~isempty(obj.hListener) && isvalid(obj.hListener)
                obj.hListener.Enabled = val && obj.visible;
            end
            obj.enabled = val;
        end
        
        function set.scrollLine(obj,val)            
            totalLines = length(obj.cmwString);
            val = round(max(min(val,totalLines),0));
            
            oldVal = obj.scrollLine;            
            obj.scrollLine = val;
            
            if oldVal == 0 && val == 0
                % performance optimization
                return
            end
            
            if totalLines == 0
                obj.controls.cmwscrollbar.Value = 0;
            else
                obj.controls.cmwscrollbar.Value = min(max(val ./ totalLines,0),1);
            end            
            
            str = obj.cmwString(1:end-obj.scrollLine);
            obj.controls.cmwecho.String = str;
        end
        
        function val = get.cmwString(obj)
            if ~iscellstr(obj.cmwString)
               % performance optimization: only convert to cellstr if actually requested
               obj.cmwString = strsplit(obj.cmwString,'\n');
            end
            val = obj.cmwString;
        end
    end
    
    methods (Hidden)        
        function executeCommand(obj,src,evt)
            try
                cmd = src.String;
                src.String = '';
                fprintf('>> %s\n',cmd);
                evalin('base',cmd);
            catch ME
                fprintf(2,'%s\n\n',ME.message);
            end
        end
        
        function scrollBarCb(obj,src,evt)
            numLines = length(obj.cmwString);
            obj.scrollLine = floor(numLines * src.Value);
        end
        
        function scrollWhellFcn(obj,src,evt)
            obj.scrollLine = obj.scrollLine - evt.VerticalScrollCount * evt.VerticalScrollAmount;
        end
    end
end

%--------------------------------------------------------------------------%
% CmwClone.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
