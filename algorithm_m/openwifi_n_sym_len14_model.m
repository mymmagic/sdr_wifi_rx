function n_sym = openwifi_n_sym_len14_model(ht_flag, rate_mcs)
%OPENWIFI_N_SYM_LEN14_MODEL Reverse model for n_sym_len14_pkt.v.

key = uint8(uint8(ht_flag(:)) * 16 + uint8(rate_mcs(:)));
n_sym = zeros(size(key), 'uint8');

for k = 1:numel(key)
    switch key(k)
        case bin2dec('01011') % non-HT 6 Mbps
            n_sym(k) = 6;
        case bin2dec('01111') % non-HT 9 Mbps
            n_sym(k) = 4;
        case bin2dec('01010') % non-HT 12 Mbps
            n_sym(k) = 3;
        case {bin2dec('01110'), bin2dec('01001')} % non-HT 18/24 Mbps
            n_sym(k) = 2;
        case {bin2dec('01101'), bin2dec('01000'), bin2dec('01100')} % non-HT 36/48/54 Mbps
            n_sym(k) = 1;
        case bin2dec('10000') % HT MCS0
            n_sym(k) = 6;
        case bin2dec('10001') % HT MCS1
            n_sym(k) = 3;
        case {bin2dec('10010'), bin2dec('10011')} % HT MCS2/3
            n_sym(k) = 2;
        case {bin2dec('10100'), bin2dec('10101'), bin2dec('10110'), bin2dec('10111')} % HT MCS4..7
            n_sym(k) = 1;
        otherwise
            n_sym(k) = 6;
    end
end
end
