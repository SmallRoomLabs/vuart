`default_nettype none

module top(
 input EXTCLK, BUT1, BUT2,
 output reg LED1, LED2,
 input P65,
 output P66
);

uart uart(
  .SYSCLK(EXTCLK),
  .RESET(1'b0),

  .txData(txData), // data to be transmitted serially onto tx
  .txStb(txStb),        // positive going strobe for the txData - 1 SYSCLK
  .tx(P66),          // serial output stream in 8N1 format with high idle
  .txRdy(txRdy),       // high when the uart is ready to accept new data

  .rx(P65),
  .rxData(rxData),
  .rxAck(rxAck),
  .rxRdy(rxRdy)
);

reg [7:0] txData=8'h55;
reg txStb=0;
wire txRdy;

wire [7:0] rxData;
reg rxAck=0;
wire rxRdy;

reg [24:0] dly=0;

always @(posedge EXTCLK) begin
  LED1 <= rxRdy;
  LED2 <=dly[24];
  dly<=dly+1;
  if (rxRdy) begin
    txData<=rxData+1;
    txStb<=1;
    rxAck<=1;
  end
  if (txStb==1) begin
    txStb<=0;
    rxAck<=0;
  end
end


endmodule