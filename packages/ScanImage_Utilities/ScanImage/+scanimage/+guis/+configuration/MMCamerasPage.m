classdef MMCamerasPage < scanimage.guis.configuration.ConfigurationPage
   properties
      cameraName;
      
      uManagerPath = '';
      camConfig = '';
      
      hMMPathText;
      etMMPath;
      
      hMMCameraConfigText;
      etMMCameraConfig;
      
      delChar = ['<html><table border=0 width=50><TR><TD><center>' char(10007) '</center></TD></TR></table></html>'];
   end
   
   properties (Constant)
      modelClass = 'dabs.micromanager.Camera';
   end
   
   methods
       function obj = MMCamerasPage(hConfigEditor, cameraName, create)
           if nargin < 3 || isempty(create)
                create = false;
           end
           obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,create,false,sprintf('MicroManager Camera (%s)',cameraName));
           
           obj.cameraName = cameraName;
            
            ph = 770;
            obj.hPanel = uipanel('parent',[],'BorderType','none','units','pixels','position',[0 0 990 ph]);
            
            % Install Path Selection
            obj.hMMPathText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'CamerasTableText', ...
                'Style', 'text', ...
                'String', 'MicroManager Installation Path', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-30 250 14]);
            
            obj.etMMPath = uicontrol(...
                'Parent',obj.hPanel,...
                'Units','pixels',...
                'BackgroundColor',[1 1 1],...
                'HorizontalAlignment','left',...
                'Position',[46 ph-60 250 20],...
                'String',obj.camConfig,...
                'Style','edit',...
                'Tag','etMMPath',...
                'Visible', 'on');
            
            uicontrol(...
                'Parent',obj.hPanel,...
                'Units','pixels',...
                'Callback',@(varargin)obj.pbBrowseMMPath(varargin{1}),...
                'Position',[300 ph-60 70 20],...
                'String','Browse...',...
                'TooltipString','Select MicroManager Camera Config File.',...
                'Tag','pbBrowseMMPath');
            
            % Config File Path
            obj.hMMCameraConfigText = uicontrol(...
                'parent', obj.hPanel, ...
                'Tag', 'CamerasTableText', ...
                'Style', 'text', ...
                'String', 'Camera Config File', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Position', [46 ph-90 250 14]);
            
            obj.etMMCameraConfig = uicontrol(...
                'Parent',obj.hPanel,...
                'Units','pixels',...
                'BackgroundColor',[1 1 1],...
                'HorizontalAlignment','left',...
                'Position',[46 ph-120 250 20],...
                'String',obj.uManagerPath,...
                'Style','edit',...
                'Tag','etMMPath',...
                'Visible', 'on');
            
            uicontrol(...
                'Parent',obj.hPanel,...
                'Units','pixels',...
                'Callback',@(varargin)obj.pbBrowseMMConfig(varargin{1}),...
                'Position',[300 ph-120 70 20],...
                'String','Browse...',...
                'TooltipString','Select MicroManager Installation Path.',...
                'Tag','pbBrowseMMPath');
            

            obj.reload(cameraName);
            
       end
   end
   
   methods
       function pbBrowseMMPath(obj, uiObj)
           MMPath = get(obj.etMMPath, 'String');
           
           if isempty(MMPath)
               MMPath = uigetdir('', 'Select MicroManager Installation Path...');
           else
               MMPath = uigetdir(MMPath, 'Select MicroManager Installation Path...');
           end
           
           if ~isequal(MMPath, 0)
              obj.uManagerPath = MMPath; 
              set(obj.etMMPath, 'String', MMPath);
           end
           obj.clearFocus(uiObj);
       end
       
       function pbBrowseMMConfig(obj, uiObj)           
           [file, path] = uigetfile('*.cfg', 'Select Camera Config File...');
           MMConfig = fullfile(path, file);
           
           if ~isequal(MMConfig, 0)
              obj.camConfig = MMConfig; 
              set(obj.etMMCameraConfig, 'String', MMConfig);
           end
           obj.clearFocus(uiObj);
       end
       
       function clearFocus(~,uiObj)
            set(uiObj, 'Enable', 'off');
            drawnow update;
            set(uiObj, 'Enable', 'on');
        end
   end   
   
   methods
       function delete(obj)
       end
       
       function reload(obj, cameraName)
           if nargin > 1
               obj.cameraName = cameraName;
               obj.listLabel = ['MicroManager Camera (' cameraName ')'];
               obj.heading = ['MicroManager Camera (' cameraName ')'];
               obj.descriptionText = 'Configure MicroManager Cameras.';
           end
           
           mdfData = obj.getCurrentMdfDataStruct();
           
           if isempty(mdfData) || isempty(mdfData.mmInstallDir) || isempty(mdfData.mmConfigFile)
               set(obj.etMMPath, 'String', '');
               set(obj.etMMCameraConfig, 'String', '');
           else
               obj.uManagerPath = mdfData.mmInstallDir;
               obj.camConfig = mdfData.mmConfigFile;
               set(obj.etMMPath, 'String', obj.uManagerPath);
               set(obj.etMMCameraConfig, 'String', obj.camConfig);
           end
           
        end
        
        function s = getNewVarStruct(obj)
            MMPath = get(obj.etMMPath, 'String');
            MMConfig = get(obj.etMMCameraConfig, 'String');
            s = struct('mmInstallDir', {MMPath},'mmConfigFile', {MMConfig});
        end 
   end
end

%--------------------------------------------------------------------------%
% MMCamerasPage.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
