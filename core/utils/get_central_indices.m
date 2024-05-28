function [y_ind, x_ind] = get_central_indices(img, r, c, pixels)
    half_pix = floor(pixels / 2);
    r_start = max(r - half_pix, 1);
    r_end = min(r + half_pix, size(img, 1));
    c_start = max(c - half_pix, 1);
    c_end = min(c + half_pix, size(img, 2));
    y_ind = (r_start:r_end);
    x_ind = (c_start:c_end);
end