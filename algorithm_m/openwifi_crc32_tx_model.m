function [crc_out, idx_used] = openwifi_crc32_tx_model(data_in, crc_en, rst)
%OPENWIFI_CRC32_TX_MODEL MATLAB model of openofdm_tx crc32_tx.v.

data_in = uint32(data_in(:));
crc_en = logical(crc_en(:));
rst = logical(rst(:));

n = max([numel(data_in), numel(crc_en), numel(rst)]);
data_in = expand_scalar(data_in, n);
crc_en = expand_scalar(crc_en, n);
rst = expand_scalar(rst, n);

table = uint32([ ...
    hex2dec('4DBDF21C'), hex2dec('500AE278'), hex2dec('76D3D2D4'), hex2dec('6B64C2B0'), ...
    hex2dec('3B61B38C'), hex2dec('26D6A3E8'), hex2dec('000F9344'), hex2dec('1DB88320'), ...
    hex2dec('A005713C'), hex2dec('BDB26158'), hex2dec('9B6B51F4'), hex2dec('86DC4190'), ...
    hex2dec('D6D930AC'), hex2dec('CB6E20C8'), hex2dec('EDB71064'), hex2dec('F0000000')]);

state = uint32(0);
crc_out = zeros(n, 1, 'uint32');
idx_used = zeros(n, 1, 'uint32');

for k = 1:n
    idx = bitxor(bitand(state, uint32(15)), bitand(data_in(k), uint32(15)));
    idx_used(k) = idx;

    if rst(k)
        state = uint32(0);
    elseif crc_en(k)
        state = bitxor(bitshift(state, -4), table(double(idx) + 1));
    end

    crc_out(k) = state;
end
end

function y = expand_scalar(x, n)
if numel(x) == 1
    y = repmat(x, n, 1);
elseif numel(x) == n
    y = x;
else
    error('Inputs must be scalar-compatible vectors.');
end
end
