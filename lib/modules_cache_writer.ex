defmodule Genom.ModulesCacheWriter do
	
	use ExActor.GenServer, export: :ModulesCacheWriter

	definit do
		case Genom.Tinca.get(:modules_info) do
			:not_found -> {:ok, Genom.Tinca.put(%{}, :modules_info)}
			state when is_map(state) -> {:ok, state}
		end
	end
	defcall add_info(module, key, value = %{value: val}), state: state do
		{
			:reply,
			val,
			HashUtils.addf(state, [module, key], value) |> Genom.Tinca.put(:modules_info)
		}
	end

end