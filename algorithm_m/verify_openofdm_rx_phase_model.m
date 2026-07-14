function verify_openofdm_rx_phase_model()
% Reverse model and vector generator for openofdm RX phase.v.

outdir = fileparts(mfilename('fullpath'));
srcdir = fullfile(outdir, 'openofdm_rx_src', 'verilog');
lut = read_binary_lut(fullfile(srcdir, 'atan_lut.mif'));

pi_s = int32(1608);
pi_2 = bitshift(pi_s, -1);

in_i = int32([100000; 120000; 1; -80000; -100000; -120000; -1; 80000; ...
              123456; -234567; 500000; -700000; 262144; -262144]);
in_q = int32([1; 80000; 100000; 120000; 1; -80000; -100000; -120000; ...
              78901; 45678; -150000; -200000; 131071; -131071]);

expected = zeros(size(in_i), 'int32');
quadrants = zeros(size(in_i), 'uint8');
addr = zeros(size(in_i), 'uint16');
quot = zeros(size(in_i), 'uint32');

for k = 1:numel(in_i)
    ai = abs32(in_i(k));
    aq = abs32(in_q(k));

    sign_i = in_i(k) < 0;
    sign_q = in_q(k) < 0;

    if ai >= aq
        max_v = ai;
        min_v = aq;
        quadrant = uint8(sign_i) * 4 + uint8(sign_q) * 2;
    else
        max_v = aq;
        min_v = ai;
        quadrant = uint8(sign_i) * 4 + uint8(sign_q) * 2 + 1;
    end

    divisor = floor(double(max_v) / 256);
    if divisor == 0
        q = uint32(0);
    else
        q = uint32(floor(double(min_v) / divisor));
    end

    a = uint16(bitand(q, uint32(255)));
    ph = int32(lut(double(a) + 1));
    switch quadrant
        case 0
            y = ph;
        case 1
            y = pi_2 - ph;
        case 2
            y = -ph;
        case 3
            y = ph - pi_2;
        case 4
            y = pi_s - ph;
        case 5
            y = pi_2 + ph;
        case 6
            y = ph - pi_s;
        case 7
            y = -pi_2 - ph;
        otherwise
            error('bad quadrant');
    end

    expected(k) = int32(y);
    quadrants(k) = quadrant;
    addr(k) = a;
    quot(k) = q;
end

write_count(fullfile(outdir, 'openofdm_phase_count.txt'), numel(in_i));
write_hex(fullfile(outdir, 'openofdm_phase_i.hex'), typecast(in_i(:), 'uint32'), 8);
write_hex(fullfile(outdir, 'openofdm_phase_q.hex'), typecast(in_q(:), 'uint32'), 8);
write_hex(fullfile(outdir, 'openofdm_phase_expected.hex'), typecast(expected(:), 'uint32'), 8);
write_hex(fullfile(outdir, 'openofdm_phase_addr.hex'), uint32(addr(:)), 2);
write_hex(fullfile(outdir, 'openofdm_phase_quot.hex'), quot(:), 8);
write_hex(fullfile(outdir, 'openofdm_phase_quadrant.hex'), uint32(quadrants(:)), 1);

fprintf('Wrote OpenOFDM RX phase vectors to: %s\n', outdir);
for k = 1:numel(in_i)
    fprintf('PHASE_VEC[%02d] i=%d q=%d quadrant=%d quotient=%u addr=%u phase=%d\n', ...
        k - 1, in_i(k), in_q(k), quadrants(k), quot(k), addr(k), expected(k));
end

end

function y = abs32(x)
if x < 0
    y = int64(-x);
else
    y = int64(x);
end
end

function lut = read_binary_lut(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open lut: %s', path);
c = onCleanup(@() fclose(fid));
lines = {};
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    t = strtrim(t);
    if ~isempty(t)
        lines{end + 1, 1} = t; %#ok<AGROW>
    end
end
lut = zeros(numel(lines), 1, 'uint16');
for k = 1:numel(lines)
    lut(k) = uint16(bin2dec(lines{k}));
end
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
