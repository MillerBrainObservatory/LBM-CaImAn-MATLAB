%% Photostim
photostimScannerName = '';          % Name of scanner (from first MDF section) to use for photostimulation. Must be a linear scanner

%Monitoring DAQ AI channels
BeamAiId      = 7;                  % AI channel to be used for monitoring the Pockels cell output

loggingStartTrigger = '';           % one of {'','PFI#'} to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus
