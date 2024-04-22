%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         Benchmarking processing speed of savejson and loadjson
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

datalen=[1e3 1e4 1e5 1e6];
len=length(datalen);
tsave=zeros(len,1);
tload=zeros(len,1);
for i=1:len
    tic;
    json=savejson('data',struct('d1',rand(datalen(i),3),'d2',rand(datalen(i),3)>0.5));
    tsave(i)=toc;
    data=loadjson(json);
    tload(i)=toc-tsave(i);
    fprintf(1,'matrix size: %d\n',datalen(i));
end

loglog(datalen,tsave,'o-',datalen,tload,'r*-');
legend('savejson runtime (s)','loadjson runtime (s)');
xlabel('array size');
ylabel('running time (s)');


%--------------------------------------------------------------------------%
% jsonlab_speedtest.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
