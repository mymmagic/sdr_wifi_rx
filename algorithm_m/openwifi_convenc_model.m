function [bits_out, state_before, state_after] = openwifi_convenc_model(bit_in, enc_en, rst)
%OPENWIFI_CONVENC_MODEL MATLAB model of openofdm_tx convenc.v.
%
%   The model follows the RTL exactly:
%     bits_out[0] = bit_in ^ state[0] ^ state[1] ^ state[2] ^ state[5]
%     bits_out[1] = bit_in ^ state[1] ^ state[2] ^ state[4] ^ state[5]
%     if rst: state = 0
%     else if enc_en: state = {state[4:0], bit_in}
%
%   Outputs are reported as [bit0 bit1] per input cycle, using the state
%   value before the clock edge updates it.

bit_in = logical(bit_in(:));
enc_en = logical(enc_en(:));
rst = logical(rst(:));

n = max([numel(bit_in), numel(enc_en), numel(rst)]);
bit_in = expand_scalar(bit_in, n);
enc_en = expand_scalar(enc_en, n);
rst = expand_scalar(rst, n);

state = false(1, 6);
bits_out = false(n, 2);
state_before = false(n, 6);
state_after = false(n, 6);

for k = 1:n
    state_before(k, :) = state;

    b = bit_in(k);
    bits_out(k, 1) = xor_many([b, state(1), state(2), state(3), state(6)]);
    bits_out(k, 2) = xor_many([b, state(2), state(3), state(5), state(6)]);

    if rst(k)
        state = false(1, 6);
    elseif enc_en(k)
        state = [b, state(1:5)];
    end

    state_after(k, :) = state;
end

bits_out = int32(bits_out);
state_before = int32(state_before);
state_after = int32(state_after);
end

function y = expand_scalar(x, n)
if numel(x) == 1
    y = repmat(x, n, 1);
elseif numel(x) == n
    y = x;
else
    error('Inputs must be scalar-compatible vectors.');
end
end

function y = xor_many(x)
y = false;
for k = 1:numel(x)
    y = xor(y, logical(x(k)));
end
end
