function verify_openwifi_dot11_scrambler_model()
%VERIFY_OPENWIFI_DOT11_SCRAMBLER_MODEL Generate vectors for dot11_tx scrambler.

out_dir = fileparts(mfilename('fullpath'));

init_data_scram_state = uint8(bin2dec('1011101'));
psdu_len_bytes = uint32(8);
psdu_bit_len = psdu_len_bytes * 8;
n_dbps = uint32(24);  % Legacy 6 Mbps
payload_word = uint64(hex2dec('89ABCDEF'));

rows = openwifi_dot11_scrambler_model(init_data_scram_state, payload_word, psdu_bit_len, n_dbps);
n = numel(rows);

bram_words = zeros(16, 1, 'uint64');
bram_words(1) = bitor(uint64(bin2dec('1011')), bitshift(uint64(psdu_len_bytes), 5));
bram_words(2) = uint64(0);
bram_words(3) = payload_word;

write_hex64(fullfile(out_dir, 'dot11_scrambler_bram.hex'), bram_words);
write_hex(fullfile(out_dir, 'dot11_scrambler_expected_bit.hex'), [rows.bit_scram].', 1);
write_hex(fullfile(out_dir, 'dot11_scrambler_expected_state.hex'), [rows.scram_state].', 2);
write_hex(fullfile(out_dir, 'dot11_scrambler_expected_state11.hex'), [rows.state11].', 1);
write_hex(fullfile(out_dir, 'dot11_scrambler_expected_dbps.hex'), [rows.dbps_cnt].', 3);
write_hex(fullfile(out_dir, 'dot11_scrambler_expected_psdu.hex'), [rows.psdu_bit_cnt].', 5);
write_hex(fullfile(out_dir, 'dot11_scrambler_expected_service.hex'), [rows.service_bit_cnt].', 2);

count_path = fullfile(out_dir, 'dot11_scrambler_expected_count.txt');
fid = fopen(count_path, 'w');
if fid < 0
    error('Could not create %s', count_path);
end
fprintf(fid, '%d\n', n);
fclose(fid);

summary_path = fullfile(out_dir, 'dot11_scrambler_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi dot11_tx DATA scrambler reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\dot11_tx.v\n');
fprintf(fid, 'Packet: legacy 6 Mbps, LENGTH=%d bytes, PSDU data bits before RTL FCS=%d\n', psdu_len_bytes, psdu_bit_len - 32);
fprintf(fid, 'Initial data scrambler state: 0b%s\n', dec2bin(init_data_scram_state, 7));
fprintf(fid, 'Payload word lower bits: 0x%08X\n', uint32(payload_word));
fprintf(fid, 'FCS from crc32_tx model: 0x%08X\n', rows(1).pkt_fcs);
fprintf(fid, 'DATA-domain bits checked: %d\n', n);
fprintf(fid, 'Update while SERVICE/PSDU/FCS/PAD: state = {state[5:0], state[3]^state[6]}\n');
fprintf(fid, 'Tail behavior: bit_scram=0 and data_scram_state is held, matching dot11_tx.v\n');

fprintf('Wrote dot11_tx scrambler vectors to: %s\n', out_dir);
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
