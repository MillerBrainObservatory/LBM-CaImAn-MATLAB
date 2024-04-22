classdef ProcessingPipeline < most.gui.GuiElement
    properties
        hConfigSignalConditioning
        hConfigFIRFilter
        hConfigDiscriminiator
        hPhotonDiscriminator
        hAxes;
    end
    
    methods
        function obj = ProcessingPipeline(hParent,hPhotonDiscriminator)
            obj = obj@most.gui.GuiElement(hParent);
            obj.hPhotonDiscriminator = hPhotonDiscriminator;
            obj.init();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hConfigSignalConditioning);
            most.idioms.safeDeleteObj(obj.hConfigFIRFilter);
            most.idioms.safeDeleteObj(obj.hConfigDiscriminiator);
            most.idioms.safeDeleteObj(obj.hAxes);
        end
        
        function init(obj)
            most.idioms.safeDeleteObj(obj.hAxes);
            most.idioms.safeDeleteObj(obj.hConfigSignalConditioning);
            most.idioms.safeDeleteObj(obj.hConfigFIRFilter);
            most.idioms.safeDeleteObj(obj.hConfigDiscriminiator);
            
            obj.hAxes = axes('Parent',obj.hUIPanel,'Visible','off','XLim',[0 1],'YLim',[-1 1]);
            line('Parent',obj.hAxes,'XData',[0 1],'YData',[0 0],'Color','black','Marker','o','MarkerFaceColor','black');
            text('Parent',obj.hAxes,'HorizontalAlignment','center','VerticalAlignment','bottom','Position',[0 0],'String',sprintf('AI%d\n',obj.hPhotonDiscriminator.physicalChannelNumber));
            text('Parent',obj.hAxes,'HorizontalAlignment','center','VerticalAlignment','bottom','Position',[1 0],'String',sprintf('Photons\n'));
            
            obj.hConfigSignalConditioning = scanimage.guis.photondiscriminator.ConfigSignalConditioning(obj,obj.hPhotonDiscriminator);
            obj.hConfigFIRFilter = scanimage.guis.photondiscriminator.ConfigFIRFilter(obj,obj.hPhotonDiscriminator);
            obj.hConfigDiscriminiator = scanimage.guis.photondiscriminator.ConfigDiscriminator(obj,obj.hPhotonDiscriminator);
            
            obj.panelResized();
        end
        
        function panelResized(obj)
            obj.hConfigSignalConditioning.setPositionInUnits('pixel',[0 0 150 100]);
            obj.hConfigFIRFilter.setPositionInUnits('pixel',[0 0 150 100]);
            obj.hConfigDiscriminiator.setPositionInUnits('pixel',[0 0 150 100]);
            
            obj.hAxes.Units = 'normalized';
            obj.hAxes.Position = [0.1 0 0.8 1];
            obj.hAxes.Visible = 'off';
            
            setPosition(0.25,obj.hConfigSignalConditioning);
            setPosition(0.5,obj.hConfigFIRFilter);
            setPosition(0.75,obj.hConfigDiscriminiator);
            
            function setPosition(centerX,hEl)
                pos = hEl.getPositionInUnits('normalized');
                newPos = [centerX - pos(3)/2,0.5-pos(4)/2,pos(3),pos(4)];
                hEl.setPositionInUnits('normalized',newPos);
            end
        end
        
        function scrollWheelFcn(obj,varargin)
            % No-Op
        end
        
        function configurationChanged(obj)
            obj.hConfigSignalConditioning.configurationChanged();
            obj.hConfigFIRFilter.configurationChanged();
            obj.hConfigDiscriminiator.configurationChanged();
        end
    end
end

%--------------------------------------------------------------------------%
% ProcessingPipeline.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
