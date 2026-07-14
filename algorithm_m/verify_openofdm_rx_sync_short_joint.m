function verify_openofdm_rx_sync_short_joint()
% High-level reverse check for openofdm RX sync_short.
% This is intentionally algorithm-level: exact cycle timing is verified by
% tb_openofdm_sync_short_joint.v against the source RTL.

outdir = fileparts(mfilename('fullpath'));
sample_path = fullfile(outdir, 'openofdm_rx_src', 'testing_inputs', 'conducted', ...
    'dot11a_24mbps_qos_data_e4_90_7e_15_2a_16_e8_de_27_90_6e_42.txt');

x = read_complex_hex_samples(sample_path, 3000);
delay = 16;
win = 16;
metric = zeros(size(x));
power_avg = zeros(size(x));
pass = false(size(x));

prod = zeros(size(x));
for n = delay + 1:numel(x)
    prod(n) = x(n) * conj(x(n - delay));
end

for n = delay + win:numel(x)
    pseg = prod(n - win + 1:n);
    xseg = x(n - win + 1:n);
    corr = sum(pseg) / win;
    pwr = sum(abs(xseg).^2) / win;
    metric(n) = abs(corr);
    power_avg(n) = pwr;
    pass(n) = metric(n) > 0.75 * power_avg(n);
end

runs = find_runs(pass);
long_runs = runs(runs(:, 2) >= 100, :);
assert(~isempty(long_runs), 'sync_short high-level model did not find a correlation plateau');

first = long_runs(1, :);
fprintf('SYNC_SHORT_MODEL first_plateau_start_sample=%d len=%d metric=%0.2f threshold=%0.2f\n', ...
    first(1) - 1, first(2), metric(first(1)), 0.75 * power_avg(first(1)));
fprintf('SYNC_SHORT_MODEL max_metric=%0.2f at_sample=%d\n', max(metric), find(metric == max(metric), 1) - 1);
fprintf('PASS: openofdm RX sync_short high-level 16-sample autocorrelation model finds the expected plateau.\n');
end

function x = read_complex_hex_samples(path, max_count)
fid = fopen(path, 'r');
assert(fid >= 0, 'could not open sample file: %s', path);
c = onCleanup(@() fclose(fid));
x = complex(zeros(max_count, 1), zeros(max_count, 1));
k = 0;
while k < max_count
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    t = strtrim(t);
    if isempty(t)
        continue;
    end
    u = uint32(hex2dec(t));
    i = typecast(uint16(bitshift(u, -16)), 'int16');
    q = typecast(uint16(bitand(u, uint32(65535))), 'int16');
    k = k + 1;
    x(k) = double(i) + 1j * double(q);
end
x = x(1:k);
end

function runs = find_runs(mask)
runs = zeros(0, 2);
n = 1;
while n <= numel(mask)
    if ~mask(n)
        n = n + 1;
        continue;
    end
    s = n;
    while n <= numel(mask) && mask(n)
        n = n + 1;
    end
    runs(end + 1, :) = [s, n - s]; %#ok<AGROW>
end
end
