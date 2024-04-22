clc; clear all;
dbstop if error


h=scanimage.mroi.test.SerializeTester;
disp(h.modelGetHeader());

%{
s=h.data;
disp('***');
disp(s);
disp('---');
h.data=s;
disp('---');
disp(h.modelGetHeader());
disp('END');
%}


%--------------------------------------------------------------------------%
% scratch.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
