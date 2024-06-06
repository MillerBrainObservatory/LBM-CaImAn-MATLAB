classdef SpinCamerasPage < scanimage.guis.configuration.ConfigurationPage
    properties
        cameraName;
        
        cameraSelection;
        cameraList;
        
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
    end
    
    properties (Constant)
        modelClass = 'dabs.Spinnaker.Camera';
    end
    
    methods
        function obj = SpinCamerasPage(hConfigEditor, cameraName, create)
            if nargin < 3 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,...
                create,false,sprintf('Spinnaker Camera (%s)',cameraName));
            
            obj.cameraName = cameraName;
            
            panelHeight = 770;
            panelWidth = 990;
            leftoffset = 46;
            topoffset = 40;
            labelWidth = 100;
            colmargin = 20;
            rowmargin = 10;
            height = 20;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels',...
                'position',[0 0 panelWidth panelHeight]);
            
            rows = struct('label', 'Select Camera',...
                'style', 'popupmenu',...
                'width', 512,...
                'string', {'Choose One...'},...
                'bind', 'cameraSelection');
            
            for i=1:length(rows)
                r = rows(i);
                cursorX = leftoffset;
                cursorY = panelHeight-topoffset-((i-1)*(height+rowmargin));
                uicontrol(...
                    'parent', obj.hPanel,...
                    'Tag', 'CamerasTableText',...
                    'Style', 'text',...
                    'String', r.label,...
                    'HorizontalAlignment', 'left',...
                    'Units', 'pixels',...
                    'Position', [cursorX cursorY labelWidth height]);
                cursorX = cursorX + labelWidth + colmargin;
                entryctrl = uicontrol(...
                    'parent', obj.hPanel,...
                    'Tag', r.bind,...
                    'Style', r.style,...
                    'String', r.string,...
                    'Units', 'pixels',...
                    'Position', [cursorX cursorY r.width height]);
                if ~isempty(r.bind)
                    obj.(r.bind) = entryctrl;
                end
            end
            obj.reload(cameraName);
            
        end
    end
    
    methods
        function delete(~)
        end
        
        function reload(obj, cameraName)
            if nargin > 1
                obj.cameraName = cameraName;
                obj.listLabel = ['Spinnaker Camera (' cameraName ')'];
                obj.heading = obj.listLabel;
                obj.descriptionText = 'Configure Spinnaker Camera.';
            end
            
            mdfData = obj.getCurrentMdfDataStruct();
            
            obj.cameraList = dabs.Spinnaker.System.getCameraList();
            
            camselect = 1;
            if ~isempty(mdfData) && isfield(mdfData, 'spinCameraID') &&...
                    ischar(mdfData.spinCameraID)
                camselect = find(...
                    ~cellfun('isempty',...
                    strfind(obj.cameraList, mdfData.spinCameraID)),1);
                if isempty(camselect)
                    camselect = 1;
                else
                    camselect = camselect + 1;
                end
            end
            set(obj.cameraSelection, 'Value', camselect);
            set(obj.cameraSelection, 'String', [{'Choose One...'} obj.cameraList]);
        end
        
        function s = getNewVarStruct(obj)
            if obj.cameraSelection.Value == 1
                id = '';
            else
                id = obj.cameraList{obj.cameraSelection.Value-1};
            end
            s = struct('spinCameraID', id);
        end
    end
end


%--------------------------------------------------------------------------%
% SpinCamerasPage.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
