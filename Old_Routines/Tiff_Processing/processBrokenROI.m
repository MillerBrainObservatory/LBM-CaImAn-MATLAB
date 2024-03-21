function v = processBrokenROI(v,numROI,size2,stripwidth,trim)

siz = size(v);

size1 = min(siz(1:2));

buffer = (max(siz(1:2)) - numROI*size2)./(numROI-1);

clear vec
vec = '';

for ijk = 1:numROI
    
    s = (ijk-1)*(size2+buffer) + 1;
    e = s+size2-1;
    vec = [vec num2str(s)  ':' num2str(e) ' '];
    
    reordering(ijk,:) = [((ijk-1)*size2+1):(ijk*size2)];
    
end

eval(['v = v(:,[' vec '],:);'])

reordering = reshape(reordering,1,[]);

v = v(:,reordering,:);
v = reshape(v,numROI*size1,size2,[]);

if trim

    crosswidth = 8;

    vals = [];
    for ijk = 1:numROI
        vals = [vals num2str(stripwidth*(ijk-1)+crosswidth) ':' num2str(ijk*stripwidth - crosswidth) ' '];
    end

    eval(['v = v([' vals '],:,:,:);'])
    
    val = round(size(v,1)*0.03);
    
    v = v(val:end,:,:,:);

end