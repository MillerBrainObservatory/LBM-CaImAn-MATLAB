function vol = ProcessScanImageTiffMAxiMuM(file,nx,ny,nc,config)

addpath(genpath('C:\Users\myadmin\Documents\MATLAB\ScanImageTiffReader\share\matlab\'))
vol = ScanImageTiffReader(file).data();

switch config
    case('3mm_3p5um')
        col_pix = 870;
        vol1 = vol(:,1:col_pix,:);
        vol2 = vol(:,col_pix+1:2*col_pix,:);
        vol3 = vol(:,2*col_pix+1:3*col_pix,:);
        vol4 = vol(:,3*col_pix+1:4*col_pix,:);
        vol5 = vol(:,4*col_pix+1:5*col_pix,:);
        
        clear vol
        
        vol = [vol1; vol2; vol3; vol4; vol5];
end

vol = reshape(vol,ny,nx,nc,[]);

