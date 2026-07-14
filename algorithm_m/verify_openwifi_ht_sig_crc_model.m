function verify_openwifi_ht_sig_crc_model()
%VERIFY_OPENWIFI_HT_SIG_CRC_MODEL Generate vectors for ht_sig_crc_calc.v.

out_dir = fileparts(mfilename('fullpath'));

rng(80211, 'twister');
n = 64;
lo = uint64(randi([0, 2^32 - 1], n, 1));
hi = uint64(randi([0, 3], n, 1));
data_words = bitor(lo, bitshift(hi, 32));
data_words(1:6) = uint64([0; 1; 2; 3; hex2dec('3FFFFFFFF'); hex2dec('155555555')]);

[crc, trace_c, trace_i, trace_bit] = openwifi_ht_sig_crc_model(data_words);

write_hex64(fullfile(out_dir, 'ht_sig_crc_input.hex'), data_words, 9);
write_hex(fullfile(out_dir, 'ht_sig_crc_expected.hex'), crc, 2);
write_hex(fullfile(out_dir, 'ht_sig_crc_trace_c.hex'), trace_c, 2);
write_hex(fullfile(out_dir, 'ht_sig_crc_trace_i.hex'), trace_i, 2);
write_hex(fullfile(out_dir, 'ht_sig_crc_trace_bit.hex'), trace_bit, 1);

summary_path = fullfile(out_dir, 'ht_sig_crc_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi ht_sig_crc_calc reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\tx_intf\\src\\ht_sig_crc_calc.v\n');
fprintf(fid, 'Words tested: %d\n', n);
fprintf(fid, 'Input width: 34 bits, consumed LSB first d[0]..d[33]\n');
fprintf(fid, 'Initial c: 0xFF\n');
fprintf(fid, 'Output: bitwise complement of {c[0],c[1],...,c[7]} after 34 input bits\n');
fprintf(fid, 'Per-cycle c/i/data_bit traces: %d rows\n', numel(trace_c));

fprintf('Wrote ht_sig_crc_calc vectors to: %s\n', out_dir);
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

function write_hex64(path_name, words, digits)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(words)
    fprintf(fid, ['%0', num2str(digits), 's\n'], dec2hex(words(k), digits));
end
end
