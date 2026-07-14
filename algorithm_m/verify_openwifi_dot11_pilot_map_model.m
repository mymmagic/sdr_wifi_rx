function verify_openwifi_dot11_pilot_map_model()
%VERIFY_OPENWIFI_DOT11_PILOT_MAP_MODEL Generate vectors for dot11_tx pilot map.

out_dir = fileparts(mfilename('fullpath'));

init_pilot_scram_state = uint8(bin2dec('1011101'));
num_symbols = 5;
model = openwifi_dot11_pilot_map_model(init_pilot_scram_state, num_symbols);

psdu_len_bytes = uint64(8);
payload_word = uint64(hex2dec('89ABCDEF'));
bram_words = zeros(16, 1, 'uint64');
bram_words(1) = bitor(uint64(bin2dec('1011')), bitshift(psdu_len_bytes, 5));
bram_words(2) = uint64(0);
bram_words(3) = payload_word;

write_hex64(fullfile(out_dir, 'dot11_pilot_map_bram.hex'), bram_words);
write_hex(fullfile(out_dir, 'dot11_pilot_map_expected_p0.hex'), model.pilot(:, 1), 8);
write_hex(fullfile(out_dir, 'dot11_pilot_map_expected_p1.hex'), model.pilot(:, 2), 8);
write_hex(fullfile(out_dir, 'dot11_pilot_map_expected_p2.hex'), model.pilot(:, 3), 8);
write_hex(fullfile(out_dir, 'dot11_pilot_map_expected_p3.hex'), model.pilot(:, 4), 8);
write_hex(fullfile(out_dir, 'dot11_pilot_map_expected_state_after.hex'), model.state_after, 2);
write_hex(fullfile(out_dir, 'dot11_pilot_map_expected_gain.hex'), model.pilot_gain, 1);

count_path = fullfile(out_dir, 'dot11_pilot_map_expected_count.txt');
fid = fopen(count_path, 'w');
if fid < 0
    error('Could not create %s', count_path);
end
fprintf(fid, '%d\n', num_symbols);
fclose(fid);

summary_path = fullfile(out_dir, 'dot11_pilot_map_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi dot11_tx pilot/DC/sideband reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\dot11_tx.v\n');
fprintf(fid, 'Packet: legacy 6 Mbps, LENGTH=8 bytes\n');
fprintf(fid, 'Symbols checked: %d\n', num_symbols);
fprintf(fid, 'Legacy zero bins: iq_cnt=0 and iq_cnt=27..37\n');
fprintf(fid, 'Pilot bins: iq_cnt 7->pilot[2], 21->pilot[3], 43->pilot[0], 57->pilot[1]\n');

fprintf('Wrote dot11_tx pilot-map vectors to: %s\n', out_dir);
end

function write_hex(path_name, words, digits)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
fmt = ['%0', num2str(digits), 'X\n'];
for k = 1:numel(words)
    fprintf(fid, fmt, uint32(words(k)));
end
end

function write_hex64(path_name, words)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(words)
    fprintf(fid, '%016s\n', dec2hex(words(k), 16));
end
end
