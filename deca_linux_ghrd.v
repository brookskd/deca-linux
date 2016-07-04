// this is the base design for the DECA Linux project.
// The Qsys system encapsulates Nios II with MMU, DDR3, TSE MAC, QSPI interface, and PIOs for buttons, keys, and LEDs

`timescale 1 ps / 1 ps
module deca_linux_ghrd (
		input  wire        DDR3_CLK_50,
		input  wire        CLK1_50,
		input  wire        global_reset_n,

		output [7:0] LED,
		input [1:0] KEY,
		input [1:0] SW,

		output wire [14:0] mem_a,
		output wire [2:0]  mem_ba,
		inout  wire [0:0]  mem_ck,
		inout  wire [0:0]  mem_ck_n,
		output wire [0:0]  mem_cke,
		output wire [0:0]  mem_cs_n,
		output wire [1:0]  mem_dm,
		output wire [0:0]  mem_ras_n,
		output wire [0:0]  mem_cas_n,
		output wire [0:0]  mem_we_n,
		output wire        mem_reset_n,
		inout  wire [15:0] mem_dq,
		inout  wire [1:0]  mem_dqs,
		inout  wire [1:0]  mem_dqs_n,
		output wire [0:0]  mem_odt,

		///////// FLASH /////////

      inout wire [3:0]   FLASH_DATA,
      output wire        FLASH_DCLK,
      output wire        FLASH_NCSO,
      output wire        FLASH_RESET_n,

      ///////// NET /////////
      input              NET_COL,
      input              NET_CRS,
      output             NET_MDC,
      inout              NET_MDIO,
      output             NET_PCF_EN,
      output             NET_RESET_n,
      input       [3:0]  NET_RXD,
      input              NET_RX_CLK,
      input              NET_RX_DV,
      input              NET_RX_ER,
      output      [3:0]  NET_TXD,
      input              NET_TX_CLK,
      output             NET_TX_EN

	);

	wire mdio_in;
	wire mdio_oen;
	wire mdio_out;

	wire [7:0] led_pio;
	wire [7:0] button_pio;
	wire [7:0] switch_pio;

	reg [7:0] reset_count;
	reg reset_n;
	wire pll_locked;
	reg [2:0] pll_locked_sync;

	always @ (posedge DDR3_CLK_50 or negedge global_reset_n)
	begin

		if (~global_reset_n )
			pll_locked_sync <= 3'b000;
		else
			pll_locked_sync <= {pll_locked_sync[1:0], pll_locked};
	end

	always @ (posedge DDR3_CLK_50 or negedge global_reset_n)
	begin

		if (~global_reset_n)
		begin
			reset_count <= 0;
			reset_n <= 1'b0;

		end
		else if ((reset_count != 8'd255) && pll_locked_sync[2])
		begin
			reset_count <= reset_count + 1;
			reset_n <= 1'b0;
		end
		else
			reset_n <= 1'b1;
	end

    nios_system u0 (
        .clk_clk                 (DDR3_CLK_50),
        .led_pio_export     	 	(led_pio),
        .button_pio_export     	(button_pio),
        .switch_pio_export     	(switch_pio),
		  .memory_mem_a       		(mem_a[12:0]), // DDR3 memory bus depth reduced due to Qsys error when using Nios II w/MMU
        .memory_mem_ba      		(mem_ba),
        .memory_mem_ck      		(mem_ck),
        .memory_mem_ck_n    		(mem_ck_n),
        .memory_mem_cke     		(mem_cke),
        .memory_mem_cs_n    		(mem_cs_n),
        .memory_mem_dm      		(mem_dm),
        .memory_mem_ras_n   		(mem_ras_n),
        .memory_mem_cas_n   		(mem_cas_n),
        .memory_mem_we_n    		(mem_we_n),
        .memory_mem_reset_n 		(mem_reset_n),
        .memory_mem_dq      		(mem_dq),
        .memory_mem_dqs     		(mem_dqs),
        .memory_mem_dqs_n   		(mem_dqs_n),
        .memory_mem_odt     		(mem_odt),
        .reset_reset_n         	(reset_n),
        .qsys_reset_out_reset_n (NET_RESET_n), // reset Enet PHY from JTAG and power-on
        .qsys_reset_out_1_reset_n (FLASH_RESET_n), // reset EPCQ flash from JTAG and power-on
        .qspi_flash_dataout_conduit_dataout   (FLASH_DATA),
        .qspi_flash_dclk_out_conduit_dclk_out (FLASH_DCLK),
        .qspi_flash_ncs_conduit_ncs           (FLASH_NCSO),


        .ddr3_status_local_init_done       (),
        .ddr3_status_local_cal_success     (),
        .ddr3_status_local_cal_fail        (),
        .ddr3_pll_ref_clk_clk              (DDR3_CLK_50),
        .ddr3_pll_sharing_pll_mem_clk      (),
        .ddr3_pll_sharing_pll_write_clk    (),
        .ddr3_pll_sharing_pll_locked       (),
        .ddr3_pll_sharing_pll_capture0_clk (),
        .ddr3_pll_sharing_pll_capture1_clk (),

		  .tse_mac_status_connection_set_10      (  ),
		  .tse_mac_status_connection_set_1000    ( 1'b0 ),
		  .tse_mac_status_connection_eth_mode    (  ),
		  .tse_mac_status_connection_ena_10      ( 1'b1 ),

		  .tse_mac_mii_connection_mii_rx_d       ( NET_RXD ),
		  .tse_mac_mii_connection_mii_rx_dv      ( NET_RX_DV ),
		  .tse_mac_mii_connection_mii_rx_err     ( NET_RX_ER ),
		  .tse_mac_mii_connection_mii_tx_d       ( NET_TXD ),
		  .tse_mac_mii_connection_mii_tx_en      ( NET_TX_EN ),
		  .tse_mac_mii_connection_mii_tx_err     ( /* NET_TX_ER */ ),
		  .tse_mac_mii_connection_mii_crs        ( NET_CRS ),
		  .tse_mac_mii_connection_mii_col        ( NET_COL ),

// Deassert ff_tx_crc_fwd and clear OMIT_CRC bit in tx_cmd_stat to enable
// the MAC function to generate CRC-32 on packet transmission.
		  .tse_mac_misc_connection_ff_tx_crc_fwd ( 1'b0 ),
		  .tse_mac_misc_connection_ff_tx_septy   (  ),
		  .tse_mac_misc_connection_tx_ff_uflow   (  ),
		  .tse_mac_misc_connection_ff_tx_a_full  (  ),
		  .tse_mac_misc_connection_ff_tx_a_empty (  ),
		  .tse_mac_misc_connection_rx_err_stat   (  ),
		  .tse_mac_misc_connection_rx_frm_type   (  ),
		  .tse_mac_misc_connection_ff_rx_dsav    (  ),
		  .tse_mac_misc_connection_ff_rx_a_full  (  ),
		  .tse_mac_misc_connection_ff_rx_a_empty (  ),

		  .tse_mac_mdio_connection_mdc           ( NET_MDC ),
		  .tse_mac_mdio_connection_mdio_in       ( mdio_in ),
		  .tse_mac_mdio_connection_mdio_out      ( mdio_out ),
		  .tse_mac_mdio_connection_mdio_oen      ( mdio_oen ),
		  .tse_mac_pcs_mac_rx_clock_connection_clk   ( NET_RX_CLK ),
		  .tse_mac_pcs_mac_tx_clock_connection_clk   ( NET_TX_CLK ),
		  .pll_areset_export                         ( 1'b0 ),
		  .pll_locked_export                         ( pll_locked ),
		  .clk1_50_clk                               ( CLK1_50 ),
		  .reset1_50_reset_n                         ( global_reset_n )

    );

	assign mdio_in = NET_MDIO;
	assign NET_MDIO = mdio_oen == 0 ? mdio_out : 1'bz;

// Set high to enable the DP83620 PHY to respond to PHY Control Frames (inband signaling as opposed to MDIO)
// You can also enable it with the PCF_Enable bit in the PHY Control Frame Configuration Register (PCFCR).
	assign NET_PCF_EN = 1'b0;

	assign LED = ~led_pio; // LED's are active low

	assign button_pio[7:2] = 6'b0;
	assign button_pio[1] = ~KEY[1];
	assign button_pio[0] = ~KEY[0];

	assign switch_pio[7:2] = 6'b0;
	assign switch_pio[1] = ~SW[1];
	assign switch_pio[0] = ~SW[0];

endmodule
