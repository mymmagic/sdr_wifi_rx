function verify_openofdm_rx_stage_mult_model()
% Reverse model and vector generator for openofdm RX stage_mult.v.

outdir = fileparts(mfilename('fullpath'));

cases = int16([
    100,   20,   156,    0,   -50,   10,    -5,  120
   -300,  25,    40,  111,   120,  -70,    97,  -83
    512, -256,   21,  -28,  -333,  444,    60,   88
   -777, 888,  -115,  55,   999, -222,   -38,  106
   2047,   0,   98,   26, -2048,  31,     53,   -4
     13, -99,     1, 115,    64, 128,   -137,   47
]);

% Expand each row into X0..X7,Y0..Y7 by reusing paired patterns while keeping
% values small enough to avoid 32-bit overflow in the four-term sum.
n = size(cases, 1);
x = zeros(n, 8, 'int16');
y = zeros(n, 8, 'int16');
for k = 1:n
    x(k, :) = int16([cases(k,1), cases(k,2), cases(k,5), cases(k,6), ...
                     -cases(k,1), cases(k,2), cases(k,5), -cases(k,6)]);
    y(k, :) = int16([cases(k,3), cases(k,4), cases(k,7), cases(k,8), ...
                     cases(k,3), -cases(k,4), -cases(k,7), cases(k,8)]);
end

expected_i = zeros(n, 1, 'int32');
expected_q = zeros(n, 1, 'int32');
for k = 1:n
    si = int64(0);
    sq = int64(0);
    for p = 1:4
        xr = int64(x(k, 2*p - 1));
        xi = int64(x(k, 2*p));
        yr = int64(y(k, 2*p - 1));
        yi = int64(y(k, 2*p));
        si = si + xr * yr - xi * yi;
        sq = sq + xr * yi + xi * yr;
    end
    expected_i(k) = wrap_i32(si);
    expected_q(k) = wrap_i32(sq);
end

write_count(fullfile(outdir, 'openofdm_stage_mult_count.txt'), n);
for col = 1:8
    write_hex(fullfile(outdir, sprintf('openofdm_stage_mult_x%d.hex', col - 1)), ...
        typecast(x(:, col), 'uint16'), 4);
    write_hex(fullfile(outdir, sprintf('openofdm_stage_mult_y%d.hex', col - 1)), ...
        typecast(y(:, col), 'uint16'), 4);
end
write_hex(fullfile(outdir, 'openofdm_stage_mult_expected_i.hex'), typecast(expected_i, 'uint32'), 8);
write_hex(fullfile(outdir, 'openofdm_stage_mult_expected_q.hex'), typecast(expected_q, 'uint32'), 8);

fprintf('Wrote OpenOFDM RX stage_mult vectors to: %s\n', outdir);
for k = 1:n
    fprintf('STAGE_MULT_VEC[%02d] expected=(%d,%d)\n', k - 1, expected_i(k), expected_q(k));
end
end

function y = wrap_i32(x)
u = uint32(mod(double(x), 2^32));
y = typecast(u, 'int32');
end

function write_count(path, n)
fid = fopen(path, 'w');
assert(fid >= 0, 'could not open count output');
fprintf(fid, '%d\n', n);
fclose(fid);
end

function write_hex(path, values, width)
fid = fopen(path, 'w');
assert(fid >= 0, 'could not open hex output: %s', path);
for k = 1:numel(values)
    fprintf(fid, ['%0' num2str(width) 'x\n'], values(k));
end
fclose(fid);
end
