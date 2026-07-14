function verify_openofdm_rx_descramble_model()
%VERIFY_OPENOFDM_RX_DESCRAMBLE_MODEL Generate vectors for descramble.v.

out_dir = fileparts(mfilename('fullpath'));

in_bits = uint8([1 0 1 1 0 0 1  1 0 1 0 0 1 1 0 1 1 1 0 0 0 1 0 1 1 0 1 0 1 1 0 0]);
[out_bits, trace] = descramble_model(in_bits);

write_hex8(fullfile(out_dir, 'openofdm_descramble_input.hex'), in_bits(:));
write_hex8(fullfile(out_dir, 'openofdm_descramble_expected.hex'), out_bits(:));

fid = fopen(fullfile(out_dir, 'openofdm_descramble_input_count.txt'), 'w');
fprintf(fid, '%d\n', numel(in_bits));
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_descramble_output_count.txt'), 'w');
fprintf(fid, '%d\n', numel(out_bits));
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_descramble_model_trace.csv'), 'w');
fprintf(fid, 'idx,in_bit,state_before,feedback,out_valid,out_bit\n');
for k = 1:numel(trace)
    fprintf(fid, '%d,%d,%02x,%d,%d,%d\n', ...
        trace(k).idx, trace(k).in_bit, trace(k).state_before, ...
        trace(k).feedback, trace(k).out_valid, trace(k).out_bit);
end
fclose(fid);

fid = fopen(fullfile(out_dir, 'openofdm_descramble_model_summary.txt'), 'w');
fprintf(fid, 'OpenOFDM RX descramble reverse model\n');
fprintf(fid, 'first 7 bits initialize state[6:0]; output starts at bit 7.\n');
fprintf(fid, 'feedback=state[6] xor state[3]; out=feedback xor in_bit.\n');
fclose(fid);

fprintf('Wrote OpenOFDM RX descramble vectors to: %s\n', out_dir);
end

function [out_bits, trace] = descramble_model(in_bits)
state = uint8(0);
bit_count = 0;
inited = false;
out_bits = uint8([]);
trace = struct('idx', {}, 'in_bit', {}, 'state_before', {}, 'feedback', {}, 'out_valid', {}, 'out_bit', {});

for idx = 1:numel(in_bits)
    b = uint8(in_bits(idx) ~= 0);
    state_before = state;
    feedback = bitxor(bitget(state, 7), bitget(state, 4));
    out_valid = 0;
    out_bit = 0;

    if ~inited
        if b
            state = bitset(state, 7 - bit_count, 1);
        else
            state = bitset(state, 7 - bit_count, 0);
        end
        if bit_count == 6
            bit_count = 0;
            inited = true;
        else
            bit_count = bit_count + 1;
        end
    else
        out_bit = bitxor(feedback, b);
        out_valid = 1;
        out_bits(end+1) = uint8(out_bit); %#ok<AGROW>
        state = uint8(bitand(bitshift(state, 1), 127) + feedback);
    end

    trace(end+1) = struct('idx', idx-1, 'in_bit', b, 'state_before', state_before, ...
        'feedback', feedback, 'out_valid', out_valid, 'out_bit', out_bit); %#ok<AGROW>
end
end

function write_hex8(path, values)
fid = fopen(path, 'w');
for k = 1:numel(values)
    fprintf(fid, '%02x\n', values(k));
end
fclose(fid);
end
