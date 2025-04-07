function set_caxis(stack)

[counts, grayLevels] = hist(double(reshape(stack(:,:,1),1,[])),50);
cdf = cumsum(counts);
cdf = cdf / numel(stack(:,:,1));
index99 = find(cdf >= 0.995, 1, 'first');
maxval = grayLevels(index99);
if isempty(maxval)
   maxval = max(reshape(stack(:,:,2),1,[]));
end
index01 = find(cdf <= 0.995, 1, 'first');
minval = grayLevels(index01);
if isempty(minval)
   minval = min(reshape(stack(:,:,2),1,[]));
end

gcf;
caxis([minval maxval])