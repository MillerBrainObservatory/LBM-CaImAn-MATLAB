classdef FullScreenDisplay < handle
    properties (Access = private)
        mexWindowHandle = [];
    end
    
    methods
        function obj = FullScreenDisplay(monitorID)
            if nargin < 1 || isempty(monitorID)
                monitorID = [];
            end
            
            obj.mexWindowHandle = WindowMex('openWindow');
            
            if ~isempty(monitorID)
                pause(0.1); % weired timing issue: moveToMonitor does not work if window was just opened
                obj.moveToMonitor(monitorID);
            end
        end
        
        function delete(obj)
            WindowMex('close',obj.mexWindowHandle);
        end
        
        function updateBitmap(obj,im,isTransposed)
            if nargin < 3 || isempty(isTransposed)
                isTransposed = false;
            end
            
            if ~isTransposed
                im = im';
            end
            imSize = size(im);
            width = imSize(1);
            height = imSize(2);
            
            % https://msdn.microsoft.com/en-us/library/windows/desktop/dd162974(v=vs.85).aspx
            % The scan lines must be aligned on a DWORD except for RLE-compressed bitmaps.
            assert(mod(width,4)==0 && mod(height,4)==0,'FullScreenDisplay: bitmap width and height must be divisible by 4.');
            
            im = uint8(im);
            WindowMex('updateBitmap',obj.mexWindowHandle,width,height,im(:));
        end
        
        function redraw(obj)
            WindowMex('redraw',obj.mexWindowHandle);
        end
        
        function moveToMonitor(obj,monitorID)
            validateattributes(monitorID,{'numeric'},{'scalar','positive','integer'});
            monitorID = monitorID-1;
            success = WindowMex('moveToMonitor',obj.mexWindowHandle,monitorID);
            if ~success
                most.idioms.warn('Could not move full screen display to monitor %d.',monitorID);
            end
        end
    end
end



%--------------------------------------------------------------------------%
% FullScreenDisplay.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
