function verify_openofdm_rx_calc_mean_model()
%VERIFY_OPENOFDM_RX_CALC_MEAN_MODEL Generate vectors for calc_mean.v.

out_dir = fileparts(mfilename('fullpath'));

a = int16([100 -101 3000 -3001 7 -8 32766 -32768]);
b = int16([50 51 -1000 1001 -7 9 -32768 32767]);
sign = uint8([0 0 1 1 0 1 0 1]);
n = numel(a);

expected = zeros(n, 1, 'int16');
for k = 1:n
    cc = floor(double(a(k))/2) + floor(double(b(k))/2);
    if sign(k)
        cc = -cc;
    end
    expected(k) = int16(cc);
end

write_hex16(fullfile(out_dir, 'openofdm_calc_mean_a.hex'), typecast(a(:), 'uint16'));
write_hex16(fullfile(out_dir, 'openofdm_calc_mean_b.hex'), typecast(b(:), 'uint16'));
write_hex8(fullfile(out_dir, 'openofdm_calc_mean_sign.hex'), sign(:));
write_hex16(fullfile(out_dir, 'openofdm_calc_mean_expected.hex'), typecast(expected(:), 'uint16'));

fid = fopen(fullfile(out_dir, 'openofdm_calc_mean_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_calc_mean_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX calc_mean reverse model\n');
fprintf(fid, 'c = sign ? -((a>>>1)+(b>>>1)) : ((a>>>1)+(b>>>1)); output after two-cycle pipeline.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX calc_mean vectors to: %s\n', out_dir);
end

function write_hex16(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%04x\n', values(k));
end
fclose(fid);
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
