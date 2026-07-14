function [idx_o, punc_o, info] = openwifi_punc_interlv_model(rate, idx_i)
%OPENWIFI_PUNC_INTERLV_MODEL MATLAB model of punc_interlv_lut.v.
%
%   [IDX_O, PUNC_O] = OPENWIFI_PUNC_INTERLV_MODEL(RATE, IDX_I) returns
%   the packed output fields used by openwifi:
%       IDX_O  = [addr_for_conv_bit0, addr_for_conv_bit1] packed as
%                {high_addr, low_addr} in RTL order.
%       PUNC_O = [punc_for_high_addr, punc_for_low_addr] packed as RTL bits.
%
%   The low half of idx_o corresponds to the first post-puncture coded bit
%   consumed by dot11_tx.v, which is bits_enc[1].  The high half corresponds
%   to bits_enc[0].

rate = double(rate(:));
idx_i = double(idx_i(:));
if numel(rate) == 1 && numel(idx_i) > 1
    rate = repmat(rate, numel(idx_i), 1);
end
if numel(idx_i) == 1 && numel(rate) > 1
    idx_i = repmat(idx_i, numel(rate), 1);
end
if numel(rate) ~= numel(idx_i)
    error('rate and idx_i must be scalar-compatible vectors.');
end

idx_o = repmat(int32([511, 511]), numel(rate), 1);  % [high low]
punc_o = repmat(int32([1, 1]), numel(rate), 1);     % [high low]
info = repmat(struct('valid', false, 'n_bpsc', 0, 'n_cbps', 0, ...
    'n_dbps', 0, 'n_col', 0, 'puncture', ''), numel(rate), 1);

for n = 1:numel(rate)
    cfg = rate_cfg(rate(n));
    if ~cfg.valid || idx_i(n) < 0 || idx_i(n) >= cfg.n_dbps
        continue;
    end

    raw0 = 2 * idx_i(n);     % first consumed raw coded bit: bits_enc[1]
    raw1 = raw0 + 1;         % second consumed raw coded bit: bits_enc[0]
    keep0 = puncture_keep(cfg.puncture, raw0);
    keep1 = puncture_keep(cfg.puncture, raw1);

    low_addr = 511;
    high_addr = 511;

    if keep0
        k0 = post_puncture_index(cfg.puncture, raw0);
        low_addr = interleaver_ram_addr(k0, cfg.n_cbps, cfg.n_bpsc, cfg.n_col);
    end

    if keep1
        k1 = post_puncture_index(cfg.puncture, raw1);
        high_addr = interleaver_ram_addr(k1, cfg.n_cbps, cfg.n_bpsc, cfg.n_col);
    end

    idx_o(n, :) = int32([high_addr, low_addr]);
    punc_o(n, :) = int32([~keep1, ~keep0]);
    info(n).valid = true;
    info(n).n_bpsc = cfg.n_bpsc;
    info(n).n_cbps = cfg.n_cbps;
    info(n).n_dbps = cfg.n_dbps;
    info(n).n_col = cfg.n_col;
    info(n).puncture = cfg.puncture;
end
end

function cfg = rate_cfg(rate)
cfg = struct('valid', true, 'n_bpsc', 0, 'n_cbps', 0, 'n_dbps', 0, 'n_col', 16, 'puncture', '');
switch rate
    case bin2dec('01011') % 6 Mbps
        cfg.n_bpsc = 1; cfg.n_cbps = 48;  cfg.n_dbps = 24;  cfg.puncture = '1/2';
    case bin2dec('01111') % 9 Mbps
        cfg.n_bpsc = 1; cfg.n_cbps = 48;  cfg.n_dbps = 36;  cfg.puncture = '3/4';
    case bin2dec('01010') % 12 Mbps
        cfg.n_bpsc = 2; cfg.n_cbps = 96;  cfg.n_dbps = 48;  cfg.puncture = '1/2';
    case bin2dec('01110') % 18 Mbps
        cfg.n_bpsc = 2; cfg.n_cbps = 96;  cfg.n_dbps = 72;  cfg.puncture = '3/4';
    case bin2dec('01001') % 24 Mbps
        cfg.n_bpsc = 4; cfg.n_cbps = 192; cfg.n_dbps = 96;  cfg.puncture = '1/2';
    case bin2dec('01101') % 36 Mbps
        cfg.n_bpsc = 4; cfg.n_cbps = 192; cfg.n_dbps = 144; cfg.puncture = '3/4';
    case bin2dec('01000') % 48 Mbps
        cfg.n_bpsc = 6; cfg.n_cbps = 288; cfg.n_dbps = 192; cfg.puncture = '2/3';
    case bin2dec('01100') % 54 Mbps
        cfg.n_bpsc = 6; cfg.n_cbps = 288; cfg.n_dbps = 216; cfg.puncture = '3/4';
    case bin2dec('10000') % MCS0 6.5/7.2 Mbps
        cfg.n_bpsc = 1; cfg.n_cbps = 52;  cfg.n_dbps = 26;  cfg.n_col = 13; cfg.puncture = '1/2';
    case bin2dec('10001') % MCS1 13.0/14.4 Mbps
        cfg.n_bpsc = 2; cfg.n_cbps = 104; cfg.n_dbps = 52;  cfg.n_col = 13; cfg.puncture = '1/2';
    case bin2dec('10010') % MCS2 19.5/21.7 Mbps
        cfg.n_bpsc = 2; cfg.n_cbps = 104; cfg.n_dbps = 78;  cfg.n_col = 13; cfg.puncture = '3/4';
    case bin2dec('10011') % MCS3 26.0/28.9 Mbps
        cfg.n_bpsc = 4; cfg.n_cbps = 208; cfg.n_dbps = 104; cfg.n_col = 13; cfg.puncture = '1/2';
    case bin2dec('10100') % MCS4 39.0/43.3 Mbps
        cfg.n_bpsc = 4; cfg.n_cbps = 208; cfg.n_dbps = 156; cfg.n_col = 13; cfg.puncture = '3/4';
    case bin2dec('10101') % MCS5 52.0/57.8 Mbps
        cfg.n_bpsc = 6; cfg.n_cbps = 312; cfg.n_dbps = 208; cfg.n_col = 13; cfg.puncture = '2/3';
    case bin2dec('10110') % MCS6 58.5/65.0 Mbps
        cfg.n_bpsc = 6; cfg.n_cbps = 312; cfg.n_dbps = 234; cfg.n_col = 13; cfg.puncture = '3/4';
    case bin2dec('10111') % MCS7 65.0/72.2 Mbps
        cfg.n_bpsc = 6; cfg.n_cbps = 312; cfg.n_dbps = 260; cfg.n_col = 13; cfg.puncture = '5/6';
    otherwise
        cfg.valid = false;
end
end

function keep = puncture_keep(pattern, raw_idx)
switch pattern
    case '1/2'
        pat = [1 1];
    case '2/3'
        pat = [1 1 1 0];
    case '3/4'
        pat = [1 1 1 0 0 1];
    case '5/6'
        pat = [1 1 1 0 0 1 1 0 0 1];
    otherwise
        error('Unknown puncture pattern: %s', pattern);
end
keep = pat(mod(raw_idx, numel(pat)) + 1) ~= 0;
end

function k = post_puncture_index(pattern, raw_idx)
switch pattern
    case '1/2'
        pat = [1 1];
    case '2/3'
        pat = [1 1 1 0];
    case '3/4'
        pat = [1 1 1 0 0 1];
    case '5/6'
        pat = [1 1 1 0 0 1 1 0 0 1];
    otherwise
        error('Unknown puncture pattern: %s', pattern);
end
period = numel(pat);
full_periods = floor(raw_idx / period);
rem_idx = mod(raw_idx, period);
k = full_periods * sum(pat) + sum(pat(1:rem_idx));
end

function addr = interleaver_ram_addr(k, n_cbps, n_bpsc, n_col)
s = max(n_bpsc / 2, 1);
i = (n_cbps / n_col) * mod(k, n_col) + floor(k / n_col);
j = s * floor(i / s) + mod(i + n_cbps - floor(n_col * i / n_cbps), s);
addr = floor(j / n_bpsc) * 8 + mod(j, n_bpsc);
end
