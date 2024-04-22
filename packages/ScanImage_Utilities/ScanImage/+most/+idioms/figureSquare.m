function hFig = figureSquare(varargin)
%FIGURESQUARE Creates a square figure window

defPosn = get(0,'DefaultFigurePosition');
squareSize = mean(defPosn(3:4));
squarePosn = [defPosn(1)+(defPosn(3)-squareSize) defPosn(2)+(defPosn(4)-squareSize) squareSize squareSize];
hFig = figure(varargin{:},'Position',squarePosn);



end



%--------------------------------------------------------------------------%
% figureSquare.m                                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
