function verify_openwifi_punc_interlv_model()
%VERIFY_OPENWIFI_PUNC_INTERLV_MODEL Generate exhaustive vectors.

out_dir = fileparts(mfilename('fullpath'));
rates = [ ...
    bin2dec('01011'), bin2dec('01111'), bin2dec('01010'), bin2dec('01110'), ...
    bin2dec('01001'), bin2dec('01101'), bin2dec('01000'), bin2dec('01100'), ...
    bin2dec('10000'), bin2dec('10001'), bin2dec('10010'), bin2dec('10011'), ...
    bin2dec('10100'), bin2dec('10101'), bin2dec('10110'), bin2dec('10111'), ...
    0, 31];

num_cases = numel(rates) * 512;
input_words = zeros(num_cases, 1);
expected_words = zeros(num_cases, 1);

idx = 1;
for r = 1:numel(rates)
    for k = 0:511
        [idx_o, punc_o] = openwifi_punc_interlv_model(rates(r), k);
        input_words(idx) = rates(r) * 512 + k;
        expected_words(idx) = punc_o(1) * 2^19 + punc_o(2) * 2^18 + ...
            idx_o(1) * 2^9 + idx_o(2);
        idx = idx + 1;
    end
end

write_hex(fullfile(out_dir, 'punc_interlv_input.hex'), input_words, 4);
write_hex(fullfile(out_dir, 'punc_interlv_expected.hex'), expected_words, 5);

summary_path = fullfile(out_dir, 'punc_interlv_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi punc_interlv_lut reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\punc_interlv_lut.v\n');
fprintf(fid, 'Cases: %d = %d rates * 512 idx values\n', num_cases, numel(rates));
fprintf(fid, 'Includes all 16 supported legacy/HT rates plus invalid rates 0 and 31.\n');
fprintf(fid, 'Address model: addr = floor(j/N_BPSC)*8 + mod(j,N_BPSC), matching ram_simo bit addressing.\n');
fprintf(fid, 'Interleaver columns: 16 for legacy OFDM, 13 for HT 20MHz OFDM.\n');
fprintf(fid, 'Puncture patterns: 1/2=[11], 2/3=[1110], 3/4=[111001], 5/6=[1110011001].\n');

fprintf('Wrote punc/interleaver vectors to: %s\n', out_dir);
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
