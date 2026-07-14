function rows = openwifi_dot11_scrambler_model(init_state, payload_word, psdu_bit_len, n_dbps)
%OPENWIFI_DOT11_SCRAMBLER_MODEL Reverse model for dot11_tx.v DATA scrambler.
%
% This follows the RTL state machine, including the source behavior that the
% DATA tail bits are forced to zero and do not advance the scrambler state.

S11_SERVICE   = uint8(0);
S11_PSDU_DATA = uint8(1);
S11_PSDU_CRC  = uint8(2);
S11_TAIL      = uint8(3);
S11_PAD       = uint8(4);
S11_RESET     = uint8(5);

payload_word = uint64(payload_word);
psdu_bit_len = uint32(psdu_bit_len);
n_dbps = uint32(n_dbps);

psdu_data_bits = psdu_bit_len - 32;
pkt_fcs = local_crc32_for_payload(payload_word, psdu_data_bits);

state11 = S11_SERVICE;
service_bit_cnt = uint32(0);
psdu_bit_cnt = uint32(0);
pkt_fcs_idx = uint32(0);
dbps_cnt = uint32(0);
scram_state = uint8(init_state);

rows = struct( ...
    'bit_scram', {}, ...
    'scram_state', {}, ...
    'state11', {}, ...
    'service_bit_cnt', {}, ...
    'psdu_bit_cnt', {}, ...
    'dbps_cnt', {}, ...
    'input_bit', {}, ...
    'pkt_fcs', {});

while state11 ~= S11_RESET
    tap = scrambler_tap(scram_state);
    input_bit = uint8(0);

    if state11 == S11_SERVICE
        bit_scram = tap;
    elseif state11 == S11_PSDU_DATA
        input_bit = uint8(bitget(payload_word, double(psdu_bit_cnt) + 1));
        bit_scram = bitxor(tap, input_bit);
    elseif state11 == S11_PSDU_CRC
        input_bit = uint8(bitget(pkt_fcs, double(pkt_fcs_idx) + 1));
        bit_scram = bitxor(tap, input_bit);
    elseif state11 == S11_TAIL
        bit_scram = uint8(0);
    elseif state11 == S11_PAD
        bit_scram = tap;
    else
        bit_scram = uint8(0);
    end

    k = numel(rows) + 1;
    rows(k).bit_scram = bit_scram; %#ok<AGROW>
    rows(k).scram_state = scram_state;
    rows(k).state11 = state11;
    rows(k).service_bit_cnt = service_bit_cnt;
    rows(k).psdu_bit_cnt = psdu_bit_cnt;
    rows(k).dbps_cnt = dbps_cnt;
    rows(k).input_bit = input_bit;
    rows(k).pkt_fcs = pkt_fcs;

    old_state11 = state11;
    old_dbps_cnt = dbps_cnt;

    if old_state11 ~= S11_TAIL
        scram_state = scrambler_advance(scram_state);
    end

    if old_state11 == S11_SERVICE
        service_bit_cnt = service_bit_cnt + 1;
        if service_bit_cnt == 16
            psdu_bit_cnt = uint32(0);
            state11 = S11_PSDU_DATA;
        end
    elseif old_state11 == S11_PSDU_DATA
        psdu_bit_cnt = psdu_bit_cnt + 1;
        if psdu_bit_cnt == (psdu_bit_len - 32)
            state11 = S11_PSDU_CRC;
        end
    elseif old_state11 == S11_PSDU_CRC
        psdu_bit_cnt = psdu_bit_cnt + 1;
        pkt_fcs_idx = pkt_fcs_idx + 1;
        if psdu_bit_cnt == psdu_bit_len
            state11 = S11_TAIL;
        end
    elseif old_state11 == S11_TAIL
        psdu_bit_cnt = psdu_bit_cnt + 1;
        if psdu_bit_cnt == (psdu_bit_len + 6)
            state11 = S11_PAD;
        end
    elseif old_state11 == S11_PAD
        psdu_bit_cnt = psdu_bit_cnt + 1;
        if old_dbps_cnt == 0
            state11 = S11_RESET;
        end
    end

    if old_state11 <= S11_PAD
        if old_dbps_cnt == (n_dbps - 1)
            dbps_cnt = uint32(0);
        else
            dbps_cnt = old_dbps_cnt + 1;
        end
    end
end
end

function tap = scrambler_tap(state)
tap = uint8(xor(bitget(state, 7), bitget(state, 4)));
end

function next_state = scrambler_advance(state)
tap = uint16(scrambler_tap(state));
next_state = uint8(bitand(bitshift(uint16(bitand(state, 63)), 1) + tap, 127));
end

function crc = local_crc32_for_payload(payload_word, n_bits)
table = uint32([ ...
    hex2dec('4DBDF21C'), hex2dec('500AE278'), hex2dec('76D3D2D4'), hex2dec('6B64C2B0'), ...
    hex2dec('3B61B38C'), hex2dec('26D6A3E8'), hex2dec('000F9344'), hex2dec('1DB88320'), ...
    hex2dec('A005713C'), hex2dec('BDB26158'), hex2dec('9B6B51F4'), hex2dec('86DC4190'), ...
    hex2dec('D6D930AC'), hex2dec('CB6E20C8'), hex2dec('EDB71064'), hex2dec('F0000000')]);

crc = uint32(0);
for bit_idx = uint32(0):uint32(4):(uint32(n_bits) - 1)
    nibble = uint32(0);
    for b = 0:3
        nibble = bitor(nibble, bitshift(uint32(bitget(payload_word, double(bit_idx) + b + 1)), b));
    end
    idx = bitxor(bitand(crc, uint32(15)), nibble);
    crc = bitxor(bitshift(crc, -4), table(double(idx) + 1));
end
end
