`timescale 1ns / 1ps

module atan_lut(
  input clka,
  input [8:0] addra,
  output reg [8:0] douta
);
  reg [8:0] mem [0:511];
  integer i;

  initial begin
    for (i = 0; i < 512; i = i + 1) begin
      mem[i] = 9'h0;
    end
    $readmemb("../../../../../verilog/coregen/atan_lut.mif", mem);
  end

  always @(posedge clka) begin
    douta <= mem[addra];
  end
endmodule
