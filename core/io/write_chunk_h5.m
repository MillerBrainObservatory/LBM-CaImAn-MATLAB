function write_chunk_h5(file, Y_in, chunk, dataset_name)
if ~exist('dataset_name','var') || isempty(dataset_name);dataset_name = '/mov';end
if ~exist('chunk','var') || isempty(chunk) chunk = 2000; end
keep_reading = true;
cl = class(Y_in);
nd = ndims(Y_in) - 1;
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

h5_filename = file;
h5create(h5_filename,dataset_name,[sizY(1:nd),Inf],'Chunksize',[sizY(1:nd),min(chunk,sizY(end))],'Datatype',cl);
h5write(h5_filename,dataset_name,Y_in,[ones(1,nd),1],sizY);
cnt = sizY(end);
while keep_reading
    Y_in = read_file(file,cnt+1,chunk+1);
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
    h5write(h5_filename,dataset_name,Y_in,[ones(1,nd),cnt+1],sizY);
    cnt = cnt + sizY(end);
end