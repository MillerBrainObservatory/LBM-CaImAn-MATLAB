classdef ChannelImageHandler < scanimage.interfaces.Class
% Handles preset colormap specifications etc for channel images. Eventually
% can expand this to handle all channel-image "view" code. (Can move
% channel images, merge, etc out of SI core.)

    properties (Constant)        
        % col 1: pretty spec. col 2: detailed spec        
        colorMapSpecs = {
            'Gray'              {'gray' 'gray' 'gray'} 
            'Gray - High Sat.'  {'grayHighSat' 'grayHighSat' 'grayHighSat'}
            'Gray - Low Sat.'   {'grayLowSat' 'grayLowSat' 'grayLowSat'}
            'Gray - Both Sat.'  {'grayBothSat' 'grayBothSat' 'grayBothSat'}
            'Jet'               {'jet' 'jet' 'jet'}
            'R/G/Gray/Gray'     {'red' 'green' 'gray'}
            'G/R/Gray/Gray'     {'green' 'red' 'gray'}
            };
        prettyColorMapSpecs = scanimage.guis.ChannelImageHandler.colorMapSpecs(:,1);
        colorMapUITableColumnIdx = 7; % hardcoded for now, columnArrayTable doesn't handle everything needed  
    end
        
    properties
        hChannelControlsCAT; % ColumnArrayTable PropControl for channelControls uitable
        hChannelControlsUITable; % for ColumnEditable property, currently not a member of ColumnArrayTable
        hChannelImageFigs; % NChannelsx1 array of handles to channel image figures
    end
        
    methods
        
        function obj = ChannelImageHandler(hColumnArrayTable,hUITable)
            assert(isa(hColumnArrayTable,'most.gui.control.ColumnArrayTable'));
            assert(ishandle(hUITable) && strcmp(get(hUITable,'Type'),'uitable'));
            
            obj.hChannelControlsCAT = hColumnArrayTable;
            obj.hChannelControlsUITable = hUITable;
            obj.hChannelImageFigs = []; % remains empty until registerChannelImageFigs is called
        end
        
        function registerChannelImageFigs(obj,hFigs)
            assert(all(ishandle(hFigs))); % && numel(hFigs)==obj.hChannelControlsCAT.nRows);
            obj.hChannelImageFigs = hFigs;
            obj.applyTableColorMapsToImageFigs;
        end
        
        function initColorMapsInTable(obj)
            pms = scanimage.guis.ChannelImageHandler.prettyColorMapSpecs{1};
            obj.updateTable(pms);
        end
        
        function updateTable(obj,prettyColorMapSpec)
            assert(ischar(prettyColorMapSpec));
            if strcmp(prettyColorMapSpec,'Custom')
                ce = get(obj.hChannelControlsUITable,'ColumnEditable');
                ce(obj.colorMapUITableColumnIdx) = true;
                set(obj.hChannelControlsUITable,'ColumnEditable',ce);
            else
                cms = obj.colorMapSpecs;
                [tf loc] = ismember(prettyColorMapSpec,cms(:,1));
                assert(tf);
                clrSpecs = cms{loc,2};
                
                % truncate/expand clrSpecs to match number of rows in tbl
                Nrows = obj.hChannelControlsCAT.nRows;
                if numel(clrSpecs) > Nrows
                    clrSpecs = clrSpecs(1:Nrows);
                elseif numel(clrSpecs) < Nrows
                    clrSpecs(end+1:Nrows) = clrSpecs(end);
                end
     
                % set colormap values in table
                clrMapVals = cellfun(@(x)obj.colorMapSpec2MLCmd(x),clrSpecs,'UniformOutput',false);
                dat = get(obj.hChannelControlsUITable,'Data');
                dat(:,obj.colorMapUITableColumnIdx) = clrMapVals(:);
                set(obj.hChannelControlsUITable,'Data',dat);
                
                % update column editable-ness
                ce = get(obj.hChannelControlsUITable,'ColumnEditable');
                ce(obj.colorMapUITableColumnIdx) = false;
                set(obj.hChannelControlsUITable,'ColumnEditable',ce);
            end
        end
        
        function applyTableColorMapsToImageFigs(obj)
            assert(~isempty(obj.hChannelImageFigs)); % channel images must be registered
            
            tableDat = get(obj.hChannelControlsUITable,'Data');
            colorMapFcns = tableDat(:,obj.colorMapUITableColumnIdx);
            hFigs = obj.hChannelImageFigs;
            
            for c = 1:numel(colorMapFcns)
                cm = [];
                evalstr = sprintf('cm = %s;',colorMapFcns{c});
                try
                    eval(evalstr);
                    set(hFigs(c),'ColorMap',cm);
                catch  %#ok<CTCH>
                    warning('scanimage:ChannelImageHandler',...
                        'Error caught evaluating/applying colormap specification for channel %d. Leaving colormap unchanged.',c);
                    continue;
                end
            end            
        end
        
    end
    
    methods (Static)
        
        function cmd = colorMapSpec2MLCmd(spec)
            cmd = sprintf('obj.scim_colorMap(''%s'',8,5)',spec);
        end        
        
        
        function map = scim_colorMap(color, numBits, satLevel)
            %% function map = scim_colorMap(color, numBits, satLevel)
            % Default function used by ScanImage to generate colormap used by Image display figures
            %
            %% SYNTAX
            %   color: <OPTIONAL - Default='gray'> One of {'gray' 'grayHighSat' 'grayLowSat' 'grayBothSat' 'red' 'green' 'blue'}
            %           gray: Identical to Matlab gray() function
            %           grayHighSat: Gray colormap with pixels near high saturation (determined by numBits/satLevel) colored red
            %           grayLowSat: Gray colormap with pixels near low saturation (determined by numBits/satLevel) colored red
            %           grayBothSat: Combination of grayHighSat/grayLowSat
            %           red: Simple linear map from black to maximal red intensity (length/steps determined by numBits)
            %           green: Simple linear map from black to maximal green intensity (length/steps determined by numBits)
            %           blue: Simple linear map from black to maximal blue intensity (length/steps determined by numBits)
            %
            %   numBits: <OPTIONAL - Default=8> Specifies length (2^numBits) of map and step-size of color increments (1/(2^(numBits-1)).
            %   satLevel: <OPTIONAL - Default=5> Applies to 'grayHighSat'/'grayLowSat'/'grayBothSat' cases. Specifies, as percentage of the entire range (0-2^(numBits-1)), range of high and/or low levels to consider saturated.
            %
            %   map: An Nx3 matrix, where N=2^numBits, specifying a valid Matlab colormap (see 'help colormap' for more details)
            
            %% NOTES
            %   Type 'help colormap' or 'doc colormap' at Matlab command line for background
            %
            %   To change the default colormap used by ScanImage,in the Channels... dialog, users can:
            %       1) Change the arguments (color, bits) to scim_colorMap()
            %       2) Change the function to a Matlab built-in colormap function, e.g. to 'jet(256)' (see 'help colormap' for list of options)
            %       3) Change the function to a user-supplied colormap function, which should output a single argument 'map' containing an Nx3 matrix (see 'help colormap' for information on color map matrices)
            %
            %   If users create their own colormap function, they must ensure it is located on the Matlab path
            %
            %% CREDITS
            %   Created 11/22/10, by Vijay Iyer
            %   Based heavily on previous makeColorMap() function (unknown author)
            %% ******************************************************************************
            
            if nargin < 1 || isempty(color)
                color='gray';
                numBits=8;
                satLevel = 5;
            end
            
            if nargin < 2 || isempty(numBits)
                numBits=8;
                satLevel = 5;
            end
            
            if nargin < 3 || isempty(satLevel)
                satLevel = 5;
            end
            
            a = zeros(2^numBits-1,1);
            b = (0:1/(2^numBits-2):1)';
            fraction = .01 * satLevel;
            index=round(fraction*length(b));
            
            switch color
                case 'red'
                    map = squeeze(cat(3, b, a, a));
                case 'green'
                    map = squeeze(cat(3, a, b, a));
                case 'blue'
                    map = squeeze(cat(3, a, a, b));
                case 'gray'
                    map = squeeze(cat(3, b, b, b));
                case 'grayHighSat'
                    map = squeeze(cat(3, b, b, b));
                    map(end-index:end,[2 3])=0;
                case 'grayLowSat'
                    map = squeeze(cat(3, b, b, b));
                    map(1:index,[1 3])=0;
                    map(1:index,2)=flipud(linspace(.8,1,length(map(1:index,2)))');
                case 'grayBothSat'
                    map = squeeze(cat(3, b, b, b));
                    map(end-index:end,[2 3])=0;
                    map(1:index,[1 3])=0;
                    map(1:index,2)=flipud(linspace(.8,1,length(map(1:index,2)))');
                case 'jet'
                    map = jet;
            end
        end    
    end
end
    


%--------------------------------------------------------------------------%
% ChannelImageHandler.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
