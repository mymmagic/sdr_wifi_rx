function [y, dbg] = openwifi_ifft64_fixed_model(x, src_dir)
%OPENWIFI_IFFT64_FIXED_MODEL Fixed-point model of openwifi ifftmain.v.
%
%   Y = OPENWIFI_IFFT64_FIXED_MODEL(X) models the generated 64-point
%   inverse DIF FFT core in:
%
%     C:\wifi\openwifi-hw-master\openwifi-hw-master\ip\openofdm_tx\src\ifftmain.v
%
%   X may be a 64-by-1 complex vector or a 64-by-2 [real imag] matrix.
%   Inputs are treated as signed 16-bit integers.  Y is a 64-by-2 int32
%   matrix [real imag], matching the RTL output word order after bitreverse.
%
%   The model intentionally follows the RTL scaling:
%     - twiddles are read from icmem_*.mem as signed 20-bit values
%     - fftstage uses hwbfly arithmetic and convround windows
%     - qtrstage and laststage use their own convround instances
%     - final output order follows bitreverse.v

if nargin < 2 || isempty(src_dir)
    src_dir = 'C:\wifi\openwifi-hw-master\openwifi-hw-master\ip\openofdm_tx\src';
end

u = normalize_input(x);

dbg = struct();
dbg.input = int32(u);

[c64r, c64i] = read_icmem(fullfile(src_dir, 'icmem_64.mem'), 20);
[c32r, c32i] = read_icmem(fullfile(src_dir, 'icmem_32.mem'), 20);
[c16r, c16i] = read_icmem(fullfile(src_dir, 'icmem_16.mem'), 20);
[c8r,  c8i ] = read_icmem(fullfile(src_dir, 'icmem_8.mem'),  20);

s64 = fftstage_hwbfly_model(u,   c64r, c64i, 64, 16, 20, 16, 0);
s32 = fftstage_hwbfly_model(s64, c32r, c32i, 32, 16, 20, 16, 0);
s16 = fftstage_hwbfly_model(s32, c16r, c16i, 16, 16, 20, 16, 0);
s8  = fftstage_hwbfly_model(s16, c8r,  c8i,   8, 16, 20, 16, 0);
s4  = qtrstage_model(s8, 16, 16, 0, 1);
s2  = laststage_model(s4, 16, 16, 1);

idx = bitreverse_indices(64) + 1;
y = int32(s2(idx, :));

dbg.after_stage_64 = int32(s64);
dbg.after_stage_32 = int32(s32);
dbg.after_stage_16 = int32(s16);
dbg.after_stage_8  = int32(s8);
dbg.after_qtrstage = int32(s4);
dbg.before_bitreverse = int32(s2);
dbg.bitreverse_index0 = int32(idx(:) - 1);
end

function u = normalize_input(x)
if isvector(x) && ~isreal(x)
    xr = real(x(:));
    xi = imag(x(:));
elseif ismatrix(x) && size(x, 2) == 2
    xr = x(:, 1);
    xi = x(:, 2);
else
    error('Input must be a 64-by-1 complex vector or 64-by-2 [real imag] matrix.');
end

if numel(xr) ~= 64
    error('ifftmain.v is a generated 64-point core; input must contain 64 samples.');
end

u = zeros(64, 2);
u(:, 1) = wrap_signed(round(double(xr)), 16);
u(:, 2) = wrap_signed(round(double(xi)), 16);
end

function y = fftstage_hwbfly_model(x, cr, ci, span, iwidth, cwidth, owidth, bflyshift)
n = size(x, 1);
if mod(n, span) ~= 0
    error('Input length must be a multiple of the stage span.');
end

half = span / 2;
y = zeros(n, 2);
for base = 1:span:n
    for k = 0:(half - 1)
        a = x(base + k, :);
        b = x(base + half + k, :);
        [left, right] = hwbfly_pair(a, b, cr(k + 1), ci(k + 1), ...
            iwidth, cwidth, owidth, bflyshift);
        y(base + k, :) = left;
        y(base + half + k, :) = right;
    end
end
end

function [left, right] = hwbfly_pair(a, b, cr, ci, iwidth, cwidth, owidth, shift)
ar = wrap_signed(a(1), iwidth);
ai = wrap_signed(a(2), iwidth);
br = wrap_signed(b(1), iwidth);
bi = wrap_signed(b(2), iwidth);
cr = wrap_signed(cr, cwidth);
ci = wrap_signed(ci, cwidth);

sum_r = wrap_signed(ar + br, iwidth + 1);
sum_i = wrap_signed(ai + bi, iwidth + 1);
dif_r = wrap_signed(ar - br, iwidth + 1);
dif_i = wrap_signed(ai - bi, iwidth + 1);

left_sr = wrap_signed(sum_r * pow2i(cwidth - 2), cwidth + iwidth + 1);
left_si = wrap_signed(sum_i * pow2i(cwidth - 2), cwidth + iwidth + 1);

left = zeros(1, 2);
left(1) = convround_rtl(left_sr, cwidth + iwidth + 1, owidth, shift + 2);
left(2) = convround_rtl(left_si, cwidth + iwidth + 1, owidth, shift + 2);

p_one = wrap_signed(cr * dif_r, (iwidth + 1) + cwidth);
p_two = wrap_signed(ci * dif_i, (iwidth + 1) + cwidth);

p3c = wrap_signed(cr + ci, cwidth + 1);
p3d = wrap_signed(dif_r + dif_i, iwidth + 2);
p_three = wrap_signed(p3c * p3d, (cwidth + 1) + (iwidth + 2));

mpy_width = cwidth + iwidth + 3;
w_one = wrap_signed(p_one, mpy_width);
w_two = wrap_signed(p_two, mpy_width);
mpy_r = wrap_signed(w_one - w_two, mpy_width);
mpy_i = wrap_signed(p_three - w_one - w_two, mpy_width);

right = zeros(1, 2);
right(1) = convround_rtl(mpy_r, mpy_width, owidth, shift + 4);
right(2) = convround_rtl(mpy_i, mpy_width, owidth, shift + 4);
end

function y = qtrstage_model(x, iwidth, owidth, shift, inverse)
n = size(x, 1);
if mod(n, 4) ~= 0
    error('qtrstage input length must be a multiple of 4.');
end

y = zeros(n, 2);
for base = 1:4:n
    x0 = x(base, :);
    x1 = x(base + 1, :);
    x2 = x(base + 2, :);
    x3 = x(base + 3, :);

    [a0, b0] = qtr_pair(x0, x2, iwidth, owidth, shift);
    [a1, d1] = qtr_pair(x1, x3, iwidth, owidth, shift);

    if inverse
        b1 = [wrap_signed(-d1(2), owidth), d1(1)];
    else
        b1 = [d1(2), wrap_signed(-d1(1), owidth)];
    end

    y(base, :)     = a0;
    y(base + 1, :) = a1;
    y(base + 2, :) = b0;
    y(base + 3, :) = b1;
end
end

function [sum_out, diff_out] = qtr_pair(a, b, iwidth, owidth, shift)
sum_r = wrap_signed(a(1) + b(1), iwidth + 1);
sum_i = wrap_signed(a(2) + b(2), iwidth + 1);
dif_r = wrap_signed(a(1) - b(1), iwidth + 1);
dif_i = wrap_signed(a(2) - b(2), iwidth + 1);

sum_out = [ ...
    convround_rtl(sum_r, iwidth + 1, owidth, shift), ...
    convround_rtl(sum_i, iwidth + 1, owidth, shift)];
diff_out = [ ...
    convround_rtl(dif_r, iwidth + 1, owidth, shift), ...
    convround_rtl(dif_i, iwidth + 1, owidth, shift)];
end

function y = laststage_model(x, iwidth, owidth, shift)
n = size(x, 1);
if mod(n, 2) ~= 0
    error('laststage input length must be even.');
end

y = zeros(n, 2);
for base = 1:2:n
    a = x(base, :);
    b = x(base + 1, :);
    sum_r = wrap_signed(a(1) + b(1), iwidth + 1);
    sum_i = wrap_signed(a(2) + b(2), iwidth + 1);
    dif_r = wrap_signed(a(1) - b(1), iwidth + 1);
    dif_i = wrap_signed(a(2) - b(2), iwidth + 1);

    y(base, :) = [ ...
        convround_rtl(sum_r, iwidth + 1, owidth, shift), ...
        convround_rtl(sum_i, iwidth + 1, owidth, shift)];
    y(base + 1, :) = [ ...
        convround_rtl(dif_r, iwidth + 1, owidth, shift), ...
        convround_rtl(dif_i, iwidth + 1, owidth, shift)];
end
end

function y = convround_rtl(v, iwid, owid, shift)
% Match convround.v bit-window selection and convergent rounding.
v = wrap_signed(v, iwid);

if iwid == owid
    y = wrap_signed(v, owid);
    return;
end

drop = iwid - shift - owid;

if drop < 0
    kept_width = iwid - shift;
    y = wrap_signed(wrap_signed(v, kept_width), owid);
elseif drop == 0
    y = wrap_signed(v, owid);
elseif drop == 1
    truncated = wrap_signed(floor(v / 2), owid);
    first_lost_bit = bit_at(v, 0);
    last_valid_bit = bit_at(truncated, 0);
    if first_lost_bit && last_valid_bit
        y = wrap_signed(truncated + 1, owid);
    else
        y = truncated;
    end
else
    truncated = wrap_signed(floor(v / pow2i(drop)), owid);
    first_lost_bit = bit_at(v, drop - 1);
    other_lost_bits = mod(v, pow2i(drop - 1)) ~= 0;
    last_valid_bit = bit_at(truncated, 0);

    if first_lost_bit && (other_lost_bits || last_valid_bit)
        y = wrap_signed(truncated + 1, owid);
    else
        y = truncated;
    end
end
end

function b = bit_at(v, pos)
b = mod(floor(v / pow2i(pos)), 2) ~= 0;
end

function y = wrap_signed(v, width)
scale = pow2i(width);
half = pow2i(width - 1);
y = mod(double(v) + half, scale) - half;
end

function p = pow2i(n)
p = 2.^double(n);
end

function idx = bitreverse_indices(n)
lg = log2(n);
if abs(lg - round(lg)) > eps
    error('n must be a power of two.');
end
lg = round(lg);
idx = zeros(n, 1);
for k = 0:(n - 1)
    r = 0;
    for b = 0:(lg - 1)
        if bitand(k, bitshift(1, b))
            r = bitor(r, bitshift(1, lg - 1 - b));
        end
    end
    idx(k + 1) = r;
end
end

function [cr, ci] = read_icmem(path_name, cwidth)
fid = fopen(path_name, 'r');
if fid < 0
    error('Could not open coefficient file: %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));

lines = textscan(fid, '%s', 'CommentStyle', '//');
lines = lines{1};
cr = zeros(numel(lines), 1);
ci = zeros(numel(lines), 1);
hex_digits = ceil(2 * cwidth / 4);

for k = 1:numel(lines)
    h = strtrim(lines{k});
    if isempty(h)
        continue;
    end
    if numel(h) < hex_digits
        h = [repmat('0', 1, hex_digits - numel(h)), h]; %#ok<AGROW>
    end
    word = hex2dec(h);
    imag_u = mod(word, pow2i(cwidth));
    real_u = floor(word / pow2i(cwidth));
    cr(k) = unsigned_to_signed(real_u, cwidth);
    ci(k) = unsigned_to_signed(imag_u, cwidth);
end
end

function s = unsigned_to_signed(u, width)
half = pow2i(width - 1);
scale = pow2i(width);
if u >= half
    s = u - scale;
else
    s = u;
end
end
