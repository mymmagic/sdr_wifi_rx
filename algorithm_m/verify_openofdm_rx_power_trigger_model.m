function verify_openofdm_rx_power_trigger_model()
%VERIFY_OPENOFDM_RX_POWER_TRIGGER_MODEL Generate vectors for power_trigger.v.

out_dir = fileparts(mfilename('fullpath'));

power_thres = 100;
window_size = 3;
skip_samples = 0;

i_values = int16([ ...
    0 12 -30 80 99 100 101 130 -150 90 80 70 60 50 ...
    120 140 90 80 70 60 50 -32768 0 0 0 0 0 130 20 20 20 20 20]);
q_values = int16([ ...
    7 -4 1000 -1000 15 -16 99 -99 44 33 22 11 0 -1 ...
    3 4 5 6 7 8 9 10 -11 -12 -13 -14 -15 16 17 18 19 20 21]);

trace = openofdm_rx_power_trigger_model(i_values, power_thres, window_size, skip_samples);
n = numel(i_values);

input_words = zeros(n, 1, 'uint32');
expected_trigger = zeros(n, 1, 'uint8');
expected_state = zeros(n, 1, 'uint8');
for k = 1:n
    input_words(k) = bitor(bitshift(uint32(typecast(i_values(k), 'uint16')), 16), ...
                           uint32(typecast(q_values(k), 'uint16')));
    expected_trigger(k) = uint8(trace(k).trigger);
    expected_state(k) = uint8(trace(k).state);
end

write_hex32(fullfile(out_dir, 'openofdm_power_trigger_input.hex'), input_words);
write_hex8(fullfile(out_dir, 'openofdm_power_trigger_expected.hex'), expected_trigger);
write_hex8(fullfile(out_dir, 'openofdm_power_trigger_expected_state.hex'), expected_state);

fid = fopen(fullfile(out_dir, 'openofdm_power_trigger_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

trace_path = fullfile(out_dir, 'openofdm_power_trigger_model_trace.csv');
fid = fopen(trace_path, 'w');
fprintf(fid, 'idx,input_i,abs_i_used,abs_i_next,state,sample_count,trigger\n');
for k = 1:n
    fprintf(fid, '%d,%d,%d,%d,%d,%d,%d\n', ...
        trace(k).idx, trace(k).input_i, trace(k).abs_i_used, trace(k).abs_i_next, ...
        trace(k).state, trace(k).sample_count, trace(k).trigger);
end
fclose(fid);

summary_path = fullfile(out_dir, 'openofdm_power_trigger_model_summary.txt');
fid = fopen(summary_path, 'w');
fprintf(fid, 'OpenOFDM RX power_trigger reverse model\n');
fprintf(fid, 'power_thres=%d window_size=%d skip_samples=%d\n', power_thres, window_size, skip_samples);
fprintf(fid, 'num_samples=%d\n', n);
fprintf(fid, 'note=RTL uses registered abs(I), so trigger decisions lag input_i by one accepted strobe.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX power_trigger vectors to: %s\n', out_dir);
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
