function iq = openwifi_tx_modulation_model(n_bpsc, bits_in)
%OPENWIFI_TX_MODULATION_MODEL MATLAB model of openofdm_tx modulation.v.
%
%   IQ = OPENWIFI_TX_MODULATION_MODEL(N_BPSC, BITS_IN) returns signed
%   16-bit integer constellation points as [I Q].  N_BPSC may be 1, 2, 4,
%   or 6.  BITS_IN is interpreted the same way as modulation.v.

n_bpsc = double(n_bpsc(:));
bits_in = double(bits_in(:));
if numel(n_bpsc) == 1 && numel(bits_in) > 1
    n_bpsc = repmat(n_bpsc, numel(bits_in), 1);
end
if numel(bits_in) == 1 && numel(n_bpsc) > 1
    bits_in = repmat(bits_in, numel(n_bpsc), 1);
end
if numel(n_bpsc) ~= numel(bits_in)
    error('N_BPSC and bits_in must be scalar-compatible vectors.');
end

iq = zeros(numel(bits_in), 2);
map16 = [-15543, 15543, -5181, 5181]; % 00, 01, 10, 11
map64 = [-17696, 17696, -2528, 2528, -12640, 12640, -7584, 7584];

for k = 1:numel(bits_in)
    b = mod(round(bits_in(k)), 64);
    switch n_bpsc(k)
        case 1
            i = ternary(bitget(b, 1) == 1, 16384, -16384);
            q = 0;

        case 2
            lev = 11585;
            i = ternary(bitget(b, 1) == 1, lev, -lev);
            q = ternary(bitget(b, 2) == 1, lev, -lev);

        case 4
            i_idx = bitand(b, 3) + 1;
            q_idx = bitand(bitshift(b, -2), 3) + 1;
            i = map16(i_idx);
            q = map16(q_idx);

        case 6
            i_idx = bitand(b, 7) + 1;
            q_idx = bitand(bitshift(b, -3), 7) + 1;
            i = map64(i_idx);
            q = map64(q_idx);

        otherwise
            i = 0;
            q = 0;
    end

    iq(k, :) = [i, q];
end

iq = int32(iq);
end

function y = ternary(cond, a, b)
if cond
    y = a;
else
    y = b;
end
end
