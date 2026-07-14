function verify_openofdm_rx_ht_sig_crc_model()
%VERIFY_OPENOFDM_RX_HT_SIG_CRC_MODEL Generate vectors for ht_sig_crc.v.

out_dir = fileparts(mfilename('fullpath'));

bits = uint8([1 0 1 1 0 1 0 0 1 1 1 0 0 1 0 1 0 1 1 0 1 0 0 0 1 1 0 1 0 1 1 1]);
n = numel(bits);
C = uint8(hex2dec('ff'));
expected = zeros(n, 1, 'uint8');
state_trace = zeros(n, 1, 'uint8');
for k = 1:n
    b = uint8(bits(k) ~= 0);
    old = C;
    newC = uint8(0);
    newC = bitset(newC, 1, bitxor(b, bitget(old, 8)));
    newC = bitset(newC, 2, bitxor(bitxor(b, bitget(old, 8)), bitget(old, 1)));
    newC = bitset(newC, 3, bitxor(bitxor(b, bitget(old, 8)), bitget(old, 2)));
    for bitpos = 4:8
        newC = bitset(newC, bitpos, bitget(old, bitpos-1));
    end
    C = newC;
    state_trace(k) = C;
    expected(k) = crc_output(C);
end

write_hex8(fullfile(out_dir, 'openofdm_ht_sig_crc_input.hex'), bits(:));
write_hex8(fullfile(out_dir, 'openofdm_ht_sig_crc_expected.hex'), expected);

fid = fopen(fullfile(out_dir, 'openofdm_ht_sig_crc_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_ht_sig_crc_model_trace.csv'), 'w');
fprintf(fid, 'idx,bit,C,crc\n');
for k = 1:n
    fprintf(fid, '%d,%d,%02x,%02x\n', k-1, bits(k), state_trace(k), expected(k));
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_ht_sig_crc_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX ht_sig_crc reverse model\n');
fprintf(fid, 'C reset=0xff; crc[i]=~C[7-i].\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX ht_sig_crc vectors to: %s\n', out_dir);
end

function y = crc_output(C)
y = uint8(0);
for i = 0:7
    y = bitset(y, i+1, ~bitget(C, 8-i));
end
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
