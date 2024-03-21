function [xout,yout,zout] = gaussian_informed_monte_carlo_engine_fast(Nr,w0,zfocal,ztarget,ls,g,n,lambda0)

%% Inputs

% Nr = 1e4; % number of photon packets
% w0 = 1.2011e-6; % target spot size in sample
% zfocal = 500e-6; % depth of focal point in sample
% ztarget = zfocal; % depth of plane of interest in sample
% tau = 100e-15; % pulse duration
% allow_scatter = 1; % allow scattering in sample, set to 0 to turn off scattering
% epsilon = 1e-6; % step size coefficient
% dr_max = 0.5e-6; % maximum step size 

%% Constants

lambda = lambda0/n; % wavelength in medium

%% Define the input beam

zR = pi.*w0.^2./lambda; % Rayleigh range of the beam

%% Photon packet loop

Ns = 2*ceil(ztarget/ls); % maximum allowed scattering events

disp('Starting ray trace...')

% prep the output vectors
xout = zeros(1,Nr);
yout = zeros(1,Nr);
zout = zeros(1,Nr);

parfor ii = 1:Nr
    
    Ls = -ls*log(rand(1,Ns)); % distribution of distances between scattering events
    
    z0 = min([Ls(1) ztarget]); % Depth of the Gaussian beam at the time of the first scatter
    wz = w0.*sqrt(1 + (zfocal-z0).^2./zR.^2); % width of Gaussian at current z plane
    r0 = normrnd(0,wz./sqrt(2),1); % radial position drawn from Gaussian distribution
    nu0 = 2.*pi.*rand(1); % azimuthal angle, drawn from random distribution
    x0 = r0.*sin(nu0); % initial position in x
    y0 = r0.*cos(nu0); % initial position in y
    
    % determine initial angle of photon based on it's position
    Tz = (zfocal - z0)./( (zfocal - z0).^2 + zR.^2 );
    nrm = 1./sqrt(1 + (x0.^2 + y0.^2).*Tz.^2);
    mux0 = -nrm.*Tz.*x0;
    muy0 = -nrm.*Tz.*y0;
    muz0 = nrm;        
    
    if z0 < ztarget % only do random walk if beam has not already reached focal plane
        scat = 1;
    else
        scat = 0;
    end
    
    nscat = 1; % loop index
    % random photon walk
    while scat > 0
        nscat = nscat+1; 
        s = Ls(nscat); % distance to next scattering event
        cos_theta = 1/2/g*(1 + g^2  - ((1-g^2)./(1-g+2*g*rand(1))).^2); % Henyey-Greenstein phase function
        sin_theta = sqrt(1-cos_theta.^2);
        phi = 2.*pi.*rand(1);
        
        % if on axis, adjust to avoid computation errors
        if abs(muz0) > 0.9999
            mux0 = sin_theta.*cos(phi);
            muy0 = sin_theta.*sin(phi);
            muz0 = sign(muz0).*cos_theta;
        end
        
        % determine velocity vector based on scattering event
        muxp = sin_theta.*(mux0.*muz0.*cos(phi) - muy0.*sin(phi))./sqrt(1 - muz0.^2) + mux0.*cos_theta;
        muyp = sin_theta.*(muy0.*muz0.*cos(phi) + mux0.*sin(phi))./sqrt(1 - muz0.^2) + muy0.*cos_theta;
        muzp = -sqrt(1-muz0.^2).*sin_theta.*cos(phi) + muz0.*cos_theta;
        
        % if scatter puts photon past target, trace back to target plane
        if (z0 + s*muzp) > ztarget
            scat = 0;
            s = (ztarget - z0)/muzp;
        end
        
        % new positions post scatter
        xp = x0 + s*muxp;
        yp = y0 + s*muyp;
        zp = z0 + s*muzp;
        
        % stop scatter is number of events exceed number allowed
        if nscat == Ns
            scat = 0;
            xp = NaN;
            yp = NaN;
            zp = NaN;
        end
        
        % reassign initial position and angle for next iteration
        x0 = xp; mux0 = muxp;
        y0 = yp; muy0 = muyp;
        z0 = zp; muz0 = muzp;
        
    end

    xout(ii) = x0;
    yout(ii) = y0;
    zout(ii) = z0;

    if 10*ii/Nr == round(10*ii/Nr)
        disp([num2str(100*ii/Nr) '% of rays traced...'])
    end
    
end

disp('Ray trace complete.')
