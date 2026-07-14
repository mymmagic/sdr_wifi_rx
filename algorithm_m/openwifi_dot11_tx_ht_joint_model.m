function joint = openwifi_dot11_tx_ht_joint_model(mcs, psdu_len_bytes, payload_word)
%OPENWIFI_DOT11_TX_HT_JOINT_MODEL HT TX chain model up to dot11_tx.ifft_iq.
%
% Scenario: mixed-mode HT packet with L-SIG plus two HT-SIG OFDM symbols.
% HT_AGGR=0 and S_GI=0 are used in the generated HT-SIG word.

if nargin < 1 || isempty(mcs)
    mcs = 0;
end
if nargin < 2 || isempty(psdu_len_bytes)
    psdu_len_bytes = 8;
end
if nargin < 3 || isempty(payload_word)
    payload_word = bitor(uint64(hex2dec('89ABCDEF')), bitshift(uint64(hex2dec('01234567')), 32));
end

[DATA_RATE, DATA_N_BPSC, DATA_N_DBPS, mcs_name] = ht_mcs_cfg(mcs);

L_SIG_RATE = bin2dec('01011');
L_SIG_N_BPSC = 1;
L_SIG_N_DBPS = 24;
HT_SIG_RATE = L_SIG_RATE;
HT_SIG_N_BPSC = 1;
HT_SIG_N_DBPS = 24;

num_data_symbols = ceil((16 + double(psdu_len_bytes) * 8 + 6) / DATA_N_DBPS);
NUM_SYMBOLS = 3 + num_data_symbols;

init_data_scram_state = uint8(bin2dec('1011101'));
init_pilot_scram_state = uint8(bin2dec('1011101'));
psdu_len_bytes = uint64(psdu_len_bytes);
psdu_bit_len = uint32(psdu_len_bytes * 8);
payload_word = uint64(payload_word);

bram_words = zeros(16, 1, 'uint64');
bram_words(1) = bitor(uint64(bin2dec('1011')), bitor(bitshift(psdu_len_bytes, 5), bitshift(uint64(1), 24)));
bram_words(2) = bitor(uint64(mcs), bitshift(psdu_len_bytes, 8));
bram_words(3) = payload_word;

l_sig_bits = word_bits(bram_words(1), L_SIG_N_DBPS);
ht_sig_bits = word_bits(bram_words(2), 48);

scram_rows = openwifi_dot11_scrambler_model(init_data_scram_state, payload_word, psdu_bit_len, uint32(DATA_N_DBPS));
data_bits = uint8([scram_rows.bit_scram].');
if numel(data_bits) < num_data_symbols * DATA_N_DBPS
    error('Expected at least %d DATA bits, got %d.', num_data_symbols * DATA_N_DBPS, numel(data_bits));
end
data_bits = data_bits(1:(num_data_symbols * DATA_N_DBPS));

l_sig_enc = openwifi_convenc_model(l_sig_bits, true(L_SIG_N_DBPS, 1), false(L_SIG_N_DBPS, 1));
ht_sig1_enc = openwifi_convenc_model(ht_sig_bits(1:24), true(24, 1), false(24, 1));
ht_sig2_enc = openwifi_convenc_model(ht_sig_bits(25:48), true(24, 1), false(24, 1));
data_enc = openwifi_convenc_model(data_bits, true(numel(data_bits), 1), false(numel(data_bits), 1));
pilot = ht_pilot_map(init_pilot_scram_state, NUM_SYMBOLS);

max_dbps = max([L_SIG_N_DBPS, HT_SIG_N_DBPS, DATA_N_DBPS]);
joint.num_symbols = NUM_SYMBOLS;
joint.num_data_symbols = num_data_symbols;
joint.mcs = uint8(mcs);
joint.rate_code = uint8(DATA_RATE);
joint.rate_name = mcs_name;
joint.n_bpsc = DATA_N_BPSC;
joint.n_dbps = DATA_N_DBPS;
joint.psdu_len_bytes = psdu_len_bytes;
joint.payload_word = payload_word;
joint.bram_words = bram_words;
joint.ifft_iq = zeros(NUM_SYMBOLS, 64, 'uint32');
joint.mod_addr = zeros(NUM_SYMBOLS, 64, 'uint8');
joint.bits_to_mod = zeros(NUM_SYMBOLS, 64, 'uint8');
joint.kind = zeros(NUM_SYMBOLS, 64, 'uint8'); % 0 zero, 1 pilot, 2 data
joint.symbol_input_bits = zeros(NUM_SYMBOLS, max_dbps, 'uint8');
joint.encoded_pairs = zeros(NUM_SYMBOLS, max_dbps, 2, 'uint8');

for sym = 1:NUM_SYMBOLS
    if sym == 1
        bits = l_sig_bits;
        enc = l_sig_enc;
        sym_rate = L_SIG_RATE;
        sym_n_bpsc = L_SIG_N_BPSC;
        sym_n_dbps = L_SIG_N_DBPS;
        sym_mode = 'legacy_sig';
    elseif sym == 2
        bits = ht_sig_bits(1:24);
        enc = ht_sig1_enc;
        sym_rate = HT_SIG_RATE;
        sym_n_bpsc = HT_SIG_N_BPSC;
        sym_n_dbps = HT_SIG_N_DBPS;
        sym_mode = 'ht_sig';
    elseif sym == 3
        bits = ht_sig_bits(25:48);
        enc = ht_sig2_enc;
        sym_rate = HT_SIG_RATE;
        sym_n_bpsc = HT_SIG_N_BPSC;
        sym_n_dbps = HT_SIG_N_DBPS;
        sym_mode = 'ht_sig';
    else
        lo = (sym - 4) * DATA_N_DBPS + 1;
        hi = (sym - 3) * DATA_N_DBPS;
        bits = data_bits(lo:hi);
        enc = data_enc(lo:hi, :);
        sym_rate = DATA_RATE;
        sym_n_bpsc = DATA_N_BPSC;
        sym_n_dbps = DATA_N_DBPS;
        sym_mode = 'ht_data';
    end

    joint.symbol_input_bits(sym, 1:numel(bits)) = bits;
    joint.encoded_pairs(sym, 1:size(enc, 1), :) = uint8(enc);

    ram = zeros(52 * 8, 1, 'uint8');
    for idx = 0:(sym_n_dbps - 1)
        [idx_o, punc_o] = openwifi_punc_interlv_model(sym_rate, idx);
        high_addr = idx_o(1, 1);
        low_addr = idx_o(1, 2);
        high_punc = punc_o(1, 1);
        low_punc = punc_o(1, 2);

        if low_punc == 0
            ram(double(low_addr) + 1) = uint8(enc(idx + 1, 2));
        end
        if high_punc == 0
            ram(double(high_addr) + 1) = uint8(enc(idx + 1, 1));
        end
    end

    for iq_cnt = 0:63
        [kind, word, raddr, bits_in] = expected_ht_iq_word(iq_cnt, ram, pilot, sym, sym_n_bpsc, sym_mode);
        joint.kind(sym, iq_cnt + 1) = kind;
        joint.ifft_iq(sym, iq_cnt + 1) = word;
        joint.mod_addr(sym, iq_cnt + 1) = uint8(raddr);
        joint.bits_to_mod(sym, iq_cnt + 1) = uint8(bits_in);
    end
end
end

function bits = word_bits(word, n)
bits = zeros(n, 1, 'uint8');
for k = 1:n
    bits(k) = uint8(bitget(word, k));
end
end

function [rate_code, n_bpsc, n_dbps, mcs_name] = ht_mcs_cfg(mcs)
switch double(mcs)
    case 0
        rate_code = bin2dec('10000'); n_bpsc = 1; n_dbps = 26;  mcs_name = 'MCS0';
    case 1
        rate_code = bin2dec('10001'); n_bpsc = 2; n_dbps = 52;  mcs_name = 'MCS1';
    case 2
        rate_code = bin2dec('10010'); n_bpsc = 2; n_dbps = 78;  mcs_name = 'MCS2';
    case 3
        rate_code = bin2dec('10011'); n_bpsc = 4; n_dbps = 104; mcs_name = 'MCS3';
    case 4
        rate_code = bin2dec('10100'); n_bpsc = 4; n_dbps = 156; mcs_name = 'MCS4';
    case 5
        rate_code = bin2dec('10101'); n_bpsc = 6; n_dbps = 208; mcs_name = 'MCS5';
    case 6
        rate_code = bin2dec('10110'); n_bpsc = 6; n_dbps = 234; mcs_name = 'MCS6';
    case 7
        rate_code = bin2dec('10111'); n_bpsc = 6; n_dbps = 260; mcs_name = 'MCS7';
    otherwise
        error('Unsupported HT MCS: %d.', mcs);
end
end

function [kind, word, raddr, bits_in] = expected_ht_iq_word(iq_cnt, ram, pilot, sym, n_bpsc, sym_mode)
raddr = uint8(0);
bits_in = uint8(0);
is_ht_data = strcmp(sym_mode, 'ht_data');
is_ht_sig = strcmp(sym_mode, 'ht_sig');

if iq_cnt == 0 || (~is_ht_data && iq_cnt >= 27 && iq_cnt < 38) || (is_ht_data && iq_cnt >= 29 && iq_cnt < 36)
    kind = uint8(0);
    word = uint32(0);
elseif iq_cnt == 7
    kind = uint8(1);
    word = pilot.pilot(sym, 3);
elseif iq_cnt == 21
    kind = uint8(1);
    word = pilot.pilot(sym, 4);
elseif iq_cnt == 43
    kind = uint8(1);
    word = pilot.pilot(sym, 1);
elseif iq_cnt == 57
    kind = uint8(1);
    word = pilot.pilot(sym, 2);
else
    kind = uint8(2);
    if is_ht_data
        raddr = uint8(ht_mod_addr(iq_cnt - 1));
    else
        raddr = uint8(legacy_mod_addr(iq_cnt - 1));
    end
    bits_in = ram_simo_read(ram, raddr);
    word = pack_mod_iq(openwifi_tx_modulation_model(n_bpsc, bits_in));
    if is_ht_sig
        word = bitor(bitshift(bitand(word, uint32(65535)), 16), bitshift(word, -16));
    end
end
end

function addr = legacy_mod_addr(prev_iq_cnt)
if prev_iq_cnt < 6
    addr = prev_iq_cnt + 24;
elseif prev_iq_cnt < 20
    addr = prev_iq_cnt + 23;
elseif prev_iq_cnt < 28
    addr = prev_iq_cnt + 22;
elseif prev_iq_cnt < 42
    addr = prev_iq_cnt - 37;
elseif prev_iq_cnt < 56
    addr = prev_iq_cnt - 38;
else
    addr = prev_iq_cnt - 39;
end
end

function addr = ht_mod_addr(prev_iq_cnt)
if prev_iq_cnt < 6
    addr = prev_iq_cnt + 26;
elseif prev_iq_cnt < 20
    addr = prev_iq_cnt + 25;
elseif prev_iq_cnt < 28
    addr = prev_iq_cnt + 24;
elseif prev_iq_cnt < 42
    addr = prev_iq_cnt - 35;
elseif prev_iq_cnt < 56
    addr = prev_iq_cnt - 36;
else
    addr = prev_iq_cnt - 37;
end
end

function bits = ram_simo_read(ram, raddr)
bits = uint8(0);
base = double(raddr) * 8;
for lane = 0:5
    bits = bits + uint8(ram(base + lane + 1)) * uint8(2^lane);
end
end

function word = pack_mod_iq(iq)
i = uint32(typecast(int16(iq(1)), 'uint16'));
q = uint32(typecast(int16(iq(2)), 'uint16'));
word = bitor(bitshift(i, 16), q);
end

function model = ht_pilot_map(init_pilot_state, num_symbols)
state = uint8(init_pilot_state);
ht_polarity = uint8(bin2dec('1000'));
model.pilot = zeros(num_symbols, 4, 'uint32');
model.state_after = zeros(num_symbols, 1, 'uint8');
model.pilot_gain = zeros(num_symbols, 1, 'uint8');

pos = uint32(hex2dec('40000000'));
neg = uint32(hex2dec('C0000000'));

for sym = 1:num_symbols
    gain = uint8(xor(bitget(state, 7), bitget(state, 4)));
    model.pilot_gain(sym) = gain;
    if sym > 3
        for p = 0:3
            if xor(bitget(ht_polarity, p + 1), gain) == 0
                model.pilot(sym, p + 1) = pos;
            else
                model.pilot(sym, p + 1) = neg;
            end
        end
        ht_polarity = rotate_ht_polarity(ht_polarity);
    else
        if gain == 0
            model.pilot(sym, :) = [pos, pos, pos, neg];
        else
            model.pilot(sym, :) = [neg, neg, neg, pos];
        end
    end
    state = scrambler_advance(state);
    model.state_after(sym) = state;
end
end

function y = rotate_ht_polarity(x)
y = uint8(0);
y = bitset(y, 1, bitget(x, 2));
y = bitset(y, 2, bitget(x, 3));
y = bitset(y, 3, bitget(x, 4));
y = bitset(y, 4, bitget(x, 1));
end

function next_state = scrambler_advance(state)
tap = uint16(xor(bitget(state, 7), bitget(state, 4)));
next_state = uint8(bitand(bitshift(uint16(bitand(state, 63)), 1) + tap, 127));
end
