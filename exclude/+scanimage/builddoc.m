% Build html documentation for the package.
% This should be run after 'cmake --build build --target install'.

options=struct('format','html','outputDir','public');
publish('ScanImageTiffReader.index',options);
