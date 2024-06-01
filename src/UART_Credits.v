module UART_Credits (
    input  wire     clk  ,
    input  wire     rst_n,
    output      reg tx
);

    reg [ 1:0] state              = INIT       ;
    reg [31:0] clk_counter        = 0          ;
    reg [ 3:0] bit_counter        = 0          ;
    reg [ 3:0] char_counter       = 0          ;
    reg [ 7:0] tx_shift_reg       = 8'b11111111;
    reg [31:0] idle_counter       = 0          ;
    reg        tx_busy            = 0          ;
    reg [ 7:0] MESSAGE     [0:10]              ;

    parameter CLK_FREQ     = 10000000            ; // 10 MHz
    parameter BAUD_RATE    = 115200              ; // 115200 baud
    parameter SYMBOL_COUNT = CLK_FREQ / BAUD_RATE;
    parameter BIT_COUNT    = 10                  ; // 1 start bit, 8 data bits, 1 stop bit
    parameter IDLE_COUNT   = 100000              ; // 10 ms delay

    localparam [7:0] CHAR_P     = 8'd80 ;
    localparam [7:0] CHAR_h     = 8'd104;
    localparam [7:0] CHAR_i     = 8'd105;
    localparam [7:0] CHAR_l     = 8'd108;
    localparam [7:0] CHAR_i2    = 8'd105;
    localparam [7:0] CHAR_p     = 8'd112;
    localparam [7:0] CHAR_space = 8'd32 ;
    localparam [7:0] CHAR_M     = 8'd77 ;
    localparam [7:0] CHAR_o     = 8'd111;
    localparam [7:0] CHAR_h2    = 8'd104;
    localparam [7:0] CHAR_r     = 8'd114;

    localparam INIT = 0, IDLE = 1, START = 2, TRANSMIT = 3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter  <= 0;
            bit_counter  <= 0;
            char_counter <= 0;
            tx_shift_reg <= 8'b11111111;
            idle_counter <= 0;
            tx_busy      <= 0;
            tx           <= 1'b1;
            state        <= INIT;
        end else begin
            case (state)
                INIT : begin
                    MESSAGE[0]  <= CHAR_P;
                    MESSAGE[1]  <= CHAR_h;
                    MESSAGE[2]  <= CHAR_i;
                    MESSAGE[3]  <= CHAR_l;
                    MESSAGE[4]  <= CHAR_i2;
                    MESSAGE[5]  <= CHAR_p;
                    MESSAGE[6]  <= CHAR_space;
                    MESSAGE[7]  <= CHAR_M;
                    MESSAGE[8]  <= CHAR_o;
                    MESSAGE[9]  <= CHAR_h2;
                    MESSAGE[10] <= CHAR_r;
                    state       <= IDLE;
                end
                IDLE : begin
                    if (idle_counter < IDLE_COUNT) begin
                        idle_counter <= idle_counter + 1;
                    end else begin
                        idle_counter <= 0;
                        state        <= START;
                    end
                end
                START : begin
                    tx_busy      <= 1;
                    char_counter <= 0;
                    tx_shift_reg <= MESSAGE[0];
                    state        <= TRANSMIT;
                end
                TRANSMIT : begin
                    if (clk_counter < SYMBOL_COUNT) begin
                        clk_counter <= clk_counter + 1;
                    end else begin
                        clk_counter <= 0;
                        if (bit_counter < BIT_COUNT) begin
                            bit_counter <= bit_counter + 1;
                            case (bit_counter)
                                0 : tx <= 1'b0;
                                1 : tx <= tx_shift_reg[0];
                                2 : tx <= tx_shift_reg[1];
                                3 : tx <= tx_shift_reg[2];
                                4 : tx <= tx_shift_reg[3];
                                5 : tx <= tx_shift_reg[4];
                                6 : tx <= tx_shift_reg[5];
                                7 : tx <= tx_shift_reg[6];
                                8 : tx <= tx_shift_reg[7];
                                9 : tx <= 1'b1;
                            endcase
                        end else begin
                            bit_counter <= 0;
                            if (char_counter < 10) begin
                                char_counter <= char_counter + 1;
                                tx_shift_reg <= MESSAGE[char_counter + 1];
                            end else begin
                                char_counter <= 0;
                                tx_busy      <= 0;
                                state        <= IDLE;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
