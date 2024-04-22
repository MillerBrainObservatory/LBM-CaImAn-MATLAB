classdef ConfigurationPage < handle & matlab.mixin.Heterogeneous
    
    properties
        heading;
        listLabel;
        descriptionText;
        minimumWidth = 400;
        
        hText;
    end
    
    properties
        hConfigEditor;
        hPanel;
        
        isGeneric = false;
    end
    
    properties (Abstract, Constant)
        defaultPagePath;
    end
    
    methods
        function obj = ConfigurationPage(hConfigEditor, create, generic, hdg)
            obj.hConfigEditor = hConfigEditor;
            
            if nargin > 1 && ~isempty(create) && create
                if nargin > 3
                    vrs = {hdg};
                else
                    vrs = {};
                end
                hConfigEditor.addMdfPageToFile(obj.defaultPagePath,vrs{:});
            end
            
            if nargin > 3 && generic
                obj.isGeneric = true;
                
                %implement generic page functionality
                obj.heading = hdg;
                obj.listLabel = hdg;
                
                obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 obj.minimumWidth 800],'BackgroundColor','g');
                mainContainer = most.gui.uiflowcontainer('Parent',obj.hPanel,'FlowDirection','TopDown','margin',5);
                obj.hText = uicontrol('parent', mainContainer,'units','pixels','style','edit','HorizontalAlignment', 'left','Max',2);
            end
        end
        
        function delete(~)
        end
        
        function refreshPageDependentOptions(~)
        end
        
        function reload(obj)
            % this or some other mdf section has changed. reload the
            % settings
            obj.hText.String
        end
        
        function resizePnl(obj,newWith)
            obj.hPanel.Units = 'pixels';
            if obj.isGeneric
                obj.hPanel.Parent.Units = 'pixels';
                p = obj.hPanel.Parent.Position(3:4);
                
                obj.hPanel.Position(3:4) = p;
            else
                obj.hPanel.Position(3) = max(obj.minimumWidth,newWith);
            end
        end
        
        function s = reportDaqUsage(~,s)
            % overload with custom functionality
        end
        
        function s = getNewVarStruct(~)
            % overload with custom functionality
            s = struct();
        end
        
        function applySmartDefaultSettings(~)
            % overload with custom functionality
        end
        
        function s = getCurrentMdfDataStruct(obj)
            s = obj.hConfigEditor.getCurrentMdfDataStruct(obj.heading);
        end
        
        function applyVarStruct(obj,s)
            obj.hConfigEditor.applyVarStruct(obj.heading,s);
        end
    end
end


%--------------------------------------------------------------------------%
% ConfigurationPage.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
