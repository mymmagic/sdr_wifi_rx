function verify_openofdm_rx_complex_to_mag_model()
%VERIFY_OPENOFDM_RX_COMPLEX_TO_MAG_MODEL Generate vectors for complex_to_mag.v.

out_dir = fileparts(mfilename('fullpath'));

i_values = int16([0 100 -100 300 -400 1000 -1000 1234 -2222 16000 -16000 -32768]);
q_values = int16([0 20 40 -300 100 -900 1000 -4321 1111 -12000 8000 0]);
n = numel(i_values);

input_words = zeros(n, 1, 'uint32');
expected_mag = zeros(n, 1, 'uint16');
for k = 1:n
    ai = abs16(i_values(k));
    aq = abs16(q_values(k));
    mx = max(ai, aq);
    mn = min(ai, aq);
    expected_mag(k) = uint16(mod(mx + floor(mn/4), 65536));
    input_words(k) = bitor(bitshift(uint32(typecast(i_values(k), 'uint16')), 16), ...
                           uint32(typecast(q_values(k), 'uint16')));
end

write_hex32(fullfile(out_dir, 'openofdm_complex_to_mag_input.hex'), input_words);
write_hex16(fullfile(out_dir, 'openofdm_complex_to_mag_expected.hex'), expected_mag);

fid = fopen(fullfile(out_dir, 'openofdm_complex_to_mag_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_complex_to_mag_model_trace.csv'), 'w');
fprintf(fid, 'idx,input_i,input_q,abs_i,abs_q,expected_mag\n');
for k = 1:n
    fprintf(fid, '%d,%d,%d,%d,%d,%d\n', k-1, i_values(k), q_values(k), ...
        abs16(i_values(k)), abs16(q_values(k)), expected_mag(k));
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_complex_to_mag_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX complex_to_mag reverse model\n');
fprintf(fid, 'formula=max(abs(i),abs(q)) + floor(min(abs(i),abs(q))/4)\n');
fprintf(fid, 'num_samples=%d\n', n);
fclose(fid);

fprintf('Wrote OpenOFDM RX complex_to_mag vectors to: %s\n', out_dir);
end

function y = abs16(x)
raw = typecast(int16(x), 'uint16');
if bitget(raw, 16)
    y = double(mod(double(bitcmp(raw)) + 1, 65536));
else
    y = double(raw);
end
end

function write_hex32(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%08x\n', values(k));
end
fclose(fid);
end

function write_hex16(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%04x\n', values(k));
end
fclose(fid);
end
