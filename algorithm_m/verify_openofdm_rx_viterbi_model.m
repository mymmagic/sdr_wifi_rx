function verify_openofdm_rx_viterbi_model(mode)
% Reverse-vector generator and checker for openofdm RX viterbi.v.
% mode = 'gen' generates soft-input vectors.
% mode = 'check' compares source simulation output against the encoded bits.

if nargin < 1
    mode = 'gen';
end

outdir = fileparts(mfilename('fullpath'));
switch lower(mode)
    case 'gen'
        gen_vectors(outdir);
    case 'check'
        check_outputs(outdir);
    otherwise
        error('unknown mode: %s', mode);
end

end

function gen_vectors(outdir)
payload_len = 144;
tail_len = 48;
bits = zeros(payload_len + tail_len, 1, 'uint8');
state = uint16(hex2dec('5d'));
for k = 1:payload_len
    fb = bitxor(bitget(state, 7), bitget(state, 4));
    bits(k) = uint8(bitget(state, 1));
    state = bitor(bitshift(state, -1), bitshift(uint16(fb), 6));
end

[enc0, enc1] = conv_encode_133_171(bits);

sym0 = uint8(enc0) * 4 + 3; % OpenOFDM maps hard 1 to 111 and hard 0 to 011.
sym1 = uint8(enc1) * 4 + 3;
erase = zeros(size(bits), 'uint8');

write_count(fullfile(outdir, 'openofdm_viterbi_count.txt'), numel(bits));
write_hex(fullfile(outdir, 'openofdm_viterbi_sym0.hex'), uint32(sym0), 1);
write_hex(fullfile(outdir, 'openofdm_viterbi_sym1.hex'), uint32(sym1), 1);
write_hex(fullfile(outdir, 'openofdm_viterbi_erase.hex'), uint32(erase), 1);
write_hex(fullfile(outdir, 'openofdm_viterbi_expected_bits.hex'), uint32(bits), 1);

fprintf('Wrote OpenOFDM RX viterbi vectors to: %s\n', outdir);
fprintf('VITERBI_VEC count=%d payload=%d tail=%d generator=(133,171) soft0=(3,7)\n', ...
    numel(bits), payload_len, tail_len);
end

function check_outputs(outdir)
expected = read_hex_vec(fullfile(outdir, 'openofdm_viterbi_expected_bits.hex'));
observed = read_viterbi_trace(fullfile(outdir, 'openofdm_viterbi_out_bits.txt'));
payload_len = 144;
traceback_len = 24;
stable_first = 3;                    % Skip the initial traceback convergence.
stable_last = payload_len - traceback_len;

best_shift = -1;
best_mismatches = intmax;
best_checked = 0;

for shift = 0:96
    checked = 0;
    mismatches = 0;
    for k = 1:numel(observed)
        exp_idx = k - shift;
        if exp_idx < stable_first || exp_idx > stable_last
            continue;
        end
        checked = checked + 1;
        if observed(k) ~= expected(exp_idx)
            mismatches = mismatches + 1;
        end
    end
    if checked >= 80 && mismatches < best_mismatches
        best_mismatches = mismatches;
        best_shift = shift;
        best_checked = checked;
    end
end

if best_shift < 0
    error('could not align Viterbi output to expected bits');
end

trace_path = fullfile(outdir, 'openofdm_viterbi_compare_trace.csv');
fid = fopen(trace_path, 'w');
assert(fid >= 0, 'could not write trace');
fprintf(fid, 'out_idx,observed,expected_idx,expected,match\n');
for k = 1:numel(observed)
    exp_idx = k - best_shift;
    if exp_idx >= 1 && exp_idx <= numel(expected)
        fprintf(fid, '%d,%d,%d,%d,%d\n', k - 1, observed(k), exp_idx - 1, ...
            expected(exp_idx), observed(k) == expected(exp_idx));
    end
end
fclose(fid);

fprintf('VITERBI_ALIGN shift=%d checked=%d mismatches=%d observed=%d\n', ...
    best_shift, best_checked, best_mismatches, numel(observed));
fprintf('VITERBI_STABLE_WINDOW expected_idx=%d..%d, excluded traceback head/tail convergence\n', ...
    stable_first - 1, stable_last - 1);

if best_mismatches == 0
    fprintf('PASS: openofdm RX viterbi wrapper/core stable payload output matches MATLAB convolutional-code expectation after traceback alignment.\n');
else
    error('FAIL: Viterbi mismatch count %d at best shift %d', best_mismatches, best_shift);
end
end

function [enc0, enc1] = conv_encode_133_171(bits)
g0 = logical([1 0 1 1 0 1 1]); % octal 133, MSB first over [current prev1 ... prev6]
g1 = logical([1 1 1 1 0 0 1]); % octal 171
shift = false(1, 7);
enc0 = zeros(size(bits), 'uint8');
enc1 = zeros(size(bits), 'uint8');
for k = 1:numel(bits)
    shift = [logical(bits(k)), shift(1:6)];
    enc0(k) = uint8(mod(sum(shift(g0)), 2));
    enc1(k) = uint8(mod(sum(shift(g1)), 2));
end
end

function values = read_hex_vec(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open %s', path);
c = onCleanup(@() fclose(fid));
values = [];
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    t = strtrim(t);
    if isempty(t)
        continue;
    end
    values(end + 1, 1) = uint8(hex2dec(t)); %#ok<AGROW>
end
end

function bits = read_viterbi_trace(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open %s', path);
c = onCleanup(@() fclose(fid));
bits = [];
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    vals = sscanf(t, '%d,%d,%d');
    if numel(vals) == 3
        bits(end + 1, 1) = uint8(vals(2)); %#ok<AGROW>
    end
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
