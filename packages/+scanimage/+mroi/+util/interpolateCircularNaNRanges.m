function data = interpolateCircularNaNRanges(data,boundingpolygon,algorithm,rangeIdentifier)
if nargin < 2 || isempty(boundingpolygon)
    boundingpolygon = [];
end

if nargin < 3 || isempty(algorithm)
    algorithm = 'tryall';
end

if nargin < 4 || isempty(rangeIdentifier)
    rangeIdentifier = NaN;
end

% data needs to be a Nx1 or Nx2 matrix
assert(size(data,2) == 1 || size(data,2) == 2);

[nanRanges,isIdentifierFnc] = scanimage.mroi.util.findNaNRanges(data,rangeIdentifier);
if isempty(nanRanges);return;end % Nothing to interpolate

if any(isIdentifierFnc(data(1,:))) && any(isIdentifierFnc(data(end,:)))
    shifted = nanRanges(end,2)-nanRanges(end,1)+1;
    data = circshift(data,[shifted,0]);
    nanRanges = scanimage.mroi.util.findNaNRanges(data,rangeIdentifier);
else
    shifted = 0;
end

datalen = size(data,1);
Nnr = size(nanRanges,1);

% find nan ranges with only one point in between
% these are waypoints that dictate position but
% dont constrain velocity

for i = 1:Nnr
    st = nanRanges(i,1); % start index
    en = nanRanges(i,2); % end index
    len = en - st + 1;
    
    pi  = st - 1;
    ppi = st - 2;
    ni  = en + 1;
    nni = en + 2;
    
    % ensure index rolls over correctly
    pi  = pi  + datalen*(pi<1);
    ppi = ppi + datalen*(ppi<1);
    ni  = ni  - datalen*(ni>datalen);
    nni = nni - datalen*(nni>datalen);
    
    % fetch data
    p  = data(pi,:);
    pp = data(ppi,:);
    n  = data(ni,:);
    nn = data(nni,:);
    
    if isIdentifierFnc(pp)
        % there is only one point before this nan range. that is a way
        % point that does not contrain velocity. determine a velocity
        
        % get the previous nan range
        ipr = i-1;
        ipr = ipr + Nnr*(ipr<1);
        stpr = nanRanges(ipr,1); % start index
        enpr = nanRanges(ipr,2); % end index
        lenpr = enpr - stpr + 1;
        
        %get the point preceding the previous nan range
        ppr = stpr - 1;
        ppr = ppr + datalen*(ppr<1);
        ppr = data(ppr,:);
        
        % average velocity from point preceding previous nan range to point
        % preceding this nan range
        velpr = (p - ppr) / lenpr;
        
        % average velocity over this nan range
        velth = (n - p) / len;
        
        % mean of the two
        vel = (velpr + velth) * .5;
        
        pp = p - vel;
        data(ppi,:) = pp;
    end
    
    if isIdentifierFnc(nn)
        % there is only one point after this nan range. that is a way
        % point that does not contrain velocity. determine a velocity
        
        % get the next nan range
        inr = i+1;
        inr = inr - Nnr*(inr>Nnr);
        stnr = nanRanges(inr,1); % start index
        ennr = nanRanges(inr,2); % end index
        lennr = ennr - stnr + 1;
        
        %get the point after the previous nan range
        nnr = ennr + 1;
        nnr = nnr - datalen*(nnr>datalen);
        nnr = data(nnr,:);
        
        % average velocity from point after this nan range to point
        % after next nan range
        velnr = (nnr - n) / lennr;
        
        % average velocity over this nan range
        velth = (n - p) / len;
        
        % mean of the two
        vel = (velnr + velth) * .5;
        
        nn = n + vel;
        data(nni,:) = nn;
    end
    
    assert(~(any(isIdentifierFnc(p))||any(isIdentifierFnc(n))||any(isIdentifierFnc(pp))||any(isIdentifierFnc(nn))),'Something bad happened');
    
    switch lower(algorithm)
        case {'tryall','default'}
            data(st:en,:) = interpolateNaNRangeDefault(pp,p,n,nn,len,boundingpolygon);
        case 'maa'
            data(st:en,:) = interpolateNaNRangeMAA(pp,p,n,nn,len);
        case 'spline'
            data(st:en,:) = interpolateNaNRangeSpline(pp,p,n,nn,len);
        case 'pchip'
            data(st:en,:) = interpolateNaNRangePchip(pp,p,n,nn,len);
        case 'linear'
            data(st:en,:) = interpolateNaNRangeLinear(pp,p,n,nn,len);
        case 'linearwithsettle'
            data(st:en,:) = interpolateNaNRangeLinearWithTwoThirdSettleTime(pp,p,n,nn,len);
        otherwise
            error('Unsupport algorithm: %s',algorithm);
    end
end

if shifted ~= 0
    data = circshift(data,-shifted); % shift data back
end
end

%local functions
function data = interpolateNaNRangeDefault(pp,p,n,nn,numPoints,boundingpolygon)
if nargin < 6 || isempty(boundingpolygon)
    checkbounds = false;
else
    checkbounds = true;
end

data = interpolateNaNRangeMAA(pp,p,n,nn,numPoints);
if ~checkbounds || boundcheck(data,boundingpolygon)
    return
end

data = interpolateNaNRangeSpline(pp,p,n,nn,numPoints);
if ~checkbounds || boundcheck(data,boundingpolygon)
    return
end

data = interpolateNaNRangePchip(pp,p,n,nn,numPoints);
if ~checkbounds || boundcheck(data,boundingpolygon)
    return
end

data = interpolateNaNRangeLinear(pp,p,n,nn,numPoints);
end

function data = interpolateNaNRangeMAA(pp,p,n,nn,numPoints)
data = zeros(numPoints,length(pp));
for idx = 1:length(pp)
    dd = scanimage.mroi.util.MAA_curve(p(idx),n(idx),p(idx)-pp(idx),nn(idx)-n(idx),numPoints-1,numPoints+1);
    data(:,idx) = dd(2:end-1);
end
end

function data = interpolateNaNRangeSpline(pp,p,n,nn,numPoints)
data = zeros(numPoints,length(pp));
for idx = 1:length(pp)
    data(:,idx) = spline([0 numPoints+1],[p(idx)-pp(idx),p(idx),n(idx),nn(idx)-n(idx)],1:numPoints)';
end
end

function data = interpolateNaNRangePchip(pp,p,n,nn,numPoints)
data = zeros(numPoints,length(pp));
for idx = 1:length(pp)
    data(:,idx) = pchip([-1 0 numPoints+1 numPoints+2],[pp(idx),p(idx),n(idx),nn(idx)],1:numPoints)';
end
end

function data = interpolateNaNRangeLinear(pp,p,n,nn,numPoints)
data = zeros(numPoints+2,length(p));
for idx = 1:length(p)
    data(:,idx) = linspace(p(idx),n(idx),numPoints + 2)';
end
data([1,end],:) = [];
end

function data = interpolateNaNRangeLinearWithTwoThirdSettleTime(pp,p,n,nn,numPoints)
data = ones(numPoints+2,length(p)) * n;
numPoints_third = ceil((numPoints+2)/3);
for idx = 1:length(p)
    data(1:numPoints_third,idx) = linspace(p(idx),n(idx),numPoints_third)';
end
data([1,end],:) = [];
end

function datavalid = boundcheck(data,boundingpolygon)
if size(data,2) == 1
    boundingpolygon = sort(boundingpolygon);
    minVal = boundingpolygon(1);
    maxVal = boundingpolygon(2);
    datavalid = min(data) > minVal && max(data) < maxVal;
elseif size(data,2) == 2
    if isNonRotatedRect(boundingpolygon)
        % inpolygon is slow, speed things up if polygon is a non
        % rotaged rectangle
        minX = min(boundingpolygon(:,1));
        maxX = max(boundingpolygon(:,1));
        minY = min(boundingpolygon(:,2));
        maxY = max(boundingpolygon(:,2));
        datavalid = all(data(:,1)>=minX & data(:,1)<=maxX & data(:,2)>=minY & data(:,2) <=maxY);
    else
        datavalid = all(inpolygon(data(:,1),data(:,2),boundingpolygon(:,1),boundingpolygon(:,2)));
    end
else
    assert(false);
end
end

function tf = isNonRotatedRect(polygon)
if size(polygon,1) ~= 4
    tf = false;
    return
end

% all normalized vectors have to be either [0 1] or [1 0]
v = diff([polygon;polygon(1,:)],1,1);
v = sort(abs(v),2);
tf = all(v(:,1)==0) && all(v(:,2)~=0);
end

%--------------------------------------------------------------------------%
% interpolateCircularNaNRanges.m                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
