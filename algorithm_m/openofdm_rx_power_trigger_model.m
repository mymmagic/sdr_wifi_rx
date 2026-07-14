function trace = openofdm_rx_power_trigger_model(i_values, power_thres, window_size, skip_samples)
%OPENOFDM_RX_POWER_TRIGGER_MODEL Reverse model of openofdm power_trigger.v.
% The RTL compares the registered abs(I) from the previous accepted sample.

S_SKIP = 0;
S_IDLE = 1;
S_PACKET = 2;

state = S_SKIP;
sample_count = 0;
trigger = 0;
abs_i_reg = 0;

n = numel(i_values);
trace = struct( ...
    'idx', num2cell(zeros(n, 1)), ...
    'input_i', num2cell(zeros(n, 1)), ...
    'abs_i_next', num2cell(zeros(n, 1)), ...
    'abs_i_used', num2cell(zeros(n, 1)), ...
    'state', num2cell(zeros(n, 1)), ...
    'sample_count', num2cell(zeros(n, 1)), ...
    'trigger', num2cell(zeros(n, 1)));

for idx = 1:n
    old_state = state;
    old_count = sample_count;
    old_abs_i = abs_i_reg;
    next_abs_i = abs16(i_values(idx));

    switch old_state
        case S_SKIP
            if old_count > skip_samples
                state = S_IDLE;
            else
                sample_count = old_count + 1;
            end

        case S_IDLE
            if old_abs_i > power_thres
                trigger = 1;
                sample_count = 0;
                state = S_PACKET;
            end

        case S_PACKET
            if old_abs_i < power_thres
                if old_count > window_size
                    trigger = 0;
                    state = S_IDLE;
                else
                    sample_count = old_count + 1;
                end
            else
                sample_count = 0;
            end
    end

    abs_i_reg = next_abs_i;

    trace(idx).idx = idx - 1;
    trace(idx).input_i = i_values(idx);
    trace(idx).abs_i_next = next_abs_i;
    trace(idx).abs_i_used = old_abs_i;
    trace(idx).state = state;
    trace(idx).sample_count = sample_count;
    trace(idx).trigger = trigger;
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
