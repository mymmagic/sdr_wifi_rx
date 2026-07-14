function verify_openwifi_tx_modulation_model()
%VERIFY_OPENWIFI_TX_MODULATION_MODEL Generate expected vectors for modulation.v.

out_dir = fileparts(mfilename('fullpath'));
modes = [1, 2, 4, 6];
num_cases = numel(modes) * 64;

input_rows = zeros(num_cases, 2);
expected = zeros(num_cases, 2);
idx = 1;
for m = 1:numel(modes)
    for b = 0:63
        input_rows(idx, :) = [modes(m), b];
        expected(idx, :) = double(openwifi_tx_modulation_model(modes(m), b));
        idx = idx + 1;
    end
end

write_input_rows(fullfile(out_dir, 'modulation_input.txt'), input_rows);
write_hex_words(fullfile(out_dir, 'modulation_expected.hex'), expected);
write_txt_pairs(fullfile(out_dir, 'modulation_expected.txt'), expected);

summary_path = fullfile(out_dir, 'modulation_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi openofdm_tx modulation fixed-point reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\modulation.v\n');
fprintf(fid, 'Cases: %d, all bits_in values for N_BPSC=1,2,4,6\n', num_cases);
fprintf(fid, 'BPSK level: +/-16384\n');
fprintf(fid, 'QPSK level: +/-11585\n');
fprintf(fid, '16QAM levels: +/-15543, +/-5181\n');
fprintf(fid, '64QAM levels: +/-17696, +/-12640, +/-7584, +/-2528\n');
fprintf(fid, 'All levels are signed 16-bit integer I/Q values.\n');

fprintf('Wrote modulation vectors to: %s\n', out_dir);
end

function write_input_rows(path_name, rows)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:size(rows, 1)
    fprintf(fid, '%d %d\n', rows(k, 1), rows(k, 2));
end
end

function write_hex_words(path_name, iq)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:size(iq, 1)
    r = to_u16(iq(k, 1));
    i = to_u16(iq(k, 2));
    fprintf(fid, '%04X%04X\n', r, i);
end
end

function write_txt_pairs(path_name, iq)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:size(iq, 1)
    fprintf(fid, '%d %d\n', iq(k, 1), iq(k, 2));
end
end

function u = to_u16(v)
u = mod(round(double(v)), 65536);
end
