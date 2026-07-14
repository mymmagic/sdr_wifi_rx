`timescale 1ns / 1ps

// Renamed copy of the calibrated OpenOFDM RX AXI-Stream Viterbi behavior
// model. It lets the Vivado-2024 wrapper keep the licensed Xilinx IP
// instantiated in parallel while driving the legacy-latency data path used by
// the original OpenOFDM control FSM.
module viterbi_v7_0_axis_behav_core (
  input         aclk,
  input         aresetn,
  input         aclken,
  input  [15:0] s_axis_data_tdata,
  input  [7:0]  s_axis_data_tuser,
  input         s_axis_data_tvalid,
  output        s_axis_data_tready,
  output reg [7:0] m_axis_data_tdata,
  output reg       m_axis_data_tvalid
);
  localparam integer NUM_STATES = 64;
  localparam integer HISTORY = 256;
  localparam integer TRACEBACK_LENGTH = 84;
  localparam integer OUTPUT_DELAY = 84;
  localparam [15:0] METRIC_MAX = 16'h7fff;
  localparam [6:0] G0 = 7'b1011011;
  localparam [6:0] G1 = 7'b1111001;

  reg [15:0] metric [0:NUM_STATES-1];
  reg [15:0] next_metric [0:NUM_STATES-1];
  reg [5:0]  prev_state_mem [0:HISTORY-1][0:NUM_STATES-1];
  reg        input_bit_mem [0:HISTORY-1][0:NUM_STATES-1];
  reg [5:0]  next_prev_state [0:NUM_STATES-1];
  reg        next_input_bit [0:NUM_STATES-1];

  reg [15:0] step_count;
  reg [5:0] best_state;
  reg [5:0] trace_state;
  reg [5:0] ns;
  reg [15:0] cand_metric;
  reg [15:0] best_metric;
  reg [7:0] branch_metric;
  reg exp0;
  reg exp1;
  reg decoded_bit;

  integer i;
  integer prev;
  integer bitv;
  integer tb;
  integer wr_idx;
  integer rd_idx;

  wire [2:0] sym0 = s_axis_data_tdata[2:0];
  wire [2:0] sym1 = s_axis_data_tdata[10:8];
  wire [1:0] erase = s_axis_data_tuser[1:0];
  wire in_fire = aresetn & aclken & s_axis_data_tvalid;

  assign s_axis_data_tready = aresetn & aclken;

  function parity7;
    input [6:0] v;
    begin
      parity7 = ^v;
    end
  endfunction

  function enc0;
    input in_bit;
    input [5:0] st;
    reg [6:0] shift_reg;
    begin
      shift_reg = {in_bit, st};
      enc0 = parity7(shift_reg & G0);
    end
  endfunction

  function enc1;
    input in_bit;
    input [5:0] st;
    reg [6:0] shift_reg;
    begin
      shift_reg = {in_bit, st};
      enc1 = parity7(shift_reg & G1);
    end
  endfunction

  function [3:0] offset_binary_distance;
    input [2:0] sym;
    input expected;
    input erased;
    begin
      if (erased) begin
        offset_binary_distance = 4'd0;
      end else if (expected) begin
        offset_binary_distance = {1'b0, (3'd7 - sym)};
      end else begin
        offset_binary_distance = {1'b0, sym};
      end
    end
  endfunction

  always @(posedge aclk) begin
    if (!aresetn) begin
      for (i = 0; i < NUM_STATES; i = i + 1) begin
        metric[i] <= (i == 0) ? 16'd0 : METRIC_MAX;
        next_metric[i] <= METRIC_MAX;
        next_prev_state[i] <= 6'd0;
        next_input_bit[i] <= 1'b0;
      end
      for (tb = 0; tb < HISTORY; tb = tb + 1) begin
        for (i = 0; i < NUM_STATES; i = i + 1) begin
          prev_state_mem[tb][i] <= 6'd0;
          input_bit_mem[tb][i] <= 1'b0;
        end
      end
      step_count <= 16'd0;
      best_state <= 6'd0;
      trace_state <= 6'd0;
      decoded_bit <= 1'b0;
      m_axis_data_tdata <= 8'd0;
      m_axis_data_tvalid <= 1'b0;
    end else if (aclken) begin
      m_axis_data_tvalid <= 1'b0;

      if (s_axis_data_tvalid) begin
        for (i = 0; i < NUM_STATES; i = i + 1) begin
          next_metric[i] = METRIC_MAX;
          next_prev_state[i] = 6'd0;
          next_input_bit[i] = 1'b0;
        end

        for (prev = 0; prev < NUM_STATES; prev = prev + 1) begin
          if (metric[prev] != METRIC_MAX) begin
            for (bitv = 0; bitv < 2; bitv = bitv + 1) begin
              ns = {bitv[0], prev[5:1]};
              exp0 = enc0(bitv[0], prev[5:0]);
              exp1 = enc1(bitv[0], prev[5:0]);
              branch_metric = offset_binary_distance(sym0, exp0, erase[0]) +
                              offset_binary_distance(sym1, exp1, erase[1]);
              cand_metric = metric[prev] + branch_metric;
              if (cand_metric < next_metric[ns]) begin
                next_metric[ns] = cand_metric;
                next_prev_state[ns] = prev[5:0];
                next_input_bit[ns] = bitv[0];
              end
            end
          end
        end

        wr_idx = step_count % HISTORY;
        best_metric = METRIC_MAX;
        best_state = 6'd0;
        for (i = 0; i < NUM_STATES; i = i + 1) begin
          metric[i] <= next_metric[i];
          prev_state_mem[wr_idx][i] = next_prev_state[i];
          input_bit_mem[wr_idx][i] = next_input_bit[i];
          if (next_metric[i] < best_metric) begin
            best_metric = next_metric[i];
            best_state = i[5:0];
          end
        end

        trace_state = best_state;
        for (tb = 0; tb < TRACEBACK_LENGTH - 1; tb = tb + 1) begin
          rd_idx = (step_count + HISTORY - tb) % HISTORY;
          trace_state = prev_state_mem[rd_idx][trace_state];
        end
        rd_idx = (step_count + HISTORY - (TRACEBACK_LENGTH - 1)) % HISTORY;
        decoded_bit = input_bit_mem[rd_idx][trace_state];

        step_count <= step_count + 16'd1;
        if (step_count >= OUTPUT_DELAY - 1) begin
          m_axis_data_tdata <= {7'd0, decoded_bit};
          m_axis_data_tvalid <= in_fire;
        end
      end
    end
  end
endmodule
