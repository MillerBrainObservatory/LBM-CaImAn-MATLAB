%% Newport XPS
positionerNames = {'' '' ''}; %Positioner names as strings, in the order XYZ. Use empty string if dimension isn't used (e.g. If only using the z dimensions {'','','Z.Z'})
ipAddress = '192.168.0.254';
port = 5001;
acceleration = [1E3 1E3 40E3];    %um per s
velocity = [.4E3 .4E3 5E3];       %um per s
minJerkRaw = [.005 .005 .005];    %device units
maxJerkRaw = [.005 .005 .005];    %device units
invertCoordinates = [0 0 0];
