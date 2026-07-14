`timescale 1 ns / 1 ps

`ifndef TX_MEM_FILE
`define TX_MEM_FILE "ht_tx_intf_mem_mcs7_gi1_aggr0_byte100.mem"
`endif
`ifndef TX_CASE_NAME
`define TX_CASE_NAME "ht_mcs7_gi1_aggr0_byte100"
`endif
`ifndef TX_MEM_TOTAL_WORDS
`define TX_MEM_TOTAL_WORDS 15
`endif
`ifndef TX_PSDU_BYTES
`define TX_PSDU_BYTES 100
`endif
`ifndef TX_SLV_REG17_VALUE
`define TX_SLV_REG17_VALUE 32'h0007C064
`endif
`ifndef TX_TIMEOUT_CYCLES
`define TX_TIMEOUT_CYCLES 120000
`endif

module openwifi_tx_main_joint_tb;
  localparam integer CLK_PERIOD_NS = 10;
  localparam integer DAC_CLK_PERIOD_NS = 25;
  localparam integer MEM_TOTAL_WORDS = `TX_MEM_TOTAL_WORDS;
  localparam integer PAYLOAD_START_WORD = 2;
  localparam integer PAYLOAD_DMA_WORDS = MEM_TOTAL_WORDS - PAYLOAD_START_WORD;
  localparam integer PSDU_BYTES = `TX_PSDU_BYTES;
  localparam integer AUTO_START_BRAM_ADDR = PAYLOAD_START_WORD + PAYLOAD_DMA_WORDS - 1;
  localparam [31:0] TX_SLV_REG2 = (AUTO_START_BRAM_ADDR << 4) | 32'h00000008;
  localparam [31:0] TX_SLV_REG8 = PAYLOAD_DMA_WORDS;
  localparam [31:0] TX_SLV_REG17 = `TX_SLV_REG17_VALUE;
  localparam USE_HT_RATE = TX_SLV_REG17[15];

  reg clk = 0;
  reg dac_clk = 0;
  reg rstn = 0;
  reg [63:0] tx_mem [0:MEM_TOTAL_WORDS-1];

  always #(CLK_PERIOD_NS/2) clk = ~clk;
  always #(DAC_CLK_PERIOD_NS/2) dac_clk = ~dac_clk;

  reg s_axis_tvalid = 0;
  reg [63:0] s_axis_tdata = 0;
  reg [7:0] s_axis_tstrb = 8'hFF;
  reg s_axis_tlast = 0;
  wire s_axis_tready;

  wire phy_tx_start;
  wire tx_hold;
  wire [9:0] bram_addr;
  wire [63:0] data_to_acc;
  wire [9:0] bram_addr_to_xpu;
  wire phy_tx_done;
  wire phy_tx_started;
  wire result_iq_valid;
  wire [15:0] result_i;
  wire [15:0] result_q;

  wire dac_valid;
  wire [63:0] dac_data;
  wire [31:0] iq0_for_check;
  wire [31:0] iq1_for_check;
  wire iq_valid_for_check;
  wire tx_pkt_iq_to_dac_ongoing;
  wire tx_itrpt;
  wire tx_itrpt_led;
  wire tx_end_led;
  wire [63:0] douta;
  wire tx_iq_fifo_empty;
  wire tx_pkt_need_ack;
  wire [3:0] tx_pkt_retrans_limit;
  wire use_ht_aggr;
  wire cts_toself_bb_is_ongoing;
  wire cts_toself_rf_is_ongoing;
  wire quit_retrans;
  wire reset_backoff;
  wire high_trigger;
  wire [1:0] tx_queue_idx_to_xpu;

  reg tx_bb_is_ongoing = 0;
  reg tsf_pulse_1M = 0;
  integer tsf_count = 0;

  reg [6:0] tx_axi_awaddr = 0;
  reg [2:0] tx_axi_awprot = 0;
  reg tx_axi_awvalid = 0;
  wire tx_axi_awready;
  reg [31:0] tx_axi_wdata = 0;
  reg [3:0] tx_axi_wstrb = 4'hF;
  reg tx_axi_wvalid = 0;
  wire tx_axi_wready;
  wire [1:0] tx_axi_bresp;
  wire tx_axi_bvalid;
  reg tx_axi_bready = 1;
  reg [6:0] tx_axi_araddr = 0;
  reg [2:0] tx_axi_arprot = 0;
  reg tx_axi_arvalid = 0;
  wire tx_axi_arready;
  wire [31:0] tx_axi_rdata;
  wire [1:0] tx_axi_rresp;
  wire tx_axi_rvalid;
  reg tx_axi_rready = 1;

  reg [6:0] phy_axi_awaddr = 0;
  reg [2:0] phy_axi_awprot = 0;
  reg phy_axi_awvalid = 0;
  wire phy_axi_awready;
  reg [31:0] phy_axi_wdata = 0;
  reg [3:0] phy_axi_wstrb = 4'hF;
  reg phy_axi_wvalid = 0;
  wire phy_axi_wready;
  wire [1:0] phy_axi_bresp;
  wire phy_axi_bvalid;
  reg phy_axi_bready = 1;
  reg [6:0] phy_axi_araddr = 0;
  reg [2:0] phy_axi_arprot = 0;
  reg phy_axi_arvalid = 0;
  wire phy_axi_arready;
  wire [31:0] phy_axi_rdata;
  wire [1:0] phy_axi_rresp;
  wire phy_axi_rvalid;
  reg phy_axi_rready = 1;

  integer cycle = 0;
  integer axis_sent_count = 0;
  integer bram_write_count = 0;
  integer bram_header_mismatch = 0;
  integer bram_l_sig_mismatch = 0;
  integer bram_ht_sig_vector_mismatch = 0;
  integer bram_payload_mismatch = 0;
  integer phy_start_count = 0;
  integer phy_started_count = 0;
  integer phy_done_count = 0;
  integer core_iq_accept_count = 0;
  integer core_iq_nonzero_count = 0;
  integer iq_check_count = 0;
  integer iq_check_nonzero_count = 0;
  integer dac_nonzero_count = 0;
  integer timeout_fail = 0;
  integer finish_done = 0;

  integer event_fd;
  integer axis_fd;
  integer bram_fd;
  integer core_iq_fd;
  integer check_iq_fd;
  integer trace_fd;
  integer dot11_tail_fd;
  integer dot11_enc_fd;
  integer summary_fd;

  reg phy_tx_start_d = 0;
  reg phy_tx_started_d = 0;
  reg phy_tx_done_d = 0;

  tx_intf tx_intf_i (
    .dac_rst(~rstn),
    .dac_clk(dac_clk),
    .dma_valid(1'b0),
    .dma_data(64'd0),
    .dma_ready(),
    .dac_valid(dac_valid),
    .dac_data(dac_data),
    .dac_ready(1'b1),
    .iq0_for_check(iq0_for_check),
    .iq1_for_check(iq1_for_check),
    .iq_valid_for_check(iq_valid_for_check),
    .tx_pkt_iq_to_dac_ongoing(tx_pkt_iq_to_dac_ongoing),
    .fcs_in_strobe(1'b0),
    .phy_tx_start(phy_tx_start),
    .tx_hold(tx_hold),
    .bram_addr(bram_addr),
    .rf_i_from_acc(result_i),
    .rf_q_from_acc(result_q),
    .rf_iq_valid_from_acc(result_iq_valid),
    .data_to_acc(data_to_acc),
    .bram_addr_to_xpu(bram_addr_to_xpu),
    .tx_start_from_acc(phy_tx_started),
    .tx_end_from_acc(phy_tx_done),
    .tx_itrpt(tx_itrpt),
    .tx_itrpt_led(tx_itrpt_led),
    .tx_end_led(tx_end_led),
    .tx_status(80'd0),
    .mac_addr(48'h112233445566),
    .douta(douta),
    .tx_iq_fifo_empty(tx_iq_fifo_empty),
    .slice_en(4'b0001),
    .backoff_done(1'b1),
    .tx_bb_is_ongoing(tx_bb_is_ongoing),
    .ack_tx_flag(1'b0),
    .wea_from_xpu(1'b0),
    .addra_from_xpu(10'd0),
    .dina_from_xpu(64'd0),
    .tx_pkt_need_ack(tx_pkt_need_ack),
    .tx_pkt_retrans_limit(tx_pkt_retrans_limit),
    .use_ht_aggr(use_ht_aggr),
    .tx_try_complete(1'b0),
    .num_slot_random(10'd0),
    .cw(4'd0),
    .retrans_in_progress(1'b0),
    .start_retrans(1'b0),
    .start_tx_ack(1'b0),
    .tx_control_state_idle(1'b1),
    .cts_toself_bb_is_ongoing(cts_toself_bb_is_ongoing),
    .cts_toself_rf_is_ongoing(cts_toself_rf_is_ongoing),
    .tsf_pulse_1M(tsf_pulse_1M),
    .band(4'd1),
    .channel(8'd1),
    .quit_retrans(quit_retrans),
    .reset_backoff(reset_backoff),
    .high_trigger(high_trigger),
    .tx_queue_idx_to_xpu(tx_queue_idx_to_xpu),
    .s00_axi_aclk(clk),
    .s00_axi_aresetn(rstn),
    .s00_axi_awaddr(tx_axi_awaddr),
    .s00_axi_awprot(tx_axi_awprot),
    .s00_axi_awvalid(tx_axi_awvalid),
    .s00_axi_awready(tx_axi_awready),
    .s00_axi_wdata(tx_axi_wdata),
    .s00_axi_wstrb(tx_axi_wstrb),
    .s00_axi_wvalid(tx_axi_wvalid),
    .s00_axi_wready(tx_axi_wready),
    .s00_axi_bresp(tx_axi_bresp),
    .s00_axi_bvalid(tx_axi_bvalid),
    .s00_axi_bready(tx_axi_bready),
    .s00_axi_araddr(tx_axi_araddr),
    .s00_axi_arprot(tx_axi_arprot),
    .s00_axi_arvalid(tx_axi_arvalid),
    .s00_axi_arready(tx_axi_arready),
    .s00_axi_rdata(tx_axi_rdata),
    .s00_axi_rresp(tx_axi_rresp),
    .s00_axi_rvalid(tx_axi_rvalid),
    .s00_axi_rready(tx_axi_rready),
    .s00_axis_aclk(clk),
    .s00_axis_aresetn(rstn),
    .s00_axis_tready(s_axis_tready),
    .s00_axis_tdata(s_axis_tdata),
    .s00_axis_tstrb(s_axis_tstrb),
    .s00_axis_tlast(s_axis_tlast),
    .s00_axis_tvalid(s_axis_tvalid),
    .tsf_runtime_val(64'd0)
  );

  openofdm_tx openofdm_tx_i (
    .clk(clk),
    .phy_tx_arestn(rstn),
    .phy_tx_start(phy_tx_start),
    .phy_tx_done(phy_tx_done),
    .phy_tx_started(phy_tx_started),
    .bram_din(data_to_acc),
    .bram_addr(bram_addr),
    .result_iq_hold(tx_hold),
    .result_iq_valid(result_iq_valid),
    .result_i(result_i),
    .result_q(result_q),
    .s00_axi_aclk(clk),
    .s00_axi_aresetn(rstn),
    .s00_axi_awaddr(phy_axi_awaddr),
    .s00_axi_awprot(phy_axi_awprot),
    .s00_axi_awvalid(phy_axi_awvalid),
    .s00_axi_awready(phy_axi_awready),
    .s00_axi_wdata(phy_axi_wdata),
    .s00_axi_wstrb(phy_axi_wstrb),
    .s00_axi_wvalid(phy_axi_wvalid),
    .s00_axi_wready(phy_axi_wready),
    .s00_axi_bresp(phy_axi_bresp),
    .s00_axi_bvalid(phy_axi_bvalid),
    .s00_axi_bready(phy_axi_bready),
    .s00_axi_araddr(phy_axi_araddr),
    .s00_axi_arprot(phy_axi_arprot),
    .s00_axi_arvalid(phy_axi_arvalid),
    .s00_axi_arready(phy_axi_arready),
    .s00_axi_rdata(phy_axi_rdata),
    .s00_axi_rresp(phy_axi_rresp),
    .s00_axi_rvalid(phy_axi_rvalid),
    .s00_axi_rready(phy_axi_rready)
  );

  task apply_config;
    begin
      force tx_intf_i.slv_reg0 = 32'h00000000;
      force tx_intf_i.slv_reg1 = 32'h00000000;
      force tx_intf_i.slv_reg2 = TX_SLV_REG2;
      force tx_intf_i.slv_reg4 = 32'h00000000;
      force tx_intf_i.slv_reg5 = 32'h00000000;
      force tx_intf_i.slv_reg6 = 32'h00000000;
      force tx_intf_i.slv_reg7 = 32'h00000000;
      force tx_intf_i.slv_reg8 = TX_SLV_REG8;
      force tx_intf_i.slv_reg9 = 32'h00000000;
      force tx_intf_i.slv_reg10 = 32'h00000000;
      force tx_intf_i.slv_reg11 = 32'h00000000;
      force tx_intf_i.slv_reg12 = 32'd64;
      force tx_intf_i.slv_reg13 = 32'd128;
      force tx_intf_i.slv_reg14 = 32'h00000000;
      force tx_intf_i.slv_reg15 = 32'h0000FFFF;
      force tx_intf_i.slv_reg16 = 32'h00000000;
      force tx_intf_i.slv_reg17 = TX_SLV_REG17;
      force tx_intf_i.tx_bit_intf_i.tx_queue_idx_indication_from_ps = 3'd0;

      force openofdm_tx_i.slv_reg0 = 32'h00000000;
      force openofdm_tx_i.slv_reg1 = 32'h0000005D;
      force openofdm_tx_i.slv_reg2 = 32'h0000005D;
    end
  endtask

  task send_axis_word;
    input [63:0] data;
    input last;
    begin
      s_axis_tdata = data;
      s_axis_tlast = last;
      s_axis_tvalid = 1'b1;
      @(posedge clk);
      while (s_axis_tready !== 1'b1) begin
        @(posedge clk);
      end
      $fwrite(axis_fd, "%0d,%0t,%h,%0d\n", cycle, $time, data, last);
      axis_sent_count = axis_sent_count + 1;
      s_axis_tvalid = 1'b0;
      s_axis_tlast = 1'b0;
      s_axis_tdata = 64'd0;
      @(posedge clk);
    end
  endtask

  task send_payload;
    integer i;
    begin
      for (i = PAYLOAD_START_WORD; i < MEM_TOTAL_WORDS; i = i + 1) begin
        send_axis_word(tx_mem[i], (i == MEM_TOTAL_WORDS-1));
      end
    end
  endtask

  task write_summary_and_finish;
    integer pass;
    integer header_vector_exact;
    begin
      if (finish_done == 0) begin
        finish_done = 1;
        header_vector_exact = (bram_header_mismatch == 0);
        pass = (timeout_fail == 0 &&
                axis_sent_count == PAYLOAD_DMA_WORDS &&
                bram_payload_mismatch == 0 &&
                phy_start_count > 0 &&
                phy_started_count > 0 &&
                phy_done_count > 0 &&
                core_iq_accept_count > 0 &&
                core_iq_nonzero_count > 0 &&
                iq_check_count > 0 &&
                iq_check_nonzero_count > 0);
        summary_fd = $fopen("tx_main_joint_summary.txt", "w");
        $fwrite(summary_fd, "case,%s\n", `TX_CASE_NAME);
        $fwrite(summary_fd, "mem_file,%s\n", `TX_MEM_FILE);
        $fwrite(summary_fd, "psdu_bytes,%0d\n", PSDU_BYTES);
        $fwrite(summary_fd, "payload_dma_words,%0d\n", PAYLOAD_DMA_WORDS);
        $fwrite(summary_fd, "auto_start_bram_addr,%0d\n", AUTO_START_BRAM_ADDR);
        $fwrite(summary_fd, "tx_slv_reg2,0x%08h\n", TX_SLV_REG2);
        $fwrite(summary_fd, "tx_slv_reg8,0x%08h\n", TX_SLV_REG8);
        $fwrite(summary_fd, "tx_slv_reg17,0x%08h\n", TX_SLV_REG17);
        $fwrite(summary_fd, "axis_sent_count,%0d\n", axis_sent_count);
        $fwrite(summary_fd, "bram_write_count,%0d\n", bram_write_count);
        $fwrite(summary_fd, "bram_header_mismatch,%0d\n", bram_header_mismatch);
        $fwrite(summary_fd, "bram_l_sig_mismatch,%0d\n", bram_l_sig_mismatch);
        $fwrite(summary_fd, "bram_ht_sig_vector_mismatch,%0d\n", bram_ht_sig_vector_mismatch);
        $fwrite(summary_fd, "bram_payload_mismatch,%0d\n", bram_payload_mismatch);
        $fwrite(summary_fd, "phy_start_count,%0d\n", phy_start_count);
        $fwrite(summary_fd, "phy_started_count,%0d\n", phy_started_count);
        $fwrite(summary_fd, "phy_done_count,%0d\n", phy_done_count);
        $fwrite(summary_fd, "core_iq_accept_count,%0d\n", core_iq_accept_count);
        $fwrite(summary_fd, "core_iq_nonzero_count,%0d\n", core_iq_nonzero_count);
        $fwrite(summary_fd, "iq_check_count,%0d\n", iq_check_count);
        $fwrite(summary_fd, "iq_check_nonzero_count,%0d\n", iq_check_nonzero_count);
        $fwrite(summary_fd, "dac_nonzero_count,%0d\n", dac_nonzero_count);
        $fwrite(summary_fd, "timeout_fail,%0d\n", timeout_fail);
        $fwrite(summary_fd, "header_vector_exact,%0d\n", header_vector_exact);
        $fwrite(summary_fd, "pass,%0d\n", pass);
        $fclose(summary_fd);
        $fclose(event_fd);
        $fclose(axis_fd);
        $fclose(bram_fd);
        $fclose(core_iq_fd);
        $fclose(check_iq_fd);
        $fclose(trace_fd);
        $fclose(dot11_tail_fd);
        $fclose(dot11_enc_fd);
        $display("TX_MAIN_JOINT_SUMMARY pass=%0d axis=%0d bram=%0d start=%0d done=%0d core_iq=%0d check_iq=%0d",
                 pass, axis_sent_count, bram_write_count, phy_start_count, phy_done_count,
                 core_iq_accept_count, iq_check_count);
        $finish;
      end
    end
  endtask

  initial begin
    $readmemh(`TX_MEM_FILE, tx_mem);
    event_fd = $fopen("tx_main_joint_events.csv", "w");
    axis_fd = $fopen("tx_main_joint_s_axis.csv", "w");
    bram_fd = $fopen("tx_main_joint_bram_write.csv", "w");
    core_iq_fd = $fopen("tx_main_joint_core_iq.csv", "w");
    check_iq_fd = $fopen("tx_main_joint_check_iq.csv", "w");
    trace_fd = $fopen("tx_main_joint_txintf_trace.csv", "w");
    dot11_tail_fd = $fopen("tx_main_joint_dot11_tail_debug.csv", "w");
    dot11_enc_fd = $fopen("tx_main_joint_dot11_encode_debug.csv", "w");
    $fwrite(event_fd, "cycle,time_ns,event,arg0,arg1,arg2,arg3\n");
    $fwrite(axis_fd, "cycle,time_ns,tdata,tlast\n");
    $fwrite(bram_fd, "cycle,time_ns,addr,data,expected,match\n");
    $fwrite(core_iq_fd, "sample,cycle,time_ns,i,q,hold\n");
    $fwrite(check_iq_fd, "sample,cycle,time_ns,iq0,iq1,ongoing\n");
    $fwrite(trace_fd, "cycle,time_ns,s_axis_state,write_pointer,writes_done,s_axis_recv,s_fifo_count0,config_wren,config_empty,config_count0,high_state,queue,read_s_axis,emptyn,wea,addra,start_delay0,phy_tx_start,tx_hold\n");
    $fwrite(dot11_tail_fd, "cycle,time_ns,state1,state11,psdu_bit_cnt,dbps_cnt,bram_addr,bram_din,bit_scram,pkt_fcs,pkt_fcs_idx,crc_en,crc_data,data_scram_state,bits_iready\n");
    $fwrite(dot11_enc_fd, "cycle,time_ns,state1,state11,state2,ofdm_cnt_fsm1,ofdm_cnt_fsm2,dbps_cnt_fsm1,dbps_cnt_fsm2,psdu_bit_cnt,enc_en,bit_scram,bits_enc,fifo_ivalid,fifo_iready,fifo_ovalid,fifo_oready,fifo_odata,enc_pos,punc_info,interlv_addrs,bits_ram_en,bits_ram_waddr,punc_bit,mod_addr,bits_to_mod\n");

    apply_config();
    repeat (20) @(posedge clk);
    rstn <= 1'b1;
    repeat (20) @(posedge clk);
    $fwrite(event_fd, "%0d,%0t,config,0x%08h,0x%08h,0x%08h,0x%08h\n",
            cycle, $time, TX_SLV_REG2, TX_SLV_REG8, TX_SLV_REG17, tx_mem[0][31:0]);
    send_payload();
    $fwrite(event_fd, "%0d,%0t,s_axis_done,%0d,0,0,0\n", cycle, $time, axis_sent_count);
  end

  initial begin
    repeat (`TX_TIMEOUT_CYCLES) @(posedge clk);
    timeout_fail = 1;
    $fwrite(event_fd, "%0d,%0t,timeout,0,0,0,0\n", cycle, $time);
    write_summary_and_finish();
  end

  initial begin
    wait (phy_done_count > 0);
    repeat (3000) @(posedge clk);
    write_summary_and_finish();
  end

  always @(posedge clk) begin
    cycle <= cycle + 1;
    phy_tx_start_d <= phy_tx_start;
    phy_tx_started_d <= phy_tx_started;
    phy_tx_done_d <= phy_tx_done;

    if (!rstn) begin
      tx_bb_is_ongoing <= 1'b0;
      tsf_count <= 0;
      tsf_pulse_1M <= 1'b0;
    end else begin
      if (phy_tx_start && !phy_tx_start_d)
        tx_bb_is_ongoing <= 1'b1;
      else if (phy_tx_done)
        tx_bb_is_ongoing <= 1'b0;

      if (tsf_count == 99) begin
        tsf_count <= 0;
        tsf_pulse_1M <= 1'b1;
      end else begin
        tsf_count <= tsf_count + 1;
        tsf_pulse_1M <= 1'b0;
      end

      if (phy_tx_start && !phy_tx_start_d) begin
        phy_start_count = phy_start_count + 1;
        $fwrite(event_fd, "%0d,%0t,phy_tx_start,%0d,%0d,%0d,%0d\n",
                cycle, $time, bram_write_count, tx_intf_i.tx_bit_intf_i.addra, bram_addr, tx_hold);
      end
      if ((phy_tx_started === 1'b1) && (phy_tx_started_d !== 1'b1)) begin
        phy_started_count = phy_started_count + 1;
        $fwrite(event_fd, "%0d,%0t,phy_tx_started,%0d,%0d,%0d,%0d\n",
                cycle, $time, bram_addr, tx_hold, core_iq_accept_count, iq_check_count);
      end
      if (phy_tx_done && !phy_tx_done_d) begin
        phy_done_count = phy_done_count + 1;
        $fwrite(event_fd, "%0d,%0t,phy_tx_done,%0d,%0d,%0d,%0d\n",
                cycle, $time, core_iq_accept_count, iq_check_count, tx_intf_i.tx_iq_fifo_empty, tx_hold);
      end

      if (tx_intf_i.tx_bit_intf_i.wea) begin
        bram_write_count = bram_write_count + 1;
        if (tx_intf_i.tx_bit_intf_i.addra == 0) begin
          if (tx_intf_i.tx_bit_intf_i.dina !== tx_mem[0]) begin
            bram_header_mismatch = bram_header_mismatch + 1;
            bram_l_sig_mismatch = bram_l_sig_mismatch + 1;
          end
          $fwrite(bram_fd, "%0d,%0t,%0d,%h,%h,%0d\n",
                  cycle, $time, tx_intf_i.tx_bit_intf_i.addra,
                  tx_intf_i.tx_bit_intf_i.dina, tx_mem[0],
                  (tx_intf_i.tx_bit_intf_i.dina === tx_mem[0]));
        end else if (USE_HT_RATE && tx_intf_i.tx_bit_intf_i.addra == 1) begin
          if (tx_intf_i.tx_bit_intf_i.dina !== tx_mem[1]) begin
            bram_header_mismatch = bram_header_mismatch + 1;
            bram_ht_sig_vector_mismatch = bram_ht_sig_vector_mismatch + 1;
          end
          $fwrite(bram_fd, "%0d,%0t,%0d,%h,%h,%0d\n",
                  cycle, $time, tx_intf_i.tx_bit_intf_i.addra,
                  tx_intf_i.tx_bit_intf_i.dina, tx_mem[1],
                  (tx_intf_i.tx_bit_intf_i.dina === tx_mem[1]));
        end else begin
          if (tx_intf_i.tx_bit_intf_i.dina !== tx_mem[tx_intf_i.tx_bit_intf_i.addra])
            bram_payload_mismatch = bram_payload_mismatch + 1;
          $fwrite(bram_fd, "%0d,%0t,%0d,%h,%h,%0d\n",
                  cycle, $time, tx_intf_i.tx_bit_intf_i.addra,
                  tx_intf_i.tx_bit_intf_i.dina,
                  tx_mem[tx_intf_i.tx_bit_intf_i.addra],
                  (tx_intf_i.tx_bit_intf_i.dina === tx_mem[tx_intf_i.tx_bit_intf_i.addra]));
        end
      end

      if (result_iq_valid && !tx_hold) begin
        if (core_iq_accept_count < 20000)
          $fwrite(core_iq_fd, "%0d,%0d,%0t,%0d,%0d,%0d\n",
                  core_iq_accept_count, cycle, $time, $signed(result_i), $signed(result_q), tx_hold);
        core_iq_accept_count = core_iq_accept_count + 1;
        if (result_i != 16'd0 || result_q != 16'd0)
          core_iq_nonzero_count = core_iq_nonzero_count + 1;
      end

      if (iq_valid_for_check) begin
        if (iq_check_count < 20000)
          $fwrite(check_iq_fd, "%0d,%0d,%0t,%h,%h,%0d\n",
                  iq_check_count, cycle, $time, iq0_for_check, iq1_for_check,
                  tx_pkt_iq_to_dac_ongoing);
        iq_check_count = iq_check_count + 1;
        if (iq0_for_check != 32'd0 || iq1_for_check != 32'd0)
          iq_check_nonzero_count = iq_check_nonzero_count + 1;
      end

      if (dac_data != 64'd0)
        dac_nonzero_count = dac_nonzero_count + 1;

      if ((cycle < 5000) || ((cycle % 1000) == 0)) begin
        $fwrite(trace_fd, "%0d,%0t,%0d,%0d,%0d,%0d,%0d,%h,%h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                cycle, $time,
                tx_intf_i.tx_intf_s_axis_i.mst_exec_state,
                tx_intf_i.tx_intf_s_axis_i.write_pointer,
                tx_intf_i.tx_intf_s_axis_i.writes_done,
                tx_intf_i.s_axis_recv_data_from_high,
                tx_intf_i.s_axis_fifo_data_count0,
                tx_intf_i.tx_bit_intf_i.tx_config_fifo_wren,
                tx_intf_i.tx_bit_intf_i.tx_config_fifo_empty,
                tx_intf_i.tx_config_fifo_data_count0,
                tx_intf_i.tx_bit_intf_i.high_tx_ctl_state,
                tx_intf_i.tx_bit_intf_i.tx_queue_idx_reg,
                tx_intf_i.tx_bit_intf_i.read_from_s_axis_en,
                tx_intf_i.s_axis_emptyn_to_acc,
                tx_intf_i.tx_bit_intf_i.wea,
                tx_intf_i.tx_bit_intf_i.addra,
                tx_intf_i.tx_bit_intf_i.start_delay0,
                phy_tx_start,
                tx_hold);
      end

      if ((openofdm_tx_i.dot11_tx.state1 != 2'd0) ||
          openofdm_tx_i.dot11_tx.bits_enc_fifo_ivalid ||
          openofdm_tx_i.dot11_tx.bits_enc_fifo_ovalid ||
          openofdm_tx_i.dot11_tx.bits_ram_en ||
          (openofdm_tx_i.dot11_tx.state2 != 2'd0)) begin
        $fwrite(dot11_enc_fd, "%0d,%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%02b,%0d,%0d,%0d,%0d,%02b,%0d,%02b,%05h,%0d,%0d,%0d,%0d,%02h\n",
                cycle, $time,
                openofdm_tx_i.dot11_tx.state1,
                openofdm_tx_i.dot11_tx.state11,
                openofdm_tx_i.dot11_tx.state2,
                openofdm_tx_i.dot11_tx.ofdm_cnt_FSM1,
                openofdm_tx_i.dot11_tx.ofdm_cnt_FSM2,
                openofdm_tx_i.dot11_tx.dbps_cnt_FSM1,
                openofdm_tx_i.dot11_tx.dbps_cnt_FSM2,
                openofdm_tx_i.dot11_tx.psdu_bit_cnt,
                openofdm_tx_i.dot11_tx.enc_en,
                openofdm_tx_i.dot11_tx.bit_scram,
                openofdm_tx_i.dot11_tx.bits_enc,
                openofdm_tx_i.dot11_tx.bits_enc_fifo_ivalid,
                openofdm_tx_i.dot11_tx.bits_enc_fifo_iready,
                openofdm_tx_i.dot11_tx.bits_enc_fifo_ovalid,
                openofdm_tx_i.dot11_tx.bits_enc_fifo_oready,
                openofdm_tx_i.dot11_tx.bits_enc_fifo_odata,
                openofdm_tx_i.dot11_tx.enc_pos,
                openofdm_tx_i.dot11_tx.punc_info,
                openofdm_tx_i.dot11_tx.interlv_addrs,
                openofdm_tx_i.dot11_tx.bits_ram_en,
                openofdm_tx_i.dot11_tx.bits_ram_waddr,
                openofdm_tx_i.dot11_tx.punc_bit,
                openofdm_tx_i.dot11_tx.mod_addr,
                openofdm_tx_i.dot11_tx.bits_to_mod);
      end

      if ((openofdm_tx_i.dot11_tx.state1 == 3'd3) &&
          (openofdm_tx_i.dot11_tx.psdu_bit_cnt >= ((PSDU_BYTES * 8) - 48)) &&
          (openofdm_tx_i.dot11_tx.state11 < 3'd5)) begin
        $fwrite(dot11_tail_fd, "%0d,%0t,%0d,%0d,%0d,%0d,%0d,%h,%0d,%08h,%0d,%0d,%h,%02h,%0d\n",
                cycle, $time,
                openofdm_tx_i.dot11_tx.state1,
                openofdm_tx_i.dot11_tx.state11,
                openofdm_tx_i.dot11_tx.psdu_bit_cnt,
                openofdm_tx_i.dot11_tx.dbps_cnt_FSM1,
                bram_addr,
                data_to_acc,
                openofdm_tx_i.dot11_tx.bit_scram,
                openofdm_tx_i.dot11_tx.pkt_fcs,
                openofdm_tx_i.dot11_tx.pkt_fcs_idx,
                openofdm_tx_i.dot11_tx.crc_en,
                openofdm_tx_i.dot11_tx.crc_data,
                openofdm_tx_i.dot11_tx.data_scram_state,
                openofdm_tx_i.dot11_tx.bits_enc_fifo_iready);
      end
    end
  end
endmodule
