function res = normxcorr2(A, B)
  disp('most.mimics.normxcorr2: WARNING, naive normalization. Different from toolbox version');
  if nargin == 2
    res = most.mimics.xcorr2(A,B);
    maxVal = max(max(res));
    minVal = min(min(res));

    if maxVal > 0 && minVal < 0
      normVal = max(maxVal,-minVal);
    elseif maxVal > 0 
      normVal = maxVal;
    elseif minVal < 0 
      normVal = minVal;
    else
      disp('most.mimics.normxcorr2: Error, zero matrix');
    end
    normVal
    res = res./normVal;


  else
    disp('most.mimics.normxcorr2: Unexpected number of arguments');
  end
end


%--------------------------------------------------------------------------%
% normxcorr2.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
