function hFig = figureScaled(scaleFactor,varargin)
  %FIGURESCALED Creates a figure window scaled by specified scaleFactor
  
  defPosn = get(0,'DefaultFigurePosition');
  
  %Scale by scaleFactor. Shift by half the scaling horizontally and all the
  %scaling vertically. This keeps the default figure position horizontal
  %centering and the vertical top edge.
  hFig = figure(varargin{:},'Position', ...
    defPosn .* [1 1 scaleFactor scaleFactor] - [defPosn(3)*(scaleFactor-1)/2 defPosn(4)*(scaleFactor-1) 0 0]);   
  
  
  
end



%--------------------------------------------------------------------------%
% figureScaled.m                                                           %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
