`timescale 1ns / 1ps

module viterbi_v7_0 (
  input         aclk,
  input         aresetn,
  input         aclken,
  input  [15:0] s_axis_data_tdata,
  input  [7:0]  s_axis_data_tuser,
  input         s_axis_data_tvalid,
  output        s_axis_data_tready,
  output [7:0]  m_axis_data_tdata,
  output        m_axis_data_tvalid
);

  wire core_tready;
  wire [7:0] raw_m_axis_data_tdata;
  wire raw_m_axis_data_tvalid;
  wire [15:0] core_tdata;
  wire [7:0] core_tuser;
  wire [15:0] legacy_tdata;
  wire [7:0] legacy_tuser;
  assign s_axis_data_tready = core_tready;

  function [2:0] offset_binary_to_signed_magnitude;
    input [2:0] sym;
    begin
      offset_binary_to_signed_magnitude =
        (sym <= 3'd3) ? {1'b0, (2'd3 - sym[1:0])} : sym;
    end
  endfunction

`ifdef VITERBI_IP2024_SIGNED_MAG_INPUT
  wire [2:0] raw_sym0 = s_axis_data_tdata[2:0];
  wire [2:0] raw_sym1 = s_axis_data_tdata[10:8];
`ifdef VITERBI_IP2024_SWAP_INPUT_LANES
  wire [2:0] lane_sym0 = raw_sym1;
  wire [2:0] lane_sym1 = raw_sym0;
`else
  wire [2:0] lane_sym0 = raw_sym0;
  wire [2:0] lane_sym1 = raw_sym1;
`endif
`ifdef VITERBI_IP2024_INVERT_SOFT
  wire [2:0] soft_sym0 = 3'd7 - lane_sym0;
  wire [2:0] soft_sym1 = 3'd7 - lane_sym1;
`else
  wire [2:0] soft_sym0 = lane_sym0;
  wire [2:0] soft_sym1 = lane_sym1;
`endif
  assign core_tdata = {
    5'b0, offset_binary_to_signed_magnitude(soft_sym1),
    5'b0, offset_binary_to_signed_magnitude(soft_sym0)
  };
`else
  wire [2:0] raw_sym0 = s_axis_data_tdata[2:0];
  wire [2:0] raw_sym1 = s_axis_data_tdata[10:8];
`ifdef VITERBI_IP2024_SWAP_INPUT_LANES
  wire [2:0] lane_sym0 = raw_sym1;
  wire [2:0] lane_sym1 = raw_sym0;
`else
  wire [2:0] lane_sym0 = raw_sym0;
  wire [2:0] lane_sym1 = raw_sym1;
`endif
`ifdef VITERBI_IP2024_INVERT_SOFT
  wire [2:0] soft_sym0 = 3'd7 - lane_sym0;
  wire [2:0] soft_sym1 = 3'd7 - lane_sym1;
`else
  wire [2:0] soft_sym0 = lane_sym0;
  wire [2:0] soft_sym1 = lane_sym1;
`endif
  assign core_tdata = {5'b0, soft_sym1, 5'b0, soft_sym0};
`endif

`ifdef VITERBI_IP2024_SWAP_INPUT_LANES
  assign core_tuser = {s_axis_data_tuser[7:2], s_axis_data_tuser[0], s_axis_data_tuser[1]};
`else
  assign core_tuser = s_axis_data_tuser;
`endif

  assign legacy_tdata = {5'b0, soft_sym1, 5'b0, soft_sym0};
  assign legacy_tuser = core_tuser;

  viterbi_v7_0_core u_viterbi_v7_0_core (
    .aclk(aclk),
    .aresetn(aresetn),
    .aclken(aclken),
    .s_axis_data_tdata(core_tdata),
    .s_axis_data_tuser(core_tuser),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(core_tready),
    .m_axis_data_tdata(raw_m_axis_data_tdata),
    .m_axis_data_tvalid(raw_m_axis_data_tvalid)
  );

`ifdef VITERBI_IP2024_LEGACY_TIMING_OUTPUT
  wire legacy_core_ready;
  wire legacy_core_bit;
  wire legacy_core_ce = (~aresetn) | (aclken & s_axis_data_tvalid);
  wire [7:0] legacy_m_axis_data_tdata = {7'd0, legacy_core_bit};
  wire legacy_m_axis_data_tvalid = legacy_core_ready & s_axis_data_tvalid;

  viterbi_v7_0_legacy_core legacy_core (
    .clk(aclk),
    .ce(legacy_core_ce),
    .sclr(~aresetn),
    .data_in0(legacy_tdata[2:0]),
    .data_in1(legacy_tdata[10:8]),
    .erase(legacy_tuser[1:0]),
    .rdy(legacy_core_ready),
    .data_out(legacy_core_bit)
  );
`else
  wire [7:0] legacy_m_axis_data_tdata = 8'd0;
  wire legacy_m_axis_data_tvalid = 1'b0;
`endif

`ifdef VITERBI_IP2024_BEHAV_TIMING_OUTPUT
  wire behav_s_axis_data_tready;
  wire [7:0] behav_m_axis_data_tdata;
  wire behav_m_axis_data_tvalid;

  viterbi_v7_0_axis_behav_core behav_core (
    .aclk(aclk),
    .aresetn(aresetn),
    .aclken(aclken),
    .s_axis_data_tdata(legacy_tdata),
    .s_axis_data_tuser(legacy_tuser),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(behav_s_axis_data_tready),
    .m_axis_data_tdata(behav_m_axis_data_tdata),
    .m_axis_data_tvalid(behav_m_axis_data_tvalid)
  );
`else
  wire behav_s_axis_data_tready = 1'b0;
  wire [7:0] behav_m_axis_data_tdata = 8'd0;
  wire behav_m_axis_data_tvalid = 1'b0;
`endif

`ifdef VITERBI_IP2024_INVERT_OUTPUT_BIT
  wire [7:0] raw_m_axis_data_tdata_selected = {raw_m_axis_data_tdata[7:1], ~raw_m_axis_data_tdata[0]};
`else
  wire [7:0] raw_m_axis_data_tdata_selected = raw_m_axis_data_tdata;
`endif

`ifdef VITERBI_IP2024_BEHAV_TIMING_OUTPUT
  assign m_axis_data_tdata = behav_m_axis_data_tdata;
  assign m_axis_data_tvalid = behav_m_axis_data_tvalid;
`else
`ifdef VITERBI_IP2024_LEGACY_TIMING_OUTPUT
  assign m_axis_data_tdata = legacy_m_axis_data_tdata;
  assign m_axis_data_tvalid = legacy_m_axis_data_tvalid;
`else
  assign m_axis_data_tdata = raw_m_axis_data_tdata_selected;
  assign m_axis_data_tvalid = raw_m_axis_data_tvalid;
`endif
`endif

  integer axis_fd;
  initial begin
    axis_fd = $fopen("viterbi_ip2024_axis.csv", "w");
    $fwrite(axis_fd, "time_ns,aresetn,aclken,s_valid,s_ready,s_tdata,s_tuser,m_valid,m_tdata,raw_m_valid,raw_m_tdata,legacy_m_valid,legacy_m_tdata,behav_m_valid,behav_m_tdata\n");
  end

  always @(posedge aclk) begin
    if (s_axis_data_tvalid || m_axis_data_tvalid || raw_m_axis_data_tvalid || legacy_m_axis_data_tvalid || behav_m_axis_data_tvalid || !core_tready) begin
      $fwrite(axis_fd, "%0t,%0d,%0d,%0d,%0d,%04x,%02x,%0d,%02x,%0d,%02x,%0d,%02x,%0d,%02x\n",
              $time, aresetn, aclken, s_axis_data_tvalid, core_tready,
              core_tdata, s_axis_data_tuser, m_axis_data_tvalid,
              m_axis_data_tdata, raw_m_axis_data_tvalid,
              raw_m_axis_data_tdata_selected, legacy_m_axis_data_tvalid,
              legacy_m_axis_data_tdata, behav_m_axis_data_tvalid,
              behav_m_axis_data_tdata);
    end
  end

endmodule
