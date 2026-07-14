function verify_openwifi_n_sym_len14_model()
%VERIFY_OPENWIFI_N_SYM_LEN14_MODEL Generate vectors for n_sym_len14_pkt.v.

out_dir = fileparts(mfilename('fullpath'));

ht_flag = repelem(uint8([0; 1]), 16);
rate_mcs = repmat(uint8((0:15).'), 2, 1);
n_sym = openwifi_n_sym_len14_model(ht_flag, rate_mcs);
input_words = uint32(ht_flag) * 16 + uint32(rate_mcs);

write_hex(fullfile(out_dir, 'n_sym_len14_input.hex'), input_words, 2);
write_hex(fullfile(out_dir, 'n_sym_len14_expected.hex'), n_sym, 1);

summary_path = fullfile(out_dir, 'n_sym_len14_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi n_sym_len14_pkt reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\xpu\\src\\n_sym_len14_pkt.v\n');
fprintf(fid, 'Exhaustive inputs: 32 combinations of {ht_flag, rate_mcs}\n');
fprintf(fid, 'Default output for unsupported rate/MCS combinations: 6\n');

fprintf('Wrote n_sym_len14_pkt vectors to: %s\n', out_dir);
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
