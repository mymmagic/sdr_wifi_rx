function trace = openofdm_rx_moving_avg_model(x, data_width, window_shift)
%OPENOFDM_RX_MOVING_AVG_MODEL Cycle model of openofdm moving_avg.v.
% Models the registered RAM read latency used for old_data.

window_size = 2^window_shift;
scale = 2^window_shift;

addr = 0;
full = 0;
running_sum = 0;
ram = zeros(window_size, 1);
dob = 0;

n = numel(x);
trace = struct( ...
    'idx', num2cell(zeros(n, 1)), ...
    'input', num2cell(zeros(n, 1)), ...
    'old_data_used', num2cell(zeros(n, 1)), ...
    'running_sum_before', num2cell(zeros(n, 1)), ...
    'data_out', num2cell(zeros(n, 1)), ...
    'output_strobe', num2cell(zeros(n, 1)), ...
    'addr', num2cell(zeros(n, 1)), ...
    'full', num2cell(zeros(n, 1)));

for idx = 1:n
    new_data = double(x(idx));
    old_data = dob;
    old_sum = running_sum;
    old_full = full;
    old_addr = addr;

    data_out = floor(old_sum / scale);
    output_strobe = old_full;

    if old_full
        running_sum = running_sum + new_data - old_data;
    else
        running_sum = running_sum + new_data;
    end

    if old_addr == window_size - 1
        full = 1;
    end

    ram_old = ram(old_addr + 1);
    ram(old_addr + 1) = new_data;
    dob = ram_old;
    addr = mod(old_addr + 1, window_size);

    trace(idx).idx = idx - 1;
    trace(idx).input = new_data;
    trace(idx).old_data_used = old_data;
    trace(idx).running_sum_before = old_sum;
    trace(idx).data_out = wrap_signed(data_out, data_width);
    trace(idx).output_strobe = output_strobe;
    trace(idx).addr = old_addr;
    trace(idx).full = old_full;
end
end

function y = wrap_signed(x, width)
modulus = 2^width;
u = mod(x, modulus);
if u >= 2^(width-1)
    y = u - modulus;
else
    y = u;
end
end
