function verify_openofdm_rx_top_nodes()
% Verify official dot11_tb source-simulation nodes produced under sim_out.

outdir = fileparts(mfilename('fullpath'));
simdir = fullfile(outdir, 'openofdm_rx_src', 'verilog', 'sim_out');

long_det = read_two_col(fullfile(simdir, 'sync_long_frame_detected.txt'));
long_events = long_det(long_det(:, 2) == 1, 1);
assert(numel(long_events) == 2, 'expected 2 long-preamble detections, got %d', numel(long_events));
assert(all(abs(long_events(:) - [7887; 65362]) <= 0), 'unexpected long detection times');

sig = parse_signal(fullfile(simdir, 'signal_out.txt'));
assert(numel(sig) == 2, 'expected 2 SIGNAL records, got %d', numel(sig));
assert(strcmp(sig(1).rate, '1001') && sig(1).length == 138 && sig(1).parity == 1, 'bad first SIGNAL');
assert(strcmp(sig(2).rate, '1001') && sig(2).length == 111 && sig(2).parity == 0, 'bad second SIGNAL');

sync_long_out = read_iq(fullfile(simdir, 'sync_long_out.txt'));
eq_out = read_iq(fullfile(simdir, 'equalizer_out.txt'));
assert(size(sync_long_out, 1) == 1369, 'unexpected sync_long_out count');
assert(size(eq_out, 1) == 816, 'unexpected equalizer_out count');
assert(mod(size(eq_out, 1), 48) == 0, 'equalizer_out should be whole 48-carrier legacy symbols');

demod_count = count_lines(fullfile(simdir, 'demod_out.txt'));
deinter_count = count_lines(fullfile(simdir, 'deinterleave_out.txt'));
conv_count = count_lines(fullfile(simdir, 'conv_out.txt'));
descr_count = count_lines(fullfile(simdir, 'descramble_out.txt'));
byte_count = count_lines(fullfile(simdir, 'byte_out.txt'));
assert(demod_count == 720, 'unexpected demod_out count');
assert(deinter_count == 1385, 'unexpected deinterleave_out count');
assert(conv_count == 1248, 'unexpected conv_out count');
assert(descr_count == 1233, 'unexpected descramble_out count');
assert(byte_count == 151, 'unexpected byte_out count');

bytes = read_hex_bytes(fullfile(simdir, 'byte_out.txt'));
expected_prefix = uint8(hex2dec({'88','42','2c','00','e4','90','7e','15','2a','16','e8','de','27','90','6e','42'}));
assert(isequal(bytes(1:numel(expected_prefix)), expected_prefix(:)), 'byte_out prefix mismatch');

metric = read_two_col(fullfile(simdir, 'sync_long_metric.txt'));
[max_metric, max_idx] = max(metric(:, 2));
assert(max_metric > 10000000, 'sync_long metric peak too small');

summary_path = fullfile(outdir, 'openofdm_rx_top_node_summary.txt');
fid = fopen(summary_path, 'w');
assert(fid >= 0, 'could not write summary');
fprintf(fid, 'long_events=%s\n', mat2str(long_events(:).'));
fprintf(fid, 'signal_lengths=[%d %d]\n', sig(1).length, sig(2).length);
fprintf(fid, 'sync_long_out=%d\n', size(sync_long_out, 1));
fprintf(fid, 'equalizer_out=%d symbols=%d\n', size(eq_out, 1), size(eq_out, 1) / 48);
fprintf(fid, 'demod=%d deinterleave=%d conv=%d descramble=%d bytes=%d\n', ...
    demod_count, deinter_count, conv_count, descr_count, byte_count);
fprintf(fid, 'sync_long_metric_max=%d at_time=%d\n', max_metric, metric(max_idx, 1));
fprintf(fid, 'byte_prefix=%s\n', sprintf('%02x ', bytes(1:numel(expected_prefix))));
fclose(fid);

fprintf('RX_TOP_NODE long_events=%s\n', mat2str(long_events(:).'));
fprintf('RX_TOP_NODE SIGNAL rate=%s lengths=[%d %d]\n', sig(1).rate, sig(1).length, sig(2).length);
fprintf('RX_TOP_NODE sync_long_out=%d equalizer_out=%d legacy_symbols=%d\n', ...
    size(sync_long_out, 1), size(eq_out, 1), size(eq_out, 1) / 48);
fprintf('RX_TOP_NODE demod=%d deinterleave=%d conv=%d descramble=%d bytes=%d\n', ...
    demod_count, deinter_count, conv_count, descr_count, byte_count);
fprintf('RX_TOP_NODE max_sync_long_metric=%d at_time=%d\n', max_metric, metric(max_idx, 1));
fprintf('PASS: openofdm RX official dot11_tb node outputs match expected source-simulation checkpoints.\n');
end

function n = count_lines(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open %s', path);
c = onCleanup(@() fclose(fid));
n = 0;
while ischar(fgetl(fid))
    n = n + 1;
end
end

function data = read_two_col(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open %s', path);
c = onCleanup(@() fclose(fid));
data = fscanf(fid, '%d %d', [2 inf]).';
end

function iq = read_iq(path)
data = read_two_col(path);
iq = data(:, 1) + 1j * data(:, 2);
end

function bytes = read_hex_bytes(path)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open %s', path);
c = onCleanup(@() fclose(fid));
bytes = zeros(0, 1, 'uint8');
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    t = strtrim(t);
    if ~isempty(t)
        bytes(end + 1, 1) = uint8(hex2dec(t)); %#ok<AGROW>
    end
end
end

function sig = parse_signal(path)
txt = fileread(path);
tokens = regexp(txt, '([01]{4})\s+([01])\s+([01]{12})\s+([01])\s+([01]{6})', 'tokens');
sig = struct('rate', {}, 'rsvd', {}, 'length', {}, 'parity', {}, 'tail', {});
for k = 1:numel(tokens)
    t = tokens{k};
    sig(k).rate = t{1}; %#ok<AGROW>
    sig(k).rsvd = str2double(t{2});
    sig(k).length = bin2dec(t{3});
    sig(k).parity = str2double(t{4});
    sig(k).tail = t{5};
end
end
