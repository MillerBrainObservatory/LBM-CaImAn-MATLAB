function reorderPlanes(h5path, loc, order)
    % REORDERPLANES Reorder planes in the HDF5 file to match the input
    % order parameter.
    %
    % Parameters
    % ----------
    % h5path : char
    %     Path to the HDF5 file.
    % loc : char
    %     Location within the HDF5 file where the planes are stored (e.g., '/registration').
    % order : array
    %     Array specifying the new order of the planes.
    
    % Validate the order
    info = h5info(h5path, loc);
    num_groups = numel(info.Groups);
    if num_groups ~= numel(order)
        error('The number of groups (%d) does not match the number of elements in order (%d).', num_groups, numel(order));
    end

    % Use a temp name to avoid conflicts
    temp_name_prefix = 'temp_plane_';

    fid = H5F.open(h5path, 'H5F_ACC_RDWR', 'H5P_DEFAULT');

    % Rename all groups to temporary names
    for i = 1:numel(order)
        original_plane_name = sprintf('%s/plane_%d', loc, order(i));
        temp_plane_name = sprintf('%s/%s%d', loc, temp_name_prefix, i);
        H5L.move(fid, original_plane_name, fid, temp_plane_name, 'H5P_DEFAULT', 'H5P_DEFAULT');
    end

    for i = 1:numel(order)
        temp_plane_name = sprintf('%s/%s%d', loc, temp_name_prefix, i);
        new_plane_name = sprintf('%s/plane_%d', loc, i);
        H5L.move(fid, temp_plane_name, fid, new_plane_name, 'H5P_DEFAULT', 'H5P_DEFAULT');

        plane_info = h5info(h5path, new_plane_name);
        for j = 1:numel(plane_info.Attributes)
            attr_name = plane_info.Attributes(j).Name;
            attr_value = h5readatt(h5path, temp_plane_name, attr_name);
            h5writeatt(h5path, new_plane_name, attr_name, attr_value);
        end
    end

    % Store the original order as an attribute so we know if this
    % dataset was altered and can re-instantiate the original order.
    original_order = 1:num_groups;
    h5writeatt(h5path, loc, 'original_order', original_order);
    h5writeatt(h5path, loc, 'reordered', true);
    h5writeatt(h5path, loc, 'new_order', order);

    H5F.close(fid);
end
