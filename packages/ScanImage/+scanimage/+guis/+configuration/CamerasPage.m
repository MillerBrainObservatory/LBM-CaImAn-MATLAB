classdef CamerasPage < scanimage.guis.configuration.ConfigurationPage
   properties
      hCamerasPanel;
      hCamerasTable
      hCamerasTableText;
      keyDown = false;
      delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
   end
   
   properties (Constant)
      modelClass = 'scanimage.components.CameraManager';
   end
   
   methods
       function obj = CamerasPage(hConfigEditor, create)
           if nargin < 2 || isempty(create)
                create = false;
            end
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create);
            
            obj.listLabel = 'Cameras';
            obj.heading = 'CameraManager';
            obj.descriptionText = 'Configure cameras for ScanImage to control and acquire images from.';
            
            ph = 770;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 990 ph]);
            
            camEntries = scanimage.components.cameramanager.registry.CameraRegistry.getAllCameraEntries();
            camEntries = arrayfun(@(e)e.prettyNames(1), camEntries);
            
            % CamerasTableText
            obj.hCamerasTableText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'CamerasTableText', ...
                'Style', 'text', ...
                'String', 'Camera Types and Names', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-42 250 14]);
            
            % CamerasTable
            camerasColumnNames      = {'Camera Type' 'Camera Name' 'Delete'};
            camerasColumnFormats    = {camEntries 'char' 'char'};
            camerasColumnEditable   = [true, true, false];
            camerasColumnWidths     = {100 100 50};
            camerasBlankRow         = {'' '' obj.delChar};

            obj.hCamerasTable = uitable( ... 
                'parent', obj.hPanel, ...
                'Tag', 'CamerasTable', ...
                'Data', camerasBlankRow, ...
                'ColumnName', camerasColumnNames, ...
                'ColumnFormat', camerasColumnFormats, ...
                'ColumnEditable', camerasColumnEditable, ...
                'ColumnWidth', camerasColumnWidths, ...
                'RowName', 'numbered', ...
                'RowStriping', 'Off', ...
                'Units', 'pixels', ...
                'KeyPressFcn',@obj.KeyFcn,...
                'KeyReleaseFcn',@obj.KeyFcn,...
                'Position', [46 ph-169 282 120],...
                'CellSelectionCallback',@obj.cellSelFcn,...
                'CellEditCallback',@obj.cellEditFcn);
            
            obj.reload();
            
       end
   end
   
   methods
       function KeyFcn(obj,~,evt)
            switch evt.EventName
                case 'KeyRelease'
                    obj.keyDown = false;
                case 'KeyPress'
                    obj.keyDown = true;
            end
       end
        
       function cellSelFcn(obj,~,evt)
            if size(evt.Indices,1) == 1 && evt.Indices(2) == 3
                if obj.keyDown
                    d = obj.hCamerasTable.Data;
                    obj.hCamerasTable.Data = {};
                    obj.hCamerasTable.Data = d;
                    obj.keyDown = false;
                else
                    obj.hCamerasTable.Data(evt.Indices(1),:) = [];
                end
                obj.cellEditFcn();
            end
       end
       
       function cellEditFcn(obj,varargin)
           dat = obj.hCamerasTable.Data;
           
           if size(dat,1) < 1
               lr = [];
           else
               lr = dat(end,:);
           end
           
           if isemptyCell(lr) || ~isemptyCell(lr{1})
               dat(end+1,:) = {'' '' obj.delChar};
           end
           
           obj.hCamerasTable.Data = dat;
        end

   end   
   
   methods
       
       function delete(obj)
       end
       
       function reload(obj)
           mdfData = obj.getCurrentMdfDataStruct();
           
           if isempty(mdfData) || isempty(mdfData.cameraTypes) || isempty(mdfData.cameraNames)
               dat = {'' '' obj.delChar};
           else
               names = mdfData.cameraNames;
               types = mdfData.cameraTypes;
               dat = cellfun(@(c1, c2) {c1 c2 obj.delChar}, types, names,'UniformOutput',false);
               dat = vertcat(dat{:});
               dat(end+1,:) = {'' '' obj.delChar};
           end
           
           obj.hCamerasTable.Data = dat;
       end
       
       function s = getNewVarStruct(obj)
           dat = obj.hCamerasTable.Data;
           % Make sure last row is empty
           if isempty(dat{end,1}) || isempty(dat{end,2})
              dat(end, :) = []; 
           end
           s = struct('cameraTypes', {dat(:,1)'},'cameraNames', {dat(:,2)'});
       end 
   end
end

function tf = isemptyCell(c)
tf = isempty(c) || (ischar(c) && strcmpi(c,' '));
end

%--------------------------------------------------------------------------%
% CamerasPage.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
