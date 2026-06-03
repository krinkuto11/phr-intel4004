## =============================================================
##  Archivo de Restricciones Físicas (.XDC) para Basys 3
##  Proyecto : Calculadora BCD con Intel 4004
##  Archivo  : basys3.xdc
## =============================================================

## Reloj del Sistema (100 MHz Oscillator)
set_property PACKAGE_PIN W5 [get_ports clk]							
	set_property IOSTANDARD LVCMOS33 [get_ports clk]
	create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]
 
## Interruptores Deslizantes (Switches)
# sw(3 downto 0) -> Operando A
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

# sw(7 downto 4) -> Operando B
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[7]}]

# sw(8) -> Operador (0 = Suma, 1 = Resta)
set_property PACKAGE_PIN V2 [get_ports {sw[8]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sw[8]}]

## Display de 7 Segmentos (Ánodo Común / Activo Bajo)
# seg(6 downto 0) -> Segmentos A, B, C, D, E, F, G
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

# dp -> Punto Decimal
set_property PACKAGE_PIN V7 [get_ports dp]							
	set_property IOSTANDARD LVCMOS33 [get_ports dp]

# an(3 downto 0) -> Ánodos de habilitación de dígitos
set_property PACKAGE_PIN U2 [get_ports {an[0]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]

## Botón Central (btnC) -> RESET
set_property PACKAGE_PIN U18 [get_ports btnC]						
	set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## Configuración adicional de Voltage y Bitstream (Estándar para Basys 3)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Degradación de severidad de reglas DRC (Necesario para bucles combinacionales históricos del Intel 4004)
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical *]


