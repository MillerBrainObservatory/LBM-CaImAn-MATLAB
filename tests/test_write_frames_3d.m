function test_write_frames_3d()

    initial_data = rand(5, 5, 5);
    append_data = rand(5, 5, 5);
    file_name = 'test.h5';
    dataset_name = '/Y';

    if exist(file_name, 'file'); delete(file_name); end
    write_frames_3d(file_name, initial_data, '/Y');
    data_read = h5read(file_name, dataset_name);
    assert(isequal(data_read, initial_data), 'Initial data write failed');

    write_frames_3d(file_name, append_data, '/Y','append', true);
    data_read = h5read(file_name, dataset_name);
    expected_data = cat(3, initial_data, append_data);
    assert(isequal(data_read, expected_data), 'Data append failed');

    if exist(file_name, 'file'); delete(file_name); end

    disp('All tests passed successfully');
end
