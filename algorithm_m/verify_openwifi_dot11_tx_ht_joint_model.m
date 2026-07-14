function verify_openwifi_dot11_tx_ht_joint_model(case_name, mcs, psdu_len_bytes)
%VERIFY_OPENWIFI_DOT11_TX_HT_JOINT_MODEL Generate vectors for HT dot11_tx joint sim.

if nargin < 1 || isempty(case_name)
    case_name = 'ht_mcs0_len8';
end
if nargin < 2 || isempty(mcs)
    mcs = 0;
end
if nargin < 3 || isempty(psdu_len_bytes)
    psdu_len_bytes = 8;
end

out_dir = fileparts(mfilename('fullpath'));
payload_word = case_payload_word(mcs, psdu_len_bytes);
joint = openwifi_dot11_tx_ht_joint_model(mcs, psdu_len_bytes, payload_word);
n = joint.num_symbols * 64;

write_hex64(fullfile(out_dir, 'dot11_tx_joint_bram.hex'), joint.bram_words);
write_hex(fullfile(out_dir, 'dot11_tx_joint_ifft_iq_expected.hex'), reshape(joint.ifft_iq.', n, 1), 8);
write_hex(fullfile(out_dir, 'dot11_tx_joint_mod_addr_expected.hex'), reshape(joint.mod_addr.', n, 1), 2);
write_hex(fullfile(out_dir, 'dot11_tx_joint_bits_to_mod_expected.hex'), reshape(joint.bits_to_mod.', n, 1), 2);
write_hex(fullfile(out_dir, 'dot11_tx_joint_kind_expected.hex'), reshape(joint.kind.', n, 1), 1);

ifft_out = zeros(joint.num_symbols, 64, 'uint32');
for sym = 1:joint.num_symbols
    frame_in = unpack_iq_words(joint.ifft_iq(sym, :).');
    frame_out = openwifi_ifft64_fixed_model(frame_in);
    ifft_out(sym, :) = pack_iq_matrix(frame_out);
end
write_hex(fullfile(out_dir, 'dot11_tx_joint_ifft_out_expected.hex'), reshape(ifft_out.', n, 1), 8);

count_path = fullfile(out_dir, 'dot11_tx_joint_expected_count.txt');
fid = fopen(count_path, 'w');
if fid < 0
    error('Could not create %s', count_path);
end
fprintf(fid, '%d\n', joint.num_symbols);
fclose(fid);

summary_path = fullfile(out_dir, 'dot11_tx_joint_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi dot11_tx HT module-chain joint reverse model\n');
fprintf(fid, 'Case: %s\n', case_name);
fprintf(fid, 'Source RTL top: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\dot11_tx.v\n');
fprintf(fid, 'Scenario: HT %s, MCS=%d, LENGTH=%d bytes, payload source word=0x%016s\n', ...
    joint.rate_name, joint.mcs, joint.psdu_len_bytes, dec2hex(joint.payload_word, 16));
fprintf(fid, 'N_BPSC=%d, N_DBPS=%d, DATA symbols=%d\n', joint.n_bpsc, joint.n_dbps, joint.num_data_symbols);
fprintf(fid, 'Checked symbols: %d (%d IFFT input/output samples)\n', joint.num_symbols, n);
fprintf(fid, 'Comparison nodes: dot11_tx.ifft_iq during S2_MOD_IFFT_INPUT, plus ifft_o_result after o_sync.\n');
fprintf(fid, 'Data bins also compare mod_addr and bits_to_mod.\n');

fprintf('Wrote HT dot11_tx joint vectors to: %s\n', out_dir);
end

function payload_word = case_payload_word(mcs, psdu_len_bytes)
base = bitor(uint64(hex2dec('89ABCDEF')), bitshift(uint64(hex2dec('76543210')), 32));
tag = bitor(uint64(mcs), bitshift(uint64(psdu_len_bytes), 8));
payload_word = bitxor(base, tag);
end

function iq = unpack_iq_words(words)
iq = zeros(numel(words), 2, 'int32');
for k = 1:numel(words)
    w = uint32(words(k));
    iq(k, 1) = int32(typecast(uint16(bitshift(w, -16)), 'int16'));
    iq(k, 2) = int32(typecast(uint16(bitand(w, uint32(65535))), 'int16'));
end
end

function words = pack_iq_matrix(iq)
words = zeros(size(iq, 1), 1, 'uint32');
for k = 1:size(iq, 1)
    i = uint32(typecast(int16(iq(k, 1)), 'uint16'));
    q = uint32(typecast(int16(iq(k, 2)), 'uint16'));
    words(k) = bitor(bitshift(i, 16), q);
end
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
