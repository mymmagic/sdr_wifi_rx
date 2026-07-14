function verify_openofdm_rx_demodulate_model()
%VERIFY_OPENOFDM_RX_DEMODULATE_MODEL Generate vectors for demodulate.v.

out_dir = fileparts(mfilename('fullpath'));

% rate, I, Q. Rates cover legacy BPSK/QPSK/16QAM/64QAM and one HT case.
cases = [ ...
    11,   500,     0;  ... % legacy 6M BPSK
    11,  -500,     0;  ...
    10,   300,  -300;  ... % legacy 12M QPSK
    10,  -300,   300;  ...
     9,   500,   700;  ... % legacy 24M 16QAM
     9,  -900,  -100;  ...
     8,   200,   900;  ... % legacy 48M 64QAM
     8,  -600,  -400;  ...
     8,  -900,   100;  ...
   131,   500,  -500];     % HT MCS3, 16QAM

n = size(cases, 1);
rate_words = zeros(n, 1, 'uint8');
i_words = zeros(n, 1, 'uint16');
q_words = zeros(n, 1, 'uint16');
expected_bits = zeros(n, 1, 'uint8');

for k = 1:n
    rate = uint8(cases(k, 1));
    i = int16(cases(k, 2));
    q = int16(cases(k, 3));
    rate_words(k) = rate;
    i_words(k) = typecast(i, 'uint16');
    q_words(k) = typecast(q, 'uint16');
    expected_bits(k) = uint8(demod_bits(rate, i, q));
end

write_hex8(fullfile(out_dir, 'openofdm_demodulate_rate.hex'), rate_words);
write_hex16(fullfile(out_dir, 'openofdm_demodulate_i.hex'), i_words);
write_hex16(fullfile(out_dir, 'openofdm_demodulate_q.hex'), q_words);
write_hex8(fullfile(out_dir, 'openofdm_demodulate_expected.hex'), expected_bits);

fid = fopen(fullfile(out_dir, 'openofdm_demodulate_count.txt'), 'w');
fprintf(fid, '%d\n', n);
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_demodulate_model_trace.csv'), 'w');
fprintf(fid, 'idx,rate,input_i,input_q,expected_bits\n');
for k = 1:n
    fprintf(fid, '%d,%d,%d,%d,%02x\n', k-1, cases(k, 1), cases(k, 2), cases(k, 3), expected_bits(k));
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_demodulate_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX demodulate reverse model\n');
fprintf(fid, 'CONS_SCALE_SHIFT=10 MAX=1024 QAM16_DIV=682 QAM64_DIV=[292,585,877]\n');
fprintf(fid, 'bits are hard-decision fields packed in bits[5:0].\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX demodulate vectors to: %s\n', out_dir);
end

function bits = demod_bits(rate, i, q)
MAX = 2^10;
QAM_16_DIV = floor(MAX*2/3);
QAM_64_DIV_0 = floor(MAX*2/7);
QAM_64_DIV_1 = floor(MAX*4/7);
QAM_64_DIV_2 = floor(MAX*6/7);

mod_type = rate_to_mod(rate);
ai = abs16(i);
aq = abs16(q);
si = double(i >= 0);
sq = double(q >= 0);
bits = 0;

switch mod_type
    case 1 % BPSK
        bits = si;
    case 2 % QPSK
        bits = si + 2*sq;
    case 3 % 16QAM
        bits = si + 2*double(ai < QAM_16_DIV) + ...
            4*sq + 8*double(aq < QAM_16_DIV);
    case 4 % 64QAM
        bits = si + 2*double(ai < QAM_64_DIV_1) + ...
            4*double(ai > QAM_64_DIV_0 && ai < QAM_64_DIV_2) + ...
            8*sq + 16*double(aq < QAM_64_DIV_1) + ...
            32*double(aq > QAM_64_DIV_0 && aq < QAM_64_DIV_2);
end
end

function mod_type = rate_to_mod(rate)
key = bitor(bitshift(bitget(rate, 8), 4), bitand(rate, 15));
switch key
    case {bin2dec('01011'), bin2dec('01111'), bin2dec('10000')}
        mod_type = 1;
    case {bin2dec('01010'), bin2dec('01110'), bin2dec('10001'), bin2dec('10010')}
        mod_type = 2;
    case {bin2dec('01001'), bin2dec('01101'), bin2dec('10011'), bin2dec('10100')}
        mod_type = 3;
    otherwise
        mod_type = 4;
end
end

function y = abs16(x)
raw = typecast(int16(x), 'uint16');
if bitget(raw, 16)
    y = double(mod(double(bitcmp(raw)) + 1, 65536));
else
    y = double(raw);
end
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end

function write_hex16(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%04x\n', values(k));
end
fclose(fid);
end
