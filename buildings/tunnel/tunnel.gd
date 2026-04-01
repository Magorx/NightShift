class_name TunnelLogic
extends UndergroundTransportLogic

## Tunnel: underground item transport, max 4 cell gap between input and output.

func _is_input_category(category: String) -> bool:
	return category == "tunnel"
