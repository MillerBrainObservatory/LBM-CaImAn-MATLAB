classdef CameraRegistry
    methods (Static)
        function entries = getAllCameraEntries()
            import scanimage.components.cameramanager.registry.*
            entries = CameraRegistryEntry.empty(0,1); % not handle objects;
            
            % list camera registry entries here
            entries(end+1) = CameraRegistryEntry({'MicroManager'},'dabs.micromanager.Camera');
            entries(end+1) = CameraRegistryEntry({'Simulated' 'sim'},'dabs.simulated.Camera');
            entries(end+1) = CameraRegistryEntry({'Spinnaker'}, 'dabs.Spinnaker.Camera');

            % validation
            assert(most.idioms.isunique([entries.prettyNames]),'Duplicate entries found in camera registry');
        end
        
        function entry = getCameraEntryByName(name)
            import scanimage.components.cameramanager.registry.*
            entries = CameraRegistry.getAllCameraEntries();
            mask = arrayfun(@(entry)any(strcmpi(entry.prettyNames,name)), entries);
            entry = entries(mask);
        end
    end
end

%--------------------------------------------------------------------------%
% CameraRegistry.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
