function valid = is_valid_dataset(filename, location)
    try
        data = h5read(filename, location, 1, 2);
        if size(data, 1) > 20
            valid = any(data(1:20) ~= 0);
        elseif size(data, 1) > 5
            valid = any(data(1:20) ~= 0);
        else
            valid = false;
        end
    catch
        valid = false;
    end
end
