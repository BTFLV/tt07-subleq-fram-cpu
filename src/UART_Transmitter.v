module UART_Transmitter (
    input  wire           clk     ,
    input  wire           rst_n   ,
    input  wire           tx_start,
    input  wire     [7:0] tx_data ,
    output      reg       tx      ,
    output      reg       tx_busy
);

    reg [15:0] baud_counter;
    reg [ 3:0] bit_counter ;
    reg [ 7:0] shift_reg   ;
    reg        transmitting;

    localparam CLK_FREQ   = 10000000; // 10 MHz
    localparam BAUD_RATE  = 115200  ; // 115200 baud
    localparam BIT_PERIOD = 87      ; // CLK_FREQ / BAUD_RATE

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx           <= 1'b1;
            tx_busy      <= 1'b0;
            transmitting <= 1'b0;
            baud_counter <= 0;
            bit_counter  <= 0;
            shift_reg    <= 0;
        end else begin
            if (tx_start && !transmitting) begin
                transmitting <= 1'b1;
                tx_busy      <= 1'b1;
                shift_reg    <= tx_data;
                bit_counter  <= 0;
                baud_counter <= 0;
                tx           <= 1'b0;
            end else if (transmitting) begin
                if (baud_counter < BIT_PERIOD - 1) begin
                    baud_counter <= baud_counter + 1;
                end else begin
                    baud_counter <= 0;
                    if (bit_counter < 8) begin
                        tx          <= shift_reg[0];
                        shift_reg   <= shift_reg >> 1;
                        bit_counter <= bit_counter + 1;
                    end else if (bit_counter == 8) begin
                        tx          <= 1'b1;
                        bit_counter <= bit_counter + 1;
                    end else begin
                        tx_busy      <= 1'b0;
                        transmitting <= 1'b0;
                        bit_counter  <= 0;
                    end
                end
            end
        end
    end
endmodule
