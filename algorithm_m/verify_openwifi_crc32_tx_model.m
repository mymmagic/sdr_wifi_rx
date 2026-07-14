function verify_openwifi_crc32_tx_model()
%VERIFY_OPENWIFI_CRC32_TX_MODEL Generate vectors for crc32_tx.v comparison.

out_dir = fileparts(mfilename('fullpath'));

rng(32, 'twister');
n = 180;
data_in = uint32(randi([0, 15], n, 1));
crc_en = ones(n, 1);
rst = zeros(n, 1);
rst([1, 2, 90]) = 1;
crc_en([17, 18, 19, 83, 121]) = 0;
data_in(1:16) = uint32(0:15).';

[crc_out, idx_used] = openwifi_crc32_tx_model(data_in, crc_en, rst);

input_words = uint32(rst) * 32 + uint32(crc_en) * 16 + data_in;
write_hex(fullfile(out_dir, 'crc32_tx_input.hex'), input_words, 2);
write_hex(fullfile(out_dir, 'crc32_tx_expected.hex'), crc_out, 8);
write_hex(fullfile(out_dir, 'crc32_tx_idx_expected.hex'), idx_used, 1);

summary_path = fullfile(out_dir, 'crc32_tx_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi crc32_tx reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\crc32_tx.v\n');
fprintf(fid, 'Cycles: %d\n', n);
fprintf(fid, 'Update: idx = crc_out[3:0] ^ data_in; crc_out = (crc_out >> 4) ^ table[idx]\n');
fprintf(fid, 'Reset value: 0x00000000\n');
fprintf(fid, 'Verification includes crc_en stalls and mid-stream reset.\n');

fprintf('Wrote crc32_tx vectors to: %s\n', out_dir);
end

function write_hex(path_name, words, digits)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
fmt = ['%0', num2str(digits), 'X\n'];
for k = 1:numel(words)
    fprintf(fid, fmt, words(k));
end
end
