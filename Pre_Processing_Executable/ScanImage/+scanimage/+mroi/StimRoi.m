function hRoi = StimRoi(varargin)
    % Helper function that creates a roi, creates a stimulus field, and adds the stim to the roi at plane zero takes
    % the same arguments as scanimage.mroi.scanfield.fields.StimulusField(); with the exception that the first argument
    % can be just a string containing the name of a stim function in the scanimage.mroi.stimulusfunctions package or a
    % function handle like scanimage.mroi.scanfield.fields.StimulusField() expects.
    if ischar(varargin{1})
        varargin{1} = str2func(['scanimage.mroi.stimulusfunctions.' varargin{1}]);
    end
    
    hStim = scanimage.mroi.scanfield.fields.StimulusField(varargin{:});
    hRoi = scanimage.mroi.Roi;
    hRoi.add(0,hStim);
end



%--------------------------------------------------------------------------%
% StimRoi.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
