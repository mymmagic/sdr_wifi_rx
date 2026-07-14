function verify_openwifi_convenc_model()
%VERIFY_OPENWIFI_CONVENC_MODEL Generate vectors for convenc.v comparison.

out_dir = fileparts(mfilename('fullpath'));

rng(133171, 'twister');
n = 160;
bit_in = randi([0, 1], n, 1);
enc_en = ones(n, 1);
rst = zeros(n, 1);

% Add stalls and mid-stream resets to cover state hold and reset behavior.
enc_en([17, 18, 53, 54, 55, 101]) = 0;
rst([1, 2, 80]) = 1;
bit_in(1:12) = [1 0 1 1 0 0 1 0 1 0 0 1].';

[bits_out, state_before, state_after] = openwifi_convenc_model(bit_in, enc_en, rst);

write_input(fullfile(out_dir, 'convenc_input.txt'), rst, enc_en, bit_in);
write_expected(fullfile(out_dir, 'convenc_expected.txt'), bits_out, state_before, state_after);

summary_path = fullfile(out_dir, 'convenc_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi openofdm_tx convolutional encoder reverse model\n');
fprintf(fid, 'Source RTL: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\convenc.v\n');
fprintf(fid, 'Cycles: %d\n', n);
fprintf(fid, 'Generator comment: g0=133, g1=171, rate=1/2\n');
fprintf(fid, 'RTL bits_out[0] = bit_in ^ state[0] ^ state[1] ^ state[2] ^ state[5]\n');
fprintf(fid, 'RTL bits_out[1] = bit_in ^ state[1] ^ state[2] ^ state[4] ^ state[5]\n');
fprintf(fid, 'Verification includes enc_en stalls and mid-stream reset.\n');

fprintf('Wrote convenc vectors to: %s\n', out_dir);
end

function write_input(path_name, rst, enc_en, bit_in)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(bit_in)
    fprintf(fid, '%d %d %d\n', rst(k), enc_en(k), bit_in(k));
end
end

function write_expected(path_name, bits_out, state_before, state_after)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:size(bits_out, 1)
    sb = binvec_to_int(state_before(k, :));
    sa = binvec_to_int(state_after(k, :));
    bo = bits_out(k, 1) + 2 * bits_out(k, 2);
    fprintf(fid, '%d %d %d %d %d\n', bits_out(k, 1), bits_out(k, 2), bo, sb, sa);
end
end

function v = binvec_to_int(x)
v = 0;
for k = 1:numel(x)
    v = v + double(x(k)) * 2^(k - 1);
end
end
