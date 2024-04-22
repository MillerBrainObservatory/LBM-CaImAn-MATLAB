%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         Regression Test Unit of loadjson and savejson
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:4
    fname=sprintf('example%d.json',i);
    if(exist(fname,'file')==0) break; end
    fprintf(1,'===============================================\n>> %s\n',fname);
    json=savejson('data',loadjson(fname));
    fprintf(1,'%s\n',json);
    fprintf(1,'%s\n',savejson('data',loadjson(fname),'Compact',1));
    data=loadjson(json);
    savejson('data',data,'selftest.json');
    data=loadjson('selftest.json');
end

for i=1:4
    fname=sprintf('example%d.json',i);
    if(exist(fname,'file')==0) break; end
    fprintf(1,'===============================================\n>> %s\n',fname);
    json=saveubjson('data',loadjson(fname));
    fprintf(1,'%s\n',json);
    data=loadubjson(json);
    savejson('',data);
    saveubjson('data',data,'selftest.ubj');
    data=loadubjson('selftest.ubj');
end


%--------------------------------------------------------------------------%
% jsonlab_selftest.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
