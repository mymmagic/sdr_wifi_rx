function [crc, trace_c, trace_i, trace_bit] = openwifi_ht_sig_crc_model(data_words)
%OPENWIFI_HT_SIG_CRC_MODEL Reverse model for ht_sig_crc_calc.v.
%
% The RTL shifts in d[0]..d[33], initializes c to 0xff, and outputs the
% complemented bit-reversal of c one cycle later when i == 34.

data_words = uint64(data_words(:));
n = numel(data_words);
crc = zeros(n, 1, 'uint8');
trace_c = zeros(n * 34, 1, 'uint8');
trace_i = zeros(n * 34, 1, 'uint8');
trace_bit = zeros(n * 34, 1, 'uint8');

trace_idx = 1;
for k = 1:n
    c = uint8(255);
    for i = uint8(0):uint8(33)
        data_bit = uint8(bitget(data_words(k), double(i) + 1));
        trace_c(trace_idx) = c;
        trace_i(trace_idx) = i;
        trace_bit(trace_idx) = data_bit;
        trace_idx = trace_idx + 1;
        c = crc_step(c, data_bit);
    end
    crc(k) = bitcmp(reverse8(c), 'uint8');
end
end

function c_next = crc_step(c, data_bit)
temp = uint8(xor(bitget(c, 8), data_bit));
c_next = uint8(0);
c_next = bitset(c_next, 8, bitget(c, 7));
c_next = bitset(c_next, 7, bitget(c, 6));
c_next = bitset(c_next, 6, bitget(c, 5));
c_next = bitset(c_next, 5, bitget(c, 4));
c_next = bitset(c_next, 4, bitget(c, 3));
c_next = bitset(c_next, 3, xor(bitget(c, 2), temp));
c_next = bitset(c_next, 2, xor(bitget(c, 1), temp));
c_next = bitset(c_next, 1, temp);
end

function y = reverse8(x)
y = uint8(0);
for b = 0:7
    y = bitset(y, 8 - b, bitget(x, b + 1));
end
end
