function write_chunk_h5(filename,Y_in, chunk)

% rewrites a file into a hdf5 file
if ~exist('chunk','var') || isempty(chunk); chunk = 2000; end
keep_reading = true;
cl = class(Y_in);
nd = ndims(Y_in) - 1;
sizY = size(Y_in);
d = prod(sizY(1:nd));
if sizY(end) < chunk+1
    keep_reading = false;
else
    if nd == 2
        Y_in(:,:,end) = [];
    elseif nd == 3
        Y_in(:,:,:,end) = [];
    end
    sizY(end) = sizY(end)-1;
end
[pathstr, name, ext] = fileparts(filename);
h5_filename = [pathstr,'/',name,'.h5'];
h5create(h5_filename,'/mov',[sizY(1:nd),Inf],'Chunksize',[sizY(1:nd),min(chunk,sizY(end))],'Datatype',cl);
h5write(h5_filename,'/mov',Y_in,[ones(1,nd),1],sizY);
cnt = sizY(end);
while keep_reading
    Y_in = read_file(filename,cnt+1,chunk+1);
    sizY = size(Y_in);
    if sizY(end) < chunk+1
        keep_reading = false;
    else
        if nd == 2
            Y_in(:,:,end) = [];
        elseif nd == 3
            Y_in(:,:,:,end) = [];
        end
        sizY(end) = sizY(end)-1;
    end
    h5write(h5_filename,'/mov',Y_in,[ones(1,nd),cnt+1],sizY);
    cnt = cnt + sizY(end);
end