function verify_openofdm_rx_rate_to_idx_model()
%VERIFY_OPENOFDM_RX_RATE_TO_IDX_MODEL Generate vectors for rate_to_idx.v.

out_dir = fileparts(mfilename('fullpath'));

rates = uint8([11 15 10 14 9 13 8 12 128 129 130 131 132 133 134 135 255]);
n = numel(rates);
expected = zeros(n, 1, 'uint8');
for k = 1:n
    expected(k) = uint8(rate_to_idx_model(rates(k)));
end

write_hex8(fullfile(out_dir, 'openofdm_rate_to_idx_input.hex'), rates(:));
write_hex8(fullfile(out_dir, 'openofdm_rate_to_idx_expected.hex'), expected);

fid = fopen(fullfile(out_dir, 'openofdm_rate_to_idx_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_rate_to_idx_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX rate_to_idx reverse model\n');
fprintf(fid, 'legacy maps rate[2:0] to 0..7; HT/default maps MCS rate[2:0].\n');
fprintf(fid, 'num_cases=%d\n', n);
fclose(fid);

fprintf('Wrote OpenOFDM RX rate_to_idx vectors to: %s\n', out_dir);
end

function idx = rate_to_idx_model(rate)
key = double(bitget(rate, 8))*8 + double(bitand(rate, uint8(7)));
switch key
    case bin2dec('0011')
        idx = 0;
    case bin2dec('0111')
        idx = 1;
    case bin2dec('0010')
        idx = 2;
    case bin2dec('0110')
        idx = 3;
    case bin2dec('0001')
        idx = 4;
    case bin2dec('0101')
        idx = 5;
    case bin2dec('0000')
        idx = 6;
    case bin2dec('0100')
        idx = 7;
    otherwise
        idx = bitand(rate, uint8(7));
end
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
