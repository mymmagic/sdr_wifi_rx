function joint = openwifi_dot11_tx_joint_model(rate_nibble, psdu_len_bytes, payload_word)
%OPENWIFI_DOT11_TX_JOINT_MODEL TX PHY chain model up to dot11_tx.ifft_iq.
%
% Legacy packet model. In this openwifi TX path, LENGTH includes the 32-bit
% FCS that the RTL appends internally.

if nargin < 1 || isempty(rate_nibble)
    rate_nibble = bin2dec('1011');
end
if nargin < 2 || isempty(psdu_len_bytes)
    psdu_len_bytes = 8;
end
if nargin < 3 || isempty(payload_word)
    payload_word = bitor(uint64(hex2dec('89ABCDEF')), bitshift(uint64(hex2dec('01234567')), 32));
end

[RATE, N_BPSC, N_DBPS, rate_name] = legacy_rate_cfg(rate_nibble);
num_data_symbols = ceil((16 + double(psdu_len_bytes) * 8 + 6) / N_DBPS);
NUM_SYMBOLS = 1 + num_data_symbols;

init_data_scram_state = uint8(bin2dec('1011101'));
init_pilot_scram_state = uint8(bin2dec('1011101'));
psdu_len_bytes = uint64(psdu_len_bytes);
psdu_bit_len = uint32(psdu_len_bytes * 8);
payload_word = uint64(payload_word);

bram_words = zeros(16, 1, 'uint64');
bram_words(1) = bitor(uint64(rate_nibble), bitshift(psdu_len_bytes, 5));
bram_words(2) = uint64(0);
bram_words(3) = payload_word;

L_SIG_RATE = bin2dec('01011');
L_SIG_N_BPSC = 1;
L_SIG_N_DBPS = 24;

l_sig_bits = zeros(L_SIG_N_DBPS, 1, 'uint8');
for k = 1:L_SIG_N_DBPS
    l_sig_bits(k) = uint8(bitget(bram_words(1), k));
end

scram_rows = openwifi_dot11_scrambler_model(init_data_scram_state, payload_word, psdu_bit_len, uint32(N_DBPS));
data_bits = uint8([scram_rows.bit_scram].');
if numel(data_bits) < num_data_symbols * N_DBPS
    error('Expected at least %d DATA bits, got %d.', num_data_symbols * N_DBPS, numel(data_bits));
end
data_bits = data_bits(1:(num_data_symbols * N_DBPS));

l_sig_enc = openwifi_convenc_model(l_sig_bits, true(L_SIG_N_DBPS, 1), false(L_SIG_N_DBPS, 1));
data_enc = openwifi_convenc_model(data_bits, true(numel(data_bits), 1), false(numel(data_bits), 1));
pilot = openwifi_dot11_pilot_map_model(init_pilot_scram_state, NUM_SYMBOLS);

max_dbps = max(N_DBPS, L_SIG_N_DBPS);
joint.num_symbols = NUM_SYMBOLS;
joint.num_data_symbols = num_data_symbols;
joint.rate_nibble = uint8(rate_nibble);
joint.rate_code = uint8(RATE);
joint.rate_name = rate_name;
joint.n_bpsc = N_BPSC;
joint.n_dbps = N_DBPS;
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
    else
        lo = (sym - 2) * N_DBPS + 1;
        hi = (sym - 1) * N_DBPS;
        bits = data_bits(lo:hi);
        enc = data_enc(lo:hi, :);
        sym_rate = RATE;
        sym_n_bpsc = N_BPSC;
        sym_n_dbps = N_DBPS;
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
        [kind, word, raddr, bits_in] = expected_iq_word(iq_cnt, ram, pilot, sym, sym_n_bpsc);
        joint.kind(sym, iq_cnt + 1) = kind;
        joint.ifft_iq(sym, iq_cnt + 1) = word;
        joint.mod_addr(sym, iq_cnt + 1) = uint8(raddr);
        joint.bits_to_mod(sym, iq_cnt + 1) = uint8(bits_in);
    end
end
end

function [rate_code, n_bpsc, n_dbps, rate_name] = legacy_rate_cfg(rate_nibble)
switch double(rate_nibble)
    case bin2dec('1011')
        rate_code = bin2dec('01011'); n_bpsc = 1; n_dbps = 24;  rate_name = '6M';
    case bin2dec('1111')
        rate_code = bin2dec('01111'); n_bpsc = 1; n_dbps = 36;  rate_name = '9M';
    case bin2dec('1010')
        rate_code = bin2dec('01010'); n_bpsc = 2; n_dbps = 48;  rate_name = '12M';
    case bin2dec('1110')
        rate_code = bin2dec('01110'); n_bpsc = 2; n_dbps = 72;  rate_name = '18M';
    case bin2dec('1001')
        rate_code = bin2dec('01001'); n_bpsc = 4; n_dbps = 96;  rate_name = '24M';
    case bin2dec('1101')
        rate_code = bin2dec('01101'); n_bpsc = 4; n_dbps = 144; rate_name = '36M';
    case bin2dec('1000')
        rate_code = bin2dec('01000'); n_bpsc = 6; n_dbps = 192; rate_name = '48M';
    case bin2dec('1100')
        rate_code = bin2dec('01100'); n_bpsc = 6; n_dbps = 216; rate_name = '54M';
    otherwise
        error('Unsupported legacy rate nibble: %d.', rate_nibble);
end
end

function [kind, word, raddr, bits_in] = expected_iq_word(iq_cnt, ram, pilot, sym, n_bpsc)
raddr = uint8(0);
bits_in = uint8(0);

if iq_cnt == 0 || (iq_cnt >= 27 && iq_cnt < 38)
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
    raddr = uint8(legacy_mod_addr(iq_cnt - 1));
    bits_in = ram_simo_read(ram, raddr);
    word = pack_mod_iq(openwifi_tx_modulation_model(n_bpsc, bits_in));
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
