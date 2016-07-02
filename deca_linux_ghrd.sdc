#create_clock -name NET_TX_CLK -period 40.000 NET_TX_CLK
create_clock -name NET_TX_CLK -period 40.000 -waveform {0.000 20.000} [get_ports {NET_TX_CLK}]
create_clock -name NET_RX_CLK -period 40.000 -waveform {0.000 20.000} [get_ports {NET_RX_CLK}]
