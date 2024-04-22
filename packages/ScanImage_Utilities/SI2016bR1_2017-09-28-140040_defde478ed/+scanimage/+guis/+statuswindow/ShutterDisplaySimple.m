classdef ShutterDisplaySimple < handle
    properties
        shutterOpen = true;
        name = '';
        hSI;
        shutterID;
    end
    
    properties (Access = private)
        hPb
        openColor = [1 0 0];
        closedColor;
    end
    
    methods
        function obj = ShutterDisplaySimple(hParent,name)
            if nargin < 1 || isempty(hParent);
                hParent = figure();
            end
            
            if nargin < 2
                name = 'Shutter';
            end
            
            obj.hPb = uicontrol('Parent',hParent,'String','Shutter','Callback',@obj.toggleShutter);
            obj.closedColor = obj.hPb.BackgroundColor;
            
            obj.name = name;
            obj.shutterOpen = obj.shutterOpen;
        end
        
        function delete(obj)
            delete(obj.hPb);
        end
        
        function toggleShutter(obj,varargin)
            assert(~isempty(obj.hSI) && isvalid(obj.hSI),'ScanImage handle is invalid');
            assert(~isempty(obj.shutterID),'Shutter ID is empty');
            
            obj.hSI.hShutters.shuttersTransition(obj.shutterID,~obj.shutterOpen);
        end
    end
    
    methods        
        function set.shutterOpen(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            if val
                obj.hPb.BackgroundColor = obj.openColor;
                obj.hPb.Value = true;
                %obj.hPb.String = ['<HTML><center>',obj.name,'<br>Open</center></HTML>'];
            else
                obj.hPb.BackgroundColor = obj.closedColor;
                obj.hPb.Value = false;
                %obj.hPb.String = obj.name;
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
            obj.hPb.String = val;
        end
    end
end

%--------------------------------------------------------------------------%
% ShutterDisplaySimple.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
