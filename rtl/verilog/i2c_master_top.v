//
// WISHBONE revB2 compiant I2C master core
//
// author: Richard Herveille
// rev. 0.1 26-08-2001. Iinitial Verilog release
//

`include "timescale.v"
`include "i2c_master_defines.v"

module i2c_master_top(
	wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o, 
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_inta_o,
	scl_pad_i, scl_pad_o, scl_padoen_o, sda_pad_i, sda_pad_o, sda_padoen_o );

	//
	// inputs & outputs
	//

	// wishbone signals
	input        wb_clk_i;     // master clock input
	input        wb_rst_i;     // synchronous active high reset
	input        arst_i;       // asynchronous reset
	input  [2:0] wb_adr_i;     // lower address bits
	input  [7:0] wb_dat_i;     // databus input
	output [7:0] wb_dat_o;     // databus output
	reg [7:0] wb_dat_o;
	input        wb_we_i;      // write enable input
	input        wb_stb_i;     // stobe/core select signal
	input        wb_cyc_i;     // valid bus cycle input
	output       wb_ack_o;     // bus cycle acknowledge output
	output       wb_inta_o;    // interrupt request signal output
	reg wb_inta_o;

	// I2C signals
	// i2c clock line
	input  scl_pad_i;       // SCL-line input
	output scl_pad_o;       // SCL-line output (always 1'b0)
	output scl_padoen_o;    // SCL-line output enable (active low)
	// i2c data line
	input  sda_pad_i;       // SDA-line input
	output sda_pad_o;       // SDA-line output (always 1'b0)
	output sda_padoen_o;    // SDA-line output enable (active low)


	//
	// variable declarations
	//

	// registers
	reg  [15:0] prer; // clock prescale register
	reg  [ 7:0] ctr;  // control register
	reg  [ 7:0] txr;  // transmit register
	wire [ 7:0] rxr;  // receive register
	reg  [ 7:0] cr;   // command register
	wire [ 7:0] sr;   // status register

	// done signal: command completed, clear command register
	wire done;

	// core enable signal
	wire core_en;

	// status register signals
	wire irxack;
	reg  rxack;       // received aknowledge from slave
	reg  tip;         // transfer in progress
	reg  irq_flag;    // interrupt pending flag
	wire i2c_busy;    // bus busy (start signal detected)

	//
	// module body
	//

	// generate internal reset
	wire rst_i = arst_i ^ `I2C_RST_LVL;
	
	// generate acknowledge output signal
	assign wb_ack_o = wb_cyc_i && wb_stb_i; // because timing is always honored

	// assign DAT_O
	always@(wb_adr_i or prer or ctr or txr or cr or rxr or sr)
	begin
		case (wb_adr_i) // synopsis full_case parallel_case
			3'b000: wb_dat_o = prer[ 7:0];
			3'b001: wb_dat_o = prer[15:8];
			3'b010: wb_dat_o = ctr;
			3'b011: wb_dat_o = rxr; // write is transmit register (txr)
			3'b100: wb_dat_o = sr;  // write is command register (cr)
			3'b101: wb_dat_o = txr;
			3'b110: wb_dat_o = cr;
		endcase
	end


	// generate registers
	always@(posedge wb_clk_i or negedge rst_i)
		if (!rst_i)
			begin
				prer <= #1 16'h0;
				ctr  <= #1  8'h0;
				txr  <= #1  8'h0;
				cr   <= #1  8'h0;
			end
		else if (wb_rst_i)
			begin
				prer <= #1 16'h0;
				ctr  <= #1  8'h0;
				txr  <= #1  8'h0;
				cr   <= #1  8'h0;
			end
		else
			if (wb_cyc_i && wb_stb_i && wb_we_i)
				begin
					if (!wb_adr_i[2])
						case (wb_adr_i[1:0]) // synopsis full_case parallel_case
							2'b00 : prer [ 7:0] <= #1 wb_dat_i;
							2'b01 : prer [15:8] <= #1 wb_dat_i;
							2'b10 : ctr         <= #1 wb_dat_i;
							2'b11 : txr         <= #1 wb_dat_i;
						endcase
					else
						if (core_en && (wb_adr_i[1:0] == 2'b00) ) // only take new commands when i2c core enabled, pending commands are finished
							cr <= #1 wb_dat_i;
				end
			else
				begin
					if (done)
						cr[7:4] <= #1 4'h0; // clear command bits when done

					cr[2:1] <= #1 2'b00;  // reserved bits
					cr[0]   <= #1 cr[0] && irq_flag; // clear when irq_flag cleared
				end


	// decode command register
	wire sta  = cr[7];
	wire sto  = cr[6];
	wire rd   = cr[5];
	wire wr   = cr[4];
	wire ack  = cr[3];
	wire iack = cr[0];

	// decode control register
	assign core_en = ctr[7];

	// hookup byte controller block
	i2c_master_byte_ctrl byte_controller (
		.clk(wb_clk_i),
		.rst(wb_rst_i),
		.nReset(rst_i),
		.ena(core_en),
		.clk_cnt(prer),
		.start(sta),
		.stop(sto),
		.read(rd),
		.write(wr),
		.ack_in(ack),
		.din(txr),
		.cmd_ack(done),
		.ack_out(irxack),
		.dout(rxr),
		.i2c_busy(i2c_busy),
		.scl_i(scl_pad_i),
		.scl_o(scl_pad_o),
		.scl_oen(scl_padoen_o),
		.sda_i(sda_pad_i),
		.sda_o(sda_pad_o),
		.sda_oen(sda_padoen_o)
	);


	// status register block + interrupt request signal
	always@(posedge wb_clk_i or negedge rst_i)
		if (!rst_i)
			begin
				rxack    <= #1 1'b0;
				tip      <= #1 1'b0;
				irq_flag <= #1 1'b0;
			end
		else if (wb_rst_i)
			begin
				rxack    <= #1 1'b0;
				tip      <= #1 1'b0;
				irq_flag <= #1 1'b0;
			end
		else
			begin
				rxack    <= #1 irxack;
				tip      <= #1 (rd || wr);
				irq_flag <= #1 (done || irq_flag) && !iack; // interrupt request flag is always generated
			end

		// generate interrupt request signals
		always@(posedge wb_clk_i or negedge rst_i)
			if (!rst_i)
				wb_inta_o <= #1 1'b0;
			else if (wb_rst_i)
				wb_inta_o <= #1 1'b0;
			else
				wb_inta_o <= #1 irq_flag && ctr[6]; // interrupt signal is only generated when IEN (interrupt enable bit is set)

		// assign status register bits
		assign sr[7]   = rxack;
		assign sr[6]   = i2c_busy;
		assign sr[5:2] = 4'h0; // reserved
		assign sr[1]   = tip;
		assign sr[0]   = irq_flag;

endmodule








