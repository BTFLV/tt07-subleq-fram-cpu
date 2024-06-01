`default_nettype none

module tt_um_btflv_subleq (
	input  wire [7:0] ui_in  , // Dedicated inputs
	output wire [7:0] uo_out , // Dedicated outputs
	input  wire [7:0] uio_in , // IOs: Input path
	output wire [7:0] uio_out, // IOs: Output path
	output wire [7:0] uio_oe , // IOs: Enable path (active high: 0=input, 1=output)
	input  wire       ena    , // always 1 when the design is powered, so you can ignore it
	input  wire       clk    , // clock
	input  wire       rst_n    // reset_n - low to reset
);

	assign in_miso = ui_in[0];

	assign uio_out     = data;
	assign uio_oe      = 8'b11111111;
	assign uo_out[0]   = out_mosi;
	assign uo_out[1]   = out_sck;
	assign uo_out[2]   = out_cs;
	assign uo_out[3]   = tx;
	assign uo_out[4]   = ctx;
	assign uo_out[7:5] = 3'b111;

	assign char_out     = data_a[7:0];
	assign char_valid   = char_output_flag;
	assign result       = data_b - data_a;

	reg signed [15:0] ir_a, ir_b, ir_c;
	reg signed [15:0] data_a, data_b;
	reg        [ 5:0] state, next_state;
	reg        [ 7:0] data            ;
	reg        [15:0] pc              ;
	reg               char_output_flag;
	reg               halted_reg      ;
	reg signed [15:0] data_to_ram     ;
	reg               ram_we          ;
	reg        [15:0] ram_addr        ;
	reg               tx_start        ;
	reg               ramstart        ;

	wire               ramdone      ;
	wire        [ 7:0] char_out     ;
	wire               char_valid   ;
	wire        [15:0] data_from_ram;
	wire               tx_busy      ;
	wire               ctx          ;
	wire               tx           ;
	wire signed [15:0] result       ;
	wire               in_miso      ;
	wire               out_mosi     ;
	wire               out_sck      ;
	wire               out_cs       ;

	SPI_FRAM_Interface ram (
		.clk     (clk          ),
		.rst_n   (rst_n        ),
		.addr    (ram_addr     ),
		.spi_miso(in_miso      ),
		.spi_mosi(out_mosi     ),
		.spi_sck (out_sck      ),
		.spi_cs  (out_cs       ),
		.data_in (data_to_ram  ),
		.we      (ram_we       ),
		.start   (ramstart     ),
		.done    (ramdone      ),
		.data_out(data_from_ram)
	);

	UART_Credits CreditsTX (
		.clk  (clk  ),
		.rst_n(rst_n),
		.tx   (ctx  )
	);

	UART_Transmitter uart_tx (
		.clk     (clk     ),
		.rst_n   (rst_n   ),
		.tx_start(tx_start),
		.tx_data (char_out),
		.tx      (tx      ),
		.tx_busy (tx_busy )
	);

	localparam START	 = 6'd0,
		FETCH_A0  = 6'd1,
		FETCH_A1  = 6'd2,
		FETCH_A2  = 6'd3,
		FETCH_B0  = 6'd4,
		FETCH_B1  = 6'd5,
		FETCH_B2  = 6'd6,
		FETCH_C0  = 6'd7,
		FETCH_C1  = 6'd8,
		FETCH_C2  = 6'd9,
		DECODE_A0 = 6'd10,
		DECODE_A1 = 6'd11,
		DECODE_A2 = 6'd12,
		DECODE_B0 = 6'd13,
		DECODE_B1 = 6'd14,
		DECODE_B2 = 6'd15,
		WRITE_B0 = 6'd16,
		WRITE_B1 = 6'd17,
		WRITE_B2 = 6'd18,
		HALT     = 6'd19;



	always @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			state <= START;
		else
			state <= next_state;
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			pc               <= 15'd0;
			ir_a             <= 16'b0;
			ir_b             <= 16'b0;
			ir_c             <= 16'b0;
			data_a           <= 16'b0;
			data_b           <= 16'b0;
			char_output_flag <= 1'b0;
			halted_reg       <= 1'b0;
			data_to_ram      <= 16'b0;
			ram_addr         <= 15'b0;
			ram_we           <= 1'b0;
		end else begin
			case (state)

				START : begin
					ram_addr <= pc;
					ramstart <= 1'b1;
				end

				// Fetch A B C
				FETCH_A0 : begin
					ram_addr <= pc;
					ramstart <= 1'b1;
				end

				FETCH_A1 : begin
					ramstart <= 1'b0;
				end

				FETCH_A2 : begin
					ir_a <= data_from_ram;
				end

				FETCH_B0 : begin
					ram_addr <= pc + 1;
					ramstart <= 1'b1;
				end

				FETCH_B1 : begin
					ramstart <= 1'b0;
				end

				FETCH_B2 : begin
					ir_b <= data_from_ram;
				end

				FETCH_C0 : begin
					ram_addr <= pc + 2;
					ramstart <= 1'b1;
				end

				FETCH_C1 : begin
					ramstart <= 1'b0;
				end

				FETCH_C2 : begin
					ir_c <= data_from_ram;
				end

				// Decode A B
				DECODE_A0 : begin
					ram_addr <= ir_a;
					ramstart <= 1'b1;
				end

				DECODE_A1 : begin
					ramstart <= 1'b0;
				end

				DECODE_A2 : begin
					data_a <= data_from_ram;
				end

				DECODE_B0 : begin
					if(ir_b == -1) begin
						char_output_flag <= 1'b1;
						data             <= char_out;
						ram_addr         <= 16'b0;
						ramstart         <= 1'b1;
					end else begin
						ram_addr <= ir_b;
						ramstart <= 1'b1;
					end
					if(ir_c < 0) begin
						halted_reg <= 1'b1;
					end
				end

				DECODE_B1 : begin
					ramstart         <= 1'b0;
					char_output_flag <= 1'b0;
				end

				DECODE_B2 : begin
					if(ir_b == -1) begin
						data_b <= 16'b0;
					end else begin
						data_b <= data_from_ram;
					end
				end

				// Write B-A to address B
				WRITE_B0 : begin
					if(ir_b == -1) begin
						ram_addr <= 16'b0;
						ramstart <= 1'b1;
						ram_we   <= 1'b0;
					end else begin
						ram_addr    <= ir_b;
						ramstart    <= 1'b1;
						ram_we      <= 1'b1;
						data_to_ram <= result;
					end
				end

				WRITE_B1 : begin
					ramstart <= 1'b0;
				end

				WRITE_B2 : begin
					pc     <= (result > 0 || ir_b == -1) ? pc + 3 : ir_c;
					ram_we <= 1'b0;
				end

				HALT : begin
					halted_reg <= 1'b1;
				end

			endcase
		end
	end

	always @(*) begin
		if(halted_reg)
			next_state = HALT;
		else
			case (state)
				START     : next_state = FETCH_A0;
				FETCH_A0  : next_state = FETCH_A1;
				FETCH_A1  : next_state = ramdone ? FETCH_A2 : FETCH_A1;
				FETCH_A2  : next_state = FETCH_B0;
				FETCH_B0  : next_state = FETCH_B1;
				FETCH_B1  : next_state = ramdone ? FETCH_B2 : FETCH_B1;
				FETCH_B2  : next_state = FETCH_C0;
				FETCH_C0  : next_state = FETCH_C1;
				FETCH_C1  : next_state = ramdone ? FETCH_C2 : FETCH_C1;
				FETCH_C2  : next_state = DECODE_A0;
				DECODE_A0 : next_state = DECODE_A1;
				DECODE_A1 : next_state = ramdone ? DECODE_A2 : DECODE_A1;
				DECODE_A2 : next_state = DECODE_B0;
				DECODE_B0 : next_state = DECODE_B1;
				DECODE_B1 : next_state = ramdone ? DECODE_B2 : DECODE_B1;
				DECODE_B2 : next_state = !tx_busy ? WRITE_B0 : DECODE_B2;
				WRITE_B0  : next_state = WRITE_B1;
				WRITE_B1  : next_state = ramdone ? WRITE_B2 : WRITE_B1;
				WRITE_B2  : next_state = FETCH_A0;
				HALT      : next_state = HALT;
			endcase
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			tx_start <= 1'b0;
		end else begin
			if (char_valid && !tx_busy) begin
				tx_start <= 1'b1;
			end else begin
				tx_start <= 1'b0;
			end
		end
	end

endmodule
