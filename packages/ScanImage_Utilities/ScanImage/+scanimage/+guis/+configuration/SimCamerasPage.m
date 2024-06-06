classdef SimCamerasPage < scanimage.guis.configuration.ConfigurationPage
    properties
        cameraName;
        
        datatypeEntry = '';
        widthEntry = '';
        heightEntry = '';
        
        delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
    end
    
    properties (Constant)
        modelClass = 'dabs.simulated.Camera';
        DATATYPE_DROPDOWN_SEL = {'uint8' 'uint16' 'uint32'};
    end
    
    methods
        function obj = SimCamerasPage(hConfigEditor, cameraName, create)
            if nargin < 3 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,...
                create,false,sprintf('Simulated Camera (%s)',cameraName));
            
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
            
            rows = [...
                struct('label', 'Datatype',...
                'style', 'popupmenu',...
                'width', 80,...
                'string', {obj.DATATYPE_DROPDOWN_SEL},...
                'bind', 'datatypeEntry');...
                struct('label', 'Image Width',...
                'style', 'edit',...
                'width', 100,...
                'string', '512',...
                'bind', 'widthEntry');...
                struct('label', 'Image Height',...
                'style', 'edit',...
                'width', 100,...
                'string', '512',...
                'bind', 'heightEntry')];
            
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
                obj.listLabel = ['Simulated Camera (' cameraName ')'];
                obj.heading = ['Simulated Camera (' cameraName ')'];
                obj.descriptionText = 'Configure Simulated Camera.';
            end
            
            mdfData = obj.getCurrentMdfDataStruct();
            
            dtval = 1;
            wstr = '512';
            hstr = '512';
            
            if ~isempty(mdfData)
                if isfield(mdfData, 'simcamDatatype') &&...
                        ischar(mdfData.simcamDatatype) &&...
                        any(strcmpi(mdfData.simcamDatatype, obj.DATATYPE_DROPDOWN_SEL))
                    dtval = find(strcmpi(mdfData.simcamDatatype, obj.DATATYPE_DROPDOWN_SEL));
                end
                
                if isfield(mdfData, 'simcamResolution') &&...
                        isnumeric(mdfData.simcamResolution) &&...
                        numel(mdfData.simcamResolution) >= 2
                    wstr = num2str(mdfData.simcamResolution(1));
                    hstr = num2str(mdfData.simcamResolution(2));
                end
            end
            set(obj.datatypeEntry, 'Value', dtval);
            set(obj.widthEntry, 'String', wstr);
            set(obj.heightEntry, 'String', hstr);
        end
        
        function s = getNewVarStruct(obj)
            dt = obj.DATATYPE_DROPDOWN_SEL{obj.datatypeEntry.Value};
            w = str2double(obj.widthEntry.String);
            h = str2double(obj.heightEntry.String);
            s = struct('simcamDatatype', dt,'simcamResolution', [w h]);
        end
    end
end

%--------------------------------------------------------------------------%
% SimCamerasPage.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
