function verify_openwifi_dot11_tx_full_stream_model(case_name, pkt_type, rate_or_mcs, psdu_len_bytes)
%VERIFY_OPENWIFI_DOT11_TX_FULL_STREAM_MODEL Generate full result_i/q stream.

if nargin < 1 || isempty(case_name)
    case_name = 'legacy_6M_len8_full';
end
if nargin < 2 || isempty(pkt_type)
    pkt_type = 'legacy';
end
if nargin < 3 || isempty(rate_or_mcs)
    rate_or_mcs = bin2dec('1011');
end
if nargin < 4 || isempty(psdu_len_bytes)
    psdu_len_bytes = 8;
end

out_dir = fileparts(mfilename('fullpath'));
src_dir = 'C:\wifi\openwifi-hw-master\openwifi-hw-master\ip\openofdm_tx\src';

if strcmpi(pkt_type, 'legacy')
    payload_word = legacy_payload_word(rate_or_mcs, psdu_len_bytes);
    joint = openwifi_dot11_tx_joint_model(rate_or_mcs, psdu_len_bytes, payload_word);
    stream_kind = 'legacy';
elseif strcmpi(pkt_type, 'ht')
    payload_word = ht_payload_word(rate_or_mcs, psdu_len_bytes);
    joint = openwifi_dot11_tx_ht_joint_model(rate_or_mcs, psdu_len_bytes, payload_word);
    stream_kind = 'ht';
else
    error('pkt_type must be legacy or ht.');
end

ifft_out = calc_ifft_out(joint, src_dir);
stream = build_stream(joint, ifft_out, stream_kind, src_dir);

write_hex64(fullfile(out_dir, 'dot11_tx_full_bram.hex'), joint.bram_words);
write_hex(fullfile(out_dir, 'dot11_tx_full_expected.hex'), stream.words, 8);
write_hex(fullfile(out_dir, 'dot11_tx_full_expected_kind.hex'), stream.kind, 2);

count_path = fullfile(out_dir, 'dot11_tx_full_expected_count.txt');
fid = fopen(count_path, 'w');
if fid < 0
    error('Could not create %s', count_path);
end
fprintf(fid, '%d\n', numel(stream.words));
fclose(fid);

summary_path = fullfile(out_dir, 'dot11_tx_full_stream_model_summary.txt');
fid = fopen(summary_path, 'w');
if fid < 0
    error('Could not create summary file: %s', summary_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'openwifi dot11_tx full result_i/q stream reverse model\n');
fprintf(fid, 'Case: %s\n', case_name);
fprintf(fid, 'Packet type: %s\n', pkt_type);
fprintf(fid, 'Source RTL top: C:\\wifi\\openwifi-hw-master\\openwifi-hw-master\\ip\\openofdm_tx\\src\\dot11_tx.v\n');
fprintf(fid, 'Payload source word: 0x%016s\n', dec2hex(joint.payload_word, 16));
fprintf(fid, 'OFDM symbols modeled through IFFT: %d\n', joint.num_symbols);
fprintf(fid, 'Expected result_i/q samples: %d\n', numel(stream.words));
fprintf(fid, 'Stream order: legacy STF/LTF ROMs, CP+64-sample OFDM payload; HT also inserts HT-STF/HT-LTF after HT-SIG.\n');

fprintf('Wrote dot11_tx full-stream vectors to: %s\n', out_dir);
end

function payload_word = legacy_payload_word(rate_nibble, psdu_len_bytes)
base = bitor(uint64(hex2dec('89ABCDEF')), bitshift(uint64(hex2dec('01234567')), 32));
tag = bitor(uint64(rate_nibble), bitshift(uint64(psdu_len_bytes), 8));
payload_word = bitxor(base, tag);
end

function payload_word = ht_payload_word(mcs, psdu_len_bytes)
base = bitor(uint64(hex2dec('89ABCDEF')), bitshift(uint64(hex2dec('76543210')), 32));
tag = bitor(uint64(mcs), bitshift(uint64(psdu_len_bytes), 8));
payload_word = bitxor(base, tag);
end

function ifft_out = calc_ifft_out(joint, src_dir)
ifft_out = zeros(joint.num_symbols, 64, 'uint32');
for sym = 1:joint.num_symbols
    frame_in = unpack_iq_words(joint.ifft_iq(sym, :).');
    frame_out = openwifi_ifft64_fixed_model(frame_in, src_dir);
    ifft_out(sym, :) = pack_iq_matrix(frame_out);
end
end

function stream = build_stream(joint, ifft_out, stream_kind, src_dir)
l_stf_rom = read_rom_case(fullfile(src_dir, 'l_stf_rom.v'), 16);
l_ltf_rom = read_rom_case(fullfile(src_dir, 'l_ltf_rom.v'), 160);

words = zeros(0, 1, 'uint32');
kind = zeros(0, 1, 'uint32');

words = [words; repmat(l_stf_rom(:), 10, 1)]; %#ok<AGROW>
kind = [kind; repmat(uint32(1), 160, 1)]; %#ok<AGROW>
words = [words; l_ltf_rom(:)]; %#ok<AGROW>
kind = [kind; repmat(uint32(2), 160, 1)]; %#ok<AGROW>

if strcmpi(stream_kind, 'legacy')
    for sym = 1:joint.num_symbols
        [words, kind] = append_ofdm_symbol(words, kind, ifft_out(sym, :).', uint32(10 + sym));
    end
elseif strcmpi(stream_kind, 'ht')
    ht_stf_rom = read_rom_case(fullfile(src_dir, 'ht_stf_rom.v'), 16);
    ht_ltf_rom = read_rom_case(fullfile(src_dir, 'ht_ltf_rom.v'), 80);

    for sym = 1:3
        [words, kind] = append_ofdm_symbol(words, kind, ifft_out(sym, :).', uint32(10 + sym));
    end

    words = [words; repmat(ht_stf_rom(:), 5, 1)]; %#ok<AGROW>
    kind = [kind; repmat(uint32(3), 80, 1)]; %#ok<AGROW>
    words = [words; ht_ltf_rom(:)]; %#ok<AGROW>
    kind = [kind; repmat(uint32(4), 80, 1)]; %#ok<AGROW>

    for sym = 4:joint.num_symbols
        [words, kind] = append_ofdm_symbol(words, kind, ifft_out(sym, :).', uint32(10 + sym));
    end
else
    error('Unknown stream kind: %s', stream_kind);
end

stream.words = words;
stream.kind = kind;
end

function [words, kind] = append_ofdm_symbol(words, kind, symbol_words, tag)
words = [words; symbol_words(49:64); symbol_words(:)]; %#ok<AGROW>
kind = [kind; repmat(tag, 80, 1)]; %#ok<AGROW>
end

function rom = read_rom_case(path_name, n)
txt = fileread(path_name);
tokens = regexp(txt, '(\d+)\s*:\s*dout\s*=\s*32''h([0-9A-Fa-f]+)', 'tokens');
rom = zeros(n, 1, 'uint32');
for k = 1:numel(tokens)
    idx = str2double(tokens{k}{1});
    if idx >= 0 && idx < n
        rom(idx + 1) = uint32(hex2dec(tokens{k}{2}));
    end
end
end

function iq = unpack_iq_words(words)
iq = zeros(numel(words), 2, 'int32');
for k = 1:numel(words)
    w = uint32(words(k));
    iq(k, 1) = int32(typecast(uint16(bitshift(w, -16)), 'int16'));
    iq(k, 2) = int32(typecast(uint16(bitand(w, uint32(65535))), 'int16'));
end
end

function words = pack_iq_matrix(iq)
words = zeros(size(iq, 1), 1, 'uint32');
for k = 1:size(iq, 1)
    i = uint32(typecast(int16(iq(k, 1)), 'uint16'));
    q = uint32(typecast(int16(iq(k, 2)), 'uint16'));
    words(k) = bitor(bitshift(i, 16), q);
end
end

function write_hex(path_name, words, digits)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
fmt = ['%0', num2str(digits), 'X\n'];
for k = 1:numel(words)
    fprintf(fid, fmt, uint32(words(k)));
end
end

function write_hex64(path_name, words)
fid = fopen(path_name, 'w');
if fid < 0
    error('Could not create %s', path_name);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(words)
    fprintf(fid, '%016s\n', dec2hex(words(k), 16));
end
end
