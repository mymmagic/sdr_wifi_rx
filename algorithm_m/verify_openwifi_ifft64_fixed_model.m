function verify_openwifi_ifft64_fixed_model()
%VERIFY_OPENWIFI_IFFT64_FIXED_MODEL Generate vectors for RTL comparison.
%
% This script does not modify the openwifi source tree.  It writes all
% generated inputs, expected outputs, and copied coefficient memories into
% the same outputs directory as this script.

out_dir = fileparts(mfilename('fullpath'));
src_dir = 'C:\wifi\openwifi-hw-master\openwifi-hw-master\ip\openofdm_tx\src';

rng(64, 'twister');
num_frames = 4;
frames = zeros(64, 2, num_frames);

frames(1, 1, 1) = 1024;                 % DC real impulse
frames(2, 1, 2) = 1024;                 % One-bin tone
frames(:, :, 3) = randi([-2000, 2000], 64, 2);
frames(:, :, 4) = randi([-12000, 12000], 64, 2);

y_all = zeros(64 * num_frames, 2);
for f = 1:num_frames
    [yf, dbg] = openwifi_ifft64_fixed_model(frames(:, :, f), src_dir);
    y_all((f - 1) * 64 + (1:64), :) = double(yf);
end

rtl_input = reshape(permute(frames, [1 3 2]), [], 2);
rtl_input = [rtl_input; zeros(64, 2)];

write_hex_words(fullfile(out_dir, 'ifft64_rtl_in.hex'), rtl_input);
write_hex_words(fullfile(out_dir, 'ifft64_model_expected.hex'), y_all);
write_txt_pairs(fullfile(out_dir, 'ifft64_model_expected.txt'), y_all);
write_txt_pairs(fullfile(out_dir, 'ifft64_model_input.txt'), rtl_input);

copyfile(fullfile(src_dir, 'icmem_64.mem'), fullfile(out_dir, 'icmem_64.mem'));
copyfile(fullfile(src_dir, 'icmem_32.mem'), fullfile(out_dir, 'icmem_32.mem'));
copyfile(fullfile(src_dir, 'icmem_16.mem'), fullfile(out_dir, 'icmem_16.mem'));
copyfile(fullfile(src_dir, 'icmem_8.mem'),  fullfile(out_dir, 'icmem_8.mem'));

summary_path = fullfile(out_dir, 'ifft64_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi ifftmain fixed-point reverse model\n');
fprintf(fid, 'Source RTL: %s\n', fullfile(src_dir, 'ifftmain.v'));
fprintf(fid, 'Input samples: 64 complex signed 16-bit values\n');
fprintf(fid, 'Output samples: 64 complex signed 16-bit values\n');
fprintf(fid, 'Verification frames: %d plus one zero flush frame\n', num_frames);
fprintf(fid, 'Stage scale windows:\n');
fprintf(fid, '  stage_64/32/16/8: hwbfly IWIDTH=16 CWIDTH=20 OWIDTH=16 BFLYSHIFT=0\n');
fprintf(fid, '  qtrstage: IWIDTH=16 OWIDTH=16 INVERSE=1 SHIFT=0\n');
fprintf(fid, '  laststage: IWIDTH=16 OWIDTH=16 SHIFT=1\n');
fprintf(fid, '  bitreverse: LGSIZE=6 WIDTH=16\n');
fprintf(fid, 'Output min/max real: %d / %d\n', min(y_all(:, 1)), max(y_all(:, 1)));
fprintf(fid, 'Output min/max imag: %d / %d\n', min(y_all(:, 2)), max(y_all(:, 2)));
fprintf(fid, 'Frame 1 DC check, first output real/imag: %d / %d\n', y_all(1, 1), y_all(1, 2));
fprintf(fid, 'Frame 2 one-bin tone, first output real/imag: %d / %d\n', y_all(65, 1), y_all(65, 2));
fprintf(fid, 'First eight bitreverse input indexes, zero based:\n');
fprintf(fid, '  ');
fprintf(fid, '%d ', dbg.bitreverse_index0(1:8));
fprintf(fid, '\n');

fprintf('Wrote vectors and summary to: %s\n', out_dir);
fprintf('Expected output hex: %s\n', fullfile(out_dir, 'ifft64_model_expected.hex'));
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
