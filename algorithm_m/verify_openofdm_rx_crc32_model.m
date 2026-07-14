function verify_openofdm_rx_crc32_model()
%VERIFY_OPENOFDM_RX_CRC32_MODEL Generate vectors for openofdm crc32.v.

out_dir = fileparts(mfilename('fullpath'));

bytes = uint8([hex2dec('88') hex2dec('42') hex2dec('2c') hex2dec('00') ...
               hex2dec('e4') hex2dec('90') hex2dec('7e') hex2dec('15') ...
               hex2dec('2a') hex2dec('16') hex2dec('e8') hex2dec('de')]);
n = numel(bytes);

crc = uint32(hex2dec('ffffffff'));
expected = zeros(n, 1, 'uint32');
for k = 1:n
    crc = crc32_update_openofdm(crc, bytes(k));
    expected(k) = crc;
end

write_hex8(fullfile(out_dir, 'openofdm_crc32_input.hex'), bytes(:));
write_hex32(fullfile(out_dir, 'openofdm_crc32_expected.hex'), expected);

fid = fopen(fullfile(out_dir, 'openofdm_crc32_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_crc32_model_trace.csv'), 'w');
fprintf(fid, 'idx,data_byte,crc_after\n');
for k = 1:n
    fprintf(fid, '%d,%02x,%08x\n', k-1, bytes(k), expected(k));
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_crc32_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX crc32 reverse model\n');
fprintf(fid, 'initial_state=0xffffffff; one parallel 8-bit LFSR update per crc_en.\n');
fprintf(fid, 'polynomial terms match 1+x^1+x^2+x^4+x^5+x^7+x^8+x^10+x^11+x^12+x^16+x^22+x^23+x^26+x^32.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX crc32 vectors to: %s\n', out_dir);
end

function next = crc32_update_openofdm(q, d)
c = false(32, 1);
c(1)  = xo(qb(q,24), qb(q,30), db(d,0), db(d,6));
c(2)  = xo(qb(q,24), qb(q,25), qb(q,30), qb(q,31), db(d,0), db(d,1), db(d,6), db(d,7));
c(3)  = xo(qb(q,24), qb(q,25), qb(q,26), qb(q,30), qb(q,31), db(d,0), db(d,1), db(d,2), db(d,6), db(d,7));
c(4)  = xo(qb(q,25), qb(q,26), qb(q,27), qb(q,31), db(d,1), db(d,2), db(d,3), db(d,7));
c(5)  = xo(qb(q,24), qb(q,26), qb(q,27), qb(q,28), qb(q,30), db(d,0), db(d,2), db(d,3), db(d,4), db(d,6));
c(6)  = xo(qb(q,24), qb(q,25), qb(q,27), qb(q,28), qb(q,29), qb(q,30), qb(q,31), db(d,0), db(d,1), db(d,3), db(d,4), db(d,5), db(d,6), db(d,7));
c(7)  = xo(qb(q,25), qb(q,26), qb(q,28), qb(q,29), qb(q,30), qb(q,31), db(d,1), db(d,2), db(d,4), db(d,5), db(d,6), db(d,7));
c(8)  = xo(qb(q,24), qb(q,26), qb(q,27), qb(q,29), qb(q,31), db(d,0), db(d,2), db(d,3), db(d,5), db(d,7));
c(9)  = xo(qb(q,0), qb(q,24), qb(q,25), qb(q,27), qb(q,28), db(d,0), db(d,1), db(d,3), db(d,4));
c(10) = xo(qb(q,1), qb(q,25), qb(q,26), qb(q,28), qb(q,29), db(d,1), db(d,2), db(d,4), db(d,5));
c(11) = xo(qb(q,2), qb(q,24), qb(q,26), qb(q,27), qb(q,29), db(d,0), db(d,2), db(d,3), db(d,5));
c(12) = xo(qb(q,3), qb(q,24), qb(q,25), qb(q,27), qb(q,28), db(d,0), db(d,1), db(d,3), db(d,4));
c(13) = xo(qb(q,4), qb(q,24), qb(q,25), qb(q,26), qb(q,28), qb(q,29), qb(q,30), db(d,0), db(d,1), db(d,2), db(d,4), db(d,5), db(d,6));
c(14) = xo(qb(q,5), qb(q,25), qb(q,26), qb(q,27), qb(q,29), qb(q,30), qb(q,31), db(d,1), db(d,2), db(d,3), db(d,5), db(d,6), db(d,7));
c(15) = xo(qb(q,6), qb(q,26), qb(q,27), qb(q,28), qb(q,30), qb(q,31), db(d,2), db(d,3), db(d,4), db(d,6), db(d,7));
c(16) = xo(qb(q,7), qb(q,27), qb(q,28), qb(q,29), qb(q,31), db(d,3), db(d,4), db(d,5), db(d,7));
c(17) = xo(qb(q,8), qb(q,24), qb(q,28), qb(q,29), db(d,0), db(d,4), db(d,5));
c(18) = xo(qb(q,9), qb(q,25), qb(q,29), qb(q,30), db(d,1), db(d,5), db(d,6));
c(19) = xo(qb(q,10), qb(q,26), qb(q,30), qb(q,31), db(d,2), db(d,6), db(d,7));
c(20) = xo(qb(q,11), qb(q,27), qb(q,31), db(d,3), db(d,7));
c(21) = xo(qb(q,12), qb(q,28), db(d,4));
c(22) = xo(qb(q,13), qb(q,29), db(d,5));
c(23) = xo(qb(q,14), qb(q,24), db(d,0));
c(24) = xo(qb(q,15), qb(q,24), qb(q,25), qb(q,30), db(d,0), db(d,1), db(d,6));
c(25) = xo(qb(q,16), qb(q,25), qb(q,26), qb(q,31), db(d,1), db(d,2), db(d,7));
c(26) = xo(qb(q,17), qb(q,26), qb(q,27), db(d,2), db(d,3));
c(27) = xo(qb(q,18), qb(q,24), qb(q,27), qb(q,28), qb(q,30), db(d,0), db(d,3), db(d,4), db(d,6));
c(28) = xo(qb(q,19), qb(q,25), qb(q,28), qb(q,29), qb(q,31), db(d,1), db(d,4), db(d,5), db(d,7));
c(29) = xo(qb(q,20), qb(q,26), qb(q,29), qb(q,30), db(d,2), db(d,5), db(d,6));
c(30) = xo(qb(q,21), qb(q,27), qb(q,30), qb(q,31), db(d,3), db(d,6), db(d,7));
c(31) = xo(qb(q,22), qb(q,28), qb(q,31), db(d,4), db(d,7));
c(32) = xo(qb(q,23), qb(q,29), db(d,5));

next = uint32(0);
for k = 1:32
    if c(k)
        next = bitset(next, k, 1);
    end
end
end

function b = qb(q, idx)
b = logical(bitget(q, idx + 1));
end

function b = db(d, idx)
b = logical(bitget(d, idx + 1));
end

function y = xo(varargin)
y = false;
for k = 1:nargin
    y = xor(y, varargin{k});
end
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end

function write_hex32(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%08x\n', values(k));
end
fclose(fid);
end
