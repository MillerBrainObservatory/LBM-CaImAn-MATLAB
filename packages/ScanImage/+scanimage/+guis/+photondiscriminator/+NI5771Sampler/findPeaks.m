function [threshIdxs,canceled] = findPeaks(data,threshold,maskBefore,maskAfter,debounceSamples,cancel_progressFcn)
canceled = false;

if nargin<3 || isempty(maskBefore)
    maskBefore = true(1,8);
end

if nargin<4 || isempty(maskAfter)
    maskAfter = true(1,8);
end

if nargin<5 || isempty(debounceSamples)
    debounceSamples = 8;    
end

if nargin<6 || isempty(cancel_progressFcn)
    cancel_progressFcn = [];
end

if ~isempty(cancel_progressFcn)
    validateattributes(cancel_progressFcn,{'function_handle'},{'scalar'});
    validateattributes(cancel_progressFcn(),{'numeric','logical'},{'scalar','binary'});
end

if ~isempty(cancel_progressFcn) && cancel_progressFcn(0)    
    threshIdxs = [];
    canceled = true;
    return
end

mask = data >= threshold;
threshIdxs = find(mask);

if ~isempty(cancel_progressFcn) && cancel_progressFcn(0)   
    threshIdxs = [];
    canceled = true;
    return
end

maskBefore = find(maskBefore);

if ~isempty(cancel_progressFcn) && cancel_progressFcn(0)
    threshIdxs = [];
    canceled = true;
    return
end

maskAfter = find(maskAfter);

if ~isempty(cancel_progressFcn) && cancel_progressFcn(0)   
    threshIdxs = [];
    canceled = true;
    return
end

mask = [fliplr(-maskBefore(:)') maskAfter(:)'];

%fprintf('Threshold detection completed, %d samples remaining',length(threshIdxs));
windowMask = false(size(threshIdxs));
for idx = 1:length(threshIdxs)
    if ~isempty(cancel_progressFcn) && mod(idx,100000)==0 && (cancel_progressFcn(idx/length(threshIdxs)))
        threshIdxs = [];
        canceled = true;
        return
    end
    
    
    sampleIdx = threshIdxs(idx);
    
    if sampleIdx > length(data)-length(maskAfter) || sampleIdx <= length(maskBefore)
        continue
    end
    
    if all(data(sampleIdx) >= data(sampleIdx+mask))
        windowMask(idx) = true;
    end
end
threshIdxs = threshIdxs(windowMask);

if isempty(threshIdxs)
    return
end

% find risingEdges with debounce
debounceMask = false(size(threshIdxs));
debounceMask(1) = true;
lastValidPhtIdx = threshIdxs(1);
for idx = 2:length(threshIdxs)
    if ~isempty(cancel_progressFcn) && mod(idx,100000)==0 && (cancel_progressFcn(idx/length(threshIdxs)))
        threshIdxs = [];
        canceled = true;
        return
    end
    
    phtIdx = threshIdxs(idx);
    d = phtIdx-lastValidPhtIdx;
    if d>debounceSamples
        lastValidPhtIdx = phtIdx;
        debounceMask(idx) = true;
    end
end

threshIdxs = threshIdxs(debounceMask);

end

%--------------------------------------------------------------------------%
% findPeaks.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
