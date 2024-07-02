function valid = is_valid_group(x)
if startsWith(x, '/')
    x = char(x);
    if endsWith(x, '/')
        x = x(1:end-1);
    end
    valid = true;
    p.Results.group_path = string(x);
else
    error('group_path must start with a leading /.');
end
end
