function metadata = read_h5_metadata(h5_fullfile, loc)
    h5_data = h5info(h5_fullfile, loc);
    metadata = struct();
    for k = 1:numel(h5_data.Attributes)
        attr_name = h5_data.Attributes(k).Name;
        attr_value = h5readatt(h5_fullfile, ['/' h5_data.Name], attr_name);
        metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
    end
end