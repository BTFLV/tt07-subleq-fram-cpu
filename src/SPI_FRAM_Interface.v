module SPI_FRAM_Interface (
    input  wire            clk     ,
    input  wire            rst_n   ,
    input                  spi_miso,
    output      reg        spi_mosi,
    output      reg        spi_sck ,
    output      reg        spi_cs  ,
    input  wire     [15:0] addr    ,
    input  wire     [15:0] data_in ,
    input  wire            we      ,
    input  wire            start   ,
    output      reg [15:0] data_out,
    output      reg        done
);

    assign write_data_l = data_in[7:0];
    assign write_data_h = data_in[15:8];
    assign address      = (addr[14:0] << 1)  + !hbyte;
    assign write_enable = we;

    reg [ 7:0] temp_data  ;
    reg [ 4:0] state      ;
    reg [ 4:0] bit_counter;
    reg [ 5:0] spi_clk    ;
    reg        clk_out    ;
    reg        hbyte      ;

    wire [ 7:0] write_data_l;
    wire [ 7:0] write_data_h;
    wire        write_enable;
    wire [15:0] address     ;

    parameter CMD_READ   = 8'h03;
    parameter CMD_WRITE  = 8'h02;
    parameter CMD_WREN   = 8'h06;
    parameter CMD_WRDI   = 8'h04;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk <= 6'd0;
            clk_out <= 1'b0;
        end else begin
            if (spi_clk == 6'd7) begin
                spi_clk <= 6'd0;
                clk_out <= ~clk_out;
            end else begin
                spi_clk <= spi_clk + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_cs      <= 1;
            spi_sck     <= 0;
            spi_mosi    <= 0;
            state       <= 0;
            bit_counter <= 0;
            hbyte       <= 0;
        end else begin
            case (state)
                0 : begin
                    done <= 0;
                    if (start && write_enable) begin
                        state <= 6;
                    end else if (start || hbyte) begin
                        state    <= 1;
                        spi_cs   <= 0;
                        spi_mosi <= 0;
                        spi_sck  <= 0;
                    end
                end
                1 : begin // Send read command
                    if (bit_counter < 8) begin
                        spi_mosi <= CMD_READ[7 - bit_counter];
                        spi_sck  <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 2;
                    end
                end
                2 : begin // Send address (16 bits)
                    if (bit_counter < 16) begin
                        spi_mosi <= address[15 - bit_counter];
                        spi_sck  <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 3;
                    end
                end
                3 : begin // Wait
                    if (bit_counter < 8) begin
                        bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        state       <= 4;
                    end
                end
                4 : begin // Read data byte
                    if (bit_counter < 8) begin
                        spi_sck <= ~spi_sck;
                        if (~spi_sck) temp_data[7 - bit_counter] <= spi_miso;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        if(hbyte)
                            begin
                                data_out[15:8] <= temp_data;
                            end
                        else
                            begin
                                data_out[7:0] <= temp_data;
                            end
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 5;
                        hbyte       <= ~hbyte;
                    end
                end
                5 : begin // End communication
                    spi_cs <= 1;
                    if(hbyte)
                        begin
                            state <= 0;
                        end
                    else
                        begin
                            state <= 16;
                        end
                end
                6 : begin // Send Write Enable (WREN) command
                    spi_cs <= 0;
                    if (bit_counter < 8) begin
                        spi_mosi <= CMD_WREN[7 - bit_counter];
                        spi_sck  <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 7;
                    end
                end
                7 : begin // End WREN command
                    spi_cs <= 1;
                    state  <= 8;
                end
                8 : begin // Wait
                    if (bit_counter < 8) begin
                        bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        state       <= 9;
                    end
                end
                9 : begin // Send write command
                    spi_cs <= 0;
                    if (bit_counter < 8) begin
                        spi_mosi <= CMD_WRITE[7 - bit_counter];
                        spi_sck  <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 10;
                    end
                end
                10 : begin // Send address (16 bits) for writing
                    if (bit_counter < 16) begin
                        spi_mosi <= address[15 - bit_counter];
                        spi_sck  <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 11;
                        spi_mosi    <= write_data_h[7 - bit_counter];
                    end
                end
                11 : begin // Write data byte
                    if (bit_counter < 8) begin
                        if(hbyte) begin
                            spi_mosi <= write_data_h[7 - bit_counter];
                        end else begin
                            spi_mosi <= write_data_l[7 - bit_counter];
                        end
                        spi_sck <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 12;
                        hbyte       <= ~hbyte;
                    end
                end
                12 : begin // End write communication
                    spi_cs <= 1;
                    state  <= 13;
                end
                13 : begin // Wait
                    if (bit_counter < 8) begin
                        bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        state       <= 14;
                    end
                end
                14 : begin // Send Write Disable (WRDI) command
                    spi_cs <= 0;
                    if (bit_counter < 8) begin
                        spi_mosi <= CMD_WRDI[7 - bit_counter];
                        spi_sck  <= ~spi_sck;
                        if (!spi_sck) bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        spi_mosi    <= 0;
                        spi_sck     <= 0;
                        state       <= 15;
                    end
                end
                15 : begin // End WRDI command
                    spi_cs <= 1;
                    if(hbyte)
                        begin
                            state <= 6;
                        end
                    else
                        begin
                            state <= 16;
                        end
                end
                16 : begin // Wait
                    if (bit_counter < 8) begin
                        bit_counter <= bit_counter + 1;
                    end else begin
                        bit_counter <= 0;
                        state       <= 0;
                        done        <= 1;
                    end
                end
            endcase
        end
    end
endmodule
