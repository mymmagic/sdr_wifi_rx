function verify_openofdm_rx_moving_avg_model()
%VERIFY_OPENOFDM_RX_MOVING_AVG_MODEL Generate vectors for moving_avg.v.

out_dir = fileparts(mfilename('fullpath'));

data_width = 16;
window_shift = 2;
x = int16([10 -4 7 12 -5 20 -8 3 16 -2 9 11 -7 6]);
n = numel(x);

trace = openofdm_rx_moving_avg_model(double(x), data_width, window_shift);

input_words = zeros(n, 1, 'uint16');
expected_out = zeros(n, 1, 'uint16');
expected_stb = zeros(n, 1, 'uint8');
for k = 1:n
    input_words(k) = typecast(x(k), 'uint16');
    expected_out(k) = typecast(int16(trace(k).data_out), 'uint16');
    expected_stb(k) = uint8(trace(k).output_strobe);
end

write_hex16(fullfile(out_dir, 'openofdm_moving_avg_input.hex'), input_words);
write_hex16(fullfile(out_dir, 'openofdm_moving_avg_expected.hex'), expected_out);
write_hex8(fullfile(out_dir, 'openofdm_moving_avg_expected_stb.hex'), expected_stb);

fid = fopen(fullfile(out_dir, 'openofdm_moving_avg_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_moving_avg_model_trace.csv'), 'w');
fprintf(fid, 'idx,input,addr,full,old_data_used,running_sum_before,data_out,output_strobe\n');
for k = 1:n
    fprintf(fid, '%d,%d,%d,%d,%d,%d,%d,%d\n', ...
        trace(k).idx, trace(k).input, trace(k).addr, trace(k).full, ...
        trace(k).old_data_used, trace(k).running_sum_before, ...
        trace(k).data_out, trace(k).output_strobe);
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_moving_avg_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX moving_avg reverse model\n');
fprintf(fid, 'DATA_WIDTH=%d WINDOW_SHIFT=%d WINDOW_SIZE=%d\n', data_width, window_shift, 2^window_shift);
fprintf(fid, 'note=data_out is running_sum before current update; old_data is RAM dob from previous strobe.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX moving_avg vectors to: %s\n', out_dir);
end

function write_hex16(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%04x\n', values(k));
end
fclose(fid);
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
