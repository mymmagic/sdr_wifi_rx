function verify_openofdm_rx_delay_sample_model()
%VERIFY_OPENOFDM_RX_DELAY_SAMPLE_MODEL Generate vectors for delay_sample.v.

out_dir = fileparts(mfilename('fullpath'));

delay_shift = 3;
i_values = int16([1 2 3 4 5 6 7 8 9 10 -11 -12 13 14 15 16 17 18]);
q_values = int16([101 102 103 104 105 106 107 108 109 110 -111 -112 113 114 115 116 117 118]);
n = numel(i_values);

input_words = zeros(n, 1, 'uint32');
for k = 1:n
    input_words(k) = bitor(bitshift(uint32(typecast(i_values(k), 'uint16')), 16), ...
                           uint32(typecast(q_values(k), 'uint16')));
end

trace = openofdm_rx_delay_sample_model(double(input_words), delay_shift);

expected_out = zeros(n, 1, 'uint32');
expected_stb = zeros(n, 1, 'uint8');
for k = 1:n
    expected_out(k) = uint32(trace(k).data_out);
    expected_stb(k) = uint8(trace(k).output_strobe);
end

write_hex32(fullfile(out_dir, 'openofdm_delay_sample_input.hex'), input_words);
write_hex32(fullfile(out_dir, 'openofdm_delay_sample_expected.hex'), expected_out);
write_hex8(fullfile(out_dir, 'openofdm_delay_sample_expected_stb.hex'), expected_stb);

fid = fopen(fullfile(out_dir, 'openofdm_delay_sample_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_delay_sample_model_trace.csv'), 'w');
fprintf(fid, 'idx,input_hex,addr,full,data_out_hex,output_strobe\n');
for k = 1:n
    fprintf(fid, '%d,%08x,%d,%d,%08x,%d\n', ...
        trace(k).idx, uint32(trace(k).input), trace(k).addr, trace(k).full, ...
        uint32(trace(k).data_out), trace(k).output_strobe);
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_delay_sample_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX delay_sample reverse model\n');
fprintf(fid, 'DATA_WIDTH=32 DELAY_SHIFT=%d DELAY_SIZE=%d\n', delay_shift, 2^delay_shift);
fprintf(fid, 'note=output is old RAM value at current address; output_strobe starts after one full address cycle.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX delay_sample vectors to: %s\n', out_dir);
end

function write_hex32(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%08x\n', values(k));
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
