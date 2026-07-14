function model = openwifi_dot11_pilot_map_model(init_pilot_state, num_symbols)
%OPENWIFI_DOT11_PILOT_MAP_MODEL Reverse model for dot11_tx pilot/DC mapping.
%
% This models the legacy/non-HT pilot branch in dot11_tx.v. Pilot words are
% [I,Q] packed as {I[15:0], Q[15:0]}.

init_pilot_state = uint8(init_pilot_state);
num_symbols = double(num_symbols);

state = init_pilot_state;
model.pilot = zeros(num_symbols, 4, 'uint32');
model.state_before = zeros(num_symbols, 1, 'uint8');
model.state_after = zeros(num_symbols, 1, 'uint8');
model.pilot_gain = zeros(num_symbols, 1, 'uint8');

pos = uint32(hex2dec('40000000'));
neg = uint32(hex2dec('C0000000'));

for k = 1:num_symbols
    gain = uint8(xor(bitget(state, 7), bitget(state, 4)));
    model.state_before(k) = state;
    model.pilot_gain(k) = gain;
    if gain == 0
        model.pilot(k, :) = [pos, pos, pos, neg];
    else
        model.pilot(k, :) = [neg, neg, neg, pos];
    end
    state = scrambler_advance(state);
    model.state_after(k) = state;
end
end

function next_state = scrambler_advance(state)
tap = uint16(xor(bitget(state, 7), bitget(state, 4)));
next_state = uint8(bitand(bitshift(uint16(bitand(state, 63)), 1) + tap, 127));
end
