`timescale 1ns / 1ps

module rot_lut(
  input clka,
  input [8:0] addra,
  output reg [31:0] douta,
  input clkb,
  input [8:0] addrb,
  output reg [31:0] doutb
);
  reg [31:0] mem [0:511];
  integer i;

  initial begin
    for (i = 0; i < 512; i = i + 1) begin
      mem[i] = 32'h0;
    end
    $readmemb("../../../../../verilog/coregen/rot_lut.mif", mem);
  end

  always @(posedge clka) begin
    douta <= mem[addra];
  end

  always @(posedge clkb) begin
    doutb <= mem[addrb];
  end
endmodule
