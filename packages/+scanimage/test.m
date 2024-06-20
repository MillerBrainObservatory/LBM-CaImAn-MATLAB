% Runs the suite of tests exposed by the ScanImageTiffReader package using matlab's unit testing framework.

try
    res=runtests('ScanImageTiffReader');
    exit(any([res(:).Failed]))
catch me
    disp(me)
    exit(-1)
end