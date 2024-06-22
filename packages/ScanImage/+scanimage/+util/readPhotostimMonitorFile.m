function out = readPhotostimMonitorFile(filename)
    %% get photostim geometry
    hFile = fopen(filename,'r');
    phtstimdata = fread(hFile,'single');
    fclose(hFile);

    % sanity check for file size
    % each data record consists of three entries of type single: x,y,beam power
    datarecordsize = 3;
    lgth = length(phtstimdata);
    if mod(lgth,datarecordsize) ~= 0
        most.idioms.warn('Unexpected size of photostim log file');
        lgth = floor(lgth/datarecordsize) * datarecordsize;
        phtstimdata = phtstimdata(1:lgth);
    end
    phtstimdata = reshape(phtstimdata',3,[])';

    % x,y are in reference coordinate space, beam power is in [V], native readout of photo diode
    out.X = phtstimdata(:,1);
    out.Y = phtstimdata(:,2);
    out.Beam = phtstimdata(:,3);

    %the monitoring rate is saved to the tiff header
    %phstimrate = header.SI.hPhotostim.monitoringSampleRate;
    %phtstimtimeseries = linspace(0,lgth/phstimrate-1/phstimrate,lgth);
end


%--------------------------------------------------------------------------%
% readPhotostimMonitorFile.m                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
