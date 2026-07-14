function trace = openofdm_rx_delay_sample_model(x, delay_shift)
%OPENOFDM_RX_DELAY_SAMPLE_MODEL Cycle model of openofdm delay_sample.v.

delay_size = 2^delay_shift;
addr = 0;
full = 0;
ram = zeros(delay_size, 1);

n = numel(x);
trace = struct( ...
    'idx', num2cell(zeros(n, 1)), ...
    'input', num2cell(zeros(n, 1)), ...
    'addr', num2cell(zeros(n, 1)), ...
    'full', num2cell(zeros(n, 1)), ...
    'data_out', num2cell(zeros(n, 1)), ...
    'output_strobe', num2cell(zeros(n, 1)));

for idx = 1:n
    old_addr = addr;
    old_full = full;
    old_value = ram(old_addr + 1);

    trace(idx).idx = idx - 1;
    trace(idx).input = x(idx);
    trace(idx).addr = old_addr;
    trace(idx).full = old_full;
    trace(idx).data_out = old_value;
    trace(idx).output_strobe = old_full;

    ram(old_addr + 1) = x(idx);
    if old_addr == delay_size - 1
        full = 1;
    end
    addr = mod(old_addr + 1, delay_size);
end
end
