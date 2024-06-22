classdef CmwClone < handle
    properties
        enabled = true;
        visible = true;
        containers = struct();
        controls = struct();
    end
    
    properties (Access = private)
        hFig;
        hStream;
        hListener;
        scrollLine = 1;
        maxNumLines = 100; %100 line limit
        commandHistory = {};
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
                    obj.controls.cmwClc = uicontrol('Parent',obj.containers.bottom,'Tag','cmwClc','style','pushbutton','String','CLC','Tooltip','Clear the command window','Callback',@(varargin)obj.hStream.doClc());
                    obj.controls.cmwClc.WidthLimits = [30 30];
            
            obj.controls.cmwecho.FontName = obj.controls.cmwprompt.FontName;
            obj.controls.cmwecho.FontWeight = obj.controls.cmwprompt.FontWeight;
            obj.controls.cmwecho.FontSize = obj.controls.cmwprompt.FontSize;
            
            obj.hFig = ancestor(obj.controls.cmwecho,'figure');
            obj.initVisProps();
            
            obj.controls.cmwecho.Enable = 'inactive';

            %commandwindow does not exist in compiled mode so we route stdout
            %through the window instead.
            if ismcc || isdeployed
                obj.hStream = scanimage.guis.statuswindow.streams.StdoutListener();
            else
                obj.controls.cmwecho.ButtonDownFcn = @cmwSelectCallback;
                obj.hStream = scanimage.guis.statuswindow.streams.CmwListener();
            end
            obj.hListener = addlistener(obj.hStream,'Updated',@streamCallback);
            %             hListener_ = most.util.DelayedEventListener(0.1,hCmwListener_,'cmwUpdated',@cmwCallback);
            obj.controls.cmwecho.DeleteFcn = @(varargin)delete(obj.hListener);
            
            %initialize screen
            obj.scrollLine = 0;
            
            obj.hFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;
            
            % use a closure for this callback; this still works if the
            % class is removed from the Matlab path
            function streamCallback(src,evt)
                %snaps scrollLine to the bottom
                %see set.scrollLine function
                obj.scrollLine = 0;
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
            
            delete(obj.hStream);
            delete(obj.containers.main);
        end
        
        %called by generateSIReport to get a history from compiled ScanImage.
        function hist = getHistory(obj)
            hist = obj.commandHistory; 
        end
        
        %called by generateSIReport to get full buffer from compiled ScanImage
        function buffer = getBuffer(obj)
            buffer = obj.hStream.getString();
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
            str = obj.hStream.getString();
            if isempty(str)
                nlines = 0;
            else
            	nlines = numel(strfind(str, sprintf('\n'))) + 1;
            end
            val = round(max(min(val,nlines-1),0));
            
            obj.scrollLine = val;
            if isempty(str)
                %`clc` case
                obj.controls.cmwscrollbar.Value = 0;
                obj.controls.cmwecho.String = '';
            else
                obj.controls.cmwscrollbar.Value = min(obj.scrollLine ./ (nlines - 1),1);
                lineindex = max(nlines - obj.scrollLine, 1);
                strindices = [strfind(str, sprintf('\n')) (length(str)+1)];
                
                %calculate right offset ignoring the newline
                endindex = strindices(lineindex) - 1;
                
                %calculate left offset
                if lineindex <= obj.maxNumLines
                    startindex = 1;
                else
                    startindex = strindices(lineindex - obj.maxNumLines);
                end
                
                obj.controls.cmwecho.String = str(startindex:endindex);
            end
        end
    end
    
    methods (Hidden)
        function executeCommand(obj,src,evt)
            try
                cmd = src.String;
                if ismcc || isdeployed
                    % add to command History because compiled doesn't have the
                    % command window history functions
                    obj.commandHistory{length(obj.commandHistory)+1} = cmd;
                end
                src.String = '';
                fprintf('>> %s\n',cmd);
                %hack to allow printing for both compiled and non-compiled
                %versions
                fprintf('%s', evalc(sprintf('evalin(''base'',''%s'')', strrep(cmd, '''', ''''''))));
            catch ME
                fprintf(2, '%s\n\n',ME.message);
            end
        end
        
        function scrollBarCb(obj,src,evt)
            s = obj.hStream.getString();
            if isempty(s)
                nlines = 0;
            else
                nlines = numel(strfind(s, sprintf('\n'))) + 1;
            end
            obj.scrollLine = floor(nlines * src.Value);
        end
        
        function scrollWheelFcn(obj,src,evt)
            obj.scrollLine = obj.scrollLine - evt.VerticalScrollCount * evt.VerticalScrollAmount;
        end
    end
end

%--------------------------------------------------------------------------%
% CmwClone.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
