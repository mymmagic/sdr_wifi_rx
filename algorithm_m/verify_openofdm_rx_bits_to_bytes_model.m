function verify_openofdm_rx_bits_to_bytes_model()
%VERIFY_OPENOFDM_RX_BITS_TO_BYTES_MODEL Generate vectors for bits_to_bytes.v.

out_dir = fileparts(mfilename('fullpath'));

bytes = uint8([hex2dec('a5') hex2dec('3c') hex2dec('00') hex2dec('ff') hex2dec('81')]);
in_bits = uint8([]);
for k = 1:numel(bytes)
    for b = 0:7
        in_bits(end+1) = uint8(bitget(bytes(k), b+1)); %#ok<AGROW>
    end
end

write_hex8(fullfile(out_dir, 'openofdm_bits_to_bytes_input.hex'), in_bits(:));
write_hex8(fullfile(out_dir, 'openofdm_bits_to_bytes_expected.hex'), bytes(:));

fid = fopen(fullfile(out_dir, 'openofdm_bits_to_bytes_input_count.txt'), 'w');
fprintf(fid, '%d\n', numel(in_bits));
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_bits_to_bytes_output_count.txt'), 'w');
fprintf(fid, '%d\n', numel(bytes));
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_bits_to_bytes_model_trace.csv'), 'w');
fprintf(fid, 'byte_idx,expected_byte,input_bits_lsb_first\n');
for k = 1:numel(bytes)
    fprintf(fid, '%d,%02x,', k-1, bytes(k));
    for b = 1:8
        fprintf(fid, '%d', in_bits((k-1)*8 + b));
    end
    fprintf(fid, '\n');
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_bits_to_bytes_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX bits_to_bytes reverse model\n');
fprintf(fid, 'input bits are LSB-first per byte; output_strobe asserted on every 8th input bit.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX bits_to_bytes vectors to: %s\n', out_dir);
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
