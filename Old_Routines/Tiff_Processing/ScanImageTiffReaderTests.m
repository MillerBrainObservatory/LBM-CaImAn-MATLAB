classdef ScanImageTiffReaderTests < matlab.unittest.TestCase
    methods(Test)
        function basicOperations(~)
            % Just making the calls to check if anything crashes/throws.
            % Currently, we rely on other testing of the API to make sure outputs
            % are what we expect.
            reader=ScanImageTiffReader('../../../data/resj_00001.tif');
            reader.data();
            reader.descriptions();
            reader.metadata();
            reader.apiVersion();
        end
    end
end
