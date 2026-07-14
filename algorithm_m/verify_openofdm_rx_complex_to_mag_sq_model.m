function verify_openofdm_rx_complex_to_mag_sq_model()
%VERIFY_OPENOFDM_RX_COMPLEX_TO_MAG_SQ_MODEL Generate vectors for complex_to_mag_sq.v.

out_dir = fileparts(mfilename('fullpath'));

i_values = int16([0 3 -4 100 -100 511 -512 1234 -2048 12000 -16000]);
q_values = int16([0 4 3 -50 50 -300 301 -432 1024 -5000 7000]);
n = numel(i_values);

input_words = zeros(n, 1, 'uint32');
expected_mag_sq = zeros(n, 1, 'uint32');
for k = 1:n
    i = double(i_values(k));
    q = double(q_values(k));
    expected_mag_sq(k) = uint32(i*i + q*q);
    input_words(k) = bitor(bitshift(uint32(typecast(i_values(k), 'uint16')), 16), ...
                           uint32(typecast(q_values(k), 'uint16')));
end

write_hex32(fullfile(out_dir, 'openofdm_complex_to_mag_sq_input.hex'), input_words);
write_hex32(fullfile(out_dir, 'openofdm_complex_to_mag_sq_expected.hex'), expected_mag_sq);

fid = fopen(fullfile(out_dir, 'openofdm_complex_to_mag_sq_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_complex_to_mag_sq_model_trace.csv'), 'w');
fprintf(fid, 'idx,input_i,input_q,expected_mag_sq\n');
for k = 1:n
    fprintf(fid, '%d,%d,%d,%u\n', k-1, i_values(k), q_values(k), expected_mag_sq(k));
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_complex_to_mag_sq_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX complex_to_mag_sq reverse model\n');
fprintf(fid, 'formula=I^2 + Q^2 via (I+jQ)*(I-jQ) real output\n');
fprintf(fid, 'num_samples=%d\n', n);
fclose(fid);

fprintf('Wrote OpenOFDM RX complex_to_mag_sq vectors to: %s\n', out_dir);
end

function write_hex32(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%08x\n', values(k));
end
fclose(fid);
end
