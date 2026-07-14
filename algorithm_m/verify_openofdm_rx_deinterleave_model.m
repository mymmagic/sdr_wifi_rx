function verify_openofdm_rx_deinterleave_model(case_name)
%VERIFY_OPENOFDM_RX_DEINTERLEAVE_MODEL Generate vectors for deinterleave.v.
% Coverage points include legacy 6 Mbps and legacy 48 Mbps.

out_dir = fileparts(mfilename('fullpath'));

if nargin < 1
    case_name = 'legacy6';
end

switch lower(case_name)
    case 'legacy6'
        rate = uint8(11); % 1011
        rate_mbps = 6;
        ht = false;
        n_bpsc = 1;
        n_cbps = 48;
        erase_mode = '1/2';
    case 'legacy48'
        rate = uint8(8); % 1000
        rate_mbps = 48;
        ht = false;
        n_bpsc = 6;
        n_cbps = 288;
        erase_mode = '2/3';
    otherwise
        error('Unknown deinterleave case: %s', case_name);
end

num_data_carrier = 48;
half_data_carrier = 24;

% One 6-bit demod word per data carrier. Nonzero higher bits prove that the
% LUT bit index is honored for high-order QAM as well.
in_words = zeros(num_data_carrier, 1, 'uint8');
for k = 1:num_data_carrier
    in_words(k) = uint8(mod(7*k + 3, 64));
end

ram = zeros(64, 1, 'uint8');
addr = half_data_carrier;
for k = 1:num_data_carrier
    ram(addr + 1) = in_words(k);
    if addr == num_data_carrier - 1
        addr = 0;
    else
        addr = addr + 1;
    end
end

seq = deinterleave_seq(n_bpsc, n_cbps, ht);
lut_entries = deinter_lut_entries(seq, n_bpsc, erase_mode, half_data_carrier);
out_entries = lut_entries([lut_entries.out_stb] == 1);
num_out = numel(out_entries);
expected_bits = zeros(num_out, 1, 'uint8');
expected_erase = zeros(num_out, 1, 'uint8');
for k = 1:num_out
    addra = out_entries(k).addra;
    bita = out_entries(k).bita;
    addrb = out_entries(k).addrb;
    bitb = out_entries(k).bitb;
    out0 = bitget(ram(addra + 1), bita + 1);
    out1 = bitget(ram(addrb + 1), bitb + 1);
    expected_bits(k) = uint8(out0 + 2*out1);
    expected_erase(k) = uint8(out_entries(k).erase0 + 2*out_entries(k).erase1);
end

write_hex8(fullfile(out_dir, 'openofdm_deinterleave_input.hex'), in_words);
write_hex8(fullfile(out_dir, 'openofdm_deinterleave_expected_bits.hex'), expected_bits);
write_hex8(fullfile(out_dir, 'openofdm_deinterleave_expected_erase.hex'), expected_erase);
write_hex8(fullfile(out_dir, 'openofdm_deinterleave_rate.hex'), rate);

fid = fopen(fullfile(out_dir, 'openofdm_deinterleave_input_count.txt'), 'w');
fprintf(fid, '%d\n', num_data_carrier);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_deinterleave_output_count.txt'), 'w');
fprintf(fid, '%d\n', num_out);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_deinterleave_model_trace.csv'), 'w');
fprintf(fid, 'out_idx,addra,bita,addrb,bitb,out_bits,erase\n');
for k = 1:num_out
    fprintf(fid, '%d,%d,%d,%d,%d,%02x,%02x\n', ...
        k-1, out_entries(k).addra, out_entries(k).bita, ...
        out_entries(k).addrb, out_entries(k).bitb, expected_bits(k), expected_erase(k));
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_deinterleave_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX deinterleave reverse model\n');
fprintf(fid, 'case=%s, legacy_rate_mbps=%d, rate=0x%02x, n_bpsc=%d, n_cbps=%d\n', ...
    case_name, rate_mbps, rate, n_bpsc, n_cbps);
fprintf(fid, 'input_words=%d output_pairs=%d puncturing=%s\n', num_data_carrier, num_out, erase_mode);
fprintf(fid, 'write_addr_order=24..47,0..23 for legacy 48 carriers\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX deinterleave vectors to: %s\n', out_dir);
end

function seq = deinterleave_seq(n_bpsc, n_cbps, ht)
if ht
    n_col = 13;
    n_row = 4*n_bpsc;
else
    n_col = 16;
    n_row = 3*n_bpsc;
end
s = max(floor(n_bpsc/2), 1);
idx_map = zeros(n_cbps, 2);
for k = 0:n_cbps-1
    first = s*floor(k/s) + mod(k + floor(n_col*k/n_cbps), s);
    second = n_col*first - (n_cbps-1)*floor(first/n_row);
    idx_map(k+1,:) = [second, k];
end
idx_map = sortrows(idx_map, 1);
seq = idx_map(:,2).';
end

function entries = deinter_lut_entries(seq, n_bpsc, erase_mode, reset_addr)
entries = struct('addra', {}, 'addrb', {}, 'bita', {}, 'bitb', {}, ...
    'erase0', {}, 'erase1', {}, 'out_stb', {}, 'done', {});
pos = 1;
puncture = 0;
while pos <= numel(seq)
    a = seq(pos);
    if pos + 1 <= numel(seq)
        b = seq(pos + 1);
    else
        b = 0;
    end
    entry = make_entry(floor(a/n_bpsc), floor(b/n_bpsc), mod(a,n_bpsc), mod(b,n_bpsc), 0, 0, 1, 0);
    switch erase_mode
        case '1/2'
            entries(end+1) = entry; %#ok<AGROW>
        case '3/4'
            if puncture == 0
                entries(end+1) = entry; %#ok<AGROW>
                puncture = 1;
            else
                entry1 = entry;
                entry1.erase1 = 1;
                entries(end+1) = entry1; %#ok<AGROW>
                entry2 = entry;
                entry2.erase0 = 1;
                entries(end+1) = entry2; %#ok<AGROW>
                puncture = 0;
            end
        case '2/3'
            if puncture == 0
                entries(end+1) = entry; %#ok<AGROW>
                puncture = 1;
            else
                entry1 = entry;
                entry1.erase1 = 1;
                entries(end+1) = entry1; %#ok<AGROW>
                pos = pos - 1;
                puncture = 0;
            end
        case '5/6'
            if puncture == 0
                entries(end+1) = entry; %#ok<AGROW>
                puncture = 1;
            elseif puncture == 1
                entry1 = entry;
                entry1.erase1 = 1;
                entries(end+1) = entry1; %#ok<AGROW>
                entry2 = entry;
                entry2.erase0 = 1;
                entries(end+1) = entry2; %#ok<AGROW>
                puncture = 2;
            else
                entry1 = entry;
                entry1.erase1 = 1;
                entries(end+1) = entry1; %#ok<AGROW>
                entry2 = entry;
                entry2.erase0 = 1;
                entries(end+1) = entry2; %#ok<AGROW>
                puncture = 0;
            end
    end
    pos = pos + 2;
end
entries(end+1) = make_entry(reset_addr, 0, 0, 0, 0, 0, 0, 1);
end

function entry = make_entry(addra, addrb, bita, bitb, erase0, erase1, out_stb, done)
entry = struct('addra', addra, 'addrb', addrb, 'bita', bita, 'bitb', bitb, ...
    'erase0', erase0, 'erase1', erase1, 'out_stb', out_stb, 'done', done);
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
