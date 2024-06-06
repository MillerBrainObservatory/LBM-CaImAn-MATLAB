classdef ConfigFIRFilter < most.gui.GuiElement
    properties
        hAx;
        hCheckBox;
        hLine;
        hPhotonDiscriminator;
    end
    
    methods
        function obj = ConfigFIRFilter(hParent,hPhotonDiscriminator)
            obj = obj@most.gui.GuiElement(hParent);
            obj.hPhotonDiscriminator = hPhotonDiscriminator;
            obj.init();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAx);
            most.idioms.safeDeleteObj(obj.hCheckBox);
            most.idioms.safeDeleteObj(obj.hLine);
        end
        
        function init(obj)
            delete(obj.hUIPanel.Children);
            colors = get(gca,'colororder');
            obj.hUIPanel.Title = 'FIR Filter';
            obj.hCheckBox = uicontrol('Parent',obj.hUIPanel,'Style','checkbox','String','Enable','Callback',@obj.toggleEnable);
            obj.hAx = axes('Parent',obj.hUIPanel,'Box','on','ButtonDownFcn',@obj.openInputDialog);
            obj.hLine = line('Parent',obj.hAx,'XData',[],'YData',[],'Color',colors(1,:),'Marker','none');
            obj.panelResized();
            obj.configurationChanged();
        end
        
        function scrollWheelFcn(obj,varargin)
           % No-Op
        end
    end
    
    methods
        function configurationChanged(obj)
            filterCoefficients = obj.hPhotonDiscriminator.filterCoefficients;
            
            if isempty(filterCoefficients)
                obj.hLine.Visible = 'off';
            else
                obj.hLine.Visible = 'on';
                obj.hLine.XData = 0:(length(filterCoefficients)-1);
                obj.hLine.YData = filterCoefficients;
                xlim = [0 length(filterCoefficients)-1];
                if diff(xlim)<=0
                    xlim(2) = xlim(1)+1;
                end
                obj.hAx.XLim = xlim;
            end
            
            enabled = obj.hPhotonDiscriminator.filterEnabled;
            if enabled
                c = [0 0 1];
            else
                c = [0.8 0.8 0.8];
            end
            obj.hLine.Color = c;
            obj.hCheckBox.Value = enabled;
        end
        
        function panelResized(obj)
            obj.hCheckBox.Units = 'pixel';
            obj.hAx.Units = 'pixel';
            panelPos = obj.getPositionInUnits('pixel');
            
            pSz = panelPos(3:4);
            cbSz = obj.hCheckBox.Position(3:4);
            padding = [30 10 15 10];%lrtb
            
            obj.hCheckBox.Position(1:2) = [padding(1),pSz(2)-padding(3)-cbSz(2)];
            axSize = [pSz(1)-padding(1)-padding(2),pSz(2)-padding(3)-padding(4)-cbSz(2)];
            obj.hAx.Position = [padding(1),padding(4),axSize(1),axSize(2)];
        end
        
        function toggleEnable(obj,varargin)
            obj.hPhotonDiscriminator.filterEnabled = ~obj.hPhotonDiscriminator.filterEnabled;
        end
        
        function openInputDialog(obj,varargin)
            fc = mat2str(obj.hPhotonDiscriminator.filterCoefficients);
            answer = inputdlg('Enter Filter Kernel (or variable name in Matlab base space)','Filter Kernel',[1 100],{fc});
            if ~isempty(answer)
                try
                    answer = answer{1};
                    if ~isempty(regexpi(answer,'[a-z]*'))
                        fc = evalin('base',answer);
                    else
                        fc = str2num(answer);
                    end
                    obj.hPhotonDiscriminator.filterCoefficients = fc;
                catch ME
                    obj.configurationChanged();
                    most.idioms.rethrowMsgDlg(ME);
                end
            end
        end
    end
end

%--------------------------------------------------------------------------%
% ConfigFIRFilter.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
