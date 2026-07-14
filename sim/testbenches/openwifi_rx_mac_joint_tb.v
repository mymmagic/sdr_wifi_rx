`timescale 1ns / 1ps

`include "openofdm_rx_pre_def.v"

module openwifi_rx_mac_joint_tb;
  localparam integer IQ_DATA_WIDTH = 16;
  localparam integer RSSI_HALF_DB_WIDTH = 11;

  reg clk = 1'b0;
  reg rstn = 1'b0;
  reg send_samples = 1'b0;

  always #5 clk = ~clk;

  // IQ injection through rx_intf loopback path. Packing is {q, i}; rx_intf
  // emits sample0 as {i, q}, matching openofdm_rx sample_in.
  reg [31:0] iq0_from_tx_intf = 32'd0;
  reg [31:0] iq1_from_tx_intf = 32'd0;
  reg iq_valid_from_tx_intf = 1'b0;

  wire [31:0] sample0;
  wire [31:0] sample1;
  wire sample_strobe;

  wire signed [RSSI_HALF_DB_WIDTH-1:0] xpu_rssi_half_db;
  wire signed [RSSI_HALF_DB_WIDTH-1:0] rssi_half_db_lock_by_sig_valid;
  wire [7:0] gpio_status_lock_by_sig_valid;
  wire [63:0] tsf_runtime_val;
  wire tsf_pulse_1M;

  wire demod_is_ongoing;
  wire short_preamble_detected;
  wire long_preamble_detected;
  wire pkt_header_valid;
  wire pkt_header_valid_strobe;
  wire ht_unsupport;
  wire [7:0] pkt_rate;
  wire [15:0] pkt_len;
  wire ht_aggr;
  wire ht_aggr_last;
  wire ht_sgi;
  wire byte_out_strobe;
  wire [7:0] byte_out;
  wire [15:0] byte_count;
  wire fcs_out_strobe;
  wire fcs_ok;
  wire [31:0] csi;
  wire csi_valid;
  wire signed [31:0] phase_offset_taken;
  wire [31:0] equalizer;
  wire equalizer_valid;
  wire ofdm_symbol_eq_out_pulse;
  wire [14:0] n_ofdm_sym;
  wire [9:0] n_bit_in_last_sym;
  wire phy_len_valid;

  wire mute_adc_out_to_bb;
  wire block_rx_dma_to_ps;
  wire block_rx_dma_to_ps_valid;

  wire [79:0] tx_status;
  wire [47:0] mac_addr;
  wire retrans_in_progress;
  wire start_retrans;
  wire start_tx_ack;
  wire tx_try_complete;
  wire [3:0] slice_en;
  wire backoff_done;
  wire tx_bb_is_ongoing;
  wire tx_rf_is_ongoing;
  wire ack_tx_flag;
  wire wea;
  wire [9:0] addra;
  wire [63:0] dina;
  wire [3:0] band;
  wire [15:0] channel;
  wire [3:0] tx_control_state;
  wire tx_control_state_idle;
  wire [9:0] num_slot_random;
  wire [3:0] cw;
  wire [31:0] FC_DI;
  wire FC_DI_valid;
  wire [47:0] addr1;
  wire addr1_valid;
  wire [47:0] addr2;
  wire addr2_valid;
  wire [47:0] addr3;
  wire addr3_valid;
  wire pkt_for_me;
  wire ch_idle_final;
  wire spi_sclk;
  wire spi_csn;
  wire spi_mosi;

  wire rx_pkt_intr;
  wire fcs_ok_led;
  wire [7:0] gpio_status_bb;
  wire [7:0] gpio_status_bb_raw;
  wire m00_axis_tvalid;
  wire [63:0] m00_axis_tdata;
  wire [7:0] m00_axis_tstrb;
  wire m00_axis_tlast;

  // AXI-lite signals: openofdm_rx
  reg [6:0] phy_awaddr = 7'd0;
  reg [2:0] phy_awprot = 3'd0;
  reg phy_awvalid = 1'b0;
  wire phy_awready;
  reg [31:0] phy_wdata = 32'd0;
  reg [3:0] phy_wstrb = 4'hf;
  reg phy_wvalid = 1'b0;
  wire phy_wready;
  wire [1:0] phy_bresp;
  wire phy_bvalid;
  reg phy_bready = 1'b0;
  reg [6:0] phy_araddr = 7'd0;
  reg [2:0] phy_arprot = 3'd0;
  reg phy_arvalid = 1'b0;
  wire phy_arready;
  wire [31:0] phy_rdata;
  wire [1:0] phy_rresp;
  wire phy_rvalid;
  reg phy_rready = 1'b0;

  // AXI-lite signals: xpu
  reg [7:0] xpu_awaddr = 8'd0;
  reg [2:0] xpu_awprot = 3'd0;
  reg xpu_awvalid = 1'b0;
  wire xpu_awready;
  reg [31:0] xpu_wdata = 32'd0;
  reg [3:0] xpu_wstrb = 4'hf;
  reg xpu_wvalid = 1'b0;
  wire xpu_wready;
  wire [1:0] xpu_bresp;
  wire xpu_bvalid;
  reg xpu_bready = 1'b0;
  reg [7:0] xpu_araddr = 8'd0;
  reg [2:0] xpu_arprot = 3'd0;
  reg xpu_arvalid = 1'b0;
  wire xpu_arready;
  wire [31:0] xpu_rdata;
  wire [1:0] xpu_rresp;
  wire xpu_rvalid;
  reg xpu_rready = 1'b0;

  // AXI-lite signals: rx_intf
  reg [6:0] rxi_awaddr = 7'd0;
  reg [2:0] rxi_awprot = 3'd0;
  reg rxi_awvalid = 1'b0;
  wire rxi_awready;
  reg [31:0] rxi_wdata = 32'd0;
  reg [3:0] rxi_wstrb = 4'hf;
  reg rxi_wvalid = 1'b0;
  wire rxi_wready;
  wire [1:0] rxi_bresp;
  wire rxi_bvalid;
  reg rxi_bready = 1'b0;
  reg [6:0] rxi_araddr = 7'd0;
  reg [2:0] rxi_arprot = 3'd0;
  reg rxi_arvalid = 1'b0;
  wire rxi_arready;
  wire [31:0] rxi_rdata;
  wire [1:0] rxi_rresp;
  wire rxi_rvalid;
  reg rxi_rready = 1'b0;

  openofdm_rx openofdm_rx_i (
    .trigger_mode_setting_en(1'b0),
    .para_valid(1'b0),
    .para_rx_sensitivity_th({(RSSI_HALF_DB_WIDTH-1){1'b0}}),
    .rssi_half_db(xpu_rssi_half_db),
    .sample_in(sample0),
    .sample_in_strobe(sample_strobe),
    .Fc_in_MHz(16'd5220),
    .demod_is_ongoing(demod_is_ongoing),
    .short_preamble_detected(short_preamble_detected),
    .long_preamble_detected(long_preamble_detected),
    .pkt_header_valid(pkt_header_valid),
    .pkt_header_valid_strobe(pkt_header_valid_strobe),
    .ht_unsupport(ht_unsupport),
    .pkt_rate(pkt_rate),
    .pkt_len(pkt_len),
    .ht_aggr(ht_aggr),
    .ht_aggr_last(ht_aggr_last),
    .ht_sgi(ht_sgi),
    .byte_out_strobe(byte_out_strobe),
    .byte_out(byte_out),
    .byte_count(byte_count),
    .fcs_out_strobe(fcs_out_strobe),
    .fcs_ok(fcs_ok),
    .csi(csi),
    .csi_valid(csi_valid),
    .phase_offset_taken(phase_offset_taken),
    .equalizer(equalizer),
    .equalizer_valid(equalizer_valid),
    .ofdm_symbol_eq_out_pulse(ofdm_symbol_eq_out_pulse),
    .n_ofdm_sym(n_ofdm_sym),
    .n_bit_in_last_sym(n_bit_in_last_sym),
    .phy_len_valid(phy_len_valid),
    .s00_axi_aclk(clk),
    .s00_axi_aresetn(rstn),
    .s00_axi_awaddr(phy_awaddr),
    .s00_axi_awprot(phy_awprot),
    .s00_axi_awvalid(phy_awvalid),
    .s00_axi_awready(phy_awready),
    .s00_axi_wdata(phy_wdata),
    .s00_axi_wstrb(phy_wstrb),
    .s00_axi_wvalid(phy_wvalid),
    .s00_axi_wready(phy_wready),
    .s00_axi_bresp(phy_bresp),
    .s00_axi_bvalid(phy_bvalid),
    .s00_axi_bready(phy_bready),
    .s00_axi_araddr(phy_araddr),
    .s00_axi_arprot(phy_arprot),
    .s00_axi_arvalid(phy_arvalid),
    .s00_axi_arready(phy_arready),
    .s00_axi_rdata(phy_rdata),
    .s00_axi_rresp(phy_rresp),
    .s00_axi_rvalid(phy_rvalid),
    .s00_axi_rready(phy_rready)
  );

  xpu xpu_i (
    .gpio_status(8'h80),
    .ddc_i(sample0[31:16]),
    .ddc_q(sample0[15:0]),
    .ddc_iq_valid(sample_strobe),
    .mute_adc_out_to_bb(mute_adc_out_to_bb),
    .block_rx_dma_to_ps(block_rx_dma_to_ps),
    .block_rx_dma_to_ps_valid(block_rx_dma_to_ps_valid),
    .rssi_half_db_lock_by_sig_valid(rssi_half_db_lock_by_sig_valid),
    .gpio_status_lock_by_sig_valid(gpio_status_lock_by_sig_valid),
    .tsf_runtime_val(tsf_runtime_val),
    .tsf_pulse_1M(tsf_pulse_1M),
    .rssi_half_db(xpu_rssi_half_db),
    .demod_is_ongoing(demod_is_ongoing),
    .pkt_header_valid(pkt_header_valid),
    .pkt_header_valid_strobe(pkt_header_valid_strobe),
    .ht_unsupport(ht_unsupport),
    .pkt_rate(pkt_rate),
    .pkt_len(pkt_len),
    .byte_in_strobe(byte_out_strobe),
    .byte_in(byte_out),
    .byte_count(byte_count),
    .fcs_in_strobe(fcs_out_strobe),
    .fcs_ok(fcs_ok),
    .n_ofdm_sym(n_ofdm_sym),
    .n_bit_in_last_sym(n_bit_in_last_sym),
    .phy_len_valid(phy_len_valid),
    .rx_ht_aggr(ht_aggr),
    .rx_ht_aggr_last(ht_aggr_last),
    .demod_is_ongoing_led(),
    .cycle_start0_led(),
    .phy_tx_started_led(),
    .sig_valid_led(),
    .phy_tx_start(1'b0),
    .phy_tx_started(1'b0),
    .phy_tx_done(1'b0),
    .tx_status(tx_status),
    .mac_addr(mac_addr),
    .retrans_in_progress(retrans_in_progress),
    .start_retrans(start_retrans),
    .start_tx_ack(start_tx_ack),
    .tx_try_complete(tx_try_complete),
    .tx_iq_fifo_empty(1'b1),
    .slice_en(slice_en),
    .backoff_done(backoff_done),
    .tx_bb_is_ongoing(tx_bb_is_ongoing),
    .tx_rf_is_ongoing(tx_rf_is_ongoing),
    .ack_tx_flag(ack_tx_flag),
    .wea(wea),
    .addra(addra),
    .dina(dina),
    .tx_pkt_need_ack(1'b0),
    .tx_pkt_retrans_limit(4'd0),
    .tx_ht_aggr(1'b0),
    .douta(64'd0),
    .cts_toself_bb_is_ongoing(1'b0),
    .cts_toself_rf_is_ongoing(1'b0),
    .bram_addr(10'd0),
    .band(band),
    .channel(channel),
    .quit_retrans(1'b0),
    .reset_backoff(1'b0),
    .tx_control_state(tx_control_state),
    .tx_control_state_idle(tx_control_state_idle),
    .num_slot_random(num_slot_random),
    .cw(cw),
    .high_trigger(1'b0),
    .tx_queue_idx(2'd0),
    .FC_DI(FC_DI),
    .FC_DI_valid(FC_DI_valid),
    .addr1(addr1),
    .addr1_valid(addr1_valid),
    .addr2(addr2),
    .addr2_valid(addr2_valid),
    .addr3(addr3),
    .addr3_valid(addr3_valid),
    .pkt_for_me(pkt_for_me),
    .ch_idle_final(ch_idle_final),
    .ps_clk(clk),
    .spi0_sclk(1'b0),
    .spi0_mosi(1'b0),
    .spi0_csn(1'b1),
    .spi_sclk(spi_sclk),
    .spi_csn(spi_csn),
    .spi_mosi(spi_mosi),
    .s00_axi_aclk(clk),
    .s00_axi_aresetn(rstn),
    .s00_axi_awaddr(xpu_awaddr),
    .s00_axi_awprot(xpu_awprot),
    .s00_axi_awvalid(xpu_awvalid),
    .s00_axi_awready(xpu_awready),
    .s00_axi_wdata(xpu_wdata),
    .s00_axi_wstrb(xpu_wstrb),
    .s00_axi_wvalid(xpu_wvalid),
    .s00_axi_wready(xpu_wready),
    .s00_axi_bresp(xpu_bresp),
    .s00_axi_bvalid(xpu_bvalid),
    .s00_axi_bready(xpu_bready),
    .s00_axi_araddr(xpu_araddr),
    .s00_axi_arprot(xpu_arprot),
    .s00_axi_arvalid(xpu_arvalid),
    .s00_axi_arready(xpu_arready),
    .s00_axi_rdata(xpu_rdata),
    .s00_axi_rresp(xpu_rresp),
    .s00_axi_rvalid(xpu_rvalid),
    .s00_axi_rready(xpu_rready)
  );

  rx_intf rx_intf_i (
    .trigger_out0(),
    .trigger_out1(),
    .trigger_out2(),
    .trigger_out3(),
    .trigger_out4(),
    .trigger_out5(),
    .trigger_out6(),
    .trigger_out7(),
    .gpio_status_rf(8'h80),
    .gpio_status_bb(gpio_status_bb),
    .gpio_status_bb_raw(gpio_status_bb_raw),
    .adc_clk(clk),
    .adc_rst(~rstn),
    .adc_data(64'd0),
    .adc_valid(1'b0),
    .iq0_from_tx_intf(iq0_from_tx_intf),
    .iq1_from_tx_intf(iq1_from_tx_intf),
    .iq_valid_from_tx_intf(iq_valid_from_tx_intf),
    .sample0(sample0),
    .sample1(sample1),
    .sample_strobe(sample_strobe),
    .pkt_header_valid(pkt_header_valid),
    .pkt_header_valid_strobe(pkt_header_valid_strobe),
    .ht_unsupport(ht_unsupport),
    .pkt_rate(pkt_rate),
    .pkt_len(pkt_len),
    .ht_aggr(ht_aggr),
    .ht_aggr_last(ht_aggr_last),
    .ht_sgi(ht_sgi),
    .byte_in_strobe(byte_out_strobe),
    .byte_in(byte_out),
    .byte_count(byte_count),
    .fcs_in_strobe(fcs_out_strobe),
    .fcs_ok(fcs_ok),
    .phase_offset_taken(phase_offset_taken),
    .fcs_ok_led(fcs_ok_led),
    .rx_pkt_intr(rx_pkt_intr),
    .s2mm_intr(1'b0),
    .mute_adc_out_to_bb(mute_adc_out_to_bb),
    .block_rx_dma_to_ps(block_rx_dma_to_ps),
    .block_rx_dma_to_ps_valid(block_rx_dma_to_ps_valid),
    .rssi_half_db_lock_by_sig_valid(rssi_half_db_lock_by_sig_valid),
    .gpio_status_lock_by_sig_valid(gpio_status_lock_by_sig_valid),
    .tsf_runtime_val(tsf_runtime_val),
    .tsf_pulse_1M(tsf_pulse_1M),
    .s00_axi_aclk(clk),
    .s00_axi_aresetn(rstn),
    .s00_axi_awaddr(rxi_awaddr),
    .s00_axi_awprot(rxi_awprot),
    .s00_axi_awvalid(rxi_awvalid),
    .s00_axi_awready(rxi_awready),
    .s00_axi_wdata(rxi_wdata),
    .s00_axi_wstrb(rxi_wstrb),
    .s00_axi_wvalid(rxi_wvalid),
    .s00_axi_wready(rxi_wready),
    .s00_axi_bresp(rxi_bresp),
    .s00_axi_bvalid(rxi_bvalid),
    .s00_axi_bready(rxi_bready),
    .s00_axi_araddr(rxi_araddr),
    .s00_axi_arprot(rxi_arprot),
    .s00_axi_arvalid(rxi_arvalid),
    .s00_axi_arready(rxi_arready),
    .s00_axi_rdata(rxi_rdata),
    .s00_axi_rresp(rxi_rresp),
    .s00_axi_rvalid(rxi_rvalid),
    .s00_axi_rready(rxi_rready),
    .m00_axis_aclk(clk),
    .m00_axis_aresetn(rstn),
    .m00_axis_tvalid(m00_axis_tvalid),
    .m00_axis_tdata(m00_axis_tdata),
    .m00_axis_tstrb(m00_axis_tstrb),
    .m00_axis_tlast(m00_axis_tlast),
    .m00_axis_tready(1'b1)
  );

  task automatic phy_axi_write(input [6:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      phy_awaddr <= addr;
      phy_wdata <= data;
      phy_awvalid <= 1'b1;
      phy_wvalid <= 1'b1;
      phy_bready <= 1'b1;
      wait (phy_awready && phy_wready);
      @(posedge clk);
      phy_awvalid <= 1'b0;
      phy_wvalid <= 1'b0;
      wait (phy_bvalid);
      @(posedge clk);
      phy_bready <= 1'b0;
    end
  endtask

  task automatic xpu_axi_write(input [7:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      xpu_awaddr <= addr;
      xpu_wdata <= data;
      xpu_awvalid <= 1'b1;
      xpu_wvalid <= 1'b1;
      xpu_bready <= 1'b1;
      wait (xpu_awready && xpu_wready);
      @(posedge clk);
      xpu_awvalid <= 1'b0;
      xpu_wvalid <= 1'b0;
      wait (xpu_bvalid);
      @(posedge clk);
      xpu_bready <= 1'b0;
    end
  endtask

  task automatic rxi_axi_write(input [6:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      rxi_awaddr <= addr;
      rxi_wdata <= data;
      rxi_awvalid <= 1'b1;
      rxi_wvalid <= 1'b1;
      rxi_bready <= 1'b1;
      wait (rxi_awready && rxi_wready);
      @(posedge clk);
      rxi_awvalid <= 1'b0;
      rxi_wvalid <= 1'b0;
      wait (rxi_bvalid);
      @(posedge clk);
      rxi_bready <= 1'b0;
    end
  endtask

  integer iq_sample_file;
  integer result;
  integer file_i;
  integer file_q;
  integer dummy;
  integer parse_count;
  reg [100*8-1:0] line;
  reg [2:0] clk_count = 3'd0;
  integer iq_count = 0;
  integer eof_drain_count = 0;
  reg run_out_of_iq_sample = 1'b0;

  integer event_fd;
  integer byte_fd;
  integer phy_bits_fd;
  integer demod_fd;
  integer ctrl_fd;
  integer axis_fd;
  integer summary_fd;
  integer sample_name_fd;
  reg [8*1024-1:0] sample_file_runtime;

  integer phy_header_cnt = 0;
  integer ht_unsupport_cnt = 0;
  integer phy_byte_cnt = 0;
  integer fcs_cnt = 0;
  integer fcs_ok_cnt = 0;
  integer fc_cnt = 0;
  integer addr1_cnt = 0;
  integer addr2_cnt = 0;
  integer addr3_cnt = 0;
  integer filter_valid_cnt = 0;
  integer filter_pass_cnt = 0;
  integer filter_block_cnt = 0;
  integer axis_word_cnt = 0;
  integer axis_tlast_cnt = 0;
  integer rxi_sig_valid_cnt = 0;
  integer demod_data_count = 0;
  reg [2:0] last_rxi_state = 3'b111;

  initial begin
    event_fd = $fopen("rx_mac_joint_events.csv", "w");
    $fwrite(event_fd, "time_ns,iq_count,event,phy_state,rxi_state,rate,len,byte_count,byte,fc_di,addr1,addr2,addr3,block,block_valid,m_axis_data,m_axis_last,rxi_sig_valid,rxi_reg5,rxi_reg6,rxi_start,rxi_start_m_axis,rxi_monitor_words,rxi_axis_words\n");
    byte_fd = $fopen("rx_mac_joint_bytes.csv", "w");
    $fwrite(byte_fd, "time_ns,iq_count,byte_count,byte\n");
    phy_bits_fd = $fopen("rx_mac_joint_phy_bits.csv", "w");
    $fwrite(phy_bits_fd, "time_ns,iq_count,state,deinter_count,deinter_stb,deinter_erase,deinter_bits,conv_stb,conv_bit,descr_stb,descr_bit,bit_stb,bit,byte_stb,byte_count,byte\n");
    demod_fd = $fopen("rx_mac_joint_demod.csv", "w");
    $fwrite(demod_fd, "time_ns,iq_count,data_demod_idx,data_symbol,carrier_idx,state,num_ofdm_symbol,demod_out,demod_soft_bits,cons_i_delayed,cons_q_delayed,abs_cons_i,abs_cons_q,bits_raw,bits_delay1,bits_delay2,csi_addr,csi_llr\n");
    ctrl_fd = $fopen("rx_mac_joint_ctrl.csv", "w");
    $fwrite(ctrl_fd, "time_ns,iq_count,state,old_state,num_ofdm_symbol,ht_ready,ofdm_in_stb,eq_out_stb_delayed,ofdm_symbol_eq_out_pulse,rate,len,num_bits_to_decode,n_ofdm_sym,n_bit_in_last_sym,deinter_decode_limit,deinter_count,demod_stb,deinter_stb,conv_in_stb,conv_in_stb_dly,vit_valid,conv_stb,descr_stb,bit_stb,byte_stb,byte_count,byte,fcs_stb,fcs_ok\n");
    axis_fd = $fopen("rx_mac_joint_m_axis.csv", "w");
    $fwrite(axis_fd, "time_ns,word_index,tdata,tlast,tstrb\n");
    if (!$value$plusargs("SAMPLE_FILE=%s", sample_file_runtime)) begin
      sample_file_runtime = `SAMPLE_FILE;
    end

    sample_name_fd = $fopen("rx_mac_joint_sample_file.txt", "w");
    $fwrite(sample_name_fd, "%0s\n", sample_file_runtime);
    $fclose(sample_name_fd);

    iq_sample_file = $fopen(sample_file_runtime, "r");
    if (iq_sample_file == 0) begin
      $display("RX_MAC_JOINT_ERROR cannot open SAMPLE_FILE");
      $finish;
    end

    repeat (20) @(posedge clk);
    rstn <= 1'b1;
    repeat (20) @(posedge clk);

    // Match the standalone PHY RX configuration used in the validated run.
    phy_axi_write(7'd1 << 2, 32'h0000_0001); // force HT smoothing
    phy_axi_write(7'd2 << 2, 32'h0040_0000); // watchdog DC threshold
    phy_axi_write(7'd3 << 2, 32'd100);       // min plateau
    phy_axi_write(7'd4 << 2, 32'h06A4_E001); // max/min len and soft decoding
    phy_axi_write(7'd5 << 2, 32'h0000_0304); // small EQ threshold and FFT window shift
    phy_axi_write(7'd18 << 2, 32'd22);       // phase offset abs threshold

    // Low-MAC pass-all monitor mode, ACK TX disabled for this RX-only sim.
    xpu_axi_write(8'd5 << 2, 32'hFFFF_0000); // max SIGNAL length threshold
    xpu_axi_write(8'd11 << 2, 32'h0000_0030); // disable ACK TX/RX behavior
    xpu_axi_write(8'd27 << 2, 32'h0000_2000); // MONITOR_ALL

    // Use rx_intf loopback injection and let M_AXIS count come from packet length.
    rxi_axi_write(7'd3 << 2, 32'h0000_0100); // iq_from_tx_intf select
    rxi_axi_write(7'd5 << 2, 32'h0000_0025); // mode 101: header insert + filter-gated start, use monitor count
    rxi_axi_write(7'd6 << 2, 32'hFFFF_0000); // max SIGNAL length threshold
    rxi_axi_write(7'd12 << 2, 32'h8000_0000); // disable zero-timeout M_AXIS auto recover in this TB

    repeat (20) @(posedge clk);
    send_samples <= 1'b1;
  end

  always @(posedge clk) begin
    if (!rstn || !send_samples) begin
      iq_valid_from_tx_intf <= 1'b0;
      iq0_from_tx_intf <= 32'd0;
      iq1_from_tx_intf <= 32'd0;
      clk_count <= 3'd0;
    end else if (!run_out_of_iq_sample) begin
      if (clk_count == 3'd4) begin
        result = $fgets(line, iq_sample_file);
        if (result == 0) begin
          run_out_of_iq_sample <= 1'b1;
          iq_valid_from_tx_intf <= 1'b0;
        end else begin
          parse_count = $sscanf(line, "%d %d %d", file_i, file_q, dummy);
          if (parse_count < 2) begin
            result = $fgets(line, iq_sample_file);
            parse_count = $sscanf(line, "%d %d %d", file_i, file_q, dummy);
          end
          iq0_from_tx_intf <= {file_q[15:0], file_i[15:0]};
          iq1_from_tx_intf <= 32'd0;
          iq_valid_from_tx_intf <= 1'b1;
          iq_count <= iq_count + 1;
        end
        clk_count <= 3'd0;
      end else begin
        iq_valid_from_tx_intf <= 1'b0;
        clk_count <= clk_count + 1'b1;
      end
    end else begin
      iq_valid_from_tx_intf <= 1'b0;
      eof_drain_count <= eof_drain_count + 1;
      if (eof_drain_count == 3000) begin
        summary_fd = $fopen("rx_mac_joint_summary.txt", "w");
        $fwrite(summary_fd, "phy_header_cnt %0d\n", phy_header_cnt);
        $fwrite(summary_fd, "ht_unsupport_cnt %0d\n", ht_unsupport_cnt);
        $fwrite(summary_fd, "phy_byte_cnt %0d\n", phy_byte_cnt);
        $fwrite(summary_fd, "fcs_cnt %0d\n", fcs_cnt);
        $fwrite(summary_fd, "fcs_ok_cnt %0d\n", fcs_ok_cnt);
        $fwrite(summary_fd, "fc_cnt %0d\n", fc_cnt);
        $fwrite(summary_fd, "addr1_cnt %0d\n", addr1_cnt);
        $fwrite(summary_fd, "addr2_cnt %0d\n", addr2_cnt);
        $fwrite(summary_fd, "addr3_cnt %0d\n", addr3_cnt);
        $fwrite(summary_fd, "filter_valid_cnt %0d\n", filter_valid_cnt);
        $fwrite(summary_fd, "filter_pass_cnt %0d\n", filter_pass_cnt);
        $fwrite(summary_fd, "filter_block_cnt %0d\n", filter_block_cnt);
        $fwrite(summary_fd, "axis_word_cnt %0d\n", axis_word_cnt);
        $fwrite(summary_fd, "axis_tlast_cnt %0d\n", axis_tlast_cnt);
        $fwrite(summary_fd, "rxi_sig_valid_cnt %0d\n", rxi_sig_valid_cnt);
        $fwrite(summary_fd, "rxi_slv_reg5 %08x\n", rx_intf_i.slv_reg5);
        $fwrite(summary_fd, "rxi_slv_reg6 %08x\n", rx_intf_i.slv_reg6);
        $fwrite(summary_fd, "rxi_final_state %0d\n", rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state);
        $fwrite(summary_fd, "rxi_monitor_words %0d\n", rx_intf_i.monitor_num_dma_symbol_to_ps);
        $fwrite(summary_fd, "rxi_num_dma_words %0d\n", rx_intf_i.num_dma_symbol_to_ps);
        if (fcs_ok_cnt > 0 && fc_cnt > 0 && filter_pass_cnt > 0 && axis_word_cnt > 0 && axis_tlast_cnt > 0) begin
          $fwrite(summary_fd, "status PASS\n");
          $display("RX_MAC_JOINT_PASS");
        end else begin
          $fwrite(summary_fd, "status FAIL\n");
          $display("RX_MAC_JOINT_FAIL");
        end
        $fclose(summary_fd);
        $finish;
      end
    end
  end

  always @(posedge clk) begin
    if (rstn) begin
      if (pkt_header_valid_strobe) begin
        phy_header_cnt <= phy_header_cnt + 1;
        if (ht_unsupport) begin
          ht_unsupport_cnt <= ht_unsupport_cnt + 1;
        end
        $fwrite(event_fd, "%0t,%0d,phy_header,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (byte_out_strobe) begin
        phy_byte_cnt <= phy_byte_cnt + 1;
        $fwrite(byte_fd, "%0t,%0d,%0d,%02x\n", $time, iq_count, byte_count, byte_out);
      end

      if (openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinterleave_erase_out_strobe ||
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_decoder_out_stb ||
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.descramble_out_strobe ||
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.bit_in_stb ||
          byte_out_strobe) begin
        $fwrite(phy_bits_fd, "%0t,%0d,%0d,%0d,%0d,%0d,%02x,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%02x\n",
          $time, iq_count, openofdm_rx_i.state,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinter_out_count,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinterleave_erase_out_strobe,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinterleave_erase_out[7:6],
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinterleave_erase_out[5:0],
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_decoder_out_stb,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_decoder_out,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.descramble_out_strobe,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.descramble_out,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.bit_in_stb,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.bit_in,
          byte_out_strobe, byte_count, byte_out);
      end

      if (openofdm_rx_i.state == 5'd12 &&
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_out_strobe) begin
        $fwrite(demod_fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%02x,%05x,%0d,%0d,%0d,%0d,%02x,%02x,%02x,%0d,%0d\n",
          $time, iq_count, demod_data_count, (demod_data_count/52), (demod_data_count%52),
          openofdm_rx_i.state,
          openofdm_rx_i.dot11_i.num_ofdm_symbol,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_out,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_soft_bits,
          $signed(openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.cons_i_delayed),
          $signed(openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.cons_q_delayed),
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.abs_cons_i,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.abs_cons_q,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.bits,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.bits_delay1,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.bits_delay2,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.csi_square_over_noise_var_read_addr,
          $signed(openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_inst.csi_square_over_noise_var_for_llr));
        demod_data_count <= demod_data_count + 1;
      end

      if (openofdm_rx_i.state == 5'd12 ||
          openofdm_rx_i.state == 5'd13 ||
          openofdm_rx_i.state == 5'd16 ||
          openofdm_rx_i.dot11_i.ofdm_in_stb ||
          openofdm_rx_i.dot11_i.eq_out_stb_delayed ||
          openofdm_rx_i.dot11_i.ofdm_symbol_eq_out_pulse ||
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_out_strobe ||
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinterleave_erase_out_strobe ||
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_decoder_out_stb ||
          byte_out_strobe ||
          fcs_out_strobe) begin
        $fwrite(ctrl_fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%02x,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%02x,%0d,%0d\n",
          $time, iq_count,
          openofdm_rx_i.state,
          openofdm_rx_i.dot11_i.old_state,
          openofdm_rx_i.dot11_i.num_ofdm_symbol,
          openofdm_rx_i.dot11_i.ht_data_decoder_ready,
          openofdm_rx_i.dot11_i.ofdm_in_stb,
          openofdm_rx_i.dot11_i.eq_out_stb_delayed,
          openofdm_rx_i.dot11_i.ofdm_symbol_eq_out_pulse,
          pkt_rate, pkt_len,
          openofdm_rx_i.dot11_i.num_bits_to_decode,
          n_ofdm_sym,
          n_bit_in_last_sym,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinter_decode_limit,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinter_out_count,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.demod_out_strobe,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.deinterleave_erase_out_strobe,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_in_stb,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_in_stb_dly,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.m_axis_data_tvalid,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.conv_decoder_out_stb,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.descramble_out_strobe,
          openofdm_rx_i.dot11_i.ofdm_decoder_inst.bit_in_stb,
          byte_out_strobe, byte_count, byte_out,
          fcs_out_strobe, fcs_ok);
      end

      if (FC_DI_valid) begin
        fc_cnt <= fc_cnt + 1;
        $fwrite(event_fd, "%0t,%0d,fc_di,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (addr1_valid) begin
        addr1_cnt <= addr1_cnt + 1;
        $fwrite(event_fd, "%0t,%0d,addr1,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (addr2_valid) begin
        addr2_cnt <= addr2_cnt + 1;
      end
      if (addr3_valid) begin
        addr3_cnt <= addr3_cnt + 1;
      end

      if (block_rx_dma_to_ps_valid) begin
        filter_valid_cnt <= filter_valid_cnt + 1;
        if (block_rx_dma_to_ps) begin
          filter_block_cnt <= filter_block_cnt + 1;
        end else begin
          filter_pass_cnt <= filter_pass_cnt + 1;
        end
        $fwrite(event_fd, "%0t,%0d,filter,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (fcs_out_strobe) begin
        fcs_cnt <= fcs_cnt + 1;
        if (fcs_ok) begin
          fcs_ok_cnt <= fcs_ok_cnt + 1;
        end
        $fwrite(event_fd, "%0t,%0d,fcs,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (rx_intf_i.sig_valid) begin
        rxi_sig_valid_cnt <= rxi_sig_valid_cnt + 1;
        $fwrite(event_fd, "%0t,%0d,rxi_sig,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state != last_rxi_state) begin
        last_rxi_state <= rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state;
        $fwrite(event_fd, "%0t,%0d,rxi_state,%0d,%0d,%02x,%0d,%0d,%02x,%08x,%012x,%012x,%012x,%0d,%0d,%016x,%0d,%0d,%08x,%08x,%0d,%0d,%0d,%0d\n",
          $time, iq_count, openofdm_rx_i.state, rx_intf_i.rx_intf_pl_to_m_axis_i.rx_state,
          pkt_rate, pkt_len, byte_count, byte_out, FC_DI, addr1, addr2, addr3,
          block_rx_dma_to_ps, block_rx_dma_to_ps_valid, m00_axis_tdata, m00_axis_tlast,
          rx_intf_i.sig_valid, rx_intf_i.slv_reg5, rx_intf_i.slv_reg6,
          rx_intf_i.start_1trans_from_acc_to_m_axis,
          rx_intf_i.rx_intf_pl_to_m_axis_i.start_m_axis,
          rx_intf_i.monitor_num_dma_symbol_to_ps, rx_intf_i.num_dma_symbol_to_ps);
      end

      if (m00_axis_tvalid) begin
        $fwrite(axis_fd, "%0t,%0d,%016x,%0d,%02x\n",
          $time, axis_word_cnt, m00_axis_tdata, m00_axis_tlast, m00_axis_tstrb);
        axis_word_cnt <= axis_word_cnt + 1;
        if (m00_axis_tlast) begin
          axis_tlast_cnt <= axis_tlast_cnt + 1;
        end
      end

      $fflush(event_fd);
      $fflush(byte_fd);
      $fflush(ctrl_fd);
      $fflush(axis_fd);
    end
  end
endmodule
