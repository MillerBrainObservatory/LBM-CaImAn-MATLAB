function success = flushFpgaFifo(fifo,timeout_s)
if nargin < 2 || isempty(timeout_s)
    timeout_s = 5;
end

validateattributes(fifo,{'dabs.ni.rio.NiFIFO'},{'scalar'});
validateattributes(timeout_s,{'numeric'},{'positive','scalar','finite','nonnan','real'});


starttime = tic();
elremaining = 1;

success = false;
while elremaining > 0
    try
        [~,elremaining] = fifo.read(elremaining,0);
    catch ME
        if ~isempty(strfind(ME.message,'-50400')) % filter timeout error
            break
        end
        most.idioms.reportError(ME);
    end
    if toc(starttime) >= timeout_s
        if nargout < 1
            most.idioms.warn('Could not flush fifo %s within timeout.',fifo.fifoName);
        end
        return
    end
end

success = true;

end

%--------------------------------------------------------------------------%
% flushFpgaFifo.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
