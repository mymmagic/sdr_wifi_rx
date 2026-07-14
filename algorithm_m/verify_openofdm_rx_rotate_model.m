function verify_openofdm_rx_rotate_model()
% Reverse model and vector generator for openofdm RX rotate.v.

outdir = fileparts(mfilename('fullpath'));
srcdir = fullfile(outdir, 'openofdm_rx_src', 'verilog');
rot_lut = read_binary_lut32(fullfile(srcdir, 'rot_lut.mif'));

pi_s = int32(1608);
pi_2 = bitshift(pi_s, -1);
pi_4 = bitshift(pi_s, -2);
pi_3_4 = pi_2 + pi_4;
shift = 11;

in_i = int16([1000; 1000; 0; -800; -900; -1000; 0; 700; 321; -456; 1200; -1200; 512; -512]);
in_q = int16([0; 500; 1000; 900; 0; -500; -1000; -900; -654; 789; -333; -333; 256; -256]);
phase = int32([0; 300; 804; 1104; 1608; -1308; -804; -504; ...
               236; -1372; 402; -402; 1206; -1206]);

expected_i = zeros(size(in_i), 'int16');
expected_q = zeros(size(in_q), 'int16');
addr = zeros(size(phase), 'uint16');
quadrants = zeros(size(phase), 'uint8');
rot_i_vec = zeros(size(phase), 'int16');
rot_q_vec = zeros(size(phase), 'int16');

for k = 1:numel(phase)
    ph = phase(k);
    sign_bit = ph < 0;
    phase_abs = abs32(ph);

    if phase_abs <= pi_4
        quadrant = uint8(sign_bit) * 4 + 0;
        actual_phase = phase_abs;
    elseif phase_abs <= pi_2
        quadrant = uint8(sign_bit) * 4 + 1;
        actual_phase = int32(pi_2 - phase_abs);
    elseif phase_abs <= pi_3_4
        quadrant = uint8(sign_bit) * 4 + 2;
        actual_phase = int32(phase_abs - pi_2);
    else
        quadrant = uint8(sign_bit) * 4 + 3;
        actual_phase = int32(pi_s - phase_abs);
    end

    a = uint16(bitand(uint32(actual_phase), uint32(511)));
    raw = rot_lut(double(a) + 1);
    raw_i = u16_to_i16(bitshift(raw, -16));
    raw_q = u16_to_i16(bitand(raw, uint32(65535)));

    switch quadrant
        case 0
            ri = raw_i; rq = raw_q;
        case 1
            ri = raw_q; rq = raw_i;
        case 2
            ri = neg16(raw_q); rq = raw_i;
        case 3
            ri = neg16(raw_i); rq = raw_q;
        case 4
            ri = raw_i; rq = neg16(raw_q);
        case 5
            ri = raw_q; rq = neg16(raw_i);
        case 6
            ri = neg16(raw_q); rq = neg16(raw_i);
        case 7
            ri = neg16(raw_i); rq = neg16(raw_q);
        otherwise
            error('bad quadrant');
    end

    prod_i = int64(in_i(k)) * int64(ri) - int64(in_q(k)) * int64(rq);
    prod_q = int64(in_i(k)) * int64(rq) + int64(in_q(k)) * int64(ri);

    expected_i(k) = wrap_i16(floor(double(prod_i) / 2^shift));
    expected_q(k) = wrap_i16(floor(double(prod_q) / 2^shift));
    addr(k) = a;
    quadrants(k) = quadrant;
    rot_i_vec(k) = ri;
    rot_q_vec(k) = rq;
end

write_count(fullfile(outdir, 'openofdm_rotate_count.txt'), numel(in_i));
write_hex(fullfile(outdir, 'openofdm_rotate_i.hex'), typecast(in_i(:), 'uint16'), 4);
write_hex(fullfile(outdir, 'openofdm_rotate_q.hex'), typecast(in_q(:), 'uint16'), 4);
write_hex(fullfile(outdir, 'openofdm_rotate_phase.hex'), typecast(phase(:), 'uint32'), 8);
write_hex(fullfile(outdir, 'openofdm_rotate_expected_i.hex'), typecast(expected_i(:), 'uint16'), 4);
write_hex(fullfile(outdir, 'openofdm_rotate_expected_q.hex'), typecast(expected_q(:), 'uint16'), 4);
write_hex(fullfile(outdir, 'openofdm_rotate_addr.hex'), uint32(addr(:)), 3);
write_hex(fullfile(outdir, 'openofdm_rotate_quadrant.hex'), uint32(quadrants(:)), 1);
write_hex(fullfile(outdir, 'openofdm_rotate_lut_i.hex'), typecast(rot_i_vec(:), 'uint16'), 4);
write_hex(fullfile(outdir, 'openofdm_rotate_lut_q.hex'), typecast(rot_q_vec(:), 'uint16'), 4);

fprintf('Wrote OpenOFDM RX rotate vectors to: %s\n', outdir);
for k = 1:numel(in_i)
    fprintf('ROTATE_VEC[%02d] i=%d q=%d phase=%d quadrant=%d addr=%u rot=(%d,%d) out=(%d,%d)\n', ...
        k - 1, in_i(k), in_q(k), phase(k), quadrants(k), addr(k), ...
        rot_i_vec(k), rot_q_vec(k), expected_i(k), expected_q(k));
end

end

function y = abs32(x)
if x < 0
    y = int32(-x);
else
    y = int32(x);
end
end

function y = neg16(x)
y = wrap_i16(-double(x));
end

function y = u16_to_i16(x)
x = uint16(x);
y = typecast(x, 'int16');
end

function y = wrap_i16(x)
u = uint16(mod(round(x), 65536));
y = typecast(u, 'int16');
end

function lut = read_binary_lut32(path)
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
lut = zeros(numel(lines), 1, 'uint32');
for k = 1:numel(lines)
    lut(k) = uint32(bin2dec(lines{k}));
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
