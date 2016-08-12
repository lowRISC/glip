/* Copyright (c) 2015-2016 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 *
 * eth Toplevel
 *
 * This module handles the eth interface and puts incoming bytes to a
 * FIFO and vice versa. The module only supports 8N1 eth, meaning 8
 * bit, no parity and one stop bit. All baud rates are supported, but
 * be careful with low frequencies and large baud rates that the
 * tolerance of the rounded bit divisor (rounding error of
 * FREQ/BAUD) is within 2%.
 * 
 * Parameters:
 *  - XILINX_TARGET_DEVICE: Xilinx device, allowed: "7SERIES"
 *
 * Author(s):
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 */

module glip_eth_toplevel
  #(parameter XILINX_TARGET_DEVICE = "7SERIES")
   (
    // Clock & Reset
    input              clk_io,
    input              clk_logic,
    input              rst,

    // GLIP FIFO Interface
    input [15:0]       fifo_out_data,
    input              fifo_out_valid,
    output             fifo_out_ready,
    output [15:0]      fifo_in_data,
    output             fifo_in_valid,
    input              fifo_in_ready,

    // GLIP Control Interface
    output             logic_rst,
    output             com_rst,
    
    // eth Interface
    input [31:0]       i_glip,
    output [31:0]      o_glip,
    
    // Error signal if failure on the line
    output             error
    );

wire [9:0] irdcnt, ordcnt, iwrcnt, owrcnt;
wire irderr, orderr, iwrerr, owrerr;

   // Clock domain crossing eth -> logic
   FIFO_DUALCLOCK_MACRO
     #(.ALMOST_FULL_OFFSET(9'h006), // Sets almost full threshold
       .ALMOST_EMPTY_OFFSET(9'h006),
       .DATA_WIDTH(16), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
       .DEVICE(XILINX_TARGET_DEVICE), // Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
       .FIFO_SIZE("18Kb"), // Target BRAM: "18Kb" or "36Kb"
       .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIfor FWFT to "TRUE" or "FALSE"
       )
   in_fifo
     (.ALMOSTEMPTY (),
      .ALMOSTFULL  (),
      .DO          (fifo_in_data[15:0]),
      .EMPTY       (iempty),
      .FULL        (ifull),
      .RDCOUNT     (irdcnt[9:0]),
      .RDERR       (irderr),
      .WRCOUNT     (iwrcnt[9:0]),
      .WRERR       (iwrerr),
      .DI          (i_glip[15:0]),
      .RDCLK       (clk_logic),
      .RDEN        (fifo_in_ready),
      .RST         (com_rst),
      .WRCLK       (clk_io),
      .WREN        (i_glip[31])
      );
   
   // Clock domain crossing logic -> eth
   FIFO_DUALCLOCK_MACRO
     #(.ALMOST_EMPTY_OFFSET(9'h006), // Sets the almost empty threshold
       .ALMOST_FULL_OFFSET(9'h006),
       .DATA_WIDTH(16), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
       .DEVICE(XILINX_TARGET_DEVICE), // Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
       .FIFO_SIZE("18Kb"), // Target BRAM: "18Kb" or "36Kb"
       .FIRST_WORD_FALL_THROUGH("TRUE") // Sets the FIfor FWFT to "TRUE" or "FALSE"
       )
   out_fifo
     (.ALMOSTEMPTY (),
      .ALMOSTFULL  (),
      .DO          (o_glip[15:0]),
      .EMPTY       (oempty),
      .FULL        (ofull),
      .RDCOUNT     (ordcnt[9:0]),
      .RDERR       (orderr),
      .WRCOUNT     (owrcnt[9:0]),
      .WRERR       (owrerr),
      .DI          (fifo_out_data[15:0]),
      .RDCLK       (clk_io),
      .RDEN        (i_glip[30]),
      .RST         (com_rst),
      .WRCLK       (clk_logic),
      .WREN        (fifo_out_valid)
      );

assign com_rst = i_glip[16];
assign logic_rst = i_glip[17];
assign error = i_glip[18];
assign o_glip[31:16] = {ifull|irderr|iwrerr,ofull|orderr|owrerr,
        iempty,oempty,
        irdcnt[2:0], ordcnt[2:0], iwrcnt[2:0], owrcnt[2:0]};
assign fifo_out_ready = ~ofull;
assign fifo_in_valid = ~iempty;

endmodule // glip_eth_toplevel
