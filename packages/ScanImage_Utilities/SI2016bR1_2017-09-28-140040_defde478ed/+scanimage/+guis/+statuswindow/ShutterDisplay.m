classdef ShutterDisplay < handle
    properties
        shutterOpen = true;
        name = '';
    end
    
    properties (Access = private)
        containers;
        hAx;
        hOpenGroup;
        hPatchOpen;
        hLaserSymbolGroup;
        hTextName;
        
        hClosedGroup;
        hPatchClosed;
    end
    
    methods
        function obj = ShutterDisplay(hParent,name)
            if nargin < 1 || isempty(hParent);
                hParent = figure();
            end
            
            if nargin < 2
                name = 'Shutter';
            end
            
            obj.containers.main = most.idioms.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
                obj.containers.top = uicontainer('Parent',obj.containers.main);
                    obj.hAx = axes('Parent',obj.containers.top,'LooseInset',[0 0 0 0],...
                        'XTick',[],'YTick',[],'XTickLabel',[],'YTickLabel',[],...
                        'XLim',[-.6 .6],'YLim',[-.4 .7],'DataAspectRatio',[1 1 1],'Visible','off');
            
                        tOutline = linspace(0,2*pi,100);
                        tInline = linspace(0,2*pi,9);
                        openRadius = 0.8;
            
                        obj.hOpenGroup = hggroup('Parent',obj.hAx);
                            obj.hLaserSymbolGroup = makeLaserSymbol(obj.hOpenGroup);
                            obj.hLaserSymbolGroup.Matrix = makehgtform('scale',0.65);
            
                        obj.hClosedGroup = hggroup('Parent',obj.hAx);
                    
                 obj.containers.bottom = most.idioms.uiflowcontainer('Parent',obj.containers.main,'FlowDirection','LeftToRight');
                 obj.containers.bottom.HeightLimits = [15 15];
                    obj.hTextName = uicontrol('Parent',obj.containers.bottom,'Style','Text','HorizontalAlignment','center');
            
            
            obj.name = name;
            obj.shutterOpen = obj.shutterOpen;
            
            function hGroup = makeLaserSymbol(hParent)
                hGroup = hgtransform('Parent',hParent);
                    numLines = 12;
                    lineWidth = 1;
                    color = [1 0 0];
                    
                    tt = linspace(0,2*pi,numLines+1);
                    lA = 1 / 180 * (2*pi);
                    tt(end) = [];
                    xx = 1/3 * [sin(tt-lA);sin(tt+lA);zeros(1,length(tt))];
                    yy = 1/3 * [cos(tt-lA);cos(tt+lA);zeros(1,length(tt))];
                    patch('Parent',hGroup,'XData',xx,'YData',yy,'FaceColor',color,'EdgeColor','none'); % long lines
                    
                    tt = linspace(pi/numLines,2*pi+pi/numLines,numLines+1);
                    lA = 1 / 180 * (2*pi);
                    tt(end) = [];
                    xx = 1/4 * [sin(tt-lA);sin(tt+lA);zeros(1,length(tt))];
                    yy = 1/4 * [cos(tt-lA);cos(tt+lA);zeros(1,length(tt))];
                    patch('Parent',hGroup,'XData',xx,'YData',yy,'FaceColor',color,'EdgeColor','none'); % short lines
                    
                    patch('Parent',hGroup,'XData',1/8*sin(linspace(0,2*pi,100)),'YData',1/8*cos(linspace(0,2*pi,100)),'FaceColor',color,'EdgeColor','none');
                    
                    tt = linspace(0,2*pi,4);
                    xx = 1 * sin(tt);
                    yy = 1 * cos(tt);
                    xx(end+1) = xx(1); % close curve for smooth edges
                    yy(end+1) = yy(1);
                    line('Parent',hGroup,'XData',xx,'YData',yy,'LineWidth',lineWidth*3,'Color',color);
                    try
                        lin.LineJoin = 'round'; % only available in Matlab >= 2016a
                    catch 
                    end
            end
        end
        
        function delete(obj)
            delete(obj.containers.main);
        end
    end
    
    methods        
        function set.shutterOpen(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            if val
                obj.hOpenGroup.Visible = 'on';
                obj.hClosedGroup.Visible = 'off';
            else
                obj.hOpenGroup.Visible = 'off';
                obj.hClosedGroup.Visible = 'on';
            end
            
            obj.shutterOpen = val;
        end
        
        function set.name(obj,val)
            if isempty(val)
                val = ''; % assert right type
            else
                validateattributes(val,{'char'},{});
            end
            
            obj.name = val;
            obj.hTextName.String = val;
        end
    end
end

%--------------------------------------------------------------------------%
% ShutterDisplay.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
